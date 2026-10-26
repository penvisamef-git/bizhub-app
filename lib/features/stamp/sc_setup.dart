import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/color_pick.dart' show pickColor;
import '../../widgets/look_sheet.dart';
import '../../widgets/ui.dart';
import '../guesthouse/gh_common.dart' show GhCtx, ghPickPicture;
import '../mart/mart_common.dart' show GoldBtn, fileForm;
import '../restaurant/rest_common.dart' show SwitchRow;
import '../restaurant/rest_online.dart' show shareWidgets;
import 'sc_card.dart';
import 'sc_common.dart';
import 'sc_data.dart';
import 'sc_poster.dart';

// ------------------------------------------------------------------------------------------------ SHOP QR (posters)
class ShopQrTab extends StatefulWidget {
  final ScCtx ctx;
  const ShopQrTab({super.key, required this.ctx});
  @override
  State<ShopQrTab> createState() => _ShopQrTabState();
}

class _ShopQrTabState extends State<ShopQrTab> {
  ScCtx get ctx => widget.ctx;
  final _shot = GlobalKey(), _qrShot = GlobalKey();
  late String _pick = str(ctx.program['poster']).isNotEmpty ? str(ctx.program['poster']) : 'basic';
  String _filter = 'all';
  int _shown = 12;
  final _lines = {
    for (final k in ['title', 'sub', 'rule', 'scan', 'note']) k: TextEditingController(),
  };
  bool _phone = true, _address = false, _busy = false;

  Json get _saved => {'title': '', 'sub': '', 'rule': '', 'scan': '', 'note': '', 'phone': true, 'address': false, ...obj(ctx.program['poster_info'])};

  @override
  void initState() {
    super.initState();
    final s = _saved;
    for (final e in _lines.entries) {
      e.value.text = str(s[e.key]);
    }
    _phone = s['phone'] != false;
    _address = s['address'] == true;
  }

