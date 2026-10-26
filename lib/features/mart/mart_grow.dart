import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../restaurant/rest_common.dart' show Segmented, SwitchRow, gap14;
import 'mart_common.dart';
import 'mart_kit.dart';

// Promotions (mart_promos) + Loyalty points (mart_loyalty) — the app version of MartPromos.jsx and MartLoyalty.jsx.

String promoLine(MartCtx ctx, Json p) {
  final what = switch (str(p['kind'])) {
    'bxgy' => ctx.x('bxgyLine', {'buy': n(p['buy_qty']), 'get': n(p['get_qty'])}),
    'percent' => ctx.x('pctLine', {'v': qtyOf(p['value'])}),
    _ => ctx.x('amtLine', {'v': money(p['value'], ctx.cur)}),
  };
  return n(p['min_spend']) > 0 ? '$what · ${ctx.x('over', {'amt': money(p['min_spend'], ctx.cur)})}' : what;
}

Widget _chip(BuildContext context, String label, bool on, VoidCallback onTap) {
  final c = context.c;
  return ChoiceChip(
    label: Text(label),
    selected: on,
    showCheckmark: false,
    onSelected: (_) => onTap(),
    selectedColor: c.active,
    labelStyle: TextStyle(fontWeight: FontWeight.w700, color: on ? c.brandInk : c.ink),
    side: BorderSide(color: on ? c.brand : c.line),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
  );
}

class PromosTab extends StatefulWidget {
  final MartCtx ctx;
  const PromosTab({super.key, required this.ctx});
  @override
  State<PromosTab> createState() => _PromosTabState();
}

class _PromosTabState extends State<PromosTab> {
  List<Json>? _rows;
  List<Json> _prods = [];
  MartCtx get ctx => widget.ctx;
  bool get _on => ctx.addonOn('mart_promos');

