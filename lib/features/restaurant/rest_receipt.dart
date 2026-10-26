import 'package:flutter/material.dart';

import '../../widgets/ui.dart';

import '../../core/api.dart';
import 'rest_common.dart';

// The receipt as printed by the POS (the web's pos/receipt.jsx + receipt.css), drawn natively.
// Black on white paper, the width of the shop's printer roll (58 / 80 mm). Every look of the web.
//   restaurant = { name_km, name_en, logo, address, phone, tin, receipt: { footer, wifi_name, wifi_pass, theme } }
//   money      = { currency, khr_rate, khr_rounding, vat, service_charge }
//   label(key) = receiptTitle, billTitle, table, takeaway, cashier, subtotal, discount, service, vat, vatIncl, total, change, rate, thanks, cancelledTitle

num _round2(num v) => (v * 100).round() / 100;
num _roundStep(num v, num step) => (v / (step == 0 ? 1 : step)).round() * (step == 0 ? 1 : step);

// qty × (price + add-ons); a cancelled line counts 0
num lineTotal(Json l) {
  if (l['status'] == 'void') return 0;
  final addons = objs(l['addons']).fold<num>(0, (a, x) => a + n(x['price']));
  return n(l['qty']) * (n(l['unit_price']) + addons);
}

// money off one line: the cashier's discount, else the promotion's
num lineOff(Json l) {
  final t = lineTotal(l);
  if (t == 0) return 0;
  final d = obj(l['discount']);
  num off;
  if (d['kind'] == 'percent') {
    off = t * n(d['value']).clamp(0, 100) / 100;
  } else if (d['kind'] == 'amount') {
    off = n(d['value']) < 0 ? 0 : n(d['value']);
  } else {
    off = n(obj(l['promo'])['off']) < 0 ? 0 : n(obj(l['promo'])['off']);
  }
  final r = _round2(off);
  return r > t ? t : r;
}

num _money(num v, Json m) => m['currency'] == 'KHR' ? _roundStep(v, n(m['khr_rounding']) == 0 ? 100 : n(m['khr_rounding'])) : _round2(v);
num _other(num v, Json m) {
  final rate = n(m['khr_rate']) == 0 ? 4100 : n(m['khr_rate']);
  return m['currency'] == 'USD' ? _roundStep(v * rate, n(m['khr_rounding']) == 0 ? 100 : n(m['khr_rounding'])) : _round2(v / rate);
}

// the totals of a bill (calcOrder on the web) — used when the API didn't send them
Json calcOrder(Json order, Json m) {
  final lines = objs(order['lines']);
  final subtotal = _money(lines.fold<num>(0, (a, l) => a + lineTotal(l)), m);
  final itemDiscount = _money(lines.fold<num>(0, (a, l) => a + lineOff(l)), m);
  final rw = obj(order['reward_discount']);
  num reward = 0;
  if (rw['kind'] == 'percent') reward = _money((subtotal - itemDiscount) * n(rw['value']).clamp(0, 100) / 100, m);
  if (rw['kind'] == 'amount') reward = _money([subtotal - itemDiscount, n(rw['value']) < 0 ? 0 : n(rw['value'])].reduce((a, b) => a < b ? a : b), m);
  final after = subtotal - itemDiscount - reward;
  final d = obj(order['discount']);
  num bill = 0;
  if (d['kind'] == 'percent') bill = _money(after * n(d['value']).clamp(0, 100) / 100, m);
  if (d['kind'] == 'amount') bill = _money([after, n(d['value']) < 0 ? 0 : n(d['value'])].reduce((a, b) => a < b ? a : b), m);
  final discount = itemDiscount + reward + bill;
  final afterDiscount = subtotal - discount;
  final svc = obj(m['service_charge']);
  final service = svc['enabled'] == true && order['type'] != 'takeaway' ? _money(afterDiscount * n(svc['rate']) / 100, m) : 0;
  final base = afterDiscount + service;
  final vatS = obj(m['vat']);
  final rate = n(vatS['rate']);
  num vat = 0, total = base;
  if (vatS['enabled'] == true && rate > 0) {
    if (vatS['included'] == true) {
      vat = _money(base * rate / (100 + rate), m);
    } else {
      vat = _money(base * rate / 100, m);
      total = base + vat;
    }
  }
  total = _money(total, m);
  return {'subtotal': subtotal, 'discount': discount, 'service': service, 'vat': vat, 'vat_included': vatS['enabled'] == true && vatS['included'] == true, 'total': total, 'other': _other(total, m)};
}

