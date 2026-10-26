import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'rest_common.dart';
import 'rest_reports.dart' show whenShort;

// Stock (the web's StockTab.jsx): what's left of each item, stock in / out / count, history, sample items.

extension on RestCtx {
  String sk(String key, [Map<String, Object?> vars = const {}]) => t('stock.$key', vars);
}

String _stateOf(Json i) {
  if (i['track_stock'] != true) return 'none';
  final s = n(i['stock']), low = i['low_stock'] == null ? 5 : n(i['low_stock']);
  return s <= 0 ? 'out' : (s <= low ? 'low' : 'ok');
}

class StockSection extends StatefulWidget {
  final RestCtx ctx;
  const StockSection({super.key, required this.ctx});
  @override
  State<StockSection> createState() => _StockSectionState();
}

class _StockSectionState extends State<StockSection> {
  Json? _data;
  String _filter = 'all', _q = '', _busy = '';
  final _search = TextEditingController();
  RestCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/stock');
      if (mounted) setState(() => _data = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _act(String key, Future<void> Function() fn) async {
    setState(() => _busy = key);
    try {
      await fn();
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Future<void> _move(Json item, String kind) async {
    final saved = await showEditor<bool>(
      context,
      builder: (_) => _MoveEditor(ctx: ctx, item: item, kind: kind),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final data = _data;
    if (data == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 5));
    final sm = obj(data['summary']);
    final cats = {for (final x in objs(data['categories'])) str(x['_id']): x};
    final qq = _q.trim().toLowerCase();
    final rows = objs(data['items'])
        .where((i) => _filter == 'all' ? i['track_stock'] == true : (_filter == 'none' ? i['track_stock'] != true : _stateOf(i) == _filter))
        .where((i) => qq.isEmpty || '${str(i['name_en'])} ${str(i['name_km'])}'.toLowerCase().contains(qq))
        .toList();
    String money(Object? v) => fmtMoney(n(v), ctx.currency);
    final active = data['active'] == true;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RestHead(ctx.sk('title'), sub: ctx.sk('sub')),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Btn(ctx.sk('history'), icon: LucideIcons.history, kind: BtnKind.ghost, small: true, onTap: () => _history(null)),
                    if (n(sm['items']) <= 40)
                      Btn(
                        _busy == 'sample' ? ctx.r('saving') : ctx.sk('addSamples'),
                        icon: LucideIcons.sparkles,
                        kind: BtnKind.ghost,
                        small: true,
                        busy: _busy == 'sample',
                        onTap: ctx.readOnly || _busy == 'sample'
                            ? null
                            : () => _act('sample', () async {
                                final r = await ctx.api.post('${ctx.base}/stock/sample');
                                await _load();
                                ctx.reload();
                                ctx.notify(r['tracked'] == true ? ctx.sk('samplesDone') : ctx.sk('samplesDoneNoStock'));
                              }),
                      ),
                  ],
                ),
              ],
            ),
          ),
          gap14,
          if (!active) AddonPrompt(ctx: ctx, addonKey: 'rest_stock'),
          if (active) ...[
            LayoutBuilder(
              builder: (_, box) {
                final w = (box.maxWidth - 12) / 2;
                Widget kpi(String label, String value, {String? sub, Color? tone, VoidCallback? onTap}) => SizedBox(
                  width: w,
                  child: Panel(
                    padding: const EdgeInsets.all(14),
                    onTap: onTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: value),
                                if (sub != null)
                                  TextSpan(
                                    text: ' $sub',
                                    style: TextStyle(fontSize: 13, color: c.muted, fontWeight: FontWeight.w600),
                                  ),
                              ],
                            ),
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tone ?? c.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    kpi(ctx.sk('kpiTracked'), fmt(sm['tracked']), sub: '/ ${fmt(sm['items'])}'),
                    kpi(ctx.sk('kpiLow'), fmt(sm['low']), tone: n(sm['low']) > 0 ? c.warn : null, onTap: () => setState(() => _filter = 'low')),
                    kpi(ctx.sk('kpiOut'), fmt(sm['out']), tone: n(sm['out']) > 0 ? c.danger : null, onTap: () => setState(() => _filter = 'out')),
                    kpi(ctx.sk('kpiValue'), money(sm['value'])),
                    kpi(ctx.sk('kpiRetail'), money(sm['retail'])),
                  ],
                );
              },
            ),
            gap14,
            Field(
              controller: _search,
              hint: ctx.sk('search'),
              icon: LucideIcons.search,
              onChanged: (v) => setState(() => _q = v),
              suffix: _q.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () => setState(() {
                        _search.clear();
                        _q = '';
                      }),
                    ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (k, label) in [('all', ctx.sk('all')), ('low', ctx.sk('low')), ('out', ctx.sk('out')), ('none', ctx.sk('notTracked'))])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(label: Text(label), selected: _filter == k, onSelected: (_) => setState(() => _filter = k)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Panel(child: Muted(_filter == 'all' && n(sm['tracked']) == 0 ? ctx.sk('noneTracked') : ctx.sk('none'), align: TextAlign.center))
            else
              Panel(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final (i, it) in rows.indexed) ...[if (i > 0) Divider(height: 1, color: c.line, indent: 16, endIndent: 16), _row(it, cats[str(it['category_id'])], money)],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _row(Json i, Json? cat, String Function(Object?) money) {
    final c = context.c;
    final st = _stateOf(i);
    final price = n(i['price']), cost = n(i['cost']);
    final margin = price != 0 ? ((price - cost) / price * 100).round() : 0;
    final catColor = str(cat?['color']);
    final badge = switch (st) {
      'out' => Chip2(ctx.sk('soldOut'), tone: Tone.danger),
      'low' => Chip2(fmt(i['stock']), tone: Tone.warn),
      'ok' => Chip2(fmt(i['stock']), tone: Tone.good),
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: str(i['photo']).isNotEmpty
                    ? Image(image: netImage(
                        str(i['photo'])),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(LucideIcons.package, size: 18, color: c.muted),
                      )
                    : Icon(LucideIcons.package, size: 18, color: c.muted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nameOf(i, ctx.lang), style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (catColor.isNotEmpty) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: _hex(catColor), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Flexible(
                          child: Text(
                            [if (cat != null) nameOf(cat, ctx.lang), money(price), if (cost > 0) '${ctx.sk('colCost')} ${money(cost)}', if (cost > 0) '$margin%'].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: margin < 0 && cost > 0 ? c.danger : c.muted, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_filter != 'none' && badge != null) ...[const SizedBox(width: 8), badge],
            ],
          ),
          const SizedBox(height: 10),
          if (i['track_stock'] == true)
            Row(
              children: [
                Btn(ctx.sk('stockIn'), icon: LucideIcons.plus, small: true, onTap: ctx.readOnly ? null : () => _move(i, 'in')),
                const Spacer(),
                RoundBtn(LucideIcons.minus, size: 38, tip: ctx.sk('stockOut'), onTap: ctx.readOnly ? null : () => _move(i, 'out')),
                const SizedBox(width: 8),
                RoundBtn(LucideIcons.clipboardCheck, size: 38, tip: ctx.sk('count'), onTap: ctx.readOnly ? null : () => _move(i, 'count')),
                const SizedBox(width: 8),
                RoundBtn(LucideIcons.history, size: 38, tip: ctx.sk('history'), onTap: () => _history(i)),
              ],
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: Btn(
                _busy == str(i['_id']) ? ctx.sk('tracking') : ctx.sk('track'),
                kind: BtnKind.ghost,
                small: true,
                busy: _busy == str(i['_id']),
                onTap: ctx.readOnly || _busy == str(i['_id'])
                    ? null
                    : () => _act(str(i['_id']), () async {
                        await ctx.api.put('${ctx.base}/items/${i['_id']}', {'track_stock': true});
                        await _load();
                      }),
              ),
            ),
        ],
      ),
    );
  }

  void _history(Json? item) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _HistorySheet(ctx: ctx, item: item),
  );
}

