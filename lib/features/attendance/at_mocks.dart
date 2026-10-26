import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../widgets/ui.dart';

import '../../core/i18n.dart';
import 'at_common.dart';

// Small drawn previews for the attendance looks (staff app · QR sticker · door kiosk).
// The web draws the real screens scaled down; the app draws a native sketch of each layout in the chosen colour.

Color shade(Color c, double p) {
  // p > 0 lighter, p < 0 darker (like looks.js shade)
  int f(int v) => (v + (p / 100) * (p > 0 ? 255 - v : v)).round().clamp(0, 255);
  return Color.fromARGB(255, f((c.r * 255).round()), f((c.g * 255).round()), f((c.b * 255).round()));
}

const _gold = Color(0xFFC9A227), _goldDeep = Color(0xFF8C6A12), _angkorRed = Color(0xFF7A1F1F);

Widget _qr(double size, {Color fg = Colors.black, Color bg = Colors.white, String data = 'https://bizhub.app/a/preview'}) => Container(
  color: bg,
  padding: EdgeInsets.all(size * .06),
  child: QrImageView(
    data: data,
    size: size,
    padding: EdgeInsets.zero,
    backgroundColor: bg,
    eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: fg),
    dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: fg),
  ),
);

Widget _logo(String name, String logo, double size, Color bg, Color fg) => Container(
  width: size,
  height: size,
  alignment: Alignment.center,
  clipBehavior: Clip.antiAlias,
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * .28)),
  child: logo.isNotEmpty
      ? Image(image: netImage(logo), fit: BoxFit.cover, width: size, height: size, errorBuilder: (_, _, _) => Text(initial(name)))
      : Text(
          initial(name),
          style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: size * .5),
        ),
);

