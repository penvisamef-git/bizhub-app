import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../event/ev_common.dart' show EvChips, EvHead, evPickFrom;
import 'ts_common.dart';
import 'ts_orders.dart' show TsOrderRow, showTsOrder;

// Customers: people who ordered from the store — the web's TsCustomers.jsx.
//   GET /customers?q&kind&sort&page → { data, pagination, stats }   GET /customers/:cid   PUT /customers/:cid { note }

String _initial(String s) => s.trim().isEmpty ? '?' : s.trim().substring(0, 1).toUpperCase();

class CustomersTab extends StatefulWidget {
  final TsCtx ctx;
  const CustomersTab({super.key, required this.ctx});
  @override
  State<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<CustomersTab> {
  final _q = TextEditingController();
  String _kind = 'all', _sort = 'recent';
  int _page = 1;
  Json? _r;
  Timer? _deb;
  TsCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _deb?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/customers', {if (_q.text.trim().isNotEmpty) 'q': _q.text.trim(), 'sort': _sort, 'page': _page, if (_kind != 'all') 'kind': _kind});
      if (mounted) setState(() => _r = r);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(
        () => _r = {
          'data': <Json>[],
          'stats': <String, dynamic>{},
          'pagination': {'total': 0, 'limit': 30},
        },
      );
      ctx.notify(e.network ? ctx.t('app.offline') : e.message);
    }
  }

  void _set(VoidCallback f) {
    setState(() {
      f();
      _page = 1;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = _r;
    final st = obj(r?['stats']);
    final pg = obj(r?['pagination']);
    final pages = r == null ? 1 : (n(pg['total']) / (n(pg['limit']) == 0 ? 30 : n(pg['limit']))).ceil().clamp(1, 9999);
    final rows = objs(r?['data']);
    const kinds = ['all', 'telegram', 'web', 'repeat', 'message'];
    const sorts = ['recent', 'spent', 'orders', 'new', 'name'];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + MediaQuery.of(context).padding.bottom),
        children: [
          EvHead(ctx.m('tabs.customers'), sub: ctx.m('customersSub')),
          TsKpis([
            for (final k in ['all', 'telegram', 'repeat', 'new_month', 'spent']) TsKpi(ctx.m('custStats.$k'), r == null ? '…' : (k == 'spent' ? ctx.money(st['spent']) : fmt(n(st[k])))),
          ]),
          const SizedBox(height: 14),
          Field(
            controller: _q,
            hint: ctx.m('search'),
            icon: LucideIcons.search,
            onChanged: (_) {
              _deb?.cancel();
              _deb = Timer(const Duration(milliseconds: 350), () => _set(() {}));
            },
          ),
          const SizedBox(height: 10),
          EvChips(items: [for (final k in kinds) (k, ctx.m('kinds2.$k'), null)], value: _kind, onPick: (v) => _set(() => _kind = v)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              avatar: Icon(LucideIcons.arrowUpDown, size: 14, color: c.muted),
              label: Text('${ctx.m('sortBy')}: ${ctx.m('sorts.$_sort')}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              backgroundColor: c.chip,
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                final v = await evPickFrom(context, ctx.m('sortBy'), [for (final s in sorts) (s, ctx.m('sorts.$s'))], value: _sort);
                if (v != null) _set(() => _sort = v);
              },
            ),
          ),
          const SizedBox(height: 12),
          if (r == null)
            const SkelList(rows: 4)
          else if (rows.isEmpty)
            Panel(
              child: Column(
                children: [
                  Icon(LucideIcons.users, size: 28, color: c.muted),
                  const SizedBox(height: 8),
                  Muted(ctx.m('noCustomers'), align: TextAlign.center),
                ],
              ),
            )
          else ...[
            for (final cu in rows) _row(context, cu),
            if (pages > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Btn(
                      ctx.m('prev'),
                      icon: LucideIcons.chevronLeft,
                      small: true,
                      kind: BtnKind.ghost,
                      onTap: _page <= 1
                          ? null
                          : () {
                              setState(() => _page--);
                              _load();
                            },
                    ),
                    const SizedBox(width: 12),
                    Text(ctx.m('pageOf', {'p': _page, 'n': pages})),
                    const SizedBox(width: 12),
                    Btn(
                      ctx.m('next'),
                      small: true,
                      kind: BtnKind.ghost,
                      onTap: _page >= pages
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
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Json cu) {
    final c = context.c;
    final name = str(cu['name']).isNotEmpty ? str(cu['name']) : str(cu['phone']);
    final contact = [if (str(cu['username']).isNotEmpty) '@${cu['username']}', cu['telegram'] == true ? 'Telegram' : ctx.m('viaWeb')].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _open(cu),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.line),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: c.active,
                  child: Text(
                    _initial(name),
                    style: TextStyle(color: c.brandInk, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? '—' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        [if (str(cu['phone']).isNotEmpty && str(cu['name']).isNotEmpty) str(cu['phone']), contact].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.muted, fontSize: 12.5),
                      ),
                      if (str(cu['note']).isNotEmpty)
                        Text(
                          str(cu['note']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.muted, fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(ctx.money(cu['spent']), style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                      '${fmt(n(cu['orders']))}${n(cu['placed']) > n(cu['orders']) ? ' / ${fmt(n(cu['placed']))}' : ''} · ${cu['last_order_at'] != null ? ctx.ago(cu['last_order_at']) : ctx.m('never')}',
                      style: TextStyle(fontSize: 11.5, color: c.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(Json cu) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _CustomerSheet(ctx: ctx, id: str(cu['_id']), onSaved: _load),
    );
  }
}

class _CustomerSheet extends StatefulWidget {
  final TsCtx ctx;
  final String id;
  final VoidCallback onSaved;
  const _CustomerSheet({required this.ctx, required this.id, required this.onSaved});
  @override
  State<_CustomerSheet> createState() => _CustomerSheetState();
}

class _CustomerSheetState extends State<_CustomerSheet> {
  Json? _d;
  final _note = TextEditingController();
  bool _busy = false;
  TsCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await ctx.run(() => ctx.api.get('${ctx.base}/customers/${widget.id}'));
    if (!mounted || r == null) return;
    final d = obj(r['data']);
    setState(() {
      if (_d == null) {
        _note.text = str(obj(d['customer'])['note']);
      }
      _d = d;
    });
  }

  Future<void> _saveNote() async {
    setState(() => _busy = true);
    final r = await ctx.run(() => ctx.api.put('${ctx.base}/customers/${widget.id}', {'note': _note.text.trim()}), ctx.m('saved'));
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r != null && _d != null) {
        _d = {
          ..._d!,
          'customer': {...obj(_d!['customer']), 'note': _note.text.trim()},
        };
      }
    });
    if (r != null) widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = _d;
    final cu = obj(d?['customer']);
    final name = str(cu['name']).isNotEmpty ? str(cu['name']) : str(cu['phone']);
    final orders = n(cu['orders']);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .88,
      maxChildSize: .95,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.of(context).viewInsets.bottom),
        children: d == null
            ? const [SkelList(rows: 4)]
            : [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: c.active,
                      child: Text(
                        _initial(name),
                        style: TextStyle(color: c.brandInk, fontWeight: FontWeight.w800, fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name.isEmpty ? '—' : name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                          Muted(ctx.m('since', {'date': tsDay(cu['created_date'], ctx.lang)})),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (str(cu['phone']).isNotEmpty)
                                InkWell(
                                  onTap: () => tsOpen('tel:${cu['phone']}'),
                                  child: TsPill(str(cu['phone']), icon: LucideIcons.phone, tone: Tone.brand),
                                ),
                              if (str(cu['username']).isNotEmpty)
                                InkWell(
                                  onTap: () => tsOpen('https://t.me/${cu['username']}'),
                                  child: TsPill('@${cu['username']}', icon: LucideIcons.send, tone: Tone.brand),
                                ),
                              if (cu['can_message'] == true) TsPill(ctx.m('canMessage'), icon: LucideIcons.messageCircle, tone: Tone.good),
                            ],
                          ),
                          if (str(cu['address']).isNotEmpty) TsLine(LucideIcons.mapPin, str(cu['address'])),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TsKpis([
                  TsKpi(ctx.m('custCols.orders'), '${fmt(orders)}${n(cu['placed']) > orders ? ' / ${fmt(n(cu['placed']))}' : ''}'),
                  TsKpi(ctx.m('custCols.spent'), ctx.money(cu['spent'])),
                  TsKpi(ctx.m('avg'), orders > 0 ? ctx.money(n(cu['spent']) / orders) : '—'),
                  TsKpi(ctx.m('custCols.last'), cu['last_order_at'] != null ? ctx.ago(cu['last_order_at']) : ctx.m('never')),
                ]),
                if (objs(d['favourites']).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(ctx.m('favourites'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [for (final f in objs(d['favourites'])) TsPill('${f['name']} × ${fmt(n(f['qty']))}')]),
                ],
                const SizedBox(height: 16),
                Field(label: ctx.m('custNote'), controller: _note, hint: ctx.m('custNotePh'), maxLength: 300, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Btn(
                    ctx.m('save'),
                    small: true,
                    busy: _busy,
                    onTap: ctx.readOnly || _busy || _note.text.trim() == str(cu['note']) ? null : _saveNote,
                    key: const ValueKey('ts-cust-note-save'),
                  ),
                ),
                const SizedBox(height: 18),
                Text(ctx.m('theirOrders'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                if (objs(d['orders']).isEmpty)
                  Muted(ctx.m('noOrders'))
                else
                  for (final o in objs(d['orders']))
                    TsOrderRow(
                      ctx: ctx,
                      o: o,
                      hideWho: true,
                      onTap: () => showTsOrder(context, ctx, o, onChanged: _load),
                    ),
              ],
      ),
    );
  }
}
