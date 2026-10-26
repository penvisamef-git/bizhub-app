import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/providers.dart' show prefStr, prefSetStr;
import '../../core/theme.dart';
import '../mart/mart_kit.dart' show MSheet, showSheet;
import 'nt_blocks.dart';
import 'nt_common.dart';
import 'nt_data.dart';
import 'nt_editor.dart';
import 'nt_extras_text.dart';

// The style pack (note_style) in the app: a style sheet per line (colour, highlight, size, align, bold, italic), a box
// (callout) and a line (divider), stickers, the emoji picker and the note paper (the web's blocks.jsx StylePop / pickers).
// The server refuses only NEW styled content without the pack (403 need_style → the editor opens the unlock sheet).

// ---------------------------------------------------------------- the style of one line
Future<void> ntStyleSheet(NtEditorApi ed) async {
  final b = ed.currentBlock;
  final ctx = ed.ctx;
  if (b == null || (!b.isText && b.t != 'sticker')) {
    ctx.notify(ctx.m('stPickBlock'));
    return;
  }
  await showSheet<void>(ed.context, (_) => _StyleSheet(ed: ed, block: b));
}

class _StyleSheet extends StatefulWidget {
  final NtEditorApi ed;
  final NtBlock block;
  const _StyleSheet({required this.ed, required this.block});
  @override
  State<_StyleSheet> createState() => _StyleSheetState();
}

class _StyleSheetState extends State<_StyleSheet> {
  NtBlock get b => widget.block;
  NtCtx get ctx => widget.ed.ctx;

  void _set(String k, Object? v) {
    setState(() {
      // the API keeps only what is set (md size / left align are the defaults)
      if (v == null || v == false || (k == 'size' && v == 'md') || (k == 'align' && v == 'left')) {
        b.style.remove(k);
      } else {
        b.style[k] = v;
      }
    });
    widget.ed.rebuild();
    widget.ed.changed();
  }

