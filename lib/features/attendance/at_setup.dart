import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../guesthouse/gh_common.dart' show ghDay;
import '../mart/mart_common.dart' show MHead, GoldBtn, SureDelete, mGap, mDate, fileForm, todayKH, addDaysKH;
import '../mart/mart_kit.dart' show MSheet, showSheet, DayField, decimalKeys, numOf;
import '../restaurant/rest_common.dart' show Segmented, SwitchRow, gap14;
import '../restaurant/rest_online.dart' show shareWidgets;
import 'at_common.dart';

// Staff · Branches · Shifts · Rules & link — SetupTabs.jsx + StaffExtras.jsx (profile, documents, manager note).

String _short(Object? label) {
  final s = '${label ?? ''}';
  final m = RegExp(r'iPhone|iPad|Android[^;)]*|Windows|Mac OS X|Linux').firstMatch(s);
  final out = (m?.group(0) ?? s);
  return out.isEmpty ? '✓' : (out.length > 30 ? out.substring(0, 30) : out);
}

Widget _label(String t) => Padding(
  padding: const EdgeInsets.only(bottom: 7),
  child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
);

// a 24h time chosen with the clock picker ('' = none)
class TimeField extends StatelessWidget {
  final String value;
  final String hint;
  final ValueChanged<String> onChanged;
  final bool clearable;
  const TimeField({super.key, required this.value, required this.onChanged, this.hint = '—', this.clearable = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final p = (value.isEmpty ? '08:00' : value).split(':');
        final t = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: int.tryParse(p[0]) ?? 8, minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0),
          builder: (c2, child) => MediaQuery(data: MediaQuery.of(c2).copyWith(alwaysUse24HourFormat: true), child: child!),
        );
        if (t != null) onChanged('${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.clock, size: 15, color: c.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value.isEmpty ? hint : value,
                style: TextStyle(fontWeight: FontWeight.w700, color: value.isEmpty ? c.muted : c.ink),
              ),
            ),
            if (clearable && value.isNotEmpty)
              InkWell(
                onTap: () => onChanged(''),
                child: Icon(LucideIcons.x, size: 14, color: c.muted),
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ STAFF
class StaffTab extends StatelessWidget {
  final AtCtx ctx;
  const StaffTab({super.key, required this.ctx});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final staff = ctx.staff;
    final active = staff.where((s) => s['active'] == true).length;
    final max = n(ctx.limits['staff']);
    final full = active >= max;
    final price = fmt(n(ctx.addon('att_staff')['price']));
    void edit(Json row) => showSheet<bool>(context, (_) => _StaffEditor(ctx: ctx, row: row, full: full));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        atPanel([
          MHead(ctx.a('tabs.staff'), icon: LucideIcons.users, sub: ctx.a('staffCount', {'n': active, 'max': max})),
          Muted(ctx.a('staffSub')),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: max == 0 ? 0 : (active / max).clamp(0, 1).toDouble(), minHeight: 6, color: c.brand, backgroundColor: c.bg2),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Btn(ctx.a('addStaff'), icon: LucideIcons.plus, small: true, onTap: ctx.readOnly ? null : () => edit({'active': !full})),
          ),
        ]),
        mGap,
        if (staff.isEmpty)
          atPanel([Icon(LucideIcons.users, size: 32, color: c.muted), const SizedBox(height: 8), Muted(ctx.a('noStaff'), align: TextAlign.center)])
        else
          atPanel(padding: const EdgeInsets.fromLTRB(10, 6, 10, 6), [
            for (final s in staff)
              Opacity(
                opacity: s['active'] == true ? 1 : .5,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: ctx.readOnly ? null : () => edit(s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                    child: Row(
                      children: [
                        AtAvatar(s['name'], color: str(ctx.shiftOf(s['shift_id'])?['color']), size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(str(s['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text('${str(s['phone'])}${str(s['position']).isNotEmpty ? ' · ${s['position']}' : ''}', style: TextStyle(color: c.muted, fontSize: 12.5)),
                              Text(
                                '📱 ${s['device_bound'] == true ? ctx.a('phoneLocked', {'label': _short(s['device_label'])}) : ctx.a('phoneFree')}',
                                style: TextStyle(color: s['device_bound'] == true ? c.good : c.muted, fontSize: 12),
                              ),
                              if (s['last_seen'] != null) Muted(ctx.a('seen', {'date': mDate(s['last_seen'], ctx.lang)})),
                            ],
                          ),
                        ),
                        if (s['active'] != true) Chip2(ctx.a('off')),
                        if (s['role'] == 'manager' && s['active'] == true) Chip2(ctx.a('roles.manager'), tone: Tone.brand),
                      ],
                    ),
                  ),
                ),
              ),
          ]),
        if (full) ...[
          mGap,
          atPanel([
            MHead(ctx.a('staffLimitTitle', {'max': max}), icon: LucideIcons.lock, sub: ctx.a('staffLimitSub', {'coins': price})),
            Align(
              alignment: Alignment.centerLeft,
              child: GoldBtn(ctx.a('buyStaff', {'coins': price}), onTap: ctx.readOnly ? null : () => ctx.askBuy('att_staff')),
            ),
          ]),
        ],
        if (objs(ctx.data['staff_slots']).isNotEmpty) ...[
          mGap,
          atPanel([
            for (final s in objs(ctx.data['staff_slots']))
              _SlotRow(
                ctx: ctx,
                icon: LucideIcons.users,
                title: ctx.a('staffSlot', {'n': str(s['item']).split('-').last}),
                slot: s,
                onRenew: () => ctx.askBuy('att_staff', item: str(s['item'])),
              ),
          ]),
        ],
      ],
    );
  }
}

