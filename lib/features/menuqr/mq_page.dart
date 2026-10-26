import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt, fmtDate;
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/buy_sheet.dart';
import '../../widgets/ui.dart';
import '../team/team_frame.dart' show TeamTopBtn;
import '../common/qr_card.dart' show qrStyles;
import '../mart/mart_common.dart' show mDate;
import 'mq_common.dart';
import 'mq_looks.dart';
import 'mq_menu.dart';
import 'mq_more.dart';
import 'mq_profile.dart';

// Menu QR Code — the app version of the web's MenuQrDashboard.jsx (same API, same words, same sections).
const _tabs = <String, IconData>{
  'menu': LucideIcons.utensilsCrossed,
  'media': LucideIcons.images,
  'profile': LucideIcons.store,
  'looks': LucideIcons.palette,
  'promos': LucideIcons.tag,
  'qr': LucideIcons.qrCode,
  'feedback': LucideIcons.messageSquareHeart,
  'stats': LucideIcons.chartColumn,
  'addons': LucideIcons.puzzle,
};
const _groups = <(String?, List<String>)>[
  ('build', ['menu', 'media', 'profile', 'looks', 'promos']),
  ('share', ['qr']),
  ('grow', ['feedback', 'stats']),
  (null, ['addons']),
];
const _needs = {'promos': 'mq_promos', 'feedback': 'mq_feedback', 'stats': 'mq_stats'};

class MenuQrPage extends ConsumerStatefulWidget {
  final String id, title, tab;
  const MenuQrPage({super.key, required this.id, this.title = '', this.tab = ''});
  @override
  ConsumerState<MenuQrPage> createState() => _MenuQrPageState();
}

class _MenuQrPageState extends ConsumerState<MenuQrPage> {
  Json? _data;
  String _error = '';
  String? _tab;