Color _hex(String h) => Color(0xFF000000 | (int.tryParse(h.replaceFirst('#', ''), radix: 16) ?? 0x999999));

// stock in / out / count
class _MoveEditor extends StatefulWidget {
  final RestCtx ctx;
  final Json item;
  final String kind;
  const _MoveEditor({required this.ctx, required this.item, required this.kind});
  @override
  State<_MoveEditor> createState() => _MoveEditorState();
}

class _MoveEditorState extends State<_MoveEditor> {
  late final _qty = TextEditingController(text: widget.kind == 'count' ? fmt(widget.item['stock']).replaceAll(',', '') : '');
  late final _cost = TextEditingController(text: widget.item['cost'] == null ? '' : '${widget.item['cost']}');
  final _note = TextEditingController();
  bool _busy = false;
  String _error = '';
  RestCtx get ctx => widget.ctx;

  @override
  void dispose() {
    _qty.dispose();
    _cost.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await ctx.api.post('${ctx.base}/stock/${widget.item['_id']}', {
        'kind': widget.kind,
        'qty': num.parse(_qty.text.trim()),
        'note': _note.text.trim(),
        if (widget.kind == 'in' && _cost.text.trim().isNotEmpty) 'cost': num.tryParse(_cost.text.trim()) ?? 0,
      });
      ctx.notify(ctx.r('saved'));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiError ? e.message : '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final kind = widget.kind, item = widget.item;
    final stock = n(item['stock']);
    final low = item['low_stock'] == null ? 5 : n(item['low_stock']);
    final q = num.tryParse(_qty.text.trim());
    final can = q != null && q >= 0 && (kind == 'count' || q > 0);
    final after = q == null ? stock : (kind == 'in' ? stock + q : (kind == 'out' ? stock - q : q));
    return EditorFrame(
      title: ctx.sk('moveTitle.$kind', {'name': nameOf(item, ctx.lang)}),
      cancel: ctx.r('cancel'),
      save: ctx.sk('save'),
      busy: _busy,
      canSave: can,
      onSave: _save,
      children: [
        Muted(ctx.sk('moveSub.$kind')),
        gap14,
        Field(label: kind == 'count' ? ctx.sk('countedQty') : ctx.sk('qty'), controller: _qty, keyboard: TextInputType.number, autofocus: true, onChanged: (_) => setState(() {})),
        if (can) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Expanded(child: Muted(ctx.sk('colStock'))),
                Text(
                  ctx.sk('nowAfter', {'a': fmt(stock), 'b': fmt(after)}),
                  style: TextStyle(fontWeight: FontWeight.w800, color: after <= 0 ? c.danger : (after <= low ? c.warn : c.ink)),
                ),
              ],
            ),
          ),
        ],
        if (kind == 'in') ...[
          gap14,
          Field(label: '${ctx.sk('costEach')} (${ctx.currency})', controller: _cost, keyboard: const TextInputType.numberWithOptions(decimal: true)),
          Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Muted(ctx.sk('costEachHint'))),
        ],
        gap14,
        Field(label: ctx.sk('note'), hint: ctx.sk('notePh'), controller: _note, maxLength: 200, onChanged: (_) => setState(() {})),
        if (kind == 'out') ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final x in ctx.t.list('stock.reasons'))
                ChoiceChip(
                  label: Text(x),
                  selected: _note.text == x,
                  onSelected: (_) => setState(() {
                    _note.text = x;
                    HapticFeedback.selectionClick();
                  }),
                ),
            ],
          ),
        ],
        if (_error.isNotEmpty) ...[gap14, Alert(_error)],
      ],
    );
  }
}

