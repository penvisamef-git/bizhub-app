import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../restaurant/rest_common.dart' show Segmented, SwitchRow;
import 'mq_common.dart';

// ============================== Media (MqMedia.jsx) ==============================
class MediaTab extends StatefulWidget {
  final MqCtx ctx;
  const MediaTab({super.key, required this.ctx});
  @override
  State<MediaTab> createState() => _MediaTabState();
}

class _MediaTabState extends State<MediaTab> {
  MqCtx get ctx => widget.ctx;
  MediaRes? _res;
  String _busy = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await loadMedia(ctx);
    if (mounted && r != null) setState(() => _res = r);
  }

  Future<void> _buy() async {
    await openBuySlots(context, ctx, n(_res?.room['slot_price']));
    await _load();
  }

  Future<void> _upload() async {
    setState(() => _busy = 'upload');
    await uploadMedia(context, ctx, onFull: _buy);
    await _load();
    if (mounted) setState(() => _busy = '');
  }

  Future<void> _remove(Json x) async {
    final used = (x['used'] as List? ?? const []).length;
    final ask = used > 0 ? ctx.m('deleteUsed', {'n': used}) : ctx.m('sure', {'name': str(x['name']).isEmpty ? '📷' : str(x['name'])});
    if (!await mqConfirm(context, ctx, ask)) return;
    setState(() => _busy = str(x['_id']));
    final r = await ctx.run(() => ctx.api.delete('${ctx.base}/media/${x['_id']}'), ctx.m('saved'));
    if (r != null) {
      await _load();
      ctx.reload();
    }
    if (mounted) setState(() => _busy = '');
  }

  void _usedBy(Json x) {
    final used = objs(x['used']);
    if (used.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(ctx.m('usedCount', {'n': used.length})),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final u in used) Text('• ${ctx.t.or('mq.kindNames.${u['kind']}', str(u['kind']))}${str(u['name']).isNotEmpty ? ': ${u['name']}' : ''}')],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: Text(ctx.m('close')))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final res = _res;
    final c = context.c;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          mqHead(
            context,
            LucideIcons.images,
            ctx.m('mediaTitle'),
            ctx.m('mediaSub'),
            actions: [Btn(ctx.m('upload'), icon: LucideIcons.upload, small: true, busy: _busy == 'upload', onTap: ctx.readOnly || _busy.isNotEmpty ? null : _upload)],
          ),
          const SizedBox(height: 12),
          if (res == null)
            const SkelList(rows: 4)
          else ...[
            mqPanel([MediaRoom(ctx: ctx, res: res, onBuy: _buy), const SizedBox(height: 8), Muted(ctx.m('uploadHint'))]),
            const SizedBox(height: 12),
            if (res.rows.isEmpty)
              mqPanel([Muted(ctx.m('emptyMedia'))])
            else
              mqPanel([
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
                          final used = (x['used'] as List? ?? const []).length;
                          return MediaTile(
                            url: str(x['url']),
                            onTap: () => _usedBy(x),
                            badge: mediaBadge(context, used > 0 ? ctx.m('usedCount', {'n': used}) : ctx.m('notUsed'), used > 0),
                            corner: _busy == x['_id']
                                ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2))
                                : Material(
                                    color: Colors.black54,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: ctx.readOnly || _busy.isNotEmpty ? null : () => _remove(x),
                                      child: Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Icon(LucideIcons.trash2, size: 14, color: c.dangerBg),
                                      ),
                                    ),
                                  ),
                          );
                        },
                      ),
                  ],
                ),
              ]),
          ],
        ],
      ),
    );
  }
}

// ============================== Business info (MqProfile.jsx) ==============================
const _contact = [
  ('phone', 'phone', 30, '012 345 678'),
  ('phone2', 'phone2', 30, ''),
  ('telegram', 'telegram', 120, '@yourname'),
  ('facebook', 'facebook', 200, 'facebook.com/…'),
  ('instagram', 'instagram', 200, 'instagram.com/…'),
  ('tiktok', 'tiktok', 200, 'tiktok.com/@…'),
  ('website', 'website', 200, 'www…'),
  ('email', 'email', 120, ''),
  ('wifi_name', 'wifiName', 60, ''),
  ('wifi_pass', 'wifiPass', 60, ''),
  ('address', 'address', 300, ''),
  ('map_url', 'mapUrl', 400, 'https://maps.app.goo.gl/…'),
];

class ProfileTab extends StatefulWidget {
  final MqCtx ctx;
  const ProfileTab({super.key, required this.ctx});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  MqCtx get ctx => widget.ctx;
  Json get s => ctx.settings;
  late final _tagline = TextEditingController(text: str(s['tagline']));
  late final _about = TextEditingController(text: str(s['about']));
  late final _hours = TextEditingController(text: str(s['hours']));
  late final _rate = TextEditingController(text: '${s['khr_rate'] ?? 4100}');
  late final _slug = TextEditingController(text: str(s['slug']));
  late final _c = {for (final (k, _, _, _) in _contact) k: TextEditingController(text: str(obj(s['contact'])[k]))};
  late String _currency = ctx.currency;
  late String _lang = str(s['lang']).isEmpty ? 'km' : str(s['lang']);
  late bool _both = s['show_both'] == true;
  late bool _feedback = s['feedback_on'] != false;
  String _busy = '', _err = '';

