import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/look_sheet.dart';
import '../../widgets/ui.dart';
import '../debt/dk_common.dart' show dkDate, dkTime;
import '../mart/mart_common.dart' show GoldBtn, mGap, fileForm;
import '../mart/mart_kit.dart' show DayField, MSheet, showSheet;
import '../restaurant/rest_common.dart' show Segmented, SwitchRow, gap14;
import '../restaurant/rest_online.dart' show shareQr;
import 'wb_common.dart';
import 'wb_data.dart';
import 'wb_editor.dart' show TemplatePicker;

// WsMore.jsx: Look & style · Business info · Settings · Inbox · Blog · Visits · Telegram · Add-ons

Widget _list(List<Widget> children) => ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: children);

// save part of the site settings, keep the dashboard in step
Future<Json?> saveSite(WbCtx ctx, Json body) async {
  try {
    final r = await ctx.api.put('${ctx.base}/settings', body);
    ctx.put(
      (d) => {
        'site': {...obj(d['site']), ...obj(r['data'])},
      },
    );
    return obj(r['data']);
  } on ApiError catch (e) {
    if (e.status == 402 && e.body['product'] != null) {
      ctx.askBuy(e.body['product'] == 'web_theme' ? {'theme': str(e.body['item'])} : {'addon': str(e.body['product'])});
    } else {
      ctx.notify(e.network ? ctx.t('app.offline') : e.message);
    }
    return null;
  }
}

// "Big photo banner, soft shadows, wavy edges — for cafés…"
String wbThemeDescOf(String k, String lang) {
  final t = wbTheme(k);
  final i = lang == 'km' ? 1 : 0;
  String pick(String part, String? v) {
    final x = wbThemeDesc[part]?[v ?? ''];
    return x is List && x.length > i ? '${x[i]}' : '';
  }

  final hero = pick('hero', t.parts['hero']);
  final cards = pick('cards', t.parts['cards']);
  final use = pick('use', t.cat);
  String ex = '';
  for (final d in ['divider', 'pics', 'bgfx', 'type', 'width', 'sections', 'header']) {
    final x = wbThemeDesc['extra']?['$d:${t.parts[d] ?? ''}'];
    if (x is List) {
      ex = '${x[i]}';
      break;
    }
  }
  if (i == 1) return '$hero $cards${ex.isNotEmpty ? ' $ex' : ''}${t.dark ? ' ងងឹត' : ''} — សម្រាប់$use។';
  return '$hero, $cards${ex.isNotEmpty ? ', $ex' : ''}${t.dark ? ', dark' : ''} — for $use.';
}

// the colours a site really uses (look + owner's changes)
({Color c, Color c2, Color bg, Color sf, Color ink, bool dark, double r, String btn}) wbLook(String theme, Json style) {
  final t = wbTheme(theme);
  final wantDark = str(style['mode']).isNotEmpty ? style['mode'] == 'dark' : t.dark;
  var bg = str(style['bg']).isNotEmpty ? hexColor(style['bg']) : Color(t.bg);
  var sf = Color(t.sf), ink = Color(t.ink);
  if (wantDark && !t.dark) {
    bg = str(style['bg']).isNotEmpty ? bg : const Color(0xFF0F1218);
    sf = const Color(0xFF181C25);
    ink = const Color(0xFFE8EAF0);
  } else if (!wantDark && t.dark) {
    bg = str(style['bg']).isNotEmpty ? bg : Colors.white;
    sf = const Color(0xFFF5F7FA);
    ink = const Color(0xFF0F172A);
  }
  return (
    c: str(style['color']).isNotEmpty ? hexColor(style['color']) : Color(t.c),
    c2: str(style['accent']).isNotEmpty ? hexColor(style['accent']) : Color(t.c2),
    bg: bg,
    sf: sf,
    ink: ink,
    dark: wantDark,
    r: t.r.toDouble(),
    btn: str(style['buttons']).isNotEmpty ? str(style['buttons']) : t.btn,
  );
}

// a small drawing of a site in a look
class LookMini extends StatelessWidget {
  final String theme, name;
  final Json style;
  const LookMini({super.key, required this.theme, required this.name, this.style = const {}});
  @override
  Widget build(BuildContext context) {
    final l = wbLook(theme, style);
    final t = wbTheme(theme);
    final on = l.c.computeLuminance() > .45 ? const Color(0xFF111111) : Colors.white;
    final hero = t.parts['hero'] ?? 'cover';
    final r = (l.r / 3).clamp(0, 8).toDouble();
    final btnR = l.btn == 'pill'
        ? 99.0
        : l.btn == 'square'
        ? 1.0
        : 4.0;
    final title = Text(
      name.isEmpty ? 'Aa' : name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: ['cover', 'gradient', 'poster', 'diagonal'].contains(hero) ? on : l.ink),
    );
    final btn = Container(
      width: 30,
      height: 8,
      decoration: BoxDecoration(color: ['cover', 'gradient', 'poster', 'diagonal'].contains(hero) ? on.withValues(alpha: .9) : l.c, borderRadius: BorderRadius.circular(btnR)),
    );
    final heroBox = switch (hero) {
      'cover' || 'poster' || 'diagonal' => Container(
        decoration: BoxDecoration(color: l.c, borderRadius: BorderRadius.circular(r)),
        padding: const EdgeInsets.all(6),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [title, const SizedBox(height: 4), btn]),
      ),
      'gradient' => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [l.c, l.c2]),
          borderRadius: BorderRadius.circular(r),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [title, const SizedBox(height: 4), btn]),
      ),
      'split' || 'frame' || 'editorial' => Row(
        children: [
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 4), btn]),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: l.c2.withValues(alpha: .8), borderRadius: BorderRadius.circular(r)),
            ),
          ),
        ],
      ),
      _ => Column(mainAxisAlignment: MainAxisAlignment.center, children: [title, const SizedBox(height: 4), btn]),
    };
    return Container(
      decoration: BoxDecoration(color: l.bg, borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: l.c, borderRadius: BorderRadius.circular(3)),
              ),
              const Spacer(),
              for (var i = 0; i < 3; i++)
                Container(
                  margin: const EdgeInsets.only(left: 3),
                  width: 9,
                  height: 3,
                  decoration: BoxDecoration(color: l.ink.withValues(alpha: .35), borderRadius: BorderRadius.circular(2)),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Expanded(
            flex: 5,
            child: SizedBox(width: double.infinity, child: heroBox),
          ),
          const SizedBox(height: 5),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: l.sf,
                        borderRadius: BorderRadius.circular(r),
                        border: Border.all(color: l.ink.withValues(alpha: .1)),
                      ),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: l.c.withValues(alpha: .8), shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// the main colours of a picture (for "colours from my logo")
