import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart' show fmt;
import '../../core/i18n.dart';
import '../../core/providers.dart' show prefStr, prefSetStr;
import '../../core/theme.dart';
import '../../widgets/buy_sheet.dart';
import '../../widgets/ui.dart';
import '../mart/mart_kit.dart' show showSheet;
import 'nt_api.dart';
import 'nt_data.dart';

// Digital Note — shared pieces of the owner screens (the web's dashboard/client/note/NoteParts.jsx + text.js helpers).
//   GET /note → { data: { book, license, addons, storage_slots, prices, themes, link, business, counts, telegram, templates } }

class NtCtx {
  final String id;
  final NtApi a;
  final T t;
  final Json data;
  final Future<void> Function() reload;
  final void Function(String text) notify;
  // open the unlock / buy sheet of a product (item: theme key, group id, "slot-N"; qty: storage packs)
  final Future<bool> Function(String product, {String? item, int qty, Json? extra}) askBuy;
  const NtCtx({required this.id, required this.a, required this.t, required this.data, required this.reload, required this.notify, required this.askBuy});

  Api get api => a.api;
  String get lang => t.lang;
  bool get km => t.lang == 'km';
  Json get book => obj(data['book']);
  Json get license => obj(data['license']);
  Json get addons => obj(data['addons']);
  Json get prices => obj(data['prices']);
  Json get counts => obj(data['counts']);
  Json get business => obj(data['business']);
  Json get telegram => obj(data['telegram']);
  num price(String k) => n(prices[k]);
  bool get readOnly => license['read_only'] == true;
  bool get inGrace => license['in_grace'] == true;
  num get fileLimit => n(book['file_limit']) > 0 ? n(book['file_limit']) : 20 * 1048576;
  String get bizName => str(business['name']);
  String get logo => str(business['logo_url']);

  // bought in this session: true at once (the ctx a screen holds keeps the data it was opened with)
  bool owned(String product) => obj(addons[product])['active'] == true || ntBought.contains(product);
  bool get style => owned('note_style');
  bool get sign => owned('note_sign');
  bool get voice => owned('note_voice');
  bool get ack => owned('note_ack');
  bool get form => owned('note_form');
  bool get pdf => owned('note_pdf');
  bool get media => owned('note_media');
  bool get tg => owned('note_telegram');
  bool get link => obj(data['link'])['owned'] == true || owned('note_link');
  Set<String> get themesOwned => {for (final k in (obj(data['themes'])['owned'] as List? ?? const [])) '$k', for (final b in ntBought) if (b.startsWith('note_theme:')) b.substring(11)};
  Set<String> get groupIcons => {for (final k in (obj(addons['note_group_icon'])['items'] as List? ?? const [])) '$k', for (final b in ntBought) if (b.startsWith('note_group_icon:')) b.substring(16)};
  List<String> get builtInTemplates => [for (final k in (data['templates'] as List? ?? ntTemplates)) '$k'];

  String m(String key, [Map<String, Object?> vars = const {}]) => t('note.$key', vars);
  String x(String key, [Map<String, Object?> vars = const {}]) => t('ntx.$key', vars); // app-only words
  List<String> l(String key) => t.list('note.$key');

  String errText(Object e) {
    if (e is NtUploadError) {
      return switch (e.code) {
        'timeout' => m('padTimeout'),
        'network' => t('app.offline'),
        'storage_full' => m('storageFull'),
        'file_too_big' => m('tooBig', {'mb': fileLimit ~/ 1048576}),
        _ => e.message,
      };
    }
    if (e is TimeoutException) return m('padTimeout');
    if (e is ApiError) {
      if (e.network) return t('app.offline');
      if (ntCode(e) == 'too_large') return m('tooLarge');
      return e.message;
    }
    return '$e';
  }