  @override
  void dispose() {
    for (final c in _lines.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _has(String k) => ctx.ownedPosters.contains(k) || scPosterOf(k).tier == 'free';
  String get _rule => ctx.m('posterRule', {'goal': ctx.goal, 'reward': levelName(ctx.levels.last, ctx.lang)});
  bool get _dirty {
    final s = _saved;
    return _lines.entries.any((e) => e.value.text != str(s[e.key])) || _phone != (s['phone'] != false) || _address != (s['address'] == true);
  }

  Map<String, String> _info({bool saved = false}) {
    final s = _saved;
    String v(String k) => saved ? str(s[k]) : _lines[k]!.text;
    final ph = saved ? s['phone'] != false : _phone, ad = saved ? s['address'] == true : _address;
    return {for (final k in _lines.keys) k: v(k), 'phone': ph ? str(ctx.program['phone']) : '', 'address': ad ? str(ctx.program['address']) : ''};
  }

  Future<void> _use(String k) async {
    setState(() => _pick = k);
    if (!_has(k) || k == str(ctx.program['poster'])) return;
    if (await ctx.run(() => ctx.api.put('${ctx.base}/settings', {'poster': k})) != null) ctx.reload();
  }

  // tap a poster → the look sheet (big poster, swipe for the others). Use puts it on the shop QR at once · Buy unlocks it
  Future<void> _openPoster(List<String> keys, String k, String url, ScShop shop, String rule) async {
    await showLookSheet(
      context,
      title: ctx.m('posters'),
      count: keys.length,
      initial: keys.contains(k) ? keys.indexOf(k) : 0,
      item: (context, i, refresh) {
        final x = keys[i];
        final has = _has(x);
        final inUse = str(ctx.program['poster']) == x || (str(ctx.program['poster']).isEmpty && x == 'basic');
        return LookItem(
          name: scPosterName(x, ctx.lang),
          badge: inUse ? ctx.t('looks.inUse') : (has ? (scPosterOf(x).tier == 'free' ? ctx.m('free') : ctx.m('unlocked')) : ctx.m('buyTheme', {'coins': fmt(ctx.posterPrice)})),
          badgeTone: has ? Tone.good : Tone.warn,
          preview: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ScPosterView(poster: x, url: url, shop: shop, rule: rule, info: _info(), width: 320),
          ),
          acts: [
            if (has && !inUse)
              LookAct(
                ctx.m('useIt'),
                icon: LucideIcons.check,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        await _use(x);
                        return true;
                      },
              ),
            if (!has)
              LookAct(
                ctx.m('buyTheme', {'coins': fmt(ctx.posterPrice)}),
                gold: true,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        Future.microtask(() => ctx.askBuy('poster', item: x));
                        return true;
                      },
              ),
          ],
        );
      },
    );
  }

  Future<void> _saveInfo() async {
    setState(() => _busy = true);
    final body = {for (final e in _lines.entries) e.key: e.value.text.trim(), 'phone': _phone, 'address': _address};
    if (await ctx.run(() => ctx.api.put('${ctx.base}/settings', {'poster_info': body}), ctx.m('saved')) != null) await ctx.reload();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final url = shopUrl(ctx.program['slug']);
    final shop = ctx.shop();
    final keys = scPosters.keys.where((k) => _filter == 'all' || (_filter == 'mine' ? _has(k) : scPosterOf(k).layout == _filter)).toList();
    final locked = !_has(_pick);
    final rule = _rule;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        scHead(context, LucideIcons.qrCode, ctx.m('qrTitle'), ctx.m('qrSub')),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Btn(
              ctx.m('openShop'),
              icon: LucideIcons.externalLink,
              kind: BtnKind.ghost,
              small: true,
              onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            ),
            Btn(ctx.m('copyLink'), icon: LucideIcons.copy, kind: BtnKind.ghost, small: true, onTap: () => scCopy(ctx, url)),
          ],
        ),
        scGap,
        // the big preview
        scPanel([
          scTitle(context, '${ctx.m('preview')} · ${scPosterName(_pick, ctx.lang)}'),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: RepaintBoundary(
                key: _shot,
                child: ScPosterView(poster: _pick, url: url, shop: shop, rule: rule, info: _info(), width: 320),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (locked)
            Center(
              child: GoldBtn(ctx.m('buyTheme', {'coins': fmt(ctx.posterPrice)}), onTap: ctx.readOnly ? null : () => ctx.askBuy('poster', item: _pick)),
            )
          else ...[
            Btn(ctx.t('app.share'), icon: LucideIcons.share2, onTap: () => shareWidgets([_shot], (_) => '${ctx.program['slug']}-$_pick.png')),
            const SizedBox(height: 8),
            Btn(ctx.m('downloadQr'), icon: LucideIcons.qrCode, kind: BtnKind.ghost, small: true, onTap: () => shareWidgets([_qrShot], (_) => '${ctx.program['slug']}-qr.png')),
          ],
          const SizedBox(height: 6),
          SelectableText(
            url,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
          // the QR alone, for "Share QR only" (off screen)
          Offstage(
            child: RepaintBoundary(
              key: _qrShot,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: QrImageView(data: url, size: 330, padding: EdgeInsets.zero, backgroundColor: Colors.white),
              ),
            ),
          ),
        ]),
        scGap,
        // the designs
        scPanel([
          scTitle(context, ctx.m('posters')),
          Muted(ctx.m('postersSub', {'n': fmt(scPosters.length - 1), 'coins': fmt(ctx.posterPrice)})),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final k in ['all', 'mine', 'center', 'band', 'frame', 'ticket', 'stamps'])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(ctx.m('posterFilters.$k')),
                      selected: _filter == k,
                      onSelected: (_) => setState(() {
                        _filter = k;
                        _shown = 12;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, box) {
              final cols = box.maxWidth > 520 ? 4 : 3;
              final w = (box.maxWidth - 10 * (cols - 1)) / cols;
              return Wrap(
                spacing: 10,
                runSpacing: 12,
                children: [
                  for (final k in keys.take(_shown))
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openPoster(keys, k, url, shop, rule),
                      child: Container(
                        width: w,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: c.bg2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _pick == k ? c.brand : Colors.transparent, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ScPosterView(poster: k, url: url, shop: shop, rule: rule, info: _info(saved: true), width: w - 8),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(scPosterName(k, ctx.lang), maxLines: 2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.2)),
                                ),
                                if (_has(k))
                                  str(ctx.program['poster']) == k ? Icon(LucideIcons.check, size: 14, color: c.good) : const SizedBox.shrink()
                                else ...[
                                  const CoinIcon(size: 11),
                                  Text(' ${fmt(ctx.posterPrice)}', style: TextStyle(fontSize: 11, color: c.muted)),
                                ],
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
          if (keys.length > _shown)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Btn(ctx.m('more'), kind: BtnKind.ghost, small: true, onTap: () => setState(() => _shown += 12)),
            ),
        ]),
        scGap,
        // the words on the poster
        scPanel([
          scTitle(context, ctx.m('pInfo')),
          Muted(ctx.m('pInfoSub')),
          const SizedBox(height: 10),
          for (final (k, max, def) in [
            ('title', 60, scPosterText['title']!),
            ('sub', 80, scPosterText['sub']!),
            ('rule', 80, rule),
            ('scan', 90, scPosterText['scan']!),
            ('note', 90, scPosterText['note']!),
          ]) ...[Field(label: ctx.m('pLines.$k'), controller: _lines[k]!, hint: def, maxLength: max, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})), const SizedBox(height: 10)],
          Muted(ctx.m('pEmpty')),
          SwitchRow(
            title: ctx.m('pPhone'),
            sub: str(ctx.program['phone']).isNotEmpty ? str(ctx.program['phone']) : null,
            value: _phone,
            onChanged: ctx.readOnly || str(ctx.program['phone']).isEmpty ? null : (v) => setState(() => _phone = v),
          ),
          SwitchRow(
            title: ctx.m('pAddress'),
            sub: str(ctx.program['address']).isNotEmpty ? str(ctx.program['address']) : null,
            value: _address,
            onChanged: ctx.readOnly || str(ctx.program['address']).isEmpty ? null : (v) => setState(() => _address = v),
          ),
          if (str(ctx.program['phone']).isEmpty || str(ctx.program['address']).isEmpty) Muted(ctx.m('pNoContact')),
          if (_dirty) ...[const SizedBox(height: 10), Btn(ctx.m('save'), icon: LucideIcons.check, busy: _busy, onTap: ctx.readOnly ? null : _saveInfo)],
        ]),
        scGap,
        scPanel([
          SwitchRow(
            title: ctx.m('joinOn'),
            value: ctx.program['join_on'] != false,
            onChanged: ctx.readOnly
                ? null
                : (v) async {
                    if (await ctx.run(() => ctx.api.put('${ctx.base}/settings', {'join_on': v}), ctx.m('saved')) != null) ctx.reload();
                  },
          ),
          if (ctx.program['join_on'] == false) Muted(ctx.m('qrJoinOff')),
          const SizedBox(height: 8),
          if (ctx.on('sc_check'))
            Row(
              children: [
                Icon(LucideIcons.check, size: 16, color: c.good),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ctx.m('checkOn'),
                    style: TextStyle(color: c.good, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            )
          else
            ScLocked(ctx: ctx, addon: 'sc_check', small: true),
        ]),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ CARD & REWARDS
class DesignTab extends StatefulWidget {
  final ScCtx ctx;
  const DesignTab({super.key, required this.ctx});
  @override
  State<DesignTab> createState() => _DesignTabState();
}

class _LevelRow {
  int at;
  final TextEditingController en, km;
  _LevelRow(this.at, String e, String k) : en = TextEditingController(text: e), km = TextEditingController(text: k);
}

class _DesignTabState extends State<DesignTab> {
  ScCtx get ctx => widget.ctx;
  Json get p => ctx.program;
  late final _name = TextEditingController(text: ctx.shopName);
  late final _phone = TextEditingController(text: str(p['phone']));
  late final _address = TextEditingController(text: str(p['address']));
  late final _rewardEn = TextEditingController(text: str(p['reward_en']));
  late final _rewardKm = TextEditingController(text: str(p['reward_km']));
  late final _termsEn = TextEditingController(text: str(p['terms_en']));
  late final _termsKm = TextEditingController(text: str(p['terms_km']));
  late String _theme = str(p['theme']).isEmpty ? 'classic' : str(p['theme']);
  late String _color = str(p['color']);
  late String _icon = str(p['icon']).isEmpty ? 'coffee' : str(p['icon']);
  late int _goal = ctx.goal;
  late int _welcome = n(p['welcome']).toInt();
  late int _maxPer = n(p['max_per_visit']).toInt() == 0 ? 5 : n(p['max_per_visit']).toInt();
  late int _expiry = n(p['expiry_months']).toInt();
  late final List<_LevelRow> _levels = [for (final l in objs(p['levels'])) _LevelRow(n(l['at']).toInt(), str(l['en']), str(l['km']))];
  String _busy = '';
  bool _showPreview = true;

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _rewardEn, _rewardKm, _termsEn, _termsKm]) {
      c.dispose();
    }
    for (final l in _levels) {
      l.en.dispose();
      l.km.dispose();
    }
    super.dispose();
  }

  List<Json> get _previewLevels {
    final on = ctx.on('sc_levels');
    final list = <Json>[
      if (on)
        for (final l in _levels)
          if (l.at >= 1 && l.at < _goal && (l.en.text.isNotEmpty || l.km.text.isNotEmpty)) {'at': l.at, 'en': l.en.text, 'km': l.km.text},
      {'at': _goal, 'en': _rewardEn.text, 'km': _rewardKm.text},
    ];
    list.sort((a, b) => n(a['at']).compareTo(n(b['at'])));
    return list;
  }

  Future<void> _save() async {
    setState(() => _busy = 'save');
    final owned = ctx.ownedThemes.contains(_theme) || scThemeOf(_theme).tier == 'free';
    final body = <String, Object?>{
      'shop_name': _name.text.trim(),
      'phone': _phone.text.trim(),
      'address': _address.text.trim(),
      if (owned) 'theme': _theme,
      'color': _color,
      'icon': _icon,
      'goal': _goal,
      'reward_en': _rewardEn.text.trim(),
      'reward_km': _rewardKm.text.trim(),
      'welcome': _welcome,
      'max_per_visit': _maxPer,
      'terms_en': _termsEn.text.trim(),
      'terms_km': _termsKm.text.trim(),
      if (ctx.on('sc_levels'))
        'levels': [
          for (final l in _levels) {'at': l.at, 'en': l.en.text.trim(), 'km': l.km.text.trim()},
        ],
      if (ctx.on('sc_expiry')) 'expiry_months': _expiry,
    };
    if (await ctx.run(() => ctx.api.put('${ctx.base}/settings', body), ctx.m('saved')) != null) await ctx.reload();
    if (mounted) setState(() => _busy = '');
  }

  Future<void> _logo() async {
    final img = await ghPickPicture(
      context,
      GhCtx(id: ctx.id, api: ctx.api, t: ctx.t, data: const {}, reload: ctx.reload, askBuy: (_, {item, onDone}) {}, go: (_) {}, notify: ctx.notify),
      maxSize: 600,
    );
    if (img == null) return;
    setState(() => _busy = 'logo');
    if (await ctx.run(() => ctx.api.post('${ctx.base}/logo', fileForm('logo', img, 'logo.png'))) != null) await ctx.reload();
    if (mounted) setState(() => _busy = '');
  }

  // tap a card look → the look sheet (big card, swipe for the others). Use picks it (then Save, like before) · Buy unlocks it
  Future<void> _openTheme(String k) async {
    final keys = scThemes.keys.toList();
    await showLookSheet(
      context,
      title: ctx.m('look'),
      count: keys.length,
      initial: keys.contains(k) ? keys.indexOf(k) : 0,
      item: (context, i, refresh) {
        final x = keys[i];
        final t = scThemes[x]!;
        final has = t.tier == 'free' || ctx.ownedThemes.contains(x);
        final picked = _theme == x;
        return LookItem(
          name: ctx.lang == 'km' ? t.km : t.en,
          badge: picked ? ctx.t('looks.inUse') : (has ? (t.tier == 'free' ? ctx.m('free') : ctx.m('unlocked')) : ctx.m('buyTheme', {'coins': fmt(ctx.themePrice)})),
          badgeTone: has ? Tone.good : Tone.warn,
          preview: SizedBox(
            width: 320,
            child: ScCardView(
              shop: ScShop(name: _name.text, logo: str(p['logo']), theme: x, color: picked ? _color : '', icon: _icon, goal: _goal, levels: _previewLevels),
              member: {'name': ctx.lang == 'km' ? 'សុខា' : 'Sokha', 'no': 12, 'stamps': (_goal * .6).round().clamp(1, 20), 'claimed': const []},
              lang: ctx.lang,
            ),
          ),
          acts: [
            if (has && !picked)
              LookAct(
                ctx.m('useIt'),
                icon: LucideIcons.check,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        setState(() => _theme = x);
                        return true;
                      },
              ),
            if (!has)
              LookAct(
                ctx.m('buyTheme', {'coins': fmt(ctx.themePrice)}),
                gold: true,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        Future.microtask(() => ctx.askBuy('theme', item: x));
                        return true;
                      },
              ),
          ],
        );
      },
    );
  }

  Widget _drop<V>(String label, V value, List<(V, String)> items, ValueChanged<V> onChanged, {bool enabled = true}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
      const SizedBox(height: 6),
      DropdownButtonFormField<V>(
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
        items: [for (final (v, l) in items) DropdownMenuItem(value: v, child: Text(l))],
        onChanged: enabled ? (v) => v == null ? null : onChanged(v) : null,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ro = ctx.readOnly;
    final logo = str(p['logo']);
    final accent = scHex(_color) ?? scThemeOf(_theme).accent;
    return Column(
      children: [
        // the live preview stays in view while you scroll the settings (the web's right bar)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _showPreview = !_showPreview),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(LucideIcons.eye, size: 15, color: c.muted),
                      const SizedBox(width: 6),
                      Text(
                        ctx.m('preview'),
                        style: TextStyle(fontWeight: FontWeight.w800, color: c.muted, fontSize: 13),
                      ),
                      const Spacer(),
                      Icon(_showPreview ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 16, color: c.muted),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: _showPreview
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 250),
                          child: ScCardView(
                            shop: ScShop(name: _name.text, logo: logo, theme: _theme, color: _color, icon: _icon, goal: _goal, levels: _previewLevels),
                            member: {'name': ctx.lang == 'km' ? 'សុខា' : 'Sokha', 'no': 12, 'stamps': (_goal * .6).round().clamp(1, 20), 'claimed': const []},
                            lang: ctx.lang,
                            compact: true,
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              scPanel([
                scTitle(context, ctx.m('shopBox')),
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(16)),
                      child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.imagePlus, color: c.brand),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Btn(ctx.m('logoPick'), icon: LucideIcons.imagePlus, kind: BtnKind.ghost, small: true, busy: _busy == 'logo', onTap: ro || _busy.isNotEmpty ? null : _logo),
                          if (logo.isNotEmpty)
                            Btn(
                              ctx.m('logoRemove'),
                              kind: BtnKind.ghost,
                              small: true,
                              onTap: ro
                                  ? null
                                  : () async {
                                      if (await ctx.run(() => ctx.api.delete('${ctx.base}/logo')) != null) ctx.reload();
                                    },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Field(label: ctx.m('shopName'), controller: _name, maxLength: 80, enabled: !ro, onChanged: (_) => setState(() {})),
                const SizedBox(height: 6),
                Muted(ctx.m('shopBoxHint')),
              ]),
              scGap,
              scPanel([
                scTitle(context, ctx.m('look')),
                LayoutBuilder(
                  builder: (context, box) {
                    final cols = box.maxWidth > 520 ? 3 : 2;
                    final w = (box.maxWidth - 10 * (cols - 1)) / cols;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final k in scThemes.keys)
                          () {
                            final t = scThemes[k]!;
                            final has = t.tier == 'free' || ctx.ownedThemes.contains(k);
                            return InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _openTheme(k),
                              child: Container(
                                width: w,
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: c.bg2,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _theme == k ? c.brand : Colors.transparent, width: 2),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    ScThemeSwatch(theme: t, icon: _icon),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            ctx.lang == 'km' ? t.km : t.en,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                                          ),
                                        ),
                                        if (has)
                                          _theme == k
                                              ? Icon(LucideIcons.check, size: 14, color: c.good)
                                              : Text(t.tier == 'free' ? ctx.m('free') : ctx.m('unlocked'), style: TextStyle(fontSize: 11, color: c.muted))
                                        else ...[
                                          const CoinIcon(size: 11),
                                          Text(' ${fmt(ctx.themePrice)}', style: TextStyle(fontSize: 11, color: c.muted)),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }(),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                scTitle(context, ctx.m('stampIcon')),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final k in (ctx.data['icons'] as List? ?? scIcons.keys.toList()).map((e) => '$e'))
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _icon = k),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _icon == k ? accent.withValues(alpha: .14) : c.bg2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _icon == k ? accent : c.line, width: _icon == k ? 2 : 1),
                          ),
                          child: Icon(scIconOf(k), size: 20, color: _icon == k ? accent : c.ink),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(ctx.m('color'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: ro
                          ? null
                          : () async {
                              final col = await pickColor(context, accent, ctx.m('save'), ctx.m('cancel'));
                              if (col != null) setState(() => _color = scColorHex(col));
                            },
                      child: Container(
                        width: 56,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.line),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (_color.isNotEmpty) TextButton.icon(onPressed: () => setState(() => _color = ''), icon: const Icon(LucideIcons.rotateCcw, size: 14), label: Text(ctx.m('colorReset'))),
                  ],
                ),
                const SizedBox(height: 12),
                Field(label: ctx.m('shopPhone'), controller: _phone, keyboard: TextInputType.phone, maxLength: 40, enabled: !ro),
                const SizedBox(height: 10),
                Field(label: ctx.m('shopAddress'), controller: _address, maxLength: 200, enabled: !ro),
              ]),
              scGap,
              scPanel([
                scTitle(context, ctx.m('rule')),
                Row(
                  children: [
                    Expanded(child: _drop<int>(ctx.m('goal'), _goal, [for (var i = 3; i <= 20; i++) (i, '$i')], (v) => setState(() => _goal = v), enabled: !ro)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _drop<int>(
                        ctx.m('welcome'),
                        _welcome,
                        [
                          for (final i in [0, 1, 2, 3]) (i, i == 0 ? ctx.m('welcomeNone') : '$i'),
                        ],
                        (v) => setState(() => _welcome = v),
                        enabled: !ro,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Field(label: ctx.m('rewardEn'), controller: _rewardEn, maxLength: 80, enabled: !ro, onChanged: (_) => setState(() {})),
                const SizedBox(height: 10),
                Field(label: ctx.m('rewardKm'), controller: _rewardKm, maxLength: 120, enabled: !ro, onChanged: (_) => setState(() {})),
                const SizedBox(height: 14),
                scTitle(context, ctx.m('levels')),
                if (ctx.on('sc_levels')) ...[
                  Muted(ctx.m('levelsHint')),
                  const SizedBox(height: 8),
                  for (final (i, l) in _levels.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 80,
                            child: _drop<int>(ctx.m('levelAt'), l.at.clamp(1, _goal - 1), [for (var k = 1; k < _goal; k++) (k, '$k ★')], (v) => setState(() => l.at = v), enabled: !ro),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Field(controller: l.en, hint: 'English', maxLength: 80, enabled: !ro, onChanged: (_) => setState(() {})),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Field(controller: l.km, hint: 'ខ្មែរ', maxLength: 120, enabled: !ro, onChanged: (_) => setState(() {})),
                          ),
                          IconButton(
                            onPressed: ro ? null : () => setState(() => _levels.removeAt(i)),
                            icon: Icon(LucideIcons.trash2, size: 17, color: c.danger),
                          ),
                        ],
                      ),
                    ),
                  if (_levels.length < 4)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Btn(
                        ctx.m('levelAdd'),
                        icon: LucideIcons.plus,
                        kind: BtnKind.ghost,
                        small: true,
                        onTap: ro ? null : () => setState(() => _levels.add(_LevelRow((_goal / 2).floor().clamp(1, _goal - 1), '', ''))),
                      ),
                    ),
                ] else
                  ScLocked(ctx: ctx, addon: 'sc_levels', small: true),
              ]),
              scGap,
              scPanel([
                _drop<int>(
                  ctx.m('maxPerVisit'),
                  [1, 2, 3, 5, 10].contains(_maxPer) ? _maxPer : 5,
                  [
                    for (final i in [1, 2, 3, 5, 10]) (i, '$i'),
                  ],
                  (v) => setState(() => _maxPer = v),
                  enabled: !ro,
                ),
                const SizedBox(height: 12),
                if (ctx.on('sc_expiry'))
                  _drop<int>(
                    ctx.m('expiry'),
                    [0, 3, 6, 9, 12, 18, 24].contains(_expiry) ? _expiry : 0,
                    [
                      for (final i in [0, 3, 6, 9, 12, 18, 24]) (i, i == 0 ? ctx.m('expiryNever') : ctx.m('expiryMonths', {'n': i})),
                    ],
                    (v) => setState(() => _expiry = v),
                    enabled: !ro,
                  )
                else ...[
                  Text(ctx.m('expiry'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  const SizedBox(height: 6),
                  ScLocked(ctx: ctx, addon: 'sc_expiry', small: true),
                ],
                const SizedBox(height: 14),
                scTitle(context, ctx.m('terms')),
                Field(label: ctx.m('termsEn'), controller: _termsEn, hint: ctx.m('termsPh'), maxLength: 300, maxLines: 2, enabled: !ro),
                const SizedBox(height: 10),
                Field(label: ctx.m('termsKm'), controller: _termsKm, maxLength: 400, maxLines: 2, enabled: !ro),
              ]),
            ],
          ),
        ),
        // save
        Container(
          decoration: BoxDecoration(
            color: c.card,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 20, offset: const Offset(0, -4))],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Btn(ctx.m('save'), icon: LucideIcons.check, busy: _busy == 'save', expand: true, onTap: ro || _busy.isNotEmpty ? null : _save),
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ STAFF DESK
class DeskTab extends StatefulWidget {
  final ScCtx ctx;
  const DeskTab({super.key, required this.ctx});
  @override
  State<DeskTab> createState() => _DeskTabState();
}

