import 'dart:async';

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
import '../common/branches_view.dart';
import '../team/team_frame.dart' show TeamTopBtn;
import '../mart/mart_common.dart' show mDate;
import 'gh_common.dart';
import 'gh_daily.dart';
import 'gh_extra.dart';
import 'gh_grow.dart';
import 'gh_ops.dart';
import 'gh_website.dart';
import 'gh_pos.dart';
import 'gh_receipt.dart';
import 'gh_setup.dart';
import 'gh_site_looks.dart' show GsThumb;
import '../owner/coin_play.dart' show playBilling;

// Guest House — the app version of the web's GuestHouseDashboard.jsx (same API, same words, same sections).
//   GET /api/user/businesses/:id/guesthouse → { data: { business, license, limits, addons, renew_price, settings, types, rooms, counts, lists } }
const _tabs = <String, IconData>{
  'today': LucideIcons.sun,
  'calendar': LucideIcons.calendarRange,
  'bookings': LucideIcons.clipboardList,
  'longstay': LucideIcons.keyRound,
  'housekeeping': LucideIcons.sparkles,
  'report': LucideIcons.chartColumn,
  'expenses': LucideIcons.wallet,
  'police': LucideIcons.shieldCheck,
  'profile': LucideIcons.store,
  'rooms': LucideIcons.bedDouble,
  'pos': LucideIcons.monitorSmartphone,
  'print': LucideIcons.printer,
  'services': LucideIcons.conciergeBell,
  'website': LucideIcons.globe,
  'ota': LucideIcons.calendarSync,
  'promos': LucideIcons.badgePercent,
  'customers': LucideIcons.userRoundCheck,
  'loyalty': LucideIcons.gift,
  'reviews': LucideIcons.star,
  'telegram': LucideIcons.send,
  'settings': LucideIcons.settings2,
  'branches': LucideIcons.network,
  'addons': LucideIcons.puzzle,
};
const _groups = <(String?, List<String>)>[
  ('daily', ['today', 'calendar', 'bookings', 'longstay', 'housekeeping', 'report', 'expenses', 'police']),
  ('setup', ['profile', 'rooms', 'pos', 'print', 'services', 'website', 'ota', 'promos', 'customers', 'loyalty', 'reviews', 'telegram', 'settings']),
  (null, ['branches', 'addons']),
];
// rebuilt in the app so far (the others come in the next parts)
const _native = {
  'today',
  'calendar',
  'bookings',
  'report',
  'rooms',
  'pos',
  'print',
  'settings',
  'branches',
  'addons',
  'website',
  'promos',
  'customers',
  'police',
  'housekeeping',
  'ota',
  'longstay',
  'reviews',
  'loyalty',
  'expenses',
  'services',
  'telegram',
  'profile',
};
const _themeAddons = {'gh_display_theme', 'gh_print_theme', 'gh_site_theme', 'gh_portal_theme'};

class GuestHousePage extends ConsumerStatefulWidget {
  final String id, title, tab;
  const GuestHousePage({super.key, required this.id, this.title = '', this.tab = ''});
  @override
  ConsumerState<GuestHousePage> createState() => _GuestHousePageState();
}

class _GuestHousePageState extends ConsumerState<GuestHousePage> {
  Json? _data;
  String _error = '';
  String? _tab;
  int _waiting = 0; // online bookings waiting (gh_customers)
  Timer? _alertTimer;

  String get _base => '${Api.user}/businesses/${widget.id}/guesthouse';
  String get _current => _tab ?? (_tabs.containsKey(widget.tab) ? widget.tab : 'today');

  @override
  void initState() {
    super.initState();
    _reload();
    _alertTimer = Timer.periodic(const Duration(seconds: 15), (_) => _countWaiting());
  }

  @override
  void dispose() {
    _alertTimer?.cancel();
    super.dispose();
  }

  // online bookings from customer accounts: a bar shows until they are answered
  Future<void> _countWaiting() async {
    if (_data == null || obj(obj(_data!['addons'])['gh_customers'])['active'] != true) return;
    try {
      final r = await ref.read(apiProvider).get('$_base/cust-requests/count');
      final v = n(obj(r['data'])['pending']).toInt();
      if (mounted && v != _waiting) setState(() => _waiting = v);
    } catch (_) {}
  }

