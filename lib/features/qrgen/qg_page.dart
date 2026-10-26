import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart' show fmt;
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/buy_sheet.dart';
import '../../widgets/ui.dart';
import '../team/team_data.dart' show teamViewOnly;
import '../team/team_frame.dart' show TeamTopBtn;
import 'qg_codes.dart';
import 'qg_inbox.dart';
import 'qg_more.dart';
import 'qg_print.dart';
import 'qg_common.dart';
import 'qg_data.dart';
import 'qr_art.dart';

// QR Code Generator — the app version of the web's QrGenDashboard.jsx (same API, same words, same sections).
const _tabs = <String, IconData>{
  'codes': LucideIcons.qrCode,
  'designs': LucideIcons.palette,
  'bulk': LucideIcons.layers,
  'print': LucideIcons.printer,
  'inbox': LucideIcons.inbox,
  'stats': LucideIcons.chartColumn,
  'telegram': LucideIcons.send,
  'profile': LucideIcons.store,
  'addons': LucideIcons.puzzle,
};
const _groups = <(String, List<String>)>[
  ('make', ['codes', 'designs', 'bulk', 'print']),
  ('grow', ['inbox', 'stats', 'telegram']),
  ('more', ['profile', 'addons']),
];
const _needs = {'inbox': 'qr_forms', 'stats': 'qr_stats', 'bulk': 'qr_bulk', 'telegram': 'qr_telegram'};

class QrGenPage extends ConsumerStatefulWidget {
  final String id, title, tab;
  const QrGenPage({super.key, required this.id, this.title = '', this.tab = ''});
  @override
  ConsumerState<QrGenPage> createState() => _QrGenPageState();
}

class _QrGenPageState extends ConsumerState<QrGenPage> {
  Json? _data;
  String _error = '';
  String? _tab;

  String get _base => '${Api.user}/businesses/${widget.id}/qrgen';
  String get _current => _tab ?? (_tabs.containsKey(widget.tab) ? widget.tab : 'codes');

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final api = ref.read(apiProvider);
    try {
      final r = await Future.wait([api.get(_base), api.get('$_base/codes')]);
      if (!mounted) return;
      setState(() {
        _data = {...obj(r[0]['data']), 'codes': objs(r[1]['data'])};
        _error = '';
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.network ? ref.read(tProvider)('app.offline') : (e.message.isNotEmpty ? e.message : ref.read(tProvider)('qg.loadFail')));
    }
  }

  QgCtx _ctx() => QgCtx(
    id: widget.id,
    api: ref.read(apiProvider),
    t: ref.read(tProvider),
    data: _data!,
    reload: _reload,
    askBuy: _buy,
    go: (tab) => setState(() => _tab = _tabs.containsKey(tab) ? tab : 'codes'),
    notify: (text) => toast(context, text),
    put: (patch) {
      if (mounted) setState(() => _data = {..._data!, ...patch(_data!)});
    },
  );

