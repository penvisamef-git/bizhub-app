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
import '../debt/dk_common.dart' show dkDate;
import '../mart/mart_common.dart' show GoldBtn;
import 'wb_common.dart';
import 'wb_data.dart';
import 'wb_editor.dart';
import 'wb_more.dart';

// Website Builder — the app version of the web's WebsiteDashboard.jsx (same API, same words, same sections).
const _tabs = <String, IconData>{
  'pages': LucideIcons.layers,
  'style': LucideIcons.palette,
  'profile': LucideIcons.store,
  'settings': LucideIcons.settings,
  'inbox': LucideIcons.inbox,
  'blog': LucideIcons.newspaper,
  'stats': LucideIcons.chartColumn,
  'telegram': LucideIcons.send,
  'addons': LucideIcons.puzzle,
};
const _groups = <(String, List<String>)>[
  ('build', ['pages', 'style', 'profile', 'settings']),
  ('grow', ['inbox', 'blog', 'stats', 'telegram']),
  ('more', ['addons']),
];
const _needs = {'blog': 'web_blog', 'telegram': 'web_telegram'};

class WebsitePage extends ConsumerStatefulWidget {
  final String id, title, tab;
  const WebsitePage({super.key, required this.id, this.title = '', this.tab = ''});
  @override
  ConsumerState<WebsitePage> createState() => _WebsitePageState();
}

class _WebsitePageState extends ConsumerState<WebsitePage> {
  Json? _data;
  String _error = '';
  String? _tab;
  bool _publishing = false;
  Future<void> Function()? _flush;

