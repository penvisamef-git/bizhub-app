import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../guesthouse/gh_common.dart' show ghDay, ghDayLong;
import '../mart/mart_common.dart' show Tiles, mGap, todayKH, addDaysKH, mDayTime;
import '../mart/mart_kit.dart' show MSheet, showSheet, DayField;
import '../restaurant/rest_common.dart' show Segmented, gap14;
import 'at_common.dart';

// Today · Needs review (+ correction and overtime requests) · a record added by hand — DailyTabs.jsx, StaffExtras.jsx HrCard, DaysTabs.jsx.

// the 4 setup steps, until all are done
class _SetupCard extends StatelessWidget {
  final AtCtx ctx;
  const _SetupCard({required this.ctx});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = ctx.setup;
    final done = n(s['done']), total = n(s['total']);
    if (total == 0 || done >= total) return const SizedBox.shrink();
    final steps = obj(s['steps']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: atPanel([
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ctx.a('setupTitle'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  Muted(ctx.a('setupSub')),
                ],
              ),
            ),
            Text(
              '${done.toInt()}/${total.toInt()}',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: c.brand),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(value: done / total, minHeight: 6, color: c.brand, backgroundColor: c.bg2),
        ),
        const SizedBox(height: 8),
        for (final (i, (key, tab)) in [('branch', 'branches'), ('shift', 'shifts'), ('staff', 'staff'), ('link', 'settings')].indexed)
          () {
            final ok = steps[key] == true;
            final txt = ctx.t.list('att.steps.$key');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: ok ? c.good : c.active, shape: BoxShape.circle),
                    child: ok
                        ? const Icon(LucideIcons.check, size: 15, color: Colors.white)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(fontWeight: FontWeight.w800, color: c.brandInk),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(txt.isNotEmpty ? txt[0] : key, style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (txt.length > 1) Muted(txt[1]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ok ? Chip2(ctx.a('done'), tone: Tone.good) : Btn(ctx.a('go'), small: true, onTap: () => ctx.go(tab)),
                ],
              ),
            );
          }(),
      ]),
    );
  }
}

// HR reminders: birthdays, contracts and documents ending (hidden when empty)
class _HrCard extends StatefulWidget {
  final AtCtx ctx;
  const _HrCard({required this.ctx});
  @override
  State<_HrCard> createState() => _HrCardState();
}

class _HrCardState extends State<_HrCard> {
  List<Json> _items = [];
  AtCtx get ctx => widget.ctx;
  String t(String k, [Map<String, Object?> v = const {}]) => ctx.t('atsx.$k', v);