Future<List<String>?> logoColors(String url) async {
  final r = await Dio().get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(r.data!), targetWidth: 48, targetHeight: 48);
  final img = (await codec.getNextFrame()).image;
  final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) return null;
  final px = data.buffer.asUint8List();
  final buckets = <String, List<double>>{}; // n, r, g, b, sat
  for (var i = 0; i + 3 < px.length; i += 4) {
    final rr = px[i], g = px[i + 1], b = px[i + 2], a = px[i + 3];
    if (a < 128) continue;
    final mx = [rr, g, b].reduce((x, y) => x > y ? x : y), mn = [rr, g, b].reduce((x, y) => x < y ? x : y);
    if (mx > 240 && mn > 225) continue;
    if (mx < 25) continue;
    final sat = mx == 0 ? 0.0 : (mx - mn) / mx;
    final e = buckets.putIfAbsent('${rr >> 4},${g >> 4},${b >> 4}', () => [0, 0, 0, 0, 0]);
    e[0] += 1;
    e[1] += rr;
    e[2] += g;
    e[3] += b;
    e[4] += sat;
  }
  if (buckets.isEmpty) return null;
  String hex(List<double> e) => '#${[e[1] / e[0], e[2] / e[0], e[3] / e[0]].map((v) => v.round().toRadixString(16).padLeft(2, '0')).join()}'.toUpperCase();
  final list = buckets.values.toList()..sort((a, b) => (b[0] * (.4 + b[4] / b[0])).compareTo(a[0] * (.4 + a[4] / a[0])));
  final first = list.first;
  bool far(List<double> e) => (e[1] / e[0] - first[1] / first[0]).abs() + (e[2] / e[0] - first[2] / first[0]).abs() + (e[3] / e[0] - first[3] / first[0]).abs() > 120;
  return [hex(first), hex(list.where(far).firstOrNull ?? first)];
}

// ------------------------------------------------------------------------------------------- look & style
class StyleTab extends StatefulWidget {
  final WbCtx ctx;
  const StyleTab({super.key, required this.ctx});
  @override
  State<StyleTab> createState() => _StyleTabState();
}

class _StyleTabState extends State<StyleTab> {
  WbCtx get ctx => widget.ctx;
  String _busy = '', _cat = 'all', _fam = '';
  int _limit = 24;
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  List<String> get _owned => (obj(ctx.data['themes'])['owned'] as List? ?? const []).map((e) => '$e').toList();

  Future<void> _set(Json patch, [String key = 'x']) async {
    setState(() => _busy = key);
    await saveSite(ctx, {'style': patch});
    if (mounted) setState(() => _busy = '');
  }

  Future<void> _useTheme(String k) async {
    if (!_owned.contains(k) && !wbFreeThemes.contains(k)) return ctx.askBuy({'theme': k});
    setState(() => _busy = k);
    final r = await ctx.run(() => ctx.api.post('${ctx.base}/themes/$k', {}));
    if (r != null) ctx.put((_) => obj(r['data']));
    if (mounted) setState(() => _busy = '');
  }