class _DeskTabState extends State<DeskTab> {
  ScCtx get ctx => widget.ctx;
  final _pin = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _save(Map<String, Object?> body, [String? ok]) async {
    setState(() => _busy = true);
    if (await ctx.run(() => ctx.api.put('${ctx.base}/desk', body), ok ?? ctx.m('saved')) != null) {
      _pin.clear();
      await ctx.reload();
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = obj(ctx.program['desk']);
    final url = deskUrl(ctx.program['slug']);
    final ro = ctx.readOnly;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        scHead(context, LucideIcons.monitor, ctx.m('deskTitle'), ctx.m('deskSub')),
        scGap,
        scPanel([
          SwitchRow(title: ctx.m('deskOn'), value: d['on'] != false, onChanged: ro || _busy ? null : (v) => _save({'on': v})),
          SwitchRow(title: ctx.m('deskCanReset'), sub: ctx.m('deskCanResetSub'), value: d['can_reset'] == true, onChanged: ro || _busy ? null : (v) => _save({'can_reset': v})),
          const SizedBox(height: 6),
          Muted(d['has_pin'] == true ? ctx.m('deskPinSet') : ctx.m('deskPinNone')),
          const SizedBox(height: 10),
          Field(label: ctx.m('deskPin'), controller: _pin, password: true, keyboard: TextInputType.number, maxLength: 8, enabled: !ro, onChanged: (_) => setState(() {})),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Btn(
                ctx.m('deskPinSave'),
                icon: LucideIcons.lock,
                small: true,
                busy: _busy,
                onTap: ro || _busy || !RegExp(r'^\d{4,8}$').hasMatch(_pin.text) ? null : () => _save({'pin': _pin.text}, ctx.m('deskPinSaved')),
              ),
              if (d['has_pin'] == true)
                Btn(ctx.m('deskLogoutAll'), icon: LucideIcons.logOut, kind: BtnKind.ghost, small: true, onTap: ro || _busy ? null : () => _save({'logout_all': true}, ctx.m('deskLoggedOut'))),
            ],
          ),
        ]),
        scGap,
        scPanel([
          scTitle(context, ctx.m('deskLink')),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.line),
              ),
              child: QrImageView(data: url, size: 190, padding: EdgeInsets.zero, backgroundColor: Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            url,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Btn(
                ctx.m('deskOpen'),
                icon: LucideIcons.externalLink,
                kind: BtnKind.ghost,
                small: true,
                onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
              ),
              Btn(ctx.m('copyLink'), icon: LucideIcons.copy, kind: BtnKind.ghost, small: true, onTap: () => scCopy(ctx, url)),
              Btn(
                ctx.t('app.share'),
                icon: LucideIcons.share2,
                kind: BtnKind.ghost,
                small: true,
                onTap: () => SharePlus.instance.share(ShareParams(text: '${ctx.m('deskTitle')} · ${ctx.shopName}\n$url')),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Muted(ctx.m('deskHow'), align: TextAlign.center),
        ]),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ TELEGRAM
class TelegramTab extends StatefulWidget {
  final ScCtx ctx;
  const TelegramTab({super.key, required this.ctx});
  @override
  State<TelegramTab> createState() => _TelegramTabState();
}

class _TelegramTabState extends State<TelegramTab> {
  ScCtx get ctx => widget.ctx;
  late Json _tg = obj(ctx.data['telegram']);
  String _busy = '';
  bool _waiting = false;

