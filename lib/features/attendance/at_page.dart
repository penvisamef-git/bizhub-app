import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart' show fmt, fmtDate;
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/buy_sheet.dart';
import '../../widgets/ui.dart';
import '../team/team_frame.dart' show TeamTopBtn;
import '../mart/mart_common.dart' show mDate;
import 'at_addons.dart';
import 'at_common.dart';
import 'at_daily.dart';
import 'at_days.dart';
import 'at_engage.dart';
import 'at_website.dart';
import 'at_looks.dart';
import 'at_pay.dart';
import 'at_report.dart';
import 'at_setup.dart';
import '../owner/coin_play.dart' show playBilling;

// Attendance — the app version of the web's AttendanceDashboard.jsx (same API, same words, same sections).
//   GET /api/user/businesses/:id/attendance
const _tabs = <String, IconData>{
  'today': LucideIcons.sun,
  'review': LucideIcons.inbox,
  'report': LucideIcons.chartColumn,
  'roster': LucideIcons.calendarRange,
  'leave': LucideIcons.fileText,
  'payroll': LucideIcons.coins,
  'news': LucideIcons.megaphone,
  'rewards': LucideIcons.award,
  'staff': LucideIcons.users,
  'branches': LucideIcons.mapPin,
  'shifts': LucideIcons.clock,
  'holidays': LucideIcons.calendarHeart,
  'settings': LucideIcons.settings2,
  'looks': LucideIcons.palette,
  'telegram': LucideIcons.send,
  'kiosk': LucideIcons.scanLine,
  'website': LucideIcons.globe,
  'addons': LucideIcons.puzzle,
};
const _groups = <(String?, List<String>)>[
  ('daily', ['today', 'review', 'report', 'roster', 'leave', 'payroll', 'news', 'rewards']),
  ('setup', ['staff', 'branches', 'shifts', 'holidays', 'settings', 'looks', 'telegram', 'kiosk', 'website']),
  (null, ['addons']),
];
const _stepOf = {'branches': 'branch', 'shifts': 'shift', 'staff': 'staff', 'settings': 'link'};
const _needs = {
  'leave': 'att_leave',
  'payroll': 'att_payroll',
  'telegram': 'att_telegram',
  'kiosk': 'att_kiosk',
  'website': 'att_website',
  'roster': 'att_roster',
  'news': 'att_news',
  'rewards': 'att_rewards',
};
// rebuilt in the app so far (the others come in the next parts)
// every section is rebuilt in the app
const _native = {
  'today',
  'review',
  'report',
  'staff',
  'branches',
  'shifts',
  'settings',
  'addons',
  'roster',
  'leave',
  'payroll',
  'holidays',
  'looks',
  'kiosk',
  'news',
  'rewards',
  'telegram',
  'website',
};

class AttendancePage extends ConsumerStatefulWidget {
  final String id, title, tab;
  const AttendancePage({super.key, required this.id, this.title = '', this.tab = ''});
  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  Json? _data;
  String _error = '';
  String? _tab;

