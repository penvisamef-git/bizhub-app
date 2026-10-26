import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../owner/data.dart' show coinsChanged;
import '../../widgets/pay.dart';
import '../../widgets/color_pick.dart';
import '../../widgets/look_sheet.dart';
import '../../widgets/ui.dart';
import '../attendance/at_setup.dart' show TimeField;
import '../mart/mart_common.dart' show GoldBtn, mGap, fileForm;
import '../mart/mart_kit.dart' show DayField, MSheet, showSheet;
import '../restaurant/rest_common.dart' show Segmented, SwitchRow, gap14;
import 'qg_common.dart';
import 'qg_data.dart';
import 'qr_art.dart';

// make / edit one QR code — QgEditor.jsx (the form + the code preview)

const _kinds = ['text', 'textarea', 'select', 'checkbox', 'radio', 'phone', 'email', 'number', 'date', 'photo', 'rating', 'signature'];
const _proKinds = ['photo', 'rating', 'signature'];
const _linkKinds = ['facebook', 'tiktok', 'telegram', 'instagram', 'youtube', 'web', 'shop', 'phone', 'email', 'map', 'whatsapp', 'messenger', 'line', 'linkedin', 'x'];
const _templates = ['card', 'banner', 'minimal'];
const _pageTypes = ['text', 'file', 'form', 'vcard', 'map', 'links', 'coupon'];
const _swatches = ['#E0581A', '#DC2626', '#DB2777', '#9333EA', '#4F46E5', '#0284C7', '#0D9488', '#16A34A', '#CA8A04', '#334155'];

Json _field(String key) => {
  'key': key,
  'label': '',
  'kind': 'text',
  'options': <String>[],
  'required': false,
  'placeholder': '',
  'show_if': {'key': '', 'value': ''},
};

Json _blank(String type, String color) => {
  'name': '',
  'type': type,
  'folder_id': null,
  'active': true,
  'url': '',
  'smart': {'ios': '', 'android': '', 'times': <Json>[]},
  'links': <Json>[
    {'kind': 'facebook', 'label': '', 'url': ''},
  ],
  'coupon': {'title': '', 'offer': '', 'terms': '', 'ends_at': null, 'limit': 0, 'pin': '', 'has_pin': false, 'issued': 0, 'used': 0},
  'text': {'title': '', 'body': ''},
  'file': {'url': '', 'name': '', 'kind': '', 'bytes': 0},
  'form': {
    'title': '',
    'intro': '',
    'button': '',
    'thanks': '',
    'fields': <Json>[
      {..._field('f1'), 'required': true},
    ],
  },
  'vcard': {
    for (final k in ['name', 'org', 'job', 'phone', 'phone2', 'email', 'website', 'address']) k: '',
  },
  'map': {'place': '', 'link': '', 'note': ''},
  'wifi': {'ssid': '', 'password': '', 'security': 'WPA', 'hidden': false},
  'phone': {'number': '', 'body': ''},
  'page': {'template': 'card', 'color': color, 'header': '', 'footer': '', 'rows': <Json>[], 'logo': true},
  'design': {'key': 'plain', 'color': '', 'bg': '', 'accent': '', 'label': '', 'logo': false},
  'notify_scan': false,
  'rules': {'expires_at': null, 'max_scans': 0},
};

// blank + the saved code (one level deep, like the web's merge)
Json _merge(Json b, Json c) {
  final out = jsonDecode(jsonEncode(b)) as Json;
  for (final e in c.entries) {
    if (e.value == null && out[e.key] is Map) continue;
    if (e.value is Map && out[e.key] is Map) {
      out[e.key] = <String, dynamic>{...out[e.key] as Map, ...e.value as Map};
    } else {
      out[e.key] = e.value is Map || e.value is List ? jsonDecode(jsonEncode(e.value)) : e.value;
    }
  }
  (out['coupon'] as Map)['pin'] = '';
  for (final f in objs(obj(out['form'])['fields'])) {
    f['options'] = (f['options'] as List? ?? const []).map((e) => '$e').toList();
    f['show_if'] = <String, dynamic>{'key': '', 'value': '', ...obj(f['show_if'])};
  }
  return out;
}

class CodeEditor extends StatefulWidget {
  final QgCtx ctx;
  final Json start;
  final VoidCallback onClose;
  final void Function(Json row, bool isNew) onSaved;
  const CodeEditor({super.key, required this.ctx, required this.start, required this.onClose, required this.onSaved});
  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  QgCtx get ctx => widget.ctx;
  late final bool isNew = widget.start['_id'] == null;
  late Json _f = _merge(_blank(str(widget.start['type']), str(ctx.settings['color']).isEmpty ? '#E0581A' : str(ctx.settings['color'])), isNew ? {} : widget.start);
  late Json? _code = isNew ? null : widget.start;
  String _busy = '', _err = '';
  final Map<String, TextEditingController> _ctl = {};
  final _pw = TextEditingController();

