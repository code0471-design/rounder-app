/// 빌드가 바라보는 백엔드 환경 (스테이징 / 운영)
///
/// `--dart-define=APP_ENV=prod` 로 운영 빌드, 지정하지 않으면 스테이징.
/// 값을 잘못 적으면 조용히 스테이징으로 떨어지지 않고 [isRecognized] 가 false 가 되어
/// `FirebaseEnvGuard` 가 앱을 멈춘다.
enum AppEnvironment { staging, prod }

abstract final class AppEnv {
  static const _raw = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'staging',
  );

  static const stagingProjectId = 'rounder-staging';
  static const prodProjectId = 'rounder-f6019';

  /// `--dart-define=APP_ENV=` 에 넘어온 원본 값
  static String get rawValue => _raw;

  /// 아는 환경 이름인지. 오타(`production`, `PROD` 등)를 가드가 잡게 한다.
  static bool get isRecognized => _raw == 'staging' || _raw == 'prod';

  static AppEnvironment get current =>
      _raw == 'prod' ? AppEnvironment.prod : AppEnvironment.staging;

  static bool get isProd => _raw == 'prod';

  static bool get isStaging => _raw == 'staging';

  /// 이 빌드가 반드시 붙어야 하는 Firebase projectId
  static String get expectedProjectId =>
      isProd ? prodProjectId : stagingProjectId;

  static String get label => isProd ? 'PROD' : 'STAGING';
}
