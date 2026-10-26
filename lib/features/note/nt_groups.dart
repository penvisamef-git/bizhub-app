import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/providers.dart' show prefStr;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_kit.dart' show MSheet, showSheet;
import 'nt_common.dart';
import 'nt_editor.dart' show ntOpenNote;
import 'nt_files.dart';
import 'nt_groups_pick.dart';
import 'nt_more_ui.dart';
import 'nt_new.dart';
import 'nt_page.dart' show NtNav;
import 'nt_share.dart' show ntShareGroup;

// Groups (the web's NoteGroups.jsx): folders of notes sent together with one link.
//   the list: search, list / grid, deleted groups + restore, New group (paid: the note_group price, once per group)
//   a group's page: rename, picture (note_group_icon per group), delete, link + share, Notes (search, move up / down,
//   remove, add notes, New note here) · Files (every file of its notes) · Opened the group link + views per day

// set by the Look picker (editor extras): the page theme of a group. null = no Look button.
Future<Json?> Function(BuildContext context, NtCtx ctx, Json group)? ntGroupLookHook;

class GroupsSection extends StatefulWidget {
  final NtCtx ctx;
  final NtNav nav;
  const GroupsSection({super.key, required this.ctx, required this.nav});
  @override
  State<GroupsSection> createState() => _GroupsSectionState();
}

class _GroupsSectionState extends State<GroupsSection> {
  NtCtx get ctx => widget.ctx;
  final _q = TextEditingController();
  bool _deleted = false;
  List<Json>? _groups;
  String _error = '';
  late String _view = prefStr('note_view_groups') == 'list' ? 'list' : 'grid'; // grid unless the person picked list
  String _open = '';

