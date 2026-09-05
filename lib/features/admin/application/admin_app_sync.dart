import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../di/app_dependencies.dart';
import '../../../data/repositories/mock/mock_data_store.dart';
import '../../../data/repositories/mock/mock_store_persistence.dart';
import '../../../domain/data/club_sample_catalog.dart';
import '../../../models/club_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/club_provider.dart';
import '../../../services/club_data_codec.dart';
import '../../../services/club_persistence.dart';
import '../../../services/firebase_auth_bridge.dart';

class AdminSyncReport {
  final int storeTotal;
  final int operating;
  final int memberCount;
  final List<String> myClubLabels;
  final List<String> pendingNames;
  final List<String> userClubNames;

  const AdminSyncReport({
    required this.storeTotal,
    required this.operating,
    required this.memberCount,
    required this.myClubLabels,
    required this.pendingNames,
    required this.userClubNames,
  });
}

/// 앱 → 어드민 단일 동기화
abstract final class AdminAppSync {
  static final _seedIds =
      ClubSampleCatalog.clubs.map((c) => c.id).toSet();

  static AdminSyncReport? lastReport;

  static Future<AdminSyncReport> syncFromApp({
    required AuthProvider auth,
    required ClubProvider clubs,
  }) async {
    final store = AppDependencies.instance.mockDataStore;
    // Staging/Firebase — Mock store 없음. 로컬에만 있는 사용자 모임을 Firestore로 올림
    if (store == null) {
      return lastReport = await _syncLocalClubsToFirestore(
        auth: auth,
        clubs: clubs,
      );
    }

    try {
      await store.hydrateFromDisk();
    } catch (e) {
      debugPrint('[AdminAppSync] hydrate: $e');
    }

    // 어드민 동기화가 ClubProvider 계정을 가로채지 않도록 이전 계정 기억
    final previousPersistUserId = clubs.persistAuthUserId;
    var userId = 'user_me';
    try {
      await auth.tryAutoLogin();
      userId = auth.currentUser?.id ?? 'user_me';
      await clubs.switchUser(userId, displayName: auth.currentUser?.name);
    } catch (_) {
      try {
        await clubs.switchUser('user_me');
        userId = 'user_me';
      } catch (_) {}
    }
    clubs.ensureCreatorMembers();

    final fresh = <String>{
      for (final c in [...clubs.myClubs, ...clubs.allClubs])
        if (clubs.isFreshClub(c.id)) c.id,
    };

    // 1) ClubPersistence + 전 계정 (게스트 포함 — 다른 계정이 만든 모임/회원 반영)
    try {
      for (final uid in {userId, 'user_me', 'user_guest'}) {
        final bundle = await ClubPersistence.load(uid);
        if (bundle == null) continue;
        fresh.addAll(bundle.freshClubIds);
        _upsertClubsFromBundle(store, bundle, fresh);
      }
    } catch (e) {
      debugPrint('[AdminAppSync] persistence: $e');
    }

    // 2) raw localStorage 스캔 — version 검사 무시하고 c_* 강제 복원
    await _forceScanRawUserClubs(store);

    // 3) ClubProvider 메모리
    _upsertClubs(
      store,
      [...clubs.myClubs, ...clubs.allClubs],
      clubs,
      fresh,
    );

    // ※ 과거에는 여기서 "어디서도 발견되지 않는 모임"을 자동 삭제했으나,
    //   다른 탭/세션에 살아있는 실제 사용자 모임까지 지워버리는 위험이 있어 제거함.
    //   (절대 자동으로 모임을 삭제하지 않는다 — 데이터 유실 방지 최우선)

    // 4) 각 모임 회원수 = 게스트 제외 활성 인원으로 갱신 (실 명단이 있을 때만)
    _reconcileAllMemberCounts(store);

    store.setMemberClubCountOverride('user_me', clubs.myClubs.length);
    store.setMemberClubCountOverride('m1', clubs.myClubs.length);
    store.setMemberClubCountOverride(userId, clubs.myClubs.length);

    await MockStorePersistence.save(store);
    store.bump(persist: false);

    // 앱 세션 계정 복구 (동기화 중 switchUser로 바뀐 상태 되돌림)
    final restoreId = previousPersistUserId ?? auth.currentUser?.id;
    if (restoreId != null && restoreId != clubs.persistAuthUserId) {
      try {
        await clubs.switchUser(restoreId);
      } catch (e) {
        debugPrint('[AdminAppSync] restore user $restoreId: $e');
      }
    }

    final operating = store.clubs.where((c) {
      final s = store.clubModerationStatus(c.id);
      return s == 'active' || s == 'pending';
    }).length;

    final pendingNames = store.clubs
        .where((c) => store.clubModerationStatus(c.id) == 'pending')
        .map((c) => c.name)
        .toList();
    final userClubNames = store.clubs
        .where((c) => c.id.startsWith('c_'))
        .map((c) => c.name)
        .toList();

    final memberIds = <String>{};
    for (final entry in store.membersByClub.entries) {
      for (final m in entry.value.values) {
        if (m.id == 'user_me') continue;
        if (m.memberType == '게스트') continue;
        if (m.status != '활성') continue;
        memberIds.add(m.id);
      }
    }

    final report = AdminSyncReport(
      storeTotal: store.clubs.length,
      operating: operating,
      memberCount: memberIds.length,
      myClubLabels:
          clubs.myClubs.map((c) => '${c.name}(${c.id})').toList(),
      pendingNames: pendingNames,
      userClubNames: userClubNames,
    );
    lastReport = report;

    debugPrint(
      '[AdminAppSync] total=${report.storeTotal} operating=$operating '
      'userClubs=$userClubNames pending=$pendingNames '
      'my=${report.myClubLabels}',
    );
    return report;
  }

