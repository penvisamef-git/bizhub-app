import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../widgets/ui.dart' show netImage;
import 'ev_common.dart';

// Event Tickets designs, drawn in the app (the web's evpub/themes.js + themes.css, pageThemes.js + pagethemes.css,
// certThemes.js + cert.css). Keys and colours are the same as the web and the API (event.themes.js).

// ============================================================ colours
Color evHex(Object? v, [Color? fallback]) {
  final s = '${v ?? ''}'.replaceFirst('#', '');
  final x = s.length == 6 ? int.tryParse(s, radix: 16) : null;
  return x == null ? (fallback ?? const Color(0xFFF0662B)) : Color(0xFF000000 | x);
}

bool _isHex(Object? v) => RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch('${v ?? ''}');
// color-mix(in srgb, a p%, b)
Color mixC(Color a, Color b, double p) => Color.lerp(b, a, p)!;
Color fade(Color a, double p) => a.withValues(alpha: p);

class EvLook {
  final String key, tier, layout, palette;
  final Color a, b, c;
  const EvLook(this.key, this.tier, this.layout, this.palette, this.a, this.b, this.c);
  bool get free => tier == 'free';
}

// ============================================================ ticket designs: classic + 12 styles × 10 colours
const evTicketLayouts = ['gradient', 'stub', 'pass', 'neon', 'retro', 'vip', 'glass', 'festival', 'minimal', 'badge', 'khmer', 'pop'];
const _tPal = <String, List<int>>{
  'ruby': [0xe11d48, 0xfb7185, 0x881337],
  'ocean': [0x0284c7, 0x38bdf8, 0x0c4a6e],
  'jungle': [0x16a34a, 0x86efac, 0x14532d],
  'sunset': [0xea580c, 0xfbbf24, 0x7c2d12],
  'royal': [0x7c3aed, 0xc4b5fd, 0x3b0764],
  'rose': [0xdb2777, 0xf9a8d4, 0x831843],
  'gold': [0xb7791f, 0xf6d365, 0x4a3300],
  'teal': [0x0d9488, 0x5eead4, 0x134e4a],
  'indigo': [0x4f46e5, 0xa5b4fc, 0x1e1b4b],
  'mono': [0x27272a, 0xa1a1aa, 0x09090b],
};
Color _c(int v) => Color(0xFF000000 | v);
final Map<String, EvLook> evTicketThemes = {
  'classic': EvLook('classic', 'free', 'classic', 'classic', _c(0xf0662b), _c(0xff9a3c), _c(0xb03c8f)),
  for (final l in evTicketLayouts)
    for (final p in _tPal.entries) '$l-${p.key}': EvLook('$l-${p.key}', 'premium', l, p.key, _c(p.value[0]), _c(p.value[1]), _c(p.value[2])),
};
List<String> get evTicketKeys => evTicketThemes.keys.toList();
EvLook ticketThemeOf(Object? key) => evTicketThemes['${key ?? ''}'] ?? evTicketThemes['classic']!;

const _tLayoutNames = <String, List<String>>{
  'classic': ['Classic', 'បុរាណ'],
  'gradient': ['Gradient', 'ពណ៌លាយ'],
  'stub': ['Tear-off', 'ហែកបាន'],
  'pass': ['Boarding pass', 'សំបុត្រជិះ'],
  'neon': ['Neon night', 'នីអុង'],
  'retro': ['Cinema', 'រោងកុន'],
  'vip': ['VIP foil', 'VIP ភ្លឺ'],
  'glass': ['Glass', 'កញ្ចក់'],
  'festival': ['Festival', 'មហោស្រព'],
  'minimal': ['Minimal', 'សាមញ្ញ'],
  'badge': ['Name badge', 'កាតឈ្មោះ'],
  'khmer': ['Khmer art', 'ក្បាច់ខ្មែរ'],
  'pop': ['Pop art', 'ប៉ុបអាត'],
};
const _tPalNames = <String, List<String>>{
  'ruby': ['Ruby', 'ត្បូងទទឹម'],
  'ocean': ['Ocean', 'សមុទ្រ'],
  'jungle': ['Jungle', 'ព្រៃ'],
  'sunset': ['Sunset', 'ថ្ងៃលិច'],
  'royal': ['Royal', 'រាជវង្ស'],
  'rose': ['Rose', 'ផ្កាកុលាប'],
  'gold': ['Gold', 'មាស'],
  'teal': ['Teal', 'ខៀវបៃតង'],
  'indigo': ['Indigo', 'ខៀវចាស់'],
  'mono': ['Mono', 'ខ្មៅស'],
};
String ticketLayoutName(String l, String lang) => (_tLayoutNames[l] ?? _tLayoutNames['classic']!)[lang == 'km' ? 1 : 0];
String ticketThemeName(Object? key, String lang) {
  final t = ticketThemeOf(key);
  if (t.layout == 'classic') return ticketLayoutName('classic', lang);
  return '${ticketLayoutName(t.layout, lang)} · ${_tPalNames[t.palette]![lang == 'km' ? 1 : 0]}';
}

// ============================================================ event page designs: standard + 12 styles × 10 colours
const evPageStill = ['aurora', 'editorial', 'bold', 'midnight', 'pastel', 'cinema'];
const evPageLive = ['live-glow', 'live-confetti', 'live-stars', 'live-waves', 'live-flow', 'live-stage'];
const evPageLayouts = [...evPageStill, ...evPageLive];
const _pDark = {'aurora', 'midnight', 'cinema', 'live-glow', 'live-stars', 'live-stage'};
const _pPal = <String, List<int>>{
  'coral': [0xff5a5f, 0xffb199, 0x7a1f22],
  'lagoon': [0x0891b2, 0x67e8f9, 0x164e63],
  'forest': [0x15803d, 0xbef264, 0x14532d],
  'amber': [0xd97706, 0xfde68a, 0x78350f],
  'violet': [0x8b5cf6, 0xddd6fe, 0x2e1065],
  'blush': [0xec4899, 0xfbcfe8, 0x831843],
  'crimson': [0xdc2626, 0xfca5a5, 0x450a0a],
  'sky': [0x2563eb, 0xbfdbfe, 0x172554],
  'olive': [0x65a30d, 0xd9f99d, 0x365314],
  'graphite': [0x334155, 0xcbd5e1, 0x0f172a],
};
final Map<String, EvLook> evPageThemes = {
  'standard': EvLook('standard', 'free', 'standard', 'standard', _c(0xf0662b), _c(0xff9a3c), _c(0x7c2d12)),
  for (final l in evPageLayouts)
    for (final p in _pPal.entries) '$l-${p.key}': EvLook('$l-${p.key}', 'premium', l, p.key, _c(p.value[0]), _c(p.value[1]), _c(p.value[2])),
};
List<String> get evPageKeys => evPageThemes.keys.toList();
EvLook pageThemeOf(Object? key) => evPageThemes['${key ?? ''}'] ?? evPageThemes['standard']!;
bool isLivePage(Object? key) => evPageLive.contains(pageThemeOf(key).layout);
const _pLayoutNames = <String, List<String>>{
  'standard': ['Standard', 'ស្តង់ដារ'],
  'aurora': ['Aurora', 'ពន្លឺអូរ៉ូរ៉ា'],
  'editorial': ['Magazine', 'ទស្សនាវដ្តី'],
  'bold': ['Bold block', 'ប្លុកដិត'],
  'midnight': ['Midnight', 'កណ្តាលអធ្រាត្រ'],
  'pastel': ['Pastel', 'ពណ៌ស្រាល'],
  'cinema': ['Big poster', 'ផ្ទាំងធំ'],
  'live-glow': ['Live glow', 'ពន្លឺរស់'],
  'live-confetti': ['Live confetti', 'ក្រដាសពណ៌រស់'],
  'live-stars': ['Live stars', 'ផ្កាយរស់'],
  'live-waves': ['Live waves', 'រលករស់'],
  'live-flow': ['Live colours', 'ពណ៌ហូររស់'],
  'live-stage': ['Live stage lights', 'ភ្លើងឆាករស់'],
};
const _pPalNames = <String, List<String>>{
  'coral': ['Coral', 'ផ្កាថ្ម'],
  'lagoon': ['Lagoon', 'បឹងខៀវ'],
  'forest': ['Forest', 'ព្រៃឈើ'],
  'amber': ['Amber', 'ទឹកឃ្មុំ'],
  'violet': ['Violet', 'ស្វាយ'],
  'blush': ['Blush', 'ផ្កាឈូក'],
  'crimson': ['Crimson', 'ក្រហមចាស់'],
  'sky': ['Sky', 'មេឃ'],
  'olive': ['Olive', 'អូលីវ'],
  'graphite': ['Graphite', 'ប្រផេះ'],
};
String pageLayoutName(String l, String lang) => (_pLayoutNames[l] ?? _pLayoutNames['standard']!)[lang == 'km' ? 1 : 0];
String pageThemeName(Object? key, String lang) {
  final t = pageThemeOf(key);
  if (t.layout == 'standard') return pageLayoutName('standard', lang);
  return '${pageLayoutName(t.layout, lang)} · ${_pPalNames[t.palette]![lang == 'km' ? 1 : 0]}';
}

// the colours a design shows with (the owner's own colours win)
(Color, Color, Color) lookColors(EvLook t, Json? own) => (_isHex(own?['a']) ? evHex(own!['a']) : t.a, _isHex(own?['b']) ? evHex(own!['b']) : t.b, _isHex(own?['c']) ? evHex(own!['c']) : t.c);

