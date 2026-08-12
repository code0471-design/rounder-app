import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app_startup_bootstrap.dart';
import 'app/app_startup_host.dart';
import 'app/rounder_app.dart';
import 'core/config/runtime_mode.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureAppErrorHandlers();
  configureSystemChrome();

  if (kIsWeb) {
    debugPrint('[main] Uri.base=${Uri.base} fragment=${Uri.base.fragment} '
        'admin=${Uri.base.queryParameters['admin']}');
  }

  // Web Firebase 미설정 → 로딩 화면 없이 즉시 Mock 앱 실행
  if (RuntimeMode.useOfflineMock) {
    final startup = await AppStartupBootstrap.runOfflineMock();
    runApp(RounderApp(startup: startup));
    return;
  }

  runApp(const AppStartupHost());
}
