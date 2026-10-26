import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/buy_sheet.dart';
import '../../widgets/ui.dart';
import '../guesthouse/gh_common.dart' show ghDay, ghWeekday;
import '../mart/mart_common.dart' show GoldBtn, mGap, todayKH, addDaysKH;
import '../mart/mart_kit.dart' show DayField, showSheet;
import 'at_addons.dart';
import 'at_common.dart';

// Weekly roster (RosterTab.jsx) · Holidays (DaysTabs.jsx HolidaysTab)

String _mondayOf(String day) {
  final wd = DateTime.parse('${day}T00:00:00Z').weekday; // 1 = Mon
  return addDaysKH(day, -(wd - 1));
}

int _jsDay(String day) => DateTime.parse('${day}T00:00:00Z').weekday % 7; // 0 = Sun, like the web

// ------------------------------------------------------------------------------------------------ ROSTER
class RosterTab extends StatefulWidget {
  final AtCtx ctx;
  const RosterTab({super.key, required this.ctx});
  @override
  State<RosterTab> createState() => _RosterTabState();
}

class _RosterTabState extends State<RosterTab> {
  AtCtx get ctx => widget.ctx;
  late String _from = _mondayOf(todayKH());
  Json? _data;
  final Map<String, String> _edits = {}; // "staff|day" → shift id | off | default
  bool _busy = false;
  String r(String k, [Map<String, Object?> v = const {}]) => ctx.t('atro.$k', v);
  bool get _on => ctx.addonOn('att_roster');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ctx.api.get('${ctx.base}/roster', {'from': _from});
      if (mounted) {
        setState(() {
          _data = obj(res['data']);
          _edits.clear();
        });
      }
    } catch (e) {
      ctx.fail(e);
    }
  }

  void _go(int days) {
    setState(() {
      _from = addDaysKH(_from, days);
      _data = null;
    });
    _load();
  }

  Map<String, String> get _saved => {for (final e in objs(_data?['entries'])) '${e['staff_id']}|${e['day']}': e['shift_id'] == null ? 'off' : str(e['shift_id'])};
  Map<String, Json> get _shiftOf => {for (final s in objs(_data?['shifts'])) str(s['_id']): s};
  String _valueOf(String sid, String day) => _edits['$sid|$day'] ?? _saved['$sid|$day'] ?? 'default';
  List<MapEntry<String, String>> get _changes {
    final saved = _saved;
    return _edits.entries.where((e) => (saved[e.key] ?? 'default') != e.value).toList();
  }

  Future<void> _run(Future<Json> Function() fn, String ok) async {
    setState(() => _busy = true);
    try {
      await fn();
      ctx.notify(ok);
      await _load();
    } on ApiError catch (e) {
      if (e.status == 402) {
        ctx.askBuy('att_roster');
      } else {
        ctx.fail(e);
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pick(Json staff, String day, Json? usual) async {
    final shifts = objs(_data!['shifts']).where((x) => x['active'] != false).toList();
    final cur = _valueOf(str(staff['_id']), day);
    final usualWorks = usual != null && (usual['days'] as List? ?? const []).map((e) => n(e).toInt()).contains(_jsDay(day));
    final v = await showSheet<String>(
      context,
      (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text('${str(staff['name'])} · ${ghDay(day, ctx.lang, weekday: true)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            for (final (key, label, color) in [
              ('default', usual != null ? r('usualOf', {'name': usualWorks ? str(usual['name']) : r('off')}) : r('usual'), ''),
              ('off', r('off'), ''),
              for (final s in shifts) (str(s['_id']), '${str(s['name'])} ${str(s['start'])}–${str(s['end'])}', str(s['color'])),
            ])
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                leading: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: color.isEmpty ? Colors.transparent : atHex(color),
                    border: color.isEmpty ? Border.all(color: sheet.c.muted) : null,
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(label, style: TextStyle(fontWeight: cur == key ? FontWeight.w800 : FontWeight.w500)),
                trailing: cur == key ? Icon(LucideIcons.check, color: sheet.c.brand) : null,
                onTap: () => Navigator.pop(sheet, key),
              ),
          ],
        ),
      ),
    );
    if (v != null) setState(() => _edits['${staff['_id']}|$day'] = v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = _data;
    final thisWeek = _from == _mondayOf(todayKH());
    final changes = _changes;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        if (!_on) ...[AtLocked(ctx: ctx, addon: 'att_roster'), mGap],
        atPanel([
          Row(
            children: [
              Icon(LucideIcons.calendarRange, size: 20, color: c.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(r('title'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Muted(r('sub')),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(onPressed: () => _go(-7), icon: const Icon(LucideIcons.chevronLeft)),
              Expanded(
                child: Text(
                  thisWeek ? r('thisWeek') : r('week', {'date': ghDay(_from, ctx.lang)}),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              IconButton(onPressed: () => _go(7), icon: const Icon(LucideIcons.chevronRight)),
            ],
          ),
          if (_on && !ctx.readOnly)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Btn(
                  r('copyPrev'),
                  icon: LucideIcons.copy,
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: _busy ? null : () => _run(() => ctx.api.post('${ctx.base}/roster/copy', {'from': addDaysKH(_from, -7), 'to': _from}), r('copied')),
                ),
                Btn(
                  r('clear'),
                  icon: LucideIcons.eraser,
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: _busy ? null : () => _run(() => ctx.api.post('${ctx.base}/roster/clear', {'from': _from}), r('cleared')),
                ),
              ],
            ),
        ]),
        mGap,
        if (d == null)
          const SkelList(rows: 4)
        else if (objs(d['staff']).isEmpty)
          atPanel([Muted(r('noStaff'), align: TextAlign.center)])
        else if (objs(d['shifts']).isEmpty)
          atPanel([Muted(r('noShifts'), align: TextAlign.center)])
        else
          atPanel(padding: const EdgeInsets.fromLTRB(10, 12, 10, 12), [_grid(context, d), const SizedBox(height: 12), _legend(context, d)]),
        if (changes.isNotEmpty) ...[
          mGap,
          Panel(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: Muted(r('changed', {'n': changes.length}))),
                Btn(r('undo'), icon: LucideIcons.rotateCcw, kind: BtnKind.ghost, small: true, onTap: _busy ? null : () => setState(_edits.clear)),
                const SizedBox(width: 8),
                Btn(
                  _busy ? r('saving') : r('save'),
                  icon: LucideIcons.save,
                  small: true,
                  busy: _busy,
                  onTap: _busy || ctx.readOnly
                      ? null
                      : () => _run(
                          () => ctx.api.put('${ctx.base}/roster', {
                            'entries': [
                              for (final e in changes) {'staff_id': e.key.split('|')[0], 'day': e.key.split('|')[1], 'shift': e.value},
                            ],
                          }),
                          r('saved'),
                        ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _grid(BuildContext context, Json d) {
    final c = context.c;
    final days = (d['days'] as List? ?? const []).map((e) => '$e').toList();
    final hol = obj(d['holidays']);
    final today = todayKH();
    final shiftOf = _shiftOf;
    final saved = _saved;
    const nameW = 112.0, cellW = 76.0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: nameW),
              for (final day in days)
                Container(
                  width: cellW,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: day == today
                        ? c.active
                        : hol[day] != null
                        ? c.dangerBg
                        : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(ghWeekday(day, ctx.lang), style: TextStyle(color: c.muted, fontSize: 11.5)),
                      Text('${int.parse(day.substring(8))}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (hol[day] != null)
                        Text(
                          r('holiday'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.danger, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          for (final s in objs(d['staff']))
            () {
              final sid = str(s['_id']);
              final usual = s['shift_id'] == null ? null : shiftOf[str(s['shift_id'])];
              return Row(
                children: [
                  SizedBox(
                    width: nameW,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            str(s['name']),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            usual == null ? '—' : '${str(usual['name'])} ${str(usual['start'])}–${str(usual['end'])}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c.muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                  for (final day in days)
                    () {
                      final v = _valueOf(sid, day);
                      final usualWorks = usual != null && (usual['days'] as List? ?? const []).map((e) => n(e).toInt()).contains(_jsDay(day));
                      final sh = v == 'default'
                          ? (usualWorks ? usual : null)
                          : v == 'off'
                          ? null
                          : shiftOf[v];
                      final changed = _edits['$sid|$day'] != null && (saved['$sid|$day'] ?? 'default') != v;
                      final col = sh == null ? c.muted : atHex(str(sh['color']));
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: ctx.readOnly || !_on ? null : () => _pick(s, day, usual),
                        child: Container(
                          width: cellW,
                          height: 50,
                          margin: const EdgeInsets.all(2),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: sh == null ? c.bg2 : col.withValues(alpha: v == 'default' ? .10 : .20),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: changed
                                  ? c.brand
                                  : sh == null
                                  ? Colors.transparent
                                  : col.withValues(alpha: .5),
                              width: changed ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                sh == null ? r('off') : str(sh['name']),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: sh == null ? c.muted : col),
                              ),
                              Text(
                                sh != null
                                    ? '${str(sh['start'])}–${str(sh['end'])}'
                                    : v == 'default'
                                    ? r('usual')
                                    : '',
                                maxLines: 1,
                                style: TextStyle(fontSize: 10, color: c.muted),
                              ),
                            ],
                          ),
                        ),
                      );
                    }(),
                ],
              );
            }(),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context, Json d) => Wrap(
    spacing: 10,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Muted('${r('legend')}:'),
      for (final x in objs(d['shifts']))
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 5, backgroundColor: atHex(str(x['color']))),
            const SizedBox(width: 4),
            Text('${str(x['name'])} ${str(x['start'])}–${str(x['end'])}', style: const TextStyle(fontSize: 12.5)),
          ],
        ),
    ],
  );
}

// ------------------------------------------------------------------------------------------------ HOLIDAYS
class HolidaysTab extends StatefulWidget {
  final AtCtx ctx;
  const HolidaysTab({super.key, required this.ctx});
  @override
  State<HolidaysTab> createState() => _HolidaysTabState();
}

class _HolidaysTabState extends State<HolidaysTab> {
  AtCtx get ctx => widget.ctx;
  late int _year = int.parse(todayKH().substring(0, 4));
  Json? _res;
  bool _busy = false;
  String _day = '';
  final _name = TextEditingController();
  String h(String k, [Map<String, Object?> v = const {}]) => ctx.t('atdy.$k', v);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/holidays', {'year': '$_year'});
      if (mounted) setState(() => _res = r);
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _run(Future<Json> Function() fn) async {
    setState(() => _busy = true);
    await ctx.run(fn);
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  void _year2(int by) {
    setState(() {
      _year += by;
      _res = null;
      _day = '';
    });
    _load();
  }

  Future<void> _rename(Json x) async {
    final ctl = TextEditingController(text: str(x['name']));
    final v = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(h('edit')),
        content: Field(controller: ctl, maxLength: 80, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(ctx.a('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(d, ctl.text.trim()), child: Text(ctx.a('save'))),
        ],
      ),
    );
    ctl.dispose();
    if (v != null && v.isNotEmpty && v != x['name']) await _run(() => ctx.api.put('${ctx.base}/holidays/${x['_id']}', {'name': v}));
  }

  Future<void> _buy() async {
    final res = _res!;
    final preset = n(res['preset']).toInt();
    final price = n(res['price']);
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BuySheet(
        stage: Container(
          width: 150,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFD86B), Color(0xFFE0A21A)]),
          ),
          child: Column(
            children: [
              const Icon(LucideIcons.calendarHeart, size: 50, color: Color(0xFF5B3A00)),
              Text(
                '$_year',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Color(0xFF3A2500)),
              ),
            ],
          ),
        ),
        badge: h('title'),
        title: h('buyTitle', {'year': _year}),
        sub: h('buySub', {'n': preset, 'year': _year}),
        perks: [
          h('perk1', {'n': preset}),
          h('perk2'),
          h('perk3', {'year': _year}),
        ],
        price: price,
        buyLabel: h('unlock', {'year': _year, 'coins': price}),
        doneTitle: h('buyTitle', {'year': _year}),
        doneSub: h('done', {'year': _year}),
        doneButton: ctx.t('app.continue'),
        buy: () => ctx.api.post('${ctx.base}/holidays/unlock', {'year': _year}),
        onDone: (_) {
          _load();
          ctx.reload();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final res = _res;
    final rows = objs(res?['data']);
    final rate = ctx.data['holiday_rate'] ?? 2;
    final months = <int, List<Json>>{};
    for (final x in rows) {
      months.putIfAbsent(int.parse(str(x['day']).substring(5, 7)), () => []).add(x);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        atPanel([
          Row(
            children: [
              Icon(LucideIcons.calendarHeart, size: 20, color: c.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(h('title'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              IconButton(onPressed: () => _year2(-1), icon: const Icon(LucideIcons.chevronLeft)),
              Text('$_year', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              IconButton(onPressed: () => _year2(1), icon: const Icon(LucideIcons.chevronRight)),
            ],
          ),
          Muted(h('sub', {'rate': rate})),
          const SizedBox(height: 6),
          Muted(h('auto')),
          if (!ctx.readOnly) ...[
            const SizedBox(height: 12),
            DayField(label: h('day'), value: _day, first: DateTime.utc(_year, 1, 1), last: DateTime.utc(_year, 12, 31), onChanged: (v) => setState(() => _day = v)),
            const SizedBox(height: 10),
            Field(label: h('name'), controller: _name, hint: h('namePh'), maxLength: 80, onChanged: (_) => setState(() {})),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Btn(
                h('save'),
                icon: LucideIcons.plus,
                small: true,
                busy: _busy,
                onTap: _busy || _day.isEmpty || _name.text.trim().isEmpty
                    ? null
                    : () async {
                        await _run(() => ctx.api.post('${ctx.base}/holidays', {'day': _day, 'name': _name.text.trim()}));
                        _name.clear();
                        setState(() => _day = '');
                      },
              ),
            ),
          ],
          if (res != null && res['locked'] == true && res['can_buy'] == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.warnBg, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.lock, size: 18, color: c.warn),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(h('lockedTitle', {'year': _year}), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(h('lockedSub', {'year': _year, 'n': n(res['preset']), 'coins': n(res['price'])})),
                  if (res['official'] != true) ...[const SizedBox(height: 6), Muted(h('soonNote'))],
                  const SizedBox(height: 10),
                  GoldBtn(h('unlock', {'year': _year, 'coins': n(res['price'])}), onTap: ctx.readOnly ? null : _buy),
                ],
              ),
            ),
          ],
          if (res != null && res['free'] == true && n(res['preset']) > 0) ...[
            const SizedBox(height: 10),
            Text(
              '✓ ${h('freeNote')}',
              style: TextStyle(color: c.good, fontWeight: FontWeight.w700),
            ),
          ],
          if (res != null && n(res['missing']) > 0 && !ctx.readOnly) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Btn(
                h('missing', {'n': n(res['missing'])}),
                icon: LucideIcons.rotateCcw,
                kind: BtnKind.ghost,
                small: true,
                onTap: _busy ? null : () => _run(() => ctx.api.post('${ctx.base}/holidays/preset', {'year': _year})),
              ),
            ),
          ],
        ]),
        mGap,
        if (res == null)
          const SkelList(rows: 4)
        else if (rows.isEmpty)
          atPanel([Muted(h('none'), align: TextAlign.center)])
        else
          atPanel([
            Align(
              alignment: Alignment.centerLeft,
              child: Chip2(h('days', {'n': rows.length}), icon: LucideIcons.calendarHeart, tone: Tone.good),
            ),
            for (final e in months.entries) ...[
              const SizedBox(height: 14),
              Text(
                ghMonthLong(e.key, ctx.lang),
                style: TextStyle(fontWeight: FontWeight.w800, color: c.muted),
              ),
              const SizedBox(height: 6),
              for (final x in e.value)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(color: x['preset'] == true ? c.dangerBg : c.active, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            Text(
                              '${int.parse(str(x['day']).substring(8, 10))}',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: x['preset'] == true ? c.danger : c.brand),
                            ),
                            Text(ghWeekday(str(x['day']), ctx.lang), style: TextStyle(fontSize: 11, color: c.muted)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(str(x['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            AtTag(x['preset'] == true ? h('preset') : h('own'), tone: x['preset'] == true ? '' : 'blue'),
                          ],
                        ),
                      ),
                      if (!ctx.readOnly) ...[
                        IconButton(tooltip: h('edit'), onPressed: _busy ? null : () => _rename(x), icon: const Icon(LucideIcons.pencilLine, size: 18)),
                        IconButton(
                          tooltip: h('remove'),
                          onPressed: _busy ? null : () => _run(() => ctx.api.delete('${ctx.base}/holidays/${x['_id']}')),
                          icon: Icon(LucideIcons.trash2, size: 18, color: c.danger),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ]),
      ],
    );
  }
}

const _monthsEn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _monthsKm = ['មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា', 'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ'];
String ghMonthLong(int m, String lang) => (lang == 'km' ? _monthsKm : _monthsEn)[m - 1];
