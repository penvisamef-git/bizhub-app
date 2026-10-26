import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'rest_common.dart';

// Telegram (the web's TelegramTab.jsx) and Add-ons (AddonsTab.jsx).

extension on RestCtx {
  String tg(String key, [Map<String, Object?> vars = const {}]) => t('tg.$key', vars);
}

// ------------------------------------------------------------------------------------------- Telegram
class TelegramSection extends StatefulWidget {
  final RestCtx ctx;
  const TelegramSection({super.key, required this.ctx});
  @override
  State<TelegramSection> createState() => _TelegramSectionState();
}

class _TelegramSectionState extends State<TelegramSection> {
  Json? _status, _form, _link;
  String _busy = '';
  bool _slow = false;
  Timer? _timer;
  RestCtx get ctx => widget.ctx;
  bool get _on => ctx.addonOn('rest_telegram');
  static const _keys = ['daily_report', 'report_time', 'shift_open', 'shift_close', 'stock_alerts'];

  @override
  void initState() {
    super.initState();
    if (_on) {
      _load().then((_) {}, onError: (Object e) => ctx.fail(e));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<Json> _load() async {
    final r = await ctx.api.get('${ctx.base}/telegram');
    final d = obj(r['data']);
    if (mounted) {
      setState(() {
        _status = d;
        _form ??= {for (final k in _keys) k: d[k]};
      });
    }
    return d;
  }

  // a one-time link, then check every few seconds until the person pressed Start
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
      final expires = DateTime.tryParse(str(link['expires_at'])) ?? DateTime.now().add(const Duration(minutes: 15));
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 2500), (_) async {
        if (DateTime.now().isAfter(expires)) {
          _timer?.cancel();
          if (mounted) setState(() => _link = null);
          return;
        }
        if (DateTime.now().difference(started).inSeconds > 45 && mounted && !_slow) setState(() => _slow = true);
        final s = await _load().catchError((_) => <String, dynamic>{});
        if (s['connected'] == true) {
          _timer?.cancel();
          if (mounted) setState(() => _link = null);
          ctx.notify(ctx.tg('connectedTo', {'name': s['chat_name']}));
        }
      });
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Future<void> _run(String key, Future<Json> Function() fn, [String? ok]) async {
    setState(() => _busy = key);
    try {
      final r = await fn();
      if (r['data'] is Map && mounted) setState(() => _status = obj(r['data']));
      if (ok != null) ctx.notify(ok);
    } catch (e) {
      ctx.fail(e);
      if (e is ApiError && e.status == 410) _load();
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  void _open(Object? url) => launchUrl(Uri.parse(str(url)), mode: LaunchMode.externalApplication);

  // what the daily report looks like in Telegram
  Widget _sample() {
    final s = ctx.settings;
    final name = str(s['name_km']).isNotEmpty ? str(s['name_km']) : str(s['name_en']);
    const ink = Color(0xFF1B2A3A);
    TextStyle st([FontWeight w = FontWeight.w400]) => TextStyle(fontSize: 13, color: ink, fontWeight: w, height: 1.45);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFD4E5C4), Color(0xFFB9D3A6)]),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFF517DA2),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFFE0581A),
                  child: Text(
                    'B',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BizHub',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    Text('bot', style: TextStyle(color: Colors.white.withValues(alpha: .7), fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 50, 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📊 $name', style: st(FontWeight.w800)),
                  Text('${ctx.tg('sampleDate')} · ${ctx.tg('sampleTitle')}', style: st()),
                  const Divider(height: 14),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '💰 ${ctx.tg('sales')}: '),
                        TextSpan(text: '\$486.50', style: st(FontWeight.w800)),
                      ],
                    ),
                    style: st(),
                  ),
                  Text('🧾 ${ctx.tg('bills')}: 62', style: st()),
                  Text('💵 ${ctx.tg('cash')} \$301.00 · 🏦 ${ctx.tg('bank')} \$185.50', style: st()),
                  const Divider(height: 14),
                  Text('🔥 ${ctx.tg('top')}', style: st()),
                  Text('1. Beef noodle soup × 41', style: st()),
                  Text('2. Iced coffee × 33', style: st()),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('21:00', style: TextStyle(fontSize: 11, color: ink.withValues(alpha: .5))),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (!_on) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RestHead(ctx.r('addonNames.rest_telegram'), sub: ctx.tg('promo')),
                for (final k in ['p1', 'p2', 'p3'])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(LucideIcons.circleCheck, size: 17, color: c.good),
                        const SizedBox(width: 8),
                        Expanded(child: Text(ctx.tg(k), style: const TextStyle(height: 1.4))),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                _sample(),
              ],
            ),
          ),
          gap14,
          AddonPrompt(ctx: ctx, addonKey: 'rest_telegram'),
        ],
      );
    }
    final s = _status, f = _form;
    if (s == null || f == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 3));
    final ro = ctx.readOnly;
    final link = _link;
    final dirty = _keys.any((k) => f[k] != s[k]);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (s['configured'] != true) ...[Alert(ctx.tg('notConfigured'), tone: Tone.warn), gap14],
          if (s['connected'] == true)
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: c.goodBg, shape: BoxShape.circle),
                        child: Icon(LucideIcons.circleCheck, color: c.good, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ctx.tg('connectedLabel'), style: TextStyle(color: c.muted, fontSize: 12.5)),
                            Row(
                              children: [
                                if (s['chat_type'] != 'private') ...[Icon(LucideIcons.users, size: 15, color: c.ink), const SizedBox(width: 5)],
                                Flexible(
                                  child: Text(str(s['chat_name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                ),
                              ],
                            ),
                            Text(
                              ctx.tg('since', {'date': fmtDate(s['connected_at'], lang: ctx.lang)}),
                              style: TextStyle(color: c.muted, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Btn(
                        ctx.tg('sendTest'),
                        icon: LucideIcons.bellRing,
                        kind: BtnKind.ghost,
                        small: true,
                        busy: _busy == 'test',
                        onTap: ro || _busy.isNotEmpty ? null : () => _run('test', () => ctx.api.post('${ctx.base}/telegram/test'), ctx.tg('testSent')),
                      ),
                      Btn(
                        ctx.tg('disconnect'),
                        icon: LucideIcons.unplug,
                        kind: BtnKind.danger,
                        small: true,
                        busy: _busy == 'off',
                        onTap: ro || _busy.isNotEmpty ? null : () => _run('off', () => ctx.api.delete('${ctx.base}/telegram'), ctx.tg('disconnected')),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(ctx.tg('connectTitle'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  for (final (i, k) in ['step1', 'step2', 'step3'].indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: c.active, shape: BoxShape.circle),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(fontWeight: FontWeight.w800, color: c.brandInk, fontSize: 12.5),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(ctx.tg(k), style: const TextStyle(height: 1.4))),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (link == null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Btn(ctx.tg('connect'), icon: LucideIcons.send, busy: _busy == 'link', onTap: ro || _busy == 'link' || s['configured'] != true ? null : _connect),
                    )
                  else ...[
                    Btn(ctx.tg('openTelegram'), icon: LucideIcons.send, expand: true, onTap: () => _open(link['url'])),
                    const SizedBox(height: 8),
                    Btn(ctx.tg('addToGroup'), icon: LucideIcons.users, kind: BtnKind.ghost, expand: true, onTap: () => _open(link['group_url'])),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(ctx.tg('waiting'), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Muted(ctx.tg('groupHow')),
                    if (_slow) ...[const SizedBox(height: 8), Alert(ctx.tg('slow'), tone: Tone.warn)],
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: c.line),
                        ),
                        child: QrImageView(data: str(link['url']), size: 150, padding: EdgeInsets.zero),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Muted(ctx.tg('scanHint'), align: TextAlign.center),
                  ],
                ],
              ),
            ),
          gap14,
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RestHead(ctx.tg('reportTitle'), sub: ctx.tg('reportSub')),
                SwitchRow(title: ctx.tg('dailyReport'), value: f['daily_report'] == true, onChanged: ro ? null : (v) => setState(() => f['daily_report'] = v)),
                if (f['daily_report'] == true)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(ctx.tg('reportTime'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(ctx.tg('reportTimeHint'), style: TextStyle(color: c.muted, fontSize: 12.5)),
                    trailing: Btn(str(f['report_time']).isEmpty ? '21:00' : str(f['report_time']), icon: LucideIcons.clock3, kind: BtnKind.ghost, small: true, onTap: ro ? null : _pickTime),
                  ),
                const Divider(),
                SwitchRow(title: ctx.tg('shiftOpen'), sub: ctx.tg('shiftOpenSub'), value: f['shift_open'] == true, onChanged: ro ? null : (v) => setState(() => f['shift_open'] = v)),
                SwitchRow(title: ctx.tg('shiftClose'), sub: ctx.tg('shiftCloseSub'), value: f['shift_close'] == true, onChanged: ro ? null : (v) => setState(() => f['shift_close'] = v)),
                SwitchRow(
                  title: ctx.tg('stockAlerts'),
                  sub: ctx.addonOn('rest_stock') ? ctx.tg('stockAlertsSub') : ctx.tg('stockAlertsNeed'),
                  value: f['stock_alerts'] == true,
                  onChanged: ro ? null : (v) => setState(() => f['stock_alerts'] = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(ctx.tg('posNote'), style: TextStyle(color: c.muted, fontSize: 12.5)),
                    ),
                    const SizedBox(width: 10),
                    Btn(
                      _busy == 'save' ? ctx.r('saving') : ctx.r('save'),
                      small: true,
                      busy: _busy == 'save',
                      onTap: ro || !dirty || _busy == 'save' ? null : () => _run('save', () => ctx.api.put('${ctx.base}/telegram', f), ctx.r('saved')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          gap14,
          Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Muted(ctx.tg('preview'))),
          _sample(),
        ],
      ),
    );
  }

  Future<void> _pickTime() async {
    final parts = str(_form?['report_time']).split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: parts.length == 2 ? TimeOfDay(hour: int.tryParse(parts[0]) ?? 21, minute: int.tryParse(parts[1]) ?? 0) : const TimeOfDay(hour: 21, minute: 0),
      builder: (c2, child) => MediaQuery(data: MediaQuery.of(c2).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (t == null) return;
    setState(() => _form!['report_time'] = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
  }
}

// ------------------------------------------------------------------------------------------- Add-ons
class AddonsSection extends StatefulWidget {
  final RestCtx ctx;
  const AddonsSection({super.key, required this.ctx});
  @override
  State<AddonsSection> createState() => _AddonsSectionState();
}

class _AddonsSectionState extends State<AddonsSection> {
  final _search = TextEditingController();
  String _q = '', _show = 'all';
  RestCtx get ctx => widget.ctx;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _owned(Json a) => a['soon'] != true && ['active', 'expiring', 'forever'].contains(a['status']);
  String _norm(String v) => v.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final addons = ctx.addons;
    final other = ctx.lang == 'km' ? 'en' : 'km';
    final words = _norm(_q).split(' ').where((w) => w.isNotEmpty).toList();
    final mine = addons.where(_owned).length;
    final counts = {'all': addons.length, 'mine': mine, 'notMine': addons.length - mine};
    final list = addons.where((a) {
      if (_show == 'mine' && !_owned(a)) return false;
      if (_show == 'notMine' && _owned(a)) return false;
      if (words.isEmpty) return true;
      final k = str(a['key']);
      final hay = _norm(
        [ctx.r('addonNames.$k'), ctx.r('addonWhat.$k'), ctx.r('addonFree.$k'), ctx.t.other(other, 'rest.addonNames.$k'), ctx.t.other(other, 'rest.addonWhat.$k'), k.replaceAll('_', ' ')].join(' '),
      );
      return words.every(hay.contains);
    }).toList();
    String f(String k, [Map<String, Object?> v = const {}]) => ctx.t('addfind.$k', v);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RestHead(ctx.r('tabs.addons'), sub: ctx.r('addonsSub')),
              Field(
                controller: _search,
                hint: f('search'),
                icon: LucideIcons.search,
                onChanged: (v) => setState(() => _q = v),
                suffix: _q.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(LucideIcons.x, size: 16),
                        onPressed: () => setState(() {
                          _search.clear();
                          _q = '';
                        }),
                      ),
              ),
              const SizedBox(height: 10),
              Segmented<String>(
                value: _show,
                options: [
                  for (final k in ['all', 'mine', 'notMine']) (k, '${f(k)} ${counts[k]}'),
                ],
                onChanged: (v) => setState(() => _show = v),
              ),
            ],
          ),
        ),
        gap14,
        if (list.isEmpty)
          Panel(
            child: Column(
              children: [
                Muted(_q.isNotEmpty ? f('none', {'q': _q.trim()}) : f('noneFilter'), align: TextAlign.center),
                if (_q.isNotEmpty || _show != 'all') ...[
                  const SizedBox(height: 10),
                  Btn(
                    f('clear'),
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: () => setState(() {
                      _search.clear();
                      _q = '';
                      _show = 'all';
                    }),
                  ),
                ],
              ],
            ),
          ),
        for (final a in list) ...[_card(a, c), const SizedBox(height: 12)],
      ],
    );
  }

  Widget _card(Json a, C c) {
    final k = str(a['key']);
    final status = a['soon'] == true ? 'soon' : str(a['status']);
    final ro = ctx.readOnly;
    final on = status == 'active' || status == 'forever';
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: on ? c.goodBg : const Color(0xFFFFC53D).withValues(alpha: .2), borderRadius: BorderRadius.circular(14)),
                child: Icon(addonIcon(k), size: 22, color: on ? c.good : const Color(0xFF8A5A00)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ctx.r('addonNames.$k'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const CoinIcon(size: 14),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${fmt(a['price'])} ${ctx.r('coins')} ${n(a['days']) > 0 ? ctx.r('perYear') : '· ${ctx.r('oneTime')}'}',
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
          Text(ctx.r('addonWhat.$k'), style: const TextStyle(height: 1.45)),
          const SizedBox(height: 4),
          Text(ctx.r('addonFree.$k'), style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (status == 'soon') Chip2(k == 'rest_app' ? ctx.r('comingSoon') : ctx.r('soon'), icon: LucideIcons.clock3),
              if (status == 'forever') Chip2(ctx.r('forever'), icon: LucideIcons.infinity, tone: Tone.good),
              if (status == 'active' || status == 'expiring')
                Chip2(
                  ctx.r('activeUntil', {'date': fmtDate(a['expires_at'], lang: ctx.lang)}),
                  icon: LucideIcons.calendarClock,
                  tone: status == 'active' ? Tone.good : Tone.warn,
                ),
              if (status == 'expired') Chip2(ctx.r('expired', {'date': fmtDate(a['expires_at'], lang: ctx.lang)}), tone: Tone.danger),
              if (status != 'soon' && status != 'forever')
                status == 'active'
                    ? Btn(ctx.r('renewAddon'), icon: LucideIcons.check, kind: BtnKind.ghost, small: true, onTap: ro ? null : () => ctx.askBuy(k))
                    : Btn(
                        status == 'none' || status.isEmpty ? ctx.r('buy', {'coins': fmt(a['price'])}) : ctx.r('renewAddon'),
                        lead: const CoinIcon(size: 15),
                        small: true,
                        onTap: ro ? null : () => ctx.askBuy(k),
                      ),
            ],
          ),
        ],
      ),
    );
  }
}
