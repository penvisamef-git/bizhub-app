import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'nt_common.dart';
import 'nt_data.dart';

// Note blocks — the model, the registry of block types and the read-only renderers (the web's note/blocks.jsx).
// A block = { id, t, text, done, file_id, style?, icon?, sticker?, due?, who? }.
//
// EXTENDING (phase 2 and later): register a block type with ntRegisterBlock(NtBlockKind(...)): its toolbar icon,
// whether it has text, which add-on it needs, and (optional) a read-only view and an editor row. The editor and the
// read-only view look types up here, so a new type needs no change in the editor itself.

class NtBlock {
  String id, t, text, fileId, icon, sticker, due, who;
  bool done;
  Json style;
  final Json rest; // fields this app doesn't know yet: kept as they are
  NtBlock({required this.id, this.t = 'p', this.text = '', this.done = false, this.fileId = '', Json? style, this.icon = '', this.sticker = '', this.due = '', this.who = '', Json? rest})
    : style = style ?? {},
      rest = rest ?? {};

  static const _known = {'id', 't', 'text', 'done', 'file_id', 'style', 'icon', 'sticker', 'due', 'who'};

  factory NtBlock.fromJson(Json j) => NtBlock(
    id: str(j['id']).isEmpty ? ntRandom(8) : str(j['id']),
    t: str(j['t']).isEmpty ? 'p' : str(j['t']),
    text: str(j['text']),
    done: j['done'] == true,
    fileId: str(j['file_id']),
    style: obj(j['style']),
    icon: str(j['icon']),
    sticker: str(j['sticker']),
    due: str(j['due']),
    who: str(j['who']),
    rest: {
      for (final e in j.entries)
        if (!_known.contains(e.key)) e.key: e.value,
    },
  );

  factory NtBlock.blank([String t = 'p']) => NtBlock(id: ntRandom(8), t: t);

  Json toJson() => {
    ...rest,
    'id': id,
    't': t,
    'text': text,
    'done': done,
    'file_id': fileId,
    if (style.isNotEmpty) 'style': style,
    if (icon.isNotEmpty) 'icon': icon,
    if (sticker.isNotEmpty) 'sticker': sticker,
    if (due.isNotEmpty) 'due': due,
    if (who.isNotEmpty) 'who': who,
  };

  NtBlock copy() => NtBlock.fromJson(toJson());
  bool get isText => ntBlockKinds[t]?.textual ?? true;
}

List<NtBlock> ntBlocksOf(Object? v) {
  final list = objs(v).map(NtBlock.fromJson).toList();
  return list.isEmpty ? [NtBlock.blank()] : list;
}

List<Json> ntBlocksJson(List<NtBlock> list) => [for (final b in list) b.toJson()];

// what the blocks say (to compare two versions)
String ntContentKey(String title, List<NtBlock> blocks) => '$title\u0001${blocks.map((b) => '${b.t}|${b.text}|${b.done}|${b.fileId}|${b.style}|${b.icon}|${b.sticker}|${b.due}|${b.who}').join('\u0002')}';

// ---------------------------------------------------------------- the registry
class NtBlockView {
  final BuildContext context;
  final NtCtx ctx;
  final NtBlock block;
  final List<Json> files;
  final int index;
  final String nid; // the note (file downloads)
  const NtBlockView(this.context, this.ctx, this.block, this.files, this.index, {this.nid = ''});
  Json? get file => files.where((f) => str(f['_id']) == block.fileId).firstOrNull;
}

class NtBlockKind {
  final String type;
  final IconData icon;
  final String label; // a note.* text key
  final bool textual; // has a text field
  final bool inTypeBar; // shown in the "change type" bar
  final String? needs; // the add-on it needs to be added (note_style, note_sign, note_voice)
  final Widget Function(NtBlockView v)? view; // read-only look (null = the text look)
  const NtBlockKind({required this.type, required this.icon, required this.label, this.textual = true, this.inTypeBar = false, this.needs, this.view});
}

