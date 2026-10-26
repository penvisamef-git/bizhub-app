import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/color_pick.dart' show hexToColor;
import '../../widgets/ui.dart';
import '../restaurant/rest_common.dart' show Segmented, gap14;
import 'mart_common.dart';
import 'mart_kit.dart';

// Debt book (mart_debt) + Profit (mart_profit) — the app version of MartDebt.jsx and MartProfit.jsx.
//   GET mart/debtors {q} → { rows[{_id,name,phone,note,balance}], totals{owed,people} }      GET mart/debtors/:id → { balance, txs }
//   POST mart/debtors/:id/payments { amount, method, note }
//   GET mart/profit {day | month} → { kind, totals, series, products, categories, low_margin, no_cost }

class DebtTab extends StatefulWidget {
  final MartCtx ctx;
  const DebtTab({super.key, required this.ctx});
  @override
  State<DebtTab> createState() => _DebtTabState();
}

class _DebtTabState extends State<DebtTab> {
  Json? _data;
  final _q = TextEditingController();
  Timer? _wait;
  MartCtx get ctx => widget.ctx;
  bool get _on => ctx.addonOn('mart_debt');

  @override
  void initState() {
    super.initState();
    if (_on) _load();
  }

  @override
  void dispose() {
    _wait?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/debtors', {'q': _q.text.trim()});
      if (mounted) setState(() => _data = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _open(Widget sheet) async {
    final ok = await showSheet<bool>(context, (_) => sheet);
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_on) {
      return MLocked(
        ctx: ctx,
        addon: 'mart_debt',
        icon: LucideIcons.handCoins,
        text: ctx.m('debtLocked'),
        button: '${ctx.m('unlock', {'coins': fmt(n(ctx.addon('mart_debt')['price'] ?? 50))})} ${ctx.m('perYear')}',
      );
    }
    final c = context.c;
    final data = _data;
    final totals = obj(data?['totals']);
    final rows = objs(data?['rows']);
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
                MHead(
                  ctx.m('tabs.debt'),
                  icon: LucideIcons.handCoins,
                  sub: ctx.m('debtSub'),
                  trailing: Btn(
                    ctx.m('addDebtor'),
                    icon: LucideIcons.plus,
                    small: true,
                    onTap: ctx.readOnly || data == null ? null : () => _open(_DebtorEditor(ctx: ctx, row: const {})),
                  ),
                ),
                if (data != null) Tiles([(money(totals['owed'], ctx.cur), ctx.m('totalOwed'), n(totals['owed']) > 0 ? c.danger : null), ('${n(totals['people'])}', ctx.m('debtPeople'), null)]),
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
                  hint: ctx.m('debtSearch'),
                  icon: LucideIcons.search,
                  onChanged: (_) {
                    _wait?.cancel();
                    _wait = Timer(const Duration(milliseconds: 350), _load);
                  },
                ),
                const SizedBox(height: 6),
                if (data == null)
                  const SkelList(rows: 4)
                else if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Muted(ctx.m('noDebtors'), align: TextAlign.center),
                  )
                else
                  for (final (i, d) in rows.indexed) ...[
                    if (i > 0) Divider(height: 1, color: c.line),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 19,
                                backgroundColor: c.active,
                                child: Icon(LucideIcons.userRound, size: 18, color: c.brandInk),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(str(d['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text([str(d['phone']).isEmpty ? '—' : str(d['phone']), str(d['note'])].where((s) => s.isNotEmpty).join(' · '), style: TextStyle(color: c.muted, fontSize: 12.5)),
                                  ],
                                ),
                              ),
                              n(d['balance']) > 0
                                  ? Text(
                                      money(d['balance'], ctx.cur),
                                      style: TextStyle(fontWeight: FontWeight.w800, color: c.danger),
                                    )
                                  : Pill(ctx.m('clear2'), tone: 'ok'),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (n(d['balance']) > 0 && !ctx.readOnly)
                                Btn(
                                  ctx.m('repay'),
                                  icon: LucideIcons.handCoins,
                                  small: true,
                                  onTap: () => _open(_RepaySheet(ctx: ctx, d: d)),
                                ),
                              Btn(
                                ctx.m('editDebtor'),
                                icon: LucideIcons.userRound,
                                kind: BtnKind.ghost,
                                small: true,
                                onTap: ctx.readOnly ? null : () => _open(_DebtorEditor(ctx: ctx, row: d)),
                              ),
                              Btn(
                                ctx.m('debtHistory'),
                                icon: LucideIcons.history,
                                kind: BtnKind.ghost,
                                small: true,
                                onTap: () => showSheet<void>(context, (_) => _DebtHistory(ctx: ctx, d: d)),
                              ),
                              if (str(d['phone']).isNotEmpty) RoundBtn(LucideIcons.phone, size: 36, onTap: () => launchUrl(Uri.parse('tel:${str(d['phone']).replaceAll(' ', '')}'))),
                            ],
                          ),
                        ],
                      ),
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

