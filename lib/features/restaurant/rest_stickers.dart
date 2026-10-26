import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../widgets/ui.dart';

// Table QR stickers in all 11 looks (QrSticker.jsx + qr-stickers.css) and a small guest ordering page per look
// (OrderThemeMock.jsx). Drawn at 240 px wide (80 mm on paper).

class QrSticker extends StatelessWidget {
  final String theme; // classic | minimal | block | tent | kraft | neon | gold | bubble | khmer | polaroid | ticket
  final Color color;
  final String logo, shop, table, data;
  final String scan, tableWord;
  const QrSticker({
    super.key,
    this.theme = 'classic',
    required this.color,
    required this.logo,
    required this.shop,
    required this.table,
    required this.data,
    this.scan = 'ស្កេនដើម្បីមើលម៉ឺនុយ · Scan to see the menu',
    this.tableWord = 'តុ · Table',
  });

  @override
  Widget build(BuildContext context) {
    if (theme == 'tent') {
      return SizedBox(
        width: 240,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RotatedBox(quarterTurns: 2, child: _face(tentTop: true)),
            _face(tentBottom: true),
          ],
        ),
      );
    }
    return SizedBox(width: 240, child: _face());
  }

  Widget _qr({double size = 150, double pad = 6, BoxBorder? border, double radius = 0}) => Container(
    padding: EdgeInsets.all(pad),
    decoration: BoxDecoration(color: Colors.white, border: border, borderRadius: BorderRadius.circular(radius)),
    child: data.isEmpty
        ? Container(width: size, height: size, color: const Color(0xFFEEEEEE))
        : QrImageView(
            data: data,
            size: size,
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF16171B)),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF16171B)),
          ),
  );

  Widget _face({bool tentTop = false, bool tentBottom = false}) {
    const ink = Color(0xFF111111);
    Color fg = ink, top = ink, tableC = ink;
    BoxDecoration deco = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: ink, width: 2),
    );
    EdgeInsets pad = const EdgeInsets.fromLTRB(18, 18, 18, 20);
    String? topFont, tableFont;
    FontWeight tableW = FontWeight.w900, topW = FontWeight.w800;
    double tableSize = 40;
    Widget qr = _qr();
    Widget scanW(Color c) => Text(
      scan,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c),
    );
    Widget scanBox = scanW(fg);
    final extras = <Widget>[];
    bool showWord = true;

    switch (theme) {
      case 'minimal':
        deco = BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFFCFCFCF)),
        );
        pad = const EdgeInsets.fromLTRB(22, 28, 22, 22);
        topW = FontWeight.w600;
        tableW = FontWeight.w300;
        tableSize = 44;
        scanBox = Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 9),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFDDDDDD))),
          ),
          child: scanW(const Color(0xFF666666)),
        );
      case 'block':
        deco = BoxDecoration(color: color, borderRadius: BorderRadius.circular(18));
        fg = top = tableC = Colors.white;
        qr = _qr(pad: 9, radius: 12);
        scanBox = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: .18), borderRadius: BorderRadius.circular(30)),
          child: scanW(Colors.white),
        );
      case 'tent':
        deco = BoxDecoration(
          color: Colors.white,
          border: Border(
            left: const BorderSide(color: ink, width: 1.5),
            right: const BorderSide(color: ink, width: 1.5),
            top: tentBottom ? const BorderSide(color: Color(0xFF999999), width: 1.5) : const BorderSide(color: ink, width: 1.5),
            bottom: tentTop ? BorderSide.none : const BorderSide(color: ink, width: 1.5),
          ),
        );
        top = color;
      case 'kraft':
        deco = BoxDecoration(color: const Color(0xFFC9A27A), borderRadius: BorderRadius.circular(6));
        fg = top = tableC = const Color(0xFF3B2A20);
        topFont = 'Georgia';
        qr = _qr(border: Border.all(color: const Color(0xFF3B2A20), width: 1.5));
        extras.add(
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF3B2A20).withValues(alpha: .45), width: 1.5),
              ),
            ),
          ),
        );
      case 'neon':
        deco = BoxDecoration(
          color: const Color(0xFF0B0B14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFF2EA6), width: 2),
        );
        fg = Colors.white;
        top = const Color(0xFF25E2FF);
        tableC = const Color(0xFFFF2EA6);
        qr = _qr(radius: 6);
        extras.add(
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFF25E2FF), width: 1.2),
              ),
            ),
          ),
        );
      case 'gold':
        deco = const BoxDecoration(color: Color(0xFF0E0D0B));
        fg = const Color(0xFFF1E6CC);
        top = const Color(0xFFC9A45C);
        tableC = const Color(0xFFF1E6CC);
        topFont = tableFont = 'Georgia';
        tableW = FontWeight.w600;
        pad = const EdgeInsets.fromLTRB(24, 28, 24, 28);
        qr = _qr(border: Border.all(color: const Color(0xFFC9A45C), width: 1.2));
        extras.add(
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(9),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFC9A45C), width: 1.2)),
            ),
          ),
        );
      case 'bubble':
        deco = BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: color, width: 2.5),
        );
        tableC = color;
        qr = _qr(radius: 18, border: Border.all(color: color, width: 1.8));
        scanBox = Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(30)),
          child: scanW(Colors.white),
        );
        Widget dot(double l, double t, double s, Color c) => Positioned(
          left: l,
          top: t,
          child: Container(
            width: s,
            height: s,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
        );
        extras.addAll([
          dot(10, 20, 36, Color.lerp(Colors.white, color, .35)!),
          dot(205, 40, 24, const Color(0xFFFFD84D)),
          dot(180, 330, 54, Color.lerp(Colors.white, color, .25)!),
          dot(8, 300, 21, const Color(0xFF8BE0FF)),
        ]);
      case 'khmer':
        deco = BoxDecoration(color: const Color(0xFF7A1414), borderRadius: BorderRadius.circular(9));
        fg = top = tableC = const Color(0xFFF7E3B0);
        topW = FontWeight.w400;
        pad = const EdgeInsets.fromLTRB(26, 30, 26, 30);
        qr = _qr(border: Border.all(color: const Color(0xFFC99A2E), width: 1.8));
        extras.add(
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFC99A2E), width: 4)),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFF2D27A), width: 1)),
              ),
            ),
          ),
        );
      case 'polaroid':
        deco = BoxDecoration(color: const Color(0xFFF3EFE8), borderRadius: BorderRadius.circular(3));
        showWord = false;
        tableFont = 'Comic Sans MS';
        tableW = FontWeight.w700;
      case 'ticket':
        deco = BoxDecoration(color: color, borderRadius: BorderRadius.circular(9));
        fg = top = tableC = Colors.white;
        qr = _qr(radius: 6);
      default:
        top = color;
    }

    final topRow = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (logo.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image(image: netImage(logo), width: 32, height: 32, fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink()),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            shop,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: topW,
              fontSize: 17,
              color: top,
              height: 1.15,
              fontFamily: topFont,
              fontStyle: theme == 'kraft' ? FontStyle.italic : null,
              letterSpacing: theme == 'gold' || theme == 'minimal' ? .8 : null,
            ),
          ),
        ),
      ],
    );
    final word = Text(
      tableWord.toUpperCase(),
      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: theme == 'ticket' ? 3 : .8, color: fg.withValues(alpha: .6)),
    );
    final tableT = Text(
      table,
      style: TextStyle(fontSize: tableSize, fontWeight: tableW, height: 1, color: tableC, fontFamily: tableFont),
    );

    final children = theme == 'polaroid'
        ? <Widget>[
            topRow,
            const SizedBox(height: 12),
            Transform.rotate(
              angle: -.035,
              child: Container(
                padding: const EdgeInsets.fromLTRB(9, 9, 9, 30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 9, offset: const Offset(0, 3))],
                ),
                child: _qr(pad: 0, size: 156),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -24),
              child: Transform.rotate(angle: -.035, child: tableT),
            ),
            scanBox,
          ]
        : <Widget>[topRow, const SizedBox(height: 8), if (showWord) word, tableT, const SizedBox(height: 8), qr, const SizedBox(height: 8), scanBox];
    return Container(
      decoration: deco,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          ...extras,
          if (theme == 'ticket')
            Positioned(
              left: 18,
              right: 18,
              top: 250,
              child: Row(
                children: [
                  for (var i = 0; i < 24; i++)
                    Expanded(
                      child: Container(height: 1.5, margin: const EdgeInsets.symmetric(horizontal: 2), color: Colors.white.withValues(alpha: .7)),
                    ),
                ],
              ),
            ),
          Padding(
            padding: pad,
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ],
      ),
    );
  }
}