final ntBlockKinds = <String, NtBlockKind>{
  'p': const NtBlockKind(type: 'p', icon: LucideIcons.pilcrow, label: 'types.p', inTypeBar: true),
  'h': const NtBlockKind(type: 'h', icon: LucideIcons.heading, label: 'types.h', inTypeBar: true),
  'bullet': const NtBlockKind(type: 'bullet', icon: LucideIcons.list, label: 'types.bullet', inTypeBar: true),
  'check': const NtBlockKind(type: 'check', icon: LucideIcons.squareCheck, label: 'types.check', inTypeBar: true),
  'quote': const NtBlockKind(type: 'quote', icon: LucideIcons.quote, label: 'types.quote', inTypeBar: true),
  'file': NtBlockKind(type: 'file', icon: LucideIcons.paperclip, label: 'attach', textual: false, view: (v) => NtFileBlock(view: v)),
  'draw': NtBlockKind(type: 'draw', icon: LucideIcons.signature, label: 'drawBtn', textual: false, needs: 'note_sign', view: (v) => NtDrawBlock(view: v)),
  'audio': NtBlockKind(type: 'audio', icon: LucideIcons.mic, label: 'voiceBtn', textual: false, needs: 'note_voice', view: (v) => NtFileBlock(view: v)),
  'callout': NtBlockKind(type: 'callout', icon: LucideIcons.messageSquareWarning, label: 'stCallout', needs: 'note_style', view: (v) => NtCallout(view: v)),
  'divider': NtBlockKind(type: 'divider', icon: LucideIcons.minus, label: 'stDivider', textual: false, needs: 'note_style', view: (v) => const NtDivider()),
  'sticker': NtBlockKind(type: 'sticker', icon: LucideIcons.smilePlus, label: 'stSticker', textual: false, needs: 'note_style', view: (v) => NtStickerBlock(view: v)),
};

void ntRegisterBlock(NtBlockKind kind) => ntBlockKinds[kind.type] = kind;

// ---------------------------------------------------------------- the style pack look (web style.js / blocks.css)
const _textColour = <String, int>{'red': 0xFFC62F34, 'orange': 0xFFC4520A, 'amber': 0xFFA46800, 'green': 0xFF1F7A4C, 'teal': 0xFF0B7F72, 'blue': 0xFF1F5FD1, 'indigo': 0xFF4848C8, 'purple': 0xFF7A3FB0, 'pink': 0xFFB62D85, 'gray': 0xFF6B7080};
const _hlLight = <String, int>{'red': 0xFFFDE2E2, 'orange': 0xFFFFE7D4, 'amber': 0xFFFFF1C7, 'green': 0xFFDCF5E6, 'teal': 0xFFD4F4EF, 'blue': 0xFFDDE9FF, 'indigo': 0xFFE4E4FF, 'purple': 0xFFEFE2FB, 'pink': 0xFFFDE0F0, 'gray': 0xFFECEEF2};

Color? ntTextColour(BuildContext context, Json style) {
  final k = str(style['color']);
  if (!_textColour.containsKey(k)) return null;
  final dark = Theme.of(context).brightness == Brightness.dark;
  return dark ? Color(ntSwatch[k]!) : Color(_textColour[k]!);
}

Color? ntHighlight(BuildContext context, Object? bg) {
  final k = str(bg);
  if (!_hlLight.containsKey(k)) return null;
  final dark = Theme.of(context).brightness == Brightness.dark;
  return dark ? Color(ntSwatch[k]!).withValues(alpha: .22) : Color(_hlLight[k]!);
}

Color ntHighlightLine(Object? bg) => Color(ntSwatch[str(bg)] ?? ntSwatch['amber']!);