// ================================================================================================ STAFF APP
// drawn at 195 × 390, scaled to [width]
class AppMock extends StatelessWidget {
  final String theme, name, logo;
  final Color color;
  final bool dark;
  final T t;
  final double width;
  const AppMock({super.key, required this.theme, required this.color, required this.t, this.dark = false, this.name = 'My Company', this.logo = '', this.width = 140});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: width * 2,
    child: FittedBox(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(width: 195, height: 390, child: _screen()),
      ),
    ),
  );

  Widget _screen() {
    final digital = theme == 'digital';
    final dk = dark || digital;
    final bg = digital ? const Color(0xFF0B0F14) : (dk ? const Color(0xFF15161B) : const Color(0xFFF4F5F8));
    final card = dk ? const Color(0xFF22242C) : Colors.white;
    final ink = dk ? Colors.white : const Color(0xFF16171B);
    final muted = dk ? const Color(0xFF9A9CA6) : const Color(0xFF6B6F7B);
    final c = color, cDark = shade(color, -40), cSoft = shade(color, dk ? -70 : 86);
    final out = t('sax.clockOut');
    TextStyle s(double size, {FontWeight w = FontWeight.w700, Color? col}) => TextStyle(fontSize: size, fontWeight: w, color: col ?? ink, height: 1.1);
    Widget head({Color? fg}) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Row(
        children: [
          _logo(name, logo, 26, fg == null ? cSoft : Colors.white24, fg ?? c),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: s(11, col: fg),
            ),
          ),
        ],
      ),
    );
    Widget who({Color? fg}) => Column(
      children: [
        Text(
          '${t('sax.hello')}, Sok Dara',
          style: s(10, w: FontWeight.w600, col: fg ?? muted),
        ),
        const SizedBox(height: 2),
        Text(
          'Day · 08:00–17:00',
          style: s(9, w: FontWeight.w500, col: fg ?? muted),
        ),
      ],
    );
    Widget round(double size, {Color? bgc, Color? fg}) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgc ?? c,
        boxShadow: [BoxShadow(color: (bgc ?? c).withValues(alpha: .35), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.fingerprint, color: fg ?? Colors.white, size: size * .3),
          const SizedBox(height: 3),
          Text(out, style: s(10, col: fg ?? Colors.white)),
        ],
      ),
    );
    Widget pill({double h = 44, Color? bgc, double r = 22, Color? fg}) => Container(
      height: h,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bgc ?? c, borderRadius: BorderRadius.circular(r)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.logOut, size: 15, color: fg ?? Colors.white),
          const SizedBox(width: 6),
          Text(out, style: s(12, col: fg ?? Colors.white)),
        ],
      ),
    );
    Widget inLine({Color? col}) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(LucideIcons.logIn, size: 11, color: col ?? const Color(0xFF16A34A)),
        const SizedBox(width: 4),
        Text('${t('sax.in')} 08:04', style: s(10, col: col ?? const Color(0xFF16A34A))),
      ],
    );
    Widget box(Widget child, {EdgeInsets m = const EdgeInsets.symmetric(horizontal: 14), double r = 18, Color? col}) => Container(
      margin: m,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: col ?? card,
        borderRadius: BorderRadius.circular(r),
        boxShadow: dk ? null : [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: child,
    );

    final Widget body = switch (theme) {
      'hero' => Column(
        children: [
          Container(
            height: 170,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c, cDark]),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              children: [
                head(fg: Colors.white),
                const SizedBox(height: 4),
                Text(
                  '11:30',
                  style: s(44, w: FontWeight.w800, col: Colors.white),
                ),
                who(fg: Colors.white70),
              ],
            ),
          ),
          Transform.translate(offset: const Offset(0, -34), child: round(96)),
          inLine(),
        ],
      ),
      'badge' => Column(
        children: [
          head(),
          box(
            Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  child: Text('S', style: s(24, col: Colors.white)),
                ),
                const SizedBox(height: 8),
                Text('Sok Dara', style: s(15, w: FontWeight.w800)),
                Text(
                  'Cashier',
                  style: s(10, col: muted, w: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: cSoft, borderRadius: BorderRadius.circular(20)),
                  child: Text('11:30 · Day 08:00–17:00', style: s(9, col: c)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          inLine(),
          const Spacer(),
          Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 22), child: pill(h: 48, r: 24)),
        ],
      ),
      'split' => Column(
        children: [
          head(),
          const SizedBox(height: 22),
          Text('11:30', style: s(58, w: FontWeight.w900)),
          who(),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 22),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 90,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.logIn, color: muted, size: 22),
                        Text('08:04', style: s(11, col: muted)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 90,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.logOut, color: Colors.white, size: 22),
                        Text(out, style: s(11, col: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      'minimal' => Column(
        children: [
          head(),
          const Spacer(),
          Text('11:30', style: s(70, w: FontWeight.w200)),
          const SizedBox(height: 6),
          Text(
            'Sok Dara · Day',
            style: s(10, col: muted, w: FontWeight.w400),
          ),
          const Spacer(),
          Container(
            margin: const EdgeInsets.only(bottom: 30),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: c, width: 1.5),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(out, style: s(12, col: c)),
          ),
        ],
      ),
      'ring' => Column(
        children: [
          head(),
          const SizedBox(height: 16),
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(value: .42, strokeWidth: 12, color: c, backgroundColor: cSoft, strokeCap: StrokeCap.round),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('11:30', style: s(32, w: FontWeight.w800)),
                    Text('3h 26m', style: s(10, col: muted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          who(),
          const Spacer(),
          Padding(padding: const EdgeInsets.fromLTRB(30, 0, 30, 22), child: pill()),
        ],
      ),
      'timeline' => Column(
        children: [
          head(),
          box(
            Column(
              children: [
                for (final (time, label, on) in [('08:00', 'Day', false), ('08:04', t('sax.in'), true), ('11:30', '●', true), ('17:00', t('sax.out'), false)])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: on ? c : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(color: c, width: 2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(time, style: s(12, w: FontWeight.w800)),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: s(10, col: muted, w: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 22), child: pill(h: 46, r: 14)),
        ],
      ),
      'glass' => Stack(
        children: [
          Positioned(top: -40, left: -50, child: CircleAvatar(radius: 90, backgroundColor: c.withValues(alpha: .55))),
          Positioned(bottom: 40, right: -60, child: CircleAvatar(radius: 100, backgroundColor: shade(c, 40).withValues(alpha: .5))),
          Column(
            children: [
              head(),
              box(
                Column(
                  children: [
                    Text('11:30', style: s(44, w: FontWeight.w800)),
                    who(),
                  ],
                ),
                col: (dk ? Colors.white : Colors.white).withValues(alpha: dk ? .10 : .55),
              ),
              const SizedBox(height: 26),
              round(
                92,
                bgc: Colors.white.withValues(alpha: dk ? .18 : .7),
                fg: c,
              ),
              const SizedBox(height: 10),
              inLine(),
            ],
          ),
        ],
      ),
      'bold' => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          head(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('11\n30', style: s(72, w: FontWeight.w900)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'SOK DARA',
              style: s(14, w: FontWeight.w900, col: c),
            ),
          ),
          const Spacer(),
          Container(
            height: 86,
            width: double.infinity,
            color: c,
            alignment: Alignment.center,
            child: Text(
              out.toUpperCase(),
              style: s(18, w: FontWeight.w900, col: Colors.white),
            ),
          ),
        ],
      ),
      'digital' => Column(
        children: [
          head(fg: Colors.white),
          const SizedBox(height: 18),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: c, width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '11:30:00',
                style: TextStyle(fontFamily: 'monospace', fontSize: 30, fontWeight: FontWeight.w700, color: shade(c, 35)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final l in ['> IN   08:04  OK', '> SHIFT 08:00–17:00', '> STATUS WORKING'])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: shade(c, 45)),
                ),
              ),
            ),
          const Spacer(),
          Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 22), child: pill(r: 6)),
        ],
      ),
      'ticket' => Column(
        children: [
          head(),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: Row(
                    children: [
                      Text('IN 08:04', style: s(12, col: Colors.white)),
                      const Spacer(),
                      const Icon(LucideIcons.plane, size: 14, color: Colors.white),
                      const Spacer(),
                      Text('OUT 17:00', style: s(12, col: Colors.white)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text('Sok Dara', style: s(14, w: FontWeight.w800)),
                      Text(
                        '11:30',
                        style: s(30, w: FontWeight.w800, col: c),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 20,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (_, k) => Row(
                          children: [for (var i = 0; i < k.maxWidth ~/ 8; i++) Container(width: 4, height: 1.5, margin: const EdgeInsets.only(right: 4), color: muted)],
                        ),
                      ),
                    ),
                    Container(
                      width: 10,
                      height: 20,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                      ),
                    ),
                  ],
                ),
                Padding(padding: const EdgeInsets.all(12), child: pill(h: 40, r: 10)),
              ],
            ),
          ),
        ],
      ),
      'angkor' => Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: _gold, width: 3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: _gold.withValues(alpha: .6), width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              head(),
              const SizedBox(height: 10),
              Container(
                width: 140,
                height: 140,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _gold, width: 4),
                ),
                child: Container(
                  width: 118,
                  height: 118,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _goldDeep, width: 1.5),
                  ),
                  child: Text(
                    '11:30',
                    style: s(30, w: FontWeight.w800, col: dk ? _gold : _goldDeep),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              who(),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                child: pill(bgc: c),
              ),
            ],
          ),
        ),
      ),
      _ => Column(
        // classic
        children: [
          head(),
          box(
            Column(
              children: [
                Text('11:30', style: s(40, w: FontWeight.w800)),
                const SizedBox(height: 2),
                who(),
              ],
            ),
          ),
          const SizedBox(height: 30),
          round(110),
          const SizedBox(height: 14),
          inLine(),
        ],
      ),
    };
    return Container(color: bg, child: body);
  }
}

