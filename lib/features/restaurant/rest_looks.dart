import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/buy_sheet.dart';
import '../../widgets/look_sheet.dart';
import '../../widgets/ui.dart';
import 'rest_common.dart';
import 'rest_receipt.dart';

// Receipt look + POS look (the web's ReceiptTab.jsx, PosLookTab.jsx): Classic is free, the others are unlocked once.

extension on RestCtx {
  String x(String key, [Map<String, Object?> vars = const {}]) => t('extras.$key', vars);
}

// a made-up paid bill, printed with the restaurant's real name, logo and money settings (sampleOrder on the web)
Json sampleOrder(RestCtx ctx) {
  final rows = ctx.t.raw('extras.sample');
  final list = rows is List ? rows.whereType<List>().toList() : const <List>[];
  final now = DateTime.now().toUtc().toIso8601String();
  return {
    'number': 'A-0042',
    'table_name': 'A3',
    'type': 'dine_in',
    'status': 'paid',
    'lines': [
      for (final (i, r) in list.indexed)
        {
          'id': 's$i',
          'item_id': 's$i',
          'name_en': r[0],
          'name_km': r[1],
          'qty': r[2],
          'unit_price': r[3],
          'addons': i == 0
              ? [
                  {'name': 'Less sugar', 'price': 0},
                ]
              : [],
          'status': 'sent',
        },
    ],
    'payments': [
      {'id': 'p', 'method': 'Cash', 'kind': 'cash', 'currency': 'USD', 'amount': 20},
    ],
    'change': {'usd': 0, 'khr': 0},
    'discount': {'kind': '', 'value': 0},
    'opened_at': now,
    'paid_at': now,
    'closed_by': {'name': 'Dara'},
  };
}

Json moneyOfSettings(Json s) => {
  'currency': str(s['currency']).isEmpty ? 'USD' : s['currency'],
  'khr_rate': n(s['khr_rate']) == 0 ? 4100 : s['khr_rate'],
  'khr_rounding': n(s['khr_rounding']) == 0 ? 100 : s['khr_rounding'],
  'vat': obj(s['vat']),
  'service_charge': obj(s['service_charge']),
};

Json restaurantOfSettings(Json s) => {
  'name_km': s['name_km'],
  'name_en': s['name_en'],
  'logo': obj(s['logo'])['url'] ?? '',
  'address': s['address'],
  'phone': s['phone'],
  'tin': s['tin'],
  'receipt': {'footer': s['receipt_footer'], 'wifi_name': s['wifi_name'], 'wifi_pass': s['wifi_pass']},
};

// the restaurant's own receipt on paper, in one look (also the live preview in Profile / Money)
class SampleReceipt extends StatelessWidget {
  final RestCtx ctx;
  final Json settings;
  final String? theme;
  const SampleReceipt({super.key, required this.ctx, required this.settings, this.theme});
  @override
  Widget build(BuildContext context) => ReceiptPaper(
    size: n(settings['receipt_size']) == 58 ? 58 : 80,
    child: ReceiptView(
      order: sampleOrder(ctx),
      restaurant: restaurantOfSettings(settings),
      money: moneyOfSettings(settings),
      label: (k) => ctx.t('report.receipt.$k'),
      theme: theme ?? (str(settings['receipt_theme']).isEmpty ? 'classic' : str(settings['receipt_theme'])),
    ),
  );
}

// ------------------------------------------------------------------------------------------- shared gallery
// one look: picture, name, one status line (In use / Free / Owned / price). Tap → the look sheet.
class _LookCard extends StatelessWidget {
  final RestCtx ctx;
  final Widget picture;
  final String name;
  final bool free, owned, on;
  final num price;
  final VoidCallback? onTap;
  const _LookCard({required this.ctx, required this.picture, required this.name, required this.free, required this.owned, required this.on, required this.price, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: on ? c.good : c.line, width: on ? 2 : 1),
            boxShadow: on ? [BoxShadow(color: c.good.withValues(alpha: .15), blurRadius: 0, spreadRadius: 3)] : c.cardShadow,
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IgnorePointer(child: picture),
              const SizedBox(height: 8),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              lookStatus(context, ctx, on: on, free: free, owned: owned, price: price),
            ],
          ),
        ),
      ),
    );
  }
}

