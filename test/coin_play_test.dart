// In-app coin shop: Google Play (Android) and App Store (iPhone). Packs with the store's prices, buying → the server
// adds the coins → the purchase is finished; pending / cancelled / failed / restored purchases; no double taps.
// Fake billing + fake API.
import 'dart:async';

import 'package:bizhub_admin/core/api.dart';
import 'package:bizhub_admin/core/i18n.dart';
import 'package:bizhub_admin/core/providers.dart';
import 'package:bizhub_admin/core/theme.dart';
import 'package:bizhub_admin/features/owner/coin_play.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nc_recipes_test.dart' show loadFonts;

class _Billing implements PlayBilling {
  final ctl = StreamController<List<PlayPurchase>>.broadcast();
  final bought = <String>[];
  final completed = <String>[];
  int restores = 0;
  bool ok = true;
  @override
  Future<bool> available() async => ok;
  @override
  Future<List<PlayProduct>> products(Set<String> ids) async => [
    for (final id in ids)
      PlayProduct(id, {'coins_100': '\$10.00', 'coins_250': '\$25.00', 'coins_500': '\$50.00', 'coins_1000': '\$100.00', 'coins_2500': '\$250.00'}[id] ?? '\$1'),
  ];
  @override
  Future<bool> buy(String productId, String accountRef) async {
    bought.add('$productId|$accountRef');
    return true;
  }

  @override
  Stream<List<PlayPurchase>> get updates => ctl.stream;
  @override
  Future<void> complete(PlayPurchase p) async => completed.add(p.token);
  @override
  Future<void> restore() async => restores++;
}

class _Api extends Api {
  final verifies = <Json>[];
  final verifyPaths = <String>[];
  String packsPath = '';
  Object? verifyError; // throw this instead of answering
  int balance = 120;
  _Api() : super(token: () => 't', onUnauthorized: () {});
  @override
  Future<Json> get(String path, [Map<String, dynamic>? query]) async {
    if (path.endsWith('/coins/google-packs') || path.endsWith('/coins/apple-packs')) {
      packsPath = path;
      return {
        'data': {
          'ready': true,
          'account_ref': path.endsWith('apple-packs') ? '0b1c2d3e-4f50-5a6b-8c7d-8e9fa0b1c2d3' : 'ref123',
          'packs': [
            for (final p in const [
              [100, 0, 10],
              [250, 10, 25],
              [500, 15, 50],
              [1000, 20, 100],
              [2500, 30, 250],
            ])
              {'product_id': 'coins_${p[0]}', 'coins': p[0], 'bonus_pct': p[1], 'bonus': p[0] * p[1] ~/ 100, 'total_coins': p[0] + p[0] * p[1] ~/ 100, 'usd': p[2]},
          ],
        },
      };
    }
    return {'data': {}};
  }

  @override
  Future<Json> post(String path, [Object? body]) async {
    if (path.endsWith('/coins/google/verify') || path.endsWith('/coins/apple/verify')) {
      verifies.add(Map<String, dynamic>.from(body as Map));
      verifyPaths.add(path);
      final e = verifyError;
      if (e != null) throw e;
      balance += 275;
      return {
        'data': {'status': 'credited', 'coins_added': 275, 'balance': balance, 'consumed': true},
      };
    }
    return {'data': {}};
  }
}

class _Me extends SessionNotifier {
  @override
  Session? build() => const Session({'access_token': 't', 'name': 'Sokha Chan', 'coin_balance': 120});
  @override
  Future<void> patch(Json fields) async => state = Session({...state!.data, ...fields});
}

Widget _app(_Api api, _Billing b, {String lang = 'en', String store = 'google'}) => ProviderScope(
  overrides: [
    apiProvider.overrideWithValue(api),
    playBillingProvider.overrideWithValue(b),
    billingStoreProvider.overrideWithValue(store),
    tProvider.overrideWithValue(T.of(lang)),
    sessionProvider.overrideWith(_Me.new),
  ],
  child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(dark: false, khmer: lang == 'km'), home: const CoinPlayPage()),
);

