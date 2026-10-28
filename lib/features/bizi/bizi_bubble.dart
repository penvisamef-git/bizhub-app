import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'bizi_face.dart';
import 'bizi_find.dart';

// Bizi in the owner app (v3.0.0): the helper floating over Dashboard · Business · Wallet · More, like the website.
//   tap → the search screen (/o/bizi) · hold and drag → anywhere on the screen (it stays there next time)
//   every minute while the app is open it reads GET /api/user/bizi/brief: worried + a red dot when something waits,
//   happy for a moment when a new sale / order comes in, and once a day a short summary next to it.

// the last brief (the search screen shows its alerts too)
final biziBriefProvider = StateProvider<Json?>((_) => null);

const _posKey = 'bizi_pos'; // {x, y} as parts of the screen (0–1)
const _dayKey = 'bizi_brief_day'; // the Cambodia day the summary was shown
const size = 60.0;
const _edge = 8.0;

String khDay([DateTime? now]) => (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7)).toIso8601String().substring(0, 10);
int _khHour() => DateTime.now().toUtc().add(const Duration(hours: 7)).hour;
String biziMoney(Object? v, String cur) {
  final n = v is num ? v : num.tryParse('$v') ?? 0;
  if (cur == 'KHR') {
    final s = n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return '$s៛';
  }
  return '\$${n.toStringAsFixed(2)}';
}

class BiziBubble extends ConsumerStatefulWidget {
  const BiziBubble({super.key});
  @override
  ConsumerState<BiziBubble> createState() => _BiziBubbleState();
}

class _BiziBubbleState extends ConsumerState<BiziBubble> with WidgetsBindingObserver {
  Timer? _poll;
  Offset? _pos; // fractions of the screen; null = the corner above the bottom bar
  Offset? _dragAt;
  bool _dragging = false;
  bool _happy = false;
  num? _pulse;
  List<String>? _note; // the lines of the daily summary / "a new sale"
  Timer? _noteTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    try {
      final v = jsonDecode(prefStr(_posKey) ?? 'null');
      if (v is Map && v['x'] is num && v['y'] is num) _pos = Offset((v['x'] as num).toDouble(), (v['y'] as num).toDouble());
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _poll = Timer.periodic(const Duration(minutes: 1), (_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _noteTimer?.cancel();
    super.dispose();
  }

  // back in front → ask now
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    if (!mounted || WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused) return;
    try {
      final b = obj((await ref.read(apiProvider).get('${Api.user}/bizi/brief'))['data']);
      if (!mounted) return;
      ref.read(biziBriefProvider.notifier).state = b;
      _react(b);
    } catch (_) {
      /* offline: keep the last one */
    }
  }

  void _react(Json b) {
    final lang = ref.read(tProvider).lang;
    final before = _pulse;
    final p = b['pulse'] is num ? b['pulse'] as num : 0;
    _pulse = p;
    if (before != null && p > before) {
      setState(() => _happy = true);
      _show([biziT(lang, 'newSale')], seconds: 6, happy: true);
      return;
    }
    if (prefStr(_dayKey) == khDay()) return;
    final s = obj(b['summary']);
    final h = _khHour();
    final cur = str(s['currency']).isEmpty ? 'USD' : str(s['currency']);
    final lines = [
      biziT(
        lang,
        'hello.${h < 12
            ? 'morning'
            : h < 17
            ? 'afternoon'
            : 'evening'}',
      ),
    ];
    final y = s['yesterday'] is num ? s['yesterday'] as num : 0;
    final td = s['today'] is num ? s['today'] as num : 0;
    if (y > 0) {
      lines.add(biziT(lang, 'yesterday', {'money': biziMoney(y, cur)}));
    } else if (td > 0) {
      lines.add(biziT(lang, 'todaySoFar', {'money': biziMoney(td, cur)}));
    }
    final pct = s['change_pct'];
    if (pct is num) lines.add(biziT(lang, 'week', {'pct': '${pct > 0 ? '+' : ''}$pct%'}));
    final n = objs(b['alerts']).length;
    lines.add(
      n == 1 && biziHas(lang, 'needYou1')
          ? biziT(lang, 'needYou1')
          : n > 0
          ? biziT(lang, 'needYou', {'n': n})
          : biziT(lang, 'allGood'),
    );
    prefSetStr(_dayKey, khDay());
    _show(lines, seconds: 15);
  }

