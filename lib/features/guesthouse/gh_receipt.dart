import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show money, mDayTime;
import '../restaurant/rest_online.dart' show shareWidgets;
import '../restaurant/rest_receipt.dart' show ReceiptPaper;
import 'gh_common.dart';

// Guest House receipt / bill in 24 templates (pos/guesthouse/GhReceipt.jsx) + the guest display looks (DisplayView.jsx).
// All black on white for receipt printers (58 / 80 mm) or A4.

class GhPrintTheme {
  final String key, en, km, enSub, kmSub, font, rule, total, head, frame;
  final bool caps, titleBand;
  final double base;
  const GhPrintTheme(
    this.key,
    this.en,
    this.km,
    this.enSub,
    this.kmSub, {
    this.font = 'sans',
    this.rule = 'dash',
    this.total = 'plain',
    this.head = 'center',
    this.frame = 'none',
    this.caps = false,
    this.titleBand = false,
    this.base = 11.5,
  });
  String name(String lang) => lang == 'km' ? km : en;
  String sub(String lang) => lang == 'km' ? kmSub : enSub;
}

const ghPrintThemes = <GhPrintTheme>[
  GhPrintTheme('classic', 'Classic', 'បុរាណ', 'The standard receipt. Free.', 'វិក្កយបត្រស្តង់ដារ។ ឥតគិតថ្លៃ។'),
  GhPrintTheme('modern', 'Modern', 'ទំនើប', 'Clean letters, solid lines, a big total.', 'អក្សរស្អាត បន្ទាត់ពេញ សរុបធំ។', font: 'round', rule: 'solid', total: 'big', head: 'left'),
  GhPrintTheme('typewriter', 'Typewriter', 'ម៉ាស៊ីនអង្គុលីលេខ', 'Old typewriter letters and double lines.', 'អក្សរម៉ាស៊ីនចាស់ បន្ទាត់ពីរជាន់។', font: 'mono', rule: 'double', caps: true),
  GhPrintTheme('bold', 'Bold', 'ដិតខ្លាំង', 'Black title band and a black total box.', 'ក្បាលខ្មៅ និងប្រអប់សរុបខ្មៅ។', rule: 'thick', total: 'invert', titleBand: true),
  GhPrintTheme('compact', 'Compact', 'តូចសន្សំក្រដាស', 'Small and tight — saves paper.', 'តូច និងតឹង — សន្សំក្រដាស។', base: 9.5, head: 'left'),
  GhPrintTheme('elegant', 'Elegant', 'ប្រណីត', 'Serif letters, centred, double lines.', 'អក្សរមានជើង នៅកណ្តាល បន្ទាត់ពីរជាន់។', font: 'serif', rule: 'double'),
  GhPrintTheme('boxed', 'Boxed', 'ប្រអប់', 'Every part in its own neat box.', 'ផ្នែកនីមួយៗនៅក្នុងប្រអប់ស្អាត។', rule: 'solid', total: 'box', frame: 'solid'),
  GhPrintTheme('columns', 'Columns', 'ជួរឈរ', 'Item · qty · amount in clear columns.', 'មុខទំនិញ · ចំនួន · តម្លៃ ជាជួរឈរច្បាស់។', rule: 'solid'),
  GhPrintTheme('biglogo', 'Big logo', 'ឡូហ្គោធំ', 'A large round logo on top — for strong brands.', 'ឡូហ្គោមូលធំខាងលើ — សម្រាប់ម៉ាកល្បី។', total: 'box'),
  GhPrintTheme('minimal', 'Minimal', 'សាមញ្ញ', 'No lines, lots of space, very light.', 'គ្មានបន្ទាត់ ស្រឡះ ស្រាល។', rule: 'none', head: 'left'),
  GhPrintTheme('khmer', 'Khmer first', 'ខ្មែរមុន', 'Every label in Khmer first, English below.', 'ពាក្យទាំងអស់ជាខ្មែរមុន អង់គ្លេសខាងក្រោម។', rule: 'double', total: 'box'),
  GhPrintTheme(
    'ticket',
    'Room ticket',
    'សំបុត្របន្ទប់',
    'Like a boarding pass: room and dates up front, tear-off stub.',
    'ដូចសំបុត្រយន្តហោះ៖ បន្ទប់ និងថ្ងៃខាងមុខ មានផ្នែកហែក។',
    font: 'mono',
    total: 'big',
  ),
  GhPrintTheme('stamp', 'Paid stamp', 'ត្រាបង់រួច', 'A round PAID (or DUE) stamp across the bill.', 'ត្រាមូល «បានបង់» (ឬ «ជំពាក់») លើវិក្កយបត្រ។', font: 'mono'),
  GhPrintTheme(
    'invoice',
    'Invoice',
    'វិក្កយបត្រផ្លូវការ',
    'Formal invoice with a \'bill to\' box — best on A4.',
    'វិក្កយបត្រផ្លូវការ មានប្រអប់អតិថិជន — ល្អបំផុតលើ A4។',
    rule: 'solid',
    total: 'double',
    head: 'left',
  ),
  GhPrintTheme(
    'folio',
    'Hotel folio',
    'បញ្ជីសណ្ឋាគារ',
    'Every night on its own line, payments as credits, running balance.',
    'យប់នីមួយៗមួយជួរ ការបង់ជាឥណទាន សមតុល្យបន្ត។',
    rule: 'solid',
    total: 'box',
  ),
  GhPrintTheme('postcard', 'Thank-you card', 'កាតអរគុណ', 'A big thank-you to the guest, then the bill.', 'អរគុណភ្ញៀវធំៗ បន្ទាប់មកវិក្កយបត្រ។', font: 'serif', rule: 'dots'),
  GhPrintTheme('retro', 'Retro', 'រ៉េត្រូ', 'All caps, dotted leaders, star lines.', 'អក្សរធំ បន្ទាត់ចុចៗ បន្ទាត់ផ្កាយ។', font: 'mono', rule: 'dots', caps: true),
  GhPrintTheme('banner', 'Banner', 'បដា', 'Black bands for the name and the total.', 'របារខ្មៅសម្រាប់ឈ្មោះ និងសរុប។', head: 'banner', total: 'invert', rule: 'solid'),
  GhPrintTheme('grid', 'Fact grid', 'ក្រឡាព័ត៌មាន', 'Room, nights and dates in a grid of boxes.', 'បន្ទប់ ចំនួនយប់ និងថ្ងៃ ក្នុងក្រឡាប្រអប់។', rule: 'solid', total: 'box'),
  GhPrintTheme(
    'regcard',
    'Registration card',
    'កាតចុះឈ្មោះ',
    'Guest details with lines to sign — guest and staff.',
    'ព័ត៌មានភ្ញៀវ និងកន្លែងចុះហត្ថលេខា — ភ្ញៀវ និងបុគ្គលិក។',
    rule: 'solid',
    head: 'left',
  ),
  GhPrintTheme('luxe', 'Luxe', 'ប្រណីតខ្ពស់', 'Double frame, serif letters, ornaments.', 'ស៊ុមពីរជាន់ អក្សរមានជើង លំអ។', font: 'serif', rule: 'double', total: 'double', frame: 'double'),
  GhPrintTheme('large', 'Large print', 'អក្សរធំ', 'Big letters and numbers — easy to read.', 'អក្សរ និងលេខធំ — ងាយអាន។', base: 14, rule: 'solid', total: 'big'),
  GhPrintTheme('zigzag', 'Zigzag', 'ក្រញាំ', 'Zigzag cuts between the parts.', 'កាត់ជាក្រញាំរវាងផ្នែកនីមួយៗ។', rule: 'zigzag'),
  GhPrintTheme('calendar', 'Calendar', 'ប្រតិទិន', 'The stay drawn as a row of calendar days.', 'ការស្នាក់នៅគូរជាជួរថ្ងៃប្រតិទិន។', rule: 'solid', total: 'box'),
];
GhPrintTheme ghPrintThemeOf(Object? key) => ghPrintThemes.firstWhere((t) => t.key == key, orElse: () => ghPrintThemes.first);

