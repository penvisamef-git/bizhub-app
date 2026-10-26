import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../restaurant/rest_common.dart' show SelectField, gap14;
import 'mart_common.dart';
import 'mart_kit.dart';

// Expiry dates (mart_expiry) + Purchase orders (mart_purchase) — the app version of MartExpiry.jsx and MartPurchase.jsx.
//   GET mart/expiry → { rows[{_id,name,photo,expires,left,note,state,days_left,value}], counts{expired,soon,ok,all}, days, at_risk, at_risk_sale }
//   GET mart/waste {month} → { rows, total }      GET mart/reorder → { groups, stock_on }      GET mart/po {status}

int _daysTo(String day) => DateTime.parse('${day}T00:00:00Z').difference(DateTime.parse('${todayKH()}T00:00:00Z')).inDays;

class ExpiryTab extends StatefulWidget {
  final MartCtx ctx;
  const ExpiryTab({super.key, required this.ctx});
  @override
  State<ExpiryTab> createState() => _ExpiryTabState();
}

class _ExpiryTabState extends State<ExpiryTab> {
  Json? _data, _waste;
  List<Json> _prods = [];
  String _show = 'soon', _month = todayKH().substring(0, 7);
  final _days = TextEditingController();
  MartCtx get ctx => widget.ctx;
  bool get _on => ctx.addonOn('mart_expiry');

