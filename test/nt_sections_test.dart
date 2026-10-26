// Digital Note (phase 2a) on a fake API: the dashboard sections — Groups (list / grid, a group's page with its notes
// and files, add notes, rename), Storage & plan, Media (locked / list / grid + selection), Telegram alerts (locked /
// connected), Business profile, Add-ons + the theme shop. Pictures: test/shots/nts-*.png
import 'package:bizhub_admin/core/api.dart';
import 'package:bizhub_admin/core/i18n.dart';
import 'package:bizhub_admin/core/providers.dart';
import 'package:bizhub_admin/core/theme.dart';
import 'package:bizhub_admin/features/note/nt_addons.dart';
import 'package:bizhub_admin/features/note/nt_alerts.dart';
import 'package:bizhub_admin/features/note/nt_api.dart';
import 'package:bizhub_admin/features/note/nt_common.dart';
import 'package:bizhub_admin/features/note/nt_groups.dart';
import 'package:bizhub_admin/features/note/nt_media.dart';
import 'package:bizhub_admin/features/note/nt_page.dart';
import 'package:bizhub_admin/features/note/nt_profile.dart';
import 'package:bizhub_admin/features/note/nt_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nc_recipes_test.dart' show loadFonts;

// fixed times, so the pictures are the same on every run (ntAgo uses ntNow)
final _now = DateTime.utc(2026, 10, 1, 5);
String _ago(Duration d) => _now.subtract(d).toIso8601String();
String _in(Duration d) => _now.add(d).toIso8601String();

Json share(String level, {bool pin = false}) => {'token': 'GrpTok123', 'slug': '', 'path': '/n/g/class-7a', 'level': level, 'has_pin': pin};

Json book({bool media = false, bool tg = false, bool connected = false, List<String> themes = const [], List<String> icons = const []}) => {
  'book': {'storage_used': 3221225472, 'storage_limit': 10737418240, 'file_limit': 20971520},
  'license': {'active': true, 'expires_at': '2027-08-16T00:00:00.000Z', 'days_left': 299, 'read_only': false, 'in_grace': false},
  'addons': {
    'note_style': {'active': true},
    'note_sign': {'active': false},
    'note_ack': {'active': true},
    'note_form': {'active': false},
    'note_link': {'active': false},
    'note_voice': {'active': false},
    'note_pdf': {'active': false},
    'note_media': {'active': media},
    'note_telegram': {'active': tg, if (tg) 'expires_at': _in(const Duration(days: 200))},
    'note_storage': {'packs': 1, 'slots': 2, 'active': true, 'gb_each': 5},
    'note_group': {'owned': 3},
    'note_group_icon': {'items': icons},
    'note_theme': {'items': themes},
  },
  'storage_slots': [
    {'item': 'slot-1', 'active': true, 'expires_at': _in(const Duration(days: 120))},
    {'item': 'slot-2', 'active': false, 'expires_at': _ago(const Duration(days: 20))},
  ],
  'prices': {'digital_note': 10, 'note_storage': 15, 'note_group': 1, 'note_sign': 5, 'note_style': 5, 'note_media': 8, 'note_link': 10, 'note_ack': 5, 'note_form': 5, 'note_voice': 5, 'note_pdf': 5, 'note_telegram': 10, 'note_theme': 3, 'note_group_icon': 2},
  'themes': {'owned': themes, 'price': 3},
  'link': {'owned': false, 'price': 10},
  'business': {'_id': 'b', 'name': 'Sokha Coffee', 'logo_url': ''},
  'counts': {
    'notes': 12,
    'shared': 5,
    'entries_new': 3,
    'groups': 3,
    'due': {'overdue': 0, 'today': 0, 'week': 0},
  },
  'telegram': {'configured': true, 'active': tg, 'connected': connected, 'chat_name': connected ? 'Sokha (@sokha_kh)' : '', 'lang': 'km', 'replies': true, 'replies_batch': true, 'signups': true, 'edits': false, 'acks': true, 'daily': true, 'reminders': true},
  'templates': ['blank', 'meeting', 'homework', 'checklist', 'room_rent', 'repair_job', 'trip', 'signup'],
};

final groups = <Json>[
  {
    '_id': 'g1',
    'name': 'Class 7A homework',
    'color': 'blue',
    'icon': '',
    'icon_image': '',
    'note_ids': ['n2', 'n3', 'n1'],
    'notes_count': 3,
    'files_count': 6,
    'share': share('view', pin: true),
    'updated_date': _ago(const Duration(hours: 2)),
  },
  {'_id': 'g2', 'name': 'Room 12 documents', 'color': 'green', 'icon': '', 'icon_image': '', 'note_ids': ['n3'], 'notes_count': 1, 'files_count': 1, 'share': share('off'), 'updated_date': _ago(const Duration(days: 1))},
  {
    '_id': 'g3',
    'name': 'Team · staff notices for the new shop',
    'color': 'purple',
    'icon': '🧑‍💼',
    'icon_image': '',
    'note_ids': ['n1', 'n4'],
    'notes_count': 2,
    'files_count': 0,
    'share': share('reply'),
    'updated_date': _ago(const Duration(days: 4)),
  },
];