  String get type => str(_f['type']);
  bool get hasPage => _pageTypes.contains(type);
  Json get draft => {..._f, 'slug': str(_code?['slug']).isEmpty ? 'preview' : _code!['slug']};

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    _pw.dispose();
    super.dispose();
  }

  void _drop(String prefix) => _ctl.removeWhere((k, c) {
    if (!k.startsWith(prefix)) return false;
    c.dispose();
    return true;
  });

  // a text box bound to map[field]
  Widget _in(String key, Json map, String field, String label, {int max = 100, String hint = '', int lines = 1, TextInputType? kb, ValueChanged<String>? onChanged}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Field(
      label: label.isEmpty ? null : label,
      controller: _ctl.putIfAbsent(key, () => TextEditingController(text: str(map[field]) == '0' && field == 'limit' ? '' : str(map[field]))),
      hint: hint,
      maxLength: max,
      maxLines: lines,
      keyboard: kb,
      enabled: !ctx.readOnly,
      onChanged: (v) => setState(() => onChanged != null ? onChanged(v) : map[field] = v),
    ),
  );

  Json _body() {
    final f = _f;
    final b = <String, dynamic>{'name': f['name'], 'folder_id': f['folder_id'], 'active': f['active']};
    if (isNew && _code == null) b['type'] = type;
    if (type == 'url') b['url'] = f['url'];
    final sm = obj(_code?['smart']);
    if (type == 'url' && (ctx.on('qr_smart') || str(sm['ios']).isNotEmpty || str(sm['android']).isNotEmpty || objs(sm['times']).isNotEmpty)) b['smart'] = f['smart'];
    if (type == 'links') b['links'] = objs(f['links']).where((x) => str(x['url']).trim().isNotEmpty).toList();
    if (type == 'coupon') {
      final c = obj(f['coupon']);
      b['coupon'] = {
        'title': c['title'],
        'offer': c['offer'],
        'terms': c['terms'],
        'ends_at': c['ends_at'],
        'limit': n(int.tryParse('${c['limit']}') ?? c['limit']),
        if (str(c['pin']).isNotEmpty) 'pin': c['pin'],
      };
    }
    if (type == 'text') b['text'] = f['text'];
    if (type == 'form') {
      final fm = obj(f['form']);
      b['form'] = {
        ...fm,
        'fields': [
          for (final x in objs(fm['fields'])) {...x, 'options': (x['options'] as List).where((o) => '$o'.isNotEmpty).toList()},
        ],
      };
    }
    if (type == 'vcard') b['vcard'] = f['vcard'];
    if (type == 'map') b['map'] = f['map'];
    if (type == 'wifi') b['wifi'] = f['wifi'];
    if (type == 'phone' || type == 'sms') b['phone'] = f['phone'];
    if (hasPage) b['page'] = f['page'];
    b['design'] = f['design'];
    if (ctx.on('qr_telegram') || _code?['notify_scan'] == true) b['notify_scan'] = f['notify_scan'];
    if (ctx.on('qr_rules')) b['rules'] = {'expires_at': obj(f['rules'])['expires_at'], 'max_scans': n(obj(f['rules'])['max_scans'])};
    return b;
  }

  Future<Json?> _save() async {
    setState(() {
      _busy = 'save';
      _err = '';
    });
    try {
      final was = _code;
      final r = was != null ? await ctx.api.put('${ctx.base}/codes/${was['_id']}', _body()) : await ctx.api.post('${ctx.base}/codes', _body());
      final row = obj(r['data']);
      setState(() {
        _code = row;
        _f = _merge(_f, row);
      });
      widget.onSaved(row, was == null);
      ctx.notify(was != null ? ctx.m('saved') : ctx.m('created'));
      return row;
    } on ApiError catch (e) {
      final code = str(e.body['code']);
      if (code == 'need_addon' && e.body['product'] != null) ctx.askBuy({'addon': str(e.body['product'])});
      if (code == 'not_owned') ctx.askBuy(e.body['product'] == 'qr_theme' ? {'theme': str(e.body['item'])} : {'design': str(e.body['item'])});
      setState(() => _err = e.network ? ctx.t('app.offline') : e.message);
      return null;
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Future<void> _upload() async {
    var row = _code;
    if (row == null) {
      if (str(_f['name']).trim().isEmpty) return setState(() => _err = '${ctx.m('name')}?');
      row = await _save();
      if (row == null) return;
    }
    final pick = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp']);
    if (pick == null) return;
    final bytes = await pick.xFile.readAsBytes();
    setState(() {
      _busy = 'file';
      _err = '';
    });
    try {
      final r = await ctx.api.post('${ctx.base}/codes/${row['_id']}/file', fileForm('file', bytes, pick.xFile.name));
      final saved = obj(r['data']);
      setState(() {
        _code = saved;
        _f['file'] = obj(saved['file']);
      });
      ctx.put((d) => {'files': r['files'] ?? d['files']});
      widget.onSaved(saved, false);
    } on ApiError catch (e) {
      if (e.body['code'] == 'files_full' && mounted) showSheet<void>(context, (_) => BuyFilesSheet(ctx: ctx));
      setState(() => _err = e.message);
    }
    if (mounted) setState(() => _busy = '');
  }

  Future<void> _password(bool on) async {
    setState(() => _busy = 'pw');
    final r = await ctx.run(
      () => on ? ctx.api.post('${ctx.base}/codes/${_code!['_id']}/password', {'password': _pw.text}) : ctx.api.delete('${ctx.base}/codes/${_code!['_id']}/password'),
      ctx.m('saved'),
    );
    if (r != null) {
      setState(() => _code = obj(r['data']));
      widget.onSaved(obj(r['data']), false);
      _pw.clear();
    }
    if (mounted) setState(() => _busy = '');
  }

  Widget _section(String title, List<Widget> children, {IconData? icon}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: qgPanel([
      Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 17, color: context.c.brand), const SizedBox(width: 6)],
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        ],
      ),
      const SizedBox(height: 10),
      ...children,
    ]),
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final f = _f;
    final code = _code;
    final ro = ctx.readOnly;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              qgHead(
                context,
                qrTypeIcons[type] ?? LucideIcons.qrCode,
                code != null ? ctx.m('editTitle') : ctx.m('newTitle', {'type': ctx.m('types.$type')}),
                ctx.m('typeWhat.$type'),
                actions: [Btn(ctx.m('back'), icon: LucideIcons.arrowLeft, kind: BtnKind.ghost, small: true, onTap: widget.onClose)],
              ),
              mGap,
              if (_err.isNotEmpty) ...[Alert(_err), mGap],
              _preview(context),
              mGap,
              _section(ctx.m('name'), [
                _in('name', f, 'name', '', max: 80, hint: ctx.m('namePh')),
                _label(ctx.m('folder')),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(label: Text(ctx.m('noFolder')), selected: f['folder_id'] == null, onSelected: (_) => setState(() => f['folder_id'] = null)),
                    for (final x in ctx.folders) ChoiceChip(label: Text(str(x['name'])), selected: f['folder_id'] == x['_id'], onSelected: (_) => setState(() => f['folder_id'] = x['_id'])),
                  ],
                ),
                if (code != null) ...[const SizedBox(height: 6), SwitchRow(title: ctx.m('active'), value: f['active'] != false, onChanged: ro ? null : (v) => setState(() => f['active'] = v))],
                if (isStatic(type)) ...[const SizedBox(height: 8), Muted(ctx.m('staticNote'))],
              ]),
              _section(ctx.m('sContent'), _content(context)),
              if (type == 'url') _section(ctx.m('sSmart'), _smart(context), icon: LucideIcons.shuffle),
              if (type == 'coupon' && code != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CouponPanel(ctx: ctx, code: code),
                ),
              if (hasPage) _section(ctx.m('sPage'), _page(context)),
              _section(ctx.m('sDesign'), _design(context)),
              if (!isStatic(type)) _section(ctx.m('sOptions'), _options(context)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: c.card,
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Btn(ctx.m('back'), kind: BtnKind.ghost, small: true, onTap: widget.onClose),
                const Spacer(),
                Btn(ctx.m('save'), icon: LucideIcons.save, small: true, busy: _busy == 'save', onTap: ro || _busy.isNotEmpty || str(f['name']).trim().isEmpty ? null : _save),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // the code itself + its link + share
  Widget _preview(BuildContext context) {
    final c = context.c;
    final code = _code;
    final ready = code != null || isStatic(type);
    return qgPanel([
      Center(
        child: LayoutBuilder(
          builder: (_, box) => SizedBox(
            width: box.maxWidth.clamp(0, 260).toDouble(),
            child: FittedBox(
              child: QrView(code: draft, logo: ctx.logo, size: 260, scanMe: ctx.scanMe),
            ),
          ),
        ),
      ),
      if (code != null && !isStatic(type)) ...[
        const SizedBox(height: 8),
        InkWell(
          onTap: () => launchUrl(Uri.parse(codeUrl(code['slug'])), mode: LaunchMode.externalApplication),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  codeUrl(code['slug']).replaceFirst(RegExp(r'^https?://'), ''),
                  style: TextStyle(color: c.brand, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 4),
              Icon(LucideIcons.externalLink, size: 13, color: c.brand),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SlugBox(
          ctx: ctx,
          code: code,
          onDone: (row) {
            setState(() => _code = row);
            widget.onSaved(row, false);
          },
        ),
      ],
      const SizedBox(height: 10),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Btn(ctx.m('download'), icon: LucideIcons.download, small: true, onTap: ready ? () => shareCodePng(ctx, draft) : null),
          Btn(ctx.m('downloadSvg'), kind: BtnKind.ghost, small: true, onTap: ready ? () => shareCodeSvg(ctx, draft) : null),
          if (code != null && !isStatic(type))
            Btn(
              ctx.m('copyLink'),
              icon: LucideIcons.copy,
              kind: BtnKind.ghost,
              small: true,
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: codeUrl(code['slug'])));
                ctx.notify(ctx.m('copied'));
              },
            ),
        ],
      ),
      const SizedBox(height: 6),
      if (!ready) Muted(ctx.m('saveFirst'), align: TextAlign.center),
      if (code != null) Muted('✓ ${ctx.m('scans', {'n': fmt(n(code['scans']))})}', align: TextAlign.center),
    ]);
  }

  List<Widget> _content(BuildContext context) {
    final c = context.c;
    final f = _f;
    switch (type) {
      case 'url':
        return [_in('url', f, 'url', ctx.m('url'), max: 2000, hint: ctx.m('urlPh'), kb: TextInputType.url)];
      case 'links':
        final links = (f['links'] as List).cast<Json>();
        return [
          Muted(ctx.m('linksSub')),
          const SizedBox(height: 10),
          for (final (i, x) in links.indexed)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: linkKinds[x['kind']]?.color ?? const Color(0xFF334155),
                        child: Icon(linkIcons[x['kind']] ?? LucideIcons.globe, size: 15, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _linkKinds.contains(x['kind']) ? str(x['kind']) : 'web',
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          items: [for (final k in _linkKinds) DropdownMenuItem(value: k, child: Text(ctx.m('linkKinds.$k')))],
                          onChanged: (v) => setState(() => x['kind'] = v),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: i == 0
                            ? null
                            : () => setState(() {
                                links.insert(i - 1, links.removeAt(i));
                                _drop('link.');
                              }),
                        icon: const Icon(LucideIcons.arrowUp, size: 16),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() {
                          links.removeAt(i);
                          _drop('link.');
                        }),
                        icon: Icon(LucideIcons.trash2, size: 16, color: c.danger),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _in('link.$i.url', x, 'url', '', max: 600, hint: ctx.m('linkUrl'), kb: TextInputType.url),
                  _in('link.$i.label', x, 'label', '', max: 60, hint: ctx.m('linkLabel')),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: Btn(
              ctx.m('addLink'),
              icon: LucideIcons.plus,
              kind: BtnKind.ghost,
              small: true,
              onTap: links.length >= 20 ? null : () => setState(() => links.add({'kind': 'web', 'label': '', 'url': ''})),
            ),
          ),
        ];
      case 'coupon':
        final cp = f['coupon'] as Json;
        final ends = str(cp['ends_at']);
        return [
          _in('c.title', cp, 'title', ctx.m('cTitle'), max: 120, hint: ctx.m('cTitlePh')),
          _in('c.offer', cp, 'offer', ctx.m('cOffer'), max: 60, hint: ctx.m('cOfferPh')),
          _in('c.terms', cp, 'terms', ctx.m('cTerms'), max: 1000, lines: 2),
          DayField(label: ctx.m('cEnds'), value: ends.length >= 10 ? ends.substring(0, 10) : '', onChanged: (v) => setState(() => cp['ends_at'] = v.isEmpty ? null : '${v}T16:59:59.000Z')),
          gap14,
          _in('c.limit', cp, 'limit', ctx.m('cLimit'), max: 6, kb: TextInputType.number, onChanged: (v) => cp['limit'] = int.tryParse(v) ?? 0),
          _in('c.pin', cp, 'pin', cp['has_pin'] == true ? '${ctx.m('cPin')} — ${ctx.m('cPinSet')}' : ctx.m('cPin'), max: 6, hint: cp['has_pin'] == true ? '••••' : '1234', kb: TextInputType.number),
          if (cp['has_pin'] != true && str(cp['pin']).isEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Muted(ctx.m('cPinNeed'))),
          Muted(ctx.m('cHow')),
        ];
      case 'text':
        final t = f['text'] as Json;
        return [_in('t.title', t, 'title', ctx.m('textTitle'), max: 160), _in('t.body', t, 'body', ctx.m('textBody'), max: 8000, lines: 7)];
      case 'file':
        final fl = f['file'] as Json;
        final files = ctx.files;
        return [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(14)),
                child: Icon(fl['kind'] == 'image' ? LucideIcons.image : LucideIcons.fileText, color: c.brand),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(str(fl['name']).isEmpty ? ctx.m('file') : str(fl['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                    Muted('${ctx.m('fileSub')} · ${ctx.m('fileRoom', {'n': n(files['count']), 'max': n(files['capacity'])})}'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Btn(
                _busy == 'file'
                    ? ctx.m('uploading')
                    : str(fl['url']).isNotEmpty
                    ? ctx.m('replace')
                    : ctx.m('upload'),
                icon: LucideIcons.upload,
                small: true,
                busy: _busy == 'file',
                onTap: ctx.readOnly || _busy.isNotEmpty ? null : _upload,
              ),
              GoldBtn(
                ctx.m('moreFiles', {'n': n(files['pack']), 'coins': fmt(n(ctx.prices['qr_file_pack']))}),
                onTap: ctx.readOnly ? null : () => showSheet<void>(context, (_) => BuyFilesSheet(ctx: ctx)),
              ),
            ],
          ),
          if (str(fl['url']).isEmpty && _busy != 'file') ...[
            const SizedBox(height: 8),
            Text(
              ctx.m('fileMissing'),
              style: TextStyle(color: c.warn, fontWeight: FontWeight.w600),
            ),
          ],
        ];
      case 'form':
        return _form(context);
      case 'vcard':
        final v = f['vcard'] as Json;
        return [
          for (final (k, label, max) in [
            ('name', ctx.m('vName'), 80),
            ('org', ctx.m('vOrg'), 80),
            ('job', ctx.m('vJob'), 80),
            ('phone', ctx.m('vPhone'), 40),
            ('phone2', ctx.m('vPhone2'), 40),
            ('email', ctx.m('vEmail'), 120),
            ('website', ctx.m('vWebsite'), 200),
            ('address', ctx.m('vAddress'), 300),
          ])
            _in(
              'v.$k',
              v,
              k,
              label,
              max: max,
              kb: k.startsWith('phone')
                  ? TextInputType.phone
                  : k == 'email'
                  ? TextInputType.emailAddress
                  : null,
            ),
        ];
      case 'map':
        final mp = f['map'] as Json;
        return [
          _in('m.place', mp, 'place', ctx.m('mPlace'), max: 160),
          _in('m.link', mp, 'link', ctx.m('mLink'), max: 600, hint: 'https://maps.app.goo.gl/…', kb: TextInputType.url),
          _in('m.note', mp, 'note', ctx.m('mNote'), max: 300),
        ];
      case 'wifi':
        final w = f['wifi'] as Json;
        return [
          _in('w.ssid', w, 'ssid', ctx.m('wSsid'), max: 64),
          _label(ctx.m('wSecurity')),
          Segmented<String>(value: str(w['security']), options: const [('WPA', 'WPA / WPA2'), ('WEP', 'WEP'), ('nopass', '—')], onChanged: (v) => setState(() => w['security'] = v)),
          gap14,
          if (w['security'] != 'nopass') _in('w.pw', w, 'password', ctx.m('wPassword'), max: 64),
          SwitchRow(title: ctx.m('wHidden'), value: w['hidden'] == true, onChanged: (v) => setState(() => w['hidden'] = v)),
        ];
      default: // phone · sms
        final p = f['phone'] as Json;
        return [_in('p.number', p, 'number', ctx.m('pNumber'), max: 40, kb: TextInputType.phone), if (type == 'sms') _in('p.body', p, 'body', ctx.m('pBody'), max: 300, lines: 3)];
    }
  }

  List<Widget> _form(BuildContext context) {
    final c = context.c;
    final fm = _f['form'] as Json;
    final fields = (fm['fields'] as List).cast<Json>();
    final pro = ctx.on('qr_form_pro');
    String nextKey() {
      var k = fields.length + 1;
      while (fields.any((x) => x['key'] == 'f$k')) {
        k++;
      }
      return 'f$k';
    }

    return [
      _in('fm.title', fm, 'title', ctx.m('formTitle'), max: 160),
      _in('fm.button', fm, 'button', ctx.m('formButton'), max: 40, hint: 'Send'),
      _in('fm.intro', fm, 'intro', ctx.m('formIntro'), max: 1000, lines: 2),
      Row(
        children: [
          Expanded(
            child: Text(ctx.m('fields'), style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          PopupMenuButton<String>(
            tooltip: ctx.m('templateHint'),
            onSelected: (k) => setState(() {
              final t = formTemplates[k]!;
              final list = (t[ctx.lang] as List).cast<Map<String, dynamic>>().where((x) => pro || (!_proKinds.contains(x['kind']) && obj(x['show_if'])['key'] == null)).toList();
              if (str(fm['title']).isEmpty) fm['title'] = obj(t['title'])[ctx.lang];
              fm['fields'] = [
                for (final (i, x) in list.indexed)
                  {
                    ..._field('f${i + 1}'),
                    ...x,
                    'options': (x['options'] as List? ?? const []).map((e) => '$e').toList(),
                    'show_if': {'key': '', 'value': '', ...obj(x['show_if'])},
                  },
              ];
              _drop('fm.');
            }),
            itemBuilder: (_) => [for (final k in formTemplates.keys) PopupMenuItem(value: k, child: Text(ctx.m('formTemplates.$k')))],
            child: Chip(avatar: const Icon(LucideIcons.layoutTemplate, size: 15), label: Text(ctx.m('templatesBtn'))),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (!pro) ...[NeedLine(ctx: ctx, addon: 'qr_form_pro'), const SizedBox(height: 8)],
      for (final (i, x) in fields.indexed)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
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
                    child: DropdownButton<String>(
                      value: str(x['kind']),
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      items: [for (final k in _kinds) DropdownMenuItem(value: k, child: Text('${ctx.m('kinds.$k')}${_proKinds.contains(k) && !pro ? ' 🔒' : ''}'))],
                      onChanged: (v) => setState(() => x['kind'] = v),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: i == 0
                        ? null
                        : () => setState(() {
                            fields.insert(i - 1, fields.removeAt(i));
                            _drop('fm.');
                          }),
                    icon: const Icon(LucideIcons.arrowUp, size: 16),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: i == fields.length - 1
                        ? null
                        : () => setState(() {
                            fields.insert(i + 1, fields.removeAt(i));
                            _drop('fm.');
                          }),
                    icon: const Icon(LucideIcons.arrowDown, size: 16),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() {
                      fields.removeAt(i);
                      _drop('fm.');
                    }),
                    icon: Icon(LucideIcons.trash2, size: 16, color: c.danger),
                  ),
                ],
              ),
              _in('fm.$i.label', x, 'label', '', max: 120, hint: ctx.m('fieldLabel')),
              if (['select', 'checkbox', 'radio'].contains(x['kind']))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Field(
                    controller: _ctl.putIfAbsent('fm.$i.options', () => TextEditingController(text: (x['options'] as List).join('\n'))),
                    hint: ctx.m('options'),
                    maxLines: 3,
                    onChanged: (v) => setState(() => x['options'] = v.split('\n').take(20).toList()),
                  ),
                ),
              if (['text', 'textarea', 'phone', 'email', 'number'].contains(x['kind'])) _in('fm.$i.ph', x, 'placeholder', '', max: 120, hint: ctx.m('placeholder')),
              if (i > 0 && (pro || str(obj(x['show_if'])['key']).isNotEmpty)) ...[
                Muted(ctx.m('showIf')),
                DropdownButton<String>(
                  value: fields.take(i).any((y) => y['key'] == obj(x['show_if'])['key']) ? str(obj(x['show_if'])['key']) : '',
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(value: '', child: Text(ctx.m('showIfAny'))),
                    for (final (j, y) in fields.take(i).indexed)
                      if (str(y['label']).isNotEmpty)
                        DropdownMenuItem(
                          value: str(y['key']),
                          child: Text('${j + 1}. ${y['label']}', overflow: TextOverflow.ellipsis),
                        ),
                  ],
                  onChanged: (v) => setState(() => x['show_if'] = {'key': v ?? '', 'value': ''}),
                ),
                if (str(obj(x['show_if'])['key']).isNotEmpty) ...[
                  Muted(ctx.m('showIfIs')),
                  () {
                    final src = fields.where((y) => y['key'] == obj(x['show_if'])['key']).firstOrNull;
                    final opts = (src?['options'] as List? ?? const []).map((e) => '$e').where((e) => e.isNotEmpty).toList();
                    final si = obj(x['show_if']);
                    return opts.isNotEmpty
                        ? DropdownButton<String>(
                            value: opts.contains(si['value']) ? str(si['value']) : null,
                            hint: const Text('…'),
                            isExpanded: true,
                            items: [for (final o in opts) DropdownMenuItem(value: o, child: Text(o))],
                            onChanged: (v) => setState(() => x['show_if'] = {...si, 'value': v ?? ''}),
                          )
                        : _in('fm.$i.siv', si, 'value', '', max: 80);
                  }(),
                ],
              ],
              SwitchRow(title: ctx.m('requiredQ'), value: x['required'] == true, onChanged: (v) => setState(() => x['required'] = v)),
            ],
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: Btn(ctx.m('addField'), icon: LucideIcons.plus, kind: BtnKind.ghost, small: true, onTap: fields.length >= 30 ? null : () => setState(() => fields.add(_field(nextKey())))),
      ),
      gap14,
      _in('fm.thanks', fm, 'thanks', ctx.m('formThanks'), max: 300),
    ];
  }

  List<Widget> _smart(BuildContext context) {
    final c = context.c;
    final sm = _f['smart'] as Json;
    final times = (sm['times'] as List).cast<Json>();
    final on = ctx.on('qr_smart');
    return [
      Muted(ctx.m('smartSub')),
      const SizedBox(height: 8),
      if (!on) ...[NeedLine(ctx: ctx, addon: 'qr_smart'), const SizedBox(height: 8)],
      IgnorePointer(
        ignoring: !on,
        child: Opacity(
          opacity: on ? 1 : .5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _in('s.ios', sm, 'ios', ctx.m('smartIos'), max: 600, hint: 'apps.apple.com/…', kb: TextInputType.url),
              _in('s.android', sm, 'android', ctx.m('smartAndroid'), max: 600, hint: 'play.google.com/…', kb: TextInputType.url),
              Text(ctx.m('smartTimes'), style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final (i, t) in times.indexed)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TimeField(value: str(t['from']), onChanged: (v) => setState(() => t['from'] = v)),
                          ),
                          const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('–')),
                          Expanded(
                            child: TimeField(value: str(t['to']), onChanged: (v) => setState(() => t['to'] = v)),
                          ),
                          IconButton(
                            onPressed: () => setState(() {
                              times.removeAt(i);
                              _drop('s.t');
                            }),
                            icon: Icon(LucideIcons.trash2, size: 16, color: c.danger),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _in('s.t$i', t, 'url', '', max: 600, hint: ctx.m('urlPh'), kb: TextInputType.url),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: Btn(
                  ctx.m('smartAddTime'),
                  icon: LucideIcons.plus,
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: times.length >= 6 ? null : () => setState(() => times.add({'from': '11:00', 'to': '14:00', 'url': ''})),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  // tap a page theme → the theme sheet (bigger, swipe for the next). "Use" picks it for this page (saved with the code).
  Future<void> _openTheme(String key, List<String> list) async {
    final pg = _f['page'] as Json;
    final owned = (ctx.data['themes'] as List? ?? const []).map((e) => '$e').toSet();
    final color = Color(0xFF000000 | (int.tryParse(str(pg['color']).replaceFirst('#', ''), radix: 16) ?? 0xE0581A));
    final price = n(ctx.prices['qr_theme']);
    final name = str(pg['header']).isNotEmpty ? str(pg['header']) : (str(_f['name']).isEmpty ? 'Aa' : str(_f['name']));
    await showLookSheet(
      context,
      title: ctx.m('themesName'),
      count: list.length,
      initial: list.indexOf(key),
      item: (context, i, refresh) {
        final k = list[i];
        final t = themeOf(k);
        final mine = t == null || owned.contains(k);
        final using = str(pg['template']) == k;
        return LookItem(
          name: t?.name(ctx.lang) ?? ctx.m('templates.$k'),
          badge: using ? ctx.t('looks.inUse') : (t == null ? ctx.m('free') : (mine ? ctx.m('yours') : '${fmt(price)} ${ctx.m('coins')}')),
          badgeTone: using || mine ? Tone.good : Tone.warn,
          preview: ThemeThumb(template: k, color: color, name: name, business: str(ctx.business['name']), width: 240),
          acts: [
            if (!using && mine)
              LookAct(
                ctx.m('use'),
                icon: LucideIcons.check,
                onTap: () async {
                  setState(() => pg['template'] = k);
                  return true;
                },
              ),
            if (!mine)
              LookAct(
                ctx.m('buy', {'coins': fmt(price)}),
                gold: true,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        ctx.askBuy({'theme': k, 'color': pg['color']});
                        return true;
                      },
              ),
          ],
        );
      },
    );
  }

  // tap one of your QR designs → the design sheet (your code in it, big). "Use" picks it (saved with the code).
  Future<void> _openDesign(String key, List<String> list) async {
    final d = _f['design'] as Json;
    await showLookSheet(
      context,
      title: ctx.m('designsTitle'),
      count: list.length,
      initial: list.indexOf(key),
      item: (context, i, refresh) {
        final k = list[i];
        final using = (str(d['key']).isEmpty ? 'plain' : str(d['key'])) == k;
        return LookItem(
          name: qrDesigns[k]?.name(ctx.lang) ?? k,
          badge: using ? ctx.t('looks.inUse') : (k == 'plain' ? ctx.m('free') : ctx.m('yours')),
          badgeTone: Tone.good,
          preview: QrView(
            code: {
              ...draft,
              'design': {...d, 'key': k},
            },
            size: 260,
            scanMe: ctx.scanMe,
          ),
          acts: [
            if (!using)
              LookAct(
                ctx.m('use'),
                icon: LucideIcons.check,
                onTap: () async {
                  setState(() => d['key'] = k);
                  return true;
                },
              ),
          ],
        );
      },
    );
  }

  List<Widget> _page(BuildContext context) {
    final c = context.c;
    final pg = _f['page'] as Json;
    final owned = (ctx.data['themes'] as List? ?? const []).map((e) => '$e').toSet();
    final color = Color(0xFF000000 | (int.tryParse(str(pg['color']).replaceFirst('#', ''), radix: 16) ?? 0xE0581A));
    final tpl = str(pg['template']);
    final rows = (pg['rows'] as List).cast<Json>();
    return [
      SizedBox(
        height: 152,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final k in [..._templates, for (final t in pageThemes) t.key])
              () {
                final t = themeOf(k);
                final locked = t != null && !owned.contains(k);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openTheme(k, [..._templates, for (final t in pageThemes) t.key]),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: tpl == k ? c.brand : Colors.transparent, width: 2),
                      ),
                      child: Column(
                        children: [
                          ThemeThumb(
                            template: k,
                            color: color,
                            name: str(pg['header']).isNotEmpty ? str(pg['header']) : (str(_f['name']).isEmpty ? 'Aa' : str(_f['name'])),
                            business: str(ctx.business['name']),
                            width: 88,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(t?.name(ctx.lang) ?? ctx.m('templates.$k'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              const SizedBox(width: 3),
                              if (t == null)
                                Text(
                                  ctx.m('free'),
                                  style: TextStyle(fontSize: 10, color: c.good, fontWeight: FontWeight.w700),
                                )
                              else if (locked) ...[
                                const CoinIcon(size: 10),
                                Text(fmt(n(ctx.prices['qr_theme'])), style: const TextStyle(fontSize: 10)),
                              ] else
                                Icon(LucideIcons.check, size: 11, color: c.good),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }(),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Muted(ctx.m('themesHint', {'n': pageThemes.length, 'coins': fmt(n(ctx.prices['qr_theme']))})),
      gap14,
      _label(ctx.m('pageColor')),
      ColorRow(
        value: str(pg['color']).toUpperCase(),
        colors: _swatches,
        customLabel: ctx.m('pageColor'),
        saveLabel: ctx.m('save'),
        cancelLabel: ctx.m('cancel'),
        onChanged: (v) => setState(() => pg['color'] = v),
      ),
      gap14,
      _in('pg.header', pg, 'header', ctx.m('header'), max: 120, hint: str(_f['name'])),
      _in('pg.footer', pg, 'footer', ctx.m('footer'), max: 200),
      Text(ctx.m('rows'), style: const TextStyle(fontWeight: FontWeight.w700)),
      Muted(ctx.m('rowsSub')),
      const SizedBox(height: 8),
      for (final (i, r) in rows.indexed)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _in('pg.r$i.l', r, 'label', '', max: 60, hint: ctx.m('label'))),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _in('pg.r$i.v', r, 'value', '', max: 300, hint: ctx.m('value'))),
            IconButton(
              onPressed: () => setState(() {
                rows.removeAt(i);
                _drop('pg.r');
              }),
              icon: Icon(LucideIcons.trash2, size: 16, color: c.danger),
            ),
          ],
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: Btn(ctx.m('addRow'), icon: LucideIcons.plus, kind: BtnKind.ghost, small: true, onTap: rows.length >= 20 ? null : () => setState(() => rows.add({'label': '', 'value': ''}))),
      ),
      const SizedBox(height: 6),
      SwitchRow(title: ctx.m('showLogo'), value: pg['logo'] != false, onChanged: (v) => setState(() => pg['logo'] = v)),
    ];
  }

  List<Widget> _design(BuildContext context) {
    final c = context.c;
    final d = _f['design'] as Json;
    final owned = (ctx.data['designs'] as List? ?? const ['plain']).map((e) => '$e').toList();
    final def = qrDesigns[d['key']] ?? qrDesigns['plain']!;
    String hex(Color x) => '#${(x.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    return [
      Muted(ctx.m('designSub')),
      const SizedBox(height: 10),
      SizedBox(
        height: 98,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final k in owned)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openDesign(k, owned),
                  child: Container(
                    width: 88,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: d['key'] == k ? c.brand : c.line, width: d['key'] == k ? 2 : 1),
                    ),
                    child: FittedBox(
                      child: QrView(
                        code: {
                          ...draft,
                          'design': {'key': k},
                        },
                        size: 80,
                        scanMe: ctx.scanMe,
                      ),
                    ),
                  ),
                ),
              ),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => ctx.go('designs'),
              child: Container(
                width: 88,
                decoration: BoxDecoration(
                  color: c.bg2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.line),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.plus, color: c.brand),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        ctx.m('moreDesigns', {'n': qrDesigns.length - 1}),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10.5, color: c.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      gap14,
      for (final (k, label, dc) in [('color', ctx.m('cCode'), def.color), ('bg', ctx.m('cBg'), def.bg), ('accent', ctx.m('cAccent'), def.accent)]) ...[
        _label(label),
        ColorRow(
          value: str(d[k]).isEmpty ? hex(dc) : str(d[k]).toUpperCase(),
          colors: {hex(dc), '#111111', if (k == 'bg') '#FFFFFF', ..._swatches}.toList(),
          customLabel: label,
          saveLabel: ctx.m('save'),
          cancelLabel: ctx.m('cancel'),
          onChanged: (v) => setState(() => d[k] = v),
        ),
        const SizedBox(height: 10),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: Btn(
          ctx.m('resetColors'),
          icon: LucideIcons.rotateCcw,
          kind: BtnKind.ghost,
          small: true,
          onTap: () => setState(() {
            d['color'] = '';
            d['bg'] = '';
            d['accent'] = '';
          }),
        ),
      ),
      gap14,
      _in('d.label', d, 'label', ctx.m('frameLabel'), max: 40, hint: ctx.m('frameLabelPh')),
      if (ctx.logo.isNotEmpty) SwitchRow(title: ctx.m('logoMiddle'), value: d['logo'] == true, onChanged: (v) => setState(() => d['logo'] = v)),
    ];
  }

  List<Widget> _options(BuildContext context) {
    final rules = _f['rules'] as Json;
    final code = _code;
    final exp = str(rules['expires_at']);
    return [
      if (ctx.on('qr_telegram'))
        SwitchRow(title: ctx.m('notifyScan'), value: _f['notify_scan'] == true, onChanged: (v) => setState(() => _f['notify_scan'] = v))
      else
        NeedLine(ctx: ctx, addon: 'qr_telegram'),
      gap14,
      Text(ctx.m('rules'), style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      if (!ctx.on('qr_rules'))
        NeedLine(ctx: ctx, addon: 'qr_rules')
      else ...[
        DayField(
          label: ctx.m('expires'),
          value: exp.isEmpty ? '' : DateTime.parse(exp).toUtc().add(const Duration(hours: 7)).toIso8601String().substring(0, 10),
          onChanged: (v) => setState(() => rules['expires_at'] = v.isEmpty ? null : DateTime.parse('${v}T23:59:59+07:00').toUtc().toIso8601String()),
        ),
        gap14,
        _in('r.max', rules, 'max_scans', ctx.m('maxScans'), max: 7, kb: TextInputType.number, onChanged: (v) => rules['max_scans'] = int.tryParse(v) ?? 0),
        if (code != null) ...[
          if (code['has_password'] == true)
            Align(
              alignment: Alignment.centerLeft,
              child: Chip2(ctx.m('pwOn'), icon: LucideIcons.lock, tone: Tone.good),
            ),
          const SizedBox(height: 8),
          Field(controller: _pw, hint: ctx.m('pwNew'), maxLength: 40, onChanged: (_) => setState(() {})),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Btn(ctx.m('pwSet'), icon: LucideIcons.lock, kind: BtnKind.ghost, small: true, busy: _busy == 'pw', onTap: _busy == 'pw' || _pw.text.length < 4 ? null : () => _password(true)),
              if (code['has_password'] == true) Btn(ctx.m('pwRemove'), icon: LucideIcons.lockOpen, kind: BtnKind.ghost, small: true, onTap: _busy == 'pw' ? null : () => _password(false)),
            ],
          ),
        ] else
          Muted('${ctx.m('password')}: ${ctx.m('saveFirst')}'),
      ],
    ];
  }
}

