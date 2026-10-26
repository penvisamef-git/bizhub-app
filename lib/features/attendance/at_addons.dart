import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show mDate, mGap, GoldBtn;
import 'at_common.dart';

// Add-ons — AddonsTab.jsx + addon-info.js (same items, same words)
const atYearly = [
  'att_news',
  'att_rewards',
  'att_gps_guard',
  'att_manager',
  'att_docs',
  'att_khpay',
  'att_roster',
  'att_website',
  'att_telegram',
  'att_leave',
  'att_selfie',
  'att_kiosk',
  'att_payroll',
];
const atAddonTab = {
  'att_telegram': 'telegram',
  'att_leave': 'leave',
  'att_selfie': 'settings',
  'att_kiosk': 'kiosk',
  'att_payroll': 'payroll',
  'att_staff': 'staff',
  'att_branch': 'branches',
  'att_app_theme': 'looks',
  'att_qr_theme': 'looks',
  'att_kiosk_theme': 'kiosk',
  'att_website': 'website',
  'att_web_theme': 'website',
  'att_holidays': 'holidays',
  'att_roster': 'roster',
  'att_khpay': 'payroll',
  'att_manager': 'staff',
  'att_docs': 'staff',
  'att_news': 'news',
  'att_rewards': 'rewards',
  'att_gps_guard': 'settings',
};
const atAddonIcons = <String, IconData>{
  'att_branch': LucideIcons.mapPin,
  'att_staff': LucideIcons.users,
  'att_app_theme': LucideIcons.smartphone,
  'att_qr_theme': LucideIcons.qrCode,
  'att_kiosk_theme': LucideIcons.scanLine,
  'att_telegram': LucideIcons.send,
  'att_leave': LucideIcons.fileText,
  'att_selfie': LucideIcons.camera,
  'att_kiosk': LucideIcons.scanLine,
  'att_payroll': LucideIcons.coins,
  'att_app': LucideIcons.tabletSmartphone,
  'att_website': LucideIcons.globe,
  'att_web_theme': LucideIcons.layoutTemplate,
  'att_holidays': LucideIcons.calendarHeart,
  'att_roster': LucideIcons.calendarRange,
  'att_khpay': LucideIcons.landmark,
  'att_manager': LucideIcons.userCog,
  'att_docs': LucideIcons.folderLock,
  'att_news': LucideIcons.megaphone,
  'att_rewards': LucideIcons.award,
  'att_gps_guard': LucideIcons.shieldCheck,
};

class AddonsTab extends StatefulWidget {
  final AtCtx ctx;
  const AddonsTab({super.key, required this.ctx});
  @override
  State<AddonsTab> createState() => _AddonsTabState();
}

class _Item {
  final String key, kind; // yearly · slot · look · year · soon
  final num price;
  final Json st;
  final bool mine, yearly;
  final int count, max;
  final String next;
  final List<String> years;
  const _Item(this.key, this.kind, this.price, {this.st = const {}, this.mine = false, this.yearly = false, this.count = 0, this.max = 0, this.next = '', this.years = const []});
}

class _AddonsTabState extends State<AddonsTab> {
  AtCtx get ctx => widget.ctx;
  Json? _looks;
  String _q = '', _show = 'all';
  final _search = TextEditingController();
  String x(String k, [Map<String, Object?> v = const {}]) => ctx.t('atad.$k', v);

