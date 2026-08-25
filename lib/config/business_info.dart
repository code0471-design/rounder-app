/// 포트원·통신사 본인인증 심사에 필요한 사업자·서비스 정보.
///
/// 본인인증 화면 하단과 서비스 소개 페이지에 그대로 노출한다.
class BusinessInfo {
  BusinessInfo._();

  static const String serviceName = 'ROUNDER';
  static const String serviceNameKo = '라운더';

  /// 상호명
  static const String tradeName = '아레나엑스';

  /// 대표자명
  static const String ceo = '안경헌';

  /// 사업자번호
  static const String registrationNo = '889-38-01370';

  /// 사업장주소지
  static const String address = '서울특별시 동작구 사당로20사길 6, 제이하우스 301호';

  /// 전화번호 — 포트원/통신사 심사는 유선번호만 인정한다. 010은 거절된다.
  static const String phone = '070-4571-4169';

  static const String email = 'code0471@gmail.com';

  static const String serviceHeadline = '골프 모임 관리 서비스';

  static const String serviceIntro =
      'ROUNDER는 골프 동호회·지역 모임·클럽의 라운딩 일정, 참석, 회원, 회비, '
      '카카오 알림톡을 한곳에서 관리하는 모바일 서비스입니다. '
      '성인·도박·채팅 만남 서비스가 아닙니다.';

  static const List<String> serviceFeatures = [
    '라운딩 일정 등록과 참석·불참 관리',
    '회원·게스트·직책 관리 및 초대 가입',
    '회비 장부와 월/연 결산',
    '모임 운영용 정보성 카카오 알림톡·푸시',
  ];
}