  // an error: a locked add-on opens its unlock sheet, a full storage the packs, the ended year the renew
  void fail(Object e) {
    final code = ntCode(e);
    if (e is ApiError || e is NtUploadError) {
      final product = e is ApiError ? str(e.body['product']) : '';
      if (code == 'locked') {
        askBuy('digital_note');
      } else if (code == 'storage_full') {
        askBuy('note_storage', qty: 1);
      } else if (code.startsWith('need_') && product.isNotEmpty) {
        askBuy(product, item: e is ApiError && e.body['item'] != null ? str(e.body['item']) : null);
      }
    }
    notify(errText(e));
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

// products (and "note_theme:<key>", "note_group_icon:<gid>") bought while the app is open — see NtCtx.owned
final ntBought = <String>{};

// ---------------------------------------------------------------- fixed lists (same as the API / web)
const ntLevels = ['off', 'view', 'reply', 'edit', 'collect'];
const ntGroupLevels = ['off', 'view', 'reply', 'edit'];
const ntColours = ['default', 'yellow', 'green', 'blue', 'purple', 'pink', 'gray'];
const ntTemplates = ['blank', 'meeting', 'homework', 'checklist', 'room_rent', 'repair_job', 'trip', 'signup'];
const ntStyleColours = ['red', 'orange', 'amber', 'green', 'teal', 'blue', 'indigo', 'purple', 'pink', 'gray'];
const ntPapers = ['plain', 'lined', 'grid', 'dots', 'kraft', 'night'];

const ntLevelIcons = <String, IconData>{
  'off': LucideIcons.eyeOff,
  'view': LucideIcons.eye,
  'reply': LucideIcons.messageSquareText,
  'edit': LucideIcons.penLine,
  'collect': LucideIcons.clipboardList,
};
const ntTemplateIcons = <String, IconData>{
  'blank': LucideIcons.fileText,
  'meeting': LucideIcons.users,
  'homework': LucideIcons.graduationCap,
  'checklist': LucideIcons.squareCheck,
  'room_rent': LucideIcons.bedDouble,
  'repair_job': LucideIcons.wrench,
  'trip': LucideIcons.plane,
  'signup': LucideIcons.clipboardList,
};
const ntProductIcons = <String, IconData>{
  'digital_note': LucideIcons.stickyNote,
  'note_storage': LucideIcons.hardDrive,
  'note_group': LucideIcons.folders,
  'note_sign': LucideIcons.signature,
  'note_style': LucideIcons.type,
  'note_media': LucideIcons.images,
  'note_link': LucideIcons.link,
  'note_group_icon': LucideIcons.image,
  'note_theme': LucideIcons.palette,
  'note_telegram': LucideIcons.bellRing,
  'note_ack': LucideIcons.circleCheckBig,
  'note_form': LucideIcons.sheet,
  'note_voice': LucideIcons.mic,
  'note_pdf': LucideIcons.fileDown,
};

// the card colours (web .c-yellow …: paper + accent; dark mode has its own papers)
const _paperLight = {'yellow': 0xFFFFF8D6, 'green': 0xFFE7F6EA, 'blue': 0xFFE5F0FF, 'purple': 0xFFF1E9FF, 'pink': 0xFFFFE8F1, 'gray': 0xFFEEF0F3};
const _paperDark = {'yellow': 0xFF2C2612, 'green': 0xFF142A1B, 'blue': 0xFF14223B, 'purple': 0xFF241A3A, 'pink': 0xFF33172A, 'gray': 0xFF22252C};
const _accent = {'default': 0xFF9AA0AC, 'yellow': 0xFFCA8A04, 'green': 0xFF16A34A, 'blue': 0xFF2563EB, 'purple': 0xFF7C3AED, 'pink': 0xFFDB2777, 'gray': 0xFF4B5563};
Color ntPaper(BuildContext context, String colour) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final v = (dark ? _paperDark : _paperLight)[colour];
  return v == null ? context.c.card : Color(v);
}

Color ntAccent(String colour) => Color(_accent[colour] ?? _accent['default']!);

// style pack colours (web style.js SWATCH)
const ntSwatch = <String, int>{
  'red': 0xFFE5484D,
  'orange': 0xFFF76B15,
  'amber': 0xFFF5A524,
  'green': 0xFF30A46C,
  'teal': 0xFF12A594,
  'blue': 0xFF2F6FEB,
  'indigo': 0xFF5B5BD6,
  'purple': 0xFF8E4EC6,
  'pink': 0xFFD6409F,
  'gray': 0xFF7C818D,
};

// ---------------------------------------------------------------- small helpers
String ntBytes(Object? v) {
  final b = n(v).toDouble();
  String one(double x) => x.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  if (b >= 1073741824) return '${b >= 10737418240 ? (b / 1073741824).round() : one(b / 1073741824)} GB';
  if (b >= 1048576) return '${one(b / 1048576)} MB';
  if (b >= 1024) return '${(b / 1024).round()} KB';
  return '${b.round()} B';
}

const _monEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monKm = ['មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា', 'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ'];
DateTime? ntLocal(Object? d) => DateTime.tryParse('${d ?? ''}')?.toUtc().add(const Duration(hours: 7));
String _two(int v) => v.toString().padLeft(2, '0');
String ntDate(Object? d, String lang) {
  final x = ntLocal(d);
  return x == null ? '' : '${x.day} ${(lang == 'km' ? _monKm : _monEn)[x.month - 1]} ${x.year}';
}

String ntTime(Object? d, String lang) {
  final x = ntLocal(d);
  return x == null ? '' : '${x.day} ${(lang == 'km' ? _monKm : _monEn)[x.month - 1]}, ${_two(x.hour)}:${_two(x.minute)}';
}

// "just now" / "5 min ago" / "3 h ago" / "2 d ago", then the date
// open a link outside the app (the public note page, Telegram…); a phone that can't opens nothing, and says so
Future<void> ntLaunch(NtCtx ctx, String url) async {
  try {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok) ctx.notify(ctx.x('openFail'));
  } catch (_) {
    ctx.notify(ctx.x('openFail'));
  }
}