class _SlotRow extends StatelessWidget {
  final AtCtx ctx;
  final IconData icon;
  final String title;
  final Json slot;
  final VoidCallback onRenew;
  const _SlotRow({required this.ctx, required this.icon, required this.title, required this.slot, required this.onRenew});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final on = slot['active'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 17, color: c.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(on ? ctx.a('slotEnds', {'date': mDate(slot['expires_at'], ctx.lang)}) : ctx.a('slotEnded'), style: TextStyle(color: on ? c.muted : c.danger, fontSize: 12.5)),
              ],
            ),
          ),
          Btn(ctx.a('renewSlot'), lead: const CoinIcon(size: 14), kind: BtnKind.ghost, small: true, onTap: ctx.readOnly ? null : onRenew),
        ],
      ),
    );
  }
}

const _profileKeys = ['start_date', 'birthday', 'contract_end', 'id_number', 'address', 'emergency_name', 'emergency_phone', 'notes'];

class _StaffEditor extends StatefulWidget {
  final AtCtx ctx;
  final Json row;
  final bool full;
  const _StaffEditor({required this.ctx, required this.row, required this.full});
  @override
  State<_StaffEditor> createState() => _StaffEditorState();
}

class _StaffEditorState extends State<_StaffEditor> with AtSave {
  AtCtx get ctx => widget.ctx;
  @override
  AtCtx get actx => ctx;
  late final Json r = widget.row;
  late final bool isNew = r['_id'] == null;
  late final Map<String, TextEditingController> _f = {
    for (final k in ['name', 'phone', 'position', 'bank_name', 'bank_account', 'account_name', 'id_number', 'address', 'emergency_name', 'emergency_phone', 'notes'])
      k: TextEditingController(text: str(r[k])),
    'salary': TextEditingController(text: r['salary'] == null || n(r['salary']) == 0 ? '' : '${n(r['salary'])}'.replaceFirst(RegExp(r'\.0$'), '')),
    'dependents': TextEditingController(text: '${n(r['dependents']).toInt()}'),
    'pin': TextEditingController(),
  };
  late String _role = str(r['role']).isEmpty ? 'staff' : str(r['role']);
  late String _shift = str(r['shift_id']).isNotEmpty ? str(r['shift_id']) : (isNew && ctx.shifts.length == 1 ? str(ctx.shifts.first['_id']) : '');
  late final Set<String> _branches = {...(r['branch_ids'] as List? ?? const []).map((e) => '$e')};
  late bool _active = r['active'] != false && !(isNew && widget.full);
  late String _payType = str(r['pay_type']).isEmpty ? 'monthly' : str(r['pay_type']);
  late String _contract = str(r['contract']).isEmpty ? 'udc' : str(r['contract']);
  late bool _resident = r['resident'] != false;
  late String _start = str(r['start_date']), _birthday = str(r['birthday']), _contractEnd = str(r['contract_end']);
  bool _more = false, _prof = false, _resetting = false;
  String sx(String k, [Map<String, Object?> v = const {}]) => ctx.t('atsx.$k', v);

