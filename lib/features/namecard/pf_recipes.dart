part of 'pf_view.dart';

// The 100 portfolio recipe themes (recipes_data.dart · spec: bizhub/src/namecard/THEME_RECIPES.md, PORTFOLIO part).
// A recipe = one choice per part: bg hero hs hl pat ph sec h2 tl chip ft. The phone layout uses the app's sizes
// (photo 92 instead of 120, h1 ×0.75), everything else follows the spec.

bool isPfRecipe(String theme) => pfRecipes.containsKey(theme);

// group for the gallery filters: light | dark (page palette) · colour (a coloured hero)
bool pfRecipeDark(Recipe r) => const {'dark', 'black', 'navy', 'warm'}.contains(r['bg']);
bool pfRecipeColour(Recipe r) => r['hero'] != 'soft' && r['hero'] != 'plain';

const _rHeroEdge = {'flat': 0.0, 'wave': 56.0, 'arc': 56.0, 'slant': 56.0, 'zig': 18.0, 'bowl': 56.0};

_Pf _pfRecipeLook(Recipe r, Color c, bool km) {
  final dark = shade(c, -45), light = shade(c, 55), soft = shade(c, 90);
  final l = _Pf()..recipe = r;
  // ---------------------------------------------------------------- page palette
  final (page, paper, ink, muted, line, isDark) = switch (r['bg']) {
    'white' => (Colors.white, Colors.white, const Color(0xFF15161A), const Color(0xFF646A78), const Color(0xFFE6E8EE), false),
    'cream' => (const Color(0xFFF3EDE2), const Color(0xFFFBF8F2), const Color(0xFF2B2620), const Color(0xFF6F665B), const Color(0xFFE6DCCB), false),
    'slate' => (const Color(0xFFE6EAF0), const Color(0xFFF8FAFC), const Color(0xFF1D2430), const Color(0xFF5D6878), const Color(0xFFD5DCE6), false),
    'tint' => (soft, Colors.white, const Color(0xFF15161A), const Color(0xFF646A78), shade(c, 75), false),
    'dark' => (const Color(0xFF0F1115), const Color(0xFF171A21), const Color(0xFFEEF0F4), const Color(0xFF9AA1AE), const Color(0xFF262A33), true),
    'black' => (const Color(0xFF050507), const Color(0xFF0E0E12), Colors.white, const Color(0xFF8E909C), const Color(0xFF1F1F26), true),
    'navy' => (const Color(0xFF0B1226), const Color(0xFF121B36), const Color(0xFFEEF2FF), const Color(0xFFA3AED0), const Color(0xFF22305A), true),
    'warm' => (const Color(0xFF17130F), const Color(0xFF211B15), const Color(0xFFF6EFE6), const Color(0xFFB3A594), const Color(0xFF352C22), true),
    _ => (const Color(0xFFF4F5F8), Colors.white, const Color(0xFF15161A), const Color(0xFF646A78), const Color(0xFFE9EBF0), false),
  };
  final a = isDark ? light : c; // accent A
  l
    ..rDark = isDark
    ..rAccent = a
    ..page = page
    ..paper = paper
    ..ink = ink
    ..muted = muted
    ..line = line
    ..aboutInk = ink.withValues(alpha: .85)
    ..pInk = ink.withValues(alpha: .85)
    ..accent = a
    ..soft = isDark ? c.withValues(alpha: .18) : soft
    ..softInk = isDark ? light : dark
    ..icBg = isDark ? c.withValues(alpha: .18) : soft
    ..icInk = isDark ? light : dark
    ..fileBg = isDark ? Color.alphaBlend(c.withValues(alpha: .12), paper) : soft
    ..projLine = line
    ..dotBg = paper
    ..dotLine = c
    ..dotRingColor = isDark ? c.withValues(alpha: .25) : soft
    ..tlLine = line;

  // ---------------------------------------------------------------- hero
  final hero = r['hero'];
  final coloured = pfRecipeColour(r);
  l.rColoured = coloured;
  const tl0 = Alignment.topLeft, br = Alignment.bottomRight;
  l.heroDeco = switch (hero) {
    'solid' => BoxDecoration(color: c),
    'deep' => BoxDecoration(gradient: LinearGradient(begin: tl0, end: br, colors: [dark, c])),
    'mesh' => _Layers(
      [
        RadialGradient(center: const Alignment(-.7, -.6), radius: .55, colors: [light, light.withValues(alpha: 0)]),
        RadialGradient(center: const Alignment(.8, .8), radius: .6, colors: [dark, dark.withValues(alpha: 0)]),
      ],
      c,
      box: true,
    ),
    'duo' => BoxDecoration(gradient: LinearGradient(colors: [dark, dark, c, c], stops: const [0, .5, .5, 1])),
    'stripe' => _Layers(const [], c, stripes: light.withValues(alpha: .35)),
    'soft' => BoxDecoration(color: r['bg'] == 'tint' ? shade(c, 78) : soft), // soft on a soft page would vanish
    'plain' => BoxDecoration(
      border: Border(bottom: BorderSide(color: line)),
    ),
    _ => BoxDecoration(
      gradient: LinearGradient(begin: tl0, end: br, colors: [dark, c, Color.lerp(c, light, .5)!], stops: const [0, .7, 1]),
    ),
  };
  l
    ..heroFx = false
    ..rEdge = r['hs']
    ..rPat = r['pat']
    ..heroInk = coloured ? Colors.white : (hero == 'soft' ? const Color(0xFF15161A) : ink)
    ..roleColor = coloured ? null : a
    ..left = r['hl'] == 'left';
  if (hero == 'soft' && isDark) l.roleColor = c;
  l.rPatColor = coloured ? Colors.white.withValues(alpha: .14) : (isDark && hero == 'plain' ? light.withValues(alpha: .16) : c.withValues(alpha: .14));
  l.rConfetti = coloured
      ? [light.withValues(alpha: .6), Colors.white.withValues(alpha: .35), dark.withValues(alpha: .5)]
      : (isDark && hero == 'plain' ? [light.withValues(alpha: .6), Colors.white.withValues(alpha: .35), c.withValues(alpha: .7)] : [c.withValues(alpha: .55), light.withValues(alpha: .8), dark.withValues(alpha: .45)]);
  if (!coloured) {
    l
      ..pillBg = Colors.transparent
      ..pillLine = line
      ..pillInk = hero == 'soft' ? const Color(0xFF15161A) : ink;
  }
  l.mainTop = r['hs'] == 'flat' && coloured ? -28 : 8;

  // ---------------------------------------------------------------- photo
  l
    ..rPhoto = r['ph']
    ..rPhotoB = coloured ? Colors.white.withValues(alpha: .85) : (hero == 'soft' ? Colors.white : paper)
    ..rRing = coloured ? Colors.white : a
    ..photoBg = soft
    ..photoInk = dark
    ..photoTurn = 0;

  // ---------------------------------------------------------------- sections
  l.secShadow = const [BoxShadow(color: Color(0x0F16171B), blurRadius: 30, offset: Offset(0, 10))];
  if (isDark) l.secShadow = const [BoxShadow(color: Color(0x59000000), blurRadius: 30, offset: Offset(0, 10))];
  l.secRadius = 22;
  switch (r['sec']) {
    case 'flat':
      l
        ..secBg = Colors.transparent
        ..secShadow = const []
        ..secRadius = 0
        ..secPadV = 26
        ..secPadH = 4
        ..secLine = true
        ..mainGap = 0;
    case 'outline':
      l
        ..secShadow = const []
        ..secRadius = 16
        ..secBorder = Border.all(color: line, width: 1.5);
    case 'bar':
      l
        ..secRadius = 14
        ..secLeft = c
        ..secShadow = isDark ? const [] : const [BoxShadow(color: Color(0x0D000000), blurRadius: 18, offset: Offset(0, 6))];
    case 'tinted':
      l
        ..secBg = isDark ? Color.alphaBlend(c.withValues(alpha: .12), paper) : (r['bg'] == 'tint' ? shade(c, 78) : soft)
        ..secShadow = const []
        ..secRadius = 22;
    case 'brutal':
      l
        ..secRadius = 4
        ..secBorder = Border.all(color: ink, width: 2)
        ..secShadow = [BoxShadow(color: isDark ? c : ink, offset: const Offset(5, 5))];
    case 'glass':
      l
        ..secBg = Colors.white.withValues(alpha: isDark ? .05 : .6)
        ..secBorder = Border.all(color: Colors.white.withValues(alpha: isDark ? .1 : .8))
        ..secShadow = const []
        ..secRadius = 22
        ..secBlur = true;
  }

  // ---------------------------------------------------------------- section titles
  switch (r['h2']) {
    case 'caps':
      l
        ..icon = false
        ..h2Size = km ? 15 : 12.5
        ..h2Upper = !km
        ..h2Spacing = km ? 0 : 1.75
        ..h2Color = a;
    case 'under':
      l
        ..icon = false
        ..h2Size = 20
        ..h2Bar = a;
    case 'num':
      l
        ..icon = false
        ..h2Number = true
        ..numColor = a
        ..numSize = 14
        ..numGap = 10;
    case 'pill':
      l.h2Pill = c;
  }
  l
    ..rTl = r['tl']
    ..rChip = r['chip'];
  if (r['tl'] != 'dots') l.timeline = false;

  // ---------------------------------------------------------------- font
  switch (r['ft']) {
    case 'serif':
      l
        ..font = _serif
        ..nameSize = 27
        ..nameWeight = FontWeight.w600
        ..nameSpacing = 0;
    case 'mono':
      l
        ..font = _mono
        ..nameSize = 21
        ..nameWeight = FontWeight.w700
        ..nameSpacing = 0;
    case 'display':
      l
        ..nameSize = 25.5
        ..nameUpper = !km
        ..nameSpacing = km ? 0 : 1;
    case 'light':
      l
        ..nameSize = 28.5
        ..nameWeight = FontWeight.w400
        ..nameSpacing = -0.6;
    default:
      l.nameSize = 24;
  }
  return l;
}

