part of 'namecard_page.dart';

// Portfolio tab — the app version of the web's PortfolioEditor.jsx (same API, same words).
//   GET/PUT /api/user/businesses/:id/portfolio · POST …/portfolio/unlock · POST/PATCH/DELETE …/portfolio/files
//   buy / renew: POST /api/user/businesses/:id/licenses/portfolio { expect }
class _ListSpec {
  final String key;
  final IconData icon;
  final int max;
  final List<(String, String, int, String?)> fields; // field, label key (pf.f.*), max length, placeholder key
  final String? flag; // "current"
  final (String, String, int)? text; // long text: field, label key, max
  const _ListSpec(this.key, this.icon, this.max, this.fields, {this.flag, this.text});
}

const _lists = [
  _ListSpec(
    'experience',
    LucideIcons.briefcaseBusiness,
    20,
    [('title', 'title', 80, null), ('company', 'company', 80, null), ('location', 'location', 80, null), ('start', 'start', 20, 'datePh'), ('end', 'end', 20, 'datePh')],
    flag: 'current',
    text: ('description', 'description', 1000),
  ),
  _ListSpec(
    'education',
    LucideIcons.graduationCap,
    20,
    [('school', 'school', 120, null), ('degree', 'degree', 120, null), ('field', 'field', 120, null), ('start', 'start', 20, 'datePh'), ('end', 'end', 20, 'datePh')],
    text: ('description', 'description', 600),
  ),
  _ListSpec('projects', LucideIcons.globe, 20, [('title', 'ptitle', 100, null), ('link', 'link', 200, null)], text: ('description', 'pdesc', 600)),
  _ListSpec('certifications', LucideIcons.award, 20, [('name', 'name', 120, null), ('issuer', 'issuer', 120, null), ('year', 'year', 20, null), ('link', 'link', 200, null)]),
  _ListSpec('languages', LucideIcons.languages, 10, [('name', 'lang', 40, null), ('level', 'level', 40, 'levelPh')]),
];

// one row of a list: a text box per field (+ the "I work here now" switch)
class _Row {
  final Map<String, TextEditingController> c;
  bool flag;
  _Row(_ListSpec spec, Map src)
    : c = {for (final f in spec.fields) f.$1: TextEditingController(text: '${src[f.$1] ?? ''}'), if (spec.text != null) spec.text!.$1: TextEditingController(text: '${src[spec.text!.$1] ?? ''}')},
      flag = src[spec.flag] == true;
  Json value(_ListSpec spec) => {for (final e in c.entries) e.key: e.value.text, if (spec.flag != null) spec.flag!: flag};
  void listen(VoidCallback f) {
    for (final x in c.values) {
      x.addListener(f);
    }
  }

  void dispose() {
    for (final x in c.values) {
      x.dispose();
    }
  }
}

class _PortfolioTab extends ConsumerStatefulWidget {
  final String businessId;
  final Json card; // the name card as it looks now (photo, colour, contacts…)
  final bool suspended;
  final void Function(Json license) onLicense;
  final VoidCallback onGoCard;
  const _PortfolioTab({required this.businessId, required this.card, required this.suspended, required this.onLicense, required this.onGoCard});
  @override
  ConsumerState<_PortfolioTab> createState() => _PortfolioTabState();
}

class _PortfolioTabState extends ConsumerState<_PortfolioTab> {
  Json? _saved; // what the server has (same shape as _form)
  Json _license = {};
  num _price = 50, _themePrice = 20;
  List<String> _free = pfFreeThemes, _premium = pfPremiumThemes, _unlocked = [];
  List<Json> _files = [];
  String _error = '';
  bool _saving = false, _uploading = false;
  String _confirmFile = '';

  String _theme = 'classic', _color = '';
  bool _published = true;
  final _headline = TextEditingController(), _about = TextEditingController(), _skill = TextEditingController();
  List<String> _skills = [];
  final Map<String, List<_Row>> _rows = {for (final l in _lists) l.key: []};

  String get _base => '${Api.user}/businesses/${widget.businessId}/portfolio';
  T get t => ref.read(tProvider);

  @override
  void initState() {
    super.initState();
    _headline.addListener(_changed);
    _about.addListener(_changed);
    _load();
  }

  @override
  void dispose() {
    _headline.dispose();
    _about.dispose();
    _skill.dispose();
    for (final list in _rows.values) {
      for (final r in list) {
        r.dispose();
      }
    }
    super.dispose();
  }

  void _changed() => mounted ? setState(() {}) : null;

