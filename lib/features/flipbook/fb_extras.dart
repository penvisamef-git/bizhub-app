import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../debt/dk_common.dart' show dkDate;
import '../mart/mart_common.dart' show GoldBtn, mGap, todayKH;
import '../mart/mart_kit.dart' show showSheet;
import '../qrgen/qg_inbox.dart' show shareCsv, localTime;
import '../restaurant/rest_common.dart' show Segmented, gap14;
import 'fb_books.dart' show LeadFormSheet;
import 'fb_common.dart';

// FbExtras.jsx + FbMore.jsx: Contacts · Reading stats · Add-ons

// ------------------------------------------------------------------------------------------- where the contact form shows
class _FormPlaces extends StatefulWidget {
  final FbCtx ctx;
  const _FormPlaces({required this.ctx});
  @override
  State<_FormPlaces> createState() => _FormPlacesState();
}

class _FormPlacesState extends State<_FormPlaces> {
  FbCtx get ctx => widget.ctx;
  late Json _f = _start;
  String _busy = '';
  late final _title = TextEditingController(text: str(_f['title']));
  late final _msg = TextEditingController(text: str(_f['message']));

  Json get _start {
    final lf = obj(ctx.settings['lead_form']);
    return {
      'on': lf['on'] == true,
      'ask_email': lf['ask_email'] == true,
      'ask_telegram': lf['ask_telegram'] == true,
      'ask_note': lf['ask_note'] != false,
      'title': str(lf['title']),
      'message': str(lf['message']),
    };
  }

  @override
  void dispose() {
    _title.dispose();
    _msg.dispose();
    super.dispose();
  }

  Future<void> _saveLib(Json next) async {
    setState(() => _busy = 'lib');
    final r = await ctx.run(() => ctx.api.put('${ctx.base}/settings', {'lead_form': next}), ctx.m('saved'));
    if (r != null) ctx.put((_) => {'settings': obj(r['data'])});
    if (mounted) setState(() => _busy = '');
  }

  Future<void> _quick(Json b, bool v) async {
    if (v && !ctx.on('fb_leads')) return ctx.askBuy({'addon': 'fb_leads'});
    setState(() => _busy = str(b['_id']));
    final lf = obj(b['lead_form']);
    final mode = v ? (str(lf['mode']).isNotEmpty && lf['mode'] != 'off' ? lf['mode'] : 'after') : 'off';
    final r = await ctx.run(
      () => ctx.api.put('${ctx.base}/books/${b['_id']}', {
        'lead_form': {...lf, 'mode': mode, 'page': lf['page'] ?? 3},
      }),
    );
    if (r != null) ctx.setBook(obj(r['data']));
    if (mounted) setState(() => _busy = '');
  }

