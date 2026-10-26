import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'rest_common.dart';
import 'rest_reports.dart' show ShiftTile;

// POS (the web's PosTab.jsx): link devices with a 6-digit code, how they send sales, recent shifts.

extension on RestCtx {
  String ps(String key, [Map<String, Object?> vars = const {}]) => t('pos.$key', vars);
}

class PosSection extends StatefulWidget {
  final RestCtx ctx;
  const PosSection({super.key, required this.ctx});
  @override
  State<PosSection> createState() => _PosSectionState();
}

class _PosSectionState extends State<PosSection> {
  Json? _data, _form, _pair;
  String _busy = '', _sure = '';
  DateTime _now = DateTime.now();
  Timer? _tick, _poll;
  RestCtx get ctx => widget.ctx;
  String get _posUrl => '${Config.siteUrl}/pos/restaurant';

  @override
  void initState() {
    super.initState();
    _load().catchError((Object e) => ctx.fail(e));
  }

  @override
  void dispose() {
    _tick?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await ctx.api.get('${ctx.base}/pos');
    if (!mounted) return;
    final d = obj(r['data']);
    setState(() {
      _data = d;
      _form ??= Json.from(obj(d['settings']));
      if (d['pair'] != null) {
        _pair = obj(d['pair']);
      } else if (_pair != null) {
        _pair = null; // the code was used
      }
    });
    _timers();
  }

  // while a code is shown: tick the countdown, and refresh the list so the new device appears
  void _timers() {
    if (_pair == null) {
      _tick?.cancel();
      _poll?.cancel();
      _tick = _poll = null;
      return;
    }
    _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _poll ??= Timer.periodic(const Duration(seconds: 4), (_) => _load().catchError((_) {}));
  }

