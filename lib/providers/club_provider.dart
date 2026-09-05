import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/repositories/mock/mock_data_store.dart';
import '../data/repositories/mock/mock_store_persistence.dart';
import '../di/app_dependencies.dart';
import '../domain/services/app_data_bootstrap_service.dart';
import '../domain/services/group_assignment_service.dart';
import '../models/club_model.dart';
import '../models/member_role.dart';
import '../services/club_data_codec.dart';
import '../services/club_ops_sync.dart';
import '../services/club_persistence.dart';
import '../services/firebase_auth_bridge.dart';
import '../services/hq_alimtalk_catalog.dart';
import '../services/hq_push_catalog.dart';
import '../services/push_notification_service.dart';
import '../services/shared_join_request_store.dart';
import '../services/solapi_service.dart';

// ════════════════════════════════════════════════════════════
//  ClubProvider
// ════════════════════════════════════════════════════════════
class ClubProvider extends ChangeNotifier with WidgetsBindingObserver {
  String? _persistAuthUserId;
  bool _suppressPersist = false;
  bool _applyingCloudOps = false;
  String? _watchingClubId;
  Timer? _persistTimer;
  Timer? _cloudPushTimer;

  ClubProvider() {
    _normalizeScheduleTitles();
    _syncAllNextRounds();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _persistTimer?.cancel();
    _cloudPushTimer?.cancel();
    ClubOpsSync.stopAllWatches();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(HqPushCatalog.load());
    unawaited(HqAlimtalkCatalog.load());
    _syncAllNextRounds();
    notifyListeners();
  }

  static String _monthlyTitle(DateTime date, String name) =>
      '${date.month}월 $name';

  /// 신규 생성 모임 — mock 데이터 미적용
  final Set<String> _freshClubIds = {};

  /// 총무가 인수인계 없이 탈퇴한 모임 (회장/부회장 선임 안내)
  final Set<String> _treasurerVacantClubIds = {};

  /// 계정별 탈퇴한 모임 — 시드 재투입/저장 레이스로 내 모임에 다시 뜨는 것 방지
  final Set<String> _leftClubIds = {};

  bool isFreshClub(String clubId) => _freshClubIds.contains(clubId);
  bool get isSelectedClubFresh => _freshClubIds.contains(selectedClub.id);
  bool isTreasurerVacant(String clubId) =>
      _treasurerVacantClubIds.contains(clubId);
  bool get isSelectedTreasurerVacant =>
      isTreasurerVacant(selectedClub.id);

  void clearTreasurerVacant(String clubId) {
    if (_treasurerVacantClubIds.remove(clubId)) {
      notifyListeners();
      _persistImmediately();
    }
  }

  /// mock 재무/회원/공지/일정 데이터가 있는 기본 데모 모임
  static const _legacyMockClubIds = {'c1', 'c2', 'c3', 'c4', 'c5', 'c6'};

  bool get _selectedHasLegacyMock =>
      _legacyMockClubIds.contains(selectedClub.id) && !isSelectedClubFresh;

  // ── 현재 로그인 유저 — AuthProvider에서 switchUser()로 설정 ──
  // 기본값: m1(홍길동/총무) — 강남 골프회 총무 계정
  String _currentUserId   = 'm1';
  String _currentUserName = '홍길동';

  String get currentUserId   => _currentUserId;
  String get currentUserName => _currentUserName;

  /// mock seed ID ↔ ClubProvider legacy ID
  static const seedToLegacyClubId = {
    'seed_c1': 'c1',
    'seed_c2': 'c2',
    'seed_c3': 'c3',
    'seed_c4': 'c4',
    'seed_c5': 'c5',
    'seed_c6': 'c6',
  };

  static String legacyClubIdFor(String clubId) =>
      seedToLegacyClubId[clubId] ?? clubId;

  static String? legacyClubIdForSeed(String seedId) => seedToLegacyClubId[seedId];

  /// seed_c1 ↔ c1 등 같은 모임의 별칭 집합
  static Set<String> clubIdAliases(String clubId) {
    final legacy = legacyClubIdFor(clubId);
    final aliases = <String>{clubId, legacy};
    for (final e in seedToLegacyClubId.entries) {
      if (e.value == legacy) aliases.add(e.key);
    }
    if (_legacyMockClubIds.contains(legacy)) {
      aliases.add('seed_$legacy');
    }
    return aliases;
  }

  bool _isLeftClub(String clubId) =>
      clubIdAliases(clubId).any(_leftClubIds.contains);

  /// 탈퇴한 모임인지 (seed_c* / c* 별칭 포함)
  bool hasLeftClub(String clubId) => _isLeftClub(clubId);

  void _markClubLeft(String clubId) {
    _leftClubIds.addAll(clubIdAliases(clubId));
  }

  /// Firestore/Mock bootstrap → ClubProvider(legacy mock) 동기화
  ///
  /// 이미 로컬에 있는 모임(테스트·사용자 수정 포함)의 이름/팀수/소개/D-day는
  /// bootstrap으로 덮어쓰지 않는다. 신규 모임만 추가한다.
  void hydrateFromBootstrap(
    AppBootstrapSnapshot snapshot, {
    List<JoinRequest> pendingRequests = const [],
  }) {
    _suppressPersist = true;

    for (final bootClub in snapshot.myClubs) {
      final legacy = _clubFromBootstrap(bootClub);
      // 탈퇴한 모임은 bootstrap이 다시 넣지 못함 (상세 복귀·새로고침 회귀 방지)
      if (_isLeftClub(legacy.id) || _isLeftClub(bootClub.id)) continue;
      final idx = _myClubs.indexWhere((c) => c.id == legacy.id);
      if (idx >= 0) {
        // 로컬 저장 데이터 유지 — myRole만 비어 있을 때 보정
        final existing = _myClubs[idx];
        if (existing.myRole.trim().isEmpty && legacy.myRole.isNotEmpty) {
          _myClubs[idx] = existing.copyWith(myRole: legacy.myRole);
        }
      } else {
        _myClubs.add(legacy);
        if (!_legacyMockClubIds.contains(legacy.id)) {
          _freshClubIds.add(legacy.id);
        }
      }
    }

    _myClubs.removeWhere((c) => _isLeftClub(c.id));

    for (final bootClub in snapshot.discoverableClubs) {
      final legacy = _clubFromBootstrap(bootClub, forCatalog: true);
      final idx = _allClubs.indexWhere((c) => c.id == legacy.id);
      if (idx < 0) {
        _allClubs.add(legacy);
      }
    }

    if (pendingRequests.isNotEmpty) {
      final userId = snapshot.userId;
      _joinRequests.removeWhere(
        (r) =>
            r.userId == userId &&
            (seedToLegacyClubId.containsKey(r.clubId) ||
                r.clubId.startsWith('seed_')),
      );
      for (final req in pendingRequests) {
        if (req.userId != userId) continue;
        final legacyClubId = legacyClubIdFor(req.clubId);
        _joinRequests.add(
          JoinRequest(
            id: req.id,
            clubId: legacyClubId,
            userId: req.userId,
            userName: req.userName,
            userGender: req.userGender,
            userHandicap: req.userHandicap,
            message: req.message,
            status: req.status,
            requestedAt: req.requestedAt,
            reviewedBy: req.reviewedBy,
            reviewedAt: req.reviewedAt,
          ),
        );
      }
    }

    if (_selectedClubIndex >= _myClubs.length) {
      _selectedClubIndex = 0;
    }

    // 일정 기준 D-day로 맞춤 (bootstrap 템플릿 날짜로 덮지 않음)
    _syncAllNextRounds();
    _suppressPersist = false;
    notifyListeners();
    // bootstrap 후 스테이징 ops 동기화
    unawaited(_pullCloudOpsForMyClubs().then((_) => _watchSelectedClubOps()));
  }

  Club _clubFromBootstrap(Club bootClub, {bool forCatalog = false}) {
    final legacyId = legacyClubIdFor(bootClub.id);
    Club? template;
    for (final c in _allClubs) {
      if (c.id == legacyId) {
        template = c;
        break;
      }
    }
    template ??= () {
      for (final c in _myClubs) {
        if (c.id == legacyId) return c;
      }
      return null;
    }();

    if (template != null) {
      return template.copyWith(
        myRole: forCatalog ? template.myRole : bootClub.myRole,
        memberCount: bootClub.memberCount,
        teamCount: bootClub.teamCount,
        description: bootClub.description.isNotEmpty
            ? bootClub.description
            : template.description,
      );
    }

    return Club(
      id: legacyId,
      name: bootClub.name,
      imageUrl: bootClub.imageUrl,
      myRole: forCatalog ? bootClub.myRole : bootClub.myRole,
      memberCount: bootClub.memberCount,
      nextRoundDate: bootClub.nextRoundDate,
      nextRoundCourse: bootClub.nextRoundCourse,
      creatorId: bootClub.creatorId,
      region: bootClub.region,
      industry: bootClub.industry,
      teamCount: bootClub.teamCount,
      description: bootClub.description,
      createdAt: bootClub.createdAt,
    );
  }

  /// AuthProvider 로그인 계정에 따라 ClubProvider 상태 전환 + 저장 데이터 복원
  Future<void> switchUser(String authUserId) async {
    _persistAuthUserId = authUserId;
    await _loadLeftClubIds(authUserId);
    switch (authUserId) {
      case 'user_guest':
        _currentUserId = 'mg1';
        _currentUserName = '이민준';
        // 시드를 먼저 넣지 않음 — 탈퇴 후 저장 로드 전에 c1이 잠깐이라도 끼어들면 안 됨
        _myClubs.clear();
        break;
      case 'user_other':
        _currentUserId = 'm4';
        _currentUserName = '박민준';
        _myClubs.clear();
        break;
      case 'user_me':
      default:
        _currentUserId = 'm1';
        _currentUserName = '홍길동';
        _myClubs.clear();
        break;
    }
    _selectedClubIndex = 0;

    final saved = await ClubPersistence.load(authUserId);
    if (saved != null) {
      _suppressPersist = true;
      _importBundle(saved);
      _suppressPersist = false;
    } else {
      // 시드 계정만 템플릿. 카카오/구글/애플 계정은 빈 내 모임에서 시작.
      if (authUserId == 'user_guest') {
        _myClubs.addAll(_guestClubs);
      } else if (authUserId == 'user_other') {
        _myClubs.addAll(_otherMemberClubs);
      } else if (authUserId == 'user_me' || authUserId == 'default') {
        _myClubs.addAll(_adminClubs);
      }
      _syncAccountClubRoles(authUserId);
      _syncAllNextRounds();
      _normalizeScheduleTitles();
    }

    // 탈퇴한 모임은 절대 내 모임에 다시 넣지 않음
    _myClubs.removeWhere((c) => _isLeftClub(c.id));

    if (authUserId == 'user_guest') {
      final self = _members.where((m) => m.id == 'mg1').firstOrNull;
      final leftGangnam = _isLeftClub('c1') || self?.status == '탈퇴';
      if (!leftGangnam) {
        for (final seed in _guestClubs) {
          if (!_myClubs.any((c) => c.id == seed.id) && !_isLeftClub(seed.id)) {
            _myClubs.add(seed);
          }
        }
      } else {
        _myClubs.removeWhere((c) => clubIdAliases('c1').contains(c.id));
        _markClubLeft('c1');
        if (self != null && self.status != '탈퇴') {
          final i = _members.indexWhere((m) => m.id == 'mg1');
          if (i >= 0) {
            _members[i] = _members[i].copyWith(status: '탈퇴');
          }
        }
      }
      if (self == null) {
        _members.add(Member(
          id: 'mg1',
          name: '이민준',
          gender: '남',
          birthDate: DateTime(1991, 9, 20),
          memberType: '정회원',
          role: '일반',
          phone: '010-9999-0000',
          bio: '강남 골프회 회원입니다. 핸디 18로 꾸준히 실력 향상 중입니다.',
          handicap: 18.0,
          joinDate: DateTime(2022, 7, 1),
          address: '서울시 강남구 논현동',
          status: leftGangnam ? '탈퇴' : '활성',
        ));
      }
      if (_selectedClubIndex >= _myClubs.length) {
        _selectedClubIndex = 0;
      }
      await _saveLeftClubIds(authUserId);
    } else if (authUserId == 'user_other' && saved == null) {
      _myClubs
        ..clear()
        ..addAll(_otherMemberClubs);
    } else if ((authUserId == 'user_me' || authUserId == 'default') &&
        saved == null) {
      // already filled from templates above
    }

    // 저장소/리포에 남은 '내가 만든 모임' 복구 (시드 정리·포트 전환으로 myClubs에서 빠진 경우)
    final recovered = await _restoreOwnedClubsFromStores(authUserId);
    // 복구 후에도 탈퇴 목록은 제외
    _myClubs.removeWhere((c) => _isLeftClub(c.id));
    if (recovered) {
      await _persistNow();
    }

    // 항상 실제 일정 기준으로 D-day 재동기화
    _syncAllNextRounds();
    // 신규 모임에 생성자 회원이 누락된 경우 복구 (회비·회원 목록)
    ensureCreatorMembers();
    // 데모 모임(c1~c5) 회원수 — 과거에 저장된 임의값이 남아있어도 실제 명단 기준으로 교정
    _reconcileLegacyMemberCounts();
    // 내 모임 → Mock 저장소(어드민·모임찾기) 강제 동기화
    _syncMyClubsToMockStore();

    // 다른 계정에서 신청한 가입 요청·알림을 공유 스토어에서 병합
    await mergeSharedJoinRequests();
    await refreshJoinRequestInbox();
    _purgeDemoSeedNotifications();
    await HqPushCatalog.load();
    unawaited(PushNotificationService.bindUserIds([authUserId, _currentUserId]));

    // rounder-staging 운영 데이터 pull (테스터끼리 공유)
    await _pullCloudOpsForMyClubs();
    _watchSelectedClubOps();
    notifyListeners();
  }

  Future<void> _pullCloudOpsForMyClubs() async {
    final authUserId = _persistAuthUserId;
    if (authUserId == null) return;
    if (!AppDependencies.instance.isInitialized ||
        AppDependencies.instance.isOfflineMockMode) {
      return;
    }
    _applyingCloudOps = true;
    _suppressPersist = true;
    try {
      var bundle = _exportBundle();
      final userMerged = await ClubOpsSync.pullMergeUser(
        authUserId: authUserId,
        local: bundle,
      );
      if (userMerged != null) bundle = userMerged;

      for (final club in List<Club>.from(_myClubs)) {
        final merged = await ClubOpsSync.pullMergeClub(
          clubId: club.id,
          local: bundle,
        );
        if (merged != null) bundle = merged;
      }
      _importBundle(bundle);
      _scrubUndersizedScheduleCapacities();
      _syncAllNextRounds();
    } catch (e) {
      debugPrint('[ClubProvider] cloud pull fail: $e');
    } finally {
      _suppressPersist = false;
      _applyingCloudOps = false;
      // 로컬만 있던 데이터를 서버에 최초 반영
      unawaited(_persistNow());
    }
  }

  void _watchSelectedClubOps() {
    if (_myClubs.isEmpty) return;
    if (!AppDependencies.instance.isInitialized ||
        AppDependencies.instance.isOfflineMockMode) {
      return;
    }
    final clubId = selectedClub.id;
    if (_watchingClubId == clubId) return;
    if (_watchingClubId != null) {
      ClubOpsSync.stopWatchClub(_watchingClubId!);
    }
    _watchingClubId = clubId;
    ClubOpsSync.watchClub(clubId, (remote) {
      if (_applyingCloudOps) return;
      _applyingCloudOps = true;
      _suppressPersist = true;
      final beforeSig = _galleryWatchSignature();
      try {
        final merged = ClubOpsSync.applyRemoteSlice(
          _exportBundle(),
          clubId,
          remote,
        );
        _importBundle(merged);
        _syncNextRound(clubId);
      } catch (e) {
        debugPrint('[ClubProvider] cloud watch apply fail: $e');
      } finally {
        _suppressPersist = false;
        _applyingCloudOps = false;
        // 사진·일정 등 갤러리 관련 내용이 같으면 통지 생략 → 깜빡임 감소
        if (beforeSig != _galleryWatchSignature()) {
          notifyListeners();
        }
      }
    });
  }

  String _galleryWatchSignature() {
    final photoPart = _photos
        .map((p) => '${p.id}:${p.imageUrl.length}:${p.caption ?? ''}')
        .join(',');
    // status 포함 — 다른 기기에서 일정을 취소하면 갤러리 앨범이 빠져야 한다.
    final schedPart = _schedules
        .map((s) => '${s.id}:${s.responses.length}:${s.title}:${s.status.name}')
        .join(',');
    final duesPart = _duesPayments.map((p) => p.id).join(',');
    final waitPart = _waitingList.map((w) => '${w.scheduleId}:${w.memberId}').join(',');
    final memberPart =
        _members.map((m) => '${m.id}:${m.name}:${m.status}').join(',');
    return '$photoPart|$schedPart|$duesPart|$waitPart|${_announcements.length}|$memberPart';
  }

  static String _leftClubsPrefsKey(String authUserId) =>
      'rounder_left_clubs_v2_$authUserId';