// the clock for "5 min ago" texts (tests set a fixed one so screenshots stay the same)
DateTime Function() ntNow = DateTime.now;

String ntAgo(Object? d, NtCtx ctx) {
  final x = DateTime.tryParse('${d ?? ''}');
  if (x == null) return '';
  final s = ntNow().difference(x).inSeconds;
  if (s < 60) return ctx.m('justNow');
  if (s < 3600) return ctx.m('minAgo', {'n': s ~/ 60});
  if (s < 86400) return ctx.m('hourAgo', {'n': s ~/ 3600});
  if (s < 7 * 86400) return ctx.m('dayAgo', {'n': s ~/ 86400});
  return ntDate(d, ctx.lang);
}

// the link people open (share.path = /n/<slug or token>, a group /n/g/…)
String ntUrl(Object? path) => '${Config.siteUrl.replaceFirst(RegExp(r'/+$'), '')}${str(path).startsWith('/') ? '' : '/'}${str(path)}';

// a random id (a group create attempt key, a new block id)
final _rnd = math.Random();
String ntRandom([int len = 16]) {
  const ch = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  return List.generate(len, (_) => ch[_rnd.nextInt(ch.length)]).join();
}

// list / grid, remembered on this phone per screen
String ntView(String screen) => prefStr('note_view_$screen') == 'grid' ? 'grid' : 'list';
void ntSetView(String screen, String v) => prefSetStr('note_view_$screen', v);

// ---------------------------------------------------------------- widgets
class NtLevelBadge extends StatelessWidget {
  final NtCtx ctx;
  final String level;
  final bool pin;
  const NtLevelBadge({super.key, required this.ctx, required this.level, this.pin = false});
  @override
  Widget build(BuildContext context) {
    final off = level == 'off' || level.isEmpty;
    final c = context.c;
    final fg = off ? c.muted : c.brandInk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: off ? c.chip : c.active, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ntLevelIcons[off ? 'off' : level], size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            ctx.m('levelShort.${off ? 'off' : level}'),
            style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.3),
          ),
          if (pin) ...[const SizedBox(width: 3), Icon(LucideIcons.lock, size: 11, color: fg)],
        ],
      ),
    );
  }
}

