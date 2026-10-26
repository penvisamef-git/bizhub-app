import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../restaurant/rest_common.dart' show Segmented, gap14;
import '../restaurant/rest_online.dart' show shareWidgets;
import '../restaurant/rest_reports.dart' show ColumnsChart;
import 'mart_common.dart';
import 'mart_receipt.dart';

// Today + Sales — the app version of MartSales.jsx.
//   GET mart/report {day | from,to} → { kind, totals{sales,count,voids,avg,discount,by_method}, series, top, by_staff }
//   GET mart/sales  {day | from,to} → { rows, totals, limited, since }      POST mart/sales/:sid/void {reason}

// free plan: the last N days; "Full report history" (mart_history) shows everything
String? sinceOf(MartCtx ctx) {
  final d = n(ctx.limits['history_days']).toInt();
  return d > 0 ? addDaysKH(todayKH(), -(d - 1)) : null;
}

class _HistoryNote extends StatelessWidget {
  final MartCtx ctx;
  const _HistoryNote(this.ctx);
  @override
  Widget build(BuildContext context) {
    final since = sinceOf(ctx);
    if (since == null) return const SizedBox.shrink();
    final price = ctx.addon('mart_history')['price'] ?? 35;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LockNote(
        text: ctx.m('historyNote', {'n': n(ctx.limits['history_days']), 'date': mDay(since, ctx.lang)}),
        button: '${ctx.m('unlock', {'coins': fmt(n(price))})} ${ctx.m('perYear')}',
        onTap: ctx.readOnly ? null : () => ctx.askBuy('mart_history'),
      ),
    );
  }
}

Widget _kpis(MartCtx ctx, Json t, {bool range = false}) => Tiles([
  (money(t['sales'], ctx.cur), range ? ctx.m('total') : ctx.m('todaySales'), null),
  ('${n(t['count'])}', ctx.m('receipts'), null),
  (money(t['avg'], ctx.cur), ctx.m('avgSale'), null),
  ('${n(t['voids'])}', ctx.m('voids'), n(t['voids']) > 0 ? const Color(0xFFB45309) : null),
]);

Widget _methods(MartCtx ctx, Object? by) {
  final list = obj(by).entries.toList()..sort((a, b) => n(b.value).compareTo(n(a.value)));
  if (list.isEmpty) return const SizedBox.shrink();
  final all = list.fold<num>(0, (a, e) => a + n(e.value));
  return Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      children: [for (final e in list) BarRow(label: ctx.methodName(e.key), value: money(e.value, ctx.cur), pct: all == 0 ? 0 : (n(e.value) / all * 100).clamp(4, 100))],
    ),
  );
}

String _items(MartCtx ctx, Json s) {
  final k = objs(s['items']).length;
  return k == 1 ? ctx.m('oneItem') : ctx.m('nItems', {'n': k});
}

class SaleRow extends StatelessWidget {
  final MartCtx ctx;
  final Json s;
  final bool withDay;
  final VoidCallback onTap;
  const SaleRow({super.key, required this.ctx, required this.s, required this.onTap, this.withDay = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final voided = s['status'] == 'void';
    final sub = [
      ctx.methodName(str(s['method']), str(s['method_name'])),
      if (str(s['debtor_name']).isNotEmpty) str(s['debtor_name']),
      if (str(s['by']).isNotEmpty) str(s['by']),
      if (voided) ctx.m('voided'),
      if (s['offline'] == true && s['pending'] == true) '⏳',
    ].join(' · ');
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: withDay ? 74 : 46,
              child: Text(
                withDay ? mDayTime(s['at'], ctx.lang) : mTime(s['at']),
                style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${str(s['no']).isEmpty ? '—' : s['no']} · ${_items(ctx, s)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w700, decoration: voided ? TextDecoration.lineThrough : null),
                        ),
                      ),
                      if (s['offline'] == true) ...[const SizedBox(width: 5), Icon(LucideIcons.wifiOff, size: 12, color: c.muted)],
                    ],
                  ),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: voided ? c.danger : c.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              money(s['total'], str(s['currency']).isEmpty ? ctx.cur : str(s['currency'])),
              style: TextStyle(fontWeight: FontWeight.w800, color: voided ? c.muted : c.ink, decoration: voided ? TextDecoration.lineThrough : null),
            ),
          ],
        ),
      ),
    );
  }
}

