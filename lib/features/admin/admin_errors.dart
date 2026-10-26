import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../common/shell.dart';
import 'admin_customers.dart';
import 'admin_parts.dart';

// Super admin → App errors: crashes the BizHub app sent (core/crash.dart → POST /api/public/app-error)
class AdminErrorsPage extends ConsumerStatefulWidget {
  const AdminErrorsPage({super.key});
  @override
  ConsumerState<AdminErrorsPage> createState() => _AdminErrorsPageState();
}

class _AdminErrorsPageState extends ConsumerState<AdminErrorsPage> with PagedLoad {
  String _resolved = '0';
  @override
  String get path => '${Api.admin}/app-errors';
  @override
  Map<String, dynamic> get query => {'resolved': _resolved, 'limit': 20};

  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  Future<void> _set(Json e, {bool? resolved, bool delete = false}) async {
    final api = ref.read(apiProvider);
    try {
      delete ? await api.delete('${Api.admin}/app-errors/${e['_id']}') : await api.put('${Api.admin}/app-errors/${e['_id']}', {'resolved': resolved});
      if (mounted) Navigator.of(context).maybePop();
      load(reset: true);
    } on ApiError catch (x) {
      if (mounted) toast(context, x.message);
    }
  }

  void _open(Json e) {
    final t = ref.read(tProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final c = ctx.c;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .85,
          maxChildSize: .95,
          builder: (_, sc) => ListView(
            controller: sc,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(t('app.errTitle'), style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 10),
              SelectableText(
                str(e['message']),
                style: TextStyle(fontWeight: FontWeight.w700, color: c.danger),
              ),
              const SizedBox(height: 10),
              for (final (k, v) in [
                (t('app.errScreen'), str(e['route'])),
                (t('app.errWhere'), str(e['context'])),
                (t('app.errDevice'), '${e['platform']} ${e['os']} · v${e['version']}'),
                (t('app.errCount'), '${fmt(e['count'])}× · ${fmtDate(e['first_at'], time: true, lang: t.lang)} → ${fmtDate(e['last_at'], time: true, lang: t.lang)}'),
                (t('app.errUsers'), (e['users'] is List ? (e['users'] as List).join(', ') : '')),
              ])
                if (v.trim().isNotEmpty && v.trim() != '·')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(k, style: Theme.of(ctx).textTheme.bodySmall),
                        SelectableText(v, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
                child: SelectableText(str(e['stack']), style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.4)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Btn(
                      t('app.errCopy'),
                      icon: LucideIcons.copy,
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: '${e['message']}\n${e['context']}\nscreen: ${e['route']}\n${e['platform']} ${e['os']} v${e['version']}\n\n${e['stack']}'));
                        toast(context, t('sa.copied'));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: e['resolved'] == true
                        ? Btn(t('app.errReopen'), icon: LucideIcons.rotateCcw, small: true, onTap: () => _set(e, resolved: false))
                        : Btn(t('app.errFixed'), icon: LucideIcons.check, small: true, onTap: () => _set(e, resolved: true)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Btn(t('app.errDelete'), icon: LucideIcons.trash2, kind: BtnKind.danger, small: true, onTap: () => _set(e, delete: true)),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    return NotificationListener<ScrollNotification>(
      onNotification: onScroll,
      child: SubPage(
        title: t('app.errPage'),
        onRefresh: () => load(reset: true),
        children: [
          Muted(t('app.errSub')),
          const SizedBox(height: 12),
          Segs(
            items: [('0', '${t('app.errOpen')}${lastResponse['open'] != null ? ' ${lastResponse['open']}' : ''}'), ('1', t('app.errFixedTab')), ('', t('sa.all'))],
            value: _resolved,
            onTap: (v) {
              setState(() => _resolved = v);
              load(reset: true);
            },
          ),
          const SizedBox(height: 12),
          if (p.error.isNotEmpty) Alert(p.error),
          if (p.page == 0 && p.loading) const Panel(child: SkelList()),
          if (p.page > 0 && p.rows.isEmpty) Panel(child: Muted(t('app.errNone'))),
          for (final e in p.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                padding: const EdgeInsets.all(14),
                onTap: () => _open(e),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: e['resolved'] == true ? c.goodBg : c.dangerBg, borderRadius: BorderRadius.circular(12)),
                      child: Icon(e['resolved'] == true ? LucideIcons.check : LucideIcons.bug, size: 18, color: e['resolved'] == true ? c.good : c.danger),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            str(e['message']).split('\n').first,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            [str(e['route']), '${e['platform']} · v${e['version']}', fmtDate(e['last_at'], time: true, lang: t.lang)].where((x) => x.isNotEmpty).join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip2('${fmt(e['count'])}×', tone: n(e['count']) > 9 ? Tone.danger : Tone.warn),
                  ],
                ),
              ),
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
