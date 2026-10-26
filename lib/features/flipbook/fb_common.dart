import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart' show fmt;
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/pay.dart';
import '../../widgets/ui.dart';
import '../common/qr_card.dart';
import '../mart/mart_common.dart' show GoldBtn;
import '../mart/mart_kit.dart' show MSheet, showSheet;
import '../owner/data.dart' show coinsChanged;
import 'fb_data.dart';

// Flip Book — shared pieces (FbParts.jsx + the dashboard ctx).
//   GET /flipbook → { data: { business, settings, addons, prices, limits, room, reader_themes, shelf_themes, passwords } }
//   GET /flipbook/books → { data: [books], room } · GET /flipbook/categories → { data: [categories] }

class FbCtx {
  final String id;
  final Api api;
  final T t;
  final Json data;
  final Future<void> Function() reload;
  final void Function(Json buy) askBuy; // {addon} · {shelf} · {reader} · {password: book}
  final void Function(String tab) go;
  final void Function(String text) notify;
  final void Function(Json Function(Json d) patch) put;
  const FbCtx({required this.id, required this.api, required this.t, required this.data, required this.reload, required this.askBuy, required this.go, required this.notify, required this.put});

  String get base => '${Api.user}/businesses/$id/flipbook';
  String get lang => t.lang;
  Json get business => obj(data['business']);
  Json get settings => obj(data['settings']);
  Json get prices => obj(data['prices']);
  Json get limits => obj(data['limits']);
  Json get room => obj(data['room']);
  List<Json> get books => objs(data['books']);
  List<Json> get categories => objs(data['categories']);
  String get logo => str(obj(settings['logo'])['url']);
  String get libName => str(settings['title']).isNotEmpty ? str(settings['title']) : str(business['name']);
  Json addon(String k) => obj(obj(data['addons'])[k]);
  bool on(String k) => addon(k)['active'] == true;
  bool get readOnly => business['status'] == false;
  String m(String key, [Map<String, Object?> vars = const {}]) => t('fb.$key', vars);