  Future<void> _link(bool group) async {
    setState(() => _busy = 'link');
    final r = await ctx.run(() => ctx.api.post('${ctx.base}/telegram/link'));
    if (r != null) {
      final d = obj(r['data']);
      final u = str(group ? d['group_url'] : d['url']);
      if (u.isNotEmpty) await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
      if (mounted) setState(() => _waiting = true);
    }
    if (mounted) setState(() => _busy = '');
  }

  Future<void> _save(Map<String, Object?> body) async {
    final r = await ctx.run(() => ctx.api.put('${ctx.base}/telegram', body));
    if (r != null && mounted) setState(() => _tg = obj(r['data']));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (!ctx.on('sc_telegram')) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [ScLocked(ctx: ctx, addon: 'sc_telegram')],
      );
    }
    final ro = ctx.readOnly;
    final tg = _tg;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        scHead(context, LucideIcons.send, ctx.m('tgTitle'), ctx.m('tgSub')),
        scGap,
        scPanel([
          if (tg['configured'] == false)
            Muted(ctx.m('tgNotReady'))
          else if (tg['connected'] == true) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Chip2(ctx.m('tgConnected', {'name': tg['chat_name']}), icon: LucideIcons.check, tone: Tone.good),
            ),
            SwitchRow(title: ctx.m('tgReward'), value: tg['reward'] == true, onChanged: ro ? null : (v) => _save({'reward': v})),
            SwitchRow(title: ctx.m('tgJoined'), value: tg['joined'] == true, onChanged: ro ? null : (v) => _save({'joined': v})),
            SwitchRow(title: ctx.m('tgDaily'), value: tg['daily'] == true, onChanged: ro ? null : (v) => _save({'daily': v})),
            if (tg['daily'] == true)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(ctx.m('tgTime'), style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: Text(
                  str(tg['time']).isEmpty ? '20:00' : str(tg['time']),
                  style: TextStyle(fontWeight: FontWeight.w800, color: c.brand),
                ),
                onTap: ro
                    ? null
                    : () async {
                        final parts = (str(tg['time']).isEmpty ? '20:00' : str(tg['time'])).split(':');
                        final pick = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: int.tryParse(parts[0]) ?? 20, minute: int.tryParse(parts.last) ?? 0),
                        );
                        if (pick != null) _save({'time': '${pick.hour.toString().padLeft(2, '0')}:${pick.minute.toString().padLeft(2, '0')}'});
                      },
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Btn(
                  ctx.m('tgTest'),
                  icon: LucideIcons.send,
                  small: true,
                  busy: _busy == 'test',
                  onTap: ro || _busy.isNotEmpty
                      ? null
                      : () async {
                          setState(() => _busy = 'test');
                          await ctx.run(() => ctx.api.post('${ctx.base}/telegram/test'), ctx.m('tgSentOk'));
                          if (mounted) setState(() => _busy = '');
                        },
                ),
                Btn(
                  ctx.m('tgOff'),
                  icon: LucideIcons.unplug,
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: ro || _busy.isNotEmpty
                      ? null
                      : () async {
                          final r = await ctx.run(() => ctx.api.delete('${ctx.base}/telegram'));
                          if (r != null && mounted) setState(() => _tg = obj(r['data']));
                        },
                ),
              ],
            ),
          ] else ...[
            Btn(ctx.m('tgConnect'), icon: LucideIcons.send, busy: _busy == 'link', onTap: ro || _busy.isNotEmpty ? null : () => _link(false)),
            const SizedBox(height: 8),
            Btn(ctx.m('tgGroup'), icon: LucideIcons.users, kind: BtnKind.ghost, onTap: ro || _busy.isNotEmpty ? null : () => _link(true)),
            if (_waiting) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: Muted(ctx.m('tgWaiting'))),
                  IconButton(
                    onPressed: () async {
                      await ctx.reload();
                      if (mounted) setState(() => _tg = obj(ctx.data['telegram']));
                    },
                    icon: const Icon(LucideIcons.rotateCcw, size: 18),
                  ),
                ],
              ),
            ],
          ],
        ]),
        scGap,
        scPanel([Muted(ctx.m('tgCustomers'))]),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ ADD-ONS
