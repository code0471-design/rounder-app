import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../core/config/runtime_mode.dart';
import '../di/app_dependencies.dart';
import '../firebase_options.dart';
import '../services/firebase_auth_bridge.dart';
import '../services/hq_alimtalk_catalog.dart';
import '../services/hq_push_catalog.dart';
import '../services/push_notification_service.dart';
import 'app_startup_result.dart';

/// runApp 이전 최소 부트스트랩 — Web Mock 은 Firebase 완전 생략
abstract final class AppStartupBootstrap {
  /// Web Firebase 미설정 → 즉시 Mock DI (네트워크 대기 없음)
  static Future<AppStartupResult> runOfflineMock() async {
    debugPrint('[AppStartup] OFFLINE MOCK — Firebase skip');
    AppDependencies.instance.init(offlineMock: true);
    try {
      await AppDependencies.instance.mockDataStore?.hydrateFromDisk();
    } catch (e) {
      debugPrint('[AppStartup] mock store hydrate skip: $e');
    }
    try {
      await initializeDateFormatting('ko', null);
    } catch (e) {
      debugPrint('[AppStartup] date formatting skip: $e');
    }
    return AppStartupResult.offlineMock();
  }

  static Future<AppStartupResult> run() async {
    if (RuntimeMode.useOfflineMock) {
      return runOfflineMock();
    }

    var firebaseReady = false;
    String? warning;
    String? errorDetail;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 5));
      }
      firebaseReady = true;
      debugPrint('[AppStartup] Firebase.initializeApp OK');
      try {
        await Future.wait([
          HqPushCatalog.load(),
          HqAlimtalkCatalog.load(),
          PushNotificationService.init(),
        ]).timeout(const Duration(seconds: 6));
      } catch (e) {
        debugPrint('[AppStartup] Push init skip: $e');
      }
    } catch (e, st) {
      errorDetail = e.toString();
      debugPrint('[AppStartup] Firebase failed: $e\n$st');
      // Firebase 실패 → Mock fallback
      return runOfflineMock();
    }

    try {
      AppDependencies.instance.init(offlineMock: false);
    } catch (e, st) {
      errorDetail ??= e.toString();
      warning ??= '앱 의존성(DI) 초기화 중 문제가 발생했습니다.';
      debugPrint('[AppStartup] DI failed: $e\n$st');
      return runOfflineMock();
    }

    // Firestore rules(request.auth) — 시드/어드민 조회 전에 Auth 세션 확보
    try {
      final ok = await FirebaseAuthBridge.ensureStagingSession()
          .timeout(const Duration(seconds: 8));
      debugPrint('[AppStartup] staging Auth session: $ok');
      if (!ok) {
        warning ??= 'Firebase Auth 세션을 만들지 못했습니다. Firestore가 비어 보일 수 있습니다.';
      }
    } catch (e) {
      debugPrint('[AppStartup] staging Auth skip: $e');
      warning ??= 'Firebase Auth 연결에 실패했습니다.';
    }

    unawaited(_seedInBackground());

    try {
      await initializeDateFormatting('ko', null);
    } catch (e) {
      debugPrint('[AppStartup] date formatting skip: $e');
    }

    // Web + USE_FIREBASE_WEB=true 성공 시 Staging 배너로 모드 표시
    if (firebaseReady && warning == null && RuntimeMode.useFirebaseWeb) {
      return AppStartupResult.stagingFirebase();
    }

    return AppStartupResult(
      firebaseReady: firebaseReady,
      warning: warning,
      errorDetail: errorDetail,
    );
  }

  static Future<void> _seedInBackground() async {
    if (AppDependencies.instance.isOfflineMockMode) return;
    try {
      await AppDependencies.instance
          .ensureClubCatalogSeeded()
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[AppStartup] club seed background skip: $e');
    }
  }
}
