// Screenshots of the 100 recipe name card themes (only for checking the layout): test/shots/ncr-*.png
import 'package:bizhub_admin/features/namecard/nc_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadFonts() async {
  Future<void> fam(String name, List<String> files) async {
    final l = FontLoader(name);
    for (final f in files) {
      l.addFont(rootBundle.load(f));
    }
    await l.load();
  }

  await fam('PlusJakartaSans', [for (final w in [400, 500, 600, 700, 800]) 'assets/fonts/PlusJakartaSans-$w.ttf']);
  await fam('KantumruyPro', [for (final w in [400, 500, 600, 700]) 'assets/fonts/KantumruyPro-$w.ttf']);
  await fam('serif', [for (final w in [400, 700]) 'assets/fonts/PlusJakartaSans-$w.ttf']);
  await fam('monospace', ['assets/fonts/PlusJakartaSans-500.ttf']);
  await fam('packages/lucide_icons_flutter/Lucide', ['packages/lucide_icons_flutter/assets/lucide.ttf']);
}

const colors = ['#E0581A', '#1A73E8', '#00897B', '#7B1FA2', '#D93025'];

Map<String, dynamic> sample(String theme, int i) => {
  'name': i.isEven ? 'Sokha Chan' : 'Dara Kim',
  'job_title': 'Designer',
  'company': 'BizHub',
  'bio': i % 3 == 0 ? 'Brand & product design for small shops.' : '',
  'theme': theme,
  'color': colors[i % colors.length],
  'phone1': '012 345 678',
  'email': 'sokha@bizhub.app',
  'portfolio': true,
  'slug': 'sokha',
};

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadFonts();
  });

  final keys = cardRecipes.keys.toList();
  const per = 10;
  for (var p = 0; p * per < keys.length; p++) {
    final page = keys.skip(p * per).take(per).toList();
    testWidgets('recipes page $p', (tester) async {
      await tester.binding.setSurfaceSize(const Size(5 * 440 + 20, 2 * 860 + 20));
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFFDDE1E6),
            body: RepaintBoundary(
              key: const Key('shot'),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Wrap(
                  children: [
                    for (final (i, k) in page.indexed)
                      SizedBox(
                        width: 440,
                        height: 860,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            children: [
                              Text('$k · ${cardRecipes[k]!.parts.values.join(' ')}', style: const TextStyle(fontSize: 11, fontFamily: 'PlusJakartaSans')),
                              const SizedBox(height: 4),
                              NcCard(card: sample(k, p * per + i), fieldLabels: const {'phone1': 'Phone', 'email': 'Email'}),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await expectLater(find.byKey(const Key('shot')), matchesGoldenFile('shots/ncr-$p.png'));
    });
  }
}