// In use ✓ · Free · Owned · 🔒 25
Widget lookStatus(BuildContext context, RestCtx ctx, {required bool on, required bool free, required bool owned, required num price, String? yearly}) {
  final c = context.c;
  final st = TextStyle(color: c.good, fontWeight: FontWeight.w700, fontSize: 12);
  if (on) {
    return Row(
      children: [
        Icon(LucideIcons.check, size: 14, color: c.good),
        const SizedBox(width: 3),
        Text(ctx.x('inUse'), style: st),
      ],
    );
  }
  if (free) return Text(ctx.x('free'), style: st.copyWith(color: c.muted));
  if (owned) return Text(ctx.x('owned'), style: st);
  return Row(
    children: [
      Icon(LucideIcons.lock, size: 12, color: c.muted),
      const SizedBox(width: 4),
      const CoinIcon(size: 13),
      const SizedBox(width: 3),
      Flexible(
        child: Text(
          '${fmt(price)}${yearly == null ? '' : ' · $yearly'}',
          overflow: TextOverflow.ellipsis,
          style: st.copyWith(color: c.muted),
        ),
      ),
    ],
  );
}

// two columns on a phone, more on a tablet
class _Gallery extends StatelessWidget {
  final List<Widget> children;
  final double min;
  const _Gallery({required this.children, this.min = 170});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) {
      final cols = (box.maxWidth / min).floor().clamp(1, 4);
      final w = (box.maxWidth - 12 * (cols - 1)) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [for (final x in children) SizedBox(width: w, child: x)],
      );
    },
  );
}

