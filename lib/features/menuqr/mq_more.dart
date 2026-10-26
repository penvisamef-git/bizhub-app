import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt, fmtDate;
import '../../core/theme.dart';
import '../../widgets/color_pick.dart';
import '../../widgets/look_sheet.dart';
import '../../widgets/ui.dart';
import '../common/qr_card.dart';
import '../mart/mart_common.dart' show GoldBtn;
import '../mart/mart_kit.dart' show DayField, MSheet, showSheet;
import '../restaurant/rest_common.dart' show SwitchRow;
import 'mq_common.dart';

Color _hexColor(Object? h, int fallback) {
  final s = str(h).replaceFirst('#', '');
  return Color(s.length == 6 ? 0xFF000000 | (int.tryParse(s, radix: 16) ?? fallback & 0xFFFFFF) : fallback);
}

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

double _lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  final hi = x > y ? x : y, lo = x > y ? y : x;
  return (hi + 0.05) / (lo + 0.05);
}

// ============================== QR code (MqQr.jsx) ==============================
class QrTab extends StatefulWidget {
  final MqCtx ctx;
  const QrTab({super.key, required this.ctx});
  @override
  State<QrTab> createState() => _QrTabState();
}

class _QrTabState extends State<QrTab> {
  MqCtx get ctx => widget.ctx;
  Json get s => ctx.settings;
  late Json _q = Map<String, dynamic>.from(obj(s['qr']));
  late final _header = TextEditingController(text: str(_q['header']));
  late final _footer = TextEditingController(text: str(_q['footer']));
  late final _info = TextEditingController(text: str(_q['info']));
  String _busy = '';

  List<String> get _owned => (obj(ctx.data['qr'])['owned'] as List? ?? const []).map((e) => '$e').toList();
  num get _price => n(obj(ctx.data['qr'])['price']);

  @override
  void dispose() {
    _header.dispose();
    _footer.dispose();
    _info.dispose();
    super.dispose();
  }

  Color _c(String k, int fb) => _hexColor(_q[k], fb);

  bool get _dirty {
    final o = obj(s['qr']);
    return _header.text != str(o['header']) ||
        _footer.text != str(o['footer']) ||
        _info.text != str(o['info']) ||
        str(_q['color']) != str(o['color']) ||
        str(_q['bg']) != str(o['bg']) ||
        str(_q['accent']) != str(o['accent']) ||
        (_q['logo'] == true) != (o['logo'] == true);
  }

  Future<void> _save([Json extra = const {}]) async {
    setState(() => _busy = extra['style'] != null ? 'use-${extra['style']}' : 'save');
    final r = await ctx.run(
      () => ctx.api.put('${ctx.base}/settings', {
        'qr': {'color': _q['color'], 'bg': _q['bg'], 'accent': _q['accent'], 'header': _header.text, 'footer': _footer.text, 'info': _info.text, 'logo': _q['logo'] == true, ...extra},
      }),
      ctx.m('saved'),
    );
    if (r != null) {
      final d = obj(r['data']);
      ctx.setSettings(d);
      setState(() => _q = Map<String, dynamic>.from(obj(d['qr'])));
    }
    if (mounted) setState(() => _busy = '');
  }

