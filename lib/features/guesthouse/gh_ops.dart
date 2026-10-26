import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show MHead, GoldBtn, SureDelete, Tiles, mGap, mDate, mDayTime, todayKH, addDaysKH;
import '../mart/mart_kit.dart' show MSheet, showSheet, DayField, decimalKeys, numOf;
import '../restaurant/rest_common.dart' show SwitchRow, gap14;
import '../restaurant/rest_online.dart' show shareWidgets;
import 'gh_common.dart';
import 'gh_setup.dart' show GhSave;
import 'gh_stay.dart';

// Foreign guests (gh_police), Housekeeping (gh_housekeeping), Booking.com / Agoda (gh_ical), Monthly rent (gh_longstay)
// — GhExtras.jsx PoliceTab, GhOps.jsx HousekeepingTab, GhOta.jsx, GhLease.jsx.

Widget _panel(List<Widget> children, {EdgeInsets padding = const EdgeInsets.all(16)}) => Panel(
  padding: padding,
  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
);

// the head of an add-on section: icon · title · line + unlock / renew (+ an extra button when on)
class GhHero extends StatelessWidget {
  final GhCtx ctx;
  final String addon, title, sub;
  final IconData icon;
  final bool yearly;
  final Widget? extra;
  const GhHero({super.key, required this.ctx, required this.addon, required this.icon, required this.title, required this.sub, this.yearly = false, this.extra});
  @override
  Widget build(BuildContext context) {
    final a = ctx.addon(addon);
    final on = a['active'] == true;
    final x = ctx.t;
    final buy = !on || (yearly && a['status'] == 'expiring');
    final price = fmt(n(a['price']));
    return _panel([
      MHead(title, icon: icon, sub: sub),
      if (extra != null || buy)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ?extra,
            if (buy) GoldBtn(on ? x('gx.renew') : (yearly ? x('gx.unlockYear', {'coins': price}) : x('gx.unlock', {'coins': price})), onTap: ctx.readOnly ? null : () => ctx.askBuy(addon)),
          ],
        ),
    ]);
  }
}

// what a locked add-on does + its perks
class GhPerks extends StatelessWidget {
  final GhCtx ctx;
  final String addon;
  const GhPerks({super.key, required this.ctx, required this.addon});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _panel([
      Muted(ctx.g('addonInfo.$addon.what')),
      const SizedBox(height: 10),
      for (final p in ctx.t.list('gh.addonInfo.$addon.perks'))
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.circleCheck, size: 15, color: c.good),
              const SizedBox(width: 8),
              Expanded(child: Text(p)),
            ],
          ),
        ),
    ]);
  }
}

String _x(GhCtx ctx, String k, [Map<String, Object?> v = const {}]) => ctx.t('gx.$k', v);

// ------------------------------------------------------------------------------------------------ FOREIGN GUESTS
class PoliceTab extends StatefulWidget {
  final GhCtx ctx;
  const PoliceTab({super.key, required this.ctx});
  @override
  State<PoliceTab> createState() => _PoliceTabState();
}