String _when(Object? v) {
  final d = (DateTime.tryParse('${v ?? ''}') ?? DateTime.now()).toLocal();
  String p(int x) => x.toString().padLeft(2, '0');
  return '${p(d.day)}/${p(d.month)}/${d.year}, ${p(d.hour)}:${p(d.minute)}';
}

const receiptThemes = ['classic', 'modern', 'mono', 'bold', 'compact', 'elegant', 'boxed', 'columns', 'biglogo', 'minimal', 'khmer'];

class ReceiptView extends StatelessWidget {
  final Json order, restaurant, money;
  final String Function(String key) label;
  final bool paidView, showVoid;
  final String? theme;
  const ReceiptView({super.key, required this.order, required this.restaurant, required this.money, required this.label, this.paidView = true, this.showVoid = false, this.theme});

  @override
  Widget build(BuildContext context) {
    final R = restaurant;
    final m = money;
    final rc = obj(R['receipt']);
    final c = str(m['currency']).isEmpty ? 'USD' : str(m['currency']);
    final other = c == 'USD' ? 'KHR' : 'USD';
    final tot = order['totals'] is Map && obj(order['totals']).containsKey('subtotal') ? obj(order['totals']) : calcOrder(order, m);
    final look = theme ?? (str(rc['theme']).isEmpty ? 'classic' : str(rc['theme']));
    final s = _Look(look);
    final cancelled = order['status'] == 'void';
    final lines = objs(order['lines']).where((l) => showVoid ? l['void_reason'] != 'removed' : l['status'] != 'void').toList();
    final khmerFirst = look == 'khmer';
    final columns = look == 'columns';
    String mo(Object? v, [String? cur]) => fmtMoney(n(v), cur ?? c);
    final base = TextStyle(fontFamily: s.font, fontFamilyFallback: s.fallback, fontSize: s.size, height: s.height, color: Colors.black);

    Widget row(String a, String b, {TextStyle? style, bool firstBold = false}) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(a, style: firstBold ? const TextStyle(fontWeight: FontWeight.w700) : null),
        ),
        const SizedBox(width: 8),
        Text(b),
      ],
    );
    Widget sub(String text, {bool italic = false}) => Padding(
      padding: EdgeInsets.only(left: columns ? 30 : 11),
      child: Text(
        text,
        style: TextStyle(fontSize: s.subSize, fontStyle: italic ? FontStyle.italic : null),
      ),
    );

    final head = Column(
      children: [
        if (str(R['logo']).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(s.logoRound ? 999 : 10),
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix([.2126, .7152, .0722, 0, 0, .2126, .7152, .0722, 0, 0, .2126, .7152, .0722, 0, 0, 0, 0, 0, 1, 0]),
                child: Image(image: netImage(str(R['logo'])), width: s.logo, height: s.logo, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
              ),
            ),
          ),
        if (str(R['name_km']).isNotEmpty)
          Text(
            str(R['name_km']),
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: khmerFirst ? 17 : s.nameSize),
          ),
        if (str(R['name_en']).isNotEmpty)
          Text(
            s.upper ? str(R['name_en']).toUpperCase() : str(R['name_en']),
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: s.nameSize, letterSpacing: look == 'elegant' ? .6 : null),
          ),
        if (str(R['address']).isNotEmpty) Text(str(R['address']), textAlign: TextAlign.center),
        if (str(R['phone']).isNotEmpty) Text(str(R['phone']), textAlign: TextAlign.center),
        if (str(R['tin']).isNotEmpty && obj(m['vat'])['enabled'] == true) Text('TIN: ${str(R['tin'])}', textAlign: TextAlign.center),
      ],
    );

    final titleText = paidView ? label('receiptTitle') : label('billTitle');
    Widget title = Text(
      titleText,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontWeight: s.titleWeight,
        fontStyle: look == 'elegant' ? FontStyle.italic : null,
        fontSize: s.titleSize,
        letterSpacing: s.titleSpacing,
        color: look == 'bold' ? Colors.white : Colors.black,
      ),
    );
    title = Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: look == 'compact' ? 4 : 8, bottom: 4),
      padding: look == 'bold' || look == 'boxed' ? const EdgeInsets.symmetric(vertical: 4) : null,
      decoration: look == 'bold'
          ? const BoxDecoration(color: Colors.black)
          : look == 'boxed'
          ? BoxDecoration(border: Border.all(width: 1.5), borderRadius: BorderRadius.circular(5))
          : null,
      child: title,
    );

    final totalRow = Container(
      margin: look == 'bold' || look == 'boxed' ? const EdgeInsets.symmetric(vertical: 4) : EdgeInsets.zero,
      padding: look == 'bold' || look == 'boxed'
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5)
          : look == 'minimal'
          ? const EdgeInsets.only(top: 5)
          : EdgeInsets.zero,
      decoration: look == 'bold'
          ? const BoxDecoration(color: Colors.black)
          : look == 'boxed'
          ? BoxDecoration(border: Border.all(width: 1.5), borderRadius: BorderRadius.circular(5))
          : look == 'minimal'
          ? const BoxDecoration(border: Border(top: BorderSide()))
          : null,
      child: DefaultTextStyle.merge(
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: s.totalSize, color: look == 'bold' ? Colors.white : Colors.black),
        child: row(s.upper ? label('total').toUpperCase() : label('total'), mo(tot['total'])),
      ),
    );

    final vat = obj(m['vat']), svc = obj(m['service_charge']);
    final change = obj(order['change']);
    final member = obj(order['member']);
    final pointsEarned = order['points_applied'] == true ? n(order['points_earned']) : 0;

    Widget boxed(Widget w) => look == 'boxed'
        ? Container(
            width: double.infinity,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(border: Border.all(), borderRadius: BorderRadius.circular(5)),
            child: w,
          )
        : w;

    return DefaultTextStyle(
      style: base,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, look == 'compact' ? 10 : 14, 12, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            boxed(head),
            title,
            if (cancelled)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(border: Border.all(width: 2)),
                child: Text(
                  label('cancelledTitle'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.4),
                ),
              ),
            row('#${str(order['number'])}', str(order['table_name']).isNotEmpty ? '${label('table')} ${str(order['table_name'])}' : label('takeaway')),
            row(
              _when(paidView ? order['paid_at'] ?? order['opened_at'] : order['paid_at']),
              '${label('cashier')}: ${str(obj(order['closed_by'])['name']).isNotEmpty ? str(obj(order['closed_by'])['name']) : str(obj(order['opened_by'])['name'])}',
            ),
            _Rule(s),
            if (columns)
              Container(
                padding: const EdgeInsets.only(bottom: 3),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide())),
                child: DefaultTextStyle.merge(
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: s.size * .85),
                  child: _cols('QTY', 'ITEM', 'AMOUNT'),
                ),
              ),
            for (final l in lines) _line(l, s, columns, khmerFirst, mo, sub, row),
            _Rule(s),
            row(label('subtotal'), mo(tot['subtotal']), firstBold: khmerFirst),
            if (n(tot['discount']) > 0) row(label('discount'), '−${mo(tot['discount'])}', firstBold: khmerFirst),
            if (n(tot['service']) > 0) row('${label('service')} ${fmtNum(svc['rate'])}%', mo(tot['service']), firstBold: khmerFirst),
            if (n(tot['vat']) > 0) row('${tot['vat_included'] == true ? label('vatIncl') : label('vat')} ${fmtNum(vat['rate'])}%', mo(tot['vat']), firstBold: khmerFirst),
            totalRow,
            Align(
              alignment: Alignment.centerRight,
              child: Text(mo(tot['other'], other), style: TextStyle(fontSize: s.subSize)),
            ),
            if (paidView) ...[
              _Rule(s),
              for (final p in objs(order['payments'])) row(str(p['method']), fmtMoney(n(p['amount']), str(p['currency']).isEmpty ? c : str(p['currency']))),
              if (n(change['usd']) > 0 || n(change['khr']) > 0)
                row(label('change'), [if (n(change['usd']) > 0) fmtMoney(n(change['usd']), 'USD'), if (n(change['khr']) > 0) fmtMoney(n(change['khr']), 'KHR')].join(' + ')),
            ],
            if (str(member['id']).isNotEmpty) ...[
              _Rule(s),
              row('★ Member', '${str(member['name'])} ${str(member['phone'])}'),
              for (final r in objs(order['redemptions']))
                DefaultTextStyle.merge(
                  style: const TextStyle(fontStyle: FontStyle.italic),
                  child: row(str(r['name']), str(r['code']).isNotEmpty ? str(r['code']) : '−${fmtNum(r['points'])} pts'),
                ),
              if (pointsEarned > 0) row('Points earned', '+${fmtNum(pointsEarned)}'),
            ],
            _Rule(s),
            boxed(
              DefaultTextStyle.merge(
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: s.subSize, fontStyle: look == 'elegant' ? FontStyle.italic : null),
                child: Column(
                  children: [
                    Text('${label('rate')}: 1 USD = ${fmtMoney(n(m['khr_rate']), 'KHR')}'),
                    if (str(rc['footer']).isNotEmpty) Text(str(rc['footer'])),
                    if (str(rc['wifi_name']).isNotEmpty) Text('Wi-Fi: ${str(rc['wifi_name'])}${str(rc['wifi_pass']).isNotEmpty ? ' · ${str(rc['wifi_pass'])}' : ''}'),
                    if (str(rc['footer']).isEmpty) Text(label('thanks')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _cols(String a, String b, String c) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 26, child: Text(a)),
      const SizedBox(width: 5),
      Expanded(child: Text(b)),
      const SizedBox(width: 5),
      Text(c, textAlign: TextAlign.right),
    ],
  );

  Widget _line(
    Json l,
    _Look s,
    bool columns,
    bool khmerFirst,
    String Function(Object?, [String?]) mo,
    Widget Function(String, {bool italic}) sub,
    Widget Function(String, String, {TextStyle? style, bool firstBold}) row,
  ) {
    final km = str(l['name_km']), en = str(l['name_en']);
    final main = khmerFirst ? (km.isNotEmpty ? km : en) : (en.isNotEmpty ? en : km);
    final second = khmerFirst ? (km.isNotEmpty ? en : '') : (en.isNotEmpty ? km : '');
    final isVoid = l['status'] == 'void';
    final price = mo(isVoid ? lineTotal({...l, 'status': ''}) : lineTotal(l));
    final size = str(l['size']).isNotEmpty ? ' (${str(l['size'])})' : '';
    final d = obj(l['discount']);
    final off = isVoid ? 0 : lineOff(l);
    final w = Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (columns) _cols(fmtNum(l['qty']), '$main$size', price) else row('${fmtNum(l['qty'])} × $main$size', price, firstBold: khmerFirst),
          if (second.isNotEmpty) sub(second),
          for (final a in objs(l['addons'])) sub('+ ${str(a['name'])}${n(a['price']) != 0 ? ' ${mo(a['price'])}' : ''}'),
          if (str(l['note']).isNotEmpty) sub('“${str(l['note'])}”'),
          if (off > 0)
            Padding(
              padding: EdgeInsets.only(left: columns ? 30 : 11),
              child: DefaultTextStyle.merge(
                style: TextStyle(fontSize: s.subSize, fontStyle: FontStyle.italic),
                child: row(
                  str(d['kind']).isNotEmpty
                      ? '${label('discount')}${d['kind'] == 'percent' ? ' ${fmtNum(d['value'])}%' : ''}${str(d['reason']).isNotEmpty ? ' · ${str(d['reason'])}' : ''}'
                      : str(obj(l['promo'])['name']),
                  '−${mo(off)}',
                ),
              ),
            ),
          if (isVoid && str(l['void_reason']).isNotEmpty) sub('✕ ${str(l['void_reason'])}'),
        ],
      ),
    );
    return isVoid
        ? Opacity(
            opacity: .6,
            child: DefaultTextStyle.merge(
              style: const TextStyle(decoration: TextDecoration.lineThrough),
              child: w,
            ),
          )
        : w;
  }
}