// one receipt: the paper in the shop's template, share it (printing add-on), void it
Future<void> showMartSale(BuildContext context, MartCtx ctx, Json sale, {VoidCallback? onChanged}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _SaleSheet(ctx: ctx, sale: sale, onChanged: onChanged),
);

class _SaleSheet extends StatefulWidget {
  final MartCtx ctx;
  final Json sale;
  final VoidCallback? onChanged;
  const _SaleSheet({required this.ctx, required this.sale, this.onChanged});
  @override
  State<_SaleSheet> createState() => _SaleSheetState();
}

class _SaleSheetState extends State<_SaleSheet> {
  final _paper = GlobalKey();
  final _reason = TextEditingController();
  bool _voiding = false, _busy = false;
  MartCtx get ctx => widget.ctx;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _void() async {
    setState(() => _busy = true);
    try {
      await ctx.api.post('${ctx.base}/sales/${widget.sale['_id']}/void', {'reason': _reason.text.trim()});
      ctx.notify(ctx.m('voided'));
      widget.onChanged?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ctx.fail(e);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      await shareWidgets([_paper], (_) => 'receipt-${str(widget.sale['no']).isEmpty ? 'sale' : widget.sale['no']}.png');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = widget.sale;
    final pr = ctx.print;
    final canVoid = s['status'] == 'paid' && !ctx.readOnly;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text('${ctx.m('receipt')} ${str(s['no'])}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _voiding
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(ctx.m('voidTitle'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 4),
                        Muted(ctx.m('voidSub')),
                        gap14,
                        Field(label: ctx.m('voidReason'), controller: _reason, maxLength: 200, autofocus: true),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(18)),
                          child: RepaintBoundary(
                            key: _paper,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: MartReceipt(sale: s, shop: ctx.shop, m: (k) => ctx.m(k), methodName: ctx.methodName, lang: ctx.lang, theme: str(pr['theme']), size: str(pr['size'])),
                            ),
                          ),
                        ),
                        if (s['status'] == 'void') ...[
                          const SizedBox(height: 10),
                          Muted('${ctx.m('voidedBy', {'name': str(s['void_by'])})}${str(s['void_reason']).isNotEmpty ? ' · ${s['void_reason']}' : ''}', align: TextAlign.center),
                        ],
                        if (s['offline'] == true) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.wifiOff, size: 13, color: c.muted),
                              const SizedBox(width: 6),
                              Muted(ctx.m('offlineSale')),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.line)),
            ),
            child: Row(
              children: _voiding
                  ? [
                      const Spacer(),
                      Btn(ctx.m('cancel'), kind: BtnKind.ghost, small: true, onTap: _busy ? null : () => setState(() => _voiding = false)),
                      const SizedBox(width: 8),
                      Btn(ctx.m('voidBtn'), icon: LucideIcons.ban, kind: BtnKind.danger, small: true, busy: _busy, onTap: _busy ? null : _void),
                    ]
                  : [
                      if (canVoid) Btn(ctx.m('voidBtn'), icon: LucideIcons.ban, kind: BtnKind.ghost, small: true, onTap: () => setState(() => _voiding = true)),
                      const Spacer(),
                      if (pr['on'] == true)
                        Btn(ctx.t('app.shareReceipt'), icon: LucideIcons.share2, small: true, busy: _busy, onTap: _busy ? null : _share)
                      else
                        Btn(
                          ctx.m('print'),
                          icon: LucideIcons.lock,
                          kind: BtnKind.ghost,
                          small: true,
                          onTap: () {
                            Navigator.pop(context);
                            ctx.askBuy('mart_printer');
                          },
                        ),
                    ],
            ),
          ),
        ],
      ),
    );
  }
}

// a section card with a title
Widget _card(BuildContext context, String title, List<Widget> children, {Widget? trailing}) => Panel(
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
          ?trailing,
        ],
      ),
      const SizedBox(height: 10),
      ...children,
    ],
  ),
);

