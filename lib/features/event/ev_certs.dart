import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/look_sheet.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show GoldBtn, MHead;
import '../restaurant/rest_common.dart' show Segmented, SwitchRow;
import '../restaurant/rest_online.dart' show shareWidgets;
import 'ev_common.dart';
import 'ev_looks.dart';

// Certificates & attendance (the web's EvCerts.jsx): who came, and a certificate for each of them (ev_certs).
//   GET /events/:eid/attendance · PUT /events/:eid { cert } · POST|DELETE /events/:eid/cert-signature · POST /events/:eid/certs/send
const _def = {
  'on': false,
  'who': 'checked_in',
  'title': 'Certificate of Attendance',
  'body': 'This is to certify that {name} attended {event} on {date}.',
  'signer': '',
  'signer_title': '',
  'design': 'classic',
};

class CertsTab extends StatefulWidget {
  final EvCtx ctx;
  const CertsTab({super.key, required this.ctx});
  @override
  State<CertsTab> createState() => _CertsTabState();
}

class _CertsTabState extends State<CertsTab> {
  EvCtx get ctx => widget.ctx;
  late String _event = ctx.firstEvent();
  Json? _att;
  String _filter = 'all', _style = 'all';
  final _q = TextEditingController();
  final _title = TextEditingController(), _body = TextEditingController(), _signer = TextEditingController(), _signerTitle = TextEditingController();
  bool _on = false;
  String _who = 'checked_in', _design = 'classic', _look = 'classic';
  String _busy = '';
  int _shown = 24;

  Json? get _ev => ctx.eventById(_event);
  Json get _cert => {..._def, ...obj(_ev?['cert'])};
  List<String> get _owned => [...certFree, for (final x in (obj(ctx.data['cert_themes'])['owned'] as List? ?? const [])) '$x'];
  bool _has(String k) => isFreeCert(k) || _owned.contains(k);
  num get _price => n(obj(ctx.data['cert_themes'])['price']);

  @override
  void initState() {
    super.initState();
    _fill();
    _load();
  }

  @override
  void dispose() {
    for (final x in [_q, _title, _body, _signer, _signerTitle]) {
      x.dispose();
    }
    super.dispose();
  }

  void _fill() {
    final c = _cert;
    _on = c['on'] == true;
    _who = str(c['who']).isEmpty ? 'checked_in' : str(c['who']);
    _title.text = str(c['title']);
    _body.text = str(c['body']);
    _signer.text = str(c['signer']);
    _signerTitle.text = str(c['signer_title']);
    _design = str(c['design']).isEmpty ? 'classic' : str(c['design']);
    _look = _design;
  }

  Json get _form => {'on': _on, 'who': _who, 'title': _title.text.trim(), 'body': _body.text, 'signer': _signer.text.trim(), 'signer_title': _signerTitle.text.trim(), 'design': _design};
  bool get _dirty {
    final c = _cert;
    final f = _form;
    return f.entries.any((e) => '${e.value}' != '${c[e.key] ?? ''}');
  }

