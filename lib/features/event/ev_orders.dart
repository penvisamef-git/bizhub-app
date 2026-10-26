import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show scanBarcode;
import '../restaurant/rest_common.dart' show SelectField;
import 'ev_common.dart';

// ======================================== Orders (OrdersTab in EvTabs.jsx) ========================================
const _ostatus = ['review', 'pending', 'paid', 'rejected', 'expired', 'cancelled'];

class OrdersTab extends StatefulWidget {
  final EvCtx ctx;
  const OrdersTab({super.key, required this.ctx});
  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  EvCtx get ctx => widget.ctx;
  late String _event = ctx.event;
  late String _status = ctx.status.isNotEmpty ? ctx.status : (n(ctx.data['waiting']) > 0 ? 'review' : '');
  final _q = TextEditingController();
  Timer? _deb;
  List<Json>? _rows;
  Json _summary = {};
  int _page = 1, _pages = 1;
  bool _more = false;
  String _busy = '';

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

  Future<void> _load({bool next = false}) async {
    if (next) setState(() => _more = true);
    try {
      final r = await ctx.api.get('${ctx.base}/orders', {'event': _event, 'status': _status, 'q': _q.text.trim(), 'page': next ? _page + 1 : 1});
      if (!mounted) return;
      final pg = obj(r['pagination']);
      setState(() {
        final rows = objs(r['data']);
        _rows = next ? [...?_rows, ...rows] : rows;
        _summary = obj(r['summary']);
        _page = n(pg['currentPage']).toInt().clamp(1, 99999);
        _pages = n(pg['totalPages']).toInt();
      });
    } catch (e) {
      ctx.fail(e);
      if (mounted && _rows == null) setState(() => _rows = []);
    } finally {
      if (mounted) setState(() => _more = false);
    }
  }

