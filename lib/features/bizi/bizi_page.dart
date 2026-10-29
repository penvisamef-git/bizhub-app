import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../common/open_business.dart';
import '../owner/coin_play.dart' show playBilling;
import '../owner/data.dart';
import '../team/team_data.dart';
import 'bizi_actions.dart';
import 'bizi_bubble.dart';
import 'bizi_face.dart';
import 'bizi_find.dart';
import 'bizi_settings.dart';
import 'bizi_telegram.dart';
import 'bizi_voice.dart';

// Bizi's search screen (/o/bizi) — the same box as ⌘K on the website:
//   here, without the server: the sections of every business I can open, the how-tos ("how do I pair a POS?"),
//   dark mode / language, my recent picks; the server (GET /api/user/search): products, orders, bookings, people…
//   in all my businesses, and the smart words ("new", "unpaid orders today", "ការកម្ម៉ង់ថ្មី").
//   Empty box: what Bizi has to say (the brief), smart-word chips, questions, recent, my businesses.

const _groups = ['smart', 'pages', 'help', 'businesses', 'products', 'orders', 'people', 'other'];
const _groupsAsked = ['help', 'smart', 'pages', 'businesses', 'products', 'orders', 'people', 'other'];
const _adminGroups = ['smart', 'pages', 'help', 'people', 'businesses', 'orders', 'other'];
const _adminGroupsAsked = ['help', 'smart', 'pages', 'people', 'businesses', 'orders', 'other'];
const _recentKey = 'bizi_recent';

// the BizHub team: web addresses (alerts, results) → the admin app's screens
String adminRoute(String href) {
  final u = Uri.parse(href);
  final open = u.queryParameters['open'] ?? '';
  final t = u.queryParameters['t'] ?? '';
  return switch (u.path) {
    '/app/super-admin/customers' when open.isNotEmpty => '/a/customer/$open',
    '/app/super-admin/customers' => '/a/customers',
    '/app/super-admin/businesses' => '/a/businesses',
    '/app/super-admin/coin-orders' => '/a/orders',
    '/app/super-admin/inbox' when t.isNotEmpty => '/a/inbox/$t',
    '/app/super-admin/inbox' => '/a/inbox',
    '/app/super-admin/coins' => u.queryParameters['tab'] == 'cards' ? '/a/cards' : '/a/coins',
    '/app/super-admin/licenses' => '/a/licenses',
    _ => '/a/dash',
  };
}

// web addresses (alerts, results) → the app's own screens
String appRoute(String href) {
  final p = href.split('?').first;
  if (href.startsWith('/app/licenses?tab=coins')) return '/o/coins';
  return switch (p) {
    '/app/licenses' => '/o/licenses',
    '/app/businesses' => '/o/business',
    '/app/wallet' => '/o/wallet',
    '/app/account' || '/app/settings' => '/account',
    '/app/support' => '/o/support',
    '/app/updates' => '/updates',
    _ => '/o/home',
  };
}

// words only the app needs (buying coins on a phone goes through the store)
const _appWords = {
  'en': {
    'storeSteps': ['Open More → “Buy coins” (or tap your coins at the top).', 'Pick a package.', 'Pay with {store} — the coins are added at once.'],
  },
  'km': {
    'storeSteps': ['បើក ច្រើនទៀត → “ទិញកាក់” (ឬចុចកាក់របស់អ្នកនៅខាងលើ)។', 'ជ្រើសកញ្ចប់។', 'បង់ជាមួយ {store} — កាក់ត្រូវបានបញ្ចូលភ្លាមៗ។'],
  },
};

class _Row {
  final String group, kind, id, title, sub;
  final IconData icon;
  final String level;
  final Json? business; // open this business (at tab)
  final String tab;
  final String route; // or this app screen
  final String status, flag, logo, cur;
  final Object? money;
  final HelpHit? help;
  final Json? tip; // a thing not set up yet (opens its how-to for that business)
  final Json? week; // last week's report
  final VoidCallback? run;
  const _Row({
    required this.group,
    required this.kind,
    required this.id,
    required this.title,
    this.sub = '',
    this.icon = LucideIcons.arrowUpRight,
    this.level = '',
    this.business,
    this.tab = '',
    this.route = '',
    this.status = '',
    this.flag = '',
    this.logo = '',
    this.cur = '',
    this.money,
    this.help,
    this.tip,
    this.week,
    this.run,
  });
  Json toRecent() => {
    'kind': kind,
    'title': title,
    'sub': sub,
    'route': route,
    'tab': tab,
    if (business != null) 'business': {'_id': business!['_id'], 'name': business!['name'], 'category': business!['category']},
  };
}

