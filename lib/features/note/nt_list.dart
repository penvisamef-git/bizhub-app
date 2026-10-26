import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_kit.dart' show showSheet;
import 'nt_common.dart';
import 'nt_editor.dart';
import 'nt_groups_pick.dart';
import 'nt_new.dart';
import 'nt_page.dart' show NtNav;

// My notes: search, filters (all / pinned / shared / due / deleted), sort, list or grid, pin / copy link / copy /
// delete / restore / delete forever (the web's NoteList.jsx). 30 a page, more as you scroll.

const _filters = ['all', 'pinned', 'shared', 'due', 'deleted'];
const _sorts = ['updated', 'created', 'title'];

class NotesTab extends StatefulWidget {
  final NtCtx ctx;
  final NtNav nav;
  const NotesTab({super.key, required this.ctx, required this.nav});
  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  NtCtx get ctx => widget.ctx;
  final _q = TextEditingController();
  String _filter = 'all', _sort = 'updated';
  late String _view = ntView('notes');
  List<Json>? _rows;
  int _page = 1, _pages = 1;
  bool _more = false;
  bool _fresh = false; // a new search / filter is on its way: no next page until it's back
  bool _moreFailed = false; // a next page failed: no retry on every scroll (the button below asks again)
  String _error = '';
  Map<String, Json> _groups = const {};
  int _ask = 0; // only the newest search answer is used

  @override
  void initState() {
    super.initState();
    _load();
    _loadGroups();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    try {
      final r = await ctx.a.groups();
      if (mounted) setState(() => _groups = {for (final g in objs(r['data'])) str(g['_id']): g});
    } catch (_) {}
  }

