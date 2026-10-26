import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../restaurant/rest_common.dart' show SelectField;
import 'ev_common.dart';

// a simple bar: label · bar · value
class _Bar extends StatelessWidget {
  final String label, value;
  final double part;
  final Color? color;
  const _Bar(this.label, this.part, this.value, {this.color});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: part.clamp(0, 1), minHeight: 9, backgroundColor: c.chip, color: color ?? c.brand),
            ),
          ),
          SizedBox(
            width: 74,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

// columns (money per month, tickets per day…)
class _Cols extends StatelessWidget {
  final List<(String, num)> items;
  final String Function(num) label;
  const _Cols(this.items, {required this.label});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final max = items.fold<num>(1, (a, x) => x.$2 > a ? x.$2 : a);
    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (k, v) in items)
            Expanded(
              child: Tooltip(
                message: '$k · ${label(v)}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: (v / max).clamp(.02, 1).toDouble(),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.brand, c.brand.withValues(alpha: .55)]),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        k,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(fontSize: 9.5, color: c.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ======================================== Report: all events + one event ========================================
class ReportTab extends StatefulWidget {
  final EvCtx ctx;
  const ReportTab({super.key, required this.ctx});
  @override
  State<ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<ReportTab> {
  EvCtx get ctx => widget.ctx;
  late String _mode = ctx.event.isNotEmpty ? 'one' : 'all';
  late String _event = ctx.firstEvent();
  int _months = 12;
  Json? _ov, _one;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (_mode == 'all') {
        final r = await ctx.api.get('${ctx.base}/report/overview', {'months': _months});
        if (mounted) setState(() => _ov = obj(r['data']));
      } else if (_event.isNotEmpty) {
        final r = await ctx.api.get('${ctx.base}/events/$_event/report');
        if (mounted) setState(() => _one = obj(r['data']));
      }
    } catch (e) {
      ctx.fail(e);
    }
  }

  String _mon(String k) {
    final p = k.split('-');
    if (p.length < 2) return k;
    const en = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${en[(int.tryParse(p[1]) ?? 1) - 1]} ${p[0].substring(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return EvList(
      onRefresh: _load,
      children: [
        EvHead(ctx.m('reportTitle'), sub: ctx.m('reportSub')),
        EvChips(
          items: [('all', ctx.m('grow.ovAll'), null), ('one', ctx.m('grow.ovOne'), null)],
          value: _mode,
          onPick: (v) => setState(() {
            _mode = v;
            _load();
          }),
        ),
        const SizedBox(height: 12),
        if (_mode == 'all') ..._all() else ..._oneEvent(),
      ],
    );
  }

  List<Widget> _all() {
    final c = context.c;
    final d = _ov;
    return [
      EvChips(
        items: [
          for (final m in [3, 6, 12, 24]) ('$m', ctx.m('grow.ovMonths', {'n': m}), null),
        ],
        value: '$_months',
        onPick: (v) => setState(() {
          _months = int.parse(v);
          _ov = null;
          _load();
        }),
      ),
      const SizedBox(height: 10),
      if (d == null)
        const SkelList(rows: 4)
      else ...[
        Builder(
          builder: (_) {
            final t = obj(d['totals']);
            final fb = obj(d['feedback']);
            return EvStats([
              EvStat(ctx.m('grow.ovMoney'), usd2(t['money']), sub: n(t['refunded']) > 0 ? ctx.m('grow.ovRefunded', {'m': usd2(t['refunded'])}) : ctx.m('grow.ovNoRefund'), tone: Tone.good),
              EvStat(ctx.m('grow.ovTickets'), fmt(n(t['tickets'])), sub: ctx.m('grow.ovOrders', {'n': fmt(n(t['orders']))})),
              EvStat(ctx.m('grow.ovIn'), fmt(n(t['used'])), sub: n(t['tickets']) > 0 ? '${(n(t['used']) / n(t['tickets']) * 100).round()}%' : '—'),
              EvStat(ctx.m('grow.ovScore'), fb['avg'] == null ? '—' : '${fb['avg']} ★', sub: ctx.m('grow.ovReviews', {'n': n(fb['n'])})),
            ]);
          },
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(ctx.m('grow.ovChart'), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _Cols([for (final m in objs(d['series'])) (_mon(str(m['month'])), n(m['money']))], label: usd2),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(ctx.m('grow.ovTop'), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              if (objs(d['top']).isEmpty) Muted(ctx.m('noData')),
              for (final (i, t) in objs(d['top']).indexed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: CircleAvatar(
                    radius: 13,
                    backgroundColor: c.active,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.brandInk),
                    ),
                  ),
                  title: Text(
                    str(obj(t['event'])['title']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('${fmt(n(t['tickets']))} · ${evWhen(obj(t['event'])['starts_at'], ctx.lang, time: false)}'),
                  trailing: Text(usd2(t['money']), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(ctx.m('grow.ovPay'), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              if (objs(d['pay']).isEmpty) Muted('—'),
              for (final p in objs(d['pay'])) _Bar(str(p['label']), n(objs(d['pay']).first['money']) > 0 ? (n(p['money']) / n(objs(d['pay']).first['money'])).toDouble() : 0, usd2(p['money'])),
              const SizedBox(height: 12),
              Text(ctx.m('grow.ovVia'), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              for (final v in objs(d['via']))
                _Bar(
                  ctx.m('grow.via.${v['via']}'),
                  (n(v['tickets']) / objs(d['via']).fold<num>(1, (a, x) => n(x['tickets']) > a ? n(x['tickets']) : a)).toDouble(),
                  fmt(n(v['tickets'])),
                  color: c.good,
                ),
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _oneEvent() {
    final c = context.c;
    final r = _one;
    return [
      EvEventPick(
        ctx: ctx,
        value: _event,
        onChanged: (v) => setState(() {
          _event = v;
          _one = null;
          _load();
        }),
      ),
      const SizedBox(height: 10),
      if (_event.isEmpty)
        Panel(child: Muted(ctx.m('noEvents')))
      else if (r == null)
        const SkelList(rows: 4)
      else ...[
        Builder(
          builder: (_) {
            final t = obj(r['totals']);
            return EvStats([
              EvStat(ctx.m('rSold'), '${fmt(n(t['sold']))} / ${fmt(n(t['qty']))}'),
              EvStat(ctx.m('rIn'), fmt(n(t['used'])), tone: Tone.good),
              EvStat(ctx.m('rMoney'), usd2(t['money']), sub: n(t['discount']) > 0 ? '${ctx.m('more.discount')} −${usd2(t['discount'])}' : null, tone: Tone.good),
              EvStat(ctx.m('rWaiting'), fmt(n(t['waiting'])), tone: n(t['waiting']) > 0 ? Tone.warn : null),
            ]);
          },
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(ctx.m('rType'), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              for (final ty in objs(r['types']))
                _Bar('${ty['name']} · ${usd2(ty['price'])}', n(ty['qty']) > 0 ? (n(ty['sold']) / n(ty['qty'])).toDouble() : 0, '${fmt(n(ty['sold']))}/${fmt(n(ty['qty']))}'),
              if (objs(r['shows']).isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(ctx.m('more.perShow'), style: const TextStyle(fontWeight: FontWeight.w800)),
                for (final sh in objs(r['shows']))
                  _Bar(
                    str(sh['label']).isNotEmpty ? str(sh['label']) : evWhen(sh['starts_at'], ctx.lang, year: false),
                    n(sh['qty']) > 0 ? (n(sh['sold']) / n(sh['qty'])).toDouble() : 0,
                    '${fmt(n(sh['sold']))} · ${fmt(n(sh['used']))} in',
                  ),
              ],
              const SizedBox(height: 12),
              Text(ctx.m('viaTitle'), style: const TextStyle(fontWeight: FontWeight.w800)),
              for (final v in objs(r['via'])) _Bar(ctx.m('grow.via.${v['via']}'), 1, '${fmt(n(v['tickets']))} · ${usd2(v['money'])}', color: c.good),
              if (objs(r['promos']).isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(ctx.m('tabs.promos'), style: const TextStyle(fontWeight: FontWeight.w800)),
                for (final p in objs(r['promos'])) _Bar(str(p['code']), 1, '${fmt(n(p['orders']))} · −${usd2(p['off'])}', color: c.warn),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(ctx.m('perDay'), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (objs(r['per_day']).isEmpty)
                Muted(ctx.m('noData'))
              else
                _Cols([for (final d in objs(r['per_day']).reversed.take(14).toList().reversed) (str(d['day']).substring(5), n(d['tickets']))], label: fmt),
              const SizedBox(height: 14),
              Text(ctx.m('perHour'), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (objs(r['checkins']).isEmpty)
                Muted(ctx.m('noData'))
              else
                _Cols([
                  for (final h in objs(r['checkins']).reversed.take(16).toList().reversed) (str(h['hour']).length >= 13 ? str(h['hour']).substring(11, 13) : str(h['hour']), n(h['n'])),
                ], label: fmt),
            ],
          ),
        ),
      ],
    ];
  }
}

// ======================================== Feedback ========================================
class FeedbackTab extends StatefulWidget {
  final EvCtx ctx;
  const FeedbackTab({super.key, required this.ctx});
  @override
  State<FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends State<FeedbackTab> {
  EvCtx get ctx => widget.ctx;
  late String _event = ctx.firstEvent();
  Json? _d;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_event.isEmpty) return;
    try {
      final r = await ctx.api.get('${ctx.base}/events/$_event/feedback');
      if (mounted) setState(() => _d = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ev = ctx.eventById(_event);
    final d = _d;
    final dist = (d?['dist'] as List? ?? const [0, 0, 0, 0, 0]).map((x) => n(x)).toList();
    final max = dist.fold<num>(1, (a, x) => x > a ? x : a);
    Widget stars(num v, double size) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [for (var i = 1; i <= 5; i++) Icon(LucideIcons.star, size: size, color: v >= i - .25 ? const Color(0xFFF59E0B) : c.line)],
    );
    return EvList(
      onRefresh: _load,
      children: [
        EvHead(ctx.m('grow.fbTabTitle'), sub: ctx.m('grow.fbTabSub')),
        EvLocked(
          ctx: ctx,
          addon: 'ev_feedback',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EvEventPick(
                ctx: ctx,
                value: _event,
                onChanged: (v) => setState(() {
                  _event = v;
                  _d = null;
                  _load();
                }),
              ),
              const SizedBox(height: 10),
              if (ev != null && obj(ev['feedback'])['on'] != true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Alert(ctx.m('grow.fbOff'), tone: Tone.warn),
                ),
              if (ev != null && obj(ev['feedback'])['on'] == true)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Btn(
                    ctx.m('grow.fbSend'),
                    icon: LucideIcons.send,
                    small: true,
                    kind: BtnKind.ghost,
                    onTap: ctx.readOnly
                        ? null
                        : () async {
                            final r = await ctx.run(() => ctx.api.post('${ctx.base}/events/$_event/feedback/send'));
                            if (r != null) ctx.notify(ctx.m('grow.fbSent', {'n': n(r['sent'])}));
                          },
                  ),
                ),
              const SizedBox(height: 10),
              if (d == null)
                const SkelList(rows: 3)
              else ...[
                Panel(
                  child: Row(
                    children: [
                      Column(
                        children: [
                          Text(d['avg'] == null ? '—' : '${d['avg']}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800)),
                          stars(n(d['avg']), 16),
                          const SizedBox(height: 4),
                          Text(ctx.m('grow.fbCount', {'n': n(d['n']), 'of': n(d['paid'])}), style: TextStyle(fontSize: 11.5, color: c.muted)),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(children: [for (var s = 5; s >= 1; s--) _Bar('$s ★', (dist[s - 1] / max).toDouble(), fmt(dist[s - 1]), color: const Color(0xFFF59E0B))]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (objs(d['list']).isEmpty) Panel(child: Muted(ctx.m('grow.fbNone'), align: TextAlign.center)),
                for (final f in objs(d['list']))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Panel(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              stars(n(f['rating']), 14),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(str(f['name']).isEmpty ? '—' : str(f['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                              ),
                              Text(evWhen(f['at'], ctx.lang, time: false), style: TextStyle(fontSize: 11.5, color: c.muted)),
                            ],
                          ),
                          if (str(f['answer']).isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(str(obj(ev?['feedback'])['question']), style: TextStyle(fontSize: 11.5, color: c.muted)),
                            Text(str(f['answer'])),
                          ],
                          if (str(f['comment']).isNotEmpty) ...[const SizedBox(height: 6), Text(str(f['comment']))],
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ======================================== Waitlist ========================================
class WaitlistTab extends StatefulWidget {
  final EvCtx ctx;
  const WaitlistTab({super.key, required this.ctx});
  @override
  State<WaitlistTab> createState() => _WaitlistTabState();
}

class _WaitlistTabState extends State<WaitlistTab> {
  EvCtx get ctx => widget.ctx;
  late String _event = ctx.firstEvent();
  Json? _d;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_event.isEmpty || !ctx.on('ev_waitlist')) return;
    try {
      final r = await ctx.api.get('${ctx.base}/events/$_event/waitlist');
      if (mounted) setState(() => _d = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ev = ctx.eventById(_event);
    final d = _d;
    final cnt = obj(d?['counts']);
    final left = obj(d?['left']).values.fold<num>(0, (a, v) => a + n(v));
    String typeName(String k) => objs(ev?['types']).where((t) => t['key'] == k).firstOrNull?['name']?.toString() ?? ctx.m('grow.anyType');
    return EvList(
      onRefresh: _load,
      children: [
        EvHead(ctx.m('grow.wlTitle'), sub: ctx.m('grow.wlSub')),
        EvLocked(
          ctx: ctx,
          addon: 'ev_waitlist',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EvEventPick(
                ctx: ctx,
                value: _event,
                onChanged: (v) => setState(() {
                  _event = v;
                  _d = null;
                  _load();
                }),
              ),
              const SizedBox(height: 10),
              if (d == null)
                const SkelList(rows: 3)
              else ...[
                EvStats([
                  EvStat(ctx.m('grow.wlWaiting'), fmt(n(cnt['waiting']))),
                  EvStat(ctx.m('grow.wlToldN'), fmt(n(cnt['told'])), tone: Tone.warn),
                  EvStat(ctx.m('grow.wlBought'), fmt(n(cnt['bought'])), tone: Tone.good),
                  EvStat(ctx.m('grow.wlLeft'), fmt(left)),
                ]),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Btn(
                    ctx.m('grow.wlNotify'),
                    icon: LucideIcons.send,
                    small: true,
                    busy: _busy,
                    onTap: ctx.readOnly || n(cnt['waiting']) == 0
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            final r = await ctx.run(() => ctx.api.post('${ctx.base}/events/$_event/waitlist/notify', {'n': 10}));
                            if (r != null) ctx.notify(ctx.m('grow.wlTold', {'n': n(r['told'])}));
                            await _load();
                            if (mounted) setState(() => _busy = false);
                          },
                  ),
                ),
                const SizedBox(height: 10),
                if (objs(d['list']).isEmpty) Panel(child: Muted(ctx.m('grow.wlNone'), align: TextAlign.center)),
                if (objs(d['list']).isNotEmpty)
                  Panel(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Column(
                      children: [
                        for (final (i, w) in objs(d['list']).indexed)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: c.chip,
                              child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                            ),
                            title: Text(str(w['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${w['phone']} · ${w['qty']} × ${typeName(str(w['type_key']))}${w['tg'] == true ? ' · Telegram ✓' : ''}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip2(ctx.m('grow.wlStatus.${w['status']}'), tone: w['status'] == 'bought' ? Tone.good : (w['status'] == 'told' ? Tone.warn : Tone.muted)),
                                IconButton(
                                  onPressed: () => launchUrl(Uri.parse('tel:${w['phone']}')),
                                  icon: Icon(LucideIcons.phone, size: 16, color: c.brand),
                                ),
                                IconButton(
                                  onPressed: ctx.readOnly
                                      ? null
                                      : () async {
                                          final r = await ctx.run(() => ctx.api.delete('${ctx.base}/waitlist/${w['_id']}'));
                                          if (r != null) _load();
                                        },
                                  icon: Icon(LucideIcons.trash2, size: 16, color: c.muted),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ======================================== Promoters (ev_referrals) ========================================
class PromotersTab extends StatefulWidget {
  final EvCtx ctx;
  const PromotersTab({super.key, required this.ctx});
  @override
  State<PromotersTab> createState() => _PromotersTabState();
}

class _PromotersTabState extends State<PromotersTab> {
  EvCtx get ctx => widget.ctx;
  List<Json>? _list;
  final _name = TextEditingController(), _code = TextEditingController(), _value = TextEditingController(text: '10');
  String _kind = 'percent', _evFor = '';
  late String _linkEv = ctx.events.where((e) => e['status'] == 'published').map((e) => str(e['slug'])).firstOrNull ?? '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _value.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!ctx.on('ev_referrals')) return;
    try {
      final r = await ctx.api.get('${ctx.base}/refs');
      if (mounted) setState(() => _list = objs(r['data']));
    } catch (e) {
      ctx.fail(e);
      if (mounted) setState(() => _list = []);
    }
  }

  Future<void> _do(Future<Json> Function() fn, [String? ok]) async {
    final r = await ctx.run(fn, ok);
    if (r != null && mounted) setState(() => _list = objs(r['data']));
  }

  String _linkFor(Json r) {
    final slug = str(obj(r['event'])['slug']).isNotEmpty ? str(obj(r['event'])['slug']) : _linkEv;
    return slug.isEmpty ? '' : '${eventUrl(slug)}?ref=${r['code']}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final list = [...?_list]..sort((a, b) => n(b['money']).compareTo(n(a['money'])));
    final tickets = list.fold<num>(0, (a, r) => a + n(r['tickets']));
    final money = list.fold<num>(0, (a, r) => a + n(r['money']));
    final owed = list.fold<num>(0, (a, r) => a + n(r['owed']));
    final evFor = ctx.eventById(_evFor);
    return EvList(
      onRefresh: _load,
      children: [
        EvHead(ctx.m('grow.prTitle'), sub: ctx.m('grow.prSub')),
        EvLocked(
          ctx: ctx,
          addon: 'ev_referrals',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(ctx.m('grow.prAdd'), style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Field(hint: ctx.m('grow.prName'), controller: _name, maxLength: 60, onChanged: (_) => setState(() {})),
                    const SizedBox(height: 8),
                    Field(hint: ctx.m('grow.prCode'), controller: _code, maxLength: 24),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final v = await pickEvent(context, ctx, _evFor, all: true);
                        if (v != null) setState(() => _evFor = v);
                      },
                      icon: const Icon(LucideIcons.ticket, size: 15),
                      label: Text(evFor == null ? ctx.m('grow.prAnyEvent') : str(evFor['title']), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 90,
                          child: Field(hint: ctx.m('grow.prCommission'), controller: _value, keyboard: const TextInputType.numberWithOptions(decimal: true)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: [
                              ButtonSegment(value: 'percent', label: Text(ctx.m('grow.prPercent'))),
                              ButtonSegment(value: 'amount', label: Text(ctx.m('grow.prPerTicket'))),
                            ],
                            selected: {_kind},
                            onSelectionChanged: (v) => setState(() => _kind = v.first),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Btn(
                      ctx.m('grow.prAddBtn'),
                      icon: LucideIcons.plus,
                      busy: _busy,
                      onTap: _name.text.trim().isEmpty || ctx.readOnly
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              await _do(
                                () => ctx.api.post('${ctx.base}/refs', {
                                  'name': _name.text.trim(),
                                  if (_code.text.trim().isNotEmpty) 'code': _code.text.trim(),
                                  'event_id': _evFor.isEmpty ? null : _evFor,
                                  'commission': {'kind': _kind, 'value': num.tryParse(_value.text.trim()) ?? 0},
                                }),
                                ctx.m('saved'),
                              );
                              _name.clear();
                              _code.clear();
                              if (mounted) setState(() => _busy = false);
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              EvStats([
                EvStat(ctx.m('grow.prCount'), fmt(list.length)),
                EvStat(ctx.m('grow.prSold'), fmt(tickets), sub: usd2(money)),
                EvStat(ctx.m('grow.prOwed'), usd2(owed), tone: owed > 0 ? Tone.warn : null),
              ]),
              const SizedBox(height: 10),
              if (ctx.events.any((e) => e['status'] == 'published'))
                SelectField<String>(
                  label: ctx.m('grow.prLinkFor'),
                  value: _linkEv,
                  options: [('', '—'), for (final e in ctx.events.where((e) => e['status'] == 'published')) (str(e['slug']), str(e['title']))],
                  onChanged: (v) => setState(() => _linkEv = v),
                ),
              const SizedBox(height: 10),
              if (_list == null)
                const SkelList(rows: 3)
              else if (list.isEmpty)
                Panel(child: Muted(ctx.m('grow.prNone'), align: TextAlign.center))
              else
                for (final (i, r) in list.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Opacity(
                      opacity: r['active'] == true ? 1 : .6,
                      child: Panel(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 15,
                                  backgroundColor: c.brand,
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(str(r['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                                      Text(
                                        '${r['code']} · ${obj(r['commission'])['kind'] == 'percent' ? '${obj(r['commission'])['value']}%' : '${usd2(obj(r['commission'])['value'])} / ${ctx.m('grow.ticket')}'}${obj(r['event'])['title'] != null ? ' · ${obj(r['event'])['title']}' : ''}',
                                        style: TextStyle(fontSize: 12, color: c.muted),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(value: r['active'] == true, onChanged: ctx.readOnly ? null : (v) => _do(() => ctx.api.put('${ctx.base}/refs/${r['_id']}', {'active': v}))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            EvStats([
                              EvStat(ctx.m('grow.prClicks'), fmt(n(r['clicks']))),
                              EvStat(ctx.m('grow.prTickets'), fmt(n(r['tickets'])), sub: usd2(r['money'])),
                              EvStat(ctx.m('grow.prEarned'), usd2(r['earned'])),
                              EvStat(ctx.m('grow.prOwedOne'), usd2(r['owed']), tone: n(r['owed']) > 0 ? Tone.warn : null),
                            ]),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Btn(ctx.m('grow.prCopy'), icon: LucideIcons.copy, small: true, kind: BtnKind.ghost, onTap: _linkFor(r).isEmpty ? null : () => evCopy(ctx, _linkFor(r))),
                                const SizedBox(width: 6),
                                if (n(r['owed']) > 0)
                                  Btn(
                                    ctx.m('grow.prPay'),
                                    icon: LucideIcons.wallet,
                                    small: true,
                                    kind: BtnKind.ghost,
                                    onTap: ctx.readOnly
                                        ? null
                                        : () async {
                                            final v = await askText(
                                              context,
                                              title: ctx.m('grow.prPayAsk', {'name': r['name']}),
                                              initial: '${r['owed']}',
                                              keyboard: const TextInputType.numberWithOptions(decimal: true),
                                              ok: ctx.m('grow.prPay'),
                                              cancel: ctx.m('cancel'),
                                            );
                                            if (v != null && (num.tryParse(v) ?? 0) > 0) _do(() => ctx.api.post('${ctx.base}/refs/${r['_id']}/payout', {'amount': num.parse(v)}));
                                          },
                                  ),
                                const Spacer(),
                                IconButton(
                                  onPressed: ctx.readOnly
                                      ? null
                                      : () async {
                                          if (await askSure(context, ctx.m('grow.prDelSure'), ok: ctx.m('remove'), cancel: ctx.m('cancel'), danger: true)) {
                                            _do(() => ctx.api.delete('${ctx.base}/refs/${r['_id']}'));
                                          }
                                        },
                                  icon: Icon(LucideIcons.trash2, size: 17, color: c.danger),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}