  Future<void> _load() async {
    setState(() => _error = '');
    try {
      final r = await ref.read(apiProvider).get(_base);
      final themes = obj(r['themes']);
      final data = obj(r['data']);
      setState(() {
        _license = obj(r['license']);
        _price = n(r['price']);
        if (themes['free'] is List) _free = (themes['free'] as List).map((e) => '$e').toList();
        if (themes['premium'] is List) _premium = (themes['premium'] as List).map((e) => '$e').toList();
        if (themes['price'] != null) _themePrice = n(themes['price']);
        _unlocked = ((data['unlocked_themes'] as List?) ?? const []).map((e) => '$e').toList();
        _files = objs(data['files']);
      });
      widget.onLicense(_license);
      _fill(data);
    } on ApiError catch (e) {
      setState(() => _error = e.network ? t('app.offline') : (e.message.isNotEmpty ? e.message : t('pf.loadFail')));
    }
  }

  static Json _pick(Json d) => {
    'theme': str(d['theme']).isEmpty ? 'classic' : str(d['theme']),
    'color': str(d['color']),
    'headline': str(d['headline']),
    'about': str(d['about']),
    'skills': ((d['skills'] as List?) ?? const []).map((e) => '$e').toList(),
    'published': d['published'] != false,
    for (final l in _lists)
      l.key: [
        for (final r in objs(d[l.key])) {for (final f in l.fields) f.$1: str(r[f.$1]), if (l.text != null) l.text!.$1: str(r[l.text!.$1]), if (l.flag != null) l.flag!: r[l.flag] == true},
      ],
  };

  void _fill(Json data) {
    final p = _pick(data);
    _saved = p;
    _theme = p['theme'];
    _color = p['color'];
    _published = p['published'];
    _headline.text = p['headline'];
    _about.text = p['about'];
    _skills = List<String>.from(p['skills']);
    for (final l in _lists) {
      for (final r in _rows[l.key]!) {
        r.dispose();
      }
      _rows[l.key] = [for (final src in (p[l.key] as List)) _Row(l, src as Map)..listen(_changed)];
    }
    setState(() {});
  }

  Json get _form => {
    'theme': _theme,
    'color': _color,
    'headline': _headline.text,
    'about': _about.text,
    'skills': _skills,
    'published': _published,
    for (final l in _lists) l.key: [for (final r in _rows[l.key]!) r.value(l)],
  };

  bool get _dirty {
    final s = _saved;
    if (s == null) return false;
    final f = _form;
    return f.keys.any((k) => jsonEncode(f[k]) != jsonEncode(s[k]));
  }

