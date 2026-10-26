import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../guesthouse/gh_common.dart' show ghDay, ghMonth, shiftMonth;
import '../mart/mart_common.dart' show GoldBtn, mGap, todayKH, money;
import '../mart/mart_kit.dart' show MSheet, showSheet, DayField, decimalKeys, numOf;
import '../restaurant/rest_common.dart' show Segmented, SwitchRow, gap14;
import '../restaurant/rest_online.dart' show shareWidgets;
import 'at_addons.dart';
import 'at_common.dart';

// Leave · Payroll — AddonTabs.jsx (same API, same words)

String _hm(Object? min) {
  final m = n(min).toInt();
  return m == 0 ? '0' : '${m ~/ 60}h${m % 60 > 0 ? ' ${m % 60}m' : ''}';
}

Widget _seg<V>(BuildContext context, V value, List<(V, String)> options, ValueChanged<V> onChanged) => SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Wrap(
    spacing: 6,
    children: [for (final (v, label) in options) ChoiceChip(label: Text(label), selected: value == v, onSelected: (_) => onChanged(v))],
  ),
);

// ------------------------------------------------------------------------------------------------ LEAVE
class LeaveTab extends StatefulWidget {
  final AtCtx ctx;
  const LeaveTab({super.key, required this.ctx});
  @override
  State<LeaveTab> createState() => _LeaveTabState();
}

class _LeaveTabState extends State<LeaveTab> {
  AtCtx get ctx => widget.ctx;
  String _show = 'pending';
  Json? _data;
  final Map<String, TextEditingController> _notes = {};
  String _busy = '';
  final _annual = TextEditingController();
  String x(String k, [Map<String, Object?> v = const {}]) => ctx.t('atx.$k', v);
  String _type(Object? k) => ctx.t.or('sax.types.$k', '$k');

  @override
  void initState() {
    super.initState();
    if (ctx.addonOn('att_leave')) _load();
  }