  @override
  void initState() {
    super.initState();
    if (_on) {
      _load();
      ctx.api.get('${ctx.base}/products').then((r) {
        if (mounted) setState(() => _prods = objs(r['data']));
      }, onError: (_) {});
    }
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/promos');
      if (mounted) setState(() => _rows = objs(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _edit(Json row) async {
    final ok = await showSheet<bool>(context, (_) => _PromoEditor(ctx: ctx, row: row, products: _prods));
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final head = MAddonHead(
      ctx: ctx,
      addon: 'mart_promos',
      icon: LucideIcons.badgePercent,
      title: ctx.x('proTitle'),
      sub: ctx.x('proSub'),
      perks: ctx.t.list('mx.proPerks'),
      action: Btn(ctx.x('newPromo'), icon: LucideIcons.plus, small: true, onTap: ctx.readOnly ? null : () => _edit({})),
    );
    if (!_on) return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [head]);
    final c = context.c;
    final days = ctx.t.list('mx.dayNames');
    String cat(Object? id) => str(objs(ctx.data['categories']).where((x) => str(x['_id']) == str(id)).firstOrNull?['name']);
    String prod(Object? id) => str(_prods.where((x) => str(x['_id']) == str(id)).firstOrNull?['name']);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          head,
          mGap,
          if (_rows == null)
            const SkelList(rows: 3)
          else if (_rows!.isEmpty)
            Panel(child: Muted(ctx.x('noPromos'), align: TextAlign.center))
          else
            for (final p in _rows!)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Opacity(
                  opacity: p['active'] == true ? 1 : .6,
                  child: Panel(
                    padding: const EdgeInsets.all(14),
                    onTap: ctx.readOnly ? null : () => _edit(p),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(12)),
                              child: Icon(str(p['code']).isNotEmpty ? LucideIcons.ticket : LucideIcons.badgePercent, size: 18, color: c.brandInk),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(str(p['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text(promoLine(ctx, p), style: TextStyle(color: c.muted, fontSize: 12.5)),
                                ],
                              ),
                            ),
                            Switch(
                              value: p['active'] == true,
                              onChanged: ctx.readOnly
                                  ? null
                                  : (v) async {
                                      try {
                                        await ctx.api.put('${ctx.base}/promos/${p['_id']}', {'active': v});
                                        _load();
                                      } catch (e) {
                                        ctx.fail(e);
                                      }
                                    },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (str(p['code']).isNotEmpty) Chip2(str(p['code']), icon: LucideIcons.ticket, tone: Tone.warn),
                            Chip2(
                              p['target'] == 'all'
                                  ? ctx.x('targets.all')
                                  : p['target'] == 'categories'
                                  ? (p['category_ids'] as List? ?? []).map(cat).where((s) => s.isNotEmpty).join(', ')
                                  : '${(p['product_ids'] as List? ?? []).map(prod).where((s) => s.isNotEmpty).take(4).join(', ')}${(p['product_ids'] as List? ?? []).length > 4 ? '…' : ''}',
                            ),
                            Chip2(ctx.x('wheres.${p['where'] ?? 'both'}')),
                            if ((p['days'] as List? ?? []).isNotEmpty || str(p['time_from']).isNotEmpty)
                              Chip2(
                                '${(p['days'] as List? ?? []).map((d) => days.length > n(d) ? days[n(d).toInt()] : '').join(' ')} ${str(p['time_from']).isNotEmpty && str(p['time_to']).isNotEmpty ? ctx.x('hhLine', {'from': p['time_from'], 'to': p['time_to']}) : ''}'
                                    .trim(),
                                icon: LucideIcons.clock,
                              ),
                            if (str(p['date_from']).isNotEmpty || str(p['date_to']).isNotEmpty)
                              Chip2('${str(p['date_from']).isEmpty ? '…' : p['date_from']} → ${str(p['date_to']).isEmpty ? '…' : p['date_to']}'),
                            Chip2('${ctx.x('uses', {'n': n(p['uses'])})}${n(p['max_uses']) > 0 ? ' / ${n(p['max_uses'])}' : ''}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _PromoEditor extends StatefulWidget {
  final MartCtx ctx;
  final Json row;
  final List<Json> products;
  const _PromoEditor({required this.ctx, required this.row, required this.products});
  @override
  State<_PromoEditor> createState() => _PromoEditorState();
}

class _PromoEditorState extends State<_PromoEditor> with SheetSave {
  late final Json r = widget.row;
  late final _name = TextEditingController(text: str(r['name']));
  late final _value = TextEditingController(text: r['value'] == null ? '' : qtyOf(r['value']));
  late final _buy = TextEditingController(text: '${r['buy_qty'] ?? 2}'), _get = TextEditingController(text: '${r['get_qty'] ?? 1}');
  late final _min = TextEditingController(text: n(r['min_spend']) > 0 ? qtyOf(r['min_spend']) : '');
  late final _code = TextEditingController(text: str(r['code']));
  late final _max = TextEditingController(text: n(r['max_uses']) > 0 ? '${r['max_uses']}' : '');
  late String _kind = str(r['kind']).isEmpty ? 'percent' : str(r['kind']);
  late String _target = str(r['target']).isEmpty ? 'all' : str(r['target']);
  late String _where = str(r['where']).isEmpty ? 'both' : str(r['where']);
  late final Set<String> _cats = {...(r['category_ids'] as List? ?? []).map((e) => '$e')}, _prods = {...(r['product_ids'] as List? ?? []).map((e) => '$e')};
  late final List<int> _days = [...(r['days'] as List? ?? []).map((e) => n(e).toInt())];
  late String _tf = str(r['time_from']), _tt = str(r['time_to']), _df = str(r['date_from']), _dt = str(r['date_to']);
  late bool _active = r['active'] != false;
  final _find = TextEditingController();
  @override
  MartCtx get mctx => widget.ctx;
  bool get _isNew => r['_id'] == null;

  @override
  void dispose() {
    for (final x in [_name, _value, _buy, _get, _min, _code, _max, _find]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _time(bool from) async {
    final cur = from ? _tf : _tt;
    final parts = cur.split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: cur.length == 5 ? TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])) : const TimeOfDay(hour: 17, minute: 0),
    );
    if (t == null) return;
    final v = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() => from ? _tf = v : _tt = v);
  }

  Widget _timeBox(String label, String v, VoidCallback onTap, VoidCallback onClear) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
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
                Expanded(
                  child: Text(
                    v.isEmpty ? '—' : v,
                    style: TextStyle(color: v.isEmpty ? c.muted : c.ink, fontWeight: FontWeight.w600),
                  ),
                ),
                if (v.isNotEmpty)
                  InkWell(
                    onTap: onClear,
                    child: Icon(LucideIcons.x, size: 15, color: c.muted),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final days = ctx.t.list('mx.dayNames');
    final ok =
        _name.text.trim().isNotEmpty &&
        (_kind == 'bxgy' ? (int.tryParse(_buy.text) ?? 0) > 0 && (int.tryParse(_get.text) ?? 0) > 0 : (numOf(_value.text) ?? 0) > 0) &&
        (_target != 'categories' || _cats.isNotEmpty) &&
        (_target != 'products' || _prods.isNotEmpty);
    final body = {
      'name': _name.text.trim(),
      'kind': _kind,
      'value': numOf(_value.text) ?? 0,
      'buy_qty': int.tryParse(_buy.text) ?? 0,
      'get_qty': int.tryParse(_get.text) ?? 0,
      'target': _target,
      'category_ids': _cats.toList(),
      'product_ids': _prods.toList(),
      'min_spend': numOf(_min.text) ?? 0,
      'code': _code.text.trim(),
      'where': _where,
      'days': _days..sort(),
      'time_from': _tf,
      'time_to': _tt,
      'date_from': _df,
      'date_to': _dt,
      'max_uses': int.tryParse(_max.text) ?? 0,
      'active': _active,
    };
    final t = _find.text.trim().toLowerCase();
    final pickProds = widget.products.where((p) => p['active'] != false && (_prods.contains(str(p['_id'])) || t.isEmpty || str(p['name']).toLowerCase().contains(t))).take(60).toList();
    Widget pair(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 10),
        Expanded(child: b),
      ],
    );
    Text label(String s) => Text(s, style: const TextStyle(fontWeight: FontWeight.w700));
    return MSheet(
      title: _isNew ? ctx.x('newPromo') : ctx.x('editPromo'),
      footer: [
        if (!_isNew) SureDelete(remove: ctx.x('remove'), sure: ctx.x('sure'), onDelete: busy ? null : () => save(() => ctx.api.delete('${ctx.base}/promos/${r['_id']}'))),
        const Spacer(),
        Btn(ctx.x('cancel'), kind: BtnKind.ghost, small: true, onTap: busy ? null : () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(
          busy ? ctx.x('saving') : ctx.x('save'),
          small: true,
          busy: busy,
          onTap: !ok || busy ? null : () => save(() => _isNew ? ctx.api.post('${ctx.base}/promos', body) : ctx.api.put('${ctx.base}/promos/${r['_id']}', body), ok: ctx.x('saved')),
        ),
      ],
      children: [
        Field(label: ctx.x('name'), hint: 'Buy 2 get 1 · Happy hour · NEWYEAR', controller: _name, maxLength: 60, autofocus: _isNew, onChanged: (_) => setState(() {})),
        gap14,
        label(ctx.x('kind')),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Segmented<String>(
            value: _kind,
            options: [
              for (final k in ['percent', 'amount', 'bxgy']) (k, ctx.x('kinds.$k')),
            ],
            onChanged: (v) => setState(() => _kind = v),
          ),
        ),
        gap14,
        if (_kind == 'bxgy')
          pair(
            Field(label: ctx.x('buyQty'), controller: _buy, keyboard: TextInputType.number, onChanged: (_) => setState(() {})),
            Field(label: ctx.x('getQty'), controller: _get, keyboard: TextInputType.number, onChanged: (_) => setState(() {})),
          )
        else
          Field(label: '${ctx.x('value')} (${_kind == 'percent' ? '%' : (ctx.cur == 'KHR' ? '៛' : '\$')})', controller: _value, keyboard: decimalKeys, onChanged: (_) => setState(() {})),
        gap14,
        label(ctx.x('target')),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Segmented<String>(
            value: _target,
            options: [
              for (final k in ['all', 'categories', 'products']) (k, ctx.x('targets.$k')),
            ],
            onChanged: (v) => setState(() => _target = v),
          ),
        ),
        if (_target == 'categories') ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final cat in objs(ctx.data['categories']))
                _chip(context, str(cat['name']), _cats.contains(str(cat['_id'])), () => setState(() => _cats.contains(str(cat['_id'])) ? _cats.remove(str(cat['_id'])) : _cats.add(str(cat['_id'])))),
            ],
          ),
        ],
        if (_target == 'products') ...[
          const SizedBox(height: 8),
          if (widget.products.length > 12) ...[Field(controller: _find, hint: ctx.x('search'), icon: LucideIcons.search, onChanged: (_) => setState(() {})), const SizedBox(height: 8)],
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in pickProds)
                _chip(context, str(p['name']), _prods.contains(str(p['_id'])), () => setState(() => _prods.contains(str(p['_id'])) ? _prods.remove(str(p['_id'])) : _prods.add(str(p['_id'])))),
            ],
          ),
        ],
        gap14,
        pair(
          Field(label: ctx.x('minSpend'), controller: _min, keyboard: decimalKeys),
          Field(
            label: ctx.x('code'),
            hint: 'SAVE10',
            controller: _code,
            maxLength: 20,
            onChanged: (v) {
              final up = v.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_-]'), '');
              if (up != v) {
                _code.value = TextEditingValue(
                  text: up,
                  selection: TextSelection.collapsed(offset: up.length),
                );
              }
            },
          ),
        ),
        const SizedBox(height: 4),
        Muted(ctx.x('codeHint')),
        gap14,
        label(ctx.x('where')),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Segmented<String>(
            value: _where,
            options: [
              for (final k in ['both', 'pos', 'online']) (k, ctx.x('wheres.$k')),
            ],
            onChanged: (v) => setState(() => _where = v),
          ),
        ),
        gap14,
        label(ctx.x('days')),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _chip(context, ctx.x('everyDay'), _days.isEmpty, () => setState(_days.clear)),
            for (final (i, d) in days.indexed) _chip(context, d, _days.contains(i), () => setState(() => _days.contains(i) ? _days.remove(i) : _days.add(i))),
          ],
        ),
        gap14,
        pair(_timeBox(ctx.x('timeFrom'), _tf, () => _time(true), () => setState(() => _tf = '')), _timeBox(ctx.x('timeTo'), _tt, () => _time(false), () => setState(() => _tt = ''))),
        gap14,
        pair(DayField(label: ctx.x('dateFrom'), value: _df, onChanged: (v) => setState(() => _df = v)), DayField(label: ctx.x('dateTo'), value: _dt, onChanged: (v) => setState(() => _dt = v))),
        gap14,
        Field(label: ctx.x('maxUses'), controller: _max, keyboard: TextInputType.number),
        gap14,
        SwitchRow(title: ctx.x('active'), value: _active, onChanged: (v) => setState(() => _active = v)),
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------- Loyalty
class LoyaltyTab extends StatefulWidget {
  final MartCtx ctx;
  const LoyaltyTab({super.key, required this.ctx});
  @override
  State<LoyaltyTab> createState() => _LoyaltyTabState();
}

