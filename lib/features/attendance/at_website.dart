import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/buy_sheet.dart';
import '../../widgets/look_sheet.dart';
import '../../widgets/color_pick.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show mGap, mDate, fileForm;
import '../restaurant/rest_common.dart' show Segmented, SwitchRow;
import 'at_addons.dart';
import 'at_common.dart';
import 'at_web_looks.dart';

// Company website (att_website) — WebsiteTab.jsx: address, look, top, menu, pages, services, about, gallery, form, contact, SEO + inbox.
//   GET /site → { data: site, themes{owned,price}, suggested_slug, unread, preview }

const _parts = ['home', 'about', 'services', 'gallery', 'message', 'contact'];
const _socials = ['facebook', 'instagram', 'tiktok', 'telegram', 'linkedin', 'youtube'];
const _contactKeys = ['title', 'phone', 'email', 'address', 'hours', 'map_url', ..._socials];
const _colors = ['#4F46E5', '#1E3A8A', '#2563EB', '#0891B2', '#0F766E', '#16A34A', '#CA8A04', '#EA580C', '#DC2626', '#DB2777', '#7C3AED', '#111827'];
const serviceIcons = <String, IconData>{
  'briefcase': LucideIcons.briefcase,
  'users': LucideIcons.users,
  'truck': LucideIcons.truck,
  'wrench': LucideIcons.wrench,
  'code': LucideIcons.codeXml,
  'chart': LucideIcons.chartColumn,
  'shield': LucideIcons.shieldCheck,
  'heart': LucideIcons.heart,
  'home': LucideIcons.house,
  'leaf': LucideIcons.leaf,
  'camera': LucideIcons.camera,
  'megaphone': LucideIcons.megaphone,
  'graduation': LucideIcons.graduationCap,
  'scale': LucideIcons.scale,
  'stethoscope': LucideIcons.stethoscope,
  'car': LucideIcons.car,
  'plane': LucideIcons.plane,
  'shopping': LucideIcons.shoppingBag,
  'palette': LucideIcons.palette,
  'coffee': LucideIcons.coffee,
  'hammer': LucideIcons.hammer,
  'zap': LucideIcons.zap,
  'globe': LucideIcons.globe,
  'star': LucideIcons.star,
};