// ============================================================ certificate designs: 3 free + 10 styles × 10 colours
const certFree = ['classic', 'modern', 'royal'];
const certLayouts = <(String, String, String)>[
  ('frame', 'Frame', 'ស៊ុម'),
  ('band', 'Band', 'ឆ្នូត'),
  ('ornate', 'Ornate', 'លម្អ'),
  ('ribbon', 'Ribbon', 'ខ្សែបូ'),
  ('wave', 'Wave', 'រលក'),
  ('geo', 'Geometric', 'ធរណីមាត្រ'),
  ('minimal', 'Minimal', 'សាមញ្ញ'),
  ('kbach', 'Kbach', 'ក្បាច់'),
  ('medal', 'Medal', 'មេដាយ'),
  ('night', 'Night gold', 'រាត្រីមាស'),
];
const _certPal = <(String, String, String, int, int, int)>[
  ('navy', 'Navy', 'ខៀវចាស់', 0x1e3a8a, 0xc9a227, 0xfffdf7),
  ('emerald', 'Emerald', 'បៃតងត្បូង', 0x065f46, 0xd4af37, 0xf7fdf9),
  ('crimson', 'Crimson', 'ក្រហមចាស់', 0x9f1239, 0xd4a017, 0xfffaf5),
  ('violet', 'Violet', 'ស្វាយ', 0x5b21b6, 0xe0b84f, 0xfcfaff),
  ('teal', 'Teal', 'បៃតងខៀវ', 0x0f766e, 0xf59e0b, 0xf6fefd),
  ('sunset', 'Sunset', 'ថ្ងៃលិច', 0xc2410c, 0xf2b33d, 0xfffaf3),
  ('rose', 'Rose', 'ផ្កាឈូក', 0xbe185d, 0xd9a38b, 0xfff7fa),
  ('slate', 'Slate', 'ប្រផេះ', 0x334155, 0x94a3b8, 0xfafafa),
  ('olive', 'Olive', 'អូលីវ', 0x4d5a1e, 0xb08d3c, 0xfbfaf2),
  ('sky', 'Sky', 'មេឃ', 0x0369a1, 0x38bdf8, 0xf5fbff),
];
final List<String> certAll = [
  ...certFree,
  for (final l in certLayouts)
    for (final p in _certPal) '${l.$1}-${p.$1}',
];
bool isFreeCert(Object? k) => certFree.contains('$k');
String certName(Object? key, String lang) {
  const free = {
    'classic': ['Classic', 'បុរាណ'],
    'modern': ['Modern', 'ទំនើប'],
    'royal': ['Royal', 'រាជ'],
  };
  final k = '${key ?? ''}';
  if (free[k] != null) return free[k]![lang == 'km' ? 1 : 0];
  final parts = k.split('-');
  final l = certLayouts.where((x) => x.$1 == parts.first).firstOrNull;
  final p = parts.length > 1 ? _certPal.where((x) => x.$1 == parts[1]).firstOrNull : null;
  if (l == null || p == null) return k;
  return lang == 'km' ? '${l.$3} · ${p.$3}' : '${l.$2} · ${p.$2}';
}

String certLayoutLabel(String key, String lang) {
  final l = certLayouts.where((x) => x.$1 == key).firstOrNull;
  return l == null ? key : (lang == 'km' ? l.$3 : l.$2);
}

// ============================================================ painters
class _Stripes extends CustomPainter {
  final Color a, b;
  final double w;
  const _Stripes(this.a, this.b, this.w);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = a);
    final p = Paint()..color = b;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (double x = -size.height; x < size.width + size.height; x += w * 2) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + w, size.height)
        ..lineTo(x + w + size.height, 0)
        ..lineTo(x + size.height, 0)
        ..close();
      canvas.drawPath(path, p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Stripes o) => o.a != a || o.b != b;
}

// small dots on a grid (pop art halftone, confetti, stars)
class _Dots extends CustomPainter {
  final List<Color> colors;
  final double gap, r;
  final int seed;
  final bool random;
  final double t; // 0..1 animation
  const _Dots(this.colors, {this.gap = 10, this.r = 1.7, this.seed = 1, this.random = false, this.t = 0});
  @override
  void paint(Canvas canvas, Size size) {
    if (!random) {
      final p = Paint()..color = colors.first;
      for (double y = gap / 2; y < size.height; y += gap) {
        for (double x = gap / 2; x < size.width; x += gap) {
          canvas.drawCircle(Offset(x, y), r, p);
        }
      }
      return;
    }
    final rnd = math.Random(seed);
    final n = (size.width * size.height / (gap * gap)).clamp(10, 400).toInt();
    for (var i = 0; i < n; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = (rnd.nextDouble() * size.height + t * size.height) % size.height;
      final col = colors[i % colors.length];
      final rr = r * (.6 + rnd.nextDouble() * .8);
      canvas.drawCircle(Offset(x, y), rr, Paint()..color = col);
    }
  }

  @override
  bool shouldRepaint(_Dots o) => o.t != t || o.colors != colors;
}

// boarding pass barcode
class _Barcode extends CustomPainter {
  final Color color;
  const _Barcode(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    const pat = [2.0, 2.0, 1.0, 3.0, 3.0, 2.0];
    var x = 0.0;
    var i = 0;
    while (x < size.width) {
      final w = pat[i % pat.length];
      if (i.isEven) canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), p);
      x += w;
      i++;
    }
  }

  @override
  bool shouldRepaint(_Barcode o) => false;
}

// a checker band (Khmer kbach-style)
class _Kbach extends CustomPainter {
  final Color color;
  static const cell = 7.0;
  const _Kbach(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (double x = 0; x < size.width; x += cell * 2) {
      final path = Path()
        ..moveTo(x, size.height / 2)
        ..lineTo(x + cell, 0)
        ..lineTo(x + cell * 2, size.height / 2)
        ..lineTo(x + cell, size.height)
        ..close();
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_Kbach o) => o.color != color;
}

// a dashed / dotted line
class _Dash extends StatelessWidget {
  final Color color;
  final double thick, dash, gap;
  const _Dash(this.color, {this.thick = 2, this.dash = 6, this.gap = 4});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: thick,
    width: double.infinity,
    child: CustomPaint(painter: _DashP(color, thick, dash, gap)),
  );
}

class _DashP extends CustomPainter {
  final Color color;
  final double thick, dash, gap;
  const _DashP(this.color, this.thick, this.dash, this.gap);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = thick
      ..strokeCap = dash <= thick ? StrokeCap.round : StrokeCap.butt;
    if (gap == 0) {
      canvas.drawLine(Offset(0, thick / 2), Offset(size.width, thick / 2), p);
      return;
    }
    for (double x = 0; x < size.width; x += dash + gap) {
      if (dash <= thick) {
        canvas.drawCircle(Offset(x + thick / 2, thick / 2), thick / 2, Paint()..color = color);
      } else {
        canvas.drawLine(Offset(x, thick / 2), Offset(math.min(x + dash, size.width), thick / 2), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DashP o) => o.color != color;
}

// ============================================================ one ticket
// tk: { code, type_name, holder, seat_label, status } · theme / colors: a design to show (null = the event's own)
class EvTicketView extends StatelessWidget {
  final Json ev, tk;
  final String? theme;
  final Json? colors;
  final T t;
  final double width;
  final Color pageBg; // the page behind the ticket (the round cut-outs show it)
  final bool lite; // small previews: a QR picture instead of a real QR code (faster)
  const EvTicketView({super.key, required this.ev, required this.tk, required this.t, this.theme, this.colors, this.width = 300, this.pageBg = const Color(0xFFF5F4F7), this.lite = false});

  @override
  Widget build(BuildContext context) {
    final th = ticketThemeOf(theme ?? ev['theme']);
    final own = colors ?? (theme == null ? obj(ev['theme_colors']) : null);
    final (a, b, c) = lookColors(th, own);
    final L = th.layout;
    final lang = t.lang;
    const ink = Color(0xFF16161D), muted = Color(0xFF6B6B78);
    final serif = L == 'retro' ? 'serif' : null;
    final mono = L == 'minimal' ? 'monospace' : null;
    final foil = LinearGradient(colors: [c, b, Colors.white, b, a], stops: const [0, .28, .45, .6, 1], begin: Alignment.centerLeft, end: Alignment.centerRight);

    // ---- the card
    double radius = 24;
    Color cardColor = Colors.white;
    Gradient? cardGrad;
    BoxBorder? border;
    List<BoxShadow> shadow = const [BoxShadow(color: Color(0x1A141428), blurRadius: 30, offset: Offset(0, 10))];
    Color infoInk = ink, infoMuted = muted;
    switch (L) {
      case 'gradient':
        radius = 26;
      case 'stub':
        radius = 14;
        cardColor = mixC(a, Colors.white, .09);
        border = Border(left: BorderSide(color: a, width: 12));
      case 'pass':
        radius = 18;
      case 'neon':
        radius = 22;
        cardColor = const Color(0xFF0B0B14);
        cardGrad = RadialGradient(center: const Alignment(0, -1), radius: 1.1, colors: [fade(a, .3), const Color(0xFF0B0B14)], stops: const [0, .7]);
        border = Border.all(color: b, width: 1.5);
        shadow = [BoxShadow(color: fade(a, .55), blurRadius: 28), const BoxShadow(color: Color(0x59000000), blurRadius: 34, offset: Offset(0, 14))];
        infoInk = const Color(0xFFF4F4F8);
        infoMuted = const Color(0xFFB8B8C8);
      case 'retro':
        radius = 10;
        cardColor = const Color(0xFFFBF3E1);
        shadow = const [BoxShadow(color: Color(0x2E46280A), blurRadius: 26, offset: Offset(0, 10))];
        infoInk = const Color(0xFF3A2A17);
        infoMuted = const Color(0xFF7A6448);
      case 'vip':
        radius = 18;
        cardGrad = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1B1B1F), Color(0xFF050506)]);
        shadow = const [BoxShadow(color: Color(0x59000000), blurRadius: 36, offset: Offset(0, 14))];
        infoInk = const Color(0xFFF2EFE6);
        infoMuted = const Color(0xFFB9B3A3);
      case 'glass':
        radius = 28;
        cardColor = mixC(b, Colors.white, .35);
        shadow = [BoxShadow(color: fade(c, .3), blurRadius: 40, offset: const Offset(0, 16))];
        infoInk = c;
        infoMuted = mixC(c, Colors.white, .75);
      case 'festival':
        radius = 22;
      case 'minimal':
        radius = 6;
        border = Border.all(color: c, width: 1.5);
        shadow = [BoxShadow(color: fade(a, .22), offset: const Offset(6, 6))];
      case 'badge':
        radius = 20;
      case 'khmer':
        radius = 16;
        cardColor = const Color(0xFFFFF8EA);
        shadow = [BoxShadow(color: fade(c, .25), blurRadius: 30, offset: const Offset(0, 12))];
      case 'pop':
        radius = 16;
        border = Border.all(color: const Color(0xFF111111), width: 3);
        shadow = const [BoxShadow(color: Color(0xFF111111), offset: Offset(7, 7))];
    }

