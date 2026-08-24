// ════════════════════════════════════════════════════════════
//  ROUNDER — User Model
// ════════════════════════════════════════════════════════════

/// 본인인증 방식
enum VerifyMethod { sms, pass }

/// 초대 경로
enum InviteSource { kakao, direct }

// ────────────────────────────────────────────────────────────
//  AppUser — 앱 가입 사용자
// ────────────────────────────────────────────────────────────
class AppUser {
  final String id;
  final String name;
  final String phone;       // 010-0000-0000 형식
  final double? handicap;   // 핸디캡 (선택)
  final bool isVerified;    // 본인인증 완료 여부
  final bool isAdmin;       // 관리자 여부 (회장·총무 등 운영자)
  final String role;        // 역할: '회장' | '총무' | '일반'
  final VerifyMethod? verifyMethod;  // SMS or PASS
  final DateTime createdAt;
  final String? profileImageUrl;

  AppUser({
    required this.id,
    required this.name,
    required this.phone,
    this.handicap,
    this.isVerified = false,
    this.isAdmin    = false,
    this.role       = '일반',
    this.verifyMethod,
    DateTime? createdAt,
    this.profileImageUrl,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 표시용 전화번호 (마스킹: 010-****-1234)
  String get maskedPhone {
    if (phone.length < 4) return phone;
    final parts = phone.replaceAll('-', '');
    if (parts.length == 11) {
      return '${parts.substring(0, 3)}-****-${parts.substring(7)}';
    }
    return phone;
  }

  /// 핸디 표시 텍스트
  String get handicapText {
    if (handicap == null) return '미입력';
    if (handicap! == handicap!.truncateToDouble()) {
      return handicap!.toInt().toString();
    }
    return handicap!.toStringAsFixed(1);
  }

  AppUser copyWith({
    String? name,
    String? phone,
    double? handicap,
    bool? isVerified,
    bool? isAdmin,
    String? role,
    VerifyMethod? verifyMethod,
    String? profileImageUrl,
  }) {
    return AppUser(
      id:             id,
      name:           name           ?? this.name,
      phone:          phone          ?? this.phone,
      handicap:       handicap       ?? this.handicap,
      isVerified:     isVerified     ?? this.isVerified,
      isAdmin:        isAdmin        ?? this.isAdmin,
      role:           role           ?? this.role,
      verifyMethod:   verifyMethod   ?? this.verifyMethod,
      createdAt:      createdAt,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}

// ────────────────────────────────────────────────────────────
//  InviteToken — 초대장 링크 정보
// ────────────────────────────────────────────────────────────
/// 초대장 종류 — 정회원용 / 게스트용
enum InviteMemberType { regular, guest }

class InviteToken {
  final String token;       // 고유 토큰 (URL에 포함)
  final String clubId;
  final String clubName;
  final String inviterName; // 초대한 사람 이름
  final String inviterId;
  final DateTime createdAt;
  final DateTime expiresAt; // 유효기간 (7일)
  final bool isUsed;
  final InviteMemberType inviteType; // 정회원 / 게스트 초대
  final String? guestName;    // 게스트 초대 시 총무가 미리 입력한 이름
  final String? referrerId;   // 게스트를 소개한 회원 id
  final String? referrerName; // 게스트를 소개한 회원 이름

  InviteToken({
    required this.token,
    required this.clubId,
    required this.clubName,
    required this.inviterName,
    required this.inviterId,
    DateTime? createdAt,
    DateTime? expiresAt,
    this.isUsed = false,
    this.inviteType = InviteMemberType.regular,
    this.guestName,
    this.referrerId,
    this.referrerName,
  })  : createdAt = createdAt ?? DateTime.now(),
        expiresAt = expiresAt ??
            (createdAt ?? DateTime.now()).add(const Duration(days: 7));

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !isExpired && !isUsed;
  bool get isGuestInvite => inviteType == InviteMemberType.guest;

  /// 앱 딥링크 URL
  String get deepLink {
    final name = Uri.encodeComponent(clubName);
    final inviter = Uri.encodeComponent(inviterName);
    return 'rounder://invite?token=$token&club=$clubId&name=$name&inviter=$inviter';
  }

  /// 카카오 공유용 웹 URL (실제 배포 시 도메인으로 교체)
  String get webUrl =>
      'https://rounder.app/invite?token=$token&club=$clubId';

  /// 카카오 알림톡 메시지 템플릿
  String kakaoMessage(String clubName) {
    if (isGuestInvite) {
      final name = guestName?.isNotEmpty == true ? '$guestName님, ' : '';
      return '''[ROUNDER] $name$inviterName님의 추천으로 '$clubName' 골프 모임에 게스트로 초대되었습니다! 🏌️

아래 링크를 눌러 게스트로 가입하세요 (7일 이내 유효)
$webUrl

#ROUNDER #골프모임 #게스트초대''';
    }
    return '''[ROUNDER] $inviterName님이 '$clubName' 골프 모임에 초대했습니다!

앱에서 초대를 확인해 주세요. (7일 이내 유효)
$webUrl

#ROUNDER #골프모임 #초대''';
  }
}
