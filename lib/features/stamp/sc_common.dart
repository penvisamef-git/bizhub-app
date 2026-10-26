import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart' show fmt;
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show GoldBtn;
import 'sc_data.dart';

// Loyalty Stamp Card — shared pieces (the web's dashboard/client/stamp/text.js helpers + the dashboard ctx).
//   GET /api/user/businesses/:id/stamps → { data: { business, program, levels, license, addons, themes, posters, icons, limits, totals, telegram, bot } }

class ScCtx {
  final String id;
  final Api api;
  final T t;
  final Json data;
  final Future<void> Function() reload;
  final void Function(String kind, {String? item}) askBuy; // 'renew' | an add-on key | 'theme' + item | 'poster' + item
  final void Function(String tab) go;
  final void Function(String text) notify;
  const ScCtx({required this.id, required this.api, required this.t, required this.data, required this.reload, required this.askBuy, required this.go, required this.notify});

  String get base => '${Api.user}/businesses/$id/stamps';
  String get lang => t.lang;
  Json get business => obj(data['business']);
  Json get program => obj(data['program']);
  Json get license => obj(data['license']);
  Json get totals => obj(data['totals']);
  Json get today => obj(totals['today']);
  List<Json> get levels => objs(data['levels']);
  Json addon(String k) => obj(obj(data['addons'])[k]);
  bool on(String k) => addon(k)['active'] == true;
  bool get readOnly => business['status'] == false || license['read_only'] == true;
  int get goal => n(program['goal']).toInt().clamp(3, 20);
  String get shopName => str(program['shop_name']).isNotEmpty ? str(program['shop_name']) : str(business['name']);
  List<String> get ownedThemes => (obj(data['themes'])['owned'] as List? ?? const []).map((e) => '$e').toList();
  List<String> get ownedPosters => (obj(data['posters'])['owned'] as List? ?? const []).map((e) => '$e').toList();
  num get themePrice => n(obj(data['themes'])['price']);
  num get posterPrice => n(obj(data['posters'])['price']);

  // the owner's words (sc.*) and the customer / desk pages' words (scp.*)
  String m(String key, [Map<String, Object?> vars = const {}]) => t('sc.$key', vars);
  String p(String key, [Map<String, Object?> vars = const {}]) => t('scp.$key', vars);

  ScShop shop({String? theme, String? color, String? icon, int? goal, List<Json>? levels, String? name}) => ScShop(
    name: name ?? shopName,
    logo: str(program['logo']),
    theme: theme ?? str(program['theme']),
    color: color ?? str(program['color']),
    icon: icon ?? str(program['icon']),
    goal: goal ?? this.goal,
    levels: levels ?? this.levels,
  );

  void fail(Object e) {
    if (e is ApiError && e.status == 402 && e.body['product'] != null) {
      final pr = str(e.body['product']);
      if (pr == 'sc_theme') return askBuy('theme', item: str(e.body['item']));
      if (pr == 'sc_poster') return askBuy('poster', item: str(e.body['item']));
      return askBuy(pr);
    }
    if (e is ApiError) return notify(e.network ? t('app.offline') : e.message);
    notify('$e');
  }

  Future<Json?> run(Future<Json> Function() fn, [String? ok]) async {
    try {
      final r = await fn();
      if (ok != null) notify(ok);
      return r;
    } catch (e) {
      fail(e);
      return null;
    }
  }
}

// what a card shows (StampCard.jsx `shop`)
class ScShop {
  final String name, logo, theme, color, icon;
  final int goal;
  final List<Json> levels;
  const ScShop({required this.name, this.logo = '', this.theme = 'classic', this.color = '', this.icon = 'coffee', this.goal = 10, this.levels = const []});
}

ScTheme scThemeOf(String key) => scThemes[key] ?? scThemes['classic']!;
String scThemeName(String key, String lang) => lang == 'km' ? scThemeOf(key).km : scThemeOf(key).en;
ScPoster scPosterOf(String key) => scPosters[key] ?? scPosters['basic']!;
String scPosterName(String key, String lang) => lang == 'km' ? scPosterOf(key).km : scPosterOf(key).en;

// the 14 stamp pictures (themes.js SC_ICONS)
const scIcons = <String, IconData>{
  'coffee': LucideIcons.coffee,
  'cup': LucideIcons.cupSoda,
  'star': LucideIcons.star,
  'heart': LucideIcons.heart,
  'scissors': LucideIcons.scissors,
  'car': LucideIcons.car,
  'shirt': LucideIcons.shirt,
  'utensils': LucideIcons.utensilsCrossed,
  'gift': LucideIcons.gift,
  'paw': LucideIcons.pawPrint,
  'drop': LucideIcons.droplets,
  'cake': LucideIcons.cake,
  'flower': LucideIcons.flower2,
  'crown': LucideIcons.crown,
};
IconData scIconOf(String key) => scIcons[key] ?? LucideIcons.coffee;

