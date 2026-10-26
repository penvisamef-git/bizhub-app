import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../owner/data.dart';
import 'team_data.dart';
import 'team_text.dart';

// Around every business screen (/biz/...): in a business someone shared with me, a line on top says what I may do
// (View only / Admin). My own businesses show nothing extra. The API checks every change anyway.
class TeamFrame extends ConsumerWidget {
  final String id;
  final Widget child;
  const TeamFrame({super.key, required this.id, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = objs(ref.watch(dashboardProvider).valueOrNull?['businesses']).any((b) => str(b['_id']) == id);
    final shared = mine ? null : sharedOf(ref.watch(sharedProvider).valueOrNull, id);
    final view = shared != null && str(shared['role']) == 'view';
    markTeamViewOnly(id, view);
    if (shared == null) return child;
    final lang = ref.watch(tProvider).lang;
    final c = context.c;
    final bg = view ? c.limeBg : c.active;
    final fg = view ? c.limeInk : c.brandInk;
    return ColoredBox(
      color: c.appBg,
      child: Column(
        children: [
          Material(
            color: bg,
            child: SafeArea(
              bottom: false,
              child: Padding(
                key: ValueKey(view ? 'team-view-banner' : 'team-admin-banner'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Icon(view ? LucideIcons.eye : LucideIcons.shieldCheck, size: 16, color: fg),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        view ? tm(lang, 'viewBanner') : tm(lang, 'adminBanner', {'name': str(shared['owner_name'])}),
                        style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: MediaQuery.removePadding(context: context, removeTop: true, child: child),
          ),
        ],
      ),
    );
  }
}

// the owner's Team button at the top right of every business screen (web: the "Team" button on the business page)
class TeamTopBtn extends ConsumerWidget {
  final String id;
  final String name;
  const TeamTopBtn({super.key, required this.id, this.name = ''});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = objs(ref.watch(dashboardProvider).valueOrNull?['businesses']).any((b) => str(b['_id']) == id);
    if (!mine) return const SizedBox.shrink(); // team members don't manage the team
    final lang = ref.watch(tProvider).lang;
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Material(
        color: c.card,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          key: const ValueKey('team-top-btn'),
          borderRadius: BorderRadius.circular(999),
          onTap: () => context.push(Uri(path: '/o/team/$id', queryParameters: {if (name.isNotEmpty) 'name': name}).toString()),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), boxShadow: c.cardShadow),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.users, size: 17, color: c.ink),
                const SizedBox(width: 6),
                Text(tm(lang, 'teamBtn'), style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
