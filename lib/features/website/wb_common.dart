import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../attendance/at_setup.dart' show TimeField;
import '../mart/mart_common.dart' show GoldBtn, fileForm;
import '../mart/mart_kit.dart' show DayField, MSheet, showSheet;
import '../restaurant/rest_common.dart' show Segmented, SwitchRow;
import 'wb_data.dart';

// Website Builder — shared pieces (WsFields.jsx + the dashboard ctx).
//   GET /website → { data: { business, site, pages, license, addons, themes {owned, price}, limits {pages, media}, counts, telegram, templates, renew_price, fonts, colors } }

class WbCtx {
  final String id;
  final Api api;
  final T t;
  final Json data;
  final Future<void> Function() reload;
  final void Function(Json buy) askBuy; // {addon} · {theme} · {renew}
  final void Function(String tab) go;
  final void Function(String text) notify;
  final void Function(Json Function(Json d) patch) put;
  const WbCtx({required this.id, required this.api, required this.t, required this.data, required this.reload, required this.askBuy, required this.go, required this.notify, required this.put});

  String get base => '${Api.user}/businesses/$id/website';
  String get lang => t.lang;
  Json get business => obj(data['business']);
  Json get site => obj(data['site']);
  Json get license => obj(data['license']);
  Json get limits => obj(data['limits']);
  List<Json> get pages => objs(data['pages']);
  Json addon(String k) => obj(obj(data['addons'])[k]);
  bool on(String k) => addon(k)['active'] == true;
  bool get readOnly => business['status'] == false || license['locked'] == true;
  String get siteUrl => '${Config.siteUrl}/site/${site['slug']}';
  String m(String key, [Map<String, Object?> vars = const {}]) => t('wb.$key', vars);
  String block(String type) => t.or('wbk.block.$type', type);
  String field(String k) => t.or('wbk.field.$k', k);
  String choice(String k) => t.or('wbk.choice.$k', k);

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
}

// text in the visitor's language (the other one when empty)
String tx(Object? v, String lang) {
  if (v == null) return '';
  if (v is String) return v;
  if (v is Map) {
    final km = str(v['km']), en = str(v['en']);
    return lang == 'km' ? (km.isNotEmpty ? km : en) : (en.isNotEmpty ? en : km);
  }
  return '';
}

// every field present (empty values where none given) — blocks.js fill
Json wbFill(Map<String, dynamic> fields, Map? data) {
  final out = <String, dynamic>{};
  for (final e in fields.entries) {
    final v = data?[e.key];
    final kind = e.value;
    if (kind is List) {
      out[e.key] = kind.contains(v) ? v : kind.first;
    } else if (kind is Map) {
      out[e.key] = [for (final row in (v is List ? v : const [])) wbFill((kind['list'] as Map).cast<String, dynamic>(), row is Map ? row : null)];
    } else if (kind == 't' || kind == 'tl') {
      out[e.key] = v is Map ? {'en': str(v['en']), 'km': str(v['km'])} : {'en': str(v), 'km': ''};
    } else if (kind == 'bool') {
      out[e.key] = v == true;
    } else {
      out[e.key] = v ?? '';
    }
  }
  return out;
}

final _rnd = Random();
String newBlockId() => List.generate(8, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[_rnd.nextInt(36)]).join();

Json newBlock(String type) => {'id': newBlockId(), 'type': type, 'hidden': false, 'data': wbFill(wbBlocks[type]!, deepCopy(wbNewData[type]) as Map?)};

Object? deepCopy(Object? v) {
  if (v is Map) return <String, dynamic>{for (final e in v.entries) '${e.key}': deepCopy(e.value)};
  if (v is List) return [for (final x in v) deepCopy(x)];
  return v;
}