const scAddonIcons = <String, IconData>{
  'sc_check': LucideIcons.searchCheck,
  'sc_telegram': LucideIcons.send,
  'sc_more': LucideIcons.users,
  'sc_levels': LucideIcons.layers,
  'sc_expiry': LucideIcons.hourglass,
};

// "#c2410c" → Color (empty / bad → null)
Color? scHex(String v) {
  final h = v.replaceAll('#', '').trim();
  if (h.length != 6) return null;
  final x = int.tryParse(h, radix: 16);
  return x == null ? null : Color(0xFF000000 | x);
}

String scColorHex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

// CSS "160deg" → a Flutter gradient direction
LinearGradient scGradient(List<Color> colors, double deg) {
  if (colors.length == 1) return LinearGradient(colors: [colors.first, colors.first]);
  final r = deg * math.pi / 180;
  final dx = math.sin(r), dy = -math.cos(r);
  return LinearGradient(begin: Alignment(-dx, -dy), end: Alignment(dx, dy), colors: colors);
}

String levelName(Json l, String lang) {
  final en = str(l['en']), km = str(l['km']);
  return lang == 'km' ? (km.isNotEmpty ? km : en) : (en.isNotEmpty ? en : km);
}

// 012 345 678
String prettyPhone(Object? p) {
  final s = str(p);
  final m = RegExp(r'^(\d{3})(\d{3})(\d{3,4})$').firstMatch(s);
  return m == null ? s : '${m[1]} ${m[2]} ${m[3]}';
}

String scAgo(Object? d, ScCtx ctx) {
  final x = DateTime.tryParse('${d ?? ''}');
  if (x == null) return '';
  final min = DateTime.now().difference(x).inMinutes;
  if (min < 1) return ctx.m('justNow');
  if (min < 60) return ctx.m('minAgo', {'n': min});
  if (min < 60 * 24) return ctx.m('hAgo', {'n': min ~/ 60});
  return ctx.m('dAgo', {'n': min ~/ (60 * 24)});
}

const _monEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monKm = ['មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា', 'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ'];
DateTime? _kh(Object? d) => DateTime.tryParse('${d ?? ''}')?.toUtc().add(const Duration(hours: 7));
String scDate(Object? d, String lang) {
  final x = _kh(d);
  return x == null ? '' : '${x.day} ${(lang == 'km' ? _monKm : _monEn)[x.month - 1]} ${x.year}';
}

String scTime(Object? d, String lang) {
  final x = _kh(d);
  if (x == null) return '';
  return '${x.day} ${(lang == 'km' ? _monKm : _monEn)[x.month - 1]}, ${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';
}

// "2026-10-18" → 18 Oct
String scDay(String day, String lang) {
  final x = DateTime.tryParse('${day}T00:00:00Z');
  return x == null ? day : '${x.day} ${(lang == 'km' ? _monKm : _monEn)[x.month - 1]}';
}

String shopUrl(Object? slug) => '${Config.siteUrl}/stamp/$slug';
String cardUrl(Object? token) => '${Config.siteUrl}/stamp/c/$token';
String deskUrl(Object? slug) => '${Config.siteUrl}/stamp/desk/$slug';

Future<void> scCopy(ScCtx ctx, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  ctx.notify(ctx.m('copied'));
}

// one history line: "+1 stamp" / "Got Free latte" / "Fixed -2" …
String scEvent(Json e, ScCtx ctx) {
  final k = str(e['kind']);
  final nn = n(e['n']).toInt();
  if (k == 'stamp') return ctx.m('ev.stamp', {'n': nn});
  if (k == 'reward') {
    final parts = str(e['reward']).split(' · ');
    return ctx.m('ev.reward', {'reward': parts.length > 1 ? parts[ctx.lang == 'km' ? 0 : 1] : str(e['reward'])});
  }
  if (k == 'adjust') return ctx.m('ev.adjust', {'n': nn > 0 ? '+$nn' : '$nn'});
  if (k == 'expire') return ctx.m('ev.expire', {'n': nn.abs()});
  return ctx.m('ev.join');
}

String scBy(Json e, ScCtx ctx) {
  final by = obj(e['by']);
  final who = ctx.t.or('sc.by.${by['kind']}', str(by['kind']));
  return str(by['name']).isNotEmpty ? '$who (${by['name']})' : who;
}

const scGap = SizedBox(height: 14);

Widget scPanel(List<Widget> children, {EdgeInsets padding = const EdgeInsets.all(16)}) => Panel(
  padding: padding,
  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
);

