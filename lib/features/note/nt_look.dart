import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt, initialOf;
import '../../core/theme.dart';
import '../../widgets/look_sheet.dart';
import '../../widgets/ui.dart';
import 'nt_blocks.dart';
import 'nt_common.dart';
import 'nt_data.dart';
import 'nt_editor.dart';

// Page looks (note_theme, 3 coins per theme, forever, for every note and group of the business): how people see the
// shared page. The look sheet shows each theme on the note's own words (native previews built from the web's
// themes.css tokens), the accent colour panel, Use / Unlock. ntLookSheet is shared with groups.

// 12 accent swatches (web themes.js ACCENTS)
const ntAccents = ['#e0581a', '#e11d48', '#db2777', '#9333ea', '#4f46e5', '#2563eb', '#0891b2', '#0d9488', '#16a34a', '#ca8a04', '#a0522d', '#334155'];

Color ntHex(String hex, [Color fallback = const Color(0xFFE0581A)]) {
  final h = hex.replaceFirst('#', '');
  final v = int.tryParse(h.length == 6 ? h : '', radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

String ntHexOf(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

// lighter (+) / darker (−) like the web's shade()
Color ntShade(Color c, double percent) {
  int f(int v) => (v + (percent / 100) * (percent > 0 ? 255 - v : v)).round().clamp(0, 255);
  final argb = c.toARGB32();
  return Color.fromARGB(255, f((argb >> 16) & 255), f((argb >> 8) & 255), f(argb & 255));
}

// the look of one theme (from themes.css): page background, card, text colours, title font, corners, decoration
class NtLook {
  final List<int> bg; // a gradient top → bottom (one colour = flat)
  final int card, ink, muted, line;
  final String font; // sans | serif | hand | mono | didot
  final double radius;
  final String deco; // none | dots | lines | grid | stars | blobs | band | confetti | petals | weave
  final bool dark;
  const NtLook({required this.bg, required this.card, required this.ink, required this.muted, required this.line, this.font = 'sans', this.radius = 22, this.deco = 'none', this.dark = false});
}

const ntLooks = <String, NtLook>{
  'default': NtLook(bg: [0xFFF4F5F8, 0xFFEEF0F4], card: 0xFFFFFFFF, ink: 0xFF16171B, muted: 0xFF6A6E7A, line: 0xFFE7E9EE),
  'paper': NtLook(bg: [0xFFF3EEE3, 0xFFEBE4D6], card: 0xFFFFFDF7, ink: 0xFF2A251D, muted: 0xFF7A7062, line: 0xFFE7E0CF, font: 'serif', radius: 6, deco: 'dots'),
  'linen': NtLook(bg: [0xFFECE3D4, 0xFFE6DCCB], card: 0xFFFAF6EF, ink: 0xFF3A3128, muted: 0xFF85786A, line: 0xFFE4DACB, font: 'serif', radius: 22, deco: 'weave'),
  'notebook': NtLook(bg: [0xFFE7EDF6, 0xFFDFE7F3], card: 0xFFFFFFFF, ink: 0xFF1F2A44, muted: 0xFF67708A, line: 0xFFD9E3F2, font: 'hand', radius: 12, deco: 'lines'),
  'chalk': NtLook(bg: [0xFF22392D, 0xFF1D3127], card: 0xFF2B4437, ink: 0xFFF2F0E6, muted: 0xFFB9C7BB, line: 0x29FFFFFF, font: 'hand', radius: 10, deco: 'dots', dark: true),
  'midnight': NtLook(bg: [0xFF141B36, 0xFF0B1020], card: 0xFF141A2F, ink: 0xFFE9ECFF, muted: 0xFF9AA3C7, line: 0xFF262E4C, radius: 22, deco: 'stars', dark: true),
  'ocean': NtLook(bg: [0xFFE0F4FB, 0xFFBDE6F5, 0xFF7CC8E6], card: 0xE6FFFFFF, ink: 0xFF0B2A3A, muted: 0xFF4B6A7A, line: 0x2E0E7490, radius: 28, deco: 'blobs'),
  'forest': NtLook(bg: [0xFF13301F, 0xFF0B1D12], card: 0xFFF4F1E6, ink: 0xFF1D2B1F, muted: 0xFF5D6D5C, line: 0xFFD9DCCB, font: 'serif', radius: 26, deco: 'weave'),
  'sunset': NtLook(bg: [0xFFFFB36B, 0xFFFF7A7A, 0xFFB45CC9], card: 0xFFFFFAF6, ink: 0xFF3B1D1D, muted: 0xFF8A5D58, line: 0xFFF3D9CD, radius: 26),
  'lotus': NtLook(bg: [0xFFFDF1F5, 0xFFFBE3EC], card: 0xFFFFFFFF, ink: 0xFF3D1F2C, muted: 0xFF8D6678, line: 0xFFF6D7E2, font: 'serif', radius: 32, deco: 'petals'),
  'temple': NtLook(bg: [0xFFD5BD93, 0xFFC3A679], card: 0xFFEFE3CC, ink: 0xFF3B2B17, muted: 0xFF7A6446, line: 0xFFD7C3A0, font: 'serif', radius: 4, deco: 'grid'),
  'mango': NtLook(bg: [0xFFFFCF3A, 0xFFFFC21F], card: 0xFFFFFFFF, ink: 0xFF1B1400, muted: 0xFF6B5A20, line: 0xFF1B1400, radius: 24, deco: 'dots'),
  'mint': NtLook(bg: [0xFFE9FBF3, 0xFFF6FFFB], card: 0xFFFFFFFF, ink: 0xFF0F2E25, muted: 0xFF5B7B70, line: 0xFFCDEEE2, radius: 20),
  'lavender': NtLook(bg: [0xFFE7DCFB, 0xFFF5F0FC, 0xFFFBE3F3], card: 0xFFFCFAFF, ink: 0xFF2C2240, muted: 0xFF7D7196, line: 0xFFE7DEF7, font: 'serif', radius: 28),
  'coffee': NtLook(bg: [0xFF4A3326, 0xFF2C1E16], card: 0xFFF6ECDF, ink: 0xFF3A2619, muted: 0xFF86684F, line: 0xFFE2D1BC, font: 'serif', radius: 14),
  'newsprint': NtLook(bg: [0xFFE9E6DE, 0xFFE9E6DE], card: 0xFFFBFAF6, ink: 0xFF111111, muted: 0xFF555555, line: 0xFFCFCBC0, font: 'serif', radius: 0, deco: 'dots'),
  'blueprint': NtLook(bg: [0xFF0F3B6D, 0xFF0F3B6D], card: 0xFF13467F, ink: 0xFFEAF4FF, muted: 0xFFA7C7EC, line: 0x40FFFFFF, font: 'mono', radius: 2, deco: 'grid', dark: true),
  'neon': NtLook(bg: [0xFF1A0F2E, 0xFF07060D], card: 0xFF0F0D1A, ink: 0xFFF2F0FF, muted: 0xFF9B97B8, line: 0xFF2A2640, radius: 16, deco: 'blobs', dark: true),
  'glass': NtLook(bg: [0xFFDCD8FF, 0xFFEEF0FF, 0xFFCFF4FA], card: 0x8CFFFFFF, ink: 0xFF15172B, muted: 0xFF55597A, line: 0xB3FFFFFF, radius: 26, deco: 'blobs'),
  'kraft': NtLook(bg: [0xFFCFAE7E, 0xFFC9A574], card: 0xFFE8D3AD, ink: 0xFF3A2612, muted: 0xFF7A5C3B, line: 0x47502814, font: 'mono', radius: 6, deco: 'dots'),
  'sakura': NtLook(bg: [0xFFFFF5F9, 0xFFFFE8F1], card: 0xFFFFFFFF, ink: 0xFF3A1D2B, muted: 0xFF8F6A7C, line: 0xFFF8DBE7, font: 'serif', radius: 24, deco: 'petals'),
  'corporate': NtLook(bg: [0xFFEEF2F7, 0xFFEEF2F7], card: 0xFFFFFFFF, ink: 0xFF0F1A2E, muted: 0xFF5A6478, line: 0xFFE1E6EE, radius: 8, deco: 'band'),
  'school': NtLook(bg: [0xFFFEF9E7, 0xFFFEF9E7], card: 0xFFFFFFFF, ink: 0xFF1F2937, muted: 0xFF6B7280, line: 0xFFE5E7EB, font: 'hand', radius: 20, deco: 'dots'),
  'wedding': NtLook(bg: [0xFFFFFFFF, 0xFFF5EEE2], card: 0xFFFFFDF9, ink: 0xFF3A2E22, muted: 0xFF8A7A66, line: 0xFFEADFCA, font: 'didot', radius: 2),
  'festival': NtLook(bg: [0xFFE11D48, 0xFFF97316, 0xFFFACC15], card: 0xFFFFFFFF, ink: 0xFF26120D, muted: 0xFF7A5148, line: 0xFFF6D6C9, radius: 22, deco: 'confetti'),
};

String? _family(String font) => switch (font) {
  'serif' || 'didot' => 'serif',
  'mono' => 'monospace',
  'hand' => 'cursive',
  _ => null,
};

// ---------------------------------------------------------------- one theme on the note's own words
class NtThemePreview extends StatelessWidget {
  final String themeKey, color; // color '' = the theme's own accent
  final String title, bizName;
  final List<NtBlock> blocks;
  final double width;
  const NtThemePreview({super.key, required this.themeKey, this.color = '', this.title = '', this.bizName = '', this.blocks = const [], this.width = 300});

  @override
  Widget build(BuildContext context) {
    final look = ntLooks[themeKey] ?? ntLooks['default']!;
    final th = ntThemes.where((t) => t.key == themeKey).firstOrNull;
    final acc = color.isNotEmpty ? ntHex(color) : (str(th?.accent).isNotEmpty ? ntHex(th!.accent) : const Color(0xFFE0581A));
    final ink = Color(look.ink), muted = Color(look.muted), card = Color(look.card), line = Color(look.line);
    final titleStyle = TextStyle(fontFamily: _family(look.font), fontFamilyFallback: const ['KantumruyPro'], fontWeight: look.font == 'didot' ? FontWeight.w500 : FontWeight.w800, fontSize: 21, height: 1.25, color: ink, fontStyle: themeKey == 'linen' ? FontStyle.italic : FontStyle.normal);
    final body = TextStyle(fontFamily: look.font == 'mono' ? 'monospace' : null, fontFamilyFallback: const ['KantumruyPro'], fontSize: 13, height: 1.5, color: ink.withValues(alpha: .86));
    final lines = blocks.where((b) => b.isText && b.text.trim().isNotEmpty).take(5).toList();
    Widget lineOf(NtBlock b) {
      final text = Text(b.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: b.t == 'h' ? body.copyWith(fontWeight: FontWeight.w800, fontSize: 15, fontFamily: _family(look.font)) : body);
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: switch (b.t) {
          'check' => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2, right: 8),
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: b.done ? acc : Colors.transparent,
                  borderRadius: BorderRadius.circular(themeKey == 'linen' ? 99 : 4),
                  border: Border.all(color: b.done ? acc : muted, width: 1.5),
                ),
                child: b.done ? const Icon(LucideIcons.check, size: 11, color: Colors.white) : null,
              ),
              Expanded(child: text),
            ],
          ),
          'bullet' => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 7, right: 8, left: 2),
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: acc, shape: BoxShape.circle),
              ),
              Expanded(child: text),
            ],
          ),
          'quote' => Container(
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: acc, width: 3)),
            ),
            child: Text(b.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: body.copyWith(fontStyle: FontStyle.italic, color: muted)),
          ),
          _ => text,
        },
      );
    }

    final page = Container(
      width: width,
      height: width * 1.55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [for (final x in look.bg) Color(x)]),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _DecoPainter(look.deco, acc, look.dark))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // the top bar
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                color: look.deco == 'band' ? Colors.transparent : card.withValues(alpha: .78),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: acc, borderRadius: BorderRadius.circular(8)),
                      child: Text(initialOf(bizName.isEmpty ? 'B' : bizName), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        bizName.isEmpty ? 'BizHub' : bizName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: look.deco == 'band' ? Colors.white : ink),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(look.radius.clamp(0, 26)),
                      border: Border.all(color: line),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: look.dark ? .3 : .08), blurRadius: 18, offset: const Offset(0, 8))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 4, width: 44, decoration: BoxDecoration(color: acc, borderRadius: BorderRadius.circular(9))),
                        const SizedBox(height: 10),
                        Text(title.isEmpty ? (th?.name(false) ?? 'Note') : title, maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle),
                        const SizedBox(height: 10),
                        // the note's own lines (as many as fit)
                        Expanded(
                          child: ClipRect(
                            child: SingleChildScrollView(
                              physics: const NeverScrollableScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (lines.isEmpty)
                                    for (final w in const [1.0, .85, .6])
                                      Container(
                                        height: 9,
                                        margin: const EdgeInsets.only(bottom: 8),
                                        width: width * .62 * w,
                                        decoration: BoxDecoration(color: muted.withValues(alpha: .25), borderRadius: BorderRadius.circular(9)),
                                      )
                                  else
                                    for (final b in lines) lineOf(b),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // a reply bubble + the button, in the accent
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(color: Color.alphaBlend(ink.withValues(alpha: .05), card), borderRadius: BorderRadius.circular(themeKey == 'newsprint' ? 0 : 14)),
                          child: Row(
                            children: [
                              CircleAvatar(radius: 9, backgroundColor: acc.withValues(alpha: .25), child: Text('S', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: acc))),
                              const SizedBox(width: 6),
                              Expanded(child: Container(height: 7, decoration: BoxDecoration(color: muted.withValues(alpha: .3), borderRadius: BorderRadius.circular(9)))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: acc,
                            borderRadius: BorderRadius.circular(themeKey == 'paper' || themeKey == 'temple' || themeKey == 'blueprint' || themeKey == 'newsprint' ? 6 : 99),
                            boxShadow: themeKey == 'paper' ? [BoxShadow(color: ntShade(acc, -35), offset: const Offset(0, 3))] : null,
                          ),
                          child: const Icon(LucideIcons.send, size: 15, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return page;
  }
}

class _DecoPainter extends CustomPainter {
  final String deco;
  final Color acc;
  final bool dark;
  _DecoPainter(this.deco, this.acc, this.dark);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..isAntiAlias = true;
    switch (deco) {
      case 'dots':
        p.color = (dark ? Colors.white : Colors.black).withValues(alpha: .07);
        for (var y = 6.0; y < size.height; y += 12) {
          for (var x = 6.0; x < size.width; x += 12) {
            canvas.drawCircle(Offset(x, y), 1.1, p);
          }
        }
      case 'lines':
        p
          ..color = const Color(0x332F6FEB)
          ..strokeWidth = 1;
        for (var y = 30.0; y < size.height; y += 18) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
        p.color = const Color(0x66EF4444);
        canvas.drawLine(const Offset(26, 0), Offset(26, size.height), p);
      case 'grid':
        p
          ..color = (dark ? Colors.white : const Color(0xFF5A3C14)).withValues(alpha: .14)
          ..strokeWidth = 1;
        for (var y = 0.0; y < size.height; y += 20) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
        for (var x = 0.0; x < size.width; x += 20) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
        }
      case 'weave':
        p
          ..color = (dark ? Colors.white : const Color(0xFF6E5A3C)).withValues(alpha: .06)
          ..strokeWidth = 1;
        for (var y = 0.0; y < size.height; y += 4) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
        for (var x = 0.0; x < size.width; x += 4) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
        }
      case 'stars':
        p.color = Colors.white.withValues(alpha: .8);
        for (final (x, y, r) in const [(.2, .3, 1.0), (.7, .12, 1.0), (.85, .6, 1.4), (.4, .8, 1.0), (.1, .7, .8), (.55, .45, .9), (.92, .25, .8)]) {
          canvas.drawCircle(Offset(size.width * x, size.height * y), r, p);
        }
        p.shader = RadialGradient(colors: [acc.withValues(alpha: .35), acc.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: Offset(size.width * .8, 0), radius: size.width * .9));
        canvas.drawRect(Offset.zero & size, p);
      case 'blobs':
        for (final (x, y, col) in [(.15, .2, acc), (.85, .35, const Color(0xFFEC4899)), (.5, .95, const Color(0xFF22D3EE))]) {
          p.shader = RadialGradient(colors: [col.withValues(alpha: dark ? .3 : .5), col.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: Offset(size.width * x, size.height * y), radius: size.width * .6));
          canvas.drawRect(Offset.zero & size, p);
        }
      case 'band':
        p.color = const Color(0xFF0F2A5E);
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * .28), p);
      case 'confetti':
        for (final (x, y, col) in const [(.1, .1, 0xFFFFD23F), (.3, .4, 0xFF3EC1FF), (.7, .2, 0xFFFFFFFF), (.85, .6, 0xFF7CFF6B), (.5, .85, 0xFFFFD23F), (.2, .7, 0xFFFFFFFF)]) {
          p.color = Color(col).withValues(alpha: .85);
          canvas.drawCircle(Offset(size.width * x, size.height * y), 3, p);
        }
      case 'petals':
        for (final (x, y) in const [(.12, .18), (.32, .64), (.68, .22), (.86, .72), (.52, .88)]) {
          p.color = const Color(0x66F9A8D4);
          canvas.drawOval(Rect.fromCenter(center: Offset(size.width * x, size.height * y), width: 12, height: 8), p);
        }
    }
  }

  @override
  bool shouldRepaint(_DecoPainter old) => old.deco != deco || old.acc != acc;
}

