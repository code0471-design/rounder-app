import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// 런타임 모드 — Web도 Staging Firebase가 기본 (목업 아님)
abstract final class RuntimeMode {
  /// `--dart-define=FORCE_OFFLINE_MOCK=true` 로만 강제 Mock
  static const forceOfflineMock = bool.fromEnvironment('FORCE_OFFLINE_MOCK');

  /// 하위 호환. Web Firebase 사용은 이제 기본이며, 이 플래그는 문서/스크립트용.
  /// 예: `flutter build web --dart-define=USE_FIREBASE_WEB=true`
  static const useFirebaseWeb = bool.fromEnvironment(
    'USE_FIREBASE_WEB',
    defaultValue: true,
  );

  /// Mock은 강제 플래그이거나 Web Firebase options가 비어 있을 때만.
  static bool get useOfflineMock {
    if (forceOfflineMock) return true;
    if (kIsWeb) {
      if (!useFirebaseWeb) return true;
      return !DefaultFirebaseOptions.isWebConfigured;
    }
    return false;
  }
}