// what each template adds to the plain receipt
const _parts = <String, Set<String>>{
  'columns': {'cols'},
  'invoice': {'cols', 'invoice'},
  'grid': {'cols', 'facts'},
  'folio': {'folio'},
  'calendar': {'cal'},
  'regcard': {'reg', 'sign'},
  'ticket': {'ticket'},
  'stamp': {'stamp'},
  'khmer': {'bi'},
  'postcard': {'hello'},
  'biglogo': {'bigLogo'},
  'large': {'facts'},
  'luxe': {'orn'},
  'elegant': {'orn'},
  'retro': {'stars'},
};

// a made-up stay for the template previews
Json ghSampleStay(String lang) => {
  '_id': 'sample',
  'no': 'B-0042',
  'status': 'out',
  'room_name': '201',
  'from': '2026-10-12',
  'to': '2026-10-14',
  'rate': 25,
  'adults': 2,
  'children': 1,
  'guest': {'name': 'John Smith', 'phone': '012 345 678', 'nationality': 'UK', 'id_type': 'passport', 'id_number': 'P1234567'},
  'charges': [
    {'_id': 'c1', 'label': lang == 'km' ? 'បោកអ៊ុត' : 'Laundry', 'amount': 3, 'qty': 2},
    {'_id': 'c2', 'label': lang == 'km' ? 'ទឹកសុទ្ធ' : 'Water', 'amount': 0.5, 'qty': 4},
  ],
  'payments': [
    {'_id': 'p1', 'method': 'cash', 'amount': 20, 'at': '2026-10-12T07:30:00Z'},
    {'_id': 'p2', 'method': 'aba', 'amount': 38, 'at': '2026-10-14T04:10:00Z'},
  ],
  'discount': 0,
  'by': 'Srey',
  'bill': {'nights': 2, 'room': 50, 'extras': 8, 'discount': 0, 'total': 58, 'paid': 58, 'balance': 0},
};