// ---------------------------------------------------------------------------------------------- edges
// the hero's bottom edge: a full box for H−E px, then the spec path (0..100 box) stretched over the last E px
Path _rEdgePath(String hs, Size size, double e) {
  final w = size.width, h = size.height, top = h - e;
  Offset p(double x, double y) => Offset(x * w / 100, top + y * e / 100);
  final path = Path()..addRect(Rect.fromLTWH(0, 0, w, top + .5));
  final q = Path();
  void m(double x, double y) => q.moveTo(p(x, y).dx, p(x, y).dy);
  void ln(double x, double y) => q.lineTo(p(x, y).dx, p(x, y).dy);
  void cu(double a, double b, double c, double d, double x, double y) {
    final p1 = p(a, b), p2 = p(c, d), p3 = p(x, y);
    q.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);
  }

  m(0, 0);
  ln(100, 0);
  switch (hs) {
    case 'wave': // M0 0H100V55C80 100 65 20 45 55S10 90 0 50Z
      ln(100, 55);
      cu(80, 100, 65, 20, 45, 55);
      cu(25, 90, 10, 90, 0, 50);
    case 'arc': // M0 0H100V20Q50 140 0 20Z
      ln(100, 20);
      final c1 = p(50, 140), e1 = p(0, 20);
      q.quadraticBezierTo(c1.dx, c1.dy, e1.dx, e1.dy);
    case 'slant': // M0 0H100V10L0 100Z
      ln(100, 10);
      ln(0, 100);
    case 'zig': // M0 0H100V40L90 100 80 40 … 0 40Z
      ln(100, 40);
      for (var x = 90; x >= 0; x -= 10) {
        ln(x.toDouble(), x % 20 == 10 ? 100 : 40);
      }
    case 'bowl': // M0 0H100V0C100 60 75 100 50 100S0 60 0 0Z
      cu(100, 60, 75, 100, 50, 100);
      cu(25, 100, 0, 60, 0, 0);
    case 'tab': // M0 0H100V100H45C20 100 0 80 0 50Z
      ln(100, 100);
      ln(45, 100);
      cu(20, 100, 0, 80, 0, 50);
  }
  q.close();
  return Path.combine(PathOperation.union, path, q);
}

