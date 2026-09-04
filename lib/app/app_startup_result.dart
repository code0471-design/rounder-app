/// 앱 cold start 결과 (Firebase·DI·시드)
class AppStartupResult {
  final bool firebaseReady;
  final bool offlineMockMode;
  final String? warning;
  final String? errorDetail;

  /// true 면 Mock 으로 우회하지 않고 실행을 막아야 하는 설정 오류.
  final bool fatal;

  const AppStartupResult({
    required this.firebaseReady,
    this.offlineMockMode = false,
    this.warning,
    this.errorDetail,
    this.fatal = false,
  });

  bool get hasWarning => warning != null && warning!.isNotEmpty;

  factory AppStartupResult.offlineMock() => const AppStartupResult(
        firebaseReady: false,
        offlineMockMode: true,
        warning:
            '오프라인 Mock 모드 — Firebase Web 미설정.\n'
            '로컬 샘플 데이터로 실행 중입니다.',
      );

  /// Staging Firebase 실연동 배너
  factory AppStartupResult.stagingFirebase() => const AppStartupResult(
        firebaseReady: true,
        offlineMockMode: false,
        warning: 'STAGING Firebase — 실데이터 모드 (Mock 아님)',
      );

  /// 운영 Firebase 실연동 — 배너 없음
  factory AppStartupResult.prodFirebase() => const AppStartupResult(
        firebaseReady: true,
        offlineMockMode: false,
      );

  /// 빌드 환경과 실제 Firebase 프로젝트가 어긋남 — Mock fallback 금지
  factory AppStartupResult.envMismatch(String detail) => AppStartupResult(
        firebaseReady: false,
        offlineMockMode: false,
        fatal: true,
        warning: '환경 설정 오류 — 앱을 실행할 수 없습니다.',
        errorDetail: detail,
      );
}
