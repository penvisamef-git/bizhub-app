import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../common/open_business.dart';
import 'team_data.dart';
import 'team_parts.dart';
import 'team_text.dart';

// "Shared with me" under the owner's businesses: businesses other owners added me to, invites to accept, and
// "Join with a code" (web: SharedSection.jsx)
class SharedSection extends ConsumerStatefulWidget {
  const SharedSection({super.key});
  @override
  ConsumerState<SharedSection> createState() => _SharedSectionState();
}

class _SharedSectionState extends ConsumerState<SharedSection> {
  String _busy = '';

  Future<void> _act(String key, Future<Json> Function() fn, {VoidCallback? then}) async {
    setState(() => _busy = key);
    try {
      await fn();
      ref.invalidate(sharedProvider);
      await ref.read(sharedProvider.future);
      then?.call();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.network ? ref.read(tProvider)('app.offline') : e.message);
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Future<void> _joinCode() async {
    final code = await showModalBottomSheet<String>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => const JoinCodeSheet());
    if (code != null && mounted) context.push('/o/join/$code');
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final lang = t.lang;
    final c = context.c;
    final data = ref.watch(sharedProvider).valueOrNull;
    final list = objs(data?['businesses']);
    final invites = objs(data?['invites']);
    final api = ref.read(apiProvider);

    final join = Panel(
      key: const ValueKey('team-join-code'),
      onTap: _joinCode,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(12)),
            child: Icon(LucideIcons.ticket, size: 18, color: c.brandInk),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tm(lang, 'joinCode'), style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(tm(lang, 'joinCodeSub'), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight, size: 18),
        ],
      ),
    );

    if (list.isEmpty && invites.isEmpty) return Padding(padding: const EdgeInsets.only(top: 18), child: join);

    Widget row(Json b, {List<Widget> actions = const [], List<Widget> below = const [], VoidCallback? onTap, bool paused = false}) => InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            BizLogo(name: str(b['name']), logo: str(b['logo_url'])),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    str(b['name']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    paused ? tm(lang, 'paused') : '${t('sa.categoryNames.${b['category']}')} · ${tm(lang, 'sharedBy', {'name': str(b['owner_name'])})}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: paused ? c.warn : null),
                  ),
                  const SizedBox(height: 4),
                  RoleBadge(str(b['role']), lang: lang),
                  if (below.isNotEmpty) ...[const SizedBox(height: 10), Row(children: below)],
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        key: const ValueKey('team-shared'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SecHead(tm(lang, 'shared'), sub: tm(lang, 'sharedNote')),
          if (invites.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(tm(lang, 'invites').toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 12, letterSpacing: .6)),
            ),
            Panel(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < invites.length; i++) ...[
                    if (i > 0) Divider(height: 1, indent: 68, color: c.line),
                    KeyedSubtree(
                      key: ValueKey('team-invite-${invites[i]['member_id']}'),
                      child: row(
                        invites[i],
                        below: [
                          Btn(
                            tm(lang, 'decline'),
                            kind: BtnKind.ghost,
                            small: true,
                            onTap: _busy.isNotEmpty ? null : () => _act('no${invites[i]['member_id']}', () => api.post('${Api.user}/team/invites/${invites[i]['member_id']}/decline')),
                          ),
                          const SizedBox(width: 8),
                          Btn(
                            tm(lang, 'accept'),
                            key: ValueKey('team-accept-${invites[i]['member_id']}'),
                            icon: LucideIcons.check,
                            small: true,
                            busy: _busy == 'yes${invites[i]['member_id']}',
                            onTap: _busy.isNotEmpty
                                ? null
                                : () {
                                    final b = invites[i];
                                    _act(
                                      'yes${b['member_id']}',
                                      () => api.post('${Api.user}/team/invites/${b['member_id']}/accept'),
                                      then: () => mounted ? openBusiness(context, id: str(b['_id']), name: str(b['name']), category: str(b['category'])) : null,
                                    );
                                  },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (list.isNotEmpty)
            Panel(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) Divider(height: 1, indent: 68, color: c.line),
                    KeyedSubtree(
                      key: ValueKey('team-shared-${list[i]['_id']}'),
                      child: row(
                        list[i],
                        paused: list[i]['team_on'] != true,
                        onTap: list[i]['team_on'] == true ? () => openBusiness(context, id: str(list[i]['_id']), name: str(list[i]['name']), category: str(list[i]['category'])) : null,
                        actions: [
                          IconButton(
                            tooltip: tm(lang, 'leave'),
                            onPressed: _busy.isNotEmpty
                                ? null
                                : () async {
                                    final b = list[i];
                                    final ok = await teamConfirm(context, title: tm(lang, 'leaveAsk', {'name': str(b['name'])}), yes: tm(lang, 'leave'), no: tm(lang, 'cancelLink'));
                                    if (ok) await _act('lv${b['_id']}', () => api.post('${Api.user}/team/shared/${b['_id']}/leave'));
                                  },
                            icon: Icon(LucideIcons.logOut, size: 17, color: c.muted),
                          ),
                          if (list[i]['team_on'] == true) Icon(LucideIcons.chevronRight, size: 18, color: c.muted),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),
          join,
        ],
      ),
    );
  }
}

// type the code of an invite link (or paste the whole link)
class JoinCodeSheet extends ConsumerStatefulWidget {
  const JoinCodeSheet({super.key});
  @override
  ConsumerState<JoinCodeSheet> createState() => _JoinCodeSheetState();
}

class _JoinCodeSheetState extends ConsumerState<JoinCodeSheet> {
  final _code = TextEditingController();
  String _error = '';
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _go() {
    final code = joinCodeOf(_code.text);
    if (code == null) return setState(() => _error = tm(ref.read(tProvider).lang, 'wrongCode'));
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(tProvider).lang;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tm(lang, 'joinCode'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Muted(tm(lang, 'joinCodeSub')),
            const SizedBox(height: 16),
            Field(
              key: const ValueKey('team-code'),
              label: tm(lang, 'codeLabel'),
              hint: tm(lang, 'codePh'),
              controller: _code,
              icon: LucideIcons.ticket,
              autofocus: true,
              invalid: _error.isNotEmpty,
              onChanged: (_) => _error.isEmpty ? null : setState(() => _error = ''),
              onSubmit: (_) => _go(),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _error,
                style: TextStyle(color: context.c.danger, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 16),
            Btn(tm(lang, 'next'), key: const ValueKey('team-code-next'), icon: LucideIcons.arrowRight, expand: true, onTap: _go),
          ],
        ),
      ),
    );
  }
}
