import 'dart:async';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'config.dart';

// The app's version (from pubspec.yaml: version: 1.0.0+1) — shown in More, sent with crash reports
class AppInfo {
  static String version = '';
  static String build = '';
  static String get full => build.isEmpty ? version : '$version+$build';

  static Future<void> init() async {
    try {
      final p = await PackageInfo.fromPlatform();
      version = p.version;
      build = p.buildNumber;
    } catch (e) {
      debugPrint('AppInfo: $e');
    }
  }

  static String get platform => kIsWeb ? 'web' : defaultTargetPlatform.name;
  static String get os {
    if (kIsWeb) return '';
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return '';
    }
  }
}

// Sends app crashes to our API (POST /api/public/app-error) → super admin Telegram + "App errors" in More.
// Same error is sent once per app run; at most 20 reports per run.
class Crash {
  static String route = '';
  static Map<String, String>? user; // { type, id, email }
  static final _sent = <String>{};
  static final _dio = Dio(BaseOptions(baseUrl: Config.apiHost, connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 10), validateStatus: (_) => true));

  static void install() {
    final before = FlutterError.onError;
    FlutterError.onError = (d) {
      before?.call(d);
      if (d.silent) return;
      report(d.exception, d.stack, library: d.library ?? '', context: d.context?.toDescription() ?? '');
    };
    PlatformDispatcher.instance.onError = (e, s) {
      report(e, s, library: 'async');
      return true; // handled: keep the app running
    };
    // a part of a screen that failed: a small friendly box instead of the grey / red one
    if (kReleaseMode) {
      ErrorWidget.builder = (d) => const _BrokenPart();
    }
  }

  static Future<void> report(Object error, StackTrace? stack, {String library = '', String context = ''}) async {
    try {
      final message = '$error';
      // a lost connection is not a bug
      if (error is DioException || message.contains('SocketException') || message.contains('Failed host lookup') || message.contains('XMLHttpRequest error')) return;
      final key = '${message.split('\n').first}|$context';
      if (_sent.contains(key) || _sent.length >= 20 || Config.apiHost.isEmpty) return;
      _sent.add(key);
      await _dio.post<dynamic>(
        '/api/public/app-error',
        data: {
          'message': message.length > 2000 ? message.substring(0, 2000) : message,
          'stack': '${stack ?? ''}'.length > 6000 ? '$stack'.substring(0, 6000) : '${stack ?? ''}',
          'library': library,
          'context': context,
          'route': route,
          'version': AppInfo.full,
          'platform': AppInfo.platform,
          'os': AppInfo.os,
          'user': ?user,
        },
        options: Options(headers: {'x-api-key': Config.apiKey, 'Content-Type': 'application/json'}),
      );
    } catch (_) {
      // never crash while reporting a crash
    }
  }
}

class _BrokenPart extends StatelessWidget {
  const _BrokenPart();
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0x14E0581A), borderRadius: BorderRadius.circular(16)),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, color: Color(0xFFE0581A), size: 20),
        SizedBox(width: 10),
        Flexible(
          child: Text(
            'This part could not be shown. We got the report and will fix it.\nផ្នែកនេះមិនអាចបង្ហាញបានទេ។ យើងបានទទួលរបាយការណ៍ ហើយនឹងកែឆាប់ៗ។',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFF9E380A), decoration: TextDecoration.none, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
