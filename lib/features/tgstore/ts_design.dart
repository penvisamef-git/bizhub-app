import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/color_pick.dart' show ColorRow;
import '../../widgets/ui.dart';
import '../common/web_page.dart' show openWeb;
import '../event/ev_common.dart' show EvChips;
import '../restaurant/rest_common.dart' show Segmented;
import 'ts_common.dart';
import 'ts_themes.dart';

// Design (TsDesign.jsx): the shop colour + 120 store designs (3 free, the others one coin price each, forever)
const _swatches = ['#C4470F', '#E11D48', '#F97316', '#F59E0B', '#65A30D', '#10A37F', '#0E7490', '#229ED9', '#2563EB', '#7C3AED', '#DB2777', '#1F1A16'];

class DesignTab extends StatefulWidget {
  final TsCtx ctx;
  const DesignTab({super.key, required this.ctx});
  @override
  State<DesignTab> createState() => _DesignTabState();
}

class _DesignTabState extends State<DesignTab> {
  TsCtx get ctx => widget.ctx;
  String _layout = '';
  bool _mine = false;
  String _busy = '';
  late String _color = str(ctx.store['color']);

  Set<String> get _owned => {for (final k in (ctx.themes['owned'] is List ? ctx.themes['owned'] as List : const [])) '$k'};
  List<String> get _free => [for (final k in (ctx.themes['free'] is List ? ctx.themes['free'] as List : tsFreeThemes)) '$k'];

  Future<void> _saveColor(String value) async {
    setState(() {
      _color = value;
      _busy = 'color';
    });
    final r = await ctx.run(() => ctx.api.put('${ctx.base}/settings', {'color': value}));
    if (mounted) setState(() => _busy = '');
    if (r != null) ctx.put({'store': obj(obj(r['data'])['store'])});
  }

  Future<void> _use(String key) async {
    setState(() => _busy = key);
    final r = await ctx.run(() => ctx.api.post('${ctx.base}/themes/$key'), ctx.m('saved'));
    if (mounted) setState(() => _busy = '');
    if (r == null) return;
    final d = obj(r['data']);
    ctx.put({
      'store': {...ctx.store, 'theme': d['theme']},
      'themes': {...ctx.themes, 'owned': d['owned']},
    });
  }

