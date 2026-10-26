import 'package:flutter/material.dart';

import '../../widgets/ui.dart';

import '../../core/api.dart';
import '../../widgets/color_pick.dart' show hexToColor;

// The 24 looks of the guest house website (gsite/looks.js — generated) + a small drawn picture of each.
class GsLook {
  final String en, km, enSub, kmSub, font, nav, hero, rooms;
  final Color bg, fg, card, accent;
  final num r;
  final List<String> flags;
  const GsLook(
    this.en,
    this.km,
    this.enSub,
    this.kmSub, {
    required this.bg,
    required this.fg,
    required this.card,
    required this.accent,
    required this.font,
    required this.nav,
    required this.hero,
    required this.rooms,
    required this.r,
    required this.flags,
  });
  String name(String lang) => lang == 'km' ? km : en;
  String sub(String lang) => lang == 'km' ? kmSub : enSub;
}

const ghSiteLooks = <String, GsLook>{
  'classic': GsLook(
    'Homestay',
    'ផ្ទះស្នាក់នៅ',
    'Clean white, photo beside the welcome, simple room cards. Free.',
    'សស្អាត រូបក្បែរការស្វាគមន៍ កាតបន្ទប់សាមញ្ញ។ ឥតគិតថ្លៃ។',
    bg: Color(0xFFFFFFFF),
    fg: Color(0xFF0F172A),
    card: Color(0xFFF6F8FA),
    accent: Color(0xFF0F766E),
    font: 'sans',
    nav: 'bar',
    hero: 'split',
    rooms: 'cards',
    r: 16,
    flags: [],
  ),
  'riverside': GsLook(
    'Riverside',
    'មាត់ទន្លេ',
    'Full photo under a floating menu, wide room rows, soft river waves.',
    'រូបពេញ ម៉ឺនុយអណ្តែត បន្ទប់ជាជួរធំ រលកទន្លេ។',
    bg: Color(0xFFF3F8F7),
    fg: Color(0xFF0D2B2A),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFF0E7490),
    font: 'sans',
    nav: 'ghost',
    hero: 'full',
    rooms: 'wide',
    r: 14,
    flags: ['wave'],
  ),
  'boutique': GsLook(
    'Boutique',
    'ប៊ូទិក',
    'Cream and black, serif letters, framed photo, rooms as a price list.',
    'ក្រែម និងខ្មៅ អក្សរមានជើង រូបមានស៊ុម បន្ទប់ជាបញ្ជីតម្លៃ។',
    bg: Color(0xFFFAF7F2),
    fg: Color(0xFF1C1917),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFF9A6B3F),
    font: 'serif',
    nav: 'center',
    hero: 'frame',
    rooms: 'menu',
    r: 0,
    flags: ['upper'],
  ),
  'tropical': GsLook(
    'Tropical',
    'ត្រូពិក',
    'Coral and palm green, round cards, a photo card on a sunny background.',
    'ផ្កាឈូកទឹកក្រូច និងបៃតងដូង កាតមូល រូបលើផ្ទៃភ្លឺ។',
    bg: Color(0xFFFFFBF3),
    fg: Color(0xFF133B2C),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFFF25F5C),
    font: 'sans',
    nav: 'pill',
    hero: 'card',
    rooms: 'cards',
    r: 24,
    flags: ['leaf'],
  ),
  'beach': GsLook(
    'Beach',
    'ឆ្នេរ',
    'Sand and turquoise, full photo, rooms as photo tiles, wave edges.',
    'ខ្សាច់ និងខៀវទឹកសមុទ្រ រូបពេញ បន្ទប់ជាក្រឡារូប គែមរលក។',
    bg: Color(0xFFFDF8EE),
    fg: Color(0xFF0B3A4A),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFF0891B2),
    font: 'sans',
    nav: 'ghost',
    hero: 'resort',
    rooms: 'tiles',
    r: 20,
    flags: ['wave'],
  ),
  'mountain': GsLook(
    'Mountain lodge',
    'ផ្ទះលើភ្នំ',
    'Stone and forest green, slanted photo, rooms in a clean list.',
    'ថ្ម និងបៃតងព្រៃ រូបទ្រេត បន្ទប់ជាបញ្ជីស្អាត។',
    bg: Color(0xFFF4F3EE),
    fg: Color(0xFF1F2A1F),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFF3F6212),
    font: 'sans',
    nav: 'bar',
    hero: 'slant',
    rooms: 'list',
    r: 6,
    flags: [],
  ),
  'angkor': GsLook(
    'Angkor',
    'អង្គរ',
    'Deep red and gold, Khmer-style pattern, framed welcome.',
    'ក្រហមចាស់ និងមាស ក្បាច់ខ្មែរ ការស្វាគមន៍មានស៊ុម។',
    bg: Color(0xFFFBF3E6),
    fg: Color(0xFF3A0D0D),
    card: Color(0xFFFFFAF2),
    accent: Color(0xFF9E1B1B),
    font: 'serif',
    nav: 'center',
    hero: 'frame',
    rooms: 'cards',
    r: 4,
    flags: ['khmer'],
  ),
  'hostel': GsLook(
    'Backpacker',
    'អ្នកដើរព្រៃ',
    'Bold yellow and black, chunky borders, big words — for hostels.',
    'លឿង និងខ្មៅដិត ស៊ុមក្រាស់ អក្សរធំ — សម្រាប់អនុដ្ឋាន។',
    bg: Color(0xFFFFF6CC),
    fg: Color(0xFF111111),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFF111111),
    font: 'sans',
    nav: 'bar',
    hero: 'stack',
    rooms: 'tiles',
    r: 0,
    flags: ['hard', 'upper'],
  ),
  'villa': GsLook(
    'Luxury villa',
    'វីឡាប្រណីត',
    'Night blue and gold, full photo, wide rooms — quiet luxury.',
    'ខៀវយប់ និងមាស រូបពេញ បន្ទប់ធំ — ប្រណីតស្ងប់ស្ងាត់។',
    bg: Color(0xFF0D1321),
    fg: Color(0xFFF3EAD7),
    card: Color(0xFF151C2E),
    accent: Color(0xFFC9A45C),
    font: 'serif',
    nav: 'ghost',
    hero: 'full',
    rooms: 'wide',
    r: 2,
    flags: ['dark', 'upper'],
  ),
  'minimal': GsLook(
    'Minimal',
    'សាមញ្ញ',
    'Lots of white, giant words, rooms in a calm list.',
    'ទំហំសច្រើន អក្សរធំ បន្ទប់ជាបញ្ជីស្ងប់។',
    bg: Color(0xFFFFFFFF),
    fg: Color(0xFF111111),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFF111111),
    font: 'sans',
    nav: 'bar',
    hero: 'minimal',
    rooms: 'list',
    r: 0,
    flags: ['thin'],
  ),
  'colonial': GsLook(
    'French colonial',
    'អាណានិគមបារាំង',
    'Ochre and teal, shutter stripes, serif titles — old-town Kampot feel.',
    'លឿងដី និងខៀវបៃតង ឆ្នូតបង្អួច — ដូចក្រុងចាស់កំពត។',
    bg: Color(0xFFF6EFE1),
    fg: Color(0xFF23302E),
    card: Color(0xFFFFFAF0),
    accent: Color(0xFF1F6F6A),
    font: 'serif',
    nav: 'center',
    hero: 'split',
    rooms: 'menu',
    r: 8,
    flags: ['stripes'],
  ),
  'bamboo': GsLook(
    'Bamboo eco',
    'ឫស្សីបរិស្ថាន',
    'Natural beige and leaf green, soft round shapes — eco lodges.',
    'ពណ៌ធម្មជាតិ និងបៃតងស្លឹក រាងមូលទន់ — ផ្ទះបរិស្ថាន។',
    bg: Color(0xFFF3EEE3),
    fg: Color(0xFF3B2F22),
    card: Color(0xFFFBF8F1),
    accent: Color(0xFF6B7F2A),
    font: 'sans',
    nav: 'pill',
    hero: 'card',
    rooms: 'cards',
    r: 18,
    flags: ['leaf', 'grain'],
  ),
  'sunset': GsLook(
    'Sunset',
    'ថ្ងៃលិច',
    'Orange-to-pink glow over a full photo, rooms as photo tiles.',
    'ពន្លឺទឹកក្រូចទៅផ្កាឈូកលើរូបពេញ បន្ទប់ជាក្រឡារូប។',
    bg: Color(0xFFFFF7F2),
    fg: Color(0xFF3B1023),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFFEA580C),
    font: 'sans',
    nav: 'ghost',
    hero: 'full',
    rooms: 'tiles',
    r: 18,
    flags: ['gradient'],
  ),
  'lotus': GsLook(
    'Lotus',
    'ផ្កាឈូក',
    'Soft lotus pink, round shapes, centred welcome.',
    'ផ្កាឈូកស្រាល រាងមូល ការស្វាគមន៍នៅកណ្តាល។',
    bg: Color(0xFFFDF2F6),
    fg: Color(0xFF4A1D2F),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFFD9567A),
    font: 'serif',
    nav: 'center',
    hero: 'center',
    rooms: 'cards',
    r: 28,
    flags: ['soft'],
  ),
  'night': GsLook(
    'City night',
    'រាត្រីក្រុង',
    'Dark with violet and cyan glow — for city hotels.',
    'ងងឹត មានពន្លឺស្វាយ និងខៀវ — សម្រាប់សណ្ឋាគារក្នុងក្រុង។',
    bg: Color(0xFF0A0A12),
    fg: Color(0xFFE8E8F5),
    card: Color(0xFF14141F),
    accent: Color(0xFFA78BFA),
    font: 'sans',
    nav: 'dark',
    hero: 'center',
    rooms: 'cards',
    r: 14,
    flags: ['dark', 'glow'],
  ),
  'nordic': GsLook(
    'Nordic',
    'ន័រឌីក',
    'Light grey and warm wood, thin lines, big room photos two by two.',
    'ប្រផេះស្រាល និងពណ៌ឈើ បន្ទាត់ស្តើង រូបបន្ទប់ធំពីរៗ។',
    bg: Color(0xFFF7F7F5),
    fg: Color(0xFF222222),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFF8C6A4F),
    font: 'sans',
    nav: 'bar',
    hero: 'split',
    rooms: 'stack',
    r: 4,
    flags: ['thin'],
  ),
  'vintage': GsLook(
    'Vintage postcard',
    'កាតប៉ុស្តាល់ចាស់',
    'Old paper, stamp-like frames, dashed lines, typewriter prices.',
    'ក្រដាសចាស់ ស៊ុមដូចតែម បន្ទាត់ដាច់ៗ តម្លៃអក្សរម៉ាស៊ីន។',
    bg: Color(0xFFF4ECD8),
    fg: Color(0xFF2D2418),
    card: Color(0xFFFBF5E6),
    accent: Color(0xFFA44A3F),
    font: 'serif',
    nav: 'center',
    hero: 'frame',
    rooms: 'menu',
    r: 0,
    flags: ['grain', 'dashed'],
  ),
  'resort': GsLook(
    'Resort',
    'រីសត',
    'Full photo with a booking box on top, wide rooms — feels like a resort.',
    'រូបពេញ មានប្រអប់កក់ខាងលើ បន្ទប់ធំ — ដូចរីសត។',
    bg: Color(0xFFF5FAFC),
    fg: Color(0xFF0F2A3D),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFF0F766E),
    font: 'sans',
    nav: 'ghost',
    hero: 'resort',
    rooms: 'wide',
    r: 14,
    flags: [],
  ),
  'garden': GsLook(
    'Garden B&B',
    'សួនច្បារ',
    'Leafy green and white, soft serif, cosy cards — for garden stays.',
    'បៃតងស្លឹក និងស អក្សរទន់ កាតកក់ក្តៅ — សម្រាប់ផ្ទះមានសួន។',
    bg: Color(0xFFF2F7EF),
    fg: Color(0xFF1D3320),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFF2F855A),
    font: 'serif',
    nav: 'bar',
    hero: 'split',
    rooms: 'cards',
    r: 14,
    flags: ['leaf'],
  ),
  'urban': GsLook(
    'Urban',
    'ទីក្រុង',
    'City grey and blue, dark menu, sharp grid of rooms.',
    'ប្រផេះ និងខៀវ ម៉ឺនុយងងឹត ក្រឡាបន្ទប់មុតស្រួច។',
    bg: Color(0xFFF1F3F6),
    fg: Color(0xFF0F172A),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFF2563EB),
    font: 'sans',
    nav: 'dark',
    hero: 'slant',
    rooms: 'tiles',
    r: 4,
    flags: ['grid'],
  ),
  'family': GsLook(
    'Family',
    'គ្រួសារ',
    'Sunny yellow and blue, bubbly shapes — friendly for families.',
    'លឿងភ្លឺ និងខៀវ រាងពពុះ — រួសរាយសម្រាប់គ្រួសារ។',
    bg: Color(0xFFFFFDF7),
    fg: Color(0xFF1E293B),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFFF59E0B),
    font: 'sans',
    nav: 'pill',
    hero: 'card',
    rooms: 'cards',
    r: 26,
    flags: ['blobs'],
  ),
  'lake': GsLook(
    'Lakeside',
    'មាត់បឹង',
    'Calm blue and white, big title above the photo, quiet room list.',
    'ខៀវស្ងប់ និងស ចំណងជើងធំលើរូប បញ្ជីបន្ទប់ស្ងប់។',
    bg: Color(0xFFF4F8FB),
    fg: Color(0xFF0C2A43),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFF2B6CB0),
    font: 'sans',
    nav: 'center',
    hero: 'stack',
    rooms: 'list',
    r: 10,
    flags: [],
  ),
  'magazine': GsLook(
    'Magazine',
    'ទស្សនាវដ្តី',
    'Like a travel magazine: serif, rules, big photo rows.',
    'ដូចទស្សនាវដ្តីទេសចរណ៍៖ អក្សរមានជើង បន្ទាត់ រូបធំៗ។',
    bg: Color(0xFFFFFFFF),
    fg: Color(0xFF111111),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFFB91C1C),
    font: 'serif',
    nav: 'center',
    hero: 'split',
    rooms: 'wide',
    r: 0,
    flags: ['rules', 'upper'],
  ),
  'glass': GsLook(
    'Glass',
    'កញ្ចក់',
    'Soft colour gradient with frosted glass cards — modern and light.',
    'ពណ៌ចម្រុះទន់ កាតកញ្ចក់ស្រអាប់ — ទំនើប និងស្រាល។',
    bg: Color(0xFFEEF0FF),
    fg: Color(0xFF1E1B4B),
    card: Color(0x99FFFFFF),
    accent: Color(0xFF6366F1),
    font: 'sans',
    nav: 'pill',
    hero: 'center',
    rooms: 'cards',
    r: 22,
    flags: ['glass'],
  ),
};

