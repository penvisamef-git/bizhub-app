import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/buy_sheet.dart';
import '../../widgets/ui.dart';
import '../team/team_frame.dart' show TeamTopBtn;
import '../mart/mart_common.dart' show GoldBtn;
import 'sc_card.dart';
import 'sc_common.dart';
import 'sc_counter.dart';
import 'sc_poster.dart';
import 'sc_setup.dart';

// Loyalty Stamp Card — the app version of the web's StampDashboard.jsx (same API, same words, same sections).
const _tabs = <String, IconData>{
  'stamp': LucideIcons.stamp,
  'customers': LucideIcons.users,
  'history': LucideIcons.history,
  'stats': LucideIcons.chartColumn,
  'shopqr': LucideIcons.qrCode,
  'telegram': LucideIcons.send,
  'design': LucideIcons.palette,
  'desk': LucideIcons.monitor,
  'addons': LucideIcons.puzzle,
};
const _groups = <(String, List<String>)>[
  ('card', ['stamp', 'customers', 'history']),
  ('grow', ['stats', 'shopqr', 'telegram']),
  ('setup', ['design', 'desk', 'addons']),
];
const _needs = {'telegram': 'sc_telegram'};
const _graceDays = 7;

class StampPage extends ConsumerStatefulWidget {
  final String id, title, tab;
  const StampPage({super.key, required this.id, this.title = '', this.tab = ''});
  @override
  ConsumerState<StampPage> createState() => _StampPageState();
}

class _StampPageState extends ConsumerState<StampPage> {
  Json? _data;
  String _error = '';
  String? _tab;
  int _nav = 0;

