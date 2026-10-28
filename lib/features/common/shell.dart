import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../bizi/bizi_bubble.dart';
import '../owner/coin_play.dart' show playCoinsBoot;

// the coin number in the header (owner: own balance · super admin: treasury)
final treasuryProvider = StateProvider<num?>((_) => null);

class NavTab {
  final IconData icon;
  final String label;
  const NavTab(this.icon, this.label);
}

// Same frame as the web on a phone: header (logo · page title + date · coins · theme · me)
// and the floating bottom bar with the orange pill on the open tab.
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell nav;
  final bool admin;
  const AppShell({super.key, required this.nav, required this.admin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    if (!admin) playCoinsBoot(ref); // Android: add coins of Google Play purchases that weren't finished (once per run)
    final tabs = admin
        ? [
            NavTab(LucideIcons.layoutDashboard, t('messages.navDashboard')),
            NavTab(LucideIcons.users, t('messages.navCustomers')),
            NavTab(LucideIcons.building2, t('messages.navBusinesses')),
            NavTab(LucideIcons.coins, t('messages.navCoins')),
            NavTab(LucideIcons.ellipsis, t('messages.navMore')),
          ]
        : [
            NavTab(LucideIcons.layoutDashboard, t('messages.navDashboard')),
            NavTab(LucideIcons.store, t('messages.navBusinesses')),
            NavTab(LucideIcons.wallet, t('messages.navWallet')),
            NavTab(LucideIcons.ellipsis, t('messages.navMore')),
          ];
    final page = Scaffold(
      extendBody: true,
      body: Column(
        children: [
          AppHeader(title: tabs[nav.currentIndex].label, admin: admin),
          Expanded(child: nav),
        ],
      ),
      bottomNavigationBar: BottomBar(
        tabs: tabs,
        index: nav.currentIndex,
        onTap: (i) => nav.goBranch(i, initialLocation: i == nav.currentIndex),
      ),
    );
    if (admin) return page;
    // Bizi (v3.0.0) floats over the owner's tabs — tap to search, hold and drag to move it
    return Stack(
      children: [
        page,
        const Positioned.fill(child: Material(type: MaterialType.transparency, child: BiziBubble())),
      ],
    );
  }
}

class AppHeader extends ConsumerWidget {
  final String title;
  final bool admin;
  const AppHeader({super.key, required this.title, required this.admin});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final s = ref.watch(sessionProvider);
    final prefs = ref.watch(prefsProvider);
    final treasury = ref.watch(treasuryProvider);
    final coins = admin ? treasury : s?.coins;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Row(
          children: [
            const Logo(height: 34, iconOnly: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
                  ),
                  Text(
                    fmtToday(prefs.lang),
                    maxLines: 1,
                    style: TextStyle(fontSize: 12.5, color: c.muted, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            if (coins != null)
              GestureDetector(
                onTap: () => admin ? context.go('/a/coins') : context.go('/o/wallet'),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
                  decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(999), boxShadow: c.cardShadow),
                  child: Row(
                    children: [
                      const CoinIcon(size: 26),
                      const SizedBox(width: 6),
                      Text(fmt(coins), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                    ],
                  ),
                ),
              ),
            const SizedBox(width: 8),
            RoundBtn(
              dark ? LucideIcons.sun : LucideIcons.moon,
              size: 42,
              tip: ref.watch(tProvider)('messages.themeLabel'),
              onTap: () => ref.read(prefsProvider.notifier).setTheme(dark ? ThemeMode.light : ThemeMode.dark),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => context.push('/account'),
              child: Avatar(name: s?.name ?? '', photo: s?.photo ?? '', size: 42, brand: true),
            ),
          ],
        ),
      ),
    );
  }
}

class BottomBar extends StatelessWidget {
  final List<NavTab> tabs;
  final int index;
  final ValueChanged<int> onTap;
  const BottomBar({super.key, required this.tabs, required this.index, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(28), boxShadow: c.popShadow),
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: _BarItem(tab: tabs[i], on: i == index, onTap: () => onTap(i)),
              ),
          ],
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  final NavTab tab;
  final bool on;
  final VoidCallback onTap;
  const _BarItem({required this.tab, required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      selected: on,
      button: true,
      label: tab.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(gradient: on ? c.gradient : null, borderRadius: BorderRadius.circular(22), boxShadow: on ? c.orangeShadow : null),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tab.icon, size: 22, color: on ? Colors.white : c.muted),
              const SizedBox(height: 4),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: on ? Colors.white : c.muted, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// A page inside a tab: pull to refresh, room for the floating bar.
class TabPage extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  const TabPage({super.key, required this.children, this.onRefresh});
  @override
  Widget build(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: EdgeInsets.fromLTRB(16, 8, 16, 120 + MediaQuery.of(context).padding.bottom),
      children: children,
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(color: context.c.brand, onRefresh: onRefresh!, child: list);
  }
}

// A page opened on top (back arrow + title)
class SubPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final Widget? bottom;
  final List<Widget> actions;
  const SubPage({super.key, required this.title, required this.children, this.onRefresh, this.bottom, this.actions = const []});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + MediaQuery.of(context).padding.bottom),
      children: children,
    );
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
              child: Row(
                children: [
                  RoundBtn(
                    LucideIcons.arrowLeft,
                    size: 42,
                    onTap: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : GoRouter.of(context).go('/'),
                    tip: MaterialLocalizations.of(context).backButtonTooltip,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
          ),
          Expanded(
            child: onRefresh == null ? list : RefreshIndicator(color: c.brand, onRefresh: onRefresh!, child: list),
          ),
          if (bottom != null)
            Container(
              decoration: BoxDecoration(color: c.card, boxShadow: c.popShadow),
              child: SafeArea(
                top: false,
                child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), child: bottom),
              ),
            ),
        ],
      ),
    );
  }
}

// shows "your session ended" once when the API says the login is no longer valid
class SessionWatcher extends ConsumerWidget {
  final Widget child;
  const SessionWatcher({super.key, required this.child});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(sessionEndedProvider, (_, _) {
      final m = ScaffoldMessenger.maybeOf(context);
      m?.showSnackBar(SnackBar(content: Text(ref.read(tProvider)('app.sessionEnded'))));
    });
    return ScaffoldMessenger(child: child);
  }
}