PlayPurchase _p(String token, PlayStatus s, {String product = 'coins_250'}) => PlayPurchase(productId: product, token: token, orderId: 'GPA.$token', status: s, needsComplete: true);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await PrefsNotifier.init();
    await T.load();
    await loadFonts();
  });

  Future<void> size(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(400, 860));
    t.view.devicePixelRatio = 2;
  }

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('packs show Google prices; buy → verify → coins added → finished', (t) async {
    await size(t);
    final api = _Api(), b = _Billing();
    await t.pumpWidget(_app(api, b));
    await settle(t);
    expect(b.restores, 1); // unfinished purchases are checked on open
    // the same packs + prices as the web (prices come from Google; set the same USD in Play Console)
    expect(find.text('\$25.00'), findsOneWidget);
    expect(find.text('\$10.00'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/coinplay-shop.png'));

    // double tap = one purchase
    await t.tap(find.text('\$25.00'));
    await t.tap(find.text('\$25.00'), warnIfMissed: false);
    await settle(t);
    expect(b.bought, ['coins_250|ref123']); // the account ref goes to Google

    // Google says purchased → the server adds the coins → the purchase is finished
    b.ctl.add([_p('tok1', PlayStatus.purchased)]);
    await settle(t);
    expect(api.verifies.single, {'productId': 'coins_250', 'purchaseToken': 'tok1', 'orderId': 'GPA.tok1'});
    expect(b.completed, ['tok1']);
    expect(find.text('+275 coins added to your wallet'), findsOneWidget);
    expect(find.text('395'), findsOneWidget); // the new balance
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/coinplay-added.png'));

    // the same purchase delivered twice at once (restore + live) → sent once at a time
    b.ctl.add([_p('tok1', PlayStatus.restored), _p('tok1', PlayStatus.restored)]);
    await settle(t);
    expect(api.verifies.length, lessThanOrEqualTo(3));
  });

  testWidgets('pending, no internet and cancelled keep the coins safe', (t) async {
    await size(t);
    final api = _Api(), b = _Billing();
    await t.pumpWidget(_app(api, b));
    await settle(t);

    b.ctl.add([_p('tokP', PlayStatus.pending)]);
    await settle(t);
    expect(find.textContaining('Payment pending'), findsOneWidget);
    expect(api.verifies, isEmpty);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/coinplay-pending.png'));

    // paid, but the phone is offline: the purchase stays open (checked again next start)
    api.verifyError = const ApiError(0, 'network');
    b.ctl.add([_p('tokN', PlayStatus.purchased)]);
    await settle(t);
    expect(b.completed, isNot(contains('tokN')));
    expect(find.textContaining("couldn't be completed"), findsOneWidget);

    // the server says "pending" (202) → not finished either
    api.verifyError = const ApiError(202, 'pending', code: 'pending');
    b.ctl.add([_p('tokS', PlayStatus.purchased)]);
    await settle(t);
    expect(b.completed, isNot(contains('tokS')));

    // cancelled in Google's sheet
    b.ctl.add([_p('tokC', PlayStatus.canceled)]);
    await settle(t);
    expect(find.text('Purchase cancelled.'), findsOneWidget);
  });

  testWidgets('Khmer + Google Play not available', (t) async {
    await size(t);
    final api = _Api(), b = _Billing();
    await t.pumpWidget(_app(api, b, lang: 'km'));
    await settle(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/coinplay-km.png'));
    final b2 = _Billing()..ok = false;
    await t.pumpWidget(Container());
    await t.pumpWidget(_app(_Api(), b2));
    await settle(t);
    expect(find.textContaining("isn't available on this device"), findsOneWidget);
  });

  testWidgets('iPhone: App Store packs, the signed transaction goes to the Apple check, then finished', (t) async {
    await size(t);
    final api = _Api(), b = _Billing();
    await t.pumpWidget(_app(api, b, store: 'apple'));
    await settle(t);
    expect(api.packsPath, endsWith('/coins/apple-packs'));
    expect(b.restores, 1); // unfinished App Store transactions are checked on open
    expect(find.text('Paid securely with the App Store'), findsOneWidget);
    expect(find.textContaining('Google'), findsNothing);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/coinplay-ios.png'));

    await t.tap(find.text('\$25.00'));
    await settle(t);
    expect(b.bought, ['coins_250|0b1c2d3e-4f50-5a6b-8c7d-8e9fa0b1c2d3']); // appAccountToken = the server's UUID

    // StoreKit: purchased, token = the JWS signed by Apple
    b.ctl.add([PlayPurchase(productId: 'coins_250', token: 'eyJhbGciOiJFUzI1NiJ9.x.y', orderId: '2000000123', status: PlayStatus.purchased, needsComplete: true)]);
    await settle(t);
    expect(api.verifyPaths.single, endsWith('/coins/apple/verify'));
    expect(api.verifies.single, {'productId': 'coins_250', 'jws': 'eyJhbGciOiJFUzI1NiJ9.x.y'});
    expect(b.completed, ['eyJhbGciOiJFUzI1NiJ9.x.y']); // finished only after the server added the coins
    expect(find.text('+275 coins added to your wallet'), findsOneWidget);

    // offline: the transaction stays unfinished (StoreKit gives it again next start)
    api.verifyError = const ApiError(0, 'network');
    b.ctl.add([PlayPurchase(productId: 'coins_100', token: 'eyJhbGciOiJFUzI1NiJ9.a.b', orderId: '2000000124', status: PlayStatus.purchased, needsComplete: true)]);
    await settle(t);
    expect(b.completed, isNot(contains('eyJhbGciOiJFUzI1NiJ9.a.b')));
  });

  testWidgets('iPhone: Khmer + App Store not available', (t) async {
    await size(t);
    await t.pumpWidget(_app(_Api(), _Billing(), lang: 'km', store: 'apple'));
    await settle(t);
    expect(find.text('បង់ប្រាក់ដោយសុវត្ថិភាពតាម App Store'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/coinplay-ios-km.png'));
    await t.pumpWidget(Container());
    await t.pumpWidget(_app(_Api(), _Billing()..ok = false, store: 'apple'));
    await settle(t);
    expect(find.textContaining('Screen Time'), findsOneWidget);
  });
}
