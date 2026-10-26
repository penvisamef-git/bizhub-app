import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show MHead, GoldBtn, SureDelete, mGap, mDate, todayKH, MLookCard, openLookSheet;
import '../mart/mart_kit.dart' show MSheet, showSheet, DayField, decimalKeys, numOf;
import '../restaurant/rest_common.dart' show Segmented, SwitchRow, gap14;
import 'gh_common.dart';
import 'gh_setup.dart' show GhSave;
import 'gh_stay.dart';

// Promotions (gh_promos) and Customer accounts (gh_customers) + online booking requests — GhPromos.jsx, GhCustomers.jsx, GhRequests.jsx.

Widget _panel(List<Widget> children, {EdgeInsets padding = const EdgeInsets.all(16)}) => Panel(
  padding: padding,
  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
);

num _after(String kind, num value, num price) => switch (kind) {
  'percent' => (price * (1 - value.clamp(0, 100) / 100)).clamp(0, double.infinity),
  'amount' => (price - value).clamp(0, double.infinity),
  _ => value < price ? value : price,
};

// ------------------------------------------------------------------------------------------------ PROMOTIONS
class PromosTab extends StatefulWidget {
  final GhCtx ctx;
  const PromosTab({super.key, required this.ctx});
  @override
  State<PromosTab> createState() => _PromosTabState();
}

class _PromosTabState extends State<PromosTab> {
  Json? _info;
  GhCtx get ctx => widget.ctx;
  String p(String k, [Map<String, Object?> v = const {}]) => ctx.t('gpr.$k', v);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PromosTab old) {
    super.didUpdateWidget(old);
    if (!identical(old.ctx.data, ctx.data)) _load();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/promos');
      if (mounted) setState(() => _info = r);
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _edit(Json row) async {
    final ok = await showSheet<bool>(context, (_) => _PromoEditor(ctx: ctx, row: row));
    if (ok == true) _load();
  }

  Future<void> _toggle(Json r) async {
    if (await ctx.run(() => ctx.api.put('${ctx.base}/promos/${r['_id']}', {'active': r['active'] != true})) != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final info = _info;
    if (info == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 4));
    final on = info['on'] == true;
    final rows = objs(info['data']);
    final today = todayKH();
    String typeName(Object? id) => str(ctx.typeOf(id)?['name']).isEmpty ? '—' : str(ctx.typeOf(id)?['name']);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _panel([
            MHead(p('title'), icon: LucideIcons.badgePercent, sub: on ? p('sub') : p('off', {'price': fmt(n(info['price']))})),
            Align(
              alignment: Alignment.centerLeft,
              child: on
                  ? Btn(p('add'), icon: LucideIcons.plus, small: true, onTap: ctx.readOnly ? null : () => _edit({}))
                  : GoldBtn(p('unlock', {'coins': fmt(n(info['price']))}), onTap: ctx.readOnly ? null : () => ctx.askBuy('gh_promos')),
            ),
          ]),
          mGap,
          if (rows.isEmpty)
            _panel([Icon(LucideIcons.badgePercent, size: 40, color: c.muted), const SizedBox(height: 8), Muted(p('none'), align: TextAlign.center)])
          else
            for (final r in rows) ...[
              () {
                final kind = str(r['kind']);
                final value = n(r['value']);
                final typeIds = (r['type_ids'] as List? ?? const []).map((e) => '$e').toList();
                final (st, label) = r['active'] != true
                    ? ('paused', p('paused'))
                    : str(r['to']).compareTo(today) < 0
                    ? ('ended', p('ended'))
                    : str(r['from']).compareTo(today) > 0
                    ? ('upcoming', p('upcoming', {'date': ghDay(str(r['from']), ctx.lang)}))
                    : ('running', p('running'));
                final tone = switch (st) {
                  'running' => c.good,
                  'upcoming' => const Color(0xFF2563EB),
                  _ => c.muted,
                };
                final sample = ctx.types.where((t) => typeIds.isEmpty || typeIds.contains(t['_id'])).firstOrNull;
                final badge = str(r['badge']).isNotEmpty
                    ? str(r['badge'])
                    : kind == 'percent'
                    ? '-${fmt(value)}%'
                    : kind == 'amount'
                    ? '-${ctx.mo(value)}'
                    : ctx.mo(value);
                return Opacity(
                  opacity: st == 'ended' || st == 'paused' ? .65 : 1,
                  child: Panel(
                    padding: const EdgeInsets.all(14),
                    onTap: ctx.readOnly ? null : () => _edit(r),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          constraints: const BoxConstraints(minWidth: 64),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(14)),
                          child: Text(
                            badge,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(str(r['name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                              Text(
                                label,
                                style: TextStyle(color: tone, fontWeight: FontWeight.w800, fontSize: 12.5),
                              ),
                              const SizedBox(height: 4),
                              Text('📅 ${p('nights', {'from': ghDay(str(r['from']), ctx.lang), 'to': ghDay(str(r['to']), ctx.lang)})}', style: const TextStyle(fontSize: 13)),
                              Text('${p('kinds.$kind')} · ${typeIds.isEmpty ? p('allTypes') : typeIds.map(typeName).join(', ')}', style: TextStyle(fontSize: 12.5, color: c.muted)),
                              if (sample != null)
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(text: '${str(sample['name'])}: '),
                                      TextSpan(
                                        text: ctx.mo(sample['price']),
                                        style: const TextStyle(decoration: TextDecoration.lineThrough),
                                      ),
                                      const TextSpan(text: ' → '),
                                      TextSpan(
                                        text: ctx.mo(_after(kind, value, n(sample['price']))),
                                        style: TextStyle(fontWeight: FontWeight.w800, color: c.ink),
                                      ),
                                      TextSpan(text: ' ${p('perNight')}'),
                                    ],
                                  ),
                                  style: TextStyle(fontSize: 12.5, color: c.muted),
                                ),
                            ],
                          ),
                        ),
                        Switch.adaptive(value: r['active'] == true, onChanged: ctx.readOnly ? null : (_) => _toggle(r)),
                      ],
                    ),
                  ),
                );
              }(),
              mGap,
            ],
        ],
      ),
    );
  }
}