  Future<void> _act(Json o, String kind) async {
    String? reason;
    if (kind == 'reject') {
      reason = await askText(context, title: ctx.m('rejectWhy'), hint: ctx.m('rejectPh'), ok: ctx.m('reject'), cancel: ctx.m('cancel'));
      if (reason == null) return;
    }
    if (kind == 'cancel') {
      if (!mounted || !await askSure(context, ctx.m('cancelWhy'), ok: ctx.m('cancelOrder'), cancel: ctx.m('cancel'), danger: true)) return;
    }
    setState(() => _busy = '${o['_id']}$kind');
    final r = await ctx.run(
      () => ctx.api.post('${ctx.base}/orders/${o['_id']}/$kind', {'reason': reason ?? ''}),
      kind == 'approve' ? ctx.m('approved', {'n': o['qty']}) : (kind == 'reject' ? ctx.m('rejected') : ctx.m('saved')),
    );
    if (!mounted) return;
    setState(() => _busy = '');
    if (r != null) {
      await _load();
      ctx.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final paid = obj(_summary['paid']);
    final totalN = _summary.values.fold<num>(0, (a, v) => a + n(obj(v)['n']));
    return EvList(
      onRefresh: () => _load(),
      children: [
        EvHead(ctx.m('ordersTitle'), sub: ctx.m('ordersSub')),
        EvEventPick(
          ctx: ctx,
          value: _event,
          all: true,
          onChanged: (v) => setState(() {
            _event = v;
            _rows = null;
            _load();
          }),
        ),
        const SizedBox(height: 10),
        EvStats([
          EvStat(ctx.m('ord.money'), usd2(paid['money']), sub: ctx.m('ord.paidOnly'), tone: Tone.good),
          EvStat(
            ctx.m('ostatus.review'),
            fmt(n(obj(_summary['review'])['n'])),
            tone: n(obj(_summary['review'])['n']) > 0 ? Tone.warn : null,
            onTap: () => setState(() {
              _status = 'review';
              _load();
            }),
          ),
          EvStat(ctx.m('ostatus.paid'), fmt(n(paid['n'])), sub: ctx.m('ord.tickets', {'n': fmt(n(paid['tickets']))})),
          EvStat(ctx.m('ostatus.pending'), fmt(n(obj(_summary['pending'])['n']))),
        ]),
        const SizedBox(height: 10),
        Field(
          controller: _q,
          hint: ctx.m('search'),
          icon: LucideIcons.search,
          onChanged: (_) {
            _deb?.cancel();
            _deb = Timer(const Duration(milliseconds: 350), _load);
          },
        ),
        const SizedBox(height: 10),
        EvChips(
          items: [('', ctx.m('all'), totalN), for (final s in _ostatus) (s, ctx.m('ostatus.$s'), n(obj(_summary[s])['n']))],
          value: _status,
          onPick: (v) => setState(() {
            _status = v;
            _load();
          }),
        ),
        const SizedBox(height: 10),
        if (_rows == null)
          const SkelList(rows: 4)
        else if (_rows!.isEmpty)
          Panel(child: Muted(ctx.m('noOrders'), align: TextAlign.center))
        else ...[
          for (final o in _rows!) _card(o, c),
          if (_page < _pages) Btn(ctx.m('ord.loadMore'), kind: BtnKind.ghost, icon: LucideIcons.chevronDown, busy: _more, onTap: () => _load(next: true)),
        ],
      ],
    );
  }

  Widget _card(Json o, C c) {
    final st = str(o['status']);
    final ev = obj(o['event']);
    final proof = str(o['proof']);
    final lines = objs(o['lines']).map((l) => '${l['qty']} × ${l['name']}').join(', ');
    final via = str(o['via']);
    final waits = ['review', 'pending', 'expired'].contains(st);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (proof.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => Dialog(
                        child: InteractiveViewer(child: Image(image: netImage(proof))),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image(image: netImage(proof), width: 64, height: 80, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('#${o['no']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(width: 8),
                          Chip2(ctx.m('ostatus.$st'), tone: orderTone(st)),
                          if (via != 'online') ...[const SizedBox(width: 6), Chip2(via == 'gate' ? ctx.m('viaGate') : ctx.m('viaInvite'))],
                          const Spacer(),
                          Text(n(o['total']) > 0 ? usd2(o['total']) : ctx.p('free'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(str(obj(o['buyer'])['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                      GestureDetector(
                        onTap: () => launchUrl(Uri.parse('tel:${obj(o['buyer'])['phone']}')),
                        child: Text(str(obj(o['buyer'])['phone']), style: TextStyle(color: c.brand, fontSize: 13)),
                      ),
                      Text(lines, style: TextStyle(fontSize: 13, color: c.muted)),
                      if (_event.isEmpty && ev.isNotEmpty)
                        Text(
                          str(ev['title']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: c.muted),
                        ),
                      if (obj(o['promo'])['code'] != null) Text('${ctx.m('more.promo')} ${obj(o['promo'])['code']} −${usd2(obj(o['promo'])['off'])}', style: TextStyle(fontSize: 12, color: c.good)),
                      if (n(o['bundle_off']) > 0) Text('${ctx.p('bundleOff')} −${usd2(o['bundle_off'])}', style: TextStyle(fontSize: 12, color: c.good)),
                      if (str(o['pay_label']).isNotEmpty) Text(ctx.m('pm.paidWith', {'m': o['pay_label']}), style: TextStyle(fontSize: 12, color: c.muted)),
                      if (str(o['reference']).isNotEmpty) Text('${ctx.m('ref')}: ${o['reference']}', style: TextStyle(fontSize: 12, color: c.muted)),
                      if (str(o['ref']).isNotEmpty) Text('${ctx.m('tabs.promoters')}: ${o['ref']}', style: TextStyle(fontSize: 12, color: c.muted)),
                      if (str(o['note']).isNotEmpty)
                        Text(
                          '“${o['note']}”',
                          style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: c.muted),
                        ),
                      if (str(o['reason']).isNotEmpty) Text(str(o['reason']), style: TextStyle(fontSize: 12.5, color: c.danger)),
                      for (final a in objs(o['answers'])) Text('${a['label']}: ${a['value']}', style: TextStyle(fontSize: 12, color: c.muted)),
                      Text(evWhen(o['created_date'], ctx.lang), style: TextStyle(fontSize: 11.5, color: c.muted)),
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
                if (waits) Btn(ctx.m('approve'), icon: LucideIcons.check, small: true, busy: _busy == '${o['_id']}approve', onTap: ctx.readOnly || _busy.isNotEmpty ? null : () => _act(o, 'approve')),
                if (['review', 'pending'].contains(st))
                  Btn(ctx.m('reject'), icon: LucideIcons.x, small: true, kind: BtnKind.danger, onTap: ctx.readOnly || _busy.isNotEmpty ? null : () => _act(o, 'reject')),
                if (st == 'paid') Btn(ctx.m('cancelOrder'), icon: LucideIcons.ban, small: true, kind: BtnKind.ghost, onTap: ctx.readOnly || _busy.isNotEmpty ? null : () => _act(o, 'cancel')),
                Btn(
                  ctx.m('buyerLink'),
                  icon: LucideIcons.externalLink,
                  small: true,
                  kind: BtnKind.ghost,
                  onTap: () => launchUrl(Uri.parse(orderUrl(o['token'])), mode: LaunchMode.externalApplication),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================== Guests & check-in (GuestsTab in EvTabs.jsx) ========================================
class GuestsTab extends StatefulWidget {
  final EvCtx ctx;
  const GuestsTab({super.key, required this.ctx});
  @override
  State<GuestsTab> createState() => _GuestsTabState();
}

class _GuestsTabState extends State<GuestsTab> {
  EvCtx get ctx => widget.ctx;
  late String _event = ctx.firstEvent();
  String _status = '';
  final _q = TextEditingController();
  Timer? _deb;
  List<Json>? _rows;
  int _total = 0, _page = 1, _pages = 1;
  String _busy = '';

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

  Future<void> _load({bool next = false}) async {
    if (_event.isEmpty) return setState(() => _rows = []);
    try {
      final r = await ctx.api.get('${ctx.base}/events/$_event/tickets', {'status': _status, 'q': _q.text.trim(), 'page': next ? _page + 1 : 1});
      if (!mounted) return;
      final pg = obj(r['pagination']);
      setState(() {
        _rows = next ? [...?_rows, ...objs(r['data'])] : objs(r['data']);
        _total = n(pg['total']).toInt();
        _page = n(pg['currentPage']).toInt().clamp(1, 99999);
        _pages = n(pg['totalPages']).toInt();
      });
    } catch (e) {
      ctx.fail(e);
      if (mounted && _rows == null) setState(() => _rows = []);
    }
  }

  Future<bool> _act(Json t, String kind) async {
    if (kind == 'cancel' && !await askSure(context, ctx.m('cancelTicketSure'), ok: ctx.m('cancelTicket'), cancel: ctx.m('cancel'), danger: true)) return false;
    if (!mounted) return false;
    Json body = {};
    if (kind == 'transfer') {
      final name = await askText(context, title: ctx.m('grow.giveName'), ok: ctx.m('grow.give'), cancel: ctx.m('cancel'));
      if (name == null || name.trim().isEmpty || !mounted) return false;
      final phone = await askText(context, title: ctx.m('grow.givePhone'), keyboard: TextInputType.phone, ok: ctx.m('save'), cancel: ctx.m('cancel'));
      body = {'name': name.trim(), 'phone': phone ?? ''};
    }
    setState(() => _busy = '${t['_id']}$kind');
    final path = kind == 'in' ? 'checkin' : kind;
    final r = await ctx.run(() => ctx.api.post('${ctx.base}/tickets/${t['_id']}/$path', body), kind == 'transfer' ? ctx.m('grow.giveDone') : null);
    if (!mounted) return false;
    setState(() => _busy = '');
    if (r != null) await _load();
    return r != null;
  }

  // scan a ticket QR (…/ev/t/<code>) → check in
  Future<void> _scan() async {
    final raw = await scanBarcode(context, ctx.t);
    if (raw == null || !mounted) return;
    final m = RegExp(r'/ev/t/([A-Za-z0-9]+)').firstMatch(raw);
    final code = (m?.group(1) ?? raw).toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    String text;
    Tone tone = Tone.danger;
    try {
      final r = await ctx.api.get('${ctx.base}/events/$_event/tickets', {'q': code});
      final t = objs(r['data']).where((x) => str(x['code']).toUpperCase() == code).firstOrNull;
      if (t == null) {
        text = ctx.a('scanNotFound');
      } else if (t['status'] == 'cancelled') {
        text = ctx.a('scanCancelled');
      } else if (t['status'] == 'used') {
        text = '${t['holder']} · ${ctx.a('scanAlready', {'t': evTime(t['used_at'])})}';
        tone = Tone.warn;
      } else {
        await ctx.api.post('${ctx.base}/tickets/${t['_id']}/checkin');
        text = '${ctx.a('scanIn', {'name': str(t['holder']).isEmpty ? code : t['holder']})}\n${t['type_name']}${str(t['seat_label']).isNotEmpty ? ' · ${t['seat_label']}' : ''}';
        tone = Tone.good;
      }
    } on ApiError catch (e) {
      text = e.network ? ctx.t('app.offline') : e.message;
    }
    if (!mounted) return;
    _load();
    final again = await showDialog<bool>(
      context: context,
      builder: (d) {
        final c = d.c;
        final col = tone == Tone.good ? c.good : (tone == Tone.warn ? c.warn : c.danger);
        return AlertDialog(
          icon: Icon(tone == Tone.good ? LucideIcons.circleCheck : (tone == Tone.warn ? LucideIcons.triangleAlert : LucideIcons.circleX), size: 48, color: col),
          content: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: Text(ctx.m('close'))),
            FilledButton.icon(onPressed: () => Navigator.pop(d, true), icon: const Icon(LucideIcons.scanLine, size: 16), label: Text(ctx.a('scanAgain'))),
          ],
        );
      },
    );
    if (again == true && mounted) _scan();
  }

  Future<void> _invite() async {
    final ev = ctx.eventById(_event);
    if (ev == null) return;
    final done = await showModalBottomSheet<Json>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _InviteSheet(ctx: ctx, ev: ev),
    );
    if (done == null || !mounted) return;
    final link = orderUrl(obj(done['order'])['token']);
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(ctx.m('inviteDone')),
        content: SelectableText(link),
        actions: [
          TextButton(onPressed: () => evCopy(ctx, link), child: Text(ctx.m('copyLink'))),
          FilledButton(
            onPressed: () => SharePlus.instance.share(ShareParams(text: '${ev['title']}\n$link')),
            child: Text(ctx.a('share')),
          ),
        ],
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ev = ctx.eventById(_event);
    final k = obj(ev?['counts']);
    return EvList(
      onRefresh: () => _load(),
      children: [
        EvHead(ctx.m('guestsTitle'), sub: ctx.m('guestsSub')),
        EvEventPick(
          ctx: ctx,
          value: _event,
          onChanged: (v) => setState(() {
            _event = v;
            _rows = null;
            _load();
          }),
        ),
        if (ev != null) ...[
          const SizedBox(height: 10),
          EvStats([EvStat(ctx.m('ticketsSold'), fmt(n(k['tickets']))), EvStat(ctx.m('inside'), fmt(n(k['used'])), tone: Tone.good)]),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Btn(ctx.a('scan'), icon: LucideIcons.scanLine, onTap: ctx.readOnly ? null : _scan),
              ),
              const SizedBox(width: 8),
              ctx.on('ev_invites')
                  ? Btn(ctx.m('invite'), icon: LucideIcons.gift, kind: BtnKind.ghost, onTap: ctx.readOnly ? null : _invite)
                  : Btn(ctx.m('invite'), icon: LucideIcons.lock, kind: BtnKind.ghost, onTap: () => ctx.askBuy('ev_invites')),
            ],
          ),
          const SizedBox(height: 10),
          Field(
            controller: _q,
            hint: ctx.m('search'),
            icon: LucideIcons.search,
            onChanged: (_) {
              _deb?.cancel();
              _deb = Timer(const Duration(milliseconds: 350), _load);
            },
          ),
          const SizedBox(height: 10),
          EvChips(
            items: [('', ctx.m('all'), null), ('valid', ctx.m('tstatus.valid'), null), ('used', ctx.m('tstatus.used'), null), ('cancelled', ctx.m('tstatus.cancelled'), null)],
            value: _status,
            onPick: (v) => setState(() {
              _status = v;
              _load();
            }),
          ),
          const SizedBox(height: 6),
          Text(fmt(_total), style: TextStyle(fontSize: 12.5, color: c.muted)),
          const SizedBox(height: 6),
        ],
        if (ev == null)
          Panel(child: Muted(ctx.m('noEvents'), align: TextAlign.center))
        else if (_rows == null)
          const SkelList(rows: 5)
        else if (_rows!.isEmpty)
          Panel(child: Muted(ctx.m('noGuests'), align: TextAlign.center))
        else ...[
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(children: [for (final t in _rows!) _row(t, c)]),
          ),
          if (_page < _pages) ...[const SizedBox(height: 10), Btn(ctx.a('loadMore'), kind: BtnKind.ghost, icon: LucideIcons.chevronDown, onTap: () => _load(next: true))],
        ],
      ],
    );
  }

  Widget _row(Json t, C c) {
    final st = str(t['status']);
    final id = str(t['_id']);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          Icon(st == 'used' ? LucideIcons.userCheck : (st == 'cancelled' ? LucideIcons.userX : LucideIcons.user), size: 20, color: st == 'used' ? c.good : (st == 'cancelled' ? c.danger : c.muted)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  str(t['holder']).isEmpty ? '—' : str(t['holder']),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${t['type_name']}${str(t['seat_label']).isNotEmpty ? ' · ${t['seat_label']}' : ''} · #${t['order_no']}${str(t['phone']).isNotEmpty ? ' · ${t['phone']}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.muted),
                ),
                if (st == 'used') Text('${evTime(t['used_at'])}${str(t['used_by']).isNotEmpty ? ' · ${ctx.m('by', {'name': t['used_by']})}' : ''}', style: TextStyle(fontSize: 11.5, color: c.good)),
              ],
            ),
          ),
          if (st == 'valid') ...[
            Btn(ctx.m('checkin'), small: true, busy: _busy == '${id}in', onTap: ctx.readOnly || _busy.isNotEmpty ? null : () => _act(t, 'in')),
            IconButton(
              icon: Icon(LucideIcons.ellipsisVertical, size: 18, color: c.muted),
              onPressed: () async {
                final k = await evPickFrom(context, str(t['holder']), [('transfer', ctx.m('grow.give')), ('cancel', ctx.m('cancelTicket'))]);
                if (k != null) _act(t, k);
              },
            ),
          ] else if (st == 'used')
            TextButton.icon(onPressed: ctx.readOnly || _busy.isNotEmpty ? null : () => _act(t, 'undo'), icon: const Icon(LucideIcons.rotateCcw, size: 14), label: Text(ctx.m('undo')))
          else
            Chip2(ctx.m('tstatus.cancelled'), tone: Tone.danger),
        ],
      ),
    );
  }
}