const wbIcons = <String, IconData>{
  'star': LucideIcons.star,
  'heart': LucideIcons.heart,
  'zap': LucideIcons.zap,
  'coffee': LucideIcons.coffee,
  'cake': LucideIcons.cakeSlice,
  'utensils': LucideIcons.utensils,
  'pizza': LucideIcons.pizza,
  'wifi': LucideIcons.wifi,
  'truck': LucideIcons.truck,
  'shield': LucideIcons.shieldCheck,
  'card': LucideIcons.creditCard,
  'scissors': LucideIcons.scissors,
  'sparkles': LucideIcons.sparkles,
  'book': LucideIcons.bookOpen,
  'award': LucideIcons.award,
  'clock': LucideIcons.clock,
  'stethoscope': LucideIcons.stethoscope,
  'pill': LucideIcons.pill,
  'flask': LucideIcons.flaskConical,
  'calendar': LucideIcons.calendarDays,
  'droplet': LucideIcons.droplet,
  'music': LucideIcons.music,
  'gift': LucideIcons.gift,
  'pen': LucideIcons.penTool,
  'camera': LucideIcons.camera,
  'monitor': LucideIcons.monitor,
  'laptop': LucideIcons.laptop,
  'phone': LucideIcons.phone,
  'map': LucideIcons.mapPin,
  'users': LucideIcons.users,
  'leaf': LucideIcons.leaf,
  'flower': LucideIcons.flower2,
  'home': LucideIcons.house,
  'car': LucideIcons.car,
  'plane': LucideIcons.plane,
  'bag': LucideIcons.shoppingBag,
  'shirt': LucideIcons.shirt,
  'package': LucideIcons.package,
  'smile': LucideIcons.smile,
  'baby': LucideIcons.baby,
  'paw': LucideIcons.pawPrint,
  'dumbbell': LucideIcons.dumbbell,
  'school': LucideIcons.graduationCap,
  'briefcase': LucideIcons.briefcase,
  'building': LucideIcons.building2,
  'handshake': LucideIcons.handshake,
  'idea': LucideIcons.lightbulb,
  'megaphone': LucideIcons.megaphone,
  'palette': LucideIcons.palette,
  'rocket': LucideIcons.rocket,
  'target': LucideIcons.target,
  'thumbs': LucideIcons.thumbsUp,
  'trophy': LucideIcons.trophy,
  'wrench': LucideIcons.wrench,
  'globe': LucideIcons.globe,
};

const blockIcons = <String, IconData>{
  'hero': LucideIcons.panelTop,
  'text': LucideIcons.type,
  'split': LucideIcons.columns2,
  'image': LucideIcons.image,
  'gallery': LucideIcons.images,
  'video': LucideIcons.play,
  'services': LucideIcons.layoutGrid,
  'prices': LucideIcons.circleDollarSign,
  'team': LucideIcons.usersRound,
  'quotes': LucideIcons.messageSquareQuote,
  'faq': LucideIcons.circleQuestionMark,
  'hours': LucideIcons.clock,
  'map': LucideIcons.mapPinned,
  'contact': LucideIcons.mailOpen,
  'buttons': LucideIcons.mousePointerClick,
  'social': LucideIcons.share2,
  'countdown': LucideIcons.timer,
  'numbers': LucideIcons.hash,
  'logos': LucideIcons.building,
  'cta': LucideIcons.megaphone,
  'spacer': LucideIcons.separatorHorizontal,
  'posts': LucideIcons.newspaper,
};

const wbAddonIcons = <String, IconData>{
  'web_telegram': LucideIcons.send,
  'web_brand': LucideIcons.palette,
  'web_pages': LucideIcons.layers,
  'web_blog': LucideIcons.newspaper,
  'web_nobrand': LucideIcons.globe,
  'web_slug': LucideIcons.globe,
  'web_stats': LucideIcons.chartColumn,
};

Color hexColor(Object? h, [int fallback = 0xFF2563EB]) {
  var s = str(h).replaceFirst('#', '');
  if (s.length == 3) s = s.split('').map((c) => '$c$c').join();
  return Color(s.length == 6 ? 0xFF000000 | (int.tryParse(s, radix: 16) ?? (fallback & 0xFFFFFF)) : fallback);
}

Widget wbPanel(List<Widget> children, {EdgeInsets padding = const EdgeInsets.all(16)}) => Panel(
  padding: padding,
  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
);

