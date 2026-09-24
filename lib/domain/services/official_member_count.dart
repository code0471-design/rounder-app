import '../../models/club_model.dart';
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
}