class _REdgeClip extends CustomClipper<Path> {
  final String hs;
  final double e;
  const _REdgeClip(this.hs, this.e);
  @override
  Path getClip(Size size) => _rEdgePath(hs, size, e);
  @override
  bool shouldReclip(_REdgeClip o) => o.hs != hs || o.e != e;
}

// ---------------------------------------------------------------------------------------------- patterns
class _RPat extends CustomPainter {
  final String pat;
  final Color color;
  final List<Color> confetti;
  const _RPat(this.pat, this.color, this.confetti);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final fill = Paint()..color = color;
    Paint stroke(double sw) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw;
    void tiles(double tw, double th, void Function(double x, double y) f) {
      for (double y = 0; y < h; y += th) {
        for (double x = 0; x < w; x += tw) {
          f(x, y);
        }
      }
    }

    switch (pat) {
      case 'dots':
        tiles(18, 18, (x, y) => canvas.drawCircle(Offset(x + 9, y + 9), 1.6, fill));
      case 'grid':
        for (double x = 0; x < w; x += 24) {
          canvas.drawRect(Rect.fromLTWH(x, 0, 1, h), fill);
        }
        for (double y = 0; y < h; y += 24) {
          canvas.drawRect(Rect.fromLTWH(0, y, w, 1), fill);
        }
      case 'diag':
        final p = stroke(2);
        for (double d = -h; d < w + h; d += 14) {
          canvas.drawLine(Offset(d, h), Offset(d + h, 0), p);
        }
      case 'waves':
        final p = stroke(1.4);
        for (double y = 9; y < h + 9; y += 18) {
          final path = Path()..moveTo(0, y);
          for (double x = 0; x <= w; x += 2) {
            path.lineTo(x, y + 4 * math.sin(x / 28 * 2 * math.pi));
          }
          canvas.drawPath(path, p);
        }
      case 'rings':
        final p = stroke(1.2);
        for (double r = 26; r <= 520; r += 26) {
          canvas.drawCircle(Offset(w - 40, 60), r, p);
        }
      case 'bubbles':
        for (final (cx, cy, r) in const [(.85, 40.0, 70.0), (.08, 260.0, 46.0), (.92, 420.0, 34.0), (.20, 540.0, 22.0)]) {
          canvas.drawCircle(Offset(w * cx, cy), r, fill);
        }
      case 'stars':
        tiles(60, 60, (x, y) {
          for (final (sx, sy, s) in const [(10.0, 12.0, 8.0), (38.0, 30.0, 5.0), (22.0, 48.0, 6.0)]) {
            canvas.drawPath(_star(Offset(x + sx, y + sy), s), fill);
          }
        });
      case 'confetti':
        tiles(48, 48, (x, y) {
          for (final (i, (cx, cy, deg)) in const [(8.0, 10.0, 30.0), (32.0, 22.0, -40.0), (18.0, 38.0, 70.0)].indexed) {
            canvas.save();
            canvas.translate(x + cx, y + cy);
            canvas.rotate(deg * math.pi / 180);
            canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -1.5, 8, 3), const Radius.circular(1.5)), Paint()..color = confetti[i]);
            canvas.restore();
          }
        });
      case 'tri':
        final p = stroke(1.2);
        tiles(32, 32, (x, y) {
          canvas.drawPath(
            Path()
              ..moveTo(x + 8, y + 24)
              ..lineTo(x + 16, y + 10)
              ..lineTo(x + 24, y + 24)
              ..close(),
            p,
          );
        });
      case 'plus':
        final p = stroke(1.4);
        tiles(26, 26, (x, y) {
          canvas.drawLine(Offset(x + 9, y + 13), Offset(x + 17, y + 13), p);
          canvas.drawLine(Offset(x + 13, y + 9), Offset(x + 13, y + 17), p);
        });
      case 'zigzag':
        final p = stroke(1.4);
        for (double y = 10; y < h + 10; y += 20) {
          final path = Path()..moveTo(0, y + 2.5);
          for (double x = 0; x <= w + 16; x += 8) {
            path.lineTo(x, (x / 8).round().isEven ? y + 2.5 : y - 2.5);
          }
          canvas.drawPath(path, p);
        }
      case 'halftone':
        final corner = Offset(w, 0);
        for (double y = 7; y < h; y += 14) {
          for (double x = 7; x < w; x += 14) {
            final r = 3.5 * math.max(0, 1 - (Offset(x, y) - corner).distance / 320);
            if (r > .1) canvas.drawCircle(Offset(x, y), r, fill);
          }
        }
    }
    canvas.restore();
  }

  static Path _star(Offset c, double s) {
    final k = s * .28;
    return Path()
      ..moveTo(c.dx, c.dy - s)
      ..lineTo(c.dx + k, c.dy - k)
      ..lineTo(c.dx + s, c.dy)
      ..lineTo(c.dx + k, c.dy + k)
      ..lineTo(c.dx, c.dy + s)
      ..lineTo(c.dx - k, c.dy + k)
      ..lineTo(c.dx - s, c.dy)
      ..lineTo(c.dx - k, c.dy - k)
      ..close();
  }

  @override
  bool shouldRepaint(_RPat o) => o.pat != pat || o.color != color;
}

