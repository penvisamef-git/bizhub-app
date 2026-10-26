import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/buy_sheet.dart';
import '../../widgets/ui.dart';
import '../common/shell.dart';
import 'add_member_sheet.dart';
import 'team_data.dart';
import 'team_parts.dart';
import 'team_text.dart';

// /o/team/:id — the owner adds people to one business as Admin or View only (web: dashboard/client/team/TeamPage.jsx)
class TeamPage extends ConsumerStatefulWidget {
  final String id;
  final String name;
  const TeamPage({super.key, required this.id, this.name = ''});
  @override
  ConsumerState<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends ConsumerState<TeamPage> {
  String _busy = '';

  String get _lang => ref.read(tProvider).lang;
  String x(String k, [Map<String, Object?> v = const {}]) => tm(_lang, k, v);

  Future<void> _reload() async {
    ref.invalidate(teamProvider(widget.id));
    try {
      await ref.read(teamProvider(widget.id).future);
    } catch (_) {}
  }

  Future<void> _run(String key, Future<Json> Function() fn, {String? ok}) async {
    setState(() => _busy = key);
    try {
      await fn();
      await _reload();
      if (mounted && ok != null) toast(context, ok);
    } on ApiError catch (e) {
      if (mounted) toast(context, e.network ? ref.read(tProvider)('app.offline') : e.message);
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Future<void> _unlock(Json data) async {
    final lang = _lang;
    final price = n(data['price']);
    final lic = obj(data['license']);
    final name = widget.name.isNotEmpty ? widget.name : str(obj(data['business'])['name']);
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BuySheet(
        stage: Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF9A52), Color(0xFFE0581A)]),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.users, color: Colors.white, size: 54),
              const SizedBox(height: 8),
              Text(
                tm(lang, 'team'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
              ),
              if (name.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        badge: tm(lang, 'team'),
        title: tm(lang, 'lockedTitle'),
        sub: tm(lang, 'lockedSub'),
        perks: [tm(lang, 'lockedPoints.0'), tm(lang, 'lockedPoints.1'), tm(lang, 'lockedPoints.2')],
        price: price,
        buyLabel: tm(lang, 'payLabel', {'price': fmt(price)}),
        doneTitle: tm(lang, 'team'),
        doneSub: tm(lang, 'paidSub'),
        doneButton: ref.read(tProvider)('app.continue'),
        buy: () => ref.read(apiProvider).post('${Api.user}/businesses/${widget.id}/licenses/team', {if (lic['expires_at'] != null) 'expect': lic['expires_at']}),
        onDone: (_) => ref.invalidate(teamProvider(widget.id)),
      ),
    );
  }

