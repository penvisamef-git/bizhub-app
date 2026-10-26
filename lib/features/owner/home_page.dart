import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../common/delete_account.dart';
import '../common/shell.dart';
import '../common/open_business.dart';
import '../team/team_text.dart' show teamText;
import 'data.dart';

const bizTypes = ['namecard', 'menu_qr', 'flipbook', 'qr_gen', 'website', 'restaurant', 'attendance', 'guest_house', 'mart', 'debt_book', 'stamp_card', 'event', 'digital_note', 'tg_store'];
num? _pct(num now, num before) => before > 0 ? ((now - before) / before * 100).round() : null;

// Owner home = the web dashboard (dashboard/client/DashboardPage.jsx), top to bottom.
class OwnerHomePage extends ConsumerStatefulWidget {
  const OwnerHomePage({super.key});
  @override
  ConsumerState<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends ConsumerState<OwnerHomePage> {
  Future<void> _reload() async {
    ref.invalidate(dashboardProvider);
    try {
      await ref.read(dashboardProvider.future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final s = ref.watch(sessionProvider);
    final async = ref.watch(dashboardProvider);
    final data = async.valueOrNull;
    final welcome = ref.watch(welcomeProvider);
    final hour = DateTime.now().hour;
    final hello = hour < 12
        ? t('dash.morning')
        : hour < 18
        ? t('dash.afternoon')
        : t('dash.evening');
    final sales = data == null ? null : (data['sales'] is Map ? obj(data['sales']) : null);
    final list = objs(data?['businesses']);

    return TabPage(
      onRefresh: _reload,
      children: [
        const DeletionBanner(), // "Delete my account" pending / just cancelled
        if (welcome)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Alert(
              t('messages.welcomeBonus', {'coins': fmt(s?.coins)}),
              tone: Tone.good,
              action: GestureDetector(
                onTap: () => ref.read(welcomeProvider.notifier).state = false,
                child: Text(
                  t('messages.close'),
                  style: TextStyle(fontWeight: FontWeight.w800, color: context.c.good),
                ),
              ),
            ),
          ),
        Text('$hello, ${s?.name ?? ''}', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        Row(
          children: [_UpdatedChip(loading: async.isLoading, at: data?['at'], t: t, onTap: _reload)],
        ),
        const SizedBox(height: 16),
        if (async.hasError && data == null) ...[LoadError(text: t('dash.errorLoad'), retry: t('app.retry'), onRetry: _reload), const SizedBox(height: 16)],
        CoinCard(coins: data == null ? null : obj(data['coins']), name: s?.name ?? '', balance: s?.coins ?? 0, t: t),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Btn(t('dash.topUp'), icon: LucideIcons.plus, small: true, onTap: () => context.push('/o/coins')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Btn(t('dash.history'), icon: LucideIcons.history, small: true, kind: BtnKind.ghost, onTap: () => context.go('/o/wallet')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (data == null && !async.hasError) ...[
          const Panel(child: SkelList(rows: 3)),
        ] else if (sales != null) ...[
          _TodayCard(sales: sales, t: t),
          const SizedBox(height: 14),
          _WeekCard(sales: sales, t: t),
          const SizedBox(height: 14),
          _SalesChart(sales: sales, t: t),
          const SizedBox(height: 14),
          _TopItems(items: objs(data?['top_items']), t: t, currency: str(sales['currency']), many: objs(sales['by_business']).length > 1),
        ] else if (data != null)
          Panel(
            child: Row(
              children: [
                Icon(LucideIcons.sparkles, color: context.c.brand, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(list.isNotEmpty ? t('dash.chartEmpty') : t('dash.none'), style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Muted(t('dash.noneSub')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        _RightNow(tiles: data == null ? null : objs(data['now']), t: t),
      ],
    );
  }
}

class _UpdatedChip extends StatelessWidget {
  final bool loading;
  final Object? at;
  final T t;
  final VoidCallback onTap;
  const _UpdatedChip({required this.loading, required this.at, required this.t, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.card,
      shape: StadiumBorder(side: BorderSide(color: c.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              loading ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.muted)) : Icon(LucideIcons.refreshCw, size: 14, color: c.muted),
              const SizedBox(width: 8),
              Text(
                at == null ? t('dash.refresh') : t('dash.updated', {'t': fmtTime(at)}),
                style: TextStyle(color: c.muted, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// a payment-card look: chip, balance, masked wallet number, holder (db-card)
class CoinCard extends StatelessWidget {
  final Json? coins;
  final String name;
  final num balance;
  final T t;
  const CoinCard({super.key, required this.coins, required this.name, required this.balance, required this.t});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bal = coins?['balance'] ?? balance;
    final w = str(coins?['wallet']);
    final last4 = w.length >= 4 ? w.substring(w.length - 4).toUpperCase() : '••••';
    TextStyle small = const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xD9FFFFFF), letterSpacing: .8);
    return AspectRatio(
      aspectRatio: 1.586,
      child: Container(
        decoration: BoxDecoration(gradient: c.gradient, borderRadius: BorderRadius.circular(20), boxShadow: c.orangeShadow),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => context.go('/o/wallet'),
            child: Stack(
              children: [
                Positioned(
                  right: -90,
                  top: -110,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .14)),
                  ),
                ),
                Positioned(
                  left: -70,
                  bottom: -130,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: .1)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CoinIcon(size: 20),
                          const SizedBox(width: 8),
                          Text(
                            t('dash.coinCard'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const Spacer(),
                          const _CardChip(),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        fmt(bal),
                        style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -.3, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                      Text(
                        '••••  ••••  ••••  $last4',
                        style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13, letterSpacing: 2, fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t('dash.holder').toUpperCase(), style: small),
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          if (coins != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(t('dash.spent30').toUpperCase(), style: small),
                                Text(
                                  fmt(coins!['spent_30d']),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardChip extends StatelessWidget {
  const _CardChip();
  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      gradient: const LinearGradient(colors: [Color(0xFFF6E3A6), Color(0xFFD8B45A), Color(0xFFF3DC95)], stops: [0, .6, 1]),
      border: Border.all(color: const Color(0x59785A14)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(3, (_) => Container(height: 1, color: const Color(0x73785A14))),
    ),
  );
}

class _Delta extends StatelessWidget {
  final num now, before;
  final String label, none;
  const _Delta({required this.now, required this.before, required this.label, required this.none});
  @override
  Widget build(BuildContext context) {
    final p = _pct(now, before);
    if (p == null) return Chip2(none);
    final up = p >= 0;
    return Chip2('${p.abs()}% $label', tone: up ? Tone.good : Tone.danger, icon: up ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight);
  }
}

Widget _kpiRow(BuildContext context, List<(String, String)> items) => Padding(
  padding: const EdgeInsets.only(top: 16),
  child: Row(
    children: [
      for (final it in items)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(it.$1, style: Theme.of(context).textTheme.bodySmall),
              Text(it.$2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
        ),
    ],
  ),
);

class _TodayCard extends StatelessWidget {
  final Json sales;
  final T t;
  const _TodayCard({required this.sales, required this.t});
  @override
  Widget build(BuildContext context) {
    final cur = str(sales['currency']);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('dash.today'), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 14)),
          Text(money(sales['today'], cur), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -.5)),
          const SizedBox(height: 6),
          _Delta(now: n(sales['today']), before: n(sales['yesterday']), label: t('dash.vsYesterday'), none: t('dash.noYesterday')),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              text: '${t('dash.yesterday')} ',
              children: [
                TextSpan(
                  text: money(sales['yesterday'], cur),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            style: TextStyle(color: context.c.muted, fontSize: 13.5),
          ),
          _kpiRow(context, [(t('dash.bills'), fmt(sales['bills_today'])), (t('dash.avgBill'), money(sales['avg_today'], cur)), (t('dash.openNow'), fmt(sales['open_now']))]),
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  final Json sales;
  final T t;
  const _WeekCard({required this.sales, required this.t});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cur = str(sales['currency']);
    final start = str(sales['week_start']);
    final week = objs(sales['days']).where((x) => str(x['day']).compareTo(start) >= 0).toList();
    final mx = week.fold<num>(1, (a, x) => math.max(a, n(x['sales'])));
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: t('dash.week'),
              children: [TextSpan(text: ' · ${t('dash.sinceMon')}', style: const TextStyle(fontSize: 12))],
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 14),
          ),
          Text(money(sales['week'], cur), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -.5)),
          const SizedBox(height: 6),
          _Delta(now: n(sales['week']), before: n(sales['last_week']), label: t('dash.vsLastWeek'), none: t('dash.noLastWeek')),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              text: '${t('dash.lastWeekSame')} ',
              children: [
                TextSpan(
                  text: money(sales['last_week'], cur),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            style: TextStyle(color: c.muted, fontSize: 13.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 46,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final x = i < week.length ? week[i] : null;
                final h = x == null ? .06 : math.max(.06, n(x['sales']) / mx);
                final now = x != null && i == week.length - 1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: FractionallySizedBox(
                      heightFactor: h.toDouble(),
                      child: Container(
                        decoration: BoxDecoration(color: x == null ? c.chip : (now ? null : c.brand.withValues(alpha: .35)), gradient: now ? c.gradient : null, borderRadius: BorderRadius.circular(5)),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          _kpiRow(context, [(t('dash.bills'), fmt(sales['bills_week'])), (t('dash.month'), money(sales['month'], cur))]),
        ],
      ),
    );
  }
}

// 14 bars, today darkest; tap a bar to read that day
class _SalesChart extends StatefulWidget {
  final Json sales;
  final T t;
  const _SalesChart({required this.sales, required this.t});
  @override
  State<_SalesChart> createState() => _SalesChartState();
}

class _SalesChartState extends State<_SalesChart> {
  int? _sel;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = widget.t;
    final cur = str(widget.sales['currency']);
    final days = objs(widget.sales['days']);
    final mx = days.fold<num>(0, (a, x) => math.max(a, n(x['sales'])));
    final last = days.length - 1;
    final h = _sel ?? last;
    String label(String day) {
      final d = DateTime.tryParse(day);
      if (d == null) return day;
      return '${d.day}/${d.month}';
    }

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SecHead(t('dash.chart')),
          if (mx <= 0 || days.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Muted(t('dash.chartEmpty'), align: TextAlign.center)),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(money(days[h]['sales'], cur), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(h == last ? t('dash.todayBar') : label(str(days[h]['day'])), style: TextStyle(color: c.muted, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < days.length; i++)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _sel = i),
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: n(days[i]['sales']) > 0 ? math.max(.02, n(days[i]['sales']) / mx).toDouble() : 0.0,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                    decoration: BoxDecoration(
                                      gradient: i == last || i == h ? c.gradient : null,
                                      color: i == last || i == h ? null : c.brand.withValues(alpha: .3),
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 14,
                              child: Text(
                                i % 2 == last % 2 ? (i == last ? t('dash.todayBar') : label(str(days[i]['day']))) : '',
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                                softWrap: false,
                                style: TextStyle(fontSize: 9.5, color: c.muted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopItems extends StatelessWidget {
  final List<Json> items;
  final T t;
  final String currency;
  final bool many;
  const _TopItems({required this.items, required this.t, required this.currency, required this.many});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final mx = items.fold<num>(1, (a, x) => math.max(a, n(x['qty'])));
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SecHead(t('dash.top')),
          if (items.isEmpty) Muted(t('dash.topEmpty')),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: i == 0 ? c.brand : c.chip, shape: BoxShape.circle),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: i == 0 ? Colors.white : c.muted),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (t.km
                                  ? (str(items[i]['name_km']).isNotEmpty ? items[i]['name_km'] : items[i]['name_en'])
                                  : (str(items[i]['name_en']).isNotEmpty ? items[i]['name_en'] : items[i]['name_km'])) ??
                              '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${t('dash.sold', {'n': fmt(items[i]['qty'])})}${many && str(items[i]['business']).isNotEmpty ? ' · ${items[i]['business']}' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: LinearProgressIndicator(value: (n(items[i]['qty']) / mx).toDouble(), minHeight: 5, backgroundColor: c.chip, color: c.brand),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(money(items[i]['value'], currency), style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String bizSub(Json b, T t) {
  var s = t('sa.categoryNames.${b['category']}');
  if (b['namecard'] is Map && str(obj(b['namecard'])['slug']).isNotEmpty) s += ' · /${obj(b['namecard'])['slug']}';
  if (b['website'] is Map && str(obj(b['website'])['slug']).isNotEmpty) s += ' · /site/${obj(b['website'])['slug']}';
  return s;
}

class BusinessList extends ConsumerStatefulWidget {
  final List<Json> list;
  final Json? sales;
  final T t;
  final TextEditingController q;
  final String type;
  final ValueChanged<String> onType;
  final bool loading;
  const BusinessList({super.key, required this.list, required this.sales, required this.t, required this.q, required this.type, required this.onType, required this.loading});
  @override
  ConsumerState<BusinessList> createState() => _BusinessListState();
}

// My businesses: search + type filter, list or grid (this phone), and the owner's own order (saved on the server,
// the same on the web) — Arrange: drag a business, or use the arrows.
class _BusinessListState extends ConsumerState<BusinessList> {
  late String _view = prefStr('bizhub_biz_view') ?? 'list';
  bool _arrange = false;
  List<String>? _order;
  bool _saving = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _pickView(String v) {
    prefSetStr('bizhub_biz_view', v);
    setState(() => _view = v);
  }

  List<Json> get _sorted {
    final order = _order;
    if (order == null) return widget.list;
    final byId = {for (final b in widget.list) str(b['_id']): b};
    return [...order.map((id) => byId[id]).whereType<Json>(), ...widget.list.where((b) => !order.contains(str(b['_id'])))];
  }

  void _move(String id, int to) {
    final ids = _sorted.map((b) => str(b['_id'])).toList();
    final from = ids.indexOf(id);
    if (from < 0 || to < 0 || to >= ids.length || from == to) return;
    ids.insert(to, ids.removeAt(from));
    setState(() => _order = ids);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), () => _save(ids));
  }

  Future<void> _save(List<String> ids) async {
    setState(() => _saving = true);
    try {
      await ref.read(apiProvider).put('${Api.user}/businesses-order', {'ids': ids});
      ref.invalidate(dashboardProvider);
    } on ApiError catch (e) {
      if (mounted) toast(context, e.network ? widget.t('app.offline') : e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _start() {
    widget.q.clear();
    widget.onType('');
    setState(() {
      _order = widget.list.map((b) => str(b['_id'])).toList();
      _arrange = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final list = widget.list;
    final c = context.c;
    final counts = <String, int>{};
    for (final b in list) {
      counts[str(b['category'])] = (counts[str(b['category'])] ?? 0) + 1;
    }
    final types = bizTypes.where((k) => counts.containsKey(k)).toList();
    final qq = widget.q.text.trim().toLowerCase();
    final sorted = _sorted;
    final shown = _arrange
        ? sorted
        : sorted.where((b) => (widget.type.isEmpty || b['category'] == widget.type) && (qq.isEmpty || str(b['name']).toLowerCase().contains(qq) || str(obj(b['namecard'])['slug']).toLowerCase().contains(qq))).toList();
    final per = {for (final x in objs(widget.sales?['by_business'])) str(x['id']): x};
    final grid = _view == 'grid';
    Widget item(Json b, int i) {
      final id = str(b['_id']);
      final arrange = _arrange ? _Arrange(i: i, n: shown.length, up: () => _move(id, i - 1), down: () => _move(id, i + 1), top: () => _move(id, 0)) : null;
      return grid ? _BizCard(b: b, per: per[id], t: t, arrange: arrange) : _BizRow(b: b, per: per[id], t: t, arrange: arrange);
    }

    Widget body;
    if (grid) {
      body = LayoutBuilder(
        builder: (context, box) {
          final cols = box.maxWidth >= 720 ? 4 : (box.maxWidth >= 480 ? 3 : 2);
          const gap = 10.0;
          final w = (box.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < shown.length; i++)
                SizedBox(
                  width: w,
                  child: _arrange
                      // drag a card onto another one to put it there
                      ? DragTarget<String>(
                          onWillAcceptWithDetails: (d) {
                            if (d.data != str(shown[i]['_id'])) _move(d.data, i);
                            return true;
                          },
                          builder: (context, _, _) => LongPressDraggable<String>(
                            data: str(shown[i]['_id']),
                            delay: const Duration(milliseconds: 180),
                            feedback: Material(color: Colors.transparent, child: SizedBox(width: w, child: Opacity(opacity: .9, child: item(shown[i], i)))),
                            childWhenDragging: Opacity(opacity: .35, child: item(shown[i], i)),
                            child: item(shown[i], i),
                          ),
                        )
                      : item(shown[i], i),
                ),
            ],
          );
        },
      );
    } else if (_arrange) {
      body = ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: shown.length,
        // ignore: deprecated_member_use (onReorderItem is only in the newest Flutter)
        onReorder: (from, to) => _move(str(shown[from]['_id']), to > from ? to - 1 : to),
        proxyDecorator: (child, _, _) => Material(color: c.card, elevation: 6, borderRadius: BorderRadius.circular(16), child: child),
        itemBuilder: (context, i) => ReorderableDelayedDragStartListener(key: ValueKey(str(shown[i]['_id'])), index: i, child: item(shown[i], i)),
      );
    } else {
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < shown.length; i++) item(shown[i], i)]);
    }

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SecHead(
            t('dash.businesses'),
            trailing: _arrange
                ? Btn(t('dash.arrangeDone'), icon: _saving ? LucideIcons.loaderCircle : LucideIcons.check, small: true, onTap: () => setState(() => _arrange = false))
                : Btn(t('dash.add'), icon: LucideIcons.plus, small: true, onTap: () => context.push('/o/add')),
          ),
          if (list.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  _ViewSwitch(grid: grid, onPick: _pickView, t: t),
                  const Spacer(),
                  if (list.length > 1 && !_arrange)
                    TextButton.icon(onPressed: _start, icon: const Icon(LucideIcons.arrowUpDown, size: 16), label: Text(t('dash.arrange'))),
                ],
              ),
            ),
          if (_arrange)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(12)),
              child: Text(t('dash.arrangeHint'), style: TextStyle(fontSize: 13, color: c.brandInk)),
            ),
          if (list.length > 1 && !_arrange) ...[
            Field(controller: widget.q, hint: t('dash.bizSearch'), icon: LucideIcons.search, onChanged: (_) => setState(() {})),
            if (types.length > 1) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(label: t('sa.allCategories'), count: list.length, on: widget.type.isEmpty, onTap: () => widget.onType('')),
                    for (final k in types) _FilterChip(label: t('sa.categoryNames.$k'), count: counts[k]!, on: widget.type == k, onTap: () => widget.onType(k)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
          if (widget.loading) const SkelList(rows: 3),
          if (!widget.loading && list.isEmpty) ...[Muted(t('dash.none')), const SizedBox(height: 12), Btn(t('app.addFirst'), icon: LucideIcons.plus, onTap: () => context.push('/o/add'), expand: true)],
          if (!widget.loading && list.isNotEmpty && shown.isEmpty) Muted(t('dash.bizNoMatch')),
          if (!widget.loading && shown.isNotEmpty) body,
        ],
      ),
    );
  }
}

class _Arrange {
  final int i, n;
  final VoidCallback up, down, top;
  const _Arrange({required this.i, required this.n, required this.up, required this.down, required this.top});
}

class _ViewSwitch extends StatelessWidget {
  final bool grid;
  final ValueChanged<String> onPick;
  final T t;
  const _ViewSwitch({required this.grid, required this.onPick, required this.t});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget one(String v, IconData icon, String tip) {
      final on = (v == 'grid') == grid;
      return Tooltip(
        message: tip,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => onPick(v),
          child: Container(
            width: 34,
            height: 32,
            decoration: BoxDecoration(color: on ? c.card : Colors.transparent, borderRadius: BorderRadius.circular(9), boxShadow: on ? c.cardShadow : null),
            child: Icon(icon, size: 16, color: on ? c.ink : c.muted),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(11)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [one('list', LucideIcons.list, t('dash.viewList')), one('grid', LucideIcons.layoutGrid, t('dash.viewGrid'))]),
    );
  }
}

// the arrows while arranging (in a grid: left / right)
class _MoveBtns extends StatelessWidget {
  final _Arrange a;
  final T t;
  final bool grid;
  const _MoveBtns({required this.a, required this.t, this.grid = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget b(IconData icon, String tip, VoidCallback? onTap) => IconButton(
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: Icon(icon, size: 17, color: onTap == null ? c.muted.withValues(alpha: .35) : c.ink),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        b(LucideIcons.chevronsUp, t('dash.moveTop'), a.i == 0 ? null : a.top),
        b(grid ? LucideIcons.arrowLeft : LucideIcons.arrowUp, t('dash.moveUp'), a.i == 0 ? null : a.up),
        b(grid ? LucideIcons.arrowRight : LucideIcons.arrowDown, t('dash.moveDown'), a.i >= a.n - 1 ? null : a.down),
      ],
    );
  }
}

class _BizIcon extends StatelessWidget {
  final Json b;
  final double size;
  const _BizIcon({required this.b, this.size = 46});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final photo = b['photo'] is Map ? str(obj(b['photo'])['url']) : str(b['photo']);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.active,
        borderRadius: BorderRadius.circular(size * .3),
        image: photo.isNotEmpty ? DecorationImage(image: netImage(photo), fit: BoxFit.cover) : null,
      ),
      child: photo.isNotEmpty ? null : Icon(rowIcons[str(b['category'])] ?? LucideIcons.sparkles, size: size * .42, color: c.brandInk),
    );
  }
}

String? _endsText(Json b, T t) {
  final lic = obj(b['license']);
  final status = str(lic['status']);
  if (status.isEmpty || status == 'none' || status == 'forever') return null;
  return status == 'expired' ? t('messages.bizExpired') : t(status == 'expiring' ? 'messages.bizEndsSoon' : 'messages.bizEnds', {'date': fmtDate(lic['expires_at'], lang: t.lang)});
}

class _BizCard extends StatelessWidget {
  final Json b;
  final Json? per;
  final T t;
  final _Arrange? arrange;
  const _BizCard({required this.b, required this.per, required this.t, this.arrange});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cat = str(b['category']);
    final status = str(obj(b['license'])['status']);
    final ends = _endsText(b, t);
    final pos = per != null && ['restaurant', 'guest_house', 'mart'].contains(cat);
    return Material(
      color: arrange != null ? c.chip : c.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: arrange != null ? null : () => openBusiness(context, id: str(b['_id']), name: str(b['name']), category: cat),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: c.line)),
          padding: const EdgeInsets.fromLTRB(12, 12, 6, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BizIcon(b: b, size: 54),
                  const Spacer(),
                  if (arrange != null)
                    Padding(padding: const EdgeInsets.all(6), child: Icon(LucideIcons.gripVertical, size: 16, color: c.muted))
                  else ...[
                    // Team access (v1.5): who else can open this business
                    IconButton(
                      key: ValueKey('team-open-${b['_id']}'),
                      tooltip: teamText[t.lang]?['team'] ?? 'Team',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => context.push(Uri(path: '/o/team/${b['_id']}', queryParameters: {'name': str(b['name'])}).toString()),
                      icon: Icon(LucideIcons.users, size: 15, color: c.muted),
                    ),
                    IconButton(
                      tooltip: t('dash.edit'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => context.push('/o/add', extra: b),
                      icon: Icon(LucideIcons.pencil, size: 15, color: c.muted),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(str(b['name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text(bizSub(b, t), maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
              if (ends != null)
                Text(
                  ends,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: status == 'expired' ? c.danger : (status == 'expiring' ? c.warn : c.muted)),
                ),
              if (pos) ...[
                const SizedBox(height: 6),
                Text(money(per!['today'], str(per!['currency'])), style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(t('dash.todaySales'), style: Theme.of(context).textTheme.bodySmall),
              ],
              if (b['status'] == false) ...[const SizedBox(height: 6), Chip2(t('sa.suspended'), tone: Tone.danger)],
              if (arrange != null) Center(child: _MoveBtns(a: arrange!, t: t, grid: true)) else const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool on;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.count, required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: on ? c.solid : c.chip,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: on ? c.onSolid : c.ink),
                ),
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on ? c.onSolid.withValues(alpha: .7) : c.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BizRow extends StatelessWidget {
  final Json b;
  final Json? per;
  final T t;
  final _Arrange? arrange;
  const _BizRow({required this.b, required this.per, required this.t, this.arrange});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cat = str(b['category']);
    final lic = obj(b['license']);
    final status = str(lic['status']);
    final photo = b['photo'] is Map ? str(obj(b['photo'])['url']) : str(b['photo']);
    String? ends;
    if (status.isNotEmpty && status != 'none' && status != 'forever') {
      ends = status == 'expired' ? t('messages.bizExpired') : t(status == 'expiring' ? 'messages.bizEndsSoon' : 'messages.bizEnds', {'date': fmtDate(lic['expires_at'], lang: t.lang)});
    }
    final pos = per != null && ['restaurant', 'guest_house', 'mart'].contains(cat);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: arrange != null ? null : () => openBusiness(context, id: str(b['_id']), name: str(b['name']), category: cat),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            if (arrange != null) ...[Icon(LucideIcons.gripVertical, size: 18, color: c.muted), const SizedBox(width: 6)],
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: c.active,
                borderRadius: BorderRadius.circular(14),
                image: photo.isNotEmpty ? DecorationImage(image: netImage(photo), fit: BoxFit.cover) : null,
              ),
              child: photo.isNotEmpty ? null : Icon(rowIcons[cat] ?? LucideIcons.sparkles, size: 19, color: c.brandInk),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    str(b['name']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  Text(bizSub(b, t), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                  if (ends != null)
                    Text(
                      ends,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: status == 'expired' ? c.danger : (status == 'expiring' ? c.warn : c.muted)),
                    ),
                ],
              ),
            ),
            if (pos)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(money(per!['today'], str(per!['currency'])), style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(
                    '${t('dash.todaySales')}${n(per!['open_now']) > 0 ? ' · ${per!['kind'] == 'guest_house' ? t('dash.inHouse', {'n': per!['open_now']}) : t('dash.open', {'n': per!['open_now']})}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            if (b['namecard'] is Map)
              Row(
                children: [
                  Icon(LucideIcons.eye, size: 13, color: c.muted),
                  const SizedBox(width: 4),
                  Text(fmt(obj(b['namecard'])['views']), style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            if (b['status'] == false) ...[const SizedBox(width: 6), Chip2(t('sa.suspended'), tone: Tone.danger)],
            if (arrange != null)
              _MoveBtns(a: arrange!, t: t)
            else ...[
              IconButton(
                key: ValueKey('team-open-${b['_id']}'),
                tooltip: teamText[t.lang]?['team'] ?? 'Team',
                onPressed: () => context.push(Uri(path: '/o/team/${b['_id']}', queryParameters: {'name': str(b['name'])}).toString()),
                icon: Icon(LucideIcons.users, size: 16, color: c.muted),
              ),
              IconButton(
                tooltip: t('dash.edit'),
                onPressed: () => context.push('/o/add', extra: b),
                icon: Icon(LucideIcons.pencil, size: 16, color: c.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const _nowIcons = <String, IconData>{
  'waiting': LucideIcons.bellRing,
  'in_house': LucideIcons.bedDouble,
  'open_bills': LucideIcons.chefHat,
  'staff_in': LucideIcons.fingerprint,
  'messages': LucideIcons.inbox,
  'stock': LucideIcons.packageX,
  'new_customers': LucideIcons.userPlus,
  'renewals': LucideIcons.calendarClock,
};

class _RightNow extends StatelessWidget {
  final List<Json>? tiles;
  final T t;
  const _RightNow({required this.tiles, required this.t});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SecHead(t('dash.nowTitle'), sub: t('dash.nowSub')),
          if (tiles == null) const SkelList(rows: 2),
          if (tiles != null && tiles!.isEmpty) Muted(t('dash.nowEmpty')),
          if (tiles != null && tiles!.isNotEmpty && !tiles!.any(_busy)) Muted(t('dash.allQuiet')),
          // tiles with something to do first; the quiet ones shrink to chips underneath
          if (tiles != null && tiles!.any(_busy))
            LayoutBuilder(
              builder: (context, box) {
                final w = (box.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final x in tiles!.where(_busy))
                      SizedBox(
                        width: w,
                        child: _Tile(x: x, t: t, c: c),
                      ),
                  ],
                );
              },
            ),
          if (tiles != null && tiles!.any((x) => !_busy(x))) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final x in tiles!.where((x) => !_busy(x)))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(999)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_nowIcons[str(x['key'])] ?? LucideIcons.sparkles, size: 13, color: c.muted),
                        const SizedBox(width: 5),
                        Text(
                          '${t.list('dash.now.${x['key']}').firstOrNull ?? x['key']}  0',
                          style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// a tile with something in it (staff: also when someone is late / not in yet)
bool _busy(Json x) => n(x['n']) > 0 || (x['key'] == 'staff_in' && (n(x['late']) > 0 || n(x['not_in']) > 0));

class _Tile extends StatelessWidget {
  final Json x;
  final T t;
  final C c;
  const _Tile({required this.x, required this.t, required this.c});
  @override
  Widget build(BuildContext context) {
    final key = str(x['key']);
    final count = n(x['n']);
    final pair = t.list('dash.now.$key'); // [title, sub]
    final title = pair.isNotEmpty ? pair[0] : key;
    final warnStaff = key == 'staff_in' && (n(x['late']) > 0 || n(x['not_in']) > 0);
    final subRaw = warnStaff ? t('dash.staffWarn') : (pair.length > 1 ? pair[1] : '');
    final sub = subRaw
        .replaceAll('{late}', '${x['late'] ?? 0}')
        .replaceAll('{notin}', '${x['not_in'] ?? 0}')
        .replaceAll('{n}', '${x['of'] ?? ''}')
        .replaceAll('{out}', '${x['out'] ?? 0}')
        .replaceAll('{low}', '${x['low'] ?? 0}')
        .replaceAll('{date}', x['soonest'] != null ? fmtDate(x['soonest'], lang: t.lang) : '—');
    final by = objs(x['by']);
    final hot = warnStaff || (count > 0 && ['waiting', 'messages', 'stock', 'renewals'].contains(key));
    final first = by.isNotEmpty ? by.first : null;
    final tab = first == null ? '' : str(obj(x['tab'])[str(first['kind'])]);
    VoidCallback? go;
    if (count > 0 || warnStaff) {
      if (key == 'renewals') {
        go = () => context.push('/o/licenses');
      } else if (first != null) {
        go = () => openBusiness(context, id: str(first['id']), name: str(first['name']), category: str(first['kind']), tab: tab);
      }
    }
    return Material(
      color: hot ? c.active : c.bg2,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: go,
        child: Opacity(
          opacity: count == 0 && key != 'staff_in' ? .75 : 1,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: hot ? c.brand : c.active, borderRadius: BorderRadius.circular(10)),
                      child: Icon(_nowIcons[key] ?? LucideIcons.sparkles, size: 16, color: hot ? Colors.white : c.brandInk),
                    ),
                    const Spacer(),
                    Text.rich(
                      TextSpan(
                        text: fmt(count),
                        children: [
                          if (key == 'staff_in' && x['of'] != null)
                            TextSpan(
                              text: '/${fmt(x['of'])}',
                              style: TextStyle(fontSize: 13, color: c.muted),
                            ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                Text(
                  sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12, color: warnStaff ? c.warn : null, fontWeight: warnStaff ? FontWeight.w700 : null),
                ),
                for (final b in by.take(3))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${b['name']} · ${fmt(b['n'])}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: c.brandInk, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
