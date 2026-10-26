import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_kit.dart' show showSheet;
import 'nt_blocks.dart';
import 'nt_common.dart';
import 'nt_editor.dart';
import 'nt_export.dart';
import 'nt_extras_text.dart';
import 'nt_form.dart';
import 'nt_share.dart';
import 'nt_voice.dart';

// The tabs of a note (the web's NoteEditor tabs + NoteV4.jsx): Replies (or the sign-up rows as a table, CSV / Excel),
// Confirmed ("I've read it"), Seen by + views per day, Files, History.

String _who(NtCtx ctx, Json e) => e['by_owner'] == true ? ctx.m('ownerTag') : (str(e['name']).isEmpty ? ctx.m('guest') : str(e['name']));

// ================================================================ Replies / sign-ups
class NtEntriesTab extends StatefulWidget {
  final NtEditorApi ed;
  const NtEntriesTab({super.key, required this.ed});
  @override
  State<NtEntriesTab> createState() => _NtEntriesTabState();
}

class _NtEntriesTabState extends State<NtEntriesTab> {
  List<Json>? _rows;
  int _page = 1, _pages = 1, _total = 0;
  bool _more = false, _sending = false, _exporting = false;
  String _err = '';
  final _reply = TextEditingController();

  NtEditorApi get ed => widget.ed;
  NtCtx get ctx => ed.ctx;
  bool get _collect => obj(ed.note['share'])['level'] == 'collect';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    try {
      if (more) setState(() => _more = true);
      final p = more ? _page + 1 : 1;
      final r = await ctx.a.entries(ed.nid, page: p);
      if (!mounted) return;
      setState(() {
        final list = objs(r['data']);
        _rows = more ? [...?_rows, ...list] : list;
        _page = p;
        _pages = n(r['pages']).toInt().clamp(1, 9999);
        _total = n(r['total']).toInt();
        _err = '';
      });
    } catch (e) {
      if (mounted) setState(() => _err = ctx.errText(e));
    } finally {
      if (mounted) setState(() => _more = false);
    }
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final r = await ctx.run(() => ctx.a.reply(ed.nid, text));
    if (!mounted) return;
    setState(() => _sending = false);
    if (r == null) return;
    _reply.clear();
    setState(() => _rows = [obj(r['data']), ...?_rows]);
  }

  Future<void> _hide(Json e) async {
    final r = await ctx.run(() => ctx.a.entryHide(str(e['_id']), e['hidden'] != true));
    if (r != null && mounted) setState(() => _rows = [for (final x in _rows!) str(x['_id']) == str(e['_id']) ? obj(r['data']) : x]);
  }

  Future<void> _delete(Json e) async {
    if (!await ntConfirm(context, ctx, ctx.m('entryDeleteAsk'), ctx.m('entryDeleteSub'))) return;
    final r = await ctx.run(() => ctx.a.entryDelete(str(e['_id'])));
    if (r != null && mounted) setState(() => _rows = _rows!.where((x) => str(x['_id']) != str(e['_id'])).toList());
  }

  Future<void> _csv() async {
    setState(() => _exporting = true);
    try {
      final text = await ctx.a.exportCsv(ed.nid);
      await ntShareCsv(text, ntFileName(str(ed.note['title']), 'csv'));
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _excel() async {
    if (!ctx.form) {
      await ctx.askBuy('note_form');
      return;
    }
    setState(() => _exporting = true);
    try {
      final d = obj((await ctx.a.exportRows(ed.nid))['data']);
      final cols = [for (final c in (d['columns'] as List? ?? const [])) '$c'];
      final rows = [for (final r in (d['rows'] as List? ?? const [])) (r as List).toList()];
      final bytes = ntXlsx(str(ed.note['title']).isEmpty ? ctx.m('collectTitle') : str(ed.note['title']), [cols, ...rows]);
      await ntShareFile(bytes, ntFileName(str(ed.note['title']), 'xlsx'), 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_rows == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _err.isNotEmpty ? LoadError(text: _err, retry: ctx.m('retry'), onRetry: _load) : const SkelList(rows: 4),
      );
    }
    final rows = _rows!;
    final head = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_collect ? ctx.m('collectTitle') : ctx.m('entriesTitle'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              if (_total > 0) Text(_collect ? ctx.m('people', {'n': fmt(_total)}) : fmt(_total), style: TextStyle(color: c.muted, fontSize: 12.5)),
            ],
          ),
        ),
        if (rows.isNotEmpty) ...[
          Btn(ctx.m('csv'), small: true, kind: BtnKind.ghost, icon: LucideIcons.download, onTap: _exporting ? null : _csv),
          if (_collect) ...[
            const SizedBox(width: 6),
            Btn(ctx.m('excel'), small: true, kind: ctx.form ? BtnKind.primary : BtnKind.ghost, icon: ctx.form ? LucideIcons.sheet : LucideIcons.lock, busy: _exporting, onTap: _excel),
          ],
        ],
      ],
    );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          head,
          const SizedBox(height: 12),
          if (!_collect && !ed.readOnly) _composer(),
          if (rows.isEmpty)
            Panel(
              child: NtEmpty(icon: _collect ? LucideIcons.clipboardList : LucideIcons.messageSquareText, title: _collect ? ctx.m('noResponses') : ctx.m('noEntries')),
            )
          else if (_collect)
            NtRowsTable(ctx: ctx, note: ed.note, rows: rows)
          else
            for (final e in rows) _entry(e),
          if (_page < _pages)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(child: Btn(ctx.m('loadMore'), kind: BtnKind.ghost, small: true, busy: _more, onTap: () => _load(more: true))),
            ),
        ],
      ),
    );
  }

  Widget _composer() {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(18), boxShadow: c.cardShadow),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _reply,
              minLines: 1,
              maxLines: 5,
              maxLength: 3000,
              decoration: InputDecoration(border: InputBorder.none, counterText: '', hintText: ctx.m('replyPh')),
            ),
          ),
          IconButton.filled(tooltip: ctx.m('send'), onPressed: _sending ? null : _send, icon: _sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(LucideIcons.send, size: 18)),
        ],
      ),
    );
  }

  Widget _entry(Json e) {
    final c = context.c;
    final owner = e['by_owner'] == true;
    final hidden = e['hidden'] == true;
    final files = objs(e['files']);
    final eid = str(e['_id']);
    return Opacity(
      opacity: hidden ? .55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        decoration: BoxDecoration(
          color: owner ? c.active : c.card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: owner ? null : c.cardShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(name: _who(ctx, e), size: 36, brand: owner),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(_who(ctx, e), style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(ntAgo(e['created_date'], ctx), style: TextStyle(color: c.muted, fontSize: 12)),
                      if (e['new'] == true) Chip2(ctx.m('newTag'), tone: Tone.brand),
                      if (hidden) Chip2(ctx.m('hiddenTag')),
                    ],
                  ),
                  if (str(e['text']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: SelectableText(str(e['text']), style: const TextStyle(height: 1.5))),
                  for (final f in files)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: f['voice'] == true || ntFineKind(f) == 'audio'
                          ? NtAudioPlayer(ctx: ctx, file: f, eid: eid)
                          : f['sign'] == true
                          ? _signImage(f)
                          : NtFileChip(ctx: ctx, file: f, eid: eid),
                    ),
                ],
              ),
            ),
            // hide / delete work after the plan ended too (the API allows it)
            PopupMenuButton<String>(
                icon: Icon(LucideIcons.ellipsisVertical, size: 18, color: c.muted),
                onSelected: (k) => k == 'hide' ? _hide(e) : _delete(e),
                itemBuilder: (_) => [
                  if (!owner) PopupMenuItem(value: 'hide', child: Text(hidden ? ctx.m('unhide') : ctx.m('hide'))),
                  PopupMenuItem(value: 'delete', child: Text(ctx.m('delete'), style: TextStyle(color: c.danger))),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _signImage(Json f) => Container(
    constraints: const BoxConstraints(maxWidth: 280, maxHeight: 150),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.c.line)),
    clipBehavior: Clip.antiAlias,
    child: str(f['url']).isEmpty ? const Padding(padding: EdgeInsets.all(12), child: Icon(LucideIcons.signature)) : Image(image: netImage(str(f['url'])), fit: BoxFit.contain, errorBuilder: (_, _, _) => const Padding(padding: EdgeInsets.all(12), child: Icon(LucideIcons.signature))),
  );
}

