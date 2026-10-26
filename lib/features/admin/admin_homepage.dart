import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../common/shell.dart';
import '../restaurant/rest_common.dart' show Segmented;
import 'admin_data.dart';
import 'admin_parts.dart';

// Super admin: everything shown on the public homepage (HomepageSettingsPage.jsx + TelegramBotCard.jsx)
// GET /api/admin/homepage → form; Save → PUT /api/admin/homepage
const _contactKeys = ['email', 'telegram', 'telegram_url', 'facebook_url', 'map_url', 'address'];
const _names = {
  'namecard': 'cCard',
  'restaurant': 'cRestaurant',
  'mart': 'cMart',
  'guest': 'cGuest',
  'warehouse': 'cWarehouse',
  'attend': 'cAttend',
  'website': 'cWeb',
  'menu_qr': 'cMenuQr',
  'flipbook': 'cFlip',
  'qr_gen': 'cQr',
  'debt_book': 'cDebt',
  'stamp_card': 'cStamp',
  'event': 'cEvent',
  'digital_note': 'cNote',
  'tg_store': 'cTgStore',
};

class AdminHomepagePage extends ConsumerStatefulWidget {
  const AdminHomepagePage({super.key});
  @override
  ConsumerState<AdminHomepagePage> createState() => _AdminHomepagePageState();
}

class _AdminHomepagePageState extends ConsumerState<AdminHomepagePage> {
  String _savedKey = ''; // payload of the last saved copy, to know if something changed
  Json _base = {}; // the normalized form (payment methods etc. pass through)
  final _phones = TextEditingController();
  final _contact = {for (final k in _contactKeys) k: TextEditingController()};
  final _android = TextEditingController(), _ios = TextEditingController();
  String _appStatus = 'coming_soon';
  List<Json> _services = [];
  final _texts = {'en': <String, TextEditingController>{}, 'km': <String, TextEditingController>{}};
  String _textLang = 'en', _q = '', _error = '';
  bool _loading = true, _saving = false;

  @override
  void initState() {
    super.initState();
    _textLang = ref.read(tProvider).lang;
    _load();
  }

  @override
  void dispose() {
    for (final c in [_phones, _android, _ios, ..._contact.values, ..._texts['en']!.values, ..._texts['km']!.values]) {
      c.dispose();
    }
    super.dispose();
  }

  // fill missing parts with defaults so the form always has every field
  Json _normalize(Json src) {
    final d = defaultHomepage;
    final saved = objs(src['services']).where((x) => x['key'] != 'warehouse').toList();
    final services = saved.isEmpty ? objs(d['services']) : [...saved, ...objs(d['services']).where((x) => !saved.any((r) => r['key'] == x['key']))];
    final pm = src['payment_methods'] is List && (src['payment_methods'] as List).isNotEmpty ? src['payment_methods'] : d['payment_methods'];
    return {
      'contact': {...obj(d['contact']), ...obj(src['contact'])},
      'payment_methods': pm,
      'app': {...obj(d['app']), ...obj(src['app'])},
      'services': services,
      'texts': {'en': obj(obj(src['texts'])['en']), 'km': obj(obj(src['texts'])['km'])},
    };
  }

