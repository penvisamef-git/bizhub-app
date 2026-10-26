// Google Play screenshots: the real app screens with sample data, phone size (360×780 dp at 3× = 1080×2340).
//   flutter test test/store/store_shots_test.dart --update-goldens --dart-define=STORE_SHOTS=true   → test/store/out/<lang>-<n>-<name>.png
// (a picture maker, not a check: the home and wallet screens show the time of day, so it only runs when asked)
// store/android/compose/ then puts each one in a phone frame with a headline (1080×1920).
import 'package:bizhub_admin/app.dart';
import 'package:bizhub_admin/core/api.dart';
import 'package:bizhub_admin/core/i18n.dart';
import 'package:bizhub_admin/core/providers.dart';
import 'package:bizhub_admin/core/theme.dart';
import 'package:bizhub_admin/features/event/ev_looks.dart';
import 'package:bizhub_admin/features/namecard/namecard_page.dart';
import 'package:bizhub_admin/features/namecard/nc_card.dart';
import 'package:bizhub_admin/features/note/nt_api.dart';
import 'package:bizhub_admin/features/note/nt_common.dart';
import 'package:bizhub_admin/features/note/nt_editor.dart';
import 'package:bizhub_admin/features/note/nt_extras_reg.dart';
import 'package:bizhub_admin/features/note/nt_share.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../nc_recipes_test.dart' show loadFonts;
import '../nt_shots_test.dart' as p1;
import 'store_data.dart';

const _size = Size(392.727, 850.909); // × 2.75 = 1080 × 2340

// ---------------------------------------------------------------- one fake API for every screen
class StoreApi extends Api {
  final String lang;
  StoreApi(this.lang) : super(token: () => 't', onUnauthorized: () {});

  @override
  Future<Json> get(String path, [Map<String, dynamic>? query]) async {
    if (path.endsWith('/user/dashboard')) return {'data': dashboard(lang)};
    if (path.endsWith('/user/wallet')) return wallet(lang);
    if (path.endsWith('/businesses-prices')) return bizPrices();
    if (path.endsWith('/public/homepage')) return homepage();
    if (path.contains('/namecard')) {
      return {
        'business': {'_id': 'b4', 'name': card(lang)['name'], 'status': true},
        'themes': {'free': freeThemes, 'premium': premiumThemes, 'price': 15},
        'licenses': {},
        'data': {
          ...card(lang),
          'published': true,
          'unlocked_themes': ['harbor', 'velvet', 'neon', 'lotus'],
        },
      };
    }
    if (path.endsWith('/note')) return {'data': noteBook()};
    if (path.endsWith('/note/groups')) return {'data': const [], 'price': 1};
    if (path.contains('/note/notes/n1')) {
      return {
        'data': {'note': note(lang), 'entries_new': 2, 'group_ids': const []},
      };
    }
    if (path.endsWith('/people')) {
      return {
        'data': const ['Dara', 'Vanna', 'Sokha'],
      };
    }
    return {'data': {}};
  }

  @override
  Future<Json> post(String path, [Object? body]) async => {'data': {}};
  @override
  Future<Json> put(String path, [Object? body]) async => {'data': note(lang)};
}

Json noteBook() {
  final b = p1.book(link: true, ack: true);
  b['business'] = {'_id': 'b6', 'name': 'Sokha Coffee', 'logo_url': ''};
  return b;
}