String _addDays(String day, int d) => DateTime.parse('${day}T00:00:00Z').add(Duration(days: d)).toIso8601String().substring(0, 10);
String _dm(String day) {
  final d = DateTime.tryParse('${day}T00:00:00Z');
  return d == null ? '·' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

// one bill on paper, drawn natively in the chosen template
class GhReceipt extends StatelessWidget {
  final Json stay, data;
  final String lang, theme, size;
  final bool qr;
  final String staff;
  const GhReceipt({super.key, required this.stay, required this.data, required this.lang, this.theme = 'classic', this.size = '80', this.qr = true, this.staff = ''});

  @override
  Widget build(BuildContext context) {
    final th = ghPrintThemeOf(theme);
    final p = _parts[th.key] ?? const <String>{};
    final t = T.of(lang), km = T.of('km'), en = T.of('en');
    String w(String k, [Map<String, Object?> v = const {}]) => t('grc.$k', v);
    final s = stay;
    final set = obj(data['settings']);
    final biz = obj(data['business']);
    final cur = str(set['currency']).isEmpty ? 'USD' : str(set['currency']);
    final rate = n(set['khr_rate']) == 0 ? 4100 : n(set['khr_rate']);
    final b = obj(s['bill']);
    final guest = obj(s['guest']);
    final nights = n(b['nights']).toInt();
    final total = n(b['total']), balance = n(b['balance']);
    final paidUp = balance <= 0 && total > 0;
    String m(Object? v) => money(v, cur);
    final base = th.base * (size == 'a4' ? 1.15 : 1);

    final (family, fallback) = switch (th.font) {
      'serif' => ('Georgia', const ['Times New Roman', 'serif', 'KantumruyPro']),
      'mono' => ('Courier New', const ['Courier', 'monospace', 'KantumruyPro']),
      'round' => ('PlusJakartaSans', const ['KantumruyPro']),
      _ => ('KantumruyPro', const <String>['sans-serif']),
    };
    final style = TextStyle(fontFamily: family, fontFamilyFallback: fallback, fontSize: base, height: 1.38, color: Colors.black);
    final small = style.copyWith(fontSize: base * .88);
    final bold = style.copyWith(fontWeight: FontWeight.w800);
    String cap(String x) => th.caps ? x.toUpperCase() : x;

    // a label; "Khmer first" prints both languages
    Widget L(String k, {TextStyle? st}) {
      final ts = st ?? style;
      if (!p.contains('bi')) return Text(cap(w(k)), style: ts);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(km('grc.$k'), style: ts.copyWith(fontWeight: FontWeight.w700)),
          Text(en('grc.$k'), style: ts.copyWith(fontSize: (ts.fontSize ?? base) * .78)),
        ],
      );
    }

    Widget row(Widget a, String v, {TextStyle? vs}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(child: a),
          if (th.key == 'retro') const Expanded(child: _Dots()) else const Spacer(),
          const SizedBox(width: 6),
          Text(
            v,
            textAlign: TextAlign.right,
            style: vs ?? bold.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
    Widget rowT(String a, String v, {TextStyle? vs}) => row(Text(cap(a), style: style), v, vs: vs);
    Widget rule() => _GRule(th.rule, base);

    // head
    final logo = str(biz['logo_url']);
    final banner = th.head == 'banner';
    final ink = banner ? Colors.white : Colors.black;
    final left = th.head == 'left';
    final contact = [str(biz['phone']), str(set['email']), str(set['website'])].where((x) => x.isNotEmpty).join(' · ');
    final logoSize = p.contains('bigLogo') ? 70.0 : 34.0;
    Widget head = Column(
      crossAxisAlignment: left ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            shape: p.contains('bigLogo') ? BoxShape.circle : BoxShape.rectangle,
            border: p.contains('bigLogo') ? Border.all(width: 2, color: ink) : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: logo.isNotEmpty
              ? Image(image: netImage(
                  logo),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(LucideIcons.bedDouble, color: ink, size: logoSize * .7),
                )
              : Icon(LucideIcons.bedDouble, color: ink, size: logoSize * .7),
        ),
        const SizedBox(height: 3),
        Text(
          cap(str(biz['name'])),
          textAlign: left ? TextAlign.left : TextAlign.center,
          style: bold.copyWith(fontSize: base * (th.key == 'bold' ? 1.45 : 1.25), color: ink),
        ),
        if (str(biz['address']).isNotEmpty)
          Text(
            str(biz['address']),
            textAlign: left ? TextAlign.left : TextAlign.center,
            style: small.copyWith(color: ink),
          ),
        if (contact.isNotEmpty)
          Text(
            contact,
            textAlign: left ? TextAlign.left : TextAlign.center,
            style: small.copyWith(color: ink),
          ),
      ],
    );
    head = banner
        ? Container(width: double.infinity, color: Colors.black, padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6), child: head)
        : SizedBox(width: double.infinity, child: head);

    final titleText = p.contains('invoice')
        ? w('invoice')
        : p.contains('reg')
        ? w('regTitle')
        : paidUp
        ? w('receipt')
        : w('bill');
    Widget title = Text(
      titleText,
      textAlign: left ? TextAlign.left : TextAlign.center,
      style: bold.copyWith(
        fontSize: base * (th.key == 'modern' ? 1.6 : 1.12),
        letterSpacing: base * .12,
        color: th.titleBand ? Colors.white : Colors.black,
        decoration: th.key == 'typewriter' ? TextDecoration.underline : null,
      ),
    );
    title = th.titleBand ? Container(width: double.infinity, color: Colors.black, padding: const EdgeInsets.symmetric(vertical: 4), child: title) : SizedBox(width: double.infinity, child: title);

    final printedAt = mDayTime(DateTime.now().toUtc().toIso8601String(), lang);
    final meta = Column(children: [row(L('no'), str(s['no'])), row(L('date'), printedAt), if (staff.isNotEmpty || str(s['by']).isNotEmpty) row(L('staff'), staff.isNotEmpty ? staff : str(s['by']))]);

    Widget box(Widget child, {EdgeInsets pad = const EdgeInsets.all(6)}) => Container(
      padding: pad,
      decoration: BoxDecoration(border: Border.all(width: 1.2)),
      child: child,
    );

    // the guest part (registration card / invoice "bill to" / plain)
    Widget guestBlock;
    if (p.contains('reg')) {
      guestBlock = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (k, v) in [
            ('guest', str(guest['name'])),
            ('phone', str(guest['phone'])),
            ('nat', str(guest['nationality'])),
            ('id', str(guest['id_number'])),
            ('people', w('peopleV', {'a': n(s['adults']) == 0 ? 1 : n(s['adults']).toInt(), 'c': n(s['children']).toInt()})),
          ])
            Container(
              padding: const EdgeInsets.only(top: 3, bottom: 2),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(width: .8))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  L(k, st: small),
                  Text(v.isEmpty ? ' ' : v, style: bold),
                ],
              ),
            ),
        ],
      );
    } else if (p.contains('invoice')) {
      guestBlock = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: box(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  L('billTo', st: small),
                  Text(str(guest['name']), style: bold),
                  if (str(guest['phone']).isNotEmpty) Text(str(guest['phone']), style: small),
                  if (str(guest['nationality']).isNotEmpty) Text(str(guest['nationality']), style: small),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: box(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  L('stay', st: small),
                  Text('${w('room')} ${str(s['room_name'])}', style: bold),
                  Text('${ghDay(str(s['from']), lang, year: true)} → ${ghDay(str(s['to']), lang, year: true)}', style: small),
                  Text(w('nightsV', {'n': nights}), style: small),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      guestBlock = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(border: Border.all(width: 1.4), borderRadius: BorderRadius.circular(4)),
                child: Text('${cap(w('room'))} ${str(s['room_name'])}', style: bold),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(str(guest['name']), style: bold),
                    if (str(guest['phone']).isNotEmpty) Text(str(guest['phone']), style: small),
                  ],
                ),
              ),
            ],
          ),
          if (!p.contains('facts') && !p.contains('ticket')) ...[
            const SizedBox(height: 4),
            row(L('checkIn'), ghDay(str(s['from']), lang, year: true)),
            row(L('checkOut'), ghDay(str(s['to']), lang, year: true)),
            row(L('nights'), w('nightsV', {'n': nights})),
          ],
        ],
      );
    }

    Widget cell(String k, String v) => Expanded(
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
        decoration: BoxDecoration(border: Border.all(width: 1.2)),
        child: Column(
          children: [
            L(k, st: small.copyWith(fontSize: base * .72)),
            Text(v, style: bold.copyWith(fontSize: base * 1.25)),
          ],
        ),
      ),
    );
    final facts = Column(
      children: [
        Row(children: [cell('room', str(s['room_name'])), cell('nights', '$nights')]),
        Row(children: [cell('checkIn', ghDay(str(s['from']), lang)), cell('checkOut', ghDay(str(s['to']), lang))]),
      ],
    );

    final ticket = Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(border: Border.all(width: 2)),
              child: Column(
                children: [
                  L('room', st: small),
                  Text(str(s['room_name']), style: bold.copyWith(fontSize: base * 2.2)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final (k, d, h) in [
                    ('checkIn', str(s['from']), str(set['check_in']).isEmpty ? '14:00' : str(set['check_in'])),
                    ('checkOut', str(s['to']), str(set['check_out']).isEmpty ? '12:00' : str(set['check_out'])),
                  ]) ...[
                    if (k == 'checkOut') Text('→', style: bold.copyWith(fontSize: base * 1.4)),
                    Column(
                      children: [
                        L(k, st: small.copyWith(fontSize: base * .72)),
                        Text(ghDay(d, lang), style: bold.copyWith(fontSize: base * 1.2)),
                        Text(h, style: small),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Text('✂', style: style),
              const SizedBox(width: 4),
              const Expanded(child: _GRule('dash', 10)),
            ],
          ),
        ),
      ],
    );

    final nightsList = [for (var i = 0; i < nights; i++) _addDays(str(s['from']), i)];
    Widget calDay(String d, String a, String sub, {bool out = false}) => Container(
      width: base * 3.6,
      margin: const EdgeInsets.all(1.5),
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(border: Border.all(width: 1.2), color: out ? const Color(0xFFE6E6E6) : null),
      child: Column(
        children: [
          Text(ghWeekday(d, lang), style: small.copyWith(fontSize: base * .7)),
          Text(a, style: bold.copyWith(fontSize: base * 1.2)),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: small.copyWith(fontSize: base * .62),
          ),
        ],
      ),
    );
    final cal = Wrap(
      alignment: WrapAlignment.center,
      children: [
        for (final d in nightsList.take(14)) calDay(d, '${int.parse(d.substring(8))}', m(s['rate'])),
        calDay(str(s['to']), '${int.parse(str(s['to']).substring(8))}', w('checkOut'), out: true),
      ],
    );

    final extras = [
      for (final c in objs(s['charges'])) (label: str(c['label']), qty: n(c['qty']) == 0 ? 1 : n(c['qty']), unit: n(c['amount']), amount: n(c['amount']) * (n(c['qty']) == 0 ? 1 : n(c['qty']))),
    ];
    final discount = n(b['discount']);

    // folio: each night a line, payments as credits, running balance
    Widget folio() {
      num run = 0;
      final th2 = small.copyWith(fontWeight: FontWeight.w800);
      TableRow r(String a, String b2, String c2, String d, {bool cr = false, bool head = false}) => TableRow(
        decoration: head ? const BoxDecoration(border: Border(bottom: BorderSide())) : null,
        children: [
          for (final (i, x) in [a, b2, c2, d].indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5, horizontal: 2),
              child: Text(
                x,
                textAlign: i >= 2 ? TextAlign.right : TextAlign.left,
                style: head ? th2 : (cr ? small.copyWith(fontStyle: FontStyle.italic) : small),
              ),
            ),
        ],
      );
      final rows = <TableRow>[r(w('date'), w('item'), w('amount'), w('balance'), head: true)];
      for (final d in nightsList) {
        run += n(s['rate']);
        rows.add(r(_dm(d), '${w('night')} · ${str(s['room_name'])}', m(s['rate']), m(run)));
      }
      for (final c in extras) {
        run += c.amount;
        rows.add(r('·', '${c.label}${c.qty > 1 ? ' × ${c.qty.toInt()}' : ''}', m(c.amount), m(run)));
      }
      if (discount > 0) {
        run -= discount;
        rows.add(r('·', w('discount'), '−${m(discount)}', m(run)));
      }
      for (final py in objs(s['payments'])) {
        run -= n(py['amount']);
        final at = DateTime.tryParse(str(py['at']))?.toUtc().add(const Duration(hours: 7));
        rows.add(
          r(
            at == null ? '·' : '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')}',
            '${w('payment')} · ${t.or('gh.methods.${py['method']}', str(py['method']))}',
            '−${m(py['amount'])}',
            m(run),
            cr: true,
          ),
        );
      }
      return Table(columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth(), 2: IntrinsicColumnWidth(), 3: IntrinsicColumnWidth()}, children: rows);
    }

    Widget lines;
    if (p.contains('cols')) {
      final th2 = bold.copyWith(fontSize: base * .9);
      TableRow tr(Widget a, String q, String v) => TableRow(
        children: [
          Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: a),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(q, textAlign: TextAlign.center, style: style),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(v, textAlign: TextAlign.right, style: style),
          ),
        ],
      );
      Widget two(String a, String sub) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(a, style: style),
          if (sub.isNotEmpty) Text(sub, style: small.copyWith(fontSize: base * .8)),
        ],
      );
      lines = Table(
        columnWidths: const {0: FlexColumnWidth(), 1: IntrinsicColumnWidth(), 2: IntrinsicColumnWidth()},
        children: [
          TableRow(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide())),
            children: [
              L('item', st: th2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Center(child: L('qty', st: th2)),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: L('amount', st: th2),
              ),
            ],
          ),
          tr(two('${w('room')} ${str(s['room_name'])}', '${ghDay(str(s['from']), lang)} → ${ghDay(str(s['to']), lang)} · ${m(s['rate'])}'), '$nights', m(b['room'])),
          for (final c in extras) tr(two(c.label, m(c.unit)), '${c.qty.toInt()}', m(c.amount)),
          if (discount > 0) tr(Text(w('discount'), style: style), '', '−${m(discount)}'),
        ],
      );
    } else {
      lines = Column(
        children: [
          rowT(w('roomLine', {'room': str(s['room_name']), 'n': nights, 'rate': m(s['rate'])}), m(b['room'])),
          for (final c in extras) rowT('${c.label}${c.qty > 1 ? ' × ${c.qty.toInt()}' : ''}', m(c.amount)),
          if (discount > 0) row(L('discount'), '−${m(discount)}'),
        ],
      );
    }

    final invert = th.total == 'invert';
    final grandStyle = bold.copyWith(fontSize: base * (th.total == 'big' ? 1.9 : 1.25), color: invert ? Colors.white : Colors.black);
    Widget grand = Padding(
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: th.total == 'box' || invert ? 6 : 0),
      child: row(L('total', st: grandStyle), m(total), vs: grandStyle),
    );
    grand = switch (th.total) {
      'box' => Container(
        decoration: BoxDecoration(border: Border.all(width: 2)),
        child: grand,
      ),
      'invert' => Container(color: Colors.black, child: grand),
      'double' => Column(children: [grand, const _GRule('double', 10)]),
      _ => grand,
    };
    final totals = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        grand,
        if (cur == 'USD' && total > 0)
          Align(
            alignment: Alignment.centerRight,
            child: Text('≈ ${money(total * rate, 'KHR')}', style: small),
          ),
        if (!p.contains('folio') && n(b['paid']) != 0) row(L('paid'), m(b['paid'])),
        row(L(balance >= 0 ? 'toPay' : 'change'), m(balance.abs()), vs: bold.copyWith(fontSize: base * (balance > 0 ? 1.15 : 1))),
      ],
    );

    final pays = objs(s['payments']);
    final payBlock = !p.contains('folio') && pays.isNotEmpty
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              L('payments', st: small.copyWith(fontWeight: FontWeight.w800)),
              for (final py in pays) rowT('${t.or('gh.methods.${py['method']}', str(py['method']))}${str(py['at']).isNotEmpty ? ' · ${mDayTime(py['at'], lang)}' : ''}', m(py['amount'])),
            ],
          )
        : null;

    final qrUrl = str(obj(set['pay_qr'])['url']);
    final showQr = qr && balance > 0 && qrUrl.isNotEmpty;
    final orn = p.contains('orn') ? Text('✦ ❖ ✦', textAlign: TextAlign.center, style: style) : null;
    final stars = p.contains('stars') ? Text('* ' * 18, maxLines: 1, overflow: TextOverflow.clip, textAlign: TextAlign.center, style: style) : null;

    Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (p.contains('hello'))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                Text(
                  w('thanksName', {'name': str(guest['name'])}),
                  textAlign: TextAlign.center,
                  style: bold.copyWith(fontSize: base * 1.6),
                ),
                Text(w('seeYou'), textAlign: TextAlign.center, style: small),
                Text('★ ★ ★ ★ ★', style: style),
              ],
            ),
          ),
        head,
        ?orn,
        ?stars,
        const SizedBox(height: 6),
        title,
        const SizedBox(height: 4),
        meta,
        rule(),
        if (p.contains('ticket')) ticket,
        guestBlock,
        if (p.contains('facts')) ...[const SizedBox(height: 4), facts],
        if (p.contains('cal')) ...[const SizedBox(height: 6), cal],
        rule(),
        if (p.contains('folio')) folio() else lines,
        rule(),
        totals,
        ?payBlock,
        if (showQr)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              children: [
                L('scan', st: small),
                const SizedBox(height: 4),
                Image(image: netImage(qrUrl), width: 130, height: 130, fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                Text(m(balance), style: bold),
                if (str(set['pay_qr_label']).isNotEmpty) Text(str(set['pay_qr_label']), style: small),
              ],
            ),
          ),
        if (p.contains('sign'))
          Padding(
            padding: const EdgeInsets.only(top: 22),
            child: Row(
              children: [
                for (final k in ['signGuest', 'signStaff']) ...[
                  if (k == 'signStaff') const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      children: [
                        Container(height: 1, color: Colors.black),
                        const SizedBox(height: 2),
                        L(k, st: small),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ?stars,
        ?orn,
        const SizedBox(height: 8),
        if (str(set['receipt_note']).isNotEmpty) Text(str(set['receipt_note']), textAlign: TextAlign.center, style: small),
        if (!p.contains('hello')) Text(w('thanks'), textAlign: TextAlign.center, style: bold),
        if (str(set['telegram']).isNotEmpty) Text('Telegram: ${set['telegram']}', textAlign: TextAlign.center, style: small),
      ],
    );

    if (th.frame != 'none') {
      body = Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(border: Border.all(width: th.frame == 'double' ? 1 : 2)),
        child: th.frame == 'double'
            ? Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(border: Border.all()),
                child: body,
              )
            : body,
      );
    }
    if (p.contains('stamp')) {
      body = Stack(
        children: [
          body,
          Positioned(
            top: 120,
            right: 14,
            child: Transform.rotate(
              angle: -0.3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(width: 3, color: Colors.black.withValues(alpha: .75)),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Text(
                  paidUp ? w('stampPaid') : w('stampDue'),
                  style: bold.copyWith(fontSize: base * 1.6, letterSpacing: base * .2, color: Colors.black.withValues(alpha: .75)),
                ),
              ),
            ),
          ),
        ],
      );
    }
    final inner = Padding(
      padding: EdgeInsets.all(size == 'a4' ? 22 : 11),
      child: DefaultTextStyle(style: style, child: body),
    );
    if (size == 'a4') {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: inner,
        ),
      );
    }
    return ReceiptPaper(size: size == '58' ? 58 : 80, child: inner);
  }
}