  @override
  void initState() {
    super.initState();
    if (_on) {
      _load();
      _loadWaste();
      ctx.api.get('${ctx.base}/products').then((r) => _prods = objs(r['data']), onError: (_) {});
    }
  }

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/expiry');
      if (!mounted) return;
      setState(() {
        _data = obj(r['data']);
        _days.text = '${n(_data!['days'])}';
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _loadWaste() async {
    setState(() => _waste = null);
    try {
      final r = await ctx.api.get('${ctx.base}/waste', {'month': _month});
      if (mounted) setState(() => _waste = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  void _reload() {
    _load();
    _loadWaste();
  }

  Future<void> _open(Widget sheet) async {
    final ok = await showSheet<bool>(context, (_) => sheet);
    if (ok == true) _reload();
  }

  String _when(Json r) {
    final d = n(r['days_left']).toInt();
    if (d == -1) return ctx.x('yesterday');
    if (d == 1) return ctx.x('tomorrow');
    if (d < 0) return ctx.x('agoDays', {'n': -d});
    if (d == 0) return ctx.x('todayExp');
    return ctx.x('inDays', {'n': d});
  }

  @override
  Widget build(BuildContext context) {
    final head = MAddonHead(ctx: ctx, addon: 'mart_expiry', icon: LucideIcons.calendarX, title: ctx.x('expTitle'), sub: ctx.x('expSub'), perks: ctx.t.list('mx.expPerks'));
    if (!_on) {
      return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [head]);
    }
    final c = context.c;
    final data = _data;
    final counts = obj(data?['counts']);
    final rows = objs(data?['rows']).where((r) => _show == 'all' || (_show == 'expired' ? r['state'] == 'expired' : r['state'] != 'ok')).toList();
    final waste = _waste;
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          head,
          mGap,
          Panel(
            padding: const EdgeInsets.all(16),
            child: data == null
                ? const SkelList(rows: 3)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Tiles([
                        ('${n(counts['expired'])}', ctx.x('expired'), n(counts['expired']) > 0 ? c.danger : null),
                        ('${n(counts['soon'])}', ctx.x('soon'), n(counts['soon']) > 0 ? c.warn : null),
                        (money(data['at_risk'], ctx.cur), ctx.x('atRisk'), null),
                        (money(data['at_risk_sale'], ctx.cur), ctx.x('atRiskSale'), null),
                      ]),
                      const SizedBox(height: 6),
                      Muted('${ctx.x('okLeft')}: ${n(counts['ok'])}'),
                      gap14,
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final (k, label) in [
                              ('soon', '${ctx.x('sellFirst')} (${n(counts['expired']) + n(counts['soon'])})'),
                              ('expired', '${ctx.x('expired')} (${n(counts['expired'])})'),
                              ('all', '${ctx.x('all')} (${n(counts['all'])})'),
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(label),
                                  selected: _show == k,
                                  showCheckmark: false,
                                  onSelected: (_) => setState(() => _show = k),
                                  selectedColor: c.active,
                                  labelStyle: TextStyle(fontWeight: FontWeight.w700, color: _show == k ? c.brandInk : c.ink),
                                  side: BorderSide(color: _show == k ? c.brand : c.line),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(ctx.x('warnDays'), style: TextStyle(color: c.muted, fontSize: 13)),
                          ),
                          SizedBox(
                            width: 80,
                            child: Focus(
                              onFocusChange: (on) async {
                                final v = int.tryParse(_days.text) ?? 0;
                                if (on || v == n(data['days']) || v < 1 || v > 365) return;
                                try {
                                  await ctx.api.put('${ctx.base}/expiry/settings', {'days': v});
                                  ctx.notify(ctx.x('saved'));
                                  _load();
                                } catch (e) {
                                  ctx.fail(e);
                                }
                              },
                              child: Field(controller: _days, keyboard: TextInputType.number, align: TextAlign.center, enabled: !ctx.readOnly),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(ctx.x('warnDaysUnit'), style: TextStyle(color: c.muted, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Btn(
                        ctx.x('addExpiry'),
                        icon: LucideIcons.plus,
                        small: true,
                        onTap: ctx.readOnly ? null : () => _open(_AddBatch(ctx: ctx, products: _prods)),
                      ),
                      const SizedBox(height: 8),
                      Muted(ctx.x('expHint')),
                      const SizedBox(height: 8),
                      if (rows.isEmpty)
                        Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Muted(n(counts['all']) > 0 ? ctx.x('none') : ctx.x('noBatches')))
                      else
                        for (final (i, r) in rows.indexed) ...[
                          if (i > 0) Divider(height: 1, color: c.line),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(12)),
                                      clipBehavior: Clip.antiAlias,
                                      child: str(r['photo']).isNotEmpty
                                          ? Image(image: netImage(str(r['photo'])), fit: BoxFit.cover, width: 40, height: 40, errorBuilder: (_, _, _) => const SizedBox.shrink())
                                          : Text(
                                              str(r['name']).characters.take(2).toString(),
                                              style: TextStyle(fontWeight: FontWeight.w800, color: c.muted),
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(str(r['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                                          Text(
                                            '${ctx.x('expires')} ${mDay(str(r['expires']), ctx.lang)} ${str(r['expires']).substring(0, 4)} · ${ctx.x('left')} ${qtyOf(r['left'])}${str(r['note']).isNotEmpty ? ' · ${r['note']}' : ''}',
                                            style: TextStyle(color: c.muted, fontSize: 12.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Pill(
                                          _when(r),
                                          tone: r['state'] == 'expired'
                                              ? 'bad'
                                              : r['state'] == 'soon'
                                              ? 'warn'
                                              : 'ok',
                                        ),
                                        const SizedBox(height: 4),
                                        Text(money(r['value'], ctx.cur), style: const TextStyle(fontWeight: FontWeight.w800)),
                                      ],
                                    ),
                                  ],
                                ),
                                if (!ctx.readOnly) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Btn(
                                        ctx.x('waste'),
                                        icon: LucideIcons.trash2,
                                        kind: BtnKind.ghost,
                                        small: true,
                                        onTap: () => _open(_WasteSheet(ctx: ctx, row: r, products: _prods)),
                                      ),
                                      const SizedBox(width: 6),
                                      Btn(
                                        ctx.x('edit'),
                                        icon: LucideIcons.pencil,
                                        kind: BtnKind.ghost,
                                        small: true,
                                        onTap: () => _open(_EditBatch(ctx: ctx, row: r)),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                    ],
                  ),
          ),
          mGap,
          mCard(
            context,
            ctx.x('wasteRecord'),
            [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      _month = prevMonth(_month);
                      _loadWaste();
                    },
                    icon: const Icon(LucideIcons.chevronLeft, size: 18),
                  ),
                  Expanded(
                    child: Text(
                      monthName(_month, ctx.lang),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: _month == todayKH().substring(0, 7)
                        ? null
                        : () {
                            final y = int.parse(_month.substring(0, 4)), m = int.parse(_month.substring(5, 7));
                            _month = m == 12 ? '${y + 1}-01' : '$y-${(m + 1).toString().padLeft(2, '0')}';
                            _loadWaste();
                          },
                    icon: const Icon(LucideIcons.chevronRight, size: 18),
                  ),
                ],
              ),
              if (waste == null)
                const SkelList(rows: 2)
              else if (objs(waste['rows']).isEmpty)
                Muted(ctx.x('noWaste'))
              else ...[
                Text(ctx.x('wasteTotal', {'amt': money(waste['total'], ctx.cur)}), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                for (final w in objs(waste['rows']))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${qtyOf(w['qty'])}× ${w['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text([mDayTime(w['created_date'], ctx.lang), str(w['note']), str(w['by'])].where((s) => s.isNotEmpty).join(' · '), style: TextStyle(color: c.muted, fontSize: 12.5)),
                            ],
                          ),
                        ),
                        Text(money(w['value'], ctx.cur), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
              ],
            ],
            trailing: Btn(
              ctx.x('wasteOther'),
              icon: LucideIcons.trash2,
              kind: BtnKind.ghost,
              small: true,
              onTap: ctx.readOnly ? null : () => _open(_WasteSheet(ctx: ctx, row: const {'free': true}, products: _prods)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddBatch extends StatefulWidget {
  final MartCtx ctx;
  final List<Json> products;
  const _AddBatch({required this.ctx, required this.products});
  @override
  State<_AddBatch> createState() => _AddBatchState();
}

class _AddBatchState extends State<_AddBatch> with SheetSave {
  Json? _p;
  String _exp = '';
  final _qty = TextEditingController(), _note = TextEditingController();
  @override
  MartCtx get mctx => widget.ctx;

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final ok = _p != null && (numOf(_qty.text) ?? 0) > 0 && _exp.isNotEmpty;
    final d = _exp.isEmpty ? 0 : _daysTo(_exp);
    return MSheet(
      title: ctx.x('addExpiry'),
      footer: [
        const Spacer(),
        Btn(ctx.x('cancel'), kind: BtnKind.ghost, small: true, onTap: busy ? null : () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(
          busy ? ctx.x('saving') : ctx.x('save'),
          small: true,
          busy: busy,
          onTap: !ok || busy
              ? null
              : () => save(() => ctx.api.post('${ctx.base}/expiry', {'product_id': _p!['_id'], 'qty': numOf(_qty.text), 'expires': _exp, 'note': _note.text.trim()}), ok: ctx.x('saved')),
        ),
      ],
      children: [
        ProductField(
          ctx: ctx,
          label: ctx.x('product'),
          value: _p,
          onTap: () async {
            final p = await pickProduct(context, ctx, widget.products);
            if (p != null) setState(() => _p = p);
          },
        ),
        gap14,
        Field(label: ctx.x('qty'), controller: _qty, keyboard: decimalKeys, onChanged: (_) => setState(() {})),
        gap14,
        DayField(label: ctx.x('expires'), value: _exp, onChanged: (v) => setState(() => _exp = v)),
        if (_exp.isNotEmpty) ...[
          const SizedBox(height: 4),
          Muted(d < 0 ? ctx.x('agoDays', {'n': -d}) : ctx.x('inDays', {'n': d})),
        ],
        gap14,
        Field(label: ctx.x('note'), controller: _note, maxLength: 200),
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}

class _EditBatch extends StatefulWidget {
  final MartCtx ctx;
  final Json row;
  const _EditBatch({required this.ctx, required this.row});
  @override
  State<_EditBatch> createState() => _EditBatchState();
}

class _EditBatchState extends State<_EditBatch> with SheetSave {
  late final _left = TextEditingController(text: qtyOf(widget.row['left'])), _note = TextEditingController(text: str(widget.row['note']));
  late String _exp = str(widget.row['expires']);
  @override
  MartCtx get mctx => widget.ctx;

  @override
  void dispose() {
    _left.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final path = '${ctx.base}/expiry/${widget.row['_id']}';
    return MSheet(
      title: '${ctx.x('batchEdit')} · ${widget.row['name']}',
      footer: [
        SureDelete(remove: ctx.x('remove'), sure: ctx.x('sure'), onDelete: busy ? null : () => save(() => ctx.api.delete(path))),
        const Spacer(),
        Btn(ctx.x('cancel'), kind: BtnKind.ghost, small: true, onTap: busy ? null : () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(
          busy ? ctx.x('saving') : ctx.x('save'),
          small: true,
          busy: busy,
          onTap: busy || _exp.isEmpty ? null : () => save(() => ctx.api.put(path, {'left': numOf(_left.text) ?? 0, 'expires': _exp, 'note': _note.text.trim()})),
        ),
      ],
      children: [
        Field(label: ctx.x('left'), controller: _left, keyboard: decimalKeys),
        gap14,
        DayField(label: ctx.x('expires'), value: _exp, onChanged: (v) => setState(() => _exp = v)),
        gap14,
        Field(label: ctx.x('note'), controller: _note, maxLength: 200),
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}

class _WasteSheet extends StatefulWidget {
  final MartCtx ctx;
  final Json row; // a batch, or {free: true} for any product
  final List<Json> products;
  const _WasteSheet({required this.ctx, required this.row, required this.products});
  @override
  State<_WasteSheet> createState() => _WasteSheetState();
}

class _WasteSheetState extends State<_WasteSheet> with SheetSave {
  late final bool free = widget.row['free'] == true;
  late final _qty = TextEditingController(text: free ? '' : qtyOf(widget.row['left']));
  late final _reasons = widget.ctx.t.list('mx.wasteReasons');
  late final _reason = TextEditingController(text: _reasons.length > 1 ? (free ? _reasons[1] : _reasons[0]) : '');
  Json? _p;
  @override
  MartCtx get mctx => widget.ctx;

  @override
  void dispose() {
    _qty.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ctx = widget.ctx;
    final q = numOf(_qty.text) ?? 0;
    final ok = q > 0 && (free ? _p != null : q <= n(widget.row['left']) + 1e-9);
    return MSheet(
      title: ctx.x('wasteTitle', {'name': free ? '' : str(widget.row['name'])}),
      footer: [
        const Spacer(),
        Btn(ctx.x('cancel'), kind: BtnKind.ghost, small: true, onTap: busy ? null : () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(
          ctx.x('waste'),
          icon: LucideIcons.trash2,
          kind: BtnKind.danger,
          small: true,
          busy: busy,
          onTap: !ok || busy
              ? null
              : () => save(
                  () => free
                      ? ctx.api.post('${ctx.base}/waste', {'product_id': _p!['_id'], 'qty': q, 'reason': _reason.text.trim()})
                      : ctx.api.post('${ctx.base}/expiry/${widget.row['_id']}/waste', {'qty': q, 'reason': _reason.text.trim()}),
                  ok: ctx.x('wasteDone'),
                ),
        ),
      ],
      children: [
        if (free) ...[
          ProductField(
            ctx: ctx,
            label: ctx.x('product'),
            value: _p,
            onTap: () async {
              final p = await pickProduct(context, ctx, widget.products);
              if (p != null) setState(() => _p = p);
            },
          ),
          gap14,
        ],
        Field(label: '${ctx.x('qty')}${free ? '' : ' (${ctx.x('left')} ${qtyOf(widget.row['left'])})'}', controller: _qty, keyboard: decimalKeys, autofocus: !free, onChanged: (_) => setState(() {})),
        gap14,
        Text(ctx.x('wasteReason'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final r in _reasons)
              ChoiceChip(
                label: Text(r),
                selected: _reason.text == r,
                showCheckmark: false,
                onSelected: (_) => setState(() => _reason.text = r),
                selectedColor: c.active,
                side: BorderSide(color: _reason.text == r ? c.brand : c.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Field(controller: _reason, maxLength: 200, onChanged: (_) => setState(() {})),
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------- Purchase orders
const _tone = {'draft': '', 'sent': 'info', 'partial': 'warn', 'received': 'ok', 'cancelled': 'bad'};

class PurchaseTab extends StatefulWidget {
  final MartCtx ctx;
  const PurchaseTab({super.key, required this.ctx});
  @override
  State<PurchaseTab> createState() => _PurchaseTabState();
}

class _PurchaseTabState extends State<PurchaseTab> {
  Json? _re;
  List<Json>? _pos;
  List<Json> _prods = [], _sups = [];
  String _status = 'open';
  MartCtx get ctx => widget.ctx;
  bool get _on => ctx.addonOn('mart_purchase');

  @override
  void initState() {
    super.initState();
    if (_on) {
      _reload();
      ctx.api.get('${ctx.base}/products').then((r) => _prods = objs(r['data']), onError: (_) {});
      ctx.api.get('${ctx.base}/suppliers').then((r) => _sups = objs(r['data']), onError: (_) {});
    }
  }

  Future<void> _reload() async {
    try {
      final r = await Future.wait([
        ctx.api.get('${ctx.base}/reorder'),
        ctx.api.get('${ctx.base}/po', {'status': _status}),
      ]);
      if (!mounted) return;
      setState(() {
        _re = obj(r[0]['data']);
        _pos = objs(r[1]['data']);
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _edit(Json po) async {
    final ok = await showSheet<bool>(context, (_) => _PoEdit(ctx: ctx, po: po, products: _prods, sups: _sups));
    if (ok == true) _reload();
  }

  Future<void> _view(Json po) async {
    final r = await showSheet<Object>(context, (_) => _PoView(ctx: ctx, po: po, stockOn: _re?['stock_on'] == true, onChanged: _reload));
    if (!mounted) return;
    if (r is Map && r['edit'] != null) _edit(obj(r['edit']));
    if (r is Map && r['receive'] != null) {
      final ok = await showSheet<bool>(context, (_) => _PoReceive(ctx: ctx, po: obj(r['receive'])));
      if (ok == true) _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final head = MAddonHead(
      ctx: ctx,
      addon: 'mart_purchase',
      icon: LucideIcons.clipboardCheck,
      title: ctx.x('purTitle'),
      sub: ctx.x('purSub'),
      perks: ctx.t.list('mx.purPerks'),
      yearly: false,
      action: Btn(ctx.x('makePo'), icon: LucideIcons.plus, small: true, onTap: ctx.readOnly ? null : () => _edit({'items': []})),
    );
    if (!_on) return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [head]);
    final c = context.c;
    final groups = objs(_re?['groups']);
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          head,
          mGap,
          mCard(context, ctx.x('reorder'), sub: ctx.x('reorderSub'), [
            if (_re == null)
              const SkelList(rows: 3)
            else if (groups.isEmpty)
              Muted(ctx.x('noReorder'))
            else
              for (final g in groups)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
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
                          Icon(LucideIcons.truck, size: 16, color: c.brand),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(str(g['supplier']).isEmpty ? ctx.x('noSupplier') : str(g['supplier']), style: const TextStyle(fontWeight: FontWeight.w800)),
                                if (str(g['phone']).isNotEmpty) Text(str(g['phone']), style: TextStyle(color: c.muted, fontSize: 12.5)),
                              ],
                            ),
                          ),
                          Btn(
                            ctx.x('makePo'),
                            icon: LucideIcons.plus,
                            small: true,
                            onTap: ctx.readOnly
                                ? null
                                : () => _edit({
                                    'supplier_id': g['supplier_id'] ?? '',
                                    'items': [
                                      for (final i in objs(g['items'])) {'product_id': i['product_id'], 'name': i['name'], 'qty': i['qty'], 'cost': i['cost']},
                                    ],
                                  }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      for (final i in objs(g['items']))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(str(i['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text(
                                      '${ctx.x('stockNow', {'n': qtyOf(i['stock'])})} · ${ctx.x('lowAt', {'n': qtyOf(i['low_stock'])})}${n(i['coming']) > 0 ? ' · ${ctx.x('coming', {'n': qtyOf(i['coming'])})}' : ''}',
                                      style: TextStyle(color: c.muted, fontSize: 12.5),
                                    ),
                                  ],
                                ),
                              ),
                              Pill(qtyOf(i['stock']), tone: n(i['stock']) <= 0 ? 'bad' : 'warn'),
                              const SizedBox(width: 10),
                              Text('+${qtyOf(i['qty'])}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
          ]),
          mGap,
          mCard(context, ctx.x('orders'), [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final k in ['open', 'received', 'cancelled', 'all'])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(k == 'open' ? ctx.x('open') : (k == 'all' ? ctx.x('all') : ctx.x('poStatus.$k'))),
                        selected: _status == k,
                        showCheckmark: false,
                        onSelected: (_) {
                          setState(() {
                            _status = k;
                            _pos = null;
                          });
                          _reload();
                        },
                        selectedColor: c.active,
                        labelStyle: TextStyle(fontWeight: FontWeight.w700, color: _status == k ? c.brandInk : c.ink),
                        side: BorderSide(color: _status == k ? c.brand : c.line),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_pos == null)
              const SkelList(rows: 3)
            else if (_pos!.isEmpty)
              Muted(ctx.x('noPos'))
            else
              for (final po in _pos!)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _view(po),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(12)),
                          child: Icon(LucideIcons.clipboardCheck, size: 18, color: c.muted),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${po['no']} · ${str(po['supplier_name']).isEmpty ? ctx.x('noSupplier') : po['supplier_name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                '${mDate(po['created_date'], ctx.lang)} · ${objs(po['items']).length} × · ${objs(po['items']).take(3).map((i) => i['name']).join(', ')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: c.muted, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Pill(ctx.x('poStatus.${po['status']}'), tone: _tone[po['status']] ?? ''),
                            const SizedBox(height: 4),
                            Text(money(po['total'], ctx.cur), style: const TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ]),
        ],
      ),
    );
  }
}

class _PoLine {
  final String id, name;
  final qty = TextEditingController(), cost = TextEditingController();
  String expires = '';
  _PoLine(this.id, this.name, Object? q, Object? c) {
    qty.text = qtyOf(q);
    cost.text = qtyOf(c ?? 0);
  }
  void dispose() {
    qty.dispose();
    cost.dispose();
  }
}

class _PoEdit extends StatefulWidget {
  final MartCtx ctx;
  final Json po;
  final List<Json> products, sups;
  const _PoEdit({required this.ctx, required this.po, required this.products, required this.sups});
  @override
  State<_PoEdit> createState() => _PoEditState();
}

class _PoEditState extends State<_PoEdit> with SheetSave {
  late String _sup = str(widget.po['supplier_id']);
  late final List<_PoLine> _items = [for (final i in objs(widget.po['items'])) _PoLine(str(i['product_id']), str(i['name']), i['qty'], i['cost'])];
  late final _note = TextEditingController(text: str(widget.po['note']));
  @override
  MartCtx get mctx => widget.ctx;

  @override
  void dispose() {
    for (final l in _items) {
      l.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ctx = widget.ctx;
    final total = _items.fold<num>(0, (a, i) => a + (numOf(i.qty.text) ?? 0) * (numOf(i.cost.text) ?? 0));
    final lines = _items.where((i) => (numOf(i.qty.text) ?? 0) > 0).toList();
    final body = {
      'supplier_id': _sup.isEmpty ? null : _sup,
      'note': _note.text.trim(),
      'items': [
        for (final i in lines) {'product_id': i.id, 'qty': numOf(i.qty.text), 'cost': numOf(i.cost.text) ?? 0},
      ],
    };
    final id = widget.po['_id'];
    // the supplier on the PO may not be in the list any more
    final sups = [('', ctx.x('noSupplier')), for (final s in widget.sups) (str(s['_id']), str(s['name']))];
    if (!sups.any((s) => s.$1 == _sup)) _sup = '';
    return MSheet(
      title: id != null ? str(widget.po['no']) : ctx.x('makePo'),
      footer: [
        Expanded(
          child: Text('${ctx.x('total')}: ${money(total, ctx.cur)}', style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        Btn(ctx.x('cancel'), kind: BtnKind.ghost, small: true, onTap: busy ? null : () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(
          busy ? ctx.x('saving') : ctx.x('save'),
          small: true,
          busy: busy,
          onTap: busy || lines.isEmpty ? null : () => save(() => id != null ? ctx.api.put('${ctx.base}/po/$id', body) : ctx.api.post('${ctx.base}/po', body), ok: ctx.x('saved')),
        ),
      ],
      children: [
        SelectField<String>(label: ctx.x('supplier'), value: _sup, options: sups, onChanged: (v) => setState(() => _sup = v)),
        gap14,
        for (final i in _items)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
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
                      child: Text(i.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    RoundBtn(
                      LucideIcons.x,
                      size: 32,
                      onTap: () => setState(() {
                        _items.remove(i);
                        i.dispose();
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Field(label: ctx.x('qty'), controller: i.qty, keyboard: decimalKeys, onChanged: (_) => setState(() {})),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Field(label: ctx.x('cost'), controller: i.cost, keyboard: decimalKeys, onChanged: (_) => setState(() {})),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Btn(
          ctx.x('addLine'),
          icon: LucideIcons.plus,
          kind: BtnKind.ghost,
          expand: true,
          onTap: () async {
            final p = await pickProduct(context, ctx, widget.products, exclude: _items.map((i) => i.id).toSet());
            if (p != null) setState(() => _items.add(_PoLine(str(p['_id']), str(p['name']), 1, p['cost'] ?? 0)));
          },
        ),
        gap14,
        Field(label: ctx.x('note'), controller: _note, maxLength: 500),
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}

class _PoView extends StatefulWidget {
  final MartCtx ctx;
  final Json po;
  final bool stockOn;
  final VoidCallback onChanged;
  const _PoView({required this.ctx, required this.po, required this.stockOn, required this.onChanged});
  @override
  State<_PoView> createState() => _PoViewState();
}

class _PoViewState extends State<_PoView> {
  late Json _row = widget.po;
  bool _busy = false;
  MartCtx get ctx => widget.ctx;

  String get _text => ctx.x('poText', {
    'no': _row['no'],
    'shop': str(ctx.business['name']),
    'date': mDate(_row['created_date'], ctx.lang),
    'lines': objs(_row['items']).map((i) => '• ${i['name']} × ${qtyOf(i['qty'])}${n(i['cost']) > 0 ? ' @ ${money(i['cost'], ctx.cur)}' : ''}').join('\n'),
    'total': money(_row['total'], ctx.cur),
    'note': str(_row['note']).isNotEmpty ? '\n${_row['note']}' : '',
  });

  Future<void> _act(Future<Json> Function() fn, {bool close = false}) async {
    setState(() => _busy = true);
    try {
      final r = await fn();
      if (r['data'] is Map) _row = obj(r['data']);
      widget.onChanged();
      if (close && mounted) Navigator.pop(context);
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _sent() {
    if (_row['status'] == 'draft') _act(() => ctx.api.post('${ctx.base}/po/${_row['_id']}/send'));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final status = str(_row['status']);
    final open = ['draft', 'sent', 'partial'].contains(status);
    return MSheet(
      title: '${_row['no']} · ${ctx.x('poStatus.$status')}',
      footer: [
        if (status == 'draft')
          Btn(
            ctx.x('deletePo'),
            icon: LucideIcons.trash2,
            kind: BtnKind.ghost,
            small: true,
            onTap: _busy || ctx.readOnly ? null : () => _act(() => ctx.api.delete('${ctx.base}/po/${_row['_id']}'), close: true),
          ),
        if (open && status != 'draft')
          Btn(ctx.x('cancelPo'), kind: BtnKind.ghost, small: true, onTap: _busy || ctx.readOnly ? null : () => _act(() => ctx.api.post('${ctx.base}/po/${_row['_id']}/cancel'))),
        const Spacer(),
        if (status == 'draft' || status == 'sent') Btn(ctx.x('edit'), kind: BtnKind.ghost, small: true, onTap: _busy || ctx.readOnly ? null : () => Navigator.pop(context, {'edit': _row})),
        if (open) ...[
          const SizedBox(width: 8),
          Btn(ctx.x('receive'), icon: LucideIcons.packageCheck, small: true, onTap: _busy || ctx.readOnly || !widget.stockOn ? null : () => Navigator.pop(context, {'receive': _row})),
        ],
      ],
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Chip2(str(_row['supplier_name']).isEmpty ? ctx.x('noSupplier') : str(_row['supplier_name']), icon: LucideIcons.truck),
            Chip2(mDate(_row['created_date'], ctx.lang)),
            if (str(_row['invoice_no']).isNotEmpty) Chip2('${ctx.x('invoiceNo')} ${_row['invoice_no']}'),
          ],
        ),
        gap14,
        Row(
          children: [
            Expanded(
              child: Text(
                ctx.x('product'),
                style: TextStyle(color: c.muted, fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
            SizedBox(
              width: 58,
              child: Text(
                ctx.x('ordered'),
                textAlign: TextAlign.right,
                style: TextStyle(color: c.muted, fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
            SizedBox(
              width: 62,
              child: Text(
                ctx.x('received'),
                textAlign: TextAlign.right,
                style: TextStyle(color: c.muted, fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
            SizedBox(
              width: 64,
              child: Text(
                ctx.x('cost'),
                textAlign: TextAlign.right,
                style: TextStyle(color: c.muted, fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
          ],
        ),
        Divider(color: c.line),
        for (final i in objs(_row['items']))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: Text(str(i['name']), style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                SizedBox(width: 58, child: Text(qtyOf(i['qty']), textAlign: TextAlign.right)),
                SizedBox(width: 62, child: Text(qtyOf(i['received'] ?? 0), textAlign: TextAlign.right)),
                SizedBox(width: 64, child: Text(money(i['cost'], ctx.cur), textAlign: TextAlign.right)),
              ],
            ),
          ),
        Divider(color: c.line),
        Align(
          alignment: Alignment.centerRight,
          child: Text('${ctx.x('total')}: ${money(_row['total'], ctx.cur)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
        if (str(_row['note']).isNotEmpty) ...[const SizedBox(height: 6), Muted(str(_row['note']))],
        if (!widget.stockOn && open) ...[const SizedBox(height: 6), Muted(ctx.x('needStock'))],
        gap14,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Btn(
              ctx.x('sendTg'),
              icon: LucideIcons.send,
              small: true,
              onTap: _busy
                  ? null
                  : () {
                      launchUrl(Uri.parse('https://t.me/share/url?url=${Uri.encodeComponent(' ')}&text=${Uri.encodeComponent(_text)}'), mode: LaunchMode.externalApplication);
                      _sent();
                    },
            ),
            Btn(
              ctx.x('copy'),
              icon: LucideIcons.copy,
              kind: BtnKind.ghost,
              small: true,
              onTap: _busy
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: _text));
                      ctx.notify(ctx.x('copied'));
                      _sent();
                    },
            ),
            Btn(
              ctx.t('app.share'),
              icon: LucideIcons.share2,
              kind: BtnKind.ghost,
              small: true,
              onTap: _busy
                  ? null
                  : () async {
                      await SharePlus.instance.share(ShareParams(text: _text));
                      _sent();
                    },
            ),
          ],
        ),
      ],
    );
  }
}

class _PoReceive extends StatefulWidget {
  final MartCtx ctx;
  final Json po;
  const _PoReceive({required this.ctx, required this.po});
  @override
  State<_PoReceive> createState() => _PoReceiveState();
}

class _PoReceiveState extends State<_PoReceive> with SheetSave {
  late final List<_PoLine> _lines = [
    for (final i in objs(widget.po['items']))
      _PoLine(str(i['product_id']), str(i['name']), ((n(i['qty']) - n(i['received'])) * 1000).round() / 1000 < 0 ? 0 : ((n(i['qty']) - n(i['received'])) * 1000).round() / 1000, i['cost']),
  ];
  final _inv = TextEditingController();
  @override
  MartCtx get mctx => widget.ctx;

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    _inv.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ctx = widget.ctx;
    final expOn = ctx.addonOn('mart_expiry');
    final items = [
      for (final l in _lines)
        if ((numOf(l.qty.text) ?? 0) > 0) {'product_id': l.id, 'qty': numOf(l.qty.text), 'cost': numOf(l.cost.text) ?? 0, if (l.expires.isNotEmpty) 'expires': l.expires},
    ];
    return MSheet(
      title: ctx.x('receiveTitle', {'no': widget.po['no']}),
      footer: [
        const Spacer(),
        Btn(ctx.x('cancel'), kind: BtnKind.ghost, small: true, onTap: busy ? null : () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(
          ctx.x('receive'),
          icon: LucideIcons.packageCheck,
          small: true,
          busy: busy,
          onTap: busy || items.isEmpty ? null : () => save(() => ctx.api.post('${ctx.base}/po/${widget.po['_id']}/receive', {'invoice_no': _inv.text.trim(), 'items': items}), ok: ctx.x('saved')),
        ),
      ],
      children: [
        for (final l in _lines)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: c.line),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Field(label: ctx.x('received'), controller: l.qty, keyboard: decimalKeys, onChanged: (_) => setState(() {})),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Field(label: ctx.x('cost'), controller: l.cost, keyboard: decimalKeys),
                    ),
                  ],
                ),
                if (expOn) ...[const SizedBox(height: 10), DayField(label: ctx.x('expiryOpt'), value: l.expires, onChanged: (v) => setState(() => l.expires = v))],
              ],
            ),
          ),
        Field(label: ctx.x('invoiceNo'), controller: _inv, maxLength: 60),
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}
