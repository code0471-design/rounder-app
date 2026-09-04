import 'package:firebase_core/firebase_core.dart';

import 'app_environment.dart';

/// 빌드가 의도한 Firebase 프로젝트에 붙었는지 검사한다.
///
/// 모바일에서는 네이티브 설정 파일(google-services.json / GoogleService-Info.plist)이
/// Dart 쪽 [DefaultFirebaseOptions] 보다 먼저 기본 앱을 초기화한다. 그래서
/// `--dart-define=APP_ENV=prod` 로 빌드해도 네이티브 파일이 스테이징이면
/// **운영 빌드가 조용히 스테이징에 쓰게 된다.** 이 가드가 그 경우를 잡는다.
abstract final class FirebaseEnvGuard {
  /// 문제가 없으면 null, 있으면 사용자에게 보여줄 오류 메시지.
  static String? verify() {
    if (!AppEnv.isRecognized) {
      return 'APP_ENV 값이 잘못되었습니다: "${AppEnv.rawValue}"\n'
          'staging 또는 prod 만 사용할 수 있습니다.';
    }

    final String actual;
    try {
      actual = Firebase.app().options.projectId;
    } catch (e) {
      return 'Firebase 앱이 초기화되지 않았습니다: $e';
    }

    if (actual != AppEnv.expectedProjectId) {
      return '빌드 환경과 Firebase 프로젝트가 다릅니다.\n'
          '빌드: ${AppEnv.label} (${AppEnv.expectedProjectId} 예상)\n'
          '실제 연결: $actual\n\n'
          'tool/select_firebase_env.py --env ${AppEnv.rawValue} 를 실행한 뒤 다시 빌드하세요.';
    }

    return null;
  }
}
