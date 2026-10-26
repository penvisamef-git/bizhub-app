import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show mGap, mDate;
import '../mart/mart_kit.dart' show showSheet;
import 'qg_common.dart';
import 'qg_editor.dart';
import 'qr_art.dart';

// The QR codes: search, type, folders, the grid, new code, trash — QgCodes.jsx
class CodesTab extends StatefulWidget {
  final QgCtx ctx;
  const CodesTab({super.key, required this.ctx});
  @override
  State<CodesTab> createState() => _CodesTabState();
}

class _CodesTabState extends State<CodesTab> {
  QgCtx get ctx => widget.ctx;
  String _q = '', _type = '', _folder = '';
  Json? _editing; // a code, or {type} for a new one
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<bool> _confirm(String title, String sub) async =>
      await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(title),
          content: Text(sub),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: Text(ctx.m('cancel'))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: d.c.danger),
              onPressed: () => Navigator.pop(d, true),
              child: Text(ctx.m('delete')),
            ),
          ],
        ),
      ) ==
      true;

  void _setCodes(List<Json> Function(List<Json>) fn) => ctx.put((d) => {'codes': fn(objs(d['codes']))});

  Future<void> _folderBox([Json? row]) async {
    final ctl = TextEditingController(text: str(row?['name']));
    final name = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(row == null ? ctx.m('newFolder') : ctx.m('edit')),
        content: Field(label: ctx.m('folderName'), controller: ctl, maxLength: 60, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(ctx.m('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(d, ctl.text.trim()), child: Text(ctx.m('save'))),
        ],
      ),
    );
    ctl.dispose();
    if (name == null || name.isEmpty) return;
    if (row == null) {
      final r = await ctx.run(() => ctx.api.post('${ctx.base}/folders', {'name': name}));
      if (r != null) {
        ctx.put(
          (d) => {
            'folders': [...objs(d['folders']), obj(r['data'])],
          },
        );
      }
    } else {
      final r = await ctx.run(() => ctx.api.put('${ctx.base}/folders/${row['_id']}', {'name': name}));
      if (r != null) {
        ctx.put(
          (d) => {
            'folders': [for (final f in objs(d['folders'])) f['_id'] == row['_id'] ? obj(r['data']) : f],
          },
        );
      }
    }
  }

  Future<void> _pickType() async {
    final k = await showSheet<String>(
      context,
      (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(ctx.m('pickType'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            for (final k in typeOrder)
              () {
                final need = typeNeeds[k];
                final locked = need != null && !ctx.on(need);
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: sheet.c.active, borderRadius: BorderRadius.circular(12)),
                    child: Icon(qrTypeIcons[k], color: sheet.c.brand),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(ctx.m('types.$k'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      if (locked) ...[const SizedBox(width: 6), const CoinIcon(size: 12), const SizedBox(width: 2), Text(fmt(n(ctx.addon(need)['price'])), style: const TextStyle(fontSize: 12))],
                    ],
                  ),
                  subtitle: Text(ctx.m('typeWhat.$k'), maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(sheet, k),
                );
              }(),
          ],
        ),
      ),
    );
    if (k == null) return;
    final need = typeNeeds[k];
    if (need != null && !ctx.on(need)) return ctx.askBuy({'addon': need});
    setState(() => _editing = {'type': k});
  }

  @override
  Widget build(BuildContext context) {
    final editing = _editing;
    if (editing != null) {
      return CodeEditor(
        key: ValueKey(editing['_id'] ?? 'new'),
        ctx: ctx,
        start: editing,
        onClose: () => setState(() => _editing = null),
        onSaved: (row, isNew) {
          _setCodes((list) => isNew ? [row, ...list] : [for (final x in list) x['_id'] == row['_id'] ? row : x]);
        },
      );
    }
    final c = context.c;
    final codes = ctx.codes;
    final words = _q.trim().toLowerCase();
    final shown = codes.where((x) {
      if (words.isNotEmpty && !str(x['name']).toLowerCase().contains(words)) return false;
      if (_type.isNotEmpty && x['type'] != _type) return false;
      if (_folder == 'none') return x['folder_id'] == null;
      if (_folder.isNotEmpty) return x['folder_id'] == _folder;
      return true;
    }).toList();
    String? folderName(Object? id) => ctx.folders.where((f) => f['_id'] == id).firstOrNull?['name'] as String?;
    final trashN = n(ctx.counts['trash']).toInt();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        qgHead(
          context,
          LucideIcons.qrCode,
          ctx.m('codesTitle'),
          ctx.m('codesSub'),
          actions: [
            Btn(ctx.m('newCode'), icon: LucideIcons.plus, small: true, onTap: ctx.readOnly ? null : _pickType),
            Btn(
              '${ctx.m('trash')}${trashN > 0 ? ' ($trashN)' : ''}',
              icon: LucideIcons.trash2,
              kind: BtnKind.ghost,
              small: true,
              onTap: () => showSheet<void>(context, (_) => _Trash(ctx: ctx)),
            ),
          ],
        ),
        mGap,
        qgPanel([
          Row(
            children: [
              Expanded(
                child: Field(controller: _search, hint: ctx.m('search'), prefix: const Icon(LucideIcons.search, size: 16), onChanged: (v) => setState(() => _q = v)),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                tooltip: ctx.m('allTypes'),
                icon: Icon(LucideIcons.listFilter, color: _type.isEmpty ? c.muted : c.brand),
                onSelected: (v) => setState(() => _type = v),
                itemBuilder: (_) => [
                  CheckedPopupMenuItem(value: '', checked: _type.isEmpty, child: Text(ctx.m('allTypes'))),
                  for (final k in typeOrder) CheckedPopupMenuItem(value: k, checked: _type == k, child: Text(ctx.m('types.$k'))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (k, label, count) in [
                  ('', ctx.m('allFolders'), codes.length),
                  for (final f in ctx.folders) (str(f['_id']), str(f['name']), codes.where((x) => x['folder_id'] == f['_id']).length),
                  ('none', ctx.m('noFolder'), codes.where((x) => x['folder_id'] == null).length),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(label: Text('$label $count'), selected: _folder == k, onSelected: (_) => setState(() => _folder = k)),
                  ),
                ActionChip(avatar: const Icon(LucideIcons.folderPlus, size: 15), label: Text(ctx.m('newFolder')), onPressed: ctx.readOnly ? null : () => _folderBox()),
              ],
            ),
          ),
          if (_folder.isNotEmpty && _folder != 'none' && !ctx.readOnly) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Btn(ctx.m('edit'), icon: LucideIcons.pencil, kind: BtnKind.ghost, small: true, onTap: () => _folderBox(ctx.folders.where((f) => f['_id'] == _folder).firstOrNull)),
                const SizedBox(width: 8),
                Btn(
                  ctx.m('removeFolder'),
                  icon: LucideIcons.trash2,
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: () async {
                    final f = ctx.folders.where((x) => x['_id'] == _folder).firstOrNull;
                    if (f == null || !await _confirm(ctx.m('removeFolder'), '${f['name']} — ${ctx.m('removeFolderSub')}')) return;
                    if (await ctx.run(() => ctx.api.delete('${ctx.base}/folders/${f['_id']}')) != null) {
                      ctx.put(
                        (d) => {
                          'folders': objs(d['folders']).where((x) => x['_id'] != f['_id']).toList(),
                          'codes': [
                            for (final x in objs(d['codes'])) x['folder_id'] == f['_id'] ? {...x, 'folder_id': null} : x,
                          ],
                        },
                      );
                      setState(() => _folder = '');
                    }
                  },
                ),
              ],
            ),
          ],
        ]),
        mGap,
        if (codes.isEmpty)
          qgPanel([
            Icon(LucideIcons.qrCode, size: 34, color: c.muted),
            const SizedBox(height: 8),
            Muted(ctx.m('noCodes'), align: TextAlign.center),
            const SizedBox(height: 10),
            Center(
              child: Btn(ctx.m('newCode'), icon: LucideIcons.plus, onTap: ctx.readOnly ? null : _pickType),
            ),
          ])
        else
          LayoutBuilder(
            builder: (_, box) {
              final cols = box.maxWidth > 560 ? 3 : 2;
              final w = (box.maxWidth - 10 * (cols - 1)) / cols;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final x in shown)
                    SizedBox(
                      width: w,
                      child: Opacity(
                        opacity: x['active'] == false ? .6 : 1,
                        child: Panel(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () => setState(() => _editing = x),
                                child: Center(
                                  child: SizedBox(
                                    height: w - 30,
                                    child: FittedBox(
                                      child: QrView(code: x, logo: ctx.logo, size: 150, scanMe: ctx.scanMe),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                str(x['name']),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  _Tag(icon: qrTypeIcons[x['type']], text: ctx.m('types.${x['type']}')),
                                  if (!isStatic(x['type'])) _Tag(icon: LucideIcons.chartColumn, text: ctx.m('scans', {'n': fmt(n(x['scans']))})),
                                  if (x['type'] == 'form')
                                    _Tag(icon: LucideIcons.inbox, text: '${ctx.m('replies', {'n': fmt(n(x['replies']))})}${n(x['unread']) > 0 ? ' · ${n(x['unread'])}' : ''}', hot: n(x['unread']) > 0),
                                  if (x['has_password'] == true) const _Tag(icon: LucideIcons.lock, text: ''),
                                  if (x['active'] == false) _Tag(text: ctx.m('paused'), warn: true),
                                  if (folderName(x['folder_id']) != null) _Tag(icon: LucideIcons.folder, text: folderName(x['folder_id'])!),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 0,
                                children: [
                                  _Icon(LucideIcons.pencil, ctx.m('edit'), () => setState(() => _editing = x)),
                                  _Icon(
                                    LucideIcons.copyPlus,
                                    ctx.m('duplicate'),
                                    ctx.readOnly
                                        ? null
                                        : () async {
                                            final r = await ctx.run(() => ctx.api.post('${ctx.base}/codes/${x['_id']}/copy'), ctx.m('duplicated'));
                                            if (r != null) _setCodes((l) => [obj(r['data']), ...l]);
                                          },
                                  ),
                                  _Icon(LucideIcons.share2, ctx.m('download'), () => shareCodePng(ctx, x)),
                                  if (!isStatic(x['type'])) ...[
                                    _Icon(LucideIcons.copy, ctx.m('copyLink'), () async {
                                      await Clipboard.setData(ClipboardData(text: codeUrl(x['slug'])));
                                      ctx.notify(ctx.m('copied'));
                                    }),
                                    _Icon(LucideIcons.externalLink, ctx.m('open'), () => launchUrl(Uri.parse(codeUrl(x['slug'])), mode: LaunchMode.externalApplication)),
                                  ],
                                  _Icon(
                                    LucideIcons.trash2,
                                    ctx.m('delete'),
                                    ctx.readOnly
                                        ? null
                                        : () async {
                                            if (!await _confirm(ctx.m('removeCode'), '${x['name']} — ${ctx.m('removeCodeSub')}')) return;
                                            final r = await ctx.run(() => ctx.api.delete('${ctx.base}/codes/${x['_id']}'));
                                            if (r != null) {
                                              ctx.put(
                                                (d) => {
                                                  'codes': objs(d['codes']).where((y) => y['_id'] != x['_id']).toList(),
                                                  if (r['files'] != null) 'files': r['files'],
                                                  'counts': {...obj(d['counts']), 'trash': n(obj(d['counts'])['trash']) + 1},
                                                },
                                              );
                                            }
                                          },
                                    danger: true,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData? icon;
  final String text;
  final bool hot, warn;
  const _Tag({this.icon, required this.text, this.hot = false, this.warn = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = hot
        ? c.brand
        : warn
        ? c.warn
        : c.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: hot
            ? c.active
            : warn
            ? c.warnBg
            : c.bg2,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 10, color: fg),
          if (icon != null && text.isNotEmpty) const SizedBox(width: 3),
          if (text.isNotEmpty)
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: fg, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class _Icon extends StatelessWidget {
  final IconData icon;
  final String tip;
  final VoidCallback? onTap;
  final bool danger;
  const _Icon(this.icon, this.tip, this.onTap, {this.danger = false});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tip,
    visualDensity: VisualDensity.compact,
    onPressed: onTap,
    icon: Icon(icon, size: 17, color: danger ? context.c.danger : null),
  );
}

// deleted QR codes (30 days): restore or delete for good
class _Trash extends StatefulWidget {
  final QgCtx ctx;
  const _Trash({required this.ctx});
  @override
  State<_Trash> createState() => _TrashState();
}

class _TrashState extends State<_Trash> {
  QgCtx get ctx => widget.ctx;
  Json? _res;
  String _busy = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/trash');
      if (mounted) setState(() => _res = r);
    } catch (e) {
      ctx.fail(e);
    }
  }

  void _sync(int left) => ctx.put(
    (d) => {
      'counts': {...obj(d['counts']), 'trash': left},
    },
  );

  Future<bool> _sure(String title, String sub) async =>
      await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(title),
          content: Text(sub),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: Text(ctx.m('cancel'))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: d.c.danger),
              onPressed: () => Navigator.pop(d, true),
              child: Text(ctx.m('delete')),
            ),
          ],
        ),
      ) ==
      true;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final res = _res;
    final rows = objs(res?['data']);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(ctx.m('trashTitle'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Muted(ctx.m('trashSub', {'days': n(res?['days'] ?? 30)})),
          const SizedBox(height: 12),
          if (res == null)
            const SkelList(rows: 2)
          else if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(LucideIcons.trash2, size: 28, color: c.muted),
                  const SizedBox(height: 6),
                  Muted(ctx.m('trashEmpty')),
                ],
              ),
            )
          else ...[
            for (final x in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: FittedBox(
                        child: QrView(code: x, logo: ctx.logo, size: 56),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(str(x['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                          Muted('${ctx.m('types.${x['type']}')} · ${ctx.m('deletedAgo', {'date': mDate(x['deleted_at'], ctx.lang)})}'),
                        ],
                      ),
                    ),
                    Btn(
                      ctx.m('restore'),
                      icon: LucideIcons.rotateCcw,
                      small: true,
                      busy: _busy == x['_id'],
                      onTap: ctx.readOnly || _busy.isNotEmpty
                          ? null
                          : () async {
                              setState(() => _busy = str(x['_id']));
                              final r = await ctx.run(() => ctx.api.post('${ctx.base}/codes/${x['_id']}/restore'), ctx.m('restored'));
                              if (r != null) {
                                ctx.put(
                                  (d) => {
                                    'codes': [obj(r['data']), ...objs(d['codes'])],
                                  },
                                );
                                setState(() => _res = {..._res!, 'data': rows.where((y) => y['_id'] != x['_id']).toList()});
                                _sync(rows.length - 1);
                              }
                              if (mounted) setState(() => _busy = '');
                            },
                    ),
                    IconButton(
                      tooltip: ctx.m('deleteForever'),
                      onPressed: ctx.readOnly || _busy.isNotEmpty
                          ? null
                          : () async {
                              if (!await _sure(ctx.m('deleteForever'), '${x['name']} — ${ctx.m('emptyTrashSub')}')) return;
                              final r = await ctx.run(() => ctx.api.delete('${ctx.base}/trash/${x['_id']}'));
                              if (r != null) {
                                final left = rows.where((y) => y['_id'] != x['_id']).toList();
                                setState(() => _res = {..._res!, 'data': left});
                                ctx.put(
                                  (d) => {
                                    if (r['files'] != null) 'files': r['files'],
                                    'counts': {...obj(d['counts']), 'trash': left.length},
                                  },
                                );
                              }
                            },
                      icon: Icon(LucideIcons.trash2, size: 18, color: c.danger),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Btn(
                ctx.m('emptyTrash'),
                icon: LucideIcons.trash2,
                kind: BtnKind.ghost,
                small: true,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        if (!await _sure(ctx.m('emptyTrash'), ctx.m('emptyTrashSub'))) return;
                        final r = await ctx.run(() => ctx.api.delete('${ctx.base}/trash'));
                        if (r != null) {
                          setState(() => _res = {..._res!, 'data': <Json>[]});
                          ctx.put(
                            (d) => {
                              if (r['files'] != null) 'files': r['files'],
                              'counts': {...obj(d['counts']), 'trash': 0},
                            },
                          );
                        }
                      },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
