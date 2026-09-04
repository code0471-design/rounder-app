import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/data/club_sample_catalog.dart';
import '../../../models/club_model.dart';
import 'mock_store_persistence.dart';

/// 오프라인 Mock 공유 메모리 저장소 (앱 리포지토리 + 어드민 공유)
final class MockDataStore extends ChangeNotifier {
  MockDataStore({List<Club>? seedClubs})
      : clubs = List<Club>.from(seedClubs ?? ClubSampleCatalog.clubs) {
    _seedDefaultMemberships();
    _seedAppUsers();
  }

  bool _hydrating = false;
  Timer? _persistTimer;

  /// 디스크에서 사용자 생성 모임 복원 (앱↔어드민 공유)
  Future<void> hydrateFromDisk() async {
    _hydrating = true;
    try {
      await MockStorePersistence.loadInto(this);
    } finally {
      _hydrating = false;
      notifyListeners();
    }
  }

  void _schedulePersist() {
    if (_hydrating) return;
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 200), () {
      unawaited(MockStorePersistence.save(this));
    });
  }

  final List<Club> clubs;
  final List<JoinRequest> pendingJoinRequests = [];
  final Map<String, Map<String, Member>> membersByClub = {};

  /// 플랫폼 어드민용 모임 검수 상태: pending | active | ended | blinded
  final Map<String, String> _clubModeration = {};

  /// 플랫폼 어드민용 계정 상태: normal | blocked
  final Map<String, String> _userAccountStatus = {};

  final Map<String, int> _clubMaxMembers = {};

  /// Auth와 공유할 앱 사용자 목록 (어드민 회원 관리)
  final List<MockAppUser> appUsers = [];

  void upsertAppUser(MockAppUser user) {
    final i = appUsers.indexWhere((u) => u.id == user.id);
    if (i >= 0) {
      appUsers[i] = user;
    } else {
      appUsers.add(user);
    }
    notifyListeners();
    _schedulePersist();
  }

  /// 어드민 회원 모임수 오버라이드 (앱 내모임 수와 맞춤)
  final Map<String, int> _clubCountOverride = {};

  void _seedDefaultMemberships() {
    // 클린 슬레이트: 시드 모임/멤버십 없음 — 사용자가 만든 모임만 존재
    for (final c in clubs) {
      _clubModeration.putIfAbsent(c.id, () => 'active');
    }
  }

  void _seedAppUsers() {
    appUsers
      ..clear()
      ..addAll([
        MockAppUser(
          id: 'user_me',
          name: '홍길동',
          phone: '010-1234-5678',
          gender: '남',
          createdAt: DateTime(2024, 3, 1),
        ),
        MockAppUser(
          id: 'user_guest',
          name: '이민준',
          phone: '010-9999-0000',
          gender: '남',
          createdAt: DateTime(2024, 7, 1),
        ),
      ]);
  }

  String clubModerationStatus(String clubId) =>
      _clubModeration[clubId] ?? 'active';

  /// 저장소에 검수 상태가 이미 있으면 그 값, 없으면 null
  String? clubModerationStatusOrNull(String clubId) =>
      _clubModeration[clubId];

  int clubMaxMembers(String clubId) => _clubMaxMembers[clubId] ?? 20;

  String userAccountStatus(String userId) =>
      _userAccountStatus[userId] ?? 'normal';

  void setClubModerationStatus(
    String clubId,
    String status, {
    bool persist = true,
  }) {
    _clubModeration[clubId] = status;
    notifyListeners();
    if (persist) _schedulePersist();
  }

  void setUserAccountStatus(String userId, String status) {
    _userAccountStatus[userId] = status;
    notifyListeners();
  }

  void clearUserPhone(String userId) {
    final i = appUsers.indexWhere((u) => u.id == userId);
    if (i == -1) return;
    final u = appUsers[i];
    appUsers[i] = MockAppUser(
      id: u.id,
      name: u.name,
      phone: '',
      gender: u.gender,
      createdAt: u.createdAt,
    );
    notifyListeners();
    _schedulePersist();
  }

  void upsertClub(
    Club club, {
    String moderationStatus = 'active',
    int maxMembers = 20,
    bool persist = true,
  }) {
    final i = clubs.indexWhere((c) => c.id == club.id);
    if (i >= 0) {
      clubs[i] = club;
    } else {
      clubs.add(club);
    }
    _clubModeration[club.id] = moderationStatus;
    _clubMaxMembers[club.id] = maxMembers;
    notifyListeners();
    if (persist) _schedulePersist();
  }

  /// 레거시 템플릿(c1~c10) 등 저장소에서 제거
  void removeClub(String clubId, {bool persist = true}) {
    clubs.removeWhere((c) => c.id == clubId);
    membersByClub.remove(clubId);
    _clubModeration.remove(clubId);
    _clubMaxMembers.remove(clubId);
    notifyListeners();
    if (persist) _schedulePersist();
  }

  /// 외부 리포지토리에서 필드 직접 수정 후 구독자에 알릴 때 사용
  void bump({bool persist = true}) {
    notifyListeners();
    if (persist) _schedulePersist();
  }

  void setMemberClubCountOverride(String userId, int count) {
    _clubCountOverride[userId] = count;
  }

  int? memberClubCountOverride(String userId) => _clubCountOverride[userId];

  Club? clubById(String clubId) {
    try {
      return clubs.firstWhere((c) => c.id == clubId);
    } catch (_) {
      return null;
    }
  }

  Club clubForUser(String clubId, String userId) {
    final base = clubById(clubId);
    if (base == null) throw StateError('club not found: $clubId');
    final role = roleFor(clubId, userId);
    if (role == null) return base;
    return base.copyWith(myRole: role);
  }

  bool isMember(String clubId, String userId) =>
      membersByClub[clubId]?.containsKey(userId) ?? false;

  String? roleFor(String clubId, String userId) =>
      membersByClub[clubId]?[userId]?.role;

  List<Member> membersOf(String clubId) =>
      membersByClub[clubId]?.values.toList() ?? const [];

  void addMember({
    required String clubId,
    required Member member,
    bool bumpCount = true,
    List<String> alsoAsIds = const [],
    bool persist = true,
  }) {
    final map = membersByClub.putIfAbsent(clubId, () => {});
    map[member.id] = member;
    for (final altId in alsoAsIds) {
      if (altId.isEmpty || altId == member.id) continue;
      map[altId] = Member(
        id: altId,
        name: member.name,
        gender: member.gender,
        phone: member.phone,
        memberType: member.memberType,
        role: member.role,
        handicap: member.handicap,
        joinDate: member.joinDate,
        status: member.status,
      );
    }
    if (bumpCount) _bumpMemberCount(clubId, 1);
    notifyListeners();
    if (persist) _schedulePersist();
  }

  void _bumpMemberCount(String clubId, int delta) {
    final i = clubs.indexWhere((c) => c.id == clubId);
    if (i == -1) return;
    final next = (clubs[i].memberCount + delta).clamp(0, 9999);
    clubs[i] = clubs[i].copyWith(memberCount: next);
  }

  JoinRequest? pendingForUser(String clubId, String userId) {
    try {
      return pendingJoinRequests.firstWhere(
        (r) => r.clubId == clubId && r.userId == userId,
      );
    } catch (_) {
      return null;
    }
  }

  List<JoinRequest> pendingForClub(String clubId) =>
      pendingJoinRequests.where((r) => r.clubId == clubId).toList();

  Set<String> pendingClubIdsForUser(String userId) => pendingJoinRequests
      .where((r) => r.userId == userId)
      .map((r) => r.clubId)
      .toSet();

  /// 계정 전환과 무관하게 공유되는 가입 신청 upsert
  void upsertPendingJoinRequest(JoinRequest req, {bool persist = true}) {
    pendingJoinRequests.removeWhere(
      (r) =>
          r.id == req.id ||
          (r.clubId == req.clubId &&
              r.userId == req.userId &&
              r.status == JoinRequestStatus.pending),
    );
    pendingJoinRequests.add(req);
    notifyListeners();
    if (persist) _schedulePersist();
  }

  void removePendingJoinRequest(String requestId, {bool persist = true}) {
    final before = pendingJoinRequests.length;
    pendingJoinRequests.removeWhere((r) => r.id == requestId);
    if (pendingJoinRequests.length == before) return;
    notifyListeners();
    if (persist) _schedulePersist();
  }

  /// 테스트/데모 데이터를 시드 모임(ClubSampleCatalog) 상태로 완전 초기화.
  /// localStorage에 누적된 임의 테스트 모임·회원수를 모두 제거한다.
  void resetToSeedDefaults({bool persist = true}) {
    clubs
      ..clear()
      ..addAll(ClubSampleCatalog.clubs);
    membersByClub.clear();
    pendingJoinRequests.clear();
    _clubModeration.clear();
    _clubMaxMembers.clear();
    _clubCountOverride.clear();
    appUsers.clear();
    _seedDefaultMemberships();
    _seedAppUsers();
    notifyListeners();
    if (persist) _schedulePersist();
  }
}

/// Mock 전용 앱 사용자 (어드민 회원 목록용)
class MockAppUser {
  const MockAppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.gender,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String gender;
  final DateTime createdAt;
}
