import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../team/team_data.dart' show teamViewOnly;
import '../team/team_frame.dart' show TeamTopBtn;
import 'fb_books.dart';
import 'fb_common.dart';
import 'fb_data.dart';
import 'fb_extras.dart';
import 'fb_look.dart';
import 'fb_more.dart';

// Flip Book PDF — the app version of the web's FlipBookDashboard.jsx (same API, same words, same sections).
const _tabs = <String, IconData>{
  'books': LucideIcons.bookOpen,
  'categories': LucideIcons.folderOpen,
  'library': LucideIcons.library,
  'info': LucideIcons.info,
  'reader': LucideIcons.bookOpenText,
  'share': LucideIcons.qrCode,
  'leads': LucideIcons.users,
  'stats': LucideIcons.chartColumn,
  'addons': LucideIcons.puzzle,
};
const _groups = <(String?, List<String>)>[
  ('build', ['books', 'categories']),
  ('look', ['library', 'info', 'reader']),
  ('share', ['share']),
  ('grow', ['leads', 'stats']),
  (null, ['addons']),
];
const _needs = {'stats': 'fb_stats'};

class FlipBookPage extends ConsumerStatefulWidget {
  final String id, title, tab;
  const FlipBookPage({super.key, required this.id, this.title = '', this.tab = ''});
  @override
  ConsumerState<FlipBookPage> createState() => _FlipBookPageState();
}

class _FlipBookPageState extends ConsumerState<FlipBookPage> {
  Json? _data;
  String _error = '';
  String? _tab;

  String get _base => '${Api.user}/businesses/${widget.id}/flipbook';
  String get _current => _tab ?? (_tabs.containsKey(widget.tab) ? widget.tab : 'books');

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final api = ref.read(apiProvider);
    try {
      final r = await Future.wait([api.get(_base), api.get('$_base/books'), api.get('$_base/categories')]);
      if (!mounted) return;
      final o = obj(r[0]['data']);
      setState(() {
        _data = {...o, 'books': objs(r[1]['data']), 'room': r[1]['room'] ?? o['room'], 'categories': objs(r[2]['data'])};
        _error = '';
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.network ? ref.read(tProvider)('app.offline') : (e.message.isNotEmpty ? e.message : ref.read(tProvider)('fb.loadFail')));
    }
  }

  FbCtx _ctx() => FbCtx(
    id: widget.id,
    api: ref.read(apiProvider),
    t: ref.read(tProvider),
    data: _data!,
    reload: _reload,
    askBuy: _buy,
    go: (tab) => setState(() => _tab = _tabs.containsKey(tab) ? tab : 'books'),
    notify: (text) => toast(context, text),
    put: (patch) {
      if (mounted) setState(() => _data = {..._data!, ...patch(_data!)});
    },
  );

