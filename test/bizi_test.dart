// Bizi in the owner app (v3.0.0): the same answers as the website (the how-to cases of bizhub/tool/test-bizi-help.mjs),
// the bubble over the owner tabs (red dot, daily summary, drag), and the search screen (Bizi says, questions, a how-to
// with its Open button, sections, the server's results, nothing found). Pictures: test/shots/bizi-*.png
import 'package:bizhub_admin/core/api.dart';
import 'package:bizhub_admin/core/i18n.dart';
import 'package:bizhub_admin/core/providers.dart';
import 'package:bizhub_admin/core/theme.dart';
import 'package:bizhub_admin/features/bizi/bizi_bubble.dart';
import 'package:bizhub_admin/features/bizi/bizi_data.dart';
import 'package:bizhub_admin/features/bizi/bizi_face.dart';
import 'package:bizhub_admin/features/bizi/bizi_find.dart';
import 'package:bizhub_admin/features/bizi/bizi_page.dart';
import 'package:bizhub_admin/features/bizi/bizi_voice.dart';
import 'package:bizhub_admin/features/common/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nc_recipes_test.dart' show loadFonts;

const _coffee = {'_id': 'b1', 'name': 'Mekong Coffee Shop', 'category': 'tg_store', 'logo_url': ''};
const _kitchen = {'_id': 'b2', 'name': 'Mekong Kitchen', 'category': 'restaurant', 'logo_url': ''};
const _mart = {'_id': 'b3', 'name': 'Lucky Mini Mart', 'category': 'mart', 'logo_url': ''};

class _Api extends Api {
  _Api() : super(token: () => 't', onUnauthorized: () {});
  final calls = <String>[];
  num pulse = 3;
  bool weekly = true;
  final mute = <String>[];
  final snoozed = <String>[];
  bool tgOn = false;
  String o12 = 'new'; // order #12: its status, and paid or not
  bool o12Paid = false;
  final tg = <String, dynamic>{'morning': true, 'alerts': true, 'weekly': true};
  Json _ok(Object? data) => {'success': true, 'data': data};

