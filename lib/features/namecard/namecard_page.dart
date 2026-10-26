import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:dio/dio.dart' show DioMediaType, FormData, MultipartFile;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/buy_sheet.dart';
import '../../widgets/look_sheet.dart';
import '../../widgets/ui.dart';
import '../owner/data.dart';
import 'nc_card.dart';
import 'pf_view.dart';

part 'pf_editor.dart';

// Digital name card editor — the app version of the web's NameCardEditor.jsx (same API, same words).
//   GET/PUT /api/user/businesses/:id/namecard · POST/DELETE …/namecard/image · POST …/namecard/unlock
//   GET /api/user/namecard/slug-check
const _contactKeys = ['phone1', 'phone2', 'email', 'website', 'telegram', 'facebook'];
const _textKeys = ['name', 'job_title', 'company', 'bio', ..._contactKeys, 'address', 'slug'];
final _slugRe = RegExp(r'^[a-z0-9](?:[a-z0-9-]{1,28}[a-z0-9])$');
const _maxExtras = 6;

class NameCardPage extends ConsumerStatefulWidget {
  final String id;
  final String title;
  final String tab; // "portfolio" opens that tab
  const NameCardPage({super.key, required this.id, this.title = '', this.tab = ''});
  @override
  ConsumerState<NameCardPage> createState() => _NameCardPageState();
}

class _Extra {
  final TextEditingController label, value;
  _Extra(String l, String v) : label = TextEditingController(text: l), value = TextEditingController(text: v);
  void dispose() {
    label.dispose();
    value.dispose();
  }
}

class _NameCardPageState extends ConsumerState<NameCardPage> {
  Json? _card; // saved
  Json _business = {};
  List<String> _free = freeThemes, _premium = premiumThemes;
  num _price = 15;
  final _themeTick = ValueNotifier(0); // the theme gallery redraws on changes (picked / unlocked)
  Json _licenses = {};
  String _error = '';
  bool _saving = false;
  String _uploading = ''; // photo | cover
  String _slugState = ''; // ok | taken | bad
  Timer? _slugTimer;
  late int _tab = widget.tab == 'portfolio' ? 1 : 0;
  bool _pfSeen = false;

  final _c = {for (final k in _textKeys) k: TextEditingController()};
  final List<_Extra> _extras = [];
  String _theme = 'classic', _color = '#E0581A';
  bool _published = true;

  String get _base => '${Api.user}/businesses/${widget.id}/namecard';
  T get t => ref.read(tProvider);

  @override
  void initState() {
    super.initState();
    for (final k in _textKeys) {
      _c[k]!.addListener(_changed);
    }
    _c['slug']!.addListener(_checkSlug);
    _load();
  }

  @override
  void dispose() {
    _themeTick.dispose();
    _slugTimer?.cancel();
    for (final x in _c.values) {
      x.dispose();
    }
    for (final x in _extras) {
      x.dispose();
    }
    super.dispose();
  }

  void _changed() => mounted ? setState(() {}) : null;

  Future<void> _load() async {
    setState(() => _error = '');
    try {
      final r = await ref.read(apiProvider).get(_base);
      final themes = obj(r['themes']);
      setState(() {
        _business = obj(r['business']);
        if (themes['free'] is List) _free = (themes['free'] as List).map((e) => '$e').toList();
        if (themes['premium'] is List) _premium = (themes['premium'] as List).map((e) => '$e').toList();
        if (themes['price'] != null) _price = n(themes['price']);
        _licenses = obj(r['licenses']);
      });
      _fill(obj(r['data']));
    } on ApiError catch (e) {
      setState(() => _error = e.network ? t('app.offline') : (e.message.isNotEmpty ? e.message : t('card.loadFail')));
    }
  }

  // saved card → form
  void _fill(Json card) {
    _card = card;
    for (final k in _textKeys) {
      _c[k]!.text = str(card[k]);
    }
    for (final x in _extras) {
      x.dispose();
    }
    _extras
      ..clear()
      ..addAll(objs(card['extras']).map((x) => _Extra(str(x['label']), str(x['value'])))..forEach(_listen));
    _theme = str(card['theme']).isEmpty ? 'classic' : str(card['theme']);
    _color = str(card['color']).isEmpty ? '#E0581A' : str(card['color']).toUpperCase();
    _published = card['published'] != false;
    _slugState = 'ok';
    setState(() {});
  }

  void _listen(_Extra x) {
    x.label.addListener(_changed);
    x.value.addListener(_changed);
  }

  Json get _form => {
    for (final k in _textKeys) k: _c[k]!.text,
    'theme': _theme,
    'color': _color,
    'published': _published,
    'extras': [
      for (final x in _extras) {'label': x.label.text, 'value': x.value.text},
    ],
  };

