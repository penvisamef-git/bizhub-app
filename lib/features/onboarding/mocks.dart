import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/site.dart';
import '../../core/theme.dart';

// The pictures of the homepage banner (homepage/HeroCarousel.jsx + HeroBanner.jsx), drawn in Flutter.
// They always use the light "panel" look, like on the website's dark banner.

const _ink = Color(0xFF1A1714);
const _muted = Color(0xFF5A534C);
const _line = Color(0xFFECE7E0);
const _bar = Color(0xFFF4CDB5);
const _good = Color(0xFF2F6B2F), _goodBg = Color(0xFFE3F1DF), _warn = Color(0xFF8A4B0E), _warnBg = Color(0xFFFCE9D6);

BoxDecoration _panel() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(24),
  boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 50, offset: Offset(0, 24))],
);

Widget _badge(String text, bool good) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
  decoration: BoxDecoration(color: good ? _goodBg : _warnBg, borderRadius: BorderRadius.circular(999)),
  child: Text(
    text,
    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: good ? _good : _warn),
  ),
);

// gentle up-and-down like the web's .float
class Floaty extends StatefulWidget {
  final Widget child;
  final double amount;
  final int ms;
  const Floaty({super.key, required this.child, this.amount = 8, this.ms = 3200});
  @override
  State<Floaty> createState() => _FloatyState();
}

class _FloatyState extends State<Floaty> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: Duration(milliseconds: widget.ms))..repeat(reverse: true);
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedBuilder(
      animation: _a,
      builder: (_, child) => Transform.translate(offset: Offset(0, -widget.amount * Curves.easeInOut.transform(_a.value)), child: child),
      child: widget.child,
    );
  }
}

class DashboardMock extends StatelessWidget {
  final T t;
  final bool play; // bars grow when the slide comes in
  const DashboardMock({super.key, required this.t, this.play = true});
  @override
  Widget build(BuildContext context) {
    const bars = [42, 58, 50, 72, 64, 86, 100];
    final rows = [
      (t('home.sRestaurant'), r'$412', const Color(0xFFE0581A), true, t('home.online')),
      (t('home.sMart'), r'$286', const Color(0xFFD9A51A), false, t('home.syncing')),
      (t('home.sGuest'), r'$180', const Color(0xFF9DB01C), true, t('home.online')),
      (t('home.sWarehouse'), '—', _muted, true, t('home.online')),
    ];
    return Floaty(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _panel(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t('home.dashTitle'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFEEF3CF), borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    '${t('home.dashCoins')} · 1,250',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF525C0E)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 92,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < bars.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey(play),
                          tween: Tween(begin: play ? .1 : 1, end: 1),
                          duration: Duration(milliseconds: 900 + i * 80),
                          curve: const Cubic(.2, .8, .2, 1),
                          builder: (_, v, _) => FractionallySizedBox(
                            heightFactor: bars[i] / 100 * v,
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              decoration: BoxDecoration(
                                color: i == bars.length - 1 ? null : _bar,
                                gradient: i == bars.length - 1 ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF08A1E), Color(0xFFE0581A)]) : null,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < rows.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: _line)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(color: rows[i].$3, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        rows[i].$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _ink),
                      ),
                    ),
                    Text(
                      rows[i].$2,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _ink),
                    ),
                    const SizedBox(width: 8),
                    _badge(rows[i].$5, rows[i].$4),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class OfflineMock extends StatelessWidget {
  final T t;
  const OfflineMock({super.key, required this.t});
  @override
  Widget build(BuildContext context) {
    Widget line(String a, String b) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(a, style: const TextStyle(fontSize: 14, color: _ink)),
          ),
          Text(
            b,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
          ),
        ],
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Floaty(
          child: Container(
            margin: const EdgeInsets.only(right: 24, bottom: 36),
            padding: const EdgeInsets.all(20),
            decoration: _panel(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t('home.cashier'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _ink),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(color: _warnBg, borderRadius: BorderRadius.circular(999)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _PulseDot(),
                          const SizedBox(width: 6),
                          Text(
                            t('home.offline'),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _warn),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                line('Iced latte × 2', r'$5.00'),
                line('Fried rice', r'$3.50'),
                line('Water', r'$0.50'),
                Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 10),
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFDDD7CE))),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Total',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink),
                        ),
                      ),
                      Text(
                        r'$9.00',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink),
                      ),
                    ],
                  ),
                ),
                Text(
                  t('home.queued'),
                  style: const TextStyle(fontSize: 12.5, color: _muted),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Floaty(
            amount: 6,
            ms: 2600,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
              decoration: _panel().copyWith(borderRadius: BorderRadius.circular(18)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(color: _goodBg, shape: BoxShape.circle),
                    child: const Icon(LucideIcons.check, size: 17, color: _good),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    t('home.synced'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, _) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: const Color(0xFFD9A51A),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: const Color(0xFFD9A51A).withValues(alpha: (1 - _a.value) * .6), spreadRadius: 6 * _a.value)],
      ),
    ),
  );
}