// a field value as text (the table, like the web's fieldText)
String ntFieldText(NtCtx ctx, Json f, Object? v) {
  if (v == null || '$v'.isEmpty) return '';
  if (f['type'] == 'checkbox') return v == true || v == 'true' ? ctx.m('yes') : ctx.m('no');
  return '$v';
}

// the sign-up rows: a table that scrolls sideways, one column per field; tap a column to sort; search
class NtRowsTable extends StatefulWidget {
  final NtCtx ctx;
  final Json note;
  final List<Json> rows;
  const NtRowsTable({super.key, required this.ctx, required this.note, required this.rows});
  @override
  State<NtRowsTable> createState() => _NtRowsTableState();
}

class _NtRowsTableState extends State<NtRowsTable> {
  String _q = '';
  String _by = 'time';
  int _dir = -1;
  NtCtx get ctx => widget.ctx;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fields = objs(obj(widget.note['form'])['fields']);
    final cols = <(String, String, Json?)>[
      ('name', ctx.m('ackColName'), null),
      for (final f in fields) (str(f['id']), str(f['label']), f),
      ('text', ctx.m('fxText'), null),
      ('files', ctx.m('fxFiles'), null),
      ('time', ctx.m('fxTime'), null),
    ];
    Object valOf(Json r, (String, String, Json?) col) => switch (col.$1) {
      'name' => str(r['name']),
      'text' => str(r['text']),
      'files' => objs(r['files']).length,
      'time' => str(r['created_date']),
      _ => ntFieldText(ctx, col.$3!, obj(r['fields'])[col.$1]),
    };
    final needle = _q.trim().toLowerCase();
    final list = widget.rows.where((r) => needle.isEmpty || cols.any((col) => '${valOf(r, col)}'.toLowerCase().contains(needle))).toList();
    final sortCol = cols.firstWhere((x) => x.$1 == _by, orElse: () => cols.last);
    final numeric = sortCol.$1 == 'files' || sortCol.$3?['type'] == 'number';
    list.sort((a, b) {
      final x = valOf(a, sortCol), y = valOf(b, sortCol);
      if (numeric) return ((num.tryParse('$x') ?? 0).compareTo(num.tryParse('$y') ?? 0)) * _dir;
      return '$x'.toLowerCase().compareTo('$y'.toLowerCase()) * _dir;
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(hintText: ctx.m('fxSearch'), prefixIcon: const Icon(LucideIcons.search, size: 18), isDense: true),
        ),
        const SizedBox(height: 6),
        Text(ntE(ctx, 'tapToSort'), style: TextStyle(color: c.muted, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16), boxShadow: c.cardShadow),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 44,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 72,
              columnSpacing: 22,
              headingRowColor: WidgetStatePropertyAll(c.bg2),
              sortColumnIndex: cols.indexWhere((x) => x.$1 == _by),
              sortAscending: _dir > 0,
              columns: [
                for (final col in cols)
                  DataColumn(
                    numeric: col.$1 == 'files' || col.$3?['type'] == 'number',
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (col.$3 != null) ...[Icon(ntFieldIcon(str(col.$3!['type'])), size: 13, color: c.muted), const SizedBox(width: 4)],
                        Text(col.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                    onSort: (_, _) => setState(() {
                      _dir = _by == col.$1 ? -_dir : (col.$1 == 'time' ? -1 : 1);
                      _by = col.$1;
                    }),
                  ),
              ],
              rows: [
                for (final r in list)
                  DataRow(
                    color: r['hidden'] == true ? WidgetStatePropertyAll(c.bg2) : null,
                    cells: [
                      for (final col in cols)
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: Text(
                              col.$1 == 'time'
                                  ? ntAgo(r['created_date'], ctx)
                                  : col.$1 == 'files'
                                  ? (objs(r['files']).isEmpty ? '' : '${objs(r['files']).length}')
                                  : '${valOf(r, col)}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: col.$1 == 'name' ? FontWeight.w700 : FontWeight.w400, color: col.$1 == 'time' ? c.muted : c.ink),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (list.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Center(child: Muted(ctx.m('fxNoMatch')))),
      ],
    );
  }
}

// ================================================================ Confirmed ("I've read it")
class NtAcksTab extends StatefulWidget {
  final NtEditorApi ed;
  const NtAcksTab({super.key, required this.ed});
  @override
  State<NtAcksTab> createState() => _NtAcksTabState();
}

class _NtAcksTabState extends State<NtAcksTab> {
  Json? _d;
  String _err = '';
  bool _exporting = false;
  NtEditorApi get ed => widget.ed;
  NtCtx get ctx => ed.ctx;
  bool get _on => obj(ed.note['share'])['ack'] == true;

  @override
  void initState() {
    super.initState();
    if (_on) _load();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.a.acks(ed.nid);
      if (mounted) setState(() => _d = r);
    } catch (e) {
      if (mounted) setState(() => _err = ctx.errText(e));
    }
  }

  Future<void> _csv() async {
    setState(() => _exporting = true);
    try {
      await ntShareCsv(await ctx.a.acksCsv(ed.nid), ntFileName('${str(ed.note['title'])} - ${ctx.m('ackTitle')}', 'csv'));
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _turnOn() async {
    final fresh = await ntShareNote(context, ctx, ed.note);
    if (fresh != null) ed.setNote(fresh);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (!_on) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Panel(
            child: NtEmpty(
              icon: LucideIcons.circleCheckBig,
              title: ctx.m('ackTitle'),
              sub: ctx.m('ackOffSub'),
              action: ctx.ack
                  ? Btn(ctx.m('ackTurnOn'), icon: LucideIcons.share2, onTap: _turnOn)
                  : NtGoldBtn(ctx.m('ackUnlock', {'coins': fmt(ctx.price('note_ack'))}), onTap: () => ctx.askBuy('note_ack')),
            ),
          ),
        ],
      );
    }
    final d = _d;
    if (d == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _err.isNotEmpty ? LoadError(text: _err, retry: ctx.m('retry'), onRetry: _load) : const SkelList(rows: 4),
      );
    }
    final rows = objs(d['data']);
    final not = objs(d['not_confirmed']);
    final counts = obj(d['counts']);
    final done = n(counts['confirmed'] ?? rows.length).toInt();
    final wait = n(counts['opened_not_confirmed'] ?? not.length).toInt();
    final pct = done + wait == 0 ? 0.0 : done / (done + wait);
    Widget person(Json r, {required bool ok}) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Avatar(name: str(r['name']).isEmpty ? ctx.m('guest') : str(r['name']), size: 38),
      title: Text(str(r['name']).isEmpty ? ctx.m('guest') : str(r['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        ok ? '${ntTime(r['at'], ctx.lang)}${r['by_group'] == true ? ' · ${ctx.m('ackByGroup')}' : ''}' : '${ctx.m('ackOpened')} ${ntAgo(r['last_at'], ctx)}',
        style: TextStyle(color: c.muted, fontSize: 12.5),
      ),
      trailing: ok ? Chip2(ctx.m('ackYes'), tone: Tone.good, icon: LucideIcons.checkCheck) : Chip2(ctx.m('ackNo'), tone: Tone.warn),
    );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ctx.m('ackTitle'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Text(ctx.m('ackCount', {'n': fmt(done), 'k': fmt(wait)}), style: TextStyle(color: c.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              if (rows.isNotEmpty || not.isNotEmpty) Btn(ctx.m('csv'), small: true, kind: BtnKind.ghost, icon: LucideIcons.download, busy: _exporting, onTap: _csv),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: pct, minHeight: 10, backgroundColor: c.warnBg, color: c.good),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty && not.isEmpty) Panel(child: NtEmpty(icon: LucideIcons.users, title: ctx.m('ackNone'))),
          if (rows.isNotEmpty)
            Panel(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ctx.m('ackDone'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  for (final r in rows) person(r, ok: true),
                ],
              ),
            ),
          if (not.isNotEmpty) ...[
            const SizedBox(height: 12),
            Panel(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ctx.m('ackNotYet'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  for (final r in not) person(r, ok: false),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ================================================================ Seen by + views per day
class NtSeenTab extends StatefulWidget {
  final NtEditorApi ed;
  const NtSeenTab({super.key, required this.ed});
  @override
  State<NtSeenTab> createState() => _NtSeenTabState();
}

class _NtSeenTabState extends State<NtSeenTab> {
  List<Json>? _rows;
  String _err = '';
  NtEditorApi get ed => widget.ed;
  NtCtx get ctx => ed.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.a.seen(ed.nid);
      if (mounted) setState(() => _rows = objs(r['data']));
    } catch (e) {
      if (mounted) setState(() => _err = ctx.errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = _rows;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          NtStatsChart(ctx: ctx, load: () => ctx.a.stats(ed.nid)),
          const SizedBox(height: 14),
          Panel(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ctx.m('seenTitle'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 2),
                Muted(ctx.m('seenSub')),
                const SizedBox(height: 6),
                if (rows == null)
                  (_err.isNotEmpty ? LoadError(text: _err, retry: ctx.m('retry'), onRetry: _load) : const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())))
                else if (rows.isEmpty)
                  NtEmpty(icon: LucideIcons.eye, title: ctx.m('noSeen'))
                else
                  for (final r in rows)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Avatar(name: str(r['name']).isEmpty ? ctx.m('guest') : str(r['name']), size: 38),
                      title: Text(str(r['name']).isEmpty ? ctx.m('guest') : str(r['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${ctx.m('firstSeen')}: ${ntTime(r['first_at'], ctx.lang)}', style: TextStyle(color: c.muted, fontSize: 12)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(ntAgo(r['last_at'], ctx), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          Text(ctx.m('times', {'n': fmt(r['count'])}), style: TextStyle(color: c.muted, fontSize: 12)),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// views per day for 30 days (a note or a group): totals, best day, bars + people dots; tap a bar for its numbers
class NtStatsChart extends StatefulWidget {
  final NtCtx ctx;
  final Future<Json> Function() load;
  final String? title;
  const NtStatsChart({super.key, required this.ctx, required this.load, this.title});
  @override
  State<NtStatsChart> createState() => _NtStatsChartState();
}

class _NtStatsChartState extends State<NtStatsChart> {
  List<Json>? _days;
  Json _total = const {}, _best = const {};
  int _tip = -1;
  NtCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    widget
        .load()
        .then((r) {
          final d = obj(r['data']);
          if (mounted) {
            setState(() {
              _days = objs(d['days']);
              _total = obj(d['total']);
              _best = obj(d['best']);
            });
          }
        })
        .catchError((_) {
          if (mounted) setState(() => _days = const []);
        });
  }

  String _label(String day) {
    final d = DateTime.tryParse('${day}T05:00:00Z');
    return d == null ? day : ntDate(d.toIso8601String(), ctx.lang).replaceFirst(RegExp(r' \d{4}$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final days = _days;
    Widget num(String v, String l) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12)),
        ],
      ),
    );
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.chartColumn, size: 17, color: c.brand),
              const SizedBox(width: 8),
              Text(widget.title ?? ctx.m('statsTitle'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 2),
          Muted(ctx.m('statsSub')),
          const SizedBox(height: 12),
          if (days == null)
            const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
          else ...[
            Row(
              children: [
                num(fmt(_total['views'] ?? 0), ctx.m('statsViews')),
                num(fmt(_total['people'] ?? 0), ctx.m('statsPeople')),
                num(n(_best['views']) > 0 ? _label(str(_best['day'])) : '—', n(_best['views']) > 0 ? ctx.m('statsBest', {'n': fmt(_best['views'])}) : ctx.m('statsBestNone')),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 120,
              child: LayoutBuilder(
                builder: (_, box) => GestureDetector(
                  onTapDown: (d) {
                    if (days.isEmpty) return;
                    setState(() => _tip = (d.localPosition.dx / box.maxWidth * days.length).floor().clamp(0, days.length - 1));
                  },
                  child: CustomPaint(painter: _BarsPainter(days, _tip, c.brand, c.good, c.bg2), child: const SizedBox.expand()),
                ),
              ),
            ),
            const SizedBox(height: 6),
            if (_tip >= 0 && _tip < days.length)
              Text(
                '${_label(str(days[_tip]['day']))}: ${ctx.m('statsTip', {'v': fmt(days[_tip]['views']), 'p': fmt(days[_tip]['people'])})}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              )
            else if (days.isNotEmpty)
              Row(
                children: [
                  Text(_label(str(days.first['day'])), style: TextStyle(color: c.muted, fontSize: 11.5)),
                  const Spacer(),
                  _Legend(color: c.brand, label: ctx.m('statsViews')),
                  const SizedBox(width: 10),
                  _Legend(color: c.good, label: ctx.m('statsPeople')),
                  const Spacer(),
                  Text(_label(str(days.last['day'])), style: TextStyle(color: c.muted, fontSize: 11.5)),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: context.c.muted, fontSize: 11.5)),
    ],
  );
}

class _BarsPainter extends CustomPainter {
  final List<Json> days;
  final int tip;
  final Color bar, dot, track;
  _BarsPainter(this.days, this.tip, this.bar, this.dot, this.track);
  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    var max = 1;
    for (final d in days) {
      if (n(d['views']) > max) max = n(d['views']).toInt();
    }
    final w = size.width / days.length;
    final p = Paint();
    for (var i = 0; i < days.length; i++) {
      final v = n(days[i]['views']).toDouble();
      final pe = n(days[i]['people']).toDouble();
      final x = i * w + w * .15;
      final bw = w * .7;
      final h = v == 0 ? 2.0 : (v / max * (size.height - 6)).clamp(5.0, size.height);
      p.color = i == tip ? bar : (tip >= 0 ? bar.withValues(alpha: .45) : bar.withValues(alpha: v == 0 ? .25 : .85));
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - h, bw, h), const Radius.circular(3)), p);
      if (pe > 0) {
        p.color = dot;
        canvas.drawCircle(Offset(x + bw / 2, size.height - (pe / max * (size.height - 6)).clamp(4.0, size.height)), (bw * .3).clamp(1.5, 3.5), p);
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.tip != tip || old.days != days;
}

// ================================================================ Files
class NtFilesTab extends StatefulWidget {
  final NtEditorApi ed;
  const NtFilesTab({super.key, required this.ed});
  @override
  State<NtFilesTab> createState() => _NtFilesTabState();
}

class _NtFilesTabState extends State<NtFilesTab> {
  NtEditorApi get ed => widget.ed;
  NtCtx get ctx => ed.ctx;

  Future<void> _delete(Json f) async {
    if (!await ntConfirm(context, ctx, ctx.m('fileDeleteAsk'), ctx.m('fileDeleteSub'))) return;
    final r = await ctx.run(() => ctx.a.deleteFile(ed.nid, str(f['_id'])));
    if (r == null) return;
    ed.fileRemoved(obj(r['data']), str(f['_id'])); // the blocks that showed it are gone too (no false "changed by someone")
    ctx.reload();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final files = ed.files;
    var used = 0.0;
    for (final f in files) {
      used += n(f['size']);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        Text(ctx.m('filesTitle'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        Muted(ctx.m('filesSub')),
        const SizedBox(height: 4),
        if (files.isNotEmpty) Text('${fmt(files.length)} · ${ntBytes(used)}', style: TextStyle(color: context.c.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (files.isEmpty)
          Panel(child: NtEmpty(icon: LucideIcons.paperclip, title: ctx.m('noFiles')))
        else
          for (final f in files)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NtFileChip(
                ctx: ctx,
                file: f,
                nid: ed.nid,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(tooltip: ctx.m('download'), onPressed: () => ntOpenFile(ctx, f, nid: ed.nid, inline: false), icon: Icon(LucideIcons.download, size: 18, color: context.c.muted)),
                    // deleting works after the plan ended too (the API allows it)
                    IconButton(tooltip: ctx.m('delete'), onPressed: () => _delete(f), icon: Icon(LucideIcons.trash2, size: 18, color: context.c.danger)),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

// ================================================================ History
class NtHistoryTab extends StatefulWidget {
  final NtEditorApi ed;
  const NtHistoryTab({super.key, required this.ed});
  @override
  State<NtHistoryTab> createState() => _NtHistoryTabState();
}

class _NtHistoryTabState extends State<NtHistoryTab> {
  List<Json>? _rows;
  String _err = '';
  NtEditorApi get ed => widget.ed;
  NtCtx get ctx => ed.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.a.history(ed.nid);
      if (mounted) setState(() => _rows = objs(r['data']));
    } catch (e) {
      if (mounted) setState(() => _err = ctx.errText(e));
    }
  }

  Future<void> _open(Json r) async {
    final restore = await showSheet<bool>(context, (_) => _RevSheet(ctx: ctx, nid: ed.nid, rev: r, readOnly: ed.readOnly));
    if (restore != true || !mounted) return;
    if (!await ntConfirm(context, ctx, ctx.m('restoreAsk'), ctx.m('restoreSub'), yes: ctx.m('restore'), danger: false)) return;
    final res = await ctx.run(() => ctx.a.historyRestore(ed.nid, str(r['_id'])), ctx.m('restoredVersion'));
    if (res == null) return;
    await ed.refresh();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = _rows;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Text(ctx.m('historyTitle'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          Muted(ctx.m('historySub')),
          const SizedBox(height: 12),
          if (rows == null)
            (_err.isNotEmpty ? LoadError(text: _err, retry: ctx.m('retry'), onRetry: _load) : const SkelList(rows: 4))
          else if (rows.isEmpty)
            Panel(child: NtEmpty(icon: LucideIcons.history, title: ctx.m('noHistory')))
          else
            Panel(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (final (i, r) in rows.indexed)
                    ListTile(
                      onTap: () => _open(r),
                      leading: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: i == 0 ? c.active : c.bg2, borderRadius: BorderRadius.circular(10)),
                        child: Text('v${fmt(r['version'])}', style: TextStyle(fontWeight: FontWeight.w800, color: i == 0 ? c.brandInk : c.ink)),
                      ),
                      title: Text(str(r['title']).isEmpty ? ctx.m('untitled') : str(r['title']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${ntTime(r['at'], ctx.lang)} · ${str(r['by']) == 'owner' ? ctx.m('byOwner') : str(r['by'])}', style: TextStyle(color: c.muted, fontSize: 12.5)),
                      trailing: Icon(i == 0 ? LucideIcons.check : LucideIcons.chevronRight, size: 18, color: c.muted),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RevSheet extends StatefulWidget {
  final NtCtx ctx;
  final String nid;
  final Json rev;
  final bool readOnly;
  const _RevSheet({required this.ctx, required this.nid, required this.rev, required this.readOnly});
  @override
  State<_RevSheet> createState() => _RevSheetState();
}

class _RevSheetState extends State<_RevSheet> {
  Json? _d;
  @override
  void initState() {
    super.initState();
    widget.ctx.a.historyOne(widget.nid, str(widget.rev['_id'])).then((r) {
      if (mounted) setState(() => _d = obj(r['data']));
    }).catchError((_) {
      if (mounted) setState(() => _d = const {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final d = _d;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ctx.m('version', {'n': fmt(widget.rev['version'])}), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      Text(ntTime(widget.rev['at'], ctx.lang), style: TextStyle(color: context.c.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: d == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    children: [
                      Text(str(d['title']).isEmpty ? ctx.m('untitled') : str(d['title']), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      NtReadBlocks(ctx: ctx, blocks: ntBlocksOf(d['blocks']), files: const [], nid: widget.nid),
                    ],
                  ),
          ),
          if (!widget.readOnly)
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + MediaQuery.paddingOf(context).bottom),
              child: Btn(ntE(ctx, 'restoreThis'), icon: LucideIcons.rotateCcw, expand: true, onTap: () => Navigator.pop(context, true)),
            ),
        ],
      ),
    );
  }
}
