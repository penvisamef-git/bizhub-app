import 'dart:convert';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';

import '../../widgets/ui.dart';

import '../qrgen/qg_data.dart' show QrStyle;
import '../qrgen/qr_art.dart' show qrSvg;

// The QR code of Menu QR + Flip Book: 23 styles (menuqr/qrArt.js QR_STYLES) and the printable card (qrCardSvg).

class QrStyleDef {
  final QrStyle style;
  final String en, km;
  const QrStyleDef(this.style, this.en, this.km);
  String name(String lang) => lang == 'km' ? km : en;
}

const qrStyles = <String, QrStyleDef>{
  'classic': QrStyleDef(QrStyle('square', 'square'), 'Classic', 'បុរាណ'),
  'dots': QrStyleDef(QrStyle('dot', 'rounded'), 'Dots', 'ចំណុច'),
  'rounded': QrStyleDef(QrStyle('rounded', 'rounded'), 'Rounded', 'ជ្រុងមូល'),
  'diamond': QrStyleDef(QrStyle('diamond', 'square'), 'Diamond', 'ពេជ្រ'),
  'vbars': QrStyleDef(QrStyle('vbar', 'rounded'), 'Vertical lines', 'បន្ទាត់ឈរ'),
  'hbars': QrStyleDef(QrStyle('hbar', 'rounded'), 'Horizontal lines', 'បន្ទាត់ដេក'),
  'tiny': QrStyleDef(QrStyle('tiny', 'square'), 'Tiny dots', 'ចំណុចតូច'),
  'fluid': QrStyleDef(QrStyle('fluid', 'rounded'), 'Fluid', 'រលូន'),
  'bubble': QrStyleDef(QrStyle('bubble', 'circle'), 'Bubbles', 'ពពុះ'),
  'star': QrStyleDef(QrStyle('star', 'leaf'), 'Stars', 'ផ្កាយ'),
  'heart': QrStyleDef(QrStyle('heart', 'rounded'), 'Hearts', 'បេះដូង'),
  'plus': QrStyleDef(QrStyle('plus', 'square'), 'Plus', 'បូក'),
  'leaf': QrStyleDef(QrStyle('rounded', 'leaf'), 'Leaf', 'ស្លឹក'),
  'circle': QrStyleDef(QrStyle('dot', 'circle'), 'Circles', 'រង្វង់'),
  'sunset': QrStyleDef(QrStyle('dot', 'circle', grad: [Color(0xFFF97316), Color(0xFFDB2777)]), 'Sunset fade', 'ពណ៌ថ្ងៃលិច'),
  'ocean': QrStyleDef(QrStyle('rounded', 'rounded', grad: [Color(0xFF0EA5E9), Color(0xFF1E3A8A)]), 'Ocean fade', 'ពណ៌សមុទ្រ'),
  'mint': QrStyleDef(QrStyle('fluid', 'leaf', grad: [Color(0xFF10B981), Color(0xFF0F766E)]), 'Mint fade', 'ពណ៌មីន'),
  'berry': QrStyleDef(QrStyle('diamond', 'leaf', grad: [Color(0xFF86198F), Color(0xFFBE123C)]), 'Berry fade', 'ពណ៌បឺរី'),
  'twotone': QrStyleDef(QrStyle('square', 'rounded', eyeColor: true), 'Two colours', 'ពីរពណ៌'),
  'outline': QrStyleDef(QrStyle('outline', 'square'), 'Stitch', 'ថ្នេរ'),
  'mosaic': QrStyleDef(QrStyle('mosaic', 'square'), 'Mosaic', 'ម៉ូសាអ៊ិច'),
  'pixel': QrStyleDef(QrStyle('pixel', 'rounded', eyeColor: true), 'Pixel', 'ភីកសែល'),
  'royal': QrStyleDef(QrStyle('rounded', 'leaf', grad: [Color(0xFF713F12), Color(0xFFB45309)]), 'Royal gold', 'មាសរាជ'),
};

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
String _f(num v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(2);
String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

// a drawing + where the logo pictures go (round = in a circle)
class CardArt {
  final String svg;
  final double width, height;
  final List<(Rect, bool round)> logos;
  const CardArt(this.svg, this.width, this.height, this.logos);
}

// the code alone
CardArt qrCodeArt({
  required String text,
  String style = 'classic',
  Color color = const Color(0xFF111111),
  Color bg = Colors.white,
  Color accent = const Color(0xFFE0581A),
  bool logo = false,
  double px = 300,
}) {
  final st = (qrStyles[style] ?? qrStyles['classic']!).style;
  final svg = qrSvg(text: text, style: st, color: color, bg: bg, accent: accent, hole: logo, px: px);
  final s = px * .2;
  return CardArt(svg, px, px, logo ? [(Rect.fromLTWH((px - s) / 2, (px - s) / 2, s, s), false)] : const []);
}

// the printable card: colour band + logo + name, header, the code, footer + info line
CardArt qrCardArt({
  required String text,
  String style = 'classic',
  Color color = const Color(0xFF111111),
  Color bg = Colors.white,
  Color accent = const Color(0xFFE0581A),
  bool logo = false,
  String name = '',
  String header = '',
  String footer = '',
  String info = '',
  double width = 380,
}) {
  final w = width;
  final h = (w * (header.isNotEmpty ? 1.34 : 1.28)).roundToDouble();
  final band = h * .22;
  final codePx = (w * .66).roundToDouble();
  final codeY = (band + (header.isNotEmpty ? h * .075 : h * .04)).roundToDouble();
  final codeX = ((w - codePx) / 2).roundToDouble();
  final st = (qrStyles[style] ?? qrStyles['classic']!).style;
  final code = qrSvg(text: text, style: st, color: color, bg: bg, accent: accent, hole: logo, px: codePx, at: Offset(codeX, codeY));
  final below = codeY + codePx;
  String t(String s, double y, double sz, int weight, String fill) =>
      s.isEmpty ? '' : '<text x="${_f(w / 2)}" y="${_f(y)}" text-anchor="middle" font-family="Kantumruy Pro" font-size="${_f(sz)}" font-weight="$weight" fill="$fill">${_esc(s)}</text>';
  final r = w * .075;
  final cy = band * (name.isNotEmpty ? .42 : .5);
  final rad = w * .05;
  final logos = <(Rect, bool)>[];
  var logoTag = '';
  if (logo) {
    logoTag = '<circle cx="${_f(w / 2)}" cy="${_f(cy)}" r="${_f(r)}" fill="#fff"/>';
    logos.add((Rect.fromCircle(center: Offset(w / 2, cy), radius: r * .9), true));
    final s = codePx * .2;
    logos.add((Rect.fromLTWH(codeX + (codePx - s) / 2, codeY + (codePx - s) / 2, s, s), false));
  }
  final svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${_f(w)} ${_f(h)}" width="${_f(w)}" height="${_f(h)}"><rect width="${_f(w)}" height="${_f(h)}" rx="${_f(rad)}" fill="#fff"/>'
      '<path d="M0,${_f(rad)}a${_f(rad)},${_f(rad)} 0 0 1 ${_f(rad)},-${_f(rad)}h${_f(w - 2 * rad)}a${_f(rad)},${_f(rad)} 0 0 1 ${_f(rad)},${_f(rad)}v${_f(band - rad)}h-${_f(w)}z" fill="${_hex(accent)}"/>'
      '$logoTag${t(name, logo ? band * .86 : band * .6, w * .056, 800, '#ffffff')}${t(header, band + h * .055, w * .052, 800, '#111111')}$code${t(footer, below + w * .085, w * .044, 700, '#111111')}${t(info, below + w * .145, w * .033, 500, '#555555')}</svg>';
  return CardArt(svg, w, h, logos);
}

// on screen: the drawing + the logo pictures on top
class CardArtView extends StatelessWidget {
  final CardArt art;
  final String logo;
  const CardArtView({super.key, required this.art, this.logo = ''});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: art.width,
    height: art.height,
    child: Stack(
      children: [
        SvgPicture.string(art.svg, width: art.width, height: art.height),
        if (logo.isNotEmpty)
          for (final (rect, round) in art.logos)
            Positioned.fromRect(
              rect: rect,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(round ? rect.width : rect.width * .18),
                child: Image(image: netImage(logo), fit: round ? BoxFit.cover : BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink()),
              ),
            ),
      ],
    ),
  );
}

