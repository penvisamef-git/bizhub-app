import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../guesthouse/gh_common.dart' show ghMonth, shiftMonth, ghDay;
import '../mart/mart_common.dart' show mGap, todayKH;
import '../restaurant/rest_common.dart' show Segmented;
import 'at_common.dart';

// Monthly report: a calendar (staff × days, coloured) + totals per staff + Excel (CSV) — ReportTab.jsx.

String _cellKind(Json d) {
  if (n(d['pending']) > 0 || d['pending'] == true) return 'pending';
  final s = str(d['status']);
  if (s == 'missing_out' || s == 'absent' || s == 'extra' || s == 'leave' || s == 'holiday' || s == 'off') return s;
  if (s == 'present' || s == 'working') return n(d['late_min']) > 0 ? 'late' : 'present';
  return 'none';
}

Color cellColor(BuildContext context, String k) {
  final c = context.c;
  return switch (k) {
    'present' => c.good,
    'late' => c.warn,
    'absent' => c.danger,
    'missing_out' => const Color(0xFF9333EA),
    'extra' => const Color(0xFF2563EB),
    'leave' => const Color(0xFF0891B2),
    'holiday' => const Color(0xFFDB2777),
    'pending' => const Color(0xFFF97316),
    'off' => c.line,
    _ => c.bg2,
  };
}

