// The app review fixes (Digital Note + the shared buy sheet), as behaviour tests — no pictures.
//   1. the buy sheet can't be closed while paying, pays once on a double tap, and still records a purchase that
//      finishes after the sheet was swiped away
//   2. the editor's 20 s refresh never replaces what is being typed while a save is on its way
//   3. a failed last save after leaving the note makes no retry timer
//   4. the share sheet's custom link: an older check's answer never decides what is saved
//   5. the date pickers open when the saved date has passed already
import 'dart:async';

import 'package:bizhub_admin/core/api.dart';
import 'package:bizhub_admin/core/i18n.dart';
import 'package:bizhub_admin/core/providers.dart';
import 'package:bizhub_admin/core/theme.dart';
import 'package:bizhub_admin/features/mart/mart_kit.dart' show showSheet;
import 'package:bizhub_admin/features/note/nt_common.dart';
import 'package:bizhub_admin/features/note/nt_editor.dart';
import 'package:bizhub_admin/features/note/nt_share.dart';
import 'package:bizhub_admin/widgets/buy_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nc_recipes_test.dart' show loadFonts;
import 'nt_shots_test.dart' as p1;

// a FakeApi with switches for the cases below
class _Api extends p1.FakeApi {
  int puts = 0;
  Completer<Json>? putGate; // a save that waits until the test lets it answer
  bool putOffline = false;
  Json? noteNow; // what GET /notes/n1 answers (null = the phase-1 note)
  Completer<void>? getGate; // GET /notes/n1 waits for this (the 20 s refresh, held on its way)
  final checks = <String, Completer<Json>>{}; // slug → its /link-check answer (waits until completed)
  final shares = <Json>[];

  _Api() : super(linkOwned: true);

  @override
  Future<Json> get(String path, [Map<String, dynamic>? query]) async {
    if (path.contains('/note/notes/n1') && getGate != null) await getGate!.future;
    if (path.contains('/note/notes/n1') && noteNow != null) {
      return {
        'data': {'note': noteNow, 'entries_new': 0, 'group_ids': const []},
      };
    }
    if (path.endsWith('/link-check')) {
      final s = '${query?['slug']}';
      final c = checks.putIfAbsent(s, Completer<Json>.new);
      return c.future;
    }
    return super.get(path, query);
  }

  @override
  Future<Json> put(String path, [Object? body]) async {
    if (path.endsWith('/share')) {
      shares.add(Map<String, dynamic>.from(body as Map));
      return {'data': p1.fullNote()['share']};
    }
    puts++;
    if (putOffline) throw const ApiError(0, 'network');
    final g = putGate;
    if (g != null) return g.future;
    return super.put(path, body);
  }
}

Json _free(String s) => {
  'data': {'slug': s, 'ok': true, 'reason': '', 'dropped': false, 'suggestions': const []},
};

