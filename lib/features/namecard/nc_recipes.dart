part of 'nc_card.dart';

// The 100 recipe themes (recipes_data.dart): one choice per part — bg pat hd hf ph al ct ft nm rl btn.
// Same rules as the web (bizhub/src/namecard/THEME_RECIPES.md + cardview-recipes.css).

enum _Tone { l, d, c }

const _rcEdges = <String, (double, String)>{
  'wave': (40, 'M0 0H100V55C80 100 65 20 45 55S10 90 0 50Z'),
  'arc': (46, 'M0 0H100V20Q50 140 0 20Z'),
  'slant': (50, 'M0 0H100V10L0 100Z'),
  'zig': (16, 'M0 0H100V40L90 100 80 40 70 100 60 40 50 100 40 40 30 100 20 40 10 100 0 40Z'),
  'bowl': (70, 'M0 0H100V0C100 60 75 100 50 100S0 60 0 0Z'),
  'tab': (60, 'M0 0H100V100H45C20 100 0 80 0 50Z'),
};

const _rcHeights = <String, double>{'band': 170, 'tall': 230, 'short': 110, 'wave': 180, 'arc': 170, 'slant': 180, 'zig': 165, 'bowl': 190, 'tab': 160, 'inset': 150};

const _rcPolys = <String, List<double>>{
  'hex': [50, 0, 93, 25, 93, 75, 50, 100, 7, 75, 7, 25],
  'diamond': [50, 0, 100, 50, 50, 100, 0, 50],
  'octa': [30, 0, 70, 0, 100, 30, 100, 70, 70, 100, 30, 100, 0, 70, 0, 30],
};

// an SVG path in a 0..100 box (absolute M H V L C S Q Z) → scaled into `r`
Path rcSvgPath(String d, Rect r) {
  final tokens = RegExp(r'[MHVLCSQZ]|-?\d*\.?\d+').allMatches(d).map((m) => m.group(0)!).toList();
  final p = Path();
  double sx(double x) => r.left + x / 100 * r.width;
  double sy(double y) => r.top + y / 100 * r.height;
  var i = 0, cmd = 'M';
  double x = 0, y = 0, lcx = 0, lcy = 0; // last cubic control (for S)
  double num() => double.parse(tokens[i++]);
  bool isNum() => i < tokens.length && !RegExp(r'^[A-Z]$').hasMatch(tokens[i]);
  while (i < tokens.length) {
    if (!isNum()) cmd = tokens[i++];
    switch (cmd) {
      case 'M':
        x = num();
        y = num();
        p.moveTo(sx(x), sy(y));
        cmd = 'L';
      case 'L':
        x = num();
        y = num();
        p.lineTo(sx(x), sy(y));
      case 'H':
        x = num();
        p.lineTo(sx(x), sy(y));
      case 'V':
        y = num();
        p.lineTo(sx(x), sy(y));
      case 'C':
        final x1 = num(), y1 = num(), x2 = num(), y2 = num();
        x = num();
        y = num();
        p.cubicTo(sx(x1), sy(y1), sx(x2), sy(y2), sx(x), sy(y));
        lcx = x2;
        lcy = y2;
        continue;
      case 'S':
        final x1 = 2 * x - lcx, y1 = 2 * y - lcy;
        final x2 = num(), y2 = num();
        x = num();
        y = num();
        p.cubicTo(sx(x1), sy(y1), sx(x2), sy(y2), sx(x), sy(y));
        lcx = x2;
        lcy = y2;
        continue;
      case 'Q':
        final x1 = num(), y1 = num();
        x = num();
        y = num();
        p.quadraticBezierTo(sx(x1), sy(y1), sx(x), sy(y));
      case 'Z':
        p.close();
    }
    lcx = x;
    lcy = y;
  }
  return p;
}

