// Digital Note (phase 1) on a fake API: the dashboard (list / grid, Khmer), New note, the editor with every block
// type, the conflict banner and the share sheet (levels, custom link free / taken / locked, a group).
// Pictures: test/shots/nt-*.png
import 'package:bizhub_admin/core/api.dart';
import 'package:bizhub_admin/core/i18n.dart';
import 'package:bizhub_admin/core/providers.dart';
import 'package:bizhub_admin/core/theme.dart';
import 'package:bizhub_admin/features/note/nt_api.dart';
import 'package:bizhub_admin/features/note/nt_common.dart';
import 'package:bizhub_admin/features/note/nt_editor.dart';
import 'package:bizhub_admin/features/note/nt_page.dart';
import 'package:bizhub_admin/features/note/nt_share.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nc_recipes_test.dart' show loadFonts;

// fixed times, so the pictures are the same on every run (ntAgo uses ntNow)
final _now = DateTime.utc(2026, 10, 1, 5);
String _ago(Duration d) => _now.subtract(d).toIso8601String();

Json book({bool link = false, bool ack = false, bool style = true}) => {
  'book': {'storage_used': 734003200, 'storage_limit': 5368709120, 'file_limit': 20971520},
  'license': {'active': true, 'expires_at': '2027-08-16T00:00:00.000Z', 'days_left': 299, 'read_only': false, 'in_grace': false},
  'addons': {
    'note_style': {'active': style},
    'note_sign': {'active': true},
    'note_ack': {'active': ack},
    'note_link': {'active': link},
    'note_voice': {'active': false},
    'note_media': {'active': false},
    'note_telegram': {'active': false},
    'note_storage': {'packs': 0, 'slots': 0, 'active': false, 'gb_each': 5},
    'note_group_icon': {'items': []},
    'note_theme': {'items': []},
  },
  'storage_slots': [],
  'prices': {'digital_note': 10, 'note_storage': 15, 'note_group': 1, 'note_sign': 5, 'note_style': 5, 'note_media': 8, 'note_link': 10, 'note_ack': 5, 'note_form': 5, 'note_voice': 5, 'note_pdf': 5, 'note_telegram': 10, 'note_theme': 3, 'note_group_icon': 2},
  'themes': {'owned': [], 'price': 3},
  'link': {'owned': link, 'price': 10},
  'business': {'_id': 'b', 'name': 'Sokha Coffee', 'logo_url': ''},
  'counts': {
    'notes': 12,
    'shared': 5,
    'entries_new': 3,
    'groups': 3,
    'due': {'overdue': 2, 'today': 1, 'week': 3},
  },
  'templates': ['blank', 'meeting', 'homework', 'checklist', 'room_rent', 'repair_job', 'trip', 'signup'],
};

Json share(String level, {bool pin = false, String slug = '', bool ack = false}) => {
  'token': 'UjkylAidWOOCeQJP1mSEfP',
  'slug': slug,
  'path': '/n/${slug.isNotEmpty ? slug : 'UjkylAidWOOCeQJP1mSEfP'}',
  'level': level,
  'has_pin': pin,
  'expires_at': null,
  'allow_files': true,
  'show_entries': true,
  'ask_name': true,
  'hide_owner': false,
  'no_copy': false,
  'ack': ack,
  'opens_at': null,
};

final groups = [
  {'_id': 'g1', 'name': 'Class 7A homework', 'color': 'blue', 'icon': '', 'icon_image': '', 'notes_count': 4, 'share': share('view')},
  {'_id': 'g2', 'name': 'Room 12 documents', 'color': 'green', 'icon': '', 'icon_image': '', 'notes_count': 2, 'share': share('off')},
  {'_id': 'g3', 'name': 'Team', 'color': 'purple', 'icon': '🧑‍💼', 'icon_image': '', 'notes_count': 1, 'share': share('reply')},
];

final rows = [
  {
    '_id': 'n1',
    'title': 'Team meeting — new shop',
    'preview': 'Agenda · Opening times for the new shop · Who works on Sunday',
    'color': 'yellow',
    'pinned': true,
    'share': share('reply', pin: true),
    'entry_count': 4,
    'files_count': 2,
    'group_ids': ['g3'],
    'due': {'overdue': 1, 'today': 0, 'week': 1},
    'updated_date': _ago(const Duration(minutes: 12)),
  },
  {
    '_id': 'n2',
    'title': 'Homework week 3 — Khmer literature',
    'preview': 'Read pages 12–20 and write five sentences about the story.',
    'color': 'purple',
    'pinned': false,
    'share': share('collect'),
    'entry_count': 18,
    'files_count': 0,
    'group_ids': ['g1'],
    'due': {'overdue': 0, 'today': 1, 'week': 0},
    'updated_date': _ago(const Duration(hours: 3)),
  },
  {
    '_id': 'n3',
    'title': 'Room 12 — rules',
    'preview': 'Quiet after 22:00. Rent is due on the 5th of every month.',
    'color': 'green',
    'pinned': false,
    'share': share('view'),
    'entry_count': 0,
    'files_count': 1,
    'group_ids': ['g2', 'g1'],
    'due': {'overdue': 0, 'today': 0, 'week': 0},
    'updated_date': _ago(const Duration(days: 2)),
  },
  {
    '_id': 'n4',
    'title': 'Trip to Kampot',
    'preview': 'Day 1: Bokor · Day 2: pepper farm · Bring: hat, water',
    'color': 'blue',
    'pinned': false,
    'share': share('edit'),
    'entry_count': 2,
    'files_count': 0,
    'group_ids': [],
    'due': {'overdue': 0, 'today': 0, 'week': 2},
    'updated_date': _ago(const Duration(days: 5)),
  },
  {
    '_id': 'n5',
    'title': '',
    'preview': '',
    'color': 'default',
    'pinned': false,
    'share': share('off'),
    'entry_count': 0,
    'files_count': 0,
    'group_ids': [],
    'due': {},
    'updated_date': _ago(const Duration(days: 9)),
  },
];

