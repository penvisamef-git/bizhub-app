import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'rest_common.dart';
import 'rest_receipt.dart';

// Reports (the web's ReportsTab.jsx): overview of sales, all bills (with the receipt), shifts.

const _tz = Duration(hours: 7); // Cambodia
String localToday() => DateTime.now().toUtc().add(_tz).toIso8601String().substring(0, 10);
String addDays(String day, int d) => DateTime.parse('${day}T00:00:00Z').add(Duration(days: d)).toIso8601String().substring(0, 10);

({String from, String to}) presetRange(String key, String today) {
  final y = int.parse(today.substring(0, 4)), m = int.parse(today.substring(5, 7));
  String first(int yy, int mm) => '$yy-${mm.toString().padLeft(2, '0')}-01';
  return switch (key) {
    'yesterday' => (from: addDays(today, -1), to: addDays(today, -1)),
    'd7' => (from: addDays(today, -6), to: today),
    'd30' => (from: addDays(today, -29), to: today),
    'month' => (from: first(y, m), to: today),
    'lastMonth' => (from: first(m == 1 ? y - 1 : y, m == 1 ? 12 : m - 1), to: addDays(first(y, m), -1)),
    _ => (from: today, to: today),
  };
}

const _monEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monKm = ['មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា', 'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ'];
String _p2(int x) => x.toString().padLeft(2, '0');

// "14 Oct" for a YYYY-MM-DD day
String dayLabel(String day, String lang) {
  final d = DateTime.parse('${day}T00:00:00Z');
  return '${d.day} ${(lang == 'km' ? _monKm : _monEn)[d.month - 1]}';
}

// "14 Oct, 20:15" in Cambodia time
String whenShort(Object? v, String lang) {
  final d = DateTime.tryParse('${v ?? ''}')?.toUtc().add(_tz);
  if (d == null) return '—';
  return '${d.day} ${(lang == 'km' ? _monKm : _monEn)[d.month - 1]}, ${_p2(d.hour)}:${_p2(d.minute)}';
}

String whenLong(Object? v, String lang) {
  final d = DateTime.tryParse('${v ?? ''}')?.toUtc().add(_tz);
  if (d == null) return '—';
  return '${d.day} ${(lang == 'km' ? _monKm : _monEn)[d.month - 1]} ${d.year}, ${_p2(d.hour)}:${_p2(d.minute)}';
}

extension on RestCtx {
  String rp(String key, [Map<String, Object?> vars = const {}]) => t('report.$key', vars);
}

class ReportsSection extends StatefulWidget {
  final RestCtx ctx;
  const ReportsSection({super.key, required this.ctx});
  @override
  State<ReportsSection> createState() => _ReportsSectionState();
}

class _ReportsSectionState extends State<ReportsSection> {
  String _view = 'overview';
  String _preset = 'today';
  late ({String from, String to}) _range = presetRange('today', localToday());
  RestCtx get ctx => widget.ctx;