  void fail(Object e) {
    if (e is ApiError && e.status == 402 && e.body['product'] != null) return askBuy({'addon': str(e.body['product'])});
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

  void setBooks(List<Json> Function(List<Json> list) fn, [Object? room]) => put((d) => {'books': fn(objs(d['books'])), if (room is Map) 'room': room});
  void setBook(Json row) => setBooks((l) => [for (final x in l) x['_id'] == row['_id'] ? row : x]);
}

String shelfUrl(Object? slug) => '${Config.siteUrl}/f/$slug';
String catUrl(Object? slug) => '${Config.siteUrl}/fc/$slug';
String bookUrl(Object? slug) => '${Config.siteUrl}/b/$slug';
String mb(Object? bytes) => '${(n(bytes) / 1048576).toStringAsFixed(1)} MB';

const fbAddonIcons = <String, IconData>{
  'fb_categories': LucideIcons.folderOpen,
  'fb_stats': LucideIcons.chartColumn,
  'fb_qr_styles': LucideIcons.qrCode,
  'fb_leads': LucideIcons.users,
  'fb_links': LucideIcons.mousePointerClick,
};

// QR card styles: "classic" free, the other 11 unlock together with "fb_qr_styles". accent null = the library colour
class QrCardStyle {
  final String en, km, style;
  final Color color, bg;
  final Color? accent;
  const QrCardStyle(this.en, this.km, this.style, this.color, this.bg, [this.accent]);
  String name(String lang) => lang == 'km' ? km : en;
}

const qrCards = <String, QrCardStyle>{
  'classic': QrCardStyle('Classic', 'បុរាណ', 'classic', Color(0xFF111111), Color(0xFFFFFFFF)),
  'dots': QrCardStyle('Dots', 'ចំណុច', 'dots', Color(0xFF1F2937), Color(0xFFFFFFFF)),
  'rounded': QrCardStyle('Soft', 'ទន់', 'rounded', Color(0xFF0F172A), Color(0xFFF8FAFC)),
  'fluid': QrCardStyle('Fluid violet', 'រលូនស្វាយ', 'fluid', Color(0xFF3B0764), Color(0xFFFAF5FF), Color(0xFF7C3AED)),
  'bubble': QrCardStyle('Bubbles', 'ពពុះ', 'bubble', Color(0xFF0C4A6E), Color(0xFFF0F9FF), Color(0xFF0284C7)),
  'pixel': QrCardStyle('Pixel', 'ភីកសែល', 'pixel', Color(0xFF111111), Color(0xFFFFFBEB), Color(0xFFF59E0B)),
  'twotone': QrCardStyle('Two colours', 'ពីរពណ៌', 'twotone', Color(0xFF111827), Color(0xFFFFFFFF)),
  'sunset': QrCardStyle('Sunset', 'ថ្ងៃលិច', 'sunset', Color(0xFFC2410C), Color(0xFFFFF7ED), Color(0xFFEA580C)),
  'ocean': QrCardStyle('Ocean', 'សមុទ្រ', 'ocean', Color(0xFF1E3A8A), Color(0xFFEFF6FF), Color(0xFF0369A1)),
  'mint': QrCardStyle('Mint', 'មីន', 'mint', Color(0xFF065F46), Color(0xFFECFDF5), Color(0xFF059669)),
  'berry': QrCardStyle('Berry', 'បឺរី', 'berry', Color(0xFF831843), Color(0xFFFDF2F8), Color(0xFFBE185D)),
  'royal': QrCardStyle('Royal gold', 'មាសរាជ', 'royal', Color(0xFF713F12), Color(0xFFFFFBEB), Color(0xFFB45309)),
};

Color hexColor(Object? h, [int fallback = 0xFFE0581A]) {
  var s = str(h).replaceFirst('#', '');
  if (s.length == 3) s = s.split('').map((c) => '$c$c').join();
  return Color(s.length == 6 ? 0xFF000000 | (int.tryParse(s, radix: 16) ?? (fallback & 0xFFFFFF)) : fallback);
}

// the library colour: the owner's, or the shelf design's accent
Color libColour(FbCtx ctx) => str(ctx.settings['color']).isNotEmpty ? hexColor(ctx.settings['color']) : Color(fbShelves[str(ctx.settings['shelf_theme'])]?.accent ?? 0xFFE0581A);

CardArt qrThumbArt(FbCtx ctx, String k, String text) {
  final c = qrCards[k] ?? qrCards['classic']!;
  return qrCodeArt(text: text, style: c.style, color: c.color, bg: c.bg, accent: c.accent ?? libColour(ctx), px: 110);
}

Widget fbPanel(List<Widget> children, {EdgeInsets padding = const EdgeInsets.all(16)}) => Panel(
  padding: padding,
  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
);

Widget fbHead(BuildContext context, IconData icon, String title, String sub, {List<Widget> actions = const []}) => fbPanel([
  Row(
    children: [
      Icon(icon, size: 20, color: context.c.brand),
      const SizedBox(width: 8),
      Expanded(
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
    ],
  ),
  if (sub.isNotEmpty) ...[const SizedBox(height: 4), Muted(sub)],
  if (actions.isNotEmpty) ...[const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions)],
]);

// "this needs an add-on" card
class FbLocked extends StatelessWidget {
  final FbCtx ctx;
  final String addon;
  const FbLocked({super.key, required this.ctx, required this.addon});
  @override
  Widget build(BuildContext context) {
    final a = ctx.addon(addon);
    return fbPanel([
      Center(child: Icon(fbAddonIcons[addon] ?? LucideIcons.lock, size: 30, color: context.c.brand)),
      const SizedBox(height: 8),
      Text(
        ctx.m('addonNames.$addon'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      const SizedBox(height: 4),
      Muted(ctx.t.or('fb.addonWhat.$addon', ''), align: TextAlign.center),
      const SizedBox(height: 12),
      Center(
        child: GoldBtn(
          ctx.m('unlock', {'coins': '${fmt(n(a['price']))} ${ctx.m('coins')}${a['days'] != null ? ' ${ctx.m('perYear')}' : ''}'}),
          onTap: ctx.readOnly ? null : () => ctx.askBuy({'addon': addon}),
        ),
      ),
    ]);
  }
}

// "unlock first" line inside a box
class NeedAddon extends StatelessWidget {
  final FbCtx ctx;
  final String addon;
  final VoidCallback? onGo;
  const NeedAddon({super.key, required this.ctx, required this.addon, this.onGo});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a = ctx.addon(addon);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.warnBg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(LucideIcons.lock, size: 16, color: c.warn),
          const SizedBox(width: 8),
          Expanded(child: Text(ctx.t.or('fb.addonWhat.$addon', ''), style: const TextStyle(fontSize: 13))),
          const SizedBox(width: 8),
          GoldBtn(
            ctx.m('unlock', {'coins': '${fmt(n(a['price']))}${a['days'] != null ? ' ${ctx.m('perYear')}' : ''}'}),
            onTap: ctx.readOnly
                ? null
                : () {
                    onGo?.call();
                    ctx.askBuy({'addon': addon});
                  },
          ),
        ],
      ),
    );
  }
}

