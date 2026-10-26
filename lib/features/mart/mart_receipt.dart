import 'package:flutter/material.dart';

import '../../widgets/ui.dart';

import '../../core/api.dart';
import '../restaurant/rest_receipt.dart' show ReceiptPaper;
import 'mart_common.dart';

// Mini Mart receipt templates — the app version of pos/mart/themes.js (36 looks, all black on white for thermal printers).
//   font: sans | serif | mono | round | display      head: center | left | banner | boxed | split | big
//   rule: dash | solid | double | dots | thick | stars | wave | none      total: plain | box | invert | big | underline | double
//   items: list | table | zebra | compact      foot: plain | box | ticket | stamp      frame: none | solid | dashed | double
class MartTheme {
  final String key, en, km, font, head, rule, total, items, foot, frame, orn;
  final bool caps;
  final double base;
  const MartTheme(
    this.key,
    this.en,
    this.km, {
    this.font = 'sans',
    this.head = 'center',
    this.rule = 'dash',
    this.total = 'plain',
    this.items = 'list',
    this.foot = 'plain',
    this.frame = 'none',
    this.orn = '',
    this.caps = false,
    this.base = 12,
  });
  String name(String lang) => lang == 'km' ? km : en;
}

const martThemes = <MartTheme>[
  MartTheme('classic', 'Classic', 'បុរាណ'),
  MartTheme('minimal', 'Minimal', 'សាមញ្ញបំផុត', head: 'left', rule: 'none', items: 'compact', base: 11),
  MartTheme('bold', 'Bold', 'ដិត', rule: 'thick', total: 'invert', caps: true),
  MartTheme('mono', 'Mono', 'ម៉ូណូ', font: 'mono', total: 'box'),
  MartTheme('typewriter', 'Typewriter', 'ម៉ាស៊ីនអង្គុលីលេខ', font: 'mono', head: 'left', rule: 'dots', total: 'underline', items: 'compact', caps: true),
  MartTheme('serif', 'Elegant', 'ប្រណិត', font: 'serif', rule: 'double'),
  MartTheme('modern', 'Modern', 'ទំនើប', head: 'split', rule: 'solid', total: 'big'),
  MartTheme('market', 'Market', 'ផ្សារ', head: 'banner', total: 'box', caps: true),
  MartTheme('banner', 'Banner', 'បដា', head: 'banner', rule: 'solid', total: 'invert'),
  MartTheme('boxed', 'Boxed', 'ប្រអប់', head: 'boxed', rule: 'solid', total: 'box', foot: 'box'),
  MartTheme('double', 'Double line', 'បន្ទាត់ពីរ', font: 'serif', rule: 'double', total: 'double', frame: 'double'),
  MartTheme('dotted', 'Dotted', 'ចំណុច', rule: 'dots'),
  MartTheme('stars', 'Stars', 'ផ្កាយ', rule: 'stars', total: 'box', orn: '★'),
  MartTheme('wave', 'Wave', 'រលក', font: 'round', rule: 'wave'),
  MartTheme('kiosk', 'Kiosk', 'តូប', font: 'mono', head: 'banner', rule: 'solid', total: 'big', items: 'compact', caps: true),
  MartTheme('compact', 'Compact', 'តូចល្មម', head: 'left', items: 'compact', base: 10.5),
  MartTheme('large', 'Large print', 'អក្សរធំ', rule: 'solid', total: 'big', base: 14),
  MartTheme('table', 'Table', 'តារាង', rule: 'solid', items: 'table'),
  MartTheme('zebra', 'Stripes', 'ឆ្នូត', head: 'left', rule: 'none', total: 'box', items: 'zebra'),
  MartTheme('ticket', 'Ticket', 'សំបុត្រ', font: 'mono', head: 'boxed', total: 'big', foot: 'ticket'),
  MartTheme('coupon', 'Coupon', 'គូប៉ុង', total: 'box', foot: 'box', frame: 'dashed'),
  MartTheme('retro', 'Retro', 'បែបចាស់', font: 'mono', head: 'banner', rule: 'double', total: 'invert', caps: true),
  MartTheme('cafe', 'Café', 'កាហ្វេ', font: 'serif', rule: 'dots', total: 'underline', orn: '◆'),
  MartTheme('bakery', 'Bakery', 'នំប៉័ង', font: 'round', rule: 'wave', total: 'box', foot: 'box', orn: '❖'),
  MartTheme('fresh', 'Fresh', 'ស្រស់', font: 'round', head: 'split', rule: 'dots', total: 'big'),
  MartTheme('night', 'Night', 'យប់', head: 'banner', rule: 'thick', total: 'invert', items: 'zebra'),
  MartTheme('corporate', 'Corporate', 'ក្រុមហ៊ុន', head: 'left', rule: 'solid', total: 'double', items: 'table'),
  MartTheme('left', 'Simple left', 'ឆ្វេងសាមញ្ញ', head: 'left'),
  MartTheme('split', 'Split header', 'ក្បាលបំបែក', head: 'split', total: 'box'),
  MartTheme('bigtotal', 'Big total', 'សរុបធំ', total: 'big', items: 'compact'),
  MartTheme('underline', 'Underline', 'គូសបន្ទាត់', font: 'serif', head: 'left', rule: 'solid', total: 'underline'),
  MartTheme('stamp', 'Paid stamp', 'ត្រាបានបង់', font: 'mono', foot: 'stamp'),
  MartTheme('festive', 'Festive', 'បុណ្យ', font: 'display', rule: 'stars', total: 'invert', foot: 'box', orn: '✦'),
  MartTheme('khmer', 'Khmer classic', 'ខ្មែរបុរាណ', font: 'display', head: 'big', rule: 'double', total: 'box', orn: '❀'),
  MartTheme('angkor', 'Angkor', 'អង្គរ', font: 'display', head: 'banner', rule: 'thick', total: 'invert', items: 'table', foot: 'box', orn: '◆', frame: 'solid'),
  MartTheme('lotus', 'Lotus', 'ផ្កាឈូក', font: 'serif', rule: 'wave', total: 'box', orn: '❀'),
];
MartTheme martThemeOf(Object? key) => martThemes.firstWhere((t) => t.key == key, orElse: () => martThemes.first);

