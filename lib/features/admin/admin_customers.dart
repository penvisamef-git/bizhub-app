import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../common/shell.dart';
import 'admin_dashboard.dart' show AdminTxRow;
import 'admin_parts.dart';

// A list the API gives page by page (customers, businesses, coin history, coin orders)
class Paged {
  List<Json> rows = [];
  int page = 0, pages = 1;
  num total = 0;
  bool loading = false;
  String error = '';
  bool get more => page < pages;
}

mixin PagedLoad<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  final p = Paged();
  String get path;
  Map<String, dynamic> get query;
  Json lastResponse = {};

  Future<void> load({bool reset = false}) async {
    if (p.loading) return;
    final next = reset ? 1 : p.page + 1;
    setState(() => p.loading = true);
    try {
      final r = await ref.read(apiProvider).get(path, {...query, 'page': next});
      lastResponse = r;
      final pg = obj(r['pagination']);
      setState(() {
        p.rows = reset ? objs(r['data']) : [...p.rows, ...objs(r['data'])];
        p.page = next;
        p.pages = n(pg['totalPages']).toInt().clamp(1, 1 << 30);
        p.total = n(pg['total']);
        p.error = '';
      });
    } on ApiError catch (e) {
      setState(() => p.error = e.network ? ref.read(tProvider)('app.offline') : e.message);
    } finally {
      if (mounted) setState(() => p.loading = false);
    }
  }

  // "Load more" when the list reaches the bottom
  bool onScroll(ScrollNotification s) {
    if (s.metrics.pixels > s.metrics.maxScrollExtent - 400 && p.more && !p.loading && p.error.isEmpty) load();
    return false;
  }
}

class AdminCustomersPage extends ConsumerStatefulWidget {
  const AdminCustomersPage({super.key});
  @override
  ConsumerState<AdminCustomersPage> createState() => _AdminCustomersPageState();
}