  @override
  Future<Json> get(String path, [Map<String, dynamic>? query]) async {
    calls.add('GET $path${query == null ? '' : ' $query'}');
    if (path.endsWith('/dashboard')) {
      return _ok({
        'businesses': [_coffee, _kitchen, _mart],
        'coins': {'balance': 20},
      });
    }
    if (path.endsWith('/team/shared')) return _ok({'businesses': [], 'invites': []});
    if (path.endsWith('/bizi/brief') && path.startsWith('/api/user')) {
      return _ok({
        'summary': {'currency': 'USD', 'today': 12.5, 'yesterday': 0, 'week': 12.5, 'last_week': 0, 'change_pct': null, 'bills_today': 3, 'orders_today': 1},
        'pulse': pulse,
        'alerts': [
          {'key': 'tg_new', 'level': 'warn', 'n': 1, 'business_id': 'b1', 'business': 'Mekong Coffee Shop', 'category': 'tg_store', 'tab': 'orders'},
          {'key': 'sold_out', 'level': 'warn', 'n': 2, 'business_id': 'b1', 'business': 'Mekong Coffee Shop', 'category': 'tg_store', 'tab': 'products'},
          {'key': 'renewals', 'level': 'info', 'n': 1, 'href': '/app/licenses'},
        ],
        'mood': 'worried',
        'tips': [
          for (final t in [
            {'key': 'tg_no_group', 'business_id': 'b1', 'business': 'Mekong Coffee Shop', 'category': 'tg_store', 'tab': 'share', 'help': 'tg_group'},
            {'key': 'rest_no_tables', 'business_id': 'b2', 'business': 'Mekong Kitchen', 'category': 'restaurant', 'tab': 'tables', 'help': 'tables_qr'},
          ])
            if (!snoozed.contains('${t['key']}:${t['business_id']}')) t,
        ],
        'weekly': weekly
            ? {
                'week': '2026-10-19',
                'from': '2026-10-19',
                'to': '2026-10-25',
                'currency': 'USD',
                'total': 25,
                'bills': 3,
                'before': 20,
                'change_pct': 25,
                'best_day': {'day': '2026-10-21', 'sales': 18},
                'top': [
                  {'name': 'Khmer iced coffee', 'qty': 9, 'business': 'Mekong Coffee Shop'},
                  {'name': 'Croissant', 'qty': 4, 'business': 'Mekong Coffee Shop'},
                ],
                'up': [
                  {'id': 'b1', 'name': 'Mekong Coffee Shop', 'total': 25, 'before': 20, 'change_pct': 25},
                ],
                'down': [],
              }
            : null,
      });
    }
    if (path.endsWith('/bizi/prefs')) return _ok(_prefs);
    if (path == '/api/admin/bizi/brief') {
      return _ok({
        'summary': {'new_customers': 3, 'new_businesses': 2, 'sold_usd': 15, 'sold_orders': 1, 'waiting': 1},
        'pulse': 7,
        'alerts': [
          {'key': 'coin_orders', 'n': 1, 'level': 'warn', 'href': '/app/super-admin/coin-orders?status=pending'},
          {'key': 'chats', 'n': 2, 'level': 'warn', 'href': '/app/super-admin/inbox'},
          {'key': 'app_errors', 'n': 1, 'level': 'info', 'href': '/app/super-admin/dashboard'},
        ],
        'mood': 'worried',
        'tips': [],
        'weekly': null,
      });
    }
    if (path == '/api/admin/bizi/search') {
      final q = '${query?['q']}';
      return _ok({
        'q': q,
        'smart': q == 'pending' ? ['pending'] : [],
        'results': [
          if (q == 'pending')
            {
              'group': 'orders',
              'kind': 'coin_order',
              'id': 'c1',
              'title': '#a1b2c3 · 110 coins',
              'sub': 'Sokha · ABA-778899',
              'money': 10,
              'cur': 'USD',
              'status': 'pending',
              'href': '/app/super-admin/coin-orders?status=pending',
              'smart': true,
            },
          if (q == 'sokha') ...[
            {'group': 'people', 'kind': 'person', 'id': 'p1', 'title': 'Sokha Chan', 'sub': 'sokha@test.com · BH-437835', 'href': '/app/super-admin/customers?open=p1'},
            {'group': 'businesses', 'kind': 'business', 'id': 'b1', 'title': 'Mekong Coffee Shop', 'sub': 'Sokha Chan', 'category': 'tg_store', 'href': '/app/super-admin/businesses?open=b1'},
          ],
        ],
      });
    }
    if (path.endsWith('/search') && path.startsWith('/api/user')) {
      final q = '${query?['q']}';
      if (q.contains('coffee') || q.contains('cofee')) {
        return _ok({
          'q': q,
          'smart': [],
          'fuzzy': q.contains('cofee'),
          'results': [
            {
              'group': 'products',
              'kind': 'product',
              'id': 'p1',
              'business_id': 'b1',
              'business': 'Mekong Coffee Shop',
              'category': 'tg_store',
              'title': 'Khmer iced coffee',
              'sub': 'Coffee',
              'money': 2.5,
              'cur': 'USD',
              'tab': 'products',
              'flag': 'sold_out',
            },
          ],
        });
      }
      if (q == '#12') {
        return _ok({
          'q': q,
          'smart': [],
          'fuzzy': false,
          'results': [
            {
              'group': 'orders',
              'kind': 'order',
              'id': 'o1',
              'business_id': 'b1',
              'business': 'Mekong Coffee Shop',
              'category': 'tg_store',
              'title': '#12',
              'sub': 'Emma Wilson',
              'money': 6.5,
              'cur': 'USD',
              'tab': 'orders',
              'status': o12,
              'flag': o12Paid ? '' : 'unpaid',
            },
          ],
        });
      }
      if (q.contains('new')) {
        return _ok({
          'q': q,
          'smart': ['new'],
          'fuzzy': false,
          'results': [
            {
              'group': 'orders',
              'kind': 'order',
              'id': 'o1',
              'business_id': 'b1',
              'business': 'Mekong Coffee Shop',
              'category': 'tg_store',
              'title': '#12',
              'sub': 'Emma Wilson',
              'money': 6.5,
              'cur': 'USD',
              'tab': 'orders',
              'status': 'new',
              'smart': true,
            },
          ],
        });
      }
      return _ok({'q': q, 'smart': [], 'fuzzy': false, 'results': []});
    }
    return _ok({});
  }