class _Dots extends StatelessWidget {
  const _Dots();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 4),
    child: CustomPaint(size: const Size(double.infinity, 2), painter: _RulePaint('dots')),
  );
}

class _GRule extends StatelessWidget {
  final String kind;
  final double base;
  const _GRule(this.kind, this.base);
  @override
  Widget build(BuildContext context) {
    if (kind == 'none') return const SizedBox(height: 10);
    if (kind == 'double') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          children: [
            Container(height: 1, color: Colors.black),
            const SizedBox(height: 2),
            Container(height: 1, color: Colors.black),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: CustomPaint(
        size: Size(double.infinity, switch (kind) {
          'thick' => 3,
          'zigzag' => 6,
          'dots' => 2,
          _ => 1,
        }),
        painter: _RulePaint(kind),
      ),
    );
  }
}

class _RulePaint extends CustomPainter {
  final String kind;
  _RulePaint(this.kind);
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.black;
    switch (kind) {
      case 'solid' || 'thick':
        canvas.drawRect(Offset.zero & s, p);
      case 'dots':
        for (double x = 1; x < s.width; x += 4) {
          canvas.drawCircle(Offset(x, s.height / 2), 1, p);
        }
      case 'zigzag':
        final path = Path()..moveTo(0, s.height);
        for (double x = 0; x < s.width; x += 8) {
          path
            ..lineTo(x + 4, 0)
            ..lineTo(x + 8, s.height);
        }
        canvas.drawPath(
          path,
          p
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      default:
        for (double x = 0; x < s.width; x += 6) {
          canvas.drawRect(Rect.fromLTWH(x, 0, 3, s.height), p);
        }
    }
  }