Future<bool> fbConfirm(BuildContext context, FbCtx ctx, String title, String sub, {String? yes}) async =>
    await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: Text(sub),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(ctx.m('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: d.c.danger),
            onPressed: () => Navigator.pop(d, true),
            child: Text(yes ?? ctx.m('delete')),
          ),
        ],
      ),
    ) ==
    true;

// a QR card for one link (library, category or book) + download + copy (+ embed code for books) + a new link
class QrCardSheet extends StatefulWidget {
  final FbCtx ctx;
  final String url, name, title;
  final String? header;
  final bool embed;
  final (String kind, String id)? relink;
  const QrCardSheet({super.key, required this.ctx, required this.url, required this.name, required this.title, this.header, this.embed = false, this.relink});
  @override
  State<QrCardSheet> createState() => _QrCardSheetState();
}

class _QrCardSheetState extends State<QrCardSheet> {
  FbCtx get ctx => widget.ctx;
  late String _url = widget.url;
  bool _busy = false;

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    ctx.notify(ctx.m('copied'));
  }

  @override
  Widget build(BuildContext context) {
    final c = qrCards[str(ctx.settings['qr_style'])] ?? qrCards['classic']!;
    final art = qrCardArt(
      text: _url,
      style: c.style,
      color: c.color,
      bg: c.bg,
      accent: c.accent ?? libColour(ctx),
      logo: ctx.logo.isNotEmpty,
      name: widget.name,
      header: widget.header ?? ctx.libName,
      footer: _url.replaceFirst(RegExp(r'^https?://'), ''),
    );
    final code = '<iframe src="$_url?embed=1" width="100%" height="600" style="border:0;max-width:100%" allow="fullscreen" allowfullscreen></iframe>';
    final file = (_url.split('/').last).replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '');
    return MSheet(
      title: widget.title,
      children: [
        Center(
          child: SizedBox(
            width: 280,
            child: FittedBox(
              child: CardArtView(art: art, logo: ctx.logo),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: InkWell(
            onTap: () => launchUrl(Uri.parse(_url), mode: LaunchMode.externalApplication),
            child: Text(
              _url.replaceFirst(RegExp(r'^https?://'), ''),
              style: TextStyle(color: context.c.brand, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Btn(ctx.m('copyLink'), icon: LucideIcons.copy, kind: BtnKind.ghost, small: true, onTap: () => _copy(_url)),
            Btn(
              ctx.m('open'),
              icon: LucideIcons.externalLink,
              kind: BtnKind.ghost,
              small: true,
              onTap: () => launchUrl(Uri.parse(_url), mode: LaunchMode.externalApplication),
            ),
            Btn(
              ctx.m('downloadQr'),
              icon: LucideIcons.download,
              small: true,
              busy: _busy,
              onTap: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        await shareCardArt(art, ctx.logo, '$file-qr.png');
                      } catch (e) {
                        ctx.notify('$e');
                      }
                      if (mounted) setState(() => _busy = false);
                    },
            ),
            if (widget.relink != null)
              Btn(
                ctx.m('newLink'),
                icon: LucideIcons.refreshCw,
                kind: BtnKind.ghost,
                small: true,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        if (!await fbConfirm(context, ctx, ctx.m('newLinkTitle'), ctx.m('newLinkSub'), yes: ctx.m('newLinkYes'))) return;
                        final (kind, rid) = widget.relink!;
                        final r = await ctx.run(() => ctx.api.post('${ctx.base}/new-link', {'kind': kind, 'id': rid}));
                        if (r == null) return;
                        final slug = str(obj(r['data'])['slug']);
                        if (kind == 'library') {
                          ctx.put(
                            (d) => {
                              'settings': {...obj(d['settings']), 'slug': slug},
                            },
                          );
                        }
                        if (kind == 'book') {
                          ctx.setBooks(
                            (l) => [
                              for (final b in l) b['_id'] == rid ? {...b, 'slug': slug} : b,
                            ],
                          );
                        }
                        if (kind == 'category') {
                          ctx.put(
                            (d) => {
                              'categories': [
                                for (final x in objs(d['categories'])) x['_id'] == rid ? {...x, 'slug': slug} : x,
                              ],
                            },
                          );
                        }
                        setState(() => _url = kind == 'book' ? bookUrl(slug) : (kind == 'category' ? catUrl(slug) : shelfUrl(slug)));
                        ctx.notify(ctx.m('newLinkDone'));
                      },
              ),
          ],
        ),
        if (widget.embed) ...[
          const SizedBox(height: 14),
          Text(ctx.m('embed'), style: const TextStyle(fontWeight: FontWeight.w800)),
          Muted(ctx.m('embedSub')),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: context.c.bg2, borderRadius: BorderRadius.circular(12)),
            child: SelectableText(code, style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5)),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Btn(ctx.m('copy'), icon: LucideIcons.copy, kind: BtnKind.ghost, small: true, onTap: () => _copy(code)),
          ),
        ],
      ],
    );
  }
}