class _DebtorEditor extends StatefulWidget {
  final MartCtx ctx;
  final Json row;
  const _DebtorEditor({required this.ctx, required this.row});
  @override
  State<_DebtorEditor> createState() => _DebtorEditorState();
}

class _DebtorEditorState extends State<_DebtorEditor> with SheetSave {
  late final _name = TextEditingController(text: str(widget.row['name'])), _phone = TextEditingController(text: str(widget.row['phone'])), _note = TextEditingController(text: str(widget.row['note']));
  @override
  MartCtx get mctx => widget.ctx;
  bool get _isNew => widget.row['_id'] == null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final body = {'name': _name.text.trim(), 'phone': _phone.text.trim(), 'note': _note.text.trim()};
    return MSheet(
      title: _isNew ? ctx.m('addDebtor') : ctx.m('editDebtor'),
      footer: [
        if (!_isNew) SureDelete(remove: ctx.m('remove'), sure: ctx.m('sure'), onDelete: busy ? null : () => save(() => ctx.api.delete('${ctx.base}/debtors/${widget.row['_id']}'))),
        const Spacer(),
        Btn(ctx.m('cancel'), kind: BtnKind.ghost, small: true, onTap: busy ? null : () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(
          busy ? ctx.m('saving') : ctx.m('save'),
          small: true,
          busy: busy,
          onTap: busy || _name.text.trim().isEmpty ? null : () => save(() => _isNew ? ctx.api.post('${ctx.base}/debtors', body) : ctx.api.put('${ctx.base}/debtors/${widget.row['_id']}', body)),
        ),
      ],
      children: [
        Field(label: ctx.m('debtorName'), controller: _name, maxLength: 80, autofocus: _isNew, onChanged: (_) => setState(() {})),
        gap14,
        Field(label: ctx.m('phone'), controller: _phone, maxLength: 30, keyboard: TextInputType.phone),
        gap14,
        Field(label: ctx.m('debtNote'), controller: _note, maxLength: 200),
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}

class _RepaySheet extends StatefulWidget {
  final MartCtx ctx;
  final Json d;
  const _RepaySheet({required this.ctx, required this.d});
  @override
  State<_RepaySheet> createState() => _RepaySheetState();
}

class _RepaySheetState extends State<_RepaySheet> with SheetSave {
  final _amount = TextEditingController(), _note = TextEditingController();
  String _method = 'cash';
  @override
  MartCtx get mctx => widget.ctx;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ctx = widget.ctx;
    final bal = n(widget.d['balance']);
    final v = numOf(_amount.text) ?? 0;
    final ok = v > 0 && v <= bal + .005;
    final list = (ctx.settings['methods'] as List? ?? const ['cash']).map((e) => '$e').where((k) => k != 'debt').toList();
    final methods = list.isEmpty ? ['cash'] : list;
    return MSheet(
      title: ctx.m('repayTitle', {'name': str(widget.d['name'])}),
      footer: [
        Expanded(
          child: Btn(
            busy ? ctx.m('saving') : '${ctx.m('repay')}${ok ? ' · ${money(v, ctx.cur)}' : ''}',
            busy: busy,
            expand: true,
            onTap: busy || !ok ? null : () => save(() => ctx.api.post('${ctx.base}/debtors/${widget.d['_id']}/payments', {'amount': v, 'method': _method, 'note': _note.text.trim()})),
          ),
        ),
      ],
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${ctx.m('owes')}: '),
              TextSpan(
                text: money(bal, ctx.cur),
                style: TextStyle(fontWeight: FontWeight.w800, color: c.danger),
              ),
            ],
          ),
          style: TextStyle(color: c.muted),
        ),
        gap14,
        Field(
          label: ctx.m('repayAmount'),
          controller: _amount,
          keyboard: decimalKeys,
          autofocus: true,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(
            label: Text('${ctx.m('repayAll')} · ${money(bal, ctx.cur)}'),
            onPressed: () => setState(() => _amount.text = qtyOf(bal)),
            side: BorderSide(color: c.line),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
          ),
        ),
        gap14,
        Text(ctx.m('colPay'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Segmented<String>(value: _method, options: [for (final k in methods) (k, ctx.methodName(k))], onChanged: (v) => setState(() => _method = v)),
        ),
        gap14,
        Field(label: ctx.m('debtNote'), controller: _note, maxLength: 200),
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}

class _DebtHistory extends StatefulWidget {
  final MartCtx ctx;
  final Json d;
  const _DebtHistory({required this.ctx, required this.d});
  @override
  State<_DebtHistory> createState() => _DebtHistoryState();
}

class _DebtHistoryState extends State<_DebtHistory> {
  Json? _row;
  @override
  void initState() {
    super.initState();
    final ctx = widget.ctx;
    ctx.api.get('${ctx.base}/debtors/${widget.d['_id']}').then((r) {
      if (mounted) setState(() => _row = obj(r['data']));
    }, onError: ctx.fail);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ctx = widget.ctx;
    final row = _row;
    return MSheet(
      title: '${ctx.m('debtHistory')} · ${widget.d['name']}',
      children: [
        if (row == null)
          const SkelList(rows: 4)
        else ...[
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${ctx.m('owes')}: '),
                TextSpan(
                  text: money(row['balance'], ctx.cur),
                  style: TextStyle(fontWeight: FontWeight.w800, color: n(row['balance']) > 0 ? c.danger : c.good),
                ),
              ],
            ),
            style: TextStyle(color: c.muted),
          ),
          const SizedBox(height: 8),
          for (final x in objs(row['txs']))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Pill(
                      ctx.t.or('mart.debtKinds.${x['kind']}', str(x['kind'])),
                      tone: switch (str(x['kind'])) {
                        'payment' => 'ok',
                        'sale' => 'info',
                        _ => '',
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${str(x['sale_no']).isNotEmpty ? x['sale_no'] : ctx.t.or('mart.debtKinds.${x['kind']}', str(x['kind']))}${str(x['method']).isNotEmpty ? ' · ${ctx.methodName(str(x['method']))}' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text([mDayTime(x['created_date'], ctx.lang), str(x['by']), str(x['note'])].where((s) => s.isNotEmpty).join(' · '), style: TextStyle(color: c.muted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        n(x['amount']) > 0 ? '+${money(x['amount'], ctx.cur)}' : money(x['amount'], ctx.cur),
                        style: TextStyle(fontWeight: FontWeight.w800, color: n(x['amount']) > 0 ? c.danger : c.good),
                      ),
                      Text('→ ${money(x['balance_after'], ctx.cur)}', style: TextStyle(color: c.muted, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------- Profit
String _pct(Object? v) => '${(n(v) * 10).round() / 10}%';

class ProfitTab extends StatefulWidget {
  final MartCtx ctx;
  const ProfitTab({super.key, required this.ctx});
  @override
  State<ProfitTab> createState() => _ProfitTabState();
}

class _ProfitTabState extends State<ProfitTab> {
  final _p = Period();
  Json? _data;
  String _error = '', _sort = 'profit';
  int _seq = 0;
  MartCtx get ctx => widget.ctx;
  bool get _on => ctx.addonOn('mart_profit');

  @override
  void initState() {
    super.initState();
    if (_on) _load();
  }

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() {
      _data = null;
      _error = '';
    });
    try {
      final r = await ctx.api.get('${ctx.base}/profit', _p.params);
      if (mounted && seq == _seq) setState(() => _data = obj(r['data']));
    } on ApiError catch (e) {
      if (mounted && seq == _seq) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final head = MAddonHead(ctx: ctx, addon: 'mart_profit', icon: LucideIcons.trendingUp, title: ctx.x('prfTitle'), sub: ctx.x('prfSub'), perks: ctx.t.list('mx.prfPerks'));
    if (!_on) return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [head]);
    final c = context.c;
    final data = _data;
    final t = obj(data?['totals']);
    final products = objs(data?['products'])
      ..sort(
        (a, b) => switch (_sort) {
          'margin' => n(b['margin']).compareTo(n(a['margin'])),
          'revenue' => n(b['revenue']).compareTo(n(a['revenue'])),
          _ => n(b['profit']).compareTo(n(a['profit'])),
        },
      );
    final has = data != null && n(t['receipts']) > 0;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          head,
          mGap,
          mCard(context, ctx.x('prfTitle'), [
            PeriodBar(ctx: ctx, p: _p, onChanged: _load),
            const SizedBox(height: 8),
            if (_error.isNotEmpty)
              Alert(_error, tone: Tone.warn)
            else if (data == null)
              const SkelList(rows: 3)
            else ...[
              Tiles([
                (money(t['revenue'], ctx.cur), ctx.x('revenue'), null),
                (money(t['profit'], ctx.cur), ctx.x('profit'), n(t['profit']) >= 0 ? c.good : c.danger),
                (money(t['cost'], ctx.cur), ctx.x('cost'), null),
                (_pct(t['margin']), ctx.x('margin'), null),
              ]),
              const SizedBox(height: 6),
              Muted('${ctx.x('receipts')}: ${n(t['receipts'])}'),
              if (n(t['estimated']) > 0) ...[
                const SizedBox(height: 4),
                Muted(ctx.x('estimated', {'n': n(t['estimated'])})),
              ],
              const SizedBox(height: 10),
              if (!has) Muted(ctx.x('noProfit')) else _ProfitChart(ctx: ctx, kind: str(data['kind']), series: objs(data['series'])),
            ],
          ]),
          if (has) ...[
            if (objs(data['no_cost']).isNotEmpty) ...[mGap, Alert('${ctx.x('noCost')} ${objs(data['no_cost']).map((r) => r['name']).join(', ')}', tone: Tone.warn)],
            mGap,
            mCard(context, ctx.x('byCategory'), [
              for (final cat in objs(data['categories']))
                BarRow(
                  lead: Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(color: str(cat['color']).isEmpty ? c.brand : hexToColor(str(cat['color'])), shape: BoxShape.circle),
                  ),
                  label: cat['category_id'] == 'x' ? ctx.x('otherLines') : (str(cat['name']).isEmpty ? ctx.x('noCategory') : str(cat['name'])),
                  sub: _pct(cat['margin']),
                  value: money(cat['profit'], ctx.cur),
                  pct: n(t['revenue']) > 0 ? (n(cat['revenue']) / n(t['revenue']) * 100).clamp(2, 100) : 0,
                ),
            ]),
            mGap,
            mCard(context, ctx.x('lowMargin'), [
              if (objs(data['low_margin']).isEmpty)
                Muted('—')
              else
                for (final r in objs(data['low_margin']))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(str(r['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text('${money(r['revenue'], ctx.cur)} − ${money(r['cost'], ctx.cur)}', style: TextStyle(color: c.muted, fontSize: 12.5)),
                            ],
                          ),
                        ),
                        Text(
                          _pct(r['margin']),
                          style: TextStyle(fontWeight: FontWeight.w800, color: n(r['margin']) < 0 ? c.danger : c.warn),
                        ),
                      ],
                    ),
                  ),
            ]),
            mGap,
            mCard(context, ctx.x('byProduct'), [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Segmented<String>(
                  value: _sort,
                  options: [
                    for (final k in ['profit', 'margin', 'revenue']) (k, ctx.x(k)),
                  ],
                  onChanged: (v) => setState(() => _sort = v),
                ),
              ),
              const SizedBox(height: 8),
              for (final (i, r) in products.indexed) ...[
                if (i > 0) Divider(height: 1, color: c.line),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(str(r['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                                ),
                                if (r['no_cost'] == true) ...[const SizedBox(width: 4), Icon(LucideIcons.triangleAlert, size: 13, color: c.warn)],
                              ],
                            ),
                            Text(
                              '${qtyOf(r['qty'])} × · ${ctx.x('revenue')} ${money(r['revenue'], ctx.cur)} · ${ctx.x('cost')} ${money(r['cost'], ctx.cur)}',
                              style: TextStyle(color: c.muted, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(money(r['profit'], ctx.cur), style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(_pct(r['margin']), style: TextStyle(color: c.muted, fontSize: 12.5)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ]),
          ],
        ],
      ),
    );
  }
}

// revenue columns with the profit part filled in
class _ProfitChart extends StatefulWidget {
  final MartCtx ctx;
  final String kind;
  final List<Json> series;
  const _ProfitChart({required this.ctx, required this.kind, required this.series});
  @override
  State<_ProfitChart> createState() => _ProfitChartState();
}

class _ProfitChartState extends State<_ProfitChart> {
  int? _on;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    var s = widget.series;
    // every day of the month (up to today), so one busy day is not one giant bar
    if (widget.kind != 'day' && s.isNotEmpty && str(s.first['key']).length == 10) {
      final month = str(s.first['key']).substring(0, 7);
      final got = {for (final x in s) str(x['key']): x};
      final today = todayKH();
      final days = <Json>[];
      for (var d = '$month-01'; d.startsWith(month) && d.compareTo(today) <= 0; d = addDaysKH(d, 1)) {
        days.add(got[d] ?? {'key': d, 'revenue': 0, 'profit': 0});
      }
      if (days.isNotEmpty) s = days;
    }
    final max = s.fold<num>(1, (a, x) => n(x['revenue']) > a ? n(x['revenue']) : a);
    final day = widget.kind == 'day';
    String label(Json x) => day
        ? '${x['key']}h'
        : str(x['key']).length >= 10
        ? str(x['key']).substring(8)
        : str(x['key']);
    final step = s.length > 16 ? (s.length / 8).ceil() : 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 18,
          child: Text(
            _on == null ? '' : '${label(s[_on!])} · ${widget.ctx.x('revenue')} ${money(s[_on!]['revenue'], widget.ctx.cur)} · ${widget.ctx.x('profit')} ${money(s[_on!]['profit'], widget.ctx.cur)}',
            style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, x) in s.indexed)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _on = _on == i ? null : i),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: s.length > 40 ? .5 : 1.5),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: n(x['revenue']) <= 0 ? 2 : (n(x['revenue']) / max * 140).clamp(3, 140).toDouble(),
                          decoration: BoxDecoration(
                            color: n(x['revenue']) <= 0 ? c.bg2 : c.brand.withValues(alpha: _on == i ? .45 : .25),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: n(x['revenue']) > 0 ? (n(x['profit']) / n(x['revenue'])).clamp(0, 1).toDouble() : 0,
                            widthFactor: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _on == i ? c.brandInk : c.brand,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final (i, x) in s.indexed)
              Expanded(
                child: SizedBox(
                  height: 16,
                  child: OverflowBox(
                    maxWidth: 40,
                    alignment: Alignment.centerLeft,
                    child: Text(i % step == 0 ? label(x) : '', maxLines: 1, softWrap: false, style: TextStyle(color: c.muted, fontSize: 10.5)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(width: 10, height: 10, color: c.brand.withValues(alpha: .25)),
            const SizedBox(width: 6),
            Text(widget.ctx.x('revenue'), style: TextStyle(color: c.muted, fontSize: 12)),
            const SizedBox(width: 14),
            Container(width: 10, height: 10, color: c.brand),
            const SizedBox(width: 6),
            Text(widget.ctx.x('profit'), style: TextStyle(color: c.muted, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}
