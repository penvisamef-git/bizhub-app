import 'dart:convert';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show GoldBtn;
import 'qg_data.dart';
import 'qr_art.dart';

// QR Code Generator — shared pieces (QgParts.jsx + the dashboard ctx).
//   GET /qrgen → { data: { business, settings, addons, prices, folders, counts, files, designs, themes, slugs } } · GET /qrgen/codes → { data: [codes] }

class QgCtx {
  final String id;
  final Api api;
  final T t;
  final Json data;
  final Future<void> Function() reload;
  final void Function(Json buy) askBuy; // {addon} · {design} · {theme, color} · {print} · {slug: {code, value, done}}
  final void Function(String tab) go;
  final void Function(String text) notify;
  final void Function(Json Function(Json d) patch) put;
  const QgCtx({required this.id, required this.api, required this.t, required this.data, required this.reload, required this.askBuy, required this.go, required this.notify, required this.put});

  String get base => '${Api.user}/businesses/$id/qrgen';
  String get lang => t.lang;
  Json get business => obj(data['business']);
  Json get settings => obj(data['settings']);
  Json get prices => obj(data['prices']);
  Json get files => obj(data['files']);
  Json get counts => obj(data['counts']);
  List<Json> get codes => objs(data['codes']);
  List<Json> get folders => objs(data['folders']);
  String get logo => str(obj(settings['logo'])['url']);
  String get scanMe => m('frameLabelPh');
  Json addon(String k) => obj(obj(data['addons'])[k]);
  bool on(String k) => addon(k)['active'] == true;
  bool get readOnly => business['status'] == false;
  String m(String key, [Map<String, Object?> vars = const {}]) => t('qg.$key', vars);

  void fail(Object e) {
    if (e is ApiError && e.status == 402 && e.body['product'] != null) return askBuy({'addon': str(e.body['product'])});
    if (e is ApiError) return notify(e.network ? t('app.offline') : e.message);
    notify('$e');
  }

  Future<Json?> run(Future<Json> Function() fn, [String? ok]) async {
    try {
      final r = await fn();
      if (ok != null) notify(ok);
      return r;
    } catch (e) {
      fail(e);
      return null;
    }
  }
}

const qrTypeIcons = <String, IconData>{
  'url': LucideIcons.globe,
  'text': LucideIcons.fileText,
  'file': LucideIcons.fileText,
  'form': LucideIcons.inbox,
  'vcard': LucideIcons.userRound,
  'map': LucideIcons.mapPin,
  'wifi': LucideIcons.wifi,
  'phone': LucideIcons.phone,
  'sms': LucideIcons.messageSquare,
  'links': LucideIcons.link2,
  'coupon': LucideIcons.ticket,
};
const typeOrder = ['url', 'links', 'text', 'file', 'form', 'coupon', 'vcard', 'map', 'wifi', 'phone', 'sms'];
const typeNeeds = {'form': 'qr_forms', 'links': 'qr_links', 'coupon': 'qr_coupons'};
const qgAddonIcons = <String, IconData>{
  'qr_forms': LucideIcons.inbox,
  'qr_telegram': LucideIcons.send,
  'qr_stats': LucideIcons.chartColumn,
  'qr_geo': LucideIcons.mapPin,
  'qr_bulk': LucideIcons.layers,
  'qr_rules': LucideIcons.shieldCheck,
  'qr_links': LucideIcons.link2,
  'qr_coupons': LucideIcons.ticket,
  'qr_nobrand': LucideIcons.eyeOff,
  'qr_form_pro': LucideIcons.penLine,
  'qr_smart': LucideIcons.shuffle,
};
const linkIcons = <String, IconData>{
  'web': LucideIcons.globe,
  'facebook': LucideIcons.thumbsUp,
  'tiktok': LucideIcons.music2,
  'telegram': LucideIcons.send,
  'instagram': LucideIcons.camera,
  'youtube': LucideIcons.play,
  'x': LucideIcons.atSign,
  'whatsapp': LucideIcons.messageCircle,
  'messenger': LucideIcons.messagesSquare,
  'line': LucideIcons.messageSquare,
  'linkedin': LucideIcons.briefcaseBusiness,
  'phone': LucideIcons.phone,
  'email': LucideIcons.mail,
  'map': LucideIcons.mapPin,
  'shop': LucideIcons.shoppingBag,
};

