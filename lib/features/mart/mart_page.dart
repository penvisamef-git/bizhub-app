import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart' show fmt, fmtDate;
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/buy_sheet.dart';
import '../../widgets/ui.dart';
import 'dart:async';

import 'mart_branches.dart';
import 'mart_common.dart';
import 'mart_extras.dart';
import 'mart_grow.dart';
import 'mart_orders.dart';
import 'mart_website.dart';
import 'mart_debt.dart';
import 'mart_expiry.dart';
import 'mart_stock.dart';
import 'mart_products.dart';
import 'mart_receipt.dart';
import 'mart_sales.dart';
import 'mart_setup.dart';
import '../owner/coin_play.dart' show playBilling;

// Mini Mart — the app version of the web's MartDashboard.jsx (same API, same words, same sections).
//   GET /api/user/businesses/:id/mart → { data: { business, license, limits, addons, renew_price, settings, categories, units, counts } }
const _tabs = <String, IconData>{
  'today': LucideIcons.sun,
  'sales': LucideIcons.clipboardList,
  'stock': LucideIcons.boxes,
  'expiry': LucideIcons.calendarX,
  'purchase': LucideIcons.clipboardCheck,
  'suppliers': LucideIcons.truck,
  'debt': LucideIcons.handCoins,
  'profit': LucideIcons.trendingUp,
  'promos': LucideIcons.badgePercent,
  'loyalty': LucideIcons.gift,
  'orders': LucideIcons.shoppingBag,
  'website': LucideIcons.globe,
  'delivery': LucideIcons.mapPinned,
  'products': LucideIcons.package,
  'pos': LucideIcons.monitorSmartphone,
  'print': LucideIcons.printer,
  'telegram': LucideIcons.send,
  'settings': LucideIcons.settings2,
  'branches': LucideIcons.network,
  'addons': LucideIcons.puzzle,
};
const _groups = <(String?, List<String>)>[
  ('daily', ['today', 'sales', 'stock', 'expiry', 'purchase', 'suppliers', 'debt', 'profit']),
  ('grow', ['promos', 'loyalty']),
  ('online', ['orders', 'website', 'delivery']),
  ('setup', ['products', 'pos', 'print', 'telegram', 'settings', 'branches']),
  (null, ['addons']),
];
// add-ons paid every year (the others are bought once, forever)
const _yearly = {
  'mart_staff',
  'mart_stock',
  'mart_history',
  'mart_debt',
  'mart_website',
  'mart_shop',
  'mart_telegram',
  'mart_expiry',
  'mart_loyalty',
  'mart_promos',
  'mart_profit',
  'mart_delivery',
  'mart_branches',
};
const _themeAddons = {'mart_print_theme', 'mart_site_theme', 'mart_portal_theme', 'mart_pos_theme'};
// rebuilt in the app so far (the others come in the next parts)
const _native = {..._allTabs};
const _allTabs = [
  'today',
  'sales',
  'stock',
  'expiry',
  'purchase',
  'suppliers',
  'debt',
  'profit',
  'promos',
  'loyalty',
  'orders',
  'website',
  'delivery',
  'products',
  'pos',
  'print',
  'telegram',
  'settings',
  'branches',
  'addons',
];

class MartPage extends ConsumerStatefulWidget {
  final String id, title, tab;
  const MartPage({super.key, required this.id, this.title = '', this.tab = ''});
  @override
  ConsumerState<MartPage> createState() => _MartPageState();
}

class _MartPageState extends ConsumerState<MartPage> {
  Json? _data;
  String _error = '';
  String? _tab;
  int _newOrders = 0;
  Timer? _orderTimer;

  String get _base => '${Api.user}/businesses/${widget.id}/mart';
  String get _current => _tab ?? (_tabs.containsKey(widget.tab) ? widget.tab : 'today');

  @override
  void initState() {
    super.initState();
    _reload();
    // online orders (mart_shop): new ones show a bar until they are accepted
    _orderTimer = Timer.periodic(const Duration(seconds: 15), (_) => _countOrders());
  }

  @override
  void dispose() {
    _orderTimer?.cancel();
    super.dispose();
  }

  Future<void> _countOrders() async {
    if (_data == null || obj(obj(_data!['addons'])['mart_shop'])['active'] != true) return;
    try {
      final r = await ref.read(apiProvider).get('$_base/orders/count');
      final v = n(obj(r['data'])['pending']).toInt();
      if (mounted && v != _newOrders) setState(() => _newOrders = v);
    } catch (_) {}
  }