  /// Firebase 모드: ClubProvider/로컬 저장에만 있는 사용자 모임을 Firestore로 푸시
  static Future<AdminSyncReport> _syncLocalClubsToFirestore({
    required AuthProvider auth,
    required ClubProvider clubs,
  }) async {
    var userId = 'user_me';
    try {
      await auth.tryAutoLogin();
      userId = auth.currentUser?.id ?? 'user_me';
      await clubs.switchUser(userId, displayName: auth.currentUser?.name);
    } catch (_) {
      try {
        await clubs.switchUser('user_me');
        userId = 'user_me';
      } catch (_) {}
    }
    // Admin 탭은 앱 로그인 UI가 없어도 Firestore 읽기/쓰기용 Auth 필요
    await FirebaseAuthBridge.ensureStagingSession(userId: userId);
    clubs.ensureCreatorMembers();

    const legacyDemoIds = {'c1', 'c2', 'c3', 'c4', 'c5', 'c6'};
    bool isUserCreated(Club c) =>
        !_isSeed(c.id) && !legacyDemoIds.contains(c.id) && c.id.startsWith('c_');

    final byId = <String, Club>{
      for (final c in [...clubs.myClubs, ...clubs.allClubs])
        if (isUserCreated(c)) c.id: c,
    };

    try {
      for (final uid in {userId, 'user_me'}) {
        final bundle = await ClubPersistence.load(uid);
        if (bundle == null) continue;
        for (final c in [...bundle.myClubs, ...bundle.allClubs]) {
          if (isUserCreated(c)) byId[c.id] = c;
        }
      }
    } catch (e) {
      debugPrint('[AdminAppSync] firebase persistence scan: $e');
    }

    final repo = AppDependencies.instance.clubRepository;
    final pendingNames = <String>[];
    final userClubNames = <String>[];

    for (final club in byId.values) {
      if (!club.id.startsWith('c_')) continue;
      userClubNames.add(club.name);
      pendingNames.add(club.name);
      final members = clubs.membersForClub(club.id);
      final creator = members.isNotEmpty
          ? members.first
          : Member(
              id: 'm_creator_${club.id}',
              name: auth.currentUser?.name ?? clubs.currentUserName,
              gender: '남',
              memberType: '정회원',
              role: club.myRole.isNotEmpty ? club.myRole : '총무',
              joinDate: club.createdAt,
              status: '활성',
            );
      try {
        await repo.createClub(
          club: club,
          userId: club.creatorId.isNotEmpty ? club.creatorId : userId,
          userName: creator.name,
          creatorMember: creator,
          moderationStatus: 'active',
        );
        debugPrint('[AdminAppSync] pushed ${club.name}(${club.id}) → Firestore');
      } catch (e) {
        debugPrint('[AdminAppSync] push ${club.id} failed: $e');
      }
    }

    List<Club> remote = const [];
    try {
      remote = await repo.fetchDiscoverableClubs();
    } catch (e) {
      debugPrint('[AdminAppSync] remote fetch: $e');
    }

    final report = AdminSyncReport(
      storeTotal: remote.length,
      operating: remote.length,
      memberCount: 0,
      myClubLabels:
          clubs.myClubs.map((c) => '${c.name}(${c.id})').toList(),
      pendingNames: pendingNames,
      userClubNames: userClubNames,
    );
    debugPrint(
      '[AdminAppSync:firestore] pushed=${userClubNames.length} '
      'remote=${remote.length} my=${report.myClubLabels}',
    );
    return report;
  }

