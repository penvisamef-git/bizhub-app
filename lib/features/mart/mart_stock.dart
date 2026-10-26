import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../restaurant/rest_common.dart' show SelectField, gap14;
import 'mart_common.dart';
import 'mart_kit.dart';

// Stock (mart_stock) + Suppliers (mart_suppliers) — the app version of MartStock.jsx and MartSuppliers.jsx.
//   GET mart/stock → { rows[{…product, state: ok|low|out|off}], counts{all,low,out,off}, value }
//   POST mart/stock/in { items[{product_id, qty, cost?, expires?}], note, supplier_id?, invoice_no? }
//   POST mart/stock/count { product_id, count, note }      GET mart/stock/moves {product_id?}

class StockTab extends StatefulWidget {
  final MartCtx ctx;
  const StockTab({super.key, required this.ctx});
  @override
  State<StockTab> createState() => _StockTabState();
}

class _StockTabState extends State<StockTab> {
  Json? _data;
  String _filter = 'all', _sort = 'name', _query = '';
  final _q = TextEditingController();
  MartCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    if (ctx.stockOn) _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/stock');
      if (mounted) setState(() => _data = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  String _unit(Object? id) => unitName(objs(ctx.data['units']).where((u) => str(u['_id']) == str(id)).firstOrNull, ctx.lang);
  String _cat(Object? id) => str(objs(ctx.data['categories']).where((c) => str(c['_id']) == str(id)).firstOrNull?['name']);

  Future<void> _receive([Json? first]) async {
    final products = objs(_data?['rows']).where((p) => p['state'] != 'off').toList();
    final ok = await showSheet<bool>(context, (_) => ReceiveSheet(ctx: ctx, products: products, first: first));
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!ctx.stockOn) {
      return MLocked(
        ctx: ctx,
        addon: 'mart_stock',
        icon: LucideIcons.package,
        text: ctx.m('stockLocked'),
        button: '${ctx.m('unlock', {'coins': fmt(n(ctx.addon('mart_stock')['price'] ?? 115))})} ${ctx.m('perYear')}',
      );
    }
    final c = context.c;
    final data = _data;
    final counts = obj(data?['counts']);
    final t = _query.trim().toLowerCase();
    num val(Json p) => p['track_stock'] == true ? (n(p['stock']) > 0 ? n(p['stock']) : 0) * n(p['cost']) : 0;
    const order = {'out': 0, 'low': 1, 'ok': 2, 'off': 3};
    final rows = objs(data?['rows']).where((p) => (_filter == 'all' || p['state'] == _filter) && (t.isEmpty || str(p['name']).toLowerCase().contains(t) || str(p['barcode']).contains(t))).toList()
      ..sort(
        (a, b) => switch (_sort) {
          'low' => (order[a['state']] ?? 3).compareTo(order[b['state']] ?? 3) != 0 ? (order[a['state']] ?? 3).compareTo(order[b['state']] ?? 3) : n(a['stock']).compareTo(n(b['stock'])),
          'value' => val(b).compareTo(val(a)),
          _ => str(a['name']).toLowerCase().compareTo(str(b['name']).toLowerCase()),
        },
      );
    final tracked = n(counts['all']) - n(counts['off']);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Panel(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MHead(ctx.m('tabs.stock'), icon: LucideIcons.boxes, sub: ctx.m('stockSub')),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Btn(
                      ctx.m('history'),
                      icon: LucideIcons.history,
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: () => showSheet<void>(context, (_) => _MovesSheet(ctx: ctx)),
                    ),
                    if (!ctx.readOnly) Btn(ctx.m('receive'), icon: LucideIcons.packagePlus, small: true, onTap: data == null ? null : () => _receive()),
                  ],
                ),
                gap14,
                if (data == null)
                  const SkelList(rows: 2)
                else
                  Tiles([
                    ('${tracked.toInt()}', ctx.m('tracked'), null),
                    ('${n(counts['low'])}', ctx.m('lowStock'), n(counts['low']) > 0 ? c.warn : null),
                    ('${n(counts['out'])}', ctx.m('outStock'), n(counts['out']) > 0 ? c.danger : null),
                    (money(data['value'], ctx.cur), ctx.m('stockValue'), null),
                  ]),
              ],
            ),
          ),
          mGap,
          Panel(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Field(
                  controller: _q,
                  hint: ctx.m('search'),
                  icon: LucideIcons.search,
                  onChanged: (v) => setState(() => _query = v),
                  suffix: IconButton(
                    icon: const Icon(LucideIcons.scanBarcode, size: 18),
                    onPressed: () async {
                      final v = await scanBarcode(context, ctx.t);
                      if (v == null) return;
                      _q.text = v;
                      setState(() => _query = v);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (k, label) in [('all', ctx.m('allCats')), ('low', ctx.m('lowStock')), ('out', ctx.m('outStock')), ('off', ctx.m('notTracked'))])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(k != 'all' && n(counts[k]) > 0 ? '$label  ${n(counts[k])}' : label),
                            selected: _filter == k,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _filter = k),
                            selectedColor: c.active,
                            labelStyle: TextStyle(fontWeight: FontWeight.w700, color: _filter == k ? c.brandInk : c.ink),
                            side: BorderSide(color: _filter == k ? c.brand : c.line),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SelectField<String>(value: _sort, options: [('name', ctx.m('sortName')), ('low', ctx.m('sortLow')), ('value', ctx.m('sortValue'))], onChanged: (v) => setState(() => _sort = v)),
                const SizedBox(height: 6),
                if (data == null)
                  const SkelList(rows: 5)
                else if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Muted(ctx.m('noProducts'), align: TextAlign.center),
                  )
                else
                  for (final (i, p) in rows.indexed) ...[
                    if (i > 0) Divider(height: 1, color: c.line),
                    _StockRow(
                      ctx: ctx,
                      p: p,
                      unit: _unit(p['unit_id']),
                      sub: [str(p['barcode']), _cat(p['category_id'])].where((x) => x.isNotEmpty).join(' · '),
                      onReceive: ctx.readOnly ? null : () => _receive(p),
                      onCount: ctx.readOnly
                          ? null
                          : () async {
                              final ok = await showSheet<bool>(context, (_) => _CountSheet(ctx: ctx, p: p));
                              if (ok == true) _load();
                            },
                      onHistory: () => showSheet<void>(context, (_) => _MovesSheet(ctx: ctx, product: p)),
                    ),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  final MartCtx ctx;
  final Json p;
  final String unit, sub;
  final VoidCallback? onReceive, onCount;
  final VoidCallback onHistory;
  const _StockRow({required this.ctx, required this.p, required this.unit, required this.sub, this.onReceive, this.onCount, required this.onHistory});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final state = str(p['state']);
    final low = p['low_stock'] == null ? 5 : n(p['low_stock']);
    final stock = n(p['stock']);
    final pct = state == 'off' ? 0.0 : (stock <= 0 ? 0.0 : (stock / (low * 4 < 1 ? 1 : low * 4)).clamp(.04, 1.0).toDouble());
    final tone = switch (state) {
      'out' => c.danger,
      'low' => c.warn,
      'ok' => c.good,
      _ => c.muted,
    };
    final photo = str(obj(p['photo'])['url']);
    final label = switch (state) {
      'ok' => ctx.m('okStock'),
      'low' => ctx.m('lowStock'),
      'out' => ctx.m('outStock'),
      _ => ctx.m('notTracked'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: photo.isNotEmpty ? Image(image: netImage(photo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.package, size: 18, color: c.muted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      str(p['name']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      sub.isEmpty ? '—' : sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Pill(label, tone: {'ok': 'ok', 'low': 'warn', 'out': 'bad'}[state] ?? ''),
            ],
          ),
          if (state != 'off') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: r3(stock),
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: tone),
                      ),
                      TextSpan(
                        text: ' $unit',
                        style: TextStyle(color: c.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(value: pct, minHeight: 6, color: tone, backgroundColor: c.bg2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(money((stock > 0 ? stock : 0) * n(p['cost']), ctx.cur), style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 2),
            Text(ctx.m('lowAt', {'n': qtyOf(low)}), style: TextStyle(color: c.muted, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (onReceive != null) Btn(ctx.m('receiveShort'), icon: LucideIcons.plus, kind: BtnKind.ghost, small: true, onTap: onReceive),
                if (onCount != null) Btn(ctx.m('countBtn'), icon: LucideIcons.clipboardCheck, kind: BtnKind.ghost, small: true, onTap: onCount),
                Btn(ctx.m('history'), icon: LucideIcons.history, kind: BtnKind.ghost, small: true, onTap: onHistory),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// receive stock: lines (qty, cost each, expiry day), who brought it, note
class ReceiveSheet extends StatefulWidget {
  final MartCtx ctx;
  final List<Json> products;
  final Json? first;
  const ReceiveSheet({super.key, required this.ctx, required this.products, this.first});
  @override
  State<ReceiveSheet> createState() => _ReceiveSheetState();
}

class _Line {
  final Json p;
  final qty = TextEditingController(), cost = TextEditingController();
  String expires = '';
  _Line(this.p) {
    if (n(p['cost']) > 0) cost.text = '${p['cost']}';
  }
  void dispose() {
    qty.dispose();
    cost.dispose();
  }
}

class _ReceiveSheetState extends State<ReceiveSheet> with SheetSave {
  final List<_Line> _lines = [];
  final _note = TextEditingController(), _inv = TextEditingController();
  List<Json> _sups = [];
  String _sup = '';
  MartCtx get ctx => widget.ctx;
  @override
  MartCtx get mctx => ctx;
  bool get _supOn => ctx.addonOn('mart_suppliers');
  bool get _expOn => ctx.addonOn('mart_expiry');

  @override
  void initState() {
    super.initState();
    if (widget.first != null) _lines.add(_Line(widget.first!));
    if (_supOn) {
      ctx.api.get('${ctx.base}/suppliers').then((r) {
        if (mounted) setState(() => _sups = objs(r['data']));
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    _note.dispose();
    _inv.dispose();
    super.dispose();
  }

  bool get _ok => _lines.isNotEmpty && _lines.every((l) => (numOf(l.qty.text) ?? 0) > 0);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final sym = ctx.cur == 'KHR' ? '៛' : '\$';
    return MSheet(
      title: ctx.m('receive'),
      footer: [
        const Spacer(),
        Btn(ctx.m('cancel'), kind: BtnKind.ghost, small: true, onTap: busy ? null : () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(
          busy ? ctx.m('saving') : ctx.m('save'),
          small: true,
          busy: busy,
          onTap: busy || !_ok
              ? null
              : () => save(
                  () => ctx.api.post('${ctx.base}/stock/in', {
                    'items': [
                      for (final l in _lines)
                        {
                          'product_id': l.p['_id'],
                          'qty': numOf(l.qty.text),
                          if (l.cost.text.trim().isNotEmpty) 'cost': numOf(l.cost.text) ?? 0,
                          if (_expOn && l.expires.isNotEmpty) 'expires': l.expires,
                        },
                    ],
                    'note': _note.text.trim(),
                    if (_supOn && _sup.isNotEmpty) ...{'supplier_id': _sup, 'invoice_no': _inv.text.trim()},
                  }),
                ),
        ),
      ],
      children: [
        Btn(
          ctx.m('pickProduct'),
          icon: LucideIcons.plus,
          kind: BtnKind.ghost,
          expand: true,
          onTap: () async {
            final p = await pickProduct(context, ctx, widget.products, exclude: _lines.map((l) => str(l.p['_id'])).toSet());
            if (p != null) setState(() => _lines.add(_Line(p)));
          },
        ),
        for (final l in _lines) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: c.line),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(str(l.p['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    RoundBtn(
                      LucideIcons.trash2,
                      size: 34,
                      fg: c.danger,
                      onTap: () => setState(() {
                        _lines.remove(l);
                        l.dispose();
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Field(label: ctx.m('qtyIn'), controller: l.qty, keyboard: decimalKeys, autofocus: l == _lines.last, onChanged: (_) => setState(() {})),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Field(label: '${ctx.m('costEach')} ($sym)', controller: l.cost, keyboard: decimalKeys),
                    ),
                  ],
                ),
                if (_expOn) ...[const SizedBox(height: 10), DayField(label: ctx.x('expiryOpt'), value: l.expires, onChanged: (v) => setState(() => l.expires = v))],
              ],
            ),
          ),
        ],
        if (_supOn) ...[
          gap14,
          SelectField<String>(
            label: ctx.m('supplierCol'),
            value: _sup,
            options: [('', ctx.m('noSupplier')), for (final s in _sups) (str(s['_id']), str(s['name']))],
            onChanged: (v) => setState(() => _sup = v),
          ),
          if (_sup.isNotEmpty) ...[gap14, Field(label: ctx.m('invoiceNo'), controller: _inv, maxLength: 60)],
        ],
        gap14,
        Field(label: ctx.m('stockNote'), controller: _note, maxLength: 200),
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}

class _CountSheet extends StatefulWidget {
  final MartCtx ctx;
  final Json p;
  const _CountSheet({required this.ctx, required this.p});
  @override
  State<_CountSheet> createState() => _CountSheetState();
}

class _CountSheetState extends State<_CountSheet> with SheetSave {
  late final _count = TextEditingController(text: qtyOf(widget.p['stock']));
  final _note = TextEditingController();
  @override
  MartCtx get mctx => widget.ctx;

  @override
  void dispose() {
    _count.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ctx = widget.ctx;
    final v = numOf(_count.text);
    final diff = v == null ? 0 : ((v - n(widget.p['stock'])) * 1000).round() / 1000;
    return MSheet(
      title: '${ctx.m('countTitle')} · ${widget.p['name']}',
      footer: [
        const Spacer(),
        Btn(ctx.m('cancel'), kind: BtnKind.ghost, small: true, onTap: busy ? null : () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(
          busy ? ctx.m('saving') : ctx.m('save'),
          small: true,
          busy: busy,
          onTap: busy || v == null ? null : () => save(() => ctx.api.post('${ctx.base}/stock/count', {'product_id': widget.p['_id'], 'count': v, 'note': _note.text.trim()})),
        ),
      ],
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${ctx.m('inStock')}: '),
              TextSpan(
                text: qtyOf(widget.p['stock']),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          style: TextStyle(color: c.muted),
        ),
        gap14,
        Field(
          label: ctx.m('counted'),
          controller: _count,
          autofocus: true,
          keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true),
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          onChanged: (_) => setState(() {}),
        ),
        if (diff != 0) ...[
          const SizedBox(height: 6),
          Text(
            diff > 0 ? '+${qtyOf(diff)}' : qtyOf(diff),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: diff < 0 ? c.danger : c.good),
          ),
        ],
        gap14,
        Field(label: ctx.m('stockNote'), controller: _note, maxLength: 200),
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}

// the stock history (all products, or one)
class _MovesSheet extends StatefulWidget {
  final MartCtx ctx;
  final Json? product;
  const _MovesSheet({required this.ctx, this.product});
  @override
  State<_MovesSheet> createState() => _MovesSheetState();
}

class _MovesSheetState extends State<_MovesSheet> {
  List<Json>? _rows;
  @override
  void initState() {
    super.initState();
    final ctx = widget.ctx;
    ctx.api.get('${ctx.base}/stock/moves', {if (widget.product != null) 'product_id': widget.product!['_id']}).then((r) {
      if (mounted) setState(() => _rows = objs(r['data']));
    }, onError: ctx.fail);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ctx = widget.ctx;
    return MSheet(
      title: '${ctx.m('history')}${widget.product != null ? ' · ${widget.product!['name']}' : ''}',
      children: [
        if (_rows == null)
          const SkelList(rows: 5)
        else if (_rows!.isEmpty)
          Muted(ctx.m('noMoves'))
        else
          for (final x in _rows!)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Pill(
                      x['kind'] == 'waste' ? ctx.x('waste') : ctx.t.or('mart.moveKinds.${x['kind']}', str(x['kind'])),
                      tone: switch (str(x['kind'])) {
                        'in' => 'ok',
                        'sale' => 'info',
                        'void' => 'warn',
                        'waste' => 'bad',
                        _ => '',
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(str(x['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          [
                            mDayTime(x['created_date'], ctx.lang),
                            str(x['by']),
                            str(x['sale_no']),
                            '${str(x['supplier'])}${str(x['invoice_no']).isNotEmpty ? ' #${x['invoice_no']}' : ''}',
                            str(x['note']),
                          ].where((s) => s.trim().isNotEmpty).join(' · '),
                          style: TextStyle(color: c.muted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        n(x['qty']) > 0 ? '+${qtyOf(x['qty'])}' : qtyOf(x['qty']),
                        style: TextStyle(fontWeight: FontWeight.w800, color: n(x['qty']) < 0 ? c.danger : c.good),
                      ),
                      Text('→ ${qtyOf(x['stock_after'])}', style: TextStyle(color: c.muted, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------- Suppliers
class SuppliersTab extends StatefulWidget {
  final MartCtx ctx;
  const SuppliersTab({super.key, required this.ctx});
  @override
  State<SuppliersTab> createState() => _SuppliersTabState();
}

class _SuppliersTabState extends State<SuppliersTab> {
  List<Json>? _rows;
  MartCtx get ctx => widget.ctx;
  bool get _on => ctx.addonOn('mart_suppliers');

  @override
  void initState() {
    super.initState();
    if (_on) _load();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/suppliers');
      if (mounted) setState(() => _rows = objs(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _edit(Json row) async {
    final ok = await showSheet<bool>(context, (_) => _SupplierEditor(ctx: ctx, row: row));
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_on) {
      return MLocked(
        ctx: ctx,
        addon: 'mart_suppliers',
        icon: LucideIcons.truck,
        text: ctx.m('supLocked'),
        button: '${ctx.m('unlock', {'coins': fmt(n(ctx.addon('mart_suppliers')['price'] ?? 55))})} · ${ctx.m('forever')}',
      );
    }
    final c = context.c;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Panel(
            padding: const EdgeInsets.all(16),
            child: MHead(
              ctx.m('tabs.suppliers'),
              icon: LucideIcons.truck,
              sub: ctx.m('supSub'),
              trailing: Btn(ctx.m('addSupplier'), icon: LucideIcons.plus, small: true, onTap: ctx.readOnly ? null : () => _edit({})),
            ),
          ),
          mGap,
          if (_rows == null)
            const SkelList(rows: 3)
          else if (_rows!.isEmpty)
            Panel(child: Muted(ctx.m('noSuppliers'), align: TextAlign.center))
          else
            for (final x in _rows!)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  padding: const EdgeInsets.all(14),
                  onTap: () => showSheet<void>(
                    context,
                    (_) => _SupplierView(
                      ctx: ctx,
                      row: x,
                      onEdit: () {
                        Navigator.pop(context);
                        _edit(x);
                      },
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(12)),
                            child: Icon(LucideIcons.truck, size: 18, color: c.brandInk),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(str(x['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text(
                                  [str(x['contact']), str(x['phone'])].where((s) => s.isNotEmpty).join(' · ').isEmpty
                                      ? '—'
                                      : [str(x['contact']), str(x['phone'])].where((s) => s.isNotEmpty).join(' · '),
                                  style: TextStyle(color: c.muted, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                          Icon(LucideIcons.chevronRight, size: 16, color: c.muted),
                        ],
                      ),
                      if (str(x['note']).isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          str(x['note']),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.muted, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 14,
                        runSpacing: 4,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: '${ctx.m('deliveries')}: '),
                                TextSpan(
                                  text: '${n(x['deliveries'])}',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: '${ctx.m('spent')}: '),
                                TextSpan(
                                  text: money(x['spent'], ctx.cur),
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                          if (x['last'] != null) Text(ctx.m('lastDelivery', {'date': mDate(x['last'], ctx.lang)}), style: TextStyle(color: c.muted, fontSize: 12.5)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _SupplierEditor extends StatefulWidget {
  final MartCtx ctx;
  final Json row;
  const _SupplierEditor({required this.ctx, required this.row});
  @override
  State<_SupplierEditor> createState() => _SupplierEditorState();
}

class _SupplierEditorState extends State<_SupplierEditor> with SheetSave {
  late final _name = TextEditingController(text: str(widget.row['name'])),
      _contact = TextEditingController(text: str(widget.row['contact'])),
      _phone = TextEditingController(text: str(widget.row['phone']));
  late final _addr = TextEditingController(text: str(widget.row['address'])), _note = TextEditingController(text: str(widget.row['note']));
  @override
  MartCtx get mctx => widget.ctx;
  bool get _isNew => widget.row['_id'] == null;

  @override
  void dispose() {
    for (final x in [_name, _contact, _phone, _addr, _note]) {
      x.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final body = {'name': _name.text.trim(), 'contact': _contact.text.trim(), 'phone': _phone.text.trim(), 'address': _addr.text.trim(), 'note': _note.text.trim()};
    return MSheet(
      title: _isNew ? ctx.m('addSupplier') : ctx.m('editSupplier'),
      footer: [
        if (!_isNew) SureDelete(remove: ctx.m('remove'), sure: ctx.m('sure'), onDelete: busy ? null : () => save(() => ctx.api.delete('${ctx.base}/suppliers/${widget.row['_id']}'))),
        const Spacer(),
        Btn(ctx.m('cancel'), kind: BtnKind.ghost, small: true, onTap: busy ? null : () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(
          busy ? ctx.m('saving') : ctx.m('save'),
          small: true,
          busy: busy,
          onTap: busy || _name.text.trim().isEmpty ? null : () => save(() => _isNew ? ctx.api.post('${ctx.base}/suppliers', body) : ctx.api.put('${ctx.base}/suppliers/${widget.row['_id']}', body)),
        ),
      ],
      children: [
        Field(label: ctx.m('supName'), controller: _name, maxLength: 100, autofocus: _isNew, onChanged: (_) => setState(() {})),
        gap14,
        Field(label: ctx.m('supContact'), controller: _contact, maxLength: 80),
        gap14,
        Field(label: ctx.m('phone'), controller: _phone, maxLength: 40, keyboard: TextInputType.phone),
        gap14,
        Field(label: ctx.m('supAddress'), controller: _addr, maxLength: 300),
        gap14,
        Field(label: ctx.m('supNote'), controller: _note, maxLength: 1000, maxLines: 4),
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}

class _SupplierView extends StatefulWidget {
  final MartCtx ctx;
  final Json row;
  final VoidCallback onEdit;
  const _SupplierView({required this.ctx, required this.row, required this.onEdit});
  @override
  State<_SupplierView> createState() => _SupplierViewState();
}

class _SupplierViewState extends State<_SupplierView> {
  Json? _data;
  @override
  void initState() {
    super.initState();
    final ctx = widget.ctx;
    ctx.api.get('${ctx.base}/suppliers/${widget.row['_id']}').then((r) {
      if (mounted) setState(() => _data = obj(r['data']));
    }, onError: ctx.fail);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ctx = widget.ctx;
    final row = widget.row;
    Widget info(IconData i, String t, {VoidCallback? onTap}) => InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(i, size: 15, color: c.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t,
                style: TextStyle(color: onTap != null ? c.brand : c.ink, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
    final dels = objs(_data?['deliveries']);
    return MSheet(
      title: str(row['name']),
      footer: [if (!ctx.readOnly) Btn(ctx.m('editSupplier'), icon: LucideIcons.userRound, kind: BtnKind.ghost, small: true, onTap: widget.onEdit)],
      children: [
        if (str(row['contact']).isNotEmpty) info(LucideIcons.userRound, str(row['contact'])),
        if (str(row['phone']).isNotEmpty) info(LucideIcons.phone, str(row['phone']), onTap: () => launchUrl(Uri.parse('tel:${str(row['phone']).replaceAll(' ', '')}'))),
        if (str(row['address']).isNotEmpty) info(LucideIcons.mapPin, str(row['address'])),
        if (str(row['note']).isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(12)),
            child: Text(str(row['note'])),
          ),
        ],
        gap14,
        Text(ctx.m('deliveries'), style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        if (_data == null)
          const SkelList(rows: 3)
        else if (dels.isEmpty)
          Muted(ctx.m('noDeliveries'))
        else
          for (final d in dels)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(mDayTime(d['at'], ctx.lang), style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (str(d['invoice_no']).isNotEmpty) ...[const SizedBox(width: 6), Chip2('#${d['invoice_no']}')],
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(str(d['by']), style: TextStyle(color: c.muted, fontSize: 12.5)),
                      ),
                      Text(money(d['total'], ctx.cur), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${objs(d['items']).map((x) => '${qtyOf(x['qty'])}× ${x['name']}${n(x['cost']) > 0 ? ' @ ${money(x['cost'], ctx.cur)}' : ''}').join(' · ')}${str(d['note']).isNotEmpty ? ' — ${d['note']}' : ''}',
                    style: TextStyle(color: c.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
