import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/firebase_rest.dart';
import '../../core/providers.dart';
import '../../core/site.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'auth_shell.dart';
import 'login_page.dart' show authErrorText, emailRe;

// Asks the API whether an email is free while the person types (useTakenCheck on the web)
class TakenCheck {
  final Api api;
  final void Function(String status) onStatus;
  Timer? _t;
  int _seq = 0;
  TakenCheck(this.api, this.onStatus);
  void check(String value) {
    _t?.cancel();
    final v = value.trim().toLowerCase();
    if (!emailRe.hasMatch(v)) return onStatus('');
    final id = ++_seq;
    onStatus('checking');
    _t = Timer(const Duration(milliseconds: 450), () async {
      try {
        final r = await api.post('${Api.user}/check', {'email': v});
        if (id != _seq) return;
        final x = obj(obj(r['data'])['email']);
        onStatus(x['valid'] == false ? 'invalid' : x['taken'] == true ? 'taken' : 'ok');
      } catch (_) {
        if (id == _seq) onStatus('');
      }
    });
  }

  void dispose() => _t?.cancel();
}

// Sign-up for business owners (homepage/auth/SignUpPage.jsx). The email is confirmed by Google:
//   "Continue with Google" (one tap)  or  a confirm link sent to any email (finished on the website).
// Then: name, phone (optional), password → POST /api/user/sign-up (logged in, free coins).
class SignUpPage extends ConsumerStatefulWidget {
  final GoogleResult? google; // came from log in: Google said there is no account yet
  const SignUpPage({super.key, this.google});
  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _email = TextEditingController(), _name = TextEditingController(), _phone = TextEditingController(), _pw = TextEditingController(), _pw2 = TextEditingController();
  late final _check = TakenCheck(ref.read(apiProvider), (s) => setState(() => _emailStatus = s));
  String _step = 'start'; // start | sent | finish
  String _emailStatus = '', _error = '', _info = '', _token = '', _confirmed = '';
  bool _busy = false;
  DateTime _sentAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    final g = widget.google;
    if (g != null) {
      _info = ref.read(tProvider)('phone.googleNoAccount', {'email': g.email});
      _toFinish(g);
    }
  }

  @override
  void dispose() {
    for (final c in [_email, _name, _phone, _pw, _pw2]) {
      c.dispose();
    }
    _check.dispose();
    super.dispose();
  }

  void _toFinish(GoogleResult g) {
    _token = g.token;
    _confirmed = g.email;
    if (_name.text.isEmpty) _name.text = g.name;
    _step = 'finish';
  }

  void _say(Object e) {
    if (e is AuthError && e.key == 'cancelled') return;
    setState(() => _error = authErrorText(e, ref.read(tProvider).call));
  }

  Future<void> _google() async {
    setState(() {
      _error = '';
      _busy = true;
    });
    try {
      final g = await FirebaseRest.google();
      // already has an account → just log in
      try {
        final r = await ref.read(apiProvider).post('${Api.user}/login-google', {'firebase_token': g.token});
        await ref.read(sessionProvider.notifier).set(obj(r['data']));
        return;
      } on ApiError catch (e) {
        if (e.status != 404) rethrow;
      }
      setState(() => _toFinish(g));
    } catch (e) {
      _say(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendLink() async {
    final t = ref.read(tProvider);
    setState(() => _error = '');
    final mail = _email.text.trim().toLowerCase();
    if (!emailRe.hasMatch(mail)) return setState(() => _error = t('phone.badEmail'));
    setState(() => _busy = true);
    try {
      final r = await ref.read(apiProvider).post('${Api.user}/check', {'email': mail});
      if (obj(obj(r['data'])['email'])['taken'] == true) return setState(() => _error = t('phone.emailTaken'));
      await FirebaseRest.sendEmailLink(mail, '/sign-up', t.lang);
      _email.text = mail;
      setState(() {
        _sentAt = DateTime.now();
        _step = 'sent';
      });
    } catch (e) {
      _say(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final t = ref.read(tProvider);
    setState(() => _error = '');
    if (_name.text.trim().isEmpty || _pw.text.isEmpty || _pw2.text.isEmpty) return setState(() => _error = t('messages.fillAll'));
    if (_name.text.trim().length < 2) return setState(() => _error = t('messages.nameShort'));
    if (_phone.text.trim().isNotEmpty && PhoneField.e164(_phone.text) == null) return setState(() => _error = t('phone.badPhone'));
    if (_pw.text.length < 8) return setState(() => _error = t('messages.passwordShort'));
    if (_pw.text != _pw2.text) return setState(() => _error = t('messages.passwordMismatch'));
    setState(() => _busy = true);
    try {
      final r = await ref.read(apiProvider).post('${Api.user}/sign-up', {'name': _name.text.trim(), 'phone': _phone.text.trim().isEmpty ? '' : PhoneField.e164(_phone.text), 'password': _pw.text, 'firebase_token': _token});
      await ref.read(sessionProvider.notifier).set(obj(r['data']));
      ref.read(welcomeProvider.notifier).state = true;
    } on ApiError catch (e) {
      if (e.status == 409) {
        setState(() => _error = e.code == 'phone_taken' ? t('phone.phoneTaken') : t('phone.emailTaken'));
      } else if (e.status == 401) {
        setState(() {
          _error = t('phone.checkAgain');
          _step = 'start';
        });
      } else if (e.status == 429) {
        setState(() => _error = t('messages.tooManyTries'));
      } else {
        _say(e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final site = siteOf(ref);
    final alert = _error.isEmpty ? null : Padding(padding: const EdgeInsets.only(top: 16), child: Alert(_error));
    Widget back(String label, VoidCallback onTap) => Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _busy ? null : onTap,
        icon: Icon(LucideIcons.arrowLeft, size: 16, color: c.pubBrand),
        label: Text(label, style: TextStyle(color: c.pubBrand, fontWeight: FontWeight.w700)),
      ),
    );

    if (_step == 'sent') {
      return AuthShell(
        children: [
          back(t('phone.changeEmail'), () => setState(() => _step = 'start')),
          const SizedBox(height: 12),
          MailSent(
            title: t('phone.linkTitle'),
            sub: t('phone.linkSub', {'email': _email.text}),
            hint: t('phone.linkHint'),
            below: Column(
              children: [
                const SizedBox(height: 16),
                Alert(t('app.linkFinishWeb'), tone: Tone.brand),
                ?alert,
                const SizedBox(height: 8),
                ResendLink(sentAt: _sentAt, busy: _busy, waitText: t('phone.resendLinkIn'), readyText: t('phone.resendLink'), onTap: _sendLink),
                const SizedBox(height: 8),
                AuthButton(t('messages.loginBtn'), onTap: () => context.go('/login')),
              ],
            ),
          ),
        ],
      );
    }

    if (_step == 'finish') {
      return AuthShell(
        children: [
          AuthTitle(t('phone.finishTitle'), _info.isNotEmpty ? _info : t('phone.finishSub')),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: c.goodBg, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Icon(LucideIcons.circleCheck, size: 18, color: c.good),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _confirmed,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, color: c.good),
                  ),
                ),
                Text(t('phone.confirmed'), style: TextStyle(color: c.good, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Field(label: t('messages.fullName'), hint: t('messages.fullNamePh'), icon: LucideIcons.user, controller: _name, public: true, enabled: !_busy, autofill: const [AutofillHints.name]),
          const SizedBox(height: 18),
          PhoneField(label: '${t('phone.phoneOptional')} · ${t('phone.emailOptional')}', controller: _phone, enabled: !_busy),
          const SizedBox(height: 18),
          Field(label: '${t('messages.password')} · ${t('messages.passwordMin')}', icon: LucideIcons.lock, controller: _pw, password: true, public: true, enabled: !_busy, autofill: const [AutofillHints.newPassword]),
          const SizedBox(height: 18),
          Field(label: t('messages.confirmPassword'), icon: LucideIcons.lock, controller: _pw2, password: true, public: true, enabled: !_busy, autofill: const [AutofillHints.newPassword], onSubmit: (_) => _create()),
          ?alert,
          const SizedBox(height: 22),
          AuthButton(_busy ? t('phone.creating') : t('phone.createAccount'), busy: _busy, onTap: _create),
        ],
      );
    }

    return AuthShell(
      children: [
        AuthTitle(t('messages.signUpTitle'), t('messages.signUpSub', site.plainVars)),
        GoogleButton(t('phone.google'), busy: _busy, onTap: _google),
        OrLine(t('phone.or')),
        Field(
          label: t('phone.emailLabel'),
          hint: t('messages.emailPh'),
          icon: LucideIcons.mail,
          controller: _email,
          public: true,
          enabled: !_busy,
          keyboard: TextInputType.emailAddress,
          invalid: _emailStatus == 'taken',
          autofill: const [AutofillHints.email],
          onChanged: _check.check,
          onSubmit: (_) => _sendLink(),
        ),
        CheckNote(
          status: _emailStatus == 'invalid' ? '' : _emailStatus,
          okText: t('phone.available'),
          takenText: t('phone.emailTaken'),
          links: [AuthLink(t('phone.loginInstead'), () => context.go('/login')), AuthLink(t('phone.forgotInstead'), () => context.push('/forgot'))],
        ),
        ?alert,
        const SizedBox(height: 22),
        AuthButton(_busy ? t('phone.sendingLink') : t('phone.sendLink'), busy: _busy, onTap: _emailStatus == 'taken' ? null : _sendLink),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('${t('messages.agreePre')} ', style: TextStyle(color: c.pubMuted, fontSize: 13)),
            AuthLink(t('messages.agreeLink'), () => launchUrl(Uri.parse('${Config.siteUrl}/terms'), mode: LaunchMode.externalApplication)),
            Text(t('messages.agreePost'), style: TextStyle(color: c.pubMuted, fontSize: 13)),
          ],
        ),
        AuthSwitch(t('messages.haveAccount'), t('messages.loginBtn'), () => context.go('/login')),
      ],
    );
  }
}

// "Send again in 42s" → "Send the link again"
class ResendLink extends StatelessWidget {
  final DateTime sentAt;
  final bool busy;
  final String waitText, readyText;
  final VoidCallback onTap;
  const ResendLink({super.key, required this.sentAt, required this.busy, required this.waitText, required this.readyText, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (_, _) {
        final left = 60 - DateTime.now().difference(sentAt).inSeconds;
        return TextButton(
          onPressed: left > 0 || busy ? null : onTap,
          child: Text(left > 0 ? waitText.replaceAll('{s}', '$left') : readyText, style: TextStyle(fontWeight: FontWeight.w700, color: left > 0 ? c.pubMuted : c.pubBrand)),
        );
      },
    );
  }
}
