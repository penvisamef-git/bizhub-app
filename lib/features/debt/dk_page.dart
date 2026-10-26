import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/buy_sheet.dart';
import '../../widgets/ui.dart';
import 'dk_common.dart';
import 'dk_customers.dart';
import 'dk_more.dart';

// Debt Book — the app version of the web's DebtDashboard.jsx (same API, same words, same sections).
const _tabs = <String, IconData>{
  'customers': LucideIcons.users,
  'history': LucideIcons.history,
  'reminders': LucideIcons.bellRing,
  'excel': LucideIcons.fileSpreadsheet,
  'settings': LucideIcons.settings,
  'addons': LucideIcons.puzzle,
};
const _groups = <(String, List<String>)>[
  ('book', ['customers', 'history']),
  ('tools', ['reminders', 'excel']),
  ('more', ['settings', 'addons']),
];
const _needs = {'reminders': 'debt_remind', 'excel': 'debt_excel'};

class DebtPage extends ConsumerStatefulWidget {
  final String id, title, tab;
  const DebtPage({super.key, required this.id, this.title = '', this.tab = ''});
  @override
  ConsumerState<DebtPage> createState() => _DebtPageState();
}

class _DebtPageState extends ConsumerState<DebtPage> {
  Json? _data;
  String _error = '';
  String? _tab;
  String _openCustomer = '';
  int _nav = 0; // bumps so the customers tab opens a person from History

