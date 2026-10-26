import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show todayKH, addDaysKH, money, Tiles, BarRow, MHead, mGap;
import '../restaurant/rest_common.dart' show Segmented;
import 'gh_common.dart';
import 'gh_stay.dart';

// Today · Room calendar · Bookings · Monthly report — the app version of GhDaily.jsx.

Widget _panel(List<Widget> children, {EdgeInsets padding = const EdgeInsets.all(16)}) => Panel(
  padding: padding,
  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
);

// first steps: a room type, then rooms
class _SetupCard extends StatelessWidget {
  final GhCtx ctx;
  const _SetupCard({required this.ctx});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final steps = [('type', ctx.g('stepType'), ctx.g('stepTypeSub'), ctx.types.isNotEmpty), ('room', ctx.g('stepRoom'), ctx.g('stepRoomSub'), n(ctx.counts['rooms']) > 0)];
    if (steps.every((s) => s.$4)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _panel([
        MHead(ctx.g('setupTitle'), sub: ctx.g('setupSub'), icon: LucideIcons.listChecks),
        for (final (i, (k, title, sub, ok)) in steps.indexed)
          Padding(
            key: ValueKey(k),
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
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Muted(sub),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ok ? Chip2(ctx.g('done'), tone: Tone.good) : Btn(ctx.g('go'), small: true, onTap: () => ctx.go('rooms')),
              ],
            ),
          ),
      ]),
    );
  }
}

