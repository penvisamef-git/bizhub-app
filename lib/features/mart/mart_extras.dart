import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../restaurant/rest_common.dart' show Segmented, SwitchRow, gap14;
import 'mart_common.dart';
import 'mart_kit.dart';
import 'mart_receipt.dart';

// Telegram alerts (mart_telegram), Add-ons, Printing + receipt templates — MartTelegram.jsx and MartExtras.jsx.

const _flags = ['new_order', 'shift_close', 'low_stock', 'new_message'];

class TelegramTab extends StatefulWidget {
  final MartCtx ctx;
  const TelegramTab({super.key, required this.ctx});
  @override
  State<TelegramTab> createState() => _TelegramTabState();
}

class _TelegramTabState extends State<TelegramTab> {
  Json? _status, _form, _link;
  String _busy = '';
  bool _slow = false;
  Timer? _timer;
  MartCtx get ctx => widget.ctx;
  bool get _on => ctx.addonOn('mart_telegram');

  @override
  void initState() {
    super.initState();
    if (_on) _load(reset: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<Json?> _load({bool reset = false}) async {
    try {
      final r = await ctx.api.get('${ctx.base}/telegram');
      final s = obj(r['data']);
      if (!mounted) return s;
      setState(() {
        _status = s;
        if (reset || _form == null) _form = {for (final k in _flags) k: s[k] == true, 'daily': s['daily'] == true, 'report_time': str(s['report_time']).isEmpty ? '21:00' : s['report_time']};
      });
      return s;
    } catch (e) {
      if (reset) ctx.fail(e);
      return null;
    }
  }

  Future<void> _run(String key, Future<Json> Function() fn, String? ok) async {
    setState(() => _busy = key);
    try {
      final r = await fn();
      if (r['data'] is Map && obj(r['data']).containsKey('connected')) setState(() => _status = obj(r['data']));
      if (ok != null) ctx.notify(ok);
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Future<void> _connect() async {
    setState(() => _busy = 'link');
    try {
      final r = await ctx.api.post('${ctx.base}/telegram/link');
      final link = obj(r['data']);
      setState(() {
        _link = link;
        _slow = false;
      });
      final started = DateTime.now();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 2500), (t) async {
        final ends = DateTime.tryParse(str(link['expires_at']));
        if (ends != null && DateTime.now().isAfter(ends)) {
          t.cancel();
          if (mounted) setState(() => _link = null);
          return;
        }
        if (DateTime.now().difference(started).inSeconds > 45 && mounted && !_slow) setState(() => _slow = true);
        final s = await _load();
        if (s?['connected'] == true) {
          t.cancel();
          if (mounted) setState(() => _link = null);
          ctx.notify(ctx.w('tgConnectedTo', {'name': s!['chat_name']}));
        }
      });
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  void _open(Object? url) => launchUrl(Uri.parse(str(url)), mode: LaunchMode.externalApplication);

  Widget _sample(BuildContext context) {
    final name = str(ctx.business['name']);
    Widget bubble(List<String> lines, String time) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lines.first,
            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1F2430)),
          ),
          for (final l in lines.skip(1)) Text(l, style: const TextStyle(fontSize: 13, color: Color(0xFF1F2430))),
          Align(
            alignment: Alignment.centerRight,
            child: Text(time, style: const TextStyle(fontSize: 11, color: Color(0xFF8A94A6))),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFD5E6F4), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 15,
                backgroundColor: Color(0xFF2AABEE),
                child: Text(
                  'B',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'BizHub',
                style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1F2430)),
              ),
              const SizedBox(width: 6),
              Text('bot', style: TextStyle(color: const Color(0xFF1F2430).withValues(alpha: .5), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          bubble(['🛍 ${ctx.w('tgSampleOrder')}', '🛒 $name', '👤 Sophea · 012 888 777', '• 2× Coca-Cola — \$1.20', '💰 \$4.10 · 🚚 St 432'], '14:32'),
          bubble(['⚠️ ${ctx.w('tgSampleLow')}', '🛒 $name', '🟠 Oil 1L — 3 left', '⛔️ Eggs (10) — 0 left'], '16:05'),
          bubble(['🔒 ${ctx.w('tgSampleShift')}', '🧾 \$245.50 (61)', '💵 \$120 + 84,000៛', '✅ ${ctx.w('tgExact')}'], '21:10'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a = ctx.addon('mart_telegram');
    final price = fmt(n(a['price'] ?? 90));
    final hero = Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MHead(ctx.w('tgTitle'), icon: LucideIcons.send, sub: _on ? ctx.w('tgOn', {'date': mDate(a['expires_at'], ctx.lang)}) : ctx.w('tgOff', {'price': price})),
          if (!_on || a['status'] == 'expiring')
            Align(
              alignment: Alignment.centerLeft,
              child: GoldBtn(_on ? ctx.w('renew') : ctx.w('unlockYear', {'coins': price}), onTap: ctx.readOnly ? null : () => ctx.askBuy('mart_telegram')),
            ),
        ],
      ),
    );
    if (!_on) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          hero,
          mGap,
          mCard(context, ctx.w('tgTitle'), sub: ctx.w('tgSub'), [
            for (final p in ctx.t.list('mw.tgPerks'))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.check, size: 15, color: c.good),
                    const SizedBox(width: 8),
                    Expanded(child: Text(p)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            _sample(context),
          ]),
        ],
      );
    }
    final s = _status, f = _form;
    if (s == null || f == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 5));
    final dirty = [..._flags, 'daily', 'report_time'].any((k) => '${f[k]}' != '${k == 'report_time' ? (str(s[k]).isEmpty ? '21:00' : s[k]) : s[k] == true}');
    final link = _link;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        hero,
        mGap,
        if (s['configured'] == false) ...[Alert(ctx.w('tgNotConfigured'), tone: Tone.warn), mGap],
        if (s['connected'] == true)
          Panel(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.circleCheck, size: 26, color: c.good),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Muted(ctx.w('tgConnected')),
                          Row(
                            children: [
                              if (s['chat_type'] != 'private') ...[Icon(LucideIcons.users, size: 15, color: c.ink), const SizedBox(width: 4)],
                              Flexible(
                                child: Text(str(s['chat_name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              ),
                            ],
                          ),
                          Text(ctx.w('since', {'date': mDate(s['connected_at'], ctx.lang)}), style: TextStyle(color: c.muted, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Btn(
                      ctx.w('tgTest'),
                      icon: LucideIcons.bellRing,
                      kind: BtnKind.ghost,
                      small: true,
                      busy: _busy == 'test',
                      onTap: ctx.readOnly || _busy.isNotEmpty ? null : () => _run('test', () => ctx.api.post('${ctx.base}/telegram/test'), ctx.w('tgTestSent')),
                    ),
                    Btn(
                      ctx.w('tgDisconnect'),
                      icon: LucideIcons.unplug,
                      kind: BtnKind.ghost,
                      small: true,
                      busy: _busy == 'off',
                      onTap: ctx.readOnly || _busy.isNotEmpty ? null : () => _run('off', () => ctx.api.delete('${ctx.base}/telegram'), ctx.w('tgOffDone')),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          mCard(context, ctx.w('tgConnectTitle'), [
            for (final (i, step) in ctx.t.list('mw.tgSteps').indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: c.active,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: c.brandInk),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(step)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            if (link != null) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.line),
                  ),
                  child: QrImageView(data: str(link['url']), size: 170, padding: EdgeInsets.zero),
                ),
              ),
              gap14,
              Btn(ctx.w('tgOpen'), icon: LucideIcons.send, expand: true, onTap: () => _open(link['url'])),
              const SizedBox(height: 8),
              Btn(ctx.w('tgGroup'), icon: LucideIcons.users, kind: BtnKind.ghost, expand: true, onTap: () => _open(link['group_url'])),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Flexible(child: Muted(ctx.w('tgWaiting'))),
                ],
              ),
              if (_slow) ...[const SizedBox(height: 6), Muted(ctx.w('tgSlow'), align: TextAlign.center)],
            ] else
              Btn(ctx.w('tgConnect'), icon: LucideIcons.send, expand: true, busy: _busy == 'link', onTap: ctx.readOnly || _busy == 'link' || s['configured'] == false ? null : _connect),
          ]),
        mGap,
        mCard(context, ctx.w('tgAlerts'), sub: ctx.w('tgAlertsSub'), [
          for (final k in _flags)
            () {
              final l = ctx.t.list('mw.tgFlag.$k');
              return SwitchRow(title: l.isNotEmpty ? l[0] : k, sub: l.length > 1 ? l[1] : null, value: f[k] == true, onChanged: ctx.readOnly ? null : (v) => setState(() => f[k] = v));
            }(),
          SwitchRow(title: ctx.x('tgDaily'), sub: ctx.x('tgDailySub'), value: f['daily'] == true, onChanged: ctx.readOnly ? null : (v) => setState(() => f['daily'] = v)),
          if (f['daily'] == true) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: Muted(ctx.x('tgDailyAt'))),
                Btn(
                  str(f['report_time']),
                  icon: LucideIcons.clock,
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: ctx.readOnly
                      ? null
                      : () async {
                          final p = str(f['report_time']).split(':');
                          final t = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(hour: int.tryParse(p.first) ?? 21, minute: int.tryParse(p.last) ?? 0),
                          );
                          if (t != null) setState(() => f['report_time'] = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
                        },
                ),
              ],
            ),
            if (s['connected'] == true) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Btn(
                  ctx.x('tgDailyNow'),
                  icon: LucideIcons.send,
                  kind: BtnKind.ghost,
                  small: true,
                  busy: _busy == 'daily',
                  onTap: ctx.readOnly || _busy.isNotEmpty ? null : () => _run('daily', () => ctx.api.post('${ctx.base}/telegram/daily'), ctx.w('tgTestSent')),
                ),
              ),
            ],
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Btn(
              _busy == 'save' ? ctx.w('saving') : ctx.w('save'),
              small: true,
              busy: _busy == 'save',
              onTap: ctx.readOnly || _busy == 'save' || !dirty ? null : () => _run('save', () => ctx.api.put('${ctx.base}/telegram', f), ctx.w('saved')).then((_) => _load(reset: true)),
            ),
          ),
        ]),
        mGap,
        mCard(context, ctx.w('preview'), [_sample(context)]),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------- Add-ons