class _LoyaltyTabState extends State<LoyaltyTab> {
  Json? _info;
  List<Json>? _members;
  String _sort = 'top';
  final _q = TextEditingController();
  final _per = TextEditingController(), _val = TextEditingController(), _min = TextEditingController();
  bool _onRule = false, _online = false, _saving = false;
  Timer? _wait;
  MartCtx get ctx => widget.ctx;
  bool get _on => ctx.addonOn('mart_loyalty');

  @override
  void initState() {
    super.initState();
    if (_on) {
      _loadInfo();
      _loadMembers();
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    for (final x in [_q, _per, _val, _min]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInfo({bool reset = true}) async {
    try {
      final r = await ctx.api.get('${ctx.base}/loyalty');
      if (!mounted) return;
      setState(() {
        _info = obj(r['data']);
        if (reset) _resetRules();
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  void _resetRules() {
    final rules = obj(_info?['rules']);
    _onRule = rules['on'] == true;
    _online = rules['online'] == true;
    _per.text = qtyOf(rules['earn_per']);
    _val.text = qtyOf(rules['point_value']);
    _min.text = qtyOf(rules['min_redeem']);
  }

  Future<void> _loadMembers() async {
    try {
      final r = await ctx.api.get('${ctx.base}/loyalty/members', {'q': _q.text.trim(), 'sort': _sort});
      if (mounted) setState(() => _members = objs(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  bool get _dirty {
    final rules = obj(_info?['rules']);
    return _info != null &&
        (_onRule != (rules['on'] == true) ||
            _online != (rules['online'] == true) ||
            numOf(_per.text) != n(rules['earn_per']) ||
            numOf(_val.text) != n(rules['point_value']) ||
            numOf(_min.text) != n(rules['min_redeem']));
  }

  Future<void> _saveRules() async {
    setState(() => _saving = true);
    try {
      await ctx.api.put('${ctx.base}/loyalty', {'on': _onRule, 'online': _online, 'earn_per': numOf(_per.text) ?? 0, 'point_value': numOf(_val.text) ?? 0, 'min_redeem': numOf(_min.text) ?? 0});
      ctx.notify(ctx.x('saved'));
      await _loadInfo();
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editMember(Json row) async {
    final ok = await showSheet<bool>(context, (_) => _MemberEditor(ctx: ctx, row: row));
    if (ok == true) {
      _loadInfo(reset: false);
      _loadMembers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final head = MAddonHead(ctx: ctx, addon: 'mart_loyalty', icon: LucideIcons.gift, title: ctx.x('loyTitle'), sub: ctx.x('loySub'), perks: ctx.t.list('mx.loyPerks'));
    if (!_on) return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [head]);
    final c = context.c;
    final info = _info;
    final totals = obj(info?['totals']);
    final sym = ctx.cur == 'KHR' ? '៛' : '\$';
    return RefreshIndicator(
      onRefresh: () async {
        await _loadInfo(reset: false);
        await _loadMembers();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          head,
          mGap,
          if (info != null) ...[
            Tiles([
              ('${n(totals['members'])}', ctx.x('members'), null),
              ('${n(totals['points']).round()}', ctx.x('pointsOut'), null),
              (money(totals['owed'], ctx.cur), ctx.x('owed'), null),
              ('${n(totals['redeemed']).round()}', ctx.x('redeemed'), null),
            ]),
            mGap,
          ],
          mCard(context, ctx.x('loyRules'), [
            if (info == null)
              const SkelList(rows: 3)
            else ...[
              SwitchRow(title: ctx.x('loyOn'), value: _onRule, onChanged: ctx.readOnly ? null : (v) => setState(() => _onRule = v)),
              const SizedBox(height: 8),
              Field(label: '${ctx.x('earnPer')} ($sym)', controller: _per, keyboard: decimalKeys, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
              gap14,
              Field(label: '${ctx.x('pointValue')} ($sym)', controller: _val, keyboard: decimalKeys, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
              gap14,
              Field(label: ctx.x('minRedeem'), controller: _min, keyboard: TextInputType.number, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
              const SizedBox(height: 8),
              SwitchRow(title: ctx.x('loyOnline'), value: _online, onChanged: ctx.readOnly ? null : (v) => setState(() => _online = v)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  ctx.x('loyExample', {'spend': money(numOf(_per.text) ?? 0, ctx.cur), 'n': _min.text, 'value': money((numOf(_min.text) ?? 0) * (numOf(_val.text) ?? 0), ctx.cur)}),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (_dirty) Btn(ctx.m('cancel'), kind: BtnKind.ghost, small: true, onTap: () => setState(_resetRules)),
                  const Spacer(),
                  Btn(ctx.x('save'), small: true, busy: _saving, onTap: !_dirty || ctx.readOnly || _saving ? null : _saveRules),
                ],
              ),
            ],
          ]),
          mGap,
          mCard(context, ctx.x('members'), [
            Field(
              controller: _q,
              hint: '${ctx.x('name')} / ${ctx.x('phone')}',
              icon: LucideIcons.search,
              onChanged: (_) {
                _wait?.cancel();
                _wait = Timer(const Duration(milliseconds: 300), _loadMembers);
              },
            ),
            const SizedBox(height: 8),
            Segmented<String>(
              value: _sort,
              options: [('top', ctx.x('sortTop')), ('recent', ctx.x('sortRecent'))],
              onChanged: (v) {
                setState(() => _sort = v);
                _loadMembers();
              },
            ),
            const SizedBox(height: 8),
            if (_members == null)
              const SkelList(rows: 3)
            else if (_members!.isEmpty)
              Muted(ctx.x('noMembers'))
            else
              for (final mb in _members!)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final r = await showSheet<Object>(context, (_) => _MemberView(ctx: ctx, mid: str(mb['_id'])));
                    _loadInfo(reset: false);
                    _loadMembers();
                    if (r is Map && r['edit'] != null) _editMember(obj(r['edit']));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 19,
                          backgroundColor: c.active,
                          child: Icon(LucideIcons.userRound, size: 18, color: c.brandInk),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(str(mb['name']).isEmpty ? str(mb['phone']) : str(mb['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                '${mb['phone']} · ${ctx.x('visits')} ${n(mb['visits'])} · ${ctx.x('spent')} ${money(mb['spent'], ctx.cur)}${mb['last_at'] != null ? ' · ${mDate(mb['last_at'], ctx.lang)}' : ''}',
                                style: TextStyle(color: c.muted, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${n(mb['points']).round()}',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: c.brand),
                        ),
                      ],
                    ),
                  ),
                ),
          ], trailing: Btn(ctx.x('addMember'), icon: LucideIcons.plus, small: true, onTap: ctx.readOnly ? null : () => _editMember({}))),
        ],
      ),
    );
  }
}

class _MemberEditor extends StatefulWidget {
  final MartCtx ctx;
  final Json row;
  const _MemberEditor({required this.ctx, required this.row});
  @override
  State<_MemberEditor> createState() => _MemberEditorState();
}

class _MemberEditorState extends State<_MemberEditor> with SheetSave {
  late final _phone = TextEditingController(text: str(widget.row['phone'])), _name = TextEditingController(text: str(widget.row['name'])), _note = TextEditingController(text: str(widget.row['note']));
  @override
  MartCtx get mctx => widget.ctx;
  bool get _isNew => widget.row['_id'] == null;

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final body = {'phone': _phone.text.trim(), 'name': _name.text.trim(), 'note': _note.text.trim()};
    return MSheet(
      title: _isNew ? ctx.x('addMember') : ctx.x('memberEdit'),
      footer: [
        if (!_isNew) SureDelete(remove: ctx.x('remove'), sure: ctx.x('sure'), onDelete: busy ? null : () => save(() => ctx.api.delete('${ctx.base}/loyalty/members/${widget.row['_id']}'))),
        const Spacer(),
        Btn(ctx.x('cancel'), kind: BtnKind.ghost, small: true, onTap: busy ? null : () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(
          busy ? ctx.x('saving') : ctx.x('save'),
          small: true,
          busy: busy,
          onTap: busy || _phone.text.replaceAll(RegExp(r'\D'), '').length < 8
              ? null
              : () => save(() => _isNew ? ctx.api.post('${ctx.base}/loyalty/members', body) : ctx.api.put('${ctx.base}/loyalty/members/${widget.row['_id']}', body), ok: ctx.x('saved')),
        ),
      ],
      children: [
        Field(label: ctx.x('phone'), controller: _phone, maxLength: 30, keyboard: TextInputType.phone, autofocus: _isNew, onChanged: (_) => setState(() {})),
        gap14,
        Field(label: ctx.x('name'), controller: _name, maxLength: 80),
        gap14,
        Field(label: ctx.x('note'), controller: _note, maxLength: 200),
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}

class _MemberView extends StatefulWidget {
  final MartCtx ctx;
  final String mid;
  const _MemberView({required this.ctx, required this.mid});
  @override
  State<_MemberView> createState() => _MemberViewState();
}

class _MemberViewState extends State<_MemberView> {
  Json? _data;
  final _pts = TextEditingController(), _note = TextEditingController();
  bool _busy = false;
  MartCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pts.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/loyalty/members/${widget.mid}');
      if (mounted) setState(() => _data = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _adjust() async {
    final v = (numOf(_pts.text) ?? 0).round();
    if (v == 0) return;
    setState(() => _busy = true);
    try {
      await ctx.api.post('${ctx.base}/loyalty/members/${widget.mid}/adjust', {'points': v, 'note': _note.text.trim()});
      _pts.clear();
      _note.clear();
      ctx.notify(ctx.x('saved'));
      await _load();
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final mb = obj(_data?['member']);
    return MSheet(
      title: _data == null ? ctx.x('memberEdit') : (str(mb['name']).isEmpty ? str(mb['phone']) : str(mb['name'])),
      footer: [
        if (_data != null && !ctx.readOnly) Btn(ctx.x('edit'), icon: LucideIcons.pencil, kind: BtnKind.ghost, small: true, onTap: () => Navigator.pop(context, {'edit': mb})),
      ],
      children: [
        if (_data == null)
          const SkelList(rows: 4)
        else ...[
          Tiles([
            ('${n(mb['points']).round()}', ctx.x('points'), c.good),
            ('${n(mb['earned']).round()}', ctx.x('earned'), null),
            ('${n(mb['redeemed']).round()}', ctx.x('redeemed'), null),
            (money(mb['spent'], ctx.cur), ctx.x('spent'), null),
          ]),
          const SizedBox(height: 8),
          Muted('${mb['phone']} · ${ctx.x('visits')} ${n(mb['visits'])}${str(mb['note']).isNotEmpty ? ' · ${mb['note']}' : ''}'),
          if (!ctx.readOnly) ...[
            gap14,
            Text(ctx.x('adjust'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Field(controller: _pts, hint: '+50 / −20', keyboard: const TextInputType.numberWithOptions(signed: true), onChanged: (_) => setState(() {})),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Field(controller: _note, hint: ctx.x('note'), maxLength: 200),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Muted(ctx.x('adjustHint'))),
                const SizedBox(width: 8),
                Btn(ctx.x('adjust'), small: true, busy: _busy, onTap: _busy || (numOf(_pts.text) ?? 0).round() == 0 ? null : _adjust),
              ],
            ),
          ],
          gap14,
          Text(ctx.x('moves'), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          for (final mv in objs(_data!['moves']))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ctx.t.or('mx.move.${mv['kind']}', str(mv['kind'])), style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          [mDayTime(mv['created_date'], ctx.lang), str(mv['sale_no']), str(mv['order_no']), str(mv['note'])].where((s) => s.isNotEmpty).join(' · '),
                          style: TextStyle(color: c.muted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${n(mv['points']) > 0 ? '+' : ''}${n(mv['points']).round()}',
                        style: TextStyle(fontWeight: FontWeight.w800, color: n(mv['points']) > 0 ? c.good : c.danger),
                      ),
                      Text('${n(mv['balance_after']).round()}', style: TextStyle(color: c.muted, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
