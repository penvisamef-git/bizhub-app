// Digital Note phase 2b on a fake API: the editor extras (style pack, stickers, emoji, paper, sign / draw pad, voice
// recorder + player, due & who, form fields), the note tabs (replies, sign-up table, confirmed, seen + views, files,
// history), the Look sheet, the PDF preview + a rendered page, locked states and Khmer. Pictures: test/shots/ntx-*.png
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:bizhub_admin/core/api.dart';
import 'package:bizhub_admin/core/i18n.dart';
import 'package:bizhub_admin/core/providers.dart';
import 'package:bizhub_admin/features/note/nt_api.dart';
import 'package:bizhub_admin/features/note/nt_blocks.dart';
import 'package:bizhub_admin/features/note/nt_common.dart';
import 'package:bizhub_admin/features/note/nt_draw.dart';
import 'package:bizhub_admin/features/note/nt_due.dart';
import 'package:bizhub_admin/features/note/nt_editor.dart';
import 'package:bizhub_admin/features/note/nt_export.dart';
import 'package:bizhub_admin/features/note/nt_extras_reg.dart';
import 'package:bizhub_admin/features/note/nt_form.dart';
import 'package:bizhub_admin/features/note/nt_look.dart';
import 'package:bizhub_admin/features/note/nt_pdf.dart';
import 'package:bizhub_admin/features/note/nt_style.dart';
import 'package:bizhub_admin/features/note/nt_voice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nc_recipes_test.dart' show loadFonts;
import 'nt_shots_test.dart' as p1;

// fixed times (the pictures stay the same every run); due dates + the chart stay relative to today
final _now = DateTime.utc(2026, 10, 1, 5);
String _ago(Duration d) => _now.subtract(d).toIso8601String();
String _day(int add) {
  final x = DateTime.now().toUtc().add(const Duration(hours: 7)).add(Duration(days: add));
  return '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
}

Json bookX({bool all = true, bool style = true}) {
  final b = p1.book(style: style, ack: all);
  final addons = Map<String, dynamic>.from(b['addons'] as Map);
  for (final k in ['note_voice', 'note_form', 'note_pdf', 'note_sign']) {
    addons[k] = {'active': all};
  }
  return {...b, 'addons': addons, 'themes': {'owned': all ? ['paper', 'midnight'] : [], 'price': 3}};
}

Json noteX({String level = 'reply', String paper = 'plain', bool ack = true}) {
  final n = p1.fullNote();
  final blocks = [
    {'id': 'a', 't': 'h', 'text': 'Opening week'},
    {'id': 'b', 't': 'check', 'text': 'Order the new sign', 'done': true, 'due': _day(-2), 'who': 'Dara'},
    {'id': 'c', 't': 'check', 'text': 'Print the price list', 'due': '${_day(-1)}T09:00', 'who': 'Sokha'},
    {'id': 'd', 't': 'check', 'text': 'Call the painter', 'due': _day(0)},
    {'id': 'e', 't': 'callout', 'text': 'Bring the keys for the back door.', 'icon': '🔑', 'style': {'bg': 'amber'}},
    {
      'id': 'f',
      't': 'p',
      'text': 'Big blue line in the middle',
      'style': {'color': 'blue', 'size': 'lg', 'align': 'center', 'bold': true},
    },
    {'id': 'g', 't': 'divider'},
    {'id': 'h', 't': 'sticker', 'sticker': 'heart', 'style': {'align': 'center'}},
    {'id': 'i', 't': 'audio', 'file_id': 'v1'},
    {'id': 'j', 't': 'draw', 'file_id': 's1'},
    {'id': 'k', 't': 'p', 'text': ''},
  ];
  final share = Map<String, dynamic>.from(n['share'] as Map)
    ..['level'] = level
    ..['ack'] = ack;
  return {
    ...n,
    'paper': paper,
    'share': share,
    'blocks': blocks,
    'theme': {'key': 'paper', 'color': ''},
    'form': {
      'fields': level == 'collect'
          ? [
              {'id': 'f1', 'label': 'Phone', 'type': 'phone', 'required': true, 'options': []},
              {'id': 'f2', 'label': 'Shirt size', 'type': 'choice', 'required': false, 'options': ['S', 'M', 'L']},
              {'id': 'f3', 'label': 'Lunch', 'type': 'checkbox', 'required': false, 'options': []},
            ]
          : [],
    },
    'files': [
      ...n['files'] as List,
      {'_id': 'v1', 'url': '', 'name': 'voice-1729.m4a', 'size': 182000, 'mime': 'audio/mp4', 'kind': 'audio', 'voice': true},
      {'_id': 's1', 'url': '', 'name': 'signature.png', 'size': 22000, 'mime': 'image/png', 'kind': 'image', 'sign': true},
    ],
  };
}

