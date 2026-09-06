import '../../models/club_model.dart';
import '../../models/member_role.dart';

class RosterDedupeResult {
  final List<Member> members;
  final Map<String, String> idRemap;
  final Set<String> droppedIds;

  const RosterDedupeResult({
    required this.members,
    required this.idRemap,
    required this.droppedIds,
  });
}

class RosterDedupeMapsResult {
  final List<dynamic> members;
  final Set<String> droppedIds;

  const RosterDedupeMapsResult({
    required this.members,
    required this.droppedIds,
  });
}

/// 같은 사람이 `m_creator_{clubId}` 와 `m_{clubId}_{userId}` 두 줄로
/// 나오는 명단을 한 줄로 합친다. (임원진+정회원 중복 카드)
class RosterDedupe {
  static RosterDedupeResult collapseMembers({
    required List<Member> members,
    required String clubId,
    Set<String> creatorAuthIds = const {},
  }) {
    final creatorRowId = 'm_creator_$clubId';
    final prefix = 'm_${clubId}_';
    final creator = members.where((m) => m.id == creatorRowId).firstOrNull;
    if (creator == null) {
      return RosterDedupeResult(
        members: List<Member>.from(members),
        idRemap: const {},
        droppedIds: const {},
      );
    }

    final aliases = creatorAuthIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final drop = <String, Member>{};
    for (final m in members) {
      if (!m.id.startsWith(prefix)) continue;
      final suffix = m.id.substring(prefix.length);
      final suffixMatch = aliases.contains(suffix);
      final sameName = m.name.trim().isNotEmpty &&
          m.name.trim() == creator.name.trim() &&
          !ClubMemberRole.isOfficer(m.role);
      if (suffixMatch || sameName) {
        drop[m.id] = m;
      }
    }
    if (drop.isEmpty) {
      return RosterDedupeResult(
        members: List<Member>.from(members),
        idRemap: const {},
        droppedIds: const {},
      );
    }

    var keep = creator;
    for (final extra in drop.values) {
      keep = mergeMember(keep, extra);
    }
    return RosterDedupeResult(
      members: [
        keep,
        ...members.where((m) => m.id != creatorRowId && !drop.containsKey(m.id)),
      ],
      idRemap: {for (final id in drop.keys) id: keep.id},
      droppedIds: drop.keys.toSet(),
    );
  }

  static RosterDedupeMapsResult collapseMemberMaps({
    required List members,
    required String clubId,
    Set<String> creatorAuthIds = const {},
  }) {
    final creatorRowId = 'm_creator_$clubId';
    final prefix = 'm_${clubId}_';
    final maps = members
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final others = members.where((e) => e is! Map).toList();
    final creatorIdx = maps.indexWhere((m) => m['id'] == creatorRowId);
    if (creatorIdx < 0) {
      return RosterDedupeMapsResult(members: [...maps, ...others], droppedIds: const {});
    }

    final aliases = creatorAuthIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final creatorName = (maps[creatorIdx]['name'] as String? ?? '').trim();
    final dropped = <String>{};
    for (final m in maps) {
      final id = m['id'] as String? ?? '';
      if (!id.startsWith(prefix)) continue;
      final suffix = id.substring(prefix.length);
      final role = m['role'] as String? ?? '';
      final sameName = creatorName.isNotEmpty &&
          (m['name'] as String? ?? '').trim() == creatorName &&
          !ClubMemberRole.isOfficer(role);
      if (aliases.contains(suffix) || sameName) {
        dropped.add(id);
        _mergeMemberMap(maps[creatorIdx], m);
      }
    }
    if (dropped.isEmpty) {
      return RosterDedupeMapsResult(members: [...maps, ...others], droppedIds: const {});
    }
    return RosterDedupeMapsResult(
      members: [
        ...maps.where((m) => !dropped.contains(m['id'])),
        ...others,
      ],
      droppedIds: dropped,
    );
  }

  static void _mergeMemberMap(Map<String, dynamic> keep, Map<String, dynamic> extra) {
    String str(dynamic v) => (v as String? ?? '').trim();
    if (_isWeakName(str(keep['name'])) && !_isWeakName(str(extra['name']))) {
      keep['name'] = extra['name'];
    }
    if (str(keep['gender']).isEmpty && str(extra['gender']).isNotEmpty) {
      keep['gender'] = extra['gender'];
    }
    if ((keep['photoUrl'] == null || str(keep['photoUrl']).isEmpty) &&
        extra['photoUrl'] != null) {
      keep['photoUrl'] = extra['photoUrl'];
    }
    if ((keep['phone'] == null || str(keep['phone']).isEmpty) && extra['phone'] != null) {
      keep['phone'] = extra['phone'];
    }
    if (keep['handicap'] == null && extra['handicap'] != null) {
      keep['handicap'] = extra['handicap'];
    }
    if (keep['birthDate'] == null && extra['birthDate'] != null) {
      keep['birthDate'] = extra['birthDate'];
    }
  }

  static Member mergeMember(Member keep, Member extra) {
    final keepPlaceholder = _isWeakName(keep.name);
    final extraPlaceholder = _isWeakName(extra.name);
    final name = (keepPlaceholder && !extraPlaceholder) ? extra.name : keep.name;
    final role = ClubMemberRole.isOfficer(keep.role)
        ? keep.role
        : (ClubMemberRole.isOfficer(extra.role) ? extra.role : keep.role);
    return keep.copyWith(
      name: name,
      gender: keep.gender.trim().isEmpty ? extra.gender : keep.gender,
      birthDate: keep.birthDate ?? extra.birthDate,
      photoUrl: (keep.photoUrl == null || keep.photoUrl!.trim().isEmpty)
          ? extra.photoUrl
          : keep.photoUrl,
      phone: (keep.phone == null || keep.phone!.trim().isEmpty)
          ? extra.phone
          : keep.phone,
      bio: (keep.bio == null || keep.bio!.trim().isEmpty) ? extra.bio : keep.bio,
      role: role,
      memberType: ClubMemberRole.memberTypeForRole(role),
      handicap: keep.handicap ?? extra.handicap,
      joinDate: keep.joinDate ?? extra.joinDate,
      address:
          (keep.address == null || keep.address!.trim().isEmpty)
              ? extra.address
              : keep.address,
    );
  }

  static bool _isWeakName(String name) {
    final t = name.trim();
    return t.isEmpty || t == '회원' || t == '홍길동';
  }
}