const _kindIcon = <String, IconData>{
  'coin_order': LucideIcons.coins,
  'chat': LucideIcons.messageCircle,
  'app_error': LucideIcons.bug,
  'alert': LucideIcons.bellRing,
  'help': LucideIcons.lifeBuoy,
  'tip': LucideIcons.wrench,
  'week': LucideIcons.calendarRange,
  'product': LucideIcons.package,
  'order': LucideIcons.receiptText,
  'stay': LucideIcons.bedDouble,
  'person': LucideIcons.userRound,
  'event': LucideIcons.ticket,
  'note': LucideIcons.stickyNote,
  'book': LucideIcons.bookOpen,
  'qr': LucideIcons.qrCode,
  'page': LucideIcons.fileText,
  'business': LucideIcons.store,
  'tab': LucideIcons.arrowUpRight,
  'app': LucideIcons.layoutGrid,
  'recent': LucideIcons.clock,
};

class BiziPage extends ConsumerStatefulWidget {
  static Future<void> Function(Uri url)? openUrl; // tests: no real Telegram (null = the phone opens it)
  final bool admin; // the BizHub team's Bizi (super admin): its own search, alerts, screens, how-tos
  const BiziPage({super.key, this.admin = false});
  @override
  ConsumerState<BiziPage> createState() => _BiziPageState();
}

class _BiziPageState extends ConsumerState<BiziPage> {
  final _q = TextEditingController();
  final _focus = FocusNode();
  Timer? _wait;
  int _ask = 0;
  String _apiQ = '';
  List<Json> _api = const [];
  List<String> _smart = const [];
  bool _fuzzy = false;
  bool _busy = false;
  bool _typing = false;
  bool _offline = false;
  bool _settings = false; // the gear: Bizi settings instead of the list
  ({String row, BiziAction a, String title})? _confirm; // a quick action waiting for Yes / No
  bool _acting = false;
  bool _listening = false;