  Json get _prefs => {
    'mute': mute,
    'weekly': weekly,
    'tg': {'configured': true, 'connected': tgOn, 'chat_name': tgOn ? 'Sokha' : '', ...tg},
    'keys': {
      'alerts': ['tg_new', 'waiting', 'sold_out', 'low_stock', 'renewals'],
      'tips': ['tg_no_group', 'rest_no_tables'],
    },
  };

  @override
  Future<Json> put(String path, [Object? body]) async {
    calls.add('PUT $path $body');
    final b = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    if (b['mute'] is List)
      mute
        ..clear()
        ..addAll((b['mute'] as List).map((e) => '$e'));
    if (b['weekly'] is bool) weekly = b['weekly'] as bool;
    if (b['tg'] is Map) tg.addAll(Map<String, dynamic>.from(b['tg'] as Map));
    return _ok(_prefs);
  }

  @override
  Future<Json> post(String path, [Object? body]) async {
    calls.add('POST $path $body');
    final b = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    if (path.endsWith('/bizi/snooze')) snoozed.add('${b['key']}:${b['business_id']}');
    if (path.endsWith('/tgstore/orders/o1/paid')) o12Paid = true;
    if (path.endsWith('/tgstore/orders/o1/status')) o12 = '${b['status']}';
    if (path.endsWith('/bizi/telegram/link')) return _ok({'url': 'https://t.me/BizHubTestBot?start=bz_abc'});
    return _ok({'days': 14});
  }

  @override
  Future<Json> delete(String path, [Object? body]) async {
    calls.add('DELETE $path');
    if (path.endsWith('/bizi/telegram')) tgOn = false;
    return _ok({});
  }
}

// the phone's speech-to-text, faked: says the words one after the other
class _Voice implements BiziVoice {
  final List<String> say;
  bool ok;
  String? lang;
  _Voice(this.say, {this.ok = true});
  @override
  Future<bool> start(String lang, void Function(String words, bool done) onWords, {void Function()? onEnd}) async {
    this.lang = lang;
    if (!ok) return false;
    for (var i = 0; i < say.length; i++) {
      Future<void>.delayed(Duration(milliseconds: 300 * (i + 1)), () => onWords(say[i], i == say.length - 1));
    }
    return true;
  }

  @override
  Future<void> stop() async {}
}

class _Me extends SessionNotifier {
  @override
  Session? build() => const Session({'name': 'Sokha', 'email': 'sokha@example.com', 'access_token': 't', 'coin_balance': 20, 'account_type': 'customer'});
}

Widget _stub(String text) => Scaffold(
  body: SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(text, key: const ValueKey('stub')),
    ),
  ),
);

Widget _app(_Api api, {String lang = 'en', bool dark = false, String start = '/o/home'}) {
  final router = GoRouter(
    initialLocation: start,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, nav) => AppShell(nav: nav, admin: false),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/o/home',
                builder: (_, _) => const Center(child: Text('HOME')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/o/business',
                builder: (_, _) => const Center(child: Text('BUSINESSES')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/o/wallet',
                builder: (_, _) => const Center(child: Text('WALLET')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/o/more',
                builder: (_, _) => const Center(child: Text('MORE')),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/o/bizi', builder: (_, _) => const BiziPage()),
      GoRoute(path: '/o/support', builder: (_, _) => _stub('SUPPORT')),
      GoRoute(path: '/o/licenses', builder: (_, _) => _stub('LICENSES')),
      GoRoute(path: '/o/coins', builder: (_, _) => _stub('COINS')),
      GoRoute(path: '/biz/:kind/:id', builder: (_, s) => _stub('BUSINESS ${s.pathParameters['kind']} ${s.pathParameters['id']} tab=${s.uri.queryParameters['tab'] ?? ''}')),
    ],
  );
  return ProviderScope(
    overrides: [apiProvider.overrideWithValue(api), tProvider.overrideWithValue(T.of(lang)), sessionProvider.overrideWith(_Me.new)],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(dark: dark, khmer: lang == 'km'),
      routerConfig: router,
    ),
  );
}

class _Boss extends SessionNotifier {
  @override
  Session? build() => const Session({'name': 'Black', 'email': 'boss@bizhub.test', 'access_token': 't', 'account_type': 'team', 'is_super_admin': true});
}

