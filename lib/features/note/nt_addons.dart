import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/look_sheet.dart';
import '../../widgets/ui.dart';
import '../mart/mart_kit.dart' show MSheet, showSheet;
import 'nt_alerts.dart' show NtTelegramArt;
import 'nt_common.dart';
import 'nt_data.dart';
import 'nt_more_text.dart';
import 'nt_more_ui.dart';
import 'nt_page.dart' show NtNav;
import 'nt_storage.dart' show NtPacksCard;
import 'nt_theme_tokens.dart';

// Add-ons (the web's AddonsTab): every product of Digital Note as a card — price, owned / active, unlock / renew.
//   storage packs · groups · signature & pen · style pack · page themes (a theme shop) · media manager ·
//   Telegram alerts · "I've read it" · sign-up fields + Excel · voice notes · PDF export · custom links ·
//   group pictures · the yearly plan

class AddonsSection extends StatelessWidget {
  final NtCtx ctx;
  final NtNav nav;
  const AddonsSection({super.key, required this.ctx, required this.nav});
  @override
  Widget build(BuildContext context) {
    final off = ctx.readOnly;
    final coins = ctx.m('coins');
    final forever = ctx.m('oneTimeForever');
    final lic = ctx.license;
    final groups = n(ctx.counts['groups'] ?? obj(ctx.addons['note_group'])['owned']).toInt();
    final paid = ntThemes.where((t) => t.key != 'default').toList();
    final ownedThemes = ctx.themesOwned.where((k) => k != 'default').length;
    final icons = ctx.groupIcons.length;

    Widget owned(String product, {bool yearly = false, List<Widget> more = const []}) {
      final a = obj(ctx.addons[product]);
      if (a['active'] == true) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            NtPill(yearly && a['expires_at'] != null ? ctx.m('planActive', {'date': ntDate(a['expires_at'], ctx.lang)}) : ctx.m('unlocked'), on: true, icon: yearly ? LucideIcons.calendarClock : LucideIcons.check),
            ...more,
            // renewing stays possible after the plan ended (the API allows it)
            if (yearly) Btn(ctx.m('renew', {'coins': fmt(ctx.price(product))}), kind: BtnKind.ghost, small: true, onTap: () => ctx.askBuy(product)),
          ],
        );
      }
      return NtGoldBtn(ctx.m('v4Unlock', {'coins': fmt(ctx.price(product))}), onTap: off ? null : () => ctx.askBuy(product));
    }

    String priceLine(String product, {bool yearly = false, String? per}) => '${fmt(ctx.price(product))} $coins ${per ?? (yearly ? ctx.m('perYearPlan') : '· $forever')}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        ntHead(context, LucideIcons.puzzle, ctx.m('addonsTitle'), ctx.m('addonsSub')),
        ntGap,
        // storage packs (with the meter)
        NtPacksCard(ctx: ctx, showMeter: true),
        ntGap,
        // groups
        NtAddonCard(
          testKey: 'nt-addon-groups',
          icon: LucideIcons.folders,
          name: ctx.m('groupsCard'),
          price: priceLine('note_group', per: ctx.m('perGroup')),
          what: ctx.m('groupsWhat'),
          on: groups > 0,
          foot: [
            NtPill(groups > 0 ? ctx.m('groupsOwned', {'n': fmt(groups)}) : ctx.m('groupsNone'), on: groups > 0),
            NtGoldBtn(ctx.m('createGroup'), onTap: off ? null : () => nav.go('groups', args: {'new': '1'})),
          ],
        ),
        ntGap,
        // signature & pen
        NtAddonCard(
          testKey: 'nt-addon-sign',
          icon: LucideIcons.signature,
          name: ctx.m('signCard'),
          price: priceLine('note_sign'),
          what: ctx.m('signWhat'),
          on: ctx.sign,
          art: const _SignArt(),
          foot: [owned('note_sign')],
        ),
        ntGap,
        // style pack
        NtAddonCard(
          testKey: 'nt-addon-style',
          icon: LucideIcons.type,
          name: ctx.m('styleCard'),
          price: priceLine('note_style'),
          what: ctx.m('styleWhat'),
          on: ctx.style,
          art: const _StyleArt(),
          foot: [owned('note_style')],
        ),
        ntGap,
        // page themes
        NtAddonCard(
          testKey: 'nt-addon-themes',
          icon: LucideIcons.palette,
          name: ctx.m('themesCard'),
          price: priceLine('note_theme', per: ctx.m('themesPrice')),
          what: ctx.m('themesWhat'),
          on: ownedThemes > 0,
          art: GestureDetector(
            onTap: () => ntThemeShop(context, ctx),
            child: SizedBox(
              height: 118,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final k in ['chalk', 'temple', 'neon', 'wedding', 'sunset', 'blueprint'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: NtShopThemeMini(theme: k, width: 86),
                    ),
                ],
              ),
            ),
          ),
          foot: [
            NtPill(ctx.m('themesOwned', {'n': fmt(ownedThemes), 'total': fmt(paid.length)}), on: ownedThemes > 0),
            NtGoldBtn(ctx.m('themesOpen'), onTap: () => ntThemeShop(context, ctx)),
          ],
        ),
        ntGap,
        // media manager
        NtAddonCard(
          testKey: 'nt-addon-media',
          icon: LucideIcons.images,
          name: ctx.m('mediaCard'),
          price: priceLine('note_media'),
          what: ctx.m('mediaWhat'),
          on: ctx.media,
          foot: [
            if (ctx.media) ...[
              NtPill(ctx.m('unlocked'), on: true, icon: LucideIcons.check),
              Btn(ctx.m('tabs.media'), icon: LucideIcons.images, kind: BtnKind.ghost, small: true, onTap: () => nav.go('media')),
            ] else
              NtGoldBtn(ctx.m('mediaUnlock', {'coins': fmt(ctx.price('note_media'))}), onTap: off ? null : () => ctx.askBuy('note_media')),
          ],
        ),
        ntGap,
        // Telegram alerts (yearly)
        NtAddonCard(
          testKey: 'nt-addon-tg',
          icon: LucideIcons.bellRing,
          name: ctx.m('tgCard'),
          price: priceLine('note_telegram', yearly: true),
          what: ctx.m('tgWhat'),
          on: ctx.tg,
          art: NtTelegramArt(ctx: ctx),
          foot: [
            owned(
              'note_telegram',
              yearly: true,
              more: [Btn(ctx.m('tgSettings'), icon: LucideIcons.settings, kind: BtnKind.ghost, small: true, onTap: () => nav.go('alerts'))],
            ),
          ],
        ),
        ntGap,
        for (final (product, k, icon) in [('note_ack', 'ack', LucideIcons.circleCheckBig), ('note_form', 'fx', LucideIcons.sheet), ('note_voice', 'voice', LucideIcons.mic), ('note_pdf', 'pdf', LucideIcons.fileDown)]) ...[
          NtAddonCard(
            testKey: 'nt-addon-$k',
            icon: icon,
            name: ctx.m('${k}Card'),
            price: priceLine(product),
            what: ctx.m('${k}What'),
            on: ctx.owned(product),
            foot: [owned(product)],
          ),
          ntGap,
        ],
        // custom links
        NtAddonCard(
          testKey: 'nt-addon-link',
          icon: LucideIcons.link,
          name: ctx.m('linkCard'),
          price: priceLine('note_link'),
          what: ctx.m('linkWhat'),
          on: ctx.link,
          art: _LinkArt(ctx: ctx),
          foot: [
            if (ctx.link) ...[NtPill(ctx.m('linkOwnedPill'), on: true, icon: LucideIcons.check), Muted(ctx.m('linkOpen'))] else NtGoldBtn(ctx.m('linkUnlock', {'coins': fmt(ctx.price('note_link'))}), onTap: off ? null : () => ctx.askBuy('note_link')),
          ],
        ),
        ntGap,
        // group pictures
        NtAddonCard(
          testKey: 'nt-addon-groupicon',
          icon: LucideIcons.imagePlus,
          name: ctx.m('groupIconCard'),
          price: priceLine('note_group_icon', per: ctx.m('groupIconPrice')),
          what: ctx.m('groupIconWhat'),
          on: icons > 0,
          foot: [
            NtPill(icons > 0 ? ctx.m('groupsOwned', {'n': fmt(icons)}) : ctx.m('groupsNone'), on: icons > 0),
            Btn(ctx.m('tabs.groups'), icon: LucideIcons.folders, kind: BtnKind.ghost, small: true, onTap: () => nav.go('groups')),
          ],
        ),
        ntGap,
        // the yearly plan
        NtAddonCard(
          testKey: 'nt-addon-plan',
          icon: LucideIcons.stickyNote,
          name: ctx.m('planCard'),
          price: priceLine('digital_note', yearly: true),
          what: ctx.m('planWhat'),
          on: lic['active'] == true,
          foot: [
            if (lic['expires_at'] != null)
              NtPill(
                lic['active'] == true ? ctx.m('planActive', {'date': ntDate(lic['expires_at'], ctx.lang)}) : ctx.m('planEnded', {'date': ntDate(lic['expires_at'], ctx.lang)}),
                on: lic['active'] == true,
                bad: lic['active'] != true,
                icon: LucideIcons.calendarClock,
              ),
            Btn(ctx.m('renew', {'coins': fmt(ctx.price('digital_note'))}), kind: BtnKind.ghost, small: true, onTap: () => ctx.askBuy('digital_note')),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- small pictures on the cards
class _SignArt extends StatelessWidget {
  const _SignArt();
  @override
  Widget build(BuildContext context) => Container(
    height: 70,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.c.line)),
    child: CustomPaint(painter: _SignPainter(), size: Size.infinite),
  );
}

