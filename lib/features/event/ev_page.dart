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
import '../team/team_frame.dart' show TeamTopBtn;
import '../mart/mart_common.dart' show GoldBtn;
import 'ev_certs.dart';
import 'ev_common.dart';
import 'ev_design.dart';
import 'ev_events.dart';
import 'ev_grow.dart';
import 'ev_looks.dart';
import 'ev_more.dart';
import 'ev_orders.dart';
import 'ev_team.dart';

// Event Tickets — the app version of the web's EventDashboard.jsx (same API, same words, same sections), all native.
const _tabs = <String, IconData>{
  'events': LucideIcons.ticket,
  'orders': LucideIcons.receiptText,
  'guests': LucideIcons.usersRound,
  'requests': LucideIcons.repeat,
  'promos': LucideIcons.tag,
  'promoters': LucideIcons.megaphone,
  'waitlist': LucideIcons.hourglass,
  'team': LucideIcons.users,
  'report': LucideIcons.chartColumn,
  'certs': LucideIcons.award,
  'feedback': LucideIcons.star,
  'updates': LucideIcons.megaphone,
  'telegram': LucideIcons.send,
  'design': LucideIcons.palette,
  'payment': LucideIcons.creditCard,
  'addons': LucideIcons.puzzle,
};
const _groups = <(String, List<String>)>[
  ('sell', ['events', 'orders', 'guests', 'requests', 'promos', 'promoters', 'waitlist']),
  ('door', ['team', 'report', 'certs', 'feedback', 'updates', 'telegram']),
  ('setup', ['design', 'payment', 'addons']),
];
const _needs = {'promos': 'ev_promos', 'promoters': 'ev_referrals', 'waitlist': 'ev_waitlist', 'feedback': 'ev_feedback', 'updates': 'ev_guest_tg'};
const _graceDays = 7;

class EventPage extends ConsumerStatefulWidget {
  final String id, title, tab;
  const EventPage({super.key, required this.id, this.title = '', this.tab = ''});
  @override
  ConsumerState<EventPage> createState() => _EventPageState();
}

class _EventPageState extends ConsumerState<EventPage> {
  Json? _data;
  String _error = '';
  String? _tab;
  String _event = '', _status = '';
  int _nav = 0;
  Widget? _themeStage;
  String _themeDone = '';

