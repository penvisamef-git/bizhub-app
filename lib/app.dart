import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/api.dart';
import 'core/crash.dart';
import 'core/firebase_rest.dart';
import 'core/providers.dart';
import 'core/theme.dart';
import 'features/admin/admin_cards.dart';
import 'features/admin/admin_errors.dart';
import 'features/admin/admin_holidays.dart';
import 'features/admin/admin_homepage.dart';
import 'features/admin/admin_licenses.dart';
import 'features/admin/admin_prices.dart';
import 'features/admin/admin_team.dart';
import 'features/admin/admin_coins.dart';
import 'features/admin/admin_customers.dart';
import 'features/admin/admin_businesses.dart';
import 'features/admin/admin_dashboard.dart';
import 'features/admin/admin_more.dart';
import 'features/admin/coin_orders.dart';
import 'features/auth/forgot_page.dart';
import 'features/auth/login_page.dart';
import 'features/auth/qr_login_page.dart';
import 'features/auth/signup_page.dart';
import 'features/common/support_chat.dart';
import 'features/common/account_page.dart';
import 'features/common/shell.dart';
import 'features/common/web_page.dart';
import 'features/attendance/at_page.dart';
import 'features/debt/dk_page.dart';
import 'features/note/nt_page.dart';
import 'features/stamp/sc_page.dart';
import 'features/event/ev_page.dart';
import 'features/qrgen/qg_page.dart';
import 'features/website/wb_page.dart';
import 'features/flipbook/fb_page.dart';
import 'features/menuqr/mq_page.dart';
import 'features/guesthouse/gh_page.dart';
import 'features/mart/mart_page.dart';
import 'features/namecard/namecard_page.dart';
import 'features/restaurant/rest_page.dart';
import 'features/onboarding/welcome_page.dart';
import 'features/owner/business_page.dart';
import 'features/owner/add_business_page.dart';
import 'features/owner/coin_play.dart';
import 'features/owner/coin_shop_page.dart';
import 'features/owner/home_page.dart';
import 'features/owner/licenses_page.dart';
import 'features/owner/owner_more.dart';
import 'features/owner/wallet_page.dart';

const _public = ['/welcome', '/login', '/login-qr', '/signup', '/forgot'];

String homeOf(Session s) => s.superAdmin ? '/a/dash' : '/o/home';

// BizHub links opened from the phone (app links: https://bizhubcambodia.com/app/...) → the same screen in the app
String? webLinkTarget(Uri u) {
  final p = u.path.replaceAll(RegExp(r'/+$'), '');
  if (p != '/app' && !p.startsWith('/app/')) return null;
  final redeem = RegExp(r'^\d{12}$').hasMatch(u.queryParameters['redeem'] ?? '') ? '?redeem=${u.queryParameters['redeem']}' : '';
  return switch (p) {
    '/app/wallet' => '/o/wallet$redeem',
    '/app/licenses' => '/o/licenses',
    '/app/support' => '/o/support',
    '/app/coins' || '/app/wallet/coins' => '/o/coins',
    '/app/super-admin/inbox' => '/a/inbox',
    '/app/super-admin/coin-orders' => '/a/orders',
    '/app/super-admin/licenses' => '/a/licenses',
    '/app/super-admin/coins' => '/a/coins',
    '/app/super-admin/customers' => '/a/customers',
    '/app/super-admin/businesses' => '/a/businesses',
    _ => '/', // anything else: the home of whoever is logged in
  };
}