class _InviteSheet extends StatefulWidget {
  final EvCtx ctx;
  final Json ev;
  const _InviteSheet({required this.ctx, required this.ev});
  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _name = TextEditingController(), _phone = TextEditingController(), _qty = TextEditingController(text: '1');
  late String _type = str(objs(widget.ev['types']).firstOrNull?['key']);
  bool _busy = false;
  String _err = '';
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _qty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(ctx.m('inviteTitle'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Field(label: ctx.m('inviteName'), controller: _name, maxLength: 80, onChanged: (_) => setState(() {})),
          const SizedBox(height: 10),
          Field(label: ctx.m('invitePhone'), controller: _phone, keyboard: TextInputType.phone),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SelectField<String>(
                  label: ctx.m('inviteType'),
                  value: _type,
                  options: [for (final t in objs(widget.ev['types'])) (str(t['key']), str(t['name']))],
                  onChanged: (v) => setState(() => _type = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Field(label: ctx.m('inviteQty'), controller: _qty, keyboard: TextInputType.number),
              ),
            ],
          ),
          if (_err.isNotEmpty) ...[const SizedBox(height: 10), Alert(_err)],
          const SizedBox(height: 14),
          Btn(
            ctx.m('invite'),
            icon: LucideIcons.gift,
            busy: _busy,
            expand: true,
            onTap: _name.text.trim().isEmpty || _type.isEmpty
                ? null
                : () async {
                    setState(() {
                      _busy = true;
                      _err = '';
                    });
                    try {
                      final r = await ctx.api.post('${ctx.base}/events/${widget.ev['_id']}/invites', {
                        'name': _name.text.trim(),
                        'phone': _phone.text.trim(),
                        'key': _type,
                        'qty': int.tryParse(_qty.text) ?? 1,
                      });
                      if (context.mounted) Navigator.pop(context, obj(r['data']));
                    } on ApiError catch (e) {
                      setState(() => _err = e.message);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
          ),
        ],
      ),
    );
  }
}