// a small, made-up guest ordering page in one look (OrderThemeMock.jsx). Colours from the look's swatch.
class OrderPageMock extends StatelessWidget {
  final String theme, name, logo, lang;
  final Color color;
  const OrderPageMock({super.key, required this.theme, required this.color, required this.name, required this.logo, required this.lang});

  static const _sw = {
    'fresh': [Color(0xFFF6F5F2), Color(0xFFE0581A), Color(0xFF17181C)],
    'midnight': [Color(0xFF0F1117), Color(0xFF7C9CFF), Color(0xFFE8EAF2)],
    'latte': [Color(0xFFF5EDE3), Color(0xFF8B5A3C), Color(0xFF3B2A20)],
    'matcha': [Color(0xFFEEF4EA), Color(0xFF5B8C4A), Color(0xFF22331C)],
    'ocean': [Color(0xFFEEF6FB), Color(0xFF1E7AB8), Color(0xFF0D2A3F)],
    'sakura': [Color(0xFFFDF1F4), Color(0xFFD9567A), Color(0xFF4A1D2B)],
    'street': [Color(0xFFFFF6CC), Color(0xFF111111), Color(0xFF111111)],
    'elegant': [Color(0xFF0D0C0B), Color(0xFFC9A45C), Color(0xFFF3EAD7)],
    'mono': [Color(0xFFFFFFFF), Color(0xFF111111), Color(0xFF111111)],
    'angkor': [Color(0xFFFBF3E6), Color(0xFF9E1B1B), Color(0xFF3B1A0E)],
    'tropical': [Color(0xFFEFFAF7), Color(0xFF0F9B8E), Color(0xFF0B3B36)],
    'neon': [Color(0xFF0A0A12), Color(0xFFFF2EA6), Color(0xFFF2F2FF)],
    'gallery': [Color(0xFFF4F4F4), Color(0xFFFF5A36), Color(0xFF1A1A1A)],
  };
  static const _sample = [
    ('Iced latte', 'ឡាតេទឹកកក', 2.5, [Color(0xFFC8A27C), Color(0xFF7A4F32)]),
    ('Mango smoothie', 'ក្រឡុកស្វាយ', 2.75, [Color(0xFFFFD166), Color(0xFFF08A24)]),
    ('Fried rice', 'បាយឆា', 3.5, [Color(0xFFF4D58D), Color(0xFFC47F2C)]),
  ];