  // tap a QR style → the style sheet (your card in that style, swipe for the next), Use / Buy at the bottom
  Future<void> _openStyle(String key, String url, Color color, Color bg, Color accent, bool logo) async {
    final keys = qrStyles.keys.toList();
    final style = str(obj(s['qr'])['style']).isEmpty ? 'classic' : str(obj(s['qr'])['style']);
    await showLookSheet(
      context,
      title: ctx.m('qrStyles'),
      count: keys.length,
      initial: keys.indexOf(key),
      item: (context, i, refresh) {
        final k = keys[i];
        final st = qrStyles[k]!;
        final mine = _owned.contains(k) || k == 'classic';
        final using = style == k;
        final art = qrCardArt(text: url, style: k, color: color, bg: bg, accent: accent, logo: logo, name: str(ctx.business['name']), header: _header.text, footer: _footer.text, info: _info.text);
        return LookItem(
          name: ctx.lang == 'km' ? st.km : st.en,
          badge: using ? ctx.m('inUse') : (mine ? ctx.m(k == 'classic' ? 'free' : 'owned') : '${fmt(_price)} ${ctx.m('coins')}'),
          badgeTone: using || mine ? Tone.good : Tone.warn,
          preview: SizedBox(
            width: 300,
            child: FittedBox(
              child: CardArtView(art: art, logo: logo ? ctx.logo : ''),
            ),
          ),
          acts: [
            if (!using && mine)
              LookAct(
                ctx.m('use'),
                icon: LucideIcons.check,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        await _save({'style': k});
                        return true;
                      },
              ),
            if (!mine)
              LookAct(
                ctx.m('buy', {'coins': fmt(_price)}),
                gold: true,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        ctx.askBuy({
                          'qr': k,
                          'stage': SizedBox(
                            width: 150,
                            child: FittedBox(
                              child: CardArtView(
                                art: qrCodeArt(text: url, style: k, color: color, bg: bg, accent: accent, px: 300),
                              ),
                            ),
                          ),
                        });
                        return true;
                      },
              ),
          ],
        );
      },
    );
  }

  Future<void> _newLink() async {
    if (!await mqConfirm(context, ctx, ctx.m('newLink'), sub: ctx.m('newLinkAsk'), yes: ctx.m('newLink'))) return;
    setState(() => _busy = 'link');
    final r = await ctx.run(() => ctx.api.post('${ctx.base}/link/refresh'), ctx.m('newLinkDone'));
    if (r != null) ctx.setSettings(obj(r['data']));
    if (mounted) setState(() => _busy = '');
  }

  Widget _colour(String k, String label, int fb) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: ctx.readOnly
          ? null
          : () => showSheet<void>(
              context,
              (sheet) => MSheet(
                title: label,
                children: [
                  ColorRow(
                    value: _hex(_c(k, fb)),
                    colors: k == 'bg' ? const ['#FFFFFF', '#FFF7ED', '#F0F9FF', '#ECFDF5', '#FDF2F8', '#FFFBEB', '#F3F4F6', '#111827'] : brandColors,
                    customLabel: label,
                    saveLabel: ctx.m('save'),
                    cancelLabel: ctx.m('cancel'),
                    onChanged: (v) {
                      setState(() => _q = {..._q, k: v.toLowerCase()});
                      Navigator.pop(sheet);
                    },
                  ),
                ],
              ),
            ),
      child: Column(
        children: [
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: _c(k, fb),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.c.line),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: context.c.muted)),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final url = menuUrl(s['slug']);
    final logo = _q['logo'] == true && ctx.logo.isNotEmpty;
    final color = _c('color', 0xFF111111), bg = _c('bg', 0xFFFFFFFF), accent = _c('accent', 0xFFE0581A);
    final style = str(s['qr'] is Map ? obj(s['qr'])['style'] : '').isEmpty ? 'classic' : str(obj(s['qr'])['style']);
    final art = qrCardArt(text: url, style: style, color: color, bg: bg, accent: accent, logo: logo, name: str(ctx.business['name']), header: _header.text, footer: _footer.text, info: _info.text);
    final file = str(s['slug']).replaceAll(RegExp(r'[^a-z0-9-]'), '');
    final owned = _owned;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        mqHead(context, LucideIcons.qrCode, ctx.m('qrTitle'), ctx.m('qrSub')),
        const SizedBox(height: 12),
        mqPanel([
          Center(
            child: SizedBox(
              width: 280,
              child: FittedBox(
                child: CardArtView(art: art, logo: logo ? ctx.logo : ''),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: InkWell(
              onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
              child: Text(
                url.replaceFirst(RegExp(r'^https?://'), ''),
                style: TextStyle(color: c.brand, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Btn(
                ctx.m('download'),
                icon: LucideIcons.download,
                small: true,
                busy: _busy == 'dl',
                onTap: _busy.isNotEmpty
                    ? null
                    : () async {
                        setState(() => _busy = 'dl');
                        try {
                          await shareCardArt(art, logo ? ctx.logo : '', '$file-qr-card.png');
                        } catch (e) {
                          ctx.notify('$e');
                        }
                        if (mounted) setState(() => _busy = '');
                      },
              ),
              Btn(
                ctx.m('downloadCode'),
                icon: LucideIcons.qrCode,
                kind: BtnKind.ghost,
                small: true,
                onTap: () => shareCardArt(qrCodeArt(text: url, style: style, color: color, bg: bg, accent: accent, logo: logo, px: 1024), logo ? ctx.logo : '', '$file-qr.png', scale: 1),
              ),
              Btn(
                ctx.m('copyLink'),
                icon: LucideIcons.copy,
                kind: BtnKind.ghost,
                small: true,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  ctx.notify(ctx.m('copied'));
                },
              ),
              Btn(ctx.m('newLink'), icon: LucideIcons.refreshCw, kind: BtnKind.ghost, small: true, busy: _busy == 'link', onTap: ctx.readOnly || _busy.isNotEmpty ? null : _newLink),
            ],
          ),
        ]),
        const SizedBox(height: 12),
        mqPanel([
          MqInput(ctx.m('qrHeader'), _header, max: 60, hint: ctx.m('qrHeaderPh'), enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
          MqInput(ctx.m('qrFooter'), _footer, max: 80, hint: ctx.m('qrFooterPh'), enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
          MqInput(ctx.m('qrInfo'), _info, max: 120, hint: ctx.m('qrInfoPh'), enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
          Row(
            children: [
              _colour('color', ctx.m('qrColour'), 0xFF111111),
              const SizedBox(width: 10),
              _colour('bg', ctx.m('qrBg'), 0xFFFFFFFF),
              const SizedBox(width: 10),
              _colour('accent', ctx.m('qrAccent'), 0xFFE0581A),
            ],
          ),
          if (_contrast(color, bg) < 3) ...[const SizedBox(height: 10), Alert(ctx.m('lowContrast'), tone: Tone.warn)],
          SwitchRow(title: ctx.m('qrLogo'), value: logo, onChanged: ctx.readOnly || ctx.logo.isEmpty ? null : (v) => setState(() => _q = {..._q, 'logo': v})),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Btn(ctx.m('save'), icon: LucideIcons.save, small: true, busy: _busy == 'save', onTap: ctx.readOnly || _busy.isNotEmpty || !_dirty ? null : () => _save()),
          ),
        ]),
        const SizedBox(height: 12),
        mqPanel([
          Text(ctx.m('qrStyles'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Muted(ctx.m('qrStylesSub', {'coins': fmt(_price)})),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: .62,
            children: [
              for (final k in qrStyles.keys)
                Builder(
                  builder: (context) {
                    final mine = owned.contains(k) || k == 'classic';
                    final using = style == k;
                    final st = qrStyles[k]!;
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openStyle(k, url, color, bg, accent, logo),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: c.bg2,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: using ? c.brand : c.line, width: using ? 2.5 : 1),
                        ),
                        child: Column(
                          children: [
                            AspectRatio(
                              aspectRatio: 1,
                              child: FittedBox(
                                child: CardArtView(
                                  art: qrCodeArt(text: url, style: k, color: color, bg: bg, accent: accent, px: 96),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              ctx.lang == 'km' ? st.km : st.en,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                            ),
                            const Spacer(),
                            if (using)
                              Text(
                                ctx.m('inUse'),
                                style: TextStyle(color: c.brand, fontWeight: FontWeight.w800, fontSize: 12),
                              )
                            else if (mine)
                              Text(
                                ctx.m(k == 'classic' ? 'free' : 'owned'),
                                style: TextStyle(color: c.muted, fontWeight: FontWeight.w700, fontSize: 12),
                              )
                            else
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CoinIcon(size: 12),
                                  const SizedBox(width: 4),
                                  Text(fmt(_price), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ]),
      ],
    );
  }
}

// ============================== Sale & promotions (mq_promos) ==============================
class PromosTab extends StatefulWidget {
  final MqCtx ctx;
  const PromosTab({super.key, required this.ctx});
  @override
  State<PromosTab> createState() => _PromosTabState();
}

class _PromosTabState extends State<PromosTab> {
  MqCtx get ctx => widget.ctx;
  List<Json>? _rows;
  List<Json> _cats = [], _items = [];
  String _busy = '';

  @override
  void initState() {
    super.initState();
    if (ctx.on('mq_promos')) _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([ctx.api.get('${ctx.base}/promos'), ctx.api.get('${ctx.base}/categories'), ctx.api.get('${ctx.base}/items')]);
      if (!mounted) return;
      setState(() {
        _rows = objs(r[0]['data']);
        _cats = objs(r[1]['data']);
        _items = objs(r[2]['data']);
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  bool _live(Json p) {
    final t = DateTime.now().toUtc().add(const Duration(hours: 7)).toIso8601String().substring(0, 10);
    final a = str(p['start_date']), b = str(p['end_date']);
    return p['active'] == true && (a.isEmpty || a.compareTo(t) <= 0) && (b.isEmpty || b.compareTo(t) >= 0);
  }

  Future<void> _toggle(Json p) async {
    setState(() => _busy = str(p['_id']));
    final r = await ctx.run(() => ctx.api.put('${ctx.base}/promos/${p['_id']}', {'active': p['active'] != true}));
    if (r != null && mounted) setState(() => _rows = [for (final x in _rows!) x['_id'] == p['_id'] ? obj(r['data']) : x]);
    if (mounted) setState(() => _busy = '');
  }

  Future<void> _edit(Json p) async {
    final ok = await showSheet<bool>(context, (_) => _PromoSheet(ctx: ctx, promo: p, cats: _cats, items: _items));
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (!ctx.on('mq_promos')) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          mqHead(context, LucideIcons.tag, ctx.m('promosTitle'), ctx.m('promosSub')),
          const SizedBox(height: 12),
          MqLocked(ctx: ctx, addon: 'mq_promos'),
        ],
      );
    }
    final rows = _rows;
    final days = ctx.t.list('mq.dayNames');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          mqHead(
            context,
            LucideIcons.tag,
            ctx.m('promosTitle'),
            ctx.m('promosSub'),
            actions: [Btn(ctx.m('addPromo'), icon: LucideIcons.plus, small: true, onTap: ctx.readOnly ? null : () => _edit({}))],
          ),
          const SizedBox(height: 12),
          if (rows == null)
            const SkelList(rows: 3)
          else if (rows.isEmpty)
            mqPanel([Muted(ctx.m('noPromos'))])
          else
            for (final p in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Opacity(
                  opacity: p['active'] == true ? 1 : .6,
                  child: Panel(
                    padding: const EdgeInsets.all(12),
                    onTap: ctx.readOnly ? null : () => _edit(p),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(14)),
                          clipBehavior: Clip.antiAlias,
                          alignment: Alignment.center,
                          child: str(obj(p['photo'])['url']).isNotEmpty
                              ? Image(image: netImage(str(obj(p['photo'])['url'])), width: 64, height: 64, fit: BoxFit.cover)
                              : Text(
                                  p['kind'] == 'percent'
                                      ? '${p['value']}%'
                                      : p['kind'] == 'amount'
                                      ? money(p['value'], ctx.currency)
                                      : '📣',
                                  style: TextStyle(fontWeight: FontWeight.w900, color: c.brandInk),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ctx.lang == 'en'
                                    ? (str(p['title_en']).isNotEmpty ? str(p['title_en']) : str(p['title_km']))
                                    : (str(p['title_km']).isNotEmpty ? str(p['title_km']) : str(p['title_en'])),
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                [
                                  ctx.t.or('mq.kinds.${p['kind']}', str(p['kind'])),
                                  if (p['kind'] != 'banner') p['kind'] == 'percent' ? '${p['value']}%' : money(p['value'], ctx.currency),
                                  p['all_items'] == true
                                      ? ctx.m('allItems')
                                      : (p['category_ids'] as List? ?? const []).isNotEmpty
                                      ? '${ctx.m('someCats')} (${(p['category_ids'] as List).length})'
                                      : '${ctx.m('someItems')} (${(p['item_ids'] as List? ?? const []).length})',
                                ].join(' · '),
                                style: TextStyle(color: c.muted, fontSize: 12.5),
                              ),
                              if (str(p['start_date']).isNotEmpty || str(p['end_date']).isNotEmpty || (p['days'] as List? ?? const []).isNotEmpty)
                                Text(
                                  [
                                    if (str(p['start_date']).isNotEmpty || str(p['end_date']).isNotEmpty)
                                      '${str(p['start_date']).isEmpty ? '…' : p['start_date']} → ${str(p['end_date']).isEmpty ? '…' : p['end_date']}',
                                    if ((p['days'] as List? ?? const []).isNotEmpty) (p['days'] as List).map((d) => days.length > n(d) ? days[n(d).toInt()] : '').join(' '),
                                    if (str(p['from']).isNotEmpty && str(p['to']).isNotEmpty) '${p['from']}–${p['to']}',
                                  ].join(' · '),
                                  style: TextStyle(color: c.muted, fontSize: 12),
                                ),
                              if (_live(p)) ...[const SizedBox(height: 4), Chip2(ctx.m('running'), tone: Tone.good)],
                            ],
                          ),
                        ),
                        Switch.adaptive(value: p['active'] == true, onChanged: ctx.readOnly || _busy == p['_id'] ? null : (_) => _toggle(p)),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _PromoSheet extends StatefulWidget {
  final MqCtx ctx;
  final Json promo;
  final List<Json> cats, items;
  const _PromoSheet({required this.ctx, required this.promo, required this.cats, required this.items});
  @override
  State<_PromoSheet> createState() => _PromoSheetState();
}

class _PromoSheetState extends State<_PromoSheet> {
  MqCtx get ctx => widget.ctx;
  Json get p => widget.promo;
  late final _km = TextEditingController(text: str(p['title_km']));
  late final _en = TextEditingController(text: str(p['title_en']));
  late final _note = TextEditingController(text: str(p['note']));
  late final _value = TextEditingController(text: '${p['value'] ?? 10}');
  late String _kind = str(p['kind']).isEmpty ? 'percent' : str(p['kind']);
  late String _scope = p['all_items'] == true || p['_id'] == null
      ? 'all'
      : (p['item_ids'] as List? ?? const []).isNotEmpty
      ? 'items'
      : (p['category_ids'] as List? ?? const []).isNotEmpty
      ? 'cats'
      : 'all';
  late final List<String> _catIds = (p['category_ids'] as List? ?? const []).map((e) => '$e').toList();
  late final List<String> _itemIds = (p['item_ids'] as List? ?? const []).map((e) => '$e').toList();
  late String _start = str(p['start_date']), _end = str(p['end_date']), _from = str(p['from']), _to = str(p['to']);
  late final List<int> _days = (p['days'] as List? ?? const []).map((e) => n(e).toInt()).toList();
  late bool _active = p['active'] != false;
  Json? _photo; // chosen from the media library
  String _busy = '', _err = '';

  @override
  void dispose() {
    for (final x in [_km, _en, _note, _value]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = 'save';
      _err = '';
    });
    final body = {
      'title_km': _km.text.trim(),
      'title_en': _en.text.trim(),
      'note': _note.text.trim(),
      'kind': _kind,
      'value': num.tryParse(_value.text.trim()) ?? 0,
      'all_items': _scope == 'all',
      'category_ids': _scope == 'cats' ? _catIds : [],
      'item_ids': _scope == 'items' ? _itemIds : [],
      'start_date': _start,
      'end_date': _end,
      'days': _days,
      'from': _from.isNotEmpty && _to.isNotEmpty ? _from : '',
      'to': _from.isNotEmpty && _to.isNotEmpty ? _to : '',
      'active': _active,
    };
    try {
      final r = p['_id'] == null ? await ctx.api.post('${ctx.base}/promos', body) : await ctx.api.put('${ctx.base}/promos/${p['_id']}', body);
      final id = obj(r['data'])['_id'];
      if (_photo != null) await ctx.api.post('${ctx.base}/promos/$id/photo', {'media_id': _photo!['_id']});
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      setState(() {
        _err = e.message;
        _busy = '';
      });
    }
  }

  Future<void> _remove() async {
    final name = _km.text.trim().isNotEmpty ? _km.text.trim() : _en.text.trim();
    if (!await mqConfirm(context, ctx, ctx.m('sure', {'name': name}))) return;
    setState(() => _busy = 'remove');
    try {
      await ctx.api.delete('${ctx.base}/promos/${p['_id']}');
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      setState(() {
        _err = e.message;
        _busy = '';
      });
    }
  }

  Widget _pick(String label, bool on, VoidCallback onTap) {
    final c = context.c;
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? c.active : c.bg2,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: on ? c.brand : c.line),
        ),
        child: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: on ? c.brandInk : c.ink),
        ),
      ),
    );
  }

  Future<void> _time(bool from) async {
    final cur = from ? _from : _to;
    final parts = cur.split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: parts.length == 2 ? TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0) : const TimeOfDay(hour: 9, minute: 0),
    );
    if (t == null) return;
    final v = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() => from ? _from = v : _to = v);
  }

  Widget _timeBox(String label, String v, bool from) {
    final c = context.c;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _time(from),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              decoration: BoxDecoration(
                color: c.bg2,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.line),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.clock, size: 16, color: c.muted),
                  const SizedBox(width: 8),
                  Expanded(child: Text(v.isEmpty ? '—' : v)),
                  if (v.isNotEmpty)
                    InkWell(
                      onTap: () => setState(() => from ? _from = '' : _to = ''),
                      child: Icon(LucideIcons.x, size: 16, color: c.muted),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final noName = _km.text.trim().isEmpty && _en.text.trim().isEmpty;
    final days = ctx.t.list('mq.dayNames');
    final preview = _photo != null ? str(_photo!['url']) : str(obj(p['photo'])['url']);
    return MSheet(
      title: p['_id'] == null ? ctx.m('addPromo') : ctx.m('edit'),
      footer: [
        if (p['_id'] != null) Btn(ctx.m('delete'), icon: LucideIcons.trash2, kind: BtnKind.danger, small: true, busy: _busy == 'remove', onTap: _busy.isNotEmpty || ctx.readOnly ? null : _remove),
        const Spacer(),
        Btn(ctx.m('save'), icon: LucideIcons.check, small: true, busy: _busy == 'save', onTap: _busy.isNotEmpty || ctx.readOnly || noName ? null : _save),
      ],
      children: [
        MqInput(ctx.m('titleKm'), _km, max: 80, onChanged: (_) => setState(() {})),
        MqInput(ctx.m('titleEn'), _en, max: 80, onChanged: (_) => setState(() {})),
        Text(ctx.m('kind'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final k in ['percent', 'amount', 'banner']) _pick(ctx.m('kinds.$k'), _kind == k, () => setState(() => _kind = k)),
          ],
        ),
        const SizedBox(height: 12),
        if (_kind != 'banner') MqInput('${ctx.m('value')}${_kind == 'percent' ? ' (%)' : ''}', _value, number: true),
        MqInput(ctx.m('note'), _note, max: 200),
        if (_kind != 'banner') ...[
          Text(ctx.m('appliesTo'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (k, label) in [('all', 'allItems'), ('cats', 'someCats'), ('items', 'someItems')]) _pick(ctx.m(label), _scope == k, () => setState(() => _scope = k)),
            ],
          ),
          const SizedBox(height: 8),
          if (_scope == 'cats')
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final cat in widget.cats)
                  _pick(
                    '${str(cat['icon'])} ${mqName(cat, ctx.lang)}'.trim(),
                    _catIds.contains(str(cat['_id'])),
                    () => setState(() => _catIds.contains(str(cat['_id'])) ? _catIds.remove(str(cat['_id'])) : _catIds.add(str(cat['_id']))),
                  ),
              ],
            ),
          if (_scope == 'items')
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final it in widget.items)
                  _pick(
                    mqName(it, ctx.lang),
                    _itemIds.contains(str(it['_id'])),
                    () => setState(() => _itemIds.contains(str(it['_id'])) ? _itemIds.remove(str(it['_id'])) : _itemIds.add(str(it['_id']))),
                  ),
              ],
            ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: DayField(label: ctx.m('startDate'), value: _start, onChanged: (v) => setState(() => _start = v)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DayField(label: ctx.m('endDate'), value: _end, onChanged: (v) => setState(() => _end = v)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(children: [_timeBox(ctx.m('fromTime'), _from, true), const SizedBox(width: 10), _timeBox(ctx.m('toTime'), _to, false)]),
        const SizedBox(height: 12),
        Text(ctx.m('days'), style: const TextStyle(fontWeight: FontWeight.w700)),
        if (_days.isEmpty) Muted(ctx.m('everyDay')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < days.length; i++)
              _pick(
                days[i],
                _days.contains(i),
                () => setState(() {
                  _days.contains(i) ? _days.remove(i) : _days.add(i);
                  _days.sort();
                }),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(ctx.m('banner'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => pickMedia(
            context,
            ctx,
            onPick: (list) async {
              setState(() => _photo = list.first);
              return true;
            },
          ),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: c.bg2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.line),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: preview.isNotEmpty
                ? Image(image: netImage(preview), width: double.infinity, height: 120, fit: BoxFit.cover)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.imagePlus, color: c.muted),
                      const SizedBox(width: 8),
                      Text(ctx.m('addPhoto'), style: TextStyle(color: c.muted)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 6),
        SwitchRow(title: ctx.m('active'), value: _active, onChanged: (v) => setState(() => _active = v)),
        if (_err.isNotEmpty) Alert(_err),
      ],
    );
  }
}