// ================================================================================================ QR STICKER
class _QrStyle {
  final Color bg, ink, accent, qrBox, qrInk;
  final Gradient? gradient;
  final double radius;
  final Border? border;
  final bool serif;
  const _QrStyle({required this.bg, required this.ink, required this.accent, this.qrBox = Colors.white, this.qrInk = Colors.black, this.gradient, this.radius = 18, this.border, this.serif = false});
}

_QrStyle _qrStyle(String theme) => switch (theme) {
  'minimal' => _QrStyle(
    bg: Colors.white,
    ink: const Color(0xFF222222),
    accent: const Color(0xFF888888),
    radius: 4,
    border: Border.all(color: const Color(0xFFDDDDDD)),
  ),
  'block' => const _QrStyle(bg: Color(0xFF4F46E5), ink: Colors.white, accent: Color(0xFFC7D2FE)),
  'gradient' => const _QrStyle(
    bg: Color(0xFF2563EB),
    ink: Colors.white,
    accent: Color(0xFFE0E7FF),
    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2563EB), Color(0xFF7C3AED)]),
  ),
  'dark' => const _QrStyle(bg: Color(0xFF111111), ink: Colors.white, accent: Color(0xFF9CA3AF), qrBox: Colors.black, qrInk: Colors.white),
  'gold' => _QrStyle(
    bg: const Color(0xFF0E0E0E),
    ink: _gold,
    accent: const Color(0xFFD9C27A),
    border: Border.all(color: _gold, width: 3),
    serif: true,
  ),
  'angkor' => _QrStyle(
    bg: _angkorRed,
    ink: const Color(0xFFF6E7B0),
    accent: _gold,
    border: Border.all(color: _gold, width: 5),
  ),
  'kraft' => const _QrStyle(bg: Color(0xFFC8A57A), ink: Color(0xFF3B2A17), accent: Color(0xFF6B4E2E), radius: 6),
  'ticket' => _QrStyle(
    bg: const Color(0xFFFFF7E6),
    ink: const Color(0xFF7C2D12),
    accent: const Color(0xFFEA580C),
    radius: 10,
    border: Border.all(color: const Color(0xFFEA580C), width: 2),
  ),
  'badge' => const _QrStyle(bg: Colors.white, ink: Color(0xFF0F172A), accent: Color(0xFF0EA5E9), radius: 22),
  'photo' => const _QrStyle(bg: Color(0xFFFAFAF7), ink: Color(0xFF333333), accent: Color(0xFF777777), radius: 2),
  'neon' => _QrStyle(
    bg: Colors.black,
    ink: const Color(0xFF67E8F9),
    accent: const Color(0xFFF0ABFC),
    border: Border.all(color: const Color(0xFF22D3EE), width: 3),
    qrBox: Colors.black,
    qrInk: const Color(0xFF67E8F9),
  ),
  _ => const _QrStyle(bg: Colors.white, ink: Color(0xFF16171B), accent: Color(0xFF4F46E5)),
};

