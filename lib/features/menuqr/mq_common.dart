import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart' show fmt;
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/pay.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show GoldBtn;
import '../mart/mart_kit.dart' show MSheet, showSheet;
import '../owner/data.dart' show coinsChanged;

// Menu QR — shared pieces (parts.jsx + MqMedia.jsx + the dashboard ctx).
//   GET /menuqr → { data: { business, settings, license, addons, limits, counts, media, themes, qr, renew_price } }

class MqCtx {
  final String id;
  final Api api;
  final T t;
  final Json data;
  final Future<void> Function() reload;
  final void Function(Json buy) askBuy; // {addon} · {theme, tier} · {qr} · {renew: true}
  final void Function(String tab) go;
  final void Function(String text) notify;
  final void Function(Json Function(Json d) patch) put;
  const MqCtx({required this.id, required this.api, required this.t, required this.data, required this.reload, required this.askBuy, required this.go, required this.notify, required this.put});

  String get base => '${Api.user}/businesses/$id/menuqr';
  String get lang => t.lang;
  Json get business => obj(data['business']);
  Json get settings => obj(data['settings']);
  Json get license => obj(data['license']);
  Json get limits => obj(data['limits']);
  Json get counts => obj(data['counts']);
  Json get media => obj(data['media']);
  String get logo => str(obj(settings['logo'])['url']);
  String get currency => str(settings['currency']).isEmpty ? 'USD' : str(settings['currency']);
  Json addon(String k) => obj(obj(data['addons'])[k]);
  bool on(String k) => addon(k)['active'] == true;
  bool get readOnly => business['status'] == false || license['locked'] == true;
  String m(String key, [Map<String, Object?> vars = const {}]) => t('mq.$key', vars);

  void setSettings(Json s) => put((_) => {'settings': s});

  void fail(Object e) {
    if (e is ApiError && e.status == 402 && str(e.body['product']).startsWith('mq_')) return askBuy({'addon': str(e.body['product'])});
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

String menuUrl(Object? slug) => '${Config.siteUrl}/q/$slug';

// $1.50 · 6,000៛ (same as qmenu/MenuView money())
String money(Object? v, String cur) {
  final x = n(v);
  if (cur == 'KHR') return '${fmt(x.round())}៛';
  final s = x.toStringAsFixed(2).split('.');
  return '\$${fmt(int.parse(s[0]))}.${s[1]}';
}

String mqName(Json o, String lang) {
  final km = str(o['name_km']), en = str(o['name_en']);
  final v = lang == 'en' ? (en.isNotEmpty ? en : km) : (km.isNotEmpty ? km : en);
  return v.isEmpty ? '—' : v;
}

List<String> catsOf(Json i) {
  final l = (i['category_ids'] as List? ?? const []).map((e) => '$e').toList();
  return l.isNotEmpty ? l : [str(i['category_id'])];
}

const mqTags = ['new', 'hot', 'spicy', 'veg', 'best', 'chef'];
const mqTagIcon = {'new': '✨', 'hot': '🔥', 'spicy': '🌶️', 'veg': '🥬', 'best': '⭐', 'chef': '👨‍🍳'};

const mqAddonIcons = <String, IconData>{
  'mq_categories': LucideIcons.utensilsCrossed,
  'mq_items': LucideIcons.utensilsCrossed,
  'mq_promos': LucideIcons.tag,
  'mq_feedback': LucideIcons.messageSquareHeart,
  'mq_stats': LucideIcons.chartColumn,
};

Widget mqPanel(List<Widget> children, {EdgeInsets padding = const EdgeInsets.all(16)}) => Panel(
  padding: padding,
  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
);

Widget mqHead(BuildContext context, IconData icon, String title, String sub, {List<Widget> actions = const []}) => mqPanel([
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

String unlockLabel(MqCtx ctx, String addon) {
  final a = ctx.addon(addon);
  return ctx.m('unlock', {'coins': '${fmt(n(a['price']))} ${ctx.m('coins')}${a['days'] != null ? ' ${ctx.m('perYear')}' : ''}'});
}

// "this needs an add-on" card
class MqLocked extends StatelessWidget {
  final MqCtx ctx;
  final String addon;
  const MqLocked({super.key, required this.ctx, required this.addon});
  @override
  Widget build(BuildContext context) => mqPanel([
    Center(child: Icon(LucideIcons.lock, size: 28, color: context.c.brand)),
    const SizedBox(height: 8),
    Text(
      ctx.m('addonNames.$addon'),
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
    ),
    const SizedBox(height: 4),
    Muted(ctx.t.or('mq.addonWhat.$addon', ''), align: TextAlign.center),
    const SizedBox(height: 12),
    Center(child: GoldBtn(unlockLabel(ctx, addon), onTap: ctx.readOnly ? null : () => ctx.askBuy({'addon': addon}))),
  ]);
}

Future<bool> mqConfirm(BuildContext context, MqCtx ctx, String title, {String? sub, String? yes, bool danger = true}) async =>
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
            child: Text(yes ?? ctx.m('delete')),
          ),
        ],
      ),
    ) ==
    true;