const martAddonIcons = <String, IconData>{
  'mart_staff': LucideIcons.users,
  'mart_payments': LucideIcons.creditCard,
  'mart_stock': LucideIcons.package,
  'mart_printer': LucideIcons.printer,
  'mart_history': LucideIcons.history,
  'mart_debt': LucideIcons.handCoins,
  'mart_shifts': LucideIcons.vault,
  'mart_labels': LucideIcons.barcode,
  'mart_suppliers': LucideIcons.truck,
  'mart_website': LucideIcons.globe,
  'mart_shop': LucideIcons.shoppingBag,
  'mart_telegram': LucideIcons.send,
  'mart_expiry': LucideIcons.calendarX,
  'mart_loyalty': LucideIcons.gift,
  'mart_promos': LucideIcons.badgePercent,
  'mart_profit': LucideIcons.trendingUp,
  'mart_purchase': LucideIcons.clipboardCheck,
  'mart_display': LucideIcons.monitor,
  'mart_scale': LucideIcons.scale,
  'mart_delivery': LucideIcons.mapPinned,
  'mart_branches': LucideIcons.network,
};
const martYearly = {
  'mart_staff',
  'mart_stock',
  'mart_history',
  'mart_debt',
  'mart_website',
  'mart_shop',
  'mart_telegram',
  'mart_expiry',
  'mart_loyalty',
  'mart_promos',
  'mart_profit',
  'mart_delivery',
  'mart_branches',
};