  Json _saved() {
    final card = _card ?? {};
    return {
      for (final k in _textKeys) k: str(card[k]),
      'theme': str(card['theme']).isEmpty ? 'classic' : str(card['theme']),
      'color': str(card['color']).toUpperCase(),
      'published': card['published'] != false,
      'extras': [
        for (final x in objs(card['extras'])) {'label': str(x['label']), 'value': str(x['value'])},
      ],
    };
  }

  bool get _dirty {
    if (_card == null) return false;
    final a = _form, b = _saved();
    for (final k in a.keys) {
      if ('${a[k]}' != '${b[k]}') return true;
    }
    return false;
  }

  List<String> get _unlocked => ((_card?['unlocked_themes'] as List?) ?? const []).map((e) => '$e').toList();
  bool _isLocked(String th) => _premium.contains(th) && !_unlocked.contains(th);
  bool get _suspended => _business.isNotEmpty && _business['status'] == false;
  String get _link => '${Config.siteUrl}/public/card/${str(_card?['slug'])}';

  void _checkSlug() {
    final card = _card;
    if (card == null) return;
    final slug = _c['slug']!.text.toLowerCase();
    _slugTimer?.cancel();
    if (slug == str(card['slug'])) return setState(() => _slugState = 'ok');
    if (!_slugRe.hasMatch(slug)) return setState(() => _slugState = 'bad');
    _slugTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final r = await ref.read(apiProvider).get('${Api.user}/namecard/slug-check', {'slug': slug, 'business_id': widget.id});
        final d = obj(r['data']);
        if (mounted && _c['slug']!.text.toLowerCase() == slug) {
          setState(() => _slugState = d['available'] == true ? 'ok' : (d['valid'] == true ? 'taken' : 'bad'));
        }
      } catch (_) {}
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final r = await ref.read(apiProvider).put(_base, {..._form, 'slug': _c['slug']!.text.toLowerCase()});
      _fill(obj(r['data']));
      if (mounted) toast(context, t('card.saved'));
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.status == 402 && e.body['theme'] != null) {
        _unlock(str(e.body['theme']), str(_card?['theme']));
      } else {
        toast(context, e.network ? t('app.offline') : e.message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _undo() => _fill(_card!);

  // tap a theme → the look sheet (big card, swipe for the others): Use picks it (then Save, like before) · Unlock pays coins
  Future<void> _chooseTheme(String th, {List<String>? themes, String? title}) async {
    if (_suspended) return;
    final list = themes ?? (_free.contains(th) ? _free : _premium);
    await showLookSheet(
      context,
      title: title ?? (_free.contains(th) ? t('card.theme') : t('card.premiumThemes')),
      count: list.length,
      initial: list.contains(th) ? list.indexOf(th) : 0,
      item: (context, i, refresh) {
        final x = list[i];
        final locked = _isLocked(x);
        final on = x == _theme;
        return LookItem(
          name: ncThemeName(t, x),
          badge: on ? t('looks.inUse') : (locked ? '${fmt(_price)} ${t('card.coins')}' : (_free.contains(x) ? t('card.freeThemes') : t('card.unlockedTag'))),
          badgeTone: locked ? Tone.warn : Tone.good,
          preview: SizedBox(
            width: 380,
            child: IgnorePointer(
              child: NcCard(card: {..._preview, 'theme': x}, fieldLabels: _fieldLabels, yourName: t('card.yourName'), viewPortfolio: t('card.viewPortfolio'), km: t.km),
            ),
          ),
          acts: [
            if (!locked && !on)
              LookAct(
                t('card.useTheme'),
                icon: LucideIcons.check,
                onTap: () async {
                  setState(() => _theme = x);
                  _themeTick.value++;
                  return true;
                },
              ),
            if (locked)
              LookAct(
                t('card.unlockFor', {'coins': fmt(_price)}),
                gold: true,
                onTap: () async {
                  final previous = _isLocked(_theme) ? str(_card?['theme']) : _theme;
                  Future.microtask(() => _unlock(x, previous));
                  return true;
                },
              ),
          ],
        );
      },
    );
  }

  // every theme in one sheet: filter chips + a grid of small cards → tap one for the big look sheet
  void _openGallery() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ValueListenableBuilder(
        valueListenable: _themeTick,
        builder: (context, _, _) => _ThemeGallery(
          themes: [..._free, ..._premium],
          current: _theme,
          preview: {..._preview, 'bio': ''},
          t: t,
          locked: _isLocked,
          price: _price,
          onPick: (th, list) => _chooseTheme(th, themes: list, title: t('ncr.all')),
        ),
      ),
    );
  }

  // premium theme: pay coins once (UnlockThemeModal on the web)
  Future<void> _unlock(String theme, String previous) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _UnlockSheet(businessId: widget.id, theme: theme, price: _price, preview: _preview, onUnlocked: (data) => setState(() => _card = {...?_card, 'unlocked_themes': data['unlocked_themes']})),
    );
    if (!mounted) return;
    _themeTick.value++;
    if (ok == true) {
      setState(() => _theme = theme);
    } else if (_isLocked(theme)) {
      setState(() => _theme = previous.isEmpty ? 'classic' : previous);
    }
  }

  Future<void> _pickImage(String kind) async {
    final src = await _source();
    if (src == null) return;
    final f = await ImagePicker().pickImage(source: src, maxWidth: kind == 'cover' ? 1600 : 800, imageQuality: 88);
    if (f == null) return;
    setState(() => _uploading = kind);
    try {
      final form = FormData.fromMap({'kind': kind, 'file': MultipartFile.fromBytes(await f.readAsBytes(), filename: '$kind.jpg')});
      final r = await ref.read(apiProvider).post('$_base/image', form);
      setState(() => _card = {...?_card, kind: obj(r['data'])[kind]});
      if (mounted) toast(context, t('card.saved'));
    } on ApiError catch (e) {
      if (mounted) toast(context, e.network ? t('app.offline') : e.message);
    } finally {
      if (mounted) setState(() => _uploading = '');
    }
  }

  Future<ImageSource?> _source() => showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(LucideIcons.image), title: Text(t('card.upload')), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
          ListTile(leading: const Icon(LucideIcons.camera), title: Text(t('app.takePhoto')), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
        ],
      ),
    ),
  );

  Future<void> _removeImage(String kind) async {
    setState(() => _uploading = kind);
    try {
      final r = await ref.read(apiProvider).delete('$_base/image', {'kind': kind});
      setState(() => _card = {...?_card, kind: obj(r['data'])[kind]});
    } on ApiError catch (e) {
      if (mounted) toast(context, e.network ? t('app.offline') : e.message);
    } finally {
      if (mounted) setState(() => _uploading = '');
    }
  }

  // what the card looks like right now (form + saved pictures)
  Json get _preview => {..._form, 'slug': str(_card?['slug']), 'photo': photoUrl(_card?['photo']), 'cover': photoUrl(_card?['cover']), 'portfolio': obj(_licenses['portfolio'])['active'] == true};

  Map<String, String> get _fieldLabels => {
    for (final k in [..._contactKeys, 'address']) k: t('card.fields.$k'),
  };

  void _openPreview() => Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _PreviewPage(card: _preview, labels: _fieldLabels, title: t('card.preview'), yourName: t('card.yourName'), viewPortfolio: t('card.viewPortfolio'), km: t.km),
    ),
  );

  Future<void> _shareQr() async {
    final painter = QrPainter(
      data: _link,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF16171B)),
      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF16171B)),
    );
    final data = await painter.toImageData(600, format: ui.ImageByteFormat.png);
    if (data == null) return;
    // white border around the code, like the web's download
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png', name: 'bizhub-card-${str(_card?['slug'])}.png')],
        text: _link,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final title = str(_business['name']).isNotEmpty ? str(_business['name']) : widget.title;
    final portfolio = obj(_licenses['portfolio']);

    Widget body;
    if (_error.isNotEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(20),
        child: LoadError(text: _error, retry: t('card.retry'), onRetry: _load),
      );
    } else if (_card == null) {
      body = const Padding(padding: EdgeInsets.all(20), child: SkelList(rows: 6));
    } else {
      // the portfolio tab stays alive once opened (its unsaved changes are kept when you switch tabs)
      if (_tab == 1) _pfSeen = true;
      body = IndexedStack(
        index: _tab,
        children: [
          _form0(t, c),
          _pfSeen
              ? _PortfolioTab(
                  businessId: widget.id,
                  card: _preview,
                  suspended: _suspended,
                  onLicense: (lic) => setState(() => _licenses = {..._licenses, 'portfolio': lic}),
                  onGoCard: () => setState(() => _tab = 0),
                )
              : const SizedBox.shrink(),
        ],
      );
    }

    return Scaffold(
      backgroundColor: c.appBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // top: back · business name · views
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  RoundBtn(LucideIcons.arrowLeft, size: 42, onTap: () => context.pop()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (_card != null)
                          Row(
                            children: [
                              Icon(LucideIcons.eye, size: 13, color: c.muted),
                              const SizedBox(width: 4),
                              Text('${fmt(n(_card!['views']))} ${t('card.views')}', style: TextStyle(color: c.muted, fontSize: 12.5)),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (_card != null && _tab == 0) RoundBtn(LucideIcons.eye, size: 42, tip: t('card.preview'), onTap: _openPreview),
                ],
              ),
            ),
            // tabs: Name card · Portfolio PRO
            if (_card != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: _Tabs(
                  index: _tab,
                  onTap: (i) => setState(() => _tab = i),
                  items: [(LucideIcons.idCard, t('card.tabCard'), null), (LucideIcons.briefcaseBusiness, t('card.tabPortfolio'), portfolio['active'] == true)],
                ),
              ),
            Expanded(child: body),
          ],
        ),
      ),
      bottomNavigationBar: _card == null || _tab != 0 ? null : _saveBar(t, c),
    );
  }

  // ------------------------------------------------------------------------------------------- the form
  Widget _form0(T t, C c) {
    final locked = _suspended;
    final preview = _preview;
    Widget field(String key, {String? label, String? hint, TextInputType? kb, int max = 80, int lines = 1}) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Field(label: label ?? t('card.$key'), hint: hint, controller: _c[key]!, keyboard: kb, maxLength: max, maxLines: lines, enabled: !locked),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (locked) ...[Alert(t('card.suspended')), const SizedBox(height: 14)],
        // ---------- theme ----------
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SecHead(t('card.theme'), trailing: Chip2(t('card.freeThemes'), tone: Tone.good)),
              _ThemeRow(themes: _free, current: _theme, preview: preview, t: t, onPick: _chooseTheme),
              const SizedBox(height: 18),
              // premium
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(colors: [c.brand.withValues(alpha: .08), c.brand2.withValues(alpha: .06)]),
                  border: Border.all(color: c.brand.withValues(alpha: .18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(LucideIcons.crown, size: 18, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t('card.premiumThemes'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              Text(t('card.premiumSub'), style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.4)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const CoinIcon(size: 18),
                        const SizedBox(width: 4),
                        Text(fmt(_price), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _ThemeRow(themes: _premium, current: _theme, preview: preview, t: t, onPick: _chooseTheme, locked: _isLocked, price: _price),
                    const SizedBox(height: 10),
                    Btn(t('ncr.seeAll', {'n': '${_free.length + _premium.length}'}), icon: LucideIcons.layoutGrid, kind: BtnKind.ghost, expand: true, onTap: _suspended ? null : _openGallery),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(t('card.color'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final col in cardColors) _Swatch(color: hexColor(col), on: _color.toUpperCase() == col, onTap: locked ? null : () => setState(() => _color = col)),
                  _CustomColor(
                    label: t('card.customColor'),
                    color: hexColor(_color),
                    on: !cardColors.contains(_color.toUpperCase()),
                    onPick: locked
                        ? null
                        : () async {
                            final picked = await _pickColor(context, hexColor(_color), t);
                            if (picked != null) setState(() => _color = colorHex(picked));
                          },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // ---------- profile ----------
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SecHead(t('card.profile')),
              _ImageRow(
                label: t('card.photo'),
                url: photoUrl(_card!['photo']),
                round: true,
                busy: _uploading == 'photo',
                t: t,
                onPick: locked ? null : () => _pickImage('photo'),
                onRemove: () => _removeImage('photo'),
              ),
              const SizedBox(height: 12),
              _ImageRow(
                label: t('card.cover'),
                url: photoUrl(_card!['cover']),
                busy: _uploading == 'cover',
                t: t,
                onPick: locked ? null : () => _pickImage('cover'),
                onRemove: () => _removeImage('cover'),
              ),
              Padding(padding: const EdgeInsets.only(top: 8, bottom: 16), child: Muted(t('card.imageHint'))),
              field('name', max: 80),
              field('job_title', label: t('card.jobTitle')),
              field('company'),
              field('bio', hint: t('card.bioPh'), max: 500, lines: 4, label: '${t('card.bio')} · ${_c['bio']!.text.length}/500'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // ---------- contact ----------
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SecHead(t('card.contact'), sub: t('card.contactSub')),
              field('phone1', hint: t('card.phonePh'), kb: TextInputType.phone, max: 30),
              field('phone2', hint: t('card.phonePh'), kb: TextInputType.phone, max: 30),
              field('email', hint: 'you@example.com', kb: TextInputType.emailAddress, max: 120),
              field('website', hint: 'www.example.com', kb: TextInputType.url, max: 200),
              field('telegram', hint: t('card.telegramPh'), max: 60),
              field('facebook', hint: t('card.facebookPh'), kb: TextInputType.url, max: 200),
              field('address', max: 200, lines: 2),
              const SizedBox(height: 4),
              Text(t('card.more'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
              const SizedBox(height: 2),
              Muted(t('card.moreSub')),
              const SizedBox(height: 10),
              for (var i = 0; i < _extras.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Field(controller: _extras[i].label, hint: t('card.labelPh'), maxLength: 40, enabled: !locked),
                            const SizedBox(height: 6),
                            Field(controller: _extras[i].value, hint: t('card.valuePh'), maxLength: 200, enabled: !locked),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      RoundBtn(
                        LucideIcons.trash2,
                        size: 40,
                        tip: t('card.remove'),
                        fg: c.danger,
                        onTap: locked
                            ? null
                            : () => setState(() {
                                _extras.removeAt(i).dispose();
                              }),
                      ),
                    ],
                  ),
                ),
              if (_extras.length < _maxExtras)
                Btn(
                  t('card.addMore'),
                  icon: LucideIcons.plus,
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: locked
                      ? null
                      : () => setState(
                          () => _extras.add(
                            _Extra('', '')
                              ..label.addListener(_changed)
                              ..value.addListener(_changed),
                          ),
                        ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // ---------- link ----------
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SecHead(t('card.link')),
              Field(
                label: t('card.slugHint'),
                labelTrailing: _slugState.isEmpty || _c['slug']!.text == str(_card!['slug'])
                    ? null
                    : Chip2(_slugState == 'ok' ? t('card.slugOk') : (_slugState == 'taken' ? t('card.slugTaken') : t('card.slugBad')), tone: _slugState == 'ok' ? Tone.good : Tone.danger),
                controller: _c['slug']!,
                maxLength: 30,
                enabled: !locked,
                invalid: _slugState == 'taken' || _slugState == 'bad',
                keyboard: TextInputType.url,
                prefix: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 2),
                  child: Text(
                    '/public/card/',
                    style: TextStyle(color: c.muted, fontWeight: FontWeight.w600),
                  ),
                ),
                onChanged: (v) {
                  final clean = v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '');
                  if (clean != v) {
                    _c['slug']!.value = TextEditingValue(
                      text: clean,
                      selection: TextSelection.collapsed(offset: clean.length),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _published,
                onChanged: locked ? null : (v) => setState(() => _published = v),
                title: Text(t('card.published'), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(t('card.publishedHint'), style: TextStyle(color: c.muted, fontSize: 12.5)),
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: c.line),
                  ),
                  child: QrImageView(
                    data: _link,
                    size: 180,
                    padding: EdgeInsets.zero,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF16171B)),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF16171B)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(12)),
                child: SelectableText(
                  _link,
                  style: TextStyle(fontSize: 13, color: c.ink, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Btn(
                    t('card.openCard'),
                    icon: LucideIcons.externalLink,
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: () => launchUrl(Uri.parse(_link), mode: LaunchMode.externalApplication),
                  ),
                  Btn(
                    t('card.copyLink'),
                    icon: LucideIcons.copy,
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: _link));
                      if (mounted) toast(context, t('card.copied'));
                    },
                  ),
                  Btn(
                    t('card.share'),
                    icon: LucideIcons.share2,
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: () => SharePlus.instance.share(ShareParams(text: _link)),
                  ),
                  Btn(t('card.downloadQr'), icon: LucideIcons.download, kind: BtnKind.ghost, small: true, onTap: _shareQr),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // sticks to the bottom: unsaved changes · undo · save (or unlock)
  Widget _saveBar(T t, C c) {
    final dirty = _dirty;
    final lockedTheme = dirty && _isLocked(_theme);
    final canSave = dirty && !_saving && _slugState != 'taken' && _slugState != 'bad' && !_suspended;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Icon(dirty ? (lockedTheme ? LucideIcons.lock : LucideIcons.pencil) : LucideIcons.check, size: 16, color: dirty ? c.brandInk : c.good),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dirty ? (lockedTheme ? t('card.lockedSaveHint') : t('card.unsaved')) : t('card.allSaved'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: dirty ? c.ink : c.muted),
                ),
              ),
              if (dirty) ...[RoundBtn(LucideIcons.undo2, size: 40, tip: 'Undo', onTap: _saving ? null : _undo), const SizedBox(width: 8)],
              lockedTheme
                  ? Btn(t('card.unlockFor', {'coins': fmt(_price)}), small: true, lead: const CoinIcon(size: 16), onTap: () => _unlock(_theme, str(_card?['theme'])))
                  : Btn(_saving ? t('card.saving') : t('card.save'), small: true, busy: _saving, onTap: canSave ? _save : null),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================================ small pieces
class _Tabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<(IconData, String, bool?)> items; // bool? = portfolio active (null = no badge)
  const _Tabs({required this.index, required this.onTap, required this.items});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(999), boxShadow: c.cardShadow),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(color: index == i ? c.solid : Colors.transparent, borderRadius: BorderRadius.circular(999)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(items[i].$1, size: 16, color: index == i ? c.onSolid : c.muted),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          items[i].$2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: index == i ? c.onSolid : c.muted),
                        ),
                      ),
                      if (items[i].$3 != null) ...[
                        const SizedBox(width: 6),
                        items[i].$3!
                            ? Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: c.good, shape: BoxShape.circle),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFFFC53D), borderRadius: BorderRadius.circular(999)),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.crown, size: 10, color: Color(0xFF5B3A00)),
                                    SizedBox(width: 2),
                                    Text(
                                      'PRO',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF5B3A00)),
                                    ),
                                  ],
                                ),
                              ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  final List<String> themes;
  final String current;
  final Json preview;
  final T t;
  final ValueChanged<String> onPick;
  final bool Function(String)? locked;
  final num price;
  const _ThemeRow({required this.themes, required this.current, required this.preview, required this.t, required this.onPick, this.locked, this.price = 0});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 172,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: themes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final th = themes[i];
          final on = th == current;
          final isLocked = locked?.call(th) ?? false;
          final unlocked = locked != null && !isLocked;
          return _ThemeTile(th: th, on: on, isLocked: isLocked, unlocked: unlocked, preview: preview, t: t, price: price, onTap: () => onPick(th));
        },
      ),
    );
  }
}

