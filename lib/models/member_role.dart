/// 모임 내 직책 / 회원 등급
///
/// UI·승인·알림 라우팅에서 공통으로 사용합니다.
/// 레거시 값 `일반`은 [정규화] 시 `정회원`으로 취급합니다.
/// 한 사람이 여러 직책을 가질 수 있으며, 저장 형식은 `회장·총무`처럼 `·`로 연결합니다.
abstract final class ClubMemberRole {
  static const president = '회장';
  static const vicePresident = '부회장';
  static const treasurer = '총무';
  static const regular = '정회원';
  static const guest = '게스트';

  /// 레거시 호환
  static const legacyRegular = '일반';

  /// 가입 승인 시 선택 가능한 직책
  static const assignableRoles = <String>[
    president,
    vicePresident,
    treasurer,
    regular,
    guest,
  ];

  /// 운영진 (가입 승인·일부 관리 권한)
  static const officerRoles = <String>[
    president,
    vicePresident,
    treasurer,
  ];

  /// 총무 인수인계 진입 가능
  static const canTransferTreasurerRoles = <String>[
    president,
    treasurer,
  ];

  static const _rolePriority = <String>[
    treasurer,
    president,
    vicePresident,
    regular,
    guest,
  ];

  static String normalize(String role) {
    if (role == legacyRegular || role.isEmpty) return regular;
    return role;
  }

  /// `회장·총무`, `회장,총무` 등 복합 직책을 개별 역할로 분리
  static List<String> splitRoles(String role) {
    if (role.trim().isEmpty) return const [];
    final parts = role
        .split(RegExp(r'[·,/|]'))
        .map((e) => normalize(e.trim()))
        .where((e) => e.isNotEmpty);
    final seen = <String>{};
    final out = <String>[];
    for (final p in parts) {
      if (seen.add(p)) out.add(p);
    }
    return out;
  }

  /// 다중 직책을 표시/저장용 문자열로 합침
  static String encodeRoles(Iterable<String> roles) {
    final set = <String>{};
    for (final r in roles) {
      final n = normalize(r.trim());
      if (n.isNotEmpty) set.add(n);
    }
    if (set.isEmpty) return regular;

    final hasOfficer = set.any(officerRoles.contains);
    if (hasOfficer) {
      set.remove(regular);
      set.remove(legacyRegular);
    }
    if (set.contains(guest) && set.length > 1) {
      set.remove(guest);
    }

    final ordered = <String>[];
    for (final r in [
      president,
      vicePresident,
      treasurer,
      regular,
      guest,
    ]) {
      if (set.contains(r)) ordered.add(r);
    }
    for (final r in set) {
      if (!ordered.contains(r)) ordered.add(r);
    }
    return ordered.join('·');
  }

  static bool hasRole(String role, String want) =>
      splitRoles(role).contains(normalize(want));

  static bool isOfficer(String role) =>
      splitRoles(role).any(officerRoles.contains);

  static bool isTreasurer(String role) => hasRole(role, treasurer);

  /// 일정 등록 (회장·부회장·총무)
  static bool canCreateSchedule(String role) => isOfficer(role);

  /// 모임 정보 수정 (방장·부회장·총무)
  static bool canEditClubInfo(String role) => isOfficer(role);

  static bool canApproveJoins(String role) => isOfficer(role);

  static bool canTransferTreasurer(String role) =>
      splitRoles(role).any(canTransferTreasurerRoles.contains);

  /// 단일 대표 직책 (알림 라우팅 등) — 총무 > 회장 > 부회장 > …
  static String primaryRole(String role) {
    final parts = splitRoles(role);
    if (parts.isEmpty) return regular;
    for (final r in _rolePriority) {
      if (parts.contains(r)) return r;
    }
    return parts.first;
  }

  /// 게스트 승인 시 직책 강제
  static String roleForMemberType(String memberType, String selectedRole) {
    if (memberType == guest) return guest;
    final encoded = encodeRoles(splitRoles(selectedRole));
    if (hasRole(encoded, guest) && !isOfficer(encoded)) return guest;
    if (hasRole(encoded, guest)) {
      return encodeRoles(splitRoles(encoded).where((r) => r != guest));
    }
    return encoded;
  }

  /// 회원 유형 (정회원/게스트) — 직책 게스트면 게스트
  static String memberTypeForRole(String role) =>
      hasRole(role, guest) && !isOfficer(role) ? guest : regular;
}
