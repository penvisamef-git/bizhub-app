import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

// Super admin: every license customers bought, what ends soon, what expired (LicensesAdminPage.jsx)
class AdminLicensesPage extends ConsumerStatefulWidget {
  const AdminLicensesPage({super.key});
  @override
  ConsumerState<AdminLicensesPage> createState() => _AdminLicensesPageState();
}

class _AdminLicensesPageState extends ConsumerState<AdminLicensesPage> with PagedLoad {
  String _q = '', _status = '', _kind = '', _type = '', _product = '';
  @override
  String get path => '${Api.admin}/licenses';
  @override
  Map<String, dynamic> get query => {'q': _q, 'status': _status, 'kind': _kind, 'type': _type, 'product': _product, 'limit': 20};

  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  void _set(VoidCallback f) {
    setState(f);
    load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final sum = obj(lastResponse['summary']);
    final types = objs(lastResponse['types']);
    final products = (lastResponse['products'] is List ? lastResponse['products'] as List : const []).map((e) => '$e').toList();
    final productTypes = obj(lastResponse['product_types']);
    Widget tile(String key, String label, Tone tone) => Expanded(
      child: GestureDetector(
        onTap: () => _set(() => _status = _status == key ? '' : key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: _status == key ? c.active : c.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _status == key ? c.brand : c.line),
          ),
          child: Column(
            children: [
              Text(sum[key] == null ? '—' : fmt(sum[key]), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Chip2(label, tone: tone),
            ],
          ),
        ),
      ),
    );
    final typeTotal = types.fold<num>(0, (a, x) => a + n(x['count']));
    return NotificationListener<ScrollNotification>(
      onNotification: onScroll,
      child: SubPage(
        title: t('messages.navLicenses'),
        onRefresh: () => load(reset: true),
        children: [
          Muted(t('lic.adminSub', {'n': 14})),
          const SizedBox(height: 12),
          if (types.isNotEmpty) ...[
            Segs(
              items: [('', '${t('sa.allCategories')} ${fmt(typeTotal)}'), for (final x in types) (str(x['key']), '${t.or('sa.categoryNames.${x['key']}', str(x['key']))} ${fmt(x['count'])}')],
              value: _type,
              onTap: (v) => _set(() {
                _type = v;
                _product = '';
              }),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              tile('active', t('lic.active'), Tone.good),
              const SizedBox(width: 8),
              tile('expiring', t('lic.expiring'), Tone.warn),
              const SizedBox(width: 8),
              tile('expired', t('lic.expired'), Tone.danger),
            ],
          ),
          const SizedBox(height: 12),
          SearchBox(hint: t('lic.search'), onSearch: (v) => _set(() => _q = v)),
          const SizedBox(height: 10),
          Segs(items: [('', t('lic.allKinds')), ('forever', t('lic.kindForever')), ('renew', t('lic.kindRenew'))], value: _kind, onTap: (v) => _set(() => _kind = v)),
          if (products.length > 1) ...[
            const SizedBox(height: 8),
            Segs(items: [('', t('lic.allProducts')), for (final p in products) (p, t.or('lic.products.$p', p))], value: _product, onTap: (v) => _set(() => _product = v)),
          ],
          const SizedBox(height: 12),
          if (p.error.isNotEmpty) Alert(p.error),
          if (p.page == 0 && p.loading) const Panel(child: SkelList()),
          if (p.page > 0 && p.rows.isEmpty) Panel(child: Muted(t('lic.noResults'))),
          if (p.page > 0 && p.rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text('${fmt(p.total)} ${t('sa.total')}', style: Theme.of(context).textTheme.bodySmall),
            ),
          for (final l in p.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LicCard(l: l, t: t, type: str(productTypes[l['product']])),
            ),
          if (p.page > 0 && p.loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _LicCard extends StatelessWidget {
  final Json l;
  final T t;
  final String type;
  const _LicCard({required this.l, required this.t, required this.type});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final st = str(l['status']);
    final cu = obj(l['customer']);
    final biz = obj(l['business']);
    final (label, tone) = switch (st) {
      'expiring' => (t('lic.expiring'), Tone.warn),
      'expired' => (t('lic.expired'), Tone.danger),
      'forever' => (t('lic.forever'), Tone.lime),
      _ => (t('lic.active'), Tone.good),
    };
    final product = t.or('lic.products.${l['product']}', str(l['product']));
    final kind = l['forever'] == true ? t('lic.forever') : t.or('lic.productSub.${l['product']}', t('lic.kindRenew'));
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TypeIcon(type.isNotEmpty ? type : str(biz['category']), size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(str(l['item']).isNotEmpty ? '$product · ${l['item']}' : product, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(kind, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Chip2(label, tone: tone),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                InkWell(
                  onTap: cu['_id'] == null ? null : () => context.push('/a/customer/${cu['_id']}'),
                  child: Row(
                    children: [
                      Avatar(name: str(cu['name']), size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cu.isEmpty ? '-' : str(cu['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                            if (str(cu['email']).isNotEmpty) Text(str(cu['email']), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      if (cu['_id'] != null) Icon(LucideIcons.chevronRight, size: 16, color: c.muted),
                    ],
                  ),
                ),
                Divider(height: 18, color: c.line),
                Row(
                  children: [
                    Icon(LucideIcons.store, size: 15, color: c.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(str(biz['name']).isEmpty ? '-' : str(biz['name']), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(l['expires_at'] == null ? LucideIcons.infinity : LucideIcons.calendarClock, size: 15, color: st == 'expired' ? c.danger : c.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l['expires_at'] == null
                      ? t('lic.neverEnds')
                      : '${fmtDate(l['expires_at'], lang: t.lang)}${st != 'expired' && l['days_left'] != null ? ' · ${t('lic.daysLeft', {'n': l['days_left']})}' : ''}',
                  style: TextStyle(fontSize: 13, color: st == 'expired' ? c.danger : c.muted, fontWeight: FontWeight.w600),
                ),
              ),
              const CoinIcon(size: 15),
              const SizedBox(width: 4),
              Text(fmt(l['total_paid']), style: const TextStyle(fontWeight: FontWeight.w800)),
              if (n(l['renewals']) > 0) ...[const SizedBox(width: 8), Chip2('↻ ${fmt(l['renewals'])}', tone: Tone.brand)],
            ],
          ),
        ],
      ),
    );
  }
}
