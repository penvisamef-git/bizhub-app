// Team access (v1.5) in the owner app: the Team page (unlock → members → add by ID / link → role → remove), Shared with
// me (accept an invite, open), the Join page, the banner inside a shared business, My BizHub ID and System activity.
// Pictures: test/shots/team-*.png
import 'package:bizhub_admin/core/api.dart';
import 'package:bizhub_admin/core/i18n.dart';
import 'package:bizhub_admin/core/providers.dart';
import 'package:bizhub_admin/core/theme.dart';
import 'package:bizhub_admin/features/owner/business_page.dart';
import 'package:bizhub_admin/features/team/join_page.dart';
import 'package:bizhub_admin/features/team/my_id_card.dart';
import 'package:bizhub_admin/features/team/team_data.dart';
import 'package:bizhub_admin/features/team/team_frame.dart';
import 'package:bizhub_admin/features/team/team_page.dart';
import 'package:bizhub_admin/features/updates/updates_page.dart';
import 'package:bizhub_admin/app.dart' show webLinkTarget;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nc_recipes_test.dart' show loadFonts;

const _biz = 'b1';
final _ends = DateTime.now().toUtc().add(const Duration(days: 365)).toIso8601String();

// the API in memory, answering like bizhub-api/src/biz/team/team.route.js
class _Api extends Api {
  _Api() : super(token: () => 't', onUnauthorized: () {});
  bool on = false;
  final members = <Json>[];
  final links = <Json>[];
  final calls = <String>[];
  Duration wait = Duration.zero; // answers late (to see the loading shapes)
  // what the member side sees
  final shared = <Json>[];
  final invites = <Json>[
    {'_id': 'b9', 'name': 'Lucky Mini Mart', 'category': 'mart', 'logo_url': '', 'owner_name': 'Sokha', 'role': 'view', 'member_id': 'm9', 'team_on': true},
  ];

  Json get _team => {
    'business': {'_id': _biz, 'name': 'Ferm Cafe', 'category': 'restaurant'},
    'license': on ? {'active': true, 'status': 'active', 'expires_at': _ends} : {'active': false, 'status': 'none'},
    'price': 5,
    'members': members,
    'links': links,
  };
  Json _ok(Object? data, [Json extra = const {}]) => {'success': true, 'data': data, ...extra};

  @override
  Future<Json> get(String path, [Map<String, dynamic>? query]) async {
    calls.add('GET $path');
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    if (path.endsWith('/businesses/$_biz/team')) return _ok(_team);
    if (path.endsWith('/team/shared')) return _ok({'businesses': shared, 'invites': invites});
    if (path.endsWith('/team/my-id')) return _ok({'bizhub_id': 'BH-437835'});
    if (path.endsWith('/team/join/GONE00')) throw const ApiError(410, 'gone', code: 'link_gone');
    if (path.contains('/team/join/')) {
      return _ok({
        'business': {'_id': 'b7', 'name': 'Sunrise Guest House', 'category': 'guest_house', 'logo_url': ''},
        'owner_name': 'Vanna',
        'role': 'admin',
        'expires_at': _ends,
        'is_owner': false,
        'already': null,
      });
    }
    if (path.endsWith('/dashboard')) return _ok({'businesses': [], 'coins': {'balance': 20}});
    return _ok({});
  }

  @override
  Future<Json> post(String path, [Object? body]) async {
    final b = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    calls.add('POST $path ${b.isEmpty ? '' : b}');
    if (path.endsWith('/licenses/team')) {
      on = true;
      return _ok({'expires_at': _ends}, {'balance': 15});
    }
    if (path.endsWith('/team/members')) {
      if (b['bizhub_id'] == 'BH-000000') throw const ApiError(404, 'No BizHub account has this ID.', code: 'no_user');
      members.add({
        '_id': 'm${members.length + 1}',
        'role': b['role'],
        'status': 'invited',
        'via': 'id',
        'person': {'_id': 'p1', 'name': 'Mony', 'bizhub_id': b['bizhub_id']},
      });
      return _ok(_team);
    }
    if (path.endsWith('/team/links')) {
      final l = {'_id': 'l1', 'code': 'HFEU2Q', 'role': b['role'], 'expires_at': _ends};
      links.add(l);
      return _ok(l, {'team': _team});
    }
    if (path.endsWith('/invites/m9/accept')) {
      shared.add({...invites.removeAt(0)});
      return _ok({'business_id': 'b9', 'role': 'view', 'accepted': true});
    }
    if (path.contains('/team/join/')) {
      shared.add({'_id': 'b7', 'name': 'Sunrise Guest House', 'category': 'guest_house', 'owner_name': 'Vanna', 'role': 'admin', 'team_on': true});
      return _ok({'business_id': 'b7', 'role': 'admin'});
    }
    return _ok({});
  }