String _fileName(Json code) {
  final s = str(code['name']).replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '-').replaceAll(RegExp(r'^-|-$'), '');
  return s.isEmpty ? 'qr' : s;
}

// the logo as base64 (for pictures made from SVG), fetched once
final _logoCache = <String, String>{};
Future<String> _logoB64(String url) async {
  if (url.isEmpty) return '';
  if (_logoCache[url] != null) return _logoCache[url]!;
  try {
    final r = await Dio().get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
    return _logoCache[url] = base64Encode(r.data!);
  } catch (_) {
    return '';
  }
}

// one code as a picture (with the logo inside)
Future<ui.Image> codeImage(QgCtx ctx, Json code, {double size = 900}) async {
  final art = codeArt(code, size: size, scanMe: ctx.scanMe, hasLogo: ctx.logo.isNotEmpty);
  var svg = art.svg;
  if (art.logo != null) {
    final b64 = await _logoB64(ctx.logo);
    if (b64.isNotEmpty) {
      final l = art.logo!;
      svg = svg.replaceFirst(
        RegExp(r'</svg>$'),
        '<image x="${l.left}" y="${l.top}" width="${l.width}" height="${l.height}" href="data:image/png;base64,$b64" preserveAspectRatio="xMidYMid meet"/></svg>',
      );
    }
  }
  final info = await vg.loadPicture(SvgStringLoader(svg), null);
  final img = await info.picture.toImage(art.width.round(), art.height.round());
  info.picture.dispose();
  return img;
}

// the code as a PNG — share sheet
Future<void> shareCodePng(QgCtx ctx, Json code) async {
  final img = await codeImage(ctx, code);
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  if (png == null) return;
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(png.buffer.asUint8List(), mimeType: 'image/png', name: '${_fileName(code)}.png')],
    ),
  );
}

// A4 sheets: codes in a 3 × 4 grid with their names (the web's printCodes) — one PNG per page
Future<void> shareCodeSheets(QgCtx ctx, List<Json> codes, String title) async {
  const w = 1240.0, h = 1754.0, pad = 70.0, gap = 40.0, cols = 3, rowsPer = 4;
  final cell = (w - pad * 2 - gap * (cols - 1)) / cols;
  final files = <XFile>[];
  for (var p = 0; p * cols * rowsPer < codes.length; p++) {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.white);
    final page = codes.skip(p * cols * rowsPer).take(cols * rowsPer).toList();
    var y = pad;
    for (var r = 0; r * cols < page.length; r++) {
      var rowH = 0.0;
      for (var col = 0; col < cols && r * cols + col < page.length; col++) {
        final code = page[r * cols + col];
        final img = await codeImage(ctx, code, size: 600);
        final ih = cell * img.height / img.width;
        final x = pad + col * (cell + gap);
        canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromLTWH(x, y, cell, ih), Paint()..filterQuality = FilterQuality.high);
        final tp = TextPainter(
          text: TextSpan(
            text: str(code['name']),
            style: const TextStyle(color: Color(0xFF1D1F24), fontSize: 26, fontWeight: FontWeight.w700),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          maxLines: 2,
          ellipsis: '…',
        )..layout(maxWidth: cell);
        tp.paint(canvas, Offset(x + (cell - tp.width) / 2, y + ih + 10));
        rowH = rowH < ih + 10 + tp.height ? ih + 10 + tp.height : rowH;
      }
      y += rowH + gap;
    }
    final img = await rec.endRecording().toImage(w.round(), h.round());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    if (png != null) files.add(XFile.fromData(png.buffer.asUint8List(), mimeType: 'image/png', name: '${title.replaceAll(RegExp(r'\s+'), '-')}-${p + 1}.png'));
  }
  if (files.isNotEmpty) await SharePlus.instance.share(ShareParams(files: files));
}

// the code as an SVG file
Future<void> shareCodeSvg(QgCtx ctx, Json code) async {
  final art = codeArt(code, size: 900, scanMe: ctx.scanMe);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(utf8.encode(art.svg), mimeType: 'image/svg+xml', name: '${_fileName(code)}.svg')],
    ),
  );
}