String _newId() {
  final r = Random.secure();
  return List.generate(12, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

String _slugify(String s) {
  var v = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]+'), '-').replaceAll(RegExp(r'-{2,}'), '-').replaceAll(RegExp(r'^-+'), '');
  return v.length > 40 ? v.substring(0, 40) : v;
}

// the parts the form edits (photos are saved straight away, not here)
Json _formOf(Json s) {
  Json o(String k) => obj(s[k]);
  final hero = o('hero'), about = o('about'), svc = o('services'), gal = o('gallery'), form = o('form'), con = o('contact'), seo = o('seo');
  return {
    'slug': str(s['slug']),
    'published': s['published'] == true,
    'theme': str(s['theme']).isEmpty ? 'classic' : str(s['theme']),
    'color': str(s['color']),
    'hero': {
      for (final k in ['kicker', 'title', 'subtitle', 'button', 'button_to']) k: str(hero[k]),
    },
    'about': {
      'enabled': about['enabled'] != false,
      'title': str(about['title']),
      'text': str(about['text']),
      'highlights': [
        for (final h in objs(about['highlights'])) {'value': str(h['value']), 'label': str(h['label'])},
      ],
    },
    'services': {
      'enabled': svc['enabled'] != false,
      'title': str(svc['title']),
      'subtitle': str(svc['subtitle']),
      'items': [
        for (final x in objs(svc['items']))
          {
            '_id': str(x['_id']),
            'icon': str(x['icon']).isEmpty ? 'briefcase' : str(x['icon']),
            'title': str(x['title']),
            'text': str(x['text']),
            'price': str(x['price']),
            'page_id': str(x['page_id']),
          },
      ],
    },
    'gallery': {'enabled': gal['enabled'] != false, 'title': str(gal['title'])},
    'pages': [
      for (final p in objs(s['pages']))
        {
          for (final k in ['_id', 'slug', 'title', 'subtitle', 'body', 'button', 'button_to']) k: str(p[k]),
        },
    ],
    'nav': [
      for (final x in objs(s['nav'])) {'kind': str(x['kind']), 'key': str(x['key']), 'label': str(x['label']), 'url': str(x['url']), 'show': x['show'] != false},
    ],
    'form': {'enabled': form['enabled'] != false, 'title': str(form['title']), 'text': str(form['text']), 'notify_telegram': form['notify_telegram'] != false},
    'contact': {'enabled': con['enabled'] != false, for (final k in _contactKeys) k: str(con[k])},
    'footer_note': str(s['footer_note']),
    'seo': {'title': str(seo['title']), 'description': str(seo['description'])},
  };
}

// a little drawing of a look: its colours, menu and hero layout
class WebLookArt extends StatelessWidget {
  final String look;
  final String color;
  final double width;
  const WebLookArt({super.key, required this.look, this.color = '', this.width = 150});
  @override
  Widget build(BuildContext context) {
    final d = webLooks[look] ?? webLooks['classic']!;
    final ac = color.isEmpty ? d.accent : atHex(color, d.accent);
    final ac2 = d.accent2 ?? ac;
    final r = min(d.r, 10.0) / 2;
    final dark = d.bg.computeLuminance() < .3;
    Widget line(double w, {Color? col, double h = 3}) => Container(
      width: w,
      height: h,
      margin: const EdgeInsets.only(top: 3),
      decoration: BoxDecoration(color: col ?? d.fg.withValues(alpha: .35), borderRadius: BorderRadius.circular(2)),
    );
    final barDark = d.nav == 'dark';
    final nav = Container(
      height: 14,
      margin: d.nav == 'pill' ? const EdgeInsets.fromLTRB(10, 4, 10, 0) : EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: barDark
            ? d.fg
            : d.nav == 'pill'
            ? d.card
            : (d.nav == 'ghost' ? Colors.transparent : d.bg),
        borderRadius: d.nav == 'pill' ? BorderRadius.circular(8) : null,
        border: d.nav == 'bar' ? Border(bottom: BorderSide(color: d.fg.withValues(alpha: .08))) : null,
      ),
      child: Row(
        mainAxisAlignment: d.nav == 'center' ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: ac, shape: BoxShape.circle),
          ),
          if (d.nav != 'center') const Spacer() else const SizedBox(width: 6),
          for (var i = 0; i < 3; i++) Container(width: 9, height: 2, margin: const EdgeInsets.only(left: 3), color: (barDark ? d.bg : d.fg).withValues(alpha: .5)),
        ],
      ),
    );
    final title = Text(
      'Aa',
      style: TextStyle(color: d.fg, fontWeight: FontWeight.w900, fontSize: 15, fontFamily: d.serif ? 'serif' : null, height: 1),
    );
    final btn = Container(
      width: 22,
      height: 7,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(color: ac, borderRadius: BorderRadius.circular(r)),
    );
    final img = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [ac.withValues(alpha: .85), ac2.withValues(alpha: .55)]),
        borderRadius: BorderRadius.circular(r),
      ),
    );
    final textCol = Column(
      crossAxisAlignment: d.hero == 'center' || d.hero == 'minimal' ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [title, line(44), line(30), btn],
    );
    final Widget hero = switch (d.hero) {
      'center' || 'minimal' => Stack(
        alignment: Alignment.center,
        children: [
          if (d.glow) Positioned(top: 0, child: CircleAvatar(radius: 26, backgroundColor: ac.withValues(alpha: .25))),
          textCol,
        ],
      ),
      'full' => Stack(
        children: [
          Positioned.fill(child: img),
          Padding(
            padding: const EdgeInsets.all(8),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Aa',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, height: 1),
                  ),
                  line(44, col: Colors.white70),
                  btn,
                ],
              ),
            ),
          ),
        ],
      ),
      'card' || 'frame' => Padding(
        padding: const EdgeInsets.all(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: d.card,
            borderRadius: BorderRadius.circular(r),
            border: d.hero == 'frame' ? Border.all(color: ac, width: 1.5) : null,
          ),
          child: Row(
            children: [
              Expanded(child: textCol),
              SizedBox(width: 34, height: 34, child: img),
            ],
          ),
        ),
      ),
      'slant' => Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 60,
            child: Transform(transform: Matrix4.skewX(-.2), child: img),
          ),
          Padding(padding: const EdgeInsets.all(8), child: textCol),
        ],
      ),
      'left' => Padding(padding: const EdgeInsets.all(8), child: textCol),
      _ => Padding(
        // split
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(child: textCol),
            const SizedBox(width: 6),
            Expanded(child: img),
          ],
        ),
      ),
    };
    return SizedBox(
      width: width,
      height: width * .66,
      child: FittedBox(
        child: Container(
          width: 150,
          height: 99,
          color: d.bg,
          child: Column(
            children: [
              nav,
              Expanded(child: hero),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                child: Row(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Expanded(
                        child: Container(
                          height: 16,
                          margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
                          decoration: BoxDecoration(
                            color: dark ? d.card : d.card,
                            borderRadius: BorderRadius.circular(r),
                            border: Border.all(color: d.fg.withValues(alpha: .06)),
                          ),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Container(width: 6, height: 6, margin: const EdgeInsets.all(3), color: ac.withValues(alpha: .8)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WebsiteTab extends StatefulWidget {
  final AtCtx ctx;
  const WebsiteTab({super.key, required this.ctx});
  @override
  State<WebsiteTab> createState() => _WebsiteTabState();
}

class _WebsiteTabState extends State<WebsiteTab> {
  AtCtx get ctx => widget.ctx;
  Json? _res, _f;
  String _saved = '', _busy = '', _view = 'edit', _slugState = '';
  String? _openPage, _openSvc;
  Timer? _slugWait;
  final Map<String, TextEditingController> _ctl = {};
  String w(String k, [Map<String, Object?> v = const {}]) => ctx.t('atwb.$k', v);
  String st(String k) => ctx.t.or('webt.$k', k);
  bool get _on => ctx.addonOn('att_website');

  @override
  void initState() {
    super.initState();
    if (_on) _load();
  }

  @override
  void dispose() {
    _slugWait?.cancel();
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/site');
      if (!mounted) return;
      setState(() {
        _res = r;
        _reset(obj(r['data']), str(r['suggested_slug']));
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  void _reset(Json site, [String suggested = '']) {
    final f = _formOf(site);
    _saved = jsonEncode(f);
    if (str(f['slug']).isEmpty) f['slug'] = suggested;
    _f = f;
    _drop('');
    _slugState = str(f['slug']).isNotEmpty && f['slug'] == site['slug'] ? 'ok' : '';
  }

  void _drop(String prefix) {
    _ctl.removeWhere((k, c) {
      if (!k.startsWith(prefix)) return false;
      c.dispose();
      return true;
    });
  }

  Json get _site => obj(_res!['data']);
  Json get _themes => obj(_res!['themes']);
  bool _owns(String k) => k == 'classic' || (_themes['owned'] as List? ?? const []).contains(k);
  List<Json> get _pages => (_f!['pages'] as List).cast<Json>();
  List<Json> get _nav => (_f!['nav'] as List).cast<Json>();
  Json get _svc => _f!['services'] as Json;
  List<Json> get _svcItems => (_svc['items'] as List).cast<Json>();
  Json? _savedPage(String id) => objs(_site['pages']).where((p) => str(p['_id']) == id).firstOrNull;
  Json? _savedSvc(String id) => objs(obj(_site['services'])['items']).where((x) => str(x['_id']) == id).firstOrNull;

  // a text box bound to a map key; key = a stable id for the controller
  Widget _in(String key, Json map, String field, String label, {int max = 100, String hint = '', int lines = 1, TextInputType? kb}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Field(
      label: label,
      controller: _ctl.putIfAbsent(key, () => TextEditingController(text: str(map[field]))),
      hint: hint,
      maxLength: max,
      maxLines: lines,
      keyboard: kb,
      enabled: !ctx.readOnly,
      onChanged: (v) => setState(() => map[field] = v),
    ),
  );

  void _slug(String v) {
    final s = _slugify(v);
    final c = _ctl['slug']!;
    if (s != v) {
      c.value = TextEditingValue(
        text: s,
        selection: TextSelection.collapsed(offset: s.length),
      );
    }
    setState(() => _f!['slug'] = s);
    _slugWait?.cancel();
    if (s.isEmpty) return setState(() => _slugState = '');
    if (s == _site['slug']) return setState(() => _slugState = 'ok');
    if (!RegExp(r'^[a-z0-9](?:[a-z0-9-]{1,38})[a-z0-9]$').hasMatch(s) || s.contains('--')) return setState(() => _slugState = 'format');
    setState(() => _slugState = 'checking');
    _slugWait = Timer(const Duration(milliseconds: 400), () async {
      try {
        final r = await ctx.api.get('${ctx.base}/site/slug', {'value': s});
        final d = obj(r['data']);
        if (mounted) {
          setState(
            () => _slugState = d['available'] == true
                ? 'ok'
                : d['reason'] == 'taken'
                ? 'taken'
                : 'format',
          );
        }
      } catch (_) {
        if (mounted) setState(() => _slugState = '');
      }
    });
  }

  Future<void> _save() async {
    final theme = str(_f!['theme']);
    if (!_owns(theme)) return _buyLook(theme);
    setState(() => _busy = 'save');
    try {
      final body = jsonDecode(jsonEncode(_f)) as Json;
      body['nav'] = [
        for (final x in body['nav'] as List)
          if ((x as Json)['kind'] != 'link' || (str(x['label']).isNotEmpty && str(x['url']).isNotEmpty)) x,
      ];
      final r = await ctx.api.put('${ctx.base}/site', body);
      if (mounted) {
        setState(() {
          _res = {..._res!, 'data': r['data']};
          _reset(obj(r['data']));
        });
      }
      ctx.notify(w('r.saved'));
    } on ApiError catch (e) {
      if (e.status == 402 && e.body['product'] == 'att_web_theme') {
        _buyLook(str(e.body['item']).isEmpty ? theme : str(e.body['item']));
      } else if (e.status == 402 && e.body['product'] != null) {
        ctx.askBuy(str(e.body['product']));
      } else {
        ctx.fail(e);
      }
    }
    if (mounted) setState(() => _busy = '');
  }

  Future<void> _upload(String slot, {String? rid}) async {
    final b = await atPickPicture(context, ctx, maxSize: slot == 'hero' || slot == 'page' ? 1920 : 1600);
    if (b == null) return;
    setState(() => _busy = '$slot${rid ?? ''}');
    final form = fileForm('file', b, '$slot.jpg')..fields.addAll([MapEntry('slot', slot), if (rid != null) MapEntry('id', rid)]);
    final r = await ctx.run(() => ctx.api.post('${ctx.base}/site/image', form));
    if (r != null && mounted) setState(() => _res = {..._res!, 'data': r['data']});
    if (mounted) setState(() => _busy = '');
  }

  Future<void> _removeImage(String slot, {String? rid, int? index}) async {
    setState(() => _busy = '$slot${rid ?? ''}');
    final r = await ctx.run(() => ctx.api.delete('${ctx.base}/site/image', {'slot': slot, 'id': ?rid, 'index': ?index}));
    if (r != null && mounted) setState(() => _res = {..._res!, 'data': r['data']});
    if (mounted) setState(() => _busy = '');
  }

  Future<void> _buyLook(String k) async {
    final look = webLooks[k] ?? webLooks['classic']!;
    final name = look.nameOf(ctx.lang);
    final price = n(_themes['price']);
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BuySheet(
        stage: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: WebLookArt(look: k, width: 220),
        ),
        badge: w('look'),
        title: w('lookBuyTitle', {'name': name}),
        sub: w('lookBuySub'),
        perks: [look.descOf(ctx.lang), w('lookPerk'), w('oneTime')],
        price: price,
        buyLabel: w('buy', {'coins': fmt(price)}),
        doneTitle: name,
        doneSub: w('lookDone', {'name': name}),
        doneButton: ctx.t('app.continue'),
        buy: () => ctx.api.post('${ctx.base}/site/themes/$k'),
        onDone: (r) {
          setState(() {
            if (r['themes'] is Map) _res = {..._res!, 'themes': r['themes']};
            _f!['theme'] = k;
          });
          ctx.reload();
        },
      ),
    );
  }

  // where a button goes: '' auto · '#part' · 'page:id' · a web address
  List<(String, String)> get _targets => [
    for (final p in _parts.where((p) => p != 'contact')) ('#$p', w('partNames.$p')),
    ('#contact', w('partNames.contact')),
    for (final p in _pages) ('page:${p['_id']}', '${w('kindPage')}: ${str(p['title']).isEmpty ? '…' : p['title']}'),
  ];

  Widget _target(String key, Json map, String field) {
    final v = str(map[field]);
    final isUrl = v.isNotEmpty && !v.startsWith('#') && !v.startsWith('page:');
    final custom = isUrl || _ctl.containsKey('$key.url');
    final targets = _targets;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(w('goesTo'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: custom ? 'url' : (targets.any((t) => t.$1 == v) ? v : ''),
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              DropdownMenuItem(value: '', child: Text(w('auto'))),
              for (final (tv, label) in targets)
                DropdownMenuItem(
                  value: tv,
                  child: Text(label, overflow: TextOverflow.ellipsis),
                ),
              DropdownMenuItem(value: 'url', child: Text(w('toUrl'))),
            ],
            onChanged: ctx.readOnly
                ? null
                : (x) => setState(() {
                    if (x == 'url') {
                      map[field] = '';
                      _ctl.putIfAbsent('$key.url', TextEditingController.new);
                    } else {
                      _drop('$key.url');
                      map[field] = x ?? '';
                    }
                  }),
          ),
          if (custom) ...[
            const SizedBox(height: 8),
            Field(
              controller: _ctl.putIfAbsent('$key.url', () => TextEditingController(text: isUrl ? v : '')),
              hint: 'https://',
              maxLength: 300,
              keyboard: TextInputType.url,
              onChanged: (x) => setState(() => map[field] = x),
            ),
          ],
        ],
      ),
    );
  }

  Widget _photo(String label, String url, String slot, {String? rid, bool wide = false, String? hint}) {
    final c = context.c;
    final busy = _busy == '$slot${rid ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (hint != null && hint.isNotEmpty) Muted(hint),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: wide ? 120 : 72,
                height: 68,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: c.bg2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.line),
                ),
                child: url.isNotEmpty ? Image(image: netImage(url), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.imagePlus, color: c.muted),
              ),
              const SizedBox(width: 10),
              Btn(
                busy
                    ? w('r.uploading')
                    : url.isNotEmpty
                    ? w('r.change')
                    : w('r.upload'),
                icon: LucideIcons.imagePlus,
                kind: BtnKind.ghost,
                small: true,
                busy: busy,
                onTap: busy || ctx.readOnly ? null : () => _upload(slot, rid: rid),
              ),
              if (url.isNotEmpty && !busy)
                IconButton(
                  onPressed: ctx.readOnly ? null : () => _removeImage(slot, rid: rid),
                  icon: Icon(LucideIcons.trash2, size: 18, color: c.danger),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // a part with an on/off switch in its header (folds open)
  Widget _part(String title, IconData icon, List<Widget> children, {Json? toggle}) {
    final c = context.c;
    final off = toggle != null && toggle['enabled'] == false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(icon, size: 19, color: off ? c.muted : c.brand),
            title: Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w800, color: off ? c.muted : c.ink),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (toggle != null) SwitchRow(title: w('show'), value: !off, onChanged: ctx.readOnly ? null : (v) => setState(() => toggle['enabled'] = v)),
              if (!off) ...children,
            ],
          ),
        ),
      ),
    );
  }

  // tap a look → the look sheet: big page, swipe for the others, Use (then Save) / Buy at the bottom
  Future<void> _openLook(String k, {required bool pick}) async {
    final keys = webLooks.keys.toList();
    final price = fmt(n(_res == null ? ctx.addon('att_web_theme')['price'] ?? 35 : _themes['price']));
    await showLookSheet(
      context,
      title: w('look'),
      count: keys.length,
      initial: keys.contains(k) ? keys.indexOf(k) : 0,
      item: (context, i, refresh) {
        final x = keys[i];
        final lk = webLooks[x]!;
        final f = _f;
        final on = f != null && f['theme'] == x;
        final mine = _res == null ? x == 'classic' : _owns(x);
        return LookItem(
          name: lk.nameOf(ctx.lang),
          sub: lk.descOf(ctx.lang),
          badge: on ? w('inUse') : (x == 'classic' ? w('free') : (mine ? w('owned') : w('unlockLook', {'coins': price}))),
          badgeTone: on || mine ? Tone.good : Tone.warn,
          preview: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: WebLookArt(look: x, color: str(f?['color']), width: 320),
          ),
          acts: [
            if (pick && mine && !on)
              LookAct(
                ctx.t('atlk.use'),
                icon: LucideIcons.check,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        setState(() => _f!['theme'] = x);
                        return true;
                      },
              ),
            if (!mine && _res != null)
              LookAct(
                w('unlockLook', {'coins': price}),
                gold: true,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        Future.microtask(() => _buyLook(x));
                        return true;
                      },
              ),
          ],
        );
      },
    );
  }

  Widget _looksGrid({required bool pick}) {
    final c = context.c;
    final f = _f;
    return LayoutBuilder(
      builder: (_, box) {
        final cols = box.maxWidth > 520 ? 3 : 2;
        final cw = (box.maxWidth - 10 * (cols - 1)) / cols;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final k in webLooks.keys)
              () {
                final lk = webLooks[k]!;
                final on = f != null && f['theme'] == k;
                final mine = _res == null ? k == 'classic' : _owns(k);
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _openLook(k, pick: pick),
                  child: Container(
                    width: cw,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: on ? c.brand : c.line, width: on ? 2 : 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        WebLookArt(look: k, color: on ? str(f['color']) : '', width: cw),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lk.nameOf(ctx.lang),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              if (on)
                                AtTag(w('inUse'), tone: 'ok', icon: LucideIcons.check)
                              else if (k == 'classic')
                                AtTag(w('free'), tone: 'ok')
                              else if (mine)
                                AtTag(w('owned'), tone: 'ok', icon: LucideIcons.check)
                              else
                                AtTag(fmt(n(_res == null ? ctx.addon('att_web_theme')['price'] ?? 35 : _themes['price'])), icon: LucideIcons.lock),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }(),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (!_on) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AtLocked(ctx: ctx, addon: 'att_website'),
          mGap,
          atPanel([
            Text(w('look'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Muted(w('lookSub', {'coins': fmt(n(ctx.addon('att_web_theme')['price'] ?? 35))})),
            const SizedBox(height: 12),
            _looksGrid(pick: false),
          ]),
        ],
      );
    }
    final res = _res, f = _f;
    if (res == null || f == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 5));
    final unread = n(res['unread']).toInt();
    final dirty = jsonEncode(f) != _saved;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Segmented<String>(value: _view, options: [('edit', w('edit')), ('inbox', '${w('inbox')}${unread > 0 ? ' ($unread)' : ''}')], onChanged: (v) => setState(() => _view = v)),
              mGap,
              if (_view == 'inbox') _Inbox(ctx: ctx, onUnread: (v) => setState(() => _res = {..._res!, 'unread': v})) else ..._editor(context),
            ],
          ),
        ),
        if (_view == 'edit')
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
                      dirty ? w('r.unsaved') : w('r.allSaved'),
                      style: TextStyle(color: dirty ? c.warn : c.muted, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  if (dirty) ...[
                    Btn(
                      w('r.cancel'),
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: _busy.isNotEmpty
                          ? null
                          : () => setState(() {
                              _f = jsonDecode(_saved) as Json;
                              _drop('');
                            }),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Btn(
                    _busy == 'save' ? w('r.saving') : w('r.save'),
                    icon: LucideIcons.save,
                    small: true,
                    busy: _busy == 'save',
                    onTap: ctx.readOnly || _busy.isNotEmpty || !dirty || ['taken', 'format', 'checking'].contains(_slugState) ? null : _save,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _editor(BuildContext context) {
    final c = context.c;
    final f = _f!, site = _site;
    final biz = ctx.business;
    final liveUrl = str(site['slug']).isNotEmpty ? '${Config.siteUrl}/w/${site['slug']}' : '';
    final hero = f['hero'] as Json, about = f['about'] as Json, gal = f['gallery'] as Json, form = f['form'] as Json, con = f['contact'] as Json, seo = f['seo'] as Json;
    final highs = (about['highlights'] as List).cast<Json>();
    final images = objs(obj(site['gallery'])['images']);
    final hlPh = ctx.t.list('atwb.hlLabelPh');
    String navName(Json x) => x['kind'] == 'part'
        ? w('partNames.${x['key']}')
        : x['kind'] == 'page'
        ? str(_pages.where((p) => p['_id'] == x['key']).firstOrNull?['title']).ifBlank('…')
        : '';
    String navPh(Json x) => x['kind'] == 'part'
        ? st(switch (str(x['key'])) {
            'message' => 'message',
            final k => k,
          })
        : navName(x);
    void moveNav(int i, int d) => setState(() {
      final l = _nav;
      final t = l[i];
      l[i] = l[i + d];
      l[i + d] = t;
      _drop('nav.');
    });
    void movePage(int i, int d) => setState(() {
      final l = _pages;
      final t = l[i];
      l[i] = l[i + d];
      l[i + d] = t;
    });
    void moveSvc(int i, int d) => setState(() {
      final l = _svcItems;
      final t = l[i];
      l[i] = l[i + d];
      l[i + d] = t;
    });
    Widget arrows(int i, int len, void Function(int, int) move) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(visualDensity: VisualDensity.compact, onPressed: ctx.readOnly || i == 0 ? null : () => move(i, -1), icon: const Icon(LucideIcons.arrowUp, size: 16)),
        IconButton(visualDensity: VisualDensity.compact, onPressed: ctx.readOnly || i == len - 1 ? null : () => move(i, 1), icon: const Icon(LucideIcons.arrowDown, size: 16)),
      ],
    );

    return [
      // address + online
      atPanel([
        Text(w('address'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        const SizedBox(height: 8),
        Field(
          controller: _ctl.putIfAbsent('slug', () => TextEditingController(text: str(f['slug']))),
          hint: 'my-company',
          maxLength: 40,
          enabled: !ctx.readOnly,
          prefix: Padding(
            padding: const EdgeInsets.only(left: 14, right: 2),
            child: Center(
              widthFactor: 1,
              child: Text(
                '/w/',
                style: TextStyle(color: c.muted, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          onChanged: _slug,
        ),
        const SizedBox(height: 6),
        Text(
          switch (_slugState) {
            'checking' => w('checking'),
            'ok' => '✓ ${w('available')}',
            'taken' => w('taken'),
            'format' => w('badFormat'),
            _ => w('addressHint'),
          },
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: switch (_slugState) {
              'ok' => c.good,
              'taken' || 'format' => c.danger,
              _ => c.muted,
            },
          ),
        ),
        const SizedBox(height: 6),
        SwitchRow(title: w('published'), sub: w('publishedHint'), value: f['published'] == true, onChanged: ctx.readOnly ? null : (v) => setState(() => f['published'] = v)),
        const SizedBox(height: 4),
        if (site['published'] == true && liveUrl.isNotEmpty) ...[
          Text(
            liveUrl,
            style: TextStyle(color: c.brand, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Btn(
                w('open'),
                icon: LucideIcons.externalLink,
                small: true,
                onTap: () => launchUrl(Uri.parse(liveUrl), mode: LaunchMode.externalApplication),
              ),
              Btn(
                w('copy'),
                icon: LucideIcons.copy,
                kind: BtnKind.ghost,
                small: true,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: liveUrl));
                  ctx.notify(w('copied'));
                },
              ),
            ],
          ),
        ] else
          Align(
            alignment: Alignment.centerLeft,
            child: Chip2(w('notOnline'), icon: LucideIcons.globe),
          ),
      ]),
      mGap,
      // look
      _part(w('look'), LucideIcons.palette, [
        Muted(w('lookSub', {'coins': fmt(n(_themes['price']))})),
        const SizedBox(height: 10),
        _looksGrid(pick: true),
        const SizedBox(height: 14),
        Text(w('color'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            InkWell(
              onTap: ctx.readOnly ? null : () => setState(() => f['color'] = ''),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: (webLooks[f['theme']] ?? webLooks['classic']!).accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: str(f['color']).isEmpty ? c.ink : Colors.transparent, width: 3),
                ),
                child: str(f['color']).isEmpty ? const Icon(LucideIcons.check, size: 15, color: Colors.white) : null,
              ),
            ),
            const SizedBox(width: 10),
            Muted(w('colorTheme')),
          ],
        ),
        const SizedBox(height: 10),
        ColorRow(
          value: str(f['color']),
          colors: _colors,
          customLabel: w('custom'),
          saveLabel: w('r.save'),
          cancelLabel: w('r.cancel'),
          onChanged: ctx.readOnly ? null : (v) => setState(() => f['color'] = v),
        ),
      ]),
      // top
      _part(w('top'), LucideIcons.image, [
        _in('hero.kicker', hero, 'kicker', w('kicker'), max: 60, hint: str(biz['name'])),
        _in('hero.title', hero, 'title', w('heroTitle'), max: 90, hint: str(biz['name'])),
        _in('hero.subtitle', hero, 'subtitle', w('heroSub'), max: 240, lines: 2),
        _in('hero.button', hero, 'button', w('heroButton'), max: 30, hint: w('heroButtonPh')),
        _target('hero.to', hero, 'button_to'),
        _photo(w('heroImage'), str(obj(obj(site['hero'])['image'])['url']), 'hero', wide: true, hint: w('heroImageHint')),
      ]),
      // menu
      _part(w('menu'), LucideIcons.menu, [
        Muted(w('menuSub')),
        const SizedBox(height: 8),
        for (final (i, x) in _nav.indexed)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
            child: Opacity(
              opacity: x['show'] == true ? 1 : .55,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Switch(value: x['show'] == true, onChanged: ctx.readOnly ? null : (v) => setState(() => x['show'] = v)),
                      const SizedBox(width: 4),
                      AtTag(
                        x['kind'] == 'part'
                            ? w('kindPart')
                            : x['kind'] == 'page'
                            ? w('kindPage')
                            : w('kindLink'),
                        tone: x['kind'] == 'link' ? 'blue' : '',
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          navName(x),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      arrows(i, _nav.length, moveNav),
                      if (x['kind'] == 'link')
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: ctx.readOnly
                              ? null
                              : () => setState(() {
                                  _nav.removeAt(i);
                                  _drop('nav.');
                                }),
                          icon: Icon(LucideIcons.trash2, size: 16, color: c.danger),
                        ),
                    ],
                  ),
                  if (x['kind'] == 'link') ...[
                    Field(
                      controller: _ctl.putIfAbsent('nav.$i.label', () => TextEditingController(text: str(x['label']))),
                      hint: w('linkLabel'),
                      maxLength: 30,
                      onChanged: (v) => setState(() => x['label'] = v),
                    ),
                    const SizedBox(height: 6),
                    Field(
                      controller: _ctl.putIfAbsent('nav.$i.url', () => TextEditingController(text: str(x['url']))),
                      hint: 'https://',
                      maxLength: 300,
                      keyboard: TextInputType.url,
                      onChanged: (v) => setState(() => x['url'] = v),
                    ),
                  ] else if (x['show'] == true)
                    Field(
                      controller: _ctl.putIfAbsent('nav.$i.label', () => TextEditingController(text: str(x['label']))),
                      hint: navPh(x),
                      maxLength: 30,
                      onChanged: (v) => setState(() => x['label'] = v),
                    ),
                ],
              ),
            ),
          ),
        Muted(w('emptyHidden')),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Btn(
            w('addLink'),
            icon: LucideIcons.plus,
            kind: BtnKind.ghost,
            small: true,
            onTap: ctx.readOnly || _nav.length >= 24 ? null : () => setState(() => _nav.add({'kind': 'link', 'key': '', 'label': '', 'url': '', 'show': true})),
          ),
        ),
      ]),
      // pages
      _part(w('pages'), LucideIcons.fileText, [
        Muted(w('pagesSub')),
        const SizedBox(height: 8),
        if (_pages.isEmpty) Muted(w('noPages')),
        for (final (i, p) in _pages.indexed)
          () {
            final id = str(p['_id']);
            final open = _openPage == id;
            final stored = _savedPage(id);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: c.bg2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: open ? c.brand : Colors.transparent),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: () => setState(() => _openPage = open ? null : id),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                      child: Row(
                        children: [
                          Icon(LucideIcons.fileText, size: 16, color: c.brand),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(str(p['title']).ifBlank('…'), style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text('/w/${str(f['slug']).ifBlank('…')}/${str(p['slug']).ifBlank(_slugify(str(p['title'])))}', style: TextStyle(color: c.muted, fontSize: 11.5)),
                              ],
                            ),
                          ),
                          arrows(i, _pages.length, movePage),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: ctx.readOnly
                                ? null
                                : () => setState(() {
                                    String clear(Object? to) => to == 'page:$id' ? '' : str(to);
                                    _pages.removeAt(i);
                                    for (final q in _pages) {
                                      q['button_to'] = clear(q['button_to']);
                                    }
                                    _nav.removeWhere((x) => x['kind'] == 'page' && x['key'] == id);
                                    hero['button_to'] = clear(hero['button_to']);
                                    for (final x in _svcItems) {
                                      if (x['page_id'] == id) x['page_id'] = '';
                                    }
                                    _drop('nav.');
                                    _drop('page.$id');
                                  }),
                            icon: Icon(LucideIcons.trash2, size: 16, color: c.danger),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (open)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _in('page.$id.title', p, 'title', w('pageTitle'), max: 70),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Field(
                              label: w('pageAddress'),
                              controller: _ctl.putIfAbsent('page.$id.slug', () => TextEditingController(text: str(p['slug']))),
                              hint: _slugify(str(p['title'])),
                              maxLength: 40,
                              onChanged: (v) {
                                final s = _slugify(v);
                                if (s != v) {
                                  _ctl['page.$id.slug']!.value = TextEditingValue(
                                    text: s,
                                    selection: TextSelection.collapsed(offset: s.length),
                                  );
                                }
                                setState(() => p['slug'] = s);
                              },
                            ),
                          ),
                          _in('page.$id.subtitle', p, 'subtitle', w('pageSub'), max: 200),
                          _in('page.$id.body', p, 'body', w('pageBody'), max: 6000, lines: 8),
                          Padding(padding: const EdgeInsets.only(bottom: 12), child: Muted(w('pageBodyHint'))),
                          _in('page.$id.button', p, 'button', w('pageButton'), max: 30, hint: st('getInTouch')),
                          _target('page.$id.to', p, 'button_to'),
                          if (stored != null)
                            _photo(w('pageImage'), str(obj(stored['image'])['url']), 'page', rid: id, wide: true)
                          else
                            Padding(padding: const EdgeInsets.only(bottom: 12), child: Muted('${w('pageImage')} · ${w('saveForPhoto')}')),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }(),
        Align(
          alignment: Alignment.centerLeft,
          child: Btn(
            w('addPage'),
            icon: LucideIcons.plus,
            kind: BtnKind.ghost,
            small: true,
            onTap: ctx.readOnly || _pages.length >= 12
                ? null
                : () => setState(() {
                    final id = _newId();
                    _pages.add({'_id': id, 'slug': '', 'title': w('newPage'), 'subtitle': '', 'body': '', 'button': '', 'button_to': ''});
                    _nav.add({'kind': 'page', 'key': id, 'label': '', 'url': '', 'show': true});
                    _openPage = id;
                  }),
          ),
        ),
      ]),
      // services
      _part(w('services'), LucideIcons.briefcase, toggle: _svc, [
        _in('svc.title', _svc, 'title', w('servicesTitle'), max: 70, hint: w('servicesTitlePh')),
        _in('svc.subtitle', _svc, 'subtitle', w('servicesSub'), max: 200),
        if (_svcItems.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Muted(w('noServices'))),
        for (final (i, x) in _svcItems.indexed)
          () {
            final id = str(x['_id']);
            final open = _openSvc == id;
            final stored = _savedSvc(id);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: c.bg2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: open ? c.brand : Colors.transparent),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: () => setState(() => _openSvc = open ? null : id),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: c.active,
                            child: Icon(serviceIcons[x['icon']] ?? LucideIcons.briefcase, size: 15, color: c.brand),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(str(x['title']).ifBlank('…'), style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                          if (str(x['price']).isNotEmpty) Muted(str(x['price'])),
                          arrows(i, _svcItems.length, moveSvc),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: ctx.readOnly
                                ? null
                                : () => setState(() {
                                    _svcItems.removeAt(i);
                                    _drop('svc.$id');
                                  }),
                            icon: Icon(LucideIcons.trash2, size: 16, color: c.danger),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (open)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _in('svc.$id.title', x, 'title', w('serviceName'), max: 70),
                          _in('svc.$id.price', x, 'price', w('servicePrice'), max: 30, hint: w('servicePricePh')),
                          _in('svc.$id.text', x, 'text', w('serviceText'), max: 400, lines: 2),
                          Text(w('icon'), style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final e in serviceIcons.entries)
                                InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: ctx.readOnly ? null : () => setState(() => x['icon'] = e.key),
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(color: x['icon'] == e.key ? c.brand : c.card, borderRadius: BorderRadius.circular(10)),
                                    child: Icon(e.value, size: 17, color: x['icon'] == e.key ? Colors.white : c.ink),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(w('serviceLink'), style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _pages.any((p) => p['_id'] == x['page_id']) ? str(x['page_id']) : '',
                            isExpanded: true,
                            decoration: const InputDecoration(isDense: true),
                            items: [
                              DropdownMenuItem(value: '', child: Text(w('noLink'))),
                              for (final p in _pages)
                                DropdownMenuItem(
                                  value: str(p['_id']),
                                  child: Text(str(p['title']), overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            onChanged: ctx.readOnly || _pages.isEmpty ? null : (v) => setState(() => x['page_id'] = v ?? ''),
                          ),
                          const SizedBox(height: 12),
                          if (stored != null)
                            _photo(w('photo'), str(obj(stored['image'])['url']), 'service', rid: id)
                          else
                            Padding(padding: const EdgeInsets.only(bottom: 12), child: Muted('${w('photo')} · ${w('saveForPhoto')}')),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }(),
        Align(
          alignment: Alignment.centerLeft,
          child: Btn(
            w('addService'),
            icon: LucideIcons.plus,
            kind: BtnKind.ghost,
            small: true,
            onTap: ctx.readOnly || _svcItems.length >= 24
                ? null
                : () => setState(() {
                    final id = _newId();
                    _svcItems.add({'_id': id, 'icon': 'briefcase', 'title': '', 'text': '', 'price': '', 'page_id': ''});
                    _openSvc = id;
                  }),
          ),
        ),
      ]),
      // about
      _part(w('about'), LucideIcons.bookOpen, toggle: about, [
        _in('about.title', about, 'title', w('aboutTitle'), max: 70, hint: w('aboutTitlePh')),
        _in('about.text', about, 'text', w('aboutText'), max: 2000, lines: 5),
        _photo(w('aboutImage'), str(obj(obj(site['about'])['image'])['url']), 'about'),
        Text(w('highlights'), style: const TextStyle(fontWeight: FontWeight.w700)),
        Muted(w('highlightsHint')),
        const SizedBox(height: 8),
        for (final (i, h) in highs.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 86,
                  child: Field(
                    controller: _ctl.putIfAbsent('hl.$i.v', () => TextEditingController(text: str(h['value']))),
                    hint: ['15+', '200', '40', '500+'][i],
                    maxLength: 20,
                    onChanged: (v) => setState(() => h['value'] = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Field(
                    controller: _ctl.putIfAbsent('hl.$i.l', () => TextEditingController(text: str(h['label']))),
                    hint: i < hlPh.length ? hlPh[i] : '',
                    maxLength: 40,
                    onChanged: (v) => setState(() => h['label'] = v),
                  ),
                ),
                IconButton(
                  onPressed: ctx.readOnly
                      ? null
                      : () => setState(() {
                          highs.removeAt(i);
                          _drop('hl.');
                        }),
                  icon: Icon(LucideIcons.trash2, size: 16, color: c.danger),
                ),
              ],
            ),
          ),
        if (highs.length < 4)
          Align(
            alignment: Alignment.centerLeft,
            child: Btn(
              w('addHighlight'),
              icon: LucideIcons.plus,
              kind: BtnKind.ghost,
              small: true,
              onTap: ctx.readOnly ? null : () => setState(() => (about['highlights'] as List).add(<String, dynamic>{'value': '', 'label': ''})),
            ),
          ),
      ]),
      // gallery
      _part(w('gallery'), LucideIcons.images, toggle: gal, [
        _in('gal.title', gal, 'title', w('galleryTitle'), max: 70, hint: st('gallery')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, img) in images.indexed)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image(
                      image: netImage(str(img['url'])),
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(width: 84, height: 84, color: c.bg2),
                    ),
                  ),
                  if (!ctx.readOnly)
                    Positioned(
                      top: 3,
                      right: 3,
                      child: InkWell(
                        onTap: _busy == 'gallery' ? null : () => _removeImage('gallery', index: i),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(LucideIcons.trash2, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            if (images.length < 12 && !ctx.readOnly)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _busy == 'gallery' ? null : () => _upload('gallery'),
                child: Container(
                  width: 84,
                  height: 84,
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
                              w('addPhotos'),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 10.5, color: c.muted),
                            ),
                          ],
                        ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Muted(w('galleryHint')),
      ]),
      // message form
      _part(w('form'), LucideIcons.mail, toggle: form, [
        Muted(w('formSub')),
        const SizedBox(height: 10),
        _in('form.title', form, 'title', w('formTitle'), max: 70, hint: st('writeUs')),
        _in('form.text', form, 'text', w('formText'), max: 200, hint: st('writeUsSub')),
        SwitchRow(
          title: w('notifyTelegram'),
          sub: ctx.addonOn('att_telegram') ? null : w('notifyNeedsTelegram'),
          value: form['notify_telegram'] == true,
          onChanged: ctx.readOnly ? null : (v) => setState(() => form['notify_telegram'] = v),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Btn(
            '${w('openInbox')}${n(_res!['unread']) > 0 ? ' (${n(_res!['unread'])})' : ''}',
            icon: LucideIcons.inbox,
            kind: BtnKind.ghost,
            small: true,
            onTap: () => setState(() => _view = 'inbox'),
          ),
        ),
      ]),
      // contact
      _part(w('contact'), LucideIcons.phone, toggle: con, [
        _in('con.title', con, 'title', w('contactTitle'), max: 70, hint: st('contact')),
        _in('con.phone', con, 'phone', w('phone'), max: 30, kb: TextInputType.phone),
        _in('con.email', con, 'email', w('email'), max: 80, kb: TextInputType.emailAddress),
        _in('con.hours', con, 'hours', w('hours'), max: 120, hint: w('hoursPh')),
        _in('con.address', con, 'address', w('addressLine'), max: 200),
        _in('con.map', con, 'map_url', w('map'), max: 300, hint: 'https://maps.app.goo.gl/…'),
        for (final k in _socials)
          _in(
            'con.$k',
            con,
            k,
            switch (k) {
              'tiktok' => 'TikTok',
              'linkedin' => 'LinkedIn',
              'youtube' => 'YouTube',
              _ => '${k[0].toUpperCase()}${k.substring(1)}',
            },
            max: 300,
            hint: k == 'telegram' ? 't.me/yourname' : '$k.com/…',
          ),
        _in('footer', f, 'footer_note', w('footerNote'), max: 200),
      ]),
      // seo
      _part(w('seo'), LucideIcons.search, [
        _in('seo.title', seo, 'title', w('seoTitle'), max: 70, hint: str(biz['name'])),
        _in('seo.desc', seo, 'description', w('seoDesc'), max: 160, lines: 2, hint: w('seoDescPh')),
      ]),
    ];
  }
}