final notes = <Json>[
  {'_id': 'n1', 'title': 'Team meeting — new shop', 'preview': 'Agenda · Opening times · Who works on Sunday', 'color': 'yellow', 'share': share('reply', pin: true)},
  {'_id': 'n2', 'title': 'Homework week 3 — Khmer literature', 'preview': 'Read pages 12–20 and write five sentences.', 'color': 'purple', 'share': share('collect')},
  {'_id': 'n3', 'title': 'Room 12 — rules', 'preview': 'Quiet after 22:00. Rent is due on the 5th.', 'color': 'green', 'share': share('view')},
  {'_id': 'n4', 'title': 'Trip to Kampot', 'preview': 'Day 1: Bokor · Day 2: pepper farm', 'color': 'blue', 'share': share('edit')},
];

Json file(String id, String name, String kind, int size, {String where = 'note', String note = 'n1', String title = 'Team meeting — new shop', String entry = '', String who = ''}) => {
  '_id': id,
  'where': where,
  'note_id': note,
  'note_title': title,
  'note_deleted': false,
  'entry_id': entry.isEmpty ? null : entry,
  'entry_name': who,
  'name': name,
  'kind': kind,
  'size': size,
  'mime': '',
  'url': '',
  'at': _ago(Duration(hours: size % 90)),
  'by': where == 'entry' ? who : 'owner',
};

final files = <Json>[
  file('f1', 'Lesson video week 3.mp4', 'video', 412000000, note: 'n2', title: 'Homework week 3 — Khmer literature'),
  file('f2', 'Room rules.pdf', 'pdf', 1258291, note: 'n3', title: 'Room 12 — rules'),
  file('f3', 'meter-october.jpg', 'image', 384000, where: 'entry', note: 'n3', title: 'Room 12 — rules', entry: 'e1', who: 'Vanna'),
  file('f4', 'price-list.xlsx', 'excel', 48213),
  file('f5', 'homework-dara.docx', 'word', 220000, where: 'entry', note: 'n2', title: 'Homework week 3 — Khmer literature', entry: 'e2', who: 'Dara'),
  file('f6', 'signature-sokha.png', 'sign', 32000, where: 'entry', note: 'n1', entry: 'e3', who: 'Sokha'),
  file('f7', 'voice-note.webm', 'audio', 920000),
  file('f8', 'photos-week3.zip', 'zip', 88000000, note: 'n2', title: 'Homework week 3 — Khmer literature'),
];

Json kinds(List<Json> rows) {
  final out = <String, Json>{};
  for (final k in ['image', 'video', 'audio', 'pdf', 'word', 'excel', 'slides', 'text', 'zip', 'sign', 'other']) {
    final list = rows.where((r) => r['kind'] == k);
    out[k] = {'count': list.length, 'bytes': list.fold<num>(0, (a, r) => a + (r['size'] as num))};
  }
  return out;
}