  // tap a look → the look sheet over the looks shown (big site picture, swipe for the next), Use / Buy at the bottom
  Future<void> _openLook(String key, List<String> list) async {
    final s = ctx.site;
    final price = n(obj(ctx.data['themes'])['price']);
    final siteName = tx(s['name'], ctx.lang).isEmpty ? str(ctx.business['name']) : tx(s['name'], ctx.lang);
    await showLookSheet(
      context,
      title: ctx.m('tabs.style'),
      count: list.length,
      initial: list.contains(key) ? list.indexOf(key) : 0,
      item: (context, i, refresh) {
        final k = list[i];
        final t = wbTheme(k);
        final current = ctx.site['theme'] == k;
        final owned = _owned.contains(k) || wbFreeThemes.contains(k);
        final cat = wbThemeCats.where((c) => c.$1 == t.cat).firstOrNull;
        return LookItem(
          name: t.name(ctx.lang),
          sub: [if (cat != null) (ctx.lang == 'km' ? cat.$3 : cat.$2), wbThemeDescOf(k, ctx.lang)].where((x) => x.isNotEmpty).join(' · '),
          badge: current ? ctx.m('inUse') : (wbFreeThemes.contains(k) ? ctx.m('free') : (owned ? ctx.m('owned') : '${fmt(price)} ${ctx.m('coins')}')),
          badgeTone: current || owned ? Tone.good : Tone.warn,
          preview: SizedBox(
            width: 340,
            height: 272,
            child: LookMini(theme: k, name: siteName, style: current ? obj(s['style']) : const {}),
          ),
          acts: [
            if (!current && owned)
              LookAct(
                ctx.m('useLook'),
                icon: LucideIcons.check,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        await _useTheme(k);
                        return true;
                      },
              ),
            if (!owned)
              LookAct(
                ctx.m('buyLook', {'coins': fmt(price)}),
                gold: true,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        ctx.askBuy({'theme': k});
                        return true;
                      },
              ),
            if (current)
              LookAct(
                ctx.m('viewSite'),
                icon: LucideIcons.externalLink,
                ghost: true,
                onTap: () async {
                  await launchUrl(Uri.parse(ctx.siteUrl), mode: LaunchMode.externalApplication);
                  return false;
                },
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = ctx.site;
    final st = obj(s['style']);
    final brand = ctx.on('web_brand');
    final theme = wbTheme(str(s['theme']));
    final themeKey = wbThemeKey(str(s['theme']));
    final owned = _owned;
    final price = n(obj(ctx.data['themes'])['price']);
    final qq = _q.text.trim().toLowerCase();
    final shown = wbThemes.keys.where((k) {
      final t = wbThemes[k]!;
      if (_cat == 'free' && !wbFreeThemes.contains(k)) return false;
      if (_cat == 'owned' && !owned.contains(k)) return false;
      if (!['all', 'free', 'owned'].contains(_cat) && t.cat != _cat) return false;
      if (_fam.isNotEmpty && t.parts['style'] != _fam) return false;
      return qq.isEmpty || '${t.en} ${t.km} $k ${wbThemeDescOf(k, 'en')} ${wbThemeDescOf(k, 'km')}'.toLowerCase().contains(qq);
    }).toList();
    final chips = <(String, String, int)>[
      ('all', ctx.m('allLooks'), wbThemes.length),
      ('free', ctx.m('free'), wbFreeThemes.length),
      ('owned', ctx.m('owned'), owned.length),
      for (final cat in wbThemeCats) (cat.$1, ctx.lang == 'km' ? cat.$3 : cat.$2, wbThemes.values.where((t) => t.cat == cat.$1).length),
    ];
    final siteName = tx(s['name'], ctx.lang).isEmpty ? str(ctx.business['name']) : tx(s['name'], ctx.lang);
    String hex(int v) => '#${(v & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    return _list([
      wbHead(context, LucideIcons.palette, ctx.m('looksTitle'), ctx.m('looksSub', {'coins': fmt(price), 'n': wbThemes.length})),
      mGap,
      wbPanel([
        Field(controller: _q, hint: ctx.m('searchLooks'), icon: LucideIcons.search, onChanged: (_) => setState(() => _limit = 24)),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final (k, l, cnt) in chips)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('$l $cnt'),
                    selected: _cat == k,
                    onSelected: (_) => setState(() {
                      _cat = k;
                      _limit = 24;
                    }),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _fam,
          isExpanded: true,
          decoration: const InputDecoration(isDense: true),
          items: [
            DropdownMenuItem(value: '', child: Text(ctx.m('allStyles'))),
            for (final f in wbThemeStyles) DropdownMenuItem(value: f.$1, child: Text('${ctx.lang == 'km' ? f.$3 : f.$2} (${wbThemes.values.where((t) => t.parts['style'] == f.$1).length})')),
          ],
          onChanged: (v) => setState(() {
            _fam = v ?? '';
            _limit = 24;
          }),
        ),
      ]),
      mGap,
      if (shown.isEmpty)
        Muted(ctx.m('noLooks'))
      else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .9),
          itemCount: shown.length.clamp(0, _limit),
          itemBuilder: (_, i) {
            final k = shown[i];
            final t = wbThemes[k]!;
            final on = themeKey == k;
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openLook(k, shown),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: on ? c.brand : c.line, width: on ? 2 : 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: LookMini(theme: k, name: siteName),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.name(ctx.lang),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                          ),
                        ),
                        if (on)
                          Icon(LucideIcons.check, size: 14, color: c.good)
                        else if (wbFreeThemes.contains(k))
                          Text(
                            ctx.m('free'),
                            style: TextStyle(color: c.good, fontSize: 11, fontWeight: FontWeight.w700),
                          )
                        else if (owned.contains(k))
                          Text(
                            ctx.m('owned'),
                            style: TextStyle(color: c.good, fontSize: 11, fontWeight: FontWeight.w700),
                          )
                        else ...[
                          const CoinIcon(size: 11),
                          const SizedBox(width: 2),
                          Text(fmt(price), style: const TextStyle(fontSize: 11)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      if (shown.length > _limit) ...[
        const SizedBox(height: 10),
        Center(
          child: Btn(ctx.m('moreLooks', {'n': shown.length - _limit}), kind: BtnKind.ghost, small: true, onTap: () => setState(() => _limit += 24)),
        ),
      ],
      mGap,
      wbPanel([
        Text(ctx.m('colorTitle'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        Muted(ctx.m('colorSub')),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Swatch(color: Color(theme.c), on: str(st['color']).isEmpty, tip: ctx.m('colorTheme'), ring: true, onTap: ctx.readOnly ? null : () => _set({'color': ''})),
            for (final col in wbColors) _Swatch(color: hexColor(col), on: str(st['color']).toUpperCase() == col, onTap: ctx.readOnly ? null : () => _set({'color': col})),
          ],
        ),
        gap14,
        if (!brand)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GoldBtn('${ctx.m('brandLock')} · ${fmt(n(ctx.addon('web_brand')['price']))}', onTap: ctx.readOnly ? null : () => ctx.askBuy({'addon': 'web_brand'})),
          ),
        Opacity(
          opacity: brand ? 1 : .5,
          child: IgnorePointer(
            ignoring: !brand || ctx.readOnly,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (key, label, def) in [('color', ctx.m('colorTitle'), theme.c), ('accent', ctx.m('accent'), theme.c2), ('bg', ctx.m('bg'), theme.bg)])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        InkWell(
                          onTap: () async {
                            final v = await _pickColor(context, str(st[key]).isEmpty ? hex(def) : str(st[key]));
                            if (v != null) _set({key: v});
                          },
                          child: Container(
                            width: 64,
                            height: 32,
                            decoration: BoxDecoration(
                              color: str(st[key]).isEmpty ? Color(def) : hexColor(st[key]),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: c.line),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: str(st[key]).isNotEmpty ? IconButton(onPressed: () => _set({key: ''}), icon: const Icon(LucideIcons.rotateCcw, size: 15)) : null,
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Btn(
                    ctx.m('fromLogo'),
                    icon: LucideIcons.paintbrush,
                    kind: BtnKind.ghost,
                    small: true,
                    busy: _busy == 'logo',
                    onTap: () async {
                      if (str(s['logo']).isEmpty) return ctx.notify(ctx.m('fromLogoNone'));
                      setState(() => _busy = 'logo');
                      try {
                        final cols = await logoColors(str(s['logo']));
                        if (cols != null &&
                            await saveSite(ctx, {
                                  'style': {'color': cols[0], 'accent': cols[1]},
                                }) !=
                                null) {
                          ctx.notify(ctx.m('fromLogoDone'));
                        }
                      } catch (e) {
                        ctx.notify('$e');
                      }
                      if (mounted) setState(() => _busy = '');
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
      mGap,
      wbPanel([
        Text(ctx.m('fontTitle'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        Muted(ctx.m('fontSub')),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in wbFonts.entries)
              () {
                final k = e.key;
                final allowed = brand || wbFreeFonts.contains(k) || k == theme.font;
                final on = (str(st['font']).isEmpty ? theme.font : str(st['font'])) == k;
                return ChoiceChip(
                  selected: on,
                  avatar: allowed ? null : const Icon(LucideIcons.lock, size: 13),
                  label: Text('${ctx.lang == 'km' ? e.value.$2 : e.value.$1}${k == theme.font ? ' · ${ctx.m('fontTheme')}' : ''}'),
                  onSelected: ctx.readOnly ? null : (_) => allowed ? _set({'font': k == theme.font ? '' : k}) : ctx.askBuy({'addon': 'web_brand'}),
                );
              }(),
          ],
        ),
      ]),
      mGap,
      wbPanel([
        Text(ctx.m('buttonsTitle'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        const SizedBox(height: 8),
        Segmented<String>(
          value: str(st['buttons']),
          options: [('', ctx.m('btnTheme')), ('round', ctx.m('btnRound')), ('pill', ctx.m('btnPill')), ('square', ctx.m('btnSquare'))],
          onChanged: ctx.readOnly ? (_) {} : (v) => _set({'buttons': v}),
        ),
        gap14,
        Text(ctx.m('modeTitle'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        const SizedBox(height: 8),
        Segmented<String>(
          value: str(st['mode']),
          options: [('', ctx.m('modeAuto')), ('light', ctx.m('modeLight')), ('dark', ctx.m('modeDark'))],
          onChanged: ctx.readOnly ? (_) {} : (v) => _set({'mode': v}),
        ),
      ]),
    ]);
  }

  Future<String?> _pickColor(BuildContext context, String start) async {
    var cur = hexColor(start);
    final ctl = TextEditingController(text: start.toUpperCase());
    final r = await showDialog<String>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 56,
                decoration: BoxDecoration(color: cur, borderRadius: BorderRadius.circular(12)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final col in [...wbColors, '#FFFFFF', '#F8FAFC', '#FFF7ED', '#0F1218'])
                    InkWell(
                      onTap: () => set(() {
                        cur = hexColor(col);
                        ctl.text = col;
                      }),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: hexColor(col),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black12),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Field(
                controller: ctl,
                hint: '#E0581A',
                maxLength: 7,
                onChanged: (v) {
                  if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(v)) set(() => cur = hexColor(v));
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: Text(ctx.m('cancel'))),
            FilledButton(onPressed: RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(ctl.text) ? () => Navigator.pop(d, ctl.text.toUpperCase()) : null, child: Text(ctx.m('save'))),
          ],
        ),
      ),
    );
    ctl.dispose();
    return r;
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final bool on, ring;
  final String? tip;
  final VoidCallback? onTap;
  const _Swatch({required this.color, required this.on, this.onTap, this.tip, this.ring = false});
  @override
  Widget build(BuildContext context) {
    final w = InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: on ? context.c.ink : (ring ? context.c.line : Colors.transparent), width: on ? 2.5 : 1.5),
        ),
        child: on
            ? Icon(LucideIcons.check, size: 16, color: color.computeLuminance() > .5 ? Colors.black : Colors.white)
            : (ring ? const Icon(LucideIcons.sparkles, size: 13, color: Colors.white70) : null),
      ),
    );
    return tip == null ? w : Tooltip(message: tip!, child: w);
  }
}

// ------------------------------------------------------------------------------------------- business info
class ProfileTab extends StatefulWidget {
  final WbCtx ctx;
  const ProfileTab({super.key, required this.ctx});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  WbCtx get ctx => widget.ctx;
  late Json _name = Map<String, dynamic>.from(obj(ctx.site['name']));
  late Json _tagline = Map<String, dynamic>.from(obj(ctx.site['tagline']));
  String _busy = '';

  Future<void> _setLogo(String url) async {
    if (await saveSite(ctx, {'logo': url}) != null) ctx.notify(url.isNotEmpty ? ctx.m('logoSaved') : ctx.m('saved'));
  }