  Future<void> _load({bool next = false}) async {
    if (next && (_fresh || _more || _moreFailed)) return;
    final ask = ++_ask;
    if (next) {
      setState(() => _more = true);
    } else {
      _fresh = true;
      _moreFailed = false;
    }
    try {
      final r = await ctx.a.notes(q: _q.text.trim(), filter: _filter, sort: _sort, page: next ? _page + 1 : 1);
      if (!mounted || ask != _ask) return;
      setState(() {
        final rows = objs(r['data']);
        _rows = next ? [...?_rows, ...rows] : rows;
        _page = n(r['page']).toInt().clamp(1, 1000);
        _pages = n(r['pages']).toInt().clamp(1, 1000);
        _more = false;
        if (!next) _fresh = false;
        _error = '';
      });
    } catch (e) {
      if (!mounted || ask != _ask) return;
      setState(() {
        _more = false;
        if (next) {
          _moreFailed = true; // shown as a "Try again" row at the end, not the whole list's error
        } else {
          _fresh = false;
          _error = ctx.errText(e);
        }
      });
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_load(), ctx.reload(), _loadGroups()]);
  }

  Future<void> _new() async {
    final made = await ntNewNote(context, ctx);
    if (made == null || !mounted) return;
    await ntOpenNote(context, ctx, str(made.$1['_id']), first: made.$1);
    if (mounted) _refresh();
  }

  Future<void> _open(Json row) async {
    if (row['deleted'] == true) return _menu(row);
    await ntOpenNote(context, ctx, str(row['_id']));
    if (mounted) _refresh();
  }

  void _drop(String id) => setState(() => _rows = (_rows ?? const <Json>[]).where((r) => str(r['_id']) != id).toList());

  Future<void> _menu(Json row) async {
    final id = str(row['_id']);
    final deleted = row['deleted'] == true;
    final pinned = row['pinned'] == true;
    final pick = await showSheet<String>(
      context,
      (s) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                str(row['title']).isEmpty ? ctx.m('untitled') : str(row['title']),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
            if (!deleted) ...[
              _item(s, 'open', LucideIcons.pencil, ctx.x('openNote')),
              _item(s, 'pin', pinned ? LucideIcons.pinOff : LucideIcons.pin, pinned ? ctx.m('unpin') : ctx.m('pin')),
              _item(s, 'copy', LucideIcons.link, ctx.m('copyLink')),
              if (!ctx.readOnly) _item(s, 'duplicate', LucideIcons.copy, ctx.m('duplicate')),
              _item(s, 'delete', LucideIcons.trash2, ctx.m('delete'), danger: true),
            ] else ...[
              _item(s, 'restore', LucideIcons.rotateCcw, ctx.m('restore')),
              _item(s, 'forever', LucideIcons.trash2, ctx.m('deleteForever'), danger: true),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    if (pick == null || !mounted) return;
    switch (pick) {
      case 'open':
        await _open(row);
      case 'pin':
        final r = await ctx.run(() => ctx.a.update(id, {'pinned': !pinned}));
        if (r != null) _load();
      case 'copy':
        await Clipboard.setData(ClipboardData(text: ntUrl(obj(row['share'])['path'])));
        ctx.notify(ctx.m('copied'));
      case 'duplicate':
        final r = await ctx.run(() => ctx.a.duplicate(id), ctx.m('copiedOk'));
        if (r != null) _refresh();
      case 'delete':
        if (!await ntConfirm(context, ctx, ctx.m('deleteAsk'), ctx.m('deleteAskSub'))) return;
        final r = await ctx.run(() => ctx.a.remove(id), ctx.m('deletedOk'));
        if (r != null) {
          _drop(id);
          ctx.reload();
        }
      case 'restore':
        final r = await ctx.run(() => ctx.a.restore(id), ctx.m('restoredOk'));
        if (r != null) {
          _drop(id);
          ctx.reload();
        }
      case 'forever':
        if (!await ntConfirm(context, ctx, ctx.m('forever'), ctx.m('foreverSub'), yes: ctx.m('deleteForever'))) return;
        final r = await ctx.run(() => ctx.a.forever(id), ctx.m('goneOk'));
        if (r != null) {
          _drop(id);
          ctx.reload();
        }
    }
  }

  Widget _item(BuildContext s, String key, IconData icon, String label, {bool danger = false}) {
    final c = s.c;
    return ListTile(
      leading: Icon(icon, color: danger ? c.danger : c.ink, size: 20),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: danger ? c.danger : c.ink)),
      onTap: () => Navigator.pop(s, key),
    );
  }

  int _dueCount() {
    final d = obj(ctx.counts['due']);
    return (n(d['overdue']) + n(d['today']) + n(d['week'])).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = _rows;
    final counts = {'all': n(ctx.counts['notes']).toInt(), 'shared': n(ctx.counts['shared']).toInt(), 'due': _dueCount()};
    return RefreshIndicator(
      onRefresh: _refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (s) {
          if (s.metrics.extentAfter < 300 && !_more && _page < _pages && rows != null) _load(next: true);
          return false;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Field(
                          controller: _q,
                          hint: ctx.m('search'),
                          icon: LucideIcons.search,
                          onChanged: (_) => _load(),
                          suffix: _q.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _q.clear();
                                    _load();
                                  },
                                  icon: Icon(LucideIcons.x, size: 18, color: c.muted),
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      NtViewSwitch(
                        ctx: ctx,
                        value: _view,
                        onChanged: (v) {
                          ntSetView('notes', v);
                          setState(() => _view = v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: NtChips<String>(
                          value: _filter,
                          onChanged: (v) {
                            setState(() {
                              _filter = v;
                              _rows = null;
                            });
                            _load();
                          },
                          items: [for (final k in _filters) (k, ctx.m('filters.$k'), counts[k])],
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: ctx.m('sorts.$_sort'),
                        initialValue: _sort,
                        onSelected: (v) {
                          setState(() => _sort = v);
                          _load();
                        },
                        itemBuilder: (_) => [for (final k in _sorts) PopupMenuItem(value: k, child: Text(ctx.m('sorts.$k')))],
                        icon: Icon(LucideIcons.arrowUpDown, size: 19, color: c.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Btn(ctx.m('newNote'), icon: LucideIcons.plus, expand: true, onTap: ctx.readOnly ? null : _new),
                ],
              ),
            ),
            if (rows == null && _error.isEmpty)
              const SliverPadding(padding: EdgeInsets.symmetric(horizontal: 16), sliver: SliverToBoxAdapter(child: SkelList(rows: 5)))
            else if (rows == null)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(child: LoadError(text: _error, retry: ctx.m('retry'), onRetry: _load)),
              )
            else if (rows.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Panel(
                    child: _filter == 'deleted'
                        ? NtEmpty(icon: LucideIcons.trash2, title: ctx.m('noDeleted'))
                        : (_q.text.isNotEmpty || _filter != 'all')
                        ? NtEmpty(icon: LucideIcons.searchX, title: _filter == 'due' ? ctx.m('dueNone') : ctx.m('noMatch'))
                        : NtEmpty(
                            icon: LucideIcons.stickyNote,
                            title: ctx.m('noNotes'),
                            sub: ctx.m('noNotesSub'),
                            action: Btn(ctx.m('newNote'), icon: LucideIcons.plus, onTap: ctx.readOnly ? null : _new),
                          ),
                  ),
                ),
              )
            else if (_view == 'grid')
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 240, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .82),
                  delegate: SliverChildBuilderDelegate((_, i) => NtNoteCard(ctx: ctx, row: rows[i], onTap: () => _open(rows[i]), onMenu: () => _menu(rows[i])), childCount: rows.length),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => NtNoteRow(ctx: ctx, row: rows[i], groups: _groups, onTap: () => _open(rows[i]), onMenu: () => _menu(rows[i])),
                ),
              ),
            if (_more)
              const SliverPadding(
                padding: EdgeInsets.only(bottom: 24),
                sliver: SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
              )
            else if (_moreFailed && rows != null)
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 24),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: TextButton.icon(
                      key: const ValueKey('nt-more-retry'),
                      onPressed: () {
                        setState(() => _moreFailed = false);
                        _load(next: true);
                      },
                      icon: const Icon(LucideIcons.refreshCw, size: 16),
                      label: Text(ctx.t('app.retry')),
                    ),
                  ),
                ),
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- one note (list row / grid card)
List<Widget> _dueChips(NtCtx ctx, Json row) {
  final d = obj(row['due']);
  return [
    if (n(d['overdue']) > 0) Chip2(ctx.m('dueOverdueN', {'n': n(d['overdue'])}), tone: Tone.danger, icon: LucideIcons.alarmClock),
    if (n(d['today']) > 0) Chip2(ctx.m('dueTodayN', {'n': n(d['today'])}), tone: Tone.warn),
    if (n(d['week']) > 0) Chip2(ctx.m('dueWeekN', {'n': n(d['week'])})),
  ];
}

