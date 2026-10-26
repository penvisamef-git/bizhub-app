import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/firebase_rest.dart';
import '../../core/providers.dart';
import '../../widgets/ui.dart';
import 'auth_shell.dart';

final emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

// Firebase / API error → the web's words
String authErrorText(Object e, String Function(String, [Map<String, Object?>]) t) {
  if (e is AuthError && e.key == 'googleMissing') return t('app.googleMissing');
  if (e is AuthError && e.key == 'googleBlocked') return '${t('app.googleBlocked')} (${e.detail})';
  if (e is AuthError) return '${t('phone.${e.key}')}${e.detail != null && (e.key == 'smsFailed' || e.key == 'smsNotReady' || e.key == 'smsDomain') ? ' (${e.detail})' : ''}';
  if (e is ApiError) return e.network ? t('messages.networkError') : e.message;
  return t('phone.smsFailed');
}

// One form for everyone (homepage/auth/LoginPage.jsx): an email tries the BizHub team first, then owners.
Future<Json> loginAny(Api api, String id, String password) async {
  try {
    final r = await api.post('${Api.admin}/auth/login', {'email': id, 'password': password, 'client': 'app'}); // app session: the website stays logged in
    return {...obj(r['data']), 'account_type': 'team'};
  } on ApiError catch (e) {
    if (e.status != 401 && e.status != 400) rethrow;
    return obj((await api.post('${Api.user}/login', {'login': id, 'password': password}))['data']);
  }
}

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _id = TextEditingController();
  final _pw = TextEditingController();
  String _error = '';
  bool _badId = false, _badPw = false, _busy = false;

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = ref.read(tProvider);
    setState(() => _error = '');
    final id = _id.text.trim(), pw = _pw.text;
    if (id.isEmpty || pw.isEmpty) return _fail(t('messages.fillAll'), id.isEmpty, pw.isEmpty);
    if (!emailRe.hasMatch(id)) return _fail(t('messages.badEmail'), true, false);
    setState(() => _busy = true);
    try {
      final user = await loginAny(ref.read(apiProvider), id, pw);
      final team = user['account_type'] == 'team';
      if (team && user['is_super_admin'] != true) return _fail(t('app.teamOnly'), false, false);
      await ref.read(sessionProvider.notifier).set(user);
      if (team && user['is_first_login'] == true && mounted) {
        Future.microtask(() {
          if (mounted) GoRouter.of(context).push('/account');
        });
      }
    } on ApiError catch (e) {
      _fail(
        e.network
            ? t('messages.networkError')
            : (e.status == 400 || e.status == 401)
            ? t('messages.badLogin')
            : e.status == 429
            ? t('messages.tooManyTries')
            : e.message,
        true,
        true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Google: account with that email → in; none yet → finish signing up
  Future<void> _google() async {
    final t = ref.read(tProvider);
    setState(() {
      _error = '';
      _busy = true;
    });
    try {
      final g = await FirebaseRest.google();
      try {
        final r = await ref.read(apiProvider).post('${Api.user}/login-google', {'firebase_token': g.token});
        await ref.read(sessionProvider.notifier).set(obj(r['data']));
      } on ApiError catch (e) {
        if (e.status == 404) {
          if (mounted) context.go('/signup', extra: g);
          return;
        }
        rethrow;
      }
    } catch (e) {
      if (e is AuthError && e.key == 'cancelled') return;
      setState(() => _error = e is ApiError && e.status == 403 ? e.message : authErrorText(e, t.call));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(String m, bool id, bool pw) => setState(() {
    _error = m;
    _badId = id;
    _badPw = pw;
  });

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    return AuthShell(
      children: [
        AuthTitle(t('messages.loginTitle'), t('messages.loginSub')),
        GoogleButton(t('phone.google'), busy: _busy, onTap: _google),
        const SizedBox(height: 12),
        QrButton(t('app.qrLogin'), onTap: _busy ? null : () => context.push('/login-qr')),
        OrLine(t('phone.or')),
        Field(
          label: t('phone.emailLabel'),
          hint: t('messages.emailPh'),
          icon: LucideIcons.userRound,
          controller: _id,
          public: true,
          invalid: _badId,
          enabled: !_busy,
          keyboard: TextInputType.emailAddress,
          autofill: const [AutofillHints.username, AutofillHints.email],
          onChanged: (_) => setState(() => _badId = false),
        ),
        const SizedBox(height: 18),
        Field(
          label: t('messages.password'),
          labelTrailing: AuthLink(t('phone.forgot'), () => context.push('/forgot')),
          hint: t('messages.passwordPh'),
          icon: LucideIcons.lock,
          controller: _pw,
          password: true,
          public: true,
          invalid: _badPw,
          enabled: !_busy,
          autofill: const [AutofillHints.password],
          onChanged: (_) => setState(() => _badPw = false),
          onSubmit: (_) => _submit(),
        ),
        if (_error.isNotEmpty) ...[const SizedBox(height: 16), Alert(_error)],
        const SizedBox(height: 22),
        AuthButton(_busy ? t('messages.loggingIn') : t('messages.loginBtn'), busy: _busy, onTap: _submit),
        AuthSwitch(t('messages.noAccount'), t('messages.signUpBtn'), () => context.go('/signup')),
      ],
    );
  }
}
