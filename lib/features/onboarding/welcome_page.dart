import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers.dart';
import '../../core/site.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'mocks.dart';

const _slideMs = 6500;

// First start: pick the language, then 4 "Get started" screens — the same 4 slides as the website banner.
class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});
  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  late bool _pickLang = !ref.read(prefsProvider.notifier).langChosen;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Brand.roast,
        body: RoastStage(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child: _pickLang ? _LangStep(key: const ValueKey('lang'), onDone: () => setState(() => _pickLang = false)) : const _Slides(key: ValueKey('slides')),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 1 · language
class _LangStep extends ConsumerWidget {
  final VoidCallback onDone;
  const _LangStep({super.key, required this.onDone});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(prefsProvider).lang;
    final t = ref.watch(tProvider);
    Widget option(String code, String big, String small) {
      final on = lang == code;
      return GestureDetector(
        onTap: () => ref.read(prefsProvider.notifier).setLang(code),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: on ? Colors.white : Colors.white.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: on ? Colors.white : Colors.white.withValues(alpha: .18), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? Brand.orange : Colors.white.withValues(alpha: .1),
                ),
                child: Text(
                  code == 'en' ? 'EN' : 'ខ្មែរ',
                  style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: code == 'en' ? 15 : 13),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      big,
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: on ? const Color(0xFF1A1714) : Colors.white, height: 1.3),
                    ),
                    Text(
                      small,
                      style: TextStyle(fontSize: 13, color: on ? const Color(0xFF5A534C) : Colors.white.withValues(alpha: .6)),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: on ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(LucideIcons.circleCheck, color: Brand.orange, size: 26),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(alignment: Alignment.centerLeft, child: Logo(height: 34, white: true)),
            const Spacer(),
            const Icon(LucideIcons.languages, color: Brand.orange, size: 34),
            const SizedBox(height: 18),
            Text(
              t('app.chooseLang'),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white, height: 1.25, letterSpacing: -.5),
            ),
            const SizedBox(height: 8),
            Text(
              t('app.chooseLangSub'),
              style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: .7), height: 1.5),
            ),
            const SizedBox(height: 28),
            option('km', 'ភាសាខ្មែរ', 'Khmer'),
            const SizedBox(height: 12),
            option('en', 'English', 'អង់គ្លេស'),
            const Spacer(flex: 2),
            _BigBtn(label: t('app.continue'), onTap: onDone),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 2 · the slides
class _Slides extends ConsumerStatefulWidget {
  const _Slides({super.key});
  @override
  ConsumerState<_Slides> createState() => _SlidesState();
}

