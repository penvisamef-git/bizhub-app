import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../common/shell.dart';
import 'admin_customers.dart';
import 'admin_parts.dart';

// Coin orders (dashboard/support/CoinOrdersPage.jsx): check the screenshot, then approve or reject
class CoinOrdersPage extends ConsumerStatefulWidget {
  const CoinOrdersPage({super.key});
  @override
  ConsumerState<CoinOrdersPage> createState() => _CoinOrdersPageState();
}

class _CoinOrdersPageState extends ConsumerState<CoinOrdersPage> with PagedLoad {
  String _status = 'pending';
  String? _busy;
  @override
  String get path => '${Api.admin}/coin-orders';
  @override
  Map<String, dynamic> get query => {'status': _status};

  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  Future<void> _approve(Json o) async {
    final t = ref.read(tProvider);
    final who = obj(o['customer_id']);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('support.approve')),
        content: Text(t('app.approveAsk', {'coins': fmt(o['total_coins']), 'name': str(who['name'])})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('sa.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('support.approve'))),
        ],
      ),
    );
    if (ok != true) return;
    await _act(o, 'approve', {}, t('support.approvedOk', {'coins': fmt(o['total_coins'])}));
  }

  Future<void> _reject(Json o) async {
    final t = ref.read(tProvider);
    final why = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, set) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${t('support.reject')} · ${o['no']}', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in t.list('support.rejectReasons'))
                    ActionChip(
                      label: Text(r),
                      onPressed: () => set(() => why.text = r),
                      shape: const StadiumBorder(),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Field(controller: why, label: t('app.rejectReason'), maxLines: 2, maxLength: 300, onChanged: (_) => set(() {})),
              const SizedBox(height: 14),
              Btn(t('support.reject'), kind: BtnKind.danger, icon: LucideIcons.x, onTap: why.text.trim().isEmpty ? null : () => Navigator.pop(ctx, true)),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    await _act(o, 'reject', {'reason': why.text.trim()}, t('support.rejectedOk'));
  }

  Future<void> _act(Json o, String what, Json body, String done) async {
    setState(() => _busy = str(o['_id']));
    try {
      await ref.read(apiProvider).post('${Api.admin}/coin-orders/${o['_id']}/$what', body);
      if (mounted) toast(context, done);
      ref.invalidate(badgesProvider);
      coinsMoved(ref);
      await load(reset: true);
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final counts = obj(lastResponse['counts']);
    String label(String k) {
      final x = obj(counts[k]);
      return '${t('support.status.$k')}${x['n'] != null ? ' ${x['n']}' : ''}';
    }

    return NotificationListener<ScrollNotification>(
      onNotification: onScroll,
      child: SubPage(
        title: t('messages.navCoinOrders'),
        onRefresh: () => load(reset: true),
        children: [
          Muted(t('support.ordersSub')),
          const SizedBox(height: 12),
          Segs(
            items: [for (final k in ['pending', 'approved', 'rejected', 'cancelled']) (k, label(k))],
            value: _status,
            onTap: (v) {
              setState(() => _status = v);
              load(reset: true);
            },
          ),
          const SizedBox(height: 12),
          if (p.error.isNotEmpty) Alert(p.error),
          if (p.page == 0 && p.loading) const Panel(child: SkelList()),
          if (p.page > 0 && p.rows.isEmpty) Panel(child: Muted(t('support.noOrders'))),
          for (final o in p.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OrderCard(o: o, t: t, busy: _busy == str(o['_id']), onApprove: () => _approve(o), onReject: () => _reject(o)),
            ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Json o;
  final T t;
  final bool busy;
  final VoidCallback onApprove, onReject;
  const _OrderCard({required this.o, required this.t, required this.busy, required this.onApprove, required this.onReject});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final who = obj(o['customer_id']);
    final st = str(o['status']);
    final proof = str(o['proof']);
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(str(o['no']), style: Theme.of(context).textTheme.bodySmall),
                    Text(str(who['name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text([str(who['email']), str(who['phone'])].where((e) => e.isNotEmpty).join(' · '), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Chip2(
                t.or('support.status.$st', st),
                tone: switch (st) {
                  'approved' => Tone.good,
                  'rejected' => Tone.danger,
                  'pending' => Tone.warn,
                  _ => Tone.muted,
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const CoinIcon(size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${fmt(o['total_coins'])} ${t('coin.coins')}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                      if (n(o['bonus']) > 0) Text(t('coin.free', {'n': fmt(o['bonus'])}), style: TextStyle(color: c.good, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(usd(o['usd']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    Text(str(obj(o['bank'])['name']), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          if (str(o['reference']).isNotEmpty || str(o['note']).isNotEmpty) ...[
            const SizedBox(height: 8),
            if (str(o['reference']).isNotEmpty) Text('${t('support.ref')}: ${o['reference']}', style: Theme.of(context).textTheme.bodySmall),
            if (str(o['note']).isNotEmpty) Text(str(o['note']), style: Theme.of(context).textTheme.bodySmall),
          ],
          if (st == 'rejected' && str(o['reason']).isNotEmpty) ...[const SizedBox(height: 8), Alert(str(o['reason']))],
          if (proof.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => Dialog(
                  insetPadding: const EdgeInsets.all(12),
                  clipBehavior: Clip.antiAlias,
                  child: InteractiveViewer(child: Image(image: netImage(proof))),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image(image: netImage(
                  proof),
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(height: 60, color: c.chip, alignment: Alignment.center, child: Text(t('support.proof'))),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(fmtDate(o['created_date'], time: true, lang: t.lang), style: Theme.of(context).textTheme.bodySmall),
          if (st == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Btn(t('support.reject'), icon: LucideIcons.x, kind: BtnKind.danger, small: true, onTap: busy ? null : onReject),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Btn(t('support.approve'), icon: LucideIcons.check, small: true, busy: busy, onTap: onApprove),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