  bool _locked(String th) => _premium.contains(th) && !_unlocked.contains(th);
  bool get _active => _license['active'] == true;
  String get _slug => str(widget.card['slug']);
  String get _link => '${Config.siteUrl}/public/portfolio/$_slug';
  Json get _preview => {..._form, 'files': _files};

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final r = await ref.read(apiProvider).put(_base, _form);
      _fill(obj(r['data']));
      if (mounted) toast(context, t('pf.saved'));
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.status == 402 && e.body['theme'] != null) {
        _unlockTheme(str(e.body['theme']), str(_saved?['theme']));
      } else {
        if (e.status == 402) _load();
        toast(context, e.network ? t('app.offline') : e.message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // tap a theme → the look sheet (big page, swipe for the others): Use picks it (then Save, like before) · Unlock pays coins
  String _themeName(String x) => pfRecipeName(x, t.km) ?? t.or('pf.themeNames.$x', x);
  List<String> get _oldPremium => _premium.where((x) => !pfRecipes0(x)).toList();
  List<String> get _recipeKeys => _premium.where(pfRecipes0).toList();

  void _chooseTheme(String th, {List<String>? among}) {
    if (widget.suspended) return;
    final list = among ?? (_free.contains(th) ? _free : _oldPremium);
    showLookSheet(
      context,
      title: _free.contains(th) ? t('pf.theme') : t('pf.premiumThemes'),
      count: list.length,
      initial: list.contains(th) ? list.indexOf(th) : 0,
      item: (context, i, refresh) {
        final x = list[i];
        final locked = _locked(x);
        final on = x == _theme;
        return LookItem(
          name: _themeName(x),
          badge: on ? t('looks.inUse') : (locked ? '${fmt(_themePrice)} ${t('pf.coins')}' : (_free.contains(x) ? t('pf.freeThemes') : t('pf.unlockedTag'))),
          badgeTone: locked ? Tone.warn : Tone.good,
          preview: _PfMini(data: {..._preview, 'theme': x}, card: widget.card, width: 300, height: 520),
          acts: [
            if (!locked && !on)
              LookAct(
                t('pf.useTheme'),
                icon: LucideIcons.check,
                onTap: () async {
                  setState(() => _theme = x);
                  return true;
                },
              ),
            if (locked)
              LookAct(
                t('pf.themeUnlockFor', {'coins': '${fmt(_themePrice)} ${t('pf.coins')}'}),
                gold: true,
                onTap: () async {
                  final previous = _locked(_theme) ? str(_saved?['theme']) : _theme;
                  Future.microtask(() => _unlockTheme(x, previous));
                  return true;
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _unlockTheme(String theme, String previous) async {
    final name = _themeName(theme);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BuySheet(
        stage: _PfMini(data: {..._preview, 'theme': theme}, card: widget.card, width: 150, height: 210),
        title: t('pf.themeTitle', {'theme': name}),
        sub: t('pf.themeModalSub'),
        perks: t.list('pf.themePerks'),
        price: _themePrice,
        buyLabel: t('pf.themeUnlockFor', {'coins': '${fmt(_themePrice)} ${t('pf.coins')}'}),
        doneTitle: '${t('pf.unlockedTag')}!',
        doneSub: t('pf.themeDone', {'theme': name}),
        doneButton: t('pf.useTheme'),
        buy: () => ref.read(apiProvider).post('$_base/unlock', {'theme': theme}),
        onDone: (r) => setState(() => _unlocked = ((obj(r['data'])['unlocked_themes'] as List?) ?? _unlocked).map((e) => '$e').toList()),
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      setState(() => _theme = theme);
    } else if (_locked(theme)) {
      setState(() => _theme = previous.isEmpty ? 'classic' : previous);
    }
  }

  // buy / renew one year (PurchaseModal on the web)
  Future<void> _buy() async {
    final active = _active;
    final expired = str(_license['status']) == 'expired';
    final until = fmtDate(_license['expires_at'], lang: t.lang);
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BuySheet(
        stage: _Mock(card: widget.card),
        badge: t('pf.promoBadge'),
        title: active ? t('pf.renewTitle') : t('pf.buyTitle'),
        sub: active ? t('pf.renewSub', {'date': until}) : t('pf.buySub'),
        perks: active ? const [] : [for (final p in t.list('pf.promoPerks')) p.replaceAll('{link}', '/portfolio/$_slug')],
        price: _price,
        buyLabel: t(active || expired ? 'pf.renewFor' : 'pf.unlockFor', {'coins': '${fmt(_price)} ${t('pf.coins')}'}),
        doneTitle: active ? t('pf.renewTitle') : t('pf.doneTitle'),
        doneSub: active ? '' : t('pf.doneSub'),
        doneSubOf: active ? (r) => t('pf.renewDone', {'date': fmtDate(obj(r['data'])['expires_at'], lang: t.lang)}) : null,
        doneButton: active ? t('app.continue') : t('pf.start'),
        buy: () => ref.read(apiProvider).post('${Api.user}/businesses/${widget.businessId}/licenses/portfolio', {'expect': _license['expires_at']}),
        onDone: (r) {
          final lic = obj(r['data']);
          if (lic.isNotEmpty) {
            setState(() => _license = lic);
            widget.onLicense(lic);
          } else {
            _load();
          }
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------------------- files
  Future<void> _addFile() async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(LucideIcons.image), title: Text(t('card.upload')), onTap: () => Navigator.pop(ctx, 'photo')),
            ListTile(leading: const Icon(LucideIcons.camera), title: Text(t('app.takePhoto')), onTap: () => Navigator.pop(ctx, 'camera')),
            ListTile(leading: const Icon(LucideIcons.fileText), title: const Text('PDF'), onTap: () => Navigator.pop(ctx, 'pdf')),
          ],
        ),
      ),
    );
    if (kind == null) return;
    List<int>? bytes;
    String name = 'file';
    String type = 'image/jpeg';
    if (kind == 'pdf') {
      final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf']);
      if (f == null) return;
      bytes = await f.xFile.readAsBytes();
      name = f.name;
      type = 'application/pdf';
    } else {
      // photos of certificates: sharp but small (like the web: 2000 px, 85 %)
      final f = await ImagePicker().pickImage(source: kind == 'camera' ? ImageSource.camera : ImageSource.gallery, maxWidth: 2000, imageQuality: 85);
      if (f == null) return;
      bytes = await f.readAsBytes();
      name = '${f.name.replaceFirst(RegExp(r'\.[^.]+$'), '')}.jpg';
    }
    if (bytes.length > 4 * 1024 * 1024) {
      if (mounted) toast(context, t('pf.tooBig'));
      return;
    }
    setState(() => _uploading = true);
    try {
      final title = name.replaceFirst(RegExp(r'\.[^.]+$'), '');
      final form = FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: name, contentType: DioMediaType.parse(type)), 'title': title.length > 80 ? title.substring(0, 80) : title});
      final r = await ref.read(apiProvider).post('$_base/files', form);
      setState(() => _files = objs(r['data']));
    } on ApiError catch (e) {
      if (mounted) toast(context, e.network ? t('app.offline') : e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _renameFile(Json f, String title) async {
    if (title.trim() == str(f['title'])) return;
    try {
      final r = await ref.read(apiProvider).patch('$_base/files/${f['_id']}', {'title': title.trim()});
      setState(() => _files = objs(r['data']));
    } on ApiError catch (e) {
      if (mounted) toast(context, e.network ? t('app.offline') : e.message);
    }
  }

  Future<void> _deleteFile(Json f) async {
    try {
      final r = await ref.read(apiProvider).delete('$_base/files/${f['_id']}');
      setState(() {
        _files = objs(r['data']);
        _confirmFile = '';
      });
    } on ApiError catch (e) {
      if (mounted) toast(context, e.network ? t('app.offline') : e.message);
    }
  }

  void _openPreview() => Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => Scaffold(
        backgroundColor: ctx.c.appBg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    RoundBtn(LucideIcons.x, size: 42, onTap: () => Navigator.pop(ctx)),
                    const SizedBox(width: 12),
                    Text(t('card.preview'), style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: PfView(
                    data: _preview,
                    card: widget.card,
                    t: t,
                    onLink: (u) => launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  // ------------------------------------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    if (_error.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: LoadError(text: _error, retry: t('pf.retry'), onRetry: _load),
      );
    }
    if (_saved == null) return const Padding(padding: EdgeInsets.all(20), child: SkelList(rows: 6));
    if (!_active) return _promo(t, c);
    return Column(
      children: [
        Expanded(child: _editor(t, c)),
        _saveBar(t, c),
      ],
    );
  }

  Widget _promo(T t, C c) {
    final expired = str(_license['status']) == 'expired';
    final until = fmtDate(_license['expires_at'], lang: t.lang);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _Mock(card: widget.card)),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFFC53D), borderRadius: BorderRadius.circular(999)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.crown, size: 13, color: Color(0xFF5B3A00)),
                    const SizedBox(width: 5),
                    Text(
                      t('pf.promoBadge'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF5B3A00)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(expired ? t('pf.expiredTitle') : t('pf.promoTitle'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(expired ? t('pf.expiredSub', {'date': until}) : t('pf.promoSub'), style: TextStyle(color: c.muted, height: 1.55)),
              const SizedBox(height: 14),
              for (final p in t.list('pf.promoPerks'))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(LucideIcons.check, size: 16, color: c.good),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(p.replaceAll('{link}', '/portfolio/$_slug'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Btn(t(expired ? 'pf.renewFor' : 'pf.unlockFor', {'coins': '${fmt(_price)} ${t('pf.coins')}'}), lead: const CoinIcon(size: 20), expand: true, onTap: widget.suspended ? null : _buy),
              const SizedBox(height: 10),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.calendarClock, size: 15, color: c.muted),
                    const SizedBox(width: 6),
                    Text(
                      t('pf.perYear', {'coins': fmt(_price)}),
                      style: TextStyle(color: c.muted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _editor(T t, C c) {
    final locked = widget.suspended;
    final status = str(_license['status']);
    final days = n(_license['days_left']);
    final pct = (days / 365).clamp(.03, 1.0).toDouble();
    final cardColor = hexColor(str(widget.card['color']));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ---------- status ----------
        Panel(
          color: status == 'expiring' ? c.warnBg : null,
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: status == 'expiring' ? c.warn : c.good, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(LucideIcons.calendarClock, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('pf.activeUntil', {'date': fmtDate(_license['expires_at'], lang: t.lang)}),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(status == 'expiring' ? t('pf.expiringSoon') : t('pf.daysLeft', {'n': fmt(days)}), style: TextStyle(color: c.muted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  Btn(t('pf.renew'), small: true, lead: const CoinIcon(size: 15), onTap: locked ? null : _buy),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: pct, minHeight: 6, color: status == 'expiring' ? c.warn : c.good, backgroundColor: c.bg2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // ---------- theme + colour ----------
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SecHead(
                t('pf.theme'),
                sub: t('pf.themeSub'),
                trailing: Chip2(t('pf.freeThemes'), tone: Tone.good),
              ),
              _PfThemeRow(themes: _free, current: _theme, data: _preview, card: widget.card, t: t, onPick: _chooseTheme),
              const SizedBox(height: 18),
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
                              Text(t('pf.premiumThemes'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              Text(t('pf.premiumSub'), style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.4)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const CoinIcon(size: 18),
                        const SizedBox(width: 4),
                        Text(fmt(_themePrice), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _PfThemeRow(themes: _oldPremium, current: _theme, data: _preview, card: widget.card, t: t, onPick: _chooseTheme, locked: _locked, price: _themePrice),
                  ],
                ),
              ),
              if (_recipeKeys.isNotEmpty) ...[
                const SizedBox(height: 18),
                _PfRecipeGallery(
                  keys: _recipeKeys,
                  current: _theme,
                  data: _preview,
                  card: widget.card,
                  t: t,
                  locked: _locked,
                  price: _themePrice,
                  onPick: (x, list) => _chooseTheme(x, among: list),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(LucideIcons.palette, size: 15, color: c.ink),
                  const SizedBox(width: 6),
                  Text(t('pf.color'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  GestureDetector(
                    onTap: locked ? null : () => setState(() => _color = ''),
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.only(left: 4, right: 12),
                      decoration: BoxDecoration(
                        color: c.bg2,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _color.isEmpty ? c.ink : c.line, width: _color.isEmpty ? 2 : 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(color: cardColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(t('pf.sameAsCard'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  for (final col in cardColors) _Swatch(color: hexColor(col), on: _color == col, onTap: locked ? null : () => setState(() => _color = col)),
                  _CustomColor(
                    label: t('pf.customColor'),
                    color: hexColor(_color.isEmpty ? str(widget.card['color']) : _color),
                    on: _color.isNotEmpty && !cardColors.contains(_color),
                    onPick: locked
                        ? null
                        : () async {
                            final picked = await _pickColor(context, hexColor(_color.isEmpty ? str(widget.card['color']) : _color), t);
                            if (picked != null) setState(() => _color = colorHex(picked));
                          },
                  ),
                ],
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
              SecHead(t('pf.link')),
              if (_slug.isNotEmpty) ...[
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
                      size: 170,
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
                      t('pf.open'),
                      icon: LucideIcons.externalLink,
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: () => launchUrl(Uri.parse(_link), mode: LaunchMode.externalApplication),
                    ),
                    Btn(
                      t('pf.copy'),
                      icon: LucideIcons.copy,
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: _link));
                        if (mounted) toast(context, t('pf.copied'));
                      },
                    ),
                    Btn(
                      t('pf.share'),
                      icon: LucideIcons.share2,
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: () => SharePlus.instance.share(ShareParams(text: _link)),
                    ),
                    Btn(t('pf.downloadQr'), icon: LucideIcons.download, kind: BtnKind.ghost, small: true, onTap: () => _shareQrOf(_link, 'bizhub-portfolio-$_slug.png')),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _published,
                onChanged: locked ? null : (v) => setState(() => _published = v),
                title: Text(t('pf.published'), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(t('pf.publishedHint'), style: TextStyle(color: c.muted, fontSize: 12.5)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // ---------- introduction ----------
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SecHead(t('pf.intro')),
              Row(
                children: [
                  Avatar(name: str(widget.card['name']), photo: str(widget.card['photo']), size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t('pf.photo'), style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(str(widget.card['photo']).isNotEmpty ? t('pf.photoHint') : t('pf.noPhoto'), style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.4)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Btn(t('pf.changePhoto'), kind: BtnKind.ghost, small: true, onTap: widget.onGoCard),
                ],
              ),
              const SizedBox(height: 16),
              Field(
                label: t('pf.headline'),
                controller: _headline,
                maxLength: 120,
                hint: str(widget.card['job_title']).isNotEmpty ? str(widget.card['job_title']) : t('pf.headlinePh'),
                enabled: !locked,
              ),
              const SizedBox(height: 14),
              Field(label: '${t('pf.about')} · ${_about.text.length}/2000', controller: _about, maxLength: 2000, maxLines: 5, hint: t('pf.aboutPh'), enabled: !locked),
              const SizedBox(height: 14),
              Text(
                '${t('pf.skills')} · ${_skills.length}/40',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: c.ink),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _skills)
                    Container(
                      padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
                      decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(999)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            s,
                            style: TextStyle(fontWeight: FontWeight.w700, color: c.brandInk, fontSize: 13),
                          ),
                          InkWell(
                            onTap: locked ? null : () => setState(() => _skills = _skills.where((x) => x != s).toList()),
                            borderRadius: BorderRadius.circular(99),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(LucideIcons.x, size: 13, color: c.brandInk),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Field(
                controller: _skill,
                hint: t('pf.skillsPh'),
                maxLength: 40,
                enabled: !locked && _skills.length < 40,
                suffix: IconButton(
                  onPressed: _addSkill,
                  icon: Icon(LucideIcons.plus, size: 18, color: c.brand),
                ),
                onSubmit: (_) => _addSkill(),
                onChanged: (v) {
                  if (v.endsWith(',')) {
                    _skill.text = v.substring(0, v.length - 1);
                    _addSkill();
                  }
                },
              ),
            ],
          ),
        ),
        for (final l in _lists) ...[const SizedBox(height: 14), _listPanel(l, t, c, locked)],
        const SizedBox(height: 14),
        _filesPanel(t, c, locked),
      ],
    );
  }

  void _addSkill() {
    final v = _skill.text.trim();
    final s = v.length > 40 ? v.substring(0, 40) : v;
    if (s.isNotEmpty && !_skills.contains(s) && _skills.length < 40) setState(() => _skills = [..._skills, s]);
    _skill.clear();
  }

  Widget _listPanel(_ListSpec l, T t, C c, bool locked) {
    final rows = _rows[l.key]!;
    void move(int i, int d) => setState(() {
      final r = rows.removeAt(i);
      rows.insert(i + d, r);
    });
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(l.icon, size: 18, color: c.ink),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(child: Text(t('pf.${l.key}'), style: Theme.of(context).textTheme.titleMedium)),
                    if (rows.isNotEmpty) ...[const SizedBox(width: 6), Chip2('${rows.length}')],
                  ],
                ),
              ),
              if (rows.length < l.max)
                Btn(t('pf.add'), icon: LucideIcons.plus, kind: BtnKind.ghost, small: true, onTap: locked ? null : () => setState(() => rows.add(_Row(l, const {})..listen(_changed)))),
            ],
          ),
          for (var i = 0; i < rows.length; i++)
            Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: c.card, shape: BoxShape.circle),
                        child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                      const Spacer(),
                      RoundBtn(LucideIcons.arrowUp, size: 34, tip: t('pf.moveUp'), onTap: locked || i == 0 ? null : () => move(i, -1)),
                      const SizedBox(width: 6),
                      RoundBtn(LucideIcons.arrowDown, size: 34, tip: t('pf.moveDown'), onTap: locked || i == rows.length - 1 ? null : () => move(i, 1)),
                      const SizedBox(width: 6),
                      RoundBtn(LucideIcons.trash2, size: 34, tip: t('pf.remove'), fg: c.danger, onTap: locked ? null : () => setState(() => rows.removeAt(i).dispose())),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final f in l.fields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Field(
                        label: t('pf.f.${f.$2}'),
                        controller: rows[i].c[f.$1]!,
                        maxLength: f.$3,
                        hint: f.$4 == null ? null : t('pf.${f.$4}'),
                        keyboard: f.$1 == 'link' ? TextInputType.url : null,
                        enabled: !locked && !(l.flag != null && f.$1 == 'end' && rows[i].flag),
                      ),
                    ),
                  if (l.flag != null)
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: rows[i].flag,
                      onChanged: locked ? null : (v) => setState(() => rows[i].flag = v),
                      title: Text(t('pf.f.${l.flag}'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  if (l.text != null) Field(label: t('pf.f.${l.text!.$2}'), controller: rows[i].c[l.text!.$1]!, maxLength: l.text!.$3, maxLines: 3, enabled: !locked),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _filesPanel(T t, C c, bool locked) {
    final full = _files.length >= 12;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.fileText, size: 18, color: c.ink),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(child: Text(t('pf.documents'), style: Theme.of(context).textTheme.titleMedium)),
                    if (_files.isNotEmpty) ...[const SizedBox(width: 6), Chip2('${_files.length}/12')],
                  ],
                ),
              ),
              Btn(
                _uploading ? t('pf.uploading') : t('pf.upload'),
                icon: LucideIcons.imagePlus,
                kind: BtnKind.ghost,
                small: true,
                busy: _uploading,
                onTap: locked || _uploading || full ? null : _addFile,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Muted(full ? t('pf.filesFull') : t('pf.documentsSub')),
          for (final f in _files)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => launchUrl(Uri.parse(str(f['url'])), mode: LaunchMode.externalApplication),
                    child: Container(
                      width: 64,
                      height: 48,
                      decoration: BoxDecoration(
                        color: c.bg2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.line),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          str(f['thumb']).isNotEmpty
                              ? Image(image: netImage(str(f['thumb'])), fit: BoxFit.cover, alignment: Alignment.topCenter, errorBuilder: (_, _, _) => const SizedBox.shrink())
                              : Icon(LucideIcons.fileText, size: 22, color: c.muted),
                          if (str(f['kind']) == 'pdf')
                            Positioned(
                              top: 3,
                              left: 3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(color: const Color(0xFFD93025), borderRadius: BorderRadius.circular(4)),
                                child: const Text(
                                  'PDF',
                                  style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FileTitle(key: ValueKey(f['_id']), initial: str(f['title']), hint: t('pf.fileTitlePh'), enabled: !locked, onDone: (v) => _renameFile(f, v)),
                  ),
                  const SizedBox(width: 6),
                  _confirmFile == str(f['_id'])
                      ? Btn(t('pf.confirmDelete'), kind: BtnKind.danger, small: true, onTap: () => _deleteFile(f))
                      : RoundBtn(LucideIcons.trash2, size: 38, tip: t('pf.deleteFile'), fg: c.danger, onTap: locked ? null : () => setState(() => _confirmFile = str(f['_id']))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _saveBar(T t, C c) {
    final dirty = _dirty;
    final lockedTheme = dirty && _locked(_theme);
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
              RoundBtn(LucideIcons.eye, size: 40, tip: t('card.preview'), onTap: _openPreview),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  dirty ? (lockedTheme ? t('pf.lockedSaveHint') : t('pf.unsaved')) : t('pf.allSaved'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: dirty ? c.ink : c.muted),
                ),
              ),
              if (dirty) ...[RoundBtn(LucideIcons.undo2, size: 40, tip: 'Undo', onTap: _saving ? null : () => _fill(_saved!)), const SizedBox(width: 8)],
              lockedTheme
                  ? Btn(t('pf.themeUnlockFor', {'coins': fmt(_themePrice)}), small: true, lead: const CoinIcon(size: 16), onTap: () => _unlockTheme(_theme, str(_saved?['theme'])))
                  : Btn(_saving ? t('pf.saving') : t('pf.save'), small: true, busy: _saving, onTap: dirty && !_saving && !widget.suspended ? _save : null),
            ],
          ),
        ),
      ),
    );
  }
}

// the file title saves when the box loses focus (like the web)
class _FileTitle extends StatefulWidget {
  final String initial, hint;
  final bool enabled;
  final ValueChanged<String> onDone;
  const _FileTitle({super.key, required this.initial, required this.hint, required this.enabled, required this.onDone});
  @override
  State<_FileTitle> createState() => _FileTitleState();
}

class _FileTitleState extends State<_FileTitle> {
  late final _c = TextEditingController(text: widget.initial);
  final _focus = FocusNode();
  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) widget.onDone(_c.text);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return TextField(
      controller: _c,
      focusNode: _focus,
      enabled: widget.enabled,
      maxLength: 80,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _focus.unfocus(),
      style: TextStyle(fontSize: 14.5, color: c.ink, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        counterText: '',
        hintText: widget.hint,
        isDense: true,
        filled: true,
        fillColor: c.bg2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}

// small live portfolio (theme tiles, unlock sheet)
class _PfMini extends StatelessWidget {
  final Json data, card;
  final double width, height;
  const _PfMini({required this.data, required this.card, required this.width, required this.height});
  @override
  Widget build(BuildContext context) => Consumer(
    builder: (context, ref, _) => ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: width,
        height: height,
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 390,
            height: 390 * height / width,
            child: IgnorePointer(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                maxHeight: double.infinity,
                child: PfView(data: data, card: card, t: ref.watch(tProvider)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PfThemeRow extends StatelessWidget {
  final List<String> themes;
  final String current;
  final Json data, card;
  final T t;
  final ValueChanged<String> onPick;
  final bool Function(String)? locked;
  final num price;
  const _PfThemeRow({required this.themes, required this.current, required this.data, required this.card, required this.t, required this.onPick, this.locked, this.price = 0});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
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
          final owned = locked != null && !isLocked;
          return GestureDetector(
            onTap: () => onPick(th),
            child: SizedBox(
              width: 102,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: on ? c.brand : Colors.transparent, width: 2),
                    ),
                    child: Stack(
                      children: [
                        _PfMini(data: {...data, 'theme': th}, card: card, width: 92, height: 130),
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
                        if (owned)
                          Positioned(
                            left: 6,
                            bottom: 6,
                            child: _Badge(
                              color: c.good,
                              children: [
                                const Icon(LucideIcons.crown, size: 11, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  t('pf.unlockedTag'),
                                  style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (on) ...[Icon(LucideIcons.check, size: 13, color: c.brand), const SizedBox(width: 3)],
                      Flexible(
                        child: Text(
                          pfRecipeName(th, t.km) ?? t.or('pf.themeNames.$th', th),
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
        },
      ),
    );
  }
}

// fake mini website (promo + buy sheet), like the web's Mock
class _Mock extends StatelessWidget {
  final Json card;
  const _Mock({required this.card});
  @override
  Widget build(BuildContext context) {
    final col = hexColor(str(card['color']));
    Widget bar(double w, double o) => Container(
      height: 8,
      width: w,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: o),
        borderRadius: BorderRadius.circular(99),
      ),
    );
    return Container(
      width: 230,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x2416171B), blurRadius: 40, offset: Offset(0, 16))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: const Color(0xFFF1F2F6),
            child: Row(
              children: [
                for (final d in const [Color(0xFFFF5F57), Color(0xFFFEBC2E), Color(0xFF28C840)]) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: d, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                ],
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '/${str(card['slug'])}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF6A6E7A), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [shade(col, -45), col])),
            child: Column(
              children: [
                Avatar(name: str(card['name']), photo: str(card['photo']), size: 46),
                const SizedBox(height: 8),
                Text(
                  str(card['name']).isEmpty ? 'Your name' : str(card['name']),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                ),
                Text(str(card['job_title']).isEmpty ? 'Your job' : str(card['job_title']), style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 11.5)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(color: shade(col, 90), borderRadius: BorderRadius.circular(6)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FractionallySizedBox(widthFactor: (70 - i * 12) / 100, child: bar(100, .14)),
                              const SizedBox(height: 4),
                              FractionallySizedBox(widthFactor: (45 + i * 10) / 100, child: bar(100, .07)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    for (final w in const [40.0, 52.0, 34.0]) ...[
                      Container(
                        width: w,
                        height: 14,
                        decoration: BoxDecoration(color: shade(col, 90), borderRadius: BorderRadius.circular(99)),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _shareQrOf(String link, String fileName) async {
  final painter = QrPainter(
    data: link,
    version: QrVersions.auto,
    gapless: true,
    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF16171B)),
    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF16171B)),
  );
  final data = await painter.toImageData(600, format: ui.ImageByteFormat.png);
  if (data == null) return;
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png', name: fileName)],
      text: link,
    ),
  );
}

bool pfRecipes0(String key) => pfRecipeName(key, false) != null;

// the 100 recipe themes: filter chips + a grid of live minis (24 at a time) · tap → the look sheet over the filtered list
class _PfRecipeGallery extends StatefulWidget {
  final List<String> keys;
  final String current;
  final Json data, card;
  final T t;
  final bool Function(String) locked;
  final num price;
  final void Function(String key, List<String> list) onPick;
  const _PfRecipeGallery({required this.keys, required this.current, required this.data, required this.card, required this.t, required this.locked, required this.price, required this.onPick});
  @override
  State<_PfRecipeGallery> createState() => _PfRecipeGalleryState();
}

class _PfRecipeGalleryState extends State<_PfRecipeGallery> {
  String _filter = 'all';
  int _shown = 24;

  List<String> get _list => widget.keys.where((k) => _filter == 'owned' ? !widget.locked(k) : pfRecipeMatch(k, _filter)).toList();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = widget.t;
    final list = _list;
    final shown = list.take(_shown).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.sparkles, size: 16, color: c.brand),
            const SizedBox(width: 6),
            Text(t('pfr.title'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const Spacer(),
            const CoinIcon(size: 16),
            const SizedBox(width: 4),
            Text(fmt(widget.price), style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 2),
        Text(t('pfr.sub', {'n': '${widget.keys.length}'}), style: TextStyle(color: c.muted, fontSize: 12.5)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in const ['all', 'light', 'dark', 'color', 'serif', 'mono', 'owned'])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(t('ncr.f.$f')),
                    selected: _filter == f,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() {
                      _filter = f;
                      _shown = 24;
                    }),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text(t('ncr.none'), style: TextStyle(color: c.muted))),
          )
        else
          LayoutBuilder(
            builder: (context, box) {
              const gap = 10.0;
              final cols = box.maxWidth >= 520 ? 5 : 3;
              final w = (box.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: 12,
                children: [
                  for (final k in shown)
                    _PfRecipeTile(
                      themeKey: k,
                      width: w,
                      on: k == widget.current,
                      locked: widget.locked(k),
                      price: widget.price,
                      data: widget.data,
                      card: widget.card,
                      t: t,
                      onTap: () => widget.onPick(k, list),
                    ),
                ],
              );
            },
          ),
        if (list.length > _shown)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Btn('${t('pfr.more')} (${list.length - _shown})', kind: BtnKind.ghost, expand: true, onTap: () => setState(() => _shown += 24)),
          ),
      ],
    );
  }
}

class _PfRecipeTile extends StatelessWidget {
  final String themeKey;
  final double width;
  final bool on, locked;
  final num price;
  final Json data, card;
  final T t;
  final VoidCallback onTap;
  const _PfRecipeTile({required this.themeKey, required this.width, required this.on, required this.locked, required this.price, required this.data, required this.card, required this.t, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final w = width - 10;
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
              child: Stack(
                children: [
                  _PfMini(data: {...data, 'theme': themeKey}, card: card, width: w, height: w * 1.42),
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: locked
                        ? _Badge(
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
                          )
                        : _Badge(
                            color: c.good,
                            children: [
                              const Icon(LucideIcons.crown, size: 11, color: Colors.white),
                              const SizedBox(width: 3),
                              Text(
                                t('pf.unlockedTag'),
                                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (on) ...[Icon(LucideIcons.check, size: 13, color: c.brand), const SizedBox(width: 3)],
                Flexible(
                  child: Text(
                    pfRecipeName(themeKey, t.km) ?? themeKey,
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
