import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/color_pick.dart';
import '../../widgets/look_sheet.dart';
import '../../widgets/ui.dart';
import '../debt/dk_common.dart' show dkDate, dkTime;
import '../mart/mart_common.dart' show GoldBtn, mGap, fileForm, todayKH;
import '../mart/mart_kit.dart' show showSheet;
import '../restaurant/rest_common.dart' show SwitchRow, gap14;
import 'qg_common.dart';
import 'qg_data.dart';
import 'qg_editor.dart' show BuyFilesSheet;
import 'qg_inbox.dart' show shareCsv, localTime;
import 'qr_art.dart';

// QgMore.jsx: Designs · Stats · Bulk · Telegram · Business info · Add-ons

Widget _tabList(List<Widget> children) => ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: children);

Widget _empty(BuildContext context, String text) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Muted(text));

// ------------------------------------------------------------------------------------------- designs
const _frames = ['all', 'mine', 'none', 'card', 'banner', 'pill', 'circle', 'ticket', 'phone', 'polaroid', 'bubble', 'corners'];

class DesignsTab extends StatefulWidget {
  final QgCtx ctx;
  const DesignsTab({super.key, required this.ctx});
  @override
  State<DesignsTab> createState() => _DesignsTabState();
}

class _DesignsTabState extends State<DesignsTab> {
  QgCtx get ctx => widget.ctx;
  String _frame = 'all';
  final _arts = <String, QrArt>{};

  QrArt _art(String k) => _arts.putIfAbsent(k, () => qrDesignArt(text: '${Config.siteUrl}/x/sample', design: k, size: 170, scanMe: ctx.scanMe));