// font size of a block (heading bigger); the style pack's sm / lg / xl
double ntFontSize(NtBlock b, {double base = 15.5}) {
  final s = str(b.style['size']);
  if (b.t == 'h') {
    return switch (s) {
      'sm' => base * 1.1,
      'lg' => base * 1.6,
      'xl' => base * 2,
      _ => base * 1.32,
    };
  }
  return switch (s) {
    'sm' => base * .86,
    'lg' => base * 1.22,
    'xl' => base * 1.55,
    _ => base,
  };
}

TextStyle ntTextStyle(BuildContext context, NtBlock b, {double base = 15.5, Color? ink}) {
  final c = context.c;
  final col = ntTextColour(context, b.style) ?? (b.t == 'quote' ? c.muted : (ink ?? c.ink));
  return TextStyle(
    fontSize: ntFontSize(b, base: base),
    height: b.t == 'h' ? 1.3 : 1.55,
    fontWeight: b.style['bold'] == true || b.t == 'h' ? FontWeight.w800 : FontWeight.w400,
    fontStyle: b.style['italic'] == true || b.t == 'quote' ? FontStyle.italic : FontStyle.normal,
    color: b.t == 'check' && b.done ? col.withValues(alpha: .55) : col,
    decoration: b.t == 'check' && b.done ? TextDecoration.lineThrough : null,
    decorationColor: col.withValues(alpha: .55),
  );
}

TextAlign ntAlign(NtBlock b) => switch (str(b.style['align'])) {
  'center' => TextAlign.center,
  'right' => TextAlign.right,
  _ => TextAlign.left,
};

// ---------------------------------------------------------------- read-only note (the public look of the blocks)
class NtReadBlocks extends StatelessWidget {
  final NtCtx ctx;
  final List<NtBlock> blocks;
  final List<Json> files;
  final String nid;
  const NtReadBlocks({super.key, required this.ctx, required this.blocks, required this.files, this.nid = ''});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, b) in blocks.indexed)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: ntBlockView(NtBlockView(context, ctx, b, files, i, nid: nid)),
        ),
    ],
  );
}

Widget ntBlockView(NtBlockView v) {
  final kind = ntBlockKinds[v.block.t];
  if (kind?.view != null) return kind!.view!(v);
  return NtTextView(view: v);
}

class NtTextView extends StatelessWidget {
  final NtBlockView view;
  const NtTextView({super.key, required this.view});
  @override
  Widget build(BuildContext context) {
    final b = view.block;
    final c = context.c;
    final hl = ntHighlight(context, b.style['bg']);
    final text = Text(b.text.isEmpty ? ' ' : b.text, style: ntTextStyle(context, b), textAlign: ntAlign(b));
    Widget row = switch (b.t) {
      'bullet' => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: ntFontSize(b) * .62, right: 10, left: 4),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
            ),
          ),
          Expanded(child: text),
        ],
      ),
      'check' => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 10),
            child: NtCheckBox(on: b.done),
          ),
          Expanded(child: text),
        ],
      ),
      'quote' => Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: c.brand, width: 3)),
        ),
        child: text,
      ),
      _ => text,
    };
    if (hl != null) {
      row = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: hl, borderRadius: BorderRadius.circular(6)),
        child: row,
      );
    }
    return row;
  }
}

class NtCheckBox extends StatelessWidget {
  final bool on;
  final VoidCallback? onTap;
  const NtCheckBox({super.key, required this.on, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: on ? c.brand : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: on ? c.brand : c.lineStrong, width: 1.8),
      ),
      child: on ? const Icon(LucideIcons.check, size: 14, color: Colors.white) : null,
    );
    if (onTap == null) return box;
    return InkResponse(onTap: onTap, radius: 22, child: Padding(padding: const EdgeInsets.all(4), child: box));
  }
}

