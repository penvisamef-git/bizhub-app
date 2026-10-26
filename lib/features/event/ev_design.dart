import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/color_pick.dart' show pickColor, colorToHex;
import '../../widgets/look_sheet.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show MHead;
import '../restaurant/rest_common.dart' show Segmented;
import '../restaurant/rest_online.dart' show shareWidgets;
import 'ev_common.dart';
import 'ev_looks.dart';

// Designs (the web's DesignTab): ticket designs (121) and event page themes (121), bought once and used on any event.
// Tap a design → its big preview, your own colours, then Use / Buy.
class DesignTab extends StatefulWidget {
  final EvCtx ctx;
  final String kind; // ticket | page
  const DesignTab({super.key, required this.ctx, this.kind = 'ticket'});
  @override
  State<DesignTab> createState() => _DesignTabState();
}

class _DesignTabState extends State<DesignTab> {
  EvCtx get ctx => widget.ctx;
  late String _kind = widget.kind == 'page' ? 'page' : 'ticket';
  late String _event = ctx.firstEvent();
  String _filter = 'all';

  bool get _page => _kind == 'page';
  Json get _shop => obj(ctx.data[_page ? 'page_themes' : 'themes']);
  List<String> get _owned => [for (final x in (_shop['owned'] as List? ?? const [])) '$x'];
  num get _price => n(_shop['price']);
  EvLook _of(String k) => _page ? pageThemeOf(k) : ticketThemeOf(k);
  bool _has(String k) => _of(k).free || _owned.contains(k);
  String _name(String k) => _page ? pageThemeName(k, ctx.lang) : ticketThemeName(k, ctx.lang);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    String d(String k, [Map<String, Object?> v = const {}]) => ctx.m('design.$k', v);
    final keys = _page ? evPageKeys : evTicketKeys;
    final ev = ctx.eventById(_event);
    final current = ev == null ? keys.first : (str(ev[_page ? 'page_theme' : 'theme']).isEmpty ? keys.first : str(ev[_page ? 'page_theme' : 'theme']));
    final layouts = _page ? ['standard', ...evPageLayouts] : ['classic', ...evTicketLayouts];
    final shown = keys.where((k) {
      final t = _of(k);
      return switch (_filter) {
        'all' => true,
        'mine' => _has(k),
        'live' => isLivePage(k),
        _ => t.layout == _filter,
      };
    }).toList();
    return EvList(
      onRefresh: ctx.reload,
      children: [
        Panel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MHead(d('title'), sub: (_page ? d('pageSub') : d('sub')).replaceAll('{n}', '${keys.length - 1}').replaceAll('{coins}', fmt(_price)), icon: LucideIcons.palette),
              Segmented<String>(
                value: _kind,
                options: [
                  ('ticket', d('kinds.ticket', {'n': evTicketKeys.length - 1})),
                  ('page', d('kinds.page', {'n': evPageKeys.length - 1})),
                ],
                onChanged: (v) => setState(() {
                  _kind = v;
                  _filter = 'all';
                }),
              ),
              const SizedBox(height: 12),
              Text(
                d('event'),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: c.ink),
              ),
              const SizedBox(height: 8),
              EvEventPick(ctx: ctx, value: _event, onChanged: (v) => setState(() => _event = v)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (ev == null)
          Panel(
            child: Column(
              children: [
                Icon(LucideIcons.palette, size: 30, color: c.muted),
                const SizedBox(height: 8),
                Muted(d('needEvent'), align: TextAlign.center),
                const SizedBox(height: 12),
                Btn(ctx.m('tabs.events'), icon: LucideIcons.plus, small: true, onTap: () => ctx.go('events')),
              ],
            ),
          )
        else ...[
          // in use now
          Panel(
            padding: const EdgeInsets.all(12),
            onTap: () => _open(ev, current, current, keys),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 96,
                  child: ClipRRect(borderRadius: BorderRadius.circular(10), child: _thumb(ev, current)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Chip2(d('inUse'), icon: LucideIcons.circleCheck, tone: Tone.good),
                      const SizedBox(height: 6),
                      Text(_name(current), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(d('colors'), style: TextStyle(color: c.muted, fontSize: 12.5)),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight, color: c.muted),
              ],
            ),
          ),
          const SizedBox(height: 12),
          EvChips(
            items: [
              ('all', d('all'), keys.length),
              ('mine', d('mine'), keys.where(_has).length),
              if (_page) ('live', '● ${d('live')}', null),
              for (final l in layouts) (l, _page ? pageLayoutName(l, ctx.lang) : ticketLayoutName(l, ctx.lang), null),
            ],
            value: _filter,
            onPick: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, box) {
              final cols = box.maxWidth >= 900 ? 5 : (box.maxWidth >= 600 ? 4 : (box.maxWidth >= 380 ? 3 : 2));
              final w = (box.maxWidth - 10 * (cols - 1)) / cols;
              return Wrap(
                spacing: 10,
                runSpacing: 12,
                children: [
                  for (final k in shown)
                    SizedBox(
                      width: w,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _open(ev, k, current, shown),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              height: w * 1.55,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _page ? c.bg2 : const Color(0xFFF5F4F7),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: k == current ? c.brand : c.line, width: k == current ? 2 : 1),
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(borderRadius: BorderRadius.circular(9), child: _thumb(ev, k)),
                                  ),
                                  if (_page && isLivePage(k))
                                    Positioned(
                                      left: 4,
                                      top: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(99)),
                                        child: Text(
                                          '● ${d('live')}',
                                          style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _name(k),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                            k == current
                                ? Row(
                                    children: [
                                      Icon(LucideIcons.check, size: 12, color: c.good),
                                      const SizedBox(width: 3),
                                      Text(
                                        d('inUse'),
                                        style: TextStyle(color: c.good, fontSize: 11, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  )
                                : _has(k)
                                ? Text(
                                    _of(k).free ? d('free') : d('owned'),
                                    style: TextStyle(color: c.good, fontSize: 11, fontWeight: FontWeight.w700),
                                  )
                                : Row(
                                    children: [
                                      const CoinIcon(size: 12),
                                      const SizedBox(width: 3),
                                      Text(
                                        fmt(_price),
                                        style: TextStyle(color: c.muted, fontSize: 11, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _thumb(Json ev, String k) => _page
      ? EvMini(
          width: 360,
          height: 760,
          child: EvPagePreview(ev: ev, org: ctx.org, theme: k, t: ctx.t),
        )
      : FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: EvTicketView(ev: ev, tk: sampleTicket(ev, ctx.lang), theme: k, colors: const {}, t: ctx.t, lite: true),
          ),
        );

  // tap a design → the design sheet: big preview, swipe to the next one, your colours, Use / Buy at the bottom
  final Map<String, Map<String, String>> _own = {};
  Future<void> _open(Json ev, String k, String current, List<String> list) async {
    String d(String key, [Map<String, Object?> v = const {}]) => ctx.m('design.$key', v);
    final field = _page ? 'page_theme' : 'theme', colorsField = _page ? 'page_colors' : 'theme_colors';
    final shots = <String, GlobalKey>{};
    Map<String, String> saved(String x) => x == current ? {for (final e in obj(ev[colorsField]).entries) e.key: '${e.value ?? ''}'} : {};
    Map<String, String> own(String x) => _own.putIfAbsent(x, () => saved(x));
    (Color, Color, Color) defs(String x) {
      final t = _of(x);
      if (_page && t.layout == 'standard') return (const Color(0xFFF0662B), const Color(0xFFFF9A3C), const Color(0xFF7C2D12));
      return (t.a, t.b, t.c);
    }

    Future<bool> use(String x) async {
      try {
        final o = own(x);
        await ctx.api.put('${ctx.base}/events/${ev['_id']}', {
          field: x,
          colorsField: {'a': o['a'] ?? '', 'b': o['b'] ?? '', 'c': o['c'] ?? ''},
        });
        await ctx.reload();
        ctx.notify(d('used'));
        return true;
      } on ApiError catch (e) {
        if (e.body['product'] != null) {
          ctx.askBuy('theme', item: '$_kind|$x|${ev['_id']}');
          return true;
        }
        ctx.fail(e);
        return false;
      }
    }

    await showLookSheet(
      context,
      title: _page ? d('kinds.page', {'n': evPageKeys.length - 1}) : d('kinds.ticket', {'n': evTicketKeys.length - 1}),
      count: list.length,
      initial: list.contains(k) ? list.indexOf(k) : 0,
      item: (context, i, refresh) {
        final x = list[i];
        final o = {for (final e in own(x).entries) if (e.value.isNotEmpty) e.key: e.value};
        final (da, db, dc) = defs(x);
        final dd = {'a': da, 'b': db, 'c': dc};
        final inUse = x == current;
        final dirty = ['a', 'b', 'c'].any((c0) => (own(x)[c0] ?? '') != (saved(x)[c0] ?? ''));
        final key = shots.putIfAbsent(x, GlobalKey.new);
        final c = context.c;
        return LookItem(
          name: _name(x),
          badge: inUse ? d('inUse') : (_has(x) ? (_of(x).free ? d('free') : d('owned')) : '${fmt(_price)} ${ctx.m('coins')}'),
          badgeTone: inUse || _has(x) ? Tone.good : Tone.warn,
          sub: _page && isLivePage(x) ? '● ${d('live')}' : null,
          preview: _page
              ? EvPagePreview(ev: ev, org: ctx.org, theme: x, colors: o, t: ctx.t, animate: true)
              : RepaintBoundary(
                  key: key,
                  child: Container(
                    color: const Color(0xFFF5F4F7),
                    padding: const EdgeInsets.all(14),
                    child: EvTicketView(ev: ev, tk: sampleTicket(ev, ctx.lang), theme: x, colors: o, t: ctx.t, width: 290),
                  ),
                ),
          extras: [
            // your own colours (free)
            Row(
              children: [
                Expanded(child: Text(d('colors'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                for (final cc in ['a', 'b', 'c'])
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Tooltip(
                      message: d('colorNames.$cc'),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () async {
                          final picked = await pickColor(context, (own(x)[cc] ?? '').isNotEmpty ? evHex(own(x)[cc]) : dd[cc]!, ctx.m('save'), ctx.m('cancel'));
                          if (picked != null) {
                            own(x)[cc] = colorToHex(picked);
                            refresh();
                          }
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(color: (own(x)[cc] ?? '').isNotEmpty ? evHex(own(x)[cc]) : dd[cc], shape: BoxShape.circle, border: Border.all(color: c.line, width: 3)),
                        ),
                      ),
                    ),
                  ),
                if (o.isNotEmpty)
                  IconButton(
                    tooltip: d('colorReset'),
                    onPressed: () {
                      _own[x] = {};
                      refresh();
                    },
                    icon: const Icon(LucideIcons.rotateCcw, size: 17),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          acts: [
            if (inUse && dirty)
              LookAct(d('saveColors'), icon: LucideIcons.check, onTap: ctx.readOnly ? null : () => use(x))
            else if (!inUse && _has(x))
              LookAct(d('use'), icon: LucideIcons.check, onTap: ctx.readOnly ? null : () => use(x))
            else if (!_has(x))
              LookAct(
                d('buy', {'coins': fmt(_price)}),
                gold: true,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        ctx.askBuy('theme', item: '$_kind|$x|${ev['_id']}');
                        return true;
                      },
              ),
            if (!_page && _has(x))
              LookAct(
                d('save'),
                icon: LucideIcons.download,
                ghost: true,
                onTap: () async {
                  await shareWidgets([key], (_) => 'ticket-$x.png');
                  return false;
                },
              ),
            if (ev['status'] != 'draft' && inUse)
              LookAct(
                d('open'),
                icon: LucideIcons.externalLink,
                ghost: true,
                onTap: () async {
                  await launchUrl(Uri.parse(eventUrl(ev['slug'])), mode: LaunchMode.externalApplication);
                  return false;
                },
              ),
          ],
        );
      },
    );
    if (mounted) setState(() {});
  }
}