  Future<void> _load() async {
    if (_event.isEmpty) return;
    try {
      final r = await ctx.api.get('${ctx.base}/events/$_event/attendance');
      if (mounted) setState(() => _att = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<Json?> _run(String k, Future<Json> Function() fn, [String? ok]) async {
    setState(() => _busy = k);
    final r = await ctx.run(fn, ok ?? ctx.m('saved'));
    if (r != null) await ctx.reload();
    if (mounted) setState(() => _busy = '');
    return r;
  }

  Future<void> _save() async {
    final r = await _run('save', () => ctx.api.put('${ctx.base}/events/$_event', {'cert': _form}));
    if (r != null && mounted) setState(_fill);
  }

  Future<void> _sign() async {
    final png = await showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SignSheet(ctx: ctx),
    );
    if (png == null) return;
    await _run(
      'sign',
      () =>
          ctx.api.post('${ctx.base}/events/$_event/cert-signature', FormData.fromMap({'file': MultipartFile.fromBytes(png, filename: 'signature.png', contentType: DioMediaType.parse('image/png'))})),
    );
  }

  // tap a design → the design sheet (big certificate, swipe for the next), Use / Buy at the bottom
  Future<void> _openDesign(List<String> list, String k, String sig, Json? sample) async {
    String m(String key, [Map<String, Object?> v = const {}]) => ctx.m('certs.$key', v);
    final ev = _ev!;
    await showLookSheet(
      context,
      title: m('gallery', {'n': certAll.length}),
      count: list.length,
      initial: list.contains(k) ? list.indexOf(k) : 0,
      item: (context, i, refresh) {
        final x = list[i];
        final inUse = x == str(_cert['design']);
        return LookItem(
          name: certName(x, ctx.lang),
          badge: inUse ? m('inUse') : (_has(x) ? (isFreeCert(x) ? m('free') : m('owned')) : '${fmt(_price)} ${ctx.m('coins')}'),
          badgeTone: inUse || _has(x) ? Tone.good : Tone.warn,
          preview: SizedBox(
            width: 560,
            child: EvCertView(cert: {..._form, 'design': x, 'signature': sig}, name: str(sample?['holder']).isEmpty ? m('sampleName') : str(sample?['holder']), ev: ev, org: ctx.org, code: str(sample?['code']).isEmpty ? 'AB12CD34' : str(sample?['code']), sponsors: objs(ev['sponsors'])),
          ),
          acts: [
            if (!inUse && _has(x))
              LookAct(
                ctx.m('design.use'),
                icon: LucideIcons.check,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        _design = x;
                        _look = x;
                        final r = await ctx.run(() => ctx.api.put('${ctx.base}/events/$_event', {'cert': _form}), ctx.m('saved'));
                        if (r == null) return false;
                        await ctx.reload();
                        if (mounted) setState(_fill);
                        return true;
                      },
              ),
            if (!_has(x))
              LookAct(
                m('buyDesign', {'coins': fmt(_price)}),
                gold: true,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        ctx.askBuy('theme', item: 'cert|$x|$_event');
                        return true;
                      },
              ),
          ],
        );
      },
    );
  }

