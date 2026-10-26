import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../widgets/ui.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import 'qg_data.dart';

// The QR code drawn in its style + frame, as an SVG string — a port of the web's menuqr/qrArt.js (qrSvg)
// and qrgen/qrDesign.js (qrDesignSvg), so a code looks the same in the app, the web and the PNG.

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
String _f(num v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
int _hash(int r, int c) => ((r * 73856093) ^ (c * 19349663)) & 0xFFFFFFFF;

(String, String) _eye(num x, num y, String kind) {
  final ring = switch (kind) {
    'rounded' =>
      'M${x + 2},${y}h3a2,2 0 0 1 2,2v3a2,2 0 0 1 -2,2h-3a2,2 0 0 1 -2,-2v-3a2,2 0 0 1 2,-2z M${_f(x + 2.2)},${y + 1}a1.2,1.2 0 0 0 -1.2,1.2v2.6a1.2,1.2 0 0 0 1.2,1.2h2.6a1.2,1.2 0 0 0 1.2,-1.2v-2.6a1.2,1.2 0 0 0 -1.2,-1.2z',
    'circle' => 'M${_f(x + 3.5)},${y}a3.5,3.5 0 1 1 0,7a3.5,3.5 0 1 1 0,-7z M${_f(x + 3.5)},${y + 1}a2.5,2.5 0 1 0 0,5a2.5,2.5 0 1 0 0,-5z',
    'leaf' => 'M${x + 3},${y}h4v4a3,3 0 0 1 -3,3h-4v-4a3,3 0 0 1 3,-3z M${x + 3},${y + 1}a2,2 0 0 0 -2,2v3h3a2,2 0 0 0 2,-2v-3z',
    _ => 'M$x,${y}h7v7h-7z M${x + 1},${y + 1}v5h5v-5z',
  };
  final ball = switch (kind) {
    'rounded' => 'M${_f(x + 2.8)},${y + 2}h1.4a0.8,0.8 0 0 1 0.8,0.8v1.4a0.8,0.8 0 0 1 -0.8,0.8h-1.4a0.8,0.8 0 0 1 -0.8,-0.8v-1.4a0.8,0.8 0 0 1 0.8,-0.8z',
    'circle' => 'M${_f(x + 3.5)},${y + 2}a1.5,1.5 0 1 1 0,3a1.5,1.5 0 1 1 0,-3z',
    'leaf' => 'M${_f(x + 3.4)},${y + 2}h1.6v1.6a1.4,1.4 0 0 1 -1.4,1.4h-1.6v-1.6a1.4,1.4 0 0 1 1.4,-1.4z',
    _ => 'M${x + 2},${y + 2}h3v3h-3z',
  };
  return (ring, ball);
}

String _module(String kind, int x, int y, bool Function(int dr, int dc) on) {
  switch (kind) {
    case 'dot':
      return '<circle cx="${_f(x + .5)}" cy="${_f(y + .5)}" r="0.46"/>';
    case 'tiny':
      return '<circle cx="${_f(x + .5)}" cy="${_f(y + .5)}" r="0.4"/>';
    case 'bubble':
      return '<circle cx="${_f(x + .5)}" cy="${_f(y + .5)}" r="${(0.4 + (_hash(x, y) % 5) * 0.03).toStringAsFixed(3)}"/>';
    case 'rounded':
      return '<rect x="${_f(x + .06)}" y="${_f(y + .06)}" width="0.88" height="0.88" rx="0.3"/>';
    case 'pixel':
      return '<rect x="${_f(x + .1)}" y="${_f(y + .1)}" width="0.8" height="0.8"/>';
    case 'outline':
      const a = 0.12, t = 0.3;
      final l = 1 - 2 * a - t;
      return '<path d="M${_f(x + a)},${_f(y + a + t)}l$t,-${t}l${_f(l)},${_f(l)}l-$t,${t}z"/><path d="M${_f(x + 1 - a)},${_f(y + a + t)}l-$t,-${t}l-${_f(l)},${_f(l)}l$t,${t}z"/>';
    case 'diamond':
      return '<path d="M${_f(x + .5)},${_f(y - .12)}L${_f(x + 1.12)},${_f(y + .5)}L${_f(x + .5)},${_f(y + 1.12)}L${_f(x - .12)},${_f(y + .5)}z"/>';
    case 'plus':
      return '<path d="M${_f(x + .25)},${y}h0.5v0.25h0.25v0.5h-0.25v0.25h-0.5v-0.25h-0.25v-0.5h0.25z"/>';
    case 'star':
      final cx = x + .5, cy = y + .5;
      final d = StringBuffer();
      for (var i = 0; i < 10; i++) {
        final r = i.isOdd ? 0.34 : 0.62;
        final ang = (math.pi / 5) * i - math.pi / 2;
        d.write('${i == 0 ? 'M' : 'L'}${(cx + r * math.cos(ang)).toStringAsFixed(3)},${(cy + r * math.sin(ang)).toStringAsFixed(3)}');
      }
      return '<path d="${d}z"/>';
    case 'heart':
      return '<path d="M${_f(x + .5)},${_f(y + 1.05)}C${_f(x - .05)},${_f(y + .7)} ${_f(x - .12)},${_f(y + .35)} ${_f(x + .05)},${_f(y + .12)}C${_f(x + .22)},${_f(y - .08)} ${_f(x + .44)},$y ${_f(x + .5)},${_f(y + .2)}C${_f(x + .56)},$y ${_f(x + .78)},${_f(y - .08)} ${_f(x + .95)},${_f(y + .12)}C${_f(x + 1.12)},${_f(y + .35)} ${_f(x + 1.05)},${_f(y + .7)} ${_f(x + .5)},${_f(y + 1.05)}z"/>';
    case 'vbar':
      final up = on(-1, 0), down = on(1, 0);
      return '<rect x="${_f(x + .07)}" y="${_f(y + (up ? 0 : .06))}" width="0.86" height="${_f(1 - (up ? 0 : .06) - (down ? 0 : .06))}" rx="${up || down ? 0 : 0.43}"/>';
    case 'hbar':
      final l = on(0, -1), r = on(0, 1);
      return '<rect x="${_f(x + (l ? 0 : .06))}" y="${_f(y + .07)}" width="${_f(1 - (l ? 0 : .06) - (r ? 0 : .06))}" height="0.86" rx="${l || r ? 0 : 0.43}"/>';
    case 'fluid':
      var s = '<circle cx="${_f(x + .5)}" cy="${_f(y + .5)}" r="0.5"/>';
      if (on(0, 1)) s += '<rect x="${_f(x + .5)}" y="$y" width="1" height="1"/>';
      if (on(1, 0)) s += '<rect x="$x" y="${_f(y + .5)}" width="1" height="1"/>';
      return s;
    case 'mosaic':
      final k = _hash(x, y) % 3;
      final m = [0.0, 0.1, 0.2][k];
      return '<rect x="${_f(x + m)}" y="${_f(y + m)}" width="${_f(1 - 2 * m)}" height="${_f(1 - 2 * m)}" rx="${k == 2 ? 0.15 : 0}"/>';
    default:
      return '<rect x="$x" y="$y" width="1.02" height="1.02"/>';
  }
}

List<(int, int)> _alignCentres(int version) {
  if (version == 1) return const [];
  final count = version ~/ 7 + 2;
  final size = version * 4 + 17;
  final step = size == 145 ? 26 : ((size - 13) / (2 * count - 2)).ceil() * 2;
  final pos = <int>[size - 7];
  for (var i = 1; i < count - 1; i++) {
    pos.add(pos[i - 1] - step);
  }
  pos.add(6);
  final p = pos.reversed.toList();
  final out = <(int, int)>[];
  final last = p.length - 1;
  for (var i = 0; i < p.length; i++) {
    for (var j = 0; j < p.length; j++) {
      if ((i == 0 && j == 0) || (i == 0 && j == last) || (i == last && j == 0)) continue;
      out.add((p[i], p[j]));
    }
  }
  return out;
}

int _gid = 0;

// the code alone (viewBox in modules, quiet zone 2). hole = keep the middle clear for a logo
String qrSvg({
  required String text,
  required QrStyle style,
  Color color = const Color(0xFF111111),
  Color bg = Colors.white,
  Color accent = const Color(0xFFE0581A),
  bool hole = false,
  double px = 512,
  Offset? at,
}) {
  final gid = 'qg${_gid++}';
  final code = QrCode.fromData(data: text.isEmpty ? ' ' : text, errorCorrectLevel: QrErrorCorrectLevel.H);
  final img = QrImage(code);
  final n = img.moduleCount;
  bool get(int r, int c) => r >= 0 && c >= 0 && r < n && c < n && img.isDark(r, c);
  final aligns = _alignCentres(code.typeNumber);
  bool isAlign(int r, int c) => aligns.any((a) => (r - a.$1).abs() <= 2 && (c - a.$2).abs() <= 2);
  bool isEye(int r, int c) => (r < 7 && c < 7) || (r < 7 && c >= n - 7) || (r >= n - 7 && c < 7) || isAlign(r, c);
  final h = hole ? ((n * 0.24).ceil() | 1) : 0;
  final h0 = (n - h) ~/ 2;
  bool inHole(int r, int c) => h > 0 && r >= h0 - 1 && r <= h0 + h && c >= h0 - 1 && c <= h0 + h;
  final body = StringBuffer();
  for (var r = 0; r < n; r++) {
    for (var c = 0; c < n; c++) {
      if (!get(r, c) || isEye(r, c) || inHole(r, c)) continue;
      body.write(_module(style.dot, c, r, (dr, dc) => get(r + dr, c + dc) && !isEye(r + dr, c + dc) && !inHole(r + dr, c + dc)));
    }
  }
  const q = 2;
  final size = n + q * 2;
  final fill = style.grad != null ? 'url(#$gid)' : _hex(color);
  final eyeFill = style.eyeColor ? _hex(accent) : fill;
  final eyes = StringBuffer();
  for (final (ex, ey) in [(0, 0), (n - 7, 0), (0, n - 7)]) {
    final (ring, ball) = _eye(ex, ey, style.eye);
    eyes.write('<path d="$ring" fill-rule="evenodd"/><path d="$ball"/>');
  }
  final round = style.eye != 'square';
  for (final (ar, ac) in aligns) {
    final x = ac - 2, y = ar - 2;
    eyes.write(
      round
          ? '<path d="M${_f(x + 1.2)},${y}h2.6a1.2,1.2 0 0 1 1.2,1.2v2.6a1.2,1.2 0 0 1 -1.2,1.2h-2.6a1.2,1.2 0 0 1 -1.2,-1.2v-2.6a1.2,1.2 0 0 1 1.2,-1.2z M${_f(x + 1.4)},${y + 1}a0.4,0.4 0 0 0 -0.4,0.4v2.2a0.4,0.4 0 0 0 0.4,0.4h2.2a0.4,0.4 0 0 0 0.4,-0.4v-2.2a0.4,0.4 0 0 0 -0.4,-0.4z" fill-rule="evenodd"/><circle cx="${_f(ac + .5)}" cy="${_f(ar + .5)}" r="0.55"/>'
          : '<path d="M$x,${y}h5v5h-5z M${x + 1},${y + 1}v3h3v-3z" fill-rule="evenodd"/><rect x="$ac" y="$ar" width="1" height="1"/>',
    );
  }
  final lw = h + 1;
  final holeTag = h > 0 ? '<rect x="${_f(h0 - .5)}" y="${_f(h0 - .5)}" width="$lw" height="$lw" rx="${_f(lw * .22)}" fill="${_hex(bg)}"/>' : '';
  final grad = style.grad != null
      ? '<defs><linearGradient id="$gid" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${_hex(style.grad![0])}"/><stop offset="1" stop-color="${_hex(style.grad![1])}"/></linearGradient></defs>'
      : '';
  final inner = '$grad<rect x="${-q}" y="${-q}" width="$size" height="$size" fill="${_hex(bg)}"/><g fill="$fill">$body</g><g fill="$eyeFill">$eyes</g>$holeTag';
  // flutter_svg draws no nested <svg>: inside a frame the code is a group moved + scaled into place
  if (at != null) return '<g transform="translate(${_f(at.dx)} ${_f(at.dy)}) scale(${(px / size).toStringAsFixed(5)}) translate($q $q)">$inner</g>';
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="${-q} ${-q} $size $size" width="${_f(px)}" height="${_f(px)}">$inner</svg>';
}

// where the logo sits on a design (fractions of the width), when there is one
class QrArt {
  final String svg;
  final double width, height;
  final Rect? logo; // in px of the art
  const QrArt(this.svg, this.width, this.height, this.logo);
}

// one QR code in its design (shape + frame) — qrDesignSvg
QrArt qrDesignArt({required String text, String design = 'plain', Color? color, Color? bg, Color? accent, String label = '', bool logo = false, double size = 320, String scanMe = 'SCAN ME'}) {
  final d = qrDesigns[design] ?? qrDesigns['plain']!;
  final fg = color ?? d.color, back = bg ?? d.bg, ac = accent ?? d.accent;
  final word = label.isNotEmpty ? label : scanMe;
  final w = size;
  Rect? logoAt;
  String code(double px, double x, double y) {
    // the logo takes the middle ~26% of the code
    if (logo) {
      final s = px * .2;
      logoAt = Rect.fromLTWH(x + (px - s) / 2, y + (px - s) / 2, s, s);
    }
    return qrSvg(text: text, style: d.style, color: fg, bg: back, accent: ac, hole: logo, px: px, at: Offset(x, y));
  }

  String t(String s, double x, double y, double sz, Color fill, [int weight = 800]) =>
      '<text x="${_f(x)}" y="${_f(y)}" text-anchor="middle" font-family="Kantumruy Pro" font-size="${_f(sz)}" font-weight="$weight" fill="${_hex(fill)}">${_esc(s)}</text>';
  QrArt svg(double h, String body) => QrArt('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${_f(w)} ${_f(h)}" width="${_f(w)}" height="${_f(h)}">$body</svg>', w, h, logoAt);
  final b = _hex(back), a = _hex(ac);
  switch (d.frame) {
    case 'card':
      final c = w * .78, h = w * (label.isNotEmpty ? 1.12 : 1);
      final inner = code(c, (w - c) / 2, w * .11);
      return svg(
        h,
        '<rect x="2" y="2" width="${_f(w - 4)}" height="${_f(h - 4)}" rx="${_f(w * .08)}" fill="$b" stroke="$a" stroke-width="${_f(w * .012)}"/>$inner${label.isNotEmpty ? t(label, w / 2, w * 1.0, w * .07, ac) : ''}',
      );
    case 'banner':
      final c = w * .76, h = w * 1.16;
      final inner = code(c, (w - c) / 2, w * .26);
      return svg(
        h,
        '<rect width="${_f(w)}" height="${_f(h)}" rx="${_f(w * .06)}" fill="$b"/><path d="M0,${_f(w * .06)}a${_f(w * .06)},${_f(w * .06)} 0 0 1 ${_f(w * .06)},-${_f(w * .06)}h${_f(w * .88)}a${_f(w * .06)},${_f(w * .06)} 0 0 1 ${_f(w * .06)},${_f(w * .06)}v${_f(w * .12)}h-${_f(w)}z" fill="$a"/>${t(word, w / 2, w * .125, w * .075, Colors.white)}$inner',
      );
    case 'pill':
      final c = w * .86, h = w * 1.16;
      final inner = code(c, (w - c) / 2, w * .05);
      return svg(
        h,
        '<rect width="${_f(w)}" height="${_f(h)}" rx="${_f(w * .05)}" fill="$b"/>$inner<rect x="${_f(w * .18)}" y="${_f(w * .96)}" width="${_f(w * .64)}" height="${_f(w * .14)}" rx="${_f(w * .07)}" fill="$a"/>${t(word, w / 2, w * 1.055, w * .065, Colors.white)}',
      );
    case 'circle':
      final c = w * .6;
      final inner = code(c, (w - c) / 2, w * .17);
      return svg(
        w,
        '<circle cx="${_f(w / 2)}" cy="${_f(w / 2)}" r="${_f(w / 2 - w * .02)}" fill="$b" stroke="$a" stroke-width="${_f(w * .04)}"/><circle cx="${_f(w / 2)}" cy="${_f(w / 2)}" r="${_f(w / 2 - w * .07)}" fill="none" stroke="$a" stroke-width="${_f(w * .006)}" stroke-dasharray="${_f(w * .02)} ${_f(w * .015)}"/>$inner${t(word, w / 2, w * .88, w * .055, ac)}',
      );
    case 'ticket':
      final c = w * .7, h = w * 1.2, r = w * .06, cut = w * .92;
      final inner = code(c, (w - c) / 2, w * .14);
      return svg(
        h,
        '<path d="M${_f(r)},0h${_f(w - 2 * r)}a${_f(r)},${_f(r)} 0 0 1 ${_f(r)},${_f(r)}v${_f(cut - 2 * r)}a${_f(r)},${_f(r)} 0 0 0 0,${_f(2 * r)}v${_f(h - cut - 2 * r)}a${_f(r)},${_f(r)} 0 0 1 -${_f(r)},${_f(r)}h-${_f(w - 2 * r)}a${_f(r)},${_f(r)} 0 0 1 -${_f(r)},-${_f(r)}v-${_f(h - cut - 2 * r)}a${_f(r)},${_f(r)} 0 0 0 0,-${_f(2 * r)}v-${_f(cut - 2 * r)}a${_f(r)},${_f(r)} 0 0 1 ${_f(r)},-${_f(r)}z" fill="$a"/><rect x="${_f((w - c) / 2 - w * .04)}" y="${_f(w * .1)}" width="${_f(c + w * .08)}" height="${_f(c + w * .08)}" rx="${_f(w * .03)}" fill="$b"/>$inner<line x1="${_f(r * 1.5)}" y1="${_f(cut + r)}" x2="${_f(w - r * 1.5)}" y2="${_f(cut + r)}" stroke="#ffffff" stroke-opacity=".6" stroke-width="${_f(w * .008)}" stroke-dasharray="${_f(w * .025)} ${_f(w * .02)}"/>${t(word, w / 2, h - w * .07, w * .07, Colors.white)}',
      );
    case 'phone':
      final c = w * .62, h = w * 1.3;
      final inner = code(c, (w - c) / 2, w * .2);
      return svg(
        h,
        '<rect x="${_f(w * .1)}" y="2" width="${_f(w * .8)}" height="${_f(h - 4)}" rx="${_f(w * .12)}" fill="$a"/><rect x="${_f(w * .14)}" y="${_f(w * .08)}" width="${_f(w * .72)}" height="${_f(h - w * .16)}" rx="${_f(w * .08)}" fill="$b"/><rect x="${_f(w * .4)}" y="${_f(w * .03)}" width="${_f(w * .2)}" height="${_f(w * .025)}" rx="${_f(w * .0125)}" fill="$b" opacity=".6"/>$inner${t(word, w / 2, w * 1.0, w * .06, ac)}<rect x="${_f(w * .38)}" y="${_f(h - w * .15)}" width="${_f(w * .24)}" height="${_f(w * .02)}" rx="${_f(w * .01)}" fill="$a" opacity=".5"/>',
      );
    case 'polaroid':
      final c = w * .8, h = w * 1.12;
      final inner = code(c, w * .1, w * .08);
      return svg(
        h,
        '<rect x="2" y="2" width="${_f(w - 4)}" height="${_f(h - 4)}" rx="${_f(w * .015)}" fill="#ffffff" stroke="#dddddd" stroke-width="1"/>$inner${t(word, w / 2, w * 1.03, w * .07, ac, 700)}',
      );
    case 'bubble':
      final c = w * .7, h = w * 1.12, bh = w * .98;
      final inner = code(c, (w - c) / 2, w * .2);
      final k = w * .07;
      return svg(
        h,
        '<path d="M${_f(k)},0h${_f(w * .86)}a${_f(k)},${_f(k)} 0 0 1 ${_f(k)},${_f(k)}v${_f(bh - w * .14)}a${_f(k)},${_f(k)} 0 0 1 -${_f(k)},${_f(k)}h-${_f(w * .32)}l-${_f(w * .1)},${_f(w * .12)}l-${_f(w * .02)},-${_f(w * .12)}h-${_f(w * .42)}a${_f(k)},${_f(k)} 0 0 1 -${_f(k)},-${_f(k)}v-${_f(bh - w * .14)}a${_f(k)},${_f(k)} 0 0 1 ${_f(k)},-${_f(k)}z" fill="$a"/>${t(word, w / 2, w * .12, w * .07, Colors.white)}<rect x="${_f((w - c) / 2 - w * .03)}" y="${_f(w * .17)}" width="${_f(c + w * .06)}" height="${_f(c + w * .06)}" rx="${_f(w * .04)}" fill="$b"/>$inner',
      );
    case 'corners':
      final c = w * .74, h = w * (label.isNotEmpty ? 1.12 : 1), k = w * .16, s = w * .025, m = w * .04;
      String corner(double x, double y, int dx, int dy) => '<path d="M${_f(x)},${_f(y + dy * k)}V${_f(y)}H${_f(x + dx * k)}" fill="none" stroke="$a" stroke-width="${_f(s)}" stroke-linecap="round"/>';
      final inner = code(c, (w - c) / 2, (w - c) / 2);
      return svg(
        h,
        '<rect width="${_f(w)}" height="${_f(h)}" rx="${_f(w * .04)}" fill="$b"/>${corner(m, m, 1, 1)}${corner(w - m, m, -1, 1)}${corner(m, w - m, 1, -1)}${corner(w - m, w - m, -1, -1)}$inner${label.isNotEmpty ? t(label, w / 2, w * 1.06, w * .065, ac) : ''}',
      );
    default:
      final inner = qrSvg(text: text, style: d.style, color: fg, bg: back, accent: ac, hole: logo, px: w);
      if (logo) {
        final s = w * .2;
        logoAt = Rect.fromLTWH((w - s) / 2, (w - s) / 2, s, s);
      }
      return QrArt(inner, w, w, logoAt);
  }
}

// what the QR code holds: the short link for codes we can change later, the raw content for Wi-Fi / call / SMS
String _wifiEsc(String s) => s.replaceAllMapped(RegExp(r'([\\;,:"])'), (m) => '\\${m[1]}');
String payloadOf(Json code) {
  final type = str(code['type']);
  if (type == 'wifi') {
    final w = obj(code['wifi']);
    final sec = str(w['security']).isEmpty ? 'WPA' : str(w['security']);
    return 'WIFI:T:$sec;S:${_wifiEsc(str(w['ssid']))};${sec == 'nopass' ? '' : 'P:${_wifiEsc(str(w['password']))};'}${w['hidden'] == true ? 'H:true;' : ''};';
  }
  final num = str(obj(code['phone'])['number']).replaceAll(RegExp(r'[^+\d]'), '');
  if (type == 'phone') return 'tel:$num';
  if (type == 'sms') return 'SMSTO:$num:${str(obj(code['phone'])['body'])}';
  return '${Config.siteUrl}/x/${str(code['slug']).isEmpty ? 'preview' : code['slug']}';
}

bool isStatic(Object? type) => ['wifi', 'phone', 'sms'].contains(type);
String codeUrl(Object? slug) => '${Config.siteUrl}/x/$slug';

Color? _c(Object? hex) {
  final h = '${hex ?? ''}'.replaceFirst('#', '');
  final v = int.tryParse(h, radix: 16);
  return h.length == 6 && v != null ? Color(0xFF000000 | v) : null;
}

QrArt codeArt(Json code, {double size = 320, String scanMe = 'SCAN ME', bool hasLogo = false}) {
  final d = obj(code['design']);
  return qrDesignArt(
    text: payloadOf(code),
    design: str(d['key']).isEmpty ? 'plain' : str(d['key']),
    color: _c(d['color']),
    bg: _c(d['bg']),
    accent: _c(d['accent']),
    label: str(d['label']),
    logo: d['logo'] == true && hasLogo,
    size: size,
    scanMe: scanMe,
  );
}

// one code drawn in its design, with the business logo in the middle when chosen
class QrView extends StatelessWidget {
  final Json code;
  final String logo, scanMe;
  final double size;
  const QrView({super.key, required this.code, this.logo = '', this.size = 160, this.scanMe = 'SCAN ME'});
  @override
  Widget build(BuildContext context) {
    final art = codeArt(code, size: size, scanMe: scanMe, hasLogo: logo.isNotEmpty);
    return SizedBox(
      width: art.width,
      height: art.height,
      child: Stack(
        children: [
          SvgPicture.string(art.svg, width: art.width, height: art.height),
          if (art.logo != null)
            Positioned.fromRect(
              rect: art.logo!,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(art.logo!.width * .18),
                child: Image(image: netImage(logo), fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink()),
              ),
            ),
        ],
      ),
    );
  }
}

// a design drawing without a logo (design lists, the buy screen)
class SvgArt extends StatelessWidget {
  final QrArt art;
  const SvgArt({super.key, required this.art});
  @override
  Widget build(BuildContext context) => SvgPicture.string(art.svg, width: art.width, height: art.height);
}
