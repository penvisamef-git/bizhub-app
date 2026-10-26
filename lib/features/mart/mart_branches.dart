import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../restaurant/rest_common.dart' show Segmented, SelectField, SwitchRow, gap14;
import '../restaurant/rest_online.dart' show shareWidgets;
import 'mart_common.dart';
import 'mart_kit.dart';

// Branches (mart_branches) + barcode labels (mart_labels) — MartBranches.jsx, MartLabels.jsx, pos/mart/barcode.js.

class BranchesTab extends StatefulWidget {
  final MartCtx ctx;
  const BranchesTab({super.key, required this.ctx});
  @override
  State<BranchesTab> createState() => _BranchesTabState();
}

class _BranchesTabState extends State<BranchesTab> {
  Json? _g;
  MartCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/branches');
      if (mounted) setState(() => _g = obj(r['data']));
    } catch (e) {
      if (!(e is ApiError && e.status == 402)) ctx.fail(e);
      if (mounted) setState(() => _g = {});
    }
  }

  Future<void> _link(String bid) async {
    try {
      await ctx.api.post('${ctx.base}/branches', {'business_id': bid});
      ctx.notify(ctx.x('saved'));
      _load();
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _unlink(String bid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        content: Text('${ctx.x('unlink')}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(ctx.x('cancel'))),
          TextButton(onPressed: () => Navigator.pop(d, true), child: Text(ctx.x('unlink'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ctx.api.delete('${ctx.base}/branches/$bid');
      _load();
    } catch (e) {
      ctx.fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final g = _g;
    final head = MAddonHead(ctx: ctx, addon: 'mart_branches', icon: LucideIcons.network, title: ctx.x('brTitle'), sub: ctx.x('brSub'), perks: ctx.t.list('mx.brPerks'));
    if (g == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 4));
    final branch = g['role'] == 'branch';
    if (!branch && !ctx.addonOn('mart_branches')) return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [head]);
    final shops = objs(g['shops']);
    final group = mCard(context, ctx.x('group'), [
      for (final s in shops)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: c.active,
                backgroundImage: str(s['logo']).isNotEmpty ? netImage(str(s['logo'])) : null,
                child: str(s['logo']).isEmpty ? Icon(LucideIcons.store, size: 16, color: c.brandInk) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(str(s['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(s['is_main'] == true ? ctx.x('mainShop') : ctx.x('branch'), style: TextStyle(color: c.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              if (s['here'] == true) Pill(ctx.x('here'), tone: 'ok'),
              if (!branch && s['is_main'] != true)
                IconButton(
                  tooltip: ctx.x('unlink'),
                  onPressed: ctx.readOnly ? null : () => _unlink(str(s['_id'])),
                  icon: Icon(LucideIcons.unlink, size: 16, color: c.danger),
                ),
            ],
          ),
        ),
    ]);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (branch)
            Panel(
              padding: const EdgeInsets.all(16),
              child: MHead(ctx.x('brTitle'), icon: LucideIcons.network, sub: ctx.x('isBranchOf', {'name': str(obj(g['main'])['name'])})),
            )
          else
            head,
          mGap,
          group,
          if (!branch) ...[
            mGap,
            mCard(context, ctx.x('linkPick'), [
              if (objs(g['candidates']).isEmpty)
                Muted(ctx.x('noCandidates'))
              else
                for (final cand in objs(g['candidates']))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(LucideIcons.store, size: 18, color: c.muted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(str(cand['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        Btn(ctx.x('link'), icon: LucideIcons.link2, small: true, onTap: ctx.readOnly ? null : () => _link(str(cand['_id']))),
                      ],
                    ),
                  ),
            ]),
          ],
          if ((branch && g['active'] == true) || (!branch && shops.length > 1)) ...[mGap, _BranchTools(ctx: ctx, shops: shops)],
        ],
      ),
    );
  }
}

class _BranchTools extends StatefulWidget {
  final MartCtx ctx;
  final List<Json> shops;
  const _BranchTools({required this.ctx, required this.shops});
  @override
  State<_BranchTools> createState() => _BranchToolsState();
}

class _BranchToolsState extends State<_BranchTools> {
  final _p = Period();
  Json? _rep;
  List<Json> _found = [], _prods = [], _lines = [];
  List<Json>? _trs;
  final _q = TextEditingController(), _note = TextEditingController();
  late String _to = _others.isNotEmpty ? str(_others.first['_id']) : '', _copyTo = _to;
  bool _prices = false, _busy = false;
  final Map<String, TextEditingController> _qty = {};
  MartCtx get ctx => widget.ctx;
  List<Json> get _others => widget.shops.where((s) => s['here'] != true).toList();

  @override
  void initState() {
    super.initState();
    _loadRep();
    _loadTrs();
    ctx.api.get('${ctx.base}/products').then((r) => _prods = objs(r['data']), onError: (_) {});
  }

  @override
  void dispose() {
    _q.dispose();
    _note.dispose();
    for (final x in _qty.values) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRep() async {
    setState(() => _rep = null);
    try {
      final r = await ctx.api.get('${ctx.base}/branches/report', _p.params);
      if (mounted) setState(() => _rep = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _loadTrs() async {
    try {
      final r = await ctx.api.get('${ctx.base}/branches/transfers');
      if (mounted) setState(() => _trs = objs(r['data']));
    } catch (_) {
      if (mounted) setState(() => _trs = []);
    }
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) return setState(() => _found = []);
    try {
      final r = await ctx.api.get('${ctx.base}/branches/stock', {'q': q.trim()});
      if (mounted && _q.text == q) setState(() => _found = objs(r['data']));
    } catch (_) {}
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      await ctx.api.post('${ctx.base}/branches/transfer', {
        'to': _to,
        'note': _note.text.trim(),
        'items': [
          for (final l in _lines)
            if ((numOf(_qty[str(l['_id'])]?.text ?? '') ?? 0) > 0) {'product_id': l['_id'], 'qty': numOf(_qty[str(l['_id'])]!.text)},
        ],
      });
      ctx.notify(ctx.x('transferDone'));
      setState(() {
        _lines = [];
        _note.clear();
      });
      _loadTrs();
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    setState(() => _busy = true);
    try {
      final r = await ctx.api.post('${ctx.base}/branches/copy', {'to': _copyTo, 'prices': _prices});
      final d = obj(r['data']);
      ctx.notify(ctx.x('copyDone', {'added': n(d['added']), 'updated': n(d['updated']), 'same': n(d['same'])}));
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rep = _rep;
    final others = [for (final s in _others) (str(s['_id']), str(s['name']))];
    final canSend = _to.isNotEmpty && _lines.any((l) => (numOf(_qty[str(l['_id'])]?.text ?? '') ?? 0) > 0);
    Widget shopRow(String name, String sub, String sales, String cnt, String stock, String lowOut, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w700)),
                Text('$sub${sub.isEmpty ? '' : ' · '}${ctx.x('receipts')} $cnt · ${ctx.x('stockValue')} $stock · ${ctx.x('lowOut')} $lowOut', style: TextStyle(color: c.muted, fontSize: 12)),
              ],
            ),
          ),
          Text(
            sales,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: bold ? 16 : 14),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        mCard(context, ctx.x('report'), [
          PeriodBar(ctx: ctx, p: _p, onChanged: _loadRep),
          if (rep == null)
            const SkelList(rows: 3)
          else ...[
            for (final s in objs(rep['shops']))
              shopRow(
                str(s['name']),
                s['is_main'] == true ? ctx.x('mainShop') : '',
                money(s['sales'], str(s['currency'])),
                '${n(s['count'])}',
                money(s['stock_value'], str(s['currency'])),
                '${n(s['low'])} / ${n(s['out'])}',
              ),
            Divider(color: c.lineStrong),
            shopRow(
              ctx.x('allShops'),
              '',
              money(obj(rep['total'])['sales'], str(rep['currency'])),
              '${n(obj(rep['total'])['count'])}',
              money(obj(rep['total'])['stock_value'], str(rep['currency'])),
              '${n(obj(rep['total'])['low'])} / ${n(obj(rep['total'])['out'])}',
              bold: true,
            ),
          ],
        ]),
        mGap,
        mCard(context, ctx.x('stockAll'), [
          Field(controller: _q, hint: ctx.x('stockSearch'), icon: LucideIcons.search, onChanged: _search),
          const SizedBox(height: 8),
          for (final f in _found)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(str(f['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in objs(f['shops']))
                        Pill(
                          '${s['shop']}: ${s['stock'] == null ? '—' : qtyOf(s['stock'])}',
                          tone: s['stock'] != null && n(s['stock']) <= 0
                              ? 'bad'
                              : s['stock'] != null && n(s['stock']) <= n(s['low'])
                              ? 'warn'
                              : '',
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ]),
        mGap,
        mCard(context, ctx.x('transfer'), [
          SelectField<String>(label: ctx.x('transferTo'), value: _to, options: others, onChanged: (v) => setState(() => _to = v)),
          gap14,
          for (final l in _lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(str(l['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  SizedBox(
                    width: 90,
                    child: Field(
                      controller: _qty.putIfAbsent(str(l['_id']), () => TextEditingController(text: '1')),
                      keyboard: decimalKeys,
                      align: TextAlign.center,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  RoundBtn(LucideIcons.x, size: 34, onTap: () => setState(() => _lines.remove(l))),
                ],
              ),
            ),
          Btn(
            ctx.x('pickProduct'),
            icon: LucideIcons.plus,
            kind: BtnKind.ghost,
            expand: true,
            onTap: () async {
              final p = await pickProduct(context, ctx, _prods, exclude: _lines.map((l) => str(l['_id'])).toSet());
              if (p != null) setState(() => _lines.add(p));
            },
          ),
          gap14,
          Field(controller: _note, hint: ctx.x('note'), maxLength: 200),
          gap14,
          Btn(ctx.x('transfer'), icon: LucideIcons.arrowRightLeft, expand: true, busy: _busy, onTap: _busy || ctx.readOnly || !canSend ? null : _send),
        ]),
        mGap,
        mCard(context, ctx.x('copyProducts'), [
          SelectField<String>(label: ctx.x('copyTo'), value: _copyTo, options: others, onChanged: (v) => setState(() => _copyTo = v)),
          const SizedBox(height: 8),
          SwitchRow(title: ctx.x('copyPrices'), value: _prices, onChanged: (v) => setState(() => _prices = v)),
          const SizedBox(height: 8),
          Btn(ctx.x('copyProducts'), icon: LucideIcons.copy, kind: BtnKind.ghost, expand: true, onTap: _busy || ctx.readOnly || _copyTo.isEmpty ? null : _copy),
        ]),
        mGap,
        mCard(context, ctx.x('transfers'), [
          if (_trs == null)
            const SkelList(rows: 2)
          else if (_trs!.isEmpty)
            Muted('—')
          else
            for (final t in _trs!)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${t['from_name']} → ${t['to_name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      [
                        mDayTime(t['created_date'], ctx.lang),
                        objs(t['items']).map((i) => '${qtyOf(i['qty'])}× ${i['name']}').join(', '),
                        str(t['note']),
                        str(t['by']),
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: TextStyle(color: c.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
        ]),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------- barcodes
const _l = ['0001101', '0011001', '0010011', '0111101', '0100011', '0110001', '0101111', '0111011', '0110111', '0001011'];
const _g = ['0100111', '0110011', '0011011', '0100001', '0011101', '0111001', '0000101', '0010001', '0001001', '0010111'];
const _r = ['1110010', '1100110', '1101100', '1000010', '1011100', '1001110', '1010000', '1000100', '1001000', '1110100'];
const _parity = ['LLLLLL', 'LLGLGG', 'LLGGLG', 'LLGGGL', 'LGLLGG', 'LGGLLG', 'LGGGLL', 'LGLGLG', 'LGLGGL', 'LGGLGL'];
const _c128 = [
  '212222', '222122', '222221', '121223', '121322', '131222', '122213', '122312', '132212', '221213', '221312', '231212', '112232', '122132', '122231', '113222', '123122', '123221', //
  '223211', '221132', '221231', '213212', '223112', '312131', '311222', '321122', '321221', '312212', '322112', '322211', '212123', '212321', '232121', '111323', '131123', '131321',
  '112313', '132113', '132311', '211313', '231113', '231311', '112133', '112331', '132131', '113123', '113321', '133121', '313121', '211331', '231131', '213113', '213311', '213131',
  '311123', '311321', '331121', '312113', '312311', '332111', '314111', '221411', '431111', '111224', '111422', '121124', '121421', '141122', '141221', '112214', '112412', '122114',
  '122411', '142112', '142211', '241211', '221114', '413111', '241112', '134111', '111242', '121142', '121241', '114212', '124112', '124211', '411212', '421112', '421211', '212141',
  '214121', '412121', '111143', '111341', '131141', '114113', '114311', '411113', '411311', '113141', '114131', '311141', '411131', '211412', '211214', '211232',
];

String _ean13Check(String d12) {
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += int.parse(d12[i]) * (i.isOdd ? 3 : 1);
  }
  return '${(10 - sum % 10) % 10}';
}

String _ean8Check(String d7) {
  var sum = 0;
  for (var i = 0; i < 7; i++) {
    sum += int.parse(d7[i]) * (i.isOdd ? 1 : 3);
  }
  return '${(10 - sum % 10) % 10}';
}

String _ean13Bits(String code) {
  final first = int.parse(code[0]);
  final b = StringBuffer('101');
  for (var i = 1; i <= 6; i++) {
    b.write((_parity[first][i - 1] == 'L' ? _l : _g)[int.parse(code[i])]);
  }
  b.write('01010');
  for (var i = 7; i <= 12; i++) {
    b.write(_r[int.parse(code[i])]);
  }
  b.write('101');
  return b.toString();
}

String _ean8Bits(String code) {
  final b = StringBuffer('101');
  for (var i = 0; i < 4; i++) {
    b.write(_l[int.parse(code[i])]);
  }
  b.write('01010');
  for (var i = 4; i < 8; i++) {
    b.write(_r[int.parse(code[i])]);
  }
  b.write('101');
  return b.toString();
}

String? _code128Bits(String text) {
  final vals = <int>[];
  if (RegExp(r'^\d+$').hasMatch(text) && text.length >= 4 && text.length.isEven) {
    vals.add(105);
    for (var i = 0; i < text.length; i += 2) {
      vals.add(int.parse(text.substring(i, i + 2)));
    }
  } else {
    vals.add(104);
    for (final ch in text.codeUnits) {
      if (ch < 32 || ch > 126) return null;
      vals.add(ch - 32);
    }
  }
  var sum = vals.first;
  for (var i = 1; i < vals.length; i++) {
    sum += vals[i] * i;
  }
  vals.add(sum % 103);
  final b = StringBuffer();
  for (final v in vals) {
    var bar = true;
    for (final w in _c128[v].split('')) {
      b.write((bar ? '1' : '0') * int.parse(w));
      bar = !bar;
    }
  }
  b.write('1100011101011');
  return b.toString();
}

// bits for any code (EAN-13 / UPC-A / EAN-8 for digits, else Code 128); null when it can't be drawn
String? barcodeBits(String raw) {
  final code = raw.trim();
  if (code.isEmpty) return null;
  if (RegExp(r'^\d{13}$').hasMatch(code) && _ean13Check(code.substring(0, 12)) == code[12]) return _ean13Bits(code);
  if (RegExp(r'^\d{12}$').hasMatch(code)) {
    final c = '0$code';
    if (_ean13Check(c.substring(0, 12)) == c[12]) return _ean13Bits(c);
  }
  if (RegExp(r'^\d{8}$').hasMatch(code) && _ean8Check(code.substring(0, 7)) == code[7]) return _ean8Bits(code);
  return _code128Bits(code);
}

// a barcode with its digits under it
class BarcodeView extends StatelessWidget {
  final String code;
  final double height;
  const BarcodeView(this.code, {super.key, this.height = 40});
  @override
  Widget build(BuildContext context) {
    final bits = barcodeBits(code);
    if (bits == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(painter: _BarsPaint(bits)),
        ),
        const SizedBox(height: 2),
        Text(
          code,
          style: TextStyle(fontSize: height * .24, letterSpacing: code.length > 14 ? 0 : 1.5, color: Colors.black),
        ),
      ],
    );
  }
}

class _BarsPaint extends CustomPainter {
  final String bits;
  _BarsPaint(this.bits);
  @override
  void paint(Canvas canvas, Size s) {
    const quiet = 6;
    final unit = s.width / (bits.length + quiet * 2);
    final p = Paint()..color = Colors.black;
    var i = 0;
    while (i < bits.length) {
      if (bits[i] == '1') {
        var k = 1;
        while (i + k < bits.length && bits[i + k] == '1') {
          k++;
        }
        canvas.drawRect(Rect.fromLTWH((quiet + i) * unit, 0, k * unit, s.height), p);
        i += k;
      } else {
        i++;
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPaint o) => o.bits != bits;
}

// ------------------------------------------------------------------------------------------- labels
const _sizes = [('40x30', 40.0, 30.0), ('50x30', 50.0, 30.0), ('58x40', 58.0, 40.0)];

Future<void> openLabels(BuildContext context, MartCtx ctx, List<Json> products, VoidCallback onChanged) async {
  if (!ctx.addonOn('mart_labels')) {
    await showSheet<void>(
      context,
      (s) => MSheet(
        title: ctx.m('labelsTitle'),
        footer: [
          Expanded(
            child: GoldBtn(
              '${ctx.m('unlock', {'coins': fmt(n(ctx.addon('mart_labels')['price'] ?? 45))})} · ${ctx.m('forever')}',
              onTap: ctx.readOnly
                  ? null
                  : () {
                      Navigator.pop(s);
                      ctx.askBuy('mart_labels');
                    },
            ),
          ),
        ],
        children: [
          Icon(LucideIcons.barcode, size: 34, color: s.c.brand),
          const SizedBox(height: 10),
          Muted(ctx.m('labelsLocked'), align: TextAlign.center),
        ],
      ),
    );
    return;
  }
  await showSheet<void>(context, (_) => _LabelsSheet(ctx: ctx, products: products, onChanged: onChanged));
}

class _LabelsSheet extends StatefulWidget {
  final MartCtx ctx;
  final List<Json> products;
  final VoidCallback onChanged;
  const _LabelsSheet({required this.ctx, required this.products, required this.onChanged});
  @override
  State<_LabelsSheet> createState() => _LabelsSheetState();
}

class _LabelsSheetState extends State<_LabelsSheet> {
  late List<Json> _products = widget.products;
  final Map<String, int> _qty = {};
  final _q = TextEditingController();
  String _size = '40x30';
  bool _price = true, _shop = true, _busy = false;
  final Map<String, GlobalKey> _keys = {};
  MartCtx get ctx => widget.ctx;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _makeCode(Json p) async {
    setState(() => _busy = true);
    try {
      final r = await ctx.api.post('${ctx.base}/products/${p['_id']}/barcode');
      final row = obj(r['data']);
      setState(() => _products = [for (final x in _products) str(x['_id']) == str(row['_id']) ? row : x]);
      ctx.notify(ctx.m('saved'));
      widget.onChanged();
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _label(Json p, (String, double, double) size) {
    final (_, w, h) = size;
    final px = 3.4; // on-screen pixels per mm
    return Container(
      width: w * px,
      height: h * px,
      color: Colors.white,
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          if (_shop && str(ctx.business['name']).isNotEmpty)
            Text(
              str(ctx.business['name']),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 8.5, color: Colors.black),
            ),
          Text(
            str(p['name']),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.black, height: 1.1),
          ),
          Expanded(
            child: Center(child: BarcodeView(str(p['barcode']), height: h >= 40 ? 40 : 28)),
          ),
          if (_price)
            Text(
              money(p['price'], ctx.cur),
              style: TextStyle(fontSize: h >= 40 ? 15 : 13, fontWeight: FontWeight.w800, color: Colors.black),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final size = _sizes.firstWhere((s) => s.$1 == _size);
    final t = _q.text.trim().toLowerCase();
    final rows = _products.where((p) => p['active'] != false && (t.isEmpty || str(p['name']).toLowerCase().contains(t) || str(p['barcode']).contains(t))).toList();
    final jobs = rows.where((p) => str(p['barcode']).isNotEmpty && (_qty[str(p['_id'])] ?? 0) > 0).toList();
    final total = jobs.fold<int>(0, (a, p) => a + (_qty[str(p['_id'])] ?? 0));
    final sample = jobs.isNotEmpty ? jobs.first : rows.where((p) => str(p['barcode']).isNotEmpty).firstOrNull;
    return MSheet(
      title: ctx.m('labelsTitle'),
      footer: [
        Expanded(
          child: Btn(
            ctx.m('printLabels', {'n': total}),
            icon: LucideIcons.share2,
            expand: true,
            onTap: total == 0 ? null : () => shareWidgets([for (final p in jobs) _keys[str(p['_id'])]!], (i) => 'label-${str(jobs[i]['barcode'])}-x${_qty[str(jobs[i]['_id'])]}.png'),
          ),
        ),
      ],
      children: [
        Muted(ctx.m('labelsSub')),
        const SizedBox(height: 4),
        Muted(ctx.t('app.labelsShare')),
        gap14,
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Segmented<String>(value: _size, options: [for (final s in _sizes) (s.$1, '${s.$2.toInt()}×${s.$3.toInt()} mm')], onChanged: (v) => setState(() => _size = v)),
        ),
        const SizedBox(height: 6),
        SwitchRow(title: ctx.m('showPrice'), value: _price, onChanged: (v) => setState(() => _price = v)),
        SwitchRow(title: ctx.m('showShop'), value: _shop, onChanged: (v) => setState(() => _shop = v)),
        if (sample != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(16)),
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 14, offset: const Offset(0, 4))],
                ),
                child: _label(sample, size),
              ),
            ),
          ),
        ],
        gap14,
        Field(controller: _q, hint: ctx.m('search'), icon: LucideIcons.search, onChanged: (_) => setState(() {})),
        const SizedBox(height: 8),
        for (final p in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(str(p['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(str(p['barcode']).isEmpty ? ctx.m('noBarcodeYet') : str(p['barcode']), style: TextStyle(color: c.muted, fontSize: 12.5)),
                    ],
                  ),
                ),
                Text(money(p['price'], ctx.cur), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                if (str(p['barcode']).isNotEmpty) ...[
                  RoundBtn(LucideIcons.minus, size: 32, onTap: () => setState(() => _qty[str(p['_id'])] = ((_qty[str(p['_id'])] ?? 0) - 1).clamp(0, 999))),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${_qty[str(p['_id'])] ?? 0}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  RoundBtn(LucideIcons.plus, size: 32, onTap: () => setState(() => _qty[str(p['_id'])] = ((_qty[str(p['_id'])] ?? 0) + 1).clamp(0, 999))),
                ] else
                  Btn(ctx.m('makeBarcode'), icon: LucideIcons.wand, kind: BtnKind.ghost, small: true, onTap: _busy || ctx.readOnly ? null : () => _makeCode(p)),
              ],
            ),
          ),
        // the labels that will be shared (one picture each)
        if (jobs.isNotEmpty) ...[
          gap14,
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final p in jobs)
                Column(
                  children: [
                    RepaintBoundary(key: _keys.putIfAbsent(str(p['_id']), GlobalKey.new), child: _label(p, size)),
                    const SizedBox(height: 4),
                    Text('× ${_qty[str(p['_id'])]}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}