  @override
  void initState() {
    super.initState();
    ctx.api.get('${ctx.base}/looks').then((r) {
      if (mounted) setState(() => _looks = obj(r['data']));
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_Item> get _items {
    final d = ctx.data;
    (int, String) slots(Object? list) {
      final act = objs(list).where((s) => s['active'] == true).toList();
      final ends = act.map((s) => str(s['expires_at'])).toList()..sort();
      return (act.length, ends.isEmpty ? '' : ends.first);
    }

    int paid(String k) => (obj(_looks?[k])['owned'] as List? ?? const []).length;
    int maxOf(String k, int fb) => _looks == null ? fb : (obj(_looks![k])['list'] as List? ?? const []).length - 1;
    num lookPrice(String k, num fb) => _looks == null ? fb : n(obj(_looks![k])['price'] ?? fb);
    final (sc, sn) = slots(d['staff_slots']);
    final (bc, bn) = slots(d['slots']);
    final web = ctx.addon('att_web_theme');
    final hol = ctx.addon('att_holidays');
    final years = (hol['years'] as List? ?? const []).map((e) => '$e').toList();
    return [
      for (final k in atYearly) _Item(k, 'yearly', n(ctx.addon(k)['price']), st: ctx.addon(k), mine: ctx.addonOn(k)),
      _Item('att_staff', 'slot', n(ctx.addon('att_staff')['price']), count: sc, next: sn, mine: sc > 0),
      _Item('att_branch', 'slot', n(d['slot_price']), count: bc, next: bn, mine: bc > 0),
      _Item('att_app_theme', 'look', lookPrice('app', 55), count: paid('app'), max: maxOf('app', 11), mine: paid('app') > 0),
      _Item('att_qr_theme', 'look', lookPrice('qr', 35), count: paid('qr'), max: maxOf('qr', 11), mine: paid('qr') > 0),
      _Item('att_kiosk_theme', 'look', lookPrice('kiosk', 85), yearly: true, count: paid('kiosk'), max: maxOf('kiosk', 22), mine: paid('kiosk') > 0),
      _Item('att_web_theme', 'look', n(web['price'] ?? 35), count: n(web['owned']).toInt(), max: web['max'] == null ? 23 : n(web['max']).toInt(), mine: n(web['owned']) > 0),
      _Item('att_holidays', 'year', n(hol['price'] ?? 45), years: years, mine: years.isNotEmpty),
      _Item('att_app', 'soon', n(ctx.addon('att_app')['price'] ?? 150)),
    ];
  }

  String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final other = T.of(ctx.lang == 'km' ? 'en' : 'km');
    final counts = {'all': items.length, 'mine': items.where((i) => i.mine).length, 'notMine': items.where((i) => !i.mine).length};
    final words = _norm(_q).split(' ').where((w) => w.isNotEmpty).toList();
    final list = items.where((i) {
      if (_show == 'mine' && !i.mine) return false;
      if (_show == 'notMine' && i.mine) return false;
      if (words.isEmpty) return true;
      final hay = _norm([ctx.t('atai.names.${i.key}'), ctx.t.maybe('atai.what.${i.key}') ?? '', other('atai.names.${i.key}'), other.maybe('atai.what.${i.key}') ?? ''].join(' '));
      return words.every(hay.contains);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        atPanel([
          Text(x('title'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Muted(x('sub')),
          const SizedBox(height: 12),
          Field(controller: _search, hint: x('search'), prefix: const Icon(LucideIcons.search, size: 16), onChanged: (v) => setState(() => _q = v)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: [
              for (final k in ['all', 'mine', 'notMine']) ChoiceChip(label: Text('${x(k)} ${counts[k]}'), selected: _show == k, onSelected: (_) => setState(() => _show = k)),
            ],
          ),
        ]),
        mGap,
        if (list.isEmpty)
          atPanel([
            Muted(_q.isNotEmpty ? x('none', {'q': _q.trim()}) : x('noneFilter'), align: TextAlign.center),
            const SizedBox(height: 8),
            Center(
              child: Btn(
                x('clear'),
                kind: BtnKind.ghost,
                small: true,
                onTap: () => setState(() {
                  _q = '';
                  _search.clear();
                  _show = 'all';
                }),
              ),
            ),
          ]),
        for (final i in list) ...[_card(context, i), mGap],
      ],
    );
  }

  Widget _card(BuildContext context, _Item i) {
    final c = context.c;
    final status = i.kind == 'soon'
        ? 'soon'
        : i.kind == 'yearly'
        ? (str(i.st['status']).isEmpty ? 'none' : str(i.st['status']))
        : i.mine
        ? 'active'
        : 'none';
    final priceLine = i.kind == 'look'
        ? (i.yearly ? x('eachYear') : x('each'))
        : i.kind == 'year'
        ? x('perList')
        : i.key == 'att_staff'
        ? x('perPack')
        : x('perYear');
    final free = ctx.t.maybe('atai.free.${i.key}');
    final coins = fmt(i.price);
    final ro = ctx.readOnly;
    Widget open(String label) => Btn(label, icon: LucideIcons.chevronRight, kind: BtnKind.ghost, small: true, onTap: () => ctx.go(atAddonTab[i.key] ?? 'today'));
    final List<Widget> foot = switch (i.kind) {
      'yearly' => [
        if (status == 'active' || status == 'expiring')
          Chip2(x('activeUntil', {'date': mDate(i.st['expires_at'], ctx.lang)}), icon: LucideIcons.calendarClock, tone: status == 'active' ? Tone.good : Tone.warn),
        if (status == 'expired') Chip2(x('expired', {'date': mDate(i.st['expires_at'], ctx.lang)}), tone: Tone.danger),
        if (i.mine) open(x('open')),
        status == 'active'
            ? Btn(x('renew', {'coins': coins}), lead: const CoinIcon(size: 14), kind: BtnKind.ghost, small: true, onTap: ro ? null : () => ctx.askBuy(i.key))
            : GoldBtn((status == 'none' ? x('unlock', {'coins': coins}) : x('renew', {'coins': coins})), onTap: ro ? null : () => ctx.askBuy(i.key)),
      ],
      'slot' => [
        if (i.count > 0) Chip2(x('slots', {'n': i.count, 'date': mDate(i.next, ctx.lang)}), icon: LucideIcons.calendarClock, tone: Tone.good),
        GoldBtn(x('add', {'coins': coins}), onTap: ro ? null : () => ctx.askBuy(i.key)),
      ],
      'year' => [
        Chip2(i.years.isNotEmpty ? x('yearsOwned', {'list': i.years.join(', ')}) : x('thisYearFree'), icon: LucideIcons.calendarClock, tone: i.years.isNotEmpty ? Tone.good : Tone.muted),
        open(x('choose')),
      ],
      'look' => [
        Chip2(i.count > 0 ? x('owned', {'n': i.count, 'max': i.max}) : x('noneOwned'), icon: LucideIcons.palette, tone: i.count > 0 ? Tone.good : Tone.muted),
        open(x('choose')),
      ],
      _ => [Chip2(x('soon'), icon: LucideIcons.clock3)],
    };
    return Opacity(
      opacity: status == 'soon' ? .7 : 1,
      child: Panel(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: i.mine ? c.goodBg : c.active, borderRadius: BorderRadius.circular(14)),
                  child: Icon(atAddonIcons[i.key] ?? LucideIcons.puzzle, size: 22, color: i.mine ? c.good : c.brand),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ctx.t('atai.names.${i.key}'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const CoinIcon(size: 13),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '$coins $priceLine',
                              style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(ctx.t.maybe('atai.what.${i.key}') ?? '', style: const TextStyle(height: 1.45)),
            if (free != null) ...[const SizedBox(height: 6), Muted(free)],
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: foot),
          ],
        ),
      ),
    );
  }
}

// "this page needs an add-on" with a buy button (AddonTabs.jsx Locked)
class AtLocked extends StatelessWidget {
  final AtCtx ctx;
  final String addon;
  const AtLocked({super.key, required this.ctx, required this.addon});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return atPanel([
      Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(20)),
          child: Icon(atAddonIcons[addon] ?? LucideIcons.puzzle, size: 30, color: c.brand),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        ctx.t('atai.names.$addon'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Muted(ctx.t.maybe('atai.what.$addon') ?? '', align: TextAlign.center),
      const SizedBox(height: 10),
      for (final p in ctx.t.list('atai.perks.$addon'))
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.check, size: 16, color: c.good),
              const SizedBox(width: 8),
              Expanded(child: Text(p)),
            ],
          ),
        ),
      const SizedBox(height: 8),
      Center(child: GoldBtn(ctx.t('atx.buy', {'coins': fmt(n(ctx.addon(addon)['price']))}), onTap: ctx.readOnly ? null : () => ctx.askBuy(addon))),
    ]);
  }
}
