import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show MHead, SureDelete, BarRow, Tiles, mGap, mDate, mDayTime, todayKH, fileForm;
import '../mart/mart_kit.dart' show MSheet, showSheet, DayField, decimalKeys, numOf;
import '../restaurant/rest_common.dart' show Segmented, SwitchRow, gap14;
import 'gh_common.dart';
import 'gh_ops.dart' show GhHero, GhPerks;
import 'gh_setup.dart' show GhSave;
import 'gh_stay.dart' show svcEmoji;

// Reviews (gh_reviews), Loyalty (gh_loyalty), Expenses & profit (gh_expenses), Extra services (gh_services), Telegram (gh_telegram), Profile
// + the member box and review link inside a booking — GhGuests.jsx, GhOps.jsx, GhExtras.jsx, GhProfile.jsx.

Widget _panel(List<Widget> children, {EdgeInsets padding = const EdgeInsets.all(16)}) => Panel(
  padding: padding,
  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
);
String _x(GhCtx ctx, String k, [Map<String, Object?> v = const {}]) => ctx.t('gx.$k', v);

class Stars extends StatelessWidget {
  final num n;
  final double size;
  const Stars(this.n, {super.key, this.size = 15});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [for (var i = 1; i <= 5; i++) Icon(LucideIcons.star, size: size, color: i <= n ? const Color(0xFFF59E0B) : context.c.line)],
  );
}

// ------------------------------------------------------------------------------------------------ REVIEW LINK (inside a booking)
Future<void> openReviewShare(BuildContext context, GhCtx ctx, Json stay) => showSheet<void>(context, (_) => _ReviewShare(ctx: ctx, stay: stay));

class _ReviewShare extends StatefulWidget {
  final GhCtx ctx;
  final Json stay;
  const _ReviewShare({required this.ctx, required this.stay});
  @override
  State<_ReviewShare> createState() => _ReviewShareState();
}

