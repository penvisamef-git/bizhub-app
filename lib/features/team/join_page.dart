import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../common/open_business.dart';
import '../common/shell.dart';
import 'team_data.dart';
import 'team_parts.dart';
import 'team_text.dart';

// /o/join/:code — someone opened an invite link (bizhubcambodia.com/app/join/AB12CD) or typed its code (web: JoinPage.jsx)
class JoinPage extends ConsumerStatefulWidget {
  final String code;
  const JoinPage({super.key, required this.code});
  @override
  ConsumerState<JoinPage> createState() => _JoinPageState();
}

class _JoinPageState extends ConsumerState<JoinPage> {
  Json? _info;
  String _error = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _msg(ApiError e) {
    final lang = ref.read(tProvider).lang;
    if (e.code == 'link_gone' || e.status == 410) return tm(lang, 'gone');
    return e.network ? ref.read(tProvider)('app.offline') : e.message;
  }

  Future<void> _load() async {
    setState(() => _error = '');
    try {
      final r = await ref.read(apiProvider).get('${Api.user}/team/join/${Uri.encodeComponent(widget.code)}');
      if (mounted) setState(() => _info = obj(r['data']));
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    }
  }

  void _open(Json b) {
    // the join page goes away: back from the business lands on the businesses list
    context.go('/o/business');
    openBusiness(context, id: str(b['_id']), name: str(b['name']), category: str(b['category']));
  }

  Future<void> _join() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await ref.read(apiProvider).post('${Api.user}/team/join/${Uri.encodeComponent(widget.code)}');
      ref.invalidate(sharedProvider);
      await ref.read(sharedProvider.future).catchError((_) => <String, dynamic>{});
      if (mounted) _open(obj(_info!['business']));
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final lang = t.lang;
    final c = context.c;
    final me = ref.watch(sessionProvider);
    final info = _info;
    final b = obj(info?['business']);
    final view = str(info?['role']) == 'view';
    final myId = str(me?.data['bizhub_id']);

    return SubPage(
      title: tm(lang, 'joinTitle'),
      children: [
        if (_error.isNotEmpty) ...[Alert(_error), const SizedBox(height: 14)],
        if (info == null && _error.isEmpty) const _JoinSkeleton(),
        if (info != null)
          Panel(
            key: const ValueKey('team-join'),
            child: Column(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(gradient: c.gradient, borderRadius: BorderRadius.circular(22)),
                  clipBehavior: Clip.antiAlias,
                  child: str(b['logo_url']).isNotEmpty ? Image(image: netImage(str(b['logo_url'])), fit: BoxFit.cover) : const Icon(LucideIcons.store, color: Colors.white, size: 34),
                ),
                const SizedBox(height: 12),
                Muted(tm(lang, 'joinInvites', {'name': str(info['owner_name'])}), align: TextAlign.center),
                Text(
                  str(b['name']),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Muted(t('sa.categoryNames.${b['category']}'), align: TextAlign.center),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(tm(lang, 'joinAs')),
                          const SizedBox(width: 8),
                          RoleBadge(str(info['role']), lang: lang),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _point(LucideIcons.check, c.good, view ? tm(lang, 'canSee') : tm(lang, 'canAll')),
                      const SizedBox(height: 6),
                      _point(LucideIcons.x, c.danger, view ? tm(lang, 'cantChange') : tm(lang, 'cantBuy')),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Muted(tm(lang, 'signedAs', {'name': me?.name ?? '', 'id': myId}).replaceAll(RegExp(r' · $'), ''), align: TextAlign.center),
                const SizedBox(height: 16),
                if (info['is_owner'] == true)
                  Muted(tm(lang, 'isOwner'), align: TextAlign.center)
                else if (str(info['already']) == 'active')
                  Btn('${tm(lang, 'already')} ${tm(lang, 'open')}', expand: true, onTap: () => _open(b))
                else ...[
                  Btn(tm(lang, 'acceptOpen'), key: const ValueKey('team-join-accept'), icon: LucideIcons.check, expand: true, busy: _busy, onTap: _join),
                  const SizedBox(height: 10),
                  Btn(tm(lang, 'decline'), kind: BtnKind.ghost, expand: true, onTap: () => context.go('/o/business')),
                ],
              ],
            ),
          ),
        if (info == null && _error.isNotEmpty) Btn(t('app.retry'), icon: LucideIcons.refreshCw, kind: BtnKind.ghost, onTap: _load),
      ],
    );
  }

  Widget _point(IconData icon, Color color, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 17, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(text)),
    ],
  );
}

class _JoinSkeleton extends StatelessWidget {
  const _JoinSkeleton();
  @override
  Widget build(BuildContext context) => const Panel(
    child: Column(
      children: [
        Skel(w: 76, h: 76, r: 22),
        SizedBox(height: 14),
        Skel(w: 150, h: 12),
        SizedBox(height: 8),
        Skel(w: 200, h: 22),
        SizedBox(height: 8),
        Skel(w: 120, h: 12),
        SizedBox(height: 16),
        Skel(h: 96, r: 16),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Skel(h: 50, r: 999)),
            SizedBox(width: 10),
            Expanded(child: Skel(h: 50, r: 999)),
          ],
        ),
      ],
    ),
  );
}