  @override
  void dispose() {
    for (final c in _f.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _pinOk => isNew ? RegExp(r'^\d{4}$').hasMatch(_f['pin']!.text) : (_f['pin']!.text.isEmpty || RegExp(r'^\d{4}$').hasMatch(_f['pin']!.text));

  Json get _body => {
    'name': _f['name']!.text.trim(),
    'phone': _f['phone']!.text.trim(),
    'position': _f['position']!.text.trim(),
    'role': _role,
    'shift_id': _shift.isEmpty ? null : _shift,
    'branch_ids': _branches.toList(),
    'active': _active,
    if (_f['pin']!.text.isNotEmpty) 'pin': _f['pin']!.text,
    if (_f['salary']!.text.trim().isNotEmpty) 'salary': numOf(_f['salary']!.text) ?? 0,
    'pay_type': _payType,
    'dependents': int.tryParse(_f['dependents']!.text) ?? 0,
    'resident': _resident,
    'contract': _contract,
    'bank_name': _f['bank_name']!.text.trim(),
    'bank_account': _f['bank_account']!.text.trim(),
    'account_name': _f['account_name']!.text.trim(),
    for (final k in _profileKeys)
      k: switch (k) {
        'start_date' => _start,
        'birthday' => _birthday,
        'contract_end' => _contractEnd,
        _ => _f[k]!.text.trim(),
      },
  };

  Future<void> _resetPhone() async {
    setState(() => _resetting = true);
    if (await ctx.run(() => ctx.api.post('${ctx.base}/staff/${r['_id']}/reset-device'), ctx.a('resetDone')) != null) {
      await ctx.reload();
      if (mounted) Navigator.pop(context, true);
    }
    if (mounted) setState(() => _resetting = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final path = '${ctx.base}/staff';
    Widget two(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 10),
        Expanded(child: b),
      ],
    );
    return MSheet(
      title: isNew ? ctx.a('addStaff') : ctx.a('editStaff'),
      footer: footer(
        canSave: _f['name']!.text.trim().isNotEmpty && _f['phone']!.text.trim().isNotEmpty && _pinOk,
        onSave: () => save(() => isNew ? ctx.api.post(path, _body) : ctx.api.put('$path/${r['_id']}', _body)),
        onRemove: isNew ? null : () => save(() => ctx.api.delete('$path/${r['_id']}')),
      ),
      children: [
        Field(label: ctx.a('staffName'), controller: _f['name']!, maxLength: 80, autofocus: isNew, onChanged: (_) => setState(() {})),
        gap14,
        two(
          Field(label: ctx.a('phone'), controller: _f['phone']!, hint: '012 345 678', maxLength: 20, keyboard: TextInputType.phone, onChanged: (_) => setState(() {})),
          Field(
            label: isNew ? ctx.a('pin') : ctx.a('newPin'),
            controller: _f['pin']!,
            hint: '••••',
            maxLength: 4,
            keyboard: TextInputType.number,
            invalid: !_pinOk && _f['pin']!.text.isNotEmpty,
            onChanged: (v) {
              final d = v.replaceAll(RegExp(r'\D'), '');
              if (d != v) _f['pin']!.text = d;
              setState(() {});
            },
          ),
        ),
        const SizedBox(height: 4),
        Muted('${ctx.a('phoneHint')} ${ctx.a('pinHint')}'),
        gap14,
        Field(label: '${ctx.a('position')} (${ctx.a('optional')})', controller: _f['position']!, hint: ctx.a('positionPh'), maxLength: 60),
        gap14,
        _label(ctx.a('shift')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(label: Text(ctx.a('noShiftOpt').replaceAll('—', '').trim()), selected: _shift.isEmpty, onSelected: (_) => setState(() => _shift = '')),
            for (final s in ctx.shifts)
              ChoiceChip(
                avatar: CircleAvatar(radius: 5, backgroundColor: atHex(str(s['color']))),
                label: Text('${str(s['name'])} · ${str(s['start'])}–${str(s['end'])}'),
                selected: _shift == s['_id'],
                onSelected: (_) => setState(() => _shift = str(s['_id'])),
              ),
          ],
        ),
        gap14,
        _label('${ctx.a('salary')} (${ctx.a('optional')})'),
        Row(
          children: [
            Expanded(
              child: Field(controller: _f['salary']!, hint: '0', keyboard: decimalKeys),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Segmented<String>(
                value: _payType,
                options: [
                  for (final k in ['monthly', 'daily', 'hourly']) (k, ctx.a('payTypes.$k')),
                ],
                onChanged: (v) => setState(() => _payType = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Muted(ctx.a('salaryHint')),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: () => setState(() => _more = !_more), icon: Icon(_more ? LucideIcons.minus : LucideIcons.plus, size: 15), label: Text(ctx.a('payDetails'))),
        ),
        if (_more) ...[
          Field(label: ctx.a('bankName'), controller: _f['bank_name']!, hint: 'ABA, ACLEDA, Wing…', maxLength: 40),
          gap14,
          two(
            Field(label: ctx.a('bankAccount'), controller: _f['bank_account']!, maxLength: 40, keyboard: TextInputType.number),
            Field(label: ctx.a('accountName'), controller: _f['account_name']!, hint: _f['name']!.text, maxLength: 80),
          ),
          gap14,
          Field(label: ctx.a('dependents'), controller: _f['dependents']!, keyboard: TextInputType.number, maxLength: 2),
          const SizedBox(height: 4),
          Muted(ctx.a('dependentsHint')),
          gap14,
          _label(ctx.a('contract')),
          Segmented<String>(
            value: _contract,
            options: [
              for (final k in ['udc', 'fdc']) (k, ctx.a('contracts.$k')),
            ],
            onChanged: (v) => setState(() => _contract = v),
          ),
          gap14,
          _label(ctx.a('residentLabel')),
          Segmented<bool>(value: _resident, options: [(true, ctx.a('resident')), (false, ctx.a('nonResident'))], onChanged: (v) => setState(() => _resident = v)),
          gap14,
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: () => setState(() => _prof = !_prof), icon: Icon(_prof ? LucideIcons.minus : LucideIcons.plus, size: 15), label: Text(sx('profile'))),
        ),
        if (_prof) ...[
          two(
            DayField(label: sx('startDate'), value: _start, onChanged: (v) => setState(() => _start = v)),
            DayField(label: sx('birthday'), value: _birthday, first: DateTime(1940), onChanged: (v) => setState(() => _birthday = v)),
          ),
          gap14,
          DayField(label: sx('contractEnd'), value: _contractEnd, onChanged: (v) => setState(() => _contractEnd = v)),
          const SizedBox(height: 4),
          Muted(sx('contractHint')),
          gap14,
          Field(label: sx('idNumber'), controller: _f['id_number']!, maxLength: 40),
          gap14,
          two(
            Field(label: sx('emergency'), controller: _f['emergency_name']!, maxLength: 80),
            Field(label: sx('emergencyPhone'), controller: _f['emergency_phone']!, maxLength: 30, keyboard: TextInputType.phone),
          ),
          gap14,
          Field(label: sx('address'), controller: _f['address']!, maxLength: 200),
          gap14,
          Field(label: sx('notes'), controller: _f['notes']!, maxLength: 500, maxLines: 2),
          gap14,
        ],
        _label(ctx.a('role')),
        Segmented<String>(
          value: _role,
          options: [
            for (final k in ['staff', 'manager']) (k, ctx.a('roles.$k')),
          ],
          onChanged: (v) => setState(() => _role = v),
        ),
        if (_role == 'manager') ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: ctx.addonOn('att_manager') ? c.goodBg : c.warnBg, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ctx.addonOn('att_manager') ? sx('managerOn') : sx('managerOff'), style: const TextStyle(fontSize: 13)),
                if (!ctx.addonOn('att_manager')) ...[
                  const SizedBox(height: 8),
                  GoldBtn(
                    sx('unlock', {'coins': fmt(n(ctx.addon('att_manager')['price']) == 0 ? 40 : n(ctx.addon('att_manager')['price']))}),
                    onTap: ctx.readOnly ? null : () => ctx.askBuy('att_manager'),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (ctx.branches.length > 1) ...[
          gap14,
          _label(ctx.a('branchesLabel')),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              FilterChip(label: Text(ctx.a('allBranches')), selected: _branches.isEmpty, onSelected: (_) => setState(_branches.clear)),
              for (final b in ctx.branches)
                FilterChip(
                  label: Text(str(b['name'])),
                  selected: _branches.contains(b['_id']),
                  onSelected: (_) => setState(() => _branches.contains(b['_id']) ? _branches.remove(b['_id']) : _branches.add(str(b['_id']))),
                ),
            ],
          ),
        ],
        if (!isNew) ...[
          gap14,
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Icon(LucideIcons.smartphone, size: 17, color: c.muted),
                const SizedBox(width: 8),
                Expanded(child: Text(r['device_bound'] == true ? ctx.a('phoneLocked', {'label': _short(r['device_label'])}) : ctx.a('phoneFree'))),
                if (r['device_bound'] == true)
                  Btn(ctx.a('resetPhone'), icon: LucideIcons.refreshCw, kind: BtnKind.ghost, small: true, busy: _resetting, onTap: _resetting || busy ? null : _resetPhone),
              ],
            ),
          ),
          gap14,
          _StaffDocs(ctx: ctx, staffId: str(r['_id'])),
        ],
        const SizedBox(height: 6),
        SwitchRow(title: ctx.a('active'), value: _active, onChanged: (v) => setState(() => _active = v)),
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}

// documents of one staff (att_docs)
class _StaffDocs extends StatefulWidget {
  final AtCtx ctx;
  final String staffId;
  const _StaffDocs({required this.ctx, required this.staffId});
  @override
  State<_StaffDocs> createState() => _StaffDocsState();
}

class _StaffDocsState extends State<_StaffDocs> {
  Json? _d;
  bool _busy = false;
  Json? _draft; // {bytes, kind, name, expires}
  final _name = TextEditingController();
  AtCtx get ctx => widget.ctx;
  String sx(String k, [Map<String, Object?> v = const {}]) => ctx.t('atsx.$k', v);
  String get _path => '${ctx.base}/staff/${widget.staffId}/docs';

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
      final r = await ctx.api.get(_path);
      if (mounted) setState(() => _d = obj(r['data']));
    } catch (_) {
      if (mounted) setState(() => _d = {'on': false, 'rows': []});
    }
  }

  Future<void> _pick() async {
    final b = await atPickPicture(context, ctx, maxSize: 2000, cameraFirst: true);
    if (b == null) return;
    _name.clear();
    setState(() => _draft = {'bytes': b, 'kind': 'contract', 'expires': ''});
  }

  Future<void> _upload() async {
    final d = _draft!;
    setState(() => _busy = true);
    final form = fileForm('file', d['bytes'] as List<int>, 'doc.jpg')
      ..fields.addAll([MapEntry('kind', str(d['kind'])), MapEntry('name', _name.text.trim().isEmpty ? sx('kinds.${d['kind']}') : _name.text.trim()), MapEntry('expires', str(d['expires']))]);
    if (await ctx.run(() => ctx.api.post(_path, form)) != null) {
      setState(() => _draft = null);
      await _load();
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = _d;
    final today = todayKH();
    final rows = objs(d?['rows']);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.folderLock, size: 17, color: c.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(sx('docs'), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              if (d?['on'] == true && _draft == null && rows.length < n(d?['max'] ?? 20))
                Btn(sx('add'), icon: LucideIcons.imagePlus, kind: BtnKind.ghost, small: true, onTap: _busy || ctx.readOnly ? null : _pick),
            ],
          ),
          const SizedBox(height: 6),
          if (d == null)
            const Muted('…')
          else if (d['on'] != true && rows.isEmpty) ...[
            Muted(sx('docsLocked')),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: GoldBtn(sx('unlock', {'coins': fmt(n(ctx.addon('att_docs')['price']) == 0 ? 35 : n(ctx.addon('att_docs')['price']))}), onTap: ctx.readOnly ? null : () => ctx.askBuy('att_docs')),
            ),
          ] else ...[
            Muted(sx('docsSub')),
            if (_draft != null)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(_draft!['bytes'] as dynamic, width: 70, height: 70, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: [
                              for (final k in ['contract', 'id_card', 'certificate', 'other'])
                                ChoiceChip(label: Text(sx('kinds.$k')), selected: _draft!['kind'] == k, onSelected: (_) => setState(() => _draft!['kind'] = k)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Field(controller: _name, hint: '${sx('name')} · ${sx('kinds.${_draft!['kind']}')}', maxLength: 80),
                    const SizedBox(height: 8),
                    DayField(label: sx('expires'), value: str(_draft!['expires']), onChanged: (v) => setState(() => _draft!['expires'] = v)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Btn(ctx.a('cancel'), kind: BtnKind.ghost, small: true, onTap: _busy ? null : () => setState(() => _draft = null)),
                        const Spacer(),
                        Btn(_busy ? sx('uploading') : sx('add'), icon: LucideIcons.imagePlus, small: true, busy: _busy, onTap: _busy ? null : _upload),
                      ],
                    ),
                  ],
                ),
              ),
            if (rows.isEmpty && _draft == null) Padding(padding: const EdgeInsets.only(top: 6), child: Muted(sx('noDocs'))),
            for (final x in rows)
              () {
                final exp = str(x['expires']);
                final past = exp.isNotEmpty && exp.compareTo(today) < 0;
                final soon = exp.isNotEmpty && !past && exp.compareTo(addDaysKH(today, 30)) <= 0;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (dd) => GestureDetector(
                            onTap: () => Navigator.pop(dd),
                            child: InteractiveViewer(child: Image(image: netImage(str(x['url'])))),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image(image: netImage(
                            str(x['url'])),
                            width: 46,
                            height: 46,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(width: 46, height: 46, color: c.bg2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(str(x['name']).isEmpty ? sx('kinds.${x['kind']}') : str(x['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(
                              '${sx('kinds.${x['kind']}')} · ${exp.isEmpty ? sx('noEnd') : '${past ? sx('expired') : sx('expires')} ${ghDay(exp, ctx.lang, year: true)}'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: past
                                    ? c.danger
                                    : soon
                                    ? c.warn
                                    : c.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!ctx.readOnly)
                        SureDelete(
                          remove: sx('remove'),
                          sure: sx('sure'),
                          onDelete: () async {
                            await ctx.run(() => ctx.api.delete('$_path/${x['_id']}'));
                            _load();
                          },
                        ),
                    ],
                  ),
                );
              }(),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ BRANCHES
class BranchesTab extends StatelessWidget {
  final AtCtx ctx;
  const BranchesTab({super.key, required this.ctx});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final list = ctx.branches;
    final active = list.where((b) => b['active'] == true).length;
    final max = n(ctx.limits['branches']);
    final full = active >= max;
    final price = fmt(n(ctx.data['slot_price']));
    void edit(Json row) => showSheet<bool>(context, (_) => _BranchEditor(ctx: ctx, row: row));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        atPanel([
          MHead(ctx.a('tabs.branches'), icon: LucideIcons.mapPin, sub: ctx.a('branchCount', {'n': active, 'max': max})),
          Muted(ctx.a('branchSub')),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Btn(
              ctx.a('addBranch'),
              icon: full && list.isNotEmpty ? LucideIcons.lock : LucideIcons.plus,
              small: true,
              onTap: ctx.readOnly ? null : () => full && list.isNotEmpty ? ctx.askBuy('att_branch') : edit({}),
            ),
          ),
        ]),
        mGap,
        if (list.isEmpty)
          atPanel([Icon(LucideIcons.mapPin, size: 32, color: c.muted), const SizedBox(height: 8), Muted(ctx.a('noBranch'), align: TextAlign.center)])
        else
          for (final b in list) ...[
            () {
              final has = b['lat'] is num && b['lng'] is num;
              return Opacity(
                opacity: b['active'] == true ? 1 : .5,
                child: Panel(
                  padding: const EdgeInsets.all(14),
                  onTap: ctx.readOnly ? null : () => edit(b),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: has ? c.goodBg : c.bg2, borderRadius: BorderRadius.circular(14)),
                        child: Icon(LucideIcons.mapPin, color: has ? c.good : c.muted),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(str(b['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(
                              str(b['address']).isNotEmpty
                                  ? str(b['address'])
                                  : has
                                  ? '${n(b['lat']).toStringAsFixed(5)}, ${n(b['lng']).toStringAsFixed(5)}'
                                  : ctx.a('noLocation'),
                              style: TextStyle(color: c.muted, fontSize: 12.5),
                            ),
                            Muted(ctx.a('radiusHint', {'m': n(b['radius_m'])}).split('.').first),
                          ],
                        ),
                      ),
                      if (b['active'] != true) Chip2(ctx.a('off')),
                      if (b['active'] == true && b['usable'] == false) Chip2(ctx.a('overLimit'), tone: Tone.warn),
                    ],
                  ),
                ),
              );
            }(),
            mGap,
          ],
        if (full && list.isNotEmpty)
          atPanel([
            MHead(ctx.a('branchLimitTitle'), icon: LucideIcons.mapPin, sub: ctx.a('branchLimitSub', {'coins': price})),
            Align(
              alignment: Alignment.centerLeft,
              child: GoldBtn(ctx.a('buyBranch', {'coins': price}), onTap: ctx.readOnly ? null : () => ctx.askBuy('att_branch')),
            ),
          ]),
      ],
    );
  }
}

