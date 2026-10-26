import 'dart:async';

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
import '../restaurant/rest_common.dart' show Segmented, SwitchRow, gap14;
import 'mart_common.dart';
import 'mart_kit.dart';

// Website (mart_website) — the shop's own page at /m/<slug>: MartWebsite.jsx + MartSitePages.jsx (pages, inbox) + the 36 looks (msite/looks.js).
//   GET mart/site → { addon, site, suggested_slug, themes{owned,price}, categories, stock_on, business, unread }      PUT mart/site {…}
//   GET mart/site/slug?value=      POST/DELETE mart/site/cover      CRUD mart/site/pages (+ /image, pages-order)      mart/messages

class MsLook {
  final String en, km, enDesc, kmDesc, nav, hero, grid;
  final Color bg, fg, card, accent;
  final Color? accent2;
  final double r;
  final Set<String> flags;
  const MsLook(this.en, this.km, this.enDesc, this.kmDesc, this.bg, this.fg, this.card, this.accent, this.accent2, this.nav, this.hero, this.grid, this.r, this.flags);
  String name(String lang) => lang == 'km' ? km : en;
  String desc(String lang) => lang == 'km' ? kmDesc : enDesc;
}

const msLooks = <String, MsLook>{
  'classic': MsLook(
    'Classic',
    'បុរាណ',
    'Clean white, photo beside the welcome, simple product cards. Free.',
    'សស្អាត រូបក្បែរការស្វាគមន៍ កាតទំនិញសាមញ្ញ។ ឥតគិតថ្លៃ។',
    Color(0xFFFFFFFF),
    Color(0xFF0F172A),
    Color(0xFFF6F8FA),
    Color(0xFF0F766E),
    null,
    'bar',
    'split',
    'cards',
    14,
    {},
  ),
  'fresh': MsLook(
    'Fresh',
    'ស្រស់',
    'Leafy green, round photos, dotted welcome.',
    'បៃតងស្លឹក រូបមូល ការស្វាគមន៍មានចំណុច។',
    Color(0xFFF4FBF4),
    Color(0xFF14321C),
    Color(0xFFFFFFFF),
    Color(0xFF16A34A),
    Color(0xFF84CC16),
    'pill',
    'center',
    'round',
    20,
    {'dots'},
  ),
  'market': MsLook(
    'Market',
    'ផ្សារ',
    'Warm market stall: orange and green, products on shelves.',
    'តូបផ្សារកក់ក្តៅ៖ ទឹកក្រូច និងបៃតង ទំនិញលើធ្នើ។',
    Color(0xFFFFF8EE),
    Color(0xFF3B2410),
    Color(0xFFFFFFFF),
    Color(0xFFEA580C),
    Color(0xFF15803D),
    'bar',
    'banner',
    'shelf',
    12,
    {'stripe'},
  ),
  'minimal': MsLook(
    'Minimal',
    'សាមញ្ញបំផុត',
    'Black and white, big type, a clean price list.',
    'ខ្មៅ-ស អក្សរធំ បញ្ជីតម្លៃស្អាត។',
    Color(0xFFFFFFFF),
    Color(0xFF111111),
    Color(0xFFFFFFFF),
    Color(0xFF111827),
    null,
    'center',
    'minimal',
    'list',
    4,
    {'upper', 'outline'},
  ),
  'bold': MsLook(
    'Bold',
    'ដិត',
    'Red and black, full photo, square tiles with hard shadows.',
    'ក្រហម-ខ្មៅ រូបពេញ ក្រឡាការ៉េមានស្រមោលរឹង។',
    Color(0xFFFFFFFF),
    Color(0xFF0B0B0B),
    Color(0xFFFFFFFF),
    Color(0xFFDC2626),
    null,
    'bar',
    'full',
    'tiles',
    0,
    {'upper', 'shadow'},
  ),
  'night': MsLook(
    'Night',
    'យប់',
    'Dark navy, glowing cyan, for a 24-hour shop.',
    'ខៀវចាស់ ពន្លឺខៀវភ្លឺ សម្រាប់ហាងបើក 24 ម៉ោង។',
    Color(0xFF0B1020),
    Color(0xFFE5E7EB),
    Color(0xFF141B2F),
    Color(0xFF22D3EE),
    Color(0xFF818CF8),
    'dark',
    'full',
    'cards',
    16,
    {'glow'},
  ),
  'sunrise': MsLook(
    'Sunrise',
    'ថ្ងៃរះ',
    'Orange to yellow, soft waves, round products.',
    'ទឹកក្រូចទៅលឿង រលកទន់ ទំនិញរាងមូល។',
    Color(0xFFFFF7ED),
    Color(0xFF431407),
    Color(0xFFFFFFFF),
    Color(0xFFF97316),
    Color(0xFFFACC15),
    'pill',
    'split',
    'round',
    18,
    {'wave'},
  ),
  'ocean': MsLook(
    'Ocean',
    'សមុទ្រ',
    'Sea blue, full photo, waves under the welcome.',
    'ខៀវសមុទ្រ រូបពេញ រលកក្រោមការស្វាគមន៍។',
    Color(0xFFF0F9FF),
    Color(0xFF0C2D48),
    Color(0xFFFFFFFF),
    Color(0xFF0284C7),
    Color(0xFF06B6D4),
    'bar',
    'full',
    'cards',
    16,
    {'wave'},
  ),
  'forest': MsLook(
    'Forest',
    'ព្រៃឈើ',
    'Deep green, serif letters, a calm list.',
    'បៃតងចាស់ អក្សរមានជើង បញ្ជីស្ងប់ស្ងាត់។',
    Color(0xFFF3F6F1),
    Color(0xFF1A2E1A),
    Color(0xFFFFFFFF),
    Color(0xFF166534),
    null,
    'center',
    'split',
    'list',
    10,
    {'grain'},
  ),
  'berry': MsLook(
    'Berry',
    'ផ្លែបឺរី',
    'Pink and purple, round cards, playful dots.',
    'ផ្កាឈូក និងស្វាយ កាតមូល ចំណុចលេងៗ។',
    Color(0xFFFDF2F8),
    Color(0xFF4A0D2E),
    Color(0xFFFFFFFF),
    Color(0xFFBE185D),
    Color(0xFF7C3AED),
    'pill',
    'center',
    'round',
    22,
    {'dots'},
  ),
  'citrus': MsLook(
    'Citrus',
    'ក្រូចឆ្មារ',
    'Lemon and lime, striped top, bright tiles.',
    'លឿងក្រូចឆ្មារ និងបៃតង ឆ្នូតខាងលើ ក្រឡាភ្លឺ។',
    Color(0xFFFEFCE8),
    Color(0xFF2E2A05),
    Color(0xFFFFFFFF),
    Color(0xFFCA8A04),
    Color(0xFF65A30D),
    'bar',
    'banner',
    'tiles',
    14,
    {'stripe'},
  ),
  'mint': MsLook(
    'Mint',
    'ជីអង្កាម',
    'Cool mint, photo beside the welcome, many small cards.',
    'បៃតងស្រាល រូបក្បែរការស្វាគមន៍ កាតតូចៗច្រើន។',
    Color(0xFFF0FDFA),
    Color(0xFF083344),
    Color(0xFFFFFFFF),
    Color(0xFF0D9488),
    null,
    'pill',
    'split',
    'compact',
    14,
    {},
  ),
  'coral': MsLook(
    'Coral',
    'ផ្កាថ្ម',
    'Coral pink, centred welcome, soft wave.',
    'ផ្កាឈូកផ្កាថ្ម ការស្វាគមន៍កណ្តាល រលកទន់។',
    Color(0xFFFFF5F3),
    Color(0xFF3F1D1A),
    Color(0xFFFFFFFF),
    Color(0xFFF43F5E),
    Color(0xFFFB923C),
    'center',
    'center',
    'cards',
    18,
    {'wave'},
  ),
  'slate': MsLook(
    'Slate',
    'ថ្មខៀវ',
    'Grey and sky blue, thin lines, a tidy small grid.',
    'ប្រផេះ និងខៀវមេឃ បន្ទាត់ស្តើង ក្រឡាតូចៗរៀបរយ។',
    Color(0xFFF8FAFC),
    Color(0xFF0F172A),
    Color(0xFFFFFFFF),
    Color(0xFF334155),
    Color(0xFF0EA5E9),
    'bar',
    'minimal',
    'compact',
    8,
    {'outline'},
  ),
  'sand': MsLook(
    'Sand',
    'ខ្សាច់',
    'Beige and gold, book letters, a warm list.',
    'ពណ៌ខ្សាច់ និងមាស អក្សរសៀវភៅ បញ្ជីកក់ក្តៅ។',
    Color(0xFFFAF6EF),
    Color(0xFF3D3427),
    Color(0xFFFFFDF8),
    Color(0xFFA16207),
    null,
    'center',
    'split',
    'list',
    6,
    {'grain'},
  ),
  'royal': MsLook(
    'Royal',
    'រាជវង្ស',
    'Indigo and violet, fine letters, a banner welcome.',
    'ខៀវចាស់ និងស្វាយ អក្សរស្រស់ស្អាត ការស្វាគមន៍ជាបដា។',
    Color(0xFFF5F3FF),
    Color(0xFF1E1B4B),
    Color(0xFFFFFFFF),
    Color(0xFF4F46E5),
    Color(0xFFA855F7),
    'center',
    'banner',
    'cards',
    12,
    {'upper'},
  ),
  'candy': MsLook(
    'Candy',
    'ស្ករគ្រាប់',
    'Pink and aqua, very round, fun dots.',
    'ផ្កាឈូក និងខៀវទឹក មូលខ្លាំង ចំណុចលេងៗ។',
    Color(0xFFFFF0F6),
    Color(0xFF3B0A2A),
    Color(0xFFFFFFFF),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
    'pill',
    'center',
    'round',
    26,
    {'dots'},
  ),
  'grocery': MsLook(
    'Grocery',
    'គ្រឿងទេស',
    'Supermarket green and yellow, shelves per category.',
    'បៃតង និងលឿងផ្សារទំនើប ធ្នើតាមប្រភេទ។',
    Color(0xFFF7FAF5),
    Color(0xFF14281D),
    Color(0xFFFFFFFF),
    Color(0xFF15803D),
    Color(0xFFF59E0B),
    'bar',
    'banner',
    'shelf',
    12,
    {},
  ),
  'bakery': MsLook(
    'Bakery',
    'នំប៉័ង',
    'Cream and caramel, serif title, round photos.',
    'ក្រែម និងការ៉ាមែល ចំណងជើងមានជើង រូបមូល។',
    Color(0xFFFFF8F0),
    Color(0xFF4A2C17),
    Color(0xFFFFFFFF),
    Color(0xFFB45309),
    null,
    'center',
    'split',
    'round',
    20,
    {'grain'},
  ),
  'organic': MsLook(
    'Organic',
    'សរីរាង្គ',
    'Olive green, natural paper, full photo.',
    'បៃតងអូលីវ ក្រដាសធម្មជាតិ រូបពេញ។',
    Color(0xFFF6F7EE),
    Color(0xFF2C3318),
    Color(0xFFFFFFFF),
    Color(0xFF4D7C0F),
    null,
    'pill',
    'full',
    'cards',
    16,
    {'grain'},
  ),
  'neon': MsLook(
    'Neon',
    'នីអុង',
    'Black with lime and pink light, tiles that glow.',
    'ខ្មៅ ពន្លឺបៃតង និងផ្កាឈូក ក្រឡាភ្លឺ។',
    Color(0xFF0A0A0F),
    Color(0xFFF5F5F5),
    Color(0xFF15151F),
    Color(0xFFA3E635),
    Color(0xFFF0ABFC),
    'dark',
    'center',
    'tiles',
    10,
    {'glow'},
  ),
  'paper': MsLook(
    'Paper',
    'ក្រដាស',
    'Typewriter letters on paper, a plain list.',
    'អក្សរម៉ាស៊ីនអង្គុលីលេខលើក្រដាស បញ្ជីធម្មតា។',
    Color(0xFFF7F4EC),
    Color(0xFF222222),
    Color(0xFFFFFDF7),
    Color(0xFF1F2937),
    null,
    'center',
    'minimal',
    'list',
    2,
    {'grain', 'outline'},
  ),
  'elegant': MsLook(
    'Elegant',
    'ឆើតឆាយ',
    'Ivory and brown, serif capitals, full photo.',
    'ពណ៌ភ្លុក និងត្នោត អក្សរធំមានជើង រូបពេញ។',
    Color(0xFFFBFAF8),
    Color(0xFF1C1917),
    Color(0xFFFFFFFF),
    Color(0xFF78350F),
    null,
    'center',
    'full',
    'cards',
    0,
    {'upper'},
  ),
  'tropical': MsLook(
    'Tropical',
    'ត្រូពិក',
    'Coral and palm green, round photos, waves.',
    'ផ្កាថ្ម និងបៃតងដូង រូបមូល រលក។',
    Color(0xFFFFFBF3),
    Color(0xFF133B2C),
    Color(0xFFFFFFFF),
    Color(0xFFF25F5C),
    Color(0xFF1B998B),
    'pill',
    'split',
    'round',
    22,
    {'wave'},
  ),
  'lotus': MsLook(
    'Lotus',
    'ផ្កាឈូក',
    'Lotus pink and leaf green, a Khmer pattern.',
    'ផ្កាឈូក និងបៃតងស្លឹក លំនាំខ្មែរ។',
    Color(0xFFFDF4F8),
    Color(0xFF3A1630),
    Color(0xFFFFFFFF),
    Color(0xFFDB2777),
    Color(0xFF16A34A),
    'center',
    'center',
    'cards',
    18,
    {'khmer'},
  ),
  'angkor': MsLook(
    'Angkor',
    'អង្គរ',
    'Sandstone and gold, temple pattern, classic list.',
    'ថ្មភក់ និងមាស លំនាំប្រាសាទ បញ្ជីបុរាណ។',
    Color(0xFFFBF5EA),
    Color(0xFF3A2410),
    Color(0xFFFFFAF0),
    Color(0xFFB7791F),
    Color(0xFF7C2D12),
    'center',
    'full',
    'list',
    6,
    {'khmer', 'upper'},
  ),
  'mekong': MsLook(
    'Mekong',
    'មេគង្គ',
    'River green and gold, full photo, waves.',
    'បៃតងទន្លេ និងមាស រូបពេញ រលក។',
    Color(0xFFEFF7F6),
    Color(0xFF0F2E2C),
    Color(0xFFFFFFFF),
    Color(0xFF0F766E),
    Color(0xFFCA8A04),
    'bar',
    'full',
    'cards',
    14,
    {'wave'},
  ),
  'kampot': MsLook(
    'Kampot',
    'កំពត',
    'Pepper red and green, products on shelves.',
    'ក្រហមម្រេច និងបៃតង ទំនិញលើធ្នើ។',
    Color(0xFFF5F1EA),
    Color(0xFF2B2118),
    Color(0xFFFFFFFF),
    Color(0xFF9F1239),
    Color(0xFF15803D),
    'bar',
    'split',
    'shelf',
    10,
    {},
  ),
  'sunset': MsLook(
    'Sunset',
    'ថ្ងៃលិច',
    'Orange and pink glow, full photo.',
    'ពន្លឺទឹកក្រូច និងផ្កាឈូក រូបពេញ។',
    Color(0xFFFFF4EC),
    Color(0xFF3B1023),
    Color(0xFFFFFFFF),
    Color(0xFFEA580C),
    Color(0xFFDB2777),
    'pill',
    'full',
    'cards',
    18,
    {'glow'},
  ),
  'sky': MsLook(
    'Sky',
    'មេឃ',
    'Light blue, airy dots, small cards.',
    'ខៀវស្រាល ចំណុចស្រាលៗ កាតតូច។',
    Color(0xFFF0F7FF),
    Color(0xFF0B2545),
    Color(0xFFFFFFFF),
    Color(0xFF3B82F6),
    Color(0xFF38BDF8),
    'pill',
    'center',
    'compact',
    16,
    {'dots'},
  ),
  'rose': MsLook(
    'Rose',
    'កុលាប',
    'Rose red, book letters, photo beside the welcome.',
    'ក្រហមកុលាប អក្សរសៀវភៅ រូបក្បែរការស្វាគមន៍។',
    Color(0xFFFFF1F2),
    Color(0xFF4C0519),
    Color(0xFFFFFFFF),
    Color(0xFFE11D48),
    null,
    'center',
    'split',
    'cards',
    14,
    {},
  ),
  'coffee': MsLook(
    'Coffee',
    'កាហ្វេ',
    'Coffee brown, dark menu bar, a café list.',
    'ត្នោតកាហ្វេ របារម៉ឺនុយខ្មៅ បញ្ជីបែបហាងកាហ្វេ។',
    Color(0xFFF6F0EA),
    Color(0xFF2C1A12),
    Color(0xFFFFFAF5),
    Color(0xFF6F4E37),
    Color(0xFFC08552),
    'dark',
    'banner',
    'list',
    10,
    {'grain'},
  ),
  'pastel': MsLook(
    'Pastel',
    'ពណ៌ស្រាល',
    'Lilac and pink, soft and round.',
    'ស្វាយស្រាល និងផ្កាឈូក ទន់ និងមូល។',
    Color(0xFFF8F5FF),
    Color(0xFF2E2A47),
    Color(0xFFFFFFFF),
    Color(0xFF8B5CF6),
    Color(0xFFF472B6),
    'pill',
    'center',
    'round',
    24,
    {},
  ),
  'metro': MsLook(
    'Metro',
    'ទីក្រុង',
    'City blue on grey, dark bar, square tiles.',
    'ខៀវទីក្រុងលើប្រផេះ របារខ្មៅ ក្រឡាការ៉េ។',
    Color(0xFFF3F4F6),
    Color(0xFF111827),
    Color(0xFFFFFFFF),
    Color(0xFF2563EB),
    null,
    'dark',
    'banner',
    'tiles',
    0,
    {'stripe', 'upper'},
  ),
  'retro': MsLook(
    'Retro',
    'រេត្រូ',
    '70s orange and green, chunky letters, hard shadows.',
    'ទឹកក្រូច និងបៃតងឆ្នាំ 70 អក្សរក្រាស់ ស្រមោលរឹង។',
    Color(0xFFFDF6E3),
    Color(0xFF2D1B00),
    Color(0xFFFFFBF0),
    Color(0xFFD9480F),
    Color(0xFF2B8A3E),
    'bar',
    'banner',
    'cards',
    12,
    {'shadow', 'stripe'},
  ),
  'festival': MsLook(
    'Festival',
    'ពិធីបុណ្យ',
    'Red and gold party colours, round photos, Khmer touch.',
    'ក្រហម និងមាសបែបបុណ្យ រូបមូល លំនាំខ្មែរ។',
    Color(0xFFFFFDF5),
    Color(0xFF2A1033),
    Color(0xFFFFFFFF),
    Color(0xFFE11D48),
    Color(0xFFF59E0B),
    'pill',
    'full',
    'round',
    20,
    {'dots', 'khmer'},
  ),
};