class _AdminCustomersPageState extends ConsumerState<AdminCustomersPage> with PagedLoad {
  String _q = '', _status = '';
  @override
  String get path => '${Api.admin}/customers';
  @override
  Map<String, dynamic> get query => {'q': _q, 'status': _status, 'limit': 20};

  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    return NotificationListener<ScrollNotification>(
      onNotification: onScroll,
      child: TabPage(
        onRefresh: () => load(reset: true),
        children: [
          SearchBox(
            hint: t('sa.search'),
            onSearch: (v) {
              _q = v;
              load(reset: true);
            },
          ),
          const SizedBox(height: 10),
          Segs(
            items: [('', t('sa.all')), ('active', t('sa.active')), ('suspended', t('sa.suspended'))],
            value: _status,
            onTap: (v) {
              setState(() => _status = v);
              load(reset: true);
            },
          ),
          const SizedBox(height: 12),
          Panel(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (p.page > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 2),
                    child: Text('${fmt(p.total)} ${t('sa.total')}', style: Theme.of(context).textTheme.bodySmall),
                  ),
                if (p.error.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Alert(p.error)),
                if (p.page == 0 && p.loading) const SkelList(rows: 6),
                if (p.page > 0 && p.rows.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Muted(t('sa.noResults'))),
                for (var i = 0; i < p.rows.length; i++)
                  ListRow(
                    name: str(p.rows[i]['name']).isNotEmpty ? str(p.rows[i]['name']) : str(p.rows[i]['email']),
                    sub: [str(p.rows[i]['email']), str(p.rows[i]['phone'])].where((e) => e.isNotEmpty).join(' · '),
                    side: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CoinIcon(size: 14),
                            const SizedBox(width: 4),
                            Text(fmt(p.rows[i]['coin_balance']), style: const TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                        const SizedBox(height: 3),
                        statusChip(p.rows[i]['status'] != false, t),
                      ],
                    ),
                    last: i == p.rows.length - 1,
                    onTap: () async {
                      await context.push('/a/customer/${p.rows[i]['_id']}');
                      load(reset: true);
                    },
                  ),
                if (p.page > 0 && p.loading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// One customer: wallet, businesses, coin history, suspend / reset password / send coins
class CustomerDetailPage extends ConsumerStatefulWidget {
  final String id;
  const CustomerDetailPage({super.key, required this.id});
  @override
  ConsumerState<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends ConsumerState<CustomerDetailPage> {
  Json? _d;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(apiProvider).get('${Api.admin}/customers/${widget.id}');
      setState(() {
        _d = obj(r['data']);
        _error = '';
      });
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _status(bool on) async {
    final t = ref.read(tProvider);
    final note = TextEditingController(text: str(_d?['admin_note']));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(on ? t('sa.activate') : t('sa.suspend')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!on) Text(t('sa.suspendConfirm')),
            const SizedBox(height: 12),
            Field(controller: note, label: t('sa.adminNote'), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('sa.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: on ? ctx.c.brand : ctx.c.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('sa.confirm')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiProvider).put('${Api.admin}/customers/${widget.id}/status', {'status': on, 'admin_note': note.text});
      ref.invalidate(overviewProvider);
      _load();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> _resetPw() async {
    final t = ref.read(tProvider);
    final pw = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('sa.resetPassword')),
        content: Field(controller: pw, label: '${t('sa.newPassword')} · ${t('sa.passwordMin')}', password: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('sa.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('sa.save'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiProvider).put('${Api.admin}/customers/${widget.id}/reset-password', {'password': pw.text});
      if (mounted) toast(context, t('sa.passwordReset'));
      _load();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final d = _d;
    return SubPage(
      title: t('sa.detail'),
      onRefresh: _load,
      children: [
        if (_error.isNotEmpty) Alert(_error),
        if (d == null && _error.isEmpty) const Panel(child: SkelList()),
        if (d != null) ...[
          Panel(
            child: Column(
              children: [
                Avatar(name: str(d['name']), photo: photoUrl(d['photo']), size: 72, brand: true),
                const SizedBox(height: 10),
                Text(str(d['name']), style: Theme.of(context).textTheme.titleLarge),
                Text([str(d['email']), str(d['phone'])].where((e) => e.isNotEmpty).join(' · '), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Wrap(spacing: 6, children: [statusChip(d['status'] != false, t), Chip2('${fmt(d['active_sessions'])} ${t('sa.activeSessions')}')]),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      const CoinIcon(size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t('sa.balance'), style: Theme.of(context).textTheme.bodySmall),
                            Text(fmt(d['coin_balance']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      Btn(
                        t('sa.sendCoins'),
                        icon: LucideIcons.send,
                        small: true,
                        onTap: () async {
                          if (await showTransfer(context, to: d) == true) _load();
                        },
                      ),
                    ],
                  ),
                ),
                if (str(d['admin_note']).isNotEmpty) ...[const SizedBox(height: 10), Alert(str(d['admin_note']), tone: Tone.warn)],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Btn(t('sa.resetPassword'), icon: LucideIcons.keyRound, kind: BtnKind.ghost, small: true, onTap: _resetPw),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Btn(
                        d['status'] != false ? t('sa.suspend') : t('sa.activate'),
                        icon: d['status'] != false ? LucideIcons.ban : LucideIcons.circleCheck,
                        kind: d['status'] != false ? BtnKind.danger : BtnKind.primary,
                        small: true,
                        onTap: () => _status(d['status'] == false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SecHead(t('sa.businesses')),
                if (objs(d['businesses']).isEmpty) Muted(t('sa.noBusinesses')),
                for (final b in objs(d['businesses']))
                  ListRow(
                    lead: TypeIcon(str(b['category']), size: 38),
                    name: str(b['name']),
                    sub: t.or('sa.categoryNames.${b['category']}', str(b['category'])),
                    side: statusChip(b['status'] != false, t),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SecHead(t('sa.coinHistory')),
                if (objs(d['transactions']).isEmpty) Muted(t('sa.nothingYet')),
                for (final x in objs(d['transactions'])) AdminTxRow(x: x, t: t, meId: str(d['_id'])),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('${t('sa.joined')}: ${fmtDate(d['created_date'], lang: t.lang)}', style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ],
    );
  }
}
