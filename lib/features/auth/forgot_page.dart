import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/firebase_rest.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'auth_shell.dart';
import 'login_page.dart' show authErrorText, emailRe;
import 'signup_page.dart' show ResendLink;

// Forgot password (homepage/auth/ForgotPasswordPage.jsx): email → link → new password on the website
class ForgotPage extends ConsumerStatefulWidget {
  const ForgotPage({super.key});
  @override
  ConsumerState<ForgotPage> createState() => _ForgotPageState();
}

class _ForgotPageState extends ConsumerState<ForgotPage> {
  final _email = TextEditingController();
  String _error = '';
  bool _busy = false, _sent = false;
  DateTime _sentAt = DateTime.now();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = ref.read(tProvider);
    final mail = _email.text.trim().toLowerCase();
    setState(() => _error = '');
    if (!emailRe.hasMatch(mail)) return setState(() => _error = t('phone.badEmail'));
    setState(() => _busy = true);
    try {
      final r = await ref.read(apiProvider).post('${Api.user}/check', {'email': mail});
      if (obj(obj(r['data'])['email'])['taken'] != true) return setState(() => _error = t('phone.noAccountEmail'));
      await FirebaseRest.sendEmailLink(mail, '/forgot-password', t.lang);
      _email.text = mail;
      setState(() {
        _sent = true;
        _sentAt = DateTime.now();
      });
    } catch (e) {
      if (!(e is AuthError && e.key == 'cancelled')) setState(() => _error = authErrorText(e, t.call));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    return AuthShell(
      children: [
        if (!_sent) ...[
          AuthTitle(t('phone.forgotTitle'), t('phone.forgotEmailSub')),
          Field(label: t('phone.emailLabel'), hint: t('messages.emailPh'), icon: LucideIcons.mail, controller: _email, public: true, enabled: !_busy, keyboard: TextInputType.emailAddress, autofill: const [AutofillHints.email], onSubmit: (_) => _send()),
          if (_error.isNotEmpty) ...[const SizedBox(height: 16), Alert(_error)],
          const SizedBox(height: 22),
          AuthButton(_busy ? t('phone.sendingLink') : t('phone.sendLink'), busy: _busy, onTap: _send),
          const SizedBox(height: 14),
          Text(
            t('phone.oldEmailHint'),
            textAlign: TextAlign.center,
            style: TextStyle(color: c.pubMuted, fontSize: 13),
          ),
        ] else ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _sent = false),
              icon: Icon(LucideIcons.arrowLeft, size: 16, color: c.pubBrand),
              label: Text(t('phone.changeEmail'), style: TextStyle(color: c.pubBrand, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          MailSent(
            title: t('phone.linkTitle'),
            sub: t('phone.resetLinkSub', {'email': _email.text}),
            hint: t('phone.linkHint'),
            below: Column(
              children: [
                const SizedBox(height: 16),
                Alert(t('app.linkResetWeb'), tone: Tone.brand),
                if (_error.isNotEmpty) ...[const SizedBox(height: 12), Alert(_error)],
                const SizedBox(height: 8),
                ResendLink(sentAt: _sentAt, busy: _busy, waitText: t('phone.resendLinkIn'), readyText: t('phone.resendLink'), onTap: _send),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        Center(child: AuthLink(t('phone.backToLogin'), () => context.canPop() ? context.pop() : context.go('/login'))),
      ],
    );
  }
}
