import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/buy_sheet.dart';
import '../../widgets/color_pick.dart';
import '../../widgets/look_sheet.dart';
import '../../widgets/ui.dart';
import 'rest_common.dart';

// Website (the web's WebsiteTab.jsx): address, theme, sections. Images are saved straight away; the rest with Save.

extension on RestCtx {
  String ws(String key, [Map<String, Object?> vars = const {}]) => t('ws.$key', vars);
  String st(String key) => t('site.$key');
}

const _contactKeys = ['title', 'phone', 'email', 'address', 'hours', 'map_url', 'facebook', 'instagram', 'tiktok', 'telegram'];
const _navKeys = ['home', 'menu', 'about', 'gallery', 'message', 'contact'];

String slugify(String s) {
  final v = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]+'), '-').replaceAll(RegExp(r'-{2,}'), '-').replaceFirst(RegExp(r'^-+'), '');
  return v.length > 40 ? v.substring(0, 40) : v;
}

List<Json> _navOf(Object? nav) {
  final list = objs(nav).where((x) => _navKeys.contains(x['key'])).map((x) => <String, dynamic>{'key': x['key'], 'label': str(x['label']), 'show': x['show'] != false}).toList();
  for (final k in _navKeys) {
    if (!list.any((x) => x['key'] == k)) list.add({'key': k, 'label': '', 'show': true});
  }
  return list;
}

// the parts of the site the form edits
Json _formOf(Json site) {
  final hero = obj(site['hero']),
      about = obj(site['about']),
      form = obj(site['form']),
      menu = obj(site['menu']),
      gallery = obj(site['gallery']),
      contact = obj(site['contact']),
      seo = obj(site['seo']);
  return {
    'slug': str(site['slug']),
    'published': site['published'] == true,
    'theme': str(site['theme']).isEmpty ? 'classic' : site['theme'],
    'color': str(site['color']),
    'hero': {'title': str(hero['title']), 'subtitle': str(hero['subtitle']), 'button': str(hero['button'])},
    'nav': _navOf(site['nav']),
    'about': {
      'enabled': about['enabled'] != false,
      'title': str(about['title']),
      'text': str(about['text']),
      'image_side': str(about['image_side']).isEmpty ? 'left' : about['image_side'],
      'highlights': [
        for (final h in objs(about['highlights'])) {'value': str(h['value']), 'label': str(h['label'])},
      ],
    },
    'form': {'enabled': form['enabled'] != false, 'title': str(form['title']), 'text': str(form['text']), 'notify_telegram': form['notify_telegram'] != false},
    'menu': {
      'enabled': menu['enabled'] != false,
      'title': str(menu['title']),
      'mode': str(menu['mode']).isEmpty ? 'all' : menu['mode'],
      'featured_ids': ((menu['featured_ids'] as List?) ?? const []).map((e) => '$e').toList(),
      'show_prices': menu['show_prices'] != false,
    },
    'gallery': {'enabled': gallery['enabled'] != false, 'title': str(gallery['title'])},
    'contact': {'enabled': contact['enabled'] != false, for (final k in _contactKeys) k: str(contact[k])},
    'links': [
      for (final l in objs(site['links'])) {'label': str(l['label']), 'url': str(l['url'])},
    ],
    'footer_note': str(site['footer_note']),
    'seo': {'title': str(seo['title']), 'description': str(seo['description'])},
  };
}

class WebsiteSection extends StatefulWidget {
  final RestCtx ctx;
  const WebsiteSection({super.key, required this.ctx});
  @override
  State<WebsiteSection> createState() => _WebsiteSectionState();
}

class _WebsiteSectionState extends State<WebsiteSection> {
  Json? _res, _form;
  bool _saving = false;
  String _busy = '', _slugState = '';
  Timer? _slugTimer;
  int _rev = 0; // bumps when the form is reset, so text fields reload
  RestCtx get ctx => widget.ctx;
  bool get _on => ctx.addonOn('rest_website');

  @override
  void initState() {
    super.initState();
    if (_on) _load(reset: true);
  }

  @override
  void dispose() {
    _slugTimer?.cancel();
    super.dispose();
  }