// custom link name for one QR code (qr_slug: one-time per QR, then free to change)
class SlugBox extends StatefulWidget {
  final QgCtx ctx;
  final Json code;
  final void Function(Json row) onDone;
  const SlugBox({super.key, required this.ctx, required this.code, required this.onDone});
  @override
  State<SlugBox> createState() => _SlugBoxState();
}

class _SlugBoxState extends State<SlugBox> {
  QgCtx get ctx => widget.ctx;
  late final bool owned = (ctx.data['slugs'] as List? ?? const []).map((e) => '$e').contains(str(widget.code['_id']));
  late final _v = TextEditingController(text: owned ? str(widget.code['slug']) : '');
  bool _busy = false;
  String _err = '';

  @override
  void dispose() {
    _v.dispose();
    super.dispose();
  }

  String get _clean => _v.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '');
  bool get _ok => RegExp(r'^[a-z0-9][a-z0-9-]{1,28}[a-z0-9]$').hasMatch(_clean) && !_clean.contains('--');

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(ctx.m('sSlug'), style: const TextStyle(fontWeight: FontWeight.w800)),
          Muted(ctx.m('slugSub', {'site': codeUrl('').replaceFirst(RegExp(r'^https?://'), '').replaceFirst(RegExp(r'/x/$'), '')})),
          const SizedBox(height: 8),
          Field(
            controller: _v,
            hint: 'lucky-menu',
            maxLength: 30,
            enabled: !ctx.readOnly,
            prefix: Padding(
              padding: const EdgeInsets.only(left: 12, right: 2),
              child: Center(
                widthFactor: 1,
                child: Text(
                  '/x/',
                  style: TextStyle(color: c.muted, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            onChanged: (v) {
              final s = v.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
              if (s != v) {
                _v.value = TextEditingValue(
                  text: s,
                  selection: TextSelection.collapsed(offset: s.length),
                );
              }
              setState(() {});
            },
          ),
          if (_err.isNotEmpty) Text(_err, style: TextStyle(color: c.danger, fontSize: 12.5)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: owned
                ? Btn(
                    ctx.m('slugSave'),
                    small: true,
                    busy: _busy,
                    onTap: ctx.readOnly || _busy || !_ok || _clean == widget.code['slug']
                        ? null
                        : () async {
                            setState(() {
                              _busy = true;
                              _err = '';
                            });
                            try {
                              final r = await ctx.api.post('${ctx.base}/codes/${widget.code['_id']}/slug', {'slug': _clean});
                              widget.onDone(obj(r['data']));
                              ctx.notify(ctx.m('saved'));
                            } on ApiError catch (e) {
                              setState(() => _err = e.message);
                            }
                            if (mounted) setState(() => _busy = false);
                          },
                  )
                : GoldBtn(
                    ctx.m('slugBuy', {'coins': fmt(n(ctx.prices['qr_slug']))}),
                    onTap: ctx.readOnly || !_ok
                        ? null
                        : () => ctx.askBuy({
                            'slug': {'code': widget.code, 'value': _clean, 'done': widget.onDone},
                          }),
                  ),
          ),
          const SizedBox(height: 4),
          Muted(owned ? '${ctx.m('slugOwned')} ${ctx.m('slugOld')}' : ctx.m('slugOld')),
        ],
      ),
    );
  }
}