  String get _base => '${Api.user}/businesses/${widget.id}/website';
  String get _current => _tab ?? (_tabs.containsKey(widget.tab) ? widget.tab : 'pages');

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
      if (mounted) setState(() => _error = e.network ? ref.read(tProvider)('app.offline') : (e.message.isNotEmpty ? e.message : ref.read(tProvider)('wb.loadFail')));
    }
  }

  WbCtx _ctx() => WbCtx(
    id: widget.id,
    api: ref.read(apiProvider),
    t: ref.read(tProvider),
    data: _data!,
    reload: _reload,
    askBuy: _buy,
    go: (tab) => _goTab(_tabs.containsKey(tab) ? tab : 'pages'),
    notify: (text) => toast(context, text),
    put: (patch) {
      if (mounted) setState(() => _data = {..._data!, ...patch(_data!)});
    },
  );

  Future<void> _goTab(String tab) async {
    await _flush?.call();
    if (mounted) setState(() => _tab = tab);
  }

  Future<void> _publish() async {
    final t = ref.read(tProvider);
    setState(() => _publishing = true);
    try {
      await _flush?.call();
      final r = await ref.read(apiProvider).post('$_base/publish', {});
      setState(
        () => _data = {
          ..._data!,
          'site': {...obj(_data!['site']), ...obj(r['data'])},
        },
      );
      if (mounted) toast(context, t('wb.publishedOk'));
    } on ApiError catch (e) {
      if (e.status == 402) _buy({'renew': true});
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _publishing = false);
  }

  // one buy screen for: an add-on · a look · the yearly renewal
  Future<void> _buy(Json buying) async {
    final t = ref.read(tProvider);
    final lang = t.lang;
    String m(String k, [Map<String, Object?> v = const {}]) => t('wb.$k', v);
    final data = _data!;
    final api = ref.read(apiProvider);
    final site = obj(data['site']);
    final siteName = tx(site['name'], lang).isNotEmpty ? tx(site['name'], lang) : str(obj(data['business'])['name']);
    IconData icon = LucideIcons.puzzle;
    Widget? art;
    late String name, title, sub, done;
    late List<String> perks;
    late num price;
    late Future<Json> Function() buy;
    final once = '${m('oneTime')} · ${m('forever')}';
    if (buying['addon'] != null) {
      final key = str(buying['addon']);
      final a = obj(obj(data['addons'])[key]);
      if (a.isEmpty) return;
      final yearly = a['days'] != null;
      icon = wbAddonIcons[key] ?? LucideIcons.puzzle;
      name = t.or('wb.addonNames.$key', key);
      title = m('unlockTitle', {'name': name});
      sub = t.or('wb.addonWhat.$key', '');
      perks = [yearly ? '${fmt(n(a['price']))} ${m('coins')} ${m('perYear')}' : once];
      price = n(a['price']);
      buy = () => api.post('${Api.user}/businesses/${widget.id}/licenses/$key', {'expect': yearly ? a['expires_at'] : null});
      done = m('unlockDone', {'name': name});
    } else if (buying['theme'] != null) {
      final key = str(buying['theme']);
      final th = wbTheme(key);
      price = n(obj(data['themes'])['price']);
      name = m('themeName', {'name': th.name(lang)});
      icon = LucideIcons.palette;
      art = Container(
        width: 120,
        height: 84,
        decoration: BoxDecoration(color: Color(th.bg), borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(height: 10, color: Color(th.c)),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Color(th.c), Color(th.c2)]),
                  borderRadius: BorderRadius.circular(th.r.clamp(0, 14).toDouble()),
                ),
              ),
            ),
          ],
        ),
      );
      title = name;
      sub = m('themeWhat');
      perks = [once];
      buy = () => api.post('$_base/themes/$key', {});
      done = m('unlockDone', {'name': name});
    } else if (buying['renew'] != null) {
      price = n(data['renew_price']);
      icon = LucideIcons.globe;
      name = m('renewTitle');
      title = name;
      sub = m('renewSub');
      perks = ['${fmt(price)} ${m('coins')} ${m('perYear')}'];
      buy = () => api.post('${Api.user}/businesses/${widget.id}/licenses/website', {'expect': obj(data['license'])['expires_at']});
      done = name;
    } else {
      return;
    }
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BuySheet(
        stage: Container(
          width: 170,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFD86B), Color(0xFFE0A21A)]),
          ),
          child: Column(
            children: [
              art ?? Icon(icon, size: 54, color: const Color(0xFF5B3A00)),
              const SizedBox(height: 8),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF3A2500)),
              ),
              Text(
                siteName,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: const Color(0xFF3A2500).withValues(alpha: .7)),
              ),
            ],
          ),
        ),
        badge: m('badge'),
        title: title,
        sub: sub,
        perks: perks,
        price: price,
        buyLabel: m('buy', {'coins': fmt(price)}),
        doneTitle: name,
        doneSub: done,
        doneButton: t('app.continue'),
        buy: buy,
        onDone: (_) => _reload(),
      ),
    );
    if (mounted) setState(() {});
  }

  void _openSections() {
    final t = ref.read(tProvider);
    final c = context.c;
    final data = _data!;
    final unread = n(obj(data['counts'])['unread']).toInt();
    bool on(String k) => obj(obj(data['addons'])[k])['active'] == true;
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
            child: Text(t('wb.allSections'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          for (final (group, keys) in _groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
              child: Text(
                t('wb.groups.$group'),
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
                    _goTab(key);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    child: Row(
                      children: [
                        Icon(_tabs[key], size: 18, color: key == _current ? c.brandInk : c.ink),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            t('wb.tabs.$key'),
                            style: TextStyle(fontWeight: key == _current ? FontWeight.w800 : FontWeight.w600, color: key == _current ? c.brandInk : c.ink),
                          ),
                        ),
                        if (key == 'pages') Text(fmt(objs(data['pages']).length), style: TextStyle(color: c.muted, fontSize: 12.5)),
                        if (key == 'inbox' && unread > 0) ...[_Badge(unread), const SizedBox(width: 6)],
                        if (_needs[key] != null && !on(_needs[key]!)) Icon(LucideIcons.lock, size: 13, color: c.muted),
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
    String m(String k, [Map<String, Object?> v = const {}]) => t('wb.$k', v);
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
    final tab = _current;
    final s = ctx.site;
    final lic = ctx.license;
    final unread = n(obj(_data!['counts'])['unread']).toInt();
    final status = s['published'] != true
        ? 'draft'
        : s['changed_at'] != null
        ? 'changes'
        : 'live';
    final Widget section = switch (tab) {
      'pages' => WbEditor(key: ValueKey('pages${ctx.pages.isEmpty}'), ctx: ctx, onFlush: (f) => _flush = f),
      'style' => StyleTab(key: ValueKey('style${(obj(_data!['themes'])['owned'] as List? ?? const []).length}'), ctx: ctx),
      'profile' => ProfileTab(key: const ValueKey('profile'), ctx: ctx),
      'settings' => SettingsTab(key: ValueKey('settings${s['slug']}'), ctx: ctx),
      'inbox' => InboxTab(key: const ValueKey('inbox'), ctx: ctx),
      'blog' => BlogTab(key: ValueKey('blog${ctx.on('web_blog')}'), ctx: ctx),
      'stats' => StatsTab(key: ValueKey('stats${ctx.on('web_stats')}'), ctx: ctx),
      'telegram' => TelegramTab(key: ValueKey('telegram${ctx.on('web_telegram')}'), ctx: ctx),
      _ => AddonsTab(key: const ValueKey('addons'), ctx: ctx),
    };
    final tone = switch (status) {
      'live' => c.good,
      'changes' => c.warn,
      _ => c.muted,
    };
    return Scaffold(
      backgroundColor: c.appBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _top(context, tx(s['name'], ctx.lang).isNotEmpty ? tx(s['name'], ctx.lang) : str(ctx.business['name']), str(s['logo'])),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Chip2(m('badge'), icon: LucideIcons.globe),
                  Chip2(wbTheme(str(s['theme'])).name(ctx.lang), icon: LucideIcons.palette),
                  InkWell(
                    onTap: () => launchUrl(Uri.parse(ctx.siteUrl), mode: LaunchMode.externalApplication),
                    child: Chip2('/site/${s['slug']}', icon: LucideIcons.externalLink),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  CircleAvatar(radius: 4, backgroundColor: tone),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      m(
                        status == 'changes'
                            ? 'changes'
                            : status == 'live'
                            ? 'upToDate'
                            : 'draft',
                      ),
                      style: TextStyle(color: tone, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  if (s['published'] == true) ...[
                    Btn(
                      m('viewSite'),
                      icon: LucideIcons.externalLink,
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: () => launchUrl(Uri.parse(ctx.siteUrl), mode: LaunchMode.externalApplication),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Btn(
                    _publishing ? m('publishing') : m('publish'),
                    icon: LucideIcons.rocket,
                    small: true,
                    busy: _publishing,
                    onTap: _publishing || ctx.readOnly || ctx.pages.isEmpty || status == 'live' ? null : _publish,
                  ),
                ],
              ),
            ),
            if (ctx.business['status'] == false) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Alert(m('suspended'))),
            if (lic['locked'] == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Alert('${m('lockedTitle')} ${m('lockedSub')}', action: GoldBtn(m('renew', {'coins': fmt(n(_data!['renew_price']))}), onTap: () => _buy({'renew': true}))),
              ),
            if (lic['in_grace'] == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Alert(
                  m('graceSub', {'date': dkDate(lic['grace_until'], ctx.lang)}),
                  tone: Tone.warn,
                  action: GoldBtn(m('renew', {'coins': fmt(n(_data!['renew_price']))}), onTap: () => _buy({'renew': true})),
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
                          child: Text(t('wb.tabs.$tab'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                        if (unread > 0 && tab != 'inbox') ...[_Badge(unread), const SizedBox(width: 8)],
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
          RoundBtn(
            LucideIcons.arrowLeft,
            size: 42,
            onTap: () async {
              await _flush?.call();
              if (context.mounted) context.pop();
            },
          ),
          const SizedBox(width: 10),
          if (logo != null) ...[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(14)),
              clipBehavior: Clip.antiAlias,
              child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.globe, size: 22, color: c.brand),
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