class AddonsTab extends StatefulWidget {
  final MartCtx ctx;
  const AddonsTab({super.key, required this.ctx});
  @override
  State<AddonsTab> createState() => _AddonsTabState();
}

class _AddonsTabState extends State<AddonsTab> {
  final _q = TextEditingController();
  String _show = 'all';
  MartCtx get ctx => widget.ctx;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = _q.text.trim().toLowerCase();
    bool match(String k) {
      if (t.isEmpty) return true;
      final hay = [ctx.m('addonInfo.$k.name'), ctx.m('addonInfo.$k.what'), ctx.t.other('km', 'mart.addonInfo.$k.name'), ctx.t.other('en', 'mart.addonInfo.$k.name')].join(' ').toLowerCase();
      return hay.contains(t);
    }

    final keys = martAddonIcons.keys.where((k) => match(k) && (_show == 'all' || (_show == 'on') == ctx.addonOn(k))).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Panel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MHead(ctx.m('tabs.addons'), icon: LucideIcons.puzzle, sub: ctx.m('addonsSub')),
              Field(controller: _q, hint: ctx.t('addfind.search'), icon: LucideIcons.search, onChanged: (_) => setState(() {})),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Segmented<String>(
                  value: _show,
                  options: [('all', ctx.t('addfind.all')), ('on', ctx.t('addfind.mine')), ('off', ctx.t('addfind.notMine'))],
                  onChanged: (v) => setState(() => _show = v),
                ),
              ),
            ],
          ),
        ),
        mGap,
        if (keys.isEmpty) Panel(child: Muted(t.isEmpty ? ctx.t('addfind.noneFilter') : ctx.t('addfind.none', {'q': _q.text.trim()}), align: TextAlign.center)),
        for (final k in keys)
          () {
            final a = ctx.addon(k);
            final on = a['active'] == true;
            final renew = on && martYearly.contains(k) && a['status'] == 'expiring';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MHead(ctx.m('addonInfo.$k.name'), icon: martAddonIcons[k], sub: ctx.m('addonInfo.$k.what')),
                    for (final p in [...ctx.t.list('mart.addonInfo.$k.perks'), '${fmt(n(a['price']))} ${ctx.m('coins')} · ${martYearly.contains(k) ? ctx.m('perYear') : ctx.m('forever')}'])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(LucideIcons.check, size: 15, color: c.good),
                            const SizedBox(width: 8),
                            Expanded(child: Text(p, style: const TextStyle(fontSize: 13.5))),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: on && !renew
                          ? Chip2('${ctx.m('owned')}${a['expires_at'] != null ? ' · ${ctx.m('until', {'date': mDate(a['expires_at'], ctx.lang)})}' : ''}', icon: LucideIcons.check, tone: Tone.good)
                          : GoldBtn((renew ? ctx.m('renewAddon', {'coins': fmt(n(a['price']))}) : ctx.m('unlock', {'coins': fmt(n(a['price']))})), onTap: ctx.readOnly ? null : () => ctx.askBuy(k)),
                    ),
                  ],
                ),
              ),
            );
          }(),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------- Print