// ------------------------------------------------------------------------------------------------ TODAY
class TodayTab extends StatefulWidget {
  final GhCtx ctx;
  const TodayTab({super.key, required this.ctx});
  @override
  State<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<TodayTab> {
  Json? _d;
  bool _busy = false;
  String _filter = '';
  Timer? _tick;
  GhCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(seconds: 60), (_) => _load());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _busy = true);
    try {
      final r = await ctx.api.get('${ctx.base}/today');
      if (mounted) setState(() => _d = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _open(Object? id) => openStay(context, ctx, str(id), onChanged: _load);
  void _book({bool walkIn = false, String? roomId}) => bookThenOpen(context, ctx, _load, walkIn: walkIn, roomId: roomId);

  Future<void> _quick(Json s, String action) async {
    try {
      await ctx.api.post('${ctx.base}/stays/${s['_id']}/$action');
      ctx.notify(action == 'check-in' ? ctx.g('checkedIn') : ctx.g('checkedOut'));
      _load();
    } catch (_) {
      _open(s['_id']); // money left to settle etc. → open the booking
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = _d;
    final ready = ctx.types.isNotEmpty && n(ctx.counts['rooms']) > 0;
    final day = d == null ? todayKH() : str(d['day']);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _SetupCard(ctx: ctx),
          _panel([
            Row(
              children: [
                Expanded(
                  child: Text(ghDayLong(todayKH(), ctx.lang), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  onPressed: _busy ? null : _load,
                  icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(LucideIcons.refreshCw, size: 17),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Btn(ctx.g('walkIn'), icon: LucideIcons.userPlus, kind: BtnKind.ghost, small: true, expand: true, onTap: ctx.readOnly || !ready ? null : () => _book(walkIn: true)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Btn(ctx.g('newBooking'), icon: LucideIcons.calendarPlus, small: true, expand: true, onTap: ctx.readOnly || !ready ? null : () => _book()),
                ),
              ],
            ),
            if (d != null) ...[
              const SizedBox(height: 14),
              () {
                final cn = obj(d['counts']);
                return Tiles([
                  ('${n(cn['occupied'])}/${n(cn['rooms'])}', ctx.g('occupied'), null),
                  ('${n(cn['free'])}', ctx.g('free'), c.good),
                  ('${n(cn['arrivals'])}', ctx.g('arrivals'), c.warn),
                  ('${n(cn['departures'])}', ctx.g('departures'), null),
                ]);
              }(),
              const SizedBox(height: 10),
              () {
                final money = obj(d['money']);
                final by = obj(money['by_method']);
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: c.goodBg, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Icon(LucideIcons.wallet, color: c.good),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ctx.mo(money['total']),
                              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: c.good),
                            ),
                            Text(
                              [ctx.g('moneyToday'), for (final e in by.entries) '${ctx.method(e.key)} ${ctx.mo(e.value)}'].join(' · '),
                              style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }(),
            ],
          ]),
          mGap,
          if (d == null)
            const SkelList(rows: 4)
          else ...[
            if (objs(d['rooms']).isNotEmpty) ...[_board(context, objs(d['rooms'])), mGap],
            _list(
              ctx.g('arrivals'),
              objs(d['arrivals']),
              ctx.g('noArrivals'),
              day,
              (s) => str(s['from']).compareTo(day) <= 0 ? Btn(ctx.g('checkIn'), icon: LucideIcons.logIn, small: true, onTap: () => _quick(s, 'check-in')) : null,
            ),
            mGap,
            _list(ctx.g('departures'), objs(d['departures']), ctx.g('noDepartures'), day, (s) => Btn(ctx.g('checkOut'), icon: LucideIcons.logOut, small: true, onTap: () => _quick(s, 'check-out'))),
            if (objs(d['in_house']).isNotEmpty) ...[mGap, _list('${ctx.g('inHouse')} (${objs(d['in_house']).length})', objs(d['in_house']), '', day, null)],
          ],
        ],
      ),
    );
  }

  Widget _list(String title, List<Json> rows, String empty, String day, Widget? Function(Json s)? action) => _panel([
    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
    const SizedBox(height: 4),
    if (rows.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Muted(empty)),
    for (final s in rows) StayRow(ctx: ctx, s: s, today: day, onTap: () => _open(s['_id']), action: ctx.readOnly ? null : action?.call(s)),
  ]);

  // room cards: colour = what is happening in the room now
  Widget _board(BuildContext context, List<Json> rooms) {
    final c = context.c;
    const states = ['free', 'arriving', 'occupied', 'due_out'];
    Color tone(String k) => switch (k) {
      'free' => c.good,
      'arriving' => const Color(0xFF2563EB),
      'occupied' => const Color(0xFF7C3AED),
      _ => c.warn,
    };
    final floors = rooms.map((r) => str(r['floor'])).toSet().toList();
    final shown = rooms.where((r) => _filter.isEmpty || r['state'] == _filter).toList();
    return _panel([
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(label: Text('${ctx.g('filterAll')} ${rooms.length}'), selected: _filter.isEmpty, onSelected: (_) => setState(() => _filter = '')),
            for (final k in states) ...[
              const SizedBox(width: 6),
              ChoiceChip(
                avatar: CircleAvatar(radius: 5, backgroundColor: tone(k)),
                label: Text('${ctx.g('states.$k')} ${rooms.where((r) => r['state'] == k).length}'),
                selected: _filter == k,
                onSelected: (_) => setState(() => _filter = _filter == k ? '' : k),
              ),
            ],
          ],
        ),
      ),
      for (final fl in floors)
        if (shown.any((r) => str(r['floor']) == fl)) ...[
          if (floors.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 2),
              child: Text(
                fl.isEmpty ? '—' : '${ctx.g('floor')} $fl',
                style: TextStyle(color: c.muted, fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (_, box) {
              final cols = box.maxWidth > 640
                  ? 4
                  : box.maxWidth > 400
                  ? 3
                  : 2;
              final w = (box.maxWidth - 8 * (cols - 1)) / cols;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in shown.where((r) => str(r['floor']) == fl))
                    SizedBox(
                      width: w,
                      child: () {
                        final st = r['stay'] == null ? null : obj(r['stay']);
                        final state = str(r['state']);
                        final col = tone(state);
                        final hk = str(r['hk']);
                        return Material(
                          color: col.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: st != null ? () => _open(st['_id']) : (ctx.readOnly ? null : () => _book(walkIn: true, roomId: str(r['_id']))),
                            child: Container(
                              height: 128,
                              padding: const EdgeInsets.fromLTRB(10, 13, 10, 10),
                              // one colour per border (Flutter can't round a border of mixed colours: the card drew blank),
                              // the room's colour as a strip on top
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: col.withValues(alpha: .25)),
                              ),
                              foregroundDecoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border(top: BorderSide(color: hexColor(str(r['color']), col), width: 4)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(str(r['name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                                      ),
                                      Text(
                                        ctx.g('states.$state'),
                                        style: TextStyle(color: col, fontWeight: FontWeight.w800, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    str(r['type']),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: c.muted, fontSize: 12),
                                  ),
                                  const Spacer(),
                                  if (st != null) ...[
                                    Text(
                                      str(obj(st['guest'])['name']),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      '${ghDay(str(st['from']), ctx.lang)} → ${ghDay(str(st['to']), ctx.lang)} · ${ctx.g('nights', {'n': n(obj(st['bill'])['nights'])})}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: c.muted, fontSize: 11.5),
                                    ),
                                    if (n(obj(st['bill'])['balance']) > 0)
                                      Text(
                                        ctx.mo(obj(st['bill'])['balance']),
                                        style: TextStyle(color: c.danger, fontWeight: FontWeight.w800, fontSize: 12),
                                      ),
                                  ] else ...[
                                    Icon(LucideIcons.doorOpen, size: 22, color: col),
                                    Text(
                                      r['next'] != null ? ctx.g('nextBooking', {'date': ghDay(str(obj(r['next'])['from']), ctx.lang)}) : ' ',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: c.muted, fontSize: 11.5),
                                    ),
                                  ],
                                  if (hk.isNotEmpty && hk != 'ready')
                                    Text(
                                      '🧹 ${ctx.t.or('gh.hkStates.$hk', hk)}',
                                      style: TextStyle(fontSize: 11, color: c.warn, fontWeight: FontWeight.w700),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }(),
                    ),
                ],
              );
            },
          ),
        ],
    ]);
  }
}

