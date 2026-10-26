import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/buy_sheet.dart';
import '../../widgets/color_pick.dart';
import '../../widgets/ui.dart';
import 'rest_common.dart';
import '../common/branches_view.dart';
import 'rest_connect.dart';
import 'rest_display.dart';
import 'rest_looks.dart';
import 'rest_menu.dart';
import 'rest_online.dart';
import 'rest_pos.dart';
import 'rest_promos.dart';
import 'rest_rewards.dart';
import 'rest_reports.dart';
import 'rest_sections.dart';
import 'rest_stock.dart';
import 'rest_tableorder.dart';
import 'rest_tables.dart';
import 'rest_website.dart';
import '../owner/coin_play.dart' show playBilling;

// Restaurant setup — the app version of the web's RestaurantDashboard.jsx (same API, same words, same sections).
//   GET /api/user/businesses/:id/restaurant → { data: settings, business, setup, license, addons, limits, renew_price }
const _tabs = <String, IconData>{
  'setup': LucideIcons.circleCheck,
  'reports': LucideIcons.chartColumn,
  'profile': LucideIcons.store,
  'money': LucideIcons.creditCard,
  'tables': LucideIcons.layoutGrid,
  'menu': LucideIcons.utensilsCrossed,
  'staff': LucideIcons.users,
  'pos': LucideIcons.monitorSmartphone,
  'poslook': LucideIcons.palette,
  'stock': LucideIcons.package,
  'promos': LucideIcons.badgePercent,
  'rewards': LucideIcons.star,
  'receipt': LucideIcons.receiptText,
  'display': LucideIcons.monitorUp,
  'qr': LucideIcons.qrCode,
  'tableorder': LucideIcons.handPlatter,
  'website': LucideIcons.globe,
  'inbox': LucideIcons.inbox,
  'telegram': LucideIcons.send,
  'app': LucideIcons.smartphone,
  'branches': LucideIcons.network,
  'addons': LucideIcons.puzzle,
};
const _groups = <(String?, List<String>)>[
  (null, ['setup', 'reports']),
  ('shop', ['profile', 'money', 'tables', 'menu', 'staff', 'stock', 'promos', 'rewards', 'pos', 'poslook', 'receipt', 'display']),
  ('online', ['qr', 'tableorder', 'website', 'inbox']),
  ('connect', ['telegram', 'app']),
  (null, ['branches', 'addons']),
];
const _needs = {
  'stock': 'rest_stock',
  'promos': 'rest_promos',
  'rewards': 'rest_rewards',
  'display': 'rest_display',
  'qr': 'rest_qr_menu',
  'tableorder': 'rest_table_order',
  'website': 'rest_website',
  'inbox': 'rest_website',
  'telegram': 'rest_telegram',
};
// rebuilt in the app so far (the others come in the next parts)
const _native = {
  'setup',
  'reports',
  'profile',
  'money',
  'tables',
  'menu',
  'staff',
  'stock',
  'pos',
  'promos',
  'receipt',
  'poslook',
  'telegram',
  'addons',
  'rewards',
  'display',
  'qr',
  'inbox',
  'app',
  'branches',
};

class RestaurantPage extends ConsumerStatefulWidget {
  final String id, title, tab;
  const RestaurantPage({super.key, required this.id, this.title = '', this.tab = ''});
  @override
  ConsumerState<RestaurantPage> createState() => _RestaurantPageState();
}

class _RestaurantPageState extends ConsumerState<RestaurantPage> {
  Json? _settings, _overview;
  String _error = '';
  String? _tab;