  Future<void> _add() async {
    final sent = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddMemberSheet(businessId: widget.id, onChanged: () => ref.invalidate(teamProvider(widget.id))),
    );
    if (sent == 'invited' && mounted) toast(context, x('inviteSent'));
  }

  Future<void> _role(Json m) async {
    final lang = _lang;
    final now = str(m['role']);
    final pick = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (d) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text('${tm(lang, 'changeRole')} · ${str(obj(m['person'])['name'])}', style: Theme.of(d).textTheme.titleMedium),
              ),
              for (final r in const ['admin', 'view'])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RoleCard(role: r, on: r == now, lang: lang, onTap: () => Navigator.pop(d, r)),
                ),
            ],
          ),
        ),
      ),
    );
    if (pick == null || pick == now) return;
    await _run('role-${m['_id']}', () => ref.read(apiProvider).patch('${Api.user}/businesses/${widget.id}/team/members/${m['_id']}', {'role': pick}));
  }

  Future<void> _remove(Json m) async {
    final ok = await teamConfirm(context, title: x('removeAsk', {'name': str(obj(m['person'])['name'])}), yes: x('remove'), no: x('cancelLink'));
    if (!ok) return;
    await _run('rm-${m['_id']}', () => ref.read(apiProvider).delete('${Api.user}/businesses/${widget.id}/team/members/${m['_id']}'));
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final lang = t.lang;
    final c = context.c;
    final me = ref.watch(sessionProvider);
    final team = ref.watch(teamProvider(widget.id));
    final data = team.valueOrNull;
    final name = widget.name.isNotEmpty ? widget.name : str(obj(data?['business'])['name']);
    final lic = obj(data?['license']);
    final on = lic['active'] == true;
    final members = objs(data?['members']);
    final links = objs(data?['links']);

    return SubPage(
      title: tm(lang, 'team'),
      onRefresh: _reload,
      bottom: data != null && on ? Btn(tm(lang, 'add'), icon: LucideIcons.userPlus, expand: true, onTap: _add) : null,
      children: [
        if (name.isNotEmpty)
          Text(
            name,
            style: TextStyle(color: c.muted, fontWeight: FontWeight.w700),
          ),
        Muted(tm(lang, 'teamSub')),
        const SizedBox(height: 16),
        if (data == null && team.hasError)
          LoadError(text: team.error is ApiError ? '${team.error}' : t('app.offline'), retry: t('app.retry'), onRetry: _reload)
        else if (data == null)
          const TeamSkeleton()
        else if (!on) ...[
          Panel(
            key: const ValueKey('team-locked'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.users, size: 30, color: c.brand),
                const SizedBox(height: 10),
                Text(tm(lang, 'lockedTitle'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Muted(tm(lang, 'lockedSub')),
                const SizedBox(height: 12),
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(LucideIcons.check, size: 17, color: c.brand),
                        const SizedBox(width: 10),
                        Expanded(child: Text(tm(lang, 'lockedPoints.$i'))),
                      ],
                    ),
                  ),
                if (str(lic['status']) == 'expired') ...[
                  const SizedBox(height: 6),
                  Alert(tm(lang, 'expired', {'date': fmtDate(lic['expires_at'], lang: lang)}), tone: Tone.warn),
                ],
                const SizedBox(height: 14),
                Btn(tm(lang, str(lic['status']) == 'expired' ? 'renew' : 'unlock', {'price': fmt(data['price'])}), icon: LucideIcons.users, expand: true, onTap: () => _unlock(data)),
                if (members.isNotEmpty) ...[const SizedBox(height: 10), Muted(teamCount(lang, members.length))],
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Icon(LucideIcons.check, size: 17, color: c.good),
                const SizedBox(width: 10),
                Expanded(child: Text(lic['forever'] == true ? tm(lang, 'team') : tm(lang, 'ends', {'date': fmtDate(lic['expires_at'], lang: lang)}))),
                if (str(lic['status']) == 'expiring') Btn(tm(lang, 'renew', {'price': fmt(data['price'])}), small: true, kind: BtnKind.ghost, onTap: () => _unlock(data)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sec(context, tm(lang, 'members')),
          Panel(
            key: const ValueKey('team-members'),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _row(
                  context,
                  lead: Avatar(name: me?.name ?? '', photo: me?.photo ?? '', size: 42),
                  title: '${me?.name ?? ''} (${tm(lang, 'you')})',
                  trailing: RoleBadge('owner', lang: lang),
                ),
                if (members.isEmpty) ...[Divider(height: 1, color: c.line), Padding(padding: const EdgeInsets.all(16), child: Muted(tm(lang, 'none')))],
                for (final m in members) ...[Divider(height: 1, indent: 70, color: c.line), _member(context, m, lang)],
              ],
            ),
          ),
          if (links.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sec(context, tm(lang, 'openLinks')),
            Panel(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < links.length; i++) ...[
                    if (i > 0) Divider(height: 1, indent: 70, color: c.line),
                    _row(
                      context,
                      lead: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: c.chip, shape: BoxShape.circle),
                        child: Icon(LucideIcons.link2, size: 18, color: c.ink),
                      ),
                      title: str(links[i]['role']) == 'admin' ? tm(lang, 'admin') : tm(lang, 'view'),
                      sub: '${links[i]['code']} · ${tm(lang, 'endsOn', {'date': fmtDate(links[i]['expires_at'], lang: lang)})}',
                      trailing: TextButton(
                        onPressed: _busy.isNotEmpty
                            ? null
                            : () => _run('lk-${links[i]['_id']}', () => ref.read(apiProvider).delete('${Api.user}/businesses/${widget.id}/team/links/${links[i]['_id']}')),
                        child: Text(tm(lang, 'cancelLink')),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Muted(tm(lang, 'ownerOnlyNote')),
        ],
      ],
    );
  }

  Widget _sec(BuildContext context, String s) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(s.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 12, letterSpacing: .6)),
  );

  Widget _row(BuildContext context, {required Widget lead, required String title, String sub = '', Widget? trailing}) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
    child: Row(
      children: [
        lead,
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (sub.isNotEmpty) Text(sub, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );

  Widget _member(BuildContext context, Json m, String lang) {
    final p = obj(m['person']);
    final invited = str(m['status']) == 'invited';
    final sub = [
      str(p['bizhub_id']),
      invited ? tm(lang, 'invited') : tm(lang, 'joined', {'date': fmtDate(m['joined_at'], lang: lang)}),
      if (!invited && str(m['via']) == 'link') tm(lang, 'viaLink'),
    ].where((s) => s.isNotEmpty).join(' · ');
    final busy = _busy.endsWith('${m['_id']}');
    return _row(
      context,
      lead: Avatar(name: str(p['name']), photo: photoUrl(p['photo']), size: 42),
      title: str(p['name']),
      sub: sub,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            key: ValueKey('team-role-${m['_id']}'),
            borderRadius: BorderRadius.circular(999),
            onTap: busy ? null : () => _role(m),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RoleBadge(str(m['role']), lang: lang),
                  const SizedBox(width: 2),
                  Icon(LucideIcons.chevronDown, size: 15, color: context.c.muted),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: tm(lang, 'remove'),
            onPressed: busy ? null : () => _remove(m),
            icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(LucideIcons.trash2, size: 17, color: context.c.muted),
          ),
        ],
      ),
    );
  }
}
