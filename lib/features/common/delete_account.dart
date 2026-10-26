import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/firebase_rest.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../auth/auth_shell.dart' show GoogleButton;
import '../auth/login_page.dart' show authErrorText;

// "Delete my account" (Google Play / App Store rule) — the web's dashboard/client/account/DeleteAccount.jsx.
// Asked → 30 days to change your mind (logging in again cancels) → then businesses, files and coins are erased.
//   GET / POST { password } or { firebase_token } / DELETE   /api/user/account/delete

String _date(Object? iso, String lang) {
  final d = DateTime.tryParse(str(iso))?.toLocal();
  if (d == null) return str(iso);
  try {
    return DateFormat('d MMMM y', lang == 'km' ? 'km' : 'en').format(d);
  } catch (_) {
    return DateFormat('d MMMM y').format(d);
  }
}

// The card on My account (owners only)
class DeleteAccountCard extends ConsumerStatefulWidget {
  const DeleteAccountCard({super.key});
  @override
  ConsumerState<DeleteAccountCard> createState() => _DeleteAccountCardState();
}

class _DeleteAccountCardState extends ConsumerState<DeleteAccountCard> {
  Json? _status;
  bool _busy = false;
  String _error = '';

  String get _url => '${Api.user}/account/delete';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(apiProvider).get(_url);
      if (mounted) setState(() => _status = obj(r['data']));
    } catch (_) {
      if (mounted) setState(() => _status = {'pending': false});
    }
  }

  Future<void> _ask() async {
    final done = await showModalBottomSheet<Json>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _DeleteSheet(),
    );
    if (done == null || !mounted) return;
    setState(() => _status = done);
    await ref.read(sessionProvider.notifier).patch({'delete_at': done['delete_at'], 'deletion_cancelled': false});
  }

  Future<void> _undo() async {
    final t = ref.read(tProvider);
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final r = await ref.read(apiProvider).delete(_url);
      await ref.read(sessionProvider.notifier).patch({'delete_at': null, 'deletion_cancelled': false});
      if (!mounted) return;
      setState(() => _status = obj(r['data']));
      toast(context, t('del.undone'));
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final st = _status;
    if (st == null) return const SizedBox.shrink();
    final pending = st['pending'] == true;
    return Panel(
      key: const ValueKey('del-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: c.dangerBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(pending ? LucideIcons.calendarClock : LucideIcons.trash2, size: 19, color: c.danger),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pending ? t('del.pendingTitle') : t('del.title'), style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      pending ? t('del.pendingSub').replaceAll('{date}', _date(st['delete_at'], t.lang)).replaceAll('{days}', '${st['days'] ?? ''}') : t('del.sub'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(pending ? t('del.pendingHint') : t('del.grace'), style: TextStyle(color: c.muted, height: 1.5, fontSize: 13.5)),
          if (_error.isNotEmpty) ...[const SizedBox(height: 10), Alert(_error)],
          const SizedBox(height: 14),
          if (pending)
            Btn(t('del.undo'), icon: LucideIcons.rotateCcw, busy: _busy, expand: true, onTap: _undo)
          else
            Btn(t('del.start'), icon: LucideIcons.trash2, kind: BtnKind.danger, expand: true, onTap: _ask),
        ],
      ),
    );
  }
}

// The confirm sheet: what is lost, "I understand", password or Google
class _DeleteSheet extends ConsumerStatefulWidget {
  const _DeleteSheet();
  @override
  ConsumerState<_DeleteSheet> createState() => _DeleteSheetState();
}

