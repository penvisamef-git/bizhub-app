// "Powered by Cyber Tech System" (v3.3.0): EN / KM, on the log in screen, and a tap on the name opens ctscambodia.com.
import 'package:bizhub_admin/core/i18n.dart';
import 'package:bizhub_admin/core/providers.dart';
import 'package:bizhub_admin/core/theme.dart';
import 'package:bizhub_admin/features/auth/auth_shell.dart';
import 'package:bizhub_admin/widgets/powered_by.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(String lang, Widget home) => ProviderScope(
  overrides: [tProvider.overrideWithValue(T.of(lang))],
  child: MaterialApp(theme: buildTheme(dark: false, khmer: lang == 'km'), home: home),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await PrefsNotifier.init();
    await T.load();
  });

  testWidgets('English + the tap opens the website', (t) async {
    final opened = <Uri>[];
    openPowered = (u) async => opened.add(u);
    await t.pumpWidget(_app('en', const Scaffold(body: Center(child: PoweredBy()))));
    expect(find.text('Powered by Cyber Tech System ↗', findRichText: true), findsOneWidget);
    await t.tapOnText(find.textRange.ofSubstring('Cyber Tech System'));
    expect(opened, [Uri.parse('https://ctscambodia.com/')]);
  });

  testWidgets('Khmer', (t) async {
    await t.pumpWidget(_app('km', const Scaffold(body: Center(child: PoweredBy()))));
    expect(find.text('ដំណើរការដោយ Cyber Tech System ↗', findRichText: true), findsOneWidget);
  });

  testWidgets('the log in / sign up frame has it under the form', (t) async {
    await t.pumpWidget(_app('en', const AuthShell(children: [Text('THE FORM')])));
    await t.pump();
    expect(find.text('THE FORM'), findsOneWidget);
    expect(find.byKey(const ValueKey('powered-by')), findsOneWidget);
    expect(t.getTopLeft(find.byKey(const ValueKey('powered-by'))).dy, greaterThan(t.getTopLeft(find.text('THE FORM')).dy));
  });
}