class NtCallout extends StatelessWidget {
  final NtBlockView view;
  final Widget? child; // the editor puts its text field here
  const NtCallout({super.key, required this.view, this.child});
  @override
  Widget build(BuildContext context) {
    final b = view.block;
    final bg = ntHighlight(context, b.style['bg'].toString().isEmpty || b.style['bg'] == null ? 'amber' : b.style['bg']) ?? ntHighlight(context, 'amber')!;
    final line = ntHighlightLine(b.style['bg'] ?? 'amber');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: line.withValues(alpha: .35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(b.icon.isEmpty ? '💡' : b.icon, style: TextStyle(fontSize: ntFontSize(b) * 1.2, height: 1.35)),
          const SizedBox(width: 10),
          Expanded(
            child: child ?? Text(b.text, style: ntTextStyle(context, b), textAlign: ntAlign(b)),
          ),
        ],
      ),
    );
  }
}

class NtDivider extends StatelessWidget {
  const NtDivider({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Divider(height: 1, thickness: 1.5, color: context.c.lineStrong),
  );
}

class NtStickerBlock extends StatelessWidget {
  final NtBlockView view;
  const NtStickerBlock({super.key, required this.view});
  @override
  Widget build(BuildContext context) {
    final b = view.block;
    final s = ntStickers[b.sticker];
    final size = switch (str(b.style['size'])) {
      'sm' => 56.0,
      'lg' => 150.0,
      _ => 96.0,
    };
    final align = switch (str(b.style['align'])) {
      'center' => Alignment.center,
      'right' => Alignment.centerRight,
      _ => Alignment.centerLeft,
    };
    return Align(
      alignment: align,
      child: s == null
          ? Icon(LucideIcons.smile, size: size * .6, color: context.c.muted)
          : Tooltip(
              message: s.name(view.ctx.km),
              child: SvgPicture.string(s.svg, width: size, height: size),
            ),
    );
  }
}

// a signature / drawing (a PNG in the note's files)
class NtDrawBlock extends StatelessWidget {
  final NtBlockView view;
  const NtDrawBlock({super.key, required this.view});
  @override
  Widget build(BuildContext context) {
    final f = view.file;
    final c = context.c;
    if (f == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 220),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: str(f['url']).isEmpty
            ? Padding(padding: const EdgeInsets.all(16), child: Icon(LucideIcons.signature, color: c.muted))
            : Image(
                image: netImage(str(f['url'])),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Padding(padding: const EdgeInsets.all(16), child: Icon(LucideIcons.signature, color: c.muted)),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------- files
const _kindIcons = <String, IconData>{
  'image': LucideIcons.image,
  'video': LucideIcons.video,
  'audio': LucideIcons.audioLines,
  'pdf': LucideIcons.fileText,
  'word': LucideIcons.fileType,
  'excel': LucideIcons.sheet,
  'slides': LucideIcons.presentation,
  'text': LucideIcons.fileText,
  'zip': LucideIcons.fileArchive,
  'sign': LucideIcons.signature,
  'doc': LucideIcons.fileType,
  'other': LucideIcons.file,
};
const _kindColours = <String, int>{'image': 0xFF0EA5E9, 'video': 0xFF7C3AED, 'audio': 0xFFDB2777, 'pdf': 0xFFDC2626, 'word': 0xFF2563EB, 'doc': 0xFF2563EB, 'excel': 0xFF16A34A, 'slides': 0xFFEA580C, 'text': 0xFF64748B, 'zip': 0xFFA16207, 'sign': 0xFF0F766E};

// the fine type of a file (the API's fineKind on read)
String ntFineKind(Json f) {
  if (f['sign'] == true) return 'sign';
  if (f['voice'] == true) return 'audio';
  final m = str(f['mime']).toLowerCase();
  final ext = str(f['name']).toLowerCase().split('.').last;
  if (m.startsWith('image/') || ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'heif', 'avif'].contains(ext)) return 'image';
  if (m.startsWith('audio/') || ['mp3', 'm4a', 'wav', 'ogg', 'aac', 'flac', 'opus', 'weba'].contains(ext)) return 'audio';
  if (m.startsWith('video/') || ['mp4', 'mov', 'webm', 'mkv', 'avi', 'm4v'].contains(ext)) return 'video';
  if (m == 'application/pdf' || ext == 'pdf') return 'pdf';
  if (['doc', 'docx', 'odt', 'rtf'].contains(ext) || m.contains('word')) return 'word';
  if (['xls', 'xlsx', 'ods', 'csv'].contains(ext) || m.contains('excel') || m.contains('spreadsheet')) return 'excel';
  if (['ppt', 'pptx', 'odp'].contains(ext) || m.contains('presentation') || m.contains('powerpoint')) return 'slides';
  if (['txt', 'md'].contains(ext) || m.startsWith('text/')) return 'text';
  if (['zip', 'rar', '7z'].contains(ext) || m.contains('zip')) return 'zip';
  return 'other';
}

IconData ntKindIcon(String kind) => _kindIcons[kind] ?? LucideIcons.file;
Color ntKindColour(String kind) => Color(_kindColours[kind] ?? 0xFF64748B);

// open a file: a short-lived signed link from the API (a PDF can't be opened by its own url)
Future<void> ntOpenFile(NtCtx ctx, Json f, {String nid = '', String eid = '', bool inline = true}) async {
  try {
    final r = eid.isNotEmpty ? await ctx.a.entryDownload(eid, str(f['_id']), inline: inline) : await ctx.a.download(nid, str(f['_id']), inline: inline);
    final url = str(obj(r['data'])['url']);
    if (url.isEmpty) return ctx.notify(ctx.m('downloadFail'));
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (e) {
    ctx.notify(e is ApiError && !e.network ? e.message : ctx.m('downloadFail'));
  }
}

class NtFileChip extends StatelessWidget {
  final NtCtx ctx;
  final Json file;
  final String nid, eid;
  final Widget? trailing;
  const NtFileChip({super.key, required this.ctx, required this.file, this.nid = '', this.eid = '', this.trailing});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final kind = ntFineKind(file);
    final col = ntKindColour(kind);
    final img = kind == 'image' || kind == 'sign';
    return Material(
      color: c.bg2,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => ntOpenFile(ctx, file, nid: nid, eid: eid),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: col.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)),
                clipBehavior: Clip.antiAlias,
                child: img && str(file['url']).isNotEmpty
                    ? Image(image: netImage(str(file['url'])), fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(ntKindIcon(kind), color: col, size: 20))
                    : Icon(ntKindIcon(kind), color: col, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      str(file['name']).isEmpty ? ctx.m('mediaKinds.$kind') : str(file['name']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(ntBytes(file['size']), style: TextStyle(color: c.muted, fontSize: 12)),
                  ],
                ),
              ),
              trailing ??
                  IconButton(
                    tooltip: ctx.m('download'),
                    onPressed: () => ntOpenFile(ctx, file, nid: nid, eid: eid, inline: false),
                    icon: Icon(LucideIcons.download, size: 18, color: c.muted),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

// a "file" block: a picture shows big, anything else as a file chip (audio until the player comes: a chip too)
class NtFileBlock extends StatelessWidget {
  final NtBlockView view;
  const NtFileBlock({super.key, required this.view});
  @override
  Widget build(BuildContext context) {
    final f = view.file;
    if (f == null) return const SizedBox.shrink();
    final kind = ntFineKind(f);
    final noteId = view.nid;
    if (kind == 'image') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => ntOpenFile(view.ctx, f, nid: noteId),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: Image(
                  image: netImage(str(f['url'])),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, _, _) => NtFileChip(ctx: view.ctx, file: f, nid: noteId),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(str(f['name']), style: TextStyle(color: context.c.muted, fontSize: 12)),
          ),
        ],
      );
    }
    return NtFileChip(ctx: view.ctx, file: f, nid: noteId);
  }
}
