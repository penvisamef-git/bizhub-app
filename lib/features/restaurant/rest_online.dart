import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'rest_common.dart';
import 'rest_reports.dart' show whenShort;
import 'rest_stickers.dart';

// QR menu (QrTab.jsx), Inbox (InboxTab.jsx) and App (AppTab.jsx).

// a QR as a PNG, shared with the phone's share sheet
Future<void> shareQr(String data, String fileName, {String? text}) async {
  final painter = QrPainter(
    data: data,
    version: QrVersions.auto,
    gapless: true,
    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF16171B)),
    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF16171B)),
  );
  final img = await painter.toImage(600);
  // white border around the code
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 680, 680), Paint()..color = Colors.white);
  canvas.drawImage(img, const Offset(40, 40), Paint());
  final out = await rec.endRecording().toImage(680, 680);
  final bytes = await out.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) return;
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes.buffer.asUint8List(), mimeType: 'image/png', name: fileName)],
      text: text,
    ),
  );
}

// pictures of on-screen widgets (by their RepaintBoundary keys), shared together
Future<void> shareWidgets(List<GlobalKey> keys, String Function(int i) name) async {
  final files = <XFile>[];
  for (final (i, k) in keys.indexed) {
    final box = k.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (box == null) continue;
    final img = await box.toImage(pixelRatio: 3);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data != null) files.add(XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png', name: name(i)));
  }
  if (files.isNotEmpty) await SharePlus.instance.share(ShareParams(files: files));
}

class _QrBox extends StatelessWidget {
  final String data;
  final double size;
  const _QrBox(this.data, {this.size = 170});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.c.line),
    ),
    child: QrImageView(
      data: data,
      size: size,
      padding: EdgeInsets.zero,
      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF16171B)),
      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF16171B)),
    ),
  );
}