  @override
  bool shouldRepaint(_RulePaint o) => o.kind != kind;
}

// the bill on paper + share it (the app's way to print)
Future<void> showGhBill(BuildContext context, GhCtx ctx, Json stay) {
  final key = GlobalKey();
  final pc = ctx.print;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (s) {
      final c = s.c;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(ctx.g('printBill'), style: Theme.of(s).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(18)),
                child: RepaintBoundary(
                  key: key,
                  child: GhReceipt(stay: stay, data: ctx.data, lang: ctx.lang, theme: str(pc['theme']), size: str(pc['size']), qr: pc['qr'] == true),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.line)),
            ),
            child: Row(
              children: [
                Expanded(child: Muted(ctx.t('app.printShare'))),
                const SizedBox(width: 10),
                Btn(ctx.t('app.shareReceipt'), icon: LucideIcons.share2, small: true, onTap: () => shareWidgets([key], (_) => 'bill-${str(stay['no'])}.png')),
              ],
            ),
          ),
        ],
      );
    },
  );
}

// ------------------------------------------------------------------------------------------- guest display looks
class GhLook {
  final String en, km, layout, font;
  final List<Color> bg;
  final Color ink, card, accent;
  final bool cardLight;
  const GhLook(this.en, this.km, this.layout, this.bg, this.ink, this.card, this.accent, {this.font = 'sans', this.cardLight = false});
}

