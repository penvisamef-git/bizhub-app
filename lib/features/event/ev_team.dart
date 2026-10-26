import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show GoldBtn, MHead;
import '../restaurant/rest_common.dart' show SwitchRow;
import 'ev_common.dart';

// Team & door phones (the web's TeamTab): who scans at the door (each with a PIN and a role) and the paired phones.
//   GET /team → { members, devices, limits: { team, devices }, cashier } · POST/PUT/DELETE /team(/:mid) · POST /pair-code · DELETE /devices/:did
String doorUrl() => '${Config.siteUrl}/pos/event';

class TeamTab extends StatefulWidget {
  final EvCtx ctx;
  const TeamTab({super.key, required this.ctx});
  @override
  State<TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends State<TeamTab> {
  EvCtx get ctx => widget.ctx;
  Json? _t;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/team');
      if (mounted) setState(() => _t = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _pair() async {
    final r = await ctx.run(() => ctx.api.post('${ctx.base}/pair-code'));
    if (r == null || !mounted) return;
    final code = str(obj(r['data'])['code']);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (s) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            children: [
              Text(ctx.m('pairTitle'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Muted(ctx.m('pairSteps'), align: TextAlign.center),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: s.c.line),
                ),
                child: QrImageView(data: doorUrl(), size: 200, padding: EdgeInsets.zero, backgroundColor: Colors.white),
              ),
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => evCopy(ctx, doorUrl()),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(doorUrl(), style: TextStyle(color: s.c.muted, fontSize: 13)),
                      ),
                      const SizedBox(width: 6),
                      Icon(LucideIcons.copy, size: 14, color: s.c.muted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ctx.notify(ctx.m('copied'));
                },
                child: Text(
                  code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code,
                  style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, letterSpacing: 6, color: s.c.brandInk),
                ),
              ),
              const SizedBox(height: 16),
              Btn(ctx.t('app.continue'), expand: true, onTap: () => Navigator.pop(s)),
            ],
          ),
        ),
      ),
    );
    _load();
  }

  Future<void> _removeDevice(Json d) async {
    if (!await askSure(context, ctx.m('removeDeviceSure'), ok: ctx.m('remove'), cancel: ctx.m('cancel'), danger: true)) return;
    await ctx.run(() => ctx.api.delete('${ctx.base}/devices/${d['_id']}'));
    _load();
  }

  Future<void> _member([Json? m]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _MemberSheet(ctx: ctx, m: m, cashier: _t?['cashier'] == true),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = _t;
    if (t == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 5));
    final members = objs(t['members']);
    final devices = objs(t['devices']);
    final lim = obj(t['limits']);
    final active = members.where((m) => m['active'] == true).length;
    final teamFull = active >= n(lim['team']) && !ctx.on('ev_team');
    final doorsFull = devices.length >= n(lim['devices']) && !ctx.on('ev_doors');
    Widget roleChip(String r) {
      final (bg, fg) = switch (r) {
        'manager' => (c.active, c.brandInk),
        'cashier' => (c.goodBg, c.good),
        'crew' => (c.warnBg, c.warn),
        _ => (c.chip, c.muted),
      };
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(
          ctx.m('roles.$r'),
          style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 11.5),
        ),
      );
    }

    return EvList(
      onRefresh: _load,
      children: [
        Panel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MHead(ctx.m('teamTitle'), sub: ctx.m('teamSub'), icon: LucideIcons.users),
              Btn(ctx.m('scannerLink'), icon: LucideIcons.copy, kind: BtnKind.ghost, small: true, onTap: () => evCopy(ctx, doorUrl())),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // the team
        Panel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(ctx.m('teamCount', {'n': active, 'max': n(lim['team']).toInt()}), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                  if (teamFull)
                    GoldBtn(ctx.m('addonNames.ev_team'), onTap: ctx.readOnly ? null : () => ctx.askBuy('ev_team'))
                  else
                    Btn(ctx.m('addMember'), icon: LucideIcons.plus, small: true, onTap: ctx.readOnly ? null : () => _member()),
                ],
              ),
              const SizedBox(height: 10),
              if (members.isEmpty) Muted(ctx.m('roleWhat.door')),
              for (final m in members)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: ctx.readOnly ? null : () => _member(m),
                    child: Opacity(
                      opacity: m['active'] == true ? 1 : .55,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        child: Row(
                          children: [
                            Avatar(name: str(m['name']), size: 40),
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
                                          style: const TextStyle(fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      roleChip(str(m['role'])),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    m['active'] == true ? ctx.m('roleWhat.${m['role']}') : ctx.m('memberOff'),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12.5, color: c.muted),
                                  ),
                                ],
                              ),
                            ),
                            Icon(LucideIcons.chevronRight, size: 16, color: c.muted),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // the door phones
        Panel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(ctx.m('devicesCount', {'n': devices.length, 'max': n(lim['devices']).toInt()}), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                  if (doorsFull)
                    GoldBtn(ctx.m('addonNames.ev_doors'), onTap: ctx.readOnly ? null : () => ctx.askBuy('ev_doors'))
                  else
                    Btn(ctx.m('pairPhone'), icon: LucideIcons.smartphone, small: true, onTap: ctx.readOnly ? null : _pair),
                ],
              ),
              const SizedBox(height: 6),
              for (final d in devices)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(12)),
                        child: Icon(LucideIcons.smartphone, size: 19, color: c.brandInk),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(str(d['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(
                              d['last_seen'] != null ? ctx.m('lastSeen', {'t': evWhen(d['last_seen'], ctx.lang, year: false)}) : ctx.m('neverSeen'),
                              style: TextStyle(fontSize: 12.5, color: c.muted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: ctx.m('removeDevice'),
                        onPressed: ctx.readOnly ? null : () => _removeDevice(d),
                        icon: Icon(LucideIcons.trash2, size: 17, color: c.danger),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberSheet extends StatefulWidget {
  final EvCtx ctx;
  final Json? m;
  final bool cashier;
  const _MemberSheet({required this.ctx, this.m, required this.cashier});
  @override
  State<_MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends State<_MemberSheet> {
  EvCtx get ctx => widget.ctx;
  late final _name = TextEditingController(text: str(widget.m?['name']));
  final _pin = TextEditingController();
  late String _role = str(widget.m?['role']).isEmpty ? 'door' : str(widget.m?['role']);
  late bool _active = widget.m == null || widget.m!['active'] == true;
  String _busy = '', _error = '';

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    super.dispose();
  }

  bool get _ok {
    final pin = _pin.text.trim();
    if (_name.text.trim().isEmpty) return false;
    if (widget.m == null) return RegExp(r'^\d{4}$').hasMatch(pin);
    return pin.isEmpty || RegExp(r'^\d{4}$').hasMatch(pin);
  }

  Future<void> _go(String which, Future<Json> Function() fn) async {
    setState(() {
      _busy = which;
      _error = '';
    });
    try {
      await fn();
      ctx.notify(ctx.m('saved'));
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      if (e.status == 402 && e.body['product'] != null) {
        if (mounted) Navigator.pop(context, false);
        ctx.askBuy(str(e.body['product']));
        return;
      }
      setState(() {
        _busy = '';
        _error = e.network ? ctx.t('app.offline') : e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final m = widget.m;
    final pin = _pin.text.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(m == null ? ctx.m('addMember') : str(m['name']), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              Field(label: ctx.m('memberName'), controller: _name, maxLength: 60, onChanged: (_) => setState(() {})),
              const SizedBox(height: 14),
              Text(
                ctx.m('memberRole'),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: c.ink),
              ),
              const SizedBox(height: 8),
              for (final r in ['door', 'crew', 'cashier', 'manager'])
                Builder(
                  builder: (_) {
                    final locked = r == 'cashier' && !widget.cashier;
                    final on = _role == r;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: on ? c.active : c.bg2,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            if (locked) {
                              Navigator.pop(context, false);
                              ctx.askBuy('ev_cashier');
                              return;
                            }
                            setState(() => _role = r);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: on ? c.brand : c.line, width: on ? 1.6 : 1),
                            ),
                            child: Row(
                              children: [
                                Icon(on ? LucideIcons.circleCheck : (locked ? LucideIcons.lock : LucideIcons.circle), size: 18, color: on ? c.brand : c.muted),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ctx.m('roles.$r'),
                                        style: TextStyle(fontWeight: FontWeight.w800, color: on ? c.brandInk : c.ink),
                                      ),
                                      Text(ctx.m('roleWhat.$r'), style: TextStyle(fontSize: 12.5, color: c.muted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 6),
              Field(
                label: m == null ? ctx.m('memberPin') : ctx.m('memberPinKeep'),
                controller: _pin,
                hint: '••••',
                keyboard: TextInputType.number,
                maxLength: 4,
                invalid: pin.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(pin),
                onChanged: (_) => setState(() {}),
              ),
              if (m != null) ...[const SizedBox(height: 8), SwitchRow(title: _active ? ctx.m('roles.$_role') : ctx.m('memberOff'), value: _active, onChanged: (v) => setState(() => _active = v))],
              if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Alert(_error)),
              const SizedBox(height: 16),
              Btn(
                ctx.m('save'),
                icon: LucideIcons.save,
                expand: true,
                busy: _busy == 'save',
                onTap: !_ok || _busy.isNotEmpty
                    ? null
                    : () => _go('save', () {
                        final body = {'name': _name.text.trim(), 'role': _role, if (m != null) 'active': _active, if (pin.isNotEmpty) 'pin': pin};
                        return m == null ? ctx.api.post('${ctx.base}/team', body) : ctx.api.put('${ctx.base}/team/${m['_id']}', body);
                      }),
              ),
              if (m != null) ...[
                const SizedBox(height: 8),
                Btn(
                  ctx.m('remove'),
                  icon: LucideIcons.trash2,
                  kind: BtnKind.danger,
                  expand: true,
                  busy: _busy == 'remove',
                  onTap: _busy.isNotEmpty
                      ? null
                      : () async {
                          if (!await askSure(context, ctx.m('removeMemberSure'), ok: ctx.m('remove'), cancel: ctx.m('cancel'), danger: true)) return;
                          _go('remove', () => ctx.api.delete('${ctx.base}/team/${m['_id']}'));
                        },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