  void _preview(TsTheme th) {
    final path = Uri.tryParse(ctx.webLink)?.path ?? '/t/${ctx.store['slug']}';
    openWeb(context, '$path?theme=${th.key}', th.name(ctx.lang));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = ctx.store;
    final ro = ctx.readOnly;
    final current = tsThemeOf(str(s['theme']));
    final owned = _owned;
    final free = _free;
    final price = n(ctx.themes['price']);
    final list = tsThemes.where((t) => (_layout.isEmpty || t.layout.key == _layout) && (!_mine || owned.contains(t.key) || free.contains(t.key))).toList();
    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= 900 ? 4 : (width >= 600 ? 3 : 2);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          sliver: SliverList.list(
            children: [
              Muted(ctx.m('designSub')),
              const SizedBox(height: 12),
              Panel(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 112,
                      height: 148,
                      child: TsMiniStore(themeKey: current.key, color: _color, name: ctx.shopName, logo: str(s['logo'])),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ctx.m('using'), style: TextStyle(fontSize: 12, color: c.muted)),
                          Text(current.name(ctx.lang), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                          Text(current.kind(ctx.lang), style: TextStyle(fontSize: 12.5, color: c.muted)),
                          const SizedBox(height: 12),
                          Text(ctx.m('colour'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          const SizedBox(height: 6),
                          Segmented<bool>(
                            value: _color.isNotEmpty,
                            options: [(false, ctx.m('themeColour')), (true, ctx.m('ownColour'))],
                            onChanged: ro || _busy == 'color' ? null : (own) => _saveColor(own ? (_color.isNotEmpty ? _color : colorHex(current.palette.accent)) : ''),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_color.isNotEmpty)
                Panel(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  child: ColorRow(
                    value: _color,
                    colors: _swatches,
                    customLabel: ctx.m('ownColour'),
                    saveLabel: ctx.m('save'),
                    cancelLabel: ctx.m('cancel'),
                    onChanged: ro || _busy == 'color' ? null : _saveColor,
                  ),
                ),
              Text(ctx.m('designsN', {'n': list.length}), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              EvChips(items: [('', ctx.m('allLayouts'), null), for (final l in tsLayouts) (l.key, ctx.lang == 'km' ? l.km : l.en, null)], value: _layout, onPick: (v) => setState(() => _layout = v)),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilterChip(
                  label: Text(ctx.m('owned')),
                  avatar: Icon(LucideIcons.check, size: 14, color: _mine ? c.brandInk : c.muted),
                  showCheckmark: false,
                  selected: _mine,
                  onSelected: (v) => setState(() => _mine = v),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 32 + MediaQuery.of(context).padding.bottom),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .52),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final th = list[i];
              final using = th.key == current.key;
              final isFree = free.contains(th.key);
              final mine = isFree || owned.contains(th.key);
              return Container(
                key: ValueKey('ts-design-${th.key}'),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: using ? c.brand : c.line, width: using ? 2 : 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _preview(th),
                        child: TsMiniStore(themeKey: th.key, color: _color, name: ctx.shopName, logo: str(s['logo'])),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      th.name(ctx.lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                    Row(
                      children: [
                        if (using) ...[Icon(LucideIcons.check, size: 12, color: c.good), const SizedBox(width: 3)],
                        if (!mine) ...[Icon(LucideIcons.lock, size: 11, color: c.muted), const SizedBox(width: 3)],
                        Flexible(
                          child: Text(
                            using ? ctx.m('using') : (isFree ? ctx.m('free') : (mine ? ctx.m('owned') : '${fmt(price)} ${ctx.m('coins')}')),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: using ? c.good : c.muted, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (using)
                          Expanded(
                            child: Btn(ctx.m('tryIt'), icon: LucideIcons.eye, small: true, kind: BtnKind.ghost, onTap: () => _preview(th)),
                          )
                        else
                          RoundBtn(LucideIcons.eye, size: 40, tip: ctx.m('tryIt'), onTap: () => _preview(th)),
                        if (!using) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: mine
                                ? Btn(ctx.m('use'), small: true, busy: _busy == th.key, onTap: ro || _busy.isNotEmpty ? null : () => _use(th.key))
                                : Btn(
                                    fmt(price),
                                    lead: const CoinIcon(size: 14),
                                    small: true,
                                    kind: BtnKind.solid,
                                    onTap: ro ? null : () => ctx.askBuy('theme', item: th.key),
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// a small picture of a design: its colours + how it is laid out (MiniStore on the web)
class TsMiniStore extends StatelessWidget {
  final String themeKey, color, name, logo;
  const TsMiniStore({super.key, required this.themeKey, this.color = '', this.name = '', this.logo = ''});

  @override
  Widget build(BuildContext context) {
    final th = tsThemeOf(themeKey);
    final p = th.palette;
    final accent = hexColor(color) ?? p.accent;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth.isFinite ? box.maxWidth : 160.0;
        final s = (w / 160).clamp(.5, 2.0);
        final r = th.corner * s * .6;
        final head = _head(th, accent, s);
        return Container(
          decoration: BoxDecoration(
            color: p.page,
            borderRadius: BorderRadius.circular(14 * s),
            border: Border.all(color: p.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (th.pattern != 'none') Positioned.fill(child: CustomPaint(painter: _Pattern(th.pattern, p.dark ? Colors.white.withValues(alpha: .06) : p.line))),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  head,
                  Padding(
                    padding: EdgeInsets.fromLTRB(8 * s, 6 * s, 8 * s, 4 * s),
                    child: Row(
                      children: [
                        for (var i = 0; i < 3; i++)
                          Container(
                            margin: EdgeInsets.only(right: 4 * s),
                            width: (i == 0 ? 26 : 20) * s,
                            height: 7 * s,
                            decoration: BoxDecoration(
                              color: i == 0 ? accent : p.bg,
                              borderRadius: BorderRadius.circular(99),
                              border: i == 0 ? null : Border.all(color: p.line),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ClipRect(
                      child: Padding(padding: EdgeInsets.fromLTRB(8 * s, 2 * s, 8 * s, 8 * s), child: _items(th, accent, s, r)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _logo(TsPalette p, Color accent, double s, {bool onAccent = false}) => Container(
    width: 16 * s,
    height: 16 * s,
    decoration: BoxDecoration(color: onAccent ? Colors.white.withValues(alpha: .9) : accent, borderRadius: BorderRadius.circular(5 * s)),
    clipBehavior: Clip.antiAlias,
    child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : null,
  );

  Widget _title(Color col, double s, {TextAlign align = TextAlign.start}) => Text(
    name.isEmpty ? ' ' : name,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: align,
    style: TextStyle(fontSize: 8.5 * s, fontWeight: FontWeight.w800, color: col, height: 1.1),
  );

  Widget _head(TsTheme th, Color accent, double s) {
    final p = th.palette;
    switch (th.head) {
      case 'band':
        return Container(
          color: accent,
          padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 8 * s),
          child: Row(
            children: [
              _logo(p, accent, s, onAccent: true),
              SizedBox(width: 6 * s),
              Expanded(child: _title(Colors.white, s)),
            ],
          ),
        );
      case 'center':
        return Container(
          color: p.bg,
          padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 7 * s),
          child: Column(
            children: [
              _logo(p, accent, s),
              SizedBox(height: 3 * s),
              _title(p.ink, s, align: TextAlign.center),
            ],
          ),
        );
      case 'split':
        return SizedBox(
          height: 30 * s,
          child: Row(
            children: [
              Container(width: 34 * s, color: accent, alignment: Alignment.center, child: _logo(p, accent, s, onAccent: true)),
              Expanded(
                child: Container(
                  color: p.bg,
                  padding: EdgeInsets.symmetric(horizontal: 6 * s),
                  alignment: Alignment.centerLeft,
                  child: _title(p.ink, s),
                ),
              ),
            ],
          ),
        );
      case 'wave':
        return Container(
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.vertical(bottom: Radius.elliptical(80 * s, 14 * s)),
          ),
          padding: EdgeInsets.fromLTRB(8 * s, 8 * s, 8 * s, 12 * s),
          child: Row(
            children: [
              _logo(p, accent, s, onAccent: true),
              SizedBox(width: 6 * s),
              Expanded(child: _title(Colors.white, s)),
            ],
          ),
        );
      case 'cover':
        return Container(
          height: 42 * s,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [accent, Color.lerp(accent, Colors.black, .35)!]),
          ),
          padding: EdgeInsets.all(8 * s),
          alignment: Alignment.bottomLeft,
          child: Row(
            children: [
              _logo(p, accent, s, onAccent: true),
              SizedBox(width: 6 * s),
              Expanded(child: _title(Colors.white, s)),
            ],
          ),
        );
      default: // soft
        return Container(
          margin: EdgeInsets.fromLTRB(6 * s, 6 * s, 6 * s, 0),
          padding: EdgeInsets.all(6 * s),
          decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(8 * s)),
          child: Row(
            children: [
              _logo(p, accent, s),
              SizedBox(width: 6 * s),
              Expanded(child: _title(p.ink, s)),
            ],
          ),
        );
    }
  }

  BoxDecoration _card(TsTheme th, Color accent, double s, double r) {
    final p = th.palette;
    return switch (th.card) {
      'outline' => BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: p.line, width: 1),
      ),
      'flat' => BoxDecoration(color: Color.lerp(p.page, p.line, .55), borderRadius: BorderRadius.circular(r)),
      'glass' => BoxDecoration(
        color: p.bg.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: Colors.white.withValues(alpha: p.dark ? .12 : .7)),
      ),
      'bold' => BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: accent, width: 1.4),
      ),
      _ => BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.dark ? .4 : .08),
            blurRadius: 6 * s,
            offset: Offset(0, 2 * s),
          ),
        ],
      ),
    };
  }

  Widget _plus(TsTheme th, Color accent, double s) {
    final size = 9 * s;
    final outline = th.button == 'outline';
    return Container(
      width: th.button == 'pill' ? size * 1.8 : size,
      height: size,
      decoration: BoxDecoration(
        color: outline ? Colors.transparent : accent,
        border: outline ? Border.all(color: accent, width: 1.2) : null,
        borderRadius: BorderRadius.circular(th.button == 'square' ? 2 * s : 99),
      ),
      child: Icon(LucideIcons.plus, size: 6.5 * s, color: outline ? accent : Colors.white),
    );
  }

  Widget _lines(TsTheme th, double s, {bool price = true, Color? accent}) {
    final p = th.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FractionallySizedBox(
          widthFactor: .8,
          child: Container(
            height: 3.5 * s,
            decoration: BoxDecoration(color: p.ink.withValues(alpha: .75), borderRadius: BorderRadius.circular(9)),
          ),
        ),
        SizedBox(height: 2.5 * s),
        FractionallySizedBox(
          widthFactor: .5,
          child: Container(
            height: 3 * s,
            decoration: BoxDecoration(color: price ? (accent ?? p.accent) : p.muted.withValues(alpha: .6), borderRadius: BorderRadius.circular(9)),
          ),
        ),
      ],
    );
  }

  Widget _pic(TsTheme th, Color accent, double r, {bool circle = false}) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [accent.withValues(alpha: .35), accent.withValues(alpha: .15)]),
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : BorderRadius.circular(r * .8),
    ),
  );

  // a tile with the photo on top
  Widget _tile(TsTheme th, Color accent, double s, double r, {bool circle = false}) => Container(
    decoration: _card(th, accent, s, r),
    padding: EdgeInsets.all(4 * s),
    child: LayoutBuilder(
      // very small tiles: the photo only (no room for the name and the + button)
      builder: (_, box) => box.maxHeight < 24 * s
          ? _pic(th, accent, r, circle: circle)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: circle ? Center(child: AspectRatio(aspectRatio: 1, child: _pic(th, accent, r, circle: true))) : _pic(th, accent, r),
                ),
                SizedBox(height: 4 * s),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: _lines(th, s, accent: accent)),
                    _plus(th, accent, s),
                  ],
                ),
              ],
            ),
    ),
  );

  // a row with the photo on the side (or no photo)
  Widget _row(TsTheme th, Color accent, double s, double r, {bool pic = true, bool dotted = false}) => Container(
    decoration: dotted ? null : _card(th, accent, s, r),
    padding: EdgeInsets.all(4 * s),
    child: Row(
      children: [
        if (pic) ...[AspectRatio(aspectRatio: 1, child: _pic(th, accent, r)), SizedBox(width: 5 * s)],
        Expanded(
          child: _lines(th, s, price: !dotted, accent: accent),
        ),
        if (dotted) ...[
          Container(width: 14 * s, height: 1, color: th.palette.muted.withValues(alpha: .5)),
          SizedBox(width: 3 * s),
          Container(
            width: 12 * s,
            height: 3.5 * s,
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(9)),
          ),
        ] else
          _plus(th, accent, s),
      ],
    ),
  );

  Widget _grid(int rows, int cols, double s, Widget Function() cell) => Column(
    children: [
      for (var i = 0; i < rows; i++) ...[
        if (i > 0) SizedBox(height: 5 * s),
        Expanded(
          child: Row(
            children: [
              for (var j = 0; j < cols; j++) ...[if (j > 0) SizedBox(width: 5 * s), Expanded(child: cell())],
            ],
          ),
        ),
      ],
    ],
  );

  Widget _stack(int rows, double s, Widget Function() cell) => Column(
    children: [
      for (var i = 0; i < rows; i++) ...[if (i > 0) SizedBox(height: 4 * s), Expanded(child: cell())],
    ],
  );

  Widget _items(TsTheme th, Color accent, double s, double r) {
    switch (th.layout.key) {
      case 'list':
        return _stack(4, s, () => _row(th, accent, s, r));
      case 'big':
        return _grid(2, 1, s, () => _tile(th, accent, s, r));
      case 'compact':
        return _grid(3, 3, s, () => _tile(th, accent, s, r));
      case 'menu':
        return Container(decoration: _card(th, accent, s, r), padding: EdgeInsets.all(3 * s), child: _stack(5, s, () => _row(th, accent, s, r, pic: false, dotted: true)));
      case 'magazine':
        return Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: _card(th, accent, s, r),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [accent.withValues(alpha: .25), accent.withValues(alpha: .7)]),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 6 * s,
                      right: 6 * s,
                      bottom: 6 * s,
                      child: _lines(th, s, accent: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 5 * s),
            Expanded(flex: 2, child: _stack(2, s, () => _row(th, accent, s, r))),
          ],
        );
      case 'bubble':
        return _grid(2, 2, s, () => _tile(th, accent, s, r, circle: true));
      case 'shelf':
        return _grid(2, 3, s, () => _tile(th, accent, s, r));
      default: // grid
        return _grid(2, 2, s, () => _tile(th, accent, s, r));
    }
  }
}

