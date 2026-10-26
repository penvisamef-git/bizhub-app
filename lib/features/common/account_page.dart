import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../team/my_id_card.dart';
import '../team/team_data.dart' show myIdProvider;
import '../team/team_text.dart';
import 'delete_account.dart';
import 'settings_parts.dart';
import 'shell.dart';

// My account, grouped like the phone's Settings: who I am on top, then rows that open their own screen
// (name, password, BizHub ID, delete). The same API as the web's AccountPage.jsx.
class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});
  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  bool _photoBusy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  // the latest profile from the API (GET /me)
  Future<void> _refresh() async {
    final s = ref.read(sessionProvider);
    if (s == null) return;
    try {
      final r = await ref.read(apiProvider).get(s.team ? '${Api.admin}/auth/me' : '${Api.user}/me');
      await ref.read(sessionProvider.notifier).patch(obj(r['data']));
    } catch (_) {}
  }

  Future<void> _photo(ImageSource? src) async {
    final t = ref.read(tProvider);
    final api = ref.read(apiProvider);
    try {
      Json r;
      if (src == null) {
        setState(() => _photoBusy = true);
        r = await api.delete('${Api.user}/profile/photo');
      } else {
        final f = await ImagePicker().pickImage(source: src, maxWidth: 1200, imageQuality: 88);
        if (f == null) return;
        setState(() => _photoBusy = true);
        final form = FormData.fromMap({'photo': MultipartFile.fromBytes(await f.readAsBytes(), filename: f.name.isEmpty ? 'photo.jpg' : f.name)});
        r = await api.post('${Api.user}/profile/photo', form);
      }
      await ref.read(sessionProvider.notifier).patch(obj(r['data']));
      if (mounted) toast(context, t('app.photoSaved'));
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  void _photoMenu(Session s) {
    final t = ref.read(tProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MenuRow(
              icon: LucideIcons.image,
              label: t('app.choosePhoto'),
              onTap: () {
                Navigator.pop(ctx);
                _photo(ImageSource.gallery);
              },
            ),
            MenuRow(
              icon: LucideIcons.camera,
              label: t('app.takePhoto'),
              onTap: () {
                Navigator.pop(ctx);
                _photo(ImageSource.camera);
              },
            ),
            if (s.photo.isNotEmpty)
              MenuRow(
                icon: LucideIcons.trash2,
                label: t('app.removePhoto'),
                danger: true,
                onTap: () {
                  Navigator.pop(ctx);
                  _photo(null);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _open(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final s = ref.watch(sessionProvider);
    if (s == null) return const SizedBox.shrink();
    final owner = !s.team;
    final myId = owner ? (ref.watch(myIdProvider).valueOrNull ?? str(s.data['bizhub_id'])) : '';
    Widget value(String v) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 170),
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Text(
          v,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: c.muted, fontWeight: FontWeight.w600),
        ),
      ),
    );
    return SubPage(
      title: t('messages.navAccount'),
      onRefresh: _refresh,
      children: [
        if (s.firstLogin) ...[Alert(t('app.firstLogin'), tone: Tone.warn), const SizedBox(height: 14)],
        // who I am
        Panel(
          key: const ValueKey('acc-head'),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              GestureDetector(
                onTap: owner && !_photoBusy ? () => _photoMenu(s) : null,
                child: Stack(
                  children: [
                    Avatar(name: s.name, photo: s.photo, size: 68, brand: true),
                    if (_photoBusy)
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Color(0x66000000), shape: BoxShape.circle),
                          child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))),
                        ),
                      ),
                    if (owner)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(color: c.solid, shape: BoxShape.circle, border: Border.all(color: c.card, width: 2)),
                          child: Icon(LucideIcons.camera, size: 13, color: c.onSolid),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      s.email.isNotEmpty ? s.email : s.phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Chip2(s.superAdmin ? t('messages.superAdmin') : t('app.ownerHint'), tone: s.superAdmin ? Tone.brand : Tone.lime, icon: s.superAdmin ? LucideIcons.shieldCheck : LucideIcons.briefcase),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        MenuCard(
          title: t('acc.profile'),
          rows: [
            if (owner)
              MenuRow(
                key: const ValueKey('acc-name'),
                icon: LucideIcons.user,
                label: t('messages.fullName'),
                trailing: value(s.name),
                onTap: () => _open(const _NamePage()),
              ),
            if (s.email.isNotEmpty) _InfoRow(icon: LucideIcons.mail, label: t('messages.email'), value: s.email),
            if (s.phone.isNotEmpty) _InfoRow(icon: LucideIcons.phone, label: t('messages.phone'), value: s.phone),
            if (owner)
              MenuRow(
                key: const ValueKey('acc-id'),
                icon: LucideIcons.idCard,
                label: tm(t.lang, 'myId'),
                trailing: value(myId.isEmpty ? '…' : myId),
                onTap: () => _open(const _IdPage()),
              ),
            if (owner) _InfoRow(icon: LucideIcons.coins, label: t('messages.coinBalance'), value: '${s.coins}'),
          ],
        ),
        const SizedBox(height: 20),
        MenuCard(
          title: t('acc.security'),
          rows: [
            MenuRow(
              key: const ValueKey('acc-password'),
              icon: LucideIcons.keyRound,
              label: t('app.changePassword'),
              trailing: s.firstLogin ? Chip2('!', tone: Tone.warn) : null,
              onTap: () => _open(const _PasswordPage()),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const PreferencesCard(),
        const SizedBox(height: 20),
        MenuCard(
          title: t('acc.account'),
          rows: [
            MenuRow(icon: LucideIcons.logOut, label: t('messages.logout'), danger: true, onTap: () => logout(context, ref)),
            // "Delete my account" (owners; Google Play / App Store rule)
            if (owner) MenuRow(key: const ValueKey('acc-delete'), icon: LucideIcons.userX, label: t('messages.deleteAccountLink'), danger: true, onTap: () => _open(const _DeletePage())),
          ],
        ),
      ],
    );
  }
}

// a row that only shows a value (email, phone, coins)
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 18, color: c.brandInk),
          ),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              style: TextStyle(color: c.muted, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Full name
class _NamePage extends ConsumerStatefulWidget {
  const _NamePage();
  @override
  ConsumerState<_NamePage> createState() => _NamePageState();
}

class _NamePageState extends ConsumerState<_NamePage> {
  late final _name = TextEditingController(text: ref.read(sessionProvider)?.name ?? '');
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = ref.read(tProvider);
    if (_name.text.trim().length < 2) return setState(() => _error = t('messages.nameShort'));
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final r = await ref.read(apiProvider).put('${Api.user}/profile', {'name': _name.text.trim()});
      await ref.read(sessionProvider.notifier).patch(obj(r['data']));
      if (!mounted) return;
      toast(context, t('messages.saved2'));
      Navigator.of(context).pop();
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.network ? t('app.offline') : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    return SubPage(
      title: t('messages.fullName'),
      bottom: Btn(t('app.saveName'), key: const ValueKey('acc-name-save'), busy: _busy, expand: true, onTap: _save),
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Field(label: t('messages.fullName'), controller: _name, icon: LucideIcons.user, autofocus: true, onSubmit: (_) => _save()),
              const SizedBox(height: 10),
              Muted(t('acc.nameHint')),
              if (_error.isNotEmpty) ...[const SizedBox(height: 10), Alert(_error)],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Change password
class _PasswordPage extends ConsumerStatefulWidget {
  const _PasswordPage();
  @override
  ConsumerState<_PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends ConsumerState<_PasswordPage> {
  final _old = TextEditingController(), _new = TextEditingController(), _new2 = TextEditingController();
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    for (final c in [_old, _new, _new2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final t = ref.read(tProvider);
    final s = ref.read(sessionProvider)!;
    if (_old.text.isEmpty || _new.text.isEmpty) return setState(() => _error = t('messages.fillAll'));
    if (_new.text.length < 8) return setState(() => _error = t('messages.passwordShort'));
    if (_new.text != _new2.text) return setState(() => _error = t('messages.passwordMismatch'));
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await ref.read(apiProvider).put(s.team ? '${Api.admin}/auth/change-password' : '${Api.user}/change-password', {'old_password': _old.text, 'new_password': _new.text});
      if (s.team) await ref.read(sessionProvider.notifier).patch({'is_first_login': false});
      if (!mounted) return;
      toast(context, t('app.passwordChanged'));
      Navigator.of(context).pop();
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.network ? t('app.offline') : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    return SubPage(
      title: t('app.changePassword'),
      bottom: Btn(t('app.changePassword'), key: const ValueKey('acc-password-save'), busy: _busy, expand: true, onTap: _save),
      children: [
        Panel(
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Field(label: t('app.oldPassword'), controller: _old, password: true, icon: LucideIcons.lock, autofill: const [AutofillHints.password], autofocus: true),
                const SizedBox(height: 12),
                Field(label: '${t('app.newPassword')} · ${t('messages.passwordMin')}', controller: _new, password: true, icon: LucideIcons.keyRound, autofill: const [AutofillHints.newPassword]),
                const SizedBox(height: 12),
                Field(label: t('messages.confirmPassword'), controller: _new2, password: true, icon: LucideIcons.keyRound, onSubmit: (_) => _save()),
                const SizedBox(height: 10),
                Muted(t('acc.pwHint')),
                if (_error.isNotEmpty) ...[const SizedBox(height: 10), Alert(_error)],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- My BizHub ID / Delete account
class _IdPage extends ConsumerWidget {
  const _IdPage();
  @override
  Widget build(BuildContext context, WidgetRef ref) => SubPage(title: tm(ref.watch(tProvider).lang, 'myId'), children: const [MyIdCard()]);
}

class _DeletePage extends ConsumerWidget {
  const _DeletePage();
  @override
  Widget build(BuildContext context, WidgetRef ref) => SubPage(title: ref.watch(tProvider)('messages.deleteAccountLink'), children: const [DeleteAccountCard()]);
}