// ---------------------------------------------------------------------------------------------- photo frames
const _rPolys = {
  'hex': [50.0, 0.0, 93.0, 25.0, 93.0, 75.0, 50.0, 100.0, 7.0, 75.0, 7.0, 25.0],
  'diamond': [50.0, 0.0, 100.0, 50.0, 50.0, 100.0, 0.0, 50.0],
  'octa': [30.0, 0.0, 70.0, 0.0, 100.0, 30.0, 100.0, 70.0, 70.0, 100.0, 30.0, 100.0, 0.0, 70.0, 0.0, 30.0],
};

Path _rPoly(String kind, Size s) {
  final v = _rPolys[kind]!;
  final path = Path()..moveTo(v[0] * s.width / 100, v[1] * s.height / 100);
  for (var i = 2; i < v.length; i += 2) {
    path.lineTo(v[i] * s.width / 100, v[i + 1] * s.height / 100);
  }
  return path..close();
}

class _RPolyClip extends CustomClipper<Path> {
  final String kind;
  const _RPolyClip(this.kind);
  @override
  Path getClip(Size size) => _rPoly(kind, size);
  @override
  bool shouldReclip(_RPolyClip o) => o.kind != kind;
}

class _RPolyFrame extends CustomPainter {
  final String kind;
  final Color color;
  const _RPolyFrame(this.kind, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final path = _rPoly(kind, size);
    canvas.drawShadow(path.shift(const Offset(0, 4)), const Color(0x55000000), 8, false);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RPolyFrame o) => o.kind != kind || o.color != color;
}

