/// 앱 cold start 결과 (Firebase·DI·시드)
class AppStartupResult {
  final bool firebaseReady;
  final bool offlineMockMode;
  final String? warning;
  final String? errorDetail;

  const AppStartupResult({
    required this.firebaseReady,
    this.offlineMockMode = false,
    this.warning,
    this.errorDetail,
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
}
