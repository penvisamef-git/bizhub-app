import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'delete_account.dart';
import 'settings_parts.dart';
import 'shell.dart';

// My account (dashboard/client/account/AccountPage.jsx): photo, name, contact, password, preferences
class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});
  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  late final _name = TextEditingController(text: ref.read(sessionProvider)?.name ?? '');
  final _old = TextEditingController(), _new = TextEditingController(), _new2 = TextEditingController();
  bool _photoBusy = false, _nameBusy = false, _pwBusy = false;
  String _pwError = '', _nameError = '';

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

  @override
  void dispose() {
    for (final c in [_name, _old, _new, _new2]) {
      c.dispose();
    }
    super.dispose();
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

  Future<void> _saveName() async {
    final t = ref.read(tProvider);
    if (_name.text.trim().length < 2) return setState(() => _nameError = t('messages.nameShort'));
    setState(() {
      _nameBusy = true;
      _nameError = '';
    });
    try {
      final r = await ref.read(apiProvider).put('${Api.user}/profile', {'name': _name.text.trim()});
      await ref.read(sessionProvider.notifier).patch(obj(r['data']));
      if (mounted) toast(context, t('messages.saved2'));
    } on ApiError catch (e) {
      setState(() => _nameError = e.message);
    } finally {
      if (mounted) setState(() => _nameBusy = false);
    }
  }

  Future<void> _changePw() async {
    final t = ref.read(tProvider);
    final s = ref.read(sessionProvider)!;
    if (_old.text.isEmpty || _new.text.isEmpty) return setState(() => _pwError = t('messages.fillAll'));
    if (_new.text.length < 8) return setState(() => _pwError = t('messages.passwordShort'));
    if (_new.text != _new2.text) return setState(() => _pwError = t('messages.passwordMismatch'));
    setState(() {
      _pwBusy = true;
      _pwError = '';
    });
    try {
      await ref.read(apiProvider).put(s.team ? '${Api.admin}/auth/change-password' : '${Api.user}/change-password', {'old_password': _old.text, 'new_password': _new.text});
      if (s.team) await ref.read(sessionProvider.notifier).patch({'is_first_login': false});
      _old.clear();
      _new.clear();
      _new2.clear();
      if (mounted) toast(context, t('app.passwordChanged'));
    } on ApiError catch (e) {
      setState(() => _pwError = e.message);
    } finally {
      if (mounted) setState(() => _pwBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final s = ref.watch(sessionProvider);
    if (s == null) return const SizedBox.shrink();
    return SubPage(
      title: t('messages.navAccount'),
      children: [
        if (s.firstLogin) ...[Alert(t('app.firstLogin'), tone: Tone.warn), const SizedBox(height: 14)],
        Panel(
          child: Column(
            children: [
              Stack(
                children: [
                  Avatar(name: s.name, photo: s.photo, size: 96, brand: true),
                  if (_photoBusy)
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Color(0x66000000), shape: BoxShape.circle),
                        child: Center(child: CircularProgressIndicator(color: Colors.white)),
                      ),
                    ),
                  if (!s.team)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: RoundBtn(
                        LucideIcons.camera,
                        size: 36,
                        bg: c.solid,
                        fg: c.onSolid,
                        tip: t('app.changePhoto'),
                        onTap: _photoBusy
                            ? null
                            : () => showModalBottomSheet(
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
                              ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(s.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Chip2(s.superAdmin ? t('messages.superAdmin') : t('app.ownerHint'), tone: s.superAdmin ? Tone.brand : Tone.lime, icon: s.superAdmin ? LucideIcons.shieldCheck : LucideIcons.briefcase),
              const SizedBox(height: 16),
              if (s.email.isNotEmpty) _Info(LucideIcons.mail, t('messages.email'), s.email),
              if (s.phone.isNotEmpty) _Info(LucideIcons.phone, t('messages.phone'), s.phone),
              if (!s.team) _Info(LucideIcons.coins, t('messages.coinBalance'), '${s.coins}'),
            ],
          ),
        ),
        if (!s.team) ...[
          const SizedBox(height: 14),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Field(label: t('messages.fullName'), controller: _name, icon: LucideIcons.user),
                if (_nameError.isNotEmpty) ...[const SizedBox(height: 10), Alert(_nameError)],
                const SizedBox(height: 12),
                Btn(t('app.saveName'), busy: _nameBusy, kind: BtnKind.solid, onTap: _saveName),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SecHead(t('app.changePassword')),
              Field(label: t('app.oldPassword'), controller: _old, password: true, icon: LucideIcons.lock, autofill: const [AutofillHints.password]),
              const SizedBox(height: 12),
              Field(label: '${t('app.newPassword')} · ${t('messages.passwordMin')}', controller: _new, password: true, icon: LucideIcons.keyRound, autofill: const [AutofillHints.newPassword]),
              const SizedBox(height: 12),
              Field(label: t('messages.confirmPassword'), controller: _new2, password: true, icon: LucideIcons.keyRound),
              if (_pwError.isNotEmpty) ...[const SizedBox(height: 10), Alert(_pwError)],
              const SizedBox(height: 14),
              Btn(t('app.changePassword'), busy: _pwBusy, onTap: _changePw),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const PreferencesCard(),
        const SizedBox(height: 18),
        MenuCard(rows: [MenuRow(icon: LucideIcons.logOut, label: t('messages.logout'), danger: true, onTap: () => logout(context, ref))]),
        // "Delete my account" (owners; Google Play / App Store rule)
        if (!s.team) ...[const SizedBox(height: 18), const DeleteAccountCard()],
      ],
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Info(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, size: 17, color: c.brandInk),
          const SizedBox(width: 12),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