  String get _base => '${Api.user}/businesses/${widget.id}/attendance';
  String get _current => _tab ?? (_tabs.containsKey(widget.tab) ? widget.tab : 'today');

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
      if (mounted) setState(() => _error = e.network ? ref.read(tProvider)('app.offline') : (e.message.isNotEmpty ? e.message : ref.read(tProvider)('att.loadFail')));
    }
  }

  AtCtx _ctx() => AtCtx(
    id: widget.id,
    api: ref.read(apiProvider),
    t: ref.read(tProvider),
    data: _data!,
    reload: _reload,
    askBuy: _buy,
    go: (tab) => setState(() => _tab = tab),
    notify: (text) => toast(context, text),
  );

  // "renew" · "att_branch" / "att_staff" (a slot; item = renew that one) · a yearly add-on
  Future<void> _buy(String key, {String? item, VoidCallback? onDone}) async {
    final t = ref.read(tProvider);
    String a(String k, [Map<String, Object?> v = const {}]) => t('att.$k', v);
    final data = _data!;
    final business = obj(data['business']);
    final lic = obj(data['license']);
    final renew = key == 'renew' || key == 'attendance';
    final branch = key == 'att_branch';
    final staff = key == 'att_staff';
    final current = renew
        ? lic
        : branch
        ? objs(data['slots']).where((s) => s['item'] == item).firstOrNull
        : staff
        ? objs(data['staff_slots']).where((s) => s['item'] == item).firstOrNull
        : obj(obj(data['addons'])[key]);
    final price = renew
        ? n(data['renew_price'])
        : branch
        ? n(data['slot_price'])
        : n(obj(obj(data['addons'])[key])['price']);
    final name = renew
        ? a('renewTitle')
        : branch
        ? a('buyBranchTitle')
        : t.or('atai.names.$key', key);
    final api = ref.read(apiProvider);
    Future<Json> buy() {
      if (renew) return api.post('${Api.user}/businesses/${widget.id}/licenses/attendance', {'expect': lic['expires_at']});
      if (branch || staff) {
        return api.post('$_base/slots', {'kind': staff ? 'staff' : 'branch', 'item': ?item, if (item != null) 'expect': current?['expires_at']});
      }
      return api.post('${Api.user}/businesses/${widget.id}/licenses/$key', {'expect': current?['expires_at']});
    }

    final tabBefore = _current;
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
              Icon(renew ? LucideIcons.calendarClock : (atAddonIcons[key] ?? LucideIcons.puzzle), size: 54, color: const Color(0xFF5B3A00)),
              const SizedBox(height: 8),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF3A2500)),
              ),
              Text(
                str(business['name']),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: const Color(0xFF3A2500).withValues(alpha: .7)),
              ),
            ],
          ),
        ),
        badge: renew ? a('renew') : a('tabs.addons'),
        title: renew || branch ? name : a('unlockTitle', {'name': name}),
        sub: renew
            ? a('renewSub')
            : branch
            ? a('buyBranchWhat')
            : t.or('atai.what.$key', ''),
        perks: renew ? <String>[] : [...t.list('atai.perks.$key'), '${fmt(price)} ${a('coins')} ${a('perYear')}'],
        price: price,
        buyLabel: '${renew || current?['active'] == true ? a('renew') : a('add')} · ${fmt(price)} ${a('coins')}',
        doneTitle: name,
        doneSub: renew
            ? ''
            : branch
            ? a('branchBought')
            : a('unlockDone', {'name': name}),
        doneSubOf: renew ? (res) => a('renewDone', {'date': fmtDate(obj(res['data'])['expires_at'], lang: t.lang)}) : null,
        doneButton: t('app.continue'),
        buy: buy,
        onDone: (_) async {
          onDone?.call();
          await _reload();
          // just unlocked → open its page
          final to = atAddonTab[key];
          if (!renew && to != null && to != tabBefore && mounted) setState(() => _tab = to);
        },
      ),
    );
    if (mounted) setState(() {});
  }

  int get _pending {
    final c = obj(_data?['counts']);
    return (n(c['pending']) + n(c['fix_pending']) + n(c['ot_pending'])).toInt();
  }

  void _openSections() {
    final t = ref.read(tProvider);
    final c = context.c;
    final data = _data!;
    final setup = obj(data['setup']);
    final steps = obj(setup['steps']);
    final setupOpen = n(setup['done']) < n(setup['total']);
    final leave = n(obj(data['counts'])['leave_pending']).toInt();
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
              child: Text(t('att.allSections'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ),
            for (final (group, keys) in _groups) ...[
              if (group != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                  child: Text(
                    t('att.navGroups.$group'),
                    style: TextStyle(color: c.muted, fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                )
              else
                const SizedBox(height: 12),
              for (final key in keys)
                _NavRow(
                  icon: _tabs[key]!,
                  label: t('att.tabs.$key'),
                  on: key == _current,
                  dot: setupOpen && _stepOf[key] != null ? (steps[_stepOf[key]] == true ? 1 : 2) : 0,
                  badge: key == 'review'
                      ? _pending
                      : key == 'leave'
                      ? leave
                      : 0,
                  locked: _needs[key] != null && obj(obj(data['addons'])[_needs[key]])['active'] != true,
                  soon: !_native.contains(key),
                  soonLabel: t('rest.soonShort'),
                  onTap: () {
                    Navigator.pop(sheet);
                    setState(() => _tab = key);
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
    String a(String k, [Map<String, Object?> v = const {}]) => t('att.$k', v);

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
                  child: _error.isNotEmpty ? LoadError(text: _error, retry: a('retry'), onRetry: _reload) : const SkelList(rows: 6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final ctx = _ctx();
    final lic = ctx.license;
    final tab = _current;
    final business = ctx.business;
    final setup = ctx.setup;
    final graceLeft = lic['grace_until'] == null ? 0 : ((DateTime.tryParse(str(lic['grace_until']))?.difference(DateTime.now()).inHours ?? 0) / 24).ceil().clamp(0, 999);

    final Widget section = switch (tab) {
      'today' => TodayTab(key: const ValueKey('today'), ctx: ctx),
      'review' => ReviewTab(key: const ValueKey('review'), ctx: ctx),
      'report' => ReportTab(key: const ValueKey('report'), ctx: ctx),
      'staff' => StaffTab(key: const ValueKey('staff'), ctx: ctx),
      'branches' => BranchesTab(key: const ValueKey('branches'), ctx: ctx),
      'shifts' => ShiftsTab(key: const ValueKey('shifts'), ctx: ctx),
      'settings' => SettingsTab(key: ValueKey('settings${ctx.data['code']}${ctx.rules}'), ctx: ctx),
      'addons' => AddonsTab(key: const ValueKey('addons'), ctx: ctx),
      'roster' => RosterTab(key: ValueKey('roster${ctx.addonOn('att_roster')}'), ctx: ctx),
      'leave' => LeaveTab(key: ValueKey('leave${ctx.addonOn('att_leave')}'), ctx: ctx),
      'payroll' => PayrollTab(key: ValueKey('payroll${ctx.addonOn('att_payroll')}${ctx.addonOn('att_khpay')}'), ctx: ctx),
      'holidays' => HolidaysTab(key: const ValueKey('holidays'), ctx: ctx),
      'looks' => LooksTab(key: ValueKey('looks${ctx.business['logo_url']}'), ctx: ctx),
      'news' => NewsTab(key: ValueKey('news${ctx.addonOn('att_news')}'), ctx: ctx),
      'rewards' => RewardsTab(key: ValueKey('rewards${ctx.addonOn('att_rewards')}'), ctx: ctx),
      'telegram' => TelegramTab(key: ValueKey('telegram${ctx.addonOn('att_telegram')}'), ctx: ctx),
      'website' => WebsiteTab(key: ValueKey('website${ctx.addonOn('att_website')}'), ctx: ctx),
      'kiosk' => KioskTab(key: ValueKey('kiosk${ctx.addonOn('att_kiosk')}'), ctx: ctx),
      _ => _Soon(ctx: ctx, tab: tab),
    };

    return Scaffold(
      backgroundColor: c.appBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _top(context, str(business['name']).isNotEmpty ? str(business['name']) : widget.title, str(business['logo_url'])),
            // chips: type · ends on · staff/branches · setup steps
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Chip2(a('type')),
                    if (lic['expires_at'] != null) ...[
                      const SizedBox(width: 6),
                      Chip2(
                        a('endsOn', {'date': mDate(lic['expires_at'], t.lang)}),
                        icon: LucideIcons.calendarClock,
                        tone: lic['locked'] == true || lic['status'] == 'expired'
                            ? Tone.danger
                            : lic['status'] == 'expiring'
                            ? Tone.warn
                            : Tone.muted,
                      ),
                    ],
                    const SizedBox(width: 6),
                    Chip2(
                      a('planLine', {'staff': '${n(ctx.counts['staff'])}/${n(ctx.limits['staff'])}', 'branches': '${n(ctx.counts['branches'])}/${n(ctx.limits['branches'])}'}),
                      icon: LucideIcons.users,
                    ),
                    if (n(setup['done']) < n(setup['total'])) ...[
                      const SizedBox(width: 6),
                      Chip2(a('stepsDone', {'done': n(setup['done']), 'total': n(setup['total'])}), icon: LucideIcons.circleCheck, tone: Tone.brand),
                    ],
                  ],
                ),
              ),
            ),
            if (business['status'] == false) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Alert(a('suspended'))),
            if (lic['in_grace'] == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Alert('${a('graceTitle')} ${a('graceSub', {'n': graceLeft})}', tone: Tone.warn),
              ),
            if (lic['locked'] == true) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Alert('${a('lockedTitle')} ${a('lockedSub')}')),
            if (lic['status'] == 'expiring' || lic['in_grace'] == true || lic['locked'] == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Btn(a('renewFor', {'coins': fmt(n(_data!['renew_price']))}), lead: const CoinIcon(size: 16), expand: true, onTap: business['status'] == false ? null : () => _buy('renew')),
              ),
            // the section you are on + "All sections"
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
                          child: Text(a('tabs.$tab'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                        if (_pending > 0 && tab != 'review') ...[_Badge(_pending), const SizedBox(width: 8)],
                        Text(
                          a('allSections'),
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
              child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.fingerprint, size: 22, color: c.brand),
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

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label, soonLabel;
  final bool on, soon, locked;
  final int dot; // 0 none · 1 done · 2 to do
  final int badge;
  final VoidCallback onTap;
  const _NavRow({
    required this.icon,
    required this.label,
    required this.on,
    required this.dot,
    required this.badge,
    required this.locked,
    required this.soon,
    required this.soonLabel,
    required this.onTap,
  });
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
              if (dot > 0)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dot == 1 ? c.good : c.brand, shape: BoxShape.circle),
                ),
              if (badge > 0) ...[const SizedBox(width: 6), _Badge(badge)],
              if (locked) ...[const SizedBox(width: 6), Icon(LucideIcons.lock, size: 13, color: c.muted)],
              if (soon) ...[const SizedBox(width: 8), Chip2(soonLabel)],
            ],
          ),
        ),
      ),
    );
  }
}

// sections not rebuilt yet: say so, offer the website in the browser
class _Soon extends StatelessWidget {
  final AtCtx ctx;
  final String tab;
  const _Soon({required this.ctx, required this.tab});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Panel(
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: c.active, shape: BoxShape.circle),
                child: Icon(_tabs[tab], size: 28, color: c.brand),
              ),
              const SizedBox(height: 14),
              Text(ctx.a('tabs.$tab'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                ctx.t(playBilling ? 'app.restSoonPlay' : 'app.restSoon'), // Google Play build: no pointing to the website (it has buy buttons)
                textAlign: TextAlign.center,
                style: TextStyle(color: c.muted, height: 1.5),
              ),
              const SizedBox(height: 16),
              if (!playBilling)
                Btn(
                  ctx.t('app.openWeb'),
                  icon: LucideIcons.externalLink,
                  kind: BtnKind.ghost,
                  onTap: () => launchUrl(Uri.parse('${Config.siteUrl}/app/business/${ctx.id}?tab=$tab'), mode: LaunchMode.externalApplication),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