  Future<void> _loadLeftClubIds(String authUserId) async {
    _leftClubIds.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      try {
        await prefs.reload();
      } catch (_) {}
      final list = prefs.getStringList(_leftClubsPrefsKey(authUserId));
      if (list != null) {
        for (final id in list) {
          _leftClubIds.addAll(clubIdAliases(id));
        }
      }
    } catch (e) {
      debugPrint('[ClubProvider] load left clubs skip: $e');
    }
  }

  Future<void> _saveLeftClubIds(String authUserId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _leftClubsPrefsKey(authUserId),
        _leftClubIds.toList(),
      );
    } catch (e) {
      debugPrint('[ClubProvider] save left clubs skip: $e');
    }
  }

  Future<void> _clearLeftClubForApplicant(
    String applicantUserId,
    String clubId,
  ) async {
    final authIds = <String>{
      applicantUserId,
      if (applicantUserId == 'mg1' || applicantUserId == 'user_guest') ...[
        'user_guest',
        'mg1',
      ],
      if (applicantUserId == 'm1' || applicantUserId == 'user_me') ...[
        'user_me',
        'm1',
      ],
    };
    for (final authId in authIds) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final key = _leftClubsPrefsKey(authId);
        final list = prefs.getStringList(key) ?? <String>[];
        final before = list.length;
        list.removeWhere((id) => clubIdAliases(clubId).contains(id));
        if (list.length != before) {
          await prefs.setStringList(key, list);
        }
        // 신청자 번들에 모임 복구
        final legacyClubId = legacyClubIdFor(clubId);
        final bundle = await ClubPersistence.load(authId);
        if (bundle != null &&
            !bundle.myClubs.any(
                (c) => clubIdAliases(legacyClubId).contains(c.id))) {
          final club =
              _allClubs.where((c) => c.id == legacyClubId).firstOrNull ??
                  _myClubs.where((c) => c.id == legacyClubId).firstOrNull;
          if (club != null) {
            final myClubs = List<Club>.from(bundle.myClubs)
              ..add(club.copyWith(myRole: '정회원'));
            await ClubPersistence.save(
              authId,
              ClubDataBundle(
                selectedClubIndex: bundle.selectedClubIndex,
                freshClubIds: Set<String>.from(bundle.freshClubIds),
                myClubs: myClubs,
                allClubs: List<Club>.from(bundle.allClubs),
                joinRequests: List<JoinRequest>.from(bundle.joinRequests),
                members: List<Member>.from(bundle.members),
                activities: List<ActivityItem>.from(bundle.activities),
                announcements: List<Announcement>.from(bundle.announcements),
                appNotifications:
                    List<AppNotification>.from(bundle.appNotifications),
                duesSettings: List<DuesSetting>.from(bundle.duesSettings),
                duesPayments: List<DuesPayment>.from(bundle.duesPayments),
                paymentRequests:
                    List<PaymentRequest>.from(bundle.paymentRequests),
                transactions: List<Transaction>.from(bundle.transactions),
                schedules: List<RoundSchedule>.from(bundle.schedules),
                photos: List<RoundPhoto>.from(bundle.photos),
                groupAssignments: Map<String, GroupAssignment>.from(
                    bundle.groupAssignments),
                adApplications: List<AdApplication>.from(bundle.adApplications),
                adNotifications:
                    List<AdNotification>.from(bundle.adNotifications),
                sponsorApplications:
                    List<SponsorApplication>.from(bundle.sponsorApplications),
                pointEvents: bundle.pointEvents.map(
                  (k, v) => MapEntry(k, List<MembershipPointEvent>.from(v)),
                ),
                awardRecords: List<AwardRecord>.from(bundle.awardRecords),
                thankYouMessages:
                    List<ThankYouMessage>.from(bundle.thankYouMessages),
                waitingList: List<WaitingEntry>.from(bundle.waitingList),
                alimtalkSettings: Map<String, ClubAlimtalkSettings>.from(
                    bundle.alimtalkSettings),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('[ClubProvider] clear left for $authId skip: $e');
      }
    }
    if (_persistAuthUserId != null &&
        authIds.contains(_persistAuthUserId)) {
      _leftClubIds.removeWhere((id) => clubIdAliases(clubId).contains(id));
    }
  }

  String? get persistAuthUserId => _persistAuthUserId;

  /// 로그인/당겨서 새로고침 — 어드민에만 남은 내 생성 모임 재병합
  Future<void> refreshOwnedClubs() async {
    final authId = _persistAuthUserId;
    if (authId == null) return;
    final recovered = await _restoreOwnedClubsFromStores(authId);
    // 복구 성공 여부와 관계없이 동기화·저장 (멤버십 별칭 보정 포함)
    _syncMyClubsToMockStore();
    if (recovered) _persistImmediately();
    notifyListeners();
  }

  Set<String> _authAliases(String authUserId) => {
        authUserId,
        currentUserId,
        if (authUserId == 'user_guest' || currentUserId == 'mg1') ...[
          'user_guest',
          'mg1',
        ],
        if (authUserId == 'user_me' || currentUserId == 'm1') ...[
          'user_me',
          'm1',
        ],
      };

  bool _isStoreClubOwnedByMe(
    MockDataStore store,
    Club c,
    Set<String> aliases,
  ) {
    if (aliases.contains(c.creatorId)) return true;
    if (aliases.any((id) => store.isMember(c.id, id))) return true;

    // 어드민 host 판정과 동일: 내 이름이 회원/생성자로 있으면 내 모임
    for (final m in store.membersOf(c.id)) {
      if (m.name == currentUserName) return true;
      if (aliases.contains(m.id)) return true;
    }
    return false;
  }

  /// MockStore / Prefs / 리포에서 내가 만든·총무인 모임 복구.
  /// 어드민에만 보이는 c_* 모임이 내 모임에서 빠지는 치명 버그 방지.
  Future<bool> _restoreOwnedClubsFromStores(String authUserId) async {
    var changed = false;
    final aliases = _authAliases(authUserId);

    // 1) Mock 공유 저장소 (+ prefs 보강)
    final store = AppDependencies.instance.mockDataStore;
    if (store != null) {
      try {
        await store.hydrateFromDisk();
      } catch (_) {}
      try {
        await _forceScanPrefsIntoStore(store);
      } catch (e) {
        debugPrint('[ClubProvider] prefs→store scan skip: $e');
      }
      for (final c in List<Club>.from(store.clubs)) {
        if (!c.id.startsWith('c_')) continue;
        if (_isLeftClub(c.id)) continue;
        if (!_isStoreClubOwnedByMe(store, c, aliases)) continue;
        if (_ingestOwnedClub(c, store.membersOf(c.id))) changed = true;
        _ensureStoreMembershipAliases(store, c, aliases);
      }
      if (changed) {
        unawaited(MockStorePersistence.save(store));
      }
    }

    // 2) 계정 번들 — user_guest 의 c_* 는 전부 내 모임으로 복구
    for (final uid in <String>{
      authUserId,
      'user_guest',
      'user_me',
      'user_other',
    }) {
      try {
        final bundle = await ClubPersistence.load(uid);
        if (bundle == null) continue;
        for (final c in [...bundle.myClubs, ...bundle.allClubs]) {
          if (!c.id.startsWith('c_')) continue;
          final mine = aliases.contains(c.creatorId) ||
              (uid == authUserId &&
                  ClubMemberRole.isOfficer(c.myRole)) ||
              (authUserId == 'user_guest' && uid == 'user_guest');
          if (!mine) continue;
          final related = bundle.members
              .where((m) =>
                  m.id == 'm_creator_${c.id}' ||
                  m.id.startsWith('m_${c.id}_') ||
                  m.name == currentUserName)
              .toList();
          if (_ingestOwnedClub(c, related)) changed = true;
        }
      } catch (e) {
        debugPrint('[ClubProvider] restore bundle $uid skip: $e');
      }
    }

    // 3) Prefs 전수 스캔
    try {
      if (await _restoreOwnedClubsFromRawPrefs(aliases, authUserId)) {
        changed = true;
      }
    } catch (e) {
      debugPrint('[ClubProvider] raw prefs restore skip: $e');
    }

    // 4) 리포 fetchMyClubs + discoverable(creatorId)
    for (final uid in aliases) {
      try {
        final remote =
            await AppDependencies.instance.clubRepository.fetchMyClubs(uid);
        for (final c in remote) {
          if (_legacyMockClubIds.contains(c.id)) continue;
          if (c.id.startsWith('seed_')) continue;
          if (_ingestOwnedClub(c, const [])) changed = true;
        }
      } catch (e) {
        debugPrint('[ClubProvider] restore fetchMyClubs($uid) skip: $e');
      }
    }
    try {
      final discoverable = await AppDependencies.instance.clubRepository
          .fetchDiscoverableClubs();
      for (final c in discoverable) {
        if (!c.id.startsWith('c_')) continue;
        if (c.creatorId.isEmpty || !aliases.contains(c.creatorId)) continue;
        if (_ingestOwnedClub(c, const [])) changed = true;
      }
    } catch (e) {
      debugPrint('[ClubProvider] restore discoverable skip: $e');
    }

    if (changed) {
      final names = _myClubs
          .where((c) => c.id.startsWith('c_'))
          .map((c) => c.name)
          .toList();
      debugPrint('[ClubProvider] restored owned clubs → $names');
    }
    return changed;
  }

  void _ensureStoreMembershipAliases(
    MockDataStore store,
    Club c,
    Set<String> aliases,
  ) {
    final creator = store.membersByClub[c.id]?['m_creator_${c.id}'] ??
        store
            .membersOf(c.id)
            .where((m) => m.name == currentUserName)
            .firstOrNull;
    if (creator == null) return;
    store.addMember(
      clubId: c.id,
      member: creator,
      bumpCount: false,
      alsoAsIds: aliases.toList(),
      persist: false,
    );
  }

  Future<void> _forceScanPrefsIntoStore(MockDataStore store) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.reload();
    } catch (_) {}
    for (final key in prefs.getKeys()) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty || !raw.contains('"c_')) continue;
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
            final existing = store.clubById(id);
            final scannedCreator = m['creatorId'] as String? ?? '';
            store.upsertClub(
              Club(
                id: id,
                name: m['name'] as String? ?? existing?.name ?? '모임',
                myRole: m['myRole'] as String? ?? existing?.myRole ?? '총무',
                memberCount:
                    m['memberCount'] as int? ?? existing?.memberCount ?? 1,
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
              ),
              moderationStatus: m['moderationStatus'] as String? ??
                  store.clubModerationStatusOrNull(id) ??
                  'active',
              persist: false,
            );
          }
        }
      } catch (_) {}
    }
  }

  Future<bool> _restoreOwnedClubsFromRawPrefs(
    Set<String> aliases,
    String authUserId,
  ) async {
    var changed = false;
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.reload();
    } catch (_) {}
    for (final key in prefs.getKeys()) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty || !raw.contains('"c_')) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final map = Map<String, dynamic>.from(decoded);
        final authInKey = map['authUserId'] as String?;
        for (final listKey in ['myClubs', 'allClubs', 'clubs']) {
          final list = map[listKey];
          if (list is! List) continue;
          for (final item in list) {
            if (item is! Map) continue;
            final m = Map<String, dynamic>.from(item);
            final id = m['id'] as String? ?? '';
            if (!id.startsWith('c_')) continue;
            final creatorId = m['creatorId'] as String? ?? '';
            final myRole = m['myRole'] as String? ?? '';
            final name = m['name'] as String? ?? '';
            final membersJson = m['members'];
            var memberNameHit = false;
            if (membersJson is List) {
              for (final mem in membersJson) {
                if (mem is! Map) continue;
                final memName = mem['name'] as String? ?? '';
                final memId = mem['id'] as String? ?? '';
                if (memName == currentUserName || aliases.contains(memId)) {
                  memberNameHit = true;
                  break;
                }
              }
            }
            final mine = aliases.contains(creatorId) ||
                memberNameHit ||
                (authInKey != null && aliases.contains(authInKey)) ||
                (authUserId == 'user_guest' &&
                    (key.contains('user_guest') ||
                        authInKey == 'user_guest')) ||
                (creatorId.isEmpty &&
                    ClubMemberRole.isOfficer(myRole) &&
                    aliases.contains(authUserId));
            if (!mine) continue;
            final club = Club(
              id: id,
              name: name.isEmpty ? '모임' : name,
              myRole: myRole.isEmpty ? '총무' : myRole,
              memberCount: m['memberCount'] as int? ?? 1,
              creatorId: creatorId.isNotEmpty ? creatorId : authUserId,
              region: m['region'] as String? ?? '',
              industry: m['industry'] as String? ?? '',
              teamCount: m['teamCount'] as int? ?? 4,
              description: m['description'] as String? ?? '',
              createdAt: m['createdAt'] != null
                  ? DateTime.tryParse(m['createdAt'] as String) ?? DateTime.now()
                  : DateTime.now(),
            );
            if (_ingestOwnedClub(club, const [])) changed = true;
          }
        }
      } catch (_) {}
    }
    return changed;
  }

  bool _ingestOwnedClub(Club club, List<Member> storeMembers) {
    var changed = false;
    if (!_myClubs.any((c) => c.id == club.id)) {
      final role = club.myRole.trim().isEmpty ? '회장' : club.myRole;
      _myClubs.add(club.copyWith(myRole: role));
      changed = true;
    }
    if (!_allClubs.any((c) => c.id == club.id)) {
      _allClubs.add(club);
      changed = true;
    }
    if (!_legacyMockClubIds.contains(club.id)) {
      _freshClubIds.add(club.id);
    }
    for (final m in storeMembers) {
      if (!_members.any((x) => x.id == m.id)) {
        _members.add(m);
        changed = true;
      }
    }
    // 생성자 멤버 최소 보장
    final creatorId = 'm_creator_${club.id}';
    if (!_members.any((m) => m.id == creatorId) &&
        club.id.startsWith('c_')) {
      _members.add(Member(
        id: creatorId,
        name: currentUserName,
        gender: '남',
        memberType: '정회원',
        role: ClubMemberRole.normalize(
          club.myRole.trim().isEmpty ? '회장' : club.myRole,
        ),
        handicap: null,
        joinDate: club.createdAt,
        status: '활성',
      ));
      changed = true;
    }
    return changed;
  }

  /// 데모용 가짜 알림 제거 — 실제 액션으로 생긴 알림만 남김
  void _purgeDemoSeedNotifications() {
    const seedIds = {
      'noti0', // 입금 확인 요청 시드
      'noti1', 'noti3', 'noti_jr3', // 가입 신청 시드
      'noti2', 'noti4', 'noti5', // 공지 시드
    };
    _appNotifications.removeWhere((n) => seedIds.contains(n.id));
    final seenTargets = <String>{};
    _appNotifications.removeWhere((n) {
      if (n.type != AppNotificationType.joinRequest) return false;
      final tid = n.targetId;
      if (tid == null || tid.isEmpty) return false;
      if (!seenTargets.add(tid)) return true;
      return false;
    });
  }

  @Deprecated('Use _purgeDemoSeedNotifications')
  void _purgeLegacySeedJoinNotifications() => _purgeDemoSeedNotifications();

  /// 공유 대기열(localStorage + MockDataStore)의 가입 신청을 현재 계정에 병합.
  /// 로그인/계정 전환 직후 호출해 총무 알림 유실을 막는다.
  Future<void> mergeSharedJoinRequests() async {
    final shared = await SharedJoinRequestStore.loadAll();
    final mem = SharedJoinRequestStore.peekMemory();
    final store = AppDependencies.instance.mockDataStore;
    final fromStore = store == null
        ? const <JoinRequest>[]
        : List<JoinRequest>.from(store.pendingJoinRequests);

    if (store != null) {
      for (final req in [...shared, ...mem]) {
        store.upsertPendingJoinRequest(req, persist: false);
      }
      if (shared.isNotEmpty || mem.isNotEmpty) {
        unawaited(MockStorePersistence.save(store));
      }
    }

    final seen = <String>{};
    for (final req in [...mem, ...shared, ...fromStore]) {
      if (req.status != JoinRequestStatus.pending) continue;
      if (!seen.add(req.id)) continue;
      _ingestPendingJoinRequest(req);
    }
  }

  void _ingestPendingJoinRequest(JoinRequest req) {
    final clubId = _normalizeLegacyClubId(req.clubId);
    final normalized = clubId == req.clubId
        ? req
        : JoinRequest(
            id: req.id,
            clubId: clubId,
            userId: req.userId,
            userName: req.userName,
            userGender: req.userGender,
            userHandicap: req.userHandicap,
            message: req.message,
            referrerId: req.referrerId,
            referrerName: req.referrerName,
            status: req.status,
            requestedAt: req.requestedAt,
            reviewedBy: req.reviewedBy,
            reviewedAt: req.reviewedAt,
          );

    final exists = _joinRequests.any(
      (r) =>
          r.id == normalized.id ||
          (r.clubId == normalized.clubId &&
              r.userId == normalized.userId &&
              r.status == JoinRequestStatus.pending),
    );
    if (!exists) {
      _joinRequests.add(normalized);
    }

    final notiId = 'noti_jr_${normalized.id}';
    // 동일 신청(targetId) 알림이 시드/구버전으로 있으면 중복 생성 금지
    if (_appNotifications.any((n) =>
        n.id == notiId ||
        (n.type == AppNotificationType.joinRequest &&
            n.targetId == normalized.id))) {
      return;
    }
    // 하드코딩 시드 신청(jr1~jr3)은 승인 UI용 — 알림함에는 올리지 않음
    if (normalized.id == 'jr1' ||
        normalized.id == 'jr2' ||
        normalized.id == 'jr3') {
      return;
    }

    final inMyClubs = _myClubs.any((c) => c.id == clubId);
    if (!inMyClubs) return;

    final club = _allClubs.where((c) => c.id == clubId).firstOrNull ??
        _myClubs.where((c) => c.id == clubId).firstOrNull;
    final notifyTarget = joinRequestNotifyTargetId(clubId);
    final notifyRole = hasActiveTreasurer(clubId)
        ? ClubMemberRole.treasurer
        : ClubMemberRole.president;
    addAppNotification(
      AppNotification(
        id: notiId,
        type: AppNotificationType.joinRequest,
        clubId: clubId,
        clubName: club?.name ?? '모임',
        isAdmin: true,
        title: '가입 신청',
        body: '${normalized.userName}님이 가입을 신청했습니다 → $notifyRole 수신',
        createdAt: normalized.requestedAt,
        targetId: normalized.id,
        targetUserId: notifyTarget ?? currentUserId,
        isRead: false,
      ),
      hqPushTypeId: HqPushCatalog.joinRequest,
      notifySelf: true,
    );
  }

  String _normalizeLegacyClubId(String clubId) {
    if (clubId.startsWith('seed_')) {
      final bare = clubId.substring(5);
      if (_legacyMockClubIds.contains(bare)) return bare;
    }
    return clubId;
  }

  bool _userIdsMatch(String? a, String? b) {
    if (a == null || b == null) return false;
    if (a == b) return true;
    const pairs = [
      {'m1', 'user_me'},
      {'mg1', 'user_guest'},
      {'m4', 'user_other'},
    ];
    for (final g in pairs) {
      if (g.contains(a) && g.contains(b)) return true;
    }
    final me = <String>{
      currentUserId,
      if (_persistAuthUserId != null) _persistAuthUserId!,
    };
    return me.contains(a) && me.contains(b);
  }

  /// 명단 ID(m_creator_*, m_{clubId}_*)와 로그인 계정을 같은 사람으로 본다.
  bool _isSelfTarget(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    if (_userIdsMatch(id, currentUserId) ||
        _userIdsMatch(id, _persistAuthUserId)) {
      return true;
    }
    final me = currentMember?.id;
    if (me != null && (id == me || _userIdsMatch(id, me))) return true;

    if (_myClubs.isEmpty) return false;
    final clubId = selectedClub.id;
    if (id == 'm_creator_$clubId') {
      final cid = selectedClub.creatorId;
      return cid.isEmpty ||
          _userIdsMatch(cid, currentUserId) ||
          _userIdsMatch(cid, _persistAuthUserId);
    }
    final prefix = 'm_${clubId}_';
    if (id.startsWith(prefix)) {
      final suffix = id.substring(prefix.length);
      return _userIdsMatch(suffix, currentUserId) ||
          _userIdsMatch(suffix, _persistAuthUserId);
    }
    return false;
  }

  /// FCM·푸시함은 Firebase 로그인 ID를 쓴다. 명단 ID를 그 키로 바꾼다.
  String _fcmInboxIdFor(String memberOrUserId) {
    final raw = memberOrUserId.trim();
    if (raw.isEmpty) return raw;
    if (_isSelfTarget(raw)) {
      final auth = _persistAuthUserId?.trim();
      if (auth != null && auth.isNotEmpty) return auth;
      if (currentUserId.trim().isNotEmpty) return currentUserId;
    }
    if (_myClubs.isNotEmpty) {
      final clubId = selectedClub.id;
      final prefix = 'm_${clubId}_';
      if (raw.startsWith(prefix)) {
        final suffix = raw.substring(prefix.length);
        if (suffix.isNotEmpty) return suffix;
      }
      if (raw == 'm_creator_$clubId') {
        final cid = selectedClub.creatorId.trim();
        if (cid.isNotEmpty) return cid;
      }
    }
    if (raw.startsWith('m_creator_')) {
      final club = [..._myClubs, ..._allClubs]
          .where((c) => raw == 'm_creator_${c.id}')
          .firstOrNull;
      if (club != null && club.creatorId.trim().isNotEmpty) {
        return club.creatorId.trim();
      }
    }
    return raw;
  }

  /// 레거시 데모 모임(c1~c5)은 모두 같은 공유 명단을 쓰므로 회원수도 동일해야 함.
  /// localStorage에 예전 임의값(24, 15, 8 등)이 저장돼 있어도 항상 실제 값으로 교정.
  void _reconcileLegacyMemberCounts() {
    final regularCount = _members
        .where((m) => m.status == '활성' && m.memberType != '게스트')
        .length;
    for (var i = 0; i < _myClubs.length; i++) {
      final c = _myClubs[i];
      if (_legacyMockClubIds.contains(c.id) && c.memberCount != regularCount) {
        _myClubs[i] = c.copyWith(memberCount: regularCount);
      }
    }
    for (var i = 0; i < _allClubs.length; i++) {
      final c = _allClubs[i];
      if (_legacyMockClubIds.contains(c.id) && c.memberCount != regularCount) {
        _allClubs[i] = c.copyWith(memberCount: regularCount);
      }
    }
  }

  /// ClubProvider → MockDataStore (템플릿 c1~c10 + 사용자 c_*)
  void _syncMyClubsToMockStore() {
    final store = AppDependencies.instance.mockDataStore;
    if (store == null) return;
    final seen = <String>{};
    for (final c in [..._myClubs, ..._allClubs]) {
      if (!seen.add(c.id)) continue;
      if (c.id.startsWith('seed_')) continue;
      final isUser = c.id.startsWith('c_') || _freshClubIds.contains(c.id);
      final isTemplate = RegExp(r'^c\d+$').hasMatch(c.id);
      if (!isUser && !isTemplate) continue;

      // 데모 템플릿(c1~c6)은 seed_cN이 이미 store의 원본 행이므로
      // 별도 행을 만들지 않고, 회원만 seed_cN 쪽으로 합쳐서 동기화한다.
      // (그렇지 않으면 c1/seed_c1처럼 같은 모임이 두 줄로 중복 표시됨)
      final hasSeedCounterpart = _legacyMockClubIds.contains(c.id);
      final resolvedTargetId = hasSeedCounterpart ? 'seed_${c.id}' : c.id;

      if (!hasSeedCounterpart) {
        final status = store.clubModerationStatusOrNull(c.id) ??
            'active';
        store.upsertClub(c, moderationStatus: status, persist: false);
      }
      for (final m in membersForClub(c.id)) {
        // 탈퇴 회원은 저장소에 다시 올리지 않음 (탈퇴 직후 sync가 멤버십을 복구하던 버그)
        if (m.status != '활성') continue;
        if (_isLeftClub(c.id) &&
            (m.id == currentUserId ||
                m.id == _persistAuthUserId ||
                m.id == 'mg1' ||
                m.id == 'user_guest' ||
                m.id == 'm1' ||
                m.id == 'user_me')) {
          continue;
        }
        // alsoAsIds는 본인/생성자 레코드에만 — 게스트에 user_me를 붙이지 않음
        final isSelf = m.id == currentUserId ||
            m.id == _persistAuthUserId ||
            m.id == 'm_creator_${c.id}';
        final selfAliases = <String>{
          if (_persistAuthUserId != null) _persistAuthUserId!,
          currentUserId,
          if (_persistAuthUserId == 'user_guest' || currentUserId == 'mg1') ...[
            'user_guest',
            'mg1',
          ],
          if (_persistAuthUserId == 'user_me' || currentUserId == 'm1') ...[
            'user_me',
            'm1',
          ],
        };
        store.addMember(
          clubId: resolvedTargetId,
          member: m,
          bumpCount: false,
          alsoAsIds: isSelf ? selfAliases.toList() : const [],
          persist: false,
        );
      }
    }
    final authKey = _persistAuthUserId ?? 'user_me';
    store.setMemberClubCountOverride(authKey, _myClubs.length);
    if (authKey == 'user_me' || authKey == 'm1') {
      store.setMemberClubCountOverride('user_me', _myClubs.length);
      store.setMemberClubCountOverride('m1', _myClubs.length);
    }
    if (authKey == 'user_guest' || authKey == 'mg1') {
      store.setMemberClubCountOverride('user_guest', _myClubs.length);
      store.setMemberClubCountOverride('mg1', _myClubs.length);
    }
    unawaited(MockStorePersistence.save(store));
    store.bump(persist: false);
  }

  /// 최초 로그인(저장 없음)일 때만 템플릿 myRole 적용.
  /// nextRoundDate는 일정(_schedules)에서만 계산한다.
  void _syncAccountClubRoles(String authUserId) {
    final templates = switch (authUserId) {
      'user_guest' => _guestClubs,
      'user_other' => _otherMemberClubs,
      'user_me' => _adminClubs,
      _ => _adminClubs,
    };
    for (var i = 0; i < _myClubs.length; i++) {
      for (final t in templates) {
        if (t.id == _myClubs[i].id) {
          _myClubs[i] = _myClubs[i].copyWith(myRole: t.myRole);
          break;
        }
      }
    }
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (!_suppressPersist && _persistAuthUserId != null) {
      _persistTimer?.cancel();
      _persistTimer = Timer(const Duration(milliseconds: 500), () {
        _persistNow();
      });
    }
  }

  Future<void> _persistNow() async {
    final authUserId = _persistAuthUserId;
    if (authUserId == null) return;
    _stampOrphanDuesClubIds();
    _stampOrphanTransactionClubIds();
    final bundle = _exportBundle();
    await ClubPersistence.save(authUserId, bundle);
    if (_applyingCloudOps) return;
    // 디바운스 푸시 — 연속 저장 시 Firestore 폭주 방지
    _cloudPushTimer?.cancel();
    _cloudPushTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(ClubOpsSync.pushAllRelevant(
        bundle,
        authUserId: authUserId,
      ));
    });
  }

  /// 디바운스 없이 즉시 저장 (일정 등록 등)
  void _persistImmediately() {
    _persistTimer?.cancel();
    _persistTimer = null;
    if (!_suppressPersist && _persistAuthUserId != null) {
      _persistNow();
    }
  }

  ClubDataBundle _exportBundle() => ClubDataBundle(
        selectedClubIndex: _selectedClubIndex,
        freshClubIds: Set<String>.from(_freshClubIds),
        myClubs: List<Club>.from(_myClubs),
        allClubs: List<Club>.from(_allClubs),
        joinRequests: List<JoinRequest>.from(_joinRequests),
        members: List<Member>.from(_members),
        activities: List<ActivityItem>.from(_activities),
        announcements: List<Announcement>.from(_announcements),
        appNotifications: List<AppNotification>.from(_appNotifications),
        duesSettings: List<DuesSetting>.from(_duesSettings),
        duesPayments: List<DuesPayment>.from(_duesPayments),
        paymentRequests: List<PaymentRequest>.from(_paymentRequests),
        transactions: List<Transaction>.from(_transactions),
        schedules: List<RoundSchedule>.from(_schedules),
        photos: List<RoundPhoto>.from(_photos),
        groupAssignments: Map<String, GroupAssignment>.from(_groupAssignments),
        adApplications: List<AdApplication>.from(_adApplications),
        adNotifications: List<AdNotification>.from(_adNotifications),
        sponsorApplications: List<SponsorApplication>.from(_sponsorApplications),
        pointEvents: _pointEvents.map(
          (k, v) => MapEntry(k, List<MembershipPointEvent>.from(v)),
        ),
        awardRecords: List<AwardRecord>.from(_awardRecords),
        thankYouMessages: List<ThankYouMessage>.from(_thankYouMessages),
        waitingList: List<WaitingEntry>.from(_waitingList),
        alimtalkSettings: Map<String, ClubAlimtalkSettings>.from(_alimtalkSettings),
      );

  void _importBundle(ClubDataBundle b) {
    _selectedClubIndex = b.selectedClubIndex;
    _freshClubIds
      ..clear()
      ..addAll(b.freshClubIds);
    _myClubs
      ..clear()
      ..addAll(b.myClubs);
    _allClubs
      ..clear()
      ..addAll(b.allClubs);
    _joinRequests
      ..clear()
      ..addAll(b.joinRequests);
    _members
      ..clear()
      ..addAll(b.members);
    _activities
      ..clear()
      ..addAll(b.activities);
    _announcements
      ..clear()
      ..addAll(b.announcements);
    _appNotifications
      ..clear()
      ..addAll(b.appNotifications);
    _duesSettings
      ..clear()
      ..addAll(b.duesSettings);
    _duesPayments
      ..clear()
      ..addAll(b.duesPayments);
    _paymentRequests
      ..clear()
      ..addAll(b.paymentRequests);
    _transactions
      ..clear()
      ..addAll(b.transactions);
    _schedules
      ..clear()
      ..addAll(b.schedules);
    _scrubUndersizedScheduleCapacities();
    _normalizeStaleDuesSeed();
    _stampOrphanDuesClubIds();
    _photos
      ..clear()
      ..addAll(b.photos);
    _groupAssignments
      ..clear()
      ..addAll(b.groupAssignments);
    _adApplications
      ..clear()
      ..addAll(b.adApplications);
    _adNotifications
      ..clear()
      ..addAll(b.adNotifications);
    _sponsorApplications
      ..clear()
      ..addAll(b.sponsorApplications);
    _pointEvents
      ..clear()
      ..addAll(b.pointEvents);
    _awardRecords
      ..clear()
      ..addAll(b.awardRecords);
    _thankYouMessages
      ..clear()
      ..addAll(b.thankYouMessages);
    _waitingList
      ..clear()
      ..addAll(b.waitingList);
    _alimtalkSettings
      ..clear()
      ..addAll(b.alimtalkSettings);

    if (_selectedClubIndex >= _myClubs.length) {
      _selectedClubIndex = 0;
    }

    _syncAllNextRounds();
    _normalizeScheduleTitles();
  }

  // ── 내가 속한 모임 선택 인덱스 ─────────────────────────
  int _selectedClubIndex = 0;

  // ────────────────────────────────────────────────────────
  //  내가 속한 Club 목록 (mock)
  //  _adminClubs       : 홍길동(총무) 계정용
  //  _guestClubs       : 이민준(일반) — 강남 골프회
  //  _otherMemberClubs : 박민준(일반) — 시흥CC (다른 모임)
  //  _myClubs          : 현재 로그인 계정 기준 (switchUser로 교체됨)
  // ────────────────────────────────────────────────────────

  // ── 홍길동(총무) 모임 ────────────────────────────────────
  static final List<Club> _adminClubs = [];

  // ── 이민준(일반회원) 모임 — 강남 골프회 소속 ─────────────
  static final List<Club> _guestClubs = [];

  // ── 박민준(일반회원) 모임 — 시흘CC만 (다른 모임 테스트) ──
  static final List<Club> _otherMemberClubs = [];

  // ── 현재 로그인 계정 모임 (switchUser로 교체) ────────────
  final List<Club> _myClubs = [];

  // ────────────────────────────────────────────────────────
  //  전체 공개 모임 목록 (검색/가입 화면용 mock)
  // ────────────────────────────────────────────────────────
  static final List<Club> _demoAllClubs = [];

  final List<Club> _allClubs = [];

  /// 테스트 초기화 — 인메모리 모임을 데모 시드(6개)로 되돌리고 대기 중인 저장을 취소.
  void resetToDemoDefaults({String authUserId = 'user_me'}) {
    _persistTimer?.cancel();
    _persistTimer = null;
    _suppressPersist = true;
    _freshClubIds.clear();
    _treasurerVacantClubIds.clear();
    _allClubs
      ..clear()
      ..addAll(_demoAllClubs);
    switch (authUserId) {
      case 'user_guest':
        _currentUserId = 'mg1';
        _currentUserName = '이민준';
        _myClubs
          ..clear()
          ..addAll(_guestClubs);
        break;
      case 'user_other':
        _currentUserId = 'm4';
        _currentUserName = '박민준';
        _myClubs
          ..clear()
          ..addAll(_otherMemberClubs);
        break;
      case 'user_me':
      default:
        _currentUserId = 'm1';
        _currentUserName = '홍길동';
        _myClubs
          ..clear()
          ..addAll(_adminClubs);
        break;
    }
    _selectedClubIndex = 0;
    _syncAccountClubRoles(authUserId);
    _syncAllNextRounds();
    _normalizeScheduleTitles();
    _reconcileLegacyMemberCounts();
    _suppressPersist = false;
    notifyListeners();
  }

  // ────────────────────────────────────────────────────────
  //  가입 신청 목록
  // ────────────────────────────────────────────────────────
  final List<JoinRequest> _joinRequests = [];

  // ────────────────────────────────────────────────────────
  //  Members mock
  // ────────────────────────────────────────────────────────
  final List<Member> _members = [
    Member(id: 'm1', name: '홍길동', gender: '남',
        birthDate: DateTime(1974, 3, 15), memberType: '정회원', role: '일반',
        phone: '010-1234-5678',
        bio: '',
        handicap: 12.0, joinDate: DateTime(2018, 1, 1),
        address: '서울시 강남구', status: '활성'),
    Member(id: 'mg1', name: '이민준', gender: '남',
        birthDate: DateTime(1991, 9, 20), memberType: '정회원', role: '일반',
        phone: '010-9999-0000',
        bio: '',
        handicap: 18.0, joinDate: DateTime(2022, 7, 1),
        address: '서울시 강남구', status: '활성'),
  ];

  // ────────────────────────────────────────────────────────
  //  Activity / Attendance / Announcement
  // ────────────────────────────────────────────────────────
  final List<ActivityItem> _activities = [];

  /// @deprecated 홈 위젯 미사용 — 실제 집계는 club_room / schedule 응답 기준
  final AttendanceStatus _attendanceStatus =
      AttendanceStatus(confirmed: 0, noResponse: 0, declined: 0);

  final List<Announcement> _announcements = [];

  // ─── 앱 알림 목록 — 시드 없음(실제 액션만). 잔존 시드는 로그인 시 purge ───
  final List<AppNotification> _appNotifications = [];

  // ════════════════════════════════════════════════════════
  //  Getters — My Clubs
  // ════════════════════════════════════════════════════════
  int get selectedClubIndex => _selectedClubIndex;
  List<Club> get clubs        => List.unmodifiable(_myClubs);
  List<Club> get myClubs      => List.unmodifiable(_myClubs);   // MyClubsScreen용
  Club get selectedClub {
    if (_myClubs.isEmpty) {
      throw StateError('선택된 모임이 없습니다. myClubs가 비어 있습니다.');
    }
    final idx = _selectedClubIndex.clamp(0, _myClubs.length - 1);
    return _myClubs[idx];
  }

  Club? get selectedClubOrNull =>
      _myClubs.isEmpty ? null : selectedClub;

  // ════════════════════════════════════════════════════════
  //  Getters — All Clubs (탐색/검색)
  // ════════════════════════════════════════════════════════
  List<Club> get allClubs => List.unmodifiable(_allClubs);

  /// 지역·업종 필터 + 키워드 검색
  List<Club> filteredClubs({
    String region = '전체',
    String industry = '전체',
    String keyword = '',
  }) {
    return _allClubs.where((c) {
      // '전체': 전부, '지역다양함': 지역다양함인 모임만, 그 외: 시·도 접두사 or 완전일치
      final matchRegion = region == '전체' ||
          c.region == region ||
          c.region.startsWith('$region ') ||
          (region == '지역다양함' && c.region == '지역다양함') ||
          // 시·도 그룹 매칭: '충청' → 충북/충남/대전/세종
          (region == '충청' && (c.region.startsWith('충') || c.region == '대전' || c.region == '세종')) ||
          (region == '전라' && (c.region.startsWith('전') || c.region == '광주')) ||
          (region == '경상' && (c.region.startsWith('경') ||
              c.region.startsWith('대구') ||
              c.region.startsWith('울산') ||
              c.region.startsWith('부산')));
      final matchIndustry = industry == '전체' || c.industry == industry;
      final matchKeyword  = keyword.isEmpty ||
          c.name.contains(keyword) ||
          c.description.contains(keyword);
      return matchRegion && matchIndustry && matchKeyword;
    }).toList();
  }

  /// 내가 이미 속한 모임인지 확인 (seed_c1 ↔ c1 별칭 포함)
  bool isMyClub(String clubId) {
    if (_isLeftClub(clubId)) return false;
    final aliases = clubIdAliases(clubId);
    return _myClubs.any((c) => aliases.contains(c.id));
  }

  /// 이미 가입 신청했는지 확인 (seed↔legacy, user_guest↔mg1 별칭 포함)
  bool hasPendingRequest(String clubId) {
    final clubs = clubIdAliases(clubId);
    return _joinRequests.any((r) =>
        clubs.contains(r.clubId) &&
        r.status == JoinRequestStatus.pending &&
        (_userIdsMatch(r.userId, currentUserId) ||
            _userIdsMatch(r.userId, _persistAuthUserId)));
  }

  // ════════════════════════════════════════════════════════
  //  Getters — Members
  // ════════════════════════════════════════════════════════
  List<Member> get members {
    return membersForClub(selectedClub.id);
  }

  /// 어드민·동기화용 — 특정 모임의 회원 목록
  List<Member> membersForClub(String clubId) {
    final fresh = _freshClubIds.contains(clubId);
    final legacy = _legacyMockClubIds.contains(clubId);
    if (fresh || !legacy) {
      return _members
          .where((m) =>
              m.id == 'm_creator_$clubId' ||
              m.id.startsWith('m_${clubId}_'))
          .toList();
    }
    // c1~c5 데모 모임은 공유 mock 회원 명단
    return List.unmodifiable(_members);
  }

  List<Member> get activeMembers =>
      members.where((m) => m.status == '활성').toList();
  List<Member> get regularMembers =>
      activeMembers.where((m) => m.memberType == '정회원').toList();
  List<Member> get guestMembers =>
      activeMembers.where((m) => m.memberType == '게스트').toList();
  List<Member> get officerMembers =>
      activeMembers.where((m) => ClubMemberRole.isOfficer(m.role)).toList();

  /// 현재 로그인한 사용자의 Member 객체 (선택 모임 기준)
  ///
  /// 신규 모임은 `m_creator_{clubId}` 명단을 쓰므로, 전역 시드(m1/mg1)를
  /// 먼저 반환하면 직책이 '일반'으로 덮여 회장 권한이 사라진다.
  Member? get currentMember {
    if (_myClubs.isNotEmpty) {
      try {
        final clubId = selectedClub.id;
        final clubMembers = membersForClub(clubId);
        if (clubMembers.isNotEmpty) {
          final aliases = <String>{
            currentUserId,
            if (_persistAuthUserId != null) _persistAuthUserId!,
            ..._authAliases(_persistAuthUserId ?? currentUserId),
          };
          for (final id in aliases) {
            final hit =
                clubMembers.where((m) => m.id == id).firstOrNull;
            if (hit != null) return hit;
            final prefixed = clubMembers
                .where((m) => m.id == 'm_${clubId}_$id')
                .firstOrNull;
            if (prefixed != null) return prefixed;
          }

          final creatorId = 'm_creator_$clubId';
          final creator =
              clubMembers.where((m) => m.id == creatorId).firstOrNull;
          if (creator != null) {
            final cid = selectedClub.creatorId;
            if (cid.isEmpty ||
                _userIdsMatch(cid, currentUserId) ||
                (_persistAuthUserId != null &&
                    _userIdsMatch(cid, _persistAuthUserId))) {
              return creator;
            }
          }
        }
      } catch (_) {}
    }

    return _members.where((m) => m.id == currentUserId).firstOrNull;
  }

  List<Member> get birthdayThisMonth {
    final month = DateTime.now().month;
    return activeMembers.where((m) => m.birthDate?.month == month).toList();
  }

  // ════════════════════════════════════════════════════════
  //  Getters — Join Requests
  // ════════════════════════════════════════════════════════
  List<JoinRequest> get allJoinRequests => List.unmodifiable(_joinRequests);

  /// 특정 모임의 대기중 신청 (seed↔legacy 별칭 포함)
  List<JoinRequest> pendingRequestsOf(String clubId) {
    final clubs = clubIdAliases(clubId);
    return _joinRequests
        .where((r) =>
            clubs.contains(r.clubId) && r.status == JoinRequestStatus.pending)
        .toList();
  }

  /// 내가 관리자인 모임들의 전체 대기 건수 (알림 배지용)
  int get totalPendingRequests {
    final myAdminClubIds = _myClubs
        .where((c) => ClubMemberRole.isOfficer(c.myRole))
        .map((c) => c.id)
        .toSet();
    return _joinRequests
        .where((r) =>
            myAdminClubIds.contains(r.clubId) &&
            r.status == JoinRequestStatus.pending)
        .length;
  }

  // ════════════════════════════════════════════════════════
  //  재무 — 회비 설정 mock (현재 연/월 기준 — 하드코딩 연도 금지)
  // ════════════════════════════════════════════════════════
  late final List<DuesSetting> _duesSettings = _seedDuesSettings();
  late final List<DuesPayment> _duesPayments = _seedDuesPayments();
  late final List<PaymentRequest> _paymentRequests = _seedPaymentRequests();

  // ── 수입/지출 내역 mock ──
  final List<Transaction> _transactions = [
    // ✅ 신규 모임 온보딩: 초기 잔액 (앱 도입 전 잔액 세팅 예시)
    Transaction(id: 'ob_demo', type: TxType.income, amount: 1200000,
        category: '초기잔액', title: '앱 도입 전 잔액',
        date: DateTime(2025, 1, 1), recordedBy: '홍길동',
        source: TxSource.openingBalance),
    // 2024년 이월 잔액 (연도 시작 시 이전 연도 잔액 이월)
    Transaction(id: 't0', type: TxType.income, amount: 850000,
        category: '이월잔액', title: '2024년 잔액 이월',
        date: DateTime(2025, 1, 1), recordedBy: '시스템',
        source: TxSource.carryover),
    // 3월 월회비
    Transaction(id: 't_m3_1', type: TxType.income, amount: 50000,
        category: '월회비', title: '3월 월회비 - 홍길동',
        date: DateTime(2025, 3, 3), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't_m3_2', type: TxType.income, amount: 50000,
        category: '월회비', title: '3월 월회비 - 김철수',
        date: DateTime(2025, 3, 4), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't_m3_3', type: TxType.income, amount: 50000,
        category: '월회비', title: '3월 월회비 - 이영희',
        date: DateTime(2025, 3, 5), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't_m3_e1', type: TxType.expense, amount: 150000,
        category: '식비', title: '3월 라운딩 후 식사',
        date: DateTime(2025, 3, 10), recordedBy: '이영희',
        source: TxSource.manual),
    // 4월
    Transaction(id: 't9', type: TxType.income, amount: 50000,
        category: '월회비', title: '4월 월회비 - 홍길동',
        date: DateTime(2025, 4, 3), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't9b', type: TxType.income, amount: 50000,
        category: '월회비', title: '4월 월회비 - 김철수',
        date: DateTime(2025, 4, 4), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't9c', type: TxType.income, amount: 50000,
        category: '월회비', title: '4월 월회비 - 이영희',
        date: DateTime(2025, 4, 4), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't9d', type: TxType.income, amount: 50000,
        category: '월회비', title: '4월 월회비 - 박민준',
        date: DateTime(2025, 4, 5), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't9e', type: TxType.income, amount: 50000,
        category: '월회비', title: '4월 월회비 - 최수연',
        date: DateTime(2025, 4, 6), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't9f', type: TxType.income, amount: 50000,
        category: '월회비', title: '4월 월회비 - 정다은',
        date: DateTime(2025, 4, 7), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't9g', type: TxType.income, amount: 50000,
        category: '월회비', title: '4월 월회비 - 강동원',
        date: DateTime(2025, 4, 8), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't9h', type: TxType.income, amount: 50000,
        category: '월회비', title: '4월 월회비 - 윤서준',
        date: DateTime(2025, 4, 9), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't10', type: TxType.expense, amount: 150000,
        category: '식비', title: '4월 라운딩 후 식사',
        date: DateTime(2025, 4, 20), recordedBy: '이영희',
        source: TxSource.manual),
    Transaction(id: 't11', type: TxType.income, amount: 50000,
        category: '벌금', title: '지각 벌금 (3명)',
        date: DateTime(2025, 4, 20), recordedBy: '이영희',
        source: TxSource.manual),
    // 5월
    Transaction(id: 't4', type: TxType.income, amount: 50000,
        category: '월회비', title: '5월 월회비 - 홍길동',
        date: DateTime(2025, 5, 2), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't4b', type: TxType.income, amount: 50000,
        category: '월회비', title: '5월 월회비 - 김철수',
        date: DateTime(2025, 5, 4), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't4c', type: TxType.income, amount: 50000,
        category: '월회비', title: '5월 월회비 - 이영희',
        date: DateTime(2025, 5, 4), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't4d', type: TxType.income, amount: 50000,
        category: '월회비', title: '5월 월회비 - 박민준',
        date: DateTime(2025, 5, 6), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't4e', type: TxType.income, amount: 50000,
        category: '월회비', title: '5월 월회비 - 최수연',
        date: DateTime(2025, 5, 8), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't4f', type: TxType.income, amount: 50000,
        category: '월회비', title: '5월 월회비 - 정다은',
        date: DateTime(2025, 5, 9), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't4g', type: TxType.income, amount: 50000,
        category: '월회비', title: '5월 월회비 - 강동원',
        date: DateTime(2025, 5, 10), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't4h', type: TxType.income, amount: 50000,
        category: '월회비', title: '5월 월회비 - 윤서준',
        date: DateTime(2025, 5, 12), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't5', type: TxType.income, amount: 100000,
        category: '특별회비', title: '대회 특별회비 - 홍길동',
        date: DateTime(2025, 5, 20), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't5b', type: TxType.income, amount: 100000,
        category: '특별회비', title: '대회 특별회비 - 김철수',
        date: DateTime(2025, 5, 22), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't5c', type: TxType.income, amount: 100000,
        category: '특별회비', title: '대회 특별회비 - 이영희',
        date: DateTime(2025, 5, 22), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't5d', type: TxType.income, amount: 100000,
        category: '특별회비', title: '대회 특별회비 - 정다은',
        date: DateTime(2025, 5, 25), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't5e', type: TxType.income, amount: 100000,
        category: '특별회비', title: '대회 특별회비 - 강동원',
        date: DateTime(2025, 5, 25), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't6', type: TxType.expense, amount: 200000,
        category: '식비', title: '5월 라운딩 후 식사',
        date: DateTime(2025, 5, 18), recordedBy: '이영희',
        source: TxSource.manual),
    Transaction(id: 't7', type: TxType.expense, amount: 80000,
        category: '상품', title: '롱기스트 상품',
        date: DateTime(2025, 5, 18), recordedBy: '이영희',
        source: TxSource.manual),
    Transaction(id: 't8', type: TxType.expense, amount: 30000,
        category: '기타', title: '스코어카드 인쇄',
        date: DateTime(2025, 5, 3), recordedBy: '이영희',
        source: TxSource.manual),
    // 6월
    Transaction(id: 't1', type: TxType.income, amount: 50000,
        category: '월회비', title: '6월 월회비 - 홍길동',
        date: DateTime(2025, 6, 3), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't1b', type: TxType.income, amount: 50000,
        category: '월회비', title: '6월 월회비 - 김철수',
        date: DateTime(2025, 6, 5), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't1c', type: TxType.income, amount: 50000,
        category: '월회비', title: '6월 월회비 - 이영희',
        date: DateTime(2025, 6, 5), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't1d', type: TxType.income, amount: 50000,
        category: '월회비', title: '6월 월회비 - 정다은',
        date: DateTime(2025, 6, 7), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't1e', type: TxType.income, amount: 50000,
        category: '월회비', title: '6월 월회비 - 강동원',
        date: DateTime(2025, 6, 8), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't1f', type: TxType.income, amount: 50000,
        category: '월회비', title: '6월 월회비 - 윤서준',
        date: DateTime(2025, 6, 10), recordedBy: '이영희',
        source: TxSource.dues),
    Transaction(id: 't2', type: TxType.expense, amount: 120000,
        category: '식비', title: '6월 라운딩 후 식사',
        date: DateTime(2025, 6, 8), recordedBy: '이영희',
        source: TxSource.manual),
    Transaction(id: 't3', type: TxType.expense, amount: 50000,
        category: '상품', title: '니어리스트 상품',
        date: DateTime(2025, 6, 8), recordedBy: '이영희',
        source: TxSource.manual),

    // ── 2025년 7월 월회비 수입 (dp20~dp25와 매핑) ──
    Transaction(id: 't_m7_1', type: TxType.income, amount: 50000,
        category: '월회비', title: '7월 월회비 - 홍길동',
        date: DateTime(2025, 7, 2), recordedBy: '이영희',
        source: TxSource.dues, duesPaymentId: 'dp20'),
    Transaction(id: 't_m7_2', type: TxType.income, amount: 50000,
        category: '월회비', title: '7월 월회비 - 김철수',
        date: DateTime(2025, 7, 3), recordedBy: '이영희',
        source: TxSource.dues, duesPaymentId: 'dp21'),
    Transaction(id: 't_m7_3', type: TxType.income, amount: 50000,
        category: '월회비', title: '7월 월회비 - 이영희',
        date: DateTime(2025, 7, 4), recordedBy: '이영희',
        source: TxSource.dues, duesPaymentId: 'dp22'),
    Transaction(id: 't_m7_4', type: TxType.income, amount: 50000,
        category: '월회비', title: '7월 월회비 - 정다은',
        date: DateTime(2025, 7, 5), recordedBy: '이영희',
        source: TxSource.dues, duesPaymentId: 'dp23'),
    Transaction(id: 't_m7_5', type: TxType.income, amount: 50000,
        category: '월회비', title: '7월 월회비 - 강동원',
        date: DateTime(2025, 7, 7), recordedBy: '이영희',
        source: TxSource.dues, duesPaymentId: 'dp24'),
    Transaction(id: 't_m7_6', type: TxType.income, amount: 50000,
        category: '월회비', title: '7월 월회비 - 윤서준',
        date: DateTime(2025, 7, 8), recordedBy: '이영희',
        source: TxSource.dues, duesPaymentId: 'dp25'),
    // 광고비 수입 (ad1 — 스카이72, 2개월 × 100,000원 × 90%)
    Transaction(id: 't_ad_sky72', type: TxType.income, amount: 180000,
        category: '제휴광고', title: '광고비 수입 - 김철수 (홈 배너)',
        date: DateTime(2025, 5, 25), recordedBy: '시스템',
        source: TxSource.ad),
  ];

  // ════════════════════════════════════════════════════════
  //  Getters — 재무
  // ════════════════════════════════════════════════════════

  /// 현재 선택 모임의 회비 설정만 (레거시 mock은 데모 모임에만)
  List<DuesSetting> get _scopedDuesSettings {
    final clubId = selectedClub.id;
    if (_selectedHasLegacyMock) {
      // 데모 모임: clubId 없거나 일치하는 설정
      return _duesSettings
          .where((d) => d.clubId == null || d.clubId == clubId)
          .toList();
    }
    // 신규/테스트 모임: 해당 clubId만 (다른 모임·mock 회비 차단)
    return _duesSettings.where((d) => d.clubId == clubId).toList();
  }

  /// 활성 회비 설정 목록 (선택 모임 기준)
  List<DuesSetting> get activeDuesSettings =>
      _scopedDuesSettings.where((d) => d.isActive).toList();

  /// 전체 납부 내역 (공개)
  List<DuesPayment> get duesPayments => List.unmodifiable(_duesPayments);

  /// 전체 회비 설정 (비활성 포함, 선택 모임 기준)
  List<DuesSetting> get allDuesSettings =>
      List.unmodifiable(_scopedDuesSettings);

  // ── 이달 납부 현황 (홈 회계 카드용) ──

  /// 이달 월회비 설정 (활성 monthly 중 해당 연/월이 납부 기간에 포함)
  DuesSetting? currentMonthDuesSetting(int year, int month) {
    return activeDuesSettings
        .where((d) =>
            d.type == DuesType.monthly && d.isActiveForYearMonth(year, month))
        .cast<DuesSetting?>()
        .firstWhere((_) => true, orElse: () => null);
  }

  /// 홈 회계 카드용 — 이달 월회비, 없으면 올해 연회비. 특별회비는 제외.
  DuesSetting? currentHomeDuesSetting(int year, int month) {
    final monthly = currentMonthDuesSetting(year, month);
    if (monthly != null) return monthly;
    for (final d in activeDuesSettings) {
      if (d.type == DuesType.annual &&
          (d.year ?? d.createdAt.year) == year) {
        return d;
      }
    }
    return null;
  }

  /// 전월 월회비 미납 인원. 월회비 모임이 아니면 0.
  int previousMonthUnpaidCount() {
    if (clubPrimaryDuesType != DuesType.monthly) return 0;
    final now = DateTime.now();
    var y = now.year;
    var m = now.month - 1;
    if (m < 1) {
      m = 12;
      y--;
    }
    final setting = currentMonthDuesSetting(y, m);
    if (setting == null) return 0;
    final total = regularMembers.length;
    final paid = paymentsOf(setting.id, year: y, month: m)
        .map((p) => p.memberId)
        .toSet()
        .length;
    return (total - paid).clamp(0, total);
  }

  /// 이달 적용 회비 (월회비: 해당 연/월 기간 내 / 그 외: 활성 회비)
  List<DuesSetting> applicableDuesInMonth(int year, int month) =>
      activeDuesSettings.where((d) {
        if (d.type == DuesType.monthly) {
          return d.isActiveForYearMonth(year, month);
        }
        return true;
      }).toList();

  /// 특정 회비의 미납 회원 수
  int unpaidCountForDuesSetting(DuesSetting setting, int year, int month) {
    final members = setting.type == DuesType.monthly
        ? regularMembers
        : activeMembers;
    final paidIds = _duesPayments
        .where((p) {
          if (p.duesSettingId != setting.id) return false;
          if (setting.type == DuesType.monthly) {
            return p.paidAt.year == year && p.paidAt.month == month;
          }
          return p.paidAt.year == year;
        })
        .map((p) => p.memberId)
        .toSet();
    return members.where((m) => !paidIds.contains(m.id)).length;
  }

  /// 홈 회계 카드 미납 뱃지 — 기준: 이번 달 월회비(있으면), 복수 회비 시 라벨 보강
  MonthUnpaidSummary monthUnpaidSummary(int year, int month) {
    final applicable = applicableDuesInMonth(year, month);
    final monthly = currentMonthDuesSetting(year, month);

    if (monthly != null) {
      final unpaid = unpaidCountForDuesSetting(monthly, year, month);
      final otherWithUnpaid = applicable
          .where((d) => d.id != monthly.id)
          .where((d) => unpaidCountForDuesSetting(d, year, month) > 0)
          .length;
      final label = otherWithUnpaid > 0
          ? '${monthly.title} 외 $otherWithUnpaid건'
          : monthly.title;
      return MonthUnpaidSummary(unpaidCount: unpaid, duesLabel: label);
    }

    if (applicable.isEmpty) {
      return const MonthUnpaidSummary(unpaidCount: 0, duesLabel: '');
    }
    if (applicable.length == 1) {
      final d = applicable.first;
      return MonthUnpaidSummary(
        unpaidCount: unpaidCountForDuesSetting(d, year, month),
        duesLabel: d.title,
      );
    }

    final withUnpaid = applicable
        .where((d) => unpaidCountForDuesSetting(d, year, month) > 0)
        .toList();
    final count = withUnpaid.isEmpty
        ? 0
        : withUnpaid
            .map((d) => unpaidCountForDuesSetting(d, year, month))
            .reduce((a, b) => a > b ? a : b);
    return MonthUnpaidSummary(
      unpaidCount: count,
      duesLabel: withUnpaid.isEmpty ? '회비 ${applicable.length}건' : '회비 ${withUnpaid.length}건',
    );
  }

  /// 이달 회비 납부자 수 (홈·독촉용). 연회비는 연 단위.
  int paidCountForMonth(int year, int month) {
    final setting = currentHomeDuesSetting(year, month);
    if (setting == null) return 0;
    final monthFilter = setting.type == DuesType.monthly ? month : null;
    return paymentsOf(setting.id, year: year, month: monthFilter)
        .map((p) => p.memberId)
        .toSet()
        .length;
  }

  /// 이달 미납 회원 수 (활성 정회원 기준)
  int unpaidCountForMonth(int year, int month) {
    final setting = currentHomeDuesSetting(year, month);
    if (setting == null) return 0;
    final total = regularMembers.length;
    return (total - paidCountForMonth(year, month)).clamp(0, total);
  }

  /// 활성 회비 1건의 미납 건수 (회원×기간, 설정 생성~현재·밀린 달 포함)
  int unpaidSlotsForDuesSetting(DuesSetting setting, {DateTime? asOf}) {
    final now = asOf ?? DateTime.now();
    final members = setting.type == DuesType.monthly
        ? regularMembers
        : activeMembers;
    if (members.isEmpty) return 0;

    switch (setting.type) {
      case DuesType.monthly:
        var count = 0;
        for (final period in _expectedMonthlyPeriods(setting, now)) {
          for (final m in members) {
            if (!hasPaid(m.id, setting.id,
                year: period.year, month: period.month)) {
              count++;
            }
          }
        }
        return count;
      case DuesType.annual:
        if (setting.createdAt.year > now.year) return 0;
        return members
            .where((m) =>
                !hasPaid(m.id, setting.id, year: setting.createdAt.year))
            .length;
      case DuesType.special:
        return members
            .where((m) => !hasPaid(m.id, setting.id))
            .length;
    }
  }

  /// 활성 회비 전체 미납 금액 (원) — 미납 월별로 당시(변경 전) 금액을 적용
  int totalUnpaidDuesAmount({DateTime? asOf}) {
    final now = asOf ?? DateTime.now();
    int total = 0;
    for (final s in activeDuesSettings) {
      switch (s.type) {
        case DuesType.monthly:
          final members = regularMembers;
          if (members.isEmpty) continue;
          for (final period in _expectedMonthlyPeriods(s, now)) {
            final amt =
                s.amountForPeriod(year: period.year, month: period.month);
            for (final m in members) {
              if (!hasPaid(m.id, s.id,
                  year: period.year, month: period.month)) {
                total += amt;
              }
            }
          }
          break;
        case DuesType.annual:
          final y = s.year ?? s.createdAt.year;
          if (y > now.year) continue;
          final members = activeMembers;
          final amt = s.amountForPeriod(year: y);
          total +=
              members.where((m) => !hasPaid(m.id, s.id, year: y)).length *
                  amt;
          break;
        case DuesType.special:
          final members = activeMembers;
          final amt = s.amountForPeriod(
              year: s.createdAt.year, month: s.createdAt.month);
          total += members.where((m) => !hasPaid(m.id, s.id)).length * amt;
          break;
      }
    }
    return total;
  }

  /// 활성 회비 중 미납이 하나라도 있으면 true (홈 독촉/완납 판단용)
  bool hasAnyUnpaidActiveDues({DateTime? asOf}) =>
      totalUnpaidDuesAmount(asOf: asOf) > 0;

  /// 월회비 청구 대상 연/월 목록 (설정 시작~기준일까지, 절대 구간이면 종료 연/월까지)
  Iterable<({int year, int month})> _expectedMonthlyPeriods(
      DuesSetting setting, DateTime asOf) sync* {
    if (setting.type != DuesType.monthly) return;
    final startYear = setting.startYear ?? setting.createdAt.year;
    final periodStart = setting.startMonth ?? 1;
    final periodEnd = setting.endMonth ?? 12;

    if (setting.endYear != null) {
      // 절대 구간 (연도 포함, 1년 이상 가능)
      final endYear = setting.endYear!;
      var year = startYear;
      var month = math.max(periodStart, setting.createdAt.year == startYear
          ? setting.createdAt.month
          : periodStart);
      while (year * 12 + month <= endYear * 12 + periodEnd &&
          year * 12 + month <= asOf.year * 12 + asOf.month) {
        yield (year: year, month: month);
        month++;
        if (month > 12) {
          month = 1;
          year++;
        }
      }
      return;
    }

    // 매년 반복되는 월 구간
    for (var year = startYear; year <= asOf.year; year++) {
      var monthFrom = periodStart;
      if (year == startYear) {
        monthFrom = math.max(periodStart, setting.createdAt.month);
      }
      var monthTo = periodEnd;
      if (year == asOf.year) {
        monthTo = math.min(periodEnd, asOf.month);
      }
      for (var month = monthFrom; month <= monthTo; month++) {
        if (setting.isMonthInPeriod(month)) {
          yield (year: year, month: month);
        }
      }
    }
  }

  /// 현재 선택 모임의 거래 내역
  List<Transaction> get _scopedTransactions {
    final clubId = selectedClub.id;
    final aliases = clubIdAliases(clubId);
    final filtered = _selectedHasLegacyMock
        ? _transactions.where(
            (t) => t.clubId == null || aliases.contains(t.clubId),
          )
        : _transactions.where(
            (t) => t.clubId != null && aliases.contains(t.clubId),
          );
    final result = filtered.toList();
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  /// 전체 거래 내역 (최신순)
  List<Transaction> get transactions => _scopedTransactions;

  /// 월별 거래 내역 필터
  List<Transaction> transactionsByMonth(int year, int month) =>
      transactions.where((t) =>
          t.date.year == year && t.date.month == month).toList();

  /// 현재 잔고 (선택 모임 기준, 마이너스 허용)
  int get totalBalance {
    int balance = 0;
    for (final t in _scopedTransactions) {
      balance += t.type == TxType.income ? t.amount : -t.amount;
    }
    return balance;
  }

  /// 특정 연도 말 잔고 (다음 연도 이월 기준, 선택 모임)
  int balanceAtYearEnd(int year) {
    int balance = 0;
    for (final t in _scopedTransactions) {
      if (t.date.year <= year) {
        balance += t.type == TxType.income ? t.amount : -t.amount;
      }
    }
    return balance;
  }

  /// 특정 연·월 말까지의 누적 잔고 (선택 모임)
  int balanceUntil({required int year, required int month}) {
    int balance = 0;
    for (final t in _scopedTransactions) {
      final ym = t.date.year * 12 + t.date.month;
      final until = year * 12 + month;
      if (ym <= until) {
        balance += t.type == TxType.income ? t.amount : -t.amount;
      }
    }
    return balance;
  }

  /// 이월 잔액이 이미 등록됐는지 확인
  bool hasCarryover(int year) {
    return _transactions.any((t) =>
        t.source == TxSource.carryover &&
        t.date.year == year &&
        t.date.month == 1);
  }

  // ════════════════════════════════════════════════════════
  //  Getters — 입금 확인 요청 (PaymentRequest)
  // ════════════════════════════════════════════════════════

  /// 현재 선택 모임의 입금 확인 요청만
  List<PaymentRequest> get _scopedPaymentRequests {
    final clubId = selectedClub.id;
    final filtered = _selectedHasLegacyMock
        ? _paymentRequests.where((r) => r.clubId == null || r.clubId == clubId)
        : _paymentRequests.where((r) => r.clubId == clubId);
    return filtered.toList();
  }

  /// 전체 요청 목록 (최신순, 선택 모임 기준)
  List<PaymentRequest> get allPaymentRequests {
    final list = _scopedPaymentRequests;
    list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return list;
  }

  /// 대기 중인 요청만
  List<PaymentRequest> get pendingPaymentRequests =>
      allPaymentRequests
          .where((r) => r.status == PaymentRequestStatus.pending)
          .toList();

  /// 대기 중인 요청 수 (배지용)
  int get pendingRequestCount => pendingPaymentRequests.length;

  /// 특정 회원이 특정 회비+기간에 요청 중인지
  PaymentRequest? myPendingRequest({
    required String memberId,
    required String duesSettingId,
    int? year,
    int? month,
  }) {
    try {
      return _scopedPaymentRequests.firstWhere((r) =>
          r.memberId == memberId &&
          r.duesSettingId == duesSettingId &&
          r.status == PaymentRequestStatus.pending &&
          (year == null || r.year == year) &&
          (month == null || r.month == month));
    } catch (_) {
      return null;
    }
  }

  // ════════════════════════════════════════════════════════
  //  Actions — 입금 확인 요청
  // ════════════════════════════════════════════════════════

  /// 일반 회원: 입금 확인 요청 등록
  void submitPaymentRequest({
    required String memberId,
    required String memberName,
    required String duesSettingId,
    required int amount,
    int? year,
    int? month,
    String? memo,
  }) {
    final setting = _duesSettings.firstWhere((d) => d.id == duesSettingId);
    _paymentRequests.add(PaymentRequest(
      id: 'pr_${DateTime.now().millisecondsSinceEpoch}',
      memberId: memberId,
      memberName: memberName,
      duesSettingId: duesSettingId,
      duesTitle: setting.title,
      amount: amount,
      year: year,
      month: month,
      memo: memo,
      status: PaymentRequestStatus.pending,
      requestedAt: DateTime.now(),
      clubId: setting.clubId ?? selectedClub.id,
    ));

    // 활동 피드에 기록 (FCM 대체)
    _activities.insert(0, ActivityItem(
      id: 'act_${DateTime.now().millisecondsSinceEpoch}',
      memberId: memberId,
      memberName: memberName,
      activityType: 'payment',
      description: '입금 확인 요청 — ${setting.title}'
          '${month != null ? " ${month}월" : ""}',
      timestamp: DateTime.now(),
    ));

    notifyListeners();
  }

  /// 일반 회원: 요청 취소
  void cancelPaymentRequest(String requestId) {
    _paymentRequests.removeWhere((r) => r.id == requestId);
    notifyListeners();
  }

  /// 총무/관리자: 요청 승인 → 납부 완료 처리
  void approvePaymentRequest(String requestId) {
    final idx = _paymentRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return;
    final req = _paymentRequests[idx];

    // 상태를 confirmed로 변경
    _paymentRequests[idx] = req.copyWith(
      status: PaymentRequestStatus.confirmed,
      reviewedBy: currentUserName,
      reviewedAt: DateTime.now(),
    );

    // 납부 기록 + 수입 자동 등록
    recordPayment(
      memberId: req.memberId,
      memberName: req.memberName,
      duesSettingId: req.duesSettingId,
      amount: req.amount,
      memo: '입금확인 승인',
      year: req.year,
      month: req.month,
    );
  }

  /// 총무/관리자: 요청 반려
  void rejectPaymentRequest(String requestId, {String? reason}) {
    final idx = _paymentRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return;
    _paymentRequests[idx] = _paymentRequests[idx].copyWith(
      status: PaymentRequestStatus.rejected,
      reviewedBy: currentUserName,
      reviewedAt: DateTime.now(),
    );
    notifyListeners();
  }

  /// 특정 월 수입 합계
  int monthlyIncome(int year, int month) =>
      transactionsByMonth(year, month)
          .where((t) => t.type == TxType.income)
          .fold(0, (sum, t) => sum + t.amount);

  /// 특정 월 지출 합계
  int monthlyExpense(int year, int month) =>
      transactionsByMonth(year, month)
          .where((t) => t.type == TxType.expense)
          .fold(0, (sum, t) => sum + t.amount);

  /// 특정 연도 수입 합계 (선택 모임)
  int yearlyIncome(int year) =>
      _scopedTransactions
          .where((t) => t.date.year == year && t.type == TxType.income)
          .fold(0, (sum, t) => sum + t.amount);

  /// 특정 연도 지출 합계 (선택 모임)
  int yearlyExpense(int year) =>
      _scopedTransactions
          .where((t) => t.date.year == year && t.type == TxType.expense)
          .fold(0, (sum, t) => sum + t.amount);

  /// 특정 연도 거래 목록 (선택 모임)
  List<Transaction> transactionsByYear(int year) =>
      _scopedTransactions.where((t) => t.date.year == year).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  /// 데이터가 있는 연도 목록 (선택 모임)
  List<int> get availableYears {
    final years = _scopedTransactions.map((t) => t.date.year).toSet().toList();
    years.sort((a, b) => b.compareTo(a));
    return years.isEmpty ? [DateTime.now().year] : years;
  }

  /// 월별 요약 (결산보고용) - (year, month) → {income, expense, net}
  List<Map<String, dynamic>> monthlySummary(int year) {
    final result = <Map<String, dynamic>>[];
    for (int m = 1; m <= 12; m++) {
      final inc = monthlyIncome(year, m);
      final exp = monthlyExpense(year, m);
      if (inc > 0 || exp > 0) {
        result.add({
          'month': m,
          'income': inc,
          'expense': exp,
          'net': inc - exp,
        });
      }
    }
    return result;
  }

  /// 특정 회비설정 + 기간의 납부자 목록
  List<DuesPayment> paymentsOf(String duesSettingId,
      {int? year, int? month}) {
    return _duesPayments.where((p) {
      if (p.duesSettingId != duesSettingId) return false;
      if (year != null && p.paidAt.year != year) return false;
      if (month != null && p.paidAt.month != month) return false;
      return true;
    }).toList();
  }

  /// 특정 회원이 특정 회비설정+기간에 납부했는지
  bool hasPaid(String memberId, String duesSettingId,
      {int? year, int? month}) {
    return paymentsOf(duesSettingId, year: year, month: month)
        .any((p) => p.memberId == memberId);
  }

  // ════════════════════════════════════════════════════════
  //  Actions — 재무
  // ════════════════════════════════════════════════════════

  /// 납부 처리 (총무용) — 납부 기록 + 수입 거래 자동 등록
  void recordPayment({
    required String memberId,
    required String memberName,
    required String duesSettingId,
    required int amount,
    String? memo,
    int? year,
    int? month,
    bool skipsBalance = false,   // true = 상태만 변경, 잔고 미반영
  }) {
    final now = DateTime.now();
    final paidAt = (year != null && month != null)
        ? DateTime(year, month, now.day)
        : now;

    final paymentId = 'dp_${DateTime.now().millisecondsSinceEpoch}';
    _duesPayments.add(DuesPayment(
      id: paymentId,
      memberId: memberId,
      memberName: memberName,
      duesSettingId: duesSettingId,
      amount: amount,
      paidAt: paidAt,
      memo: memo,
      recordedBy: currentUserName,
      skipsBalance: skipsBalance,
    ));

    // 잔고 반영 옵션일 때만 수입 거래 등록
    if (!skipsBalance) {
      final setting = _duesSettings.firstWhere((d) => d.id == duesSettingId);
      final periodPart = (setting.type == DuesType.monthly && month != null)
          ? '${month}월 '
          : '';
      // 잔고 스코프는 selectedClub 기준 — setting.clubId 불일치로 잔고 미반영 방지
      final txClubId = selectedClub.id;
      _transactions.add(Transaction(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        type: TxType.income,
        amount: amount,
        category: setting.type.label,
        title: '$periodPart${setting.type.label} - $memberName',
        date: paidAt,
        recordedBy: currentUserName,
        source: TxSource.dues,
        duesPaymentId: paymentId,
        clubId: txClubId,
      ));
    }

    // 회비 설정에 clubId가 없으면 현재 모임으로 붙여 동기화·표시가 유지되게 한다
    final setIdx = _duesSettings.indexWhere((d) => d.id == duesSettingId);
    if (setIdx >= 0) {
      final s = _duesSettings[setIdx];
      if (s.clubId == null ||
          s.clubId!.isEmpty ||
          !clubIdAliases(selectedClub.id).contains(s.clubId)) {
        _duesSettings[setIdx] = s.copyWith(clubId: selectedClub.id);
      }
    }

    _stampOrphanTransactionClubIds();
    _persistImmediately();
    notifyListeners();
  }

  /// 납부 취소 — 납부 기록 + 연결된 수입 거래 함께 삭제
  void cancelPayment(String memberId, String duesSettingId,
      {int? year, int? month}) {
    // 취소할 납부 기록 찾기
    final payments = _duesPayments.where((p) {
      if (p.memberId != memberId || p.duesSettingId != duesSettingId) {
        return false;
      }
      if (year != null && p.paidAt.year != year) return false;
      if (month != null && p.paidAt.month != month) return false;
      return true;
    }).toList();

    // 연결된 수입 거래도 함께 삭제 (dues 소스만)
    for (final p in payments) {
      _transactions.removeWhere((t) =>
          t.source == TxSource.dues && t.duesPaymentId == p.id);
    }
    _duesPayments.removeWhere((p) {
      if (p.memberId != memberId || p.duesSettingId != duesSettingId) {
        return false;
      }
      if (year != null && p.paidAt.year != year) return false;
      if (month != null && p.paidAt.month != month) return false;
      return true;
    });
    _persistImmediately();
    notifyListeners();
  }

  /// 이월 잔액 수동 등록 (신규 연도 시작 시)
  void addCarryover({required int amount, required int toYear}) {
    if (hasCarryover(toYear)) return; // 이미 등록된 경우 스킵
    _transactions.add(Transaction(
      id: 'co_${DateTime.now().millisecondsSinceEpoch}',
      type: TxType.income,
      amount: amount,
      category: '이월잔액',
      title: '${toYear - 1}년 잔액 이월',
      date: DateTime(toYear, 1, 1),
      recordedBy: '시스템',
      source: TxSource.carryover,
      clubId: selectedClub.id,
    ));
    notifyListeners();
    _persistImmediately();
  }

  // ════════════════════════════════════════════════════════
  //  신규 모임 온보딩 — 초기 잔액 세팅
  // ════════════════════════════════════════════════════════

  /// 초기 잔액이 이미 세팅됐는지 (openingBalance 소스 거래 존재 여부, 선택 모임 기준)
  bool get hasOpeningBalance =>
      _scopedTransactions.any((t) => t.source == TxSource.openingBalance);

  /// 재무 데이터가 전혀 없는 상태인지 (온보딩 배너 표시 기준)
  bool get isFinanceEmpty =>
      _scopedTransactions.isEmpty && activeDuesSettings.isEmpty;

  /// 선택 모임에 회계/회비 데이터가 없는지 (홈 빈 카드 기준)
  bool get isSelectedClubFinanceEmpty =>
      isFinanceEmpty && activeDuesSettings.isEmpty;

  /// 회비(재무) 최초 세팅이 아직 안 된 상태
  bool get isFinanceSetupPending => activeDuesSettings.isEmpty;

  /// 월회비 또는 연회비 중 모임이 쓰는 쪽. 둘 다 있으면 월회비.
  DuesType? get clubPrimaryDuesType {
    for (final d in activeDuesSettings) {
      if (d.type == DuesType.monthly) return DuesType.monthly;
      if (d.type == DuesType.annual) return DuesType.annual;
    }
    for (final d in allDuesSettings) {
      if (d.type == DuesType.monthly) return DuesType.monthly;
      if (d.type == DuesType.annual) return DuesType.annual;
    }
    return null;
  }

  /// 초기 잔액 세팅
  /// [amount]    : 현재 회비 잔고 (원)
  /// [asOf]      : 기준 날짜 (예: 2025-01-01 또는 오늘)
  /// [memo]      : 메모 (예: "앱 도입 전 누적 잔액", "2025년 1월 현재 잔고")
  void setOpeningBalance({
    required int amount,
    required DateTime asOf,
    String? memo,
  }) {
    final clubId = selectedClub.id;
    // 기존 초기잔액 거래가 있으면 교체 (중복 방지, 선택 모임 한정)
    _transactions.removeWhere((t) =>
        t.source == TxSource.openingBalance &&
        (t.clubId == clubId || (t.clubId == null && _selectedHasLegacyMock)));

    // 0원도 등록(잔고등록 하지 않기) — hasOpeningBalance 판별용 마커
    _transactions.add(Transaction(
      id: 'ob_${DateTime.now().millisecondsSinceEpoch}',
      type: TxType.income,
      amount: amount < 0 ? 0 : amount,
      category: '초기잔액',
      title: memo ?? (amount == 0 ? '잔고 등록 안 함 (0원 시작)' : '앱 도입 전 잔액'),
      date: asOf,
      recordedBy: currentUserName,
      source: TxSource.openingBalance,
      clubId: clubId,
    ));
    notifyListeners();
    _persistImmediately();
  }

  /// 초기 잔액 삭제 (잘못 입력 시 리셋)
  void removeOpeningBalance() {
    final clubId = selectedClub.id;
    _transactions.removeWhere((t) =>
        t.source == TxSource.openingBalance &&
        (t.clubId == clubId || (t.clubId == null && _selectedHasLegacyMock)));
    notifyListeners();
    _persistImmediately();
  }

  /// 거래 내역 추가 (수동)
  void addTransaction(Transaction tx) {
    final clubId = selectedClub.id;
    _transactions.add(tx.clubId != null ? tx : Transaction(
      id: tx.id,
      type: tx.type,
      amount: tx.amount,
      category: tx.category,
      title: tx.title,
      memo: tx.memo,
      date: tx.date,
      recordedBy: tx.recordedBy,
      source: tx.source,
      duesPaymentId: tx.duesPaymentId,
      clubId: clubId,
    ));
    notifyListeners();
    _persistImmediately();
  }

  /// 회비 설정 추가
  void addDuesSetting(DuesSetting setting) {
    _duesSettings.add(setting);
    notifyListeners();
    _persistImmediately();
    final due = setting.dueDate;
    final dueText = due == null
        ? ''
        : '${due.year}.${due.month.toString().padLeft(2, '0')}.${due.day.toString().padLeft(2, '0')}';
    _notifyHqPush(
      typeId: HqPushCatalog.duesRequest,
      userIds: regularMembers.map((m) => m.id).toList(),
      appType: AppNotificationType.announcement,
      clubId: selectedClub.id,
      clubName: selectedClub.name,
      vars: {
        '모임명': selectedClub.name,
        '기한': dueText,
      },
      targetId: setting.id,
      notifySelf: true,
    );
    _dispatchClubAlimtalk(
      hqTypeId: HqAlimtalkCatalog.duesRequestId,
      members: regularMembers,
      variablesFor: (m) => {
        '#{모임명}': selectedClub.name,
        '#{이름}': m.name.trim().isEmpty ? '회원' : m.name.trim(),
        '#{금액}': '${setting.amount}',
        '#{기한}': dueText.isEmpty ? '-' : dueText,
      },
    );
  }

  /// 총무 수동 회비 독촉
  void sendDuesNudge({
    required List<String> memberIds,
    required String duesTitle,
  }) {
    for (final id in memberIds) {
      final name = activeMembers.where((m) => m.id == id).firstOrNull?.name ?? '';
      _notifyHqPush(
        typeId: HqPushCatalog.duesNudge,
        userIds: [id],
        appType: AppNotificationType.announcement,
        clubId: selectedClub.id,
        clubName: selectedClub.name,
        vars: {
          '이름': name,
          '모임명': selectedClub.name,
        },
        targetId: duesTitle,
        notifySelf: true,
      );
    }
    final targets = activeMembers
        .where((m) => memberIds.contains(m.id))
        .toList();
    _dispatchClubAlimtalk(
      hqTypeId: HqAlimtalkCatalog.duesNudgeId,
      members: targets,
      variablesFor: (m) => {
        '#{모임명}': selectedClub.name,
        '#{이름}': m.name.trim().isEmpty ? '회원' : m.name.trim(),
      },
    );
  }

  /// 회비 설정 수정 (기간 변경 등)
  void updateDuesSetting(DuesSetting updated) {
    final idx = _duesSettings.indexWhere((d) => d.id == updated.id);
    if (idx != -1) {
      _duesSettings[idx] = updated;
      notifyListeners();
      _persistImmediately();
    }
  }

  /// 월회비 ↔ 연회비 전환. 기존 주 회비는 종료하고 납부 기록은 유지.
  void switchPrimaryDuesType(DuesType next, {String? keepSettingId}) {
    if (next == DuesType.special) return;
    for (final d in List<DuesSetting>.from(_scopedDuesSettings)) {
      if (!d.isActive) continue;
      if (keepSettingId != null && d.id == keepSettingId) continue;
      if (d.type == DuesType.monthly || d.type == DuesType.annual) {
        final idx = _duesSettings.indexWhere((x) => x.id == d.id);
        if (idx != -1) {
          _duesSettings[idx] = _duesSettings[idx].copyWith(isActive: false);
        }
      }
    }
    notifyListeners();
    _persistImmediately();
  }

  /// 회비 설정 비활성화
  void deactivateDuesSetting(String id) {
    final idx = _duesSettings.indexWhere((d) => d.id == id);
    if (idx != -1) {
      _duesSettings[idx] = _duesSettings[idx].copyWith(isActive: false);
      notifyListeners();
      _persistImmediately();
    }
  }

  /// 회비 설정 완전 삭제 — 연결 납부·입금요청·회비 수입 거래도 함께 제거
  void deleteDuesSetting(String id) {
    final paymentIds = _duesPayments
        .where((p) => p.duesSettingId == id)
        .map((p) => p.id)
        .toSet();
    _transactions.removeWhere((t) =>
        t.source == TxSource.dues &&
        t.duesPaymentId != null &&
        paymentIds.contains(t.duesPaymentId));
    _duesPayments.removeWhere((p) => p.duesSettingId == id);
    _paymentRequests.removeWhere((r) => r.duesSettingId == id);
    _duesSettings.removeWhere((d) => d.id == id);
    notifyListeners();
    _persistImmediately();
  }

  // ════════════════════════════════════════════════════════
  //  일정 (RoundSchedule) mock
  // ════════════════════════════════════════════════════════
  final List<RoundSchedule> _schedules = [];

  // ════════════════════════════════════════════════════════
  //  Getters — Schedules
  // ════════════════════════════════════════════════════════

  /// 현재 선택된 모임의 전체 일정 (최신순)
  List<RoundSchedule> get schedules {
    final clubId = selectedClub.id;
    final list = _schedules.where((s) => s.clubId == clubId).toList();
    list.sort((a, b) => b.roundDate.compareTo(a.roundDate));
    return list;
  }

  /// 취소된 일정을 뺀 목록.
  ///
  /// 일정 탭은 `upcomingSchedules` + `pastSchedules` 만 보여 주고 둘 다
  /// 취소를 제외하므로, 이 값의 개수가 사용자가 화면에서 세는 일정 수와 같다.
  /// 갤러리처럼 '모임의 일정 전체'를 훑는 화면은 `schedules` 가 아니라
  /// 이 getter 를 써야 개수가 어긋나지 않는다.
  List<RoundSchedule> get activeSchedules =>
      schedules.where((s) => s.status != ScheduleStatus.cancelled).toList();

  /// 취소된 일정 id — 사진·조편성 등 파생 데이터를 걸러낼 때 쓴다.
  Set<String> get cancelledScheduleIds => schedules
      .where((s) => s.status == ScheduleStatus.cancelled)
      .map((s) => s.id)
      .toSet();

  /// 예정 일정만 (가까운 날짜 순)
  /// 취소된 일정은 제외하고, 라운딩 당일 자정이 지나면 자동으로 지난 일정으로 넘어간다
  /// (판별 기준: [RoundSchedule.isDateOver])
  List<RoundSchedule> get upcomingSchedules {
    final clubId = selectedClub.id;
    final list = _schedules
        .where((s) =>
            s.clubId == clubId &&
            s.status == ScheduleStatus.upcoming &&
            !s.isDateOver)
        .toList();
    list.sort((a, b) => a.roundDate.compareTo(b.roundDate));
    return list;
  }

  /// 가장 가까운 예정 일정
  RoundSchedule? get nextUpcomingSchedule =>
      upcomingSchedules.isEmpty ? null : upcomingSchedules.first;

  /// 지난 일정만 (최근 날짜 순). 자정이 지나 자동 이동된 일정도 포함되며,
  /// 이동 후에도 스코어/기록 입력은 계속 가능하다.
  List<RoundSchedule> get pastSchedules {
    final list = schedules.where((s) => s.isPast).toList();
    list.sort((a, b) => b.roundDate.compareTo(a.roundDate));
    return list;
  }

  /// id로 일정 조회
  RoundSchedule? scheduleById(String id) =>
      _schedules.cast<RoundSchedule?>().firstWhere(
          (s) => s?.id == id, orElse: () => null);

  /// 현재 유저의 응답 조회
  AttendanceResponse? myResponse(String scheduleId) {
    final s = scheduleById(scheduleId);
    if (s == null) return null;
    final myId = currentMember?.id ?? currentUserId;
    try {
      return s.responses.firstWhere((r) => r.memberId == myId);
    } catch (_) {
      return null;
    }
  }

  /// 현재 유저의 대기 등록 상태 (waiting / notified)
  WaitingEntry? myWaitingEntry(String scheduleId) {
    final myId = currentMember?.id ?? currentUserId;
    try {
      return _waitingList.firstWhere(
        (w) =>
            w.scheduleId == scheduleId &&
            w.memberId == myId &&
            (w.status == WaitingStatus.waiting ||
                w.status == WaitingStatus.notified),
      );
    } catch (_) {
      return null;
    }
  }

  // ════════════════════════════════════════════════════════
  //  Actions — Schedule
  // ════════════════════════════════════════════════════════

  /// 일정 등록 (회장·부회장·총무만)
  void addSchedule(RoundSchedule schedule) {
    if (!canCreateSchedule) {
      debugPrint('[ClubProvider] addSchedule blocked — not executive');
      return;
    }
    _schedules.add(schedule);
    // Club의 nextRoundDate/Course 업데이트 (가장 가까운 예정 일정으로)
    _syncNextRound(schedule.clubId);
    // 등록 시 지정한 동반자는 자동 참석 처리
    for (final companionId in schedule.companionIds) {
      final member = _members.where((m) => m.id == companionId).firstOrNull;
      if (member == null) continue;
      adminSetAttendance(
        scheduleId: schedule.id,
        memberId: member.id,
        memberName: member.name,
        response: '참석',
      );
    }
    notifyListeners();
    _persistImmediately();
    final clubName = selectedClub.name;
    _notifyHqPush(
      typeId: HqPushCatalog.scheduleConfirm,
      userIds: _scheduleBroadcastUserIds(),
      appType: AppNotificationType.announcement,
      clubId: schedule.clubId,
      clubName: clubName,
      vars: {
        '모임명': clubName,
        '일정명': schedule.displayTitle,
      },
      targetId: schedule.id,
      notifySelf: true,
    );
  }

  /// 일정 등록 푸시·알림톡 대상 — 정회원 전원 (등록자 본인 포함)
  /// FCM 토큰 키(로그인 ID)로 맞춰서 m_creator_* 명단 ID로는 보내지 않는다.
  List<String> _scheduleBroadcastUserIds() {
    final ids = <String>{
      for (final m in regularMembers) m.id,
    };
    final me = currentMember?.id ?? currentUserId;
    if (me.trim().isNotEmpty) ids.add(me);
    return {
      for (final id in ids)
        if (_fcmInboxIdFor(id).isNotEmpty) _fcmInboxIdFor(id),
    }.toList();
  }

  /// 라운딩 후기/메모 저장
  void saveReviewMemo(String scheduleId, String memo) {
    final idx = _schedules.indexWhere((s) => s.id == scheduleId);
    if (idx == -1) return;
    _schedules[idx] = _schedules[idx].copyWith(
      reviewMemo: memo,
      clearReviewMemo: memo.trim().isEmpty,
    );
    notifyListeners();
    _persistImmediately();
  }

  /// 미응답 회원 목록
  List<Member> nonRespondersFor(String scheduleId) {
    final s = scheduleById(scheduleId);
    if (s == null) return const [];
    final responded = s.responses.map((r) => r.memberId).toSet();
    return activeMembers.where((m) => !responded.contains(m.id)).toList();
  }

  /// 미응답자에게 참석 요청 알림 (mock)
  int notifyNonResponders(String scheduleId) {
    final s = scheduleById(scheduleId);
    if (s == null) return 0;
    final targets = nonRespondersFor(scheduleId);
    for (final m in targets) {
      addAppNotification(AppNotification(
        id: 'noti_rsvp_${scheduleId}_${m.id}_${DateTime.now().millisecondsSinceEpoch}',
        type: AppNotificationType.announcement,
        clubId: s.clubId,
        clubName: selectedClub.name,
        title: '참석 응답 요청',
        body: '${s.displayTitle} 참석 여부를 아직 응답하지 않았습니다.',
        createdAt: DateTime.now(),
        targetUserId: m.id,
        isRead: false,
      ));
    }
    final idx = _schedules.indexWhere((x) => x.id == scheduleId);
    if (idx != -1) {
      _schedules[idx] = _schedules[idx].copyWith(deadlineNotified: true);
    }
    notifyListeners();
    _persistImmediately();
    return targets.length;
  }

  /// 대기 제안 수락/거절
  void respondToWaitingOffer(String waitingId, {required bool accept}) {
    final idx = _waitingList.indexWhere((w) => w.id == waitingId);
    if (idx == -1) return;
    final w = _waitingList[idx];
    if (accept) {
      final ok = respondToSchedule(scheduleId: w.scheduleId, response: '참석');
      if (!ok) return;
      _waitingList[idx] = WaitingEntry(
        id: w.id,
        scheduleId: w.scheduleId,
        memberId: w.memberId,
        memberName: w.memberName,
        registeredAt: w.registeredAt,
        status: WaitingStatus.accepted,
        notifiedAt: w.notifiedAt,
      );
    } else {
      _waitingList.removeAt(idx);
      notifyFirstWaiting(w.scheduleId);
    }
    notifyListeners();
    _persistImmediately();
  }

  /// 오프라인 mock — 실시간 동기화 스텁 (Firestore 연동 시 교체)
  void startSchedulesRealtimeSync(String clubId) {}
  void startWaitingListRealtimeSync(String scheduleId) {}
  void stopWaitingListRealtimeSync(String scheduleId) {}
  void syncWaitingListFromFirestore(String scheduleId) {}

  /// 일정 알림톡 발송 시뮬레이션
  int sendScheduleAlimtalk({
    required String scheduleId,
    required List<String> memberIds,
  }) {
    final s = scheduleById(scheduleId);
    if (s == null) return 0;
    for (final id in memberIds) {
      addAppNotification(AppNotification(
        id: 'noti_alim_${scheduleId}_${id}_${DateTime.now().millisecondsSinceEpoch}',
        type: AppNotificationType.announcement,
        clubId: s.clubId,
        clubName: selectedClub.name,
        title: '일정 알림',
        body: '${s.displayTitle} · ${s.courseName} ${s.teeTime}',
        createdAt: DateTime.now(),
        targetUserId: id,
        isRead: false,
      ));
    }
    notifyListeners();
    return memberIds.length;
  }

  // ════════════════════════════════════════════════════════
  //  Actions — Alimtalk (mock)
  // ════════════════════════════════════════════════════════

  final Map<String, ClubAlimtalkSettings> _alimtalkSettings = {};

  ClubAlimtalkSettings alimtalkSettingsOf(String clubId) =>
      _alimtalkSettings[clubId] ??
      ClubAlimtalkSettings(clubId: clubId);

  /// 선택 모임 생성자 여부 (user_me ↔ m1 별칭 포함)
  bool get isSelectedClubCreator {
    if (_myClubs.isEmpty) return false;
    final cid = selectedClub.creatorId;
    if (cid.isEmpty) return false;
    return _userIdsMatch(cid, currentUserId) ||
        (_persistAuthUserId != null &&
            _userIdsMatch(cid, _persistAuthUserId));
  }

  /// 선택 모임에서의 총무 여부 — 재무(회비) 전용 권한
  /// Club.myRole과 회원 명단 role이 어긋난 경우(직책 수정·인수인계)도 허용
  bool get isTreasurer =>
      ClubMemberRole.isTreasurer(selectedClub.myRole) ||
      ClubMemberRole.isTreasurer(currentMember?.role ?? '');

  /// 모임 정보 수정 가능 (회장·부회장·총무)
  bool get canEditClubInfo => isClubExecutive;

  /// 선택 모임 운영진 여부 (회장·부회장·총무).
  /// Club.myRole 우선, 회원 직책과 불일치 시 member.role로 보정.
  bool get isClubExecutive =>
      ClubMemberRole.isOfficer(selectedClub.myRole) ||
      ClubMemberRole.isOfficer(currentMember?.role ?? '');

  /// 일정 등록 가능 (회장·부회장·총무, 복합 직책 포함)
  bool get canCreateSchedule => isClubExecutive;

  bool get canConfigureAlimtalk => isClubExecutive;

  /// 현재 로그인한 사용자가 해당 모임의 '게스트' 회원인지 여부.
  /// 게스트는 재무(회비) 관련 정보 열람 및 재무 탭 진입 권한이 없다.
  bool get isGuestMember => currentMember?.memberType == '게스트';

  void updateAlimtalkSettings(
    String clubId, {
    bool? promptOnScheduleUpload,
    bool? promptOnGroupFinalize,
    bool? promptOnScheduleChange,
  }) {
    final current = alimtalkSettingsOf(clubId);
    _alimtalkSettings[clubId] = current.copyWith(
      promptOnScheduleUpload: promptOnScheduleUpload,
      promptOnGroupFinalize: promptOnGroupFinalize,
      promptOnScheduleChange: promptOnScheduleChange,
    );
    notifyListeners();
    _persistImmediately();
  }

  /// 모임 로컬 알림톡 on/off (본사 카탈로그는 변경하지 않음)
  bool isClubAlimtalkTypeEnabled(String clubId, String typeId) =>
      alimtalkSettingsOf(clubId).isTypeEnabledLocally(typeId);

  void setClubAlimtalkTypeEnabled(
    String clubId,
    String typeId,
    bool enabled,
  ) {
    final current = alimtalkSettingsOf(clubId);
    _alimtalkSettings[clubId] = current.withTypeEnabled(typeId, enabled);
    notifyListeners();
    _persistImmediately();
  }

  /// 일정 변경 알림톡 대상 — 전체 정회원 + 참석 게스트
  List<String> scheduleChangeAlimtalkRecipientNames(String scheduleId) {
    final names = <String>{
      for (final m in regularMembers) m.name,
    };
    final schedule =
        _schedules.where((s) => s.id == scheduleId).firstOrNull;
    if (schedule != null) {
      final guestIds = {
        for (final m in guestMembers) m.id,
      };
      for (final r in schedule.responses) {
        if (r.response == '참석' && guestIds.contains(r.memberId)) {
          names.add(r.memberName);
        }
      }
    }
    return names.toList();
  }

  /// (레거시) 이전 응답자 목록 기반 — 호환용
  List<String> scheduleChangeAlimtalkRecipientNamesFromResponses(
          List<AttendanceResponse> priorResponses) =>
      priorResponses.map((r) => r.memberName).toList();

  /// 참석여부 알림톡 대상 — 정회원 전원 (등록자 본인 포함, 게스트 제외)
  List<Member> attendanceAlimtalkRecipients() {
    final list = List<Member>.from(regularMembers);
    final me = currentMember;
    if (me != null && list.every((m) => m.id != me.id)) {
      list.add(me);
    }
    return list;
  }

  /// 조편성 알림톡 대상 — 참석 응답자 (정회원·게스트 구분 없음)
  List<AttendanceResponse> groupAlimtalkRecipients(String scheduleId) {
    final schedule = _schedules.where((s) => s.id == scheduleId).firstOrNull;
    if (schedule == null) return [];
    return schedule.responses
        .where((r) => r.response == '참석')
        .toList();
  }

  /// 참석여부 알림톡 대상 — 정회원 전원 (등록자 본인 포함, 게스트 제외)
  /// (발송은 [sendClubAlimtalk] / 알림톡 발송 화면)
  int sendAttendanceAlimtalk(String scheduleId) =>
      attendanceAlimtalkRecipients().length;

  /// 조편성 알림톡 대상 수
  int sendGroupAssignmentAlimtalk(String scheduleId) =>
      groupAlimtalkRecipients(scheduleId).length;

  List<Member> groupAlimtalkRecipientMembers(String scheduleId) {
    final byId = {for (final m in _members) m.id: m};
    final out = <Member>[];
    for (final r in groupAlimtalkRecipients(scheduleId)) {
      final m = byId[r.memberId];
      if (m != null) out.add(m);
    }
    return out;
  }

  List<Member> scheduleChangeAlimtalkRecipients(String scheduleId) {
    final out = <Member>[...regularMembers];
    final seen = {for (final m in out) m.id};
    final schedule =
        _schedules.where((s) => s.id == scheduleId).firstOrNull;
    if (schedule == null) return out;
    final guestById = {for (final m in guestMembers) m.id: m};
    for (final r in schedule.responses) {
      if (r.response != '참석') continue;
      final g = guestById[r.memberId];
      if (g == null || seen.contains(g.id)) continue;
      seen.add(g.id);
      out.add(g);
    }
    return out;
  }

  Future<SolapiResult> sendClubAlimtalk({
    required String hqTypeId,
    required List<Member> members,
    required Map<String, String> Function(Member member) variablesFor,
  }) async {
    if (!isClubAlimtalkTypeEnabled(selectedClub.id, hqTypeId)) {
      return SolapiResult.error('이 모임에서 해당 알림톡이 꺼져 있습니다.');
    }
    final templateId =
        SolapiService.templateIdForHqType(hqTypeId)?.trim() ?? '';
    if (templateId.isEmpty) {
      return SolapiResult.error('알림톡 템플릿이 없습니다.');
    }
    final solapi = SolapiService.instance;
    if (!solapi.isConfigured) {
      return SolapiResult.error('SOLAPI API Key가 설정되지 않았습니다.');
    }
    if (!solapi.hasKakaoChannel) {
      return SolapiResult.error('카카오 채널(PFID)이 설정되지 않았습니다.');
    }
    final enabled = await HqAlimtalkCatalog.isGloballyEnabled(hqTypeId);
    if (!enabled) {
      return SolapiResult.error('본사에서 해당 알림톡이 사용중지입니다.');
    }
    final messages = <Map<String, dynamic>>[];
    for (final m in members) {
      final phone = SolapiService.normalizePhone(m.phone ?? '');
      if (phone.length < 10) continue;
      messages.add(solapi.buildAlimtalkMessage(
        to: phone,
        templateId: templateId,
        variables: variablesFor(m),
      ));
    }
    if (messages.isEmpty) {
      return SolapiResult.error('전화번호가 있는 발송 대상이 없습니다.');
    }
    final result = await solapi.sendManyRaw(messages);
    debugPrint(
      '[Alimtalk] $hqTypeId n=${messages.length} ok=${result.success} '
      '${result.errorMessage ?? ''}',
    );
    return result;
  }

  void _dispatchClubAlimtalk({
    required String hqTypeId,
    required List<Member> members,
    required Map<String, String> Function(Member member) variablesFor,
  }) {
    unawaited(sendClubAlimtalk(
      hqTypeId: hqTypeId,
      members: members,
      variablesFor: variablesFor,
    ));
  }

  List<String> attendanceAlimtalkRecipientNames() {
    final names = attendanceAlimtalkRecipients().map((m) => m.name).toList();
    final mine = currentUserName.trim();
    if (mine.isNotEmpty && !names.contains(mine)) {
      names.add(mine);
    }
    return names;
  }

  List<String> groupAlimtalkRecipientNames(String scheduleId) =>
      groupAlimtalkRecipients(scheduleId)
          .map((r) => r.memberName)
          .toList();

  /// 일정 수정
  /// 날짜·시간·코스·정원이 바뀌면 참석/대기/조편성을 초기화한다 (재참석 안내).
  /// 반환: 실질 변경(재참석·알림톡 대상) 여부. 제목·공지만 바뀌면 false.
  bool updateSchedule(RoundSchedule updated) {
    if (!canCreateSchedule) {
      debugPrint('[ClubProvider] updateSchedule blocked — not executive');
      return false;
    }
    final idx = _schedules.indexWhere((s) => s.id == updated.id);
    if (idx == -1) return false;

    final prev = _schedules[idx];
    final materialChanged = isMaterialScheduleChange(prev, updated);

    var next = updated;
    if (materialChanged) {
      next = updated.copyWith(responses: const []);
      _groupAssignments.remove(updated.id);
      _waitingList.removeWhere((w) => w.scheduleId == updated.id);
      unawaited(PushNotificationService.clearD1ForSchedule(updated.id));
      debugPrint(
        '[ClubProvider] updateSchedule reset attendance '
        'id=${updated.id} (date/time/course/capacity changed)',
      );
    }

    _schedules[idx] = next;
    _syncNextRound(next.clubId);
    notifyListeners();
    _persistImmediately();
    return materialChanged;
  }

  /// 날짜·시간·코스·정원 변경 여부 (제목·공지 제외)
  static bool isMaterialScheduleChange(RoundSchedule a, RoundSchedule b) =>
      !_isSameScheduleDay(a.roundDate, b.roundDate) ||
      a.teeTime != b.teeTime ||
      a.courseName.trim() != b.courseName.trim() ||
      (a.courseAddress ?? '').trim() != (b.courseAddress ?? '').trim() ||
      a.teamCount != b.teamCount ||
      a.effectiveCapacity != b.effectiveCapacity;

  static bool _isSameScheduleDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 일정에 딸린 사진 장수 — 취소 확인 화면에서 미리 알려 주기 위한 값
  int schedulePhotoCount(String scheduleId) {
    if (scheduleId.isEmpty) return 0;
    return _photos
        .where((p) =>
            p.scheduleId == scheduleId && !ClubOpsSync.isPhotoDeleted(p.id))
        .length;
  }

  /// 일정에 딸린 사진을 모두 삭제. 지운 장수 반환.
  ///
  /// 되돌릴 수 없다. 원격 문서까지 지우고 tombstone 을 남겨서
  /// watch/pull merge 가 다시 살려 놓지 않게 한다.
  /// 사진별 권한(`canDeletePhoto`)은 확인하지 않는다 — 일정 취소 자체가
  /// 임원 권한이고, 남의 사진만 남으면 정리가 반쪽이 된다.
  int _purgeSchedulePhotos(String scheduleId) {
    if (scheduleId.isEmpty) return 0;
    final targets =
        _photos.where((p) => p.scheduleId == scheduleId).toList();
    if (targets.isEmpty) return 0;
    for (final p in targets) {
      ClubOpsSync.markPhotoDeleted(p.id);
      final clubId = p.clubId;
      if (clubId.isNotEmpty) {
        unawaited(ClubOpsSync.deletePhotoDoc(clubId, p.id));
      }
    }
    final ids = targets.map((p) => p.id).toSet();
    _photos.removeWhere((p) => ids.contains(p.id));
    debugPrint(
      '[ClubProvider] purged ${targets.length} photos of schedule $scheduleId',
    );
    return targets.length;
  }

  /// 일정 취소. 딸린 사진도 함께 정리하고, 지운 사진 장수를 반환한다.
  int cancelSchedule(String scheduleId) {
    var purged = 0;
    final idx = _schedules.indexWhere((s) => s.id == scheduleId);
    if (idx != -1) {
      final schedule = _schedules[idx];
      notifyScheduleCancelled(schedule);
      unawaited(PushNotificationService.clearD1ForSchedule(scheduleId));
      _schedules[idx] = schedule.copyWith(status: ScheduleStatus.cancelled);
      // 사진 정리는 persist 전에 — 한 번의 push 로 일정·사진이 같이 반영된다.
      purged = _purgeSchedulePhotos(scheduleId);
      _syncNextRound(schedule.clubId);
      notifyListeners();
      _persistImmediately();
      final attendeeIds = {
        for (final r in schedule.responses)
          if (r.response == '참석') r.memberId,
      };
      final dateStr =
          '${schedule.roundDate.month}월 ${schedule.roundDate.day}일';
      final time = schedule.teeTime.trim();
      final when = time.isEmpty ? dateStr : '$dateStr $time';
      final place = schedule.courseName.trim().isEmpty
          ? '장소 미정'
          : schedule.courseName.trim();
      _dispatchClubAlimtalk(
        hqTypeId: HqAlimtalkCatalog.scheduleCancelId,
        members: _members
            .where((m) =>
                m.status == '활성' && attendeeIds.contains(m.id))
            .toList(),
        variablesFor: (_) => {
          '#{모임명}': selectedClub.name,
          '#{일정명}': schedule.displayTitle,
          '#{일시}': when,
          '#{장소}': place,
          '#{사유}': '일정이 취소되었습니다',
        },
      );
    }
    return purged;
  }

  /// 일정 취소(삭제) — 참석 회원 + 취소자(총무)에게 앱 푸시 알림 발송
  int notifyScheduleCancelled(RoundSchedule schedule) {
    final club = _myClubs.where((c) => c.id == schedule.clubId).firstOrNull ??
        _allClubs.where((c) => c.id == schedule.clubId).firstOrNull;
    final clubName = club?.name ?? '';
    final recipientIds = <String>{
      for (final r in schedule.responses)
        if (r.response == '참석') r.memberId,
    };
    final me = currentMember?.id ?? currentUserId;
    if (me.trim().isNotEmpty) recipientIds.add(me);
    var count = 0;
    for (final memberId in recipientIds) {
      final fcmId = _fcmInboxIdFor(memberId);
      if (fcmId.isEmpty) continue;
      addAppNotification(
        AppNotification(
          id: 'noti_cancel_${schedule.id}_${memberId}_${DateTime.now().millisecondsSinceEpoch}',
          type: AppNotificationType.scheduleCancelled,
          clubId: schedule.clubId,
          clubName: clubName,
          title: '일정이 취소되었습니다',
          body: '${schedule.displayTitle} 일정이 총무에 의해 취소되었습니다.',
          createdAt: DateTime.now(),
          targetId: schedule.id,
          targetUserId: fcmId,
        ),
        hqPushTypeId: HqPushCatalog.scheduleCancel,
        notifySelf: true,
      );
      count++;
    }
    return count;
  }

  /// 참석 응답 등록/수정.
  /// 정원 초과 참석은 false를 반환(대기 등록은 UI에서 처리).
  bool respondToSchedule({
    required String scheduleId,
    required String response, // '참석' | '불참'
    String? memo,
  }) {
    final idx = _schedules.indexWhere((s) => s.id == scheduleId);
    if (idx == -1) return false;
    final schedule = _schedules[idx];
    // 모임 내 회원 목록(activeMembers)과 동일한 id 기준으로 기록해야
    // 참석/미답변 집계 시 동일 인물이 두 번 잡히지 않음
    final myId = currentMember?.id ?? currentUserId;
    final prev = schedule.responses
        .where((r) => r.memberId == myId)
        .map((r) => r.response)
        .firstOrNull;

    if (response == '참석' &&
        prev != '참석' &&
        isAttendanceFull(scheduleId)) {
      return false;
    }

    final newResponse = AttendanceResponse(
      memberId: myId,
      memberName: currentUserName,
      response: response,
      memo: memo,
      respondedAt: DateTime.now(),
    );
    final existing = schedule.responses.indexWhere((r) => r.memberId == myId);
    final newResponses = List<AttendanceResponse>.from(schedule.responses);
    if (existing != -1) {
      newResponses[existing] = newResponse;
    } else {
      newResponses.add(newResponse);
    }
    _schedules[idx] = schedule.copyWith(responses: newResponses);

    // 참석으로 확정되면 대기 명단에서 수락 처리
    if (response == '참석') {
      _acceptWaitingIfAny(scheduleId, myId);
    } else {
      // 불참/미정으로 바꾸면 대기 신청도 취소
      _cancelWaitingIfAny(scheduleId, myId);
    }
    // 참석 → 불참으로 바뀌면 자리 생김 → 대기자 알림
    if (prev == '참석' && response == '불참') {
      notifyFirstWaiting(scheduleId);
      _notifyTreasurerIfDroppedFromGroup(
        scheduleId: scheduleId,
        memberId: myId,
        memberName: currentUserName,
        scheduleTitle: schedule.displayTitle,
      );
    }

    _syncAttendancePoints(
      memberId: myId,
      scheduleId: scheduleId,
      scheduleTitle: schedule.displayTitle,
      prev: prev,
      response: response,
    );

    // 활동 피드에 추가
    _activities.insert(0, ActivityItem(
      id: 'act_${DateTime.now().millisecondsSinceEpoch}',
      memberId: myId,
      memberName: currentUserName,
      activityType: 'attendance',
      description: '${schedule.title} $response',
      timestamp: DateTime.now(),
    ));
    notifyListeners();
    _persistImmediately();
    unawaited(PushNotificationService.syncD1Reminder(
      scheduleId: scheduleId,
      userId: _fcmInboxIdFor(myId),
      roundDate: schedule.roundDate,
      clubId: schedule.clubId,
      clubName: selectedClub.name,
      scheduleTitle: schedule.displayTitle,
      attending: response == '참석',
    ));
    return true;
  }

  /// 조편성에 들어 있던 회원이 불참으로 바꾸면 슬롯을 비우고 총무에게 알린다.
  void _notifyTreasurerIfDroppedFromGroup({
    required String scheduleId,
    required String memberId,
    required String memberName,
    required String scheduleTitle,
  }) {
    final assignment = _groupAssignments[scheduleId];
    if (assignment == null) return;
    final groupNo = assignment.groupOf(memberId);
    if (groupNo == null && !assignment.isFinalized) return;

    if (groupNo != null) {
      final groups = List<AssignGroup>.from(assignment.groups);
      for (var gi = 0; gi < groups.length; gi++) {
        final slots = List<GroupSlot>.from(groups[gi].slots);
        var changed = false;
        for (var si = 0; si < slots.length; si++) {
          if (slots[si].memberId == memberId) {
            slots[si] = const GroupSlot();
            changed = true;
          }
        }
        if (changed) {
          groups[gi] = groups[gi].copyWithSlots(slots);
        }
      }
      _groupAssignments[scheduleId] = assignment.copyWith(groups: groups);
    }

    final club = _myClubs.where((c) => c.id == selectedClub.id).firstOrNull ??
        selectedClub;
    final treasurerId = joinRequestNotifyTargetId(club.id);
    if (treasurerId == null || _userIdsMatch(treasurerId, memberId)) return;

    addAppNotification(AppNotification(
      id: 'noti_drop_${DateTime.now().millisecondsSinceEpoch}',
      type: AppNotificationType.attendanceChanged,
      clubId: club.id,
      clubName: club.name,
      title: '조편성 불참 변경',
      body: groupNo != null
          ? '$memberName님이 $scheduleTitle 조편성 ${groupNo}조에서 불참으로 변경했습니다.'
          : '$memberName님이 $scheduleTitle 참석을 불참으로 변경했습니다.',
      isAdmin: true,
      createdAt: DateTime.now(),
      targetId: scheduleId,
      targetUserId: treasurerId,
    ));
  }

  /// 총무 권한 — 특정 회원의 참석 상태를 강제로 변경하고 즉시 앱 푸시 알림 발송
  void adminSetAttendance({
    required String scheduleId,
    required String memberId,
    required String memberName,
    required String response, // '참석' | '불참'
  }) {
    final idx = _schedules.indexWhere((s) => s.id == scheduleId);
    if (idx == -1) return;
    final schedule = _schedules[idx];
    final newResponse = AttendanceResponse(
      memberId: memberId,
      memberName: memberName,
      response: response,
      respondedAt: DateTime.now(),
    );
    final existing = schedule.responses.indexWhere((r) => r.memberId == memberId);
    final prev = existing != -1 ? schedule.responses[existing].response : null;
    final newResponses = List<AttendanceResponse>.from(schedule.responses);
    if (existing != -1) {
      newResponses[existing] = newResponse;
    } else {
      newResponses.add(newResponse);
    }
    _schedules[idx] = schedule.copyWith(responses: newResponses);

    _syncAttendancePoints(
      memberId: memberId,
      scheduleId: scheduleId,
      scheduleTitle: schedule.displayTitle,
      prev: prev,
      response: response,
    );

    if (prev == '참석' && response == '불참') {
      notifyFirstWaiting(scheduleId);
      _notifyTreasurerIfDroppedFromGroup(
        scheduleId: scheduleId,
        memberId: memberId,
        memberName: memberName,
        scheduleTitle: schedule.displayTitle,
      );
    }

    final club = _myClubs.where((c) => c.id == schedule.clubId).firstOrNull ??
        _allClubs.where((c) => c.id == schedule.clubId).firstOrNull;

    addAppNotification(AppNotification(
      id: 'noti_att_${scheduleId}_${memberId}_${DateTime.now().millisecondsSinceEpoch}',
      type: AppNotificationType.attendanceChanged,
      clubId: schedule.clubId,
      clubName: club?.name ?? '',
      title: '참석 상태가 변경되었습니다',
      body: '총무에 의해 ${schedule.displayTitle} 일정의 참석 상태가 "$response"(으)로 변경되었습니다.',
      createdAt: DateTime.now(),
      targetId: scheduleId,
      targetUserId: memberId,
    ));

    _activities.insert(0, ActivityItem(
      id: 'act_${DateTime.now().millisecondsSinceEpoch}',
      memberId: memberId,
      memberName: memberName,
      activityType: 'attendance',
      description: '${schedule.title} $response (총무 변경)',
      timestamp: DateTime.now(),
    ));

    unawaited(PushNotificationService.syncD1Reminder(
      scheduleId: scheduleId,
      userId: _fcmInboxIdFor(memberId),
      roundDate: schedule.roundDate,
      clubId: schedule.clubId,
      clubName: club?.name ?? selectedClub.name,
      scheduleTitle: schedule.displayTitle,
      attending: response == '참석',
    ));

    notifyListeners();
    _persistImmediately();
  }

  /// Club의 다음 라운딩 정보를 가장 가까운 예정 일정으로 동기화
  void _syncNextRound(String clubId) {
    final upcoming = _schedules
        .where((s) =>
            s.clubId == clubId &&
            s.status == ScheduleStatus.upcoming &&
            !s.isDateOver)
        .toList()
      ..sort((a, b) => a.roundDate.compareTo(b.roundDate));
    final next = upcoming.isEmpty ? null : upcoming.first;
    for (final list in [_myClubs, _allClubs]) {
      final i = list.indexWhere((c) => c.id == clubId);
      if (i != -1) {
        list[i] = list[i].copyWith(
          nextRoundDate: next?.roundDate,
          nextRoundCourse: next?.courseName,
        );
      }
    }
  }

  /// 저장된 모임 목록 전체의 다음 라운딩 필드를 일정과 맞춤
  void _syncAllNextRounds() {
    final clubIds = {
      ..._myClubs.map((c) => c.id),
      ..._allClubs.map((c) => c.id),
    };
    for (final clubId in clubIds) {
      _syncNextRound(clubId);
    }
  }

  /// mock/저장 데이터에서 고정된 "N월" 제목을 실제 roundDate와 맞춤
  void _normalizeScheduleTitles() {
    for (var i = 0; i < _schedules.length; i++) {
      final schedule = _schedules[i];
      final fixed = schedule.displayTitle;
      if (fixed != schedule.title) {
        _schedules[i] = schedule.copyWith(title: fixed);
      }
    }
  }

  // ════════════════════════════════════════════════════════
  //  Getters — Activities / Attendance / Announcements
  // ════════════════════════════════════════════════════════
  List<ActivityItem> get activities =>
      _selectedHasLegacyMock ? _activities : [];

  AttendanceStatus get attendanceStatus => _attendanceStatus;

  /// 선택 모임의 공지사항 (신규 모임도 등록·조회 가능)
  List<Announcement> get announcements {
    final clubId = selectedClub.id;
    final list = _announcements.where((a) {
      if (a.clubId == clubId) return true;
      // 레거시 mock 공지(clubId 없음)는 데모 모임에서만 노출
      if (a.clubId == null && _selectedHasLegacyMock) return true;
      return false;
    }).toList();
    return List.unmodifiable(list);
  }

  // ─── 앱 알림 ───
  List<AppNotification> get appNotifications =>
      List.unmodifiable(_appNotifications);

  /// 현재 모임 관련 알림 (역할 필터 적용)
  List<AppNotification> notificationsForClub(String clubId) =>
      _appNotifications
          .where((n) => n.clubId == clubId && canSeeNotification(n))
          .toList();

  int get unreadNotificationCount =>
      _appNotifications.where((n) => !n.isRead && canSeeNotification(n)).length;

  static bool _isClubOfficer(String role) => ClubMemberRole.isOfficer(role);

  /// 활성 총무가 있는지 (가입 알림 라우팅용)
  bool hasActiveTreasurer([String? clubId]) {
    final cid = clubId ?? selectedClub.id;
    // mock 멤버 풀은 선택 모임 기준 — 해당 모임의 myRole에도 총무가 있으면 true
    final inMembers = _members
        .any((m) => m.status == '활성' && ClubMemberRole.isTreasurer(m.role));
    final clubRole = _myClubs
        .where((c) => c.id == cid)
        .map((c) => c.myRole)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);
    return inMembers ||
        (clubRole != null && ClubMemberRole.isTreasurer(clubRole));
  }

  /// 가입 신청 알림 수신 대상 memberId (총무 → 없으면 회장 → 생성자)
  String? joinRequestNotifyTargetId(String clubId) {
    final aliases = clubIdAliases(clubId);
    final pool = membersForClub(legacyClubIdFor(clubId))
        .where((m) => m.status == '활성')
        .toList();
    final treasurer = pool
        .where((m) => ClubMemberRole.isTreasurer(m.role))
        .firstOrNull;
    if (treasurer != null) return treasurer.id;

    final president = pool
        .where((m) => ClubMemberRole.hasRole(m.role, ClubMemberRole.president))
        .firstOrNull;
    if (president != null) return president.id;

    // 내 모임 myRole 기준
    final club = _myClubs.where((c) => aliases.contains(c.id)).firstOrNull ??
        _allClubs.where((c) => aliases.contains(c.id)).firstOrNull;
    if (club != null) {
      final want = hasActiveTreasurer(legacyClubIdFor(clubId))
          ? ClubMemberRole.treasurer
          : ClubMemberRole.president;
      if (club.myRole == want || ClubMemberRole.canApproveJoins(club.myRole)) {
        // 신청자가 아닌 총무/회장 계정으로 라우팅 — 생성자 id 우선
        if (club.creatorId.isNotEmpty) return club.creatorId;
        if (club.myRole == want) return currentUserId;
      }
      if (club.creatorId.isNotEmpty) return club.creatorId;
    }

    // Mock 저장소 생성자/총무
    final store = AppDependencies.instance.mockDataStore;
    if (store != null) {
      for (final key in aliases) {
        final c = store.clubById(key);
        if (c != null && c.creatorId.isNotEmpty) return c.creatorId;
        for (final m in store.membersOf(key)) {
          if (m.status == '활성' &&
              (ClubMemberRole.isTreasurer(m.role) ||
                  ClubMemberRole.hasRole(
                      m.role, ClubMemberRole.president))) {
            return m.id;
          }
        }
      }
    }
    return null;
  }

  /// 내 모임 기준으로 볼 수 있는 알림인지
  bool canSeeNotification(AppNotification n) {
    final aliases = clubIdAliases(n.clubId);
    final idx = _myClubs.indexWhere((c) => aliases.contains(c.id));

    // 가입 신청 알림 — 내 모임 임원 / 지정 수신자 / 생성자
    if (n.type == AppNotificationType.joinRequest) {
      if (n.targetUserId != null &&
          (_userIdsMatch(n.targetUserId, currentUserId) ||
              _userIdsMatch(n.targetUserId, _persistAuthUserId))) {
        return true;
      }
      if (idx == -1) {
        // 생성자인데 myClubs 동기화 전이면 생성자로 판정
        final created = _allClubs.any((c) =>
                aliases.contains(c.id) &&
                (_userIdsMatch(c.creatorId, currentUserId) ||
                    _userIdsMatch(c.creatorId, _persistAuthUserId))) ||
            _myClubs.any((c) =>
                aliases.contains(c.id) &&
                (_userIdsMatch(c.creatorId, currentUserId) ||
                    _userIdsMatch(c.creatorId, _persistAuthUserId)));
        return created;
      }
      return ClubMemberRole.canApproveJoins(_myClubs[idx].myRole);
    }

    // 본인 대상 알림(모임 초대 등) — 아직 모임에 없어도 표시·푸시 수신
    if (n.targetUserId != null && _isSelfTarget(n.targetUserId)) {
      return true;
    }

    if (idx == -1) return false;
    final role = _myClubs[idx].myRole;

    // 특정 회원 전용 알림 — 대상자가 아니면 숨김
    if (n.targetUserId != null) {
      return false;
    }

    // 입금 확인 요청 — 해당 모임 총무만
    if (n.type == AppNotificationType.paymentRequest) {
      return role == ClubMemberRole.treasurer;
    }

    // 기타 관리자 알림 — 임원진
    if (n.isAdmin) {
      return _isClubOfficer(role);
    }
    return true;
  }

  /// 내 모임 화면에서 표시 가능한 알림 (최신순)
  List<AppNotification> get visibleNotifications {
    final list = _appNotifications.where(canSeeNotification).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// 내 모임 화면 헤더 뱃지용 읽지 않은 알림 수
  int get visibleUnreadNotificationCount {
    final unread = _appNotifications
        .where((n) => !n.isRead && canSeeNotification(n))
        .length;
    if (unread > 0) return unread;
    // 가입 대기건이 알림 객체 없이 남아 있어도 뱃지 표시
    var pending = 0;
    for (final c in _myClubs) {
      if (!ClubMemberRole.canApproveJoins(c.myRole)) continue;
      pending += unreadNotificationCountFor(c.id);
    }
    return pending;
  }

  /// 현재 선택 모임의 읽지 않은 알림 수 (역할 필터 적용)
  /// 가입 대기건이 있는데 알림 객체가 비어 있으면 배지에 반영(최소 1)
  int unreadNotificationCountFor(String clubId) {
    final unread = _appNotifications
        .where((n) =>
            n.clubId == clubId && !n.isRead && canSeeNotification(n))
        .length;
    if (unread > 0) return unread;

    final idx = _myClubs.indexWhere((c) => c.id == clubId);
    if (idx == -1) return 0;
    if (!ClubMemberRole.canApproveJoins(_myClubs[idx].myRole)) return 0;

    // 메모리/공유 대기열에 신청이 있으면 배지 표시 (알림 유실 보정)
    final pending = pendingRequestsOf(clubId).length;
    if (pending > 0) return pending;
    final memPending = SharedJoinRequestStore.peekMemory()
        .where((r) =>
            _normalizeLegacyClubId(r.clubId) == clubId &&
            r.status == JoinRequestStatus.pending)
        .length;
    return memPending;
  }

  void markNotificationRead(String notifId) {
    final idx = _appNotifications.indexWhere((n) => n.id == notifId);
    if (idx == -1) return;
    _appNotifications[idx] = _appNotifications[idx].copyWith(isRead: true);
    notifyListeners();
  }

  void markAllNotificationsRead() {
    for (int i = 0; i < _appNotifications.length; i++) {
      if (!_appNotifications[i].isRead) {
        _appNotifications[i] = _appNotifications[i].copyWith(isRead: true);
      }
    }
    notifyListeners();
  }

  /// 특정 모임 알림 전체 읽음 (볼 수 있는 알림만)
  void markAllNotificationsReadForClub(String clubId) {
    for (int i = 0; i < _appNotifications.length; i++) {
      final n = _appNotifications[i];
      if (n.clubId == clubId &&
          !n.isRead &&
          canSeeNotification(n)) {
        _appNotifications[i] = n.copyWith(isRead: true);
      }
    }
    notifyListeners();
  }

  /// 내 모임 화면에서 볼 수 있는 알림 전체 읽음
  void markAllVisibleNotificationsRead() {
    for (int i = 0; i < _appNotifications.length; i++) {
      if (!_appNotifications[i].isRead &&
          canSeeNotification(_appNotifications[i])) {
        _appNotifications[i] =
            _appNotifications[i].copyWith(isRead: true);
      }
    }
    notifyListeners();
  }

  void addAppNotification(
    AppNotification n, {
    String? hqPushTypeId,
    bool notifySelf = false,
  }) {
    if (hqPushTypeId != null && !HqPushCatalog.isEnabledSync(hqPushTypeId)) {
      debugPrint('[Push] skipped disabled $hqPushTypeId');
      return;
    }
    _appNotifications.insert(0, n);
    final target = n.targetUserId;
    if (target != null && target.isNotEmpty) {
      final isSelf = _isSelfTarget(target);
      if (!isSelf || notifySelf) {
        final enqueueId = _fcmInboxIdFor(target);
        unawaited(PushNotificationService.enqueue(
          targetUserId: enqueueId,
          title: n.title,
          body: n.body,
          type: hqPushTypeId ?? n.type.name,
          clubId: n.clubId,
        ));
        if (notifySelf && isSelf) {
          unawaited(PushNotificationService.showLocal(
            title: n.title,
            body: n.body,
          ));
        }
      }
    }
    notifyListeners();
  }

  void _notifyHqPush({
    required String typeId,
    required List<String> userIds,
    required AppNotificationType appType,
    required String clubId,
    required String clubName,
    Map<String, String> vars = const {},
    String? targetId,
    bool isAdmin = false,
    bool notifySelf = false,
  }) {
    if (!HqPushCatalog.isEnabledSync(typeId)) return;
    final spec = HqPushCatalog.byIdSync(typeId);
    final title = HqPushCatalog.applyVars(spec?.defaultTitle ?? spec?.name ?? '라운더', vars);
    final body = HqPushCatalog.applyVars(spec?.defaultBody ?? '', vars);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final id in userIds) {
      if (id.trim().isEmpty) continue;
      final fcmId = _fcmInboxIdFor(id);
      if (fcmId.isEmpty) continue;
      addAppNotification(
        AppNotification(
          id: 'noti_${typeId}_${id}_$now',
          type: appType,
          clubId: clubId,
          clubName: clubName,
          title: title,
          body: body,
          isAdmin: isAdmin,
          createdAt: DateTime.now(),
          targetId: targetId,
          targetUserId: fcmId,
          isRead: false,
        ),
        hqPushTypeId: typeId,
        notifySelf: notifySelf,
      );
    }
  }

  /// 알림 1개 삭제
  void removeNotification(String notifId) {
    _appNotifications.removeWhere((n) => n.id == notifId);
    notifyListeners();
  }

  /// 읽은 알림 전체 삭제
  void deleteReadNotifications() {
    _appNotifications.removeWhere((n) => n.isRead);
    notifyListeners();
  }

  /// 모든 알림 삭제
  void clearAllNotifications() {
    _appNotifications.clear();
    notifyListeners();
  }

  /// 특정 모임 알림 전체 삭제 (볼 수 있는 알림만)
  void removeAllNotificationsForClub(String clubId) {
    _appNotifications
        .removeWhere((n) => n.clubId == clubId && canSeeNotification(n));
    notifyListeners();
  }

  /// 내 모임 화면에서 볼 수 있는 알림 전체 삭제
  void removeAllVisibleNotifications() {
    _appNotifications.removeWhere(canSeeNotification);
    notifyListeners();
  }

  // ════════════════════════════════════════════════════════
  //  Actions — Announcements (공지사항 CRUD)
  // ════════════════════════════════════════════════════════

  /// 공지사항 작성 (총무/부회장/회장) — 댓글은 addAnnouncementComment
  void addAnnouncement({required String title, String? content, bool pin = false}) {
    if (!isClubExecutive) {
      debugPrint('[ClubProvider] addAnnouncement blocked — not executive');
      return;
    }
    final id = 'ann_${DateTime.now().millisecondsSinceEpoch}';
    final authorId = currentMember?.id ?? currentUserId;
    _announcements.insert(
      0,
      Announcement(
        id: id,
        title: title,
        content: content,
        isPinned: pin,
        createdAt: DateTime.now(),
        clubId: selectedClub.id,
        authorId: authorId,
        authorName: currentUserName,
      ),
    );
    // 고정 공지는 맨 위
    _announcements.sort((x, y) {
      if (x.isPinned == y.isPinned) return y.createdAt.compareTo(x.createdAt);
      return x.isPinned ? -1 : 1;
    });
    notifyListeners();
    _persistImmediately();
  }

  bool isOwnAnnouncement(Announcement a) {
    final id = a.authorId;
    if (id != null && id.isNotEmpty && _isSelfTarget(id)) return true;
    final name = a.authorName?.trim() ?? '';
    return name.isNotEmpty && name == currentUserName.trim();
  }

  /// 공지 수정 — 작성자 또는 임원
  bool updateAnnouncement({
    required String id,
    required String title,
    String? content,
  }) {
    final idx = _announcements.indexWhere((a) => a.id == id);
    if (idx == -1) return false;
    final a = _announcements[idx];
    if (!isOwnAnnouncement(a) && !isClubExecutive) return false;
    _announcements[idx] = Announcement(
      id: a.id,
      title: title.trim(),
      content: content?.trim(),
      isPinned: a.isPinned,
      createdAt: a.createdAt,
      comments: a.comments,
      clubId: a.clubId,
      authorId: a.authorId ?? (currentMember?.id ?? currentUserId),
      authorName: a.authorName ?? currentUserName,
    );
    notifyListeners();
    _persistImmediately();
    return true;
  }

  /// 공지사항 삭제 — 작성자 또는 임원
  void deleteAnnouncement(String id) {
    final a = _announcements.where((e) => e.id == id).firstOrNull;
    if (a == null) return;
    if (!isOwnAnnouncement(a) && !isClubExecutive) {
      debugPrint('[ClubProvider] deleteAnnouncement blocked — not owner/executive');
      return;
    }
    _announcements.removeWhere((e) => e.id == id);
    notifyListeners();
    _persistImmediately();
  }

  /// 공지사항 상단고정 토글
  void toggleAnnouncementPin(String id) {
    final idx = _announcements.indexWhere((a) => a.id == id);
    if (idx == -1) return;
    final a = _announcements[idx];
    _announcements[idx] = Announcement(
      id: a.id,
      title: a.title,
      content: a.content,
      isPinned: !a.isPinned,
      createdAt: a.createdAt,
      comments: a.comments,
      clubId: a.clubId,
      authorId: a.authorId,
      authorName: a.authorName,
    );
    // 고정된 공지는 맨 위로
    _announcements.sort((x, y) {
      if (x.isPinned == y.isPinned) return y.createdAt.compareTo(x.createdAt);
      return x.isPinned ? -1 : 1;
    });
    notifyListeners();
    _persistImmediately();
  }

  /// 공지사항 댓글 작성 (+2 포인트, 중복 방지)
  /// Returns true if comment was added (first time for this announcement)
  bool addAnnouncementComment({
    required String announcementId,
    required String text,
  }) {
    final idx = _announcements.indexWhere((a) => a.id == announcementId);
    if (idx == -1) return false;
    final a = _announcements[idx];

    final pointMemberId = currentMember?.id ?? currentUserId;
    final newComment = AnnouncementComment(
      id: 'cmt_${DateTime.now().millisecondsSinceEpoch}',
      authorId: pointMemberId,
      authorName: currentUserName,
      text: text.trim(),
      createdAt: DateTime.now(),
    );

    // 댓글 추가
    final updatedComments = [...a.comments, newComment];
    _announcements[idx] = Announcement(
      id: a.id,
      title: a.title,
      content: a.content,
      isPinned: a.isPinned,
      createdAt: a.createdAt,
      comments: updatedComments,
      clubId: a.clubId,
      authorId: a.authorId,
      authorName: a.authorName,
    );

    // 첫 댓글인 경우에만 포인트 +2 (동일 공지에 중복 부여 방지)
    final alreadyCommented = a.comments.any((c) =>
        c.authorId == pointMemberId || c.authorId == currentUserId);
    if (!alreadyCommented) {
      addMembershipPoint(
        memberId: pointMemberId,
        type: MembershipPointType.commentActivity,
        points: 2,
        desc: '공지 참여 (+2): ${a.title}',
      );
    }

    // 댓글 알림: 관리자용 피드 (자신에게는 쌓이지 않도록 isRead:true로 처리)
    // 실제 앱에서는 FCM으로 다른 멤버에게 발송하지만, 여기선 조용히 기록만
    _appNotifications.insert(0, AppNotification(
      id: 'noti_cmt_${DateTime.now().millisecondsSinceEpoch}',
      type: AppNotificationType.comment,
      clubId: 'c1',
      clubName: '강남 골프회',
      title: '댓글',
      body: '$currentUserName님이 댓글을 달았습니다: ${text.length > 20 ? text.substring(0, 20) + '…' : text}',
      isAdmin: false,
      isRead: true, // 자신이 단 댓글은 이미 읽은 상태 → 뱃지 증가 없음
      createdAt: DateTime.now(),
      targetId: announcementId,
    ));

    notifyListeners();
    _persistImmediately();
    return !alreadyCommented; // 포인트 획득 여부 반환
  }

  bool isOwnAnnouncementComment(AnnouncementComment c) =>
      _isSelfTarget(c.authorId) ||
      (c.authorName.trim().isNotEmpty &&
          c.authorName.trim() == currentUserName.trim());

  /// 공지 댓글 수정 — 작성자만
  bool updateAnnouncementComment({
    required String announcementId,
    required String commentId,
    required String text,
  }) {
    final idx = _announcements.indexWhere((a) => a.id == announcementId);
    if (idx == -1) return false;
    final a = _announcements[idx];
    final ci = a.comments.indexWhere((c) => c.id == commentId);
    if (ci == -1) return false;
    final c = a.comments[ci];
    if (!isOwnAnnouncementComment(c)) return false;
    final next = List<AnnouncementComment>.from(a.comments);
    next[ci] = AnnouncementComment(
      id: c.id,
      authorId: c.authorId,
      authorName: c.authorName,
      text: text.trim(),
      createdAt: c.createdAt,
    );
    _announcements[idx] = Announcement(
      id: a.id,
      title: a.title,
      content: a.content,
      isPinned: a.isPinned,
      createdAt: a.createdAt,
      comments: next,
      clubId: a.clubId,
      authorId: a.authorId,
      authorName: a.authorName,
    );
    notifyListeners();
    _persistImmediately();
    return true;
  }

  /// 공지 댓글 삭제 — 작성자 또는 임원
  bool deleteAnnouncementComment({
    required String announcementId,
    required String commentId,
  }) {
    final idx = _announcements.indexWhere((a) => a.id == announcementId);
    if (idx == -1) return false;
    final a = _announcements[idx];
    final c = a.comments.where((e) => e.id == commentId).firstOrNull;
    if (c == null) return false;
    if (!isOwnAnnouncementComment(c) && !isClubExecutive) return false;
    _announcements[idx] = Announcement(
      id: a.id,
      title: a.title,
      content: a.content,
      isPinned: a.isPinned,
      createdAt: a.createdAt,
      comments: a.comments.where((e) => e.id != commentId).toList(),
      clubId: a.clubId,
      authorId: a.authorId,
      authorName: a.authorName,
    );
    notifyListeners();
    _persistImmediately();
    return true;
  }

  // ════════════════════════════════════════════════════════
  //  Actions — Club Selection
  // ════════════════════════════════════════════════════════
  void selectClub(int index) {
    _selectedClubIndex = index;
    if (index >= 0 && index < _myClubs.length) {
      _syncNextRound(_myClubs[index].id);
    }
    ensureCreatorMembers();
    _watchSelectedClubOps();
    notifyListeners();
  }

  /// id로 모임 선택 (ClubRoomScreen 진입 시)
  void selectClubById(String clubId) {
    final idx = _myClubs.indexWhere((c) => c.id == clubId);
    if (idx != -1) {
      _selectedClubIndex = idx;
      _syncNextRound(clubId);
      ensureCreatorMembers();
      _watchSelectedClubOps();
      notifyListeners();
    }
  }

  // ════════════════════════════════════════════════════════
  //  Actions — Create Club
  // ════════════════════════════════════════════════════════
  /// 반환: 어드민 저장소(Mock/Firestore) 동기화 성공 여부
  Future<bool> createClub({
    required String name,
    required String region,
    required String industry,
    required int teamCount,
    required String myRole,
    String description = '',
    String? imageUrl,
  }) async {
    final id = 'c_${DateTime.now().millisecondsSinceEpoch}';
    final authUserId = _persistAuthUserId ?? currentUserId;
    final roleEncoded = ClubMemberRole.encodeRoles(
      ClubMemberRole.splitRoles(myRole),
    );
    final newClub = Club(
      id: id,
      name: name,
      myRole: roleEncoded,
      memberCount: 1, // 생성자 본인
      region: region,
      industry: industry,
      teamCount: teamCount.clamp(1, 30),
      description: description,
      imageUrl: imageUrl,
      creatorId: authUserId,
      createdAt: DateTime.now(),
    );
    _myClubs.add(newClub);
    _allClubs.add(newClub);
    _freshClubIds.add(id);

    // 생성자를 해당 모임 회원으로 등록 (mock 시드 회원과 분리: m_creator_*)
    final creatorMember = Member(
      id: 'm_creator_$id',
      name: currentUserName,
      gender: '남',
      memberType: ClubMemberRole.memberTypeForRole(roleEncoded),
      role: roleEncoded,
      handicap: null,
      joinDate: DateTime.now(),
      status: '활성',
    );
    _members.add(creatorMember);

    // 플랫폼 가입자(어드민 오늘 가입) — 모임 생성자도 가입일로 잡히도록
    final storeForUser = AppDependencies.instance.mockDataStore;
    if (storeForUser != null) {
      final existing = storeForUser.appUsers
          .where((u) => u.id == authUserId)
          .firstOrNull;
      storeForUser.upsertAppUser(
        MockAppUser(
          id: authUserId,
          name: currentUserName,
          phone: existing?.phone ?? '',
          gender: existing?.gender ?? '남',
          createdAt: existing?.createdAt ?? DateTime.now(),
        ),
      );
    }

    // 어드민이 보는 저장소(Mock localStorage / Firestore)에 반드시 기록
    // — ClubProvider 메모리만 쓰면 앱에는 보이고 어드민에는 안 보이는 분열이 난다.
    var adminSynced = false;
    Object? syncError;
    try {
      if (AppDependencies.instance.isOfflineMockMode) {
        final store = AppDependencies.instance.mockDataStore;
        if (store != null) {
          await AppDependencies.instance.clubRepository.createClub(
            club: newClub,
            userId: authUserId,
            userName: currentUserName,
            creatorMember: creatorMember,
            moderationStatus: 'active',
          );
          store.setMemberClubCountOverride(
            _persistAuthUserId ?? 'user_me',
            _myClubs.length,
          );
          store.setMemberClubCountOverride('user_me', _myClubs.length);
          store.setMemberClubCountOverride('m1', _myClubs.length);
          await MockStorePersistence.save(store);
          store.bump(persist: false);
          adminSynced = true;
        }
      } else {
        await FirebaseAuthBridge.ensureStagingSession(userId: authUserId);
        await AppDependencies.instance.clubRepository.createClub(
          club: newClub,
          userId: authUserId,
          userName: currentUserName,
          creatorMember: creatorMember,
          moderationStatus: 'active',
        );
        adminSynced = true;
      }
    } catch (e, st) {
      syncError = e;
      debugPrint('[ClubProvider] admin sync createClub failed: $e\n$st');
    }

    _selectedClubIndex = _myClubs.length - 1;
    notifyListeners();
    _persistImmediately();

    if (!adminSynced && syncError != null) {
      debugPrint('[ClubProvider] createClub local-only (admin sync failed)');
    }
    return adminSynced;
  }

  /// 내 모임(데모 c1~c5 제외)에 생성자 회원이 없으면 복구. 변경 여부 반환.
  bool ensureCreatorMembers() {
    var changed = false;
    for (final club in _myClubs) {
      if (_legacyMockClubIds.contains(club.id)) continue;
      _freshClubIds.add(club.id);
      final existing = membersForClub(club.id);
      final iAmCreator = club.creatorId.isEmpty ||
          _userIdsMatch(club.creatorId, currentUserId) ||
          (_persistAuthUserId != null &&
              _userIdsMatch(club.creatorId, _persistAuthUserId));

      if (existing.isNotEmpty) {
        if (club.memberCount != existing.length) {
          _setMemberCount(club.id, existing.length);
          changed = true;
        }
        if (ensureMyRosterRow(club.id)) changed = true;
        continue;
      }

      // 초대 가입자는 명단이 비어 있어도 생성자 행을 만들면 안 된다.
      if (!iAmCreator) {
        if (ensureMyRosterRow(club.id)) changed = true;
        continue;
      }

      final creatorId = 'm_creator_${club.id}';
      final role = ClubMemberRole.normalize(club.myRole);
      _members.add(Member(
        id: creatorId,
        name: currentUserName,
        gender: '남',
        memberType: ClubMemberRole.memberTypeForRole(role),
        role: role,
        handicap: null,
        joinDate: club.createdAt,
        status: '활성',
      ));
      _setMemberCount(club.id, 1);
      try {
        AppDependencies.instance.mockDataStore?.addMember(
          clubId: club.id,
          member: _members.last,
          bumpCount: false,
        );
        AppDependencies.instance.mockDataStore?.upsertClub(
          _myClubs.firstWhere((c) => c.id == club.id),
          moderationStatus: AppDependencies.instance.mockDataStore
                  ?.clubModerationStatusOrNull(club.id) ??
              'active',
        );
      } catch (_) {}
      changed = true;
    }
    if (changed) _persistImmediately();
    return changed;
  }

  /// 초대 가입이 userId 그대로 들어가 명단에 안 보이던 행을 `m_{clubId}_{userId}`로 보정한다.
  bool ensureMyRosterRow(String clubId) {
    final uid = currentUserId.trim();
    if (uid.isEmpty || _legacyMockClubIds.contains(clubId)) return false;
    final rid = Member.rosterId(clubId, uid);
    if (_members.any((m) => m.id == rid)) return false;

    final club = _myClubs.where((c) => c.id == clubId).firstOrNull;
    final iAmCreator = club != null &&
        (club.creatorId.isEmpty ||
            _userIdsMatch(club.creatorId, uid) ||
            (_persistAuthUserId != null &&
                _userIdsMatch(club.creatorId, _persistAuthUserId)));
    if (iAmCreator && _members.any((m) => m.id == 'm_creator_$clubId')) {
      return false;
    }

    final orphan = _members.where((m) => m.id == uid).firstOrNull;
    final role = ClubMemberRole.normalize(
      club?.myRole ?? ClubMemberRole.regular,
    );
    _members.add(Member(
      id: rid,
      name: orphan?.name ?? currentUserName,
      gender: orphan?.gender ?? '남',
      memberType: ClubMemberRole.memberTypeForRole(role),
      role: role,
      phone: orphan?.phone,
      handicap: orphan?.handicap,
      joinDate: orphan?.joinDate ?? DateTime.now(),
      status: '활성',
      referrerId: orphan?.referrerId,
      referrerName: orphan?.referrerName,
    ));
    _members.removeWhere((m) => m.id == uid);
    return true;
  }

  void _setMemberCount(String clubId, int count) {
    final i1 = _myClubs.indexWhere((c) => c.id == clubId);
    if (i1 != -1) {
      _myClubs[i1] = _myClubs[i1].copyWith(memberCount: count);
    }
    final i2 = _allClubs.indexWhere((c) => c.id == clubId);
    if (i2 != -1) {
      _allClubs[i2] = _allClubs[i2].copyWith(memberCount: count);
    }
  }

  // ════════════════════════════════════════════════════════
  //  Actions — Update Club teamCount (매달 변경)
  // ════════════════════════════════════════════════════════
  void updateClubTeamCount(String clubId, int teamCount) {
    updateClubInfo(clubId: clubId, teamCount: teamCount);
  }

  /// 모임 기본 정보 수정 (이름·소개·이미지·팀 수)
  void updateClubInfo({
    required String clubId,
    String? name,
    String? description,
    String? imageUrl,
    int? teamCount,
  }) {
    void apply(List<Club> list) {
      final idx = list.indexWhere((c) => c.id == clubId);
      if (idx == -1) return;
      list[idx] = list[idx].copyWith(
        name: name,
        description: description,
        imageUrl: imageUrl,
        teamCount: teamCount,
      );
    }

    apply(_myClubs);
    apply(_allClubs);
    notifyListeners();
    _persistImmediately();
  }

  // ════════════════════════════════════════════════════════
  //  Actions — Join Request
  // ════════════════════════════════════════════════════════
  Future<bool> submitJoinRequest({
    required String clubId,
    String message = '',
    // 초대 경로에서 신규 가입자 정보를 직접 전달할 때 사용
    String? userId,
    String? userName,
    double? handicap,
    // 게스트 가입 시 추천인(소개자)
    String? referrerId,
    String? referrerName,
  }) async {
    // 이미 내 모임이면 신청 불가 (탈퇴 잔존/시드 재투입 가드)
    if (isMyClub(clubId)) {
      debugPrint('[ClubProvider] submitJoinRequest blocked — already in $clubId');
      return false;
    }
    final req = JoinRequest(
      id: 'jr_${DateTime.now().millisecondsSinceEpoch}',
      clubId: clubId,
      userId: userId ?? currentUserId,
      userName: userName ?? currentUserName,
      userGender: '남',
      userHandicap: handicap ?? 12.0,
      message: message,
      referrerId: referrerId,
      referrerName: referrerName,
      requestedAt: DateTime.now(),
    );
    // 총무 계정에 먼저 공유 (신청자 persist 레이스보다 우선)
    try {
      await SharedJoinRequestStore.upsert(req);
    } catch (e) {
      debugPrint('[ClubProvider] shared join upsert early failed: $e');
    }
    _joinRequests.add(req);

    // 활동 피드에 가입 신청 기록
    _activities.insert(0, ActivityItem(
      id: 'act_join_${DateTime.now().millisecondsSinceEpoch}',
      memberId: userId ?? currentUserId,
      memberName: userName ?? currentUserName,
      activityType: 'join',
      description: '가입 신청 (승인 대기 중)',
      timestamp: DateTime.now(),
    ));

    // 가입 신청 알림 — 총무 우선, 없으면 방장(회장)
    final club = _allClubs.where((c) => c.id == clubId).firstOrNull ??
        _myClubs.where((c) => c.id == clubId).firstOrNull;
    final notifyTarget = joinRequestNotifyTargetId(clubId);
    final notifyRole = hasActiveTreasurer(clubId)
        ? ClubMemberRole.treasurer
        : ClubMemberRole.president;
    final noti = AppNotification(
      id: 'noti_jr_${req.id}',
      type: AppNotificationType.joinRequest,
      clubId: clubId,
      clubName: club?.name ?? '모임',
      isAdmin: true,
      title: '가입 신청',
      body: '${req.userName}님이 가입을 신청했습니다 → $notifyRole 수신',
      createdAt: DateTime.now(),
      targetId: req.id,
      targetUserId: notifyTarget,
      isRead: false,
    );
    addAppNotification(
      noti,
      hqPushTypeId: HqPushCatalog.joinRequest,
      notifySelf: true,
    );

    // 계정 전환과 무관한 공유 대기열 + 총무 계정 번들에 즉시 전달
    final store = AppDependencies.instance.mockDataStore;
    store?.upsertPendingJoinRequest(req);
    notifyListeners();
    _persistImmediately();
    await _publishJoinRequestCrossAccount(req, noti);
    return true;
  }

  /// 초대 링크 수락 — 총무 승인 없이 즉시 가입 (밴드형)
  Future<bool> joinViaInvite({
    required String clubId,
    String? clubName,
    bool asGuest = false,
    String? referrerId,
    String? referrerName,
    String? displayName,
  }) async {
    if (clubId.trim().isEmpty || clubId == 'unknown') {
      debugPrint('[ClubProvider] joinViaInvite blocked — invalid clubId');
      return false;
    }
    final userId = currentUserId;
    final userName = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : currentUserName;
    final role = asGuest ? ClubMemberRole.guest : ClubMemberRole.regular;
    final memberType =
        asGuest ? ClubMemberRole.guest : ClubMemberRole.regular;
    final rosterId = Member.rosterId(clubId, userId);

    Club? club = _myClubs.where((c) => c.id == clubId).firstOrNull ??
        _allClubs.where((c) => c.id == clubId).firstOrNull ??
        AppDependencies.instance.mockDataStore?.clubById(clubId);

    if (club == null) {
      try {
        club = await AppDependencies.instance.clubRepository
            .fetchClubById(clubId, userId: userId);
      } catch (e) {
        debugPrint('[ClubProvider] joinViaInvite fetchClub skip: $e');
      }
    }

    final resolvedName = (clubName != null && clubName.trim().isNotEmpty)
        ? clubName.trim()
        : (club?.name ?? '모임');

    club ??= Club(
      id: clubId,
      name: resolvedName,
      myRole: role,
      memberCount: 1,
      creatorId: '',
      createdAt: DateTime.now(),
    );

    if (!_legacyMockClubIds.contains(clubId)) {
      _freshClubIds.add(clubId);
    }

    final member = Member(
      id: rosterId,
      name: userName,
      gender: '남',
      memberType: memberType,
      role: role,
      joinDate: DateTime.now(),
      status: '활성',
      referrerId: referrerId,
      referrerName: referrerName,
    );

    // 예전 초대 가입은 userId 그대로 넣어서 명단 필터에 안 걸렸다. 고쳐서 다시 넣는다.
    _members.removeWhere((m) => m.id == userId);

    final alreadyListed = _members.any((m) => m.id == rosterId);
    if (!alreadyListed) {
      _members.add(member);
    }
    try {
      AppDependencies.instance.mockDataStore?.addMember(
        clubId: clubId,
        member: member,
        alsoAsIds: [userId],
        bumpCount: !alreadyListed,
      );
    } catch (_) {}

    if (isMyClub(clubId) && alreadyListed) {
      debugPrint('[ClubProvider] joinViaInvite — already member of $clubId');
      notifyListeners();
      _persistImmediately();
      return true;
    }

    final joinedClub = club.copyWith(
      name: resolvedName,
      myRole: role,
      memberCount: club.memberCount + (alreadyListed ? 0 : 1),
    );
    if (!_myClubs.any((c) => c.id == clubId)) {
      _myClubs.add(joinedClub);
    } else {
      final i = _myClubs.indexWhere((c) => c.id == clubId);
      if (i != -1) _myClubs[i] = _myClubs[i].copyWith(myRole: role);
    }
    if (!_allClubs.any((c) => c.id == clubId)) {
      _allClubs.add(joinedClub);
    }

    _activities.insert(
      0,
      ActivityItem(
        id: 'act_invite_${DateTime.now().millisecondsSinceEpoch}',
        memberId: userId,
        memberName: userName,
        activityType: 'join',
        description: asGuest ? '초대 링크로 게스트 가입' : '초대 링크로 즉시 가입',
        timestamp: DateTime.now(),
      ),
    );

    // 운영진에게 알림 (승인 요청이 아님)
    final notifyTarget = joinRequestNotifyTargetId(clubId);
    addAppNotification(
      AppNotification(
        id: 'noti_invite_join_${clubId}_$userId',
        type: AppNotificationType.announcement,
        clubId: clubId,
        clubName: resolvedName,
        isAdmin: true,
        title: '초대 가입',
        body: '$userName님이 초대 링크로 가입했습니다',
        createdAt: DateTime.now(),
        targetId: clubId,
        targetUserId: notifyTarget,
        isRead: false,
      ),
      notifySelf: true,
    );

    try {
      await AppDependencies.instance.clubRepository.addMemberViaInvite(
        clubId: clubId,
        userId: userId,
        member: member,
      );
    } catch (e) {
      debugPrint('[ClubProvider] joinViaInvite remote skip: $e');
    }

    notifyListeners();
    _persistImmediately();
    return true;
  }

  /// 총무 화면 진입 시 호출 — 공유 대기열 → 알림 강제 동기화
  Future<void> refreshJoinRequestInbox() async {
    await mergeSharedJoinRequests();
    // 이미 _joinRequests에만 있고 알림이 없는 건도 보정
    for (final req in List<JoinRequest>.from(_joinRequests)) {
      if (req.status == JoinRequestStatus.pending) {
        _ingestPendingJoinRequest(req);
      }
    }
    notifyListeners();
    _persistImmediately();
  }

  /// 내가 넣은 가입 신청 취소 (seed↔legacy · user alias 포함)
  Future<bool> cancelMyPendingJoinRequest(String clubId) async {
    final clubs = clubIdAliases(clubId);
    final pending = _joinRequests
        .where((r) =>
            clubs.contains(r.clubId) &&
            r.status == JoinRequestStatus.pending &&
            (_userIdsMatch(r.userId, currentUserId) ||
                _userIdsMatch(r.userId, _persistAuthUserId)))
        .toList();
    if (pending.isEmpty) {
      // 스토어에만 있을 수 있음
      try {
        await AppDependencies.instance.joinRequestRepository.cancelJoinRequest(
          clubId: legacyClubIdFor(clubId),
          requestId: '',
          userId: _persistAuthUserId ?? currentUserId,
        );
      } catch (_) {
        return false;
      }
      notifyListeners();
      return true;
    }
    for (final req in pending) {
      _joinRequests.removeWhere((r) => r.id == req.id);
      _appNotifications.removeWhere(
        (n) =>
            n.type == AppNotificationType.joinRequest && n.targetId == req.id,
      );
      try {
        await SharedJoinRequestStore.remove(req.id);
      } catch (_) {}
      try {
        await AppDependencies.instance.joinRequestRepository.cancelJoinRequest(
          clubId: req.clubId,
          requestId: req.id,
          userId: req.userId,
        );
      } catch (_) {}
      AppDependencies.instance.mockDataStore
          ?.removePendingJoinRequest(req.id, persist: true);
    }
    notifyListeners();
    _persistImmediately();
    return true;
  }

  Future<void> _publishJoinRequestCrossAccount(
    JoinRequest req,
    AppNotification noti,
  ) async {
    try {
      await SharedJoinRequestStore.upsert(req);
    } catch (e) {
      debugPrint('[ClubProvider] shared join upsert failed: $e');
    }

    // 총무/회장 테스트 계정 번들에 직접 기록 (switchUser 로드 시 바로 보이도록)
    for (final authId in const ['user_me', 'user_guest', 'user_other']) {
      if (authId == _persistAuthUserId) continue;
      try {
        await _fanoutJoinRequestToAccount(authId, req, noti);
      } catch (e) {
        debugPrint('[ClubProvider] fanout join to $authId failed: $e');
      }
    }

    // Firestore/Mock 리포지토리에도 기록 (가능하면)
    try {
      await AppDependencies.instance.joinRequestRepository.submitJoinRequest(
        clubId: req.clubId,
        userId: req.userId,
        userName: req.userName,
        userGender: req.userGender,
        userHandicap: req.userHandicap,
        message: req.message,
      );
    } catch (e) {
      debugPrint('[ClubProvider] joinRequestRepository submit skip: $e');
    }
  }

  Future<void> _fanoutJoinRequestToAccount(
    String authUserId,
    JoinRequest req,
    AppNotification noti,
  ) async {
    var saved = await ClubPersistence.load(authUserId);

    final clubId = _normalizeLegacyClubId(req.clubId);

    // 총무 계정이 아직 한 번도 저장되지 않았으면 템플릿 모임으로 시드 후 기록
    // (빈 템플릿으로 저장하면 사용자가 만든 c_* 모임이 영구 유실되므로 금지)
    if (saved == null) {
      final templates = switch (authUserId) {
        'user_guest' => _guestClubs,
        'user_other' => _otherMemberClubs,
        _ => _adminClubs,
      };
      if (templates.isEmpty) return;
      final club = templates.where((c) => c.id == clubId).firstOrNull;
      if (club == null) return;
      final role = ClubMemberRole.normalize(club.myRole);
      if (!ClubMemberRole.canApproveJoins(role)) return;

      saved = ClubDataBundle(
        selectedClubIndex: 0,
        freshClubIds: {},
        myClubs: List<Club>.from(templates),
        allClubs: List<Club>.from(_allClubs),
        joinRequests: [req],
        members: const [],
        activities: const [],
        announcements: const [],
        appNotifications: [
          AppNotification(
            id: noti.id,
            type: noti.type,
            clubId: clubId,
            clubName: club.name,
            title: noti.title,
            body: noti.body,
            isAdmin: true,
            isRead: false,
            createdAt: noti.createdAt,
            targetId: noti.targetId,
            targetUserId: noti.targetUserId,
          ),
        ],
        duesSettings: const [],
        duesPayments: const [],
        paymentRequests: const [],
        transactions: const [],
        schedules: const [],
        photos: const [],
        groupAssignments: const {},
        adApplications: const [],
        adNotifications: const [],
        sponsorApplications: const [],
        pointEvents: const {},
        awardRecords: const [],
        thankYouMessages: const [],
        waitingList: const [],
        alimtalkSettings: const {},
      );
      await ClubPersistence.save(authUserId, saved);
      debugPrint(
        '[ClubProvider] fanout seeded+$authUserId with join ${req.id}',
      );
      return;
    }

    final club = saved.myClubs.where((c) => c.id == clubId).firstOrNull;
    if (club == null) {
      // 내 모임 목록에 없어도 템플릿상 총무면 강제 추가
      final templates = switch (authUserId) {
        'user_guest' => _guestClubs,
        'user_other' => _otherMemberClubs,
        _ => _adminClubs,
      };
      final template = templates.where((c) => c.id == clubId).firstOrNull;
      if (template == null ||
          !ClubMemberRole.canApproveJoins(template.myRole)) {
        return;
      }
      final myClubs = List<Club>.from(saved.myClubs)..add(template);
      final joins = List<JoinRequest>.from(saved.joinRequests);
      if (!joins.any((r) => r.id == req.id)) joins.add(req);
      final notifs = List<AppNotification>.from(saved.appNotifications);
      if (!notifs.any((n) => n.id == noti.id)) {
        notifs.insert(
          0,
          AppNotification(
            id: noti.id,
            type: noti.type,
            clubId: clubId,
            clubName: template.name,
            title: noti.title,
            body: noti.body,
            isAdmin: true,
            isRead: false,
            createdAt: noti.createdAt,
            targetId: noti.targetId,
            targetUserId: noti.targetUserId,
          ),
        );
      }
      await ClubPersistence.save(
        authUserId,
        ClubDataBundle(
          selectedClubIndex: saved.selectedClubIndex,
          freshClubIds: Set<String>.from(saved.freshClubIds),
          myClubs: myClubs,
          allClubs: List<Club>.from(saved.allClubs),
          joinRequests: joins,
          members: List<Member>.from(saved.members),
          activities: List<ActivityItem>.from(saved.activities),
          announcements: List<Announcement>.from(saved.announcements),
          appNotifications: notifs,
          duesSettings: List<DuesSetting>.from(saved.duesSettings),
          duesPayments: List<DuesPayment>.from(saved.duesPayments),
          paymentRequests: List<PaymentRequest>.from(saved.paymentRequests),
          transactions: List<Transaction>.from(saved.transactions),
          schedules: List<RoundSchedule>.from(saved.schedules),
          photos: List<RoundPhoto>.from(saved.photos),
          groupAssignments:
              Map<String, GroupAssignment>.from(saved.groupAssignments),
          adApplications: List<AdApplication>.from(saved.adApplications),
          adNotifications: List<AdNotification>.from(saved.adNotifications),
          sponsorApplications:
              List<SponsorApplication>.from(saved.sponsorApplications),
          pointEvents: saved.pointEvents.map(
            (k, v) => MapEntry(k, List<MembershipPointEvent>.from(v)),
          ),
          awardRecords: List<AwardRecord>.from(saved.awardRecords),
          thankYouMessages: List<ThankYouMessage>.from(saved.thankYouMessages),
          waitingList: List<WaitingEntry>.from(saved.waitingList),
          alimtalkSettings:
              Map<String, ClubAlimtalkSettings>.from(saved.alimtalkSettings),
        ),
      );
      return;
    }

    final role = ClubMemberRole.normalize(club.myRole);
    final canReceive = ClubMemberRole.canApproveJoins(role);
    if (!canReceive) return;

    final joins = List<JoinRequest>.from(saved.joinRequests);
    if (!joins.any((r) => r.id == req.id)) {
      joins.add(
        clubId == req.clubId
            ? req
            : JoinRequest(
                id: req.id,
                clubId: clubId,
                userId: req.userId,
                userName: req.userName,
                userGender: req.userGender,
                userHandicap: req.userHandicap,
                message: req.message,
                referrerId: req.referrerId,
                referrerName: req.referrerName,
                status: req.status,
                requestedAt: req.requestedAt,
                reviewedBy: req.reviewedBy,
                reviewedAt: req.reviewedAt,
              ),
      );
    }

    final notifs = List<AppNotification>.from(saved.appNotifications);
    if (!notifs.any((n) => n.id == noti.id)) {
      notifs.insert(
        0,
        AppNotification(
          id: noti.id,
          type: noti.type,
          clubId: clubId,
          clubName: club.name,
          title: noti.title,
          body: noti.body,
          isAdmin: true,
          isRead: false,
          createdAt: noti.createdAt,
          targetId: noti.targetId,
          targetUserId: noti.targetUserId,
        ),
      );
    }

    await ClubPersistence.save(
      authUserId,
      ClubDataBundle(
        selectedClubIndex: saved.selectedClubIndex,
        freshClubIds: Set<String>.from(saved.freshClubIds),
        myClubs: List<Club>.from(saved.myClubs),
        allClubs: List<Club>.from(saved.allClubs),
        joinRequests: joins,
        members: List<Member>.from(saved.members),
        activities: List<ActivityItem>.from(saved.activities),
        announcements: List<Announcement>.from(saved.announcements),
        appNotifications: notifs,
        duesSettings: List<DuesSetting>.from(saved.duesSettings),
        duesPayments: List<DuesPayment>.from(saved.duesPayments),
        paymentRequests: List<PaymentRequest>.from(saved.paymentRequests),
        transactions: List<Transaction>.from(saved.transactions),
        schedules: List<RoundSchedule>.from(saved.schedules),
        photos: List<RoundPhoto>.from(saved.photos),
        groupAssignments:
            Map<String, GroupAssignment>.from(saved.groupAssignments),
        adApplications: List<AdApplication>.from(saved.adApplications),
        adNotifications: List<AdNotification>.from(saved.adNotifications),
        sponsorApplications:
            List<SponsorApplication>.from(saved.sponsorApplications),
        pointEvents: saved.pointEvents.map(
          (k, v) => MapEntry(k, List<MembershipPointEvent>.from(v)),
        ),
        awardRecords: List<AwardRecord>.from(saved.awardRecords),
        thankYouMessages: List<ThankYouMessage>.from(saved.thankYouMessages),
        waitingList: List<WaitingEntry>.from(saved.waitingList),
        alimtalkSettings:
            Map<String, ClubAlimtalkSettings>.from(saved.alimtalkSettings),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  Actions — Approve / Reject Join Request
  // ════════════════════════════════════════════════════════
  /// 가입 승인 — 직책 지정(회장/부회장/총무/정회원/게스트) + 권한 자동 세팅
  void approveRequest(
    String requestId, {
    String memberType = ClubMemberRole.regular,
    String role = ClubMemberRole.regular,
  }) {
    final idx = _joinRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return;
    final req = _joinRequests[idx];

    final assignedRole = ClubMemberRole.roleForMemberType(memberType, role);
    final assignedType = ClubMemberRole.memberTypeForRole(assignedRole);

    _joinRequests[idx] = req.copyWith(
      status: JoinRequestStatus.approved,
      reviewedBy: currentUserName,
      reviewedAt: DateTime.now(),
    );

    // 회원으로 자동 등록 (직책 = 권한)
    // 신규 모임 필터: m_{clubId}_* 또는 m_creator_{clubId}
    final newMember = Member(
      id: Member.rosterId(req.clubId, req.userId),
      name: req.userName,
      gender: req.userGender,
      memberType: assignedType,
      role: assignedRole,
      handicap: req.userHandicap,
      joinDate: DateTime.now(),
      status: '활성',
      referrerId: req.referrerId,
      referrerName: req.referrerName,
    );
    _members.add(newMember);
    AppDependencies.instance.mockDataStore
        ?.removePendingJoinRequest(requestId);
    unawaited(SharedJoinRequestStore.remove(requestId));

    // 해당 모임 memberCount 증가
    _updateMemberCount(req.clubId, 1);

    // 활동 피드에 추가
    _activities.insert(0, ActivityItem(
      id: 'act_${DateTime.now().millisecondsSinceEpoch}',
      memberId: req.userId,
      memberName: req.userName,
      activityType: 'join',
      description: '$assignedType ($assignedRole) 가입 승인',
      timestamp: DateTime.now(),
    ));

    // 신청자에게 승인 알림
    final club = _allClubs.where((c) => c.id == req.clubId).firstOrNull ??
        _myClubs.where((c) => c.id == req.clubId).firstOrNull;
    addAppNotification(AppNotification(
      id: 'noti_approved_${req.id}',
      type: AppNotificationType.joinApproved,
      clubId: req.clubId,
      clubName: club?.name ?? '모임',
      title: '가입 승인',
      body: '${club?.name ?? '모임'} 가입이 승인되었습니다 ($assignedRole)',
      createdAt: DateTime.now(),
      targetId: req.id,
      targetUserId: _fcmInboxIdFor(req.userId),
      isRead: false,
    ), hqPushTypeId: HqPushCatalog.joinResult, notifySelf: true);

    // 탈퇴 이력 있으면 신청자 계정에서 해제 + 내 모임 복구
    unawaited(_clearLeftClubForApplicant(req.userId, req.clubId));

    notifyListeners();
    _persistImmediately();
  }

  void rejectRequest(String requestId) {
    final idx = _joinRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return;
    final req = _joinRequests[idx];
    _joinRequests[idx] = req.copyWith(
      status: JoinRequestStatus.rejected,
      reviewedBy: currentUserName,
      reviewedAt: DateTime.now(),
    );
    AppDependencies.instance.mockDataStore
        ?.removePendingJoinRequest(requestId);
    unawaited(SharedJoinRequestStore.remove(requestId));
    final club = _allClubs.where((c) => c.id == req.clubId).firstOrNull ??
        _myClubs.where((c) => c.id == req.clubId).firstOrNull;
    _notifyHqPush(
      typeId: HqPushCatalog.joinResult,
      userIds: [req.userId],
      appType: AppNotificationType.announcement,
      clubId: req.clubId,
      clubName: club?.name ?? '모임',
      vars: {
        '이름': req.userName,
        '모임명': club?.name ?? '모임',
        '결과': '거절',
      },
      targetId: req.id,
      notifySelf: true,
    );
    notifyListeners();
    _persistImmediately();
  }

  void _updateMemberCount(String clubId, int delta) {
    final i1 = _myClubs.indexWhere((c) => c.id == clubId);
    if (i1 != -1) {
      _myClubs[i1] = _myClubs[i1].copyWith(
          memberCount: _myClubs[i1].memberCount + delta);
    }
    final i2 = _allClubs.indexWhere((c) => c.id == clubId);
    if (i2 != -1) {
      _allClubs[i2] = _allClubs[i2].copyWith(
          memberCount: _allClubs[i2].memberCount + delta);
    }
  }

  // ════════════════════════════════════════════════════════
  //  Actions — Leave Club
  // ════════════════════════════════════════════════════════
  /// 내 모임 탈퇴. 총무가 인수인계 없이 떠나면 treasurerVacated=true
  Future<LeaveClubResult> leaveClub(String clubId) async {
    final aliases = clubIdAliases(clubId);
    final idx = _myClubs.indexWhere((c) => aliases.contains(c.id));
    if (idx == -1) {
      // 이미 내 모임에 없어도 탈퇴 의도로 처리 — 재진입/참여중 회귀 방지
      _markClubLeft(clubId);
      if (_persistAuthUserId != null) {
        await _saveLeftClubIds(_persistAuthUserId!);
      }
      notifyListeners();
      return const LeaveClubResult(success: true, treasurerVacated: false);
    }
    final club = _myClubs[idx];
    final resolvedId = club.id;
    final wasTreasurer = ClubMemberRole.isTreasurer(club.myRole);

    _myClubs.removeAt(idx);
    _markClubLeft(resolvedId);
    if (_myClubs.isEmpty) {
      _selectedClubIndex = 0;
    } else if (_selectedClubIndex >= _myClubs.length) {
      _selectedClubIndex = _myClubs.length - 1;
    } else if (_selectedClubIndex > idx) {
      _selectedClubIndex -= 1;
    }

    // 회원 상태 처리 — 탈퇴하는 본인만 표시
    final leavingIds = <String>{
      currentUserId,
      if (_persistAuthUserId != null) _persistAuthUserId!,
      'm_creator_$resolvedId',
      'm_${resolvedId}_$currentUserId',
      if (_persistAuthUserId != null) 'm_${resolvedId}_$_persistAuthUserId',
      if (_persistAuthUserId == 'user_guest' || currentUserId == 'mg1') ...[
        'user_guest',
        'mg1',
      ],
      if (_persistAuthUserId == 'user_me' || currentUserId == 'm1') ...[
        'user_me',
        'm1',
      ],
    };
    for (var i = 0; i < _members.length; i++) {
      final mid = _members[i].id;
      if (!leavingIds.contains(mid)) continue;
      if (_legacyMockClubIds.contains(resolvedId)) {
        if (mid == currentUserId ||
            mid == _persistAuthUserId ||
            leavingIds.contains(mid)) {
          _members[i] = _members[i].copyWith(status: '탈퇴');
        }
      } else if (mid == 'm_creator_$resolvedId' ||
          mid.startsWith('m_${resolvedId}_') ||
          mid == currentUserId) {
        _members[i] = _members[i].copyWith(status: '탈퇴');
      }
    }

    if (wasTreasurer) {
      _treasurerVacantClubIds.add(resolvedId);
      _appNotifications.insert(
        0,
        AppNotification(
          id: 'n_treasurer_vacant_$resolvedId${DateTime.now().millisecondsSinceEpoch}',
          type: AppNotificationType.announcement,
          clubId: resolvedId,
          clubName: club.name,
          title: '총무 공석 안내',
          body:
              '${club.name} 총무가 인수인계 없이 탈퇴했습니다. 회장 또는 부회장이 총무를 선임해 주세요.',
          isAdmin: true,
          isRead: false,
          createdAt: DateTime.now(),
        ),
      );
    }

    // Mock 저장소 멤버십 제거 (c1 / seed_c1 모두)
    final store = AppDependencies.instance.mockDataStore;
    if (store != null) {
      for (final key in clubIdAliases(resolvedId)) {
        final map = store.membersByClub[key];
        if (map == null) continue;
        for (final id in leavingIds) {
          map.remove(id);
        }
      }
      await MockStorePersistence.save(store);
    }

    // 탈퇴 직후 sync가 나를 다시 올리지 않도록 — 활성 회원만 동기화
    _syncMyClubsToMockStore();
    if (_persistAuthUserId != null) {
      await _saveLeftClubIds(_persistAuthUserId!);
      await _persistNow();
    }
    notifyListeners();
    return LeaveClubResult(success: true, treasurerVacated: wasTreasurer);
  }

  /// 앱 탈퇴 — 모든 모임에서 빠지고, 이 계정 로컬·원격 모임 목록을 지운다.
  Future<void> withdrawFromApp() async {
    final authId = _persistAuthUserId;
    final clubIds = _myClubs.map((c) => c.id).toList();
    for (final id in clubIds) {
      await leaveClub(id);
    }
    if (authId != null && authId.isNotEmpty) {
      await ClubOpsSync.deleteUserMemberships(authId);
      await ClubOpsSync.deleteUserOps(authId);
      await ClubPersistence.clear(authId);
    }
    _myClubs.clear();
    _selectedClubIndex = 0;
    notifyListeners();
  }

  // ════════════════════════════════════════════════════════
  //  Actions — Members
  // ════════════════════════════════════════════════════════
  void addMember(Member member) {
    _members.add(member);
    notifyListeners();
  }

  void updateMember(Member updated) {
    final idx = _members.indexWhere((m) => m.id == updated.id);
    if (idx != -1) {
      final roleEncoded = ClubMemberRole.encodeRoles(
        ClubMemberRole.splitRoles(updated.role),
      );
      final normalized = updated.copyWith(role: roleEncoded);
      _members[idx] = normalized;
      // 본인 직책 수정 시 모임 myRole 동기화 (권한 판정용, 겸직 포함)
      final isSelf = normalized.id == currentUserId ||
          normalized.id == 'm_creator_${selectedClub.id}' ||
          normalized.id == currentMember?.id ||
          (_persistAuthUserId != null &&
              _userIdsMatch(normalized.id, _persistAuthUserId));
      if (isSelf) {
        final myIdx = _myClubs.indexWhere((c) => c.id == selectedClub.id);
        if (myIdx != -1) {
          _myClubs[myIdx] =
              _myClubs[myIdx].copyWith(myRole: roleEncoded);
        }
        final allIdx = _allClubs.indexWhere((c) => c.id == selectedClub.id);
        if (allIdx != -1) {
          _allClubs[allIdx] =
              _allClubs[allIdx].copyWith(myRole: roleEncoded);
        }
      }
      notifyListeners();
      _persistImmediately();
    }
  }

  /// 소셜 로그인 후 등록한 이름·휴대폰을 로컬 명단에 반영
  void syncAuthUserProfile({required String phone, String? name}) {
    final authId = _persistAuthUserId ?? currentUserId;
    if (authId.isEmpty || phone.trim().isEmpty) return;
    final trimmedName = name?.trim() ?? '';
    var changed = false;
    for (var i = 0; i < _members.length; i++) {
      final m = _members[i];
      final match = m.id == authId ||
          m.id == currentUserId ||
          (_persistAuthUserId != null &&
              _userIdsMatch(m.id, _persistAuthUserId)) ||
          m.id.endsWith('_$authId') ||
          m.id == 'm_creator_${selectedClub.id}';
      if (!match) continue;
      final phoneDigits = (m.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
      final needPhone = phoneDigits.length < 10;
      final needName = trimmedName.isNotEmpty &&
          (m.name.trim().isEmpty ||
              m.name.trim() == '회원' ||
              m.name.trim() == '카카오 회원' ||
              m.name.trim() == 'Google 회원' ||
              m.name.trim() == 'Apple 회원');
      if (!needPhone && !needName) continue;
      _members[i] = m.copyWith(
        phone: needPhone ? phone : null,
        name: needName ? trimmedName : null,
      );
      changed = true;
    }
    if (changed) {
      notifyListeners();
      _persistImmediately();
    }
  }

  /// 소셜 로그인 후 등록한 휴대폰을 로컬 명단에 반영
  void syncAuthUserPhone(String phone) {
    syncAuthUserProfile(phone: phone);
  }

  /// 계정에 저장한 생년월일·핸디캡을 내가 속한 모든 모임 명단에 반영.
  ///
  /// 이름·전화와 달리 본인이 직접 입력한 값이므로 비어 있지 않으면 덮어쓴다.
  /// 반영 후 Firestore ops bundle 까지 밀어서 다른 기기·총무 화면에도 보이게 한다.
  void syncAuthGolfProfile({
    DateTime? birthDate,
    double? handicap,
  }) {
    if (birthDate == null && handicap == null) return;
    final authId = _persistAuthUserId ?? currentUserId;
    if (authId.isEmpty) return;

    var changed = false;
    for (var i = 0; i < _members.length; i++) {
      final m = _members[i];
      final match = m.id == authId ||
          m.id == currentUserId ||
          (_persistAuthUserId != null &&
              _userIdsMatch(m.id, _persistAuthUserId)) ||
          m.id.endsWith('_$authId') ||
          m.id == 'm_creator_${selectedClub.id}';
      if (!match) continue;
      if (m.birthDate == birthDate && m.handicap == handicap) continue;
      _members[i] = m.copyWith(
        birthDate: birthDate,
        handicap: handicap,
      );
      changed = true;
    }
    if (changed) {
      notifyListeners();
      _persistImmediately();
    }
  }

  /// 마이페이지 직책 변경 — 명단·Club.myRole을 모임 단위로 확실히 반영
  bool setMyRoleForClub(String clubId, String role) {
    final roleEncoded = ClubMemberRole.encodeRoles(
      ClubMemberRole.splitRoles(role),
    );
    final myIdx = _myClubs.indexWhere((c) => c.id == clubId);
    if (myIdx == -1) return false;

    selectClubById(clubId);

    final creatorId = 'm_creator_$clubId';
    var me = membersForClub(clubId).where((m) {
      return m.id == creatorId ||
          m.id == currentUserId ||
          m.id == 'm_${clubId}_$currentUserId' ||
          (_persistAuthUserId != null &&
              (m.id == _persistAuthUserId ||
                  m.id == 'm_${clubId}_$_persistAuthUserId'));
    }).firstOrNull;

    if (me == null) {
      me = Member(
        id: creatorId,
        name: currentUserName,
        gender: '남',
        memberType: ClubMemberRole.memberTypeForRole(roleEncoded),
        role: roleEncoded,
        joinDate: _myClubs[myIdx].createdAt,
        status: '활성',
      );
      _members.add(me);
    } else {
      final mIdx = _members.indexWhere((m) => m.id == me!.id);
      if (mIdx != -1) {
        _members[mIdx] = _members[mIdx].copyWith(
          role: roleEncoded,
          memberType: ClubMemberRole.memberTypeForRole(roleEncoded),
        );
      }
    }

    _myClubs[myIdx] = _myClubs[myIdx].copyWith(myRole: roleEncoded);
    final allIdx = _allClubs.indexWhere((c) => c.id == clubId);
    if (allIdx != -1) {
      _allClubs[allIdx] = _allClubs[allIdx].copyWith(myRole: roleEncoded);
    }

    notifyListeners();
    _persistImmediately();
    return true;
  }

  void changeMemberType(String memberId, String newType) {
    final idx = _members.indexWhere((m) => m.id == memberId);
    if (idx != -1) {
      _members[idx] = _members[idx].copyWith(memberType: newType);
      notifyListeners();
    }
  }

  void deactivateMember(String memberId) {
    final idx = _members.indexWhere((m) => m.id == memberId);
    if (idx != -1) {
      _members[idx] = _members[idx].copyWith(status: '탈퇴');
      notifyListeners();
    }
  }

  /// 총무 권한 — 회원 강퇴 처리 + 대상 회원에게 즉시 앱 푸시 알림 발송
  void kickMember(String memberId, {String? clubId}) {
    final idx = _members.indexWhere((m) => m.id == memberId);
    if (idx == -1) return;
    final member = _members[idx];
    if (member.status == '강퇴') return;
    _members[idx] = member.copyWith(status: '강퇴');

    final targetClubId = clubId ?? selectedClub.id;
    _updateMemberCount(targetClubId, -1);

    final club = _myClubs.where((c) => c.id == targetClubId).firstOrNull ??
        _allClubs.where((c) => c.id == targetClubId).firstOrNull;

    addAppNotification(AppNotification(
      id: 'noti_kick_${memberId}_${DateTime.now().millisecondsSinceEpoch}',
      type: AppNotificationType.memberKicked,
      clubId: targetClubId,
      clubName: club?.name ?? '',
      title: '모임에서 강퇴되었습니다',
      body: '${club?.name ?? '모임'}에서 총무에 의해 강퇴 처리되었습니다.',
      createdAt: DateTime.now(),
      targetUserId: memberId,
    ));

    notifyListeners();
    _persistImmediately();
  }
  // ════════════════════════════════════════════════════════
  //  Photos — 라운딩 사진 목업
  // ════════════════════════════════════════════════════════

  final List<RoundPhoto> _photos = [
    // s3 (지난 일정: 5월 월례회) 샘플 사진
    RoundPhoto(
      id: 'p1', scheduleId: 's3', clubId: 'c1',
      uploaderId: 'm1', uploaderName: '홍길동',
      imageUrl: 'https://picsum.photos/seed/golf1/600/400',
      caption: '레이크사이드 18번 홀 파 버디!',
      takenAt: DateTime.now().subtract(const Duration(days: 20, hours: 2)),
    ),
    RoundPhoto(
      id: 'p2', scheduleId: 's3', clubId: 'c1',
      uploaderId: 'm2', uploaderName: '김철수',
      imageUrl: 'https://picsum.photos/seed/golf2/600/400',
      caption: '오늘 동반자들과 함께',
      takenAt: DateTime.now().subtract(const Duration(days: 20, hours: 1)),
    ),
    RoundPhoto(
      id: 'p3', scheduleId: 's3', clubId: 'c1',
      uploaderId: 'm3', uploaderName: '이영희',
      imageUrl: 'https://picsum.photos/seed/golf3/600/400',
      caption: '클럽하우스에서 점심',
      takenAt: DateTime.now().subtract(const Duration(days: 20)),
    ),
    RoundPhoto(
      id: 'p4', scheduleId: 's3', clubId: 'c1',
      uploaderId: 'm6', uploaderName: '정다은',
      imageUrl: 'https://picsum.photos/seed/golf4/600/400',
      caption: null,
      takenAt: DateTime.now().subtract(const Duration(days: 19, hours: 20)),
    ),
    RoundPhoto(
      id: 'p5', scheduleId: 's3', clubId: 'c1',
      uploaderId: 'm1', uploaderName: '홍길동',
      imageUrl: 'https://picsum.photos/seed/golf5/600/400',
      caption: '코스 뷰 최고였던 9번홀',
      takenAt: DateTime.now().subtract(const Duration(days: 19, hours: 18)),
    ),
    RoundPhoto(
      id: 'p6', scheduleId: 's3', clubId: 'c1',
      uploaderId: 'm4', uploaderName: '박민준',
      imageUrl: 'https://picsum.photos/seed/golf6/600/400',
      caption: '마지막 홀 기념샷',
      takenAt: DateTime.now().subtract(const Duration(days: 19, hours: 16)),
    ),
  ];

  /// 특정 일정의 사진 목록 (최신순)
  List<RoundPhoto> photosOf(String scheduleId) {
    final list = _photos
        .where((p) =>
            p.scheduleId == scheduleId &&
            !ClubOpsSync.isPhotoDeleted(p.id))
        .toList();
    list.sort((a, b) => b.takenAt.compareTo(a.takenAt));
    return list;
  }

  /// 현재 모임 전체 사진 (갤러리용, 최신순)
  ///
  /// 취소된 일정의 사진은 제외한다. 취소하면 일정 탭에서 사라지는데
  /// 갤러리에만 앨범이 남아 개수가 안 맞던 문제를 막는다.
  List<RoundPhoto> get clubPhotos {
    final clubId = selectedClub.id;
    final scheduleIds = activeSchedules.map((s) => s.id).toSet();
    final cancelledIds = cancelledScheduleIds;
    final list = _photos
        .where((p) =>
            !ClubOpsSync.isPhotoDeleted(p.id) &&
            !cancelledIds.contains(p.scheduleId) &&
            (p.clubId == clubId || scheduleIds.contains(p.scheduleId)))
        .toList();
    list.sort((a, b) => b.takenAt.compareTo(a.takenAt));
    return list;
  }

  /// 사진 추가 (갤러리 선택 이미지 또는 목업 URL)
  void addPhoto({
    required String scheduleId,
    required String caption,
    String? imageUrl,
  }) {
    addPhotos(
      scheduleId: scheduleId,
      caption: caption,
      imageUrls: [
        (imageUrl != null && imageUrl.isNotEmpty)
            ? imageUrl
            : 'https://picsum.photos/seed/user${DateTime.now().microsecondsSinceEpoch}/600/400',
      ],
    );
  }

  /// 여러 사진을 한 번에 추가 (고유 ID 보장)
  void addPhotos({
    required String scheduleId,
    required List<String> imageUrls,
    String caption = '',
  }) {
    if (imageUrls.isEmpty) return;
    final base = DateTime.now().microsecondsSinceEpoch;
    final uploaderId = currentMember?.id ?? currentUserId;
    final captionOrNull = caption.trim().isEmpty ? null : caption.trim();
    for (var i = 0; i < imageUrls.length; i++) {
      final url = imageUrls[i].trim();
      if (url.isEmpty) continue;
      _photos.add(RoundPhoto(
        id: 'photo_${base}_$i',
        scheduleId: scheduleId,
        clubId: selectedClub.id,
        uploaderId: uploaderId,
        uploaderName: currentUserName,
        imageUrl: url,
        caption: captionOrNull,
        takenAt: DateTime.now().add(Duration(milliseconds: i)),
      ));
    }
    _persistImmediately();
    notifyListeners();
  }

  /// 내가 올린 사진인지 (명단 ID·로그인 ID 별칭 포함)
  bool isOwnPhoto(RoundPhoto photo) {
    if (_isSelfTarget(photo.uploaderId)) return true;
    // ID가 어긋난 예전 저장분 — 업로드 이름이 본인과 같으면 본인으로 본다
    final name = photo.uploaderName.trim();
    return name.isNotEmpty && name == currentUserName.trim();
  }

  /// 사진 삭제 가능 — 본인 또는 운영진(회장·부회장·총무)
  bool canDeletePhoto(RoundPhoto photo) =>
      isOwnPhoto(photo) || isClubExecutive;

  /// 사진 삭제. 성공 시 true.
  bool deletePhoto(String photoId) {
    final idx = _photos.indexWhere((p) => p.id == photoId);
    if (idx < 0) return false;
    final photo = _photos[idx];
    if (!canDeletePhoto(photo)) return false;
    final clubId = photo.clubId;
    // watch merge가 삭제분을 되살리기 전에 먼저 표시
    ClubOpsSync.markPhotoDeleted(photoId);
    _photos.removeAt(idx);
    notifyListeners();
    _persistImmediately();
    if (clubId != null && clubId.isNotEmpty) {
      unawaited(ClubOpsSync.deletePhotoDoc(clubId, photoId));
    }
    return true;
  }

  /// 여러 사진 삭제. 실제 지워진 개수 반환.
  int deletePhotos(Iterable<String> photoIds) {
    var n = 0;
    for (final id in photoIds.toSet()) {
      if (deletePhoto(id)) n++;
    }
    return n;
  }

  /// 사진 캡션 수정 (본인만)
  bool updatePhotoCaption(String photoId, String caption) {
    final idx = _photos.indexWhere((p) => p.id == photoId);
    if (idx == -1) return false;
    if (!isOwnPhoto(_photos[idx])) return false;
    final trimmed = caption.trim();
    _photos[idx] = _photos[idx].copyWith(
      caption: trimmed,
      clearCaption: trimmed.isEmpty,
    );
    _persistImmediately();
    notifyListeners();
    return true;
  }

  // ════════════════════════════════════════════════════════
  //  조편성 (GroupAssignment)
  // ════════════════════════════════════════════════════════

  /// scheduleId → GroupAssignment 저장소
  final Map<String, GroupAssignment> _groupAssignments = {
    // ── s4 — 확정 조편성 (참석 응답자만: mg1/m1/m2/m4) ──
    's4': GroupAssignment(
      scheduleId: 's4',
      teamCount: 6,
      perGroup: 4,
      isFinalized: true,
      finalizedAt: DateTime.now().subtract(const Duration(days: 1)),
      groups: [
        AssignGroup(groupNumber: 1, slots: [
          const GroupSlot(memberId: 'm1',  memberName: '홍길동', gender: '남', handicap: 12.0),
          const GroupSlot(memberId: 'm2',  memberName: '김철수', gender: '남', handicap: 15.0),
          const GroupSlot(memberId: 'mg1', memberName: '이민준', gender: '남', handicap: 18.0),
          const GroupSlot(memberId: 'm4',  memberName: '박민준', gender: '남', handicap: 20.0),
        ]),
        AssignGroup(groupNumber: 2, slots: [
          const GroupSlot(),
          const GroupSlot(),
          const GroupSlot(),
          const GroupSlot(),
        ]),
        AssignGroup(groupNumber: 3, slots: [
          const GroupSlot(),
          const GroupSlot(),
          const GroupSlot(),
          const GroupSlot(),
        ]),
        AssignGroup(groupNumber: 4, slots: [
          const GroupSlot(),
          const GroupSlot(),
          const GroupSlot(),
          const GroupSlot(),
        ]),
        AssignGroup(groupNumber: 5, slots: [
          const GroupSlot(),
          const GroupSlot(),
          const GroupSlot(),
          const GroupSlot(),
        ]),
        AssignGroup(groupNumber: 6, slots: [
          const GroupSlot(),
          const GroupSlot(),
          const GroupSlot(),
          const GroupSlot(),
        ]),
      ],
    ),
  };

  /// 해당 일정의 조편성 반환 (없으면 null)
  GroupAssignment? groupAssignment(String scheduleId) =>
      _groupAssignments[scheduleId];

  /// 해당 일정의 조편성 (없으면 빈 객체를 생성해 맵에 저장)
  GroupAssignment getOrCreateAssignment(String scheduleId) {
    final existing = _groupAssignments[scheduleId];
    if (existing != null) return existing;
    final schedule = scheduleById(scheduleId);
    final teamCount = (schedule?.teamCount ?? 4).clamp(1, 30);
    final created = GroupAssignment.empty(
      scheduleId: scheduleId,
      teamCount: teamCount,
    );
    _groupAssignments[scheduleId] = created;
    return created;
  }

  /// 일정에 저장된 팀 수로 조편성 조 수를 맞춘다 (1팀 포함).
  /// 확정된 조편성은 건드리지 않는다.
  void syncAssignmentTeamCountFromSchedule(String scheduleId) {
    final schedule = scheduleById(scheduleId);
    if (schedule == null) return;
    final want = schedule.teamCount.clamp(1, 30);
    final existing = _groupAssignments[scheduleId];
    if (existing == null) {
      getOrCreateAssignment(scheduleId);
      return;
    }
    if (existing.isFinalized || existing.teamCount == want) return;
    changeTeamCount(scheduleId, want);
  }

  /// 조편성 저장
  void saveAssignment(GroupAssignment assignment) {
    _groupAssignments[assignment.scheduleId] = assignment;
    notifyListeners();
    _persistImmediately();
  }

  /// 조편성 초기화 (전체 비우기)
  void clearAssignment(String scheduleId) {
    final current = _groupAssignments[scheduleId];
    if (current == null) return;
    _groupAssignments[scheduleId] = GroupAssignment.empty(
      scheduleId: scheduleId,
      teamCount: current.teamCount,
      perGroup: current.perGroup,
    );
    notifyListeners();
    _persistImmediately();
  }

  /// 팀 수 변경 (가능하면 기존 배정 유지, 모드·옵션 유지)
  /// 일정 teamCount(정원=팀수×4)도 함께 동기화한다. 최소 1조.
  void changeTeamCount(String scheduleId, int newCount) {
    final n = newCount.clamp(1, 30);
    final current = _groupAssignments[scheduleId] ??
        getOrCreateAssignment(scheduleId);
    if (current.teamCount == n && current.groups.length == n) {
      // 일정 쪽만 어긋난 경우 보정
      final sIdx = _schedules.indexWhere((s) => s.id == scheduleId);
      if (sIdx != -1 && _schedules[sIdx].teamCount != n) {
        final s = _schedules[sIdx];
        final keepCap = s.maxCapacity != null && s.maxCapacity! >= n * 4;
        _schedules[sIdx] = s.copyWith(
          teamCount: n,
          maxCapacity: keepCap ? s.maxCapacity : null,
          clearMaxCapacity: !keepCap,
        );
        _syncNextRound(s.clubId);
        notifyListeners();
        _persistImmediately();
      }
      return;
    }

    final perGroup = current.perGroup;
    final List<AssignGroup> newGroups;
    if (n <= current.groups.length) {
      // 축소: 뒤 조가 비어 있으면 유지 축소, 아니면 빈 조편성으로 재생성
      final trailingEmpty =
          current.groups.skip(n).every((g) => g.filledCount == 0);
      if (trailingEmpty) {
        newGroups = [
          for (var i = 0; i < n; i++)
            AssignGroup(
              groupNumber: i + 1,
              slots: List<GroupSlot>.from(current.groups[i].slots),
            ),
        ];
      } else {
        newGroups = GroupAssignment.empty(
          scheduleId: scheduleId,
          teamCount: n,
          perGroup: perGroup,
        ).groups;
      }
    } else {
      newGroups = [
        for (var i = 0; i < current.groups.length; i++)
          AssignGroup(
            groupNumber: i + 1,
            slots: List<GroupSlot>.from(current.groups[i].slots),
          ),
        for (var i = current.groups.length; i < n; i++)
          AssignGroup(
            groupNumber: i + 1,
            slots: List.generate(perGroup, (_) => const GroupSlot()),
          ),
      ];
    }

    _groupAssignments[scheduleId] = GroupAssignment(
      scheduleId: scheduleId,
      teamCount: n,
      perGroup: perGroup,
      groups: newGroups,
      isFinalized: current.isFinalized,
      finalizedAt: current.finalizedAt,
      mode: current.mode,
      selectedOptions: current.selectedOptions,
    );

    final sIdx = _schedules.indexWhere((s) => s.id == scheduleId);
    if (sIdx != -1) {
      final s = _schedules[sIdx];
      final keepCap = s.maxCapacity != null && s.maxCapacity! >= n * 4;
      _schedules[sIdx] = s.copyWith(
        teamCount: n,
        maxCapacity: keepCap ? s.maxCapacity : null,
        clearMaxCapacity: !keepCap,
      );
      _syncNextRound(s.clubId);
    }
    notifyListeners();
    _persistImmediately();
  }

  /// 조편성 방식(수동/혼합/자동) 변경
  void setAssignmentMode(String scheduleId, GroupAssignmentMode mode) {
    final assignment = getOrCreateAssignment(scheduleId);
    if (assignment.mode == mode) return;
    _groupAssignments[scheduleId] = assignment.copyWith(mode: mode);
    notifyListeners();
    _persistImmediately();
  }

  /// 자동 배정 옵션 토글 저장
  void setAssignmentOptions(
    String scheduleId,
    List<AutoAssignOption> options,
  ) {
    final assignment = getOrCreateAssignment(scheduleId);
    _groupAssignments[scheduleId] =
        assignment.copyWith(selectedOptions: options);
    notifyListeners();
    _persistImmediately();
  }

  /// 슬롯에 멤버 수동 배정
  void assignMember({
    required String scheduleId,
    required int groupIndex,
    required int slotIndex,
    required GroupSlot slot,
  }) {
    final assignment = getOrCreateAssignment(scheduleId);
    final groups = List<AssignGroup>.from(assignment.groups);
    final slots = List<GroupSlot>.from(groups[groupIndex].slots);

    // 같은 멤버가 다른 슬롯에 있으면 제거
    if (slot.isFilled) {
      for (int gi = 0; gi < groups.length; gi++) {
        final grpSlots = List<GroupSlot>.from(groups[gi].slots);
        for (int si = 0; si < grpSlots.length; si++) {
          if (grpSlots[si].memberId == slot.memberId) {
            grpSlots[si] = const GroupSlot();
          }
        }
        groups[gi] = groups[gi].copyWithSlots(grpSlots);
      }
    }

    slots[slotIndex] = slot;
    groups[groupIndex] = groups[groupIndex].copyWithSlots(slots);
    _groupAssignments[scheduleId] = assignment.copyWith(groups: groups);
    notifyListeners();
    _persistImmediately();
  }

  /// 슬롯 비우기
  void clearSlot({
    required String scheduleId,
    required int groupIndex,
    required int slotIndex,
  }) {
    final assignment = _groupAssignments[scheduleId];
    if (assignment == null) return;
    final groups = List<AssignGroup>.from(assignment.groups);
    final slots = List<GroupSlot>.from(groups[groupIndex].slots);
    slots[slotIndex] = const GroupSlot();
    groups[groupIndex] = groups[groupIndex].copyWithSlots(slots);
    _groupAssignments[scheduleId] = assignment.copyWith(groups: groups);
    notifyListeners();
    _persistImmediately();
  }

  /// 자동 배정 (옵션 적용). GroupAssignmentService에 위임.
  /// 참석 응답에만 있고 회원 명단에 없는 ID도 배정 가능하도록 보강한다.
  void autoAssign({
    required String scheduleId,
    required List<AutoAssignOption> options,
    bool keepManual = true, // true: 수동 배정된 슬롯 유지
  }) {
    final assignment = getOrCreateAssignment(scheduleId);
    final schedule = scheduleById(scheduleId);
    if (schedule == null) return;

    final attendeeResponses = schedule.responses
        .where((r) => r.response == '참석')
        .toList();

    final alreadyAssigned = <String>{};
    if (keepManual) {
      for (final g in assignment.groups) {
        for (final s in g.slots) {
          if (s.isFilled) alreadyAssigned.add(s.memberId!);
        }
      }
    }

    final unassigned = <Member>[];
    for (final r in attendeeResponses) {
      if (alreadyAssigned.contains(r.memberId)) continue;
      unassigned.add(_memberForAssignment(r));
    }

    final prevGroupOf = <String, int>{};
    if (options.contains(AutoAssignOption.avoidLastMonth)) {
      final pastList = pastSchedules;
      if (pastList.isNotEmpty) {
        final prevAssign = groupAssignment(pastList.first.id);
        if (prevAssign != null) {
          for (final g in prevAssign.groups) {
            for (final s in g.slots) {
              if (s.isFilled) prevGroupOf[s.memberId!] = g.groupNumber;
            }
          }
        }
      }
    }

    final companionIdsByMember = <String, List<String>>{
      for (final r in attendeeResponses)
        if (r.companionMemberIds.isNotEmpty)
          r.memberId: List<String>.from(r.companionMemberIds),
    };

    final nextGroups = const GroupAssignmentService().autoAssign(
      GroupAssignmentInput(
        groups: assignment.groups,
        unassigned: unassigned,
        options: options,
        prevGroupOf: prevGroupOf,
        companionIdsByMember: companionIdsByMember,
        keepManual: keepManual,
      ),
    );

    _groupAssignments[scheduleId] = assignment.copyWith(
      groups: nextGroups,
      selectedOptions: options,
    );
    notifyListeners();
    _persistImmediately();
  }

  /// 참석 응답 → 배정용 Member. 명단 조회 실패 시 응답 정보로 임시 생성.
  Member _memberForAssignment(AttendanceResponse response) {
    final existing = memberById(response.memberId);
    if (existing != null) return existing;
    return Member(
      id: response.memberId,
      name: response.memberName,
      gender: '남',
      memberType: '게스트',
      role: '게스트',
    );
  }

  /// 조편성 확정
  void finalizeAssignment(String scheduleId) {
    final current = _groupAssignments[scheduleId] ??
        getOrCreateAssignment(scheduleId);
    _groupAssignments[scheduleId] = current.copyWith(
      isFinalized: true,
      finalizedAt: DateTime.now(),
    );
    notifyListeners();
    _persistImmediately();
  }

  /// 조편성 확정 취소
  void unfinalizeAssignment(String scheduleId) {
    final current = _groupAssignments[scheduleId];
    if (current == null) return;
    _groupAssignments[scheduleId] = current.copyWith(isFinalized: false);
    notifyListeners();
    _persistImmediately();
  }

  // ════════════════════════════════════════════════════════════
  //  제휴 광고
  // ════════════════════════════════════════════════════════════

  List<AdApplication> _adApplications = _createDefaultAdApplications();

  static List<AdApplication> _createDefaultAdApplications() {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    return <AdApplication>[
      // 샘플: 현재 게재 중인 광고 (홈 배너 — 스카이72) — 이번달부터 2개월
      AdApplication(
        id: 'ad1',
        clubId: 'c1',
        clubName: '강남 골프회',
        applicantId: 'm2',
        applicantName: '김철수',
        slotType: AdSlotType.home,
        startMonth: thisMonth,                              // ← 현재 월
        durationMonths: 2,
        status: AdStatus.active,
        appliedAt: thisMonth.subtract(const Duration(days: 20)),
        title: '스카이72 골프 & 리조트',
        description: '인천 영종도 36홀 · 지금 예약 시 그린피 15% 할인',
        bannerImageUrl: 'assets/ads/sky72.png',
        landingUrl: 'https://sky72.com',
        paidAt: thisMonth.subtract(const Duration(days: 15)),
        paidAmount: 200000,
      ),
      // 샘플: 일정 탭 — 승인 대기 중 (다음달)
      AdApplication(
        id: 'ad2',
        clubId: 'c1',
        clubName: '강남 골프회',
        applicantId: 'm4',
        applicantName: '박민준',
        slotType: AdSlotType.schedule,
        startMonth: nextMonth,                             // ← 다음달
        durationMonths: 1,
        status: AdStatus.pending,
        appliedAt: thisMonth.subtract(const Duration(days: 3)),
        title: 'TITLEIST Pro V1x 한정 특가',
        description: '공식 파트너 온라인몰 단독 15% 할인',
      ),
      // 샘플: 홈 배너 — 승인 완료 대기 (후원과 함께 전체 내역에 표시)
      AdApplication(
        id: 'ad3',
        clubId: 'c1',
        clubName: '강남 골프회',
        applicantId: 'user_me',
        applicantName: '홍길동',
        slotType: AdSlotType.home,
        startMonth: nextMonth,                             // ← 다음달
        durationMonths: 2,
        status: AdStatus.approved,
        appliedAt: thisMonth.subtract(const Duration(days: 15)),
        title: '레이크사이드CC 회원권 특가',
        description: '강남 회원 전용 주중 그린피 20% 할인',
      ),
    ];
  }

  final List<AdNotification> _adNotifications = [];

  List<AdApplication> get allAdApplications =>
      List.unmodifiable(_adApplications);

  /// 특정 모임의 광고 신청 목록
  List<AdApplication> adApplicationsForClub(String clubId) =>
      _adApplications.where((a) => a.clubId == clubId).toList()
        ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));

  /// 내가 신청한 광고 목록
  List<AdApplication> myAdApplications(String memberId) =>
      _adApplications.where((a) => a.applicantId == memberId).toList()
        ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));

  /// 총무 검토 대기 목록 (특정 모임)
  List<AdApplication> pendingAdsForClub(String clubId) =>
      _adApplications
          .where((a) => a.clubId == clubId && a.status == AdStatus.pending)
          .toList();

  /// 특정 슬롯의 현재 활성 광고
  AdApplication? activeAdForSlot(String clubId, AdSlotType slot) {
    final now = DateTime.now();
    try {
      return _adApplications.firstWhere(
        (a) => a.clubId == clubId && a.slotType == slot && a.isActiveOn(now),
      );
    } catch (_) {
      return null;
    }
  }

  /// 슬롯에서 특정 기간과 겹치는 점유 광고 반환
  /// (active + paid + approved + pending 모두 포함 — 기간 충돌 체크용)
  AdApplication? occupiedAdForSlot(
      String clubId, AdSlotType slot, DateTime targetStart, int durationMonths) {
    final targetEnd = DateTime(
        targetStart.year, targetStart.month + durationMonths, 1);
    try {
      return _adApplications.firstWhere((a) {
        if (a.clubId != clubId || a.slotType != slot) return false;
        if (a.status == AdStatus.expired || a.status == AdStatus.rejected) {
          return false;
        }
        // 기간 겹침: a.start < targetEnd && a.end > targetStart
        return a.startMonth.isBefore(targetEnd) &&
            a.endMonth.isAfter(targetStart);
      });
    } catch (_) {
      return null;
    }
  }

  /// 만료 5일 전인 광고에 연장 알림 발송 (이미 보낸 경우 제외)
  void checkAndSendExpiryNotifications() {
    final now = DateTime.now();
    final in5Days = now.add(const Duration(days: 5));
    for (final ad in _adApplications) {
      if (ad.status != AdStatus.active) continue;
      // endMonth 5일 전 이내인지
      final diff = ad.endMonth.difference(now).inDays;
      if (diff > 5 || diff < 0) continue;
      // 이미 동일한 만료 알림이 있으면 스킵
      final alreadySent = _adNotifications.any((n) =>
          n.adApplicationId == ad.id && n.title.contains('만료 임박'));
      if (alreadySent) continue;
      _adNotifications.add(AdNotification(
        id: 'adn_expiry_${ad.id}_${now.millisecondsSinceEpoch}',
        recipientId: ad.applicantId,
        title: '[광고 만료 임박] ${ad.slotType.label}',
        body: '${ad.clubName}의 ${ad.slotType.label} 광고가 '
            '${ad.endMonth.month}월 ${ad.endMonth.day}일에 만료됩니다.\n'
            '광고를 연장하시려면 \'광고연장하기\'를 눌러주세요.',
        sentAt: now,
        adApplicationId: ad.id,
      ));
    }
    notifyListeners();
  }

  /// 광고 연장 — 기존 광고의 endMonth를 늘리는 새 광고 신청
  void extendAd(String adId, int extraMonths) {
    final idx = _adApplications.indexWhere((a) => a.id == adId);
    if (idx == -1) return;
    final original = _adApplications[idx];
    final newStart = original.endMonth; // 기존 만료월 = 새 시작월
    final newAd = AdApplication(
      id: 'ad_ext_${DateTime.now().millisecondsSinceEpoch}',
      clubId: original.clubId,
      clubName: original.clubName,
      applicantId: original.applicantId,
      applicantName: original.applicantName,
      slotType: original.slotType,
      startMonth: newStart,
      durationMonths: extraMonths,
      status: AdStatus.pending,
      appliedAt: DateTime.now(),
      title: original.title,
      description: original.description,
    );
    _adApplications.add(newAd);
    // 총무에게 알림
    _adNotifications.add(AdNotification(
      id: 'adn_ext_${DateTime.now().millisecondsSinceEpoch}',
      recipientId: 'treasurer',
      title: '[광고 연장 신청] ${original.slotType.label}',
      body: '${original.applicantName}님이 ${original.clubName}의 '
          '${original.slotType.label} 광고 연장을 신청했습니다.\n'
          '연장 기간: ${newStart.month}월부터 ${extraMonths}개월\n검토 후 승인/거절 해주세요.',
      sentAt: DateTime.now(),
      adApplicationId: newAd.id,
    ));
    notifyListeners();
  }

  /// 특정 슬롯의 다음 예정 광고 (가장 가까운 startMonth 기준)
  AdApplication? nextScheduledAd(String clubId, AdSlotType slot) {
    final now = DateTime.now();
    final upcoming = _adApplications
        .where((a) =>
            a.clubId == clubId &&
            a.slotType == slot &&
            (a.status == AdStatus.active || a.status == AdStatus.paid) &&
            a.startMonth.isAfter(now))
        .toList()
      ..sort((a, b) => a.startMonth.compareTo(b.startMonth));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  /// 특정 슬롯에서 가장 빠른 게재 가능 시작일
  DateTime earliestAvailableDate(String clubId, AdSlotType slot) {
    final relevant = _adApplications
        .where((a) =>
            a.clubId == clubId &&
            a.slotType == slot &&
            (a.status == AdStatus.active ||
                a.status == AdStatus.paid ||
                a.status == AdStatus.approved))
        .toList()
      ..sort((a, b) => a.endMonth.compareTo(b.endMonth));
    if (relevant.isEmpty) {
      // 이번 달 1일부터 가능
      final now = DateTime.now();
      return DateTime(now.year, now.month, 1);
    }
    return relevant.last.endMonth;
  }

  /// 광고 신청
  void applyForAd(AdApplication ad) {
    _adApplications.add(ad);
    // 총무에게 알림톡 발송 (UI)
    _adNotifications.add(AdNotification(
      id: 'adn_${DateTime.now().millisecondsSinceEpoch}',
      recipientId: 'treasurer', // 실제로는 해당 모임 총무 id
      title: '[광고 신청] ${ad.slotType.label}',
      body:
          '${ad.applicantName}님이 ${ad.clubName}의 ${ad.slotType.label} 광고를 신청했습니다.\n'
          '기간: ${ad.startMonth.month}월 ~ ${ad.endMonth.month - 1}월 (${ad.durationMonths}개월)\n'
          '금액: ${_fmtAmount(ad.totalFee)}원\n검토 후 승인/거절 해주세요.',
      sentAt: DateTime.now(),
      adApplicationId: ad.id,
    ));
    notifyListeners();
  }

  /// 총무 승인
  void approveAd(String adId) {
    final idx = _adApplications.indexWhere((a) => a.id == adId);
    if (idx == -1) return;
    final ad = _adApplications[idx].copyWith(
      status: AdStatus.approved,
      reviewedAt: DateTime.now(),
    );
    _adApplications[idx] = ad;
    // 신청자에게 알림
    _adNotifications.add(AdNotification(
      id: 'adn_${DateTime.now().millisecondsSinceEpoch}',
      recipientId: ad.applicantId,
      title: '[광고 승인] ${ad.slotType.label}',
      body: '${ad.clubName}의 ${ad.slotType.label} 광고가 승인되었습니다.\n'
          '48시간 내에 결제를 완료해주세요.\n'
          '총 결제금액: ${_fmtAmount(ad.totalFee)}원',
      sentAt: DateTime.now(),
      adApplicationId: ad.id,
    ));
    notifyListeners();
  }

  /// 총무 거절
  void rejectAd(String adId, String reason) {
    final idx = _adApplications.indexWhere((a) => a.id == adId);
    if (idx == -1) return;
    final ad = _adApplications[idx].copyWith(
      status: AdStatus.rejected,
      rejectReason: reason,
      reviewedAt: DateTime.now(),
    );
    _adApplications[idx] = ad;
    _adNotifications.add(AdNotification(
      id: 'adn_${DateTime.now().millisecondsSinceEpoch}',
      recipientId: ad.applicantId,
      title: '[광고 거절] ${ad.slotType.label}',
      body: '${ad.clubName}의 ${ad.slotType.label} 광고 신청이 거절되었습니다.\n사유: $reason',
      sentAt: DateTime.now(),
      adApplicationId: ad.id,
    ));
    notifyListeners();
  }

  /// 결제 완료 처리 (PG 연동 후 호출)
  /// 광고비 수입(90%) → 해당 모임 _transactions 자동 등록 (회비 납부와 동일한 패턴)
  void markAdPaid(String adId) {
    final idx = _adApplications.indexWhere((a) => a.id == adId);
    if (idx == -1) return;
    final ad = _adApplications[idx];
    final now = DateTime.now();
    _adApplications[idx] = ad.copyWith(
      status: AdStatus.paid,
      paidAt: now,
      paidAmount: ad.totalFee,
    );
    // 광고비 90% → 모임 수입 자동 등록
    _transactions.add(Transaction(
      id: 'tx_ad_${now.millisecondsSinceEpoch}',
      type: TxType.income,
      amount: ad.clubRevenue,
      category: '제휴광고',
      title: '광고비 수입 - ${ad.applicantName} (${ad.slotType.label})',
      date: now,
      recordedBy: '시스템',
      source: TxSource.ad,
      clubId: ad.clubId,
    ));
    notifyListeners();
  }

  /// 이미지 업로드 완료 → 활성화
  void activateAd(String adId,
      {required String bannerImageUrl,
      required String detailImageUrl,
      String? landingUrl}) {
    final idx = _adApplications.indexWhere((a) => a.id == adId);
    if (idx == -1) return;
    _adApplications[idx] = _adApplications[idx].copyWith(
      status: AdStatus.active,
      bannerImageUrl: bannerImageUrl,
      detailImageUrl: detailImageUrl,
      landingUrl: landingUrl,
    );
    notifyListeners();
  }

  /// 내 알림 목록
  List<AdNotification> myAdNotifications(String memberId) =>
      _adNotifications
          .where((n) => n.recipientId == memberId)
          .toList()
        ..sort((a, b) => b.sentAt.compareTo(a.sentAt));

  int unreadAdNotificationCount(String memberId) =>
      _adNotifications
          .where((n) => n.recipientId == memberId && !n.isRead)
          .length;

  void markAdNotificationRead(String notificationId) {
    final idx = _adNotifications.indexWhere((n) => n.id == notificationId);
    if (idx == -1) return;
    _adNotifications[idx] = _adNotifications[idx].copyWith(isRead: true);
    notifyListeners();
  }

  String _fmtAmount(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  // ════════════════════════════════════════════════════════
  //  후원(Sponsor) 시스템
  // ════════════════════════════════════════════════════════

  // 샘플 데이터: 현재 월 기준 동적 계산 (항상 현재 활성화 상태 유지)
  static DateTime _thisMonth() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, 1);
  }

  List<SponsorApplication> _sponsorApplications =
      _createDefaultSponsorApplications();

  static List<SponsorApplication> _createDefaultSponsorApplications() => [
    // 샘플: 현재 후원 중 (다다치과) — 이번달부터 3개월
    SponsorApplication(
      id: 'sp1',
      clubId: 'c1',
      clubName: '강남 골프회',
      applicantId: 'user_me',
      applicantName: '홍길동',
      sponsorName: '다다치과',
      description: '강남구 소재 치과. 회원 대상 첫 방문 20% 할인 제공',
      landingUrl: 'https://dadaclinic.kr',
      amount: 300000,
      durationMonths: 3,
      startMonth: _thisMonth(),                          // ← 앱 시작 시 현재 월
      status: SponsorStatus.active,
      appliedAt: DateTime(DateTime.now().year, DateTime.now().month, 1).subtract(const Duration(days: 20)),
      paidAt: DateTime(DateTime.now().year, DateTime.now().month, 1).subtract(const Duration(days: 10)),
      paidAmount: 300000,
    ),
  ];

  // ── Getters ──────────────────────────────────────────────

  List<SponsorApplication> sponsorApplicationsForClub(String clubId) =>
      _sponsorApplications.where((s) => s.clubId == clubId).toList();

  List<SponsorApplication> mySponsorApplications(String applicantId) =>
      _sponsorApplications.where((s) => s.applicantId == applicantId).toList();

  List<SponsorApplication> pendingSponsorsForClub(String clubId) =>
      _sponsorApplications
          .where((s) => s.clubId == clubId && s.status == SponsorStatus.pending)
          .toList();

  /// 현재 게재 중인 후원사 목록 (모임 홈 뱃지 표시용)
  List<SponsorApplication> activeSponsorsForClub(String clubId) {
    final now = DateTime.now();
    final list = _sponsorApplications
        .where((s) =>
            s.clubId == clubId &&
            s.status == SponsorStatus.active &&
            s.isActiveOn(now))
        .toList();
    // 노출 우선순위: ① 총 후원금 큰 순 ② 계약기간(개월) 긴 순 ③ 시작일 빠른 순
    list.sort((a, b) {
      final byAmount = b.amount.compareTo(a.amount);
      if (byAmount != 0) return byAmount;
      final byDuration = b.durationMonths.compareTo(a.durationMonths);
      if (byDuration != 0) return byDuration;
      return a.startMonth.compareTo(b.startMonth);
    });
    return list;
  }

  int get totalPendingSponsors =>
      _sponsorApplications.where((s) => s.status == SponsorStatus.pending).length;

  // ── Actions ──────────────────────────────────────────────

  void applyForSponsor(SponsorApplication sp) {
    _sponsorApplications.add(sp);
    // 총무에게 알림
    _adNotifications.add(AdNotification(
      id: 'adn_sp_${DateTime.now().millisecondsSinceEpoch}',
      recipientId: 'treasurer',
      title: '[후원 신청] ${sp.sponsorName}',
      body: '${sp.applicantName}님이 ${sp.clubName}에 "${sp.sponsorName}" 후원을 신청했습니다.\n'
          '금액: ${_fmtAmount(sp.amount)}원 · ${sp.durationMonths}개월\n검토 후 승인/거절 해주세요.',
      sentAt: DateTime.now(),
      adApplicationId: sp.id,
    ));
    notifyListeners();
  }

  void approveSponsor(String spId) {
    final idx = _sponsorApplications.indexWhere((s) => s.id == spId);
    if (idx == -1) return;
    final sp = _sponsorApplications[idx];
    _sponsorApplications[idx] =
        sp.copyWith(status: SponsorStatus.approved, reviewedAt: DateTime.now());
    _adNotifications.add(AdNotification(
      id: 'adn_sp_appr_${DateTime.now().millisecondsSinceEpoch}',
      recipientId: sp.applicantId,
      title: '[후원 승인] ${sp.sponsorName}',
      body: '${sp.clubName}의 후원 신청이 승인됐습니다!\n'
          '${_fmtAmount(sp.amount)}원을 결제하시면 후원사 뱃지가 게재됩니다.',
      sentAt: DateTime.now(),
      adApplicationId: sp.id,
    ));
    notifyListeners();
  }

  void rejectSponsor(String spId, String reason) {
    final idx = _sponsorApplications.indexWhere((s) => s.id == spId);
    if (idx == -1) return;
    final sp = _sponsorApplications[idx];
    _sponsorApplications[idx] = sp.copyWith(
        status: SponsorStatus.rejected,
        rejectReason: reason,
        reviewedAt: DateTime.now());
    _adNotifications.add(AdNotification(
      id: 'adn_sp_rej_${DateTime.now().millisecondsSinceEpoch}',
      recipientId: sp.applicantId,
      title: '[후원 거절] ${sp.sponsorName}',
      body: '${sp.clubName}의 후원 신청이 거절됐습니다.\n사유: $reason',
      sentAt: DateTime.now(),
      adApplicationId: sp.id,
    ));
    notifyListeners();
  }

  /// 결제 완료 → 수입 90% 자동 등록 + 즉시 active (공식후원사 자동 등록)
  void markSponsorPaid(String spId) {
    final idx = _sponsorApplications.indexWhere((s) => s.id == spId);
    if (idx == -1) return;
    final sp = _sponsorApplications[idx];
    final now = DateTime.now();
    // 결제 완료 즉시 active 상태로 전환 (총무 확인 불필요)
    _sponsorApplications[idx] = sp.copyWith(
      status: SponsorStatus.active,
      paidAt: now,
      paidAmount: sp.amount,
    );
    // 후원금 90% → 모임 수입 자동 등록
    _transactions.add(Transaction(
      id: 'tx_sp_${now.millisecondsSinceEpoch}',
      type: TxType.income,
      amount: sp.clubRevenue,
      category: '공식후원',
      title: '후원금 수입 - ${sp.sponsorName} (${sp.durationMonths}개월)',
      date: now,
      recordedBy: '시스템',
      source: TxSource.sponsor,
      clubId: sp.clubId,
    ));
    // 신청자에게 활성화 알림
    _adNotifications.add(AdNotification(
      id: 'adn_sp_active_${now.millisecondsSinceEpoch}',
      recipientId: sp.applicantId,
      title: '[후원 시작] ${sp.sponsorName}',
      body: '결제가 완료되어 ${sp.clubName}의 공식 후원사로 등록되었습니다! '
            '모임 홈에서 후원사 배지를 확인하세요.',
      sentAt: now,
      adApplicationId: sp.id,
    ));
    notifyListeners();
  }

  void activateSponsor(String spId) {
    final idx = _sponsorApplications.indexWhere((s) => s.id == spId);
    if (idx == -1) return;
    _sponsorApplications[idx] =
        _sponsorApplications[idx].copyWith(status: SponsorStatus.active);
    notifyListeners();
  }

  void extendSponsor(String spId, int extraMonths) {
    final idx = _sponsorApplications.indexWhere((s) => s.id == spId);
    if (idx == -1) return;
    final original = _sponsorApplications[idx];
    final newSp = SponsorApplication(
      id: 'sp_ext_${DateTime.now().millisecondsSinceEpoch}',
      clubId: original.clubId,
      clubName: original.clubName,
      applicantId: original.applicantId,
      applicantName: original.applicantName,
      sponsorName: original.sponsorName,
      description: original.description,
      landingUrl: original.landingUrl,
      amount: original.amount,
      durationMonths: extraMonths,
      startMonth: original.endMonth,
      status: SponsorStatus.pending,
      appliedAt: DateTime.now(),
    );
    _sponsorApplications.add(newSp);
    _adNotifications.add(AdNotification(
      id: 'adn_sp_ext_${DateTime.now().millisecondsSinceEpoch}',
      recipientId: 'treasurer',
      title: '[후원 연장 신청] ${original.sponsorName}',
      body: '${original.applicantName}님이 "${original.sponsorName}" 후원 연장을 신청했습니다.\n'
          '연장: ${newSp.startMonth.month}월부터 ${extraMonths}개월',
      sentAt: DateTime.now(),
      adApplicationId: newSp.id,
    ));
    notifyListeners();
  }

  // ════════════════════════════════════════════════════════
  //  멤버십 포인트 시스템
  //  · 라운딩 참석 +10, 회비 정시납부 +5, 댓글/공지 참여 +2
  //  · 후원사 인사 +2, 노쇼 -10
  // ════════════════════════════════════════════════════════

  // 포인트 이벤트 기록 (memberId → 이벤트 목록)
  final Map<String, List<MembershipPointEvent>> _pointEvents = {
    'm1': [
      MembershipPointEvent(type: MembershipPointType.roundAttendance, points: 10, desc: '5월 월례회 참석', date: DateTime(2025, 5, 20)),
      MembershipPointEvent(type: MembershipPointType.roundAttendance, points: 10, desc: '4월 월례회 참석', date: DateTime(2025, 4, 15)),
      MembershipPointEvent(type: MembershipPointType.duesOnTime, points: 5, desc: '5월 회비 정시납부', date: DateTime(2025, 5, 1)),
      MembershipPointEvent(type: MembershipPointType.commentActivity, points: 2, desc: '공지 참여', date: DateTime(2025, 5, 10)),
      MembershipPointEvent(type: MembershipPointType.sponsorGreeting, points: 2, desc: '후원사 감사인사', date: DateTime(2025, 5, 15)),
    ],
    'm2': [
      MembershipPointEvent(type: MembershipPointType.roundAttendance, points: 10, desc: '5월 월례회 참석', date: DateTime(2025, 5, 20)),
      MembershipPointEvent(type: MembershipPointType.duesOnTime, points: 5, desc: '5월 회비 정시납부', date: DateTime(2025, 5, 1)),
      MembershipPointEvent(type: MembershipPointType.noShow, points: -10, desc: '4월 노쇼', date: DateTime(2025, 4, 15)),
    ],
    'm3': [
      MembershipPointEvent(type: MembershipPointType.roundAttendance, points: 10, desc: '5월 월례회 참석', date: DateTime(2025, 5, 20)),
      MembershipPointEvent(type: MembershipPointType.duesOnTime, points: 5, desc: '5월 회비 정시납부', date: DateTime(2025, 5, 1)),
      MembershipPointEvent(type: MembershipPointType.commentActivity, points: 2, desc: '댓글 활동', date: DateTime(2025, 5, 8)),
      MembershipPointEvent(type: MembershipPointType.sponsorGreeting, points: 2, desc: '후원사 감사인사', date: DateTime(2025, 5, 12)),
    ],
    'm4': [
      MembershipPointEvent(type: MembershipPointType.roundAttendance, points: 10, desc: '5월 월례회 참석', date: DateTime(2025, 5, 20)),
      MembershipPointEvent(type: MembershipPointType.duesOnTime, points: 5, desc: '5월 회비 정시납부', date: DateTime(2025, 5, 1)),
    ],
    'm5': [
      MembershipPointEvent(type: MembershipPointType.roundAttendance, points: 10, desc: '5월 월례회 참석', date: DateTime(2025, 5, 20)),
    ],
  };

  /// 같은 사람의 포인트 키 (auth id / m_creator / currentMember 혼용 보정)
  Set<String> _membershipPointKeysFor(String memberId) {
    final keys = <String>{memberId};
    final creatorId = 'm_creator_${selectedClub.id}';
    final meIds = <String>{
      currentUserId,
      if (currentMember != null) currentMember!.id,
      creatorId,
      if (_persistAuthUserId != null) _persistAuthUserId!,
    };
    if (meIds.contains(memberId)) {
      keys.addAll(meIds);
    }
    // 생성자 레코드면 auth/creator 키도 합산
    if (memberId == creatorId || memberId.startsWith('m_creator_')) {
      keys.add(creatorId);
      keys.add(currentUserId);
      if (_persistAuthUserId != null) keys.add(_persistAuthUserId!);
    }
    return keys;
  }

  /// 특정 회원의 올해 멤버십 포인트 합산
  int getMembershipPoints(String memberId) {
    final now = DateTime.now();
    var sum = 0;
    for (final key in _membershipPointKeysFor(memberId)) {
      final events = _pointEvents[key] ?? const <MembershipPointEvent>[];
      for (final e in events) {
        if (e.date.year == now.year) sum += e.points;
      }
    }
    return sum;
  }

  /// 선택 모임 활성 회원 포인트 랭킹 (내림차순)
  List<MapEntry<String, int>> get memberPointsRanking {
    final result = <MapEntry<String, int>>[];
    for (final m in activeMembers) {
      result.add(MapEntry(m.id, getMembershipPoints(m.id)));
    }
    result.sort((a, b) => b.value.compareTo(a.value));
    return result;
  }

  Member? memberById(String memberId) {
    return activeMembers.where((m) => m.id == memberId).firstOrNull ??
        _members.where((m) => m.id == memberId).firstOrNull;
  }

  void _syncAttendancePoints({
    required String memberId,
    required String scheduleId,
    required String scheduleTitle,
    required String? prev,
    required String response,
  }) {
    final tag = '|$scheduleId';
    final events = _pointEvents[memberId] ?? [];
    if (response == '참석' && prev != '참석') {
      final already = events.any((e) =>
          e.type == MembershipPointType.roundAttendance &&
          e.points > 0 &&
          e.desc.contains(tag));
      if (!already) {
        addMembershipPoint(
          memberId: memberId,
          type: MembershipPointType.roundAttendance,
          points: 10,
          desc: '$scheduleTitle 참석$tag',
        );
      }
    } else if (prev == '참석' && response == '불참') {
      final alreadyDeducted = events.any((e) =>
          e.points < 0 && e.desc.contains(tag));
      if (!alreadyDeducted) {
        addMembershipPoint(
          memberId: memberId,
          type: MembershipPointType.noShow,
          points: -10,
          desc: '$scheduleTitle 불참 변경$tag',
        );
      }
    }
  }

  /// 포인트 적립 (클럽 회원 id 기준으로 저장 + 즉시 영속화)
  void addMembershipPoint({
    required String memberId,
    required MembershipPointType type,
    required int points,
    required String desc,
  }) {
    // 가능하면 현재 클럽 멤버 id로 정규화
    final canonical = (memberId == currentUserId ||
            memberId == _persistAuthUserId)
        ? (currentMember?.id ?? memberId)
        : memberId;
    _pointEvents.putIfAbsent(canonical, () => []);
    _pointEvents[canonical]!.add(MembershipPointEvent(
      type: type,
      points: points,
      desc: desc,
      date: DateTime.now(),
    ));
    notifyListeners();
    _persistImmediately();
  }

  // ════════════════════════════════════════════════════════
  //  시상 결과 저장
  //  · scheduleId별 수상 기록 관리
  //  · 회원별 올해 시상 횟수 계산
  // ════════════════════════════════════════════════════════

  final List<AwardRecord> _awardRecords = [
    AwardRecord(
      id: 'ar1',
      scheduleId: 's3',
      scheduleName: '5월 월례회',
      awardName: '메달리스트',
      awardIcon: '🥇',
      winnerIds: ['m1'],
      winnerNames: ['홍길동'],
      recordedAt: DateTime(2025, 5, 20),
    ),
    AwardRecord(
      id: 'ar2',
      scheduleId: 's3',
      scheduleName: '5월 월례회',
      awardName: '니어리스트',
      awardIcon: '🎯',
      winnerIds: ['m3'],
      winnerNames: ['이영희'],
      recordedAt: DateTime(2025, 5, 20),
    ),
    AwardRecord(
      id: 'ar3',
      scheduleId: 's3',
      scheduleName: '5월 월례회',
      awardName: '롱기스트',
      awardIcon: '🏌️',
      winnerIds: ['m2', 'm4'],
      winnerNames: ['김철수', '박민준'],
      recordedAt: DateTime(2025, 5, 20),
    ),
  ];

  List<AwardRecord> get allAwardRecords => List.unmodifiable(_awardRecords);

  /// 특정 회원의 올해 시상 횟수
  int getMemberAwardCount(String memberId) {
    final now = DateTime.now();
    return _awardRecords
        .where((r) => r.winnerIds.contains(memberId) && r.recordedAt.year == now.year)
        .length;
  }

  /// 시상 기록 저장
  void saveAwardRecord(AwardRecord record) {
    _awardRecords.removeWhere(
        (r) => r.scheduleId == record.scheduleId && r.awardName == record.awardName);
    _awardRecords.add(record);
    // 수상자에게 포인트 적립 (없으면 추가)
    for (final winnerId in record.winnerIds) {
      addMembershipPoint(
        memberId: winnerId,
        type: MembershipPointType.roundAttendance,
        points: 0,  // 시상 포인트는 별도 운영
        desc: '${record.awardName} 수상',
      );
    }
    notifyListeners();
  }

  // ════════════════════════════════════════════════════════
  //  후원사 감사인사 피드
  //  · ThankYouMessage: 보낸 사람, 후원사, 메시지, 시각
  // ════════════════════════════════════════════════════════

  final List<ThankYouMessage> _thankYouMessages = [
    ThankYouMessage(
      id: 'ty1',
      senderId: 'm1',
      senderName: '홍길동',
      sponsorName: '골프존마켓',
      message: '항상 좋은 골프용품 제공해 주셔서 감사합니다! 덕분에 이번 라운드도 즐거웠습니다 😊',
      createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 2)),
    ),
    ThankYouMessage(
      id: 'ty2',
      senderId: 'm3',
      senderName: '이영희',
      sponsorName: '스카이72골프장',
      message: '그린피 할인 혜택 정말 감사해요! 다음 라운딩도 기대됩니다 ⛳',
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 5)),
    ),
    ThankYouMessage(
      id: 'ty3',
      senderId: 'm2',
      senderName: '김철수',
      sponsorName: '골프존마켓',
      message: '회원들을 위해 후원해 주셔서 진심으로 감사드립니다. 앞으로도 잘 부탁드립니다!',
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
    ),
  ];

  List<ThankYouMessage> get thankYouMessages =>
      List.unmodifiable(_thankYouMessages..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  /// 감사인사 추가
  void addThankYouMessage({
    required String senderId,
    required String senderName,
    required String sponsorName,
    required String message,
  }) {
    _thankYouMessages.add(ThankYouMessage(
      id: 'ty_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      senderName: senderName,
      sponsorName: sponsorName,
      message: message,
      createdAt: DateTime.now(),
    ));
    // 후원사 인사 포인트 +2 적립
    addMembershipPoint(
      memberId: senderId,
      type: MembershipPointType.sponsorGreeting,
      points: 2,
      desc: '$sponsorName 감사인사',
    );
    notifyListeners();
  }

  // ════════════════════════════════════════════════════════
  //  총무 인수인계
  //  · 현 총무 → 일반, 신규 총무 → 총무로 역할 교체
  // ════════════════════════════════════════════════════════

  /// 총무 인수인계 실행 — 기존 총무→정회원, 신규→총무 (알림 타겟 즉시 전환)
  ///
  /// 회장/부회장이 첫 총무를 선임할 때는 본인 직책을 정회원으로 내리지 않는다.
  /// (과거 버그: 총무 공석 시 currentTreasurerId=본인 → 회장이 정회원으로 강등)
  void transferTreasurer({
    required String currentTreasurerId,
    required String newTreasurerId,
  }) {
    clearTreasurerVacant(selectedClub.id);
    final clubId = selectedClub.id;
    final me = currentMember;
    final selfIds = {
      currentUserId,
      if (me != null) me.id,
      'm_creator_$clubId',
    };

    final previousTreasurerIds = _members
        .where((m) => ClubMemberRole.isTreasurer(m.role))
        .map((m) => m.id)
        .toSet();
    final hadTreasurer = previousTreasurerIds.isNotEmpty;
    // 실제 총무만 강등 대상. 공석 선임 시 넘긴 currentUserId는 무시.
    final demoteIds = hadTreasurer
        ? {
            ...previousTreasurerIds,
            if (currentTreasurerId.isNotEmpty) currentTreasurerId
          }
        : <String>{};

    String stripTreasurer(String role) => ClubMemberRole.encodeRoles(
          ClubMemberRole.splitRoles(role)
              .where((r) => r != ClubMemberRole.treasurer),
        );
    String withTreasurer(String role) => ClubMemberRole.encodeRoles([
          ...ClubMemberRole.splitRoles(role)
              .where((r) => r != ClubMemberRole.guest),
          ClubMemberRole.treasurer,
        ]);

    for (var i = 0; i < _members.length; i++) {
      final m = _members[i];
      if (m.id == newTreasurerId) continue;
      if (demoteIds.contains(m.id) && ClubMemberRole.isTreasurer(m.role)) {
        // 회장·총무 → 회장 유지 (총무만 해제)
        _members[i] = m.copyWith(role: stripTreasurer(m.role));
      }
    }

    // 신규 총무 (기존 회장/부회장 직책 유지 + 총무 겸직)
    final newIdx = _members.indexWhere((m) => m.id == newTreasurerId);
    if (newIdx != -1) {
      final prev = _members[newIdx];
      _members[newIdx] = prev.copyWith(
        role: withTreasurer(prev.role),
        memberType: ClubMemberRole.regular,
      );
    }

    // 내 모임 myRole 동기화
    final myIdx = _myClubs.indexWhere((c) => c.id == clubId);
    if (myIdx != -1) {
      final iAmNew = selfIds.contains(newTreasurerId);
      final iWasTreasurer = selfIds.any(demoteIds.contains) ||
          (me != null && previousTreasurerIds.contains(me.id));
      if (iAmNew) {
        _myClubs[myIdx] = _myClubs[myIdx].copyWith(
          myRole: withTreasurer(_myClubs[myIdx].myRole),
        );
      } else if (iWasTreasurer && hadTreasurer) {
        // 총무만 해제 — 회장·부회장 겸직은 유지
        if (ClubMemberRole.isTreasurer(_myClubs[myIdx].myRole)) {
          _myClubs[myIdx] = _myClubs[myIdx].copyWith(
            myRole: stripTreasurer(_myClubs[myIdx].myRole),
          );
        }
      }
    }

    final newMember = newIdx != -1 ? _members[newIdx] : null;
    if (newMember != null) {
      _activities.insert(0, ActivityItem(
        id: 'act_transfer_${DateTime.now().millisecondsSinceEpoch}',
        memberId: newTreasurerId,
        memberName: newMember.name,
        activityType: 'role_change',
        description: '총무 인수인계 완료 — ${newMember.name}님이 새 총무가 되었습니다',
        timestamp: DateTime.now(),
      ));

      // 대기 중인 가입 신청 알림의 수신 대상을 새 총무로 전환
      for (var i = 0; i < _appNotifications.length; i++) {
        final n = _appNotifications[i];
        if (n.type == AppNotificationType.joinRequest &&
            n.clubId == clubId &&
            !n.isRead) {
          _appNotifications[i] = AppNotification(
            id: n.id,
            type: n.type,
            clubId: n.clubId,
            clubName: n.clubName,
            title: n.title,
            body: n.body,
            isAdmin: n.isAdmin,
            isRead: n.isRead,
            createdAt: n.createdAt,
            targetId: n.targetId,
            targetUserId: newTreasurerId,
          );
        }
      }

      addAppNotification(AppNotification(
        id: 'noti_transfer_${DateTime.now().millisecondsSinceEpoch}',
        type: AppNotificationType.announcement,
        clubId: clubId,
        clubName: selectedClub.name,
        title: '총무 인수인계',
        body: '${newMember.name}님이 새 총무로 지정되었습니다. 이후 가입 신청 알림은 새 총무에게 전달됩니다.',
        createdAt: DateTime.now(),
        targetUserId: newTreasurerId,
        isRead: false,
      ));
    }
    notifyListeners();
    _persistImmediately();
  }

  /// 총무 인수인계/선임 진입 — 총무·회장, 또는 총무 공석 시 회장·부회장
  bool get canAccessTreasurerTransfer {
    final role = selectedClub.myRole;
    final memberRole = currentMember?.role ?? '';
    if (ClubMemberRole.canTransferTreasurer(role) ||
        ClubMemberRole.canTransferTreasurer(memberRole)) {
      return true;
    }
    final isPres = role == ClubMemberRole.president ||
        role == ClubMemberRole.vicePresident ||
        memberRole == ClubMemberRole.president ||
        memberRole == ClubMemberRole.vicePresident;
    if ((isSelectedTreasurerVacant || !hasActiveTreasurer()) && isPres) {
      return true;
    }
    return false;
  }

  /// 직책 불일치 복구 — 선택 모임 명단의 본인 role ↔ Club.myRole
  ///
  /// 전역 시드(m1 role=일반)로 회장 myRole을 덮어쓰지 않는다.
  void syncMyRoleFromMemberRoster() {
    final clubId = selectedClub.id;
    final myIdx = _myClubs.indexWhere((c) => c.id == clubId);
    if (myIdx == -1) return;

    final clubMembers = membersForClub(clubId);
    final creatorId = 'm_creator_$clubId';
    final creator =
        clubMembers.where((m) => m.id == creatorId).firstOrNull;
    final me = currentMember;
    final isCreator = isSelectedClubCreator ||
        (me != null && me.id == creatorId) ||
        (creator != null &&
            (selectedClub.creatorId.isEmpty ||
                _userIdsMatch(selectedClub.creatorId, currentUserId)));

    // 모임 스코프 명단을 소스로 사용 (전역 시드 m1 제외)
    Member? source = me;
    if (creator != null && isCreator) {
      if (source == null ||
          source.id != creator.id ||
          !ClubMemberRole.isOfficer(source.role)) {
        source = creator;
      }
    }
    if (source == null) return;

    final clubRole = _myClubs[myIdx].myRole;
    var role = ClubMemberRole.encodeRoles(
      ClubMemberRole.splitRoles(source.role),
    );

    // 클럽이 이미 임원인데 소스만 정회원인 경우:
    // · 신규(생성) 모임 + 생성자 → 명단(선택 직책)을 신뢰하고 클럽 myRole을 맞춤
    // · 레거시 데모 모임 → 시드(일반)가 회장 myRole을 덮지 않도록 명단을 클럽에 맞춤
    if (ClubMemberRole.isOfficer(clubRole) &&
        !ClubMemberRole.isOfficer(role)) {
      if (isFreshClub(clubId) && isCreator) {
        // fall through — apply `role`(정회원 등) to Club.myRole
      } else if (creator != null) {
        final mIdx = _members.indexWhere((m) => m.id == creator.id);
        if (mIdx != -1 && _members[mIdx].role != clubRole) {
          _members[mIdx] = _members[mIdx].copyWith(role: clubRole);
          notifyListeners();
          _persistImmediately();
        }
        return;
      }
    }

    if (_myClubs[myIdx].myRole == role) return;
    _myClubs[myIdx] = _myClubs[myIdx].copyWith(myRole: role);
    final allIdx = _allClubs.indexWhere((c) => c.id == clubId);
    if (allIdx != -1) {
      _allClubs[allIdx] = _allClubs[allIdx].copyWith(myRole: role);
    }
    notifyListeners();
    _persistImmediately();
  }

  // ════════════════════════════════════════════════════════
  //  라운딩 대기 등록 시스템
  //  · 정원 초과 시 대기 등록
  //  · 취소자 발생 시 대기자 자동 알림
  // ════════════════════════════════════════════════════════

  final List<WaitingEntry> _waitingList = [];

  List<WaitingEntry> get waitingList => List.unmodifiable(_waitingList);

  List<WaitingEntry> waitingListForSchedule(String scheduleId) =>
      _waitingList.where((w) => w.scheduleId == scheduleId).toList()
        ..sort((a, b) => a.registeredAt.compareTo(b.registeredAt));

  /// 대기 등록
  void addToWaitingList({
    required String scheduleId,
    required String memberId,
    required String memberName,
  }) {
    // 이미 대기 중인지 확인
    if (_waitingList.any((w) => w.scheduleId == scheduleId && w.memberId == memberId)) {
      return;
    }
    _waitingList.add(WaitingEntry(
      id: 'wl_${DateTime.now().millisecondsSinceEpoch}',
      scheduleId: scheduleId,
      memberId: memberId,
      memberName: memberName,
      registeredAt: DateTime.now(),
      status: WaitingStatus.waiting,
    ));
    notifyListeners();
  }

  /// 대기 취소
  void cancelWaiting(String waitingId) {
    _waitingList.removeWhere((w) => w.id == waitingId);
    notifyListeners();
  }

  /// 대기자 알림 (취소자 발생 시 첫 번째 대기자에게 알림 발송 시뮬레이션)
  void notifyFirstWaiting(String scheduleId) {
    final waiters = waitingListForSchedule(scheduleId)
        .where((w) => w.status == WaitingStatus.waiting)
        .toList();
    if (waiters.isEmpty) return;
    final firstWaiter = waiters.first;
    final idx = _waitingList.indexWhere((w) => w.id == firstWaiter.id);
    if (idx != -1) {
      _waitingList[idx] = WaitingEntry(
        id: firstWaiter.id,
        scheduleId: firstWaiter.scheduleId,
        memberId: firstWaiter.memberId,
        memberName: firstWaiter.memberName,
        registeredAt: firstWaiter.registeredAt,
        status: WaitingStatus.notified,
        notifiedAt: DateTime.now(),
      );
    }
    // 푸시 알림 시뮬레이션
    final schedule = scheduleById(scheduleId);
    addAppNotification(AppNotification(
      id: 'noti_wl_${DateTime.now().millisecondsSinceEpoch}',
      type: AppNotificationType.announcement,
      clubId: schedule?.clubId ?? selectedClub.id,
      clubName: selectedClub.name,
      title: '참석 가능 알림',
      body:
          '${schedule?.title ?? '라운딩'}에 자리가 생겼습니다. 참석으로 응답하면 확정됩니다.',
      createdAt: DateTime.now(),
      targetUserId: firstWaiter.memberId,
      isRead: false,
    ));
    notifyListeners();
  }

  /// 대기자가 참석으로 확정할 때 대기 상태 → accepted
  void _acceptWaitingIfAny(String scheduleId, String memberId) {
    final idx = _waitingList.indexWhere(
      (w) =>
          w.scheduleId == scheduleId &&
          w.memberId == memberId &&
          (w.status == WaitingStatus.waiting ||
              w.status == WaitingStatus.notified),
    );
    if (idx == -1) return;
    final w = _waitingList[idx];
    _waitingList[idx] = WaitingEntry(
      id: w.id,
      scheduleId: w.scheduleId,
      memberId: w.memberId,
      memberName: w.memberName,
      registeredAt: w.registeredAt,
      status: WaitingStatus.accepted,
      notifiedAt: w.notifiedAt,
    );
  }

  void _cancelWaitingIfAny(String scheduleId, String memberId) {
    _waitingList.removeWhere(
      (w) =>
          w.scheduleId == scheduleId &&
          w.memberId == memberId &&
          (w.status == WaitingStatus.waiting ||
              w.status == WaitingStatus.notified),
    );
  }

  /// 확정 참석 인원이 정원(팀수×4, 또는 그 이상 maxCapacity)에 찼는지
  bool isAttendanceFull(String scheduleId, {String? excludingMemberId}) {
    final s = scheduleById(scheduleId);
    if (s == null) return false;
    final confirmed = s.responses
        .where((r) =>
            r.response == '참석' &&
            (excludingMemberId == null || r.memberId != excludingMemberId))
        .length;
    return confirmed >= s.effectiveCapacity;
  }

  /// 저장된 일정의 테스트용 과소 maxCapacity 제거
  void _scrubUndersizedScheduleCapacities() {
    for (var i = 0; i < _schedules.length; i++) {
      final s = _schedules[i];
      if (s.maxCapacity != null && s.maxCapacity! < s.teamCount * 4) {
        _schedules[i] = s.copyWith(clearMaxCapacity: true);
      }
    }
  }

  /// 구버전 시드 제목의 연도만 현재로 맞춘다. 납부 내역은 절대 지우지 않는다.
  void _normalizeStaleDuesSeed() {
    final now = DateTime.now();
    final y = now.year;
    final monthly = _duesSettings.where((d) => d.id == 'ds1').firstOrNull;
    if (monthly == null) return;
    if (monthly.title.contains('$y년')) return;
    final looksLikeBuiltInSeed = _duesSettings.isNotEmpty &&
        _duesSettings.every((d) => RegExp(r'^ds\d+$').hasMatch(d.id));
    if (!looksLikeBuiltInSeed) return;

    for (var i = 0; i < _duesSettings.length; i++) {
      final d = _duesSettings[i];
      var title = d.title;
      title = title.replaceAllMapped(
        RegExp(r'(\d{4})년'),
        (_) => '$y년',
      );
      if (title == d.title && d.id == 'ds1' && !title.contains('$y년')) {
        title = '$y년 월회비';
      }
      if (title != d.title) {
        _duesSettings[i] = d.copyWith(title: title);
      }
    }
    // 납부(_duesPayments)·신청(_paymentRequests)은 유지
  }

  /// clubId 없는 회비 설정에 현재 선택 모임을 붙여 동기화·표시에서 빠지지 않게 한다.
  void _stampOrphanDuesClubIds() {
    if (_myClubs.isEmpty) return;
    final clubId = selectedClub.id;
    for (var i = 0; i < _duesSettings.length; i++) {
      final d = _duesSettings[i];
      if (d.clubId == null || d.clubId!.isEmpty) {
        _duesSettings[i] = d.copyWith(clubId: clubId);
      }
    }
  }

  /// clubId 없는 회비 수입 거래에 현재 모임을 붙여 잔고에 잡히게 한다.
  void _stampOrphanTransactionClubIds() {
    if (_myClubs.isEmpty) return;
    final clubId = selectedClub.id;
    final settingIds = _duesSettings
        .where((d) => d.clubId == null || clubIdAliases(clubId).contains(d.clubId))
        .map((d) => d.id)
        .toSet();
    final paymentIds = _duesPayments
        .where((p) => settingIds.contains(p.duesSettingId))
        .map((p) => p.id)
        .toSet();
    for (var i = 0; i < _transactions.length; i++) {
      final t = _transactions[i];
      if (t.clubId != null && t.clubId!.isNotEmpty) continue;
      final linked = t.duesPaymentId != null &&
          paymentIds.contains(t.duesPaymentId);
      final duesSource = t.source == TxSource.dues ||
          t.source == TxSource.openingBalance ||
          t.source == TxSource.carryover;
      if (linked || (duesSource && _selectedHasLegacyMock)) {
        _transactions[i] = Transaction(
          id: t.id,
          type: t.type,
          amount: t.amount,
          category: t.category,
          title: t.title,
          memo: t.memo,
          date: t.date,
          recordedBy: t.recordedBy,
          source: t.source,
          duesPaymentId: t.duesPaymentId,
          clubId: clubId,
        );
      }
    }
  }

  static List<DuesSetting> _seedDuesSettings() {
    final now = DateTime.now();
    final y = now.year;
    return [
      DuesSetting(
        id: 'ds1',
        type: DuesType.monthly,
        amount: 50000,
        title: '$y년 월회비',
        description: '매월 말일까지 납부',
        createdAt: DateTime(y, 1, 1),
        isActive: true,
        startMonth: 3,
        endMonth: 11,
        startYear: y,
        endYear: y,
        dueDayOfMonth: 25,
      ),
      DuesSetting(
        id: 'ds2',
        type: DuesType.special,
        amount: 100000,
        title: '상반기 골프대회 특별회비',
        description: '대회 운영비',
        createdAt: DateTime(y, 5, 1),
        isActive: true,
        dueDate: DateTime(y, 5, 15),
      ),
      DuesSetting(
        id: 'ds3',
        type: DuesType.annual,
        amount: 300000,
        title: '$y년 연회비',
        description: '연 1회 납부',
        createdAt: DateTime(y, 1, 1),
        isActive: true,
        year: y,
        dueDate: DateTime(y, 3, 1),
      ),
      DuesSetting(
        id: 'ds4',
        type: DuesType.annual,
        amount: 300000,
        title: '${y - 1}년 연회비',
        description: '',
        createdAt: DateTime(y - 1, 1, 1),
        isActive: false,
        year: y - 1,
        dueDate: DateTime(y - 1, 3, 1),
      ),
    ];
  }

  static List<DuesPayment> _seedDuesPayments() {
    final now = DateTime.now();
    final y = now.year;
    // 납부 기간(3~11월) 안에서 현재/직전 월 샘플
    final curMonth = now.month.clamp(3, 11);
    final prevMonth = curMonth == 3 ? 3 : curMonth - 1;
    final membersPaidCur = [
      ('m1', '홍길동'),
      ('m2', '김철수'),
      ('m3', '이영희'),
      ('m6', '정다은'),
      ('m7', '강동원'),
      ('m8', '윤서준'),
    ];
    final membersPaidPrev = [
      ('m1', '홍길동'),
      ('m2', '김철수'),
      ('m3', '이영희'),
      ('m4', '박민준'),
      ('m5', '최수연'),
      ('m6', '정다은'),
      ('m7', '강동원'),
      ('m8', '윤서준'),
    ];
    final list = <DuesPayment>[];
    var i = 1;
    for (final (id, name) in membersPaidPrev) {
      list.add(DuesPayment(
        id: 'dp${i++}',
        memberId: id,
        memberName: name,
        duesSettingId: 'ds1',
        amount: 50000,
        paidAt: DateTime(y, prevMonth, 5),
        recordedBy: '이영희',
      ));
    }
    for (final (id, name) in membersPaidCur) {
      list.add(DuesPayment(
        id: 'dp${i++}',
        memberId: id,
        memberName: name,
        duesSettingId: 'ds1',
        amount: 50000,
        paidAt: DateTime(y, curMonth, 4),
        recordedBy: '이영희',
      ));
    }
    // 특별회비 일부 납부
    for (final (id, name) in [
      ('m1', '홍길동'),
      ('m2', '김철수'),
      ('m3', '이영희'),
      ('m6', '정다은'),
      ('m7', '강동원'),
    ]) {
      list.add(DuesPayment(
        id: 'dp${i++}',
        memberId: id,
        memberName: name,
        duesSettingId: 'ds2',
        amount: 100000,
        paidAt: DateTime(y, 5, 20),
        recordedBy: '이영희',
      ));
    }
    return list;
  }

  static List<PaymentRequest> _seedPaymentRequests() {
    final now = DateTime.now();
    final y = now.year;
    final m = now.month.clamp(3, 11);
    return [
      PaymentRequest(
        id: 'pr1',
        memberId: 'm4',
        memberName: '박민준',
        duesSettingId: 'ds1',
        duesTitle: '$y년 월회비',
        amount: 50000,
        year: y,
        month: m,
        memo: '방금 이체했습니다 :)',
        status: PaymentRequestStatus.pending,
        requestedAt: now.subtract(const Duration(minutes: 30)),
      ),
      PaymentRequest(
        id: 'pr2',
        memberId: 'm5',
        memberName: '최수연',
        duesSettingId: 'ds1',
        duesTitle: '$y년 월회비',
        amount: 50000,
        year: y,
        month: m,
        memo: '토스로 보냈어요',
        status: PaymentRequestStatus.pending,
        requestedAt: now.subtract(const Duration(hours: 1)),
      ),
    ];
  }
}

class LeaveClubResult {
  final bool success;
  final bool treasurerVacated;
  const LeaveClubResult({
    required this.success,
    required this.treasurerVacated,
  });
}
