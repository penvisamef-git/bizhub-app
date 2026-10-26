import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/buy_sheet.dart';
import '../../widgets/look_sheet.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show mGap, mDate, fileForm;
import '../restaurant/rest_online.dart' show shareWidgets;
import 'at_addons.dart';
import 'at_common.dart';
import 'at_mocks.dart';

// Logo & looks (LooksTab.jsx) · Door kiosk (AddonTabs.jsx KioskTab)
//   GET /looks → { app|qr|kiosk: { list, current, free, owned, price, yearly?, until? }, app_color, kiosk_color, qr_note }

const _appColors = ['#4F46E5', '#1A73E8', '#00897B', '#2E7D32', '#E0581A', '#D93025', '#C2185B', '#7B1FA2', '#B8860B', '#16171B'];
const _kioskColors = ['#0F766E', '#4F46E5', '#1A73E8', '#2E7D32', '#E0581A', '#D93025', '#C2185B', '#7B1FA2', '#B8860B', '#16171B'];

List<String> _hoursOf(List<Json> shifts) => shifts.where((s) => s['active'] != false).take(3).map((s) => '${str(s['name'])} ${str(s['start'])}–${str(s['end'])}').toList();

class LooksTab extends StatefulWidget {
  final AtCtx ctx;
  final bool kioskOnly;
  const LooksTab({super.key, required this.ctx, this.kioskOnly = false});
  @override
  State<LooksTab> createState() => _LooksTabState();
}