  @override
  void dispose() {
    _annual.dispose();
    for (final c in _notes.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/leave', _show == 'all' ? null : {'status': _show});
      if (!mounted) return;
      setState(() {
        _data = obj(r['data']);
        _annual.text = '${n(_data!['annual_days']).toInt()}';
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _act(String id, Future<Json> Function() fn) async {
    setState(() => _busy = id);
    if (await ctx.run(fn) != null) {
      await _load();
      ctx.reload();
    }
    if (mounted) setState(() => _busy = '');
  }

  @override
  Widget build(BuildContext context) {
    if (!ctx.addonOn('att_leave')) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [AtLocked(ctx: ctx, addon: 'att_leave')],
      );
    }
    final c = context.c;
    final d = _data;
    if (d == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 3));
    final rows = objs(d['rows']);
    final pending = n(d['pending']).toInt();
    final annualChanged = _annual.text != '${n(d['annual_days']).toInt()}';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        atPanel([
          Row(
            children: [
              Expanded(
                child: Text(ctx.a('tabs.leave'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              Btn(
                x('addLeave'),
                icon: LucideIcons.plus,
                small: true,
                onTap: ctx.readOnly ? null : () => showSheet<bool>(context, (_) => _LeaveSheet(ctx: ctx)).then((ok) => ok == true ? _load() : null),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Muted(x('leaveSub')),
          const SizedBox(height: 12),
          _seg<String>(
            context,
            _show,
            [
              for (final k in ['pending', 'approved', 'rejected', 'all']) (k, '${x(k)}${k == 'pending' && pending > 0 ? ' ($pending)' : ''}'),
            ],
            (v) {
              setState(() {
                _show = v;
                _data = null;
              });
              _load();
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text(x('annualDays'))),
              SizedBox(
                width: 70,
                child: Field(controller: _annual, keyboard: TextInputType.number, align: TextAlign.center, maxLength: 2, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
              ),
              const SizedBox(width: 6),
              Text(x('daysWord')),
              if (annualChanged) ...[
                const SizedBox(width: 8),
                Btn(
                  x('save'),
                  small: true,
                  onTap: () async {
                    if (await ctx.run(() => ctx.api.put('${ctx.base}/leave-settings', {'annual_days': int.tryParse(_annual.text) ?? 0}), x('saved')) != null) _load();
                  },
                ),
              ],
            ],
          ),
        ]),
        mGap,
        if (rows.isEmpty)
          atPanel([Muted(x('noLeave'), align: TextAlign.center)])
        else
          for (final l in rows) ...[
            () {
              final id = str(l['_id']);
              final note = _notes.putIfAbsent(id, TextEditingController.new);
              final status = str(l['status']);
              return atPanel(padding: const EdgeInsets.all(14), [
                Row(
                  children: [
                    AtAvatar(l['staff_name'], size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(str(l['staff_name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(
                            '${ghDay(str(l['from']), ctx.lang, weekday: true)}${l['to'] != l['from'] ? ' → ${ghDay(str(l['to']), ctx.lang, weekday: true)}' : ''} · ${x('days', {'n': n(l['days'])})}',
                            style: TextStyle(color: c.muted, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AtTag(_type(l['type']), tone: l['type'] == 'sick' ? 'warn' : (l['type'] == 'unpaid' ? 'bad' : 'blue')),
                    AtTag(
                      x(status),
                      tone: switch (status) {
                        'approved' => 'ok',
                        'rejected' => 'bad',
                        'pending' => 'warn',
                        _ => '',
                      },
                    ),
                  ],
                ),
                if (str(l['reason']).isNotEmpty) ...[const SizedBox(height: 8), Text('“${l['reason']}”')],
                if (str(l['note']).isNotEmpty) Muted('↳ ${l['note']}'),
                if (str(l['by']).isNotEmpty && l['by'] != 'staff') Muted(x('byOwner', {'name': l['by']})),
                if (!ctx.readOnly) ...[
                  const SizedBox(height: 10),
                  if (status == 'pending') ...[
                    Field(controller: note, hint: x('notePh'), maxLength: 300),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Btn(
                            x('reject'),
                            icon: LucideIcons.x,
                            kind: BtnKind.ghost,
                            small: true,
                            onTap: _busy == id ? null : () => _act(id, () => ctx.api.post('${ctx.base}/leave/$id/decide', {'status': 'rejected', 'note': note.text})),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Btn(
                            x('approve'),
                            icon: LucideIcons.check,
                            small: true,
                            onTap: _busy == id ? null : () => _act(id, () => ctx.api.post('${ctx.base}/leave/$id/decide', {'status': 'approved', 'note': note.text})),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Align(
                      alignment: Alignment.centerRight,
                      child: Btn(x('remove'), icon: LucideIcons.trash2, kind: BtnKind.ghost, small: true, onTap: _busy == id ? null : () => _act(id, () => ctx.api.delete('${ctx.base}/leave/$id'))),
                    ),
                ],
              ]);
            }(),
            mGap,
          ],
      ],
    );
  }
}

class _LeaveSheet extends StatefulWidget {
  final AtCtx ctx;
  const _LeaveSheet({required this.ctx});
  @override
  State<_LeaveSheet> createState() => _LeaveSheetState();
}

class _LeaveSheetState extends State<_LeaveSheet> with AtSave {
  AtCtx get ctx => widget.ctx;
  @override
  AtCtx get actx => ctx;
  late final staff = ctx.staff.where((s) => s['active'] == true).toList();
  late String _staff = staff.isEmpty ? '' : str(staff.first['_id']);
  String _type = 'annual';
  String _from = todayKH(), _to = todayKH();
  final _reason = TextEditingController();
  String x(String k) => ctx.t('atx.$k');

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MSheet(
    title: x('addLeave'),
    footer: footer(
      canSave: _staff.isNotEmpty,
      onSave: () => save(() => ctx.api.post('${ctx.base}/leave', {'staff_id': _staff, 'type': _type, 'from': _from, 'to': _to, 'reason': _reason.text.trim()}), ok: x('saved')),
    ),
    children: [
      Text(x('staff'), style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 7),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [for (final s in staff) ChoiceChip(label: Text(str(s['name'])), selected: _staff == s['_id'], onSelected: (_) => setState(() => _staff = str(s['_id'])))],
      ),
      gap14,
      Text(x('type'), style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 7),
      Segmented<String>(
        value: _type,
        options: [
          for (final k in ['annual', 'sick', 'personal', 'unpaid']) (k, ctx.t.or('sax.types.$k', k)),
        ],
        onChanged: (v) => setState(() => _type = v),
      ),
      gap14,
      Row(
        children: [
          Expanded(
            child: DayField(
              label: x('from'),
              value: _from,
              onChanged: (v) => setState(() {
                _from = v;
                if (_to.compareTo(v) < 0) _to = v;
              }),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DayField(label: x('to'), value: _to, first: DateTime.parse('${_from}T00:00:00Z'), onChanged: (v) => setState(() => _to = v)),
          ),
        ],
      ),
      gap14,
      Field(label: x('reason'), controller: _reason, maxLength: 300),
      if (error.isNotEmpty) ...[gap14, Alert(error)],
    ],
  );
}

// ------------------------------------------------------------------------------------------------ PAYROLL
class PayrollTab extends StatefulWidget {
  final AtCtx ctx;
  const PayrollTab({super.key, required this.ctx});
  @override
  State<PayrollTab> createState() => _PayrollTabState();
}

class _PayrollTabState extends State<PayrollTab> {
  AtCtx get ctx => widget.ctx;
  late String _month = todayKH().substring(0, 7);
  Json? _data;
  bool _rules = false, _exporting = false;
  String x(String k, [Map<String, Object?> v = const {}]) => ctx.t('atx.$k', v);

  @override
  void initState() {
    super.initState();
    if (ctx.addonOn('att_payroll')) _load();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/payroll', {'month': _month});
      if (mounted) setState(() => _data = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _set(Json patch) async {
    if (await ctx.run(() => ctx.api.put('${ctx.base}/payroll/settings', patch)) != null) _load();
  }

  Future<void> _export(String format) async {
    setState(() => _exporting = true);
    try {
      final text = await ctx.api.text('${ctx.base}/payroll', {'month': _month, 'format': format, 'lang': ctx.lang});
      final name = format == 'bank' ? 'bank-transfer-$_month.csv' : 'payroll-$_month.csv';
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(utf8.encode(text), name: name, mimeType: 'text/csv')],
        ),
      );
    } catch (e) {
      ctx.fail(e);
    }
    if (mounted) setState(() => _exporting = false);
  }

  Future<void> _salary(Json r) async {
    final cur = str(obj(_data!['settings'])['currency']).isEmpty ? 'USD' : str(obj(_data!['settings'])['currency']);
    final ctl = TextEditingController(text: n(r['salary']) == 0 ? '' : '${n(r['salary'])}'.replaceFirst(RegExp(r'\.0$'), ''));
    String type = str(r['pay_type']).isEmpty ? 'monthly' : str(r['pay_type']);
    final ok = await showSheet<bool>(
      context,
      (sheet) => StatefulBuilder(
        builder: (sheet, set) => MSheet(
          title: '${x('col.salary')} · ${str(obj(r['staff'])['name'])}',
          footer: [
            const Spacer(),
            Btn(x('cancel'), kind: BtnKind.ghost, small: true, onTap: () => Navigator.pop(sheet)),
            const SizedBox(width: 8),
            Btn(x('save'), small: true, onTap: () => Navigator.pop(sheet, true)),
          ],
          children: [
            Field(label: '${x('col.salary')} (${cur == 'KHR' ? '៛' : '\$'})', controller: ctl, keyboard: decimalKeys, autofocus: true),
            gap14,
            Text(x('payType'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 7),
            Segmented<String>(
              value: type,
              options: [
                for (final k in ['monthly', 'daily', 'hourly']) (k, x('types.$k')),
              ],
              onChanged: (v) => set(() => type = v),
            ),
          ],
        ),
      ),
    );
    final v = numOf(ctl.text);
    ctl.dispose();
    if (ok != true || v == null || v < 0) return;
    if (await ctx.run(() => ctx.api.put('${ctx.base}/payroll/salary/${obj(r['staff'])['_id']}', {'salary': v, 'pay_type': type})) != null) {
      await _load();
      ctx.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ctx.addonOn('att_payroll')) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [AtLocked(ctx: ctx, addon: 'att_payroll')],
      );
    }
    final c = context.c;
    final d = _data;
    final st = obj(d?['settings']);
    final cur = str(st['currency']).isEmpty ? 'USD' : str(st['currency']);
    final rows = objs(d?['rows']);
    num sum(num Function(Json) f) => rows.fold<num>(0, (a, r) => a + f(r));
    final minus = sum((r) => n(r['absent_ded']) + n(r['late_ded']) + n(r['unpaid_ded']));
    final plus = sum((r) => n(r['ot_pay']) + n(r['extra_pay']));
    final adj = sum((r) => n(r['adj_total']));
    final noSalary = rows.where((r) => n(r['salary']) == 0).length;
    final kh = obj(d?['kh']);
    final thisMonth = todayKH().substring(0, 7);
    String m(num v) => money(v, cur);

    Widget kpi(String label, String value, {Color? color}) => Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: c.muted, fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color),
          ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        atPanel([
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _month = shiftMonth(_month, -1);
                    _data = null;
                  });
                  _load();
                },
                icon: const Icon(LucideIcons.chevronLeft),
              ),
              Expanded(
                child: Text(
                  ghMonth(_month, ctx.lang),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              IconButton(
                onPressed: _month.compareTo(thisMonth) >= 0
                    ? null
                    : () {
                        setState(() {
                          _month = shiftMonth(_month, 1);
                          _data = null;
                        });
                        _load();
                      },
                icon: const Icon(LucideIcons.chevronRight),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Btn(x('rules'), icon: LucideIcons.settings2, kind: _rules ? BtnKind.primary : BtnKind.ghost, small: true, onTap: () => setState(() => _rules = !_rules)),
              Btn(x('bankCsv'), icon: LucideIcons.landmark, kind: BtnKind.ghost, small: true, onTap: rows.isEmpty || _exporting ? null : () => _export('bank')),
              Btn(x('exportCsv'), icon: LucideIcons.download, small: true, busy: _exporting, onTap: rows.isEmpty || _exporting ? null : () => _export('csv')),
            ],
          ),
          if (d != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          x('totalPay'),
                          style: TextStyle(color: c.brandInk, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          m(n(d['total'])),
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: c.brandInk),
                        ),
                      ],
                    ),
                  ),
                  Chip2(x('staffCount', {'n': rows.length})),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  kpi(x('col.base'), m(sum((r) => n(r['base'])))),
                  const SizedBox(width: 8),
                  kpi(x('col.minus'), minus != 0 ? '−${m(minus)}' : '—', color: minus != 0 ? c.danger : null),
                  const SizedBox(width: 8),
                  kpi(x('col.plus'), plus != 0 ? '+${m(plus)}' : '—', color: plus != 0 ? c.good : null),
                  const SizedBox(width: 8),
                  kpi(
                    x('col.adj'),
                    adj != 0 ? '${adj > 0 ? '+' : '−'}${m(adj.abs())}' : '—',
                    color: adj < 0
                        ? c.danger
                        : adj > 0
                        ? c.good
                        : null,
                  ),
                  if (kh['on'] == true) ...[
                    const SizedBox(width: 8),
                    kpi(x('kTax'), n(kh['tax']) != 0 ? '−${m(n(kh['tax']))}' : '—', color: c.danger),
                    const SizedBox(width: 8),
                    kpi(x('kNssfStaff'), n(kh['nssf_staff']) != 0 ? '−${m(n(kh['nssf_staff']))}' : '—', color: c.danger),
                    const SizedBox(width: 8),
                    kpi(x('kNssfEmployer'), m(n(kh['nssf_employer']))),
                  ],
                ],
              ),
            ),
          ],
          if (_rules && d != null) ..._rulesBox(context, st, cur),
        ]),
        if (noSalary > 0) ...[
          mGap,
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.warnBg, borderRadius: BorderRadius.circular(14)),
            child: Text(
              x('noSalaryHint', {'n': noSalary}),
              style: TextStyle(color: c.warn, fontWeight: FontWeight.w700),
            ),
          ),
        ],
        mGap,
        if (d == null) const SkelList(rows: 4) else if (rows.isEmpty) atPanel([Muted(x('noStaffPay'), align: TextAlign.center)]) else for (final r in rows) ...[_card(context, r, cur), mGap],
      ],
    );
  }

  List<Widget> _rulesBox(BuildContext context, Json st, String cur) {
    final c = context.c;
    final ro = ctx.readOnly;
    final khOn = ctx.addonOn('att_khpay');
    final khSet = obj(st['kh']);
    Widget pick(String label, num value, List<num> list, String post, ValueChanged<num> on) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          DropdownButton<num>(
            value: list.contains(value) ? value : list.first,
            onChanged: ro ? null : (v) => v == null ? null : on(v),
            items: [for (final v in list) DropdownMenuItem(value: v, child: Text('$v×'))],
          ),
          const SizedBox(width: 6),
          Text(post, style: TextStyle(color: c.muted, fontSize: 12.5)),
        ],
      ),
    );
    return [
      const Divider(height: 28),
      Muted(x('paySub')),
      const SizedBox(height: 12),
      Text(x('currency'), style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 7),
      Segmented<String>(value: cur, options: const [('USD', 'USD \$'), ('KHR', 'KHR ៛')], onChanged: (v) => ro ? null : _set({'currency': v})),
      gap14,
      pick(x('otRate'), n(st['ot_rate'] ?? 1.5), const [1, 1.25, 1.5, 2, 2.5, 3], x('timesHour'), (v) => _set({'ot_rate': v})),
      pick(x('holidayRate'), n(st['holiday_rate'] ?? 2), const [1, 1.5, 2, 2.5, 3], x('timesDay'), (v) => _set({'holiday_rate': v})),
      SwitchRow(title: x('showStaff'), value: st['show_staff'] != false, onChanged: ro ? null : (v) => _set({'show_staff': v})),
      SwitchRow(title: x('otApproval'), value: st['ot_approval'] == true, onChanged: ro ? null : (v) => _set({'ot_approval': v})),
      SwitchRow(title: x('deductAbsent'), value: st['deduct_absent'] != false, onChanged: ro ? null : (v) => _set({'deduct_absent': v})),
      SwitchRow(title: x('deductLate'), value: st['deduct_late'] != false, onChanged: ro ? null : (v) => _set({'deduct_late': v})),
      SwitchRow(title: x('payExtra'), value: st['pay_extra_days'] != false, onChanged: ro ? null : (v) => _set({'pay_extra_days': v})),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(LucideIcons.landmark, size: 17, color: c.brand),
                const SizedBox(width: 8),
                Text(x('khTitle'), style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 6),
            Muted(x('khSub')),
            const SizedBox(height: 10),
            if (!khOn)
              Align(
                alignment: Alignment.centerLeft,
                child: GoldBtn(x('khUnlock', {'coins': fmt(n(ctx.addon('att_khpay')['price'] ?? 80))}), onTap: ro ? null : () => ctx.askBuy('att_khpay')),
              )
            else ...[
              for (final k in ['tax', 'nssf', 'seniority'])
                SwitchRow(
                  title: x('kh${k[0].toUpperCase()}${k.substring(1)}'),
                  value: khSet[k] != false,
                  onChanged: ro
                      ? null
                      : (v) => _set({
                          'kh': {k: v},
                        }),
                ),
              const SizedBox(height: 6),
              for (final (k, label, post, def) in [
                ('khr_rate', x('khRate'), x('khPerUsd'), 4100),
                ('pension_ee', x('khPensionEe'), '', 2),
                ('pension_er', x('khPensionEr'), '', 2),
                ('risk_er', x('khRisk'), '', 0.8),
                ('health_er', x('khHealth'), '', 2.6),
              ])
                _RateRow(
                  label: label,
                  post: post,
                  value: n(khSet[k] ?? def),
                  enabled: !ro,
                  onSave: (v) => _set({
                    'kh': {k: v},
                  }),
                ),
              Muted(x('khNote')),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _card(BuildContext context, Json r, String cur) {
    final c = context.c;
    final staff = obj(r['staff']);
    final shift = obj(r['shift']);
    final minus = n(r['absent_ded']) + n(r['late_ded']) + n(r['unpaid_ded']);
    final plus = n(r['ot_pay']) + n(r['extra_pay']) + n(r['paid_leave_pay']);
    final adj = n(r['adj_total']);
    final kh = r['kh'] is Map ? obj(r['kh']) : null;
    String m(num v) => money(v, cur);
    final facts = [
      n(r['work_days']) > 0 ? x('fWorkDays', {'p': n(r['present']), 'd': n(r['work_days'])}) : x('fNoShift'),
      if (n(r['absent_days']) > 0) x('fAbsent', {'n': n(r['absent_days'])}),
      if (n(r['late_min']) > 0) x('fLate', {'t': _hm(r['late_min'])}),
      if (n(r['ot_min']) > 0) x('fOt', {'t': _hm(r['ot_min'])}),
      if (n(r['paid_leave_days']) + n(r['unpaid_days']) > 0) x('fLeave', {'n': n(r['paid_leave_days']) + n(r['unpaid_days'])}),
    ];
    Widget cell(String label, String v, [Color? color]) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.muted, fontSize: 11.5),
          ),
          Text(
            v,
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
    final ro = ctx.readOnly;
    return Opacity(
      opacity: n(r['salary']) == 0 ? .75 : 1,
      child: atPanel(padding: const EdgeInsets.all(14), [
        Row(
          children: [
            AtAvatar(staff['name'], color: str(shift['color']), size: 42),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(str(staff['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                  Muted([str(staff['position']), if (shift.isNotEmpty) '${str(shift['start'])}–${str(shift['end'])}'].where((s) => s.isNotEmpty).join(' · ').ifEmpty('—')),
                ],
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: ro ? null : () => _salary(r),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: n(r['salary']) == 0 ? c.warnBg : c.bg2, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      n(r['salary']) == 0 ? x('noSalary') : '${m(n(r['salary']))}${x('per.${str(r['pay_type']).isEmpty ? 'monthly' : r['pay_type']}')}',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: n(r['salary']) == 0 ? c.warn : c.ink),
                    ),
                    const SizedBox(width: 4),
                    Icon(LucideIcons.pencil, size: 13, color: c.muted),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            cell(x('col.base'), m(n(r['base']))),
            cell(x('col.minus'), minus != 0 ? '−${m(minus)}' : '—', minus != 0 ? c.danger : null),
            cell(x('col.plus'), plus != 0 ? '+${m(plus)}' : '—', plus != 0 ? c.good : null),
            cell(
              x('col.adj'),
              adj != 0 ? '${adj > 0 ? '+' : '−'}${m(adj.abs())}' : '—',
              adj < 0
                  ? c.danger
                  : adj > 0
                  ? c.good
                  : null,
            ),
          ],
        ),
        const Divider(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(x('col.net'), style: TextStyle(color: c.muted, fontSize: 12)),
                  Text(m(n(r['net'])), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                  if (kh != null)
                    Muted(
                      [
                        '${x('kGross')} ${m(n(kh['gross']))}',
                        if (n(kh['seniority']) > 0) '${x('kSeniority')} +${m(n(kh['seniority']))}',
                        if (n(kh['pension_ee']) > 0) 'NSSF −${m(n(kh['pension_ee']))}',
                        if (n(kh['tax']) > 0) '${x('kTax')} −${m(n(kh['tax']))}',
                      ].join(' · '),
                    ),
                ],
              ),
            ),
            Btn(
              x('payslip'),
              icon: LucideIcons.fileText,
              kind: BtnKind.ghost,
              small: true,
              onTap: () => showSheet<void>(context, (_) => _Payslip(ctx: ctx, month: _month, row: r, cur: cur, onChanged: _load)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (n(r['reward']) > 0) AtTag('+${m(n(r['reward']))} 🏆 ${ctx.lang == 'km' ? 'ខែល្អឥតខ្ចោះ' : 'Perfect month'}', tone: 'ok'),
            for (final a in objs(r['adjustments']))
              InputChip(
                label: Text('${n(a['amount']) < 0 ? '−' : '+'}${m(n(a['amount']).abs())} ${str(a['label'])}'),
                labelStyle: TextStyle(color: n(a['amount']) < 0 ? c.danger : c.good, fontWeight: FontWeight.w700, fontSize: 12),
                onDeleted: ro
                    ? null
                    : () async {
                        if (await ctx.run(() => ctx.api.delete('${ctx.base}/payroll/adjust/${a['_id']}')) != null) _load();
                      },
              ),
            if (!ro) ...[
              ActionChip(
                avatar: Icon(LucideIcons.plus, size: 14, color: c.good),
                label: Text(
                  x('addBonus'),
                  style: TextStyle(color: c.good, fontWeight: FontWeight.w700),
                ),
                onPressed: () => showSheet<bool>(context, (_) => _AdjustSheet(ctx: ctx, month: _month, cur: cur, row: r, deduct: false)).then((ok) => ok == true ? _load() : null),
              ),
              ActionChip(
                avatar: Icon(LucideIcons.minus, size: 14, color: c.danger),
                label: Text(
                  x('addDeduct'),
                  style: TextStyle(color: c.danger, fontWeight: FontWeight.w700),
                ),
                onPressed: () => showSheet<bool>(context, (_) => _AdjustSheet(ctx: ctx, month: _month, cur: cur, row: r, deduct: true)).then((ok) => ok == true ? _load() : null),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [for (final f in facts) AtTag(f)]),
      ]),
    );
  }
}

extension on String {
  String ifEmpty(String v) => isEmpty ? v : this;
}

class _RateRow extends StatefulWidget {
  final String label, post;
  final num value;
  final bool enabled;
  final ValueChanged<num> onSave;
  const _RateRow({required this.label, required this.post, required this.value, required this.enabled, required this.onSave});
  @override
  State<_RateRow> createState() => _RateRowState();
}

class _RateRowState extends State<_RateRow> {
  late final _c = TextEditingController(text: '${widget.value}'.replaceFirst(RegExp(r'\.0$'), ''));
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final changed = numOf(_c.text) != null && numOf(_c.text) != widget.value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(widget.label)),
          SizedBox(
            width: 84,
            child: Field(controller: _c, keyboard: decimalKeys, align: TextAlign.center, enabled: widget.enabled, onChanged: (_) => setState(() {})),
          ),
          if (widget.post.isNotEmpty) ...[const SizedBox(width: 6), Muted(widget.post)],
          if (changed) IconButton(onPressed: () => widget.onSave(numOf(_c.text)!), icon: const Icon(LucideIcons.check, size: 18)),
        ],
      ),
    );
  }
}