class WebsiteMock extends StatelessWidget {
  final T t;
  const WebsiteMock({super.key, required this.t});
  @override
  Widget build(BuildContext context) {
    Widget block(double h, {double? w}) => Container(
      height: h,
      width: w,
      decoration: BoxDecoration(color: const Color(0xFFF3F0EB), borderRadius: BorderRadius.circular(10)),
    );
    return Floaty(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _panel(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    for (final _ in [1, 2, 3])
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: const BoxDecoration(color: Color(0xFFDDD7CE), shape: BoxShape.circle),
                      ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFF3F0EB), borderRadius: BorderRadius.circular(999)),
                      child: const Text('/site/sokha-coffee', style: TextStyle(fontSize: 11.5, color: _muted)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(colors: [Color(0xFFE0581A), Color(0xFFF08A1E), Color(0xFFB4C21C)]),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sokha Coffee',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      Text(
                        t('home.s4b'),
                        style: const TextStyle(fontSize: 12, color: Color(0xFFFFF1E6)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: block(54)),
                    const SizedBox(width: 8),
                    Expanded(child: block(54)),
                    const SizedBox(width: 8),
                    Expanded(child: block(54)),
                  ],
                ),
                const SizedBox(height: 10),
                block(8),
                const SizedBox(height: 6),
                block(8, w: 160),
                const SizedBox(height: 18),
              ],
            ),
          ),
          Positioned(
            right: -6,
            bottom: -14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF1F9D55),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [BoxShadow(color: Color(0x551F9D55), blurRadius: 24, offset: Offset(0, 10))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.check, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    t('home.publish'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WalletMock extends StatelessWidget {
  final T t;
  final SiteInfo site;
  const WalletMock({super.key, required this.t, required this.site});
  @override
  Widget build(BuildContext context) {
    return Floaty(
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFB9420C), Color(0xFFE0681A), Color(0xFF9AA516)], stops: [0, .55, 1]),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 50, offset: Offset(0, 24))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t('home.wallet'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFFFE9DA)),
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFFFFD25E), Color(0xFFF0A020)]),
                  ),
                  child: const Text(
                    'B',
                    style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF9A5400), fontSize: 17),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              t('home.bonus'),
              style: const TextStyle(fontSize: 13, color: Color(0xFFFFE9DA)),
            ),
            Text(
              '+${site.vars(t.lang)['bonus']}',
              style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1, letterSpacing: -1.5),
            ),
            Text(
              t('home.coinPrice', site.vars(t.lang)),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFFFE9DA)),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in site.payments)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(999)),
                    child: Text(
                      m,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// the dark banner background: roast brown, orange + lime glows, faint grid
class RoastStage extends StatelessWidget {
  final Widget child;
  const RoastStage({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Brand.roast2, Brand.roast]),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          const Positioned(left: -180, top: -200, child: _Glow(size: 520, color: Color(0x6BE0581A))),
          const Positioned(right: -160, bottom: -180, child: _Glow(size: 440, color: Color(0x42B4C21C))),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;
  const _Glow({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
    ),
  );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x0DFFF7EF)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 48) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 48) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
