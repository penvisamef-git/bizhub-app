import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../team/team_frame.dart' show TeamTopBtn;
import 'nt_api.dart';
import 'nt_common.dart';
import 'nt_extras_reg.dart';
import 'nt_list.dart';
import 'nt_more_reg.dart';

// Digital Note — the app version of the web's NoteDashboard.jsx (same API, same words, same sections).
//   Notes: My notes · Groups   More: Storage & plan · Media · Telegram alerts · Business profile   Add-ons (on its own, last)
//
// EXTENDING: a section is one entry in ntSections (key, icon, builder). Phase 2 replaces the placeholder builders
// (groups, storage, media, alerts, profile, addons) with ntSetSection('groups', (ctx) => GroupsTab(ctx: ctx)) etc.

typedef NtSectionBuilder = Widget Function(NtCtx ctx, NtNav nav);

class NtNav {
  final void Function(String section, {Json? args}) go; // open another section
  final Json args; // what the last go() gave (e.g. { group: id })
  const NtNav({required this.go, this.args = const {}});
}

class NtSection {
  final String key;
  final IconData icon;
  NtSectionBuilder builder;
  NtSection(this.key, this.icon, this.builder);
}

final ntSections = <NtSection>[
  NtSection('notes', LucideIcons.stickyNote, (ctx, nav) => NotesTab(key: const ValueKey('notes'), ctx: ctx, nav: nav)),
  NtSection('groups', LucideIcons.folders, (ctx, nav) => NtSoon(ctx: ctx, section: 'groups')),
  NtSection('storage', LucideIcons.hardDrive, (ctx, nav) => NtSoon(ctx: ctx, section: 'storage')),
  NtSection('media', LucideIcons.images, (ctx, nav) => NtSoon(ctx: ctx, section: 'media')),
  NtSection('alerts', LucideIcons.bellRing, (ctx, nav) => NtSoon(ctx: ctx, section: 'alerts')),
  NtSection('profile', LucideIcons.building2, (ctx, nav) => NtSoon(ctx: ctx, section: 'profile')),
  NtSection('addons', LucideIcons.puzzle, (ctx, nav) => NtSoon(ctx: ctx, section: 'addons')),
];
// the menu: Notes · More · Add-ons last on its own (like every other business)
const ntMenu = <(String?, List<String>)>[
  ('notes', ['notes', 'groups']),
  ('more', ['storage', 'media', 'alerts', 'profile']),
  (null, ['addons']),
];

void ntSetSection(String key, NtSectionBuilder builder) => ntSections.firstWhere((s) => s.key == key).builder = builder;

class NotePage extends ConsumerStatefulWidget {
  final String id, title, tab;
  const NotePage({super.key, required this.id, this.title = '', this.tab = ''});
  @override
  ConsumerState<NotePage> createState() => _NotePageState();
}

bool _registered = false;
void _registerOnce() {
  if (_registered) return;
  _registered = true;
  ntRegisterSections(); // phase 2a (nt_more_reg.dart)
  ntRegisterExtras(); // phase 2b (nt_extras_reg.dart)
}

class _NotePageState extends ConsumerState<NotePage> {
  Json? _data;
  String _error = '';
  String? _tab;
  Json _args = const {};
  int _nav = 0;

  NtApi get _a => NtApi(ref.read(apiProvider), widget.id);
  String get _current => _tab ?? (ntSections.any((s) => s.key == widget.tab) ? widget.tab : 'notes');

  @override
  void initState() {
    super.initState();
    _registerOnce();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final r = await _a.book();
      if (!mounted) return;
      setState(() {
        _data = obj(r['data']);
        _error = '';
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.network ? ref.read(tProvider)('app.offline') : (e.message.isNotEmpty ? e.message : ref.read(tProvider)('note.loadFail')));
    }
  }

  NtCtx _ctx() => NtCtx(
    id: widget.id,
    a: _a,
    t: ref.read(tProvider),
    data: _data!,
    reload: _reload,
    notify: (text) {
      if (mounted) toast(context, text);
    },
    askBuy: (product, {item, qty = 1, extra}) => ntUnlock(context, _ctx(), product, item: item, qty: qty, extra: extra),
  );

  void _go(String section, {Json? args}) => setState(() {
    _tab = section;
    _args = args ?? const {};
    _nav++;
  });