class _SlidesState extends ConsumerState<_Slides> {
  final _pc = PageController();
  int _i = 0;
  bool _hold = false;
  Timer? _timer;
  static const n = 4;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    if (_i >= n - 1 || _hold) return; // stop on the last one (the buttons are there)
    _timer = Timer(const Duration(milliseconds: _slideMs), () => _go(_i + 1));
  }

  void _go(int i) {
    if (!mounted) return;
    _pc.animateToPage(i.clamp(0, n - 1), duration: const Duration(milliseconds: 520), curve: const Cubic(.2, .8, .2, 1));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  void _finish(String to) {
    ref.read(prefsProvider.notifier).finishOnboarding();
    context.go(to);
  }

  @override
  Widget build(BuildContext context) {
    final site = siteOf(ref);
    final t = ref.watch(tProvider).over(site.homeTexts(ref.watch(prefsProvider).lang));
    final v = site.vars(t.lang);
    final slides = [
      (t('home.dashTitle'), t('home.s1a'), t('home.s1b'), t('home.heroSub'), DashboardMock(t: t, play: _i == 0)),
      (t('home.s2e'), t('home.s2a'), t('home.s2b'), t('home.s2d'), OfflineMock(t: t) as Widget),
      (t('home.s4e'), t('home.s4a'), t('home.s4b'), t('home.s4d'), WebsiteMock(t: t) as Widget),
      (t('home.s3e'), t('home.s3a'), t('home.s3b', v), t('home.s3d', v), WalletMock(t: t, site: site) as Widget),
    ];
    final last = _i == n - 1;
    final reduce = MediaQuery.of(context).disableAnimations;
    return SafeArea(
      child: Column(
        children: [
          // top: logo · EN/ខ្មែរ · skip
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
            child: Row(
              children: [
                const Logo(height: 30, white: true),
                const Spacer(),
                const _LangToggle(),
                AnimatedOpacity(
                  opacity: last ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: last ? null : () => _go(n - 1),
                    child: Text(
                      t('app.skip'),
                      style: TextStyle(color: Colors.white.withValues(alpha: .8), fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Listener(
              onPointerDown: (_) {
                _hold = true;
                _timer?.cancel();
              },
              onPointerUp: (_) {
                _hold = false;
                _arm();
              },
              child: PageView.builder(
                controller: _pc,
                itemCount: n,
                onPageChanged: (i) {
                  setState(() => _i = i);
                  _arm();
                },
                itemBuilder: (_, i) {
                  final s = slides[i];
                  return _Slide(on: i == _i, label: s.$1, a: s.$2, b: s.$3, d: s.$4, visual: s.$5);
                },
              ),
            ),
          ),
          // progress tabs, like the website banner
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
            child: Row(
              children: [
                for (var k = 0; k < n; k++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _go(k),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
                        child: _ProgressBar(state: k < _i ? 1 : (k == _i ? 0 : -1), run: k == _i && !last && !reduce, key: ValueKey('$k-$_i')),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: last
                  ? Column(
                      children: [
                        _BigBtn(label: t('home.ctaStart', v), onTap: () => _finish('/signup')),
                        const SizedBox(height: 10),
                        _BigBtn(label: t('app.haveAccount'), ghost: true, onTap: () => _finish('/login')),
                      ],
                    )
                  : _BigBtn(label: t('app.next'), icon: LucideIcons.arrowRight, onTap: () => _go(_i + 1)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final bool on;
  final String label, a, b, d;
  final Widget visual;
  const _Slide({required this.on, required this.label, required this.a, required this.b, required this.d, required this.visual});
  @override
  Widget build(BuildContext context) {
    final km = Localizations.localeOf(context).languageCode == 'km';
    Widget rise(Widget child, int delay) => TweenAnimationBuilder<double>(
      key: ValueKey('rise-$delay-$on'),
      tween: Tween(begin: on ? 0 : 1, end: 1),
      duration: Duration(milliseconds: 700 + delay),
      curve: Interval(delay / (700 + delay), 1, curve: const Cubic(.2, .8, .2, 1)),
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: c),
      ),
      child: child,
    );
    return LayoutBuilder(
      builder: (context, box) {
        final short = box.maxHeight < 560;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(width: 340, child: rise(visual, 80)),
                    ),
                  ),
                ),
              ),
              rise(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .1), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: .16))),
                  child: Text(
                    label,
                    style: const TextStyle(color: Color(0xFFFFD9C2), fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                ),
                0,
              ),
              SizedBox(height: short ? 10 : 14),
              rise(
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$a\n'),
                      TextSpan(
                        text: b,
                        style: TextStyle(color: Colors.white.withValues(alpha: .58)),
                      ),
                    ],
                  ),
                  style: TextStyle(fontSize: short ? 28 : (km ? 30 : 36), fontWeight: FontWeight.w800, color: Colors.white, height: km ? 1.35 : 1.06, letterSpacing: km ? 0 : -1),
                ),
                60,
              ),
              SizedBox(height: short ? 8 : 12),
              rise(
                Text(
                  d,
                  maxLines: short ? 3 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, height: km ? 1.7 : 1.55, color: Colors.white.withValues(alpha: .76)),
                ),
                140,
              ),
              const SizedBox(height: 14),
            ],
          ),
        );
      },
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int state; // -1 not yet · 0 running · 1 done
  final bool run;
  const _ProgressBar({super.key, required this.state, required this.run});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 4,
        color: Colors.white.withValues(alpha: .18),
        alignment: Alignment.centerLeft,
        child: state == 1
            ? Container(color: Brand.orange)
            : state == 0
            ? TweenAnimationBuilder<double>(
                tween: Tween(begin: run ? 0 : 1, end: 1),
                duration: const Duration(milliseconds: _slideMs),
                builder: (_, v, _) => FractionallySizedBox(
                  widthFactor: v,
                  child: Container(color: Brand.orange),
                ),
              )
            : null,
      ),
    );
  }
}

class _LangToggle extends ConsumerWidget {
  const _LangToggle();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(prefsProvider).lang;
    Widget seg(String code, String label) {
      final on = lang == code;
      return GestureDetector(
        onTap: () => ref.read(prefsProvider.notifier).setLang(code),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: on ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(999)),
          child: Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: on ? const Color(0xFF1A1714) : Colors.white.withValues(alpha: .75)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .1), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [seg('en', 'EN'), seg('km', 'ខ្មែរ')]),
    );
  }
}

class _BigBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool ghost;
  final IconData? icon;
  const _BigBtn({required this.label, required this.onTap, this.ghost = false, this.icon});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: ghost ? Colors.white.withValues(alpha: .08) : Brand.orange,
        shape: StadiumBorder(side: ghost ? BorderSide(color: Colors.white.withValues(alpha: .28)) : BorderSide.none),
        clipBehavior: Clip.antiAlias,
        elevation: ghost ? 0 : 10,
        shadowColor: const Color(0xCCE0581A),
        child: InkWell(
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
              ),
              if (icon != null) ...[const SizedBox(width: 8), Icon(icon, color: Colors.white, size: 18)],
            ],
          ),
        ),
      ),
    );
  }
}