class PrintTab extends StatefulWidget {
  final MartCtx ctx;
  const PrintTab({super.key, required this.ctx});
  @override
  State<PrintTab> createState() => _PrintTabState();
}

class _PrintTabState extends State<PrintTab> {
  Json? _info;
  bool _busy = false;
  MartCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PrintTab old) {
    super.didUpdateWidget(old);
    if (!identical(old.ctx.data, ctx.data)) _load();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/print');
      if (mounted) setState(() => _info = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _save(Json body) async {
    setState(() => _busy = true);
    try {
      final r = await ctx.api.put('${ctx.base}/print', body);
      setState(() => _info = obj(r['data']));
      ctx.notify(ctx.m('saved'));
      ctx.reload();
    } on ApiError catch (e) {
      if (e.status == 402 && e.body['product'] != null) {
        ctx.askBuy(str(e.body['product']), item: e.body['item'] == null ? null : str(e.body['item']));
      } else {
        ctx.fail(e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final info = _info;
    if (info == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 5));
    final owned = (info['owned'] as List? ?? const []).map((e) => '$e').toSet();
    final current = str(info['current']);
    Widget receipt(String k) => MartReceipt(sale: martSampleSale, shop: ctx.shop, m: (x) => ctx.m(x), methodName: ctx.methodName, lang: ctx.lang, theme: k);
    String status(String k) => current == k ? ctx.m('inUse') : (k == 'classic' ? ctx.m('free') : (owned.contains(k) ? ctx.m('yours') : '${fmt(n(info['price']))} ${ctx.m('coins')}'));
    void open(String k) => openLookSheet(
      context,
      title: ctx.m('templates'),
      keys: [for (final t in martThemes) t.key],
      start: k,
      current: current,
      owned: owned.contains,
      name: (x) => martThemeOf(x).name(ctx.lang),
      big: (x) => Container(
        width: 320,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: c.cardShadow),
        child: receipt(x),
      ),
      status: status,
      useLabel: ctx.m('use'),
      buyLabel: (_) => ctx.m('unlock', {'coins': '${fmt(n(info['price']))} ${ctx.m('coins')}'}),
      readOnly: ctx.readOnly || _busy,
      use: (x) async {
        await _save({'theme': x});
        return true;
      },
      buy: (x) => ctx.askBuy('mart_print_theme', item: x, onDone: _load),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        mCard(context, ctx.m('tabs.print'), sub: ctx.m('printSub'), [
          if (info['on'] != true)
            LockNote(
              text: ctx.m('printLocked'),
              button: '${ctx.m('unlock', {'coins': fmt(n(info['addon_price']))})} · ${ctx.m('forever')}',
              onTap: ctx.readOnly ? null : () => ctx.askBuy('mart_printer'),
            )
          else ...[
            Text(ctx.m('paper'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Segmented<String>(value: str(info['size']), options: const [('80', '80 mm'), ('58', '58 mm')], onChanged: ctx.readOnly || _busy ? null : (v) => _save({'size': v})),
            const SizedBox(height: 8),
            SwitchRow(title: ctx.m('autoPrint'), value: info['auto'] == true, onChanged: ctx.readOnly || _busy ? null : (v) => _save({'auto': v})),
            const SizedBox(height: 6),
            Muted(ctx.t('app.printShare')),
          ],
        ]),
        mGap,
        mCard(context, ctx.m('templates'), sub: ctx.m('templatesSub', {'coins': n(info['price'])}), [
          LayoutBuilder(
            builder: (_, box) {
              final cols = box.maxWidth > 520 ? 3 : 2;
              final w = (box.maxWidth - 10 * (cols - 1)) / cols;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final t in martThemes)
                    SizedBox(
                      width: w,
                      child: MLookCard(
                        picture: Container(
                          height: 210,
                          color: c.bg2,
                          padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                          child: ClipRect(
                            child: OverflowBox(
                              alignment: Alignment.topCenter,
                              maxHeight: double.infinity,
                              child: FittedBox(
                                fit: BoxFit.fitWidth,
                                alignment: Alignment.topCenter,
                                child: SizedBox(width: 300, child: receipt(t.key)),
                              ),
                            ),
                          ),
                        ),
                        name: t.name(ctx.lang),
                        on: current == t.key,
                        locked: !owned.contains(t.key),
                        status: status(t.key),
                        onTap: () => open(t.key),
                      ),
                    ),
                ],
              );
            },
          ),
        ]),
      ],
    );
  }
}