class _TopList extends StatelessWidget {
  final MartCtx ctx;
  final List<Json>? rows;
  const _TopList(this.ctx, this.rows);
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (rows == null) return const SkelList(rows: 3);
    if (rows!.isEmpty) return Muted(ctx.m('noTop'));
    final max = n(rows!.first['value']) == 0 ? 1 : n(rows!.first['value']);
    return Column(
      children: [
        for (final (i, t) in rows!.take(10).indexed)
          BarRow(
            lead: Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: i == 0 ? c.active : c.bg2, shape: BoxShape.circle),
              child: Text(
                '${i + 1}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: i == 0 ? c.brandInk : c.muted),
              ),
            ),
            label: str(t['name']),
            sub: ctx.m('sold', {'n': qtyOf(t['qty'])}),
            value: money(t['value'], ctx.cur),
            pct: (n(t['value']) / max * 100).clamp(3, 100),
          ),
      ],
    );
  }
}

// ----------------------------------------------------------------------------------------------- Today
class TodayTab extends StatefulWidget {
  final MartCtx ctx;
  const TodayTab({super.key, required this.ctx});
  @override
  State<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<TodayTab> {
  Json? _rep, _list;
  String _error = '';
  MartCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final day = todayKH();
    try {
      final r = await Future.wait([
        ctx.api.get('${ctx.base}/report', {'day': day}),
        ctx.api.get('${ctx.base}/sales', {'day': day}),
      ]);
      if (!mounted) return;
      setState(() {
        _rep = obj(r[0]['data']);
        _list = obj(r[1]['data']);
        _error = '';
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.network ? ctx.t('app.offline') : e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final empty = n(ctx.counts['products']) == 0;
    if (_error.isNotEmpty && _rep == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: LoadError(text: _error, retry: ctx.m('retry'), onRetry: _load),
      );
    }
    final rows = objs(_list?['rows']);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (empty) ...[
            Panel(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(LucideIcons.packagePlus, size: 26, color: context.c.brand),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(ctx.m('setupFirst'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Btn(ctx.m('addProducts'), small: true, onTap: () => ctx.go('products')),
                ],
              ),
            ),
            mGap,
          ],
          _card(
            context,
            ctx.m('tabs.today'),
            [
              if (_rep == null) const SkelList(rows: 2) else ...[_kpis(ctx, obj(_rep!['totals'])), _methods(ctx, obj(_rep!['totals'])['by_method'])],
            ],
            trailing: Btn(
              ctx.m('openPos'),
              icon: LucideIcons.externalLink,
              kind: BtnKind.ghost,
              small: true,
              onTap: () => launchUrl(Uri.parse('${Config.siteUrl}/pos/mini-mart'), mode: LaunchMode.externalApplication),
            ),
          ),
          mGap,
          _card(context, ctx.m('recent'), [
            if (_list == null)
              const SkelList(rows: 3)
            else if (rows.isEmpty)
              Muted(ctx.m('noSales'))
            else
              for (final s in rows.take(12))
                SaleRow(
                  ctx: ctx,
                  s: s,
                  onTap: () => showMartSale(context, ctx, s, onChanged: _load),
                ),
          ]),
          mGap,
          _card(context, ctx.m('topProducts'), [_TopList(ctx, _rep == null ? null : objs(_rep!['top']))]),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------------------------- Sales
const _ranges = ['today', 'yesterday', 'week', 'month'];
(String, String) _rangeOf(String k) {
  final t = todayKH();
  return switch (k) {
    'yesterday' => (addDaysKH(t, -1), addDaysKH(t, -1)),
    'week' => (addDaysKH(t, -6), t),
    'month' => ('${t.substring(0, 7)}-01', t),
    _ => (t, t),
  };
}

String _csvCell(Object? v) {
  final t = '${v ?? ''}';
  return RegExp(r'[",\n]').hasMatch(t) ? '"${t.replaceAll('"', '""')}"' : t;
}

class SalesTab extends StatefulWidget {
  final MartCtx ctx;
  const SalesTab({super.key, required this.ctx});
  @override
  State<SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends State<SalesTab> {
  String _range = 'today', _from = todayKH(), _to = todayKH();
  Json? _list, _rep;
  String _error = '';
  bool _sharing = false;
  int _seq = 0;
  MartCtx get ctx => widget.ctx;
  Map<String, String> get _params => _from == _to ? {'day': _from} : {'from': _from, 'to': _to};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() {
      _list = null;
      _rep = null;
      _error = '';
    });
    try {
      final r = await Future.wait([ctx.api.get('${ctx.base}/sales', _params), ctx.api.get('${ctx.base}/report', _params)]);
      if (!mounted || seq != _seq) return;
      setState(() {
        _list = obj(r[0]['data']);
        _rep = obj(r[1]['data']);
      });
    } on ApiError catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() => _error = e.status == 402 ? '' : (e.network ? ctx.t('app.offline') : e.message));
    }
  }

  void _pick(String k) {
    final (a, b) = _rangeOf(k);
    final since = sinceOf(ctx);
    _range = k;
    _from = since != null && a.compareTo(since) < 0 ? since : a;
    _to = b;
    _load();
  }

  Future<void> _custom() async {
    final today = DateTime.parse(todayKH());
    final since = sinceOf(ctx);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: since != null ? DateTime.parse(since) : DateTime(2024),
      lastDate: today,
      initialDateRange: DateTimeRange(start: DateTime.parse(_from), end: DateTime.parse(_to)),
    );
    if (picked == null) return;
    String d(DateTime x) => x.toIso8601String().substring(0, 10);
    _range = '';
    _from = d(picked.start);
    _to = d(picked.end);
    _load();
  }

