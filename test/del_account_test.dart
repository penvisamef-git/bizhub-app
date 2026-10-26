// "Delete my account" (Google Play rule): the card on My account, the confirm sheet, the pending state and the
// home banner. Pictures: test/shots/del-*.png
import 'package:bizhub_admin/core/api.dart';
import 'package:bizhub_admin/core/i18n.dart';
import 'package:bizhub_admin/core/providers.dart';
import 'package:bizhub_admin/core/theme.dart';
import 'package:bizhub_admin/features/common/delete_account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nc_recipes_test.dart' show loadFonts;

final _deleteAt = DateTime.now().toUtc().add(const Duration(days: 30)).toIso8601String();

class _Api extends Api {
  _Api() : super(token: () => 't', onUnauthorized: () {});
  bool pending = false;
  final calls = <String>[];
  Json get _st => pending ? {'pending': true, 'delete_at': _deleteAt, 'days': 30, 'grace_days': 30} : {'pending': false, 'delete_at': null, 'days': null, 'grace_days': 30};
  @override
  Future<Json> get(String path, [Map<String, dynamic>? query]) async => {'success': true, 'data': _st};
  @override
  Future<Json> post(String path, [Object? body]) async {
    calls.add('POST $path ${(body as Map?)?.keys.join(',')}');
    if (body?['password'] == 'wrong') throw const ApiError(400, 'Wrong password!', code: 'wrong_password');
    pending = true;
    return {'success': true, 'data': _st};
  }

  @override
  Future<Json> delete(String path, [Object? body]) async {
    calls.add('DELETE $path');
    pending = false;
    return {'success': true, 'data': _st};
  }
}

class _Me extends SessionNotifier {
  final Json data;
  _Me(this.data);
  @override
  Session? build() => Session(data);
  @override
  Future<void> set(Json login) async => state = Session(login);
}

Widget _app(_Api api, Json me, Widget child, {bool km = false}) => ProviderScope(
  overrides: [apiProvider.overrideWithValue(api), sessionProvider.overrideWith(() => _Me(me))],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(dark: false, khmer: km),
    home: Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [child]),
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await PrefsNotifier.init();
    await T.load();
    await loadFonts();
  });

  testWidgets('ask → sheet → confirm → pending → cancel', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    tester.view.devicePixelRatio = 2;
    final api = _Api();
    await tester.pumpWidget(_app(api, {'name': 'Sokha', 'email': 'sokha@example.com', 'access_token': 't'}, const DeleteAccountCard()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Delete my account'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/del-card.png'));

    await tester.tap(find.text('Delete my account…'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your BizHub account?'), findsOneWidget);
    // nothing can be sent before "I understand"
    final confirm = find.byKey(const ValueKey('del-confirm'));
    await tester.tap(confirm, warnIfMissed: false);
    await tester.pump();
    expect(api.calls, isEmpty);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/del-sheet.png'));

    await tester.tap(find.byKey(const ValueKey('del-agree')));
    await tester.pump();
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('del-pw')), matching: find.byType(EditableText)), 'wrong');
    await tester.pump();
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Wrong password!'), findsOneWidget, reason: 'a wrong password keeps the sheet open with the message');

    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('del-pw')), matching: find.byType(EditableText)), 'secret123');
    await tester.pump();
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(api.calls.last, startsWith('POST /api/user/account/delete password'));
    expect(find.text('Your account will be deleted'), findsOneWidget);
    expect(find.text('Cancel deletion'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/del-pending.png'));

    await tester.tap(find.text('Cancel deletion'));
    await tester.pumpAndSettle();
    expect(api.calls.last, 'DELETE /api/user/account/delete');
    expect(find.text('Delete my account'), findsOneWidget);
  });

  testWidgets('home banner: pending, and "welcome back" after a cancelled deletion', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 260));
    tester.view.devicePixelRatio = 2;
    await tester.pumpWidget(_app(_Api(), {'name': 'Sokha', 'access_token': 't', 'delete_at': _deleteAt}, const DeletionBanner()));
    await tester.pump();
    expect(find.textContaining('Your account will be deleted on'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/del-banner.png'));
    await tester.pumpWidget(const SizedBox()); // a fresh ProviderScope for the next login
    await tester.pumpWidget(_app(_Api(), {'name': 'Sokha', 'access_token': 't', 'deletion_cancelled': true}, const DeletionBanner()));
    await tester.pump();
    expect(find.textContaining('Welcome back'), findsOneWidget);
    // team accounts never see it
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(_Api(), {'name': 'Admin', 'access_token': 't', 'account_type': 'team', 'delete_at': _deleteAt}, const DeletionBanner()));
    await tester.pump();
    expect(find.textContaining('deleted on'), findsNothing);
  });

  testWidgets('Khmer sheet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    tester.view.devicePixelRatio = 2;
    SharedPreferences.setMockInitialValues({'lang': 'km'});
    final api = _Api();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          sessionProvider.overrideWith(() => _Me({'name': 'Sokha', 'access_token': 't'})),
          tProvider.overrideWithValue(T.of('km')),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(dark: false, khmer: true),
          home: const Scaffold(
            body: SafeArea(child: Padding(padding: EdgeInsets.all(16), child: DeleteAccountCard())),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text(T.of('km')('del.start')));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/del-sheet-km.png'));
  });
}