// List | Grid (the web's ViewSwitch)
class NtViewSwitch extends StatelessWidget {
  final NtCtx ctx;
  final String value;
  final ValueChanged<String> onChanged;
  const NtViewSwitch({super.key, required this.ctx, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget one(String v, IconData icon, String tip) {
      final on = value == v;
      return Tooltip(
        message: tip,
        child: Material(
          color: on ? c.card : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onChanged(v),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(icon, size: 17, color: on ? c.brand : c.muted),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(13)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [one('list', LucideIcons.list, ctx.m('viewList')), one('grid', LucideIcons.layoutGrid, ctx.m('viewGrid'))]),
    );
  }
}

// a horizontal row of choice chips (filters)
class NtChips<V> extends StatelessWidget {
  final List<(V, String, int?)> items; // value, label, count
  final V value;
  final ValueChanged<V> onChanged;
  final EdgeInsets padding;
  const NtChips({super.key, required this.items, required this.value, required this.onChanged, this.padding = EdgeInsets.zero});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final (v, label, count) in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: v == value ? c.solid : c.card,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => onChanged(v),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: v == value ? c.solid : c.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: v == value ? c.onSolid : c.ink),
                        ),
                        if (count != null && count > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            fmt(count),
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: v == value ? c.onSolid.withValues(alpha: .75) : c.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// "Delete …?" — the answer once (a second tap can't open a second dialog)
bool _asking = false;
Future<bool> ntConfirm(BuildContext context, NtCtx ctx, String title, String sub, {String? yes, bool danger = true}) async {
  if (_asking) return false;
  _asking = true;
  try {
    return await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            content: Text(sub, style: TextStyle(color: d.c.muted, height: 1.5)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d, false), child: Text(ctx.m('cancel'))),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: danger ? d.c.danger : d.c.brand),
                onPressed: () => Navigator.pop(d, true),
                child: Text(yes ?? ctx.m('delete')),
              ),
            ],
          ),
        ) ==
        true;
  } finally {
    _asking = false;
  }
}

// a grey placeholder screen ("comes next")
class NtEmpty extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final Widget? action;
  const NtEmpty({super.key, required this.icon, required this.title, this.sub = '', this.action});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(22)),
            child: Icon(icon, size: 30, color: c.brand),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          if (sub.isNotEmpty) ...[const SizedBox(height: 6), Muted(sub, align: TextAlign.center)],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