// the photo in the recipe's frame (base 92 px on the phone)
Widget _rPhotoBox(_Pf l, Widget inner) {
  const base = 92.0, bw = 4.0;
  final kind = l.rPhoto;
  final b = l.rPhotoB!;
  const shadow = [BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8))];
  Widget boxed(double w, double h, BorderRadius radius, {double border = bw, Color? borderColor, List<BoxShadow> shadows = shadow}) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: l.photoBg,
      borderRadius: radius,
      border: Border.all(color: borderColor ?? b, width: border),
      boxShadow: shadows,
    ),
    child: ClipRRect(borderRadius: radius, child: inner),
  );
  switch (kind) {
    case 'hex' || 'diamond' || 'octa':
      final size = kind == 'diamond' ? base * 1.1 : base;
      final gap = kind == 'diamond' ? 6.0 : bw;
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RPolyFrame(kind, b),
          child: Padding(
            padding: EdgeInsets.all(gap),
            child: ClipPath(
              clipper: _RPolyClip(kind),
              child: ColoredBox(color: l.photoBg, child: SizedBox.expand(child: inner)),
            ),
          ),
        ),
      );
    case 'ring':
      const size = base * 112 / 120;
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: l.photoBg,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: l.rRing!, spreadRadius: 6), BoxShadow(color: b == Colors.white.withValues(alpha: .85) ? Colors.white.withValues(alpha: .35) : b, spreadRadius: 3)],
        ),
        child: ClipOval(child: inner),
      );
    case 'tilt':
      return Transform.rotate(
        angle: -4 * math.pi / 180,
        child: boxed(base, base, BorderRadius.circular(16), border: 5, borderColor: Colors.white, shadows: const [BoxShadow(color: Color(0x38000000), blurRadius: 30, offset: Offset(0, 14))]),
      );
    case 'arch':
      return boxed(base, base * 140 / 120, const BorderRadius.only(topLeft: Radius.circular(46), topRight: Radius.circular(46), bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)));
    case 'blob':
      const s = base;
      return boxed(
        s,
        s,
        const BorderRadius.only(
          topLeft: Radius.elliptical(s * .58, s * .45),
          topRight: Radius.elliptical(s * .42, s * .55),
          bottomRight: Radius.elliptical(s * .55, s * .45),
          bottomLeft: Radius.elliptical(s * .45, s * .55),
        ),
      );
    case 'round':
      return boxed(base, base, BorderRadius.circular(22));
    case 'square':
      return boxed(base, base, BorderRadius.circular(5));
    case 'squircle':
      return boxed(base, base, BorderRadius.circular(34));
    default: // circle
      return boxed(base, base, BorderRadius.circular(base));
  }
}