class _SignPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 300, sy = size.height / 70;
    final p = Path()
      ..moveTo(18 * sx, 48 * sy)
      ..cubicTo(32 * sx, 22 * sy, 44 * sx, 14 * sy, 48 * sx, 24 * sy)
      ..cubicTo(52 * sx, 36 * sy, 34 * sx, 54 * sy, 40 * sx, 56 * sy)
      ..cubicTo(48 * sx, 58 * sy, 60 * sx, 26 * sy, 70 * sx, 28 * sy)
      ..cubicTo(78 * sx, 30 * sy, 70 * sx, 52 * sy, 78 * sx, 52 * sy)
      ..cubicTo(88 * sx, 52 * sy, 94 * sx, 30 * sy, 104 * sx, 30 * sy)
      ..cubicTo(112 * sx, 30 * sy, 108 * sx, 48 * sy, 116 * sx, 48 * sy)
      ..cubicTo(128 * sx, 48 * sy, 134 * sx, 34 * sy, 146 * sx, 34 * sy)
      ..cubicTo(156 * sx, 34 * sy, 152 * sx, 46 * sy, 162 * sx, 46 * sy)
      ..cubicTo(176 * sx, 46 * sy, 184 * sx, 36 * sy, 202 * sx, 34 * sy);
    canvas.drawPath(
      p,
      Paint()
        ..color = const Color(0xFF1F3A93)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(14 * sx, 60 * sy),
      Offset(286 * sx, 60 * sy),
      Paint()
        ..color = const Color(0xFFCBD0DA)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StyleArt extends StatelessWidget {
  const _StyleArt();
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget chip(Color bg, Widget child) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: child,
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          chip(
            const Color(0xFFFDE2E2),
            const Text(
              'Aa',
              style: TextStyle(color: Color(0xFFC62F34), fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
          chip(
            const Color(0xFFFFF1C7),
            const Text('💡 Tip', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          chip(const Color(0xFFDDE9FF), const Text('🎉 😀 🛺 🇰🇭')),
          chip(
            const Color(0xFFDCF5E6),
            const Text(
              'Big',
              style: TextStyle(color: Color(0xFF1F7A4C), fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ),
          chip(
            const Color(0xFFEFE2FB),
            const Text(
              'Italic',
              style: TextStyle(color: Color(0xFF7A3FB0), fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkArt extends StatelessWidget {
  final NtCtx ctx;
  const _LinkArt({required this.ctx});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final slug = ctx.bizName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    Widget line(String path, {bool big = false}) => Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: big ? c.goodBg : c.bg2, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(big ? LucideIcons.circleCheck : LucideIcons.link, size: 15, color: big ? c.good : c.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '…/n/',
                    style: TextStyle(color: c.muted),
                  ),
                  TextSpan(
                    text: path,
                    style: TextStyle(fontWeight: big ? FontWeight.w800 : FontWeight.w500, color: big ? c.ink : c.muted),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    return Column(
      children: [
        line('UjkylAidWOOCeQJP1mSEfP'),
        line(slug.length >= 3 ? '$slug-menu' : 'my-shop-menu', big: true),
      ],
    );
  }
}

// ---------------------------------------------------------------- page themes: small + big previews, the shop
String _fontOf(String f) => switch (f) {
  'serif' => defaultTargetPlatform == TargetPlatform.iOS ? 'Georgia' : 'serif',
  'mono' => defaultTargetPlatform == TargetPlatform.iOS ? 'Menlo' : 'monospace',
  'hand' => defaultTargetPlatform == TargetPlatform.iOS ? 'Chalkboard SE' : 'cursive',
  _ => 'PlusJakartaSans',
};

NtThemeTokens _tokens(String key) => ntThemeTokens[key] ?? ntThemeTokens['default']!;
Color _accent(String key, [String colour = '']) {
  final hex = colour.isNotEmpty ? colour : ntThemes.firstWhere((t) => t.key == key, orElse: () => ntThemes.first).accent;
  final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return v == null ? const Color(0xFFE0581A) : Color(0xFF000000 | v);
}

BoxDecoration _pageBg(NtThemeTokens t) =>
    t.page.length > 1 ? BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [for (final v in t.page) Color(v)])) : BoxDecoration(color: Color(t.page.first));

// a small card: the page colour, a note card with a title, lines and the accent button
class NtShopThemeMini extends StatelessWidget {
  final String theme;
  final double width;
  const NtShopThemeMini({super.key, required this.theme, this.width = 96});
  @override
  Widget build(BuildContext context) {
    final t = _tokens(theme);
    final acc = _accent(theme);
    final ink = Color(t.ink), muted = Color(t.muted);
    return Container(
      width: width,
      height: width * 1.3,
      decoration: _pageBg(t).copyWith(borderRadius: BorderRadius.circular(14), border: Border.all(color: context.c.line)),
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.all(width * .1),
      child: Container(
        decoration: BoxDecoration(color: Color(t.card), borderRadius: BorderRadius.circular(8), border: Border.all(color: Color(t.line))),
        padding: EdgeInsets.all(width * .08),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aa',
              style: TextStyle(fontFamily: _fontOf(t.font), color: ink, fontWeight: FontWeight.w800, fontSize: width * .17, height: 1.1),
            ),
            SizedBox(height: width * .05),
            for (final f in [.9, .7, .8])
              Padding(
                padding: EdgeInsets.only(bottom: width * .04),
                child: FractionallySizedBox(
                  widthFactor: f,
                  child: Container(
                    height: width * .035,
                    decoration: BoxDecoration(color: muted.withValues(alpha: .45), borderRadius: BorderRadius.circular(9)),
                  ),
                ),
              ),
            const Spacer(),
            Container(
              height: width * .13,
              decoration: BoxDecoration(color: acc, borderRadius: BorderRadius.circular(99)),
            ),
          ],
        ),
      ),
    );
  }
}

// a big phone page in the theme (the look sheet preview)
class NtShopThemePage extends StatelessWidget {
  final NtCtx ctx;
  final String theme;
  const NtShopThemePage({super.key, required this.ctx, required this.theme});
  @override
  Widget build(BuildContext context) {
    final t = _tokens(theme);
    final acc = _accent(theme);
    final ink = Color(t.ink), muted = Color(t.muted), line = Color(t.line), card = Color(t.card);
    final font = _fontOf(t.font);
    TextStyle s(double size, {FontWeight w = FontWeight.w500, Color? color}) => TextStyle(fontFamily: font, fontFamilyFallback: const ['KantumruyPro'], fontSize: size, fontWeight: w, color: color ?? ink, height: 1.35);
    Widget check(bool done, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: done ? acc : Colors.transparent, borderRadius: BorderRadius.circular(5), border: Border.all(color: done ? acc : muted, width: 1.6)),
            child: done ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: s(12.5, color: done ? muted : ink).copyWith(decoration: done ? TextDecoration.lineThrough : null),
            ),
          ),
        ],
      ),
    );
    return Container(
      width: 300,
      height: 600,
      decoration: _pageBg(t).copyWith(borderRadius: BorderRadius.circular(28), border: Border.all(color: context.c.lineStrong, width: 3)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // top bar
          Container(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
            color: card.withValues(alpha: .86),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: acc, borderRadius: BorderRadius.circular(7)),
                  child: const Icon(LucideIcons.stickyNote, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(ctx.bizName.isEmpty ? 'Sokha Coffee' : ctx.bizName, maxLines: 1, overflow: TextOverflow.ellipsis, style: s(12.5, w: FontWeight.w700)),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(), // never cut: longer (Khmer) text just runs below the frame
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: line),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 18, offset: const Offset(0, 8))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ctx.km ? 'ប្រជុំក្រុម — ហាងថ្មី' : 'Team meeting — new shop', style: s(19, w: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(ctx.km ? 'បានកែ ១២ នាទីមុន' : 'Changed 12 min ago', style: s(11, color: muted)),
                        const SizedBox(height: 12),
                        Text(ctx.km ? 'របៀបវារៈ' : 'Agenda', style: s(14.5, w: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text(ctx.km ? 'ម៉ោងបើកហាងថ្មី និងអ្នកធ្វើការថ្ងៃអាទិត្យ។' : 'Opening times for the new shop and who works on Sunday.', style: s(12.5)),
                        const SizedBox(height: 10),
                        check(true, ctx.km ? 'បញ្ជាទិញស្លាកថ្មី' : 'Order the new sign'),
                        check(false, ctx.km ? 'បោះពុម្ពបញ្ជីតម្លៃ' : 'Print the price list'),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.only(left: 10),
                          decoration: BoxDecoration(border: Border(left: BorderSide(color: acc, width: 3))),
                          child: Text(ctx.km ? 'ប្រជុំថ្ងៃសៅរ៍ ម៉ោង ៩:០០' : 'Meeting on Saturday 9:00 at the shop.', style: s(12, color: muted).copyWith(fontStyle: FontStyle.italic)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // a reply
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Color.alphaBlend(ink.withValues(alpha: .05), card), borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: acc,
                          child: const Text(
                            'S',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Sokha', style: s(12, w: FontWeight.w800)),
                              Text(ctx.km ? 'បើក ៧:៣០ ល្អជាង។' : 'Opening at 7:30 is better.', style: s(12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: acc, borderRadius: BorderRadius.circular(99)),
                    child: Text(
                      ctx.km ? 'សរសេរនៅខាងក្រោម' : 'Write below',
                      style: s(13.5, w: FontWeight.w800, color: Colors.white),
                    ),
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

// the theme shop: every paid theme as a small card; tap one → the big preview (swipe), unlock it there
Future<void> ntThemeShop(BuildContext context, NtCtx ctx) => showSheet<void>(context, (_) => _ThemeShop(ctx: ctx));

class _ThemeShop extends StatefulWidget {
  final NtCtx ctx;
  const _ThemeShop({required this.ctx});
  @override
  State<_ThemeShop> createState() => _ThemeShopState();
}

class _ThemeShopState extends State<_ThemeShop> {
  NtCtx get ctx => widget.ctx;
  final Set<String> _bought = {};
  List<NtTheme> get _list => ntThemes.where((t) => t.key != 'default').toList();
  bool _owned(String k) => ctx.themesOwned.contains(k) || _bought.contains(k);

  void _open(int i) {
    final list = _list;
    showLookSheet(
      context,
      title: ctx.m('themesCard'),
      count: list.length,
      initial: i,
      item: (_, j, refresh) {
        final th = list[j];
        final own = _owned(th.key);
        return LookItem(
          name: th.name(ctx.km),
          sub: ctx.m('themeUnlockSub'),
          preview: NtShopThemePage(ctx: ctx, theme: th.key),
          badge: own ? ctx.m('themeOwned') : '${fmt(ctx.price('note_theme'))} ${ctx.m('coins')}',
          badgeTone: own ? Tone.good : Tone.warn,
          acts: [
            if (own)
              LookAct(ctx.m('themeOwned'), icon: LucideIcons.check, ghost: true)
            else
              LookAct(
                ctx.m('v4Unlock', {'coins': fmt(ctx.price('note_theme'))}),
                gold: true,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        final ok = await ctx.askBuy('note_theme', item: th.key);
                        if (ok && mounted) {
                          setState(() => _bought.add(th.key));
                          refresh();
                        }
                        return false;
                      },
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final list = _list;
    final owned = list.where((t) => _owned(t.key)).length;
    return MSheet(
      title: ctx.m('themesCard'),
      children: [
        Muted('${ctx.m('themesWhat')} ${ntw(ctx, 'themeTapToSee')}'),
        const SizedBox(height: 8),
        Row(
          children: [
            NtPill(ctx.m('themesOwned', {'n': fmt(owned), 'total': fmt(list.length)}), on: owned > 0),
            const Spacer(),
            const CoinIcon(size: 14),
            const SizedBox(width: 4),
            Text('${fmt(ctx.price('note_theme'))} ${ctx.m('coins')} ${ctx.m('themesPrice')}', style: TextStyle(color: c.muted, fontSize: 12.5)),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (_, box) {
            final cols = (box.maxWidth / 110).floor().clamp(3, 6);
            final w = (box.maxWidth - (cols - 1) * 10) / cols;
            return Wrap(
              spacing: 10,
              runSpacing: 12,
              children: [
                for (final (i, th) in list.indexed)
                  GestureDetector(
                    key: ValueKey('theme-${th.key}'),
                    onTap: () => _open(i),
                    child: SizedBox(
                      width: w,
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              NtShopThemeMini(theme: th.key, width: w),
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(color: _owned(th.key) ? c.good : const Color(0xFFE0A21A), shape: BoxShape.circle),
                                  child: Icon(_owned(th.key) ? LucideIcons.check : LucideIcons.lock, size: 11, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            th.name(ctx.km),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
