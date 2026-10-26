import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show todayKH, addDaysKH, mTime, mDayTime, fileForm, SureDelete;
import '../mart/mart_kit.dart' show DayField, decimalKeys, numOf;
import 'gh_common.dart';
import 'gh_extra.dart' show MemberBox, openReviewShare;
import 'gh_receipt.dart';

// A booking: new booking / walk-in, and one stay with its bill — the app version of GhStay.jsx.

const svcEmoji = {'laundry': '🧺', 'bike': '🛵', 'tour': '🗺️', 'minibar': '🥤', 'food': '🍳', 'coffee': '☕', 'transfer': '🚐', 'spa': '💆', 'other': '✨'};

// which rooms are taken from → to (live stays block; the departure day is free)
Future<Set<String>> busyRooms(GhCtx ctx, String from, String to, [String? except]) async {
  if (from.isEmpty || to.compareTo(from) <= 0) return {};
  try {
    final r = await ctx.api.get('${ctx.base}/stays', {'from': from, 'to': to});
    return {
      for (final s in objs(r['data']))
        if (['booked', 'in'].contains(s['status']) && s['_id'] != except) str(s['room_id']),
    };
  } catch (_) {
    return {};
  }
}

Future<Json?> openBook(BuildContext context, GhCtx ctx, {bool walkIn = false, String? roomId, String? from, String? to}) => showModalBottomSheet<Json>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _BookSheet(ctx: ctx, walkIn: walkIn, roomId: roomId, from: from, to: to),
);

Future<void> openStay(BuildContext context, GhCtx ctx, String id, {VoidCallback? onChanged}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _StaySheet(ctx: ctx, id: id, onChanged: onChanged),
);

// a new booking, then straight into it (the web's useStayModals)
Future<void> bookThenOpen(BuildContext context, GhCtx ctx, VoidCallback onChanged, {bool walkIn = false, String? roomId, String? from, String? to}) async {
  final s = await openBook(context, ctx, walkIn: walkIn, roomId: roomId, from: from, to: to);
  if (s == null) return;
  onChanged();
  if (context.mounted) await openStay(context, ctx, str(s['_id']), onChanged: onChanged);
}

