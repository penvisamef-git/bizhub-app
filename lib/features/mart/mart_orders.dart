import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/color_pick.dart';
import '../../widgets/ui.dart';
import '../restaurant/rest_common.dart' show Segmented, SelectField, SwitchRow, gap14;
import 'mart_common.dart';
import 'mart_kit.dart';

// Online orders (mart_shop) + Delivery (mart_delivery) — MartOrders.jsx, MartCustomer.jsx, MartDelivery.jsx.
//   GET mart/shop → { addon, website, site{slug,published}, themes, settings, has_qr, qr, sound, counts }      PUT mart/shop {…}
//   GET mart/orders {status}      POST mart/orders/:oid/accept|ready|done|decline {reason}      GET mart/customers {q}      GET mart/customers/:cid
//   GET mart/delivery → { zones, drivers }      PUT mart/delivery/zones {zones}      CRUD mart/drivers      POST mart/orders/:oid/driver {driver_id}

const _open = ['new', 'accepted', 'ready', 'delivering'];
const _tone = {'new': 'warn', 'accepted': 'info', 'ready': 'ok', 'delivering': 'info', 'done': '', 'declined': 'bad', 'cancelled': ''};
const _presets = ['#0F766E', '#0369A1', '#2563EB', '#4F46E5', '#7C3AED', '#BE185D', '#E11D48', '#DC2626', '#EA580C', '#D97706', '#65A30D', '#16A34A', '#334155', '#18181B'];

String _mapUrl(String m) => RegExp(r'^https?://', caseSensitive: false).hasMatch(m) ? m : 'https://maps.google.com/?q=${Uri.encodeComponent(m)}';

class OrdersTab extends StatefulWidget {
  final MartCtx ctx;
  final VoidCallback? onCount;
  const OrdersTab({super.key, required this.ctx, this.onCount});
  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  Json? _info;
  String _tab = 'orders';
  MartCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/shop');
      if (mounted) setState(() => _info = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final info = _info;
    if (info == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 5));
    final a = obj(info['addon']);
    if (a['active'] != true) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MHead(ctx.w('shopTitle'), icon: LucideIcons.shoppingBag, sub: info['website'] == true ? ctx.w('shopLocked') : ctx.w('needWebsite')),
                for (final p in ctx.t.list('mw.shopPerks'))
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
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: info['website'] == true
                      ? GoldBtn(ctx.w('unlockYear', {'coins': fmt(n(a['price'] ?? 75))}), onTap: ctx.readOnly ? null : () => ctx.askBuy('mart_shop', onDone: _load))
                      : Btn(ctx.w('goWebsite'), icon: LucideIcons.globe, small: true, onTap: () => ctx.go('website')),
                ),
              ],
            ),
          ),
        ],
      );
    }
    final s = obj(info['settings']);
    final site = obj(info['site']);
    final counts = obj(info['counts']);
    final url = str(site['slug']).isNotEmpty ? '${Config.siteUrl}/m/${site['slug']}/account' : '';
    final head = Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MHead(ctx.w('shopTitle'), icon: LucideIcons.shoppingBag, sub: a['expires_at'] != null ? ctx.w('until', {'date': mDate(a['expires_at'], ctx.lang)}) : null),
          SwitchRow(
            title: s['shop_on'] == true ? ctx.w('taking') : ctx.w('paused'),
            value: s['shop_on'] == true,
            onChanged: ctx.readOnly
                ? null
                : (v) async {
                    try {
                      final r = await ctx.api.put('${ctx.base}/shop', {'shop_on': v});
                      setState(() => _info = obj(r['data']));
                    } catch (e) {
                      ctx.fail(e);
                    }
                  },
          ),
          if (site['published'] != true || info['website'] != true) ...[const SizedBox(height: 8), Alert(ctx.w('notLive'))],
          if (url.isNotEmpty && site['published'] == true) ...[
            const SizedBox(height: 8),
            Text(
              url,
              style: TextStyle(color: c.brand, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Btn(
                  ctx.w('copy'),
                  icon: LucideIcons.copy,
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: url));
                    ctx.notify(ctx.w('copied'));
                  },
                ),
                Btn(
                  ctx.w('open'),
                  icon: LucideIcons.externalLink,
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                ),
              ],
            ),
          ],
          gap14,
          Tiles([
            ('${n(counts['new'])}', ctx.w('status.new'), n(counts['new']) > 0 ? c.warn : null),
            ('${n(counts['open'])}', ctx.w('inProgress'), null),
            ('${n(counts['customers'])}', ctx.w('customers'), null),
          ]),
        ],
      ),
    );
    final Widget body = switch (_tab) {
      'customers' => _Customers(key: const ValueKey('cu'), ctx: ctx),
      'rules' => _Rules(key: const ValueKey('rules'), ctx: ctx, info: info, setInfo: (v) => setState(() => _info = v)),
      'looks' => _PortalLooks(key: const ValueKey('looks'), ctx: ctx, info: info, setInfo: (v) => setState(() => _info = v), reload: _load),
      _ => OrdersList(
        key: const ValueKey('orders'),
        ctx: ctx,
        onChange: () {
          _load();
          widget.onCount?.call();
        },
      ),
    };
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          head,
          mGap,
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Segmented<String>(
              value: _tab,
              options: [
                for (final k in ['orders', 'customers', 'rules', 'looks']) (k, k == 'orders' && n(counts['new']) > 0 ? '${ctx.w('shopTabs.$k')} (${n(counts['new'])})' : ctx.w('shopTabs.$k')),
              ],
              onChanged: (v) => setState(() => _tab = v),
            ),
          ),
          mGap,
          body,
        ],
      ),
    );
  }
}

// the orders + their buttons
class OrdersList extends StatefulWidget {
  final MartCtx ctx;
  final VoidCallback? onChange;
  const OrdersList({super.key, required this.ctx, this.onChange});
  @override
  State<OrdersList> createState() => _OrdersListState();
}

