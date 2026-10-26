import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show MHead;
import '../restaurant/rest_common.dart' show SelectField, SwitchRow;
import 'ev_common.dart';

// The extra parts of an event in the editor (the web's EvMore.jsx ShowsBox / SeatsBox / QuestionsBox and EvGrow.jsx SponsorsEditor):
// showtimes (ev_shows), a seat map (ev_seats), questions for buyers (ev_questions), sponsors (ev_sponsors).
String _rid(String p) => '$p${math.Random().nextInt(1 << 30).toRadixString(36)}';
String seatRowName(int i) {
  var s = '';
  var n0 = i + 1;
  while (n0 > 0) {
    final m = (n0 - 1) % 26;
    s = String.fromCharCode(65 + m) + s;
    n0 = (n0 - 1) ~/ 26;
  }
  return s;
}

class EvExtras {
  final List<Json> shows; // { key, starts_at: DateTime?, label, active }
  bool seatsOn;
  final List<Json> sections; // { key, name, type_key, rows, cols, blocked: [..] }
  bool askNames;
  final List<Json> questions; // { key, label, kind, options: String, required }
  EvExtras._(this.shows, this.seatsOn, this.sections, this.askNames, this.questions);
  factory EvExtras.of(Json? ev) => EvExtras._(
    [
      for (final s in objs(ev?['shows'])) {'key': str(s['key']), 'starts_at': evDate(s['starts_at']), 'label': str(s['label']), 'active': s['active'] != false},
    ],
    obj(ev?['seating'])['on'] == true,
    [
      for (final s in objs(obj(ev?['seating'])['sections']))
        {
          ...s,
          'blocked': [for (final b in (s['blocked'] as List? ?? const [])) '$b'],
        },
    ],
    ev?['ask_names'] == true,
    [
      for (final q in objs(ev?['questions']))
        {
          ...q,
          'options': [for (final o in (q['options'] as List? ?? const [])) '$o'].join('\n'),
        },
    ],
  );
  // what to send (only the add-ons that are on)
  Json body(EvCtx ctx) => {
    if (ctx.on('ev_shows'))
      'shows': [
        for (final s in shows)
          if (s['starts_at'] != null) {'key': s['key'], 'starts_at': (s['starts_at'] as DateTime).toUtc().toIso8601String(), 'label': s['label'], 'active': s['active']},
      ],
    if (ctx.on('ev_seats')) 'seating': {'on': seatsOn, 'sections': sections},
    if (ctx.on('ev_questions')) ...{
      'questions': [
        for (final q in questions) {...q, 'options': str(q['options']).split('\n')},
      ],
      'ask_names': askNames,
    },
  };
}

class _Box extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final Widget child;
  const _Box({required this.icon, required this.title, required this.sub, required this.child});
  @override
  Widget build(BuildContext context) => Panel(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MHead(title, sub: sub, icon: icon),
        child,
      ],
    ),
  );
}

Future<DateTime?> _pickWhen(BuildContext context, DateTime? cur) async {
  final now = DateTime.now();
  final d = await showDatePicker(context: context, initialDate: cur ?? now, firstDate: DateTime(now.year - 2), lastDate: DateTime(now.year + 5));
  if (d == null || !context.mounted) return null;
  final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(cur ?? DateTime(now.year, now.month, now.day, 18)));
  if (t == null) return null;
  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}

// ---------------------------------------------------------------- showtimes (ev_shows)
class EvShowsBox extends StatefulWidget {
  final EvCtx ctx;
  final EvExtras x;
  final DateTime? starts;
  const EvShowsBox({super.key, required this.ctx, required this.x, this.starts});
  @override
  State<EvShowsBox> createState() => _EvShowsBoxState();
}

class _EvShowsBoxState extends State<EvShowsBox> {
  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final c = context.c;
    final shows = widget.x.shows;
    return _Box(
      icon: LucideIcons.calendarClock,
      title: ctx.m('more.shows'),
      sub: ctx.m('more.showsSub'),
      child: EvLocked(
        ctx: ctx,
        addon: 'ev_shows',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < shows.length; i++)
              Container(
                key: ObjectKey(shows[i]),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () async {
                              final d = await _pickWhen(context, shows[i]['starts_at'] as DateTime? ?? widget.starts);
                              if (d != null) setState(() => shows[i]['starts_at'] = d);
                            },
                            icon: const Icon(LucideIcons.calendarDays, size: 16),
                            label: Text(shows[i]['starts_at'] == null ? ctx.m('more.showStart') : evWhen(shows[i]['starts_at'], ctx.lang)),
                          ),
                        ),
                        Switch(value: shows[i]['active'] == true, onChanged: (v) => setState(() => shows[i]['active'] = v)),
                        IconButton(
                          tooltip: ctx.m('remove'),
                          onPressed: () => setState(() => shows.removeAt(i)),
                          icon: Icon(LucideIcons.trash2, size: 16, color: c.danger),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _Text(hint: ctx.m('more.showLabelPh'), value: str(shows[i]['label']), max: 60, onChanged: (v) => shows[i]['label'] = v),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: Btn(
                ctx.m('more.addShow'),
                icon: LucideIcons.plus,
                kind: BtnKind.ghost,
                small: true,
                onTap: shows.length >= 60 ? null : () => setState(() => shows.add({'key': '', 'starts_at': shows.isNotEmpty ? shows.last['starts_at'] : widget.starts, 'label': '', 'active': true})),
              ),
            ),
            if (shows.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Muted(ctx.m('more.showsHint'))),
          ],
        ),
      ),
    );
  }
}