class NtNoteRow extends StatelessWidget {
  final NtCtx ctx;
  final Json row;
  final Map<String, Json> groups;
  final VoidCallback onTap, onMenu;
  const NtNoteRow({super.key, required this.ctx, required this.row, this.groups = const {}, required this.onTap, required this.onMenu});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final share = obj(row['share']);
    final colour = str(row['color']);
    final gids = [for (final g in (row['group_ids'] as List? ?? const [])) '$g'].where(groups.containsKey).toList();
    final deleted = row['deleted'] == true;
    return Opacity(
      opacity: deleted ? .7 : 1,
      child: Material(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          onLongPress: onMenu,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border(left: BorderSide(color: colour == 'default' || colour.isEmpty ? c.lineStrong : ntAccent(colour), width: 4)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (row['pinned'] == true) ...[Icon(LucideIcons.pin, size: 14, color: c.brand), const SizedBox(width: 4)],
                          Expanded(
                            child: Text(
                              str(row['title']).isEmpty ? ctx.m('untitled') : str(row['title']),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                            ),
                          ),
                        ],
                      ),
                      if (str(row['preview']).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            str(row['preview']),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c.muted, fontSize: 13.5),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          NtLevelBadge(ctx: ctx, level: str(share['level']), pin: share['has_pin'] == true),
                          for (final g in gids.take(3)) NtGroupChip(groups[g]!),
                          if (gids.length > 3) Chip2('+${gids.length - 3}'),
                          ..._dueChips(ctx, row),
                          if (n(row['entry_count']) > 0) _Meta(LucideIcons.messageSquareText, fmt(n(row['entry_count']))),
                          if (n(row['files_count']) > 0) _Meta(LucideIcons.paperclip, fmt(n(row['files_count']))),
                          Text(ntAgo(row['updated_date'], ctx), style: TextStyle(color: c.muted, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onMenu,
                  icon: Icon(LucideIcons.ellipsisVertical, size: 18, color: c.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NtNoteCard extends StatelessWidget {
  final NtCtx ctx;
  final Json row;
  final VoidCallback onTap, onMenu;
  const NtNoteCard({super.key, required this.ctx, required this.row, required this.onTap, required this.onMenu});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final share = obj(row['share']);
    final colour = str(row['color']);
    return Material(
      color: ntPaper(context, colour),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        onLongPress: onMenu,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colour == 'default' || colour.isEmpty ? c.line : ntAccent(colour).withValues(alpha: .35)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      str(row['title']).isEmpty ? ctx.m('untitled') : str(row['title']),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, height: 1.3),
                    ),
                  ),
                  if (row['pinned'] == true) Padding(padding: const EdgeInsets.only(top: 2, left: 4), child: Icon(LucideIcons.pin, size: 14, color: c.brand)),
                  SizedBox(
                    width: 30,
                    height: 26,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: onMenu,
                      icon: Icon(LucideIcons.ellipsisVertical, size: 17, color: c.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  str(row['preview']).isEmpty ? ctx.m('emptyText') : str(row['preview']),
                  overflow: TextOverflow.fade,
                  style: TextStyle(color: c.muted, fontSize: 13, height: 1.45),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 4, runSpacing: 4, children: _dueChips(ctx, row).take(1).toList()),
              const SizedBox(height: 6),
              Row(
                children: [
                  NtLevelBadge(ctx: ctx, level: str(share['level']), pin: share['has_pin'] == true),
                  const Spacer(),
                  if (n(row['entry_count']) > 0) _Meta(LucideIcons.messageSquareText, fmt(n(row['entry_count']))),
                  const SizedBox(width: 8),
                ],
              ),
              const SizedBox(height: 4),
              Text(ntAgo(row['updated_date'], ctx), style: TextStyle(color: c.muted, fontSize: 11.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: context.c.muted),
      const SizedBox(width: 3),
      Text(text, style: TextStyle(color: context.c.muted, fontSize: 12, fontWeight: FontWeight.w600)),
    ],
  );
}