// ------------------------------------------------------------------------------------------- room tiles
class RoomPicker extends StatelessWidget {
  final GhCtx ctx;
  final String value;
  final Set<String>? busy;
  final void Function(Json room, Json? type) onPick;
  const RoomPicker({super.key, required this.ctx, required this.value, required this.busy, required this.onPick});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (busy == null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final rooms = ctx.rooms.where((r) => r['active'] == true && r['usable'] != false).toList();
    final free = rooms.where((r) => !busy!.contains(r['_id']) || r['_id'] == value).toList();
    if (free.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Alert(ctx.g('noFree'), tone: Tone.warn),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in ctx.types)
          for (final r in free.where((r) => r['type_id'] == t['_id']))
            () {
              final on = r['_id'] == value;
              final col = hexColor(str(t['color']), const Color(0xFF2563EB));
              return Material(
                color: on ? col.withValues(alpha: .14) : c.bg2,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onPick(r, t),
                  child: Container(
                    width: 104,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: on ? col : c.line, width: on ? 2 : 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(str(r['name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            ),
                            if (on) Icon(LucideIcons.circleCheck, size: 16, color: col),
                          ],
                        ),
                        Text(
                          str(t['name']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.muted, fontSize: 12),
                        ),
                        Text(
                          '${ctx.mo(t['price'])} ${ctx.g('perNight')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: col),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }(),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------- guest
class GuestForm {
  final name = TextEditingController(), phone = TextEditingController(), idNumber = TextEditingController(), nationality = TextEditingController(), visaType = TextEditingController();
  String idType = 'id_card', gender = '', dob = '', visaUntil = '';
  int adults = 1, children = 0;
  GuestForm([Json? g, int a = 1, int ch = 0]) {
    final x = g ?? const {};
    name.text = str(x['name']);
    phone.text = str(x['phone']);
    idNumber.text = str(x['id_number']);
    nationality.text = str(x['nationality']);
    visaType.text = str(x['visa_type']);
    idType = str(x['id_type']).isEmpty ? 'id_card' : str(x['id_type']);
    gender = str(x['gender']);
    dob = str(x['dob']);
    visaUntil = str(x['visa_until']);
    adults = a < 1 ? 1 : a;
    children = ch;
  }
  void fill(Json h) {
    name.text = str(h['name']);
    phone.text = str(h['phone']);
    idType = str(h['id_type']).isEmpty ? 'id_card' : str(h['id_type']);
    idNumber.text = str(h['id_number']);
    nationality.text = str(h['nationality']);
    gender = str(h['gender']);
    dob = str(h['dob']);
    visaType.text = str(h['visa_type']);
    visaUntil = str(h['visa_until']);
  }

  Json get body => {
    'name': name.text.trim(),
    'phone': phone.text.trim(),
    'id_type': idType,
    'id_number': idNumber.text.trim(),
    'nationality': nationality.text.trim(),
    'gender': gender,
    'dob': dob,
    'visa_type': visaType.text.trim(),
    'visa_until': visaUntil,
  };
  bool get hasMore => idNumber.text.isNotEmpty || nationality.text.isNotEmpty;
  void dispose() {
    for (final c in [name, phone, idNumber, nationality, visaType]) {
      c.dispose();
    }
  }
}

class GuestFields extends StatefulWidget {
  final GhCtx ctx;
  final GuestForm f;
  final bool lookup;
  final VoidCallback onChanged;
  const GuestFields({super.key, required this.ctx, required this.f, required this.onChanged, this.lookup = true});
  @override
  State<GuestFields> createState() => _GuestFieldsState();
}

class _GuestFieldsState extends State<GuestFields> {
  List<Json> _hits = [];
  Timer? _wait;
  late bool _more = widget.f.hasMore || (_police && widget.f.idType == 'passport');
  GhCtx get ctx => widget.ctx;
  GuestForm get f => widget.f;
  bool get _police => ctx.addonOn('gh_police') || ctx.data['police'] == true;

  @override
  void dispose() {
    _wait?.cancel();
    super.dispose();
  }

  void _find() {
    widget.onChanged();
    if (!widget.lookup) return;
    _wait?.cancel();
    final q = f.name.text.trim().length >= 2 ? f.name.text : (f.phone.text.trim().length >= 3 ? f.phone.text : '');
    if (q.isEmpty) return setState(() => _hits = []);
    _wait = Timer(const Duration(milliseconds: 300), () async {
      try {
        final r = await ctx.api.get('${ctx.base}/guests', {'q': q});
        if (mounted) setState(() => _hits = objs(r['data']));
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final shown = _hits.where((h) => !(h['name'] == f.name.text && str(h['phone']) == f.phone.text)).take(4).toList();
    Widget two(Widget a, Widget b) => LayoutBuilder(
      builder: (_, box) => box.maxWidth > 460
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: a),
                const SizedBox(width: 10),
                Expanded(child: b),
              ],
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, const SizedBox(height: 12), b]),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        two(
          Field(label: '${ctx.g('guestName')} *', controller: f.name, hint: 'Sok Dara', maxLength: 80, onChanged: (_) => _find()),
          Field(label: ctx.g('phone'), controller: f.phone, hint: '012 345 678', maxLength: 30, keyboard: TextInputType.phone, onChanged: (_) => _find()),
        ),
        if (shown.isNotEmpty) ...[
          const SizedBox(height: 8),
          Muted(ctx.g('past')),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final h in shown)
                ActionChip(
                  avatar: const Icon(LucideIcons.userRound, size: 14),
                  label: Text('${str(h['name'])}${str(h['phone']).isNotEmpty ? ' · ${h['phone']}' : ''}'),
                  onPressed: () {
                    f.fill(h);
                    setState(() => _hits = []);
                    widget.onChanged();
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ctx.g('adults'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Stepper2(
                  value: f.adults,
                  min: 1,
                  max: 20,
                  onChanged: (v) => setState(() {
                    f.adults = v;
                    widget.onChanged();
                  }),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ctx.g('children'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Stepper2(
                  value: f.children,
                  max: 20,
                  onChanged: (v) => setState(() {
                    f.children = v;
                    widget.onChanged();
                  }),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => setState(() => _more = !_more),
              icon: Icon(_more ? LucideIcons.minus : LucideIcons.plus, size: 15),
              label: Text('${ctx.g('idType')} / ${ctx.g('nationality')}'),
            ),
          ],
        ),
        if (_more) ...[
          const SizedBox(height: 8),
          Chips<String>(
            options: [for (final k in ctx.list('id_types')) (k, ctx.g('idTypes.$k'))],
            on: (k) => f.idType == k,
            onTap: (k) => setState(() {
              f.idType = k;
              widget.onChanged();
            }),
          ),
          const SizedBox(height: 12),
          two(Field(label: ctx.g('idNumber'), controller: f.idNumber, maxLength: 40), Field(label: ctx.g('nationality'), controller: f.nationality, hint: 'Cambodia', maxLength: 40)),
          if (_police) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.bg2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Muted(ctx.g('passportBox')),
                  const SizedBox(height: 10),
                  Label(ctx.g('gender')),
                  Chips<String>(
                    options: [
                      for (final k in ['m', 'f']) (k, ctx.g('genders.$k')),
                    ],
                    on: (k) => f.gender == k,
                    onTap: (k) => setState(() => f.gender = f.gender == k ? '' : k),
                  ),
                  const SizedBox(height: 12),
                  DayField(label: ctx.g('dob'), value: f.dob, last: DateTime.now(), first: DateTime(1920), onChanged: (v) => setState(() => f.dob = v)),
                  const SizedBox(height: 12),
                  two(
                    Field(label: ctx.g('visaType'), controller: f.visaType, hint: 'T · E · K', maxLength: 30),
                    DayField(label: ctx.g('visaUntil'), value: f.visaUntil, onChanged: (v) => setState(() => f.visaUntil = v)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

// a numbered step title (✓ when done)
class _Step extends StatelessWidget {
  final String n, title;
  final bool done;
  const _Step(this.n, this.title, this.done);
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: done ? c.good : c.active, shape: BoxShape.circle),
            child: done
                ? const Icon(LucideIcons.check, size: 14, color: Colors.white)
                : Text(
                    n,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: c.brandInk),
                  ),
          ),
          const SizedBox(width: 9),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------- new booking / walk-in
class _BookSheet extends StatefulWidget {
  final GhCtx ctx;
  final bool walkIn;
  final String? roomId, from, to;
  const _BookSheet({required this.ctx, required this.walkIn, this.roomId, this.from, this.to});
  @override
  State<_BookSheet> createState() => _BookSheetState();
}

class _BookSheetState extends State<_BookSheet> {
  final today = todayKH();
  late String _from, _to, _room, _source, _method;
  final _rate = TextEditingController(), _deposit = TextEditingController(), _note = TextEditingController();
  final _guest = GuestForm();
  Set<String>? _busy;
  bool _saving = false;
  String _error = '';
  GhCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    final room = ctx.roomOf(widget.roomId);
    final type = room == null ? null : ctx.typeOf(room['type_id']);
    _from = widget.walkIn ? today : (widget.from ?? today);
    _to = widget.to ?? addDaysKH(_from, 1);
    _room = widget.roomId ?? '';
    if (type != null) _rate.text = _num(type['price']);
    _source = widget.walkIn ? 'walk_in' : 'phone';
    _method = ctx.methods.first;
    _loadBusy();
  }

  @override
  void dispose() {
    _rate.dispose();
    _deposit.dispose();
    _note.dispose();
    _guest.dispose();
    super.dispose();
  }

  String _num(Object? v) {
    final x = n(v);
    return x == x.roundToDouble() ? '${x.toInt()}' : '$x';
  }

  Future<void> _loadBusy() async {
    setState(() => _busy = null);
    final from = _from, to = _to;
    final b = await busyRooms(ctx, from, to);
    if (!mounted || from != _from || to != _to) return;
    setState(() {
      _busy = b;
      if (b.contains(_room)) _room = '';
    });
  }

  int get _nights => _to.compareTo(_from) > 0 ? nightsOf(_from, _to) : 0;
  num get _total => _nights * (numOf(_rate.text) ?? 0);

  void _setNights(int v) {
    _to = addDaysKH(_from, v.clamp(1, 366));
    _loadBusy();
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      final r = await ctx.api.post('${ctx.base}/stays', {
        'from': _from,
        'to': _to,
        'room_id': _room,
        'rate': numOf(_rate.text) ?? 0,
        'guest': _guest.body,
        'adults': _guest.adults,
        'children': _guest.children,
        'source': _source,
        'note': _note.text.trim(),
        'deposit': numOf(_deposit.text) ?? 0,
        'method': _method,
        'check_in_now': widget.walkIn,
      });
      final s = obj(r['data']);
      ctx.notify(widget.walkIn ? ctx.g('checkedIn') : ctx.g('booked', {'no': s['no']}));
      if (mounted) Navigator.pop(context, s);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.network ? ctx.t('app.offline') : e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final nights = _nights;
    final total = _total;
    final rate = numOf(_rate.text) ?? 0;
    final dep = numOf(_deposit.text) ?? 0;
    final room = ctx.roomOf(_room);
    final can = _room.isNotEmpty && nights > 0 && _guest.name.text.trim().isNotEmpty && _rate.text.trim().isNotEmpty && !_saving;
    Widget quick(String label, num v) => ChoiceChip(label: Text(label), selected: dep == v, onSelected: (_) => setState(() => _deposit.text = v == 0 ? '' : _num(v)));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: widget.walkIn ? c.goodBg : c.active, borderRadius: BorderRadius.circular(14)),
                  child: Icon(widget.walkIn ? LucideIcons.userPlus : LucideIcons.calendarPlus, size: 21, color: widget.walkIn ? c.good : c.brandInk),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.walkIn ? ctx.g('walkIn') : ctx.g('bookTitle'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      Muted(widget.walkIn ? ctx.g('checkInNow') : ctx.g('bookSub')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Step('1', ctx.g('stayDates'), nights > 0),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: widget.walkIn
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Label(ctx.g('arrive')),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                                    decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(18)),
                                    child: Text(ghDay(_from, ctx.lang, weekday: true), style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              )
                            : DayField(
                                label: ctx.g('arrive'),
                                value: _from,
                                first: DateTime.parse(addDaysKH(today, -1)),
                                onChanged: (v) {
                                  if (v.isEmpty) return;
                                  final keep = nights < 1 ? 1 : nights;
                                  _from = v;
                                  _to = addDaysKH(v, keep);
                                  _loadBusy();
                                },
                              ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        children: [
                          Text(
                            ctx.g('nightsLabel'),
                            style: TextStyle(fontSize: 12, color: c.muted, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Stepper2(value: nights, min: 1, max: 366, onChanged: _setNights),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DayField(
                    label: ctx.g('leave'),
                    value: _to,
                    first: DateTime.parse(addDaysKH(_from, 1)),
                    onChanged: (v) {
                      if (v.isEmpty) return;
                      _to = v;
                      _loadBusy();
                    },
                  ),
                  _Step('2', ctx.g('room'), _room.isNotEmpty),
                  RoomPicker(
                    ctx: ctx,
                    value: _room,
                    busy: _busy,
                    onPick: (r, t) => setState(() {
                      final sameType = _room.isNotEmpty && ctx.roomOf(_room)?['type_id'] == t?['_id'];
                      _room = str(r['_id']);
                      if (!sameType && t != null) _rate.text = _num(t['price']);
                    }),
                  ),
                  _Step('3', ctx.g('guest'), _guest.name.text.trim().isNotEmpty),
                  GuestFields(ctx: ctx, f: _guest, onChanged: () => setState(() {})),
                  if (!widget.walkIn) ...[
                    const SizedBox(height: 16),
                    Label(ctx.g('source')),
                    Chips<String>(
                      options: [for (final k in ctx.list('sources').where((k) => k != 'walk_in')) (k, ctx.g('sources.$k'))],
                      on: (k) => _source == k,
                      onTap: (k) => setState(() => _source = k),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Field(label: ctx.g('note'), controller: _note, maxLength: 500),
                  _Step('4', ctx.g('payNow'), dep > 0),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(room != null ? '${ctx.g('room')} ${str(room['name'])}' : ctx.g('pickRoom'), style: TextStyle(color: c.muted)),
                            ),
                            Text('${ghDay(_from, ctx.lang)} → ${ghDay(_to, ctx.lang)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(ctx.g('rate'), style: TextStyle(color: c.muted)),
                            ),
                            SizedBox(
                              width: 130,
                              child: Field(
                                controller: _rate,
                                keyboard: decimalKeys,
                                align: TextAlign.right,
                                suffix: SizedBox(width: 48, child: Center(child: Text(ctx.cur))),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: Text(ctx.g('nights', {'n': nights}))),
                            Text(ctx.mo(total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Field(
                    label: ctx.g('deposit'),
                    controller: _deposit,
                    hint: '0',
                    keyboard: decimalKeys,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.ink),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [quick('0', 0), if (rate > 0 && nights > 1) quick('${ctx.g('oneNight')} · ${ctx.mo(rate)}', rate), if (total > 0) quick('${ctx.g('payAll')} · ${ctx.mo(total)}', total)],
                  ),
                  if (dep > 0) ...[
                    const SizedBox(height: 10),
                    Chips<String>(options: [for (final k in ctx.methods) (k, ctx.method(k))], on: (k) => _method == k, onTap: (k) => setState(() => _method = k)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(ctx.g('balance'), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      Text(
                        ctx.mo((total - dep) < 0 ? 0 : total - dep),
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: total - dep > 0 ? c.danger : c.good),
                      ),
                    ],
                  ),
                  if (_error.isNotEmpty) ...[const SizedBox(height: 12), Alert(_error)],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.line)),
            ),
            child: Row(
              children: [
                Btn(ctx.g('cancel'), kind: BtnKind.ghost, small: true, onTap: _saving ? null : () => Navigator.pop(context)),
                const SizedBox(width: 10),
                Expanded(
                  child: Btn(
                    _saving
                        ? ctx.g('saving')
                        : widget.walkIn
                        ? ctx.g('checkInNow')
                        : ctx.g('book'),
                    icon: widget.walkIn ? LucideIcons.logIn : LucideIcons.calendarRange,
                    busy: _saving,
                    expand: true,
                    onTap: can ? _submit : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------- one stay
class _StaySheet extends StatefulWidget {
  final GhCtx ctx;
  final String id;
  final VoidCallback? onChanged;
  const _StaySheet({required this.ctx, required this.id, this.onChanged});
  @override
  State<_StaySheet> createState() => _StaySheetState();
}

class _StaySheetState extends State<_StaySheet> {
  Json? _s;
  bool _busy = false, _edit = false;
  String _error = '';
  Json? _ask; // a refused check-out: { code, balance, nights, total }
  Json? _charge; // {label, amount, qty}
  Json? _pay; // {method, amount, note}
  final _disc = TextEditingController();
  final _cLabel = TextEditingController(), _cAmount = TextEditingController(), _cQty = TextEditingController(text: '1');
  final _pAmount = TextEditingController(), _pNote = TextEditingController();
  GhCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_disc, _cLabel, _cAmount, _cQty, _pAmount, _pNote]) {
      c.dispose();
    }
    super.dispose();
  }

  void _set(Json s) {
    _s = s;
    final d = n(s['discount']);
    _disc.text = d == 0 ? '' : (d == d.roundToDouble() ? '${d.toInt()}' : '$d');
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/stays/${widget.id}');
      if (mounted) setState(() => _set(obj(r['data'])));
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  // one change; the answer is the new stay
  Future<Json?> _run(Future<Json> Function() fn, [String? ok]) async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final r = await fn();
      final d = obj(r['data']);
      if (mounted && d['_id'] != null) setState(() => _set(d));
      if (ok != null) ctx.notify(ok);
      widget.onChanged?.call();
      return r;
    } on ApiError catch (e) {
      final code = str(e.body['code']);
      if (e.status == 409 && ['unpaid', 'refund'].contains(code)) {
        if (mounted) setState(() => _ask = {'code': code, 'balance': e.body['balance'], 'nights': e.body['nights'], 'total': e.body['total']});
      } else if (e.status == 402 && e.body['product'] != null) {
        ctx.askBuy(str(e.body['product']));
      } else if (mounted) {
        setState(() => _error = e.network ? ctx.t('app.offline') : e.message);
      }
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _sp => '${ctx.base}/stays/${widget.id}';

  Future<void> _checkOut([Json body = const {}]) async {
    final r = await _run(() => ctx.api.post('$_sp/check-out', body), ctx.g('checkedOut'));
    final pc = ctx.print;
    if (r != null && pc['on'] == true && pc['auto'] == true && mounted) _printBill();
  }

  void _printBill() {
    if (ctx.print['on'] != true) {
      ctx.askBuy('gh_printer');
      return;
    }
    showGhBill(context, ctx, _s!);
  }

  Future<void> _addIdPhoto() async {
    final b = await ghPickPicture(context, ctx, cameraFirst: true);
    if (b == null) return;
    await _run(() => ctx.api.post('$_sp/id-photos', fileForm('photo', b, 'id.jpg')));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = _s;
    if (s == null) {
      return SizedBox(
        height: 260,
        child: Center(
          child: _error.isNotEmpty ? Padding(padding: const EdgeInsets.all(20), child: Alert(_error)) : const CircularProgressIndicator(),
        ),
      );
    }
    final today = todayKH();
    final b = obj(s['bill']);
    final status = str(s['status']);
    final live = ['booked', 'in'].contains(status);
    final lease = s['lease'] != null;
    final type = ctx.typeOf(s['type_id']);
    final open = !ctx.readOnly && status != 'cancelled';
    final guest = obj(s['guest']);
    final col = hexColor(str(type?['color']), const Color(0xFF2563EB));
    final balance = n(b['balance']);
    final photos = objs(s['id_photos']);

    final info = [
      str(guest['phone']),
      if (str(guest['id_number']).isNotEmpty) '${ctx.g('idTypes.${guest['id_type']}')} ${guest['id_number']}',
      str(guest['nationality']),
    ].where((x) => x.isNotEmpty).join(' · ');
    final dates = lease
        ? '🔑 ${ghDay(str(s['from']), ctx.lang, year: true)} → ${str(obj(s['lease'])['end']).isEmpty ? '…' : ghDay(str(obj(s['lease'])['end']), ctx.lang, year: true)}'
        : '${ghDay(str(s['from']), ctx.lang, weekday: true)} → ${ghDay(str(s['to']), ctx.lang, weekday: true)} · ${ctx.g('nights', {'n': n(b['nights'])})}';
    final people = '${n(s['adults']).toInt()}${n(s['children']) > 0 ? ' + ${n(s['children']).toInt()}' : ''} 👤 · ${ctx.t.or('gh.sources.${s['source']}', str(s['source']))}';

    Widget line(String a, String v, {Widget? end, TextStyle? style, String? sub}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: a),
                  if (sub != null && sub.isNotEmpty)
                    TextSpan(
                      text: '  $sub',
                      style: TextStyle(color: c.muted, fontSize: 11.5, fontWeight: FontWeight.w400),
                    ),
                ],
              ),
              style: style,
            ),
          ),
          Text(v, style: (style ?? const TextStyle()).copyWith(fontWeight: FontWeight.w800)),
          if (end != null) ...[const SizedBox(width: 4), end],
        ],
      ),
    );

    final children = <Widget>[
      // head: room · guest · dates · status
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(color: col.withValues(alpha: .14), borderRadius: BorderRadius.circular(14)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.bedDouble, size: 17, color: col),
                const SizedBox(width: 6),
                Text(
                  str(s['room_name']),
                  style: TextStyle(fontWeight: FontWeight.w800, color: c.ink, fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(str(guest['name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                if (info.isNotEmpty) Text(info, style: TextStyle(color: c.muted, fontSize: 12.5)),
                const SizedBox(height: 2),
                Text('$dates · $people', style: const TextStyle(fontSize: 12.5, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StayStatus(ctx, status),
        ],
      ),
      if (str(s['note']).isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: c.warnBg, borderRadius: BorderRadius.circular(12)),
          child: Text(str(s['note'])),
        ),
      // ID card / passport photos
      if (!(status == 'cancelled' && photos.isEmpty)) ...[
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(LucideIcons.idCard, size: 15, color: c.muted),
            const SizedBox(width: 6),
            Text(ctx.g('idPhotos'), style: const TextStyle(fontWeight: FontWeight.w700)),
            if (photos.isEmpty) ...[const SizedBox(width: 8), Expanded(child: Muted(ctx.g('idPhotosHint')))],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in photos)
              Stack(
                children: [
                  InkWell(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (d) => GestureDetector(
                        onTap: () => Navigator.pop(d),
                        child: InteractiveViewer(child: Image(image: netImage(str(p['url'])))),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image(image: netImage(
                        str(p['url'])),
                        width: 84,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(width: 84, height: 64, color: c.bg2),
                      ),
                    ),
                  ),
                  if (!ctx.readOnly)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: InkWell(
                        onTap: _busy ? null : () => _run(() => ctx.api.delete('$_sp/id-photos/${p['_id']}')),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(LucideIcons.x, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            if (!ctx.readOnly && photos.length < 4)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _busy ? null : _addIdPhoto,
                child: Container(
                  width: 84,
                  height: 64,
                  decoration: BoxDecoration(
                    color: c.bg2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.line),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.camera, size: 18, color: c.muted),
                      Text(ctx.g('idAdd'), style: TextStyle(fontSize: 11, color: c.muted)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
      if (live && !ctx.readOnly && !_edit && !lease) ...[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Btn(ctx.g('move'), icon: LucideIcons.pencil, kind: BtnKind.ghost, small: true, onTap: () => setState(() => _edit = true)),
        ),
      ],
      if (_edit)
        _EditStay(
          ctx: ctx,
          s: s,
          busy: _busy,
          onCancel: () => setState(() => _edit = false),
          onSave: (body) async {
            if (await _run(() => ctx.api.put(_sp, body), ctx.g('saved')) != null && mounted) setState(() => _edit = false);
          },
        ),
      if (_ask != null)
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.warnBg, borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    if (_ask!['nights'] != null && n(_ask!['nights']) != n(b['nights']))
                      TextSpan(
                        text: '${ctx.g('leavingEarly', {'n': n(_ask!['nights']), 'total': ctx.mo(_ask!['total'])})} ',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    TextSpan(text: ctx.g(_ask!['code'] == 'refund' ? 'refundAsk' : 'unpaidAsk', {'amt': ctx.mo(n(_ask!['balance']).abs())})),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Btn(
                    ctx.g('forceOut'),
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: _busy
                        ? null
                        : () {
                            setState(() => _ask = null);
                            _checkOut({'force': true});
                          },
                  ),
                  Btn(
                    _ask!['code'] == 'refund' ? ctx.g('refund') : ctx.g('takePayment'),
                    small: true,
                    onTap: () => setState(() {
                      final refund = _ask!['code'] == 'refund';
                      _pay = {'method': refund ? 'cash' : ctx.methods.first};
                      _pAmount.text = '${n(_ask!['balance'])}';
                      _pNote.text = refund ? ctx.g('refund') : '';
                      _ask = null;
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
      MemberBox(
        ctx: ctx,
        stay: s,
        busy: _busy,
        onStay: (d) {
          setState(() => _set(d));
          widget.onChanged?.call();
        },
      ),
      // the bill
      const SizedBox(height: 16),
      Text(ctx.g('bill'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 4),
      if (!lease) line(ctx.g('roomCharge', {'n': n(b['nights']), 'rate': ctx.mo(s['rate'])}), ctx.mo(b['room'])),
      for (final ch in objs(s['charges']))
        line(
          '${str(ch['label'])}${n(ch['qty']) > 1 ? ' × ${n(ch['qty']).toInt()}' : ''}',
          ctx.mo(n(ch['amount']) * (n(ch['qty']) == 0 ? 1 : n(ch['qty']))),
          sub: mTime(ch['at']),
          end: open
              ? InkWell(
                  onTap: _busy ? null : () => _run(() => ctx.api.delete('$_sp/charges/${ch['_id']}')),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(LucideIcons.x, size: 15, color: c.muted),
                  ),
                )
              : null,
        ),
      // extra services (gh_services): one tap adds a line
      if (open && ctx.services.isNotEmpty && _charge == null) ...[
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final x in ctx.services)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: c.bg2,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _busy ? null : () => _run(() => ctx.api.post('$_sp/charges', {'service_id': x['_id'], 'label': x['name'], 'amount': x['price'], 'qty': 1})),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Column(
                          children: [
                            Text(svcEmoji[str(x['icon'])] ?? svcEmoji['other']!, style: const TextStyle(fontSize: 18)),
                            Text(str(x['name']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                            Text(ctx.mo(x['price']), style: TextStyle(color: c.muted, fontSize: 11.5)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      if (open)
        _charge != null
            ? Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final p in ctx.t.list('gh.chargePresets')) ChoiceChip(label: Text(p), selected: _cLabel.text == p, onSelected: (_) => setState(() => _cLabel.text = p))],
                    ),
                    const SizedBox(height: 10),
                    Field(controller: _cLabel, hint: ctx.g('chargePh'), maxLength: 80, autofocus: true, onChanged: (_) => setState(() {})),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Field(controller: _cAmount, hint: ctx.g('amount'), keyboard: decimalKeys, onChanged: (_) => setState(() {})),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Field(
                            controller: _cQty,
                            hint: ctx.g('qty'),
                            keyboard: TextInputType.number,
                            prefix: const SizedBox(
                              width: 32,
                              child: Center(
                                child: Text('×', style: TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Btn(ctx.g('cancel'), kind: BtnKind.ghost, small: true, onTap: () => setState(() => _charge = null)),
                        const Spacer(),
                        Btn(
                          ctx.g('addCharge'),
                          icon: LucideIcons.plus,
                          small: true,
                          busy: _busy,
                          onTap: _busy || _cLabel.text.trim().isEmpty || numOf(_cAmount.text) == null
                              ? null
                              : () async {
                                  final r = await _run(
                                    () => ctx.api.post('$_sp/charges', {'label': _cLabel.text.trim(), 'amount': numOf(_cAmount.text), 'qty': (int.tryParse(_cQty.text) ?? 1).clamp(1, 1000)}),
                                  );
                                  if (r != null && mounted) setState(() => _charge = null);
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              )
            : Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _charge = {};
                    _cLabel.clear();
                    _cAmount.clear();
                    _cQty.text = '1';
                  }),
                  icon: const Icon(LucideIcons.plus, size: 15),
                  label: Text(ctx.g('addCharge')),
                ),
              ),
      Row(
        children: [
          Expanded(child: Text(ctx.g('discount'))),
          if (open)
            SizedBox(
              width: 120,
              child: Focus(
                onFocusChange: (on) {
                  if (on) return;
                  final v = numOf(_disc.text) ?? 0;
                  if (v != n(s['discount'])) _run(() => ctx.api.put('$_sp/discount', {'discount': v}));
                },
                child: Field(
                  controller: _disc,
                  hint: '0',
                  keyboard: decimalKeys,
                  align: TextAlign.right,
                  prefix: const SizedBox(
                    width: 32,
                    child: Center(
                      child: Text('−', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ),
            )
          else
            Text(n(b['discount']) > 0 ? '−${ctx.mo(b['discount'])}' : '—', style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
      Divider(height: 20, color: c.line),
      line(ctx.g('total'), ctx.mo(b['total']), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      Text(ctx.g('payments'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 4),
      for (final p in objs(s['payments']))
        line(
          '${ctx.method(str(p['method']))}${str(p['note']).isNotEmpty ? ' · ${p['note']}' : ''}',
          ctx.mo(p['amount']),
          sub: mDayTime(p['at'], ctx.lang),
          style: n(p['amount']) < 0 ? TextStyle(color: c.danger) : null,
          end: !ctx.readOnly
              ? InkWell(
                  onTap: _busy ? null : () => _run(() => ctx.api.delete('$_sp/payments/${p['_id']}')),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(LucideIcons.trash2, size: 15, color: c.muted),
                  ),
                )
              : null,
        ),
      if (!ctx.readOnly)
        _pay != null
            ? Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Chips<String>(options: [for (final k in ctx.methods) (k, ctx.method(k))], on: (k) => _pay!['method'] == k, onTap: (k) => setState(() => _pay!['method'] = k)),
                    const SizedBox(height: 10),
                    Field(
                      controller: _pAmount,
                      hint: ctx.g('amount'),
                      keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      autofocus: true,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.ink),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Field(controller: _pNote, hint: ctx.g('note'), maxLength: 120),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Btn(ctx.g('cancel'), kind: BtnKind.ghost, small: true, onTap: () => setState(() => _pay = null)),
                        const Spacer(),
                        Btn(
                          (numOf(_pAmount.text) ?? 0) < 0 ? ctx.g('refund') : ctx.g('takePayment'),
                          icon: (numOf(_pAmount.text) ?? 0) < 0 ? LucideIcons.minus : LucideIcons.plus,
                          small: true,
                          busy: _busy,
                          onTap: _busy || (numOf(_pAmount.text) ?? 0) == 0
                              ? null
                              : () async {
                                  final r = await _run(() => ctx.api.post('$_sp/payments', {'method': _pay!['method'], 'amount': numOf(_pAmount.text), 'note': _pNote.text.trim()}));
                                  if (r != null && mounted) setState(() => _pay = null);
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              )
            : Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _pay = {'method': ctx.methods.first};
                    _pAmount.text = balance > 0 ? '$balance' : '';
                    _pNote.clear();
                  }),
                  icon: const Icon(LucideIcons.plus, size: 15),
                  label: Text(ctx.g('takePayment')),
                ),
              ),
      Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: balance > 0
              ? c.dangerBg
              : balance < 0
              ? c.warnBg
              : c.goodBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                balance > 0
                    ? ctx.g('balance')
                    : balance < 0
                    ? ctx.g('change')
                    : ctx.g('settled'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              ctx.mo(balance.abs()),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: balance > 0
                    ? c.danger
                    : balance < 0
                    ? c.warn
                    : c.good,
              ),
            ),
          ],
        ),
      ),
      if (str(s['by']).isNotEmpty) ...[
        const SizedBox(height: 10),
        Muted('${ctx.g('by', {'name': s['by']})} · ${mDayTime(s['created_date'], ctx.lang)}'),
      ],
      if (_error.isNotEmpty) ...[const SizedBox(height: 10), Alert(_error)],
    ];

    // actions at the bottom
    final actions = <Widget>[
      if (open && status == 'booked') ...[
        SureDelete(remove: ctx.g('cancelBooking'), sure: ctx.g('sure'), onDelete: _busy ? null : () => _run(() => ctx.api.post('$_sp/cancel'))),
        if (str(s['from']).compareTo(today) <= 0) SureDelete(remove: ctx.g('noShow'), sure: ctx.g('sure'), onDelete: _busy ? null : () => _run(() => ctx.api.post('$_sp/no-show'))),
        Btn(
          ctx.g('checkIn'),
          icon: LucideIcons.logIn,
          small: true,
          busy: _busy,
          onTap: _busy || str(s['from']).compareTo(today) > 0 ? null : () => _run(() => ctx.api.post('$_sp/check-in'), ctx.g('checkedIn')),
        ),
      ],
      if (open && status == 'in' && !lease) Btn(ctx.g('checkOut'), icon: LucideIcons.logOut, small: true, busy: _busy, onTap: _busy ? null : () => _checkOut()),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(ctx.g('stayTitle', {'no': s['no']}), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                ),
                if ((ctx.addonOn('gh_reviews') || ctx.data['reviews'] == true) && ['in', 'out'].contains(s['status']))
                  IconButton(tooltip: ctx.t('gx.rvSend'), onPressed: () => openReviewShare(context, ctx, s), icon: const Icon(LucideIcons.star, size: 18)),
                TextButton.icon(onPressed: _printBill, icon: Icon(ctx.print['on'] == true ? LucideIcons.printer : LucideIcons.lock, size: 16), label: Text(ctx.g('printBill'))),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
          if (actions.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.line)),
              ),
              child: Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
            ),
        ],
      ),
    );
  }
}

// change dates / room / guest / rate of a live stay
class _EditStay extends StatefulWidget {
  final GhCtx ctx;
  final Json s;
  final bool busy;
  final VoidCallback onCancel;
  final Future<void> Function(Json body) onSave;
  const _EditStay({required this.ctx, required this.s, required this.busy, required this.onCancel, required this.onSave});
  @override
  State<_EditStay> createState() => _EditStayState();
}

class _EditStayState extends State<_EditStay> {
  late String _from = str(widget.s['from']), _to = str(widget.s['to']), _room = str(widget.s['room_id']);
  late final _rate = TextEditingController(text: '${n(widget.s['rate'])}'.replaceFirst(RegExp(r'\.0$'), ''));
  late final _note = TextEditingController(text: str(widget.s['note']));
  late final _guest = GuestForm(obj(widget.s['guest']), n(widget.s['adults']).toInt(), n(widget.s['children']).toInt());
  Set<String>? _busy;
  GhCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _loadBusy();
  }

  @override
  void dispose() {
    _rate.dispose();
    _note.dispose();
    _guest.dispose();
    super.dispose();
  }

  Future<void> _loadBusy() async {
    setState(() => _busy = null);
    final b = await busyRooms(ctx, _from, _to, str(widget.s['_id']));
    if (mounted) setState(() => _busy = b);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = widget.s;
    final nights = _to.compareTo(_from) > 0 ? nightsOf(_from, _to) : 0;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (s['status'] == 'booked') ...[
            DayField(
              label: ctx.g('arrive'),
              value: _from,
              onChanged: (v) {
                if (v.isEmpty) return;
                _from = v;
                if (_to.compareTo(v) <= 0) _to = addDaysKH(v, 1);
                _loadBusy();
              },
            ),
            const SizedBox(height: 12),
          ],
          DayField(
            label: '${ctx.g('leave')}${nights > 0 ? ' · ${ctx.g('nights', {'n': nights})}' : ''}',
            value: _to,
            first: DateTime.parse(addDaysKH(_from, 1)),
            onChanged: (v) {
              if (v.isEmpty) return;
              _to = v;
              _loadBusy();
            },
          ),
          const SizedBox(height: 12),
          Label(ctx.g('room')),
          RoomPicker(ctx: ctx, value: _room, busy: _busy, onPick: (r, _) => setState(() => _room = str(r['_id']))),
          const SizedBox(height: 14),
          GuestFields(ctx: ctx, f: _guest, lookup: false, onChanged: () => setState(() {})),
          const SizedBox(height: 12),
          Field(label: '${ctx.g('rate')} (${ctx.cur})', controller: _rate, keyboard: decimalKeys),
          const SizedBox(height: 12),
          Field(label: ctx.g('note'), controller: _note, maxLength: 500),
          const SizedBox(height: 12),
          Row(
            children: [
              Btn(ctx.g('cancel'), kind: BtnKind.ghost, small: true, onTap: widget.busy ? null : widget.onCancel),
              const Spacer(),
              Btn(
                widget.busy ? ctx.g('saving') : ctx.g('save'),
                small: true,
                busy: widget.busy,
                onTap: widget.busy || nights == 0 || _guest.name.text.trim().isEmpty
                    ? null
                    : () => widget.onSave({
                        if (s['status'] == 'booked') 'from': _from,
                        'to': _to,
                        if (_room != str(s['room_id'])) 'room_id': _room,
                        'rate': numOf(_rate.text) ?? 0,
                        'adults': _guest.adults,
                        'children': _guest.children,
                        'note': _note.text.trim(),
                        'guest': _guest.body,
                      }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
