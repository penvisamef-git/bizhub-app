import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/crash.dart';
import 'core/i18n.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Crash.install(); // app errors → our API → super admin Telegram
  await Future.wait([PrefsNotifier.init(), SessionNotifier.init(), T.load(), AppInfo.init()]);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ProviderScope(child: BizHubApp()));
}