// a small text input with a label (md-field)
class MqInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final int? max;
  final int lines;
  final bool enabled, number;
  final ValueChanged<String>? onChanged;
  const MqInput(this.label, this.controller, {super.key, this.hint, this.max, this.lines = 1, this.enabled = true, this.number = false, this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Field(
      label: label,
      controller: controller,
      hint: hint,
      maxLength: max,
      maxLines: lines,
      enabled: enabled,
      onChanged: onChanged,
      keyboard: number ? const TextInputType.numberWithOptions(decimal: true) : (lines > 1 ? TextInputType.multiline : null),
    ),
  );
}

// ============================== media library ==============================
// GET /media → { data: [{ _id, url, name, used: [{kind, name}] }], count, capacity, free, slots, slot_price }
class MediaRes {
  final List<Json> rows;
  final Json room;
  const MediaRes(this.rows, this.room);
  int get count => n(room['count']).toInt();
  int get capacity => n(room['capacity']).toInt();
  bool get full => count >= capacity;
}

Future<MediaRes?> loadMedia(MqCtx ctx) async {
  final r = await ctx.run(() => ctx.api.get('${ctx.base}/media'));
  if (r == null) return null;
  return MediaRes(objs(r['data']), r);
}

// pick pictures (≤4 MB each) and upload 10 at a time → the new rows. onFull: no room left
Future<List<Json>> uploadMedia(BuildContext context, MqCtx ctx, {required VoidCallback onFull, bool single = false}) async {
  final picker = ImagePicker();
  final List<XFile> files;
  if (single) {
    final f = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1800, maxHeight: 1800, imageQuality: 85);
    files = f == null ? const [] : [f];
  } else {
    files = await picker.pickMultiImage(maxWidth: 1800, maxHeight: 1800, imageQuality: 85);
  }
  if (files.isEmpty) return const [];
  final list = <(Uint8List, String)>[];
  for (final f in files) {
    final b = await f.readAsBytes();
    if (b.length <= 4 * 1024 * 1024) list.add((b, f.name.isEmpty ? 'photo.jpg' : f.name));
  }
  final added = <Json>[];
  try {
    for (var i = 0; i < list.length; i += 10) {
      final form = FormData();
      for (final (b, name) in list.skip(i).take(10)) {
        form.files.add(MapEntry('photos', MultipartFile.fromBytes(b, filename: name)));
      }
      final r = await ctx.api.post('${ctx.base}/media', form);
      added.addAll(objs(r['data']));
      if (n(r['skipped']) > 0) {
        ctx.notify(ctx.m('skipped', {'n': list.length - added.length}));
        onFull();
        break;
      }
    }
  } on ApiError catch (e) {
    if (e.code == 'media_full' || e.body['code'] == 'media_full') {
      ctx.notify(ctx.m('full'));
      onFull();
    } else {
      ctx.notify(e.network ? ctx.t('app.offline') : e.message);
    }
  }
  ctx.reload();
  return added;
}