const _showKeys = ['products', 'prices', 'stock', 'about', 'hours', 'contact', 'map', 'contact_form'];
const _presets = ['#0F766E', '#16A34A', '#2563EB', '#7C3AED', '#DB2777', '#DC2626', '#EA580C', '#CA8A04', '#0891B2', '#111827'];

Json _pick(Json s) => {
  'slug': str(s['slug']),
  'published': s['published'] == true,
  'theme': str(s['theme']).isEmpty ? 'classic' : str(s['theme']),
  'color': str(s['color']),
  'tagline': str(s['tagline']),
  'about': str(s['about']),
  'hours': str(s['hours']),
  'map_url': str(s['map_url']),
  'facebook': str(s['facebook']),
  'telegram': str(s['telegram']),
  'show': {'products': true, 'prices': true, 'stock': false, 'about': true, 'hours': true, 'contact': true, 'map': true, 'contact_form': true, ...obj(s['show'])},
  'hidden_categories': [...(s['hidden_categories'] as List? ?? const []).map((e) => '$e')],
};

// a small picture of the website in one look: menu, welcome, products
class MsThumb extends StatelessWidget {
  final String look, name, tagline, cover, color;
  final List<Json> products;
  const MsThumb({super.key, required this.look, required this.name, this.tagline = '', this.cover = '', this.color = '', this.products = const []});
  @override
  Widget build(BuildContext context) {
    final d = msLooks[look] ?? msLooks['classic']!;
    final a = color.isNotEmpty ? hexToColor(color) : d.accent;
    final a2 = d.accent2 ?? Color.lerp(a, Colors.white, .35)!;
    final upper = d.flags.contains('upper');
    final r = d.r * .35;
    final dark = d.nav == 'dark';
    final title = upper ? name.toUpperCase() : name;
    final names = products.isEmpty ? ['Coca', 'Bread', 'Water', 'Chips', 'Eggs', 'Oil'] : products.take(6).map((p) => str(p['name'])).toList();
    final photos = products.take(6).map((p) => str(obj(p['photo'])['url']).isNotEmpty ? str(obj(p['photo'])['url']) : str(p['photo'])).toList();
    // the menu
    final navBg = dark ? Color.lerp(d.bg, Colors.black, .35)! : d.bg;
    final navFg = dark ? Colors.white : d.fg;
    Widget dots() => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            width: 10,
            height: 3,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(color: navFg.withValues(alpha: .35), borderRadius: BorderRadius.circular(2)),
          ),
      ],
    );
    final nav = Container(
      height: 16,
      color: navBg,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: d.nav == 'center'
          ? Center(
              child: Text(
                title,
                maxLines: 1,
                style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: navFg),
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: navFg),
                  ),
                ),
                if (d.nav == 'pill')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: a, borderRadius: BorderRadius.circular(99)),
                    child: const Text(
                      'Shop',
                      style: TextStyle(fontSize: 5.5, color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  )
                else
                  dots(),
              ],
            ),
    );
    // the welcome
    final pic = cover.isNotEmpty
        ? Image(
            image: netImage(cover),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(color: a2.withValues(alpha: .4)),
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [a, a2], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
          );
    final words = Column(
      crossAxisAlignment: d.hero == 'center' || d.hero == 'minimal' ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: d.hero == 'full' || d.hero == 'banner' ? Colors.white : d.fg),
        ),
        if (tagline.isNotEmpty)
          Text(
            tagline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 5.5, color: (d.hero == 'full' || d.hero == 'banner' ? Colors.white : d.fg).withValues(alpha: .7)),
          ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: d.hero == 'full' || d.hero == 'banner' ? Colors.white : a, borderRadius: BorderRadius.circular(r)),
          child: Text(
            'Shop',
            style: TextStyle(fontSize: 5.5, fontWeight: FontWeight.w800, color: d.hero == 'full' || d.hero == 'banner' ? a : Colors.white),
          ),
        ),
      ],
    );
    final Widget hero = switch (d.hero) {
      'full' => SizedBox(
        height: 44,
        child: Stack(
          fit: StackFit.expand,
          children: [
            pic,
            Container(color: Colors.black.withValues(alpha: .35)),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Align(alignment: Alignment.centerLeft, child: words),
            ),
          ],
        ),
      ),
      'banner' => Container(
        height: 36,
        color: a,
        padding: const EdgeInsets.all(6),
        child: Align(alignment: Alignment.centerLeft, child: words),
      ),
      'center' => SizedBox(height: 40, child: Center(child: words)),
      'minimal' => SizedBox(height: 32, child: Center(child: words)),
      _ => SizedBox(
        height: 40,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(padding: const EdgeInsets.all(6), child: words),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: ClipRRect(borderRadius: BorderRadius.circular(r), child: pic),
              ),
            ),
          ],
        ),
      ),
    };
    // the products
    Widget photo(int i) {
      final p = i < photos.length ? photos[i] : '';
      return p.isNotEmpty
          ? Image(
              image: netImage(p),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(color: a.withValues(alpha: .15)),
            )
          : Container(color: a.withValues(alpha: .15));
    }

    Widget card(int i) {
      final nm = names[i % names.length];
      final label = Text(
        upper ? nm.toUpperCase() : nm,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(fontSize: 5, fontWeight: FontWeight.w700, color: d.fg),
      );
      final price = Text(
        '\$1.25',
        style: TextStyle(fontSize: 5, fontWeight: FontWeight.w800, color: a),
      );
      return Container(
        decoration: BoxDecoration(
          color: d.card,
          borderRadius: BorderRadius.circular(d.grid == 'round' ? 99 : r),
          border: d.flags.contains('outline') ? Border.all(color: d.fg.withValues(alpha: .4), width: .6) : null,
          boxShadow: d.flags.contains('shadow') ? [BoxShadow(color: d.fg, offset: const Offset(1.5, 1.5))] : null,
        ),
        padding: const EdgeInsets.all(2),
        clipBehavior: Clip.antiAlias,
        child: d.grid == 'list' || d.grid == 'compact'
            ? Row(
                children: [
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: ClipRRect(borderRadius: BorderRadius.circular(2), child: photo(i)),
                  ),
                  const SizedBox(width: 3),
                  Expanded(child: label),
                  price,
                ],
              )
            : d.grid == 'round'
            ? ClipOval(child: photo(i))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(r * .7),
                      child: SizedBox(width: double.infinity, child: photo(i)),
                    ),
                  ),
                  label,
                  price,
                ],
              ),
      );
    }

    final listy = d.grid == 'list' || d.grid == 'compact';
    final grid = Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      child: listy
          ? Column(
              children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: Padding(padding: const EdgeInsets.only(bottom: 2), child: card(i)),
                  ),
              ],
            )
          : Column(
              children: [
                for (final row in [
                  [0, 1, 2],
                  [3, 4, 5],
                ])
                  Expanded(
                    child: Row(
                      children: [
                        for (final i in row)
                          Expanded(
                            child: Padding(padding: const EdgeInsets.all(1.5), child: card(i)),
                          ),
                      ],
                    ),
                  ),
                if (d.grid == 'shelf') Container(height: 2, color: a2),
              ],
            ),
    );
    // drawn at 200 × 160 and scaled to the space it gets
    return AspectRatio(
      aspectRatio: 1.25,
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: 200,
          height: 160,
          child: Container(
            color: d.bg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                nav,
                hero,
                if (d.flags.contains('wave')) Container(height: 3, color: a.withValues(alpha: .25)),
                if (d.flags.contains('stripe')) Container(height: 3, color: a2),
                Expanded(child: grid),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WebsiteTab extends StatefulWidget {
  final MartCtx ctx;
  const WebsiteTab({super.key, required this.ctx});
  @override
  State<WebsiteTab> createState() => _WebsiteTabState();
}

class _WebsiteTabState extends State<WebsiteTab> {
  Json? _info, _f;
  List<Json> _products = [];
  String _tab = 'edit', _busy = '';
  Json? _slug; // {available, reason}
  Timer? _wait;
  final _c = <String, TextEditingController>{
    for (final k in ['slug', 'tagline', 'about', 'hours', 'map_url', 'facebook', 'telegram']) k: TextEditingController(),
  };
  MartCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    ctx.api.get('${ctx.base}/products').then((r) {
      if (mounted) setState(() => _products = objs(r['data']).where((p) => p['active'] != false).toList());
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _wait?.cancel();
    for (final x in _c.values) {
      x.dispose();
    }
    super.dispose();
  }

  void _setForm(Json f) {
    _f = f;
    for (final e in _c.entries) {
      e.value.text = str(f[e.key]);
    }
  }

  Future<void> _load({bool reset = false}) async {
    try {
      final r = await ctx.api.get('${ctx.base}/site');
      final info = obj(r['data']);
      if (!mounted) return;
      setState(() {
        _info = info;
        if (reset || _f == null) {
          final s = obj(info['site']);
          _setForm(_pick({...s, 'slug': str(s['slug']).isEmpty ? info['suggested_slug'] : s['slug']}));
        }
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  Json get _now => {..._f!, for (final e in _c.entries) e.key: e.value.text.trim()};

  void _checkSlug() {
    _wait?.cancel();
    final v = _c['slug']!.text;
    if (v == str(obj(_info?['site'])['slug'])) return setState(() => _slug = null);
    _wait = Timer(const Duration(milliseconds: 400), () async {
      try {
        final r = await ctx.api.get('${ctx.base}/site/slug', {'value': v});
        if (mounted && _c['slug']!.text == v) setState(() => _slug = obj(r['data']));
      } catch (_) {}
    });
  }

  Future<void> _save([Json? patch]) async {
    setState(() => _busy = 'save');
    try {
      final r = await ctx.api.put('${ctx.base}/site', patch ?? _now);
      final info = obj(r['data']);
      setState(() {
        _info = info;
        _setForm(_pick(obj(info['site'])));
        _slug = null;
      });
      ctx.notify(ctx.w('saved'));
    } on ApiError catch (e) {
      if (e.status == 402 && e.body['product'] != null) {
        ctx.askBuy(str(e.body['product']), item: e.body['item'] == null ? null : str(e.body['item']), onDone: () => _load(reset: true));
      } else {
        ctx.fail(e);
      }
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Future<void> _cover(List<int>? bytes) async {
    setState(() => _busy = 'cover');
    try {
      final r = bytes != null ? await ctx.api.post('${ctx.base}/site/cover', fileForm('file', bytes, 'cover.jpg')) : await ctx.api.delete('${ctx.base}/site/cover');
      setState(() => _info = obj(r['data']));
    } on ApiError catch (e) {
      if (e.status == 402) {
        ctx.askBuy('mart_website');
      } else {
        ctx.fail(e);
      }
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final info = _info, f = _f;
    if (info == null || f == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 5));
    final addon = obj(info['addon']);
    final on = addon['active'] == true;
    final site = obj(info['site']);
    final now = _now;
    final dirty = '${_pick(site)}' != '$now';
    final url = str(site['slug']).isNotEmpty ? '${Config.siteUrl}/m/${site['slug']}' : '';
    final price = fmt(n(addon['price'] ?? 110));
    final host = Uri.tryParse(Config.siteUrl)?.authority ?? '';
    final hero = Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MHead(ctx.w('siteTitle'), icon: LucideIcons.globe, sub: on ? ctx.w('siteOn', {'date': mDate(addon['expires_at'], ctx.lang)}) : ctx.w('siteOff', {'price': price})),
          if (!on || addon['status'] == 'expiring')
            Align(
              alignment: Alignment.centerLeft,
              child: GoldBtn(on ? ctx.w('renew') : ctx.w('unlockYear', {'coins': price}), onTap: ctx.readOnly ? null : () => ctx.askBuy('mart_website', onDone: () => _load())),
            ),
        ],
      ),
    );
    final slug = _slug;
    final address = Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Field(
            label: ctx.w('address'),
            controller: _c['slug']!,
            hint: 'my-shop',
            maxLength: 40,
            enabled: !ctx.readOnly,
            prefix: Padding(
              padding: const EdgeInsets.only(left: 14, right: 2),
              child: Center(
                widthFactor: 1,
                child: Text('$host/m/', style: TextStyle(color: c.muted, fontSize: 13)),
              ),
            ),
            onChanged: (v) {
              final s = v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '');
              if (s != v) {
                _c['slug']!.value = TextEditingValue(
                  text: s,
                  selection: TextSelection.collapsed(offset: s.length),
                );
              }
              setState(() {});
              _checkSlug();
            },
          ),
          const SizedBox(height: 4),
          Text(
            slug == null
                ? ctx.w('addressHint')
                : slug['available'] == true
                ? '✓ ${ctx.w('slugFree')}'
                : slug['reason'] == 'format'
                ? ctx.w('slugFormat')
                : ctx.w('slugTaken'),
            style: TextStyle(
              fontSize: 12.5,
              color: slug == null
                  ? c.muted
                  : slug['available'] == true
                  ? c.good
                  : c.danger,
            ),
          ),
          gap14,
          SwitchRow(
            title: f['published'] == true ? ctx.w('published') : ctx.w('hidden'),
            sub: f['published'] == true ? ctx.w('publishedSub') : ctx.w('hiddenSub'),
            value: f['published'] == true,
            onChanged: ctx.readOnly || _busy.isNotEmpty
                ? null
                : (v) {
                    if (!on && v) return ctx.askBuy('mart_website', onDone: () => _load());
                    _save({...now, 'published': v});
                  },
          ),
          if (url.isNotEmpty && site['published'] == true && site['slug'] == now['slug']) ...[
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
        ],
      ),
    );
    final pages = objs(site['pages']);
    final unread = n(info['unread']);
    final Widget body = switch (_tab) {
      'pages' => _Pages(key: const ValueKey('pages'), ctx: ctx, site: site, setInfo: (v) => setState(() => _info = v)),
      'inbox' => _Inbox(
        key: const ValueKey('inbox'),
        ctx: ctx,
        onUnread: (v) {
          setState(() => _info = {...?_info, 'unread': v});
          if (v != n(ctx.counts['unread'])) ctx.reload();
        },
      ),
      'looks' => _looks(context, info, site, now),
      _ => _edit(context, info, site, now, dirty),
    };
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                hero,
                mGap,
                address,
                mGap,
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Segmented<String>(
                    value: _tab,
                    options: [
                      for (final k in ['edit', 'pages', 'looks', 'inbox'])
                        (
                          k,
                          k == 'inbox' && unread > 0
                              ? '${ctx.w('siteTabs.$k')} ($unread)'
                              : k == 'pages' && pages.isNotEmpty
                              ? '${ctx.w('siteTabs.$k')} (${pages.length})'
                              : ctx.w('siteTabs.$k'),
                        ),
                    ],
                    onChanged: (v) => setState(() => _tab = v),
                  ),
                ),
                mGap,
                body,
              ],
            ),
          ),
        ),
        if (_tab == 'edit' && dirty)
          Container(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.paddingOf(context).bottom),
            decoration: BoxDecoration(
              color: c.card,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 20, offset: const Offset(0, -4))],
            ),
            child: Row(
              children: [
                Expanded(child: Muted(ctx.w('unsaved'))),
                Btn(ctx.m('cancel'), kind: BtnKind.ghost, small: true, onTap: _busy.isNotEmpty ? null : () => setState(() => _setForm(_pick(site)))),
                const SizedBox(width: 8),
                Btn(_busy == 'save' ? ctx.w('saving') : ctx.w('save'), icon: LucideIcons.save, busy: _busy == 'save', onTap: ctx.readOnly || _busy.isNotEmpty ? null : () => _save()),
              ],
            ),
          ),
      ],
    );
  }

  Widget _edit(BuildContext context, Json info, Json site, Json now, bool dirty) {
    final c = context.c;
    final f = _f!;
    final show = obj(f['show']);
    final hidden = (f['hidden_categories'] as List).map((e) => '$e').toSet();
    final cover = str(obj(site['cover'])['url']);
    final cats = objs(info['categories']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // a picture of the website as it is now (unsaved changes too)
        Panel(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  for (final col in [const Color(0xFFFF5F57), const Color(0xFFFEBC2E), const Color(0xFF28C840)])
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(color: col, shape: BoxShape.circle),
                    ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      str(site['slug']).isEmpty ? ctx.w('preview') : '${Uri.tryParse(Config.siteUrl)?.authority ?? ''}/m/${now['slug']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: MsThumb(
                  look: str(now['theme']),
                  name: str(ctx.business['name']),
                  tagline: str(now['tagline']),
                  cover: cover,
                  color: str(now['color']),
                  products: show['products'] == true ? _products.where((p) => p['category_id'] == null || !hidden.contains(str(p['category_id']))).toList() : const [],
                ),
              ),
            ],
          ),
        ),
        mGap,
        mCard(context, ctx.w('shopInfo'), [
          Text(ctx.w('cover'), style: const TextStyle(fontWeight: FontWeight.w700)),
          Muted(ctx.w('coverHint')),
          const SizedBox(height: 8),
          MImagePick(
            ctx: ctx,
            url: cover,
            wide: true,
            busy: _busy == 'cover',
            disabled: ctx.readOnly,
            maxSize: 1600,
            onPick: (b, _) async {
              if (!ctx.addonOn('mart_website')) return ctx.askBuy('mart_website');
              await _cover(b);
            },
            onRemove: () => _cover(null),
          ),
          gap14,
          Field(label: ctx.w('tagline'), hint: ctx.w('taglinePh'), controller: _c['tagline']!, maxLength: 140, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
          gap14,
          Field(label: ctx.w('about'), controller: _c['about']!, maxLength: 2000, maxLines: 4, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
          gap14,
          Field(label: ctx.w('hours'), hint: ctx.w('hoursPh'), controller: _c['hours']!, maxLength: 300, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
          gap14,
          Field(label: ctx.w('mapLink'), hint: 'https://maps.app.goo.gl/…', controller: _c['map_url']!, maxLength: 500, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
          gap14,
          Field(label: 'Facebook', hint: 'https://facebook.com/…', controller: _c['facebook']!, maxLength: 200, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
          gap14,
          Field(label: 'Telegram', hint: '@myshop', controller: _c['telegram']!, maxLength: 100, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
          const SizedBox(height: 6),
          Muted(ctx.w('contactFrom')),
        ]),
        mGap,
        mCard(context, ctx.w('color'), sub: ctx.w('colorSub'), [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: ctx.readOnly ? null : () => setState(() => f['color'] = ''),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: (msLooks[str(f['theme'])] ?? msLooks['classic']!).accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: str(f['color']).isEmpty ? c.ink : Colors.transparent, width: 2),
                  ),
                  child: str(f['color']).isEmpty ? const Icon(LucideIcons.check, size: 15, color: Colors.white) : null,
                ),
              ),
              const SizedBox(width: 10),
              Muted(ctx.w('colorLook')),
            ],
          ),
          const SizedBox(height: 10),
          ColorRow(
            value: str(f['color']),
            colors: _presets,
            customLabel: ctx.w('colorCustom'),
            saveLabel: ctx.m('save'),
            cancelLabel: ctx.m('cancel'),
            onChanged: ctx.readOnly ? null : (v) => setState(() => f['color'] = v),
          ),
        ]),
        mGap,
        mCard(context, ctx.w('showTitle'), sub: ctx.w('showSub'), [
          for (final k in _showKeys)
            () {
              final lock = k == 'stock' && info['stock_on'] != true;
              return SwitchRow(
                title: ctx.w('show.$k'),
                sub: lock ? ctx.w('needStock') : ctx.w('showHint.$k'),
                value: show[k] == true && !lock,
                onChanged: ctx.readOnly || lock ? null : (v) => setState(() => f['show'] = {...show, k: v}),
              );
            }(),
          if (show['products'] == true && cats.isNotEmpty) ...[
            gap14,
            Text(ctx.w('cats'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final cat in cats)
                  () {
                    final id = str(cat['_id']);
                    final shown = !hidden.contains(id);
                    return FilterChip(
                      label: Text(str(cat['name'])),
                      selected: shown,
                      onSelected: ctx.readOnly ? null : (_) => setState(() => f['hidden_categories'] = shown ? [...hidden, id] : hidden.where((x) => x != id).toList()),
                      selectedColor: c.active,
                      checkmarkColor: c.brandInk,
                      side: BorderSide(color: shown ? c.brand : c.line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                    );
                  }(),
              ],
            ),
            const SizedBox(height: 4),
            Muted(ctx.w('catsHint')),
          ],
        ]),
      ],
    );
  }

  Widget _looks(BuildContext context, Json info, Json site, Json now) {
    final th = obj(info['themes']);
    final owned = {'classic', ...(th['owned'] as List? ?? const []).map((e) => '$e')};
    final current = str(site['theme']).isEmpty ? 'classic' : str(site['theme']);
    final cover = str(obj(site['cover'])['url']);
    Widget thumb(String k) => MsThumb(look: k, name: str(ctx.business['name']), tagline: str(now['tagline']), cover: cover, color: current == k ? str(site['color']) : '', products: _products);
    String status(String k) => current == k ? ctx.w('inUse') : (k == 'classic' ? ctx.w('free') : (owned.contains(k) ? ctx.m('yours') : '${fmt(n(th['price']))} ${ctx.m('coins')}'));
    void open(String k) => openLookSheet(
      context,
      title: ctx.w('looksTitle'),
      keys: msLooks.keys.toList(),
      start: k,
      current: current,
      owned: owned.contains,
      name: (x) => msLooks[x]!.name(ctx.lang),
      sub: (x) => msLooks[x]!.desc(ctx.lang),
      big: (x) => SizedBox(width: 380, child: thumb(x)),
      status: status,
      useLabel: ctx.w('use'),
      buyLabel: (_) => ctx.m('unlock', {'coins': '${fmt(n(th['price']))} ${ctx.m('coins')}'}),
      readOnly: ctx.readOnly || _busy.isNotEmpty,
      use: (x) async {
        await _save({...now, 'theme': x});
        return true;
      },
      buy: (x) => ctx.askBuy('mart_site_theme', item: x, onDone: () => _load(reset: true)),
    );
    return mCard(context, ctx.w('looksTitle'), sub: ctx.w('siteLooksSub', {'price': n(th['price'])}), [
      LayoutBuilder(
        builder: (_, box) {
          final cols = box.maxWidth > 520 ? 3 : 2;
          final w = (box.maxWidth - 10 * (cols - 1)) / cols;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final k in msLooks.keys)
                SizedBox(
                  width: w,
                  child: MLookCard(picture: thumb(k), name: msLooks[k]!.name(ctx.lang), on: current == k, locked: !owned.contains(k), status: status(k), onTap: () => open(k)),
                ),
            ],
          );
        },
      ),
    ]);
  }
}

