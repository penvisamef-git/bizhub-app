import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../common/shell.dart';
import 'package:go_router/go_router.dart';
import 'admin_customers.dart';
import 'admin_dashboard.dart' show AdminTxRow;
import 'admin_parts.dart';

// Coins (dashboard/super_admin/CoinsPage.jsx): treasury, totals, generate / transfer, history
class AdminCoinsPage extends ConsumerStatefulWidget {
  const AdminCoinsPage({super.key});
  @override
  ConsumerState<AdminCoinsPage> createState() => _AdminCoinsPageState();
}

class _AdminCoinsPageState extends ConsumerState<AdminCoinsPage> with PagedLoad {
  String _type = '';
  @override
  String get path => '${Api.admin}/coins/transactions';
  @override
  Map<String, dynamic> get query => {'type': _type, 'limit': 20};

  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  Future<void> _reload() async {
    ref.invalidate(coinSummaryProvider);
    await load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final s = ref.watch(coinSummaryProvider).valueOrNull;
    Widget box(String label, Object? v, IconData icon, {String? sub}) => Expanded(
      child: Panel(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: c.brandInk),
            const SizedBox(height: 8),
            Text(label, maxLines: 2, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12)),
            Text(s == null ? '—' : fmt(v), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            if (sub != null) Text(sub, style: TextStyle(fontSize: 11.5, color: c.brandInk, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
    return NotificationListener<ScrollNotification>(
      onNotification: onScroll,
      child: TabPage(
        onRefresh: _reload,
        children: [
          Muted(t('sa.coinsSub')),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: c.gradient, borderRadius: BorderRadius.circular(24), boxShadow: c.orangeShadow),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.landmark, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      t('sa.treasury'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                Text(
                  s == null ? '—' : fmt(s['treasury_balance']),
                  style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Btn(t('sa.generateCoins'), icon: LucideIcons.circlePlus, kind: BtnKind.white, small: true, onTap: () async => (await showGenerate(context)) == true ? load(reset: true) : null),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Btn(t('sa.transferCoins'), icon: LucideIcons.arrowRightLeft, kind: BtnKind.white, small: true, onTap: () async => (await showTransfer(context)) == true ? load(reset: true) : null),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              box(t('sa.inWallets'), s?['customer_balance'], LucideIcons.wallet),
              const SizedBox(width: 10),
              box(t('sa.onCards'), s?['cards_balance'], LucideIcons.creditCard),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              box(t('sa.generated'), s?['generated_total'], LucideIcons.circlePlus),
              const SizedBox(width: 10),
              box(t('sa.sold30'), obj(s?['treasury_out_30d'])['coins'], LucideIcons.send, sub: s == null ? null : usd(obj(s['treasury_out_30d'])['usd'])),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              box(t('sa.signupBonus'), s?['signup_bonus_total'], LucideIcons.gift),
              const SizedBox(width: 10),
              box(t('sa.spent'), s?['spent_total'], LucideIcons.shoppingBag),
            ],
          ),
          const SizedBox(height: 12),
          Panel(
            onTap: () => context.push('/a/cards'),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(LucideIcons.creditCard, color: c.brandInk),
                const SizedBox(width: 12),
                Expanded(child: Text(t('sa.tabCards'), style: const TextStyle(fontWeight: FontWeight.w800))),
                Icon(LucideIcons.chevronRight, size: 18, color: c.muted),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Segs(
            items: [('', t('sa.all')), for (final k in ['generate', 'transfer', 'signup_bonus', 'spend', 'card_create', 'card_redeem']) (k, t.or('sa.typeNames.$k', k))],
            value: _type,
            onTap: (v) {
              setState(() => _type = v);
              load(reset: true);
            },
          ),
          const SizedBox(height: 12),
          Panel(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SecHead(t('sa.history')),
                if (p.error.isNotEmpty) Alert(p.error),
                if (p.page == 0 && p.loading) const SkelList(),
                if (p.page > 0 && p.rows.isEmpty) Muted(t('sa.nothingYet')),
                for (var i = 0; i < p.rows.length; i++) AdminTxRow(x: p.rows[i], t: t, last: i == p.rows.length - 1),
                if (p.page > 0 && p.loading) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
