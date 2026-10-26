import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/color_pick.dart';
import '../../widgets/look_sheet.dart';
import '../../widgets/ui.dart';
import 'mq_common.dart';
import 'mq_data.dart';

// Menu looks (MqLooks.jsx): 77 designs, buy once, switch any time
const _oneRow = ['rows', 'list', 'board', 'banner', 'split', 'ticket', 'line'];

// demo menu when the owner has fewer than 2 items
final _demo = <Json>[
  {'name_km': 'កាហ្វេទឹកដោះគោ', 'name_en': 'Iced milk coffee', 'price': 1.5, 'emoji': '🧋', 'tint': 0xFFF3D9B1},
  {'name_km': 'តែក្រូចឆ្មា', 'name_en': 'Lemon tea', 'price': 1.25, 'emoji': '🍹', 'tint': 0xFFFDE68A},
  {'name_km': 'គុយទាវសាច់គោ', 'name_en': 'Beef noodle soup', 'price': 3.5, 'emoji': '🍜', 'tint': 0xFFFECACA},
  {'name_km': 'សាឡាដស្វាយ', 'name_en': 'Green mango salad', 'price': 2.75, 'emoji': '🥗', 'tint': 0xFFBBF7D0},
];

Color _col(int v) => Color(v);

class LooksTab extends StatefulWidget {
  final MqCtx ctx;
  const LooksTab({super.key, required this.ctx});
  @override
  State<LooksTab> createState() => _LooksTabState();
}

class _LooksTabState extends State<LooksTab> {
  MqCtx get ctx => widget.ctx;
  String _show = 'all';
  List<Json>? _items;

  List<String> get _owned => (obj(ctx.data['themes'])['owned'] as List? ?? const []).map((e) => '$e').toList();
  Json get _price => obj(obj(ctx.data['themes'])['price']);

  @override
  void initState() {
    super.initState();
    ctx.api
        .get('${ctx.base}/items')
        .then((r) {
          if (mounted) setState(() => _items = objs(r['data']).where((x) => x['active'] != false).toList());
        })
        .catchError((_) {
          if (mounted) setState(() => _items = []);
          return null;
        });
  }

  List<Json> get _menu => (_items != null && _items!.length >= 2) ? _items!.take(4).toList() : _demo;

  // tap a look → the look sheet over the list shown (swipe for the next one)
  final Map<String, String> _colors = {};
  Future<void> _open(String key, List<String> keys) async {
    final using = str(ctx.settings['theme']).isEmpty ? 'classic' : str(ctx.settings['theme']);
    String hex(int v) => '#${(v & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    Future<bool> save(Json body) async {
      final r = await ctx.run(() => ctx.api.put('${ctx.base}/settings', body), ctx.m('saved'));
      if (r != null) ctx.setSettings(obj(r['data']));
      return r != null;
    }