class _PromoEditor extends StatefulWidget {
  final GhCtx ctx;
  final Json row;
  const _PromoEditor({required this.ctx, required this.row});
  @override
  State<_PromoEditor> createState() => _PromoEditorState();
}

class _PromoEditorState extends State<_PromoEditor> with GhSave {
  GhCtx get ctx => widget.ctx;
  @override
  GhCtx get gctx => ctx;
  String p(String k, [Map<String, Object?> v = const {}]) => ctx.t('gpr.$k', v);
  late final isNew = widget.row['_id'] == null;
  late final _name = TextEditingController(text: str(widget.row['name']));
  late final _value = TextEditingController(text: widget.row['value'] == null ? '' : '${n(widget.row['value'])}'.replaceFirst(RegExp(r'\.0$'), ''));
  late final _badge = TextEditingController(text: str(widget.row['badge']));
  late final _note = TextEditingController(text: str(widget.row['note']));
  late String _kind = str(widget.row['kind']).isEmpty ? 'percent' : str(widget.row['kind']);
  late final Set<String> _types = {...(widget.row['type_ids'] as List? ?? const []).map((e) => '$e')};
  late String _from = str(widget.row['from']).isEmpty ? todayKH() : str(widget.row['from']);
  late String _to = str(widget.row['to']).isEmpty ? todayKH() : str(widget.row['to']);
  late bool _active = widget.row['active'] != false;

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    _badge.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final v = numOf(_value.text) ?? 0;
    final body = {
      'name': _name.text.trim(),
      'kind': _kind,
      'value': v,
      'type_ids': _types.toList(),
      'from': _from,
      'to': _to,
      'badge': _badge.text.trim(),
      'note': _note.text.trim(),
      'active': _active,
    };
    final sample = ctx.types.where((t) => _types.isEmpty || _types.contains(t['_id'])).firstOrNull;
    final path = '${ctx.base}/promos';
    return MSheet(
      title: isNew ? p('add') : p('edit'),
      footer: [
        if (!isNew) SureDelete(remove: p('del'), sure: p('sure'), onDelete: busy ? null : () => save(() => ctx.api.delete('$path/${widget.row['_id']}'), reload: false)),
        const Spacer(),
        Btn(p('cancel'), kind: BtnKind.ghost, small: true, onTap: busy ? null : () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(
          p('save'),
          icon: LucideIcons.check,
          small: true,
          busy: busy,
          onTap: busy || _name.text.trim().isEmpty || v <= 0 ? null : () => save(() => isNew ? ctx.api.post(path, body) : ctx.api.put('$path/${widget.row['_id']}', body), reload: false),
        ),
      ],
      children: [
        Field(label: p('name'), hint: p('namePh'), controller: _name, maxLength: 60, autofocus: isNew, onChanged: (_) => setState(() {})),
        gap14,
        Label(p('kind')),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Segmented<String>(
            value: _kind,
            options: [
              for (final k in ['percent', 'amount', 'price']) (k, p('kinds.$k')),
            ],
            onChanged: (k) => setState(() => _kind = k),
          ),
        ),
        gap14,
        Field(label: '${p('value')} ${_kind == 'percent' ? '(%)' : '(${ctx.cur})'}', controller: _value, keyboard: decimalKeys, onChanged: (_) => setState(() {})),
        gap14,
        Label(p('types')),
        Chips<String>(
          options: [('', p('allTypes')), for (final t in ctx.types) (str(t['_id']), str(t['name']))],
          on: (k) => k.isEmpty ? _types.isEmpty : _types.contains(k),
          onTap: (k) => setState(() => k.isEmpty ? _types.clear() : (_types.contains(k) ? _types.remove(k) : _types.add(k))),
        ),
        gap14,
        Row(
          children: [
            Expanded(
              child: DayField(
                label: p('from'),
                value: _from,
                onChanged: (x) => x.isEmpty
                    ? null
                    : setState(() {
                        _from = x;
                        if (_to.compareTo(x) < 0) _to = x;
                      }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DayField(label: p('to'), value: _to, first: DateTime.parse(_from), onChanged: (x) => x.isEmpty ? null : setState(() => _to = x)),
            ),
          ],
        ),
        gap14,
        Field(label: p('badge'), hint: p('badgePh'), controller: _badge, maxLength: 24),
        gap14,
        Field(label: p('note'), controller: _note, maxLength: 200),
        const SizedBox(height: 6),
        SwitchRow(title: p('active'), value: _active, onChanged: (x) => setState(() => _active = x)),
        if (sample != null && v > 0)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(14)),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${str(sample['name'])}: '),
                  TextSpan(
                    text: ctx.mo(sample['price']),
                    style: const TextStyle(decoration: TextDecoration.lineThrough),
                  ),
                  const TextSpan(text: ' → '),
                  TextSpan(
                    text: ctx.mo(_after(_kind, v, n(sample['price']))),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: ' ${p('perNight')} · ${ghDay(_from, ctx.lang)} → ${ghDay(_to, ctx.lang)}'),
                ],
              ),
              style: TextStyle(color: c.brandInk),
            ),
          ),
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ CUSTOMERS
// the 6 looks of the customers' dashboard (gsite/portal/ptext.js + gportal.css)
class GpLook {
  final String en, km, layout;
  final Color bg, fg, card, accent, nav, navFg;
  final List<Color> head;
  const GpLook(this.en, this.km, this.layout, {required this.bg, required this.fg, required this.card, required this.accent, required this.nav, required this.navFg, required this.head});
}

