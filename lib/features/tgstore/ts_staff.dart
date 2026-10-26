import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../event/ev_common.dart' show EvHead, EvList, askSure;
import '../restaurant/rest_common.dart' show SelectField;
import 'ts_common.dart';

// Staff screen (POS): the tablets / phones at the counter + the staff PINs (TsStaff.jsx)
//   GET /pos → { staff, devices, limits, free, more, url }
class StaffTab extends StatefulWidget {
  final TsCtx ctx;
  const StaffTab({super.key, required this.ctx});
  @override
  State<StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<StaffTab> {
  Json? _d;
  Json? _pair; // { code, expires_at, url, n }
  int _left = 0;
  String _busy = '';
  String _role = 'staff';
  String? _pinFor;
  final _name = TextEditingController();
  final _pin = TextEditingController();
  final _newPin = TextEditingController();
  Timer? _tick, _poll;
  TsCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _poll?.cancel();
    for (final x in [_name, _pin, _newPin]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/pos');
      if (mounted) setState(() => _d = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  // like the web: a full plan opens the add-on to buy
  Future<Json?> _run(String key, Future<Json> Function() fn, [String? ok]) async {
    setState(() => _busy = key);
    try {
      final r = await fn();
      if (ok != null) ctx.notify(str(r['message']).isNotEmpty ? str(r['message']) : ok);
      return r;
    } on ApiError catch (e) {
      if (e.status == 402 || e.body['code'] == 'device_limit' || e.body['code'] == 'staff_limit') {
        ctx.askBuy('ts_pos');
      } else {
        ctx.notify(e.network ? ctx.t('app.offline') : e.message);
      }
      return null;
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Future<void> _startPair() async {
    final r = await _run('pair', () => ctx.api.post('${ctx.base}/pos/pair-code'));
    if (r == null || !mounted) return;
    setState(() => _pair = {...obj(r['data']), 'n': objs(_d?['devices']).length});
    _tick?.cancel();
    _poll?.cancel();
    void count() {
      final exp = tsDate(_pair?['expires_at']);
      final s = exp == null ? 0 : exp.difference(DateTime.now()).inSeconds.clamp(0, 99999);
      if (!mounted) return;
      setState(() {
        _left = s;
        if (s == 0) {
          _pair = null;
          _tick?.cancel();
          _poll?.cancel();
        }
      });
    }

    count();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => count());
    // the screen that used the code shows up in the list
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  Future<void> _add() async {
    final r = await _run('add', () => ctx.api.post('${ctx.base}/pos/staff', {'name': _name.text.trim(), 'role': _role, 'pin': _pin.text}), ctx.m('saved'));
    if (r != null) {
      _name.clear();
      _pin.clear();
      setState(() => _role = 'staff');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = _d;
    final lim = obj(d?['limits']);
    final devices = objs(d?['devices']);
    final staff = objs(d?['staff']);
    final off = ctx.readOnly || _busy.isNotEmpty;
    return EvList(
      onRefresh: _load,
      children: [
        EvHead(
          ctx.m('tabs.staff'),
          sub: ctx.m('staffScreenSub'),
          trailing: d == null ? null : Btn(ctx.m('openScreen'), icon: LucideIcons.externalLink, small: true, kind: BtnKind.ghost, onTap: () => tsOpen(str(d['url']))),
        ),
        if (d == null)
          const SkelList(rows: 3)
        else ...[
          TsCard(
            children: [
              for (final (i, s) in ctx.t.list('ts.staffHow').indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${i + 1}. $s', style: TextStyle(color: c.muted, fontSize: 13.5)),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  TsPill(ctx.m('screensOf', {'n': devices.length, 'max': lim['devices']})),
                  TsPill(ctx.m('staffOf', {'n': staff.length, 'max': lim['staff']})),
                ],
              ),
              if (!ctx.on('ts_pos')) ...[const SizedBox(height: 10), TsLocked(ctx: ctx, addon: 'ts_pos', small: true)],
            ],
          ),
          TsCard(
            title: ctx.m('screens'),
            icon: LucideIcons.monitorSmartphone,
            children: [
              if (_pair != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(14)),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TsQr(str(_pair!['url']), size: 140),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(ctx.m('pairCode'), style: TextStyle(fontSize: 12.5, color: c.muted)),
                          Text(
                            '${str(_pair!['code']).substring(0, 3)} ${str(_pair!['code']).substring(3)}',
                            key: const ValueKey('ts-pair-code'),
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: 4),
                          ),
                          const SizedBox(height: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: Text(ctx.m('pairHint', {'url': str(_pair!['url']).split('?').first}), style: TextStyle(fontSize: 12, color: c.muted)),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              TsPill(ctx.m('pairLeft', {'m': _left ~/ 60, 's': (_left % 60).toString().padLeft(2, '0')})),
                              if (devices.length > n(_pair!['n'])) TsPill(ctx.m('pairedOk'), tone: Tone.good),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: Btn(ctx.m('pairScreen'), icon: LucideIcons.plus, small: true, busy: _busy == 'pair', onTap: off ? null : _startPair),
                ),
              const SizedBox(height: 12),
              if (devices.isEmpty)
                Muted(ctx.m('noScreens'))
              else
                for (final v in devices)
                  _row(
                    context,
                    lead: Icon(LucideIcons.monitorSmartphone, size: 20, color: c.muted),
                    title: str(v['name']),
                    sub: v['last_seen'] != null ? ctx.m('lastSeen', {'when': tsAgo(v['last_seen'], ctx.t)}) : '',
                    trailing: IconButton(
                      tooltip: ctx.m('remove'),
                      onPressed: off
                          ? null
                          : () async {
                              if (!await askSure(context, ctx.m('removeScreenAsk', {'name': v['name']}), ok: ctx.m('remove'), cancel: ctx.m('cancel'), danger: true)) return;
                              final r = await _run('rm', () => ctx.api.delete('${ctx.base}/pos/devices/${v['_id']}'), ctx.m('deleted'));
                              if (r != null) _load();
                            },
                      icon: const Icon(LucideIcons.trash2, size: 18),
                    ),
                  ),
            ],
          ),
          TsCard(
            title: ctx.m('staffPins'),
            icon: LucideIcons.userRound,
            children: [
              for (final s in staff)
                Opacity(
                  opacity: s['active'] == true ? 1 : .6,
                  child: _row(
                    context,
                    lead: Avatar(name: str(s['name']), size: 36),
                    title: str(s['name']),
                    sub: ctx.m('posRoles.${s['role']}'),
                    below: _pinFor == str(s['_id'])
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 130,
                                  child: Field(controller: _newPin, hint: '••••', keyboard: TextInputType.number, maxLength: 4, autofocus: true, onChanged: (v) => _digits(_newPin, v)),
                                ),
                                const SizedBox(width: 8),
                                Btn(
                                  ctx.m('save'),
                                  small: true,
                                  busy: _busy == 'pin',
                                  onTap: _newPin.text.length != 4 || _busy.isNotEmpty
                                      ? null
                                      : () async {
                                          final r = await _run('pin', () => ctx.api.put('${ctx.base}/pos/staff/${s['_id']}', {'pin': _newPin.text}), ctx.m('saved'));
                                          if (r != null) {
                                            setState(() {
                                              _pinFor = null;
                                              _newPin.clear();
                                            });
                                          }
                                        },
                                ),
                                IconButton(onPressed: () => setState(() => _pinFor = null), icon: const Icon(LucideIcons.x, size: 18)),
                              ],
                            ),
                          )
                        : null,
                    trailing: _pinFor == str(s['_id'])
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch.adaptive(
                                value: s['active'] == true,
                                onChanged: ctx.readOnly
                                    ? null
                                    : (v) async {
                                        final r = await _run('on', () => ctx.api.put('${ctx.base}/pos/staff/${s['_id']}', {'active': v}));
                                        if (r != null) _load();
                                      },
                              ),
                              IconButton(
                                tooltip: ctx.m('newPin'),
                                onPressed: ctx.readOnly
                                    ? null
                                    : () => setState(() {
                                        _pinFor = str(s['_id']);
                                        _newPin.clear();
                                      }),
                                icon: const Icon(LucideIcons.keyRound, size: 18),
                              ),
                              IconButton(
                                tooltip: ctx.m('remove'),
                                onPressed: ctx.readOnly
                                    ? null
                                    : () async {
                                        if (!await askSure(context, ctx.m('removeStaffAsk', {'name': s['name']}), ok: ctx.m('remove'), cancel: ctx.m('cancel'), danger: true)) return;
                                        final r = await _run('rm', () => ctx.api.delete('${ctx.base}/pos/staff/${s['_id']}'), ctx.m('deleted'));
                                        if (r != null) _load();
                                      },
                                icon: const Icon(LucideIcons.trash2, size: 18),
                              ),
                            ],
                          ),
                  ),
                ),
              if (staff.isNotEmpty) const SizedBox(height: 8),
              Field(label: ctx.m('staffName'), controller: _name, hint: ctx.m('staffNamePh'), maxLength: 60, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: SelectField<String>(
                      label: ctx.m('posRole'),
                      value: _role,
                      options: [('staff', ctx.m('posRoles.staff')), ('manager', ctx.m('posRoles.manager'))],
                      onChanged: ctx.readOnly ? null : (v) => setState(() => _role = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Field(
                      label: 'PIN',
                      controller: _pin,
                      hint: ctx.m('staffPinPh'),
                      keyboard: TextInputType.number,
                      maxLength: 4,
                      enabled: !ctx.readOnly,
                      onChanged: (v) => setState(() => _digits(_pin, v)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Btn(ctx.m('addStaff'), icon: LucideIcons.plus, small: true, busy: _busy == 'add', onTap: off || _name.text.trim().isEmpty || _pin.text.length != 4 ? null : _add),
              ),
              const SizedBox(height: 8),
              Text(ctx.m('posRoleHint'), style: TextStyle(fontSize: 12, color: c.muted)),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Btn(ctx.m('refresh'), icon: LucideIcons.refreshCw, small: true, kind: BtnKind.ghost, onTap: _load),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _digits(TextEditingController x, String v) {
    final d = v.replaceAll(RegExp(r'\D'), '');
    final s = d.length > 4 ? d.substring(0, 4) : d;
    if (s != v) {
      x.value = TextEditingValue(
        text: s,
        selection: TextSelection.collapsed(offset: s.length),
      );
    }
  }

  Widget _row(BuildContext context, {required Widget lead, required String title, String sub = '', Widget? trailing, Widget? below}) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              lead,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (sub.isNotEmpty) Text(sub, style: TextStyle(fontSize: 12, color: c.muted)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          ?below,
        ],
      ),
    );
  }
}