// the printed sticker, drawn 300 wide (100 mm on paper)
class QrSticker extends StatelessWidget {
  final String theme, name, logo, link, note;
  final List<String> hours;
  final double width;
  const QrSticker({super.key, required this.theme, required this.name, required this.link, this.logo = '', this.note = '', this.hours = const [], this.width = 300});

  @override
  Widget build(BuildContext context) {
    final st = _qrStyle(theme);
    final font = st.serif ? 'serif' : null;
    TextStyle s(double size, {FontWeight w = FontWeight.w700, Color? col}) => TextStyle(fontSize: size, fontWeight: w, color: col ?? st.ink, fontFamily: font, height: 1.25);
    final card = Container(
      width: 300,
      padding: EdgeInsets.fromLTRB(22, theme == 'badge' ? 34 : 22, 22, 18),
      decoration: BoxDecoration(
        color: st.gradient == null ? st.bg : null,
        gradient: st.gradient,
        borderRadius: BorderRadius.circular(st.radius),
        border: st.border,
        boxShadow: theme == 'photo' ? [BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 12, offset: const Offset(0, 4))] : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (theme == 'badge')
            Container(
              width: 46,
              height: 9,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(9)),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _logo(name, logo, 36, st.accent.withValues(alpha: .2), st.ink),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: s(17, w: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'វត្តមានបុគ្គលិក · Staff attendance',
            style: s(10, w: FontWeight.w600, col: st.accent),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: st.qrBox,
              borderRadius: BorderRadius.circular(theme == 'photo' ? 0 : 12),
              border: theme == 'neon' ? Border.all(color: const Color(0xFFF0ABFC), width: 2) : null,
            ),
            child: _qr(theme == 'photo' ? 160 : 170, fg: st.qrInk, bg: st.qrBox, data: link),
          ),
          const SizedBox(height: 10),
          Text('ស្កេនដើម្បីចុះវត្តមាន', style: s(15, w: FontWeight.w800)),
          Text(
            'Scan to clock in / out',
            style: s(11, w: FontWeight.w500, col: st.accent),
          ),
          if (hours.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final h in hours)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(color: st.accent.withValues(alpha: .6)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(h, style: s(9.5, w: FontWeight.w600)),
                  ),
              ],
            ),
          ],
          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              note,
              textAlign: TextAlign.center,
              style: s(11, w: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'BizHub · Attendance',
            style: s(8.5, w: FontWeight.w500, col: st.accent.withValues(alpha: .8)),
          ),
          if (theme == 'kraft')
            Align(
              alignment: Alignment.centerRight,
              child: Transform.rotate(
                angle: -.25,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF9B2C2C), width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'STAFF',
                    style: TextStyle(color: Color(0xFF9B2C2C), fontWeight: FontWeight.w900, fontSize: 10),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return SizedBox(
      width: width,
      child: FittedBox(child: card),
    );
  }
}