  @override
  void initState() {
    super.initState();
    _open = str(widget.nav.args['group']);
    _load();
    if (widget.nav.args['new'] == '1') WidgetsBinding.instance.addPostFrameCallback((_) => _make());
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.a.groups(deleted: _deleted);
      if (!mounted) return;
      setState(() {
        _groups = objs(r['data']).where((g) => (g['deleted'] == true) == _deleted).toList();
        _error = '';
      });
    } catch (e) {
      if (mounted) setState(() => _error = ctx.errText(e));
    }
  }

  Future<void> _make() async {
    if (ctx.readOnly) return;
    final g = await ntCreateGroup(context, ctx);
    if (g == null || !mounted) return;
    await _load();
    if (mounted) setState(() => _open = str(g['_id']));
  }

  void _put(Json g) => setState(() => _groups = [for (final x in _groups ?? const <Json>[]) str(x['_id']) == str(g['_id']) ? {...x, ...g} : x]);

  Future<void> _restore(Json g) async {
    final r = await ctx.run(() => ctx.a.groupRestore(str(g['_id'])), ctx.m('groupRestored'));
    if (r == null) return;
    ctx.reload();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_open.isNotEmpty) {
      final g = (_groups ?? const <Json>[]).where((x) => str(x['_id']) == _open).firstOrNull;
      if (g == null && _groups == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 4));
      if (g == null) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Panel(
              child: NtEmpty(
                icon: LucideIcons.folderX,
                title: _error.isNotEmpty ? _error : ctx.m('loadFail'),
                action: Btn(ctx.m('allGroups'), icon: LucideIcons.arrowLeft, kind: BtnKind.ghost, onTap: () => setState(() => _open = '')),
              ),
            ),
          ],
        );
      }
      return GroupPage(
        key: ValueKey('group-$_open'),
        ctx: ctx,
        group: g,
        onBack: () => setState(() => _open = ''),
        onChanged: _put,
        onGone: () {
          ctx.reload();
          setState(() => _open = '');
          _load();
        },
      );
    }

    final c = context.c;
    final needle = _q.text.trim().toLowerCase();
    final list = (_groups ?? const <Json>[]).where((g) => needle.isEmpty || str(g['name']).toLowerCase().contains(needle)).toList();
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_load(), ctx.reload()]);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            sliver: SliverList.list(
              children: [
                ntHead(
                  context,
                  LucideIcons.folders,
                  ctx.m('groupsTitle'),
                  ctx.m('groupsSub'),
                  actions: [
                    if (!_deleted) Btn(ctx.m('newGroup'), icon: LucideIcons.folderPlus, small: true, onTap: ctx.readOnly ? null : _make),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CoinIcon(size: 13),
                        const SizedBox(width: 4),
                        Text(ctx.m('newGroupPrice', {'coins': fmt(ctx.price('note_group'))}), style: TextStyle(color: c.muted, fontSize: 12.5)),
                      ],
                    ),
                  ],
                ),
                ntGap,
                Row(
                  children: [
                    Expanded(
                      child: Field(
                        controller: _q,
                        hint: ctx.m('groupsSearch'),
                        icon: LucideIcons.search,
                        onChanged: (_) => setState(() {}),
                        suffix: _q.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () => setState(_q.clear),
                                icon: Icon(LucideIcons.x, size: 18, color: c.muted),
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    NtViewSwitch(
                      ctx: ctx,
                      value: _view,
                      onChanged: (v) {
                        ntSetView('groups', v);
                        setState(() => _view = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                NtChips<bool>(
                  value: _deleted,
                  onChanged: (v) {
                    setState(() {
                      _deleted = v;
                      _groups = null;
                    });
                    _load();
                  },
                  items: [(false, ctx.m('groupsTitle'), n(ctx.counts['groups']).toInt()), (true, ctx.m('showDeleted'), null)],
                ),
              ],
            ),
          ),
          if (_groups == null && _error.isEmpty)
            const SliverPadding(padding: EdgeInsets.symmetric(horizontal: 16), sliver: SliverToBoxAdapter(child: SkelList(rows: 4)))
          else if (_groups == null)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(child: LoadError(text: _error, retry: ctx.m('retry'), onRetry: _load)),
            )
          else if (_groups!.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Panel(
                  child: NtEmpty(
                    icon: LucideIcons.folders,
                    title: _deleted ? ctx.m('noDeleted') : ctx.m('noGroups'),
                    sub: _deleted ? '' : ctx.m('noGroupsSub'),
                    action: _deleted ? null : Btn(ctx.m('newGroup'), icon: LucideIcons.folderPlus, onTap: ctx.readOnly ? null : _make),
                  ),
                ),
              ),
            )
          else if (list.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(child: Muted(ctx.m('groupsNoMatch'), align: TextAlign.center)),
            )
          else if (_view == 'grid')
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .98),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => NtGroupCard(ctx: ctx, group: list[i], onOpen: _deleted ? null : () => setState(() => _open = str(list[i]['_id'])), onRestore: _deleted ? () => _restore(list[i]) : null),
                  childCount: list.length,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => NtGroupRow(ctx: ctx, group: list[i], onOpen: _deleted ? null : () => setState(() => _open = str(list[i]['_id'])), onRestore: _deleted ? () => _restore(list[i]) : null),
              ),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }
}

String _notesLine(NtCtx ctx, Json g) {
  final count = n(g['notes_count'] ?? (g['note_ids'] as List? ?? const []).length).toInt();
  return count == 1 ? ctx.m('groupNote') : ctx.m('groupNotes', {'n': fmt(count)});
}

