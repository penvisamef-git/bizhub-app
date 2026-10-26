import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/pay.dart';
import '../../widgets/ui.dart';
import '../common/shell.dart';
import 'data.dart';

// My licenses (dashboard/client/licenses/LicensesPage.jsx): what was bought, when it ends, renew
class LicensesPage extends ConsumerStatefulWidget {
  const LicensesPage({super.key});
  @override
  ConsumerState<LicensesPage> createState() => _LicensesPageState();
}

class _LicensesPageState extends ConsumerState<LicensesPage> {
  String _status = ''; // '' | active | expiring | expired
  String _kind = ''; // '' | yearly | forever
  String? _busy;

  Future<void> _renew(Json l) async {
    final t = ref.read(tProvider);
    final name = _name(l, t);
    final price = n(l['renew_price']);
    if (!await confirmPay(context, ref, coins: price, what: '${t('lic.renewTitle', {'name': name})} · ${obj(l['business'])['name'] ?? ''}')) return;
    setState(() => _busy = str(l['_id']));
    try {
      final r = await ref.read(apiProvider).post('${Api.user}/businesses/${obj(l['business'])['_id']}/licenses/${l['product']}', {
        'expect': l['expires_at'],
        if (str(l['item']).isNotEmpty) 'item': l['item'],
      });
      if (r['balance'] is num) ref.read(sessionProvider.notifier).patch({'coin_balance': r['balance']});
      if (mounted) toast(context, t('lic.renewed', {'date': fmtDate(obj(r['data'])['expires_at'], lang: t.lang)}));
      coinsChanged(ref);
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  String _name(Json l, T t) {
    final base = t.or('lic.products.${l['product']}', str(l['product']));
    return str(l['item']).isNotEmpty ? '$base · ${l['item']}' : base;
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final async = ref.watch(licensesProvider);
    final r = async.valueOrNull;
    final rows = objs(r?['data']);
    final sum = obj(r?['summary']);
    final shown = rows.where((l) {
      final st = str(l['status']);
      if (_status == 'active' && !(st == 'active' || st == 'forever')) return false;
      if (_status.isNotEmpty && _status != 'active' && st != _status) return false;
      if (_kind == 'yearly' && l['days'] == null) return false;
      if (_kind == 'forever' && l['days'] != null) return false;
      return true;
    }).toList();
    Widget stat(String key, String label, Object? v, Tone tone) => Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _status = _status == key ? '' : key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: _status == key ? c.active : c.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _status == key ? c.brand : c.line),
          ),
          child: Column(
            children: [
              Text(fmt(v), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Chip2(label, tone: tone),
            ],
          ),
        ),
      ),
    );
    return SubPage(
      title: t('messages.navLicenses'),
      onRefresh: () async {
        ref.invalidate(licensesProvider);
        try {
          await ref.read(licensesProvider.future);
        } catch (_) {}
      },
      children: [
        Muted(t('lic.sub')),
        const SizedBox(height: 14),
        if (async.hasError && r == null) LoadError(text: t('lic.loadFail'), retry: t('app.retry'), onRetry: () => ref.invalidate(licensesProvider)),
        if (r != null) ...[
          Row(
            children: [
              stat('active', t('lic.active'), sum['active'], Tone.good),
              const SizedBox(width: 8),
              stat('expiring', t('lic.expiring'), sum['expiring'], Tone.warn),
              const SizedBox(width: 8),
              stat('expired', t('lic.expired'), sum['expired'], Tone.danger),
            ],
          ),
          if (n(sum['expiring']) > 0) ...[
            const SizedBox(height: 12),
            Alert(t('lic.alertExpiring', {'n': sum['expiring']}), tone: Tone.warn),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final k in [('', t('lic.kindAll')), ('yearly', t('lic.kindYearly')), ('forever', t('lic.kindForever'))])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(k.$2),
                      selected: _kind == k.$1,
                      onSelected: (_) => setState(() => _kind = k.$1),
                      showCheckmark: false,
                      selectedColor: c.solid,
                      backgroundColor: c.card,
                      labelStyle: TextStyle(fontWeight: FontWeight.w700, color: _kind == k.$1 ? c.onSolid : c.ink),
                      side: BorderSide(color: c.line),
                      shape: const StadiumBorder(),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (r == null && !async.hasError) const Panel(child: SkelList()),
        if (r != null && rows.isEmpty)
          Panel(
            child: Column(
              children: [
                Icon(LucideIcons.badgeCheck, size: 30, color: c.brand),
                const SizedBox(height: 10),
                Text(t('lic.empty'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Muted(t('lic.emptySub'), align: TextAlign.center),
                const SizedBox(height: 14),
                Btn(t('lic.goDashboard'), small: true, onTap: () => context.go('/o/home')),
              ],
            ),
          ),
        if (r != null && rows.isNotEmpty && shown.isEmpty) Panel(child: Muted(t('lic.noMatch'))),
        for (final l in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _LicRow(l: l, t: t, name: _name(l, t), busy: _busy == str(l['_id']), onRenew: () => _renew(l)),
          ),
      ],
    );
  }
}

class _LicRow extends StatelessWidget {
  final Json l;
  final T t;
  final String name;
  final bool busy;
  final VoidCallback onRenew;
  const _LicRow({required this.l, required this.t, required this.name, required this.busy, required this.onRenew});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final st = str(l['status']);
    final biz = obj(l['business']);
    final (label, tone) = switch (st) {
      'expiring' => (t('lic.expiring'), Tone.warn),
      'expired' => (t('lic.expired'), Tone.danger),
      'forever' => (t('lic.forever'), Tone.lime),
      _ => (t('lic.active'), Tone.good),
    };
    final when = l['expires_at'] == null
        ? t('lic.neverEnds')
        : st == 'expired'
        ? t('lic.ended', {'date': fmtDate(l['expires_at'], lang: t.lang)})
        : '${t('lic.ends', {'date': fmtDate(l['expires_at'], lang: t.lang)})}${l['days_left'] != null ? ' · ${t('lic.daysLeft', {'n': l['days_left']})}' : ''}';
    final renewable = l['days'] != null && l['renew_price'] != null;
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TypeIcon(str(biz['category']), size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(str(biz['name']), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Chip2(label, tone: tone),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(l['expires_at'] == null ? LucideIcons.infinity : LucideIcons.calendarClock, size: 15, color: st == 'expired' ? c.danger : c.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  when,
                  style: TextStyle(fontSize: 13, color: st == 'expired' ? c.danger : c.muted, fontWeight: FontWeight.w600),
                ),
              ),
              if (renewable)
                Btn(
                  t('lic.renewFor', {'coins': fmt(l['renew_price'])}),
                  lead: const CoinIcon(size: 16),
                  small: true,
                  busy: busy,
                  kind: st == 'active' ? BtnKind.ghost : BtnKind.primary,
                  onTap: onRenew,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