const ghLooks = <String, GhLook>{
  'classic': GhLook('Classic', 'បុរាណ', 'split', [Color(0xFF1E3A8A), Color(0xFF0F172A)], Color(0xFFF8FAFC), Color(0x14FFFFFF), Color(0xFF34D399)),
  'paper': GhLook('Paper receipt', 'វិក្កយបត្រក្រដាស', 'receipt', [Color(0xFFFDF6E3), Color(0xFFEADFC8)], Color(0xFF3B2F22), Colors.white, Color(0xFFB91C1C), font: 'mono', cardLight: true),
  'resort': GhLook('Resort', 'រីសត', 'hero', [Color(0xFF7DB9A0), Color(0xFF1F3B2D)], Color(0xFF1F3B2D), Color(0xFFF4F1EA), Color(0xFF0F766E), cardLight: true),
  'gold': GhLook('Black & gold', 'ខ្មៅ & មាស', 'center', [Color(0xFF2A2414), Color(0xFF0B0B0B)], Color(0xFFF3E7C4), Color(0x14D4AF37), Color(0xFFD4AF37), font: 'serif'),
  'sunrise': GhLook('Sunrise', 'ថ្ងៃរះ', 'split', [Color(0xFFFF9A56), Color(0xFFFF6A88), Color(0xFFFF99AC)], Colors.white, Color(0x33FFFFFF), Colors.white),
  'minimal': GhLook('Minimal', 'សាមញ្ញ', 'total', [Color(0xFFFAFAFA), Color(0xFFFAFAFA)], Color(0xFF111111), Colors.white, Color(0xFF111111), cardLight: true),
  'neon': GhLook('Neon night', 'រាត្រីនីអុង', 'split', [Color(0xFF07040F), Color(0xFF120A2A)], Color(0xFFE8F7FF), Color(0x0AFFFFFF), Color(0xFF22D3EE)),
  'khmer': GhLook('Khmer heritage', 'បេតិកភណ្ឌខ្មែរ', 'split', [Color(0xFF8B1A1A), Color(0xFF4A0B0B)], Color(0xFFFBE7B5), Color(0x40000000), Color(0xFFF5C451)),
  'ocean': GhLook('Ocean', 'សមុទ្រ', 'stack', [Color(0xFF0EA5E9), Color(0xFF0E7490), Color(0xFF134E4A)], Colors.white, Color(0x26FFFFFF), Color(0xFFFDE68A)),
  'boutique': GhLook('Boutique', 'ប៊ូទិក', 'center', [Color(0xFFFBEEE6), Color(0xFFF4DCD6)], Color(0xFF5B3A3A), Colors.white, Color(0xFFB4535B), font: 'serif', cardLight: true),
  'forest': GhLook('Forest lodge', 'ផ្ទះព្រៃ', 'split', [Color(0xFF1D3A2A), Color(0xFF0F2419)], Color(0xFFF1EAD9), Color(0x0FFFFFFF), Color(0xFFE9C46A)),
  'split': GhLook('Bold split', 'ពីរផ្នែក', 'total', [Colors.white, Colors.white], Color(0xFF111827), Color(0xFFF3F4F6), Color(0xFF2563EB), cardLight: true),
};
String ghLookName(String k, String lang) => lang == 'km' ? (ghLooks[k]?.km ?? k) : (ghLooks[k]?.en ?? k);