// a text box that keeps its own controller (rows that come and go)
class _Text extends StatefulWidget {
  final String value, hint;
  final int max, lines;
  final ValueChanged<String> onChanged;
  const _Text({required this.value, required this.hint, required this.onChanged, this.max = 120, this.lines = 1});
  @override
  State<_Text> createState() => _TextState();
}

class _TextState extends State<_Text> {
  late final _c = TextEditingController(text: widget.value);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Field(controller: _c, hint: widget.hint, maxLength: widget.max, maxLines: widget.lines, onChanged: widget.onChanged);
}

// ---------------------------------------------------------------- seat map (ev_seats)
class EvSeatsBox extends StatefulWidget {
  final EvCtx ctx;
  final EvExtras x;
  final Json? ev;
  final List<(String, String)> types; // saved ticket types: key, name
  const EvSeatsBox({super.key, required this.ctx, required this.x, required this.types, this.ev});
  @override
  State<EvSeatsBox> createState() => _EvSeatsBoxState();
}

class _EvSeatsBoxState extends State<EvSeatsBox> {
  List<String> _sold = [];
  EvCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    final ev = widget.ev;
    if (ev?['_id'] != null && ctx.on('ev_seats')) {
      final show = str(objs(ev!['shows']).firstOrNull?['key']);
      ctx.api.get('${ctx.base}/events/${ev['_id']}/seats', {if (show.isNotEmpty) 'show': show}).then((r) {
        if (mounted) setState(() => _sold = [for (final x in (obj(r['data'])['taken'] as List? ?? const [])) '$x']);
      }, onError: (_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final x = widget.x;
    final types = widget.types;
    return _Box(
      icon: LucideIcons.armchair,
      title: ctx.m('more.seats'),
      sub: ctx.m('more.seatsSub'),
      child: EvLocked(
        ctx: ctx,
        addon: 'ev_seats',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchRow(
              title: ctx.m('more.seatsOn'),
              value: x.seatsOn,
              onChanged: (v) => setState(() {
                x.seatsOn = v;
                if (v && x.sections.isEmpty) {
                  x.sections.add({'key': _rid('z'), 'name': ctx.m('more.secDefault'), 'type_key': types.isEmpty ? '' : types.first.$1, 'rows': 5, 'cols': 10, 'blocked': <String>[]});
                }
              }),
            ),
            if (x.seatsOn) ...[
              for (var i = 0; i < x.sections.length; i++) _section(i, c),
              Align(
                alignment: Alignment.centerLeft,
                child: Btn(
                  ctx.m('more.addSec'),
                  icon: LucideIcons.plus,
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: x.sections.length >= 20
                      ? null
                      : () => setState(
                          () => x.sections.add({
                            'key': _rid('z'),
                            'name': '',
                            'type_key': types.length > 1 ? types[1].$1 : (types.isEmpty ? '' : types.first.$1),
                            'rows': 4,
                            'cols': 8,
                            'blocked': <String>[],
                          }),
                        ),
                ),
              ),
              if (types.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Muted(ctx.m('more.saveTypesFirst'))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(int i, C c) {
    final s = widget.x.sections[i];
    final rows = n(s['rows']).toInt().clamp(1, 40), cols = n(s['cols']).toInt().clamp(1, 60);
    final blocked = (s['blocked'] as List).cast<String>();
    Widget stepper(String label, String k, int max) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.5, color: c.muted, fontWeight: FontWeight.w700),
        ),
        IconButton(visualDensity: VisualDensity.compact, onPressed: n(s[k]) <= 1 ? null : () => setState(() => s[k] = n(s[k]).toInt() - 1), icon: const Icon(LucideIcons.minus, size: 15)),
        Text('${n(s[k]).toInt()}', style: const TextStyle(fontWeight: FontWeight.w800)),
        IconButton(visualDensity: VisualDensity.compact, onPressed: n(s[k]) >= max ? null : () => setState(() => s[k] = n(s[k]).toInt() + 1), icon: const Icon(LucideIcons.plus, size: 15)),
      ],
    );
    return Container(
      key: ValueKey(s['key']),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _Text(hint: ctx.m('more.secName'), value: str(s['name']), max: 40, onChanged: (v) => s['name'] = v),
              ),
              IconButton(
                tooltip: ctx.m('remove'),
                onPressed: () => setState(() => widget.x.sections.removeAt(i)),
                icon: Icon(LucideIcons.trash2, size: 16, color: c.danger),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectField<String>(value: str(s['type_key']), options: [('', ctx.m('more.secTypePick')), for (final t in widget.types) t], onChanged: (v) => setState(() => s['type_key'] = v)),
          const SizedBox(height: 4),
          Wrap(spacing: 8, children: [stepper(ctx.m('more.rows'), 'rows', 40), stepper(ctx.m('more.cols'), 'cols', 60)]),
          Muted('${ctx.m('more.seatsCount', {'n': fmt(rows * cols - blocked.length)})} · ${ctx.m('more.seatsClick')}'),
          const SizedBox(height: 8),
          // the map: tap a seat to take it off (aisle, pillar…); sold seats can't change
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: cols * 24.0 + 26,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.solid, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    'STAGE',
                    style: TextStyle(color: c.onSolid, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 2),
                  ),
                ),
                for (var r = 0; r < rows; r++)
                  Row(
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text(
                          seatRowName(r),
                          style: TextStyle(fontSize: 11, color: c.muted, fontWeight: FontWeight.w700),
                        ),
                      ),
                      for (var col = 0; col < cols; col++)
                        Builder(
                          builder: (_) {
                            final seat = '${seatRowName(r)}${col + 1}';
                            final off = blocked.contains(seat);
                            final sold = _sold.contains('${s['key']}:$seat');
                            return GestureDetector(
                              onTap: sold ? null : () => setState(() => off ? blocked.remove(seat) : blocked.add(seat)),
                              child: Container(
                                width: 20,
                                height: 20,
                                margin: const EdgeInsets.all(2),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: sold ? c.muted : (off ? Colors.transparent : c.active),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: off ? c.line : (sold ? c.muted : c.brand), width: 1),
                                ),
                                child: Text(
                                  off ? '' : '${col + 1}',
                                  style: TextStyle(fontSize: 8.5, color: sold ? Colors.white : c.brandInk, fontWeight: FontWeight.w700),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- questions for buyers (ev_questions)
const _qKinds = ['text', 'long', 'choice', 'yesno', 'email', 'number'];

class EvQuestionsBox extends StatefulWidget {
  final EvCtx ctx;
  final EvExtras x;
  const EvQuestionsBox({super.key, required this.ctx, required this.x});
  @override
  State<EvQuestionsBox> createState() => _EvQuestionsBoxState();
}

class _EvQuestionsBoxState extends State<EvQuestionsBox> {
  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final c = context.c;
    final x = widget.x;
    final qs = x.questions;
    return _Box(
      icon: LucideIcons.messageSquareText,
      title: ctx.m('more.questions'),
      sub: ctx.m('more.questionsSub'),
      child: EvLocked(
        ctx: ctx,
        addon: 'ev_questions',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchRow(title: ctx.m('more.askNames'), value: x.askNames, onChanged: (v) => setState(() => x.askNames = v)),
            for (var i = 0; i < qs.length; i++)
              Container(
                key: ObjectKey(qs[i]),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _Text(hint: ctx.m('more.qLabel'), value: str(qs[i]['label']), max: 120, onChanged: (v) => qs[i]['label'] = v),
                        ),
                        IconButton(
                          tooltip: ctx.m('remove'),
                          onPressed: () => setState(() => qs.removeAt(i)),
                          icon: Icon(LucideIcons.trash2, size: 16, color: c.danger),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectField<String>(
                      value: _qKinds.contains(qs[i]['kind']) ? str(qs[i]['kind']) : 'text',
                      options: [for (final k in _qKinds) (k, ctx.m('more.qKinds.$k'))],
                      onChanged: (v) => setState(() => qs[i]['kind'] = v),
                    ),
                    if (qs[i]['kind'] == 'choice') ...[
                      const SizedBox(height: 8),
                      _Text(hint: ctx.m('more.qOptionsPh'), value: str(qs[i]['options']), max: 1000, lines: 3, onChanged: (v) => qs[i]['options'] = v),
                    ],
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => qs[i]['required'] = qs[i]['required'] != true),
                      child: Row(
                        children: [
                          Checkbox(value: qs[i]['required'] == true, onChanged: (v) => setState(() => qs[i]['required'] = v == true)),
                          Text(ctx.m('more.qRequired')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: Btn(
                ctx.m('more.addQ'),
                icon: LucideIcons.plus,
                kind: BtnKind.ghost,
                small: true,
                onTap: qs.length >= 15 ? null : () => setState(() => qs.add({'key': '', 'label': '', 'kind': 'text', 'options': '', 'required': false})),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- sponsors (ev_sponsors): saved straight away
class EvSponsorsBox extends StatefulWidget {
  final EvCtx ctx;
  final Json? ev;
  const EvSponsorsBox({super.key, required this.ctx, this.ev});
  @override
  State<EvSponsorsBox> createState() => _EvSponsorsBoxState();
}

class _EvSponsorsBoxState extends State<EvSponsorsBox> {
  EvCtx get ctx => widget.ctx;
  late List<Json> _list = objs(widget.ev?['sponsors']);
  final _name = TextEditingController(), _link = TextEditingController();
  String _tier = 'partner', _busy = '';
  Uint8List? _file;

  @override
  void dispose() {
    _name.dispose();
    _link.dispose();
    super.dispose();
  }

  String get _base => '${ctx.base}/events/${widget.ev!['_id']}/sponsors';
  List<(String, String)> get _tiers => [
    for (final t in ['main', 'gold', 'partner']) (t, ctx.m('grow.tiers_.$t')),
  ];

  Future<bool> _run(String k, Future<Json> Function() fn) async {
    setState(() => _busy = k);
    final r = await ctx.run(fn);
    if (!mounted) return false;
    setState(() {
      _busy = '';
      if (r != null && obj(r['data'])['sponsors'] != null) _list = objs(obj(r['data'])['sponsors']);
    });
    return r != null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _Box(
      icon: LucideIcons.handshake,
      title: ctx.m('grow.spTitle'),
      sub: ctx.m('grow.spSub'),
      child: EvLocked(
        ctx: ctx,
        addon: 'ev_sponsors',
        child: widget.ev?['_id'] == null
            ? Muted(ctx.m('grow.spSaveFirst'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final s in _list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: c.line),
                            ),
                            child: str(s['logo']).isEmpty ? null : Image(image: netImage(str(s['logo'])), fit: BoxFit.contain),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(str(s['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text(
                                  str(s['link']).isEmpty ? '—' : str(s['link']),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: c.muted),
                                ),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: ctx.readOnly
                                      ? null
                                      : () async {
                                          final v = await evPickFrom(context, ctx.m('grow.spTitle'), _tiers, value: str(s['tier']));
                                          if (v != null) _run('t${s['key']}', () => ctx.api.put('$_base/${s['key']}', {'tier': v}));
                                        },
                                  child: Chip2(ctx.m('grow.tiers_.${str(s['tier']).isEmpty ? 'partner' : s['tier']}'), icon: LucideIcons.chevronDown, tone: Tone.brand),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: ctx.m('remove'),
                            onPressed: ctx.readOnly || _busy.isNotEmpty ? null : () => _run('d${s['key']}', () => ctx.api.delete('$_base/${s['key']}')),
                            icon: Icon(LucideIcons.trash2, size: 16, color: c.danger),
                          ),
                        ],
                      ),
                    ),
                  if (_list.length < 12)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 90);
                                  if (f == null) return;
                                  final b = await f.readAsBytes();
                                  setState(() => _file = b);
                                },
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: c.card,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: c.line),
                                  ),
                                  child: _file != null
                                      ? Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Image.memory(_file!, fit: BoxFit.contain),
                                        )
                                      : Icon(LucideIcons.imagePlus, color: c.muted),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Field(controller: _name, hint: ctx.m('grow.spName'), maxLength: 60, onChanged: (_) => setState(() {})),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Field(controller: _link, hint: ctx.m('grow.spLink'), keyboard: TextInputType.url, maxLength: 300),
                          const SizedBox(height: 8),
                          SelectField<String>(value: _tier, options: _tiers, onChanged: (v) => setState(() => _tier = v)),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Btn(
                              ctx.m('grow.spAdd'),
                              icon: LucideIcons.plus,
                              small: true,
                              busy: _busy == 'add',
                              onTap: _file == null || _name.text.trim().isEmpty || _busy.isNotEmpty || ctx.readOnly
                                  ? null
                                  : () async {
                                      final ok = await _run(
                                        'add',
                                        () => ctx.api.post(
                                          _base,
                                          FormData.fromMap({
                                            'file': MultipartFile.fromBytes(_file!, filename: 'logo.jpg', contentType: DioMediaType.parse('image/jpeg')),
                                            'name': _name.text.trim(),
                                            'link': _link.text.trim(),
                                            'tier': _tier,
                                          }),
                                        ),
                                      );
                                      if (ok && mounted) {
                                        setState(() {
                                          _file = null;
                                          _name.clear();
                                          _link.clear();
                                          _tier = 'partner';
                                        });
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
