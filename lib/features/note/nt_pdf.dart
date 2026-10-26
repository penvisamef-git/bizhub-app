import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'nt_api.dart' show ntCode;
import 'nt_blocks.dart';
import 'nt_common.dart';
import 'nt_editor.dart';
import 'nt_export.dart';
import 'nt_extras_text.dart';
import 'nt_tabs.dart' show ntFieldText;

// PDF export (note_pdf): an A4 document with the logo and name (unless hidden), the note (blocks, checkboxes, pictures,
// signatures, stickers), and if wanted the replies / sign-up rows and the "Confirmed" list. Drawn by the app itself and
// put into the PDF as pictures, so Khmer always looks right (the pdf packages break Khmer letters). Page breaks fall
// between lines. Then shared with the phone's share sheet (save, Telegram, print…).

const _pw = 595.0; // A4 width in points = the page's width in logical pixels
const _ph = 842.0;
const _top = 40.0, _bottom = 56.0, _side = 42.0;
const _scale = 2.0; // pixels per point in the pictures (sharp enough to print)

Future<void> ntPdfTool(NtEditorApi ed) => Navigator.of(ed.context).push<void>(
  MaterialPageRoute(fullscreenDialog: true, builder: (_) => NtPdfPage(ctx: ed.ctx, nid: ed.nid, title: str(ed.note['title']), blocks: ed.blocks, files: ed.files)),
);

class NtPdfPage extends StatefulWidget {
  final NtCtx ctx;
  final String nid, title;
  final List<NtBlock> blocks; // what the editor has now (also not saved yet)
  final List<Json> files;
  final Json? data; // tests: the /print answer
  const NtPdfPage({super.key, required this.ctx, required this.nid, this.title = '', this.blocks = const [], this.files = const [], this.data});
  @override
  State<NtPdfPage> createState() => NtPdfPageState();
}

class NtPdfPageState extends State<NtPdfPage> {
  Json? _d;
  String _err = '';
  bool _withEntries = true, _withAcks = true;
  bool _busy = false;
  String _step = '';
  final _doc = GlobalKey();
  final _items = <(GlobalKey, bool)>[]; // each line of the document; true = keep it with the next one (a heading)

  NtCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    if (widget.data != null) {
      _d = widget.data;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final r = await ctx.a.print(widget.nid);
      if (mounted) setState(() => _d = obj(r['data']));
    } catch (e) {
      if (!mounted) return;
      if (ntCode(e) == 'need_pdf') {
        Navigator.pop(context);
        ctx.askBuy('note_pdf');
        return;
      }
      setState(() => _err = ctx.errText(e));
    }
  }

  Json get _note => obj(_d?['note']);
  bool get _collect => obj(_note['share'])['level'] == 'collect';
  List<Json> get _entries => objs(_d?['entries']).where((e) => e['hidden'] != true).toList();
  List<Json> get _acks => objs(_d?['acks']);

  // wait for the pictures on the page (logo, photos, signatures) — at most 6 s
  Future<void> _images() async {
    final urls = <String>{
      if (str(obj(_d?['business'])['logo_url']).isNotEmpty) str(obj(_d?['business'])['logo_url']),
      for (final b in widget.blocks)
        if (b.t == 'draw' || b.t == 'file')
          for (final f in widget.files)
            if (str(f['_id']) == b.fileId && (ntFineKind(f) == 'image' || ntFineKind(f) == 'sign') && str(f['url']).isNotEmpty) str(f['url']),
      if (_withEntries)
        for (final e in _entries)
          for (final f in objs(e['files']))
            if (f['sign'] == true && str(f['url']).isNotEmpty) str(f['url']),
    };
    await Future.wait([for (final u in urls) precacheImage(netImage(u), context).catchError((_) {})]).timeout(const Duration(seconds: 6), onTimeout: () => []);
  }

  // the pages as pictures: the document is cut between its lines
  Future<List<ui.Image>> pages() async {
    final box = _doc.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (box == null) return const [];
    final whole = await box.toImage(pixelRatio: _scale);
    final docH = box.size.height;
    var spans = <(double, double, bool)>[]; // each item's top / bottom in the document, keep with the next
    for (final (k, keep) in _items) {
      final rb = k.currentContext?.findRenderObject() as RenderBox?;
      if (rb == null || !rb.attached) continue;
      final top = rb.localToGlobal(Offset.zero, ancestor: box).dy;
      spans.add((top, top + rb.size.height, keep));
    }
    spans.sort((a, b) => a.$1.compareTo(b.$1));
    // a heading (and a table's head row) travels with the line after it: join them into one block
    final joined = <(double, double, bool)>[];
    for (var i = 0; i < spans.length; i++) {
      var (t, b, keep) = spans[i];
      while (keep && i + 1 < spans.length) {
        i++;
        b = spans[i].$2;
        keep = spans[i].$3;
      }
      joined.add((t, b, false));
    }
    spans = joined;
    const usable = _ph - _top - _bottom;
    final cuts = <(double, double)>[];
    var start = 0.0;
    var end = 0.0;
    for (final (t, b, _) in spans) {
      if (b - start <= usable) {
        end = b;
        continue;
      }
      if (end > start) cuts.add((start, end));
      start = t;
      // one item taller than a page: cut it through
      while (b - start > usable) {
        cuts.add((start, start + usable));
        start += usable;
      }
      end = b;
    }
    if (end > start || cuts.isEmpty) cuts.add((start, end > start ? end : docH));
    final out = <ui.Image>[];
    final footLeft = obj(_note['share'])['hide_owner'] == true ? ntTime(ntNow().toUtc().toIso8601String(), ctx.lang) : '${str(obj(_d?['business'])['name']).isEmpty ? ctx.bizName : str(obj(_d?['business'])['name'])} · ${ntTime(ntNow().toUtc().toIso8601String(), ctx.lang)}';
    for (final (i, (a, b)) in cuts.indexed) {
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.drawRect(const Rect.fromLTWH(0, 0, _pw * _scale, _ph * _scale), Paint()..color = Colors.white);
      canvas.drawImageRect(whole, Rect.fromLTWH(0, a * _scale, _pw * _scale, (b - a) * _scale), Rect.fromLTWH(0, _top * _scale, _pw * _scale, (b - a) * _scale), Paint()..filterQuality = FilterQuality.high);
      _foot(canvas, footLeft, '${ctx.m('pubMade')} · ${ntE(ctx, 'pdfPage', {'n': i + 1, 'k': cuts.length})}');
      final pic = rec.endRecording();
      out.add(await pic.toImage((_pw * _scale).round(), (_ph * _scale).round()));
      pic.dispose();
    }
    whole.dispose();
    return out;
  }

  void _foot(Canvas canvas, String left, String right) {
    const style = TextStyle(color: Color(0xFF8A8F9C), fontSize: 9 * _scale, fontFamily: 'PlusJakartaSans', fontFamilyFallback: ['KantumruyPro']);
    final y = (_ph - _bottom + 22) * _scale;
    canvas.drawLine(Offset(_side * _scale, y - 8 * _scale), Offset((_pw - _side) * _scale, y - 8 * _scale), Paint()..color = const Color(0xFFE5E7EB));
    final l = TextPainter(text: TextSpan(text: left, style: style), textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…')..layout(maxWidth: (_pw / 2 - _side) * _scale);
    l.paint(canvas, Offset(_side * _scale, y));
    final r = TextPainter(text: TextSpan(text: right, style: style), textDirection: TextDirection.ltr, maxLines: 1)..layout(maxWidth: (_pw / 2) * _scale);
    r.paint(canvas, Offset((_pw - _side) * _scale - r.width, y));
  }

  Future<void> _share() async {
    setState(() {
      _busy = true;
      _step = ntE(ctx, 'pdfMaking');
    });
    try {
      await _images();
      await WidgetsBinding.instance.endOfFrame;
      final list = await pages();
      if (list.isEmpty) throw StateError('no pages');
      final bytes = await ntPdf(list, title: widget.title);
      for (final p in list) {
        p.dispose();
      }
      await ntShareFile(bytes, ntFileName(widget.title.isEmpty ? ctx.m('untitled') : widget.title, 'pdf'), 'application/pdf');
    } catch (e) {
      ctx.notify(e is ApiError ? ctx.errText(e) : ctx.m('loadFail'));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _step = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.appBg,
      appBar: AppBar(
        backgroundColor: c.appBg,
        surfaceTintColor: Colors.transparent,
        title: Text(ctx.m('pdfTitle'), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _d == null
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: _err.isNotEmpty ? LoadError(text: _err, retry: ctx.m('retry'), onRetry: _load) : const SkelList(rows: 4),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Muted(ntE(ctx, 'pdfAppSub')),
                      if (_entries.isNotEmpty)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: _withEntries,
                          onChanged: _busy ? null : (v) => setState(() => _withEntries = v),
                          title: Text(ctx.m(_collect ? 'pdfWithRows' : 'pdfWithReplies', {'n': fmt(_entries.length)})),
                        ),
                      if (_acks.isNotEmpty)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: _withAcks,
                          onChanged: _busy ? null : (v) => setState(() => _withAcks = v),
                          title: Text(ctx.m('pdfWithAcks', {'n': fmt(_acks.length)})),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    color: c.bg2,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.fitWidth,
                          child: DecoratedBox(
                            decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 6))]),
                            child: _document(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.paddingOf(context).bottom),
                  child: Btn(_busy ? _step : ntE(ctx, 'pdfShare'), icon: LucideIcons.fileDown, busy: _busy, expand: true, onTap: _share),
                ),
              ],
            ),
    );
  }

  // ---------------------------------------------------------------- the document (always the light look, on white)
  Widget _item(Widget w, {bool keep = false}) {
    final k = GlobalKey();
    _items.add((k, keep));
    return KeyedSubtree(key: k, child: w);
  }

  Widget _document() {
    _items.clear();
    final biz = obj(_d?['business']);
    final hidden = obj(_note['share'])['hide_owner'] == true;
    final name = str(biz['name']).isEmpty ? ctx.bizName : str(biz['name']);
    final logo = str(biz['logo_url']);
    final fields = objs(obj(_note['form'])['fields']);
    final entries = _withEntries ? _entries : const <Json>[];
    final acks = _withAcks ? _acks : const <Json>[];
    return Theme(
      data: buildTheme(dark: false, khmer: ctx.km),
      child: Builder(
        builder: (context) {
          final c = context.c;
          Widget h2(String t) => Padding(
            padding: const EdgeInsets.only(top: 22, bottom: 8),
            child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          );
          return RepaintBoundary(
            key: _doc,
            child: Container(
              width: _pw,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(_side, 0, _side, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _item(
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              if (!hidden) ...[
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(8)),
                                  clipBehavior: Clip.antiAlias,
                                  alignment: Alignment.center,
                                  child: logo.isNotEmpty
                                      ? Image(image: netImage(logo), fit: BoxFit.cover, width: 30, height: 30, errorBuilder: (_, _, _) => const SizedBox.shrink())
                                      : Text(name.isEmpty ? 'B' : name.substring(0, 1), style: TextStyle(fontWeight: FontWeight.w800, color: c.brandInk)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                              ] else
                                const Spacer(),
                              Text(ntDate(ntNow().toUtc().toIso8601String(), ctx.lang), style: TextStyle(color: c.muted, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Divider(height: 1, color: c.line),
                          const SizedBox(height: 18),
                          Text(widget.title.isEmpty ? ctx.m('untitled') : widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24, height: 1.3)),
                          const SizedBox(height: 4),
                          Text(ctx.m('pdfUpdated', {'date': ntTime(_note['updated_date'], ctx.lang)}), style: TextStyle(color: c.muted, fontSize: 11)),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),
                  for (final (i, b) in widget.blocks.indexed)
                    if (!(b.isText && b.text.isEmpty && b.t == 'p'))
                      _item(Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: _block(context, b, i))),
                  if (entries.isNotEmpty) ...[
                    _item(h2(_collect ? ctx.m('collectTitle') : ctx.m('entriesTitle')), keep: true),
                    if (_collect && fields.isNotEmpty) ...[
                      _item(_tableRow(context, ['#', ctx.m('ackColName'), for (final f in fields) str(f['label']), ctx.m('fxText'), ctx.m('fxTime')], head: true), keep: true),
                      for (final (i, e) in entries.indexed)
                        _item(
                          _tableRow(context, ['${i + 1}', str(e['name']), for (final f in fields) ntFieldText(ctx, f, obj(e['fields'])[str(f['id'])]), str(e['text']), ntTime(e['created_date'], ctx.lang)]),
                        ),
                    ] else
                      for (final e in entries) _item(_reply(context, e)),
                  ],
                  if (acks.isNotEmpty) ...[
                    _item(h2(ctx.m('ackTitle')), keep: true),
                    _item(_tableRow(context, ['#', ctx.m('ackColName'), ctx.m('ackColWhen')], head: true), keep: true),
                    for (final (i, a) in acks.indexed) _item(_tableRow(context, ['${i + 1}', str(a['name']), ntTime(a['at'], ctx.lang)])),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _block(BuildContext context, NtBlock b, int i) {
    final c = context.c;
    final f = widget.files.where((x) => str(x['_id']) == b.fileId).firstOrNull;
    if (b.t == 'audio' || (b.t == 'file' && f != null && ntFineKind(f) != 'image')) {
      if (f == null) return const SizedBox.shrink();
      final kind = ntFineKind(f);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Icon(ntKindIcon(kind), size: 16, color: ntKindColour(kind)),
            const SizedBox(width: 8),
            Expanded(child: Text(str(f['name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
            Text(ntBytes(f['size']), style: TextStyle(color: c.muted, fontSize: 11)),
          ],
        ),
      );
    }
    return ntBlockView(NtBlockView(context, ctx, b, widget.files, i, nid: widget.nid));
  }

  Widget _reply(BuildContext context, Json e) {
    final c = context.c;
    final files = objs(e['files']);
    final signs = files.where((f) => f['sign'] == true && str(f['url']).isNotEmpty).toList();
    final others = files.where((f) => f['sign'] != true).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: e['by_owner'] == true ? c.active : c.bg2, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(e['by_owner'] == true ? ctx.m('ownerTag') : (str(e['name']).isEmpty ? ctx.m('guest') : str(e['name'])), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
              const SizedBox(width: 8),
              Text(ntTime(e['created_date'], ctx.lang), style: TextStyle(color: c.muted, fontSize: 10.5)),
            ],
          ),
          if (str(e['text']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(str(e['text']), style: const TextStyle(fontSize: 12.5, height: 1.5))),
          for (final s in signs)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Image(image: netImage(str(s['url'])), height: 70, fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink()),
            ),
          if (others.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('📎 ${others.map((f) => str(f['name'])).join(', ')}', style: TextStyle(color: c.muted, fontSize: 11))),
        ],
      ),
    );
  }

  // a table line (cells in equal parts; the first one small)
  Widget _tableRow(BuildContext context, List<String> cells, {bool head = false}) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: head ? c.bg2 : null,
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, t) in cells.indexed)
            Expanded(
              flex: i == 0 ? 1 : 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(t, style: TextStyle(fontSize: 10.5, height: 1.4, fontWeight: head ? FontWeight.w800 : FontWeight.w400)),
              ),
            ),
        ],
      ),
    );
  }
}