  Future<void> _reload() async {
    try {
      final r = await ref.read(apiProvider).get(_base);
      if (!mounted) return;
      setState(() {
        _data = obj(r['data']);
        Future.microtask(_countOrders);
        _error = '';
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.network ? ref.read(tProvider)('app.offline') : (e.message.isNotEmpty ? e.message : ref.read(tProvider)('mart.loadFail')));
    }
  }

  MartCtx _ctx() => MartCtx(
    id: widget.id,
    api: ref.read(apiProvider),
    t: ref.read(tProvider),
    data: _data!,
    reload: _reload,
    askBuy: _buy,
    go: (tab) => setState(() => _tab = tab),
    notify: (text) => toast(context, text),
  );

  // renew ("mart"), an add-on, or one look (receipt template / POS / website / order page)
  Future<void> _buy(String key, {String? item, VoidCallback? onDone}) async {
    final t = ref.read(tProvider);
    String m(String k, [Map<String, Object?> v = const {}]) => t('mart.$k', v);
    final data = _data!;
    final business = obj(data['business']);
    final lic = obj(data['license']);
    final renew = key == 'mart';
    final a = obj(obj(data['addons'])[key]);
    final theme = _themeAddons.contains(key);
    final price = renew ? n(data['renew_price']) : n(a['price']);
    final api = ref.read(apiProvider);
    final infoName = renew ? m('renewTitle') : t.or('mart.addonInfo.$key.name', key);
    final name = switch (key) {
      'mart_print_theme' => m('templateName', {'name': martThemeOf(item).name(t.lang)}),
      'mart_pos_theme' => '$infoName · ${posLookName(item ?? '', t.lang)}',
      _ when theme => '$infoName · ${item ?? ''}',
      _ => infoName,
    };
    final perks = renew ? <String>[] : [...t.list('mart.addonInfo.$key.perks'), '${fmt(price)} ${m('coins')} · ${_yearly.contains(key) ? m('perYear') : m('forever')}'];
    Future<Json> buy() {
      if (renew) return api.post('${Api.user}/businesses/${widget.id}/licenses/mart', {'expect': lic['expires_at']});
      if (!theme) return api.post('${Api.user}/businesses/${widget.id}/licenses/$key', {'expect': a['expires_at']});
      final path = switch (key) {
        'mart_pos_theme' => 'pos-themes',
        'mart_site_theme' => 'site-themes',
        'mart_portal_theme' => 'portal-themes',
        _ => 'print-themes',
      };
      return api.post('$_base/$path/$item/buy');
    }

    // a look: the look itself as the picture
    final ctx0 = _ctx();
    Widget? look;
    if (theme && item != null) {
      final bn = str(business['name']);
      final big = switch (key) {
        'mart_pos_theme' => SizedBox(
          width: 380,
          child: MartPosThumb(look: item, name: bn),
        ),
        'mart_site_theme' => SizedBox(
          width: 380,
          child: MsThumb(look: item, name: bn),
        ),
        'mart_portal_theme' => SizedBox(
          width: 380,
          child: MpThumb(look: item, name: bn),
        ),
        _ => Container(
          width: 300,
          padding: const EdgeInsets.all(10),
          color: Colors.white,
          child: MartReceipt(sale: martSampleSale, shop: ctx0.shop, m: (k) => ctx0.m(k), methodName: ctx0.methodName, lang: t.lang, theme: item),
        ),
      };
      look = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 190,
          height: 230,
          child: FittedBox(fit: BoxFit.contain, child: big),
        ),
      );
    }
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BuySheet(
        stage:
            look ??
            Container(
              width: 150,
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFD86B), Color(0xFFE0A21A)]),
              ),
              child: Column(
                children: [
                  Icon(renew ? LucideIcons.calendarClock : LucideIcons.puzzle, size: 54, color: const Color(0xFF5B3A00)),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF3A2500)),
                  ),
                  Text(
                    str(business['name']),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: const Color(0xFF3A2500).withValues(alpha: .7)),
                  ),
                ],
              ),
            ),
        badge: renew ? m('renew') : m('tabs.addons'),
        title: name,
        sub: renew ? m('renewSub') : t.or('mart.addonInfo.$key.what', ''),
        perks: perks,
        price: price,
        buyLabel: renew || a['active'] == true ? '${m('renew')} · ${fmt(price)} ${m('coins')}' : '${m('unlock', {'coins': ''}).replaceAll(' · ', '').trim()} · ${fmt(price)} ${m('coins')}',
        doneTitle: renew ? m('renewTitle') : name,
        doneSub: renew ? '' : m('unlocked', {'name': name}),
        doneSubOf: renew ? (res) => m('renewDone', {'date': fmtDate(obj(res['data'])['expires_at'], lang: t.lang)}) : null,
        doneButton: t('app.continue'),
        buy: buy,
        onDone: (_) {
          onDone?.call();
          _reload();
        },
      ),
    );
    if (mounted) setState(() {});
  }

  void _openSections() {
    final t = ref.read(tProvider);
    final c = context.c;
    final counts = obj(_data!['counts']);
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
              child: Text(t('mart.allSections'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ),
            for (final (group, keys) in _groups) ...[
              if (group != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                  child: Text(
                    t('mart.navGroups.$group'),
                    style: TextStyle(color: c.muted, fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                )
              else
                const SizedBox(height: 12),
              for (final key in keys)
                _NavRow(
                  icon: _tabs[key]!,
                  label: t('mart.tabs.$key'),
                  on: key == _current,
                  dot: key == 'products' && n(counts['products']) == 0,
                  badge: key == 'website' && n(counts['unread']) > 0
                      ? '${n(counts['unread'])}'
                      : key == 'orders' && _newOrders > 0
                      ? '$_newOrders'
                      : null,
                  soon: !_native.contains(key),
                  soonLabel: t('rest.soonShort'),
                  onTap: () {
                    Navigator.pop(sheet);
                    setState(() => _tab = key);
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
    String m(String k, [Map<String, Object?> v = const {}]) => t('mart.$k', v);

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
                  child: _error.isNotEmpty ? LoadError(text: _error, retry: m('retry'), onRetry: _reload) : const SkelList(rows: 6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final ctx = _ctx();
    final lic = ctx.license;
    final tab = _current;
    final business = ctx.business;
    final graceLeft = lic['grace_until'] == null ? 0 : ((DateTime.tryParse(str(lic['grace_until']))?.difference(DateTime.now()).inHours ?? 0) / 24).ceil().clamp(0, 999);

    final Widget section = switch (tab) {
      'today' => TodayTab(key: const ValueKey('today'), ctx: ctx),
      'sales' => SalesTab(key: const ValueKey('sales'), ctx: ctx),
      'products' => ProductsTab(key: const ValueKey('products'), ctx: ctx),
      'pos' => PosTab(key: const ValueKey('pos'), ctx: ctx),
      'settings' => SettingsTab(key: const ValueKey('settings'), ctx: ctx),
      'promos' => PromosTab(key: ValueKey('promos${ctx.addonOn('mart_promos')}'), ctx: ctx),
      'loyalty' => LoyaltyTab(key: ValueKey('loyalty${ctx.addonOn('mart_loyalty')}'), ctx: ctx),
      'orders' => OrdersTab(key: ValueKey('orders${ctx.addonOn('mart_shop')}'), ctx: ctx, onCount: _countOrders),
      'website' => WebsiteTab(key: ValueKey('website${ctx.addonOn('mart_website')}'), ctx: ctx),
      'delivery' => DeliveryTab(key: ValueKey('delivery${ctx.addonOn('mart_delivery')}'), ctx: ctx),
      'print' => PrintTab(key: const ValueKey('print'), ctx: ctx),
      'telegram' => TelegramTab(key: ValueKey('telegram${ctx.addonOn('mart_telegram')}'), ctx: ctx),
      'branches' => BranchesTab(key: ValueKey('branches${ctx.addonOn('mart_branches')}'), ctx: ctx),
      'addons' => AddonsTab(key: const ValueKey('addons'), ctx: ctx),
      'stock' => StockTab(key: ValueKey('stock${ctx.stockOn}'), ctx: ctx),
      'expiry' => ExpiryTab(key: ValueKey('expiry${ctx.addonOn('mart_expiry')}'), ctx: ctx),
      'purchase' => PurchaseTab(key: ValueKey('purchase${ctx.addonOn('mart_purchase')}'), ctx: ctx),
      'suppliers' => SuppliersTab(key: ValueKey('suppliers${ctx.addonOn('mart_suppliers')}'), ctx: ctx),
      'debt' => DebtTab(key: ValueKey('debt${ctx.addonOn('mart_debt')}'), ctx: ctx),
      'profit' => ProfitTab(key: ValueKey('profit${ctx.addonOn('mart_profit')}'), ctx: ctx),
      _ => _Soon(ctx: ctx, tab: tab),
    };

    return Scaffold(
      backgroundColor: c.appBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _top(context, str(business['name']).isNotEmpty ? str(business['name']) : widget.title, str(business['logo_url'])),
            // chips: type · ends on · products
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Chip2(m('type')),
                    if (lic['expires_at'] != null) ...[
                      const SizedBox(width: 6),
                      Chip2(
                        m('endsOn', {'date': mDate(lic['expires_at'], t.lang)}),
                        icon: LucideIcons.calendarClock,
                        tone: lic['locked'] == true || lic['status'] == 'expired'
                            ? Tone.danger
                            : lic['status'] == 'expiring'
                            ? Tone.warn
                            : Tone.muted,
                      ),
                    ],
                    const SizedBox(width: 6),
                    Chip2(m('productsLine', {'n': n(ctx.counts['products']), 'max': n(ctx.limits['products'])}), icon: LucideIcons.package),
                  ],
                ),
              ),
            ),
            if (business['status'] == false) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Alert(m('suspended'))),
            if (lic['in_grace'] == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Alert('${m('graceTitle')} ${m('graceSub', {'n': graceLeft})}', tone: Tone.warn),
              ),
            if (lic['locked'] == true) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Alert('${m('lockedTitle')} ${m('lockedSub')}')),
            if (lic['status'] == 'expiring' || lic['in_grace'] == true || lic['locked'] == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Btn(
                  '${m('renew')} · ${fmt(n(_data!['renew_price']))} ${m('coins')}',
                  lead: const CoinIcon(size: 16),
                  expand: true,
                  onTap: business['status'] == false ? null : () => _buy('mart'),
                ),
              ),
            // the section you are on + "All sections"
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
                        Expanded(
                          child: Text(m('tabs.$tab'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                        Text(
                          m('allSections'),
                          style: TextStyle(color: c.muted, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(width: 4),
                        Icon(LucideIcons.chevronDown, size: 16, color: c.muted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_newOrders > 0 && tab != 'orders')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Material(
                  color: c.warnBg,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _tab = 'orders'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      child: Row(
                        children: [
                          Icon(LucideIcons.bellRing, size: 19, color: c.warn),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _newOrders == 1 ? t('mw.alertOne') : t('mw.alertMany', {'n': _newOrders}),
                              style: TextStyle(fontWeight: FontWeight.w800, color: c.warn),
                            ),
                          ),
                          Text(
                            t('mw.alertOpen'),
                            style: TextStyle(fontWeight: FontWeight.w800, color: c.warn),
                          ),
                          Icon(LucideIcons.chevronRight, size: 16, color: c.warn),
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
              child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.shoppingBasket, size: 22, color: c.brand),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label, soonLabel;
  final bool on, dot, soon;
  final String? badge;
  final VoidCallback onTap;
  const _NavRow({required this.icon, required this.label, required this.on, required this.dot, required this.soon, required this.soonLabel, this.badge, required this.onTap});
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
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? c.brandInk : c.ink),
                ),
              ),
              if (dot)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
                ),
              if (badge != null) ...[const SizedBox(width: 8), Chip2(badge!, tone: Tone.danger)],
              if (soon) ...[const SizedBox(width: 8), Chip2(soonLabel)],
            ],
          ),
        ),
      ),
    );
  }
}

// sections not rebuilt yet: say so, offer the website in the browser
class _Soon extends StatelessWidget {
  final MartCtx ctx;
  final String tab;
  const _Soon({required this.ctx, required this.tab});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Panel(
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: c.active, shape: BoxShape.circle),
                child: Icon(_tabs[tab], size: 28, color: c.brand),
              ),
              const SizedBox(height: 14),
              Text(ctx.m('tabs.$tab'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                ctx.t(playBilling ? 'app.restSoonPlay' : 'app.restSoon'), // Google Play build: no pointing to the website (it has buy buttons)
                textAlign: TextAlign.center,
                style: TextStyle(color: c.muted, height: 1.5),
              ),
              const SizedBox(height: 16),
              if (!playBilling)
                Btn(
                  ctx.t('app.openWeb'),
                  icon: LucideIcons.externalLink,
                  kind: BtnKind.ghost,
                  onTap: () => launchUrl(Uri.parse('${Config.siteUrl}/app/business/${ctx.id}?tab=$tab'), mode: LaunchMode.externalApplication),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
