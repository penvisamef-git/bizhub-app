import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'rest_common.dart';
import 'rest_reports.dart' show dayLabel, localToday;

// Promotions (the web's PromotionsTab.jsx): % off, $ off, buy X get Y on chosen items, with dates / days / hours.

extension on RestCtx {
  String pm(String key, [Map<String, Object?> vars = const {}]) => t('promo.$key', vars);
}

// is a promotion on right now? (promoOn on the web — Cambodia time; "22:00–02:00" works too)
bool promoOn(Json p, DateTime at) {
  final local = at.toUtc().add(const Duration(hours: 7));
  final iso = local.toIso8601String();
  final day = iso.substring(0, 10), hm = iso.substring(11, 16);
  final start = str(p['start_date']), end = str(p['end_date']);
  if (start.isNotEmpty && day.compareTo(start) < 0) return false;
  if (end.isNotEmpty && day.compareTo(end) > 0) return false;
  final days = (p['days'] as List?)?.map((e) => n(e).toInt()).toList() ?? const <int>[];
  if (days.isNotEmpty && !days.contains(local.weekday % 7)) return false;
  final from = str(p['from']), to = str(p['to']);
  if (from.isNotEmpty && to.isNotEmpty) {
    final off = from.compareTo(to) <= 0 ? (hm.compareTo(from) < 0 || hm.compareTo(to) >= 0) : (hm.compareTo(from) < 0 && hm.compareTo(to) >= 0);
    if (off) return false;
  }
  return true;
}

// on / later / ended / off / waiting (right dates, outside its hours)
String promoStatus(Json p) {
  if (p['active'] != true) return 'off';
  final today = localToday();
  final start = str(p['start_date']), end = str(p['end_date']);
  if (end.isNotEmpty && today.compareTo(end) > 0) return 'ended';
  if (start.isNotEmpty && today.compareTo(start) < 0) return 'later';
  return promoOn(p, DateTime.now()) ? 'on' : 'waiting';
}

class PromosSection extends StatefulWidget {
  final RestCtx ctx;
  const PromosSection({super.key, required this.ctx});
  @override
  State<PromosSection> createState() => _PromosSectionState();
}

