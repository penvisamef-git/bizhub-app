import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../event/ev_common.dart' show EvChips, EvHead, EvList, askSure;
import '../mart/mart_common.dart' show GoldBtn;
import '../qrgen/qg_inbox.dart' show shareCsv;
import '../restaurant/rest_common.dart' show Segmented, SwitchRow;
import 'ts_common.dart';

// Grow: promo codes, message the customers, cart reminder, sales report, add-ons (TsGrow.jsx + TsMore.jsx RemindTab)

String _num(String v) => v.replaceAll(RegExp(r'[^\d.]'), '');

// ---------------------------------------------------------------- Promo codes
class PromosTab extends StatefulWidget {
  final TsCtx ctx;
  const PromosTab({super.key, required this.ctx});
  @override
  State<PromosTab> createState() => _PromosTabState();
}

class _PromosTabState extends State<PromosTab> {
  List<Json>? _rows;
  TsCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/promos');
      if (mounted) setState(() => _rows = objs(r['data']));
    } catch (_) {
      if (mounted) setState(() => _rows = []);
    }
  }

  Future<void> _edit([Json? p]) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _PromoSheet(ctx: ctx, promo: p),
    );
    if (ok == true) {
      ctx.notify(ctx.m('saved'));
      _load();
    }
  }

  Future<void> _toggle(Json p) async {
    await ctx.run(() => ctx.api.put('${ctx.base}/promos/${p['_id']}', {'on': p['on'] != true}));
    _load();
  }

  Future<void> _remove(Json p) async {
    if (!await askSure(context, ctx.m('removePromoAsk', {'code': p['code']}), ok: ctx.m('delete'), cancel: ctx.m('cancel'), danger: true)) return;
    await ctx.run(() => ctx.api.delete('${ctx.base}/promos/${p['_id']}'));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final on = ctx.on('ts_promos');
    return EvList(
      onRefresh: _load,
      children: [
        EvHead(
          ctx.m('tabs.promos'),
          sub: ctx.m('promosSub'),
          trailing: on ? Btn(ctx.m('addPromo'), icon: LucideIcons.plus, small: true, onTap: ctx.readOnly ? null : () => _edit()) : null,
        ),
        if (!on)
          TsLocked(ctx: ctx, addon: 'ts_promos')
        else if (_rows == null)
          const SkelList(rows: 3)
        else if (_rows!.isEmpty)
          Panel(
            child: Column(
              children: [
                Icon(LucideIcons.tag, size: 30, color: c.muted),
                const SizedBox(height: 8),
                Muted(ctx.m('noPromos'), align: TextAlign.center),
                const SizedBox(height: 12),
                Btn(ctx.m('addPromo'), icon: LucideIcons.plus, onTap: ctx.readOnly ? null : () => _edit()),
              ],
            ),
          )
        else
          for (final p in _rows!) _promoCard(context, p),
      ],
    );
  }

  Widget _promoCard(BuildContext context, Json p) {
    final c = context.c;
    final ends = tsDate(p['ends_at']);
    final ended = ends != null && ends.isBefore(DateTime.now());
    final full = n(p['max_uses']) > 0 && n(p['used']) >= n(p['max_uses']);
    final off = p['on'] != true || ended || full;
    return Opacity(
      opacity: off ? .65 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.active,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.brand, style: BorderStyle.solid),
                  ),
                  child: Text(
                    str(p['code']),
                    style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2, color: c.brandInk),
                  ),
                ),
                const Spacer(),
                Text(p['kind'] == 'percent' ? '−${fmt(n(p['value']))}%' : '−${ctx.money(p['value'])}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (n(p['min_order']) > 0) TsPill('≥ ${ctx.money(p['min_order'])}'),
                if (ends != null) TsPill(ended ? ctx.m('ended') : ctx.m('until', {'date': tsDay(p['ends_at'], ctx.lang)}), tone: ended ? Tone.danger : Tone.muted),
                TsPill(
                  n(p['max_uses']) > 0 ? ctx.m('usedOf', {'n': fmt(n(p['used'])), 'max': fmt(n(p['max_uses']))}) : ctx.m('usedN', {'n': fmt(n(p['used']))}),
                  tone: full ? Tone.danger : Tone.muted,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Switch.adaptive(value: p['on'] == true, onChanged: ctx.readOnly ? null : (_) => _toggle(p)),
                Text(p['on'] == true ? ctx.m('onWord') : ctx.m('off'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(tooltip: ctx.m('edit'), onPressed: ctx.readOnly ? null : () => _edit(p), icon: const Icon(LucideIcons.pencil, size: 18)),
                IconButton(tooltip: ctx.m('delete'), onPressed: ctx.readOnly ? null : () => _remove(p), icon: const Icon(LucideIcons.trash2, size: 18)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoSheet extends StatefulWidget {
  final TsCtx ctx;
  final Json? promo;
  const _PromoSheet({required this.ctx, this.promo});
  @override
  State<_PromoSheet> createState() => _PromoSheetState();
}

class _PromoSheetState extends State<_PromoSheet> {
  late final Json? p = widget.promo;
  late final _code = TextEditingController(text: str(p?['code']));
  late final _value = TextEditingController(text: p == null ? '' : fmt(n(p!['value'])).replaceAll(',', ''));
  late final _min = TextEditingController(text: p != null && n(p!['min_order']) > 0 ? '${n(p!['min_order'])}' : '');
  late final _max = TextEditingController(text: p != null && n(p!['max_uses']) > 0 ? '${n(p!['max_uses'])}' : '');
  late String _kind = str(p?['kind']).isEmpty ? 'percent' : str(p!['kind']);
  late DateTime? _ends = tsDate(p?['ends_at']);
  late bool _on = p == null || p!['on'] == true;
  bool _busy = false;
  String _error = '';
  TsCtx get ctx => widget.ctx;

  @override
  void dispose() {
    for (final x in [_code, _value, _min, _max]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    final body = {
      'code': _code.text.trim(),
      'kind': _kind,
      'value': num.tryParse(_value.text) ?? 0,
      'min_order': num.tryParse(_min.text) ?? 0,
      'max_uses': int.tryParse(_max.text) ?? 0,
      'ends_at': _ends == null ? null : '${tsYmd(_ends!)}T23:59:59+07:00',
      'on': _on,
    };
    try {
      if (p == null) {
        await ctx.api.post('${ctx.base}/promos', body);
      } else {
        await ctx.api.put('${ctx.base}/promos/${p!['_id']}', body);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.network ? ctx.t('app.offline') : e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sign = ctx.cur == 'KHR' ? '៛' : '\$';
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(p == null ? ctx.m('addPromo') : ctx.m('editPromo'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Alert(_error)),
            Field(
              label: ctx.m('code'),
              controller: _code,
              maxLength: 20,
              hint: 'SAVE10',
              autofocus: p == null,
              onChanged: (v) {
                final up = v.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
                if (up != v) {
                  _code.value = TextEditingValue(
                    text: up,
                    selection: TextSelection.collapsed(offset: up.length),
                  );
                }
                setState(() {});
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 2),
              child: Text(ctx.m('codeHint'), style: TextStyle(fontSize: 12, color: context.c.muted)),
            ),
            const SizedBox(height: 12),
            Segmented<String>(value: _kind, options: [('percent', ctx.m('kinds.percent')), ('amount', ctx.m('kinds.amount'))], onChanged: (v) => setState(() => _kind = v)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Field(
                    label: '${ctx.m('value')} (${_kind == 'percent' ? '%' : sign})',
                    controller: _value,
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => setState(() => _fix(_value, v)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Field(label: '${ctx.m('promoFrom')} ($sign)', controller: _min, hint: '0', keyboard: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => _fix(_min, v)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(ctx.m('endsAt'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(LucideIcons.calendar, size: 16),
                    label: Text(_ends == null ? '—' : tsDay(_ends!.toIso8601String(), ctx.lang)),
                    onPressed: () async {
                      final now = DateTime.now();
                      final d = await showDatePicker(context: context, initialDate: _ends ?? now, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 5));
                      if (d != null) setState(() => _ends = d);
                    },
                  ),
                ),
                if (_ends != null) IconButton(onPressed: () => setState(() => _ends = null), icon: const Icon(LucideIcons.x, size: 18)),
              ],
            ),
            const SizedBox(height: 12),
            Field(label: ctx.m('maxUses'), controller: _max, hint: '0', keyboard: TextInputType.number, onChanged: (v) => _fix(_max, v.replaceAll(RegExp(r'\D'), ''))),
            SwitchRow(title: _on ? ctx.m('onWord') : ctx.m('off'), value: _on, onChanged: (v) => setState(() => _on = v)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Btn(ctx.m('cancel'), kind: BtnKind.ghost, onTap: _busy ? null : () => Navigator.pop(context)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Btn(ctx.m('save'), busy: _busy, onTap: _code.text.trim().isEmpty || _value.text.isEmpty ? null : _save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _fix(TextEditingController x, String v) {
    final clean = _num(v);
    if (clean != v) {
      x.value = TextEditingValue(
        text: clean,
        selection: TextSelection.collapsed(offset: clean.length),
      );
    }
  }
}

// ---------------------------------------------------------------- Message the customers
class MessagesTab extends StatefulWidget {
  final TsCtx ctx;
  const MessagesTab({super.key, required this.ctx});
  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  Json? _d;
  final _text = TextEditingController();
  bool _busy = false;
  TsCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/broadcasts');
      if (mounted) setState(() => _d = obj(r['data']));
    } catch (_) {
      if (mounted) setState(() => _d = {'rows': [], 'reach': 0, 'today': 0, 'per_day': 3});
    }
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    final r = await ctx.run(() => ctx.api.post('${ctx.base}/broadcasts', {'text': _text.text.trim()}));
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) {
      ctx.notify(str(r['message']).isNotEmpty ? str(r['message']) : ctx.m('saved'));
      _text.clear();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final on = ctx.on('ts_broadcast');
    final d = _d;
    final reach = n(d?['reach']).toInt();
    final full = d != null && n(d['today']) >= n(d['per_day']);
    return EvList(
      onRefresh: _load,
      children: [
        EvHead(ctx.m('tabs.messages'), sub: ctx.m('messagesSub')),
        if (!on)
          TsLocked(ctx: ctx, addon: 'ts_broadcast')
        else if (d == null)
          const SkelList(rows: 3)
        else ...[
          TsCard(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: c.active, shape: BoxShape.circle),
                    child: Icon(LucideIcons.send, size: 18, color: c.brand),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ctx.m('reach', {'n': fmt(reach)}), style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text(reach > 0 ? ctx.m('reachHint') : ctx.m('reachNone'), style: TextStyle(fontSize: 12.5, color: c.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TsPill(ctx.m('perDay', {'n': d['today'], 'max': d['per_day']})),
                ],
              ),
              if (d['telegram'] == false) ...[const SizedBox(height: 10), Alert(ctx.m('tgNotReady'), tone: Tone.warn)],
              const SizedBox(height: 12),
              Field(label: ctx.m('message'), controller: _text, hint: ctx.m('messagePh'), maxLines: 4, maxLength: 1000, onChanged: (_) => setState(() {})),
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 2),
                child: Text('${_text.text.length} / 1000', style: TextStyle(fontSize: 12, color: c.muted)),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Btn(
                  _busy ? ctx.m('sending') : ctx.m('sendTo', {'n': fmt(reach)}),
                  icon: LucideIcons.send,
                  busy: _busy,
                  onTap: ctx.readOnly || _text.text.trim().isEmpty || reach == 0 || full || d['telegram'] == false ? null : _send,
                ),
              ),
            ],
          ),
          TsCard(
            title: ctx.m('sentBefore'),
            children: [
              if (objs(d['rows']).isEmpty)
                Muted(ctx.m('noMessages'))
              else
                for (final m in objs(d['rows']))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(str(m['text'])),
                        const SizedBox(height: 3),
                        Text(
                          [
                            tsDay(m['created_date'], ctx.lang),
                            tsAgo(m['created_date'], ctx.t),
                            ctx.m('sentTo', {'n': m['sent']}),
                            if (n(m['failed']) > 0) ctx.m('failedN', {'n': m['failed']}),
                            str(m['by']),
                          ].where((s) => s.isNotEmpty).join(' · '),
                          style: TextStyle(fontSize: 12, color: c.muted),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- Cart reminder + Order again
const _after = [30, 60, 120, 180];

class RemindTab extends StatefulWidget {
  final TsCtx ctx;
  const RemindTab({super.key, required this.ctx});
  @override
  State<RemindTab> createState() => _RemindTabState();
}

class _RemindTabState extends State<RemindTab> {
  Json? _d;
  bool _on = true;
  int _min = 60;
  final _text = TextEditingController();
  bool _busy = false, _filled = false;
  TsCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    if (ctx.on('ts_remind')) _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/carts');
      if (!mounted) return;
      setState(() {
        _d = obj(r['data']);
        if (!_filled) {
          final s = obj(_d!['settings']);
          _on = s['on'] != false;
          _min = n(s['after_min']).toInt() == 0 ? 60 : n(s['after_min']).toInt();
          _text.text = str(s['text']);
          _filled = true;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _d = {
            'rows': [],
            'stats': {'sent': 0, 'back': 0, 'back_total': 0},
          },
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final r = await ctx.run(
      () => ctx.api.put('${ctx.base}/settings', {
        'remind': {'on': _on, 'after_min': _min, 'text': _text.text.trim()},
      }),
      ctx.m('saved'),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) ctx.put({'store': obj(obj(r['data'])['store'])});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final on = ctx.on('ts_remind');
    final d = _d;
    final st = obj(d?['stats']);
    final preview = _text.text.trim().isNotEmpty ? _text.text.replaceAll('{name}', 'Dara').replaceAll('{shop}', ctx.shopName).replaceAll('{n}', '2') : ctx.m('remindDefault');
    return EvList(
      onRefresh: () async => on ? _load() : null,
      children: [
        EvHead(ctx.m('tabs.remind'), sub: ctx.m('remindSub')),
        if (!on)
          TsLocked(ctx: ctx, addon: 'ts_remind')
        else if (d == null)
          const SkelList(rows: 3)
        else ...[
          TsKpis([
            TsKpi(ctx.m('remindStats.sent'), fmt(n(st['sent']))),
            TsKpi(ctx.m('remindStats.back'), fmt(n(st['back']))),
            TsKpi(ctx.m('remindStats.rate'), n(st['sent']) > 0 ? '${(n(st['back']) / n(st['sent']) * 100).round()}%' : '—'),
            TsKpi(ctx.m('remindStats.total'), ctx.money(st['back_total'])),
          ]),
          const SizedBox(height: 14),
          TsCard(
            children: [
              SwitchRow(title: ctx.m('remindOn'), value: _on, onChanged: ctx.readOnly ? null : (v) => setState(() => _on = v)),
              const SizedBox(height: 8),
              Text(ctx.m('remindAfter'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              const SizedBox(height: 8),
              Segmented<int>(
                value: _min,
                options: [
                  for (final m in _after) (m, m < 60 ? ctx.m('minN', {'n': m}) : ctx.m('hourN', {'n': m ~/ 60})),
                ],
                onChanged: ctx.readOnly ? null : (v) => setState(() => _min = v),
              ),
              const SizedBox(height: 12),
              Field(label: ctx.m('remindText'), controller: _text, hint: ctx.m('remindDefault'), maxLines: 3, maxLength: 300, enabled: !ctx.readOnly, onChanged: (_) => setState(() {})),
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 2),
                child: Text(ctx.m('remindTextHint'), style: TextStyle(fontSize: 12, color: c.muted)),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Btn(ctx.m('save'), small: true, busy: _busy, onTap: ctx.readOnly ? null : _save),
              ),
              const SizedBox(height: 14),
              // what the customer gets in Telegram
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFCFE3D1), Color(0xFFE3EEDB)]),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ctx.m('preview'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF4B6B50)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12), bottomRight: Radius.circular(12), bottomLeft: Radius.circular(4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '🛒 ${ctx.shopName}',
                            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1F1A16)),
                          ),
                          const SizedBox(height: 4),
                          Text(preview, style: const TextStyle(color: Color(0xFF1F1A16), fontSize: 13.5)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(color: const Color(0xFFE8F3FB), borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              '🛒 ${ctx.m('finishOrder')}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF2481CC), fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(ctx.m('againHint'), style: const TextStyle(fontSize: 12, color: Color(0xFF4B6B50))),
                  ],
                ),
              ),
            ],
          ),
          TsCard(
            title: ctx.m('leftCarts'),
            children: [
              if (objs(d['rows']).isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      Icon(LucideIcons.shoppingCart, size: 28, color: c.muted),
                      const SizedBox(height: 6),
                      Muted(ctx.m('noCarts'), align: TextAlign.center),
                    ],
                  ),
                )
              else
                for (final r in objs(d['rows']))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Avatar(name: str(r['name']).isEmpty ? 'T' : str(r['name']), size: 36),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(str(r['name']).isEmpty ? 'Telegram' : str(r['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                ['${str(r['username']).isNotEmpty ? '@${r['username']} · ' : ''}${ctx.m('itemsCol')}: ${fmt(n(r['n']))}', tsAgo(r['at'], ctx.t)].join(' · '),
                                style: TextStyle(fontSize: 12, color: c.muted),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(ctx.money(r['total']), style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            TsPill(
                              r['reminded'] == true ? ctx.m('cartReminded') : (r['can_message'] == true ? ctx.m('cartWaiting') : ctx.m('cartNoMsg')),
                              tone: r['reminded'] == true ? Tone.good : (r['can_message'] == true ? Tone.brand : Tone.muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- Sales report
class ReportTab extends StatefulWidget {
  final TsCtx ctx;
  const ReportTab({super.key, required this.ctx});
  @override
  State<ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<ReportTab> {
  int _days = 30;
  Json? _r;
  bool _busy = false;
  TsCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    if (ctx.on('ts_reports')) _load();
  }

  Future<void> _load() async {
    setState(() => _r = null);
    final r = await ctx.run(() => ctx.api.get('${ctx.base}/report', {'days': _days}));
    if (mounted && r != null) setState(() => _r = obj(r['data']));
  }

  Future<void> _excel() async {
    setState(() => _busy = true);
    final r = await ctx.run(() => ctx.api.get('${ctx.base}/report/orders', {'days': _days}));
    if (r != null) {
      final head = ['No', 'Date', 'Status', 'How', 'Table', 'Customer', 'Phone', 'Items', 'Subtotal', 'Discount', 'Promo', 'Delivery', 'Total', 'Pay', 'Paid'];
      final rows = [
        for (final o in objs(r['data']))
          [
            o['no'],
            '${tsDay(o['date'], 'en')} ${tsTime(o['date'])}',
            o['status'],
            o['mode'],
            o['table'],
            o['customer'],
            o['phone'],
            o['items'],
            o['subtotal'],
            o['discount'],
            o['promo'],
            o['fee'],
            o['total'],
            o['pay'],
            o['paid'] == true ? 'yes' : 'no',
          ],
      ];
      try {
        await shareCsv('telegram-store-$_days-days.csv', [head, ...rows]);
      } catch (e) {
        ctx.notify('$e');
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final on = ctx.on('ts_reports');
    final r = _r;
    final cur = str(r?['currency']).isEmpty ? ctx.cur : str(r!['currency']);
    final tot = obj(r?['totals']);
    return EvList(
      onRefresh: () async => on ? _load() : null,
      children: [
        EvHead(
          ctx.m('tabs.report'),
          sub: ctx.m('reportSub'),
          trailing: on ? Btn(ctx.m('excel'), icon: LucideIcons.download, small: true, kind: BtnKind.ghost, busy: _busy, onTap: r == null ? null : _excel) : null,
        ),
        if (!on)
          TsLocked(ctx: ctx, addon: 'ts_reports')
        else ...[
          EvChips(
            items: [
              for (final d in [7, 30, 90]) ('$d', ctx.m('ranges.$d'), null),
            ],
            value: '$_days',
            onPick: (v) {
              _days = int.parse(v);
              _load();
            },
          ),
          const SizedBox(height: 12),
          if (r == null)
            const SkelList(rows: 3)
          else ...[
            TsKpis([
              TsKpi(ctx.m('sales'), tsMoney(tot['sales'], cur)),
              TsKpi(ctx.m('ordersWord'), fmt(n(tot['orders']))),
              TsKpi(ctx.m('avg'), tsMoney(tot['avg'], cur)),
              n(tot['discount']) > 0 ? TsKpi(ctx.m('discounts'), tsMoney(tot['discount'], cur)) : TsKpi(ctx.m('cancelledN'), fmt(n(tot['cancelled']))),
            ]),
            const SizedBox(height: 14),
            TsCard(
              title: ctx.m('byDay'),
              children: [n(tot['orders']) > 0 ? _Bars(rows: objs(r['by_day']), cur: cur) : Muted(ctx.m('noSales'))],
            ),
            TsCard(
              title: ctx.m('best'),
              children: [
                if (objs(r['best']).isEmpty)
                  Muted(ctx.m('noSales'))
                else
                  for (final (i, b) in objs(r['best']).indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${i + 1}.',
                              style: TextStyle(color: c.muted, fontWeight: FontWeight.w700),
                            ),
                          ),
                          Expanded(child: Text(str(b['name']), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Text(ctx.m('sold', {'n': fmt(n(b['qty']))}), style: TextStyle(fontSize: 12, color: c.muted)),
                          const SizedBox(width: 10),
                          Text(tsMoney(b['sales'], cur), style: const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
              ],
            ),
            TsCard(
              title: ctx.m('busy'),
              children: [
                _Hours(hours: [for (final x in (r['hours'] is List ? r['hours'] as List : const [])) n(x)]),
                const SizedBox(height: 16),
                Text(ctx.m('howGet'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 8),
                ..._shares(context, obj(r['modes']), (k) => ctx.m('modes.$k'), (k) => tsModeIcons[k] ?? LucideIcons.shoppingBag),
                const SizedBox(height: 14),
                Text(ctx.m('howPay'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 8),
                ..._shares(context, obj(r['pay']), (k) => ctx.t.maybe('ts.payMethods.$k') ?? (k == 'custom' ? ctx.m('ownPay') : k), (_) => LucideIcons.circleDollarSign),
              ],
            ),
          ],
        ],
      ],
    );
  }

  List<Widget> _shares(BuildContext context, Json m, String Function(String) label, IconData Function(String) icon) {
    final c = context.c;
    final sum = m.values.fold<num>(0, (a, v) => a + n(v));
    final total = sum <= 0 ? 1 : sum;
    return [
      for (final e in m.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(icon(e.key), size: 14, color: c.muted),
              const SizedBox(width: 8),
              SizedBox(
                width: 92,
                child: Text(label(e.key), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: n(e.value) / total, minHeight: 8, backgroundColor: c.chip, color: c.brand),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 36,
                child: Text(
                  fmt(n(e.value)),
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
    ];
  }
}

// sales per day (ts-bars)
class _Bars extends StatelessWidget {
  final List<Json> rows;
  final String cur;
  const _Bars({required this.rows, required this.cur});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final max = rows.fold<num>(1, (a, r) => n(r['sales']) > a ? n(r['sales']) : a);
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final r in rows)
            Expanded(
              child: Tooltip(
                message: '${r['day']} · ${tsMoney(r['sales'], cur)} · ${r['orders']}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: (n(r['sales']) / max).clamp(.02, 1).toDouble(),
                          child: Container(
                            decoration: BoxDecoration(color: n(r['sales']) > 0 ? c.brand : c.line, borderRadius: BorderRadius.circular(3)),
                          ),
                        ),
                      ),
                      if (rows.length <= 31) ...[
                        const SizedBox(height: 3),
                        Text(
                          '${int.tryParse(str(r['day']).length >= 10 ? str(r['day']).substring(8) : '') ?? ''}',
                          style: TextStyle(fontSize: rows.length > 14 ? 7.5 : 10, color: c.muted),
                        ),
                      ],
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

// orders per hour of the day (ts-hours-chart)
class _Hours extends StatelessWidget {
  final List<num> hours;
  const _Hours({required this.hours});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final max = hours.fold<num>(1, (a, v) => v > a ? v : a);
    return SizedBox(
      height: 100,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (h, v) in hours.indexed)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: FractionallySizedBox(
                        heightFactor: (v / max).clamp(.02, 1).toDouble(),
                        child: Container(
                          decoration: BoxDecoration(color: v > 0 ? c.brand.withValues(alpha: .8) : c.line, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(h % 3 == 0 ? '$h' : '', style: TextStyle(fontSize: 9, color: c.muted)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Add-ons
class AddonsTab extends StatelessWidget {
  final TsCtx ctx;
  const AddonsTab({super.key, required this.ctx});
  @override
  Widget build(BuildContext context) {
    final lic = ctx.license;
    final addons = obj(ctx.data['addons']);
    return EvList(
      onRefresh: ctx.reload,
      children: [
        EvHead(ctx.m('addonsTitle'), sub: ctx.m('addonsSub')),
        _AddonCard(
          icon: LucideIcons.send,
          name: ctx.m('badge'),
          price: '${fmt(n(lic['price']))} ${ctx.m('coins')} ${ctx.m('perYear')}',
          what: ctx.m('baseWhat'),
          active: true,
          pill: lic['expires_at'] != null ? ctx.m('endsOn', {'date': tsDay(lic['expires_at'], ctx.lang)}) : ctx.m('unlocked'),
          pillOn: lic['active'] == true,
          action: Btn(ctx.m('renewFor', {'coins': fmt(n(lic['price']))}), small: true, kind: BtnKind.ghost, onTap: ctx.business['status'] == false ? null : () => ctx.askBuy('renew')),
        ),
        for (final e in addons.entries)
          Builder(
            builder: (_) {
              final k = e.key;
              final a = obj(e.value);
              final yearly = a['days'] != null;
              final active = a['active'] == true;
              return _AddonCard(
                icon: tsAddonIcons[k] ?? LucideIcons.puzzle,
                name: ctx.m('addonNames.$k'),
                price: '${fmt(n(a['price']))} ${ctx.m('coins')} ${yearly ? ctx.m('perYear') : '· ${ctx.m('forever')}'}',
                what: ctx.m('addonWhat.$k'),
                active: active,
                pill: active ? (a['expires_at'] != null ? ctx.m('endsOn', {'date': tsDay(a['expires_at'], ctx.lang)}) : ctx.m('unlocked')) : null,
                pillOn: active,
                action: active
                    ? (yearly ? Btn(ctx.m('renewFor', {'coins': fmt(n(a['price']))}), small: true, kind: BtnKind.ghost, onTap: ctx.readOnly ? null : () => ctx.askBuy(k)) : null)
                    : GoldBtn(ctx.m('unlock', {'coins': fmt(n(a['price']))}), onTap: ctx.readOnly ? null : () => ctx.askBuy(k)),
              );
            },
          ),
      ],
    );
  }
}

class _AddonCard extends StatelessWidget {
  final IconData icon;
  final String name, price, what;
  final bool active, pillOn;
  final String? pill;
  final Widget? action;
  const _AddonCard({required this.icon, required this.name, required this.price, required this.what, required this.active, this.pill, this.pillOn = false, this.action});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? c.good.withValues(alpha: .45) : c.line),
        boxShadow: c.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: active ? c.goodBg : c.active, borderRadius: BorderRadius.circular(13)),
                child: Icon(icon, size: 20, color: active ? c.good : c.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const CoinIcon(size: 13),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            price,
                            style: TextStyle(fontSize: 12.5, color: c.muted, fontWeight: FontWeight.w600),
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
          Text(what, style: TextStyle(fontSize: 13.5, color: c.muted, height: 1.45)),
          if (pill != null || action != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (pill != null) Chip2(pill!, icon: LucideIcons.check, tone: pillOn ? Tone.good : Tone.muted),
                ?action,
              ],
            ),
          ],
        ],
      ),
    );
  }
}