class _OrdersListState extends State<OrdersList> {
  String _filter = 'open', _busy = '';
  List<Json>? _rows;
  Timer? _timer;
  MartCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/orders', {'status': _filter});
      if (mounted) setState(() => _rows = objs(r['data']));
    } catch (e) {
      if (mounted && _rows == null) ctx.fail(e);
    }
  }

  Future<void> _step(Json o, String k, [Json? body]) async {
    setState(() => _busy = '${o['_id']}:$k');
    try {
      await ctx.api.post('${ctx.base}/orders/${o['_id']}/$k', body ?? {});
      ctx.notify(ctx.w('stepDone.$k', {'no': o['no']}));
      await _load();
      widget.onChange?.call();
    } catch (e) {
      ctx.fail(e);
      _load();
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Future<void> _decline(Json o) async {
    final reason = await showSheet<String>(context, (_) => _DeclineSheet(ctx: ctx, order: o));
    if (reason != null) _step(o, 'decline', {'reason': reason});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final deliveryOn = ctx.addonOn('mart_delivery');
    return Panel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Segmented<String>(
              value: _filter,
              options: [
                for (final k in ['open', 'new', 'closed', 'all']) (k, ctx.w('filters.$k')),
              ],
              onChanged: (v) {
                setState(() {
                  _filter = v;
                  _rows = null;
                });
                _load();
              },
            ),
          ),
          const SizedBox(height: 10),
          if (_rows == null)
            const SkelList(rows: 3)
          else if (_rows!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(LucideIcons.shoppingBag, size: 30, color: c.muted),
                  const SizedBox(height: 8),
                  Muted(_filter == 'open' || _filter == 'new' ? ctx.w('noOpen') : ctx.w('noOrders'), align: TextAlign.center),
                ],
              ),
            )
          else
            for (final o in _rows!) _orderCard(context, o, deliveryOn),
        ],
      ),
    );
  }

  Widget _orderCard(BuildContext context, Json o, bool deliveryOn) {
    final c = context.c;
    final cur = str(o['currency']).isEmpty ? ctx.cur : str(o['currency']);
    final status = str(o['status']);
    final addr = obj(o['address']);
    Widget btn(String k, String label, {bool ghost = false}) => Btn(
      _busy == '${o['_id']}:$k' ? '…' : label,
      kind: ghost ? BtnKind.ghost : BtnKind.primary,
      small: true,
      onTap: ctx.readOnly || _busy.isNotEmpty ? null : () => k == 'decline' ? _decline(o) : _step(o, k),
    );
    Widget line(String a, String b, {bool bold = false, Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              a,
              style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: color),
            ),
          ),
          Text(
            b,
            style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color),
          ),
        ],
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: status == 'new' ? c.warn : c.line, width: status == 'new' ? 1.6 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(str(o['no']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(mDayTime(o['created_date'], ctx.lang), style: TextStyle(color: c.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              Pill(ctx.w('status.$status'), tone: _tone[status] ?? ''),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: o['customer_id'] == null ? null : () => showSheet<void>(context, (_) => _CustomerSheet(ctx: ctx, cid: str(o['customer_id']))),
                  child: Text(
                    str(o['name']),
                    style: TextStyle(fontWeight: FontWeight.w700, color: c.brand, decoration: TextDecoration.underline),
                  ),
                ),
              ),
              InkWell(
                onTap: () => launchUrl(Uri.parse('tel:${str(o['phone']).replaceAll(' ', '')}')),
                child: Row(
                  children: [
                    Icon(LucideIcons.phone, size: 13, color: c.muted),
                    const SizedBox(width: 4),
                    Text(
                      str(o['phone']),
                      style: TextStyle(color: c.muted, fontWeight: FontWeight.w600),
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
              Chip2(o['fulfil'] == 'delivery' ? ctx.w('delivery') : ctx.w('pickup'), icon: o['fulfil'] == 'delivery' ? LucideIcons.truck : LucideIcons.store),
              Chip2(o['pay_method'] == 'qr' ? ctx.w('paidQr') : ctx.w('cash'), icon: o['pay_method'] == 'qr' ? LucideIcons.qrCode : LucideIcons.banknote),
              if (str(o['sale_no']).isNotEmpty) Chip2(str(o['sale_no'])),
            ],
          ),
          if (o['fulfil'] == 'delivery' && str(addr['address']).isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.mapPin, size: 15, color: c.muted),
                const SizedBox(width: 6),
                Expanded(child: Text('${addr['address']}${str(addr['note']).isNotEmpty ? ' · ${addr['note']}' : ''}')),
                if (str(addr['map']).isNotEmpty)
                  InkWell(
                    onTap: () => launchUrl(Uri.parse(_mapUrl(str(addr['map']))), mode: LaunchMode.externalApplication),
                    child: Text(
                      ctx.w('map'),
                      style: TextStyle(color: c.brand, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Divider(height: 1, color: c.line),
          const SizedBox(height: 6),
          for (final x in objs(o['items']))
            line(
              '${qtyOf(x['qty'])}× ${x['name']}${str(ctx.lang == 'km' ? x['unit_km'] : x['unit_en']).isNotEmpty ? ' / ${ctx.lang == 'km' ? x['unit_km'] : x['unit_en']}' : ''}',
              money(x['total'], cur),
            ),
          for (final p in objs(o['promos'])) line('🏷 ${p['name']}${str(o['coupon']).isNotEmpty && p['code'] == o['coupon'] ? ' (${o['coupon']})' : ''}', '−${money(p['amount'], cur)}', color: c.good),
          if (n(o['points_value']) > 0) line('🎁 ${ctx.x('pointsOff')} (${qtyOf(o['points_used'])})', '−${money(o['points_value'], cur)}', color: c.good),
          if (n(o['delivery_fee']) > 0) line('${ctx.w('deliveryFee')}${str(o['zone_name']).isNotEmpty ? ' · ${o['zone_name']}' : ''}', money(o['delivery_fee'], cur)),
          const SizedBox(height: 4),
          line(ctx.w('total'), money(o['total'], cur), bold: true),
          if (o['fulfil'] == 'delivery' && deliveryOn && ['accepted', 'ready', 'delivering', 'done'].contains(status)) ...[const SizedBox(height: 8), OrderDriver(ctx: ctx, o: o)],
          if (o['fulfil'] == 'delivery' && !deliveryOn && str(o['driver_name']).isNotEmpty) ...[const SizedBox(height: 6), Muted('🛵 ${o['driver_name']}')],
          if (str(o['note']).isNotEmpty) ...[const SizedBox(height: 6), Text('“${o['note']}”', style: const TextStyle(fontStyle: FontStyle.italic))],
          if (str(o['reason']).isNotEmpty) ...[const SizedBox(height: 6), Text(str(o['reason']), style: TextStyle(color: c.danger))],
          if (str(o['proof']).isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => Dialog(
                  child: InteractiveViewer(child: Image(image: netImage(str(o['proof'])))),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image(image: netImage(str(o['proof'])), width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 48)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ctx.w('seeProof'),
                    style: TextStyle(color: c.brand, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
          if (_open.contains(status)) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (status == 'new') ...[btn('accept', ctx.w('accept')), btn('decline', ctx.w('decline'), ghost: true)],
                if (status == 'accepted') ...[btn('ready', o['fulfil'] == 'delivery' ? ctx.w('sendOut') : ctx.w('markReady')), btn('decline', ctx.w('cancelOrder'), ghost: true)],
                if (status == 'ready' || status == 'delivering') ...[
                  btn('done', o['pay_method'] == 'cash' ? ctx.w('doneCash', {'amt': money(o['total'], cur)}) : ctx.w('done')),
                  btn('decline', ctx.w('cancelOrder'), ghost: true),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DeclineSheet extends StatefulWidget {
  final MartCtx ctx;
  final Json order;
  const _DeclineSheet({required this.ctx, required this.order});
  @override
  State<_DeclineSheet> createState() => _DeclineSheetState();
}

class _DeclineSheetState extends State<_DeclineSheet> {
  final _reason = TextEditingController();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ctx = widget.ctx;
    final label = widget.order['status'] == 'new' ? ctx.w('decline') : ctx.w('cancelOrder');
    return MSheet(
      title: '$label · ${widget.order['no']}',
      footer: [
        const Spacer(),
        Btn(ctx.w('back'), kind: BtnKind.ghost, small: true, onTap: () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(label, small: true, onTap: () => Navigator.pop(context, _reason.text.trim())),
      ],
      children: [
        Muted(ctx.w('declineSub')),
        gap14,
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final q in ctx.t.list('mw.reasons'))
              ChoiceChip(
                label: Text(q),
                selected: _reason.text == q,
                showCheckmark: false,
                onSelected: (_) => setState(() => _reason.text = q),
                selectedColor: c.active,
                side: BorderSide(color: _reason.text == q ? c.brand : c.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Field(controller: _reason, hint: ctx.w('reasonPh'), maxLength: 200, maxLines: 2, onChanged: (_) => setState(() {})),
      ],
    );
  }
}

// one online customer
class _CustomerSheet extends StatefulWidget {
  final MartCtx ctx;
  final String cid;
  const _CustomerSheet({required this.ctx, required this.cid});
  @override
  State<_CustomerSheet> createState() => _CustomerSheetState();
}

class _CustomerSheetState extends State<_CustomerSheet> {
  Json? _data;
  String _error = '';
  @override
  void initState() {
    super.initState();
    final ctx = widget.ctx;
    ctx.api.get('${ctx.base}/customers/${widget.cid}').then((r) {
      if (mounted) setState(() => _data = obj(r['data']));
    }, onError: (e) => setState(() => _error = e is ApiError ? e.message : '$e'));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ctx = widget.ctx;
    final cu = obj(_data?['customer']);
    final st = obj(_data?['stats']);
    final cur = str(_data?['currency']).isEmpty ? ctx.cur : str(_data?['currency']);
    return MSheet(
      title: _data == null ? ctx.w('customer') : str(cu['name']),
      children: [
        if (_error.isNotEmpty)
          Alert(_error)
        else if (_data == null)
          const SkelList(rows: 4)
        else ...[
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: c.active,
                backgroundImage: str(cu['avatar']).isNotEmpty ? netImage(str(cu['avatar'])) : null,
                child: str(cu['avatar']).isEmpty
                    ? Text(
                        str(cu['name']).characters.take(1).toString().toUpperCase(),
                        style: TextStyle(fontWeight: FontWeight.w800, color: c.brandInk),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(str(cu['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        if (cu['blocked'] == true) ...[const SizedBox(width: 6), Pill(ctx.w('blocked'), tone: 'bad')],
                      ],
                    ),
                    Text([str(cu['phone']), str(cu['email'])].where((s) => s.isNotEmpty).join(' · '), style: TextStyle(color: c.muted, fontSize: 12.5)),
                    Text(
                      '${ctx.w('since', {'date': mDate(cu['created_date'], ctx.lang)})}${cu['last_login'] != null ? ' · ${ctx.w('lastSeen', {'date': mDayTime(cu['last_login'], ctx.lang)})}' : ''}',
                      style: TextStyle(color: c.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              RoundBtn(LucideIcons.phone, size: 38, onTap: () => launchUrl(Uri.parse('tel:${str(cu['phone']).replaceAll(' ', '')}'))),
            ],
          ),
          gap14,
          Tiles([
            ('${n(st['orders'])}', ctx.w('orders'), null),
            (money(st['spent'], cur), ctx.w('spent'), null),
            (money(st['avg'], cur), ctx.w('avgOrder'), null),
            ('${n(st['open'])}', ctx.w('inProgress'), null),
          ]),
          gap14,
          Text(ctx.w('howTheyBuy'), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Chip2('${ctx.w('delivery')} · ${n(st['delivery'])}', icon: LucideIcons.truck),
              Chip2('${ctx.w('pickup')} · ${n(st['pickup'])}', icon: LucideIcons.store),
              Chip2('${ctx.w('cash')} · ${n(st['cash'])}', icon: LucideIcons.banknote),
              Chip2('${ctx.w('qr')} · ${n(st['qr'])}', icon: LucideIcons.qrCode),
              if (st['first_order'] != null) Chip2('${ctx.w('firstOrder')} · ${mDate(st['first_order'], ctx.lang)}', icon: LucideIcons.calendarDays),
            ],
          ),
          gap14,
          Text(ctx.w('addressesTitle'), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (objs(cu['addresses']).isEmpty) Muted('—'),
          for (final a in objs(cu['addresses']))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.mapPin, size: 15, color: c.muted),
                  const SizedBox(width: 6),
                  Expanded(child: Text('${str(a['label']).isNotEmpty ? '${a['label']} · ' : ''}${a['address']}${str(a['note']).isNotEmpty ? ' · ${a['note']}' : ''}')),
                  if (str(a['map']).isNotEmpty)
                    InkWell(
                      onTap: () => launchUrl(Uri.parse(_mapUrl(str(a['map']))), mode: LaunchMode.externalApplication),
                      child: Text(
                        ctx.w('map'),
                        style: TextStyle(color: c.brand, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
          if (objs(_data!['favourites']).isNotEmpty) ...[
            gap14,
            Text(ctx.w('favourites'), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final f in objs(_data!['favourites'])) Chip2('${f['name']} · ${qtyOf(f['qty'])}× · ${money(f['total'], cur)}')]),
          ],
          gap14,
          Text('${ctx.w('allOrders')} (${objs(_data!['orders']).length})', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (objs(_data!['orders']).isEmpty) Muted(ctx.w('noOrders')),
          for (final o in objs(_data!['orders']))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(str(o['no']), style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          '${mDayTime(o['created_date'], ctx.lang)} · ${o['fulfil'] == 'delivery' ? ctx.w('delivery') : ctx.w('pickup')} · ${o['pay_method'] == 'qr' ? ctx.w('paidQr') : ctx.w('cash')}',
                          style: TextStyle(color: c.muted, fontSize: 12),
                        ),
                        Text(objs(o['items']).map((x) => '${qtyOf(x['qty'])}× ${x['name']}').join(' · '), style: const TextStyle(fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Pill(ctx.w('status.${o['status']}'), tone: _tone[o['status']] ?? ''),
                      const SizedBox(height: 4),
                      Text(money(o['total'], str(o['currency']).isEmpty ? cur : str(o['currency'])), style: const TextStyle(fontWeight: FontWeight.w800)),
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

class _Customers extends StatefulWidget {
  final MartCtx ctx;
  const _Customers({super.key, required this.ctx});
  @override
  State<_Customers> createState() => _CustomersState();
}

class _CustomersState extends State<_Customers> {
  final _q = TextEditingController();
  List<Json>? _rows;
  Timer? _wait;
  MartCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _wait?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/customers', {if (_q.text.trim().isNotEmpty) 'q': _q.text.trim()});
      if (mounted) setState(() => _rows = objs(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Panel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Field(
            controller: _q,
            hint: ctx.w('findCustomer'),
            icon: LucideIcons.search,
            onChanged: (_) {
              _wait?.cancel();
              _wait = Timer(const Duration(milliseconds: 300), _load);
            },
          ),
          const SizedBox(height: 8),
          if (_rows == null)
            const SkelList(rows: 3)
          else if (_rows!.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Muted(ctx.w('noCustomers'), align: TextAlign.center),
            )
          else
            for (final cu in _rows!)
              Opacity(
                opacity: cu['blocked'] == true ? .55 : 1,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => showSheet<void>(context, (_) => _CustomerSheet(ctx: ctx, cid: str(cu['_id']))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 19,
                          backgroundColor: c.active,
                          backgroundImage: str(cu['avatar']).isNotEmpty ? netImage(str(cu['avatar'])) : null,
                          child: str(cu['avatar']).isEmpty
                              ? Text(
                                  str(cu['name']).characters.take(1).toString().toUpperCase(),
                                  style: TextStyle(fontWeight: FontWeight.w800, color: c.brandInk),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(str(cu['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                '${cu['phone']} · ${ctx.w('orders')} ${n(cu['orders'])} (${n(cu['done'])} ✓) · ${cu['last_order'] != null ? mDate(cu['last_order'], ctx.lang) : '—'}',
                                style: TextStyle(color: c.muted, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(money(cu['spent'], ctx.cur), style: const TextStyle(fontWeight: FontWeight.w800)),
                            InkWell(
                              onTap: ctx.readOnly
                                  ? null
                                  : () async {
                                      try {
                                        await ctx.api.put('${ctx.base}/customers/${cu['_id']}', {'blocked': cu['blocked'] != true});
                                        _load();
                                      } catch (e) {
                                        ctx.fail(e);
                                      }
                                    },
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  cu['blocked'] == true ? ctx.w('unblock') : ctx.w('block'),
                                  style: TextStyle(color: cu['blocked'] == true ? c.good : c.danger, fontWeight: FontWeight.w700, fontSize: 12.5),
                                ),
                              ),
                            ),
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

class _Rules extends StatefulWidget {
  final MartCtx ctx;
  final Json info;
  final ValueChanged<Json> setInfo;
  const _Rules({super.key, required this.ctx, required this.info, required this.setInfo});
  @override
  State<_Rules> createState() => _RulesState();
}

class _RulesState extends State<_Rules> {
  late Json _f;
  final _fee = TextEditingController(), _min = TextEditingController(), _label = TextEditingController(), _note = TextEditingController();
  bool _busy = false;
  String _file = '';
  MartCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _reset(widget.info);
  }

  void _reset(Json info) {
    _f = {...obj(info['settings'])};
    _fee.text = qtyOf(_f['delivery_fee']);
    _min.text = qtyOf(_f['min_order']);
    _label.text = str(obj(info['qr'])['label']);
    _note.text = str(_f['shop_note']);
  }

  @override
  void dispose() {
    for (final x in [_fee, _min, _label, _note]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final r = await ctx.api.put('${ctx.base}/shop', {
        ..._f,
        'delivery_fee': numOf(_fee.text) ?? 0,
        'min_order': numOf(_min.text) ?? 0,
        'shop_qr_label': _label.text.trim(),
        'shop_note': _note.text.trim(),
      });
      final info = obj(r['data']);
      widget.setInfo(info);
      setState(() => _reset(info));
      ctx.notify(ctx.w('saved'));
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload(String kind, Future<Json> Function() fn) async {
    setState(() => _file = kind);
    try {
      final r = await fn();
      widget.setInfo(obj(r['data']));
      ctx.notify(ctx.w('saved'));
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _file = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final info = widget.info;
    final qr = obj(info['qr']);
    final sound = str(info['sound']);
    Widget tog(String k, String title, String sub, {bool disabled = false}) =>
        SwitchRow(title: title, sub: sub, value: _f[k] == true, onChanged: ctx.readOnly || disabled ? null : (v) => setState(() => _f[k] = v));
    Text head(String s) => Text(s, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15));
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          head(ctx.w('getting')),
          tog('pickup_on', ctx.w('pickup'), ctx.w('pickupSub')),
          tog('delivery_on', ctx.w('delivery'), ctx.w('deliverySub')),
          const SizedBox(height: 8),
          Field(label: '${ctx.w('deliveryFee')} (${ctx.cur})', controller: _fee, keyboard: decimalKeys, enabled: !ctx.readOnly && _f['delivery_on'] == true),
          gap14,
          Field(label: '${ctx.w('minOrder')} (${ctx.cur})', controller: _min, keyboard: decimalKeys, enabled: !ctx.readOnly),
          const SizedBox(height: 4),
          Muted(ctx.w('minOrderHint')),
          gap14,
          head(ctx.w('payment')),
          tog('shop_cash', ctx.w('cash'), ctx.w('cashSub')),
          tog('shop_qr', ctx.w('qr'), info['has_qr'] == true ? ctx.w('qrSub') : ctx.w('qrNeed'), disabled: info['has_qr'] != true),
          gap14,
          head(ctx.w('posAccess')),
          tog('pos_customers', ctx.w('posCustomers'), ctx.w('posCustomersSub')),
          gap14,
          Text(ctx.w('shopQr'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          MImagePick(
            ctx: ctx,
            url: str(qr['url']),
            busy: _file == 'qr',
            disabled: ctx.readOnly,
            maxSize: 900,
            onPick: (b, name) => _upload('qr', () => ctx.api.post('${ctx.base}/shop/qr', fileForm('file', b, name))),
            onRemove: () => _upload('qr', () => ctx.api.delete('${ctx.base}/shop/qr')),
          ),
          const SizedBox(height: 4),
          Muted(
            str(qr['url']).isNotEmpty
                ? ctx.w('shopQrHint')
                : str(qr['pos_url']).isNotEmpty
                ? ctx.w('shopQrPos')
                : ctx.w('shopQrNone'),
          ),
          gap14,
          Field(label: ctx.w('shopQrLabel'), hint: 'ABA · Lucky Mart · 000 123 456', controller: _label, maxLength: 60, enabled: !ctx.readOnly),
          gap14,
          Field(label: ctx.w('shopNote'), hint: ctx.w('shopNotePh'), controller: _note, maxLength: 300, maxLines: 2, enabled: !ctx.readOnly),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Btn(_busy ? ctx.w('saving') : ctx.w('save'), small: true, busy: _busy, onTap: ctx.readOnly || _busy ? null : _save),
          ),
          gap14,
          head(ctx.w('alarm')),
          const SizedBox(height: 4),
          Muted(ctx.w('alarmSub')),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.music, size: 18, color: c.brand),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sound.isNotEmpty ? ctx.w('alarmOwn') : ctx.w('alarmDefault'), style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(sound.isNotEmpty ? Uri.decodeComponent(sound.split('/').last) : ctx.w('alarmDefaultSub'), style: TextStyle(color: c.muted, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Btn(
                      _file == 'sound' ? '…' : ctx.w('alarmUpload'),
                      icon: LucideIcons.music,
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: ctx.readOnly || _file.isNotEmpty
                          ? null
                          : () async {
                              final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['mp3', 'm4a', 'wav', 'ogg']);
                              if (f == null) return;
                              final bytes = await f.xFile.readAsBytes();
                              final ext = f.name.split('.').last.toLowerCase();
                              final type = switch (ext) {
                                'm4a' => 'audio/mp4',
                                'wav' => 'audio/wav',
                                'ogg' => 'audio/ogg',
                                _ => 'audio/mpeg',
                              };
                              _upload(
                                'sound',
                                () => ctx.api.post('${ctx.base}/shop/sound', FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: f.name, contentType: DioMediaType.parse(type))})),
                              );
                            },
                    ),
                    if (sound.isNotEmpty) ...[
                      Btn(
                        ctx.w('alarmTest'),
                        icon: LucideIcons.play,
                        kind: BtnKind.ghost,
                        small: true,
                        onTap: () => launchUrl(Uri.parse(sound), mode: LaunchMode.externalApplication),
                      ),
                      Btn(
                        ctx.w('alarmReset'),
                        kind: BtnKind.ghost,
                        small: true,
                        onTap: ctx.readOnly || _file.isNotEmpty ? null : () => _upload('sound', () => ctx.api.delete('${ctx.base}/shop/sound')),
                      ),
                    ],
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

// the 24 looks of the customers' order page (msite/looks.js MP_LOOKS)
class MpLook {
  final String en, km, layout;
  final Color bg, fg, card, accent, accent2, nav, navfg;
  final double r;
  const MpLook(this.en, this.km, this.bg, this.fg, this.card, this.accent, this.accent2, this.nav, this.navfg, this.r, this.layout);
}

const mpLooks = <String, MpLook>{
  'classic': MpLook('Classic', 'បុរាណ', Color(0xFFF5F7F9), Color(0xFF0F172A), Color(0xFFFFFFFF), Color(0xFF0F766E), Color(0xFF14B8A6), Color(0xFFFFFFFF), Color(0xFF0F172A), 16, 'side'),
  'ocean': MpLook('Ocean', 'សមុទ្រ', Color(0xFFEEF6FB), Color(0xFF0B2440), Color(0xFFFFFFFF), Color(0xFF0891B2), Color(0xFF2563EB), Color(0xFF0B3A5B), Color(0xFFE0F2FE), 18, 'top'),
  'sunset': MpLook('Sunset', 'ថ្ងៃលិច', Color(0xFFFFF7F0), Color(0xFF3B1023), Color(0xFFFFFFFF), Color(0xFFEA580C), Color(0xFFDB2777), Color(0xFFFFFFFF), Color(0xFF3B1023), 20, 'top'),
  'forest': MpLook('Forest', 'ព្រៃឈើ', Color(0xFFF1F5F0), Color(0xFF14281A), Color(0xFFFFFFFF), Color(0xFF166534), Color(0xFF65A30D), Color(0xFF14532D), Color(0xFFDCFCE7), 14, 'side'),
  'midnight': MpLook('Midnight', 'ពាក់កណ្តាលអធ្រាត្រ', Color(0xFF0B1020), Color(0xFFE5E7EB), Color(0xFF141B2F), Color(0xFF818CF8), Color(0xFF22D3EE), Color(0xFF0F1629), Color(0xFFE5E7EB), 16, 'side'),
  'rose': MpLook('Rose', 'កុលាប', Color(0xFFFFF1F2), Color(0xFF4C0519), Color(0xFFFFFFFF), Color(0xFFE11D48), Color(0xFFF472B6), Color(0xFFFFFFFF), Color(0xFF4C0519), 22, 'top'),
  'mint': MpLook('Mint', 'ជីអង្កាម', Color(0xFFEFFCF8), Color(0xFF083344), Color(0xFFFFFFFF), Color(0xFF0D9488), Color(0xFF34D399), Color(0xFFFFFFFF), Color(0xFF083344), 16, 'side'),
  'grape': MpLook('Grape', 'ទំពាំងបាយជូរ', Color(0xFFF6F3FF), Color(0xFF24124D), Color(0xFFFFFFFF), Color(0xFF7C3AED), Color(0xFFC026D3), Color(0xFF2E1065), Color(0xFFEDE9FE), 18, 'side'),
  'sand': MpLook('Sand', 'ខ្សាច់', Color(0xFFFAF6EF), Color(0xFF3D3427), Color(0xFFFFFDF8), Color(0xFFA16207), Color(0xFFD97706), Color(0xFFFFFDF8), Color(0xFF3D3427), 10, 'top'),
  'slate': MpLook('Slate', 'ថ្មខៀវ', Color(0xFFF1F5F9), Color(0xFF0F172A), Color(0xFFFFFFFF), Color(0xFF334155), Color(0xFF0EA5E9), Color(0xFF1E293B), Color(0xFFE2E8F0), 10, 'side'),
  'coral': MpLook('Coral', 'ផ្កាថ្ម', Color(0xFFFFF5F3), Color(0xFF3F1D1A), Color(0xFFFFFFFF), Color(0xFFF43F5E), Color(0xFFFB923C), Color(0xFFFFFFFF), Color(0xFF3F1D1A), 20, 'top'),
  'sky': MpLook('Sky', 'មេឃ', Color(0xFFF0F7FF), Color(0xFF0B2545), Color(0xFFFFFFFF), Color(0xFF3B82F6), Color(0xFF38BDF8), Color(0xFFFFFFFF), Color(0xFF0B2545), 18, 'top'),
  'lemon': MpLook('Lemon', 'ក្រូចឆ្មារ', Color(0xFFFEFCE8), Color(0xFF2E2A05), Color(0xFFFFFFFF), Color(0xFFCA8A04), Color(0xFF65A30D), Color(0xFFFFFEF5), Color(0xFF2E2A05), 14, 'top'),
  'berry': MpLook('Berry', 'ផ្លែបឺរី', Color(0xFFFDF2F8), Color(0xFF4A0D2E), Color(0xFFFFFFFF), Color(0xFFBE185D), Color(0xFF7C3AED), Color(0xFF500724), Color(0xFFFCE7F3), 20, 'side'),
  'teal': MpLook('Teal', 'ខៀវបៃតង', Color(0xFFEFFAFA), Color(0xFF082F30), Color(0xFFFFFFFF), Color(0xFF0F766E), Color(0xFF0891B2), Color(0xFF134E4A), Color(0xFFCCFBF1), 16, 'side'),
  'amber': MpLook('Amber', 'អាំប័រ', Color(0xFFFFFBEB), Color(0xFF3A2304), Color(0xFFFFFFFF), Color(0xFFD97706), Color(0xFFDC2626), Color(0xFFFFFFFF), Color(0xFF3A2304), 16, 'top'),
  'ink': MpLook('Ink', 'ទឹកខ្មៅ', Color(0xFFF4F4F5), Color(0xFF18181B), Color(0xFFFFFFFF), Color(0xFF18181B), Color(0xFF52525B), Color(0xFF18181B), Color(0xFFFAFAFA), 8, 'side'),
  'blossom': MpLook('Blossom', 'ផ្ការីក', Color(0xFFFFF5FB), Color(0xFF3B0A2A), Color(0xFFFFFFFF), Color(0xFFEC4899), Color(0xFFA855F7), Color(0xFFFFFFFF), Color(0xFF3B0A2A), 24, 'top'),
  'jade': MpLook('Jade', 'ត្បូងខៀវ', Color(0xFFF0FDF4), Color(0xFF052E16), Color(0xFFFFFFFF), Color(0xFF059669), Color(0xFF0D9488), Color(0xFF064E3B), Color(0xFFD1FAE5), 14, 'side'),
  'ruby': MpLook('Ruby', 'ត្បូងទទឹម', Color(0xFFFFF1F1), Color(0xFF3F0A0A), Color(0xFFFFFFFF), Color(0xFFB91C1C), Color(0xFFEA580C), Color(0xFF450A0A), Color(0xFFFEE2E2), 12, 'side'),
  'cloud': MpLook('Cloud', 'ពពក', Color(0xFFF8FAFC), Color(0xFF1E293B), Color(0xFFFFFFFF), Color(0xFF6366F1), Color(0xFF38BDF8), Color(0xFFFFFFFF), Color(0xFF1E293B), 22, 'top'),
  'mocha': MpLook('Mocha', 'ម៉ូកា', Color(0xFFF6F0EA), Color(0xFF2C1A12), Color(0xFFFFFAF5), Color(0xFF6F4E37), Color(0xFFC08552), Color(0xFF2C1A12), Color(0xFFF6F0EA), 12, 'side'),
  'neon': MpLook('Neon', 'នីអុង', Color(0xFF0A0A0F), Color(0xFFF5F5F5), Color(0xFF15151F), Color(0xFFA3E635), Color(0xFFF0ABFC), Color(0xFF111118), Color(0xFFF5F5F5), 12, 'top'),
  'lotus': MpLook('Lotus', 'ផ្កាឈូក', Color(0xFFFDF4F8), Color(0xFF3A1630), Color(0xFFFFFFFF), Color(0xFFDB2777), Color(0xFF16A34A), Color(0xFFFFFFFF), Color(0xFF3A1630), 18, 'top'),
};
String mpLookName(String k, String lang) => lang == 'km' ? (mpLooks[k]?.km ?? k) : (mpLooks[k]?.en ?? k);

// a small picture of the customer page in one look: menu (side or top), welcome box, product cards
class MpThumb extends StatelessWidget {
  final String look, name;
  final String color;
  final List<Json> products;
  const MpThumb({super.key, required this.look, required this.name, this.color = '', this.products = const []});
  @override
  Widget build(BuildContext context) {
    final d = mpLooks[look] ?? mpLooks['classic']!;
    final a = color.isNotEmpty ? hexToColor(color) : d.accent;
    final r = d.r * .4;
    final names = products.isEmpty ? ['Coca', 'Bread', 'Water', 'Chips'] : products.take(4).map((p) => str(p['name'])).toList();
    final menu = [
      for (final i in [0, 1, 2])
        Container(
          height: 4,
          width: 22,
          margin: const EdgeInsets.only(bottom: 4, right: 4),
          decoration: BoxDecoration(color: i == 0 ? a : d.navfg.withValues(alpha: .3), borderRadius: BorderRadius.circular(2)),
        ),
    ];
    final content = Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [a, color.isNotEmpty ? Color.lerp(a, Colors.white, .35)! : d.accent2]),
              borderRadius: BorderRadius.circular(r),
            ),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 5),
          Expanded(
            child: Row(
              children: [
                for (final (i, nm) in names.indexed) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(color: d.card, borderRadius: BorderRadius.circular(r)),
                      padding: const EdgeInsets.all(3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(color: a.withValues(alpha: .15), borderRadius: BorderRadius.circular(r * .7)),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            nm,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(fontSize: 5.5, color: d.fg, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '\$1.25',
                            style: TextStyle(fontSize: 5.5, color: a, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    return AspectRatio(
      aspectRatio: 1.45,
      child: Container(
        color: d.bg,
        child: d.layout == 'side'
            ? Row(
                children: [
                  Container(
                    width: 34,
                    color: d.nav,
                    padding: const EdgeInsets.fromLTRB(6, 8, 0, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: menu),
                  ),
                  Expanded(child: content),
                ],
              )
            : Column(
                children: [
                  Container(
                    height: 14,
                    color: d.nav,
                    padding: const EdgeInsets.fromLTRB(6, 5, 6, 0),
                    child: Row(children: menu),
                  ),
                  Expanded(child: content),
                ],
              ),
      ),
    );
  }
}

class _PortalLooks extends StatefulWidget {
  final MartCtx ctx;
  final Json info;
  final ValueChanged<Json> setInfo;
  final VoidCallback reload;
  const _PortalLooks({super.key, required this.ctx, required this.info, required this.setInfo, required this.reload});
  @override
  State<_PortalLooks> createState() => _PortalLooksState();
}

class _PortalLooksState extends State<_PortalLooks> {
  List<Json> _prods = [];
  MartCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    ctx.api.get('${ctx.base}/products').then((r) {
      if (mounted) setState(() => _prods = objs(r['data']).where((p) => p['active'] != false).toList());
    }, onError: (_) {});
  }

  Future<void> _put(Json body) async {
    try {
      final r = await ctx.api.put('${ctx.base}/shop', body);
      widget.setInfo(obj(r['data']));
      ctx.notify(ctx.w('saved'));
    } catch (e) {
      ctx.fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final th = obj(widget.info['themes']);
    final owned = {'classic', ...(th['owned'] as List? ?? const []).map((e) => '$e')};
    final current = str(th['current']).isEmpty ? 'classic' : str(th['current']);
    final color = str(th['color']);
    Widget thumb(String k) => MpThumb(look: k, name: str(ctx.business['name']), color: current == k ? color : '', products: _prods);
    String status(String k) => current == k ? ctx.w('inUse') : (k == 'classic' ? ctx.w('free') : (owned.contains(k) ? ctx.m('yours') : '${fmt(n(th['price']))} ${ctx.m('coins')}'));
    void open(String k) => openLookSheet(
      context,
      title: ctx.w('portalLooksTitle'),
      keys: mpLooks.keys.toList(),
      start: k,
      current: current,
      owned: owned.contains,
      name: (x) => mpLookName(x, ctx.lang),
      big: (x) => SizedBox(width: 380, child: thumb(x)),
      status: status,
      useLabel: ctx.w('use'),
      buyLabel: (_) => ctx.m('unlock', {'coins': '${fmt(n(th['price']))} ${ctx.m('coins')}'}),
      readOnly: ctx.readOnly,
      use: (x) async {
        await _put({'portal_theme': x});
        return true;
      },
      buy: (x) => ctx.askBuy('mart_portal_theme', item: x, onDone: widget.reload),
    );
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MHead(ctx.w('portalLooksTitle'), icon: LucideIcons.palette, sub: ctx.w('portalLooksSub', {'price': n(th['price'])})),
          Text(ctx.w('portalColor'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: ctx.readOnly || color.isEmpty ? null : () => _put({'portal_color': ''}),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: (mpLooks[current] ?? mpLooks['classic']!).accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: color.isEmpty ? c.ink : Colors.transparent, width: 2),
                  ),
                  child: color.isEmpty ? const Icon(LucideIcons.check, size: 15, color: Colors.white) : null,
                ),
              ),
              const SizedBox(width: 10),
              Muted(ctx.w('colorLookShort')),
            ],
          ),
          const SizedBox(height: 10),
          ColorRow(
            value: color,
            colors: _presets,
            customLabel: ctx.w('colorCustom'),
            saveLabel: ctx.m('save'),
            cancelLabel: ctx.m('cancel'),
            onChanged: ctx.readOnly ? null : (v) => _put({'portal_color': v}),
          ),
          gap14,
          LayoutBuilder(
            builder: (_, box) {
              final cols = box.maxWidth > 520 ? 3 : 2;
              final w = (box.maxWidth - 10 * (cols - 1)) / cols;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final k in mpLooks.keys)
                    SizedBox(
                      width: w,
                      child: MLookCard(picture: thumb(k), name: mpLookName(k, ctx.lang), on: current == k, locked: !owned.contains(k), status: status(k), onTap: () => open(k)),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------- Delivery
// in a delivery order: pick the driver, send them the order
class OrderDriver extends StatefulWidget {
  final MartCtx ctx;
  final Json o;
  const OrderDriver({super.key, required this.ctx, required this.o});
  @override
  State<OrderDriver> createState() => _OrderDriverState();
}

class _OrderDriverState extends State<OrderDriver> {
  List<Json>? _drivers;
  late String _cur = str(widget.o['driver_id']);
  MartCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    ctx.api.get('${ctx.base}/delivery').then((r) {
      if (mounted) setState(() => _drivers = objs(obj(r['data'])['drivers']));
    }, onError: (_) => setState(() => _drivers = []));
  }

  @override
  Widget build(BuildContext context) {
    final drivers = _drivers;
    if (drivers == null) return const SizedBox.shrink();
    final o = widget.o;
    final addr = obj(o['address']);
    final d = drivers.where((v) => str(v['_id']) == _cur).firstOrNull;
    final text = [
      '🛵 ${o['no']} · ${ctx.business['name'] ?? ''}',
      '👤 ${o['name']} · ${o['phone']}',
      '📍 ${addr['address'] ?? ''}${str(addr['note']).isNotEmpty ? ' (${addr['note']})' : ''}',
      if (str(addr['map']).isNotEmpty) '🗺 ${_mapUrl(str(addr['map']))}',
      for (final l in objs(o['items'])) '• ${qtyOf(l['qty'])}× ${l['name']}',
      '💰 ${money(o['total'], str(o['currency']).isEmpty ? ctx.cur : str(o['currency']))}${o['pay_method'] == 'qr' ? ' (paid QR)' : ' (cash)'}',
    ].join('\n');
    return Row(
      children: [
        Expanded(
          child: SelectField<String>(
            value: drivers.any((v) => str(v['_id']) == _cur) ? _cur : '',
            options: [('', ctx.x('pickDriver')), for (final v in drivers) (str(v['_id']), str(v['name']))],
            onChanged: ctx.readOnly
                ? null
                : (v) async {
                    setState(() => _cur = v);
                    try {
                      await ctx.api.post('${ctx.base}/orders/${o['_id']}/driver', {'driver_id': v.isEmpty ? null : v});
                    } catch (e) {
                      ctx.fail(e);
                    }
                  },
          ),
        ),
        if (d != null) ...[
          const SizedBox(width: 8),
          Btn(
            ctx.x('sendDriver'),
            icon: LucideIcons.send,
            kind: BtnKind.ghost,
            small: true,
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: text));
              final tg = str(d['telegram']).replaceAll('@', '');
              launchUrl(
                Uri.parse(tg.isNotEmpty ? 'https://t.me/$tg' : 'https://t.me/share/url?url=${Uri.encodeComponent(' ')}&text=${Uri.encodeComponent(text)}'),
                mode: LaunchMode.externalApplication,
              );
            },
          ),
        ],
      ],
    );
  }
}

class _Zone {
  final String? key;
  final name = TextEditingController(), fee = TextEditingController(), min = TextEditingController(), eta = TextEditingController();
  bool active;
  _Zone(Json z) : key = z['key'] == null ? null : str(z['key']), active = z['active'] != false {
    name.text = str(z['name']);
    fee.text = qtyOf(z['fee'] ?? 0);
    min.text = qtyOf(z['min_order'] ?? 0);
    eta.text = str(z['eta']);
  }
  Json get json => {if (key != null) 'key': key, 'name': name.text.trim(), 'fee': numOf(fee.text) ?? 0, 'min_order': numOf(min.text) ?? 0, 'eta': eta.text.trim(), 'active': active};
  void dispose() {
    for (final x in [name, fee, min, eta]) {
      x.dispose();
    }
  }
}

class DeliveryTab extends StatefulWidget {
  final MartCtx ctx;
  const DeliveryTab({super.key, required this.ctx});
  @override
  State<DeliveryTab> createState() => _DeliveryTabState();
}

class _DeliveryTabState extends State<DeliveryTab> {
  Json? _data, _report;
  List<_Zone>? _zones;
  String _month = todayKH().substring(0, 7), _start = '';
  bool _saving = false;
  MartCtx get ctx => widget.ctx;
  bool get _on => ctx.addonOn('mart_delivery');

  @override
  void initState() {
    super.initState();
    if (_on) {
      _load(reset: true);
      _loadReport();
    }
  }

  @override
  void dispose() {
    for (final z in _zones ?? <_Zone>[]) {
      z.dispose();
    }
    super.dispose();
  }

  String _sig() => (_zones ?? []).map((z) => z.json.toString()).join('|');

  Future<void> _load({bool reset = false}) async {
    try {
      final r = await ctx.api.get('${ctx.base}/delivery');
      if (!mounted) return;
      setState(() {
        _data = obj(r['data']);
        if (reset || _zones == null) {
          for (final z in _zones ?? <_Zone>[]) {
            z.dispose();
          }
          _zones = objs(_data!['zones']).map(_Zone.new).toList();
          _start = _sig();
        }
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _loadReport() async {
    setState(() => _report = null);
    try {
      final r = await ctx.api.get('${ctx.base}/drivers/report', {'month': _month});
      if (mounted) setState(() => _report = obj(r['data']));
    } catch (_) {
      if (mounted) setState(() => _report = {'rows': []});
    }
  }

  Future<void> _saveZones() async {
    setState(() => _saving = true);
    try {
      await ctx.api.put('${ctx.base}/delivery/zones', {
        'zones': [
          for (final z in _zones!)
            if (z.name.text.trim().isNotEmpty) z.json,
        ],
      });
      ctx.notify(ctx.x('saved'));
      await _load(reset: true);
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final head = MAddonHead(ctx: ctx, addon: 'mart_delivery', icon: LucideIcons.mapPinned, title: ctx.x('delTitle'), sub: ctx.x('delSub'), perks: ctx.t.list('mx.delPerks'));
    if (!_on) return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [head]);
    final c = context.c;
    final zones = _zones;
    final drivers = objs(_data?['drivers']);
    final dirty = zones != null && _sig() != _start;
    return RefreshIndicator(
      onRefresh: () async {
        await _load();
        await _loadReport();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          head,
          mGap,
          mCard(context, ctx.x('zones'), sub: ctx.x('zonesSub'), [
            if (zones == null)
              const SkelList(rows: 3)
            else ...[
              if (zones.isEmpty) Muted(ctx.x('noZones')),
              for (final z in zones)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: c.line),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Field(label: ctx.x('zoneName'), controller: z.name, maxLength: 60, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Switch(value: z.active, onChanged: ctx.readOnly ? null : (v) => setState(() => z.active = v)),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: RoundBtn(
                              LucideIcons.x,
                              size: 34,
                              onTap: ctx.readOnly
                                  ? null
                                  : () => setState(() {
                                      zones.remove(z);
                                      z.dispose();
                                    }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Field(label: ctx.x('fee'), controller: z.fee, keyboard: decimalKeys, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Field(label: ctx.x('minOrder'), controller: z.min, keyboard: decimalKeys, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Field(label: ctx.x('eta'), hint: '30 min', controller: z.eta, maxLength: 40, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Btn(
                    ctx.x('addZone'),
                    icon: LucideIcons.plus,
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: ctx.readOnly || zones.length >= 50 ? null : () => setState(() => zones.add(_Zone(const {'active': true}))),
                  ),
                  const Spacer(),
                  Btn(ctx.x('save'), small: true, busy: _saving, onTap: ctx.readOnly || !dirty || _saving ? null : _saveZones),
                ],
              ),
            ],
          ]),
          mGap,
          mCard(
            context,
            ctx.x('drivers'),
            [
              if (_data == null)
                const SkelList(rows: 2)
              else if (drivers.isEmpty)
                Muted(ctx.x('noDrivers'))
              else
                for (final d in drivers)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: ctx.readOnly
                        ? null
                        : () async {
                            final ok = await showSheet<bool>(context, (_) => _DriverEditor(ctx: ctx, row: d));
                            if (ok == true) _load();
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: c.active,
                            child: Icon(LucideIcons.bike, size: 18, color: c.brandInk),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(str(d['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(
                                  [str(d['phone']), if (str(d['telegram']).isNotEmpty) '@${str(d['telegram']).replaceAll('@', '')}'].where((s) => s.isNotEmpty).join(' · '),
                                  style: TextStyle(color: c.muted, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                          Icon(LucideIcons.chevronRight, size: 16, color: c.muted),
                        ],
                      ),
                    ),
                  ),
            ],
            trailing: Btn(
              ctx.x('addDriver'),
              icon: LucideIcons.plus,
              small: true,
              onTap: ctx.readOnly
                  ? null
                  : () async {
                      final ok = await showSheet<bool>(context, (_) => _DriverEditor(ctx: ctx, row: const {}));
                      if (ok == true) _load();
                    },
            ),
          ),
          mGap,
          mCard(context, ctx.x('driverReport'), [
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    _month = prevMonth(_month);
                    _loadReport();
                  },
                  icon: const Icon(LucideIcons.chevronLeft, size: 18),
                ),
                Expanded(
                  child: Text(
                    monthName(_month, ctx.lang),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: _month == todayKH().substring(0, 7)
                      ? null
                      : () {
                          final y = int.parse(_month.substring(0, 4)), m = int.parse(_month.substring(5, 7));
                          _month = m == 12 ? '${y + 1}-01' : '$y-${(m + 1).toString().padLeft(2, '0')}';
                          _loadReport();
                        },
                  icon: const Icon(LucideIcons.chevronRight, size: 18),
                ),
              ],
            ),
            if (_report == null)
              const SkelList(rows: 2)
            else if (objs(_report!['rows']).isEmpty)
              Muted('—')
            else
              for (final r in objs(_report!['rows']))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(str(r['name']).isEmpty ? ctx.x('noDriver') : str(r['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${ctx.x('fees')} ${money(r['fees'], ctx.cur)} · ${ctx.x('total')} ${money(r['total'], ctx.cur)}', style: TextStyle(color: c.muted, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      Text('${n(r['orders'])}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ],
                  ),
                ),
          ]),
        ],
      ),
    );
  }
}

class _DriverEditor extends StatefulWidget {
  final MartCtx ctx;
  final Json row;
  const _DriverEditor({required this.ctx, required this.row});
  @override
  State<_DriverEditor> createState() => _DriverEditorState();
}

class _DriverEditorState extends State<_DriverEditor> with SheetSave {
  late final _name = TextEditingController(text: str(widget.row['name'])),
      _phone = TextEditingController(text: str(widget.row['phone'])),
      _tg = TextEditingController(text: str(widget.row['telegram']));
  @override
  MartCtx get mctx => widget.ctx;
  bool get _isNew => widget.row['_id'] == null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _tg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final body = {'name': _name.text.trim(), 'phone': _phone.text.trim(), 'telegram': _tg.text.trim()};
    return MSheet(
      title: _isNew ? ctx.x('addDriver') : str(widget.row['name']),
      footer: [
        if (!_isNew) SureDelete(remove: ctx.x('remove'), sure: ctx.x('sure'), onDelete: busy ? null : () => save(() => ctx.api.delete('${ctx.base}/drivers/${widget.row['_id']}'))),
        const Spacer(),
        Btn(ctx.x('cancel'), kind: BtnKind.ghost, small: true, onTap: busy ? null : () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(
          busy ? ctx.x('saving') : ctx.x('save'),
          small: true,
          busy: busy,
          onTap: busy || _name.text.trim().isEmpty
              ? null
              : () => save(() => _isNew ? ctx.api.post('${ctx.base}/drivers', body) : ctx.api.put('${ctx.base}/drivers/${widget.row['_id']}', body), ok: ctx.x('saved')),
        ),
      ],
      children: [
        Field(label: ctx.x('name'), controller: _name, maxLength: 60, autofocus: _isNew, onChanged: (_) => setState(() {})),
        gap14,
        Field(label: ctx.x('phone'), controller: _phone, maxLength: 30, keyboard: TextInputType.phone),
        gap14,
        Field(label: ctx.x('driverTg'), hint: '@username', controller: _tg, maxLength: 60),
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}