class _BranchEditor extends StatefulWidget {
  final AtCtx ctx;
  final Json row;
  const _BranchEditor({required this.ctx, required this.row});
  @override
  State<_BranchEditor> createState() => _BranchEditorState();
}

class _BranchEditorState extends State<_BranchEditor> with AtSave {
  AtCtx get ctx => widget.ctx;
  @override
  AtCtx get actx => ctx;
  late final Json r = widget.row;
  late final isNew = r['_id'] == null;
  late final _name = TextEditingController(text: str(r['name']));
  late final _addr = TextEditingController(text: str(r['address']));
  late final _lat = TextEditingController(text: r['lat'] == null ? '' : '${r['lat']}');
  late final _lng = TextEditingController(text: r['lng'] == null ? '' : '${r['lng']}');
  late double _radius = n(r['radius_m']) == 0 ? 100 : n(r['radius_m']).toDouble();
  late bool _active = r['active'] != false;

  @override
  void dispose() {
    for (final c in [_name, _addr, _lat, _lng]) {
      c.dispose();
    }
    super.dispose();
  }

  // "11.5564, 104.9282" (or a Google Maps link with @lat,lng / q=lat,lng) pasted fills both boxes
  void _onLat(String v) {
    final m = RegExp(r'(-?\d{1,3}\.\d+)\s*[, ]\s*(-?\d{1,3}\.\d+)').firstMatch(v);
    if (m != null) {
      _lat.text = m.group(1)!;
      _lng.text = m.group(2)!;
    }
    setState(() {});
  }