  void _openCert(Json r) {
    final ev = _ev!;
    final key = GlobalKey();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (s) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                str(r['holder']).isEmpty ? ctx.m('certs.noName') : str(r['holder']),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 12),
              RepaintBoundary(
                key: key,
                child: EvCertView(
                  cert: {..._cert, 'signature': obj(ev['cert'])['signature'] ?? ''},
                  name: str(r['holder']),
                  ev: ev,
                  org: ctx.org,
                  code: str(r['code']),
                  sponsors: objs(ev['sponsors']),
                ),
              ),
              const SizedBox(height: 14),
              Btn(ctx.p('certImage'), icon: LucideIcons.share2, expand: true, onTap: () => shareWidgets([key], (_) => 'certificate-${r['code']}.png')),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    String m(String k, [Map<String, Object?> v = const {}]) => ctx.m('certs.$k', v);
    final ev = _ev;
    final rows = objs(_att?['rows']);
    final q = _q.text.trim().toLowerCase();
    final list = rows
        .where(
          (r) =>
              (_filter == 'all' || (_filter == 'in' ? r['status'] == 'used' : r['status'] != 'used')) &&
              (q.isEmpty || [r['holder'], r['code'], r['order_no'], r['phone'], r['type_name']].any((v) => str(v).toLowerCase().contains(q))),
        )
        .toList();
    final total = n(_att?['total']), used = n(_att?['used']);
    final tg = rows.where((r) => r['tg'] == true).length;
    final sample = rows.where((r) => r['status'] == 'used').firstOrNull ?? rows.firstOrNull;
    final sig = str(obj(ev?['cert'])['signature']);
    final designs = certAll.where((k) => _style == 'all' || (_style == 'free' ? isFreeCert(k) : (_style == 'mine' ? _has(k) : k.startsWith('$_style-')))).toList();
    final certOn = obj(ev?['cert'])['on'] == true;
    return EvList(
      onRefresh: () async {
        await ctx.reload();
        await _load();
      },
      children: [
        Panel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MHead(m('title'), sub: m('sub'), icon: LucideIcons.award),
              EvEventPick(
                ctx: ctx,
                value: _event,
                onChanged: (v) => setState(() {
                  _event = v;
                  _att = null;
                  _fill();
                  _load();
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (ev == null)
          Panel(child: Muted(m('noEvent'), align: TextAlign.center))
        else ...[
          // ---------- attendance
          EvStats([
            EvStat(m('guests'), _att == null ? '…' : fmt(total)),
            EvStat(m('came'), _att == null ? '…' : fmt(used), tone: Tone.good),
            EvStat(m('notCame'), _att == null ? '…' : fmt(total - used), tone: Tone.warn),
            EvStat(m('rate'), total > 0 ? '${(used / total * 100).round()}%' : '0%'),
          ]),
          const SizedBox(height: 12),
          // ---------- certificates
          Panel(
            padding: const EdgeInsets.all(16),
            child: EvLocked(
              ctx: ctx,
              addon: 'ev_certs',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchRow(title: m('certs'), sub: m('auto'), value: _on, onChanged: ctx.readOnly ? null : (v) => setState(() => _on = v)),
                  const SizedBox(height: 6),
                  Segmented<String>(value: _who, options: [('checked_in', m('who.checked_in')), ('all', m('who.all'))], onChanged: ctx.readOnly ? null : (v) => setState(() => _who = v)),
                  const SizedBox(height: 14),
                  Field(label: m('ctitle'), controller: _title, maxLength: 80, onChanged: (_) => setState(() {})),
                  const SizedBox(height: 12),
                  Field(label: m('body'), controller: _body, maxLength: 400, maxLines: 3, onChanged: (_) => setState(() {})),
                  Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Muted(m('bodyHint'))),
                  const SizedBox(height: 12),
                  Field(label: m('signer'), controller: _signer, maxLength: 60, onChanged: (_) => setState(() {})),
                  const SizedBox(height: 12),
                  Field(label: m('signerTitle'), controller: _signerTitle, hint: 'Director', maxLength: 60, onChanged: (_) => setState(() {})),
                  const SizedBox(height: 14),
                  // the signature
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.bg2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.line),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 96,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: c.line),
                          ),
                          child: sig.isNotEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Image(image: netImage(sig), fit: BoxFit.contain),
                                )
                              : Icon(LucideIcons.penLine, color: c.muted),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(sig.isNotEmpty ? m('signHas') : m('signNone'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                        if (sig.isNotEmpty)
                          IconButton(
                            tooltip: ctx.m('remove'),
                            onPressed: ctx.readOnly || _busy.isNotEmpty ? null : () => _run('unsign', () => ctx.api.delete('${ctx.base}/events/$_event/cert-signature')),
                            icon: Icon(LucideIcons.trash2, size: 17, color: c.danger),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Btn(
                      sig.isNotEmpty ? m('signChange') : m('signAdd'),
                      icon: LucideIcons.penLine,
                      kind: BtnKind.ghost,
                      small: true,
                      busy: _busy == 'sign',
                      onTap: ctx.readOnly || _busy.isNotEmpty ? null : _sign,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // the preview
                  Text('${ctx.m('design.preview')} · ${certName(_look, ctx.lang)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: DecoratedBox(
                      decoration: BoxDecoration(boxShadow: c.cardShadow),
                      child: EvCertView(
                        cert: {..._form, 'design': _look, 'signature': sig},
                        name: str(sample?['holder']).isEmpty ? m('sampleName') : str(sample?['holder']),
                        ev: ev,
                        org: ctx.org,
                        code: str(sample?['code']).isEmpty ? 'AB12CD34' : str(sample?['code']),
                        sponsors: objs(ev['sponsors']),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!_has(_look))
                    Center(
                      child: GoldBtn(m('buyDesign', {'coins': fmt(_price)}), onTap: ctx.readOnly ? null : () => ctx.askBuy('theme', item: 'cert|$_look|$_event')),
                    )
                  else if (_look == _design)
                    Center(
                      child: Chip2(_dirty && _look != str(_cert['design']) ? m('pickedSave') : m('inUse'), icon: LucideIcons.circleCheck, tone: Tone.good),
                    ),
                  const SizedBox(height: 14),
                  Btn(ctx.m('save'), icon: LucideIcons.save, expand: true, busy: _busy == 'save', onTap: ctx.readOnly || !_dirty || _busy.isNotEmpty ? null : _save),
                  if (certOn) ...[
                    const SizedBox(height: 8),
                    Btn(
                      m('send'),
                      icon: LucideIcons.send,
                      kind: BtnKind.ghost,
                      expand: true,
                      busy: _busy == 'send',
                      onTap: ctx.readOnly || _dirty || _busy.isNotEmpty
                          ? null
                          : () async {
                              if (!await askSure(context, m('sendSure', {'n': tg}), ok: m('send'), cancel: ctx.m('cancel'))) return;
                              final r = await _run('send', () => ctx.api.post('${ctx.base}/events/$_event/certs/send'), '');
                              if (r != null) ctx.notify(m('sent', {'n': n(r['sent'])}));
                            },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ---------- the gallery
          if (ctx.on('ev_certs'))
            Panel(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MHead(m('gallery', {'n': certAll.length}), sub: m('gallerySub', {'coins': fmt(_price)}), icon: LucideIcons.layoutGrid),
                  EvChips(
                    items: [
                      ('all', m('all'), certAll.length),
                      ('free', m('free'), certFree.length),
                      ('mine', m('mine'), certAll.where(_has).length),
                      for (final l in certLayouts) (l.$1, certLayoutLabel(l.$1, ctx.lang), null),
                    ],
                    value: _style,
                    onPick: (v) => setState(() {
                      _style = v;
                      _shown = 24;
                    }),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, box) {
                      final cols = box.maxWidth >= 600 ? 3 : 2;
                      final w = (box.maxWidth - 10 * (cols - 1)) / cols;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 12,
                        children: [
                          for (final k in designs.take(_shown))
                            SizedBox(
                              width: w,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => _openDesign(designs, k, sig, sample),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: _look == k ? c.brand : c.line, width: _look == k ? 2 : 1),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: EvCertView(
                                        thumb: true,
                                        cert: {..._form, 'design': k, 'signature': sig},
                                        name: str(sample?['holder']).isEmpty ? m('sampleName') : str(sample?['holder']),
                                        ev: ev,
                                        org: ctx.org,
                                        code: 'AB12CD34',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      certName(k, ctx.lang),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                    ),
                                    _design == k
                                        ? Row(
                                            children: [
                                              Icon(LucideIcons.check, size: 12, color: c.good),
                                              const SizedBox(width: 3),
                                              Text(
                                                m('inUse'),
                                                style: TextStyle(color: c.good, fontSize: 11, fontWeight: FontWeight.w700),
                                              ),
                                            ],
                                          )
                                        : _has(k)
                                        ? Text(
                                            isFreeCert(k) ? m('free') : m('owned'),
                                            style: TextStyle(color: c.good, fontSize: 11, fontWeight: FontWeight.w700),
                                          )
                                        : Row(
                                            children: [
                                              Icon(LucideIcons.lock, size: 11, color: c.muted),
                                              const SizedBox(width: 3),
                                              const CoinIcon(size: 11),
                                              const SizedBox(width: 3),
                                              Text(
                                                fmt(_price),
                                                style: TextStyle(color: c.muted, fontSize: 11, fontWeight: FontWeight.w700),
                                              ),
                                            ],
                                          ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  if (designs.length > _shown)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Center(
                        child: Btn(ctx.m('evl.more', {'n': designs.length - _shown}), kind: BtnKind.ghost, small: true, onTap: () => setState(() => _shown += 24)),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          // ---------- who came
          Field(controller: _q, hint: m('search'), icon: LucideIcons.search, onChanged: (_) => setState(() {})),
          const SizedBox(height: 10),
          EvChips(
            items: [
              for (final k in ['all', 'in', 'out']) (k, m('f.$k'), null),
            ],
            value: _filter,
            onPick: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: 10),
          if (_att == null)
            const SkelList(rows: 5)
          else if (list.isEmpty)
            Panel(child: Muted(m('empty'), align: TextAlign.center))
          else
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [
                  for (final r in list.take(300))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(r['status'] == 'used' ? LucideIcons.userCheck : LucideIcons.userX, color: r['status'] == 'used' ? c.good : c.muted),
                      title: Text(str(r['holder']).isEmpty ? m('noName') : str(r['holder']), style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${r['type_name']} · #${r['order_no']}${str(r['seat_label']).isNotEmpty ? ' · ${r['seat_label']}' : ''}${str(r['phone']).isNotEmpty ? ' · ${r['phone']}' : ''}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            r['status'] == 'used' ? '${evTime(r['used_at'])}${str(r['used_by']).isNotEmpty ? ' · ${r['used_by']}' : ''}' : m('notYet'),
                            style: TextStyle(fontSize: 12, color: c.muted),
                          ),
                          if (certOn && (_cert['who'] == 'all' || r['status'] == 'used'))
                            IconButton(
                              tooltip: m('open'),
                              onPressed: () => _openCert(r),
                              icon: Icon(LucideIcons.award, size: 17, color: c.brand),
                            ),
                        ],
                      ),
                    ),
                  if (list.length > 300) Padding(padding: const EdgeInsets.all(8), child: Muted(m('more', {'n': list.length - 300}))),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- sign on screen, or a picture of a signature → PNG
class _SignSheet extends StatefulWidget {
  final EvCtx ctx;
  const _SignSheet({required this.ctx});
  @override
  State<_SignSheet> createState() => _SignSheetState();
}

class _SignSheetState extends State<_SignSheet> {
  static const _inks = [Color(0xFF111827), Color(0xFF1E3A8A), Color(0xFF0F766E)];
  String _tab = 'draw';
  Color _ink = _inks.first;
  final List<(Color, List<Offset>)> _lines = [];
  Uint8List? _file;
  bool _busy = false;
  Size _pad = Size.zero;

  EvCtx get ctx => widget.ctx;
  String m(String k) => ctx.m('certs.$k');

  // the drawing as a PNG, cut to the strokes
  Future<Uint8List?> _drawn() async {
    final pts = [for (final l in _lines) ...l.$2];
    if (pts.isEmpty) return null;
    var x0 = pts.first.dx, y0 = pts.first.dy, x1 = x0, y1 = y0;
    for (final p in pts) {
      if (p.dx < x0) x0 = p.dx;
      if (p.dy < y0) y0 = p.dy;
      if (p.dx > x1) x1 = p.dx;
      if (p.dy > y1) y1 = p.dy;
    }
    const pad = 8.0, scale = 3.0;
    final rect = Rect.fromLTRB(x0 - pad, y0 - pad, x1 + pad, y1 + pad);
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.scale(scale);
    canvas.translate(-rect.left, -rect.top);
    _SignPainter(_lines).paint(canvas, _pad);
    final img = await rec.endRecording().toImage((rect.width * scale).ceil(), (rect.height * scale).ceil());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _pick() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 92);
    if (f == null) return;
    final b = await f.readAsBytes();
    setState(() => _file = b);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final has = _tab == 'draw' ? _lines.isNotEmpty : _file != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(m('signTitle'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Segmented<String>(value: _tab, options: [('draw', m('signDraw')), ('upload', m('signUpload'))], onChanged: (v) => setState(() => _tab = v)),
            const SizedBox(height: 12),
            if (_tab == 'draw') ...[
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: LayoutBuilder(
                  builder: (_, box) {
                    _pad = Size(box.maxWidth, box.maxHeight);
                    return GestureDetector(
                      onPanStart: (d) => setState(() => _lines.add((_ink, [d.localPosition]))),
                      onPanUpdate: (d) => setState(() => _lines.last.$2.add(d.localPosition)),
                      child: Stack(
                        children: [
                          Positioned(left: 24, right: 24, bottom: 46, child: Container(height: 1, color: const Color(0xFFD1D5DB))),
                          if (_lines.isEmpty)
                            Center(
                              child: Text(m('signHere'), style: const TextStyle(color: Color(0xFF9CA3AF))),
                            ),
                          Positioned.fill(child: CustomPaint(painter: _SignPainter(_lines))),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final ink in _inks)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _ink = ink),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: ink,
                            shape: BoxShape.circle,
                            border: Border.all(color: _ink == ink ? c.brand : Colors.transparent, width: 3),
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  TextButton.icon(onPressed: _lines.isEmpty ? null : () => setState(_lines.clear), icon: const Icon(LucideIcons.eraser, size: 16), label: Text(m('signClear'))),
                ],
              ),
            ] else ...[
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _pick,
                child: Container(
                  height: 170,
                  decoration: BoxDecoration(
                    color: c.bg2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.line),
                  ),
                  child: _file != null
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: Image.memory(_file!, fit: BoxFit.contain),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.upload, size: 26, color: c.muted),
                            const SizedBox(height: 6),
                            Text(m('signPick')),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Muted(m('signTip')),
            ],
            const SizedBox(height: 14),
            Btn(
              m('signSave'),
              icon: LucideIcons.penLine,
              expand: true,
              busy: _busy,
              onTap: !has || _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final nav = Navigator.of(context);
                      final png = _tab == 'draw' ? await _drawn() : _file;
                      if (mounted) nav.pop(png);
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _SignPainter extends CustomPainter {
  final List<(Color, List<Offset>)> lines;
  const _SignPainter(this.lines);
  @override
  void paint(Canvas canvas, Size size) {
    for (final (col, pts) in lines) {
      final p = Paint()
        ..color = col
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (pts.length == 1) {
        canvas.drawCircle(pts.first, 1.6, p..style = PaintingStyle.fill);
        continue;
      }
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        final a = pts[i - 1], b = pts[i];
        path.quadraticBezierTo(a.dx, a.dy, (a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      }
      path.lineTo(pts.last.dx, pts.last.dy);
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_SignPainter o) => true;
}