// ---------------------------------------------------------------- the sheet (notes + groups)
// theme = { key, color } now; save(theme) → true = saved. Locked themes show "Unlock · 3 coins".
Future<void> ntLookSheet(BuildContext context, NtCtx ctx, {required Json theme, required Future<bool> Function(Json theme) save, String title = '', List<NtBlock> blocks = const []}) async {
  final keys = [for (final t in ntThemes) t.key];
  var current = {'key': str(theme['key']).isEmpty ? 'default' : str(theme['key']), 'color': str(theme['color'])};
  var color = current['color']!;
  final owned = {...ctx.themesOwned};
  bool isOwned(String k) => k == 'default' || owned.contains(k) || ctx.themesOwned.contains(k);
  await showLookSheet(
    context,
    title: ctx.m('lookTitle'),
    count: keys.length,
    initial: keys.indexOf(current['key']!).clamp(0, keys.length - 1),
    item: (c, i, refresh) {
      final k = keys[i];
      final th = ntThemes[i];
      final inUse = current['key'] == k;
      final mine = isOwned(k);
      return LookItem(
        name: th.name(ctx.km),
        sub: [for (final tag in th.tags) tag].where((x) => x != 'free').join(' · '),
        badge: inUse ? ctx.m('themeIn') : (k == 'default' ? ctx.m('themeFree') : (mine ? ctx.m('themeOwned') : '${fmt(ctx.price('note_theme'))} ${ctx.m('coins')}')),
        badgeTone: inUse ? Tone.good : (mine ? Tone.brand : Tone.muted),
        preview: NtThemePreview(themeKey: k, color: color, title: title, bizName: ctx.bizName, blocks: blocks),
        extras: [
          _AccentRow(
            ctx: ctx,
            value: color,
            auto: th.accent,
            onPick: (v) {
              color = v;
              refresh();
            },
          ),
          const SizedBox(height: 10),
        ],
        acts: [
          if (mine)
            LookAct(
              inUse && color == current['color'] ? ctx.m('themeIn') : ctx.m('themeUse'),
              icon: LucideIcons.check,
              onTap: inUse && color == current['color']
                  ? null
                  : () async {
                      final next = {'key': k, 'color': color};
                      if (!await save(next)) return false;
                      current = next;
                      ctx.notify(ctx.m('themeApplied'));
                      return true;
                    },
            )
          else
            LookAct(
              ctx.m('v4Unlock', {'coins': fmt(ctx.price('note_theme'))}),
              gold: true,
              onTap: () async {
                final bought = await ntUnlock(c, ctx, 'note_theme', item: k);
                if (!bought) return false;
                owned.add(k);
                final next = {'key': k, 'color': color};
                if (!await save(next)) {
                  refresh();
                  return false;
                }
                current = next;
                return true;
              },
            ),
        ],
      );
    },
  );
}

