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
    if (path.endsWith('/bizi/brief')) {
      return _ok({
        'summary': {'currency': 'USD', 'today': 12.5, 'yesterday': 0, 'week': 12.5, 'last_week': 0, 'change_pct': null, 'bills_today': 3, 'orders_today': 1},
        'pulse': pulse,
        'alerts': [
          {'key': 'tg_new', 'level': 'warn', 'n': 1, 'business_id': 'b1', 'business': 'Mekong Coffee Shop', 'category': 'tg_store', 'tab': 'orders'},
          {'key': 'sold_out', 'level': 'warn', 'n': 2, 'business_id': 'b1', 'business': 'Mekong Coffee Shop', 'category': 'tg_store', 'tab': 'products'},
          {'key': 'renewals', 'level': 'info', 'n': 1, 'href': '/app/licenses'},
        ],
        'mood': 'worried',
      });
    }
    if (path.endsWith('/search')) {
      final q = '${query?['q']}';
      if (q.contains('coffee') || q.contains('cofee')) {
        return _ok({
          'q': q,
          'smart': [],
          'fuzzy': q.contains('cofee'),
          'results': [
            {'group': 'products', 'kind': 'product', 'id': 'p1', 'business_id': 'b1', 'business': 'Mekong Coffee Shop', 'category': 'tg_store', 'title': 'Khmer iced coffee', 'sub': 'Coffee', 'money': 2.5, 'cur': 'USD', 'tab': 'products', 'flag': 'sold_out'},
          ],
        });
      }
      if (q.contains('new')) {
        return _ok({
          'q': q,
          'smart': ['new'],
          'fuzzy': false,
          'results': [
            {'group': 'orders', 'kind': 'order', 'id': 'o1', 'business_id': 'b1', 'business': 'Mekong Coffee Shop', 'category': 'tg_store', 'title': '#12', 'sub': 'Emma Wilson', 'money': 6.5, 'cur': 'USD', 'tab': 'orders', 'status': 'new', 'smart': true},
          ],
        });
      }
      return _ok({'q': q, 'smart': [], 'fuzzy': false, 'results': []});
    }
    return _ok({});
  }
}

class _Me extends SessionNotifier {
  @override
  Session? build() => const Session({'name': 'Sokha', 'email': 'sokha@example.com', 'access_token': 't', 'coin_balance': 20, 'account_type': 'customer'});
}

Widget _stub(String text) => Scaffold(
  body: SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Text(text, key: const ValueKey('stub')))),
);

Widget _app(_Api api, {String lang = 'en', bool dark = false, String start = '/o/home'}) {
  final router = GoRouter(
    initialLocation: start,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, nav) => AppShell(nav: nav, admin: false),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/o/home', builder: (_, _) => const Center(child: Text('HOME')))]),
          StatefulShellBranch(routes: [GoRoute(path: '/o/business', builder: (_, _) => const Center(child: Text('BUSINESSES')))]),
          StatefulShellBranch(routes: [GoRoute(path: '/o/wallet', builder: (_, _) => const Center(child: Text('WALLET')))]),
          StatefulShellBranch(routes: [GoRoute(path: '/o/more', builder: (_, _) => const Center(child: Text('MORE')))]),
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
    child: MaterialApp.router(debugShowCheckedModeBanner: false, theme: buildTheme(dark: dark, khmer: lang == 'km'), routerConfig: router),
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
    expect(find.byKey(const ValueKey('bizi-note')), findsOneWidget);
    expect(find.textContaining('Today so far: \$12.50'), findsOneWidget);
    expect(find.text('3 things need you'), findsOneWidget);
    await _shot(t, 'bubble');
    // the summary goes by itself, once a day
    await t.pump(const Duration(seconds: 16));
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

  for (final (lang, dark) in [('en', false), ('km', false), ('en', true)]) {
    testWidgets('search: Bizi says, a how-to, sections, results ($lang${dark ? ' dark' : ''})', (t) async {
      await phone(t);
      SharedPreferences.setMockInitialValues({'bizi_brief_day': khDay()});
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

      // nothing found for a question → the BizHub team
      await t.tap(find.byKey(const ValueKey('bizi-bubble')));
      await _settle(t);
      expect(find.text('Delivery'), findsOneWidget); // recent
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