  void _pick(String key) async {
    if (key == 'custom') {
      final today = DateTime.parse(localToday());
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2024),
        lastDate: today,
        initialDateRange: DateTimeRange(start: DateTime.parse(_range.from), end: DateTime.parse(_range.to)),
      );
      if (picked == null) return;
      String d(DateTime x) => '${x.year}-${_p2(x.month)}-${_p2(x.day)}';
      setState(() {
        _preset = 'custom';
        _range = (from: d(picked.start), to: d(picked.end));
      });
      return;
    }
    setState(() {
      _preset = key;
      _range = presetRange(key, localToday());
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final full = ctx.addonOn('rest_history');
    final ranges = ['today', 'yesterday', 'd7', 'd30', 'month', 'lastMonth', 'custom'];
    final top = <Widget>[
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RestHead(ctx.rp('title'), sub: ctx.rp('sub')),
            Segmented<String>(
              value: _view,
              options: [
                for (final k in ['overview', 'invoices', 'shifts']) (k, ctx.rp('views.$k')),
              ],
              onChanged: (v) => setState(() => _view = v),
            ),
            if (_view != 'shifts') ...[
              const SizedBox(height: 12),
              SelectField<String>(value: _preset, options: [for (final k in ranges) (k, ctx.rp('ranges.$k'))], onChanged: _pick),
              if (_preset == 'custom') ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _pick('custom'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(LucideIcons.calendarRange, size: 16, color: c.muted),
                        const SizedBox(width: 8),
                        Text('${dayLabel(_range.from, ctx.lang)} → ${dayLabel(_range.to, ctx.lang)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      if (!full && _view != 'shifts') ...[const SizedBox(height: 12), _HistoryBanner(ctx: ctx)],
      gap14,
    ];
    final body = switch (_view) {
      'invoices' => _Invoices(key: ValueKey('inv${_range.from}${_range.to}'), ctx: ctx, from: _range.from, to: _range.to, top: top),
      'shifts' => ShiftsList(key: const ValueKey('shifts'), ctx: ctx, top: top),
      _ => _Overview(key: ValueKey('ov${_range.from}${_range.to}'), ctx: ctx, from: _range.from, to: _range.to, top: top),
    };
    return body;
  }
}

class _HistoryBanner extends StatelessWidget {
  final RestCtx ctx;
  const _HistoryBanner({required this.ctx});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(color: c.warnBg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(LucideIcons.history, size: 18, color: c.warn),
          const SizedBox(width: 10),
          Expanded(
            child: Text(ctx.rp('historyFree', {'n': 30}), style: TextStyle(color: c.ink, fontSize: 13, height: 1.4)),
          ),
          const SizedBox(width: 8),
          Btn(ctx.rp('getHistory'), kind: BtnKind.ghost, small: true, onTap: ctx.readOnly ? null : () => ctx.askBuy('rest_history')),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------ overview
class _Overview extends StatefulWidget {
  final RestCtx ctx;
  final String from, to;
  final List<Widget> top;
  const _Overview({super.key, required this.ctx, required this.from, required this.to, required this.top});
  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> {
  Json? _data;
  String _error = '';
  bool _loading = false, _allItems = false;
  RestCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final r = await ctx.api.get('${ctx.base}/report', {'from': widget.from, 'to': widget.to});
      if (mounted) setState(() => _data = obj(r['data']));
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiError ? (e.network ? ctx.t('app.offline') : e.message) : ctx.rp('loadFail'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final data = _data;
    final list = <Widget>[...widget.top];
    if (data == null) {
      list.add(_error.isNotEmpty ? LoadError(text: _error, retry: ctx.rp('refresh'), onRetry: _load) : const Panel(child: SkelList(rows: 5)));
      return _scroll(list);
    }
    final rep = obj(data['report']);
    final range = obj(data['range']);
    final history = obj(data['history']);
    final cur = str(obj(data['money'])['currency']).isEmpty ? 'USD' : str(obj(data['money'])['currency']);
    String m(Object? v) => fmtMoney(n(v), cur);
    final days = n(range['days']).toInt();
    final prev = obj(data['prev']);
    final change = prev.isNotEmpty && n(prev['sales']) > 0 ? (n(rep['sales']) - n(prev['sales'])) / n(prev['sales']) * 100 : null;
    final byItem = objs(rep['by_item']);
    final items = _allItems ? byItem : byItem.take(10).toList();
    final maxQty = byItem.fold<num>(1, (a, x) => n(x['qty']) > a ? n(x['qty']) : a);
    final methods = objs(rep['by_method']);
    final methodsTotal = methods.fold<num>(0, (a, x) => a + (n(x['value']) > 0 ? n(x['value']) : 0));
    final cats = objs(rep['by_category']);
    final catsTotal = cats.fold<num>(0, (a, x) => a + n(x['sales']));
    final sales = n(rep['sales']);
    final cost = n(rep['cost']);
    final byType = obj(rep['by_type']);
    String billsN(Object? v) => n(v) == 1 ? (ctx.lang == 'km' ? ctx.rp('billsN', {'n': 1}) : '1 bill') : ctx.rp('billsN', {'n': fmt(v)});

    if (history['limited'] == true) {
      list.addAll([
        Alert(ctx.rp('historyCut', {'n': history['free_days']}), tone: Tone.warn),
        const SizedBox(height: 12),
      ]);
    }
    if (rep['truncated'] == true) list.addAll([Alert(ctx.rp('truncated')), const SizedBox(height: 12)]);

    final pct = change == null ? '' : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}%';
    list.add(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: c.gradient, borderRadius: BorderRadius.circular(22), boxShadow: c.orangeShadow),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.trendingUp, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  ctx.rp('sales'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                InkWell(
                  onTap: _loading ? null : _load,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: _loading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(LucideIcons.refreshCw, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              m(sales),
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -.5),
            ),
            if (change != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(change >= 0 ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight, size: 15, color: Colors.white),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      (days == 1 ? ctx.rp('vsBefore1', {'p': pct}) : ctx.rp('vsBefore', {'p': pct, 'n': days})),
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
    list.add(const SizedBox(height: 12));
    final kpis = <Widget>[
      _Kpi(icon: LucideIcons.receiptText, label: ctx.rp('bills'), value: fmt(rep['bills'])),
      _Kpi(icon: LucideIcons.wallet, label: ctx.rp('avg'), value: m(rep['avg'])),
      if (cost > 0)
        _Kpi(
          icon: LucideIcons.trendingUp,
          label: ctx.rp('profit'),
          value: m(rep['profit']),
          sub: ctx.rp('profitSub', {'p': sales != 0 ? (n(rep['profit']) / ((sales - n(rep['vat'])) == 0 ? 1 : sales - n(rep['vat'])) * 100).round() : 0}),
          tone: Tone.good,
        )
      else
        _Kpi(icon: LucideIcons.users, label: ctx.rp('guests'), value: fmt(rep['guests'])),
      _Kpi(icon: LucideIcons.arrowDownRight, label: ctx.rp('discounts'), value: m(rep['discounts'])),
      _Kpi(
        icon: LucideIcons.ban,
        label: ctx.rp('cancelled'),
        value: fmt(rep['void_orders']),
        sub: n(rep['void_orders']) > 0 ? ctx.rp('cancelledSub', {'v': m(rep['void_value'])}) : null,
        tone: n(rep['void_orders']) > 0 ? Tone.warn : null,
      ),
      if (cost > 0)
        _Kpi(icon: LucideIcons.shoppingBasket, label: ctx.rp('costSold'), value: m(cost), sub: ctx.rp('itemsSoldN', {'n': fmt(rep['items'])}))
      else
        _Kpi(icon: LucideIcons.shoppingBasket, label: ctx.rp('itemsSold'), value: fmt(rep['items'])),
    ];
    list.add(_Grid(children: kpis));
    list.add(gap14);

    if (n(rep['bills']) == 0 && n(rep['void_orders']) == 0) {
      list.add(
        Panel(
          child: Column(
            children: [
              Icon(LucideIcons.chartColumn, size: 34, color: c.muted),
              const SizedBox(height: 10),
              Text(
                ctx.rp('empty'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Muted(ctx.rp('emptySub'), align: TextAlign.center),
              const SizedBox(height: 12),
              Btn(ctx.rp('openPos'), kind: BtnKind.ghost, small: true, onTap: () => ctx.go('pos')),
            ],
          ),
        ),
      );
      return _scroll(list);
    }

    list.add(
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(days == 1 ? ctx.rp('salesByHour') : ctx.rp('salesByDay'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            days == 1 ? _hourChart(rep, m) : _dayChart(rep, str(range['from']), str(range['to']), m),
            if (n(rep['vat']) > 0 || n(rep['service']) > 0) ...[
              const SizedBox(height: 10),
              Muted(ctx.rp('taxes', {'v': m(rep['vat']), 's': m(rep['service'])})),
            ],
          ],
        ),
      ),
    );
    list.add(gap14);
    list.add(
      _Card(
        title: ctx.rp('methods'),
        children: [
          for (final x in methods)
            _Bar(label: str(x['name']), sub: '×${fmt(x['count'])}', value: m(x['value']), pct: methodsTotal == 0 ? 0 : (n(x['value']) > 0 ? n(x['value']) : 0) / methodsTotal * 100),
        ],
      ),
    );
    list.add(gap14);
    list.add(
      _Card(
        title: ctx.rp('types'),
        children: [
          for (final (k, label) in [('dine_in', ctx.rp('dineIn')), ('takeaway', ctx.rp('takeaway'))])
            _Bar(label: label, sub: billsN(obj(byType[k])['bills']), value: m(obj(byType[k])['sales']), pct: sales == 0 ? 0 : n(obj(byType[k])['sales']) / sales * 100),
        ],
      ),
    );
    list.add(gap14);
    list.add(
      _Card(
        title: ctx.rp('items'),
        children: [
          for (final (i, x) in items.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(color: c.muted, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: nameOf(x, ctx.lang)),
                              if (str(x['size']).isNotEmpty)
                                TextSpan(
                                  text: ' · ${str(x['size'])}',
                                  style: TextStyle(color: c.muted, fontStyle: FontStyle.italic),
                                ),
                            ],
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 5),
                        _Track(pct: n(x['qty']) / maxQty * 100),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(m(x['sales']), style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                        '×${fmt(x['qty'])}${cost > 0 && n(x['cost']) > 0 ? ' · ${m(x['profit'])}' : ''}',
                        style: TextStyle(color: n(x['profit']) < 0 && n(x['cost']) > 0 ? c.danger : c.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (byItem.length > 10)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Center(
                child: Btn(_allItems ? ctx.rp('showLess') : ctx.rp('showAll', {'n': byItem.length}), kind: BtnKind.ghost, small: true, onTap: () => setState(() => _allItems = !_allItems)),
              ),
            ),
        ],
      ),
    );
    final promos = objs(rep['by_promo']);
    if (promos.isNotEmpty) {
      list.add(gap14);
      list.add(
        _Card(
          title: ctx.rp('promos'),
          children: [
            for (final x in promos)
              _Bar(
                label: x['id'] == 'manual' ? ctx.rp('manualDisc') : (str(x['name']).isEmpty ? ctx.rp('promo') : str(x['name'])),
                sub: ctx.rp('promoUsed', {'n': fmt(x['qty'])}),
                value: '−${m(x['off'])}',
                pct: n(rep['discounts']) == 0 ? 0 : n(x['off']) / n(rep['discounts']) * 100,
              ),
          ],
        ),
      );
    }
    list.add(gap14);
    list.add(
      _Card(
        title: ctx.rp('categories'),
        children: [
          for (final x in cats)
            _Bar(
              label: nameOf(x, ctx.lang) == '—' ? ctx.rp('noCategory') : nameOf(x, ctx.lang),
              sub: '×${fmt(x['qty'])}',
              value: m(x['sales']),
              pct: catsTotal == 0 ? 0 : n(x['sales']) / catsTotal * 100,
              color: str(x['color']).isEmpty ? null : _hex(str(x['color'])),
            ),
        ],
      ),
    );
    list.add(gap14);
    list.add(
      _Card(
        title: ctx.rp('staff'),
        children: [for (final x in objs(rep['by_staff'])) _Bar(label: str(x['name']), sub: billsN(x['bills']), value: m(x['sales']), pct: sales == 0 ? 0 : n(x['sales']) / sales * 100)],
      ),
    );
    return _scroll(list);
  }

  Widget _scroll(List<Widget> list) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: list),
  );

  Widget _dayChart(Json rep, String from, String to, String Function(Object?) m) {
    final byDay = {for (final d in objs(rep['by_day'])) str(d['day']): d};
    final all = <Json>[];
    for (var d = from; d.compareTo(to) <= 0 && all.length < 400; d = addDays(d, 1)) {
      all.add(byDay[d] ?? {'day': d, 'sales': 0, 'bills': 0});
    }
    final every = (all.length / 6).ceil();
    return ColumnsChart(
      values: [for (final d in all) n(d['sales'])],
      labels: [for (final (i, d) in all.indexed) i % every == 0 ? dayLabel(str(d['day']), ctx.lang) : ''],
      tips: [for (final d in all) '${dayLabel(str(d['day']), ctx.lang)} · ${m(d['sales'])} · ${fmt(d['bills'])}'],
    );
  }

  Widget _hourChart(Json rep, String Function(Object?) m) {
    final hours = (rep['by_hour'] is List ? rep['by_hour'] as List : List.filled(24, 0)).map(n).toList();
    final used = [
      for (var h = 0; h < hours.length; h++)
        if (hours[h] > 0) h,
    ];
    final lo = used.isEmpty ? 7 : (used.first < 7 ? used.first : 7);
    final hi = used.isEmpty ? 21 : (used.last > 21 ? used.last : 21);
    final list = [for (var h = lo; h <= hi; h++) h];
    return ColumnsChart(values: [for (final h in list) hours[h]], labels: [for (final h in list) h % 3 == 0 ? '${h}h' : ''], tips: [for (final h in list) '${_p2(h)}:00 · ${m(hours[h])}']);
  }
}

Color? _hex(String h) {
  final v = int.tryParse(h.replaceFirst('#', ''), radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

class _Grid extends StatelessWidget {
  final List<Widget> children;
  const _Grid({required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) {
      final cols = box.maxWidth > 560 ? 3 : 2;
      final w = (box.maxWidth - 12 * (cols - 1)) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [for (final x in children) SizedBox(width: w, child: x)],
      );
    },
  );
}

class _Kpi extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final String? sub;
  final Tone? tone;
  const _Kpi({required this.icon, required this.label, required this.value, this.sub, this.tone});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = switch (tone) {
      Tone.good => c.good,
      Tone.warn => c.warn,
      Tone.danger => c.danger,
      _ => c.ink,
    };
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: c.muted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fg),
            ),
          ),
          if (sub != null && sub!.isNotEmpty) ...[const SizedBox(height: 2), Text(sub!, maxLines: 2, style: TextStyle(color: c.muted, fontSize: 11.5))],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Card({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (children.isEmpty) const Muted('—') else ...children,
      ],
    ),
  );
}

class _Track extends StatelessWidget {
  final num pct;
  final Color? color;
  const _Track({required this.pct, this.color});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Stack(
        children: [
          Container(height: 6, color: c.bg2),
          FractionallySizedBox(
            widthFactor: (pct / 100).clamp(0, 1).toDouble(),
            child: Container(
              height: 6,
              decoration: BoxDecoration(color: color, gradient: color == null ? c.gradient : null),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label, value;
  final String? sub;
  final num pct;
  final Color? color;
  const _Bar({required this.label, required this.value, this.sub, required this.pct, this.color});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: label),
                      if (sub != null && sub!.isNotEmpty)
                        TextSpan(
                          text: '  $sub',
                          style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(
                width: 44,
                child: Text(
                  '${pct.round()}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _Track(pct: pct, color: color),
        ],
      ),
    );
  }
}

// a simple column chart; tap a column to see its numbers
class ColumnsChart extends StatefulWidget {
  final List<num> values;
  final List<String> labels, tips;
  const ColumnsChart({super.key, required this.values, required this.labels, required this.tips});
  @override
  State<ColumnsChart> createState() => _ColumnsChartState();
}

class _ColumnsChartState extends State<ColumnsChart> {
  int? _on;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final max = widget.values.fold<num>(1, (a, v) => v > a ? v : a);
    final gap = widget.values.length > 40 ? 1.0 : 3.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 18,
          child: Text(
            _on == null ? '' : widget.tips[_on!],
            style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < widget.values.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _on = _on == i ? null : i),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: gap / 2),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: widget.values[i] <= 0 ? 2 : (widget.values[i] / max * 150).clamp(3, 150).toDouble(),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            color: widget.values[i] <= 0 ? c.bg2 : (_on == i ? c.brandInk : null),
                            gradient: widget.values[i] > 0 && _on != i
                                ? LinearGradient(colors: [c.brand, c.brand.withValues(alpha: .65)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
                                : null,
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
            for (final l in widget.labels)
              Expanded(
                child: SizedBox(
                  height: 16,
                  child: OverflowBox(
                    maxWidth: 60,
                    alignment: Alignment.centerLeft,
                    child: Text(l, maxLines: 1, softWrap: false, style: TextStyle(color: c.muted, fontSize: 10.5)),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------ invoices
class _Invoices extends StatefulWidget {
  final RestCtx ctx;
  final String from, to;
  final List<Widget> top;
  const _Invoices({super.key, required this.ctx, required this.from, required this.to, required this.top});
  @override
  State<_Invoices> createState() => _InvoicesState();
}

class _InvoicesState extends State<_Invoices> {
  final _q = TextEditingController();
  String _status = 'all', _query = '';
  int _page = 1;
  Json? _data;
  String _error = '';
  bool _loading = false, _downloading = false;
  int _seq = 0;
  RestCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _params => {'from': widget.from, 'to': widget.to, 'status': _status, 'q': _query};

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final r = await ctx.api.get('${ctx.base}/report/invoices', {..._params, 'page': _page});
      if (mounted && seq == _seq) setState(() => _data = r);
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _error = e is ApiError ? (e.network ? ctx.t('app.offline') : e.message) : ctx.rp('loadFail'));
    } finally {
      if (mounted && seq == _seq) setState(() => _loading = false);
    }
  }

  // typing waits a moment before searching
  void _typed(String v) {
    final seq = ++_seq;
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || seq != _seq) return;
      _query = v.trim();
      _page = 1;
      _load();
    });
  }

  Future<void> _csv() async {
    setState(() => _downloading = true);
    try {
      final r = await ctx.api.get('${ctx.base}/report/invoices', {..._params, 'format': 'csv'});
      final text = str(r['message'] ?? r['data']);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(utf8.encode(text), mimeType: 'text/csv', name: 'invoices-${widget.from}-to-${widget.to}.csv')],
        ),
      );
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final data = _data;
    final rows = objs(data?['data']);
    final pg = obj(data?['pagination']);
    final cur = ctx.currency;
    final list = <Widget>[
      ...widget.top,
      Row(
        children: [
          Expanded(
            child: Field(
              controller: _q,
              hint: ctx.rp('search'),
              icon: LucideIcons.search,
              onChanged: (v) {
                setState(() {});
                _typed(v);
              },
              suffix: _q.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () {
                        _q.clear();
                        _typed('');
                        setState(() {});
                      },
                    ),
            ),
          ),
          const SizedBox(width: 10),
          _downloading
              ? const SizedBox(
                  width: 44,
                  height: 44,
                  child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2.2)),
                )
              : RoundBtn(LucideIcons.download, tip: ctx.rp('csv'), onTap: rows.isEmpty ? null : _csv),
        ],
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final k in ['all', 'paid', 'void', 'open'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(ctx.rp(k)),
                  selected: _status == k,
                  onSelected: (_) {
                    setState(() {
                      _status = k;
                      _page = 1;
                    });
                    _load();
                  },
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (obj(data?['history'])['limited'] == true) ...[
        Alert(ctx.rp('historyCut', {'n': 30}), tone: Tone.warn),
        const SizedBox(height: 12),
      ],
    ];
    if (data == null) {
      list.add(_error.isNotEmpty ? LoadError(text: _error, retry: ctx.rp('refresh'), onRetry: _load) : const Panel(child: SkelList(rows: 6)));
    } else if (rows.isEmpty) {
      list.add(Panel(child: Muted(ctx.rp('noBills'), align: TextAlign.center)));
    } else {
      list.add(
        AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _loading ? .5 : 1,
          child: Panel(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final (i, o) in rows.indexed) ...[
                  if (i > 0) Divider(height: 1, color: c.line, indent: 16, endIndent: 16),
                  InkWell(
                    onTap: () => showBill(context, ctx, str(o['_id'])),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('#${str(o['number'])}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        str(o['table_name']).isEmpty ? ctx.rp('takeaway') : str(o['table_name']),
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: c.muted, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  [
                                    whenShort(o['paid_at'] ?? o['opened_at'], ctx.lang),
                                    str(o['closed_by']).isNotEmpty ? str(o['closed_by']) : str(o['opened_by']),
                                    if ((o['methods'] as List?)?.isNotEmpty == true) (o['methods'] as List).join(' + '),
                                  ].where((s) => s.isNotEmpty).join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: c.muted, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(fmtMoney(n(o['total']), cur), style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              _statusChip(ctx, str(o['status'])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
      if (n(pg['totalPages']) > 1) {
        list.add(
          _Pager(
            page: n(pg['currentPage']).toInt(),
            pages: n(pg['totalPages']).toInt(),
            text: '${ctx.rp('page', {'p': pg['currentPage'], 'n': pg['totalPages']})} · ${fmt(pg['total'])}',
            onPage: (p) {
              setState(() => _page = p);
              _load();
            },
          ),
        );
      }
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: list),
    );
  }
}

Widget _statusChip(RestCtx ctx, String status) =>
    Chip2(status == 'paid' ? ctx.rp('paid') : (status == 'void' ? ctx.rp('void') : ctx.rp('open')), tone: status == 'paid' ? Tone.good : (status == 'void' ? Tone.danger : Tone.brand));

class _Pager extends StatelessWidget {
  final int page, pages;
  final String text;
  final ValueChanged<int> onPage;
  const _Pager({required this.page, required this.pages, required this.text, required this.onPage});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RoundBtn(LucideIcons.chevronLeft, size: 40, onTap: page <= 1 ? null : () => onPage(page - 1)),
        const SizedBox(width: 12),
        Muted(text),
        const SizedBox(width: 12),
        RoundBtn(LucideIcons.chevronRight, size: 40, onTap: page >= pages ? null : () => onPage(page + 1)),
      ],
    ),
  );
}

// one bill: the receipt as printed + who / when / where
Future<void> showBill(BuildContext context, RestCtx ctx, String id) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _BillSheet(ctx: ctx, id: id),
);

class _BillSheet extends StatefulWidget {
  final RestCtx ctx;
  final String id;
  const _BillSheet({required this.ctx, required this.id});
  @override
  State<_BillSheet> createState() => _BillSheetState();
}

class _BillSheetState extends State<_BillSheet> {
  Json? _data;
  String _error = '';
  bool _sharing = false;
  final _paper = GlobalKey();
  RestCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    ctx.api
        .get('${ctx.base}/report/invoices/${widget.id}')
        .then((r) {
          if (mounted) setState(() => _data = obj(r['data']));
        })
        .catchError((Object e) {
          if (mounted) setState(() => _error = e is ApiError ? e.message : '$e');
        });
  }

  Future<void> _share(String number) async {
    setState(() => _sharing = true);
    try {
      final box = _paper.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (box == null) return;
      final img = await box.toImage(pixelRatio: 3);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png', name: 'bill-$number.png')],
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final o = obj(_data?['order']);
    final restaurant = obj(_data?['restaurant']);
    final size = n(obj(restaurant['receipt'])['size']) == 58 ? 58 : 80;
    Widget meta(String k, Widget v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              k,
              style: TextStyle(color: c.muted, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontWeight: FontWeight.w700),
              child: v,
            ),
          ),
        ],
      ),
    );
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .9,
      minChildSize: .5,
      maxChildSize: 1,
      builder: (_, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(o.isEmpty ? '…' : ctx.rp('bill', {'n': o['number']}), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                ),
                if (o.isNotEmpty) Btn(ctx.t('app.shareReceipt'), icon: LucideIcons.share2, kind: BtnKind.ghost, small: true, busy: _sharing, onTap: _sharing ? null : () => _share(str(o['number']))),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                if (_error.isNotEmpty) Alert(_error),
                if (o.isEmpty && _error.isEmpty) const SkelList(rows: 4),
                if (o.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(18)),
                    child: RepaintBoundary(
                      key: _paper,
                      child: ReceiptPaper(
                        size: size,
                        child: ReceiptView(order: o, restaurant: restaurant, money: obj(_data?['money']), label: (k) => ctx.rp('receipt.$k'), paidView: o['status'] == 'paid', showVoid: true),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  meta(ctx.rp('colStatus'), Align(alignment: Alignment.centerLeft, child: _statusChip(ctx, str(o['status'])))),
                  meta(ctx.rp('colWhere'), Text(str(o['table_name']).isEmpty ? ctx.rp('takeaway') : str(o['table_name']))),
                  meta(ctx.rp('openedBy'), Text(str(obj(o['opened_by'])['name']).isEmpty ? '—' : str(obj(o['opened_by'])['name']))),
                  meta(ctx.rp('openedAt'), Text(whenLong(o['opened_at'], ctx.lang))),
                  if (o['paid_at'] != null) meta(ctx.rp('paidAt'), Text('${whenLong(o['paid_at'], ctx.lang)} · ${str(obj(o['closed_by'])['name'])}')),
                  if (str(o['device_name']).isNotEmpty) meta(ctx.rp('device'), Text(str(o['device_name']))),
                  if (n(o['guests']) > 0) meta(ctx.rp('guests'), Text(fmt(o['guests']))),
                  if (str(o['void_reason']).isNotEmpty) meta(ctx.rp('reason'), Text('${str(o['void_reason'])} · ${str(obj(o['closed_by'])['name'])}')),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------ shifts
// one shift: when, device, who, bills, sales, cash difference (USD · KHR)
class ShiftTile extends StatelessWidget {
  final RestCtx ctx;
  final Json s;
  final String device;
  final String currency;
  const ShiftTile({super.key, required this.ctx, required this.s, required this.device, required this.currency});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final closed = s['status'] == 'closed';
    final du = n(obj(s['counted'])['usd']) - n(obj(s['expected'])['usd']);
    final dk = n(obj(s['counted'])['khr']) - n(obj(s['expected'])['khr']);
    final who = str(obj(s['closed_by'])['name']).isNotEmpty ? str(obj(s['closed_by'])['name']) : str(obj(s['opened_by'])['name']);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  closed ? '${whenShort(s['opened_at'], ctx.lang)} → ${s['closed_at'] == null ? '' : whenShort(s['closed_at'], ctx.lang).split(', ').last}' : whenShort(s['opened_at'], ctx.lang),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text([device, who].where((x) => x.isNotEmpty).join(' · '), style: TextStyle(color: c.muted, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (!closed)
            Chip2(ctx.rp('shiftOpen'), tone: Tone.brand)
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fmtMoney(n(obj(s['totals'])['sales']), currency), style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('${fmt(obj(s['totals'])['bills'])} ${ctx.rp('bills').toLowerCase()}', style: TextStyle(color: c.muted, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  '${du >= 0 ? '+' : '−'}${fmtMoney(du.abs(), 'USD')} · ${dk >= 0 ? '+' : '−'}${fmtMoney(dk.abs(), 'KHR')}',
                  style: TextStyle(color: du < 0 || dk < 0 ? c.danger : c.good, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class ShiftsList extends StatefulWidget {
  final RestCtx ctx;
  final List<Widget> top;
  const ShiftsList({super.key, required this.ctx, this.top = const []});
  @override
  State<ShiftsList> createState() => _ShiftsListState();
}

class _ShiftsListState extends State<ShiftsList> {
  int _page = 1;
  Json? _data;
  String _error = '';
  RestCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/pos/shifts', {'page': _page});
      if (mounted) setState(() => _data = r);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiError ? (e.network ? ctx.t('app.offline') : e.message) : ctx.rp('loadFail'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final data = _data;
    final rows = objs(data?['data']);
    final pg = obj(data?['pagination']);
    final list = <Widget>[...widget.top];
    if (data == null) {
      list.add(_error.isNotEmpty ? LoadError(text: _error, retry: ctx.rp('refresh'), onRetry: _load) : const Panel(child: SkelList(rows: 5)));
    } else {
      list.add(
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 6), child: Muted(ctx.rp('shiftsSub'))),
              if (rows.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Muted(ctx.rp('noShifts'))),
              for (final (i, s) in rows.indexed) ...[
                if (i > 0) Divider(height: 1, color: c.line, indent: 16, endIndent: 16),
                ShiftTile(ctx: ctx, s: s, device: str(s['device_name']), currency: ctx.currency),
              ],
            ],
          ),
        ),
      );
      if (n(pg['totalPages']) > 1) {
        list.add(
          _Pager(
            page: n(pg['currentPage']).toInt(),
            pages: n(pg['totalPages']).toInt(),
            text: ctx.rp('page', {'p': pg['currentPage'], 'n': pg['totalPages']}),
            onPage: (p) {
              setState(() => _page = p);
              _load();
            },
          ),
        );
      }
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: list),
    );
  }
}