    // ---- the top
    Widget? topBg;
    var topColor = Colors.white;
    Color smallColor = fade(Colors.white, .9);
    var center = false;
    var pad = const EdgeInsets.fromLTRB(20, 18, 20, 16);
    var margin = EdgeInsets.zero;
    double titleSize = 17;
    var titleWeight = FontWeight.w800;
    var italic = false, upper = false, foilTitle = false;
    List<Shadow>? titleShadow;
    Widget? kicker;
    final admit = t('evp.admit');
    TextStyle kStyle(Color col, {double size = 10.5, double sp = 2.3, String? family}) => TextStyle(color: col, fontSize: size, fontWeight: FontWeight.w800, letterSpacing: sp, fontFamily: family);
    switch (L) {
      case 'classic':
        topBg = DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a, const Color(0xFFB03C8F)]),
          ),
        );
      case 'gradient':
        topBg = Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: a),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(center: Alignment.topLeft, radius: 1.3, colors: [fade(b, .85), fade(b, 0)], stops: const [0, .55]),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(center: Alignment.bottomRight, radius: 1.1, colors: [fade(c, .9), fade(c, 0)], stops: const [0, .6]),
              ),
            ),
          ],
        );
        pad = const EdgeInsets.fromLTRB(22, 22, 22, 20);
        titleSize = 19;
      case 'stub':
        topBg = const ColoredBox(color: Colors.white);
        topColor = c;
        smallColor = mixC(c, Colors.white, .75);
        kicker = Text(admit.toUpperCase(), style: kStyle(a));
        pad = const EdgeInsets.fromLTRB(18, 18, 18, 16);
      case 'pass':
        topBg = ColoredBox(color: a);
        kicker = Text(admit.toUpperCase(), style: kStyle(fade(Colors.white, .75)));
        pad = const EdgeInsets.fromLTRB(22, 18, 84, 18);
        titleSize = 21;
        upper = true;
      case 'neon':
        center = true;
        topBg = null;
        kicker = Text(
          admit.toUpperCase(),
          style: kStyle(b).copyWith(shadows: [Shadow(color: a, blurRadius: 10)]),
        );
        pad = const EdgeInsets.fromLTRB(18, 22, 18, 18);
        titleSize = 22;
        titleShadow = [Shadow(color: b, blurRadius: 6), Shadow(color: a, blurRadius: 18)];
        smallColor = const Color(0xFFB8B8C8);
      case 'retro':
        center = true;
        topBg = DecoratedBox(
          decoration: BoxDecoration(color: a, borderRadius: BorderRadius.circular(4)),
        );
        margin = const EdgeInsets.fromLTRB(22, 16, 22, 0);
        pad = const EdgeInsets.fromLTRB(12, 14, 12, 14);
        kicker = Text(
          '★ ${admit.toUpperCase()} ★',
          textAlign: TextAlign.center,
          style: kStyle(Colors.white, size: 17, sp: 4, family: 'serif').copyWith(fontWeight: FontWeight.w900),
        );
        titleSize = 16;
        italic = true;
      case 'vip':
        center = true;
        pad = const EdgeInsets.fromLTRB(22, 26, 22, 18);
        kicker = ShaderMask(
          shaderCallback: foil.createShader,
          child: Text(admit.toUpperCase(), style: kStyle(Colors.white, size: 12)),
        );
        titleSize = 21;
        foilTitle = true;
        smallColor = const Color(0xFFD6D0C0);
      case 'glass':
        topBg = DecoratedBox(
          decoration: BoxDecoration(
            color: fade(Colors.white, .42),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: fade(Colors.white, .65)),
          ),
        );
        margin = const EdgeInsets.fromLTRB(12, 12, 12, 0);
        topColor = c;
        smallColor = mixC(c, Colors.white, .8);
        titleSize = 19;
      case 'festival':
        topBg = Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _Stripes(a, mixC(a, b, .78), 16)),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [fade(c, 0), fade(c, .55)], stops: const [.4, 1]),
              ),
            ),
          ],
        );
        pad = const EdgeInsets.fromLTRB(20, 22, 20, 20);
        kicker = Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
          child: Text(admit.toUpperCase(), style: kStyle(a)),
        );
        titleSize = 23;
        titleWeight = FontWeight.w900;
        titleShadow = [Shadow(color: fade(c, .7), offset: const Offset(0, 2))];
      case 'minimal':
        topBg = const ColoredBox(color: Colors.white);
        topColor = c;
        smallColor = const Color(0xFF555555);
        kicker = Text(admit.toUpperCase(), style: kStyle(a, sp: 1.3, family: 'monospace'));
        titleSize = 24;
        pad = const EdgeInsets.fromLTRB(20, 20, 20, 14);
      case 'badge':
        center = true;
        kicker = Text(admit.toUpperCase(), style: kStyle(fade(Colors.white, .8)));
        pad = const EdgeInsets.fromLTRB(20, 36, 20, 16);
      case 'khmer':
        center = true;
        topBg = Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: c),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(center: Alignment.topCenter, radius: 1, colors: [fade(a, .7), fade(a, 0)]),
              ),
            ),
          ],
        );
        topColor = b;
        smallColor = const Color(0xFFFFF6DC);
        kicker = Text('❖  ${admit.toUpperCase()}  ❖', style: kStyle(b, sp: 3));
        pad = const EdgeInsets.fromLTRB(20, 26, 20, 18);
        titleSize = 20;
      case 'pop':
        topBg = Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a, b]),
              ),
            ),
            CustomPaint(painter: _Dots([fade(c, .6)])),
            const Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: 3,
                width: double.infinity,
                child: ColoredBox(color: Color(0xFF111111)),
              ),
            ),
          ],
        );
        smallColor = const Color(0xFF111111);
        kicker = Transform.rotate(
          angle: -.05,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE14A),
              border: Border.all(color: const Color(0xFF111111), width: 2),
            ),
            child: Text(admit.toUpperCase(), style: kStyle(const Color(0xFF111111))),
          ),
        );
        titleSize = 24;
        titleWeight = FontWeight.w900;
        upper = true;
        titleShadow = const [Shadow(color: Color(0xFF111111), offset: Offset(3, 3))];
        pad = const EdgeInsets.fromLTRB(18, 20, 18, 18);
    }
    final whenText = '${evWhen(tk['show_at'] ?? ev['starts_at'], lang, time: false)} · ${evTime(tk['show_at'] ?? ev['starts_at'])}';
    final title = str(ev['title']).isEmpty ? 'Event' : str(ev['title']);
    Widget titleW = Text(
      upper ? title.toUpperCase() : title,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        color: foilTitle ? Colors.white : topColor,
        fontSize: titleSize,
        fontWeight: titleWeight,
        fontStyle: italic ? FontStyle.italic : null,
        height: 1.15,
        shadows: titleShadow,
        fontFamily: serif,
        letterSpacing: upper ? .6 : null,
      ),
    );
    if (foilTitle) titleW = ShaderMask(shaderCallback: foil.createShader, child: titleW);
    final small = TextStyle(color: smallColor, fontSize: 12.5, fontFamily: mono ?? serif);
    final top = Container(
      margin: margin,
      child: Stack(
        children: [
          if (topBg != null)
            Positioned.fill(
              child: ClipRRect(borderRadius: L == 'retro' ? BorderRadius.circular(4) : (L == 'glass' ? BorderRadius.circular(20) : BorderRadius.zero), child: topBg),
            ),
          Padding(
            padding: pad,
            child: Column(
              crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                if (kicker != null) Padding(padding: const EdgeInsets.only(bottom: 4), child: kicker),
                titleW,
                const SizedBox(height: 3),
                Text(whenText, textAlign: center ? TextAlign.center : TextAlign.start, style: small),
                if (str(ev['venue']).isNotEmpty) Text(str(ev['venue']), textAlign: center ? TextAlign.center : TextAlign.start, style: small),
              ],
            ),
          ),
        ],
      ),
    );

    // ---- the cut line
    final notch = Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(color: pageBg, shape: BoxShape.circle),
    );
    Widget cut;
    switch (L) {
      case 'badge' || 'pop':
        cut = const SizedBox(height: 0);
      case 'glass':
        cut = const SizedBox(height: 6);
      case 'minimal':
        cut = Container(height: 1.5, color: c);
      case 'stub':
        cut = _Dash(mixC(a, Colors.white, .45), thick: 4, dash: 4, gap: 4);
      case 'retro':
        cut = Padding(padding: const EdgeInsets.fromLTRB(26, 14, 26, 0), child: _Dash(c, dash: 2, gap: 3));
      case 'khmer':
        cut = Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 0), child: _Dash(mixC(c, Colors.white, .4), dash: 2, gap: 3));
      default:
        final col = switch (L) {
          'pass' => mixC(a, Colors.white, .35),
          'neon' => fade(b, .55),
          'vip' => fade(b, .6),
          'festival' => mixC(b, Colors.white, .6),
          _ => const Color(0xFFE8E8EE),
        };
        cut = SizedBox(
          height: 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: L == 'vip' ? Container(height: 1.5, color: col) : _Dash(col, thick: L == 'festival' ? 3 : 2),
              ),
              Positioned(left: -11, top: -11, child: notch),
              Positioned(right: -11, top: -11, child: notch),
            ],
          ),
        );
    }

    // ---- the QR
    final qrBorder = switch (L) {
      'retro' => Border.all(color: c, width: 2),
      'khmer' => Border.all(color: b, width: 2),
      'pop' => Border.all(color: const Color(0xFF111111), width: 3),
      'gradient' => Border.all(color: const Color(0xFFE8E8EE)),
      _ => null,
    };
    final qrShadow = switch (L) {
      'neon' => [BoxShadow(color: fade(a, .7), blurRadius: 22)],
      'glass' => const [BoxShadow(color: Color(0x1F000000), blurRadius: 26, offset: Offset(0, 10))],
      'badge' => const [BoxShadow(color: Color(0x1F000000), blurRadius: 22, offset: Offset(0, 8))],
      _ => null,
    };
    final qrSize = math.min(width - 60, 200.0);
    final qr = Padding(
      padding: EdgeInsets.fromLTRB(18, L == 'badge' ? 0 : (L == 'pop' ? 20 : 18), 18, 6),
      child: Center(
        child: Container(
          padding: EdgeInsets.all(L == 'classic' ? 0 : 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(L == 'retro' ? 6 : (L == 'pop' ? 10 : 16)), border: qrBorder, boxShadow: qrShadow),
          child: lite
              ? SizedBox(
                  width: qrSize,
                  height: qrSize,
                  child: FittedBox(child: Icon(LucideIcons.qrCode, color: Colors.black.withValues(alpha: .85))),
                )
              : QrImageView(data: ticketUrl(tk['code']), size: qrSize, padding: EdgeInsets.zero, backgroundColor: Colors.white),
        ),
      ),
    );

    // ---- the info
    final typeName = str(tk['type_name']);
    BoxDecoration pill = BoxDecoration(color: mixC(a, Colors.white, .12), borderRadius: BorderRadius.circular(99));
    var pillText = TextStyle(color: a, fontSize: 12.5, fontWeight: FontWeight.w800, fontFamily: mono);
    var pillUpper = false;
    Gradient? pillGrad;
    switch (L) {
      case 'stub':
        pill = pill.copyWith(color: a);
        pillText = pillText.copyWith(color: Colors.white);
      case 'pass':
        pill = pill.copyWith(borderRadius: BorderRadius.circular(6));
        pillUpper = true;
      case 'neon':
        pill = BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: b, width: 1.5),
          boxShadow: [BoxShadow(color: fade(a, .6), blurRadius: 10)],
          color: const Color(0xFF0B0B14),
        );
        pillText = pillText.copyWith(color: b);
      case 'retro':
        pill = BoxDecoration(color: c, borderRadius: BorderRadius.circular(3));
        pillText = pillText.copyWith(color: const Color(0xFFFBF3E1), letterSpacing: 1.2);
        pillUpper = true;
      case 'vip':
        pillGrad = foil;
        pillText = pillText.copyWith(color: const Color(0xFF111111), letterSpacing: 1.4);
        pillUpper = true;
      case 'festival':
        pill = pill.copyWith(color: b);
        pillText = pillText.copyWith(color: c);
      case 'minimal':
        pill = BoxDecoration(border: Border.all(color: a, width: 1.5));
        pillUpper = true;
      case 'badge':
        pill = pill.copyWith(color: c);
        pillText = pillText.copyWith(color: Colors.white);
      case 'khmer':
        pill = pill.copyWith(color: c);
        pillText = pillText.copyWith(color: b);
      case 'pop':
        pill = BoxDecoration(
          color: b,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: const Color(0xFF111111), width: 2),
        );
        pillText = pillText.copyWith(color: const Color(0xFF111111));
    }
    final typePill = Container(
      padding: EdgeInsets.symmetric(horizontal: L == 'badge' ? 16 : 12, vertical: L == 'badge' ? 5 : 4),
      decoration: pillGrad == null ? pill : BoxDecoration(gradient: pillGrad, borderRadius: BorderRadius.circular(99)),
      child: Text(pillUpper ? typeName.toUpperCase() : typeName, style: pillText),
    );
    final holderStyle = TextStyle(
      fontSize: L == 'badge' ? 24 : 17,
      fontWeight: L == 'badge' ? FontWeight.w900 : FontWeight.w800,
      color: L == 'badge' || L == 'khmer' ? c : infoInk,
      fontFamily: serif,
      height: 1.15,
    );
    final seat = str(tk['seat_label']);
    final infoCol = Column(
      children: [
        if (L != 'badge') typePill,
        if (seat.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              '💺 $seat',
              style: TextStyle(fontWeight: FontWeight.w800, color: infoInk),
            ),
          ),
        const SizedBox(height: 3),
        Text(str(tk['holder']), textAlign: TextAlign.center, style: holderStyle),
        if (L == 'badge') Padding(padding: const EdgeInsets.only(top: 4), child: typePill),
        const SizedBox(height: 3),
        Text(
          str(tk['code']),
          style: TextStyle(fontSize: 12.5, letterSpacing: 1, color: infoMuted, fontFamily: mono ?? 'monospace'),
        ),
        Text(
          t('evp.showAtDoor'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: infoMuted, fontFamily: serif),
        ),
      ],
    );
    final info = L == 'glass'
        ? Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: fade(Colors.white, .42),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: fade(Colors.white, .65)),
            ),
            child: infoCol,
          )
        : Padding(padding: EdgeInsets.fromLTRB(18, 0, 18, ['retro', 'khmer', 'festival'].contains(L) ? 26 : (L == 'pass' ? 20 : 16)), child: infoCol);

    // ---- decorations over / under
    final under = <Widget>[
      if (L == 'glass') ...[
        Positioned(left: -40, top: -30, child: _Blob(b, 200)),
        Positioned(right: -60, top: 60, child: _Blob(fade(a, .8), 220)),
        Positioned(left: -30, bottom: -50, child: _Blob(fade(c, .7), 240)),
      ],
      if (L == 'badge') ...[
        Positioned(left: 0, right: 0, top: 0, height: 150, child: ColoredBox(color: a)),
        Positioned(
          right: -30,
          top: 0,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(shape: BoxShape.circle, color: fade(b, .45)),
          ),
        ),
      ],
    ];
    final over = <Widget>[
      if (L == 'pass') ...[
        Positioned(
          right: 18,
          top: 20,
          child: SizedBox(
            width: 52,
            height: 46,
            child: Opacity(opacity: .55, child: CustomPaint(painter: _Barcode(Colors.white))),
          ),
        ),
        Positioned(
          left: 22,
          right: 22,
          bottom: 12,
          child: Container(
            height: 4,
            decoration: BoxDecoration(color: fade(a, .25), borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ],
      if (L == 'retro') ...[
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: fade(c, .6), width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
        Positioned(left: -5, top: 0, bottom: 0, child: _Scallops(pageBg)),
        Positioned(right: -5, top: 0, bottom: 0, child: _Scallops(pageBg)),
      ],
      if (L == 'vip') ...[
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _FoilBorder(foil, radius))),
        ),
        Positioned(left: 10, top: 10, child: _Corner(b, left: true)),
        Positioned(right: 10, top: 10, child: _Corner(b, left: false)),
      ],
      if (L == 'festival') Positioned(left: 0, right: 0, bottom: 0, height: 12, child: CustomPaint(painter: _Stripes(a, b, 10))),
      if (L == 'badge')
        Positioned(
          left: 0,
          right: 0,
          top: 12,
          child: Center(
            child: Container(
              width: 58,
              height: 11,
              decoration: BoxDecoration(color: pageBg, borderRadius: BorderRadius.circular(99)),
            ),
          ),
        ),
      if (L == 'khmer') ...[
        Positioned(left: 0, right: 0, top: 0, height: 10, child: CustomPaint(painter: _Kbach(b))),
        Positioned(left: 0, right: 0, bottom: 0, height: 10, child: CustomPaint(painter: _Kbach(b))),
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                border: Border.all(color: b, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    ];
    return Container(
      width: width,
      decoration: BoxDecoration(color: cardColor, gradient: cardGrad, borderRadius: BorderRadius.circular(radius), border: border, boxShadow: shadow),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          ...under,
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [top, cut, qr, info]),
          ...over,
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob(this.color, this.size);
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, fade(color, 0)]),
    ),
  );
}