  /// 테스트 목적의 로컬 목 데이터를 모두 지우고 클린 슬레이트(모임 0)로 초기화.
  static Future<AdminSyncReport> resetAllMockData({
    ClubProvider? clubs,
    String authUserId = 'user_me',
  }) async {
    clubs?.resetToDemoDefaults(authUserId: authUserId);

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(
          (k) =>
              k == 'rounder_mock_store_v1' ||
              k == 'rounder_mock_store_v2' ||
              k.startsWith('rounder_club_data_v1_') ||
              k.startsWith('rounder_club_data_v2_') ||
              k.startsWith('rounder_left_clubs_') ||
              k.startsWith('rounder_shared_pending_joins_'),
        );
    for (final k in keys.toList()) {
      await prefs.remove(k);
    }

    final store = AppDependencies.instance.mockDataStore;
    store?.resetToSeedDefaults(persist: false);
    if (store != null) {
      await MockStorePersistence.save(store);
    }

    final report = AdminSyncReport(
      storeTotal: store?.clubs.length ?? 0,
      operating: 0,
      memberCount: 0,
      myClubLabels: const [],
      pendingNames: const [],
      userClubNames: const [],
    );
    lastReport = report;
    return report;
  }

  static bool _isSeed(String id) =>
      _seedIds.contains(id) || id.startsWith('seed_');

  static void _upsertClubs(
    MockDataStore store,
    List<Club> list,
    ClubProvider clubs,
    Set<String> fresh,
  ) {
    final seen = <String>{};
    for (final c in list) {
      if (!seen.add(c.id)) continue;
      if (_isSeed(c.id)) continue;
      // 데모 템플릿(c1~c10)은 seed_cN으로 이미 store에 존재 — 별도 행으로 중복 upsert 금지
      if (RegExp(r'^c\d+$').hasMatch(c.id) && _seedIds.contains('seed_${c.id}')) {
        continue;
      }

      final status =
          store.clubModerationStatusOrNull(c.id) ??
              'active';
      store.upsertClub(c, moderationStatus: status, persist: false);

      for (final m in clubs.membersForClub(c.id)) {
        store.addMember(
          clubId: c.id,
          member: m,
          bumpCount: false,
          alsoAsIds: _alsoAsIdsForMember(c, m),
          persist: false,
        );
      }
    }
  }

  static List<String> _alsoAsIdsForMember(Club c, Member m) {
    final ids = <String>{};
    if (m.id == 'm1' || c.creatorId == 'user_me') {
      ids.addAll(['user_me', 'm1']);
    }
    if (m.id == 'mg1' || c.creatorId == 'user_guest') {
      ids.addAll(['user_guest', 'mg1']);
    }
    if (m.id == 'm_creator_${c.id}') {
      if (c.creatorId == 'user_guest' || c.creatorId.isEmpty) {
        ids.addAll(['user_guest', 'mg1']);
      }
      if (c.creatorId == 'user_me') {
        ids.addAll(['user_me', 'm1']);
      }
      if (c.creatorId.isNotEmpty) ids.add(c.creatorId);
    }
    ids.remove(m.id);
    return ids.toList();
  }

  /// 번들 소유 계정의 회원 명단까지 같이 올려 어드민 가입일/회원수 유실 방지
  static void _upsertClubsFromBundle(
    MockDataStore store,
    ClubDataBundle bundle,
    Set<String> fresh,
  ) {
    final seen = <String>{};
    for (final c in [...bundle.myClubs, ...bundle.allClubs]) {
      if (!seen.add(c.id)) continue;
      if (_isSeed(c.id)) continue;
      if (RegExp(r'^c\d+$').hasMatch(c.id) &&
          _seedIds.contains('seed_${c.id}')) {
        continue;
      }
      final status =
          store.clubModerationStatusOrNull(c.id) ?? 'active';
      store.upsertClub(c, moderationStatus: status, persist: false);

      for (final m in bundle.members) {
        final belongs = m.id == 'm_creator_${c.id}' ||
            m.id.startsWith('m_${c.id}_') ||
            (c.creatorId.isNotEmpty && m.id == c.creatorId);
        if (!belongs) continue;
        final withJoin = m.joinDate != null
            ? m
            : Member(
                id: m.id,
                name: m.name,
                gender: m.gender,
                phone: m.phone,
                memberType: m.memberType,
                role: m.role,
                handicap: m.handicap,
                joinDate: c.createdAt,
                status: m.status,
              );
        store.addMember(
          clubId: c.id,
          member: withJoin,
          bumpCount: false,
          alsoAsIds: _alsoAsIdsForMember(c, withJoin),
          persist: false,
        );
      }
    }
  }

