import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/crash.dart';
import '../../core/config.dart';
import '../../core/providers.dart';
import '../../widgets/ui.dart';
import '../common/settings_parts.dart';
import '../common/shell.dart';
import '../updates/updates_page.dart' show updatesText;

// "More" of the owner bottom bar (the web's more sheet)
class OwnerMorePage extends ConsumerWidget {
  const OwnerMorePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final s = ref.watch(sessionProvider);
    return TabPage(
      children: [
        Panel(
          onTap: () => context.push('/account'),
          child: Row(
            children: [
              Avatar(name: s?.name ?? '', photo: s?.photo ?? '', size: 54, brand: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s?.name ?? '', style: Theme.of(context).textTheme.titleMedium),
                    Text((s?.phone.isNotEmpty ?? false) ? s!.phone : (s?.email ?? ''), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight, size: 18),
            ],
          ),
        ),
        const SizedBox(height: 18),
        MenuCard(
          rows: [
            MenuRow(icon: LucideIcons.badgeCheck, label: t('messages.navLicenses'), onTap: () => context.push('/o/licenses')),
            MenuRow(icon: LucideIcons.plus, label: t('messages.addBusiness'), onTap: () => context.push('/o/add')),
            MenuRow(icon: LucideIcons.coins, label: t('coin.title'), onTap: () => context.push('/o/coins')),
            MenuRow(icon: LucideIcons.userRound, label: t('messages.navAccount'), sub: t('messages.accountLink'), onTap: () => context.push('/account')),
            MenuRow(icon: LucideIcons.messageCircle, label: t('messages.navSupport'), onTap: () => context.push('/o/support')),
            MenuRow(icon: LucideIcons.history, label: updatesText(t.lang, 'title'), onTap: () => context.push('/updates')),
          ],
        ),
        const SizedBox(height: 18),
        const PreferencesCard(),
        const SizedBox(height: 18),
        MenuCard(
          rows: [
            MenuRow(
              icon: LucideIcons.fileText,
              label: t('messages.terms'),
              web: true,
              onTap: () => launchUrl(Uri.parse('${Config.siteUrl}/terms'), mode: LaunchMode.externalApplication),
            ),
            MenuRow(
              icon: LucideIcons.shieldCheck,
              label: t('messages.privacy'),
              web: true,
              onTap: () => launchUrl(Uri.parse('${Config.siteUrl}/privacy'), mode: LaunchMode.externalApplication),
            ),
            MenuRow(icon: LucideIcons.userX, label: t('messages.deleteAccountLink'), onTap: () => context.push('/account')),
            MenuRow(icon: LucideIcons.logOut, label: t('messages.logout'), danger: true, onTap: () => logout(context, ref)),
          ],
        ),
        const SizedBox(height: 18),
        Center(child: Muted(t('app.version', {'v': AppInfo.full}))),
      ],
    );
  }
}
