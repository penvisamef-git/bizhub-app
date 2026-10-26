import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../debt/dk_common.dart' show dkTime;
import '../mart/mart_common.dart' show mGap, todayKH;
import '../mart/mart_kit.dart' show DayField;
import 'qg_common.dart';

// Inbox: answers sent from Form QR codes — QgMore.jsx InboxTab

final _phoneRe = RegExp(r'^[+\d\s().-]{6,}$');
final _mailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final _nameRe = RegExp(r'name|ឈ្មោះ|nom', caseSensitive: false);
const _skipKinds = ['rating', 'photo', 'signature', 'number', 'date', 'checkbox', 'radio', 'select'];
const _colors = [Color(0xFFE0581A), Color(0xFF0D9488), Color(0xFF7C3AED), Color(0xFFDB2777), Color(0xFF2563EB), Color(0xFFCA8A04), Color(0xFF16A34A), Color(0xFFDC2626)];

String valueText(Object? v) => v is List ? v.join(', ') : str(v);
Color _colorOf(String t) => _colors[t.runes.fold<int>(0, (a, c) => a + c) % _colors.length];
bool _isPhone(String v) => _phoneRe.hasMatch(v) && v.replaceAll(RegExp(r'\D'), '').length >= 8;

// who sent it: the "name" answer, or the first text answer
String _whoOf(Json r) {
  final list = objs(r['answers']).where((a) => a['value'] is String && str(a['value']).isNotEmpty && !_skipKinds.contains(a['kind']) && !RegExp(r'^\d+$').hasMatch(str(a['value']))).toList();
  final pick =
      list.where((a) => _nameRe.hasMatch(str(a['label']))).firstOrNull ?? list.where((a) => !_phoneRe.hasMatch(str(a['value'])) && !_mailRe.hasMatch(str(a['value']))).firstOrNull ?? list.firstOrNull;
  return pick == null ? '—' : str(pick['value']);
}

String _phoneOf(Json r) => str(objs(r['answers']).where((a) => a['value'] is String && _isPhone(str(a['value']))).firstOrNull?['value']);
String _mailOf(Json r) => str(objs(r['answers']).where((a) => a['value'] is String && _mailRe.hasMatch(str(a['value']))).firstOrNull?['value']);

