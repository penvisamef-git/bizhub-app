import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/buy_sheet.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show GoldBtn;
import '../team/team_frame.dart' show TeamTopBtn;
import 'ts_common.dart';
import 'ts_customers.dart';
import 'ts_design.dart';
import 'ts_grow.dart';
import 'ts_orders.dart';
import 'ts_products.dart';
import 'ts_setup.dart';
import 'ts_share.dart';
import 'ts_staff.dart';
import 'ts_themes.dart';

// Telegram Store — the app version of the web's TgStoreDashboard.jsx (same API, same words, same sections), all native.
const _tabs = <String, IconData>{
  'orders': LucideIcons.receiptText,
  'products': LucideIcons.package,
  'customers': LucideIcons.users,
  'staff': LucideIcons.monitorSmartphone,
  'promos': LucideIcons.tag,
  'messages': LucideIcons.megaphone,
  'remind': LucideIcons.shoppingCart,
  'report': LucideIcons.chartColumn,
  'store': LucideIcons.settings,
  'delivery': LucideIcons.truck,
  'design': LucideIcons.palette,
  'share': LucideIcons.share2,
  'addons': LucideIcons.puzzle,
};
const _groups = <(String, List<String>)>[
  ('sell', ['orders', 'products', 'customers', 'staff']),
  ('grow', ['promos', 'messages', 'remind', 'report']),
  ('setup', ['store', 'delivery', 'design', 'share', 'addons']),
];
const _needs = {'promos': 'ts_promos', 'messages': 'ts_broadcast', 'remind': 'ts_remind', 'report': 'ts_reports'};
const _graceDays = 7;

class TgStorePage extends ConsumerStatefulWidget {
  final String id, title, tab;
  const TgStorePage({super.key, required this.id, this.title = '', this.tab = ''});
  @override
  ConsumerState<TgStorePage> createState() => _TgStorePageState();
}

class _TgStorePageState extends ConsumerState<TgStorePage> {
  Json? _data;
  String _error = '';
  String? _tab;
  int _nav = 0;