final replies = [
  {'_id': 'e1', 'kind': 'reply', 'name': 'Sokha', 'text': 'Opening at 7:30 is better — people buy coffee on the way to work.', 'files': [], 'hidden': false, 'by_owner': false, 'new': true, 'created_date': _ago(const Duration(minutes: 50))},
  {
    '_id': 'e2',
    'kind': 'reply',
    'name': 'Vanna',
    'text': 'I can work Sunday morning.',
    'files': [
      {'_id': 'x1', 'url': '', 'name': 'schedule.pdf', 'size': 205000, 'mime': 'application/pdf'},
      {'_id': 'x2', 'url': '', 'name': 'voice-2.m4a', 'size': 92000, 'mime': 'audio/mp4', 'voice': true},
    ],
    'hidden': false,
    'by_owner': false,
    'new': false,
    'created_date': _ago(const Duration(hours: 3)),
  },
  {'_id': 'e3', 'kind': 'reply', 'name': 'Sokha Coffee', 'text': 'Thanks! See you Saturday.', 'files': [], 'hidden': false, 'by_owner': true, 'new': false, 'created_date': _ago(const Duration(hours: 2))},
  {'_id': 'e4', 'kind': 'reply', 'name': 'Guest', 'text': 'Spam spam', 'files': [], 'hidden': true, 'by_owner': false, 'new': false, 'created_date': _ago(const Duration(days: 1))},
];

final signups = [
  for (final (i, (name, phone, size, lunch)) in [('Dara', '012 345 678', 'M', true), ('Vanna', '+855 17 222 333', 'S', false), ('Sokha', '096 111 2222', 'L', true), ('Bopha', '011 909 808', 'M', true)].indexed)
    {
      '_id': 'r$i',
      'kind': 'collect',
      'name': name,
      'text': i == 1 ? 'I will come a bit late.' : '',
      'fields': {'f1': phone, 'f2': size, 'f3': lunch},
      'files': i == 0
          ? [
              {'_id': 'y$i', 'url': '', 'name': 'id-card.jpg', 'size': 120000, 'mime': 'image/jpeg'},
            ]
          : [],
      'hidden': false,
      'by_owner': false,
      'new': i == 0,
      'created_date': _ago(Duration(hours: 2 + i * 5)),
    },
];

