import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import 'ui.dart';

// One coin transaction in a small sheet (the web's TxDetail.jsx): in / out, when, what for (business, product,
// period), how it was paid, balance after. The owner wallet (admin: false) and the super admin (admin: true).

String _tx(T t, String k) => t('tx.$k');
String _who(Object? c, T t) => c is Map ? (str(c['name']).isNotEmpty ? str(c['name']) : (str(c['email']).isNotEmpty ? str(c['email']) : '—')) : _tx(t, 'bizhub');

// a readable title for a transaction (list rows + the sheet)
String txTitle(Json x, T t) {
  final order = obj(x['order']);
  if (str(order['no']).isNotEmpty) return '${_tx(t, 'buyCoins')} · ${order['no']}';
  final type = str(x['type']);
  final product = str(x['product']);
  if (type == 'spend') {
    if (product == 'new_business') return '${_tx(t, 'newBiz')} · ${t.or('sa.categoryNames.${x['service']}', str(x['service']))}';
    if (product.isNotEmpty && t.maybe('lic.products.$product') != null) return t('lic.products.$product');
    return str(x['note']).isNotEmpty ? str(x['note']) : t('sa.typeNames.spend');
  }
  if (type == 'signup_bonus') return t('messages.txBonus');
  if (type == 'card_redeem') return t('messages.txCard');
  return str(x['note']).isNotEmpty ? str(x['note']) : t.or('sa.typeNames.$type', type);
}

Future<void> showTxSheet(BuildContext context, Json x, T t, {bool admin = false, String meId = ''}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _TxSheet(x: x, t: t, admin: admin, meId: meId),
);

class _TxSheet extends StatelessWidget {
  final Json x;
  final T t;
  final bool admin;
  final String meId;
  const _TxSheet({required this.x, required this.t, required this.admin, required this.meId});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final type = str(x['type']);
    final to = x['to_customer'];
    final toId = to is Map ? str(to['_id']) : str(to);
    final incoming = !admin ? x['direction'] == 'in' : (meId.isNotEmpty ? toId == meId : type == 'generate' || type == 'signup_bonus');
    final signed = !admin || meId.isNotEmpty;
    final typeName = !admin && type == 'transfer' ? (incoming ? t('messages.txIn') : t('messages.txOut')) : t.or('sa.typeNames.$type', type);
    final biz = obj(x['business']);
    final product = str(x['product']);
    final pay = obj(x['payment']);
    final order = obj(x['order']);
    final other = obj(x['other']);
    final days = x['days'];
    final rows = <(String, String)>[
      (_tx(t, 'when'), fmtDate(x['created_date'], time: true, lang: t.lang)),
      (_tx(t, 'kind'), typeName),
      if (biz.isNotEmpty) (_tx(t, 'business'), '${biz['name']}${biz['deleted'] == true ? ' (${_tx(t, 'deleted')})' : ''} · ${t.or('sa.categoryNames.${biz['category']}', str(biz['category']))}'),
      if (product.isNotEmpty && product != 'new_business') (_tx(t, 'what'), t.or('lic.products.$product', product)),
      if (str(x['item']).isNotEmpty) (_tx(t, 'item'), str(x['item'])),
      if (type == 'spend' && product.isNotEmpty && product != 'new_business') (_tx(t, 'period'), days != null ? _tx(t, 'days').replaceAll('{n}', '$days') : _tx(t, 'forever')),
      if (admin) (_tx(t, 'from'), type == 'generate' || type == 'signup_bonus' ? '—' : (type == 'card_redeem' || type == 'card_cancel' ? _tx(t, 'cards') : _who(x['from_customer'], t))),
      if (admin) (_tx(t, 'to'), type == 'card_create' ? _tx(t, 'cards') : _who(x['to_customer'], t)),
      if (!admin && other.isNotEmpty) (incoming ? _tx(t, 'from') : _tx(t, 'to'), other['kind'] == 'customer' ? (str(other['name']).isEmpty ? '—' : str(other['name'])) : _tx(t, 'bizhub')),
      if (order.isNotEmpty) (_tx(t, 'order'), '${order['no']} · ${_tx(t, 'orderCoins').replaceAll('{coins}', fmt(order['coins'])).replaceAll('{bonus}', fmt(order['bonus']))}'),
      if (str(pay['method']).isNotEmpty) (_tx(t, 'payment'), '${pay['method']}${pay['amount_usd'] != null ? ' · \$${pay['amount_usd']}' : ''}'),
      if (str(pay['reference']).isNotEmpty) (_tx(t, 'reference'), str(pay['reference'])),
      if (n(x['cards']) > 0) (_tx(t, 'cards'), fmt(x['cards'])),
      if (!admin && x['balance_after'] != null) (_tx(t, 'balanceAfter'), fmt(x['balance_after'])),
      if (admin && x['from_balance_after'] != null && x['from_customer'] != null) ('${_tx(t, 'balanceAfter')} · ${_who(x['from_customer'], t)}', fmt(x['from_balance_after'])),
      if (admin && x['to_balance_after'] != null) ('${_tx(t, 'balanceAfter')} · ${_who(x['to_customer'], t)}', fmt(x['to_balance_after'])),
      if (str(x['note']).isNotEmpty) (_tx(t, 'note'), str(x['note'])),
      if (admin && x['by_user'] is Map) (_tx(t, 'by'), '${obj(x['by_user'])['firstname'] ?? ''} ${obj(x['by_user'])['lastname'] ?? ''}'.trim()),
    ];
    final col = !signed ? c.ink : (incoming ? c.good : c.danger);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).padding.bottom),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            decoration: BoxDecoration(color: !signed ? c.bg2 : (incoming ? c.goodBg : c.dangerBg), borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: c.card, shape: BoxShape.circle),
                  child: Icon(incoming ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight, color: col),
                ),
                const SizedBox(height: 8),
                Text(
                  '${signed ? (incoming ? '+' : '−') : ''}${fmt(x['amount'])}',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: col, height: 1.1),
                ),
                const SizedBox(height: 4),
                Text(
                  txTitle(x, t),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Chip2(typeName),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final (k, v) in rows) _Row(k, v),
          // the transaction id (to quote when asking support)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(_tx(t, 'id'), style: TextStyle(color: c.muted, fontSize: 13)),
                ),
                Flexible(
                  child: Text(
                    str(x['_id']),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.muted, fontSize: 11.5, fontFamily: 'monospace'),
                  ),
                ),
                IconButton(
                  tooltip: _tx(t, 'copy'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: str(x['_id'])));
                    toast(context, _tx(t, 'copied'));
                  },
                  icon: Icon(LucideIcons.copy, size: 15, color: c.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Btn(_tx(t, 'close'), kind: BtnKind.ghost, expand: true, onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String k, v;
  const _Row(this.k, this.v);
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(k, style: TextStyle(color: c.muted, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}