  // one buy screen for: an add-on · a library design · a reader look · a book password
  Future<void> _buy(Json buying) async {
    final t = ref.read(tProvider);
    final lang = t.lang;
    String m(String k, [Map<String, Object?> v = const {}]) => t('fb.$k', v);
    final data = _data!;
    final prices = obj(data['prices']);
    final api = ref.read(apiProvider);
    final business = str(obj(data['business'])['name']);
    IconData icon = LucideIcons.puzzle;
    late String name, title, sub, done;
    late List<String> perks;
    late num price;
    late Future<Json> Function() buy;
    final once = '${m('oneTime')} · ${m('forever')}';
    if (buying['addon'] != null) {
      final key = str(buying['addon']);
      final a = obj(obj(data['addons'])[key]);
      if (a.isEmpty) return;
      icon = fbAddonIcons[key] ?? LucideIcons.puzzle;
      name = t.or('fb.addonNames.$key', key);
      title = m('unlockTitle', {'name': name});
      sub = t.or('fb.addonWhat.$key', '');
      perks = [t.or('fb.addonFree.$key', ''), a['days'] != null ? '${fmt(n(a['price']))} ${m('coins')} ${m('perYear')}' : once].where((x) => x.isNotEmpty).toList();
      price = n(a['price']);
      buy = () => api.post('${Api.user}/businesses/${widget.id}/licenses/$key', {'expect': a['expires_at']});
      done = m('unlockDone', {'name': name});
    } else if (buying['shelf'] != null) {
      final key = str(buying['shelf']);
      final s = fbShelves[key];
      price = n(prices[s?.isLive == true ? 'fb_shelf_live' : 'fb_shelf_theme']);
      name = m('designName', {'name': s?.name(lang) ?? key});
      icon = LucideIcons.palette;
      title = name;
      sub = m('designWhat');
      perks = [once];
      buy = () => api.post('$_base/shelf-themes/$key', {});
      done = m('unlockDone', {'name': name});
    } else if (buying['reader'] != null) {
      final key = str(buying['reader']);
      price = n(prices['fb_reader_theme']);
      name = m('readerName', {'name': fbReaders[key]?.name(lang) ?? key});
      icon = LucideIcons.bookOpenText;
      title = name;
      sub = m('readerWhat');
      perks = [once];
      buy = () => api.post('$_base/reader-themes/$key', {});
      done = m('unlockDone', {'name': name});
    } else if (buying['password'] != null) {
      final b = obj(buying['password']);
      price = n(prices['fb_password']);
      name = m('pwName');
      icon = LucideIcons.lock;
      title = '${m('pwName')} · ${b['title']}';
      sub = m('pwWhat');
      perks = [once, m('pwNote')];
      buy = () => api.post('$_base/books/${b['_id']}/password-unlock', {});
      done = m('unlockDone', {'name': name});
    } else {
      return;
    }
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BuySheet(
        // the look itself when the caller sends its picture, else the gold card
        stage: buying['stage'] is Widget
            ? buying['stage'] as Widget
            : Container(
                width: 170,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFD86B), Color(0xFFE0A21A)]),
                ),
                child: Column(
                  children: [
                    Icon(icon, size: 54, color: const Color(0xFF5B3A00)),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF3A2500)),
                    ),
                    Text(
                      business,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: const Color(0xFF3A2500).withValues(alpha: .7)),
                    ),
                  ],
                ),
              ),
        badge: 'Flip Book PDF',
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
    final room = obj(data['room']);
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
            child: Text(t('fb.allSections'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          for (final (group, keys) in _groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
              child: group == null
                  ? const Divider(height: 1)
                  : Text(
                      t('fb.groups.$group'),
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
                    setState(() => _tab = key);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    child: Row(
                      children: [
                        Icon(_tabs[key], size: 18, color: key == _current ? c.brandInk : c.ink),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            t('fb.tabs.$key'),
                            style: TextStyle(fontWeight: key == _current ? FontWeight.w800 : FontWeight.w600, color: key == _current ? c.brandInk : c.ink),
                          ),
                        ),
                        if (key == 'books')
                          Text('${room['books']}/${room['book_capacity']}', style: TextStyle(color: n(room['books']) >= n(room['book_capacity']) ? c.danger : c.muted, fontSize: 12.5)),
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
    String m(String k, [Map<String, Object?> v = const {}]) => t('fb.$k', v);
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
    final room = ctx.room;
    final url = shelfUrl(ctx.settings['slug']);
    final Widget section = switch (tab) {
      'books' => BooksTab(key: const ValueKey('books'), ctx: ctx),
      'categories' => CategoriesTab(key: const ValueKey('categories'), ctx: ctx),
      'share' => ShareTab(key: ValueKey('share${ctx.settings['qr_style']}'), ctx: ctx),
      'library' => LibraryTab(key: ValueKey('library${(_data!['shelf_themes'] as List? ?? const []).length}'), ctx: ctx),
      'info' => InfoTab(key: const ValueKey('info'), ctx: ctx),
      'reader' => ReaderTab(key: const ValueKey('reader'), ctx: ctx),
      'leads' => LeadsTab(key: ValueKey('leads${ctx.on('fb_leads')}'), ctx: ctx),
      'stats' => StatsTab(key: ValueKey('stats${ctx.on('fb_stats')}'), ctx: ctx),
      _ => AddonsTab(key: const ValueKey('addons'), ctx: ctx),
    };
    return Scaffold(
      backgroundColor: c.appBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _top(context, str(ctx.business['name']), ctx.logo),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Chip2('Flip Book PDF', icon: LucideIcons.bookOpen),
                  Chip2(m('room', {'n': room['books'], 'max': room['book_capacity']}), icon: LucideIcons.bookOpen),
                  Chip2(fmt(ctx.categories.length), icon: LucideIcons.folderOpen),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Btn(
                    m('openLibrary'),
                    icon: LucideIcons.externalLink,
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                  ),
                  const SizedBox(width: 6),
                  Btn(
                    m('copyLink'),
                    icon: LucideIcons.copy,
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: url));
                      if (context.mounted) toast(context, m('copied'));
                    },
                  ),
                ],
              ),
            ),
            if (ctx.readOnly && !teamViewOnly(ctx.id)) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Alert(m('suspended'))),
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
                          child: Text(t('fb.tabs.$tab'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
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
              child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.bookOpen, size: 22, color: c.brand),
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