  String get _base => '${Api.user}/businesses/${widget.id}/tgstore';
  String get _current => _tab ?? (_tabs.containsKey(widget.tab) ? widget.tab : 'orders');

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final r = await ref.read(apiProvider).get(_base);
      if (!mounted) return;
      setState(() {
        _data = obj(r['data']);
        _error = '';
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.network ? ref.read(tProvider)('app.offline') : (e.message.isNotEmpty ? e.message : ref.read(tProvider)('ts.loadFail')));
    }
  }

  void _go(String tab) => setState(() {
    _tab = tab;
    _nav++;
  });

  TsCtx _ctx() => TsCtx(
    id: widget.id,
    api: ref.read(apiProvider),
    t: ref.read(tProvider),
    data: _data!,
    reload: _reload,
    put: (patch) => setState(() => _data = {..._data!, ...patch}),
    askBuy: _buy,
    go: _go,
    notify: (text) => toast(context, text),
  );

  // renew · an add-on · a store design
  Future<void> _buy(String kind, {String? item}) async {
    final ctx = _ctx();
    final api = ref.read(apiProvider);
    final lic = ctx.license;
    late final String name, title, sub, label, done;
    late final List<String> perks;
    late final num price;
    late final Future<Json> Function() buy;
    IconData icon = LucideIcons.puzzle;
    Widget? stage;
    if (kind == 'renew') {
      price = n(lic['price']);
      name = ctx.m('renewTitle');
      title = name;
      sub = ctx.m('renewSub');
      perks = ['${fmt(price)} ${ctx.m('coins')} ${ctx.m('perYear')}'];
      label = ctx.m('renewFor', {'coins': fmt(price)});
      done = ctx.m('renewTitle');
      icon = LucideIcons.send;
      buy = () => api.post('${Api.user}/businesses/${widget.id}/licenses/tg_store', {'expect': lic['expires_at']});
    } else if (kind == 'theme' && item != null) {
      final th = tsThemeOf(item);
      price = n(ctx.themes['price']);
      name = th.name(ctx.lang);
      title = ctx.m('unlockTitle', {'name': name});
      sub = ctx.m('designWhat');
      perks = ['${ctx.m('oneTime')} · ${ctx.m('forever')}'];
      label = ctx.m('buy', {'coins': fmt(price)});
      done = ctx.m('designBought', {'name': name});
      icon = LucideIcons.palette;
      stage = SizedBox(
        width: 170,
        height: 220,
        child: TsMiniStore(themeKey: item, color: str(ctx.store['color']), name: ctx.shopName, logo: str(ctx.store['logo'])),
      );
      buy = () => api.post('$_base/themes/$item');
    } else {
      final a = ctx.addon(kind);
      if (a.isEmpty) return;
      final yearly = a['days'] != null;
      price = n(a['price']);
      name = ctx.m('addonNames.$kind');
      title = ctx.m('unlockTitle', {'name': name});
      sub = ctx.m('addonWhat.$kind');
      perks = [...ctx.t.list('ts.perks.$kind'), yearly ? '${fmt(price)} ${ctx.m('coins')} ${ctx.m('perYear')}' : '${ctx.m('oneTime')} · ${ctx.m('forever')}'];
      label = ctx.m('buy', {'coins': fmt(price)});
      done = ctx.m('unlockDone', {'name': name});
      icon = tsAddonIcons[kind] ?? LucideIcons.puzzle;
      buy = () => api.post('${Api.user}/businesses/${widget.id}/licenses/$kind', {'expect': yearly ? a['expires_at'] : null});
    }
    stage ??= Container(
      width: 150,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFD86B), Color(0xFFE0A21A)]),
      ),
      child: Column(
        children: [
          Icon(icon, size: 54, color: const Color(0xFF5B3A00)),
          const SizedBox(height: 8),
          Text(name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF3A2500))),
          Text(ctx.shopName, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: const Color(0xFF3A2500).withValues(alpha: .7))),
        ],
      ),
    );
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BuySheet(
        stage: stage!,
        badge: ctx.m('badge'),
        title: title,
        sub: sub,
        perks: perks,
        price: price,
        buyLabel: label,
        doneTitle: name,
        doneSub: done,
        doneSubOf: kind == 'renew' ? (r) => ctx.m('renewDone', {'date': tsDay(obj(r['data'])['expires_at'] ?? obj(obj(r['data'])['license'])['expires_at'], ctx.lang)}) : null,
        doneButton: ctx.t('app.continue'),
        buy: buy,
        onDone: (_) => _reload(),
      ),
    );
    if (mounted) setState(() {});
  }

  void _openSections() {
    final t = ref.read(tProvider);
    final c = context.c;
    final ctx = _ctx();
    final fresh = n(ctx.counts['new']).toInt();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .8,
        maxChildSize: .95,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text(t('ts.allSections'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ),
            for (final (group, keys) in _groups) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                child: Text(t('ts.groups.$group'), style: TextStyle(color: c.muted, fontWeight: FontWeight.w800, fontSize: 12.5)),
              ),
              for (final key in keys)
                _NavRow(
                  icon: _tabs[key]!,
                  label: t('ts.tabs.$key'),
                  on: key == _current,
                  badge: key == 'orders' && fresh > 0 ? fresh : 0,
                  count: key == 'products' ? n(ctx.counts['products']).toInt() : (key == 'customers' ? n(ctx.counts['customers']).toInt() : null),
                  dot: key == 'share' && ctx.telegram['connected'] != true,
                  locked: _needs[key] != null && !ctx.on(_needs[key]!),
                  onTap: () {
                    Navigator.pop(sheet);
                    _go(key);
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    if (_data == null) {
      return Scaffold(
        backgroundColor: c.appBg,
        body: SafeArea(
          child: Column(
            children: [
              _top(context, widget.title, null),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _error.isNotEmpty ? LoadError(text: _error, retry: t('ts.retry'), onRetry: _reload) : const SkelList(rows: 6),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final ctx = _ctx();
    final tab = _current;
    final lic = ctx.license;
    final fresh = n(ctx.counts['new']).toInt();
    final exp = DateTime.tryParse('${lic['expires_at'] ?? ''}');
    final graceLeft = exp == null ? 0 : (_graceDays - DateTime.now().difference(exp).inDays).clamp(0, _graceDays);
    final inGrace = lic['active'] != true && lic['locked'] != true && exp != null;
    final soon = lic['active'] == true && exp != null && exp.difference(DateTime.now()).inDays <= 14;
    final openNow = obj(ctx.data['open_now']);
    final k = ValueKey('$tab$_nav');
    final Widget section = switch (tab) {
      'products' => ProductsTab(key: k, ctx: ctx),
      'customers' => CustomersTab(key: k, ctx: ctx),
      'staff' => StaffTab(key: k, ctx: ctx),
      'promos' => PromosTab(key: k, ctx: ctx),
      'messages' => MessagesTab(key: k, ctx: ctx),
      'remind' => RemindTab(key: k, ctx: ctx),
      'report' => ReportTab(key: k, ctx: ctx),
      'store' => StoreTab(key: k, ctx: ctx),
      'delivery' => DeliveryTab(key: k, ctx: ctx),
      'design' => DesignTab(key: k, ctx: ctx),
      'share' => ShareTab(key: k, ctx: ctx),
      'addons' => AddonsTab(key: k, ctx: ctx),
      _ => OrdersTab(key: k, ctx: ctx),
    };
    return Scaffold(
      backgroundColor: c.appBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _top(context, ctx.shopName, str(ctx.store['logo'])),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Chip2(t('ts.badge'), icon: LucideIcons.send),
                  if (exp != null) ...[
                    const SizedBox(width: 6),
                    Chip2(t('ts.endsOn', {'date': tsDay(exp, ctx.lang)}), icon: LucideIcons.calendarClock, tone: lic['locked'] == true ? Tone.danger : (inGrace || soon ? Tone.warn : Tone.good)),
                  ],
                  const SizedBox(width: 6),
                  Chip2(openNow['open'] == true ? t('ts.openNowChip') : t('ts.closedNowChip'), tone: openNow['open'] == true ? Tone.good : Tone.warn),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: Icon(LucideIcons.externalLink, size: 14, color: c.brand),
                    label: Text(t('ts.openStore')),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => tsOpen(ctx.webLink),
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: Icon(LucideIcons.copy, size: 14, color: c.brand),
                    label: Text(t('ts.copyLink')),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => tsCopy(context, ctx.mainLink, t('ts.copied')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (ctx.business['status'] == false) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Alert(t('ts.suspended'))),
            if (inGrace || lic['locked'] == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: lic['locked'] == true ? c.dangerBg : c.warnBg, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lic['locked'] == true ? t('ts.lockedTitle') : t('ts.graceTitle'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(lic['locked'] == true ? t('ts.lockedSub') : t('ts.graceSub', {'n': graceLeft}), style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 8),
                      GoldBtn(t('ts.renewFor', {'coins': fmt(n(lic['price']))}), onTap: ctx.business['status'] == false ? null : () => _buy('renew')),
                    ],
                  ),
                ),
              )
            else if (soon)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GoldBtn(t('ts.renewFor', {'coins': fmt(n(lic['price']))}), onTap: ctx.business['status'] == false ? null : () => _buy('renew')),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Material(
                color: c.card,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _openSections,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(_tabs[tab], size: 18, color: c.brand),
                        const SizedBox(width: 10),
                        Expanded(child: Text(t('ts.tabs.$tab'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                        if (fresh > 0 && tab != 'orders') ...[_Badge(fresh), const SizedBox(width: 8)],
                        Text(t('ts.allSections'), style: TextStyle(color: c.muted, fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(width: 4),
                        Icon(LucideIcons.chevronDown, size: 16, color: c.muted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: section),
          ],
        ),
      ),
    );
  }

  Widget _top(BuildContext context, String name, String? logo) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: [
          RoundBtn(LucideIcons.arrowLeft, size: 42, onTap: () => context.pop()),
          const SizedBox(width: 10),
          if (logo != null) ...[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(14)),
              clipBehavior: Clip.antiAlias,
              child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.send, size: 22, color: c.brand),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          TeamTopBtn(id: widget.id, name: name), // owner: who else can open this business (v1.5)
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool on, locked, dot;
  final int badge;
  final int? count;
  final VoidCallback onTap;
  const _NavRow({required this.icon, required this.label, required this.on, required this.locked, required this.badge, required this.onTap, this.count, this.dot = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: on ? c.active : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: on ? c.brandInk : c.ink),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: TextStyle(fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? c.brandInk : c.ink))),
              if (count != null) Text(fmt(count!), style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
              if (badge > 0) _Badge(badge),
              if (dot) Container(width: 8, height: 8, decoration: BoxDecoration(color: c.warn, shape: BoxShape.circle)),
              if (locked) ...[const SizedBox(width: 8), Icon(LucideIcons.lock, size: 14, color: c.muted)],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int n;
  const _Badge(this.n);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: context.c.danger, borderRadius: BorderRadius.circular(99)),
    child: Text(n > 99 ? '99+' : '$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11.5)),
  );
}