class _Scallops extends StatelessWidget {
  final Color color;
  const _Scallops(this.color);
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 11,
    child: LayoutBuilder(
      builder: (_, box) => Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < (box.maxHeight / 17).floor(); i++)
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
        ],
      ),
    ),
  );
}

class _Corner extends StatelessWidget {
  final Color color;
  final bool left;
  const _Corner(this.color, {required this.left});
  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: fade(color, .85), width: 2),
        left: left ? BorderSide(color: fade(color, .85), width: 2) : BorderSide.none,
        right: left ? BorderSide.none : BorderSide(color: fade(color, .85), width: 2),
      ),
    ),
  );
}

class _FoilBorder extends CustomPainter {
  final Gradient foil;
  final double radius;
  const _FoilBorder(this.foil, this.radius);
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius((Offset.zero & size).deflate(.75), Radius.circular(radius));
    canvas.drawRRect(
      r,
      Paint()
        ..shader = foil.createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_FoilBorder o) => false;
}

// ============================================================ the event page in one design (a phone-sized copy)
class EvPagePreview extends StatefulWidget {
  final Json ev, org;
  final String theme;
  final Json? colors;
  final T t;
  final bool animate; // live designs move (only in the big preview)
  const EvPagePreview({super.key, required this.ev, required this.org, required this.theme, required this.t, this.colors, this.animate = false});
  @override
  State<EvPagePreview> createState() => _EvPagePreviewState();
}

class _EvPagePreviewState extends State<EvPagePreview> with SingleTickerProviderStateMixin {
  AnimationController? _a;
  @override
  void initState() {
    super.initState();
    if (widget.animate) _a = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  }