class _PromosSectionState extends State<PromosSection> {
  List<Json>? _promos;
  List<Json> _items = [], _cats = [];
  RestCtx get ctx => widget.ctx;
  bool get _active => ctx.addonOn('rest_promos');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([
        if (_active) ctx.api.get('${ctx.base}/promos') else Future.value(<String, dynamic>{'data': []}),
        ctx.api.get('${ctx.base}/items'),
        ctx.api.get('${ctx.base}/categories'),
      ]);
      if (!mounted) return;
      setState(() {
        _promos = objs(r[0]['data']);
        _items = objs(r[1]['data']);
        _cats = objs(r[2]['data']);
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  String _summary(Json x) {
    if (x['kind'] == 'percent') return ctx.pm('sumPercent', {'v': _num(x['value'])});
    if (x['kind'] == 'amount') return ctx.pm('sumAmount', {'v': fmtMoney(n(x['value']), ctx.currency)});
    return ctx.pm(n(x['get_percent']) >= 100 ? 'sumBxgy' : 'sumBxgyPct', {'b': _num(x['buy']), 'g': _num(x['get_qty']), 'p': _num(x['get_percent'])});
  }

  String _applies(Json x) {
    if (x['all_items'] == true) return ctx.pm('allItems');
    final cats = ((x['category_ids'] as List?) ?? const []).map((id) => nameOf(_cats.firstWhere((c) => str(c['_id']) == '$id', orElse: () => {}), ctx.lang));
    final count = ((x['item_ids'] as List?) ?? const []).length;
    return [
      ...cats,
      if (count > 0) ctx.pm('itemsN', {'n': count}),
    ].join(', ');
  }

  String _when(Json x) {
    final s = str(x['start_date']), e = str(x['end_date']);
    final dates = s.isNotEmpty || e.isNotEmpty ? '${s.isNotEmpty ? dayLabel(s, ctx.lang) : ''}${e.isNotEmpty ? ' – ${dayLabel(e, ctx.lang)}' : (s.isNotEmpty ? ' · ${ctx.pm('noEnd')}' : '')}' : '';
    final names = ctx.t.list('promo.dayNames');
    final d = ((x['days'] as List?) ?? const []).map((v) => n(v).toInt()).toList();
    final days = d.isNotEmpty && d.length < 7 ? d.map((i) => i < names.length ? names[i] : '$i').join(' ') : ctx.pm('everyDay');
    final hours = str(x['from']).isNotEmpty && str(x['to']).isNotEmpty ? '${x['from']}–${x['to']}' : ctx.pm('allDay');
    return [dates, days, hours].where((v) => v.isNotEmpty).join(' · ');
  }

  Json _idea(String kind) {
    final base = <String, dynamic>{
      'name': '',
      'kind': 'percent',
      'value': 20,
      'buy': 1,
      'get_qty': 1,
      'get_percent': 100,
      'all_items': true,
      'item_ids': <String>[],
      'category_ids': <String>[],
      'start_date': '',
      'end_date': '',
      'days': <int>[],
      'from': '',
      'to': '',
      'active': true,
    };
    return switch (kind) {
      'blank' => {...base, 'value': 10},
      'happy' => {
        ...base,
        'name': ctx.pm('ideaHappy'),
        'from': '14:00',
        'to': '17:00',
        'days': [1, 2, 3, 4, 5],
      },
      'b1g1' => {...base, 'name': ctx.pm('ideaB1G1'), 'kind': 'bxgy', 'all_items': false},
      'amount' => {...base, 'name': ctx.pm('ideaAmount'), 'kind': 'amount', 'value': ctx.currency == 'KHR' ? 2000 : 0.5, 'all_items': false},
      _ => {...base, 'name': ctx.pm('ideaSecondHalf'), 'kind': 'bxgy', 'get_percent': 50, 'all_items': false},
    };
  }

  Future<void> _toggle(Json x) async {
    setState(() => x['active'] = x['active'] != true);
    try {
      await ctx.api.put('${ctx.base}/promos/${x['_id']}', {'active': x['active']});
    } catch (e) {
      ctx.fail(e);
      _load();
    }
  }

  Future<void> _edit(Json row) async {
    final saved = await showEditor<bool>(
      context,
      builder: (_) => _PromoEditor(ctx: ctx, row: row, items: _items, cats: _cats),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final promos = _promos;
    if (promos == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 4));
    final ro = ctx.readOnly;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Panel(
            child: RestHead(
              ctx.pm('title'),
              sub: ctx.pm('sub'),
              trailing: _active ? Btn(ctx.pm('add'), icon: LucideIcons.plus, small: true, onTap: ro ? null : () => _edit(_idea('blank'))) : null,
            ),
          ),
          gap14,
          if (!_active)
            AddonPrompt(ctx: ctx, addonKey: 'rest_promos')
          else ...[
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(ctx.pm('ideas'), style: Theme.of(context).textTheme.titleMedium),
                  if (promos.isEmpty) ...[const SizedBox(height: 4), Muted(ctx.pm('none'))],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (k, icon) in [('happy', LucideIcons.clock3), ('b1g1', LucideIcons.gift), ('half', LucideIcons.gift), ('amount', LucideIcons.tag)])
                        Btn(
                          ctx.pm(switch (k) {
                            'happy' => 'ideaHappy',
                            'b1g1' => 'ideaB1G1',
                            'half' => 'ideaSecondHalf',
                            _ => 'ideaAmount',
                          }),
                          icon: icon,
                          kind: BtnKind.ghost,
                          small: true,
                          onTap: ro ? null : () => _edit(_idea(k)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            for (final x in promos) ...[gap14, _card(x, c, ro)],
            const SizedBox(height: 16),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Muted(ctx.pm('rules'))),
          ],
        ],
      ),
    );
  }

  Widget _card(Json x, C c, bool ro) {
    final st = promoStatus(x);
    final tone = switch (st) {
      'on' => Tone.good,
      'later' => Tone.brand,
      'waiting' => Tone.warn,
      _ => Tone.muted,
    };
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      onTap: ro ? null : () => _edit(x),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: st == 'on' ? c.goodBg : c.bg2, borderRadius: BorderRadius.circular(13)),
            child: Icon(x['kind'] == 'bxgy' ? LucideIcons.gift : LucideIcons.badgePercent, size: 20, color: st == 'on' ? c.good : c.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(str(x['name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Chip2(ctx.pm('status.$st'), tone: tone),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _summary(x),
                  style: TextStyle(fontWeight: FontWeight.w700, color: c.brandInk),
                ),
                const SizedBox(height: 4),
                _line(LucideIcons.tag, _applies(x), c),
                _line(LucideIcons.calendarDays, _when(x), c),
              ],
            ),
          ),
          Switch.adaptive(value: x['active'] == true, onChanged: ro ? null : (_) => _toggle(x)),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text, C c) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 12, color: c.muted),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(text, style: TextStyle(color: c.muted, fontSize: 12.5)),
        ),
      ],
    ),
  );
}