  bool get _has => num.tryParse(_lat.text.trim()) != null && num.tryParse(_lng.text.trim()) != null;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final body = {
      'name': _name.text.trim(),
      'address': _addr.text.trim(),
      'lat': num.tryParse(_lat.text.trim()),
      'lng': num.tryParse(_lng.text.trim()),
      'radius_m': _radius.round(),
      'active': _active,
    };
    final path = '${ctx.base}/branches';
    return MSheet(
      title: isNew ? ctx.a('addBranch') : ctx.a('editBranch'),
      footer: footer(
        canSave: _name.text.trim().isNotEmpty,
        onSave: () => save(() => isNew ? ctx.api.post(path, body) : ctx.api.put('$path/${r['_id']}', body)),
        onRemove: isNew ? null : () => save(() => ctx.api.delete('$path/${r['_id']}')),
      ),
      children: [
        Field(label: ctx.a('branchName'), controller: _name, maxLength: 80, autofocus: isNew, onChanged: (_) => setState(() {})),
        gap14,
        Field(label: '${ctx.a('address')} (${ctx.a('optional')})', controller: _addr, maxLength: 200),
        gap14,
        _label(ctx.a('location')),
        Row(
          children: [
            Expanded(
              child: Field(controller: _lat, hint: ctx.a('lat'), keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: _onLat),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Field(controller: _lng, hint: ctx.a('lng'), keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {})),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Muted(ctx.a('pasteHint')),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: () async {
                final d = await Clipboard.getData('text/plain');
                if (d?.text != null) _onLat(d!.text!);
              },
              icon: const Icon(LucideIcons.clipboardPaste, size: 15),
              label: Text(ctx.t.or('app.paste', 'Paste')),
            ),
            if (_has)
              TextButton.icon(
                onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps?q=${_lat.text.trim()},${_lng.text.trim()}'), mode: LaunchMode.externalApplication),
                icon: const Icon(LucideIcons.externalLink, size: 15),
                label: Text(ctx.a('openMap')),
              ),
          ],
        ),
        gap14,
        _label(ctx.a('radius')),
        Row(
          children: [
            Expanded(
              child: Slider(value: _radius.clamp(20, 1000), min: 20, max: 1000, divisions: 98, onChanged: (v) => setState(() => _radius = v)),
            ),
            SizedBox(
              width: 60,
              child: Text(
                '${_radius.round()} m',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        Muted(ctx.a('radiusHint', {'m': _radius.round()})),
        const SizedBox(height: 6),
        SwitchRow(title: ctx.a('active'), value: _active, onChanged: (v) => setState(() => _active = v)),
        if (!_has)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: c.warnBg, borderRadius: BorderRadius.circular(12)),
            child: Text(
              ctx.a('noLocation'),
              style: TextStyle(color: c.warn, fontWeight: FontWeight.w700),
            ),
          ),
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ SHIFTS
class ShiftsTab extends StatelessWidget {
  final AtCtx ctx;
  const ShiftsTab({super.key, required this.ctx});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final dayShort = ctx.t.list('att.dayShort');
    void edit(Json row) => showSheet<bool>(context, (_) => _ShiftEditor(ctx: ctx, row: row));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        atPanel([
          MHead(ctx.a('tabs.shifts'), icon: LucideIcons.clock, sub: ctx.a('shiftSub')),
          Align(
            alignment: Alignment.centerLeft,
            child: Btn(ctx.a('addShift'), icon: LucideIcons.plus, small: true, onTap: ctx.readOnly ? null : () => edit({})),
          ),
        ]),
        mGap,
        if (ctx.shifts.isEmpty)
          atPanel([Icon(LucideIcons.clock, size: 32, color: c.muted), const SizedBox(height: 8), Muted(ctx.a('noShifts'), align: TextAlign.center)])
        else
          for (final s in ctx.shifts) ...[
            () {
              final col = atHex(str(s['color']));
              final days = (s['days'] as List? ?? const []).map((e) => n(e).toInt()).toSet();
              final count = ctx.staff.where((x) => x['active'] == true && x['shift_id'] == s['_id']).length;
              final win = [s['in_from'], s['in_to'], s['out_from'], s['out_to']].any((x) => str(x).isNotEmpty);
              String or(Object? v) => str(v).isEmpty ? '…' : str(v);
              return Opacity(
                opacity: s['active'] == false ? .5 : 1,
                child: Panel(
                  padding: EdgeInsets.zero,
                  onTap: ctx.readOnly ? null : () => edit(s),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: col, width: 5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(str(s['name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                            ),
                            Chip2(ctx.a('staffOnShift', {'n': count})),
                          ],
                        ),
                        Text(
                          '${str(s['start'])} – ${str(s['end'])}${str(s['end']).compareTo(str(s['start'])) < 0 ? ' 🌙' : ''}${n(s['break_min']) > 0 ? ' · ☕ ${n(s['break_min'])}m' : ''}',
                          style: TextStyle(fontWeight: FontWeight.w700, color: col),
                        ),
                        if (win) Muted('${ctx.a('inShort')} ${or(s['in_from'])}–${or(s['in_to'])} · ${ctx.a('outShort')} ${or(s['out_from'])}–${or(s['out_to'])}'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (final d in dayOrder)
                              Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(color: days.contains(d) ? col.withValues(alpha: .15) : c.bg2, borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                  d < dayShort.length ? dayShort[d] : '$d',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: days.contains(d) ? col : c.muted),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }(),
            mGap,
          ],
      ],
    );
  }
}

class _ShiftEditor extends StatefulWidget {
  final AtCtx ctx;
  final Json row;
  const _ShiftEditor({required this.ctx, required this.row});
  @override
  State<_ShiftEditor> createState() => _ShiftEditorState();
}

class _ShiftEditorState extends State<_ShiftEditor> with AtSave {
  AtCtx get ctx => widget.ctx;
  @override
  AtCtx get actx => ctx;
  late final Json r = widget.row;
  late final isNew = r['_id'] == null;
  late final _name = TextEditingController(text: str(r['name']));
  late final _break = TextEditingController(text: '${r['break_min'] == null ? 60 : n(r['break_min']).toInt()}');
  late String _start = str(r['start']).isEmpty ? '08:00' : str(r['start']), _end = str(r['end']).isEmpty ? '17:00' : str(r['end']);
  late String _inFrom = str(r['in_from']), _inTo = str(r['in_to']), _outFrom = str(r['out_from']), _outTo = str(r['out_to']);
  late final Set<int> _days = {
    ...(r['days'] as List? ?? const [1, 2, 3, 4, 5, 6]).map((e) => n(e).toInt()),
  };
  late String _color = str(r['color']).isEmpty ? atColors.first : str(r['color']);
  late bool _active = r['active'] != false;
  late bool _limit = [_inFrom, _inTo, _outFrom, _outTo].any((x) => x.isNotEmpty);

  @override
  void dispose() {
    _name.dispose();
    _break.dispose();
    super.dispose();
  }

  String _shift(String t, int min) {
    final p = t.split(':').map(int.parse).toList();
    final v = (((p[0] * 60 + p[1] + min) % 1440) + 1440) % 1440;
    return '${(v ~/ 60).toString().padLeft(2, '0')}:${(v % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final dayShort = ctx.t.list('att.dayShort');
    final body = {
      'name': _name.text.trim(),
      'start': _start,
      'end': _end,
      'break_min': int.tryParse(_break.text) ?? 0,
      'days': _days.toList(),
      'color': _color,
      'active': _active,
      'in_from': _limit ? _inFrom : '',
      'in_to': _limit ? _inTo : '',
      'out_from': _limit ? _outFrom : '',
      'out_to': _limit ? _outTo : '',
    };
    final path = '${ctx.base}/shifts';
    return MSheet(
      title: isNew ? ctx.a('addShift') : ctx.a('editShift'),
      footer: footer(
        canSave: _name.text.trim().isNotEmpty && _start != _end,
        onSave: () => save(() => isNew ? ctx.api.post(path, body) : ctx.api.put('$path/${r['_id']}', body)),
        onRemove: isNew ? null : () => save(() => ctx.api.delete('$path/${r['_id']}')),
      ),
      children: [
        Field(label: ctx.a('shiftName'), hint: ctx.a('shiftNamePh'), controller: _name, maxLength: 60, autofocus: isNew, onChanged: (_) => setState(() {})),
        gap14,
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _label(ctx.a('start')),
                  TimeField(value: _start, onChanged: (v) => setState(() => _start = v)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _label(ctx.a('end')),
                  TimeField(value: _end, onChanged: (v) => setState(() => _end = v)),
                ],
              ),
            ),
          ],
        ),
        if (_end.compareTo(_start) < 0) Padding(padding: const EdgeInsets.only(top: 6), child: Muted('🌙 ${ctx.a('nightHint')}')),
        const SizedBox(height: 6),
        SwitchRow(
          title: ctx.a('limitTimes'),
          sub: ctx.a('limitHint'),
          value: _limit,
          onChanged: (v) => setState(() {
            _limit = v;
            if (v && [_inFrom, _inTo, _outFrom, _outTo].every((x) => x.isEmpty)) {
              _inFrom = _shift(_start, -60);
              _inTo = _shift(_start, 60);
              _outFrom = _shift(_end, -15);
              _outTo = _shift(_end, 120);
            }
          }),
        ),
        if (_limit) ...[
          for (final (label, from, to, setFrom, setTo) in [
            (ctx.a('inAllowed'), _inFrom, _inTo, (String v) => _inFrom = v, (String v) => _inTo = v),
            (ctx.a('outAllowed'), _outFrom, _outTo, (String v) => _outFrom = v, (String v) => _outTo = v),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: TimeField(value: from, clearable: true, onChanged: (v) => setState(() => setFrom(v))),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('–')),
                  Expanded(
                    child: TimeField(value: to, clearable: true, onChanged: (v) => setState(() => setTo(v))),
                  ),
                ],
              ),
            ),
        ],
        gap14,
        Field(label: ctx.a('breakMin'), controller: _break, keyboard: TextInputType.number, maxLength: 3),
        gap14,
        _label(ctx.a('days')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final d in dayOrder)
              FilterChip(label: Text(d < dayShort.length ? dayShort[d] : '$d'), selected: _days.contains(d), onSelected: (_) => setState(() => _days.contains(d) ? _days.remove(d) : _days.add(d))),
          ],
        ),
        gap14,
        _label(ctx.a('color')),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final h in atColors)
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _color = h),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: atHex(h),
                    shape: BoxShape.circle,
                    border: Border.all(color: _color == h ? c.ink : Colors.transparent, width: 3),
                  ),
                  child: _color == h ? const Icon(LucideIcons.check, size: 15, color: Colors.white) : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        SwitchRow(title: ctx.a('active'), value: _active, onChanged: (v) => setState(() => _active = v)),
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ RULES & LINK
const _ruleKeys = ['late_grace_min', 'early_grace_min', 'ot_after_min', 'max_accuracy_m', 'auto_out_hours'];