Json fullNote({int version = 7, String title = 'Team meeting — new shop'}) => {
  '_id': 'n1',
  'title': title,
  'color': 'yellow',
  'paper': 'plain',
  'pinned': true,
  'version': version,
  'share': share('reply', pin: true),
  'files': [
    {'_id': 'f1', 'url': '', 'name': 'Room rules.pdf', 'size': 1258291, 'mime': 'application/pdf', 'kind': 'pdf'},
    {'_id': 'f2', 'url': '', 'name': 'price-list.xlsx', 'size': 48213, 'mime': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'kind': 'doc'},
  ],
  'blocks': [
    {'id': 'a', 't': 'h', 'text': 'Agenda'},
    {'id': 'b', 't': 'bullet', 'text': 'Opening times for the new shop'},
    {'id': 'c', 't': 'bullet', 'text': 'Who works on Sunday'},
    {'id': 'd', 't': 'p', 'text': 'Please add your ideas below before Friday. Short is fine — one line each.'},
    {'id': 'e', 't': 'h', 'text': 'To do'},
    {'id': 'f', 't': 'check', 'text': 'Order the new sign', 'done': true},
    {'id': 'g', 't': 'check', 'text': 'Print the price list'},
    {'id': 'h', 't': 'quote', 'text': 'Meeting on Saturday 9:00 at the shop.'},
    {
      'id': 'i',
      't': 'callout',
      'text': 'Bring the keys for the back door.',
      'icon': '🔑',
      'style': {'bg': 'amber'},
    },
    {
      'id': 'j',
      't': 'p',
      'text': 'Big red line, in the middle',
      'style': {'color': 'red', 'size': 'lg', 'align': 'center', 'bold': true},
    },
    {
      'id': 'k',
      't': 'p',
      'text': 'A highlighted line',
      'style': {'bg': 'green'},
    },
    {'id': 'l', 't': 'divider'},
    {
      'id': 'm',
      't': 'sticker',
      'sticker': 'star',
      'style': {'size': 'sm'},
    },
    {'id': 'n', 't': 'file', 'file_id': 'f1'},
    {'id': 'o', 't': 'file', 'file_id': 'f2'},
    {'id': 'p', 't': 'p', 'text': ''},
  ],
  'form': {'fields': []},
  'entry_count': 4,
  'updated_date': _ago(const Duration(minutes: 12)),
};

class FakeApi extends Api {
  final bool linkOwned;
  bool conflict = false;
  FakeApi({this.linkOwned = false}) : super(token: () => 't', onUnauthorized: () {});
  @override
  Future<Json> get(String path, [Map<String, dynamic>? query]) async {
    if (path.endsWith('/note')) return {'data': book(link: linkOwned)};
    if (path.endsWith('/note/notes')) return {'data': rows, 'page': 1, 'pages': 1, 'total': rows.length};
    if (path.endsWith('/note/groups')) return {'data': groups, 'price': 1};
    if (path.endsWith('/note/templates')) {
      return {
        'data': [
          {'_id': 't1', 'name': 'Weekly staff meeting', 'color': 'blue', 'blocks_count': 9},
        ],
      };
    }
    if (path.contains('/note/notes/n1')) {
      return {
        'data': {
          'note': fullNote(),
          'entries_new': 3,
          'group_ids': ['g3'],
        },
      };
    }
    if (path.endsWith('/link-check')) {
      final s = '${query?['slug']}';
      if (s.startsWith('menu')) {
        return {
          'data': {
            'slug': s,
            'ok': false,
            'reason': 'taken',
            'dropped': false,
            'suggestions': ['$s-2', 'sokha-$s', '$s-kh'],
          },
        };
      }
      return {
        'data': {'slug': s, 'ok': true, 'reason': '', 'dropped': false, 'suggestions': []},
      };
    }
    return {'data': {}};
  }

  @override
  Future<Json> put(String path, [Object? body]) async {
    if (conflict && body is Map && body.containsKey('blocks')) {
      throw ApiError(409, 'conflict', code: 'conflict', body: {'code': 'conflict', 'data': fullNote(version: 9, title: 'Team meeting — NEW TIME')});
    }
    return {'data': fullNote(version: 8)};
  }
}

