import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/tx_sheet.dart';
import '../../widgets/ui.dart';
import '../common/shell.dart';
import 'admin_parts.dart';

double _pct(num part, num total) => total > 0 ? part / total * 100 : 0;

// Super admin home (dashboard/super_admin/SuperDashboardPage.jsx)
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final async = ref.watch(overviewProvider);
    final d = async.valueOrNull;
    final badges = ref.watch(badgesProvider).valueOrNull;
    Future<void> reload() async {
      ref.invalidate(overviewProvider);
      ref.invalidate(badgesProvider);
      try {
        await ref.read(overviewProvider.future);
      } catch (_) {}
    }

    if (d == null) {
      return TabPage(
        onRefresh: reload,
        children: [
          if (async.hasError)
            LoadError(text: t('sa.loadFail'), retry: t('sa.retry'), onRetry: reload)
          else ...[
            const Panel(child: SkelList()),
            const SizedBox(height: 14),
            const Panel(child: SkelList()),
          ],
        ],
      );
    }
    final cust = obj(d['customers']), biz = obj(d['businesses']), coins = obj(d['coins']);
    final signups = objs(d['signups_14d']);
    final signups14 = signups.fold<num>(0, (a, x) => a + n(x['count']));
    final types = objs(d['types']);
    final orders = n(badges?['orders']);
    final chats = n(badges?['chats']);

    return TabPage(
      onRefresh: reload,
      children: [
        Muted(t('sa.saSub')),
        const SizedBox(height: 12),
        if (orders > 0 || chats > 0) ...[
          Row(
            children: [
              if (orders > 0)
                Expanded(
                  child: _Badge(icon: LucideIcons.receiptText, label: t('messages.navCoinOrders'), n: orders, onTap: () => context.push('/a/orders')),
                ),
              if (orders > 0 && chats > 0) const SizedBox(width: 10),
              if (chats > 0)
                Expanded(
                  child: _Badge(icon: LucideIcons.inbox, label: t('messages.navInbox'), n: chats, onTap: () => context.push('/a/inbox')),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        // sign-ups chart
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SecHead(
                t('sa.signups14'),
                sub: '${fmt(signups14)} ${t('sa.total')}',
                trailing: RoundBtn(LucideIcons.arrowRight, size: 36, onTap: () => context.go('/a/customers')),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(gradient: c.gradient, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Text(
                      t('sa.customers'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      fmt(cust['total']),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('+${fmt(cust['new_7d'])} ${t('sa.newThisWeek')}', style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SignupBars(signups: signups),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // status donuts
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SecHead(t('sa.status')),
              _DonutRow(title: t('sa.customers'), active: n(cust['active']), suspended: n(cust['suspended']), total: n(cust['total']), color: c.brand, t: t),
              const SizedBox(height: 16),
              _DonutRow(title: t('sa.businesses'), active: n(biz['active']), suspended: n(biz['suspended']), total: n(biz['total']), color: c.solid, t: t),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // key numbers
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              _Strip(icon: LucideIcons.users, label: t('sa.customers'), value: cust['total'], sub: '+${fmt(cust['new_7d'])} ${t('sa.newThisWeek')}', onTap: () => context.go('/a/customers')),
              _Strip(icon: LucideIcons.building2, label: t('sa.businesses'), value: biz['total'], sub: '+${fmt(biz['new_7d'])} ${t('sa.newThisWeek')}', onTap: () => context.go('/a/businesses')),
              _Strip(icon: LucideIcons.landmark, label: t('sa.treasury'), value: coins['treasury'], sub: '${t('sa.generated')}: ${fmt(coins['generated_total'])}', onTap: () => context.go('/a/coins')),
              _Strip(
                icon: LucideIcons.coins,
                label: t('sa.inWallets'),
                value: coins['in_wallets'],
                sub: '${t('sa.signupBonus')}: ${fmt(coins['signup_bonus_total'])}',
                onTap: () => context.go('/a/coins'),
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // treasury card
        _TreasuryCard(coins: coins, t: t),
        const SizedBox(height: 14),
        // business types
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SecHead(t('sa.servicesUsed'), trailing: RoundBtn(LucideIcons.arrowRight, size: 36, onTap: () => context.go('/a/businesses'))),
              for (final x in types) _TypeBar(x: x, max: types.fold<num>(1, (a, y) => math.max(a, n(y['count']))), t: t),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ListCard(
          title: t('sa.recentCustomers'),
          onMore: () => context.go('/a/customers'),
          empty: t('sa.nothingYet'),
          rows: [
            for (final x in objs(d['recent_customers']).take(5))
              ListRow(
                name: str(x['name']),
                sub: str(x['email']).isNotEmpty ? str(x['email']) : str(x['phone']),
                side: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    statusChip(x['status'] != false, t),
                    const SizedBox(height: 2),
                    Text(fmtDate(x['created_date'], lang: t.lang), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5)),
                  ],
                ),
                onTap: () => context.push('/a/customer/${x['_id']}'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _ListCard(
          title: t('sa.recentBusinesses'),
          onMore: () => context.go('/a/businesses'),
          empty: t('sa.nothingYet'),
          rows: [
            for (final x in objs(d['recent_businesses']).take(5))
              ListRow(
                lead: TypeIcon(str(x['category']), size: 38),
                name: str(x['name']),
                sub: '${t.or('sa.categoryNames.${x['category']}', str(x['category']))} · ${obj(x['owner_id'])['name'] ?? '-'}',
                side: statusChip(x['status'] != false, t),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _ListCard(
          title: t('sa.recentCoins'),
          onMore: () => context.go('/a/coins'),
          empty: t('sa.nothingYet'),
          rows: [for (final x in objs(d['recent_transactions']).take(5)) AdminTxRow(x: x, t: t)],
        ),
        const SizedBox(height: 14),
        _ListCard(
          title: t('sa.recentActivity'),
          onMore: () => context.push('/a/activity'),
          empty: t('sa.nothingYet'),
          rows: [
            for (final a in objs(d['recent_activity']).take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(str(a['title']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(
                      '${a['time'] ?? ''}${str(a['description']).isNotEmpty ? ' · ${a['description']}' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final num n;
  final VoidCallback onTap;
  const _Badge({required this.icon, required this.label, required this.n, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      color: c.active,
      child: Row(
        children: [
          Icon(icon, color: c.brandInk, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(999)),
            child: Text(
              fmt(n),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignupBars extends StatelessWidget {
  final List<Json> signups;
  const _SignupBars({required this.signups});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final mx = signups.fold<num>(1, (a, x) => math.max(a, n(x['count'])));
    var peak = -1;
    for (var i = 0; i < signups.length; i++) {
      if (n(signups[i]['count']) > (peak < 0 ? 0 : n(signups[peak]['count']))) peak = i;
    }
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < signups.length; i++)
            Expanded(
              child: Column(
                children: [
                  if (i == peak)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        fmt(signups[i]['count']),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    )
                  else
                    const SizedBox(height: 18),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(6)),
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: (n(signups[i]['count']) / mx).toDouble(),
                        child: Container(
                          decoration: BoxDecoration(gradient: i == peak ? c.gradient : null, color: i == peak ? null : c.brand.withValues(alpha: .45), borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(str(signups[i]['date']).length >= 10 ? str(signups[i]['date']).substring(8) : '', style: TextStyle(fontSize: 9.5, color: c.muted)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DonutRow extends StatelessWidget {
  final String title;
  final num active, suspended, total;
  final Color color;
  final T t;
  const _DonutRow({required this.title, required this.active, required this.suspended, required this.total, required this.color, required this.t});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget leg(Color col, String label, num v) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: col, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: TextStyle(color: c.muted, fontSize: 13.5)),
          ),
          Text(fmt(v), style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
    return Row(
      children: [
        Donut(value: _pct(active, total), color: color, track: c.chip, size: 92),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              leg(color, t('sa.active'), active),
              leg(c.lineStrong, t('sa.suspended'), suspended),
            ],
          ),
        ),
      ],
    );
  }
}

class _Strip extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Object? value;
  final VoidCallback onTap;
  final bool last;
  const _Strip({required this.icon, required this.label, required this.value, required this.sub, required this.onTap, this.last = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: c.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: c.solid, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: c.onSolid),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  Text(fmt(value), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),
                  Text(
                    sub,
                    style: TextStyle(fontSize: 12, color: c.brandInk, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 18, color: c.muted),
          ],
        ),
      ),
    );
  }
}

class _TreasuryCard extends ConsumerWidget {
  final Json coins;
  final T t;
  const _TreasuryCard({required this.coins, required this.t});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final total = n(coins['treasury']) + n(coins['in_wallets']);
    Widget act(IconData icon, String label, VoidCallback onTap) => Expanded(
      child: Material(
        color: Colors.white.withValues(alpha: .18),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: c.gradient, borderRadius: BorderRadius.circular(24), boxShadow: c.orangeShadow),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('sa.treasury'),
                      style: const TextStyle(color: Color(0xE6FFFFFF), fontWeight: FontWeight.w700),
                    ),
                    Text(
                      fmt(coins['treasury']),
                      style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800),
                    ),
                    Text('${t('sa.inWallets')}: ${fmt(coins['in_wallets'])}', style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 12.5)),
                  ],
                ),
              ),
              Donut(value: _pct(n(coins['treasury']), total), size: 84, stroke: 10, color: Colors.white, track: Colors.white.withValues(alpha: .25), textColor: Colors.white),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              act(LucideIcons.circlePlus, t('sa.generateCoins'), () => showGenerate(context)),
              const SizedBox(width: 10),
              act(LucideIcons.arrowRightLeft, t('sa.transferCoins'), () => showTransfer(context)),
            ],
          ),
        ],
      ),
    );
  }
}

const _dots = [Color(0xFFE0581A), Color(0xFF16171B), Color(0xFFE08A1A), Color(0xFF2F6B2F), Color(0xFF4F7BD9), Color(0xFF9B6BE0)];

class _TypeBar extends StatelessWidget {
  final Json x;
  final num max;
  final T t;
  const _TypeBar({required this.x, required this.max, required this.t});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final i = bizIndex(str(x['key']));
    final col = c.dark && i % 6 == 1 ? c.ink : _dots[i % 6];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: col, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t.or('sa.categoryNames.${x['key']}', str(x['key'])), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
              ),
              Text(fmt(x['count']), style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: LinearProgressIndicator(value: (n(x['count']) / max).toDouble(), minHeight: 6, backgroundColor: c.chip, color: col),
          ),
        ],
      ),
    );
  }
}

int bizIndex(String k) => const ['namecard', 'restaurant', 'attendance', 'guest_house', 'mart', 'menu_qr', 'flipbook', 'qr_gen', 'website', 'debt_book', 'stamp_card', 'event', 'digital_note', 'tg_store'].indexOf(k).clamp(0, 99);

class _ListCard extends StatelessWidget {
  final String title, empty;
  final VoidCallback onMore;
  final List<Widget> rows;
  const _ListCard({required this.title, required this.onMore, required this.empty, required this.rows});
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SecHead(title, trailing: RoundBtn(LucideIcons.arrowRight, size: 36, onTap: onMore)),
        if (rows.isEmpty) Muted(empty),
        ...rows,
      ],
    ),
  );
}

// a coin move line for the super admin: [Spend] 25 · Sokha Chan → BizHub treasury · 13 Oct 20:20
class AdminTxRow extends StatelessWidget {
  final Json x;
  final T t;
  final bool last;
  final String meId; // a customer's page: their side decides + / −
  const AdminTxRow({super.key, required this.x, required this.t, this.last = false, this.meId = ''});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final type = str(x['type']);
    final tone = switch (type) {
      'generate' => Tone.brand,
      'signup_bonus' => Tone.good,
      'spend' => Tone.warn,
      'card_redeem' || 'card_create' => Tone.lime,
      _ => Tone.muted,
    };
    final plus = type == 'generate' || type == 'signup_bonus';
    final who = type == 'generate'
        ? t('sa.treasuryWallet')
        : type == 'signup_bonus'
        ? walletName(x['to_customer'], t)
        : '${walletName(x['from_customer'], t)} → ${walletName(x['to_customer'], t)}';
    return InkWell(
      onTap: () => showTxSheet(context, x, t, admin: true, meId: meId),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: c.line)),
        ),
        child: Row(
          children: [
            Chip2(t.or('sa.typeNames.$type', type), tone: tone),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${plus ? '+' : ''}${fmt(x['amount'])}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(who, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                  if (str(x['note']).isNotEmpty) Text(str(x['note']), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(fmtDate(x['created_date'], time: true, lang: t.lang), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}