  void _fill(Json data) {
    final ct = obj(data['contact']);
    _phones.text = ct['phones'] is List ? (ct['phones'] as List).join('\n') : str(ct['phones']);
    for (final k in _contactKeys) {
      _contact[k]!.text = str(ct[k]);
    }
    final app = obj(data['app']);
    _appStatus = str(app['status']).isEmpty ? 'coming_soon' : str(app['status']);
    _android.text = str(app['android_url']);
    _ios.text = str(app['ios_url']);
    _services = [for (final s in objs(data['services'])) Map.of(s)];
    for (final l in ['en', 'km']) {
      final saved = obj(obj(data['texts'])[l]);
      for (final c in _texts[l]!.values) {
        c.text = '';
      }
      saved.forEach((k, v) => (_texts[l]![k] ??= TextEditingController()).text = str(v));
    }
    _base = data;
    _savedKey = jsonEncode(_payload());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final r = obj((await ref.read(apiProvider).get('${Api.admin}/homepage'))['data']);
      _fill(_normalize(r));
    } on ApiError catch (e) {
      _error = e.network ? ref.read(tProvider)('messages.networkError') : e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Json _payload() {
    final texts = {'en': <String, String>{}, 'km': <String, String>{}};
    for (final l in ['en', 'km']) {
      _texts[l]!.forEach((k, c) {
        if (c.text.trim().isNotEmpty) texts[l]![k] = c.text;
      });
    }
    return {
      'contact': {'phones': _phones.text.split('\n').map((p) => p.trim()).where((p) => p.isNotEmpty).toList(), for (final k in _contactKeys) k: _contact[k]!.text},
      'payment_methods': [for (final m in (_base['payment_methods'] is List ? _base['payment_methods'] as List : const [])) '$m'.trim()].where((m) => m.isNotEmpty).toList(),
      'app': {'status': _appStatus, 'android_url': _android.text, 'ios_url': _ios.text},
      'services': [
        for (var i = 0; i < _services.length; i++) {..._services[i], 'sort_order': i},
      ],
      'texts': texts,
    };
  }

  Future<void> _save() async {
    final t = ref.read(tProvider);
    setState(() => _saving = true);
    try {
      final r = obj((await ref.read(apiProvider).put('${Api.admin}/homepage', _payload()))['data']);
      setState(() => _fill(_normalize(r)));
      if (mounted) toast(context, t('messages.saved'));
    } on ApiError catch (e) {
      if (mounted) toast(context, e.network ? t('messages.networkError') : e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final dirty = !_loading && _savedKey.isNotEmpty && jsonEncode(_payload()) != _savedKey;
    String serviceName(String key) {
      final h = homeText(t.lang);
      return h[_names[key]] ?? (serviceTitle(t.lang, key).isNotEmpty ? serviceTitle(t.lang, key) : key);
    }

    Widget field(String label, TextEditingController ctl, {String? hint, int lines = 1, TextInputType? kb}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Field(label: label, controller: ctl, hint: hint, maxLines: lines, keyboard: kb, onChanged: (_) => setState(() {})),
    );

    final defaults = homeText(_textLang);
    final qq = _q.toLowerCase();
    final keys = defaults.keys
        .where((k) => qq.isEmpty || k.toLowerCase().contains(qq) || defaults[k]!.toLowerCase().contains(qq) || (_texts[_textLang]![k]?.text ?? '').toLowerCase().contains(qq))
        .toList();

    return SubPage(
      title: t('messages.hpTitle'),
      onRefresh: _load,
      actions: [
        RoundBtn(
          LucideIcons.externalLink,
          size: 42,
          tip: t('messages.viewSite'),
          onTap: () => launchUrl(Uri.parse(Config.siteUrl), mode: LaunchMode.externalApplication),
        ),
      ],
      bottom: dirty
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    t('messages.unsaved'),
                    style: TextStyle(fontWeight: FontWeight.w700, color: c.brandInk),
                  ),
                ),
                TextButton(onPressed: _saving ? null : () => setState(() => _fill(_base)), child: Text(t('messages.discard'))),
                const SizedBox(width: 6),
                Btn(_saving ? t('messages.saving') : t('messages.save'), busy: _saving, onTap: _save),
              ],
            )
          : null,
      children: [
        Muted(t('messages.hpSub')),
        const SizedBox(height: 14),
        if (_loading) const Panel(child: SkelList()),
        if (!_loading && _error.isNotEmpty) LoadError(text: _error, retry: t('app.retry'), onRetry: _load),
        if (!_loading && _error.isEmpty) ...[
          _Card(
            icon: LucideIcons.phone,
            title: t('messages.hpContact'),
            children: [
              field('${t('messages.hpPhones')} · ${t('messages.hpPhonesHint')}', _phones, lines: 3, kb: TextInputType.multiline),
              field(t('messages.hpEmail'), _contact['email']!, kb: TextInputType.emailAddress),
              field(t('messages.hpTelegram'), _contact['telegram']!),
              field(t('messages.hpTelegramUrl'), _contact['telegram_url']!, hint: 'https://t.me/...', kb: TextInputType.url),
              field(t('messages.hpFacebook'), _contact['facebook_url']!, hint: 'https://facebook.com/...', kb: TextInputType.url),
              field(t('messages.hpMap'), _contact['map_url']!, kb: TextInputType.url),
              field(t('messages.hpAddress'), _contact['address']!),
            ],
          ),
          _Card(
            icon: LucideIcons.coins,
            title: t('messages.hpCoins'),
            children: [
              Muted(t('messages.hpPricesMoved')),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Btn(t('messages.navPrices'), icon: LucideIcons.tags, kind: BtnKind.ghost, small: true, onTap: () => context.push('/a/prices')),
              ),
            ],
          ),
          _Card(
            icon: LucideIcons.smartphone,
            title: t('messages.hpApp'),
            children: [
              Text(t('messages.hpAppStatus'), style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Segmented<String>(value: _appStatus, options: [('coming_soon', t('messages.hpAppSoon')), ('live', t('messages.hpAppLive'))], onChanged: (v) => setState(() => _appStatus = v)),
              const SizedBox(height: 12),
              field(t('messages.hpAndroid'), _android, kb: TextInputType.url),
              field(t('messages.hpIos'), _ios, kb: TextInputType.url),
            ],
          ),
          _Card(
            icon: LucideIcons.layoutGrid,
            title: t('messages.hpServices'),
            children: [Muted(t('messages.hpServicesHint')), const SizedBox(height: 8), for (var i = 0; i < _services.length; i++) _serviceRow(i, serviceName(str(_services[i]['key'])), t, c)],
          ),
          const _TelegramBot(),
          const SizedBox(height: 14),
          _Card(
            icon: LucideIcons.type,
            title: t('messages.hpTexts'),
            children: [
              Muted(t('messages.hpTextsHint')),
              const SizedBox(height: 10),
              Segmented<String>(value: _textLang, options: const [('en', 'English'), ('km', 'ខ្មែរ')], onChanged: (v) => setState(() => _textLang = v)),
              const SizedBox(height: 10),
              SearchBox(hint: t('messages.hpSearch'), onSearch: (v) => setState(() => _q = v)),
              const SizedBox(height: 10),
              for (final k in keys) _textRow(k, defaults[k]!, t, c),
            ],
          ),
        ],
      ],
    );
  }

  Widget _serviceRow(int i, String name, T t, C c) {
    final s = _services[i];
    final on = s['enabled'] != false;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: on ? c.active : c.chip, shape: BoxShape.circle),
            child: Text(
              '${i + 1}',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: on ? c.brandInk : c.muted),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(fontWeight: FontWeight.w700, color: on ? c.ink : c.muted),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    FilterChip(
                      label: Text(t('messages.hpShow')),
                      selected: on,
                      showCheckmark: true,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: (v) => setState(() => s['enabled'] = v),
                    ),
                    FilterChip(
                      label: Text(t('messages.hpSoonLabel')),
                      selected: s['coming_soon'] == true,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: (v) => setState(() => s['coming_soon'] = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(tooltip: t('messages.hpUp'), onPressed: i == 0 ? null : () => setState(() => _services.insert(i - 1, _services.removeAt(i))), icon: const Icon(LucideIcons.arrowUp, size: 18)),
          IconButton(
            tooltip: t('messages.hpDown'),
            onPressed: i == _services.length - 1 ? null : () => setState(() => _services.insert(i + 1, _services.removeAt(i))),
            icon: const Icon(LucideIcons.arrowDown, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _textRow(String k, String def, T t, C c) {
    final ctl = _texts[_textLang]![k] ??= TextEditingController();
    final changed = ctl.text.trim().isNotEmpty;
    return Container(
      key: ValueKey('$_textLang/$k'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: changed ? c.active.withValues(alpha: .5) : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: changed ? c.brand : c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  k,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: c.muted),
                ),
              ),
              if (changed) ...[
                Chip2(t('messages.hpChanged'), tone: Tone.brand),
                TextButton.icon(onPressed: () => setState(() => ctl.clear()), icon: const Icon(LucideIcons.rotateCcw, size: 13), label: Text(t('messages.hpReset'))),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Field(controller: ctl, hint: def, maxLines: def.length > 70 ? 3 : 1, onChanged: (_) => setState(() {})),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  const _Card({required this.icon, required this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Panel(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 18, color: c.brandInk),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

// Telegram bot status + "fix the connection" (TelegramBotCard.jsx)
class _TelegramBot extends ConsumerStatefulWidget {
  const _TelegramBot();
  @override
  ConsumerState<_TelegramBot> createState() => _TelegramBotState();
}

class _TelegramBotState extends ConsumerState<_TelegramBot> {
  Json? _s;
  bool _busy = false;
  (bool, String)? _msg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final r = await ref.read(apiProvider).get('${Api.admin}/telegram');
      if (mounted) setState(() => _s = obj(r['data']));
    } on ApiError catch (e) {
      if (mounted) setState(() => _msg = (false, e.message));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fix() async {
    final t = ref.read(tProvider);
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final r = await ref.read(apiProvider).post('${Api.admin}/telegram/webhook');
      setState(() {
        _s = obj(r['data']);
        _msg = (true, t('tgb.fixed'));
      });
    } on ApiError catch (e) {
      setState(() => _msg = (false, e.message));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final s = _s ?? const <String, dynamic>{};
    final loaded = _s != null;
    final configured = s['configured'] == true;
    final working = loaded && (s['mode'] == 'webhook' || s['mode'] == 'polling') && str(s['error']).isEmpty;
    Widget line(bool ok, String text) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Alert(text, tone: ok ? Tone.good : Tone.warn),
    );
    Widget kv(String k, String v) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: Theme.of(context).textTheme.bodySmall),
            Text(
              v,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
    final err = str(s['error']).isNotEmpty ? str(s['error']) : str(s['last_error']);
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(color: Color(0xFF229ED9), shape: BoxShape.circle),
                child: const Icon(LucideIcons.send, size: 17, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('tgb.title'), style: Theme.of(context).textTheme.titleMedium),
                    Text(t('tgb.sub'), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              RoundBtn(LucideIcons.refreshCw, size: 38, tip: t('tgb.check'), onTap: _busy ? null : _load),
            ],
          ),
          if (_busy && !loaded) const Padding(padding: EdgeInsets.only(top: 12), child: SkelList(rows: 1)),
          if (loaded && !configured) line(false, t('tgb.noToken')),
          if (configured) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                kv(t('tgb.bot'), str(s['bot']).isEmpty ? '—' : '@${s['bot']}'),
                const SizedBox(width: 8),
                kv(t('tgb.mode'), t.or('tgb.modes.${s['mode']}', str(s['mode']))),
                if (n(s['pending']) > 0) ...[const SizedBox(width: 8), kv(t('tgb.pending'), str(s['pending']))],
              ],
            ),
            if (working) line(true, t('tgb.ok')),
            if (!working) ...[
              if (err.isNotEmpty) line(false, '${t('tgb.lastError')}: $err'),
              if (str(s['public_url']).isEmpty) line(false, t('tgb.noUrl')),
              const SizedBox(height: 10),
              Btn(t('tgb.fix'), busy: _busy, onTap: str(s['public_url']).isEmpty ? null : _fix),
            ],
          ],
          if (_msg != null) line(_msg!.$1, _msg!.$2),
        ],
      ),
    );
  }
}
