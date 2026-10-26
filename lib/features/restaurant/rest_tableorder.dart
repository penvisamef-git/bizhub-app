import 'package:dio/dio.dart' show DioMediaType, FormData, MultipartFile;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/buy_sheet.dart';
import '../../widgets/look_sheet.dart';
import '../../widgets/ui.dart';
import 'rest_common.dart';
import 'rest_looks.dart' show lookStatus;
import 'rest_online.dart' show shareWidgets;
import 'rest_reports.dart' show whenShort;
import 'rest_stickers.dart';

// Table ordering (the web's TableOrderTab.jsx): guests order from the QR on their table.

extension on RestCtx {
  String to(String key, [Map<String, Object?> vars = const {}]) => t('to.$key', vars);
  String xt(String key, [Map<String, Object?> vars = const {}]) => t('extras.$key', vars);
}

const _radii = [50, 100, 200, 500, 0];

class TableOrderSection extends StatefulWidget {
  final RestCtx ctx;
  const TableOrderSection({super.key, required this.ctx});
  @override
  State<TableOrderSection> createState() => _TableOrderSectionState();
}

class _TableOrderSectionState extends State<TableOrderSection> {
  Json? _data;
  String _view = 'setup', _busy = '', _zone = '', _renewing = '';
  final Set<String> _picked = {};
  final _lat = TextEditingController(), _lng = TextEditingController();
  RestCtx get ctx => widget.ctx;
  bool get _on => ctx.addonOn('rest_table_order');
  String _link(Object? tok) => '${Config.siteUrl}/public/order/$tok';
  String get _shop => str(ctx.settings['name_km']).isNotEmpty ? str(ctx.settings['name_km']) : str(ctx.settings['name_en']);
  Color get _color => Color(0xFF000000 | (int.tryParse(str(ctx.settings['color']).replaceFirst('#', ''), radix: 16) ?? 0xE0581A));
  String get _logo => str(obj(ctx.settings['logo'])['url']);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  Json get _s => obj(_data?['settings']);