// ---------------------------------------------------------------- a group in the list (row) / grid (card)
class NtGroupRow extends StatelessWidget {
  final NtCtx ctx;
  final Json group;
  final VoidCallback? onOpen, onRestore;
  const NtGroupRow({super.key, required this.ctx, required this.group, this.onOpen, this.onRestore});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final files = n(group['files_count']).toInt();
    final col = str(group['color']);
    return Opacity(
      opacity: onRestore != null ? .75 : 1,
      child: Material(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border(left: BorderSide(color: col == 'default' || col.isEmpty ? c.lineStrong : ntAccent(col), width: 4)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                NtGroupIcon(group, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        str(group['name']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(LucideIcons.stickyNote, size: 12, color: c.muted),
                          const SizedBox(width: 3),
                          Text(_notesLine(ctx, group), style: TextStyle(color: c.muted, fontSize: 12.5)),
                          if (files > 0) ...[
                            const SizedBox(width: 8),
                            Icon(LucideIcons.paperclip, size: 12, color: c.muted),
                            const SizedBox(width: 3),
                            Text(files == 1 ? ctx.m('fileCount') : ctx.m('filesCount', {'n': fmt(files)}), style: TextStyle(color: c.muted, fontSize: 12.5)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (onRestore != null)
                  Btn(ctx.m('restoreGroup'), icon: LucideIcons.rotateCcw, kind: BtnKind.ghost, small: true, onTap: ctx.readOnly ? null : onRestore)
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      NtLevelBadge(ctx: ctx, level: str(obj(group['share'])['level']), pin: obj(group['share'])['has_pin'] == true),
                      const SizedBox(height: 4),
                      Text(ntAgo(group['updated_date'], ctx), style: TextStyle(color: c.muted, fontSize: 11.5)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NtGroupCard extends StatelessWidget {
  final NtCtx ctx;
  final Json group;
  final VoidCallback? onOpen, onRestore;
  const NtGroupCard({super.key, required this.ctx, required this.group, this.onOpen, this.onRestore});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final col = str(group['color']);
    final files = n(group['files_count']).toInt();
    return Opacity(
      opacity: onRestore != null ? .75 : 1,
      child: Material(
        color: ntPaper(context, col),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: col == 'default' || col.isEmpty ? c.line : ntAccent(col).withValues(alpha: .35)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NtGroupIcon(group, size: 46),
                    const Spacer(),
                    if (onRestore == null) NtLevelBadge(ctx: ctx, level: str(obj(group['share'])['level']), pin: obj(group['share'])['has_pin'] == true),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Text(
                    str(group['name']),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, height: 1.3),
                  ),
                ),
                if (onRestore != null)
                  Btn(ctx.m('restoreGroup'), icon: LucideIcons.rotateCcw, kind: BtnKind.ghost, small: true, expand: true, onTap: ctx.readOnly ? null : onRestore)
                else ...[
                  Row(
                    children: [
                      Icon(LucideIcons.stickyNote, size: 12, color: c.muted),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(_notesLine(ctx, group), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12)),
                      ),
                      if (files > 0) ...[
                        const SizedBox(width: 8),
                        Icon(LucideIcons.paperclip, size: 12, color: c.muted),
                        const SizedBox(width: 2),
                        Text(fmt(files), style: TextStyle(color: c.muted, fontSize: 12)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(ntAgo(group['updated_date'], ctx), style: TextStyle(color: c.muted, fontSize: 11.5)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// every note of the business (pages of 30), for the group page and the "add notes" picker
Future<List<Json>> ntAllNotes(NtCtx ctx, {String q = ''}) async {
  final out = <Json>[];
  var page = 1, pages = 1;
  do {
    final r = await ctx.a.notes(q: q, page: page);
    out.addAll(objs(r['data']));
    pages = n(r['pages']).toInt().clamp(1, 40);
    page++;
  } while (page <= pages);
  return out;
}

// ---------------------------------------------------------------- one group's page
class GroupPage extends StatefulWidget {
  final NtCtx ctx;
  final Json group;
  final VoidCallback onBack, onGone;
  final ValueChanged<Json> onChanged;
  const GroupPage({super.key, required this.ctx, required this.group, required this.onBack, required this.onGone, required this.onChanged});
  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  NtCtx get ctx => widget.ctx;
  Json get g => widget.group;
  String get gid => str(g['_id']);
  List<String> get ids => [for (final x in (g['note_ids'] as List? ?? const [])) '$x'];
  List<Json>? _notes; // all notes of the business
  List<Json>? _seen;
  Json? _stats;
  String _part = 'notes'; // notes | files
  final _nq = TextEditingController();
  String _busy = '';
  String _pic = ''; // uploading | removing

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _loadSeen();
  }

  @override
  void dispose() {
    _nq.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    try {
      final all = await ntAllNotes(ctx);
      if (mounted) setState(() => _notes = all);
    } catch (_) {
      if (mounted) setState(() => _notes = const []);
    }
  }

  Future<void> _loadSeen() async {
    try {
      final r = await Future.wait([ctx.a.groupSeen(gid), ctx.a.groupStats(gid)]);
      if (!mounted) return;
      setState(() {
        _seen = objs(r[0]['data']);
        _stats = obj(r[1]['data']);
      });
    } catch (_) {
      if (mounted) setState(() => _seen = const []);
    }
  }

  Future<bool> _save(Json body, [String? ok]) async {
    final r = await ctx.run(() => ctx.a.updateGroup(gid, body), ok);
    if (r == null) return false;
    widget.onChanged({...body, ...obj(r['data'])});
    return true;
  }

  void _move(String nid, int d) {
    final list = [...ids];
    final i = list.indexOf(nid), j = i + d;
    if (i < 0 || j < 0 || j >= list.length) return;
    final tmp = list[i];
    list[i] = list[j];
    list[j] = tmp;
    widget.onChanged({'note_ids': list});
    _save({'note_ids': list});
  }

  Future<void> _drop(String nid) async {
    setState(() => _busy = nid);
    final r = await ctx.run(() => ctx.a.groupDrop(gid, nid));
    if (!mounted) return;
    setState(() => _busy = '');
    if (r != null) widget.onChanged({'note_ids': ids.where((x) => x != nid).toList(), ...obj(r['data'])});
  }

  Future<void> _rename() async {
    final name = await showSheet<String>(context, (_) => _RenameSheet(ctx: ctx, initial: str(g['name'])));
    if (name == null || name.isEmpty || name == str(g['name'])) return;
    await _save({'name': name}, ctx.m('groupSaved'));
  }

  Future<void> _delete() async {
    if (!await ntConfirm(context, ctx, ctx.m('deleteGroupAsk'), ctx.m('deleteGroupSub'), yes: ctx.m('deleteGroup'))) return;
    final r = await ctx.run(() => ctx.a.groupDelete(gid), ctx.m('groupDeleted'));
    if (r != null) widget.onGone();
  }

  bool get _iconOwned => ctx.groupIcons.contains(gid) || g['icon_unlocked'] == true;

  // a picture: unlock it once for this group (the note_group_icon price), then upload / change it for free
  Future<void> _picture() async {
    if (!_iconOwned) {
      final ok = await ctx.askBuy('note_group_icon', item: gid, extra: {'name': str(g['name'])});
      if (!ok || !mounted) return;
    }
    final pick = await ntPickPicture(context, ctx, maxSize: 512);
    if (pick == null || !mounted) return;
    final (bytes, name, mime) = pick;
    if (bytes.length > 2 * 1048576) return ctx.notify(ctx.m('pictureBad'));
    setState(() => _pic = 'uploading');
    final r = await ctx.run(() => ctx.a.groupIconUpload(gid, bytes, name, mime));
    if (!mounted) return;
    setState(() => _pic = '');
    if (r != null) {
      widget.onChanged(obj(r['data']));
      ctx.reload();
    }
  }

  Future<void> _dropPicture() async {
    setState(() => _pic = 'removing');
    final r = await ctx.run(() => ctx.a.groupIconDelete(gid));
    if (!mounted) return;
    setState(() => _pic = '');
    if (r != null) {
      widget.onChanged({'icon_image': '', ...obj(r['data'])});
      ctx.reload();
    }
  }

  Future<void> _share() async {
    final pinNotes = (_notes ?? const <Json>[]).where((x) => ids.contains(str(x['_id'])) && obj(x['share'])['has_pin'] == true).length;
    final saved = await ntShareGroup(context, ctx, g, pinNotes: pinNotes);
    if (saved == null) return;
    widget.onChanged(saved['share'] != null ? saved : {'share': {...obj(g['share']), ...saved}});
    ctx.reload();
  }

  Future<void> _addNotes() async {
    await showSheet<void>(
      context,
      (_) => _AddNotesSheet(
        ctx: ctx,
        group: g,
        ids: ids,
        onChanged: (list) => widget.onChanged({'note_ids': list}),
      ),
    );
    _loadNotes();
  }

  Future<void> _newNote() async {
    final made = await ntNewNote(context, ctx, preGroups: [gid]);
    if (made == null || !mounted) return;
    final (note, gids) = made;
    if (gids.contains(gid)) widget.onChanged({'note_ids': [...ids.where((x) => x != str(note['_id'])), str(note['_id'])]});
    await ntOpenNote(context, ctx, str(note['_id']), first: note, fromGroup: gid);
    if (mounted) {
      _loadNotes();
      ctx.reload();
    }
  }

  Future<void> _openNote(String nid) async {
    await ntOpenNote(context, ctx, nid, fromGroup: gid);
    if (mounted) _loadNotes();
  }

  Future<void> _look() async {
    final hook = ntGroupLookHook;
    if (hook == null) return;
    final saved = await hook(context, ctx, g);
    if (saved != null) widget.onChanged(saved);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final share = obj(g['share']);
    final shared = str(share['level']).isNotEmpty && str(share['level']) != 'off';
    final url = ntUrl(share['path']);
    final ro = ctx.readOnly;
    final byId = {for (final x in _notes ?? const <Json>[]) str(x['_id']): x};
    final list = [for (final id in ids) ?byId[id]];
    final needle = _nq.text.trim().toLowerCase();
    final shown = needle.isEmpty ? list : list.where((x) => '${str(x['title'])} ${str(x['preview'])}'.toLowerCase().contains(needle)).toList();
    final files = n(g['files_count']).toInt();
    final hasPic = str(g['icon_image']).isNotEmpty;

    final top = <Widget>[
      // back + look + share
      Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(LucideIcons.arrowLeft, size: 17),
                label: Text(ctx.m('allGroups'), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          if (shared) RoundBtn(LucideIcons.externalLink, size: 40, tip: ctx.m('open'), onTap: () => ntLaunch(ctx, url)),
          if (ntGroupLookHook != null) ...[const SizedBox(width: 6), RoundBtn(LucideIcons.palette, size: 40, tip: ctx.m('lookBtn'), onTap: ro ? null : _look)],
          const SizedBox(width: 8),
          Btn(ctx.m('shareGroup'), icon: LucideIcons.share2, small: true, onTap: _share),
        ],
      ),
      const SizedBox(height: 8),
      // the group card
      Panel(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: ro || _pic.isNotEmpty ? null : _picture,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _pic == 'uploading'
                          ? Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(20)),
                              child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))),
                            )
                          : NtGroupIcon(g, size: 64),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _iconOwned ? c.brand : const Color(0xFFE0A21A),
                            shape: BoxShape.circle,
                            border: Border.all(color: c.card, width: 2),
                          ),
                          child: Icon(_iconOwned ? LucideIcons.imagePlus : LucideIcons.lock, size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(str(g['name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19, height: 1.25)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          NtLevelBadge(ctx: ctx, level: str(share['level']), pin: share['has_pin'] == true),
                          Text(_notesLine(ctx, {...g, 'notes_count': ids.length}), style: TextStyle(color: c.muted, fontSize: 12.5)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Btn(ctx.m('rename'), icon: LucideIcons.penLine, kind: BtnKind.ghost, small: true, onTap: ro ? null : _rename),
                if (_iconOwned)
                  Btn(hasPic ? ctx.m('changePicture') : ctx.m('addPicture'), icon: LucideIcons.imagePlus, kind: BtnKind.ghost, small: true, busy: _pic == 'uploading', onTap: ro || _pic.isNotEmpty ? null : _picture)
                else
                  NtGoldBtn(ctx.m('addPictureFor', {'coins': fmt(ctx.price('note_group_icon'))}), onTap: ro || _pic.isNotEmpty ? null : _picture),
                if (hasPic) Btn(ctx.m('removePicture'), icon: LucideIcons.x, kind: BtnKind.ghost, small: true, busy: _pic == 'removing', onTap: ro || _pic.isNotEmpty ? null : _dropPicture),
                Btn(ctx.m('deleteGroup'), icon: LucideIcons.trash2, kind: BtnKind.danger, small: true, onTap: _delete),
              ],
            ),
            if (shared) ...[
              const SizedBox(height: 14),
              _LinkLine(ctx: ctx, url: url),
            ],
          ],
        ),
      ),
      ntGap,
      // Notes · Files
      Panel(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: NtChips<String>(
                    value: _part,
                    onChanged: (v) => setState(() => _part = v),
                    items: [('notes', ctx.m('groupTabNotes'), ids.length), ('files', ctx.m('groupTabFiles'), files)],
                  ),
                ),
              ],
            ),
            if (_part == 'notes') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: Btn(ctx.m('newNoteHere'), icon: LucideIcons.penLine, kind: BtnKind.ghost, small: true, onTap: ro ? null : _newNote)),
                  const SizedBox(width: 8),
                  Expanded(child: Btn(ctx.m('addNotes'), icon: LucideIcons.plus, small: true, onTap: ro ? null : _addNotes)),
                ],
              ),
              if (ids.isNotEmpty) ...[
                const SizedBox(height: 10),
                Field(
                  controller: _nq,
                  hint: ctx.m('groupNotesSearch'),
                  icon: LucideIcons.search,
                  onChanged: (_) => setState(() {}),
                  suffix: _nq.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => setState(_nq.clear),
                          icon: Icon(LucideIcons.x, size: 18, color: c.muted),
                        ),
                ),
              ],
              const SizedBox(height: 8),
              if (_notes == null && ids.isNotEmpty)
                const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
              else if (list.isEmpty)
                Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Muted(ctx.m('groupNoNotes'), align: TextAlign.center))
              else if (shown.isEmpty)
                Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Muted(ctx.m('groupNotesNoMatch'), align: TextAlign.center))
              else
                for (final x in shown)
                  _GroupNoteRow(
                    ctx: ctx,
                    note: x,
                    index: list.indexOf(x),
                    count: list.length,
                    searching: needle.isNotEmpty,
                    busy: _busy == str(x['_id']),
                    onOpen: () => _openNote(str(x['_id'])),
                    onUp: ro ? null : () => _move(str(x['_id']), -1),
                    onDown: ro ? null : () => _move(str(x['_id']), 1),
                    onRemove: ro ? null : () => _drop(str(x['_id'])),
                  ),
            ],
          ],
        ),
      ),
    ];

    if (_part == 'files') {
      return GroupFilesView(key: ValueKey('gf-$gid'), ctx: ctx, group: g, header: top, noteCount: ids.length, onOpenNote: _openNote, tail: _tail());
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_loadNotes(), _loadSeen()]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [...top, ..._tail()],
      ),
    );
  }

  // views per day + who opened the group link
  List<Widget> _tail() {
    final c = context.c;
    return [
      ntGap,
      if (_stats != null) ...[NtDayBars(ctx: ctx, stats: _stats!, title: ctx.m('statsGroupTitle')), ntGap],
      Panel(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(LucideIcons.users, size: 18, color: c.brand),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(ctx.m('groupSeenTitle'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_seen == null)
              const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
            else if (_seen!.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Muted(ctx.m('groupSeenNone')))
            else
              for (final s in _seen!)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Avatar(name: str(s['name']).isEmpty ? ctx.m('guest') : str(s['name']), size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(str(s['name']).isEmpty ? ctx.m('guest') : str(s['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${ctx.m('firstSeen')}: ${ntTime(s['first_at'], ctx.lang)}', style: TextStyle(color: c.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(ntAgo(s['last_at'], ctx), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          Text(ctx.m('times', {'n': fmt(n(s['count']))}), style: TextStyle(color: c.muted, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    ];
  }
}

// the group link with Copy
class _LinkLine extends StatelessWidget {
  final NtCtx ctx;
  final String url;
  const _LinkLine({required this.ctx, required this.url});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(LucideIcons.link, size: 15, color: c.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              url.replaceFirst(RegExp(r'^https?://'), ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              ctx.notify(ctx.m('copied'));
            },
            icon: const Icon(LucideIcons.copy, size: 15),
            label: Text(ctx.m('copyLink')),
          ),
        ],
      ),
    );
  }
}

class _GroupNoteRow extends StatelessWidget {
  final NtCtx ctx;
  final Json note;
  final int index, count;
  final bool searching, busy;
  final VoidCallback onOpen;
  final VoidCallback? onUp, onDown, onRemove;
  const _GroupNoteRow({required this.ctx, required this.note, required this.index, required this.count, required this.searching, required this.busy, required this.onOpen, this.onUp, this.onDown, this.onRemove});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final col = str(note['color']);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: c.bg2,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onOpen,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border(left: BorderSide(color: col == 'default' || col.isEmpty ? c.lineStrong : ntAccent(col), width: 3)),
            ),
            padding: const EdgeInsets.fromLTRB(10, 8, 2, 8),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Text('${index + 1}', style: TextStyle(color: c.muted, fontWeight: FontWeight.w800, fontSize: 12.5)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        str(note['title']).isEmpty ? ctx.m('untitled') : str(note['title']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      if (str(note['preview']).isNotEmpty)
                        Text(
                          str(note['preview']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.muted, fontSize: 12.5),
                        ),
                    ],
                  ),
                ),
                if (!searching) ...[
                  _Mini(LucideIcons.arrowUp, ctx.m('moveUp'), index == 0 ? null : onUp),
                  _Mini(LucideIcons.arrowDown, ctx.m('moveDown'), index == count - 1 ? null : onDown),
                ],
                busy ? const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : _Mini(LucideIcons.x, ctx.m('removeFromGroup'), onRemove),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  final IconData icon;
  final String tip;
  final VoidCallback? onTap;
  const _Mini(this.icon, this.tip, this.onTap);
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tip,
    visualDensity: VisualDensity.compact,
    onPressed: onTap,
    icon: Icon(icon, size: 16, color: onTap == null ? context.c.lineStrong : context.c.muted),
  );
}

// ---------------------------------------------------------------- rename (a proper styled field)
class _RenameSheet extends StatefulWidget {
  final NtCtx ctx;
  final String initial;
  const _RenameSheet({required this.ctx, required this.initial});
  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  late final _v = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _v.dispose();
    super.dispose();
  }

  void _done() {
    final s = _v.text.trim();
    if (s.isEmpty) return;
    Navigator.pop(context, s.length > 80 ? s.substring(0, 80) : s);
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    return MSheet(
      title: ctx.m('renameTitle'),
      footer: [
        Expanded(
          child: Btn(ctx.m('cancel'), kind: BtnKind.ghost, onTap: () => Navigator.pop(context)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Btn(ctx.m('save'), onTap: _v.text.trim().isEmpty ? null : _done),
        ),
      ],
      children: [
        Field(label: ctx.m('groupName'), controller: _v, hint: ctx.m('groupNamePh'), maxLength: 80, autofocus: true, onChanged: (_) => setState(() {}), onSubmit: (_) => _done()),
      ],
    );
  }
}

// ---------------------------------------------------------------- add notes to the group (search; add / remove at once)
class _AddNotesSheet extends StatefulWidget {
  final NtCtx ctx;
  final Json group;
  final List<String> ids;
  final ValueChanged<List<String>> onChanged;
  const _AddNotesSheet({required this.ctx, required this.group, required this.ids, required this.onChanged});
  @override
  State<_AddNotesSheet> createState() => _AddNotesSheetState();
}

class _AddNotesSheetState extends State<_AddNotesSheet> {
  NtCtx get ctx => widget.ctx;
  late final List<String> _ids = [...widget.ids];
  final _q = TextEditingController();
  List<Json>? _rows;
  String _busy = '';
  Timer? _t;
  int _ask = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _t?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final ask = ++_ask;
    try {
      final r = await ntAllNotes(ctx, q: _q.text.trim());
      if (mounted && ask == _ask) setState(() => _rows = r);
    } catch (_) {
      if (mounted && ask == _ask) setState(() => _rows = const []);
    }
  }

  Future<void> _toggle(String nid) async {
    final gid = str(widget.group['_id']);
    final inside = _ids.contains(nid);
    setState(() => _busy = nid);
    final r = await ctx.run(() => inside ? ctx.a.groupDrop(gid, nid) : ctx.a.groupAdd(gid, nid));
    if (!mounted) return;
    setState(() {
      _busy = '';
      if (r != null) {
        _ids.remove(nid);
        if (!inside) _ids.add(nid);
      }
    });
    if (r != null) widget.onChanged([..._ids]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = _rows;
    return MSheet(
      title: ctx.m('addNotesTitle', {'name': str(widget.group['name'])}),
      footer: [Expanded(child: Btn(ctx.m('close'), icon: LucideIcons.check, onTap: () => Navigator.pop(context)))],
      children: [
        Field(
          controller: _q,
          hint: ctx.m('addNotesSearch'),
          icon: LucideIcons.search,
          onChanged: (_) {
            _t?.cancel();
            _t = Timer(const Duration(milliseconds: 300), _load);
          },
        ),
        const SizedBox(height: 10),
        if (rows == null)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (rows.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Muted(ctx.m('addNotesNone'), align: TextAlign.center))
        else
          for (final x in rows)
            () {
              final nid = str(x['_id']);
              final inside = _ids.contains(nid);
              final col = str(x['color']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: inside ? c.active : c.bg2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border(left: BorderSide(color: col == 'default' || col.isEmpty ? c.lineStrong : ntAccent(col), width: 3)),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              str(x['title']).isEmpty ? ctx.m('untitled') : str(x['title']),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            if (str(x['preview']).isNotEmpty)
                              Text(
                                str(x['preview']),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: c.muted, fontSize: 12.5),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Btn(
                        inside ? ctx.m('inGroup') : ctx.m('addThis'),
                        icon: inside ? LucideIcons.check : LucideIcons.plus,
                        kind: inside ? BtnKind.ghost : BtnKind.primary,
                        small: true,
                        busy: _busy == nid,
                        onTap: _busy.isNotEmpty ? null : () => _toggle(nid),
                      ),
                    ],
                  ),
                ),
              );
            }(),
      ],
    );
  }
}