  @override
  void dispose() {
    _a?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_a == null) return _page(0);
    return AnimatedBuilder(animation: _a!, builder: (_, _) => _page(_a!.value));
  }

  Widget _page(double tt) {
    final w = widget;
    final t = w.t;
    final th = pageThemeOf(w.theme);
    final L = th.layout;
    final ev = w.ev;
    final lang = t.lang;
    // standard: the ticket design's accent (or the owner's own colour)
    late Color a, b, c;
    if (L == 'standard') {
      final tt0 = ticketThemeOf(ev['theme']);
      final own = w.colors ?? obj(ev['page_colors']);
      final tOwn = obj(ev['theme_colors']);
      if (_isHex(own['a'])) {
        a = evHex(own['a']);
        b = _isHex(own['b']) ? evHex(own['b']) : a;
      } else if (tt0.layout != 'classic' || _isHex(tOwn['a'])) {
        a = _isHex(tOwn['a']) ? evHex(tOwn['a']) : tt0.a;
        b = _isHex(tOwn['b']) ? evHex(tOwn['b']) : (tt0.palette == 'mono' ? const Color(0xFF52525B) : tt0.b);
      } else {
        a = const Color(0xFFF0662B);
        b = const Color(0xFFFF9A3C);
      }
      c = const Color(0xFF7C2D12);
    } else {
      (a, b, c) = lookColors(th, w.colors);
    }
    final accent = a;
    final accent2 = L == 'standard' ? b : (th.palette == 'graphite' && !_isHex(w.colors?['b']) ? const Color(0xFF64748B) : b);
    // page colours
    var bg = const Color(0xFFF5F4F7), card = Colors.white, ink = const Color(0xFF16161D), muted = const Color(0xFF6B6B78), line = const Color(0xFFE8E8EE);
    switch (L) {
      case 'aurora':
        (bg, card, ink, muted, line) = (const Color(0xFF0A0A12), fade(Colors.white, .06), const Color(0xFFF5F5FB), const Color(0xFFA6A6BD), fade(Colors.white, .13));
      case 'editorial':
        (bg, card, ink, muted, line) = (const Color(0xFFF6F1E7), const Color(0xFFFFFDF8), const Color(0xFF1F1A14), const Color(0xFF6F665A), const Color(0xFFE3D9C8));
      case 'bold':
        (bg, card, ink, muted, line) = (mixC(b, Colors.white, .22), Colors.white, const Color(0xFF111111), const Color(0xFF555555), const Color(0xFF111111));
      case 'midnight':
        (bg, card, ink, muted, line) = (const Color(0xFF0D1020), const Color(0xFF161A2E), const Color(0xFFEEF0FF), const Color(0xFF9CA3C7), const Color(0xFF272C48));
      case 'pastel':
        (bg, card, ink, muted, line) = (mixC(b, Colors.white, .26), Colors.white, mixC(c, Colors.black, .85), mixC(c, const Color(0xFF8A8A8A), .55), mixC(b, Colors.white, .6));
      case 'cinema':
        (bg, card, ink, muted, line) = (const Color(0xFF0C0C0F), const Color(0xFF17171C), const Color(0xFFF6F6F7), const Color(0xFFA1A1AA), const Color(0xFF2A2A31));
      case 'live-glow':
        (bg, card, ink, muted, line) = (const Color(0xFF08080F), fade(Colors.white, .07), const Color(0xFFF7F7FC), const Color(0xFFB0B0C6), fade(Colors.white, .14));
      case 'live-confetti':
        (bg, card, ink, muted, line) = (mixC(b, Colors.white, .18), fade(Colors.white, .92), const Color(0xFF17151C), const Color(0xFF6B6676), mixC(b, Colors.white, .55));
      case 'live-stars':
        (bg, card, ink, muted, line) = (const Color(0xFF070A1A), const Color(0xD112162E), const Color(0xFFF1F3FF), const Color(0xFFA2A8CC), fade(Colors.white, .12));
      case 'live-waves':
        (bg, card, ink, muted, line) = (mixC(b, Colors.white, .14), Colors.white, mixC(c, Colors.black, .88), mixC(c, const Color(0xFF8A8A8A), .5), mixC(b, Colors.white, .5));
      case 'live-flow':
        (bg, card, ink, muted, line) = (const Color(0xFFF7F6FA), Colors.white, const Color(0xFF16151C), const Color(0xFF67646F), const Color(0xFFEBE9F0));
      case 'live-stage':
        (bg, card, ink, muted, line) = (const Color(0xFF0B0A0E), const Color(0xFF17151C), const Color(0xFFF8F7FA), const Color(0xFFA9A5B4), const Color(0xFF2A2731));
    }
    final dark = _pDark.contains(L);
    final serif = L == 'editorial' ? 'serif' : null;
    final poster = str(ev['poster']);
    // ---- hero
    var heroInk = Colors.white;
    Widget heroBg = const ColoredBox(color: Color(0xFF121218));
    switch (L) {
      case 'aurora' || 'live-glow' || 'live-stars' || 'live-stage' || 'live-confetti':
        heroBg = const SizedBox.shrink();
        if (L == 'live-confetti') heroInk = ink;
      case 'editorial':
        heroBg = ColoredBox(color: bg);
        heroInk = ink;
      case 'bold':
        heroBg = ColoredBox(color: a);
      case 'midnight':
        heroBg = DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [mixC(c, bg, .75), bg]),
          ),
        );
      case 'pastel':
        heroBg = DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [mixC(b, Colors.white, .75), bg]),
          ),
        );
        heroInk = ink;
      case 'cinema':
        heroBg = Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a, c]),
              ),
            ),
            if (poster.isNotEmpty)
              Opacity(
                opacity: .75,
                child: Image(image: netImage(poster), fit: BoxFit.cover),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [fade(bg, .1), fade(bg, .35), bg], stops: const [0, .45, 1]),
              ),
            ),
          ],
        );
      case 'live-waves':
        heroBg = DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a, c]),
          ),
        );
      case 'live-flow':
        heroBg = DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment(-1 + 2 * math.sin(tt * math.pi), -1), end: Alignment(1 + 2 * math.sin(tt * math.pi), 1), colors: [a, c, b, a], tileMode: TileMode.mirror),
          ),
        );
    }
    final titleSize = ['bold', 'cinema', 'editorial'].contains(L) ? 34.0 : 28.0;
    final title = str(ev['title']).isEmpty ? (str(w.org['name']).isEmpty ? 'Event' : str(w.org['name'])) : str(ev['title']);
    final titleStyle = TextStyle(
      fontSize: titleSize,
      height: 1.05,
      fontWeight: ['bold', 'cinema', 'live-flow', 'live-confetti'].contains(L) ? FontWeight.w900 : FontWeight.w800,
      color: L == 'live-confetti' ? c : heroInk,
      fontFamily: serif,
      shadows: switch (L) {
        'bold' => const [Shadow(color: Color(0xFF111111), offset: Offset(3, 3))],
        'midnight' || 'live-stage' => [Shadow(color: fade(a, .7), blurRadius: 24)],
        'live-stars' => [Shadow(color: fade(b, .7), blurRadius: 24)],
        _ => null,
      },
    );
    final upper = L == 'bold' || L == 'live-stage';
    Widget titleW = Text(upper ? title.toUpperCase() : title, style: titleStyle);
    if (L == 'aurora') {
      titleW = ShaderMask(
        shaderCallback: LinearGradient(colors: [Colors.white, b]).createShader,
        child: titleW,
      );
    }
    final posterBox = L == 'cinema'
        ? const SizedBox.shrink()
        : Center(
            child: Transform.rotate(
              angle: switch (L) {
                'bold' => -.035,
                'pastel' => .05,
                'live-confetti' => -.035,
                _ => 0,
              },
              child: Container(
                width: 170,
                height: 226,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(switch (L) {
                    'editorial' => 2,
                    'bold' => 6,
                    'pastel' => 28,
                    'live-confetti' => 20,
                    'live-flow' => 22,
                    _ => 18,
                  }),
                  border: switch (L) {
                    'bold' => Border.all(color: const Color(0xFF111111), width: 4),
                    'pastel' || 'live-confetti' => Border.all(color: Colors.white, width: 6),
                    _ => null,
                  },
                  gradient: poster.isEmpty ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [accent, const Color(0xFF7C3AED)]) : null,
                  image: poster.isNotEmpty ? DecorationImage(image: netImage(poster), fit: BoxFit.cover) : null,
                  boxShadow: switch (L) {
                    'editorial' => [BoxShadow(color: b, offset: const Offset(10, 10))],
                    'bold' => const [BoxShadow(color: Color(0xFF111111), offset: Offset(10, 10))],
                    'midnight' => [BoxShadow(color: fade(a, .5), blurRadius: 50, spreadRadius: 2)],
                    'aurora' || 'live-glow' => [BoxShadow(color: fade(a, .5), blurRadius: 60)],
                    _ => const [BoxShadow(color: Color(0x80000000), blurRadius: 40, offset: Offset(0, 20))],
                  },
                ),
                child: poster.isEmpty ? const Icon(LucideIcons.ticket, size: 40, color: Colors.white) : null,
              ),
            ),
          );
    final factStyle = TextStyle(color: fade(heroInk, .95), fontSize: 13.5);
    Widget fact(IconData i, String s) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(i, size: 15, color: heroInk),
          const SizedBox(width: 8),
          Expanded(
            child: Text(s, style: factStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
    final start = ev['starts_at'] ?? DateTime.now().toIso8601String();
    final hero = Stack(
      children: [
        Positioned.fill(child: heroBg),
        if (poster.isNotEmpty && !['editorial', 'bold', 'pastel', 'cinema', 'live-confetti'].contains(L))
          Positioned.fill(
            child: Opacity(
              opacity: .3,
              child: Image(image: netImage(poster), fit: BoxFit.cover, color: Colors.black26, colorBlendMode: BlendMode.darken),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, L == 'cinema' ? 210 : 50, 16, L == 'live-waves' ? 46 : 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              posterBox,
              if (L != 'cinema') const SizedBox(height: 16),
              if (L == 'editorial')
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(width: 56, height: 5, margin: const EdgeInsets.only(bottom: 14), color: a),
                ),
              titleW,
              if (L == 'cinema')
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 80,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(color: a, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              const SizedBox(height: 12),
              fact(LucideIcons.calendarDays, evWhen(start, lang, time: false)),
              fact(LucideIcons.clock, evTime(start)),
              if (str(ev['venue']).isNotEmpty) fact(LucideIcons.mapPin, str(ev['venue'])),
              if (str(w.org['name']).isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.fromLTRB(12, 6, 14, 6),
                    decoration: BoxDecoration(
                      color: switch (L) {
                        'editorial' => const Color(0x0D000000),
                        'bold' => const Color(0xFF111111),
                        'pastel' => fade(Colors.white, .7),
                        'live-confetti' => fade(Colors.white, .85),
                        _ => fade(Colors.white, .14),
                      },
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      t('evp.by', {'name': w.org['name']}),
                      style: TextStyle(color: L == 'bold' ? Colors.white : heroInk, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (L == 'live-waves') Positioned(left: 0, right: 0, bottom: -1, height: 30, child: CustomPaint(painter: _Waves(bg, tt))),
      ],
    );
    // ---- ticket types
    final types0 = objs(ev['types']).where((x) => x['active'] != false).take(2).toList();
    final types = types0.isEmpty
        ? [
            {'name': 'Standard', 'price': 10, 'left': 80},
            {'name': 'VIP', 'price': 25, 'left': 6},
          ]
        : types0;
    final free = ev['kind'] == 'free';
    final cardRadius = switch (L) {
      'editorial' => 4.0,
      'bold' => 14.0,
      'pastel' => 30.0,
      'live-confetti' => 26.0,
      'live-waves' => 24.0,
      _ => 22.0,
    };
    final typeRadius = switch (L) {
      'editorial' => 4.0,
      'bold' => 10.0,
      'pastel' => 22.0,
      _ => 18.0,
    };
    String money(Object? v) => free || n(v) == 0 ? t('evp.free') : usd2(v);
    final cardW = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(cardRadius),
        border: L == 'bold' ? Border.all(color: const Color(0xFF111111), width: 2.5) : (dark || L == 'editorial' ? Border.all(color: line) : null),
        boxShadow: L == 'bold'
            ? const [BoxShadow(color: Color(0xFF111111), offset: Offset(6, 6))]
            : (L == 'editorial' ? null : const [BoxShadow(color: Color(0x0F141428), blurRadius: 24, offset: Offset(0, 8))]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            free ? t('evp.register') : t('evp.pick'),
            style: TextStyle(color: ink, fontSize: 19, fontWeight: FontWeight.w800, fontFamily: serif),
          ),
          const SizedBox(height: 12),
          for (final (i, x) in types.indexed)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(typeRadius),
                border: Border.all(color: i == 0 ? (L == 'bold' ? const Color(0xFF111111) : accent) : (L == 'bold' ? const Color(0xFF111111) : line), width: L == 'bold' ? 2 : 1.5),
                color: i == 0 ? (L == 'bold' ? b : (dark ? fade(accent, .16) : mixC(accent, Colors.white, .05))) : null,
                boxShadow: i == 0 && L == 'midnight' ? [BoxShadow(color: fade(a, .4), blurRadius: 22)] : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          str(x['name']),
                          style: TextStyle(color: ink, fontWeight: FontWeight.w800),
                        ),
                        Text(t('evp.left', {'n': x['left'] ?? 50}), style: TextStyle(color: muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        money(x['price']),
                        style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(color: dark ? fade(Colors.white, .06) : bg, borderRadius: BorderRadius.circular(99)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.minus, size: 13, color: ink),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                i == 0 ? '2' : '0',
                                style: TextStyle(color: ink, fontWeight: FontWeight.w800),
                              ),
                            ),
                            Icon(LucideIcons.plus, size: 13, color: ink),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    // ---- the bar
    final barRadius = switch (L) {
      'editorial' => 6.0,
      'pastel' => 99.0,
      'bold' => 16.0,
      _ => 22.0,
    };
    final btnRadius = switch (L) {
      'editorial' => 4.0,
      'bold' => 12.0,
      'pastel' || 'live-confetti' || 'live-waves' => 99.0,
      'cinema' => 10.0,
      _ => 16.0,
    };
    final bar = Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
      decoration: BoxDecoration(
        color: switch (L) {
          'editorial' || 'pastel' => ink,
          _ when dark => mixC(Color.alphaBlend(card, bg), Colors.black, .7),
          _ => const Color(0xFF16161D),
        },
        borderRadius: BorderRadius.circular(barRadius),
        border: L == 'bold' ? Border.all(color: const Color(0xFF111111), width: 2.5) : (dark ? Border.all(color: line) : null),
        boxShadow: L == 'bold' ? const [BoxShadow(color: Color(0xFF111111), offset: Offset(6, 6))] : const [BoxShadow(color: Color(0x59000000), blurRadius: 30, offset: Offset(0, 14))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('evp.ticketsN', {'n': 2}), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(
                  money(n(types.first['price']) * 2),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: L == 'editorial' ? c : (L == 'bold' ? a : null),
              gradient: L == 'editorial' || L == 'bold'
                  ? null
                  : LinearGradient(colors: L == 'live-flow' ? [a, c, a] : [accent, accent2], begin: Alignment(-1 + 2 * tt, 0), end: Alignment(1 + 2 * tt, 0), tileMode: TileMode.mirror),
              borderRadius: BorderRadius.circular(btnRadius),
              border: L == 'bold' ? Border.all(color: const Color(0xFF111111), width: 2.5) : null,
              boxShadow: L == 'midnight' ? [BoxShadow(color: fade(a, .55), blurRadius: 26)] : null,
            ),
            child: Text(
              t('evp.continue'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    // ---- the page background (and the moving layer of live designs)
    final back = <Widget>[
      ColoredBox(color: bg),
      if (L == 'aurora') ...[
        Positioned(left: -60, top: -40, child: _Blob(fade(a, .5), 320)),
        Positioned(right: -80, top: 10, child: _Blob(fade(b, .38), 260)),
        Positioned(left: 0, right: 0, bottom: -100, child: Center(child: _Blob(fade(c, .75), 460))),
      ],
      if (L == 'live-glow') ...[
        Positioned(left: -40 + 40 * math.sin(tt * 2 * math.pi), top: -30 + 30 * math.cos(tt * 2 * math.pi), child: _Blob(fade(a, .75), 300)),
        Positioned(right: -60 + 30 * math.cos(tt * 2 * math.pi), top: 180, child: _Blob(fade(b, .55), 260)),
        Positioned(left: 40 - 30 * math.sin(tt * 2 * math.pi), bottom: -60, child: _Blob(fade(c, .9), 340)),
      ],
      if (L == 'live-stars') ...[
        Positioned(left: -40, right: -40, top: -60, child: _Blob(fade(c, .7), 420)),
        Positioned(right: -80, bottom: -80, child: _Blob(fade(a, .3), 320)),
        Positioned.fill(
          child: Opacity(
            opacity: .5 + .5 * math.sin(tt * 2 * math.pi * 3).abs(),
            child: CustomPaint(painter: _Dots([Colors.white, b], gap: 34, r: 1.1, random: true, seed: 7, t: tt * .2)),
          ),
        ),
      ],
      if (L == 'live-confetti')
        Positioned.fill(
          child: Opacity(
            opacity: .8,
            child: CustomPaint(painter: _Dots([a, b, c, const Color(0xFFFACC15)], gap: 44, r: 3, random: true, seed: 3, t: tt)),
          ),
        ),
      if (L == 'live-stage') ...[
        Positioned.fill(child: CustomPaint(painter: _Beam(fade(a, .55), .3, -.28 + .6 * math.sin(tt * 2 * math.pi)))),
        Positioned.fill(child: CustomPaint(painter: _Beam(fade(b, .45), .7, .3 - .6 * math.sin(tt * 2 * math.pi)))),
      ],
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        width: 360,
        height: 760,
        child: Stack(
          children: [
            ...back.map((x) => x is Positioned ? x : Positioned.fill(child: x)),
            SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: switch (L) {
                        'editorial' => Border(bottom: BorderSide(color: ink)),
                        'bold' => const Border(bottom: BorderSide(color: Color(0xFF111111), width: 4)),
                        _ => null,
                      },
                    ),
                    child: hero,
                  ),
                  Padding(padding: const EdgeInsets.fromLTRB(12, 14, 12, 12), child: cardW),
                ],
              ),
            ),
            Positioned(left: 0, right: 0, bottom: 0, child: bar),
          ],
        ),
      ),
    );
  }
}

class _Waves extends CustomPainter {
  final Color color;
  final double t;
  const _Waves(this.color, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    for (final (w, alpha, shift) in [(140.0, .45, -t), (96.0, 1.0, t)]) {
      final p = Paint()..color = color.withValues(alpha: alpha);
      final path = Path()..moveTo(0, size.height);
      final off = (shift * w * 4) % w;
      for (double x = -w + off; x < size.width + w; x += w) {
        path.quadraticBezierTo(x + w / 2, alpha < 1 ? 0 : 6, x + w, size.height * .55);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_Waves o) => o.t != t;
}

// a stage light from the top
class _Beam extends CustomPainter {
  final Color color;
  final double x, angle;
  const _Beam(this.color, this.x, this.angle);
  @override
  void paint(Canvas canvas, Size size) {
    final o = Offset(size.width * x, 0);
    canvas.save();
    canvas.translate(o.dx, o.dy);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(-60, size.height * 1.2)
      ..lineTo(60, size.height * 1.2)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color, color.withValues(alpha: 0)]).createShader(Rect.fromLTWH(-60, 0, 120, size.height))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Beam o) => o.angle != angle || o.color != color;
}

// ============================================================ a certificate (A4 landscape, scaled to fit)
class EvCertView extends StatelessWidget {
  final Json cert; // { title, body, signer, signer_title, design, signature }
  final String name, code;
  final Json ev, org;
  final List<Json> sponsors;
  final bool thumb;
  const EvCertView({super.key, required this.cert, required this.name, required this.ev, required this.org, this.code = '', this.sponsors = const [], this.thumb = false});

  static const W = 1123.0, H = 794.0;
  // corners / diamonds / the medal sit over the paper (z-index 2 on the web)
  static const _decoOnTop = {'ornate', 'kbach', 'medal'};

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: W / H,
    child: FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(width: W, height: H, child: _sheet()),
    ),
  );

  Widget _sheet() {
    final key = str(cert['design']).isEmpty ? 'classic' : str(cert['design']);
    final parts = key.split('-');
    final pal = parts.length > 1 ? _certPal.where((x) => x.$1 == parts[1]).firstOrNull : null;
    final layout = pal == null ? key : parts.first;
    final c1 = pal == null ? null : _c(pal.$4), c2 = pal == null ? null : _c(pal.$5), bg = pal == null ? null : _c(pal.$6);
    // the colours of the free designs
    final (main, gold, paper) = switch (layout) {
      'classic' => (const Color(0xFF1E3A8A), const Color(0xFFC9A227), const Color(0xFFFFFDF7)),
      'modern' => (const Color(0xFF0F766E), const Color(0xFF14B8A6), Colors.white),
      'royal' => (const Color(0xFF7A1530), const Color(0xFFD4AF37), const Color(0xFFFFFAF0)),
      _ => (c1 ?? const Color(0xFF1E3A8A), c2 ?? const Color(0xFFC9A227), bg ?? const Color(0xFFFFFDF7)),
    };
    final sans = ['modern', 'band', 'geo', 'minimal'].contains(layout);
    final family = sans ? null : 'serif';
    final night = layout == 'night';
    final left = ['modern', 'band', 'minimal'].contains(layout);
    final ink = night ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937);
    final soft = night ? const Color(0xFFCBD5E1) : const Color(0xFF6B7280);
    final date = _date(ev['starts_at']);
    final body = str(cert['body']).isEmpty ? 'This is to certify that {name} attended {event} on {date}.' : str(cert['body']);
    final text = body.replaceAll('{name}', name).replaceAll('{event}', str(ev['title'])).replaceAll('{date}', date).replaceAll('{venue}', str(ev['venue']));
    final logo = str(org['logo']);
    final sig = str(cert['signature']);
    final nameColor = switch (layout) {
      'band' || 'modern' || 'minimal' => const Color(0xFF111827),
      'night' => Colors.white,
      _ => main,
    };
    final titleText = str(cert['title']).isEmpty ? 'Certificate of Attendance' : str(cert['title']);
    final titleStyle = TextStyle(
      fontFamily: family,
      fontSize: switch (layout) {
        'modern' || 'band' => 46,
        'geo' => 44,
        'minimal' => 26,
        _ => 50,
      },
      fontWeight: switch (layout) {
        'modern' || 'band' || 'geo' => FontWeight.w800,
        'minimal' => FontWeight.w600,
        _ => FontWeight.w700,
      },
      letterSpacing: switch (layout) {
        'minimal' => 6,
        'geo' => 3,
        'modern' || 'band' || 'royal' || 'ornate' => 1.5,
        _ => 0,
      },
      color: layout == 'minimal' ? const Color(0xFF6B7280) : (night ? gold : main),
      height: 1.1,
    );
    final upperTitle = ['modern', 'band', 'geo', 'minimal'].contains(layout);
    final orgW = Text(
      str(org['name']).toUpperCase(),
      style: TextStyle(fontSize: 17, letterSpacing: 3, fontWeight: FontWeight.w600, color: layout == 'wave' ? Colors.white : (layout == 'classic' ? const Color(0xFFA37F12) : (night ? gold : main))),
    );
    final logoW = logo.isNotEmpty
        ? SizedBox(
            height: layout == 'medal' ? 54 : 70,
            child: Image(image: netImage(logo), fit: BoxFit.contain, color: layout == 'medal' ? Colors.white : null, colorBlendMode: layout == 'medal' ? BlendMode.srcIn : null),
          )
        : Icon(LucideIcons.award, size: 54, color: layout == 'wave' || layout == 'medal' ? Colors.white : (night ? gold : main));
    final top = layout == 'medal'
        ? logoW
        : (left ? Row(mainAxisSize: MainAxisSize.min, children: [logoW, const SizedBox(width: 14), orgW]) : Column(mainAxisSize: MainAxisSize.min, children: [logoW, const SizedBox(height: 8), orgW]));
    final seal = layout == 'medal'
        ? const SizedBox(width: 96)
        : Transform.rotate(
            angle: layout == 'geo' ? math.pi / 4 : 0,
            child: Container(
              width: layout == 'minimal' ? 64 : 96,
              height: layout == 'minimal' ? 64 : 96,
              decoration: BoxDecoration(
                shape: ['modern', 'band', 'geo'].contains(layout) ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: ['modern', 'band', 'geo'].contains(layout) ? BorderRadius.circular(layout == 'geo' ? 18 : 22) : null,
                color: ['modern', 'band'].contains(layout) ? main : (layout == 'minimal' ? Colors.transparent : null),
                gradient: ['modern', 'band', 'minimal'].contains(layout)
                    ? null
                    : RadialGradient(
                        center: const Alignment(-.3, -.4),
                        colors: layout == 'classic' ? const [Color(0xFFF5D76E), Color(0xFFB8860B)] : (layout == 'royal' ? const [Color(0xFFA3243F), Color(0xFF5C0F22)] : [gold, main]),
                      ),
                border: layout == 'minimal' ? Border.all(color: main, width: 2) : null,
                boxShadow: ['modern', 'band', 'minimal'].contains(layout)
                    ? null
                    : [BoxShadow(color: night ? const Color(0xFF0B0F1A) : paper, spreadRadius: 5), BoxShadow(color: gold, spreadRadius: 7)],
              ),
              child: Transform.rotate(
                angle: layout == 'geo' ? -math.pi / 4 : 0,
                child: Icon(LucideIcons.award, size: layout == 'minimal' ? 32 : 46, color: layout == 'minimal' ? main : Colors.white),
              ),
            ),
          );
    final foot = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 260,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (sig.isNotEmpty)
                    SizedBox(
                      height: 64,
                      child: Image(image: netImage(sig), fit: BoxFit.contain, color: night ? Colors.white : null, colorBlendMode: night ? BlendMode.srcIn : null),
                    )
                  else
                    const SizedBox(height: 30),
                  Container(width: 240, height: 1.5, color: night ? gold : const Color(0xFF374151), margin: const EdgeInsets.only(bottom: 8)),
                  Text(
                    str(cert['signer']).isNotEmpty ? str(cert['signer']) : str(org['name']),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink),
                  ),
                  if (str(cert['signer_title']).isNotEmpty) Text(str(cert['signer_title']), style: TextStyle(fontSize: 13, color: soft)),
                ],
              ),
            ),
          ),
        ),
        seal,
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: layout == 'geo' ? const EdgeInsets.all(6) : EdgeInsets.zero,
              decoration: layout == 'geo' ? BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)) : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    color: Colors.white,
                    padding: night ? const EdgeInsets.all(4) : EdgeInsets.zero,
                    child: thumb
                        ? const ColoredBox(color: Color(0xFFF3F4F6))
                        : QrImageView(data: '${ticketUrl('x').replaceFirst('/ev/t/x', '/ev/c/')}${code.isEmpty ? 'AB12CD34' : code}', padding: EdgeInsets.zero, backgroundColor: Colors.white),
                  ),
                  const SizedBox(height: 3),
                  Text('No. ${code.isEmpty ? 'XXXXXXXX' : code}', style: TextStyle(fontSize: 11, color: soft)),
                  Text(date, style: TextStyle(fontSize: 11, color: soft)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    final framePad = switch (layout) {
      'modern' || 'band' => const EdgeInsets.fromLTRB(120, 60, 90, 46),
      'minimal' => const EdgeInsets.fromLTRB(70, 70, 70, 40),
      'wave' => const EdgeInsets.fromLTRB(90, 26, 90, 70),
      'medal' => const EdgeInsets.fromLTRB(70, 140, 70, 36),
      _ => const EdgeInsets.fromLTRB(70, 44, 70, 36),
    };
    final content = Padding(
      padding: framePad,
      child: Column(
        crossAxisAlignment: left ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          if (layout != 'medal') top,
          SizedBox(
            height: switch (layout) {
              'minimal' => 40,
              'wave' => 64,
              'medal' => 40,
              _ => 22,
            },
          ),
          Text(upperTitle ? titleText.toUpperCase() : titleText, textAlign: left ? TextAlign.left : TextAlign.center, style: titleStyle),
          const SizedBox(height: 16),
          Text(
            'This certificate is proudly presented to',
            style: TextStyle(fontSize: layout == 'minimal' ? 15 : 18, fontStyle: sans ? null : FontStyle.italic, color: soft, fontFamily: family),
          ),
          const SizedBox(height: 6),
          Container(
            constraints: BoxConstraints(minWidth: left || layout == 'minimal' ? 0 : 520),
            padding: EdgeInsets.fromLTRB(left ? 0 : 40, 4, left ? 0 : 40, 10),
            decoration: BoxDecoration(
              border: layout == 'minimal'
                  ? null
                  : Border(
                      bottom: BorderSide(color: gold, width: left ? 4 : 2),
                    ),
            ),
            child: Text(
              name.isEmpty ? 'Guest name' : name,
              textAlign: left ? TextAlign.left : TextAlign.center,
              style: TextStyle(
                fontSize: layout == 'minimal' ? 64 : (left ? 52 : 54),
                height: 1.15,
                color: nameColor,
                fontFamily: sans ? null : 'serif',
                fontStyle: sans ? null : FontStyle.italic,
                fontWeight: switch (layout) {
                  'minimal' => FontWeight.w300,
                  'modern' || 'band' => FontWeight.w800,
                  'geo' => FontWeight.w700,
                  _ => FontWeight.w400,
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Text(
              text,
              textAlign: left ? TextAlign.left : TextAlign.center,
              style: TextStyle(fontSize: 19, height: 1.55, color: layout == 'minimal' ? soft : (night ? soft : const Color(0xFF374151)), fontFamily: family),
            ),
          ),
          const Spacer(),
          if (sponsors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final s in sponsors.take(8))
                    if (str(s['logo']).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        child: SizedBox(
                          height: 34,
                          width: 110,
                          child: Image(image: netImage(str(s['logo'])), fit: BoxFit.contain),
                        ),
                      ),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.only(bottom: layout == 'wave' ? 20 : 0),
            child: foot,
          ),
        ],
      ),
    );
    // the frame around the content
    BoxDecoration? frameDeco;
    var sheetPad = const EdgeInsets.all(34);
    Widget? sheetBack;
    var sheetColor = paper;
    switch (layout) {
      case 'classic' || 'frame':
        frameDeco = BoxDecoration(border: Border.all(color: main, width: 3));
      case 'modern' || 'band':
        sheetPad = EdgeInsets.zero;
        sheetColor = layout == 'modern' ? Colors.white : paper;
      case 'royal' || 'ornate':
        sheetColor = layout == 'royal' ? const Color(0xFF4A0D1F) : main;
        sheetPad = const EdgeInsets.all(26);
        frameDeco = BoxDecoration(
          color: paper,
          border: Border.all(color: gold, width: 2),
        );
      case 'ribbon':
        frameDeco = BoxDecoration(border: Border.all(color: gold, width: 1.5));
      case 'wave':
        sheetPad = EdgeInsets.zero;
      case 'minimal':
        sheetColor = Colors.white;
      case 'kbach':
        sheetPad = const EdgeInsets.all(30);
        sheetBack = CustomPaint(painter: _Stripes(main, gold, 8));
        frameDeco = BoxDecoration(
          color: paper,
          border: Border.all(color: gold, width: 3),
        );
      case 'medal':
        frameDeco = BoxDecoration(
          border: Border.all(color: gold, width: 2),
          borderRadius: BorderRadius.circular(14),
        );
      case 'night':
        sheetBack = DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(center: const Alignment(-.7, -1), radius: 1.4, colors: [main, const Color(0xFF0B0F1A)], stops: const [0, .72]),
          ),
        );
        frameDeco = BoxDecoration(border: Border.all(color: gold, width: 1.5));
    }
    final inner = <Widget>[
      // a second line inside the frame
      if (layout == 'classic' || layout == 'frame')
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: gold, width: 1.5)),
            ),
          ),
        ),
      if (layout == 'royal' || layout == 'ornate')
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: gold, width: 2)),
            ),
          ),
        ),
      if (layout == 'kbach')
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: main)),
            ),
          ),
        ),
      if (layout == 'night')
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: fade(gold, .5))),
            ),
          ),
        ),
    ];
    // decorations on the sheet
    final deco = <Widget>[
      if (layout == 'modern')
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 34,
          child: Row(
            children: [
              Container(width: 26, color: main),
              Container(width: 8, color: gold),
            ],
          ),
        ),
      if (layout == 'band')
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 34,
          child: Row(
            children: [
              Container(width: 26, color: main),
              Container(width: 8, color: gold),
            ],
          ),
        ),
      if (layout == 'ornate')
        for (final (al, br) in [
          (Alignment.topLeft, const BorderRadius.only(topLeft: Radius.circular(30))),
          (Alignment.topRight, const BorderRadius.only(topRight: Radius.circular(30))),
          (Alignment.bottomLeft, const BorderRadius.only(bottomLeft: Radius.circular(30))),
          (Alignment.bottomRight, const BorderRadius.only(bottomRight: Radius.circular(30))),
        ])
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(44),
              child: Align(
                alignment: al,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: br,
                    border: Border(
                      top: al.y < 0 ? BorderSide(color: gold, width: 3) : BorderSide.none,
                      bottom: al.y > 0 ? BorderSide(color: gold, width: 3) : BorderSide.none,
                      left: al.x < 0 ? BorderSide(color: gold, width: 3) : BorderSide.none,
                      right: al.x > 0 ? BorderSide(color: gold, width: 3) : BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
      if (layout == 'ribbon') ...[
        Positioned(
          left: -86,
          top: 62,
          child: Transform.rotate(angle: -38 * math.pi / 180, child: _Ribbon(main, gold, paper)),
        ),
        Positioned(
          right: -86,
          top: 62,
          child: Transform.rotate(angle: 38 * math.pi / 180, child: _Ribbon(main, gold, paper)),
        ),
      ],
      if (layout == 'wave') ...[
        Positioned(
          left: -112,
          right: -112,
          top: -110,
          height: 262,
          child: Container(
            decoration: BoxDecoration(
              color: gold,
              borderRadius: const BorderRadius.vertical(bottom: Radius.elliptical(700, 130)),
            ),
          ),
        ),
        Positioned(
          left: -112,
          right: -112,
          top: -110,
          height: 250,
          child: Container(
            decoration: BoxDecoration(
              color: main,
              borderRadius: const BorderRadius.vertical(bottom: Radius.elliptical(700, 125)),
            ),
          ),
        ),
        Positioned(
          left: -112,
          right: -112,
          bottom: -182,
          height: 242,
          child: Container(
            decoration: BoxDecoration(
              color: gold,
              borderRadius: const BorderRadius.vertical(top: Radius.elliptical(700, 120)),
            ),
          ),
        ),
        Positioned(
          left: -112,
          right: -112,
          bottom: -170,
          height: 230,
          child: Container(
            decoration: BoxDecoration(
              color: main,
              borderRadius: const BorderRadius.vertical(top: Radius.elliptical(700, 115)),
            ),
          ),
        ),
      ],
      if (layout == 'geo') ...[
        Positioned(
          left: 0,
          top: 0,
          child: CustomPaint(size: const Size(360, 360), painter: _Tri(fade(gold, .55), topLeft: true)),
        ),
        Positioned(
          left: 0,
          top: 0,
          child: CustomPaint(size: const Size(300, 300), painter: _Tri(main, topLeft: true)),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: CustomPaint(size: const Size(360, 360), painter: _Tri(fade(gold, .55), topLeft: false)),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: CustomPaint(size: const Size(300, 300), painter: _Tri(main, topLeft: false)),
        ),
      ],
      if (layout == 'minimal') ...[
        Positioned(left: 104, top: 34, child: Container(width: 80, height: 6, color: main)),
        Positioned(left: 190, top: 34, child: Container(width: 30, height: 6, color: gold)),
      ],
      if (layout == 'kbach')
        for (final top0 in [true, false])
          Positioned(
            left: 0,
            right: 0,
            top: top0 ? 13 : null,
            bottom: top0 ? null : 13,
            child: Center(
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: gold,
                    boxShadow: [
                      BoxShadow(color: paper, spreadRadius: 5),
                      BoxShadow(color: main, spreadRadius: 7),
                    ],
                  ),
                ),
              ),
            ),
          ),
      if (layout == 'medal') ...[
        Positioned(
          left: 0,
          right: 0,
          top: 46,
          child: Center(
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(center: const Alignment(-.3, -.4), colors: [gold, main]),
                boxShadow: [
                  BoxShadow(color: paper, spreadRadius: 6),
                  BoxShadow(color: gold, spreadRadius: 9),
                ],
              ),
            ),
          ),
        ),
        Positioned(left: 0, right: 0, top: 82, child: Center(child: logoW)),
      ],
    ];
    return Container(
      color: sheetColor,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          ?(sheetBack == null ? null : Positioned.fill(child: sheetBack)),
          if (!_decoOnTop.contains(layout)) ...deco,
          Padding(
            padding: sheetPad,
            child: Container(
              decoration: frameDeco,
              child: Stack(children: [...inner, content]),
            ),
          ),
          if (_decoOnTop.contains(layout)) ...deco,
        ],
      ),
    );
  }

  static String _date(Object? v) {
    final d = evDate(v);
    if (d == null) return '';
    const mon = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${d.day} ${mon[d.month - 1]} ${d.year}';
  }
}