String fmtNum(Object? v) {
  final x = n(v);
  return x == x.roundToDouble() ? x.toInt().toString() : x.toString();
}

// the type sizes / fonts of each look (receipt.css, the on-screen .pr-paper sizes)
class _Look {
  final String look;
  _Look(this.look);
  String get font => switch (look) {
    'modern' => 'PlusJakartaSans',
    'mono' => 'Courier New',
    'elegant' => 'Georgia',
    _ => 'KantumruyPro',
  };
  List<String> get fallback => switch (look) {
    'mono' => const ['Courier', 'monospace', 'KantumruyPro'],
    'elegant' => const ['Times New Roman', 'serif', 'KantumruyPro'],
    'modern' => const ['KantumruyPro'],
    _ => const ['monospace'],
  };
  double get size => look == 'compact' ? 10.5 : 12;
  double get subSize => look == 'compact' ? 9.5 : 10.5;
  double get height => look == 'compact' ? 1.2 : 1.35;
  bool get upper => look == 'mono';
  double get logo => look == 'biglogo' ? 90 : (look == 'compact' ? 34 : 48);
  bool get logoRound => look == 'biglogo' || look == 'minimal';
  double get nameSize => switch (look) {
    'bold' || 'elegant' => 15,
    'biglogo' => 17,
    _ => 13,
  };
  double get titleSize => switch (look) {
    'modern' || 'biglogo' => 12,
    'compact' => 11,
    'minimal' => 10,
    'khmer' => 15,
    _ => 13,
  };
  double get titleSpacing => switch (look) {
    'modern' => 2.4,
    'elegant' => 3.6,
    'biglogo' => 3,
    'minimal' => 4.2,
    _ => 1,
  };
  FontWeight get titleWeight => switch (look) {
    'elegant' => FontWeight.w400,
    'minimal' => FontWeight.w600,
    _ => FontWeight.w800,
  };
  double get totalSize => switch (look) {
    'modern' || 'minimal' => 16,
    'bold' => 15,
    _ => 13,
  };
  // the line between parts: dashed (classic), solid, double or none
  String get rule => switch (look) {
    'modern' || 'boxed' || 'columns' => 'solid',
    'mono' || 'elegant' => 'double',
    'minimal' => 'none',
    _ => 'dashed',
  };
}