// coupons given from a Coupon QR: numbers, mark one used, the list
class CouponPanel extends StatefulWidget {
  final QgCtx ctx;
  final Json code;
  const CouponPanel({super.key, required this.ctx, required this.code});
  @override
  State<CouponPanel> createState() => _CouponPanelState();
}

class _CouponPanelState extends State<CouponPanel> {
  QgCtx get ctx => widget.ctx;
  Json? _res;
  String _used = '';
  bool _busy = false;
  final _q = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/codes/${widget.code['_id']}/coupons', {'used': _used});
      if (mounted) setState(() => _res = r);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cp = obj(widget.code['coupon']);
    final counts = _res?['counts'] != null ? obj(_res!['counts']) : {'issued': cp['issued'] ?? 0, 'used': cp['used'] ?? 0, 'limit': cp['limit'] ?? 0};
    final rows = objs(_res?['data']);
    Widget stat(String l, String v) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(l, style: TextStyle(color: c.muted, fontSize: 12)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
      ),
    );
    final ok = _q.text.replaceAll(RegExp(r'[^A-Z0-9]'), '').length == 6;
    return qgPanel([
      Row(
        children: [
          Icon(LucideIcons.ticket, size: 17, color: c.brand),
          const SizedBox(width: 6),
          Text(ctx.m('cList'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          stat(ctx.m('cGiven'), fmt(n(counts['issued']))),
          const SizedBox(width: 8),
          stat(ctx.m('cUsed'), fmt(n(counts['used']))),
          const SizedBox(width: 8),
          stat(ctx.m('cLeft'), n(counts['limit']) > 0 ? fmt(n(counts['limit']) - n(counts['issued']) < 0 ? 0 : n(counts['limit']) - n(counts['issued'])) : '∞'),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: Field(
              controller: _q,
              hint: ctx.m('cRedeemPh'),
              maxLength: 8,
              onChanged: (v) {
                final u = v.toUpperCase();
                if (u != v) {
                  _q.value = TextEditingValue(
                    text: u,
                    selection: TextSelection.collapsed(offset: u.length),
                  );
                }
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 8),
          Btn(
            ctx.m('cRedeemBtn'),
            icon: LucideIcons.check,
            small: true,
            busy: _busy,
            onTap: ctx.readOnly || _busy || !ok
                ? null
                : () async {
                    setState(() => _busy = true);
                    final r = await ctx.run(() => ctx.api.post('${ctx.base}/codes/${widget.code['_id']}/coupons/redeem', {'code': _q.text}));
                    if (r != null) {
                      ctx.notify(ctx.m('cRedeemed', {'code': obj(r['data'])['code']}));
                      _q.clear();
                      _load();
                    }
                    if (mounted) setState(() => _busy = false);
                  },
          ),
        ],
      ),
      const SizedBox(height: 10),
      Segmented<String>(
        value: _used,
        options: [('', ctx.m('cAll')), ('0', ctx.m('cOnlyNew')), ('1', ctx.m('cOnlyUsed'))],
        onChanged: (v) {
          setState(() => _used = v);
          _load();
        },
      ),
      const SizedBox(height: 8),
      if (rows.isEmpty)
        Muted(ctx.m('cNone'))
      else
        for (final x in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(
                  str(x['code']),
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                Expanded(child: Muted(_when(x['created_date']))),
                x['used_at'] != null ? Chip2(_when(x['used_at']), icon: LucideIcons.check, tone: Tone.good) : Chip2(ctx.m('cOnlyNew')),
              ],
            ),
          ),
    ]);
  }

  String _when(Object? d) {
    final x = DateTime.tryParse('${d ?? ''}')?.toUtc().add(const Duration(hours: 7));
    if (x == null) return '';
    const en = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${x.day} ${en[x.month - 1]} ${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';
  }
}

// buy n × 10 more files
class BuyFilesSheet extends ConsumerStatefulWidget {
  final QgCtx ctx;
  const BuyFilesSheet({super.key, required this.ctx});
  @override
  ConsumerState<BuyFilesSheet> createState() => _BuyFilesSheetState();
}

class _BuyFilesSheetState extends ConsumerState<BuyFilesSheet> {
  QgCtx get ctx => widget.ctx;
  int _n = 1;
  bool _busy = false;
  String _err = '';

  @override
  Widget build(BuildContext context) {
    final price = n(ctx.prices['qr_file_pack']);
    final pack = n(ctx.files['pack']).toInt();
    final total = _n * price;
    return MSheet(
      title: ctx.m('buyFiles'),
      footer: [
        const Spacer(),
        Btn(ctx.m('cancel'), kind: BtnKind.ghost, small: true, onTap: _busy ? null : () => Navigator.pop(context)),
        const SizedBox(width: 8),
        GoldBtn(
          ctx.m('buyFor', {'n': '+${_n * pack}', 'coins': fmt(total)}),
          onTap: _busy
              ? null
              : () async {
                  final ok = await confirmPay(context, ref, coins: total, what: ctx.m('buyFiles'));
                  if (!ok) return;
                  setState(() {
                    _busy = true;
                    _err = '';
                  });
                  try {
                    final r = await ctx.api.post('${ctx.base}/file-packs', {'n': _n});
                    if (r['balance'] is num) await ref.read(sessionProvider.notifier).patch({'coin_balance': r['balance']});
                    coinsChanged(ref);
                    ctx.put((d) => {'files': r['files'] ?? d['files']});
                    ctx.notify(ctx.m('bought', {'n': _n * pack}));
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
        Muted(ctx.m('buyFilesSub', {'coins': fmt(price)})),
        gap14,
        Text(ctx.m('packs'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(
          children: [
            IconButton.filledTonal(onPressed: _n > 1 ? () => setState(() => _n--) : null, icon: const Icon(LucideIcons.minus)),
            SizedBox(
              width: 60,
              child: Text(
                '$_n',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
              ),
            ),
            IconButton.filledTonal(onPressed: _n < 100 ? () => setState(() => _n++) : null, icon: const Icon(LucideIcons.plus)),
          ],
        ),
        if (_err.isNotEmpty) ...[gap14, Alert(_err)],
      ],
    );
  }
}