// "12 / 30 pictures" + bar + Add places
class MediaRoom extends StatelessWidget {
  final MqCtx ctx;
  final MediaRes res;
  final VoidCallback onBuy;
  const MediaRoom({super.key, required this.ctx, required this.res, required this.onBuy});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pct = (res.count / (res.capacity < 1 ? 1 : res.capacity)).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ctx.m('room', {'n': fmt(res.count), 'max': fmt(res.capacity)}),
                    style: TextStyle(fontWeight: FontWeight.w800, color: res.full ? c.danger : c.ink),
                  ),
                  Text(ctx.m('roomHint', {'free': res.room['free'], 'slots': fmt(n(res.room['slots']))}), style: TextStyle(color: c.muted, fontSize: 12.5)),
                ],
              ),
            ),
            GoldBtn(ctx.m('addPlaces'), onTap: ctx.readOnly ? null : onBuy),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: c.bg2, color: res.full ? c.danger : c.brand),
        ),
      ],
    );
  }
}

// a picture tile from the library
class MediaTile extends StatelessWidget {
  final String url;
  final Widget? corner, badge;
  final bool selected;
  final VoidCallback? onTap;
  const MediaTile({super.key, required this.url, this.corner, this.badge, this.selected = false, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? c.brand : c.line, width: selected ? 3 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(image: netImage(
              url),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(LucideIcons.imageOff, color: c.muted),
            ),
            if (badge != null) Positioned(left: 4, bottom: 4, right: 4, child: badge!),
            if (corner != null) Positioned(right: 4, top: 4, child: corner!),
          ],
        ),
      ),
    );
  }
}

Widget mediaBadge(BuildContext context, String text, bool on) => Align(
  alignment: Alignment.bottomLeft,
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: on ? context.c.brand : Colors.black54, borderRadius: BorderRadius.circular(99)),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
    ),
  ),
);

Future<void> openBuySlots(BuildContext context, MqCtx ctx, num price) => showSheet<void>(context, (_) => BuySlotsSheet(ctx: ctx, price: price));

// buy more picture places
class BuySlotsSheet extends ConsumerStatefulWidget {
  final MqCtx ctx;
  final num price;
  const BuySlotsSheet({super.key, required this.ctx, required this.price});
  @override
  ConsumerState<BuySlotsSheet> createState() => _BuySlotsSheetState();
}

class _BuySlotsSheetState extends ConsumerState<BuySlotsSheet> {
  MqCtx get ctx => widget.ctx;
  int _n = 5;
  bool _busy = false;
  String _err = '';