class AddonsTab extends StatelessWidget {
  final ScCtx ctx;
  const AddonsTab({super.key, required this.ctx});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final lic = ctx.license;
    final addons = obj(ctx.data['addons']);
    Widget card(IconData icon, String name, String price, String what, List<Widget> foot, {bool on = false}) => Panel(
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
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        scHead(context, LucideIcons.puzzle, ctx.m('addonsTitle'), ctx.m('addonsSub')),
        scGap,
        card(LucideIcons.stamp, ctx.m('renewTitle'), '${fmt(n(lic['price']))} ${ctx.m('coins')} ${ctx.m('perYear')}', ctx.m('baseWhat'), [
          Chip2(
            lic['expires_at'] != null ? ctx.m('endsOn', {'date': scDate(lic['expires_at'], ctx.lang)}) : ctx.m('unlocked'),
            icon: LucideIcons.check,
            tone: lic['active'] == true ? Tone.good : Tone.muted,
          ),
          Btn(ctx.m('renewFor', {'coins': fmt(n(lic['price']))}), kind: BtnKind.ghost, small: true, onTap: ctx.business['status'] == false ? null : () => ctx.askBuy('renew')),
        ], on: lic['active'] == true),
        for (final e in addons.entries) ...[
          scGap,
          () {
            final a = obj(e.value);
            final k = e.key;
            final yearly = a['days'] != null;
            final active = a['active'] == true;
            return card(
              scAddonIcons[k] ?? LucideIcons.puzzle,
              ctx.m('addonNames.$k'),
              '${fmt(n(a['price']))} ${ctx.m('coins')} ${yearly ? ctx.m('perYear') : '· ${ctx.m('forever')}'}',
              ctx.m('addonWhat.$k'),
              active
                  ? [
                      Chip2(a['expires_at'] != null ? ctx.m('endsOn', {'date': scDate(a['expires_at'], ctx.lang)}) : ctx.m('unlocked'), icon: LucideIcons.check, tone: Tone.good),
                      if (yearly) Btn(ctx.m('renewFor', {'coins': fmt(n(a['price']))}), kind: BtnKind.ghost, small: true, onTap: ctx.readOnly ? null : () => ctx.askBuy(k)),
                    ]
                  : [
                      GoldBtn(ctx.m('unlock', {'coins': fmt(n(a['price']))}), onTap: ctx.readOnly ? null : () => ctx.askBuy(k)),
                    ],
              on: active,
            );
          }(),
        ],
      ],
    );
  }
}
