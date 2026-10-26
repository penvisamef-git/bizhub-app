import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/color_pick.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show MHead, GoldBtn, mGap, mDate, fileForm, MLookCard, openLookSheet;
import '../restaurant/rest_common.dart' show Segmented, SwitchRow;
import 'gh_common.dart';
import 'gh_site_looks.dart';

// The guest house website (gh_website, yearly) — address, content, 24 looks, booking requests. GhWebsite.jsx.
//   GET /site → { data: site, preview, addon, themes{owned,price}, unread, suggested_slug }

const _facilityKeys = [
  'wifi',
  'parking',
  'ac',
  'hot_water',
  'breakfast',
  'restaurant',
  'pool',
  'garden',
  'laundry',
  'airport',
  'tours',
  'bike',
  'motorbike',
  'family',
  'pets',
  'reception24',
  'kitchen',
  'terrace',
  'river_view',
  'cards',
];
const _contactKeys = ['title', 'phone', 'email', 'address', 'map_url', 'facebook', 'telegram', 'instagram', 'tiktok', 'whatsapp'];
const _sitePresets = ['#0F766E', '#0E7490', '#2563EB', '#4F46E5', '#7C3AED', '#BE185D', '#E11D48', '#DC2626', '#EA580C', '#CA8A04', '#4D7C0F', '#1C1917'];

// what the editor edits (texts only — pictures are saved straight away)
Json _draftOf(Json s) {
  Json o(String k) => obj(s[k]);
  final about = o('about'), rooms = o('rooms'), fac = o('facilities'), gal = o('gallery'), book = o('booking'), con = o('contact'), hero = o('hero'), seo = o('seo');
  final highs = objs(about['highlights']);
  return {
    'slug': str(s['slug']),
    'published': s['published'] == true,
    'theme': str(s['theme']).isEmpty ? 'classic' : str(s['theme']),
    'color': str(s['color']),
    'hero': {
      for (final k in ['kicker', 'title', 'subtitle', 'button']) k: str(hero[k]),
    },
    'about': {
      'enabled': about['enabled'] != false,
      'title': str(about['title']),
      'text': str(about['text']),
      'highlights': [
        for (var i = 0; i < 4; i++) {'value': i < highs.length ? str(highs[i]['value']) : '', 'label': i < highs.length ? str(highs[i]['label']) : ''},
      ],
    },
    'rooms': {
      'enabled': rooms['enabled'] != false,
      'title': str(rooms['title']),
      'subtitle': str(rooms['subtitle']),
      'show_prices': rooms['show_prices'] != false,
      'items': [
        for (final x in objs(rooms['items'])) {'type_id': str(x['type_id']), 'text': str(x['text']), 'hidden': x['hidden'] == true},
      ],
    },
    'facilities': {
      'enabled': fac['enabled'] != false,
      'title': str(fac['title']),
      'keys': (fac['keys'] as List? ?? const []).map((e) => '$e').toList(),
      'extra': (fac['extra'] as List? ?? const []).join(', '),
    },
    'gallery': {'enabled': gal['enabled'] != false, 'title': str(gal['title'])},
    'booking': {'enabled': book['enabled'] != false, 'title': str(book['title']), 'text': str(book['text']), 'show_free': book['show_free'] != false},
    'contact': {'enabled': con['enabled'] != false, for (final k in _contactKeys) k: str(con[k])},
    'footer_note': str(s['footer_note']),
    'seo': {'title': str(seo['title']), 'description': str(seo['description'])},
  };
}

Json _bodyOf(Json f) {
  final b = jsonDecode(jsonEncode(f)) as Json;
  final about = b['about'] as Json;
  about['highlights'] = [
    for (final h in about['highlights'] as List)
      if (str((h as Json)['value']).isNotEmpty || str(h['label']).isNotEmpty) h,
  ];
  final fac = b['facilities'] as Json;
  fac['extra'] = str(fac['extra']).split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
  return b;
}

class WebsiteTab extends StatefulWidget {
  final GhCtx ctx;
  const WebsiteTab({super.key, required this.ctx});
  @override
  State<WebsiteTab> createState() => _WebsiteTabState();
}