Widget qgPanel(List<Widget> children, {EdgeInsets padding = const EdgeInsets.all(16)}) => Panel(
  padding: padding,
  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
);

Widget qgHead(BuildContext context, IconData icon, String title, String sub, {List<Widget> actions = const []}) => qgPanel([
  Row(
    children: [
      Icon(icon, size: 20, color: context.c.brand),
      const SizedBox(width: 8),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ),
    ],
  ),
  const SizedBox(height: 6),
  Muted(sub),
  if (actions.isNotEmpty) ...[const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: actions)],
]);

// "this needs an add-on" card
class QgLocked extends StatelessWidget {
  final QgCtx ctx;
  final String addon;
  const QgLocked({super.key, required this.ctx, required this.addon});
  @override
  Widget build(BuildContext context) {
    final a = ctx.addon(addon);
    return qgPanel([
      Center(child: Icon(qgAddonIcons[addon] ?? LucideIcons.lock, size: 30, color: context.c.brand)),
      const SizedBox(height: 8),
      Text(
        ctx.m('addonNames.$addon'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      const SizedBox(height: 4),
      Muted(ctx.m('addonWhat.$addon'), align: TextAlign.center),
      const SizedBox(height: 10),
      Center(
        child: GoldBtn(
          ctx.m('unlock', {'coins': '${fmt(n(a['price']))} ${ctx.m('coins')}${a['days'] != null ? ' ${ctx.m('perYear')}' : ''}'}),
          onTap: ctx.readOnly ? null : () => ctx.askBuy({'addon': addon}),
        ),
      ),
    ]);
  }
}

// a one-line "unlock" bar inside a form
class NeedLine extends StatelessWidget {
  final QgCtx ctx;
  final String addon;
  const NeedLine({super.key, required this.ctx, required this.addon});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a = ctx.addon(addon);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.warnBg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.lock, size: 15, color: c.warn),
              const SizedBox(width: 8),
              Expanded(child: Text(ctx.m('addonWhat.$addon'), style: const TextStyle(fontSize: 13))),
            ],
          ),
          const SizedBox(height: 8),
          GoldBtn(ctx.m('unlock', {'coins': '${fmt(n(a['price']))}${a['days'] != null ? ' ${ctx.m('perYear')}' : ''}'}), onTap: ctx.readOnly ? null : () => ctx.askBuy({'addon': addon})),
        ],
      ),
    );
  }
}