  String get _base => '${Api.user}/businesses/${widget.id}/debt';
  String get _current => _tab ?? (_tabs.containsKey(widget.tab) ? widget.tab : 'customers');

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final r = await ref.read(apiProvider).get(_base);
      if (!mounted) return;
      setState(() {
        _data = obj(r['data']);
        _error = '';
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.network ? ref.read(tProvider)('app.offline') : (e.message.isNotEmpty ? e.message : ref.read(tProvider)('debt.loadFail')));
    }
  }

  DkCtx _ctx() => DkCtx(
    id: widget.id,
    api: ref.read(apiProvider),
    t: ref.read(tProvider),
    data: _data!,
    reload: _reload,
    askBuy: _buy,
    go: (tab, {customer}) => setState(() {
      _tab = tab;
      _openCustomer = customer ?? '';
      _nav++;
    }),
    notify: (text) => toast(context, text),
  );

  Future<void> _buy(String key) async {
    final t = ref.read(tProvider);
    String m(String k, [Map<String, Object?> v = const {}]) => t('debt.$k', v);
    final data = _data!;
    final a = obj(obj(data['addons'])[key]);
    if (a.isEmpty) return;
    final yearly = a['days'] != null;
    final price = n(a['price']);
    final name = t.or('debt.addonNames.$key', key);
    final book = obj(data['book']);
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BuySheet(
        stage: Container(
          width: 150,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFD86B), Color(0xFFE0A21A)]),
          ),
          child: Column(
            children: [
              Icon(dkAddonIcons[key] ?? LucideIcons.puzzle, size: 54, color: const Color(0xFF5B3A00)),
              const SizedBox(height: 8),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF3A2500)),
              ),
              Text(
                str(book['shop_name']).isNotEmpty ? str(book['shop_name']) : str(obj(data['business'])['name']),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: const Color(0xFF3A2500).withValues(alpha: .7)),
              ),
            ],
          ),
        ),
        badge: m('badge'),
        title: m('unlockTitle', {'name': name}),
        sub: t.or('debt.addonWhat.$key', ''),
        perks: [...t.list('debt.perks.$key'), yearly ? '${fmt(price)} ${m('coins')} ${m('perYear')}' : '${m('oneTime')} · ${m('forever')}'],
        price: price,
        buyLabel: m('buy', {'coins': fmt(price)}),
        doneTitle: name,
        doneSub: m('unlockDone', {'name': name}),
        doneButton: t('app.continue'),
        buy: () => ref.read(apiProvider).post('${Api.user}/businesses/${widget.id}/licenses/$key', {'expect': yearly ? a['expires_at'] : null}),
        onDone: (_) => _reload(),
      ),
    );
    if (mounted) setState(() {});
  }

  void _openSections() {
    final t = ref.read(tProvider);
    final c = context.c;
    final data = _data!;
    final totals = obj(data['totals']);
    bool on(String k) => obj(obj(data['addons'])[k])['active'] == true;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheet) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(t('debt.allSections'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          for (final (group, keys) in _groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
              child: Text(
                t('debt.groups.$group'),
                style: TextStyle(color: c.muted, fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ),
            for (final key in keys)
              Material(
                color: key == _current ? c.active : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.pop(sheet);
                    setState(() {
                      _tab = key;
                      _openCustomer = '';
                      _nav++;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    child: Row(
                      children: [
                        Icon(_tabs[key], size: 18, color: key == _current ? c.brandInk : c.ink),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            t('debt.tabs.$key'),
                            style: TextStyle(fontWeight: key == _current ? FontWeight.w800 : FontWeight.w600, color: key == _current ? c.brandInk : c.ink),
                          ),
                        ),
                        if (key == 'customers') ...[
                          Text(fmt(n(totals['customers'])), style: TextStyle(color: c.muted, fontSize: 12.5)),
                          if (n(totals['overdue']) > 0) ...[const SizedBox(width: 6), _Badge(n(totals['overdue']).toInt())],
                        ],
                        if (_needs[key] != null && !on(_needs[key]!)) Icon(LucideIcons.lock, size: 13, color: c.muted),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    String m(String k) => t('debt.$k');
    if (_data == null) {
      return Scaffold(
        backgroundColor: c.appBg,
        body: SafeArea(
          child: Column(
            children: [
              _top(context, widget.title, null),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _error.isNotEmpty ? LoadError(text: _error, retry: m('retry'), onRetry: _reload) : const SkelList(rows: 6),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final ctx = _ctx();
    final tab = _current;
    final b = ctx.book;
    final overdue = n(ctx.totals['overdue']).toInt();
    final Widget section = switch (tab) {
      'history' => HistoryTab(key: const ValueKey('history'), ctx: ctx),
      'reminders' => RemindersTab(key: ValueKey('reminders${ctx.on('debt_remind')}'), ctx: ctx),
      'excel' => ExcelTab(key: ValueKey('excel${ctx.on('debt_excel')}'), ctx: ctx),
      'settings' => SettingsTab(key: ValueKey('settings${b['logo']}'), ctx: ctx),
      'addons' => AddonsTab(key: const ValueKey('addons'), ctx: ctx),
      _ => CustomersTab(key: ValueKey('customers$_nav'), ctx: ctx, initial: _openCustomer),
    };
    return Scaffold(
      backgroundColor: c.appBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _top(context, str(b['shop_name']).isNotEmpty ? str(b['shop_name']) : str(ctx.business['name']), str(b['logo'])),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip2(m('badge'), icon: LucideIcons.notebookPen),
              ),
            ),
            if (ctx.readOnly) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Alert(m('suspended'))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Material(
                color: c.card,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _openSections,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(_tabs[tab], size: 18, color: c.brand),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(t('debt.tabs.$tab'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                        if (overdue > 0 && tab != 'customers') ...[_Badge(overdue), const SizedBox(width: 8)],
                        Text(
                          m('allSections'),
                          style: TextStyle(color: c.muted, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(width: 4),
                        Icon(LucideIcons.chevronDown, size: 16, color: c.muted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: section),
          ],
        ),
      ),
    );
  }

  Widget _top(BuildContext context, String name, String? logo) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: [
          RoundBtn(LucideIcons.arrowLeft, size: 42, onTap: () => context.pop()),
          const SizedBox(width: 10),
          if (logo != null) ...[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(14)),
              clipBehavior: Clip.antiAlias,
              child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.notebookPen, size: 22, color: c.brand),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int n;
  const _Badge(this.n);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: context.c.danger, borderRadius: BorderRadius.circular(99)),
    child: Text(
      n > 99 ? '99+' : '$n',
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11.5),
    ),
  );
}
