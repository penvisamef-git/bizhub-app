import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../common/shell.dart';
import '../restaurant/rest_common.dart' show SwitchRow;
import 'admin_customers.dart';
import 'admin_parts.dart';

// BizHub team: Users (dashboard/admin/users/UsersPage.jsx) + Activity log (ActivityLogPage.jsx)
// roles are saved as this exact text (bizhub-api/src/util/user_roles.js)
const roleAdmin = 'អ្នកគ្រប់គ្រងប្រព័ន្ធ';
const roleStaff = 'បុគ្គលិក';

String _full(Json u) => '${str(u['firstname'])} ${str(u['lastname'])}'.trim();
String _role(Object? r) => r is Map ? str(r['name']) : str(r);

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});
  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> with PagedLoad {
  String _q = '';
  @override
  String get path => '${Api.admin}/users';
  @override
  Map<String, dynamic> get query => {
    'limit': 20,
    if (_q.isNotEmpty) ...{
      'q': _q,
      'q_key': jsonEncode(['firstname', 'lastname', 'email', 'contact']),
    },
  };

  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  Future<void> _edit([Json? u]) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _UserSheet(u: u),
    );
    if (ok == true) load(reset: true);
  }

  Future<void> _delete(Json u) async {
    final t = ref.read(tProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('app.uDelete')),
        content: Text(t('app.uDeleteAsk', {'name': _full(u)})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('sa.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.c.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('app.uDelete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiProvider).delete('${Api.admin}/users/${u['_id']}');
      if (mounted) toast(context, t('app.uDeleted'));
      load(reset: true);
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> _reset(Json u) async {
    final t = ref.read(tProvider);
    final pw = TextEditingController(), again = TextEditingController();
    var err = '';
    var busy = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t('app.uReset'), style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 4),
              Muted('${_full(u)} (${u['email']})'),
              const SizedBox(height: 14),
              Field(label: t('app.uNewPw'), controller: pw, password: true, autofill: const [AutofillHints.newPassword]),
              const SizedBox(height: 12),
              Field(label: t('app.uConfirmPw'), controller: again, password: true),
              const SizedBox(height: 10),
              Muted(t('app.uResetHint')),
              if (err.isNotEmpty) ...[const SizedBox(height: 10), Alert(err)],
              const SizedBox(height: 14),
              Btn(
                t('sa.save'),
                icon: LucideIcons.keyRound,
                busy: busy,
                onTap: () async {
                  if (pw.text.length < 8) return set(() => err = t('app.uPwShort'));
                  if (pw.text != again.text) return set(() => err = t('app.uPwMismatch'));
                  set(() {
                    busy = true;
                    err = '';
                  });
                  try {
                    final r = await ref.read(apiProvider).put('${Api.admin}/users/reset-password/${u['_id']}', {'password': pw.text});
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) toast(context, str(r['message']).isNotEmpty ? str(r['message']) : t('app.uResetDone'));
                  } on ApiError catch (e) {
                    set(() {
                      busy = false;
                      err = e.message;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final me = str(ref.watch(sessionProvider)?.data['_id']);
    return NotificationListener<ScrollNotification>(
      onNotification: onScroll,
      child: SubPage(
        title: t('messages.navUsers'),
        onRefresh: () => load(reset: true),
        actions: [RoundBtn(LucideIcons.userPlus, size: 42, tip: t('app.uAdd'), onTap: () => _edit())],
        children: [
          SearchBox(
            hint: t('sa.search'),
            onSearch: (v) {
              _q = v;
              load(reset: true);
            },
          ),
          const SizedBox(height: 12),
          if (p.error.isNotEmpty) Alert(p.error),
          if (p.page == 0 && p.loading) const Panel(child: SkelList()),
          if (p.page > 0 && p.rows.isEmpty) Panel(child: Muted(t('sa.noResults'))),
          for (final u in p.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                onTap: () => _edit(u),
                child: Row(
                  children: [
                    Avatar(name: _full(u), size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_full(u).isEmpty ? '-' : _full(u), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          Text(
                            [str(u['job_title']), str(u['email'])].where((e) => e.isNotEmpty).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Chip2(
                                _role(u['role']).isEmpty
                                    ? '-'
                                    : (_role(u['role']) == roleAdmin
                                          ? t('app.uRoleAdmin')
                                          : _role(u['role']) == roleStaff
                                          ? t('app.uRoleStaff')
                                          : _role(u['role'])),
                                tone: Tone.brand,
                              ),
                              statusChip(u['status'] != false, t),
                              if (str(u['_id']) == me) Chip2(t('app.uYou'), tone: Tone.lime),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(LucideIcons.ellipsisVertical, color: c.muted),
                      onSelected: (v) => switch (v) {
                        'edit' => _edit(u),
                        'reset' => _reset(u),
                        _ => _delete(u),
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'edit', child: Text(t('app.uEdit'))),
                        PopupMenuItem(value: 'reset', child: Text(t('app.uReset'))),
                        if (str(u['_id']) != me)
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(t('app.uDelete'), style: TextStyle(color: c.danger)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (p.page > 0 && p.loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _UserSheet extends ConsumerStatefulWidget {
  final Json? u;
  const _UserSheet({this.u});
  @override
  ConsumerState<_UserSheet> createState() => _UserSheetState();
}

class _UserSheetState extends ConsumerState<_UserSheet> {
  late final _first = TextEditingController(text: str(widget.u?['firstname']));
  late final _last = TextEditingController(text: str(widget.u?['lastname']));
  late final _email = TextEditingController(text: str(widget.u?['email']));
  late final _contact = TextEditingController(text: str(widget.u?['contact']));
  final _pw = TextEditingController();
  late final _job = TextEditingController(text: str(widget.u?['job_title']));
  late final _note = TextEditingController(text: str(widget.u?['note']));
  late String _roleV = _role(widget.u?['role']).isEmpty ? roleStaff : _role(widget.u?['role']);
  late bool _on = widget.u?['status'] != false;
  bool _busy = false;
  String _err = '';

  bool get _isNew => widget.u == null;

  Future<void> _save() async {
    final t = ref.read(tProvider);
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty || _email.text.trim().isEmpty || (_isNew && _pw.text.isEmpty)) return setState(() => _err = t('app.uFill'));
    if (_isNew && _pw.text.length < 8) return setState(() => _err = t('app.uPwShort'));
    setState(() {
      _busy = true;
      _err = '';
    });
    final body = {
      'status': _on,
      'firstname': _first.text.trim(),
      'lastname': _last.text.trim(),
      'email': _email.text.trim(),
      'contact': _contact.text.trim(),
      if (_isNew) 'password': _pw.text,
      'job_title': _job.text.trim(),
      'role': _roleV,
      'note': _note.text.trim(),
    };
    try {
      final api = ref.read(apiProvider);
      _isNew ? await api.post('${Api.admin}/users', body) : await api.put('${Api.admin}/users/${widget.u!['_id']}', body);
      if (mounted) {
        toast(context, t('app.uSaved'));
        Navigator.pop(context, true);
      }
    } on ApiError catch (e) {
      setState(() {
        _busy = false;
        _err = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    Widget gap() => const SizedBox(height: 12);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isNew ? t('app.uAdd') : t('app.uEdit'), style: Theme.of(context).textTheme.titleLarge),
            gap(),
            Row(
              children: [
                Expanded(
                  child: Field(label: t('app.uFirst'), controller: _first),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Field(label: t('app.uLast'), controller: _last),
                ),
              ],
            ),
            gap(),
            Field(label: t('messages.email'), controller: _email, keyboard: TextInputType.emailAddress, hint: 'name@example.com'),
            gap(),
            Field(label: t('messages.phone'), controller: _contact, keyboard: TextInputType.phone, hint: '012345678'),
            if (_isNew) ...[
              gap(),
              Field(label: t('app.uPassword'), controller: _pw, password: true, autofill: const [AutofillHints.newPassword]),
            ],
            gap(),
            Field(label: t('app.uJob'), controller: _job, hint: 'Cashier / Manager'),
            gap(),
            Text(t('app.uRole'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final (v, label) in [(roleAdmin, t('app.uRoleAdmin')), (roleStaff, t('app.uRoleStaff'))])
                  ChoiceChip(label: Text(label), selected: _roleV == v, onSelected: (_) => setState(() => _roleV = v)),
              ],
            ),
            gap(),
            Field(label: t('app.uNote'), controller: _note, maxLines: 3),
            SwitchRow(title: t('sa.active'), value: _on, onChanged: (v) => setState(() => _on = v)),
            if (_err.isNotEmpty) ...[Alert(_err), gap()],
            Btn(t('sa.save'), icon: LucideIcons.check, busy: _busy, onTap: _save),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Activity log (read only)
class AdminActivityPage extends ConsumerStatefulWidget {
  const AdminActivityPage({super.key});
  @override
  ConsumerState<AdminActivityPage> createState() => _AdminActivityPageState();
}

class _AdminActivityPageState extends ConsumerState<AdminActivityPage> with PagedLoad {
  String _q = '', _cat = '';
  List<Json> _cats = [];
  @override
  String get path => '${Api.admin}/activity_log';
  @override
  Map<String, dynamic> get query => {
    'limit': 30,
    'category': _cat,
    if (_q.isNotEmpty) ...{
      'q': _q,
      'q_key': jsonEncode(['title', 'description']),
    },
  };

  @override
  void initState() {
    super.initState();
    load(reset: true);
    ref.read(apiProvider).get('${Api.admin}/activity_log/category-all').then((r) {
      if (mounted) setState(() => _cats = objs(r['data']));
    }, onError: (_) {});
  }

  String _catName(String k, dynamic t) => t.or('app.logCat.$k', k);

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    return NotificationListener<ScrollNotification>(
      onNotification: onScroll,
      child: SubPage(
        title: t('messages.navActivity'),
        onRefresh: () => load(reset: true),
        children: [
          SearchBox(
            hint: t('sa.search'),
            onSearch: (v) {
              _q = v;
              load(reset: true);
            },
          ),
          if (_cats.isNotEmpty) ...[
            const SizedBox(height: 10),
            Segs(
              items: [('', t('sa.all')), for (final x in _cats) (str(x['title']), _catName(str(x['title']), t))],
              value: _cat,
              onTap: (v) {
                setState(() => _cat = v);
                load(reset: true);
              },
            ),
          ],
          const SizedBox(height: 12),
          if (p.error.isNotEmpty) Alert(p.error),
          if (p.page == 0 && p.loading) const Panel(child: SkelList()),
          if (p.page > 0 && p.rows.isEmpty) Panel(child: Muted(t('sa.noResults'))),
          if (p.rows.isNotEmpty)
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(children: [for (var i = 0; i < p.rows.length; i++) _row(p.rows[i], t, c, i == p.rows.length - 1)]),
            ),
          if (p.page > 0 && p.loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _row(Json r, dynamic t, C c, bool last) {
    final by = obj(r['create_by_id']);
    final dev = obj(r['device']);
    final cat = str(obj(r['activity_log_category_id'])['title']);
    final icon = switch (cat) {
      'auth' => LucideIcons.logIn,
      'user' => LucideIcons.userRound,
      'setting' => LucideIcons.settings,
      'homepage' => LucideIcons.globe,
      _ => LucideIcons.activity,
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 17, color: c.brandInk),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(str(r['title']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                if (str(r['description']).isNotEmpty) Text(str(r['description']), style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (cat.isNotEmpty) Chip2(_catName(cat, t), tone: Tone.brand),
                    Text(
                      [
                        str(r['time']),
                        if (by.isNotEmpty) _full(by).isNotEmpty ? _full(by) : str(by['email']),
                        if (dev.isNotEmpty) '${str(dev['device'])} · ${str(dev['browser'])}',
                      ].where((e) => e.isNotEmpty).join(' · '),
                      style: TextStyle(fontSize: 11.5, color: c.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