  @override
  void initState() {
    super.initState();
    ctx.api.get('${ctx.base}/hr').then((r) {
      if (mounted) setState(() => _items = objs(obj(r['data'])['items']));
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_items.isEmpty) return const SizedBox.shrink();
    String when(num d) => d == 0
        ? t('today')
        : d == 1
        ? t('tomorrow')
        : t('inDays', {'n': d});
    String ago(num d) => t('daysAgo', {'n': -d});
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: atPanel([
        Text(t('hrTitle'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        for (final i in _items)
          () {
            final d = n(i['in_days']);
            final past = d < 0;
            final type = str(i['type']);
            final label = type == 'birthday'
                ? '${t('hrBirthday', {'when': when(d)})} · ${t('turns', {'age': i['age']})}'
                : type == 'contract'
                ? (past ? t('hrContractPast', {'ago': ago(d)}) : t('hrContract', {'when': when(d)}))
                : (past ? t('hrDocPast', {'ago': ago(d)}) : t('hrDoc', {'when': when(d)})).replaceAll('{name}', str(i['name']).isEmpty ? t('kinds.${i['kind']}') : str(i['name']));
            final col = past
                ? c.danger
                : d <= 7
                ? c.warn
                : c.muted;
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => ctx.go('staff'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Icon(type == 'birthday' ? LucideIcons.cake : LucideIcons.fileText, size: 17, color: col),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(str(i['staff_name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(label, style: TextStyle(color: col, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Muted(ghDay(str(i['day']), ctx.lang)),
                  ],
                ),
              ),
            );
          }(),
      ]),
    );
  }
}

// one clock in / out
class PunchLine extends StatelessWidget {
  final AtCtx ctx;
  final Json p;
  final VoidCallback? onRemove;
  const PunchLine({super.key, required this.ctx, required this.p, this.onRemove});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final flags = (p['flags'] as List? ?? const []).map((e) => '$e').toList();
    final photo = str(obj(p['photo'])['url']);
    final review = str(p['review']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photo.isNotEmpty) ...[
            InkWell(
              onTap: () => showDialog<void>(
                context: context,
                builder: (d) => GestureDetector(
                  onTap: () => Navigator.pop(d),
                  child: InteractiveViewer(child: Image(image: netImage(photo))),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image(image: netImage(photo), width: 38, height: 38, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 38)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Icon(p['kind'] == 'in' ? LucideIcons.logIn : LucideIcons.logOut, size: 15, color: review == 'rejected' ? c.danger : c.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  hhmm(p['at']),
                  style: TextStyle(fontWeight: FontWeight.w800, decoration: review == 'rejected' ? TextDecoration.lineThrough : null),
                ),
                Text(ctx.a('kinds.${p['kind']}'), style: const TextStyle(fontSize: 13)),
                if (str(p['branch_name']).isNotEmpty) AtTag('📍 ${str(p['branch_name'])}'),
                if (p['distance_m'] != null && flags.contains('outside')) AtTag(ctx.a('away', {'m': p['distance_m']}), tone: 'warn'),
                for (final f in flags.where((f) => f != 'outside')) AtTag(ctx.t.or('att.flags.$f', f), tone: 'warn'),
                if (p['source'] != null && p['source'] != 'phone') AtTag(ctx.t.or('att.source.${p['source']}', str(p['source']))),
                if (p['kiosk'] == true) AtTag(ctx.a('kioskTag')),
                if (review.isNotEmpty && review != 'ok') AtTag(ctx.a('review.$review'), tone: review == 'rejected' ? 'bad' : 'warn'),
                if (str(p['note']).isNotEmpty)
                  Text(
                    '“${str(p['note'])}”',
                    style: TextStyle(color: c.muted, fontSize: 12, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
          if (onRemove != null && p['source'] == 'manual')
            InkWell(
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(LucideIcons.trash2, size: 15, color: c.danger),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ TODAY
class TodayTab extends StatefulWidget {
  final AtCtx ctx;
  const TodayTab({super.key, required this.ctx});
  @override
  State<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<TodayTab> {
  String _day = todayKH();
  Json? _board;
  String _open = '';
  bool _busy = false;
  Timer? _tick;
  AtCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_day == todayKH()) _load();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final day = _day;
    if (mounted) setState(() => _busy = true);
    try {
      final r = await ctx.api.get('${ctx.base}/today', {'day': day});
      if (mounted && day == _day) setState(() => _board = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _go(String day) {
    setState(() {
      _day = day;
      _board = null;
    });
    _load();
  }

  Future<void> _add({String? staffId, String kind = 'in'}) async {
    final rows = objs(_board?['rows']);
    final ok = await showSheet<bool>(context, (_) => ManualSheet(ctx: ctx, staff: [for (final r in rows) obj(r['staff'])], staffId: staffId, kind: kind, day: _day));
    if (ok == true) {
      _load();
      ctx.reload();
    }
  }

  Future<void> _remove(Json p) async {
    if (await ctx.run(() => ctx.api.delete('${ctx.base}/punches/${p['_id']}')) != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final b = _board;
    final today = todayKH();
    final isToday = _day == today;
    final tot = obj(b?['totals']);
    final rows = objs(b?['rows']);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _SetupCard(ctx: ctx),
          if (isToday) _HrCard(ctx: ctx),
          atPanel([
            Row(
              children: [
                IconButton(onPressed: () => _go(addDaysKH(_day, -1)), icon: const Icon(LucideIcons.chevronLeft, size: 18)),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.parse(today), initialDate: DateTime.parse(_day));
                      if (d != null) _go(d.toIso8601String().substring(0, 10));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        ghDayLong(_day, ctx.lang),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                      ),
                    ),
                  ),
                ),
                IconButton(onPressed: isToday ? null : () => _go(addDaysKH(_day, 1)), icon: const Icon(LucideIcons.chevronRight, size: 18)),
              ],
            ),
            Row(
              children: [
                if (!isToday) ...[Btn(ctx.a('todayBtn'), kind: BtnKind.ghost, small: true, onTap: () => _go(today)), const SizedBox(width: 8)],
                const Spacer(),
                IconButton(
                  onPressed: _busy ? null : _load,
                  icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(LucideIcons.refreshCw, size: 17),
                ),
                Btn(ctx.a('addRecord'), icon: LucideIcons.plus, small: true, onTap: ctx.readOnly || rows.isEmpty ? null : () => _add()),
              ],
            ),
            if (b != null) ...[
              const SizedBox(height: 10),
              Tiles([
                ('${n(tot['in'])}', ctx.a('tot.in'), c.good),
                ('${n(tot['working'])}', ctx.a('tot.working'), const Color(0xFF2563EB)),
                ('${n(tot['late'])}', ctx.a('tot.late'), c.warn),
                if (isToday) ('${n(tot['not_yet'])}', ctx.a('tot.not_yet'), null) else ('${n(tot['absent'])}', ctx.a('tot.absent'), c.danger),
                if (isToday) ('${n(tot['absent'])}', ctx.a('tot.absent'), c.danger),
              ]),
              if (n(tot['pending']) > 0) ...[
                const SizedBox(height: 10),
                Material(
                  color: c.warnBg,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => ctx.go('review'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(LucideIcons.triangleAlert, size: 18, color: c.warn),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${n(tot['pending'])} · ${ctx.a('tot.pending')}',
                              style: TextStyle(fontWeight: FontWeight.w800, color: c.warn),
                            ),
                          ),
                          Icon(LucideIcons.chevronRight, size: 16, color: c.warn),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ]),
          mGap,
          if (b == null)
            const SkelList(rows: 4)
          else if (rows.isEmpty)
            atPanel([
              Icon(LucideIcons.users, size: 34, color: c.muted),
              const SizedBox(height: 8),
              Muted(ctx.a('noStaffToday'), align: TextAlign.center),
              const SizedBox(height: 10),
              Center(
                child: Btn(ctx.a('addStaff'), icon: LucideIcons.plus, small: true, onTap: () => ctx.go('staff')),
              ),
            ])
          else
            atPanel(padding: const EdgeInsets.fromLTRB(12, 6, 12, 6), [
              for (final row in rows)
                () {
                  final st = obj(row['staff']);
                  final shift = row['shift'] == null ? null : obj(row['shift']);
                  final open = _open == st['_id'];
                  final status = str(row['status']);
                  final punches = objs(row['punches']);
                  return Container(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: c.line)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _open = open ? '' : str(st['_id'])),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AtAvatar(st['name'], color: str(shift?['color'])),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(str(st['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                                      Text(shift != null ? '${str(shift['name'])} · ${str(shift['start'])}–${str(shift['end'])}' : ctx.a('noShift'), style: TextStyle(color: c.muted, fontSize: 12)),
                                      const SizedBox(height: 5),
                                      Wrap(
                                        spacing: 5,
                                        runSpacing: 4,
                                        children: [
                                          AtTag(ctx.t.or('att.status.$status', status), tone: statusTone(status)),
                                          if (n(row['late_min']) > 0) AtTag(ctx.a('lateBy', {'m': dur(row['late_min'])}), tone: 'warn'),
                                          if (n(row['early_min']) > 0) AtTag(ctx.a('earlyBy', {'m': dur(row['early_min'])}), tone: 'warn'),
                                          if (n(row['ot_min']) > 0) AtTag(ctx.a('otBy', {'m': dur(row['ot_min'])}), tone: 'blue'),
                                          if (n(row['pending']) > 0) AtTag('${n(row['pending'])}', tone: 'bad', icon: LucideIcons.triangleAlert),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '${ctx.a('inAt')} ',
                                            style: TextStyle(color: c.muted, fontSize: 11.5),
                                          ),
                                          TextSpan(
                                            text: hhmm(row['first_in']).isEmpty ? '—' : hhmm(row['first_in']),
                                            style: const TextStyle(fontWeight: FontWeight.w800),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '${ctx.a('outAt')} ',
                                            style: TextStyle(color: c.muted, fontSize: 11.5),
                                          ),
                                          TextSpan(
                                            text: status == 'missing_out' ? '?' : (hhmm(row['last_out']).isEmpty ? '—' : hhmm(row['last_out'])),
                                            style: const TextStyle(fontWeight: FontWeight.w800),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(open ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 15, color: c.muted),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (open)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(50, 0, 0, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (n(row['worked_min']) > 0) Muted(ctx.a('worked', {'m': dur(row['worked_min'])})),
                                if (punches.isEmpty) const Muted('—'),
                                for (final p in punches) PunchLine(ctx: ctx, p: p, onRemove: ctx.readOnly ? null : () => _remove(p)),
                                if (!ctx.readOnly)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () => _add(staffId: str(st['_id']), kind: status == 'working' || status == 'missing_out' ? 'out' : 'in'),
                                      icon: const Icon(LucideIcons.plus, size: 15),
                                      label: Text(ctx.a('addRecord')),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                }(),
            ]),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ A RECORD BY HAND
class ManualSheet extends StatefulWidget {
  final AtCtx ctx;
  final List<Json> staff;
  final String? staffId, forDay, at;
  final String kind, day;
  final bool lockStaff;
  const ManualSheet({super.key, required this.ctx, required this.staff, this.staffId, this.kind = 'in', required this.day, this.forDay, this.at, this.lockStaff = false});
  @override
  State<ManualSheet> createState() => _ManualSheetState();
}

class _ManualSheetState extends State<ManualSheet> with AtSave {
  AtCtx get ctx => widget.ctx;
  @override
  AtCtx get actx => ctx;
  late String _staff = widget.staffId ?? str(widget.staff.firstOrNull?['_id']);
  late String _kind = widget.kind;
  late String _date, _time;
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    final at = DateTime.tryParse(widget.at ?? '')?.toUtc().add(const Duration(hours: 7));
    if (at != null) {
      _date = at.toIso8601String().substring(0, 10);
      _time = '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    } else if (widget.day != todayKH()) {
      _date = widget.day;
      _time = widget.kind == 'out' ? '17:00' : '08:00';
    } else {
      final now = DateTime.now().toUtc().add(const Duration(hours: 7));
      _date = todayKH();
      _time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String get _iso {
    final d = DateTime.parse('${_date}T$_time:00Z').subtract(const Duration(hours: 7));
    return d.toIso8601String();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return MSheet(
      title: ctx.a('manualTitle'),
      footer: footer(
        canSave: _staff.isNotEmpty,
        onSave: () {
          if (_note.text.trim().isEmpty) return setState(() => error = ctx.a('needReason'));
          save(() => ctx.api.post('${ctx.base}/punches', {'staff_id': _staff, 'kind': _kind, 'at': _iso, 'note': _note.text.trim(), if (widget.forDay != null) 'day': widget.forDay}), reload: false);
        },
      ),
      children: [
        Muted(ctx.a('manualSub')),
        gap14,
        Text(ctx.a('who'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (widget.lockStaff)
          Text(str(widget.staff.where((s) => s['_id'] == _staff).firstOrNull?['name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final s in widget.staff) ChoiceChip(label: Text(str(s['name'])), selected: _staff == s['_id'], onSelected: (_) => setState(() => _staff = str(s['_id'])))],
          ),
        gap14,
        Text(ctx.a('kind'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Segmented<String>(value: _kind, options: [('in', ctx.a('kinds.in')), ('out', ctx.a('kinds.out'))], onChanged: (v) => setState(() => _kind = v)),
        gap14,
        Text(ctx.a('when'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: DayField(value: _date, last: DateTime.parse(todayKH()), onChanged: (v) => v.isEmpty ? null : setState(() => _date = v)),
            ),
            const SizedBox(width: 10),
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () async {
                final p = _time.split(':');
                final t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])),
                  builder: (c2, child) => MediaQuery(data: MediaQuery.of(c2).copyWith(alwaysUse24HourFormat: true), child: child!),
                );
                if (t != null) setState(() => _time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                decoration: BoxDecoration(
                  color: c.bg2,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: c.line),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.clock, size: 16, color: c.muted),
                    const SizedBox(width: 8),
                    Text(_time, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
              ),
            ),
          ],
        ),
        gap14,
        Field(label: ctx.a('reason'), hint: ctx.a('reasonPh'), controller: _note, maxLength: 300),
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ NEEDS REVIEW
class ReviewTab extends StatefulWidget {
  final AtCtx ctx;
  const ReviewTab({super.key, required this.ctx});
  @override
  State<ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<ReviewTab> {
  Json? _list;
  List<Json>? _fixes, _ot;
  List<Json> _staff = [];
  final Map<String, TextEditingController> _notes = {};
  String _busy = '';
  AtCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _notes.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _note(Object? id) => _notes.putIfAbsent('$id', TextEditingController.new);

  Future<void> _load() async {
    final r = await Future.wait([
      ctx.api
          .get('${ctx.base}/review')
          .then(
            (x) => obj(x['data']),
            onError: (Object e) {
              ctx.fail(e);
              return <String, dynamic>{'pending': [], 'missing_out': []};
            },
          ),
      ctx.api.get('${ctx.base}/fixes', {'status': 'pending'}).then((x) => objs(x['data']), onError: (_) => <Json>[]),
      ctx.api.get('${ctx.base}/overtime', {'status': 'pending'}).then((x) => objs(x['data']), onError: (_) => <Json>[]),
      ctx.api.get('${ctx.base}/staff').then((x) => objs(x['data']), onError: (_) => <Json>[]),
    ]);
    if (!mounted) return;
    setState(() {
      _list = r[0] as Json;
      _fixes = r[1] as List<Json>;
      _ot = r[2] as List<Json>;
      _staff = r[3] as List<Json>;
    });
  }

  Future<void> _decide(String path, Object? id, Json body) async {
    setState(() => _busy = '$id');
    if (await ctx.run(() => ctx.api.post(path, body)) != null) {
      await _load();
      ctx.reload();
    }
    if (mounted) setState(() => _busy = '');
  }

  Widget _actions(Object? id, String approve, String reject, VoidCallback onOk, VoidCallback onNo) {
    if (ctx.readOnly) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Field(controller: _note(id), hint: ctx.a('notePh'), maxLength: 300),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Btn(reject, icon: LucideIcons.x, kind: BtnKind.ghost, small: true, expand: true, onTap: _busy == '$id' ? null : onNo),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Btn(approve, icon: LucideIcons.check, small: true, expand: true, busy: _busy == '$id', onTap: _busy == '$id' ? null : onOk),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _head(IconData icon, String title, int count, [String? sub]) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            ),
            Chip2('$count', tone: Tone.danger),
          ],
        ),
        if (sub != null) ...[const SizedBox(height: 4), Muted(sub)],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final l = _list;
    if (l == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 3));
    final pending = objs(l['pending']), missing = objs(l['missing_out']);
    final fixes = _fixes ?? [], ot = _ot ?? [];
    final empty = pending.isEmpty && missing.isEmpty && fixes.isEmpty && ot.isEmpty;
    String dy(String k, [Map<String, Object?> v = const {}]) => ctx.t('atdy.$k', v);
    String o(String k, [Map<String, Object?> v = const {}]) => ctx.t('atot.$k', v);
    Widget person(Object? name, String sub, {String photo = '', Widget? end}) => Row(
      children: [
        if (photo.isNotEmpty)
          InkWell(
            onTap: () => showDialog<void>(
              context: context,
              builder: (d) => GestureDetector(
                onTap: () => Navigator.pop(d),
                child: InteractiveViewer(child: Image(image: netImage(photo))),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image(image: netImage(photo), width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, _, _) => AtAvatar(name)),
            ),
          )
        else
          AtAvatar(name),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(str(name), style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(sub, style: TextStyle(color: c.muted, fontSize: 12.5)),
            ],
          ),
        ),
        ?end,
      ],
    );
    final divider = Divider(height: 22, color: c.line);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          atPanel([Text(ctx.a('tabs.review'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Muted(ctx.a('reviewSub'))]),
          if (empty) ...[
            mGap,
            atPanel([
              Icon(LucideIcons.circleCheck, size: 36, color: c.good),
              const SizedBox(height: 8),
              Text(
                ctx.a('allClear'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ]),
          ],
          if (fixes.isNotEmpty) ...[
            mGap,
            atPanel([
              _head(LucideIcons.pencilLine, dy('fixTitle'), fixes.length, dy('fixSub')),
              for (final (i, f) in fixes.indexed) ...[
                if (i > 0) divider,
                person(
                  obj(f['staff'])['name'],
                  '${ghDay(str(f['day']), ctx.lang, weekday: true)} · ${f['kind'] == 'in' ? dy('inAt') : dy('outAt')} ${str(f['time'])} · ${dy('asked', {'date': mDayTime(f['created_date'], ctx.lang)})}',
                ),
                const SizedBox(height: 6),
                AtTag('“${str(f['reason'])}”'),
                _actions(
                  f['_id'],
                  dy('approve'),
                  dy('reject'),
                  () => _decide('${ctx.base}/fixes/${f['_id']}/decide', f['_id'], {'status': 'approved', 'note': _note(f['_id']).text}),
                  () => _decide('${ctx.base}/fixes/${f['_id']}/decide', f['_id'], {'status': 'rejected', 'note': _note(f['_id']).text}),
                ),
              ],
            ]),
          ],
          if (ot.isNotEmpty) ...[
            mGap,
            atPanel([
              _head(LucideIcons.clock8, o('title'), ot.length, o('sub')),
              for (final (i, x) in ot.indexed) ...[
                if (i > 0) divider,
                person(obj(x['staff'])['name'], '${ghDay(str(x['day']), ctx.lang, weekday: true)} · ${o('until', {'t': x['until']})}'),
                const SizedBox(height: 6),
                AtTag('“${str(x['reason'])}”'),
                _actions(
                  x['_id'],
                  o('approve'),
                  o('reject'),
                  () => _decide('${ctx.base}/overtime/${x['_id']}/decide', x['_id'], {'status': 'approved', 'note': _note(x['_id']).text}),
                  () => _decide('${ctx.base}/overtime/${x['_id']}/decide', x['_id'], {'status': 'rejected', 'note': _note(x['_id']).text}),
                ),
              ],
            ]),
          ],
          if (pending.isNotEmpty) ...[
            mGap,
            atPanel([
              _head(LucideIcons.triangleAlert, ctx.a('pendingTitle'), pending.length),
              for (final (i, p) in pending.indexed) ...[
                if (i > 0) divider,
                person(p['staff_name'], '${ghDay(str(p['day']), ctx.lang, weekday: true)} · ${ctx.a('kinds.${p['kind']}')} ${hhmm(p['at'])}', photo: str(obj(p['photo'])['url'])),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final f in (p['flags'] as List? ?? const []).map((e) => '$e'))
                      AtTag(f == 'outside' && p['distance_m'] != null ? '${ctx.a('flags.$f')} · ${ctx.a('away', {'m': p['distance_m']})}' : ctx.t.or('att.flags.$f', f), tone: 'bad'),
                    if (str(p['branch_name']).isNotEmpty) AtTag('📍 ${str(p['branch_name'])}'),
                    if (p['accuracy'] != null) AtTag('GPS ±${p['accuracy']} m'),
                    if (p['lat'] is num)
                      InkWell(
                        onTap: () => launchUrl(Uri.parse('https://www.google.com/maps?q=${p['lat']},${p['lng']}'), mode: LaunchMode.externalApplication),
                        child: AtTag('🗺 ${ctx.a('openMap')}', tone: 'blue'),
                      ),
                  ],
                ),
                _actions(
                  p['_id'],
                  ctx.a('approve'),
                  ctx.a('reject'),
                  () => _decide('${ctx.base}/punches/${p['_id']}/decide', p['_id'], {'review': 'ok', 'note': _note(p['_id']).text}),
                  () => _decide('${ctx.base}/punches/${p['_id']}/decide', p['_id'], {'review': 'rejected', 'note': _note(p['_id']).text}),
                ),
              ],
            ]),
          ],
          if (missing.isNotEmpty) ...[
            mGap,
            atPanel([
              _head(LucideIcons.clock, ctx.a('missingTitle'), missing.length, ctx.a('missingSub')),
              for (final (i, m) in missing.indexed) ...[
                if (i > 0) divider,
                person(
                  m['staff_name'],
                  '${ghDay(str(m['day']), ctx.lang, weekday: true)} · ${ctx.a('inAt')} ${hhmm(m['first_in'])} · ${ctx.a('outAt')} ?',
                  end: ctx.readOnly
                      ? null
                      : Btn(
                          ctx.a('addOut'),
                          icon: LucideIcons.logOut,
                          small: true,
                          onTap: () async {
                            final ok = await showSheet<bool>(
                              context,
                              (_) => ManualSheet(
                                ctx: ctx,
                                staff: _staff,
                                staffId: str(m['staff_id']),
                                kind: 'out',
                                day: str(m['day']),
                                forDay: str(m['day']),
                                at: str(m['end'] ?? m['first_in']),
                                lockStaff: true,
                              ),
                            );
                            if (ok == true) {
                              _load();
                              ctx.reload();
                            }
                          },
                        ),
                ),
              ],
            ]),
          ],
        ],
      ),
    );
  }
}

// so other files can show a day like the web (Mon 14 Oct)
String atDay(String day, String lang) => ghDay(day, lang, weekday: true);
