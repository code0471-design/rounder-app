import '../../models/club_model.dart';
import '../../models/member_role.dart';
import '../../services/club_ops_sync.dart';

/// 모임찾기·내 모임 회원수.
///
/// 만든 사람 + 초대 가입 + 가입 승인만 센다. 같은 사람을 방장 자리와
/// 계정 자리로 두 번 세지 않고, 그 모임 회원이 아닌 찌꺼기는 뺀다.
abstract final class OfficialMemberCount {
  static String personKey({
    required String clubId,
    required String creatorUserId,
    required String memberId,
  }) {
    final id = memberId.trim();
    if (id.isEmpty) return '';
    if (id == 'm_creator_$clubId') {
      final creator = creatorUserId.trim();
      return creator.isEmpty ? 'creator:$clubId' : creator;
    }
    final prefix = 'm_${clubId}_';
    if (id.startsWith(prefix)) return id.substring(prefix.length);
    return id;
  }

  static int of({
    required String clubId,
    required String creatorUserId,
    required Iterable<Member> roster,
  }) {
    final seen = <String>{};
    for (final m in roster) {
      if (m.status != '활성') continue;
      if (m.memberType == '게스트') continue;
      if (ClubOpsSync.isForeignLeftoverMember(
        id: m.id,
        name: m.name,
        clubId: clubId,
        creatorUserId: creatorUserId,
      )) {
        continue;
      }
      final key = personKey(
        clubId: clubId,
        creatorUserId: creatorUserId,
        memberId: m.id,
      );
      if (key.isEmpty) continue;
      seen.add(key);
    }
    return seen.length;
  }

  /// 참석 인원. 방장 자리와 같은 사람 줄이 생겼다 사라져도 수는 그대로다.
  static List<Member> attendanceRoster({
    required String clubId,
    required String creatorUserId,
    required Iterable<Member> roster,
  }) {
    final active = roster.where((m) => m.status == '활성').toList();
    final creatorRow =
        active.where((m) => m.id == 'm_creator_$clubId').firstOrNull;
    final creatorName = creatorRow?.name.trim() ?? '';
    final creatorKey = creatorRow == null
        ? ''
        : personKey(
            clubId: clubId,
            creatorUserId: creatorUserId,
            memberId: creatorRow.id,
          );
    final seen = <String>{};
    final out = <Member>[];
    for (final m in active) {
      if (ClubOpsSync.isForeignLeftoverMember(
        id: m.id,
        name: m.name,
        clubId: clubId,
        creatorUserId: creatorUserId,
      )) {
        continue;
      }
      var key = personKey(
        clubId: clubId,
        creatorUserId: creatorUserId,
        memberId: m.id,
      );
      if (creatorRow != null &&
          m.id != creatorRow.id &&
          creatorName.isNotEmpty &&
          m.name.trim() == creatorName &&
          !ClubMemberRole.isOfficer(m.role)) {
        key = creatorKey;
      }
      if (key.isEmpty || !seen.add(key)) continue;
      out.add(m);
    }
    return out;
  }
}