NtCtx ctxOf(FakeApi api, {String lang = 'en', bool link = false, bool ack = false}) => NtCtx(
  id: 'b',
  a: NtApi(api, 'b'),
  t: T.of(lang),
  data: book(link: link, ack: ack),
  reload: () async {},
  notify: (_) {},
  askBuy: (product, {item, qty = 1, extra}) async => false,
);

Widget app(Widget home, {FakeApi? api, String lang = 'en'}) => ProviderScope(
  overrides: [apiProvider.overrideWithValue(api ?? FakeApi()), tProvider.overrideWithValue(T.of(lang))],
  child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(dark: false, khmer: lang == 'km'), home: home),
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

  setUp(() {
    ntSetView('notes', 'list');
  });

  Future<void> size(WidgetTester t, [double h = 860]) async {
    await t.binding.setSurfaceSize(Size(400, h));
    t.view.devicePixelRatio = 2;
  }

  testWidgets('dashboard: list, grid, new note', (t) async {
    await size(t);
    await t.pumpWidget(app(const NotePage(id: 'b', title: 'Sokha Coffee')));
    await settle(t);
    await shot(t, 'nt-list');
    await t.tap(find.byTooltip('Grid'));
    await settle(t);
    await shot(t, 'nt-grid');
    await t.tap(find.text('New note').first);
    await settle(t, 800);
    await shot(t, 'nt-new');
  });

  testWidgets('dashboard in Khmer', (t) async {
    await size(t);
    await t.pumpWidget(app(const NotePage(id: 'b', title: 'Sokha Coffee'), lang: 'km'));
    await settle(t);
    await shot(t, 'nt-list-km');
    await t.tap(find.text(T.of('km')('note.allSections'))); // the sections menu
    await settle(t, 800);
    await shot(t, 'nt-sections-km');
  });

  testWidgets('editor with every block', (t) async {
    await size(t, 1500);
    final api = FakeApi();
    await t.pumpWidget(app(NtEditorPage(ctx: ctxOf(api), nid: 'n1'), api: api));
    await settle(t);
    await shot(t, 'nt-editor');
    // tap a line: the toolbar shows its type
    await t.tap(find.textContaining('Who works on Sunday'));
    await settle(t);
    await shot(t, 'nt-editor-focus');
  });

  testWidgets('conflict banner', (t) async {
    await size(t);
    final api = FakeApi()..conflict = true;
    await t.pumpWidget(app(NtEditorPage(ctx: ctxOf(api), nid: 'n1'), api: api));
    await settle(t);
    await t.enterText(find.byType(TextField).at(2), '​My new line');
    await t.pump(const Duration(milliseconds: 1700));
    await settle(t);
    await shot(t, 'nt-conflict');
  });

  testWidgets('editor in Khmer', (t) async {
    await size(t, 1100);
    final api = FakeApi();
    await t.pumpWidget(app(NtEditorPage(ctx: ctxOf(api, lang: 'km'), nid: 'n1'), api: api, lang: 'km'));
    await settle(t);
    await shot(t, 'nt-editor-km');
  });

  Future<void> openShare(WidgetTester t, NtCtx ctx, {bool group = false}) async {
    await t.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => group ? ntShareGroup(context, ctx, groups.first, pinNotes: 2) : ntShareNote(context, ctx, fullNote(), groupCount: 1),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        api: ctx.api as FakeApi,
      ),
    );
    await t.tap(find.text('open'));
    await settle(t, 800);
  }

  Future<void> toLink(WidgetTester t) async {
    final field = find.byType(TextField).last;
    await t.scrollUntilVisible(field, 300, scrollable: find.byType(Scrollable).last);
    await settle(t);
  }

  testWidgets('share sheet: levels, link free / taken', (t) async {
    await size(t);
    final api = FakeApi(linkOwned: true);
    await openShare(t, ctxOf(api, link: true));
    await shot(t, 'nt-share');
    await toLink(t);
    await t.enterText(find.byType(TextField).last, 'menu');
    await t.pump(const Duration(milliseconds: 500));
    await settle(t);
    await shot(t, 'nt-share-taken');
    await t.enterText(find.byType(TextField).last, 'sokha-coffee-menu');
    await t.pump(const Duration(milliseconds: 500));
    await settle(t);
    await shot(t, 'nt-share-free');
  });

  testWidgets('share sheet: locked link', (t) async {
    await size(t);
    final api = FakeApi();
    await openShare(t, ctxOf(api));
    await t.scrollUntilVisible(find.text('Custom link'), 300, scrollable: find.byType(Scrollable).last);
    await t.drag(find.byType(Scrollable).last, const Offset(0, -300));
    await settle(t);
    await shot(t, 'nt-share-locked');
  });

  testWidgets('share sheet: a group', (t) async {
    await size(t);
    await openShare(t, ctxOf(FakeApi()), group: true);
    await shot(t, 'nt-share-group');
    await t.scrollUntilVisible(find.text('PIN (4–8 numbers)'), 300, scrollable: find.byType(Scrollable).last);
    await settle(t);
    await shot(t, 'nt-share-group-pin');
  });
}
