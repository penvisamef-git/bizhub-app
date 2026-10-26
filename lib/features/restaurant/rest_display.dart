import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/buy_sheet.dart';
import '../../widgets/look_sheet.dart';
import '../../widgets/ui.dart';
import 'rest_common.dart';
import 'rest_looks.dart' show lookStatus, moneyOfSettings, sampleOrder;
import 'rest_receipt.dart' show calcOrder, lineTotal;

// Customer display (the web's DisplayTab.jsx): texts, pictures and look of the screen facing the guest, with a live preview.

extension on RestCtx {
  String x(String key, [Map<String, Object?> vars = const {}]) => t('extras.$key', vars);
}

const _formKeys = ['theme', 'color', 'header', 'welcome', 'thanks', 'footer', 'show_logo', 'slide_seconds', 'thanks_blur'];
Json _pick(Json d) => {for (final k in _formKeys) k: d[k]};

class DisplaySection extends StatefulWidget {
  final RestCtx ctx;
  const DisplaySection({super.key, required this.ctx});
  @override
  State<DisplaySection> createState() => _DisplaySectionState();
}

class _DisplaySectionState extends State<DisplaySection> {
  Json? _data, _form;
  bool _saving = false;
  String _uploading = '', _mode = 'idle';
  final _c = {
    for (final k in ['welcome', 'thanks', 'header', 'footer']) k: TextEditingController(),
  };
  RestCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/display');
      if (!mounted) return;
      setState(() {
        _data = obj(r['data']);
        if (_form == null) _reset();
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  void _reset() {
    _form = _pick(obj(_data!['display']));
    for (final e in _c.entries) {
      e.value.text = str(_form![e.key]);
    }
  }

  bool get _dirty {
    final a = _pick(obj(_data!['display']));
    return _formKeys.any((k) => '${_form![k]}' != '${a[k]}');
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final r = await ctx.api.put('${ctx.base}/display', _form);
      setState(() {
        _data = obj(r['data']);
        _reset();
      });
      ctx.notify(ctx.r('saved'));
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _upload(String slot, int room) async {
    final picker = ImagePicker();
    final files = room > 1
        ? await picker.pickMultiImage(maxWidth: 1920, maxHeight: 1920, imageQuality: 85, limit: room)
        : [?await picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, maxHeight: 1920, imageQuality: 85)];
    if (files.isEmpty) return;
    setState(() => _uploading = slot);
    try {
      Json? last;
      for (final f in files.take(room)) {
        last = await ctx.api.post('${ctx.base}/display/image', imageForm(await f.readAsBytes(), '$slot.jpg', {'slot': slot}));
      }
      if (last != null && mounted) setState(() => _data = obj(last!['data']));
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _uploading = '');
    }
  }

  Future<void> _remove(String slot, int i) async {
    try {
      final r = await ctx.api.delete('${ctx.base}/display/image', {'index': i, 'slot': slot});
      if (mounted) setState(() => _data = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  // what the guest's screen shows now
  Json _pic(String mode, [String? theme]) {
    final s = ctx.settings;
    final money = moneyOfSettings(s);
    final sample = sampleOrder(ctx);
    final t = calcOrder(sample, money);
    final d = obj(_data!['display']);
    return {
      'mode': mode,
      'restaurant': {'name_km': s['name_km'], 'name_en': s['name_en'], 'logo': obj(s['logo'])['url'] ?? '', 'color': s['color'] ?? ''},
      'look': {...d, ..._form!, 'theme': ?theme},
      'currency': money['currency'],
      'other': money['currency'] == 'USD' ? 'KHR' : 'USD',
      'rate': money['khr_rate'],
      'order': {
        'table': sample['table_name'],
        'lines': [
          for (final l in objs(sample['lines']))
            {'id': l['id'], 'qty': l['qty'], 'name_km': l['name_km'], 'name_en': l['name_en'], 'addons': objs(l['addons']).map((a) => str(a['name'])).toList(), 'total': lineTotal(l)},
        ],
        'totals': t,
      },
      'change': {'usd': 0, 'khr': ((20 - n(t['total'])) * n(money['khr_rate']) / 100).round() * 100},
    };
  }

  String _themeName(String k) => ctx.t.or('dtheme.$k.${ctx.lang}', k);

  void _buy(String k) {
    final price = n(obj(_data!['themes'])['price']);
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BuySheet(
        stage: SizedBox(width: 280, child: DisplayMock(pic: _pic('order', k))),
        badge: ctx.x('cdTitle'),
        title: ctx.x('lookBuyTitle', {'name': _themeName(k)}),
        sub: ctx.x('lookBuySub'),
        perks: [ctx.x('lookPerk'), '${ctx.r('oneTime')} · ${ctx.r('forever')}'],
        price: price,
        buyLabel: ctx.r('buy', {'coins': '${fmt(price)} ${ctx.r('coins')}'}),
        doneTitle: ctx.r('unlockedTag'),
        doneSub: ctx.x('lookDone', {'name': _themeName(k)}),
        doneButton: ctx.t('app.continue'),
        buy: () => ctx.api.post('${ctx.base}/display/themes/$k'),
        onDone: (_) {
          setState(() => _form!['theme'] = k);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final data = _data, form = _form;
    if (data == null || form == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 4));
    final active = data['active'] == true;
    final ro = ctx.readOnly;
    final themes = obj(data['themes']);
    final free = ((themes['free'] as List?) ?? const []).map((e) => '$e').toList();
    final paid = ((themes['paid'] as List?) ?? const []).map((e) => '$e').toList();
    final owned = ((themes['owned'] as List?) ?? const []).map((e) => '$e').toList();
    final banners = objs(data['banners']), side = objs(data['side_banners']);
    final thanksBg = str(obj(data['display'])['thanks_bg']);
    void set(String k, Object? v) => setState(() => form[k] = v);
    Widget field(String k, String label, String ph, int max, {String? mode}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Focus(
        onFocusChange: (f) => f && mode != null ? setState(() => _mode = mode) : null,
        child: Field(label: label, hint: ph, controller: _c[k]!, maxLength: max, enabled: !ro, onChanged: (v) => set(k, v)),
      ),
    );
    final list = <Widget>[Panel(child: RestHead(ctx.x('cdTitle'), sub: ctx.x('cdSub'))), gap14];
    if (!active) {
      list.add(AddonPrompt(ctx: ctx, addonKey: 'rest_display'));
      return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: list);
    }
    list.addAll([
      // live preview
      Panel(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(ctx.x('preview'), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Segmented<String>(value: _mode, options: [('idle', ctx.x('pvIdle')), ('order', ctx.x('pvOrder')), ('thanks', ctx.x('pvThanks'))], onChanged: (v) => setState(() => _mode = v)),
            const SizedBox(height: 12),
            DisplayMock(pic: _pic(_mode)),
          ],
        ),
      ),
      gap14,
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Muted(ctx.x('cdHow')),
            const SizedBox(height: 14),
            Text(ctx.x('texts'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            field('welcome', ctx.x('welcome'), ctx.x('welcomePh'), 80, mode: 'idle'),
            field('thanks', ctx.x('thanks'), ctx.x('thanksPh'), 80, mode: 'thanks'),
            field('header', ctx.x('header'), ctx.x('headerPh'), 80),
            field('footer', ctx.x('footer'), ctx.x('footerPh'), 120),
            SwitchRow(title: ctx.x('showLogo'), value: form['show_logo'] != false, onChanged: ro ? null : (v) => set('show_logo', v)),
          ],
        ),
      ),
      gap14,
      _picPanel(ctx.x('pictures'), ctx.x('picturesHint', {'n': data['max_banners']}), banners, n(data['max_banners']).toInt(), 'banner', 'idle', ro, c),
      if (banners.length + side.length > 1) ...[
        const SizedBox(height: 10),
        SelectField<num>(
          label: ctx.x('slide'),
          value: n(form['slide_seconds']) == 0 ? 6 : n(form['slide_seconds']),
          options: [
            for (final s in [4, 6, 10, 15]) (s, ctx.x('seconds', {'n': s})),
          ],
          onChanged: ro ? null : (v) => set('slide_seconds', v),
        ),
      ],
      gap14,
      _picPanel(ctx.x('sidePictures'), ctx.x('sideHint', {'n': data['max_side']}), side, n(data['max_side']).toInt(), 'side', 'order', ro, c),
      gap14,
      _picPanel(
        ctx.x('thanksPicture'),
        ctx.x('thanksPictureHint'),
        thanksBg.isEmpty
            ? []
            : [
                {'url': thanksBg},
              ],
        1,
        'thanks',
        'thanks',
        ro,
        c,
        extra: Row(
          children: [
            Text('${ctx.x('blur')} ', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              '${n(form['thanks_blur'])}%',
              style: TextStyle(color: c.brandInk, fontWeight: FontWeight.w800),
            ),
            Expanded(
              child: Slider(
                value: n(form['thanks_blur']).toDouble().clamp(0, 100),
                min: 0,
                max: 100,
                divisions: 20,
                onChanged: ro || thanksBg.isEmpty
                    ? null
                    : (v) => setState(() {
                        _mode = 'thanks';
                        form['thanks_blur'] = v.round();
                      }),
              ),
            ),
          ],
        ),
      ),
      gap14,
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RestHead(ctx.x('looks'), sub: ctx.x('looksSub')),
            LayoutBuilder(
              builder: (_, box) {
                final cols = box.maxWidth > 520 ? 3 : 2;
                final w = (box.maxWidth - 10 * (cols - 1)) / cols;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final k in [...free, ...paid])
                      SizedBox(width: w, child: _lookTile(k, form['theme'] == k, free.contains(k), owned.contains(k), n(themes['price']), ro, c, [...free, ...paid], free, owned)),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Text(ctx.x('colour'), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(label: Text(ctx.x('colourAuto')), selected: str(form['color']).isEmpty, onSelected: ro ? null : (_) => set('color', '')),
                for (final col in ((data['colors'] as List?) ?? const []).map((e) => '$e'))
                  GestureDetector(
                    onTap: ro ? null : () => set('color', col),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _hex(col),
                        shape: BoxShape.circle,
                        border: Border.all(color: form['color'] == col ? c.ink : Colors.transparent, width: 2.5),
                      ),
                      child: form['color'] == col ? const Icon(LucideIcons.check, size: 16, color: Colors.white) : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ]);
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: list),
          ),
        ),
        RestSaveBar(ctx: ctx, dirty: _dirty, saving: _saving, disabled: ro, onSave: _save, onUndo: () => setState(_reset)),
      ],
    );
  }

  // tap a look → the look sheet over all of them (swipe). "Use" sets the look here; the save bar saves it.
  Future<void> _openLooks(List<String> all, String start, List<String> free, List<String> owned, num price) => showLookSheet(
    context,
    title: ctx.x('looks'),
    count: all.length,
    initial: all.contains(start) ? all.indexOf(start) : 0,
    item: (context, i, refresh) {
      final k = all[i];
      final on = _form?['theme'] == k;
      final have = free.contains(k) || owned.contains(k);
      return LookItem(
        name: _themeName(k),
        sub: ctx.t.or('dtheme.$k.d_${ctx.lang}', ''),
        preview: SizedBox(width: 420, child: DisplayMock(pic: _pic('order', k))),
        badge: on ? ctx.x('inUse') : (free.contains(k) ? ctx.x('free') : (have ? ctx.x('owned') : '${fmt(price)} ${ctx.r('coins')}')),
        badgeTone: on || have ? Tone.good : Tone.warn,
        acts: [
          if (!on && have)
            LookAct(
              ctx.x('use'),
              icon: LucideIcons.check,
              onTap: ctx.readOnly
                  ? null
                  : () async {
                      setState(() {
                        _form!['theme'] = k;
                        _mode = 'order';
                      });
                      return true;
                    },
            ),
          if (!have)
            LookAct(
              ctx.r('buy', {'coins': '${fmt(price)} ${ctx.r('coins')}'}),
              gold: true,
              onTap: ctx.readOnly
                  ? null
                  : () async {
                      Future.microtask(() => _buy(k));
                      return true;
                    },
            ),
        ],
      );
    },
  );

  Widget _lookTile(String k, bool on, bool free, bool owned, num price, bool ro, C c, List<String> all, List<String> freeL, List<String> ownedL) {
    final have = free || owned;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openLooks(all, k, freeL, ownedL, price),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? c.brand : c.line, width: on ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Opacity(
              opacity: have ? 1 : .75,
              child: DisplayMock(pic: _pic('order', k)),
            ),
            const SizedBox(height: 8),
            Text(
              _themeName(k),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            lookStatus(context, ctx, on: on, free: free, owned: owned, price: price),
          ],
        ),
      ),
    );
  }

  Widget _picPanel(String title, String hint, List<Json> list, int max, String slot, String mode, bool ro, C c, {Widget? extra}) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (i, b) in list.indexed)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image(
                      image: netImage(str(b['url'])),
                      width: 128,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(width: 128, height: 72, color: c.bg2),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: RoundBtn(LucideIcons.trash2, size: 30, fg: c.danger, tip: ctx.r('remove'), onTap: ro || _uploading.isNotEmpty ? null : () => _remove(slot, i)),
                  ),
                ],
              ),
            if (list.length < max)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: ro || _uploading.isNotEmpty
                    ? null
                    : () {
                        setState(() => _mode = mode);
                        _upload(slot, max - list.length);
                      },
                child: Container(
                  width: 128,
                  height: 72,
                  decoration: BoxDecoration(
                    color: c.bg2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.line),
                  ),
                  child: _uploading == slot
                      ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.imagePlus, size: 20, color: c.muted),
                            const SizedBox(height: 4),
                            Text(
                              max > 1 ? ctx.x('addPictures') : ctx.x('addPicture'),
                              style: TextStyle(color: c.muted, fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                ),
              ),
          ],
        ),
        if (extra != null) ...[const SizedBox(height: 8), extra],
        const SizedBox(height: 8),
        Muted(hint),
      ],
    ),
  );
}

