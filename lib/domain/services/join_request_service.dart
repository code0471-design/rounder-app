import '../../models/member_role.dart';

/// 가입 알림을 받을 운영진 계정. 명단 행 id 가 아니라 계정 id.
class JoinOfficer {
  const JoinOfficer({required this.userId, required this.role});

  final String userId;
  final String role;
}

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

  /// `m_{clubId}_{uid}` 명단 행이면 계정 id, 아니면 그대로.
  static String accountIdOf({
    required String clubId,
    required String memberOrUserId,
  }) {
    final raw = memberOrUserId.trim();
    if (raw.isEmpty || clubId.trim().isEmpty) return raw;
    final prefix = 'm_${clubId.trim()}_';
    if (raw.startsWith(prefix) && raw.length > prefix.length) {
      return raw.substring(prefix.length);
    }
    return raw;
  }

  /// 가입 알림 수신 계정. 총무 전원 → 없으면 회장 → 없으면 생성자.
  /// 신청자 기기 로컬 명단이 비어 있어도 서버 소속 계정만으로 고른다.
  static List<String> notifyAccountIds({
    required List<JoinOfficer> officers,
    String? creatorId,
  }) {
    final seen = <String>{};
    List<String> pick(bool Function(String role) pred) {
      final out = <String>[];
      for (final o in officers) {
        final uid = o.userId.trim();
        if (uid.isEmpty || !pred(o.role) || !seen.add(uid)) continue;
        out.add(uid);
      }
      return out;
    }

    final treasurers = pick(ClubMemberRole.isTreasurer);
    if (treasurers.isNotEmpty) return treasurers;

    final presidents = pick(
      (role) => ClubMemberRole.hasRole(role, ClubMemberRole.president),
    );
    if (presidents.isNotEmpty) return presidents;

    final creator = creatorId?.trim() ?? '';
    if (creator.isNotEmpty) return [creator];
    return const [];
  }

  static bool canApprove({
    required String myRole,
    required String? creatorId,
    required String reviewerId,
    String memberRole = '',
  }) {
    if (ClubMemberRole.canApproveJoins(myRole)) return true;
    if (memberRole.isNotEmpty && ClubMemberRole.canApproveJoins(memberRole)) {
      return true;
    }
    final creator = creatorId?.trim() ?? '';
    final reviewer = reviewerId.trim();
    return creator.isNotEmpty && reviewer.isNotEmpty && creator == reviewer;
  }
}
