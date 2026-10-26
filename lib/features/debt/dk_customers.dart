import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show mGap, todayKH, addDaysKH, fileForm;
import '../mart/mart_kit.dart' show MSheet, showSheet, DayField, decimalKeys, numOf;
import '../restaurant/rest_common.dart' show Segmented, gap14;
import '../restaurant/rest_online.dart' show shareWidgets;
import '../guesthouse/gh_common.dart' show ghPickPicture, GhCtx;
import 'dk_common.dart';

// People who owe · one person · add debt / take payment · reminder · receipt — DebtCustomers.jsx

Future<void> _copy(DkCtx ctx, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  ctx.notify(ctx.m('copied'));
}

// ------------------------------------------------------------------------------------------------ LIST
class CustomersTab extends StatefulWidget {
  final DkCtx ctx;
  final String initial;
  const CustomersTab({super.key, required this.ctx, this.initial = ''});
  @override
  State<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<CustomersTab> {
  DkCtx get ctx => widget.ctx;
  late String _cid = widget.initial;
  String _filter = 'all', _sort = '', _q = '';
  List<Json>? _rows;
  int _page = 1, _pages = 1, _total = 0;
  bool _busy = false;
  Timer? _wait;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load(1);
  }

  @override
  void dispose() {
    _wait?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load(int p) async {
    setState(() => _busy = true);
    try {
      final r = await ctx.api.get('${ctx.base}/customers', {'filter': _filter, 'q': _q.trim(), 'sort': _sort, 'page': '$p'});
      final pg = obj(r['pagination']);
      if (!mounted) return;
      setState(() {
        _rows = p == 1 ? objs(r['data']) : [...?_rows, ...objs(r['data'])];
        _page = p;
        _pages = n(pg['totalPages']).toInt().clamp(1, 9999);
        _total = n(pg['total']).toInt();
      });
    } catch (e) {
      ctx.fail(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  void _refresh() {
    _load(1);
    ctx.reload();
  }

  Future<void> _entry(Json c, String kind) async {
    final r = await showSheet<Json>(context, (_) => EntrySheet(ctx: ctx, customer: c, kind: kind));
    if (r == null) return;
    _refresh();
    ctx.notify(r['kind'] == 'pay' ? ctx.m('savedPay') : ctx.m('savedDebt'));
    if (r['kind'] == 'pay' && mounted) showReceipt(context, ctx, obj(r['entry']), obj(r['customer']));
  }

  @override
  Widget build(BuildContext context) {
    if (_cid.isNotEmpty) {
      return CustomerView(
        key: ValueKey(_cid),
        ctx: ctx,
        cid: _cid,
        onBack: () {
          setState(() => _cid = '');
          _load(1);
        },
        onChanged: () => ctx.reload(),
      );
    }
    final c = context.c;
    final t = ctx.totals;
    final full = n(t['customers']) >= n(ctx.limits['customers']);
    final month = obj(t['month']);
    final filters = ['all', 'owing', 'overdue', 'week', 'paid', if (ctx.owner) 'deleted'];
    Widget tile(IconData icon, String label, String value, {String? sub, Color? tint, VoidCallback? onTap}) => Expanded(
      child: Panel(
        padding: const EdgeInsets.all(12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: tint ?? c.muted),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: c.muted, fontSize: 12)),
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: tint),
            ),
            if (sub != null) Text(sub, style: TextStyle(color: c.muted, fontSize: 11.5)),
          ],
        ),
      ),
    );
    final rows = _rows;
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Row(
            children: [
              tile(
                LucideIcons.wallet,
                ctx.m('owedNow'),
                owed(t['owed']),
                tint: dkDebt,
                sub: n(obj(t['owed'])['usd']) > 0 && n(obj(t['owed'])['khr']) > 0 ? ctx.m('aboutUsd', {'v': dkMoney('USD', totalUsd(t['owed'], ctx.rate).round())}) : null,
              ),
              const SizedBox(width: 10),
              tile(LucideIcons.users, ctx.m('peopleOwing'), fmt(n(t['people'])), sub: ctx.m('ofCustomers', {'n': fmt(n(t['customers']))})),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              tile(
                LucideIcons.alarmClock,
                ctx.m('lateNow'),
                fmt(n(t['overdue'])),
                tint: n(t['overdue']) > 0 ? c.danger : null,
                onTap: () {
                  setState(() => _filter = 'overdue');
                  _load(1);
                },
              ),
              const SizedBox(width: 10),
              tile(LucideIcons.arrowDownLeft, ctx.m('paidMonth'), owed(month['paid']), tint: dkPay, sub: '${ctx.m('lentMonth')}: ${owed(month['lent'])}'),
            ],
          ),
          mGap,
          dkPanel([
            Row(
              children: [
                Expanded(
                  child: Field(
                    controller: _search,
                    hint: ctx.m('search'),
                    prefix: const Icon(LucideIcons.search, size: 16),
                    onChanged: (v) {
                      _q = v;
                      _wait?.cancel();
                      _wait = Timer(const Duration(milliseconds: 250), () => _load(1));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: ctx.m('sortBy'),
                  icon: Icon(LucideIcons.arrowUpDown, color: _sort.isEmpty ? c.muted : c.brand),
                  onSelected: (v) {
                    setState(() => _sort = v);
                    _load(1);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: '', child: Text(ctx.m('sortBy'))),
                    for (final k in ['balance', 'due', 'recent', 'name']) CheckedPopupMenuItem(value: k, checked: _sort == k, child: Text(ctx.m('sorts.$k'))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final k in filters)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('${ctx.m('filters.$k')}${k == 'overdue' && n(t['overdue']) > 0 ? ' ${n(t['overdue'])}' : ''}'),
                        selected: _filter == k,
                        onSelected: (_) {
                          setState(() => _filter = k);
                          _load(1);
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Btn(
              ctx.m('addCustomer'),
              icon: LucideIcons.userPlus,
              expand: true,
              onTap: ctx.readOnly
                  ? null
                  : () async {
                      if (full) return ctx.askBuy('debt_more');
                      final x = await showSheet<Json>(context, (_) => CustomerSheet(ctx: ctx));
                      if (x != null) {
                        ctx.reload();
                        setState(() => _cid = str(x['_id']));
                      }
                    },
            ),
            if (full && ctx.owner) ...[
              const SizedBox(height: 8),
              Muted(ctx.m('limitFull', {'n': fmt(n(ctx.limits['customers']))})),
            ],
          ]),
          mGap,
          if (rows == null)
            const SkelList(rows: 5)
          else if (rows.isEmpty)
            dkPanel([
              Icon(LucideIcons.users, size: 30, color: c.muted),
              const SizedBox(height: 8),
              Muted(n(t['customers']) > 0 || _q.isNotEmpty || _filter != 'all' ? ctx.m('noMatch') : ctx.m('noCustomers'), align: TextAlign.center),
            ])
          else
            dkPanel(padding: const EdgeInsets.fromLTRB(6, 6, 6, 6), [
              for (final x in rows)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _cid = str(x['_id'])),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(color: dueState(x) == 'late' ? c.dangerBg.withValues(alpha: .5) : null, borderRadius: BorderRadius.circular(14)),
                    child: Opacity(
                      opacity: x['deleted'] == true ? .5 : 1,
                      child: Row(
                        children: [
                          DkAvatar(x),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  str(x['name']),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  '${[str(x['phone']), str(x['telegram']), str(x['note'])].firstWhere((s) => s.isNotEmpty, orElse: () => '—')}${x['last_at'] != null ? ' · ${dkDate(x['last_at'], ctx.lang)}' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: c.muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                owes(x['balance']) ? owed(x['balance']) : ctx.m('nothing'),
                                style: TextStyle(fontWeight: FontWeight.w900, color: owes(x['balance']) ? dkDebt : c.good),
                              ),
                              const SizedBox(height: 3),
                              DueChip(ctx: ctx, c: x),
                            ],
                          ),
                          if (x['deleted'] != true && !ctx.readOnly) ...[
                            const SizedBox(width: 6),
                            _Mini(icon: LucideIcons.arrowUpRight, color: dkDebt, tip: ctx.m('addDebt'), onTap: () => _entry(x, 'debt')),
                            const SizedBox(width: 4),
                            _Mini(icon: LucideIcons.arrowDownLeft, color: dkPay, tip: ctx.m('takePay'), onTap: owes(x['balance']) ? () => _entry(x, 'pay') : null),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              if (_page < _pages)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Btn('${ctx.m('more')} (${fmt(_total - rows.length)})', kind: BtnKind.ghost, small: true, busy: _busy, onTap: _busy ? null : () => _load(_page + 1)),
                ),
            ]),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tip;
  final VoidCallback? onTap;
  const _Mini({required this.icon, required this.color, required this.tip, this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tip,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? .35 : 1,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------------------------------------------ ONE PERSON
class CustomerView extends StatefulWidget {
  final DkCtx ctx;
  final String cid;
  final VoidCallback onBack, onChanged;
  const CustomerView({super.key, required this.ctx, required this.cid, required this.onBack, required this.onChanged});
  @override
  State<CustomerView> createState() => _CustomerViewState();
}

class _CustomerViewState extends State<CustomerView> {
  DkCtx get ctx => widget.ctx;
  Json? _d;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/customers/${widget.cid}', {'page': '1'});
      if (mounted) setState(() => _d = obj(r['data']));
    } on ApiError catch (e) {
      if (mounted) setState(() => _err = e.message);
    }
  }

  void _changed([Json? cust]) {
    if (cust != null && cust.isNotEmpty) {
      setState(
        () => _d = {
          ..._d!,
          'customer': {...obj(_d!['customer']), ...cust},
        },
      );
    }
    widget.onChanged();
  }

  Future<bool> _confirm(String title, String sub, {bool danger = true, TextEditingController? reason}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(sub),
            if (reason != null) ...[const SizedBox(height: 12), Field(controller: reason, hint: ctx.m('reason'), maxLength: 200)],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(ctx.m('cancel'))),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: d.c.danger) : null,
            onPressed: () => Navigator.pop(d, true),
            child: Text(ctx.m('yes')),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _entry(Json c, String kind) async {
    final r = await showSheet<Json>(context, (_) => EntrySheet(ctx: ctx, customer: c, kind: kind));
    if (r == null) return;
    _changed(obj(r['customer']));
    _load();
    ctx.notify(r['kind'] == 'pay' ? ctx.m('savedPay') : ctx.m('savedDebt'));
    if (r['kind'] == 'pay' && mounted) showReceipt(context, ctx, obj(r['entry']), obj(r['customer']));
  }

  Future<void> _photo(Json c) async {
    final b = await ghPickPicture(context, GhCtx(id: ctx.id, api: ctx.api, t: ctx.t, data: const {}, reload: ctx.reload, askBuy: (_, {item, onDone}) {}, go: (_) {}, notify: ctx.notify), maxSize: 600);
    if (b == null) return;
    final r = await ctx.run(() => ctx.api.post('${ctx.base}/customers/${c['_id']}/photo', fileForm('photo', b, 'photo.jpg')));
    if (r != null) _changed(obj(r['data']));
  }

  @override
  Widget build(BuildContext context) {
    final col = context.c;
    if (_err.isNotEmpty) return Padding(padding: const EdgeInsets.all(16), child: Alert(_err));
    final d = _d;
    if (d == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 4));
    final c = obj(d['customer']);
    final bal = obj(c['balance']), lim = obj(c['limit']);
    final over = (n(lim['usd']) > 0 && n(bal['usd']) > n(lim['usd'])) || (n(lim['khr']) > 0 && n(bal['khr']) > n(lim['khr']));
    final link = statementUrl(c['token']);
    final ro = ctx.readOnly, deleted = c['deleted'] == true;
    final entries = objs(d['entries']);
    final phone = str(c['phone']).replaceAll(RegExp(r'[^\d+]'), '');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: widget.onBack, icon: const Icon(LucideIcons.arrowLeft, size: 16), label: Text(ctx.m('tabs.customers'))),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border(top: BorderSide(color: owes(bal) ? dkDebt : dkPay, width: 4)),
          ),
          child: dkPanel([
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: ctx.owner && !ro ? () => _photo(c) : null,
                  child: Stack(
                    children: [
                      DkAvatar(c, size: 64),
                      if (ctx.owner && !ro)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 11,
                            backgroundColor: col.brand,
                            child: const Icon(LucideIcons.camera, size: 12, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(str(c['name']), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      if (phone.isNotEmpty)
                        InkWell(
                          onTap: () => launchUrl(Uri.parse('tel:$phone')),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Icon(LucideIcons.phone, size: 13, color: col.brand),
                                const SizedBox(width: 4),
                                Text(
                                  str(c['phone']),
                                  style: TextStyle(color: col.brand, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (str(c['telegram']).isNotEmpty)
                        InkWell(
                          onTap: () => launchUrl(Uri.parse('https://t.me/${str(c['telegram']).replaceFirst(RegExp(r'^@'), '')}'), mode: LaunchMode.externalApplication),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Icon(LucideIcons.send, size: 13, color: col.brand),
                                const SizedBox(width: 4),
                                Text(
                                  str(c['telegram']),
                                  style: TextStyle(color: col.brand, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (str(c['address']).isNotEmpty) Muted(str(c['address'])),
                      if (str(c['note']).isNotEmpty) Muted(str(c['note'])),
                    ],
                  ),
                ),
                if (ctx.owner && !ro && !deleted)
                  IconButton(
                    onPressed: () async {
                      final x = await showSheet<Json>(context, (_) => CustomerSheet(ctx: ctx, customer: c));
                      if (x != null) _changed(x);
                    },
                    icon: const Icon(LucideIcons.pencil, size: 18),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              ctx.m('owes'),
              style: TextStyle(color: col.muted, fontWeight: FontWeight.w600),
            ),
            Text(
              owed(bal),
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 30, color: owes(bal) ? dkDebt : dkPay),
            ),
            if (n(bal['usd']) > 0 && n(bal['khr']) > 0) Muted(ctx.m('total', {'v': dkMoney('USD', (totalUsd(bal, ctx.rate) * 100).round() / 100)})),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                DueChip(ctx: ctx, c: c),
                if (n(lim['usd']) > 0 || n(lim['khr']) > 0) Chip2('${over ? '${ctx.m('overLimitNow')} · ' : ''}${ctx.m('limitIs', {'v': owed(lim)})}', tone: over ? Tone.danger : Tone.muted),
              ],
            ),
            if (!deleted) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _BigBtn(label: ctx.m('addDebt'), icon: LucideIcons.arrowUpRight, color: dkDebt, onTap: ro ? null : () => _entry(c, 'debt')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BigBtn(label: ctx.m('takePay'), icon: LucideIcons.arrowDownLeft, color: dkPay, onTap: ro ? null : () => _entry(c, 'pay')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Btn(
                ctx.m('remind'),
                icon: LucideIcons.bellRing,
                kind: BtnKind.ghost,
                expand: true,
                onTap: ro || !owes(bal) ? null : () => showSheet<void>(context, (_) => RemindSheet(ctx: ctx, customer: c, texts: obj(d['remind_text']), onDone: (x) => _changed(x))),
              ),
            ],
            if (ctx.owner && deleted) ...[
              const SizedBox(height: 12),
              Btn(
                ctx.m('restoreCustomer'),
                icon: LucideIcons.rotateCcw,
                expand: true,
                onTap: () async {
                  final r = await ctx.run(() => ctx.api.post('${ctx.base}/customers/${c['_id']}/restore'));
                  if (r != null) _changed(obj(r['data']));
                },
              ),
            ],
          ]),
        ),
        mGap,
        dkPanel([
          Row(
            children: [
              Icon(LucideIcons.link2, size: 16, color: col.brand),
              const SizedBox(width: 6),
              Text(ctx.m('statement'), style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Muted(ctx.m('statementSub')),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: col.bg2, borderRadius: BorderRadius.circular(12)),
            child: SelectableText(link, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (c['tg_linked'] == true) Chip2(ctx.m('tgLinked'), icon: LucideIcons.send, tone: Tone.good) else Muted(ctx.m('tgNotLinked')),
              if (n(c['reminds']) > 0) Muted(ctx.m('reminded', {'n': n(c['reminds']), 'date': dkDate(c['last_remind_at'], ctx.lang)})),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Btn(ctx.m('copy'), icon: LucideIcons.copy, kind: BtnKind.ghost, small: true, onTap: () => _copy(ctx, link)),
              Btn(
                ctx.m('open'),
                icon: LucideIcons.externalLink,
                kind: BtnKind.ghost,
                small: true,
                onTap: () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
              ),
              if (ctx.owner && !ro)
                Btn(
                  ctx.m('newLink'),
                  icon: LucideIcons.rotateCcw,
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: () async {
                    if (!await _confirm(ctx.m('newLink'), ctx.m('newLinkSub'), danger: false)) return;
                    final r = await ctx.run(() => ctx.api.post('${ctx.base}/customers/${c['_id']}/new-link'));
                    if (r != null) _changed(obj(r['data']));
                  },
                ),
            ],
          ),
        ]),
        mGap,
        dkPanel(padding: const EdgeInsets.fromLTRB(12, 14, 12, 8), [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(ctx.m('history'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
          ),
          if (entries.isEmpty) Padding(padding: const EdgeInsets.all(4), child: Muted(ctx.m('noLines'))),
          for (final e in entries)
            EntryRow(
              ctx: ctx,
              e: e,
              onReceipt: () => showReceipt(context, ctx, e, c),
              onChanged: (cust) {
                _changed(cust);
                _load();
              },
              confirm: _confirm,
            ),
        ]),
        if (ctx.owner && !ro && !deleted) ...[
          mGap,
          Btn(
            ctx.m('deleteCustomer'),
            icon: LucideIcons.trash2,
            kind: BtnKind.ghost,
            onTap: () async {
              if (!await _confirm(ctx.m('deleteCustomer'), ctx.m('deleteSub'))) return;
              if (await ctx.run(() => ctx.api.delete('${ctx.base}/customers/${c['_id']}')) != null) {
                widget.onChanged();
                widget.onBack();
              }
            },
          ),
        ],
      ],
    );
  }
}

class _BigBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _BigBtn({required this.label, required this.icon, required this.color, this.onTap});
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? .5 : 1,
    child: Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// one line of the history (debt + / payment −)
class EntryRow extends StatelessWidget {
  final DkCtx ctx;
  final Json e;
  final VoidCallback? onReceipt;
  final void Function(Json customer)? onChanged;
  final Future<bool> Function(String title, String sub, {bool danger, TextEditingController? reason})? confirm;
  final VoidCallback? onName;
  const EntryRow({super.key, required this.ctx, required this.e, this.onReceipt, this.onChanged, this.confirm, this.onName});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pay = e['kind'] == 'pay';
    final voided = e['void'] == true;
    final color = pay ? dkPay : dkDebt;
    final meta = [
      dkTime(e['date'], ctx.lang),
      if (str(e['method']).isNotEmpty) str(e['method']),
      if (e['due_at'] != null) ctx.m('due', {'date': dkDate(e['due_at'], ctx.lang)}),
      if (voided) '${ctx.m('voided')}${str(e['void_reason']).isNotEmpty ? ' (${e['void_reason']})' : ''}',
    ].join(' · ');
    return Opacity(
      opacity: voided ? .5 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle),
              child: Icon(pay ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (onName != null)
                    InkWell(
                      onTap: onName,
                      child: Text(
                        '${str(e['customer_name']).isEmpty ? '—' : e['customer_name']}${str(e['note']).isNotEmpty ? ' · ${lineNote(e, ctx)}' : ''}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: c.ink, decoration: voided ? TextDecoration.lineThrough : null),
                      ),
                    )
                  else
                    Text(
                      lineNote(e, ctx),
                      style: TextStyle(fontWeight: FontWeight.w700, decoration: voided ? TextDecoration.lineThrough : null),
                    ),
                  Text(meta, style: TextStyle(color: c.muted, fontSize: 11.5)),
                ],
              ),
            ),
            Text(
              '${pay ? '−' : '+'}${dkMoney(str(e['currency']), e['amount'])}',
              style: TextStyle(fontWeight: FontWeight.w900, color: color),
            ),
            if (onReceipt != null && !voided) IconButton(tooltip: ctx.m('receipt'), visualDensity: VisualDensity.compact, onPressed: onReceipt, icon: const Icon(LucideIcons.receipt, size: 17)),
            if (onChanged != null && confirm != null && ctx.owner && !ctx.readOnly)
              voided
                  ? IconButton(
                      tooltip: ctx.m('restore'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        final r = await ctx.run(() => ctx.api.post('${ctx.base}/entries/${e['_id']}/restore'));
                        if (r != null) onChanged!(obj(obj(r['data'])['customer']));
                      },
                      icon: const Icon(LucideIcons.rotateCcw, size: 17),
                    )
                  : IconButton(
                      tooltip: ctx.m('voidLine'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        final reason = TextEditingController();
                        final ok = await confirm!('${ctx.m('voidLine')} · ${pay ? '−' : '+'}${dkMoney(str(e['currency']), e['amount'])}', ctx.m('voidSub'), reason: reason);
                        final why = reason.text.trim();
                        reason.dispose();
                        if (!ok) return;
                        final r = await ctx.run(() => ctx.api.post('${ctx.base}/entries/${e['_id']}/void', {'reason': why}));
                        if (r != null) onChanged!(obj(obj(r['data'])['customer']));
                      },
                      icon: Icon(LucideIcons.trash2, size: 17, color: c.danger),
                    ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ ADD / EDIT A PERSON
class CustomerSheet extends StatefulWidget {
  final DkCtx ctx;
  final Json? customer;
  const CustomerSheet({super.key, required this.ctx, this.customer});
  @override
  State<CustomerSheet> createState() => _CustomerSheetState();
}

class _CustomerSheetState extends State<CustomerSheet> {
  DkCtx get ctx => widget.ctx;
  late final Json c = widget.customer ?? {};
  late final bool editing = widget.customer != null;
  late final Map<String, TextEditingController> _f = {
    for (final k in ['name', 'phone', 'telegram', 'address', 'note']) k: TextEditingController(text: str(c[k])),
    'limit_usd': TextEditingController(text: n(obj(c['limit'])['usd']) == 0 ? '' : '${n(obj(c['limit'])['usd'])}'),
    'limit_khr': TextEditingController(text: n(obj(c['limit'])['khr']) == 0 ? '' : '${n(obj(c['limit'])['khr'])}'),
    'open_usd': TextEditingController(),
    'open_khr': TextEditingController(),
  };
  late String _due = c['due_at'] == null ? '' : dayOf(c['due_at']);
  bool _busy = false;
  String _err = '';

  @override
  void dispose() {
    for (final x in _f.values) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _err = '';
    });
    try {
      final body = <String, dynamic>{
        for (final k in ['name', 'phone', 'telegram', 'address', 'note']) k: _f[k]!.text.trim(),
      };
      if (ctx.owner) body['limit'] = {'usd': numOf(_f['limit_usd']!.text) ?? 0, 'khr': numOf(_f['limit_khr']!.text) ?? 0};
      if (!editing) {
        body['opening'] = {'usd': numOf(_f['open_usd']!.text) ?? 0, 'khr': numOf(_f['open_khr']!.text) ?? 0};
        body['due_at'] = fromDay(_due);
      } else if (owes(c['balance'])) {
        body['due_at'] = fromDay(_due);
      }
      final r = editing ? await ctx.api.put('${ctx.base}/customers/${c['_id']}', body) : await ctx.api.post('${ctx.base}/customers', body);
      if (mounted) Navigator.pop(context, obj(r['data']));
    } on ApiError catch (e) {
      if (e.status == 402 && e.body['product'] != null) {
        if (mounted) Navigator.pop(context);
        ctx.askBuy(str(e.body['product']));
      } else if (mounted) {
        setState(() => _err = e.network ? ctx.t('app.offline') : e.message);
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _two(Widget a, Widget b) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: a),
      const SizedBox(width: 10),
      Expanded(child: b),
    ],
  );

  @override
  Widget build(BuildContext context) => MSheet(
    title: editing ? ctx.m('editCustomer') : ctx.m('newCustomer'),
    footer: [
      const Spacer(),
      Btn(ctx.m('cancel'), kind: BtnKind.ghost, small: true, onTap: _busy ? null : () => Navigator.pop(context)),
      const SizedBox(width: 8),
      Btn(ctx.m('save'), icon: LucideIcons.check, small: true, busy: _busy, onTap: _busy || _f['name']!.text.trim().isEmpty ? null : _go),
    ],
    children: [
      Field(label: '${ctx.m('name')} *', controller: _f['name']!, maxLength: 80, autofocus: !editing, onChanged: (_) => setState(() {})),
      gap14,
      _two(
        Field(label: ctx.m('phone'), controller: _f['phone']!, maxLength: 40, keyboard: TextInputType.phone),
        Field(label: ctx.m('telegram'), controller: _f['telegram']!, maxLength: 60, hint: '@'),
      ),
      gap14,
      Field(label: ctx.m('address'), controller: _f['address']!, maxLength: 200),
      gap14,
      Field(label: ctx.m('note'), controller: _f['note']!, maxLength: 500),
      if (!editing) ...[
        gap14,
        Text(ctx.m('opening'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        _two(Field(controller: _f['open_usd']!, hint: '\$', keyboard: decimalKeys), Field(controller: _f['open_khr']!, hint: '៛', keyboard: TextInputType.number)),
      ],
      if (!editing || owes(c['balance'])) ...[gap14, DayField(label: ctx.m('dueDate'), value: _due, onChanged: (v) => setState(() => _due = v))],
      if (ctx.owner) ...[
        gap14,
        Text(ctx.m('limit'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        _two(Field(controller: _f['limit_usd']!, hint: '\$', keyboard: decimalKeys), Field(controller: _f['limit_khr']!, hint: '៛', keyboard: TextInputType.number)),
        const SizedBox(height: 4),
        Muted(ctx.m('limitHint')),
      ],
      if (_err.isNotEmpty) ...[gap14, Alert(_err)],
    ],
  );
}

// ------------------------------------------------------------------------------------------------ ADD A DEBT / TAKE A PAYMENT
String _endOfMonth() {
  final d = DateTime.parse('${todayKH()}T00:00:00Z');
  return DateTime.utc(d.year, d.month + 1, 0).toIso8601String().substring(0, 10);
}

class EntrySheet extends StatefulWidget {
  final DkCtx ctx;
  final Json customer;
  final String kind;
  const EntrySheet({super.key, required this.ctx, required this.customer, required this.kind});
  @override
  State<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<EntrySheet> {
  DkCtx get ctx => widget.ctx;
  Json get c => widget.customer;
  late String _kind = widget.kind;
  late String _cur = () {
    final main = str(ctx.book['main']).isEmpty ? 'USD' : str(ctx.book['main']);
    final bal = obj(c['balance']);
    if (widget.kind == 'pay' && !(n(bal[main == 'KHR' ? 'khr' : 'usd']) > 0) && owes(bal)) return n(bal['usd']) > 0 ? 'USD' : 'KHR';
    return main;
  }();
  final _amount = TextEditingController(), _note = TextEditingController();
  String _method = 'cash', _due = '', _date = todayKH();
  bool _busy = false;
  String _err = '';
  Json? _ask; // {text, force}

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  num get _bal => n(obj(c['balance'])[_cur == 'KHR' ? 'khr' : 'usd']);

  Future<void> _save([bool force = false]) async {
    setState(() {
      _busy = true;
      _err = '';
    });
    try {
      final body = <String, dynamic>{
        'kind': _kind,
        'currency': _cur,
        'amount': numOf(_amount.text) ?? 0,
        'note': _note.text.trim(),
        if (_date != todayKH()) 'date': fromDay(_date),
        'force': force,
        if (_kind == 'debt') 'due_at': fromDay(_due) else 'method': ctx.t.or('debt.methods.$_method', _method),
      };
      final r = await ctx.api.post('${ctx.base}/customers/${c['_id']}/entries', body);
      if (mounted) Navigator.pop(context, {...obj(r['data']), 'kind': _kind});
    } on ApiError catch (e) {
      final code = str(e.body['code']);
      if (code == 'over_limit') {
        setState(
          () => _ask = {
            'text': ctx.m('overLimitAsk', {'limit': dkMoney(_cur, e.body['limit']), 'balance': dkMoney(_cur, e.body['balance'])}),
            'force': ctx.owner,
          },
        );
      } else if (code == 'too_much') {
        setState(
          () => _ask = {
            'text': ctx.m('tooMuchAsk', {'balance': dkMoney(_cur, e.body['balance'])}),
            'force': true,
          },
        );
      } else {
        setState(() => _err = e.network ? ctx.t('app.offline') : e.message);
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final col = context.c;
    final pay = _kind == 'pay';
    final color = pay ? dkPay : dkDebt;
    final ok = (numOf(_amount.text) ?? 0) > 0;
    final quick = _cur == 'KHR' ? [5000, 10000, 20000, 50000, 100000] : [1, 5, 10, 20, 50];
    final ask = _ask;
    Widget chip(String label, bool on, VoidCallback onTap) => ChoiceChip(label: Text(label), selected: on, onSelected: (_) => onTap());
    return MSheet(
      title: (pay ? ctx.m('payTitle') : ctx.m('debtTitle')).replaceAll('{name}', str(c['name'])),
      footer: ask != null
          ? [
              const Spacer(),
              Btn(ctx.m('cancel'), kind: BtnKind.ghost, small: true, onTap: _busy ? null : () => setState(() => _ask = null)),
              if (ask['force'] == true) ...[const SizedBox(width: 8), Btn(ctx.m('yes'), icon: LucideIcons.check, small: true, busy: _busy, onTap: _busy ? null : () => _save(true))],
            ]
          : [
              const Spacer(),
              Btn(ctx.m('cancel'), kind: BtnKind.ghost, small: true, onTap: _busy ? null : () => Navigator.pop(context)),
              const SizedBox(width: 8),
              Material(
                color: ok && !_busy ? color : color.withValues(alpha: .4),
                borderRadius: BorderRadius.circular(99),
                child: InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: ok && !_busy ? () => _save() : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_busy)
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        else
                          const Icon(LucideIcons.check, size: 15, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          pay ? ctx.m('savePay') : ctx.m('saveDebt'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
      children: ask != null
          ? [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: col.warnBg, borderRadius: BorderRadius.circular(14)),
                child: Text(ask['text'] as String, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4)),
              ),
            ]
          : [
              Segmented<String>(value: _kind, options: [('debt', ctx.m('lineDebt')), ('pay', ctx.m('linePay'))], onChanged: (v) => setState(() => _kind = v)),
              gap14,
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: .3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Segmented<String>(value: _cur, options: const [('USD', '\$ USD'), ('KHR', '៛ KHR')], onChanged: (v) => setState(() => _cur = v)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _amount,
                      autofocus: true,
                      keyboardType: decimalKeys,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: color),
                      decoration: InputDecoration(hintText: _cur == 'KHR' ? '0 ៛' : '\$0.00', border: InputBorder.none),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => ok ? _save() : null,
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (pay && _bal > 0)
                          ActionChip(label: Text(ctx.m('payAll', {'v': dkMoney(_cur, _bal)})), onPressed: () => setState(() => _amount.text = '$_bal'.replaceFirst(RegExp(r'\.0$'), ''))),
                        for (final q in quick)
                          ActionChip(
                            label: Text('+${_cur == 'KHR' ? fmt(q) : '\$$q'}'),
                            onPressed: () => setState(() => _amount.text = '${(numOf(_amount.text) ?? 0) + q}'.replaceFirst(RegExp(r'\.0$'), '')),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              gap14,
              if (!pay) ...[
                Field(label: ctx.m('what'), controller: _note, hint: ctx.m('whatPh'), maxLength: 300),
                gap14,
                Text(ctx.m('dueIn'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    chip(ctx.m('noDue'), _due.isEmpty, () => setState(() => _due = '')),
                    for (final d in [7, 15, 30]) chip(nDays(ctx, d), _due == addDaysKH(todayKH(), d), () => setState(() => _due = addDaysKH(todayKH(), d))),
                    chip(ctx.m('endMonth'), _due == _endOfMonth(), () => setState(() => _due = _endOfMonth())),
                  ],
                ),
                const SizedBox(height: 8),
                DayField(label: ctx.m('dueDate'), value: _due, onChanged: (v) => setState(() => _due = v)),
              ] else ...[
                Text(ctx.m('howPaid'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final k in ['cash', 'aba', 'acleda', 'wing', 'other']) chip(ctx.m('methods.$k'), _method == k, () => setState(() => _method = k)),
                  ],
                ),
                gap14,
                Field(label: ctx.m('payNote'), controller: _note, maxLength: 300),
              ],
              gap14,
              DayField(label: ctx.m('date'), value: _date, last: DateTime.parse('${todayKH()}T00:00:00Z'), onChanged: (v) => setState(() => _date = v.isEmpty ? todayKH() : v)),
              if (_err.isNotEmpty) ...[gap14, Alert(_err)],
            ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ REMINDER BY HAND
class RemindSheet extends StatefulWidget {
  final DkCtx ctx;
  final Json customer, texts;
  final void Function(Json customer) onDone;
  const RemindSheet({super.key, required this.ctx, required this.customer, required this.texts, required this.onDone});
  @override
  State<RemindSheet> createState() => _RemindSheetState();
}

class _RemindSheetState extends State<RemindSheet> {
  DkCtx get ctx => widget.ctx;
  late String _l = ctx.lang == 'en' ? 'en' : 'km';
  late final _text = TextEditingController(text: str(widget.texts[_l]));
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _mark() async {
    try {
      final r = await ctx.api.post('${ctx.base}/customers/${widget.customer['_id']}/reminded');
      widget.onDone(obj(r['data']));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;
    final phone = str(c['phone']).replaceAll(RegExp(r'[^\d+]'), '');
    final auto = ctx.on('debt_remind') && c['tg_linked'] == true;
    final link = statementUrl(c['token']);
    return MSheet(
      title: ctx.m('remindTitle'),
      children: [
        Muted(ctx.m('remindSub')),
        gap14,
        Segmented<String>(
          value: _l,
          options: const [('km', 'ខ្មែរ'), ('en', 'English')],
          onChanged: (v) => setState(() {
            _l = v;
            _text.text = str(widget.texts[v]);
          }),
        ),
        gap14,
        Field(controller: _text, maxLines: 6),
        gap14,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Btn(
              ctx.m('shareTg'),
              icon: LucideIcons.send,
              small: true,
              onTap: () {
                launchUrl(Uri.parse('https://t.me/share/url?url=${Uri.encodeComponent(link)}&text=${Uri.encodeComponent(_text.text)}'), mode: LaunchMode.externalApplication);
                _mark();
              },
            ),
            if (phone.isNotEmpty)
              Btn(
                ctx.m('sms'),
                icon: LucideIcons.messageSquare,
                kind: BtnKind.ghost,
                small: true,
                onTap: () {
                  launchUrl(Uri.parse('sms:$phone?body=${Uri.encodeComponent(_text.text)}'));
                  _mark();
                },
              ),
            Btn(
              ctx.m('copyText'),
              icon: LucideIcons.copy,
              kind: BtnKind.ghost,
              small: true,
              onTap: () async {
                await _copy(ctx, _text.text);
                _mark();
              },
            ),
            if (auto)
              Btn(
                ctx.m('autoSend'),
                icon: LucideIcons.bellRing,
                kind: BtnKind.ghost,
                small: true,
                busy: _busy,
                onTap: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        if (await ctx.run(() => ctx.api.post('${ctx.base}/customers/${c['_id']}/remind', {'lang': _l}), ctx.m('autoSent')) != null && context.mounted) {
                          widget.onDone(const {});
                          Navigator.pop(context);
                        }
                        if (mounted) setState(() => _busy = false);
                      },
              ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ RECEIPT PICTURE
void showReceipt(BuildContext context, DkCtx ctx, Json entry, Json customer) => showSheet<void>(context, (_) => _ReceiptSheet(ctx: ctx, entry: entry, customer: customer));

class _ReceiptSheet extends StatelessWidget {
  final DkCtx ctx;
  final Json entry, customer;
  const _ReceiptSheet({required this.ctx, required this.entry, required this.customer});

  @override
  Widget build(BuildContext context) {
    final key = GlobalKey();
    final b = ctx.book;
    final pay = entry['kind'] == 'pay';
    const ink = Color(0xFF111827), grey = Color(0xFF6B7280);
    final color = pay ? const Color(0xFF047857) : const Color(0xFFB91C1C);
    final bal = obj(customer['balance']);
    TextStyle s(double size, {FontWeight w = FontWeight.w400, Color col = ink}) => TextStyle(fontSize: size, fontWeight: w, color: col, height: 1.3);
    return MSheet(
      title: ctx.m('receiptTitle'),
      footer: [
        const Spacer(),
        Btn(ctx.m('close'), kind: BtnKind.ghost, small: true, onTap: () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(ctx.m('share'), icon: LucideIcons.share2, small: true, onTap: () => shareWidgets([key], (_) => 'receipt-${entry['no'] ?? 'x'}.png')),
      ],
      children: [
        Center(
          child: RepaintBoundary(
            key: key,
            child: Container(
              width: 340,
              color: Colors.white,
              child: Column(
                children: [
                  Container(height: 5, color: pay ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                    child: Column(
                      children: [
                        if (str(b['shop_name']).isNotEmpty)
                          Text(
                            str(b['shop_name']),
                            textAlign: TextAlign.center,
                            style: s(18, w: FontWeight.w800),
                          ),
                        if (str(b['phone']).isNotEmpty) Text(str(b['phone']), style: s(12, col: grey)),
                        if (str(b['address']).isNotEmpty)
                          Text(
                            str(b['address']),
                            textAlign: TextAlign.center,
                            style: s(11, col: grey),
                          ),
                        const Divider(height: 24, color: Color(0xFFE5E7EB)),
                        Text(
                          '${pay ? ctx.m('receiptPay') : ctx.m('receiptDebt')}  ·  ${ctx.m('receiptNo', {'n': entry['no'] ?? '—'})}',
                          style: s(12.5, w: FontWeight.w800, col: color),
                        ),
                        Text(dkTime(entry['date'], ctx.lang), style: s(11.5, col: grey)),
                        const SizedBox(height: 10),
                        Text(
                          str(customer['name']),
                          textAlign: TextAlign.center,
                          style: s(17, w: FontWeight.w800),
                        ),
                        if (str(customer['phone']).isNotEmpty) Text(str(customer['phone']), style: s(11.5, col: grey)),
                        const SizedBox(height: 8),
                        Text(
                          '${pay ? '−' : '+'} ${dkMoney(str(entry['currency']), entry['amount'])}',
                          style: s(34, w: FontWeight.w900, col: color),
                        ),
                        if (str(entry['note']).isNotEmpty)
                          Text(
                            lineNote(entry, ctx),
                            textAlign: TextAlign.center,
                            style: s(12.5, col: const Color(0xFF374151)),
                          ),
                        if (str(entry['method']).isNotEmpty) Text(str(entry['method']), style: s(11.5, col: grey)),
                        const Divider(height: 26, color: Color(0xFFE5E7EB)),
                        Row(
                          children: [
                            Expanded(
                              child: Text(ctx.m('receiptLeft'), style: s(14, w: FontWeight.w800)),
                            ),
                            Text(owed(bal), style: s(14, w: FontWeight.w800)),
                          ],
                        ),
                        if (customer['due_at'] != null && owes(bal))
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(ctx.m('dueDate'), style: s(11.5, col: grey)),
                                ),
                                Text(dkDate(customer['due_at'], ctx.lang), style: s(11.5, col: grey)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 14),
                        Text(ctx.m('receiptThanks'), style: s(13.5, w: FontWeight.w800)),
                        if (!ctx.on('debt_nobrand')) Text('BizHub', style: s(10, col: const Color(0xFF9CA3AF))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
