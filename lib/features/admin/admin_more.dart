import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/crash.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../common/settings_parts.dart';
import '../common/shell.dart';
import '../updates/changelog.dart' show bizhubVersion;
import '../updates/updates_page.dart' show updatesText;
import 'admin_parts.dart';

// "More" of the super admin bottom bar — the rest of SUPER_NAV + the BizHub team pages
class AdminMorePage extends ConsumerWidget {
  const AdminMorePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final s = ref.watch(sessionProvider);
    final badges = ref.watch(badgesProvider).valueOrNull;
    Widget badge(Object? v) => n(v) > 0
        ? Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: context.c.brand, borderRadius: BorderRadius.circular(999)),
            child: Text(
              '$v',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          )
        : const SizedBox.shrink();
    return TabPage(
      onRefresh: () async => ref.invalidate(badgesProvider),
      children: [
        Panel(
          onTap: () => context.push('/account'),
          child: Row(
            children: [
              Avatar(name: s?.name ?? '', size: 54, brand: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s?.name ?? '', style: Theme.of(context).textTheme.titleMedium),
                    Text(t('messages.superAdmin'), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight, size: 18),
            ],
          ),
        ),
        const SizedBox(height: 18),
        MenuCard(
          title: t('messages.superAdmin'),
          rows: [
            MenuRow(icon: LucideIcons.receiptText, label: t('messages.navCoinOrders'), trailing: badge(badges?['orders']), onTap: () => context.push('/a/orders')),
            MenuRow(icon: LucideIcons.inbox, label: t('messages.navInbox'), trailing: badge(badges?['chats']), onTap: () => context.push('/a/inbox')),
            MenuRow(icon: LucideIcons.badgeCheck, label: t('messages.navLicenses'), onTap: () => context.push('/a/licenses')),
            MenuRow(icon: LucideIcons.tags, label: t('messages.navPrices'), onTap: () => context.push('/a/prices')),
            MenuRow(icon: LucideIcons.calendarHeart, label: t('messages.navHolidays'), onTap: () => context.push('/a/holidays')),
            MenuRow(icon: LucideIcons.globe, label: t('messages.navWebsite'), onTap: () => context.push('/a/homepage')),
          ],
        ),
        const SizedBox(height: 18),
        MenuCard(
          title: t('messages.adminSection'),
          rows: [
            MenuRow(icon: LucideIcons.usersRound, label: t('messages.navUsers'), onTap: () => context.push('/a/users')),
            MenuRow(icon: LucideIcons.activity, label: t('messages.navActivity'), onTap: () => context.push('/a/activity')),
            MenuRow(icon: LucideIcons.bug, label: t('app.errPage'), onTap: () => context.push('/a/errors')),
          ],
        ),
        const SizedBox(height: 18),
        const PreferencesCard(),
        const SizedBox(height: 18),
        MenuCard(
          rows: [
            MenuRow(icon: LucideIcons.userRound, label: t('messages.navAccount'), onTap: () => context.push('/account')),
            MenuRow(icon: LucideIcons.history, label: updatesText(t.lang, 'title'), sub: 'v$bizhubVersion', onTap: () => context.push('/updates')),
            MenuRow(icon: LucideIcons.logOut, label: t('messages.logout'), danger: true, onTap: () => logout(context, ref)),
          ],
        ),
        const SizedBox(height: 18),
        Center(child: Muted(t('app.version', {'v': AppInfo.full}))),
      ],
    );
  }
}