// the drawing as a PNG (logo fetched into it) — share sheet
Future<void> shareCardArt(CardArt art, String logo, String fileName, {double scale = 2.5}) async {
  var svg = art.svg;
  if (logo.isNotEmpty && art.logos.isNotEmpty) {
    try {
      final r = await Dio().get<List<int>>(logo, options: Options(responseType: ResponseType.bytes));
      final b64 = base64Encode(r.data!);
      final tags = StringBuffer();
      for (final (i, (rect, round)) in art.logos.indexed) {
        if (round) {
          tags.write(
            '<clipPath id="lc$i"><circle cx="${_f(rect.center.dx)}" cy="${_f(rect.center.dy)}" r="${_f(rect.width / 2)}"/></clipPath><image x="${_f(rect.left)}" y="${_f(rect.top)}" width="${_f(rect.width)}" height="${_f(rect.height)}" href="data:image/png;base64,$b64" clip-path="url(#lc$i)" preserveAspectRatio="xMidYMid slice"/>',
          );
        } else {
          tags.write('<image x="${_f(rect.left)}" y="${_f(rect.top)}" width="${_f(rect.width)}" height="${_f(rect.height)}" href="data:image/png;base64,$b64" preserveAspectRatio="xMidYMid meet"/>');
        }
      }
      svg = svg.replaceFirst(RegExp(r'</svg>$'), '$tags</svg>');
    } catch (_) {}
  }
  final info = await vg.loadPicture(SvgStringLoader(svg), null);
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.scale(scale);
  canvas.drawPicture(info.picture);
  final img = await rec.endRecording().toImage((art.width * scale).round(), (art.height * scale).round());
  info.picture.dispose();
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  if (png == null) return;
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(png.buffer.asUint8List(), mimeType: 'image/png', name: fileName)],
    ),
  );
}
