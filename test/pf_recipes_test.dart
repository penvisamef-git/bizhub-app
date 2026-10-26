import 'package:bizhub_admin/core/i18n.dart';
import 'package:bizhub_admin/core/providers.dart';
import 'package:bizhub_admin/features/namecard/pf_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Renders portfolio recipe themes side by side (test/shots/pfr-*.png) to eyeball them against the spec.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefsNotifier.init();
    await T.load();
    for (final (name, files) in [
      ('PlusJakartaSans', [for (final w in [400, 500, 600, 700, 800]) 'assets/fonts/PlusJakartaSans-$w.ttf']),
      ('KantumruyPro', [for (final w in [400, 500, 600, 700]) 'assets/fonts/KantumruyPro-$w.ttf']),
      ('monospace', ['assets/fonts/PlusJakartaSans-500.ttf']),
      ('serif', ['assets/fonts/PlusJakartaSans-600.ttf']),
      ('packages/lucide_icons_flutter/Lucide', ['packages/lucide_icons_flutter/assets/lucide.ttf']),
    ]) {
      final l = FontLoader(name);
      for (final f in files) {
        l.addFont(rootBundle.load(f));
      }
      await l.load();
    }
  });
  const card = {'name': 'Dara Chan', 'job_title': 'Product designer', 'company': 'Mekong Labs', 'color': '#1A73E8', 'email': 'dara@mekong.dev', 'phone1': '012 345 678', 'address': 'Phnom Penh'};
  final data = {
    'about': 'I design calm, useful products for small businesses in Cambodia.',
    'experience': [
      {'title': 'Lead designer', 'company': 'Mekong Labs', 'start': '2022', 'current': true, 'description': 'Design system and mobile apps.'},
      {'title': 'UI designer', 'company': 'Angkor Soft', 'start': '2019', 'end': '2022'},
    ],
    'skills': ['Figma', 'UX research', 'Flutter', 'Branding'],
    'projects': [
      {'title': 'BizHub', 'description': 'Tools for shops.', 'link': 'https://bizhub.app'},
    ],
    'languages': [
      {'name': 'Khmer', 'level': 'Native'},
      {'name': 'English', 'level': 'Fluent'},
    ],
  };
  final groups = [
    ['horizon', 'ledger', 'nightshift', 'atelier'],
    ['neonlab', 'blossom', 'founder', 'vintage'],
    ['inferno', 'satellite', 'carnival', 'popart'],
    ['abyss', 'regal', 'arcade', 'lightning'],
    ['petal', 'kyoto', 'sorbet', 'teahouse'],
  ];
  const colors = ['#1A73E8', '#E0581A', '#C2185B', '#00897B'];
  for (final (gi, g) in groups.indexed) {
    testWidgets('pfr-$gi', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1250));
      final t = T.of(gi == 4 ? 'km' : 'en');
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, th) in g.indexed)
                  SizedBox(
                    width: 400,
                    height: 1250,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        maxHeight: double.infinity,
                        child: PfView(data: {...data, 'theme': th}, card: {...card, 'color': colors[i]}, t: t),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/pfr-$gi.png'));
    });
  }
}