class _Rule extends StatelessWidget {
  final _Look s;
  const _Rule(this.s);
  @override
  Widget build(BuildContext context) {
    final kind = s.rule;
    if (kind == 'none') return const SizedBox(height: 18);
    final margin = EdgeInsets.symmetric(vertical: s.look == 'compact' ? 3 : (s.look == 'elegant' ? 8 : 6), horizontal: s.look == 'elegant' ? 22 : 0);
    if (kind == 'double') {
      return Container(
        margin: margin,
        height: 3,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(width: 1), bottom: BorderSide(width: 1)),
        ),
      );
    }
    if (kind == 'solid') return Container(margin: margin, height: 1, color: Colors.black);
    return Padding(
      padding: margin,
      child: CustomPaint(size: const Size(double.infinity, 1), painter: _Dash()),
    );
  }
}

class _Dash extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.black
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, .5), Offset((x + 3).clamp(0, size.width), .5), p);
    }
  }

  @override
  bool shouldRepaint(_Dash old) => false;
}

// on screen: the receipt on a strip of paper with a torn bottom edge
class ReceiptPaper extends StatelessWidget {
  final int size; // 58 or 80 (mm roll)
  final Widget child;
  const ReceiptPaper({super.key, this.size = 80, required this.child});
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: size == 58 ? 220 : 300),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 2, offset: const Offset(0, 1)),
            BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 28, offset: const Offset(0, 8)),
          ],
        ),
        child: ClipPath(
          clipper: _Torn(),
          child: Container(color: Colors.white, padding: const EdgeInsets.only(bottom: 8), child: child),
        ),
      ),
    ),
  );
}

class _Torn extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width, s.height - 8);
    var x = s.width;
    var down = false;
    while (x > 0) {
      x -= 6;
      p.lineTo(x.clamp(0, s.width), down ? s.height - 8 : s.height);
      down = !down;
    }
    p
      ..lineTo(0, s.height - 8)
      ..close();
    return p;
  }

  @override
  bool shouldReclip(_Torn old) => false;
}
