import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart' show SK2Transaction;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../common/shell.dart';
import 'coin_play_text.dart';
import 'data.dart';

// Buying coins inside the app = the store's own payment only: Google Play Billing on Android, Apple in-app purchase
// on iPhone (Google Play payments policy / App Store rule 3.1.1: no KHQR / bank / website payment, links or wording
// in the store app). Coins go into the same wallet as web top-ups.
//   Android  GET /api/user/coins/google-packs   POST /api/user/coins/google/verify { productId, purchaseToken }
//            the server checks the purchase with Google, adds the coins once, consumes it
//   iPhone   GET /api/user/coins/apple-packs    POST /api/user/coins/apple/verify { productId, jws }
//            StoreKit 2 gives a transaction signed by Apple (jws); the server checks Apple's signature, adds the
//            coins once; the app then finishes the transaction
// Same packs (coins_<coins>) on both. Unfinished purchases (app closed, no internet) are checked again every time
// the app starts. A build outside the stores can keep the web coin shop with --dart-define=WEB_BILLING=true.

const _webBilling = bool.fromEnvironment('WEB_BILLING');
bool get appleBilling => !kIsWeb && Platform.isIOS && !_webBilling;
// "store billing": the in-app coin shop and no pointing to the website's payments (Android and iPhone)
bool get playBilling => !kIsWeb && (Platform.isAndroid || Platform.isIOS) && !_webBilling;

// which store: 'apple' or 'google' (tests override it)
final billingStoreProvider = Provider<String>((_) => appleBilling ? 'apple' : 'google');

// ---------------------------------------------------------------- the billing library behind a small interface (tests fake it)
enum PlayStatus { pending, purchased, restored, error, canceled }

class PlayProduct {
  final String id, price;
  const PlayProduct(this.id, this.price);
}

class PlayPurchase {
  final String productId, token, orderId;
  final PlayStatus status;
  final bool needsComplete;
  final Object? raw;
  const PlayPurchase({required this.productId, required this.token, this.orderId = '', required this.status, this.needsComplete = false, this.raw});
}

abstract class PlayBilling {
  Future<bool> available();
  Future<List<PlayProduct>> products(Set<String> ids);
  Future<bool> buy(String productId, String accountRef);
  Stream<List<PlayPurchase>> get updates;
  Future<void> complete(PlayPurchase p);
  Future<void> restore();
}

class GooglePlayBilling implements PlayBilling {
  final _iap = InAppPurchase.instance;
  final _details = <String, ProductDetails>{};

  @override
  Future<bool> available() => _iap.isAvailable();

  @override
  Future<List<PlayProduct>> products(Set<String> ids) async {
    final r = await _iap.queryProductDetails(ids);
    for (final d in r.productDetails) {
      _details[d.id] = d;
    }
    return [for (final d in r.productDetails) PlayProduct(d.id, d.price)];
  }

  @override
  Future<bool> buy(String productId, String accountRef) async {
    final d = _details[productId];
    if (d == null) return false;
    // autoConsume: false — the server consumes it after the coins are added (never lose a paid purchase)
    return _iap.buyConsumable(purchaseParam: PurchaseParam(productDetails: d, applicationUserName: accountRef), autoConsume: false);
  }

  @override
  Stream<List<PlayPurchase>> get updates => _iap.purchaseStream.map((list) => [for (final p in list) _toPurchase(p)]);

  @override
  Future<void> complete(PlayPurchase p) async {
    final raw = p.raw;
    if (raw is PurchaseDetails && raw.pendingCompletePurchase) await _iap.completePurchase(raw);
  }

  @override
  Future<void> restore() => _iap.restorePurchases();
}

// iPhone: the same plugin with StoreKit 2. A consumable is "used up" when the app finishes the transaction
// (complete), which happens only after the server added the coins.
class AppStoreBilling extends GooglePlayBilling {
  final _unfinished = StreamController<List<PlayPurchase>>.broadcast();

  @override
  Future<bool> buy(String productId, String accountRef) async {
    final d = _details[productId];
    if (d == null) return false;
    // applicationUserName = StoreKit's appAccountToken (a UUID from the server): the purchase belongs to this account
    return _iap.buyConsumable(purchaseParam: PurchaseParam(productDetails: d, applicationUserName: accountRef.isEmpty ? null : accountRef));
  }

