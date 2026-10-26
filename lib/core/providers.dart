import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'i18n.dart';

// ---------------------------------------------------------------- device settings (same keys as the web)
class Prefs {
  final String lang; // en | km
  final ThemeMode theme;
  final bool onboarded; // saw "Get started"
  const Prefs({required this.lang, required this.theme, required this.onboarded});
  Prefs copy({String? lang, ThemeMode? theme, bool? onboarded}) => Prefs(lang: lang ?? this.lang, theme: theme ?? this.theme, onboarded: onboarded ?? this.onboarded);
}

late SharedPreferences _sp;

class PrefsNotifier extends Notifier<Prefs> {
  static Future<void> init() async => _sp = await SharedPreferences.getInstance();

  @override
  Prefs build() {
    final sys = PlatformDispatcher.instance.locale.languageCode;
    final theme = _sp.getString('bizhub_theme');
    return Prefs(
      lang: _sp.getString('bizhub_lang') ?? (sys == 'km' ? 'km' : 'en'),
      theme: theme == 'dark' ? ThemeMode.dark : theme == 'light' ? ThemeMode.light : ThemeMode.system,
      onboarded: _sp.getBool('bizhub_onboarded') ?? false,
    );
  }

  bool get langChosen => _sp.getString('bizhub_lang') != null;

  void setLang(String lang) {
    _sp.setString('bizhub_lang', lang);
    state = state.copy(lang: lang);
  }

  void setTheme(ThemeMode m) {
    _sp.setString('bizhub_theme', m == ThemeMode.dark ? 'dark' : m == ThemeMode.light ? 'light' : 'system');
    state = state.copy(theme: m);
  }

  void finishOnboarding() {
    _sp.setBool('bizhub_onboarded', true);
    state = state.copy(onboarded: true);
  }
}

// small per-phone choices (list / grid…)
String? prefStr(String key) => _sp.getString(key);
void prefSetStr(String key, String v) => _sp.setString(key, v);

final prefsProvider = NotifierProvider<PrefsNotifier, Prefs>(PrefsNotifier.new);
final tProvider = Provider<T>((ref) => T.of(ref.watch(prefsProvider.select((p) => p.lang))));

// ---------------------------------------------------------------- who is logged in
// The same login object the web keeps: user fields + access_token (+ account_type "team" for the BizHub team).
class Session {
  final Json data;
  const Session(this.data);
  String get token => str(data['access_token']);
  bool get team => data['account_type'] == 'team';
  bool get superAdmin => team && data['is_super_admin'] == true;
  bool get firstLogin => team && data['is_first_login'] == true;
  String get name {
    final n = str(data['name']).isNotEmpty ? str(data['name']) : [str(data['firstname']), str(data['lastname'])].where((x) => x.isNotEmpty).join(' ');
    return n.isNotEmpty ? n : str(data['email']).isNotEmpty ? str(data['email']) : str(data['phone']);
  }

  String get photo {
    final p = data['photo'];
    return p is Map ? str(p['url']) : str(p);
  }
  num get coins => n(data['coin_balance']);
  String get email => str(data['email']);
  String get phone => str(data['phone']);
}

const _store = FlutterSecureStorage();
const _key = 'bizhub_login';
Session? _saved;

class SessionNotifier extends Notifier<Session?> {
  static Future<void> init() async {
    try {
      final raw = await _store.read(key: _key);
      if (raw != null) _saved = Session(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      _saved = null;
    }
  }

  @override
  Session? build() => _saved;

  Future<void> set(Json login) async {
    state = Session(login);
    await _store.write(key: _key, value: jsonEncode(login));
  }

  // keep the token, change some fields (name, photo, coin balance…)
  Future<void> patch(Json fields) async {
    final s = state;
    if (s == null) return;
    await set({...s.data, ...fields, 'access_token': s.token, if (s.team) 'account_type': 'team'});
  }

  Future<void> clear() async {
    state = null;
    await _store.delete(key: _key);
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, Session?>(SessionNotifier.new);

// tells the screen above the router to show "your session ended"
final sessionEndedProvider = StateProvider<int>((ref) => 0);

final apiProvider = Provider<Api>((ref) {
  return Api(
    token: () => ref.read(sessionProvider)?.token,
    onUnauthorized: () {
      if (ref.read(sessionProvider) == null) return;
      ref.read(sessionProvider.notifier).clear();
      ref.read(sessionEndedProvider.notifier).state++;
    },
  );
});

// just signed up → the dashboard shows "Welcome to BizHub! You have … free coins"
final welcomeProvider = StateProvider<bool>((ref) => false);