// the GET / PUT current / POST buy flow both screens share
mixin _Looks<W extends StatefulWidget> on State<W> {
  RestCtx get ctx;
  String get path; // receipt-themes | pos-themes
  String get settingKey; // receipt_theme | pos_theme
  Json? data;
  String busy = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/$path');
      if (mounted) setState(() => data = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> use(String theme) async {
    setState(() => busy = theme);
    try {
      final r = await ctx.api.put('${ctx.base}/$path/current', {'theme': theme});
      if (mounted) setState(() => data = obj(r['data']));
      ctx.setSettings({...ctx.settings, settingKey: theme});
      ctx.notify(ctx.r('saved'));
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => busy = '');
    }
  }

  List<String> get free => ((data?['free'] as List?) ?? const []).map((e) => '$e').toList();
  List<String> get paid => ((data?['paid'] as List?) ?? const []).map((e) => '$e').toList();
  List<String> get owned => ((data?['owned'] as List?) ?? const []).map((e) => '$e').toList();
  num get price => n(data?['price']);

  // tap a look → the look sheet over all of them (swipe), Use / Unlock at the bottom
  Future<void> openLooks(
    List<String> all,
    String start, {
    required Widget Function(String k) big,
    required String Function(String k) name,
    required String Function(String k) desc,
    required Future<void> Function(String k) onBuy,
  }) => showLookSheet(
    context,
    title: ctx.x(path == 'pos-themes' ? 'plTitle' : 'rtTitle'),
    count: all.length,
    initial: all.contains(start) ? all.indexOf(start) : 0,
    item: (context, i, refresh) {
      final k = all[i];
      final on = str(data?['current']) == k;
      final has = free.contains(k) || owned.contains(k);
      return LookItem(
        name: name(k),
        sub: desc(k),
        preview: big(k),
        badge: on ? ctx.x('inUse') : (free.contains(k) ? ctx.x('free') : (has ? ctx.x('owned') : '${fmt(price)} ${ctx.r('coins')}')),
        badgeTone: on || has ? Tone.good : Tone.warn,
        acts: [
          if (!on && has)
            LookAct(
              ctx.x('use'),
              icon: LucideIcons.check,
              onTap: ctx.readOnly
                  ? null
                  : () async {
                      await use(k);
                      return true;
                    },
            ),
          if (!has)
            LookAct(
              ctx.r('buy', {'coins': '${fmt(price)} ${ctx.r('coins')}'}),
              gold: true,
              onTap: ctx.readOnly
                  ? null
                  : () async {
                      Future.microtask(() => onBuy(k));
                      return true;
                    },
            ),
        ],
      );
    },
  );

  Future<void> buy(String k, {required Widget stage, required String title, required String sub, required String perk, required String done}) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BuySheet(
        stage: stage,
        badge: ctx.x(path == 'pos-themes' ? 'plTitle' : 'rtTitle'),
        title: title,
        sub: sub,
        perks: [perk, '${ctx.r('oneTime')} · ${ctx.r('forever')}'],
        price: price,
        buyLabel: ctx.r('buy', {'coins': '${fmt(price)} ${ctx.r('coins')}'}),
        doneTitle: ctx.r('unlockedTag'),
        doneSub: done,
        doneButton: ctx.t('app.continue'),
        buy: () => ctx.api.post('${ctx.base}/$path/$k'),
        onDone: (_) => load().then((_) => use(k)),
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------- receipt look
class ReceiptLookSection extends StatefulWidget {
  final RestCtx ctx;
  const ReceiptLookSection({super.key, required this.ctx});
  @override
  State<ReceiptLookSection> createState() => _ReceiptLookSectionState();
}

class _ReceiptLookSectionState extends State<ReceiptLookSection> with _Looks {
  @override
  RestCtx get ctx => widget.ctx;
  @override
  String get path => 'receipt-themes';
  @override
  String get settingKey => 'receipt_theme';

  String _name(String k) => ctx.t.or('rtheme.$k.${ctx.lang}', k);
  String _desc(String k) => ctx.t.or('rtheme.$k.d_${ctx.lang}', '');

  // the top of the receipt, scaled to the card
  Widget _paper(String k, {double height = 250}) {
    final c = context.c;
    return Container(
      height: height,
      decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
      child: ShaderMask(
        shaderCallback: (r) =>
            const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black, Colors.black, Colors.transparent], stops: [0, .82, 1]).createShader(r),
        blendMode: BlendMode.dstIn,
        child: FittedBox(
          fit: BoxFit.fitWidth,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 300,
            child: SampleReceipt(ctx: ctx, settings: ctx.settings, theme: k),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (data == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 4));
    final all = [...free, ...paid];
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Panel(child: RestHead(ctx.x('rtTitle'), sub: ctx.x('rtSub'))),
          gap14,
          _Gallery(
            children: [
              for (final k in all)
                _LookCard(
                  ctx: ctx,
                  picture: _paper(k),
                  name: _name(k),
                  free: free.contains(k),
                  owned: owned.contains(k),
                  on: str(data!['current']) == k,
                  price: price,
                  onTap: () => openLooks(
                    all,
                    k,
                    big: (x) => SizedBox(
                      width: 300,
                      child: SampleReceipt(ctx: ctx, settings: ctx.settings, theme: x),
                    ),
                    name: _name,
                    desc: _desc,
                    onBuy: (x) => buy(
                      x,
                      stage: SizedBox(width: 200, child: _paper(x, height: 260)),
                      title: ctx.x('rtBuyTitle', {'name': _name(x)}),
                      sub: ctx.x('rtBuySub'),
                      perk: ctx.x('rtPerk'),
                      done: ctx.x('rtDone', {'name': _name(x)}),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Muted(ctx.x('rtNote'), align: TextAlign.center),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------- POS look
// colours and shapes of each look (pos/restThemes.js REST_POS_LOOKS)
class PosLook {
  final Color brand, bg, card, ink;
  final Color? brand2, onbrand;
  final String head, tile, ticket; // light | brand | dark · card | photo | list | round | bold | flat · plain | paper | dark
  final double r;
  final bool dark;
  const PosLook(this.brand, this.bg, this.card, this.ink, this.head, this.tile, this.ticket, this.r, {this.brand2, this.onbrand, this.dark = false});
  Color mix(Color a, double p, Color b) => Color.lerp(b, a, p / 100)!;
  Color get accent => brand2 ?? brand;
  Color get on => onbrand ?? Colors.white;
  Color get line => mix(ink, dark ? 16 : 10, card);
  Color get lineStrong => mix(ink, dark ? 26 : 18, card);
  Color get muted => mix(ink, 58, card);
  Color get active => mix(brand, dark ? 22 : 12, card);
}

const posLooks = <String, PosLook>{
  'classic': PosLook(Color(0xFF2563EB), Color(0xFFF4F6F9), Color(0xFFFFFFFF), Color(0xFF0F172A), 'light', 'card', 'plain', 12),
  'ocean': PosLook(Color(0xFF0369A1), Color(0xFFEAF4FB), Color(0xFFFFFFFF), Color(0xFF0C2A3F), 'brand', 'card', 'plain', 16),
  'sunset': PosLook(Color(0xFFEA580C), Color(0xFFFFF4EC), Color(0xFFFFFFFF), Color(0xFF431407), 'brand', 'photo', 'plain', 18, brand2: Color(0xFFE11D48)),
  'forest': PosLook(Color(0xFF15803D), Color(0xFFF0F5EF), Color(0xFFFFFFFF), Color(0xFF14290F), 'dark', 'list', 'plain', 10),
  'night': PosLook(Color(0xFF818CF8), Color(0xFF0B1020), Color(0xFF151B2E), Color(0xFFE5E9F5), 'dark', 'card', 'dark', 14, dark: true),
  'coffee': PosLook(Color(0xFF7C4A2D), Color(0xFFF6EFE6), Color(0xFFFFFAF3), Color(0xFF3B2416), 'brand', 'round', 'paper', 20),
  'neon': PosLook(Color(0xFFA3E635), Color(0xFF09090B), Color(0xFF18181B), Color(0xFFF4F4F5), 'dark', 'bold', 'dark', 8, onbrand: Color(0xFF111827), dark: true),
  'berry': PosLook(Color(0xFFC026D3), Color(0xFFFDF2FB), Color(0xFFFFFFFF), Color(0xFF3B0A3F), 'light', 'round', 'plain', 22, brand2: Color(0xFFDB2777)),
  'angkor': PosLook(Color(0xFFB45309), Color(0xFFF8F1E4), Color(0xFFFFFBF3), Color(0xFF3D2208), 'brand', 'list', 'paper', 6, brand2: Color(0xFF7C2D12)),
  'mint': PosLook(Color(0xFF0D9488), Color(0xFFECFDF8), Color(0xFFFFFFFF), Color(0xFF063B36), 'light', 'photo', 'plain', 16),
  'slate': PosLook(Color(0xFF334155), Color(0xFFEEF1F5), Color(0xFFFFFFFF), Color(0xFF0F172A), 'dark', 'flat', 'plain', 6),
  'candy': PosLook(Color(0xFFEC4899), Color(0xFFFFF0F7), Color(0xFFFFFFFF), Color(0xFF4A044E), 'brand', 'round', 'plain', 24, brand2: Color(0xFF06B6D4)),
  'paper': PosLook(Color(0xFF111111), Color(0xFFF5F2EA), Color(0xFFFFFDF8), Color(0xFF111111), 'light', 'flat', 'paper', 2),
};

const _dishes = [
  (LucideIcons.soup, 'Noodle soup', 'គុយទាវ', '2.50', Color(0xFFF59E0B)),
  (LucideIcons.coffee, 'Iced coffee', 'កាហ្វេទឹកកក', '1.50', Color(0xFF92400E)),
  (LucideIcons.salad, 'Mango salad', 'ញាំស្វាយ', '3.00', Color(0xFF16A34A)),
  (LucideIcons.pizza, 'Fried rice', 'បាយឆា', '2.75', Color(0xFFDC2626)),
  (LucideIcons.cupSoda, 'Lemon tea', 'តែក្រូចឆ្មា', '1.25', Color(0xFF0EA5E9)),
  (LucideIcons.iceCreamCone, 'Ice cream', 'ការ៉េម', '1.75', Color(0xFFDB2777)),
];

// a small picture of the POS in one look (PosMock on the web)
class PosMock extends StatelessWidget {
  final String look, name, lang;
  const PosMock({super.key, required this.look, required this.name, required this.lang});
  @override
  Widget build(BuildContext context) {
    final d = posLooks[look] ?? posLooks['classic']!;
    final km = lang == 'km';
    const fs = 9.0;
    final topBg = switch (d.head) {
      'brand' => null,
      'dark' => d.dark ? d.mix(d.card, 70, Colors.black) : d.mix(d.ink, 92, Colors.black),
      _ => d.card,
    };
    final topFg = d.head == 'brand' ? d.on : (d.head == 'dark' ? Colors.white : d.ink);
    final ticketBg = d.ticket == 'dark' ? d.mix(d.card, 80, Colors.black) : d.card;
    Widget item((IconData, String, String, String, Color) x) {
      final (icon, en, kmName, price, col) = x;
      final label = Text(
        km ? kmName : en,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: d.tile == 'photo' ? Colors.white : d.ink),
      );
      final priceText = Text(
        '\$$price',
        style: TextStyle(fontSize: fs, fontWeight: FontWeight.w800, color: d.tile == 'photo' ? Colors.white : (d.tile == 'bold' ? d.on : d.brand)),
      );
      final img = Container(
        decoration: BoxDecoration(
          color: d.tile == 'photo' ? null : Color.lerp(d.card, col, .18),
          gradient: d.tile == 'photo' ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(Colors.white, col, .55)!, col]) : null,
          shape: d.tile == 'round' ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: d.tile == 'round' || d.tile == 'photo' || d.tile == 'bold' ? null : BorderRadius.circular((d.r - 2).clamp(0, 30)),
          border: d.tile == 'flat' ? Border.all(color: d.line) : null,
        ),
        alignment: d.tile == 'photo' ? Alignment.topRight : Alignment.center,
        padding: d.tile == 'photo' ? const EdgeInsets.all(5) : null,
        child: Icon(icon, size: d.tile == 'list' ? 11 : 16, color: d.tile == 'photo' ? Colors.white : col),
      );
      final box = BoxDecoration(
        color: d.tile == 'flat' || d.tile == 'photo' ? Colors.transparent : d.card,
        borderRadius: BorderRadius.circular(d.r),
        border: d.tile == 'flat' || d.tile == 'photo' ? null : Border.all(color: d.line, width: d.tile == 'bold' ? 1.5 : 1),
      );
      return switch (d.tile) {
        'photo' => ClipRRect(
          borderRadius: BorderRadius.circular(d.r),
          child: SizedBox(
            height: 46,
            child: Stack(
              fit: StackFit.expand,
              children: [
                img,
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 3),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [label, priceText]),
                ),
              ],
            ),
          ),
        ),
        'list' => Container(
          decoration: box,
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              SizedBox(width: 18, height: 18, child: img),
              const SizedBox(width: 4),
              Expanded(child: label),
              priceText,
            ],
          ),
        ),
        'round' => Container(
          decoration: box,
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              FractionallySizedBox(widthFactor: .7, child: AspectRatio(aspectRatio: 1, child: img)),
              const SizedBox(height: 2),
              label,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(color: d.active, borderRadius: BorderRadius.circular(99)),
                child: priceText,
              ),
            ],
          ),
        ),
        'bold' => Container(
          decoration: box,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(aspectRatio: 4 / 3, child: img),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  (km ? kmName : en).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: d.ink),
                ),
              ),
              Container(color: d.brand, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), child: priceText),
            ],
          ),
        ),
        _ => Container(
          decoration: box,
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(aspectRatio: 4 / 3, child: img),
              const SizedBox(height: 2),
              label,
              priceText,
            ],
          ),
        ),
      };
    }

    Widget chip(String text, bool on) => Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: on ? d.brand : d.card,
        borderRadius: BorderRadius.circular(d.r + 2),
        border: Border.all(color: on ? d.brand : d.lineStrong),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: fs, fontWeight: FontWeight.w700, color: on ? d.on : d.ink),
      ),
    );
    Widget row(String a, String b, {bool bold = false, Color? color}) => Row(
      children: [
        Expanded(
          child: Text(
            a,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: fs, color: color ?? d.ink, fontWeight: bold ? FontWeight.w800 : FontWeight.w400),
          ),
        ),
        Text(
          b,
          style: TextStyle(fontSize: fs, color: color ?? d.ink, fontWeight: bold ? FontWeight.w800 : FontWeight.w400),
        ),
      ],
    );
    final cols = d.tile == 'list' ? 2 : 3;
    return Container(
      decoration: BoxDecoration(
        color: d.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: d.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: topBg,
              gradient: d.head == 'brand' ? LinearGradient(colors: [d.brand, d.accent]) : null,
              border: d.head == 'light' ? Border(bottom: BorderSide(color: d.line)) : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    name.isEmpty ? 'B' : name.substring(0, 1),
                    style: TextStyle(fontSize: fs, fontWeight: FontWeight.w800, color: d.brand),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: topFg),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: topFg.withValues(alpha: .14), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    'Dara',
                    style: TextStyle(fontSize: fs, fontWeight: FontWeight.w700, color: topFg),
                  ),
                ),
              ],
            ),
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [chip(km ? 'ទាំងអស់' : 'All', true), chip(km ? 'ម្ហូប' : 'Food', false), chip(km ? 'ភេសជ្ជៈ' : 'Drinks', false)]),
                        const SizedBox(height: 5),
                        for (var i = 0; i < _dishes.length; i += cols)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var j = i; j < i + cols; j++) ...[if (j > i) const SizedBox(width: 5), Expanded(child: j < _dishes.length ? item(_dishes[j]) : const SizedBox())],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 96,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: ticketBg,
                    border: Border(
                      left: BorderSide(color: d.ticket == 'paper' ? d.lineStrong : d.line, width: d.ticket == 'paper' ? 1.5 : 1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        km ? 'តុ A3' : 'Table A3',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: d.ink),
                      ),
                      const SizedBox(height: 4),
                      row('2 × ${km ? 'គុយទាវ' : 'Noodle soup'}', '\$5.00'),
                      const SizedBox(height: 4),
                      row('1 × ${km ? 'កាហ្វេទឹកកក' : 'Iced coffee'}', '\$1.50'),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: d.line)),
                        ),
                        child: row(km ? 'សរុប' : 'Total', '\$6.50', bold: true),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: d.brand, borderRadius: BorderRadius.circular(d.r)),
                        child: Text(
                          km ? 'គិតលុយ' : 'Pay',
                          style: TextStyle(fontSize: fs, fontWeight: FontWeight.w800, color: d.on),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PosLookSection extends StatefulWidget {
  final RestCtx ctx;
  const PosLookSection({super.key, required this.ctx});
  @override
  State<PosLookSection> createState() => _PosLookSectionState();
}

class _PosLookSectionState extends State<PosLookSection> with _Looks {
  @override
  RestCtx get ctx => widget.ctx;
  @override
  String get path => 'pos-themes';
  @override
  String get settingKey => 'pos_theme';

  String _name(String k) => ctx.t.or('postheme.$k.${ctx.lang}', k);
  String _desc(String k) => ctx.t.or('postheme.$k.d_${ctx.lang}', '');
  String get _shop {
    final s = ctx.settings;
    return str(s['name_en']).isNotEmpty ? str(s['name_en']) : (str(s['name_km']).isNotEmpty ? str(s['name_km']) : 'BizHub');
  }

  @override
  Widget build(BuildContext context) {
    if (data == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 4));
    final all = posLooks.keys.where((k) => free.contains(k) || paid.contains(k)).toList();
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Panel(child: RestHead(ctx.x('plTitle'), sub: ctx.x('plSub', {'coins': fmt(price)}))),
          gap14,
          _Gallery(
            min: 300,
            children: [
              for (final k in all)
                _LookCard(
                  ctx: ctx,
                  picture: PosMock(look: k, name: _shop, lang: ctx.lang),
                  name: _name(k),
                  free: free.contains(k),
                  owned: owned.contains(k),
                  on: str(data!['current']) == k,
                  price: price,
                  onTap: () => openLooks(
                    all,
                    k,
                    big: (x) => SizedBox(
                      width: 420,
                      child: PosMock(look: x, name: _shop, lang: ctx.lang),
                    ),
                    name: _name,
                    desc: _desc,
                    onBuy: (x) => buy(
                      x,
                      stage: SizedBox(
                        width: 300,
                        child: PosMock(look: x, name: _shop, lang: ctx.lang),
                      ),
                      title: ctx.x('plBuyTitle', {'name': _name(x)}),
                      sub: ctx.x('plBuySub'),
                      perk: ctx.x('plPerk'),
                      done: ctx.x('plDone', {'name': _name(x)}),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Muted(ctx.x('plNote'), align: TextAlign.center),
        ],
      ),
    );
  }
}