  @override
  Future<Json> patch(String path, [Object? body]) async {
    calls.add('PATCH $path $body');
    final id = path.split('/').last;
    for (final m in members) {
      if (m['_id'] == id) m['role'] = (body as Map)['role'];
    }
    return _ok(_team);
  }

  @override
  Future<Json> delete(String path, [Object? body]) async {
    calls.add('DELETE $path');
    final id = path.split('/').last;
    members.removeWhere((m) => m['_id'] == id);
    links.removeWhere((l) => l['_id'] == id);
    return _ok(_team);
  }
}

class _Me extends SessionNotifier {
  @override
  Session? build() => const Session({'name': 'Sokha', 'email': 'sokha@example.com', 'access_token': 't', 'coin_balance': 20, 'account_type': 'customer'});
  @override
  Future<void> patch(Json fields) async => state = Session({...state!.data, ...fields});
}

// the screen under test inside a tiny router (push / go work), with a stub for the business screens
Widget _app(_Api api, String start, {String lang = 'en', bool dark = false}) {
  final router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(path: '/o/business', builder: (_, _) => const Scaffold(body: SafeArea(child: OwnerBusinessPage()))),
      GoRoute(
        path: '/o/team/:id',
        builder: (_, s) => TeamPage(id: s.pathParameters['id']!, name: s.uri.queryParameters['name'] ?? ''),
      ),
      GoRoute(path: '/o/join/:code', builder: (_, s) => JoinPage(code: s.pathParameters['code']!)),
      GoRoute(path: '/updates', builder: (_, _) => const UpdatesPage()),
      GoRoute(
        path: '/account',
        builder: (_, _) => Scaffold(
          body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: const [MyIdCard()])),
        ),
      ),
      GoRoute(
        path: '/biz/:kind/:id',
        builder: (_, s) => TeamFrame(
          id: s.pathParameters['id']!,
          child: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('BUSINESS ${s.pathParameters['id']} ${s.uri.queryParameters['name'] ?? ''}', key: const ValueKey('biz-screen')),
              ),
            ),
          ),
        ),
      ),
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