  @override
  Stream<List<PlayPurchase>> get updates {
    final c = StreamController<List<PlayPurchase>>();
    final subs = <StreamSubscription<List<PlayPurchase>>>[];
    c.onListen = () {
      subs.add(super.updates.listen(c.add, onError: c.addError));
      subs.add(_unfinished.stream.listen(c.add, onError: c.addError));
    };
    c.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
    };
    return c.stream;
  }

  // paid but not finished (the coins may not be in yet): StoreKit keeps them until the app finishes them
  @override
  Future<void> restore() async {
    final list = await SK2Transaction.unfinishedTransactions();
    if (list.isEmpty) return;
    _unfinished.add([
      for (final t in list)
        if ((t.receiptData ?? '').isNotEmpty) PlayPurchase(productId: t.productId, token: t.receiptData!, orderId: t.id, status: PlayStatus.purchased, needsComplete: true, raw: t),
    ]);
  }

  @override
  Future<void> complete(PlayPurchase p) async {
    final raw = p.raw;
    if (raw is SK2Transaction) return SK2Transaction.finish(int.parse(raw.id));
    return super.complete(p);
  }
}

PlayPurchase _toPurchase(PurchaseDetails p) => PlayPurchase(
  productId: p.productID,
  token: p.verificationData.serverVerificationData,
  orderId: p.purchaseID ?? '',
  status: switch (p.status) {
    PurchaseStatus.pending => PlayStatus.pending,
    PurchaseStatus.purchased => PlayStatus.purchased,
    PurchaseStatus.restored => PlayStatus.restored,
    PurchaseStatus.canceled => PlayStatus.canceled,
    PurchaseStatus.error => PlayStatus.error,
  },
  needsComplete: p.pendingCompletePurchase,
  raw: p,
);

final playBillingProvider = Provider<PlayBilling>((ref) => ref.watch(billingStoreProvider) == 'apple' ? AppStoreBilling() : GooglePlayBilling());

// ---------------------------------------------------------------- state
class PlayCoinsState {
  final bool loading;
  final bool ready; // the server has Google Play set up
  final bool available; // Google Play works on this phone
  final List<Json> packs; // server packs + Google's price
  final String accountRef;
  final String busy; // product being bought
  final bool checking; // a purchase is being added
  final String message;
  final Tone tone;
  final String error; // loading failed
  const PlayCoinsState({this.loading = true, this.ready = false, this.available = false, this.packs = const [], this.accountRef = '', this.busy = '', this.checking = false, this.message = '', this.tone = Tone.brand, this.error = ''});
  PlayCoinsState copy({bool? loading, bool? ready, bool? available, List<Json>? packs, String? accountRef, String? busy, bool? checking, String? message, Tone? tone, String? error}) => PlayCoinsState(
    loading: loading ?? this.loading,
    ready: ready ?? this.ready,
    available: available ?? this.available,
    packs: packs ?? this.packs,
    accountRef: accountRef ?? this.accountRef,
    busy: busy ?? this.busy,
    checking: checking ?? this.checking,
    message: message ?? this.message,
    tone: tone ?? this.tone,
    error: error ?? this.error,
  );
}

final playCoinsProvider = NotifierProvider<PlayCoins, PlayCoinsState>(PlayCoins.new);

class PlayCoins extends Notifier<PlayCoinsState> {
  StreamSubscription<List<PlayPurchase>>? _sub;
  final _inFlight = <String>{};
  bool _started = false;

  String get _lang => ref.read(tProvider).lang;
  Api get _api => ref.read(apiProvider);
  bool get _apple => ref.read(billingStoreProvider) == 'apple';
  String _w(String k, [Map<String, Object>? v]) => cpwFor(ref.read(billingStoreProvider), _lang, k, v);

  @override
  PlayCoinsState build() {
    ref.onDispose(() => _sub?.cancel());
    return const PlayCoinsState();
  }

  // once per app run (owner signed in): listen to Google + check purchases that were paid but not added yet
  Future<void> start() async {
    if (_started) return;
    _started = true;
    final billing = ref.read(playBillingProvider);
    _sub = billing.updates.listen(_onUpdates, onError: (_) {});
    try {
      if (await billing.available()) await billing.restore();
    } catch (_) {}
  }