  // tap a design → the design sheet (big, swipe for the next), Buy at the bottom (owned ones are used per code in the editor)
  Future<void> _open(String key, List<String> list, List<String> owned) async {
    final price = n(ctx.prices['qr_design']);
    await showLookSheet(
      context,
      title: ctx.m('designsTitle'),
      count: list.length,
      initial: list.indexOf(key),
      item: (context, i, refresh) {
        final k = list[i];
        final mine = owned.contains(k);
        return LookItem(
          name: qrDesigns[k]!.name(ctx.lang),
          badge: mine ? (k == 'plain' ? ctx.m('free') : ctx.m('yours')) : '${fmt(price)} ${ctx.m('coins')}',
          badgeTone: mine ? Tone.good : Tone.warn,
          sub: ctx.m('frames.${qrDesigns[k]!.frame}'),
          preview: SizedBox(
            width: 300,
            child: FittedBox(child: SvgArt(art: _art(k))),
          ),
          acts: [
            if (!mine)
              LookAct(
                ctx.m('buy', {'coins': fmt(price)}),
                gold: true,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        ctx.askBuy({'design': k});
                        return true;
                      },
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final owned = (ctx.data['designs'] as List? ?? const ['plain']).map((e) => '$e').toList();
    final shown = qrDesigns.keys.where((k) => _frame == 'all' || (_frame == 'mine' ? owned.contains(k) : qrDesigns[k]!.frame == _frame)).toList();
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          sliver: SliverList.list(
            children: [
              qgHead(context, LucideIcons.palette, ctx.m('designsTitle'), ctx.m('designsSub', {'n': qrDesigns.length - 1})),
              mGap,
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final k in _frames)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(label: Text('${ctx.m('frames.$k')}${k == 'mine' ? ' (${owned.length})' : ''}'), selected: _frame == k, onSelected: (_) => setState(() => _frame = k)),
                      ),
                  ],
                ),
              ),
              mGap,
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 190, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .66),
            itemCount: shown.length,
            itemBuilder: (_, i) {
              final k = shown[i];
              final mine = owned.contains(k);
              final a = _art(k);
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _open(k, shown, owned),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: mine ? c.good : c.line, width: mine ? 1.6 : 1),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: FittedBox(child: SvgArt(art: a)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        qrDesigns[k]!.name(ctx.lang),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      mine
                          ? Text(
                              k == 'plain' ? ctx.m('free') : ctx.m('yours'),
                              style: TextStyle(color: c.good, fontWeight: FontWeight.w800, fontSize: 12),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CoinIcon(size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  fmt(n(ctx.prices['qr_design'])),
                                  style: TextStyle(color: c.muted, fontWeight: FontWeight.w800, fontSize: 12),
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------- stats
class StatsTab extends StatefulWidget {
  final QgCtx ctx;
  const StatsTab({super.key, required this.ctx});
  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  QgCtx get ctx => widget.ctx;
  int _days = 30, _page = 1;
  String _code = '';
  Json? _st, _hist;

  @override
  void initState() {
    super.initState();
    if (ctx.on('qr_stats')) {
      _load();
      _loadHist();
    }
  }

  Future<void> _load() async {
    setState(() => _st = null);
    try {
      final r = await ctx.api.get('${ctx.base}/stats', {'days': _days, 'code': _code});
      if (mounted) setState(() => _st = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _loadHist() async {
    try {
      final r = await ctx.api.get('${ctx.base}/scans', {'code': _code, 'page': _page, 'limit': 25});
      if (mounted) setState(() => _hist = r);
    } catch (_) {}
  }

  String _nameOf(Object? cid) => str(ctx.codes.where((c) => c['_id'] == cid).firstOrNull?['name']).isEmpty ? '—' : str(ctx.codes.firstWhere((c) => c['_id'] == cid)['name']);
  String _dev(Object? k) => ctx.t.or('qg.devices.$k', str(k));

  Widget _bars(BuildContext context, String title, List<Json> list, {String Function(String)? label}) {
    final c = context.c;
    final max = list.fold<num>(1, (a, x) => n(x['n']) > a ? n(x['n']) : a);
    return qgPanel([
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      const SizedBox(height: 10),
      if (list.isEmpty)
        Muted(ctx.m('noScans'))
      else
        for (final x in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(label != null ? label(str(x['key'])) : str(x['key']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(value: n(x['n']) / max, minHeight: 9, backgroundColor: c.bg2, color: c.brand),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    fmt(n(x['n'])),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final head = qgHead(context, LucideIcons.chartColumn, ctx.m('statsTitle'), ctx.m('statsSub'));
    if (!ctx.on('qr_stats')) return _tabList([head, mGap, QgLocked(ctx: ctx, addon: 'qr_stats')]);
    final st = _st;
    final hist = _hist;
    return RefreshIndicator(
      onRefresh: () async {
        await _load();
        await _loadHist();
      },
      child: _tabList([
        head,
        mGap,
        qgPanel([
          DropdownButtonFormField<String>(
            initialValue: _code,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              DropdownMenuItem(value: '', child: Text(ctx.m('allCodes'))),
              for (final x in ctx.codes)
                DropdownMenuItem(
                  value: str(x['_id']),
                  child: Text(str(x['name']), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) {
              setState(() {
                _code = v ?? '';
                _page = 1;
              });
              _load();
              _loadHist();
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: [
              for (final d in [7, 30, 90, 365])
                ChoiceChip(
                  label: Text('$d'),
                  selected: _days == d,
                  onSelected: (_) {
                    setState(() => _days = d);
                    _load();
                  },
                ),
            ],
          ),
        ]),
        mGap,
        if (st == null)
          const SkelList(rows: 3)
        else ...[
          Row(
            children: [
              for (final (i, (k, v)) in [
                (ctx.m('today'), st['today']),
                (ctx.m('total', {'n': st['days'] ?? _days}), st['total']),
                (ctx.m('allTime'), st['all_time']),
              ].indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Panel(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          k,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.muted, fontSize: 12),
                        ),
                        Text(fmt(n(v)), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          mGap,
          qgPanel([
            if (n(st['total']) == 0)
              Muted(ctx.m('noScans'))
            else
              SizedBox(
                height: 130,
                child: () {
                  final series = objs(st['series']);
                  final max = series.fold<num>(1, (a, x) => n(x['scans']) > a ? n(x['scans']) : a);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final d in series)
                        Expanded(
                          child: Tooltip(
                            message: '${d['day']} · ${d['scans']}',
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: .8),
                              height: 130 * (n(d['scans']) / max).clamp(.02, 1).toDouble(),
                              decoration: BoxDecoration(
                                color: c.brand,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                }(),
              ),
          ]),
          mGap,
          qgPanel([
            Text(ctx.m('byHour'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 10),
            SizedBox(
              height: 110,
              child: () {
                final hours = (st['hours'] as List? ?? List.filled(24, 0)).map(n).toList();
                final max = hours.fold<num>(1, (a, x) => x > a ? x : a);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final (h, v) in hours.indexed)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Tooltip(
                              message: '$h:00 · $v',
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                height: 88 * (v / max).clamp(.02, 1).toDouble(),
                                decoration: BoxDecoration(
                                  color: c.brand.withValues(alpha: .75),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 16,
                              child: Text(h % 3 == 0 ? '$h' : '', style: TextStyle(fontSize: 9.5, color: c.muted)),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              }(),
            ),
          ]),
          mGap,
          _bars(context, ctx.m('topCodes'), [
            for (final x in objs(st['top'])) {'key': x['name'], 'n': x['scans']},
          ]),
          mGap,
          if (st['geo'] == true) ...[
            _bars(context, ctx.m('cities'), objs(st['city'])),
            mGap,
            _bars(context, ctx.m('countries'), objs(st['country'])),
            mGap,
            _bars(context, ctx.m('device'), objs(st['device']), label: _dev),
            mGap,
            _bars(context, ctx.m('systems'), objs(st['os'])),
          ] else
            qgPanel([
              Row(
                children: [
                  Icon(LucideIcons.mapPin, size: 16, color: c.brand),
                  const SizedBox(width: 6),
                  Text(ctx.m('geoTitle'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 8),
              NeedLine(ctx: ctx, addon: 'qr_geo'),
            ]),
        ],
        mGap,
        qgPanel([
          Row(
            children: [
              Expanded(
                child: Text(ctx.m('history'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              Btn(
                ctx.m('excel'),
                icon: LucideIcons.download,
                kind: BtnKind.ghost,
                small: true,
                onTap: n(obj(hist?['pagination'])['total']) == 0
                    ? null
                    : () async {
                        final r = await ctx.run(() => ctx.api.get('${ctx.base}/scans', {'code': _code, 'all': '1'}));
                        if (r == null) return;
                        await shareCsv('scans-${todayKH()}.csv', [
                          ['Date', 'QR', 'Device', 'System', 'Browser', 'City', 'Country'],
                          for (final x in objs(r['data'])) [localTime(x['at']), _nameOf(x['code_id']), x['device'], x['os'], x['browser'], x['city'], x['country']],
                        ]);
                      },
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (hist == null)
            const Padding(padding: EdgeInsets.all(12), child: Text('…'))
          else if (objs(hist['data']).isEmpty)
            _empty(context, ctx.m('noScans'))
          else ...[
            for (final x in objs(hist['data']))
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.line)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_nameOf(x['code_id']), style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (hist['geo'] == true) ...[
                            Muted([_dev(x['device']), x['os'], x['browser']].where((e) => str(e).isNotEmpty).join(' · ')),
                            Muted([x['city'], x['country']].where((e) => str(e).isNotEmpty).join(', ').isEmpty ? '—' : [x['city'], x['country']].where((e) => str(e).isNotEmpty).join(', ')),
                          ],
                        ],
                      ),
                    ),
                    Text(dkTime(x['at'], ctx.lang), style: TextStyle(color: c.muted, fontSize: 12.5)),
                  ],
                ),
              ),
            if (n(obj(hist['pagination'])['pages']) > 1)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Btn(
                      ctx.m('prev'),
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: _page <= 1
                          ? null
                          : () {
                              setState(() => _page--);
                              _loadHist();
                            },
                    ),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('$_page / ${obj(hist['pagination'])['pages']}')),
                    Btn(
                      ctx.m('next'),
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: _page >= n(obj(hist['pagination'])['pages'])
                          ? null
                          : () {
                              setState(() => _page++);
                              _loadHist();
                            },
                    ),
                  ],
                ),
              ),
            if (hist['geo'] != true) ...[const SizedBox(height: 8), Muted(ctx.m('geoLocked'))],
          ],
        ]),
      ]),
    );
  }
}

// ------------------------------------------------------------------------------------------- bulk
class BulkTab extends StatefulWidget {
  final QgCtx ctx;
  const BulkTab({super.key, required this.ctx});
  @override
  State<BulkTab> createState() => _BulkTabState();
}

class _BulkTabState extends State<BulkTab> {
  QgCtx get ctx => widget.ctx;
  String _type = 'url', _folder = '', _design = 'plain';
  final _list = TextEditingController();
  bool _busy = false, _sharing = false;
  Json? _made;

  @override
  void dispose() {
    _list.dispose();
    super.dispose();
  }

  List<Json> get _rows => _list.text
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .map((l) {
        final i = l.indexOf(RegExp(r'[,;\t]'));
        String unq(String s) => s.trim().replaceAll(RegExp(r'^"|"$'), '');
        return i < 0 ? <String, dynamic>{'name': l, 'value': ''} : <String, dynamic>{'name': unq(l.substring(0, i)), 'value': unq(l.substring(i + 1))};
      })
      .take(500)
      .toList();

  Future<void> _make() async {
    setState(() => _busy = true);
    final r = await ctx.run(
      () => ctx.api.post('${ctx.base}/bulk', {
        'type': _type,
        'folder_id': _folder.isEmpty ? null : _folder,
        'rows': _rows,
        'design': {'key': _design},
      }),
    );
    if (r != null) {
      final made = objs(r['data']);
      setState(() => _made = r);
      ctx.put(
        (d) => {
          'codes': [...made, ...objs(d['codes'])],
        },
      );
      ctx.notify(ctx.m('bulkDone', {'n': made.length}));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final head = qgHead(context, LucideIcons.layers, ctx.m('bulkTitle'), ctx.m('bulkSub'));
    if (!ctx.on('qr_bulk')) return _tabList([head, mGap, QgLocked(ctx: ctx, addon: 'qr_bulk')]);
    final rows = _rows;
    final designs = (ctx.data['designs'] as List? ?? const ['plain']).map((e) => '$e').toList();
    Widget select(String label, String value, List<(String, String)> items, ValueChanged<String> on) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: items.any((x) => x.$1 == value) ? value : items.first.$1,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: [
          for (final (k, l) in items)
            DropdownMenuItem(
              value: k,
              child: Text(l, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) => setState(() => on(v ?? '')),
      ),
    );
    final made = objs(_made?['data']);
    return _tabList([
      head,
      mGap,
      qgPanel([
        select(ctx.m('bulkType'), _type, [('url', ctx.m('types.url')), ('text', ctx.m('types.text'))], (v) => _type = v),
        select(ctx.m('folder'), _folder, [('', ctx.m('noFolder')), for (final f in ctx.folders) (str(f['_id']), str(f['name']))], (v) => _folder = v),
        select(ctx.m('sDesign'), _design, [for (final k in designs) (k, qrDesigns[k]?.name(ctx.lang) ?? k)], (v) => _design = v),
        Field(label: '${ctx.m('bulkList')} (${rows.length})', controller: _list, hint: ctx.m('bulkPh'), maxLines: 9, onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Btn(
              ctx.m('bulkFile'),
              icon: LucideIcons.upload,
              kind: BtnKind.ghost,
              small: true,
              onTap: () async {
                final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['csv', 'txt']);
                if (f == null) return;
                final text = utf8.decode(await f.xFile.readAsBytes(), allowMalformed: true).replaceFirst('﻿', '');
                setState(() => _list.text = text);
              },
            ),
            Btn(ctx.m('bulkMake', {'n': rows.length}), icon: LucideIcons.layers, busy: _busy, onTap: ctx.readOnly || _busy || rows.isEmpty ? null : _make),
          ],
        ),
      ]),
      if (_made != null) ...[
        mGap,
        qgPanel([
          Row(
            children: [
              Expanded(
                child: Text(ctx.m('bulkDone', {'n': made.length}), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              Btn(
                ctx.m('printSheet'),
                icon: LucideIcons.printer,
                small: true,
                busy: _sharing,
                onTap: _sharing || made.isEmpty
                    ? null
                    : () async {
                        setState(() => _sharing = true);
                        try {
                          await shareCodeSheets(ctx, made, ctx.m('bulkTitle'));
                        } catch (e) {
                          ctx.fail(e);
                        }
                        if (mounted) setState(() => _sharing = false);
                      },
              ),
            ],
          ),
          if ((_made!['skipped'] as List? ?? const []).isNotEmpty) ...[
            const SizedBox(height: 8),
            Alert(ctx.m('bulkSkipped', {'list': (_made!['skipped'] as List).join(', ')}), tone: Tone.warn),
          ],
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: .8,
            children: [
              for (final x in made.take(60))
                Column(
                  children: [
                    Expanded(
                      child: FittedBox(
                        child: QrView(code: x, logo: ctx.logo, size: 110, scanMe: ctx.scanMe),
                      ),
                    ),
                    Text(
                      str(x['name']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
            ],
          ),
        ]),
      ],
    ]);
  }
}

// ------------------------------------------------------------------------------------------- telegram
class TelegramTab extends StatefulWidget {
  final QgCtx ctx;
  const TelegramTab({super.key, required this.ctx});
  @override
  State<TelegramTab> createState() => _TelegramTabState();
}

class _TelegramTabState extends State<TelegramTab> {
  QgCtx get ctx => widget.ctx;
  late Json _tg = obj(ctx.data['telegram']);
  String _busy = '';
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _wait() {
    _poll?.cancel();
    var tries = 0;
    _poll = Timer.periodic(const Duration(seconds: 3), (t) async {
      if (++tries > 100) return t.cancel();
      try {
        final r = await ctx.api.get('${ctx.base}/telegram');
        if (!mounted) return t.cancel();
        setState(() => _tg = obj(r['data']));
        if (_tg['connected'] == true) {
          t.cancel();
          ctx.put((_) => {'telegram': _tg});
        }
      } catch (_) {}
    });
    setState(() {});
  }

  Future<void> _link(bool group) async {
    setState(() => _busy = 'link');
    final r = await ctx.run(() => ctx.api.post('${ctx.base}/telegram/link', {}));
    if (r != null) {
      final u = str(obj(r['data'])[group ? 'group_url' : 'url']);
      if (u.isNotEmpty) await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
      _wait();
    }
    if (mounted) setState(() => _busy = '');
  }

  @override
  Widget build(BuildContext context) {
    final head = qgHead(context, LucideIcons.send, ctx.m('tgTitle'), ctx.m('tgSub'));
    if (!ctx.on('qr_telegram')) return _tabList([head, mGap, QgLocked(ctx: ctx, addon: 'qr_telegram')]);
    final tg = _tg;
    final ro = ctx.readOnly;
    return _tabList([
      head,
      mGap,
      qgPanel([
        if (tg['configured'] != true)
          Muted(ctx.m('tgNotConfigured'))
        else if (tg['connected'] == true) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Chip2(ctx.m('tgConnected', {'name': tg['chat_name']}), icon: LucideIcons.check, tone: Tone.good),
          ),
          gap14,
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
                        final r = await ctx.run(() => ctx.api.post('${ctx.base}/telegram/test', {}));
                        if (r != null) ctx.notify(str(r['message']));
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
                        if (r == null) return;
                        setState(() => _tg = obj(r['data']));
                        ctx.put((_) => {'telegram': _tg});
                      },
              ),
            ],
          ),
          gap14,
          SwitchRow(
            title: ctx.m('weekly'),
            value: ctx.settings['weekly'] != false,
            onChanged: ro
                ? null
                : (v) async {
                    final r = await ctx.run(() => ctx.api.put('${ctx.base}/settings', {'weekly': v}));
                    if (r != null) ctx.put((_) => {'settings': obj(r['data'])});
                  },
          ),
          Muted(ctx.m('weeklySub')),
        ] else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Btn(ctx.m('tgConnect'), icon: LucideIcons.send, busy: _busy == 'link', onTap: _busy.isNotEmpty || ro ? null : () => _link(false)),
              Btn(ctx.m('tgGroup'), kind: BtnKind.ghost, onTap: _busy.isNotEmpty || ro ? null : () => _link(true)),
            ],
          ),
          if (_poll?.isActive == true) ...[const SizedBox(height: 8), Muted(ctx.m('tgWaiting'))],
        ],
        gap14,
        Muted(ctx.m('tgHow')),
      ]),
    ]);
  }
}

// ------------------------------------------------------------------------------------------- business info
class ProfileTab extends StatefulWidget {
  final QgCtx ctx;
  const ProfileTab({super.key, required this.ctx});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  QgCtx get ctx => widget.ctx;
  String _busy = '';
  late String _color = (str(ctx.settings['color']).isEmpty ? '#E0581A' : str(ctx.settings['color'])).toUpperCase();

  Future<void> _logo(bool remove) async {
    List<int>? bytes;
    if (!remove) {
      final src = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (s) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(leading: const Icon(LucideIcons.image), title: Text(ctx.m('upload')), onTap: () => Navigator.pop(s, ImageSource.gallery)),
              ListTile(leading: const Icon(LucideIcons.camera), title: Text(ctx.t('app.takePhoto')), onTap: () => Navigator.pop(s, ImageSource.camera)),
            ],
          ),
        ),
      );
      if (src == null) return;
      final f = await ImagePicker().pickImage(source: src, maxWidth: 600, maxHeight: 600, imageQuality: 88);
      if (f == null) return;
      bytes = await f.readAsBytes();
    }
    setState(() => _busy = 'logo');
    final r = await ctx.run(() => remove ? ctx.api.delete('${ctx.base}/logo') : ctx.api.post('${ctx.base}/logo', fileForm('photo', bytes!, 'logo.jpg')));
    if (r != null) ctx.put((_) => {'settings': obj(r['data'])});
    if (mounted) setState(() => _busy = '');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final logo = ctx.logo;
    final ro = ctx.readOnly;
    final saved = (str(ctx.settings['color']).isEmpty ? '#E0581A' : str(ctx.settings['color'])).toUpperCase();
    return _tabList([
      qgHead(context, LucideIcons.store, ctx.m('profileTitle'), ctx.m('profileSub')),
      mGap,
      qgPanel([
        Text(ctx.m('logo'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: c.bg2,
                shape: BoxShape.circle,
                border: Border.all(color: c.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.imagePlus, color: c.muted),
            ),
            const SizedBox(width: 12),
            Btn(
              _busy == 'logo' ? '…' : ctx.m('upload'),
              icon: LucideIcons.imagePlus,
              kind: BtnKind.ghost,
              small: true,
              busy: _busy == 'logo',
              onTap: ro || _busy.isNotEmpty ? null : () => _logo(false),
            ),
            if (logo.isNotEmpty && _busy.isEmpty) ...[const SizedBox(width: 6), RoundBtn(LucideIcons.trash2, size: 38, tip: ctx.m('remove'), fg: c.danger, onTap: ro ? null : () => _logo(true))],
          ],
        ),
        gap14,
        Text(ctx.m('defaultColor'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ColorRow(
          value: _color,
          colors: const ['#E0581A', '#DC2626', '#DB2777', '#9333EA', '#4F46E5', '#0284C7', '#0D9488', '#16A34A', '#CA8A04', '#334155'],
          customLabel: ctx.m('defaultColor'),
          saveLabel: ctx.m('save'),
          cancelLabel: ctx.m('cancel'),
          onChanged: (v) => setState(() => _color = v.toUpperCase()),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Btn(
            ctx.m('save'),
            icon: LucideIcons.save,
            small: true,
            busy: _busy == 'c',
            onTap: ro || _color == saved || _busy.isNotEmpty
                ? null
                : () async {
                    setState(() => _busy = 'c');
                    final r = await ctx.run(() => ctx.api.put('${ctx.base}/settings', {'color': _color}), ctx.m('saved'));
                    if (r != null) ctx.put((_) => {'settings': obj(r['data'])});
                    if (mounted) setState(() => _busy = '');
                  },
          ),
        ),
      ]),
    ]);
  }
}

// ------------------------------------------------------------------------------------------- add-ons
class AddonsTab extends StatelessWidget {
  final QgCtx ctx;
  const AddonsTab({super.key, required this.ctx});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final addons = obj(ctx.data['addons']);
    final ro = ctx.readOnly;
    Widget card(IconData icon, String name, String price, String what, List<Widget> foot, {bool on = false, String note = ''}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
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
            if (note.isNotEmpty) ...[const SizedBox(height: 4), Muted(note)],
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: foot),
          ],
        ),
      ),
    );
    final once = ctx.m('forever');
    String owned(String k) => ctx.m('themesOwned', {'n': (ctx.data[k] as List? ?? const []).length});
    return _tabList([
      qgHead(context, LucideIcons.puzzle, ctx.m('addonsTitle'), ctx.m('addonsSub')),
      mGap,
      for (final e in addons.entries)
        () {
          final a = obj(e.value);
          final k = e.key;
          final yearly = a['days'] != null;
          final active = a['active'] == true;
          return card(
            qgAddonIcons[k] ?? LucideIcons.puzzle,
            ctx.m('addonNames.$k'),
            '${fmt(n(a['price']))} ${ctx.m('coins')} ${yearly ? ctx.m('perYear') : '· $once'}',
            ctx.m('addonWhat.$k'),
            note: ctx.t.or('qg.addonFree.$k', ''),
            active
                ? [
                    Chip2(a['expires_at'] != null ? ctx.m('ends', {'date': dkDate(a['expires_at'], ctx.lang)}) : ctx.m('unlocked'), icon: LucideIcons.check, tone: Tone.good),
                    if (yearly) Btn(ctx.m('renewFor', {'coins': fmt(n(a['price']))}), kind: BtnKind.ghost, small: true, onTap: ro ? null : () => ctx.askBuy({'addon': k})),
                  ]
                : [
                    GoldBtn(ctx.m('unlock', {'coins': fmt(n(a['price']))}), onTap: ro ? null : () => ctx.askBuy({'addon': k})),
                  ],
            on: active,
          );
        }(),
      card(
        LucideIcons.fileStack,
        ctx.m('filesName'),
        '${fmt(n(ctx.prices['qr_file_pack']))} ${ctx.m('coins')} / +${n(ctx.files['pack'])} · $once',
        '${ctx.m('filesWhat')} ${ctx.m('fileRoom', {'n': n(ctx.files['count']), 'max': n(ctx.files['capacity'])})}',
        [GoldBtn(ctx.m('buyFiles'), onTap: ro ? null : () => showSheet<void>(context, (_) => BuyFilesSheet(ctx: ctx)))],
      ),
      card(LucideIcons.palette, ctx.m('designsName'), '${fmt(n(ctx.prices['qr_design']))} ${ctx.m('coins')} · $once', ctx.m('designsSub', {'n': qrDesigns.length - 1}), [
        Btn(ctx.m('tabs.designs'), icon: LucideIcons.arrowRight, kind: BtnKind.ghost, small: true, onTap: () => ctx.go('designs')),
      ]),
      card(LucideIcons.printer, ctx.m('printTitle'), '${fmt(n(ctx.prices['qr_print']))} ${ctx.m('coins')} · $once', ctx.m('printSub'), note: owned('prints'), [
        Btn(ctx.m('tabs.print'), icon: LucideIcons.arrowRight, kind: BtnKind.ghost, small: true, onTap: () => ctx.go('print')),
      ]),
      card(LucideIcons.link2, ctx.m('slugTitle'), '${fmt(n(ctx.prices['qr_slug']))} ${ctx.m('coins')} · $once', ctx.m('slugWhat'), note: owned('slugs'), [
        Btn(ctx.m('tabs.codes'), icon: LucideIcons.arrowRight, kind: BtnKind.ghost, small: true, onTap: () => ctx.go('codes')),
      ]),
      card(
        LucideIcons.layoutTemplate,
        ctx.m('themesName'),
        '${fmt(n(ctx.prices['qr_theme']))} ${ctx.m('coins')} · $once',
        ctx.m('themesSub', {'n': pageThemes.length, 'coins': fmt(n(ctx.prices['qr_theme']))}),
        note: owned('themes'),
        [Btn(ctx.m('tabs.codes'), icon: LucideIcons.arrowRight, kind: BtnKind.ghost, small: true, onTap: () => ctx.go('codes'))],
      ),
    ]);
  }
}
