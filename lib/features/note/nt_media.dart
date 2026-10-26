import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'nt_blocks.dart' show ntKindColour;
import 'nt_common.dart';
import 'nt_editor.dart' show ntOpenNote;
import 'nt_files.dart';
import 'nt_more_ui.dart';
import 'nt_page.dart' show NtNav;

// Media (note_media, the web's NoteMedia.jsx): every photo, file and signature of the business — the biggest notes,
// search, sort, type chips, list / grid, select + delete many (with how much space it frees), download, open its note.
// Not unlocked: the storage meter, a blurred preview and the unlock card.

const _sorts = ['size', 'date', 'name'];

class MediaSection extends StatefulWidget {
  final NtCtx ctx;
  final NtNav nav;
  const MediaSection({super.key, required this.ctx, required this.nav});
  @override
  State<MediaSection> createState() => _MediaSectionState();
}

class _MediaSectionState extends State<MediaSection> {
  NtCtx get ctx => widget.ctx;
  final _q = TextEditingController();
  String _kind = 'all', _sort = 'size';
  late String _view = ntView('media');
  List<Json>? _rows;
  Json _totals = const {};
  bool _locked = false;
  int _page = 1, _pages = 1;
  bool _more = false;
  String _error = '';
  final Map<String, Json> _picked = {};
  int _ask = 0;
  Timer? _t;
  bool _deleting = false;
  bool _wasOwned = false;

  @override
  void initState() {
    super.initState();
    _wasOwned = ctx.media;
    _load();
  }