  Future<void> _upload() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 88);
    if (f == null) return;
    setState(() => _busy = 'logo');
    final r = await ctx.run(() async => ctx.api.post('${ctx.base}/media', fileForm('photo', await f.readAsBytes(), f.name.isEmpty ? 'logo.jpg' : f.name)));
    if (r != null) await _setLogo(str(obj(r['data'])['url']));
    if (mounted) setState(() => _busy = '');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = ctx.site;
    final logo = str(s['logo']);
    final ro = ctx.readOnly;
    final name = tx(_name, ctx.lang).isEmpty ? str(ctx.business['name']) : tx(_name, ctx.lang);
    Widget chip(String sub, Widget mark) => Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          mark,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                Muted(sub),
              ],
            ),
          ),
        ],
      ),
    );
    Widget mark(Widget fallback) => Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Center(child: fallback),
    );
    return _list([
      wbHead(context, LucideIcons.store, ctx.m('tabs.profile'), ctx.m('profileSub')),
      mGap,
      wbPanel([
        Row(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: c.bg2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.globe, size: 34, color: c.muted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ctx.m('logo'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                  Muted(ctx.m('logoSub')),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Btn(logo.isNotEmpty ? ctx.m('logoChange') : ctx.m('logoUpload'), icon: LucideIcons.upload, small: true, busy: _busy == 'logo', onTap: ro || _busy.isNotEmpty ? null : _upload),
            Btn(
              ctx.m('fromLibrary'),
              kind: BtnKind.ghost,
              small: true,
              onTap: ro
                  ? null
                  : () async {
                      final u = await showSheet<String>(context, (_) => MediaSheet(ctx: ctx));
                      if (u != null && u.isNotEmpty) _setLogo(u);
                    },
            ),
            if (logo.isNotEmpty) Btn(ctx.m('removeImage'), icon: LucideIcons.trash2, kind: BtnKind.ghost, small: true, onTap: ro ? null : () => _setLogo('')),
          ],
        ),
      ]),
      mGap,
      wbPanel([
        Text(ctx.m('siteTitle'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        const SizedBox(height: 10),
        TrInput(value: _name, onChanged: (v) => setState(() => _name = v), elang: 'km', label: ctx.m('siteName'), max: 80, ctx: ctx, enabled: !ro),
        TrInput(value: _name, onChanged: (v) => setState(() => _name = v), elang: 'en', label: ctx.m('siteName'), max: 80, ctx: ctx, enabled: !ro),
        TrInput(value: _tagline, onChanged: (v) => setState(() => _tagline = v), elang: 'km', label: ctx.m('tagline'), max: 160, ctx: ctx, enabled: !ro),
        TrInput(value: _tagline, onChanged: (v) => setState(() => _tagline = v), elang: 'en', label: ctx.m('tagline'), max: 160, ctx: ctx, enabled: !ro),
        Align(
          alignment: Alignment.centerLeft,
          child: Btn(
            ctx.m('save'),
            icon: LucideIcons.save,
            small: true,
            busy: _busy == 'save',
            onTap: ro || _busy.isNotEmpty
                ? null
                : () async {
                    setState(() => _busy = 'save');
                    if (await saveSite(ctx, {'name': _name, 'tagline': _tagline}) != null) ctx.notify(ctx.m('saved'));
                    if (mounted) setState(() => _busy = '');
                  },
          ),
        ),
      ]),
      mGap,
      wbPanel([
        Text(ctx.m('logoWhere'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        const SizedBox(height: 10),
        chip(ctx.m('whereDash'), mark(Icon(LucideIcons.globe, size: 18, color: c.brand))),
        const SizedBox(height: 8),
        chip(
          ctx.m('whereSite', {'slug': s['slug']}),
          mark(
            Text(
              name.isEmpty ? '?' : name.characters.first,
              style: TextStyle(fontWeight: FontWeight.w900, color: c.brand),
            ),
          ),
        ),
      ]),
    ]);
  }
}

// ------------------------------------------------------------------------------------------- settings
class SettingsTab extends StatefulWidget {
  final WbCtx ctx;
  const SettingsTab({super.key, required this.ctx});
  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  WbCtx get ctx => widget.ctx;
  late final Json _contact = Map<String, dynamic>.from(obj(ctx.site['contact']));
  late Json _footer = Map<String, dynamic>.from(obj(ctx.site['footer']));
  late final Json _seo = Map<String, dynamic>.from(obj(ctx.site['seo']));
  bool _busy = false;

  List<String> get _langs {
    final l = (ctx.site['langs'] as List? ?? const []).map((e) => '$e').toList();
    return l.isEmpty ? ['km', 'en'] : l;
  }

  Future<void> _slug() async {
    if (!ctx.on('web_slug')) return ctx.askBuy({'addon': 'web_slug'});
    final ctl = TextEditingController(text: str(ctx.site['slug']));
    String err = '';
    var busy = false;
    await showSheet<void>(
      context,
      (sheet) => StatefulBuilder(
        builder: (sheet, set) => MSheet(
          title: ctx.m('slugChange'),
          footer: [
            const Spacer(),
            Btn(ctx.m('cancel'), kind: BtnKind.ghost, small: true, onTap: busy ? null : () => Navigator.pop(sheet)),
            const SizedBox(width: 8),
            Btn(
              ctx.m('save'),
              small: true,
              busy: busy,
              onTap: busy
                  ? null
                  : () async {
                      final v = ctl.text;
                      if (!RegExp(r'^[a-z0-9](?:[a-z0-9-]{1,38})[a-z0-9]$').hasMatch(v)) return set(() => err = ctx.m('slugBad'));
                      set(() => busy = true);
                      try {
                        final r = await ctx.api.put('${ctx.base}/settings', {'slug': v});
                        ctx.put(
                          (d) => {
                            'site': {...obj(d['site']), ...obj(r['data'])},
                          },
                        );
                        if (sheet.mounted) Navigator.pop(sheet);
                      } on ApiError catch (e) {
                        set(() {
                          err = e.status == 409 ? ctx.m('slugTaken') : e.message;
                          busy = false;
                        });
                      }
                    },
            ),
          ],
          children: [
            Muted(ctx.m('slugWhat')),
            const SizedBox(height: 10),
            Field(
              controller: ctl,
              maxLength: 40,
              prefix: Padding(
                padding: const EdgeInsets.only(left: 12, right: 2),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    '/site/',
                    style: TextStyle(color: sheet.c.muted, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              onChanged: (v) {
                final x = v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '-');
                if (x != v) {
                  ctl.value = TextEditingValue(
                    text: x,
                    selection: TextSelection.collapsed(offset: x.length),
                  );
                }
              },
            ),
            if (err.isNotEmpty) ...[const SizedBox(height: 8), Alert(err)],
          ],
        ),
      ),
    );
    ctl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = ctx.site;
    final ro = ctx.readOnly;
    final link = ctx.siteUrl;
    final langs = _langs;
    Future<void> setLangs(List<String> next) async => saveSite(ctx, {'langs': next});
    Widget contact(String k, String label, String ph) => PlainInput(value: str(_contact[k]), label: label, hint: ph, max: k == 'map_url' ? 800 : 300, enabled: !ro, onChanged: (v) => _contact[k] = v);
    return _list([
      wbHead(context, LucideIcons.settings, ctx.m('tabs.settings'), ''),
      mGap,
      wbPanel([
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.line),
              ),
              child: QrImageView(data: link, size: 92, padding: EdgeInsets.zero),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ctx.m('linkTitle'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                  Muted(ctx.m('linkSub')),
                  const SizedBox(height: 4),
                  SelectableText(
                    link.replaceFirst(RegExp(r'^https?://'), ''),
                    style: TextStyle(color: c.brand, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Btn(
              ctx.m('copy'),
              icon: LucideIcons.copy,
              kind: BtnKind.ghost,
              small: true,
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: link));
                ctx.notify(ctx.m('copied'));
              },
            ),
            Btn(ctx.m('downloadQr'), icon: LucideIcons.download, kind: BtnKind.ghost, small: true, onTap: () => shareQr(link, '${s['slug']}-qr.png')),
            Btn(ctx.m('slugChange'), icon: ctx.on('web_slug') ? LucideIcons.pencil : LucideIcons.lock, kind: BtnKind.ghost, small: true, onTap: ro ? null : _slug),
          ],
        ),
      ]),
      mGap,
      wbPanel([
        Text(ctx.m('langsTitle'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        Muted(ctx.m('langsSub')),
        const SizedBox(height: 8),
        for (final l in ['km', 'en'])
          Row(
            children: [
              Expanded(
                child: SwitchRow(
                  title: l == 'km' ? 'ខ្មែរ' : 'English',
                  value: langs.contains(l),
                  onChanged: ro || (langs.contains(l) && langs.length == 1) ? null : (v) => setLangs(v ? [...langs, l] : langs.where((x) => x != l).toList()),
                ),
              ),
              if (langs.contains(l) && langs.length > 1) ...[
                const SizedBox(width: 8),
                langs.first == l
                    ? Chip2(ctx.m('first'), tone: Tone.good)
                    : Btn(ctx.m('makeFirst'), kind: BtnKind.ghost, small: true, onTap: ro ? null : () => setLangs([l, ...langs.where((x) => x != l)])),
              ],
            ],
          ),
      ]),
      mGap,
      wbPanel([
        Text(ctx.m('contactTitle'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        Muted(ctx.m('contactSub')),
        const SizedBox(height: 10),
        contact('phone', 'Phone / ទូរស័ព្ទ', '012 345 678'),
        contact('telegram', 'Telegram', '@yourname'),
        contact('facebook', 'Facebook', 'facebook.com/…'),
        contact('instagram', 'Instagram', 'instagram.com/…'),
        contact('tiktok', 'TikTok', 'tiktok.com/@…'),
        contact('youtube', 'YouTube', 'youtube.com/@…'),
        contact('email', 'Email / អ៊ីមែល', 'you@example.com'),
        contact('map_url', 'Google Maps', 'https://maps.app.goo.gl/…'),
        TrInput(value: _contact['address'], onChanged: (v) => _contact['address'] = v, elang: 'km', label: 'អាសយដ្ឋាន / Address', max: 300, ctx: ctx, enabled: !ro),
        TrInput(value: _contact['address'], onChanged: (v) => _contact['address'] = v, elang: 'en', label: 'អាសយដ្ឋាន / Address', max: 300, ctx: ctx, enabled: !ro),
        TrInput(value: _footer, onChanged: (v) => _footer = v, elang: 'km', label: ctx.m('footerText'), max: 300, ctx: ctx, enabled: !ro),
        TrInput(value: _footer, onChanged: (v) => _footer = v, elang: 'en', label: ctx.m('footerText'), max: 300, ctx: ctx, enabled: !ro),
      ]),
      mGap,
      wbPanel([
        Text(ctx.m('seoTitle'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        Muted(ctx.m('seoSub')),
        const SizedBox(height: 10),
        TrInput(value: _seo['title'], onChanged: (v) => _seo['title'] = v, elang: 'km', label: ctx.m('seoName'), max: 80, ctx: ctx, enabled: !ro),
        TrInput(value: _seo['title'], onChanged: (v) => _seo['title'] = v, elang: 'en', label: ctx.m('seoName'), max: 80, ctx: ctx, enabled: !ro),
        TrInput(value: _seo['description'], onChanged: (v) => _seo['description'] = v, elang: 'km', label: ctx.m('seoDesc'), long: true, max: 300, ctx: ctx, enabled: !ro),
        TrInput(value: _seo['description'], onChanged: (v) => _seo['description'] = v, elang: 'en', label: ctx.m('seoDesc'), long: true, max: 300, ctx: ctx, enabled: !ro),
        ImageField(value: str(_seo['image']), onChanged: (v) => setState(() => _seo['image'] = v), label: ctx.m('seoImage'), ctx: ctx),
      ]),
      mGap,
      Btn(
        ctx.m('save'),
        icon: LucideIcons.save,
        busy: _busy,
        onTap: _busy || ro
            ? null
            : () async {
                setState(() => _busy = true);
                if (await saveSite(ctx, {'footer': _footer, 'contact': _contact, 'seo': _seo}) != null) ctx.notify(ctx.m('saved'));
                if (mounted) setState(() => _busy = false);
              },
      ),
      mGap,
      wbPanel([
        Text(ctx.m('changeStarter'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        Muted(ctx.m('startSub')),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Btn(
            ctx.m('changeStarter'),
            icon: LucideIcons.rotateCcw,
            kind: BtnKind.ghost,
            small: true,
            onTap: ro
                ? null
                : () => showSheet<void>(
                    context,
                    (sheet) => MSheet(
                      title: ctx.m('changeStarter'),
                      children: [TemplatePicker(ctx: ctx, replace: true, onDone: () => Navigator.pop(sheet))],
                    ),
                  ),
          ),
        ),
      ]),
      if (s['published'] == true) ...[
        mGap,
        wbPanel([
          Text(ctx.m('offlineTitle'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
          Muted(ctx.m('offlineSub')),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Btn(
              ctx.m('unpublish'),
              icon: LucideIcons.wifiOff,
              kind: BtnKind.ghost,
              small: true,
              onTap: ro
                  ? null
                  : () async {
                      if (!await wbConfirm(context, ctx, ctx.m('offlineTitle'), ctx.m('offlineSub'), yes: ctx.m('unpublish'))) return;
                      final r = await ctx.run(() => ctx.api.post('${ctx.base}/unpublish', {}));
                      if (r != null) {
                        ctx.put(
                          (d) => {
                            'site': {...obj(d['site']), ...obj(r['data'])},
                          },
                        );
                      }
                    },
            ),
          ),
        ]),
      ],
    ]);
  }
}

// ------------------------------------------------------------------------------------------- messages
class InboxTab extends StatefulWidget {
  final WbCtx ctx;
  const InboxTab({super.key, required this.ctx});
  @override
  State<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<InboxTab> {
  WbCtx get ctx => widget.ctx;
  List<Json>? _rows;
  int _unread = 0, _page = 1, _pages = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ctx.run(() => ctx.api.get('${ctx.base}/messages', {'page': _page}));
    if (r == null || !mounted) return;
    setState(() {
      _rows = objs(r['data']);
      _unread = n(r['unread']).toInt();
      _pages = n(obj(r['pagination'])['totalPages']).toInt().clamp(1, 1 << 20);
    });
    ctx.put(
      (d) => {
        'counts': {...obj(d['counts']), 'unread': _unread},
      },
    );
  }

  Future<void> _act(Future<Json> Function() fn) async {
    if (await ctx.run(fn) != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ro = ctx.readOnly;
    final rows = _rows;
    return RefreshIndicator(
      onRefresh: _load,
      child: _list([
        wbHead(
          context,
          LucideIcons.inbox,
          ctx.m('inboxTitle'),
          ctx.m('inboxSub'),
          actions: [
            if (_unread > 0) Btn(ctx.m('readAll'), icon: LucideIcons.check, kind: BtnKind.ghost, small: true, onTap: ro ? null : () => _act(() => ctx.api.put('${ctx.base}/messages-read-all', {}))),
          ],
        ),
        mGap,
        if (rows == null) const SkelList(rows: 3) else if (rows.isEmpty) wbPanel([Muted(ctx.m('inboxEmpty'), align: TextAlign.center)]),
        for (final r in rows ?? const <Json>[])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border(left: BorderSide(color: r['read'] == true ? Colors.transparent : c.brand, width: 4)),
              ),
              child: wbPanel([
                Row(
                  children: [
                    Expanded(
                      child: Text(str(r['name']).isEmpty ? '—' : str(r['name']), style: TextStyle(fontWeight: r['read'] == true ? FontWeight.w700 : FontWeight.w900)),
                    ),
                    Text(dkTime(r['created_date'], ctx.lang), style: TextStyle(color: c.muted, fontSize: 12)),
                  ],
                ),
                if (str(r['page']).isNotEmpty) Muted(ctx.m('fromPage', {'page': r['page']})),
                const SizedBox(height: 6),
                SelectableText(str(r['text']), style: const TextStyle(height: 1.45)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (str(r['phone']).isNotEmpty)
                      Btn(str(r['phone']), icon: LucideIcons.phone, kind: BtnKind.ghost, small: true, onTap: () => launchUrl(Uri.parse('tel:${str(r['phone']).replaceAll(RegExp(r'[^\d+]'), '')}'))),
                    if (str(r['email']).isNotEmpty) Btn(str(r['email']), icon: LucideIcons.mail, kind: BtnKind.ghost, small: true, onTap: () => launchUrl(Uri.parse('mailto:${r['email']}'))),
                    Btn(
                      r['read'] == true ? ctx.m('markUnread') : ctx.m('markRead'),
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: ro ? null : () => _act(() => ctx.api.put('${ctx.base}/messages/${r['_id']}', {'read': r['read'] != true})),
                    ),
                    RoundBtn(LucideIcons.trash2, size: 36, tip: ctx.m('delete'), fg: c.danger, onTap: ro ? null : () => _act(() => ctx.api.delete('${ctx.base}/messages/${r['_id']}'))),
                  ],
                ),
              ]),
            ),
          ),
        if (_pages > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _page <= 1
                    ? null
                    : () {
                        setState(() => _page--);
                        _load();
                      },
                icon: const Icon(LucideIcons.chevronLeft),
              ),
              Text('$_page / $_pages'),
              IconButton(
                onPressed: _page >= _pages
                    ? null
                    : () {
                        setState(() => _page++);
                        _load();
                      },
                icon: const Icon(LucideIcons.chevronRight),
              ),
            ],
          ),
      ]),
    );
  }
}

// ------------------------------------------------------------------------------------------- blog
class BlogTab extends StatefulWidget {
  final WbCtx ctx;
  const BlogTab({super.key, required this.ctx});
  @override
  State<BlogTab> createState() => _BlogTabState();
}

class _BlogTabState extends State<BlogTab> {
  WbCtx get ctx => widget.ctx;
  List<Json>? _rows;

  @override
  void initState() {
    super.initState();
    if (ctx.on('web_blog')) _load();
  }

  Future<void> _load() async {
    final r = await ctx.run(() => ctx.api.get('${ctx.base}/posts'));
    if (r != null && mounted) setState(() => _rows = objs(r['data']));
  }

  Future<void> _edit(Json? post) async {
    final saved = await showSheet<Json>(context, (_) => _PostSheet(ctx: ctx, post: post));
    if (saved == null) return;
    setState(() => _rows = post == null ? [saved, ...?_rows] : [for (final x in _rows ?? const <Json>[]) x['_id'] == saved['_id'] ? saved : x]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ro = ctx.readOnly;
    if (!ctx.on('web_blog')) return _list([wbHead(context, LucideIcons.newspaper, ctx.m('blogTitle'), ctx.m('blogSub')), mGap, WbLocked(ctx: ctx, addon: 'web_blog')]);
    final rows = _rows;
    return _list([
      wbHead(
        context,
        LucideIcons.newspaper,
        ctx.m('blogTitle'),
        ctx.m('blogSub'),
        actions: [Btn(ctx.m('newPost'), icon: LucideIcons.plus, small: true, onTap: ro ? null : () => _edit(null))],
      ),
      mGap,
      if (rows == null) const SkelList(rows: 3) else if (rows.isEmpty) wbPanel([Muted(ctx.m('postsEmpty'), align: TextAlign.center)]),
      for (final p in rows ?? const <Json>[])
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 52,
                  decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(10)),
                  clipBehavior: Clip.antiAlias,
                  child: str(p['cover']).isNotEmpty
                      ? Image(image: netImage(str(p['cover'])), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())
                      : Icon(LucideIcons.newspaper, color: c.brand),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx(p['title'], ctx.lang),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Muted('${dkDate(p['date'], ctx.lang)} · ${p['published'] == true ? ctx.m('postPublished') : ctx.m('postDraft')} · ${ctx.m('views', {'n': fmt(n(p['views']))})}'),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'open') {
                      launchUrl(Uri.parse('${ctx.siteUrl}/blog/${p['slug']}'), mode: LaunchMode.externalApplication);
                    } else if (v == 'edit') {
                      _edit(p);
                    } else if (await wbConfirm(context, ctx, ctx.m('deletePost'), ctx.m('deletePostSub', {'name': tx(p['title'], ctx.lang)}))) {
                      if (await ctx.run(() => ctx.api.delete('${ctx.base}/posts/${p['_id']}')) != null) setState(() => _rows!.remove(p));
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'open', child: Text(ctx.m('viewSite'))),
                    if (!ro) PopupMenuItem(value: 'edit', child: Text(ctx.m('editPost'))),
                    if (!ro)
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(ctx.m('deletePost'), style: TextStyle(color: c.danger)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ]);
  }
}

class _PostSheet extends StatefulWidget {
  final WbCtx ctx;
  final Json? post;
  const _PostSheet({required this.ctx, required this.post});
  @override
  State<_PostSheet> createState() => _PostSheetState();
}

class _PostSheetState extends State<_PostSheet> {
  WbCtx get ctx => widget.ctx;
  late final Json _f = {
    'title': {'km': str(obj(widget.post?['title'])['km']), 'en': str(obj(widget.post?['title'])['en'])},
    'excerpt': {'km': str(obj(widget.post?['excerpt'])['km']), 'en': str(obj(widget.post?['excerpt'])['en'])},
    'body': {'km': str(obj(widget.post?['body'])['km']), 'en': str(obj(widget.post?['body'])['en'])},
    'cover': str(widget.post?['cover']),
    'category': str(widget.post?['category']),
    'published': widget.post == null || widget.post!['published'] == true,
    'date': (str(widget.post?['date']).isEmpty ? DateTime.now().toIso8601String() : str(widget.post!['date'])).substring(0, 10),
  };
  String _elang = 'km';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final t = obj(_f['title']);
    return MSheet(
      title: widget.post != null ? ctx.m('editPost') : ctx.m('newPost'),
      footer: [
        const Spacer(),
        Btn(ctx.m('cancel'), kind: BtnKind.ghost, small: true, onTap: _busy ? null : () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(
          ctx.m('save'),
          icon: LucideIcons.save,
          small: true,
          busy: _busy,
          onTap: _busy || (str(t['km']).trim().isEmpty && str(t['en']).trim().isEmpty)
              ? null
              : () async {
                  setState(() => _busy = true);
                  final p = widget.post;
                  final r = await ctx.run(() => p != null ? ctx.api.put('${ctx.base}/posts/${p['_id']}', _f) : ctx.api.post('${ctx.base}/posts', _f));
                  if (!context.mounted) return;
                  if (r != null) {
                    Navigator.pop(context, obj(r['data']));
                  } else {
                    setState(() => _busy = false);
                  }
                },
        ),
      ],
      children: [
        Row(
          children: [
            Text(ctx.m('editIn'), style: TextStyle(color: context.c.muted, fontSize: 12.5)),
            const SizedBox(width: 6),
            Segmented<String>(value: _elang, options: const [('km', 'ខ្មែរ'), ('en', 'English')], onChanged: (v) => setState(() => _elang = v)),
          ],
        ),
        gap14,
        TrInput(key: ValueKey('t$_elang'), value: _f['title'], onChanged: (v) => setState(() => _f['title'] = v), elang: _elang, label: ctx.m('postTitle'), max: 160, ctx: ctx),
        TrInput(key: ValueKey('e$_elang'), value: _f['excerpt'], onChanged: (v) => _f['excerpt'] = v, elang: _elang, label: ctx.m('postExcerpt'), max: 400, long: true, ctx: ctx),
        TrInput(key: ValueKey('b$_elang'), value: _f['body'], onChanged: (v) => _f['body'] = v, elang: _elang, label: ctx.m('postBody'), max: 20000, long: true, ctx: ctx),
        Padding(padding: const EdgeInsets.only(bottom: 12), child: Muted(ctx.m('postBodyHint'))),
        ImageField(value: str(_f['cover']), onChanged: (v) => setState(() => _f['cover'] = v), label: ctx.m('postCover'), ctx: ctx),
        PlainInput(value: str(_f['category']), label: ctx.m('postCategory'), max: 40, onChanged: (v) => _f['category'] = v),
        DayField(label: ctx.m('postDate'), value: str(_f['date']), onChanged: (v) => setState(() => _f['date'] = v)),
        gap14,
        SwitchRow(title: ctx.m('postPublished'), value: _f['published'] == true, onChanged: (v) => setState(() => _f['published'] = v)),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------- visits
String _flag(Object? cc) {
  final s = str(cc);
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(s)) return '🌐';
  return String.fromCharCodes(s.codeUnits.map((c) => 127397 + c));
}

class StatsTab extends StatefulWidget {
  final WbCtx ctx;
  const StatsTab({super.key, required this.ctx});
  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  WbCtx get ctx => widget.ctx;
  int _days = 30;
  Json? _d;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ctx.run(() => ctx.api.get('${ctx.base}/stats', {'days': _days}));
    if (r != null && mounted) setState(() => _d = obj(r['data']));
  }

  String _pageName(Object? slug) {
    if (slug == 'blog') return ctx.m('tabs.blog');
    final p = ctx.pages.where((x) => x['slug'] == slug).firstOrNull;
    return p != null ? tx(p['title'], ctx.lang) : str(slug);
  }

  String _dev(Object? k) => switch (k) {
    'mobile' => ctx.m('devMobile'),
    'tablet' => ctx.m('devTablet'),
    'desktop' => ctx.m('devDesktop'),
    _ => str(k),
  };

  Widget _bars(BuildContext context, String title, List<Json> rows, String Function(Object? k) label) {
    final c = context.c;
    final max = rows.fold<num>(1, (a, r) => n(r['n']) > a ? n(r['n']) : a);
    final total = rows.fold<num>(0, (a, r) => a + n(r['n']));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: wbPanel([
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 8),
        if (rows.isEmpty) const Muted('—'),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(label(r['key']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(value: n(r['n']) / max, minHeight: 8, backgroundColor: c.bg2, color: c.brand),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    fmt(n(r['n'])),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                ),
                SizedBox(
                  width: 38,
                  child: Text(
                    '${total == 0 ? 0 : (n(r['n']) / total * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: c.muted, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = _d;
    final pro = obj(d?['pro']);
    final hasPro = d?['pro'] != null;
    return RefreshIndicator(
      onRefresh: _load,
      child: _list([
        wbHead(
          context,
          LucideIcons.chartColumn,
          ctx.m('statsTitle'),
          ctx.m('statsSub'),
          actions: [
            Segmented<int>(
              value: _days,
              options: [(7, ctx.m('days7')), (30, ctx.m('days30')), (90, ctx.m('days90'))],
              onChanged: (v) {
                setState(() => _days = v);
                _load();
              },
            ),
          ],
        ),
        mGap,
        if (d == null)
          const SkelList(rows: 3)
        else ...[
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.3,
            children: [
              for (final (l, v) in [
                (ctx.m('today'), d['today']),
                (ctx.m('total', {'n': _days}), d['total']),
                hasPro ? (ctx.m('uniqueVisitors'), pro['unique']) : (ctx.m('avg'), d['avg']),
                (ctx.m('allTime'), d['all_time']),
              ])
                Panel(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.muted, fontSize: 12),
                      ),
                      Text(fmt(n(v)), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 21)),
                    ],
                  ),
                ),
            ],
          ),
          mGap,
          wbPanel([
            if (n(d['total']) == 0)
              Muted(ctx.m('noVisits'))
            else
              SizedBox(
                height: 130,
                child: () {
                  final series = objs(d['series']);
                  final max = series.fold<num>(1, (a, x) => n(x['views']) > a ? n(x['views']) : a);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final x in series)
                        Expanded(
                          child: Tooltip(
                            message: '${x['day']}: ${x['views']}',
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: .8),
                              height: 130 * (n(x['views']) / max).clamp(.02, 1).toDouble(),
                              decoration: BoxDecoration(
                                color: c.brand,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                }(),
              ),
          ]),
          if (objs(d['top']).isNotEmpty) ...[
            mGap,
            wbPanel([
              Text(ctx.m('topPages'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 6),
              for (final x in objs(d['top']))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(_pageName(x['page']))),
                      Text(fmt(n(x['views'])), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
            ]),
          ],
          mGap,
          if (hasPro) ...[
            _bars(context, ctx.m('countries'), objs(pro['countries']), (k) => '${_flag(k)} ${str(k).isEmpty ? ctx.m('unknown') : k}'),
            _bars(context, ctx.m('cities'), objs(pro['cities']), (k) => str(k)),
            _bars(context, ctx.m('sources'), objs(pro['sources']), (k) => str(k).isEmpty ? ctx.m('direct') : str(k)),
            _bars(context, ctx.m('devices'), objs(pro['devices']), _dev),
            _bars(context, ctx.m('browsers'), objs(pro['browsers']), (k) => str(k)),
            _bars(context, ctx.m('systems'), objs(pro['os']), (k) => str(k)),
            wbPanel([
              Text(ctx.m('busyHours'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: () {
                  final hours = (pro['hours'] as List? ?? List.filled(24, 0)).map(n).toList();
                  final max = hours.fold<num>(1, (a, x) => x > a ? x : a);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final (h, v) in hours.indexed)
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                height: 80 * (v / max).clamp(.03, 1).toDouble(),
                                decoration: BoxDecoration(
                                  color: c.brand.withValues(alpha: .75),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                ),
                              ),
                              SizedBox(
                                height: 16,
                                child: Text(h % 3 == 0 ? '$h' : '', style: TextStyle(fontSize: 9.5, color: c.muted)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                }(),
              ),
            ]),
            mGap,
            wbPanel([
              Text(ctx.m('recentVisits'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Muted(ctx.m('ipNote')),
              const SizedBox(height: 6),
              if (objs(pro['recent']).isEmpty) Muted(ctx.m('noVisits')),
              for (final v in objs(pro['recent']))
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.line)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_pageName(v['page']), style: const TextStyle(fontWeight: FontWeight.w700)),
                            Muted(str(v['country']).isNotEmpty ? '${_flag(v['country'])} ${[v['city'], v['country']].where((e) => str(e).isNotEmpty).join(', ')}' : ctx.m('unknown')),
                            Muted([_dev(v['device']), v['browser'], v['os']].where((e) => str(e).isNotEmpty).join(' · ')),
                            Muted('${str(v['source']).isEmpty ? ctx.m('direct') : v['source']} · ${str(v['ip']).isEmpty ? '—' : v['ip']}'),
                          ],
                        ),
                      ),
                      Text(dkTime(v['at'], ctx.lang), style: TextStyle(color: c.muted, fontSize: 12)),
                    ],
                  ),
                ),
            ]),
          ] else ...[
            WbLocked(ctx: ctx, addon: 'web_stats'),
            const SizedBox(height: 8),
            wbPanel([
              for (final x in ctx.t.list('wb.statsPerks'))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.check, size: 15, color: c.good),
                      const SizedBox(width: 8),
                      Expanded(child: Text(x)),
                    ],
                  ),
                ),
            ]),
          ],
        ],
      ]),
    );
  }
}

