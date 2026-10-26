import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';

// Several places (rest_branches / gh_branches) — the web's dashboard/client/branches/BranchesTab.jsx.
// The group, add / remove branches, one report for all. category: "restaurant" | "guest_house".
class BranchesView extends StatefulWidget {
  final String id, category;
  final Api api;
  final T t;
  final bool owned, readOnly;
  final num? price;
  final VoidCallback onBuy;
  final void Function(String text) notify;
  const BranchesView({
    super.key,
    required this.id,
    required this.category,
    required this.api,
    required this.t,
    required this.owned,
    required this.readOnly,
    required this.price,
    required this.onBuy,
    required this.notify,
  });
  @override
  State<BranchesView> createState() => _BranchesViewState();
}

class _BranchesViewState extends State<BranchesView> {
  Json? _g;
  String _error = '', _busy = '';
  String x(String k, [Map<String, Object?> v = const {}]) => widget.t('branches.$k', v);
  String get _base => '${Api.user}/businesses/${widget.id}/branches';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(BranchesView old) {
    super.didUpdateWidget(old);
    if (old.owned != widget.owned) _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.api.get(_base);
      if (mounted) setState(() => _g = obj(r['data']));
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiError ? e.message : '$e');
    }
  }

  Future<void> _link(String bid) async {
    if (_busy.isNotEmpty) return;
    setState(() => _busy = bid);
    try {
      final r = await widget.api.post(_base, {'business_id': bid});
      setState(() => _g = {..._g!, ...obj(r['data']), 'candidates': objs(_g!['candidates']).where((c) => str(c['_id']) != bid).toList()});
      widget.notify(x('saved'));
    } catch (e) {
      widget.notify(e is ApiError ? e.message : '$e');
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Future<void> _unlink(Json s) async {
    if (_busy.isNotEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        content: Text(x('unlinkAsk', {'name': s['name']})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(widget.t('rest.cancel'))),
          TextButton(onPressed: () => Navigator.pop(d, true), child: Text(x('unlink'))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = str(s['_id']));
    try {
      await widget.api.delete('$_base/${s['_id']}');
      await _load();
    } catch (e) {
      widget.notify(e is ApiError ? e.message : '$e');
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final g = _g;
    final cat = widget.category;
    final isBranch = g?['role'] == 'branch';
    final head = Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(14)),
                child: Icon(LucideIcons.network, color: c.brandInk),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(x('title.$cat'), style: Theme.of(context).textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 10),
          Muted(x('sub.$cat')),
          if (!isBranch) ...[
            const SizedBox(height: 10),
            for (final p in widget.t.list('branches.perks.$cat'))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.check, size: 15, color: c.good),
                    const SizedBox(width: 8),
                    Expanded(child: Text(p, style: const TextStyle(height: 1.35))),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: widget.owned
                  ? Chip2(x('owned'), icon: LucideIcons.check, tone: Tone.good)
                  : Btn(x('unlock', {'coins': fmt(widget.price ?? 0)}), lead: const CoinIcon(size: 15), small: true, onTap: widget.readOnly ? null : widget.onBuy),
            ),
          ],
        ],
      ),
    );
    final list = <Widget>[head];
    if (g == null) {
      if (_error.isNotEmpty) list.addAll([const SizedBox(height: 12), Alert(_error)]);
    } else {
      final shops = objs(g['shops']);
      final cands = objs(g['candidates']);
      final showGroup = isBranch || (widget.owned && shops.isNotEmpty);
      if (isBranch) {
        list.addAll([
          const SizedBox(height: 12),
          Alert(x('isBranchOf', {'name': obj(g['main'])['name']}), tone: Tone.brand),
        ]);
      }
      if (showGroup) {
        list.addAll([
          const SizedBox(height: 14),
          Panel(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(x('group'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                for (final s in shops)
                  _shopRow(
                    c,
                    name: str(s['name']),
                    logo: str(s['logo']),
                    sub: '${s['is_main'] == true ? x('main') : x('branch')}${s['status'] == false ? ' · ${x('off')}' : ''}',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (s['here'] == true) Chip2(x('here'), tone: Tone.good),
                        if (s['is_main'] != true && !isBranch)
                          IconButton(
                            tooltip: x('unlink'),
                            onPressed: widget.readOnly || _busy.isNotEmpty ? null : () => _unlink(s),
                            icon: _busy == str(s['_id'])
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : Icon(LucideIcons.unlink, size: 17, color: c.danger),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ]);
      }
      if (!isBranch && widget.owned) {
        list.addAll([
          const SizedBox(height: 14),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(x('linkTitle'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Muted(x('linkSub')),
                const SizedBox(height: 8),
                if (cands.isEmpty) Muted(x('noCandidates')),
                for (final cd in cands)
                  _shopRow(
                    c,
                    name: str(cd['name']),
                    logo: '',
                    trailing: Btn(x('link'), icon: LucideIcons.link2, small: true, busy: _busy == str(cd['_id']), onTap: widget.readOnly || _busy.isNotEmpty ? null : () => _link(str(cd['_id']))),
                  ),
              ],
            ),
          ),
        ]);
      }
      if (showGroup) {
        list.add(const SizedBox(height: 14));
        if (g['active'] != true) {
          list.add(Alert(x('needMain'), tone: Tone.warn));
        } else if (shops.length < 2) {
          list.add(Padding(padding: const EdgeInsets.all(4), child: Muted(x('soloHint'))));
        } else {
          list.add(_Report(id: widget.id, category: cat, api: widget.api, t: widget.t));
        }
      }
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: list),
    );
  }

  Widget _shopRow(C c, {required String name, required String logo, String? sub, required Widget trailing}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(11)),
          clipBehavior: Clip.antiAlias,
          child: logo.isNotEmpty
              ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())
              : Icon(widget.category == 'restaurant' ? LucideIcons.utensilsCrossed : LucideIcons.bedDouble, size: 16, color: c.muted),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
              if (sub != null) Text(sub, style: TextStyle(color: c.muted, fontSize: 12.5)),
            ],
          ),
        ),
        trailing,
      ],
    ),
  );
}