class _WebsiteTabState extends State<WebsiteTab> {
  Json? _info, _f;
  String _saved = '', _busy = '', _tab = 'edit';
  Json? _slugState;
  Timer? _slugWait;
  final Map<String, TextEditingController> _ctl = {};
  GhCtx get ctx => widget.ctx;
  String w(String k, [Map<String, Object?> v = const {}]) => ctx.t('gws.$k', v);
  String gs(String k) => ctx.t('gs.$k');

  @override
  void initState() {
    super.initState();
    _load(false);
  }

  @override
  void didUpdateWidget(WebsiteTab old) {
    super.didUpdateWidget(old);
    // after buying (add-on or a look) the page reloads: refresh looks + add-on, keep the draft
    if (!identical(old.ctx.data, ctx.data)) _load(true);
  }

  @override
  void dispose() {
    _slugWait?.cancel();
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load(bool keepDraft) async {
    try {
      final r = await ctx.api.get('${ctx.base}/site');
      if (!mounted) return;
      setState(() {
        _info = r;
        if (!keepDraft || _f == null) _reset(obj(r['data']), str(r['suggested_slug']));
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  void _reset(Json site, [String suggested = '']) {
    final d = _draftOf(site);
    // one line per room type, so the editor never changes the draft just by showing it
    final items = (d['rooms'] as Json)['items'] as List;
    for (final t in ctx.types) {
      if (!items.any((x) => (x as Json)['type_id'] == t['_id'])) items.add(<String, dynamic>{'type_id': str(t['_id']), 'text': '', 'hidden': false});
    }
    _saved = jsonEncode(d);
    if (str(d['slug']).isEmpty) d['slug'] = suggested;
    _f = d;
    for (final c in _ctl.values) {
      c.dispose();
    }
    _ctl.clear();
  }

  // a dotted path into the draft: 'hero.title', 'about.highlights.0.value'
  Object? _get(String path) {
    Object? cur = _f;
    for (final k in path.split('.')) {
      cur = cur is List ? cur[int.parse(k)] : (cur as Map?)?[k];
    }
    return cur;
  }

  void _set(String path, Object? v) {
    final ks = path.split('.');
    Object? cur = _f;
    for (final k in ks.take(ks.length - 1)) {
      cur = cur is List ? cur[int.parse(k)] : (cur as Map)[k];
    }
    if (cur is List) {
      cur[int.parse(ks.last)] = v;
    } else {
      (cur as Map)[ks.last] = v;
    }
    setState(() {});
  }

  TextEditingController _c(String path) => _ctl.putIfAbsent(path, () => TextEditingController(text: str(_get(path))));

  Widget _in(String path, String label, {int max = 100, String hint = '', int lines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Field(label: label, controller: _c(path), hint: hint, maxLength: max, maxLines: lines, enabled: !ctx.readOnly, onChanged: (v) => _set(path, v)),
  );

  Json _roomItem(String id) {
    final items = (_f!['rooms'] as Json)['items'] as List;
    final hit = items.cast<Json>().where((x) => x['type_id'] == id).firstOrNull;
    if (hit != null) return hit;
    final x = <String, dynamic>{'type_id': id, 'text': '', 'hidden': false};
    items.add(x);
    return x;
  }

  void _slug(String v) {
    final clean = v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '');
    final s = clean.length > 40 ? clean.substring(0, 40) : clean;
    if (s != v) {
      _c('slug').value = TextEditingValue(
        text: s,
        selection: TextSelection.collapsed(offset: s.length),
      );
    }
    _set('slug', s);
    _slugWait?.cancel();
    if (s.isEmpty || s == str(obj(_info!['data'])['slug'])) return setState(() => _slugState = null);
    _slugWait = Timer(const Duration(milliseconds: 400), () async {
      try {
        final r = await ctx.api.get('${ctx.base}/site/slug', {'value': s});
        if (mounted) setState(() => _slugState = obj(r['data']));
      } catch (_) {}
    });
  }

  Future<bool> _save([Json extra = const {}]) async {
    setState(() => _busy = 'save');
    try {
      final r = await ctx.api.put('${ctx.base}/site', {..._bodyOf(_f!), ...extra});
      if (mounted) {
        setState(() {
          _info = {..._info!, 'data': r['data'], 'preview': r['preview']};
          _reset(obj(r['data']));
          _slugState = null;
        });
      }
      ctx.notify(w('saved'));
      return true;
    } on ApiError catch (e) {
      if (e.status == 402) {
        e.body['product'] == 'gh_site_theme' ? ctx.askBuy('gh_site_theme', item: str(e.body['item'])) : ctx.askBuy('gh_website');
      } else {
        ctx.fail(e);
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  // pictures go up straight away
  Future<void> _pic(Future<Json> Function() fn) async {
    setState(() => _busy = 'pic');
    try {
      await fn();
      await _load(true);
    } on ApiError catch (e) {
      if (e.status == 402) {
        ctx.askBuy('gh_website');
      } else {
        ctx.fail(e);
      }
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Future<void> _upload(String slot, [String? typeId]) async {
    final b = await ghPickPicture(context, ctx, maxSize: 1800);
    if (b == null) return;
    await _pic(() => ctx.api.post('${ctx.base}/site/image', fileForm('file', b, 'photo.jpg')..fields.addAll([MapEntry('slot', slot), if (typeId != null) MapEntry('type_id', typeId)])));
  }

  Future<void> _drop(Json body) => _pic(() => ctx.api.delete('${ctx.base}/site/image', body));

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final info = _info, f = _f;
    if (info == null || f == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 5));
    final addon = obj(info['addon']);
    final on = addon['active'] == true;
    final site = obj(info['data']);
    final dirty = jsonEncode(f) != _saved;
    final slug = str(f['slug']);
    final url = slug.isNotEmpty ? '${Config.siteUrl}/g/$slug' : '';
    final live = site['published'] == true && site['slug'] == slug && url.isNotEmpty;
    final themes = obj(info['themes']);
    final owned = (themes['owned'] as List? ?? const []).map((e) => '$e').toSet()..add('classic');
    final cover = str(obj(obj(site['hero'])['image'])['url']).isNotEmpty ? str(obj(obj(site['hero'])['image'])['url']) : str(obj(ctx.settings['cover'])['url']);
    final unread = n(info['unread']);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Panel(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MHead(w('title'), icon: LucideIcons.globe, sub: on ? w('on', {'date': mDate(addon['expires_at'], ctx.lang)}) : w('off', {'price': fmt(n(addon['price']))})),
                    if (!on || addon['status'] == 'expiring')
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GoldBtn(on ? w('renew') : w('unlock', {'coins': fmt(n(addon['price']))}), onTap: ctx.readOnly ? null : () => ctx.askBuy('gh_website')),
                      ),
                  ],
                ),
              ),
              mGap,
              Panel(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Field(
                      label: w('address'),
                      controller: _c('slug'),
                      hint: 'my-guest-house',
                      enabled: !ctx.readOnly,
                      prefix: Padding(
                        padding: const EdgeInsets.only(left: 14, right: 2),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            '/g/',
                            style: TextStyle(color: c.muted, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      onChanged: _slug,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _slugState == null
                          ? w('addressHint')
                          : _slugState!['available'] == true
                          ? '✓ ${w('free')}'
                          : (_slugState!['reason'] == 'format' ? w('badFormat') : w('taken')),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _slugState == null
                            ? c.muted
                            : _slugState!['available'] == true
                            ? c.good
                            : c.danger,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SwitchRow(
                      title: f['published'] == true ? w('published') : w('hidden'),
                      sub: f['published'] == true ? w('publishedSub') : w('hiddenSub'),
                      value: f['published'] == true,
                      onChanged: ctx.readOnly ? null : (v) => !on && v ? ctx.askBuy('gh_website') : _set('published', v),
                    ),
                    if (live) ...[
                      const SizedBox(height: 4),
                      Text(
                        url,
                        style: TextStyle(color: c.brand, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Btn(
                            w('copy'),
                            icon: LucideIcons.copy,
                            kind: BtnKind.ghost,
                            small: true,
                            onTap: () async {
                              await Clipboard.setData(ClipboardData(text: url));
                              ctx.notify(w('copied'));
                            },
                          ),
                          Btn(
                            w('open'),
                            icon: LucideIcons.externalLink,
                            kind: BtnKind.ghost,
                            small: true,
                            onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              mGap,
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Segmented<String>(
                  value: _tab,
                  options: [('edit', w('tabs.edit')), ('looks', w('tabs.looks')), ('requests', '${w('tabs.requests')}${unread > 0 ? ' ($unread)' : ''}')],
                  onChanged: (v) => setState(() => _tab = v),
                ),
              ),
              mGap,
              if (_tab == 'edit') ..._editor(context, site, cover),
              if (_tab == 'looks')
                Panel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MHead(w('looksTitle'), icon: LucideIcons.palette, sub: w('looksSub', {'price': fmt(n(themes['price']))})),
                      LayoutBuilder(
                        builder: (_, box) {
                          final cols = box.maxWidth > 520 ? 3 : 2;
                          final cw = (box.maxWidth - 10 * (cols - 1)) / cols;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final k in ghSiteLooks.keys)
                                SizedBox(
                                  width: cw,
                                  child: () {
                                    final cur = str(site['theme']).isEmpty ? 'classic' : str(site['theme']);
                                    String status(String x) =>
                                        cur == x ? w('inUse') : (x == 'classic' ? ctx.g('free') : (owned.contains(x) ? ctx.g('owned') : '${fmt(n(themes['price']))} ${ctx.g('coins')}'));
                                    Widget thumb(String x) => GsThumb(look: x, name: str(ctx.business['name']), cover: cover, color: str(f['color']), types: ctx.types);
                                    return MLookCard(
                                      picture: thumb(k),
                                      name: ghSiteLooks[k]!.name(ctx.lang),
                                      on: cur == k,
                                      locked: !owned.contains(k),
                                      status: status(k),
                                      onTap: () => openLookSheet(
                                        context,
                                        title: w('looksTitle'),
                                        keys: ghSiteLooks.keys.toList(),
                                        start: k,
                                        current: cur,
                                        owned: owned.contains,
                                        name: (x) => ghSiteLooks[x]!.name(ctx.lang),
                                        sub: (x) => ghSiteLooks[x]!.sub(ctx.lang),
                                        big: (x) => SizedBox(width: 380, child: thumb(x)),
                                        status: status,
                                        useLabel: w('use'),
                                        buyLabel: (_) => ctx.g('unlock', {'coins': '${fmt(n(themes['price']))} ${ctx.g('coins')}'}),
                                        readOnly: ctx.readOnly || _busy.isNotEmpty,
                                        use: (x) async {
                                          _set('theme', x);
                                          await _save({'theme': x});
                                          return true;
                                        },
                                        buy: (x) => ctx.askBuy('gh_site_theme', item: x),
                                      ),
                                    );
                                  }(),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              if (_tab == 'requests') _SiteRequests(ctx: ctx, onCount: (v) => setState(() => _info = {..._info!, 'unread': v})),
            ],
          ),
        ),
        if (_tab == 'edit')
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: c.card,
              border: Border(top: BorderSide(color: c.line)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      dirty ? w('unsaved') : w('saved'),
                      style: TextStyle(color: dirty ? c.warn : c.muted, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  Btn(_busy == 'save' ? w('saving') : w('save'), icon: LucideIcons.save, small: true, busy: _busy == 'save', onTap: ctx.readOnly || _busy.isNotEmpty || !dirty ? null : () => _save()),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // a part of the website: title + "show this part" + its fields (folds open)
  Widget _part(String title, List<Widget> children, {String? toggle, IconData icon = LucideIcons.layoutTemplate}) {
    final off = toggle != null && _get(toggle) == false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(icon, size: 19, color: off ? context.c.muted : context.c.brand),
            title: Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w800, color: off ? context.c.muted : context.c.ink),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (toggle != null) SwitchRow(title: w('show'), value: !off, onChanged: ctx.readOnly ? null : (v) => _set(toggle, v)),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _pics(String label, List<String> list, int max, {String? hint, bool wide = false, required VoidCallback onAdd, required void Function(int i) onDrop}) {
    final c = context.c;
    final busy = _busy == 'pic';
    final size = wide ? const Size(150, 84) : const Size(84, 84);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Label(label, hint: hint),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, src) in list.indexed)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image(
                        image: netImage(src),
                        width: size.width,
                        height: size.height,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(width: size.width, height: size.height, color: c.bg2),
                      ),
                    ),
                    if (!ctx.readOnly)
                      Positioned(
                        top: 3,
                        right: 3,
                        child: InkWell(
                          onTap: busy ? null : () => onDrop(i),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(LucideIcons.trash2, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              if (list.length < max && !ctx.readOnly)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: busy ? null : onAdd,
                  child: Container(
                    width: size.width,
                    height: size.height,
                    decoration: BoxDecoration(
                      color: c.bg2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.line),
                    ),
                    child: busy
                        ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.imagePlus, size: 20, color: c.muted),
                              Text(w('addPhoto'), style: TextStyle(fontSize: 11, color: c.muted)),
                            ],
                          ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _editor(BuildContext context, Json site, String cover) {
    final c = context.c;
    final f = _f!;
    final biz = ctx.business, set = ctx.settings;
    List<String> urls(Object? list) => objs(list).map((i) => str(i['url'])).where((u) => u.isNotEmpty).toList();
    final heroImg = str(obj(obj(site['hero'])['image'])['url']);
    final aboutImg = str(obj(obj(site['about'])['image'])['url']);
    final gallery = urls(obj(site['gallery'])['images']);
    List<String> roomImgs(String id) => urls(objs(obj(site['rooms'])['items']).where((x) => str(x['type_id']) == id).firstOrNull?['images']);
    final keys = (f['facilities'] as Json)['keys'] as List;
    return [
      _part(w('color'), icon: LucideIcons.palette, [
        Row(
          children: [
            InkWell(
              onTap: ctx.readOnly ? null : () => _set('color', ''),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (ghSiteLooks[f['theme']] ?? ghSiteLooks['classic']!).accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: str(f['color']).isEmpty ? c.ink : Colors.transparent, width: 3),
                ),
                child: str(f['color']).isEmpty ? const Icon(LucideIcons.check, size: 15, color: Colors.white) : null,
              ),
            ),
            const SizedBox(width: 10),
            Muted(w('colorReset')),
          ],
        ),
        const SizedBox(height: 10),
        ColorRow(value: str(f['color']), colors: _sitePresets, customLabel: w('color'), saveLabel: w('save'), cancelLabel: ctx.g('cancel'), onChanged: ctx.readOnly ? null : (v) => _set('color', v)),
      ]),
      _part(w('hero'), icon: LucideIcons.image, [
        _pics(w('heroImg'), heroImg.isEmpty ? [] : [heroImg], 1, hint: w('heroImgHint'), wide: true, onAdd: () => _upload('hero'), onDrop: (_) => _drop({'slot': 'hero'})),
        _in('hero.kicker', w('kicker'), max: 60, hint: gs('welcome')),
        _in('hero.title', w('heroTitle'), max: 90, hint: str(biz['name'])),
        _in('hero.subtitle', w('heroSub'), max: 240, lines: 3),
        _in('hero.button', w('heroBtn'), max: 30, hint: gs('bookNow')),
      ]),
      _part(w('rooms'), toggle: 'rooms.enabled', icon: LucideIcons.bedDouble, [
        _in('rooms.title', w('roomsTitle'), max: 70, hint: gs('roomsTitle')),
        _in('rooms.subtitle', w('roomsSub'), max: 200, hint: gs('roomsSub')),
        SwitchRow(title: w('showPrices'), value: (f['rooms'] as Json)['show_prices'] == true, onChanged: ctx.readOnly ? null : (v) => _set('rooms.show_prices', v)),
        if (ctx.types.isEmpty) Muted(w('noTypes')),
        for (final t in ctx.types)
          () {
            final id = str(t['_id']);
            final it = _roomItem(id);
            final i = ((f['rooms'] as Json)['items'] as List).indexOf(it);
            final imgs = roomImgs(id);
            return Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(16)),
              child: Opacity(
                opacity: it['hidden'] == true ? .55 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: hexColor(str(t['color']), const Color(0xFF2563EB)),
                          child: const Icon(LucideIcons.bedDouble, size: 13, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('${str(t['name'])} · ${ctx.mo(t['price'])}${gs('perNight')}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: it['hidden'] == true,
                      onChanged: ctx.readOnly ? null : (v) => _set('rooms.items.$i.hidden', v == true),
                      title: Text(w('hideRoom')),
                    ),
                    _in('rooms.items.$i.text', w('roomText'), max: 400, lines: 3),
                    _pics(w('roomPhotos', {'n': imgs.length}), imgs, 6, onAdd: () => _upload('room', id), onDrop: (x) => _drop({'slot': 'room', 'type_id': id, 'index': x})),
                  ],
                ),
              ),
            );
          }(),
      ]),
      _part(w('about'), toggle: 'about.enabled', icon: LucideIcons.bookOpen, [
        _in('about.title', w('aboutTitle'), max: 70, hint: gs('aboutTitle')),
        _in('about.text', w('aboutText'), max: 2000, lines: 5, hint: str(set['description'])),
        _pics(w('aboutImg'), aboutImg.isEmpty ? [] : [aboutImg], 1, wide: true, onAdd: () => _upload('about'), onDrop: (_) => _drop({'slot': 'about'})),
        Label(w('highlights')),
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Field(controller: _c('about.highlights.$i.value'), hint: w('hValue'), maxLength: 20, onChanged: (v) => _set('about.highlights.$i.value', v)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Field(controller: _c('about.highlights.$i.label'), hint: w('hLabel'), maxLength: 40, onChanged: (v) => _set('about.highlights.$i.label', v)),
                ),
              ],
            ),
          ),
      ]),
      _part(w('facilities'), toggle: 'facilities.enabled', icon: LucideIcons.sparkles, [
        _in('facilities.title', w('facTitle'), max: 70, hint: gs('facilitiesTitle')),
        Chips<String>(
          options: [for (final k in _facilityKeys) (k, ctx.t.or('gs.fac.$k', k))],
          on: keys.contains,
          onTap: ctx.readOnly ? null : (k) => setState(() => keys.contains(k) ? keys.remove(k) : keys.add(k)),
        ),
        const SizedBox(height: 12),
        _in('facilities.extra', w('facExtra'), max: 500),
      ]),
      _part(w('gallery'), toggle: 'gallery.enabled', icon: LucideIcons.images, [
        _in('gallery.title', w('galTitle'), max: 70, hint: gs('galleryTitle')),
        _pics('${gallery.length}/16', gallery, 16, onAdd: () => _upload('gallery'), onDrop: (i) => _drop({'slot': 'gallery', 'index': i})),
      ]),
      _part(w('booking'), toggle: 'booking.enabled', icon: LucideIcons.calendarCheck, [
        _in('booking.title', w('bookTitle'), max: 70, hint: gs('bookTitle')),
        _in('booking.text', w('bookText'), max: 300, lines: 3, hint: gs('bookText')),
        SwitchRow(title: w('showFree'), value: (f['booking'] as Json)['show_free'] == true, onChanged: ctx.readOnly ? null : (v) => _set('booking.show_free', v)),
      ]),
      _part(w('contact'), toggle: 'contact.enabled', icon: LucideIcons.phone, [
        _in('contact.title', w('cTitle'), max: 70, hint: gs('contactTitle')),
        _in('contact.phone', w('phone'), max: 30, hint: str(biz['phone'])),
        _in('contact.email', w('email'), max: 80, hint: str(set['email'])),
        _in('contact.whatsapp', w('whatsapp'), max: 30),
        _in('contact.telegram', 'Telegram', max: 300, hint: str(set['telegram']).isEmpty ? 'https://t.me/…' : str(set['telegram'])),
        _in('contact.facebook', 'Facebook', max: 300, hint: str(set['facebook']).isEmpty ? 'https://facebook.com/…' : str(set['facebook'])),
        _in('contact.instagram', 'Instagram', max: 300),
        _in('contact.tiktok', 'TikTok', max: 300),
        _in('contact.map_url', w('map'), max: 300, hint: str(set['map_url']).isEmpty ? 'https://maps.app.goo.gl/…' : str(set['map_url'])),
        _in('contact.address', w('address2'), max: 200, hint: str(biz['address'])),
      ]),
      _part(w('footer'), icon: LucideIcons.search, [
        _in('footer_note', w('footerNote'), max: 200),
        _in('seo.title', w('seoTitle'), max: 70, hint: str(biz['name'])),
        _in('seo.description', w('seoDesc'), max: 160, lines: 3),
      ]),
    ];
  }
}

// messages sent from the website's booking form
class _SiteRequests extends StatefulWidget {
  final GhCtx ctx;
  final ValueChanged<num> onCount;
  const _SiteRequests({required this.ctx, required this.onCount});
  @override
  State<_SiteRequests> createState() => _SiteRequestsState();
}

class _SiteRequestsState extends State<_SiteRequests> {
  String _status = 'new';
  List<Json>? _rows;
  int _page = 1, _pages = 1;
  GhCtx get ctx => widget.ctx;
  String w(String k, [Map<String, Object?> v = const {}]) => ctx.t('gws.$k', v);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([int p = 1]) async {
    try {
      final r = await ctx.api.get('${ctx.base}/site/requests', {'status': _status == 'all' ? '' : _status, 'page': '$p'});
      if (!mounted) return;
      setState(() {
        _rows = p == 1 ? objs(r['data']) : [...?_rows, ...objs(r['data'])];
        _page = p;
        _pages = n(obj(r['pagination'])['totalPages']).toInt();
      });
      widget.onCount(n(r['unread']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _act(Future<Json> Function() fn) async {
    try {
      final r = await fn();
      widget.onCount(n(r['unread']));
      _load();
    } catch (e) {
      ctx.fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = _rows;
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MHead(w('reqTitle'), icon: LucideIcons.inbox, sub: w('reqSub')),
          Segmented<String>(
            value: _status,
            options: [('new', w('reqNew')), ('all', w('reqAll'))],
            onChanged: (v) {
              setState(() {
                _status = v;
                _rows = null;
              });
              _load();
            },
          ),
          const SizedBox(height: 10),
          if (rows == null)
            const SkelList(rows: 3)
          else if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Muted(w('reqNone'), align: TextAlign.center),
            )
          else ...[
            for (final r in rows)
              () {
                final contact = str(r['contact']);
                final mail = contact.contains('@');
                final isNew = r['status'] == 'new';
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: c.line)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isNew) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(str(r['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () => launchUrl(Uri.parse(mail ? 'mailto:$contact' : 'tel:${contact.replaceAll(RegExp(r'[^\d+]'), '')}')),
                        child: Text(
                          contact,
                          style: TextStyle(color: c.brand, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${ghDay(str(r['from']), ctx.lang, weekday: true)} → ${ghDay(str(r['to']), ctx.lang, weekday: true)} · ${w('nights', {'n': nightsOf(str(r['from']), str(r['to']))})}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      Muted('${str(r['type_name']).isEmpty ? w('anyRoom') : str(r['type_name'])} · ${w('guests', {'n': n(r['guests'])})} · ${mDate(r['created_date'], ctx.lang)}'),
                      if (str(r['message']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(str(r['message']))),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (!mail) Btn(w('call'), icon: LucideIcons.phone, kind: BtnKind.ghost, small: true, onTap: () => launchUrl(Uri.parse('tel:${contact.replaceAll(RegExp(r'[^\d+]'), '')}'))),
                          Btn(
                            isNew ? w('markDone') : w('markNew'),
                            icon: LucideIcons.check,
                            kind: BtnKind.ghost,
                            small: true,
                            onTap: () => _act(() => ctx.api.put('${ctx.base}/site/requests/${r['_id']}', {'status': isNew ? 'done' : 'new'})),
                          ),
                          Btn(
                            w('del'),
                            icon: LucideIcons.trash2,
                            kind: BtnKind.ghost,
                            small: true,
                            onTap: ctx.readOnly ? null : () => _act(() => ctx.api.delete('${ctx.base}/site/requests/${r['_id']}')),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }(),
            if (_page < _pages) Btn(w('more'), kind: BtnKind.ghost, small: true, onTap: () => _load(_page + 1)),
          ],
        ],
      ),
    );
  }
}