class FakeX extends p1.FakeApi {
  String level;
  String paper;
  FakeX({this.level = 'reply', this.paper = 'plain'});
  final saved = <Json>[];
  @override
  Future<Json> get(String path, [Map<String, dynamic>? query]) async {
    if (path.endsWith('/note/notes/n1')) {
      return {
        'data': {
          'note': noteX(level: level, paper: paper),
          'entries_new': 1,
          'group_ids': ['g3'],
        },
      };
    }
    if (path.endsWith('/entries')) return {'data': level == 'collect' ? signups : replies, 'page': 1, 'pages': 1, 'total': level == 'collect' ? signups.length : replies.length};
    if (path.endsWith('/acks')) {
      return {
        'data': [
          {'name': 'Sokha', 'at': _ago(const Duration(hours: 1)), 'by_group': false},
          {'name': 'Dara', 'at': _ago(const Duration(hours: 5)), 'by_group': true},
        ],
        'not_confirmed': [
          {'name': 'Vanna', 'first_at': _ago(const Duration(days: 1)), 'last_at': _ago(const Duration(hours: 9))},
        ],
        'counts': {'confirmed': 2, 'opened_not_confirmed': 1},
      };
    }
    if (path.endsWith('/seen')) {
      return {
        'data': [
          {'name': 'Sokha', 'first_at': _ago(const Duration(days: 3)), 'last_at': _ago(const Duration(minutes: 50)), 'count': 4},
          {'name': 'Vanna', 'first_at': _ago(const Duration(days: 2)), 'last_at': _ago(const Duration(hours: 3)), 'count': 2},
          {'name': '', 'first_at': _ago(const Duration(days: 1)), 'last_at': _ago(const Duration(hours: 20)), 'count': 1},
        ],
      };
    }
    if (path.endsWith('/stats')) {
      final days = [for (var i = 29; i >= 0; i--) {'day': _day(-i), 'views': [0, 2, 5, 1, 0, 8, 3, 4, 0, 12, 6, 2][i % 12], 'people': [0, 1, 3, 1, 0, 4, 2, 2, 0, 6, 3, 1][i % 12]}];
      return {
        'data': {
          'days': days,
          'total': {'views': days.fold<num>(0, (a, d) => a + (d['views'] as num)), 'people': days.fold<num>(0, (a, d) => a + (d['people'] as num))},
          'best': {'day': days.firstWhere((d) => d['views'] == 12)['day'], 'views': 12},
        },
      };
    }
    if (path.contains('/history/')) {
      return {
        'data': {
          '_id': 'h2',
          'version': 6,
          'title': 'Team meeting — new shop',
          'blocks': [
            {'id': 'a', 't': 'h', 'text': 'Agenda'},
            {'id': 'b', 't': 'bullet', 'text': 'Opening times'},
            {'id': 'c', 't': 'p', 'text': 'Old text before the change.'},
          ],
        },
      };
    }
    if (path.endsWith('/history')) {
      return {
        'data': [
          {'_id': 'h1', 'version': 7, 'by': 'owner', 'at': _ago(const Duration(minutes: 12)), 'title': 'Team meeting — new shop'},
          {'_id': 'h2', 'version': 6, 'by': 'Dara', 'at': _ago(const Duration(hours: 3)), 'title': 'Team meeting — new shop'},
          {'_id': 'h3', 'version': 3, 'by': 'owner', 'at': _ago(const Duration(days: 1)), 'title': 'Team meeting'},
        ],
      };
    }
    if (path.endsWith('/people')) return {'data': ['Dara', 'Sokha', 'Vanna', 'Bopha']};
    return super.get(path, query);
  }

  @override
  Future<Json> put(String path, [Object? body]) async {
    if (body is Map) saved.add(Map<String, dynamic>.from(body));
    return {'data': noteX(level: level, paper: paper)};
  }
}

NtCtx ctxX(FakeX api, {String lang = 'en', bool all = true, bool style = true}) => NtCtx(
  id: 'b',
  a: NtApi(api, 'b'),
  t: T.of(lang),
  data: bookX(all: all, style: style),
  reload: () async {},
  notify: (_) {},
  askBuy: (product, {item, qty = 1, extra}) async => false,
);

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  await t.pump();
  await t.pump(Duration(milliseconds: ms));
}

Future<void> shot(WidgetTester t, String name) => expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/$name.png'));

// a button that opens something on a fresh screen
Widget opener(Future<void> Function(BuildContext context) open) => Builder(
  builder: (context) => Scaffold(
    body: Center(
      child: ElevatedButton(onPressed: () => open(context), child: const Text('open')),
    ),
  ),
);