  void _setPlace(Json s) {
    _lat.text = s['lat'] == null ? '' : '${s['lat']}';
    _lng.text = s['lng'] == null ? '' : '${s['lng']}';
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/table-order');
      if (!mounted) return;
      setState(() {
        _data = obj(r['data']);
        _setPlace(_s);
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _save(Json patch) async {
    final s = {..._s, ...patch};
    setState(() => _busy = 'save');
    try {
      final body = {
        'enabled': s['enabled'] == true,
        'require_open': s['require_open'] == true,
        'radius': n(s['radius']),
        'lat': _lat.text.trim().isEmpty ? null : num.tryParse(_lat.text.trim()),
        'lng': _lng.text.trim().isEmpty ? null : num.tryParse(_lng.text.trim()),
      };
      final r = await ctx.api.put('${ctx.base}/table-order', body);
      setState(() {
        _data = {..._data!, 'settings': obj(r['data'])};
        _setPlace(_s);
      });
      ctx.notify(ctx.to('saved'));
    } catch (e) {
      ctx.fail(e);
      _setPlace(_s);
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  // "11.5564, 104.9282" pasted into one box fills both
  void _onLat(String v) {
    final m = RegExp(r'^\s*(-?\d+(?:\.\d+)?)\s*[, ]\s*(-?\d+(?:\.\d+)?)\s*$').firstMatch(v);
    if (m != null) {
      _lat.text = m[1]!;
      _lng.text = m[2]!;
    }
    setState(() {});
  }

  Future<void> _uploadSound() async {
    final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['mp3', 'm4a', 'wav', 'ogg']);
    if (f == null) return;
    final bytes = await f.xFile.readAsBytes();
    final ext = f.name.split('.').last.toLowerCase();
    final type = switch (ext) {
      'm4a' => 'audio/mp4',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      _ => 'audio/mpeg',
    };
    setState(() => _busy = 'sound');
    try {
      final r = await ctx.api.post('${ctx.base}/table-order/sound', FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: f.name, contentType: DioMediaType.parse(type))}));
      setState(() => _data = {..._data!, 'settings': obj(r['data'])});
      ctx.notify(ctx.to('saved'));
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Future<void> _removeSound() async {
    setState(() => _busy = 'sound');
    try {
      final r = await ctx.api.delete('${ctx.base}/table-order/sound');
      setState(() => _data = {..._data!, 'settings': obj(r['data'])});
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Future<void> _renew(Json tb) async {
    setState(() => _renewing = '');
    try {
      final r = await ctx.api.post('${ctx.base}/table-order/tables/${tb['_id']}/renew');
      final fresh = obj(r['data']);
      setState(() => _data = {..._data!, 'tables': objs(_data!['tables']).map((x) => str(x['_id']) == str(tb['_id']) ? fresh : x).toList()});
      ctx.notify(ctx.to('renewed', {'t': tb['name']}));
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _useLook(String kind, String theme) async {
    setState(() => _busy = 'look:$theme');
    try {
      final r = await ctx.api.put('${ctx.base}/table-order/themes/$kind/current', {'theme': theme});
      setState(
        () => _data = {
          ..._data!,
          'themes': {...obj(_data!['themes']), kind: obj(r['data'])},
        },
      );
      if (kind == 'qr') ctx.reload(); // the QR menu prints with the same look
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  String _lookName(String kind, String k) => ctx.t.or('${kind == 'qr' ? 'qtheme' : 'otheme'}.$k.${ctx.lang}', k);

  Widget _lookPicture(String kind, String k) {
    final tables = objs(_data!['tables']);
    final sample = tables.isNotEmpty ? tables.first : null;
    if (kind == 'qr') {
      return FittedBox(
        fit: BoxFit.contain,
        child: QrSticker(
          theme: k,
          color: _color,
          logo: _logo,
          shop: _shop,
          table: sample == null ? 'A1' : str(sample['name']),
          data: sample == null ? _link('sample') : _link(sample['token']),
          scan: ctx.to('scan'),
          tableWord: ctx.to('tableWord'),
        ),
      );
    }
    return OrderPageMock(theme: k, color: _color, name: _shop, logo: _logo, lang: ctx.lang);
  }

  void _buy(String kind, String k) {
    final L = obj(obj(_data!['themes'])[kind]);
    final price = n(L['price']);
    final qr = kind == 'qr';
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BuySheet(
        stage: SizedBox(width: qr ? 170 : 220, height: qr ? 280 : null, child: _lookPicture(kind, k)),
        badge: ctx.to(qr ? 'views.stickers' : 'views.page'),
        title: ctx.to(qr ? 'buyStickerTitle' : 'buyPageTitle', {'name': _lookName(kind, k)}),
        sub: ctx.to(qr ? 'buyStickerSub' : 'buyPageSub'),
        perks: [ctx.to(qr ? 'perkSticker' : 'perkPage'), '${ctx.r('oneTime')} · ${ctx.r('forever')}'],
        price: price,
        buyLabel: ctx.r('buy', {'coins': '${fmt(price)} ${ctx.r('coins')}'}),
        doneTitle: ctx.r('unlockedTag'),
        doneSub: ctx.to(qr ? 'doneSticker' : 'donePage', {'name': _lookName(kind, k)}),
        doneButton: ctx.t('app.continue'),
        buy: () => ctx.api.post('${ctx.base}/table-order/themes/$kind/$k'),
        onDone: (_) => _load().then((_) => _useLook(kind, k)),
      ),
    );
  }

  void _print(List<Json> tables) {
    final theme = str(obj(obj(_data!['themes'])['qr'])['current']).isEmpty ? 'classic' : str(obj(obj(_data!['themes'])['qr'])['current']);
    final keys = [for (final _ in tables) GlobalKey()];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(ctx.to('printN', {'n': tables.length}), style: Theme.of(sheet).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                ),
                Btn(ctx.t('app.shareReceipt'), icon: LucideIcons.share2, small: true, onTap: () => shareWidgets(keys, (i) => 'table-${str(tables[i]['name'])}.png')),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              child: Wrap(
                spacing: 14,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                children: [
                  for (final (i, tb) in tables.indexed)
                    RepaintBoundary(
                      key: keys[i],
                      child: QrSticker(theme: theme, color: _color, logo: _logo, shop: _shop, table: str(tb['name']), data: _link(tb['token']), scan: ctx.to('scan'), tableWord: ctx.to('tableWord')),
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
    final data = _data;
    if (data == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 4));
    final s = _s;
    final ro = ctx.readOnly;
    final list = <Widget>[
      Panel(
        child: RestHead(
          ctx.to('title'),
          sub: ctx.to('sub'),
          trailing: _on ? Switch.adaptive(value: s['enabled'] == true, onChanged: ro || _busy == 'save' ? null : (v) => _save({'enabled': v})) : null,
        ),
      ),
      const SizedBox(height: 12),
      Segmented<String>(
        value: _view,
        options: [
          for (final v in ['setup', 'stickers', 'page']) (v, ctx.to('views.$v')),
        ],
        onChanged: (v) => setState(() => _view = v),
      ),
      gap14,
    ];
    if (_view != 'setup') {
      final kind = _view == 'stickers' ? 'qr' : 'order';
      final L = obj(obj(data['themes'])[kind]);
      List<String> ls(String k) => ((L[k] as List?) ?? const []).map((e) => '$e').toList();
      final free = ls('free'), paid = ls('paid'), owned = ls('owned');
      list.add(Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Muted(ctx.to(kind == 'qr' ? 'stickersSub' : 'pageSub'))));
      list.add(gap14);
      list.add(
        LayoutBuilder(
          builder: (_, box) {
            final cols = box.maxWidth > 520 ? 3 : 2;
            final w = (box.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final k in [...free, ...paid])
                  SizedBox(width: w, child: _lookCard(kind, k, str(L['current']) == k, free.contains(k), owned.contains(k), n(L['price']), ro, c, [...free, ...paid])),
              ],
            );
          },
        ),
      );
      return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: list);
    }
    if (!_on) {
      list.addAll([AddonPrompt(ctx: ctx, addonKey: 'rest_table_order'), gap14, _How(ctx: ctx)]);
      return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: list);
    }
    final placeChanged = _lat.text.trim() != (s['lat'] == null ? '' : '${s['lat']}') || _lng.text.trim() != (s['lng'] == null ? '' : '${s['lng']}');
    final lat = num.tryParse(_lat.text.trim()), lng = num.tryParse(_lng.text.trim());
    final sound = obj(s['sound']);
    final allTables = objs(data['tables']);
    final zones = objs(data['zones']);
    final tables = allTables.where((t) => _zone.isEmpty || str(t['zone_id']) == _zone).toList();
    final toPrint = tables.where((t) => _picked.contains(str(t['_id']))).toList();
    final allPicked = tables.isNotEmpty && toPrint.length == tables.length;
    final recent = objs(data['recent']);
    list.addAll([
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: s['enabled'] == true ? c.goodBg : c.bg2, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ctx.to('on'),
              style: TextStyle(fontWeight: FontWeight.w800, color: s['enabled'] == true ? c.good : c.ink),
            ),
            const SizedBox(height: 4),
            Muted(s['enabled'] == true ? ctx.to('posNote') : ctx.to('onSub')),
          ],
        ),
      ),
      gap14,
      // place
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RestHead(ctx.to('place'), sub: ctx.to('placeSub')),
            Row(
              children: [
                Expanded(
                  child: Field(label: ctx.to('lat'), hint: '11.5564', controller: _lat, keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true), enabled: !ro, onChanged: _onLat),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Field(
                    label: ctx.to('lng'),
                    hint: '104.9282',
                    controller: _lng,
                    keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    enabled: !ro,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Muted(ctx.to('pasteHint')),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Btn(
                  ctx.t('app.pasteLocation'),
                  icon: LucideIcons.clipboardPaste,
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: ro
                      ? null
                      : () async {
                          final d = await Clipboard.getData('text/plain');
                          if (d?.text != null) _onLat(d!.text!);
                        },
                ),
                if (lat != null && lng != null)
                  Btn(
                    ctx.t('app.showOnMap'),
                    icon: LucideIcons.mapPin,
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: () => launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'), mode: LaunchMode.externalApplication),
                  ),
                if (placeChanged) Btn(ctx.to('save'), small: true, busy: _busy == 'save', onTap: ro || _busy == 'save' ? null : () => _save({})),
              ],
            ),
            if (lat == null || lng == null) ...[const SizedBox(height: 8), Muted(ctx.to('noPlace'))],
            gap14,
            SelectField<num>(
              label: ctx.to('radius'),
              value: n(s['radius']),
              options: [for (final m in _radii) (m, m == 0 ? ctx.to('radiusOff') : '$m m')],
              onChanged: ro ? null : (v) => _save({'radius': v}),
            ),
            if (n(s['radius']) == 0) ...[const SizedBox(height: 10), Alert(ctx.to('radiusWarn'), tone: Tone.warn)],
          ],
        ),
      ),
      gap14,
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(ctx.to('rules'), style: Theme.of(context).textTheme.titleMedium),
            SwitchRow(title: ctx.to('requireOpen'), sub: ctx.to('requireOpenSub'), value: s['require_open'] == true, onChanged: ro ? null : (v) => _save({'require_open': v})),
          ],
        ),
      ),
      gap14,
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RestHead(ctx.to('sound'), sub: ctx.to('soundSub')),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(12)),
                  child: Icon(LucideIcons.music, size: 18, color: c.brandInk),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(str(sound['url']).isNotEmpty ? (str(sound['name']).isEmpty ? 'sound.mp3' : str(sound['name'])) : ctx.to('builtIn'), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (str(sound['url']).isNotEmpty)
                  Btn(
                    ctx.to('play'),
                    icon: LucideIcons.play,
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: () => launchUrl(Uri.parse(str(sound['url'])), mode: LaunchMode.externalApplication),
                  ),
                Btn(
                  str(sound['url']).isNotEmpty ? ctx.to('change') : ctx.to('upload'),
                  icon: LucideIcons.upload,
                  kind: BtnKind.ghost,
                  small: true,
                  busy: _busy == 'sound',
                  onTap: ro || _busy == 'sound' ? null : _uploadSound,
                ),
                if (str(sound['url']).isNotEmpty) Btn(ctx.to('remove'), icon: LucideIcons.trash2, kind: BtnKind.ghost, small: true, onTap: ro || _busy == 'sound' ? null : _removeSound),
              ],
            ),
          ],
        ),
      ),
      gap14,
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RestHead(ctx.to('tables'), sub: ctx.to('tablesSub')),
            if (allTables.isEmpty)
              Muted(ctx.to('noTables'))
            else ...[
              if (zones.isNotEmpty) ...[
                SelectField<String>(value: _zone, options: [('', ctx.to('allZones')), for (final z in zones) (str(z['_id']), str(z['name']))], onChanged: (v) => setState(() => _zone = v)),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Btn(
                    allPicked ? ctx.to('clearPick') : ctx.to('pickAll'),
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: tables.isEmpty
                        ? null
                        : () => setState(() {
                            if (allPicked) {
                              _picked.removeAll(tables.map((t) => str(t['_id'])));
                            } else {
                              _picked.addAll(tables.map((t) => str(t['_id'])));
                            }
                          }),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Btn(
                      toPrint.isEmpty ? ctx.to('pickFirst') : ctx.to('printN', {'n': toPrint.length}),
                      icon: LucideIcons.printer,
                      small: true,
                      onTap: toPrint.isEmpty ? null : () => _print(toPrint),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final tb in tables) _tableRow(tb, c, ro),
            ],
          ],
        ),
      ),
      gap14,
      Panel(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(ctx.to('recent'), style: Theme.of(context).textTheme.titleMedium),
            ),
            if (recent.isEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 12), child: Muted(ctx.to('recentEmpty'))),
            for (final (i, g) in recent.indexed) ...[if (i > 0) Divider(height: 1, color: c.line, indent: 16, endIndent: 16), _recentRow(g, c)],
          ],
        ),
      ),
      gap14,
      _How(ctx: ctx),
    ]);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: list),
    );
  }

  Widget _tableRow(Json tb, C c, bool ro) {
    final id = str(tb['_id']);
    final picked = _picked.contains(id);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(4, 6, 6, 6),
      decoration: BoxDecoration(
        color: picked ? c.active : null,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: picked ? c.brand : c.line),
      ),
      child: _renewing == id
          ? Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(ctx.to('renewAsk', {'t': tb['name']}), style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Btn('✕', kind: BtnKind.ghost, small: true, onTap: () => setState(() => _renewing = '')),
                      const SizedBox(width: 8),
                      Btn(ctx.to('renew'), small: true, onTap: () => _renew(tb)),
                    ],
                  ),
                ],
              ),
            )
          : Row(
              children: [
                Checkbox(value: picked, onChanged: (v) => setState(() => v == true ? _picked.add(id) : _picked.remove(id))),
                Icon(LucideIcons.qrCode, size: 18, color: c.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(str(tb['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  tooltip: ctx.to('copy'),
                  icon: const Icon(LucideIcons.copy, size: 17),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _link(tb['token'])));
                    ctx.notify(ctx.to('copied'));
                  },
                ),
                IconButton(
                  tooltip: ctx.to('open'),
                  icon: const Icon(LucideIcons.externalLink, size: 17),
                  onPressed: () => launchUrl(Uri.parse(_link(tb['token'])), mode: LaunchMode.externalApplication),
                ),
                IconButton(tooltip: ctx.to('renew'), icon: const Icon(LucideIcons.refreshCw, size: 17), onPressed: ro ? null : () => setState(() => _renewing = id)),
              ],
            ),
    );
  }

  Widget _recentRow(Json g, C c) {
    final lines = objs(g['lines']);
    final count = lines.fold<num>(0, (a, l) => a + n(l['qty']));
    final st = str(g['status']);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${str(g['table_name'])} · ${count == 1 && ctx.lang == 'en' ? '1 item' : ctx.to('items', {'n': fmt(count)})}${str(g['guest_name']).isNotEmpty ? ' · ${g['guest_name']}' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  lines.map((l) => '${fmt(l['qty'])}× ${str(l['name_en']).isNotEmpty ? l['name_en'] : l['name_km']}').join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.muted, fontSize: 12.5),
                ),
                Text(whenShort(g['created_date'], ctx.lang), style: TextStyle(color: c.muted, fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmtMoney(n(g['total']), ctx.currency), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Chip2(
                '${ctx.t.or('to.st.$st', st)}${str(g['order_number']).isNotEmpty ? ' · #${g['order_number']}' : ''}',
                tone: st == 'accepted' ? Tone.good : (st == 'rejected' ? Tone.danger : Tone.brand),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // tap a look → the look sheet over all of them (swipe), Use / Unlock at the bottom
  Future<void> _openLooks(String kind, List<String> all, String start) => showLookSheet(
    context,
    title: ctx.to(kind == 'qr' ? 'views.stickers' : 'views.page'),
    count: all.length,
    initial: all.contains(start) ? all.indexOf(start) : 0,
    item: (context, i, refresh) {
      final k = all[i];
      final L = obj(obj(_data!['themes'])[kind]);
      List<String> ls(String x) => ((L[x] as List?) ?? const []).map((e) => '$e').toList();
      final free = ls('free').contains(k), owned = ls('owned').contains(k);
      final on = str(L['current']) == k;
      final has = free || owned;
      final price = n(L['price']);
      return LookItem(
        name: _lookName(kind, k),
        sub: ctx.t.or('${kind == 'qr' ? 'qtheme' : 'otheme'}.$k.d_${ctx.lang}', ''),
        preview: kind == 'qr' ? SizedBox(width: 280, height: 440, child: _lookPicture(kind, k)) : SizedBox(width: 360, child: _lookPicture(kind, k)),
        badge: on ? ctx.xt('inUse') : (free ? ctx.xt('free') : (owned ? ctx.xt('owned') : '${fmt(price)} ${ctx.r('coins')}')),
        badgeTone: on || has ? Tone.good : Tone.warn,
        acts: [
          if (!on && has)
            LookAct(
              ctx.xt('use'),
              icon: LucideIcons.check,
              onTap: ctx.readOnly
                  ? null
                  : () async {
                      await _useLook(kind, k);
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
                      Future.microtask(() => _buy(kind, k));
                      return true;
                    },
            ),
        ],
      );
    },
  );

  Widget _lookCard(String kind, String k, bool on, bool free, bool owned, num price, bool ro, C c, List<String> all) {
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openLooks(kind, all, k),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: on ? c.good : c.line, width: on ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IgnorePointer(
                child: Container(
                  height: kind == 'qr' ? 230 : null,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(12)),
                  child: _lookPicture(kind, k),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _lookName(kind, k),
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

class _How extends StatelessWidget {
  final RestCtx ctx;
  const _How({required this.ctx});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(ctx.to('howTitle'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final (i, x) in ctx.t.list('to.how').indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.active, shape: BoxShape.circle),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(fontWeight: FontWeight.w800, color: c.brandInk, fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(x, style: const TextStyle(height: 1.4))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