// ================================================================================================ DOOR KIOSK
// drawn at 320 × 200 (a tablet on its side), scaled to [width]
class KioskMock extends StatelessWidget {
  final String theme, name, logo;
  final Color color;
  final T t;
  final double width;
  const KioskMock({super.key, required this.theme, required this.color, required this.t, this.name = 'My Company', this.logo = '', this.width = 240});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: width * 200 / 320,
    child: FittedBox(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: 320, height: 200, child: _screen()),
      ),
    ),
  );

  Widget _screen() {
    final c = color, cDark = shade(color, -40), cSoft = shade(color, 86);
    String k(String key) => t('kq.$key');
    TextStyle s(double size, {FontWeight w = FontWeight.w700, Color col = const Color(0xFF16171B), String? font}) =>
        TextStyle(fontSize: size, fontWeight: w, color: col, height: 1.15, fontFamily: font);
    Widget clock({Color col = Colors.white, double size = 34, FontWeight w = FontWeight.w800, String? font}) => Text(
      '08:05',
      style: s(size, w: w, col: col, font: font),
    );
    Widget qr(double size, {Color fg = Colors.black, Color bg = Colors.white}) => ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: _qr(size, fg: fg, bg: bg),
    );
    Widget brand({Color col = const Color(0xFF16171B)}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _logo(name, logo, 16, col.withValues(alpha: .15), col),
        const SizedBox(width: 5),
        Text(name, style: s(8, col: col)),
      ],
    );
    Widget scanText({Color col = const Color(0xFF16171B), double size = 10}) => Text(
      k('scan'),
      textAlign: TextAlign.center,
      style: s(size, col: col),
    );
    Widget recent({Color col = const Color(0xFF16171B)}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k('recent'), style: s(7, col: col.withValues(alpha: .7))),
        for (final (nm, tm) in [('Dara', '08:04'), ('Sreyneang', '08:01'), ('Rithy', '07:58')])
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              '● $nm  $tm',
              style: s(7, col: col, w: FontWeight.w600),
            ),
          ),
      ],
    );
    Widget split({required bool qrLeft}) {
      final side = Expanded(
        child: Container(
          color: c,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              brand(col: Colors.white),
              const Spacer(),
              clock(),
              Text(k('attendance'), style: s(9, col: Colors.white70)),
              const Spacer(),
              recent(col: Colors.white),
            ],
          ),
        ),
      );
      final q = Expanded(
        child: Container(
          color: Colors.white,
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [qr(104), const SizedBox(height: 8), scanText()]),
        ),
      );
      return Row(children: qrLeft ? [q, side] : [side, q]);
    }

    Widget tile(Widget child, {Color? col, double r = 12}) => Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: col ?? Colors.white, borderRadius: BorderRadius.circular(r)),
      child: child,
    );

    return switch (theme) {
      'reverse' => split(qrLeft: true),
      'center' => Container(
        color: Colors.white,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            brand(),
            const SizedBox(height: 6),
            qr(110),
            const SizedBox(height: 6),
            scanText(),
            clock(col: c, size: 16),
          ],
        ),
      ),
      'hero' => Container(
        color: Colors.white,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Container(
              height: 80,
              color: c,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  brand(col: Colors.white),
                  const Spacer(),
                  clock(size: 20),
                ],
              ),
            ),
            Positioned(
              top: 46,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                    ),
                    child: qr(100),
                  ),
                  const SizedBox(height: 6),
                  scanText(),
                ],
              ),
            ),
          ],
        ),
      ),
      'dark' => Container(
        color: const Color(0xFF0B0D12),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    brand(col: Colors.white),
                    const Spacer(),
                    clock(col: shade(c, 40)),
                    scanText(col: Colors.white70),
                    const Spacer(),
                  ],
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 22),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c, width: 2),
                boxShadow: [BoxShadow(color: c.withValues(alpha: .7), blurRadius: 18)],
              ),
              child: qr(104),
            ),
          ],
        ),
      ),
      'minimal' => Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  clock(col: const Color(0xFF16171B), size: 54, w: FontWeight.w200),
                  scanText(size: 9),
                ],
              ),
            ),
            qr(84),
          ],
        ),
      ),
      'bold' => Container(
        color: c,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    k('scanShort'),
                    style: s(48, w: FontWeight.w900, col: Colors.white),
                  ),
                  scanText(col: Colors.white, size: 9),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 8)),
              child: qr(100),
            ),
          ],
        ),
      ),
      'card' => Container(
        color: c,
        alignment: Alignment.center,
        child: Container(
          width: 250,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              qr(100),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    brand(),
                    const SizedBox(height: 10),
                    clock(col: c, size: 26),
                    scanText(size: 8.5),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      'ring' => Container(
        color: cSoft,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    brand(),
                    const SizedBox(height: 10),
                    clock(col: cDark),
                    scanText(size: 9),
                    Text(k('next').replaceAll('{s}', '13'), style: s(8, col: cDark)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: CircularProgressIndicator(value: .65, strokeWidth: 8, color: c, backgroundColor: Colors.white),
                    ),
                    ClipOval(
                      child: Container(color: Colors.white, padding: const EdgeInsets.all(22), child: qr(78)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      'gradient' => Stack(
        children: [
          Container(color: shade(c, 70)),
          Positioned(left: -30, top: -30, child: CircleAvatar(radius: 80, backgroundColor: c.withValues(alpha: .6))),
          Positioned(right: -20, bottom: -40, child: CircleAvatar(radius: 90, backgroundColor: shade(c, 30).withValues(alpha: .6))),
          Center(
            child: Container(
              width: 260,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        brand(),
                        const SizedBox(height: 8),
                        clock(col: cDark, size: 28),
                        scanText(size: 9),
                      ],
                    ),
                  ),
                  qr(92),
                ],
              ),
            ),
          ),
        ],
      ),
      'sidebar' => Row(
        children: [
          Container(
            width: 70,
            color: c,
            padding: const EdgeInsets.all(8),
            child: Column(children: [_logo(name, logo, 26, Colors.white24, Colors.white), const Spacer(), clock(size: 16), const Spacer()]),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Column(mainAxisAlignment: MainAxisAlignment.center, children: [qr(100), const SizedBox(height: 6), scanText(size: 8)]),
                  const SizedBox(width: 14),
                  Expanded(child: recent()),
                ],
              ),
            ),
          ),
        ],
      ),
      'ticker' => Column(
        children: [
          Expanded(child: split(qrLeft: false)),
          Container(
            height: 22,
            color: const Color(0xFF16171B),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            child: Text('● Dara ${k('in')} 08:04   ● Sreyneang ${k('in')} 08:01   ● Rithy ${k('in')} 07:58', maxLines: 1, style: s(8, col: Colors.white)),
          ),
        ],
      ),
      'poster' => Container(
        color: const Color(0xFFFFF3D6),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    k('scan'),
                    style: s(22, w: FontWeight.w900, col: cDark),
                  ),
                  const SizedBox(height: 8),
                  Icon(LucideIcons.arrowRight, size: 34, color: c),
                ],
              ),
            ),
            qr(110),
          ],
        ),
      ),
      'welcome' => Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '☀️ ${k('morning')}',
                    style: s(20, w: FontWeight.w800, col: c),
                  ),
                  const SizedBox(height: 4),
                  Text(name, style: s(10, col: const Color(0xFF6B6F7B))),
                  const SizedBox(height: 10),
                  clock(col: const Color(0xFF16171B), size: 22),
                ],
              ),
            ),
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [qr(100), const SizedBox(height: 6), scanText(size: 8)]),
          ],
        ),
      ),
      'stats' || 'bento' => Container(
        color: theme == 'bento' ? const Color(0xFFF1F2F6) : cSoft,
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: tile(Column(mainAxisAlignment: MainAxisAlignment.center, children: [qr(96), const SizedBox(height: 4), scanText(size: 8)])),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Expanded(
                    child: tile(Center(child: clock(size: 22)), col: c),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: tile(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '12/15',
                                  style: s(14, w: FontWeight.w900, col: c),
                                ),
                                Text(k('came'), style: s(6.5)),
                              ],
                            ),
                          ),
                        ),
                        if (theme == 'bento') ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: tile(
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Dara', style: s(10, w: FontWeight.w800)),
                                  Text(k('last'), style: s(6.5)),
                                ],
                              ),
                              col: shade(c, 60),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      'digital' => Container(
        color: const Color(0xFF05080C),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  clock(col: shade(c, 40), font: 'monospace', size: 28),
                  const SizedBox(height: 8),
                  for (final l in ['\$ dara    in  08:04', '\$ sreyneang in 08:01', '\$ rithy   in  07:58', '\$ _'])
                    Text(
                      l,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 8, color: shade(c, 50)),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(border: Border.all(color: shade(c, 40))),
              child: qr(96),
            ),
          ],
        ),
      ),
      'paper' => Container(
        color: const Color(0xFFF7F0E1),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: s(14, col: const Color(0xFF3B2F22), font: 'serif'),
                  ),
                  const SizedBox(height: 6),
                  clock(col: const Color(0xFF3B2F22), size: 30, font: 'serif', w: FontWeight.w500),
                  Text(
                    k('scan'),
                    style: s(9, col: const Color(0xFF6B5B45), font: 'serif', w: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Transform.rotate(
              angle: -.06,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFF9B2C2C), width: 3)),
                child: qr(90, fg: const Color(0xFF3B2F22), bg: const Color(0xFFF7F0E1)),
              ),
            ),
          ],
        ),
      ),
      'angkor' || 'gold' => Container(
        color: theme == 'angkor' ? _angkorRed : const Color(0xFF0C0C0C),
        padding: const EdgeInsets.all(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: _gold, width: theme == 'angkor' ? 4 : 1.5),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    brand(col: _gold),
                    const SizedBox(height: 8),
                    clock(col: _gold, size: 30, font: theme == 'gold' ? 'serif' : null),
                    scanText(col: const Color(0xFFF6E7B0), size: 9),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(border: Border.all(color: _gold, width: 2)),
                child: qr(96),
              ),
            ],
          ),
        ),
      ),
      'pastel' => Container(
        color: shade(c, 80),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: shade(c, 60), borderRadius: BorderRadius.circular(28)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    clock(col: cDark, size: 28),
                    scanText(col: cDark, size: 9),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
              child: qr(96),
            ),
          ],
        ),
      ),
      'diagonal' => Stack(
        children: [
          Container(color: Colors.white),
          ClipPath(
            clipper: _Diag(),
            child: Container(color: c),
          ),
          Positioned(
            left: 16,
            top: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                brand(col: Colors.white),
                const SizedBox(height: 18),
                clock(),
                Text(k('attendance'), style: s(9, col: Colors.white70)),
              ],
            ),
          ),
          Positioned(right: 18, bottom: 16, child: Column(children: [qr(98), const SizedBox(height: 4), scanText(size: 8)])),
        ],
      ),
      'frame' => Container(
        color: cSoft,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  brand(),
                  const SizedBox(height: 10),
                  clock(col: cDark, size: 28),
                  Text(k('hold'), style: s(9, col: cDark)),
                ],
              ),
            ),
            Container(
              width: 110,
              height: 176,
              padding: const EdgeInsets.fromLTRB(8, 20, 8, 20),
              decoration: BoxDecoration(color: const Color(0xFF16171B), borderRadius: BorderRadius.circular(18)),
              child: Container(
                color: Colors.white,
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    qr(80),
                    Positioned(top: 30, left: 0, right: 0, child: Container(height: 2, color: c)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      _ => split(qrLeft: false), // classic
    };
  }
}

class _Diag extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..lineTo(s.width * .62, 0)
    ..lineTo(s.width * .38, s.height)
    ..lineTo(0, s.height)
    ..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
