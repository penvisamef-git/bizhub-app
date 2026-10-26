import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/look_sheet.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show GoldBtn, mGap;
import '../mart/mart_kit.dart' show MSheet, showSheet;
import '../restaurant/rest_common.dart' show Segmented, SwitchRow;
import 'wb_common.dart';
import 'wb_data.dart';
import 'wb_more.dart' show LookMini;

// Pages + blocks — WsEditor.jsx. The draft saves a moment after each change; Publish shows it to visitors.

const _templateIcons = {
  'cafe': LucideIcons.coffee,
  'shop': LucideIcons.shoppingBag,
  'salon': LucideIcons.scissors,
  'school': LucideIcons.graduationCap,
  'clinic': LucideIcons.stethoscope,
  'ngo': LucideIcons.handshake,
  'event': LucideIcons.ticket,
  'personal': LucideIcons.userRound,
};
const _third = {
  'cafe': ['Menu', 'ម៉ឺនុយ'],
  'shop': ['Products', 'ផលិតផល'],
  'salon': ['Services', 'សេវាកម្ម'],
  'school': ['Courses', 'វគ្គសិក្សា'],
  'clinic': ['Services', 'សេវាកម្ម'],
  'ngo': ['Our work', 'ការងាររបស់យើង'],
  'event': ['Programme', 'កម្មវិធី'],
  'personal': ['Work', 'ស្នាដៃ'],
};

// a block's first text, to name it in the list
String _summary(Json b, String lang) {
  final d = obj(b['data']);
  for (final k in ['title', 'caption', 'body', 'sub']) {
    final s = tx(d[k], lang);
    if (s.isNotEmpty) return s.length > 60 ? '${s.substring(0, 60)}…' : s;
  }
  final list = (d['items'] ?? d['people'] ?? d['images'] ?? d['rows']);
  if (list is List && list.isNotEmpty && list.first is Map) {
    final f = list.first as Map;
    return tx(f['title'] ?? f['name'] ?? f['label'] ?? f['q'] ?? f['day'], lang);
  }
  return '';
}

// ------------------------------------------------------------------------------------------- starters
class TemplatePicker extends StatefulWidget {
  final WbCtx ctx;
  final bool replace;
  final VoidCallback? onDone;
  const TemplatePicker({super.key, required this.ctx, this.replace = false, this.onDone});
  @override
  State<TemplatePicker> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends State<TemplatePicker> {
  WbCtx get ctx => widget.ctx;
  String _busy = '';

  Future<void> _use(Json t) async {
    final name = ctx.lang == 'km' ? str(t['km']) : str(t['en']);
    if (widget.replace && !await wbConfirm(context, ctx, ctx.m('replaceTitle'), ctx.m('replaceSub', {'name': name}), yes: ctx.m('replaceYes'))) return;
    setState(() => _busy = str(t['key']));
    final r = await ctx.run(() => ctx.api.post('${ctx.base}/template', {'key': t['key'], 'keep_look': false}), ctx.m('saved'));
    if (r != null) {
      ctx.put((_) => obj(r['data']));
      widget.onDone?.call();
    }
    if (mounted) setState(() => _busy = '');
  }

  // the small picture of a starter: its colours, a hero with the icon, three cards
  Widget _mock(C c, WbTheme th, String key) => Container(
    decoration: BoxDecoration(
      color: Color(th.bg),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: c.line),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        Container(height: 8, color: Color(th.c)),
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(th.c), Color(th.c2)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Icon(_templateIcons[key] ?? LucideIcons.layoutGrid, color: Colors.white, size: 26)),
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(th.sf),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Color(th.c).withValues(alpha: .25)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );

  // tap a starter → the starter sheet (its look, big, swipe for the next), Use at the bottom (with the replace question)
  Future<void> _open(List<Json> list, String key) async {
    Json? pick;
    final siteName = tx(ctx.site['name'], ctx.lang).isEmpty ? str(ctx.business['name']) : tx(ctx.site['name'], ctx.lang);
    await showLookSheet(
      context,
      title: ctx.m('startTitle'),
      count: list.length,
      initial: list.indexWhere((t) => str(t['key']) == key).clamp(0, list.length - 1),
      item: (context, i, refresh) {
        final t = list[i];
        final k = str(t['key']);
        return LookItem(
          name: ctx.lang == 'km' ? str(t['km']) : str(t['en']),
          sub: ctx.m('starterPages', {'third': (_third[k] ?? _third['shop']!)[ctx.lang == 'km' ? 1 : 0]}),
          badge: ctx.m('free'),
          badgeTone: Tone.good,
          preview: SizedBox(
            width: 340,
            height: 272,
            child: LookMini(theme: str(t['theme']), name: siteName),
          ),
          acts: [
            LookAct(
              ctx.m('startUse'),
              icon: LucideIcons.check,
              onTap: ctx.readOnly
                  ? null
                  : () async {
                      pick = t;
                      return true;
                    },
            ),
          ],
        );
      },
    );
    // after the sheet is closed: the replace question + apply (onDone may close the sheet around the picker)
    if (pick != null && mounted) await _use(pick!);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final list = objs(ctx.data['templates']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(ctx.m('startTitle'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 4),
        Muted(ctx.m('startSub')),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: .74,
          children: [
            for (final t in list)
              () {
                final th = wbTheme(str(t['theme']));
                final key = str(t['key']);
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _busy.isNotEmpty ? null : () => _open(list, key),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: c.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _mock(c, th, key)),
                        const SizedBox(height: 8),
                        Text(ctx.lang == 'km' ? str(t['km']) : str(t['en']), style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text(ctx.m('starterPages', {'third': (_third[key] ?? _third['shop']!)[ctx.lang == 'km' ? 1 : 0]}), maxLines: 2, style: TextStyle(color: c.muted, fontSize: 11.5)),
                        if (_busy == key) const Padding(padding: EdgeInsets.only(top: 6), child: LinearProgressIndicator(minHeight: 3)),
                      ],
                    ),
                  ),
                );
              }(),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------- page settings
class _PageSheet extends StatefulWidget {
  final WbCtx ctx;
  final Json? page;
  final String elang;
  const _PageSheet({required this.ctx, required this.page, required this.elang});
  @override
  State<_PageSheet> createState() => _PageSheetState();
}

class _PageSheetState extends State<_PageSheet> {
  WbCtx get ctx => widget.ctx;
  bool get isNew => widget.page == null;
  late Json _title = {'km': str(obj(widget.page?['title'])['km']), 'en': str(obj(widget.page?['title'])['en'])};
  late String _slug = str(widget.page?['slug']);
  late bool _menu = widget.page == null || widget.page!['menu'] != false;
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final p = widget.page;
      final r = isNew
          ? await ctx.api.post('${ctx.base}/pages', {'title': _title})
          : await ctx.api.put('${ctx.base}/pages/${p!['_id']}', {'title': _title, 'menu': _menu, if (p['home'] != true) 'slug': _slug});
      if (mounted) Navigator.pop(context, obj(r['data']));
    } catch (e) {
      ctx.fail(e);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.page;
    return MSheet(
      title: isNew ? ctx.m('addPage') : ctx.m('pageSettings'),
      footer: [
        const Spacer(),
        Btn(ctx.m('cancel'), kind: BtnKind.ghost, small: true, onTap: _busy ? null : () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(ctx.m('save'), icon: LucideIcons.save, small: true, busy: _busy, onTap: _busy || (str(_title['km']).trim().isEmpty && str(_title['en']).trim().isEmpty) ? null : _save),
      ],
      children: [
        TrInput(value: _title, onChanged: (v) => setState(() => _title = v), elang: 'km', label: ctx.m('pageTitle'), max: 60, ctx: ctx),
        TrInput(value: _title, onChanged: (v) => setState(() => _title = v), elang: 'en', label: ctx.m('pageTitle'), max: 60, ctx: ctx),
        if (!isNew && p!['home'] != true) ...[
          PlainInput(
            value: _slug,
            label: '${ctx.m('pageLink')} · /site/${ctx.site['slug']}/',
            max: 40,
            onChanged: (v) => setState(() => _slug = v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '-')),
          ),
          SwitchRow(title: ctx.m('inMenu'), value: _menu, onChanged: (v) => setState(() => _menu = v)),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------- the editor
class WbEditor extends StatefulWidget {
  final WbCtx ctx;
  final void Function(Future<void> Function()? flush) onFlush; // the page calls it before Publish
  const WbEditor({super.key, required this.ctx, required this.onFlush});
  @override
  State<WbEditor> createState() => _WbEditorState();
}

class _WbEditorState extends State<WbEditor> {
  WbCtx get ctx => widget.ctx;
  String? _pid;
  List<Json> _blocks = [];
  String? _sel; // the block being edited
  late String _elang = (ctx.site['langs'] as List? ?? const ['km']).map((e) => '$e').firstOrNull ?? 'km';
  String _state = ''; // '' | saving | saved
  Timer? _timer;
  ({String pid, List<Json> blocks})? _pending;
  int _gen = 0;

  List<Json> get pages => ctx.pages;
  Json? get page => pages.where((p) => p['_id'] == _pid).firstOrNull ?? pages.where((p) => p['home'] == true).firstOrNull ?? pages.firstOrNull;

  @override
  void initState() {
    super.initState();
    _pid = str(page?['_id']);
    _blocks = _copyBlocks(page);
    widget.onFlush(_flush);
  }

  @override
  void dispose() {
    widget.onFlush(null);
    _flush();
    super.dispose();
  }

  List<Json> _copyBlocks(Json? p) => [for (final b in objs(p?['blocks'])) deepCopy(b) as Json];

  Future<void> _flush() async {
    _timer?.cancel();
    final job = _pending;
    if (job == null) return;
    _pending = null;
    if (mounted) setState(() => _state = 'saving');
    try {
      final r = await ctx.api.put('${ctx.base}/pages/${job.pid}', {'blocks': job.blocks});
      ctx.put(
        (d) => {
          'pages': [
            for (final p in objs(d['pages'])) p['_id'] == job.pid ? {...p, 'blocks': obj(r['data'])['blocks']} : p,
          ],
          'site': {...obj(d['site']), 'changed_at': r['changed_at'] ?? DateTime.now().toUtc().toIso8601String()},
        },
      );
      if (mounted) setState(() => _state = 'saved');
    } catch (e) {
      if (mounted) setState(() => _state = '');
      ctx.fail(e);
    }
  }

  void _change(List<Json> next) {
    setState(() => _blocks = next);
    if (ctx.readOnly || page == null) return;
    _pending = (pid: str(page!['_id']), blocks: next);
    setState(() => _state = 'saving');
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 900), _flush);
  }

  void _setBlock(String bid, Json patch) => _change([
    for (final b in _blocks) b['id'] == bid ? {...b, ...patch} : b,
  ]);

  void _move(int i, int d) {
    final n = [..._blocks];
    final x = n[i];
    n[i] = n[i + d];
    n[i + d] = x;
    _change(n);
  }

  Future<void> _switchPage(String id) async {
    await _flush();
    setState(() {
      _pid = id;
      _blocks = _copyBlocks(page);
      _sel = null;
      _gen++;
    });
  }

  Future<void> _pageAct(Future<Json> Function() fn, void Function(Json r) after) async {
    await _flush();
    final r = await ctx.run(fn);
    if (r != null) after(r);
  }

  void _putPages(List<Json> list) => ctx.put(
    (_) => {
      'pages': [
        for (final x in list) x['_id'] == _pid ? {...x, 'blocks': _blocks} : x,
      ],
    },
  );

  void _savedPage(Json p, bool isNew) {
    ctx.put(
      (d) => {
        'pages': isNew
            ? [...objs(d['pages']), p]
            : [
                for (final x in objs(d['pages'])) x['_id'] == p['_id'] ? {...x, ...p, 'blocks': x['_id'] == _pid ? _blocks : p['blocks']} : x,
              ],
        'site': {...obj(d['site']), 'changed_at': DateTime.now().toUtc().toIso8601String()},
      },
    );
    if (isNew) _switchPage(str(p['_id']));
  }

  Future<void> _openPageSheet(Json? p) async {
    final r = await showSheet<Json>(context, (_) => _PageSheet(ctx: ctx, page: p, elang: _elang));
    if (r != null) _savedPage(r, p == null);
  }

  Future<void> _addBlock() async {
    final type = await showSheet<String>(context, (_) => _AddSheet(ctx: ctx));
    if (type == null) return;
    final b = newBlock(type);
    final at = _sel != null ? _blocks.indexWhere((x) => x['id'] == _sel) + 1 : _blocks.length;
    final n = [..._blocks]..insert(at < 1 ? _blocks.length : at, b);
    _change(n);
    setState(() => _sel = str(b['id']));
  }

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [TemplatePicker(ctx: ctx)],
      );
    }
    final sel = _blocks.where((b) => b['id'] == _sel).firstOrNull;
    return Column(
      children: [
        _bar(context),
        Expanded(child: sel != null ? _blockForm(context, sel) : _list(context)),
      ],
    );
  }