// every change of one item (or all items)
class _HistorySheet extends StatefulWidget {
  final RestCtx ctx;
  final Json? item;
  const _HistorySheet({required this.ctx, this.item});
  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  int _page = 1;
  Json? _data;
  RestCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/stock/moves', {'item': widget.item?['_id'], 'page': _page});
      if (mounted) setState(() => _data = r);
    } catch (e) {
      ctx.fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = objs(_data?['data']);
    final pg = obj(_data?['pagination']);
    final item = widget.item;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .8,
      minChildSize: .4,
      maxChildSize: 1,
      builder: (_, scroll) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              item == null ? ctx.sk('historyAll') : ctx.sk('historyTitle', {'name': nameOf(item, ctx.lang)}),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                if (_data == null) const SkelList(rows: 4),
                if (_data != null && rows.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Muted(ctx.sk('noMoves'))),
                for (final (i, m) in rows.indexed) ...[
                  if (i > 0) Divider(height: 1, color: c.line),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Chip2(ctx.sk('kinds.${m['kind']}'), tone: _tone(str(m['kind']))),
                                  if (item == null) ...[
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        str(m['item_name']),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  whenShort(m['created_date'], ctx.lang),
                                  str(m['by']),
                                  if (str(m['order_number']).isNotEmpty) '#${str(m['order_number'])}',
                                  str(m['note']),
                                ].where((x) => x.isNotEmpty).join(' · '),
                                style: TextStyle(color: c.muted, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${n(m['qty']) > 0 ? '+' : ''}${fmt(m['qty'])}',
                              style: TextStyle(fontWeight: FontWeight.w800, color: n(m['qty']) < 0 ? c.danger : c.good),
                            ),
                            Text('${ctx.sk('colAfter')} ${fmt(m['after'])}', style: TextStyle(color: c.muted, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                if (n(pg['totalPages']) > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        RoundBtn(
                          LucideIcons.chevronLeft,
                          size: 40,
                          onTap: _page <= 1
                              ? null
                              : () {
                                  setState(() => _page--);
                                  _load();
                                },
                        ),
                        const SizedBox(width: 12),
                        Muted(ctx.sk('page', {'p': pg['currentPage'], 'n': pg['totalPages']})),
                        const SizedBox(width: 12),
                        RoundBtn(
                          LucideIcons.chevronRight,
                          size: 40,
                          onTap: _page >= n(pg['totalPages'])
                              ? null
                              : () {
                                  setState(() => _page++);
                                  _load();
                                },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Tone _tone(String kind) => switch (kind) {
    'in' || 'opening' => Tone.good,
    'out' || 'sale' => Tone.danger,
    'count' => Tone.brand,
    _ => Tone.muted,
  };
}