  // voice: the phone's own speech-to-text; the words go into the box as they come
  Future<void> _voice() async {
    final lang = ref.read(tProvider).lang;
    if (_listening) {
      await BiziVoice.instance.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    final ok = await BiziVoice.instance.start(
      lang,
      (words, done) {
        if (!mounted) return;
        if (words.isNotEmpty) {
          _q.value = TextEditingValue(
            text: words,
            selection: TextSelection.collapsed(offset: words.length),
          );
        }
        if (done) setState(() => _listening = false);
      },
      onEnd: () {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!ok && mounted) {
      setState(() => _listening = false);
      toast(context, biziT(lang, 'voiceNo'));
    }
  }

  List<BiziAction> _actionsOf(_Row r) =>
      r.business == null ? const [] : actionsOf(category: str(r.business!['category']), kind: r.kind, id: r.id, businessId: str(r.business!['_id']), status: r.status, flag: r.flag);
  BiziAction? _primaryOf(_Row r) {
    final v = verbOf(_term);
    if (v == null) return null;
    return _actionsOf(r).where((a) => a.key == v.key).firstOrNull;
  }

  Future<void> _runConfirm() async {
    final c = _confirm;
    if (c == null || _acting) return;
    final lang = ref.read(tProvider).lang;
    setState(() => _acting = true);
    final api = ref.read(apiProvider);
    final path = '${Api.user}${c.a.path}';
    try {
      await (c.a.method == 'put' ? api.put(path, c.a.body) : api.post(path, c.a.body));
      if (!mounted) return;
      toast(context, biziT(lang, 'actOk.${c.a.key}', {'t': c.title}));
      setState(() => _confirm = null);
      _changed(); // the result again, as it is now
      _reloadBrief();
    } catch (e) {
      if (!mounted) return;
      toast(context, '$e');
      setState(() => _confirm = null);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  final Set<String> _hidden = {}; // tips put off ("Not now") while the screen is open

  // ask for the brief again (after settings change / a tip is put off)
  Future<void> _reloadBrief() async {
    try {
      final b = obj((await ref.read(apiProvider).get('${widget.admin ? Api.admin : Api.user}/bizi/brief'))['data']);
      if (mounted) ref.read(biziBriefProvider.notifier).state = b;
    } catch (_) {}
  }

  void _snooze(Json tip) {
    final lang = ref.read(tProvider).lang;
    setState(() => _hidden.add('${tip['key']}:${tip['business_id']}'));
    toast(context, biziT(lang, 'snoozed'));
    ref.read(apiProvider).post('${Api.user}/bizi/snooze', {'key': tip['key'], 'business_id': tip['business_id']}).then((_) => _reloadBrief()).catchError((_) => <String, dynamic>{});
  }

  String? _openQ; // the how-to opened (or closed: '') for these words
  String _openId = '';

  @override
  void initState() {
    super.initState();
    _q.addListener(_changed);
  }

  @override
  void dispose() {
    if (_listening) BiziVoice.instance.stop();
    _wait?.cancel();
    _q.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _term => _q.text.trim();
  String _route(String href) => widget.admin ? adminRoute(href) : appRoute(href);

  // ask the server a moment after the typing stops; an older answer never replaces a newer one
  void _changed() {
    final term = _term;
    _wait?.cancel();
    if (term.length < 2 && !RegExp(r'^#?\d+$').hasMatch(term)) {
      setState(() {
        _apiQ = term;
        _api = const [];
        _smart = const [];
        _fuzzy = false;
        _busy = false;
        _typing = false;
      });
      return;
    }
    setState(() => _typing = true);
    final n = ++_ask;
    _wait = Timer(const Duration(milliseconds: 240), () async {
      if (!mounted) return;
      setState(() {
        _typing = false;
        _busy = true;
      });
      try {
        // "#12 paid" looks for "#12" (the words that say what to do are not searched)
        final d = obj((await ref.read(apiProvider).get(widget.admin ? '${Api.admin}/bizi/search' : '${Api.user}/search', {'q': verbOf(term)?.rest ?? term}))['data']);
        if (!mounted || n != _ask) return;
        setState(() {
          _offline = false;
          _apiQ = term;
          _smart = (d['smart'] as List? ?? const []).map((e) => '$e').toList();
          _fuzzy = d['fuzzy'] == true;
          _api = objs(d['results']).where((r) => widget.admin || r['group'] != 'businesses').toList();
        });
      } catch (_) {
        if (mounted && n == _ask) setState(() => _offline = true);
      } finally {
        if (mounted && n == _ask) setState(() => _busy = false);
      }
    });
  }

  List<Json> _businesses() {
    if (widget.admin) return const []; // the BizHub team has no businesses of its own
    final own = objs(ref.watch(dashboardProvider).valueOrNull?['businesses']);
    final shared = objs(obj(ref.watch(sharedProvider).valueOrNull)['businesses']).where((b) => b['team_on'] == true).map((b) => {...b, 'shared': true});
    return [...own, ...shared];
  }

  List<Json> _recent() {
    try {
      final v = jsonDecode(prefStr(_recentKey) ?? '[]');
      return v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).take(6).toList() : const [];
    } catch (_) {
      return const [];
    }
  }

  void _remember(_Row r) {
    if (r.run != null || r.help != null || r.kind == 'alert') return;
    final keep = r.toRecent();
    final list = [
      keep,
      ..._recent().where((x) => !(x['title'] == keep['title'] && x['route'] == keep['route'] && obj(x['business'])['_id'] == obj(keep['business'])['_id'] && x['tab'] == keep['tab'])),
    ].take(6).toList();
    prefSetStr(_recentKey, jsonEncode(list));
  }

  void _go(_Row r) {
    final primary = _primaryOf(r);
    if (primary != null) {
      setState(() => _confirm = (row: '${r.group}:${r.id}', a: primary, title: r.title));
      return;
    }
    if (r.help != null || r.week != null) {
      setState(() {
        final open = _currentOpen(isQuestion(_term), r.id);
        _openQ = _term;
        _openId = open == r.id ? '' : r.id;
      });
      return;
    }
    if (r.run != null) {
      r.run!();
      return;
    }
    _remember(r);
    _openTarget(context, business: r.business, tab: r.tab, route: r.route);
  }

  void _openTarget(BuildContext context, {Json? business, String tab = '', String route = ''}) {
    final nav = GoRouter.of(context);
    nav.pop();
    if (business != null) {
      openBusiness(nav.routerDelegate.navigatorKey.currentContext ?? context, id: str(business['_id']), name: str(business['name']), category: str(business['category']), tab: tab);
    } else if (route.isNotEmpty) {
      const tabs = ['/o/home', '/o/business', '/o/wallet', '/o/more', '/a/dash', '/a/customers', '/a/businesses', '/a/coins', '/a/more'];
      if (tabs.any((t) => route == t || route.startsWith('$t?'))) {
        nav.go(route);
      } else {
        nav.push(route);
      }
    }
  }

  String? _currentOpen(bool asked, String? first) => _openQ == _term ? _openId : (asked ? first ?? '' : '');

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final lang = ref.watch(tProvider).lang;
    final en = T.of('en');
    final km = T.of('km');
    String typeName(String type, String l) => (l == 'km' ? km : en).or('sa.categoryNames.$type', type);
    String x(String k, [Map<String, Object?> v = const {}]) => biziT(lang, k, v);
    final term = _term;
    final ws = words(term);
    final list = _businesses();
    final brief = ref.watch(biziBriefProvider);
    final asked = isQuestion(term);

    _Row asBiz(Json b) => _Row(
      group: 'businesses',
      kind: 'business',
      id: str(b['_id']),
      title: str(b['name']),
      sub: [typeName(str(b['category']), lang), if (b['shared'] == true) x('shared')].join(' · '),
      business: b,
      logo: str(b['photo']).isNotEmpty ? str(b['photo']) : str(b['logo_url']),
    );

    final rows = <_Row>[];
    if (term.isEmpty) {
      // what Bizi has to say, then my recent picks, then my businesses
      var i = 0;
      for (final a in objs(brief?['alerts'])) {
        final n = a['n'] is num ? a['n'] as num : 0;
        final key = str(a['key']);
        final set = widget.admin ? 'adminAlerts' : 'alerts';
        final title = (n == 1 && biziHas(lang, '${set}1.$key') ? x('${set}1.$key') : x('$set.$key')).replaceAll('{n}', '$n');
        final b = list.where((y) => str(y['_id']) == str(a['business_id'])).firstOrNull;
        rows.add(
          _Row(
            group: 'says',
            kind: 'alert',
            id: 'a${i++}',
            title: title,
            sub: str(a['business']),
            level: str(a['level']),
            business: b ?? (str(a['business_id']).isEmpty ? null : {'_id': a['business_id'], 'name': a['business'], 'category': a['category']}),
            tab: str(a['tab']),
            route: str(a['href']).isNotEmpty ? _route(str(a['href'])) : (str(a['business_id']).isEmpty ? (widget.admin ? '/a/dash' : '/o/home') : ''),
          ),
        );
      }
      // things not set up yet: each opens its how-to, with that business's section
      for (final tp in objs(brief?['tips'])) {
        if (_hidden.contains('${tp['key']}:${tp['business_id']}')) continue;
        final a = helpList.where((h) => h['id'] == tp['help']).firstOrNull;
        rows.add(
          _Row(
            group: 'tips',
            kind: 'tip',
            id: 'tip:${tp['key']}:${tp['business_id']}',
            title: x('tips.${tp['key']}'),
            sub: str(tp['business']),
            icon: LucideIcons.wrench,
            help: a == null ? null : HelpHit(a, 0),
            tip: tp,
          ),
        );
      }
      // last week's report
      final wk = brief?['weekly'] is Map ? obj(brief!['weekly']) : null;
      if (wk != null) {
        final pct = wk['change_pct'];
        rows.add(
          _Row(
            group: 'week',
            kind: 'week',
            id: 'week',
            title: [
              x('weekTotal', {'money': biziMoney(wk['total'], str(wk['currency']))}),
              if (pct is num) x('weekChange', {'pct': pctOf(pct)}),
            ].join(' · '),
            sub: weekSub(wk, lang),
            icon: LucideIcons.calendarRange,
            week: wk,
          ),
        );
      }
      var r = 0;
      for (final h in _recent()) {
        final b = h['business'] is Map ? obj(h['business']) : null;
        rows.add(
          _Row(group: 'recent', kind: str(h['kind']), id: 'r${r++}', title: str(h['title']), sub: str(h['sub']), business: b, tab: str(h['tab']), route: str(h['route']), icon: LucideIcons.clock),
        );
      }
      rows.addAll(list.take(8).map(asBiz));
    } else {
      final all = <_Row>[];
      for (final (route, en, km) in widget.admin ? findAdminPages(term) : const <(String, String, String)>[]) {
        all.add(_Row(group: 'pages', kind: 'app', id: 'admin:$route', title: lang == 'km' ? km : en, sub: lang == 'km' ? en : km, route: route, icon: LucideIcons.layoutGrid));
      }
      for (final p in findPages(list, term, typeName)) {
        all.add(
          _Row(
            group: 'pages',
            kind: 'tab',
            id: '${p.business['_id']}:${p.tab}',
            title: lang == 'km' ? p.km : p.en,
            sub: [str(p.business['name']), lang == 'km' ? p.en : p.km].join(' · '),
            business: p.business,
            tab: p.tab,
          ),
        );
      }
      // two actions anyone may want from the box
      final dark = Theme.of(context).brightness == Brightness.dark;
      final acts = [
        (
          dark ? x('light') : x('dark'),
          'dark light mode night theme colour color ងងឹត ភ្លឺ ពណ៌',
          dark ? LucideIcons.sun : LucideIcons.moon,
          () => ref.read(prefsProvider.notifier).setTheme(dark ? ThemeMode.light : ThemeMode.dark),
        ),
        (lang == 'km' ? 'English' : 'ភាសាខ្មែរ', 'language khmer english lang ភាសា ខ្មែរ អង់គ្លេស', LucideIcons.languages, () => ref.read(prefsProvider.notifier).setLang(lang == 'km' ? 'en' : 'km')),
      ];
      for (final (title, more, icon, run) in acts) {
        if (ws.every((w) => hit(w, '$title $more'.toLowerCase()) > 0)) all.add(_Row(group: 'pages', kind: 'action', id: title, title: title, sub: x('action'), icon: icon, run: run));
      }
      for (final h in findHelp(term, list: widget.admin ? adminHelpList : null)) {
        all.add(_Row(group: 'help', kind: 'help', id: h.id, title: h.q(lang), sub: x('helpSub'), help: h, icon: LucideIcons.lifeBuoy));
      }
      for (final b in list.where((b) => ws.every((w) => hit(w, '${b['name']} ${typeName(str(b['category']), 'en')} ${typeName(str(b['category']), 'km')}'.toLowerCase()) > 0)).take(6)) {
        all.add(asBiz(b));
      }
      if (_apiQ == term) {
        for (final it in _api) {
          final b = list.where((y) => str(y['_id']) == str(it['business_id'])).firstOrNull ?? {'_id': it['business_id'], 'name': it['business'], 'category': it['category']};
          all.add(
            _Row(
              group: it['smart'] == true ? 'smart' : str(it['group']),
              kind: str(it['kind']),
              id: str(it['id']),
              title: str(it['title']),
              sub: [str(it['business']), str(it['sub']), if (widget.admin && it['kind'] == 'business') typeName(str(it['category']), lang)].where((s) => s.isNotEmpty).join(' · '),
              business: str(it['href']).isNotEmpty ? null : b,
              route: str(it['href']).isNotEmpty ? _route(str(it['href'])) : '',
              tab: str(it['tab']),
              status: str(it['status']),
              flag: str(it['flag']),
              money: it['money'],
              cur: str(it['cur']),
            ),
          );
        }
      }
      for (final g in widget.admin ? (asked ? _adminGroupsAsked : _adminGroups) : (asked ? _groupsAsked : _groups)) {
        rows.addAll(all.where((r) => r.group == g));
      }
    }

    final help = rows.where((r) => r.help != null).toList();
    final openId = _currentOpen(asked, help.firstOrNull?.id) ?? '';
    final waiting = _typing || _busy;
    final mood = term.isEmpty
        ? BiziMood.idle
        : waiting
        ? BiziMood.thinking
        : rows.isNotEmpty
        ? BiziMood.happy
        : BiziMood.worried;

    String head(String g) => switch (g) {
      'smart' => '${x('groups.smart')} · ${(_apiQ == term ? _smart : const <String>[]).map((k) => biziT(lang, 'smart.$k')).join(' · ')}',
      'says' => x('says'),
      'tips' => x('tipsHead'),
      'week' => x('weekHead'),
      'recent' => x('recent'),
      'businesses' when term.isEmpty => x('quick'),
      _ => widget.admin && biziHas(lang, 'adminGroups.$g') ? x('adminGroups.$g') : x('groups.$g'),
    };

    final children = <Widget>[];
    // the empty box: what Bizi has to say first, then the chips, then recent + my businesses
    final start = <Widget>[];
    if (term.isEmpty) {
      start.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
          child: Text(x(widget.admin ? 'adminStart' : 'start'), style: TextStyle(color: c.muted, fontSize: 14, height: 1.45)),
        ),
      );
      start.add(_Chips(icon: LucideIcons.sparkles, label: x('try'), items: [for (final (v, l) in widget.admin ? adminSuggestions(lang) : suggestions(lang)) (l, () => _q.text = v)]));
      start.add(
        _Chips(
          icon: LucideIcons.lifeBuoy,
          label: x('questions'),
          keyPrefix: 'bizi-ask',
          items: [for (final a in (widget.admin ? adminHelpList : helpList).where((a) => a['popular'] == true).take(4)) (HelpHit(a, 0).q(lang), () => _q.text = HelpHit(a, 0).q(lang))],
        ),
      );
      if (!widget.admin) {
        start.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Text(x('actHint'), style: TextStyle(color: c.muted, fontSize: 12.5)),
          ),
        );
      }
    }
    if (term.isNotEmpty && !waiting && _fuzzy && _apiQ == term) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            x('fuzzy', {'q': term}),
            style: TextStyle(color: c.muted, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    String last = '';
    var started = false;
    for (final r in rows) {
      if (!started && r.group != 'says') {
        started = true;
        children.addAll(start);
      }
      if (r.group != last) {
        last = r.group;
        final hot = const {'smart', 'says', 'help', 'tips', 'week'}.contains(r.group);
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
            child: Text(
              head(r.group).toUpperCase(),
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .6, color: hot ? c.brandInk : c.muted),
            ),
          ),
        );
      }
      final open = (r.help != null || r.week != null) && openId == r.id;
      children.add(_RowTile(row: r, open: open, lang: lang, statusWord: r.status.isEmpty ? '' : biziT(lang, 'status.${r.status}'), flagWord: r.flag.isEmpty ? '' : x(r.flag), onTap: () => _go(r)));
      final acts = _actionsOf(r);
      if (acts.isNotEmpty) {
        final key = '${r.group}:${r.id}';
        final asking = _confirm?.row == key ? _confirm : null;
        final primary = _primaryOf(r)?.key;
        children.add(
          _ActsBar(
            key: ValueKey('bizi-acts-$key'),
            lang: lang,
            acts: acts,
            primary: primary,
            asking: asking == null ? null : (asking.a, asking.title),
            busy: _acting,
            onPick: (a) => setState(() => _confirm = (row: key, a: a, title: r.title)),
            onYes: _runConfirm,
            onNo: () => setState(() => _confirm = null),
          ),
        );
      }
      if (open && r.week != null) children.add(_WeekCard(wk: r.week!, lang: lang));
      if (open && r.help != null) {
        final tp = r.tip;
        children.add(
          _HelpCard(
            hit: r.help!,
            lang: lang,
            list: list,
            to: tp == null ? null : HelpTarget(business: {'_id': tp['business_id'], 'name': tp['business'], 'category': tp['category']}, tab: str(tp['tab'])),
            onLater: tp == null ? null : () => _snooze(tp),
            team: widget.admin,
            onOpen: (target) => _openTarget(context, business: target.business, tab: target.tab, route: target.route),
          ),
        );
      }
    }
    if (!started) children.addAll(start);
    if (term.isNotEmpty && waiting) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(x('busy'), style: TextStyle(color: c.muted)),
        ),
      );
    }
    if (term.isNotEmpty && !waiting && _offline) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(x('offline'), style: TextStyle(color: c.muted)),
        ),
      );
    }
    if (term.isNotEmpty && !waiting && !_offline && rows.isEmpty) {
      children.add(
        Padding(
          key: const ValueKey('bizi-none'),
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
          child: Column(
            children: [
              Text(
                x('empty', {'q': term}),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                asked && !widget.admin ? x('helpNone') : x('emptySub'),
                textAlign: TextAlign.center,
                style: TextStyle(color: c.muted, fontSize: 13.5),
              ),
              if (asked && !widget.admin) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => _openTarget(context, route: '/o/support'),
                  icon: Icon(LucideIcons.messageCircle, size: 16, color: c.brandInk),
                  label: Text(
                    x('helpAsk'),
                    style: TextStyle(color: c.brandInk, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.appBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: c.card, shape: BoxShape.circle, boxShadow: c.cardShadow),
                    alignment: Alignment.center,
                    child: BiziFace(mood: _typing || _listening ? BiziMood.listening : mood, size: 40),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.brand, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.search, size: 18, color: c.muted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              key: const ValueKey('bizi-input'),
                              controller: _q,
                              focusNode: _focus,
                              autofocus: true,
                              textInputAction: TextInputAction.search,
                              autocorrect: false,
                              onSubmitted: (_) {
                                if (_confirm != null) {
                                  _runConfirm();
                                } else if (rows.isNotEmpty) {
                                  _go(rows.first);
                                }
                              },
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.ink),
                              decoration: InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                hintText: _listening ? x('voiceOn') : x(widget.admin ? 'adminPh' : 'ph'),
                                hintStyle: TextStyle(color: c.muted, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                          if (_q.text.isNotEmpty && !_listening)
                            GestureDetector(
                              onTap: () => _q.clear(),
                              child: Icon(LucideIcons.circleX, size: 18, color: c.muted),
                            ),
                          const SizedBox(width: 6),
                          Semantics(
                            button: true,
                            toggled: _listening,
                            label: x('voice'),
                            child: GestureDetector(
                              key: const ValueKey('bizi-mic'),
                              onTap: _voice,
                              child: Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: _listening ? c.dangerBg : c.chip, shape: BoxShape.circle),
                                child: Icon(LucideIcons.mic, size: 18, color: _listening ? c.danger : c.brandInk),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!widget.admin) ...[
                    RoundBtn(LucideIcons.settings2, key: const ValueKey('bizi-gear'), size: 44, tip: x('settings'), onTap: () => setState(() => _settings = !_settings)),
                    const SizedBox(width: 8),
                  ],
                  RoundBtn(LucideIcons.x, size: 44, tip: x('close'), onTap: () => context.pop()),
                ],
              ),
            ),
            if (_settings)
              Expanded(
                child: BiziSettingsView(
                  onBack: () => setState(() => _settings = false),
                  onChanged: _reloadBrief,
                  more: (p, save, reload) => BiziTelegramSection(
                    prefs: p,
                    save: save,
                    reload: reload,
                    open: (u) async {
                      final f = BiziPage.openUrl;
                      if (f != null) return f(u);
                      await launchUrl(u, mode: LaunchMode.externalApplication);
                    },
                  ),
                ),
              ),
            if (!_settings)
              Expanded(
                child: ListView(
                  key: const ValueKey('bizi-list'),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 24 + MediaQuery.of(context).padding.bottom),
                  children: children,
                ),
              ),
            if (term.isEmpty && !_settings && !widget.admin)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Text(
                  x('soon'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<(String, VoidCallback)> items;
  final String keyPrefix;
  const _Chips({required this.icon, required this.label, required this.items, this.keyPrefix = 'bizi-sugg'});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: c.brandInk),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(color: c.brandInk, fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ],
          ),
          for (final (i, (text, onTap)) in items.indexed)
            Material(
              color: c.card,
              shape: StadiumBorder(side: BorderSide(color: c.line)),
              child: InkWell(
                key: ValueKey('$keyPrefix-$i'),
                customBorder: const StadiumBorder(),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  final _Row row;
  final bool open;
  final String lang, statusWord, flagWord;
  final VoidCallback onTap;
  const _RowTile({required this.row, required this.open, required this.lang, required this.statusWord, required this.flagWord, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final warn = row.level == 'warn';
    final icon = row.kind == 'action' || row.group == 'recent' ? row.icon : (_kindIcon[row.kind] ?? row.icon);
    final (bg, fg) = switch (row.kind) {
      'help' => (c.dark ? const Color(0x2E3B82F6) : const Color(0xFFE8F1FF), c.dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
      'tip' => (c.dark ? const Color(0x29EAB308) : const Color(0xFFFFF4D6), c.dark ? const Color(0xFFFCD34D) : const Color(0xFF8A5A00)),
      _ when warn => (c.dangerBg, c.danger),
      'alert' || 'action' || 'app' || 'order' || 'stay' || 'week' => (c.active, c.brandInk),
      _ => (c.chip, c.brandInk),
    };
    final money = row.money == null || '${row.money}'.isEmpty ? '' : biziMoney(row.money, row.cur.isEmpty ? 'USD' : row.cur);
    return Material(
      color: open ? c.active : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey('bizi-row-${row.group}-${row.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
                alignment: Alignment.center,
                child: row.kind == 'business' && row.logo.isEmpty && row.business != null
                    ? TypeIcon(str(row.business!['category']), size: 38)
                    : (row.logo.isNotEmpty
                          ? Image.network(
                              row.logo,
                              fit: BoxFit.cover,
                              width: 38,
                              height: 38,
                              errorBuilder: (_, _, _) => Icon(icon, size: 18, color: fg),
                            )
                          : Icon(icon, size: 18, color: fg)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    if (row.sub.isNotEmpty)
                      Text(
                        row.sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.muted, fontSize: 12.5),
                      ),
                  ],
                ),
              ),
              if (flagWord.isNotEmpty) ...[const SizedBox(width: 6), Chip2(flagWord, tone: Tone.warn)],
              if (statusWord.isNotEmpty && statusWord != 'status.${row.status}') ...[const SizedBox(width: 6), Chip2(statusWord)],
              if (money.isNotEmpty) ...[const SizedBox(width: 8), Text(money, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5))],
              if (row.kind == 'help' || row.kind == 'tip' || row.kind == 'week') ...[const SizedBox(width: 4), Icon(open ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 18, color: c.muted)],
            ],
          ),
        ),
      ),
    );
  }
}