// the gold tile on top of a buy sheet (icon + name + business)
class NtStage extends StatelessWidget {
  final IconData icon;
  final String name, sub;
  final Widget? art;
  const NtStage({super.key, required this.icon, required this.name, this.sub = '', this.art});
  @override
  Widget build(BuildContext context) => Container(
    width: 170,
    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFD86B), Color(0xFFE0A21A)]),
    ),
    child: Column(
      children: [
        art ?? Icon(icon, size: 52, color: const Color(0xFF5B3A00)),
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF3A2500)),
        ),
        if (sub.isNotEmpty)
          Text(
            sub,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: const Color(0xFF3A2500).withValues(alpha: .7)),
          ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- unlock / buy (the web's NoteDashboard "buying" sheets)
class NtSell {
  final IconData icon;
  final String name, title, sub;
  final List<String> perks;
  final num price;
  final Future<Json> Function() buy;
  final Widget? art;
  const NtSell({required this.icon, required this.name, required this.title, required this.sub, required this.perks, required this.price, required this.buy, this.art});
}

const _v4Words = {'note_telegram': 'tg', 'note_ack': 'ack', 'note_form': 'fx', 'note_voice': 'voice', 'note_pdf': 'pdf'};
const _gb5 = 5 * 1073741824;

// what a product sells (null = nothing to buy)
NtSell? ntSellOf(NtCtx ctx, String product, {String? item, int qty = 1, Json? extra}) {
  final p = ctx.price(product);
  final a = ctx.a;
  String forever() => ctx.m('oneTimeForever');
  String perYear(num price) => '${fmt(price)} ${ctx.m('coins')} ${ctx.m('perYear')}';
  switch (product) {
    case 'digital_note':
      return NtSell(
        icon: ntProductIcons[product]!,
        name: ctx.m('plan'),
        title: ctx.m('unlockTitle', {'name': ctx.m('plan')}),
        sub: ctx.m('notesSub'),
        perks: [...ctx.l('planPerks'), perYear(p)],
        price: p,
        buy: () => a.buy('digital_note', expect: ctx.license['expires_at']),
      );
    case 'note_storage':
      if (item != null) {
        final slot = objs(ctx.data['storage_slots']).firstWhere((s) => str(s['item']) == item, orElse: () => <String, dynamic>{});
        final no = item.split('-').last;
        return NtSell(
          icon: ntProductIcons[product]!,
          name: ctx.m('packLine', {'n': no}),
          title: ctx.m('packRenewTitle', {'n': no}),
          sub: ctx.m('moreStorageSub'),
          perks: ctx.l('storagePerks'),
          price: p,
          buy: () => a.renewStorage(item, slot['expires_at']),
        );
      }
      final q = qty.clamp(1, 20);
      final key = ntRandom(24); // one per sheet: a retry (or a second tap after a timeout) never pays twice
      final limit = n(ctx.book['storage_limit']) > 0 ? n(ctx.book['storage_limit']) : _gb5;
      return NtSell(
        icon: ntProductIcons[product]!,
        name: '+${q * 5} GB',
        title: ctx.m('packsBuyTitle', {'gb': q * 5}),
        sub: ctx.m('packsBuySub', {'n': q, 'total': ntBytes(limit + q * _gb5)}),
        perks: ctx.l('packsBuyPerks'),
        price: q * p,
        buy: () => a.buyStorage(q, key: key),
      );
    case 'note_sign':
      return NtSell(icon: ntProductIcons[product]!, name: ctx.m('signCard'), title: ctx.m('signTitle'), sub: ctx.m('signSub'), perks: [...ctx.l('signPerks')], price: p, buy: () => a.buy(product));
    case 'note_style':
      return NtSell(icon: ntProductIcons[product]!, name: ctx.m('styleCard'), title: ctx.m('styleTitle'), sub: ctx.m('styleSub'), perks: ctx.l('stylePerks'), price: p, buy: () => a.buy(product));
    case 'note_media':
      return NtSell(icon: ntProductIcons[product]!, name: ctx.m('mediaCard'), title: ctx.m('mediaTitle'), sub: ctx.m('mediaSub'), perks: ctx.l('mediaPerks'), price: p, buy: () => a.buy(product));
    case 'note_link':
      return NtSell(icon: ntProductIcons[product]!, name: ctx.m('linkCard'), title: ctx.m('linkTitle'), sub: ctx.m('linkSub'), perks: ctx.l('linkPerks'), price: p, buy: a.linkUnlock);
    case 'note_theme':
      if (item == null) return null;
      final th = ntThemes.firstWhere((x) => x.key == item, orElse: () => NtTheme(item, item, item, '', const []));
      return NtSell(
        icon: ntProductIcons[product]!,
        name: th.name(ctx.km),
        title: ctx.m('themeUnlockTitle', {'name': th.name(ctx.km)}),
        sub: ctx.m('themeUnlockSub'),
        perks: ctx.l('themePerks'),
        price: p,
        buy: () => a.themeUnlock(item),
      );
    case 'note_group_icon':
      if (item == null) return null;
      final name = str(extra?['name']);
      return NtSell(
        icon: ntProductIcons[product]!,
        name: ctx.m('groupIconCard'),
        title: ctx.m('groupIconTitle', {'name': name}),
        sub: ctx.m('groupIconSub'),
        perks: ctx.l('groupIconPerks'),
        price: p,
        buy: () => a.groupIconUnlock(item),
      );
  }
  final k = _v4Words[product];
  if (k == null) return null;
  final yearly = product == 'note_telegram';
  return NtSell(
    icon: ntProductIcons[product]!,
    name: ctx.m('${k}Card'),
    title: ctx.m('${k}BuyTitle'),
    sub: ctx.m('${k}BuySub'),
    perks: [...ctx.l('${k}Perks'), yearly ? perYear(p) : forever()],
    price: p,
    buy: () => a.buy(product, expect: yearly ? obj(ctx.addons[product])['expires_at'] : null),
  );
}

// the buy sheet; true = bought
Future<bool> ntUnlock(BuildContext context, NtCtx ctx, String product, {String? item, int qty = 1, Json? extra, Future<void> Function()? after}) async {
  final s = ntSellOf(ctx, product, item: item, qty: qty, extra: extra);
  if (s == null) return false;
  var bought = false;
  Future<Json>? paying; // the purchase in flight (the sheet can be swiped away while it runs)
  await showSheet<bool>(
    context,
    (_) => BuySheet(
      stage: NtStage(icon: s.icon, name: s.name, sub: ctx.bizName, art: s.art),
      badge: ctx.m('badge'),
      title: s.title,
      sub: s.sub,
      perks: s.perks,
      price: s.price,
      buyLabel: ctx.m('buy', {'coins': fmt(s.price)}),
      doneTitle: s.name,
      doneSub: ctx.m('unlockDone', {'name': s.name}),
      doneButton: ctx.t('app.continue'),
      buy: () => paying = s.buy(),
      onDone: (_) {
        bought = true;
        ntBought.add(item != null && (product == 'note_theme' || product == 'note_group_icon') ? '$product:$item' : product);
      },
    ),
  );
  // closed while paying: wait for the answer first, so the reload shows what was bought
  if (paying != null && !bought) {
    try {
      await paying;
      bought = true; // (the sheet's own "done" may come a moment later: mark it here too)
      ntBought.add(item != null && (product == 'note_theme' || product == 'note_group_icon') ? '$product:$item' : product);
    } catch (_) {}
  }
  // a partly bought set of packs (402 with data.bought) is shown after a reload too
  await ctx.reload();
  if (after != null) await after();
  return bought;
}

// a locked feature line with a gold unlock button
class NtLockLine extends StatelessWidget {
  final NtCtx ctx;
  final String text, product;
  final String? item;
  final VoidCallback? onTap;
  const NtLockLine({super.key, required this.ctx, required this.text, required this.product, this.item, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFFFC53D).withValues(alpha: .14),
        border: Border.all(color: const Color(0xFFFFC53D).withValues(alpha: .5)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.lock, size: 16, color: c.ink),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4, fontSize: 13.5))),
          const SizedBox(width: 8),
          _Gold(ctx.m('v4Unlock', {'coins': fmt(ctx.price(product))}), onTap: onTap ?? () => ctx.askBuy(product, item: item)),
        ],
      ),
    );
  }
}

class _Gold extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _Gold(this.label, {this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    borderRadius: BorderRadius.circular(999),
    clipBehavior: Clip.antiAlias,
    child: Ink(
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFFD86B), Color(0xFFE0A21A)])),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CoinIcon(size: 14),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF3A2500), fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// a gold "Unlock · N coins" button for wider places
class NtGoldBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const NtGoldBtn(this.label, {super.key, this.onTap});
  @override
  Widget build(BuildContext context) => Opacity(opacity: onTap == null ? .5 : 1, child: _Gold(label, onTap: onTap));
}