// ------------------------------------------------------------------------------------------------ CALENDAR
const _days = 14;

class CalendarTab extends StatefulWidget {
  final GhCtx ctx;
  const CalendarTab({super.key, required this.ctx});
  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  String _start = addDaysKH(todayKH(), -1);
  List<Json>? _stays;
  GhCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final start = _start;
    try {
      final r = await ctx.api.get('${ctx.base}/stays', {'from': start, 'to': addDaysKH(start, _days)});
      if (mounted && start == _start) setState(() => _stays = objs(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  void _move(String to) {
    setState(() {
      _start = to;
      _stays = null;
    });
    _load();
  }

  int _idx(String day) => nightsOf(_start, day);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rooms = ctx.rooms.where((r) => r['active'] == true).toList();
    final today = todayKH();
    final days = [for (var i = 0; i < _days; i++) addDaysKH(_start, i)];
    const cellW = 46.0, roomW = 78.0, rowH = 48.0;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _panel([
            MHead(ctx.g('calTitle'), sub: ctx.g('calSub'), icon: LucideIcons.calendarRange),
            Row(
              children: [
                IconButton(onPressed: () => _move(addDaysKH(_start, -7)), icon: const Icon(LucideIcons.chevronLeft, size: 18)),
                Expanded(
                  child: Center(
                    child: Btn(ctx.g('thisWeek'), kind: BtnKind.ghost, small: true, onTap: () => _move(addDaysKH(todayKH(), -1))),
                  ),
                ),
                IconButton(onPressed: () => _move(addDaysKH(_start, 7)), icon: const Icon(LucideIcons.chevronRight, size: 18)),
              ],
            ),
          ]),
          mGap,
          if (_stays == null)
            const SkelList(rows: 5)
          else if (rooms.isEmpty)
            _panel([
              Muted(ctx.g('noRooms')),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Btn(ctx.g('addRooms'), icon: LucideIcons.plus, small: true, onTap: () => ctx.go('rooms')),
              ),
            ])
          else
            _panel(padding: const EdgeInsets.fromLTRB(10, 12, 10, 14), [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: roomW + cellW * _days,
                  child: Column(
                    children: [
                      // day heads
                      Row(
                        children: [
                          const SizedBox(width: roomW),
                          for (final d in days)
                            Container(
                              width: cellW,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(color: d == today ? c.active : null, borderRadius: BorderRadius.circular(10)),
                              child: Column(
                                children: [
                                  Text(
                                    ghWeekday(d, ctx.lang),
                                    style: TextStyle(fontSize: 11, color: ghWeekend(d) ? c.danger : c.muted, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${int.parse(d.substring(8))}',
                                    style: TextStyle(fontWeight: FontWeight.w800, color: d == today ? c.brandInk : c.ink),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      for (final r in rooms)
                        () {
                          final t = ctx.typeOf(r['type_id']);
                          final col = hexColor(str(t?['color']), const Color(0xFF2563EB));
                          final mine = _stays!.where((s) => s['room_id'] == r['_id']).toList();
                          return Container(
                            height: rowH,
                            decoration: BoxDecoration(
                              border: Border(top: BorderSide(color: c.line)),
                            ),
                            child: Stack(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: roomW,
                                      padding: const EdgeInsets.only(left: 6),
                                      decoration: BoxDecoration(
                                        border: Border(left: BorderSide(color: col, width: 3)),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(str(r['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                                          Text(
                                            str(t?['name']),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 11, color: c.muted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    for (final d in days)
                                      InkWell(
                                        onTap: ctx.readOnly || d.compareTo(addDaysKH(today, -1)) < 0
                                            ? null
                                            : () => bookThenOpen(context, ctx, _load, roomId: str(r['_id']), from: d, to: addDaysKH(d, 1)),
                                        child: Container(width: cellW, height: rowH, color: d == today ? c.active.withValues(alpha: .35) : (ghWeekend(d) ? c.bg2.withValues(alpha: .6) : null)),
                                      ),
                                  ],
                                ),
                                for (final s in mine)
                                  () {
                                    final a = _idx(str(s['from'])).clamp(0, _days);
                                    final z = _idx(str(s['to'])).clamp(0, _days);
                                    if (z <= a) return const SizedBox.shrink();
                                    final st = str(s['status']);
                                    final bg = switch (st) {
                                      'in' => col,
                                      'out' => c.muted.withValues(alpha: .45),
                                      _ => col.withValues(alpha: .22),
                                    };
                                    final fg = st == 'booked' ? c.ink : Colors.white;
                                    return Positioned(
                                      left: roomW + a * cellW + 2,
                                      width: (z - a) * cellW - 4,
                                      top: 8,
                                      bottom: 8,
                                      child: Material(
                                        color: bg,
                                        borderRadius: BorderRadius.horizontal(left: Radius.circular(_idx(str(s['from'])) < 0 ? 2 : 10), right: Radius.circular(_idx(str(s['to'])) > _days ? 2 : 10)),
                                        child: InkWell(
                                          onTap: () => openStay(context, ctx, str(s['_id']), onChanged: _load),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7),
                                            decoration: st == 'booked'
                                                ? BoxDecoration(
                                                    border: Border.all(color: col, width: 1.4),
                                                    borderRadius: BorderRadius.circular(10),
                                                  )
                                                : null,
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    str(obj(s['guest'])['name']),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: fg),
                                                  ),
                                                ),
                                                if (n(obj(s['bill'])['balance']) > 0)
                                                  Container(
                                                    width: 7,
                                                    height: 7,
                                                    decoration: BoxDecoration(color: c.danger, shape: BoxShape.circle),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }(),
                              ],
                            ),
                          );
                        }(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  for (final (k, bg, border) in [
                    ('booked', const Color(0xFF2563EB).withValues(alpha: .22), const Color(0xFF2563EB)),
                    ('in', const Color(0xFF2563EB), null),
                    ('out', c.muted.withValues(alpha: .45), null),
                  ])
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 10,
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(4),
                            border: border == null ? null : Border.all(color: border),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(ctx.g('status.$k'), style: TextStyle(fontSize: 12.5, color: c.muted)),
                      ],
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: c.danger, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(ctx.g('balance'), style: TextStyle(fontSize: 12.5, color: c.muted)),
                    ],
                  ),
                ],
              ),
            ]),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ BOOKINGS
class BookingsTab extends StatefulWidget {
  final GhCtx ctx;
  const BookingsTab({super.key, required this.ctx});
  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  final _q = TextEditingController();
  String _status = '';
  List<Json>? _rows;
  Timer? _wait;
  GhCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _wait?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/stays', {if (_q.text.trim().isNotEmpty) 'q': _q.text.trim(), if (_status.isNotEmpty) 'status': _status});
      if (mounted) setState(() => _rows = objs(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _panel([
            Row(
              children: [
                Expanded(
                  child: Field(
                    controller: _q,
                    hint: ctx.g('search'),
                    icon: LucideIcons.search,
                    onChanged: (_) {
                      _wait?.cancel();
                      _wait = Timer(const Duration(milliseconds: 300), _load);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Btn(ctx.g('newBooking'), icon: LucideIcons.calendarPlus, small: true, onTap: ctx.readOnly || n(ctx.counts['rooms']) == 0 ? null : () => bookThenOpen(context, ctx, _load)),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Segmented<String>(
                value: _status,
                options: [
                  for (final k in ['', 'booked', 'in', 'out', 'cancelled', 'no_show']) (k, k.isEmpty ? ctx.g('all') : ctx.g('status.$k')),
                ],
                onChanged: (v) {
                  setState(() {
                    _status = v;
                    _rows = null;
                  });
                  _load();
                },
              ),
            ),
          ]),
          mGap,
          if (rows == null)
            const SkelList(rows: 5)
          else if (rows.isEmpty)
            _panel([Muted(ctx.g('noBookings'), align: TextAlign.center)])
          else
            _panel(padding: const EdgeInsets.fromLTRB(12, 8, 12, 8), [
              for (final s in rows)
                StayRow(
                  ctx: ctx,
                  s: s,
                  showNo: true,
                  showTotal: true,
                  showStatus: true,
                  onTap: () => openStay(context, ctx, str(s['_id']), onChanged: _load),
                ),
            ]),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ REPORT
class ReportTab extends StatefulWidget {
  final GhCtx ctx;
  const ReportTab({super.key, required this.ctx});
  @override
  State<ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<ReportTab> {
  final _now = todayKH().substring(0, 7);
  late String _month = _now;
  Json? _r;
  GhCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = _month;
    try {
      final r = await ctx.api.get('${ctx.base}/report', {'month': m});
      if (mounted && m == _month) setState(() => _r = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  void _go(int by) {
    setState(() {
      _month = shiftMonth(_month, by);
      _r = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = _r;
    final cur = r == null || str(r['currency']).isEmpty ? ctx.cur : str(r['currency']);
    String mo(Object? v) => money(v, cur);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _panel([
            MHead(ctx.g('repTitle'), icon: LucideIcons.chartColumn),
            Row(
              children: [
                IconButton(onPressed: () => _go(-1), icon: const Icon(LucideIcons.chevronLeft, size: 18)),
                Expanded(
                  child: Text(
                    _month == _now ? ctx.g('thisMonth') : ghMonth(_month, ctx.lang),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(onPressed: _month.compareTo(_now) >= 0 ? null : () => _go(1), icon: const Icon(LucideIcons.chevronRight, size: 18)),
              ],
            ),
            if (r != null) ...[
              const SizedBox(height: 8),
              Tiles([
                ('${n(r['occupancy'])}%', ctx.g('occupancy'), null),
                ('${n(r['nights'])}', ctx.g('nightsSold'), null),
                (mo(r['adr']), ctx.g('adr'), null),
                (mo(r['received']), ctx.g('received'), c.good),
              ]),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: c.goodBg, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mo(n(r['room_revenue']) + n(r['extras'])),
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: c.good),
                    ),
                    Text(
                      '${ctx.g('roomRevenue')} ${mo(r['room_revenue'])} · ${ctx.g('extrasRevenue')} ${mo(r['extras'])}',
                      style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ]),
          mGap,
          if (r == null)
            const SkelList(rows: 4)
          else ...[
            _panel([
              Text(ctx.g('occupancy'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              () {
                final days = objs(r['days']);
                final rooms = n(r['rooms']);
                return _OccChart(values: [for (final d in days) rooms == 0 ? 0 : (n(d['occupied']) / rooms * 100).round()], days: [for (final d in days) str(d['day'])]);
              }(),
            ]),
            mGap,
            _panel([
              Text(ctx.g('byType'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              () {
                final list = objs(r['by_type']);
                final top = list.fold<num>(0, (a, x) => n(x['revenue']) > a ? n(x['revenue']) : a);
                return Column(
                  children: [
                    if (list.isEmpty) const Muted('—'),
                    for (final t in list) BarRow(label: str(t['name']), sub: ctx.g('nights', {'n': n(t['nights'])}), value: mo(t['revenue']), pct: top == 0 ? 0 : n(t['revenue']) / top * 100),
                  ],
                );
              }(),
            ]),
            mGap,
            _panel([
              Text(ctx.g('byMethod'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              () {
                final by = obj(r['by_method']);
                final sum = by.values.fold<num>(0, (a, v) => a + n(v));
                return Column(
                  children: [
                    if (by.isEmpty) const Muted('—'),
                    for (final e in by.entries) BarRow(label: ctx.method(e.key), value: mo(e.value), pct: sum == 0 ? 0 : n(e.value) / sum * 100),
                  ],
                );
              }(),
            ]),
            if (objs(r['by_room']).isNotEmpty) ...[
              mGap,
              _panel([
                Text(ctx.g('byRoom'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    horizontalMargin: 4,
                    columnSpacing: 18,
                    headingRowHeight: 38,
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 52,
                    headingTextStyle: TextStyle(fontWeight: FontWeight.w800, color: c.muted, fontSize: 12.5),
                    columns: [
                      DataColumn(label: Text(ctx.g('roomCol'))),
                      DataColumn(label: Text(ctx.g('nightsCol')), numeric: true),
                      DataColumn(label: Text(ctx.g('occCol'))),
                      DataColumn(label: Text(ctx.g('staysCol')), numeric: true),
                      DataColumn(label: Text(ctx.g('revenueCol')), numeric: true),
                      DataColumn(label: Text(ctx.g('extrasCol')), numeric: true),
                    ],
                    rows: [
                      for (final x in objs(r['by_room']))
                        DataRow(
                          cells: [
                            DataCell(
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: str(x['name']),
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                    TextSpan(
                                      text: '  ${str(x['type'])}',
                                      style: TextStyle(color: c.muted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(Text('${n(x['nights'])}')),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 70,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(99),
                                      child: LinearProgressIndicator(
                                        value: (n(x['occupancy']) / 100).clamp(0, 1).toDouble(),
                                        minHeight: 6,
                                        color: n(x['occupancy']) >= 80 ? c.good : c.brand,
                                        backgroundColor: c.bg2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text('${n(x['occupancy'])}%', style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                            DataCell(Text('${n(x['stays'])}')),
                            DataCell(Text(mo(x['revenue']), style: const TextStyle(fontWeight: FontWeight.w800))),
                            DataCell(Text(mo(x['extras']))),
                          ],
                        ),
                    ],
                  ),
                ),
              ]),
            ],
          ],
        ],
      ),
    );
  }
}

// occupancy per day: bars out of 100 %, a day number every 5 days
class _OccChart extends StatelessWidget {
  final List<int> values;
  final List<String> days;
  const _OccChart({required this.values, required this.days});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, v) in values.indexed)
            Expanded(
              child: Tooltip(
                message: '${days[i]} · $v%',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: (v < 2 ? 2 : v) / 100,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1.2),
                            decoration: BoxDecoration(
                              color: v >= 80 ? c.good : (v == 0 ? c.bg2 : c.brand),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 14,
                      child: Text(
                        i == 0 || (i + 1) % 5 == 0 ? '${i + 1}' : '',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: TextStyle(fontSize: 10, color: c.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