class FakeApi extends Api {
  final bool media;
  FakeApi({this.media = true}) : super(token: () => 't', onUnauthorized: () {});
  @override
  Future<Json> get(String path, [Map<String, dynamic>? query]) async {
    if (path.endsWith('/note')) return {'data': book(media: media)};
    if (path.endsWith('/note/notes')) return {'data': notes, 'page': 1, 'pages': 1, 'total': notes.length};
    if (path.endsWith('/note/groups')) {
      final deleted = query?['deleted'] == '1';
      return {
        'data': deleted
            ? [
                {...groups[1], '_id': 'g9', 'name': 'Old price lists', 'deleted': true},
              ]
            : groups,
      };
    }
    if (path.endsWith('/groups/g1/files')) {
      final rows = files.where((f) => f['where'] == 'note').toList();
      final k = '${query?['kind'] ?? 'all'}';
      return {
        'data': k == 'all' ? rows : rows.where((r) => r['kind'] == k).toList(),
        'page': 1,
        'pages': 1,
        'totals': {'count': rows.length, 'bytes': 0, 'kinds': kinds(rows)},
      };
    }
    if (path.endsWith('/groups/g1/seen')) {
      return {
        'data': [
          {'name': 'Sokha', 'first_at': _ago(const Duration(days: 3)), 'last_at': _ago(const Duration(minutes: 50)), 'count': 4},
          {'name': '', 'first_at': _ago(const Duration(days: 1)), 'last_at': _ago(const Duration(hours: 1)), 'count': 1},
        ],
      };
    }
    if (path.endsWith('/groups/g1/stats')) {
      return {
        'data': {
          'days': [
            for (var i = 0; i < 30; i++) {'day': '2026-10-${(i + 1).toString().padLeft(2, '0')}', 'views': (i * 7) % 11, 'people': (i * 3) % 5},
          ],
          'total': {'views': 152, 'people': 61},
          'best': {'day': '2026-10-17', 'views': 10},
        },
      };
    }
    if (path.endsWith('/note/media')) {
      final totals = {
        'used': 3221225472,
        'limit': 10737418240,
        'count': files.length,
        'bytes': files.fold<num>(0, (a, r) => a + (r['size'] as num)),
        'kinds': kinds(files),
        'top_notes': [
          {'note_id': 'n2', 'note_title': 'Homework week 3 — Khmer literature', 'count': 3, 'bytes': 500220000},
          {'note_id': 'n1', 'note_title': 'Team meeting — new shop', 'count': 3, 'bytes': 1000213},
          {'note_id': 'n3', 'note_title': 'Room 12 — rules', 'count': 2, 'bytes': 1642291},
        ],
      };
      if (!media) return {'locked': true, 'data': [], 'totals': totals, 'page': 1, 'pages': 1};
      final sorted = [...files]..sort((a, b) => (b['size'] as num).compareTo(a['size'] as num));
      return {'locked': false, 'data': sorted, 'totals': totals, 'page': 1, 'pages': 1};
    }
    return {'data': {}};
  }
}

NtCtx ctxOf(FakeApi api, {String lang = 'en', bool media = true, bool tg = false, bool connected = false, List<String> themes = const ['chalk', 'temple'], List<String> icons = const []}) => NtCtx(
  id: 'b',
  a: NtApi(api, 'b'),
  t: T.of(lang),
  data: book(media: media, tg: tg, connected: connected, themes: themes, icons: icons),
  reload: () async {},
  notify: (_) {},
  askBuy: (product, {item, qty = 1, extra}) async => false,
);

final _nav = NtNav(go: (_, {args}) {});

Widget app(Widget home, {FakeApi? api, String lang = 'en'}) => ProviderScope(
  overrides: [apiProvider.overrideWithValue(api ?? FakeApi()), tProvider.overrideWithValue(T.of(lang))],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(dark: false, khmer: lang == 'km'),
    home: Scaffold(body: SafeArea(child: home)),
  ),
);

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  await t.pump();
  await t.pump(Duration(milliseconds: ms));
}

Future<void> shot(WidgetTester t, String name) => expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/$name.png'));