    await showLookSheet(
      context,
      title: ctx.m('looksTitle'),
      count: keys.length,
      initial: keys.contains(key) ? keys.indexOf(key) : 0,
      item: (context, i, refresh) {
        final k = keys[i];
        final l = mqLooks[k]!;
        final mine = _owned.contains(k) || l.tier == 'free';
        final inUse = k == using;
        final saved = inUse ? str(ctx.settings['color']) : '';
        final color = _colors[k] ?? saved;
        final price = n(_price[l.tier]);
        return LookItem(
          name: l.name(ctx.lang),
          sub: '${l.desc(ctx.lang)} · ${ctx.m(l.tier)}',
          badge: inUse ? ctx.m('inUse') : (mine ? ctx.m(l.tier == 'free' ? 'free' : 'owned') : '${fmt(price)} ${ctx.m('coins')}'),
          badgeTone: inUse || mine ? Tone.good : Tone.warn,
          preview: SizedBox(
            width: 250,
            height: 440,
            child: MqMock(look: l, color: color, name: str(ctx.business['name']), menu: _menu, lang: ctx.lang, big: true, logo: ctx.logo),
          ),
          extras: [
            Text(ctx.m('yourColour'), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ColorRow(
              value: color.isEmpty ? hex(l.accent) : color,
              customLabel: ctx.m('yourColour'),
              saveLabel: ctx.m('save'),
              cancelLabel: ctx.m('cancel'),
              onChanged: ctx.readOnly
                  ? null
                  : (v) {
                      _colors[k] = v.toUpperCase();
                      refresh();
                    },
            ),
            if (color.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: ctx.readOnly
                      ? null
                      : () {
                          _colors[k] = '';
                          refresh();
                        },
                  icon: const Icon(LucideIcons.rotateCcw, size: 15),
                  label: Text(ctx.m('themeColour')),
                ),
              ),
            const SizedBox(height: 10),
          ],
          acts: [
            if (inUse && color != saved)
              LookAct(ctx.m('save'), icon: LucideIcons.save, onTap: ctx.readOnly ? null : () => save({'color': color}))
            else if (!inUse && mine)
              LookAct(ctx.m('use'), icon: LucideIcons.check, onTap: ctx.readOnly ? null : () => save({'theme': k, if (_colors[k] != null) 'color': color}))
            else if (!mine)
              LookAct(
                ctx.m('buy', {'coins': fmt(price)}),
                gold: true,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        ctx.askBuy({
                          'theme': k,
                          'tier': l.tier,
                          'label': l.name(ctx.lang),
                          'stage': SizedBox(
                            width: 150,
                            height: 264,
                            child: MqMock(look: l, color: '', name: str(ctx.business['name']), menu: _menu, lang: ctx.lang),
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

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = ctx.settings;
    final using = str(s['theme']).isEmpty ? 'classic' : str(s['theme']);
    final owned = _owned;
    final keys = mqLooks.keys.where((k) {
      final l = mqLooks[k]!;
      return switch (_show) {
        'mine' => owned.contains(k) || l.tier == 'free',
        'row' => _oneRow.contains(l.layout),
        'all' => true,
        _ => l.tier == _show,
      };
    }).toList();
    // the one in use first
    keys.sort((a, b) => (a == using ? 0 : 1).compareTo(b == using ? 0 : 1));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        mqHead(context, LucideIcons.palette, ctx.m('looksTitle'), ctx.m('looksSub')),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final k in ['all', 'mine', 'row', 'free', 'basic', 'pro'])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(label: Text('${ctx.m(k)}${k == 'mine' ? ' (${owned.length})' : ''}'), selected: _show == k, onSelected: (_) => setState(() => _show = k)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: keys.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .66),
          itemBuilder: (_, i) {
            final k = keys[i];
            final l = mqLooks[k]!;
            final mine = owned.contains(k) || l.tier == 'free';
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _open(k, keys),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: k == using ? c.brand : c.line, width: k == using ? 2.5 : 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          MqMock(look: l, color: k == using ? str(s['color']) : '', name: str(ctx.business['name']), menu: _menu, lang: ctx.lang),
                          if (!mine)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: CircleAvatar(
                                radius: 11,
                                backgroundColor: Colors.black54,
                                child: Icon(LucideIcons.lock, size: 12, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.name(ctx.lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    k == using
                        ? Text(
                            ctx.m('inUse'),
                            style: TextStyle(color: c.brand, fontWeight: FontWeight.w700, fontSize: 12.5),
                          )
                        : mine
                        ? Text(ctx.m(l.tier == 'free' ? 'free' : 'owned'), style: TextStyle(color: c.muted, fontSize: 12.5))
                        : Row(
                            children: [
                              const CoinIcon(size: 12),
                              const SizedBox(width: 4),
                              Text(
                                fmt(n(_price[l.tier])),
                                style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// a small (or big) picture of a menu look: header, tabs, items in the look's layout and colours
class MqMock extends StatelessWidget {
  final MqLook look;
  final String color, name, lang, logo;
  final List<Json> menu;
  final bool big;
  const MqMock({super.key, required this.look, required this.color, required this.name, required this.menu, required this.lang, this.big = false, this.logo = ''});

  @override
  Widget build(BuildContext context) {
    final l = look;
    final accent = color.isNotEmpty ? Color(0xFF000000 | (int.tryParse(color.replaceFirst('#', ''), radix: 16) ?? (l.accent & 0xFFFFFF))) : _col(l.accent);
    final bg = _col(l.bg), card = _col(l.card), ink = _col(l.ink), muted = _col(l.muted), line = _col(l.line);
    final k = big ? 1.0 : .55;
    final r = (l.r * k * .8).toDouble();
    Widget pic(Json it, double w, double h) {
      final url = str(objs(it['photos']).firstOrNull?['url']);
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(color: it['tint'] != null ? Color(it['tint'] as int) : line, borderRadius: BorderRadius.circular(r * .7)),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: url.isNotEmpty
            ? Image(image: netImage(url), width: w, height: h, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())
            : Text(str(it['emoji']).isEmpty ? '🍽️' : str(it['emoji']), style: TextStyle(fontSize: h * .45)),
      );
    }

    String nm(Json it) => lang == 'en' ? (str(it['name_en']).isNotEmpty ? str(it['name_en']) : str(it['name_km'])) : (str(it['name_km']).isNotEmpty ? str(it['name_km']) : str(it['name_en']));
    final pr = TextStyle(color: l.price == 'plain' ? accent : ink, fontWeight: FontWeight.w900, fontSize: 11 * k + 2);
    Widget price(Json it) {
      final t = Text('\$${n(it['sale_price'] ?? it['price']).toStringAsFixed(2)}', style: pr);
      if (l.price == 'tag' || l.price == 'badge') {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 6 * k, vertical: 2 * k),
          decoration: BoxDecoration(color: accent.withValues(alpha: .15), borderRadius: BorderRadius.circular(99)),
          child: t,
        );
      }
      return t;
    }

    final nameStyle = TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 11 * k + 2, height: 1.2);
    final items = menu.take(big ? 4 : 3).toList();
    Widget row(Json it, {bool photo = true, bool right = false}) => Container(
      margin: EdgeInsets.only(bottom: 6 * k),
      padding: EdgeInsets.all(l.layout == 'list' || l.layout == 'line' ? 4 * k : 6 * k),
      decoration: BoxDecoration(
        color: l.layout == 'list' || l.layout == 'line' || l.layout == 'board' ? Colors.transparent : card,
        borderRadius: BorderRadius.circular(r),
        border: l.layout == 'line' || l.layout == 'list' ? Border(bottom: BorderSide(color: line)) : null,
      ),
      child: Row(
        children: [
          if (photo && !right) ...[pic(it, 34 * k + 8, 34 * k + 8), SizedBox(width: 8 * k)],
          Expanded(
            child: Text(nm(it), maxLines: 2, overflow: TextOverflow.ellipsis, style: nameStyle),
          ),
          SizedBox(width: 4 * k),
          price(it),
          if (photo && right) ...[SizedBox(width: 8 * k), pic(it, 34 * k + 8, 34 * k + 8)],
        ],
      ),
    );
    Widget tile(Json it, {bool photo = true}) => Container(
      padding: EdgeInsets.all(5 * k),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photo) ...[
            AspectRatio(
              aspectRatio: l.layout == 'magazine' ? 1.8 : 1.25,
              child: LayoutBuilder(builder: (_, c) => pic(it, c.maxWidth, c.maxHeight)),
            ),
            SizedBox(height: 4 * k),
          ],
          Text(nm(it), maxLines: 1, overflow: TextOverflow.ellipsis, style: nameStyle),
          price(it),
        ],
      ),
    );
    final body = switch (l.layout) {
      'cards' || 'tiles' || 'polaroid' || 'compact' => GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 6 * k,
        crossAxisSpacing: 6 * k,
        childAspectRatio: l.layout == 'compact' ? 2.2 : .82,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [for (final it in menu.take(4)) tile(it, photo: l.layout != 'compact')],
      ),
      'magazine' => Column(
        children: [
          for (final it in items.take(2))
            Padding(
              padding: EdgeInsets.only(bottom: 6 * k),
              child: tile(it),
            ),
        ],
      ),
      'list' || 'line' || 'board' => Column(children: [for (final it in items) row(it, photo: false)]),
      'split' => Column(children: [for (final it in items) row(it, right: true)]),
      _ => Column(children: [for (final it in items) row(it)]),
    };
    final logoBox = Container(
      width: 30 * k + 8,
      height: 30 * k + 8,
      decoration: BoxDecoration(
        color: card,
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.utensilsCrossed, size: 14 * k + 4, color: accent),
    );
    final title = Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: l.head == 'bar' || l.head == 'cover' ? Colors.white : ink, fontWeight: FontWeight.w900, fontSize: 13 * k + 3),
    );
    final head = switch (l.head) {
      'cover' => Container(
        height: 62 * k + 20,
        padding: EdgeInsets.all(8 * k),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [accent, accent.withValues(alpha: .6)])),
        alignment: Alignment.bottomLeft,
        child: Row(
          children: [
            logoBox,
            SizedBox(width: 6 * k),
            Expanded(child: title),
          ],
        ),
      ),
      'bar' => Container(
        color: accent,
        padding: EdgeInsets.symmetric(horizontal: 8 * k, vertical: 10 * k),
        child: Row(
          children: [
            logoBox,
            SizedBox(width: 6 * k),
            Expanded(child: title),
          ],
        ),
      ),
      'split' => Padding(
        padding: EdgeInsets.all(8 * k),
        child: Row(
          children: [
            logoBox,
            SizedBox(width: 6 * k),
            Expanded(child: title),
          ],
        ),
      ),
      'minimal' => Padding(padding: EdgeInsets.fromLTRB(8 * k, 12 * k, 8 * k, 4 * k), child: title),
      _ => Padding(
        padding: EdgeInsets.all(8 * k),
        child: Column(
          children: [
            logoBox,
            SizedBox(height: 4 * k),
            title,
          ],
        ),
      ),
    };
    Widget tabChip(int i) {
      final on = i == 0;
      final label = ['☕', '🍜', '🍰'][i];
      return Container(
        margin: EdgeInsets.only(right: 4 * k),
        padding: EdgeInsets.symmetric(horizontal: 8 * k, vertical: 3 * k),
        decoration: BoxDecoration(
          color: l.tabs == 'underline' ? Colors.transparent : (on ? accent : card),
          borderRadius: BorderRadius.circular(l.tabs == 'boxed' ? 4 : 99),
          border: l.tabs == 'underline' ? Border(bottom: BorderSide(color: on ? accent : Colors.transparent, width: 2)) : null,
        ),
        child: Text(label, style: TextStyle(fontSize: 10 * k + 2)),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(big ? 22 : 12),
      child: Container(
        color: bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            head,
            Padding(
              padding: EdgeInsets.fromLTRB(8 * k, 4 * k, 8 * k, 6 * k),
              child: Row(children: [for (var i = 0; i < 3; i++) tabChip(i)]),
            ),
            Expanded(
              child: ClipRect(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 8 * k),
                  child: DefaultTextStyle(
                    style: TextStyle(color: muted),
                    child: body,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