  String get _base => '${Api.user}/businesses/${widget.id}/restaurant';

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
        _settings = obj(r['data']);
        _overview = {
          'business': r['business'],
          'setup': r['setup'],
          'license': r['license'],
          'addons': r['addons'],
          'limits': r['limits'],
          'renew_price': r['renew_price'],
          'inbox_unread': r['inbox_unread'],
        };
        _error = '';
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.network ? ref.read(tProvider)('app.offline') : (e.message.isNotEmpty ? e.message : ref.read(tProvider)('rest.loadFail')));
    }
  }

  Json get _setup => obj(_overview?['setup']);
  bool get _setupDone => _overview != null && n(_setup['done']) >= n(_setup['total']);
  String get _home => _setupDone ? 'reports' : 'setup';
  String get _current => _tab ?? (_tabs.containsKey(widget.tab) ? widget.tab : _home);

  RestCtx _ctx() {
    final t = ref.read(tProvider);
    return RestCtx(
      id: widget.id,
      api: ref.read(apiProvider),
      t: t,
      settings: _settings!,
      overview: _overview!,
      setSettings: (s, [setup]) => setState(() {
        _settings = s;
        if (setup != null) _overview = {..._overview!, 'setup': setup};
      }),
      reload: _reload,
      askBuy: _buy,
      go: (tab) => setState(() => _tab = tab),
      setUnread: (v) => setState(() => _overview = {..._overview!, 'inbox_unread': v}),
      notify: (text) => toast(context, text),
    );
  }

  // add-on or renewal (PurchaseModal on the web)
  Future<void> _buy(String key) async {
    final t = ref.read(tProvider);
    String r(String k, [Map<String, Object?> v = const {}]) => t('rest.$k', v);
    final addons = objs(_overview?['addons']);
    final addon = key == 'restaurant' ? <String, dynamic>{} : addons.firstWhere((a) => a['key'] == key, orElse: () => {});
    final lic = obj(_overview?['license']);
    final price = addon.isNotEmpty ? n(addon['price']) : n(_overview?['renew_price']);
    final name = _name(t.lang);
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BuySheet(
        stage: Container(
          width: 150,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFD86B), Color(0xFFE0A21A)]),
          ),
          child: Column(
            children: [
              Icon(addon.isNotEmpty ? addonIcon(key) : LucideIcons.calendarClock, size: 54, color: const Color(0xFF5B3A00)),
              const SizedBox(height: 8),
              Text(
                addon.isNotEmpty ? r('addonNames.$key') : r('renewTitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF3A2500)),
              ),
              Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: const Color(0xFF3A2500).withValues(alpha: .7)),
              ),
            ],
          ),
        ),
        badge: addon.isNotEmpty ? r('tabs.addons') : r('renew'),
        title: addon.isNotEmpty ? r('unlockTitle', {'name': r('addonNames.$key')}) : r('renewTitle'),
        sub: addon.isNotEmpty ? r('addonWhat.$key') : r('renewSub'),
        perks: addon.isNotEmpty ? [r('addonFree.$key'), n(addon['days']) > 0 ? '${fmt(price)} ${r('coins')} ${r('perYear')}' : '${r('oneTime')} · ${r('forever')}'] : const [],
        price: price,
        buyLabel: addon.isNotEmpty ? r('buy', {'coins': '${fmt(price)} ${r('coins')}'}) : r('renewFor', {'coins': '${fmt(price)} ${r('coins')}'}),
        doneTitle: addon.isNotEmpty ? r('unlockedTag') : r('renewTitle'),
        doneSub: addon.isNotEmpty ? r('unlockDone', {'name': r('addonNames.$key')}) : '',
        doneSubOf: addon.isNotEmpty ? null : (res) => r('renewDone', {'date': fmtDate(obj(res['data'])['expires_at'], lang: t.lang)}),
        doneButton: t('app.continue'),
        buy: () => ref.read(apiProvider).post('${Api.user}/businesses/${widget.id}/licenses/$key', {'expect': (addon.isNotEmpty ? addon : lic)['expires_at']}),
        onDone: (_) => _reload(),
      ),
    );
    if (mounted) setState(() {});
  }

  String _name(String lang) {
    final s = _settings ?? {};
    final km = str(s['name_km']), en = str(s['name_en']);
    final v = lang == 'km' ? (km.isNotEmpty ? km : en) : (en.isNotEmpty ? en : km);
    return v.isNotEmpty ? v : (str(obj(_overview?['business'])['name']).isNotEmpty ? str(obj(_overview?['business'])['name']) : widget.title);
  }

  void _openSections() {
    final t = ref.read(tProvider);
    String r(String k) => t('rest.$k');
    final c = context.c;
    final ctx = _ctx();
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
              child: Text(r('allSections'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ),
            for (final (group, keys) in _groups) ...[
              if (group != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                  child: Text(
                    t('rest.navGroups.$group'),
                    style: TextStyle(color: c.muted, fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                ),
              for (final key in keys.where((k) => !(k == 'setup' && _setupDone && _current != 'setup')))
                _NavRow(
                  icon: _tabs[key]!,
                  label: t('rest.tabs.$key'),
                  on: key == _current,
                  count: key == 'setup' ? '${n(_setup['done'])}/${n(_setup['total'])}' : null,
                  step: obj(_setup['steps']).containsKey(key) ? obj(_setup['steps'])[key] == true : null,
                  locked: _needs[key] != null && !ctx.addonOn(_needs[key]!),
                  soon: !_native.contains(key),
                  soonLabel: r('soonShort'),
                  badge: key == 'inbox' && n(_overview?['inbox_unread']) > 0 ? '${n(_overview?['inbox_unread'])}' : null,
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
    String r(String k, [Map<String, Object?> v = const {}]) => t('rest.$k', v);

    if (_settings == null) {
      return Scaffold(
        backgroundColor: c.appBg,
        body: SafeArea(
          child: Column(
            children: [
              _top(context, widget.title, null),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _error.isNotEmpty ? LoadError(text: _error, retry: r('retry'), onRetry: _reload) : const SkelList(rows: 6),
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
    final logo = str(obj(_settings!['logo'])['url']);
    final graceLeft = lic['grace_until'] == null ? 0 : (DateTime.tryParse(str(lic['grace_until']))?.difference(DateTime.now()).inHours ?? 0) ~/ 24 + 1;
    final color = hexToColor(str(_settings!['color']));

    Widget section = switch (tab) {
      'setup' => SetupSection(ctx: ctx),
      'profile' => ProfileSection(key: const ValueKey('profile'), ctx: ctx),
      'money' => MoneySection(key: const ValueKey('money'), ctx: ctx),
      'tables' => TablesSection(key: const ValueKey('tables'), ctx: ctx),
      'menu' => MenuSection(key: const ValueKey('menu'), ctx: ctx),
      'staff' => StaffSection(key: const ValueKey('staff'), ctx: ctx),
      'reports' => ReportsSection(key: const ValueKey('reports'), ctx: ctx),
      'stock' => StockSection(key: const ValueKey('stock'), ctx: ctx),
      'pos' => PosSection(key: const ValueKey('pos'), ctx: ctx),
      'promos' => PromosSection(key: const ValueKey('promos'), ctx: ctx),
      'receipt' => ReceiptLookSection(key: const ValueKey('receipt'), ctx: ctx),
      'poslook' => PosLookSection(key: const ValueKey('poslook'), ctx: ctx),
      'telegram' => TelegramSection(key: const ValueKey('telegram'), ctx: ctx),
      'addons' => AddonsSection(key: const ValueKey('addons'), ctx: ctx),
      'tableorder' => TableOrderSection(key: const ValueKey('tableorder'), ctx: ctx),
      'website' => WebsiteSection(key: const ValueKey('website'), ctx: ctx),
      'rewards' => RewardsSection(key: const ValueKey('rewards'), ctx: ctx),
      'display' => DisplaySection(key: const ValueKey('display'), ctx: ctx),
      'qr' => QrMenuSection(key: const ValueKey('qr'), ctx: ctx),
      'inbox' => InboxSection(key: const ValueKey('inbox'), ctx: ctx),
      'app' => AppSection(key: const ValueKey('app'), ctx: ctx),
      'branches' => BranchesView(
        key: const ValueKey('branches'),
        id: ctx.id,
        category: 'restaurant',
        api: ctx.api,
        t: ctx.t,
        owned: ctx.addonOn('rest_branches'),
        readOnly: ctx.readOnly,
        price: ctx.addon('rest_branches')['price'] as num?,
        onBuy: () => ctx.askBuy('rest_branches'),
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
            _top(context, _name(t.lang), logo, color: color),
            // chips: type · ends on · steps
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Chip2(t.or('rest.types.${_settings!['type']}', str(_settings!['type']))),
                    if (lic['expires_at'] != null) ...[
                      const SizedBox(width: 6),
                      Chip2(
                        r('endsOn', {'date': fmtDate(lic['expires_at'], lang: t.lang)}),
                        icon: LucideIcons.calendarClock,
                        tone: lic['locked'] == true || lic['status'] == 'expired'
                            ? Tone.danger
                            : lic['status'] == 'expiring'
                            ? Tone.warn
                            : Tone.muted,
                      ),
                    ],
                    const SizedBox(width: 6),
                    Chip2(r('stepsDone', {'done': n(_setup['done']), 'total': n(_setup['total'])}), icon: LucideIcons.circleCheck, tone: _setupDone ? Tone.good : Tone.muted),
                  ],
                ),
              ),
            ),
            if (obj(_overview!['business'])['status'] == false) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Alert(r('suspended'))),
            if (lic['in_grace'] == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Alert('${r('graceTitle')} ${r('graceSub', {'n': graceLeft})}', tone: Tone.warn),
              ),
            if (lic['locked'] == true) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Alert('${r('lockedTitle')} ${r('lockedSub')}')),
            if (lic['status'] == 'expiring' || lic['in_grace'] == true || lic['locked'] == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Btn(
                  r('renewFor', {'coins': fmt(n(_overview!['renew_price']))}),
                  lead: const CoinIcon(size: 16),
                  expand: true,
                  onTap: obj(_overview!['business'])['status'] == false ? null : () => _buy('restaurant'),
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
                          child: Text(t('rest.tabs.$tab'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                        Text(
                          r('allSections'),
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
            Expanded(child: section),
          ],
        ),
      ),
    );
  }

  Widget _top(BuildContext context, String name, String? logo, {Color? color}) {
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
              decoration: BoxDecoration(color: (color ?? c.brand).withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
              clipBehavior: Clip.antiAlias,
              child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover) : Icon(LucideIcons.chefHat, size: 22, color: color ?? c.brand),
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
  final String label;
  final bool on, locked, soon;
  final String? count, badge;
  final bool? step;
  final String soonLabel;
  final VoidCallback onTap;
  const _NavRow({required this.icon, required this.label, required this.on, this.count, this.step, required this.locked, required this.soon, required this.soonLabel, this.badge, required this.onTap});
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
              if (count != null)
                Text(
                  count!,
                  style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              if (step != null) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: step! ? c.good : c.lineStrong, shape: BoxShape.circle),
                ),
              ],
              if (badge != null) ...[const SizedBox(width: 8), Chip2(badge!, tone: Tone.danger)],
              if (soon) ...[const SizedBox(width: 8), Chip2(soonLabel)],
              if (locked) ...[const SizedBox(width: 8), Icon(LucideIcons.lock, size: 13, color: c.muted)],
            ],
          ),
        ),
      ),
    );
  }
}

// sections not rebuilt yet: say so, offer the website in the browser
class _Soon extends StatelessWidget {
  final RestCtx ctx;
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
              Text(ctx.t('rest.tabs.$tab'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
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