  String get _base => '${Api.user}/businesses/${widget.id}/events';
  String get _current => _tab ?? (_tabs.containsKey(widget.tab) ? widget.tab : 'events');

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
      if (mounted) setState(() => _error = e.network ? ref.read(tProvider)('app.offline') : (e.message.isNotEmpty ? e.message : ref.read(tProvider)('ev.loadFail')));
    }
  }

  void _go(String tab, {String event = '', String status = ''}) {
    setState(() {
      _tab = tab;
      _event = event;
      _status = status;
      _nav++;
    });
  }

  EvCtx _ctx() => EvCtx(
    id: widget.id,
    api: ref.read(apiProvider),
    t: ref.read(tProvider),
    data: _data!,
    reload: _reload,
    askBuy: _buy,
    go: _go,
    notify: (text) => toast(context, text),
    event: _event,
    status: _status,
  );

  // renew · an add-on · featuring an event on the public events page
  Future<void> _buy(String kind, {String? item}) async {
    final ctx = _ctx();
    final api = ref.read(apiProvider);
    final lic = ctx.license;
    late final String name, title, sub, label;
    late final List<String> perks;
    late final num price;
    late final Future<Json> Function() buy;
    IconData icon = LucideIcons.puzzle;
    if (kind == 'renew') {
      price = n(lic['price']);
      name = ctx.m('renewTitle');
      title = name;
      sub = ctx.m('renewSub');
      perks = ['${fmt(price)} ${ctx.m('coins')} ${ctx.m('perYear')}'];
      label = ctx.m('renewFor', {'coins': fmt(price)});
      icon = LucideIcons.calendarClock;
      buy = () => api.post('${Api.user}/businesses/${widget.id}/licenses/event', {'expect': lic['expires_at']});
    } else if (kind == 'feature' && item != null) {
      final ev = ctx.eventById(item) ?? {};
      price = n(obj(ctx.data['feature'])['price']);
      name = ctx.m('grow.featName', {'name': str(ev['title'])});
      title = ctx.m('grow.featTitle');
      sub = ctx.m('grow.featWhat');
      perks = [
        ctx.m('grow.featPerk1'),
        ctx.m('grow.featPerk2'),
        ev['featured_until'] != null ? ctx.m('grow.featUntil', {'d': evWhen(ev['featured_until'], ctx.lang, time: false)}) : ctx.m('grow.feat7'),
      ];
      label = ctx.m('buy', {'coins': fmt(price)});
      icon = LucideIcons.rocket;
      buy = () => api.post('$_base/events/$item/feature');
    } else if (kind == 'theme' && item != null) {
      // item: "ticket|key|eventId" · "page|…" · "cert|…"
      final parts = item.split('|');
      final what = parts[0], key = parts.length > 1 ? parts[1] : '', eid = parts.length > 2 ? parts[2] : '';
      final nice = what == 'cert' ? certName(key, ctx.lang) : (what == 'page' ? pageThemeName(key, ctx.lang) : ticketThemeName(key, ctx.lang));
      price = n(obj(ctx.data[what == 'cert' ? 'cert_themes' : (what == 'page' ? 'page_themes' : 'themes')])['price']);
      name = what == 'cert' ? ctx.m('certs.buyName', {'name': nice}) : ctx.m(what == 'page' ? 'design.pageName' : 'design.name', {'name': nice});
      title = name;
      sub = what == 'cert' ? ctx.m('certs.buyWhat') : ctx.m(what == 'page' ? 'design.pageWhat' : 'design.what');
      perks = ['${ctx.m('oneTime')} · ${ctx.m('forever')}'];
      label = ctx.m('buy', {'coins': fmt(price)});
      icon = what == 'cert' ? LucideIcons.award : LucideIcons.palette;
      _themeDone = ctx.m('design.done', {'name': nice});
      final ev = ctx.eventById(eid) ?? (ctx.events.isEmpty ? {'title': ctx.orgName} : ctx.events.first);
      _themeStage = SizedBox(
        width: 170,
        height: 220,
        child: what == 'cert'
            ? Center(
                child: EvCertView(thumb: true, cert: {...obj(ev['cert']), 'design': key}, name: ctx.m('certs.sampleName'), ev: ev, org: ctx.org),
              )
            : what == 'page'
            ? EvMini(
                width: 360,
                height: 760,
                child: EvPagePreview(ev: ev, org: ctx.org, theme: key, t: ctx.t),
              )
            : FittedBox(
                child: EvTicketView(ev: ev, tk: sampleTicket(ev, ctx.lang), theme: key, colors: const {}, t: ctx.t, lite: true),
              ),
      );
      final path = what == 'cert' ? 'cert-themes' : (what == 'page' ? 'page-themes' : 'themes');
      buy = () => api.post('$_base/$path/$key', {if (eid.isNotEmpty) 'event_id': eid});
    } else {
      final a = ctx.addon(kind);
      if (a.isEmpty) return;
      final yearly = a['days'] != null;
      price = n(a['price']);
      name = ctx.m('addonNames.$kind');
      title = ctx.m('unlockTitle', {'name': name});
      sub = ctx.m('addonWhat.$kind');
      perks = [...ctx.t.list('ev.perks.$kind'), yearly ? '${fmt(price)} ${ctx.m('coins')} ${ctx.m('perYear')}' : '${ctx.m('oneTime')} · ${ctx.m('forever')}'];
      label = ctx.m('buy', {'coins': fmt(price)});
      icon = evAddonIcons[kind] ?? LucideIcons.puzzle;
      buy = () => api.post('${Api.user}/businesses/${widget.id}/licenses/$kind', {'expect': yearly ? a['expires_at'] : null});
    }
    final stage = kind == 'theme' && _themeStage != null
        ? _themeStage!
        : Container(
            width: 150,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
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
                  ctx.orgName,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: const Color(0xFF3A2500).withValues(alpha: .7)),
                ),
              ],
            ),
          );
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BuySheet(
        stage: stage,
        badge: ctx.m('badge'),
        title: title,
        sub: sub,
        perks: perks,
        price: price,
        buyLabel: label,
        doneTitle: name,
        doneSub: kind == 'renew' ? ctx.m('renewTitle') : (kind == 'feature' ? ctx.m('grow.featDone') : (kind == 'theme' ? _themeDone : ctx.m('unlockDone', {'name': name}))),
        doneSubOf: kind == 'renew' ? (r) => ctx.m('renewDone', {'date': evWhen(obj(r['data'])['expires_at'] ?? obj(obj(r['data'])['license'])['expires_at'], ctx.lang, time: false)}) : null,
        doneButton: ctx.t('app.continue'),
        buy: buy,
        onDone: (_) => _reload(),
      ),
    );
    if (mounted) setState(() {});
  }

  void _openSections() {
    final t = ref.read(tProvider);
    final c = context.c;
    final ctx = _ctx();
    final waiting = n(ctx.data['waiting']).toInt();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .8,
        maxChildSize: .95,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text(t('ev.allSections'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ),
            for (final (group, keys) in _groups) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                child: Text(
                  t('ev.groups.$group'),
                  style: TextStyle(color: c.muted, fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
              for (final key in keys)
                _NavRow(
                  icon: _tabs[key]!,
                  label: t('ev.tabs.$key'),
                  on: key == _current,
                  badge: key == 'orders' && waiting > 0 ? waiting : 0,
                  locked: _needs[key] != null && !ctx.on(_needs[key]!),
                  onTap: () {
                    Navigator.pop(sheet);
                    _go(key);
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
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
                  child: _error.isNotEmpty ? LoadError(text: _error, retry: t('ev.retry'), onRetry: _reload) : const SkelList(rows: 6),
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
    final waiting = n(ctx.data['waiting']).toInt();
    final exp = DateTime.tryParse('${lic['expires_at'] ?? ''}');
    final graceLeft = exp == null ? 0 : (_graceDays - DateTime.now().difference(exp).inDays).clamp(0, _graceDays);
    final needRenew = lic['status'] == 'expiring' || lic['in_grace'] == true || lic['locked'] == true;
    final k = ValueKey('$tab$_nav');
    final Widget section = switch (tab) {
      'orders' => OrdersTab(key: k, ctx: ctx),
      'guests' => GuestsTab(key: k, ctx: ctx),
      'requests' => RequestsTab(key: k, ctx: ctx),
      'promos' => PromosTab(key: k, ctx: ctx),
      'promoters' => PromotersTab(key: k, ctx: ctx),
      'waitlist' => WaitlistTab(key: k, ctx: ctx),
      'report' => ReportTab(key: k, ctx: ctx),
      'certs' => CertsTab(key: k, ctx: ctx),
      'feedback' => FeedbackTab(key: k, ctx: ctx),
      'updates' => UpdatesTab(key: k, ctx: ctx),
      'telegram' => TelegramTab(key: k, ctx: ctx),
      'payment' => PaymentTab(key: k, ctx: ctx),
      'addons' => AddonsTab(key: k, ctx: ctx),
      'team' => TeamTab(key: k, ctx: ctx),
      'design' => DesignTab(key: k, ctx: ctx, kind: _status),
      _ => EventsTab(key: ValueKey('events$_nav${ctx.events.length}'), ctx: ctx),
    };
    final logo = str(ctx.org['logo']);
    return Scaffold(
      backgroundColor: c.appBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _top(context, ctx.orgName, logo),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Chip2(t('ev.badge'), icon: LucideIcons.ticket),
                  if (exp != null) ...[
                    const SizedBox(width: 6),
                    Chip2(
                      t('ev.endsOn', {'date': evWhen(exp, ctx.lang, time: false)}),
                      icon: LucideIcons.calendarClock,
                      tone: lic['locked'] == true
                          ? Tone.danger
                          : lic['status'] == 'expiring' || lic['in_grace'] == true
                          ? Tone.warn
                          : Tone.good,
                    ),
                  ],
                  const SizedBox(width: 6),
                  Chip2(fmt(ctx.events.length), icon: LucideIcons.calendarDays),
                  if (waiting > 0) ...[
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: Icon(LucideIcons.bellRing, size: 14, color: c.warn),
                      label: Text(t('ev.waitingN', {'n': waiting})),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _go('orders', status: 'review'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (ctx.business['status'] == false) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Alert(t('ev.suspended'))),
            if (lic['in_grace'] == true || lic['locked'] == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: lic['locked'] == true ? c.dangerBg : c.warnBg, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lic['locked'] == true ? t('ev.lockedTitle') : t('ev.graceTitle'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(lic['locked'] == true ? t('ev.lockedSub') : t('ev.graceSub', {'n': graceLeft}), style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 8),
                      GoldBtn(t('ev.renewFor', {'coins': fmt(n(lic['price']))}), onTap: ctx.business['status'] == false ? null : () => _buy('renew')),
                    ],
                  ),
                ),
              )
            else if (needRenew)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GoldBtn(t('ev.renewFor', {'coins': fmt(n(lic['price']))}), onTap: ctx.business['status'] == false ? null : () => _buy('renew')),
                ),
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
                          child: Text(t('ev.tabs.$tab'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                        if (waiting > 0 && tab != 'orders') ...[_Badge(waiting), const SizedBox(width: 8)],
                        Text(
                          t('ev.allSections'),
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
              child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.ticket, size: 22, color: c.brand),
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

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool on, locked;
  final int badge;
  final VoidCallback onTap;
  const _NavRow({required this.icon, required this.label, required this.on, required this.locked, required this.badge, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: on ? c.active : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: on ? c.brandInk : c.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? c.brandInk : c.ink),
                ),
              ),
              if (badge > 0) _Badge(badge),
              if (locked) ...[const SizedBox(width: 8), Icon(LucideIcons.lock, size: 14, color: c.muted)],
            ],
          ),
        ),
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