// a bonus (+) or a deduction (−) with its reason
class _AdjustSheet extends StatefulWidget {
  final AtCtx ctx;
  final String month, cur;
  final Json row;
  final bool deduct;
  const _AdjustSheet({required this.ctx, required this.month, required this.cur, required this.row, required this.deduct});
  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> with AtSave {
  AtCtx get ctx => widget.ctx;
  @override
  AtCtx get actx => ctx;
  final _amount = TextEditingController(), _label = TextEditingController();
  String x(String k, [Map<String, Object?> v = const {}]) => ctx.t('atx.$k', v);

  @override
  void dispose() {
    _amount.dispose();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = widget.deduct;
    final presets = ctx.t.list(d ? 'atx.deductPresets' : 'atx.bonusPresets');
    final amt = (numOf(_amount.text) ?? 0).abs();
    return MSheet(
      title: '${d ? x('deductTitle') : x('bonusTitle')} · ${str(obj(widget.row['staff'])['name'])}',
      footer: [
        const Spacer(),
        Btn(x('cancel'), kind: BtnKind.ghost, small: true, onTap: busy ? null : () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(
          busy ? x('saving') : (d ? x('addDeduct') : x('addBonus')),
          kind: d ? BtnKind.danger : BtnKind.primary,
          small: true,
          busy: busy,
          onTap: busy || amt == 0 || _label.text.trim().isEmpty
              ? null
              : () => save(
                  () => ctx.api.post('${ctx.base}/payroll/adjust', {'staff_id': obj(widget.row['staff'])['_id'], 'month': widget.month, 'label': _label.text.trim(), 'amount': d ? -amt : amt}),
                  reload: false,
                  ok: x('saved'),
                ),
        ),
      ],
      children: [
        Field(
          label: '${x('amount')} (${widget.cur == 'KHR' ? '៛' : '\$'})',
          controller: _amount,
          keyboard: decimalKeys,
          autofocus: true,
          prefix: Padding(
            padding: const EdgeInsets.only(left: 12, right: 4),
            child: Text(
              d ? '−' : '+',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: d ? c.danger : c.good),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        gap14,
        Field(label: x('reason'), controller: _label, hint: d ? x('deductPh') : x('bonusPh'), maxLength: 60, onChanged: (_) => setState(() {})),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final p in presets) ChoiceChip(label: Text(p), selected: _label.text == p, onSelected: (_) => setState(() => _label.text = p))],
        ),
        gap14,
        Muted(x('adjNote', {'month': ghMonth(widget.month, ctx.lang)})),
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}

// payslip: the lines, share as a picture
class _Payslip extends StatelessWidget {
  final AtCtx ctx;
  final String month, cur;
  final Json row;
  final Future<void> Function() onChanged;
  const _Payslip({required this.ctx, required this.month, required this.row, required this.cur, required this.onChanged});
  String x(String k, [Map<String, Object?> v = const {}]) => ctx.t('atx.$k', v);

  @override
  Widget build(BuildContext context) {
    final r = row;
    final staff = obj(r['staff']);
    final kh = r['kh'] is Map ? obj(r['kh']) : const <String, dynamic>{};
    String br(String k, Object? v) => x('br.$k', {'n': n(v), 't': _hm(v)});
    final lines = <(String, num)>[
      (x('br.base'), n(r['base'])),
      if (n(r['absent_ded']) != 0) (br('absent', r['absent_days']), -n(r['absent_ded'])),
      if (n(r['late_ded']) != 0) (br('late', r['late_min']), -n(r['late_ded'])),
      if (n(r['unpaid_ded']) != 0) (br('unpaid', r['unpaid_days']), -n(r['unpaid_ded'])),
      if (n(r['ot_pay']) != 0) (br('ot', r['ot_min']), n(r['ot_pay'])),
      if (n(r['extra_pay']) != 0) (br('extra', r['extra_days']), n(r['extra_pay'])),
      for (final a in objs(r['adjustments'])) (str(a['label']), n(a['amount'])),
      if (n(r['reward']) != 0) ('🏆 ${ctx.lang == 'km' ? 'ប្រាក់រង្វាន់ខែល្អឥតខ្ចោះ' : 'Perfect month bonus'}', n(r['reward'])),
      if (n(r['paid_leave_pay']) != 0) (x('br.paidLeave', {'n': n(r['paid_leave_days'])}), n(r['paid_leave_pay'])),
      if (n(kh['seniority']) != 0) (x('kSeniority'), n(kh['seniority'])),
      if (n(kh['pension_ee']) != 0) ('NSSF', -n(kh['pension_ee'])),
      if (n(kh['tax']) != 0) (x('kTax'), -n(kh['tax'])),
    ];
    final key = GlobalKey();
    const ink = Color(0xFF111111), grey = Color(0xFF666666);
    return MSheet(
      title: x('payslip'),
      footer: [
        const Spacer(),
        Btn(x('cancel'), kind: BtnKind.ghost, small: true, onTap: () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(x('print'), icon: LucideIcons.share2, small: true, onTap: () => shareWidgets([key], (_) => 'payslip-${str(staff['name']).replaceAll(' ', '-')}-$month.png')),
      ],
      children: [
        RepaintBoundary(
          key: key,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: DefaultTextStyle(
              style: const TextStyle(color: ink, fontSize: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(str(ctx.business['name']), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                  Text('${x('payslip')} · ${ghMonth(month, ctx.lang)}', style: const TextStyle(color: grey)),
                  const SizedBox(height: 12),
                  Text('${str(staff['name'])}${str(staff['position']).isNotEmpty ? ' · ${staff['position']}' : ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(x('br.daily', {'v': money(n(r['daily_rate']), cur), 'h': money(n(r['hourly_rate']), cur), 'd': n(r['work_days'])}), style: const TextStyle(color: grey, fontSize: 12)),
                  if (n(r['paid_leave_days']) > 0) Text(x('br.paidLeave', {'n': n(r['paid_leave_days'])}), style: const TextStyle(color: grey, fontSize: 12)),
                  const SizedBox(height: 10),
                  for (final (i, (label, v)) in lines.indexed)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFDDDDDD))),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(label)),
                          Text(
                            '${v < 0 ? '−' : (i > 0 ? '+' : '')}${money(v.abs(), cur)}',
                            style: TextStyle(color: v < 0 ? const Color(0xFFB91C1C) : ink, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: ink, width: 2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(x('br.net'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                        ),
                        Text(money(n(r['net']), cur), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