  void _openSections() {
    final ctx = _ctx();
    final c = context.c;
    final due = obj(ctx.counts['due']);
    final late = n(due['overdue']).toInt();
    final locks = {'media': !ctx.media, 'alerts': !ctx.tg};
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
            child: Text(ctx.m('allSections'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          for (final (group, keys) in ntMenu) ...[
            if (group != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                child: Text(
                  ctx.m('groups.$group'),
                  style: TextStyle(color: c.muted, fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              )
            else
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(color: c.line, height: 1)),
            for (final key in keys)
              Material(
                color: key == _current ? c.active : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.pop(sheet);
                    _go(key);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    child: Row(
                      children: [
                        Icon(ntSections.firstWhere((s) => s.key == key).icon, size: 18, color: key == _current ? c.brandInk : c.ink),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ctx.m('tabs.$key'),
                            style: TextStyle(fontWeight: key == _current ? FontWeight.w800 : FontWeight.w600, color: key == _current ? c.brandInk : c.ink),
                          ),
                        ),
                        if (key == 'notes') ...[
                          Text(fmt(n(ctx.counts['notes'])), style: TextStyle(color: c.muted, fontSize: 12.5)),
                          if (late > 0) ...[const SizedBox(width: 6), NtBadge(late)],
                        ],
                        if (key == 'groups') Text(fmt(n(ctx.counts['groups'])), style: TextStyle(color: c.muted, fontSize: 12.5)),
                        if (locks[key] == true) Icon(LucideIcons.lock, size: 13, color: c.muted),
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
                  child: _error.isNotEmpty ? LoadError(text: _error, retry: t('note.retry'), onRetry: _reload) : const SkelList(rows: 6),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final ctx = _ctx();
    final tab = _current;
    final section = ntSections.firstWhere((s) => s.key == tab);
    final late = n(obj(ctx.counts['due'])['overdue']).toInt();
    return Scaffold(
      backgroundColor: c.appBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _top(context, ctx.bizName.isNotEmpty ? ctx.bizName : widget.title, ctx.logo),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Chip2(ctx.m('badge'), icon: LucideIcons.stickyNote),
                  const SizedBox(width: 6),
                  _PlanChip(ctx: ctx),
                ],
              ),
            ),
            if (ctx.readOnly || ctx.inGrace)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Alert(
                  ctx.m('locked'),
                  tone: ctx.readOnly ? Tone.danger : Tone.warn,
                  action: NtGoldBtn(ctx.m('renewNow', {'coins': fmt(ctx.price('digital_note'))}), onTap: () => ctx.askBuy('digital_note')),
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
                        Icon(section.icon, size: 18, color: c.brand),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(ctx.m('tabs.$tab'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                        if (late > 0 && tab != 'notes') ...[NtBadge(late), const SizedBox(width: 8)],
                        Text(
                          ctx.m('allSections'),
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
            Expanded(
              child: KeyedSubtree(
                key: ValueKey('$tab$_nav'),
                child: section.builder(ctx, NtNav(go: _go, args: _args)),
              ),
            ),
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
              child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.stickyNote, size: 22, color: c.brand),
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

// Active until … / n days left / Ended
class _PlanChip extends StatelessWidget {
  final NtCtx ctx;
  const _PlanChip({required this.ctx});
  @override
  Widget build(BuildContext context) {
    final l = ctx.license;
    if (l['expires_at'] == null) return const SizedBox.shrink();
    final date = ntDate(l['expires_at'], ctx.lang);
    if (ctx.readOnly || ctx.inGrace) return Chip2(ctx.m('planEnded', {'date': date}), tone: Tone.danger);
    final left = n(l['days_left']).toInt();
    if (left > 0 && left <= 30) return Chip2(ctx.m('planDays', {'n': left}), tone: Tone.warn);
    return Chip2(ctx.m('planActive', {'date': date}), tone: Tone.good);
  }
}

class NtBadge extends StatelessWidget {
  final int n;
  const NtBadge(this.n, {super.key});
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

// a section that comes in the next app update (phase 2 replaces these with ntSetSection)
class NtSoon extends StatelessWidget {
  final NtCtx ctx;
  final String section;
  const NtSoon({super.key, required this.ctx, required this.section});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
    children: [
      Panel(
        child: NtEmpty(icon: ntSections.firstWhere((s) => s.key == section).icon, title: ctx.m('tabs.$section'), sub: ctx.x('soon')),
      ),
    ],
  );
}