  /// localStorage 전수 스캔 — c_* 모임 JSON을 무조건 upsert
  /// 발견한 모든 c_* id를 반환 (고아 데이터 정리 시 "생존" 판정에 사용)
  static Future<Set<String>> _forceScanRawUserClubs(MockDataStore store) async {
    final found = <String>{};
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;
      if (!raw.contains('"c_') && !raw.contains("'c_")) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final map = Map<String, dynamic>.from(decoded);
        for (final listKey in ['myClubs', 'allClubs', 'clubs']) {
          final list = map[listKey];
          if (list is! List) continue;
          for (final item in list) {
            if (item is! Map) continue;
            final m = Map<String, dynamic>.from(item);
            final id = m['id'] as String? ?? '';
            if (!id.startsWith('c_')) continue;
            found.add(id);
            final existing = store.clubById(id);
            final scannedCreator = m['creatorId'] as String? ?? '';
            final club = Club(
              id: id,
              name: m['name'] as String? ?? existing?.name ?? '모임',
              myRole: m['myRole'] as String? ?? existing?.myRole ?? '총무',
              memberCount: m['memberCount'] as int? ??
                  existing?.memberCount ??
                  1,
              // 빈 creatorId로 기존 값을 덮어쓰지 않음
              creatorId: scannedCreator.isNotEmpty
                  ? scannedCreator
                  : (existing?.creatorId ?? ''),
              region: m['region'] as String? ?? existing?.region ?? '',
              industry: m['industry'] as String? ?? existing?.industry ?? '',
              teamCount: m['teamCount'] as int? ?? existing?.teamCount ?? 4,
              description: m['description'] as String? ??
                  existing?.description ??
                  '',
              createdAt: m['createdAt'] != null
                  ? DateTime.tryParse(m['createdAt'] as String) ??
                      existing?.createdAt ??
                      DateTime.now()
                  : existing?.createdAt ?? DateTime.now(),
            );
            final status = m['moderationStatus'] as String? ??
                store.clubModerationStatusOrNull(id) ??
                'pending';
            store.upsertClub(club, moderationStatus: status, persist: false);
          }
        }
      } catch (_) {}
    }
    return found;
  }

  /// 게스트·alias 제외한 활성 정회원 수로 Club.memberCount 갱신
  /// 실제 명단이 없는 모임(n==0)은 기존 값을 보존
  static void _reconcileAllMemberCounts(MockDataStore store) {
    for (final c in List<Club>.from(store.clubs)) {
      final n = countRegularMembers(store, c.id);
      if (n > 0 && n != c.memberCount) {
        store.upsertClub(
          c.copyWith(memberCount: n),
          moderationStatus: store.clubModerationStatus(c.id),
          maxMembers: store.clubMaxMembers(c.id),
          persist: false,
        );
      }
    }
  }

  /// 게스트 제외 · user_me alias 제외 · 이름 중복 제거
  static int countRegularMembers(MockDataStore store, String clubId) {
    final clubIds = <String>{clubId};
    if (clubId.startsWith('seed_')) {
      clubIds.add(clubId.substring('seed_'.length)); // seed_c1 → c1
    } else if (RegExp(r'^c\d+$').hasMatch(clubId)) {
      clubIds.add('seed_$clubId');
    }

    final seen = <String>{};
    var n = 0;
    for (final id in clubIds) {
      for (final m in store.membersOf(id)) {
        if (m.status != '활성') continue;
        if (m.memberType == '게스트') continue;
        if (m.id == 'user_me') continue;
        final key = m.phone?.isNotEmpty == true ? m.phone! : '${m.id}:${m.name}';
        if (!seen.add(key)) continue;
        n++;
      }
    }
    return n;
  }
}