  String _status(Json b) {
    final lf = obj(b['lead_form']);
    if (str(lf['mode']).isEmpty || lf['mode'] == 'off') return ctx.m('lfOff');
    return lf['mode'] == 'before' ? ctx.m('lfBefore') : ctx.m('lfAfterN', {'n': lf['page'] ?? 3});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ro = ctx.readOnly;
    final dirty = '${{..._f, 'title': _title.text, 'message': _msg.text}}' != '$_start';
    return fbPanel([
      Text(ctx.m('formWhere'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
      Muted(ctx.m('formWhereSub')),
      const SizedBox(height: 10),
      Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: c.active,
            child: Icon(LucideIcons.messageCircle, size: 18, color: c.brand),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ctx.m('formLibrary'), style: const TextStyle(fontWeight: FontWeight.w800)),
                Muted(ctx.m('formLibrarySub')),
              ],
            ),
          ),
          Switch(
            value: _f['on'] == true,
            onChanged: ro || _busy == 'lib'
                ? null
                : (v) {
                    if (v && !ctx.on('fb_leads')) return ctx.askBuy({'addon': 'fb_leads'});
                    final next = {..._f, 'on': v, 'title': _title.text, 'message': _msg.text};
                    setState(() => _f = next);
                    _saveLib(next);
                  },
          ),
        ],
      ),
      if (_f['on'] == true) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (k, label) in [('ask_email', ctx.m('lfEmail')), ('ask_telegram', ctx.m('lfTelegram')), ('ask_note', ctx.m('lfNote'))])
              FilterChip(label: Text(label), selected: _f[k] == true, onSelected: (v) => setState(() => _f = {..._f, k: v})),
          ],
        ),
        gap14,
        Field(label: ctx.m('lfTitle'), controller: _title, hint: ctx.m('contactTitlePh'), maxLength: 80, onChanged: (_) => setState(() {})),
        gap14,
        Field(label: ctx.m('lfMessage'), controller: _msg, hint: ctx.m('contactMsgPh'), maxLength: 300, onChanged: (_) => setState(() {})),
        if (dirty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Btn(
              ctx.m('save'),
              icon: LucideIcons.save,
              small: true,
              busy: _busy == 'lib',
              onTap: ro || _busy.isNotEmpty ? null : () => _saveLib({..._f, 'title': _title.text, 'message': _msg.text}),
            ),
          ),
        ],
      ],
      if (ctx.books.isNotEmpty) ...[
        const Divider(height: 24),
        Text(ctx.m('formBooks'), style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        for (final b in ctx.books)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 46,
                  decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(4)),
                  clipBehavior: Clip.antiAlias,
                  child: Image(image: netImage(str(b['cover'])), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        str(b['title']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Muted('${_status(b)}${n(b['leads']) > 0 ? ' · ${ctx.m('contacts', {'n': fmt(n(b['leads']))})}' : ''}'),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: ro ? null : () => showSheet<void>(context, (_) => LeadFormSheet(ctx: ctx, book: b)),
                  child: Text(ctx.m('edit')),
                ),
                Switch(value: str(obj(b['lead_form'])['mode']).isNotEmpty && obj(b['lead_form'])['mode'] != 'off', onChanged: ro || _busy == b['_id'] ? null : (v) => _quick(b, v)),
              ],
            ),
          ),
      ],
    ]);
  }
}

// ------------------------------------------------------------------------------------------- contacts
class LeadsTab extends StatefulWidget {
  final FbCtx ctx;
  const LeadsTab({super.key, required this.ctx});
  @override
  State<LeadsTab> createState() => _LeadsTabState();
}