// the guest display (1280×720) in one look, scaled to fit — sample bill like DisplayView.jsx SAMPLE
class GhDisplayThumb extends StatelessWidget {
  final String look, name, logo, image, lang;
  const GhDisplayThumb({super.key, required this.look, required this.name, this.logo = '', this.image = '', required this.lang});
  @override
  Widget build(BuildContext context) {
    final l = ghLooks[look] ?? ghLooks['classic']!;
    final t = T.of(lang);
    String w(String k, [Map<String, Object?> v = const {}]) => t('gdv.$k', v);
    final family = switch (l.font) {
      'serif' => 'Georgia',
      'mono' => 'Courier New',
      _ => 'KantumruyPro',
    };
    final ink = l.ink;
    final cardInk = l.cardLight && l.layout == 'hero' ? const Color(0xFF1F3B2D) : ink;
    final base = TextStyle(fontFamily: family, fontFamilyFallback: const ['KantumruyPro'], color: ink, fontSize: 22, height: 1.3);
    final accent = l.accent;

    Widget big({Color? bg, Color? fg}) => Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(w('toPay'), style: base.copyWith(color: (fg ?? ink).withValues(alpha: .75))),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '\$36.00',
              style: base.copyWith(fontSize: 96, fontWeight: FontWeight.w800, color: fg ?? accent, height: 1.1),
            ),
          ),
          Text('${w('room')} 201 · John Smith', style: base.copyWith(color: (fg ?? ink).withValues(alpha: .85))),
        ],
      ),
    );
    Widget lineRow(String a, String b, {bool strong = false, Color? col}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              a,
              style: base.copyWith(color: col ?? cardInk, fontWeight: strong ? FontWeight.w800 : FontWeight.w400),
            ),
          ),
          Text(
            b,
            style: base.copyWith(color: col ?? cardInk, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
    final bill = Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: l.card,
        borderRadius: BorderRadius.circular(l.font == 'mono' ? 4 : 24),
        border: look == 'gold' || look == 'khmer' || look == 'neon' ? Border.all(color: accent.withValues(alpha: .6), width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${w('room')} 201',
            style: base.copyWith(color: accent, fontWeight: FontWeight.w800, fontSize: 20),
          ),
          Text(
            'John Smith',
            style: base.copyWith(color: cardInk, fontWeight: FontWeight.w800, fontSize: 30),
          ),
          Text('12 Oct → 14 Oct · ${w('nights', {'n': 2})}', style: base.copyWith(color: cardInk.withValues(alpha: .7), fontSize: 18)),
          const SizedBox(height: 10),
          lineRow('${w('nights', {'n': 2})} × \$25.00', '\$50.00'),
          lineRow('Laundry × 2', '\$6.00'),
          Divider(color: cardInk.withValues(alpha: .25)),
          lineRow(w('total'), '\$56.00', strong: true),
          lineRow(w('paid'), '\$20.00'),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: accent.withValues(alpha: .18), borderRadius: BorderRadius.circular(14)),
            child: lineRow(w('toPay'), '\$36.00', strong: true, col: l.cardLight ? accent : null),
          ),
        ],
      ),
    );
    final qr = Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: l.card, borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            w('scan'),
            style: base.copyWith(color: cardInk, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Container(
            width: 190,
            height: 190,
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            child: const CustomPaint(painter: _FakeQr()),
          ),
          const SizedBox(height: 8),
          Text(
            '\$36.00',
            style: base.copyWith(color: cardInk, fontWeight: FontWeight.w800, fontSize: 30),
          ),
          Text('ABA · $name', style: base.copyWith(color: cardInk.withValues(alpha: .7), fontSize: 16)),
        ],
      ),
    );

    final Widget body = switch (l.layout) {
      'total' => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: big(bg: accent, fg: look == 'minimal' ? Colors.white : Colors.white),
          ),
          const SizedBox(width: 26),
          Expanded(flex: 5, child: Center(child: bill)),
          const SizedBox(width: 26),
          Expanded(flex: 3, child: Center(child: qr)),
        ],
      ),
      'center' => Column(
        children: [
          big(),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Expanded(flex: 5, child: bill),
                const SizedBox(width: 26),
                Expanded(flex: 3, child: qr),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
      'stack' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 210, child: big()),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: bill),
                const SizedBox(width: 26),
                Expanded(child: qr),
              ],
            ),
          ),
        ],
      ),
      'receipt' => Row(
        children: [
          Expanded(child: big()),
          SizedBox(width: 400, child: bill),
          const SizedBox(width: 40),
          Expanded(child: Center(child: qr)),
        ],
      ),
      _ => Row(
        children: [
          Expanded(flex: 4, child: big()),
          const SizedBox(width: 26),
          Expanded(flex: 5, child: bill),
          const SizedBox(width: 26),
          Expanded(flex: 3, child: qr),
        ],
      ),
    };

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: 1280,
          height: 720,
          child: Container(
            decoration: BoxDecoration(
              gradient: l.layout == 'hero'
                  ? null
                  : LinearGradient(
                      begin: look == 'ocean' ? Alignment.topCenter : Alignment.topLeft,
                      end: look == 'ocean' ? Alignment.bottomCenter : Alignment.bottomRight,
                      colors: l.bg.length == 1 ? [l.bg.first, l.bg.first] : l.bg,
                    ),
              color: l.layout == 'hero' ? l.bg.last : null,
              image: l.layout == 'hero' && image.isNotEmpty ? DecorationImage(image: netImage(image), fit: BoxFit.cover) : null,
            ),
            child: Container(
              decoration: l.layout == 'hero'
                  ? BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: .1), Colors.black.withValues(alpha: .45)]),
                    )
                  : null,
              padding: const EdgeInsets.fromLTRB(36, 24, 36, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: ink.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
                        clipBehavior: Clip.antiAlias,
                        child: logo.isNotEmpty
                            ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())
                            : Icon(LucideIcons.bedDouble, color: l.layout == 'hero' ? Colors.white : ink, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: base.copyWith(fontWeight: FontWeight.w800, fontSize: 28, color: l.layout == 'hero' ? Colors.white : ink),
                        ),
                      ),
                      Text('09:41', style: base.copyWith(fontSize: 26, color: l.layout == 'hero' ? Colors.white : ink)),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Expanded(
                    child: l.layout == 'hero'
                        ? Row(
                            children: [
                              Expanded(child: big(fg: Colors.white)),
                              SizedBox(width: 480, child: bill),
                              const SizedBox(width: 26),
                              qr,
                            ],
                          )
                        : body,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// a QR-looking pattern for previews (not scannable)
class _FakeQr extends CustomPainter {
  const _FakeQr();
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = const Color(0xFF111111);
    final c = s.width / 21;
    for (var y = 0; y < 21; y++) {
      for (var x = 0; x < 21; x++) {
        final finder = (x < 7 && y < 7) || (x > 13 && y < 7) || (x < 7 && y > 13);
        final on = finder ? (x % 7 == 0 || y % 7 == 0 || x % 7 == 6 || y % 7 == 6 || (x % 7 > 1 && x % 7 < 5 && y % 7 > 1 && y % 7 < 5)) : (x * 7 + y * 13 + x * y) % 3 == 0;
        if (on) canvas.drawRect(Rect.fromLTWH(x * c, y * c, c, c), p);
      }
    }
  }

  @override
  bool shouldRepaint(_FakeQr o) => false;
}