  Future<void> load() async {
    state = state.copy(loading: true, error: '');
    try {
      await start();
      final r = obj((await _api.get('${Api.user}/coins/${_apple ? 'apple' : 'google'}-packs'))['data']);
      final packs = objs(r['packs']);
      final billing = ref.read(playBillingProvider);
      final ok = r['ready'] == true && await billing.available();
      final prices = ok ? {for (final p in await billing.products({for (final x in packs) str(x['product_id'])})) p.id: p.price} : <String, String>{};
      state = state.copy(
        loading: false,
        ready: r['ready'] == true,
        available: ok,
        accountRef: str(r['account_ref']),
        // only the packs the store knows (created in Play Console / App Store Connect), with its price in the phone's currency
        packs: [
          for (final p in packs)
            if (prices.containsKey(str(p['product_id']))) {...p, 'price': prices[str(p['product_id'])]},
        ],
      );
    } on ApiError catch (e) {
      state = state.copy(loading: false, error: e.network ? _w('unavailable') : e.message);
    } catch (_) {
      state = state.copy(loading: false, error: _w('unavailable'));
    }
  }

  Future<void> buy(String productId) async {
    if (state.busy.isNotEmpty || state.checking) return; // no double taps
    state = state.copy(busy: productId, message: '');
    try {
      final started = await ref.read(playBillingProvider).buy(productId, state.accountRef);
      if (!started) state = state.copy(busy: '', message: _w('failed'), tone: Tone.danger);
      // the result arrives on the purchase stream
    } catch (_) {
      state = state.copy(busy: '', message: _w('failed'), tone: Tone.danger);
    }
  }

  Future<void> _onUpdates(List<PlayPurchase> list) async {
    for (final p in list) {
      switch (p.status) {
        case PlayStatus.pending:
          state = state.copy(busy: '', message: _w('pending'), tone: Tone.warn);
        case PlayStatus.canceled:
          state = state.copy(busy: '', message: _w('cancelled'), tone: Tone.muted);
          await _complete(p);
        case PlayStatus.error:
          state = state.copy(busy: '', message: _w('failed'), tone: Tone.danger);
          await _complete(p);
        case PlayStatus.purchased || PlayStatus.restored:
          await _verify(p);
      }
    }
  }

  Future<void> _complete(PlayPurchase p) async {
    try {
      await ref.read(playBillingProvider).complete(p);
    } catch (_) {}
  }

  Future<void> _verify(PlayPurchase p) async {
    if (p.token.isEmpty || !_inFlight.add(p.token)) return;
    state = state.copy(checking: true, busy: '', message: '');
    try {
      final r = obj(
        (await _api.post(
          _apple ? '${Api.user}/coins/apple/verify' : '${Api.user}/coins/google/verify',
          _apple ? {'productId': p.productId, 'jws': p.token} : {'productId': p.productId, 'purchaseToken': p.token, 'orderId': p.orderId},
        ))['data'],
      );
      if (r['balance'] is num) await ref.read(sessionProvider.notifier).patch({'coin_balance': r['balance']});
      ref.invalidate(dashboardProvider);
      ref.invalidate(licensesProvider);
      await _complete(p);
      state = state.copy(checking: false, message: _w('added', {'n': fmt(r['coins_added'])}), tone: Tone.good);
    } on ApiError catch (e) {
      // pending / no internet / server busy: keep the purchase open, it's checked again next time
      final keep = e.network || e.status == 202 || e.code == 'pending' || e.code == 'busy' || e.status >= 500;
      state = state.copy(checking: false, message: e.code == 'pending' || e.status == 202 ? _w('pending') : (keep ? _w('failed') : e.message), tone: e.code == 'pending' ? Tone.warn : Tone.danger);
    } catch (_) {
      state = state.copy(checking: false, message: _w('failed'), tone: Tone.danger);
    } finally {
      _inFlight.remove(p.token);
    }
  }

  void clearMessage() => state = state.copy(message: '');
}

// started from the owner's app frame, so a purchase paid while the app was closed is added on the next start
void playCoinsBoot(WidgetRef ref) {
  if (!playBilling) return;
  Future.microtask(() => ref.read(playCoinsProvider.notifier).start());
}