  String _paidOf(Json x) {
    final method = str(x['method']);
    if (method == 'cash') return [if (n(x['paid_usd']) > 0) money(x['paid_usd']), if (n(x['paid_khr']) > 0) riel(x['paid_khr'])].join(' + ');
    if (method == 'debt') return str(x['debtor_name']);
    return '';
  }

  Future<void> _csv() async {
    final rows = objs(_list?['rows']);
    final head = ['colNo', 'day', 'colTime', 'colCashier', 'colPay', 'colItems', 'subtotal', 'discount', 'colTotal', 'received', 'change', 'colStatus'].map(ctx.m).toList();
    final lines = [
      for (final x in rows)
        [
          x['no'],
          DateTime.tryParse(str(x['at']))?.toUtc().add(const Duration(hours: 7)).toIso8601String().substring(0, 10) ?? '',
          mTime(x['at']),
          x['by'],
          ctx.methodName(str(x['method']), str(x['method_name'])) + (str(x['debtor_name']).isNotEmpty ? ' (${x['debtor_name']})' : ''),
          objs(x['items']).map((l) => '${qtyOf(l['qty'])}× ${l['name']}').join('; '),
          x['subtotal'],
          x['discount'],
          x['total'],
          _paidOf(x),
          x['change'],
          x['status'] == 'void' ? ctx.m('voided') : ctx.m('statusPaid'),
        ],
    ];
    final csv = '﻿${[head, ...lines].map((r) => r.map(_csvCell).join(',')).join('\n')}';
    setState(() => _sharing = true);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(utf8.encode(csv), mimeType: 'text/csv', name: 'sales-$_from${_from != _to ? '-$_to' : ''}.csv')],
        ),
      );
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final multi = _from != _to;
    final rows = objs(_list?['rows']);
    final totals = obj(_list?['totals']);
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
                Text(ctx.m('tabs.sales'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Muted('${mDay(_from, ctx.lang)}${multi ? ' → ${mDay(_to, ctx.lang)}' : ''}${_list?['limited'] == true ? ' · ${ctx.m('historyNote').split('.').first}' : ''}'),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Segmented<String>(value: _range, options: [for (final k in _ranges) (k, ctx.m('ranges.$k'))], onChanged: _pick),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _custom,
                        icon: const Icon(LucideIcons.calendarRange, size: 16),
                        label: Text(
                          '${mDay(_from, ctx.lang)} → ${mDay(_to, ctx.lang)}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.ink, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _range.isEmpty ? c.brand : c.line),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Btn(ctx.m('exportCsv'), icon: LucideIcons.download, kind: BtnKind.ghost, small: true, busy: _sharing, onTap: rows.isEmpty || _sharing ? null : _csv),
                  ],
                ),
                const SizedBox(height: 12),
                _HistoryNote(ctx),
                if (_list == null && _error.isEmpty) const SkelList(rows: 2) else if (_list != null) ...[_kpis(ctx, totals, range: true), _methods(ctx, totals['by_method'])],
              ],
            ),
          ),
          mGap,
          Panel(
            padding: const EdgeInsets.all(12),
            child: _list == null
                ? (_error.isNotEmpty ? Alert(_error) : const SkelList(rows: 4))
                : rows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 26),
                    child: Column(
                      children: [
                        Icon(LucideIcons.receiptText, size: 30, color: c.muted),
                        const SizedBox(height: 8),
                        Muted(ctx.m('noSales')),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, s) in rows.indexed) ...[
                        if (i > 0) Divider(height: 1, color: c.line),
                        SaleRow(
                          ctx: ctx,
                          s: s,
                          withDay: multi,
                          onTap: () => showMartSale(context, ctx, s, onChanged: _load),
                        ),
                      ],
                      Divider(height: 18, color: c.lineStrong),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${ctx.m('receipts')}: ${n(totals['count'])}${n(totals['voids']) > 0 ? ' · ${ctx.m('voids')}: ${n(totals['voids'])}' : ''}${n(totals['discount']) > 0 ? ' · ${ctx.m('discount')} −${money(totals['discount'], ctx.cur)}' : ''}',
                                style: TextStyle(color: c.muted, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                            Text(money(totals['sales'], ctx.cur), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          if (_rep != null && n(obj(_rep!['totals'])['count']) > 0) ..._insights(context),
        ],
      ),
    );
  }

  // sales per hour / per day, best sellers, by cashier
  List<Widget> _insights(BuildContext context) {
    final rep = _rep!;
    final day = rep['kind'] == 'day';
    final got = {for (final x in objs(rep['series'])) str(x['key']): x};
    final keys = <String>[];
    if (day) {
      final hrs = got.keys.map(int.parse);
      final lo = [7, ...hrs].reduce((a, b) => a < b ? a : b), hi = [21, ...hrs].reduce((a, b) => a > b ? a : b);
      for (var h = lo; h <= hi; h++) {
        keys.add(h.toString().padLeft(2, '0'));
      }
    } else {
      final today = todayKH();
      for (var d = str(rep['from']); d.compareTo(str(rep['to'])) < 0 && d.compareTo(today) <= 0; d = addDaysKH(d, 1)) {
        keys.add(d);
      }
    }
    final series = [
      for (final k in keys) got[k] ?? {'key': k, 'sales': 0, 'count': 0},
    ];
    return [
      if (series.length > 1) ...[
        mGap,
        _card(context, day ? ctx.m('perHour') : ctx.m('perDay'), [
          ColumnsChart(
            values: [for (final x in series) n(x['sales'])],
            labels: [
              for (final (i, x) in series.indexed)
                (series.length > 16 && i % (series.length ~/ 8) != 0)
                    ? ''
                    : day
                    ? '${x['key']}h'
                    : mDay(str(x['key']), ctx.lang).split(' ').first,
            ],
            tips: [for (final x in series) '${day ? '${x['key']}h' : mDay(str(x['key']), ctx.lang)} · ${money(x['sales'], ctx.cur)} · ${n(x['count'])} ${ctx.m('receipts').toLowerCase()}'],
          ),
        ]),
      ],
      mGap,
      _card(context, ctx.m('topProducts'), [_TopList(ctx, objs(rep['top']))]),
      mGap,
      _card(context, ctx.m('byCashier'), [
        for (final s in objs(rep['by_staff']))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(str(s['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${n(s['count'])} ${ctx.m('receipts').toLowerCase()}', style: TextStyle(color: context.c.muted, fontSize: 12.5)),
                    ],
                  ),
                ),
                Text(money(s['sales'], ctx.cur), style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
      ]),
    ];
  }
}
