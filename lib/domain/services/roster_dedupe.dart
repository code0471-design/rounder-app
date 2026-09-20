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
    var dropped = <String>{};
    if (creatorIdx >= 0) {

      final aliases = creatorAuthIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
      final creatorName = (maps[creatorIdx]['name'] as String? ?? '').trim();
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
      maps.removeWhere((m) => dropped.contains(m['id']));
    }
    dropped.addAll(_collapseSamePhoneMaps(maps, clubId));
    return RosterDedupeMapsResult(
      members: [...maps, ...others],
      droppedIds: dropped,
    );
  }

  static Set<String> _collapseSamePhoneMaps(
    List<Map<String, dynamic>> maps,
    String clubId,
  ) {
    final prefix = 'm_${clubId}_';
    final creatorRow = 'm_creator_$clubId';
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final m in maps) {
      final id = '${m['id'] ?? ''}';
      if (id != creatorRow && !id.startsWith(prefix)) continue;
      final phone = _digits(m['phone'] as String?);
      if (phone.length < 10) continue;
      groups.putIfAbsent(phone, () => []).add(m);
    }
    final dropped = <String>{};
    for (final group in groups.values) {
      if (group.length < 2) continue;
      final ranked = [...group]..sort((a, b) {
          return _keepScore(_memberFromMap(b))
              .compareTo(_keepScore(_memberFromMap(a)));
        });
      final keep = ranked.first;
      for (final extra in ranked.skip(1)) {
        _mergeMemberMap(keep, extra);
        dropped.add('${extra['id']}');
      }
    }
    if (dropped.isNotEmpty) {
      maps.removeWhere((m) => dropped.contains('${m['id']}'));
    }
    return dropped;
  }

  static Member _memberFromMap(Map<String, dynamic> m) => Member(
        id: '${m['id'] ?? ''}',
        name: '${m['name'] ?? ''}',
        gender: '${m['gender'] ?? '남'}',
        memberType: '${m['memberType'] ?? '정회원'}',
        role: '${m['role'] ?? '정회원'}',
        phone: m['phone'] as String?,
      );

  static void _mergeMemberMap(Map<String, dynamic> keep, Map<String, dynamic> extra) {
    String str(dynamic v) => (v as String? ?? '').trim();
    if (_preferName(str(extra['name']), str(keep['name']))) {
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
    final name = _preferName(extra.name, keep.name) ? extra.name : keep.name;
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

  static bool _looksKorean(String name) =>
      RegExp(r'[가-힣]').hasMatch(name.trim());

  /// [candidate] 를 [current] 대신 쓸지. 한글 실명 > 영문 닉네임 > 약한 이름.
  static bool _preferName(String candidate, String current) {
    if (_isWeakName(current) && !_isWeakName(candidate)) return true;
    if (_looksKorean(candidate) && !_looksKorean(current)) return true;
    return false;
  }

  static String _digits(String? phone) =>
      (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');

  static int _keepScore(Member m) {
    var s = 0;
    if (ClubMemberRole.isOfficer(m.role)) s += 100;
    if (RegExp(r'(kakao|google|apple)_').hasMatch(m.id)) s += 20;
    if (_looksKorean(m.name)) s += 10;
    if (m.id.endsWith('_m1') || m.id.contains('_m1')) s -= 5;
    return s;
  }

  /// 같은 전화번호면 누가 보든 한 줄. (아레나: Jeongwon Leeee + 이정원)
  /// 번호 없는 행은 합치지 않는다.
  static RosterDedupeResult collapseSamePhone({
    required List<Member> members,
    required String clubId,
  }) {
    final inClub = <Member>[];
    final others = <Member>[];
    for (final m in members) {
      if (Member.isClubRosterId(clubId, m.id)) {
        inClub.add(m);
      } else {
        others.add(m);
      }
    }

    final groups = <String, List<Member>>{};
    for (final m in inClub) {
      final phone = _digits(m.phone);
      if (phone.length < 10) continue;
      groups.putIfAbsent(phone, () => []).add(m);
    }

    final remap = <String, String>{};
    final dropped = <String>{};
    final next = List<Member>.from(inClub);

    for (final group in groups.values) {
      if (group.length < 2) continue;
      final ranked = [...group]..sort((a, b) => _keepScore(b).compareTo(_keepScore(a)));
      var keep = ranked.first;
      for (final extra in ranked.skip(1)) {
        final keepIdx = next.indexWhere((m) => m.id == keep.id);
        if (keepIdx < 0) continue;
        keep = mergeMember(next[keepIdx], extra);
        next[keepIdx] = keep;
        next.removeWhere((m) => m.id == extra.id);
        remap[extra.id] = keep.id;
        dropped.add(extra.id);
      }
    }

    if (dropped.isEmpty) {
      return RosterDedupeResult(
        members: List<Member>.from(members),
        idRemap: const {},
        droppedIds: const {},
      );
    }
    return RosterDedupeResult(
      members: [...next, ...others],
      idRemap: remap,
      droppedIds: dropped,
    );
  }

  static RosterDedupeResult collapseClub({
    required List<Member> members,
    required String clubId,
    Set<String> creatorAuthIds = const {},
  }) {
    final creator = collapseMembers(
      members: members,
      clubId: clubId,
      creatorAuthIds: creatorAuthIds,
    );
    final phone = collapseSamePhone(
      members: creator.members,
      clubId: clubId,
    );
    return RosterDedupeResult(
      members: phone.members,
      idRemap: {...creator.idRemap, ...phone.idRemap},
      droppedIds: {...creator.droppedIds, ...phone.droppedIds},
    );
  }
}