// ======================================== Refunds & transfers (RequestsTab in EvGrow.jsx) ========================================
class RequestsTab extends StatefulWidget {
  final EvCtx ctx;
  const RequestsTab({super.key, required this.ctx});
  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  EvCtx get ctx => widget.ctx;
  String _status = 'open';
  List<Json>? _rows;
  String _busy = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/requests', {'status': _status});
      if (mounted) setState(() => _rows = objs(r['data']));
    } catch (e) {
      ctx.fail(e);
      if (mounted) setState(() => _rows = []);
    }
  }

  Future<void> _decide(Json row, bool ok) async {
    final q = obj(row['request']);
    final body = <String, Object?>{'ok': ok};
    if (ok && q['kind'] == 'refund') {
      final sum = objs(row['tickets']).fold<num>(0, (a, t) => a + n(t['price']));
      final v = await askText(
        context,
        title: ctx.m('grow.rqAmount'),
        initial: '$sum',
        keyboard: const TextInputType.numberWithOptions(decimal: true),
        ok: ctx.m('grow.rqRefund'),
        cancel: ctx.m('cancel'),
      );
      if (v == null) return;
      body['amount'] = num.tryParse(v.trim()) ?? 0;
    } else if (!ok) {
      final v = await askText(context, title: ctx.m('grow.rqWhy'), ok: ctx.m('grow.rqDecline'), cancel: ctx.m('cancel'));
      if (v == null) return;
      body['reply'] = v;
    } else if (!await askSure(context, ctx.m('grow.rqTransferSure', {'name': q['to_name']}), ok: ctx.m('grow.rqTransfer'), cancel: ctx.m('cancel'))) {
      return;
    }
    setState(() => _busy = str(q['_id']));
    final r = await ctx.run(() => ctx.api.post('${ctx.base}/orders/${obj(row['order'])['_id']}/requests/${q['_id']}', body), ctx.m('grow.rqDone'));
    if (!mounted) return;
    setState(() => _busy = '');
    if (r != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return EvList(
      onRefresh: _load,
      children: [
        EvHead(ctx.m('grow.rqTitle'), sub: ctx.m('grow.rqSub')),
        EvChips(
          items: [
            for (final s in ['open', 'done', 'declined']) (s, ctx.m('grow.rqStatus.$s'), null),
          ],
          value: _status,
          onPick: (v) => setState(() {
            _status = v;
            _rows = null;
            _load();
          }),
        ),
        const SizedBox(height: 10),
        if (_rows == null)
          const SkelList(rows: 3)
        else if (_rows!.isEmpty)
          Panel(child: Muted(ctx.m('grow.rqNone'), align: TextAlign.center))
        else
          for (final row in _rows!)
            Builder(
              builder: (_) {
                final q = obj(row['request']);
                final o = obj(row['order']);
                final refund = q['kind'] == 'refund';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Chip2(ctx.m('grow.rqKind.${q['kind']}'), icon: refund ? LucideIcons.undo2 : LucideIcons.repeat, tone: refund ? Tone.warn : Tone.good),
                            const SizedBox(width: 8),
                            Text('#${o['no']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                str(obj(row['event'])['title']),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5, color: c.muted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('${ctx.m('grow.rqBuyer')}: ${obj(o['buyer'])['name']} · ${obj(o['buyer'])['phone']}', style: const TextStyle(fontSize: 13.5)),
                        for (final t in objs(row['tickets']))
                          Text('• ${t['type_name']} · ${t['holder']}${n(t['price']) > 0 ? ' · ${usd2(t['price'])}' : ''}', style: TextStyle(fontSize: 13, color: c.muted)),
                        if (!refund) Text('${ctx.m('grow.rqTo')}: ${q['to_name']} ${q['to_phone'] ?? ''}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                        if (str(q['note']).isNotEmpty)
                          Text(
                            '“${q['note']}”',
                            style: TextStyle(fontStyle: FontStyle.italic, color: c.muted),
                          ),
                        Text(evWhen(q['at'], ctx.lang), style: TextStyle(fontSize: 11.5, color: c.muted)),
                        const SizedBox(height: 8),
                        if (q['status'] == 'open')
                          Row(
                            children: [
                              Btn(
                                refund ? ctx.m('grow.rqRefund') : ctx.m('grow.rqTransfer'),
                                icon: LucideIcons.check,
                                small: true,
                                busy: _busy == str(q['_id']),
                                onTap: ctx.readOnly || _busy.isNotEmpty ? null : () => _decide(row, true),
                              ),
                              const SizedBox(width: 8),
                              Btn(ctx.m('grow.rqDecline'), icon: LucideIcons.x, small: true, kind: BtnKind.ghost, onTap: ctx.readOnly || _busy.isNotEmpty ? null : () => _decide(row, false)),
                            ],
                          )
                        else
                          Muted(
                            '${ctx.m('grow.rqStatus.${q['status']}')} · ${q['decided_by'] ?? ''}${str(q['reply']).isNotEmpty ? ' · “${q['reply']}”' : ''}${refund && n(o['refunded']) > 0 ? ' · ${usd2(o['refunded'])}' : ''}',
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
      ],
    );
  }
}