  @override
  void dispose() {
    for (final x in [_tagline, _about, _hours, _rate, _slug, ..._c.values]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final slug = _slug.text.trim();
    if (slug != str(s['slug']) && !await mqConfirm(context, ctx, ctx.m('linkAsk'), yes: ctx.m('save'), danger: false)) return;
    setState(() {
      _busy = 'save';
      _err = '';
    });
    try {
      final r = await ctx.api.put('${ctx.base}/settings', {
        'tagline': _tagline.text.trim(),
        'about': _about.text.trim(),
        'hours': _hours.text.trim(),
        'currency': _currency,
        'khr_rate': num.tryParse(_rate.text.trim()) ?? 4100,
        'show_both': _both,
        'lang': _lang,
        'slug': slug,
        'feedback_on': _feedback,
        'contact': {for (final e in _c.entries) e.key: e.value.text.trim()},
      });
      ctx.setSettings(obj(r['data']));
      ctx.notify(ctx.m('saved'));
    } on ApiError catch (e) {
      if (mounted) setState(() => _err = e.message);
    }
    if (mounted) setState(() => _busy = '');
  }

  Future<void> _usePicture(String field, String label) async {
    await pickMedia(
      context,
      ctx,
      title: '$label · ${ctx.m('pickTitle')}',
      onPick: (list) async {
        setState(() => _busy = field);
        final r = await ctx.run(() => ctx.api.post('${ctx.base}/$field', {'media_id': list.first['_id']}));
        if (mounted) setState(() => _busy = '');
        if (r == null) return false;
        ctx.setSettings(obj(r['data']));
        return true;
      },
    );
  }

  Future<void> _removePicture(String field) async {
    setState(() => _busy = '$field-x');
    final r = await ctx.run(() => ctx.api.delete('${ctx.base}/$field'));
    if (r != null) ctx.setSettings(obj(r['data']));
    if (mounted) setState(() => _busy = '');
  }

  Widget _picture(String field, String label, {bool round = false}) {
    final c = context.c;
    final url = str(obj(s[field])['url']);
    final off = ctx.readOnly || _busy.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: c.muted, fontSize: 12.5)),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(round ? 99 : 16),
          onTap: off ? null : () => _usePicture(field, label),
          child: Container(
            width: round ? 96 : double.infinity,
            height: round ? 96 : 140,
            decoration: BoxDecoration(
              color: c.bg2,
              shape: round ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: round ? null : BorderRadius.circular(16),
              border: Border.all(color: c.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: _busy == field
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : url.isNotEmpty
                ? Image(image: netImage(url), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())
                : Icon(LucideIcons.imagePlus, color: c.muted),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            Btn(url.isNotEmpty ? ctx.m('change') : ctx.m('fromMedia'), icon: LucideIcons.images, kind: BtnKind.ghost, small: true, onTap: off ? null : () => _usePicture(field, label)),
            if (url.isNotEmpty) Btn(ctx.m('remove'), icon: LucideIcons.trash2, kind: BtnKind.danger, small: true, busy: _busy == '$field-x', onTap: off ? null : () => _removePicture(field)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ro = ctx.readOnly;
    final site = menuUrl('').replaceFirst(RegExp(r'^https?://'), '');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        mqHead(context, LucideIcons.store, ctx.m('profileTitle'), ctx.m('profileSub')),
        const SizedBox(height: 12),
        mqPanel([
          _picture('logo', ctx.m('logo'), round: true),
          const SizedBox(height: 14),
          _picture('cover', ctx.m('cover')),
          const SizedBox(height: 16),
          MqInput(ctx.m('tagline'), _tagline, max: 120, hint: ctx.m('taglinePh'), enabled: !ro),
          MqInput(ctx.m('about'), _about, max: 600, lines: 3, enabled: !ro),
          MqInput(ctx.m('hours'), _hours, max: 160, hint: ctx.m('hoursPh'), enabled: !ro),
        ]),
        const SizedBox(height: 12),
        mqPanel([
          Text(ctx.m('contact'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          for (final (k, label, max, ph) in _contact) MqInput(ctx.m(label), _c[k]!, max: max, hint: ph.isEmpty ? null : ph, enabled: !ro),
        ]),
        const SizedBox(height: 12),
        mqPanel([
          Text(ctx.m('money'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          Text(ctx.m('currency'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Segmented<String>(value: _currency, options: const [('USD', 'USD (\$)'), ('KHR', 'KHR (៛)')], onChanged: ro ? null : (v) => setState(() => _currency = v)),
          const SizedBox(height: 12),
          MqInput(ctx.m('khrRate'), _rate, number: true, enabled: !ro),
          Text(ctx.m('firstLang'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Segmented<String>(value: _lang, options: const [('km', 'ខ្មែរ'), ('en', 'English')], onChanged: ro ? null : (v) => setState(() => _lang = v)),
          const SizedBox(height: 6),
          SwitchRow(title: ctx.m('showBoth'), value: _both, onChanged: ro ? null : (v) => setState(() => _both = v)),
          if (ctx.on('mq_feedback')) SwitchRow(title: ctx.m('feedbackOn'), value: _feedback, onChanged: ro ? null : (v) => setState(() => _feedback = v)),
        ]),
        const SizedBox(height: 12),
        mqPanel([
          Text(ctx.m('link'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          Text(site, style: TextStyle(color: c.muted, fontSize: 13)),
          const SizedBox(height: 6),
          Field(
            controller: _slug,
            maxLength: 40,
            enabled: !ro,
            onChanged: (v) {
              final clean = v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '');
              if (clean != v) {
                _slug.value = TextEditingValue(
                  text: clean,
                  selection: TextSelection.collapsed(offset: clean.length),
                );
              }
            },
          ),
          const SizedBox(height: 6),
          Muted(ctx.m('linkHint')),
        ]),
        if (_err.isNotEmpty) ...[const SizedBox(height: 12), Alert(_err)],
        const SizedBox(height: 14),
        Btn(ctx.m(_busy == 'save' ? 'saving' : 'save'), icon: LucideIcons.save, expand: true, busy: _busy == 'save', onTap: ro || _busy.isNotEmpty ? null : _save),
      ],
    );
  }
}