class _Ribbon extends StatelessWidget {
  final Color main, gold, paper;
  const _Ribbon(this.main, this.gold, this.paper);
  @override
  Widget build(BuildContext context) => Container(
    width: 380,
    height: 54,
    decoration: BoxDecoration(
      color: main,
      boxShadow: [
        BoxShadow(color: paper, spreadRadius: 4),
        BoxShadow(color: gold, spreadRadius: 7),
      ],
    ),
  );
}

class _Tri extends CustomPainter {
  final Color color;
  final bool topLeft;
  const _Tri(this.color, {required this.topLeft});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path();
    if (topLeft) {
      p
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(0, size.height);
    } else {
      p
        ..moveTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height);
    }
    canvas.drawPath(p..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Tri o) => o.color != color;
}

// a sample ticket for previews
Json sampleTicket(Json ev, String lang) => {
  'code': 'K7QX2MPA9D',
  'no': 1,
  'type_name': objs(ev['types']).isNotEmpty ? str(objs(ev['types']).first['name']) : 'Standard',
  'holder': lang == 'km' ? 'សុខ ដារ' : 'Sok Dara',
  'status': 'valid',
};

// a small picture that fits a box (for grids of designs)
class EvMini extends StatelessWidget {
  final Widget child;
  final double width, height;
  const EvMini({super.key, required this.child, required this.width, required this.height});
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: FittedBox(
      fit: BoxFit.contain,
      alignment: Alignment.topCenter,
      child: SizedBox(width: width, height: height, child: child),
    ),
  );
}
