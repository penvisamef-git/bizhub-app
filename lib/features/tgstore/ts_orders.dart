import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../event/ev_common.dart' show EvChips, evPickFrom;
import '../mart/mart_common.dart' show GoldBtn;
import 'ts_common.dart';

// Orders: the live board (open orders, refreshed every 12 s) + all orders with search and filters (TsOrders.jsx)

// move an order on (shared by the live board, the history and a customer's orders)
Future<Json?> tsOrderAct(TsCtx ctx, Json o, String status, [Json extra = const {}]) => ctx.run(() {
  final id = o['_id'];
  if (status == 'paid') return ctx.api.post('${ctx.base}/orders/$id/paid');
  if (status == 'riders') return ctx.api.post('${ctx.base}/orders/$id/riders');
  return ctx.api.post('${ctx.base}/orders/$id/status', {'status': status, ...extra});
}, status == 'riders' ? ctx.m('ridersSent') : null);

bool tsRidersOn(TsCtx ctx) => ctx.on('ts_riders') && ctx.riders['connected'] == true;

// one order in a sheet (from the history or a customer)
Future<void> showTsOrder(BuildContext context, TsCtx ctx, Json order, {VoidCallback? onChanged}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _OrderSheet(ctx: ctx, order: order, onChanged: onChanged),
);

class _OrderSheet extends StatefulWidget {
  final TsCtx ctx;
  final Json order;
  final VoidCallback? onChanged;
  const _OrderSheet({required this.ctx, required this.order, this.onChanged});
  @override
  State<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<_OrderSheet> {
  late Json _o = widget.order;
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .85,
      maxChildSize: .95,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(ctx.m('orderTitle', {'n': _o['no']}), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TsOrderCard(
            o: _o,
            t: ctx.t,
            readOnly: ctx.readOnly,
            ridersOn: tsRidersOn(ctx),
            busy: _busy,
            act: (o, status, [extra = const {}]) async {
              setState(() => _busy = true);
              final r = await tsOrderAct(ctx, o, status, extra);
              if (!mounted) return;
              setState(() {
                _busy = false;
                if (r != null && r['data'] is Map) _o = obj(r['data']);
              });
              widget.onChanged?.call();
            },
          ),
        ],
      ),
    );
  }
}

class OrdersTab extends StatefulWidget {
  final TsCtx ctx;
  const OrdersTab({super.key, required this.ctx});
  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  String _view = 'live';
  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final fresh = n(ctx.counts['new']).toInt();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: EvChips(
            items: [('live', ctx.m('live'), fresh > 0 ? fresh : null), ('history', ctx.m('history'), null)],
            value: _view,
            onPick: (v) => setState(() => _view = v),
          ),
        ),
        Expanded(child: _view == 'live' ? _Live(ctx: ctx) : _History(ctx: ctx)),
      ],
    );
  }
}

class _Live extends StatefulWidget {
  final TsCtx ctx;
  const _Live({required this.ctx});
  @override
  State<_Live> createState() => _LiveState();
}

class _LiveState extends State<_Live> {
  List<Json>? _rows;
  String _error = '';
  String _busy = '';
  Timer? _timer;
  TsCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/orders', {'status': 'open'});
      if (!mounted) return;
      setState(() {
        _rows = objs(r['data']);
        _error = '';
      });
      if (r['counts'] is Map) ctx.put({'counts': {...ctx.counts, ...obj(r['counts'])}});
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.network ? ctx.t('app.offline') : e.message);
    }
  }

  Future<void> _act(Json o, String status, [Json extra = const {}]) async {
    setState(() => _busy = str(o['_id']));
    await tsOrderAct(ctx, o, status, extra);
    await _load();
    if (mounted) setState(() => _busy = '');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final k = ctx.counts;
    final noProducts = n(k['products']) == 0;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + MediaQuery.of(context).padding.bottom),
        children: [
          TsKpis([
            TsKpi(ctx.m('todayOrders'), fmt(n(k['today_orders']))),
            TsKpi(ctx.m('todaySales'), ctx.money(k['today_total'])),
            TsKpi(ctx.m('openOrders'), fmt(n(k['open']))),
            TsKpi(ctx.m('waiting'), fmt(n(k['new'])), hot: n(k['new']) > 0),
          ]),
          const SizedBox(height: 14),
          if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Alert(_error)),
          if (_rows == null)
            const SkelList(rows: 2)
          else if (_rows!.isEmpty)
            Panel(
              child: Column(
                children: [
                  Icon(LucideIcons.receiptText, size: 30, color: c.muted),
                  const SizedBox(height: 8),
                  Muted(ctx.m('noOpen'), align: TextAlign.center),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (noProducts) Btn(ctx.m('addFirst'), icon: LucideIcons.plus, small: true, onTap: () => ctx.go('products')),
                      Btn(ctx.m('shareStore'), icon: LucideIcons.share2, small: true, kind: noProducts ? BtnKind.ghost : BtnKind.primary, onTap: () => ctx.go('share')),
                    ],
                  ),
                ],
              ),
            )
          else
            for (final o in _rows!) TsOrderCard(o: o, t: ctx.t, readOnly: ctx.readOnly, ridersOn: tsRidersOn(ctx), busy: _busy == str(o['_id']), act: _act),
        ],
      ),
    );
  }
}

