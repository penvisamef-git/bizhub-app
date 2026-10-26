import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/color_pick.dart';
import '../../widgets/look_sheet.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show mGap, fileForm;
import '../restaurant/rest_common.dart' show Segmented, SwitchRow, gap14;
import 'fb_common.dart';
import 'fb_data.dart';

// FbLook.jsx: Library design · Library info · Reader looks

const _presets = ['#E0581A', '#DC2626', '#DB2777', '#9333EA', '#4F46E5', '#0284C7', '#0D9488', '#16A34A', '#CA8A04', '#78350F', '#334155', '#111111'];
const _layouts = ['shelf', 'grid', 'magazine', 'carousel', 'list', 'wall', 'spotlight', 'stack'];

Future<Json?> saveFb(FbCtx ctx, Json body) async {
  final r = await ctx.run(() => ctx.api.put('${ctx.base}/settings', body), ctx.m('saved'));
  if (r != null) ctx.put((_) => {'settings': obj(r['data'])});
  return r;
}

// falling / floating dots for the live designs (snow, rain, stars, bubbles…)
class _LiveDots extends StatefulWidget {
  final String effect;
  final Color color;
  const _LiveDots({required this.effect, required this.color});
  @override
  State<_LiveDots> createState() => _LiveDotsState();
}

class _LiveDotsState extends State<_LiveDots> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _a,
      builder: (_, _) => CustomPaint(painter: _DotsPainter(widget.effect, widget.color, _a.value), size: Size.infinite),
    ),
  );
}

