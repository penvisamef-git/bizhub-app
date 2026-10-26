import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';

// a row in a menu card: icon · text · (badge) · chevron
class MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback onTap;
  final bool danger;
  final Widget? trailing;
  final bool web; // opens a web screen
  const MenuRow({super.key, required this.icon, required this.label, required this.onTap, this.sub, this.danger = false, this.trailing, this.web = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final col = danger ? c.danger : c.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: danger ? c.dangerBg : c.active, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 18, color: danger ? c.danger : c.brandInk),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: col),
                  ),
                  if (sub != null) Text(sub!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            ?trailing,
            if (!danger) Icon(web ? LucideIcons.externalLink : LucideIcons.chevronRight, size: web ? 15 : 18, color: c.muted),
          ],
        ),
      ),
    );
  }
}

class MenuCard extends StatelessWidget {
  final String? title;
  final List<Widget> rows;
  const MenuCard({super.key, this.title, required this.rows});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            child: Text(title!, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 12.5)),
          ),
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                rows[i],
                if (i < rows.length - 1) Divider(height: 1, indent: 68, color: c.line),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// language + light/dark (Settings on the web)
class PreferencesCard extends ConsumerWidget {
  const PreferencesCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final p = ref.watch(prefsProvider);
    final c = context.c;
    Widget seg<V>(List<(V, String, IconData?)> items, V value, ValueChanged<V> onTap) => Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(999)),
      child: Row(
        children: [
          for (final it in items)
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(it.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: value == it.$1 ? c.card : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: value == it.$1 ? c.cardShadow : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (it.$3 != null) ...[Icon(it.$3, size: 15, color: value == it.$1 ? c.brandInk : c.muted), const SizedBox(width: 6)],
                      Flexible(
                        child: Text(
                          it.$2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: value == it.$1 ? c.ink : c.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
          child: Text(t('messages.settingsTitle'), style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 12.5)),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('messages.language'), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              seg<String>([('en', 'English', null), ('km', 'ខ្មែរ', null)], p.lang, ref.read(prefsProvider.notifier).setLang),
              const SizedBox(height: 16),
              Text(t('messages.theme'), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              seg<ThemeMode>(
                [(ThemeMode.light, t('messages.themeLight'), LucideIcons.sun), (ThemeMode.dark, t('messages.themeDark'), LucideIcons.moon), (ThemeMode.system, t('app.system'), LucideIcons.smartphone)],
                p.theme,
                ref.read(prefsProvider.notifier).setTheme,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> logout(BuildContext context, WidgetRef ref) async {
  final t = ref.read(tProvider);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t('messages.logout')),
      content: Text(t('app.logoutAsk')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('app.cancel'))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: ctx.c.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(t('messages.logout')),
        ),
      ],
    ),
  );
  if (ok != true) return;
  final s = ref.read(sessionProvider);
  try {
    // tell the API so this device's session ends (best effort)
    await ref.read(apiProvider).post(s?.team == true ? '${Api.admin}/auth/logout' : '${Api.user}/logout');
  } catch (_) {}
  await ref.read(sessionProvider.notifier).clear();
}