class SettingsTab extends StatefulWidget {
  final AtCtx ctx;
  const SettingsTab({super.key, required this.ctx});
  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  AtCtx get ctx => widget.ctx;
  late final Map<String, TextEditingController> _rules = {for (final k in _ruleKeys) k: TextEditingController(text: '${n(ctx.rules[k]).toInt()}')};
  final _qr = GlobalKey();
  bool _saving = false, _askNew = false;

  @override
  void dispose() {
    for (final c in _rules.values) {
      c.dispose();
    }
    super.dispose();
  }

  String get _link => '${Config.siteUrl}/a/${str(ctx.data['code'])}';
  bool get _dirty => _ruleKeys.any((k) => (int.tryParse(_rules[k]!.text) ?? -1) != n(ctx.rules[k]).toInt());

  Future<void> _saveRules() async {
    setState(() => _saving = true);
    if (await ctx.run(() => ctx.api.put('${ctx.base}/rules', {for (final k in _ruleKeys) k: int.tryParse(_rules[k]!.text) ?? 0}), ctx.a('saved')) != null) await ctx.reload();
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final link = _link;
    final slotPrice = fmt(n(ctx.data['slot_price']));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        atPanel([
          MHead(ctx.a('linkTitle'), icon: LucideIcons.link2, sub: ctx.a('linkSub')),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
            child: SelectableText(link, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          Center(
            child: RepaintBoundary(
              key: _qr,
              child: Container(
                padding: const EdgeInsets.all(14),
                color: Colors.white,
                child: Column(
                  children: [
                    QrImageView(data: link, size: 190),
                    const SizedBox(height: 6),
                    Text(
                      str(ctx.business['name']),
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Btn(
                ctx.a('copy'),
                icon: LucideIcons.copy,
                small: true,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  ctx.notify(ctx.a('copied'));
                },
              ),
              Btn(
                ctx.a('share'),
                icon: LucideIcons.share2,
                kind: BtnKind.ghost,
                small: true,
                onTap: () => SharePlus.instance.share(ShareParams(text: '${ctx.a('linkSub')}\n$link')),
              ),
              Btn(ctx.a('downloadQr'), icon: LucideIcons.download, kind: BtnKind.ghost, small: true, onTap: () => shareWidgets([_qr], (_) => 'attendance-qr-${ctx.data['code']}.png')),
              Btn(ctx.a('changeStyle'), icon: LucideIcons.palette, kind: BtnKind.ghost, small: true, onTap: () => ctx.go('looks')),
              if (!ctx.readOnly && !_askNew) Btn(ctx.a('newLink'), icon: LucideIcons.refreshCw, kind: BtnKind.ghost, small: true, onTap: () => setState(() => _askNew = true)),
            ],
          ),
          if (_askNew)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.warnBg, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    ctx.a('newLinkSure'),
                    style: TextStyle(color: c.warn, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Spacer(),
                      Btn(ctx.a('cancel'), kind: BtnKind.ghost, small: true, onTap: () => setState(() => _askNew = false)),
                      const SizedBox(width: 8),
                      Btn(
                        ctx.a('newLink'),
                        icon: LucideIcons.refreshCw,
                        small: true,
                        onTap: () async {
                          setState(() => _askNew = false);
                          if (await ctx.run(() => ctx.api.post('${ctx.base}/code'), ctx.a('saved')) != null) await ctx.reload();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ]),
        mGap,
        atPanel([
          Text(ctx.a('rulesTitle'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          for (final k in _ruleKeys)
            () {
              final words = ctx.t.list('att.rules.$k');
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(child: Text(words.isNotEmpty ? words[0] : k)),
                    SizedBox(
                      width: 80,
                      child: Field(controller: _rules[k]!, keyboard: TextInputType.number, align: TextAlign.center, enabled: !ctx.readOnly, maxLength: 4, onChanged: (_) => setState(() {})),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 96,
                      child: Text(words.length > 1 ? words[1] : '', style: TextStyle(color: c.muted, fontSize: 12.5)),
                    ),
                  ],
                ),
              );
            }(),
          Muted(ctx.a('rulesNote')),
          if (_dirty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                Btn(
                  ctx.a('cancel'),
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: () => setState(() {
                    for (final k in _ruleKeys) {
                      _rules[k]!.text = '${n(ctx.rules[k]).toInt()}';
                    }
                  }),
                ),
                const SizedBox(width: 8),
                Btn(ctx.a('save'), small: true, busy: _saving, onTap: _saving || ctx.readOnly ? null : _saveRules),
              ],
            ),
          ],
        ]),
        mGap,
        atPanel([
          MHead(
            ctx.lang == 'km' ? 'ពិនិត្យ GPS ក្លែងក្លាយ' : 'Fake GPS check',
            icon: LucideIcons.shieldCheck,
            sub: ctx.lang == 'km'
                ? 'ចាប់កម្មវិធីក្លែងទីតាំង៖ GPS ភាពត្រឹមត្រូវ 0 m ទីតាំងដដែលបេះបិទជាមួយថ្ងៃមុន ឬលោតឆ្ងាយលឿនជាង 250 km/h។ កំណត់ត្រាទាំងនោះទៅ “ត្រូវពិនិត្យ”។'
                : 'Catches location-faking apps: GPS that claims 0 m accuracy, the exact same spot as another day, or a jump faster than 250 km/h. Those records go to “Needs review”.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: ctx.addonOn('att_gps_guard')
                ? Chip2(ctx.lang == 'km' ? 'កំពុងដំណើរការ' : 'On for every clock-in', icon: LucideIcons.check, tone: Tone.good)
                : GoldBtn(
                    ctx.a('unlockFor', {'coins': fmt(n(ctx.addon('att_gps_guard')['price']) == 0 ? 40 : n(ctx.addon('att_gps_guard')['price']))}),
                    onTap: ctx.readOnly ? null : () => ctx.askBuy('att_gps_guard'),
                  ),
          ),
        ]),
        mGap,
        atPanel([
          MHead(ctx.a('selfieTitle'), icon: LucideIcons.camera, sub: ctx.a('selfieSub')),
          if (ctx.addonOn('att_selfie'))
            SwitchRow(
              title: ctx.a('selfieOn'),
              value: ctx.data['selfie_required'] != false,
              onChanged: ctx.readOnly
                  ? null
                  : (v) async {
                      if (await ctx.run(() => ctx.api.put('${ctx.base}/selfie', {'required': v})) != null) await ctx.reload();
                    },
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: GoldBtn(ctx.a('unlockFor', {'coins': fmt(n(ctx.addon('att_selfie')['price']))}), onTap: ctx.readOnly ? null : () => ctx.askBuy('att_selfie')),
            ),
        ]),
        mGap,
        atPanel([
          MHead(ctx.a('addonsTitle'), icon: LucideIcons.mapPin, sub: ctx.a('addonsSub', {'coins': slotPrice})),
          for (final s in objs(ctx.data['slots']))
            _SlotRow(
              ctx: ctx,
              icon: LucideIcons.mapPin,
              title: ctx.a('slot', {'n': str(s['item']).split('-').last}),
              slot: s,
              onRenew: () => ctx.askBuy('att_branch', item: str(s['item'])),
            ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: GoldBtn(ctx.a('buyBranch', {'coins': slotPrice}), onTap: ctx.readOnly ? null : () => ctx.askBuy('att_branch')),
          ),
        ]),
      ],
    );
  }
}