  @override
  Widget build(BuildContext context) {
    final sw = _sw[theme] ?? _sw['fresh']!;
    final bg = sw[0], ink = sw[2];
    final brand = theme == 'fresh' ? color : sw[1];
    final dark = bg.computeLuminance() < .2;
    final card = dark ? Color.lerp(bg, Colors.white, .07)! : Colors.white;
    final onBrand = brand.computeLuminance() > .55 ? const Color(0xFF111111) : Colors.white;
    final km = lang == 'km';
    final serif = theme == 'elegant' || theme == 'latte';
    final r = switch (theme) {
      'mono' => 0.0,
      'sakura' => 18.0,
      'street' => 6.0,
      _ => 12.0,
    };
    final heroBg = switch (theme) {
      'street' => const Color(0xFFFFCC00),
      'angkor' => const Color(0xFF9E1B1B),
      _ => brand,
    };
    final heroFg = heroBg.computeLuminance() > .55 ? const Color(0xFF111111) : Colors.white;
    Widget item((String, String, double, List<Color>) x, int i) {
      final (en, kh, p, g) = x;
      final photo = Container(
        width: theme == 'gallery' ? double.infinity : 46,
        height: theme == 'gallery' ? 60 : 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r * .7),
          gradient: LinearGradient(colors: g),
        ),
      );
      final add = Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: i == 0 ? brand : card,
          shape: BoxShape.circle,
          border: Border.all(color: brand, width: 1.5),
        ),
        child: i == 0
            ? Text(
                '2',
                style: TextStyle(color: onBrand, fontSize: 11, fontWeight: FontWeight.w800),
              )
            : Icon(LucideIcons.plus, size: 14, color: brand),
      );
      final txt = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            km ? kh : en,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: ink, fontFamily: serif ? 'Georgia' : null),
          ),
          Text(
            km ? en : kh,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, color: ink.withValues(alpha: .6)),
          ),
          Text(
            '\$${p.toStringAsFixed(2)}',
            style: TextStyle(fontSize: theme == 'street' ? 13 : 10.5, fontWeight: FontWeight.w800, color: theme == 'street' || theme == 'mono' ? ink : brand),
          ),
        ],
      );
      if (theme == 'gallery') {
        return Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(r)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              photo,
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: txt),
                  add,
                ],
              ),
            ],
          ),
        );
      }
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(r),
          border: theme == 'mono' || theme == 'street' ? Border.all(color: ink, width: 1.5) : null,
        ),
        child: Row(
          children: [
            Expanded(child: txt),
            const SizedBox(width: 6),
            Stack(
              clipBehavior: Clip.none,
              children: [
                photo,
                Positioned(right: -6, bottom: -6, child: add),
              ],
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: heroBg,
                gradient: theme == 'ocean' ? LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [brand, Color.lerp(brand, Colors.white, .4)!]) : null,
              ),
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
                    clipBehavior: Clip.antiAlias,
                    child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.chefHat, size: 18, color: brand),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: heroFg, fontWeight: FontWeight.w800, fontSize: 13, fontFamily: serif ? 'Georgia' : null),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: km ? 'តុ ' : 'Table '),
                        const TextSpan(
                          text: 'A3',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    style: TextStyle(color: ink, fontSize: 10.5),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(99)),
                    child: Text(
                      km ? 'ម៉ឺនុយ' : 'Menu',
                      style: TextStyle(color: onBrand, fontSize: 9.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: theme == 'gallery'
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: item(_sample[0], 0)),
                        const SizedBox(width: 6),
                        Expanded(child: item(_sample[1], 1)),
                      ],
                    )
                  : Column(children: [for (final (i, x) in _sample.indexed) item(x, i)]),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(r + 4)),
              child: Row(
                children: [
                  Icon(LucideIcons.shoppingBag, size: 14, color: onBrand),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      km ? 'មើលការកុម្ម៉ង់ · 2 មុខ' : 'View order · 2 items',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: onBrand, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '\$5.00',
                    style: TextStyle(color: onBrand, fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