Widget _adminApp(_Api api, {String lang = 'en'}) {
  final router = GoRouter(
    initialLocation: '/a/dash',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, nav) => AppShell(nav: nav, admin: true),
        branches: [
          for (final p in ['/a/dash', '/a/customers', '/a/businesses', '/a/coins', '/a/more'])
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: p,
                  builder: (_, _) => Center(child: Text('TAB $p')),
                ),
              ],
            ),
        ],
      ),
      GoRoute(path: '/a/bizi', builder: (_, _) => const BiziPage(admin: true)),
      GoRoute(path: '/a/orders', builder: (_, _) => _stub('ORDERS')),
      GoRoute(path: '/a/prices', builder: (_, _) => _stub('PRICES')),
      GoRoute(path: '/a/inbox', builder: (_, _) => _stub('INBOX')),
      GoRoute(path: '/a/customer/:id', builder: (_, s) => _stub('CUSTOMER ${s.pathParameters['id']}')),
    ],
  );
  return ProviderScope(
    overrides: [apiProvider.overrideWithValue(api), tProvider.overrideWithValue(T.of(lang)), sessionProvider.overrideWith(_Boss.new)],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(dark: false, khmer: lang == 'km'),
      routerConfig: router,
    ),
  );
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _shot(WidgetTester t, String name) => expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/bizi-$name.png'));

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await PrefsNotifier.init();
    await T.load();
    await loadFonts();
    BiziFace.animate = false;
  });

  Future<void> phone(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(400, 860));
    t.view.devicePixelRatio = 2;
    t.view.physicalSize = const Size(800, 1720);
    addTearDown(t.view.reset);
  }

  group('the same answers as the website', () {
    String? top(String q) => findHelp(q).firstOrNull?.id;
    test('every how-to finds itself (EN + KM)', () {
      for (final a in helpList) {
        final h = HelpHit(a, 0);
        expect(top(h.q('en')), h.id, reason: h.q('en'));
        expect(top(h.q('km')), h.id, reason: h.q('km'));
        expect(h.steps('km').length, h.steps('en').length, reason: h.id);
      }
    });
    test('what people type', () {
      const cases = {
        'how do I pair a POS?': 'pos_pair',
        'how to connect pos': 'pos_pair',
        'link tablet': 'pos_pair',
        'ធ្វើម៉េចភ្ជាប់ POS': 'pos_pair',
        'how to buy coins': 'coins_buy',
        'top up': 'coins_buy',
        'ទិញកាក់យ៉ាងម៉េច': 'coins_buy',
        'prnter setup': 'printer',
        'ភ្ជាប់ម៉ាស៊ីនព្រីន': 'printer',
        'telegram group orders': 'tg_group',
        'where is my store link': 'tg_share',
        'ថ្លៃដឹក': 'tg_delivery',
        'how to make a promo code': 'tg_promo',
        'ធ្វើម៉េចបង្កើតកូដបញ្ចុះតម្លៃ': 'tg_promo',
        'excel report': 'report_excel',
        'how to add team member': 'team_add',
        'where is my bizhub id': 'my_id',
        'dark mode how': 'look',
      };
      cases.forEach((q, id) => expect(top(q), id, reason: q));
      expect(findHelp('coffee'), isEmpty);
      expect(findHelp('how do I fly to the moon?'), isEmpty);
      expect(isQuestion('ធ្វើម៉េចភ្ជាប់ POS') && !isQuestion('coffee'), isTrue);
    });
    test('Open goes to my business of that type, or an app screen', () {
      final pos = helpList.firstWhere((a) => a['id'] == 'pos_pair');
      final t1 = targetOf(pos, [_coffee, _kitchen])!;
      expect((t1.business?['_id'], t1.tab), ('b1', 'staff'));
      expect(targetOf(pos, [_kitchen])!.tab, 'pos');
      expect(targetOf(pos, [])!.add, isTrue);
      expect(targetOf(helpList.firstWhere((a) => a['id'] == 'coins_buy'), [])!.route, '/o/coins');
      expect(targetOf(helpList.firstWhere((a) => a['id'] == 'team_add'), [_kitchen])!.route, '/o/team/b2');
    });
    test('sections: more words + a typing mistake, only sections the app has', () {
      String name(String type, String lang) => type;
      final fee = findPages([_coffee, _mart], 'delivry', name);
      expect(fee.map((p) => '${p.business['_id']}:${p.tab}'), contains('b1:delivery'));
      expect(findPages([_kitchen], 'printer', name).map((p) => p.tab), contains('receipt'));
      final pages = biziData['pages'] as Map;
      expect((pages['tg_store'] as List).map((p) => p[0]), containsAll(['orders', 'products', 'staff', 'share', 'store']));
      expect(biziT('km', 'groups.help'), 'របៀបធ្វើ');
      expect(biziT('en', 'needYou', {'n': 3}), '3 things need you');
    });
  });

  testWidgets('the bubble: red dot, daily summary, drag, tap → search', (t) async {
    await phone(t);
    SharedPreferences.setMockInitialValues({});
    await PrefsNotifier.init();
    final api = _Api();
    await t.pumpWidget(_app(api));
    await _settle(t);
    expect(find.byKey(const ValueKey('bizi-bubble')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('bizi-dot')), matching: find.text('2')), findsOneWidget); // 2 warnings
    // a new week: last week's report comes first (once)
    expect(find.byKey(const ValueKey('bizi-note')), findsOneWidget);
    expect(find.text('Last week'), findsOneWidget);
    expect(find.textContaining('\$25.00 · +25% vs the week before'), findsOneWidget);
    expect(find.text('Best day: Wed 21 · \$18.00'), findsOneWidget);
    expect(find.text('Best seller: Khmer iced coffee ×9'), findsOneWidget);
    expect(find.text('Up: Mekong Coffee Shop +25%'), findsOneWidget);
    await _shot(t, 'bubble');
    // the report goes by itself, once a week
    await t.pump(const Duration(seconds: 21));
    expect(find.byKey(const ValueKey('bizi-note')), findsNothing);

    // drag it up-left; it stays there after a rebuild
    final from = t.getTopLeft(find.byKey(const ValueKey('bizi-bubble')));
    await t.drag(find.byKey(const ValueKey('bizi-bubble')), const Offset(-220, -300));
    await _settle(t);
    final to = t.getTopLeft(find.byKey(const ValueKey('bizi-bubble')));
    expect(to.dx, lessThan(from.dx - 150));
    expect(to.dy, lessThan(from.dy - 200));
    expect(prefStr('bizi_pos'), isNotNull);

    // a new order → happy for a moment
    api.pulse = 4;
    for (var i = 0; i < 70 && find.byKey(const ValueKey('bizi-note')).evaluate().isEmpty; i++) {
      await t.pump(const Duration(seconds: 1)); // the next minute's look
    }
    await _shot(t, 'happy');
    expect(find.text('A new sale or order just came in!'), findsOneWidget);
    await t.pump(const Duration(seconds: 7));

    await t.tap(find.byKey(const ValueKey('bizi-bubble')));
    await _settle(t);
    expect(find.byKey(const ValueKey('bizi-input')), findsOneWidget);
  });

  testWidgets('the BizHub team: its own Bizi (alerts, smart words, screens, how-tos)', (t) async {
    await phone(t);
    SharedPreferences.setMockInitialValues({'bizi_tip_seen': '1'});
    await PrefsNotifier.init();
    final api = _Api();
    await t.pumpWidget(_adminApp(api));
    await _settle(t);
    expect(api.calls.any((c) => c.startsWith('GET /api/admin/bizi/brief')), isTrue);
    expect(find.descendant(of: find.byKey(const ValueKey('bizi-dot')), matching: find.text('2')), findsOneWidget);
    expect(find.text('Today: 3 new customers · 2 new businesses'), findsOneWidget);
    expect(find.text('Coins sold today: \$15.00'), findsOneWidget);
    await t.pump(const Duration(seconds: 16));
    await t.tap(find.byKey(const ValueKey('bizi-bubble')));
    await _settle(t);
    expect(find.text('1 coin order to check'), findsOneWidget);
    expect(find.text('2 customers waiting for an answer'), findsOneWidget);
    expect(find.text('Coin orders to check'), findsOneWidget); // the chip
    expect(find.byKey(const ValueKey('bizi-gear')), findsNothing); // owners' settings only
    await _shot(t, 'admin-empty');
    await t.enterText(find.byKey(const ValueKey('bizi-input')), 'pending');
    await _settle(t);
    expect(find.text('#a1b2c3 · 110 coins'), findsOneWidget);
    expect(find.textContaining('SMART · '), findsOneWidget);
    await t.tap(find.text('#a1b2c3 · 110 coins'));
    await _settle(t);
    expect(find.text('ORDERS'), findsOneWidget);
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await _settle(t);
    await t.tap(find.byKey(const ValueKey('bizi-bubble')));
    await _settle(t);
    await t.enterText(find.byKey(const ValueKey('bizi-input')), 'sokha');
    await _settle(t);
    expect(find.text('Sokha Chan'), findsOneWidget);
    expect(find.textContaining('Telegram Store'), findsWidgets); // the business type
    await _shot(t, 'admin-search');
    await t.tap(find.text('Sokha Chan'));
    await _settle(t);
    expect(find.text('CUSTOMER p1'), findsOneWidget);
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await _settle(t);
    await t.tap(find.byKey(const ValueKey('bizi-bubble')));
    await _settle(t);
    await t.enterText(find.byKey(const ValueKey('bizi-input')), 'how do I approve a coin order?');
    await _settle(t);
    expect(find.byKey(const ValueKey('bizi-help')), findsOneWidget);
    expect(find.textContaining('Chat with the BizHub team'), findsNothing);
    await _shot(t, 'admin-help');
    await t.tap(find.byKey(const ValueKey('bizi-help-go')));
    await _settle(t);
    expect(find.text('ORDERS'), findsOneWidget);
  });

  for (final (lang, dark) in [('en', false), ('km', false), ('en', true)]) {
    testWidgets('search: Bizi says, a how-to, sections, results ($lang${dark ? ' dark' : ''})', (t) async {
      await phone(t);
      SharedPreferences.setMockInitialValues({'bizi_brief_day': khDay(), 'bizi_week_seen': '2026-10-19'});
      await PrefsNotifier.init();
      final api = _Api();
      await t.pumpWidget(_app(api, lang: lang, dark: dark));
      await _settle(t);
      await t.tap(find.byKey(const ValueKey('bizi-bubble')));
      await _settle(t);
      final tag = '$lang${dark ? '-dark' : ''}';
      // empty box: what Bizi has to say + questions
      expect(find.text(lang == 'km' ? 'ការកម្ម៉ង់ Telegram ថ្មី 1 កំពុងរង់ចាំ' : '1 new Telegram order waiting'), findsOneWidget);
      expect(find.text(lang == 'km' ? 'ទំនិញ 2 អស់ស្តុក' : '2 products sold out'), findsOneWidget);
      expect(find.byKey(const ValueKey('bizi-ask-0')), findsOneWidget);
      await _shot(t, 'empty-$tag');
      if (lang == 'en' && !dark) {
        // a tip: its how-to, Open goes to that business's section, Not now hides it
        expect(find.text('Orders only show here — connect your staff Telegram group'), findsOneWidget);
        await t.ensureVisible(find.byKey(const ValueKey('bizi-row-tips-tip:rest_no_tables:b2')));
        await t.pump();
        await t.tap(find.byKey(const ValueKey('bizi-row-tips-tip:rest_no_tables:b2')));
        await _settle(t);
        expect(find.byKey(const ValueKey('bizi-help')), findsOneWidget);
        expect(find.text('Open Tables'), findsOneWidget);
        await _shot(t, 'tip');
        await t.ensureVisible(find.byKey(const ValueKey('bizi-later')));
        await t.pump();
        await t.tap(find.byKey(const ValueKey('bizi-later')));
        await _settle(t);
        expect(api.calls.any((c) => c.contains('POST /api/user/bizi/snooze') && c.contains('rest_no_tables')), isTrue);
        expect(find.text('Add your tables (and print table QRs)'), findsNothing);
        await t.pump(const Duration(seconds: 4)); // the toast goes
        // last week, opened
        await t.ensureVisible(find.byKey(const ValueKey('bizi-row-week-week')));
        await t.pump();
        await t.tap(find.byKey(const ValueKey('bizi-row-week-week')));
        await _settle(t);
        expect(find.byKey(const ValueKey('bizi-week')), findsOneWidget);
        expect(find.text('Best sellers: Khmer iced coffee ×9 · Croissant ×4'), findsOneWidget);
        await _shot(t, 'week');
        await t.ensureVisible(find.byKey(const ValueKey('bizi-row-week-week')));
        await t.pump();
        await t.tap(find.byKey(const ValueKey('bizi-row-week-week')));
        await _settle(t);
        // settings: mute sold out → saved on the server, the alert goes
        await t.tap(find.byKey(const ValueKey('bizi-gear')));
        await _settle(t);
        expect(find.byKey(const ValueKey('bizi-settings')), findsOneWidget);
        await _shot(t, 'settings');
        // Bizi on Telegram: Connect opens t.me; after Start this screen sees it by itself
        final opened = <Uri>[];
        BiziPage.openUrl = (u) async => opened.add(u);
        await t.tap(find.byKey(const ValueKey('bizi-tg-connect')));
        await _settle(t);
        expect(opened.single.toString(), 'https://t.me/BizHubTestBot?start=bz_abc');
        expect(api.calls.any((c) => c.startsWith('POST /api/user/bizi/telegram/link') && c.contains('lang: en')), isTrue);
        expect(find.textContaining('press Start'), findsOneWidget);
        api.tgOn = true; // the owner pressed Start in Telegram
        await t.pump(const Duration(seconds: 3));
        await _settle(t);
        expect(find.text('Connected: Sokha'), findsOneWidget);
        await _shot(t, 'telegram');
        await t.tap(find.byKey(const ValueKey('bizi-tg-alerts')));
        await _settle(t);
        expect(api.calls.any((c) => c.startsWith('PUT /api/user/bizi/prefs') && c.contains('{tg: {alerts: false}}')), isTrue);
        await t.tap(find.byKey(const ValueKey('bizi-tg-test')));
        await _settle(t);
        expect(find.text('Sent — look in Telegram'), findsOneWidget);
        await t.tap(find.text('Disconnect'));
        await _settle(t);
        expect(find.byKey(const ValueKey('bizi-tg-connect')), findsOneWidget);
        BiziPage.openUrl = null;
        await t.ensureVisible(find.byKey(const ValueKey('bizi-mute-sold_out')));
        await t.pump();
        await t.tap(find.byKey(const ValueKey('bizi-mute-sold_out')));
        await _settle(t);
        expect(api.calls.any((c) => c.startsWith('PUT /api/user/bizi/prefs') && c.contains('sold_out')), isTrue);
        expect(find.text('Saved'), findsOneWidget);
        await t.tap(find.text('Back'));
        await _settle(t);
        expect(find.byKey(const ValueKey('bizi-input')), findsOneWidget);
      }

      // voice: the words go into the box, a Khmer question opens its answer
      if (lang == 'km') {
        BiziVoice.instance = _Voice(['ធ្វើម៉េច', 'ធ្វើម៉េចភ្ជាប់ POS']);
        await t.tap(find.byKey(const ValueKey('bizi-mic')));
        await t.pump(const Duration(milliseconds: 350));
        expect(find.text('ធ្វើម៉េច'), findsOneWidget);
        await t.pump(const Duration(milliseconds: 400));
        await _settle(t);
        expect((BiziVoice.instance as _Voice).lang, 'km');
        expect(find.byKey(const ValueKey('bizi-help')), findsOneWidget);
        await _shot(t, 'voice-km');
        BiziVoice.instance = _Voice([], ok: false);
        await t.tap(find.byKey(const ValueKey('bizi-mic')));
        await _settle(t);
        expect(find.textContaining('មិនអាចស្វែងរកដោយសំឡេង'), findsOneWidget);
        await t.pump(const Duration(seconds: 4));
        await t.enterText(find.byKey(const ValueKey('bizi-input')), '');
        await _settle(t);
      }
      // a question opens its answer by itself
      await t.enterText(find.byKey(const ValueKey('bizi-input')), lang == 'km' ? 'ធ្វើម៉េចភ្ជាប់ POS' : 'how do I pair a POS?');
      await _settle(t);
      expect(find.byKey(const ValueKey('bizi-help')), findsOneWidget);
      expect(find.textContaining(lang == 'km' ? 'លេខកូដ ៦ ខ្ទង់' : '6-digit code'), findsWidgets);
      await _shot(t, 'help-$tag');
      if (lang != 'en' || dark) return;

      // tap the question → it closes; again → open; Open → my Telegram Store's Staff screen
      await t.tap(find.byKey(const ValueKey('bizi-row-help-pos_pair')));
      await _settle(t);
      expect(find.byKey(const ValueKey('bizi-help')), findsNothing);
      await t.tap(find.byKey(const ValueKey('bizi-row-help-pos_pair')));
      await _settle(t);
      await t.tap(find.byKey(const ValueKey('bizi-help-go')));
      await _settle(t);
      expect(find.text('BUSINESS tgstore b1 tab=staff'), findsOneWidget);
      t.state<NavigatorState>(find.byType(Navigator).first).pop();
      await _settle(t);

      // sections + the server's results
      await t.tap(find.byKey(const ValueKey('bizi-bubble')));
      await _settle(t);
      await t.enterText(find.byKey(const ValueKey('bizi-input')), 'cofee');
      await _settle(t);
      expect(find.text('Khmer iced coffee'), findsOneWidget);
      expect(find.text('Sold out'), findsOneWidget);
      expect(find.textContaining('Close matches'), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('bizi-input')), 'new');
      await _settle(t);
      expect(find.text('#12'), findsOneWidget);
      expect(find.textContaining('SMART · NEW'), findsOneWidget);
      await _shot(t, 'smart');
      await t.enterText(find.byKey(const ValueKey('bizi-input')), 'delivery fee');
      await _settle(t);
      expect(find.text('Delivery'), findsOneWidget);
      expect(find.text('How do I set the delivery fee?'), findsOneWidget);
      await _shot(t, 'pages');
      await t.tap(find.text('Delivery'));
      await _settle(t);
      expect(find.text('BUSINESS tgstore b1 tab=delivery'), findsOneWidget);
      t.state<NavigatorState>(find.byType(Navigator).first).pop();
      await _settle(t);

      // quick actions: "#12 paid" → asked first → Yes → paid; Accept with its chip
      await t.tap(find.byKey(const ValueKey('bizi-bubble')));
      await _settle(t);
      await t.enterText(find.byKey(const ValueKey('bizi-input')), '#12 paid');
      await _settle(t);
      expect(api.calls.any((c) => c.contains('/search') && c.contains('q: #12}')), isTrue); // "paid" is not searched
      expect(find.byKey(const ValueKey('bizi-act-paid')), findsOneWidget);
      expect(find.byKey(const ValueKey('bizi-act-accept')), findsOneWidget);
      await t.testTextInput.receiveAction(TextInputAction.search); // Enter
      await _settle(t);
      expect(find.text('Mark order #12 paid?'), findsOneWidget);
      await _shot(t, 'action');
      await t.tap(find.byKey(const ValueKey('bizi-yes')));
      await _settle(t);
      expect(api.calls.any((c) => c.startsWith('POST /api/user/businesses/b1/tgstore/orders/o1/paid')), isTrue);
      expect(find.text('Order #12 is paid'), findsOneWidget);
      expect(find.byKey(const ValueKey('bizi-act-paid')), findsNothing); // paid now
      await t.pump(const Duration(seconds: 4));
      await t.tap(find.byKey(const ValueKey('bizi-act-accept')));
      await _settle(t);
      await t.tap(find.byKey(const ValueKey('bizi-no')));
      await _settle(t);
      expect(api.calls.where((c) => c.contains('/orders/o1/status')), isEmpty); // No = nothing done
      await t.tap(find.byKey(const ValueKey('bizi-act-accept')));
      await _settle(t);
      await t.tap(find.byKey(const ValueKey('bizi-yes')));
      await _settle(t);
      expect(api.calls.any((c) => c.contains('/orders/o1/status {status: accepted}')), isTrue);
      expect(find.byKey(const ValueKey('bizi-act-done')), findsOneWidget);
      await t.pump(const Duration(seconds: 4));

      // nothing found for a question → the BizHub team
      await t.enterText(find.byKey(const ValueKey('bizi-input')), '');
      await _settle(t);
      expect(find.text('Delivery', skipOffstage: false), findsOneWidget); // recent
      await t.enterText(find.byKey(const ValueKey('bizi-input')), 'how do I fly to the moon?');
      await _settle(t);
      expect(find.byKey(const ValueKey('bizi-none')), findsOneWidget);
      await _shot(t, 'none');
      await t.tap(find.textContaining('Chat with the BizHub team'));
      await _settle(t);
      expect(find.text('SUPPORT'), findsOneWidget);
      expect(api.calls.where((c) => c.contains('/search')), isNotEmpty);
    });
  }
}
