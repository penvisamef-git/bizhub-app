import 'package:dio/dio.dart' show DioMediaType, FormData, MultipartFile;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../restaurant/rest_common.dart' show SelectField;
import 'ev_common.dart';
import 'ev_extras.dart';

// ======================================== Events (EventsTab in EvTabs.jsx) ========================================
class EventsTab extends StatefulWidget {
  final EvCtx ctx;
  const EventsTab({super.key, required this.ctx});
  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  final _q = TextEditingController();
  String _show = 'all', _sort = 'soon', _kind = '';
  int _limit = 24;
  String _busy = '';

  EvCtx get ctx => widget.ctx;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _edit([Json? ev]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventEditor(ctx: ctx, ev: ev),
      ),
    );
    if (saved == true) await ctx.reload();
  }

  Future<void> _dup(Json e) async {
    final days = await askText(context, title: ctx.m('evl.dupAsk'), initial: '7', keyboard: TextInputType.number, ok: ctx.m('evl.duplicate'), cancel: ctx.m('cancel'));
    if (days == null) return;
    setState(() => _busy = str(e['_id']));
    final r = await ctx.run(() => ctx.api.post('${ctx.base}/events/${e['_id']}/duplicate', {'days': int.tryParse(days.trim()) ?? 0}), ctx.m('evl.dupDone'));
    if (mounted) setState(() => _busy = '');
    if (r != null) {
      await ctx.reload();
      if (mounted) _edit(obj(r['data']));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final now = DateTime.now();
    final all = ctx.events;
    final counts = <String, int>{'all': all.length, 'upcoming': 0, 'live': 0, 'draft': 0, 'past': 0, 'cancelled': 0};
    num tickets = 0, money = 0, used = 0, review = 0;
    for (final e in all) {
      counts[evPhase(e, now)] = (counts[evPhase(e, now)] ?? 0) + 1;
      final k = obj(e['counts']);
      tickets += n(k['tickets']);
      money += n(k['money']);
      used += n(k['used']);
      review += n(k['review']);
    }
    final active = (counts['upcoming'] ?? 0) + (counts['live'] ?? 0);
    final next = (all.where((e) => ['upcoming', 'live'].contains(evPhase(e, now))).toList()..sort((a, b) => (evDate(a['starts_at']) ?? now).compareTo(evDate(b['starts_at']) ?? now))).firstOrNull;
    final q = _q.text.trim().toLowerCase();
    final order = {'live': 0, 'upcoming': 1, 'draft': 2, 'past': 3, 'cancelled': 4};
    DateTime at(Json e) => evDate(e['starts_at']) ?? now;
    final list = all.where((e) {
      final ph = evPhase(e, now);
      if (_show == 'active' && !['upcoming', 'live'].contains(ph)) return false;
      if (!['all', 'active'].contains(_show) && ph != _show) return false;
      if (_kind.isNotEmpty && e['kind'] != _kind) return false;
      if (q.isNotEmpty && ![e['title'], e['venue'], e['slug']].any((v) => str(v).toLowerCase().contains(q))) return false;
      return true;
    }).toList();
    list.sort((a, b) {
      switch (_sort) {
        case 'latest':
          return at(b).compareTo(at(a));
        case 'oldest':
          return at(a).compareTo(at(b));
        case 'sold':
          return n(obj(b['counts'])['tickets']).compareTo(n(obj(a['counts'])['tickets']));
        case 'money':
          return n(obj(b['counts'])['money']).compareTo(n(obj(a['counts'])['money']));
        case 'az':
          return str(a['title']).toLowerCase().compareTo(str(b['title']).toLowerCase());
        default:
          final pa = order[evPhase(a, now)]!, pb = order[evPhase(b, now)]!;
          if (pa != pb) return pa - pb;
          return pa >= 3 ? at(b).compareTo(at(a)) : at(a).compareTo(at(b));
      }
    });
    final shown = list.take(_limit).toList();
    return EvList(
      onRefresh: ctx.reload,
      children: [
        EvHead(
          ctx.m('eventsTitle'),
          sub: ctx.m('eventsSub'),
          trailing: Btn(ctx.m('newEvent'), icon: LucideIcons.plus, small: true, onTap: ctx.readOnly ? null : () => _edit()),
        ),
        if (all.isEmpty)
          Panel(
            child: Column(
              children: [
                Icon(LucideIcons.ticket, size: 34, color: c.muted),
                const SizedBox(height: 10),
                Muted(ctx.m('noEvents'), align: TextAlign.center),
                const SizedBox(height: 12),
                Btn(ctx.m('newEvent'), icon: LucideIcons.plus, onTap: ctx.readOnly ? null : () => _edit()),
              ],
            ),
          )
        else ...[
          EvStats([
            EvStat(
              ctx.m('evl.g.active'),
              fmt(active),
              sub: (counts['live'] ?? 0) > 0 ? ctx.m('evl.g.liveN', {'n': counts['live']}) : ctx.m('evl.g.ofAll', {'n': fmt(all.length)}),
              onTap: () => setState(() => _show = 'active'),
            ),
            EvStat(ctx.m('evl.g.tickets'), fmt(tickets), sub: ctx.m('evl.g.came', {'n': fmt(used)})),
            EvStat(ctx.m('evl.g.money'), usd2(money), sub: ctx.m('evl.g.allEvents')),
            if (review > 0)
              EvStat(
                ctx.m('evl.g.review'),
                fmt(review),
                sub: ctx.m('evl.g.check'),
                tone: Tone.warn,
                onTap: () => ctx.go('orders', status: 'review'),
              )
            else
              EvStat(ctx.m('evl.g.next'), next == null ? '—' : str(next['title']), sub: next == null ? ctx.m('evl.g.noNext') : _whenChip(next, now).$1, onTap: next == null ? null : () => _edit(next)),
          ]),
          const SizedBox(height: 14),
          Field(controller: _q, hint: ctx.m('evl.search'), icon: LucideIcons.search, onChanged: (_) => setState(() => _limit = 24)),
          const SizedBox(height: 10),
          EvChips(
            items: [
              ('all', ctx.m('evl.f.all'), counts['all']),
              ('active', ctx.m('evl.f.active'), active),
              if ((counts['live'] ?? 0) > 0) ('live', ctx.m('evl.f.live'), counts['live']),
              if ((counts['draft'] ?? 0) > 0) ('draft', ctx.m('evl.f.draft'), counts['draft']),
              if ((counts['past'] ?? 0) > 0) ('past', ctx.m('evl.f.past'), counts['past']),
              if ((counts['cancelled'] ?? 0) > 0) ('cancelled', ctx.m('evl.f.cancelled'), counts['cancelled']),
            ],
            value: _show,
            onPick: (v) => setState(() {
              _show = v;
              _limit = 24;
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(ctx.m('evl.found', {'n': fmt(list.length)}), style: TextStyle(color: c.muted, fontSize: 13)),
              ),
              _Menu(
                icon: LucideIcons.filter,
                label: _kind.isEmpty ? ctx.m('evl.kinds.all') : ctx.m('evl.kinds.$_kind'),
                items: {'': ctx.m('evl.kinds.all'), 'paid': ctx.m('evl.kinds.paid'), 'free': ctx.m('evl.kinds.free')},
                onPick: (v) => setState(() => _kind = v),
              ),
              const SizedBox(width: 6),
              _Menu(
                icon: LucideIcons.arrowUpDown,
                label: ctx.m('evl.s.$_sort'),
                items: {
                  for (final k in ['soon', 'latest', 'oldest', 'sold', 'money', 'az']) k: ctx.m('evl.s.$k'),
                },
                onPick: (v) => setState(() => _sort = v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (list.isEmpty)
            Panel(
              child: Column(
                children: [
                  Muted(ctx.m('evl.none'), align: TextAlign.center),
                  const SizedBox(height: 8),
                  Btn(
                    ctx.m('evl.clear'),
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: () => setState(() {
                      _q.clear();
                      _show = 'all';
                      _kind = '';
                    }),
                  ),
                ],
              ),
            ),
          for (final e in shown) _card(e, now),
          if (list.length > _limit) Btn(ctx.m('evl.more', {'n': fmt(list.length - _limit)}), kind: BtnKind.ghost, icon: LucideIcons.chevronDown, onTap: () => setState(() => _limit += 24)),
        ],
      ],
    );
  }

  // "Today" / "In 3 days" / "Live now" / "Ended"
  (String, Tone) _whenChip(Json e, DateTime now) {
    final ph = evPhase(e, now);
    if (ph == 'live') return (ctx.m('evl.liveNow'), Tone.good);
    if (ph == 'past') return (ctx.m('evl.ended'), Tone.muted);
    if (ph != 'upcoming') return ('', Tone.muted);
    final s = evDate(e['starts_at']) ?? now;
    final d = DateTime(s.year, s.month, s.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    final text = d <= 0 ? ctx.m('evl.today') : (d == 1 ? ctx.m('evl.tomorrow') : ctx.m('evl.inDays', {'n': d}));
    return (text, d <= 7 ? Tone.brand : Tone.muted);
  }

  Widget _card(Json e, DateTime now) {
    final c = context.c;
    final k = obj(e['counts']);
    final qty = evQty(e);
    final sold = n(k['tickets']);
    final id = str(e['_id']);
    final ph = evPhase(e, now);
    final closed = e['status'] == 'published' && (e['sale'] != 'open' || ph == 'past');
    final (chip, chipTone) = _whenChip(e, now);
    final poster = str(e['poster']);
    final free = e['kind'] == 'free';
    final statusText = closed ? ctx.m('saleClosed') : ctx.m('status.${e['status']}');
    final statusTone = e['status'] == 'cancelled'
        ? Tone.danger
        : e['status'] == 'draft'
        ? Tone.muted
        : closed
        ? Tone.warn
        : Tone.good;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: e['status'] == 'cancelled' ? .7 : 1,
        child: Panel(
          padding: const EdgeInsets.all(12),
          onTap: () => _edit(e),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 72,
                    height: 90,
                    decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(14)),
                    clipBehavior: Clip.antiAlias,
                    child: poster.isNotEmpty
                        ? Image(image: netImage(poster), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())
                        : Icon(LucideIcons.ticket, size: 26, color: c.brand),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Chip2(statusText, tone: statusTone),
                            if (chip.isNotEmpty) Chip2(chip, tone: chipTone),
                            if (free) Chip2(ctx.m('evl.freeEv'), tone: Tone.lime),
                            if (e['featured_until'] != null) Chip2(ctx.m('evl.featured'), icon: LucideIcons.rocket, tone: Tone.warn),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          str(e['title']),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(evWhen(e['starts_at'], ctx.lang), style: TextStyle(fontSize: 12.5, color: c.muted)),
                        if (str(e['venue']).isNotEmpty)
                          Text(
                            str(e['venue']),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: c.muted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: qty > 0 ? (sold / qty).clamp(0, 1).toDouble() : 0, minHeight: 6, backgroundColor: c.chip, color: c.brand),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (free ? ctx.m('registered', {'n': fmt(sold), 'of': fmt(qty)}) : ctx.m('sold', {'n': fmt(sold), 'of': fmt(qty)})),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(ctx.m('checkedIn', {'n': fmt(n(k['used']))}), style: TextStyle(fontSize: 13, color: c.muted)),
                  if (!free) ...[const SizedBox(width: 12), Text(usd2(k['money']), style: const TextStyle(fontWeight: FontWeight.w800))],
                ],
              ),
              if (n(k['review']) > 0) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    avatar: Icon(LucideIcons.bellRing, size: 14, color: c.warn),
                    label: Text(ctx.m('waitingN', {'n': n(k['review'])})),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => ctx.go('orders', event: id, status: 'review'),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  _Act(LucideIcons.receiptText, ctx.m('evl.orders'), () => ctx.go('orders', event: id)),
                  _Act(LucideIcons.usersRound, ctx.m('evl.guests'), () => ctx.go('guests', event: id)),
                  if (e['status'] != 'draft') ...[
                    _Act(LucideIcons.share2, ctx.a('share'), () => SharePlus.instance.share(ShareParams(text: '${e['title']}\n${eventUrl(e['slug'])}'))),
                    _Act(LucideIcons.externalLink, ctx.m('openPage'), () => launchUrl(Uri.parse(eventUrl(e['slug'])), mode: LaunchMode.externalApplication)),
                  ],
                  _Act(_busy == id ? LucideIcons.loaderCircle : LucideIcons.copyPlus, ctx.m('evl.duplicate'), ctx.readOnly || _busy.isNotEmpty ? null : () => _dup(e)),
                  if (e['status'] == 'published' && ph != 'past')
                    _Act(LucideIcons.rocket, ctx.m('evl.feature'), ctx.readOnly ? null : () => ctx.askBuy('feature', item: id), on: e['featured_until'] != null),
                  const Spacer(),
                  Btn(ctx.m('evl.edit'), icon: LucideIcons.pencil, kind: BtnKind.ghost, small: true, onTap: () => _edit(e)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Act extends StatelessWidget {
  final IconData icon;
  final String tip;
  final VoidCallback? onTap;
  final bool on;
  const _Act(this.icon, this.tip, this.onTap, {this.on = false});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tip,
    visualDensity: VisualDensity.compact,
    onPressed: onTap,
    icon: Icon(icon, size: 18, color: on ? context.c.warn : (onTap == null ? context.c.muted.withValues(alpha: .4) : context.c.ink)),
  );
}

class _Menu extends StatelessWidget {
  final IconData icon;
  final String label;
  final Map<String, String> items;
  final ValueChanged<String> onPick;
  const _Menu({required this.icon, required this.label, required this.items, required this.onPick});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final v = await evPickFrom(context, label, [for (final e in items.entries) (e.key, e.value)]);
        if (v != null) onPick(v);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: c.muted),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ======================================== the event editor (EventEditor in EvTabs.jsx) ========================================
class _Type {
  String key;
  final TextEditingController name, price, qty, note;
  bool active;
  final int taken;
  final List<(TextEditingController, TextEditingController, DateTime?)> tiers; // label, price, until
  final List<(TextEditingController, TextEditingController)> bundles; // qty, price
  bool open;
  _Type({
    this.key = '',
    String name = '',
    num price = 10,
    num qty = 100,
    String note = '',
    this.active = true,
    this.taken = 0,
    List<(TextEditingController, TextEditingController, DateTime?)>? tiers,
    List<(TextEditingController, TextEditingController)>? bundles,
  }) : name = TextEditingController(text: name),
       price = TextEditingController(text: _num(price)),
       qty = TextEditingController(text: _num(qty)),
       note = TextEditingController(text: note),
       tiers = tiers ?? [],
       bundles = bundles ?? [],
       open = (tiers?.isNotEmpty ?? false) || (bundles?.isNotEmpty ?? false);
  static String _num(num v) => v % 1 == 0 ? '${v.toInt()}' : '$v';
  factory _Type.of(Json t) => _Type(
    key: str(t['key']),
    name: str(t['name']),
    price: n(t['price']),
    qty: n(t['qty']),
    note: str(t['note']),
    active: t['active'] != false,
    taken: n(t['taken']).toInt(),
    tiers: [for (final x in objs(t['tiers'])) (TextEditingController(text: str(x['label'])), TextEditingController(text: _num(n(x['price']))), evDate(x['until']))],
    bundles: [for (final x in objs(t['bundles'])) (TextEditingController(text: '${n(x['qty']).toInt()}'), TextEditingController(text: _num(n(x['price']))))],
  );
}

class EventEditor extends StatefulWidget {
  final EvCtx ctx;
  final Json? ev;
  const EventEditor({super.key, required this.ctx, this.ev});
  @override
  State<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<EventEditor> {
  late final Json? ev = widget.ev;
  EvCtx get ctx => widget.ctx;
  bool get isNew => ev == null;
  late final _title = TextEditingController(text: str(ev?['title']));
  late final _venue = TextEditingController(text: str(ev?['venue']));
  late final _map = TextEditingController(text: str(ev?['map_url']));
  late final _about = TextEditingController(text: str(ev?['about']));
  late final _max = TextEditingController(text: '${n(ev?['max_per_order'] ?? 10).toInt()}');
  late final _terms = TextEditingController(text: str(ev?['terms']));
  late final _city = TextEditingController(text: str(ev?['city']));
  late final _fbQ = TextEditingController(text: str(obj(ev?['feedback'])['question']));
  late String _kind = str(ev?['kind']).isEmpty ? 'paid' : str(ev?['kind']);
  late String _status = str(ev?['status']).isEmpty ? 'draft' : str(ev?['status']);
  late String _category = str(ev?['category']);
  late bool _fb = obj(ev?['feedback'])['on'] == true;
  late DateTime? _starts = evDate(ev?['starts_at']);
  late DateTime? _ends = evDate(ev?['ends_at']);
  late DateTime? _saleEnds = evDate(ev?['sale_ends_at']);
  late List<String> _pay = [for (final x in (ev?['pay_methods'] as List? ?? const [])) '$x'];
  late final List<_Type> _types = ev == null ? [_Type(name: 'Standard', price: 10, qty: 100), _Type(name: 'VIP', price: 25, qty: 30)] : objs(ev!['types']).map(_Type.of).toList();
  late String _poster = str(ev?['poster']);
  late final EvExtras _x = EvExtras.of(ev);
  bool _busy = false, _posterBusy = false;
  String _error = '';

  @override
  void dispose() {
    for (final c in [_title, _venue, _map, _about, _max, _terms, _city, _fbQ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<DateTime?> _pickWhen(DateTime? cur) async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: cur ?? now, firstDate: DateTime(now.year - 2), lastDate: DateTime(now.year + 5));
    if (d == null || !mounted) return null;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(cur ?? DateTime(now.year, now.month, now.day, 18)));
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Json _body() => {
    'title': _title.text.trim(),
    'kind': _kind,
    'starts_at': _starts?.toUtc().toIso8601String(),
    'ends_at': _ends?.toUtc().toIso8601String(),
    'sale_ends_at': _saleEnds?.toUtc().toIso8601String(),
    'venue': _venue.text.trim(),
    'map_url': _map.text.trim(),
    'about': _about.text,
    'max_per_order': int.tryParse(_max.text.trim()) ?? 10,
    'terms': _terms.text,
    'status': _status,
    'category': _category,
    'city': _city.text.trim(),
    'pay_methods': _pay,
    if (ctx.on('ev_feedback') || obj(ev?['feedback'])['on'] == true) 'feedback': {'on': _fb, 'question': _fbQ.text.trim()},
    ..._x.body(ctx),
    'types': [
      for (final t in _types)
        {
          'key': t.key,
          'name': t.name.text.trim(),
          'price': num.tryParse(t.price.text.trim()) ?? 0,
          'qty': int.tryParse(t.qty.text.trim()) ?? 1,
          'note': t.note.text.trim(),
          'active': t.active,
          if (ctx.on('ev_pricing'))
            'tiers': [
              for (final (l, p, u) in t.tiers)
                if (u != null) {'label': l.text.trim(), 'price': num.tryParse(p.text.trim()) ?? 0, 'until': u.toUtc().toIso8601String()},
            ],
          if (ctx.on('ev_bundles'))
            'bundles': [
              for (final (q, p) in t.bundles)
                if ((int.tryParse(q.text.trim()) ?? 0) >= 2) {'qty': int.tryParse(q.text.trim()) ?? 0, 'price': num.tryParse(p.text.trim()) ?? 0},
            ],
        },
    ],
  };

  Future<void> _save() async {
    if (_status == 'cancelled' && ev?['status'] != 'cancelled' && !await askSure(context, ctx.m('evCancelSure'), ok: ctx.m('save'), cancel: ctx.m('cancel'), danger: true)) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      if (isNew) {
        await ctx.api.post('${ctx.base}/events', _body());
      } else {
        await ctx.api.put('${ctx.base}/events/${ev!['_id']}', _body());
      }
      ctx.notify(ctx.m('saved'));
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      if (e.status == 402 && e.body['product'] != null) {
        ctx.askBuy(str(e.body['product']));
      }
      setState(() => _error = e.network ? ctx.t('app.offline') : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (!await askSure(context, ctx.m('evDeleteSure'), ok: ctx.m('remove'), cancel: ctx.m('cancel'), danger: true)) return;
    setState(() => _busy = true);
    final r = await ctx.run(() => ctx.api.delete('${ctx.base}/events/${ev!['_id']}'));
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) Navigator.pop(context, true);
  }

  Future<void> _upPoster() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 88);
    if (f == null) return;
    setState(() => _posterBusy = true);
    final bytes = await f.readAsBytes();
    final r = await ctx.run(
      () => ctx.api.post('${ctx.base}/events/${ev!['_id']}/poster', FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: 'poster.jpg', contentType: DioMediaType.parse('image/jpeg'))})),
      ctx.m('saved'),
    );
    if (!mounted) return;
    setState(() {
      _posterBusy = false;
      if (r != null) _poster = str(obj(r['data'])['poster']);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final paid = _kind != 'free';
    final ready = ctx.payMethods.where((p) => p['active'] != false && (str(p['qr']).isNotEmpty || str(p['link']).isNotEmpty || str(p['bakong_id']).isNotEmpty)).toList();
    final payMissing = paid && (_pay.isEmpty ? ready : ready.where((p) => _pay.contains(p['key']))).isEmpty;
    Widget when(String label, DateTime? v, ValueChanged<DateTime?> set, {bool clear = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final d = await _pickWhen(v);
                    if (d != null) setState(() => set(d));
                  },
                  icon: const Icon(LucideIcons.calendarDays, size: 16),
                  label: Text(v == null ? ctx.a('pickDate') : evWhen(v, ctx.lang)),
                ),
              ),
              if (clear && v != null) IconButton(tooltip: ctx.a('clear'), onPressed: () => setState(() => set(null)), icon: const Icon(LucideIcons.x, size: 16)),
            ],
          ),
        ],
      ),
    );
    Widget gap() => const SizedBox(height: 12);
    return Scaffold(
      backgroundColor: c.appBg,
      appBar: AppBar(
        title: Text(isNew ? ctx.m('newEvent') : ctx.m('editEvent')),
        actions: [
          if (!isNew)
            IconButton(
              tooltip: ctx.m('evDelete'),
              onPressed: _busy ? null : _delete,
              icon: Icon(LucideIcons.trash2, color: c.danger),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Alert(_error)),
              Btn(ctx.m('save'), icon: LucideIcons.save, busy: _busy, expand: true, onTap: ctx.readOnly || _title.text.trim().isEmpty || _starts == null ? null : _save),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Field(label: ctx.m('evTitle'), hint: ctx.m('evTitlePh'), controller: _title, maxLength: 120, onChanged: (_) => setState(() {})),
                gap(),
                Text(ctx.m('evKind'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'paid', label: Text(ctx.m('kindPaid'))),
                    ButtonSegment(value: 'free', label: Text(ctx.m('kindFree'))),
                  ],
                  selected: {_kind},
                  onSelectionChanged: isNew ? (v) => setState(() => _kind = v.first) : null,
                ),
                const SizedBox(height: 4),
                Muted(paid ? ctx.m('evKindPaidSub') : ctx.m('evKindFreeSub')),
                gap(),
                when(ctx.m('evStarts'), _starts, (d) => _starts = d),
                when(ctx.m('evEnds'), _ends, (d) => _ends = d, clear: true),
                Field(label: ctx.m('evVenue'), hint: ctx.m('evVenuePh'), controller: _venue, maxLength: 160),
                gap(),
                Field(label: ctx.m('evMap'), hint: 'https://maps.app.goo.gl/…', controller: _map, keyboard: TextInputType.url),
                gap(),
                SelectField<String>(
                  label: ctx.m('grow.category'),
                  value: _category,
                  options: [
                    ('', '—'),
                    for (final k in ['music', 'workshop', 'seminar', 'sport', 'party', 'festival', 'food', 'art', 'business', 'kids', 'religion', 'other']) (k, ctx.m('grow.cats.$k')),
                  ],
                  onChanged: (v) => setState(() => _category = v),
                ),
                gap(),
                Field(label: ctx.m('grow.city'), hint: 'Phnom Penh', controller: _city, maxLength: 40),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // poster
          Panel(
            child: Row(
              children: [
                Container(
                  width: 70,
                  height: 90,
                  decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(12)),
                  clipBehavior: Clip.antiAlias,
                  child: _poster.isNotEmpty ? Image(image: netImage(_poster), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.image, color: c.brand),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ctx.m('evPoster'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      if (isNew)
                        Muted(ctx.m('evPosterAfter'))
                      else
                        Btn(ctx.m('evPosterPick'), icon: LucideIcons.imagePlus, kind: BtnKind.ghost, small: true, busy: _posterBusy, onTap: ctx.readOnly ? null : _upPoster),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ticket types
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(ctx.m('evTypes'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Muted(ctx.m('evTypesSub')),
                const SizedBox(height: 10),
                for (var i = 0; i < _types.length; i++) _typeBox(i, paid),
                Btn(
                  ctx.m('evAddType'),
                  icon: LucideIcons.plus,
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: _types.length >= 20 ? null : () => setState(() => _types.add(_Type(name: '', price: paid ? 10 : 0, qty: 50))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (paid && ctx.payMethods.isNotEmpty) ...[
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(ctx.m('pm.forEvent'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final pm in ctx.payMethods)
                        FilterChip(
                          label: Text(str(pm['bank']).isEmpty ? ctx.m('pm.unnamed') : str(pm['bank'])),
                          selected: _pay.isEmpty || _pay.contains(pm['key']),
                          onSelected: (on) {
                            final all = ctx.payMethods.map((x) => str(x['key'])).toList();
                            final cur = _pay.isEmpty ? all : [..._pay];
                            if (on) {
                              cur.add(str(pm['key']));
                            } else {
                              cur.remove(pm['key']);
                            }
                            setState(() => _pay = cur.toSet().length == all.length ? [] : cur.toSet().toList());
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Muted(_pay.isEmpty ? ctx.m('pm.allSub') : ctx.m('pm.someSub')),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (payMissing && _status == 'published')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Alert(ctx.m('needPayFirst'), tone: Tone.warn),
            ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Field(label: ctx.m('evAbout'), hint: ctx.m('evAboutPh'), controller: _about, maxLines: 5),
                gap(),
                Row(
                  children: [
                    Expanded(
                      child: Field(label: ctx.m('evMaxPer'), controller: _max, keyboard: TextInputType.number),
                    ),
                  ],
                ),
                gap(),
                when(ctx.m('evSaleEnds'), _saleEnds, (d) => _saleEnds = d, clear: true),
                Muted(ctx.m('evSaleEndsSub')),
                gap(),
                Field(label: ctx.m('evTerms'), hint: ctx.m('evTermsPh'), controller: _terms, maxLines: 3),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // feedback (ev_feedback)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(ctx.m('grow.fbTitle'), style: const TextStyle(fontWeight: FontWeight.w800)),
                Muted(ctx.m('grow.fbSub')),
                const SizedBox(height: 8),
                EvLocked(
                  ctx: ctx,
                  addon: 'ev_feedback',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile(contentPadding: EdgeInsets.zero, value: _fb, onChanged: (v) => setState(() => _fb = v), title: Text(ctx.m('grow.fbOn'))),
                      if (_fb) Field(label: ctx.m('grow.fbQuestion'), hint: ctx.m('grow.fbQuestionPh'), controller: _fbQ, maxLength: 160),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // status
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(ctx.m('evStatus'), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                for (final s in ['draft', 'published', 'closed', 'cancelled'])
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: s,
                    // ignore: deprecated_member_use (RadioGroup is only in the newest Flutter)
                    groupValue: _status,
                    // ignore: deprecated_member_use
                    onChanged: (v) => setState(() => _status = v ?? _status),
                    title: Text(ctx.m('status.$s')),
                    subtitle: Text(ctx.m('evStatusSub.$s')),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // showtimes, seat map, questions, sponsors
          EvShowsBox(ctx: ctx, x: _x, starts: _starts),
          const SizedBox(height: 12),
          EvSeatsBox(
            ctx: ctx,
            x: _x,
            ev: ev,
            types: [
              for (final t in _types)
                if (t.key.isNotEmpty) (t.key, t.name.text.trim().isEmpty ? t.key : t.name.text.trim()),
            ],
          ),
          const SizedBox(height: 12),
          EvQuestionsBox(ctx: ctx, x: _x),
          const SizedBox(height: 12),
          EvSponsorsBox(ctx: ctx, ev: ev),
        ],
      ),
    );
  }

  Widget _typeBox(int i, bool paid) {
    final c = context.c;
    final t = _types[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Field(hint: ctx.m('evTypeName'), controller: t.name, maxLength: 60),
              ),
              if (paid) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Field(hint: ctx.m('evTypePrice'), controller: t.price, keyboard: const TextInputType.numberWithOptions(decimal: true)),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Field(hint: ctx.m('evTypeQty'), controller: t.qty, keyboard: TextInputType.number),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Field(hint: ctx.m('evTypeNotePh'), controller: t.note, maxLength: 120),
          Row(
            children: [
              Switch(value: t.active, onChanged: (v) => setState(() => t.active = v)),
              Text(ctx.m('evTypeOn'), style: const TextStyle(fontSize: 13)),
              if (t.taken > 0) ...[
                const SizedBox(width: 8),
                Text(ctx.m('sold', {'n': t.taken, 'of': t.qty.text}), style: TextStyle(fontSize: 12, color: c.muted)),
              ],
              const Spacer(),
              IconButton(
                tooltip: ctx.m('remove'),
                onPressed: t.taken > 0 || _types.length < 2 ? null : () => setState(() => _types.removeAt(i)),
                icon: Icon(LucideIcons.trash2, size: 16, color: t.taken > 0 || _types.length < 2 ? c.muted.withValues(alpha: .4) : c.danger),
              ),
            ],
          ),
          if (paid)
            t.open
                ? _deals(t)
                : Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(onPressed: () => setState(() => t.open = true), icon: const Icon(LucideIcons.timer, size: 15), label: Text(ctx.m('grow.dealsOpen'))),
                  ),
        ],
      ),
    );
  }

  Widget _deals(_Type t) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(ctx.m('grow.tiers'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 6),
          EvLocked(
            ctx: ctx,
            addon: 'ev_pricing',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = 0; j < t.tiers.length; j++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Field(hint: ctx.m('grow.tierLabelPh'), controller: t.tiers[j].$1, maxLength: 40),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: Field(hint: '\$', controller: t.tiers[j].$2, keyboard: const TextInputType.numberWithOptions(decimal: true)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 3,
                          child: OutlinedButton(
                            onPressed: () async {
                              final d = await _pickWhen(t.tiers[j].$3);
                              if (d != null) setState(() => t.tiers[j] = (t.tiers[j].$1, t.tiers[j].$2, d));
                            },
                            child: Text(
                              t.tiers[j].$3 == null ? ctx.m('grow.until') : evWhen(t.tiers[j].$3, ctx.lang, year: false),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        IconButton(visualDensity: VisualDensity.compact, onPressed: () => setState(() => t.tiers.removeAt(j)), icon: const Icon(LucideIcons.x, size: 15)),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: t.tiers.length >= 6
                        ? null
                        : () => setState(() {
                            final unit = num.tryParse(t.price.text) ?? 0;
                            t.tiers.add((
                              TextEditingController(text: t.tiers.isEmpty ? ctx.m('grow.earlyBird') : ''),
                              TextEditingController(text: '${(unit - 5 * (t.tiers.length + 1)).clamp(0, 100000).toInt()}'),
                              null,
                            ));
                          }),
                    icon: const Icon(LucideIcons.plus, size: 15),
                    label: Text(ctx.m('grow.addTier')),
                  ),
                ),
                if (t.tiers.isNotEmpty) Muted(ctx.m('grow.tiersHint', {'price': usd2(num.tryParse(t.price.text) ?? 0)})),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(ctx.m('grow.bundles'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 6),
          EvLocked(
            ctx: ctx,
            addon: 'ev_bundles',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = 0; j < t.bundles.length; j++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 70,
                          child: Field(hint: ctx.m('grow.bQty'), controller: t.bundles[j].$1, keyboard: TextInputType.number),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(ctx.m('grow.ticketsFor'), style: TextStyle(color: c.muted, fontSize: 12.5)),
                        ),
                        Expanded(
                          child: Field(hint: '\$', controller: t.bundles[j].$2, keyboard: const TextInputType.numberWithOptions(decimal: true)),
                        ),
                        IconButton(visualDensity: VisualDensity.compact, onPressed: () => setState(() => t.bundles.removeAt(j)), icon: const Icon(LucideIcons.x, size: 15)),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: t.bundles.length >= 5
                        ? null
                        : () => setState(() {
                            final unit = num.tryParse(t.price.text) ?? 0;
                            t.bundles.add((TextEditingController(text: '4'), TextEditingController(text: '${(unit * 4 * .85).round()}')));
                          }),
                    icon: const Icon(LucideIcons.plus, size: 15),
                    label: Text(ctx.m('grow.addBundle')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