// the website in one look, drawn at 200×150 and scaled to fit
class GsThumb extends StatelessWidget {
  final String look, name, cover, color;
  final List<Json> types;
  const GsThumb({super.key, required this.look, required this.name, this.cover = '', this.color = '', this.types = const []});
  @override
  Widget build(BuildContext context) {
    final d = ghSiteLooks[look] ?? ghSiteLooks['classic']!;
    final a = color.isNotEmpty ? hexToColor(color) : d.accent;
    final upper = d.flags.contains('upper');
    final r = d.r * .3;
    final family = d.font == 'serif' ? 'Georgia' : 'KantumruyPro';
    final title = upper ? name.toUpperCase() : name;
    final dark = d.nav == 'dark';
    final ghost = d.nav == 'ghost';
    final navFg = dark || ghost ? Colors.white : d.fg;
    final names = types.isEmpty ? ['Double', 'Twin', 'Family'] : types.take(3).map((t) => str(t['name'])).toList();
    TextStyle ts(double s, {Color? c, FontWeight w = FontWeight.w700}) => TextStyle(fontFamily: family, fontSize: s, fontWeight: w, color: c ?? d.fg, height: 1.15);
    Widget line(double w, Color c, [double h = 3]) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
    );
    Widget photo({double? h, double radius = 0}) => Container(
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: cover.isEmpty ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a.withValues(alpha: .55), Color.lerp(a, Colors.black, .35)!]) : null,
        image: cover.isEmpty ? null : DecorationImage(image: netImage(cover), fit: BoxFit.cover),
      ),
    );
    final btn = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: a, borderRadius: BorderRadius.circular(r + 2)),
      child: line(18, Colors.white.withValues(alpha: .9), 2.5),
    );
    // the menu
    final menu = Row(
      children: [for (var i = 0; i < 3; i++) Padding(padding: const EdgeInsets.only(left: 4), child: line(10, navFg.withValues(alpha: .45)))],
    );
    Widget nav = Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      color: dark ? Color.lerp(d.fg, Colors.black, .2) : (ghost ? Colors.transparent : d.bg),
      child: d.nav == 'center'
          ? Center(
              child: Text(
                title,
                maxLines: 1,
                style: ts(7, c: navFg, w: FontWeight.w800),
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(7, c: navFg, w: FontWeight.w800),
                  ),
                ),
                menu,
                const SizedBox(width: 4),
                if (d.nav == 'pill') btn,
              ],
            ),
    );
    if (d.nav == 'pill') {
      nav = Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
        child: Container(
          decoration: BoxDecoration(
            color: d.card,
            borderRadius: BorderRadius.circular(99),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 4)],
          ),
          child: nav,
        ),
      );
    }
    final welcome = Column(
      crossAxisAlignment: d.hero == 'center' || d.hero == 'full' || d.hero == 'resort' ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        line(22, a, 2.5),
        const SizedBox(height: 3),
        Text(
          title,
          maxLines: 2,
          textAlign: d.hero == 'center' || d.hero == 'full' || d.hero == 'resort' ? TextAlign.center : TextAlign.left,
          style: ts(11, c: d.hero == 'full' || d.hero == 'resort' || ghost ? Colors.white : d.fg, w: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        line(60, (d.hero == 'full' || d.hero == 'resort' || ghost ? Colors.white : d.fg).withValues(alpha: .35)),
        const SizedBox(height: 2),
        line(44, (d.hero == 'full' || d.hero == 'resort' || ghost ? Colors.white : d.fg).withValues(alpha: .25)),
        const SizedBox(height: 5),
        btn,
      ],
    );
    final Widget hero = switch (d.hero) {
      'split' => Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Row(
          children: [
            Expanded(child: welcome),
            const SizedBox(width: 6),
            Expanded(child: photo(h: 52, radius: r)),
          ],
        ),
      ),
      'full' || 'resort' || 'slant' => SizedBox(
        height: 64,
        child: Stack(
          fit: StackFit.expand,
          children: [
            photo(),
            Container(color: Colors.black.withValues(alpha: .28)),
            Center(child: welcome),
          ],
        ),
      ),
      'card' => Container(
        color: a.withValues(alpha: .12),
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(child: welcome),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: d.card, borderRadius: BorderRadius.circular(r + 2)),
                child: photo(h: 46, radius: r),
              ),
            ),
          ],
        ),
      ),
      'frame' => Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: Column(
          children: [
            welcome,
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(border: Border.all(color: d.fg.withValues(alpha: .6))),
              child: photo(h: 30),
            ),
          ],
        ),
      ),
      'stack' => Column(
        children: [
          photo(h: 34),
          Padding(padding: const EdgeInsets.all(6), child: welcome),
        ],
      ),
      'minimal' => Padding(padding: const EdgeInsets.fromLTRB(10, 12, 10, 12), child: welcome),
      _ => Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: Center(child: welcome),
      ),
    };
    // the rooms
    Widget card(int i) => Container(
      decoration: BoxDecoration(color: d.card, borderRadius: BorderRadius.circular(r)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 18, color: a.withValues(alpha: .18 + i * .1)),
          Padding(
            padding: const EdgeInsets.all(3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(names[i % names.length], maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(5.5)),
                line(14, a, 2),
              ],
            ),
          ),
        ],
      ),
    );
    final Widget rooms = switch (d.rooms) {
      'list' || 'menu' => Column(
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
              decoration: BoxDecoration(
                color: d.rooms == 'list' ? d.card : null,
                borderRadius: BorderRadius.circular(r * .6),
                border: d.rooms == 'menu' ? Border(bottom: BorderSide(color: d.fg.withValues(alpha: .25), width: .5)) : null,
              ),
              child: Row(
                children: [
                  if (d.rooms == 'list') ...[Container(width: 12, height: 9, color: a.withValues(alpha: .3)), const SizedBox(width: 4)],
                  Expanded(child: Text(names[i % names.length], maxLines: 1, style: ts(5.5))),
                  line(12, a, 2),
                ],
              ),
            ),
        ],
      ),
      'wide' => Column(
        children: [
          for (var i = 0; i < 2; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 3),
              height: 16,
              decoration: BoxDecoration(color: d.card, borderRadius: BorderRadius.circular(r)),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  Container(width: 30, color: a.withValues(alpha: .25 + i * .1)),
                  const SizedBox(width: 4),
                  Expanded(child: Text(names[i % names.length], maxLines: 1, style: ts(5.5))),
                  line(12, a, 2),
                  const SizedBox(width: 4),
                ],
              ),
            ),
        ],
      ),
      'tiles' => Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: a.withValues(alpha: .15 + i * .08),
                    borderRadius: BorderRadius.circular(r),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      _ => Row(
        children: [
          for (var i = 0; i < 3; i++) ...[if (i > 0) const SizedBox(width: 4), Expanded(child: card(i))],
        ],
      ),
    };
    final body = Container(
      color: d.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ghost) Stack(children: [hero, nav]) else ...[nav, hero],
          if (d.flags.contains('wave')) Container(height: 3, color: a.withValues(alpha: .25)),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [line(34, d.fg.withValues(alpha: .6), 3.5), const SizedBox(height: 5), rooms]),
          ),
        ],
      ),
    );
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 200,
            height: 150,
            child: OverflowBox(
              alignment: Alignment.topCenter,
              maxHeight: 400,
              child: SizedBox(width: 200, child: body),
            ),
          ),
        ),
      ),
    );
  }
}