Widget scHead(BuildContext context, IconData icon, String title, String sub, {Widget? trailing}) {
  final c = context.c;
  return scPanel([
    Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [c.brand, c.brand2]),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        ),
        ?trailing,
      ],
    ),
    const SizedBox(height: 8),
    Muted(sub),
  ]);
}

Widget scTitle(BuildContext context, String text, {IconData? icon, String? count}) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Row(
    children: [
      if (icon != null) ...[Icon(icon, size: 17, color: context.c.brand), const SizedBox(width: 8)],
      Flexible(
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
      ),
      if (count != null) ...[const SizedBox(width: 8), Text(count, style: TextStyle(color: context.c.muted, fontWeight: FontWeight.w700))],
    ],
  ),
);

Future<bool> scConfirm(BuildContext context, ScCtx ctx, String title, {String? sub, String? yes, bool danger = true}) async =>
    await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: sub == null ? null : Text(sub),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(ctx.m('cancel'))),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: d.c.danger) : null,
            onPressed: () => Navigator.pop(d, true),
            child: Text(yes ?? ctx.m('yes')),
          ),
        ],
      ),
    ) ==
    true;

// "this needs an add-on" with a buy button (ScTabs.jsx Locked)
class ScLocked extends StatelessWidget {
  final ScCtx ctx;
  final String addon;
  final bool small;
  const ScLocked({super.key, required this.ctx, required this.addon, this.small = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a = ctx.addon(addon);
    if (small) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.warnBg, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.lock, size: 15, color: c.warn),
                const SizedBox(width: 8),
                Expanded(child: Text(ctx.m('addonWhat.$addon'), style: const TextStyle(fontSize: 13, height: 1.4))),
              ],
            ),
            const SizedBox(height: 8),
            GoldBtn(ctx.m('unlock', {'coins': fmt(n(a['price']))}), onTap: ctx.readOnly ? null : () => ctx.askBuy(addon)),
          ],
        ),
      );
    }
    return scPanel([
      Center(child: Icon(scAddonIcons[addon] ?? LucideIcons.lock, size: 30, color: c.brand)),
      const SizedBox(height: 8),
      Text(
        ctx.m('addonNames.$addon'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      const SizedBox(height: 4),
      Muted(ctx.m('addonWhat.$addon'), align: TextAlign.center),
      const SizedBox(height: 8),
      for (final p in ctx.t.list('sc.perks.$addon'))
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.check, size: 15, color: c.good),
              const SizedBox(width: 8),
              Expanded(child: Text(p)),
            ],
          ),
        ),
      const SizedBox(height: 8),
      Center(
        child: GoldBtn(ctx.m('unlock', {'coins': '${fmt(n(a['price']))} ${ctx.m('coins')}${a['days'] != null ? ' ${ctx.m('perYear')}' : ''}'}), onTap: ctx.readOnly ? null : () => ctx.askBuy(addon)),
      ),
    ]);
  }
}

// a customer's first letter in a circle
class ScAvatar extends StatelessWidget {
  final String name;
  final double size;
  const ScAvatar(this.name, {super.key, this.size = 42});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = name.trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.active, shape: BoxShape.circle),
      child: Text(
        s.isEmpty ? '?' : s.characters.first.toUpperCase(),
        style: TextStyle(fontWeight: FontWeight.w800, color: c.brandInk, fontSize: size * .42),
      ),
    );
  }
}

// one customer in a list: name #no · phone · last visit · stamps (dots / bar / reward ready)
class ScMemberRow extends StatelessWidget {
  final ScCtx ctx;
  final Json m;
  final VoidCallback onTap;
  const ScMemberRow({super.key, required this.ctx, required this.m, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final goal = ctx.goal;
    final stamps = n(m['stamps']).toInt();
    final ready = (m['ready'] as List? ?? const []).isNotEmpty;
    final accent = scHex(str(ctx.program['color'])) ?? scThemeOf(str(ctx.program['theme'])).accent;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          children: [
            ScAvatar(str(m['name'])),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: str(m['name']),
                      style: TextStyle(fontWeight: FontWeight.w800, color: m['deleted'] == true ? c.muted : c.ink),
                      children: [
                        TextSpan(
                          text: '  #${m['no']}',
                          style: TextStyle(color: c.muted, fontWeight: FontWeight.w600, fontSize: 12.5),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    [if (str(m['phone']).isNotEmpty) prettyPhone(m['phone']), m['last_visit_at'] != null ? ctx.m('lastVisit', {'ago': scAgo(m['last_visit_at'], ctx)}) : ctx.m('neverVisit')].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$stamps/$goal', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                if (ready)
                  Chip2(ctx.m('readyNow'), tone: Tone.good)
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 64,
                      height: 6,
                      child: LinearProgressIndicator(value: (stamps / goal).clamp(0, 1).toDouble(), backgroundColor: c.line, color: accent),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