const gpLooks = <String, GpLook>{
  'classic': GpLook(
    'Classic',
    'បុរាណ',
    'side',
    bg: Color(0xFFF5F7F9),
    fg: Color(0xFF0F172A),
    card: Colors.white,
    accent: Color(0xFF0F766E),
    nav: Colors.white,
    navFg: Color(0xFF0F172A),
    head: [Color(0xFF0F766E), Color(0xFF14B8A6)],
  ),
  'ocean': GpLook(
    'Ocean',
    'សមុទ្រ',
    'top',
    bg: Color(0xFFEEF6FB),
    fg: Color(0xFF0B2440),
    card: Colors.white,
    accent: Color(0xFF0891B2),
    nav: Color(0xFF0B3A5B),
    navFg: Color(0xFFE0F2FE),
    head: [Color(0xFF0B3A5B), Color(0xFF0891B2), Color(0xFF38BDF8)],
  ),
  'sunset': GpLook(
    'Sunset',
    'ថ្ងៃលិច',
    'top',
    bg: Color(0xFFFFF7F0),
    fg: Color(0xFF3B1023),
    card: Colors.white,
    accent: Color(0xFFEA580C),
    nav: Colors.white,
    navFg: Color(0xFF3B1023),
    head: [Color(0xFFF97316), Color(0xFFDB2777)],
  ),
  'forest': GpLook(
    'Forest',
    'ព្រៃឈើ',
    'side',
    bg: Color(0xFFF3F1EA),
    fg: Color(0xFF1D2B1F),
    card: Color(0xFFFFFDF7),
    accent: Color(0xFF4D7C0F),
    nav: Color(0xFF14301C),
    navFg: Color(0xFFECFCCB),
    head: [Color(0xFF14301C), Color(0xFF3F6212)],
  ),
  'midnight': GpLook(
    'Midnight',
    'ពាក់កណ្តាលអធ្រាត្រ',
    'side',
    bg: Color(0xFF0B1020),
    fg: Color(0xFFE5E7F5),
    card: Color(0xFF141A2E),
    accent: Color(0xFFA78BFA),
    nav: Color(0xFF070B17),
    navFg: Color(0xFFC7C9E0),
    head: [Color(0xFF312E81), Color(0xFF6D28D9), Color(0xFF0891B2)],
  ),
  'rose': GpLook(
    'Rose',
    'ផ្កាកុលាប',
    'top',
    bg: Color(0xFFFFF1F5),
    fg: Color(0xFF4A1530),
    card: Colors.white,
    accent: Color(0xFFDB2777),
    nav: Colors.white,
    navFg: Color(0xFF4A1530),
    head: [Color(0xFFF472B6), Color(0xFFBE185D)],
  ),
};