// a made-up sale to show what a template looks like (themes.js SAMPLE_SALE)
const martSampleSale = <String, dynamic>{
  'no': 'S-000128',
  'at': '2026-10-12T09:41:00.000Z',
  'currency': 'USD',
  'khr_rate': 4100,
  'items': [
    {'name': 'Coca-Cola 330ml', 'qty': 2, 'price': 0.6, 'total': 1.2, 'unit_en': 'can', 'unit_km': 'កំប៉ុង'},
    {'name': 'Bread', 'qty': 1, 'price': 1.25, 'total': 1.25, 'unit_en': 'piece', 'unit_km': 'ដុំ'},
    {'name': "Lay's Classic", 'qty': 3, 'price': 0.75, 'total': 2.25, 'unit_en': 'pack', 'unit_km': 'កញ្ចប់'},
  ],
  'subtotal': 4.7,
  'discount': 0,
  'total': 4.7,
  'method': 'cash',
  'paid_usd': 5,
  'paid_khr': 0,
  'change': 0.3,
  'change_khr': 1200,
  'status': 'paid',
  'by': 'Sokha',
};

const _monEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monKm = ['មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា', 'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ'];
String _when(Object? v, String lang) {
  final d = DateTime.tryParse('${v ?? ''}')?.toUtc().add(const Duration(hours: 7));
  if (d == null) return '';
  String p(int x) => x.toString().padLeft(2, '0');
  return '${p(d.day)} ${(lang == 'km' ? _monKm : _monEn)[d.month - 1]} ${d.year}, ${p(d.hour)}:${p(d.minute)}';
}

// one receipt on paper, drawn natively in the chosen template
class MartReceipt extends StatelessWidget {
  final Json sale, shop;
  final String Function(String key) m; // mart.* words
  final String Function(String method, String? saved) methodName;
  final String lang, theme, size;
  const MartReceipt({super.key, required this.sale, required this.shop, required this.m, required this.methodName, required this.lang, this.theme = 'classic', this.size = '80'});