// ---------------------------------------------------------------- the screen
class CoinPlayPage extends ConsumerStatefulWidget {
  const CoinPlayPage({super.key});
  @override
  ConsumerState<CoinPlayPage> createState() => _CoinPlayPageState();
}

class _CoinPlayPageState extends ConsumerState<CoinPlayPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(playCoinsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final store = ref.watch(billingStoreProvider);
    String w(String k, [Map<String, Object>? v]) => cpwFor(store, t.lang, k, v);
    final c = context.c;
    final s = ref.watch(playCoinsProvider);
    final balance = ref.watch(sessionProvider)?.data['coin_balance'];
    final best = s.packs.isEmpty ? '' : str((s.packs.toList()..sort((a, b) => n(b['bonus_pct']).compareTo(n(a['bonus_pct'])))).first['product_id']);
    return SubPage(
      title: w('title'),
      onRefresh: () => ref.read(playCoinsProvider.notifier).load(),
      children: [
        // balance
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFE0581A), Color(0xFFF59E0B)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(22), boxShadow: c.orangeShadow),
          child: Row(
            children: [
              const CoinIcon(size: 38),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w('balance'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    Text(fmt(balance ?? 0), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 30, height: 1.15)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Muted(w('sub')),
        const SizedBox(height: 14),
        if (s.message.isNotEmpty) ...[
          Alert(s.message, tone: s.tone == Tone.muted ? Tone.warn : s.tone),
          const SizedBox(height: 12),
        ],
        if (s.checking) ...[
          Alert(w('checking'), tone: Tone.brand),
          const SizedBox(height: 12),
        ],
        if (s.loading && s.packs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (s.error.isNotEmpty)
          Alert(s.error, action: Btn(w('retry'), small: true, kind: BtnKind.ghost, onTap: () => ref.read(playCoinsProvider.notifier).load()))
        else if (!s.ready)
          Alert(w('notSetup'), tone: Tone.warn)
        else if (!s.available)
          Alert(w('unavailable'), tone: Tone.warn)
        else if (s.packs.isEmpty)
          Alert(w('noPacks'), tone: Tone.warn)
        else
          for (final p in s.packs) ...[
            _PackCard(
              pack: p,
              best: str(p['product_id']) == best && n(p['bonus_pct']) > 0,
              busy: s.busy == str(p['product_id']),
              off: s.busy.isNotEmpty || s.checking,
              w: w,
              onBuy: () => ref.read(playCoinsProvider.notifier).buy(str(p['product_id'])),
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.shieldCheck, size: 15, color: c.muted),
            const SizedBox(width: 6),
            Text(w('secure'), style: TextStyle(color: c.muted, fontSize: 12.5)),
          ],
        ),
      ],
    );
  }
}

class _PackCard extends StatelessWidget {
  final Json pack;
  final bool best, busy, off;
  final String Function(String, [Map<String, Object>?]) w;
  final VoidCallback onBuy;
  const _PackCard({required this.pack, required this.best, required this.busy, required this.off, required this.w, required this.onBuy});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bonus = n(pack['bonus']);
    final pct = n(pack['bonus_pct']);
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(16)),
            child: const Center(child: CoinIcon(size: 30)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(fmt(pack['coins']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, height: 1.1)),
                    // how much extra they earn, like the web's "10% free" badge
                    if (pct > 0) _PctBadge(w('pct', {'n': fmt(pct)})),
                    if (best) Chip2(w('bestValue'), tone: Tone.brand),
                  ],
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      if (bonus > 0) TextSpan(text: '${w('free', {'n': fmt(bonus)})} · ', style: TextStyle(color: c.good, fontWeight: FontWeight.w700)),
                      TextSpan(text: w('total', {'n': fmt(pack['total_coins'])})),
                    ],
                  ),
                  style: TextStyle(color: c.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Btn(str(pack['price']).isEmpty ? w('buy') : str(pack['price']), small: true, busy: busy, onTap: off ? null : onBuy),
        ],
      ),
    );
  }
}

// the orange "10% free" badge (same look as the web coin shop)
class _PctBadge extends StatelessWidget {
  final String text;
  const _PctBadge(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFE0581A)]),
    ),
    child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
  );
}