// ============================== Customer feedback (mq_feedback) ==============================
class FeedbackTab extends StatefulWidget {
  final MqCtx ctx;
  const FeedbackTab({super.key, required this.ctx});
  @override
  State<FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends State<FeedbackTab> {
  MqCtx get ctx => widget.ctx;
  Json? _res;
  int _page = 1;
  String _busy = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ctx.run(() => ctx.api.get('${ctx.base}/feedback', {'page': _page}));
    if (mounted && r != null) setState(() => _res = r);
  }

  Future<void> _readAll() async {
    setState(() => _busy = 'all');
    final r = await ctx.run(() => ctx.api.put('${ctx.base}/feedback-read-all'));
    if (r != null) {
      await _load();
      ctx.reload();
    }
    if (mounted) setState(() => _busy = '');
  }

  Future<void> _remove(Json f) async {
    if (!await mqConfirm(context, ctx, ctx.m('sure', {'name': '★${f['stars']}'}))) return;
    setState(() => _busy = str(f['_id']));
    final r = await ctx.run(() => ctx.api.delete('${ctx.base}/feedback/${f['_id']}'));
    if (r != null) {
      await _load();
      ctx.reload();
    }
    if (mounted) setState(() => _busy = '');
  }

  Widget _stars(num v, double size) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [for (var s = 1; s <= 5; s++) Icon(Icons.star_rounded, size: size, color: s <= v.round() ? const Color(0xFFF5B82E) : const Color(0x33888888))],
  );

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final res = _res;
    final rows = objs(res?['data']);
    final total = n(res?['total']);
    final stars = (res?['stars'] as List? ?? const []).map((e) => n(e)).toList();
    final pages = n(res?['pages']).toInt();
    final unread = rows.any((f) => f['read'] != true);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          mqHead(
            context,
            LucideIcons.messageSquareHeart,
            ctx.m('fbTitle'),
            ctx.m('fbSub'),
            actions: [
              if (unread) Btn(ctx.m('readAll'), icon: LucideIcons.checkCheck, kind: BtnKind.ghost, small: true, busy: _busy == 'all', onTap: ctx.readOnly || _busy.isNotEmpty ? null : _readAll),
            ],
          ),
          const SizedBox(height: 12),
          if (!ctx.on('mq_feedback')) ...[MqLocked(ctx: ctx, addon: 'mq_feedback'), const SizedBox(height: 12)],
          if (res == null)
            const SkelList(rows: 3)
          else ...[
            if (total > 0) ...[
              mqPanel([
                Row(
                  children: [
                    Column(
                      children: [
                        Text('${res['avg']}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
                        _stars(n(res['avg']), 18),
                        Text(ctx.m('reviews', {'n': fmt(total)}), style: TextStyle(color: c.muted, fontSize: 12.5)),
                      ],
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        children: [
                          for (var s = 5; s >= 1; s--)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  SizedBox(width: 28, child: Text('$s★', style: const TextStyle(fontSize: 12.5))),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(99),
                                      child: LinearProgressIndicator(
                                        value: total == 0 || stars.length < s ? 0 : stars[s - 1] / total,
                                        minHeight: 8,
                                        backgroundColor: c.bg2,
                                        color: const Color(0xFFF5B82E),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 30,
                                    child: Text(
                                      stars.length >= s ? fmt(stars[s - 1]) : '0',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(fontSize: 12.5, color: c.muted),
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
              ]),
              const SizedBox(height: 12),
            ],
            if (total == 0 && ctx.on('mq_feedback')) mqPanel([Muted(ctx.m('fbEmpty'))]),
            for (final f in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  padding: const EdgeInsets.all(14),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _stars(n(f['stars']), 18),
                          const SizedBox(width: 8),
                          if (f['read'] != true) Chip2(ctx.m('new'), tone: Tone.brand),
                          const Spacer(),
                          Text(
                            fmtDate(f['created_date'], lang: ctx.lang),
                            style: TextStyle(color: c.muted, fontSize: 12),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: ctx.readOnly || _busy.isNotEmpty ? null : () => _remove(f),
                            icon: Icon(LucideIcons.trash2, size: 16, color: c.danger),
                          ),
                        ],
                      ),
                      if (str(f['text']).isNotEmpty) Text(str(f['text']), style: const TextStyle(height: 1.5)),
                      if (str(f['name']).isNotEmpty || str(f['phone']).isNotEmpty) ...[
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: str(f['phone']).isEmpty ? null : () => launchUrl(Uri.parse('tel:${f['phone']}')),
                          child: Text([str(f['name']), str(f['phone'])].where((x) => x.isNotEmpty).join(' · '), style: TextStyle(color: c.muted, fontSize: 12.5)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (pages > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _page <= 1
                        ? null
                        : () {
                            setState(() => _page--);
                            _load();
                          },
                    icon: const Icon(LucideIcons.chevronLeft),
                  ),
                  Text('$_page / $pages'),
                  IconButton(
                    onPressed: _page >= pages
                        ? null
                        : () {
                            setState(() => _page++);
                            _load();
                          },
                    icon: const Icon(LucideIcons.chevronRight),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

// ============================== Scan stats (mq_stats) ==============================
class StatsTab extends StatefulWidget {
  final MqCtx ctx;
  const StatsTab({super.key, required this.ctx});
  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  MqCtx get ctx => widget.ctx;
  int _days = 30;
  Json? _st;

  @override
  void initState() {
    super.initState();
    if (ctx.on('mq_stats')) _load();
  }

  Future<void> _load() async {
    setState(() => _st = null);
    final r = await ctx.run(() => ctx.api.get('${ctx.base}/stats', {'days': _days}));
    if (mounted && r != null) setState(() => _st = obj(r['data']));
  }

  Widget _bars(List<num> values, {double height = 140, List<String>? labels}) {
    final c = context.c;
    final max = values.fold<num>(1, (a, b) => b > a ? b : a);
    return SizedBox(
      height: height + (labels == null ? 0 : 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: (values[i] / max * height).clamp(2, height).toDouble(),
                      decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(3)),
                    ),
                    if (labels != null)
                      SizedBox(
                        height: 18,
                        child: Text(labels[i], style: TextStyle(fontSize: 10, color: c.muted)),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (!ctx.on('mq_stats')) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          mqHead(context, LucideIcons.chartColumn, ctx.m('statsTitle'), ctx.m('statsSub')),
          const SizedBox(height: 12),
          MqLocked(ctx: ctx, addon: 'mq_stats'),
        ],
      );
    }
    final st = _st;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          mqHead(
            context,
            LucideIcons.chartColumn,
            ctx.m('statsTitle'),
            ctx.m('statsSub'),
            actions: [
              for (final d in [7, 30, 90])
                ChoiceChip(
                  label: Text('$d'),
                  selected: _days == d,
                  onSelected: (_) {
                    setState(() => _days = d);
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (st == null)
            const SkelList(rows: 4)
          else ...[
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.1,
              children: [
                for (final (k, v) in [
                  (ctx.m('today'), st['today']),
                  (ctx.m('total', {'n': st['days']}), st['total']),
                  (ctx.m('perDay'), st['avg']),
                  (ctx.m('allTime'), st['all_time']),
                ])
                  Panel(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(k, style: TextStyle(color: c.muted, fontSize: 12.5)),
                        Text(fmt(n(v)), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            mqPanel([
              n(st['total']) == 0 ? Muted(ctx.m('noStats')) : _bars([for (final d in objs(st['series'])) n(d['scans'])]),
            ]),
            const SizedBox(height: 12),
            mqPanel([
              Text(ctx.m('byHour'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              _bars((st['hours'] as List? ?? const []).map((e) => n(e)).toList(), height: 90, labels: [for (var h = 0; h < 24; h++) h % 6 == 0 ? '$h' : '']),
            ]),
            const SizedBox(height: 12),
            mqPanel([
              Text(ctx.m('topItems'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              if (objs(st['top']).isEmpty) Muted(ctx.m('noStats')),
              for (final (i, t) in objs(st['top']).indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(color: c.muted, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(10)),
                        clipBehavior: Clip.antiAlias,
                        alignment: Alignment.center,
                        child: str(t['photo']).isNotEmpty ? Image(image: netImage(str(t['photo'])), fit: BoxFit.cover, width: 40, height: 40) : const Text('🍽️'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(mqName(t, ctx.lang), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      Text(ctx.m('opened', {'n': fmt(n(t['opened']))}), style: TextStyle(color: c.muted, fontSize: 12.5)),
                    ],
                  ),
                ),
            ]),
          ],
        ],
      ),
    );
  }
}

// ============================== Add-ons ==============================
class AddonsTab extends StatelessWidget {
  final MqCtx ctx;
  const AddonsTab({super.key, required this.ctx});

  Widget _card(BuildContext context, {required IconData icon, required String title, required String price, required String what, String free = '', required List<Widget> foot, bool active = false}) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        padding: const EdgeInsets.all(14),
        color: active ? c.goodBg : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, size: 20, color: c.brand),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                      Row(
                        children: [
                          const CoinIcon(size: 12),
                          const SizedBox(width: 4),
                          Text(
                            price,
                            style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(what, style: const TextStyle(height: 1.5)),
            if (free.isNotEmpty) Text(free, style: TextStyle(color: c.muted, fontSize: 12.5)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: foot),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final addons = obj(ctx.data['addons']);
    final themes = obj(obj(ctx.data['themes'])['price']);
    final qrPrice = n(obj(ctx.data['qr'])['price']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        mqHead(context, LucideIcons.puzzle, ctx.m('addonsTitle'), ctx.m('addonsSub')),
        const SizedBox(height: 12),
        for (final e in addons.entries)
          Builder(
            builder: (context) {
              final a = obj(e.value);
              final k = e.key;
              final active = a['active'] == true;
              return _card(
                context,
                icon: mqAddonIcons[k] ?? LucideIcons.puzzle,
                title: ctx.t.or('mq.addonNames.$k', k),
                price: '${fmt(n(a['price']))} ${ctx.m('coins')} ${a['days'] != null ? ctx.m('perYear') : '· ${ctx.m('forever')}'}',
                what: ctx.t.or('mq.addonWhat.$k', ''),
                free: ctx.t.or('mq.addonFree.$k', ''),
                active: active,
                foot: [
                  if (active)
                    Chip2(
                      a['expires_at'] != null ? ctx.m('ends', {'date': fmtDate(a['expires_at'], lang: ctx.lang)}) : ctx.m('unlocked'),
                      icon: LucideIcons.check,
                      tone: Tone.good,
                    )
                  else
                    GoldBtn(ctx.m('unlock', {'coins': fmt(n(a['price']))}), onTap: ctx.readOnly ? null : () => ctx.askBuy({'addon': k})),
                  if (active && a['days'] != null) Btn(ctx.m('renewFor', {'coins': fmt(n(a['price']))}), kind: BtnKind.ghost, small: true, onTap: ctx.readOnly ? null : () => ctx.askBuy({'addon': k})),
                ],
              );
            },
          ),
        _card(
          context,
          icon: LucideIcons.palette,
          title: ctx.m('looksTitle'),
          price: '${fmt(n(themes['basic']))} / ${fmt(n(themes['pro']))} · ${ctx.m('forever')}',
          what: ctx.m('looksSub'),
          foot: [Btn('${ctx.m('tabs.looks')} →', kind: BtnKind.ghost, small: true, onTap: () => ctx.go('looks'))],
        ),
        _card(
          context,
          icon: LucideIcons.qrCode,
          title: ctx.m('qrStyles'),
          price: '${fmt(qrPrice)} · ${ctx.m('forever')}',
          what: ctx.m('qrStylesSub', {'coins': fmt(qrPrice)}),
          foot: [Btn('${ctx.m('tabs.qr')} →', kind: BtnKind.ghost, small: true, onTap: () => ctx.go('qr'))],
        ),
      ],
    );
  }
}