  @override
  Widget build(BuildContext context) {
    final t = martThemeOf(theme);
    final base = t.base;
    final cur = str(sale['currency']).isEmpty ? 'USD' : str(sale['currency']);
    String mo(Object? v) => money(v, cur);
    String usd(Object? v) => money(v, 'USD');
    final (family, fallback) = switch (t.font) {
      'serif' => ('Georgia', const ['Times New Roman', 'serif', 'KantumruyPro']),
      'mono' => ('Courier New', const ['Courier', 'monospace', 'KantumruyPro']),
      'round' => ('PlusJakartaSans', const ['KantumruyPro']),
      _ => ('KantumruyPro', const <String>['sans-serif']),
    };
    final style = TextStyle(fontFamily: family, fontFamilyFallback: fallback, fontSize: base, height: 1.38, color: Colors.black);
    String cap(String s) => t.caps ? s.toUpperCase() : s;
    final capStyle = t.caps ? style.copyWith(letterSpacing: base * .06) : style;
    final small = style.copyWith(fontSize: base - 1);
    final items = objs(sale['items']);
    String unitOf(Json l) {
      final km = str(l['unit_km']), en = str(l['unit_en']);
      return lang == 'km' ? (km.isNotEmpty ? km : en) : (en.isNotEmpty ? en : km);
    }

    String lineTotal(Json l) => mo(l['total'] ?? n(l['price']) * n(l['qty']));
    Widget rule() => _MRule(t.rule, base);

    // head
    final logo = str(shop['logo_url']);
    final banner = t.head == 'banner';
    final ink = banner ? Colors.white : Colors.black;
    final nameStyle = (t.font == 'display' ? style.copyWith(fontWeight: FontWeight.w700, letterSpacing: .3) : style.copyWith(fontWeight: FontWeight.w700)).copyWith(
      fontSize: base + (t.head == 'big' ? 9 : 4),
      color: ink,
    );
    final orn = t.orn.isEmpty ? '' : '${t.orn} ';
    final ornR = t.orn.isEmpty ? '' : ' ${t.orn}';
    final nameText = Text('$orn${cap(str(shop['name']))}$ornR', textAlign: t.head == 'left' ? TextAlign.left : (t.head == 'split' ? TextAlign.right : TextAlign.center), style: nameStyle);
    final subs = [
      for (final s in [str(shop['address']), str(shop['phone'])])
        if (s.isNotEmpty)
          Text(
            s,
            textAlign: t.head == 'left' ? TextAlign.left : (t.head == 'split' ? TextAlign.right : TextAlign.center),
            style: small.copyWith(color: ink),
          ),
    ];
    Widget logoImg(double h, double w) => logo.isEmpty
        ? const SizedBox.shrink()
        : ConstrainedBox(
            constraints: BoxConstraints(maxHeight: h, maxWidth: w),
            child: Image(image: netImage(logo), fit: BoxFit.contain, color: banner ? Colors.white : null, colorBlendMode: banner ? BlendMode.srcIn : null, errorBuilder: (_, _, _) => const SizedBox.shrink()),
          );
    Widget head;
    if (t.head == 'split') {
      head = Row(
        children: [
          if (logo.isNotEmpty) ...[logoImg(38, 80), const SizedBox(width: 8)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [nameText, ...subs]),
          ),
        ],
      );
    } else {
      final left = t.head == 'left';
      head = Column(
        crossAxisAlignment: left ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          if (logo.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 2), child: logoImg(42, 150)),
          nameText,
          ...subs,
        ],
      );
      if (t.head == 'boxed') {
        head = Container(
          width: double.infinity,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(border: Border.all(width: 2), borderRadius: BorderRadius.circular(4)),
          child: head,
        );
      } else if (banner) {
        head = Container(width: double.infinity, color: Colors.black, padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: head);
      } else if (!left) {
        head = SizedBox(width: double.infinity, child: head);
      }
    }

    // items
    final subStyle = style.copyWith(fontSize: base - 1.5, color: const Color(0xFF222222));
    Widget itemsBox;
    if (t.items == 'table') {
      final th = capStyle.copyWith(fontSize: base - 1, fontWeight: FontWeight.w700);
      itemsBox = Table(
        columnWidths: const {0: FlexColumnWidth(), 1: IntrinsicColumnWidth(), 2: IntrinsicColumnWidth()},
        children: [
          TableRow(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide())),
            children: [
              Text(cap(m('item')), style: th),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(cap(m('qty')), textAlign: TextAlign.center, style: th),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(cap(m('total')), textAlign: TextAlign.right, style: th),
              ),
            ],
          ),
          for (final l in items)
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(str(l['name']), style: style),
                      Text(mo(l['price']), style: subStyle),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text('${qtyOf(l['qty'])}${unitOf(l).isNotEmpty ? ' ${unitOf(l)}' : ''}', textAlign: TextAlign.center, style: style),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6, top: 2),
                  child: Text(lineTotal(l), textAlign: TextAlign.right, style: style),
                ),
              ],
            ),
        ],
      );
    } else if (t.items == 'compact') {
      itemsBox = Column(
        children: [
          for (final l in items)
            _Line(
              left: Text('${qtyOf(l['qty'])}× ${str(l['name'])}', style: style),
              right: Text(lineTotal(l), style: style),
            ),
        ],
      );
    } else {
      final zebra = t.items == 'zebra';
      itemsBox = Column(
        children: [
          for (final (i, l) in items.indexed)
            Container(
              color: zebra && i.isEven ? const Color(0xFFE9E9E9) : null,
              padding: EdgeInsets.symmetric(horizontal: zebra ? 3 : 0, vertical: zebra ? 1 : 0),
              child: _Line(
                left: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(str(l['name']), style: style),
                    Text('${qtyOf(l['qty'])}${unitOf(l).isNotEmpty ? ' ${unitOf(l)}' : ''} × ${mo(l['price'])}', style: subStyle),
                  ],
                ),
                right: Text(lineTotal(l), style: style),
              ),
            ),
        ],
      );
    }

    // sums
    final method = str(sale['method']);
    final paid = method == 'cash'
        ? [if (n(sale['paid_usd']) > 0) usd(sale['paid_usd']), if (n(sale['paid_khr']) > 0) riel(sale['paid_khr'])].join(' + ')
        : method == 'debt'
        ? str(sale['debtor_name'])
        : mo(sale['total']);
    Widget sumRow(String a, String b, {TextStyle? s}) => _Line(
      left: Text(cap(a), style: (s ?? style).merge(t.caps ? TextStyle(letterSpacing: base * .06) : null)),
      right: Text(b, style: s ?? style),
    );
    final totStyle = style.copyWith(fontWeight: FontWeight.w700, fontSize: base + (t.total == 'big' ? 10 : 3), color: t.total == 'invert' ? Colors.white : Colors.black);
    Widget total = Padding(
      padding: EdgeInsets.symmetric(vertical: t.total == 'big' ? 6 : 4, horizontal: (t.total == 'box' || t.total == 'invert') ? 6 : 0),
      child: sumRow(m('total'), mo(sale['total']), s: totStyle),
    );
    total = switch (t.total) {
      'box' => Container(
        decoration: BoxDecoration(border: Border.all(width: 2)),
        child: total,
      ),
      'invert' => Container(color: Colors.black, child: total),
      'underline' => Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(width: 2))),
        child: total,
      ),
      'double' => Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide()),
          color: Colors.white,
        ),
        child: Column(children: [total, const _DoubleLine()]),
      ),
      _ => total,
    };
    final pointsWord = lang == 'km' ? 'ពិន្ទុ' : 'Points';
    final sums = Column(
      children: [
        if (n(sale['discount']) > 0 || n(sale['promo_discount']) > 0 || n(sale['points_value']) > 0) sumRow(m('subtotal'), mo(sale['subtotal'])),
        for (final p in objs(sale['promos'])) sumRow('🏷 ${str(p['name'])}', '−${mo(p['amount'])}'),
        if (n(sale['discount']) > 0) sumRow(m('discount'), '−${mo(sale['discount'])}'),
        if (n(sale['points_value']) > 0) sumRow('🎁 $pointsWord (${qtyOf(sale['points_used'])})', '−${mo(sale['points_value'])}'),
        total,
        if (cur == 'USD')
          Align(
            alignment: Alignment.centerRight,
            child: Text(riel((n(sale['total']) * (n(sale['khr_rate']) == 0 ? 4100 : n(sale['khr_rate'])) / 100).round() * 100), style: style.copyWith(fontSize: base - .5)),
          ),
        sumRow(methodName(method, str(sale['method_name'])), paid.isEmpty ? mo(sale['total']) : paid),
        if (method == 'cash' && n(sale['change']) > 0)
          sumRow(m('change'), '${mo(sale['change'])}${cur == 'USD' ? ' = ${riel(sale['change_khr'])}' : ''}', s: style.copyWith(fontWeight: FontWeight.w700)),
      ],
    );

    // foot
    final phone = str(sale['member_phone']);
    final masked = phone.replaceAllMapped(RegExp(r'\d(?=\d{3})'), (_) => '•');
    final footLines = [
      if (phone.isNotEmpty)
        '${lang == 'km' ? 'សមាជិក' : 'Member'}: ${str(sale['member_name'])} $masked${n(sale['points_earned']) > 0 ? ' · +${qtyOf(sale['points_earned'])} ${lang == 'km' ? 'ពិន្ទុ' : 'points'}' : ''}',
      if (str(sale['by']).isNotEmpty) '${m('cashier')}: ${str(sale['by'])}',
      if (str(shop['receipt_note']).isNotEmpty) str(shop['receipt_note']),
    ];
    Widget foot = SizedBox(
      width: double.infinity,
      child: Column(
        children: [for (final l in footLines) Text(l, textAlign: TextAlign.center, style: small)],
      ),
    );
    if (t.foot == 'box' && footLines.isNotEmpty) {
      foot = Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(border: Border.all(), borderRadius: BorderRadius.circular(4)),
        child: foot,
      );
    }

    final voided = sale['status'] == 'void';
    Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        head,
        rule(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(str(sale['no']).isEmpty ? '—' : str(sale['no']), style: small),
            Flexible(
              child: Text(_when(sale['at'], lang), textAlign: TextAlign.right, style: small),
            ),
          ],
        ),
        rule(),
        itemsBox,
        rule(),
        sums,
        if (voided)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(border: Border.all(width: 3)),
            child: Text(
              m('voided').toUpperCase(),
              textAlign: TextAlign.center,
              style: style.copyWith(fontWeight: FontWeight.w800, fontSize: base + 4, letterSpacing: base * .2),
            ),
          ),
        rule(),
        foot,
        if (t.foot == 'ticket')
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              str(sale['no']),
              textAlign: TextAlign.center,
              style: style.copyWith(fontWeight: FontWeight.w700, fontSize: base + 8, letterSpacing: base * .12),
            ),
          ),
        if (t.foot == 'stamp' && !voided)
          Center(
            child: Transform.rotate(
              angle: -0.14,
              child: Container(
                margin: const EdgeInsets.fromLTRB(0, 8, 0, 2),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(border: Border.all(width: 3), borderRadius: BorderRadius.circular(40)),
                child: Text(
                  m('paidStamp'),
                  style: style.copyWith(fontWeight: FontWeight.w800, letterSpacing: base * .2),
                ),
              ),
            ),
          ),
      ],
    );
    if (t.frame != 'none') {
      body = Container(
        padding: const EdgeInsets.all(9),
        decoration: t.frame == 'dashed' ? null : BoxDecoration(border: Border.all(width: t.frame == 'double' ? 1 : 2)),
        foregroundDecoration: null,
        child: t.frame == 'double'
            ? Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(border: Border.all()),
                child: body,
              )
            : body,
      );
      if (t.frame == 'dashed') body = CustomPaint(foregroundPainter: _DashBox(), child: body);
    }
    return ReceiptPaper(
      size: size == '58' ? 58 : 80,
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: DefaultTextStyle(style: style, child: body),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final Widget left, right;
  const _Line({required this.left, required this.right});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1.5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 6),
        right,
      ],
    ),
  );
}