class _LeadsTabState extends State<LeadsTab> {
  FbCtx get ctx => widget.ctx;
  final _q = TextEditingController();
  String _book = '', _cat = '';
  int _page = 1;
  Json? _res;
  bool _busy = false;
  Timer? _deb;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    _deb?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await ctx.run(() => ctx.api.get('${ctx.base}/leads', {'q': _q.text.trim(), 'book': _book, 'category': _cat, 'page': _page, 'limit': 30}));
    if (r != null && mounted) setState(() => _res = r);
  }

  String _titleOf(Object? bid) =>
      bid == null || bid == '' ? ctx.m('fromLibrary') : (str(ctx.books.where((b) => b['_id'] == bid).firstOrNull?['title']).isEmpty ? '—' : str(ctx.books.firstWhere((b) => b['_id'] == bid)['title']));
  List<String> _cats(Object? ids) => [for (final c in (ids as List? ?? const [])) str(ctx.categories.where((x) => x['_id'] == c).firstOrNull?['name'])].where((x) => x.isNotEmpty).toList();

  Future<void> _excel() async {
    setState(() => _busy = true);
    final r = await ctx.run(() => ctx.api.get('${ctx.base}/leads', {'q': _q.text.trim(), 'book': _book, 'category': _cat, 'all': '1'}));
    if (r != null) {
      await shareCsv('contacts-${todayKH()}.csv', [
        [ctx.m('colDate'), ctx.m('colName'), ctx.m('colPhone'), ctx.m('colEmail'), ctx.m('colTelegram'), ctx.m('colNote'), ctx.m('colCategory'), ctx.m('colBook'), ctx.m('colPage')],
        for (final x in objs(r['data']))
          [
            localTime(x['created_date']),
            x['name'],
            x['phone'],
            x['email'],
            x['telegram'],
            x['note'],
            _cats(x['category_ids']).isEmpty ? ctx.m('noCat') : _cats(x['category_ids']).join(' / '),
            _titleOf(x['book_id']),
            x['page'] ?? '',
          ],
      ]);
    }
    if (mounted) setState(() => _busy = false);
  }

  void _set(VoidCallback f) {
    setState(() {
      f();
      _page = 1;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ro = ctx.readOnly;
    final rows = objs(_res?['data']);
    final pg = _res?['pagination'] != null ? obj(_res!['pagination']) : {'page': 1, 'pages': 1, 'total': 0};
    final counts = obj(_res?['counts']);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          fbHead(
            context,
            LucideIcons.users,
            ctx.m('leadsTitle'),
            ctx.m('leadsSub'),
            actions: [Btn(ctx.m('excel'), icon: LucideIcons.download, kind: BtnKind.ghost, small: true, busy: _busy, onTap: _busy || n(pg['total']) == 0 ? null : _excel)],
          ),
          mGap,
          if (!ctx.on('fb_leads')) ...[NeedAddon(ctx: ctx, addon: 'fb_leads'), mGap],
          _FormPlaces(ctx: ctx),
          mGap,
          if (n(counts['all']) > 0) ...[
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (k, label, cnt) in [
                    ('', ctx.m('allCats'), n(counts['all'])),
                    for (final x in ctx.categories) (str(x['_id']), str(x['name']), n(obj(counts['categories'])[x['_id']])),
                    ('none', ctx.m('noCat'), n(counts['none'])),
                  ])
                    if (k.isEmpty || cnt > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(label: Text('$label ${fmt(cnt)}'), selected: _cat == k, onSelected: (_) => _set(() => _cat = k)),
                      ),
                ],
              ),
            ),
            mGap,
          ],
          fbPanel([
            Field(
              controller: _q,
              hint: ctx.m('leadsSearch'),
              icon: LucideIcons.search,
              onChanged: (_) {
                _deb?.cancel();
                _deb = Timer(const Duration(milliseconds: 300), () => _set(() {}));
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _book,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: [
                DropdownMenuItem(value: '', child: Text(ctx.m('allBooks'))),
                DropdownMenuItem(value: 'library', child: Text(ctx.m('fromLibrary'))),
                for (final b in ctx.books)
                  DropdownMenuItem(
                    value: str(b['_id']),
                    child: Text(str(b['title']), overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => _set(() => _book = v ?? ''),
            ),
            const SizedBox(height: 6),
            Muted(ctx.m('found', {'n': rows.length, 'max': pg['total']})),
          ]),
          mGap,
          if (_res == null)
            const SkelList(rows: 3)
          else if (rows.isEmpty)
            fbPanel([Icon(LucideIcons.clipboardList, size: 28, color: c.muted), const SizedBox(height: 8), Muted(ctx.m('noLeads'), align: TextAlign.center)])
          else ...[
            for (final x in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: fbPanel([
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: str(x['name']),
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              if (str(x['telegram']).isNotEmpty)
                                TextSpan(
                                  text: ' · ${x['telegram']}',
                                  style: TextStyle(color: c.muted),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Text(dkDate(x['created_date'], ctx.lang), style: TextStyle(color: c.muted, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => launchUrl(Uri.parse('tel:${str(x['phone']).replaceAll(RegExp(r'[^+\d]'), '')}')),
                    child: Text(
                      str(x['phone']),
                      style: TextStyle(color: c.brand, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (str(x['email']).isNotEmpty) Muted(str(x['email'])),
                  if (str(x['note']).isNotEmpty) ...[const SizedBox(height: 4), Text(str(x['note']))],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final cn in _cats(x['category_ids'])) Chip2(cn, icon: LucideIcons.folderOpen, tone: Tone.brand),
                            Chip2('${_titleOf(x['book_id'])}${x['page'] != null ? ' · p.${x['page']}' : ''}', icon: LucideIcons.bookOpen),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: ctx.m('delete'),
                        onPressed: ro
                            ? null
                            : () async {
                                if (!await fbConfirm(context, ctx, ctx.m('removeLead'), '${x['name']} · ${x['phone']}')) return;
                                if (await ctx.run(() => ctx.api.delete('${ctx.base}/leads/${x['_id']}')) != null) _load();
                              },
                        icon: Icon(LucideIcons.trash2, size: 17, color: c.danger),
                      ),
                    ],
                  ),
                ]),
              ),
            if (n(pg['pages']) > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Btn(
                    ctx.m('prev'),
                    icon: LucideIcons.chevronLeft,
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: n(pg['page']) <= 1
                        ? null
                        : () {
                            setState(() => _page--);
                            _load();
                          },
                  ),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('${pg['page']} / ${pg['pages']}')),
                  Btn(
                    ctx.m('next'),
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: n(pg['page']) >= n(pg['pages'])
                        ? null
                        : () {
                            setState(() => _page++);
                            _load();
                          },
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------- reading stats
class StatsTab extends StatefulWidget {
  final FbCtx ctx;
  const StatsTab({super.key, required this.ctx});
  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  FbCtx get ctx => widget.ctx;
  int _days = 30;
  String _book = '';
  Json? _st;

  @override
  void initState() {
    super.initState();
    if (ctx.on('fb_stats')) _load();
  }

  Future<void> _load() async {
    setState(() => _st = null);
    final r = await ctx.run(() => ctx.api.get('${ctx.base}/stats', {'days': _days, if (_book.isNotEmpty) 'book': _book}));
    if (r != null && mounted) setState(() => _st = obj(r['data']));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final head = fbHead(context, LucideIcons.chartColumn, ctx.m('statsTitle'), ctx.m('statsSub'));
    if (!ctx.on('fb_stats')) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          head,
          mGap,
          FbLocked(ctx: ctx, addon: 'fb_stats'),
        ],
      );
    }
    final st = _st;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          head,
          mGap,
          fbPanel([
            DropdownButtonFormField<String>(
              initialValue: _book,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: [
                DropdownMenuItem(value: '', child: Text(ctx.m('allBooks'))),
                for (final b in ctx.books)
                  DropdownMenuItem(
                    value: str(b['_id']),
                    child: Text(str(b['title']), overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) {
                setState(() => _book = v ?? '');
                _load();
              },
            ),
            const SizedBox(height: 10),
            Segmented<int>(
              value: _days,
              options: const [(7, '7'), (30, '30'), (90, '90')],
              onChanged: (v) {
                setState(() => _days = v);
                _load();
              },
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
            fbPanel([
              if (n(st['total']) == 0)
                Muted(ctx.m('noStats'))
              else
                SizedBox(
                  height: 130,
                  child: () {
                    final series = objs(st['series']);
                    final max = series.fold<num>(1, (a, x) => n(x['views']) > a ? n(x['views']) : a);
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final d in series)
                          Expanded(
                            child: Tooltip(
                              message: '${d['day']} · ${d['views']}',
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: .8),
                                height: 130 * (n(d['views']) / max).clamp(.02, 1).toDouble(),
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
            fbPanel([
              Text(ctx.m('topBooks'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 6),
              if (objs(st['books']).isEmpty) Muted(ctx.m('noStats')),
              for (final b in objs(st['books']).take(10))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 38,
                        decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(3)),
                        clipBehavior: Clip.antiAlias,
                        child: Image(image: netImage(
                          str(ctx.books.where((x) => x['_id'] == b['_id']).firstOrNull?['cover'])),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(LucideIcons.bookOpen, size: 14, color: c.muted),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(str(b['title']), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Muted(ctx.m('views', {'n': fmt(n(b['views']))})),
                    ],
                  ),
                ),
            ]),
            mGap,
            fbPanel([
              Text(ctx.m('topPages'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 8),
              if (objs(st['pages']).isEmpty) Muted(ctx.m('noStats')),
              () {
                final pages = objs(st['pages']);
                final max = pages.fold<num>(1, (a, x) => n(x['views']) > a ? n(x['views']) : a);
                return Column(
                  children: [
                    for (final p in pages)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          children: [
                            SizedBox(width: 70, child: Text(ctx.m('page', {'n': p['page']}), style: const TextStyle(fontSize: 12.5))),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(value: n(p['views']) / max, minHeight: 8, backgroundColor: c.bg2, color: c.brand),
                              ),
                            ),
                            SizedBox(
                              width: 44,
                              child: Text(
                                fmt(n(p['views'])),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              }(),
            ]),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------- add-ons
class AddonsTab extends StatelessWidget {
  final FbCtx ctx;
  const AddonsTab({super.key, required this.ctx});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ro = ctx.readOnly;
    final l = ctx.limits;
    final room = ctx.room;
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
    final forever = ctx.m('forever');
    final coins = ctx.m('coins');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        fbHead(context, LucideIcons.puzzle, ctx.m('addonsTitle'), ctx.m('addonsSub')),
        mGap,
        for (final e in obj(ctx.data['addons']).entries)
          () {
            final a = obj(e.value);
            final k = e.key;
            final active = a['active'] == true;
            final yearly = a['days'] != null;
            return card(
              fbAddonIcons[k] ?? LucideIcons.puzzle,
              ctx.m('addonNames.$k'),
              '${fmt(n(a['price']))} $coins ${yearly ? ctx.m('perYear') : '· $forever'}',
              ctx.t.or('fb.addonWhat.$k', ''),
              note: ctx.t.or('fb.addonFree.$k', ''),
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
          LucideIcons.bookOpen,
          ctx.m('slotsName'),
          '${fmt(n(ctx.prices['fb_book_slot']))} $coins · $forever',
          '${ctx.m('slotsWhat')} ${ctx.m('room', {'n': room['books'], 'max': room['book_capacity']})}',
          [
            GoldBtn(
              ctx.m('moreBooks'),
              onTap: ro ? null : () => showSheet<void>(context, (_) => BuySlotsSheet(ctx: ctx, kind: 'book')),
            ),
          ],
        ),
        card(
          LucideIcons.hardDrive,
          ctx.m('bigName'),
          '${fmt(n(ctx.prices['fb_big_slot']))} $coins · $forever',
          '${ctx.m('bigWhat', {'mb': n(l['bytes']) ~/ 1048576, 'pages': l['pages'], 'bmb': n(l['big_bytes']) ~/ 1048576, 'bpages': l['big_pages']})} ${ctx.m('bigRoom', {'n': room['big'], 'max': room['big_capacity']})}',
          [
            GoldBtn(
              ctx.m('moreBig'),
              onTap: ro ? null : () => showSheet<void>(context, (_) => BuySlotsSheet(ctx: ctx, kind: 'big')),
            ),
          ],
        ),
        card(LucideIcons.lock, ctx.m('pwName'), '${fmt(n(ctx.prices['fb_password']))} $coins · $forever', ctx.m('pwWhat'), [
          Btn(ctx.m('tabs.books'), icon: LucideIcons.arrowRight, kind: BtnKind.ghost, small: true, onTap: () => ctx.go('books')),
        ]),
        card(LucideIcons.palette, ctx.m('designs'), '${fmt(n(ctx.prices['fb_shelf_theme']))} $coins · $forever', ctx.m('libSub', {'n': 60, 'coins': fmt(n(ctx.prices['fb_shelf_theme']))}), [
          Btn(ctx.m('tabs.library'), icon: LucideIcons.arrowRight, kind: BtnKind.ghost, small: true, onTap: () => ctx.go('library')),
        ]),
        card(LucideIcons.bookOpenText, ctx.m('readers'), '${fmt(n(ctx.prices['fb_reader_theme']))} $coins · $forever', ctx.m('readerSub', {'coins': fmt(n(ctx.prices['fb_reader_theme']))}), [
          Btn(ctx.m('tabs.reader'), icon: LucideIcons.arrowRight, kind: BtnKind.ghost, small: true, onTap: () => ctx.go('reader')),
        ]),
      ],
    );
  }
}