class _AccentRow extends StatelessWidget {
  final NtCtx ctx;
  final String value, auto;
  final ValueChanged<String> onPick;
  const _AccentRow({required this.ctx, required this.value, required this.auto, required this.onPick});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget dot(String hex, {bool isAuto = false}) {
      final on = isAuto ? value.isEmpty : value == hex;
      final col = isAuto ? (auto.isEmpty ? c.muted : ntHex(auto)) : ntHex(hex);
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Tooltip(
          message: isAuto ? ctx.m('themeColorAuto') : hex,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onPick(isAuto ? '' : hex),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: col,
                border: Border.all(color: on ? c.ink : Colors.white, width: on ? 2.5 : 2),
                boxShadow: c.cardShadow,
              ),
              child: isAuto ? const Icon(LucideIcons.sparkles, size: 14, color: Colors.white) : (on ? const Icon(LucideIcons.check, size: 14, color: Colors.white) : null),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ctx.m('themeColor'), style: TextStyle(color: c.muted, fontWeight: FontWeight.w800, fontSize: 12)),
        const SizedBox(height: 6),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              dot('', isAuto: true),
              for (final a in ntAccents) dot(a),
              Tooltip(
                message: ctx.m('themeCustom'),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () async {
                    final v = await _customColour(context, ctx, value.isEmpty ? (auto.isEmpty ? '#e0581a' : auto) : value);
                    if (v != null) onPick(v);
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.lineStrong, width: 1.5)),
                    child: Icon(LucideIcons.pipette, size: 15, color: c.ink),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// a #rrggbb colour (with a little live dot)
Future<String?> _customColour(BuildContext context, NtCtx ctx, String start) {
  final ctl = TextEditingController(text: start);
  return showDialog<String>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, set) {
        final ok = RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(ctl.text.trim());
        final hex = ok ? '#${ctl.text.trim().replaceFirst('#', '').toLowerCase()}' : '';
        return AlertDialog(
          title: Text(ctx.m('themeCustom')),
          content: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: ok ? ntHex(hex) : d.c.bg2, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: ctl,
                  maxLength: 7,
                  autofocus: true,
                  onChanged: (_) => set(() {}),
                  decoration: const InputDecoration(counterText: '', hintText: '#e0581a'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: Text(ctx.m('cancel'))),
            FilledButton(onPressed: ok ? () => Navigator.pop(d, hex) : null, child: Text(ctx.m('save'))),
          ],
        );
      },
    ),
  ).whenComplete(ctl.dispose);
}

// the ⋯ menu entry of a note
Future<void> ntLookTool(NtEditorApi ed) => ntLookSheet(
  ed.context,
  ed.ctx,
  theme: obj(ed.note['theme']),
  title: str(ed.note['title']),
  blocks: ed.blocks,
  save: (theme) async {
    final r = await ed.ctx.run(() => ed.ctx.a.update(ed.nid, {'theme': theme}));
    if (r == null) return false;
    ed.setNote({'theme': theme});
    return true;
  },
);