// ---------------------------------------------------------------- a group's Files tab (free): every file of its notes
class GroupFilesView extends StatefulWidget {
  final NtCtx ctx;
  final Json group;
  final List<Widget> header, tail;
  final int noteCount;
  final void Function(String nid) onOpenNote;
  const GroupFilesView({super.key, required this.ctx, required this.group, required this.header, required this.tail, required this.noteCount, required this.onOpenNote});
  @override
  State<GroupFilesView> createState() => _GroupFilesViewState();
}

class _GroupFilesViewState extends State<GroupFilesView> {
  NtCtx get ctx => widget.ctx;
  final _q = TextEditingController();
  String _kind = 'all';
  late String _view = prefStr('note_view_group-files') == 'list' ? 'list' : 'grid';
  List<Json>? _rows;
  Json _totals = const {};
  int _page = 1, _pages = 1;
  bool _more = false;
  String _error = '';
  int _ask = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _t?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _load({bool next = false}) async {
    final ask = ++_ask;
    if (next) setState(() => _more = true);
    try {
      final r = await ctx.a.groupFiles(str(widget.group['_id']), q: _q.text.trim(), kind: _kind, page: next ? _page + 1 : 1);
      if (!mounted || ask != _ask) return;
      setState(() {
        _rows = next ? [...?_rows, ...objs(r['data'])] : objs(r['data']);
        _totals = obj(r['totals']);
        _page = n(r['page']).toInt().clamp(1, 1000);
        _pages = n(r['pages']).toInt().clamp(1, 1000);
        _more = false;
        _error = '';
      });
    } catch (e) {
      if (mounted && ask == _ask) {
        setState(() {
          _more = false;
          _error = ctx.errText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = _rows;
    final empty = _totals.isNotEmpty && n(_totals['count']) == 0;
    return NotificationListener<ScrollNotification>(
      onNotification: (s) {
        if (s.metrics.extentAfter < 300 && !_more && _page < _pages && rows != null) _load(next: true);
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            sliver: SliverList.list(
              children: [
                ...widget.header,
                const SizedBox(height: 8),
                Muted(ctx.m('groupFilesSub')),
                const SizedBox(height: 10),
                if (!empty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Field(
                          controller: _q,
                          hint: ctx.m('groupFilesSearch'),
                          icon: LucideIcons.search,
                          onChanged: (_) {
                            setState(() {});
                            _t?.cancel();
                            _t = Timer(const Duration(milliseconds: 300), _load);
                          },
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
                          ntSetView('group-files', v);
                          setState(() => _view = v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_totals.isNotEmpty)
                    NtKindChips(
                      ctx: ctx,
                      kinds: obj(_totals['kinds']),
                      total: n(_totals['count']),
                      value: _kind,
                      onChanged: (k) {
                        setState(() {
                          _kind = k;
                          _rows = null;
                        });
                        _load();
                      },
                    ),
                  const SizedBox(height: 12),
                ],
                if (rows == null && _error.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                if (rows == null && _error.isNotEmpty) LoadError(text: _error, retry: ctx.m('retry'), onRetry: _load),
                if (empty) Panel(child: NtEmpty(icon: LucideIcons.paperclip, title: ctx.m('groupFilesNone'))),
                if (rows != null && rows.isEmpty && !empty) Padding(padding: const EdgeInsets.all(18), child: Muted(ctx.m('groupFilesNoMatch'), align: TextAlign.center)),
              ],
            ),
          ),
          if (rows != null && rows.isNotEmpty) ...ntFileSlivers(ctx, rows, view: _view, onOpenNote: (r) => widget.onOpenNote(str(r['note_id']))),
          if (_more) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList.list(children: widget.tail),
          ),
        ],
      ),
    );
  }
}