void main() {
  setUpAll(() async {
    ntNow = () => _now; // "… ago" texts and the PDF footer time stay the same on every run
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({'note_emoji_recent': '🎉\u0001👍\u0001☕'});
    await PrefsNotifier.init();
    await T.load();
    await loadFonts();
    final hand = FontLoader('cursive')..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-600.ttf'));
    await hand.load();
    ntRegisterExtras();
  });

  Future<void> size(WidgetTester t, [double h = 860]) async {
    await t.binding.setSurfaceSize(Size(400, h));
    t.view.devicePixelRatio = 2;
  }

  Future<NtEditorState> editor(WidgetTester t, FakeX api, {String lang = 'en', bool all = true, bool style = true}) async {
    await t.pumpWidget(p1.app(NtEditorPage(key: UniqueKey(), ctx: ctxX(api, lang: lang, all: all, style: style), nid: 'n1'), api: api, lang: lang));
    await settle(t);
    return t.state<NtEditorState>(find.byType(NtEditorPage));
  }

  Future<void> tab(WidgetTester t, String label) async {
    // the tab bar scrolls sideways: bring the tab into view first
    final bar = find.descendant(of: find.byKey(const ValueKey('nt-note-tabs')), matching: find.byType(Scrollable)).first;
    await t.scrollUntilVisible(find.text(label).first, 120, scrollable: bar);
    await t.tap(find.text(label).first);
    await settle(t, 800);
  }

  testWidgets('editor: every extra block + the toolbar', (t) async {
    await size(t, 1500);
    final ed = await editor(t, FakeX());
    await shot(t, 'ntx-editor');
    // a checklist line selected: the due tool shows in the toolbar
    await t.tap(find.textContaining('Print the price list'));
    await settle(t);
    expect(ed.currentBlock?.t, 'check');
    await t.drag(find.byType(ListView).last, const Offset(-500, 0));
    await settle(t);
    await shot(t, 'ntx-toolbar');
  });

  testWidgets('editor: style pack locked', (t) async {
    await size(t, 900);
    await editor(t, FakeX(), all: false, style: false);
    await t.tap(find.textContaining('Opening week'));
    await settle(t);
    await t.drag(find.byType(ListView).last, const Offset(-420, 0));
    await settle(t);
    await shot(t, 'ntx-locked');
  });

  testWidgets('paper: lined and night', (t) async {
    await size(t, 900);
    await editor(t, FakeX(paper: 'lined'));
    await shot(t, 'ntx-paper-lined');
    await editor(t, FakeX(paper: 'night'));
    await shot(t, 'ntx-paper-night');
  });

  testWidgets('style sheet, emoji, stickers, paper picker', (t) async {
    await size(t, 1000);
    final ed = await editor(t, FakeX());
    await t.tap(find.textContaining('Big blue line'));
    await settle(t);
    ntStyleSheet(ed);
    await settle(t, 900);
    await shot(t, 'ntx-style');
    Navigator.of(ed.context).pop();
    await settle(t, 600);
    ntEmojiTool(ed);
    await settle(t, 900);
    await shot(t, 'ntx-emoji');
    await t.tap(find.text('🍜'));
    await settle(t, 400);
    await shot(t, 'ntx-emoji-food');
    Navigator.of(ed.context).pop();
    await settle(t, 600);
    ntStickerSheet(ed);
    await settle(t, 900);
    await shot(t, 'ntx-stickers');
    await t.tap(find.text('Cambodia'));
    await settle(t, 400);
    await shot(t, 'ntx-stickers-kh');
    Navigator.of(ed.context).pop();
    await settle(t, 600);
    ntPaperSheet(ed);
    await settle(t, 900);
    await shot(t, 'ntx-paper-pick');
  });

  testWidgets('sign / draw pad', (t) async {
    await size(t, 860);
    final strokes = [
      NtStroke([for (var i = 0; i <= 40; i++) Offset(40 + i * 6.0, 220 - 40 * (i / 40) * (1 - i / 40) * 4 + (i.isEven ? 6 : 0))], const Color(0xFF111827), 2.6),
      NtStroke([for (var i = 0; i <= 20; i++) Offset(120 + i * 5.0, 190 + (i % 5) * 6.0)], const Color(0xFF1D4ED8), 2.6),
    ];
    await t.pumpWidget(p1.app(NtPadPage(ctx: ctxX(FakeX()), name: 'Sokha Chan', strokes: strokes)));
    await settle(t);
    await shot(t, 'ntx-pad-sign');
    await t.tap(find.text('Drawing'));
    await settle(t);
    await shot(t, 'ntx-pad-draw');
    // the clean PNG it saves
    final png = await t.runAsync(() => ntRenderPad(strokes, const Size(360, 280), sign: true, caption: 'Signed by Sokha Chan · 21 Oct 2026'));
    expect(png!.sublist(1, 4), utf8.encode('PNG'));
  });

  testWidgets('voice recorder + player', (t) async {
    await size(t, 760);
    for (final (state, secs) in [('idle', 0), ('recording', 75), ('done', 92), ('denied', 0)]) {
      await t.pumpWidget(p1.app(Scaffold(body: Align(alignment: Alignment.bottomCenter, child: NtRecorder(key: UniqueKey(), ctx: ctxX(FakeX()), initial: state, initialSecs: secs)))));
      await settle(t);
      await shot(t, 'ntx-voice-$state');
    }
    await t.pumpWidget(
      p1.app(
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: NtAudioPlayer(ctx: ctxX(FakeX()), file: const {'_id': 'v1', 'url': '', 'name': 'voice-1729.m4a', 'voice': true}),
          ),
        ),
      ),
    );
    await settle(t);
    await shot(t, 'ntx-voice-player');
  });

  testWidgets('due & who sheet', (t) async {
    await size(t, 860);
    final api = FakeX();
    await t.pumpWidget(p1.app(opener((c) => showModalBottomSheet<void>(context: c, isScrollControlled: true, showDragHandle: true, builder: (_) => NtDueSheet(ctx: ctxX(api), due: '${_day(1)}T09:30', who: 'Da'))), api: api));
    await t.tap(find.text('open'));
    await settle(t, 900);
    await shot(t, 'ntx-due');
  });

  testWidgets('form fields', (t) async {
    await size(t, 1300);
    final api = FakeX(level: 'collect');
    await t.pumpWidget(p1.app(NtFormPage(ctx: ctxX(api), note: noteX(level: 'collect')), api: api));
    await settle(t);
    await shot(t, 'ntx-form');
    await t.pumpWidget(p1.app(NtFormPage(key: UniqueKey(), ctx: ctxX(api, all: false), note: {...noteX(level: 'collect'), 'form': {'fields': []}}), api: api));
    await settle(t);
    await shot(t, 'ntx-form-locked');
  });

  testWidgets('tabs: replies, confirmed, seen, files, history', (t) async {
    await size(t, 1200);
    await editor(t, FakeX());
    await tab(t, 'Replies');
    await shot(t, 'ntx-tab-replies');
    await tab(t, 'Confirmed');
    await shot(t, 'ntx-tab-acks');
    await tab(t, 'Seen by');
    await shot(t, 'ntx-tab-seen');
    await t.tapAt(const Offset(200, 330)); // a bar of the chart
    await settle(t);
    await tab(t, 'Files');
    await shot(t, 'ntx-tab-files');
    await tab(t, 'History');
    await shot(t, 'ntx-tab-history');
    await t.tap(find.textContaining('Dara').first);
    await settle(t, 900);
    await shot(t, 'ntx-history-preview');
  });

  testWidgets('tabs: sign-up table', (t) async {
    await size(t, 1000);
    await editor(t, FakeX(level: 'collect'));
    await tab(t, 'Responses');
    await shot(t, 'ntx-tab-rows');
  });

  testWidgets('tabs in Khmer', (t) async {
    await size(t, 1100);
    await editor(t, FakeX(level: 'collect'), lang: 'km');
    await tab(t, T.of('km')('note.collectTab'));
    await shot(t, 'ntx-tab-rows-km');
    await tab(t, T.of('km')('note.noteTabs.seen'));
    await shot(t, 'ntx-tab-seen-km');
  });

  testWidgets('look sheet', (t) async {
    await size(t, 900);
    final api = FakeX();
    final ctx = ctxX(api);
    final note = noteX();
    Future<void> open(BuildContext c, String key) =>
        ntLookSheet(c, ctx, theme: {'key': key, 'color': ''}, title: 'Team meeting — new shop', blocks: [for (final b in note['blocks'] as List) NtBlock.fromJson(b as Json)], save: (_) async => true);
    await t.pumpWidget(p1.app(opener((c) => open(c, 'paper')), api: api));
    await t.tap(find.text('open'));
    await settle(t, 900);
    await shot(t, 'ntx-look-paper');
    await t.pumpWidget(p1.app(opener((c) => open(c, 'festival')), api: api));
    await t.tap(find.text('open'));
    await settle(t, 900);
    await shot(t, 'ntx-look-locked');
  });

  testWidgets('every theme preview', (t) async {
    await t.binding.setSurfaceSize(const Size(1300, 1500));
    t.view.devicePixelRatio = 1;
    final note = noteX();
    final blocks = [for (final b in note['blocks'] as List) NtBlock.fromJson(b as Json)];
    await t.pumpWidget(
      p1.app(
        Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final k in ntLooks.keys)
                  Column(
                    children: [
                      NtThemePreview(themeKey: k, title: 'Team meeting', bizName: 'Sokha Coffee', blocks: blocks, width: 190),
                      Text(k),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await settle(t);
    await shot(t, 'ntx-themes');
  });

  testWidgets('PDF preview + a page', (t) async {
    await size(t, 1100);
    final api = FakeX(level: 'collect');
    final note = noteX(level: 'collect');
    final data = {
      'note': note,
      'business': {'name': 'Sokha Coffee', 'logo_url': ''},
      'entries': signups,
      'acks': [
        {'name': 'Sokha', 'at': _ago(const Duration(hours: 1))},
        {'name': 'Dara', 'at': _ago(const Duration(hours: 5))},
      ],
      'theme': {'key': 'paper', 'color': ''},
    };
    final blocks = [for (final b in note['blocks'] as List) NtBlock.fromJson(b as Json)];
    await t.pumpWidget(p1.app(NtPdfPage(ctx: ctxX(api), nid: 'n1', title: 'Team meeting — new shop', blocks: blocks, files: [for (final f in note['files'] as List) f as Json], data: data), api: api));
    await settle(t);
    await shot(t, 'ntx-pdf');
    final st = t.state<NtPdfPageState>(find.byType(NtPdfPage));
    final pages = await t.runAsync(() => st.pages());
    expect(pages, isNotNull);
    expect(pages!.isNotEmpty, true);
    final bytes = await t.runAsync(() => ntPdf(pages, title: 'Team meeting'));
    expect(latin1.decode(bytes!.sublist(0, 8)), '%PDF-1.4');
    // the first page as a picture
    final png = await t.runAsync(() async => (await pages.first.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
    await t.binding.setSurfaceSize(const Size(600, 848));
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, home: Scaffold(body: Image.memory(png!, width: 595, height: 842, fit: BoxFit.fill))));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await settle(t);
    await shot(t, 'ntx-pdf-page1');
  });

  test('xlsx + csv helpers', () {
    final x = ntXlsx('Sign-ups', [
      ['Name', 'Phone', 'Count'],
      ['សុខា', '=SUM(A1)', 3],
    ]);
    expect(x.sublist(0, 2), [0x50, 0x4B]); // a zip
    expect(utf8.decode(x, allowMalformed: true).contains('inlineStr'), true);
    expect(ntFileName('Team — meeting/plan', 'csv'), 'Team - meetingplan.csv');
  });
}

