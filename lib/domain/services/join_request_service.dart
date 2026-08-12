import '../../models/member_role.dart';

/// 가입 신청 / 승인 권한 — 순수 함수
abstract final class JoinRequestService {
  static bool canSubmit({
    required bool isMember,
    required bool hasPendingRequest,
  }) =>
      !isMember && !hasPendingRequest;

  static bool isAdminRole(String role) => ClubMemberRole.isOfficer(role);

  /// 가입 신청 알림 수신자 우선순위: 총무 → 없으면 방장(회장)
  static String? notifyTargetRole({
    required bool hasActiveTreasurer,
  }) =>
      hasActiveTreasurer
          ? ClubMemberRole.treasurer
          : ClubMemberRole.president;
}