// extra website pages (delivery info, promotions, FAQ…)
class _Pages extends StatefulWidget {
  final MartCtx ctx;
  final Json site;
  final ValueChanged<Json> setInfo;
  const _Pages({super.key, required this.ctx, required this.site, required this.setInfo});
  @override
  State<_Pages> createState() => _PagesState();
}

class _PagesState extends State<_Pages> {
  bool _busy = false;
  MartCtx get ctx => widget.ctx;

  Future<void> _move(List<Json> pages, int i, int d) async {
    final ids = pages.map((x) => str(x['_id'])).toList();
    final t = ids[i];
    ids[i] = ids[i + d];
    ids[i + d] = t;
    setState(() => _busy = true);
    try {
      final r = await ctx.api.put('${ctx.base}/site/pages-order', {'ids': ids});
      widget.setInfo(obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(Json row) => showSheet<void>(context, (_) => _PageEditor(ctx: ctx, row: row, setInfo: widget.setInfo));

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pages = objs(widget.site['pages']);
    final templates = (ctx.t.raw('mw.pageTemplates') as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final site = widget.site;
    String url(Object? k) => str(site['slug']).isNotEmpty && site['published'] == true ? '${Config.siteUrl}/m/${site['slug']}?p=$k' : '';
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MHead(
            ctx.w('pagesTitle'),
            icon: LucideIcons.fileText,
            sub: ctx.w('pagesSub', {'n': 8}),
            trailing: pages.length < 8 ? Btn(ctx.w('pageAdd'), icon: LucideIcons.plus, small: true, onTap: ctx.readOnly ? null : () => _edit({'title': '', 'body': '', 'visible': true})) : null,
          ),
          if (pages.length < 8 && templates.isNotEmpty) ...[
            Text(
              ctx.w('pageIdeas'),
              style: TextStyle(color: c.muted, fontWeight: FontWeight.w800, fontSize: 12.5),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in templates)
                  ActionChip(
                    avatar: const Icon(LucideIcons.plus, size: 14),
                    label: Text(str(t['title'])),
                    onPressed: ctx.readOnly ? null : () => _edit({'title': t['title'], 'body': t['body'], 'visible': true}),
                    side: BorderSide(color: c.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                  ),
              ],
            ),
            gap14,
          ],
          if (pages.isEmpty)
            Muted(ctx.w('pagesNone'))
          else
            for (final (i, x) in pages.indexed)
              Opacity(
                opacity: x['visible'] == false ? .6 : 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Column(
                        children: [
                          InkWell(
                            onTap: ctx.readOnly || _busy || i == 0 ? null : () => _move(pages, i, -1),
                            child: Icon(LucideIcons.chevronUp, size: 18, color: i == 0 ? c.lineStrong : c.ink),
                          ),
                          InkWell(
                            onTap: ctx.readOnly || _busy || i == pages.length - 1 ? null : () => _move(pages, i, 1),
                            child: Icon(LucideIcons.chevronDown, size: 18, color: i == pages.length - 1 ? c.lineStrong : c.ink),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(10)),
                        clipBehavior: Clip.antiAlias,
                        child: str(obj(x['image'])['url']).isNotEmpty
                            ? Image(image: netImage(str(obj(x['image'])['url'])), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())
                            : Icon(LucideIcons.fileText, size: 18, color: c.muted),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: ctx.readOnly ? null : () => _edit(x),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(str(x['title']), style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                str(x['body']).isEmpty ? '—' : str(x['body']),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: c.muted, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Pill(x['visible'] == false ? ctx.w('pageHidden') : ctx.w('pageShown'), tone: x['visible'] == false ? '' : 'ok'),
                      if (url(x['key']).isNotEmpty && x['visible'] != false)
                        IconButton(
                          onPressed: () => launchUrl(Uri.parse(url(x['key'])), mode: LaunchMode.externalApplication),
                          icon: const Icon(LucideIcons.externalLink, size: 16),
                        ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _PageEditor extends StatefulWidget {
  final MartCtx ctx;
  final Json row;
  final ValueChanged<Json> setInfo;
  const _PageEditor({required this.ctx, required this.row, required this.setInfo});
  @override
  State<_PageEditor> createState() => _PageEditorState();
}

class _PageEditorState extends State<_PageEditor> {
  late final _title = TextEditingController(text: str(widget.row['title'])), _body = TextEditingController(text: str(widget.row['body']));
  late bool _visible = widget.row['visible'] != false;
  late String? _id = widget.row['_id'] == null ? null : str(widget.row['_id']);
  late String _img = str(obj(widget.row['image'])['url']);
  String _busy = '';
  MartCtx get ctx => widget.ctx;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<Json?> _run(String kind, Future<Json> Function() fn) async {
    setState(() => _busy = kind);
    try {
      final r = await fn();
      widget.setInfo(obj(r['data']));
      return r;
    } catch (e) {
      ctx.fail(e);
      return null;
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Json? _page(Json? r) => objs(obj(obj(r?['data'])['site'])['pages']).where((p) => str(p['_id']) == _id).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final body = {'title': _title.text.trim(), 'body': _body.text, 'visible': _visible};
    return MSheet(
      title: _id != null ? ctx.w('pageEdit') : ctx.w('pageAdd'),
      footer: [
        if (_id != null)
          SureDelete(
            remove: ctx.w('pmRemove'),
            sure: ctx.m('sure'),
            onDelete: _busy.isNotEmpty
                ? null
                : () async {
                    if (await _run('del', () => ctx.api.delete('${ctx.base}/site/pages/$_id')) != null && context.mounted) Navigator.pop(context);
                  },
          ),
        const Spacer(),
        Btn(ctx.m('close'), kind: BtnKind.ghost, small: true, onTap: () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(
          _busy == 'save' ? ctx.w('saving') : ctx.w('save'),
          small: true,
          busy: _busy == 'save',
          onTap: _busy.isNotEmpty || _title.text.trim().isEmpty
              ? null
              : () async {
                  final r = await _run('save', () => _id != null ? ctx.api.put('${ctx.base}/site/pages/$_id', body) : ctx.api.post('${ctx.base}/site/pages', body));
                  if (r == null) return;
                  if (_id != null) {
                    if (context.mounted) Navigator.pop(context);
                    return;
                  }
                  // a new page: stay open so a picture can be added
                  final list = objs(obj(obj(r['data'])['site'])['pages']);
                  setState(() => _id = list.isEmpty ? null : str(list.last['_id']));
                  ctx.notify(ctx.w('saved'));
                },
        ),
      ],
      children: [
        Field(label: ctx.w('pageTitle'), controller: _title, maxLength: 60, autofocus: _id == null, onChanged: (_) => setState(() {})),
        gap14,
        Field(label: ctx.w('pageBody'), controller: _body, maxLength: 6000, maxLines: 10),
        const SizedBox(height: 4),
        Muted(ctx.w('pageBodyHint')),
        gap14,
        SwitchRow(title: ctx.w('pageShowMenu'), sub: ctx.w('pageShowMenuSub'), value: _visible, onChanged: (v) => setState(() => _visible = v)),
        gap14,
        if (_id != null) ...[
          Text(ctx.w('pagePic'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          MImagePick(
            ctx: ctx,
            url: _img,
            busy: _busy == 'img',
            maxSize: 1400,
            onPick: (b, name) async {
              final r = await _run('img', () => ctx.api.post('${ctx.base}/site/pages/$_id/image', fileForm('file', b, name)));
              final p = _page(r);
              if (p != null) setState(() => _img = str(obj(p['image'])['url']));
            },
            onRemove: () async {
              if (await _run('img', () => ctx.api.delete('${ctx.base}/site/pages/$_id/image')) != null) setState(() => _img = '');
            },
          ),
        ] else
          Muted(ctx.w('pagePicLater')),
      ],
    );
  }
}

// "Contact us" messages from the website
class _Inbox extends StatefulWidget {
  final MartCtx ctx;
  final ValueChanged<int> onUnread;
  const _Inbox({super.key, required this.ctx, required this.onUnread});
  @override
  State<_Inbox> createState() => _InboxState();
}

class _InboxState extends State<_Inbox> {
  List<Json>? _rows;
  bool _unreadOnly = false;
  String? _open;
  Timer? _timer;
  MartCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/messages', {if (_unreadOnly) 'unread': 'true'});
      if (!mounted) return;
      setState(() => _rows = objs(r['data']));
      if (r['unread'] != null) widget.onUnread(n(r['unread']).toInt());
    } catch (e) {
      if (_rows == null) ctx.fail(e);
    }
  }

  Future<void> _act(Future<Json> Function() fn) async {
    try {
      final r = await fn();
      if (r['unread'] != null) widget.onUnread(n(r['unread']).toInt());
      _load();
    } catch (e) {
      ctx.fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MHead(
            ctx.w('inboxTitle'),
            icon: LucideIcons.inbox,
            sub: ctx.w('inboxSub'),
            trailing: Btn(
              ctx.w('inboxAllRead'),
              icon: LucideIcons.checkCheck,
              kind: BtnKind.ghost,
              small: true,
              onTap: ctx.readOnly ? null : () => _act(() => ctx.api.post('${ctx.base}/messages/read-all')),
            ),
          ),
          Segmented<bool>(
            value: _unreadOnly,
            options: [(false, ctx.w('inboxAll')), (true, ctx.w('inboxUnread'))],
            onChanged: (v) {
              setState(() {
                _unreadOnly = v;
                _rows = null;
              });
              _load();
            },
          ),
          const SizedBox(height: 10),
          if (_rows == null)
            const SkelList(rows: 3)
          else if (_rows!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Icon(LucideIcons.inbox, size: 30, color: c.muted),
                  const SizedBox(height: 8),
                  Muted(ctx.w('inboxNone')),
                ],
              ),
            )
          else
            for (final m in _rows!)
              () {
                final open = _open == str(m['_id']);
                final contact = str(m['contact']);
                final mail = contact.contains('@');
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: m['read'] == true ? null : c.active,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          setState(() => _open = open ? null : str(m['_id']));
                          if (m['read'] != true && !ctx.readOnly) {
                            setState(() => m['read'] = true);
                            ctx.api.put('${ctx.base}/messages/${m['_id']}', {'read': true}).then((r) {
                              if (r['unread'] != null) widget.onUnread(n(r['unread']).toInt());
                            }, onError: (_) {});
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(m['read'] == true ? LucideIcons.mailOpen : LucideIcons.mail, size: 17, color: m['read'] == true ? c.muted : c.brand),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(str(m['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text(
                                      open ? (contact.isEmpty ? '—' : contact) : str(m['message']),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: c.muted, fontSize: 12.5),
                                    ),
                                  ],
                                ),
                              ),
                              Text(mDayTime(m['created_date'], ctx.lang), style: TextStyle(color: c.muted, fontSize: 11.5)),
                            ],
                          ),
                        ),
                      ),
                      if (open)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SelectableText(str(m['message'])),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (contact.isNotEmpty)
                                    Btn(
                                      mail ? ctx.w('inboxEmail') : ctx.w('inboxCall'),
                                      icon: mail ? LucideIcons.mail : LucideIcons.phone,
                                      small: true,
                                      onTap: () => launchUrl(Uri.parse(mail ? 'mailto:$contact' : 'tel:${contact.replaceAll(RegExp(r'[^\d+]'), '')}')),
                                    ),
                                  Btn(
                                    ctx.w('inboxMarkUnread'),
                                    icon: LucideIcons.mail,
                                    kind: BtnKind.ghost,
                                    small: true,
                                    onTap: ctx.readOnly ? null : () => _act(() => ctx.api.put('${ctx.base}/messages/${m['_id']}', {'read': false})),
                                  ),
                                  Btn(
                                    ctx.w('pmRemove'),
                                    icon: LucideIcons.trash2,
                                    kind: BtnKind.ghost,
                                    small: true,
                                    onTap: ctx.readOnly ? null : () => _act(() => ctx.api.delete('${ctx.base}/messages/${m['_id']}')),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              }(),
        ],
      ),
    );
  }
}