Path _polyPath(List<double> pts, Rect r) {
  final p = Path();
  for (var i = 0; i < pts.length; i += 2) {
    final o = Offset(r.left + pts[i] / 100 * r.width, r.top + pts[i + 1] / 100 * r.height);
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

// cover: full rectangle for H−E, then the edge shape in the last E px
class _EdgeClip extends CustomClipper<Path> {
  final double e;
  final String d;
  _EdgeClip(this.e, this.d);
  @override
  Path getClip(Size s) => Path.combine(PathOperation.union, Path()..addRect(Rect.fromLTWH(0, 0, s.width, s.height - e + .5)), rcSvgPath(d, Rect.fromLTWH(0, s.height - e, s.width, e)));
  @override
  bool shouldReclip(_EdgeClip o) => o.e != e || o.d != d;
}

class _PolyClip extends CustomClipper<Path> {
  final List<double> pts;
  _PolyClip(this.pts);
  @override
  Path getClip(Size s) => _polyPath(pts, Offset.zero & s);
  @override
  bool shouldReclip(_PolyClip o) => o.pts != pts;
}

class _PolyShadow extends CustomPainter {
  final List<double> pts;
  _PolyShadow(this.pts);
  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    _polyPath(pts, Offset.zero & size).shift(const Offset(0, 8)),
    Paint()
      ..color = const Color(0x1F000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
  );
  @override
  bool shouldRepaint(_PolyShadow o) => false;
}

// stripe fill: c + 45° stripes of a(light,.5) 0–6px, transparent 6–12px (period measured across the stripes)
class _StripeFill extends CustomPainter {
  final Color base, stripe;
  static const on = 6.0, period = 12.0;
  _StripeFill(this.base, this.stripe);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final p = Paint()..color = stripe;
    // 45deg gradient runs towards top-right: stripes are the lines x − y = k (going down-right)
    final step = period * math.sqrt2, w = on * math.sqrt2;
    for (double k = -size.height; k < size.width + size.height; k += step) {
      canvas.drawPath(
        Path()
          ..moveTo(k, 0)
          ..lineTo(k + w, 0)
          ..lineTo(k + w + size.height, size.height)
          ..lineTo(k + size.height, size.height)
          ..close(),
        p,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StripeFill o) => o.base != base || o.stripe != stripe;
}

// the whole-card pattern layer (shared geometry with the portfolio hero)
class RcPattern extends CustomPainter {
  final String pat;
  final Color p;
  final List<Color> confetti;
  RcPattern(this.pat, this.p, [this.confetti = const []]);

  @override
  void paint(Canvas canvas, Size s) {
    if (pat == 'none') return;
    canvas.save();
    canvas.clipRect(Offset.zero & s);
    final fill = Paint()..color = p;
    Paint stroke(double w) => Paint()
      ..color = p
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;
    switch (pat) {
      case 'dots':
        for (double y = 9; y < s.height + 9; y += 18) {
          for (double x = 9; x < s.width + 9; x += 18) {
            canvas.drawCircle(Offset(x, y), 1.6, fill);
          }
        }
      case 'grid':
        final st = stroke(1);
        for (double x = .5; x < s.width; x += 24) {
          canvas.drawLine(Offset(x, 0), Offset(x, s.height), st);
        }
        for (double y = .5; y < s.height; y += 24) {
          canvas.drawLine(Offset(0, y), Offset(s.width, y), st);
        }
      case 'diag':
        final st = stroke(2);
        for (double k = 0; k < s.width + s.height; k += 14) {
          canvas.drawLine(Offset(k, 0), Offset(k - s.height, s.height), st); // x + y = k
        }
      case 'waves':
        final st = stroke(1.4);
        for (double y0 = 9; y0 < s.height + 9; y0 += 18) {
          final path = Path()..moveTo(0, y0);
          for (double x = 2; x <= s.width + 2; x += 2) {
            path.lineTo(x, y0 + 4 * math.sin(2 * math.pi * x / 28));
          }
          canvas.drawPath(path, st);
        }
      case 'rings':
        final st = stroke(1.2);
        for (double r = 26; r <= 520; r += 26) {
          canvas.drawCircle(Offset(s.width - 40, 60), r, st);
        }
      case 'bubbles':
        for (final (fx, cy, r) in const [(.85, 40.0, 70.0), (.08, 260.0, 46.0), (.92, 420.0, 34.0), (.20, 540.0, 22.0)]) {
          canvas.drawCircle(Offset(s.width * fx, cy), r, fill);
        }
      case 'stars':
        Path star(double cx, double cy, double z) {
          final q = z * .28;
          return Path()
            ..moveTo(cx, cy - z)
            ..lineTo(cx + q, cy - q)
            ..lineTo(cx + z, cy)
            ..lineTo(cx + q, cy + q)
            ..lineTo(cx, cy + z)
            ..lineTo(cx - q, cy + q)
            ..lineTo(cx - z, cy)
            ..lineTo(cx - q, cy - q)
            ..close();
        }
        for (double ty = 0; ty < s.height; ty += 60) {
          for (double tx = 0; tx < s.width; tx += 60) {
            for (final (x, y, z) in const [(10.0, 12.0, 8.0), (38.0, 30.0, 5.0), (22.0, 48.0, 6.0)]) {
              canvas.drawPath(star(tx + x, ty + y, z), fill);
            }
          }
        }
      case 'confetti':
        final cols = confetti.length == 3 ? confetti : [p, p, p];
        for (double ty = 0; ty < s.height; ty += 48) {
          for (double tx = 0; tx < s.width; tx += 48) {
            for (final (i, (x, y, deg)) in const [(8.0, 10.0, 30.0), (32.0, 22.0, -40.0), (18.0, 38.0, 70.0)].indexed) {
              canvas.save();
              canvas.translate(tx + x, ty + y);
              canvas.rotate(deg * math.pi / 180);
              canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -1.5, 8, 3), const Radius.circular(1.5)), Paint()..color = cols[i]);
              canvas.restore();
            }
          }
        }
      case 'tri':
        final st = stroke(1.2);
        for (double ty = 0; ty < s.height; ty += 32) {
          for (double tx = 0; tx < s.width; tx += 32) {
            canvas.drawPath(
              Path()
                ..moveTo(tx + 8, ty + 24)
                ..lineTo(tx + 16, ty + 10)
                ..lineTo(tx + 24, ty + 24)
                ..close(),
              st,
            );
          }
        }
      case 'plus':
        final st = stroke(1.4);
        for (double ty = 0; ty < s.height; ty += 26) {
          for (double tx = 0; tx < s.width; tx += 26) {
            canvas.drawLine(Offset(tx + 9, ty + 13), Offset(tx + 17, ty + 13), st);
            canvas.drawLine(Offset(tx + 13, ty + 9), Offset(tx + 13, ty + 17), st);
          }
        }
      case 'zigzag':
        final st = stroke(1.4)..strokeJoin = StrokeJoin.miter;
        for (double y0 = 10; y0 < s.height + 10; y0 += 20) {
          final path = Path()..moveTo(0, y0 + 2.5);
          var up = true;
          for (double x = 8; x <= s.width + 8; x += 8) {
            path.lineTo(x, y0 + (up ? -2.5 : 2.5));
            up = !up;
          }
          canvas.drawPath(path, st);
        }
      case 'halftone':
        for (double y = 7; y < 330; y += 14) {
          for (double x = s.width - 7; x > s.width - 330; x -= 14) {
            final d = math.sqrt(math.pow(s.width - x, 2) + y * y);
            final r = 3.5 * math.max(0, 1 - d / 320);
            if (r > .05) canvas.drawCircle(Offset(x, y), r, fill);
          }
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(RcPattern o) => o.pat != pat || o.p != p;
}

// CSS linear-gradient angle → begin / end
(Alignment, Alignment) _cssAngle(double deg) {
  final a = deg * math.pi / 180;
  final v = Alignment(math.sin(a), -math.cos(a));
  return (-v, v);
}

LinearGradient _lin(double deg, List<Color> colors, [List<double>? stops]) {
  final (b, e) = _cssAngle(deg);
  return LinearGradient(begin: b, end: e, colors: colors, stops: stops);
}

class _RcBody extends StatelessWidget {
  final NcCard widget;
  final Recipe r;
  const _RcBody({required this.widget, required this.r});

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final km = widget.km;
    final compact = widget.compact;
    final c = hexColor('${card['color'] ?? ''}');
    final dark = shade(c, -35), light = shade(c, 55), soft = shade(c, 88);
    String s(String k) => '${card[k] ?? ''}'.trim();
    final role = [s('job_title'), s('company')].where((x) => x.isNotEmpty).join(' · ');
    final cover = s('cover'), photo = s('photo');
    final contacts = compact ? <NcContact>[] : contactsOf(card);
    final extras = compact ? <Map>[] : ((card['extras'] as List?) ?? const []).whereType<Map>().where((x) => '${x['label'] ?? ''}'.isNotEmpty || '${x['value'] ?? ''}'.isNotEmpty).toList();

    const white = Colors.white;
    // ------------------------------------------------ bg → tone, colours
    final bg = r['bg'];
    Color? bgColor;
    Gradient? bgGrad;
    Color ink, muted;
    _Tone tone;
    switch (bg) {
      case 'cream':
        (bgColor, ink, muted, tone) = (const Color(0xFFF6EFE3), const Color(0xFF2B2620), const Color(0xFF6F665B), _Tone.l);
      case 'paper':
        (bgColor, ink, muted, tone) = (const Color(0xFFFBFAF6), const Color(0xFF23211C), const Color(0xFF6A665C), _Tone.l);
      case 'slate':
        (bgColor, ink, muted, tone) = (const Color(0xFFE8ECF1), const Color(0xFF1D2430), const Color(0xFF5D6878), _Tone.l);
      case 'tint':
        (bgColor, ink, muted, tone) = (soft, const Color(0xFF16171B), const Color(0xFF5A5E6A), _Tone.l);
      case 'fade':
        bgGrad = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [soft, white], stops: const [0, .55]);
        (ink, muted, tone) = (const Color(0xFF16171B), const Color(0xFF6A6E7A), _Tone.l);
      case 'color':
        (bgColor, ink, muted, tone) = (c, white, white.withValues(alpha: .86), _Tone.c);
      case 'grad':
        bgGrad = _lin(160, [dark, c, light], const [0, .45, 1]);
        (ink, muted, tone) = (white, white.withValues(alpha: .88), _Tone.c);
      case 'deep':
        (bgColor, ink, muted, tone) = (dark, white, white.withValues(alpha: .8), _Tone.c);
      case 'dark':
        (bgColor, ink, muted, tone) = (const Color(0xFF131418), const Color(0xFFF4F5F7), const Color(0xFFA3A7B3), _Tone.d);
      case 'black':
        (bgColor, ink, muted, tone) = (const Color(0xFF050507), white, const Color(0xFF9A9CAB), _Tone.d);
      case 'navy':
        (bgColor, ink, muted, tone) = (const Color(0xFF0D1530), const Color(0xFFEEF2FF), const Color(0xFFA8B3D6), _Tone.d);
      default: // white
        (bgColor, ink, muted, tone) = (white, const Color(0xFF16171B), const Color(0xFF6A6E7A), _Tone.l);
    }
    final L = tone == _Tone.l, D = tone == _Tone.d, C = tone == _Tone.c;
    final accent = L ? c : (D ? light : white);
    final patColor = L ? c.withValues(alpha: .14) : (D ? light.withValues(alpha: .16) : white.withValues(alpha: .14));
    final confetti = L ? [c.withValues(alpha: .55), light.withValues(alpha: .8), dark.withValues(alpha: .45)] : [light.withValues(alpha: .6), white.withValues(alpha: .35), c.withValues(alpha: .7)];
    final frameB = bgColor ?? white; // photo border (fade / grad → white)

    // ------------------------------------------------ fonts
    final ft = r['ft'];
    final family = switch (ft) {
      'serif' => _serif,
      'mono' => _mono,
      _ => _sans,
    };
    final align = r['al'] == 'l' ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final textAlign = r['al'] == 'l' ? TextAlign.left : TextAlign.center;
    TextStyle ts({double size = 14, FontWeight w = FontWeight.w400, Color? color, double? h, double ls = 0, List<Shadow>? shadows}) =>
        TextStyle(fontFamily: family, fontFamilyFallback: _kh, fontSize: size, fontWeight: w, color: color ?? ink, height: h, letterSpacing: ls, shadows: shadows);

    // ------------------------------------------------ cover
    final hd = r['hd'];
    Widget coverFill() {
      if (cover.isNotEmpty) {
        return Image(image: netImage(cover), fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, _, _) => ColoredBox(color: c));
      }
      return switch (r['hf']) {
        'solid' => ColoredBox(color: c),
        'deep' => DecoratedBox(decoration: BoxDecoration(gradient: _lin(135, [dark, c]))),
        'soft' => ColoredBox(color: soft),
        'mesh' => DecoratedBox(
          decoration: BoxDecoration(color: c),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(center: const Alignment(-.6, -.4), radius: .9, colors: [light, light.withValues(alpha: 0)], stops: const [0, .6]),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(center: const Alignment(.7, .6), radius: .85, colors: [dark, dark.withValues(alpha: 0)], stops: const [0, .55]),
                ),
              ),
            ],
          ),
        ),
        'stripe' => CustomPaint(painter: _StripeFill(c, light.withValues(alpha: .5)), size: Size.infinite),
        'duo' => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [dark, dark, c, c], stops: const [0, .5, .5, 1]),
          ),
        ),
        _ => DecoratedBox(decoration: BoxDecoration(gradient: _lin(135, [c, light]))),
      };
    }

    Widget? coverBox() {
      if (hd == 'none') return null;
      final h = _rcHeights[hd] ?? 170;
      if (hd == 'inset') {
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(height: h, width: double.infinity, child: coverFill()),
          ),
        );
      }
      final edge = _rcEdges[hd];
      Widget box = SizedBox(height: h, width: double.infinity, child: coverFill());
      if (edge != null) box = ClipPath(clipper: _EdgeClip(edge.$1, edge.$2), child: box);
      return box;
    }

    // ------------------------------------------------ photo
    final ph = r['ph'];
    final pw = switch (ph) {
      'diamond' => 132.0,
      'ring' => 112.0,
      _ => 120.0,
    };
    final phH = ph == 'arch' ? 140.0 : pw;
    Widget photoBox() {
      final inner = photo.isNotEmpty
          ? Image(image: netImage(photo), fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, _, _) => const SizedBox.shrink())
          : ColoredBox(
              color: soft,
              child: Center(
                child: Text(
                  _initial(s('name')),
                  style: TextStyle(fontFamily: _sans, fontFamilyFallback: _kh, fontSize: 48, fontWeight: FontWeight.w800, color: dark),
                ),
              ),
            );
      const shadow = [BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8))];
      final poly = _rcPolys[ph];
      if (poly != null) {
        final inset = ph == 'diamond' ? 6.0 : 5.0;
        return SizedBox(
          width: pw,
          height: phH,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _PolyShadow(poly)),
              ClipPath(clipper: _PolyClip(poly), child: ColoredBox(color: frameB)),
              Padding(
                padding: EdgeInsets.all(inset),
                child: ClipPath(clipper: _PolyClip(poly), child: inner),
              ),
            ],
          ),
        );
      }
      if (ph == 'ring') {
        return Container(
          width: pw,
          height: pw,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: C ? white : accent, spreadRadius: 7), BoxShadow(color: frameB, spreadRadius: 4)],
          ),
          child: ClipOval(child: inner),
        );
      }
      BorderRadius radius;
      var border = 5.0;
      var borderColor = frameB;
      var sh = shadow;
      switch (ph) {
        case 'round':
          radius = BorderRadius.circular(28);
        case 'square':
          radius = BorderRadius.circular(6);
        case 'squircle':
          radius = BorderRadius.circular(44);
        case 'tilt':
          radius = BorderRadius.circular(18);
          border = 6;
          borderColor = white;
          sh = const [BoxShadow(color: Color(0x38000000), blurRadius: 30, offset: Offset(0, 14))];
        case 'arch':
          radius = const BorderRadius.only(topLeft: Radius.circular(60), topRight: Radius.circular(60), bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12));
        case 'blob':
          radius = BorderRadius.only(
            topLeft: Radius.elliptical(pw * .58, phH * .45),
            topRight: Radius.elliptical(pw * .42, phH * .55),
            bottomRight: Radius.elliptical(pw * .55, phH * .45),
            bottomLeft: Radius.elliptical(pw * .45, phH * .55),
          );
        default: // circle
          radius = BorderRadius.circular(pw);
      }
      Widget pic = Container(
        width: pw,
        height: phH,
        decoration: BoxDecoration(
          color: borderColor,
          borderRadius: radius,
          boxShadow: sh,
        ),
        padding: EdgeInsets.all(border),
        child: ClipRRect(borderRadius: _shrink(radius, border), child: inner),
      );
      if (ph == 'tilt') pic = Transform.rotate(angle: -4 * math.pi / 180, child: pic);
      return pic;
    }

    // ------------------------------------------------ name
    Widget nameText() {
      var text = s('name').isEmpty ? widget.yourName : s('name');
      var size = 26.0, ls = 0.0;
      var w = FontWeight.w800;
      switch (ft) {
        case 'serif':
          size = 30;
          w = FontWeight.w600;
        case 'mono':
          size = 23;
          w = FontWeight.w700;
        case 'display':
          size = 30;
          if (!km) {
            text = text.toUpperCase();
            ls = 30 * .04;
          }
        case 'light':
          size = 32;
          w = FontWeight.w400;
          ls = 32 * -.02;
      }
      final nm = r['nm'];
      List<Shadow>? shadows;
      if (nm == 'glow') {
        final g = C ? white.withValues(alpha: .55) : c;
        shadows = [Shadow(color: g, blurRadius: 8), Shadow(color: g, blurRadius: 22)];
      } else if (nm == 'shadow') {
        shadows = [Shadow(color: L ? c.withValues(alpha: .45) : (D ? c : dark), offset: const Offset(3, 3))];
      }
      Widget t = Text(text, textAlign: textAlign, style: ts(size: size, w: w, h: 1.2, ls: ls, shadows: shadows));
      if (nm == 'grad') {
        final cols = L ? [dark, c] : [white, light];
        t = ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (b) => LinearGradient(colors: cols).createShader(Offset.zero & b.size),
          child: t,
        );
      } else if (nm == 'mark') {
        final m = L ? c.withValues(alpha: .3) : (D ? light.withValues(alpha: .35) : white.withValues(alpha: .25));
        t = DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.transparent, m, m], stops: const [0, .62, .62, 1]),
          ),
          child: t,
        );
      }
      return Padding(
        padding: const EdgeInsets.only(top: 18), // margin-top 10 + the body's 8 gap
        child: Column(
          crossAxisAlignment: align,
          mainAxisSize: MainAxisSize.min,
          children: [
            t,
            if (nm == 'bar')
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
              ),
          ],
        ),
      );
    }

    // ------------------------------------------------ role
    Widget roleText() {
      final rc = L ? c : (D ? light : white.withValues(alpha: .92));
      final w = (ft == 'serif' || ft == 'light') ? FontWeight.w500 : FontWeight.w700;
      switch (r['rl']) {
        case 'pill':
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: C ? white : c, borderRadius: BorderRadius.circular(999)),
            child: Text(role, textAlign: textAlign, style: ts(size: 14, w: FontWeight.w700, color: C ? dark : white)),
          );
        case 'tag':
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: rc, width: 1.5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(role, textAlign: textAlign, style: ts(size: 13.5, w: FontWeight.w700, color: rc)),
          );
        case 'caps':
          return Text(km ? role : role.toUpperCase(), textAlign: textAlign, style: ts(size: km ? 14 : 12, w: FontWeight.w700, color: rc, ls: km ? 0 : 12 * .16));
        case 'dash':
          return Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '—  ', style: TextStyle(color: rc)),
                TextSpan(text: role),
                TextSpan(text: '  —', style: TextStyle(color: rc)),
              ],
            ),
            textAlign: textAlign,
            style: ts(size: 15, w: FontWeight.w600, color: muted),
          );
        case 'slash':
          return Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '/ ',
                  style: TextStyle(color: rc, fontWeight: FontWeight.w800),
                ),
                TextSpan(text: role),
              ],
            ),
            textAlign: textAlign,
            style: ts(size: 15, w: FontWeight.w600),
          );
        default:
          return Text(role, textAlign: textAlign, style: ts(size: 15, w: w, color: rc));
      }
    }

    // ------------------------------------------------ contacts
    final ct = r['ct'];
    Widget contactRow(NcContact x) {
      final label = widget.fieldLabels[x.key] ?? x.key;
      Color? tile;
      Border? border;
      var radius = 16.0, icRadius = 12.0;
      Color? icBg = c;
      var icInk = white, tileInk = ink;
      var labelOp = .65;
      List<BoxShadow> shadow = const [];
      var pad = const EdgeInsets.fromLTRB(9, 9, 12, 9);
      var line = false, bar = false;
      switch (ct) {
        case 'outline':
          border = Border.all(color: ink.withValues(alpha: .14), width: 1.5);
          radius = 14;
          (icBg, icInk) = L ? (soft, dark) : (D ? (white.withValues(alpha: .08), light) : (white.withValues(alpha: .18), white));
        case 'line':
          line = true;
          radius = 0;
          pad = const EdgeInsets.fromLTRB(0, 9, 12, 9);
          (icBg, icInk) = (null, accent);
        case 'solid':
          tile = C ? dark : c;
          tileInk = white;
          labelOp = .75;
          (icBg, icInk) = (white.withValues(alpha: .2), white);
        case 'glass':
          radius = 18;
          if (L) {
            tile = white.withValues(alpha: .7);
            border = Border.all(color: ink.withValues(alpha: .08));
          } else {
            tile = white.withValues(alpha: .12);
            border = Border.all(color: white.withValues(alpha: .2));
          }
          if (C) (icBg, icInk) = (white, c);
        case 'shadow':
          tile = D ? const Color(0xFF1D1F26) : white;
          if (C) tileInk = const Color(0xFF16171B);
          shadow = [BoxShadow(color: D ? const Color(0x59000000) : const Color(0x14000000), blurRadius: 18, offset: const Offset(0, 6))];
          (icBg, icInk) = D ? (c, white) : (soft, dark);
        case 'bar':
          bar = true;
          radius = 8;
          tile = L ? ink.withValues(alpha: .04) : white.withValues(alpha: .06);
          (icBg, icInk) = (null, accent);
        default: // soft, pill
          tile = L ? soft : (D ? white.withValues(alpha: .07) : Colors.black.withValues(alpha: .16));
          if (C) (icBg, icInk) = (white, c);
          if (ct == 'pill') {
            radius = 999;
            icRadius = 999;
            pad = const EdgeInsets.fromLTRB(6, 6, 18, 6);
          }
      }
      Widget content = Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: icBg, borderRadius: BorderRadius.circular(icRadius)),
            alignment: Alignment.center,
            child: _contactIcon(x.key, icInk),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: ts(size: 11, w: FontWeight.w700, color: tileInk.withValues(alpha: labelOp))),
                Text(x.text, style: ts(size: 14, w: FontWeight.w700, color: tileInk, h: 1.35)),
              ],
            ),
          ),
        ],
      );
      Widget row;
      if (line) {
        row = Container(
          padding: pad,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: ink.withValues(alpha: .12))),
          ),
          child: content,
        );
      } else if (bar) {
        row = Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: tile, borderRadius: BorderRadius.circular(radius)),
          child: Container(
            padding: pad.copyWith(left: pad.left + 4),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: accent, width: 4)),
            ),
            child: content,
          ),
        );
      } else {
        row = Container(
          padding: pad,
          decoration: BoxDecoration(color: tile, borderRadius: BorderRadius.circular(radius), border: border, boxShadow: shadow),
          child: content,
        );
      }
      return GestureDetector(onTap: widget.onContact == null ? null : () => widget.onContact!(x), child: row);
    }

    Widget extrasBox() {
      final rows = <Widget>[
        for (var i = 0; i < extras.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: i == 0
                ? null
                : BoxDecoration(
                    border: Border(top: BorderSide(color: ink.withValues(alpha: .1))),
                  ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${extras[i]['label'] ?? ''}', style: ts(size: 13.5, w: FontWeight.w600, color: muted)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${extras[i]['value'] ?? ''}', textAlign: TextAlign.right, style: ts(size: 13.5, w: FontWeight.w700)),
                ),
              ],
            ),
          ),
      ];
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CustomPaint(
          painter: _DashedBox(ink.withValues(alpha: .18), 16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(children: rows),
          ),
        ),
      );
    }

    Widget portfolioBtn() {
      final btn = r['btn'];
      Color? bgc;
      Gradient? g;
      Border? border;
      var fg = white;
      var radius = 999.0;
      switch (btn) {
        case 'outline':
          border = Border.all(color: accent, width: 2);
          fg = accent;
        case 'grad':
          g = LinearGradient(colors: C ? [white, soft] : [dark, light]);
          fg = C ? dark : white;
        default: // pill, square
          bgc = C ? white : c;
          fg = C ? dark : white;
          if (btn == 'square') radius = 10;
      }
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Container(
          height: 50,
          width: double.infinity,
          decoration: BoxDecoration(
            color: bgc,
            gradient: g,
            border: border,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: btn == 'outline' ? null : [BoxShadow(color: (bgc ?? c).withValues(alpha: .35), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.briefcaseBusiness, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(widget.viewPortfolio, style: ts(size: 15, w: FontWeight.w800, color: fg)),
            ],
          ),
        ),
      );
    }

    // ------------------------------------------------ body
    final children = <Widget>[
      photoBox(),
      nameText(),
      if (role.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: roleText()),
      if (s('bio').isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Text(s('bio'), textAlign: textAlign, style: ts(size: 14.5, color: muted, h: 1.65)),
        ),
      if (contacts.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 26),
          child: Column(
            children: [
              for (var i = 0; i < contacts.length; i++) ...[if (i > 0) const SizedBox(height: 8), contactRow(contacts[i])],
            ],
          ),
        ),
      if (extras.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: extrasBox()),
      if (!compact && card['portfolio'] == true && s('slug').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: portfolioBtn()),
    ];
    final cov = coverBox();
    final body = Padding(
      padding: EdgeInsets.fromLTRB(28, cov == null ? 36 : 0, 28, 24),
      child: _Overlap(
        shift: cov == null ? 0 : phH / 2,
        child: Column(crossAxisAlignment: align, mainAxisSize: MainAxisSize.min, children: children),
      ),
    );

    final radius = BorderRadius.circular(28);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420, minHeight: 560),
      child: Container(
        constraints: const BoxConstraints(minHeight: 560),
        decoration: BoxDecoration(
          color: bgGrad == null ? bgColor : null,
          gradient: bgGrad,
          borderRadius: radius,
          boxShadow: const [BoxShadow(color: Color(0x2416171B), blurRadius: 60, offset: Offset(0, 20))],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(child: CustomPaint(painter: RcPattern(r['pat'], patColor, confetti))),
              ),
              if (bg == 'paper')
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      margin: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: c.withValues(alpha: .35)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [?cov, body, const SizedBox(height: 24)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

BorderRadius _shrink(BorderRadius r, double by) {
  Radius f(Radius x) => Radius.elliptical(math.max(0, x.x - by), math.max(0, x.y - by));
  return BorderRadius.only(topLeft: f(r.topLeft), topRight: f(r.topRight), bottomLeft: f(r.bottomLeft), bottomRight: f(r.bottomRight));
}

// gallery groups (spec: Light = bg L, Dark = bg D, Colour = bg C)
String ncRecipeTone(String theme) {
  final r = cardRecipes[theme];
  if (r == null) return '';
  return switch (r['bg']) {
    'color' || 'grad' || 'deep' => 'color',
    'dark' || 'black' || 'navy' => 'dark',
    _ => 'light',
  };
}
