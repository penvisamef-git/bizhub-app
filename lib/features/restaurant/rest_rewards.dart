import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart' show fmt, fmtDate;
import '../../core/theme.dart';
import '../../widgets/buy_sheet.dart';
import '../../widgets/look_sheet.dart';
import '../../widgets/ui.dart';
import 'rest_common.dart';
import 'rest_online.dart' show shareQr;

// Reward points (the web's RewardsTab.jsx): overview, members, the rewards catalogue, the points rules and the customer page.

extension on RestCtx {
  String w(String key, [Map<String, Object?> vars = const {}]) => t('rw.$key', vars);
}

class RewardsSection extends StatefulWidget {
  final RestCtx ctx;
  const RewardsSection({super.key, required this.ctx});
  @override
  State<RewardsSection> createState() => _RewardsSectionState();
}

class _RewardsSectionState extends State<RewardsSection> {
  Json? _data;
  String _view = 'overview';
  RestCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/rewards');
      if (mounted) setState(() => _data = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _save(Json patch) async {
    try {
      final r = await ctx.api.put('${ctx.base}/rewards', patch);
      if (mounted) setState(() => _data = {..._data!, 'settings': obj(r['data'])});
      ctx.notify(ctx.w('saved'));
    } catch (e) {
      ctx.fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 4));
    final on = data['active'] == true;
    final s = obj(data['settings']);
    final head = Panel(
      child: RestHead(
        ctx.w('title'),
        sub: ctx.w('sub'),
        trailing: on ? Switch.adaptive(value: s['enabled'] == true, onChanged: ctx.readOnly ? null : (v) => _save({'enabled': v})) : null,
      ),
    );
    if (!on) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          head,
          gap14,
          AddonPrompt(ctx: ctx, addonKey: 'rest_rewards'),
          gap14,
          _How(ctx: ctx),
        ],
      );
    }
    final views = ['overview', 'members', 'rewards', 'rules', 'page'];
    final top = <Widget>[
      head,
      const SizedBox(height: 12),
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final v in views)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: Text(ctx.w('views.$v')), selected: _view == v, onSelected: (_) => setState(() => _view = v)),
              ),
          ],
        ),
      ),
      gap14,
    ];
    return switch (_view) {
      'members' => _Members(key: const ValueKey('m'), ctx: ctx, top: top, onChanged: _load),
      'rewards' => _Rewards(key: const ValueKey('r'), ctx: ctx, top: top, items: objs(data['items'])),
      'rules' => _Rules(key: const ValueKey('ru'), ctx: ctx, top: top, data: data, save: _save, reload: _load),
      'page' => _CustomerPage(key: const ValueKey('p'), ctx: ctx, top: top, data: data, reload: _load),
      _ => _Overview(ctx: ctx, top: top, data: data, onOpen: () => setState(() => _view = 'members'), reload: _load),
    };
  }
}

String _day(Object? d) => d == null ? '—' : fmtDate(d);