String? _pendingLink; // a link opened before logging in: go there after the login

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.listen(prefsProvider.select((p) => p.onboarded), (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/o/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final s = ref.read(sessionProvider);
      final onboarded = ref.read(prefsProvider).onboarded;
      final link = webLinkTarget(state.uri);
      if (link != null && s == null) _pendingLink = link == '/' ? null : link;
      if (link != null && s != null) return link == '/' ? homeOf(s) : link;
      final at = state.matchedLocation;
      final public = _public.contains(at);
      if (s == null) {
        if (!onboarded && at != '/welcome' && !public) return '/welcome';
        return public ? null : '/login';
      }
      if (public) {
        final next = _pendingLink;
        _pendingLink = null;
        return next ?? homeOf(s);
      }
      if (s.superAdmin && at.startsWith('/o/')) return '/a/dash';
      if (!s.superAdmin && at.startsWith('/a/')) return '/o/home';
      return null;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomePage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/login-qr', builder: (_, _) => const QrLoginPage()),
      GoRoute(
        path: '/signup',
        builder: (_, s) => SignUpPage(google: s.extra is GoogleResult ? s.extra as GoogleResult : null),
      ),
      GoRoute(path: '/forgot', builder: (_, _) => const ForgotPage()),
      // business owner: Dashboard · Business · Wallet · More (Licenses is in More)
      StatefulShellRoute.indexedStack(
        builder: (_, _, nav) => AppShell(nav: nav, admin: false),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/o/home', builder: (_, _) => const OwnerHomePage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/o/business', builder: (_, _) => const OwnerBusinessPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/o/wallet', builder: (_, _) => const WalletPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/o/more', builder: (_, _) => const OwnerMorePage())],
          ),
        ],
      ),
      GoRoute(
        path: '/o/add',
        builder: (_, s) => AddBusinessPage(edit: s.extra as Map<String, dynamic>?),
      ),
      GoRoute(path: '/o/licenses', builder: (_, _) => const LicensesPage()),
      // Android (Google Play): coins only through Google Play Billing · elsewhere: the bank / KHQR coin shop
      GoRoute(path: '/o/coins', builder: (_, _) => playBilling ? const CoinPlayPage() : const CoinShopPage()),
      GoRoute(
        path: '/biz/restaurant/:id',
        builder: (_, s) => RestaurantPage(id: s.pathParameters['id']!, title: s.uri.queryParameters['name'] ?? '', tab: s.uri.queryParameters['tab'] ?? ''),
      ),
      GoRoute(
        path: '/biz/mart/:id',
        builder: (_, s) => MartPage(id: s.pathParameters['id']!, title: s.uri.queryParameters['name'] ?? '', tab: s.uri.queryParameters['tab'] ?? ''),
      ),
      GoRoute(
        path: '/biz/guesthouse/:id',
        builder: (_, s) => GuestHousePage(id: s.pathParameters['id']!, title: s.uri.queryParameters['name'] ?? '', tab: s.uri.queryParameters['tab'] ?? ''),
      ),
      GoRoute(
        path: '/biz/attendance/:id',
        builder: (_, s) => AttendancePage(id: s.pathParameters['id']!, title: s.uri.queryParameters['name'] ?? '', tab: s.uri.queryParameters['tab'] ?? ''),
      ),
      GoRoute(
        path: '/biz/menuqr/:id',
        builder: (_, s) => MenuQrPage(id: s.pathParameters['id']!, title: s.uri.queryParameters['name'] ?? '', tab: s.uri.queryParameters['tab'] ?? ''),
      ),
      GoRoute(
        path: '/biz/flipbook/:id',
        builder: (_, s) => FlipBookPage(id: s.pathParameters['id']!, title: s.uri.queryParameters['name'] ?? '', tab: s.uri.queryParameters['tab'] ?? ''),
      ),
      GoRoute(
        path: '/biz/website/:id',
        builder: (_, s) => WebsitePage(id: s.pathParameters['id']!, title: s.uri.queryParameters['name'] ?? '', tab: s.uri.queryParameters['tab'] ?? ''),
      ),
      GoRoute(
        path: '/biz/qrgen/:id',
        builder: (_, s) => QrGenPage(id: s.pathParameters['id']!, title: s.uri.queryParameters['name'] ?? '', tab: s.uri.queryParameters['tab'] ?? ''),
      ),
      GoRoute(
        path: '/biz/debt/:id',
        builder: (_, s) => DebtPage(id: s.pathParameters['id']!, title: s.uri.queryParameters['name'] ?? '', tab: s.uri.queryParameters['tab'] ?? ''),
      ),
      GoRoute(
        path: '/biz/note/:id',
        builder: (_, s) => NotePage(id: s.pathParameters['id']!, title: s.uri.queryParameters['name'] ?? '', tab: s.uri.queryParameters['tab'] ?? ''),
      ),
      GoRoute(
        path: '/biz/event/:id',
        builder: (_, s) => EventPage(id: s.pathParameters['id']!, title: s.uri.queryParameters['name'] ?? '', tab: s.uri.queryParameters['tab'] ?? ''),
      ),
      GoRoute(
        path: '/biz/stamp/:id',
        builder: (_, s) => StampPage(id: s.pathParameters['id']!, title: s.uri.queryParameters['name'] ?? '', tab: s.uri.queryParameters['tab'] ?? ''),
      ),
      GoRoute(
        path: '/biz/namecard/:id',
        builder: (_, s) => NameCardPage(id: s.pathParameters['id']!, title: s.uri.queryParameters['name'] ?? '', tab: s.uri.queryParameters['tab'] ?? ''),
      ),
      // super admin: Dashboard · Customers · Businesses · Coins · More
      StatefulShellRoute.indexedStack(
        builder: (_, _, nav) => AppShell(nav: nav, admin: true),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/a/dash', builder: (_, _) => const AdminDashboardPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/a/customers', builder: (_, _) => const AdminCustomersPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/a/businesses', builder: (_, _) => const AdminBusinessesPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/a/coins', builder: (_, _) => const AdminCoinsPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/a/more', builder: (_, _) => const AdminMorePage())],
          ),
        ],
      ),
      GoRoute(path: '/a/orders', builder: (_, _) => const CoinOrdersPage()),
      GoRoute(path: '/a/inbox', builder: (_, _) => const InboxPage()),
      GoRoute(
        path: '/a/inbox/:id',
        builder: (_, s) => InboxThreadPage(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/a/licenses', builder: (_, _) => const AdminLicensesPage()),
      GoRoute(path: '/a/holidays', builder: (_, _) => const AdminHolidaysPage()),
      GoRoute(path: '/a/prices', builder: (_, _) => const AdminPricesPage()),
      GoRoute(path: '/a/homepage', builder: (_, _) => const AdminHomepagePage()),
      GoRoute(path: '/a/users', builder: (_, _) => const AdminUsersPage()),
      GoRoute(path: '/a/activity', builder: (_, _) => const AdminActivityPage()),
      GoRoute(path: '/a/cards', builder: (_, _) => const AdminCardsPage()),
      GoRoute(path: '/a/errors', builder: (_, _) => const AdminErrorsPage()),
      GoRoute(path: '/o/support', builder: (_, _) => const SupportChatPage()),
      GoRoute(
        path: '/a/customer/:id',
        builder: (_, s) => CustomerDetailPage(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/account', builder: (_, _) => const AccountPage()),
      // a web screen inside the app: /web?path=/app/business/123&title=Sokha%20Coffee
      GoRoute(
        path: '/web',
        builder: (_, s) => WebPage(path: s.uri.queryParameters['path'] ?? '/app/dashboard', title: s.uri.queryParameters['title'] ?? ''),
      ),
    ],
  );
});

// crash reports say which screen and who (Crash in core/crash.dart)
GoRouter? _watched;
void _watchForCrashReports(WidgetRef ref, GoRouter router) {
  final s = ref.watch(sessionProvider);
  Crash.user = s == null ? null : {'type': s.team ? 'team' : 'customer', 'id': str(s.data['_id']), 'email': s.email.isNotEmpty ? s.email : s.phone};
  if (identical(_watched, router)) return;
  _watched = router;
  router.routerDelegate.addListener(() => Crash.route = router.routerDelegate.currentConfiguration.uri.toString());
}

class BizHubApp extends ConsumerWidget {
  const BizHubApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider);
    final router = ref.watch(routerProvider);
    final km = prefs.lang == 'km';
    _watchForCrashReports(ref, router);
    return MaterialApp.router(
      title: 'BizHub',
      debugShowCheckedModeBanner: false,
      themeMode: prefs.theme,
      theme: buildTheme(dark: false, khmer: km),
      darkTheme: buildTheme(dark: true, khmer: km),
      routerConfig: router,
      locale: Locale(prefs.lang),
      supportedLocales: const [Locale('en'), Locale('km')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => SessionWatcher(child: child ?? const SizedBox()),
    );
  }
}