void main() {
  setUpAll(() async {
    ntNow = () => _now;
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await PrefsNotifier.init();
    await T.load();
    await loadFonts();
  });

  Future<void> size(WidgetTester t, [double h = 860]) async {
    await t.binding.setSurfaceSize(Size(400, h));
    t.view.devicePixelRatio = 2;
  }

  testWidgets('groups: grid, list, deleted', (t) async {
    await size(t);
    final api = FakeApi();
    await t.pumpWidget(app(GroupsSection(ctx: ctxOf(api), nav: _nav), api: api));
    await settle(t);
    await shot(t, 'nts-groups-grid');
    await t.tap(find.byTooltip('List'));
    await settle(t);
    await shot(t, 'nts-groups-list');
    await t.enterText(find.byType(TextField).first, 'room');
    await settle(t);
    await shot(t, 'nts-groups-search');
    await t.enterText(find.byType(TextField).first, '');
    await t.tap(find.text('Deleted groups'));
    await settle(t);
    await shot(t, 'nts-groups-deleted');
  });

  testWidgets('a group: notes, files, add notes, rename', (t) async {
    await size(t, 1500);
    final api = FakeApi();
    await t.pumpWidget(app(GroupsSection(ctx: ctxOf(api, icons: const ['g3']), nav: NtNav(go: (_, {args}) {}, args: const {'group': 'g1'})), api: api));
    await settle(t, 900);
    await shot(t, 'nts-group');
    await t.tap(find.text('Files').first);
    await settle(t, 900);
    await shot(t, 'nts-group-files');
    await t.tap(find.byTooltip('List'));
    await settle(t);
    await shot(t, 'nts-group-files-list');
    await t.tap(find.text('Notes').first);
    await settle(t, 900);
    await t.tap(find.text('Add notes'));
    await settle(t, 900);
    await shot(t, 'nts-group-add');
    Navigator.of(t.element(find.text('Close'))).pop();
    await settle(t, 600);
    await t.tap(find.text('Rename'));
    await settle(t, 800);
    await shot(t, 'nts-group-rename');
  });

  testWidgets('a group with a picture unlocked, in Khmer', (t) async {
    await size(t, 1100);
    final api = FakeApi();
    await t.pumpWidget(app(GroupsSection(ctx: ctxOf(api, lang: 'km', icons: const ['g3']), nav: NtNav(go: (_, {args}) {}, args: const {'group': 'g3'})), api: api, lang: 'km'));
    await settle(t, 900);
    await shot(t, 'nts-group-km');
  });

  testWidgets('groups in Khmer', (t) async {
    await size(t);
    final api = FakeApi();
    await t.pumpWidget(app(GroupsSection(ctx: ctxOf(api, lang: 'km'), nav: _nav), api: api, lang: 'km'));
    await settle(t);
    await shot(t, 'nts-groups-km');
  });

  testWidgets('storage & plan', (t) async {
    await size(t, 1300);
    final api = FakeApi();
    await t.pumpWidget(app(StorageSection(ctx: ctxOf(api), nav: _nav), api: api));
    await settle(t);
    await t.tap(find.byIcon(LucideIcons.plus).first);
    await t.tap(find.byIcon(LucideIcons.plus).first);
    await settle(t);
    await shot(t, 'nts-storage');
  });

  testWidgets('media: locked', (t) async {
    await size(t, 1100);
    final api = FakeApi(media: false);
    await t.pumpWidget(app(MediaSection(ctx: ctxOf(api, media: false), nav: _nav), api: api));
    await settle(t);
    await shot(t, 'nts-media-locked');
  });

  testWidgets('media: list, grid, select', (t) async {
    await size(t, 1700);
    final api = FakeApi();
    await t.pumpWidget(app(MediaSection(ctx: ctxOf(api), nav: _nav), api: api));
    await settle(t);
    await shot(t, 'nts-media-list');
    await t.tap(find.text('Room rules.pdf'));
    await t.tap(find.text('meter-october.jpg'));
    await settle(t);
    await shot(t, 'nts-media-picked');
    await t.tap(find.byTooltip('Grid'));
    await settle(t);
    await shot(t, 'nts-media-grid');
  });

  testWidgets('telegram: locked, connected', (t) async {
    await size(t, 1000);
    final api = FakeApi();
    await t.pumpWidget(app(AlertsSection(ctx: ctxOf(api), nav: _nav), api: api));
    await settle(t);
    await shot(t, 'nts-alerts-locked');
    await t.pumpWidget(app(AlertsSection(key: const ValueKey('on'), ctx: ctxOf(api, tg: true, connected: true), nav: _nav), api: api));
    await settle(t);
    await shot(t, 'nts-alerts-on');
    await t.pumpWidget(app(AlertsSection(key: const ValueKey('off'), ctx: ctxOf(api, tg: true), nav: _nav), api: api));
    await settle(t);
    await shot(t, 'nts-alerts-connect');
  });

  testWidgets('business profile', (t) async {
    await size(t);
    final api = FakeApi();
    await t.pumpWidget(app(ProfileSection(ctx: ctxOf(api), nav: _nav), api: api));
    await settle(t);
    await shot(t, 'nts-profile');
  });

  testWidgets('add-ons + theme shop', (t) async {
    await size(t, 5200);
    final api = FakeApi();
    await t.pumpWidget(app(AddonsSection(ctx: ctxOf(api, tg: true, connected: true), nav: _nav), api: api));
    await settle(t);
    await shot(t, 'nts-addons');
    await size(t, 900);
    await t.pumpWidget(app(AddonsSection(key: const ValueKey('shop'), ctx: ctxOf(api), nav: _nav), api: api));
    await settle(t);
    await t.scrollUntilVisible(find.text('See the themes'), 300, scrollable: find.byType(Scrollable).first);
    await settle(t);
    await t.tap(find.text('See the themes').last);
    await settle(t, 900);
    await shot(t, 'nts-theme-shop');
    await t.ensureVisible(find.byKey(const ValueKey('theme-midnight')));
    await t.tap(find.byKey(const ValueKey('theme-midnight')));
    await settle(t, 900);
    await shot(t, 'nts-theme-look');
  });

  testWidgets('add-ons in Khmer', (t) async {
    await size(t, 1600);
    final api = FakeApi();
    await t.pumpWidget(app(AddonsSection(ctx: ctxOf(api, lang: 'km'), nav: _nav), api: api, lang: 'km'));
    await settle(t);
    await shot(t, 'nts-addons-km');
  });
}