String _today() => DateTime.now().toUtc().add(const Duration(hours: 7)).toIso8601String().substring(0, 10);

class _Report extends StatefulWidget {
  final String id, category;
  final Api api;
  final T t;
  const _Report({required this.id, required this.category, required this.api, required this.t});
  @override
  State<_Report> createState() => _ReportState();
}

class _ReportState extends State<_Report> {
  String _mode = 'day', _day = _today(), _month = _today().substring(0, 7);
  Json? _rep;
  String _error = '';
  int _seq = 0;
  String x(String k, [Map<String, Object?> v = const {}]) => widget.t('branches.$k', v);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() => _error = '');
    try {
      final r = await widget.api.get('${Api.user}/businesses/${widget.id}/branches/report', _mode == 'day' ? {'day': _day} : {'month': _month});
      if (mounted && seq == _seq) setState(() => _rep = obj(r['data']));
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _error = e is ApiError ? e.message : '$e');
    }
  }

  Future<void> _pick() async {
    final now = DateTime.parse(_today());
    if (_mode == 'day') {
      final d = await showDatePicker(context: context, firstDate: DateTime(2024), lastDate: now, initialDate: DateTime.parse(_day));
      if (d == null) return;
      _day = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } else {
      // a month: pick any day in it
      final d = await showDatePicker(context: context, firstDate: DateTime(2024), lastDate: now, initialDate: DateTime.parse('$_month-01'), initialDatePickerMode: DatePickerMode.year);
      if (d == null) return;
      _month = '${d.year}-${d.month.toString().padLeft(2, '0')}';
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rep = _rep;
    final rest = widget.category == 'restaurant';
    final cur = str(rep?['currency']).isEmpty ? 'USD' : str(rep?['currency']);
    String m(Object? v, [String? cc]) => money(v, cc ?? cur);
    final cols = <(String, String, String Function(Json))>[
      if (rest) ...[
        ('sales', x('sales.restaurant'), (s) => m(s['sales'], str(s['currency']).isEmpty ? cur : str(s['currency']))),
        ('count', x('bills.restaurant'), (s) => fmt(s['count'])),
        ('avg', x('avg'), (s) => m(s['avg'], str(s['currency']).isEmpty ? cur : str(s['currency']))),
        ('guests', x('guests'), (s) => fmt(s['guests'])),
        ('voids', x('voids'), (s) => fmt(s['voids'])),
      ] else ...[
        ('sales', x('sales.guest_house'), (s) => m(s['sales'], str(s['currency']).isEmpty ? cur : str(s['currency']))),
        ('checkins', x('checkins'), (s) => fmt(s['checkins'])),
        ('nights', x('nights'), (s) => fmt(s['nights'])),
        ('occupancy', x('occupancy'), (s) => '${n(s['occupancy'])}%'),
        ('in_house', x('inHouse'), (s) => fmt(s['in_house'])),
        ('arrivals', x('arrivals'), (s) => fmt(s['arrivals'])),
        ('departures', x('departures'), (s) => fmt(s['departures'])),
      ],
    ];
    final t = obj(rep?['total']);
    final kpis = rest
        ? [(x('sales.restaurant'), m(t['sales'])), (x('bills.restaurant'), fmt(t['count'])), (x('avg'), m(t['avg'])), (x('guests'), fmt(t['guests']))]
        : [(x('sales.guest_house'), m(t['sales'])), (x('checkins'), fmt(t['checkins'])), (x('occupancy'), '${n(t['occupancy'])}%'), (x('inHouse'), fmt(t['in_house']))];
    num inCur(Json s) =>
        n(s['sales']) *
        (str(s['currency']) == cur || str(s['currency']).isEmpty ? 1 : (cur == 'USD' ? 1 / (n(s['khr_rate']) == 0 ? 4100 : n(s['khr_rate'])) : (n(s['khr_rate']) == 0 ? 4100 : n(s['khr_rate']))));
    final shops = objs(rep?['shops']);
    final max = shops.fold<num>(1, (a, s) => inCur(s) > a ? inCur(s) : a);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(x('report'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 170,
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'day', label: Text(x('day'))),
                    ButtonSegment(value: 'month', label: Text(x('month'))),
                  ],
                  selected: {_mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) {
                    _mode = v.first;
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Btn(
                  _mode == 'day' ? fmtDate('${_day}T00:00:00Z', lang: widget.t.lang) : _month,
                  icon: LucideIcons.calendarDays,
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: _pick,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_error.isNotEmpty)
            Alert(_error)
          else if (rep == null)
            const SkelList(rows: 3)
          else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (k, v) in kpis)
                  Container(
                    width: 140,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(k, style: TextStyle(color: c.muted, fontSize: 12)),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            for (final s in [...shops, null])
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: s == null ? c.active : (s['here'] == true ? c.bg2 : null),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(s == null ? x('all') : str(s['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (s != null) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(value: (inCur(s) / max).clamp(0, 1).toDouble(), minHeight: 5, color: c.brand, backgroundColor: c.bg2),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        for (final (_, label, show) in cols)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: TextStyle(color: c.muted, fontSize: 11.5)),
                              Text(show(s ?? {...t, 'currency': cur}), style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            if (rest) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(LucideIcons.trophy, size: 16, color: c.brandInk),
                  const SizedBox(width: 6),
                  Text(x('best'), style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 6),
              if (objs(rep['best']).isEmpty)
                Muted(x('noSales'))
              else
                for (final (i, b) in objs(rep['best']).indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${i + 1}.',
                            style: TextStyle(color: c.muted, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: Text(str(b['name']), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Text(x('sold', {'n': fmt(b['qty'])}), style: TextStyle(color: c.muted, fontSize: 12.5)),
                      ],
                    ),
                  ),
            ],
          ],
        ],
      ),
    );
  }
}