  @override
  Widget build(BuildContext context) {
    final total = _n * widget.price;
    final balance = ref.watch(sessionProvider)?.coins ?? 0;
    return MSheet(
      title: ctx.m('buyTitle'),
      footer: [
        const Spacer(),
        Btn(ctx.m('cancel'), kind: BtnKind.ghost, small: true, onTap: _busy ? null : () => Navigator.pop(context)),
        const SizedBox(width: 8),
        GoldBtn(
          ctx.m('buyFor', {'n': _n, 'coins': fmt(total)}),
          onTap: _busy || _n < 1 || total > balance
              ? null
              : () async {
                  if (!await confirmPay(context, ref, coins: total, what: ctx.m('buyTitle'))) return;
                  setState(() {
                    _busy = true;
                    _err = '';
                  });
                  try {
                    final r = await ctx.api.post('${ctx.base}/media/slots', {'n': _n});
                    if (r['balance'] is num) await ref.read(sessionProvider.notifier).patch({'coin_balance': r['balance']});
                    coinsChanged(ref);
                    ctx.notify(ctx.m('bought', {'n': _n}));
                    ctx.reload();
                    if (context.mounted) Navigator.pop(context, true);
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
        Muted(ctx.m('buySub', {'coins': fmt(widget.price)})),
        const SizedBox(height: 14),
        Text(ctx.m('howMany'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(
          children: [
            IconButton.filledTonal(onPressed: _n > 1 ? () => setState(() => _n = (_n - 5).clamp(1, 500)) : null, icon: const Icon(LucideIcons.minus)),
            SizedBox(
              width: 70,
              child: Text(
                '$_n',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
              ),
            ),
            IconButton.filledTonal(onPressed: _n < 500 ? () => setState(() => _n = (_n + 5).clamp(1, 500)) : null, icon: const Icon(LucideIcons.plus)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (final k in [5, 10, 20, 50, 100]) ChoiceChip(label: Text('+$k'), selected: _n == k, onSelected: (_) => setState(() => _n = k)),
          ],
        ),
        if (total > balance) ...[const SizedBox(height: 10), Alert(ctx.m('notEnough'))],
        if (_err.isNotEmpty) ...[const SizedBox(height: 10), Alert(_err)],
      ],
    );
  }
}

// choose pictures from the library (or upload new ones) → onPick(rows); returns true when used
Future<bool> pickMedia(BuildContext context, MqCtx ctx, {int max = 1, String? title, required Future<bool> Function(List<Json> rows) onPick}) async =>
    await showSheet<bool>(context, (_) => _MediaPicker(ctx: ctx, max: max, title: title ?? ctx.m('pickTitle'), onPick: onPick)) == true;

class _MediaPicker extends StatefulWidget {
  final MqCtx ctx;
  final int max;
  final String title;
  final Future<bool> Function(List<Json> rows) onPick;
  const _MediaPicker({required this.ctx, required this.max, required this.title, required this.onPick});
  @override
  State<_MediaPicker> createState() => _MediaPickerState();
}

class _MediaPickerState extends State<_MediaPicker> {
  MqCtx get ctx => widget.ctx;
  MediaRes? _res;
  final _sel = <Json>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await loadMedia(ctx);
    if (mounted && r != null) setState(() => _res = r);
  }

  void _toggle(Json x) => setState(() {
    final i = _sel.indexWhere((y) => y['_id'] == x['_id']);
    if (i >= 0) {
      _sel.removeAt(i);
    } else if (widget.max == 1) {
      _sel
        ..clear()
        ..add(x);
    } else if (_sel.length < widget.max) {
      _sel.add(x);
    }
  });

  Future<void> _buy() async {
    await openBuySlots(context, ctx, n(_res?.room['slot_price']));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final res = _res;
    final c = context.c;
    return MSheet(
      title: widget.title,
      footer: [
        Expanded(
          child: Text(ctx.m('pickHint'), style: TextStyle(color: c.muted, fontSize: 12)),
        ),
        Btn(ctx.m('cancel'), kind: BtnKind.ghost, small: true, onTap: _busy ? null : () => Navigator.pop(context, false)),
        const SizedBox(width: 8),
        Btn(
          ctx.m('useN', {'n': _sel.isEmpty ? '' : _sel.length}),
          icon: LucideIcons.check,
          small: true,
          busy: _busy,
          onTap: _sel.isEmpty
              ? null
              : () async {
                  setState(() => _busy = true);
                  final ok = await widget.onPick(List.of(_sel));
                  if (!mounted) return;
                  setState(() => _busy = false);
                  if (ok && context.mounted) Navigator.pop(context, true);
                },
        ),
      ],
      children: [
        if (res == null)
          const SkelList(rows: 3)
        else ...[
          MediaRoom(ctx: ctx, res: res, onBuy: _buy),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Btn(
              ctx.m('upload'),
              icon: LucideIcons.upload,
              small: true,
              busy: _busy,
              onTap: ctx.readOnly || _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final added = await uploadMedia(context, ctx, onFull: _buy, single: widget.max == 1);
                      await _load();
                      if (!mounted) return;
                      setState(() {
                        _busy = false;
                        // just uploaded = chosen
                        if (added.isNotEmpty) {
                          if (widget.max == 1) {
                            _sel
                              ..clear()
                              ..add(added.first);
                          } else {
                            _sel.addAll(added.take(widget.max - _sel.length));
                          }
                        }
                      });
                    },
            ),
          ),
          const SizedBox(height: 12),
          if (res.rows.isEmpty)
            Muted(ctx.m('emptyMedia'))
          else
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final x in res.rows)
                  Builder(
                    builder: (context) {
                      final k = _sel.indexWhere((y) => y['_id'] == x['_id']);
                      final used = (x['used'] as List? ?? const []).length;
                      return MediaTile(
                        url: str(x['url']),
                        selected: k >= 0,
                        onTap: () => _toggle(x),
                        badge: used > 0 ? mediaBadge(context, ctx.m('usedCount', {'n': used}), true) : null,
                        corner: k >= 0
                            ? CircleAvatar(
                                radius: 12,
                                backgroundColor: c.brand,
                                child: widget.max == 1
                                    ? const Icon(LucideIcons.check, size: 14, color: Colors.white)
                                    : Text(
                                        '${k + 1}',
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                                      ),
                              )
                            : null,
                      );
                    },
                  ),
              ],
            ),
        ],
      ],
    );
  }
}
