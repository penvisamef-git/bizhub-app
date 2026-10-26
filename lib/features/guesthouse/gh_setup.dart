import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show MHead, GoldBtn, SureDelete, mGap, mDate;
import '../mart/mart_kit.dart' show MSheet, showSheet, decimalKeys, numOf;
import '../restaurant/rest_common.dart' show Segmented, SwitchRow;
import 'gh_common.dart';

// Rooms (types + rooms), Settings, Add-ons — the app version of GhSetup.jsx.

Widget _panel(List<Widget> children) => Panel(
  padding: const EdgeInsets.all(16),
  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
);

// add-ons paid every year (the others are bought once, forever)
const ghYearly = {'gh_staff', 'gh_website', 'gh_customers', 'gh_telegram', 'gh_ical', 'gh_longstay', 'gh_reviews', 'gh_loyalty'};

// busy + error + "saved" for an editor sheet; a 402 closes it and opens the shop
mixin GhSave<W extends StatefulWidget> on State<W> {
  bool busy = false;
  String error = '';
  GhCtx get gctx;
  Future<bool> save(Future<Json> Function() fn, {bool reload = true}) async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await fn();
      if (reload) await gctx.reload();
      gctx.notify(gctx.g('saved'));
      if (mounted) Navigator.pop(context, true);
      return true;
    } on ApiError catch (e) {
      if (e.status == 402 && e.body['product'] != null) {
        if (mounted) Navigator.pop(context);
        gctx.askBuy(str(e.body['product']));
      } else if (mounted) {
        setState(() {
          busy = false;
          error = e.network ? gctx.t('app.offline') : e.message;
        });
      }
      return false;
    }
  }

  List<Widget> footer({required bool canSave, required VoidCallback onSave, VoidCallback? onRemove}) => [
    if (onRemove != null) SureDelete(remove: gctx.g('remove'), sure: gctx.g('sure'), onDelete: busy ? null : onRemove),
    const Spacer(),
    Btn(gctx.g('cancel'), kind: BtnKind.ghost, small: true, onTap: busy ? null : () => Navigator.pop(context)),
    const SizedBox(width: 8),
    Btn(busy ? gctx.g('saving') : gctx.g('save'), small: true, busy: busy, onTap: busy || !canSave ? null : onSave),
  ];
}