String _num(Object? v) {
  final x = n(v);
  return x == x.roundToDouble() ? '${x.toInt()}' : '$x';
}

class _PromoEditor extends StatefulWidget {
  final RestCtx ctx;
  final Json row;
  final List<Json> items, cats;
  const _PromoEditor({required this.ctx, required this.row, required this.items, required this.cats});
  @override
  State<_PromoEditor> createState() => _PromoEditorState();
}

class _PromoEditorState extends State<_PromoEditor> {
  late final Json row = widget.row;
  late final _name = TextEditingController(text: str(row['name']));
  late final _value = TextEditingController(text: _num(row['value'] ?? 20));
  late final _buy = TextEditingController(text: _num(row['buy'] ?? 1));
  late final _get = TextEditingController(text: _num(row['get_qty'] ?? 1));
  final _q = TextEditingController();
  late String _kind = str(row['kind']).isEmpty ? 'percent' : str(row['kind']);
  late num _getPct = row['get_percent'] == null ? 100 : n(row['get_percent']);
  late bool _all = row['all_items'] == true, _on = row['active'] != false;
  late final Set<String> _itemIds = {...((row['item_ids'] as List?) ?? const []).map((e) => '$e')};
  late final Set<String> _catIds = {...((row['category_ids'] as List?) ?? const []).map((e) => '$e')};
  late String _start = str(row['start_date']), _end = str(row['end_date']), _from = str(row['from']), _to = str(row['to']);
  late final List<int> _days = [...((row['days'] as List?) ?? const []).map((e) => n(e).toInt())];
  bool _busy = false;
  String _error = '';
  RestCtx get ctx => widget.ctx;

  @override
  void dispose() {
    for (final x in [_name, _value, _buy, _get, _q]) {
      x.dispose();
    }
    super.dispose();
  }