  String get _base => '${Api.user}/businesses/${widget.id}/stamps';
  String get _current => _tab ?? (_tabs.containsKey(widget.tab) ? widget.tab : 'stamp');

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
      if (mounted) setState(() => _error = e.network ? ref.read(tProvider)('app.offline') : (e.message.isNotEmpty ? e.message : ref.read(tProvider)('sc.loadFail')));
    }
  }

  ScCtx _ctx() => ScCtx(
    id: widget.id,
    api: ref.read(apiProvider),
    t: ref.read(tProvider),
    data: _data!,
    reload: _reload,
    askBuy: _buy,
    go: (tab) => setState(() {
      _tab = tab;
      _nav++;
    }),
    notify: (text) => toast(context, text),
  );

  // renew · an add-on · a card design · a poster
  Future<void> _buy(String kind, {String? item}) async {
    final ctx = _ctx();
    final api = ref.read(apiProvider);
    final lic = ctx.license;
    late final String name, title, sub, label;
    late final List<String> perks;
    late final num price;
    late final Future<Json> Function() buy;
    Widget? stage;
    if (kind == 'renew') {
      price = n(lic['price']);
      name = ctx.m('renewTitle');
      title = name;
      sub = ctx.m('renewSub');
      perks = ['${fmt(price)} ${ctx.m('coins')} ${ctx.m('perYear')}'];
      label = ctx.m('renewFor', {'coins': fmt(price)});
      buy = () => api.post('${Api.user}/businesses/${widget.id}/licenses/stamp_card', {'expect': lic['expires_at']});
    } else if (kind == 'theme' && item != null) {
      price = ctx.themePrice;
      name = ctx.m('themeName', {'name': scThemeName(item, ctx.lang)});
      title = name;
      sub = ctx.m('themeWhat');
      perks = ['${ctx.m('oneTime')} · ${ctx.m('forever')}'];
      label = ctx.m('buy', {'coins': fmt(price)});
      buy = () => api.post('$_base/themes/$item');
      stage = SizedBox(width: 230, child: ScCardView(shop: ctx.shop(theme: item, color: ''), lang: ctx.lang, compact: true));
    } else if (kind == 'poster' && item != null) {
      price = ctx.posterPrice;
      name = ctx.m('posterName', {'name': scPosterName(item, ctx.lang)});
      title = name;
      sub = ctx.m('posterWhat');
      perks = ['${ctx.m('oneTime')} · ${ctx.m('forever')}'];
      label = ctx.m('buy', {'coins': fmt(price)});
      buy = () => api.post('$_base/posters/$item');
      stage = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ScPosterView(poster: item, url: shopUrl(ctx.program['slug']), shop: ctx.shop(), rule: ctx.m('posterRule', {'goal': ctx.goal, 'reward': levelName(ctx.levels.last, ctx.lang)}), width: 150),
      );
    } else {
      final a = ctx.addon(kind);
      if (a.isEmpty) return;
      final yearly = a['days'] != null;
      price = n(a['price']);
      name = ctx.m('addonNames.$kind');
      title = ctx.m('unlockTitle', {'name': name});
      sub = ctx.m('addonWhat.$kind');
      perks = [...ctx.t.list('sc.perks.$kind'), yearly ? '${fmt(price)} ${ctx.m('coins')} ${ctx.m('perYear')}' : '${ctx.m('oneTime')} · ${ctx.m('forever')}'];
      label = ctx.m('buy', {'coins': fmt(price)});
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
          Icon(kind == 'renew' ? LucideIcons.calendarClock : scAddonIcons[kind] ?? LucideIcons.puzzle, size: 54, color: const Color(0xFF5B3A00)),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF3A2500)),
          ),
          Text(
            ctx.shopName,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: const Color(0xFF3A2500).withValues(alpha: .7)),
          ),
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
        doneSub: kind == 'renew' ? ctx.m('renewTitle') : ctx.m('unlockDone', {'name': name}),
        doneSubOf: kind == 'renew' ? (r) => ctx.m('renewDone', {'date': scDate(obj(r['data'])['expires_at'] ?? obj(obj(r['data'])['license'])['expires_at'], ctx.lang)}) : null,
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheet) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(t('sc.allSections'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          for (final (group, keys) in _groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
              child: Text(
                t('sc.groups.$group'),
                style: TextStyle(color: c.muted, fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ),
            for (final key in keys)
              Material(
                color: key == _current ? c.active : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.pop(sheet);
                    setState(() {
                      _tab = key;
                      _nav++;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    child: Row(
                      children: [
                        Icon(_tabs[key], size: 18, color: key == _current ? c.brandInk : c.ink),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            t('sc.tabs.$key'),
                            style: TextStyle(fontWeight: key == _current ? FontWeight.w800 : FontWeight.w600, color: key == _current ? c.brandInk : c.ink),
                          ),
                        ),
                        if (key == 'customers') Text(fmt(n(ctx.totals['customers'])), style: TextStyle(color: c.muted, fontSize: 12.5)),
                        if (key == 'stamp' && n(ctx.totals['ready']) > 0) _Badge(n(ctx.totals['ready']).toInt()),
                        if (_needs[key] != null && !ctx.on(_needs[key]!)) Icon(LucideIcons.lock, size: 13, color: c.muted),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
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
                  child: _error.isNotEmpty ? LoadError(text: _error, retry: t('sc.retry'), onRetry: _reload) : const SkelList(rows: 6),
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
    final ready = n(ctx.totals['ready']).toInt();
    final exp = DateTime.tryParse('${lic['expires_at'] ?? ''}');
    final graceLeft = exp == null ? 0 : (_graceDays - DateTime.now().difference(exp).inDays).clamp(0, _graceDays);
    final needRenew = lic['status'] == 'expiring' || lic['in_grace'] == true || lic['locked'] == true;
    final Widget section = switch (tab) {
      'customers' => CustomersTab(key: ValueKey('customers$_nav'), ctx: ctx),
      'history' => HistoryTab(key: const ValueKey('history'), ctx: ctx),
      'stats' => StatsTab(key: const ValueKey('stats'), ctx: ctx),
      'shopqr' => ShopQrTab(key: ValueKey('shopqr${ctx.program['poster']}${ctx.ownedPosters.length}'), ctx: ctx),
      'telegram' => TelegramTab(key: ValueKey('telegram${ctx.on('sc_telegram')}'), ctx: ctx),
      'design' => DesignTab(key: ValueKey('design${ctx.program['logo']}${ctx.ownedThemes.length}'), ctx: ctx),
      'desk' => DeskTab(key: const ValueKey('desk'), ctx: ctx),
      'addons' => AddonsTab(key: const ValueKey('addons'), ctx: ctx),
      _ => StampTab(key: ValueKey('stamp$_nav'), ctx: ctx),
    };
    final url = shopUrl(ctx.program['slug']);
    return Scaffold(
      backgroundColor: c.appBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _top(context, ctx.shopName, str(ctx.program['logo'])),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Chip2(t('sc.badge'), icon: LucideIcons.stamp),
                  if (exp != null) ...[
                    const SizedBox(width: 6),
                    Chip2(
                      t('sc.endsOn', {'date': scDate(exp, ctx.lang)}),
                      icon: LucideIcons.calendarClock,
                      tone: lic['locked'] == true
                          ? Tone.danger
                          : lic['status'] == 'expiring' || lic['in_grace'] == true
                          ? Tone.warn
                          : Tone.good,
                    ),
                  ],
                  const SizedBox(width: 6),
                  Chip2(fmt(n(ctx.totals['customers'])), icon: LucideIcons.users),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Icon(LucideIcons.externalLink, size: 14),
                    label: Text(t('sc.openShop')),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                  ),
                  const SizedBox(width: 6),
                  ActionChip(avatar: const Icon(LucideIcons.copy, size: 14), label: Text(t('sc.copyLink')), visualDensity: VisualDensity.compact, onPressed: () => scCopy(ctx, url)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (ctx.business['status'] == false) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Alert(t('sc.suspended'))),
            if (lic['in_grace'] == true || lic['locked'] == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: lic['locked'] == true ? c.dangerBg : c.warnBg, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lic['locked'] == true ? t('sc.lockedTitle') : t('sc.graceTitle'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(lic['locked'] == true ? t('sc.lockedSub') : t('sc.graceSub', {'n': graceLeft}), style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 8),
                      GoldBtn(t('sc.renewFor', {'coins': fmt(n(lic['price']))}), onTap: ctx.business['status'] == false ? null : () => _buy('renew')),
                    ],
                  ),
                ),
              )
            else if (needRenew)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GoldBtn(t('sc.renewFor', {'coins': fmt(n(lic['price']))}), onTap: ctx.business['status'] == false ? null : () => _buy('renew')),
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
                        Expanded(
                          child: Text(t('sc.tabs.$tab'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                        if (ready > 0 && tab != 'stamp') ...[_Badge(ready), const SizedBox(width: 8)],
                        Text(
                          t('sc.allSections'),
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
              child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.stamp, size: 22, color: c.brand),
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

class _Badge extends StatelessWidget {
  final int n;
  const _Badge(this.n);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: context.c.danger, borderRadius: BorderRadius.circular(99)),
    child: Text(
      n > 99 ? '99+' : '$n',
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11.5),
    ),
  );
}