Json note(String lang) {
  final km = lang == 'km';
  String x(String en, String k) => km ? k : en;
  return {
    '_id': 'n1',
    'title': x('Opening week — Sokha Coffee', 'សប្តាហ៍បើកហាង — សុខា កាហ្វេ'),
    'color': 'yellow',
    'paper': 'plain',
    'pinned': true,
    'version': 4,
    'share': {
      ...p1.share('reply'),
      'slug': 'sokha-opening',
      'path': '/n/sokha-opening',
    },
    'files': [
      {
        '_id': 'f1',
        'url': '',
        'name': x('Menu 2026.pdf', 'ម៉ឺនុយ ២០២៦.pdf'),
        'size': 1258291,
        'mime': 'application/pdf',
        'kind': 'pdf',
      },
    ],
    'blocks': [
      {'id': 'a', 't': 'h', 'text': x('Before Saturday', 'មុនថ្ងៃសៅរ៍')},
      {
        'id': 'b',
        't': 'check',
        'text': x('Print the new menu', 'បោះពុម្ពម៉ឺនុយថ្មី'),
        'done': true,
        'who': x('Dara', 'ដារ៉ា'),
        'due': dayOf(1),
      },
      {
        'id': 'c',
        't': 'check',
        'text': x('Train two new baristas', 'បង្ហាត់អ្នកឆុងកាហ្វេថ្មីពីរនាក់'),
        'who': x('Vanna', 'វណ្ណា'),
        'due': dayOf(0),
      },
      {
        'id': 'd',
        't': 'check',
        'text': x('Put up the opening banner', 'ដាក់ផ្ទាំងបដាបើកហាង'),
        'who': x('Sokha', 'សុខា'),
        'due': dayOf(-2),
      },
      {
        'id': 'e',
        't': 'p',
        'text': x(
          'Free iced latte for the first 50 customers!',
          'ឡាតេទឹកកកឥតគិតថ្លៃ សម្រាប់អតិថិជន ៥០ នាក់ដំបូង!',
        ),
        'style': {'bg': 'amber', 'bold': true, 'align': 'center'},
      },
      {
        'id': 'f',
        't': 'sticker',
        'sticker': 'party',
        'style': {'size': 'sm'},
      },
      {
        'id': 'g',
        't': 'quote',
        'text': x(
          'Opening day: Saturday, 7:00 at St. 240.',
          'ថ្ងៃបើក៖ ថ្ងៃសៅរ៍ ម៉ោង ៧:០០ នៅផ្លូវ ២៤០។',
        ),
      },
      {'id': 'h', 't': 'file', 'file_id': 'f1'},
      {'id': 'i', 't': 'p', 'text': ''},
    ],
    'form': {'fields': []},
    'entry_count': 6,
    'updated_date': ago(const Duration(minutes: 8)),
  };
}

class _Me extends SessionNotifier {
  final String lang;
  _Me(this.lang);
  @override
  Session? build() => Session(me(lang));
}

NtCtx noteCtx(StoreApi api, String lang) => NtCtx(
  id: 'b6',
  a: NtApi(api, 'b6'),
  t: T.of(lang),
  data: noteBook(),
  reload: () async {},
  notify: (_) {},
  askBuy: (product, {item, qty = 1, extra}) async => false,
);

