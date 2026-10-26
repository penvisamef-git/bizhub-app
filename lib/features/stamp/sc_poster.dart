import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'sc_common.dart';
import 'sc_data.dart';

// Shop QR posters (the web's stamp/posters.js): "basic" in the card's colours + 100 premium = 5 layouts × 20 colours.
// Drawn on a 1080 × 1500 board and scaled to [width] — the same board is what "Share" saves, sharp for printing.
const scPosterText = {
  'title': 'ប្រមូលត្រា ទទួលរង្វាន់',
  'sub': 'Collect stamps, get rewards',
  'scan': 'Scan to get your card · ស្កេនដើម្បីទទួលកាត',
  'note': 'No app needed · មិនចាំបាច់មានកម្មវិធី',
};

class ScPosterView extends StatelessWidget {
  final String poster; // key
  final String url; // the shop QR link
  final ScShop shop;
  final String rule; // "8 stamps = Free latte"
  final Map<String, String> info; // the owner's words: title, sub, rule, scan, note, phone, address
  final double width;
  const ScPosterView({super.key, required this.poster, required this.url, required this.shop, required this.rule, this.info = const {}, this.width = 300});

  static const double W = 1080, H = 1500;

  ScPalette _palette() {
    final p = scPosterOf(poster);
    final pal = scPalettes[p.pal];
    if (p.pal != 'auto' && pal != null) return pal;
    final t = scThemeOf(shop.theme);
    final c1 = t.bg.first, c2 = t.bg.length > 1 ? t.bg[1] : t.bg.first;
    return ScPalette(en: '', km: '', bg1: c1.withValues(alpha: 1), bg2: c2.withValues(alpha: 1), ink: t.ink, muted: t.muted, accent: scHex(shop.color) ?? t.accent, paper: Colors.white);
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette();
    final layout = scPosterOf(poster).layout;
    String own(String k) => (info[k] ?? '').trim();
    final title = own('title').isNotEmpty ? own('title') : scPosterText['title']!;
    final sub = own('sub').isNotEmpty ? own('sub') : scPosterText['sub']!;
    final ruleText = own('rule').isNotEmpty ? own('rule') : rule;
    final scan = own('scan').isNotEmpty ? own('scan') : scPosterText['scan']!;
    final extra = [own('note'), if (own('phone').isNotEmpty) '☎ ${own('phone')}', own('address')].where((s) => s.isNotEmpty).join(' · ');
    final noApp = extra.isNotEmpty ? extra : scPosterText['note']!;
    final noAppSize = extra.isNotEmpty ? 32.0 : 28.0;
    final accentInk = _dark(p.accent) ? Colors.white : const Color(0xFF111111);
    final grad = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p.bg1, p.bg2]);
    final name = shop.name;

    // one line of text, centred on x, its baseline near y (like canvas fillText)
    Widget txt(String s, double y, double size, Color color, {FontWeight w = FontWeight.w800, double max = W - 120}) => Positioned(
      left: (W - max) / 2,
      width: max,
      top: y - size * .95,
      child: Text(
        s,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: size, color: color, fontWeight: w, height: 1.15, fontFamily: 'PlusJakartaSans', fontFamilyFallback: const ['KantumruyPro']),
      ),
    );
    Widget qrBox(double x, double y, double size, {double radius = 40, Color? border}) => Positioned(
      left: x,
      top: y,
      width: size,
      height: size,
      child: Container(
        padding: EdgeInsets.all(size * .06),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: border == null ? null : Border.all(color: border, width: 6),
        ),
        child: QrImageView(data: url, padding: EdgeInsets.zero, backgroundColor: Colors.white, errorCorrectionLevel: QrErrorCorrectLevel.M),
      ),
    );
    Widget stampRow(double y, double r, int count, int filled, Color color, Color empty) => Positioned(
      left: 0,
      right: 0,
      top: y - r,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              width: r * 2,
              height: r * 2,
              margin: EdgeInsets.symmetric(horizontal: r * .3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? color : Colors.transparent,
                border: i < filled ? null : Border.all(color: empty, width: 4),
              ),
              child: i < filled
                  ? Center(
                      child: Container(
                        width: r * .7,
                        height: r * .7,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .9)),
                      ),
                    )
                  : null,
            ),
        ],
      ),
    );
    Widget box(double l, double t, double w, double h, {Color? color, Gradient? gradient, double radius = 0, BoxBorder? border}) => Positioned(
      left: l,
      top: t,
      width: w,
      height: h,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, gradient: gradient, borderRadius: BorderRadius.circular(radius), border: border),
      ),
    );
    Widget dot(double x, double y, double r, Color color) => Positioned(
      left: x - r,
      top: y - r,
      width: r * 2,
      height: r * 2,
      child: DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );

    final children = <Widget>[];
    switch (layout) {
      case 'band':
        children.addAll([
          box(0, 0, W, H, color: p.paper),
          Positioned(
            left: 0,
            top: 0,
            width: W,
            height: 680,
            child: ClipPath(
              clipper: _Band(),
              child: DecoratedBox(decoration: BoxDecoration(gradient: grad)),
            ),
          ),
          txt(name, 150, 66, p.ink),
          txt(title, 270, 74, p.accent == p.ink ? p.ink : p.accent),
          txt(sub, 345, 44, p.ink, w: FontWeight.w700),
          stampRow(460, 30, 5, 3, p.accent, p.muted),
          qrBox((W - 600) / 2, 620, 600, radius: 36, border: p.bg1),
          txt(ruleText, 1310, 54, const Color(0xFF1D1D1F)),
          txt(scan, 1380, 34, const Color(0xFF6B6B70), w: FontWeight.w600),
          txt(noApp, 1430, noAppSize, const Color(0xFF8A8A90), w: FontWeight.w600),
        ]);
      case 'frame':
        children.addAll([
          box(0, 0, W, H, gradient: grad),
          box(50, 50, W - 100, H - 100, radius: 48, border: Border.all(color: p.accent, width: 14)),
          box(80, 80, W - 160, H - 160, radius: 36, border: Border.all(color: p.accent, width: 3)),
          for (final (x, y) in [(80.0, 80.0), (W - 80, 80.0), (80.0, H - 80), (W - 80, H - 80)]) dot(x, y, 26, p.accent),
          txt(name, 200, 64, p.ink),
          txt(title, 300, 70, p.accent),
          txt(sub, 370, 42, p.muted, w: FontWeight.w700),
          qrBox((W - 620) / 2, 440, 620, radius: 30),
          txt(ruleText, 1180, 56, p.ink),
          txt(scan, 1260, 34, p.muted, w: FontWeight.w600),
          txt(noApp, 1310, noAppSize, p.muted, w: FontWeight.w600),
        ]);
      case 'ticket':
        children.addAll([
          box(0, 0, W, H, gradient: grad),
          box(90, 110, W - 180, H - 220, color: p.paper, radius: 40),
          dot(90, 520, 38, p.bg2),
          dot(W - 90, 520, 38, p.bg2),
          Positioned(
            left: 150,
            top: 518,
            width: W - 300,
            height: 4,
            child: CustomPaint(painter: _DashLine(Colors.black.withValues(alpha: .18))),
          ),
          box(140, 160, W - 280, 90, color: p.accent, radius: 45),
          txt('LOYALTY CARD · កាតសមាជិក', 220, 38, accentInk),
          txt(name, 340, 62, const Color(0xFF1D1D1F), max: W - 300),
          txt(title, 430, 48, p.accent == Colors.white ? const Color(0xFF1D1D1F) : p.accent, max: W - 300),
          qrBox((W - 560) / 2, 590, 560, radius: 24),
          txt(ruleText, 1240, 52, const Color(0xFF1D1D1F), max: W - 300),
          txt(scan, 1310, 30, const Color(0xFF6B6B70), w: FontWeight.w600, max: W - 300),
          txt(noApp, 1356, 26, const Color(0xFF8A8A90), w: FontWeight.w600, max: W - 300),
        ]);
      case 'stamps':
        children.addAll([
          box(0, 0, W, H, gradient: grad),
          for (final (x, y, r) in [(120.0, 160.0, 120.0), (W - 100, 330.0, 160.0), (160.0, H - 260, 170.0), (W - 140, H - 150, 110.0)]) dot(x, y, r, p.accent.withValues(alpha: .12)),
          txt(name, 150, 62, p.ink),
          stampRow(270, 40, 5, 4, p.accent, p.muted),
          txt(title, 400, 72, p.ink),
          txt(sub, 470, 42, p.muted, w: FontWeight.w700),
          qrBox((W - 580) / 2, 540, 580, radius: 44),
          box(150, 1180, W - 300, 110, color: p.accent, radius: 55),
          txt(ruleText, 1255, 50, accentInk, max: W - 340),
          txt(scan, 1370, 32, p.ink, w: FontWeight.w600),
          txt(noApp, 1420, noAppSize, p.muted, w: FontWeight.w600),
        ]);
      default: // centre (and basic)
        children.addAll([
          box(0, 0, W, H, gradient: grad),
          txt(name, 150, 64, p.ink),
          txt(title, 270, 78, _dark(p.bg1) == _dark(p.accent) ? p.ink : p.accent),
          txt(sub, 345, 46, p.ink, w: FontWeight.w700),
          qrBox((W - 680) / 2, 420, 680),
          txt(ruleText, 1200, 54, p.ink),
          txt(scan, 1275, 36, p.muted, w: FontWeight.w600),
          txt(noApp, 1330, noAppSize, p.muted, w: FontWeight.w600),
        ]);
    }
    children.add(txt('BizHub', H - 30, 24, layout == 'band' ? const Color(0xFF9A9AA0) : p.muted, w: FontWeight.w700));

    return SizedBox(
      width: width,
      height: width * H / W,
      child: FittedBox(
        child: SizedBox(
          width: W,
          height: H,
          child: Stack(clipBehavior: Clip.hardEdge, children: children),
        ),
      ),
    );
  }

  static bool _dark(Color c) => (c.r * 255) * .299 + (c.g * 255) * .587 + (c.b * 255) * .114 < 140;
}

// the band layout's curved top
class _Band extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, 0)
    ..lineTo(s.width, 0)
    ..lineTo(s.width, 560)
    ..quadraticBezierTo(s.width / 2, 680, 0, 560)
    ..close();
  @override
  bool shouldReclip(_Band old) => false;
}

class _DashLine extends CustomPainter {
  final Color color;
  const _DashLine(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 4;
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 2), Offset(x + 16, 2), p);
    }
  }

  @override
  bool shouldRepaint(_DashLine old) => false;
}
