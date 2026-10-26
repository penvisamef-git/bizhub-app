import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../guesthouse/gh_common.dart' show ghMonth, shiftMonth;
import '../mart/mart_common.dart' show mGap, mDayTime, todayKH;
import '../mart/mart_kit.dart' show decimalKeys, numOf;
import '../restaurant/rest_common.dart' show SwitchRow;
import 'at_addons.dart';
import 'at_common.dart';
import 'at_setup.dart' show TimeField;

// Announcements · On-time rewards (EngageTabs.jsx) · Telegram (AddonTabs.jsx TelegramTab)

// ------------------------------------------------------------------------------------------------ ANNOUNCEMENTS
class NewsTab extends StatefulWidget {
  final AtCtx ctx;
  const NewsTab({super.key, required this.ctx});
  @override
  State<NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<NewsTab> {
  AtCtx get ctx => widget.ctx;
  Json? _data;
  bool _busy = false, _pinned = false;
  String _sure = '';
  final Set<String> _branches = {};
  final _title = TextEditingController(), _body = TextEditingController();
  String e(String k, [Map<String, Object?> v = const {}]) => ctx.t('aten.$k', v);
  bool get _on => ctx.addonOn('att_news');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/news');
      if (mounted) setState(() => _data = obj(r['data']));
    } catch (err) {
      ctx.fail(err);
    }
  }

  Future<void> _run(Future<Json> Function() fn, [String? ok]) async {
    setState(() => _busy = true);
    try {
      await fn();
      if (ok != null) ctx.notify(ok);
      await _load();
    } on ApiError catch (err) {
      if (err.status == 402) {
        ctx.askBuy('att_news');
      } else {
        ctx.fail(err);
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = objs(_data?['rows']);
    String branchName(Object? id) => str(ctx.branches.where((b) => b['_id'] == id).firstOrNull?['name']).ifBlank('?');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        if (!_on) ...[AtLocked(ctx: ctx, addon: 'att_news'), mGap],
        if (_on) ...[
          atPanel([
            Row(
              children: [
                Icon(LucideIcons.megaphone, size: 20, color: c.brand),
                const SizedBox(width: 8),
                Text(e('newsTitle'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 6),
            Muted(e('newsSub')),
            const SizedBox(height: 12),
            Field(label: e('title'), controller: _title, hint: e('titlePh'), maxLength: 100, onChanged: (_) => setState(() {})),
            const SizedBox(height: 12),
            Field(label: e('body'), controller: _body, hint: e('bodyPh'), maxLength: 2000, maxLines: 4),
            if (ctx.branches.length > 1) ...[
              const SizedBox(height: 12),
              Text(e('to'), style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  FilterChip(label: Text(e('everyone')), selected: _branches.isEmpty, onSelected: (_) => setState(_branches.clear)),
                  for (final b in ctx.branches)
                    FilterChip(
                      label: Text(str(b['name'])),
                      selected: _branches.contains(b['_id']),
                      onSelected: (_) => setState(() => _branches.contains(b['_id']) ? _branches.remove(b['_id']) : _branches.add(str(b['_id']))),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            SwitchRow(title: e('pinned'), value: _pinned, onChanged: (v) => setState(() => _pinned = v)),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Btn(
                _busy ? e('posting') : e('post'),
                icon: LucideIcons.send,
                small: true,
                busy: _busy,
                onTap: _busy || ctx.readOnly || _title.text.trim().isEmpty
                    ? null
                    : () async {
                        await _run(() => ctx.api.post('${ctx.base}/news', {'title': _title.text.trim(), 'body': _body.text.trim(), 'pinned': _pinned, 'branch_ids': _branches.toList()}), e('posted'));
                        _title.clear();
                        _body.clear();
                        setState(() {
                          _pinned = false;
                          _branches.clear();
                        });
                      },
              ),
            ),
          ]),
          mGap,
        ],
        if (_data == null)
          const SkelList(rows: 3)
        else if (rows.isEmpty)
          _on ? atPanel([Muted(e('noNews'), align: TextAlign.center)]) : const SizedBox.shrink()
        else
          for (final x in rows) ...[
            () {
              final read = n(x['read']), total = n(x['total']);
              final waiting = (x['waiting'] as List? ?? const []).map((e) => '$e').toList();
              final id = str(x['_id']);
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: x['pinned'] == true ? Border.all(color: c.brand, width: 1.5) : null,
                ),
                child: atPanel(padding: const EdgeInsets.all(14), [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (x['pinned'] == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, right: 6),
                          child: Icon(LucideIcons.pin, size: 15, color: c.brand),
                        ),
                      Expanded(
                        child: Text(str(x['title']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                      Muted(mDayTime(x['created_date'], ctx.lang)),
                    ],
                  ),
                  if (str(x['body']).isNotEmpty) ...[const SizedBox(height: 6), Text(str(x['body']), style: const TextStyle(height: 1.45))],
                  const SizedBox(height: 10),
                  if ((x['branch_ids'] as List? ?? const []).isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip2((x['branch_ids'] as List).map(branchName).join(', '), icon: LucideIcons.mapPin),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(value: total == 0 ? 0 : (read / total).toDouble(), minHeight: 6, color: c.good, backgroundColor: c.bg2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(e('readBy', {'n': read, 'm': total}), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ],
                  ),
                  if (total > 0) ...[
                    const SizedBox(height: 6),
                    Muted(waiting.isNotEmpty ? e('waiting', {'names': waiting.join(', ')}) : e('allRead')),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Btn(
                        x['pinned'] == true ? e('unpin') : e('pin'),
                        icon: x['pinned'] == true ? LucideIcons.pinOff : LucideIcons.pin,
                        kind: BtnKind.ghost,
                        small: true,
                        onTap: _busy || ctx.readOnly || !_on ? null : () => _run(() => ctx.api.put('${ctx.base}/news/$id', {'pinned': x['pinned'] != true})),
                      ),
                      const SizedBox(width: 8),
                      _sure == id
                          ? Btn(e('sure'), kind: BtnKind.danger, small: true, onTap: _busy ? null : () => _run(() => ctx.api.delete('${ctx.base}/news/$id')))
                          : Btn(e('remove'), icon: LucideIcons.trash2, kind: BtnKind.ghost, small: true, onTap: _busy || ctx.readOnly ? null : () => setState(() => _sure = id)),
                    ],
                  ),
                ]),
              );
            }(),
            mGap,
          ],
      ],
    );
  }
}

extension on String {
  String ifBlank(String v) => isEmpty ? v : this;
}

// ------------------------------------------------------------------------------------------------ ON-TIME REWARDS
class RewardsTab extends StatefulWidget {
  final AtCtx ctx;
  const RewardsTab({super.key, required this.ctx});
  @override
  State<RewardsTab> createState() => _RewardsTabState();
}

class _RewardsTabState extends State<RewardsTab> {
  AtCtx get ctx => widget.ctx;
  late String _month = todayKH().substring(0, 7);
  Json? _data;
  final _bonus = TextEditingController();
  bool? _board;
  bool _busy = false;
  String e(String k, [Map<String, Object?> v = const {}]) => ctx.t('aten.$k', v);
  bool get _on => ctx.addonOn('att_rewards');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bonus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/rewards', {'month': _month});
      if (!mounted) return;
      setState(() {
        _data = obj(r['data']);
        final st = obj(_data!['settings']);
        if (_board == null) {
          _board = st['board'] == true;
          _bonus.text = '${n(st['bonus'])}'.replaceFirst(RegExp(r'\.0$'), '');
        }
      });
    } catch (err) {
      ctx.fail(err);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ctx.api.put('${ctx.base}/rewards/settings', {'bonus': numOf(_bonus.text) ?? 0, 'board': _board});
      ctx.notify(e('saved'));
      await _load();
    } on ApiError catch (err) {
      if (err.status == 402) {
        ctx.askBuy('att_rewards');
      } else {
        ctx.fail(err);
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  void _go(int by) {
    setState(() {
      _month = shiftMonth(_month, by);
      _data = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = _data;
    final st = obj(d?['settings']);
    final thisMonth = todayKH().substring(0, 7);
    final changed = d != null && _board != null && ((numOf(_bonus.text) ?? 0) != n(st['bonus']) || _board != (st['board'] == true));
    final rows = objs(d?['rows']).where((r) => n(r['work']) > 0).toList();
    const cups = [Color(0xFFE0A21A), Color(0xFF9CA3AF), Color(0xFFB45309)];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        if (!_on) ...[AtLocked(ctx: ctx, addon: 'att_rewards'), mGap],
        atPanel([
          Row(
            children: [
              Icon(LucideIcons.award, size: 20, color: c.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(e('rwTitle'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(onPressed: () => _go(-1), icon: const Icon(LucideIcons.chevronLeft)),
              Expanded(
                child: Text(
                  _month == thisMonth ? e('thisMonth') : ghMonth(_month, ctx.lang),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              IconButton(onPressed: _month.compareTo(thisMonth) >= 0 ? null : () => _go(1), icon: const Icon(LucideIcons.chevronRight)),
            ],
          ),
          Muted(e('rwSub')),
          if (_on && d != null && _board != null) ...[
            const SizedBox(height: 12),
            Field(label: '${e('bonus')} (${str(d['currency']).ifBlank('USD')})', controller: _bonus, keyboard: decimalKeys, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
            const SizedBox(height: 4),
            Muted(d['payroll'] == true ? e('bonusHint') : e('needPayroll')),
            const SizedBox(height: 6),
            SwitchRow(title: e('board'), value: _board!, onChanged: ctx.readOnly ? null : (v) => setState(() => _board = v)),
            if (changed)
              Align(
                alignment: Alignment.centerRight,
                child: Btn(e('save'), icon: LucideIcons.save, small: true, busy: _busy, onTap: _busy || ctx.readOnly ? null : _save),
              ),
          ],
        ]),
        mGap,
        if (d == null)
          const SkelList(rows: 4)
        else if (rows.isEmpty)
          atPanel([Muted(e('noRows'), align: TextAlign.center)])
        else
          atPanel(padding: const EdgeInsets.fromLTRB(12, 8, 12, 8), [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: n(r['rank']) <= 3
                          ? Icon(LucideIcons.trophy, size: 20, color: cups[n(r['rank']).toInt() - 1])
                          : Text(
                              '${n(r['rank'])}',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w800, color: c.muted),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(str(r['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                              ),
                              if (r['perfect'] == true) ...[const SizedBox(width: 6), AtTag(e('perfect'), tone: 'ok')],
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(99),
                                  child: LinearProgressIndicator(value: n(r['rate']) / 100, minHeight: 6, color: c.good, backgroundColor: c.bg2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('${n(r['rate'])}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              AtTag('${e('days')} ${n(r['on_time'])}/${n(r['work'])}'),
                              if (n(r['late']) > 0) AtTag('${e('late')} ${n(r['late'])}', tone: 'warn'),
                              if (n(r['absent']) > 0) AtTag('${e('absent')} ${n(r['absent'])}', tone: 'bad'),
                              if (n(r['streak']) > 0) AtTag('${n(r['streak'])}', tone: 'warn', icon: LucideIcons.flame),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ]),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ TELEGRAM
class TelegramTab extends StatefulWidget {
  final AtCtx ctx;
  const TelegramTab({super.key, required this.ctx});
  @override
  State<TelegramTab> createState() => _TelegramTabState();
}

class _TelegramTabState extends State<TelegramTab> {
  AtCtx get ctx => widget.ctx;
  Json? _st;
  bool _waiting = false, _busy = false;
  Timer? _poll;
  String x(String k, [Map<String, Object?> v = const {}]) => ctx.t('atx.$k', v);

  @override
  void initState() {
    super.initState();
    if (ctx.addonOn('att_telegram')) _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<Json?> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/telegram');
      if (mounted) setState(() => _st = obj(r['data']));
      return obj(r['data']);
    } catch (err) {
      ctx.fail(err);
      return null;
    }
  }

  Future<void> _connect(bool group) async {
    final r = await ctx.run(() => ctx.api.post('${ctx.base}/telegram/link'));
    if (r == null) return;
    final url = str(obj(r['data'])[group ? 'group_url' : 'url']);
    if (url.isNotEmpty) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    setState(() => _waiting = true);
    var tries = 0;
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (t) async {
      tries++;
      final d = await _load();
      if (d?['connected'] == true || tries > 60) {
        t.cancel();
        if (mounted) setState(() => _waiting = false);
      }
    });
  }

  Future<void> _save(Json patch) async {
    setState(() => _st = {..._st!, ...patch});
    try {
      final r = await ctx.api.put('${ctx.base}/telegram', patch);
      if (mounted) setState(() => _st = obj(r['data']));
    } catch (err) {
      ctx.fail(err);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ctx.addonOn('att_telegram')) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [AtLocked(ctx: ctx, addon: 'att_telegram')],
      );
    }
    final c = context.c;
    final st = _st;
    if (st == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 3));
    final ro = ctx.readOnly;
    final on = st['connected'] == true;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        atPanel([
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: on ? const Color(0xFF229ED9) : c.bg2, shape: BoxShape.circle),
                child: Icon(LucideIcons.send, color: on ? Colors.white : c.muted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ctx.a('tabs.telegram'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Muted(x('tgSub')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (st['configured'] != true) ...[Alert(x('notConfigured')), const SizedBox(height: 10)],
          if (on)
            Text(
              '✓ ${x('connected', {'name': st['chat_name']})}',
              style: TextStyle(color: c.good, fontWeight: FontWeight.w800),
            )
          else
            Muted(_waiting ? x('waiting') : x('notConnected')),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: on
                ? [
                    Btn(
                      x('test'),
                      icon: LucideIcons.send,
                      kind: BtnKind.ghost,
                      small: true,
                      busy: _busy,
                      onTap: _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              await ctx.run(() => ctx.api.post('${ctx.base}/telegram/test'), x('sent'));
                              if (mounted) setState(() => _busy = false);
                            },
                    ),
                    Btn(
                      x('disconnect'),
                      icon: LucideIcons.unplug,
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: _busy || ro
                          ? null
                          : () async {
                              final r = await ctx.run(() => ctx.api.delete('${ctx.base}/telegram'));
                              if (r != null && mounted) setState(() => _st = obj(r['data']));
                            },
                    ),
                  ]
                : [
                    Btn(x('connect'), icon: LucideIcons.send, small: true, busy: _waiting, onTap: ro || st['configured'] != true ? null : () => _connect(false)),
                    Btn(x('connectGroup'), icon: LucideIcons.users, kind: BtnKind.ghost, small: true, onTap: ro || st['configured'] != true ? null : () => _connect(true)),
                  ],
          ),
        ]),
        mGap,
        atPanel([
          SwitchRow(title: x('dailyReport'), value: st['daily_report'] == true, onChanged: ro ? null : (v) => _save({'daily_report': v})),
          if (st['daily_report'] == true)
            Row(
              children: [
                Text(x('at')),
                const SizedBox(width: 10),
                SizedBox(
                  width: 130,
                  child: TimeField(value: str(st['report_time']), onChanged: (v) => ro || v.isEmpty ? null : _save({'report_time': v})),
                ),
              ],
            ),
          for (final k in ['late_alert', 'review_alert', 'leave_alert', 'out_alert', 'fix_alert', 'monthly'])
            SwitchRow(
              title: x(switch (k) {
                'late_alert' => 'lateAlert',
                'review_alert' => 'reviewAlert',
                'leave_alert' => 'leaveAlert',
                'out_alert' => 'outAlert',
                'fix_alert' => 'fixAlert',
                _ => 'monthly',
              }),
              value: st[k] == true,
              onChanged: ro ? null : (v) => _save({k: v}),
            ),
        ]),
      ],
    );
  }
}
