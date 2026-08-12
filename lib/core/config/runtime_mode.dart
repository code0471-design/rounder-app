import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// 런타임 모드 — Web은 기본 오프라인 Mock (테스트 데이터·어드민 초기화 일치)
abstract final class RuntimeMode {
  /// `--dart-define=FORCE_OFFLINE_MOCK=true` 로 강제 Mock
  static const forceOfflineMock = bool.fromEnvironment('FORCE_OFFLINE_MOCK');

  /// Web에서 Firestore 실연동할 때만 true
  /// 예: `flutter run -d chrome --dart-define=USE_FIREBASE_WEB=true`
  static const useFirebaseWeb = bool.fromEnvironment('USE_FIREBASE_WEB');

  /// Firebase Web 미설정·미사용 또는 강제 플래그 → Firestore 없이 로컬 샘플만 사용.
  /// Web Firebase options가 채워져 있어도, 테스트 기본값은 Mock이다.
  /// (어드민이 Firestore 모임 2개 / 앱은 ClubProvider mock 을 보는 분열 방지)
  static bool get useOfflineMock {
    if (forceOfflineMock) return true;
    if (kIsWeb) {
      if (!useFirebaseWeb) return true;
      return !DefaultFirebaseOptions.isWebConfigured;
    }
    return false;
  }
}