// ------------------------------------------------------------------------------------------------ ROOMS
class RoomsTab extends StatelessWidget {
  final GhCtx ctx;
  const RoomsTab({super.key, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final full = n(ctx.counts['rooms']) >= n(ctx.limits['rooms']);
    final typesFull = ctx.types.length >= n(ctx.limits['types']);
    final roomsOn = ctx.addonOn('gh_rooms');
    final typesOn = ctx.addonOn('gh_types');
    void editType(Json row) => showSheet<bool>(context, (_) => _TypeEditor(ctx: ctx, row: row));
    void editRoom(Json row) => showSheet<bool>(context, (_) => _RoomEditor(ctx: ctx, row: row));
    final floors = ctx.rooms.map((r) => str(r['floor'])).toSet().toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _panel([
          MHead(ctx.g('typesTitle'), icon: LucideIcons.bedDouble, sub: '${ctx.g('typesSub')}${typesOn ? '' : ' ${ctx.g('typesFree', {'n': ctx.types.length, 'max': n(ctx.limits['types'])})}'}'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Btn(ctx.g('addType'), icon: typesFull ? LucideIcons.lock : LucideIcons.plus, small: true, onTap: ctx.readOnly ? null : () => typesFull ? ctx.askBuy('gh_types') : editType({})),
              if (!typesOn) GoldBtn('${ctx.g('unlockTypes')} · ${fmt(n(ctx.addon('gh_types')['price']))}', onTap: ctx.readOnly ? null : () => ctx.askBuy('gh_types')),
            ],
          ),
          if (ctx.types.isNotEmpty) ...[
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (_, box) {
                final cols = box.maxWidth > 560 ? 3 : 2;
                final w = (box.maxWidth - 10 * (cols - 1)) / cols;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final t in ctx.types)
                      SizedBox(
                        width: w,
                        child: () {
                          final col = hexColor(str(t['color']));
                          final count = ctx.rooms.where((r) => r['type_id'] == t['_id'] && r['active'] == true).length;
                          final amen = (t['amenities'] as List? ?? const []).map((k) => ctx.t.or('gh.amenities.$k', '$k')).join(' · ');
                          return Opacity(
                            opacity: t['active'] == false ? .5 : 1,
                            child: Material(
                              color: c.bg2,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: ctx.readOnly ? null : () => editType(t),
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border(top: BorderSide(color: col, width: 4)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(str(t['name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: ctx.mo(t['price']),
                                              style: TextStyle(fontWeight: FontWeight.w800, color: col, fontSize: 16),
                                            ),
                                            TextSpan(
                                              text: ' ${ctx.g('perNight')}',
                                              style: TextStyle(color: c.muted, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(LucideIcons.users, size: 12, color: c.muted),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              '${n(t['capacity'])}${str(t['beds']).isNotEmpty ? ' · ${t['beds']}' : ''}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(color: c.muted, fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (amen.isNotEmpty)
                                        Text(
                                          amen,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 11.5, color: c.ink.withValues(alpha: .75)),
                                        ),
                                      Text('$count × ${ctx.g('room').toLowerCase()}', style: TextStyle(color: c.muted, fontSize: 12)),
                                    ],
                                  ),
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
        ]),
        mGap,
        _panel([
          MHead(
            ctx.g('roomsTitle'),
            icon: LucideIcons.doorOpen,
            sub: roomsOn ? ctx.g('roomsUnlimited', {'n': n(ctx.counts['rooms'])}) : ctx.g('freeRooms5', {'n': n(ctx.counts['rooms']), 'max': n(ctx.limits['rooms'])}),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Btn(
                ctx.g('addRoom'),
                icon: full ? LucideIcons.lock : LucideIcons.plus,
                small: true,
                onTap: ctx.readOnly || ctx.types.isEmpty ? null : () => full ? ctx.askBuy('gh_rooms') : editRoom({}),
              ),
              if (!roomsOn) GoldBtn('${ctx.g('unlockRooms')} · ${fmt(n(ctx.addon('gh_rooms')['price']))}', onTap: ctx.readOnly ? null : () => ctx.askBuy('gh_rooms')),
            ],
          ),
          if (ctx.types.isEmpty) ...[const SizedBox(height: 10), Muted(ctx.g('noTypes'))],
          for (final f in floors) ...[
            if (floors.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 2),
                child: Text(
                  f.isEmpty ? '—' : '${ctx.g('floor')} $f',
                  style: TextStyle(color: c.muted, fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in ctx.rooms.where((r) => str(r['floor']) == f))
                  () {
                    final t = ctx.typeOf(r['type_id']);
                    final col = hexColor(str(t?['color']));
                    final off = r['active'] != true;
                    final over = r['usable'] == false;
                    return Opacity(
                      opacity: off || over ? .5 : 1,
                      child: Material(
                        color: col.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: ctx.readOnly ? null : () => editRoom(r),
                          child: Container(
                            width: 92,
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border(left: BorderSide(color: col, width: 3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(str(r['name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                Text(
                                  str(t?['name']).isEmpty ? '?' : str(t?['name']),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: c.muted, fontSize: 11.5),
                                ),
                                if (off || over)
                                  Text(
                                    over ? '🔒' : ctx.g('off'),
                                    style: TextStyle(color: c.danger, fontWeight: FontWeight.w800, fontSize: 11),
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
          ],
        ]),
      ],
    );
  }
}

class _TypeEditor extends StatefulWidget {
  final GhCtx ctx;
  final Json row;
  const _TypeEditor({required this.ctx, required this.row});
  @override
  State<_TypeEditor> createState() => _TypeEditorState();
}

class _TypeEditorState extends State<_TypeEditor> with GhSave {
  late final isNew = widget.row['_id'] == null;
  late final _name = TextEditingController(text: str(widget.row['name']));
  late final _price = TextEditingController(text: widget.row['price'] == null ? '' : '${n(widget.row['price'])}'.replaceFirst(RegExp(r'\.0$'), ''));
  late final _beds = TextEditingController(text: str(widget.row['beds']));
  late int _cap = widget.row['capacity'] == null ? 2 : n(widget.row['capacity']).toInt();
  late final Set<String> _amen = {...(widget.row['amenities'] as List? ?? const []).map((e) => '$e')};
  late String _color = str(widget.row['color']).isEmpty ? ghColors[ctx.types.length % ghColors.length] : str(widget.row['color']);
  late bool _active = widget.row['active'] != false;
  GhCtx get ctx => widget.ctx;
  @override
  GhCtx get gctx => ctx;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _beds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = {'name': _name.text.trim(), 'price': numOf(_price.text) ?? 0, 'capacity': _cap, 'beds': _beds.text.trim(), 'amenities': _amen.toList(), 'color': _color, 'active': _active};
    final path = '${ctx.base}/room-types';
    return MSheet(
      title: isNew ? ctx.g('addType') : ctx.g('editType'),
      footer: footer(
        canSave: _name.text.trim().isNotEmpty && _price.text.trim().isNotEmpty,
        onSave: () => save(() => isNew ? ctx.api.post(path, body) : ctx.api.put('$path/${widget.row['_id']}', body)),
        onRemove: isNew ? null : () => save(() => ctx.api.delete('$path/${widget.row['_id']}')),
      ),
      children: [
        Field(label: ctx.g('typeName'), hint: ctx.g('typeNamePh'), controller: _name, maxLength: 60, autofocus: isNew, onChanged: (_) => setState(() {})),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Field(label: '${ctx.g('price')} (${ctx.cur})', controller: _price, keyboard: decimalKeys, onChanged: (_) => setState(() {})),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Label(ctx.g('capacity')),
                Stepper2(value: _cap, min: 1, max: 20, onChanged: (v) => setState(() => _cap = v)),
                const SizedBox(height: 6),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Field(label: ctx.g('beds'), hint: ctx.g('bedsPh'), controller: _beds, maxLength: 60),
        const SizedBox(height: 14),
        Label(ctx.g('facilities')),
        Chips<String>(
          options: [for (final k in ctx.list('amenities')) (k, ctx.t.or('gh.amenities.$k', k))],
          on: _amen.contains,
          onTap: (k) => setState(() => _amen.contains(k) ? _amen.remove(k) : _amen.add(k)),
        ),
        const SizedBox(height: 14),
        Label(ctx.g('color')),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final h in ghColors)
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _color = h),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: hexColor(h),
                    shape: BoxShape.circle,
                    border: Border.all(color: _color == h ? context.c.ink : Colors.transparent, width: 3),
                  ),
                  child: _color == h ? const Icon(LucideIcons.check, size: 16, color: Colors.white) : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchRow(title: ctx.g('active'), value: _active, onChanged: (v) => setState(() => _active = v)),
        if (error.isNotEmpty) ...[const SizedBox(height: 10), Alert(error)],
      ],
    );
  }
}

class _RoomEditor extends StatefulWidget {
  final GhCtx ctx;
  final Json row;
  const _RoomEditor({required this.ctx, required this.row});
  @override
  State<_RoomEditor> createState() => _RoomEditorState();
}

class _RoomEditorState extends State<_RoomEditor> with GhSave {
  late final isNew = widget.row['_id'] == null;
  late final Json? _last = ctx.rooms.lastOrNull;
  late final _name = TextEditingController(text: isNew ? (_last != null && RegExp(r'^\d+$').hasMatch(str(_last['name'])) ? '${int.parse(str(_last['name'])) + 1}' : '') : str(widget.row['name']));
  late final _floor = TextEditingController(text: isNew ? str(_last?['floor']) : str(widget.row['floor']));
  late final _note = TextEditingController(text: str(widget.row['note']));
  late String _type = str(widget.row['type_id']).isNotEmpty ? str(widget.row['type_id']) : (str(_last?['type_id']).isNotEmpty ? str(_last?['type_id']) : str(ctx.types.firstOrNull?['_id']));
  late bool _active = widget.row['active'] != false;
  late final List<(TextEditingController, TextEditingController)> _details = [
    for (final d in objs(widget.row['details'])) (TextEditingController(text: str(d['label'])), TextEditingController(text: str(d['value']))),
    if (objs(widget.row['details']).isEmpty) (TextEditingController(), TextEditingController()),
  ];
  GhCtx get ctx => widget.ctx;
  @override
  GhCtx get gctx => ctx;

  @override
  void dispose() {
    _name.dispose();
    _floor.dispose();
    _note.dispose();
    for (final (a, b) in _details) {
      a.dispose();
      b.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final body = {
      'name': _name.text.trim(),
      'floor': _floor.text.trim(),
      'type_id': _type,
      'note': _note.text.trim(),
      'details': [
        for (final (a, b) in _details)
          if (a.text.trim().isNotEmpty || b.text.trim().isNotEmpty) {'label': a.text.trim(), 'value': b.text.trim()},
      ],
      'active': _active,
    };
    final path = '${ctx.base}/rooms';
    return MSheet(
      title: isNew ? ctx.g('addRoom') : ctx.g('editRoom'),
      footer: footer(
        canSave: _name.text.trim().isNotEmpty && _type.isNotEmpty,
        onSave: () => save(() => isNew ? ctx.api.post(path, body) : ctx.api.put('$path/${widget.row['_id']}', body)),
        onRemove: isNew ? null : () => save(() => ctx.api.delete('$path/${widget.row['_id']}')),
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Field(label: ctx.g('roomName'), hint: '101', controller: _name, maxLength: 20, autofocus: isNew, onChanged: (_) => setState(() {})),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Field(label: ctx.g('floor'), hint: '1', controller: _floor, maxLength: 20),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Label(ctx.g('roomType')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in ctx.types)
              () {
                final on = _type == t['_id'];
                final col = hexColor(str(t['color']));
                return Material(
                  color: on ? col.withValues(alpha: .14) : c.bg2,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _type = str(t['_id'])),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: on ? col : c.line, width: on ? 2 : 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.bedDouble, size: 15, color: col),
                          const SizedBox(width: 6),
                          Text('${str(t['name'])} · ${ctx.mo(t['price'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                );
              }(),
          ],
        ),
        const SizedBox(height: 14),
        Field(label: ctx.g('description'), hint: ctx.g('descriptionPh'), controller: _note, maxLength: 500, maxLines: 2),
        const SizedBox(height: 14),
        Label(ctx.g('details'), hint: ctx.g('detailsHint')),
        for (final (i, (a, b)) in _details.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Field(controller: a, hint: ctx.g('detailLabel'), maxLength: 40),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: Field(controller: b, hint: ctx.g('detailValue'), maxLength: 120),
                ),
                IconButton(
                  onPressed: () => setState(() {
                    if (_details.length > 1) {
                      final x = _details.removeAt(i);
                      x.$1.dispose();
                      x.$2.dispose();
                    } else {
                      a.clear();
                      b.clear();
                    }
                  }),
                  icon: Icon(LucideIcons.x, size: 16, color: c.muted),
                ),
              ],
            ),
          ),
        if (_details.length < 12)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _details.add((TextEditingController(), TextEditingController()))),
              icon: const Icon(LucideIcons.plus, size: 15),
              label: Text(ctx.g('addDetail')),
            ),
          ),
        SwitchRow(title: ctx.g('active'), value: _active, onChanged: (v) => setState(() => _active = v)),
        if (error.isNotEmpty) ...[const SizedBox(height: 10), Alert(error)],
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ SETTINGS
class SettingsTab extends StatefulWidget {
  final GhCtx ctx;
  const SettingsTab({super.key, required this.ctx});
  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  GhCtx get ctx => widget.ctx;
  late Json s = ctx.settings;
  late String _cur = ctx.cur, _in = str(s['check_in']).isEmpty ? '14:00' : str(s['check_in']), _out = str(s['check_out']).isEmpty ? '12:00' : str(s['check_out']);
  late final List<String> _methods = [...ctx.methods];
  late final _rate = TextEditingController(text: '${n(s['khr_rate']) == 0 ? 4100 : n(s['khr_rate']).toInt()}');
  late final _note = TextEditingController(text: str(s['receipt_note']));
  bool _busy = false;

  @override
  void dispose() {
    _rate.dispose();
    _note.dispose();
    super.dispose();
  }

  void _toggle(String k) {
    final on = ctx.addonOn('gh_payments');
    if (!_methods.contains(k) && !on && _methods.length >= n(ctx.limits['methods'])) return ctx.askBuy('gh_payments');
    setState(() => _methods.contains(k) ? _methods.remove(k) : _methods.add(k));
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    await ctx.run(
      () => ctx.api.put('${ctx.base}/settings', {'currency': _cur, 'check_in': _in, 'check_out': _out, 'methods': _methods, 'khr_rate': numOf(_rate.text) ?? 4100, 'receipt_note': _note.text.trim()}),
      ctx.g('saved'),
    );
    await ctx.reload();
    if (mounted) setState(() => _busy = false);
  }

  Widget _time(String label, String v, ValueChanged<String> on) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Label(label),
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            final p = v.split(':');
            final t = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: int.tryParse(p.first) ?? 12, minute: int.tryParse(p.last) ?? 0),
              builder: (ctx2, child) => MediaQuery(data: MediaQuery.of(ctx2).copyWith(alwaysUse24HourFormat: true), child: child!),
            );
            if (t != null) on('${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: BoxDecoration(
              color: c.bg2,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.line),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.clock, size: 17, color: c.muted),
                const SizedBox(width: 8),
                Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final methodsOn = ctx.addonOn('gh_payments');
    final max = n(ctx.limits['methods']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _panel([
          MHead(ctx.g('setTitle'), icon: LucideIcons.settings2),
          Row(
            children: [
              Expanded(child: _time(ctx.g('checkInTime'), _in, (v) => setState(() => _in = v))),
              const SizedBox(width: 12),
              Expanded(child: _time(ctx.g('checkOutTime'), _out, (v) => setState(() => _out = v))),
            ],
          ),
          const SizedBox(height: 14),
          Label(ctx.g('currency')),
          Segmented<String>(value: _cur, options: const [('USD', '\$ USD'), ('KHR', '៛ KHR')], onChanged: (v) => setState(() => _cur = v)),
          const SizedBox(height: 14),
          Field(label: ctx.g('khrRate'), controller: _rate, keyboard: TextInputType.number, maxLength: 5),
          const SizedBox(height: 14),
          Label(ctx.g('methodsLabel'), hint: methodsOn ? null : ctx.g('methodsFree', {'max': max})),
          Chips<String>(
            options: [for (final k in ctx.list('methods')) (k, ctx.method(k))],
            on: _methods.contains,
            onTap: ctx.readOnly ? null : _toggle,
            trail: (k) => !methodsOn && !_methods.contains(k) && _methods.length >= max
                ? Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(LucideIcons.lock, size: 12, color: context.c.muted),
                  )
                : const SizedBox.shrink(),
          ),
          if (!methodsOn) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: GoldBtn(ctx.g('unlock', {'coins': fmt(n(ctx.addon('gh_payments')['price']))}), onTap: ctx.readOnly ? null : () => ctx.askBuy('gh_payments')),
            ),
          ],
          const SizedBox(height: 14),
          Field(label: ctx.g('receiptNote'), hint: ctx.g('receiptNotePh'), controller: _note, maxLength: 300),
          const SizedBox(height: 16),
          Btn(_busy ? ctx.g('saving') : ctx.g('save'), icon: LucideIcons.save, busy: _busy, expand: true, onTap: _busy || ctx.readOnly || _methods.isEmpty ? null : _save),
        ]),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ ADD-ONS
const ghAddonIcons = <String, IconData>{
  'gh_rooms': LucideIcons.bedDouble,
  'gh_types': LucideIcons.users,
  'gh_payments': LucideIcons.wallet,
  'gh_staff': LucideIcons.userRound,
  'gh_display': LucideIcons.monitorUp,
  'gh_printer': LucideIcons.printer,
  'gh_website': LucideIcons.globe,
  'gh_promos': LucideIcons.badgePercent,
  'gh_customers': LucideIcons.userRoundCheck,
  'gh_telegram': LucideIcons.send,
  'gh_police': LucideIcons.shieldCheck,
  'gh_services': LucideIcons.conciergeBell,
  'gh_housekeeping': LucideIcons.sparkles,
  'gh_expenses': LucideIcons.receipt,
  'gh_ical': LucideIcons.calendarSync,
  'gh_longstay': LucideIcons.keyRound,
  'gh_reviews': LucideIcons.star,
  'gh_loyalty': LucideIcons.gift,
  'gh_branches': LucideIcons.network,
};

class AddonsTab extends StatelessWidget {
  final GhCtx ctx;
  const AddonsTab({super.key, required this.ctx});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _panel([MHead(ctx.g('addonsTitle'), sub: ctx.g('addonsSub'), icon: LucideIcons.puzzle)]),
        for (final k in ghAddonIcons.keys) ...[
          mGap,
          () {
            final a = ctx.addon(k);
            final on = a['active'] == true;
            final yearly = ghYearly.contains(k);
            return Panel(
              padding: const EdgeInsets.all(16),
              color: on ? c.goodBg.withValues(alpha: .5) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MHead(ctx.g('addonInfo.$k.name'), icon: ghAddonIcons[k], sub: ctx.g('addonInfo.$k.what')),
                  for (final p in ctx.t.list('gh.addonInfo.$k.perks'))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(LucideIcons.check, size: 15, color: c.good),
                          const SizedBox(width: 8),
                          Expanded(child: Text(p)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (on) Chip2(ctx.g('owned'), icon: LucideIcons.badgeCheck, tone: Tone.good),
                      if (on && a['expires_at'] != null) Muted(ctx.g('endsOn', {'date': mDate(a['expires_at'], ctx.lang)})),
                      if (!on || a['status'] == 'expiring')
                        GoldBtn(
                          on ? '${ctx.g('renew')} · ${fmt(n(a['price']))}' : '${ctx.g('unlock', {'coins': fmt(n(a['price']))})} · ${yearly ? ctx.g('perYear') : ctx.g('forever')}',
                          onTap: ctx.readOnly ? null : () => ctx.askBuy(k),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }(),
        ],
      ],
    );
  }
}