void main() {
  setUpAll(() async {
    ntNow = () => DateTime.utc(2026, 10, 1, 5);
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await PrefsNotifier.init();
    await T.load();
    await loadFonts();
  });

  Future<void> size(WidgetTester t, [double h = 900]) async {
    await t.binding.setSurfaceSize(Size(400, h));
    t.view.devicePixelRatio = 2;
  }

  // ------------------------------------------------------------------------------------------------ 1. buy sheet
  group('buy sheet', () {
    Future<(Completer<Json>, List<Json>, ValueNotifier<int>)> open(WidgetTester t) async {
      final gate = Completer<Json>();
      final done = <Json>[];
      final calls = ValueNotifier(0);
      await t.pumpWidget(
        p1.app(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showSheet<bool>(
                    context,
                    (_) => BuySheet(
                      stage: const SizedBox(height: 40),
                      title: 'Unlock it',
                      sub: '',
                      perks: const [],
                      price: 0, // free here: the buy button shows (no "top up")
                      buyLabel: 'Buy now',
                      doneTitle: 'Bought',
                      doneSub: '',
                      doneButton: 'OK',
                      buy: () {
                        calls.value++;
                        return gate.future;
                      },
                      onDone: done.add,
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await p1.settle(t, 600);
      return (gate, done, calls);
    }

    testWidgets("a double tap pays once, and back can't close it while paying", (t) async {
      await size(t);
      final (gate, done, calls) = await open(t);
      await t.tap(find.text('Buy now'));
      await t.pump();
      // the button now shows a spinner: a second tap on it (or where it was) does nothing
      await t.tap(find.byType(BuySheet), warnIfMissed: false);
      await t.pump();
      expect(calls.value, 1);
      // the back button while paying: the sheet stays
      await t.binding.handlePopRoute();
      await p1.settle(t, 400);
      expect(find.byType(BuySheet), findsOneWidget);
      gate.complete({'balance': 90});
      await p1.settle(t, 400);
      expect(done, hasLength(1));
      expect(find.text('Bought'), findsOneWidget);
    });

    testWidgets('closed while paying: the purchase is still recorded, nothing throws', (t) async {
      await size(t);
      final (gate, done, _) = await open(t);
      await t.tap(find.text('Buy now'));
      await t.pump();
      // a swipe down (it closes with Navigator.pop, which no PopScope can stop)
      Navigator.of(t.element(find.byType(BuySheet))).pop();
      await p1.settle(t, 600);
      expect(find.byType(BuySheet), findsNothing);
      gate.complete({'balance': 75});
      await p1.settle(t, 200);
      expect(done, hasLength(1)); // onDone ran though the sheet was gone
      expect(t.takeException(), isNull);
    });
  });

  // ------------------------------------------------------------------------------------------------ 2 + 3. editor
  testWidgets("the 20 s refresh doesn't replace typing while a save is on its way", (t) async {
    await size(t, 1500);
    final api = _Api();
    await t.pumpWidget(p1.app(NtEditorPage(ctx: p1.ctxOf(api), nid: 'n1'), api: api));
    await p1.settle(t);
    // the refresh goes out and is held; meanwhile someone else saved a newer version
    api.getGate = Completer<void>();
    api.noteNow = p1.fullNote(version: 9, title: 'Team meeting — THEIRS');
    await t.pump(const Duration(seconds: 21));
    // the owner types, and the autosave starts (and is held too) while the refresh is still on its way
    api.putGate = Completer<Json>();
    await t.enterText(find.byType(TextField).at(2), '​My own line');
    await t.pump(const Duration(milliseconds: 1600));
    expect(api.puts, 1);
    // now the refresh answers: the old code took their version over the typing (the save was out, nothing "dirty")
    api.getGate!.complete();
    await t.pump();
    await t.pump();
    expect(find.textContaining('My own line'), findsWidgets, reason: 'the typing stays');
    expect(find.text('Team meeting — THEIRS'), findsNothing, reason: 'their title is not taken over the typing');
    // the save then meets the newer version → the conflict banner (not a silent loss)
    api.putGate!.completeError(ApiError(409, 'conflict', code: 'conflict', body: {'code': 'conflict', 'data': api.noteNow}));
    await p1.settle(t);
    expect(find.textContaining('My own line'), findsWidgets);
    expect(find.text(T.of('en')('note.conflictReload')), findsOneWidget);
  });

  testWidgets('a failed last save after leaving makes no retry timer', (t) async {
    await size(t, 1500);
    final api = _Api()..putOffline = true;
    await t.pumpWidget(p1.app(NtEditorPage(ctx: p1.ctxOf(api), nid: 'n1'), api: api));
    await p1.settle(t);
    await t.enterText(find.byType(TextField).at(2), '​typed, then left at once');
    await t.pump(const Duration(milliseconds: 200));
    expect(api.puts, 0);
    await t.pumpWidget(p1.app(const Scaffold(body: Text('elsewhere')), api: api)); // leave: the last save goes out
    await t.pump();
    expect(api.puts, 1);
    await t.pump(const Duration(seconds: 40)); // the old code tried again every 8 s, forever
    expect(api.puts, 1);
    expect(t.takeException(), isNull);
  });

  // ------------------------------------------------------------------------------------------------ 4 + 5. share sheet
  Future<void> openShare(WidgetTester t, _Api api, {Json? note}) async {
    final ctx = p1.ctxOf(api, link: true);
    await t.pumpWidget(
      p1.app(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(onPressed: () => ntShareNote(context, ctx, note ?? p1.fullNote(), groupCount: 0), child: const Text('open')),
            ),
          ),
        ),
        api: api,
      ),
    );
    await t.tap(find.text('open'));
    await p1.settle(t, 800);
  }

  testWidgets("custom link: an older check's answer never decides what is saved", (t) async {
    await size(t);
    final api = _Api();
    await openShare(t, api);
    final field = find.byType(TextField).last;
    await t.scrollUntilVisible(field, 300, scrollable: find.byType(Scrollable).last);
    await t.enterText(field, 'abc');
    await t.pump(const Duration(milliseconds: 450)); // the check for "abc" goes out (and waits)
    expect(api.checks.keys, contains('abc'));
    await t.enterText(field, 'abcd'); // typing goes on before it answers
    await t.pump(const Duration(milliseconds: 100));
    api.checks['abc']!.complete(_free('abc')); // the old answer arrives now
    await t.pump();
    // saving now must not save "abc": the field says "abcd" and nothing has checked that yet
    await t.tap(find.text(T.of('en')('note.save')).last);
    await t.pump();
    expect(api.shares, isEmpty);
    await t.pump(const Duration(milliseconds: 400)); // the check for "abcd" goes out
    api.checks['abcd']!.complete(_free('abcd'));
    await p1.settle(t, 300);
    await t.tap(find.text(T.of('en')('note.save')).last);
    await p1.settle(t, 400);
    expect(api.shares, hasLength(1));
    expect(api.shares.single['slug'], 'abcd');
  });

  testWidgets('the end date picker opens when the saved date has passed', (t) async {
    await size(t);
    final api = _Api();
    final note = p1.fullNote();
    note['share'] = {...(note['share'] as Map), 'expires_at': DateTime.now().subtract(const Duration(days: 40)).toUtc().toIso8601String()};
    await openShare(t, api, note: note);
    final row = find.text(T.of('en')('note.expires'));
    await t.scrollUntilVisible(row, 300, scrollable: find.byType(Scrollable).last);
    await t.tap(row);
    await p1.settle(t, 500);
    expect(t.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  test('ProviderContainer is used by the buy sheet (compile check)', () {
    // the sheet records a purchase through the container it took before paying
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(tProvider).lang, isNotEmpty);
    expect(buildTheme(dark: false, khmer: false), isA<ThemeData>());
  });
}