// buy more book places (kind "book") or big book places (kind "big")
class BuySlotsSheet extends ConsumerStatefulWidget {
  final FbCtx ctx;
  final String kind;
  const BuySlotsSheet({super.key, required this.ctx, required this.kind});
  @override
  ConsumerState<BuySlotsSheet> createState() => _BuySlotsSheetState();
}

class _BuySlotsSheetState extends ConsumerState<BuySlotsSheet> {
  FbCtx get ctx => widget.ctx;
  late int _n = widget.kind == 'big' ? 1 : 5;
  bool _busy = false;
  String _err = '';

  @override
  Widget build(BuildContext context) {
    final big = widget.kind == 'big';
    final price = n(ctx.prices[big ? 'fb_big_slot' : 'fb_book_slot']);
    final total = _n * price;
    final balance = ref.watch(sessionProvider)?.coins ?? 0;
    final l = ctx.limits;
    final title = big ? ctx.m('buyTitleBig') : ctx.m('buyTitleBook');
    return MSheet(
      title: title,
      footer: [
        const Spacer(),
        Btn(ctx.m('cancel'), kind: BtnKind.ghost, small: true, onTap: _busy ? null : () => Navigator.pop(context)),
        const SizedBox(width: 8),
        GoldBtn(
          ctx.m('buyFor', {'n': _n, 'coins': fmt(total)}),
          onTap: _busy || _n < 1 || total > balance
              ? null
              : () async {
                  if (!await confirmPay(context, ref, coins: total, what: title)) return;
                  setState(() {
                    _busy = true;
                    _err = '';
                  });
                  try {
                    final r = await ctx.api.post('${ctx.base}/slots', {'kind': widget.kind, 'n': _n});
                    if (r['balance'] is num) await ref.read(sessionProvider.notifier).patch({'coin_balance': r['balance']});
                    coinsChanged(ref);
                    if (r['room'] is Map) ctx.put((_) => {'room': r['room']});
                    ctx.notify(ctx.m('bought', {'n': _n}));
                    if (context.mounted) Navigator.pop(context);
                  } on ApiError catch (e) {
                    setState(() {
                      _err = e.message;
                      _busy = false;
                    });
                  }
                },
        ),
      ],
      children: [
        Muted(big ? ctx.m('buySubBig', {'mb': n(l['big_bytes']) ~/ 1048576, 'pages': l['big_pages'], 'coins': fmt(price)}) : ctx.m('buySubBook', {'coins': fmt(price)})),
        const SizedBox(height: 14),
        Text(ctx.m('howMany'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(
          children: [
            IconButton.filledTonal(onPressed: _n > 1 ? () => setState(() => _n--) : null, icon: const Icon(LucideIcons.minus)),
            SizedBox(
              width: 70,
              child: Text(
                '$_n',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
              ),
            ),
            IconButton.filledTonal(onPressed: _n < 500 ? () => setState(() => _n++) : null, icon: const Icon(LucideIcons.plus)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (final k in big ? [1, 2, 5, 10] : [5, 10, 20, 50]) ChoiceChip(label: Text('+$k'), selected: _n == k, onSelected: (_) => setState(() => _n = k)),
          ],
        ),
        if (total > balance) ...[const SizedBox(height: 10), Alert(ctx.m('notEnough'))],
        if (_err.isNotEmpty) ...[const SizedBox(height: 10), Alert(_err)],
      ],
    );
  }
}

void openQr(BuildContext context, FbCtx ctx, {required String url, required String name, bool embed = false, (String, String)? relink}) =>
    showSheet<void>(context, (_) => QrCardSheet(ctx: ctx, url: url, name: name, title: name, embed: embed, relink: relink));