Color _hex(String h) => Color(0xFF000000 | (int.tryParse(h.replaceFirst('#', ''), radix: 16) ?? 0xE0581A));

// ------------------------------------------------------------------------------------------- the guest's screen
// A 1280×720 screen drawn from a "picture" { mode, restaurant, look, order, change }, shrunk to fit (DisplayView on the web).
// Each look is its own layout: clean (split), midnight (spotlight), sunset (paper receipt), nature (item cards),
// luxe (menu board), playful (bubbles).
class DisplayMock extends StatelessWidget {
  final Json pic;
  const DisplayMock({super.key, required this.pic});

  static const _sw = {
    'clean': [Color(0xFFF6F8FB), Color(0xFF2563EB), Color(0xFF0F172A)],
    'midnight': [Color(0xFF0B1220), Color(0xFF38BDF8), Color(0xFFE2E8F0)],
    'sunset': [Color(0xFFFFF7ED), Color(0xFFEA580C), Color(0xFF431407)],
    'nature': [Color(0xFFF0FDF4), Color(0xFF16A34A), Color(0xFF14532D)],
    'luxe': [Color(0xFF0C0A09), Color(0xFFD4AF37), Color(0xFFF5F0E1)],
    'playful': [Color(0xFFFDF4FF), Color(0xFFC026D3), Color(0xFF3B0764)],
  };

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(width: 1280, height: 720, child: _Screen(pic: pic)),
      ),
    ),
  );
}