class ReportTab extends StatefulWidget {
  final AtCtx ctx;
  const ReportTab({super.key, required this.ctx});
  @override
  State<ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<ReportTab> {
  final _now = todayKH().substring(0, 7);
  late String _month = _now;
  Json? _rep;
  String _view = 'calendar', _tip = '';
  bool _sharing = false;
  AtCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = _month;
    try {
      final r = await ctx.api.get('${ctx.base}/report', {'month': m});
      if (mounted && m == _month) setState(() => _rep = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  void _go(int by) {
    setState(() {
      _month = shiftMonth(_month, by);
      _rep = null;
      _tip = '';
    });
    _load();
  }

  Future<void> _csv() async {
    setState(() => _sharing = true);
    try {
      final text = await ctx.api.text('${ctx.base}/report', {'month': _month, 'format': 'csv', 'lang': ctx.lang});
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(utf8.encode(text), mimeType: 'text/csv', name: 'attendance-$_month.csv')],
        ),
      );
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rep = _rep;
    final rows = objs(rep?['rows']);
    final days = (rep?['days'] as List? ?? const []).map((e) => '$e').toList();
    final dayShort = ctx.t.list('att.dayShort');
    String wd(String d) {
      final w = DateTime.parse('${d}T00:00:00Z').weekday % 7;
      return w < dayShort.length ? dayShort[w] : '';
    }

    String title(Json r, Json d) {
      final st = str(d['status']);
      return [
        ghDay(str(d['day']), ctx.lang, weekday: true),
        ctx.t.or('att.status.$st', st),
        if (d['first_in'] != null) '${hhmm(d['first_in'])}–${hhmm(d['last_out']).isEmpty ? '?' : hhmm(d['last_out'])}',
        if (n(d['late_min']) > 0) ctx.a('lateBy', {'m': dur(d['late_min'])}),
        if (n(d['ot_min']) > 0) ctx.a('otBy', {'m': dur(d['ot_min'])}),
      ].join(' · ');
    }

    const nameW = 110.0, cellW = 26.0;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          atPanel([
            Row(
              children: [
                IconButton(onPressed: () => _go(-1), icon: const Icon(LucideIcons.chevronLeft, size: 18)),
                Expanded(
                  child: Text(
                    ghMonth(_month, ctx.lang),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                  ),
                ),
                IconButton(onPressed: _month.compareTo(_now) >= 0 ? null : () => _go(1), icon: const Icon(LucideIcons.chevronRight, size: 18)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Segmented<String>(value: _view, options: [('calendar', ctx.a('calendar')), ('summary', ctx.a('summary'))], onChanged: (v) => setState(() => _view = v)),
                ),
                const SizedBox(width: 8),
                Btn(_sharing ? ctx.a('exporting') : ctx.a('exportCsv'), icon: LucideIcons.download, small: true, busy: _sharing, onTap: _sharing || rows.isEmpty ? null : _csv),
              ],
            ),
          ]),
          mGap,
          if (rep == null)
            const SkelList(rows: 4)
          else if (rows.isEmpty)
            atPanel([Muted(ctx.a('noReport'), align: TextAlign.center)])
          else if (_view == 'calendar')
            atPanel(padding: const EdgeInsets.fromLTRB(10, 12, 10, 14), [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: nameW,
                          child: Text(
                            ctx.a('col.name'),
                            style: TextStyle(color: c.muted, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                        for (final d in days)
                          SizedBox(
                            width: cellW,
                            child: Column(
                              children: [
                                Text(wd(d).characters.take(2).toString(), style: TextStyle(fontSize: 9.5, color: DateTime.parse('${d}T00:00:00Z').weekday == 7 ? c.danger : c.muted)),
                                Text('${int.parse(d.substring(8))}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (final r in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            SizedBox(
                              width: nameW,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    str(obj(r['staff'])['name']),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                  ),
                                  Text('${n(obj(r['totals'])['present'])}/${n(obj(r['totals'])['work_days'])}', style: TextStyle(color: c.muted, fontSize: 11)),
                                ],
                              ),
                            ),
                            for (final d in objs(r['days']))
                              Padding(
                                padding: const EdgeInsets.all(2),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () => setState(() => _tip = '${str(obj(r['staff'])['name'])} · ${title(r, d)}'),
                                  child: Container(
                                    width: cellW - 4,
                                    height: 24,
                                    decoration: BoxDecoration(color: cellColor(context, _cellKind(d)), borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (_tip.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(12)),
                  child: Text(_tip, style: const TextStyle(fontSize: 13)),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  for (final k in ['present', 'late', 'absent', 'missing_out', 'extra', 'leave', 'holiday', 'off', 'pending'])
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(color: cellColor(context, k), borderRadius: BorderRadius.circular(4)),
                        ),
                        const SizedBox(width: 5),
                        Text(ctx.a('legend.$k'), style: TextStyle(fontSize: 12, color: c.muted)),
                      ],
                    ),
                ],
              ),
            ])
          else
            atPanel(padding: const EdgeInsets.fromLTRB(8, 8, 8, 8), [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  horizontalMargin: 6,
                  columnSpacing: 16,
                  headingRowHeight: 40,
                  headingTextStyle: TextStyle(fontWeight: FontWeight.w800, color: c.muted, fontSize: 12),
                  columns: [
                    for (final k in ['name', 'work_days', 'present', 'late', 'late_min', 'early', 'absent', 'leave', 'missing_out', 'extra', 'ot_min', 'worked_min'])
                      DataColumn(label: Text(ctx.a('col.$k')), numeric: k != 'name'),
                  ],
                  rows: [
                    for (final r in rows)
                      () {
                        final t = obj(r['totals']);
                        final s = obj(r['staff']);
                        Text num0(Object? v, [Color? col]) => Text(
                          '${n(v)}',
                          style: TextStyle(color: n(v) > 0 ? col : null, fontWeight: n(v) > 0 && col != null ? FontWeight.w700 : null),
                        );
                        return DataRow(
                          cells: [
                            DataCell(
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(str(s['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                                  if (str(s['position']).isNotEmpty) Text(str(s['position']), style: TextStyle(color: c.muted, fontSize: 11)),
                                ],
                              ),
                            ),
                            DataCell(num0(t['work_days'])),
                            DataCell(num0(t['present'], c.good)),
                            DataCell(num0(t['late'], c.warn)),
                            DataCell(Text(n(t['late_min']) > 0 ? dur(t['late_min']) : '—', style: TextStyle(color: n(t['late_min']) > 0 ? c.warn : null))),
                            DataCell(num0(t['early'], c.warn)),
                            DataCell(num0(t['absent'], c.danger)),
                            DataCell(num0(t['leave'])),
                            DataCell(num0(t['missing_out'], c.danger)),
                            DataCell(num0(t['extra'])),
                            DataCell(Text(n(t['ot_min']) > 0 ? dur(t['ot_min']) : '—', style: TextStyle(color: n(t['ot_min']) > 0 ? const Color(0xFF2563EB) : null))),
                            DataCell(Text(dur(t['worked_min']), style: const TextStyle(fontWeight: FontWeight.w800))),
                          ],
                        );
                      }(),
                  ],
                ),
              ),
            ]),
        ],
      ),
    );
  }
}