  void _icon(String e) {
    setState(() => b.icon = e);
    widget.ed.rebuild();
    widget.ed.changed();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final sticker = b.t == 'sticker';
    final callout = b.t == 'callout';
    Widget label(String t) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(t, style: TextStyle(fontWeight: FontWeight.w800, color: c.muted, fontSize: 12.5)),
    );
    Widget swatches(String key, {required bool fill}) => Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _Swatch(on: b.style[key] == null, none: true, onTap: () => _set(key, null), tip: ctx.m('stNone')),
        for (final k in ntStyleColours)
          _Swatch(
            on: b.style[key] == k,
            color: fill ? (ntHighlight(context, k) ?? Colors.transparent) : Color(ntSwatch[k]!),
            ring: fill ? ntHighlightLine(k) : null,
            onTap: () => _set(key, k),
            tip: k,
          ),
      ],
    );
    final sizes = sticker ? const ['sm', 'md', 'lg'] : const ['sm', 'md', 'lg', 'xl'];
    final size = str(b.style['size']).isEmpty ? 'md' : str(b.style['size']);
    final align = str(b.style['align']).isEmpty ? 'left' : str(b.style['align']);
    return MSheet(
      title: ntE(ctx, 'styleOf'),
      footer: [
        Expanded(
          child: TextButton.icon(
            onPressed: () {
              setState(() => b.style.clear());
              widget.ed.rebuild();
              widget.ed.changed();
            },
            icon: const Icon(LucideIcons.eraser, size: 16),
            label: Text(ctx.m('stClear')),
          ),
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: Text(ctx.m('close'))),
      ],
      children: [
        // a live preview of the line
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
          child: sticker
              ? SizedBox(height: 90, child: ntBlockView(NtBlockView(context, ctx, b, const [], 0)))
              : ntBlockView(NtBlockView(context, ctx, b.text.isEmpty ? (b.copy()..text = ctx.l('stylePreview').first) : b, const [], 0)),
        ),
        if (!sticker) ...[
          if (callout) ...[
            label(ntE(ctx, 'calloutIcon')),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in const ['💡', '⚠️', '📌', '✅', '❗', '📣', '🔑', '⏰', '💬', '🎉', '📝', '❤️'])
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _icon(e),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: (b.icon.isEmpty ? '💡' : b.icon) == e ? c.active : c.bg2,
                        border: Border.all(color: (b.icon.isEmpty ? '💡' : b.icon) == e ? c.brand : Colors.transparent, width: 1.5),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
              ],
            ),
          ],
          label(ctx.m('stColor')),
          swatches('color', fill: false),
          label(ctx.m('stHighlight')),
          swatches('bg', fill: true),
        ],
        label(sticker ? ntE(ctx, 'stickerSize') : ctx.m('stSize')),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [for (final s in sizes) ButtonSegment(value: s, label: Text(ctx.m('stSizes.$s')))],
          selected: {size},
          onSelectionChanged: (v) => _set('size', v.first),
        ),
        label(ctx.m('stAlign')),
        Row(
          children: [
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'left', icon: const Icon(LucideIcons.alignLeft, size: 18), tooltip: ctx.m('stAligns.left')),
                ButtonSegment(value: 'center', icon: const Icon(LucideIcons.alignCenter, size: 18), tooltip: ctx.m('stAligns.center')),
                ButtonSegment(value: 'right', icon: const Icon(LucideIcons.alignRight, size: 18), tooltip: ctx.m('stAligns.right')),
              ],
              selected: {align},
              onSelectionChanged: (v) => _set('align', v.first),
            ),
            const Spacer(),
            if (!sticker) ...[
              _Toggle(icon: LucideIcons.bold, on: b.style['bold'] == true, tip: ctx.m('stBold'), onTap: () => _set('bold', b.style['bold'] != true)),
              const SizedBox(width: 8),
              _Toggle(icon: LucideIcons.italic, on: b.style['italic'] == true, tip: ctx.m('stItalic'), onTap: () => _set('italic', b.style['italic'] != true)),
            ],
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  final bool on, none;
  final Color? color, ring;
  final VoidCallback onTap;
  final String tip;
  const _Swatch({required this.on, this.none = false, this.color, this.ring, required this.onTap, required this.tip});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: tip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: none ? c.card : color,
            border: Border.all(color: on ? c.ink : (ring ?? c.line), width: on ? 2.5 : 1.2),
          ),
          child: none ? Icon(LucideIcons.ban, size: 16, color: c.muted) : (on ? Icon(LucideIcons.check, size: 16, color: ring != null ? c.ink : Colors.white) : null),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final IconData icon;
  final bool on;
  final String tip;
  final VoidCallback onTap;
  const _Toggle({required this.icon, required this.on, required this.tip, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: tip,
      child: Material(
        color: on ? c.solid : c.bg2,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(width: 46, height: 42, child: Icon(icon, size: 18, color: on ? c.onSolid : c.ink)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- a box (callout) and a line (divider)
void ntAddCallout(NtEditorApi ed) => ed.insertAfter(
  NtBlock.blank('callout')
    ..icon = '💡'
    ..style = {'bg': 'amber'},
);

void ntAddDivider(NtEditorApi ed) => ed.insertAfter(NtBlock.blank('divider'), focus: false);

// ---------------------------------------------------------------- stickers
Future<void> ntStickerSheet(NtEditorApi ed) async {
  final key = await showSheet<String>(ed.context, (_) => NtStickerPicker(ctx: ed.ctx));
  if (key == null) return;
  ed.insertAfter(NtBlock.blank('sticker')..sticker = key, focus: true);
}

class NtStickerPicker extends StatefulWidget {
  final NtCtx ctx;
  const NtStickerPicker({super.key, required this.ctx});
  @override
  State<NtStickerPicker> createState() => _NtStickerPickerState();
}

class _NtStickerPickerState extends State<NtStickerPicker> {
  String _group = ntStickerGroups.first;
  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final list = ntStickers.values.where((s) => s.group == _group).toList();
    final names = ntStickerGroupNames[ctx.km ? 'km' : 'en']!;
    return MSheet(
      title: ctx.m('stSticker'),
      children: [
        NtChips<String>(items: [for (final g in ntStickerGroups) (g, names[g] ?? g, null)], value: _group, onChanged: (g) => setState(() => _group = g)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            for (final s in list)
              Tooltip(
                message: s.name(ctx.km),
                child: Material(
                  color: context.c.bg2,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pop(context, s.key),
                    child: Padding(padding: const EdgeInsets.all(10), child: SvgPicture.string(s.svg)),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- emoji
const _recentKey = 'note_emoji_recent';
List<String> _recent() => (prefStr(_recentKey) ?? '').split('\u0001').where((e) => e.isNotEmpty).toList();
void _remember(String e) {
  final l = [e, ..._recent().where((x) => x != e)].take(24).toList();
  prefSetStr(_recentKey, l.join('\u0001'));
}

// picks an emoji; null = closed. Inserted at the caret by the toolbar button.
Future<String?> ntPickEmoji(BuildContext context, NtCtx ctx) => showSheet<String>(context, (_) => NtEmojiPicker(ctx: ctx));

Future<void> ntEmojiTool(NtEditorApi ed) async {
  final e = await ntPickEmoji(ed.context, ed.ctx);
  if (e == null) return;
  final b = ed.currentBlock;
  if (b != null && b.t == 'callout' && b.text.isEmpty && b.icon.isEmpty) {
    b.icon = e;
    ed.rebuild();
    ed.changed();
    return;
  }
  ed.insertText(e);
}

class NtEmojiPicker extends StatefulWidget {
  final NtCtx ctx;
  const NtEmojiPicker({super.key, required this.ctx});
  @override
  State<NtEmojiPicker> createState() => _NtEmojiPickerState();
}

class _NtEmojiPickerState extends State<NtEmojiPicker> {
  late String _tab = _recent().isNotEmpty ? 'recent' : ntEmojiGroups.first;
  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final c = context.c;
    final names = ntEmojiGroupNames[ctx.km ? 'km' : 'en']!;
    final list = _tab == 'recent' ? _recent() : (ntEmoji[_tab] ?? const <String>[]);
    return MSheet(
      title: ctx.m('stEmoji'),
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final g in ['recent', ...ntEmojiGroups])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Tooltip(
                    message: names[g] ?? g,
                    child: Material(
                      color: g == _tab ? c.active : c.bg2,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _tab = g),
                        child: SizedBox(
                          width: 46,
                          child: Center(child: Text(ntEmojiTab[g] ?? '•', style: const TextStyle(fontSize: 20))),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Text(names[_tab] ?? _tab, style: TextStyle(fontWeight: FontWeight.w800, color: c.muted, fontSize: 12.5)),
        ),
        if (list.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text(ntE(ctx, 'noRecent'), style: TextStyle(color: c.muted))))
        else
          GridView.count(
            crossAxisCount: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final e in list)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    _remember(e);
                    Navigator.pop(context, e);
                  },
                  child: Center(child: Text(e, style: const TextStyle(fontSize: 24))),
                ),
            ],
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- note paper
Future<void> ntPaperSheet(NtEditorApi ed) async {
  final ctx = ed.ctx;
  final cur = str(ed.note['paper']).isEmpty ? 'plain' : str(ed.note['paper']);
  final pick = await showSheet<String>(
    ed.context,
    (s) => MSheet(
      title: ctx.m('paperTitle'),
      children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: .82,
          children: [
            for (final p in ntPapers)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.pop(s, p),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: p == cur ? s.c.brand : s.c.line, width: p == cur ? 2.5 : 1.2),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CustomPaint(
                          painter: NtPaperPainter(p, base: s.c.card),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(ctx.m('papers.$p'), style: TextStyle(fontWeight: p == cur ? FontWeight.w800 : FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  );
  if (pick == null || pick == cur) return;
  final r = await ctx.run(() => ctx.a.update(ed.nid, {'paper': pick}));
  if (r != null) ed.setNote({'paper': pick});
}

// the paper behind the editor (the web's .paper-lined / grid / dots / kraft / night)
Color? ntPaperColour(String paper) => switch (paper) {
  'kraft' => const Color(0xFFE6D0AA),
  'night' => const Color(0xFF15171E),
  _ => null,
};

class NtPaperPainter extends CustomPainter {
  final String paper;
  final Color base;
  final double offset; // scroll (the lines move with the text)
  const NtPaperPainter(this.paper, {required this.base, this.offset = 0});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ntPaperColour(paper) ?? base);
    final p = Paint()..isAntiAlias = true;
    void dots(double step, double r, Color col, {double dx = 0}) {
      p.color = col;
      final start = -(offset % step);
      for (var y = start; y < size.height + step; y += step) {
        for (var x = dx; x < size.width + step; x += step) {
          canvas.drawCircle(Offset(x, y), r, p);
        }
      }
    }

    switch (paper) {
      case 'lined':
        p
          ..color = const Color(0x262F6FEB)
          ..strokeWidth = 1;
        for (var y = 18 + 31 - (offset % 32); y < size.height; y += 32) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
      case 'grid':
        p
          ..color = const Color(0x0F16171B)
          ..strokeWidth = 1;
        for (var y = -(offset % 22); y < size.height; y += 22) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
        for (var x = 0.0; x < size.width; x += 22) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
        }
      case 'dots':
        dots(18, 1.2, const Color(0x2B16171B), dx: 9);
      case 'kraft':
        dots(7, 1, const Color(0x17784E1E));
        dots(11, 1, const Color(0x38FFFFFF), dx: 5);
      case 'night':
        dots(26, 1, const Color(0x14FFFFFF), dx: 13);
    }
  }

  @override
  bool shouldRepaint(NtPaperPainter old) => old.paper != paper || old.base != base || old.offset != offset;
}

// the editor body on its paper (registered as an editor backdrop). Night paper = the dark look for the text too.
Widget ntPaperBackdrop(NtEditorApi ed, Widget child) {
  final paper = str(ed.note['paper']);
  if (paper.isEmpty || paper == 'plain') return child;
  final context = ed.context;
  Widget body = Stack(
    children: [
      Positioned.fill(child: CustomPaint(painter: NtPaperPainter(paper, base: context.c.card))),
      child,
    ],
  );
  if (paper == 'night' && Theme.of(context).brightness != Brightness.dark) {
    body = Theme(data: buildTheme(dark: true, khmer: ed.ctx.km), child: body);
  } else if (paper == 'kraft' && Theme.of(context).brightness == Brightness.dark) {
    body = Theme(data: buildTheme(dark: false, khmer: ed.ctx.km), child: body);
  }
  return body;
}