  Future<void> _act(String key, Future<void> Function() fn, [String? ok]) async {
    setState(() => _busy = key);
    try {
      await fn();
      if (ok != null) ctx.notify(ok);
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  String _when(Object? d) {
    final t = DateTime.tryParse('${d ?? ''}');
    if (t == null) return ctx.ps('never');
    final m = (DateTime.now().difference(t).inSeconds / 60).round();
    if (m < 1) return ctx.ps('justNow');
    if (m < 60) return ctx.ps('minAgo', {'n': m});
    if (m < 1440) return ctx.ps('hourAgo', {'n': (m / 60).round()});
    const en = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const km = ['មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា', 'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ'];
    final l = t.toUtc().add(const Duration(hours: 7));
    return '${l.day} ${(ctx.lang == 'km' ? km : en)[l.month - 1]}';
  }

  Future<void> _rename(Json d) async {
    final ctrl = TextEditingController(text: str(d['name']));
    final name = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(ctx.ps('rename')),
        content: TextField(controller: ctrl, autofocus: true, maxLength: 40, onSubmitted: (v) => Navigator.pop(dctx, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: Text(ctx.r('cancel'))),
          TextButton(onPressed: () => Navigator.pop(dctx, ctrl.text), child: Text(ctx.r('save'))),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.trim().isEmpty || name.trim() == str(d['name'])) return;
    await _act('rename', () async {
      await ctx.api.put('${ctx.base}/pos/devices/${d['_id']}', {'name': name.trim()});
      await _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final data = _data, form = _form;
    if (data == null || form == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 4));
    final pair = _pair;
    final left = pair == null ? 0 : (DateTime.tryParse(str(pair['expires_at']))?.difference(_now).inSeconds ?? 0).clamp(0, 99999);
    final dirty = jsonEncode(form) != jsonEncode(obj(data['settings']));
    final cur = str(obj(data['money'])['currency']).isEmpty ? 'USD' : str(obj(data['money'])['currency']);
    final devices = objs(data['devices']);
    final shifts = objs(data['shifts']);
    final ro = ctx.readOnly;
    void set(String k, Object v) => setState(() => form[k] = v);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RestHead(ctx.ps('title'), sub: ctx.ps('sub')),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Btn(
                    ctx.ps('openPos'),
                    icon: LucideIcons.externalLink,
                    small: true,
                    onTap: () => launchUrl(Uri.parse(_posUrl), mode: LaunchMode.externalApplication),
                  ),
                ),
              ],
            ),
          ),
          gap14,
          // ---------------- link a device
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RestHead(ctx.ps('linkTitle'), sub: ctx.ps('linkSub')),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _posUrl));
                    ctx.notify(ctx.t('app.copied'));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _posUrl,
                            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                        Icon(LucideIcons.copy, size: 16, color: c.muted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (pair != null && left > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final d in str(pair['code']).split(''))
                        Container(
                          width: 40,
                          height: 52,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: c.brand, width: 1.5),
                          ),
                          child: Text(
                            d,
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: c.brandInk),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(child: Muted(ctx.ps('codeFor', {'m': '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}'}))),
                  const SizedBox(height: 12),
                ] else if (pair != null) ...[
                  Center(child: Muted(ctx.ps('expired'))),
                  const SizedBox(height: 12),
                ],
                Center(
                  child: Btn(
                    pair != null ? ctx.ps('newCode') : ctx.ps('getCode'),
                    icon: LucideIcons.keyRound,
                    small: true,
                    busy: _busy == 'code',
                    onTap: ro || _busy == 'code'
                        ? null
                        : () => _act('code', () async {
                            final r = await ctx.api.post('${ctx.base}/pos/pair-code');
                            setState(() => _pair = obj(r['data']));
                            _timers();
                          }),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.line),
                    ),
                    child: QrImageView(data: _posUrl, size: 150, padding: EdgeInsets.zero),
                  ),
                ),
                const SizedBox(height: 6),
                Center(child: Muted(ctx.ps('scan'))),
              ],
            ),
          ),
          gap14,
          // ---------------- devices
          Panel(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: ctx.ps('devices')),
                            TextSpan(
                              text: '  ${devices.length}',
                              style: TextStyle(color: c.muted, fontSize: 14),
                            ),
                          ],
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    RoundBtn(LucideIcons.refreshCw, size: 38, onTap: _busy == 'reload' ? null : () => _act('reload', _load)),
                  ],
                ),
                const SizedBox(height: 6),
                if (devices.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 8, right: 8), child: Muted(ctx.ps('noDevices'))),
                for (final d in devices) _device(d, ro),
              ],
            ),
          ),
          gap14,
          // ---------------- settings
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RestHead(ctx.ps('settings')),
                Text(ctx.ps('syncMode'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                const SizedBox(height: 8),
                for (final k in ['instant', '5', '15', '30', 'shift']) _mode(k, form, ro),
                const SizedBox(height: 6),
                SwitchRow(title: ctx.ps('allowOffline'), sub: ctx.ps('allowOfflineHint'), value: form['allow_offline'] == true, onChanged: ro ? null : (v) => set('allow_offline', v)),
                const SizedBox(height: 8),
                SelectField<num>(
                  label: ctx.ps('maxLineDiscount'),
                  hint: ctx.ps('maxLineDiscountHint'),
                  value: form['max_line_discount'] == null ? 100 : n(form['max_line_discount']),
                  options: [
                    for (final v in [100, 50, 30, 20, 10, 0]) (v, '$v%'),
                  ],
                  onChanged: ro ? null : (v) => set('max_line_discount', v),
                ),
                if (form['allow_offline'] == true) ...[
                  gap14,
                  SelectField<num>(
                    label: ctx.ps('maxOffline'),
                    hint: ctx.ps('maxOfflineHint'),
                    value: n(form['max_offline_hours']),
                    options: [
                      for (final h in [4, 12, 24, 72]) (h, ctx.ps('hours.$h')),
                    ],
                    onChanged: ro ? null : (v) => set('max_offline_hours', v),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (dirty)
                      TextButton.icon(onPressed: () => setState(() => _form = Json.from(obj(data['settings']))), icon: const Icon(LucideIcons.rotateCcw, size: 16), label: Text(ctx.r('cancel'))),
                    const Spacer(),
                    Btn(
                      _busy == 'save' ? ctx.r('saving') : ctx.r('save'),
                      small: true,
                      busy: _busy == 'save',
                      onTap: !dirty || ro || _busy == 'save'
                          ? null
                          : () => _act('save', () async {
                              final r = await ctx.api.put('${ctx.base}/pos/settings', form);
                              final s = obj(r['data']);
                              setState(() {
                                _data = {...data, 'settings': s};
                                _form = Json.from(s);
                              });
                            }, ctx.r('saved')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          gap14,
          // ---------------- recent shifts
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                  child: Text(ctx.ps('shifts'), style: Theme.of(context).textTheme.titleMedium),
                ),
                if (shifts.isEmpty) Padding(padding: const EdgeInsets.fromLTRB(20, 6, 20, 12), child: Muted(ctx.ps('noShifts'))),
                for (final (i, s) in shifts.indexed) ...[
                  if (i > 0) Divider(height: 1, color: c.line, indent: 16, endIndent: 16),
                  ShiftTile(ctx: ctx, s: s, device: _deviceName(devices, s), currency: cur),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _deviceName(List<Json> devices, Json s) {
    final d = devices.where((x) => str(x['_id']) == str(s['device_id'])).firstOrNull;
    return d == null ? '' : '${str(d['prefix'])} · ${str(d['name'])}';
  }

  Widget _device(Json d, bool ro) {
    final c = context.c;
    final seen = DateTime.tryParse(str(d['last_seen']));
    final online = seen != null && DateTime.now().difference(seen).inSeconds < 120;
    final sure = _sure == str(d['_id']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  str(d['prefix']),
                  style: TextStyle(fontWeight: FontWeight.w800, color: c.brandInk),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(str(d['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: online ? c.good : c.line, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            ctx.ps('lastSeen', {'t': _when(d['last_seen'])}) + (n(d['pending']) > 0 ? ' · ${ctx.ps('waiting', {'n': d['pending']})}' : ''),
                            style: TextStyle(color: n(d['pending']) > 0 ? c.warn : c.muted, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              RoundBtn(LucideIcons.pencil, size: 36, tip: ctx.ps('rename'), onTap: ro ? null : () => _rename(d)),
              const SizedBox(width: 6),
              RoundBtn(LucideIcons.unplug, size: 36, tip: ctx.ps('unlink'), fg: c.danger, onTap: ro ? null : () => setState(() => _sure = sure ? '' : str(d['_id']))),
            ],
          ),
          if (sure) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Btn(
                ctx.ps('unlinkSure'),
                kind: BtnKind.danger,
                small: true,
                busy: _busy == 'unlink',
                onTap: () => _act('unlink', () async {
                  await ctx.api.delete('${ctx.base}/pos/devices/${d['_id']}');
                  _sure = '';
                  await _load();
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mode(String k, Json form, bool ro) {
    final c = context.c;
    final on = '${form['sync_mode']}' == k;
    final risky = k == 'shift';
    final words = ctx.t.list('pos.modes.$k');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: ro ? null : () => setState(() => form['sync_mode'] = k),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: on ? (risky ? c.dangerBg : c.active) : c.bg2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: on ? (risky ? c.danger : c.brand) : c.line, width: on ? 1.5 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(on ? LucideIcons.circleCheck : LucideIcons.circle, size: 20, color: on ? (risky ? c.danger : c.brand) : c.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(words.isNotEmpty ? words[0] : k, style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (words.length > 1) ...[const SizedBox(height: 2), Text(words[1], style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.4))],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