class _ReviewShareState extends State<_ReviewShare> {
  Json? _d;
  String _error = '';
  GhCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    ctx.api
        .get('${ctx.base}/stays/${widget.stay['_id']}/review')
        .then((r) {
          if (mounted) setState(() => _d = obj(r['data']));
        })
        .catchError((Object e) {
          if (mounted) setState(() => _error = e is ApiError ? e.message : '$e');
        });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final guest = obj(widget.stay['guest']);
    final d = _d;
    final url = d == null ? '' : '${Config.siteUrl}${str(d['path'])}';
    final msg = _x(ctx, 'rvMsg', {'biz': str(ctx.business['name']), 'url': url});
    final phone = str(guest['phone']).replaceAll(RegExp(r'[^\d+]'), '').replaceFirst(RegExp(r'^0'), '855').replaceAll('+', '');
    return MSheet(
      title: _x(ctx, 'rvShareTitle', {'name': str(guest['name'])}),
      children: [
        if (_error.isNotEmpty)
          Alert(_error)
        else if (d == null)
          const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
        else ...[
          if (n(d['rating']) > 0) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.goodBg, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Stars(n(d['rating'])),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_x(ctx, 'rvGot', {'n': n(d['rating'])}))),
                ],
              ),
            ),
            gap14,
          ],
          Muted(_x(ctx, 'rvShareSub')),
          gap14,
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.line),
              ),
              child: QrImageView(data: url, size: 190),
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            url,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
          gap14,
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Btn(
                _x(ctx, 'rvCopy'),
                icon: LucideIcons.copy,
                kind: BtnKind.ghost,
                small: true,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  ctx.notify(_x(ctx, 'otCopied'));
                },
              ),
              Btn(
                _x(ctx, 'rvWhatsapp'),
                icon: LucideIcons.messageCircle,
                kind: BtnKind.ghost,
                small: true,
                onTap: () => launchUrl(Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(msg)}'), mode: LaunchMode.externalApplication),
              ),
              Btn(
                _x(ctx, 'rvTelegram'),
                icon: LucideIcons.send,
                kind: BtnKind.ghost,
                small: true,
                onTap: () => launchUrl(Uri.parse('https://t.me/share/url?url=${Uri.encodeComponent(url)}&text=${Uri.encodeComponent(msg.replaceAll(url, ''))}'), mode: LaunchMode.externalApplication),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ MEMBER BOX (inside a booking)
class MemberBox extends StatefulWidget {
  final GhCtx ctx;
  final Json stay;
  final bool busy;
  final void Function(Json stay) onStay;
  const MemberBox({super.key, required this.ctx, required this.stay, required this.onStay, this.busy = false});
  @override
  State<MemberBox> createState() => _MemberBoxState();
}

class _MemberBoxState extends State<MemberBox> {
  Json? _m;
  bool _finding = false, _working = false;
  List<Json> _hits = [];
  Timer? _wait;
  final _q = TextEditingController(), _use = TextEditingController();
  GhCtx get ctx => widget.ctx;
  Json get stay => widget.stay;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MemberBox old) {
    super.didUpdateWidget(old);
    if (old.stay['customer_id'] != stay['customer_id'] || old.stay['points_used'] != stay['points_used'] || old.stay['status'] != stay['status']) _load();
  }

  @override
  void dispose() {
    _wait?.cancel();
    _q.dispose();
    _use.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/stays/${stay['_id']}/member');
      if (mounted) setState(() => _m = obj(r['data']));
    } catch (_) {
      if (mounted) setState(() => _m = null);
    }
  }

  Future<void> _run(Future<Json> Function() fn) async {
    setState(() => _working = true);
    try {
      final r = await fn();
      final d = obj(r['data']);
      if (d['_id'] != null) widget.onStay(d);
      await _load();
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _finding = false;
          _use.clear();
        });
      }
    }
  }

  void _search(String q) {
    _wait?.cancel();
    if (q.trim().length < 2) return setState(() => _hits = []);
    _wait = Timer(const Duration(milliseconds: 300), () async {
      try {
        final r = await ctx.api.get('${ctx.base}/members', {'q': q});
        if (mounted) setState(() => _hits = objs(r['data']));
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final m = _m;
    if (m == null || m['on'] != true) return const SizedBox.shrink();
    final live = ['booked', 'in'].contains(stay['status']);
    final member = m['member'] == null ? null : obj(m['member']);
    final r = obj(m['rules']);
    final bill = obj(stay['bill']);
    num worth(num p) {
      final v = p / (n(r['redeem_points']) == 0 ? 1 : n(r['redeem_points'])) * n(r['redeem_value']);
      return ctx.cur == 'KHR' ? v.round() : (v * 100).round() / 100;
    }

    final maxUse = member == null
        ? 0
        : [
            n(member['points']),
            ((bill['balance'] as num? ?? 0).clamp(0, double.infinity) / (n(r['redeem_value']) == 0 ? 1 : n(r['redeem_value'])) * n(r['redeem_points'])).ceil(),
          ].reduce((a, b) => a < b ? a : b);
    final use = (int.tryParse(_use.text) ?? 0).clamp(0, maxUse.toInt());
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: .35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.gift, size: 18, color: Color(0xFFB45309)),
          const SizedBox(width: 10),
          Expanded(
            child: member != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(str(member['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(width: 6),
                          Chip2(_x(ctx, 'lyPoints', {'n': n(member['points'])}), tone: Tone.good),
                          if (live && n(m['used']) == 0 && !ctx.readOnly)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: _x(ctx, 'lyUnlink'),
                              onPressed: _working || widget.busy ? null : () => _run(() => ctx.api.put('${ctx.base}/stays/${stay['_id']}/customer', {'customer_id': null})),
                              icon: const Icon(LucideIcons.x, size: 15),
                            ),
                        ],
                      ),
                      if (n(m['used']) > 0)
                        Row(
                          children: [
                            Flexible(child: Text(_x(ctx, 'lyUsed2', {'p': n(m['used']), 'v': ctx.mo(m['value'])}), style: const TextStyle(fontSize: 12.5))),
                            if (live && !ctx.readOnly)
                              TextButton.icon(
                                onPressed: _working ? null : () => _run(() => ctx.api.delete('${ctx.base}/stays/${stay['_id']}/points')),
                                icon: const Icon(LucideIcons.undo2, size: 13),
                                label: Text(_x(ctx, 'lyUndo')),
                              ),
                          ],
                        ),
                      if (n(m['given']) > 0) Muted(_x(ctx, 'lyGiven', {'p': n(m['given'])})),
                      if (live && n(m['given']) == 0 && n(bill['total']) > 0) Muted(_x(ctx, 'lyWillEarn', {'p': (n(bill['total']) / (n(r['unit']) == 0 ? 1 : n(r['unit'])) * n(r['earn'])).floor()})),
                      if (live && !ctx.readOnly && maxUse > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            SizedBox(
                              width: 90,
                              child: Field(controller: _use, hint: '$maxUse', keyboard: TextInputType.number, onChanged: (_) => setState(() {})),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Btn(
                                use > 0 ? _x(ctx, 'lyUseBtn', {'p': use, 'v': ctx.mo(worth(use))}) : _x(ctx, 'lyUse'),
                                small: true,
                                busy: _working,
                                onTap: _working || widget.busy || use == 0 ? null : () => _run(() => ctx.api.post('${ctx.base}/stays/${stay['_id']}/points', {'points': use})),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  )
                : _finding
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Field(
                        controller: _q,
                        hint: _x(ctx, 'lyFind'),
                        icon: LucideIcons.search,
                        autofocus: true,
                        onChanged: _search,
                        suffix: IconButton(onPressed: () => setState(() => _finding = false), icon: const Icon(LucideIcons.x, size: 16)),
                      ),
                      for (final h in _hits)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(LucideIcons.userRound, size: 16),
                          title: Text(str(h['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text([str(h['phone']), str(h['email'])].where((x) => x.isNotEmpty).join(' · ')),
                          trailing: Chip2(_x(ctx, 'lyPoints', {'n': n(h['points'])})),
                          onTap: _working ? null : () => _run(() => ctx.api.put('${ctx.base}/stays/${stay['_id']}/customer', {'customer_id': h['_id']})),
                        ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(_x(ctx, 'lyMember'), style: TextStyle(color: c.muted)),
                      ),
                      if (live && !ctx.readOnly)
                        TextButton.icon(
                          onPressed: () {
                            _q.text = str(obj(stay['guest'])['phone']);
                            setState(() => _finding = true);
                            _search(_q.text);
                          },
                          icon: const Icon(LucideIcons.link2, size: 14),
                          label: Text(_x(ctx, 'lyLink')),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ REVIEWS
class ReviewsTab extends StatefulWidget {
  final GhCtx ctx;
  const ReviewsTab({super.key, required this.ctx});
  @override
  State<ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<ReviewsTab> {
  Json? _d;
  String _replying = '';
  final _reply = TextEditingController();
  GhCtx get ctx => widget.ctx;
  bool get _on => ctx.addonOn('gh_reviews');

  @override
  void initState() {
    super.initState();
    if (_on) _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/reviews');
      if (mounted) setState(() => _d = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _save(Object? id, Json body) async {
    if (await ctx.run(() => ctx.api.put('${ctx.base}/reviews/$id', body)) != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a = ctx.addon('gh_reviews');
    final hero = GhHero(ctx: ctx, addon: 'gh_reviews', yearly: true, icon: LucideIcons.star, title: _x(ctx, 'rvTitle'), sub: _on ? _x(ctx, 'rvSub') : _x(ctx, 'rvOff', {'price': fmt(n(a['price']))}));
    if (!_on) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          hero,
          mGap,
          GhPerks(ctx: ctx, addon: 'gh_reviews'),
        ],
      );
    }
    final d = _d;
    if (d == null) return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [hero, mGap, const SkelList(rows: 4)]);
    final count = n(d['count']);
    final stars = obj(d['stars']);
    final items = objs(d['items']);
    final waiting = objs(d['waiting']);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          hero,
          mGap,
          _panel([
            Row(
              children: [
                Column(
                  children: [
                    Text(count > 0 ? n(d['avg']).toStringAsFixed(1) : '—', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
                    Stars(n(d['avg']).round(), size: 17),
                    const SizedBox(height: 2),
                    Muted(_x(ctx, 'rvCount', {'n': count})),
                  ],
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    children: [
                      for (final k in [5, 4, 3, 2, 1])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 22,
                                child: Text('$k★', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(99),
                                  child: LinearProgressIndicator(value: count == 0 ? 0 : n(stars['$k']) / count, minHeight: 7, color: const Color(0xFFF59E0B), backgroundColor: c.bg2),
                                ),
                              ),
                              SizedBox(
                                width: 26,
                                child: Text(
                                  '${n(stars['$k'])}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 12, color: c.muted),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SwitchRow(
              title: _x(ctx, 'rvAuto'),
              value: d['auto'] == true,
              onChanged: ctx.readOnly
                  ? null
                  : (v) async {
                      await ctx.run(() => ctx.api.put('${ctx.base}/reviews-settings', {'reviews_auto': v}));
                      _load();
                    },
            ),
          ]),
          mGap,
          if (items.isEmpty)
            _panel([Icon(LucideIcons.star, size: 40, color: c.muted), const SizedBox(height: 8), Muted(_x(ctx, 'rvNone'), align: TextAlign.center)])
          else
            for (final r in items) ...[
              _panel([
                Row(
                  children: [
                    Stars(n(r['rating'])),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(str(r['guest_name']).isEmpty ? '—' : str(r['guest_name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    Chip2(r['shown'] == true ? _x(ctx, 'rvShown') : _x(ctx, 'rvHidden'), tone: r['shown'] == true ? Tone.good : Tone.muted),
                  ],
                ),
                const SizedBox(height: 2),
                Muted('${str(r['room_name'])} · ${ghDay(str(r['from']), ctx.lang)} → ${ghDay(str(r['to']), ctx.lang)} · ${mDayTime(r['submitted_at'], ctx.lang)}'),
                if (str(r['text']).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('“${str(r['text'])}”', style: const TextStyle(height: 1.4)),
                  ),
                if (_replying == r['_id']) ...[
                  const SizedBox(height: 8),
                  Field(controller: _reply, hint: _x(ctx, 'rvReplyPh'), maxLength: 500, maxLines: 3, autofocus: true),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Btn(ctx.g('cancel'), kind: BtnKind.ghost, small: true, onTap: () => setState(() => _replying = '')),
                      const Spacer(),
                      Btn(
                        _x(ctx, 'save'),
                        small: true,
                        onTap: () async {
                          await _save(r['_id'], {'reply': _reply.text.trim()});
                          if (mounted) setState(() => _replying = '');
                        },
                      ),
                    ],
                  ),
                ] else if (str(r['reply']).isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: c.bg2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border(left: BorderSide(color: c.brand, width: 3)),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${_x(ctx, 'rvReply')}: ',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          TextSpan(text: str(r['reply'])),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Btn(
                      r['shown'] == true ? _x(ctx, 'rvHide') : _x(ctx, 'rvShow'),
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: ctx.readOnly ? null : () => _save(r['_id'], {'shown': r['shown'] != true}),
                    ),
                    Btn(
                      _x(ctx, 'rvReply'),
                      icon: LucideIcons.messageCircle,
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: ctx.readOnly
                          ? null
                          : () => setState(() {
                              _replying = str(r['_id']);
                              _reply.text = str(r['reply']);
                            }),
                    ),
                    if (!ctx.readOnly)
                      SureDelete(
                        remove: _x(ctx, 'rvDel'),
                        sure: ctx.g('sure'),
                        onDelete: () async {
                          await ctx.run(() => ctx.api.delete('${ctx.base}/reviews/${r['_id']}'));
                          _load();
                        },
                      ),
                  ],
                ),
              ]),
              mGap,
            ],
          if (waiting.isNotEmpty)
            _panel([
              Text('${_x(ctx, 'rvWaiting')} (${waiting.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              const SizedBox(height: 6),
              for (final w in waiting)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(str(w['guest_name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                            Muted('${str(w['room_name'])} · ${ghDay(str(w['from']), ctx.lang)} → ${ghDay(str(w['to']), ctx.lang)}'),
                          ],
                        ),
                      ),
                      Btn(
                        _x(ctx, 'rvCopy'),
                        icon: LucideIcons.copy,
                        kind: BtnKind.ghost,
                        small: true,
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: '${Config.siteUrl}/r/${w['token']}'));
                          ctx.notify(_x(ctx, 'otCopied'));
                        },
                      ),
                    ],
                  ),
                ),
            ]),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ LOYALTY
class LoyaltyTab extends StatefulWidget {
  final GhCtx ctx;
  const LoyaltyTab({super.key, required this.ctx});
  @override
  State<LoyaltyTab> createState() => _LoyaltyTabState();
}

class _LoyaltyTabState extends State<LoyaltyTab> {
  Json? _d;
  final _earn = TextEditingController(), _rp = TextEditingController(), _rv = TextEditingController();
  bool _busy = false;
  GhCtx get ctx => widget.ctx;
  bool get _on => ctx.addonOn('gh_loyalty');

  @override
  void initState() {
    super.initState();
    if (_on) _load();
  }

  @override
  void dispose() {
    _earn.dispose();
    _rp.dispose();
    _rv.dispose();
    super.dispose();
  }

  String _num(Object? v) => '${n(v)}'.replaceFirst(RegExp(r'\.0$'), '');

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/loyalty');
      if (!mounted) return;
      final d = obj(r['data']);
      final rules = obj(d['rules']);
      setState(() {
        _d = d;
        _earn.text = _num(rules['earn']);
        _rp.text = _num(rules['redeem_points']);
        _rv.text = _num(rules['redeem_value']);
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _saveRules() async {
    setState(() => _busy = true);
    if (await ctx.run(() => ctx.api.put('${ctx.base}/loyalty', {'earn': numOf(_earn.text) ?? 0, 'redeem_points': numOf(_rp.text) ?? 1, 'redeem_value': numOf(_rv.text) ?? 0}), _x(ctx, 'saved')) !=
        null) {
      await _load();
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a = ctx.addon('gh_loyalty');
    final hero = GhHero(ctx: ctx, addon: 'gh_loyalty', yearly: true, icon: LucideIcons.gift, title: _x(ctx, 'lyTitle'), sub: _on ? _x(ctx, 'lySub') : _x(ctx, 'lyOff', {'price': fmt(n(a['price']))}));
    if (!_on) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          hero,
          mGap,
          GhPerks(ctx: ctx, addon: 'gh_loyalty'),
        ],
      );
    }
    final d = _d;
    if (d == null) return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [hero, mGap, const SkelList(rows: 4)]);
    final rules = obj(d['rules']);
    final totals = obj(d['totals']);
    final km = ctx.cur == 'KHR';
    final ex = km ? 200000 : 50;
    final dirty = numOf(_earn.text) != n(rules['earn']) || numOf(_rp.text) != n(rules['redeem_points']) || numOf(_rv.text) != n(rules['redeem_value']);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          hero,
          mGap,
          Tiles([('${n(totals['earned'])}', _x(ctx, 'lyEarned'), null), ('${n(totals['used'])}', _x(ctx, 'lyUsed'), null), ('${n(totals['open'])}', _x(ctx, 'lyOpen'), c.good)]),
          mGap,
          _panel([
            Text(_x(ctx, 'lyRules'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            gap14,
            Field(label: _x(ctx, 'lyEarn', {'unit': km ? '4,000៛' : '\$1'}), controller: _earn, keyboard: decimalKeys, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
            gap14,
            Label(_x(ctx, 'lyRedeem', {'p': _rp.text.isEmpty ? '…' : _rp.text})),
            Row(
              children: [
                Expanded(
                  child: Field(controller: _rp, keyboard: TextInputType.number, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('=', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                ),
                Expanded(
                  child: Field(controller: _rv, keyboard: decimalKeys, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Muted(_x(ctx, 'lyExample', {'amt': ctx.mo(ex), 'p': (ex / (km ? 4000 : 1) * (numOf(_earn.text) ?? 0)).floor(), 'rp': _rp.text, 'rv': ctx.mo(numOf(_rv.text) ?? 0)})),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Btn(_x(ctx, 'save'), small: true, busy: _busy, onTap: ctx.readOnly || !dirty || _busy ? null : _saveRules),
            ),
          ]),
          mGap,
          _panel([
            Text(_x(ctx, 'lyMembers'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            const SizedBox(height: 4),
            if (objs(d['members']).isEmpty) Muted(_x(ctx, 'lyNone')),
            for (final m in objs(d['members']))
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                title: Text(str(m['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(str(m['phone'])),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip2(_x(ctx, 'lyPoints', {'n': n(m['points'])}), tone: Tone.good),
                    IconButton(
                      tooltip: _x(ctx, 'lyAdjust'),
                      onPressed: ctx.readOnly
                          ? null
                          : () async {
                              final ok = await showSheet<bool>(context, (_) => _AdjustSheet(ctx: ctx, member: m));
                              if (ok == true) _load();
                            },
                      icon: const Text('±', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    ),
                  ],
                ),
              ),
          ]),
          mGap,
          _panel([
            Text(_x(ctx, 'lyHistory'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            const SizedBox(height: 4),
            if (objs(d['recent']).isEmpty) const Muted('—'),
            for (final x in objs(d['recent']))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(str(x['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                          Muted([ctx.t.or('gx.lyKinds.${x['kind']}', str(x['kind'])), str(x['note']), mDayTime(x['created_date'], ctx.lang)].where((s) => s.isNotEmpty).join(' · ')),
                        ],
                      ),
                    ),
                    Text(
                      '${n(x['points']) > 0 ? '+' : ''}${n(x['points'])}',
                      style: TextStyle(fontWeight: FontWeight.w800, color: n(x['points']) < 0 ? c.danger : c.good),
                    ),
                  ],
                ),
              ),
          ]),
        ],
      ),
    );
  }
}

class _AdjustSheet extends StatefulWidget {
  final GhCtx ctx;
  final Json member;
  const _AdjustSheet({required this.ctx, required this.member});
  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> with GhSave {
  GhCtx get ctx => widget.ctx;
  @override
  GhCtx get gctx => ctx;
  final _points = TextEditingController(), _note = TextEditingController();

  @override
  void dispose() {
    _points.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = int.tryParse(_points.text.replaceAll('+', '').trim()) ?? 0;
    return MSheet(
      title: '${_x(ctx, 'lyAdjust')} · ${str(widget.member['name'])}',
      footer: footer(canSave: p != 0, onSave: () => save(() => ctx.api.post('${ctx.base}/customers/${widget.member['_id']}/points', {'points': p, 'note': _note.text.trim()}), reload: false)),
      children: [
        Muted(_x(ctx, 'lyPoints', {'n': n(widget.member['points'])})),
        gap14,
        Field(
          label: '± ${_x(ctx, 'lyPoints', {'n': ''}).trim()}',
          controller: _points,
          hint: '+100 / -50',
          keyboard: const TextInputType.numberWithOptions(signed: true),
          autofocus: true,
          onChanged: (_) => setState(() {}),
        ),
        gap14,
        Field(label: _x(ctx, 'lyAdjustNote'), controller: _note, maxLength: 200),
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ EXPENSES & PROFIT
const _catIcon = {
  'salary': '👥',
  'electricity': '⚡',
  'water': '💧',
  'internet': '📶',
  'supplies': '🧴',
  'laundry': '🧺',
  'repair': '🔧',
  'food': '🍽️',
  'rent': '🏠',
  'tax': '🧾',
  'marketing': '📣',
  'commission': '🌐',
  'other': '📦',
};
const _cats = ['salary', 'electricity', 'water', 'internet', 'supplies', 'laundry', 'repair', 'food', 'rent', 'tax', 'marketing', 'commission', 'other'];
const _monShortEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monShortKm = ['មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា', 'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ'];

class ExpensesTab extends StatefulWidget {
  final GhCtx ctx;
  const ExpensesTab({super.key, required this.ctx});
  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  final _now = todayKH().substring(0, 7);
  late String _month = _now;
  Json? _ex, _pf;
  GhCtx get ctx => widget.ctx;
  bool get _on => ctx.addonOn('gh_expenses');

  @override
  void initState() {
    super.initState();
    if (_on) _load();
  }

  Future<void> _load() async {
    final m = _month;
    try {
      final r = await Future.wait([
        ctx.api.get('${ctx.base}/expenses', {'month': m}),
        ctx.api.get('${ctx.base}/profit', {'month': m}),
      ]);
      if (!mounted || m != _month) return;
      setState(() {
        _ex = obj(r[0]['data']);
        _pf = obj(r[1]['data']);
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  void _go(int by) {
    setState(() {
      _month = shiftMonth(_month, by);
      _ex = null;
      _pf = null;
    });
    _load();
  }

  Future<void> _edit(Json? row) async {
    final cats = (_ex?['categories'] as List?)?.map((e) => '$e').toList() ?? _cats;
    final ok = await showSheet<bool>(context, (_) => _ExpenseSheet(ctx: ctx, row: row, cats: cats));
    if (ok == true) _load();
  }

  String _signed(num v) => v < 0 ? '−${ctx.mo(-v)}' : ctx.mo(v);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a = ctx.addon('gh_expenses');
    final hero = GhHero(
      ctx: ctx,
      addon: 'gh_expenses',
      icon: LucideIcons.wallet,
      title: _x(ctx, 'exTitle'),
      sub: _on ? _x(ctx, 'exSub') : _x(ctx, 'exOff', {'price': fmt(n(a['price']))}),
      extra: _on ? Btn(_x(ctx, 'exAdd'), icon: LucideIcons.plus, small: true, onTap: ctx.readOnly ? null : () => _edit(null)) : null,
    );
    if (!_on) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          hero,
          mGap,
          GhPerks(ctx: ctx, addon: 'gh_expenses'),
        ],
      );
    }
    final ex = _ex, pf = _pf;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          hero,
          mGap,
          _panel([
            Row(
              children: [
                IconButton(onPressed: () => _go(-1), icon: const Icon(LucideIcons.chevronLeft, size: 18)),
                Expanded(
                  child: Text(
                    _month == _now ? _x(ctx, 'thisMonth') : ghMonth(_month, ctx.lang),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(onPressed: _month.compareTo(_now) >= 0 ? null : () => _go(1), icon: const Icon(LucideIcons.chevronRight, size: 18)),
              ],
            ),
            if (pf != null) ...[
              const SizedBox(height: 8),
              Tiles([
                (ctx.mo(pf['income']), _x(ctx, 'exIncome'), null),
                (ctx.mo(pf['expenses']), _x(ctx, 'exOut'), c.danger),
                (_signed(n(pf['profit'])), '${_x(ctx, 'exProfit')}${n(pf['income']) > 0 ? ' · ${_x(ctx, 'exMargin', {'n': n(pf['margin'])})}' : ''}', n(pf['profit']) >= 0 ? c.good : c.danger),
              ]),
            ],
          ]),
          mGap,
          if (ex == null || pf == null)
            const SkelList(rows: 4)
          else ...[
            _panel([
              Text(_x(ctx, 'exMonths'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              const SizedBox(height: 12),
              () {
                final series = objs(pf['series']);
                final max = series.fold<num>(1, (m, s) => [m, n(s['income']), n(s['expenses'])].reduce((a, b) => a > b ? a : b));
                return SizedBox(
                  height: 170,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final s in series)
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    for (final (k, col) in [('income', c.brand), ('expenses', c.danger)])
                                      Container(
                                        width: 10,
                                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                        child: FractionallySizedBox(
                                          heightFactor: ((n(s[k]) / max).clamp(.02, 1)).toDouble(),
                                          alignment: Alignment.bottomCenter,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: col,
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                child: Text(
                                  _signed(n(s['profit'])),
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: n(s['profit']) < 0 ? c.danger : c.ink),
                                ),
                              ),
                              Text((ctx.lang == 'km' ? _monShortKm : _monShortEn)[int.parse(str(s['month']).substring(5, 7)) - 1], style: TextStyle(fontSize: 10.5, color: c.muted)),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              }(),
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                children: [
                  for (final (k, col) in [('exIncome', c.brand), ('exOut', c.danger)])
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(3)),
                        ),
                        const SizedBox(width: 6),
                        Text(_x(ctx, k), style: TextStyle(fontSize: 12.5, color: c.muted)),
                      ],
                    ),
                ],
              ),
            ]),
            mGap,
            _panel([
              Text(_x(ctx, 'exByCat'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              const SizedBox(height: 4),
              () {
                final by = obj(ex['by_category']).entries.toList()..sort((x, y) => n(y.value).compareTo(n(x.value)));
                final top = by.isEmpty ? 1 : n(by.first.value);
                return Column(
                  children: [
                    if (by.isEmpty) const Muted('—'),
                    for (final e in by)
                      BarRow(
                        lead: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(_catIcon[e.key] ?? '📦', style: const TextStyle(fontSize: 18)),
                        ),
                        label: _x(ctx, 'cats.${e.key}'),
                        value: ctx.mo(e.value),
                        pct: top == 0 ? 0 : n(e.value) / top * 100,
                      ),
                  ],
                );
              }(),
            ]),
            mGap,
            _panel([
              Text('${_x(ctx, 'exOut')} · ${ctx.mo(ex['total'])}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              const SizedBox(height: 4),
              if (objs(ex['rows']).isEmpty) Muted(_x(ctx, 'exNone')),
              for (final x in objs(ex['rows']))
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: ctx.readOnly ? null : () => _edit(x),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(12)),
                          child: Text(_catIcon[str(x['category'])] ?? '📦', style: const TextStyle(fontSize: 18)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_x(ctx, 'cats.${x['category']}'), style: const TextStyle(fontWeight: FontWeight.w700)),
                              Muted(
                                [
                                  ghDay(str(x['day']), ctx.lang, weekday: true),
                                  ctx.t.or('gx.exMethods.${x['method']}', str(x['method'])),
                                  str(x['note']),
                                  str(x['by']),
                                ].where((s) => s.isNotEmpty).join(' · '),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '−${ctx.mo(x['amount'])}',
                          style: TextStyle(fontWeight: FontWeight.w800, color: c.danger),
                        ),
                      ],
                    ),
                  ),
                ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _ExpenseSheet extends StatefulWidget {
  final GhCtx ctx;
  final Json? row;
  final List<String> cats;
  const _ExpenseSheet({required this.ctx, this.row, required this.cats});
  @override
  State<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<_ExpenseSheet> with GhSave {
  GhCtx get ctx => widget.ctx;
  @override
  GhCtx get gctx => ctx;
  late String _day = str(widget.row?['day']).isEmpty ? todayKH() : str(widget.row?['day']);
  late String _cat = str(widget.row?['category']).isEmpty ? 'supplies' : str(widget.row?['category']);
  late String _method = str(widget.row?['method']).isEmpty ? 'cash' : str(widget.row?['method']);
  late final _amount = TextEditingController(text: widget.row == null ? '' : '${n(widget.row!['amount'])}'.replaceFirst(RegExp(r'\.0$'), ''));
  late final _note = TextEditingController(text: str(widget.row?['note']));

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final body = {'day': _day, 'category': _cat, 'amount': numOf(_amount.text) ?? 0, 'method': _method, 'note': _note.text.trim()};
    final path = '${ctx.base}/expenses';
    return MSheet(
      title: row == null ? _x(ctx, 'exAdd') : _x(ctx, 'exEdit'),
      footer: footer(
        canSave: (numOf(_amount.text) ?? 0) > 0,
        onSave: () => save(() => row == null ? ctx.api.post(path, body) : ctx.api.put('$path/${row['_id']}', body), reload: false),
        onRemove: row == null ? null : () => save(() => ctx.api.delete('$path/${row['_id']}'), reload: false),
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Field(
                label: '${_x(ctx, 'exAmount')} *',
                controller: _amount,
                hint: ctx.cur == 'KHR' ? '40000' : '25',
                keyboard: decimalKeys,
                autofocus: row == null,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DayField(label: _x(ctx, 'exDay'), value: _day, last: DateTime.parse(todayKH()), onChanged: (v) => v.isEmpty ? null : setState(() => _day = v)),
            ),
          ],
        ),
        gap14,
        Label(_x(ctx, 'exCat')),
        Chips<String>(options: [for (final k in widget.cats) (k, '${_catIcon[k] ?? '📦'} ${_x(ctx, 'cats.$k')}')], on: (k) => _cat == k, onTap: (k) => setState(() => _cat = k)),
        gap14,
        Label(_x(ctx, 'exMethod')),
        Segmented<String>(
          value: _method,
          options: [
            for (final k in ['cash', 'bank']) (k, _x(ctx, 'exMethods.$k')),
          ],
          onChanged: (v) => setState(() => _method = v),
        ),
        gap14,
        Field(label: _x(ctx, 'exNote'), hint: _x(ctx, 'exNotePh'), controller: _note, maxLength: 200),
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ EXTRA SERVICES
class ServicesTab extends StatefulWidget {
  final GhCtx ctx;
  const ServicesTab({super.key, required this.ctx});
  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _SvcRow {
  final TextEditingController name, price;
  String icon;
  bool active;
  final Object? id;
  _SvcRow({required String n, required String p, required this.icon, required this.active, this.id}) : name = TextEditingController(text: n), price = TextEditingController(text: p);
  Json get body => {if (id != null) '_id': id, 'name': name.text.trim(), 'price': numOf(price.text) ?? 0, 'icon': icon, 'active': active};
  void dispose() {
    name.dispose();
    price.dispose();
  }
}

class _ServicesTabState extends State<ServicesTab> {
  Json? _info, _rep;
  List<_SvcRow>? _list;
  String _saved = '', _period = 'this';
  bool _busy = false;
  GhCtx get ctx => widget.ctx;
  bool get _on => ctx.addonOn('gh_services');

  @override
  void initState() {
    super.initState();
    _load();
    if (_on) _loadRep();
  }

  @override
  void dispose() {
    for (final r in _list ?? <_SvcRow>[]) {
      r.dispose();
    }
    super.dispose();
  }

  String _num(Object? v) => '${n(v)}'.replaceFirst(RegExp(r'\.0$'), '');
  String get _now => _list == null ? '' : _list!.map((r) => r.body.toString()).join('|');

  void _fill(List<Json> list) {
    for (final r in _list ?? <_SvcRow>[]) {
      r.dispose();
    }
    _list = [for (final x in list) _SvcRow(n: str(x['name']), p: _num(x['price']), icon: str(x['icon']).isEmpty ? 'other' : str(x['icon']), active: x['active'] != false, id: x['_id'])];
    _saved = _now;
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/services');
      if (!mounted) return;
      setState(() {
        _info = obj(r['data']);
        _fill(objs(_info!['list']));
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _loadRep() async {
    final today = todayKH();
    final first = '${today.substring(0, 7)}-01';
    final lastEnd = DateTime.parse('${first}T00:00:00Z').subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
    final range = _period == 'this' ? {'from': first, 'to': today} : {'from': '${lastEnd.substring(0, 7)}-01', 'to': lastEnd};
    setState(() => _rep = null);
    try {
      final r = await ctx.api.get('${ctx.base}/services/report', range);
      if (mounted) setState(() => _rep = obj(r['data']));
    } catch (_) {
      if (mounted) setState(() => _rep = {'items': [], 'total': 0, 'qty': 0});
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final r = await ctx.api.put('${ctx.base}/services', {
        'list': [for (final x in _list!) x.body],
      });
      if (mounted) setState(() => _fill(objs(obj(r['data'])['list'])));
      ctx.notify(_x(ctx, 'saved'));
      ctx.reload();
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a = ctx.addon('gh_services');
    final hero = GhHero(ctx: ctx, addon: 'gh_services', icon: LucideIcons.conciergeBell, title: _x(ctx, 'svTitle'), sub: _on ? _x(ctx, 'svSub') : _x(ctx, 'svOff', {'price': fmt(n(a['price']))}));
    final examples = (ctx.t.raw('gx.examples') as List? ?? const []).whereType<List>().toList();
    final info = _info, list = _list;
    if (info == null || list == null) return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [hero, mGap, const SkelList(rows: 4)]);
    if (!_on) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          hero,
          mGap,
          GhPerks(ctx: ctx, addon: 'gh_services'),
          mGap,
          _panel([
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in examples)
                  Container(
                    width: 96,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      children: [
                        Text(svcEmoji['${e[2]}'] ?? '✨', style: const TextStyle(fontSize: 20)),
                        Text(
                          '${e[0]}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                        Text(ctx.mo(e[1]), style: TextStyle(color: c.muted, fontSize: 11.5)),
                      ],
                    ),
                  ),
              ],
            ),
          ]),
        ],
      );
    }
    final icons = (info['icons'] as List? ?? svcEmoji.keys.toList()).map((e) => '$e').toList();
    final dirty = _now != _saved;
    final bad = list.any((x) => x.name.text.trim().isEmpty || x.price.text.trim().isEmpty);
    final rep = _rep;
    return RefreshIndicator(
      onRefresh: () async {
        await _load();
        await _loadRep();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          hero,
          mGap,
          _panel([
            if (list.isEmpty) ...[
              Icon(LucideIcons.conciergeBell, size: 40, color: c.muted),
              const SizedBox(height: 8),
              Muted(_x(ctx, 'svNone'), align: TextAlign.center),
              const SizedBox(height: 10),
              Center(
                child: Btn(
                  _x(ctx, 'svExamples'),
                  icon: LucideIcons.plus,
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: ctx.readOnly
                      ? null
                      : () => setState(() {
                          _list = [for (final e in examples) _SvcRow(n: '${e[0]}', p: _num(e[1]), icon: '${e[2]}', active: true)];
                        }),
                ),
              ),
            ],
            for (final (i, x) in list.indexed)
              Opacity(
                opacity: x.active ? 1 : .55,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      PopupMenuButton<String>(
                        enabled: !ctx.readOnly,
                        tooltip: _x(ctx, 'svIcon'),
                        onSelected: (k) => setState(() => x.icon = k),
                        itemBuilder: (_) => [for (final k in icons) PopupMenuItem(value: k, child: Text('${svcEmoji[k] ?? '✨'}  ${ctx.t.or('gx.icons.$k', k)}'))],
                        child: Container(
                          width: 46,
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
                          child: Text(svcEmoji[x.icon] ?? '✨', style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 3,
                        child: Field(controller: x.name, hint: _x(ctx, 'svNamePh'), maxLength: 60, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: Field(controller: x.price, hint: _x(ctx, 'svPrice'), keyboard: decimalKeys, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
                      ),
                      Switch.adaptive(value: x.active, onChanged: ctx.readOnly ? null : (v) => setState(() => x.active = v)),
                      if (!ctx.readOnly)
                        InkWell(
                          onTap: () => setState(() => list.removeAt(i).dispose()),
                          child: Icon(LucideIcons.trash2, size: 16, color: c.muted),
                        ),
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                Btn(
                  _x(ctx, 'svAdd'),
                  icon: LucideIcons.plus,
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: ctx.readOnly || list.length >= 40 ? null : () => setState(() => list.add(_SvcRow(n: '', p: '', icon: 'other', active: true))),
                ),
                const Spacer(),
                if (dirty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      _x(ctx, 'svUnsaved'),
                      style: TextStyle(color: c.warn, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                Btn(_x(ctx, 'save'), small: true, busy: _busy, onTap: ctx.readOnly || _busy || !dirty || bad ? null : _save),
              ],
            ),
          ]),
          mGap,
          _panel([
            Text(_x(ctx, 'svReport'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            const SizedBox(height: 8),
            Segmented<String>(
              value: _period,
              options: [('this', _x(ctx, 'svThisMonth')), ('last', _x(ctx, 'svLastMonth'))],
              onChanged: (v) {
                _period = v;
                _loadRep();
              },
            ),
            const SizedBox(height: 8),
            if (rep == null)
              const SkelList(rows: 3)
            else if (objs(rep['items']).isEmpty)
              Muted(_x(ctx, 'svNoSales'))
            else ...[
              for (final x in objs(rep['items']))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text('${svcEmoji[str(x['icon'])] ?? '✨'}  '),
                      Expanded(child: Text('${str(x['name'])}  × ${n(x['qty'])}')),
                      Text(ctx.mo(x['total']), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              Divider(color: c.line),
              Row(
                children: [
                  Expanded(
                    child: Text('${_x(ctx, 'svQty')}: ${n(rep['qty'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Text(ctx.mo(rep['total']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
            ],
          ]),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ TELEGRAM
const _flags = ['new_booking', 'check_in', 'check_out', 'payment'];

class TelegramTab extends StatefulWidget {
  final GhCtx ctx;
  const TelegramTab({super.key, required this.ctx});
  @override
  State<TelegramTab> createState() => _TelegramTabState();
}

class _TelegramTabState extends State<TelegramTab> {
  Json? _status, _form, _link;
  String _busy = '';
  bool _slow = false;
  Timer? _timer;
  GhCtx get ctx => widget.ctx;
  bool get _on => ctx.addonOn('gh_telegram');

  @override
  void initState() {
    super.initState();
    if (_on) _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<Json?> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/telegram');
      final s = obj(r['data']);
      if (mounted) {
        setState(() {
          _status = s;
          _form ??= {'daily_report': s['daily_report'] == true, 'report_time': str(s['report_time']).isEmpty ? '21:00' : str(s['report_time']), for (final k in _flags) k: s[k] == true};
        });
      }
      return s;
    } catch (e) {
      ctx.fail(e);
      return null;
    }
  }

  Future<void> _connect() async {
    setState(() => _busy = 'link');
    try {
      final r = await ctx.api.post('${ctx.base}/telegram/link');
      final link = obj(r['data']);
      final started = DateTime.now();
      setState(() {
        _link = link;
        _slow = false;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 2500), (t) async {
        final exp = DateTime.tryParse(str(link['expires_at']));
        if (exp != null && DateTime.now().isAfter(exp)) {
          t.cancel();
          if (mounted) setState(() => _link = null);
          return;
        }
        if (DateTime.now().difference(started).inSeconds > 45 && mounted) setState(() => _slow = true);
        final s = await _load();
        if (s?['connected'] == true) {
          t.cancel();
          if (mounted) setState(() => _link = null);
          ctx.notify(_x(ctx, 'connectedTo', {'name': s!['chat_name']}));
        }
      });
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Future<void> _run(String key, Future<Json> Function() fn, String ok) async {
    setState(() => _busy = key);
    try {
      final r = await fn();
      final d = obj(r['data']);
      if (d.isNotEmpty && mounted) setState(() => _status = d);
      ctx.notify(ok);
    } on ApiError catch (e) {
      ctx.fail(e);
      if (e.status == 410) _load();
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Widget _sample(BuildContext context) {
    String s(String k) => _x(ctx, 'sample.$k');
    Widget bubble(List<String> lines, String time) => Container(
      margin: const EdgeInsets.only(bottom: 8, right: 30),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lines.first,
            style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
          ),
          for (final l in lines.skip(1)) Text(l, style: const TextStyle(color: Colors.black87, fontSize: 13)),
          Align(
            alignment: Alignment.centerRight,
            child: Text(time, style: const TextStyle(color: Colors.black38, fontSize: 11)),
          ),
        ],
      ),
    );
    final biz = str(ctx.business['name']);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFC8DDE9), borderRadius: BorderRadius.circular(18)),
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
                style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
              ),
              const SizedBox(width: 6),
              Text('bot', style: TextStyle(color: Colors.black.withValues(alpha: .45), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          bubble(['🛎 ${s('booking')}', '🏠 $biz', '👤 ${s('guest')}', '🛏 ${s('room')}', '📅 ${s('dates')}', '💳 ${s('pay')}'], '14:32'),
          bubble([
            '📊 ${s('summary')}',
            '🏠 $biz',
            '🛏 ${s('inHouse')}',
            '🟢 ${s('ins')}',
            '🔴 ${s('outs')}',
            '💵 ${s('money')}',
          ], str(_form?['report_time']).isEmpty ? '21:00' : str(_form?['report_time'])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a = ctx.addon('gh_telegram');
    final hero = GhHero(
      ctx: ctx,
      addon: 'gh_telegram',
      yearly: true,
      icon: LucideIcons.send,
      title: ctx.g('addonInfo.gh_telegram.name'),
      sub: _on ? _x(ctx, 'tgOn', {'date': mDate(a['expires_at'], ctx.lang)}) : _x(ctx, 'tgOff', {'price': fmt(n(a['price']))}),
    );
    if (!_on) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          hero,
          mGap,
          _panel([
            Muted(_x(ctx, 'tgSub')),
            const SizedBox(height: 10),
            for (final p in ctx.t.list('gh.addonInfo.gh_telegram.perks'))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(LucideIcons.circleCheck, size: 15, color: c.good),
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
    if (s == null || f == null) return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [hero, mGap, const SkelList(rows: 3)]);
    final dirty = ['daily_report', 'report_time', ..._flags].any((k) => f[k] != (k == 'report_time' ? (str(s[k]).isEmpty ? '21:00' : str(s[k])) : s[k] == true));
    final link = _link;
    return RefreshIndicator(
      onRefresh: () async => _load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          hero,
          mGap,
          if (s['configured'] == false) ...[Alert(_x(ctx, 'notConfigured'), tone: Tone.warn), mGap],
          if (s['connected'] == true)
            _panel([
              Row(
                children: [
                  Icon(LucideIcons.circleCheck, size: 26, color: c.good),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Muted(_x(ctx, 'connectedLabel')),
                        Text('${s['chat_type'] != 'private' ? '👥 ' : ''}${str(s['chat_name'])}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        Muted(_x(ctx, 'since', {'date': mDate(s['connected_at'], ctx.lang)})),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Btn(
                    _x(ctx, 'sendTest'),
                    icon: LucideIcons.bellRing,
                    kind: BtnKind.ghost,
                    small: true,
                    busy: _busy == 'test',
                    onTap: ctx.readOnly || _busy.isNotEmpty ? null : () => _run('test', () => ctx.api.post('${ctx.base}/telegram/test'), _x(ctx, 'testSent')),
                  ),
                  Btn(
                    _x(ctx, 'disconnect'),
                    icon: LucideIcons.unplug,
                    kind: BtnKind.ghost,
                    small: true,
                    busy: _busy == 'off',
                    onTap: ctx.readOnly || _busy.isNotEmpty ? null : () => _run('off', () => ctx.api.delete('${ctx.base}/telegram'), _x(ctx, 'disconnected')),
                  ),
                ],
              ),
            ])
          else
            _panel([
              Text(_x(ctx, 'connectTitle'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              for (final (i, k) in ['step1', 'step2', 'step3'].indexed)
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
                      Expanded(child: Text(_x(ctx, k), style: const TextStyle(height: 1.4))),
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
                    child: QrImageView(data: str(link['url']), size: 170),
                  ),
                ),
                const SizedBox(height: 10),
                Btn(
                  _x(ctx, 'openTelegram'),
                  icon: LucideIcons.send,
                  expand: true,
                  onTap: () => launchUrl(Uri.parse(str(link['url'])), mode: LaunchMode.externalApplication),
                ),
                const SizedBox(height: 8),
                Btn(
                  _x(ctx, 'addToGroup'),
                  icon: LucideIcons.users,
                  kind: BtnKind.ghost,
                  expand: true,
                  onTap: () => launchUrl(Uri.parse(str(link['group_url'])), mode: LaunchMode.externalApplication),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_x(ctx, 'waiting'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Muted(_x(ctx, 'scanHint')),
                Muted(_x(ctx, 'groupHow')),
                if (_slow) Text(_x(ctx, 'slow'), style: TextStyle(color: c.warn, fontSize: 12.5)),
              ] else
                Btn(_x(ctx, 'connect'), icon: LucideIcons.send, busy: _busy == 'link', expand: true, onTap: ctx.readOnly || _busy == 'link' || s['configured'] == false ? null : _connect),
            ]),
          mGap,
          _panel([
            Text(_x(ctx, 'alertsTitle'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Muted(_x(ctx, 'alertsSub')),
            const SizedBox(height: 6),
            for (final k in _flags) SwitchRow(title: _x(ctx, 'a_$k'), sub: _x(ctx, 'a_${k}_sub'), value: f[k] == true, onChanged: ctx.readOnly ? null : (v) => setState(() => f[k] = v)),
            SwitchRow(title: _x(ctx, 'dailyReport'), sub: _x(ctx, 'dailyReportSub'), value: f['daily_report'] == true, onChanged: ctx.readOnly ? null : (v) => setState(() => f['daily_report'] = v)),
            if (f['daily_report'] == true)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_x(ctx, 'reportTime')),
                trailing: Chip2(str(f['report_time']), icon: LucideIcons.clock),
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        final p = str(f['report_time']).split(':');
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: int.tryParse(p.first) ?? 21, minute: int.tryParse(p.last) ?? 0),
                          builder: (c2, child) => MediaQuery(data: MediaQuery.of(c2).copyWith(alwaysUse24HourFormat: true), child: child!),
                        );
                        if (t != null) setState(() => f['report_time'] = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
                      },
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Btn(
                _busy == 'save' ? _x(ctx, 'saving') : _x(ctx, 'save'),
                small: true,
                busy: _busy == 'save',
                onTap: ctx.readOnly || _busy == 'save' || !dirty ? null : () => _run('save', () => ctx.api.put('${ctx.base}/telegram', f), _x(ctx, 'saved')),
              ),
            ),
          ]),
          mGap,
          Muted(_x(ctx, 'preview')),
          const SizedBox(height: 6),
          _sample(context),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ PROFILE
class ProfileTab extends StatefulWidget {
  final GhCtx ctx;
  const ProfileTab({super.key, required this.ctx});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  GhCtx get ctx => widget.ctx;
  late final Json b = ctx.business, s = ctx.settings;
  late final Map<String, TextEditingController> _f = {
    'name': TextEditingController(text: str(b['name'])),
    'phone': TextEditingController(text: str(b['phone'])),
    'address': TextEditingController(text: str(b['address'])),
    for (final k in ['email', 'website', 'facebook', 'telegram', 'map_url', 'description']) k: TextEditingController(text: str(s[k])),
  };
  bool _busy = false;
  String _pic = '';

  @override
  void dispose() {
    for (final c in _f.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    if (await ctx.run(() => ctx.api.put('${ctx.base}/profile', {for (final e in _f.entries) e.key: e.value.text.trim()}), ctx.g('saved')) != null) await ctx.reload();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _upload(String kind) async {
    final bytes = await ghPickPicture(context, ctx, maxSize: kind == 'logo' ? 600 : 1800);
    if (bytes == null) return;
    setState(() => _pic = kind);
    if (await ctx.run(() => ctx.api.post('${ctx.base}/$kind', fileForm('file', bytes, '$kind.jpg')), ctx.g('saved')) != null) await ctx.reload();
    if (mounted) setState(() => _pic = '');
  }

  Future<void> _remove(String kind) async {
    setState(() => _pic = kind);
    if (await ctx.run(() => ctx.api.delete('${ctx.base}/$kind'), ctx.g('saved')) != null) await ctx.reload();
    if (mounted) setState(() => _pic = '');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final logo = str(ctx.business['logo_url']);
    final cover = str(obj(ctx.settings['cover'])['url']);
    Widget picRow(String kind, String url, String label, {bool wide = false}) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Container(
            width: wide ? 120 : 64,
            height: 64,
            decoration: BoxDecoration(
              color: c.bg2,
              borderRadius: BorderRadius.circular(wide ? 14 : 32),
              border: Border.all(color: c.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: _pic == kind
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                : url.isNotEmpty
                ? Image(image: netImage(url), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())
                : Icon(LucideIcons.imagePlus, color: c.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    Btn(
                      _pic == kind ? ctx.g('uploading') : ctx.g('upload'),
                      icon: LucideIcons.imagePlus,
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: ctx.readOnly || _pic.isNotEmpty ? null : () => _upload(kind),
                    ),
                    if (url.isNotEmpty) Btn(ctx.g('remove'), icon: LucideIcons.trash2, kind: BtnKind.ghost, small: true, onTap: ctx.readOnly || _pic.isNotEmpty ? null : () => _remove(kind)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    Widget field(String k, String label, {String hint = '', int max = 200, int lines = 1, TextInputType? keys}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Field(label: label, controller: _f[k]!, hint: hint, maxLength: max, maxLines: lines, keyboard: keys, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 130,
                decoration: BoxDecoration(
                  color: c.active,
                  image: cover.isEmpty ? null : DecorationImage(image: netImage(cover), fit: BoxFit.cover),
                ),
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.all(14),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: c.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.card, width: 3),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.bedDouble, color: c.brand, size: 28),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(str(ctx.business['name']), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    Muted(ctx.g('profSub')),
                    picRow('logo', logo, ctx.g('logo')),
                    picRow('cover', cover, ctx.g('cover'), wide: true),
                  ],
                ),
              ),
            ],
          ),
        ),
        mGap,
        _panel([
          MHead(ctx.g('profTitle'), icon: LucideIcons.store),
          field('name', ctx.g('bizName'), max: 100),
          field('phone', ctx.g('phone'), hint: '012 345 678', max: 30, keys: TextInputType.phone),
          field('email', ctx.g('email'), max: 120, keys: TextInputType.emailAddress),
          field('address', ctx.g('address'), max: 300),
          field('map_url', ctx.g('mapUrl'), hint: 'https://maps.app.goo.gl/…', max: 500, keys: TextInputType.url),
          field('facebook', ctx.g('facebook'), hint: 'facebook.com/…'),
          field('telegram', ctx.g('telegram'), hint: '@mekongview', max: 100),
          field('website', ctx.g('website'), hint: 'https://', keys: TextInputType.url),
          field('description', ctx.g('descriptionBiz'), hint: ctx.g('descriptionBizPh'), max: 1000, lines: 3),
          Btn(_busy ? ctx.g('saving') : ctx.g('save'), icon: LucideIcons.save, expand: true, busy: _busy, onTap: _busy || ctx.readOnly || _f['name']!.text.trim().isEmpty ? null : _save),
        ]),
      ],
    );
  }
}
