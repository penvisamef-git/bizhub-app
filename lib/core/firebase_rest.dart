import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'config.dart';

// Firebase only proves the email (Google, or a confirm link) — exactly like the website (lib/phoneAuth.js).
// We talk to Firebase Auth's REST API with the same web API key, so the app needs no Firebase SDK.
//
// Errors use the keys of the web's texts (phone.*): cancelled, badEmail, smsTooMany, smsNotReady, linkUsed,
// networkError, fbEnvMissing, smsFailed.
class AuthError implements Exception {
  final String key;
  final String? detail;
  const AuthError(this.key, [this.detail]);
}

class GoogleResult {
  final String token; // Firebase ID token → firebase_token for the API
  final String email, name;
  const GoogleResult(this.token, this.email, this.name);
}

class FirebaseRest {
  static final _dio = Dio(BaseOptions(baseUrl: 'https://identitytoolkit.googleapis.com/v1/', connectTimeout: const Duration(seconds: 15), validateStatus: (_) => true));

  static bool get ready => Config.firebaseApiKey.isNotEmpty || Config.fakeAuth;

  static AuthError _map(String msg) {
    final c = msg.split(' ').first.split(':').first;
    return switch (c) {
      'INVALID_EMAIL' || 'MISSING_EMAIL' => const AuthError('badEmail'),
      'TOO_MANY_ATTEMPTS_TRY_LATER' || 'QUOTA_EXCEEDED' => const AuthError('smsTooMany'),
      'OPERATION_NOT_ALLOWED' || 'CONFIGURATION_NOT_FOUND' || 'ADMIN_ONLY_OPERATION' => AuthError('smsNotReady', c),
      'INVALID_OOB_CODE' || 'EXPIRED_OOB_CODE' => const AuthError('linkUsed'),
      'UNAUTHORIZED_DOMAIN' || 'INVALID_CONTINUE_URI' || 'UNAUTHORIZED_CONTINUE_URI' => AuthError('smsDomain', c),
      _ => AuthError('smsFailed', c),
    };
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {String lang = 'en'}) async {
    try {
      final r = await _dio.post<dynamic>(
        '$path?key=${Config.firebaseApiKey}',
        data: body,
        options: Options(headers: {'X-Firebase-Locale': lang == 'km' ? 'km' : 'en'}),
      );
      final d = r.data is Map ? Map<String, dynamic>.from(r.data as Map) : <String, dynamic>{};
      if ((r.statusCode ?? 0) >= 400) throw _map('${(d['error'] is Map ? d['error']['message'] : null) ?? 'ERROR'}');
      return d;
    } on DioException {
      throw const AuthError('networkError');
    }
  }

  // "Send confirm link" — the link opens the website (sign-up or forgot password), where the person finishes.
  static Future<void> sendEmailLink(String email, String path, String lang) async {
    if (Config.fakeAuth) return Future.delayed(const Duration(milliseconds: 200));
    if (!ready) throw const AuthError('fbEnvMissing');
    await _post('accounts:sendOobCode', {'requestType': 'EMAIL_SIGNIN', 'email': email, 'continueUrl': '${Config.siteUrl}$path', 'canHandleCodeInApp': true}, lang: lang);
  }

  static bool _googleReady = false;

  // "Continue with Google" → Google account → Firebase ID token
  static Future<GoogleResult> google() async {
    if (Config.fakeAuth) return const GoogleResult('test-email:google.demo@gmail.com', 'google.demo@gmail.com', 'Google Demo');
    if (!ready || Config.googleClientId.isEmpty) throw const AuthError('googleMissing');
    if (kIsWeb) throw const AuthError('smsNotReady', 'web');
    final g = GoogleSignIn.instance;
    try {
      if (!_googleReady) {
        await g.initialize(serverClientId: Config.googleClientId, clientId: defaultTargetPlatform == TargetPlatform.iOS && Config.googleIosClientId.isNotEmpty ? Config.googleIosClientId : null);
        _googleReady = true;
      }
      await g.signOut(); // always let the person pick the account
      final acct = await g.authenticate();
      final idToken = acct.authentication.idToken;
      if (idToken == null) throw const AuthError('smsFailed', 'no id token');
      final d = await _post('accounts:signInWithIdp', {'postBody': 'id_token=$idToken&providerId=google.com', 'requestUri': 'http://localhost', 'returnSecureToken': true, 'returnIdpCredential': true});
      final token = '${d['idToken'] ?? ''}';
      if (token.isEmpty) throw const AuthError('smsFailed', 'no firebase token');
      return GoogleResult(token, '${d['email'] ?? acct.email}', '${d['displayName'] ?? acct.displayName ?? ''}');
    } on GoogleSignInException catch (e) {
      debugPrint('[google] $e');
      // The account sheet closed by the person → nothing to say. Android also reports "canceled" when Google
      // refuses the app after an account was picked (SHA-1 / client ID not set up) — then show why.
      final why = e.description ?? '';
      final userClosed = e.code == GoogleSignInExceptionCode.canceled && (why.isEmpty || why.toLowerCase().contains('user'));
      if (userClosed) throw const AuthError('cancelled');
      throw AuthError('googleBlocked', '${e.code.name}${why.isNotEmpty ? ': $why' : ''}');
    }
  }
}