  Future<void> _reload() async {
    try {
      final r = await ref.read(apiProvider).get(_base);
      if (!mounted) return;
      setState(() {
        _data = obj(r['data']);
        _error = '';
      });
      Future.microtask(_countWaiting);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.network ? ref.read(tProvider)('app.offline') : (e.message.isNotEmpty ? e.message : ref.read(tProvider)('gh.loadFail')));
    }
  }

  GhCtx _ctx() => GhCtx(
    id: widget.id,
    api: ref.read(apiProvider),
    t: ref.read(tProvider),
    data: _data!,
    reload: _reload,
    askBuy: _buy,
    go: (tab) => setState(() => _tab = tab),
    notify: (text) => toast(context, text),
  );

  // renew ("guest_house"), an add-on, or one look (display / receipt template / website / customer page)
  Future<void> _buy(String key, {String? item, VoidCallback? onDone}) async {
    final t = ref.read(tProvider);
    String g(String k, [Map<String, Object?> v = const {}]) => t('gh.$k', v);
    final data = _data!;
    final business = obj(data['business']);
    final lic = obj(data['license']);
    final renew = key == 'guest_house';
    final a = obj(obj(data['addons'])[key]);
    final theme = _themeAddons.contains(key);
    final price = renew ? n(data['renew_price']) : n(a['price']);
    final api = ref.read(apiProvider);
    final (name, what) = switch (key) {
      'guest_house' => (g('renewTitle'), g('renewSub')),
      'gh_display_theme' => (g('lookName', {'name': ghLookName(item ?? '', t.lang)}), g('lookWhat')),
      'gh_print_theme' => (g('templateName', {'name': ghPrintThemeOf(item).name(t.lang)}), g('templateWhat')),
      _ when theme => (t.or('gws.lookName', '{name}').replaceAll('{name}', item ?? ''), ''),
      _ => (t.or('gh.addonInfo.$key.name', key), t.or('gh.addonInfo.$key.what', '')),
    };
    final perks = renew || theme ? <String>[] : [...t.list('gh.addonInfo.$key.perks'), '${fmt(price)} ${g('coins')} · ${ghYearly.contains(key) ? g('perYear') : g('forever')}'];
    Future<Json> buy() {
      if (renew) return api.post('${Api.user}/businesses/${widget.id}/licenses/guest_house', {'expect': lic['expires_at']});
      if (!theme) return api.post('${Api.user}/businesses/${widget.id}/licenses/$key', {'expect': a['expires_at']});
      return api.post(switch (key) {
        'gh_display_theme' => '$_base/display-themes/$item/buy',
        'gh_print_theme' => '$_base/print-themes/$item/buy',
        'gh_site_theme' => '$_base/site/themes/$item',
        _ => '$_base/portal-themes/$item',
      });
    }

    // a look: the look itself as the picture
    Widget? look;
    if (theme && item != null) {
      final ctx0 = _ctx();
      final bn = str(business['name']);
      final big = switch (key) {
        'gh_display_theme' => SizedBox(
          width: 420,
          child: GhDisplayThumb(look: item, name: bn, logo: str(business['logo_url']), lang: t.lang),
        ),
        'gh_print_theme' => Container(
          width: 300,
          padding: const EdgeInsets.all(10),
          color: Colors.white,
          child: GhReceipt(stay: ghSampleStay(t.lang), data: data, lang: t.lang, theme: item),
        ),
        'gh_site_theme' => SizedBox(
          width: 380,
          child: GsThumb(look: item, name: bn, types: ctx0.types),
        ),
        _ => SizedBox(
          width: 380,
          child: GpThumb(look: item, name: bn, types: ctx0.types, cur: ctx0.cur),
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
                  Icon(renew ? LucideIcons.calendarClock : (ghAddonIcons[key] ?? LucideIcons.palette), size: 54, color: const Color(0xFF5B3A00)),
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
        badge: renew ? g('renew') : g('tabs.addons'),
        title: name,
        sub: what,
        perks: perks,
        price: price,
        buyLabel: '${renew || a['active'] == true ? g('renew') : g('add')} · ${fmt(price)} ${g('coins')}',
        doneTitle: renew ? g('renewTitle') : name,
        doneSub: renew ? '' : g('unlocked', {'name': name}),
        doneSubOf: renew ? (res) => g('renewDone', {'date': fmtDate(obj(res['data'])['expires_at'], lang: t.lang)}) : null,
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
    final noSetup = objs(_data!['types']).isEmpty || objs(_data!['rooms']).isEmpty;
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
              child: Text(t('gh.allSections'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ),
            for (final (group, keys) in _groups) ...[
              if (group != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                  child: Text(
                    t('gh.navGroups.$group'),
                    style: TextStyle(color: c.muted, fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                )
              else
                const SizedBox(height: 12),
              for (final key in keys)
                _NavRow(
                  icon: _tabs[key]!,
                  label: t('gh.tabs.$key'),
                  on: key == _current,
                  dot: key == 'rooms' && noSetup,
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
    String g(String k, [Map<String, Object?> v = const {}]) => t('gh.$k', v);

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
                  child: _error.isNotEmpty ? LoadError(text: _error, retry: g('retry'), onRetry: _reload) : const SkelList(rows: 6),
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
      'calendar' => CalendarTab(key: const ValueKey('calendar'), ctx: ctx),
      'bookings' => BookingsTab(key: const ValueKey('bookings'), ctx: ctx),
      'report' => ReportTab(key: const ValueKey('report'), ctx: ctx),
      'rooms' => RoomsTab(key: const ValueKey('rooms'), ctx: ctx),
      'settings' => SettingsTab(key: ValueKey('settings${ctx.addonOn('gh_payments')}'), ctx: ctx),
      'pos' => PosTab(key: const ValueKey('pos'), ctx: ctx),
      'print' => PrintTab(key: const ValueKey('print'), ctx: ctx),
      'addons' => AddonsTab(key: const ValueKey('addons'), ctx: ctx),
      'website' => WebsiteTab(key: const ValueKey('website'), ctx: ctx),
      'promos' => PromosTab(key: const ValueKey('promos'), ctx: ctx),
      'customers' => CustomersTab(key: ValueKey('customers${ctx.addonOn('gh_customers')}'), ctx: ctx, onCount: _countWaiting),
      'police' => PoliceTab(key: ValueKey('police${ctx.addonOn('gh_police')}'), ctx: ctx),
      'housekeeping' => HousekeepingTab(key: ValueKey('housekeeping${ctx.addonOn('gh_housekeeping')}'), ctx: ctx),
      'ota' => OtaTab(key: const ValueKey('ota'), ctx: ctx),
      'reviews' => ReviewsTab(key: ValueKey('reviews${ctx.addonOn('gh_reviews')}'), ctx: ctx),
      'loyalty' => LoyaltyTab(key: ValueKey('loyalty${ctx.addonOn('gh_loyalty')}'), ctx: ctx),
      'expenses' => ExpensesTab(key: ValueKey('expenses${ctx.addonOn('gh_expenses')}'), ctx: ctx),
      'services' => ServicesTab(key: ValueKey('services${ctx.addonOn('gh_services')}'), ctx: ctx),
      'telegram' => TelegramTab(key: ValueKey('telegram${ctx.addonOn('gh_telegram')}'), ctx: ctx),
      'profile' => ProfileTab(key: ValueKey('profile${ctx.business['logo_url']}${obj(ctx.settings['cover'])['url']}'), ctx: ctx),
      'longstay' => LeasesTab(key: ValueKey('longstay${ctx.addonOn('gh_longstay')}'), ctx: ctx),
      'branches' => BranchesView(
        key: const ValueKey('branches'),
        id: ctx.id,
        category: 'guest_house',
        api: ctx.api,
        t: ctx.t,
        owned: ctx.addonOn('gh_branches'),
        readOnly: ctx.readOnly,
        price: ctx.addon('gh_branches')['price'] as num?,
        onBuy: () => ctx.askBuy('gh_branches'),
        notify: ctx.notify,
      ),
      _ => _Soon(ctx: ctx, tab: tab),
    };

    return Scaffold(
      backgroundColor: c.appBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _top(context, str(business['name']).isNotEmpty ? str(business['name']) : widget.title, str(business['logo_url'])),
            // chips: type · ends on · rooms
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Chip2(g('type')),
                    if (lic['expires_at'] != null) ...[
                      const SizedBox(width: 6),
                      Chip2(
                        g('endsOn', {'date': mDate(lic['expires_at'], t.lang)}),
                        icon: LucideIcons.calendarClock,
                        tone: lic['locked'] == true || lic['status'] == 'expired'
                            ? Tone.danger
                            : lic['status'] == 'expiring'
                            ? Tone.warn
                            : Tone.muted,
                      ),
                    ],
                    const SizedBox(width: 6),
                    Chip2(
                      ctx.addonOn('gh_rooms') ? g('roomsAll', {'n': n(ctx.counts['rooms'])}) : g('roomsLine', {'n': n(ctx.counts['rooms']), 'max': n(ctx.limits['rooms'])}),
                      icon: LucideIcons.bedDouble,
                    ),
                  ],
                ),
              ),
            ),
            if (business['status'] == false) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Alert(g('suspended'))),
            if (lic['in_grace'] == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Alert('${g('graceTitle')} ${g('graceSub', {'n': graceLeft})}', tone: Tone.warn),
              ),
            if (lic['locked'] == true) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Alert('${g('lockedTitle')} ${g('lockedSub')}')),
            if (lic['status'] == 'expiring' || lic['in_grace'] == true || lic['locked'] == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Btn(
                  '${g('renew')} · ${fmt(n(_data!['renew_price']))} ${g('coins')}',
                  lead: const CoinIcon(size: 16),
                  expand: true,
                  onTap: business['status'] == false ? null : () => _buy('guest_house'),
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
                          child: Text(g('tabs.$tab'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                        Text(
                          g('allSections'),
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
            if (_waiting > 0 && tab != 'customers')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Material(
                  color: c.warnBg,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => openRequests(context, ctx, _countWaiting),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      child: Row(
                        children: [
                          Icon(LucideIcons.bellRing, size: 19, color: c.warn),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _waiting == 1 ? t('gcu.alertOne') : t('gcu.alertMany', {'n': _waiting}),
                              style: TextStyle(fontWeight: FontWeight.w800, color: c.warn),
                            ),
                          ),
                          Text(
                            t('gcu.alertOpen'),
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
              child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.bedDouble, size: 22, color: c.brand),
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
          TeamTopBtn(id: widget.id, name: name), // owner: who else can open this business (v1.5)
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label, soonLabel;
  final bool on, dot, soon;
  final VoidCallback onTap;
  const _NavRow({required this.icon, required this.label, required this.on, required this.dot, required this.soon, required this.soonLabel, required this.onTap});
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
  final GhCtx ctx;
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
              Text(ctx.g('tabs.$tab'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
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