class _PoliceTabState extends State<PoliceTab> {
  late String _from = todayKH(), _to = todayKH();
  bool _all = false, _sharing = false;
  Json? _rep;
  final _sheet = GlobalKey();
  GhCtx get ctx => widget.ctx;
  bool get _on => ctx.addonOn('gh_police');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_on) return;
    setState(() => _rep = null);
    try {
      final r = await ctx.api.get('${ctx.base}/police', {'from': _from, 'to': _to, 'all': _all ? '1' : ''});
      if (mounted) setState(() => _rep = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  String _gender(Json g) => str(g['gender']).isEmpty ? '' : ctx.g('genders.${g['gender']}');

  Future<void> _csv() async {
    final rows = objs(_rep!['rows']);
    String cell(Object? v) {
      final s = '${v ?? ''}';
      return RegExp(r'[",\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
    }

    final head = [
      for (final k in ['poNo', 'poName', 'poGender', 'poDob', 'poNat', 'poDoc', 'poVisa']) _x(ctx, k),
      ctx.g('visaUntil'),
      _x(ctx, 'poRoom'),
      _x(ctx, 'poIn'),
      _x(ctx, 'poOut'),
      _x(ctx, 'poPhone'),
    ];
    final lines = [
      for (final (i, r) in rows.indexed)
        () {
          final g = obj(r['guest']);
          return [i + 1, g['name'], _gender(g), g['dob'], g['nationality'], g['id_number'], g['visa_type'], g['visa_until'], r['room'], r['from'], r['to'], g['phone']];
        }(),
    ];
    final csv = '﻿${[head, ...lines].map((l) => l.map(cell).join(',')).join('\r\n')}';
    setState(() => _sharing = true);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(utf8.encode(csv), mimeType: 'text/csv', name: 'foreign-guests-${_rep!['from']}${_rep!['to'] != _rep!['from'] ? '_${_rep!['to']}' : ''}.csv')],
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  // the A4 list for the police, shared as a picture
  Future<void> _print() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (s) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: RepaintBoundary(
                  key: _sheet,
                  child: _PoliceSheet(ctx: ctx, rep: _rep!),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Btn(ctx.t('app.share'), icon: LucideIcons.share2, expand: true, onTap: () => shareWidgets([_sheet], (_) => 'foreign-guests-${_rep!['from']}.png')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a = ctx.addon('gh_police');
    final hero = GhHero(ctx: ctx, addon: 'gh_police', icon: LucideIcons.shieldCheck, title: _x(ctx, 'poTitle'), sub: _on ? _x(ctx, 'poSub') : _x(ctx, 'poOff', {'price': fmt(n(a['price']))}));
    if (!_on) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          hero,
          mGap,
          GhPerks(ctx: ctx, addon: 'gh_police'),
        ],
      );
    }
    final today = todayKH();
    final rep = _rep;
    final rows = rep == null ? <Json>[] : objs(rep['rows']);
    final countries = rep == null ? <MapEntry<String, dynamic>>[] : (obj(rep['countries']).entries.toList()..sort((x, y) => n(y.value).compareTo(n(x.value))));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          hero,
          mGap,
          _panel([
            Wrap(
              spacing: 6,
              children: [
                for (final (label, d) in [(_x(ctx, 'today'), today), (_x(ctx, 'yesterday'), addDaysKH(today, -1))])
                  ChoiceChip(
                    label: Text(label),
                    selected: _from == d && _to == d,
                    onSelected: (_) {
                      _from = d;
                      _to = d;
                      _load();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DayField(
                    label: _x(ctx, 'poFrom'),
                    value: _from,
                    last: DateTime.parse(today),
                    onChanged: (v) {
                      if (v.isEmpty) return;
                      _from = v;
                      if (_to.compareTo(v) < 0) _to = v;
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DayField(
                    label: _x(ctx, 'poTo'),
                    value: _to,
                    first: DateTime.parse(_from),
                    last: DateTime.parse(addDaysKH(_from, 92)),
                    onChanged: (v) {
                      if (v.isEmpty) return;
                      _to = v;
                      _load();
                    },
                  ),
                ),
              ],
            ),
            SwitchRow(
              title: _x(ctx, 'onlyForeign'),
              value: !_all,
              onChanged: (v) {
                _all = !v;
                _load();
              },
            ),
            Row(
              children: [
                Expanded(
                  child: Btn(_x(ctx, 'download'), icon: LucideIcons.download, kind: BtnKind.ghost, small: true, expand: true, busy: _sharing, onTap: rows.isEmpty || _sharing ? null : _csv),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Btn(_x(ctx, 'print'), icon: LucideIcons.printer, small: true, expand: true, onTap: rows.isEmpty ? null : _print),
                ),
              ],
            ),
          ]),
          mGap,
          if (rep == null)
            const SkelList(rows: 4)
          else if (rows.isEmpty)
            _panel([Icon(LucideIcons.shieldCheck, size: 40, color: c.muted), const SizedBox(height: 8), Muted(_x(ctx, 'poNone'), align: TextAlign.center)])
          else
            _panel([
              Text(_x(ctx, 'poCount', {'n': n(rep['foreign'])}), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final e in countries) Chip2('${e.key} · ${n(e.value)}')]),
              if (n(rep['missing']) > 0) ...[
                const SizedBox(height: 10),
                Alert(_x(ctx, 'poMissing', {'n': n(rep['missing'])}), tone: Tone.warn),
              ],
              const SizedBox(height: 6),
              for (final r in rows)
                () {
                  final g = obj(r['guest']);
                  final miss = (r['missing'] as List? ?? const []).map((e) => '$e').toSet();
                  Widget field(String label, String v, String key) => Padding(
                    padding: const EdgeInsets.only(right: 14, top: 2),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$label: ',
                            style: TextStyle(color: c.muted),
                          ),
                          v.isNotEmpty
                              ? TextSpan(
                                  text: v,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                )
                              : TextSpan(
                                  text: miss.contains(key) ? _x(ctx, 'missing') : '—',
                                  style: TextStyle(color: miss.contains(key) ? c.danger : c.muted, fontWeight: FontWeight.w700),
                                ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  );
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => openStay(context, ctx, str(r['_id']), onChanged: _load),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: c.line)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text('${str(g['name'])}${r['foreign'] == false ? '  🇰🇭' : ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                              ),
                              Chip2('${ctx.g('room')} ${str(r['room'])}'),
                            ],
                          ),
                          Text('${ghDay(str(r['from']), ctx.lang)} → ${ghDay(str(r['to']), ctx.lang)}', style: TextStyle(color: c.muted, fontSize: 12.5)),
                          Wrap(
                            children: [
                              field(_x(ctx, 'poNat'), str(g['nationality']), 'nationality'),
                              field(_x(ctx, 'poDoc'), str(g['id_number']), 'id_number'),
                              field(_x(ctx, 'poGender'), _gender(g), 'gender'),
                              field(_x(ctx, 'poDob'), str(g['dob']), 'dob'),
                              if (str(g['visa_type']).isNotEmpty || str(g['visa_until']).isNotEmpty)
                                field(
                                  _x(ctx, 'poVisa'),
                                  [str(g['visa_type']), if (str(g['visa_until']).isNotEmpty) ghDay(str(g['visa_until']), ctx.lang)].where((x) => x.isNotEmpty).join(' · '),
                                  'visa',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }(),
            ]),
        ],
      ),
    );
  }
}

class _PoliceSheet extends StatelessWidget {
  final GhCtx ctx;
  final Json rep;
  const _PoliceSheet({required this.ctx, required this.rep});
  @override
  Widget build(BuildContext context) {
    final b = ctx.business;
    const ink = TextStyle(color: Colors.black, fontSize: 11, fontFamily: 'KantumruyPro');
    final bold = ink.copyWith(fontWeight: FontWeight.w800);
    final rows = objs(rep['rows']);
    Widget cell(String s, {bool head = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: Text(s, style: head ? bold : ink),
    );
    return Container(
      width: 820,
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(str(b['name']), style: bold.copyWith(fontSize: 15)),
                    Text([str(b['address']), str(b['phone'])].where((x) => x.isNotEmpty).join(' · '), style: ink),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_x(ctx, 'poPrintTitle'), style: bold.copyWith(fontSize: 14)),
                  Text(_x(ctx, 'poPrintDays', {'from': ghDay(str(rep['from']), ctx.lang, year: true), 'to': ghDay(str(rep['to']), ctx.lang, year: true)}), style: ink),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Table(
            border: TableBorder.all(color: Colors.black54, width: .6),
            defaultColumnWidth: const IntrinsicColumnWidth(),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFEEEEEE)),
                children: [
                  for (final k in ['poNo', 'poName', 'poGender', 'poDob', 'poNat', 'poDoc', 'poVisa', 'poRoom', 'poIn', 'poOut']) cell(_x(ctx, k), head: true),
                ],
              ),
              for (final (i, r) in rows.indexed)
                () {
                  final g = obj(r['guest']);
                  return TableRow(
                    children: [
                      cell('${i + 1}'),
                      cell(str(g['name'])),
                      cell(str(g['gender']).isEmpty ? '' : ctx.g('genders.${g['gender']}')),
                      cell(str(g['dob'])),
                      cell(str(g['nationality'])),
                      cell(str(g['id_number'])),
                      cell([str(g['visa_type']), str(g['visa_until'])].where((x) => x.isNotEmpty).join(' · ')),
                      cell(str(r['room'])),
                      cell(str(r['from'])),
                      cell(str(r['to'])),
                    ],
                  );
                }(),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Text(_x(ctx, 'poCount', {'n': n(rep['foreign'])}), style: bold)),
              Text(_x(ctx, 'poSign'), style: ink),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ HOUSEKEEPING