// ------------------------------------------------------------------------------------------- Telegram
class TelegramTab extends StatefulWidget {
  final WbCtx ctx;
  const TelegramTab({super.key, required this.ctx});
  @override
  State<TelegramTab> createState() => _TelegramTabState();
}

class _TelegramTabState extends State<TelegramTab> {
  WbCtx get ctx => widget.ctx;
  late Json _tg = obj(ctx.data['telegram']);
  String _busy = '';
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _link(bool group) async {
    setState(() => _busy = 'link');
    final r = await ctx.run(() => ctx.api.post('${ctx.base}/telegram/link', {}));
    if (r != null) {
      final u = str(obj(r['data'])[group ? 'group_url' : 'url']);
      if (u.isNotEmpty) await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
      _poll?.cancel();
      var tries = 0;
      _poll = Timer.periodic(const Duration(seconds: 3), (t) async {
        if (++tries > 100) return t.cancel();
        try {
          final x = await ctx.api.get('${ctx.base}/telegram');
          if (!mounted) return t.cancel();
          setState(() => _tg = obj(x['data']));
          if (_tg['connected'] == true) {
            t.cancel();
            ctx.put((_) => {'telegram': _tg});
          }
        } catch (_) {}
      });
    }
    if (mounted) setState(() => _busy = '');
  }