class _DoubleLine extends StatelessWidget {
  const _DoubleLine();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(height: 1, color: Colors.black),
      const SizedBox(height: 2),
      Container(height: 1, color: Colors.black),
    ],
  );
}

class _MRule extends StatelessWidget {
  final String kind;
  final double base;
  const _MRule(this.kind, this.base);
  @override
  Widget build(BuildContext context) {
    if (kind == 'stars' || kind == 'wave') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Text(
          (kind == 'stars' ? '★ ' : '〜') * 30,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: base - 1, height: 1, letterSpacing: base * .15, color: Colors.black),
        ),
      );
    }
    if (kind == 'none') return const SizedBox(height: 8);
    if (kind == 'double') {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 5), child: _DoubleLine());
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: CustomPaint(size: Size(double.infinity, kind == 'thick' ? 3 : (kind == 'dots' ? 2 : 1)), painter: _RulePaint(kind)),
    );
  }
}

class _RulePaint extends CustomPainter {
  final String kind;
  _RulePaint(this.kind);
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.black;
    if (kind == 'solid' || kind == 'thick') {
      canvas.drawRect(Offset.zero & s, p);
      return;
    }
    if (kind == 'dots') {
      for (double x = 1; x < s.width; x += 4) {
        canvas.drawCircle(Offset(x, s.height / 2), 1, p);
      }
      return;
    }
    for (double x = 0; x < s.width; x += 6) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 3, s.height), p);
    }
  }

  @override
  bool shouldRepaint(_RulePaint o) => o.kind != kind;
}

class _DashBox extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(11)));
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DashBox o) => false;
}