class _Screen extends StatelessWidget {
  final Json pic;
  const _Screen({required this.pic});

  @override
  Widget build(BuildContext context) {
    final look = obj(pic['look']);
    final r = obj(pic['restaurant']);
    final theme = DisplayMock._sw.containsKey(str(look['theme'])) ? str(look['theme']) : 'clean';
    final sw = DisplayMock._sw[theme]!;
    final custom = str(look['color']).isNotEmpty ? _hex(str(look['color'])) : (theme == 'clean' && str(r['color']).isNotEmpty ? _hex(str(r['color'])) : null);
    final s = _Style(bg: sw[0], brand: custom ?? sw[1], ink: sw[2], theme: theme);
    final mode = str(pic['mode']);
    final body = switch (mode) {
      'order' => _order(s),
      'thanks' => _thanks(s, look, r),
      _ => _idle(s, look, r),
    };
    return DefaultTextStyle(
      style: TextStyle(color: s.ink, fontFamily: s.serif ? 'Georgia' : null, fontFamilyFallback: const ['KantumruyPro']),
      child: Container(
        color: s.bg,
        child: Column(
          children: [
            if (str(look['header']).isNotEmpty) _bar(s, str(look['header'])),
            Expanded(child: body),
            if (str(look['footer']).isNotEmpty) _bar(s, str(look['footer'])),
          ],
        ),
      ),
    );
  }