class _LooksTabState extends State<LooksTab> {
  AtCtx get ctx => widget.ctx;
  Json? _looks;
  String _busy = '';
  bool _dark = false;
  final _note = TextEditingController();
  final _sticker = GlobalKey();
  Timer? _colorTimer;
  String l(String k, [Map<String, Object?> v = const {}]) => ctx.t('atlk.$k', v);
  String _name(String kind, String key) => ctx.t.or('atlook.$kind.$key.name', key);
  String _what(String kind, String key) => ctx.t.or('atlook.$kind.$key.what', '');
  String get _link => '${Config.siteUrl}/a/${str(ctx.data['code'])}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    _colorTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/looks');
      if (!mounted) return;
      setState(() {
        _looks = obj(r['data']);
        _note.text = str(_looks!['qr_note']);
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _use(String kind, String key) async {
    setState(() => _busy = '$kind:$key');
    try {
      final r = await ctx.api.put('${ctx.base}/looks', {kind: key});
      if (mounted) setState(() => _looks = obj(r['data']));
      ctx.reload();
    } on ApiError catch (e) {
      if (e.status == 402) {
        _buy(kind, key);
      } else {
        ctx.fail(e);
      }
    }
    if (mounted) setState(() => _busy = '');
  }

  // colour: free; shown at once, saved a moment later
  void _color(String key, String hex) {
    setState(() => _looks![key] = hex);
    _colorTimer?.cancel();
    _colorTimer = Timer(const Duration(milliseconds: 400), () async {
      await ctx.run(() => ctx.api.put('${ctx.base}/looks', {key: hex}));
      ctx.reload();
    });
  }

  Future<void> _logo() async {
    final b = await atPickPicture(context, ctx, maxSize: 600);
    if (b == null) return;
    setState(() => _busy = 'logo');
    if (await ctx.run(() => ctx.api.post('${ctx.base}/logo', fileForm('file', b, 'logo.png'))) != null) await ctx.reload();
    if (mounted) setState(() => _busy = '');
  }

  Future<void> _removeLogo() async {
    setState(() => _busy = 'logo');
    if (await ctx.run(() => ctx.api.delete('${ctx.base}/logo')) != null) await ctx.reload();
    if (mounted) setState(() => _busy = '');
  }

  Widget _preview(String kind, String key, {double width = 130, bool big = false}) {
    final b = ctx.business;
    final name = str(b['name']), logo = str(b['logo_url']);
    return switch (kind) {
      'app' => AppMock(theme: key, color: atHex(str(_looks!['app_color']), const Color(0xFF4F46E5)), dark: _dark, t: ctx.t, name: name, logo: logo, width: big ? 150 : width * .8),
      'kiosk' => KioskMock(theme: key, color: atHex(str(_looks!['kiosk_color']), const Color(0xFF0F766E)), t: ctx.t, name: name, logo: logo, width: big ? 230 : width * 1.5),
      _ => QrSticker(theme: key, name: name, logo: logo, link: _link, hours: _hoursOf(ctx.shifts), note: str(_looks!['qr_note']), width: big ? 170 : width),
    };
  }

  Future<void> _buy(String kind, String key, {bool renew = false}) async {
    final info = obj(_looks![kind]);
    final price = n(info['price']);
    final name = _name(kind, key);
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BuySheet(
        stage: _preview(kind, key, big: true),
        badge: switch (kind) {
          'app' => l('badgeApp'),
          'kiosk' => l('badgeKiosk'),
          _ => l('badgeQr'),
        },
        title: renew ? l('renewTitle', {'name': name}) : l('buyTitle', {'name': name}),
        sub: renew
            ? l('renewKioskSub', {'name': name})
            : switch (kind) {
                'app' => l('buyAppSub'),
                'kiosk' => l('buyKioskSub'),
                _ => l('buyQrSub'),
              },
        perks: [_what(kind, key), info['yearly'] == true ? l('yearly') : l('oneTime')],
        price: price,
        buyLabel: renew ? '${l('renew')} · ${l('buyFor', {'coins': fmt(price)})}' : l('buy', {'coins': fmt(price)}),
        doneTitle: name,
        doneSub: l('done', {'name': name}),
        doneButton: ctx.t('app.continue'),
        buy: () => ctx.api.post('${ctx.base}/looks/$kind/$key'),
        onDone: (r) {
          if (r['data'] is Map) setState(() => _looks = obj(r['data']));
          ctx.reload();
        },
      ),
    );
  }

  Widget _colors(String key, List<String> list) {
    final c = context.c;
    final cur = str(_looks![key]).toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l('colour'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final h in list)
              InkWell(
                customBorder: const CircleBorder(),
                onTap: ctx.readOnly ? null : () => _color(key, h),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: atHex(h),
                    shape: BoxShape.circle,
                    border: Border.all(color: cur == h ? c.ink : Colors.transparent, width: 3),
                  ),
                  child: cur == h ? const Icon(LucideIcons.check, size: 15, color: Colors.white) : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Muted(l('colourFree')),
      ],
    );
  }

  // a look's state: in use, owned/free (yearly: until when), or its price
  ({bool current, bool own, bool ended, Object? end}) _state(Json info, String key) {
    final owned = (info['owned'] as List? ?? const []).map((e) => '$e').toSet();
    final current = info['current'] == key;
    final own = key == info['free'] || owned.contains(key);
    final end = info['yearly'] == true && key != info['free'] ? obj(info['until'])[key] : null;
    return (current: current, own: own, ended: current && !own, end: end);
  }

  // tap a look → the look sheet (big preview, swipe for the others, Use / Buy / Renew at the bottom)
  Future<void> _open(String kind, List<String> list, String key) async {
    await showLookSheet(
      context,
      title: switch (kind) {
        'app' => l('badgeApp'),
        'kiosk' => l('badgeKiosk'),
        _ => l('badgeQr'),
      },
      count: list.length,
      initial: list.contains(key) ? list.indexOf(key) : 0,
      item: (context, i, refresh) {
        final k = list[i];
        final info = obj(_looks![kind]);
        final st = _state(info, k);
        final price = fmt(n(info['price']));
        final yearly = info['yearly'] == true;
        return LookItem(
          name: _name(kind, k),
          sub: [
            _what(kind, k),
            if (st.end != null) l('until', {'date': mDate(st.end, ctx.lang)}),
            if (st.ended) l('ended'),
          ].where((x) => x.isNotEmpty).join(' · '),
          badge: st.current && !st.ended ? l('inUse') : (st.own ? (k == info['free'] ? l('free') : l('owned')) : (yearly ? l('perYear', {'coins': price}) : l('buyFor', {'coins': price}))),
          badgeTone: st.own ? Tone.good : Tone.warn,
          preview: Padding(padding: const EdgeInsets.all(8), child: _preview(kind, k, big: true)),
          acts: [
            if (st.own && !st.current)
              LookAct(
                l('use'),
                icon: LucideIcons.check,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        await _use(kind, k);
                        return true;
                      },
              ),
            if (!st.own)
              LookAct(
                st.ended ? '${l('renew')} · $price' : (yearly ? l('perYear', {'coins': price}) : l('buyFor', {'coins': price})),
                gold: true,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        Future.microtask(() => _buy(kind, k, renew: st.ended));
                        return true;
                      },
              ),
            if (st.own && st.end != null)
              LookAct(
                '${l('renew')} · $price',
                gold: true,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        Future.microtask(() => _buy(kind, k, renew: true));
                        return true;
                      },
              ),
          ],
        );
      },
    );
  }

  Widget _grid(String kind) {
    final c = context.c;
    final info = obj(_looks![kind]);
    final list = (info['list'] as List? ?? const []).map((e) => '$e').toList();
    final yearly = info['yearly'] == true;
    final price = fmt(n(info['price']));
    final w = kind == 'kiosk' ? 300.0 : 160.0;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final key in list)
          () {
            final st = _state(info, key);
            final status = st.ended
                ? l('ended')
                : st.current
                ? l('inUse')
                : st.own
                ? (st.end != null ? l('until', {'date': mDate(st.end, ctx.lang)}) : (key == info['free'] ? l('free') : l('owned')))
                : (yearly ? l('perYear', {'coins': price}) : l('buyFor', {'coins': price}));
            return SizedBox(
              width: kind == 'kiosk' ? double.infinity : w,
              child: Material(
                color: c.card,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _open(kind, list, key),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: st.current ? c.brand : c.line, width: st.current ? 2 : 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(12)),
                          child: Stack(
                            children: [
                              IgnorePointer(child: _preview(kind, key, width: kind == 'kiosk' ? 180 : 128)),
                              if (st.current)
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: CircleAvatar(
                                    radius: 11,
                                    backgroundColor: c.brand,
                                    child: const Icon(LucideIcons.check, size: 13, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _name(kind, key),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (!st.own) ...[const SizedBox(width: 4), Icon(LucideIcons.crown, size: 13, color: c.warn)],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (!st.own) ...[const CoinIcon(size: 12), const SizedBox(width: 4)],
                            Flexible(
                              child: Text(
                                status,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: st.ended ? c.warn : (st.own ? c.good : c.muted)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }(),
      ],
    );
  }

  List<Widget> kioskSection() {
    final lk = _looks!;
    return [
      atPanel([
        MHeadRow(icon: LucideIcons.scanLine, title: l('kioskTitle')),
        const SizedBox(height: 4),
        Muted(l('kioskSub', {'coins': fmt(n(obj(lk['kiosk'])['price']))})),
        const SizedBox(height: 12),
        _colors('kiosk_color', _kioskColors),
        if (!ctx.addonOn('att_kiosk')) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: context.c.warnBg, borderRadius: BorderRadius.circular(12)),
            child: Text(
              l('kioskNeed'),
              style: TextStyle(color: context.c.warn, fontWeight: FontWeight.w600),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _grid('kiosk'),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final lk = _looks;
    if (lk == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 4));
    if (widget.kioskOnly) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kioskSection());
    final logo = str(ctx.business['logo_url']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        atPanel([
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(18)),
                child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.imagePlus, color: c.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l('logoTitle'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                    Muted(l('logoSub')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              Btn(
                _busy == 'logo'
                    ? l('uploading')
                    : logo.isNotEmpty
                    ? l('change')
                    : l('upload'),
                icon: LucideIcons.imagePlus,
                small: true,
                busy: _busy == 'logo',
                onTap: ctx.readOnly || _busy == 'logo' ? null : _logo,
              ),
              if (logo.isNotEmpty) Btn(l('remove'), icon: LucideIcons.trash2, kind: BtnKind.ghost, small: true, onTap: ctx.readOnly || _busy == 'logo' ? null : _removeLogo),
            ],
          ),
        ]),
        mGap,
        atPanel([
          MHeadRow(icon: LucideIcons.smartphone, title: l('appTitle')),
          const SizedBox(height: 4),
          Muted(l('appSub', {'coins': fmt(n(obj(lk['app'])['price']))})),
          const SizedBox(height: 12),
          _colors('app_color', _appColors),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(l('modeTitle'), style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              ChoiceChip(avatar: const Icon(LucideIcons.sunMedium, size: 14), label: Text(l('light')), selected: !_dark, onSelected: (_) => setState(() => _dark = false)),
              const SizedBox(width: 6),
              ChoiceChip(avatar: const Icon(LucideIcons.moon, size: 14), label: Text(l('dark')), selected: _dark, onSelected: (_) => setState(() => _dark = true)),
            ],
          ),
          const SizedBox(height: 4),
          Muted(l('modeNote')),
          const SizedBox(height: 12),
          _grid('app'),
        ]),
        mGap,
        atPanel([
          Row(
            children: [
              Expanded(
                child: MHeadRow(icon: LucideIcons.printer, title: l('qrTitle')),
              ),
              Btn(l('print'), icon: LucideIcons.printer, small: true, onTap: () => shareWidgets([_sticker], (_) => 'attendance-sticker.png')),
            ],
          ),
          const SizedBox(height: 4),
          Muted(l('qrSub', {'coins': fmt(n(obj(lk['qr'])['price']))})),
          const SizedBox(height: 12),
          Field(label: l('note'), controller: _note, hint: l('notePh'), maxLength: 80, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
          if (_note.text != str(lk['qr_note'])) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Btn(
                l('save'),
                small: true,
                busy: _busy == 'note',
                onTap: () async {
                  setState(() => _busy = 'note');
                  final r = await ctx.run(() => ctx.api.put('${ctx.base}/looks', {'qr_note': _note.text}), l('saved'));
                  if (r != null && mounted) setState(() => _looks = obj(r['data']));
                  if (mounted) setState(() => _busy = '');
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          // the sticker in use, full size — this is what "Print sticker" shares
          Center(
            child: RepaintBoundary(
              key: _sticker,
              child: QrSticker(
                theme: str(obj(lk['qr'])['current']).isEmpty ? 'classic' : str(obj(lk['qr'])['current']),
                name: str(ctx.business['name']),
                logo: logo,
                link: _link,
                hours: _hoursOf(ctx.shifts),
                note: str(lk['qr_note']),
                width: 300,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _grid('qr'),
        ]),
      ],
    );
  }
}

class MHeadRow extends StatelessWidget {
  final IconData icon;
  final String title;
  const MHeadRow({super.key, required this.icon, required this.title});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 19, color: context.c.brand),
      const SizedBox(width: 8),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ),
    ],
  );
}

// ------------------------------------------------------------------------------------------------ DOOR KIOSK
class KioskTab extends StatefulWidget {
  final AtCtx ctx;
  const KioskTab({super.key, required this.ctx});
  @override
  State<KioskTab> createState() => _KioskTabState();
}

class _KioskTabState extends State<KioskTab> {
  AtCtx get ctx => widget.ctx;
  Json? _data;
  String x(String k) => ctx.t('atx.$k');

  @override
  void initState() {
    super.initState();
    if (ctx.addonOn('att_kiosk')) _load();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/kiosk');
      if (mounted) setState(() => _data = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final on = ctx.addonOn('att_kiosk');
    String link(Json b) => '${Config.siteUrl}/k/${b['token']}';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        if (!on)
          AtLocked(ctx: ctx, addon: 'att_kiosk')
        else ...[
          atPanel([
            Text(ctx.a('tabs.kiosk'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Muted(x('kioskSub')),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: c.warnBg, borderRadius: BorderRadius.circular(12)),
              child: Text(
                x('kioskWarn'),
                style: TextStyle(color: c.warn, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
          mGap,
          if (_data == null)
            const SkelList(rows: 2)
          else
            for (final b in objs(_data!['branches'])) ...[
              Opacity(
                opacity: b['active'] == false ? .55 : 1,
                child: atPanel([
                  Row(
                    children: [
                      Icon(LucideIcons.mapPin, size: 17, color: c.brand),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(str(b['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      if (b['active'] == false) Chip2(x('off')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(12)),
                    child: SelectableText(link(b), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 10),
                  // the BizHub POS app on the tablet scans this to link itself
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.line),
                        ),
                        child: QrImageView(data: link(b), size: 108, padding: EdgeInsets.zero, backgroundColor: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Muted(x('kioskAppQr'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Btn(
                        x('open'),
                        icon: LucideIcons.externalLink,
                        small: true,
                        onTap: () => launchUrl(Uri.parse(link(b)), mode: LaunchMode.externalApplication),
                      ),
                      Btn(
                        x('copy'),
                        icon: LucideIcons.copy,
                        kind: BtnKind.ghost,
                        small: true,
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: link(b)));
                          ctx.notify(x('copied'));
                        },
                      ),
                      Btn(
                        x('newLink'),
                        icon: LucideIcons.refreshCw,
                        kind: BtnKind.ghost,
                        small: true,
                        onTap: ctx.readOnly
                            ? null
                            : () async {
                                if (await ctx.run(() => ctx.api.post('${ctx.base}/kiosk/${b['_id']}/reset')) != null) _load();
                              },
                      ),
                    ],
                  ),
                ]),
              ),
              mGap,
            ],
        ],
        mGap,
        LooksTab(ctx: ctx, kioskOnly: true),
      ],
    );
  }
}
