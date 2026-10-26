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
import '../owner/home_page.dart' show bizTypes;
import 'admin_customers.dart';
import 'admin_parts.dart';

// All businesses (dashboard/super_admin/BusinessesPage.jsx)
class AdminBusinessesPage extends ConsumerStatefulWidget {
  const AdminBusinessesPage({super.key});
  @override
  ConsumerState<AdminBusinessesPage> createState() => _AdminBusinessesPageState();
}

class _AdminBusinessesPageState extends ConsumerState<AdminBusinessesPage> with PagedLoad {
  String _q = '', _status = '', _cat = '';
  @override
  String get path => '${Api.admin}/businesses';
  @override
  Map<String, dynamic> get query => {'q': _q, 'status': _status, 'category': _cat, 'limit': 20};

  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  Future<void> _open(Json b) async {
    final t = ref.read(tProvider);
    final owner = obj(b['owner_id']);
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final c = ctx.c;
        final on = b['status'] != false;
        final note = TextEditingController(text: str(b['admin_note']));
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  TypeIcon(str(b['category']), size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(str(b['name']), style: Theme.of(ctx).textTheme.titleLarge),
                        Text(t.or('sa.categoryNames.${b['category']}', str(b['category'])), style: Theme.of(ctx).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  statusChip(on, t),
                ],
              ),
              const SizedBox(height: 14),
              ListRow(
                name: str(owner['name']).isNotEmpty ? str(owner['name']) : '-',
                sub: [str(owner['email']), str(owner['phone'])].where((e) => e.isNotEmpty).join(' · '),
                side: Icon(LucideIcons.chevronRight, size: 18, color: c.muted),
                onTap: owner['_id'] == null
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        context.push('/a/customer/${owner['_id']}');
                      },
                last: true,
              ),
              Text('${t('sa.created')}: ${fmtDate(b['created_date'], lang: t.lang)}', style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 14),
              Field(controller: note, label: t('sa.adminNote'), maxLines: 2),
              if (on) ...[const SizedBox(height: 10), Muted(t('sa.suspendBizConfirm'))],
              const SizedBox(height: 14),
              Btn(
                on ? t('sa.suspend') : t('sa.activate'),
                icon: on ? LucideIcons.ban : LucideIcons.circleCheck,
                kind: on ? BtnKind.danger : BtnKind.primary,
                onTap: () async {
                  try {
                    await ref.read(apiProvider).put('${Api.admin}/businesses/${b['_id']}/status', {'status': !on, 'admin_note': note.text});
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } on ApiError catch (e) {
                    if (ctx.mounted) toast(ctx, e.message);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
    if (changed == true) {
      ref.invalidate(overviewProvider);
      load(reset: true);
    }
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
            hint: t('sa.searchBiz'),
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
          const SizedBox(height: 8),
          Segs(
            items: [('', t('sa.allCategories')), for (final k in bizTypes) (k, t('sa.categoryNames.$k'))],
            value: _cat,
            onTap: (v) {
              setState(() => _cat = v);
              load(reset: true);
            },
          ),
          const SizedBox(height: 12),
          Panel(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (p.page > 0) Padding(padding: const EdgeInsets.only(top: 6, bottom: 2), child: Text('${fmt(p.total)} ${t('sa.total')}', style: Theme.of(context).textTheme.bodySmall)),
                if (p.error.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Alert(p.error)),
                if (p.page == 0 && p.loading) const SkelList(rows: 6),
                if (p.page > 0 && p.rows.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Muted(t('sa.noResults'))),
                for (var i = 0; i < p.rows.length; i++)
                  ListRow(
                    lead: TypeIcon(str(p.rows[i]['category']), size: 40),
                    name: str(p.rows[i]['name']),
                    sub: '${t.or('sa.categoryNames.${p.rows[i]['category']}', str(p.rows[i]['category']))} · ${obj(p.rows[i]['owner_id'])['name'] ?? '-'}',
                    side: statusChip(p.rows[i]['status'] != false, t),
                    last: i == p.rows.length - 1,
                    onTap: () => _open(p.rows[i]),
                  ),
                if (p.page > 0 && p.loading) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
