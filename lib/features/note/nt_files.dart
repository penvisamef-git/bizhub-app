import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart' show netImage;
import 'nt_blocks.dart' show ntKindColour, ntKindIcon, ntOpenFile;
import 'nt_common.dart';

// Stored files as a list or a grid (the web's FileViews.jsx + note/files.jsx): the Media page (selectable, every
// file of the business) and a group's Files tab (the files of its notes). Rows are the API's media / group-file rows:
//   { _id, where: note|entry, note_id, note_title, note_deleted, entry_id, entry_name, name, kind, size, mime, url, at, by }

const ntFileKinds = ['all', 'image', 'video', 'audio', 'pdf', 'word', 'excel', 'slides', 'text', 'zip', 'sign', 'other'];

String ntFileKey(Json r) => '${str(r['where'])}:${str(r['entry_id']).isNotEmpty ? str(r['entry_id']) : str(r['note_id'])}:${str(r['_id'])}';

// a small picture Cloudinary makes on the fly: photos + signatures, a video's first second, a PDF's first page ("" = none)
String ntThumbOf(Json r, {int w = 360}) {
  final url = str(r['url']);
  final h = (w * .75).round();
  final cloud = RegExp(r'res\.cloudinary\.com/[^/]+/(image|video)/upload/').hasMatch(url);
  final kind = str(r['kind']);
  if (kind == 'image') return cloud ? url.replaceFirst('/image/upload/', '/image/upload/c_fill,w_$w,h_$h,q_auto,f_auto/') : url;
  if (kind == 'sign') return cloud ? url.replaceFirst('/image/upload/', '/image/upload/c_pad,b_white,w_$w,h_$h,q_auto,f_auto/') : url;
  if (!cloud) return '';
  if (kind == 'video' && url.contains('/video/upload/')) {
    return url.replaceFirst('/video/upload/', '/video/upload/so_1,c_fill,w_$w,h_$h,q_auto/').replaceFirst(RegExp(r'\.[a-z0-9]+(\?.*)?$', caseSensitive: false), '.jpg');
  }
  if (kind == 'pdf' && url.contains('/image/upload/')) {
    return url.replaceFirst('/image/upload/', '/image/upload/pg_1,c_fill,g_north,w_$w,h_$h,q_auto/').replaceFirst(RegExp(r'\.pdf(\?.*)?$', caseSensitive: false), '.jpg');
  }
  return '';
}

// the picture, or the coloured type icon (also when the picture can't load)
class NtFileThumb extends StatelessWidget {
  final Json row;
  final double size;
  final bool big;
  const NtFileThumb(this.row, {super.key, this.size = 44, this.big = false});
  @override
  Widget build(BuildContext context) {
    final kind = str(row['kind']);
    final col = ntKindColour(kind);
    final src = ntThumbOf(row, w: big ? 480 : 120);
    final icon = Center(
      child: Icon(ntKindIcon(kind), color: col, size: big ? 34 : 20),
    );
    return Container(
      width: big ? double.infinity : size,
      height: big ? double.infinity : size,
      decoration: BoxDecoration(color: col.withValues(alpha: .12), borderRadius: BorderRadius.circular(big ? 0 : 12)),
      clipBehavior: Clip.antiAlias,
      child: src.isEmpty ? icon : Image(image: netImage(src), fit: BoxFit.cover, errorBuilder: (_, _, _) => icon),
    );
  }
}

// open / download one row (a reply's file through its entry)
Future<void> ntOpenRow(NtCtx ctx, Json r, {bool inline = true}) {
  final f = {'_id': r['_id'], 'name': r['name'], 'url': r['url']};
  return str(r['where']) == 'entry' ? ntOpenFile(ctx, f, eid: str(r['entry_id']), inline: inline) : ntOpenFile(ctx, f, nid: str(r['note_id']), inline: inline);
}