extension on String {
  String ifBlank(String v) => isEmpty ? v : this;
}

// messages sent from the website's form
class _Inbox extends StatefulWidget {
  final AtCtx ctx;
  final ValueChanged<int> onUnread;
  const _Inbox({required this.ctx, required this.onUnread});
  @override
  State<_Inbox> createState() => _InboxState();
}

class _InboxState extends State<_Inbox> {
  AtCtx get ctx => widget.ctx;
  List<Json>? _rows;
  int _unread = 0;
  String w(String k, [Map<String, Object?> v = const {}]) => ctx.t('atwb.$k', v);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _count(Object? v) {
    _unread = n(v).toInt();
    widget.onUnread(_unread);
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/site/messages', {'page': '1'});
      if (!mounted) return;
      setState(() {
        _rows = objs(r['data']);
        _count(r['unread']);
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = _rows;
    if (rows == null) return const SkelList(rows: 3);
    return atPanel([
      Row(
        children: [
          Expanded(
            child: Text(w('inbox'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
          if (_unread > 0) ...[
            Chip2(w('msgUnread', {'n': _unread}), tone: Tone.warn),
            const SizedBox(width: 6),
            Btn(
              w('readAll'),
              icon: LucideIcons.check,
              kind: BtnKind.ghost,
              small: true,
              onTap: () async {
                if (await ctx.run(() => ctx.api.post('${ctx.base}/site/messages/read-all')) != null) {
                  setState(() {
                    for (final m in rows) {
                      m['read'] = true;
                    }
                    _count(0);
                  });
                }
              },
            ),
          ],
        ],
      ),
      const SizedBox(height: 8),
      if (rows.isEmpty)
        Muted(w('msgEmpty'))
      else
        for (final m in rows)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: m['read'] == true ? c.bg2 : c.active, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(str(m['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    AtTag(ctx.t.or('atwb.kinds.${m['kind']}', str(m['kind'])), tone: 'blue'),
                  ],
                ),
                Muted(mDate(m['created_date'], ctx.lang)),
                const SizedBox(height: 6),
                Text(str(m['message']), style: const TextStyle(height: 1.4)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Btn(
                      str(m['contact']),
                      icon: str(m['contact']).contains('@') ? LucideIcons.mail : LucideIcons.phone,
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: () {
                        final v = str(m['contact']);
                        launchUrl(Uri.parse(v.contains('@') ? 'mailto:$v' : 'tel:${v.replaceAll(RegExp(r'\s+'), '')}'));
                      },
                    ),
                    Btn(
                      m['read'] == true ? w('markUnread') : w('markRead'),
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: () async {
                        final r = await ctx.run(() => ctx.api.put('${ctx.base}/site/messages/${m['_id']}', {'read': m['read'] != true}));
                        if (r != null && mounted) {
                          setState(() {
                            m['read'] = obj(r['data'])['read'] == true;
                            _count(r['unread']);
                          });
                        }
                      },
                    ),
                    IconButton(
                      onPressed: () async {
                        final r = await ctx.run(() => ctx.api.delete('${ctx.base}/site/messages/${m['_id']}'));
                        if (r != null && mounted) {
                          setState(() {
                            rows.remove(m);
                            _count(r['unread']);
                          });
                        }
                      },
                      icon: Icon(LucideIcons.trash2, size: 17, color: c.danger),
                    ),
                  ],
                ),
              ],
            ),
          ),
    ]);
  }
}
