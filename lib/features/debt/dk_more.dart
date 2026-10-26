import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../attendance/at_setup.dart' show TimeField;
import '../guesthouse/gh_common.dart' show ghPickPicture, GhCtx;
import '../mart/mart_common.dart' show GoldBtn, mGap, todayKH, fileForm;
import '../mart/mart_kit.dart' show numOf;
import '../restaurant/rest_common.dart' show Segmented, SwitchRow, gap14;
import 'dk_common.dart';
import 'dk_customers.dart' show EntryRow;

// History · Reminders + Telegram · Import / export · Settings · Add-ons — DebtMore.jsx

// ------------------------------------------------------------------------------------------------ HISTORY
class HistoryTab extends StatefulWidget {
  final DkCtx ctx;
  const HistoryTab({super.key, required this.ctx});
  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  DkCtx get ctx => widget.ctx;
  String _by = '';
  List<Json>? _rows;
  int _page = 1, _pages = 1;

  @override
  void initState() {
    super.initState();
    _load(1);
  }

  Future<void> _load(int p) async {
    try {
      final r = await ctx.api.get('${ctx.base}/history', {'by': _by, 'page': '$p'});
      if (!mounted) return;
      setState(() {
        _rows = p == 1 ? objs(r['data']) : [...?_rows, ...objs(r['data'])];
        _page = p;
        _pages = n(obj(r['pagination'])['totalPages']).toInt().clamp(1, 9999);
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        dkHead(context, LucideIcons.history, ctx.m('historyTitle'), ctx.m('historySub')),
        mGap,
        dkPanel(padding: const EdgeInsets.fromLTRB(12, 12, 12, 8), [
          Wrap(
            spacing: 6,
            children: [
              for (final (k, l) in [('', ctx.m('allLines')), ('void', ctx.m('voidLines'))])
                ChoiceChip(
                  label: Text(l),
                  selected: _by == k,
                  onSelected: (_) {
                    setState(() {
                      _by = k;
                      _rows = null;
                    });
                    _load(1);
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (rows == null)
            const SkelList(rows: 4)
          else if (rows.isEmpty)
            Padding(padding: const EdgeInsets.all(6), child: Muted(ctx.m('noLines')))
          else
            for (final e in rows)
              EntryRow(
                ctx: ctx,
                e: e,
                onName: () => ctx.go('customers', customer: str(e['customer_id'])),
              ),
          if (_page < _pages)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Btn(ctx.m('more'), kind: BtnKind.ghost, small: true, onTap: () => _load(_page + 1)),
            ),
        ]),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ REMINDERS + TELEGRAM
class RemindersTab extends StatefulWidget {
  final DkCtx ctx;
  const RemindersTab({super.key, required this.ctx});
  @override
  State<RemindersTab> createState() => _RemindersTabState();
}

class _RemindersTabState extends State<RemindersTab> {
  DkCtx get ctx => widget.ctx;
  late final Json _r0 = obj(ctx.book['remind']);
  late bool _on = _r0['on'] != false;
  late int _before = _r0['before'] == null ? 1 : n(_r0['before']).toInt();
  late int _every = _r0['every'] == null ? 7 : n(_r0['every']).toInt();
  late String _time = str(_r0['time']).isEmpty ? '09:00' : str(_r0['time']);
  late final _km = TextEditingController(text: str(_r0['text_km']));
  late final _en = TextEditingController(text: str(_r0['text_en']));
  late Json _tg = obj(ctx.data['telegram']);
  String _busy = '';
  bool _waiting = false;
  Timer? _poll;

  @override
  void dispose() {
    _km.dispose();
    _en.dispose();
    _poll?.cancel();
    super.dispose();
  }

  String get _sample {
    final words = _km.text.isEmpty ? 'សួស្តី {name} នេះជាការរំលឹកពី {shop}៖ ប្រាក់ជំពាក់ {amount} (ដល់ថ្ងៃ {due})។ សូមអរគុណ!' : _km.text;
    return words
        .replaceAll('{name}', 'សុខា')
        .replaceAll('{amount}', r'$25 + 10,000៛')
        .replaceAll('{due}', '20/10/2026')
        .replaceAll('{shop}', str(ctx.book['shop_name']))
        .replaceAll('{phone}', str(ctx.book['phone']))
        .replaceAll('{link}', '${Config.siteUrl}/d/…');
  }

  Future<void> _save() async {
    setState(() => _busy = 'save');
    final r = await ctx.run(
      () => ctx.api.put('${ctx.base}/settings', {
        'remind': {'on': _on, 'before': _before, 'every': _every, 'time': _time, 'text_km': _km.text, 'text_en': _en.text},
      }),
      ctx.m('saved'),
    );
    if (r != null) ctx.reload();
    if (mounted) setState(() => _busy = '');
  }

  Future<void> _link(bool group) async {
    setState(() => _busy = 'link');
    final r = await ctx.run(() => ctx.api.post('${ctx.base}/telegram/link'));
    if (mounted) setState(() => _busy = '');
    if (r == null) return;
    final url = str(obj(r['data'])[group ? 'group_url' : 'url']);
    if (url.isNotEmpty) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    setState(() => _waiting = true);
    var tries = 0;
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (t) async {
      tries++;
      try {
        final x = await ctx.api.get(ctx.base);
        final tg = obj(obj(x['data'])['telegram']);
        if (tg['connected'] == true || tries > 60) {
          t.cancel();
          if (mounted) {
            setState(() {
              _tg = tg;
              _waiting = false;
            });
          }
          ctx.reload();
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ro = ctx.readOnly;
    final how = dkPanel([Text(ctx.m('howItWorks'), style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 6), Muted(ctx.m('howItWorksSub'))]);
    if (!ctx.on('debt_remind')) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          dkHead(context, LucideIcons.bellRing, ctx.m('remindersTitle'), ctx.m('remindersSub')),
          mGap,
          DkLocked(ctx: ctx, addon: 'debt_remind'),
          mGap,
          how,
        ],
      );
    }
    Widget pick(String label, int value, List<(int, String)> options, ValueChanged<int> on) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          DropdownButton<int>(
            value: options.any((o) => o.$1 == value) ? value : options.first.$1,
            onChanged: ro ? null : (v) => v == null ? null : on(v),
            items: [for (final (v, l) in options) DropdownMenuItem(value: v, child: Text(l))],
          ),
        ],
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        dkHead(context, LucideIcons.bellRing, ctx.m('remindersTitle'), ctx.m('remindersSub')),
        mGap,
        dkPanel([
          SwitchRow(title: ctx.m('autoOn'), value: _on, onChanged: ro ? null : (v) => setState(() => _on = v)),
          const SizedBox(height: 6),
          pick(ctx.m('before'), _before, [
            (0, ctx.m('beforeOnDay')),
            for (final d in [1, 2, 3, 5, 7]) (d, nDays(ctx, d)),
          ], (v) => setState(() => _before = v)),
          pick(ctx.m('every'), _every, [
            (0, ctx.m('everyOnce')),
            for (final d in [1, 2, 3, 5, 7, 14, 30]) (d, ctx.m('everyDays', {'n': d})),
          ], (v) => setState(() => _every = v)),
          Row(
            children: [
              Expanded(child: Text(ctx.m('sendAt'))),
              SizedBox(
                width: 130,
                child: TimeField(value: _time, onChanged: (v) => ro ? null : setState(() => _time = v.isEmpty ? '09:00' : v)),
              ),
            ],
          ),
          gap14,
          Field(label: '${ctx.m('words')} · ខ្មែរ', controller: _km, maxLength: 500, maxLines: 3, enabled: !ro, onChanged: (_) => setState(() {})),
          gap14,
          Field(label: '${ctx.m('words')} · English', controller: _en, maxLength: 500, maxLines: 3, enabled: !ro),
          const SizedBox(height: 6),
          Muted(ctx.m('wordsHelp')),
          gap14,
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctx.m('preview'),
                  style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(_sample),
              ],
            ),
          ),
          gap14,
          Btn(ctx.m('save'), icon: LucideIcons.check, busy: _busy == 'save', onTap: ro || _busy.isNotEmpty ? null : _save),
        ]),
        mGap,
        dkPanel([
          Text(ctx.m('ownerChat'), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Muted(ctx.m('ownerChatSub')),
          const SizedBox(height: 10),
          if (_tg['configured'] != true)
            Muted(ctx.m('tgNotConfigured'))
          else if (_tg['connected'] == true) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Chip2(ctx.m('tgConnected', {'name': _tg['chat_name']}), icon: LucideIcons.check, tone: Tone.good),
            ),
            SwitchRow(
              title: ctx.m('daily'),
              value: _tg['daily'] == true,
              onChanged: ro
                  ? null
                  : (v) async {
                      final r = await ctx.run(() => ctx.api.put('${ctx.base}/telegram', {'daily': v}));
                      if (r != null && mounted) setState(() => _tg = obj(r['data']));
                    },
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Btn(
                  ctx.m('tgTest'),
                  icon: LucideIcons.send,
                  small: true,
                  busy: _busy == 'test',
                  onTap: _busy.isNotEmpty || ro
                      ? null
                      : () async {
                          setState(() => _busy = 'test');
                          await ctx.run(() => ctx.api.post('${ctx.base}/telegram/test'), ctx.m('tgSentOk'));
                          if (mounted) setState(() => _busy = '');
                        },
                ),
                Btn(
                  ctx.m('tgDisconnect'),
                  icon: LucideIcons.unplug,
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: _busy.isNotEmpty || ro
                      ? null
                      : () async {
                          final r = await ctx.run(() => ctx.api.delete('${ctx.base}/telegram'));
                          if (r != null && mounted) setState(() => _tg = obj(r['data']));
                          ctx.reload();
                        },
                ),
              ],
            ),
          ] else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Btn(ctx.m('tgConnect'), icon: LucideIcons.send, small: true, busy: _busy == 'link' || _waiting, onTap: _busy.isNotEmpty || ro ? null : () => _link(false)),
                Btn(ctx.m('tgGroup'), icon: LucideIcons.users, kind: BtnKind.ghost, small: true, onTap: _busy.isNotEmpty || ro ? null : () => _link(true)),
              ],
            ),
            if (_waiting) ...[const SizedBox(height: 6), Muted(ctx.m('tgWaiting'))],
          ],
        ]),
        mGap,
        how,
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ IMPORT / EXPORT
String _cell(Object? v) {
  final s = '${v ?? ''}';
  return RegExp(r'[",\n\r]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
}

String _csv(List<List<Object?>> rows) => '﻿${rows.map((r) => r.map(_cell).join(',')).join('\r\n')}';

Future<void> _shareCsv(String name, String text) => SharePlus.instance.share(
  ShareParams(
    files: [XFile.fromData(utf8.encode(text), name: name, mimeType: 'text/csv')],
  ),
);

// CSV / pasted Excel rows → lists of cells (quotes, commas, tabs or semicolons)
List<List<String>> csvRows(String textIn) {
  final src = textIn.replaceFirst('﻿', '');
  final first = src.split(RegExp(r'\r?\n')).first;
  final sep = first.contains('\t')
      ? '\t'
      : first.split(';').length > first.split(',').length
      ? ';'
      : ',';
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var q = false;
  for (var i = 0; i < src.length; i++) {
    final ch = src[i];
    if (q) {
      if (ch == '"' && i + 1 < src.length && src[i + 1] == '"') {
        cell.write('"');
        i++;
      } else if (ch == '"') {
        q = false;
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      q = true;
    } else if (ch == sep) {
      row.add(cell.toString());
      cell.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < src.length && src[i + 1] == '\n') i++;
      row.add(cell.toString());
      rows.add(row);
      row = <String>[];
      cell.clear();
    } else {
      cell.write(ch);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows.map((r) => r.map((c) => c.trim()).toList()).where((r) => r.any((c) => c.isNotEmpty)).toList();
}

const _cols = ['name', 'phone', 'telegram', 'address', 'note', 'usd', 'khr', 'what', 'due'];
const _example = 'name,phone,telegram,address,note,usd,khr,what,due\r\nSokha,012345678,@sokha,Phnom Penh,,12.5,20000,Rice + water,2026-11-01\r\nDara,098765432,,,,,15000,Old notebook,\r\n';

class ExcelTab extends StatefulWidget {
  final DkCtx ctx;
  const ExcelTab({super.key, required this.ctx});
  @override
  State<ExcelTab> createState() => _ExcelTabState();
}

class _ExcelTabState extends State<ExcelTab> {
  DkCtx get ctx => widget.ctx;
  String _busy = '';
  List<Json> _rows = [];
  Json? _result;
  final _paste = TextEditingController();

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  void _read(String text) {
    final all = csvRows(text);
    final head = (all.isEmpty ? <String>[] : all.first).map((h) => h.toLowerCase()).toList();
    final hasHead = head.contains('name');
    final keys = hasHead ? head : _cols;
    setState(() {
      _result = null;
      _rows = [
        for (final r in hasHead ? all.skip(1) : all) {for (final (i, k) in keys.indexed) k: i < r.length ? r[i] : ''},
      ].where((r) => str(r['name']).isNotEmpty).toList();
    });
  }

  Future<void> _export(String what) async {
    setState(() => _busy = what);
    try {
      final r = await ctx.api.get('${ctx.base}/export');
      final d = obj(r['data']);
      final day = todayKH();
      if (what == 'customers') {
        await _shareCsv(
          'debt-customers-$day.csv',
          _csv([
            ['name', 'phone', 'telegram', 'address', 'note', 'owes_usd', 'owes_khr', 'due', 'limit_usd', 'limit_khr'],
            for (final c in objs(d['customers']))
              [
                c['name'],
                c['phone'],
                c['telegram'],
                c['address'],
                c['note'],
                obj(c['balance'])['usd'],
                obj(c['balance'])['khr'],
                dayOf(c['due_at']),
                n(obj(c['limit'])['usd']) == 0 ? '' : obj(c['limit'])['usd'],
                n(obj(c['limit'])['khr']) == 0 ? '' : obj(c['limit'])['khr'],
              ],
          ]),
        );
      } else {
        await _shareCsv(
          'debt-lines-$day.csv',
          _csv([
            ['date', 'customer', 'kind', 'currency', 'amount', 'note', 'method', 'due', 'no', 'by'],
            for (final e in objs(d['entries']))
              [
                dayOf(e['date']),
                e['customer_name'],
                e['kind'],
                e['currency'],
                e['amount'],
                e['note'],
                e['method'],
                dayOf(e['due_at']),
                e['no'],
                str(obj(e['by'])['name']).isEmpty ? obj(e['by'])['kind'] : obj(e['by'])['name'],
              ],
          ]),
        );
      }
    } catch (e) {
      ctx.fail(e);
    }
    if (mounted) setState(() => _busy = '');
  }

  Future<void> _file() async {
    final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['csv', 'txt']);
    if (f == null) return;
    final b = await f.xFile.readAsBytes();
    final text = utf8.decode(b, allowMalformed: true);
    _paste.text = text;
    _read(text);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (!ctx.on('debt_excel')) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          dkHead(context, LucideIcons.fileSpreadsheet, ctx.m('excelTitle'), ctx.m('excelSub')),
          mGap,
          DkLocked(ctx: ctx, addon: 'debt_excel'),
        ],
      );
    }
    final res = _result;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        dkHead(context, LucideIcons.fileSpreadsheet, ctx.m('excelTitle'), ctx.m('excelSub')),
        mGap,
        dkPanel([
          Btn(ctx.m('exportCustomers'), icon: LucideIcons.download, kind: BtnKind.ghost, busy: _busy == 'customers', onTap: _busy.isNotEmpty ? null : () => _export('customers')),
          const SizedBox(height: 8),
          Btn(ctx.m('exportLines'), icon: LucideIcons.download, kind: BtnKind.ghost, busy: _busy == 'lines', onTap: _busy.isNotEmpty ? null : () => _export('lines')),
        ]),
        mGap,
        dkPanel([
          Text(ctx.m('importTitle'), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Muted(ctx.m('importSub')),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Btn(ctx.m('chooseFile'), icon: LucideIcons.upload, kind: BtnKind.ghost, small: true, onTap: _file),
              Btn(ctx.m('example'), icon: LucideIcons.download, kind: BtnKind.ghost, small: true, onTap: () => _shareCsv('debt-example.csv', '﻿$_example')),
            ],
          ),
          gap14,
          Field(controller: _paste, hint: ctx.m('pasteHere'), maxLines: 4, onChanged: _read),
          if (_rows.isNotEmpty) ...[
            gap14,
            Muted(ctx.m('rowsFound', {'n': _rows.length})),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 40,
                columns: [
                  for (final h in [ctx.m('name'), ctx.m('phone'), '\$', '៛', ctx.m('what')]) DataColumn(label: Text(h)),
                ],
                rows: [
                  for (final r in _rows.take(8))
                    DataRow(
                      cells: [
                        for (final k in ['name', 'phone', 'usd', 'khr', 'what']) DataCell(Text(str(r[k]))),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Btn(
              ctx.m('importGo', {'n': _rows.length}),
              icon: LucideIcons.upload,
              busy: _busy == 'import',
              onTap: ctx.readOnly || _busy.isNotEmpty
                  ? null
                  : () async {
                      setState(() => _busy = 'import');
                      final r = await ctx.run(() => ctx.api.post('${ctx.base}/import', {'rows': _rows}));
                      if (r != null && mounted) {
                        setState(() {
                          _result = obj(r['data']);
                          _rows = [];
                          _paste.clear();
                        });
                        ctx.reload();
                      }
                      if (mounted) setState(() => _busy = '');
                    },
            ),
          ],
          if (res != null) ...[
            gap14,
            Text(
              '✓ ${ctx.m('importDone', {'added': res['added'], 'updated': res['updated'], 'skipped': res['skipped']})}${res['full'] == true ? ' ${ctx.m('importFull')}' : ''}',
              style: TextStyle(color: c.good, fontWeight: FontWeight.w700),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        Muted('${fmt(n(ctx.totals['customers']))} / ${fmt(n(ctx.limits['customers']))}'),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ SETTINGS
class SettingsTab extends StatefulWidget {
  final DkCtx ctx;
  const SettingsTab({super.key, required this.ctx});
  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  DkCtx get ctx => widget.ctx;
  late final Json b = ctx.book;
  late final _name = TextEditingController(text: str(b['shop_name']));
  late final _phone = TextEditingController(text: str(b['phone']));
  late final _address = TextEditingController(text: str(b['address']));
  late final _rate = TextEditingController(text: '${ctx.rate}');
  late String _main = str(b['main']).isEmpty ? 'USD' : str(b['main']);
  String _busy = '';

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _rate]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _logo() async {
    final img = await ghPickPicture(
      context,
      GhCtx(id: ctx.id, api: ctx.api, t: ctx.t, data: const {}, reload: ctx.reload, askBuy: (_, {item, onDone}) {}, go: (_) {}, notify: ctx.notify),
      maxSize: 600,
    );
    if (img == null) return;
    setState(() => _busy = 'logo');
    if (await ctx.run(() => ctx.api.post('${ctx.base}/logo', fileForm('photo', img, 'logo.png'))) != null) await ctx.reload();
    if (mounted) setState(() => _busy = '');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ro = ctx.readOnly;
    final logo = str(ctx.book['logo']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        dkHead(context, LucideIcons.settings, ctx.m('settingsTitle'), ctx.m('settingsSub')),
        mGap,
        dkPanel([
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(16)),
                child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.notebookPen, color: c.brand),
              ),
              const SizedBox(width: 12),
              Btn(ctx.m('upload'), icon: LucideIcons.upload, kind: BtnKind.ghost, small: true, busy: _busy == 'logo', onTap: ro || _busy.isNotEmpty ? null : _logo),
              if (logo.isNotEmpty) ...[
                const SizedBox(width: 6),
                Btn(
                  ctx.m('remove'),
                  icon: LucideIcons.trash2,
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: ro
                      ? null
                      : () async {
                          if (await ctx.run(() => ctx.api.delete('${ctx.base}/logo')) != null) ctx.reload();
                        },
                ),
              ],
            ],
          ),
          gap14,
          Field(label: ctx.m('shopName'), controller: _name, maxLength: 80, enabled: !ro),
          gap14,
          Field(label: ctx.m('shopPhone'), controller: _phone, maxLength: 40, keyboard: TextInputType.phone, enabled: !ro),
          gap14,
          Field(label: ctx.m('shopAddress'), controller: _address, maxLength: 200, enabled: !ro),
          gap14,
          Text(ctx.m('mainCur'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Segmented<String>(value: _main, options: const [('USD', '\$ USD'), ('KHR', '៛ KHR')], onChanged: (v) => ro ? null : setState(() => _main = v)),
          gap14,
          Field(label: ctx.m('rate'), controller: _rate, keyboard: TextInputType.number, maxLength: 5, enabled: !ro),
          const SizedBox(height: 4),
          Muted(ctx.m('rateHint')),
          gap14,
          Btn(
            ctx.m('save'),
            icon: LucideIcons.check,
            busy: _busy == 'save',
            onTap: ro || _busy.isNotEmpty
                ? null
                : () async {
                    setState(() => _busy = 'save');
                    final r = await ctx.run(
                      () => ctx.api.put('${ctx.base}/settings', {
                        'shop_name': _name.text.trim(),
                        'phone': _phone.text.trim(),
                        'address': _address.text.trim(),
                        'main': _main,
                        'rate': numOf(_rate.text) ?? 4100,
                      }),
                      ctx.m('saved'),
                    );
                    if (r != null) ctx.reload();
                    if (mounted) setState(() => _busy = '');
                  },
          ),
        ]),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ ADD-ONS
class AddonsTab extends StatelessWidget {
  final DkCtx ctx;
  const AddonsTab({super.key, required this.ctx});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final addons = obj(ctx.data['addons']);
    Widget card(IconData icon, String name, String price, String what, List<Widget> foot, {bool on = false}) => Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: on ? c.goodBg : c.active, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: on ? c.good : c.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                    Row(
                      children: [
                        const CoinIcon(size: 13),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            price,
                            style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(what, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: foot),
        ],
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        dkHead(context, LucideIcons.puzzle, ctx.m('addonsTitle'), ctx.m('addonsSub')),
        mGap,
        card(LucideIcons.bookOpen, ctx.m('renewTitle'), '${fmt(n(ctx.data['base_price']))} ${ctx.m('coins')} · ${ctx.m('oneTime')}', ctx.m('renewSub'), [
          Chip2(ctx.m('unlocked'), icon: LucideIcons.check, tone: Tone.good),
        ], on: true),
        for (final e in addons.entries) ...[
          mGap,
          () {
            final a = obj(e.value);
            final k = e.key;
            final yearly = a['days'] != null;
            final active = a['active'] == true;
            return card(
              dkAddonIcons[k] ?? LucideIcons.puzzle,
              ctx.m('addonNames.$k'),
              '${fmt(n(a['price']))} ${ctx.m('coins')} ${yearly ? ctx.m('perYear') : '· ${ctx.m('forever')}'}',
              ctx.m('addonWhat.$k'),
              active
                  ? [
                      Chip2(a['expires_at'] != null ? ctx.m('ends', {'date': dkDate(a['expires_at'], ctx.lang)}) : ctx.m('unlocked'), icon: LucideIcons.check, tone: Tone.good),
                      if (yearly) Btn(ctx.m('renew', {'coins': fmt(n(a['price']))}), kind: BtnKind.ghost, small: true, onTap: ctx.readOnly ? null : () => ctx.askBuy(k)),
                    ]
                  : [
                      GoldBtn(ctx.m('unlock', {'coins': fmt(n(a['price']))}), onTap: ctx.readOnly ? null : () => ctx.askBuy(k)),
                    ],
              on: active,
            );
          }(),
        ],
      ],
    );
  }
}