  // one buy screen for: an add-on · a QR design · a page theme · a custom link name · a print template
  Future<void> _buy(Json buying) async {
    final t = ref.read(tProvider);
    final lang = t.lang;
    String m(String k, [Map<String, Object?> v = const {}]) => t('qg.$k', v);
    final data = _data!;
    final prices = obj(data['prices']);
    final api = ref.read(apiProvider);
    final business = str(obj(data['business'])['name']);
    final settings = obj(data['settings']);
    IconData icon = LucideIcons.puzzle;
    Widget? art;
    late String name, title, sub, done;
    late List<String> perks;
    late num price;
    late Future<Json> Function() buy;
    final once = '${m('oneTime')} · ${m('forever')}';
    if (buying['addon'] != null) {
      final key = str(buying['addon']);
      final a = obj(obj(data['addons'])[key]);
      if (a.isEmpty) return;
      final yearly = a['days'] != null;
      icon = qgAddonIcons[key] ?? LucideIcons.puzzle;
      name = t.or('qg.addonNames.$key', key);
      title = m('unlockTitle', {'name': name});
      sub = t.or('qg.addonWhat.$key', '');
      perks = [t.or('qg.addonFree.$key', ''), yearly ? '${fmt(n(a['price']))} ${m('coins')} ${m('perYear')}' : once].where((x) => x.isNotEmpty).toList();
      price = n(a['price']);
      buy = () => api.post('${Api.user}/businesses/${widget.id}/licenses/$key', {'expect': yearly ? a['expires_at'] : null});
      done = m('unlockDone', {'name': name});
    } else if (buying['design'] != null) {
      final key = str(buying['design']);
      price = n(prices['qr_design']);
      name = m('designName', {'name': qrDesigns[key]?.name(lang) ?? key});
      icon = LucideIcons.palette;
      final q = qrDesignArt(text: '${Config.siteUrl}/x/demo', design: key, size: 220, scanMe: m('frameLabelPh'));
      art = SizedBox(
        width: 150,
        child: FittedBox(child: SvgArt(art: q)),
      );
      title = name;
      sub = m('designWhat');
      perks = [once];
      buy = () => api.post('$_base/designs/$key', {});
      done = m('unlockDone', {'name': name});
    } else if (buying['theme'] != null) {
      final key = str(buying['theme']);
      price = n(prices['qr_theme']);
      name = m('themeName', {'name': themeOf(key)?.name(lang) ?? key});
      final color = str(buying['color']).isNotEmpty ? str(buying['color']) : (str(settings['color']).isNotEmpty ? str(settings['color']) : '#E0581A');
      art = ThemeThumb(template: key, color: Color(0xFF000000 | (int.tryParse(color.replaceFirst('#', ''), radix: 16) ?? 0xE0581A)), name: business, business: business, width: 120);
      title = name;
      sub = m('themeWhat');
      perks = [once];
      buy = () => api.post('$_base/themes/$key', {});
      done = m('unlockDone', {'name': name});
    } else if (buying['slug'] != null) {
      final s = buying['slug'] as Map;
      final code = obj(s['code']);
      final value = str(s['value']);
      final cb = s['done'] as void Function(Json)?;
      price = n(prices['qr_slug']);
      icon = LucideIcons.link2;
      name = m('slugTitle');
      title = '${m('slugTitle')}: /x/$value';
      sub = m('slugWhat');
      perks = [once, m('slugOld')];
      buy = () async {
        final r = await api.post('$_base/codes/${code['_id']}/slug', {'slug': value});
        cb?.call(obj(r['data']));
        return r;
      };
      done = '/x/$value';
    } else if (buying['print'] != null) {
      final key = str(buying['print']);
      price = n(prices['qr_print']);
      icon = LucideIcons.printer;
      name = m('printName', {'name': printTpls.where((x) => x.key == key).firstOrNull?.name(lang) ?? key});
      title = name;
      sub = m('printWhat');
      perks = [once];
      buy = () => api.post('$_base/print/$key', {});
      done = m('unlockDone', {'name': name});
    } else {
      return;
    }
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BuySheet(
        stage: Container(
          width: 170,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFD86B), Color(0xFFE0A21A)]),
          ),
          child: Column(
            children: [
              art ?? Icon(icon, size: 54, color: const Color(0xFF5B3A00)),
              const SizedBox(height: 8),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF3A2500)),
              ),
              Text(
                business,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: const Color(0xFF3A2500).withValues(alpha: .7)),
              ),
            ],
          ),
        ),
        badge: 'QR Code Generator',
        title: title,
        sub: sub,
        perks: perks,
        price: price,
        buyLabel: m('buy', {'coins': fmt(price)}),
        doneTitle: name,
        doneSub: done,
        doneButton: t('app.continue'),
        buy: buy,
        onDone: (_) => _reload(),
      ),
    );
    if (mounted) setState(() {});
  }

  void _openSections() {
    final t = ref.read(tProvider);
    final c = context.c;
    final data = _data!;
    final unread = n(obj(data['counts'])['unread']).toInt();
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
            child: Text(t('qg.allSections'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          for (final (group, keys) in _groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
              child: Text(
                t('qg.groups.$group'),
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
                    setState(() => _tab = key);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    child: Row(
                      children: [
                        Icon(_tabs[key], size: 18, color: key == _current ? c.brandInk : c.ink),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            t('qg.tabs.$key'),
                            style: TextStyle(fontWeight: key == _current ? FontWeight.w800 : FontWeight.w600, color: key == _current ? c.brandInk : c.ink),
                          ),
                        ),
                        if (key == 'codes') Text(fmt(objs(data['codes']).length), style: TextStyle(color: c.muted, fontSize: 12.5)),
                        if (key == 'inbox' && unread > 0) ...[_Badge(unread), const SizedBox(width: 6)],
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
    String m(String k, [Map<String, Object?> v = const {}]) => t('qg.$k', v);
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
    final unread = n(ctx.counts['unread']).toInt();
    final Widget section = switch (tab) {
      'codes' => CodesTab(key: const ValueKey('codes'), ctx: ctx),
      'designs' => DesignsTab(key: ValueKey('designs${(_data!['designs'] as List? ?? const []).length}'), ctx: ctx),
      'bulk' => BulkTab(key: ValueKey('bulk${ctx.on('qr_bulk')}'), ctx: ctx),
      'print' => PrintTab(key: const ValueKey('print'), ctx: ctx),
      'inbox' => InboxTab(key: ValueKey('inbox${ctx.on('qr_forms')}'), ctx: ctx),
      'stats' => StatsTab(key: ValueKey('stats${ctx.on('qr_stats')}${ctx.on('qr_geo')}'), ctx: ctx),
      'telegram' => TelegramTab(key: ValueKey('telegram${ctx.on('qr_telegram')}'), ctx: ctx),
      'profile' => ProfileTab(key: const ValueKey('profile'), ctx: ctx),
      _ => AddonsTab(key: const ValueKey('addons'), ctx: ctx),
    };
    final files = ctx.files;
    return Scaffold(
      backgroundColor: c.appBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _top(context, str(ctx.business['name']), ctx.logo),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  const Chip2('QR Code Generator', icon: LucideIcons.qrCode),
                  Chip2(fmt(ctx.codes.length), icon: LucideIcons.qrCode),
                  Chip2(m('fileRoom', {'n': n(files['count']), 'max': n(files['capacity'])}), icon: LucideIcons.fileStack),
                ],
              ),
            ),
            if (ctx.readOnly && !teamViewOnly(ctx.id)) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Alert(m('suspended'))),
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
                          child: Text(t('qg.tabs.$tab'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                        if (unread > 0 && tab != 'inbox') ...[_Badge(unread), const SizedBox(width: 8)],
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
              child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.qrCode, size: 22, color: c.brand),
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
          TeamTopBtn(id: widget.id, name: name), // owner: who else can open this business (v1.5)
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
