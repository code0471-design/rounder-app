/// 포트원(PortOne) 본인인증 설정
///
/// 콘솔에서 발급받은 값을 아래에 넣으면 PASS 실연동이 활성화됩니다.
/// https://admin.portone.io
///
/// 현재 SDK: portone_flutter 0.12 (V1 본인인증)
/// - [userCode] = 가맹점 식별코드 (예: imp_xxxxxxxx)
class PortoneConfig {
  PortoneConfig._();

  /// 가맹점 식별코드 (V1 userCode) — 예: imp_xxxxxxxx
  static const String userCode = '';

  /// V2 채널 키 (SDK 업그레이드 후 사용). 지금은 비워 둬도 됩니다.
  static const String channelKey = '';

  /// 앱 URL Scheme (iOS/Android 복귀용)
  static const String appScheme = 'rounder';

  /// 회사명 (인증창 표시)
  static const String company = '라운더';

  /// PG사 — 다날 휴대폰 본인인증
  static const String pg = 'danal';

  /// 키가 채워졌는지 (V1: userCode만 필수)
  static bool get isConfigured => userCode.trim().isNotEmpty;

  /// 본인인증 요청 번호
  static String newMerchantUid() =>
      'cert_${DateTime.now().millisecondsSinceEpoch}';
}
