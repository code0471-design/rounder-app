import '../../models/club_model.dart';
import '../../models/member_role.dart';

/// 가입 알림을 받을 운영진 계정. 명단 행 id 가 아니라 계정 id.
class JoinOfficer {
  const JoinOfficer({required this.userId, required this.role});

  final String userId;
  final String role;
}

/// 가입 신청 / 승인 권한 — 순수 함수
abstract final class JoinRequestService {
  /// 원클럽과 같은 신청 문서 id. `jr_{모임id}_{신청자계정id}`
  static String requestId(String clubId, String userId) {
    final c = clubId.trim();
    final u = userId.trim();
    if (c.isEmpty || u.isEmpty) return '';
    return 'jr_${c}_$u';
  }

  /// FCM data.type. 제목만 있는 푸시는 홈만 연다.
  static bool isJoinPushType(String? type) {
    final t = (type ?? '').trim();
    return t == 'joinRequest' || t == 'push_join_request';
  }

  static bool isJoinResultPushType(String? type) {
    final t = (type ?? '').trim();
    return t == 'push_join_result' || t == 'joinApproved' || t == 'joinResult';
  }

  /// 승인/거절 푸시함 문서. 재시도해도 1장.
  static String resultInboxItemId(String requestId, {required bool approved}) {
    final id = requestId.trim();
    if (id.isEmpty) return '';
    return approved ? '${id}_ok' : '${id}_no';
  }

  /// 가입 푸시함은 `jr_` 고정 id 만. 자동 id 문서는 FCM 을 다시 쏜다.
  static bool isFixedJoinInboxItemId(String? itemId, String? type) {
    final id = (itemId ?? '').trim();
    if (id.isEmpty || !id.startsWith('jr_')) return false;
    if (isJoinResultPushType(type)) {
      return id.endsWith('_ok') || id.endsWith('_no');
    }
    if (isJoinPushType(type) || type == null || type.trim().isEmpty) {
      return !id.endsWith('_ok') && !id.endsWith('_no');
    }
    return false;
  }

  /// 이미 있는 푸시함 문서는 덮어도 FCM 을 다시 보내면 안 된다.
  static bool shouldCreateJoinInboxDoc({required bool alreadyExists}) =>
      !alreadyExists;

  static bool canSubmit({
    required bool isMember,
    required bool hasPendingRequest,
  }) =>
      !isMember && !hasPendingRequest;

  /// 같은 사람이 에러로 여러 장을 넣어도 대기 목록에는 1건만 보여 준다.
  /// 서버 문서를 지우지 않는다. `jr_` 고정 id 를 우선한다.
  static List<JoinRequest> uniquePendingByUser(List<JoinRequest> requests) {
    final byUser = <String, JoinRequest>{};
    for (final r in requests) {
      if (r.status != JoinRequestStatus.pending) continue;
      final uid = r.userId.trim();
      if (uid.isEmpty) continue;
      final prev = byUser[uid];
      if (prev == null) {
        byUser[uid] = r;
        continue;
      }
      final rFixed = r.id.startsWith('jr_');
      final pFixed = prev.id.startsWith('jr_');
      if (rFixed && !pFixed) {
        byUser[uid] = r;
      } else if (rFixed == pFixed &&
          r.requestedAt.isAfter(prev.requestedAt)) {
        byUser[uid] = r;
      }
    }
    final out = byUser.values.toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return out;
  }

  static bool isAdminRole(String role) => ClubMemberRole.isOfficer(role);

  /// 가입 신청 알림 수신자 우선순위: 총무 → 없으면 방장(회장)
  static String? notifyTargetRole({
    required bool hasActiveTreasurer,
  }) =>
      hasActiveTreasurer
          ? ClubMemberRole.treasurer
          : ClubMemberRole.president;

  /// 로그인 계정 id. 명단 행(`m_{모임}_{uid}`, `m_creator_…`)은 푸시함에 쓰지 않는다.
  static bool isLoginAccountId(String id) {
    final t = id.trim();
    return t.startsWith('kakao_') ||
        t.startsWith('google_') ||
        t.startsWith('apple_');
  }

  /// `m_{clubId}_{uid}` 명단 행이면 계정 id, 아니면 그대로.
  static String accountIdOf({
    required String clubId,
    required String memberOrUserId,
    String? creatorId,
  }) {
    final raw = memberOrUserId.trim();
    if (raw.isEmpty) return raw;
    if (isLoginAccountId(raw)) return raw;
    final c = clubId.trim();
    if (c.isNotEmpty) {
      final prefix = 'm_${c}_';
      if (raw.startsWith(prefix) && raw.length > prefix.length) {
        return raw.substring(prefix.length);
      }
      if (raw == 'm_creator_$c') {
        final cid = creatorId?.trim() ?? '';
        return isLoginAccountId(cid) ? cid : '';
      }
    }
    if (raw.startsWith('m_creator_')) {
      final cid = creatorId?.trim() ?? '';
      return isLoginAccountId(cid) ? cid : '';
    }
    return raw;
  }

  /// 푸시함·user_ops 에 쓸 로그인 계정. 접히지 않으면 빈 문자열.
  static String loginAccountIdOf({
    required String clubId,
    required String memberOrUserId,
    String? creatorId,
  }) {
    final folded = accountIdOf(
      clubId: clubId,
      memberOrUserId: memberOrUserId,
      creatorId: creatorId,
    );
    return isLoginAccountId(folded) ? folded : '';
  }

  /// 가입 알림 수신 계정. 총무 전원 → 없으면 회장 → 없으면 생성자.
  /// 신청자 기기 로컬 명단이 비어 있어도 서버 소속 계정만으로 고른다.
  /// 같은 사람은 한 번만, 명단 행 id 는 보내지 않는다.
  static List<String> notifyAccountIds({
    required List<JoinOfficer> officers,
    String? creatorId,
    String clubId = '',
  }) {
    final seen = <String>{};
    List<String> pick(bool Function(String role) pred) {
      final out = <String>[];
      for (final o in officers) {
        final uid = loginAccountIdOf(
          clubId: clubId,
          memberOrUserId: o.userId,
          creatorId: creatorId,
        );
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

    final creator = loginAccountIdOf(
      clubId: clubId,
      memberOrUserId: creatorId ?? '',
      creatorId: creatorId,
    );
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