// ---------------------------------------------------------------------------------------------- skill chips
Widget _rChip(_Pf l, Color c, String text, TextStyle base) {
  final d = l.rDark, a = l.rAccent!;
  final light = shade(c, 55), dark = shade(c, -45), soft = shade(c, 90);
  const pad = EdgeInsets.symmetric(horizontal: 14, vertical: 7);
  switch (l.rChip) {
    case 'outline':
      return Container(
        padding: pad,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: a, width: 1.5)),
        child: Text(text, style: base.copyWith(color: a)),
      );
    case 'solid':
      return Container(
        padding: pad,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: base.copyWith(color: Colors.white)),
      );
    case 'square':
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: d ? c.withValues(alpha: .18) : soft, borderRadius: BorderRadius.circular(6)),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(color: c, child: const SizedBox(width: 3)),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 7, 14, 7),
                child: Text(text, style: base.copyWith(color: d ? light : dark)),
              ),
            ],
          ),
        ),
      );
    case 'hash':
      return Container(
        padding: pad,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: l.line)),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '#', style: TextStyle(color: a, fontWeight: FontWeight.w800)),
              TextSpan(text: text),
            ],
          ),
          style: base.copyWith(color: l.ink),
        ),
      );
    default: // soft
      return Container(
        padding: pad,
        decoration: BoxDecoration(color: d ? c.withValues(alpha: .18) : soft, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: base.copyWith(color: d ? light : dark)),
      );
  }
}

// ---------------------------------------------------------------------------------------------- gallery helpers
// the recipe's own name (null = not a recipe theme)
String? pfRecipeName(String key, bool km) => pfRecipes[key]?.name(km);

// gallery filter: all | light | dark | color | serif | mono (owned is decided by the editor)
bool pfRecipeMatch(String key, String filter) {
  final r = pfRecipes[key];
  if (r == null) return false;
  return switch (filter) {
    'light' => !pfRecipeDark(r),
    'dark' => pfRecipeDark(r),
    'color' => pfRecipeColour(r),
    'serif' => r['ft'] == 'serif',
    'mono' => r['ft'] == 'mono',
    _ => true,
  };
}