class _How extends StatelessWidget {
  final RestCtx ctx;
  const _How({required this.ctx});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(ctx.w('howTitle'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final (i, x) in ctx.t.list('rw.how').indexed)
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
                  Expanded(child: Text(x, style: const TextStyle(height: 1.4))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// one member in a list
Widget _memberTile(BuildContext context, RestCtx ctx, Json m, VoidCallback onTap) {
  final c = context.c;
  return InkWell(
    onTap: onTap,
    child: Opacity(
      opacity: m['active'] == false ? .5 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Avatar(name: str(m['name']).isEmpty ? str(m['phone']) : str(m['name']), size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(str(m['name']).isEmpty ? '—' : str(m['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(
                    [str(m['phone']), '${fmt(m['visits'])} ${ctx.w('colVisits').toLowerCase()}', _day(m['last_visit'])].where((x) => x.isNotEmpty).join(' · '),
                    style: TextStyle(color: c.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.star, size: 14, color: Color(0xFFE0A21A)),
                    const SizedBox(width: 3),
                    Text(fmt(m['points']), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
                Text(fmtMoney(n(m['total_spent']), ctx.currency), style: TextStyle(color: c.muted, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------------------------------------- overview
class _Overview extends StatelessWidget {
  final RestCtx ctx;
  final List<Widget> top;
  final Json data;
  final VoidCallback onOpen;
  final Future<void> Function() reload;
  const _Overview({required this.ctx, required this.top, required this.data, required this.onOpen, required this.reload});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = obj(data['summary']);
    final tops = objs(data['top']);
    final kpis = [
      (ctx.w('members'), fmt(s['members'])),
      (ctx.w('new30'), fmt(s['new_30d'])),
      (ctx.w('given30'), fmt(s['given_30d'])),
      (ctx.w('used30'), fmt(s['used_30d'])),
      (ctx.w('balance'), fmt(s['balance'])),
    ];
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          ...top,
          LayoutBuilder(
            builder: (_, box) {
              final wd = (box.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final (k, v) in kpis)
                    SizedBox(
                      width: wd,
                      child: Panel(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              k,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          gap14,
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(ctx.w('top'), style: Theme.of(context).textTheme.titleMedium),
                ),
                if (tops.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Muted(ctx.w('noMembers'))),
                for (final m in tops) _memberTile(context, ctx, m, onOpen),
              ],
            ),
          ),
          gap14,
          _How(ctx: ctx),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------- members
class _Members extends StatefulWidget {
  final RestCtx ctx;
  final List<Widget> top;
  final VoidCallback onChanged;
  const _Members({super.key, required this.ctx, required this.top, required this.onChanged});
  @override
  State<_Members> createState() => _MembersState();
}

class _MembersState extends State<_Members> {
  final _q = TextEditingController();
  String _sort = 'new';
  int _page = 1, _pages = 1, _seq = 0;
  List<Json>? _rows;
  bool _exporting = false;
  RestCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_seq;
    try {
      final r = await ctx.api.get('${ctx.base}/rewards/members', {'q': _q.text.trim(), 'sort': _sort, 'page': _page});
      if (mounted && seq == _seq) {
        setState(() {
          _rows = objs(r['data']);
          _pages = n(obj(r['pagination'])['totalPages']).toInt().clamp(1, 99999);
        });
      }
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final r = await ctx.api.get('${ctx.base}/rewards/members/export.csv');
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(utf8.encode(str(r['message'] ?? r['data'])), mimeType: 'text/csv', name: 'members.csv')],
        ),
      );
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _open(String id) async {
    final changed = await showEditor<bool>(
      context,
      builder: (_) => _MemberEditor(ctx: ctx, id: id),
    );
    if (changed == true) {
      _load();
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = _rows;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          ...widget.top,
          Row(
            children: [
              Expanded(
                child: Field(
                  controller: _q,
                  hint: ctx.w('search'),
                  icon: LucideIcons.search,
                  onChanged: (_) {
                    final seq = ++_seq;
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (mounted && seq == _seq) {
                        _page = 1;
                        _load();
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              RoundBtn(LucideIcons.download, tip: ctx.w('export'), onTap: _exporting ? null : _export),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SelectField<String>(
                  value: _sort,
                  options: [
                    for (final k in ['new', 'points', 'spent', 'recent']) (k, ctx.w('sort.$k')),
                  ],
                  onChanged: (v) {
                    setState(() => _sort = v);
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Btn(ctx.w('addMember'), icon: LucideIcons.userPlus, small: true, onTap: ctx.readOnly ? null : () => _open('new')),
            ],
          ),
          gap14,
          if (rows == null)
            const Panel(child: SkelList(rows: 4))
          else if (rows.isEmpty)
            Panel(child: Muted(ctx.w('noMembers')))
          else
            Panel(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (final (i, m) in rows.indexed) ...[if (i > 0) Divider(height: 1, color: c.line, indent: 16, endIndent: 16), _memberTile(context, ctx, m, () => _open(str(m['_id'])))],
                ],
              ),
            ),
          if (_pages > 1)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RoundBtn(
                    LucideIcons.chevronLeft,
                    size: 40,
                    onTap: _page <= 1
                        ? null
                        : () {
                            setState(() => _page--);
                            _load();
                          },
                  ),
                  const SizedBox(width: 12),
                  Muted('$_page / $_pages'),
                  const SizedBox(width: 12),
                  RoundBtn(
                    LucideIcons.chevronRight,
                    size: 40,
                    onTap: _page >= _pages
                        ? null
                        : () {
                            setState(() => _page++);
                            _load();
                          },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberEditor extends StatefulWidget {
  final RestCtx ctx;
  final String id; // "new" or a member id
  const _MemberEditor({required this.ctx, required this.id});
  @override
  State<_MemberEditor> createState() => _MemberEditorState();
}

class _MemberEditorState extends State<_MemberEditor> {
  final _name = TextEditingController(), _phone = TextEditingController(), _bd = TextEditingController(), _note = TextEditingController();
  final _pts = TextEditingController(), _why = TextEditingController();
  bool _active = true, _busy = false, _sure = false, _changed = false;
  Json? _info;
  String _error = '';
  RestCtx get ctx => widget.ctx;
  bool get _isNew => widget.id == 'new';

  @override
  void initState() {
    super.initState();
    if (!_isNew) _load();
  }

  @override
  void dispose() {
    for (final x in [_name, _phone, _bd, _note, _pts, _why]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/rewards/members/${widget.id}');
      final d = obj(r['data']);
      final m = obj(d['member']);
      if (!mounted) return;
      setState(() {
        _info = d;
        if (_name.text.isEmpty && _phone.text.isEmpty) {
          _name.text = str(m['name']);
          _phone.text = str(m['phone']);
          _bd.text = str(m['birthday']);
          _note.text = str(m['note']);
          _active = m['active'] != false;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiError ? e.message : '$e');
    }
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await fn();
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiError ? e.message : '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(() async {
    final body = {'name': _name.text.trim(), 'phone': _phone.text.trim(), 'birthday': _bd.text.trim(), 'note': _note.text.trim(), 'active': _active};
    if (_isNew) {
      await ctx.api.post('${ctx.base}/rewards/members', body);
    } else {
      await ctx.api.put('${ctx.base}/rewards/members/${widget.id}', body);
    }
    if (mounted) Navigator.pop(context, true);
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final info = _info;
    final m = obj(info?['member']);
    final link = info == null ? '' : '${Config.siteUrl}/public/member/${str(m['token'])}';
    final ro = ctx.readOnly;
    return PopScope(
      canPop: !_busy,
      onPopInvokedWithResult: (did, _) {},
      child: EditorFrame(
        title: _isNew ? ctx.w('addMember') : (_name.text.isNotEmpty ? _name.text : _phone.text),
        cancel: ctx.r('cancel'),
        save: ctx.w('save'),
        busy: _busy,
        canSave: _phone.text.trim().isNotEmpty && !ro,
        onSave: _save,
        delete: _changed ? TextButton(onPressed: () => Navigator.pop(context, true), child: Text(ctx.r('close'))) : null,
        children: [
          if (!_isNew && info == null && _error.isEmpty) const SkelList(rows: 2),
          if (!_isNew && info != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(LucideIcons.star, color: Color(0xFFE0A21A), size: 24),
                  const SizedBox(width: 8),
                  Text(fmt(m['points']), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${ctx.w('colPoints')} · ${fmt(m['visits'])} ${ctx.w('colVisits').toLowerCase()} · ${fmtMoney(n(m['total_spent']), ctx.currency)}',
                      style: TextStyle(color: c.muted, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: c.line),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(ctx.w('memberPage'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Muted(ctx.w('memberPageHint')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Btn(
                        ctx.w('copy'),
                        icon: LucideIcons.copy,
                        kind: BtnKind.ghost,
                        small: true,
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: link));
                          ctx.notify(ctx.w('copied'));
                        },
                      ),
                      Btn(
                        'QR',
                        icon: LucideIcons.qrCode,
                        kind: BtnKind.ghost,
                        small: true,
                        onTap: () => shareQr(link, 'member-qr.png', text: link),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            gap14,
          ],
          Field(label: ctx.w('name'), controller: _name, maxLength: 60, onChanged: (_) => setState(() {})),
          gap14,
          Field(label: ctx.w('phone'), controller: _phone, keyboard: TextInputType.phone, maxLength: 20, onChanged: (_) => setState(() {})),
          gap14,
          Field(label: ctx.w('birthday'), hint: '03-14', controller: _bd, maxLength: 10),
          Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Muted(ctx.w('birthdayHint'))),
          gap14,
          Field(label: ctx.w('note'), controller: _note, maxLength: 200),
          if (!_isNew) SwitchRow(title: ctx.w('off'), value: !_active, onChanged: (v) => setState(() => _active = !v)),
          if (!_isNew && info != null) ...[
            const Divider(height: 28),
            Text(ctx.w('adjust'), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Field(controller: _pts, hint: '+50 / -20', keyboard: const TextInputType.numberWithOptions(signed: true), onChanged: (_) => setState(() {})),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Field(controller: _why, hint: ctx.w('reasonPh'), maxLength: 120, onChanged: (_) => setState(() {})),
                ),
              ],
            ),
            Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Muted(ctx.w('adjustHint'))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Btn(
                  ctx.w('apply'),
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: _busy || (int.tryParse(_pts.text.trim()) ?? 0) == 0 || _why.text.trim().isEmpty || ro
                      ? null
                      : () => _run(() async {
                          await ctx.api.post('${ctx.base}/rewards/members/${widget.id}/adjust', {'points': int.parse(_pts.text.trim()), 'note': _why.text.trim()});
                          _pts.clear();
                          _why.clear();
                          _changed = true;
                          await _load();
                        }),
                ),
                _sure
                    ? Btn(
                        ctx.w('resetSure', {'n': fmt(m['points'])}),
                        kind: BtnKind.danger,
                        small: true,
                        onTap: _busy || _why.text.trim().isEmpty || ro
                            ? null
                            : () => _run(() async {
                                await ctx.api.post('${ctx.base}/rewards/members/${widget.id}/reset', {'note': _why.text.trim()});
                                _why.clear();
                                _sure = false;
                                _changed = true;
                                await _load();
                              }),
                      )
                    : Btn(ctx.w('resetOne'), kind: BtnKind.ghost, small: true, onTap: _busy || n(m['points']) == 0 || _why.text.trim().isEmpty || ro ? null : () => setState(() => _sure = true)),
              ],
            ),
            Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Muted(ctx.w('resetHint'))),
            if (objs(info['coupons']).isNotEmpty) ...[
              const Divider(height: 28),
              Text(ctx.w('coupons'), style: const TextStyle(fontWeight: FontWeight.w800)),
              for (final cp in objs(info['coupons']))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(LucideIcons.ticket, size: 18),
                  title: Text(str(cp['name'])),
                  trailing: Text(
                    str(cp['code']),
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800),
                  ),
                ),
            ],
            const Divider(height: 28),
            Text(ctx.w('history'), style: const TextStyle(fontWeight: FontWeight.w800)),
            for (final mv in objs(info['moves']))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          ctx.t.or('rw.moveKinds.${mv['kind']}', str(mv['kind'])),
                          if (str(mv['reward_name']).isNotEmpty) str(mv['reward_name']),
                          if (str(mv['order_number']).isNotEmpty) '#${mv['order_number']}',
                          if (str(mv['note']).isNotEmpty) str(mv['note']),
                          _day(mv['created_date']),
                        ].join(' · '),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      '${n(mv['points']) > 0 ? '+' : ''}${fmt(mv['points'])}',
                      style: TextStyle(fontWeight: FontWeight.w800, color: n(mv['points']) > 0 ? c.good : c.danger),
                    ),
                  ],
                ),
              ),
          ],
          if (_error.isNotEmpty) ...[gap14, Alert(_error)],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------- rewards catalogue
class _Rewards extends StatefulWidget {
  final RestCtx ctx;
  final List<Widget> top;
  final List<Json> items;
  const _Rewards({super.key, required this.ctx, required this.top, required this.items});
  @override
  State<_Rewards> createState() => _RewardsState();
}

class _RewardsState extends State<_Rewards> {
  List<Json>? _rows;
  RestCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/reward-list');
      if (mounted) setState(() => _rows = objs(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  String _itemName(Object? id) => nameOf(widget.items.firstWhere((i) => str(i['_id']) == str(id), orElse: () => {}), ctx.lang);

  String _what(Json x) {
    final k = x['kind'] == 'coupon' ? str(x['coupon_kind']) : str(x['kind']);
    final v = switch (k) {
      'amount' => '−${fmtMoney(n(x['value']), ctx.currency)}',
      'percent' => '−${fmt(x['value'])}%',
      'free_item' => _itemName(x['item_id']),
      _ => '',
    };
    return x['kind'] == 'coupon' ? '${ctx.w('kinds.coupon')}: $v' : (v.isNotEmpty ? v : ctx.w('kinds.${x['kind']}'));
  }

  Json _idea(String k) {
    String first(String key) => ctx.w(key).split(' · ').first;
    final base = <String, dynamic>{'coupon_kind': 'amount', 'note': '', 'active': true, 'value': 0, 'item_id': ''};
    return switch (k) {
      'coffee' => {...base, 'name': first('ideaCoffee'), 'kind': 'free_item', 'points': 50, 'item_id': widget.items.isNotEmpty ? widget.items.first['_id'] : ''},
      'dollar' => {...base, 'name': first('ideaDollar'), 'kind': 'amount', 'points': 30, 'value': ctx.currency == 'KHR' ? 8000 : 2},
      'pct' => {...base, 'name': first('ideaPct'), 'kind': 'percent', 'points': 80, 'value': 10},
      _ => {...base, 'name': first('ideaGift'), 'kind': 'gift', 'points': 150},
    };
  }

  Future<void> _edit(Json row) async {
    final saved = await showEditor<bool>(
      context,
      builder: (_) => _RewardEditor(ctx: ctx, row: row, items: widget.items),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = _rows;
    final ro = ctx.readOnly;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          ...widget.top,
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RestHead(
                  ctx.w('views.rewards'),
                  trailing: Btn(
                    ctx.w('addReward'),
                    icon: LucideIcons.plus,
                    small: true,
                    onTap: ro ? null : () => _edit({'name': '', 'kind': 'free_item', 'points': 50, 'item_id': '', 'value': 0, 'coupon_kind': 'amount', 'note': '', 'active': true}),
                  ),
                ),
                if (rows != null && rows.isEmpty) ...[Muted(ctx.w('noRewards')), const SizedBox(height: 10)],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (k, key) in [('coffee', 'ideaCoffee'), ('dollar', 'ideaDollar'), ('pct', 'ideaPct'), ('gift', 'ideaGift')])
                      Btn(ctx.w(key), icon: LucideIcons.gift, kind: BtnKind.ghost, small: true, onTap: ro ? null : () => _edit(_idea(k))),
                  ],
                ),
              ],
            ),
          ),
          gap14,
          if (rows == null) const Panel(child: SkelList(rows: 3)),
          for (final x in rows ?? <Json>[]) ...[
            Panel(
              padding: const EdgeInsets.all(14),
              onTap: ro ? null : () => _edit(x),
              child: Opacity(
                opacity: x['active'] == false ? .5 : 1,
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(13)),
                      child: Icon(['amount', 'percent', 'coupon'].contains(x['kind']) ? LucideIcons.ticket : LucideIcons.gift, size: 20, color: c.brandInk),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(str(x['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(_what(x), style: TextStyle(color: c.muted, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFFFFC53D).withValues(alpha: .2), borderRadius: BorderRadius.circular(99)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.star, size: 13, color: Color(0xFFB07A00)),
                          const SizedBox(width: 4),
                          Text(
                            fmt(x['points']),
                            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF7A5200)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          Muted(ctx.w('oneMoneyOff')),
        ],
      ),
    );
  }
}

class _RewardEditor extends StatefulWidget {
  final RestCtx ctx;
  final Json row;
  final List<Json> items;
  const _RewardEditor({required this.ctx, required this.row, required this.items});
  @override
  State<_RewardEditor> createState() => _RewardEditorState();
}

class _RewardEditorState extends State<_RewardEditor> {
  late final Json f = {...widget.row};
  late final _name = TextEditingController(text: str(f['name']));
  late final _pts = TextEditingController(text: fmt(f['points']).replaceAll(',', ''));
  late final _val = TextEditingController(text: n(f['value']) == 0 ? '' : '${f['value']}');
  bool _busy = false;
  String _error = '';
  RestCtx get ctx => widget.ctx;

  @override
  void dispose() {
    for (final x in [_name, _pts, _val]) {
      x.dispose();
    }
    super.dispose();
  }

  String get _effect => f['kind'] == 'coupon' ? str(f['coupon_kind']) : str(f['kind']);

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    final e = _effect;
    final body = {
      'name': _name.text.trim(),
      'kind': f['kind'],
      'points': int.tryParse(_pts.text.trim()) ?? 0,
      'item_id': e == 'free_item' ? f['item_id'] : '',
      'value': ['amount', 'percent'].contains(e) ? (num.tryParse(_val.text.trim()) ?? 0) : 0,
      'coupon_kind': f['kind'] == 'coupon' ? f['coupon_kind'] : '',
      'note': f['note'] ?? '',
      'active': f['active'] != false,
    };
    try {
      if (widget.row['_id'] != null) {
        await ctx.api.put('${ctx.base}/reward-list/${widget.row['_id']}', body);
      } else {
        await ctx.api.post('${ctx.base}/reward-list', body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiError ? e.message : '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await ctx.api.delete('${ctx.base}/reward-list/${widget.row['_id']}');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiError ? e.message : '$e';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _effect;
    final cur = ctx.currency;
    return EditorFrame(
      title: widget.row['_id'] != null ? ctx.w('edit') : ctx.w('addReward'),
      cancel: ctx.r('cancel'),
      save: ctx.w('save'),
      busy: _busy,
      canSave: _name.text.trim().isNotEmpty && (int.tryParse(_pts.text.trim()) ?? 0) > 0,
      onSave: _save,
      delete: widget.row['_id'] != null ? DeleteConfirm(ctx: ctx, onDelete: _busy ? null : _remove) : null,
      children: [
        Field(label: ctx.w('name'), controller: _name, maxLength: 60, onChanged: (_) => setState(() {})),
        gap14,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in ['free_item', 'amount', 'percent', 'gift', 'coupon'])
              ChoiceChip(label: Text(ctx.w('kinds.$k')), selected: f['kind'] == k, onSelected: (_) => setState(() => f['kind'] = k)),
          ],
        ),
        const SizedBox(height: 8),
        Muted(ctx.w('kindHint.${f['kind']}')),
        gap14,
        Field(label: ctx.w('pointsCost'), controller: _pts, keyboard: TextInputType.number, onChanged: (_) => setState(() {})),
        if (f['kind'] == 'coupon') ...[
          gap14,
          SelectField<String>(
            label: ctx.w('couponGives'),
            value: str(f['coupon_kind']).isEmpty ? 'amount' : str(f['coupon_kind']),
            options: [
              for (final k in ['amount', 'percent', 'free_item']) (k, ctx.w('kinds.$k')),
            ],
            onChanged: (v) => setState(() => f['coupon_kind'] = v),
          ),
        ],
        if (e == 'free_item') ...[
          gap14,
          SelectField<String>(
            label: ctx.w('item'),
            value: str(f['item_id']),
            options: [('', ctx.w('pickItem')), for (final i in widget.items) (str(i['_id']), '${nameOf(i, ctx.lang)} · ${fmtMoney(n(i['price']), cur)}')],
            onChanged: (v) => setState(() => f['item_id'] = v),
          ),
        ],
        if (e == 'amount' || e == 'percent') ...[
          gap14,
          Field(label: e == 'percent' ? ctx.w('percentV') : '${ctx.w('value')} (${cur == 'KHR' ? '៛' : '\$'})', controller: _val, keyboard: const TextInputType.numberWithOptions(decimal: true)),
        ],
        const SizedBox(height: 6),
        SwitchRow(title: ctx.w('active'), value: f['active'] != false, onChanged: (v) => setState(() => f['active'] = v)),
        if (_error.isNotEmpty) ...[gap14, Alert(_error)],
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------- rules
class _Rules extends StatefulWidget {
  final RestCtx ctx;
  final List<Widget> top;
  final Json data;
  final Future<void> Function(Json patch) save;
  final Future<void> Function() reload;
  const _Rules({super.key, required this.ctx, required this.top, required this.data, required this.save, required this.reload});
  @override
  State<_Rules> createState() => _RulesState();
}

class _RulesState extends State<_Rules> {
  late final Json s = obj(widget.data['settings']);
  late final _step = TextEditingController(text: _num(s['points_per_step']));
  late final _min = TextEditingController(text: _num(s['min_bill']));
  late final Map<String, TextEditingController> _pts = {for (final i in objs(widget.data['items'])) str(i['_id']): TextEditingController(text: _num(i['reward_points'] ?? 0))};
  final _note = TextEditingController(), _word = TextEditingController();
  bool _busy = false;
  RestCtx get ctx => widget.ctx;

  String _num(Object? v) {
    final x = n(v);
    return x == x.roundToDouble() ? '${x.toInt()}' : '$x';
  }

  @override
  void dispose() {
    for (final x in [_step, _min, _note, _word, ..._pts.values]) {
      x.dispose();
    }
    super.dispose();
  }

  List<Json> get _changed => objs(widget.data['items']).where((i) => (num.tryParse(_pts[str(i['_id'])]!.text) ?? 0) != n(i['reward_points'])).toList();

  Future<void> _set(Json patch) async {
    setState(() => s.addAll(patch));
    await widget.save(patch);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cur = ctx.currency;
    final ro = ctx.readOnly;
    final stepLabel = cur == 'KHR' ? fmtMoney(1000, 'KHR') : fmtMoney(1, 'USD');
    final sample = cur == 'KHR' ? 52000 : 12.5;
    final example = s['by_amount'] == true ? ((sample / (cur == 'KHR' ? 1000 : 1)) * (num.tryParse(_step.text) ?? 0)).floor() : 0;
    final total = n(obj(widget.data['summary'])['balance']);
    final changed = _changed;
    final items = objs(widget.data['items']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        ...widget.top,
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchRow(title: ctx.w('byAmount'), value: s['by_amount'] == true, onChanged: ro ? null : (v) => _set({'by_amount': v})),
              if (s['by_amount'] == true) ...[
                const SizedBox(height: 8),
                Focus(
                  onFocusChange: (f) {
                    if (!f && (num.tryParse(_step.text) ?? 0) != n(s['points_per_step'])) _set({'points_per_step': num.tryParse(_step.text) ?? 0});
                  },
                  child: Field(
                    label: ctx.w('perStep', {'step': stepLabel}),
                    controller: _step,
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                    enabled: !ro,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                gap14,
                Focus(
                  onFocusChange: (f) {
                    if (!f && (num.tryParse(_min.text) ?? 0) != n(s['min_bill'])) _set({'min_bill': num.tryParse(_min.text) ?? 0});
                  },
                  child: Field(label: ctx.w('minBill'), controller: _min, keyboard: const TextInputType.numberWithOptions(decimal: true), enabled: !ro),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    ctx.w('example', {'bill': fmtMoney(sample, cur), 'pts': example}),
                    style: TextStyle(fontWeight: FontWeight.w700, color: c.brandInk),
                  ),
                ),
              ],
              const Divider(height: 28),
              SelectField<num>(
                label: ctx.w('expire'),
                value: n(s['expire_months']),
                options: [
                  for (final mth in [0, 3, 6, 12, 24]) (mth, mth == 0 ? ctx.w('expireNever') : ctx.w('months', {'n': mth})),
                ],
                onChanged: ro ? null : (v) => _set({'expire_months': v}),
              ),
              const SizedBox(height: 6),
              SwitchRow(title: ctx.w('mask'), value: s['mask_phone'] == true, onChanged: ro ? null : (v) => _set({'mask_phone': v})),
              const SizedBox(height: 6),
              Muted(ctx.w('rulesNote')),
            ],
          ),
        ),
        gap14,
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(ctx.w('resetAllTitle'), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: c.danger)),
              const SizedBox(height: 6),
              Muted(ctx.w('resetAllSub', {'n': fmt(total)})),
              gap14,
              Field(controller: _note, hint: ctx.w('resetAllReason'), maxLength: 120, onChanged: (_) => setState(() {})),
              const SizedBox(height: 8),
              Field(controller: _word, hint: ctx.w('typeReset'), onChanged: (_) => setState(() {})),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Btn(
                  ctx.w('resetAllBtn'),
                  kind: BtnKind.danger,
                  small: true,
                  busy: _busy,
                  onTap: _busy || _note.text.trim().isEmpty || _word.text != 'RESET' || total == 0 || ro
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            final r = await ctx.api.post('${ctx.base}/rewards/reset-all', {'note': _note.text.trim(), 'confirm': 'RESET'});
                            ctx.notify(ctx.w('resetDone', {'n': obj(r['data'])['reset']}));
                            _note.clear();
                            _word.clear();
                            await widget.reload();
                          } catch (e) {
                            ctx.fail(e);
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                ),
              ),
            ],
          ),
        ),
        gap14,
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchRow(title: ctx.w('byItem'), sub: ctx.w('byItemSub'), value: s['by_item'] == true, onChanged: ro ? null : (v) => _set({'by_item': v})),
              if (s['by_item'] == true) ...[
                const SizedBox(height: 6),
                for (final i in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(nameOf(i, ctx.lang), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        SizedBox(
                          width: 90,
                          child: Field(controller: _pts[str(i['_id'])]!, keyboard: TextInputType.number, align: TextAlign.center, onChanged: (_) => setState(() {})),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Btn(
                    '${ctx.w('saveItems')}${changed.isNotEmpty ? ' · ${changed.length}' : ''}',
                    small: true,
                    busy: _busy,
                    onTap: _busy || changed.isEmpty || ro
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            try {
                              await ctx.api.put('${ctx.base}/rewards/items', {
                                'points': {for (final i in changed) str(i['_id']): num.tryParse(_pts[str(i['_id'])]!.text) ?? 0},
                              });
                              await widget.reload();
                              ctx.notify(ctx.w('saved'));
                            } catch (e) {
                              ctx.fail(e);
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
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

// ------------------------------------------------------------------------------------------- customer page
class _CustomerPage extends StatefulWidget {
  final RestCtx ctx;
  final List<Widget> top;
  final Json data;
  final Future<void> Function() reload;
  const _CustomerPage({super.key, required this.ctx, required this.top, required this.data, required this.reload});
  @override
  State<_CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<_CustomerPage> {
  RestCtx get ctx => widget.ctx;
  String _name(String k) => ctx.t.or('ptheme.$k.${ctx.lang}', k);

  Future<void> _use(String k) async {
    try {
      await ctx.api.put('${ctx.base}/rewards/themes/current', {'theme': k});
      await widget.reload();
    } catch (e) {
      ctx.fail(e);
    }
  }

  void _buy(String k, num price) {
    final s = ctx.settings;
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BuySheet(
        stage: SizedBox(
          width: 240,
          child: PointsMock(theme: k, color: str(s['color']), shop: _shop, logo: str(obj(s['logo'])['url'])),
        ),
        badge: ctx.w('looksTitle'),
        title: ctx.w('buyLook', {'name': _name(k)}),
        sub: ctx.w('buyLookSub'),
        perks: [ctx.w('lookPerk'), '${ctx.w('yearly')} · 365'],
        price: price,
        buyLabel: ctx.r('buy', {'coins': '${fmt(price)} ${ctx.r('coins')}'}),
        doneTitle: ctx.r('unlockedTag'),
        doneSub: ctx.w('doneLook', {'name': _name(k)}),
        doneButton: ctx.t('app.continue'),
        buy: () => ctx.api.post('${ctx.base}/rewards/themes/$k'),
        onDone: (_) => widget.reload().then((_) => _use(k)),
      ),
    );
  }

  // tap a look → the look sheet over all of them (swipe): Use · Buy (yearly) · Renew
  Future<void> _openLooks(List<String> all, String start) => showLookSheet(
    context,
    title: ctx.w('looksTitle'),
    count: all.length,
    initial: all.contains(start) ? all.indexOf(start) : 0,
    item: (context, i, refresh) {
      final k = all[i];
      final L = obj(widget.data['themes']);
      List<String> ls(String x) => ((L[x] as List?) ?? const []).map((e) => '$e').toList();
      final free = ls('free').contains(k), owned = ls('owned').contains(k);
      final on = str(L['live']) == k;
      final price = n(L['price']);
      final s = ctx.settings;
      final buyLabel = '${fmt(price)} ${ctx.r('coins')} / ${ctx.w('yearly').toLowerCase()}';
      return LookItem(
        name: _name(k),
        sub: owned ? ctx.w('until', {'d': _day(obj(L['until'])[k])}) : ctx.t.or('ptheme.$k.d_${ctx.lang}', ''),
        preview: SizedBox(
          width: 320,
          child: PointsMock(theme: k, color: str(s['color']), shop: _shop, logo: str(obj(s['logo'])['url'])),
        ),
        badge: on ? ctx.x2('inUse') : (free ? ctx.x2('free') : (owned ? ctx.x2('owned') : buyLabel)),
        badgeTone: on || free || owned ? Tone.good : Tone.warn,
        acts: [
          if (!on && (free || owned))
            LookAct(
              ctx.x2('use'),
              icon: LucideIcons.check,
              onTap: ctx.readOnly
                  ? null
                  : () async {
                      await _use(k);
                      return true;
                    },
            ),
          if (!free && !owned)
            LookAct(
              ctx.r('buy', {'coins': buyLabel}),
              gold: true,
              onTap: ctx.readOnly
                  ? null
                  : () async {
                      Future.microtask(() => _buy(k, price));
                      return true;
                    },
            ),
          if (owned)
            LookAct(
              ctx.w('renew'),
              gold: true,
              onTap: ctx.readOnly
                  ? null
                  : () async {
                      Future.microtask(() => _buy(k, price));
                      return true;
                    },
            ),
        ],
      );
    },
  );

  String get _shop => str(ctx.settings['name_km']).isNotEmpty ? str(ctx.settings['name_km']) : str(ctx.settings['name_en']);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final link = '${Config.siteUrl}/public/points/${str(widget.data['check_token'])}';
    final L = obj(widget.data['themes']);
    List<String> ls(String k) => ((L[k] as List?) ?? const []).map((e) => '$e').toList();
    final free = ls('free'), paid = ls('paid'), owned = ls('owned');
    final until = obj(L['until']);
    final price = n(L['price']);
    final s = ctx.settings;
    return RefreshIndicator(
      onRefresh: widget.reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          ...widget.top,
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RestHead(ctx.w('checkTitle'), sub: ctx.w('checkSub')),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.line),
                    ),
                    child: _Qr(link),
                  ),
                ),
                const SizedBox(height: 10),
                Muted(ctx.w('checkPrivacy')),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Btn(
                      ctx.w('open'),
                      icon: LucideIcons.externalLink,
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
                    ),
                    Btn(
                      ctx.w('copy'),
                      icon: LucideIcons.copy,
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: link));
                        ctx.notify(ctx.w('copied'));
                      },
                    ),
                    Btn(
                      ctx.w('download'),
                      icon: LucideIcons.download,
                      small: true,
                      onTap: () => shareQr(link, 'check-my-points-qr.png', text: link),
                    ),
                  ],
                ),
              ],
            ),
          ),
          gap14,
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RestHead(ctx.w('looksTitle'), sub: ctx.w('looksSub', {'price': fmt(price)})),
                if (str(L['current']) != str(L['live'])) ...[Alert(ctx.w('expired'), tone: Tone.warn), const SizedBox(height: 10)],
                LayoutBuilder(
                  builder: (_, box) {
                    final cols = box.maxWidth > 520 ? 3 : 2;
                    final wd = (box.maxWidth - 10 * (cols - 1)) / cols;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final k in [...free, ...paid])
                          SizedBox(
                            width: wd,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _openLooks([...free, ...paid], k),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: str(L['live']) == k ? c.good : c.line, width: str(L['live']) == k ? 2 : 1),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      IgnorePointer(
                                        child: PointsMock(theme: k, color: str(s['color']), shop: _shop, logo: str(obj(s['logo'])['url'])),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _name(k),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 2),
                                      str(L['live']) == k
                                          ? Row(
                                              children: [
                                                Icon(LucideIcons.check, size: 14, color: c.good),
                                                const SizedBox(width: 3),
                                                Text(
                                                  ctx.x2('inUse'),
                                                  style: TextStyle(color: c.good, fontWeight: FontWeight.w700, fontSize: 12),
                                                ),
                                              ],
                                            )
                                          : Text(
                                              free.contains(k) ? ctx.x2('free') : (owned.contains(k) ? ctx.w('until', {'d': _day(until[k])}) : '${fmt(price)} / ${ctx.w('yearly').toLowerCase()}'),
                                              style: TextStyle(color: owned.contains(k) ? c.good : c.muted, fontSize: 12, fontWeight: FontWeight.w700),
                                            ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension on RestCtx {
  String x2(String key) => t('extras.$key');
}

class _Qr extends StatelessWidget {
  final String data;
  const _Qr(this.data);
  @override
  Widget build(BuildContext context) => QrImageView(
    data: data,
    size: 170,
    padding: EdgeInsets.zero,
    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF16171B)),
    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF16171B)),
  );
}

// a small made-up member card in one look (PointsMock on the web, member.css looks)
class PointsMock extends StatelessWidget {
  final String theme, color, shop, logo;
  const PointsMock({super.key, required this.theme, required this.color, required this.shop, required this.logo});
  @override
  Widget build(BuildContext context) {
    final c0 = Color(0xFF000000 | (int.tryParse(color.replaceFirst('#', ''), radix: 16) ?? 0xE0581A));
    final (page, cardA, cardB, fg, accent, border) = switch (theme) {
      'gold' => (const Color(0xFF111111), const Color(0xFF1B1B1B), const Color(0xFF2C2618), const Color(0xFFF5ECD2), const Color(0xFFD4AF37), const Color(0xFFD4AF37)),
      'midnight' => (const Color(0xFF0D1020), const Color(0xFF1B2250), const Color(0xFF0D1020), const Color(0xFFE6E9FF), const Color(0xFF7C9CFF), const Color(0xFF2A3266)),
      'pastel' => (const Color(0xFFFFF4F6), const Color(0xFFFFC2D1), const Color(0xFFB8F0E0), const Color(0xFF4A2A35), const Color(0xFFFF8FAB), null),
      'kraft' => (const Color(0xFFEFE4D2), const Color(0xFFC9A27A), const Color(0xFFB88F66), const Color(0xFF3B2A20), const Color(0xFF8B5A3C), null),
      'neon' => (const Color(0xFF08080F), const Color(0xFF14141F), const Color(0xFF0D0D18), Colors.white, const Color(0xFF25E2FF), const Color(0xFFFF2EA6)),
      'khmer' => (const Color(0xFFFBF3E6), const Color(0xFF8F1414), const Color(0xFF5E0D0D), const Color(0xFFF5E6C8), const Color(0xFFC99A2E), const Color(0xFFC99A2E)),
      _ => (const Color(0xFFF6F5F2), Color.lerp(c0, Colors.black, .3)!, c0, Colors.white, Colors.white, null),
    };
    final dark = page.computeLuminance() < .2;
    final rowBg = dark ? Color.lerp(page, Colors.white, .07)! : Colors.white;
    final rowFg = dark ? fg : const Color(0xFF17181C);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: page, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(theme == 'pastel' ? 20 : 14),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [cardA, cardB]),
              border: border == null ? null : Border.all(color: border, width: theme == 'khmer' ? 2 : 1),
            ),
            child: DefaultTextStyle(
              style: TextStyle(color: fg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                        clipBehavior: Clip.antiAlias,
                        child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.chefHat, size: 12, color: c0),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          shop,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(LucideIcons.star, size: 15, color: accent),
                      const SizedBox(width: 4),
                      Text(
                        '128',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: theme == 'classic' ? fg : accent, height: 1),
                      ),
                      const SizedBox(width: 3),
                      const Text('pts', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Lita', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                  Text('••• 678 · 12 visits', style: TextStyle(fontSize: 9, color: fg.withValues(alpha: .75))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: rowBg, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Icon(LucideIcons.gift, size: 13, color: theme == 'classic' ? c0 : accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Free drink',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: rowFg),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        height: 4,
                        decoration: BoxDecoration(color: theme == 'classic' ? c0 : accent, borderRadius: BorderRadius.circular(9)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '100',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: rowFg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