Widget wbHead(BuildContext context, IconData icon, String title, String sub, {List<Widget> actions = const []}) => wbPanel([
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
  if (actions.isNotEmpty) ...[const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: actions)],
]);

// "this needs an add-on" card
class WbLocked extends StatelessWidget {
  final WbCtx ctx;
  final String addon;
  const WbLocked({super.key, required this.ctx, required this.addon});
  @override
  Widget build(BuildContext context) {
    final a = ctx.addon(addon);
    return wbPanel([
      Center(child: Icon(wbAddonIcons[addon] ?? LucideIcons.lock, size: 30, color: context.c.brand)),
      const SizedBox(height: 8),
      Text(
        ctx.m('addonNames.$addon'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      const SizedBox(height: 4),
      Muted(ctx.t.or('wb.addonWhat.$addon', ''), align: TextAlign.center),
      const SizedBox(height: 12),
      Center(child: GoldBtn(ctx.m('unlock', {'coins': n(a['price'])}), onTap: ctx.readOnly ? null : () => ctx.askBuy({'addon': addon}))),
    ]);
  }
}

// yes / no question
Future<bool> wbConfirm(BuildContext context, WbCtx ctx, String title, String sub, {String? yes, bool danger = true}) async =>
    await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: Text(sub),
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

// ------------------------------------------------------------------------------------------- fields
// text in two languages: edit the one chosen at the top, see the other one under it
class TrInput extends StatefulWidget {
  final Object? value;
  final ValueChanged<Json> onChanged;
  final String elang, label;
  final bool long, enabled;
  final int max;
  final WbCtx ctx;
  const TrInput({super.key, required this.value, required this.onChanged, required this.elang, required this.label, required this.ctx, this.long = false, this.max = 200, this.enabled = true});
  @override
  State<TrInput> createState() => _TrInputState();
}

class _TrInputState extends State<TrInput> {
  late final _c = TextEditingController(text: _v[widget.elang] ?? '');
  Map<String, String> get _v {
    final v = widget.value;
    return v is Map ? {'en': str(v['en']), 'km': str(v['km'])} : {'en': str(v), 'km': ''};
  }

  @override
  void didUpdateWidget(TrInput old) {
    super.didUpdateWidget(old);
    final want = _v[widget.elang] ?? '';
    if (old.elang != widget.elang || want != _c.text) _c.text = want;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final other = _v[widget.elang == 'km' ? 'en' : 'km'] ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Field(
            label: widget.label,
            labelTrailing: Chip2(widget.elang == 'km' ? 'ខ្មែរ' : 'EN'),
            controller: _c,
            maxLength: widget.max,
            maxLines: widget.long ? 4 : 1,
            enabled: widget.enabled,
            onChanged: (s) => widget.onChanged({..._v, widget.elang: s}),
          ),
          if (other.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(widget.ctx.m('otherLang', {'text': other.length > 80 ? '${other.substring(0, 80)}…' : other}), style: TextStyle(color: context.c.muted, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

// a plain text box bound to a value
class PlainInput extends StatefulWidget {
  final String value, label;
  final String? hint;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final int max;
  const PlainInput({super.key, required this.value, required this.label, required this.onChanged, this.hint, this.enabled = true, this.max = 300});
  @override
  State<PlainInput> createState() => _PlainInputState();
}

class _PlainInputState extends State<PlainInput> {
  late final _c = TextEditingController(text: widget.value);
  @override
  void didUpdateWidget(PlainInput old) {
    super.didUpdateWidget(old);
    if (widget.value != _c.text) _c.text = widget.value;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Field(label: widget.label, controller: _c, hint: widget.hint, maxLength: widget.max, enabled: widget.enabled, onChanged: widget.onChanged),
  );
}

// the site's picture library (upload, pick, delete)
class MediaSheet extends StatefulWidget {
  final WbCtx ctx;
  const MediaSheet({super.key, required this.ctx});
  @override
  State<MediaSheet> createState() => _MediaSheetState();
}

class _MediaSheetState extends State<MediaSheet> {
  WbCtx get ctx => widget.ctx;
  List<Json>? _rows;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ctx.run(() => ctx.api.get('${ctx.base}/media'));
    if (r != null && mounted) setState(() => _rows = objs(r['data']));
  }

  Future<void> _upload() async {
    final files = await ImagePicker().pickMultiImage(maxWidth: 1800, maxHeight: 1800, imageQuality: 86, limit: 12);
    if (files.isEmpty) return;
    setState(() => _busy = true);
    Json? last;
    for (final f in files.take(12)) {
      final r = await ctx.run(() async => ctx.api.post('${ctx.base}/media', fileForm('photo', await f.readAsBytes(), f.name.isEmpty ? 'photo.jpg' : f.name)));
      if (r == null) break;
      last = obj(r['data']);
    }
    await _load();
    if (mounted) setState(() => _busy = false);
    if (last != null && files.length == 1 && mounted) Navigator.pop(context, str(last['url']));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = _rows;
    return MSheet(
      title: ctx.m('mediaTitle'),
      footer: [
        Expanded(child: Muted(ctx.m('mediaSub', {'n': rows?.length ?? '…', 'max': n(ctx.limits['media'])}))),
        Btn(_busy ? ctx.m('uploading') : ctx.m('upload'), icon: LucideIcons.upload, small: true, busy: _busy, onTap: _busy || ctx.readOnly ? null : _upload),
      ],
      children: [
        if (rows == null)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Muted(ctx.m('mediaEmpty'), align: TextAlign.center),
          )
        else
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final r in rows)
                Stack(
                  fit: StackFit.expand,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(context, str(r['url'])),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image(image: netImage(
                          str(r['url'])),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(color: c.bg2),
                        ),
                      ),
                    ),
                    if (!ctx.readOnly)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () async {
                              final ok = await ctx.run(() => ctx.api.delete('${ctx.base}/media/${r['_id']}'));
                              if (ok != null) setState(() => _rows!.remove(r));
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(5),
                              child: Icon(LucideIcons.trash2, size: 13, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
      ],
    );
  }
}

class ImageField extends StatelessWidget {
  final String value, label;
  final ValueChanged<String> onChanged;
  final WbCtx ctx;
  const ImageField({super.key, required this.value, required this.label, required this.onChanged, required this.ctx});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 72,
                height: 54,
                decoration: BoxDecoration(
                  color: c.bg2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: value.isNotEmpty ? Image(image: netImage(value), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.imagePlus, size: 20, color: c.muted),
              ),
              const SizedBox(width: 10),
              Btn(
                value.isNotEmpty ? ctx.m('changeImage') : ctx.m('pickImage'),
                kind: BtnKind.ghost,
                small: true,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        final u = await showSheet<String>(context, (_) => MediaSheet(ctx: ctx));
                        if (u != null && u.isNotEmpty) onChanged(u);
                      },
              ),
              if (value.isNotEmpty) ...[
                const SizedBox(width: 4),
                TextButton(
                  onPressed: ctx.readOnly ? null : () => onChanged(''),
                  child: Text(ctx.m('removeImage'), style: TextStyle(color: c.danger)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// where a button / link goes: one of the pages, or any web / phone / email link
class LinkField extends StatefulWidget {
  final String value, label;
  final ValueChanged<String> onChanged;
  final WbCtx ctx;
  final List<Json> pages;
  final String lang;
  const LinkField({super.key, required this.value, required this.label, required this.onChanged, required this.ctx, required this.pages, required this.lang});
  @override
  State<LinkField> createState() => _LinkFieldState();
}

class _LinkFieldState extends State<LinkField> {
  late bool _other = widget.value.isNotEmpty && !widget.value.startsWith('page:');
  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    final ctx = widget.ctx;
    final bad = _other && v.isNotEmpty && !RegExp(r'^(https?://|tel:|mailto:|#)').hasMatch(v);
    final options = ['', for (final p in widget.pages) 'page:${p['slug']}', '__other'];
    final sel = _other ? '__other' : (options.contains(v) ? v : '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: sel,
            isExpanded: true,
            decoration: InputDecoration(labelText: widget.label, isDense: true),
            items: [
              DropdownMenuItem(value: '', child: Text(ctx.m('linkNone'))),
              for (final p in widget.pages)
                DropdownMenuItem(
                  value: 'page:${p['slug']}',
                  child: Text('${ctx.m('page')}: ${tx(p['title'], widget.lang).isEmpty ? p['slug'] : tx(p['title'], widget.lang)}', overflow: TextOverflow.ellipsis),
                ),
              DropdownMenuItem(value: '__other', child: Text(ctx.m('linkOther'))),
            ],
            onChanged: ctx.readOnly
                ? null
                : (x) {
                    setState(() => _other = x == '__other');
                    widget.onChanged(x == '__other' ? '' : (x ?? ''));
                  },
          ),
          if (_other) ...[const SizedBox(height: 8), PlainInput(value: v, label: '', hint: ctx.m('linkPh'), enabled: !ctx.readOnly, max: 500, onChanged: (s) => widget.onChanged(s.trim()))],
          if (bad) Text(ctx.m('linkBad'), style: TextStyle(color: context.c.danger, fontSize: 12)),
        ],
      ),
    );
  }
}

class _IconPick extends StatelessWidget {
  final String value, label;
  final ValueChanged<String> onChanged;
  final bool enabled;
  const _IconPick({required this.value, required this.label, required this.onChanged, required this.enabled});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            enabled: enabled,
            onSelected: onChanged,
            constraints: const BoxConstraints(maxWidth: 300),
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final e in wbIcons.entries)
                      InkWell(
                        onTap: () => Navigator.pop(context, e.key),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(color: e.key == value ? c.active : null, borderRadius: BorderRadius.circular(8)),
                          child: Icon(e.value, size: 18, color: c.ink),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(color: c.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(wbIcons[value] ?? LucideIcons.star, size: 19, color: c.brand),
                  const SizedBox(width: 4),
                  Icon(LucideIcons.chevronDown, size: 14, color: c.muted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// rows of a list (gallery pictures, prices, team…)
class _ListField extends StatefulWidget {
  final Map<String, dynamic> kind;
  final List rows;
  final String label;
  final ValueChanged<List> onChanged;
  final WbCtx ctx;
  final String elang;
  final List<Json> pages;
  const _ListField({required this.kind, required this.rows, required this.label, required this.onChanged, required this.ctx, required this.elang, required this.pages});
  @override
  State<_ListField> createState() => _ListFieldState();
}

class _ListFieldState extends State<_ListField> {
  late int _open = widget.rows.length <= 3 ? 0 : -1;
  int _gen = 0; // rebuild row editors after a move / delete

  Map<String, dynamic> get _list => (widget.kind['list'] as Map).cast<String, dynamic>();

  String _first(Map row) {
    for (final e in _list.entries) {
      if (e.value == 't' || e.value == 'tl') {
        final s = tx(row[e.key], widget.elang);
        if (s.isNotEmpty) return s;
      }
      if (e.value == 's' && e.key != 'icon' && str(row[e.key]).isNotEmpty) return str(row[e.key]);
    }
    return '';
  }

  void _set(List next, [int? open]) {
    widget.onChanged(next);
    setState(() {
      _gen++;
      if (open != null) _open = open;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ctx = widget.ctx;
    final rows = widget.rows;
    final max = n(widget.kind['max']).toInt();
    final ro = ctx.readOnly;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              const SizedBox(width: 6),
              Muted(ctx.m('rowsMax', {'n': rows.length, 'max': max})),
            ],
          ),
          const SizedBox(height: 6),
          for (final (i, row) in rows.indexed)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: c.bg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _open == i ? c.brand.withValues(alpha: .5) : Colors.transparent),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _open = _open == i ? -1 : i),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                            child: Row(
                              children: [
                                if (str((row as Map)['image'] ?? row['photo']).isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image(image: netImage(str(row['image'] ?? row['photo'])), width: 30, height: 30, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 30)),
                                  )
                                else
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: c.active,
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.brandInk),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _first(row).isEmpty ? '#${i + 1}' : _first(row),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: ro || i == 0
                            ? null
                            : () => _set(
                                [...rows]
                                  ..insert(i - 1, rows[i])
                                  ..removeAt(i + 1),
                                i - 1,
                              ),
                        icon: const Icon(LucideIcons.chevronUp, size: 16),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: ro || i == rows.length - 1
                            ? null
                            : () => _set(
                                [...rows]
                                  ..insert(i + 2, rows[i])
                                  ..removeAt(i),
                                i + 1,
                              ),
                        icon: const Icon(LucideIcons.chevronDown, size: 16),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: ro ? null : () => _set([...rows]..removeAt(i), -1),
                        icon: Icon(LucideIcons.x, size: 16, color: c.danger),
                      ),
                    ],
                  ),
                  if (_open == i)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                      child: Fields(
                        key: ValueKey('row$_gen-$i'),
                        fields: _list,
                        data: row.cast<String, dynamic>(),
                        onChanged: (r) => widget.onChanged([for (final (j, x) in rows.indexed) j == i ? r : x]),
                        ctx: ctx,
                        elang: widget.elang,
                        pages: widget.pages,
                      ),
                    ),
                ],
              ),
            ),
          if (rows.length < max)
            Align(
              alignment: Alignment.centerLeft,
              child: Btn(ctx.m('addRow'), icon: LucideIcons.plus, kind: BtnKind.ghost, small: true, onTap: ro ? null : () => _set([...rows, wbFill(_list, null)], rows.length)),
            ),
        ],
      ),
    );
  }
}