// the answer under a how-to: the steps, a button to that screen (my first business of that type), and the team
class _HelpCard extends StatelessWidget {
  final HelpHit hit;
  final String lang;
  final List<Json> list;
  final void Function(HelpTarget) onOpen;
  final HelpTarget? to; // a tip: that business, not my first one of the type
  final VoidCallback? onLater; // a tip: "Not now"
  final bool team; // the BizHub team: no "chat with the BizHub team"
  const _HelpCard({required this.hit, required this.lang, required this.list, required this.onOpen, this.to, this.onLater, this.team = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    String x(String k) => biziT(lang, k);
    var steps = hit.steps(lang);
    // on a phone coins come from the store, not a bank transfer
    if (hit.id == 'coins_buy' && playBilling) {
      final store = !kIsWeb && Platform.isIOS ? 'App Store' : 'Google Play';
      steps = (_appWords[lang]?['storeSteps'] ?? _appWords['en']!['storeSteps']!).map((s) => s.replaceAll('{store}', store)).toList();
    }
    final to = this.to ?? targetOf(hit.a, list);
    return Container(
      key: const ValueKey('bizi-help'),
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, s) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 10, top: 1),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.active, shape: BoxShape.circle),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.brandInk),
                    ),
                  ),
                  Expanded(child: Text(s, style: const TextStyle(fontSize: 14, height: 1.45))),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (to != null)
                Btn(
                  key: const ValueKey('bizi-help-go'),
                  to.add ? x('helpAdd') : (hit.open(lang).isNotEmpty ? hit.open(lang) : x('helpGo')),
                  icon: LucideIcons.arrowUpRight,
                  small: true,
                  onTap: () => onOpen(to),
                ),
              if (onLater != null)
                TextButton(
                  key: const ValueKey('bizi-later'),
                  onPressed: onLater,
                  child: Text(
                    x('notNow'),
                    style: TextStyle(color: c.brandInk, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                )
              else if (!team)
                TextButton.icon(
                  onPressed: () => onOpen(const HelpTarget(route: '/o/support')),
                  icon: Icon(LucideIcons.messageCircle, size: 16, color: c.brandInk),
                  label: Text(
                    x('helpAsk'),
                    style: TextStyle(color: c.brandInk, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
            ],
          ),
          if (to?.business != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(str(to!.business!['name']), style: TextStyle(color: c.muted, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

String pctOf(num n) => '${n > 0 ? '+' : ''}$n%';
String _dayOf(String day, String lang) => weekDay(day, lang);

String weekSub(Json wk, String lang) {
  final best = wk['best_day'] is Map ? obj(wk['best_day']) : null;
  final top = objs(wk['top']);
  return [
    if (best != null) biziT(lang, 'weekBest', {'day': _dayOf(str(best['day']), lang), 'money': biziMoney(best['sales'], str(wk['currency']))}),
    if (top.isNotEmpty) biziT(lang, 'weekTop', {'name': top.first['name'], 'qty': top.first['qty']}),
  ].join(' · ');
}

// last week, opened: the money, the best day, the best sellers, which businesses went up / down
List<String> weekLines(Json wk, String lang) {
  final pct = wk['change_pct'];
  final best = wk['best_day'] is Map ? obj(wk['best_day']) : null;
  final top = objs(wk['top']);
  return [
    biziT(lang, 'weekTotal', {'money': biziMoney(wk['total'], str(wk['currency']))}) + (pct is num ? ' · ${biziT(lang, 'weekChange', {'pct': pctOf(pct)})}' : ''),
    if (best != null) biziT(lang, 'weekBest', {'day': _dayOf(str(best['day']), lang), 'money': biziMoney(best['sales'], str(wk['currency']))}),
    if (top.isNotEmpty) biziT(lang, 'weekTops', {'list': top.map((t) => '${t['name']} ×${t['qty']}').join(' · ')}),
    for (final b in objs(wk['up'])) biziT(lang, 'weekUp', {'name': b['name'], 'pct': pctOf(b['change_pct'] as num)}),
    for (final b in objs(wk['down'])) biziT(lang, 'weekDown', {'name': b['name'], 'pct': pctOf(b['change_pct'] as num)}),
  ];
}

class _WeekCard extends StatelessWidget {
  final Json wk;
  final String lang;
  const _WeekCard({required this.wk, required this.lang});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      key: const ValueKey('bizi-week'),
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in weekLines(wk, lang))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 10),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
                    ),
                  ),
                  Expanded(child: Text(l, style: const TextStyle(fontSize: 14, height: 1.45))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// the quick actions under a result, or the question before doing one ("Mark order #12 paid?  Yes · No")
class _ActsBar extends StatelessWidget {
  final String lang;
  final List<BiziAction> acts;
  final String? primary;
  final (BiziAction, String)? asking;
  final bool busy;
  final void Function(BiziAction) onPick;
  final VoidCallback onYes, onNo;
  const _ActsBar({super.key, required this.lang, required this.acts, required this.primary, required this.asking, required this.busy, required this.onPick, required this.onYes, required this.onNo});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget chip(String text, VoidCallback? onTap, {bool strong = false, bool solid = false, Key? key}) => Material(
      color: solid ? c.brand : c.card,
      shape: StadiumBorder(side: BorderSide(color: strong || solid ? c.brand : c.line)),
      child: InkWell(
        key: key,
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            text,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: solid ? Colors.white : (strong ? c.brandInk : c.ink)),
          ),
        ),
      ),
    );
    final a = asking;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.fromLTRB(58, a == null ? 0 : 8, 8, a == null ? 4 : 10),
      decoration: a == null ? null : BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(14)),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: a == null
            ? [for (final x in acts) chip(biziT(lang, 'act.${x.key}'), () => onPick(x), strong: x.key == primary, key: ValueKey('bizi-act-${x.key}'))]
            : [
                Text(biziT(lang, 'actAsk.${a.$1.key}', {'t': a.$2}), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                chip(biziT(lang, 'yes'), busy ? null : onYes, solid: true, key: const ValueKey('bizi-yes')),
                chip(biziT(lang, 'no'), onNo, key: const ValueKey('bizi-no')),
              ],
      ),
    );
  }
}