Future<void> settle(WidgetTester t, [int ms = 700]) async {
  await t.pump();
  await t.pump(Duration(milliseconds: ms));
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> shot(WidgetTester t, String name, {Finder? of}) => expectLater(
  of ?? find.byType(MaterialApp).first,
  matchesGoldenFile('out/$name.png'),
);

Widget plainApp(Widget home, String lang, {StoreApi? api}) => ProviderScope(
  overrides: [
    apiProvider.overrideWithValue(api ?? StoreApi(lang)),
    tProvider.overrideWithValue(T.of(lang)),
    sessionProvider.overrideWith(() => _Me(lang)),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(
      dark: false,
      khmer: lang == 'km',
    ).copyWith(splashFactory: InkRipple.splashFactory),
    home: home,
  ),
);

const _storeShots = bool.fromEnvironment('STORE_SHOTS');

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    await loadFonts();
    final hand = FontLoader('cursive')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-600.ttf'));
    await hand.load();
    ntRegisterExtras();
    await T.load();
  });

  for (final lang in ['en', 'km']) {
    Future<void> phone(WidgetTester t) async {
      SharedPreferences.setMockInitialValues({
        'bizhub_lang': lang,
        'bizhub_onboarded': true,
      });
      await PrefsNotifier.init();
      await t.binding.setSurfaceSize(_size);
      t.view.devicePixelRatio = 2.75;
    }

    // the real app with its header + bottom bar, opened on one route
    Future<void> route(WidgetTester t, String path) async {
      await phone(t);
      final c = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(StoreApi(lang)),
          sessionProvider.overrideWith(() => _Me(lang)),
        ],
      );
      addTearDown(c.dispose);
      await t.pumpWidget(
        UncontrolledProviderScope(container: c, child: const BizHubApp()),
      );
      c.read(routerProvider).go(path);
      await settle(t, 900);
    }

    testWidgets('$lang 1 home', (t) async {
      await route(t, '/o/home');
      await shot(t, '$lang-1-home');
    }, skip: !_storeShots);

    testWidgets('$lang 2 add business', (t) async {
      await route(t, '/o/add');
      await shot(t, '$lang-2-add');
    }, skip: !_storeShots);

    testWidgets('$lang 3 name card', (t) async {
      await phone(t);
      await t.pumpWidget(
        plainApp(
          Scaffold(
            backgroundColor: const Color(0xFF0E0F13),
            body: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 44, 14, 24),
              child: NcCard(
                card: card(lang),
                km: lang == 'km',
                yourName: '',
                viewPortfolio: lang == 'km'
                    ? 'មើលប្រវត្តិការងារ'
                    : 'View portfolio',
                fieldLabels: lang == 'km'
                    ? const {
                        'phone1': 'ទូរស័ព្ទ',
                        'email': 'អ៊ីមែល',
                        'website': 'គេហទំព័រ',
                        'telegram': 'តេឡេក្រាម',
                        'address': 'អាសយដ្ឋាន',
                      }
                    : const {
                        'phone1': 'Phone',
                        'email': 'Email',
                        'website': 'Website',
                        'telegram': 'Telegram',
                        'address': 'Address',
                      },
              ),
            ),
          ),
          lang,
        ),
      );
      await settle(t);
      await shot(t, '$lang-3-card');
    }, skip: !_storeShots);

    testWidgets('$lang 4 themes', (t) async {
      await phone(t);
      await t.pumpWidget(
        plainApp(
          NameCardPage(id: 'b4', title: card(lang)['name'] as String),
          lang,
        ),
      );
      await settle(t);
      final btn = find.textContaining(RegExp('118')); // "See all 118 themes"
      await t.scrollUntilVisible(
        btn.first,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pump();
      await t.tap(btn.first);
      await settle(t, 900);
      await t.tap(find.text(T.of(lang)('ncr.f.dark')).last);
      await settle(t, 500);
      await shot(t, '$lang-4a-gallery');
      // one theme in the big preview (swipe, Use / Unlock)
      await t.tap(
        find.text(lang == 'km' ? 'រាត្រីវ៉ែលវ៉េត' : 'Velvet Night').first,
      );
      await settle(t, 900);
      await shot(t, '$lang-4-themes');
    }, skip: !_storeShots);

    testWidgets('$lang 5 note', (t) async {
      await phone(t);
      ntNow = DateTime.now;
      final api = StoreApi(lang);
      await t.pumpWidget(
        plainApp(
          NtEditorPage(ctx: noteCtx(api, lang), nid: 'n1'),
          lang,
          api: api,
        ),
      );
      await settle(t, 900);
      await shot(t, '$lang-5-note');
    }, skip: !_storeShots);

    testWidgets('$lang 6 event', (t) async {
      await phone(t);
      final tr = T.of(lang);
      final ev = event(lang);
      await t.pumpWidget(
        plainApp(
          Scaffold(
            backgroundColor: const Color(0xFF16161D),
            body: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 360,
                  height: 780,
                  child: EvPagePreview(
                    ev: ev,
                    org: {
                      'name': lang == 'km'
                          ? 'ក្លឹបរត់ សៀមរាប'
                          : 'Siem Reap Runners',
                    },
                    theme: 'aurora',
                    t: tr,
                  ),
                ),
              ),
            ),
          ),
          lang,
        ),
      );
      await settle(t);
      await shot(t, '$lang-6-event');
      // a ticket on its own
      await t.pumpWidget(
        plainApp(
          Scaffold(
            backgroundColor: const Color(0xFFF5F4F7),
            body: Center(
              child: EvTicketView(
                ev: ev,
                tk: sampleTicket(ev, lang),
                t: tr,
                theme: 'gradient',
                width: 320,
              ),
            ),
          ),
          lang,
        ),
      );
      await settle(t);
      await shot(t, '$lang-6b-ticket');
    }, skip: !_storeShots);

    testWidgets('$lang 7 wallet', (t) async {
      await route(t, '/o/wallet');
      await shot(t, '$lang-7-wallet');
    }, skip: !_storeShots);

    testWidgets('$lang 8 share', (t) async {
      await phone(t);
      final api = StoreApi(lang);
      final ctx = noteCtx(api, lang);
      await t.pumpWidget(
        plainApp(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => ntShareNote(context, ctx, note(lang)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          lang,
          api: api,
        ),
      );
      await t.tap(find.text('open'));
      await settle(t, 900);
      await shot(t, '$lang-8-share');
      await t.tap(find.text('QR').first);
      await settle(t, 900);
      await shot(t, '$lang-8b-qr');
    }, skip: !_storeShots);
  }
}
