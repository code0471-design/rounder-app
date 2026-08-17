import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app_startup_bootstrap.dart';
import 'app/app_startup_host.dart';
import 'app/rounder_app.dart';
import 'core/config/runtime_mode.dart';
import 'firebase_options.dart';
import 'services/push_notification_service.dart';

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

  // FCM 백그라운드 핸들러는 runApp 이전에 등록해야 한다.
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    PushNotificationService.registerBackgroundHandler();
  } catch (e) {
    debugPrint('[main] Firebase early init skip: $e');
  }

  runApp(const AppStartupHost());
}
