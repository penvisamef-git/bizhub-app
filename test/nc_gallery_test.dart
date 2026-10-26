// The card editor's theme gallery (filters + grid) and the look sheet over it: test/shots/ncr-gallery*.png
import 'package:bizhub_admin/core/api.dart';
import 'package:bizhub_admin/core/i18n.dart';
import 'package:bizhub_admin/core/providers.dart';
import 'package:bizhub_admin/core/theme.dart';
import 'package:bizhub_admin/features/namecard/namecard_page.dart';
import 'package:bizhub_admin/features/namecard/nc_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nc_recipes_test.dart' show loadFonts;

class _Api extends Api {
  _Api() : super(token: () => 't', onUnauthorized: () {});
  @override
  Future<Json> get(String path, [Map<String, dynamic>? query]) async => {
    'business': {'_id': 'b', 'name': 'Sokha Studio', 'status': true},
    'themes': {'free': freeThemes, 'premium': premiumThemes, 'price': 15},
    'licenses': {},
    'data': {
      'name': 'Sokha Chan',
      'job_title': 'Designer',
      'company': 'BizHub',
      'theme': 'harbor',
      'color': '#1A73E8',
      'phone1': '012 345 678',
      'email': 'sokha@bizhub.app',
      'slug': 'sokha',
      'published': true,
      'unlocked_themes': ['harbor', 'velvet', 'neon'],
    },
  };
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await PrefsNotifier.init();
    await T.load();
    await loadFonts();
  });

  testWidgets('gallery', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 860));
    tester.view.devicePixelRatio = 2;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(_Api())],
        child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(dark: false, khmer: false), home: const NameCardPage(id: 'b')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final btn = find.textContaining('See all');
    await tester.scrollUntilVisible(btn, 300, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    await tester.tap(btn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/ncr-gallery.png'));
    await tester.tap(find.text('Dark').last);
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/ncr-gallery-dark.png'));
    await tester.tap(find.text('Velvet Night').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/ncr-gallery-look.png'));
  });
}