Future<void> _shot(WidgetTester t, String name) => expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/team-$name.png'));

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await PrefsNotifier.init();
    await T.load();
    await loadFonts();
  });

  Future<void> phone(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(400, 860));
    t.view.devicePixelRatio = 2;
  }

  test('invite links open the Join screen', () {
    expect(webLinkTarget(Uri.parse('https://bizhubcambodia.com/app/join/hfeu2q')), '/o/join/HFEU2Q');
    expect(webLinkTarget(Uri.parse('https://bizhubcambodia.com/join/HFEU2Q')), '/o/join/HFEU2Q');
    expect(webLinkTarget(Uri.parse('https://bizhubcambodia.com/app/updates')), '/updates');
    expect(joinCodeOf('https://bizhub-cambodia.web.app/app/join/AB12CD'), 'AB12CD');
    expect(joinCodeOf(' ab12cd '), 'AB12CD');
    expect(joinCodeOf('AB1'), isNull);
  });

  testWidgets('owner: unlock → add by ID → link → change role → remove', (t) async {
    await phone(t);
    final api = _Api()..wait = const Duration(seconds: 2);
    await t.pumpWidget(_app(api, '/o/team/$_biz?name=Ferm%20Cafe'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('team-locked')), findsNothing);
    await _shot(t, 'loading'); // the skeleton before the answer
    await t.pump(const Duration(seconds: 2));
    api.wait = Duration.zero;
    await _settle(t);
    expect(find.byKey(const ValueKey('team-locked')), findsOneWidget);
    expect(find.text('Unlock Team · 5 coins / year'), findsOneWidget);
    await _shot(t, 'locked');

    // unlock: the coin sheet, pay 5
    await t.tap(find.text('Unlock Team · 5 coins / year'));
    await _settle(t);
    expect(find.text('Pay 5 coins'), findsOneWidget);
    await _shot(t, 'buy');
    await t.tap(find.text('Pay 5 coins'));
    await _settle(t);
    expect(api.calls.any((c) => c.startsWith('POST /api/user/businesses/$_biz/licenses/team')), isTrue);
    await t.tap(find.text(T.of('en')('app.continue')));
    await _settle(t);
    expect(find.byKey(const ValueKey('team-members')), findsOneWidget);
    expect(find.textContaining('Team is on until'), findsOneWidget);

    // add by BizHub ID (View only is picked first)
    await t.tap(find.text('Add member'));
    await _settle(t);
    await t.enterText(find.descendant(of: find.byKey(const ValueKey('team-bhid')), matching: find.byType(TextField)), 'BH-437835');
    await t.pump();
    await _shot(t, 'add-id');
    await t.tap(find.byKey(const ValueKey('team-send')));
    await _settle(t);
    expect(api.calls.any((c) => c.contains('/team/members {bizhub_id: BH-437835, role: view}')), isTrue);
    expect(find.text('Mony'), findsOneWidget);
    expect(find.textContaining('waiting for them to accept'), findsOneWidget);

    expect(find.textContaining('Invite sent'), findsOneWidget);
    await t.pump(const Duration(seconds: 5)); // the "Invite sent" note goes away
    await _settle(t);

    // an Admin invite link with its QR
    await t.tap(find.text('Add member'));
    await _settle(t);
    await t.tap(find.byKey(const ValueKey('team-role-admin')));
    await t.tap(find.byKey(const ValueKey('team-tab-link')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('team-make-link')));
    await _settle(t);
    expect(find.byKey(const ValueKey('team-link')), findsOneWidget);
    expect(find.textContaining('/app/join/HFEU2Q'), findsOneWidget);
    await _shot(t, 'add-link');
    await t.tapAt(const Offset(200, 20)); // close the sheet
    await _settle(t);
    expect(find.text('Invite links not used yet'.toUpperCase()), findsOneWidget);
    await _shot(t, 'members');

    // View only → Admin
    await t.tap(find.byKey(const ValueKey('team-role-m1')));
    await _settle(t);
    await t.tap(find.byKey(const ValueKey('team-role-admin')).last);
    await _settle(t);
    expect(api.calls.any((c) => c.startsWith('PATCH /api/user/businesses/$_biz/team/members/m1 {role: admin}')), isTrue);

    // remove
    await t.tap(find.byTooltip('Remove'));
    await _settle(t);
    await t.tap(find.widgetWithText(FilledButton, 'Remove'));
    await _settle(t);
    expect(api.calls.contains('DELETE /api/user/businesses/$_biz/team/members/m1'), isTrue);
    expect(find.text('Mony'), findsNothing);
  });

  testWidgets('member: an invite under Shared with me → accept → the business with the View only line', (t) async {
    await phone(t);
    final api = _Api();
    await t.pumpWidget(_app(api, '/o/business'));
    await _settle(t);
    await t.scrollUntilVisible(find.byKey(const ValueKey('team-invite-m9')), 200);
    await _settle(t);
    await _shot(t, 'shared-invite');
    await t.tap(find.byKey(const ValueKey('team-accept-m9')));
    await _settle(t);
    expect(find.byKey(const ValueKey('biz-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('team-view-banner')), findsOneWidget);
    await _shot(t, 'view-banner');
  });

  testWidgets('join from a link: the invite card → accept → the business, as Admin', (t) async {
    await phone(t);
    final api = _Api();
    await t.pumpWidget(_app(api, '/o/join/HFEU2Q'));
    await _settle(t);
    expect(find.text('Sunrise Guest House'), findsOneWidget);
    await _shot(t, 'join');
    await t.tap(find.byKey(const ValueKey('team-join-accept')));
    await _settle(t);
    expect(find.byKey(const ValueKey('team-admin-banner')), findsOneWidget);
    await _shot(t, 'admin-banner');
  });

  testWidgets('an used link says so', (t) async {
    await phone(t);
    await t.pumpWidget(_app(_Api(), '/o/join/GONE00'));
    await _settle(t);
    expect(find.textContaining('expired or was already used'), findsOneWidget);
  });

  testWidgets('My BizHub ID + Khmer', (t) async {
    await phone(t);
    await t.pumpWidget(_app(_Api(), '/account'));
    await _settle(t);
    expect(find.text('BH-437835'), findsOneWidget);
    await _shot(t, 'my-id');
    await t.pumpWidget(_app(_Api(), '/o/team/$_biz', lang: 'km'));
    await _settle(t);
    expect(find.text('ធ្វើការលើអាជីវកម្មនេះជាក្រុម'), findsWidgets);
    await _shot(t, 'locked-km');
  });

  testWidgets('System activity, EN + KM + dark', (t) async {
    await phone(t);
    await t.pumpWidget(_app(_Api(), '/updates'));
    await _settle(t);
    expect(find.byKey(const ValueKey('up-v-1.5.0')), findsOneWidget);
    expect(find.text('Testing · coming soon'), findsOneWidget);
    await _shot(t, 'updates');
    await t.pumpWidget(_app(_Api(), '/updates', lang: 'km', dark: true));
    await _settle(t);
    expect(find.text('សកម្មភាពក្នុងប្រព័ន្ធ'), findsOneWidget);
    await _shot(t, 'updates-km-dark');
  });
}