// type chips with counts: All · Photos 12 · PDF 3 … (only the types that have files)
class NtKindChips extends StatelessWidget {
  final NtCtx ctx;
  final Json kinds; // { image: { count, bytes }, … }
  final num total;
  final String value;
  final ValueChanged<String> onChanged;
  const NtKindChips({super.key, required this.ctx, required this.kinds, required this.total, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final keys = ntFileKinds.where((k) => k == 'all' || n(obj(kinds[k])['count']) > 0 || k == value).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final k in keys)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: k == value ? c.solid : c.card,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  key: ValueKey('kind-$k'),
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => onChanged(k),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: k == value ? c.solid : c.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(k == 'all' ? LucideIcons.layoutGrid : ntKindIcon(k), size: 14, color: k == value ? c.onSolid : (k == 'all' ? c.muted : ntKindColour(k))),
                        const SizedBox(width: 6),
                        Text(
                          ctx.m('mediaKinds.$k'),
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: k == value ? c.onSolid : c.ink),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          fmt(k == 'all' ? total : n(obj(kinds[k])['count'])),
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: k == value ? c.onSolid.withValues(alpha: .75) : c.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// "In: Room rules" (a reply's file: "Reply by Sokha")
String _whoOf(NtCtx ctx, Json r) => str(r['where']) == 'entry' ? ctx.m('mediaReplyBy', {'name': str(r['entry_name']).isEmpty ? ctx.m('guest') : str(r['entry_name'])}) : ctx.m('mediaByOwner');

// one file as a list row
class NtFileRow extends StatelessWidget {
  final NtCtx ctx;
  final Json row;
  final bool selectable, picked;
  final VoidCallback? onPick;
  final VoidCallback? onOpenNote;
  const NtFileRow({super.key, required this.ctx, required this.row, this.selectable = false, this.picked = false, this.onPick, this.onOpenNote});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final kind = str(row['kind']);
    final deleted = row['note_deleted'] == true;
    return Material(
      color: picked ? c.active : c.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: selectable ? onPick : () => ntOpenRow(ctx, row),
        onLongPress: selectable ? null : onPick,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
          child: Row(
            children: [
              if (selectable) ...[_Check(on: picked), const SizedBox(width: 10)],
              NtFileThumb(row),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      str(row['name']).isEmpty ? ctx.m('mediaKinds.$kind') : str(row['name']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ctx.m('mediaKinds.$kind')} · ${_whoOf(ctx, row)} · ${ntTime(row['at'], ctx.lang)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: deleted || onOpenNote == null ? null : onOpenNote,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: '${ctx.m('mediaIn')}: '),
                            TextSpan(
                              text: str(row['note_title']).isEmpty ? ctx.m('untitled') : str(row['note_title']),
                              style: TextStyle(color: deleted ? c.muted : c.brandInk, fontWeight: FontWeight.w700, decoration: deleted ? TextDecoration.lineThrough : null),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.muted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(ntBytes(row['size']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
              IconButton(
                tooltip: ctx.m('download'),
                onPressed: () => ntOpenRow(ctx, row, inline: false),
                icon: Icon(LucideIcons.download, size: 18, color: c.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// one file as a grid card (a big picture or type icon, the type label, name, size, the note)
class NtFileCard extends StatelessWidget {
  final NtCtx ctx;
  final Json row;
  final bool selectable, picked;
  final VoidCallback? onPick;
  final VoidCallback? onOpenNote;
  const NtFileCard({super.key, required this.ctx, required this.row, this.selectable = false, this.picked = false, this.onPick, this.onOpenNote});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final kind = str(row['kind']);
    final col = ntKindColour(kind);
    final deleted = row['note_deleted'] == true;
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: selectable ? onPick : () => ntOpenRow(ctx, row),
        onLongPress: selectable ? null : onPick,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: picked ? c.brand : c.line, width: picked ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NtFileThumb(row, big: true),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: Color.alphaBlend(Colors.black.withValues(alpha: .15), col), borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          ctx.m('mediaKinds.$kind'),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    if (selectable)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: _Check(on: picked, light: true),
                      ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Material(
                        color: Colors.white.withValues(alpha: .92),
                        shape: const CircleBorder(),
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: ctx.m('download'),
                          onPressed: () => ntOpenRow(ctx, row, inline: false),
                          icon: const Icon(LucideIcons.download, size: 16, color: Color(0xFF16171B)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      str(row['name']).isEmpty ? ctx.m('mediaKinds.$kind') : str(row['name']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      '${ntBytes(row['size'])} · ${ntDate(row['at'], ctx.lang)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.muted, fontSize: 11.5),
                    ),
                    GestureDetector(
                      onTap: deleted || onOpenNote == null ? null : onOpenNote,
                      child: Text(
                        '${ctx.m('mediaIn')}: ${str(row['note_title']).isEmpty ? ctx.m('untitled') : str(row['note_title'])}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: deleted ? c.muted : c.brandInk, fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  final bool on, light;
  const _Check({required this.on, this.light = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: on ? c.brand : (light ? Colors.white.withValues(alpha: .9) : Colors.transparent),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: on ? c.brand : c.lineStrong, width: 2),
      ),
      child: on ? const Icon(LucideIcons.check, size: 15, color: Colors.white) : null,
    );
  }
}

// the rows as slivers: a list, or a grid (2 columns on a phone, more on a tablet)
List<Widget> ntFileSlivers(
  NtCtx ctx,
  List<Json> rows, {
  required String view,
  bool selectable = false,
  Set<String> picked = const {},
  void Function(Json r)? onPick,
  void Function(Json r)? onOpenNote,
  EdgeInsets padding = const EdgeInsets.fromLTRB(16, 0, 16, 12),
}) => [
  if (view == 'grid')
    SliverPadding(
      padding: padding,
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .84),
        delegate: SliverChildBuilderDelegate(
          (_, i) => NtFileCard(
            key: ValueKey(ntFileKey(rows[i])),
            ctx: ctx,
            row: rows[i],
            selectable: selectable,
            picked: picked.contains(ntFileKey(rows[i])),
            onPick: onPick == null ? null : () => onPick(rows[i]),
            onOpenNote: onOpenNote == null ? null : () => onOpenNote(rows[i]),
          ),
          childCount: rows.length,
        ),
      ),
    )
  else
    SliverPadding(
      padding: padding,
      sliver: SliverList.separated(
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => NtFileRow(
          key: ValueKey(ntFileKey(rows[i])),
          ctx: ctx,
          row: rows[i],
          selectable: selectable,
          picked: picked.contains(ntFileKey(rows[i])),
          onPick: onPick == null ? null : () => onPick(rows[i]),
          onOpenNote: onOpenNote == null ? null : () => onOpenNote(rows[i]),
        ),
      ),
    ),
];