// a small picture of the customers' dashboard in one look
class GpThumb extends StatelessWidget {
  final String look, name;
  final List<Json> types;
  final String cur;
  const GpThumb({super.key, required this.look, required this.name, required this.types, required this.cur});
  @override
  Widget build(BuildContext context) {
    final l = gpLooks[look] ?? gpLooks['classic']!;
    final s = TextStyle(color: l.fg, fontSize: 18, fontFamily: 'KantumruyPro');
    Widget bar(double w, Color col, [double h = 12]) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(6)),
    );
    final nav = Container(
      color: l.nav,
      padding: const EdgeInsets.all(18),
      child: l.layout == 'side'
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  style: s.copyWith(color: l.navFg, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 20),
                for (final (i, w) in [120.0, 90.0, 110.0, 80.0].indexed) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: i == 0 ? l.accent.withValues(alpha: .18) : null, borderRadius: BorderRadius.circular(10)),
                    child: bar(w, l.navFg.withValues(alpha: i == 0 ? .9 : .35)),
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            )
          : Row(
              children: [
                Text(
                  name,
                  maxLines: 1,
                  style: s.copyWith(color: l.navFg, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                for (final w in [70.0, 60.0, 80.0]) ...[bar(w, l.navFg.withValues(alpha: .4)), const SizedBox(width: 14)],
              ],
            ),
    );
    final body = Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 120,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: l.head),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Hi, Sophea 👋',
                  style: s.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28),
                ),
                const SizedBox(height: 8),
                bar(220, Colors.white.withValues(alpha: .6)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final (i, t) in types.take(3).indexed) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: l.card, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 70,
                          decoration: BoxDecoration(color: hexColor(str(t['color']), l.accent).withValues(alpha: .25), borderRadius: BorderRadius.circular(10)),
                        ),
                        const SizedBox(height: 8),
                        Text(str(t['name']), maxLines: 1, style: s.copyWith(fontWeight: FontWeight.w800)),
                        Text(
                          '${_money(t['price'], cur)} / night',
                          style: s.copyWith(color: l.accent, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (types.isEmpty)
                Expanded(
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(color: l.card, borderRadius: BorderRadius.circular(16)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: l.card, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                bar(180, l.fg.withValues(alpha: .5)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(color: l.accent, borderRadius: BorderRadius.circular(99)),
                  child: bar(70, Colors.white.withValues(alpha: .85), 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: FittedBox(
        fit: BoxFit.fill,
        child: Container(
          width: 1000,
          height: 625,
          color: l.bg,
          child: l.layout == 'side'
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 230, child: nav),
                    Expanded(child: body),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    nav,
                    Expanded(child: body),
                  ],
                ),
        ),
      ),
    );
  }
}

String _money(Object? v, String cur) => cur == 'KHR' ? '${n(v).round()}៛' : '\$${n(v).toStringAsFixed(0)}';

class CustomersTab extends StatefulWidget {
  final GhCtx ctx;
  final VoidCallback? onCount;
  const CustomersTab({super.key, required this.ctx, this.onCount});
  @override
  State<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<CustomersTab> {
  Json? _info;
  String _tab = 'requests';
  bool _busy = false;
  final _note = TextEditingController();
  GhCtx get ctx => widget.ctx;
  String cu(String k, [Map<String, Object?> v = const {}]) => ctx.t('gcu.$k', v);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CustomersTab old) {
    super.didUpdateWidget(old);
    if (!identical(old.ctx.data, ctx.data)) _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/portal');
      if (!mounted) return;
      setState(() {
        _info = obj(r['data']);
        _note.text = str(_info!['note']);
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _save(Json patch) async {
    setState(() => _busy = true);
    try {
      final r = await ctx.api.put('${ctx.base}/portal', patch);
      if (mounted) setState(() => _info = obj(r['data']));
      ctx.notify(ctx.g('saved'));
    } on ApiError catch (e) {
      if (e.status == 402) {
        ctx.askBuy('gh_portal_theme', item: e.body['item'] == null ? null : str(e.body['item']), onDone: _load);
      } else {
        ctx.fail(e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (info == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 4));
    final addon = obj(info['addon']);
    final on = addon['active'] == true;
    final website = info['website'] == true;
    final site = obj(info['site']);
    final counts = obj(info['counts']);
    final themes = obj(info['themes']);
    final owned = (themes['owned'] as List? ?? const []).map((e) => '$e').toSet()..add('classic');
    final link = str(site['slug']).isNotEmpty ? '${Config.siteUrl}/g/${site['slug']}/account' : '';
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _panel([
            MHead(
              cu('title'),
              icon: LucideIcons.users,
              sub: !website
                  ? cu('needWebsite')
                  : on
                  ? cu('on', {'date': mDate(addon['expires_at'], ctx.lang)})
                  : '${cu('sub')} ${cu('off', {'price': fmt(n(addon['price']))})}',
            ),
            if (!website)
              Align(
                alignment: Alignment.centerLeft,
                child: Btn(cu('goWebsite'), icon: LucideIcons.globe, small: true, onTap: () => ctx.go('website')),
              )
            else if (!on || addon['status'] == 'expiring')
              Align(
                alignment: Alignment.centerLeft,
                child: GoldBtn(on ? cu('renew') : cu('unlock', {'coins': fmt(n(addon['price']))}), onTap: ctx.readOnly ? null : () => ctx.askBuy('gh_customers')),
              ),
          ]),
          if (on) ...[
            mGap,
            _panel([
              SwitchRow(
                title: info['portal_on'] == true ? cu('open') : cu('closed'),
                sub: info['portal_on'] == true ? cu('openSub') : cu('closedSub'),
                value: info['portal_on'] == true,
                onChanged: ctx.readOnly || _busy ? null : (v) => _save({'portal_on': v}),
              ),
              if (link.isNotEmpty && site['published'] == true)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Btn(
                    cu('portalLink'),
                    icon: LucideIcons.externalLink,
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
                  ),
                ),
              gap14,
              Focus(
                onFocusChange: (f) {
                  if (!f && _note.text != str(info['note'])) _save({'note': _note.text});
                },
                child: Field(label: cu('note'), hint: cu('notePh'), controller: _note, maxLength: 300, enabled: !ctx.readOnly),
              ),
            ]),
          ],
          mGap,
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Segmented<String>(
              value: _tab,
              options: [
                ('requests', '${cu('tabs.requests')}${n(counts['pending']) > 0 ? ' (${n(counts['pending'])})' : ''}'),
                ('customers', '${cu('tabs.customers')} ${n(counts['customers'])}'),
                ('looks', cu('tabs.looks')),
              ],
              onChanged: (v) => setState(() => _tab = v),
            ),
          ),
          mGap,
          if (_tab == 'requests')
            RequestsList(
              ctx: ctx,
              onChange: () {
                _load();
                widget.onCount?.call();
              },
            ),
          if (_tab == 'customers') _CustomerList(ctx: ctx),
          if (_tab == 'looks')
            _panel([
              MHead(cu('looksTitle'), icon: LucideIcons.palette, sub: cu('looksSub', {'price': fmt(n(themes['price']))})),
              LayoutBuilder(
                builder: (_, box) {
                  final cols = box.maxWidth > 520 ? 2 : 1;
                  final w = (box.maxWidth - 12 * (cols - 1)) / cols;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final k in gpLooks.keys)
                        SizedBox(
                          width: w,
                          child: () {
                            final cur = str(themes['current']).isEmpty ? 'classic' : str(themes['current']);
                            String status(String x) =>
                                cur == x ? cu('inUse') : (x == 'classic' ? ctx.g('free') : (owned.contains(x) ? ctx.g('owned') : '${fmt(n(themes['price']))} ${ctx.g('coins')}'));
                            Widget thumb(String x) => GpThumb(look: x, name: str(ctx.business['name']), types: ctx.types, cur: ctx.cur);
                            String nm(String x) => ctx.lang == 'km' ? gpLooks[x]!.km : gpLooks[x]!.en;
                            return MLookCard(
                              picture: thumb(k),
                              name: nm(k),
                              on: cur == k,
                              locked: !owned.contains(k),
                              status: status(k),
                              onTap: () => openLookSheet(
                                context,
                                title: cu('looksTitle'),
                                keys: gpLooks.keys.toList(),
                                start: k,
                                current: cur,
                                owned: owned.contains,
                                name: nm,
                                big: (x) => SizedBox(width: 380, child: thumb(x)),
                                status: status,
                                useLabel: cu('use'),
                                buyLabel: (_) => ctx.g('unlock', {'coins': '${fmt(n(themes['price']))} ${ctx.g('coins')}'}),
                                readOnly: ctx.readOnly || _busy,
                                use: (x) async {
                                  await _save({'theme': x});
                                  return true;
                                },
                                buy: (x) => ctx.askBuy('gh_portal_theme', item: x, onDone: _load),
                              ),
                            );
                          }(),
                        ),
                    ],
                  );
                },
              ),
            ]),
        ],
      ),
    );
  }
}