  Widget _bar(_Style s, String text) => Container(
    height: 48,
    alignment: Alignment.center,
    color: s.brand,
    child: Text(
      text,
      style: TextStyle(color: s.onBrand, fontSize: 22, fontWeight: FontWeight.w700),
    ),
  );

  List<String> get _imgs {
    final look = obj(pic['look']);
    final side = (look['side_banners'] as List?) ?? const [];
    final all = side.isNotEmpty ? side : ((look['banners'] as List?) ?? const []);
    return all.map((e) => e is Map ? str(e['url']) : '$e').where((e) => e.isNotEmpty).toList();
  }

  Widget _img(String url, {BoxFit fit = BoxFit.cover}) => Image(image: netImage(url), fit: fit, width: double.infinity, height: double.infinity, errorBuilder: (_, _, _) => const SizedBox.shrink());

  Widget _brand(_Style s, Json r, {bool big = false, bool logo = true, Color? color}) {
    final fg = color ?? s.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (logo)
          Container(
            width: big ? 110 : 56,
            height: big ? 110 : 56,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(big ? 28 : 14)),
            clipBehavior: Clip.antiAlias,
            child: str(r['logo']).isNotEmpty
                ? Image(
                    image: netImage(str(r['logo'])),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Icon(LucideIcons.chefHat, color: s.brand, size: big ? 54 : 28),
                  )
                : Icon(LucideIcons.chefHat, color: s.brand, size: big ? 54 : 28),
          ),
        if (logo) SizedBox(width: big ? 22 : 14),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (str(r['name_km']).isNotEmpty)
              Text(
                str(r['name_km']),
                style: TextStyle(fontSize: big ? 44 : 26, fontWeight: FontWeight.w800, color: fg),
              ),
            if (str(r['name_en']).isNotEmpty)
              Text(
                str(r['name_en']),
                style: TextStyle(fontSize: big ? 26 : 17, color: fg.withValues(alpha: .7)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _hello(_Style s, Json look, {Color? color}) {
    final w = str(look['welcome']);
    final st = TextStyle(fontSize: 64, fontWeight: FontWeight.w800, color: color ?? s.ink, height: 1.15);
    return w.isNotEmpty
        ? Text(w, textAlign: TextAlign.center, style: st)
        : Column(
            children: [
              Text('សូមស្វាគមន៍', style: st),
              Text('Welcome', style: st.copyWith(fontSize: 44, fontWeight: FontWeight.w600)),
            ],
          );
  }

  Widget _idle(_Style s, Json look, Json r) {
    final banners = ((look['banners'] as List?) ?? const []).map((e) => e is Map ? str(e['url']) : '$e').where((e) => e.isNotEmpty).toList();
    final logo = look['show_logo'] != false;
    if (banners.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _brand(s, r, big: true, logo: logo),
            const SizedBox(height: 40),
            _hello(s, look),
          ],
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        _img(banners.first),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xB3000000)], stops: [.45, 1]),
          ),
        ),
        Positioned(
          left: 60,
          right: 60,
          bottom: 50,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: _hello(s, look, color: Colors.white),
                ),
              ),
              _brand(s, r, logo: logo, color: Colors.white),
            ],
          ),
        ),
      ],
    );
  }

  Widget _thanks(_Style s, Json look, Json r) {
    final o = obj(pic['order']);
    final t = obj(o['totals']);
    final ch = obj(pic['change']);
    final bg = str(look['thanks_bg']);
    final blur = (n(look['thanks_blur'] ?? 30) / 100 * 24).toDouble();
    final fg = bg.isNotEmpty ? Colors.white : s.ink;
    final thanks = str(look['thanks']);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (bg.isNotEmpty) ...[
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Transform.scale(scale: blur > 0 ? 1.08 : 1, child: _img(bg)),
          ),
          Container(color: Colors.black.withValues(alpha: .45)),
        ],
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.circleCheck, size: 96, color: s.brand),
              const SizedBox(height: 20),
              if (thanks.isNotEmpty)
                Text(
                  thanks,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 60, fontWeight: FontWeight.w800, color: fg),
                )
              else ...[
                Text(
                  'សូមអរគុណ!',
                  style: TextStyle(fontSize: 60, fontWeight: FontWeight.w800, color: fg),
                ),
                Text(
                  'Thank you!',
                  style: TextStyle(fontSize: 42, fontWeight: FontWeight.w600, color: fg),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'បានបង់ · Paid  ${fmtMoney(n(t['total']), str(pic['currency']))}',
                style: TextStyle(fontSize: 30, color: fg.withValues(alpha: .85), fontWeight: FontWeight.w700),
              ),
              if (n(ch['usd']) > 0 || n(ch['khr']) > 0)
                Text(
                  'លុយអាប់ · Your change  ${[if (n(ch['usd']) > 0) fmtMoney(n(ch['usd']), 'USD'), if (n(ch['khr']) > 0) fmtMoney(n(ch['khr']), 'KHR')].join(' + ')}',
                  style: TextStyle(fontSize: 30, color: s.brand, fontWeight: FontWeight.w800),
                ),
              const SizedBox(height: 30),
              _brand(s, r, logo: look['show_logo'] != false, color: fg),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- order layouts
  String get _cur => str(pic['currency']);
  Json get _o => obj(pic['order']);
  Json get _t => obj(_o['totals']);
  List<Json> get _lines => objs(_o['lines']);
  String get _where => str(_o['table']).isNotEmpty ? 'តុ Table ${_o['table']}' : 'ខ្ចប់ Takeaway';
  String _km(Json l) => str(l['name_km']).isNotEmpty ? str(l['name_km']) : str(l['name_en']);

  Widget _grand(_Style s, {double size = 64, Color? color, CrossAxisAlignment align = CrossAxisAlignment.end}) => Column(
    crossAxisAlignment: align,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'សរុប · Total',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: (color ?? s.ink).withValues(alpha: .7)),
      ),
      Text(
        fmtMoney(n(_t['total']), _cur),
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, color: color ?? s.brand, height: 1.1),
      ),
      Text(fmtMoney(n(_t['other']), str(pic['other'])), style: TextStyle(fontSize: 26, color: (color ?? s.ink).withValues(alpha: .7))),
    ],
  );

  Widget _rows(_Style s) => Column(
    children: [
      _row('សរុបរង Subtotal', fmtMoney(n(_t['subtotal']), _cur), s),
      if (n(_t['discount']) > 0) _row('បញ្ចុះតម្លៃ Discount', '−${fmtMoney(n(_t['discount']), _cur)}', s),
      if (n(_t['service']) > 0) _row('សេវា Service', fmtMoney(n(_t['service']), _cur), s),
      if (n(_t['vat']) > 0) _row(_t['vat_included'] == true ? 'រួមអាករ VAT incl.' : 'អាករ VAT', fmtMoney(n(_t['vat']), _cur), s),
    ],
  );

  Widget _row(String a, String b, _Style s) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(a, style: TextStyle(fontSize: 24, color: s.ink.withValues(alpha: .75))),
        ),
        Text(b, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Widget _lineRow(Json l, _Style s, {bool dotted = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            '${fmtNum(l['qty'])}×',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: s.brand),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_km(l), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              if (str(l['name_km']).isNotEmpty && str(l['name_en']).isNotEmpty) Text(str(l['name_en']), style: TextStyle(fontSize: 20, color: s.ink.withValues(alpha: .6))),
              if ((l['addons'] as List?)?.isNotEmpty == true) Text((l['addons'] as List).join(' · '), style: TextStyle(fontSize: 18, color: s.brand)),
            ],
          ),
        ),
        if (dotted)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 22, left: 10, right: 10),
              child: Text(
                '.' * 60,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(color: s.ink.withValues(alpha: .4), letterSpacing: 3),
              ),
            ),
          ),
        Text(fmtMoney(n(l['total']), _cur), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
      ],
    ),
  );

  Widget _slider(_Style s, {double radius = 0}) {
    final imgs = _imgs;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: imgs.isNotEmpty
          ? _img(imgs.first)
          : DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [s.brand.withValues(alpha: .35), s.brand]),
              ),
              child: Center(child: Icon(LucideIcons.utensilsCrossed, size: 90, color: Colors.white.withValues(alpha: .8))),
            ),
    );
  }

  Widget _order(_Style s) {
    final r = obj(pic['restaurant']);
    final look = obj(pic['look']);
    final logo = look['show_logo'] != false;
    switch (s.theme) {
      case 'midnight':
        return Column(
          children: [
            Expanded(
              flex: 58,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _slider(s),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x66000000), Color(0xE60B1220)]),
                    ),
                  ),
                  Positioned(
                    left: 40,
                    top: 30,
                    child: _brand(s, r, logo: logo, color: Colors.white),
                  ),
                  Positioned(
                    right: 40,
                    top: 40,
                    child: Text(
                      _where,
                      style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Positioned(right: 40, bottom: 20, child: _grand(s, size: 84, color: s.brand)),
                ],
              ),
            ),
            Expanded(
              flex: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(26),
                children: [
                  for (final l in _lines)
                    Container(
                      width: 300,
                      margin: const EdgeInsets.only(right: 20),
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .06),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: s.brand.withValues(alpha: .4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${fmtNum(l['qty'])}×',
                            style: TextStyle(fontSize: 26, color: s.brand, fontWeight: FontWeight.w800),
                          ),
                          Text(_km(l), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                          Text(str(l['name_en']), style: TextStyle(fontSize: 18, color: s.ink.withValues(alpha: .6))),
                          const Spacer(),
                          Text(fmtMoney(n(l['total']), _cur), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      case 'sunset':
        return Padding(
          padding: const EdgeInsets.all(30),
          child: Row(
            children: [
              Expanded(flex: 56, child: _slider(s, radius: 28)),
              const SizedBox(width: 30),
              Expanded(
                flex: 44,
                child: Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 30, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: _brand(s, r, logo: logo)),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(_where, style: TextStyle(fontSize: 22, color: s.ink.withValues(alpha: .7))),
                      ),
                      Divider(height: 30, color: s.ink.withValues(alpha: .3)),
                      for (final l in _lines) _lineRow(l, s),
                      const Spacer(),
                      Divider(height: 20, color: s.ink.withValues(alpha: .3)),
                      _grand(s, size: 60),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      case 'nature':
        return Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 30, 30, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _brand(s, r, logo: logo),
                              const Spacer(),
                              Text(_where, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 20,
                            runSpacing: 20,
                            children: [
                              for (final l in _lines)
                                Container(
                                  width: 260,
                                  height: 170,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: s.brand.withValues(alpha: .25), width: 2),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                        decoration: BoxDecoration(color: s.brand, borderRadius: BorderRadius.circular(99)),
                                        child: Text(
                                          '${fmtNum(l['qty'])}×',
                                          style: TextStyle(color: s.onBrand, fontSize: 22, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(_km(l), maxLines: 1, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                                      const Spacer(),
                                      Text(
                                        fmtMoney(n(l['total']), _cur),
                                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: s.brand),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 30),
                    SizedBox(width: 300, height: 420, child: _slider(s, radius: 24)),
                  ],
                ),
              ),
            ),
            Container(
              height: 120,
              padding: const EdgeInsets.symmetric(horizontal: 40),
              color: s.brand,
              child: Row(
                children: [
                  Text(
                    'សរុប · Total',
                    style: TextStyle(fontSize: 34, color: s.onBrand, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(fmtMoney(n(_t['other']), str(pic['other'])), style: TextStyle(fontSize: 28, color: s.onBrand.withValues(alpha: .8))),
                  const SizedBox(width: 30),
                  Text(
                    fmtMoney(n(_t['total']), _cur),
                    style: TextStyle(fontSize: 64, color: s.onBrand, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        );
      case 'luxe':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 200, vertical: 30),
          child: Column(
            children: [
              Container(
                height: 180,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(border: Border.all(color: s.brand, width: 2)),
                child: _slider(s),
              ),
              const SizedBox(height: 18),
              _brand(s, r, logo: false, color: s.brand),
              Text(_where, style: TextStyle(fontSize: 20, letterSpacing: 4, color: s.ink.withValues(alpha: .7))),
              const SizedBox(height: 10),
              for (final l in _lines) _lineRow(l, s, dotted: true),
              const Spacer(),
              Container(height: 1, color: s.brand),
              const SizedBox(height: 10),
              _grand(s, size: 58, align: CrossAxisAlignment.center),
            ],
          ),
        );
      case 'playful':
        final colors = [s.brand, const Color(0xFFF59E0B), const Color(0xFF06B6D4), const Color(0xFF22C55E)];
        return Padding(
          padding: const EdgeInsets.all(40),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _brand(s, r, logo: logo),
                        const Spacer(),
                        Text(_where, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Wrap(
                      spacing: 22,
                      runSpacing: 22,
                      children: [
                        for (final (i, l) in _lines.indexed)
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              color: colors[i % colors.length].withValues(alpha: .15),
                              shape: BoxShape.circle,
                              border: Border.all(color: colors[i % colors.length], width: 4),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${fmtNum(l['qty'])}×',
                                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: colors[i % colors.length]),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    _km(l),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                                  ),
                                ),
                                Text(fmtMoney(n(l['total']), _cur), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(color: s.brand, shape: BoxShape.circle),
                child: Center(
                  child: _grand(s, size: 70, color: s.onBrand, align: CrossAxisAlignment.center),
                ),
              ),
            ],
          ),
        );
      default: // clean
        return Row(
          children: [
            Expanded(
              flex: 60,
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _brand(s, r, logo: logo),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(color: s.brand.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
                          child: Text(
                            _where,
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: s.brand),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    for (final l in _lines) _lineRow(l, s),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 40,
              child: Container(
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_imgs.isNotEmpty) SizedBox(height: 260, child: _slider(s)),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(36),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _rows(s),
                          const SizedBox(height: 14),
                          _grand(s, size: 76),
                          const SizedBox(height: 10),
                          Text(
                            '1 USD = ${fmtMoney(n(pic['rate']), 'KHR')}',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 18, color: s.ink.withValues(alpha: .5)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
    }
  }
}

String fmtNum(Object? v) {
  final x = n(v);
  return x == x.roundToDouble() ? '${x.toInt()}' : '$x';
}

class _Style {
  final Color bg, brand, ink;
  final String theme;
  const _Style({required this.bg, required this.brand, required this.ink, required this.theme});
  bool get serif => theme == 'luxe';
  Color get onBrand => brand.computeLuminance() > .55 ? const Color(0xFF111111) : Colors.white;
}