  void _show(List<String> lines, {required int seconds, bool happy = false}) {
    _noteTimer?.cancel();
    setState(() => _note = lines);
    _noteTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted) return;
      setState(() {
        _note = null;
        if (happy) _happy = false;
      });
    });
  }

  void _open() {
    _noteTimer?.cancel();
    setState(() => _note = null);
    context.push('/o/bizi');
  }

  // where the bubble's top-left corner is, inside the screen (above the bottom bar by default)
  Offset _px(Size screen, EdgeInsets pad) {
    final maxX = screen.width - size - _edge;
    final maxY = screen.height - size - _edge - pad.bottom;
    if (_pos == null) return Offset(maxX - 8, maxY - 84);
    return Offset((_pos!.dx * screen.width).clamp(_edge, maxX), (_pos!.dy * screen.height).clamp(_edge + pad.top, maxY));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final lang = ref.watch(tProvider).lang;
    final brief = ref.watch(biziBriefProvider);
    final alerts = objs(brief?['alerts']);
    final warn = alerts.where((a) => a['level'] == 'warn').length;
    final mq = MediaQuery.of(context);
    final at = _dragAt ?? _px(mq.size, mq.padding);
    final mood = _dragging || _happy ? BiziMood.happy : (brief?['mood'] == 'worried' ? BiziMood.worried : BiziMood.idle);
    final noteLeft = at.dx > mq.size.width / 2;
    return Stack(
      children: [
        if (_note != null && !_dragging)
          Positioned(
            top: at.dy + size / 2 - 40,
            left: noteLeft ? null : at.dx + size + 8,
            right: noteLeft ? mq.size.width - at.dx + 8 : null,
            child: GestureDetector(
              onTap: _open,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: (mq.size.width * .62).clamp(160, 280)),
                child: Container(
                  key: const ValueKey('bizi-note'),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
                  decoration: BoxDecoration(
                    color: _happy ? null : c.solid,
                    gradient: _happy ? LinearGradient(colors: c.grad) : null,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: c.popShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _note!.first,
                        style: TextStyle(color: _happy ? Colors.white : c.onSolid, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      for (final l in _note!.skip(1)) Text(l, style: TextStyle(color: (_happy ? Colors.white : c.onSolid).withValues(alpha: .85), fontSize: 12.5, height: 1.35)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: at.dx,
          top: at.dy,
          child: Semantics(
            button: true,
            label: '${biziT(lang, 'open')}. ${biziT(lang, 'dragHint')}',
            child: GestureDetector(
              key: const ValueKey('bizi-bubble'),
              onTap: _open,
              onPanStart: (_) => setState(() {
                _dragging = true;
                _dragAt = at;
              }),
              onPanUpdate: (d) => setState(() {
                final p = (_dragAt ?? at) + d.delta;
                _dragAt = Offset(p.dx.clamp(_edge, mq.size.width - size - _edge), p.dy.clamp(_edge + mq.padding.top, mq.size.height - size - _edge - mq.padding.bottom));
              }),
              onPanEnd: (_) => setState(() {
                final p = _dragAt ?? at;
                _pos = Offset(p.dx / mq.size.width, p.dy / mq.size.height);
                _dragAt = null;
                _dragging = false;
                prefSetStr(_posKey, jsonEncode({'x': _pos!.dx, 'y': _pos!.dy}));
              }),
              child: AnimatedScale(
                scale: _dragging ? 1.1 : 1,
                duration: const Duration(milliseconds: 120),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(color: c.card, shape: BoxShape.circle, boxShadow: c.popShadow),
                      alignment: Alignment.center,
                      child: BiziFace(mood: mood, size: size - 12),
                    ),
                    if (warn > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          key: const ValueKey('bizi-dot'),
                          constraints: const BoxConstraints(minWidth: 22),
                          height: 22,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFB42318),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: c.card, width: 2),
                          ),
                          child: Text(
                            warn > 9 ? '9+' : '$warn',
                            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                      )
                    else if (alerts.isNotEmpty)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: c.brand,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.card, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