  @override
  Widget build(BuildContext context) {
    final head = wbHead(context, LucideIcons.send, ctx.m('tgTitle'), ctx.m('tgSub'));
    if (!ctx.on('web_telegram')) return _list([head, mGap, WbLocked(ctx: ctx, addon: 'web_telegram')]);
    final ro = ctx.readOnly;
    final tg = _tg;
    return _list([
      head,
      mGap,
      wbPanel([
        if (tg['configured'] != true)
          Muted(ctx.m('tgNotConfigured'))
        else if (tg['connected'] == true) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Chip2(ctx.m('tgConnected', {'name': tg['chat_name']}), icon: LucideIcons.check, tone: Tone.good),
          ),
          gap14,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Btn(
                ctx.m('tgTest'),
                icon: LucideIcons.send,
                small: true,
                busy: _busy == 'test',
                onTap: _busy.isNotEmpty || ro
                    ? null
                    : () async {
                        setState(() => _busy = 'test');
                        await ctx.run(() => ctx.api.post('${ctx.base}/telegram/test', {}), ctx.m('tgSentOk'));
                        if (mounted) setState(() => _busy = '');
                      },
              ),
              Btn(
                ctx.m('tgDisconnect'),
                icon: LucideIcons.unplug,
                kind: BtnKind.ghost,
                small: true,
                onTap: _busy.isNotEmpty || ro
                    ? null
                    : () async {
                        final r = await ctx.run(() => ctx.api.delete('${ctx.base}/telegram'));
                        if (r == null) return;
                        setState(() => _tg = obj(r['data']));
                        ctx.put((_) => {'telegram': _tg});
                      },
              ),
            ],
          ),
        ] else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Btn(ctx.m('tgConnect'), icon: LucideIcons.send, busy: _busy == 'link', onTap: _busy.isNotEmpty || ro ? null : () => _link(false)),
              Btn(ctx.m('tgGroup'), kind: BtnKind.ghost, onTap: _busy.isNotEmpty || ro ? null : () => _link(true)),
            ],
          ),
          if (_poll?.isActive == true) ...[const SizedBox(height: 8), Muted(ctx.m('tgWaiting'))],
        ],
        gap14,
        Muted(ctx.m('tgHow')),
      ]),
    ]);
  }
}

