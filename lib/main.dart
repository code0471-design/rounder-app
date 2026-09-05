import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

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
  configureAndroidPhotoPicker();

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
      ).timeout(const Duration(seconds: 8));
    }
    PushNotificationService.registerBackgroundHandler();
  } catch (e) {
    debugPrint('[main] Firebase early init skip: $e');
  }

  runApp(const AppStartupHost());
}

/// 구글 포토 앱은 `pickMultiImage` 의 `limit` 을 무시한다.
/// 안드로이드 시스템 포토 피커를 강제해야 20장 제한이 실제로 걸린다.
/// (원클럽 `main.dart` 와 같은 처리)
void configureAndroidPhotoPicker() {
  if (kIsWeb || !Platform.isAndroid) return;
  final impl = ImagePickerPlatform.instance;
  if (impl is ImagePickerAndroid) {
    impl.useAndroidPhotoPicker = true;
  }
}
