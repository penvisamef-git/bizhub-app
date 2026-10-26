import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/providers.dart';

// One cache per logged-in account (the token changes → everything reloads)
String? _who(Ref ref) => ref.watch(sessionProvider.select((s) => s?.token));

// GET /api/user/dashboard — coins, sales, businesses, "Right now"
final dashboardProvider = FutureProvider<Json>((ref) async {
  _who(ref);
  final r = await ref.read(apiProvider).get('${Api.user}/dashboard');
  final d = obj(r['data']);
  // keep the coin number in the header right
  final bal = obj(d['coins'])['balance'];
  final s = ref.read(sessionProvider);
  if (bal is num && s != null && s.coins != bal) await ref.read(sessionProvider.notifier).patch({'coin_balance': bal});
  return d;
});

// GET /api/user/licenses
final licensesProvider = FutureProvider<Json>((ref) async {
  _who(ref);
  return ref.read(apiProvider).get('${Api.user}/licenses');
});

// GET /api/user/coin-shop — packages, banks, hotline, my orders
final coinShopProvider = FutureProvider<Json>((ref) async {
  _who(ref);
  return obj((await ref.read(apiProvider).get('${Api.user}/coin-shop'))['data']);
});

// GET /api/user/businesses-prices — price per type + which are yearly
final bizPricesProvider = FutureProvider<Json>((ref) async {
  _who(ref);
  return ref.read(apiProvider).get('${Api.user}/businesses-prices');
});

// after paying / topping up: reload what shows coins
void coinsChanged(WidgetRef ref) {
  ref.invalidate(dashboardProvider);
  ref.invalidate(licensesProvider);
}

// the same, from a container (works after the widget that started the purchase is gone)
void coinsChangedIn(ProviderContainer c) {
  c.invalidate(dashboardProvider);
  c.invalidate(licensesProvider);
}
