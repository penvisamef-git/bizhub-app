import 'package:dio/dio.dart' show DioMediaType, FormData, MultipartFile;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show GoldBtn, MHead;
import 'ev_common.dart';

Future<List<int>?> _pickImage() async {
  final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1400, maxHeight: 1400, imageQuality: 88);
  return f == null ? null : await f.readAsBytes();
}

FormData _img(List<int> bytes, [Map<String, String> fields = const {}]) =>
    FormData.fromMap({...fields, 'file': MultipartFile.fromBytes(bytes, filename: 'photo.jpg', contentType: DioMediaType.parse('image/jpeg'))});

// ======================================== Promo codes (ev_promos) ========================================
class PromosTab extends StatefulWidget {
  final EvCtx ctx;
  const PromosTab({super.key, required this.ctx});
  @override
  State<PromosTab> createState() => _PromosTabState();
}

class _PromosTabState extends State<PromosTab> {
  EvCtx get ctx => widget.ctx;
  List<Json>? _list;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!ctx.on('ev_promos')) return;
    try {
      final r = await ctx.api.get('${ctx.base}/promos');
      if (mounted) setState(() => _list = objs(r['data']));
    } catch (e) {
      ctx.fail(e);
      if (mounted) setState(() => _list = []);
    }
  }

  Future<void> _edit([Json? p]) async {
    final r = await showModalBottomSheet<List<Json>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _PromoSheet(ctx: ctx, p: p),
    );
    if (r != null && mounted) setState(() => _list = r);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return EvList(
      onRefresh: _load,
      children: [
        EvHead(
          ctx.m('more.promosTitle'),
          sub: ctx.m('more.promosSub'),
          trailing: ctx.on('ev_promos') ? Btn(ctx.m('more.promoNew'), icon: LucideIcons.plus, small: true, onTap: ctx.readOnly ? null : () => _edit()) : null,
        ),
        EvLocked(
          ctx: ctx,
          addon: 'ev_promos',
          child: _list == null
              ? const SkelList(rows: 3)
              : _list!.isEmpty
              ? Panel(child: Muted(ctx.m('more.promoNone'), align: TextAlign.center))
              : Column(
                  children: [
                    for (final p in _list!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Panel(
                          padding: const EdgeInsets.all(12),
                          onTap: ctx.readOnly ? null : () => _edit(p),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(10)),
                                child: Text(
                                  str(p['code']),
                                  style: TextStyle(fontWeight: FontWeight.w800, color: c.brandInk, letterSpacing: 1),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p['kind'] == 'percent' ? '−${n(p['value'])}%' : '−${usd2(p['value'])}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                    Text(
                                      [
                                        obj(p['event'])['title'] ?? ctx.m('more.promoAll'),
                                        n(p['max_uses']) > 0 ? ctx.m('more.promoUsedN', {'n': n(p['used']), 'max': n(p['max_uses'])}) : '${n(p['used'])} ×',
                                        if (p['ends_at'] != null) ctx.m('more.promoUntil', {'d': evWhen(p['ends_at'], ctx.lang, time: false)}),
                                        if (n(p['min_qty']) > 1) ctx.m('more.promoMinN', {'n': n(p['min_qty'])}),
                                      ].join(' · '),
                                      style: TextStyle(fontSize: 12, color: c.muted),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: p['active'] == true,
                                onChanged: ctx.readOnly
                                    ? null
                                    : (v) async {
                                        final r = await ctx.run(() => ctx.api.put('${ctx.base}/promos/${p['_id']}', {'active': v}));
                                        if (r != null && mounted) setState(() => _list = objs(r['data']));
                                      },
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _PromoSheet extends StatefulWidget {
  final EvCtx ctx;
  final Json? p;
  const _PromoSheet({required this.ctx, this.p});
  @override
  State<_PromoSheet> createState() => _PromoSheetState();
}

class _PromoSheetState extends State<_PromoSheet> {
  late final _code = TextEditingController(text: str(widget.p?['code']));
  late final _value = TextEditingController(text: '${n(widget.p?['value'] ?? 10)}');
  late final _max = TextEditingController(text: '${n(widget.p?['max_uses'] ?? 0).toInt()}');
  late final _min = TextEditingController(text: '${n(widget.p?['min_qty'] ?? 1).toInt()}');
  late String _kind = str(widget.p?['kind']).isEmpty ? 'percent' : str(widget.p?['kind']);
  late String _event = str(widget.p?['event_id']);
  late DateTime? _ends = evDate(widget.p?['ends_at']);
  bool _busy = false;
  String _err = '';

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final ev = ctx.eventById(_event);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.p == null ? ctx.m('more.promoNew') : str(widget.p!['code']), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if (widget.p == null) ...[Field(label: ctx.m('more.promoCode'), hint: 'SAVE10', controller: _code, maxLength: 24, onChanged: (_) => setState(() {})), const SizedBox(height: 10)],
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Field(label: ctx.m('more.promoValue'), controller: _value, keyboard: const TextInputType.numberWithOptions(decimal: true)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'percent', label: Text('%')),
                      ButtonSegment(value: 'amount', label: Text('\$')),
                    ],
                    selected: {_kind},
                    onSelectionChanged: (v) => setState(() => _kind = v.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final v = await pickEvent(context, ctx, _event, all: true);
                if (v != null) setState(() => _event = v);
              },
              icon: const Icon(LucideIcons.ticket, size: 15),
              label: Text('${ctx.m('more.promoEvent')}: ${ev == null ? ctx.m('more.promoAll') : ev['title']}', maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Field(label: ctx.m('more.promoMax'), controller: _max, keyboard: TextInputType.number),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Field(label: ctx.m('more.promoMinQty'), controller: _min, keyboard: TextInputType.number),
                ),
              ],
            ),
            Muted(ctx.m('more.promoMaxSub')),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final d = await showDatePicker(context: context, initialDate: _ends ?? now, firstDate: now.subtract(const Duration(days: 1)), lastDate: DateTime(now.year + 3));
                if (d != null) setState(() => _ends = DateTime(d.year, d.month, d.day, 23, 59));
              },
              icon: const Icon(LucideIcons.calendarDays, size: 15),
              label: Text(_ends == null ? ctx.m('more.promoEnds') : evWhen(_ends, ctx.lang, time: false)),
            ),
            if (_err.isNotEmpty) ...[const SizedBox(height: 10), Alert(_err)],
            const SizedBox(height: 14),
            Row(
              children: [
                if (widget.p != null)
                  Btn(
                    ctx.m('remove'),
                    icon: LucideIcons.trash2,
                    kind: BtnKind.danger,
                    small: true,
                    onTap: () async {
                      if (!await askSure(context, ctx.m('more.promoDelSure'), ok: ctx.m('remove'), cancel: ctx.m('cancel'), danger: true)) return;
                      final r = await ctx.run(() => ctx.api.delete('${ctx.base}/promos/${widget.p!['_id']}'));
                      if (r != null && context.mounted) Navigator.pop(context, objs(r['data']));
                    },
                  ),
                const Spacer(),
                Btn(
                  ctx.m('save'),
                  icon: LucideIcons.save,
                  busy: _busy,
                  onTap: widget.p == null && _code.text.trim().isEmpty
                      ? null
                      : () async {
                          setState(() {
                            _busy = true;
                            _err = '';
                          });
                          final body = {
                            if (widget.p == null) 'code': _code.text.trim(),
                            'kind': _kind,
                            'value': num.tryParse(_value.text.trim()) ?? 0,
                            'max_uses': int.tryParse(_max.text.trim()) ?? 0,
                            'min_qty': int.tryParse(_min.text.trim()) ?? 1,
                            'event_id': _event.isEmpty ? null : _event,
                            'ends_at': _ends?.toUtc().toIso8601String(),
                          };
                          try {
                            final r = widget.p == null ? await ctx.api.post('${ctx.base}/promos', body) : await ctx.api.put('${ctx.base}/promos/${widget.p!['_id']}', body);
                            if (context.mounted) Navigator.pop(context, objs(r['data']));
                          } on ApiError catch (e) {
                            setState(() => _err = e.message);
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================== Updates & documents (ev_guest_tg) ========================================
class UpdatesTab extends StatefulWidget {
  final EvCtx ctx;
  const UpdatesTab({super.key, required this.ctx});
  @override
  State<UpdatesTab> createState() => _UpdatesTabState();
}

class _UpdatesTabState extends State<UpdatesTab> {
  EvCtx get ctx => widget.ctx;
  late String _event = ctx.firstEvent();
  final _text = TextEditingController(), _docName = TextEditingController();
  bool _send = true;
  String _busy = '';
  Json? _count;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  @override
  void dispose() {
    _text.dispose();
    _docName.dispose();
    super.dispose();
  }

  Future<void> _loadCount() async {
    if (_event.isEmpty || !ctx.on('ev_guest_tg')) return;
    try {
      final r = await ctx.api.get('${ctx.base}/events/$_event/telegram-guests');
      if (mounted) setState(() => _count = obj(r['data']));
    } catch (_) {}
  }

  Future<void> _run(String k, Future<Json> Function() fn, [String Function(Json)? ok]) async {
    setState(() => _busy = k);
    try {
      final r = await fn();
      ctx.notify(ok != null ? ok(r) : ctx.m('saved'));
      await ctx.reload();
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Future<void> _addDoc() async {
    final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp']);
    if (f == null) return;
    final bytes = await f.xFile.readAsBytes();
    final ext = f.name.split('.').last.toLowerCase();
    final type = ext == 'pdf' ? 'application/pdf' : (ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg'));
    await _run(
      'doc',
      () => ctx.api.post(
        '${ctx.base}/events/$_event/docs',
        FormData.fromMap({'name': _docName.text.trim(), 'file': MultipartFile.fromBytes(bytes, filename: f.name, contentType: DioMediaType.parse(type))}),
      ),
    );
    _docName.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ev = ctx.eventById(_event);
    final updates = objs(ev?['updates']);
    final docs = objs(ev?['docs']);
    return EvList(
      onRefresh: () async {
        await ctx.reload();
        await _loadCount();
      },
      children: [
        EvHead(ctx.m('more.updTitle'), sub: ctx.m('more.updSub')),
        EvLocked(
          ctx: ctx,
          addon: 'ev_guest_tg',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(ctx.m('more.updFor'), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              EvEventPick(
                ctx: ctx,
                value: _event,
                onChanged: (v) => setState(() {
                  _event = v;
                  _count = null;
                  _loadCount();
                }),
              ),
              const SizedBox(height: 4),
              Muted('${ctx.m('more.updForSub')}${_count != null ? ' · ${ctx.m('more.updCount', {'n': n(_count!['linked']), 'all': n(_count!['paid_orders'])})}' : ''}'),
              const SizedBox(height: 12),
              if (ev != null) ...[
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(ctx.m('more.updNew'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Field(hint: ctx.m('more.updPh'), controller: _text, maxLines: 3, onChanged: (_) => setState(() {})),
                      SwitchListTile(contentPadding: EdgeInsets.zero, value: _send, onChanged: (v) => setState(() => _send = v), title: Text(ctx.m('more.updSend'))),
                      Btn(
                        ctx.m('more.updPostTo', {'event': ev['title']}),
                        icon: LucideIcons.send,
                        busy: _busy == 'post',
                        onTap: ctx.readOnly || _text.text.trim().isEmpty
                            ? null
                            : () async {
                                await _run(
                                  'post',
                                  () => ctx.api.post('${ctx.base}/events/$_event/updates', {'text': _text.text.trim(), 'send': _send}),
                                  (r) => n(r['sent']) > 0 ? ctx.m('more.updDone', {'n': n(r['sent'])}) : ctx.m('saved'),
                                );
                                _text.clear();
                              },
                      ),
                      for (final u in updates)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(str(u['text'])),
                          subtitle: Text('${evWhen(u['at'], ctx.lang)}${n(u['sent']) > 0 ? ' · ${ctx.m('more.updSentN', {'n': n(u['sent'])})}' : ''}'),
                          trailing: IconButton(
                            onPressed: ctx.readOnly ? null : () => _run('d${u['_id']}', () => ctx.api.delete('${ctx.base}/events/$_event/updates/${u['_id']}')),
                            icon: Icon(LucideIcons.trash2, size: 16, color: c.muted),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(ctx.m('more.docsTitle'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      Muted(ctx.m('more.docsSub')),
                      const SizedBox(height: 8),
                      for (final d in docs)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(d['kind'] == 'pdf' ? LucideIcons.fileText : LucideIcons.image, color: c.brand),
                          title: Text(str(d['name'])),
                          onTap: () => launchUrl(Uri.parse(str(d['url'])), mode: LaunchMode.externalApplication),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: ctx.m('more.docSend'),
                                onPressed: ctx.readOnly
                                    ? null
                                    : () => _run('s${d['key']}', () => ctx.api.post('${ctx.base}/events/$_event/docs/${d['key']}/send'), (r) => ctx.m('more.updDone', {'n': n(r['sent'])})),
                                icon: const Icon(LucideIcons.send, size: 16),
                              ),
                              IconButton(
                                onPressed: ctx.readOnly ? null : () => _run('x${d['key']}', () => ctx.api.delete('${ctx.base}/events/$_event/docs/${d['key']}')),
                                icon: Icon(LucideIcons.trash2, size: 16, color: c.muted),
                              ),
                            ],
                          ),
                        ),
                      Field(hint: ctx.m('more.docName'), controller: _docName, maxLength: 80),
                      const SizedBox(height: 8),
                      Btn(ctx.m('more.docAdd'), icon: LucideIcons.upload, kind: BtnKind.ghost, small: true, busy: _busy == 'doc', onTap: ctx.readOnly || docs.length >= 10 ? null : _addDoc),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ======================================== Telegram ========================================
class TelegramTab extends StatefulWidget {
  final EvCtx ctx;
  const TelegramTab({super.key, required this.ctx});
  @override
  State<TelegramTab> createState() => _TelegramTabState();
}

class _TelegramTabState extends State<TelegramTab> {
  EvCtx get ctx => widget.ctx;
  Json? _s;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/telegram');
      if (mounted) setState(() => _s = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _set(Json b) async {
    final r = await ctx.run(() => ctx.api.put('${ctx.base}/telegram', b));
    if (r != null && mounted) setState(() => _s = obj(r['data']));
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    final r = await ctx.run(() => ctx.api.post('${ctx.base}/telegram/link'));
    if (mounted) setState(() => _busy = false);
    final url = str(obj(r?['data'])['url']);
    if (url.isNotEmpty) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = _s;
    final org = obj(s?['org']);
    final g = obj(s?['guests']);
    return EvList(
      onRefresh: _load,
      children: [
        EvHead(ctx.m('more.tgTitle'), sub: ctx.m('more.tgSub')),
        if (s == null)
          const SkelList(rows: 3)
        else ...[
          if (s['configured'] != true)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Alert(ctx.m('more.tgNotReady'), tone: Tone.warn),
            ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.bellRing, color: c.brand),
                    const SizedBox(width: 8),
                    Text(ctx.m('addonNames.ev_telegram'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 8),
                EvLocked(
                  ctx: ctx,
                  addon: 'ev_telegram',
                  child: org['connected'] == true
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Alert(ctx.m('more.tgConnected', {'name': org['chat_name']}), tone: Tone.good),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: org['new_orders'] == true,
                              onChanged: ctx.readOnly ? null : (v) => _set({'new_orders': v}),
                              title: Text(ctx.m('more.tgNewOrders')),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: org['daily'] == true,
                              onChanged: ctx.readOnly ? null : (v) => _set({'daily': v}),
                              title: Text(ctx.m('more.tgDaily')),
                            ),
                            Row(
                              children: [
                                Btn(
                                  ctx.m('more.tgTest'),
                                  icon: LucideIcons.send,
                                  small: true,
                                  kind: BtnKind.ghost,
                                  onTap: () => ctx.run(() => ctx.api.post('${ctx.base}/telegram/test'), ctx.m('saved')),
                                ),
                                const SizedBox(width: 8),
                                Btn(
                                  ctx.m('more.tgDisconnect'),
                                  icon: LucideIcons.unplug,
                                  small: true,
                                  kind: BtnKind.danger,
                                  onTap: ctx.readOnly
                                      ? null
                                      : () async {
                                          if (!await askSure(context, ctx.m('more.tgOffSure'), ok: ctx.m('more.tgDisconnect'), cancel: ctx.m('cancel'), danger: true)) return;
                                          final r = await ctx.run(() => ctx.api.delete('${ctx.base}/telegram'));
                                          if (r != null && mounted) setState(() => _s = obj(r['data']));
                                        },
                                ),
                              ],
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Muted(ctx.m('more.tgHow')),
                            const SizedBox(height: 10),
                            Btn(ctx.m('more.tgConnect'), icon: LucideIcons.send, busy: _busy, onTap: ctx.readOnly || s['configured'] != true ? null : _connect),
                            const SizedBox(height: 6),
                            TextButton(onPressed: _load, child: Text(ctx.m('ord.refresh'))),
                          ],
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.send, color: c.brand),
                    const SizedBox(width: 8),
                    Text(ctx.m('addonNames.ev_guest_tg'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 8),
                EvLocked(
                  ctx: ctx,
                  addon: 'ev_guest_tg',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Muted(ctx.m('more.gtHow')),
                      const SizedBox(height: 6),
                      Text(ctx.m('more.gtLinked', {'n': n(g['linked'])}), style: const TextStyle(fontWeight: FontWeight.w700)),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: g['remind_day'] == true,
                        onChanged: ctx.readOnly ? null : (v) => _set({'remind_day': v}),
                        title: Text(ctx.m('more.gtDay')),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: g['remind_hours'] == true,
                        onChanged: ctx.readOnly ? null : (v) => _set({'remind_hours': v}),
                        title: Text(ctx.m('more.gtHours')),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(onPressed: () => ctx.go('updates'), icon: const Icon(LucideIcons.megaphone, size: 15), label: Text(ctx.m('more.gtGoUpdates'))),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ======================================== Payment & organiser ========================================
class PaymentTab extends StatefulWidget {
  final EvCtx ctx;
  const PaymentTab({super.key, required this.ctx});
  @override
  State<PaymentTab> createState() => _PaymentTabState();
}

class _PaymentTabState extends State<PaymentTab> {
  EvCtx get ctx => widget.ctx;
  late final _org = TextEditingController(text: str(ctx.org['name']));
  late final _phone = TextEditingController(text: str(ctx.org['phone']));
  late final _tg = TextEditingController(text: str(ctx.org['telegram']));
  late final _hold = TextEditingController(text: '${n(ctx.data['hold_minutes'] ?? 30).toInt()}');
  String _busy = '';

  @override
  void dispose() {
    for (final c in [_org, _phone, _tg, _hold]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(String k, Future<Json> Function() fn) async {
    setState(() => _busy = k);
    final r = await ctx.run(fn, ctx.m('saved'));
    if (r != null) await ctx.reload();
    if (mounted) setState(() => _busy = '');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final methods = ctx.payMethods;
    final auto = ctx.on('ev_autopay');
    final ready = ctx.data['khqr_ready'] == true;
    final ids = methods.any((p) => p['active'] != false && str(p['bakong_id']).isNotEmpty);
    final autoState = !auto ? 'locked' : (!ready ? 'token' : (!ids ? 'id' : 'on'));
    return EvList(
      onRefresh: ctx.reload,
      children: [
        EvHead(ctx.m('payTitle'), sub: ctx.m('pm.sub')),
        // automatic KHQR
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: autoState == 'on' ? c.goodBg : c.warnBg, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.qrCode, color: autoState == 'on' ? c.good : c.warn),
                  const SizedBox(width: 8),
                  Text(ctx.m('pm.autoTitle'), style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 6),
              Text({'locked': ctx.m('pm.autoLocked'), 'token': ctx.m('pm.autoNoToken'), 'id': ctx.m('pm.autoNoId'), 'on': ctx.m('pm.autoOn')}[autoState]!, style: const TextStyle(fontSize: 13)),
              if (autoState == 'locked') ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: GoldBtn(ctx.m('unlock', {'coins': fmt(n(ctx.addon('ev_autopay')['price']))}), onTap: ctx.readOnly ? null : () => ctx.askBuy('ev_autopay')),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        // the public events page
        Panel(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(LucideIcons.megaphone, color: c.brand),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ctx.m('grow.listTitle'), style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(ctx.m('grow.listSub'), style: TextStyle(fontSize: 12.5, color: c.muted)),
                  ],
                ),
              ),
              Switch(value: ctx.data['listed'] == true, onChanged: ctx.readOnly ? null : (v) => _run('list', () => ctx.api.put('${ctx.base}/listing', {'listed': v}))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Spacer(),
            Btn(
              ctx.m('pm.add'),
              icon: LucideIcons.plus,
              small: true,
              busy: _busy == 'add',
              onTap: ctx.readOnly || methods.length >= 10 ? null : () => _run('add', () => ctx.api.post('${ctx.base}/pay-methods', {'bank': ''})),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (methods.isEmpty) Panel(child: Muted(ctx.m('pm.none'), align: TextAlign.center)),
        for (final (i, pm) in methods.indexed) _PayMethod(key: ValueKey('${pm['key']}${pm['qr']}'), ctx: ctx, pm: pm, first: i == 0),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(ctx.m('orgTitle'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(14)),
                    clipBehavior: Clip.antiAlias,
                    child: str(ctx.org['logo']).isNotEmpty ? Image(image: netImage(str(ctx.org['logo'])), fit: BoxFit.cover) : Icon(LucideIcons.image, color: c.brand),
                  ),
                  const SizedBox(width: 10),
                  Btn(
                    ctx.m('orgLogo'),
                    icon: LucideIcons.imagePlus,
                    small: true,
                    kind: BtnKind.ghost,
                    busy: _busy == 'logo',
                    onTap: ctx.readOnly
                        ? null
                        : () async {
                            final b = await _pickImage();
                            if (b != null) await _run('logo', () => ctx.api.post('${ctx.base}/logo', _img(b)));
                          },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Field(label: ctx.m('orgName'), controller: _org, maxLength: 80),
              const SizedBox(height: 8),
              Field(label: ctx.m('orgPhone'), controller: _phone, keyboard: TextInputType.phone),
              const SizedBox(height: 8),
              Field(label: ctx.m('orgTelegram'), controller: _tg),
              const SizedBox(height: 8),
              Field(label: ctx.m('hold'), controller: _hold, keyboard: TextInputType.number),
              Muted(ctx.m('holdSub')),
              const SizedBox(height: 10),
              Btn(
                ctx.m('save'),
                icon: LucideIcons.save,
                busy: _busy == 'org',
                onTap: ctx.readOnly
                    ? null
                    : () => _run(
                        'org',
                        () => ctx.api.put('${ctx.base}/settings', {
                          'org_name': _org.text.trim(),
                          'phone': _phone.text.trim(),
                          'telegram': _tg.text.trim(),
                          'hold_minutes': int.tryParse(_hold.text.trim()) ?? 30,
                        }),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PayMethod extends StatefulWidget {
  final EvCtx ctx;
  final Json pm;
  final bool first;
  const _PayMethod({super.key, required this.ctx, required this.pm, required this.first});
  @override
  State<_PayMethod> createState() => _PayMethodState();
}

class _PayMethodState extends State<_PayMethod> {
  EvCtx get ctx => widget.ctx;
  Json get pm => widget.pm;
  late final _f = {
    for (final k in ['bank', 'account_name', 'account_no', 'link', 'note', 'bakong_id']) k: TextEditingController(text: str(pm[k])),
  };
  String _busy = '';

  @override
  void dispose() {
    for (final c in _f.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(String k, Future<Json> Function() fn) async {
    setState(() => _busy = k);
    final r = await ctx.run(fn, ctx.m('saved'));
    if (r != null) await ctx.reload();
    if (mounted) setState(() => _busy = '');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final qr = str(pm['qr']);
    final auto = ctx.on('ev_autopay') && ctx.data['khqr_ready'] == true && str(pm['bakong_id']).isNotEmpty;
    final ready = qr.isNotEmpty || str(pm['link']).isNotEmpty || auto;
    final key = str(pm['key']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: pm['active'] == false ? .6 : 1,
        child: Panel(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: ctx.readOnly
                        ? null
                        : () async {
                            final b = await _pickImage();
                            if (b != null) await _run('qr', () => ctx.api.post('${ctx.base}/pay-methods/$key/qr', _img(b)));
                          },
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: c.chip,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.line),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _busy == 'qr'
                          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                          : (qr.isNotEmpty ? Image(image: netImage(qr), fit: BoxFit.cover) : Icon(LucideIcons.qrCode, color: c.muted)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(str(pm['bank']).isEmpty ? ctx.m('pm.unnamed') : str(pm['bank']), style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (widget.first) Chip2(ctx.m('pm.first')),
                            Chip2(ready ? ctx.m('pm.ready') : ctx.m('pm.notReady'), tone: ready ? Tone.good : Tone.warn),
                            if (auto) Chip2(ctx.m('pm.autoChip'), icon: LucideIcons.qrCode, tone: Tone.good),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Switch(value: pm['active'] != false, onChanged: ctx.readOnly ? null : (v) => _run('on', () => ctx.api.put('${ctx.base}/pay-methods/$key', {'active': v}))),
                ],
              ),
              const SizedBox(height: 8),
              Field(label: ctx.m('payBank'), hint: 'ABA', controller: _f['bank']!, maxLength: 60),
              const SizedBox(height: 8),
              Field(label: ctx.m('payAccName'), controller: _f['account_name']!, maxLength: 80),
              const SizedBox(height: 8),
              Field(label: ctx.m('payAccNo'), controller: _f['account_no']!, maxLength: 60),
              const SizedBox(height: 8),
              Field(label: ctx.m('payLink'), hint: 'https://link.payway.com.kh/…', controller: _f['link']!, keyboard: TextInputType.url),
              const SizedBox(height: 8),
              Field(label: ctx.m('payNote'), controller: _f['note']!, maxLength: 200),
              if (ctx.on('ev_autopay')) ...[
                const SizedBox(height: 8),
                Field(label: ctx.m('pm.bakong'), hint: 'yourname@aba', controller: _f['bakong_id']!, maxLength: 60),
                Muted(ctx.m('pm.bakongHint')),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Btn(
                    ctx.m('save'),
                    icon: LucideIcons.save,
                    small: true,
                    busy: _busy == 'save',
                    onTap: ctx.readOnly
                        ? null
                        : () => _run(
                            'save',
                            () => ctx.api.put('${ctx.base}/pay-methods/$key', {
                              for (final e in _f.entries)
                                if (e.key != 'bakong_id' || ctx.on('ev_autopay')) e.key: e.key == 'bakong_id' ? e.value.text.trim().toLowerCase() : e.value.text.trim(),
                            }),
                          ),
                  ),
                  if (qr.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Btn(ctx.m('pm.removeQr'), small: true, kind: BtnKind.ghost, onTap: ctx.readOnly ? null : () => _run('rq', () => ctx.api.delete('${ctx.base}/pay-methods/$key/qr'))),
                  ],
                  const Spacer(),
                  IconButton(
                    onPressed: ctx.readOnly
                        ? null
                        : () async {
                            if (await askSure(context, ctx.m('pm.delSure'), ok: ctx.m('remove'), cancel: ctx.m('cancel'), danger: true)) {
                              _run('del', () => ctx.api.delete('${ctx.base}/pay-methods/$key'));
                            }
                          },
                    icon: Icon(LucideIcons.trash2, size: 17, color: c.danger),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================== Add-ons ========================================
class AddonsTab extends StatelessWidget {
  final EvCtx ctx;
  const AddonsTab({super.key, required this.ctx});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final keys = evAddonOrder.where((k) => ctx.addon(k).isNotEmpty).toList();
    final lic = ctx.license;
    Widget perk(String p) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.check, size: 15, color: c.good),
          const SizedBox(width: 8),
          Expanded(child: Text(p)),
        ],
      ),
    );
    // the same cards as the other businesses (Guest House / Restaurant add-ons)
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + MediaQuery.of(context).padding.bottom),
      children: [
        Panel(
          padding: const EdgeInsets.all(16),
          child: MHead(ctx.m('addonsTitle'), sub: ctx.m('addonsSub'), icon: LucideIcons.puzzle),
        ),
        const SizedBox(height: 12),
        // Event Tickets itself (the yearly licence)
        Panel(
          padding: const EdgeInsets.all(16),
          color: lic['active'] == true ? c.goodBg.withValues(alpha: .5) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MHead(ctx.m('renewTitle'), icon: LucideIcons.ticket, sub: ctx.m('baseWhat')),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip2(
                    lic['expires_at'] != null ? ctx.m('endsOn', {'date': evWhen(lic['expires_at'], ctx.lang, time: false)}) : ctx.m('unlocked'),
                    icon: LucideIcons.badgeCheck,
                    tone: lic['locked'] == true ? Tone.danger : Tone.good,
                  ),
                  GoldBtn(ctx.m('renewFor', {'coins': fmt(n(lic['price']))}), onTap: ctx.business['status'] == false ? null : () => ctx.askBuy('renew')),
                ],
              ),
            ],
          ),
        ),
        for (final k in keys) ...[
          const SizedBox(height: 12),
          () {
            final a = ctx.addon(k);
            final on = a['active'] == true;
            final yearly = a['days'] != null;
            return Panel(
              padding: const EdgeInsets.all(16),
              color: on ? c.goodBg.withValues(alpha: .5) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MHead(ctx.m('addonNames.$k'), icon: evAddonIcons[k] ?? LucideIcons.puzzle, sub: ctx.m('addonWhat.$k')),
                  for (final p in ctx.t.list('ev.perks.$k')) perk(p),
                  perk(yearly ? '${fmt(n(a['price']))} ${ctx.m('coins')} ${ctx.m('perYear')}' : '${fmt(n(a['price']))} ${ctx.m('coins')} · ${ctx.m('forever')}'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (on) Chip2(ctx.m('unlocked'), icon: LucideIcons.badgeCheck, tone: Tone.good),
                      if (on && a['expires_at'] != null) Muted(ctx.m('endsOn', {'date': evWhen(a['expires_at'], ctx.lang, time: false)})),
                      if (!on) GoldBtn(ctx.m('unlock', {'coins': fmt(n(a['price']))}), onTap: ctx.readOnly ? null : () => ctx.askBuy(k)),
                      if (on && yearly) GoldBtn(ctx.m('renewFor', {'coins': fmt(n(a['price']))}), onTap: ctx.readOnly ? null : () => ctx.askBuy(k)),
                    ],
                  ),
                ],
              ),
            );
          }(),
        ],
      ],
    );
  }
}