// online booking requests: waiting / all, accept (pick a room) or decline
class RequestsList extends StatefulWidget {
  final GhCtx ctx;
  final VoidCallback? onChange;
  final bool inSheet;
  const RequestsList({super.key, required this.ctx, this.onChange, this.inSheet = false});
  @override
  State<RequestsList> createState() => _RequestsListState();
}

class _RequestsListState extends State<RequestsList> {
  String _status = 'pending';
  List<Json>? _rows;
  int _page = 1, _pages = 1;
  GhCtx get ctx => widget.ctx;
  String cu(String k, [Map<String, Object?> v = const {}]) => ctx.t('gcu.$k', v);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([int p = 1]) async {
    try {
      final r = await ctx.api.get('${ctx.base}/cust-requests', {'status': _status == 'all' ? '' : _status, 'page': '$p'});
      if (!mounted) return;
      setState(() {
        _rows = p == 1 ? objs(r['data']) : [...?_rows, ...objs(r['data'])];
        _page = p;
        _pages = n(obj(r['pagination'])['totalPages']).toInt();
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _act(Widget sheet) async {
    final ok = await showSheet<bool>(context, (_) => sheet);
    if (ok == true) {
      _load();
      widget.onChange?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = _rows;
    return _panel([
      Segmented<String>(
        value: _status,
        options: [('pending', cu('pending')), ('all', cu('all'))],
        onChanged: (v) {
          setState(() {
            _status = v;
            _rows = null;
          });
          _load();
        },
      ),
      const SizedBox(height: 10),
      if (rows == null)
        const SkelList(rows: 3)
      else if (rows.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Muted(cu('none'), align: TextAlign.center),
        )
      else ...[
        for (final r in rows)
          () {
            final cus = obj(r['customer']);
            final st = str(r['status']);
            final tone = switch (st) {
              'pending' => c.warn,
              'accepted' => c.good,
              'declined' => c.danger,
              _ => c.muted,
            };
            final kids = n(r['children']) > 0 ? cu('kids', {'n': n(r['children'])}) : '';
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.line)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 64,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            Text(ghDay(str(r['from']), ctx.lang), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            Text('→ ${ghDay(str(r['to']), ctx.lang)}', style: TextStyle(fontSize: 11, color: c.muted)),
                            Text(cu('nights', {'n': n(r['nights'])}), style: TextStyle(fontSize: 10.5, color: c.muted)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(str(cus['name']).isEmpty ? '—' : str(cus['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                                ),
                                Text(
                                  cu('states.$st'),
                                  style: TextStyle(color: tone, fontWeight: FontWeight.w800, fontSize: 12),
                                ),
                              ],
                            ),
                            Text(
                              '🛏 ${str(r['type_name'])}${obj(r['stay'])['room'] != null ? ' · ${cu('room', {'r': obj(r['stay'])['room']})}' : ''} · 👤 ${cu('guests', {'a': n(r['adults']), 'c': kids})}',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                            if (cus.isNotEmpty)
                              Wrap(
                                spacing: 10,
                                children: [
                                  InkWell(
                                    onTap: () => launchUrl(Uri.parse('tel:${str(cus['phone']).replaceAll(RegExp(r'[^\d+]'), '')}')),
                                    child: Text(
                                      '📞 ${str(cus['phone'])}',
                                      style: TextStyle(color: c.brand, fontSize: 12.5, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Text('✉ ${str(cus['email'])}', style: TextStyle(color: c.muted, fontSize: 12.5)),
                                ],
                              ),
                            _PayTag(ctx: ctx, r: r),
                            if (str(r['note']).isNotEmpty) Text('“${str(r['note'])}”', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12.5)),
                            Text(
                              [
                                if (n(r['estimate']) > 0) cu('estimate', {'v': ctx.mo(r['estimate'])}),
                                mDate(r['created_date'], ctx.lang),
                                if (str(r['decided_by']).isNotEmpty) cu('by', {'name': r['decided_by']}),
                                if (str(r['reason']).isNotEmpty) str(r['reason']),
                              ].join(' · '),
                              style: TextStyle(color: c.muted, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (st == 'pending' && !ctx.readOnly) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Btn(
                            cu('accept'),
                            icon: LucideIcons.check,
                            small: true,
                            expand: true,
                            onTap: () => _act(_AcceptSheet(ctx: ctx, row: r)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Btn(
                            cu('decline'),
                            icon: LucideIcons.x,
                            kind: BtnKind.ghost,
                            small: true,
                            expand: true,
                            onTap: () => _act(_DeclineSheet(ctx: ctx, row: r)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }(),
        if (_page < _pages)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Btn(cu('more'), kind: BtnKind.ghost, small: true, onTap: () => _load(_page + 1)),
          ),
      ],
    ]);
  }
}

class _PayTag extends StatelessWidget {
  final GhCtx ctx;
  final Json r;
  const _PayTag({required this.ctx, required this.r});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final proof = str(obj(r['pay_proof'])['url']).isNotEmpty ? str(obj(r['pay_proof'])['url']) : str(r['proof']);
    if (r['pay_method'] != 'qr') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(ctx.t('gcu.payCash'), style: TextStyle(fontSize: 12, color: c.muted)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: c.goodBg, borderRadius: BorderRadius.circular(99)),
            child: Text(
              '${ctx.t('gcu.paidQr')}${n(r['estimate']) > 0 ? ' · ${ctx.mo(r['estimate'])}' : ''}',
              style: TextStyle(color: c.good, fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          if (proof.isNotEmpty) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: () => showDialog<void>(
                context: context,
                builder: (d) => GestureDetector(
                  onTap: () => Navigator.pop(d),
                  child: InteractiveViewer(child: Image(image: netImage(proof))),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image(image: netImage(proof), width: 34, height: 34, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AcceptSheet extends StatefulWidget {
  final GhCtx ctx;
  final Json row;
  const _AcceptSheet({required this.ctx, required this.row});
  @override
  State<_AcceptSheet> createState() => _AcceptSheetState();
}

class _AcceptSheetState extends State<_AcceptSheet> with GhSave {
  GhCtx get ctx => widget.ctx;
  @override
  GhCtx get gctx => ctx;
  String cu(String k, [Map<String, Object?> v = const {}]) => ctx.t('gcu.$k', v);
  List<Json>? _rooms;
  String _pick = '';
  bool _record = true;

  @override
  void initState() {
    super.initState();
    ctx.api
        .get('${ctx.base}/cust-requests/${widget.row['_id']}/rooms')
        .then((r) {
          if (!mounted) return;
          setState(() {
            _rooms = objs(r['data']);
            _pick = str(_rooms!.firstOrNull?['_id']);
          });
        })
        .catchError((Object e) {
          if (mounted) setState(() => error = e is ApiError ? e.message : '$e');
        });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = widget.row;
    final proof = str(obj(r['pay_proof'])['url']);
    return MSheet(
      title: '${cu('accept')} · ${str(obj(r['customer'])['name'])}',
      footer: [
        const Spacer(),
        Btn(ctx.g('cancel'), kind: BtnKind.ghost, small: true, onTap: busy ? null : () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(
          cu('accept'),
          icon: LucideIcons.check,
          small: true,
          busy: busy,
          onTap: busy || _pick.isEmpty ? null : () => save(() => ctx.api.post('${ctx.base}/cust-requests/${r['_id']}/accept', {'room_id': _pick, 'record_payment': _record})),
        ),
      ],
      children: [
        Text(
          '${str(r['type_name'])} · ${ghDay(str(r['from']), ctx.lang)} → ${ghDay(str(r['to']), ctx.lang)} · ${cu('nights', {'n': n(r['nights'])})}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        gap14,
        Label(cu('pickRoom')),
        if (_rooms == null && error.isEmpty)
          const SkelList(rows: 1)
        else if (_rooms != null && _rooms!.isEmpty)
          Alert(cu('noFree'))
        else if (_rooms != null)
          Chips<String>(
            options: [for (final x in _rooms!) (str(x['_id']), '${str(x['name'])}${str(x['floor']).isNotEmpty ? ' · ${x['floor']}' : ''}')],
            on: (k) => _pick == k,
            onTap: (k) => setState(() => _pick = k),
          ),
        if (r['pay_method'] == 'qr') ...[
          gap14,
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (proof.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image(image: netImage(proof), width: 80, height: 110, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cu('paidQr'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      Muted(cu('checkProof')),
                      if (n(r['estimate']) > 0)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _record,
                          onChanged: (v) => setState(() => _record = v == true),
                          title: Text(cu('recordPay', {'v': ctx.mo(r['estimate'])}), style: const TextStyle(fontSize: 13)),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}

class _DeclineSheet extends StatefulWidget {
  final GhCtx ctx;
  final Json row;
  const _DeclineSheet({required this.ctx, required this.row});
  @override
  State<_DeclineSheet> createState() => _DeclineSheetState();
}

class _DeclineSheetState extends State<_DeclineSheet> with GhSave {
  GhCtx get ctx => widget.ctx;
  @override
  GhCtx get gctx => ctx;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MSheet(
    title: '${ctx.t('gcu.decline')} · ${str(obj(widget.row['customer'])['name'])}',
    footer: [
      const Spacer(),
      Btn(ctx.g('cancel'), kind: BtnKind.ghost, small: true, onTap: busy ? null : () => Navigator.pop(context)),
      const SizedBox(width: 8),
      Btn(
        ctx.t('gcu.decline'),
        kind: BtnKind.danger,
        small: true,
        busy: busy,
        onTap: busy ? null : () => save(() => ctx.api.post('${ctx.base}/cust-requests/${widget.row['_id']}/decline', {'reason': _reason.text.trim()}), reload: false),
      ),
    ],
    children: [
      Field(label: ctx.t('gcu.reason'), hint: ctx.t('gcu.reasonPh'), controller: _reason, maxLength: 200, autofocus: true),
      if (error.isNotEmpty) ...[gap14, Alert(error)],
    ],
  );
}

// the waiting online bookings in a sheet (from the alert bar)
Future<void> openRequests(BuildContext context, GhCtx ctx, VoidCallback onChange) => showSheet<void>(
  context,
  (_) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .85,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text(ctx.t('gcu.sheetTitle'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        RequestsList(ctx: ctx, onChange: onChange, inSheet: true),
      ],
    ),
  ),
);

class _CustomerList extends StatefulWidget {
  final GhCtx ctx;
  const _CustomerList({required this.ctx});
  @override
  State<_CustomerList> createState() => _CustomerListState();
}

class _CustomerListState extends State<_CustomerList> {
  final _q = TextEditingController();
  List<Json>? _rows;
  int _page = 1, _pages = 1;
  Timer? _wait;
  GhCtx get ctx => widget.ctx;
  String cu(String k, [Map<String, Object?> v = const {}]) => ctx.t('gcu.$k', v);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _wait?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _load([int p = 1]) async {
    try {
      final r = await ctx.api.get('${ctx.base}/customers', {'q': _q.text.trim(), 'page': '$p'});
      if (!mounted) return;
      setState(() {
        _rows = p == 1 ? objs(r['data']) : [...?_rows, ...objs(r['data'])];
        _page = p;
        _pages = n(obj(r['pagination'])['totalPages']).toInt();
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _block(Json r) async {
    if (await ctx.run(() => ctx.api.put('${ctx.base}/customers/${r['_id']}', {'blocked': r['blocked'] != true})) != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = _rows;
    return _panel([
      Field(
        controller: _q,
        hint: cu('search'),
        icon: LucideIcons.search,
        onChanged: (_) {
          _wait?.cancel();
          _wait = Timer(const Duration(milliseconds: 300), _load);
        },
      ),
      const SizedBox(height: 8),
      if (rows == null)
        const SkelList(rows: 3)
      else if (rows.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Muted(cu('noCustomers'), align: TextAlign.center),
        )
      else ...[
        for (final r in rows)
          Opacity(
            opacity: r['blocked'] == true ? .55 : 1,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 2),
              onTap: () => showSheet<void>(context, (_) => _CustomerDetail(ctx: ctx, id: str(r['_id']), onBlock: _block)),
              leading: CircleAvatar(
                backgroundColor: c.active,
                child: Text(
                  str(r['name']).isEmpty ? '?' : str(r['name']).substring(0, 1).toUpperCase(),
                  style: TextStyle(color: c.brandInk, fontWeight: FontWeight.w800),
                ),
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(str(r['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  if (r['blocked'] == true) ...[const SizedBox(width: 6), Chip2(cu('blocked'), tone: Tone.danger)],
                ],
              ),
              subtitle: Text(
                '${str(r['phone'])} · ${str(r['email'])}\n${cu('joined', {'date': mDate(r['created_date'], ctx.lang)})} · ${cu('reqs', {'n': n(r['requests'])})}',
                style: TextStyle(fontSize: 12, color: c.muted),
              ),
              isThreeLine: true,
              trailing: Icon(LucideIcons.chevronRight, size: 16, color: c.muted),
            ),
          ),
        if (_page < _pages) Btn(cu('more'), kind: BtnKind.ghost, small: true, onTap: () => _load(_page + 1)),
      ],
    ]);
  }
}

class _CustomerDetail extends StatefulWidget {
  final GhCtx ctx;
  final String id;
  final Future<void> Function(Json) onBlock;
  const _CustomerDetail({required this.ctx, required this.id, required this.onBlock});
  @override
  State<_CustomerDetail> createState() => _CustomerDetailState();
}

class _CustomerDetailState extends State<_CustomerDetail> {
  Json? _d;
  GhCtx get ctx => widget.ctx;
  String cu(String k, [Map<String, Object?> v = const {}]) => ctx.t('gcu.$k', v);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/customers/${widget.id}');
      if (mounted) setState(() => _d = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = _d;
    if (d == null) return const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()));
    final cus = obj(d['customer']);
    final stats = obj(d['stats']);
    return MSheet(
      title: cu('details'),
      footer: [
        const Spacer(),
        Btn(
          cus['blocked'] == true ? cu('unblock') : cu('block'),
          kind: BtnKind.ghost,
          small: true,
          onTap: ctx.readOnly
              ? null
              : () async {
                  await widget.onBlock(cus);
                  _load();
                },
        ),
      ],
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: c.active,
              child: Text(
                str(cus['name']).isEmpty ? '?' : str(cus['name']).substring(0, 1).toUpperCase(),
                style: TextStyle(color: c.brandInk, fontWeight: FontWeight.w800, fontSize: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(str(cus['name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                      ),
                      if (cus['blocked'] == true) ...[const SizedBox(width: 6), Chip2(cu('blocked'), tone: Tone.danger)],
                    ],
                  ),
                  InkWell(
                    onTap: () => launchUrl(Uri.parse('tel:${str(cus['phone']).replaceAll(RegExp(r'[^\d+]'), '')}')),
                    child: Text(
                      '📞 ${str(cus['phone'])}',
                      style: TextStyle(color: c.brand, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text('✉ ${str(cus['email'])}', style: TextStyle(color: c.muted)),
                  Muted('${cu('joined', {'date': mDate(cus['created_date'], ctx.lang)})} · ${cu('lastLogin', {'date': cus['last_login'] != null ? mDate(cus['last_login'], ctx.lang) : cu('never')})}'),
                ],
              ),
            ),
          ],
        ),
        gap14,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (k, v) in [
              ('requests', '${n(stats['requests'])}'),
              ('accepted', '${n(stats['accepted'])}'),
              ('pending', '${n(stats['pending'])}'),
              ('nights', '${n(stats['nights'])}'),
              ('spent', ctx.mo(stats['spent'])),
              ('owed', ctx.mo(stats['owed'])),
            ])
              Container(
                width: 104,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: k == 'owed' && n(stats['owed']) > 0 ? c.dangerBg : c.bg2, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    Text(cu('stats.$k'), style: TextStyle(color: c.muted, fontSize: 11.5)),
                  ],
                ),
              ),
          ],
        ),
        gap14,
        Text(cu('allBookings'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        const SizedBox(height: 6),
        if (objs(d['bookings']).isEmpty) Muted(cu('noBookings')),
        for (final b in objs(d['bookings']))
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${ghDay(str(b['from']), ctx.lang)} → ${ghDay(str(b['to']), ctx.lang)} · ${str(b['type_name'])}${obj(b['stay'])['room'] != null ? ' · ${cu('room', {'r': obj(b['stay'])['room']})}' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                    Chip2(ctx.t.or('gcu.bstates.${b['state']}', str(b['state']))),
                  ],
                ),
                Text(
                  '${cu('nights', {'n': n(b['nights'])})} · ${cu('guests', {
                    'a': n(b['adults']) == 0 ? 1 : n(b['adults']),
                    'c': n(b['children']) > 0 ? cu('kids', {'n': n(b['children'])}) : '',
                  })} · ${cu('asked', {'date': mDate(b['created_date'], ctx.lang)})}',
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
                if (b['stay'] != null)
                  Text(
                    '${cu('total')} ${ctx.mo(obj(b['stay'])['total'])} · ${cu('paid')} ${ctx.mo(obj(b['stay'])['paid'])}${n(obj(b['stay'])['balance']) > 0 ? ' · ${cu('balance')} ${ctx.mo(obj(b['stay'])['balance'])}' : ''}',
                    style: const TextStyle(fontSize: 12.5),
                  )
                else if (n(b['estimate']) > 0)
                  Muted(cu('estimate', {'v': ctx.mo(b['estimate'])})),
                _PayTag(ctx: ctx, r: b),
                if (str(b['note']).isNotEmpty) Text('“${str(b['note'])}”', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12.5)),
                if (str(b['reason']).isNotEmpty) Text('✕ ${str(b['reason'])}', style: TextStyle(color: c.danger, fontSize: 12.5)),
                if (b['stay_id'] != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => openStay(context, ctx, str(b['stay_id']), onChanged: _load),
                      child: Text(cu('openBooking')),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