// every field of a block (or of one row) from its schema
class Fields extends StatelessWidget {
  final Map<String, dynamic> fields;
  final Json data;
  final ValueChanged<Json> onChanged;
  final WbCtx ctx;
  final String elang;
  final List<Json> pages;
  const Fields({super.key, required this.fields, required this.data, required this.onChanged, required this.ctx, required this.elang, required this.pages});

  @override
  Widget build(BuildContext context) {
    final ro = ctx.readOnly;
    void set(String k, Object? v) => onChanged({...data, k: v});
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in fields.entries)
          () {
            final k = e.key, kind = e.value, label = ctx.field(k);
            if (kind is List) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    const SizedBox(height: 6),
                    Segmented<String>(value: str(data[k]), options: [for (final o in kind) ('$o', ctx.choice('$o'))], onChanged: ro ? (_) {} : (v) => set(k, v)),
                  ],
                ),
              );
            }
            if (kind is Map) {
              return _ListField(
                kind: kind.cast<String, dynamic>(),
                rows: data[k] is List ? data[k] as List : const [],
                label: label,
                onChanged: (v) => set(k, v),
                ctx: ctx,
                elang: elang,
                pages: pages,
              );
            }
            if (kind == 't' || kind == 'tl') {
              return TrInput(value: data[k], onChanged: (v) => set(k, v), elang: elang, long: kind == 'tl', max: kind == 'tl' ? 3000 : 200, label: label, ctx: ctx, enabled: !ro);
            }
            if (kind == 'img') return ImageField(value: str(data[k]), onChanged: (v) => set(k, v), label: label, ctx: ctx);
            if (kind == 'to') return LinkField(value: str(data[k]), onChanged: (v) => set(k, v), label: label, ctx: ctx, pages: pages, lang: ctx.lang);
            if (kind == 'bool') {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SwitchRow(title: label, value: data[k] == true, onChanged: ro ? null : (v) => set(k, v)),
              );
            }
            if (kind == 'date') {
              final v = str(data[k]);
              final day = v.length >= 10 ? v.substring(0, 10) : '';
              final time = v.length >= 16 ? v.substring(11, 16) : '00:00';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DayField(label: label, value: day, onChanged: (d) => set(k, d.isEmpty ? '' : '${d}T$time')),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TimeField(value: time, onChanged: (t) => set(k, day.isEmpty ? '' : '${day}T$t')),
                    ),
                  ],
                ),
              );
            }
            if (k == 'icon') return _IconPick(value: str(data[k]), label: label, onChanged: (v) => set(k, v), enabled: !ro);
            return PlainInput(value: str(data[k]), label: label, enabled: !ro, onChanged: (v) => set(k, v));
          }(),
      ],
    );
  }
}