class _DeleteSheetState extends ConsumerState<_DeleteSheet> {
  final _pw = TextEditingController();
  bool _agree = false;
  String _busy = '';
  String _error = '';

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  Future<void> _send(Json body, String which) async {
    final t = ref.read(tProvider);
    setState(() {
      _busy = which;
      _error = '';
    });
    try {
      final r = await ref.read(apiProvider).post('${Api.user}/account/delete', body);
      if (mounted) Navigator.of(context).pop(obj(r['data']));
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.network ? t('messages.networkError') : e.message);
    } catch (e) {
      if (mounted) setState(() => _error = authErrorText(e, t.call));
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Future<void> _withPassword() async {
    if (!_agree || _pw.text.isEmpty || _busy.isNotEmpty) return;
    await _send({'password': _pw.text}, 'password');
  }

  Future<void> _withGoogle() async {
    if (!_agree || _busy.isNotEmpty) return;
    final t = ref.read(tProvider);
    setState(() {
      _busy = 'google';
      _error = '';
    });
    try {
      final g = await FirebaseRest.google();
      await _send({'firebase_token': g.token}, 'google');
    } on AuthError catch (e) {
      if (e.key == 'cancelled') {
        if (mounted) setState(() => _busy = '');
        return;
      }
      if (mounted) setState(() => _error = authErrorText(e, t.call));
    } catch (e) {
      if (mounted) setState(() => _error = authErrorText(e, t.call));
    } finally {
      if (mounted && _busy == 'google') setState(() => _busy = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final off = _busy.isNotEmpty;
    return PopScope(
      canPop: !off,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t('del.confirmTitle'), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: c.dangerBg, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.triangleAlert, size: 19, color: c.danger),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t('del.lost'), style: TextStyle(fontWeight: FontWeight.w800, color: c.danger)),
                          const SizedBox(height: 6),
                          for (final li in t.list('del.lostList'))
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('•  ', style: TextStyle(color: c.danger, height: 1.45)),
                                  Expanded(child: Text(li, style: const TextStyle(height: 1.45, fontSize: 13.5))),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(t('del.grace'), style: const TextStyle(height: 1.5, fontSize: 13.5)),
              const SizedBox(height: 8),
              Text(t('del.kept'), style: TextStyle(color: c.muted, height: 1.5, fontSize: 12.5)),
              const SizedBox(height: 12),
              // a plain row (CheckboxListTile asserts inside a coloured box)
              InkWell(
                key: const ValueKey('del-agree'),
                borderRadius: BorderRadius.circular(12),
                onTap: off ? null : () => setState(() => _agree = !_agree),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 24,
                        child: Checkbox(value: _agree, onChanged: off ? null : (v) => setState(() => _agree = v ?? false), activeColor: c.danger),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(t('del.understand'), style: const TextStyle(fontWeight: FontWeight.w700, height: 1.45)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Field(
                key: const ValueKey('del-pw'),
                label: t('del.password'),
                controller: _pw,
                password: true,
                icon: LucideIcons.lock,
                enabled: _agree && !off,
                autofill: const [AutofillHints.password],
                onChanged: (_) => setState(() {}),
                onSubmit: (_) => _withPassword(),
              ),
              if (_error.isNotEmpty) ...[const SizedBox(height: 10), Alert(_error)],
              const SizedBox(height: 14),
              Btn(
                t('del.confirm'),
                key: const ValueKey('del-confirm'),
                icon: LucideIcons.trash2,
                kind: BtnKind.danger,
                expand: true,
                busy: _busy == 'password',
                onTap: _agree && _pw.text.isNotEmpty && !off ? _withPassword : null,
              ),
              const SizedBox(height: 10),
              Center(child: Muted(t('del.orGoogle'))),
              const SizedBox(height: 10),
              Opacity(
                opacity: _agree ? 1 : .5,
                child: GoogleButton(t('del.google'), busy: _busy == 'google', onTap: _agree && !off ? _withGoogle : () {}),
              ),
              const SizedBox(height: 8),
              Btn(t('del.cancel'), kind: BtnKind.ghost, expand: true, onTap: off ? null : () => Navigator.of(context).pop()),
            ],
          ),
        ),
      ),
    );
  }
}

// Top of the owner home: "welcome back, deletion cancelled" once after logging in, or "will be deleted on …"
class DeletionBanner extends ConsumerWidget {
  const DeletionBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    if (s == null || s.team) return const SizedBox.shrink();
    final t = ref.watch(tProvider);
    final c = context.c;
    if (s.data['deletion_cancelled'] == true) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Alert(
          t('del.welcomeBack'),
          tone: Tone.good,
          action: GestureDetector(
            onTap: () => ref.read(sessionProvider.notifier).patch({'deletion_cancelled': false}),
            child: Text(t('messages.close'), style: TextStyle(fontWeight: FontWeight.w800, color: c.good)),
          ),
        ),
      );
    }
    final at = str(s.data['delete_at']);
    if (at.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Alert(
        t('del.banner').replaceAll('{date}', _date(at, t.lang)),
        tone: Tone.danger,
        action: GestureDetector(
          onTap: () => context.push('/account'),
          child: Text(t('del.bannerLink'), style: TextStyle(fontWeight: FontWeight.w800, color: c.danger)),
        ),
      ),
    );
  }
}