  Widget _bar(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Text(
            ctx.m('editIn'),
            style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Segmented<String>(
            value: _elang,
            options: const [('km', 'ខ្មែរ'), ('en', 'English')],
            onChanged: (v) => setState(() {
              _elang = v;
              _gen++;
            }),
          ),
          const Spacer(),
          if (_state == 'saving')
            Row(
              children: [
                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 5),
                Text(ctx.m('saving'), style: TextStyle(color: c.muted, fontSize: 12.5)),
              ],
            )
          else if (_state == 'saved')
            Row(
              children: [
                Icon(LucideIcons.check, size: 14, color: c.good),
                const SizedBox(width: 4),
                Text(ctx.m('saved'), style: TextStyle(color: c.good, fontSize: 12.5)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context) {
    final c = context.c;
    final p = page!;
    final ro = ctx.readOnly;
    final maxPages = n(ctx.limits['pages']).toInt();
    final full = pages.length >= maxPages && !ctx.on('web_pages');
    final idx = pages.indexWhere((x) => x['_id'] == p['_id']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        wbPanel([
          Row(
            children: [
              Text(ctx.m('pages'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              const SizedBox(width: 6),
              Muted(ctx.m('pagesUsed', {'n': pages.length, 'max': maxPages})),
              const Spacer(),
              Btn(
                ctx.m('addPage'),
                icon: full ? LucideIcons.lock : LucideIcons.filePlus2,
                kind: BtnKind.ghost,
                small: true,
                onTap: ro ? null : () => full ? ctx.askBuy({'addon': 'web_pages'}) : _openPageSheet(null),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final x in pages)
                ChoiceChip(
                  selected: x['_id'] == p['_id'],
                  avatar: Icon(
                    x['home'] == true
                        ? LucideIcons.house
                        : x['menu'] == false
                        ? LucideIcons.eyeOff
                        : LucideIcons.fileText,
                    size: 14,
                  ),
                  label: Text(tx(x['title'], _elang).isEmpty ? str(x['slug']) : tx(x['title'], _elang)),
                  onSelected: (_) => x['_id'] == p['_id'] ? null : _switchPage(str(x['_id'])),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              RoundBtn(
                LucideIcons.chevronLeft,
                size: 36,
                tip: ctx.m('moveUp'),
                onTap: ro || idx <= 0
                    ? null
                    : () {
                        final ids = pages.map((x) => str(x['_id'])).toList();
                        ids.insert(idx - 1, ids.removeAt(idx));
                        _pageAct(() => ctx.api.put('${ctx.base}/pages-order', {'ids': ids}), (r) => _putPages(objs(r['data'])));
                      },
              ),
              RoundBtn(
                LucideIcons.chevronRight,
                size: 36,
                tip: ctx.m('moveDown'),
                onTap: ro || idx >= pages.length - 1
                    ? null
                    : () {
                        final ids = pages.map((x) => str(x['_id'])).toList();
                        ids.insert(idx + 1, ids.removeAt(idx));
                        _pageAct(() => ctx.api.put('${ctx.base}/pages-order', {'ids': ids}), (r) => _putPages(objs(r['data'])));
                      },
              ),
              Btn(ctx.m('pageSettings'), icon: LucideIcons.settings2, kind: BtnKind.ghost, small: true, onTap: ro ? null : () => _openPageSheet(p)),
              if (p['home'] != true)
                Btn(
                  ctx.m('makeHome'),
                  icon: LucideIcons.house,
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: ro ? null : () => _pageAct(() => ctx.api.post('${ctx.base}/pages/${p['_id']}/home', {}), (r) => _putPages(objs(r['data']))),
                ),
              Btn(
                ctx.m('duplicate'),
                icon: LucideIcons.copy,
                kind: BtnKind.ghost,
                small: true,
                onTap: ro
                    ? null
                    : () {
                        if (full) return ctx.askBuy({'addon': 'web_pages'});
                        _pageAct(() => ctx.api.post('${ctx.base}/pages/${p['_id']}/duplicate', {}), (r) => _savedPage(obj(r['data']), true));
                      },
              ),
              if (p['home'] != true)
                RoundBtn(
                  LucideIcons.trash2,
                  size: 36,
                  tip: ctx.m('deletePage'),
                  fg: c.danger,
                  onTap: ro
                      ? null
                      : () async {
                          if (!await wbConfirm(context, ctx, ctx.m('deletePage'), ctx.m('deletePageSub', {'name': tx(p['title'], ctx.lang).isEmpty ? p['slug'] : tx(p['title'], ctx.lang)}))) return;
                          await _flush();
                          final r = await ctx.run(() => ctx.api.delete('${ctx.base}/pages/${p['_id']}'));
                          if (r == null) return;
                          final rest = pages.where((x) => x['_id'] != p['_id']).toList();
                          ctx.put((_) => {'pages': rest});
                          final next = rest.where((x) => x['home'] == true).firstOrNull ?? rest.firstOrNull;
                          setState(() {
                            _pid = str(next?['_id']);
                            _blocks = _copyBlocks(next);
                            _sel = null;
                          });
                        },
                ),
            ],
          ),
        ]),
        mGap,
        wbPanel([
          Row(
            children: [
              Expanded(
                child: Text(ctx.m('blocks'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              ),
              Btn(ctx.m('addBlock'), icon: LucideIcons.plus, small: true, onTap: ro ? null : _addBlock),
            ],
          ),
          const SizedBox(height: 8),
          if (_blocks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Muted(ctx.m('noBlocks'), align: TextAlign.center),
            ),
          for (final (i, b) in _blocks.indexed)
            Opacity(
              opacity: b['hidden'] == true ? .55 : 1,
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() => _sel = str(b['id'])),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(10)),
                                child: Icon(blockIcons[b['type']] ?? LucideIcons.layoutGrid, size: 17, color: c.brand),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(ctx.block(str(b['type'])), style: const TextStyle(fontWeight: FontWeight.w800)),
                                    Text(
                                      b['hidden'] == true ? ctx.m('hiddenBlock') : _summary(b, _elang),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: c.muted, fontSize: 12.5),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(visualDensity: VisualDensity.compact, tooltip: ctx.m('moveUp'), onPressed: ro || i == 0 ? null : () => _move(i, -1), icon: const Icon(LucideIcons.chevronUp, size: 16)),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: ctx.m('moveDown'),
                      onPressed: ro || i == _blocks.length - 1 ? null : () => _move(i, 1),
                      icon: const Icon(LucideIcons.chevronDown, size: 16),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: b['hidden'] == true ? ctx.m('show') : ctx.m('hide'),
                      onPressed: ro ? null : () => _setBlock(str(b['id']), {'hidden': b['hidden'] != true}),
                      icon: Icon(b['hidden'] == true ? LucideIcons.eye : LucideIcons.eyeOff, size: 16),
                    ),
                  ],
                ),
              ),
            ),
        ]),
        mGap,
        Align(
          alignment: Alignment.centerLeft,
          child: Btn(
            ctx.m('changeStarter'),
            icon: LucideIcons.layoutTemplate,
            kind: BtnKind.ghost,
            small: true,
            onTap: ro
                ? null
                : () async {
                    await _flush();
                    if (!context.mounted) return;
                    await showSheet<void>(
                      context,
                      (s) => MSheet(
                        title: ctx.m('changeStarter'),
                        children: [TemplatePicker(ctx: ctx, replace: true, onDone: () => Navigator.pop(s))],
                      ),
                    );
                    setState(() {
                      _pid = null;
                      _blocks = _copyBlocks(page);
                      _pid = str(page?['_id']);
                      _sel = null;
                    });
                  },
          ),
        ),
      ],
    );
  }

  Widget _blockForm(BuildContext context, Json sel) {
    final c = context.c;
    final ro = ctx.readOnly;
    final type = str(sel['type']);
    final bid = str(sel['id']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        wbPanel([
          Row(
            children: [
              RoundBtn(LucideIcons.arrowLeft, size: 38, tip: ctx.m('backToBlocks'), onTap: () => setState(() => _sel = null)),
              const SizedBox(width: 10),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(10)),
                child: Icon(blockIcons[type] ?? LucideIcons.layoutGrid, size: 17, color: c.brand),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(ctx.block(type), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              IconButton(
                tooltip: ctx.m('duplicate'),
                onPressed: ro
                    ? null
                    : () {
                        final copy = {...deepCopy(sel) as Json, 'id': newBlockId()};
                        final i = _blocks.indexWhere((b) => b['id'] == bid);
                        _change([..._blocks]..insert(i + 1, copy));
                        setState(() {
                          _sel = str(copy['id']);
                          _gen++;
                        });
                      },
                icon: const Icon(LucideIcons.copy, size: 17),
              ),
              IconButton(
                tooltip: sel['hidden'] == true ? ctx.m('show') : ctx.m('hide'),
                onPressed: ro ? null : () => _setBlock(bid, {'hidden': sel['hidden'] != true}),
                icon: Icon(sel['hidden'] == true ? LucideIcons.eye : LucideIcons.eyeOff, size: 17),
              ),
              IconButton(
                tooltip: ctx.m('deleteBlock'),
                onPressed: ro
                    ? null
                    : () async {
                        if (!await wbConfirm(context, ctx, ctx.m('deleteBlock'), ctx.m('deleteBlockSub'))) return;
                        _change(_blocks.where((b) => b['id'] != bid).toList());
                        setState(() => _sel = null);
                      },
                icon: Icon(LucideIcons.trash2, size: 17, color: c.danger),
              ),
            ],
          ),
          if (sel['hidden'] == true) ...[const SizedBox(height: 8), Alert(ctx.m('hiddenBlock'), tone: Tone.warn)],
        ]),
        mGap,
        if (type == 'posts' && !ctx.on('web_blog')) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.warnBg, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Icon(LucideIcons.lock, size: 15, color: c.warn),
                const SizedBox(width: 8),
                Expanded(child: Text(ctx.m('needsBlog'))),
                GoldBtn(fmt(n(ctx.addon('web_blog')['price'])), onTap: ro ? null : () => ctx.askBuy({'addon': 'web_blog'})),
              ],
            ),
          ),
          mGap,
        ],
        wbPanel([
          Fields(key: ValueKey('$bid-$_elang-$_gen'), fields: wbBlocks[type] ?? const {}, data: obj(sel['data']), onChanged: (d) => _setBlock(bid, {'data': d}), ctx: ctx, elang: _elang, pages: pages),
        ]),
      ],
    );
  }
}

// "Add a block" — the blocks in groups
class _AddSheet extends StatelessWidget {
  final WbCtx ctx;
  const _AddSheet({required this.ctx});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return MSheet(
      title: ctx.m('addBlock'),
      children: [
        for (final (g, types) in wbBlockGroups) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Text(
              ctx.t.or('wbk.group.$g', g),
              style: TextStyle(color: c.muted, fontWeight: FontWeight.w800, fontSize: 12.5),
            ),
          ),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.05,
            children: [
              for (final t in types)
                Material(
                  color: c.bg2,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(context, t),
                    child: Stack(
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(blockIcons[t], size: 22, color: c.brand),
                                const SizedBox(height: 6),
                                Text(
                                  ctx.block(t),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (t == 'posts' && !ctx.on('web_blog')) Positioned(top: 6, right: 6, child: Icon(LucideIcons.lock, size: 12, color: c.muted)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