const _next = {'dirty': ('cleaning', 'hkStart'), 'cleaning': ('ready', 'hkDone'), 'ready': ('dirty', 'hkDirty')};

class HousekeepingTab extends StatefulWidget {
  final GhCtx ctx;
  const HousekeepingTab({super.key, required this.ctx});
  @override
  State<HousekeepingTab> createState() => _HousekeepingTabState();
}

class _HousekeepingTabState extends State<HousekeepingTab> {
  Json? _d;
  String _filter = 'all', _busy = '';
  Timer? _tick;
  GhCtx get ctx => widget.ctx;
  bool get _on => ctx.addonOn('gh_housekeeping');

  @override
  void initState() {
    super.initState();
    if (_on) {
      _load();
      _tick = Timer.periodic(const Duration(seconds: 30), (_) => _load());
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/housekeeping');
      if (mounted) setState(() => _d = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _set(Json r, String state) async {
    setState(() => _busy = str(r['_id']));
    try {
      final res = await ctx.api.put('${ctx.base}/rooms/${r['_id']}/hk', {'state': state});
      final upd = obj(res['data']);
      final d = _d!;
      final counts = Map<String, dynamic>.from(obj(d['counts']));
      counts[str(r['hk'])] = n(counts[str(r['hk'])]) - 1;
      counts[state] = n(counts[state]) + 1;
      if (mounted) {
        setState(
          () => _d = {
            ...d,
            'counts': counts,
            'rooms': [
              for (final x in objs(d['rooms']))
                if (x['_id'] == r['_id']) {...x, ...upd, 'hk': upd['hk'] ?? state} else x,
            ],
          },
        );
      }
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a = ctx.addon('gh_housekeeping');
    final hero = GhHero(ctx: ctx, addon: 'gh_housekeeping', icon: LucideIcons.sparkles, title: _x(ctx, 'hkTitle'), sub: _on ? _x(ctx, 'hkSub') : _x(ctx, 'hkOff', {'price': fmt(n(a['price']))}));
    if (!_on) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          hero,
          mGap,
          GhPerks(ctx: ctx, addon: 'gh_housekeeping'),
        ],
      );
    }
    final d = _d;
    if (d == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 4));
    final all = objs(d['rooms']);
    final counts = obj(d['counts']);
    final rooms = all.where((r) => _filter == 'all' || r['hk'] == _filter).toList();
    Color tone(String k) => switch (k) {
      'dirty' => c.danger,
      'cleaning' => c.warn,
      _ => c.good,
    };
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          hero,
          mGap,
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final k in ['all', 'dirty', 'cleaning', 'ready']) ...[
                  ChoiceChip(
                    avatar: k == 'all' ? null : CircleAvatar(radius: 5, backgroundColor: tone(k)),
                    label: Text('${k == 'all' ? _x(ctx, 'hkAll') : _x(ctx, 'hk.$k')} ${k == 'all' ? all.length : n(counts[k])}'),
                    selected: _filter == k,
                    onSelected: (_) => setState(() => _filter = k),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (rooms.isEmpty)
            _panel([Icon(LucideIcons.sparkles, size: 36, color: c.muted), const SizedBox(height: 8), Muted(_x(ctx, 'hkNone'), align: TextAlign.center)])
          else
            LayoutBuilder(
              builder: (_, box) {
                final cols = box.maxWidth > 560 ? 3 : 2;
                final w = (box.maxWidth - 10 * (cols - 1)) / cols;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final r in rooms)
                      SizedBox(
                        width: w,
                        child: () {
                          final hk = str(r['hk']).isEmpty ? 'ready' : str(r['hk']);
                          final (next, label) = _next[hk]!;
                          final col = tone(hk);
                          final guest = str(r['guest']);
                          final who = r['leaving'] == true
                              ? _x(ctx, 'hkLeaving')
                              : guest == 'in'
                              ? _x(ctx, 'hkIn')
                              : guest == 'arriving'
                              ? _x(ctx, 'hkArriving')
                              : _x(ctx, 'hkEmpty');
                          return Container(
                            padding: const EdgeInsets.fromLTRB(12, 15, 12, 12),
                            // one colour per border (mixed colours + rounded corners drew nothing), the strip on top
                            decoration: BoxDecoration(
                              color: col.withValues(alpha: .07),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: col.withValues(alpha: .25)),
                            ),
                            foregroundDecoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border(top: BorderSide(color: col, width: 4)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(str(r['name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                                    ),
                                    Text(
                                      _x(ctx, 'hk.$hk'),
                                      style: TextStyle(color: col, fontWeight: FontWeight.w800, fontSize: 12),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${str(r['type'])}${str(r['floor']).isNotEmpty ? ' · ${r['floor']}' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: c.muted, fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$who${r['stay'] != null && guest != 'empty' ? ' · ${str(obj(r['stay'])['name'])}' : ''}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                                if (r['hk_at'] != null)
                                  Text(
                                    _x(ctx, 'hkBy', {'who': str(r['hk_by']).isEmpty ? '—' : r['hk_by'], 'time': mDayTime(r['hk_at'], ctx.lang)}),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: c.muted, fontSize: 11.5),
                                  ),
                                const SizedBox(height: 10),
                                Btn(
                                  _x(ctx, label),
                                  small: true,
                                  expand: true,
                                  kind: next == 'dirty' ? BtnKind.ghost : BtnKind.primary,
                                  busy: _busy == r['_id'],
                                  onTap: ctx.readOnly || _busy == r['_id'] ? null : () => _set(r, next),
                                ),
                              ],
                            ),
                          );
                        }(),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 14),
          Muted(_x(ctx, 'hkStaffHint')),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ BOOKING.COM / AGODA
const _logo = {'booking_com': ('B.', Color(0xFF003580)), 'agoda': ('a', Color(0xFFE2382F)), 'airbnb': ('✿', Color(0xFFFF5A5F)), 'expedia': ('E', Color(0xFFFBCC33)), 'other': ('⇄', Color(0xFF64748B))};

Widget _otaLogo(String k, {double size = 28}) {
  final (t, col) = _logo[k] ?? _logo['other']!;
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(8)),
    child: Text(
      t,
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * .5),
    ),
  );
}

class OtaTab extends StatefulWidget {
  final GhCtx ctx;
  const OtaTab({super.key, required this.ctx});
  @override
  State<OtaTab> createState() => _OtaTabState();
}

class _OtaTabState extends State<OtaTab> {
  Json? _d;
  bool _syncing = false;
  String _adding = '', _source = 'booking_com';
  bool _addBusy = false;
  String _addError = '';
  final _url = TextEditingController();
  GhCtx get ctx => widget.ctx;
  bool get _on => ctx.addonOn('gh_ical');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(OtaTab old) {
    super.didUpdateWidget(old);
    if (!identical(old.ctx.data, ctx.data)) _load();
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/ical');
      if (mounted) setState(() => _d = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  String _synced(Json r) => _x(ctx, 'otSynced', {'a': n(r['added']), 'u': n(r['updated']), 'r': n(r['removed'])});

  Future<void> _sync() async {
    setState(() => _syncing = true);
    try {
      final r = await ctx.api.post('${ctx.base}/ical/sync');
      ctx.notify(_synced(obj(r['data'])));
      _load();
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _add(Json room) async {
    setState(() {
      _addBusy = true;
      _addError = '';
    });
    try {
      final r = await ctx.api.post('${ctx.base}/ical/feeds', {'room_id': room['_id'], 'source': _source, 'url': _url.text.trim()});
      final feed = obj(r['data']);
      ctx.notify(str(feed['last_error']).isNotEmpty ? _x(ctx, 'otError', {'err': feed['last_error']}) : _synced(obj(r['result'])));
      setState(() {
        _adding = '';
        _url.clear();
      });
      _load();
      ctx.reload();
    } on ApiError catch (e) {
      if (e.status == 402) {
        ctx.askBuy('gh_ical');
      } else if (mounted) {
        setState(() => _addError = e.message);
      }
    } finally {
      if (mounted) setState(() => _addBusy = false);
    }
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    ctx.notify(_x(ctx, 'otCopied'));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a = ctx.addon('gh_ical');
    final hero = GhHero(
      ctx: ctx,
      addon: 'gh_ical',
      yearly: true,
      icon: LucideIcons.calendarSync,
      title: _x(ctx, 'otTitle'),
      sub: _on ? _x(ctx, 'otSub') : _x(ctx, 'otOff', {'price': fmt(n(a['price']))}),
      extra: _on ? Btn(_syncing ? _x(ctx, 'otSyncing') : _x(ctx, 'otSyncNow'), icon: LucideIcons.refreshCw, small: true, busy: _syncing, onTap: ctx.readOnly || _syncing ? null : _sync) : null,
    );
    final d = _d;
    if (d == null) return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [hero, mGap, const SkelList(rows: 4)]);
    final rooms = objs(d['rooms']);
    final sources = (d['sources'] as List? ?? const ['booking_com', 'agoda', 'airbnb', 'expedia', 'other']).map((e) => '$e').toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          hero,
          if (!_on) ...[mGap, GhPerks(ctx: ctx, addon: 'gh_ical')],
          mGap,
          _panel([
            Text(_x(ctx, 'otHow'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            const SizedBox(height: 8),
            for (final (i, k) in ['otStep1', 'otStep2', 'otStep3'].indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: c.active,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: c.brandInk),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_x(ctx, k), style: const TextStyle(height: 1.4))),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Muted('🔒 ${_x(ctx, 'otPrivacy')}'),
          ]),
          if (rooms.isEmpty) ...[mGap, Muted(_x(ctx, 'otNoRooms'))],
          for (final r in rooms) ...[
            mGap,
            _panel([
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: hexColor(str(r['color']), const Color(0xFF2563EB)).withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.bedDouble, size: 15, color: hexColor(str(r['color']), const Color(0xFF2563EB))),
                        const SizedBox(width: 6),
                        Text(str(r['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Muted(str(r['type']))),
                ],
              ),
              const SizedBox(height: 12),
              Label(_x(ctx, 'otExport')),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _on ? str(r['export_url']) : str(r['export_url']).replaceAll(RegExp(r'[^/]{6}\.ics$'), '••••••.ics'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: _on ? c.ink : c.muted),
                      ),
                    ),
                    TextButton.icon(onPressed: _on ? () => _copy(str(r['export_url'])) : null, icon: const Icon(LucideIcons.copy, size: 14), label: Text(_x(ctx, 'otCopy'))),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Label(_x(ctx, 'otImport')),
              for (final f in objs(r['feeds']))
                () {
                  final bad = str(f['last_error']).isNotEmpty;
                  final conflicts = objs(f['conflicts']);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: bad
                          ? c.dangerBg
                          : conflicts.isNotEmpty
                          ? c.warnBg
                          : c.bg2,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _otaLogo(str(f['source'])),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(str(f['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                                  ),
                                  if (f['active'] == false) ...[const SizedBox(width: 6), Chip2(_x(ctx, 'otPaused'))],
                                ],
                              ),
                              Text(
                                str(f['url']),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: c.muted, fontSize: 11.5),
                              ),
                              if (bad)
                                Text(
                                  '⚠ ${_x(ctx, 'otError', {'err': f['last_error']})}',
                                  style: TextStyle(color: c.danger, fontSize: 12, fontWeight: FontWeight.w600),
                                )
                              else
                                Text(
                                  f['last_ok_at'] != null ? '✓ ${_x(ctx, 'otLast', {'time': mDayTime(f['last_ok_at'], ctx.lang), 'n': n(f['last_count'])})}' : _x(ctx, 'otNever'),
                                  style: TextStyle(color: f['last_ok_at'] != null ? c.good : c.muted, fontSize: 12),
                                ),
                              for (final cf in conflicts)
                                Text(
                                  '⚠ ${_x(ctx, 'otConflict', {'from': ghDay(str(cf['from']), ctx.lang), 'to': ghDay(str(cf['to']), ctx.lang), 'no': cf['with_no']})}',
                                  style: TextStyle(color: c.warn, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                        ),
                        if (!ctx.readOnly)
                          SureDelete(
                            remove: _x(ctx, 'otRemove'),
                            sure: _x(ctx, 'otRemoveSure'),
                            onDelete: () async {
                              if (await ctx.run(() => ctx.api.delete('${ctx.base}/ical/feeds/${f['_id']}')) != null) _load();
                            },
                          ),
                      ],
                    ),
                  );
                }(),
              if (_adding == r['_id'])
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final k in sources)
                            ChoiceChip(avatar: _otaLogo(k, size: 20), label: Text(ctx.t.or('gh.sources.$k', 'Other')), selected: _source == k, onSelected: (_) => setState(() => _source = k)),
                        ],
                      ),
                      gap14,
                      Field(controller: _url, hint: _x(ctx, 'otUrlPh'), keyboard: TextInputType.url, autofocus: true, onChanged: (_) => setState(() {})),
                      if (_addError.isNotEmpty) ...[const SizedBox(height: 8), Alert(_addError)],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Btn(ctx.g('cancel'), kind: BtnKind.ghost, small: true, onTap: () => setState(() => _adding = '')),
                          const Spacer(),
                          Btn(_x(ctx, 'otAdd'), icon: LucideIcons.plus, small: true, busy: _addBusy, onTap: _addBusy || _url.text.trim().isEmpty ? null : () => _add(r)),
                        ],
                      ),
                    ],
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: ctx.readOnly
                        ? null
                        : () => _on
                              ? setState(() {
                                  _adding = str(r['_id']);
                                  _addError = '';
                                  _url.clear();
                                })
                              : ctx.askBuy('gh_ical'),
                    icon: const Icon(LucideIcons.link2, size: 15),
                    label: Text(_x(ctx, 'otAdd')),
                  ),
                ),
            ]),
          ],
          if (_on && rooms.isNotEmpty) ...[
            mGap,
            Row(
              children: [
                Expanded(child: Muted(a['expires_at'] != null ? ctx.g('endsOn', {'date': mDate(a['expires_at'], ctx.lang)}) : '')),
                if (!ctx.readOnly)
                  SureDelete(
                    remove: _x(ctx, 'otNewLinks'),
                    sure: _x(ctx, 'otNewLinksSure'),
                    onDelete: () async {
                      await ctx.run(() => ctx.api.post('${ctx.base}/ical/token'));
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

// ------------------------------------------------------------------------------------------------ MONTHLY RENT
int _rank(Json x) => !['in', 'booked'].contains(x['status'])
    ? 3
    : x['bill_due'] == true
    ? 0
    : n(obj(x['bill'])['balance']) > 0
    ? 1
    : 2;
num _round(num v, String cur) => cur == 'KHR' ? v.round() : (v * 100).round() / 100;

class LeasesTab extends StatefulWidget {
  final GhCtx ctx;
  const LeasesTab({super.key, required this.ctx});
  @override
  State<LeasesTab> createState() => _LeasesTabState();
}

class _LeasesTabState extends State<LeasesTab> {
  Json? _d;
  GhCtx get ctx => widget.ctx;
  bool get _on => ctx.addonOn('gh_longstay');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_on) return;
    try {
      final r = await ctx.api.get('${ctx.base}/leases');
      if (mounted) setState(() => _d = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _open(Widget Function(BuildContext) b) async {
    final ok = await showSheet<bool>(context, b);
    if (ok == true) {
      _load();
      ctx.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a = ctx.addon('gh_longstay');
    final hero = GhHero(
      ctx: ctx,
      addon: 'gh_longstay',
      yearly: true,
      icon: LucideIcons.keyRound,
      title: _x(ctx, 'lsTitle'),
      sub: _on ? _x(ctx, 'lsSub') : _x(ctx, 'lsOff', {'price': fmt(n(a['price']))}),
      extra: _on && _d != null
          ? Btn(
              _x(ctx, 'lsNew'),
              icon: LucideIcons.plus,
              small: true,
              onTap: ctx.readOnly
                  ? null
                  : () => _open(
                      (_) => _LeaseEditor(
                        ctx: ctx,
                        busy: [
                          for (final x in objs(_d!['list']))
                            if (['in', 'booked'].contains(x['status'])) str(x['room_id']),
                        ],
                      ),
                    ),
            )
          : null,
    );
    if (!_on) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          hero,
          mGap,
          GhPerks(ctx: ctx, addon: 'gh_longstay'),
        ],
      );
    }
    final d = _d;
    if (d == null) return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [hero, mGap, const SkelList(rows: 4)]);
    final counts = obj(d['counts']);
    final list = objs(d['list'])..sort((x, y) => _rank(x) - _rank(y));
    final month = str(d['month']).isEmpty ? todayKH().substring(0, 7) : str(d['month']);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          hero,
          mGap,
          Tiles([
            ('${n(counts['tenants'])}', _x(ctx, 'lsTenants'), null),
            (ctx.mo(d['rent_month']), _x(ctx, 'lsRentMonth'), null),
            ('${n(counts['to_bill'])}', _x(ctx, 'lsToBill'), n(counts['to_bill']) > 0 ? c.warn : null),
            (ctx.mo(d['owed']), _x(ctx, 'lsOwed'), n(d['owed']) > 0 ? c.danger : c.good),
          ]),
          mGap,
          if (list.isEmpty)
            _panel([Icon(LucideIcons.keyRound, size: 40, color: c.muted), const SizedBox(height: 8), Muted(_x(ctx, 'lsNone'), align: TextAlign.center)])
          else
            for (final x in list) ...[
              () {
                final live = ['in', 'booked'].contains(x['status']);
                final b = obj(x['bill']);
                final l = obj(x['lease']);
                final guest = obj(x['guest']);
                final (st, label) = !live
                    ? ('out', _x(ctx, 'lsEnded'))
                    : x['bill_due'] == true
                    ? ('due', _x(ctx, 'lsToMake', {'month': ghMonth(month, ctx.lang)}))
                    : n(b['balance']) > 0
                    ? ('owe', _x(ctx, 'lsOwes', {'amt': ctx.mo(b['balance'])}))
                    : ('ok', _x(ctx, 'lsPaid'));
                final tone = switch (st) {
                  'due' => c.warn,
                  'owe' => c.danger,
                  'ok' => c.good,
                  _ => c.muted,
                };
                final meter = obj(l['meter']);
                return Opacity(
                  opacity: live ? 1 : .6,
                  child: Panel(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.bedDouble, size: 15, color: c.brandInk),
                                  const SizedBox(width: 5),
                                  Text(
                                    str(x['room_name']),
                                    style: TextStyle(fontWeight: FontWeight.w800, color: c.brandInk),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(str(guest['name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                                  Text(
                                    [
                                      str(guest['phone']),
                                      _x(ctx, 'lsSince', {'date': ghDay(str(l['start']), ctx.lang, year: true)}),
                                      str(l['end']).isNotEmpty ? _x(ctx, 'lsUntil', {'date': ghDay(str(l['end']), ctx.lang, year: true)}) : _x(ctx, 'lsOpen'),
                                    ].where((s) => s.isNotEmpty).join(' · '),
                                    style: TextStyle(color: c.muted, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: tone.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            label,
                            style: TextStyle(color: tone, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: ctx.mo(l['rent']),
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  TextSpan(text: ' / ${_x(ctx, 'lsMonth').toLowerCase()}'),
                                ],
                              ),
                            ),
                            if (n(l['elec_rate']) > 0) Text('⚡ ${ctx.mo(l['elec_rate'])}/kWh'),
                            if (n(l['water_rate']) > 0) Text('💧 ${ctx.mo(l['water_rate'])}/m³'),
                            for (final f in objs(l['fixed'])) Text('${str(f['label'])} ${ctx.mo(f['amount'])}'),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Muted(_x(ctx, 'lsMeterNow', {'e': n(meter['elec']), 'w': n(meter['water'])})),
                        if (live) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (x['billed_this'] != true && x['status'] == 'in')
                                Btn(
                                  _x(ctx, 'lsMakeBill'),
                                  icon: LucideIcons.receiptText,
                                  small: true,
                                  kind: x['bill_due'] == true ? BtnKind.primary : BtnKind.ghost,
                                  onTap: ctx.readOnly ? null : () => _open((_) => _BillSheet(ctx: ctx, row: x)),
                                ),
                              Btn(
                                _x(ctx, 'lsPay'),
                                kind: BtnKind.ghost,
                                small: true,
                                onTap: () => openStay(context, ctx, str(x['_id']), onChanged: _load),
                              ),
                              Btn(
                                _x(ctx, 'lsEdit'),
                                icon: LucideIcons.pencil,
                                kind: BtnKind.ghost,
                                small: true,
                                onTap: ctx.readOnly ? null : () => _open((_) => _LeaseEditor(ctx: ctx, row: x)),
                              ),
                              Btn(
                                _x(ctx, 'lsEndBtn'),
                                icon: LucideIcons.logOut,
                                kind: BtnKind.ghost,
                                small: true,
                                onTap: ctx.readOnly ? null : () => _open((_) => _EndSheet(ctx: ctx, row: x)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }(),
              mGap,
            ],
        ],
      ),
    );
  }
}

class _LeaseEditor extends StatefulWidget {
  final GhCtx ctx;
  final Json? row;
  final List<String> busy;
  const _LeaseEditor({required this.ctx, this.row, this.busy = const []});
  @override
  State<_LeaseEditor> createState() => _LeaseEditorState();
}

class _LeaseEditorState extends State<_LeaseEditor> with GhSave {
  GhCtx get ctx => widget.ctx;
  @override
  GhCtx get gctx => ctx;
  late final Json l = obj(widget.row?['lease']);
  late final Json g = obj(widget.row?['guest']);
  late String _room = str(widget.row?['room_id']);
  late String _start = str(l['start']).isEmpty ? todayKH() : str(l['start']);
  late String _end = str(l['end']);
  late String _method = ctx.methods.first;
  String _num(Object? v) => v == null ? '' : '${n(v)}'.replaceFirst(RegExp(r'\.0$'), '');
  late final _name = TextEditingController(text: str(g['name']));
  late final _phone = TextEditingController(text: str(g['phone']));
  late final _rent = TextEditingController(text: _num(l['rent']));
  final _deposit = TextEditingController();
  late final _elecRate = TextEditingController(text: _num(l['elec_rate']));
  late final _waterRate = TextEditingController(text: _num(l['water_rate']));
  late final _billDay = TextEditingController(text: l['bill_day'] == null ? '1' : _num(l['bill_day']));
  final _elec = TextEditingController(), _water = TextEditingController();
  late final List<(TextEditingController, TextEditingController)> _fixed = [
    for (final f in objs(l['fixed'])) (TextEditingController(text: str(f['label'])), TextEditingController(text: _num(f['amount']))),
  ];

  @override
  void dispose() {
    for (final c in [_name, _phone, _rent, _deposit, _elecRate, _waterRate, _billDay, _elec, _water]) {
      c.dispose();
    }
    for (final (a, b) in _fixed) {
      a.dispose();
      b.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.row == null;
    final rooms = ctx.rooms.where((r) => r['active'] == true && r['usable'] != false && !widget.busy.contains(r['_id'])).toList();
    final body = {
      'guest': {'name': _name.text.trim(), 'phone': _phone.text.trim(), 'id_number': str(g['id_number'])},
      'end': _end,
      'rent': numOf(_rent.text),
      'elec_rate': numOf(_elecRate.text) ?? 0,
      'water_rate': numOf(_waterRate.text) ?? 0,
      'fixed': [
        for (final (a, b) in _fixed)
          if (a.text.trim().isNotEmpty) {'label': a.text.trim(), 'amount': numOf(b.text) ?? 0},
      ],
      'bill_day': int.tryParse(_billDay.text) ?? 1,
      if (isNew) ...{
        'room_id': _room,
        'start': _start,
        'deposit': numOf(_deposit.text) ?? 0,
        'deposit_method': _method,
        'meter': {'elec': numOf(_elec.text) ?? 0, 'water': numOf(_water.text) ?? 0},
      },
    };
    Widget two(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 10),
        Expanded(child: b),
      ],
    );
    return MSheet(
      title: isNew ? _x(ctx, 'lsNew') : _x(ctx, 'lsEdit'),
      footer: footer(
        canSave: _name.text.trim().isNotEmpty && (numOf(_rent.text) ?? 0) > 0 && (!isNew || _room.isNotEmpty),
        onSave: () => save(() => isNew ? ctx.api.post('${ctx.base}/leases', body) : ctx.api.put('${ctx.base}/leases/${widget.row!['_id']}', body), reload: false),
      ),
      children: [
        if (isNew) ...[
          Label('${_x(ctx, 'lsRoom')} *'),
          Chips<String>(options: [for (final r in rooms) (str(r['_id']), str(r['name']))], on: (k) => _room == k, onTap: (k) => setState(() => _room = k)),
          gap14,
        ],
        two(
          Field(label: '${ctx.g('guestName')} *', controller: _name, maxLength: 80, onChanged: (_) => setState(() {})),
          Field(label: ctx.g('phone'), controller: _phone, maxLength: 30, keyboard: TextInputType.phone),
        ),
        gap14,
        two(
          isNew
              ? DayField(label: _x(ctx, 'lsStart'), value: _start, onChanged: (v) => v.isEmpty ? null : setState(() => _start = v))
              : DayField(label: _x(ctx, 'lsStart'), value: _start, onChanged: (_) {}),
          DayField(label: _x(ctx, 'lsEnd'), value: _end, first: DateTime.parse(_start), onChanged: (v) => setState(() => _end = v)),
        ),
        gap14,
        two(
          Field(label: '${_x(ctx, 'lsRent')} *', controller: _rent, keyboard: decimalKeys, onChanged: (_) => setState(() {})),
          isNew
              ? Field(label: _x(ctx, 'lsDeposit'), controller: _deposit, keyboard: decimalKeys, onChanged: (_) => setState(() {}))
              : Field(label: _x(ctx, 'lsBillDay'), controller: _billDay, keyboard: TextInputType.number, maxLength: 2),
        ),
        if (isNew && (numOf(_deposit.text) ?? 0) > 0) ...[
          const SizedBox(height: 10),
          Chips<String>(options: [for (final k in ctx.methods) (k, ctx.method(k))], on: (k) => _method == k, onTap: (k) => setState(() => _method = k)),
        ],
        gap14,
        two(
          Field(label: _x(ctx, 'lsElecRate'), controller: _elecRate, hint: '0.25', keyboard: decimalKeys),
          Field(label: _x(ctx, 'lsWaterRate'), controller: _waterRate, hint: '0.5', keyboard: decimalKeys),
        ),
        if (isNew) ...[
          gap14,
          Field(label: _x(ctx, 'lsBillDay'), controller: _billDay, keyboard: TextInputType.number, maxLength: 2),
          gap14,
          Muted(_x(ctx, 'lsMeters')),
          const SizedBox(height: 8),
          two(Field(label: '⚡ ${_x(ctx, 'lsElec')}', controller: _elec, keyboard: decimalKeys), Field(label: '💧 ${_x(ctx, 'lsWater')}', controller: _water, keyboard: decimalKeys)),
        ],
        gap14,
        Label(_x(ctx, 'lsFixed')),
        for (final (i, (a, b)) in _fixed.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Field(controller: a, hint: 'Internet', maxLength: 60),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: Field(controller: b, keyboard: decimalKeys),
                ),
                IconButton(
                  onPressed: () => setState(() {
                    final x = _fixed.removeAt(i);
                    x.$1.dispose();
                    x.$2.dispose();
                  }),
                  icon: const Icon(LucideIcons.trash2, size: 16),
                ),
              ],
            ),
          ),
        if (_fixed.length < 10)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _fixed.add((TextEditingController(), TextEditingController()))),
              icon: const Icon(LucideIcons.plus, size: 15),
              label: Text(_x(ctx, 'lsAddFixed')),
            ),
          ),
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}

class _BillSheet extends StatefulWidget {
  final GhCtx ctx;
  final Json row;
  const _BillSheet({required this.ctx, required this.row});
  @override
  State<_BillSheet> createState() => _BillSheetState();
}

class _BillSheetState extends State<_BillSheet> with GhSave {
  GhCtx get ctx => widget.ctx;
  @override
  GhCtx get gctx => ctx;
  late final Json l = obj(widget.row['lease']);
  late final Json meter = obj(l['meter']);
  late final _elec = TextEditingController(text: '${n(meter['elec'])}'.replaceFirst(RegExp(r'\.0$'), ''));
  late final _water = TextEditingController(text: '${n(meter['water'])}'.replaceFirst(RegExp(r'\.0$'), ''));
  final month = todayKH().substring(0, 7);

  @override
  void dispose() {
    _elec.dispose();
    _water.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cur = ctx.cur;
    final e = numOf(_elec.text) ?? 0, w = numOf(_water.text) ?? 0;
    final eU = (e - n(meter['elec'])).clamp(0, double.infinity), wU = (w - n(meter['water'])).clamp(0, double.infinity);
    final lines = <(String, num)>[
      (_x(ctx, 'lsRent').split(' /').first, n(l['rent'])),
      ('⚡ ${_x(ctx, 'lsUnits', {'n': eU})}', _round(eU * n(l['elec_rate']), cur)),
      ('💧 ${_x(ctx, 'lsUnits', {'n': wU})}', _round(wU * n(l['water_rate']), cur)),
      for (final f in objs(l['fixed'])) (str(f['label']), n(f['amount'])),
    ].where((x) => x.$2 > 0).toList();
    final total = lines.fold<num>(0, (a, x) => a + x.$2);
    final back = e < n(meter['elec']) || w < n(meter['water']);
    return MSheet(
      title: _x(ctx, 'lsBillTitle', {'month': ghMonth(month, ctx.lang)}),
      footer: [
        Expanded(
          child: Btn(
            '${_x(ctx, 'lsMakeBill')} · ${ctx.mo(total)}',
            icon: LucideIcons.receiptText,
            expand: true,
            busy: busy,
            onTap: busy || back ? null : () => save(() => ctx.api.post('${ctx.base}/leases/${widget.row['_id']}/bill', {'month': month, 'elec': e, 'water': w}), reload: false),
          ),
        ),
      ],
      children: [
        Muted('${str(widget.row['room_name'])} · ${str(obj(widget.row['guest'])['name'])}'),
        gap14,
        Row(
          children: [
            Expanded(
              child: Field(
                label: '⚡ ${_x(ctx, 'lsElec')} · ${_x(ctx, 'lsPrev', {'n': n(meter['elec'])})}',
                controller: _elec,
                keyboard: decimalKeys,
                autofocus: true,
                invalid: e < n(meter['elec']),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Field(
                label: '💧 ${_x(ctx, 'lsWater')} · ${_x(ctx, 'lsPrev', {'n': n(meter['water'])})}',
                controller: _water,
                keyboard: decimalKeys,
                invalid: w < n(meter['water']),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        gap14,
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              for (final (label, v) in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text(label)),
                      Text(ctx.mo(v), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              Divider(color: c.line),
              Row(
                children: [
                  Expanded(
                    child: Text(_x(ctx, 'lsTotal'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  Text(ctx.mo(total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                ],
              ),
            ],
          ),
        ),
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}

class _EndSheet extends StatefulWidget {
  final GhCtx ctx;
  final Json row;
  const _EndSheet({required this.ctx, required this.row});
  @override
  State<_EndSheet> createState() => _EndSheetState();
}

class _EndSheetState extends State<_EndSheet> with GhSave {
  GhCtx get ctx => widget.ctx;
  @override
  GhCtx get gctx => ctx;
  late final num dep = n(obj(widget.row['lease'])['deposit']);
  late bool _refund = dep > 0;
  String _method = 'cash';

  @override
  Widget build(BuildContext context) {
    final left = n(obj(widget.row['bill'])['balance']);
    return MSheet(
      title: _x(ctx, 'lsEndTitle', {'name': str(obj(widget.row['guest'])['name'])}),
      footer: [
        const Spacer(),
        Btn(ctx.g('cancel'), kind: BtnKind.ghost, small: true, onTap: busy ? null : () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(
          _x(ctx, 'lsEndBtn'),
          icon: LucideIcons.logOut,
          kind: BtnKind.danger,
          small: true,
          busy: busy,
          onTap: busy ? null : () => save(() => ctx.api.post('${ctx.base}/leases/${widget.row['_id']}/end', {'refund_deposit': _refund, 'method': _method}), reload: false),
        ),
      ],
      children: [
        Muted(_x(ctx, 'lsEndNote')),
        if (left > 0) ...[
          gap14,
          Alert(_x(ctx, 'lsOwes', {'amt': ctx.mo(left)}), tone: Tone.warn),
        ],
        if (dep > 0) ...[
          gap14,
          SwitchRow(title: _x(ctx, 'lsRefund', {'amt': ctx.mo(dep)}), value: _refund, onChanged: (v) => setState(() => _refund = v)),
          if (_refund) Chips<String>(options: [for (final k in ctx.methods) (k, ctx.method(k))], on: (k) => _method == k, onTap: (k) => setState(() => _method = k)),
        ],
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}