  bool get _can =>
      _name.text.trim().isNotEmpty && (_all || _itemIds.isNotEmpty || _catIds.isNotEmpty) && (_kind == 'bxgy' || (num.tryParse(_value.text.trim()) ?? 0) > 0) && _from.isEmpty == _to.isEmpty;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    final body = {
      'name': _name.text.trim(),
      'kind': _kind,
      'value': num.tryParse(_value.text.trim()) ?? 0,
      'buy': int.tryParse(_buy.text.trim()) ?? 1,
      'get_qty': int.tryParse(_get.text.trim()) ?? 1,
      'get_percent': _getPct,
      'all_items': _all,
      'item_ids': _itemIds.toList(),
      'category_ids': _catIds.toList(),
      'start_date': _start,
      'end_date': _end,
      'days': _days,
      'from': _from,
      'to': _to,
      'active': _on,
    };
    try {
      if (row['_id'] != null) {
        await ctx.api.put('${ctx.base}/promos/${row['_id']}', body);
      } else {
        await ctx.api.post('${ctx.base}/promos', body);
      }
      ctx.notify(ctx.r('saved'));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (e is ApiError && e.status == 402) ctx.askBuy('rest_promos');
      if (mounted) setState(() => _error = e is ApiError ? e.message : '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await ctx.api.delete('${ctx.base}/promos/${row['_id']}');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiError ? e.message : '$e';
          _busy = false;
        });
      }
    }
  }

  Future<void> _pickDate(bool start) async {
    final cur = start ? _start : _end;
    final first = DateTime(2024);
    final init = DateTime.tryParse(cur) ?? DateTime.tryParse(start ? '' : _start) ?? DateTime.parse(localToday());
    final d = await showDatePicker(context: context, firstDate: first, lastDate: DateTime(2035), initialDate: init.isBefore(first) ? first : init);
    if (d == null) return;
    final v = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    setState(() => start ? _start = v : _end = v);
  }

  Future<void> _pickTime(bool from) async {
    final cur = from ? _from : _to;
    final parts = cur.split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: parts.length == 2 ? TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])) : TimeOfDay(hour: from ? 14 : 17, minute: 0),
      builder: (ctx2, child) => MediaQuery(data: MediaQuery.of(ctx2).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (t == null) return;
    final v = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() => from ? _from = v : _to = v);
  }

  Widget _label(String text, [String? hint]) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2, top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
        if (hint != null) ...[const SizedBox(height: 2), Muted(hint)],
      ],
    ),
  );

  Widget _pickBox(String label, String value, VoidCallback onTap, {VoidCallback? onClear}) {
    final c = context.c;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: c.muted, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            if (value.isNotEmpty && onClear != null)
              IconButton(
                onPressed: onClear,
                icon: Icon(LucideIcons.x, size: 16, color: c.muted),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cur = ctx.currency;
    final qq = _q.text.trim().toLowerCase();
    final items = widget.items.where((i) => qq.isEmpty || '${str(i['name_en'])} ${str(i['name_km'])}'.toLowerCase().contains(qq)).toList();
    final dayNames = ctx.t.list('promo.dayNames');
    Widget numBox(TextEditingController ctrl, String label) => SizedBox(
      width: 64,
      child: Field(controller: ctrl, keyboard: TextInputType.number, align: TextAlign.center, onChanged: (_) => setState(() {}), hint: label),
    );
    return EditorFrame(
      title: row['_id'] != null ? ctx.pm('edit') : ctx.pm('add'),
      cancel: ctx.r('cancel'),
      save: ctx.r('save'),
      busy: _busy,
      canSave: _can,
      onSave: _save,
      delete: row['_id'] != null ? DeleteConfirm(ctx: ctx, onDelete: _busy ? null : _remove) : null,
      children: [
        Field(label: ctx.pm('name'), hint: ctx.pm('namePh'), controller: _name, maxLength: 60, onChanged: (_) => setState(() {})),
        _label(ctx.pm('type')),
        Segmented<String>(
          value: _kind,
          options: [
            for (final k in ['percent', 'amount', 'bxgy']) (k, ctx.pm('kinds.$k')),
          ],
          onChanged: (v) => setState(() => _kind = v),
        ),
        if (_kind == 'percent') ...[
          gap14,
          Field(
            label: ctx.pm('percent'),
            controller: _value,
            keyboard: TextInputType.number,
            onChanged: (_) => setState(() {}),
            suffix: const Padding(padding: EdgeInsets.all(14), child: Text('%')),
          ),
        ],
        if (_kind == 'amount') ...[
          gap14,
          Field(label: ctx.pm('amountEach', {'c': cur}), controller: _value, keyboard: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {})),
        ],
        if (_kind == 'bxgy') ...[
          _label(ctx.pm('kinds.bxgy'), ctx.pm('bxgyHint')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(ctx.pm('buy'), style: const TextStyle(fontWeight: FontWeight.w700)),
              numBox(_buy, ctx.pm('buy')),
              Text(ctx.pm('get'), style: const TextStyle(fontWeight: FontWeight.w700)),
              numBox(_get, ctx.pm('get')),
              Text(ctx.pm('getAt'), style: const TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(
                width: 150,
                child: SelectField<num>(
                  value: _getPct,
                  options: [
                    (100, ctx.pm('getFree')),
                    for (final v in [75, 50, 30, 20, 10]) (v, '$v%'),
                  ],
                  onChanged: (v) => setState(() => _getPct = v),
                ),
              ),
            ],
          ),
        ],
        _label(ctx.pm('appliesTo')),
        Segmented<bool>(value: _all, options: [(true, ctx.pm('allItems')), (false, ctx.pm('chooseItems'))], onChanged: (v) => setState(() => _all = v)),
        if (!_all) ...[
          const SizedBox(height: 12),
          Muted(ctx.pm('categories')),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final cc in widget.cats)
                FilterChip(
                  avatar: CircleAvatar(radius: 5, backgroundColor: _hex(str(cc['color'])) ?? c.muted),
                  label: Text(nameOf(cc, ctx.lang)),
                  selected: _catIds.contains(str(cc['_id'])),
                  showCheckmark: false,
                  onSelected: (on) => setState(() => on ? _catIds.add(str(cc['_id'])) : _catIds.remove(str(cc['_id']))),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Muted(ctx.pm('items')),
          const SizedBox(height: 6),
          Field(controller: _q, hint: ctx.pm('searchItems'), icon: LucideIcons.search, onChanged: (_) => setState(() {})),
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              border: Border.all(color: c.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final i in items)
                  CheckboxListTile(
                    dense: true,
                    value: _itemIds.contains(str(i['_id'])),
                    onChanged: (on) => setState(() => on == true ? _itemIds.add(str(i['_id'])) : _itemIds.remove(str(i['_id']))),
                    title: Text(nameOf(i, ctx.lang), style: const TextStyle(fontWeight: FontWeight.w600)),
                    secondary: Text(fmtMoney(n(i['price']), cur), style: TextStyle(color: c.muted, fontSize: 12.5)),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
              ],
            ),
          ),
        ],
        _label(ctx.pm('when')),
        Row(
          children: [
            Expanded(child: _pickBox(ctx.pm('startDate'), _start.isEmpty ? '' : dayLabel(_start, ctx.lang), () => _pickDate(true), onClear: () => setState(() => _start = ''))),
            const SizedBox(width: 10),
            Expanded(child: _pickBox(ctx.pm('endDate'), _end.isEmpty ? '' : dayLabel(_end, ctx.lang), () => _pickDate(false), onClear: () => setState(() => _end = ''))),
          ],
        ),
        _label(ctx.pm('days')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < dayNames.length; i++)
              FilterChip(
                label: Text(dayNames[i]),
                selected: _days.contains(i),
                showCheckmark: false,
                onSelected: (on) => setState(() {
                  on ? _days.add(i) : _days.remove(i);
                  _days.sort();
                }),
              ),
            if (_days.isNotEmpty) ActionChip(label: Text(ctx.pm('everyDay')), onPressed: () => setState(_days.clear)),
          ],
        ),
        _label(ctx.pm('hours'), ctx.pm('hoursHint')),
        Row(
          children: [
            Expanded(child: _pickBox(ctx.pm('fromTime'), _from, () => _pickTime(true), onClear: () => setState(() => _from = ''))),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('→')),
            Expanded(child: _pickBox(ctx.pm('toTime'), _to, () => _pickTime(false), onClear: () => setState(() => _to = ''))),
          ],
        ),
        const SizedBox(height: 8),
        SwitchRow(title: ctx.pm('active'), value: _on, onChanged: (v) => setState(() => _on = v)),
        if (_error.isNotEmpty) ...[gap14, Alert(_error)],
      ],
    );
  }
}

Color? _hex(String h) {
  final v = int.tryParse(h.replaceFirst('#', ''), radix: 16);
  return h.isEmpty || v == null ? null : Color(0xFF000000 | v);
}