// one small card in the theme row / the theme gallery (tap → the look sheet)
class _ThemeTile extends StatelessWidget {
  final String th;
  final bool on, isLocked, unlocked;
  final Json preview;
  final T t;
  final num price;
  final VoidCallback onTap;
  final double width;
  const _ThemeTile({required this.th, required this.on, required this.isLocked, required this.unlocked, required this.preview, required this.t, required this.price, required this.onTap, this.width = 102});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: on ? c.brand : Colors.transparent, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: width - 10,
                  height: (width - 10) * 130 / 92,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ColoredBox(
                          color: c.bg2,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: 420,
                              child: IgnorePointer(
                                child: NcCard(card: {...preview, 'bio': '', 'theme': th}, compact: true, km: t.km),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isLocked)
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: _Badge(
                            children: [
                              const Icon(LucideIcons.lock, size: 11, color: Colors.white),
                              const SizedBox(width: 3),
                              const CoinIcon(size: 12),
                              const SizedBox(width: 2),
                              Text(
                                fmt(price),
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      if (unlocked)
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: _Badge(
                            color: c.good,
                            children: [
                              const Icon(LucideIcons.crown, size: 11, color: Colors.white),
                              const SizedBox(width: 3),
                              Text(
                                t('card.unlockedTag'),
                                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (on) ...[Icon(LucideIcons.check, size: 13, color: c.brand), const SizedBox(width: 3)],
                Flexible(
                  child: Text(
                    ncThemeName(t, th),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: on ? c.brandInk : c.ink),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final List<Widget> children;
  final Color? color;
  const _Badge({required this.children, this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: color ?? Colors.black.withValues(alpha: .72), borderRadius: BorderRadius.circular(999)),
    child: Row(mainAxisSize: MainAxisSize.min, children: children),
  );
}

class _Swatch extends StatelessWidget {
  final Color color;
  final bool on;
  final VoidCallback? onTap;
  const _Swatch({required this.color, required this.on, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: on ? context.c.ink : Colors.transparent, width: 2.5),
        boxShadow: on ? [BoxShadow(color: color.withValues(alpha: .4), blurRadius: 10)] : null,
      ),
      child: on ? const Icon(LucideIcons.check, size: 18, color: Colors.white) : null,
    ),
  );
}

class _CustomColor extends StatelessWidget {
  final String label;
  final Color color;
  final bool on;
  final VoidCallback? onPick;
  const _CustomColor({required this.label, required this.color, required this.on, this.onPick});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 38,
        padding: const EdgeInsets.only(left: 4, right: 12),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? c.ink : c.line, width: on ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: on ? null : const SweepGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.cyan, Colors.blue, Colors.purple, Colors.red]),
                color: on ? color : null,
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// colour picker: hue + lightness sliders and a #hex box
Future<Color?> _pickColor(BuildContext context, Color start, T t) {
  var hsl = HSLColor.fromColor(start);
  final hex = TextEditingController(text: colorHex(start));
  return showModalBottomSheet<Color>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final c = ctx.c;
        final now = hsl.toColor();
        void update(HSLColor v) => set(() {
          hsl = v;
          hex.text = colorHex(v.toColor());
        });
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: now, borderRadius: BorderRadius.circular(16)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Field(
                      controller: hex,
                      maxLength: 7,
                      onChanged: (v) {
                        final h = v.startsWith('#') ? v : '#$v';
                        if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(h)) set(() => hsl = HSLColor.fromColor(hexColor(h)));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _GradientSlider(
                colors: [for (var h = 0; h <= 360; h += 60) HSLColor.fromAHSL(1, h.toDouble() % 360, .75, .5).toColor()],
                value: hsl.hue / 360,
                onChanged: (v) => update(hsl.withHue(v * 360 % 360).withSaturation(hsl.saturation < .2 ? .7 : hsl.saturation)),
              ),
              const SizedBox(height: 14),
              _GradientSlider(colors: [Colors.black, hsl.withLightness(.5).toColor(), Colors.white], value: hsl.lightness, onChanged: (v) => update(hsl.withLightness(v.clamp(.05, .95)))),
              const SizedBox(height: 22),
              Btn(t('card.save'), onTap: () => Navigator.pop(ctx, now)),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t('app.cancel'), style: TextStyle(color: c.muted)),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _GradientSlider extends StatelessWidget {
  final List<Color> colors;
  final double value;
  final ValueChanged<double> onChanged;
  const _GradientSlider({required this.colors, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) {
      void at(Offset p) => onChanged((p.dx / box.maxWidth).clamp(0.0, 1.0));
      return GestureDetector(
        onPanDown: (d) => at(d.localPosition),
        onPanUpdate: (d) => at(d.localPosition),
        child: SizedBox(
          height: 32,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(colors: colors),
                ),
              ),
              Positioned(
                left: (value.clamp(0.0, 1.0) * box.maxWidth - 14).clamp(0.0, box.maxWidth - 28),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 6)],
                    border: Border.all(color: Colors.black12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ImageRow extends StatelessWidget {
  final String label, url;
  final bool round, busy;
  final T t;
  final VoidCallback? onPick;
  final VoidCallback onRemove;
  const _ImageRow({required this.label, required this.url, this.round = false, required this.busy, required this.t, required this.onPick, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Container(
          width: round ? 56 : 84,
          height: 56,
          decoration: BoxDecoration(
            color: c.bg2,
            shape: round ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: round ? null : BorderRadius.circular(12),
            border: Border.all(color: c.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: url.isNotEmpty ? Image(image: netImage(url), fit: BoxFit.cover) : Icon(LucideIcons.imagePlus, size: 20, color: c.muted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        Btn(
          busy ? t('card.uploading') : (url.isNotEmpty ? t('card.change') : t('card.upload')),
          icon: LucideIcons.imagePlus,
          kind: BtnKind.ghost,
          small: true,
          busy: busy,
          onTap: busy ? null : onPick,
        ),
        if (url.isNotEmpty && !busy && onPick != null) ...[const SizedBox(width: 6), RoundBtn(LucideIcons.trash2, size: 38, tip: t('card.remove'), fg: c.danger, onTap: onRemove)],
      ],
    );
  }
}

class _PreviewPage extends StatelessWidget {
  final Json card;
  final Map<String, String> labels;
  final String title, yourName, viewPortfolio;
  final bool km;
  const _PreviewPage({required this.card, required this.labels, required this.title, required this.yourName, required this.viewPortfolio, required this.km});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.appBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  RoundBtn(LucideIcons.x, size: 42, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Center(
                  child: NcCard(
                    card: card,
                    fieldLabels: labels,
                    yourName: yourName,
                    viewPortfolio: viewPortfolio,
                    km: km,
                    onContact: (x) => launchUrl(Uri.parse(x.href), mode: LaunchMode.externalApplication),
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

// "Unlock {theme}" (UnlockThemeModal on the web): preview, perks, balance, pay once
class _UnlockSheet extends ConsumerStatefulWidget {
  final String businessId, theme;
  final num price;
  final Json preview;
  final void Function(Json data) onUnlocked;
  const _UnlockSheet({required this.businessId, required this.theme, required this.price, required this.preview, required this.onUnlocked});
  @override
  ConsumerState<_UnlockSheet> createState() => _UnlockSheetState();
}

class _UnlockSheetState extends ConsumerState<_UnlockSheet> {
  bool _busy = false, _done = false;
  String _error = '';

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final r = await ref.read(apiProvider).post('${Api.user}/businesses/${widget.businessId}/namecard/unlock', {'theme': widget.theme});
      widget.onUnlocked(obj(r['data']));
      if (r['balance'] is num) await ref.read(sessionProvider.notifier).patch({'coin_balance': r['balance']});
      coinsChanged(ref);
      setState(() => _done = true);
    } on ApiError catch (e) {
      setState(() => _error = e.network ? ref.read(tProvider)('app.offline') : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final name = ncThemeName(t, widget.theme);
    final balance = ref.watch(sessionProvider)?.coins ?? 0;
    final short = balance < widget.price;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 150,
                height: 210,
                child: FittedBox(
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 420,
                    child: NcCard(card: {...widget.preview, 'theme': widget.theme}, compact: true, km: t.km),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _done ? t('card.unlockedTitle') : t('card.unlockTitle', {'theme': name}),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            _done ? t('card.unlockedSub', {'theme': name}) : t('card.unlockSub'),
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, height: 1.5),
          ),
          if (!_done) ...[
            const SizedBox(height: 14),
            for (final p in t.list('card.unlockPerks'))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(LucideIcons.circleCheck, size: 16, color: c.good),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(p, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [_Line(t('card.yourBalance'), fmt(balance)), const SizedBox(height: 6), _Line(t('card.afterUnlock'), short ? '—' : fmt(balance - widget.price), strong: true)]),
            ),
            if (short) ...[
              const SizedBox(height: 12),
              Alert(t('card.notEnough', {'coins': fmt(widget.price - balance)})),
            ],
            if (_error.isNotEmpty) ...[const SizedBox(height: 12), Alert(_error)],
            const SizedBox(height: 18),
            short
                ? Btn(
                    t('card.topUp'),
                    icon: LucideIcons.plus,
                    expand: true,
                    onTap: () {
                      Navigator.pop(context, false);
                      context.push('/o/coins');
                    },
                  )
                : Btn(t(_busy ? 'card.unlocking' : 'card.unlockFor', {'coins': fmt(widget.price)}), lead: const CoinIcon(size: 18), expand: true, busy: _busy, onTap: _go),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context, false),
              child: Text(t('card.maybeLater'), style: TextStyle(color: c.muted)),
            ),
          ] else ...[
            const SizedBox(height: 18),
            Btn(t('card.useTheme'), expand: true, onTap: () => Navigator.pop(context, true)),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label, value;
  final bool strong;
  const _Line(this.label, this.value, {this.strong = false});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(label, style: TextStyle(color: context.c.muted)),
      ),
      const CoinIcon(size: 16),
      const SizedBox(width: 4),
      Text(value, style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w600)),
    ],
  );
}

// a theme's shown name: the web texts (old themes) or the recipe list (the 100 new ones)
String ncThemeName(T t, String th) => t.maybe('card.themeNames.$th') ?? cardRecipes[th]?.name(t.km) ?? th;

// which gallery filters a theme belongs to (light / dark / color, serif, mono)
const _oldThemeGroups = <String, List<String>>{
  'modern': ['dark'],
  'aurora': ['dark'],
  'neon': ['dark'],
  'luxury': ['dark', 'serif'],
  'tech': ['dark', 'mono'],
  'bold': ['color'],
  'gradient': ['color'],
  'glass': ['color'],
  'sunset': ['color'],
  'elegant': ['light', 'serif'],
  'nature': ['light', 'serif'],
};

List<String> _groupsOf(String th) {
  final r = cardRecipes[th];
  if (r == null) return _oldThemeGroups[th] ?? const ['light'];
  return [ncRecipeTone(th), if (r['ft'] == 'serif') 'serif', if (r['ft'] == 'mono') 'mono'];
}

class _ThemeGallery extends StatefulWidget {
  final List<String> themes;
  final String current;
  final Json preview;
  final T t;
  final bool Function(String) locked;
  final num price;
  final Future<void> Function(String theme, List<String> list) onPick;
  const _ThemeGallery({required this.themes, required this.current, required this.preview, required this.t, required this.locked, required this.price, required this.onPick});
  @override
  State<_ThemeGallery> createState() => _ThemeGalleryState();
}

class _ThemeGalleryState extends State<_ThemeGallery> {
  String _f = 'all';

  bool _in(String th, String f) => switch (f) {
    'all' => true,
    'owned' => !widget.locked(th),
    _ => _groupsOf(th).contains(f),
  };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = widget.t;
    final list = widget.themes.where((th) => _in(th, _f)).toList();
    const filters = ['all', 'light', 'dark', 'color', 'serif', 'mono', 'owned'];
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .9,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(t('ncr.all'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                ),
                const CoinIcon(size: 16),
                const SizedBox(width: 4),
                Text(fmt(widget.price), style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: _f == f ? c.solid : c.card,
                      shape: StadiumBorder(side: BorderSide(color: _f == f ? c.solid : c.line)),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: () => setState(() => _f = f),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              Text(
                                t('ncr.f.$f'),
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: _f == f ? c.onSolid : c.ink),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${widget.themes.where((th) => _in(th, f)).length}',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _f == f ? c.onSolid.withValues(alpha: .7) : c.muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text(t('ncr.none'), style: TextStyle(color: c.muted)),
                  )
                : LayoutBuilder(
                    builder: (context, box) {
                      final cols = box.maxWidth >= 600 ? 5 : 3;
                      final w = (box.maxWidth - 32 - (cols - 1) * 10) / cols;
                      return GridView.builder(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).padding.bottom),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 12, childAspectRatio: w / ((w - 10) * 130 / 92 + 10 + 30)),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final th = list[i];
                          final locked = widget.locked(th);
                          return _ThemeTile(
                            th: th,
                            on: th == widget.current,
                            isLocked: locked,
                            unlocked: !locked && !freeThemes.contains(th),
                            preview: widget.preview,
                            t: t,
                            price: widget.price,
                            width: w,
                            onTap: () => widget.onPick(th, list),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