// ------------------------------------------------------------------------------------------- add-ons
class AddonsTab extends StatelessWidget {
  final WbCtx ctx;
  const AddonsTab({super.key, required this.ctx});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ro = ctx.readOnly;
    final lic = ctx.license;
    Widget card(IconData icon, String name, String price, String what, List<Widget> foot, {bool on = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: on ? c.goodBg : c.active, borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: on ? c.good : c.brand),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                      Row(
                        children: [
                          const CoinIcon(size: 13),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              price,
                              style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(what, style: const TextStyle(height: 1.45)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: foot),
          ],
        ),
      ),
    );
    final themesPrice = n(obj(ctx.data['themes'])['price']);
    return _list([
      wbHead(context, LucideIcons.puzzle, ctx.m('addonsTitle'), ctx.m('addonsSub', {'coins': fmt(n(ctx.addon('web_brand')['price']))})),
      mGap,
      card(LucideIcons.globe, ctx.m('renewTitle'), '${fmt(n(ctx.data['renew_price']))} ${ctx.m('coins')} ${ctx.m('perYear')}', ctx.m('renewSub'), [
        if (lic['expires_at'] != null) Chip2(ctx.m('ends', {'date': dkDate(lic['expires_at'], ctx.lang)}), tone: lic['active'] == true ? Tone.good : Tone.muted),
        Btn(ctx.m('renew', {'coins': fmt(n(ctx.data['renew_price']))}), kind: BtnKind.ghost, small: true, onTap: ctx.business['status'] == false ? null : () => ctx.askBuy({'renew': true})),
      ], on: lic['active'] == true),
      for (final e in obj(ctx.data['addons']).entries)
        () {
          final a = obj(e.value);
          final k = e.key;
          final active = a['active'] == true;
          final yearly = a['days'] != null;
          return card(
            wbAddonIcons[k] ?? LucideIcons.puzzle,
            ctx.m('addonNames.$k'),
            '${fmt(n(a['price']))} ${ctx.m('coins')} ${yearly ? ctx.m('perYear') : '· ${ctx.m('forever')}'}',
            ctx.t.or('wb.addonWhat.$k', ''),
            active
                ? [
                    Chip2(a['expires_at'] != null ? ctx.m('ends', {'date': dkDate(a['expires_at'], ctx.lang)}) : ctx.m('unlocked'), icon: LucideIcons.check, tone: Tone.good),
                    if (yearly) Btn(ctx.m('renew', {'coins': fmt(n(a['price']))}), kind: BtnKind.ghost, small: true, onTap: ro ? null : () => ctx.askBuy({'addon': k})),
                  ]
                : [
                    GoldBtn(ctx.m('unlock', {'coins': fmt(n(a['price']))}), onTap: ro ? null : () => ctx.askBuy({'addon': k})),
                  ],
            on: active,
          );
        }(),
      card(LucideIcons.palette, ctx.m('premiumLooks'), '${fmt(themesPrice)} ${ctx.m('coins')} · ${ctx.m('forever')}', ctx.m('premiumLooksSub', {'coins': fmt(themesPrice)}), [
        Btn(ctx.m('goStyle'), icon: LucideIcons.arrowRight, kind: BtnKind.ghost, small: true, onTap: () => ctx.go('style')),
      ]),
    ]);
  }
}