class _DotsPainter extends CustomPainter {
  final String effect;
  final Color color;
  final double t;
  _DotsPainter(this.effect, this.color, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final up = ['bubbles', 'fireflies', 'sparkles', 'glow', 'lava'].contains(effect);
    final still = ['stars', 'aurora', 'rays', 'clouds', 'synthgrid'].contains(effect);
    for (var i = 0; i < 26; i++) {
      final x0 = rnd.nextDouble(), y0 = rnd.nextDouble(), sp = .4 + rnd.nextDouble() * .8, r = 1.0 + rnd.nextDouble() * 2.4;
      var y = still ? y0 : (y0 + (up ? -1 : 1) * t * sp) % 1.0;
      if (y < 0) y += 1;
      final x = x0 + (still ? 0 : math.sin((t * 2 * math.pi) + i) * .015);
      final a = still ? (.35 + .65 * (.5 + .5 * math.sin(t * 2 * math.pi * 2 + i))) : .8;
      final p = Paint()..color = color.withValues(alpha: a.clamp(0, 1).toDouble());
      if (effect == 'rain') {
        canvas.drawLine(Offset(x * size.width, y * size.height), Offset(x * size.width - 1.5, y * size.height + 7), p..strokeWidth = 1.2);
      } else {
        canvas.drawCircle(Offset(x * size.width, y * size.height), effect == 'bubbles' ? r * 1.6 : r, effect == 'bubbles' ? (p..style = PaintingStyle.stroke) : p);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.t != t;
}

// a small drawing of the public library in a design, with the real covers
class ShelfMini extends StatelessWidget {
  final String theme, title;
  final Color? color;
  final List<String> covers;
  final bool moving, small;
  const ShelfMini({super.key, required this.theme, required this.title, this.color, this.covers = const [], this.moving = false, this.small = false});

  @override
  Widget build(BuildContext context) {
    final t = fbShelves[theme] ?? fbShelves['classic']!;
    final accent = color ?? Color(t.accent);
    final ink = Color(t.ink), surface = Color(t.surface);
    final plank = t.plank.isEmpty ? [accent, accent] : t.plank.map(Color.new).toList();
    Widget cover(int i, {double r = 2}) {
      final u = covers.isEmpty ? '' : covers[i % covers.length];
      return Container(
        decoration: BoxDecoration(
          color: Color.lerp(accent, surface, .3 + (i % 3) * .15),
          borderRadius: BorderRadius.circular(r),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 3, offset: const Offset(1, 2))],
        ),
        clipBehavior: Clip.antiAlias,
        child: u.isEmpty || small ? null : Image(image: netImage(u), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
      );
    }

    Widget planks(int rows, int per) => Column(
      children: [
        for (var r = 0; r < rows; r++)
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < per; i++) ...[if (i > 0) const SizedBox(width: 4), Expanded(child: FractionallySizedBox(heightFactor: .86, child: cover(r * per + i)))],
                      ],
                    ),
                  ),
                ),
                Container(
                  height: small ? 3 : 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: plank.length > 1 ? plank.take(2).toList() : [plank.first, plank.first]),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    Widget grid(int cols, int rows, {double gap = 5, bool card = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          for (var r = 0; r < rows; r++) ...[
            if (r > 0) SizedBox(height: gap),
            Expanded(
              child: Row(
                children: [
                  for (var i = 0; i < cols; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    Expanded(
                      child: card
                          ? Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(5)),
                              child: Column(
                                children: [
                                  Expanded(child: cover(r * cols + i)),
                                  const SizedBox(height: 2),
                                  Container(height: 2, color: ink.withValues(alpha: .3)),
                                ],
                              ),
                            )
                          : cover(r * cols + i),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
    final body = switch (t.layout) {
      'grid' => grid(3, 2, card: true),
      'magazine' => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            Expanded(flex: 3, child: cover(0, r: 4)),
            const SizedBox(width: 5),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Expanded(child: cover(1)),
                  const SizedBox(height: 5),
                  Expanded(child: cover(2)),
                ],
              ),
            ),
          ],
        ),
      ),
      'carousel' => Column(
        children: [
          for (var r = 0; r < 2; r++) ...[
            if (r > 0) const SizedBox(height: 6),
            Expanded(
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  for (var i = 0; i < 4; i++) ...[if (i > 0) const SizedBox(width: 4), Expanded(flex: i == 3 ? 1 : 2, child: cover(r * 4 + i))],
                ],
              ),
            ),
          ],
        ],
      ),
      'list' => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(height: 4),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    children: [
                      AspectRatio(aspectRatio: .72, child: cover(i)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FractionallySizedBox(widthFactor: .8, child: Container(height: 3, color: ink.withValues(alpha: .6))),
                            const SizedBox(height: 3),
                            FractionallySizedBox(widthFactor: .5, child: Container(height: 2, color: ink.withValues(alpha: .3))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      'wall' => grid(4, 2, gap: 2),
      'spotlight' => Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: RadialGradient(colors: [accent.withValues(alpha: .35), Colors.transparent], radius: .8)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: FractionallySizedBox(heightFactor: i == 1 ? 1 : .8, child: cover(i)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      'stack' => Center(
        child: SizedBox(
          width: 110,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 2; i >= 0; i--)
                Transform.rotate(
                  angle: (i - 1) * .18,
                  child: FractionallySizedBox(widthFactor: .55, heightFactor: .85, child: cover(i)),
                ),
            ],
          ),
        ),
      ),
      _ => planks(2, 4),
    };
    return Container(
      decoration: BoxDecoration(color: Color(t.bg), borderRadius: BorderRadius.circular(small ? 8 : 12)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (t.isLive && moving)
            Positioned.fill(
              child: _LiveDots(effect: t.live, color: Color(t.fx)),
            ),
          Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(8, small ? 5 : 8, 8, small ? 4 : 6),
                child: Row(
                  children: [
                    Container(
                      width: small ? 6 : 10,
                      height: small ? 6 : 10,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        small ? 'Aa' : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: small ? 9 : 12, fontFamily: 'serif'),
                      ),
                    ),
                    if (t.isLive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          'LIVE',
                          style: TextStyle(fontSize: small ? 6.5 : 8, fontWeight: FontWeight.w900, color: accent.computeLuminance() > .5 ? Colors.black : Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(child: body),
              SizedBox(height: small ? 5 : 8),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------- library design
class LibraryTab extends StatefulWidget {
  final FbCtx ctx;
  const LibraryTab({super.key, required this.ctx});
  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  FbCtx get ctx => widget.ctx;
  late String _try = str(ctx.settings['shelf_theme']).isEmpty ? 'classic' : str(ctx.settings['shelf_theme']);
  late String _color = str(ctx.settings['color']).toUpperCase();
  late String _kind = fbShelves[_try]?.isLive == true ? 'live' : 'standard';
  String _filter = 'all', _busy = '';

  List<String> get _owned => (ctx.data['shelf_themes'] as List? ?? const ['classic']).map((e) => '$e').toList();
  num _price(String k) => n(ctx.prices[fbShelves[k]?.isLive == true ? 'fb_shelf_live' : 'fb_shelf_theme']);

  Future<void> _save(Json body, String what) async {
    setState(() => _busy = what);
    await saveFb(ctx, body);
    if (mounted) setState(() => _busy = '');
  }

  bool _using(String k) => ctx.settings['shelf_theme'] == k || (k == 'classic' && str(ctx.settings['shelf_theme']).isEmpty);
  bool _mine(String k) => _owned.contains(k) || k == 'classic';
  Widget _status(String k, C c) {
    if (_using(k)) {
      return Text(ctx.m('inUse'), style: TextStyle(color: c.good, fontWeight: FontWeight.w800, fontSize: 12));
    }
    if (_mine(k)) {
      return Text(ctx.m(k == 'classic' ? 'free' : 'owned'), style: TextStyle(color: c.muted, fontWeight: FontWeight.w700, fontSize: 12));
    }
    return Row(
      children: [
        const CoinIcon(size: 12),
        const SizedBox(width: 4),
        Text(
          fmt(_price(k)),
          style: TextStyle(color: c.muted, fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ],
    );
  }

  // tap a design → the design sheet (big moving shelf, swipe for the next), Use / Buy at the bottom
  Future<void> _open(String key, List<String> list) async {
    final covers = ctx.books.where((b) => b['published'] != false).map((b) => str(b['cover'])).where((u) => u.isNotEmpty).toList();
    final colorVal = _color.isEmpty ? null : hexColor(_color);
    setState(() => _try = key);
    await showLookSheet(
      context,
      title: ctx.m('libTitle'),
      count: list.length,
      initial: list.contains(key) ? list.indexOf(key) : 0,
      item: (context, i, refresh) {
        final k = list[i];
        final t = fbShelves[k]!;
        return LookItem(
          name: t.name(ctx.lang),
          sub: '${ctx.m('layouts.${t.layout}')}${t.isLive ? ' · ✨ ${ctx.m('kindLive')}' : ''}',
          badge: _using(k) ? ctx.m('inUse') : (_mine(k) ? ctx.m(k == 'classic' ? 'free' : 'owned') : '${fmt(_price(k))} ${ctx.m('coins')}'),
          badgeTone: _using(k) || _mine(k) ? Tone.good : Tone.warn,
          preview: SizedBox(
            width: 340,
            height: 252,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ShelfMini(theme: k, title: ctx.libName, color: colorVal, covers: covers, moving: true),
            ),
          ),
          acts: [
            if (!_using(k) && _mine(k))
              LookAct(
                ctx.m('use'),
                icon: LucideIcons.check,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        await saveFb(ctx, {'shelf_theme': k});
                        return true;
                      },
              ),
            if (!_mine(k))
              LookAct(
                ctx.m('buy', {'coins': fmt(_price(k))}),
                gold: true,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        ctx.askBuy({
                          'shelf': k,
                          'stage': SizedBox(
                            width: 200,
                            height: 148,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: ShelfMini(theme: k, title: ctx.libName, covers: covers),
                            ),
                          ),
                        });
                        return true;
                      },
              ),
          ],
        );
      },
    );
    if (mounted) setState(() => _try = str(ctx.settings['shelf_theme']).isEmpty ? 'classic' : str(ctx.settings['shelf_theme']));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final owned = _owned;
    final standard = fbShelves.keys.where((k) => !fbShelves[k]!.isLive).toList();
    final live = fbShelves.keys.where((k) => fbShelves[k]!.isLive).toList();
    final list = _filter == 'mine' ? fbShelves.keys.where((k) => owned.contains(k) || k == 'classic').toList() : (_kind == 'live' ? live : standard);
    final shown = list.where((k) => _filter == 'all' || _filter == 'mine' || fbShelves[k]!.layout == _filter).toList();
    final design = fbShelves[_try] ?? fbShelves['classic']!;
    final covers = ctx.books.where((b) => b['published'] != false).map((b) => str(b['cover'])).where((u) => u.isNotEmpty).toList();
    final colorVal = _color.isEmpty ? null : hexColor(_color);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        fbHead(
          context,
          LucideIcons.library,
          ctx.m('libTitle'),
          ctx.m('libSub2', {'n': standard.length - 1, 'coins': fmt(n(ctx.prices['fb_shelf_theme'])), 'live': live.length, 'lcoins': fmt(n(ctx.prices['fb_shelf_live']))}),
          actions: [
            Btn(
              ctx.m('openLibrary'),
              icon: LucideIcons.eye,
              kind: BtnKind.ghost,
              small: true,
              onTap: () => launchUrl(Uri.parse(shelfUrl(ctx.settings['slug'])), mode: LaunchMode.externalApplication),
            ),
          ],
        ),
        mGap,
        fbPanel([
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(design.name(ctx.lang), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                    Muted('${ctx.m('preview')} · ${ctx.m('layouts.${design.layout}')}'),
                  ],
                ),
              ),
              _status(_try, c),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _open(_try, fbShelves.keys.toList()),
            child: AspectRatio(
              aspectRatio: 1.35,
              child: ShelfMini(theme: _try, title: ctx.libName, color: colorVal, covers: covers, moving: true),
            ),
          ),
        ]),
        mGap,
        fbPanel([
          Segmented<String>(
            value: _filter == 'mine' ? '' : _kind,
            options: [('standard', '${ctx.m('kindStandard')} ${standard.length}'), ('live', '✨ ${ctx.m('kindLive')} ${live.length}')],
            onChanged: (v) => setState(() {
              _kind = v;
              if (_filter == 'mine') _filter = 'all';
            }),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final f in ['all', 'mine', ..._layouts])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        f == 'all'
                            ? ctx.m('filterAll')
                            : f == 'mine'
                            ? '${ctx.m('filterMine')} (${owned.length})'
                            : ctx.m('layouts.$f'),
                      ),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          if (_kind == 'live' && _filter != 'mine') ...[
            const SizedBox(height: 6),
            Muted('✨ ${ctx.m('liveNote', {'coins': fmt(n(ctx.prices['fb_shelf_live']))})}'),
          ],
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 170, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .72),
            itemCount: shown.length,
            itemBuilder: (_, i) {
              final k = shown[i];
              final t = fbShelves[k]!;
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _open(k, shown),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: c.bg2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _using(k) ? c.brand : Colors.transparent, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ShelfMini(theme: k, title: '', small: true),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.name(ctx.lang),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                      ),
                      Text(ctx.m('layouts.${t.layout}'), style: TextStyle(color: c.muted, fontSize: 11)),
                      const SizedBox(height: 4),
                      _status(k, c),
                    ],
                  ),
                ),
              );
            },
          ),
        ]),
        mGap,
        fbPanel([
          Text(ctx.m('colour'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
          Muted(ctx.m('colourSub')),
          const SizedBox(height: 10),
          ColorRow(
            value: _color.isEmpty ? '#${(design.accent & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}' : _color,
            colors: _presets,
            customLabel: ctx.m('colour'),
            saveLabel: ctx.m('save'),
            cancelLabel: ctx.m('cancel'),
            onChanged: (v) => setState(() => _color = v.toUpperCase()),
          ),
          gap14,
          Wrap(
            spacing: 8,
            children: [
              Btn(ctx.m('resetColour'), icon: LucideIcons.rotateCcw, kind: BtnKind.ghost, small: true, onTap: ctx.readOnly ? null : () => setState(() => _color = '')),
              Btn(
                ctx.m('save'),
                icon: LucideIcons.save,
                small: true,
                busy: _busy == 'colour',
                onTap: ctx.readOnly || _busy.isNotEmpty || _color == str(ctx.settings['color']).toUpperCase() ? null : () => _save({'color': _color}, 'colour'),
              ),
            ],
          ),
        ]),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------- library info
class InfoTab extends StatefulWidget {
  final FbCtx ctx;
  const InfoTab({super.key, required this.ctx});
  @override
  State<InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends State<InfoTab> {
  FbCtx get ctx => widget.ctx;
  late final _title = TextEditingController(text: str(ctx.settings['title']));
  late final _about = TextEditingController(text: str(ctx.settings['about']));
  late final _slug = TextEditingController(text: str(ctx.settings['slug']));
  late String _lang = str(ctx.settings['lang']).isEmpty ? 'km' : str(ctx.settings['lang']);
  late final Map<String, TextEditingController> _contact = {
    for (final k in ['phone', 'telegram', 'facebook', 'website', 'email']) k: TextEditingController(text: str(obj(ctx.settings['contact'])[k])),
  };
  String _busy = '';

  @override
  void dispose() {
    _title.dispose();
    _about.dispose();
    _slug.dispose();
    for (final c in _contact.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _logo(bool remove) async {
    List<int>? bytes;
    if (!remove) {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 600, maxHeight: 600, imageQuality: 88);
      if (f == null) return;
      bytes = await f.readAsBytes();
    }
    setState(() => _busy = 'logo');
    final r = await ctx.run(() => remove ? ctx.api.delete('${ctx.base}/logo') : ctx.api.post('${ctx.base}/logo', fileForm('photo', bytes!, 'logo.jpg')));
    if (r != null) ctx.put((_) => {'settings': obj(r['data'])});
    if (mounted) setState(() => _busy = '');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ro = ctx.readOnly;
    final logo = ctx.logo;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        fbHead(context, LucideIcons.info, ctx.m('infoTitle'), ctx.m('infoSub')),
        mGap,
        fbPanel([
          Text(ctx.m('logo'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: c.bg2,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.imagePlus, color: c.muted),
              ),
              const SizedBox(width: 12),
              Btn(
                _busy == 'logo' ? '…' : ctx.m('upload'),
                icon: LucideIcons.imagePlus,
                kind: BtnKind.ghost,
                small: true,
                busy: _busy == 'logo',
                onTap: ro || _busy.isNotEmpty ? null : () => _logo(false),
              ),
              if (logo.isNotEmpty && _busy.isEmpty) ...[const SizedBox(width: 6), RoundBtn(LucideIcons.trash2, size: 38, tip: ctx.m('remove'), fg: c.danger, onTap: ro ? null : () => _logo(true))],
            ],
          ),
          gap14,
          Field(label: ctx.m('libName'), controller: _title, hint: str(ctx.business['name']), maxLength: 80, enabled: !ro),
          gap14,
          Text(ctx.m('lang'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Segmented<String>(value: _lang, options: const [('km', 'ខ្មែរ'), ('en', 'English')], onChanged: ro ? (_) {} : (v) => setState(() => _lang = v)),
          gap14,
          Field(label: ctx.m('libAbout'), controller: _about, maxLength: 600, maxLines: 3, enabled: !ro),
          for (final (k, max, kb) in [
            ('phone', 30, TextInputType.phone),
            ('telegram', 120, TextInputType.text),
            ('facebook', 200, TextInputType.url),
            ('website', 200, TextInputType.url),
            ('email', 120, TextInputType.emailAddress),
          ]) ...[gap14, Field(label: ctx.m(k), controller: _contact[k]!, maxLength: max, keyboard: kb, enabled: !ro)],
          gap14,
          Field(
            label: ctx.m('slug'),
            controller: _slug,
            maxLength: 40,
            enabled: !ro,
            prefix: Padding(
              padding: const EdgeInsets.only(left: 12, right: 2),
              child: Center(
                widthFactor: 1,
                child: Text(
                  '/f/',
                  style: TextStyle(color: c.muted, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            onChanged: (v) {
              final x = v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '');
              if (x != v) {
                _slug.value = TextEditingValue(
                  text: x,
                  selection: TextSelection.collapsed(offset: x.length),
                );
              }
            },
          ),
          Padding(padding: const EdgeInsets.only(top: 4), child: Muted(ctx.m('slugHint'))),
          gap14,
          Align(
            alignment: Alignment.centerRight,
            child: Btn(
              ctx.m('save'),
              icon: LucideIcons.save,
              busy: _busy == 'save',
              onTap: ro || _busy.isNotEmpty
                  ? null
                  : () async {
                      setState(() => _busy = 'save');
                      await saveFb(ctx, {
                        'title': _title.text,
                        'about': _about.text,
                        'lang': _lang,
                        'slug': _slug.text,
                        'contact': {for (final e in _contact.entries) e.key: e.value.text},
                      });
                      if (mounted) setState(() => _busy = '');
                    },
            ),
          ),
        ]),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------- reader looks
class ReaderTab extends StatefulWidget {
  final FbCtx ctx;
  const ReaderTab({super.key, required this.ctx});
  @override
  State<ReaderTab> createState() => _ReaderTabState();
}

class _ReaderTabState extends State<ReaderTab> {
  FbCtx get ctx => widget.ctx;
  String _busy = '';

  // tap a reader look → the look sheet (swipe for the next), Use / Buy at the bottom
  Future<void> _open(String key, List<String> list, String cover, Color accent) async {
    final owned = (ctx.data['reader_themes'] as List? ?? const ['classic']).map((e) => '$e').toList();
    final price = n(ctx.prices['fb_reader_theme']);
    await showLookSheet(
      context,
      title: ctx.m('readerTitle'),
      count: list.length,
      initial: list.indexOf(key),
      item: (context, i, refresh) {
        final k = list[i];
        final r = fbReaders[k]!;
        final using = (str(ctx.settings['reader_theme']).isEmpty ? 'classic' : str(ctx.settings['reader_theme'])) == k;
        final mine = owned.contains(k) || k == 'classic';
        return LookItem(
          name: r.name(ctx.lang),
          badge: using ? ctx.m('inUse') : (mine ? ctx.m(k == 'classic' ? 'free' : 'owned') : '${fmt(price)} ${ctx.m('coins')}'),
          badgeTone: using || mine ? Tone.good : Tone.warn,
          preview: SizedBox(
            width: 340,
            height: 260,
            child: ClipRRect(borderRadius: BorderRadius.circular(16), child: readerMock(r, cover, accent)),
          ),
          acts: [
            if (!using && mine)
              LookAct(
                ctx.m('use'),
                icon: LucideIcons.check,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        await saveFb(ctx, {'reader_theme': k});
                        return true;
                      },
              ),
            if (!mine)
              LookAct(
                ctx.m('buy', {'coins': fmt(price)}),
                gold: true,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        ctx.askBuy({
                          'reader': k,
                          'stage': SizedBox(
                            width: 200,
                            height: 152,
                            child: ClipRRect(borderRadius: BorderRadius.circular(14), child: readerMock(r, cover, accent)),
                          ),
                        });
                        return true;
                      },
              ),
          ],
        );
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _save(Json body, String what) async {
    setState(() => _busy = what);
    await saveFb(ctx, body);
    if (mounted) setState(() => _busy = '');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final owned = (ctx.data['reader_themes'] as List? ?? const ['classic']).map((e) => '$e').toList();
    final accent = libColour(ctx);
    final cover = ctx.books.isEmpty ? '' : str(ctx.books.first['cover']);
    final using = str(ctx.settings['reader_theme']).isEmpty ? 'classic' : str(ctx.settings['reader_theme']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        fbHead(context, LucideIcons.bookOpenText, ctx.m('readerTitle'), ctx.m('readerSub', {'coins': fmt(n(ctx.prices['fb_reader_theme']))})),
        mGap,
        fbPanel([
          SwitchRow(title: ctx.m('sound'), value: ctx.settings['sound'] == true, onChanged: ctx.readOnly || _busy == 'sound' ? null : (v) => _save({'sound': v}, 'sound')),
          Row(
            children: [
              Icon(LucideIcons.volume2, size: 12, color: c.muted),
              const SizedBox(width: 4),
              Expanded(child: Muted(ctx.m('soundSub'))),
            ],
          ),
        ]),
        mGap,
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: .88,
          children: [
            for (final e in fbReaders.entries)
              () {
                final r = e.value;
                final k = e.key;
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _open(k, fbReaders.keys.toList(), cover, accent),
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: using == k ? c.brand : c.line, width: using == k ? 2 : 1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Expanded(child: readerMock(r, cover, accent)),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(r.name(ctx.lang), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                              ),
                              if (using == k)
                                Icon(LucideIcons.check, size: 16, color: c.good)
                              else if (owned.contains(k) || k == 'classic')
                                Text(
                                  ctx.m(k == 'classic' ? 'free' : 'owned'),
                                  style: TextStyle(color: c.muted, fontWeight: FontWeight.w700, fontSize: 12),
                                )
                              else
                                Row(
                                  children: [
                                    const CoinIcon(size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      fmt(n(ctx.prices['fb_reader_theme'])),
                                      style: TextStyle(color: c.muted, fontWeight: FontWeight.w800, fontSize: 12),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }(),
          ],
        ),
      ],
    );
  }
}

// a reader look: the book open on its background, with the top / bottom bars
Widget readerMock(FbReader r, String cover, Color accent) {
  final bg = r.bg.where((x) => (x >> 24) > 0x80).map(Color.new).toList();
  return Container(
    decoration: BoxDecoration(
      gradient: bg.length > 1 ? RadialGradient(colors: bg, radius: 1.1) : null,
      color: bg.length == 1 ? bg.first : (bg.isEmpty ? Colors.grey : null),
    ),
    child: Column(
      children: [
        Container(height: 12, color: Color(r.bar)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: cover.isEmpty ? null : Image(image: netImage(cover), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                  ),
                ),
                Expanded(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [for (var i = 0; i < 5; i++) Container(margin: const EdgeInsets.only(bottom: 4), height: 2, color: Colors.black12)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          height: 14,
          color: Color(r.bar),
          alignment: Alignment.center,
          child: Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
          ),
        ),
      ],
    ),
  );
}