  Json get _site => obj(_res?['data']);
  Json get _themes => obj(_res?['themes']);

  Future<void> _load({bool reset = false}) async {
    try {
      final r = await ctx.api.get('${ctx.base}/site');
      if (!mounted) return;
      setState(() {
        _res = r;
        if (reset || _form == null) {
          _form = _formOf(_site);
          if (str(_form!['slug']).isEmpty) _form!['slug'] = str(r['suggested_slug']);
          _rev++;
          _checkSlug();
        }
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  bool get _dirty => _form != null && jsonEncode(_form) != jsonEncode(_formOf(_site));
  bool _owns(String k) => ((_themes['free'] as List?) ?? const []).contains(k) || ((_themes['owned'] as List?) ?? const []).contains(k);

  // check the address while typing
  void _checkSlug() {
    _slugTimer?.cancel();
    final slug = str(_form?['slug']);
    if (slug.isEmpty || slug == str(_site['slug'])) {
      _slugState = slug.isEmpty ? '' : 'ok';
      return;
    }
    if (!RegExp(r'^[a-z0-9](?:[a-z0-9-]{1,38})[a-z0-9]$').hasMatch(slug) || slug.contains('--')) {
      _slugState = 'format';
      return;
    }
    _slugState = 'checking';
    _slugTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final r = await ctx.api.get('${ctx.base}/site/slug', {'value': slug});
        final d = obj(r['data']);
        if (mounted && str(_form?['slug']) == slug) setState(() => _slugState = d['available'] == true ? 'ok' : (d['reason'] == 'taken' ? 'taken' : 'format'));
      } catch (_) {
        if (mounted) setState(() => _slugState = '');
      }
    });
  }

  Future<void> _save() async {
    final theme = str(_form!['theme']);
    if (!_owns(theme)) return _buyTheme(theme);
    setState(() => _saving = true);
    try {
      final r = await ctx.api.put('${ctx.base}/site', _form);
      setState(() {
        _res = {..._res!, 'data': obj(r['data'])};
        _form = _formOf(_site);
        _rev++;
      });
      ctx.notify(ctx.r('saved'));
    } catch (e) {
      if (e is ApiError && e.status == 402 && e.body['product'] == 'rest_site_theme') {
        _buyTheme(str(e.body['item']));
      } else {
        ctx.fail(e);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _upload(String slot, {int max = 1, int size = 1600}) async {
    final picker = ImagePicker();
    final files = max > 1
        ? await picker.pickMultiImage(maxWidth: size.toDouble(), maxHeight: size.toDouble(), imageQuality: 85, limit: max)
        : [?await picker.pickImage(source: ImageSource.gallery, maxWidth: size.toDouble(), maxHeight: size.toDouble(), imageQuality: 85)];
    if (files.isEmpty) return;
    setState(() => _busy = slot);
    try {
      Json? last;
      for (final f in files.take(max)) {
        last = await ctx.api.post('${ctx.base}/site/image', imageForm(await f.readAsBytes(), '$slot.jpg', {'slot': slot}));
      }
      if (last != null && mounted) setState(() => _res = {..._res!, 'data': obj(last!['data'])});
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Future<void> _removeImage(String slot, [int? index]) async {
    setState(() => _busy = slot);
    try {
      final r = await ctx.api.delete('${ctx.base}/site/image', {'slot': slot, 'index': ?index});
      if (mounted) setState(() => _res = {..._res!, 'data': obj(r['data'])});
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  String _themeName(String k) => ctx.t.or('stheme.$k.name', k);
  Color _themeColor(String k, String part) => hexToColor(ctx.t.or('stheme.$k.$part', '#999999'));

  // tap a theme → the look sheet over all of them (swipe). "Use" sets the theme; the save bar saves it.
  Future<void> _openThemes(List<String> all, String start) => showLookSheet(
    context,
    title: ctx.ws('theme'),
    count: all.length,
    initial: all.contains(start) ? all.indexOf(start) : 0,
    item: (context, i, refresh) {
      final k = all[i];
      final on = str(_form?['theme']) == k;
      final free = ((_themes['free'] as List?) ?? const []).contains(k);
      final have = _owns(k);
      final price = n(_themes['price']);
      return LookItem(
        name: _themeName(k),
        preview: _ThemeArt(bg: _themeColor(k, 'bg'), fg: _themeColor(k, 'fg'), accent: _themeColor(k, 'accent'), big: true),
        badge: on ? ctx.t('extras.inUse') : (free ? ctx.ws('free') : (have ? ctx.ws('owned') : '${fmt(price)} ${ctx.r('coins')}')),
        badgeTone: on || have ? Tone.good : Tone.warn,
        acts: [
          if (!on && have)
            LookAct(
              ctx.t('extras.use'),
              icon: LucideIcons.check,
              onTap: ctx.readOnly
                  ? null
                  : () async {
                      setState(() => _form!['theme'] = k);
                      return true;
                    },
            ),
          if (!have)
            LookAct(
              ctx.ws('unlockTheme', {'coins': fmt(price)}),
              gold: true,
              onTap: ctx.readOnly
                  ? null
                  : () async {
                      Future.microtask(() => _buyTheme(k));
                      return true;
                    },
            ),
        ],
      );
    },
  );

  void _buyTheme(String k) {
    final price = n(_themes['price']);
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BuySheet(
        stage: _ThemeArt(bg: _themeColor(k, 'bg'), fg: _themeColor(k, 'fg'), accent: _themeColor(k, 'accent'), big: true),
        badge: ctx.ws('theme'),
        title: ctx.ws('themeBuyTitle', {'name': _themeName(k)}),
        sub: ctx.ws('themeBuySub'),
        perks: [ctx.ws('themePerk'), '${ctx.r('oneTime')} · ${ctx.r('forever')}'],
        price: price,
        buyLabel: ctx.r('buy', {'coins': '${fmt(price)} ${ctx.r('coins')}'}),
        doneTitle: ctx.r('unlockedTag'),
        doneSub: ctx.ws('themeDone', {'name': _themeName(k)}),
        doneButton: ctx.t('app.continue'),
        buy: () => ctx.api.post('${ctx.base}/site/themes/$k'),
        onDone: (_) {
          setState(() => _form!['theme'] = k);
          _load();
        },
      ),
    );
  }

  // a text field bound to form[part][key] (or form[part])
  Widget _text(String part, String? key, {String? label, String? hint, int max = 80, int lines = 1, TextInputType? keyboard}) {
    final f = _form!;
    final value = key == null ? str(f[part]) : str(obj(f[part])[key]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _BoundField(
        key: ValueKey('$_rev-$part-$key'),
        initial: value,
        label: label,
        hint: hint,
        max: max,
        lines: lines,
        keyboard: keyboard,
        enabled: !ctx.readOnly,
        onChanged: (v) => setState(() {
          if (key == null) {
            f[part] = v;
          } else {
            (f[part] as Map)[key] = v;
          }
        }),
      ),
    );
  }

  Widget _part(String title, String part, List<Widget> body) {
    final on = obj(_form![part])['enabled'] == true;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              Switch.adaptive(value: on, onChanged: ctx.readOnly ? null : (v) => setState(() => (_form![part] as Map)['enabled'] = v)),
            ],
          ),
          if (on) ...[const SizedBox(height: 10), ...body],
        ],
      ),
    );
  }

  Widget _image(String slot, String url, {bool wide = false}) {
    final c = context.c;
    final ro = ctx.readOnly;
    return Row(
      children: [
        Container(
          width: wide ? 120 : 80,
          height: 70,
          decoration: BoxDecoration(
            color: c.bg2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: url.isNotEmpty ? Image(image: netImage(url), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.imagePlus, color: c.muted),
        ),
        const SizedBox(width: 10),
        Btn(
          _busy == slot ? ctx.r('uploading') : (url.isNotEmpty ? ctx.r('change') : ctx.r('upload')),
          icon: LucideIcons.imagePlus,
          kind: BtnKind.ghost,
          small: true,
          busy: _busy == slot,
          onTap: ro || _busy.isNotEmpty ? null : () => _upload(slot, size: slot == 'hero' ? 1920 : 1400),
        ),
        if (url.isNotEmpty) ...[const SizedBox(width: 6), RoundBtn(LucideIcons.trash2, size: 38, fg: c.danger, onTap: ro || _busy.isNotEmpty ? null : () => _removeImage(slot))],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = ctx.settings;
    if (!_on) {
      final slug = slugify(str(s['name_en'])).isEmpty ? 'your-restaurant' : slugify(str(s['name_en']));
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RestHead(ctx.r('addonNames.rest_website'), sub: ctx.ws('promo')),
                for (final k in ['p1', 'p2', 'p3'])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(LucideIcons.circleCheck, size: 17, color: c.good),
                        const SizedBox(width: 8),
                        Expanded(child: Text(ctx.ws(k, {'url': '${Config.siteUrl.replaceFirst(RegExp(r'^https?://'), '')}/s/$slug'}), style: const TextStyle(height: 1.4))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          gap14,
          AddonPrompt(ctx: ctx, addonKey: 'rest_website'),
        ],
      );
    }
    final f = _form;
    if (_res == null || f == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 4));
    final site = _site;
    final ro = ctx.readOnly;
    final liveUrl = str(site['slug']).isNotEmpty ? '${Config.siteUrl}/s/${site['slug']}' : '';
    final themes = [...((_themes['free'] as List?) ?? const []), ...((_themes['paid'] as List?) ?? const [])].map((e) => '$e').toList();
    final theme = str(f['theme']);
    final nav = (f['nav'] as List).cast<Json>();
    final about = f['about'] as Map, menu = f['menu'] as Map;
    final highlights = (about['highlights'] as List).cast<Map>();
    final links = (f['links'] as List).cast<Map>();
    final items = objs(obj(_res!['preview'])['items']);
    final gallery = objs(obj(site['gallery'])['images']);
    final hlPh = ctx.t.list('ws.hlLabelPh');
    final slugMsg = switch (_slugState) {
      'checking' => ctx.ws('checking'),
      'ok' => ctx.ws('available'),
      'taken' => ctx.ws('taken'),
      'format' => ctx.ws('badFormat'),
      _ => '',
    };

    final list = <Widget>[
      // address + online
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(ctx.ws('address'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            _BoundField(
              key: ValueKey('$_rev-slug'),
              initial: str(f['slug']),
              max: 40,
              enabled: !ro,
              prefix: Padding(
                padding: const EdgeInsets.only(left: 14, right: 2),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    '/s/',
                    style: TextStyle(color: c.muted, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
              format: slugify,
              onChanged: (v) => setState(() {
                f['slug'] = v;
                _checkSlug();
              }),
            ),
            if (slugMsg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Row(
                  children: [
                    if (_slugState == 'checking')
                      const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Icon(_slugState == 'ok' ? LucideIcons.check : LucideIcons.x, size: 14, color: _slugState == 'ok' ? c.good : c.danger),
                    const SizedBox(width: 6),
                    Text(
                      slugMsg,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _slugState == 'ok' ? c.good : (_slugState == 'checking' ? c.muted : c.danger)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Muted(ctx.ws('addressHint')),
            const SizedBox(height: 8),
            SwitchRow(title: ctx.ws('published'), sub: ctx.ws('publishedHint'), value: f['published'] == true, onChanged: ro ? null : (v) => setState(() => f['published'] = v)),
            const SizedBox(height: 6),
            if (site['published'] == true && liveUrl.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Btn(
                    ctx.ws('open'),
                    icon: LucideIcons.externalLink,
                    small: true,
                    onTap: () => launchUrl(Uri.parse(liveUrl), mode: LaunchMode.externalApplication),
                  ),
                  Btn(
                    ctx.ws('copy'),
                    icon: LucideIcons.copy,
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: liveUrl));
                      ctx.notify(ctx.ws('copied'));
                    },
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: Chip2(ctx.ws('notOnline'), icon: LucideIcons.globe),
              ),
          ],
        ),
      ),
      gap14,
      // theme
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(ctx.ws('theme'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final k in themes)
                  GestureDetector(
                    onTap: () => _openThemes(themes, k),
                    child: Container(
                      width: 96,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme == k ? c.brand : c.line, width: theme == k ? 2 : 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ThemeArt(bg: _themeColor(k, 'bg'), fg: _themeColor(k, 'fg'), accent: _themeColor(k, 'accent')),
                          const SizedBox(height: 6),
                          Text(_themeName(k), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                          if (((_themes['free'] as List?) ?? const []).contains(k))
                            Text(ctx.ws('free'), style: TextStyle(fontSize: 11, color: c.muted))
                          else if (_owns(k))
                            Text(
                              ctx.ws('owned'),
                              style: TextStyle(fontSize: 11, color: c.good, fontWeight: FontWeight.w700),
                            )
                          else
                            Row(
                              children: [
                                Icon(LucideIcons.lock, size: 11, color: c.muted),
                                const SizedBox(width: 3),
                                Text(
                                  fmt(_themes['price']),
                                  style: TextStyle(fontSize: 11, color: c.muted, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            gap14,
            Text(ctx.ws('color'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: _themeColor(theme, 'accent'), radius: 8),
                  label: Text(ctx.ws('colorTheme')),
                  selected: str(f['color']).isEmpty,
                  onSelected: ro ? null : (_) => setState(() => f['color'] = ''),
                ),
                ChoiceChip(
                  avatar: str(f['color']).isNotEmpty ? CircleAvatar(backgroundColor: hexToColor(str(f['color'])), radius: 8) : const Icon(LucideIcons.plus, size: 14),
                  label: Text(ctx.ws('custom')),
                  selected: str(f['color']).isNotEmpty,
                  onSelected: ro
                      ? null
                      : (_) async {
                          final picked = await pickColor(context, str(f['color']).isNotEmpty ? hexToColor(str(f['color'])) : _themeColor(theme, 'accent'), ctx.r('save'), ctx.r('cancel'));
                          if (picked != null) setState(() => f['color'] = colorToHex(picked));
                        },
                ),
              ],
            ),
          ],
        ),
      ),
      gap14,
      // top
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(ctx.ws('top'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _text('hero', 'title', label: ctx.ws('heroTitle'), hint: str(s['name_en']).isNotEmpty ? str(s['name_en']) : ctx.ws('heroTitlePh')),
            _text('hero', 'subtitle', label: ctx.ws('heroSub'), max: 200),
            _text('hero', 'button', label: ctx.ws('heroButton'), hint: ctx.ws('heroButtonPh'), max: 30),
            Text(ctx.ws('heroImage'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _image('hero', str(obj(obj(site['hero'])['image'])['url']), wide: true),
            const SizedBox(height: 6),
            Muted(ctx.ws('heroImageHint')),
          ],
        ),
      ),
      gap14,
      // top menu + links
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RestHead(ctx.ws('navTitle'), sub: ctx.ws('navSub')),
            for (final (i, item) in nav.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Opacity(
                  opacity: item['show'] == true ? 1 : .55,
                  child: Row(
                    children: [
                      Column(
                        children: [
                          InkWell(
                            onTap: ro || i == 0 ? null : () => setState(() => nav.insert(i - 1, nav.removeAt(i))),
                            child: Icon(LucideIcons.chevronUp, size: 18, color: i == 0 ? c.line : c.muted),
                          ),
                          InkWell(
                            onTap: ro || i == nav.length - 1 ? null : () => setState(() => nav.insert(i + 1, nav.removeAt(i))),
                            child: Icon(LucideIcons.chevronDown, size: 18, color: i == nav.length - 1 ? c.line : c.muted),
                          ),
                        ],
                      ),
                      Switch.adaptive(value: item['show'] == true, onChanged: ro ? null : (v) => setState(() => item['show'] = v)),
                      SizedBox(
                        width: 78,
                        child: Text(ctx.ws('navNames.${item['key']}'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                      Expanded(
                        child: _BoundField(
                          key: ValueKey('$_rev-nav-${item['key']}'),
                          initial: str(item['label']),
                          hint: _navLabel(str(item['key'])),
                          max: 30,
                          enabled: !ro && item['show'] == true,
                          onChanged: (v) => setState(() => item['label'] = v),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Muted(ctx.ws('navHint')),
            gap14,
            Text(ctx.ws('links'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Muted(ctx.ws('linksHint')),
            const SizedBox(height: 8),
            for (final (i, l) in links.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _BoundField(
                        key: ValueKey('$_rev-ll-$i-${links.length}'),
                        initial: str(l['label']),
                        hint: ctx.ws('linkLabel'),
                        max: 30,
                        enabled: !ro,
                        onChanged: (v) => setState(() => l['label'] = v),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _BoundField(
                        key: ValueKey('$_rev-lu-$i-${links.length}'),
                        initial: str(l['url']),
                        hint: 'https://',
                        max: 300,
                        enabled: !ro,
                        keyboard: TextInputType.url,
                        onChanged: (v) => setState(() => l['url'] = v),
                      ),
                    ),
                    IconButton(
                      onPressed: ro ? null : () => setState(() => links.removeAt(i)),
                      icon: Icon(LucideIcons.trash2, size: 17, color: c.danger),
                    ),
                  ],
                ),
              ),
            if (links.length < 6)
              Align(
                alignment: Alignment.centerLeft,
                child: Btn(ctx.ws('addLink'), icon: LucideIcons.plus, kind: BtnKind.ghost, small: true, onTap: ro ? null : () => setState(() => links.add({'label': '', 'url': ''}))),
              ),
          ],
        ),
      ),
      gap14,
      _part(ctx.ws('about'), 'about', [
        _text('about', 'title', label: ctx.ws('aboutTitle'), hint: ctx.ws('aboutTitlePh'), max: 60),
        _text('about', 'text', label: ctx.ws('aboutText'), hint: ctx.ws('aboutTextPh'), max: 1500, lines: 5),
        Text(ctx.ws('aboutImage'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _image('about', str(obj(obj(site['about'])['image'])['url'])),
        gap14,
        Text(ctx.ws('photoSide'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Segmented<String>(value: str(about['image_side']), options: [('left', ctx.ws('left')), ('right', ctx.ws('right'))], onChanged: ro ? null : (v) => setState(() => about['image_side'] = v)),
        gap14,
        Text(ctx.ws('highlights'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Muted(ctx.ws('highlightsHint')),
        const SizedBox(height: 8),
        for (final (i, h) in highlights.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: _BoundField(
                    key: ValueKey('$_rev-hv-$i-${highlights.length}'),
                    initial: str(h['value']),
                    hint: const ['1998', '40+', '4.9★', '100%'][i.clamp(0, 3)],
                    max: 20,
                    enabled: !ro,
                    onChanged: (v) => setState(() => h['value'] = v),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _BoundField(
                    key: ValueKey('$_rev-hl-$i-${highlights.length}'),
                    initial: str(h['label']),
                    hint: i < hlPh.length ? hlPh[i] : '',
                    max: 40,
                    enabled: !ro,
                    onChanged: (v) => setState(() => h['label'] = v),
                  ),
                ),
                IconButton(
                  onPressed: ro ? null : () => setState(() => highlights.removeAt(i)),
                  icon: Icon(LucideIcons.trash2, size: 17, color: c.danger),
                ),
              ],
            ),
          ),
        if (highlights.length < 4)
          Align(
            alignment: Alignment.centerLeft,
            child: Btn(ctx.ws('addHighlight'), icon: LucideIcons.plus, kind: BtnKind.ghost, small: true, onTap: ro ? null : () => setState(() => highlights.add({'value': '', 'label': ''}))),
          ),
      ]),
      gap14,
      _part(ctx.ws('menu'), 'menu', [
        _text('menu', 'title', label: ctx.ws('menuTitle'), hint: ctx.ws('menuTitlePh'), max: 60),
        Text(ctx.ws('menuMode'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Segmented<String>(value: str(menu['mode']), options: [('all', ctx.ws('modeAll')), ('featured', ctx.ws('modeFeatured'))], onChanged: ro ? null : (v) => setState(() => menu['mode'] = v)),
        if (menu['mode'] == 'featured') ...[
          gap14,
          Text(ctx.ws('pickDishes', {'n': (menu['featured_ids'] as List).length}), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Muted(ctx.ws('noDishes'))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final i in items)
                  Builder(
                    builder: (_) {
                      final ids = (menu['featured_ids'] as List);
                      final picked = ids.contains(str(i['_id']));
                      return FilterChip(
                        avatar: str(i['photo']).isNotEmpty ? CircleAvatar(backgroundImage: netImage(str(i['photo']))) : null,
                        label: Text(str(i['name_en']).isNotEmpty ? str(i['name_en']) : str(i['name_km'])),
                        selected: picked,
                        onSelected: ro || (!picked && ids.length >= 24) ? null : (on) => setState(() => on ? ids.add(str(i['_id'])) : ids.remove(str(i['_id']))),
                      );
                    },
                  ),
              ],
            ),
        ],
        const SizedBox(height: 6),
        SwitchRow(title: ctx.ws('showPrices'), value: menu['show_prices'] == true, onChanged: ro ? null : (v) => setState(() => menu['show_prices'] = v)),
      ]),
      gap14,
      _part(ctx.ws('gallery'), 'gallery', [
        _text('gallery', 'title', label: ctx.ws('galleryTitle'), hint: ctx.ws('galleryTitlePh'), max: 60),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (i, img) in gallery.indexed)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image(
                      image: netImage(str(img['url'])),
                      width: 96,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(width: 96, height: 72, color: c.bg2),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: RoundBtn(LucideIcons.trash2, size: 28, fg: c.danger, onTap: ro || _busy.isNotEmpty ? null : () => _removeImage('gallery', i)),
                  ),
                ],
              ),
            if (gallery.length < 12)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: ro || _busy.isNotEmpty ? null : () => _upload('gallery', max: 12 - gallery.length),
                child: Container(
                  width: 96,
                  height: 72,
                  decoration: BoxDecoration(
                    color: c.bg2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.line),
                  ),
                  child: _busy == 'gallery'
                      ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.imagePlus, size: 20, color: c.muted),
                            Text(
                              ctx.ws('addPhotos'),
                              style: TextStyle(fontSize: 11, color: c.muted, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Muted(ctx.ws('galleryHint')),
      ]),
      gap14,
      _part(ctx.ws('formTitle'), 'form', [
        Muted(ctx.ws('formSub')),
        const SizedBox(height: 10),
        _text('form', 'title', label: ctx.ws('formHeading'), hint: ctx.st('writeUs'), max: 60),
        _text('form', 'text', label: ctx.ws('formText'), hint: ctx.st('writeUsSub'), max: 200),
        SwitchRow(
          title: ctx.ws('notifyTelegram'),
          sub: ctx.addonOn('rest_telegram') ? null : ctx.ws('notifyNeedsTelegram'),
          value: obj(f['form'])['notify_telegram'] == true,
          onChanged: ro ? null : (v) => setState(() => (f['form'] as Map)['notify_telegram'] = v),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Btn(
            '${ctx.ws('openInbox')}${n(ctx.overview['inbox_unread']) > 0 ? ' · ${fmt(ctx.overview['inbox_unread'])}' : ''}',
            icon: LucideIcons.inbox,
            kind: BtnKind.ghost,
            small: true,
            onTap: () => ctx.go('inbox'),
          ),
        ),
      ]),
      gap14,
      _part(ctx.ws('contact'), 'contact', [
        Muted(ctx.ws('contactHint')),
        const SizedBox(height: 10),
        _text('contact', 'title', label: ctx.ws('contactTitle'), hint: ctx.ws('contactTitlePh'), max: 60),
        _text('contact', 'phone', label: ctx.ws('phone'), hint: str(s['phone']), max: 30, keyboard: TextInputType.phone),
        _text('contact', 'email', label: ctx.ws('email'), max: 80, keyboard: TextInputType.emailAddress),
        _text('contact', 'hours', label: ctx.ws('hours'), hint: str(s['hours']).isNotEmpty ? str(s['hours']) : ctx.ws('hoursPh'), max: 120),
        _text('contact', 'address', label: ctx.ws('address2'), hint: str(s['address']), max: 200),
        _text('contact', 'map_url', label: ctx.ws('map'), hint: str(s['map_url']).isNotEmpty ? str(s['map_url']) : 'https://maps.app.goo.gl/…', max: 300, keyboard: TextInputType.url),
        for (final k in ['facebook', 'instagram', 'tiktok', 'telegram'])
          _text('contact', k, label: '${k[0].toUpperCase()}${k.substring(1)}', hint: k == 'telegram' ? 't.me/yourname' : '$k.com/yourpage', max: 300, keyboard: TextInputType.url),
        _text('footer_note', null, label: ctx.ws('footerNote'), max: 200),
      ]),
      gap14,
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(ctx.ws('seo'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _text('seo', 'title', label: ctx.ws('seoTitle'), hint: str(s['name_en']).isNotEmpty ? str(s['name_en']) : str(s['name_km']), max: 70),
            _text('seo', 'description', label: ctx.ws('seoDesc'), hint: ctx.ws('seoDescPh'), max: 160, lines: 2),
          ],
        ),
      ),
    ];
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: list),
          ),
        ),
        RestSaveBar(
          ctx: ctx,
          dirty: _dirty,
          saving: _saving,
          disabled: ro || _slugState == 'taken' || _slugState == 'format' || _slugState == 'checking',
          onSave: _save,
          onUndo: () => setState(() {
            _form = _formOf(_site);
            _rev++;
            _checkSlug();
          }),
        ),
      ],
    );
  }

  String _navLabel(String k) => switch (k) {
    'home' => ctx.st('home'),
    'menu' => ctx.st('menu'),
    'about' => ctx.st('about'),
    'gallery' => ctx.st('gallery'),
    'message' => ctx.st('writeUsNav'),
    _ => ctx.st('contact'),
  };
}

// a text box that keeps its own controller (the form map holds the value)
class _BoundField extends StatefulWidget {
  final String initial;
  final String? label, hint;
  final int max, lines;
  final bool enabled;
  final TextInputType? keyboard;
  final Widget? prefix;
  final String Function(String)? format;
  final ValueChanged<String> onChanged;
  const _BoundField({super.key, required this.initial, this.label, this.hint, this.max = 80, this.lines = 1, this.enabled = true, this.keyboard, this.prefix, this.format, required this.onChanged});
  @override
  State<_BoundField> createState() => _BoundFieldState();
}

class _BoundFieldState extends State<_BoundField> {
  late final _c = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Field(
    label: widget.label,
    hint: widget.hint,
    controller: _c,
    maxLength: widget.max,
    maxLines: widget.lines,
    keyboard: widget.keyboard,
    enabled: widget.enabled,
    prefix: widget.prefix,
    onChanged: (v) {
      if (widget.format != null) {
        final f = widget.format!(v);
        if (f != v) {
          _c.value = TextEditingValue(
            text: f,
            selection: TextSelection.collapsed(offset: f.length),
          );
        }
        widget.onChanged(f);
      } else {
        widget.onChanged(v);
      }
    },
  );
}

class _ThemeArt extends StatelessWidget {
  final Color bg, fg, accent;
  final bool big;
  const _ThemeArt({required this.bg, required this.fg, required this.accent, this.big = false});
  @override
  Widget build(BuildContext context) => Container(
    width: big ? 160 : double.infinity,
    height: big ? 110 : 56,
    padding: EdgeInsets.all(big ? 14 : 8),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.black12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: big ? 50 : 26, height: 3, color: fg),
        const Spacer(),
        Text(
          'Aa',
          style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: big ? 30 : 17, height: 1),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final (i, col) in [accent, fg.withValues(alpha: .25), fg.withValues(alpha: .25)].indexed) ...[
              if (i > 0) const SizedBox(width: 3),
              Container(
                width: big ? 12 : 8,
                height: big ? 12 : 8,
                decoration: BoxDecoration(color: col, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}