// a tiny drawing of the page people see after scanning: free layout (card · banner · minimal) or a paid theme
class ThemeThumb extends StatelessWidget {
  final String template;
  final Color color;
  final String name, business;
  final double width;
  const ThemeThumb({super.key, required this.template, required this.color, this.name = 'Aa', this.business = 'BizHub', this.width = 96});
  @override
  Widget build(BuildContext context) {
    final th = themeOf(template);
    final base = th?.base ?? template;
    final dark = th?.dark ?? false;
    final key = th?.key ?? '';
    final bg = switch (key) {
      'midnight' => const Color(0xFF0F172A),
      'neon' || 'tech' => const Color(0xFF05070D),
      'luxe' => const Color(0xFF111111),
      'paper' => const Color(0xFFF6F1E7),
      'marble' => const Color(0xFFF4F4F5),
      'pastel' => Color.lerp(color, Colors.white, .85)!,
      'retro' => const Color(0xFFFFF4D6),
      'mono' => Colors.white,
      _ => dark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
    };
    final card = dark ? const Color(0xFF1F2937) : Colors.white;
    final ink = dark ? Colors.white : const Color(0xFF111827);
    final acc = key == 'mono' ? Colors.black : (key == 'luxe' ? const Color(0xFFD4AF37) : color);
    Widget pattern() => switch (key) {
      'dots' || 'confetti' || 'bubbles' => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < 30; i++)
            CircleAvatar(radius: key == 'bubbles' ? 4 : 1.6, backgroundColor: (key == 'confetti' ? [color, Colors.amber, Colors.pink, Colors.teal][i % 4] : acc).withValues(alpha: .25)),
        ],
      ),
      'grid' => GridPaper(color: acc.withValues(alpha: .15), interval: 12, divisions: 1, subdivisions: 1, child: const SizedBox.expand()),
      'stripes' => Row(
        children: [for (var i = 0; i < 12; i++) Expanded(child: Container(color: i.isEven ? acc.withValues(alpha: .10) : Colors.transparent))],
      ),
      'aurora' || 'sunrise' || 'glass' => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [acc.withValues(alpha: .45), (key == 'sunrise' ? Colors.amber : Colors.purpleAccent).withValues(alpha: .35)],
          ),
        ),
      ),
      'neon' || 'tech' => Container(
        decoration: BoxDecoration(border: Border.all(color: acc, width: 1)),
      ),
      'leaf' => Align(
        alignment: Alignment.topRight,
        child: Icon(LucideIcons.leaf, size: 40, color: acc.withValues(alpha: .25)),
      ),
      _ => const SizedBox.shrink(),
    };
    final head = Row(
      children: [
        Container(
          width: 16,
          height: 16,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: base == 'banner' ? Colors.white : acc, borderRadius: BorderRadius.circular(5)),
          child: Text(
            business.isEmpty ? 'B' : business.characters.first,
            style: TextStyle(color: base == 'banner' ? acc : Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                business,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 6, color: base == 'banner' ? Colors.white70 : ink.withValues(alpha: .6)),
              ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: base == 'banner' ? Colors.white : ink, fontFamily: key == 'paper' || key == 'luxe' ? 'serif' : null),
              ),
            ],
          ),
        ),
      ],
    );
    Widget rows() => Column(
      children: [
        for (final (a, b) in [('Tel', '012 345 678'), ('Open', '7:00–21:00')])
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                Text(a, style: TextStyle(fontSize: 6, color: ink.withValues(alpha: .55))),
                const Spacer(),
                Text(
                  b,
                  style: TextStyle(fontSize: 6, color: ink, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        const SizedBox(height: 3),
        Container(
          height: 13,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: acc, borderRadius: BorderRadius.circular(key == 'mono' || key == 'retro' ? 2 : 7)),
          child: const Text(
            'Open',
            style: TextStyle(color: Colors.white, fontSize: 6.5, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
    final Widget sheet = switch (base) {
      'banner' => Column(
        children: [
          ClipPath(
            clipper: _Shape(key),
            child: Container(height: 50, color: acc, padding: const EdgeInsets.fromLTRB(8, 8, 8, 14), child: head),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(8, 6, 8, 8), child: rows()),
        ],
      ),
      'minimal' => Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            head,
            Divider(height: 14, color: acc.withValues(alpha: .4)),
            rows(),
          ],
        ),
      ),
      _ => Padding(
        padding: const EdgeInsets.all(7),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: key == 'glass' ? Colors.white.withValues(alpha: .55) : card,
            borderRadius: BorderRadius.circular(key == 'ticket' ? 4 : 10),
            border: Border(top: BorderSide(color: acc, width: 3)),
          ),
          child: Column(children: [head, const SizedBox(height: 8), rows()]),
        ),
      ),
    };
    return SizedBox(
      width: width,
      height: width * 1.25,
      child: FittedBox(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 120,
            height: 150,
            color: bg,
            child: Stack(
              children: [
                Positioned.fill(child: pattern()),
                Positioned.fill(child: sheet),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Shape extends CustomClipper<Path> {
  final String key2;
  _Shape(this.key2);
  @override
  Path getClip(Size s) {
    final p = Path()..lineTo(s.width, 0);
    switch (key2) {
      case 'wave':
      case 'curve':
        p
          ..lineTo(s.width, s.height - 10)
          ..quadraticBezierTo(s.width * .5, s.height + 6, 0, s.height - 10);
      case 'angle':
      case 'split':
        p
          ..lineTo(s.width, s.height - 12)
          ..lineTo(0, s.height);
      default:
        p
          ..lineTo(s.width, s.height)
          ..lineTo(0, s.height);
    }
    return p..close();
  }

  @override
  bool shouldReclip(covariant _Shape old) => old.key2 != key2;
}
