import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import '../features/owner/data.dart';
import 'ui.dart';

// Pay coins (PurchaseModal on the web): what you get, your balance before / after, one button. Used for
// licenses, add-ons and premium themes. Returns true from the sheet when bought and closed with the done button.
class BuySheet extends ConsumerStatefulWidget {
  final Widget stage;
  final String? badge;
  final String title, sub, buyLabel, doneTitle, doneSub, doneButton;
  final List<String> perks;
  final num price;
  final Future<Json> Function() buy;
  final void Function(Json r) onDone;
  final String Function(Json r)? doneSubOf;
  const BuySheet({
    super.key,
    this.doneSubOf,
    required this.stage,
    this.badge,
    required this.title,
    required this.sub,
    required this.perks,
    required this.price,
    required this.buyLabel,
    required this.doneTitle,
    required this.doneSub,
    required this.doneButton,
    required this.buy,
    required this.onDone,
  });
  @override
  ConsumerState<BuySheet> createState() => BuySheetState();
}

class BuySheetState extends ConsumerState<BuySheet> {
  bool _busy = false, _done = false;
  String _error = '', _doneSub = '';

  Future<void> _go() async {
    if (_busy) return; // a second tap while paying never pays twice
    // what's needed after the answer, taken now: the sheet may be gone by then (swiped away, the app moved on), and the
    // coins + "bought" must still be recorded
    final container = ProviderScope.containerOf(context, listen: false);
    final offline = ref.read(tProvider)('app.offline');
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final r = await widget.buy();
      if (r['balance'] is num) await container.read(sessionProvider.notifier).patch({'coin_balance': r['balance']});
      coinsChangedIn(container);
      widget.onDone(r);
      if (!mounted) return;
      setState(() {
        if (widget.doneSubOf != null) _doneSub = widget.doneSubOf!(r);
        _done = true;
      });
    } on ApiError catch (e) {
      // a refused purchase can still change the coins: the API sends the balance (not enough coins, or part of a set
      // bought before it ran out — then data.bought says how many went through)
      final balance = e.body['balance'];
      if (balance is num) await container.read(sessionProvider.notifier).patch({'coin_balance': balance});
      final bought = obj(e.body['data'])['bought'];
      final some = bought is List && bought.isNotEmpty;
      if (balance is num || some) coinsChangedIn(container);
      if (some) widget.onDone(Map<String, dynamic>.from(e.body));
      if (!mounted) return;
      final t = ref.read(tProvider);
      final msg = e.network ? offline : e.message;
      setState(() => _error = some ? '$msg\n${t('buy.partly', {'n': bought.length})}' : msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final balance = ref.watch(sessionProvider)?.coins ?? 0;
    final short = !_done && balance < widget.price;
    // while paying, the sheet can't be closed (back button, tap outside); a swipe down still can — the purchase then
    // finishes in the background and is recorded (see _go)
    return PopScope(
      canPop: !_busy,
      child: _body(context, t, c, balance, short),
    );
  }

  Widget _body(BuildContext context, T t, C c, num balance, bool short) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: widget.stage),
          const SizedBox(height: 16),
          if (widget.badge != null && !_done)
            Center(
              child: Chip2(widget.badge!, tone: Tone.brand, icon: LucideIcons.crown),
            ),
          const SizedBox(height: 8),
          Text(
            _done ? widget.doneTitle : widget.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          if ((_done ? (_doneSub.isNotEmpty ? _doneSub : widget.doneSub) : widget.sub).isNotEmpty)
            Text(
              _done ? (_doneSub.isNotEmpty ? _doneSub : widget.doneSub) : widget.sub,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted, height: 1.5),
            ),
          if (!_done) ...[
            const SizedBox(height: 14),
            for (final p in widget.perks)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(LucideIcons.circleCheck, size: 16, color: c.good),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(p, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [_CoinLine(t('card.yourBalance'), fmt(balance)), const SizedBox(height: 6), _CoinLine(t('card.afterUnlock'), short ? '—' : fmt(balance - widget.price), strong: true)],
              ),
            ),
            if (short) ...[
              const SizedBox(height: 12),
              Alert(t('card.notEnough', {'coins': fmt(widget.price - balance)})),
            ],
            if (_error.isNotEmpty) ...[const SizedBox(height: 12), Alert(_error)],
            const SizedBox(height: 18),
            short
                ? Btn(
                    t('card.topUp'),
                    icon: LucideIcons.plus,
                    expand: true,
                    onTap: () {
                      Navigator.pop(context, false);
                      context.push('/o/coins');
                    },
                  )
                : Btn(widget.buyLabel, lead: const CoinIcon(size: 18), expand: true, busy: _busy, onTap: _go),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context, false),
              child: Text(t('card.maybeLater'), style: TextStyle(color: c.muted)),
            ),
          ] else ...[
            const SizedBox(height: 18),
            Btn(widget.doneButton, expand: true, onTap: () => Navigator.pop(context, true)),
          ],
        ],
      ),
    );
  }
}

class _CoinLine extends StatelessWidget {
  final String label, value;
  final bool strong;
  const _CoinLine(this.label, this.value, {this.strong = false});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(label, style: TextStyle(color: context.c.muted)),
      ),
      const CoinIcon(size: 16),
      const SizedBox(width: 4),
      Text(value, style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w600)),
    ],
  );
}