class _History extends StatefulWidget {
  final TsCtx ctx;
  const _History({required this.ctx});
  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  final _q = TextEditingController();
  String _status = '', _mode = '', _pay = '', _paid = '';
  DateTime? _from, _to;
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
    final r = await ctx.run(
      () => ctx.api.get('${ctx.base}/orders', {
        'status': _status.isEmpty ? 'all' : _status,
        if (_q.text.trim().isNotEmpty) 'q': _q.text.trim(),
        if (_mode.isNotEmpty) 'mode': _mode,
        if (_pay.isNotEmpty) 'pay': _pay,
        if (_paid.isNotEmpty) 'paid': _paid,
        if (_from != null) 'from': tsYmd(_from!),
        if (_to != null) 'to': tsYmd(_to!),
        'page': _page,
      }),
    );
    if (mounted && r != null) setState(() => _r = r);
  }

  void _set(VoidCallback f) {
    setState(() {
      f();
      _page = 1;
    });
    _load();
  }

  Future<void> _pick(String title, String value, List<(String, String)> options, String all, ValueChanged<String> set) async {
    final v = await evPickFrom(context, title, [('', all), ...options], value: value);
    if (v != null) _set(() => set(v));
  }

  Future<void> _date(bool from) async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: (from ? _from : _to) ?? now, firstDate: DateTime(2024), lastDate: now.add(const Duration(days: 1)));
    if (d != null) _set(() => from ? _from = d : _to = d);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = _r;
    final h = obj(r?['history']);
    final pg = obj(r?['pagination']);
    final pages = r == null ? 1 : (n(pg['total']) / (n(pg['limit']) == 0 ? 30 : n(pg['limit']))).ceil().clamp(1, 9999);
    final rows = objs(r?['data']);
    final filtered = [_status, _mode, _pay, _paid].any((x) => x.isNotEmpty) || _from != null || _to != null || _q.text.trim().isNotEmpty;
    Widget chip(String label, bool on, VoidCallback tap, {IconData icon = LucideIcons.chevronDown}) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: on ? c.brandInk : c.ink)),
        avatar: Icon(icon, size: 14, color: on ? c.brandInk : c.muted),
        backgroundColor: on ? c.active : c.chip,
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
        onPressed: tap,
      ),
    );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + MediaQuery.of(context).padding.bottom),
        children: [
          if (r != null && h['all'] != true)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.warnBg, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Icon(LucideIcons.lock, size: 15, color: c.warn),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${ctx.m('historyLimited', {'n': h['days']})} ${n(h['hidden']) > 0 ? ctx.m('historyHidden', {'n': fmt(n(h['hidden']))}) : ''}',
                      style: TextStyle(color: c.warn, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GoldBtn('${ctx.m('historyAll')} · ${fmt(n(ctx.addon('ts_history')['price']))}', onTap: ctx.readOnly ? null : () => ctx.askBuy('ts_history')),
                ],
              ),
            ),
          Field(
            controller: _q,
            hint: ctx.m('searchOrders'),
            icon: LucideIcons.search,
            onChanged: (_) {
              _deb?.cancel();
              _deb = Timer(const Duration(milliseconds: 350), () => _set(() {}));
            },
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                chip(_status.isEmpty ? ctx.m('allStatus') : ctx.m('statuses.$_status'), _status.isNotEmpty, () => _pick(ctx.m('cols.status'), _status, [for (final s in ['new', 'accepted', 'ready', 'on_way', 'done', 'cancelled']) (s, ctx.m('statuses.$s'))], ctx.m('allStatus'), (v) => _status = v)),
                chip(_mode.isEmpty ? ctx.m('allModes') : ctx.m('modes.$_mode'), _mode.isNotEmpty, () => _pick(ctx.m('cols.how'), _mode, [for (final s in ['delivery', 'pickup', 'dine_in']) (s, ctx.m('modes.$s'))], ctx.m('allModes'), (v) => _mode = v)),
                chip(
                  _pay.isEmpty ? ctx.m('allPay') : (_pay == 'custom' ? ctx.m('ownPay') : ctx.m('payMethods.$_pay')),
                  _pay.isNotEmpty,
                  () => _pick(ctx.m('cols.pay'), _pay, [('khqr', 'KHQR'), ('cash', ctx.m('payMethods.cash')), ('custom', ctx.m('ownPay'))], ctx.m('allPay'), (v) => _pay = v),
                ),
                chip(
                  _paid.isEmpty ? '${ctx.m('paidYes')} / ${ctx.m('paidNo')}' : (_paid == 'yes' ? ctx.m('paidYes') : ctx.m('paidNo')),
                  _paid.isNotEmpty,
                  () => _pick(ctx.m('cols.pay'), _paid, [('yes', ctx.m('paidYes')), ('no', ctx.m('paidNo'))], '${ctx.m('paidYes')} / ${ctx.m('paidNo')}', (v) => _paid = v),
                ),
                chip(_from == null ? ctx.m('fromDate') : '${ctx.m('fromDate')} ${tsDay(_from!.toIso8601String(), ctx.lang)}', _from != null, () => _date(true), icon: LucideIcons.calendar),
                chip(_to == null ? ctx.m('toDate') : '${ctx.m('toDate')} ${tsDay(_to!.toIso8601String(), ctx.lang)}', _to != null, () => _date(false), icon: LucideIcons.calendar),
                if (filtered)
                  chip(ctx.m('clear'), false, () {
                    _q.clear();
                    _set(() {
                      _status = _mode = _pay = _paid = '';
                      _from = _to = null;
                    });
                  }, icon: LucideIcons.x),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (r == null)
            const SkelList(rows: 4)
          else if (rows.isEmpty)
            Panel(
              child: Column(children: [Icon(LucideIcons.history, size: 28, color: c.muted), const SizedBox(height: 8), Muted(ctx.m('noOrders'), align: TextAlign.center)]),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 2),
              child: Text(ctx.m('foundN', {'n': fmt(n(pg['total'])), 'total': ctx.money(r['sum'])}), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            for (final o in rows) TsOrderRow(ctx: ctx, o: o, onTap: () => showTsOrder(context, ctx, o, onChanged: _load)),
            if (pages > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Btn(ctx.m('prev'), icon: LucideIcons.chevronLeft, small: true, kind: BtnKind.ghost, onTap: _page <= 1 ? null : () {
                        setState(() => _page--);
                        _load();
                      }),
                    const SizedBox(width: 12),
                    Text(ctx.m('pageOf', {'p': _page, 'n': pages})),
                    const SizedBox(width: 12),
                    Btn(ctx.m('next'), small: true, kind: BtnKind.ghost, onTap: _page >= pages ? null : () {
                        setState(() => _page++);
                        _load();
                      }),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// one order in a list (a table row on the web)
class TsOrderRow extends StatelessWidget {
  final TsCtx ctx;
  final Json o;
  final VoidCallback onTap;
  final bool hideWho;
  const TsOrderRow({super.key, required this.ctx, required this.o, required this.onTap, this.hideWho = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pay = obj(o['pay']);
    final status = str(o['status']);
    final who = obj(o['customer']);
    final items = objs(o['items']).map((l) => '${fmt(n(l['qty']))}× ${l['name']}').join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: c.line)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 46, child: Text('#${o['no']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!hideWho) Text(str(who['name']).isNotEmpty ? str(who['name']) : (str(who['phone']).isNotEmpty ? str(who['phone']) : '—'), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(items, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 13)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          TsPill(ctx.m('statuses.$status'), tone: tsStatusTone(status)),
                          TsPill(ctx.m('modes.${o['mode']}'), icon: tsModeIcons[o['mode']]),
                          TsPill(ctx.m('payStates.${pay['status']}'), tone: pay['status'] == 'paid' ? Tone.good : Tone.muted),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(tsMoney(o['total'], str(o['currency'])), style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${tsDay(o['created_date'], ctx.lang)} · ${tsTime(o['created_date'])}', style: TextStyle(fontSize: 11.5, color: c.muted)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