  String get _base => '${Api.user}/businesses/${widget.id}/menuqr';
  String get _current => _tab ?? (_tabs.containsKey(widget.tab) ? widget.tab : 'menu');

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
      if (mounted) setState(() => _error = e.network ? ref.read(tProvider)('app.offline') : (e.message.isNotEmpty ? e.message : ref.read(tProvider)('mq.loadFail')));
    }
  }

  MqCtx _ctx() => MqCtx(
    id: widget.id,
    api: ref.read(apiProvider),
    t: ref.read(tProvider),
    data: _data!,
    reload: _reload,
    askBuy: _buy,
    go: (tab) => setState(() => _tab = _tabs.containsKey(tab) ? tab : 'menu'),
    notify: (text) => toast(context, text),
    put: (patch) {
      if (mounted) setState(() => _data = {..._data!, ...patch(_data!)});
    },
  );

  // one buy screen for: renewing · an add-on · a menu look · a QR style
  Future<void> _buy(Json buying) async {
    final t = ref.read(tProvider);
    final lang = t.lang;
    String m(String k, [Map<String, Object?> v = const {}]) => t('mq.$k', v);
    final data = _data!;
    final api = ref.read(apiProvider);
    final lic = obj(data['license']);
    final business = str(obj(data['business'])['name']);
    final once = '${m('oneTime')} · ${m('forever')}';
    final renew = buying['renew'] == true;
    IconData icon = LucideIcons.puzzle;
    late String name, title, sub, done;
    late List<String> perks;
    late num price;
    late Future<Json> Function() buy;
    if (renew) {
      icon = LucideIcons.calendarClock;
      name = title = m('renewTitle');
      sub = m('renewSub');
      perks = [];
      price = n(data['renew_price']);
      buy = () => api.post('${Api.user}/businesses/${widget.id}/licenses/menu_qr', {'expect': lic['expires_at']});
      done = '';
    } else if (buying['addon'] != null) {
      final key = str(buying['addon']);
      final a = obj(obj(data['addons'])[key]);
      if (a.isEmpty) return;
      icon = mqAddonIcons[key] ?? LucideIcons.puzzle;
      name = t.or('mq.addonNames.$key', key);
      title = m('unlockTitle', {'name': name});
      sub = t.or('mq.addonWhat.$key', '');
      perks = [t.or('mq.addonFree.$key', ''), a['days'] != null ? '${fmt(n(a['price']))} ${m('coins')} ${m('perYear')}' : once].where((x) => x.isNotEmpty).toList();
      price = n(a['price']);
      buy = () => api.post('${Api.user}/businesses/${widget.id}/licenses/$key', {'expect': a['expires_at']});
      done = m('unlockDone', {'name': name});
    } else if (buying['theme'] != null) {
      final key = str(buying['theme']);
      price = n(obj(obj(data['themes'])['price'])[str(buying['tier'])]);
      name = m('themeName', {'name': str(buying['label']).isNotEmpty ? str(buying['label']) : key});
      icon = LucideIcons.palette;
      title = name;
      sub = m('themeWhat');
      perks = [once];
      buy = () => api.post('$_base/themes/$key', {});
      done = m('unlockDone', {'name': name});
    } else if (buying['qr'] != null) {
      final key = str(buying['qr']);
      final st = qrStyles[key];
      price = n(obj(data['qr'])['price']);
      name = m('qrName', {'name': st == null ? key : (lang == 'km' ? st.km : st.en)});
      icon = LucideIcons.qrCode;
      title = name;
      sub = m('qrWhat');
      perks = [once];
      buy = () => api.post('$_base/qr-styles/$key', {});
      done = m('unlockDone', {'name': name});
    } else {
      return;
    }
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BuySheet(
        // the look itself when the caller sends its picture, else the gold card
        stage: buying['stage'] is Widget
            ? buying['stage'] as Widget
            : Container(
                width: 170,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFD86B), Color(0xFFE0A21A)]),
                ),
                child: Column(
                  children: [
                    Icon(icon, size: 54, color: const Color(0xFF5B3A00)),
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
        badge: renew ? 'Menu QR Code' : m('tabs.addons'),
        title: title,
        sub: sub,
        perks: perks,
        price: price,
        buyLabel: renew ? m('renewFor', {'coins': fmt(price)}) : m('buy', {'coins': fmt(price)}),
        doneTitle: name,
        doneSub: done,
        doneSubOf: renew ? (res) => m('renewDone', {'date': fmtDate(obj(res['data'])['expires_at'], lang: lang)}) : null,
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
    final media = obj(data['media']);
    final unread = n(obj(data['counts'])['feedback_unread']);
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
            child: Text(t('mq.allSections'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          for (final (group, keys) in _groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
              child: group == null
                  ? const Divider(height: 1)
                  : Text(
                      t('mq.groups.$group'),
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
                            t('mq.tabs.$key'),
                            style: TextStyle(fontWeight: key == _current ? FontWeight.w800 : FontWeight.w600, color: key == _current ? c.brandInk : c.ink),
                          ),
                        ),
                        if (key == 'media' && media.isNotEmpty)
                          Text('${media['count']}/${media['capacity']}', style: TextStyle(color: n(media['count']) >= n(media['capacity']) ? c.danger : c.muted, fontSize: 12.5)),
                        if (key == 'feedback' && unread > 0) Chip2(unread > 99 ? '99+' : '$unread', tone: Tone.danger),
                        if (_needs[key] != null && !on(_needs[key]!)) ...[const SizedBox(width: 6), Icon(LucideIcons.lock, size: 13, color: c.muted)],
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
    String m(String k, [Map<String, Object?> v = const {}]) => t('mq.$k', v);
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
    final lic = ctx.license;
    final url = menuUrl(ctx.settings['slug']);
    final suspended = ctx.business['status'] == false;
    final graceLeft = lic['grace_until'] == null ? 0 : ((DateTime.tryParse(str(lic['grace_until']))?.difference(DateTime.now()).inHours ?? 0) / 24).ceil().clamp(0, 999);
    final Widget section = switch (tab) {
      'menu' => MenuTab(key: const ValueKey('menu'), ctx: ctx),
      'media' => MediaTab(key: const ValueKey('media'), ctx: ctx),
      'profile' => ProfileTab(key: ValueKey('profile${ctx.settings['slug']}'), ctx: ctx),
      'looks' => LooksTab(key: ValueKey('looks${(obj(_data!['themes'])['owned'] as List? ?? const []).length}${ctx.settings['theme']}'), ctx: ctx),
      'promos' => PromosTab(key: ValueKey('promos${ctx.on('mq_promos')}'), ctx: ctx),
      'qr' => QrTab(key: ValueKey('qr${obj(ctx.settings['qr'])['style']}${ctx.settings['slug']}${(obj(_data!['qr'])['owned'] as List? ?? const []).length}'), ctx: ctx),
      'feedback' => FeedbackTab(key: ValueKey('feedback${ctx.on('mq_feedback')}'), ctx: ctx),
      'stats' => StatsTab(key: ValueKey('stats${ctx.on('mq_stats')}'), ctx: ctx),
      _ => AddonsTab(key: const ValueKey('addons'), ctx: ctx),
    };
    return Scaffold(
      backgroundColor: c.appBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _top(context, str(ctx.business['name']), ctx.logo),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Chip2('Menu QR Code', icon: LucideIcons.qrCode),
                    if (lic['expires_at'] != null)
                      Chip2(
                        m('endsOn', {'date': mDate(lic['expires_at'], t.lang)}),
                        icon: LucideIcons.calendarClock,
                        tone: lic['locked'] == true || lic['status'] == 'expired'
                            ? Tone.danger
                            : lic['status'] == 'expiring'
                            ? Tone.warn
                            : Tone.muted,
                      ),
                    Chip2(fmt(n(ctx.counts['items'])), icon: LucideIcons.utensilsCrossed),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Btn(
                    m('openMenu'),
                    icon: LucideIcons.externalLink,
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                  ),
                  const SizedBox(width: 6),
                  Btn(
                    m('copyLink'),
                    icon: LucideIcons.copy,
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: url));
                      if (context.mounted) toast(context, m('copied'));
                    },
                  ),
                ],
              ),
            ),
            if (suspended) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Alert(m('suspended'))),
            if (lic['in_grace'] == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Alert('${m('graceTitle')} ${m('graceSub', {'n': graceLeft})}', tone: Tone.warn),
              ),
            if (lic['locked'] == true) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Alert('${m('lockedTitle')} ${m('lockedSub')}')),
            if (lic['status'] == 'expiring' || lic['in_grace'] == true || lic['locked'] == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Btn(m('renewFor', {'coins': fmt(n(_data!['renew_price']))}), lead: const CoinIcon(size: 16), expand: true, onTap: suspended ? null : () => _buy({'renew': true})),
              ),
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
                          child: Text(t('mq.tabs.$tab'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
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
