// Telegram Store (v2.0) on a fake API answering with real answers saved from the API (test/fixtures/tgstore/*.json):
// every section of the owner's screen, in English and a few in Khmer. Pictures: test/shots/ts-*.png
import 'dart:convert';
import 'dart:io';

import 'package:bizhub_admin/core/api.dart';
import 'package:bizhub_admin/core/i18n.dart';
import 'package:bizhub_admin/core/providers.dart';
import 'package:bizhub_admin/core/theme.dart';
import 'package:bizhub_admin/features/tgstore/ts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nc_recipes_test.dart' show loadFonts;

Json _fx(String name) => jsonDecode(File('test/fixtures/tgstore/$name.json').readAsStringSync()) as Json;

class FakeApi extends Api {
  FakeApi() : super(token: () => 't', onUnauthorized: () {});
  @override
  Future<Json> get(String path, [Map<String, dynamic>? query]) async {
    final p = path.split('/tgstore').length > 1 ? path.split('/tgstore').last : '';
    if (!path.contains('/tgstore')) return {'data': {}};
    if (p.isEmpty) return _fx('overview');
    if (p == '/orders') return _fx(query?['status'] == 'open' ? 'orders_open' : 'orders_all');
    if (p.startsWith('/customers/')) return _fx('customer');
    if (p == '/customers') return _fx('customers');
    if (p == '/report') return _fx('report');
    for (final n in ['products', 'categories', 'promos', 'broadcasts', 'carts', 'riders', 'pos']) {
      if (p == '/$n') return _fx(n);
    }
    return {'data': {}};
  }

  @override
  Future<Json> post(String path, [Object? body]) async => {'success': true, 'data': {}};
  @override
  Future<Json> put(String path, [Object? body]) async => {'success': true, 'data': {}};
  @override
  Future<Json> delete(String path, [Object? body]) async => {'success': true, 'data': {}};
}

Widget app(Widget home, {String lang = 'en'}) => ProviderScope(
  overrides: [apiProvider.overrideWithValue(FakeApi()), tProvider.overrideWithValue(T.of(lang))],
  child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(dark: false, khmer: lang == 'km'), home: home),
);

Future<void> settle(WidgetTester t, [int ms = 800]) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(Duration(milliseconds: ms ~/ 6));
  }
}

Future<void> shot(WidgetTester t, String name) => expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/$name.png'));

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await PrefsNotifier.init();
    await T.load();
    await loadFonts();
  });

  Future<void> size(WidgetTester t, [double h = 1400]) async {
    await t.binding.setSurfaceSize(Size(400, h));
    t.view.devicePixelRatio = 2;
    t.view.physicalSize = Size(800, h * 2); // MediaQuery = a 400 px wide phone
    addTearDown(t.view.reset);
  }

  const tabs = ['orders', 'products', 'customers', 'staff', 'promos', 'messages', 'remind', 'report', 'store', 'delivery', 'design', 'share', 'addons'];
  for (final tab in tabs) {
    testWidgets('tab $tab', (t) async {
      await size(t, tab == 'store' || tab == 'share' || tab == 'design' ? 2600 : 1500);
      await t.pumpWidget(app(TgStorePage(id: 'b', title: 'Sokha Café', tab: tab)));
      await settle(t);
      await shot(t, 'ts-$tab');
    });
  }
  testWidgets('orders in Khmer', (t) async {
    await size(t);
    await t.pumpWidget(app(const TgStorePage(id: 'b', title: 'Sokha Café'), lang: 'km'));
    await settle(t);
    await shot(t, 'ts-orders-km');
  });
  testWidgets('all orders', (t) async {
    await size(t);
    await t.pumpWidget(app(const TgStorePage(id: 'b', title: 'Sokha Café')));
    await settle(t);
    await t.tap(find.text('All orders'));
    await settle(t);
    await shot(t, 'ts-history');
  });
  testWidgets('edit a product', (t) async {
    await size(t, 1700);
    await t.pumpWidget(app(const TgStorePage(id: 'b', title: 'Sokha Café', tab: 'products')));
    await settle(t);
    await t.tap(find.byIcon(LucideIcons.pencil).first);
    await settle(t);
    await shot(t, 'ts-product-edit');
  });
  testWidgets('a customer', (t) async {
    await size(t, 1500);
    await t.pumpWidget(app(const TgStorePage(id: 'b', title: 'Sokha Café', tab: 'customers')));
    await settle(t);
    await t.tap(find.text('Vanna Chan'));
    await settle(t);
    await shot(t, 'ts-customer');
  });
  testWidgets('an order', (t) async {
    await size(t, 1500);
    await t.pumpWidget(app(const TgStorePage(id: 'b', title: 'Sokha Café')));
    await settle(t);
    await t.tap(find.text('All orders'));
    await settle(t);
    await t.tap(find.text('#2'));
    await settle(t);
    await shot(t, 'ts-order-sheet');
  });
  for (final (tab, button, name) in [('promos', 'New code', 'ts-promo-new'), ('store', 'Add a way to pay', 'ts-pay-new'), ('products', 'Add category', 'ts-cat-new')]) {
    testWidgets('sheet $name', (t) async {
      await size(t, 1500);
      await t.pumpWidget(app(TgStorePage(id: 'b', title: 'Sokha Café', tab: tab)));
      await settle(t);
      final f = find.text(button);
      if (f.evaluate().isEmpty) return;
      await t.ensureVisible(f.first);
      await t.tap(f.first);
      await settle(t);
      await shot(t, name);
    });
  }
  testWidgets('sections sheet', (t) async {
    await size(t, 1100);
    await t.pumpWidget(app(const TgStorePage(id: 'b', title: 'Sokha Café')));
    await settle(t);
    await t.tap(find.text('All sections'));
    await settle(t);
    await shot(t, 'ts-sections');
  });
}