  @override
  void didUpdateWidget(MediaSection old) {
    super.didUpdateWidget(old);
    // just unlocked (the buy sheet reloaded the book): show the files
    if (ctx.media && !_wasOwned) {
      _wasOwned = true;
      _load();
    }
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
      final r = await ctx.a.media(sort: _sort, kind: _kind, q: _q.text.trim(), page: next ? _page + 1 : 1);
      if (!mounted || ask != _ask) return;
      setState(() {
        _locked = r['locked'] == true;
        _totals = obj(r['totals']);
        _rows = next ? [...?_rows, ...objs(r['data'])] : objs(r['data']);
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

  num get _selBytes => _picked.values.fold<num>(0, (a, r) => a + n(r['size']));

  // picking + deleting work after the plan ended too (the API allows it: free space up)
  void _toggle(Json r) {
    final k = ntFileKey(r);
    setState(() {
      if (_picked.containsKey(k)) {
        _picked.remove(k);
      } else if (_picked.length < 100) {
        _picked[k] = r;
      }
    });
  }

  bool get _allOn => (_rows ?? const <Json>[]).isNotEmpty && _rows!.every((r) => _picked.containsKey(ntFileKey(r)));

  void _pickAll() => setState(() {
    if (_allOn) {
      for (final r in _rows!) {
        _picked.remove(ntFileKey(r));
      }
    } else {
      for (final r in _rows!) {
        if (_picked.length < 100) _picked[ntFileKey(r)] = r;
      }
    }
  });

  Future<void> _delete() async {
    final count = _picked.length;
    final size = _selBytes;
    if (!await ntConfirm(context, ctx, ctx.m('mediaDeleteAsk', {'n': fmt(count)}), ctx.m('mediaDeleteSub', {'size': ntBytes(size)}), yes: ctx.m('mediaDelete', {'n': fmt(count)}))) return;
    setState(() => _deleting = true);
    final items = [
      for (final r in _picked.values)
        {
          'where': str(r['where']),
          'note_id': str(r['note_id']),
          if (str(r['entry_id']).isNotEmpty) 'entry_id': str(r['entry_id']),
          'file_id': str(r['_id']),
        },
    ];
    final res = await ctx.run(() => ctx.a.mediaDelete(items));
    if (!mounted) return;
    setState(() => _deleting = false);
    if (res == null) return;
    final out = obj(res['data']);
    final removed = (out['removed'] as List?)?.length ?? items.length;
    ctx.notify(ctx.m('mediaDeleted', {'n': fmt(removed), 'size': ntBytes(out['freed'] ?? size)}));
    setState(_picked.clear);
    ctx.reload();
    _load();
  }

  Future<void> _openNote(String nid) async {
    await ntOpenNote(context, ctx, nid);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final used = _totals['used'] ?? ctx.book['storage_used'];
    final limit = _totals['limit'] ?? ctx.book['storage_limit'];
    final kinds = obj(_totals['kinds']);
    final parts = <(Color, num)>[
      for (final k in ntFileKinds)
        if (k != 'all' && n(obj(kinds[k])['bytes']) > 0) (ntKindColour(k), n(obj(kinds[k])['bytes'])),
    ];
    final rows = _rows;
    final top = objs(_totals['top_notes']).take(5).toList();
    final topMax = top.isEmpty ? 1 : n(top.first['bytes']).clamp(1, double.infinity);

    final header = <Widget>[
      ntHead(context, LucideIcons.images, ctx.m('mediaHead'), ctx.m('mediaHeadSub')),
      ntGap,
      Panel(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NtStorageMeter(ctx: ctx, used: n(used), limit: n(limit), parts: parts, right: _totals['count'] == null ? null : ctx.m('mediaFiles', {'n': fmt(n(_totals['count']))})),
            if (parts.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  for (final k in ntFileKinds)
                    if (k != 'all' && n(obj(kinds[k])['bytes']) > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: ntKindColour(k), borderRadius: BorderRadius.circular(3)),
                          ),
                          const SizedBox(width: 5),
                          Text(ctx.m('mediaKinds.$k'), style: const TextStyle(fontSize: 12.5)),
                          const SizedBox(width: 4),
                          Text(ntBytes(obj(kinds[k])['bytes']), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                        ],
                      ),
                ],
              ),
            ],
          ],
        ),
      ),
      ntGap,
    ];

    if (_locked) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          ...header,
          _LockedPreview(ctx: ctx),
        ],
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            await Future.wait([_load(), ctx.reload()]);
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (s) {
              if (s.metrics.extentAfter < 300 && !_more && _page < _pages && rows != null) _load(next: true);
              return false;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  sliver: SliverList.list(
                    children: [
                      ...header,
                      if (top.isNotEmpty) ...[
                        Panel(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(ctx.m('mediaBiggest'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              const SizedBox(height: 8),
                              for (final t in top)
                                InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: t['note_deleted'] == true ? null : () => _openNote(str(t['note_id'])),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                str(t['note_title']).isEmpty ? ctx.m('untitled') : str(t['note_title']),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: t['note_deleted'] == true ? c.muted : c.ink),
                                              ),
                                            ),
                                            Text(ctx.m('mediaFiles', {'n': fmt(n(t['count']))}), style: TextStyle(color: c.muted, fontSize: 12)),
                                            const SizedBox(width: 10),
                                            Text(ntBytes(t['bytes']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(99),
                                          child: LinearProgressIndicator(
                                            value: (n(t['bytes']) / topMax).clamp(.03, 1).toDouble(),
                                            minHeight: 6,
                                            backgroundColor: c.bg2,
                                            color: c.brand,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        ntGap,
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Field(
                              controller: _q,
                              hint: ctx.m('mediaSearch'),
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
                          PopupMenuButton<String>(
                            tooltip: ctx.m('mediaSort.$_sort'),
                            initialValue: _sort,
                            onSelected: (v) {
                              setState(() => _sort = v);
                              _load();
                            },
                            itemBuilder: (_) => [for (final k in _sorts) PopupMenuItem(value: k, child: Text(ctx.m('mediaSort.$k')))],
                            icon: Icon(LucideIcons.arrowUpDown, size: 19, color: c.muted),
                          ),
                          NtViewSwitch(
                            ctx: ctx,
                            value: _view,
                            onChanged: (v) {
                              ntSetView('media', v);
                              setState(() => _view = v);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      NtKindChips(
                        ctx: ctx,
                        kinds: kinds,
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
                      const SizedBox(height: 10),
                      if (rows != null && rows.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: _pickAll,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Icon(_allOn ? LucideIcons.squareCheck : LucideIcons.square, size: 20, color: _allOn ? c.brand : c.muted),
                                  const SizedBox(width: 8),
                                  Text(ctx.m('mediaSelectAll'), style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (rows == null && _error.isEmpty) const SkelList(rows: 4),
                      if (rows == null && _error.isNotEmpty) LoadError(text: _error, retry: ctx.m('retry'), onRetry: _load),
                      if (rows != null && rows.isEmpty)
                        Panel(
                          child: NtEmpty(icon: LucideIcons.images, title: _q.text.isNotEmpty || _kind != 'all' ? ctx.m('mediaNoMatch') : ctx.m('mediaNone')),
                        ),
                    ],
                  ),
                ),
                if (rows != null && rows.isNotEmpty)
                  ...ntFileSlivers(ctx, rows, view: _view, selectable: true, picked: _picked.keys.toSet(), onPick: _toggle, onOpenNote: (r) => _openNote(str(r['note_id']))),
                if (_more) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))),
                SliverPadding(padding: EdgeInsets.only(bottom: _picked.isEmpty ? 32 : 110)),
              ],
            ),
          ),
        ),
        // the bulk bar
        if (_picked.isNotEmpty)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: c.line),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          ctx.m('mediaSelected', {'n': fmt(_picked.length), 'size': ntBytes(_selBytes)}),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                      ),
                      TextButton(onPressed: _deleting ? null : () => setState(_picked.clear), child: Text(ctx.m('mediaClear'))),
                      const SizedBox(width: 4),
                      Btn(ctx.m('mediaDelete', {'n': fmt(_picked.length)}), icon: LucideIcons.trash2, kind: BtnKind.danger, small: true, busy: _deleting, onTap: _deleting ? null : _delete),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// not unlocked: grey rows behind a lock card
class _LockedPreview extends StatelessWidget {
  final NtCtx ctx;
  const _LockedPreview({required this.ctx});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget ghost(double w) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 11,
                  width: w,
                  decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(6)),
                ),
                const SizedBox(height: 7),
                Container(
                  height: 9,
                  width: w * .6,
                  decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(6)),
                ),
              ],
            ),
          ),
          Container(
            height: 11,
            width: 44,
            decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(6)),
          ),
        ],
      ),
    );
    return Panel(
      key: const ValueKey('nt-media-locked'),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Opacity(
            opacity: .7,
            child: Column(children: [ghost(170), ghost(120), ghost(200)]),
          ),
          const SizedBox(height: 8),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: const Color(0xFFFFC53D).withValues(alpha: .2), shape: BoxShape.circle),
            child: const Icon(LucideIcons.lock, color: Color(0xFFB7791F)),
          ),
          const SizedBox(height: 12),
          Text(
            ctx.m('mediaLockedTitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 6),
          Muted(ctx.m('mediaLockedSub'), align: TextAlign.center),
          const SizedBox(height: 10),
          for (final p in ctx.l('mediaPerks'))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.check, size: 16, color: c.good),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p, style: const TextStyle(height: 1.4))),
                ],
              ),
            ),
          const SizedBox(height: 14),
          NtGoldBtn(ctx.m('mediaUnlock', {'coins': fmt(ctx.price('note_media'))}), onTap: ctx.readOnly ? null : () => ctx.askBuy('note_media')),
        ],
      ),
    );
  }
}