// what sits behind everything (dots, grid, stripes, waves, paper)
class _Pattern extends CustomPainter {
  final String kind;
  final Color color;
  _Pattern(this.kind, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const step = 10.0;
    switch (kind) {
      case 'dots':
        final dot = Paint()..color = color;
        for (var x = 4.0; x < size.width; x += step) {
          for (var y = 4.0; y < size.height; y += step) {
            canvas.drawCircle(Offset(x, y), 1, dot);
          }
        }
      case 'grid':
        for (var x = 0.0; x < size.width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), pen);
        }
        for (var y = 0.0; y < size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), pen);
        }
      case 'stripes':
        for (var x = -size.height; x < size.width; x += step) {
          canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), pen);
        }
      case 'waves':
        for (var y = 6.0; y < size.height; y += 14) {
          final path = Path()..moveTo(0, y);
          for (var x = 0.0; x < size.width; x += 16) {
            path.quadraticBezierTo(x + 4, y - 3, x + 8, y);
            path.quadraticBezierTo(x + 12, y + 3, x + 16, y);
          }
          canvas.drawPath(path, pen);
        }
      case 'paper':
        for (var y = 12.0; y < size.height; y += 12) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), pen);
        }
    }
  }

  @override
  bool shouldRepaint(_Pattern old) => old.kind != kind || old.color != color;
}