String csvCell(Object? v) {
  final s = str(v);
  return RegExp(r'[",\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
}

Future<void> shareCsv(String name, List<List<Object?>> rows) => SharePlus.instance.share(
  ShareParams(
    files: [XFile.fromData(utf8.encode('﻿${rows.map((r) => r.map(csvCell).join(',')).join('\n')}'), name: name, mimeType: 'text/csv')],
  ),
);

String localTime(Object? d) {
  final t = DateTime.tryParse('${d ?? ''}')?.toUtc().add(const Duration(hours: 7));
  if (t == null) return '';
  String p(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${p(t.month)}-${p(t.day)} ${p(t.hour)}:${p(t.minute)}';
}

class InboxTab extends StatefulWidget {
  final QgCtx ctx;
  const InboxTab({super.key, required this.ctx});
  @override
  State<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<InboxTab> {
  QgCtx get ctx => widget.ctx;
  String _code = '', _filter = 'all', _from = '', _to = '', _busy = '';
  int _page = 1;
  Json? _res;
  String? _openId;
  final _q = TextEditingController();
  Timer? _deb;

  List<Json> get _forms => ctx.codes.where((c) => c['type'] == 'form').toList();

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
    try {
      final r = await ctx.api.get('${ctx.base}/replies', {
        'code': _code,
        'unread': _filter == 'unread' ? '1' : '',
        'days': ['1', '7', '30'].contains(_filter) ? _filter : '',
        'from': _filter == 'range' ? _from : '',
        'to': _filter == 'range' ? _to : '',
        'q': _q.text.trim(),
        'page': _page,
        'limit': 25,
      });
      if (mounted) setState(() => _res = r);
    } catch (e) {
      ctx.fail(e);
    }
  }

  void _set(VoidCallback f) {
    setState(() {
      f();
      _page = 1;
    });
    _load();
  }

  String _nameOf(Object? cid) => str(ctx.codes.where((c) => c['_id'] == cid).firstOrNull?['name']).isEmpty ? '—' : str(ctx.codes.firstWhere((c) => c['_id'] == cid)['name']);
  String _whoIs(Json r) {
    final w = _whoOf(r);
    return w == '—' ? _nameOf(r['code_id']) : w;
  }

  String _ago(Object? d) {
    final t = DateTime.tryParse('${d ?? ''}');
    if (t == null) return '';
    final min = DateTime.now().difference(t).inMinutes;
    if (min < 1) return ctx.m('justNow');
    if (min < 60) return ctx.m('minAgo', {'n': min});
    if (min < 60 * 12) return ctx.m('hourAgo', {'n': min ~/ 60});
    return dkTime(d, ctx.lang);
  }

  Future<void> _setRead(Json r, bool read) async {
    setState(() {
      r['read'] = read;
      final s = obj(_res?['summary']);
      if (s.isNotEmpty) s['unread'] = (n(s['unread']) + (read ? -1 : 1)).clamp(0, 1 << 30);
    });
    await ctx.run(() => ctx.api.put('${ctx.base}/replies/${r['_id']}', {'read': read}));
    ctx.reload();
  }

  void _pick(Json r) {
    setState(() => _openId = str(r['_id']));
    if (r['read'] != true && !ctx.readOnly) _setRead(r, true);
  }

  Future<void> _excel() async {
    setState(() => _busy = 'x');
    try {
      final r = await ctx.api.get('${ctx.base}/replies', {'code': _code, 'all': '1'});
      final rows = objs(r['data']);
      final labels = <String>{
        for (final x in rows)
          for (final a in objs(x['answers'])) str(a['label']),
      }.toList();
      await shareCsv('inbox-${todayKH()}.csv', [
        ['Date', 'QR', ...labels],
        for (final x in rows) [localTime(x['created_date']), _nameOf(x['code_id']), for (final l in labels) valueText(objs(x['answers']).where((a) => a['label'] == l).firstOrNull?['value'])],
      ]);
    } catch (e) {
      ctx.fail(e);
    }
    if (mounted) setState(() => _busy = '');
  }

  Future<void> _remove(Json r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(ctx.m('removeReply')),
        content: Text(_whoIs(r)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(ctx.m('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: d.c.danger),
            onPressed: () => Navigator.pop(d, true),
            child: Text(ctx.m('delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await ctx.run(() => ctx.api.delete('${ctx.base}/replies/${r['_id']}'));
    if (res == null) return;
    setState(() => _openId = null);
    _load();
    ctx.reload();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final forms = _forms;
    final head = qgHead(
      context,
      LucideIcons.inbox,
      ctx.m('inboxTitle'),
      ctx.m('inboxSub'),
      actions: [
        Btn(ctx.m('excel'), icon: LucideIcons.download, kind: BtnKind.ghost, small: true, busy: _busy == 'x', onTap: _busy.isNotEmpty || n(obj(_res?['summary'])['total']) == 0 ? null : _excel),
        Btn(
          ctx.m('readAll'),
          icon: LucideIcons.checkCheck,
          kind: BtnKind.ghost,
          small: true,
          onTap: ctx.readOnly || n(obj(_res?['summary'])['unread']) == 0
              ? null
              : () async {
                  await ctx.run(() => ctx.api.put('${ctx.base}/replies-read-all', _code.isEmpty ? {} : {'code': _code}));
                  _load();
                  ctx.reload();
                },
        ),
      ],
    );
    if (!ctx.on('qr_forms') && forms.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          head,
          mGap,
          QgLocked(ctx: ctx, addon: 'qr_forms'),
        ],
      );
    }
    final rows = objs(_res?['data']);
    final open = rows.where((r) => r['_id'] == _openId).firstOrNull;
    if (open != null) return _reading(context, open, rows);
    final pg = _res?['pagination'] != null ? obj(_res!['pagination']) : {'page': 1, 'pages': 1, 'total': 0};
    final sum = _res?['summary'] != null ? obj(_res!['summary']) : {'total': 0, 'unread': 0, 'today': 0, 'week': 0};
    final per = {for (final x in objs(_res?['per_code'])) str(x['code_id']): x};
    Widget tile(String label, Object? v, IconData icon, String f) => Expanded(
      child: Material(
        color: _filter == f ? c.active : c.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _set(() => _filter = f),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              children: [
                Icon(icon, size: 17, color: c.brand),
                const SizedBox(height: 4),
                Text(fmt(n(v)), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final filters = [('all', ctx.m('fAll')), ('unread', ctx.m('fUnread')), ('1', ctx.m('fToday')), ('7', ctx.m('fWeek')), ('30', ctx.m('fMonth')), ('range', ctx.m('fRange'))];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          head,
          mGap,
          if (!ctx.on('qr_forms')) ...[
            qgPanel([NeedLine(ctx: ctx, addon: 'qr_forms')]),
            mGap,
          ],
          Row(
            children: [
              tile(ctx.m('sTotal'), sum['total'], LucideIcons.inbox, 'all'),
              const SizedBox(width: 6),
              tile(ctx.m('sUnread'), sum['unread'], LucideIcons.mail, 'unread'),
              const SizedBox(width: 6),
              tile(ctx.m('sToday'), sum['today'], LucideIcons.clock, '1'),
              const SizedBox(width: 6),
              tile(ctx.m('sWeek'), sum['week'], LucideIcons.calendarDays, '7'),
            ],
          ),
          if (forms.length > 1) ...[
            mGap,
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final f in [
                    {'_id': '', 'name': ctx.m('allForms')},
                    ...forms,
                  ])
                    () {
                      final id = str(f['_id']);
                      final x = id.isEmpty ? {'n': per.values.fold<num>(0, (a, y) => a + n(y['n'])), 'unread': per.values.fold<num>(0, (a, y) => a + n(y['unread']))} : (per[id] ?? {});
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          selected: _code == id,
                          onSelected: (_) => _set(() {
                            _code = id;
                            _openId = null;
                          }),
                          label: Text('${f['name']} · ${fmt(n(x['n']))}${n(x['unread']) > 0 ? ' (${n(x['unread'])})' : ''}'),
                        ),
                      );
                    }(),
                ],
              ),
            ),
          ],
          mGap,
          qgPanel([
            Field(
              controller: _q,
              hint: ctx.m('searchReplies'),
              icon: LucideIcons.search,
              onChanged: (_) {
                _deb?.cancel();
                _deb = Timer(const Duration(milliseconds: 300), () => _set(() {}));
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final (k, l) in filters) ChoiceChip(label: Text(l), selected: _filter == k, onSelected: (_) => _set(() => _filter = k))],
            ),
            if (_filter == 'range') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DayField(label: ctx.m('fromDate'), value: _from, onChanged: (v) => _set(() => _from = v)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DayField(label: ctx.m('toDate'), value: _to, onChanged: (v) => _set(() => _to = v)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            if (_res == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    Icon(LucideIcons.inbox, size: 30, color: c.muted),
                    const SizedBox(height: 8),
                    Muted(ctx.m('noReplies'), align: TextAlign.center),
                  ],
                ),
              )
            else
              for (final r in rows) _row(context, r),
            if (n(pg['pages']) > 1)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Btn(
                      ctx.m('prev'),
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
              ),
          ]),
        ],
      ),
    );
  }

  Widget _avatar(String who, double size) => CircleAvatar(
    radius: size / 2,
    backgroundColor: _colorOf(who),
    child: Text(
      who.isEmpty ? '?' : who.characters.first.toUpperCase(),
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * .42),
    ),
  );

  Widget _row(BuildContext context, Json r) {
    final c = context.c;
    final who = _whoIs(r);
    final rest = objs(r['answers'])
        .where((a) => valueText(a['value']).isNotEmpty && valueText(a['value']) != who)
        .map(
          (a) => switch (a['kind']) {
            'photo' => '📷',
            'signature' => '✍️',
            'rating' => '★' * (int.tryParse(str(a['value'])) ?? 0),
            _ => valueText(a['value']),
          },
        )
        .join(' · ');
    final unread = r['read'] != true;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _pick(r),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(who, 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          who,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: unread ? FontWeight.w900 : FontWeight.w600),
                        ),
                      ),
                      Text(_ago(r['created_date']), style: TextStyle(color: c.muted, fontSize: 12)),
                    ],
                  ),
                  Text(
                    rest.isEmpty ? '—' : rest,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: unread ? c.ink : c.muted, fontSize: 13),
                  ),
                  if (_code.isEmpty)
                    Text(
                      _nameOf(r['code_id']),
                      style: TextStyle(color: c.brand, fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                ],
              ),
            ),
            if (unread)
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 6),
                child: CircleAvatar(radius: 4, backgroundColor: c.brand),
              ),
          ],
        ),
      ),
    );
  }

  Widget _reading(BuildContext context, Json open, List<Json> rows) {
    final c = context.c;
    final who = _whoIs(open);
    final tel = _phoneOf(open), mail = _mailOf(open);
    final idx = rows.indexOf(open);
    void go(String u) => launchUrl(Uri.parse(u));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        qgPanel([
          Row(
            children: [
              RoundBtn(LucideIcons.arrowLeft, size: 38, onTap: () => setState(() => _openId = null)),
              const SizedBox(width: 10),
              _avatar(who, 46),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(who, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    Text.rich(
                      TextSpan(
                        style: TextStyle(color: c.muted, fontSize: 12.5),
                        children: [
                          TextSpan(text: '${ctx.m('sentFrom')} '),
                          TextSpan(
                            text: _nameOf(open['code_id']),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          TextSpan(text: ' · ${dkTime(open['created_date'], ctx.lang)}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(tooltip: ctx.m('newer'), onPressed: idx <= 0 ? null : () => _pick(rows[idx - 1]), icon: const Icon(LucideIcons.chevronUp, size: 18)),
              IconButton(tooltip: ctx.m('older'), onPressed: idx < 0 || idx >= rows.length - 1 ? null : () => _pick(rows[idx + 1]), icon: const Icon(LucideIcons.chevronDown, size: 18)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (tel.isNotEmpty) Btn(ctx.m('callNow'), icon: LucideIcons.phone, small: true, onTap: () => go('tel:${tel.replaceAll(RegExp(r'[^+\d]'), '')}')),
              if (mail.isNotEmpty) Btn(ctx.m('emailNow'), icon: LucideIcons.mail, kind: BtnKind.ghost, small: true, onTap: () => go('mailto:$mail')),
              Btn(
                ctx.m('copyAll'),
                icon: LucideIcons.copy,
                kind: BtnKind.ghost,
                small: true,
                onTap: () async {
                  final txt = [
                    '${_nameOf(open['code_id'])} · ${dkTime(open['created_date'], ctx.lang)}',
                    for (final a in objs(open['answers']))
                      if (valueText(a['value']).isNotEmpty) '${a['label']}: ${valueText(a['value'])}',
                  ].join('\n');
                  await Clipboard.setData(ClipboardData(text: txt));
                  ctx.notify(ctx.m('copied'));
                },
              ),
              Btn(
                open['read'] == true ? ctx.m('markUnread') : ctx.m('markRead'),
                icon: LucideIcons.check,
                kind: BtnKind.ghost,
                small: true,
                onTap: ctx.readOnly ? null : () => _setRead(open, open['read'] != true),
              ),
              RoundBtn(LucideIcons.trash2, size: 38, tip: ctx.m('delete'), fg: c.danger, onTap: ctx.readOnly ? null : () => _remove(open)),
            ],
          ),
        ]),
        mGap,
        qgPanel([
          for (final a in objs(open['answers'])) ...[
            Text(
              str(a['label']),
              style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            _value(context, a),
            const SizedBox(height: 12),
          ],
        ]),
      ],
    );
  }

  Widget _value(BuildContext context, Json a) {
    final c = context.c;
    final v = valueText(a['value']);
    Widget chip(String x) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(99)),
      child: Text(
        x,
        style: TextStyle(color: c.brandInk, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
    if (v.isEmpty) return Text('—', style: TextStyle(color: c.muted));
    switch (a['kind']) {
      case 'photo' || 'signature':
        return Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: () => launchUrl(Uri.parse(v), mode: LaunchMode.externalApplication),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 260),
              decoration: BoxDecoration(
                color: a['kind'] == 'signature' ? Colors.white : c.bg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image(image: netImage(
                v),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Padding(padding: EdgeInsets.all(16), child: Icon(LucideIcons.imageOff)),
              ),
            ),
          ),
        );
      case 'rating':
        final k = (int.tryParse(v) ?? 0).clamp(0, 5);
        return Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 20, letterSpacing: 2),
            children: [
              TextSpan(
                text: '★' * k,
                style: const TextStyle(color: Color(0xFFF59E0B)),
              ),
              TextSpan(
                text: '★' * (5 - k),
                style: TextStyle(color: c.line),
              ),
            ],
          ),
        );
      case 'checkbox':
        return Wrap(spacing: 6, runSpacing: 6, children: [for (final x in v.split(', ')) chip(x)]);
    }
    if (a['value'] is List) return Wrap(spacing: 6, runSpacing: 6, children: [for (final x in a['value'] as List) chip('$x')]);
    if (_isPhone(v) || _mailRe.hasMatch(v)) {
      return InkWell(
        onTap: () => launchUrl(Uri.parse(_isPhone(v) ? 'tel:${v.replaceAll(RegExp(r'[^+\d]'), '')}' : 'mailto:$v')),
        child: Text(
          v,
          style: TextStyle(color: c.brand, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      );
    }
    return SelectableText(v, style: const TextStyle(fontSize: 15, height: 1.45));
  }
}