class _LinkRow extends StatelessWidget {
  final RestCtx ctx;
  final String link;
  const _LinkRow({required this.ctx, required this.link});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Clipboard.setData(ClipboardData(text: link));
        ctx.notify(ctx.r('copied'));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Expanded(
              child: Text(
                link,
                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.copy, size: 16, color: c.muted),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------- QR menu
class QrMenuSection extends StatefulWidget {
  final RestCtx ctx;
  const QrMenuSection({super.key, required this.ctx});
  @override
  State<QrMenuSection> createState() => _QrMenuSectionState();
}

class _QrMenuSectionState extends State<QrMenuSection> {
  List<Json>? _zones, _tables, _cats, _items;
  String _zone = '', _target = 'menu';
  final Set<String> _picked = {};
  RestCtx get ctx => widget.ctx;
  bool get _on => ctx.addonOn('rest_qr_menu');
  String get _base => '${Config.siteUrl}/public/menu/${str(ctx.settings['menu_token'])}';

  @override
  void initState() {
    super.initState();
    if (_on) _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([
        for (final k in ['zones', 'tables', 'categories', 'items']) ctx.api.get('${ctx.base}/$k'),
      ]);
      List<Json> act(Json x) => objs(x['data']).where((e) => e['active'] != false).toList();
      if (mounted) {
        setState(() {
          _zones = objs(r[0]['data']);
          _tables = act(r[1]);
          _cats = act(r[2]);
          _items = act(r[3]);
        });
      }
    } catch (e) {
      ctx.fail(e);
    }
  }

  String get _link => _target == 'menu' ? _base : (_target.startsWith('c:') ? '$_base?c=${_target.substring(2)}' : '$_base?i=${_target.substring(2)}');

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (!_on) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Panel(
            child: Column(
              children: [
                Container(
                  width: 150,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: c.ink, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Text('A1', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26)),
                      const Icon(LucideIcons.qrCode, size: 64),
                      const SizedBox(height: 6),
                      Text(ctx.r('scanToOrder'), style: TextStyle(fontSize: 11, color: c.muted)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                RestHead(ctx.r('addonNames.rest_qr_menu'), sub: ctx.r('qrSub')),
              ],
            ),
          ),
          gap14,
          AddonPrompt(ctx: ctx, addonKey: 'rest_qr_menu'),
        ],
      );
    }
    final tablesAll = _tables;
    if (tablesAll == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 3));
    final tables = tablesAll.where((t) => _zone.isEmpty || str(t['zone_id']) == _zone).toList();
    final toPrint = tables.where((t) => _picked.contains(str(t['_id']))).toList();
    final allPicked = tables.isNotEmpty && toPrint.length == tables.length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RestHead(ctx.r('menuLink'), sub: ctx.r('qrSub')),
                Center(child: _QrBox(_base)),
                const SizedBox(height: 12),
                _LinkRow(ctx: ctx, link: _base),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Btn(
                      ctx.r('openMenu'),
                      icon: LucideIcons.externalLink,
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: () => launchUrl(Uri.parse(_base), mode: LaunchMode.externalApplication),
                    ),
                    Btn(
                      ctx.r('downloadQr'),
                      icon: LucideIcons.share2,
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: () => shareQr(_base, 'menu-qr.png', text: _base),
                    ),
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
                RestHead(ctx.r('tableStickers'), sub: ctx.r('tableStickersHint')),
                if (tablesAll.isEmpty)
                  Muted(ctx.r('noTablesForQr'))
                else ...[
                  if (_zones!.isNotEmpty) ...[
                    SelectField<String>(value: _zone, options: [('', ctx.r('allZones')), for (final z in _zones!) (str(z['_id']), str(z['name']))], onChanged: (v) => setState(() => _zone = v)),
                    const SizedBox(height: 10),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in tables)
                        FilterChip(
                          avatar: const Icon(LucideIcons.qrCode, size: 15),
                          label: Text(str(t['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                          selected: _picked.contains(str(t['_id'])),
                          showCheckmark: false,
                          onSelected: (on) => setState(() => on ? _picked.add(str(t['_id'])) : _picked.remove(str(t['_id']))),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Btn(
                        allPicked ? ctx.r('clearPick') : ctx.r('pickAll'),
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
                          toPrint.isEmpty ? ctx.r('pickFirst') : ctx.r('printN', {'n': toPrint.length}),
                          icon: LucideIcons.printer,
                          small: true,
                          onTap: toPrint.isEmpty ? null : () => _stickers(toPrint),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          gap14,
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RestHead(ctx.r('menuQr'), sub: ctx.r('menuQrHint')),
                SelectField<String>(
                  label: ctx.r('qrTarget'),
                  value: _target,
                  options: [
                    ('menu', ctx.r('wholeMenu')),
                    for (final x in _cats!) ('c:${x['_id']}', '${ctx.r('categories')} · ${nameOf(x, ctx.lang)}'),
                    for (final x in _items!) ('i:${x['_id']}', '${ctx.r('items')} · ${nameOf(x, ctx.lang)}'),
                  ],
                  onChanged: (v) => setState(() => _target = v),
                ),
                const SizedBox(height: 14),
                Center(child: _QrBox(_link, size: 150)),
                const SizedBox(height: 10),
                _LinkRow(ctx: ctx, link: _link),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Btn(ctx.r('downloadQr'), icon: LucideIcons.download, kind: BtnKind.ghost, small: true, onTap: () => shareQr(_link, 'menu-qr-${_target.replaceAll(':', '-')}.png')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // the chosen tables' stickers, shared as pictures (print them from the phone or send to a computer)
  void _stickers(List<Json> tables) {
    final s = ctx.settings;
    final shop = str(s['name_km']).isNotEmpty ? str(s['name_km']) : str(s['name_en']);
    final color = _hex(str(s['color'])) ?? const Color(0xFFE0581A);
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
                  child: Text(ctx.r('printN', {'n': tables.length}), style: Theme.of(sheet).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
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
                  for (final (i, t) in tables.indexed)
                    RepaintBoundary(
                      key: keys[i],
                      child: QrSticker(
                        theme: str(s['qr_theme']).isEmpty ? 'classic' : str(s['qr_theme']),
                        color: color,
                        logo: str(obj(s['logo'])['url']),
                        shop: shop,
                        table: str(t['name']),
                        data: '$_base?t=${Uri.encodeComponent(str(t['name']))}',
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

Color? _hex(String h) {
  final v = int.tryParse(h.replaceFirst('#', ''), radix: 16);
  return h.isEmpty || v == null ? null : Color(0xFF000000 | v);
}

// ------------------------------------------------------------------------------------------- Inbox
class InboxSection extends StatefulWidget {
  final RestCtx ctx;
  const InboxSection({super.key, required this.ctx});
  @override
  State<InboxSection> createState() => _InboxSectionState();
}

class _InboxSectionState extends State<InboxSection> {
  List<Json>? _list;
  int _page = 1, _pages = 1, _unread = 0;
  bool _unreadOnly = false, _busy = false;
  String _open = '';
  RestCtx get ctx => widget.ctx;
  String ib(String k, [Map<String, Object?> v = const {}]) => ctx.t('inbox.$k', v);

  @override
  void initState() {
    super.initState();
    _unread = n(ctx.overview['inbox_unread']).toInt();
    _load();
  }

  void _setUnread(Object? v) {
    _unread = n(v).toInt();
    ctx.setUnread?.call(_unread);
  }

  Future<void> _load([int p = 1, bool append = false]) async {
    try {
      final r = await ctx.api.get('${ctx.base}/site/messages', {'page': p, if (_unreadOnly) 'unread': 1});
      if (!mounted) return;
      final pg = obj(r['pagination']);
      setState(() {
        _list = append ? [...?_list, ...objs(r['data'])] : objs(r['data']);
        _page = n(pg['currentPage']).toInt();
        _pages = n(pg['totalPages']).toInt();
        _setUnread(r['unread']);
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _act(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggle(Json m) {
    setState(() => _open = _open == str(m['_id']) ? '' : str(m['_id']));
    if (m['read'] != true && !ctx.readOnly) {
      ctx.api.put('${ctx.base}/site/messages/${m['_id']}', {'read': true}).then((r) {
        if (mounted) {
          setState(() {
            m['read'] = true;
            _setUnread(r['unread']);
          });
        }
      }, onError: (_) {});
    }
  }

  String _when(Object? d) {
    final t = DateTime.tryParse(str(d));
    if (t == null) return '';
    final m = DateTime.now().difference(t).inMinutes;
    if (m < 1) return ib('justNow');
    if (m < 60) return ib('minAgo', {'n': m});
    if (m < 1440) return ib('hourAgo', {'n': (m / 60).round()});
    return whenShort(d, ctx.lang);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final list = _list;
    if (list == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 4));
    final on = ctx.addonOn('rest_website');
    final ro = ctx.readOnly;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RestHead(ib('title'), sub: _unread > 0 ? ib('unreadCount', {'n': _unread}) : ib('allRead')),
                Segmented<bool>(
                  value: _unreadOnly,
                  options: [(false, ib('all')), (true, _unread > 0 ? '${ib('unread')} · $_unread' : ib('unread'))],
                  onChanged: (v) {
                    setState(() => _unreadOnly = v);
                    _load();
                  },
                ),
                if (_unread > 0) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Btn(
                      ib('markAll'),
                      icon: LucideIcons.checkCheck,
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: _busy || ro
                          ? null
                          : () => _act(() async {
                              await ctx.api.post('${ctx.base}/site/messages/read-all');
                              setState(() {
                                _list = _unreadOnly
                                    ? []
                                    : [
                                        for (final x in list) {...x, 'read': true},
                                      ];
                                _setUnread(0);
                              });
                            }),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Muted('${ib('sub')}${ctx.addonOn('rest_telegram') ? ' ${ib('alsoTelegram')}' : ''}'),
              ],
            ),
          ),
          gap14,
          if (!on) ...[AddonPrompt(ctx: ctx, addonKey: 'rest_website', sub: ib('needWebsite')), gap14],
          if (list.isEmpty)
            Panel(
              child: Column(
                children: [
                  Icon(LucideIcons.inbox, size: 30, color: c.muted),
                  const SizedBox(height: 10),
                  Muted(_unreadOnly ? ib('noUnread') : ib('empty'), align: TextAlign.center),
                  if (on && !_unreadOnly) ...[const SizedBox(height: 10), Btn(ib('openWebsite'), kind: BtnKind.ghost, small: true, onTap: () => ctx.go('website'))],
                ],
              ),
            ),
          for (final m in list) ...[_item(m, c, ro), const SizedBox(height: 10)],
          if (_page < _pages)
            Center(
              child: Btn(ib('more'), kind: BtnKind.ghost, small: true, busy: _busy, onTap: _busy ? null : () => _act(() => _load(_page + 1, true))),
            ),
        ],
      ),
    );
  }

  Widget _item(Json m, C c, bool ro) {
    final kind = str(m['kind']).isEmpty ? 'other' : str(m['kind']);
    final icon = switch (kind) {
      'feedback' => LucideIcons.messageSquare,
      'request' => LucideIcons.notebookPen,
      'booking' => LucideIcons.calendarDays,
      _ => LucideIcons.mail,
    };
    final open = _open == str(m['_id']);
    final unread = m['read'] != true;
    final contact = str(m['contact']);
    final email = contact.contains('@');
    return Panel(
      padding: EdgeInsets.zero,
      color: unread ? Color.alphaBlend(c.brand.withValues(alpha: .05), c.card) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _toggle(m),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, size: 17, color: c.brandInk),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                str(m['name']),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Chip2(ib('kinds.$kind')),
                            const Spacer(),
                            Text(_when(m['created_date']), style: TextStyle(color: c.muted, fontSize: 11.5)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          str(m['message']),
                          maxLines: open ? null : 2,
                          overflow: open ? null : TextOverflow.ellipsis,
                          style: TextStyle(color: open ? c.ink : c.muted, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  if (unread) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Btn(
                    '${email ? ib('replyEmail') : ib('call')} · $contact',
                    icon: email ? LucideIcons.mail : LucideIcons.phone,
                    small: true,
                    onTap: () => launchUrl(Uri.parse(email ? 'mailto:$contact' : 'tel:${contact.replaceAll(RegExp(r'[^\d+]'), '')}')),
                  ),
                  Btn(
                    ib('markUnread'),
                    icon: LucideIcons.mailOpen,
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: _busy || ro
                        ? null
                        : () => _act(() async {
                            final r = await ctx.api.put('${ctx.base}/site/messages/${m['_id']}', {'read': false});
                            setState(() {
                              m['read'] = false;
                              _open = '';
                              _setUnread(r['unread']);
                            });
                          }),
                  ),
                  Btn(
                    ib('delete'),
                    icon: LucideIcons.trash2,
                    kind: BtnKind.danger,
                    small: true,
                    onTap: _busy || ro
                        ? null
                        : () => _act(() async {
                            final r = await ctx.api.delete('${ctx.base}/site/messages/${m['_id']}');
                            setState(() {
                              _list!.remove(m);
                              _setUnread(r['unread']);
                            });
                          }),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------- App (coming soon)
class AppSection extends StatelessWidget {
  final RestCtx ctx;
  const AppSection({super.key, required this.ctx});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    String a(String k, [Map<String, Object?> v = const {}]) => ctx.t('apptab.$k', v);
    final price = ctx.addon('rest_app')['price'] ?? 120;
    final features = [(LucideIcons.receiptText, a('f1')), (LucideIcons.layers, a('f2')), (LucideIcons.wifiOff, a('f3')), (LucideIcons.smartphone, a('f4')), (LucideIcons.bellRing, a('f5'))];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Chip2(a('soon'), icon: LucideIcons.clock3),
              const SizedBox(height: 10),
              Text(a('title'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Muted(a('sub')),
              const SizedBox(height: 14),
              for (final (icon, label) in features)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(10)),
                        child: Icon(icon, size: 16, color: c.brandInk),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const CoinIcon(size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(a('price', {'coins': price}), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  Btn(a('soon'), small: true),
                ],
              ),
              const SizedBox(height: 8),
              Muted(a('note')),
            ],
          ),
        ),
      ],
    );
  }
}
