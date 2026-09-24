import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/repositories/club_repository.dart';
import '../data/repositories/mock/mock_data_store.dart';
import '../data/repositories/mock/mock_store_persistence.dart';
import '../di/app_dependencies.dart';
import '../domain/services/app_data_bootstrap_service.dart';
import '../domain/services/club_discovery_service.dart';
import '../domain/services/demo_finance_strip.dart';
import '../domain/services/group_assignment_service.dart';
import '../domain/services/join_request_service.dart';
import '../domain/services/club_name_policy.dart';
import '../domain/services/official_member_count.dart';
import '../domain/data/sample_club_filter.dart';
import '../domain/services/roster_dedupe.dart';
import '../models/club_model.dart';
import '../models/user_model.dart';
import 'auth_provider.dart';
import '../models/member_role.dart';
import '../services/club_data_codec.dart';
import '../services/club_ops_sync.dart';
import '../services/d1_alimtalk_flush.dart';
import '../services/club_persistence.dart';
import '../services/firebase_auth_bridge.dart';
import '../services/hq_alimtalk_catalog.dart';
import '../services/hq_push_catalog.dart';
import '../services/member_phone_index.dart';
import '../services/push_notification_service.dart';
import '../services/shared_join_request_store.dart';
import '../services/solapi_service.dart';
import '../utils/d1_enqueue_policy.dart';
import '../utils/dues_d1_schedule.dart';
import '../utils/past_schedule_import.dart';

// ════════════════════════════════════════════════════════════
//  ClubProvider
// ════════════════════════════════════════════════════════════
class ClubProvider extends ChangeNotifier with WidgetsBindingObserver {
  String? _persistAuthUserId;
  bool _suppressPersist = false;
  /// 이번 실행에서 서버 멤버십을 읽었으면, 그 목록 밖의 모임은 다시 넣지 않는다.
  bool _serverClubsAligned = false;
  final Set<String> _confirmedClubIds = {};
  bool _applyingCloudOps = false;
  /// 설정에서 고친 모임 정보. pull/watch 가 옛 번들을 넣어도 되돌리지 않는다.
  final Map<String, Club> _clubInfoOverrides = {};
  String? _watchingClubId;
  String? _watchingMembersClubId;
  StreamSubscription<List<Member>>? _memberWatchSub;
  Timer? _persistTimer;
  Timer? _cloudPushTimer;

  ClubProvider() {
    _normalizeScheduleTitles();
    _syncAllNextRounds();
    WidgetsBinding.instance.addObserver(this);
    PushNotificationService.onD1AlimtalkHint = flushDueD1Alimtalk;
    AuthProvider.onRemoteProfileHydrated = _applyHydratedAuthProfile;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _persistTimer?.cancel();
    _cloudPushTimer?.cancel();
    ClubOpsSync.stopAllWatches();
    unawaited(_memberWatchSub?.cancel());
    if (AuthProvider.onRemoteProfileHydrated == _applyHydratedAuthProfile) {
      AuthProvider.onRemoteProfileHydrated = null;
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(HqPushCatalog.load());
    unawaited(HqAlimtalkCatalog.load());
    _syncAllNextRounds();
    unawaited(_enqueueAllUpcomingD1());
    unawaited(syncAllDuesD1Reminders());
    notifyListeners();
  }

  static String _monthlyTitle(DateTime date, String name) =>
      '${date.month}월 $name';

  /// 신규 생성 모임 — mock 데이터 미적용
  final Set<String> _freshClubIds = {};

  /// 이 세션에서 방금 만든 모임. 저장하지 않는다.
  /// 카탈로그에 아직 없어도 내 모임에서 빼면 안 된다.
  final Set<String> _sessionCreatedClubIds = {};

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
  DateTime? _accountBirthDate;
  double? _accountHandicap;
  String? _accountGender;
  String? _accountPhone;
  String? _accountPhotoUrl;

  String get currentUserId   => _currentUserId;
  String get currentUserName => _currentUserName;

  /// 계정 프로필로 명단 행을 채운다. 모임이 바뀌어도 사진·전화·타수가 따라간다.
  Member _selfMember({
    required String id,
    required String name,
    required String memberType,
    required String role,
    DateTime? joinDate,
    String? referrerId,
    String? referrerName,
    Member? inherit,
  }) {
    final g = inherit?.gender;
    final gender = (g != null && g.isNotEmpty)
        ? g
        : (_accountGender != null && _accountGender!.isNotEmpty
            ? _accountGender!
            : '남');
    return Member(
      id: id,
      name: name,
      gender: gender,
      birthDate: inherit?.birthDate ?? _accountBirthDate,
      photoUrl: inherit?.photoUrl ?? _accountPhotoUrl,
      phone: inherit?.phone ?? _accountPhone,
      memberType: memberType,
      role: role,
      handicap: inherit?.handicap ?? _accountHandicap,
      joinDate: joinDate ?? inherit?.joinDate ?? DateTime.now(),
      status: '활성',
      referrerId: referrerId ?? inherit?.referrerId,
      referrerName: referrerName ?? inherit?.referrerName,
    );
  }

  /// 데모 시드 계정 이름. 실계정 명단에 이게 남아 있으면 잘못 저장된 것이다.
  static const seedMemberNames = {'홍길동', '이민준', '박민준'};

  /// 찌꺼기 정리 때 남의 이름이 내 행에 남은 경우. 본인 계정이 아니면 덮어쓴다.
  static const leftoverStolenNames = {'장창현'};

  /// 소셜 로그인이 이름을 못 받아왔을 때 임시로 넣는 이름들.
  static const _genericMemberNames = {
    '회원',
    '카카오 회원',
    'Google 회원',
    'Apple 회원',
  };

  /// 테스터 실모임 명단에는 시드 이름(홍길동 등)을 절대 보여 주지 않는다.
  static Member withoutSeedDisplayName(Member m) {
    if (!seedMemberNames.contains(m.name.trim())) return m;
    return m.copyWith(name: '회원');
  }

  /// 실제 이름으로 덮어써도 되는(= 사람이 입력한 값이 아닌) 이름인지.
  static bool isPlaceholderMemberName(String name) {
    final t = name.trim();
    return t.isEmpty ||
        t == '-' ||
        RegExp(r'^[A-Za-z]$').hasMatch(t) ||
        seedMemberNames.contains(t) ||
        _genericMemberNames.contains(t);
  }

  /// 실계정용 표시 이름. 비었거나 시드 이름이면 '회원'으로 둔다.
  /// 여기서 시드 이름을 그대로 통과시키면 잘못된 이름을 다시 심는 꼴이다.
  static String _realDisplayName(String? displayName) {
    final t = (displayName ?? '').trim();
    if (t.isEmpty || seedMemberNames.contains(t)) return '회원';
    return t;
  }

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
  /// 이름·이미지·지역 등 카탈로그 필드는 서버 값을 따른다.
  /// 일정 기준 D-day와 이미 있는 직책은 로컬을 유지한다.
  void hydrateFromBootstrap(
    AppBootstrapSnapshot snapshot, {
    List<JoinRequest> pendingRequests = const [],
  }) {
    _suppressPersist = true;
    final keepSelectedId = _selectedClubIdOrNull();

    for (final bootClub in snapshot.myClubs) {
      final legacy = _clubFromBootstrap(bootClub);
      // 서버가 내 모임으로 준 것은 로컬 탈퇴보다 앞선다. 초대 가입이 다시 안 뜨던 원인.
      _leftClubIds.removeWhere(
        (id) =>
            clubIdAliases(legacy.id).contains(id) ||
            clubIdAliases(bootClub.id).contains(id),
      );
      final idx = _myClubs.indexWhere((c) => c.id == legacy.id);
      if (idx >= 0) {
        final existing = _myClubs[idx];
        // 설정에서 고친 이름·소개·사진·지역·업종·팀수는 서버 옛값으로 덮지 않는다.
        _myClubs[idx] = existing.copyWith(
          myRole: existing.myRole.trim().isNotEmpty
              ? existing.myRole
              : legacy.myRole,
          memberCount: legacy.memberCount,
          nextRoundDate: existing.nextRoundDate,
          nextRoundCourse: existing.nextRoundCourse,
          creatorId: existing.creatorId.trim().isNotEmpty
              ? existing.creatorId
              : legacy.creatorId,
        );
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
      } else {
        final existing = _allClubs[idx];
        _allClubs[idx] = existing.copyWith(
          myRole: existing.myRole,
          memberCount: legacy.memberCount,
          nextRoundDate: existing.nextRoundDate,
          nextRoundCourse: existing.nextRoundCourse,
        );
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
    _restoreSelectedClubId(keepSelectedId);

    // 일정 기준 D-day로 맞춤 (bootstrap 템플릿 날짜로 덮지 않음)
    _syncAllNextRounds();
    _applyClubInfoOverrides();
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
      final bootUrl = bootClub.imageUrl?.trim() ?? '';
      return template.copyWith(
        name: bootClub.name.trim().isNotEmpty ? bootClub.name : template.name,
        imageUrl: bootUrl.isNotEmpty ? bootClub.imageUrl : template.imageUrl,
        myRole: forCatalog ? template.myRole : bootClub.myRole,
        memberCount: bootClub.memberCount,
        teamCount: bootClub.teamCount,
        region: bootClub.region,
        industry: bootClub.industry,
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
  ///
  /// [displayName] 은 실제 로그인 계정의 이름. 시드 계정이 아닌데 이걸 안 넘기면
  /// 명단에 '홍길동'이 박힌다. 호출부는 `auth.currentUser?.name` 을 같이 준다.
  ///
  /// [birthDate]·[handicap]·[gender]·[phone]·[photoUrl] 은 계정에 저장된 값.
  /// 가입 때 입력해도 그 시점에 모임이 없으면 명단에 안 붙는다. 로그인할 때마다
  /// 다시 흘려 넣어야 나중에 만든 모임에서도 사진·전화·평균타수가 따라간다.
  Future<void> switchUser(
    String authUserId, {
    String? displayName,
    DateTime? birthDate,
    double? handicap,
    String? gender,
    String? phone,
    String? photoUrl,
  }) async {
    _persistAuthUserId = authUserId;
    _serverClubsAligned = false;
    _confirmedClubIds.clear();
    _sessionCreatedClubIds.clear();
    _clubInfoOverrides.clear();
    _accountBirthDate = birthDate;
    _accountHandicap = handicap;
    _accountGender = gender;
    _accountPhone = phone;
    _accountPhotoUrl = photoUrl;
    await _loadLeftClubIds(authUserId);
    await _loadConfirmedClubIds(authUserId);
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
      case 'default':
        _currentUserId = 'm1';
        _currentUserName = '홍길동';
        _myClubs.clear();
        break;
      default:
        // 실계정은 카카오/구글/애플 id 그대로. m1 을 쓰면
        // 다른 회원(m_{모임}_m1)이 "나"가 된다.
        _currentUserId = authUserId;
        _currentUserName = _realDisplayName(displayName);
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
          bio: '강남 골프회 회원입니다. 평균타수 18로 꾸준히 실력 향상 중입니다.',
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

    // 복구 후에도 탈퇴 목록은 제외. 서버 소속 조회는 홈 연 뒤에.
    _myClubs.removeWhere((c) => _isLeftClub(c.id));

    // 예전 빌드가 '홍길동'으로 저장해 둔 내 명단 행을 실제 이름으로 되돌린다.
    // ensureCreatorMembers 보다 먼저 — 아래에서 새로 만드는 행도 같은 이름을 쓴다.
    repairMyDisplayName(_currentUserName);
    if (_purgeHongGilDongFromRealClubs()) _persistImmediately();
    if (_scrubSeedAuthorNames()) _persistImmediately();

    // 항상 실제 일정 기준으로 D-day 재동기화
    _syncAllNextRounds();
    // 신규 모임에 생성자 회원이 누락된 경우 복구 (회비·회원 목록)
    ensureCreatorMembers();
    // 계정의 생년월일·핸디를 명단에 반영 — 방금 만든 생성자 행도 포함해야 하므로
    // ensureCreatorMembers 다음이다. 핸디가 비면 자동 조편성이 초보로 잡는다.
    syncAuthGolfProfile(
      birthDate: birthDate,
      handicap: handicap,
      gender: gender,
      phone: phone,
      photoUrl: photoUrl,
    );
    if (pruneDuplicateRosterRows()) _persistImmediately();
    if (_repairCopiedIdentityOnLegacyM1Rows()) _persistImmediately();
    _syncSelfDisplayName();
    _applyRosterRolesToMyClubs();
    // 데모 모임(c1~c5) 회원수 — 과거에 저장된 임의값이 남아있어도 실제 명단 기준으로 교정
    _reconcileLegacyMemberCounts();
    _reconcileLiveMemberCounts();
    // 내 모임 → Mock 저장소(어드민·모임찾기) 강제 동기화
    _syncMyClubsToMockStore();

    // 홈은 저장된 내 모임을 바로 보여 준다. 서버 소속 정리는 뒤에서.
    notifyListeners();
    if (AppDependencies.instance.isInitialized &&
        AppDependencies.instance.isOfflineMockMode) {
      await _afterSwitchUserCloud();
    } else {
      unawaited(_afterSwitchUserCloud());
    }
  }

  Future<void> _afterSwitchUserCloud() async {
    final authUserId = _persistAuthUserId;
    if (authUserId == null) return;

    final deps = AppDependencies.instance;
    if (deps.isInitialized && !deps.isOfflineMockMode) {
      try {
        await FirebaseAuthBridge.ensureSignedIn(
          AppUser(
            id: authUserId,
            name: _currentUserName,
            phone: (_accountPhone ?? '').trim(),
          ),
        );
      } catch (e) {
        debugPrint('[ClubProvider] auth bridge skip: $e');
      }
    }

    try {
      var recovered = await _restoreOwnedClubsFromStores(authUserId);
      if (!_isDemoSession) {
        if (_purgeDemoIdentityClubs()) recovered = true;
        _stripHardcodedDemoPayload();
        await _claimClubsByPhone(authUserId);
        if (await _replaceMyClubsFromServerMemberships(authUserId)) {
          recovered = true;
        }
        if (_purgeDemoIdentityClubs()) recovered = true;
        if (await _pruneForeignClubs(authUserId)) recovered = true;
      }
      _myClubs.removeWhere((c) => _isLeftClub(c.id));
      if (recovered) {
        await _persistNow();
      }
      ensureCreatorMembers();
      syncAuthGolfProfile(
        birthDate: _accountBirthDate,
        handicap: _accountHandicap,
        gender: _accountGender,
        phone: _accountPhone,
        photoUrl: _accountPhotoUrl,
      );
    } catch (e) {
      debugPrint('[ClubProvider] afterSwitch align skip: $e');
    } finally {
      notifyListeners();
      unawaited(_pushMyProfileToAllClubMemberDocs());
    }

    try {
      await mergeSharedJoinRequests();
      await refreshJoinRequestInbox();
      _purgeDemoSeedNotifications();
      await HqPushCatalog.load();
      _rebindPushIdsIfChanged();
      await _pullCloudOpsForMyClubs();
      if (!_isDemoSession && authUserId.isNotEmpty) {
        await _replaceMyClubsFromServerMemberships(authUserId);
      }
      _watchSelectedClubOps();
      unawaited(_enqueueAllUpcomingD1());
      unawaited(syncAllDuesD1Reminders());
      unawaited(_pushOwnedClubCatalog());
    } catch (e) {
      debugPrint('[ClubProvider] afterSwitch sync skip: $e');
    }
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
          seedIfMissing: _iAmClubCreator(club),
        );
        if (merged != null) bundle = merged;
      }
      _importBundle(bundle);
      if (!_isDemoSession) {
        _purgeDemoIdentityClubs();
        _stripHardcodedDemoPayload();
        if (authUserId.isNotEmpty) {
          await _pruneForeignClubs(authUserId);
        }
      }
      for (final club in List<Club>.from(_myClubs)) {
        await _hydrateRosterFromServer(club.id);
      }
      _purgeHongGilDongFromRealClubs();
      _scrubUndersizedScheduleCapacities();
      _syncAllNextRounds();
      _reconcileLiveMemberCounts();
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
        unawaited(_hydrateRosterFromServer(clubId));
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
    _watchSelectedClubMembers();
  }

  void _watchSelectedClubMembers() {
    if (_myClubs.isEmpty) return;
    if (!AppDependencies.instance.isInitialized ||
        AppDependencies.instance.isOfflineMockMode) {
      return;
    }
    final clubId = selectedClub.id;
    if (_watchingMembersClubId == clubId) return;
    unawaited(_memberWatchSub?.cancel());
    _watchingMembersClubId = clubId;
    _memberWatchSub = AppDependencies.instance.memberRepository
        .watchMembers(clubId)
        .listen((remote) {
      unawaited(_mergeRemoteRoster(clubId, remote));
    }, onError: (e) {
      debugPrint('[ClubProvider] watch members $clubId skip: $e');
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
        _members.map((m) =>
            '${m.id}:${m.name}:${m.status}:${m.photoUrl ?? ''}:${m.birthDate?.millisecondsSinceEpoch ?? 0}')
            .join(',');
    // 댓글 수 포함 — 다른 기기가 댓글을 달면 공지 개수는 그대로라 놓쳤다.
    final announcePart =
        _announcements.map((a) => '${a.id}:${a.comments.length}').join(',');
    // 포인트 포함 — 이게 없으면 원격 동기화로 포인트만 바뀔 때
    // 랭킹 화면이 갱신되지 않아 "포인트가 안 오른다"로 보인다.
    final pointPart = _pointEvents.entries
        .map((e) => '${e.key}:${e.value.length}')
        .join(',');
    return '$photoPart|$schedPart|$duesPart|$waitPart|'
        '$announcePart|$memberPart|$pointPart';
  }

  static String _leftClubsPrefsKey(String authUserId) =>
      'rounder_left_clubs_v2_$authUserId';

  static String _confirmedClubsPrefsKey(String authUserId) =>
      'rounder_confirmed_clubs_v1_$authUserId';

  Future<void> _loadConfirmedClubIds(String authUserId) async {
    _confirmedClubIds.clear();
    if (_isDemoSession) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_confirmedClubsPrefsKey(authUserId));
      if (list == null) return;
      _confirmedClubIds.addAll(list.where((id) => id.trim().isNotEmpty));
    } catch (e) {
      debugPrint('[ClubProvider] load confirmed clubs skip: $e');
    }
  }

  Future<void> _saveConfirmedClubIds(String authUserId) async {
    if (_isDemoSession) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _confirmedClubsPrefsKey(authUserId),
        _confirmedClubIds.toList(),
      );
    } catch (e) {
      debugPrint('[ClubProvider] save confirmed clubs skip: $e');
    }
  }

  /// 내 모임은 서버 가입만. 폰에 남은 목록은 멤버십이 아니다.
  void _applyMembershipOnlyMyClubs() {
    if (_isDemoSession) return;
    _myClubs.removeWhere((c) =>
        !_confirmedClubIds.contains(c.id) &&
        !_sessionCreatedClubIds.contains(c.id));
    if (_selectedClubIndex >= _myClubs.length) _selectedClubIndex = 0;
  }

  void _rememberOfficialClub(String clubId) {
    if (clubId.trim().isEmpty || _isDemoSession) return;
    _confirmedClubIds.add(clubId);
    final auth = _persistAuthUserId;
    if (auth != null) unawaited(_saveConfirmedClubIds(auth));
  }

  Future<void> _loadLeftClubIds(String authUserId) async {
    _leftClubIds.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
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
                roundScores: List<RoundScoreRecord>.from(bundle.roundScores),
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
    await _claimClubsByPhone(authId);
    var recovered = await _restoreOwnedClubsFromStores(authId);
    if (await _replaceMyClubsFromServerMemberships(authId)) recovered = true;
    if (await _pruneForeignClubs(authId)) recovered = true;
    // 복구 성공 여부와 관계없이 동기화·저장 (멤버십 별칭 보정 포함)
    _syncMyClubsToMockStore();
    if (recovered) _persistImmediately();
    notifyListeners();
  }

  /// 실계정도 currentUserId 가 m1 이라, persist 키로만 데모 세션을 가린다.
  bool get _isDemoSession {
    final id = _persistAuthUserId ?? '';
    return id == 'user_me' ||
        id == 'user_guest' ||
        id == 'user_other' ||
        id == 'default';
  }

  bool _iAmClubCreator(Club club) {
    final cid = club.creatorId.trim();
    if (_persistAuthUserId != null &&
        cid.isNotEmpty &&
        _userIdsMatch(cid, _persistAuthUserId)) {
      return true;
    }
    if (_isDemoSession &&
        (cid.isEmpty || _userIdsMatch(cid, currentUserId))) {
      return true;
    }
    return false;
  }

  Set<String> _authAliases(String authUserId) {
    final ids = <String>{authUserId};
    if (authUserId == 'user_guest' || authUserId == 'mg1') {
      ids.addAll({'user_guest', 'mg1'});
    } else if (authUserId == 'user_me' ||
        authUserId == 'default' ||
        authUserId == 'm1') {
      ids.addAll({'user_me', 'm1'});
    } else if (authUserId == 'user_other' || authUserId == 'm4') {
      ids.addAll({'user_other', 'm4'});
    }
    // 데모만 currentUserId(m1/mg1)를 별칭에 넣는다.
    if (_isDemoSession) ids.add(currentUserId);
    return ids;
  }

  bool _isStoreClubOwnedByMe(
    MockDataStore store,
    Club c,
    Set<String> aliases,
  ) {
    if (aliases.contains(c.creatorId)) return true;
    if (aliases.any((id) => store.isMember(c.id, id))) return true;

    if (!_isDemoSession) return false;
    // 데모 계정만 이름 매칭. 실계정이 홍길동 명단에 걸려 전 모임이 복구되던 경로.
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

    // 1) Mock 공유 저장소 — 데모 계정만. 실계정은 폰에 남은 시드가 전 모임으로 복구된다.
    final store = AppDependencies.instance.mockDataStore;
    if (_isDemoSession && store != null) {
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

    // 2) 계정 번들 — 데모 계정만 user_guest / user_me 를 훑는다.
    // 실계정은 로컬 creatorId 를 믿지 않는다. 장창현 찌꺼기가 방장 id 를
    // 훔치면 강남·평촌이 내 모임으로 복구된다.
    final bundleUids = _isDemoSession
        ? <String>{authUserId, 'user_guest', 'user_me', 'user_other'}
        : const <String>{};
    for (final uid in bundleUids) {
      try {
        final bundle = await ClubPersistence.load(uid);
        if (bundle == null) continue;
        // 실계정은 allClubs(탐색 카탈로그)를 후보로 쓰지 않는다.
        // 카탈로그에 남의 모임이 다 들어 있어서 전 모임이 내 모임으로 붙었다.
        final candidates = _isDemoSession
            ? [...bundle.myClubs, ...bundle.allClubs]
            : bundle.myClubs;
        for (final c in candidates) {
          if (!c.id.startsWith('c_')) continue;
          final mine = aliases.contains(c.creatorId) ||
              (_isDemoSession &&
                  uid == authUserId &&
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

    // 3) Prefs 전수 스캔 — 데모 계정만
    if (_isDemoSession) {
      try {
        if (await _restoreOwnedClubsFromRawPrefs(aliases, authUserId)) {
          changed = true;
        }
      } catch (e) {
        debugPrint('[ClubProvider] raw prefs restore skip: $e');
      }
    }

    // 4) 서버 멤버십만. 카탈로그 생성자·모임찾기 열람은 내 모임이 아니다.
    if (await _ingestServerMemberships(authUserId)) changed = true;

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
    } else {
      final i = _myClubs.indexWhere((c) => c.id == club.id);
      final cur = _myClubs[i];
      if (cur.creatorId.trim().isEmpty && club.creatorId.trim().isNotEmpty) {
        _myClubs[i] = cur.copyWith(creatorId: club.creatorId);
        changed = true;
      }
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
        club.id.startsWith('c_') &&
        _iAmClubCreator(club)) {
      _members.add(_selfMember(
        id: creatorId,
        name: currentUserName,
        memberType: '정회원',
        role: ClubMemberRole.normalize(
          club.myRole.trim().isEmpty ? '회장' : club.myRole,
        ),
        joinDate: club.createdAt,
      ));
      changed = true;
    }
    return changed;
  }

  Future<bool> _ingestServerMemberships(String authUserId) async {
    var changed = false;
    try {
      final remote = await AppDependencies.instance.clubRepository
          .fetchMyClubs(authUserId);
      for (final c in remote) {
        if (SampleClubFilter.isSample(id: c.id, name: c.name)) continue;
        if (_ingestOwnedClub(c, const [])) changed = true;
        _confirmedClubIds.add(c.id);
        _leftClubIds.removeWhere((id) => clubIdAliases(c.id).contains(id));
      }
    } catch (e) {
      debugPrint('[ClubProvider] ingest fetchMyClubs skip: $e');
    }
    return changed;
  }

  /// 원클럽과 같이 내 모임 = 서버 소속. 폰 목록을 기준으로 지우지 않는다.
  Future<bool> _replaceMyClubsFromServerMemberships(String authUserId) async {
    if (_isDemoSession) return false;
    List<Club> remote;
    try {
      remote = await AppDependencies.instance.clubRepository
          .fetchMyClubs(authUserId);
    } catch (e) {
      debugPrint('[ClubProvider] replace my clubs skip: $e');
      return false;
    }
    remote = [
      for (final c in remote)
        if (!SampleClubFilter.isSample(id: c.id, name: c.name)) c,
    ];
    for (final c in remote) {
      _leftClubIds.removeWhere((id) => clubIdAliases(c.id).contains(id));
    }
    final keepById = {for (final c in _myClubs) c.id: c};
    final next = <Club>[];
    final seen = <String>{};
    for (final c in remote) {
      if (!seen.add(c.id)) continue;
      final local = keepById[c.id];
      next.add(
        local == null
            ? c
            : local.copyWith(
                myRole: c.myRole.trim().isNotEmpty ? c.myRole : local.myRole,
                creatorId: c.creatorId.trim().isNotEmpty
                    ? c.creatorId
                    : local.creatorId,
                memberCount: c.memberCount,
              ),
      );
    }
    for (final c in _myClubs) {
      if (_sessionCreatedClubIds.contains(c.id) && seen.add(c.id)) {
        next.add(c);
      }
    }
    final before = _myClubs.map((c) => c.id).toSet();
    final after = next.map((c) => c.id).toSet();
    _myClubs
      ..clear()
      ..addAll(next);
    _confirmedClubIds
      ..clear()
      ..addAll(after);
    _serverClubsAligned = true;
    if (_selectedClubIndex >= _myClubs.length) _selectedClubIndex = 0;
    final auth = _persistAuthUserId;
    if (auth != null) {
      unawaited(_saveLeftClubIds(auth));
      unawaited(_saveConfirmedClubIds(auth));
    }
    return before != after;
  }

  bool _purgeDemoIdentityClubs() {
    if (_isDemoSession) return false;
    const demoCreators = {
      'user_me',
      'm1',
      'user_guest',
      'mg1',
      'user_other',
      'm4',
    };
    final drop = <String>{};
    for (final c in _myClubs) {
      if (SampleClubFilter.isSample(id: c.id, name: c.name)) {
        drop.add(c.id);
        continue;
      }
      final cid = c.creatorId.trim();
      if (demoCreators.contains(cid)) drop.add(c.id);
    }
    if (drop.isEmpty) return false;
    _myClubs.removeWhere((c) => drop.contains(c.id));
    _allClubs.removeWhere((c) => drop.contains(c.id));
    _freshClubIds.removeAll(drop);
    _members.removeWhere((m) {
      for (final id in drop) {
        if (m.id == 'm_creator_$id' || m.id.startsWith('m_${id}_')) {
          return true;
        }
      }
      return false;
    });
    _schedules.removeWhere((s) => drop.contains(s.clubId));
    debugPrint('[ClubProvider] purged demo-identity clubs $drop');
    return true;
  }

  /// 번호로 이어 붙은 모임 → 그 모임에서 내 명단 행 id.
  final Map<String, String> _claimedRosterIds = {};

  /// 번호 색인으로 잘못 만든 소속만 지운다.
  ///
  /// 만든 사람 · 초대 수락 · 가입 승인만 내 모임이다. 번호가 같다고
  /// 소속을 만들면 가입하지 않은 모임이 내 모임에 붙는다.
  Future<bool> _claimClubsByPhone(String authUserId) async {
    if (_isDemoSession || authUserId.trim().isEmpty) return false;
    await MemberPhoneIndex.revokeSpuriousPhoneMemberships(
      userId: authUserId,
      phone: _accountPhone,
    );
    return false;
  }

  /// 예전 초대 가입자는 명단 행 id 가 `m_{모임}_m1` 로 남아 계정 ID 로 못 찾는다.
  /// 그 사람을 명단에서 빼면 안 되니 전화번호로 한 번 더 본다.
  bool _clubRosterHasMyPhone(String clubId) {
    final mine = MemberPhoneIndex.digitsOf(_accountPhone);
    if (mine.isEmpty) return false;
    return _members.any((m) =>
        Member.isClubRosterId(clubId, m.id) &&
        MemberPhoneIndex.digitsOf(m.phone) == mine);
  }

  /// 서버 멤버십이 없는 모임을 내 모임에서 뺀다.
  ///
  /// 멤버십 조회가 실패하면 아무것도 지우지 않는다. 조회에 성공하면
  /// 가입(만든 사람 · 초대 수락 · 가입 승인)이 있는 모임과 방금 만든 모임만 남긴다.
  /// 카탈로그 생성자·폰 명단·모임찾기 열람은 남기는 이유가 아니다.
  Future<bool> _pruneForeignClubs(String authUserId) async {
    if (_isDemoSession || _myClubs.isEmpty) return false;
    if (!AppDependencies.instance.isInitialized) return false;

    final repo = AppDependencies.instance.clubRepository;
    List<Club> serverMine;
    try {
      serverMine = await repo.fetchMyClubs(authUserId);
    } catch (e) {
      debugPrint('[ClubProvider] prune skip (멤버십 조회 실패): $e');
      return false;
    }

    final mineIds = serverMine.map((c) => c.id).toSet();

    final drop = <String>{};
    for (final c in List<Club>.from(_myClubs)) {
      if (_legacyMockClubIds.contains(c.id)) continue;
      if (mineIds.contains(c.id)) continue;
      if (_sessionCreatedClubIds.contains(c.id)) continue;
      drop.add(c.id);
    }
    _serverClubsAligned = true;
    _confirmedClubIds
      ..clear()
      ..addAll([
        for (final c in _myClubs)
          if (!drop.contains(c.id)) c.id,
        ...mineIds,
      ]);
    final auth = _persistAuthUserId;
    if (auth != null) unawaited(_saveConfirmedClubIds(auth));
    if (drop.isEmpty) return false;

    _myClubs.removeWhere((c) => drop.contains(c.id));
    _freshClubIds.removeAll(drop);
    // 명단·일정은 그 모임 것만 지운다. 회비·거래는 모임 키가 없는 레거시가 섞여 있어 건드리지 않는다.
    _members.removeWhere((m) {
      for (final id in drop) {
        if (Member.isClubRosterId(id, m.id)) return true;
      }
      return false;
    });
    _schedules.removeWhere((s) => drop.contains(s.clubId));
    if (_selectedClubIndex >= _myClubs.length) _selectedClubIndex = 0;
    debugPrint('[ClubProvider] pruned foreign clubs $drop');
    notifyListeners();
    return true;
  }

  /// 예전 빌드가 폰에 저장해 둔 홍길동 회비·사진·광고 시드를 실계정에서 지운다.
  void _stripHardcodedDemoPayload() {
    if (_isDemoSession) return;
    _members.removeWhere((m) =>
        DemoFinanceStrip.isGhostName(m.name) ||
        DemoFinanceStrip.isGhostMemberId(m.id) ||
        m.id == 'm4');
    _photos.removeWhere((p) =>
        p.clubId == 'c1' ||
        const {'p1', 'p2', 'p3', 'p4', 'p5', 'p6'}.contains(p.id));
    _transactions.removeWhere((t) =>
        DemoFinanceStrip.isSeedTransaction(id: t.id, clubId: t.clubId) ||
        DemoFinanceStrip.isHongGilDongGhost(t.title));
    for (var i = 0; i < _transactions.length; i++) {
      final t = _transactions[i];
      final nextTitle = DemoFinanceStrip.rewriteLedgerTitle(t.title);
      if (nextTitle == t.title) continue;
      _transactions[i] = Transaction(
        id: t.id,
        type: t.type,
        amount: t.amount,
        category: t.category,
        title: nextTitle,
        memo: t.memo,
        date: t.date,
        recordedBy: t.recordedBy,
        source: t.source,
        duesPaymentId: t.duesPaymentId,
        clubId: t.clubId,
      );
    }
    final realClubIds = {
      for (final c in _myClubs)
        if (!SampleClubFilter.isSample(id: c.id, name: c.name) &&
            !_legacyMockClubIds.contains(c.id))
          c.id,
    };
    _duesSettings.removeWhere((d) =>
        d.clubId == null && RegExp(r'^ds\d+$').hasMatch(d.id));
    _duesPayments.removeWhere((p) => DemoFinanceStrip.isSeedDuesPayment(
          id: p.id,
          memberId: p.memberId,
          inRealClub: realClubIds.isNotEmpty,
        ));
    _paymentRequests.removeWhere((r) => r.id == 'pr1' || r.id == 'pr2');
    _adApplications.removeWhere((a) =>
        a.clubId == 'c1' || a.id == 'ad1' || a.id == 'ad2');
    _sponsorApplications.removeWhere((s) =>
        s.clubId == 'c1' || s.id == 'sp1');
    _pointEvents.removeWhere((id, _) =>
        id == 'm1' ||
        id == 'mg1' ||
        id == 'm4' ||
        RegExp(r'^m\d+$').hasMatch(id));
    _awardRecords.removeWhere((r) => r.id.startsWith('ar') && r.scheduleId == 's3');
    _thankYouMessages.removeWhere((t) =>
        t.id == 'ty1' || t.id == 'ty2' || t.id == 'ty3');
    _allClubs.removeWhere(
      (c) => SampleClubFilter.isSample(id: c.id, name: c.name),
    );
  }

  Future<void> _hydrateRosterFromServer(String clubId) async {
    if (clubId.isEmpty || SampleClubFilter.isSample(id: clubId)) return;
    if (!AppDependencies.instance.isInitialized ||
        AppDependencies.instance.isOfflineMockMode) {
      return;
    }
    try {
      final remote = await AppDependencies.instance.memberRepository
          .fetchMembers(clubId)
          .timeout(const Duration(seconds: 8));
      await _mergeRemoteRoster(clubId, remote);
    } catch (e) {
      debugPrint('[ClubProvider] hydrate roster $clubId skip: $e');
    }
    await hydrateClubAccounts(clubId);
  }

  /// 모임 소속 계정 목록을 받아 둔다. 푸시 대상 계산에 쓴다.
  Future<void> hydrateClubAccounts(String clubId) async {
    if (clubId.isEmpty || !AppDependencies.instance.isInitialized) return;
    try {
      final accounts = await AppDependencies.instance.clubRepository
          .fetchClubMemberAccounts(clubId)
          .timeout(const Duration(seconds: 8));
      if (accounts.isNotEmpty) {
        _clubAccounts[clubId] = accounts;
        if (_dropUnmemberedAccountRows(clubId) && !_suppressPersist) {
          _persistImmediately();
        }
      }
    } catch (e) {
      debugPrint('[ClubProvider] hydrate accounts $clubId skip: $e');
    }
  }

  /// 모임 → 소속 계정. 푸시 대상은 명단 행이 아니라 이 계정들이다.
  final Map<String, List<ClubMemberAccount>> _clubAccounts = {};

  /// 그 모임 생성자가 아닌 장창현 소셜 행은 테스터 폰에도 안 남긴다.
  /// 로컬만 가리면 서버 명단을 받는 다른 폰에는 그대로 보인다.
  bool _dropLeftoverStolenForeignRoster() {
    final clubs = <Club>[..._myClubs, ..._allClubs];
    final drop = <String>{};
    for (final m in _members) {
      for (final club in clubs) {
        if (!Member.isClubRosterId(club.id, m.id) &&
            m.id != club.creatorId.trim()) {
          continue;
        }
        if (!ClubOpsSync.isForeignLeftoverMember(
          id: m.id,
          name: m.name,
          clubId: club.id,
          creatorUserId: club.creatorId,
        )) {
          continue;
        }
        drop.add(m.id);
      }
    }
    if (drop.isEmpty) return false;
    ClubOpsSync.seedRemovedMembers(drop);
    _members.removeWhere((m) => drop.contains(m.id));
    return true;
  }

  /// 서버 소속이 없는 소셜 계정 명단 행은 지운다.
  /// 장창현이 아레나 총무로 다시 붙던 경로.
  bool _dropUnmemberedAccountRows(String clubId) {
    if (_isDemoSession || clubId.isEmpty) return false;
    if (AppDependencies.instance.isOfflineMockMode) return false;
    final accounts = _clubAccounts[clubId];
    if (accounts == null || accounts.isEmpty) return false;
    final allowed = <String>{
      for (final a in accounts)
        if (a.userId.trim().isNotEmpty) a.userId.trim(),
    };
    final creator = (_clubById(clubId)?.creatorId ?? '').trim();
    if (creator.isNotEmpty) allowed.add(creator);

    final drop = <Member>[];
    for (final m in _members) {
      if (!Member.isClubRosterId(clubId, m.id)) continue;
      if (m.id == 'm_creator_$clubId') continue;
      final prefix = 'm_${clubId}_';
      if (!m.id.startsWith(prefix)) continue;
      if (!MemberPhoneIndex.isSocialAccountRosterId(clubId, m.id)) continue;
      final suffix = m.id.substring(prefix.length);
      if (allowed.contains(suffix)) continue;
      drop.add(m);
    }
    if (drop.isEmpty) return false;
    ClubOpsSync.seedRemovedMembers(drop.map((m) => m.id));
    _members.removeWhere((m) => drop.any((d) => d.id == m.id));
    for (final m in drop) {
      final digits = MemberPhoneIndex.digitsOf(m.phone);
      if (digits.isNotEmpty) {
        unawaited(MemberPhoneIndex.removeClub(digits, clubId));
      }
    }
    return true;
  }

  /// 명단 행을 전화번호로 계정에 잇는다. 예전 행(`m1`)은 이 길로만 찾는다.
  String _accountIdByRosterPhone(String clubId, String memberId) {
    final accounts = _clubAccounts[clubId];
    if (accounts == null || accounts.isEmpty) return '';
    final row = _members.where((m) => m.id == memberId).firstOrNull;
    final digits = MemberPhoneIndex.digitsOf(row?.phone);
    if (digits.isEmpty) return '';
    for (final a in accounts) {
      if (MemberPhoneIndex.digitsOf(a.phone) == digits) return a.userId;
    }
    return '';
  }

  /// 같은 사람이 명단에 두 줄로 남는 것을 막는다.
  ///
  /// 방장이 이름·번호만 적어 둔 행이 있는 상태에서 그 사람이 초대 링크로 가입하면,
  /// 계정 id 로 새 행이 하나 더 생겨 같은 사람이 둘이 된다. (아레나 이정원 사례)
  /// 번호가 같고 **다른 계정에 연결되지 않은** 옛 행은 내 행으로 흡수한다.
  /// 포인트·회비·참석은 행 id 에 붙어 있으므로 같이 옮긴다.
  bool _absorbUnlinkedRowsByPhone(String clubId) {
    final uid = (_persistAuthUserId ?? '').trim();
    if (uid.isEmpty || _isDemoSession) return false;

    final myId = Member.rosterId(clubId, uid);
    final mineIdx = _members.indexWhere((m) => m.id == myId);
    if (mineIdx < 0) return false;

    final myPhone = MemberPhoneIndex.digitsOf(
      (_members[mineIdx].phone ?? '').trim().isNotEmpty
          ? _members[mineIdx].phone
          : _accountPhone,
    );
    if (myPhone.isEmpty) return false;

    final absorbed = <String, String>{};
    for (final m in List<Member>.from(_members)) {
      if (m.id == myId) continue;
      if (!Member.isClubRosterId(clubId, m.id)) continue;
      if (m.id == 'm_creator_$clubId') continue; // 방장 자리는 따로 처리
      if (MemberPhoneIndex.digitsOf(m.phone) != myPhone) continue;
      absorbed[m.id] = myId;
    }
    if (absorbed.isEmpty) return false;

    for (final oldId in absorbed.keys) {
      final old = _members.where((m) => m.id == oldId).firstOrNull;
      if (old == null) continue;
      final keepIdx = _members.indexWhere((m) => m.id == myId);
      _members[keepIdx] = RosterDedupe.mergeMember(_members[keepIdx], old);
      _members.removeWhere((m) => m.id == oldId);
      ClubOpsSync.markMemberRemoved(oldId);
      // 서버 명단에도 남아 있으면 다음 실행에서 다시 내려온다
      unawaited(ClubOpsSync.deleteClubMemberDoc(
        clubId,
        oldId.substring('m_${clubId}_'.length),
      ));
      debugPrint('[ClubProvider] $clubId 중복 명단 $oldId → $myId 합침');
    }
    _applyRosterIdRemap(
      clubId,
      absorbed,
      {for (final m in _members) m.id: m.name},
    );
    if (_isDemoSession) {
      _setMemberCount(clubId, _officialMemberCount(clubId));
    } else {
      unawaited(_recountOfficialMemberCount(clubId));
    }
    return true;
  }

  /// 방장 자리(`m_creator_{모임}`)에 들어가 있으면 내 자리로 옮긴다.
  ///
  /// 초대로 들어온 모임인데 예전 빌드가 내 행을 방장 자리에 만들어 두면, 서버의
  /// 진짜 방장은 "이미 있는 행"으로 취급돼 명단에 영영 안 들어온다. 모임에
  /// 회원이 여럿인데 내 폰에만 나 혼자 보이던 원인이다.
  ///
  /// 회비·시상·참석은 행 id 로 붙어 있으므로 옮길 때 같이 옮긴다.
  bool _moveMyRowOffCreatorSeat(String clubId, String creatorUserId) {
    final uid = (_persistAuthUserId ?? '').trim();
    if (uid.isEmpty || creatorUserId.isEmpty) return false;
    if (_userIdsMatch(creatorUserId, uid)) return false; // 내가 진짜 방장

    const seat = 'm_creator_';
    final seatId = '$seat$clubId';
    final seatIdx = _members.indexWhere((m) => m.id == seatId);
    if (seatIdx < 0) return false;

    final seatRow = _members[seatIdx];
    final myPhone = MemberPhoneIndex.digitsOf(_accountPhone);
    final seatPhone = MemberPhoneIndex.digitsOf(seatRow.phone);
    final looksLikeMe = (myPhone.isNotEmpty && seatPhone == myPhone) ||
        seatRow.name.trim() == _currentUserName.trim();
    if (!looksLikeMe) return false;

    final myId = Member.rosterId(clubId, uid);
    final mineIdx = _members.indexWhere((m) => m.id == myId);
    if (mineIdx >= 0) {
      // 내 행이 이미 있다 → 방장 자리에 있던 복사본은 내 행으로 합친다.
      _members[mineIdx] = RosterDedupe.mergeMember(_members[mineIdx], seatRow);
      _members.removeAt(seatIdx);
    } else {
      _members[seatIdx] = seatRow.withId(myId);
    }
    _applyRosterIdRemap(
      clubId,
      {seatId: myId},
      {for (final m in _members) m.id: m.name},
    );
    debugPrint('[ClubProvider] $clubId 방장 자리에 있던 내 행을 $myId 로 옮김');
    return true;
  }

  @visibleForTesting
  Future<void> mergeRemoteRosterForTest(String clubId, List<Member> remote) =>
      _mergeRemoteRoster(clubId, remote);

  @visibleForTesting
  ClubDataBundle exportBundleForTest() => _exportBundle();

  @visibleForTesting
  void importBundleForTest(ClubDataBundle b) => _importBundle(b);

  Future<void> _mergeRemoteRoster(String clubId, List<Member> remote) async {
    if (clubId.isEmpty || remote.isEmpty) return;
    var creatorUserId = (_clubById(clubId)?.creatorId ?? '').trim();
    if (creatorUserId.isEmpty) {
      for (final m in remote) {
        if (ClubMemberRole.hasRole(m.role, ClubMemberRole.president)) {
          creatorUserId = m.id;
          break;
        }
      }
      if (creatorUserId.isNotEmpty) {
        final i = _myClubs.indexWhere((c) => c.id == clubId);
        if (i != -1) {
          _myClubs[i] = _myClubs[i].copyWith(creatorId: creatorUserId);
        }
      }
    }
    var changed = false;
    if (_moveMyRowOffCreatorSeat(clubId, creatorUserId)) changed = true;
    for (final raw in remote) {
      final id = Member.canonicalRosterId(
        clubId: clubId,
        rawId: raw.id,
        creatorUserId: creatorUserId,
      );
      final row = id == raw.id ? raw : raw.withId(id);
      if (DemoFinanceStrip.isGhostName(row.name) ||
          DemoFinanceStrip.isGhostMemberId(id) ||
          DemoFinanceStrip.isGhostMemberId(raw.id)) {
        ClubOpsSync.markMemberRemoved(id);
        if (raw.id != id) ClubOpsSync.markMemberRemoved(raw.id);
        final ghostIdx = _members.indexWhere((m) =>
            m.id == id ||
            (m.id == raw.id && Member.isClubRosterId(clubId, m.id)));
        if (ghostIdx >= 0) {
          _members.removeAt(ghostIdx);
          changed = true;
        }
        continue;
      }
      // 다른 모임 명단 행까지 잡으면 남의 모임 회원을 여기로 옮겨 버린다.
      final idx = _members.indexWhere((m) =>
          m.id == id ||
          (m.id == raw.id && Member.isClubRosterId(clubId, m.id)));
      if (idx < 0) {
        if (ClubOpsSync.isMemberRemoved(id)) continue;
        _members.add(row);
        changed = true;
      } else if (_members[idx].id != id) {
        _members[idx] = _preferLocalMemberProfile(row, _members[idx]);
        changed = true;
      } else if (isPlaceholderMemberName(_members[idx].name) &&
          row.name.trim().isNotEmpty &&
          !isPlaceholderMemberName(row.name)) {
        _members[idx] = _preferLocalMemberProfile(row, _members[idx]);
        changed = true;
      } else {
        final kept = _preferLocalMemberProfile(row, _members[idx]);
        if ((kept.photoUrl ?? '') != (_members[idx].photoUrl ?? '') ||
            (kept.phone ?? '') != (_members[idx].phone ?? '')) {
          _members[idx] = kept;
          changed = true;
        }
      }
    }
    if (_absorbUnlinkedRowsByPhone(clubId)) changed = true;
    if (pruneDuplicateRosterRows()) changed = true;
    if (_fillMyRosterProfile()) changed = true;
    final leftoverGhosts = _members
        .where((m) =>
            Member.isClubRosterId(clubId, m.id) &&
            (DemoFinanceStrip.isGhostName(m.name) ||
                DemoFinanceStrip.isGhostMemberId(m.id)))
        .map((m) => m.id)
        .toList();
    if (leftoverGhosts.isNotEmpty) {
      ClubOpsSync.seedRemovedMembers(leftoverGhosts);
      _members.removeWhere((m) => leftoverGhosts.contains(m.id));
      changed = true;
    }
    if (!changed) return;
    _syncSelfDisplayName();
    if (_isDemoSession) {
      _setMemberCount(clubId, _officialMemberCount(clubId));
    } else {
      unawaited(_recountOfficialMemberCount(clubId));
    }
    notifyListeners();
    if (!_suppressPersist) _persistImmediately();
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
        targetUserId: notifyTarget != null
            ? _fcmInboxIdFor(notifyTarget, clubId: clubId)
            : currentUserId,
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
    // 예전 실계정이 currentUserId 를 m1 으로 저장했다. 남은 m1 기록과
    // 카카오 id 를 같은 사람으로 묶으면 다른 테스터 명단이 된다.
    return false;
  }

  /// 실계정이 m1 이던 시절에 생긴 초대 회원 명단 id.
  String _legacyM1RosterId(String clubId) => 'm_${clubId}_m1';

  bool _isLegacyM1RosterId(String memberId, {String? clubId}) {
    if (_isDemoSession) return false;
    if (memberId == 'm1') return true;
    if (clubId != null && clubId.isNotEmpty) {
      return memberId == _legacyM1RosterId(clubId);
    }
    return memberId.startsWith('m_') &&
        memberId.endsWith('_m1') &&
        !memberId.startsWith('m_creator_');
  }

  /// 명단 ID(m_creator_*, m_{clubId}_*)와 로그인 계정을 같은 사람으로 본다.
  ///
  /// 실계정 `currentUserId` 는 카카오/구글/애플 id 다. `m1` 과 같다고 보면
  /// `m_{club}_m1` 행(다른 테스터)이 전부 "나"가 되어 랭킹·댓글이 엉킨다.
  bool _isSelfTarget(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    if (_persistAuthUserId != null &&
        _userIdsMatch(id, _persistAuthUserId)) {
      return true;
    }
    if (_isDemoSession && _userIdsMatch(id, currentUserId)) {
      return true;
    }

    if (_myClubs.isEmpty) return false;
    final clubId = selectedClub.id;
    if (id == 'm_creator_$clubId') {
      return _iAmClubCreator(selectedClub);
    }
    final prefix = 'm_${clubId}_';
    if (id.startsWith(prefix)) {
      final suffix = id.substring(prefix.length);
      if (_persistAuthUserId != null &&
          _userIdsMatch(suffix, _persistAuthUserId)) {
        return true;
      }
      if (_isDemoSession && _userIdsMatch(suffix, currentUserId)) {
        return true;
      }
      return false;
    }
    // 예전 실계정 댓글·시상이 authorId=m1 으로 저장됐다. 생성자만 본인으로 본다.
    if (!_isDemoSession && id == 'm1') {
      return _iAmClubCreator(selectedClub);
    }
    return false;
  }

  /// 내 FCM 토큰을 등록할 ID 전부.
  ///
  /// 로그인 ID만 등록하면 안 된다. 발송 대상은 **명단 ID**(`m_creator_<clubId>`,
  /// `m_<clubId>_<userId>`)로 들어오고, `_fcmInboxIdFor` 가 그걸 로그인 ID로
  /// 바꿔 주는데 `Club.creatorId` 가 비어 있으면(기본값이 `''`) 매핑이 실패해
  /// 명단 ID 그대로 push_inbox 에 쌓인다. 그러면 Cloud Functions 가
  /// `no FCM token m_creator_c_...` 를 남기고 푸시가 사라진다. (실제 발생)
  ///
  /// 그래서 매핑에 기대지 않고 명단 ID로도 토큰을 등록한다.
  /// 어느 ID로 들어와도 토큰이 있으니 푸시가 도착한다.
  List<String> myPushIds() {
    final ids = <String>{
      if (_persistAuthUserId != null) _persistAuthUserId!,
      _currentUserId,
      currentUserId,
    };
    for (final club in _myClubs) {
      // 데모 모임(c1~c5)은 공유 명단이라 남의 알림을 받게 되므로 제외.
      if (_legacyMockClubIds.contains(club.id)) continue;
      if (D1EnqueuePolicy.isBlockedRecipient(
        name: club.name,
        userId: _persistAuthUserId ?? '',
        clubId: club.id,
        creatorUserId: club.creatorId,
      )) {
        continue;
      }
      ids.add('m_creator_${club.id}');
      for (final uid in {_persistAuthUserId, _currentUserId, currentUserId}) {
        if (uid == null || uid.trim().isEmpty) continue;
        final roster = Member.rosterId(club.id, uid);
        if (D1EnqueuePolicy.isBlockedRecipient(
          name: '',
          userId: roster,
          clubId: club.id,
          creatorUserId: club.creatorId,
        )) {
          continue;
        }
        ids.add(roster);
      }
    }
    final me = currentMember?.id;
    if (me != null) ids.add(me);
    return ids
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  /// 마지막으로 푸시 등록한 ID 집합. 모임이 늘면 다시 등록해야 한다.
  String _boundPushIdsSignature = '';

  /// 모임 목록이 바뀌면 토큰을 다시 등록한다.
  ///
  /// 모임을 새로 만들거나 초대로 가입하면 명단 ID가 생기는데,
  /// 로그인 시점에 등록한 목록에는 그게 없어서 그 모임 알림만 안 왔다.
  void _rebindPushIdsIfChanged() {
    if (_persistAuthUserId == null) return;
    final ids = myPushIds();
    final signature = (ids.toList()..sort()).join(',');
    if (signature == _boundPushIdsSignature) return;
    _boundPushIdsSignature = signature;
    unawaited(PushNotificationService.bindUserIds(ids));
    unawaited(PushNotificationService.dropForeignLeftoverFcmTokens());
  }

  /// FCM·푸시함은 Firebase 로그인 ID를 쓴다. 명단 ID를 그 키로 바꾼다.
  /// `m1`·`mg1` 처럼 예전 시드 id 로 남은 명단 행. 누구 계정인지 알 수 없다.
  static final RegExp _legacySeedMemberId = RegExp(r'^m[g]?\d+$');

  @visibleForTesting
  String fcmInboxIdForTest(String memberOrUserId, {String? clubId}) =>
      _fcmInboxIdFor(memberOrUserId, clubId: clubId);

  String _clubCreatorId(String clubId) =>
      [..._myClubs, ..._allClubs]
          .where((c) => c.id == clubId)
          .firstOrNull
          ?.creatorId
          .trim() ??
      '';

  /// 명단 행 → 푸시 수신함 계정 id. 모르면 빈 문자열(발송 안 함).
  ///
  /// 옛 시드 id 를 내 계정으로 넘기면 안 된다. 실제로 `m1` 로 남아 있던 회원의
  /// 푸시가 방장 수신함으로 가서, 방장은 같은 알림을 두 번 받고 그 회원은
  /// 한 번도 못 받았다.
  ///
  /// 선택된 모임이 아니어도 `m_<clubId>_<uid>` 는 uid 로 접는다.
  /// 앱 시작 때 전 모임 일정을 넣으면 같은 사람이 두 아이디로 큐에 쌓였다.
  String _fcmInboxIdFor(String memberOrUserId, {String? clubId}) {
    final raw = memberOrUserId.trim();
    if (raw.isEmpty) return raw;
    final resolvedClubId = (clubId != null && clubId.trim().isNotEmpty)
        ? clubId.trim()
        : (_myClubs.isNotEmpty ? selectedClub.id : '');
    if (!_isDemoSession && _myClubs.isNotEmpty) {
      final prefix =
          resolvedClubId.isEmpty ? '' : 'm_${resolvedClubId}_';
      final suffix = prefix.isNotEmpty && raw.startsWith(prefix)
          ? raw.substring(prefix.length)
          : '';
      final roster = D1EnqueuePolicy.rosterMatch(raw);
      final legacyRow = _legacySeedMemberId.hasMatch(raw) ||
          _legacySeedMemberId.hasMatch(suffix) ||
          (roster != null && _legacySeedMemberId.hasMatch(roster.suffix));
      if (legacyRow) {
        // 계정 id 를 모르는 옛 행. 전화번호로 소속 계정을 찾는다.
        // 못 찾으면 발송하지 않는다 (방장에게 잘못 배달되면 더 나쁘다).
        return _accountIdByRosterPhone(
          roster?.clubId ??
              (resolvedClubId.isNotEmpty ? resolvedClubId : selectedClub.id),
          raw,
        );
      }
    }
    if (!_isDemoSession && _legacySeedMemberId.hasMatch(raw)) return '';
    if (_isSelfTarget(raw)) {
      final auth = _persistAuthUserId?.trim();
      if (auth != null && auth.isNotEmpty) return auth;
      if (currentUserId.trim().isNotEmpty) return currentUserId;
    }
    final roster = D1EnqueuePolicy.rosterMatch(raw);
    if (roster != null && roster.suffix.isNotEmpty) {
      if (!_isDemoSession && _legacySeedMemberId.hasMatch(roster.suffix)) {
        return '';
      }
      return roster.suffix;
    }
    if (resolvedClubId.isNotEmpty && raw == 'm_creator_$resolvedClubId') {
      final cid = _clubCreatorId(resolvedClubId);
      if (cid.isNotEmpty) return cid;
    }
    if (_myClubs.isNotEmpty) {
      final mappedClubId =
          resolvedClubId.isNotEmpty ? resolvedClubId : selectedClub.id;
      final prefix = 'm_${mappedClubId}_';
      if (raw.startsWith(prefix)) {
        final suffix = raw.substring(prefix.length);
        if (!_isDemoSession && _legacySeedMemberId.hasMatch(suffix)) return '';
        if (suffix.isNotEmpty) return suffix;
      }
      if (raw == 'm_creator_$mappedClubId') {
        final cid = _clubCreatorId(mappedClubId);
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

  /// 데모 화면용. 실계정 회원수는 서버 멤버십 recount 만 쓴다.
  void _reconcileLiveMemberCounts() {
    if (!_isDemoSession) return;
    final ids = <String>{
      ..._confirmedClubIds,
      ..._sessionCreatedClubIds,
    };
    for (final id in ids) {
      if (_legacyMockClubIds.contains(id)) continue;
      if (!_isOfficialMyClub(id)) continue;
      final n = _officialMemberCount(id);
      if (n <= 0) continue;
      final mine = _myClubs.where((c) => c.id == id).firstOrNull;
      if (mine?.memberCount == n) continue;
      _setMemberCount(id, n);
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
          if (_isDemoSession &&
              (_persistAuthUserId == 'user_me' || currentUserId == 'm1')) ...[
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

  /// 디바운스 없이 저장 (일정 등록·납부 처리 등)
  ///
  /// 저장은 번들 **전체**를 JSON 으로 만드는 작업이라 사진이 많으면 수백 ms 가
  /// 걸린다. 이걸 화면 갱신보다 먼저 돌리면 "납부를 눌렀는데 금액이 안 바뀌고
  /// 다른 탭 갔다 오면 바뀐다"가 된다. 프레임을 먼저 그리게 하고 바로 저장한다.
  void _persistImmediately() {
    _persistTimer?.cancel();
    _persistTimer = null;
    if (_suppressPersist || _persistAuthUserId == null) return;
    _persistTimer = Timer(Duration.zero, () {
      _persistTimer = null;
      _persistNow();
    });
  }

  void _applyClubInfoOverrides() {
    if (_clubInfoOverrides.isEmpty) return;
    void apply(List<Club> list) {
      for (var i = 0; i < list.length; i++) {
        final o = _clubInfoOverrides[list[i].id];
        if (o == null) continue;
        final cur = list[i];
        list[i] = cur.copyWith(
          name: o.name,
          description: o.description,
          imageUrl: o.imageUrl,
          region: o.region,
          industry: o.industry,
          teamCount: o.teamCount,
        );
      }
    }

    apply(_myClubs);
    apply(_allClubs);
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
        roundScores: List<RoundScoreRecord>.from(_roundScores),
        thankYouMessages: List<ThankYouMessage>.from(_thankYouMessages),
        waitingList: List<WaitingEntry>.from(_waitingList),
        alimtalkSettings: Map<String, ClubAlimtalkSettings>.from(_alimtalkSettings),
      );

  String? _selectedClubIdOrNull() {
    if (_myClubs.isEmpty) return null;
    if (_selectedClubIndex < 0 || _selectedClubIndex >= _myClubs.length) {
      return null;
    }
    return _myClubs[_selectedClubIndex].id;
  }

  void _restoreSelectedClubId(String? clubId, {int? fallbackIndex}) {
    if (clubId != null && clubId.isNotEmpty) {
      final idx = _myClubs.indexWhere((c) => c.id == clubId);
      if (idx >= 0) {
        _selectedClubIndex = idx;
        return;
      }
    }
    if (_myClubs.isEmpty) {
      _selectedClubIndex = 0;
      return;
    }
    final fb = fallbackIndex ?? 0;
    _selectedClubIndex = fb.clamp(0, _myClubs.length - 1);
  }

  void _keepClubImagesIfIncomingEmpty(Map<String, String> keep) {
    if (keep.isEmpty) return;
    void apply(List<Club> list) {
      for (var i = 0; i < list.length; i++) {
        final kept = keep[list[i].id];
        if (kept == null || kept.isEmpty) continue;
        if ((list[i].imageUrl ?? '').trim().isEmpty) {
          list[i] = list[i].copyWith(imageUrl: kept);
        }
      }
    }

    apply(_myClubs);
    apply(_allClubs);
  }

  void _importBundle(ClubDataBundle b) {
    final keepSelectedId = _selectedClubIdOrNull();
    final keepImages = <String, String>{
      for (final c in _myClubs)
        if ((c.imageUrl ?? '').trim().isNotEmpty) c.id: c.imageUrl!.trim(),
      for (final c in _allClubs)
        if ((c.imageUrl ?? '').trim().isNotEmpty) c.id: c.imageUrl!.trim(),
    };
    _selectedClubIndex = b.selectedClubIndex;
    _freshClubIds
      ..clear()
      ..addAll(b.freshClubIds);
    final keptConfirmed = <Club>[
      if (!_isDemoSession)
        for (final c in _myClubs)
          if (_confirmedClubIds.contains(c.id) ||
              _sessionCreatedClubIds.contains(c.id))
            c,
    ];
    _myClubs
      ..clear()
      ..addAll(b.myClubs);
    if (!_isDemoSession) {
      _applyMembershipOnlyMyClubs();
      for (final c in keptConfirmed) {
        if (!_myClubs.any((x) => x.id == c.id)) _myClubs.add(c);
      }
      _applyMembershipOnlyMyClubs();
    }
    _allClubs
      ..clear()
      ..addAll(b.allClubs);
    _keepClubImagesIfIncomingEmpty(keepImages);
    _applyClubInfoOverrides();
    _joinRequests
      ..clear()
      ..addAll(b.joinRequests);
    _members
      ..clear()
      ..addAll(b.members);
    _dropLeftoverStolenForeignRoster();
    // 원격 명단이 로컬을 덮은 직후다. 여기서 다시 걸지 않으면
    // switchUser 에서 고친 내 이름이 '홍길동'으로 되돌아간다.
    _repairMyRosterNames(_currentUserName);
    _applyRosterRolesToMyClubs();
    // 이름과 같은 이유로 사진·전화번호도 다시 채운다. 안 하면 켤 때마다
    // 원격 행(사진 없음)이 덮어써서 내 프로필 사진이 영영 안 보인다.
    _fillMyRosterProfile();
    _scrubSeedNamesFromFreshClubs();
    _purgeHongGilDongFromRealClubs();
    // 강퇴·탈퇴 행은 tombstone 으로 등록해, 원격이 '활성'으로 되살리지 못하게 한다.
    ClubOpsSync.seedRemovedMembers(
      _members.where((m) => m.status != '활성').map((m) => m.id),
    );
    // 모임 목록이 방금 바뀌었다. 새 모임의 명단 ID로도 FCM 토큰을 등록해야
    // 그 모임 알림이 도착한다.
    _rebindPushIdsIfChanged();
    _activities
      ..clear()
      ..addAll(b.activities);
    _announcements
      ..clear()
      ..addAll(b.announcements);
    _appNotifications
      ..clear()
      ..addAll(b.appNotifications.where((n) => !ClubOpsSync.isNotificationRemoved(n.id)));
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
    _roundScores
      ..clear()
      ..addAll(b.roundScores);
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
    _restoreSelectedClubId(keepSelectedId, fallbackIndex: b.selectedClubIndex);

    _syncAllNextRounds();
    _normalizeScheduleTitles();
    pruneDuplicateRosterRows();
    _scrubSeedAuthorNames();
    _repairCopiedIdentityOnLegacyM1Rows();
    _syncSelfDisplayName();
    _backfillMissingAttendancePoints();
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
        _currentUserId = 'm1';
        _currentUserName = '홍길동';
        _myClubs
          ..clear()
          ..addAll(_adminClubs);
        break;
      default:
        _currentUserId = authUserId;
        _currentUserName = '회원';
        _myClubs.clear();
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
  final List<Member> _members = [];

  // ────────────────────────────────────────────────────────
  //  Activity / Attendance / Announcement
  // ────────────────────────────────────────────────────────
  final List<ActivityItem> _activities = [];

  /// @deprecated 홈 위젯 미사용 — 실제 집계는 club_room / schedule 응답 기준
  final AttendanceStatus _attendanceStatus =
      AttendanceStatus(confirmed: 0, noResponse: 0, declined: 0);

  final List<Announcement> _announcements = [];
  int _localEntitySeq = 0;

  String _newLocalEntityId(String prefix) {
    _localEntitySeq += 1;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_localEntitySeq';
  }

  // ─── 앱 알림 목록 — 시드 없음(실제 액션만). 잔존 시드는 로그인 시 purge ───
  final List<AppNotification> _appNotifications = [];

  // ════════════════════════════════════════════════════════
  //  Getters — My Clubs
  // ════════════════════════════════════════════════════════
  int get selectedClubIndex => _selectedClubIndex;
  List<Club> get clubs        => List.unmodifiable(_myClubs);
  List<Club> get myClubs => List.unmodifiable(_myClubs);
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
    final byId = <String, Club>{};
    for (final c in _allClubs) {
      byId[c.id] = c;
    }
    for (final c in _myClubs) {
      byId.putIfAbsent(c.id, () => c);
    }
    return byId.values.where((c) {
      // 지역전체/전체: 전부, '지역다양함': 해당 모임만, 그 외: 시·도 접두사 or 완전일치
      final matchRegion = isAllRegionFilter(region) ||
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
      final matchIndustry =
          isAllIndustryFilter(industry) || c.industry == industry;
      final matchKeyword = ClubDiscoveryService.matchesKeyword(c, keyword);
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

  bool _isOfficialMyClub(String clubId) {
    if (_confirmedClubIds.contains(clubId)) return true;
    if (_sessionCreatedClubIds.contains(clubId)) return true;
    return false;
  }

  int _officialMemberCount(String clubId) {
    final club = _myClubs.where((c) => c.id == clubId).firstOrNull ??
        _allClubs.where((c) => c.id == clubId).firstOrNull;
    return OfficialMemberCount.of(
      clubId: clubId,
      creatorUserId: club?.creatorId ?? '',
      roster: membersForClub(clubId),
    );
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
          .map(withoutSeedDisplayName)
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
          for (final m in clubMembers) {
            if (_isMyRosterRowFor(selectedClub, m.id)) return m;
          }
        }
      } catch (_) {}
    }

    return _members.where((m) => m.id == currentUserId).firstOrNull;
  }

  /// 내 모임 카드용 직책. 목록은 Club.myRole(카탈로그 찌꺼기)이 아니라
  /// 그 모임 명단 행을 본다. 알라딘 정회원이 목록에서만 회장으로 보이던 원인.
  String myDisplayRoleFor(Club club) {
    for (final m in membersForClub(club.id)) {
      if (!_isMyRosterRowFor(club, m.id)) continue;
      final role = ClubMemberRole.encodeRoles(
        ClubMemberRole.splitRoles(m.role),
      );
      if (role.trim().isNotEmpty) return role;
    }
    return club.myRole;
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
  late final List<DuesSetting> _duesSettings = <DuesSetting>[];
  late final List<DuesPayment> _duesPayments = <DuesPayment>[];
  late final List<PaymentRequest> _paymentRequests = <PaymentRequest>[];

  final List<Transaction> _transactions = [];

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
    return unpaidCountForDuesSetting(setting, y, m);
  }

  /// 이달 적용 회비 (월회비: 해당 연/월 기간 내 / 그 외: 활성 회비)
  List<DuesSetting> applicableDuesInMonth(int year, int month) =>
      activeDuesSettings.where((d) {
        if (d.type == DuesType.monthly) {
          return d.isActiveForYearMonth(year, month);
        }
        return true;
      }).toList();

  /// 특정 회비의 미납 회원 수. 게스트는 납부 대상이 아니다.
  int unpaidCountForDuesSetting(DuesSetting setting, int year, int month) {
    final members = regularMembers;
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

  /// 독촉하기 미납자. 월회비는 지난달 + (납부일이 지난) 이번달만.
  List<DuesReminderUnpaidRow> reminderUnpaidMembers(
    DuesSetting setting, {
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    final members = regularMembers;
    if (members.isEmpty) return const [];

    if (setting.type != DuesType.monthly) {
      final due = setting.dueDateFor();
      final today = DateTime(now.year, now.month, now.day);
      if (due != null && !today.isAfter(due)) return const [];
      return [
        for (final m in members)
          if (setting.type == DuesType.special
              ? !hasPaid(m.id, setting.id)
              : !hasPaid(m.id, setting.id, year: now.year))
            DuesReminderUnpaidRow(
              member: m,
              owesPreviousMonth: false,
              owesCurrentMonth: true,
            ),
      ];
    }

    var prevY = now.year;
    var prevM = now.month - 1;
    if (prevM < 1) {
      prevM = 12;
      prevY--;
    }
    final thisOk =
        _reminderMonthCollectable(setting, now.year, now.month, now);
    final prevOk = _reminderMonthCollectable(setting, prevY, prevM, now);

    final rows = <DuesReminderUnpaidRow>[];
    for (final m in members) {
      final owesPrev = prevOk &&
          !hasPaid(m.id, setting.id, year: prevY, month: prevM);
      final owesCur = thisOk &&
          !hasPaid(m.id, setting.id, year: now.year, month: now.month);
      if (!owesPrev && !owesCur) continue;
      rows.add(DuesReminderUnpaidRow(
        member: m,
        owesPreviousMonth: owesPrev,
        owesCurrentMonth: owesCur,
      ));
    }
    return rows;
  }

  /// 이번달은 납부 기준일이 지난 뒤에만 미납으로 본다.
  bool _reminderMonthCollectable(
    DuesSetting setting,
    int year,
    int month,
    DateTime asOf,
  ) {
    if (!setting.isActiveForYearMonth(year, month)) return false;
    final due = setting.dueDateFor(year: year, month: month);
    final today = DateTime(asOf.year, asOf.month, asOf.day);
    if (due != null) return today.isAfter(due);
    final isCurrentMonth = year == asOf.year && month == asOf.month;
    return !isCurrentMonth;
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

  /// 이달 회비 납부자 수 (홈·독촉용). 현재 납부 대상 회원만 센다.
  /// 탈퇴·게스트 등 목록에 없는 납부 기록은 분자에 넣지 않는다.
  int paidCountForMonth(int year, int month) {
    final setting = currentHomeDuesSetting(year, month);
    if (setting == null) return 0;
    final members = regularMembers;
    final monthFilter = setting.type == DuesType.monthly ? month : null;
    final paidIds = paymentsOf(setting.id, year: year, month: monthFilter)
        .map((p) => p.memberId)
        .toSet();
    return members.where((m) => paidIds.contains(m.id)).length;
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
    final members = regularMembers;
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
          final members = regularMembers;
          final amt = s.amountForPeriod(year: y);
          total +=
              members.where((m) => !hasPaid(m.id, s.id, year: y)).length *
                  amt;
          break;
        case DuesType.special:
          final members = regularMembers;
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

  /// 납부일은 **그 회비의 기간**으로 잡는다.
  ///
  /// 회비납부 탭용 일자. `hasPaid` 는 이 연·월로 그달 회비가 들어왔는지 본다.
  /// 수입/지출 장부 일자는 `recordPayment` 에서 오늘(입금일)을 쓴다.
  DateTime _paymentDateFor({
    required String duesSettingId,
    int? year,
    int? month,
  }) {
    final now = DateTime.now();
    if (year == null) return now;

    int clampDay(int y, int m) {
      final lastDay = DateTime(y, m + 1, 0).day; // 2월 30일 같은 날짜는 다음 달로 넘어간다
      return now.day > lastDay ? lastDay : now.day;
    }

    if (month != null) return DateTime(year, month, clampDay(year, month));
    if (year == now.year) return now;

    // 지난 연도 연회비·특별회비 — 그 해 납부 기준일, 없으면 연말
    final due = _duesSettings
        .where((d) => d.id == duesSettingId)
        .firstOrNull
        ?.dueDate;
    if (due != null && due.year == year) return due;
    return DateTime(year, 12, 31);
  }

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
    final paidAt = _paymentDateFor(
      duesSettingId: duesSettingId,
      year: year,
      month: month,
    );

    final paymentId = 'dp_${now.microsecondsSinceEpoch}_$memberId';
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
        id: 'tx_${now.microsecondsSinceEpoch}_$memberId',
        type: TxType.income,
        amount: amount,
        category: setting.type.label,
        title: '$periodPart${setting.type.label} - $memberName',
        date: now,
        recordedBy: currentUserName,
        source: TxSource.dues,
        duesPaymentId: paymentId,
        clubId: txClubId,
      ));
    }

    // 정시납부 포인트 +5. 화면(회원 목록 '포인트 적립 기준')이 예전부터
    // +5 를 안내했는데 적립 코드가 없었다. 마감일 지난 납부는 0점.
    _awardDuesOnTimePoint(
      memberId: memberId,
      duesSettingId: duesSettingId,
      paidAt: now,
      year: year,
      month: month,
    );

    // 회비 설정에 clubId가 없으면 현재 모임만 붙인다.
    // 다른 모임의 회비를 이 모임으로 바꿔 붙이면 재무가 섞인다.
    final setIdx = _duesSettings.indexWhere((d) => d.id == duesSettingId);
    if (setIdx >= 0) {
      final s = _duesSettings[setIdx];
      if (s.clubId == null || s.clubId!.isEmpty) {
        _duesSettings[setIdx] = s.copyWith(clubId: selectedClub.id);
      }
    }

    _stampOrphanTransactionClubIds();
    _persistImmediately();
    notifyListeners();
    unawaited(_dropPaidDuesD1(
      memberId: memberId,
      duesSettingId: duesSettingId,
      year: year,
      month: month,
      paidAt: paidAt,
    ));
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
    // 납부를 되돌렸으니 정시납부 포인트도 회수한다.
    _revokeDuesOnTimePoint(
      memberId: memberId,
      duesSettingId: duesSettingId,
      year: year,
      month: month,
    );
    _persistImmediately();
    notifyListeners();
    final setting = _duesSettings.where((d) => d.id == duesSettingId).firstOrNull;
    if (setting != null) unawaited(syncDuesD1Reminders(setting));
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

  Transaction? get openingBalanceTransaction {
    for (final t in _scopedTransactions) {
      if (t.source == TxSource.openingBalance) return t;
    }
    return null;
  }

  /// 재무 데이터가 전혀 없는 상태인지 (온보딩 배너 표시 기준)
  bool get isFinanceEmpty =>
      _scopedTransactions.isEmpty && activeDuesSettings.isEmpty;

  /// 선택 모임에 회계/회비 데이터가 없는지 (홈 빈 카드 기준)
  bool get isSelectedClubFinanceEmpty =>
      isFinanceEmpty && activeDuesSettings.isEmpty;

  /// 회비(재무) 최초 세팅이 아직 안 된 상태
  bool get isFinanceSetupPending => activeDuesSettings.isEmpty;

  /// 신규 모임 총무가 재무 시작 방식(올시즌 / 이번달)을 아직 고르지 않음
  bool get needsTreasurerFinanceOnboarding =>
      isActualTreasurer && isFinanceSetupPending && !hasOpeningBalance;

  /// 신규 모임 임원이 아직 일정이 없을 때 — 일정 탭 첫 안내
  bool get needsFirstScheduleGuide =>
      canCreateSchedule && schedules.isEmpty;

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
    unawaited(syncDuesD1Reminders(setting));
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
      unawaited(_persistNow());
      unawaited(() async {
        await PushNotificationService.clearD1ForSchedule(
            DuesD1Schedule.scheduleIdFor(updated.id));
        await syncDuesD1Reminders(updated);
      }());
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
          unawaited(PushNotificationService.clearD1ForSchedule(
              DuesD1Schedule.scheduleIdFor(d.id)));
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
      unawaited(PushNotificationService.clearD1ForSchedule(
          DuesD1Schedule.scheduleIdFor(id)));
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
    ClubOpsSync.markDuesSettingRemoved(id, clubId: selectedClub.id);
    notifyListeners();
    unawaited(_persistNow());
    unawaited(PushNotificationService.clearD1ForSchedule(
        DuesD1Schedule.scheduleIdFor(id)));
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
    // 지난 날짜 일정은 알림톡·푸시 없음 (일괄 등록과 동일)
    if (schedule.isDateOver) return;
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
    // 알림톡은 총무가 보내기를 고른 뒤에만 [sendScheduleUploadAlimtalk].
    // D-1은 참석한 회원만 10시 예약 (동반자 참석 반영 후).
    final latest = scheduleById(schedule.id) ?? schedule;
    unawaited(_enqueueD1RsvpReminders(latest));
  }

  /// 일정 등록 알림톡 — 등록 직후 보내기를 고른 경우에만 호출한다.
  void sendScheduleUploadAlimtalk(String scheduleId) {
    final schedule = scheduleById(scheduleId);
    if (schedule == null || schedule.isDateOver) return;
    _dispatchClubAlimtalk(
      hqTypeId: HqAlimtalkCatalog.scheduleUploadId,
      members: attendanceAlimtalkRecipients(),
      variablesFor: (m) => _alimtalkScheduleVars(schedule, m),
    );
  }

  /// 올해 이미 지난 라운딩을 일괄 등록. 알림톡·푸시 없음.
  /// 참석자는 랭킹 포인트, 시상자는 올해 시상 집계에 반영한다.
  bool importPastSchedule({
    required String title,
    DateTime? roundDate,
    String teeTime = '',
    String courseName = '',
    String? courseAddress,
    List<String> attendeeIds = const [],
    List<PastAwardDraft> awards = const [],
    int? monthHint,
  }) {
    if (!canCreateSchedule) {
      debugPrint('[ClubProvider] importPastSchedule blocked — not executive');
      return false;
    }
    final trimmed = title.trim();
    if (trimmed.isEmpty) return false;

    final date = PastScheduleImport.resolveRoundDate(
      title: trimmed,
      roundDate: roundDate,
      monthHint: monthHint,
    );
    final id = 's_imp_${DateTime.now().millisecondsSinceEpoch}';
    final responses = <AttendanceResponse>[];
    for (final mid in attendeeIds) {
      final member = memberById(mid);
      if (member == null) continue;
      responses.add(AttendanceResponse(
        memberId: member.id,
        memberName: member.name,
        response: '참석',
        respondedAt: date,
      ));
    }

    final schedule = RoundSchedule(
      id: id,
      clubId: selectedClub.id,
      title: trimmed,
      roundDate: date,
      teeTime: teeTime.trim(),
      courseName: courseName.trim(),
      courseAddress: (courseAddress ?? '').trim().isEmpty
          ? null
          : courseAddress!.trim(),
      teamCount: selectedClub.teamCount.clamp(1, 30),
      status: ScheduleStatus.done,
      createdBy: currentMember?.name ?? '임원',
      responses: responses,
      companionIds: [
        for (final r in responses) r.memberId,
      ],
    );
    _schedules.add(schedule);
    _syncNextRound(schedule.clubId);

    for (final r in responses) {
      _syncAttendancePoints(
        memberId: r.memberId,
        scheduleId: id,
        scheduleTitle: schedule.displayTitle,
        prev: null,
        response: '참석',
      );
    }

    final awardRecords = <AwardRecord>[];
    for (final draft in awards) {
      if (draft.winnerIds.isEmpty) continue;
      final names = [
        for (final wid in draft.winnerIds)
          memberById(wid)?.name ?? wid,
      ];
      awardRecords.add(AwardRecord(
        id: 'ar_${id}_${draft.awardName}',
        scheduleId: id,
        scheduleName: schedule.displayTitle,
        awardName: draft.awardName,
        awardIcon: draft.awardIcon,
        winnerIds: List<String>.from(draft.winnerIds),
        winnerNames: names,
        recordedAt: date,
      ));
    }
    if (awardRecords.isNotEmpty) {
      _awardRecords.addAll(awardRecords);
    }

    notifyListeners();
    _persistImmediately();
    return true;
  }

  /// 일정 등록 푸시·알림톡 대상 — 정회원 전원 (등록자 본인 포함)
  /// FCM 토큰 키(로그인 ID)로 맞춰서 m_creator_* 명단 ID로는 보내지 않는다.
  List<String> _scheduleBroadcastUserIds() {
    final ids = <String>{
      for (final m in regularMembers) m.id,
    };
    final me = currentMember?.id ?? currentUserId;
    if (me.trim().isNotEmpty) ids.add(me);
    final targets = <String>{
      for (final id in ids)
        if (_fcmInboxIdFor(id).isNotEmpty) _fcmInboxIdFor(id),
    };
    // 명단 행으로 못 찾은 회원을 빠뜨리지 않는다. 서버 소속이 최종 명부다.
    if (_myClubs.isNotEmpty) {
      for (final a in _clubAccounts[selectedClub.id] ?? const []) {
        if (a.isGuest || a.userId.trim().isEmpty) continue;
        targets.add(a.userId.trim());
      }
    }
    return targets.toList();
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

  /// 직책에 총무가 실제로 있는 경우만. 환영 온보딩·재무 첫 설정은 이 값만 본다.
  bool get isActualTreasurer =>
      ClubMemberRole.isTreasurer(selectedClub.myRole) ||
      ClubMemberRole.isTreasurer(currentMember?.role ?? '');

  /// 선택 모임에서의 총무 여부 — 재무(회비) 전용 권한
  /// Club.myRole과 회원 명단 role이 어긋난 경우(직책 수정·인수인계)도 허용.
  /// 총무가 비어 있으면 회장·부회장이 이미 열린 재무를 막히지 않게 한다.
  bool get isTreasurer {
    if (isActualTreasurer) return true;
    final vacant = !hasActiveTreasurer();
    return ClubMemberRole.canActAsTreasurer(
          selectedClub.myRole,
          treasurerVacant: vacant,
        ) ||
        ClubMemberRole.canActAsTreasurer(
          currentMember?.role ?? '',
          treasurerVacant: vacant,
        );
  }

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
    String? clubIdOverride,
  }) async {
    final clubId = (clubIdOverride ?? selectedClub.id).trim();
    if (clubId.isNotEmpty &&
        !isClubAlimtalkTypeEnabled(clubId, hqTypeId)) {
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

  /// 마지막 자동 알림톡 실패 사유. 화면이 읽어 총무에게 보여 준다.
  ///
  /// 예전엔 `unawaited` 로 던져 놓고 실패를 `debugPrint` 만 했다. 그래서
  /// 키 미설정·전화번호 없음·템플릿 미승인으로 한 통도 안 나가도
  /// 총무는 발송된 줄 알았다. ("알림톡이 안 간다"의 진단을 막던 지점)
  String? get lastAlimtalkError => _lastAlimtalkError;
  String? _lastAlimtalkError;

  void clearAlimtalkError() {
    if (_lastAlimtalkError == null) return;
    _lastAlimtalkError = null;
    notifyListeners();
  }

  List<Member> _d1RsvpMembers(String clubId) {
    final creator = _clubCreatorId(clubId);
    final list = membersForClub(clubId)
        .where((m) => m.status == '활성' && m.memberType == '정회원')
        .where((m) => !D1EnqueuePolicy.isBlockedRecipient(
              name: m.name,
              userId: m.id,
              clubId: clubId,
              creatorUserId: creator,
            ))
        .toList();
    if (clubId == selectedClub.id) {
      final me = currentMember;
      if (me != null &&
          me.memberType == '정회원' &&
          list.every((m) => m.id != me.id) &&
          !D1EnqueuePolicy.isBlockedRecipient(
            name: me.name,
            userId: me.id,
            clubId: clubId,
            creatorUserId: creator,
          )) {
        list.add(me);
      }
    }
    return list;
  }

  String _clubNameOf(String clubId) =>
      _myClubs.where((c) => c.id == clubId).firstOrNull?.name ??
      _allClubs.where((c) => c.id == clubId).firstOrNull?.name ??
      selectedClub.name;

  Future<void> _enqueueAllUpcomingD1() async {
    final myIds = {for (final c in _myClubs) c.id};
    for (final s in _schedules) {
      if (!myIds.contains(s.clubId)) continue;
      if (s.isDateOver) continue;
      if (s.status != ScheduleStatus.upcoming) continue;
      await _enqueueD1RsvpReminders(s, flush: false);
    }
    await flushDueD1Alimtalk();
  }

  /// 참석 회원만 D-1 큐. 불참·미응답은 빼서 정회원 전원으로 새지 않게 한다.
  Future<void> _enqueueD1RsvpReminders(
    RoundSchedule schedule, {
    bool flush = true,
  }) async {
    if (schedule.isDateOver) return;
    final dateStr =
        '${schedule.roundDate.month}월 ${schedule.roundDate.day}일 ${schedule.teeTime}'
            .trim();
    final place = schedule.courseName.trim().isEmpty
        ? '장소 미정'
        : schedule.courseName.trim();
    final clubName = _clubNameOf(schedule.clubId);
    final attendingIds = {
      for (final r in schedule.responses)
        if (r.response == '참석') r.memberId,
    };
    final official = _d1RsvpMembers(schedule.clubId);
    final officialIds = {for (final m in official) m.id};
    final creator = _clubCreatorId(schedule.clubId);
    final attendingCanonical = <String>{};
    for (final id in attendingIds) {
      final inbox = _fcmInboxIdFor(id, clubId: schedule.clubId);
      if (inbox.isNotEmpty) attendingCanonical.add(inbox);
    }
    final seen = <String>{};
    for (final m in official) {
      final userId = _fcmInboxIdFor(m.id, clubId: schedule.clubId);
      if (userId.isEmpty) continue;
      if (!seen.add(userId)) {
        await PushNotificationService.syncD1Reminder(
          scheduleId: schedule.id,
          userId: m.id,
          roundDate: schedule.roundDate,
          clubId: schedule.clubId,
          clubName: clubName,
          scheduleTitle: schedule.displayTitle,
          enqueue: false,
          creatorUserId: creator,
        );
        continue;
      }
      await PushNotificationService.syncD1Reminder(
        scheduleId: schedule.id,
        userId: userId,
        roundDate: schedule.roundDate,
        clubId: schedule.clubId,
        clubName: clubName,
        scheduleTitle: schedule.displayTitle,
        enqueue: attendingIds.contains(m.id) ||
            attendingCanonical.contains(userId),
        phone: m.phone,
        memberName: m.name,
        whenText: dateStr,
        place: place,
        creatorUserId: creator,
        aliasUserIds: {m.id},
      );
    }
    for (final r in schedule.responses) {
      if (!officialIds.contains(r.memberId)) continue;
      final userId = _fcmInboxIdFor(r.memberId, clubId: schedule.clubId);
      if (userId.isEmpty || !seen.add(userId)) continue;
      final member = memberById(r.memberId);
      await PushNotificationService.syncD1Reminder(
        scheduleId: schedule.id,
        userId: userId,
        roundDate: schedule.roundDate,
        clubId: schedule.clubId,
        clubName: clubName,
        scheduleTitle: schedule.displayTitle,
        enqueue: r.response == '참석',
        phone: member?.phone,
        memberName: member?.name ?? r.memberName,
        whenText: dateStr,
        place: place,
        creatorUserId: creator,
        aliasUserIds: {r.memberId},
      );
    }
    if (flush) await flushDueD1Alimtalk();
  }

  Future<void> _syncD1AndFlushAlimtalk({
    required RoundSchedule schedule,
    required String memberId,
    required String response,
  }) async {
    final member = memberById(memberId);
    final dateStr =
        '${schedule.roundDate.month}월 ${schedule.roundDate.day}일 ${schedule.teeTime}'
            .trim();
    final place = schedule.courseName.trim().isEmpty
        ? '장소 미정'
        : schedule.courseName.trim();
    await PushNotificationService.syncD1Reminder(
      scheduleId: schedule.id,
      userId: _fcmInboxIdFor(memberId, clubId: schedule.clubId),
      roundDate: schedule.roundDate,
      clubId: schedule.clubId,
      clubName: _clubNameOf(schedule.clubId),
      scheduleTitle: schedule.displayTitle,
      enqueue: response == '참석',
      phone: member?.phone,
      memberName: member?.name,
      whenText: dateStr,
      place: place,
      creatorUserId: _clubCreatorId(schedule.clubId),
      aliasUserIds: {memberId},
    );
    await flushDueD1Alimtalk();
  }

  /// D-1 알림톡. 앱이 솔라피 10시 예약. Functions는 10:10 이후 보조.
  Future<void> flushDueD1Alimtalk() async {
    await D1AlimtalkFlush.run(
      clubEnabled: isClubAlimtalkTypeEnabled,
      resolvePhone: (userId, clubId) {
        for (final m in _members) {
          if (m.id == userId || _fcmInboxIdFor(m.id) == userId) {
            return m.phone;
          }
        }
        return null;
      },
    );
  }

  Future<void> syncAllDuesD1Reminders() async {
    if (_myClubs.isEmpty) return;
    for (final club in _myClubs) {
      for (final s in _duesSettings) {
        if (!s.isActive) continue;
        final sid = (s.clubId ?? '').trim();
        if (sid.isNotEmpty && sid != club.id) continue;
        if (sid.isEmpty && !_legacyMockClubIds.contains(club.id)) continue;
        await syncDuesD1Reminders(s, club: club, flush: false);
      }
    }
    await flushDueD1Alimtalk();
  }

  Future<void> syncDuesD1Reminders(
    DuesSetting setting, {
    Club? club,
    bool flush = true,
  }) async {
    final target = club ??
        _clubById((setting.clubId ?? '').trim()) ??
        selectedClub;
    if (!setting.isActive) {
      await PushNotificationService.clearD1ForSchedule(
          DuesD1Schedule.scheduleIdFor(setting.id));
      return;
    }
    final dues = DuesD1Schedule.imminentDueDates(setting);
    if (dues.isEmpty) return;
    final members = membersForClub(target.id)
        .where((m) => m.status == '활성' && m.memberType == '정회원');
    for (final due in dues) {
      final period = DuesD1Schedule.periodKey(setting, due);
      final dueLabel = DuesD1Schedule.dueText(due);
      final amount = setting.amountForPeriod(
        year: due.year,
        month: setting.type == DuesType.monthly ? due.month : 1,
      );
      for (final m in members) {
        if (D1EnqueuePolicy.isBlockedRecipient(
          name: m.name,
          userId: m.id,
          clubId: target.id,
          creatorUserId: target.creatorId,
        )) {
          continue;
        }
        final paid = setting.type == DuesType.monthly
            ? hasPaid(m.id, setting.id, year: due.year, month: due.month)
            : hasPaid(m.id, setting.id, year: due.year);
        await PushNotificationService.syncDuesD1Reminder(
          settingId: setting.id,
          userId: _fcmInboxIdFor(m.id, clubId: target.id),
          dueDate: due,
          periodKey: period,
          clubId: target.id,
          clubName: target.name,
          amountText: '$amount',
          dueText: dueLabel,
          enqueue: !paid,
          phone: m.phone,
          memberName: m.name.trim().isEmpty ? '회원' : m.name.trim(),
          creatorUserId: target.creatorId,
          aliasUserIds: {m.id},
        );
      }
    }
    if (flush) await flushDueD1Alimtalk();
  }

  Future<void> _dropPaidDuesD1({
    required String memberId,
    required String duesSettingId,
    int? year,
    int? month,
    required DateTime paidAt,
  }) async {
    final setting =
        _duesSettings.where((d) => d.id == duesSettingId).firstOrNull;
    if (setting == null) return;
    final club = _clubById((setting.clubId ?? '').trim()) ?? selectedClub;
    final due = setting.dueDateFor(year: year, month: month) ??
        DateTime(year ?? paidAt.year, month ?? paidAt.month, paidAt.day);
    await PushNotificationService.syncDuesD1Reminder(
      settingId: setting.id,
      userId: _fcmInboxIdFor(memberId, clubId: club.id),
      dueDate: due,
      periodKey: DuesD1Schedule.periodKey(setting, due),
      clubId: club.id,
      clubName: club.name,
      amountText: '${setting.amount}',
      dueText: DuesD1Schedule.dueText(due),
      enqueue: false,
      phone: '',
      memberName: '',
    );
  }

  Map<String, String> _alimtalkScheduleVars(RoundSchedule s, Member m) {
    final dateStr =
        '${s.roundDate.month}월 ${s.roundDate.day}일 ${s.teeTime}'.trim();
    final place =
        s.courseName.trim().isEmpty ? '장소 미정' : s.courseName.trim();
    return {
      '#{이름}': m.name.trim().isEmpty ? '회원' : m.name.trim(),
      '#{모임명}': selectedClub.name,
      '#{일정명}': s.displayTitle,
      '#{일시}': dateStr,
      '#{장소}': place,
    };
  }

  void _dispatchClubAlimtalk({
    required String hqTypeId,
    required List<Member> members,
    required Map<String, String> Function(Member member) variablesFor,
  }) {
    unawaited(() async {
      final result = await sendClubAlimtalk(
        hqTypeId: hqTypeId,
        members: members,
        variablesFor: variablesFor,
      );
      if (result.success) return;
      // '꺼져 있음' 은 설정대로 동작한 것이라 오류로 알리지 않는다.
      final msg = result.errorMessage ?? '알 수 없는 오류';
      if (msg.contains('꺼져 있습니다')) return;
      _lastAlimtalkError = '$hqTypeId: $msg';
      notifyListeners();
    }());
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
  /// 날짜·시간·장소가 바뀌어도 참석·대기·조편성은 유지한다.
  /// 반환: 실질 변경(알림·알림톡 대상) 여부. 제목·공지만 바뀌면 false.
  bool updateSchedule(RoundSchedule updated) {
    if (!canCreateSchedule) {
      debugPrint('[ClubProvider] updateSchedule blocked — not executive');
      return false;
    }
    final idx = _schedules.indexWhere((s) => s.id == updated.id);
    if (idx == -1) return false;

    final prev = _schedules[idx];
    final materialChanged = isMaterialScheduleChange(prev, updated);

    _schedules[idx] = updated;
    _syncNextRound(updated.clubId);
    notifyListeners();
    _persistImmediately();
    if (!updated.isDateOver) {
      unawaited((() async {
        await _enqueueD1RsvpReminders(updated);
      })());
    }
    return materialChanged;
  }

  /// 일정 변경 푸시 — 보내기를 고른 뒤에만 호출한다.
  void notifyScheduleChanged(String scheduleId) {
    final schedule = scheduleById(scheduleId);
    if (schedule == null) return;
    final club = _myClubs.where((c) => c.id == schedule.clubId).firstOrNull ??
        _allClubs.where((c) => c.id == schedule.clubId).firstOrNull;
    final clubName = club?.name ?? selectedClub.name;
    _notifyHqPush(
      typeId: HqPushCatalog.scheduleChange,
      userIds: [
        for (final m in scheduleChangeAlimtalkRecipients(scheduleId)) m.id,
      ],
      appType: AppNotificationType.scheduleChanged,
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

  /// 일정 변경 알림톡 — 변경 직후 보내기를 고른 경우에만 호출한다.
  void sendScheduleChangeAlimtalk(String scheduleId) {
    final schedule = scheduleById(scheduleId);
    if (schedule == null) return;
    _dispatchClubAlimtalk(
      hqTypeId: HqAlimtalkCatalog.scheduleChangeId,
      members: scheduleChangeAlimtalkRecipients(scheduleId),
      variablesFor: (m) => _alimtalkScheduleVars(schedule, m),
    );
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
      for (final r in schedule.responses) {
        if (r.response != '참석') continue;
        _syncAttendancePoints(
          memberId: r.memberId,
          scheduleId: scheduleId,
          scheduleTitle: schedule.displayTitle,
          prev: '참석',
          response: '불참',
        );
      }
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
    unawaited(_syncD1AndFlushAlimtalk(
      schedule: schedule,
      memberId: myId,
      response: response,
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
    final groupNo = assignment.groupOfAny(_memberAliasIds(memberId));
    if (groupNo == null && !assignment.isFinalized) return;

    if (groupNo != null) {
      final aliases = _memberAliasIds(memberId);
      final groups = List<AssignGroup>.from(assignment.groups);
      for (var gi = 0; gi < groups.length; gi++) {
        final slots = List<GroupSlot>.from(groups[gi].slots);
        var changed = false;
        for (var si = 0; si < slots.length; si++) {
          final sid = slots[si].memberId;
          if (sid != null && aliases.contains(sid)) {
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

    unawaited(_syncD1AndFlushAlimtalk(
      schedule: schedule,
      memberId: memberId,
      response: response,
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
    final inMembers = membersForClub(cid)
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
    final fromAccounts = JoinRequestService.notifyAccountIds(
      officers: [
        for (final a in _clubAccounts[clubId] ?? const <ClubMemberAccount>[])
          JoinOfficer(userId: a.userId, role: a.role),
      ],
    );
    if (fromAccounts.isNotEmpty) return fromAccounts.first;

    final pool = membersForClub(legacyClubIdFor(clubId))
        .where((m) => m.status == '활성')
        .toList();
    final treasurer = pool
        .where((m) => ClubMemberRole.isTreasurer(m.role))
        .firstOrNull;
    if (treasurer != null) {
      return JoinRequestService.accountIdOf(
        clubId: clubId,
        memberOrUserId: treasurer.id,
      );
    }

    final president = pool
        .where((m) => ClubMemberRole.hasRole(m.role, ClubMemberRole.president))
        .firstOrNull;
    if (president != null) {
      return JoinRequestService.accountIdOf(
        clubId: clubId,
        memberOrUserId: president.id,
      );
    }

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

  /// 신청자 기기의 로컬 명단이 아니라 서버 소속·명단으로 총무(없으면 회장) 계정을 고른다.
  Future<List<String>> _resolveJoinNotifyAccountIds(String clubId) async {
    final officers = await _joinOfficerAccounts(clubId);
    final club = _allClubs.where((c) => c.id == clubId).firstOrNull ??
        _myClubs.where((c) => c.id == clubId).firstOrNull;
    final ids = JoinRequestService.notifyAccountIds(
      officers: officers,
      creatorId: club?.creatorId,
    );
    if (ids.isNotEmpty) return ids;
    final fallback = joinRequestNotifyTargetId(clubId);
    if (fallback == null || fallback.isEmpty) return const [];
    final inbox = _fcmInboxIdFor(fallback, clubId: clubId);
    return [if (inbox.isNotEmpty) inbox else fallback];
  }

  Future<List<JoinOfficer>> _joinOfficerAccounts(String clubId) async {
    final byId = <String, JoinOfficer>{};
    void add(JoinOfficer officer) {
      final uid = officer.userId.trim();
      if (uid.isEmpty) return;
      final prev = byId[uid];
      if (prev == null) {
        byId[uid] = officer;
        return;
      }
      final nextIsOfficer = ClubMemberRole.isOfficer(officer.role);
      final prevIsOfficer = ClubMemberRole.isOfficer(prev.role);
      if (nextIsOfficer && !prevIsOfficer) {
        byId[uid] = officer;
      } else if (ClubMemberRole.isTreasurer(officer.role)) {
        byId[uid] = officer;
      }
    }

    void addLocal() {
      for (final m in membersForClub(legacyClubIdFor(clubId))) {
        if (m.status != '활성') continue;
        add(JoinOfficer(
          userId: JoinRequestService.accountIdOf(
            clubId: clubId,
            memberOrUserId: m.id,
          ),
          role: m.role,
        ));
      }
    }

    if (!AppDependencies.instance.isInitialized ||
        AppDependencies.instance.isOfflineMockMode) {
      addLocal();
      return byId.values.toList();
    }
    try {
      final accounts = await AppDependencies.instance.clubRepository
          .fetchClubMemberAccounts(clubId)
          .timeout(const Duration(seconds: 8));
      if (accounts.isNotEmpty) {
        _clubAccounts[clubId] = accounts;
        for (final a in accounts) {
          add(JoinOfficer(userId: a.userId, role: a.role));
        }
      }
    } catch (e) {
      debugPrint('[ClubProvider] join officer accounts skip: $e');
    }
    final hasOfficer = byId.values.any((o) => ClubMemberRole.isOfficer(o.role));
    if (!hasOfficer) {
      try {
        final remote = await AppDependencies.instance.memberRepository
            .fetchMembers(clubId)
            .timeout(const Duration(seconds: 8));
        for (final m in remote) {
          if (m.status != '활성') continue;
          add(JoinOfficer(
            userId: JoinRequestService.accountIdOf(
              clubId: clubId,
              memberOrUserId: m.id,
            ),
            role: m.role,
          ));
        }
      } catch (e) {
        debugPrint('[ClubProvider] join officer members skip: $e');
      }
    }
    if (byId.isEmpty) addLocal();
    return byId.values.toList();
  }

  bool _joinNotifyHasTreasurer(String clubId) {
    final accounts = _clubAccounts[clubId];
    if (accounts != null &&
        accounts.any((a) => ClubMemberRole.isTreasurer(a.role))) {
      return true;
    }
    return hasActiveTreasurer(clubId);
  }

  bool _canReviewJoin(JoinRequest req) {
    final aliases = clubIdAliases(req.clubId);
    final club = _myClubs.where((c) => aliases.contains(c.id)).firstOrNull;
    final reviewer = _persistAuthUserId ?? currentUserId;
    String memberRole = '';
    if (club != null) {
      for (final m in membersForClub(club.id)) {
        if (_isMyRosterRowFor(club, m.id)) {
          memberRole = m.role;
          break;
        }
      }
    }
    return JoinRequestService.canApprove(
      myRole: club?.myRole ?? '',
      creatorId: club?.creatorId,
      reviewerId: reviewer,
      memberRole: memberRole,
    );
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
    _tombstoneNotifications(_appNotifications.where((n) => n.id == notifId));
    _appNotifications.removeWhere((n) => n.id == notifId);
    notifyListeners();
    _persistImmediately();
  }

  /// 읽은 알림 전체 삭제
  void deleteReadNotifications() {
    _tombstoneNotifications(_appNotifications.where((n) => n.isRead));
    _appNotifications.removeWhere((n) => n.isRead);
    notifyListeners();
    _persistImmediately();
  }

  /// 모든 알림 삭제
  void clearAllNotifications() {
    _tombstoneNotifications(_appNotifications);
    _appNotifications.clear();
    notifyListeners();
    _persistImmediately();
  }

  /// 특정 모임 알림 전체 삭제 (볼 수 있는 알림만)
  void removeAllNotificationsForClub(String clubId) {
    _tombstoneNotifications(
      _appNotifications.where((n) => n.clubId == clubId && canSeeNotification(n)),
    );
    _appNotifications
        .removeWhere((n) => n.clubId == clubId && canSeeNotification(n));
    notifyListeners();
    _persistImmediately();
  }

  /// 내 모임 화면에서 볼 수 있는 알림 전체 삭제
  void removeAllVisibleNotifications() {
    _tombstoneNotifications(_appNotifications.where(canSeeNotification));
    _appNotifications.removeWhere(canSeeNotification);
    notifyListeners();
    _persistImmediately();
  }

  void _tombstoneNotifications(Iterable<AppNotification> items) {
    for (final n in List<AppNotification>.from(items)) {
      ClubOpsSync.markNotificationRemoved(n.id);
    }
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
    final id = _newLocalEntityId('ann');
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
    ClubOpsSync.markAnnouncementDeleted(id);
    for (final c in a.comments) {
      ClubOpsSync.markCommentDeleted(c.id);
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

  bool _samePointMember(String authorId, String memberId) {
    if (authorId.isEmpty || memberId.isEmpty) return false;
    if (authorId == memberId) return true;
    return _membershipPointKeysFor(memberId).contains(authorId) ||
        _membershipPointKeysFor(authorId).contains(memberId);
  }

  bool _isCommentPointForAnnouncement(
      MembershipPointEvent e, Announcement a) {
    if (e.type != MembershipPointType.commentActivity) return false;
    final d = e.desc;
    final pipe = d.lastIndexOf('|');
    if (pipe != -1) return d.substring(pipe + 1) == a.id;
    return d == '공지 참여 (+2): ${a.title}' ||
        d == '공지 참여 (-2): ${a.title}';
  }

  int _commentPointNetFor(String memberId, Announcement a) {
    final seen = <String>{};
    var sum = 0;
    for (final key in _membershipPointKeysFor(memberId)) {
      for (final e in _pointEvents[key] ?? const <MembershipPointEvent>[]) {
        if (!_isCommentPointForAnnouncement(e, a)) continue;
        final nk =
            '${e.type.name}|${e.points}|${e.desc}|${e.date.millisecondsSinceEpoch}';
        if (!seen.add(nk)) continue;
        sum += e.points;
      }
    }
    return sum;
  }

  /// 그 공지에 내 댓글이 있으면 순 +2, 없으면 0. 조정 점수를 반환한다.
  int _reconcileAnnouncementCommentPoints(
      String memberId, Announcement a) {
    final has =
        a.comments.any((c) => _samePointMember(c.authorId, memberId));
    final net = _commentPointNetFor(memberId, a);
    var delta = 0;
    if (has && net <= 0) {
      delta = 2;
    } else if (has && net > 2) {
      delta = 2 - net;
    } else if (!has && net != 0) {
      delta = -net;
    }
    if (delta == 0) return 0;
    final sign = delta > 0 ? '+' : '';
    addMembershipPoint(
      memberId: memberId,
      type: MembershipPointType.commentActivity,
      points: delta,
      desc: '공지 참여 ($sign$delta): ${a.title}|${a.id}',
    );
    return delta;
  }

  /// 공지사항 댓글 작성 — 그 공지에 내 댓글이 처음일 때만 +2.
  ///
  /// 반환값은 포인트 적립 여부. 호출부 스낵바가 "+2 획득" 문구에 쓴다.
  bool addAnnouncementComment({
    required String announcementId,
    required String text,
  }) {
    final idx = _announcements.indexWhere((a) => a.id == announcementId);
    if (idx == -1) return false;
    final a = _announcements[idx];

    final pointMemberId = currentMember?.id ?? currentUserId;
    final newComment = AnnouncementComment(
      id: _newLocalEntityId('cmt'),
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

    final awarded = _reconcileAnnouncementCommentPoints(
      pointMemberId,
      _announcements[idx],
    ) ==
        2;

    // 댓글 알림: 관리자용 피드 (자신에게는 쌓이지 않도록 isRead:true로 처리)
    // 실제 앱에서는 FCM으로 다른 멤버에게 발송하지만, 여기선 조용히 기록만
    _appNotifications.insert(0, AppNotification(
      id: 'noti_cmt_${DateTime.now().millisecondsSinceEpoch}',
      type: AppNotificationType.comment,
      clubId: selectedClub.id,
      clubName: selectedClub.name,
      title: '댓글',
      body: '$currentUserName님이 댓글을 달았습니다: ${text.length > 20 ? text.substring(0, 20) + '…' : text}',
      isAdmin: false,
      isRead: true, // 자신이 단 댓글은 이미 읽은 상태 → 뱃지 증가 없음
      createdAt: DateTime.now(),
      targetId: announcementId,
    ));

    notifyListeners();
    _persistImmediately();
    return awarded;
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
    // 원격 스냅샷이 늦게 오면 지운 댓글이 되살아난다.
    ClubOpsSync.markCommentDeleted(commentId);
    final remaining =
        a.comments.where((e) => e.id != commentId).toList();
    _announcements[idx] = Announcement(
      id: a.id,
      title: a.title,
      content: a.content,
      isPinned: a.isPinned,
      createdAt: a.createdAt,
      comments: remaining,
      clubId: a.clubId,
      authorId: a.authorId,
      authorName: a.authorName,
    );
    _reconcileAnnouncementCommentPoints(
      c.authorId,
      _announcements[idx],
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
      unawaited(_hydrateRosterFromServer(_myClubs[index].id));
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
      unawaited(_hydrateRosterFromServer(clubId));
      unawaited(hydrateClubAccounts(clubId));
      _watchSelectedClubOps();
      notifyListeners();
    }
  }

  /// 승인된 모임을 신청자 내 모임에 붙이고 그 모임으로 들어간다.
  Future<void> attachApprovedClub(String clubId) async {
    if (clubId.trim().isEmpty) return;
    if (!_myClubs.any((c) => c.id == clubId)) {
      Club? club = _allClubs.where((c) => c.id == clubId).firstOrNull;
      final auth = _persistAuthUserId ?? currentUserId;
      if (club == null && auth.isNotEmpty) {
        try {
          await _ingestServerMemberships(auth);
        } catch (e) {
          debugPrint('[ClubProvider] attachApproved ingest skip: $e');
        }
        club = _myClubs.where((c) => c.id == clubId).firstOrNull ??
            _allClubs.where((c) => c.id == clubId).firstOrNull;
      }
      if (club == null &&
          AppDependencies.instance.isInitialized &&
          !AppDependencies.instance.isOfflineMockMode) {
        try {
          club = await AppDependencies.instance.clubRepository
              .fetchClubById(clubId, userId: auth)
              .timeout(const Duration(seconds: 8));
        } catch (e) {
          debugPrint('[ClubProvider] attachApproved fetch skip: $e');
        }
      }
      if (club != null) {
        _ingestOwnedClub(club, const []);
        _rememberOfficialClub(clubId);
      }
    }
    selectClubById(clubId);
  }

  // ════════════════════════════════════════════════════════
  //  Actions — Create Club
  // ════════════════════════════════════════════════════════
  /// 반환: 어드민 저장소(Mock/Firestore) 동기화 성공 여부
  Future<bool> isClubNameTaken(String name, {String? exceptClubId}) async {
    final seen = <Club>[..._allClubs, ..._myClubs];
    if (AppDependencies.instance.isInitialized) {
      try {
        final remote = await AppDependencies.instance.clubRepository
            .fetchDiscoverableClubs()
            .timeout(const Duration(seconds: 8));
        for (final c in remote) {
          if (SampleClubFilter.isSample(id: c.id, name: c.name)) continue;
          if (seen.every((x) => x.id != c.id)) seen.add(c);
        }
      } catch (e) {
        debugPrint('[ClubProvider] name check catalog skip: $e');
      }
    }
    return ClubNamePolicy.isTaken(
      name: name,
      clubs: seen,
      exceptClubId: exceptClubId,
    );
  }

  Future<bool> createClub({
    required String name,
    required String region,
    required String industry,
    required int teamCount,
    required String myRole,
    String description = '',
    String? imageUrl,
  }) async {
    if (await isClubNameTaken(name)) return false;
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
    _sessionCreatedClubIds.add(id);
    _rememberOfficialClub(id);

    // 생성자를 해당 모임 회원으로 등록 (mock 시드 회원과 분리: m_creator_*)
    final creatorMember = _selfMember(
      id: 'm_creator_$id',
      name: currentUserName,
      memberType: ClubMemberRole.memberTypeForRole(roleEncoded),
      role: roleEncoded,
      joinDate: DateTime.now(),
    );
    _members.add(creatorMember);
    // 방금 만든 모임의 명단 ID(m_creator_<id>)로도 FCM 토큰을 등록한다.
    // 이게 없으면 이 모임에서 나에게 오는 푸시가 토큰을 못 찾는다.
    _rebindPushIdsIfChanged();

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
    if (_repairCopiedIdentityOnLegacyM1Rows()) changed = true;
    for (final club in _myClubs) {
      if (_legacyMockClubIds.contains(club.id)) continue;
      final existing = membersForClub(club.id);
      final iAmCreator = _iAmClubCreator(club);

      if (existing.isNotEmpty) {
        if (_isDemoSession && club.memberCount != existing.length) {
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
      _members.add(_selfMember(
        id: creatorId,
        name: currentUserName,
        memberType: ClubMemberRole.memberTypeForRole(role),
        role: role,
        joinDate: club.createdAt,
      ));
      _freshClubIds.add(club.id);
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
    if (pruneDuplicateRosterRows()) changed = true;
    if (_repairCopiedIdentityOnLegacyM1Rows()) changed = true;
    if (changed) _persistImmediately();
    return changed;
  }

  /// 내 명단 행에 박힌 데모 이름('홍길동' 등)을 실제 계정 이름으로 되돌린다.
  ///
  /// 예전 `switchUser` 는 시드가 아닌 계정을 전부 m1/홍길동으로 떨어뜨렸다.
  /// 그때 `ensureCreatorMembers` 가 만든 생성자 행이 '홍길동'으로 저장돼 있다.
  /// 사람이 직접 고친 이름은 건드리지 않는다 — placeholder 만 갈아끼운다.
  bool repairMyDisplayName(String realName) {
    final changed = _repairMyRosterNames(realName);
    if (changed) {
      notifyListeners();
      _persistImmediately();
    }
    return changed;
  }

  /// `repairMyDisplayName` 의 순수 부분 — `_members` 만 고치고 통지/저장은 안 한다.
  ///
  /// `_importBundle` 안에서도 불러야 한다. 예전엔 `switchUser` 에서 한 번만 돌았고
  /// 그 뒤 `_pullCloudOpsForMyClubs` / watch 가 원격 명단으로 덮어써서
  /// 고쳐 놓은 이름이 다시 '홍길동'으로 돌아갔다.
  bool _repairMyRosterNames(String realName) {
    final target = realName.trim();
    if (target.isEmpty || isPlaceholderMemberName(target)) return false;

    var changed = false;
    for (final club in _myClubs) {
      // 데모 모임(c1~c5)은 공유 시드 명단이라 손대면 안 된다.
      if (_legacyMockClubIds.contains(club.id)) continue;
      for (var i = 0; i < _members.length; i++) {
        final m = _members[i];
        if (!_isMyRosterRowFor(club, m.id)) continue;
        if (m.name.trim() == target) continue;
        final leftover = leftoverStolenNames.contains(m.name.trim()) &&
            m.name.trim() != target;
        if (!isPlaceholderMemberName(m.name) && !leftover) continue;
        _members[i] = m.copyWith(name: target);
        _relabelMemberDisplayName(m.id, target);
        changed = true;
      }
    }
    return changed;
  }

  /// 실모임에서 홍길동 시드 행은 이름을 바꾸지 않고 삭제한다.
  /// 이름만 바꾸면 같은 id 로 원격 홍길동이 다음 pull 에 다시 붙는다.
  bool _scrubSeedNamesFromFreshClubs() {
    if (_isDemoSession) return false;
    final drop = <String>{};
    _members.removeWhere((m) {
      if (!DemoFinanceStrip.isGhostName(m.name) &&
          !DemoFinanceStrip.isGhostMemberId(m.id)) {
        return false;
      }
      final onDemo = _legacyMockClubIds.any((id) =>
          m.id == 'm_creator_$id' ||
          m.id.startsWith('m_${id}_') ||
          m.id == 'm1');
      if (onDemo) return false;
      drop.add(m.id);
      return true;
    });
    if (drop.isEmpty) return false;
    ClubOpsSync.seedRemovedMembers(drop);
    return true;
  }

  bool _purgeHongGilDongFromRealClubs() {
    if (_isDemoSession) return false;
    final beforeMembers = _members.length;
    final beforeTx = _transactions.length;
    final beforePay = _duesPayments.length;
    _scrubSeedNamesFromFreshClubs();
    _transactions.removeWhere((t) =>
        DemoFinanceStrip.isHongGilDongGhost(t.title) ||
        DemoFinanceStrip.isSeedTransaction(id: t.id, clubId: t.clubId));
    _duesPayments.removeWhere((p) =>
        DemoFinanceStrip.isGhostName(p.memberName) ||
        DemoFinanceStrip.isGhostMemberId(p.memberId));
    return _members.length != beforeMembers ||
        _transactions.length != beforeTx ||
        _duesPayments.length != beforePay;
  }

  /// 공지·댓글에 남은 시드 이름(홍길동)을 명단 이름으로 되돌린다.
  bool _scrubSeedAuthorNames() {
    if (_isDemoSession) return false;
    var changed = false;
    for (var i = 0; i < _announcements.length; i++) {
      final a = _announcements[i];
      if (a.clubId != null && _legacyMockClubIds.contains(a.clubId)) continue;
      var rowChanged = false;
      final nextAuthor =
          (a.authorName != null && seedMemberNames.contains(a.authorName!.trim()))
              ? displayAuthorName(
                  authorId: a.authorId ?? '',
                  authorName: a.authorName!,
                  clubId: a.clubId,
                )
              : a.authorName;
      if (nextAuthor != a.authorName) rowChanged = true;
      final nextComments = <AnnouncementComment>[];
      for (final c in a.comments) {
        final name = displayAuthorName(
          authorId: c.authorId,
          authorName: c.authorName,
          clubId: a.clubId,
        );
        if (name != c.authorName) {
          rowChanged = true;
          nextComments.add(AnnouncementComment(
            id: c.id,
            authorId: c.authorId,
            authorName: name,
            text: c.text,
            createdAt: c.createdAt,
          ));
        } else {
          nextComments.add(c);
        }
      }
      if (!rowChanged) continue;
      changed = true;
      _announcements[i] = Announcement(
        id: a.id,
        title: a.title,
        content: a.content,
        isPinned: a.isPinned,
        createdAt: a.createdAt,
        comments: nextComments,
        clubId: a.clubId,
        authorId: a.authorId,
        authorName: nextAuthor,
      );
    }
    return changed;
  }

  /// 댓글/공지 작성자 표시. 시드 이름이면 명단에서 찾아 실제 이름을 보여 준다.
  String displayAuthorName({
    required String authorId,
    required String authorName,
    String? clubId,
  }) {
    final club = (clubId == null || clubId.isEmpty)
        ? (_myClubs.isEmpty ? null : selectedClub.id)
        : clubId;
    if (_isSelfTarget(authorId)) {
      final mine = currentUserName.trim();
      if (mine.isNotEmpty &&
          !isPlaceholderMemberName(mine) &&
          !seedMemberNames.contains(mine)) {
        return mine;
      }
    }
    final member = _memberForAuthorId(authorId, club);
    if (member != null) {
      final n = member.name.trim();
      if (n.isNotEmpty && !isPlaceholderMemberName(n)) return n;
    }
    final raw = authorName.trim();
    if (raw.isNotEmpty && !seedMemberNames.contains(raw)) return raw;
    if (!_isDemoSession &&
        authorId == 'm1' &&
        club != null &&
        !_legacyMockClubIds.contains(club)) {
      final creator =
          _members.where((m) => m.id == 'm_creator_$club').firstOrNull;
      if (creator != null && !seedMemberNames.contains(creator.name.trim())) {
        return creator.name;
      }
    }
    if (raw.isEmpty) return '회원';
    return seedMemberNames.contains(raw) ? '회원' : raw;
  }

  Member? _memberForAuthorId(String authorId, String? clubId) {
    if (authorId.isEmpty) return null;
    final direct = _members.where((m) => m.id == authorId).firstOrNull;
    if (direct != null) return withoutSeedDisplayName(direct);
    if (clubId == null || clubId.isEmpty) return null;
    final roster = membersForClub(clubId);
    final byId = roster.where((m) => m.id == authorId).firstOrNull;
    if (byId != null) return withoutSeedDisplayName(byId);
    final prefixed =
        roster.where((m) => m.id == 'm_${clubId}_$authorId').firstOrNull;
    if (prefixed != null) return withoutSeedDisplayName(prefixed);
    return null;
  }

  /// 실계정 m1 시절에 생성자 사진·생일·전화가 초대 회원 행에 복사된 것을 되돌린다.
  bool _repairCopiedIdentityOnLegacyM1Rows() {
    if (_isDemoSession) return false;
    var changed = false;
    for (final club in _myClubs) {
      if (_legacyMockClubIds.contains(club.id)) continue;
      final leftoverId = _legacyM1RosterId(club.id);
      if (_isMyRosterRowFor(club, leftoverId)) continue;
      final creatorIdx =
          _members.indexWhere((m) => m.id == 'm_creator_${club.id}');
      final leftoverIdx = _members.indexWhere((m) => m.id == leftoverId);
      if (creatorIdx < 0 || leftoverIdx < 0) continue;
      final creator = _members[creatorIdx];
      final leftover = _members[leftoverIdx];
      final samePhoto = (leftover.photoUrl ?? '').trim().isNotEmpty &&
          leftover.photoUrl!.trim() == (creator.photoUrl ?? '').trim();
      final sameBirth = leftover.birthDate != null &&
          creator.birthDate != null &&
          leftover.birthDate == creator.birthDate;
      final samePhone = (leftover.phone ?? '').trim().isNotEmpty &&
          leftover.phone!.trim() == (creator.phone ?? '').trim();
      final sameHandicap = leftover.handicap != null &&
          creator.handicap != null &&
          leftover.handicap == creator.handicap;
      if (!samePhoto && !sameBirth && !samePhone && !sameHandicap) continue;
      _members[leftoverIdx] = leftover.copyWith(
        clearPhoto: samePhoto,
        clearBirthDate: sameBirth,
        clearPhone: samePhone,
        clearHandicap: sameHandicap,
      );
      changed = true;
    }
    return changed;
  }

  /// 모임 명단에 내가 쓴 이름(안경헌)이 있으면 카카오 영문 이름보다 그걸 쓴다.
  /// 번호로 붙은 남의 행(장창현 총무) 이름은 가져오지 않는다.
  void _syncSelfDisplayName() {
    if (_isDemoSession || _myClubs.isEmpty) return;
    final me = currentMember;
    if (me == null || isPlaceholderMemberName(me.name)) return;
    if (!_isMyRosterRowById(selectedClub, me.id)) return;
    // 내 행에 남은 장창현 이름을 계정 이름으로 흡수하면 강남이 또 장창현이 된다.
    if (leftoverStolenNames.contains(me.name.trim()) &&
        me.name.trim() != _currentUserName.trim()) {
      return;
    }
    if (_currentUserName == me.name) return;
    _currentUserName = me.name;
  }

  /// [club] 명단에서 [memberId] 가 내 행인지. `membersForClub` 과 같은 ID 규칙만 본다.
  /// (전역 시드 'm1' 같은 맨 ID는 제외 — 실계정도 currentUserId 가 m1 이다)
  bool _isMyRosterRowFor(Club club, String memberId) {
    if (_isMyRosterRowById(club, memberId)) return true;
    // 남의 방장 자리를 번호로 내 행이라고 보면 이름이 바뀌고 전 모임이 내 모임이 된다.
    if (memberId == 'm_creator_${club.id}') return false;
    if (_claimedRosterIds[club.id] == memberId) return true;
    if (_rosterHasIdLinkedRowOfMine(club)) return false;
    return _rosterRowMatchesMyPhone(club.id, memberId);
  }

  bool _isMyRosterRowById(Club club, String memberId) {
    if (memberId == 'm_creator_${club.id}') {
      return _iAmClubCreator(club);
    }
    final prefix = 'm_${club.id}_';
    if (!memberId.startsWith(prefix)) return false;
    final suffix = memberId.substring(prefix.length);
    if (_persistAuthUserId != null &&
        _userIdsMatch(suffix, _persistAuthUserId)) {
      return true;
    }
    if (_isDemoSession && _userIdsMatch(suffix, currentUserId)) {
      return true;
    }
    return false;
  }

  /// 계정 ID 로 붙은 내 행이 이미 있으면 번호 추정은 하지 않는다(둘째 줄 방지).
  bool _rosterHasIdLinkedRowOfMine(Club club) =>
      _members.any((m) => _isMyRosterRowById(club, m.id));

  bool _rosterRowMatchesMyPhone(String clubId, String memberId) {
    final mine = MemberPhoneIndex.digitsOf(_accountPhone);
    if (mine.isEmpty) return false;
    if (memberId == 'm_creator_$clubId') return false;
    if (MemberPhoneIndex.isSocialAccountRosterId(clubId, memberId)) {
      return false;
    }
    if (!Member.isClubRosterId(clubId, memberId) &&
        !MemberPhoneIndex.isPhoneClaimableMemberId(clubId, memberId)) {
      return false;
    }
    final row = _members.where((m) => m.id == memberId).firstOrNull;
    if (row == null) return false;
    return MemberPhoneIndex.digitsOf(row.phone) == mine;
  }

  /// 초대 가입이 userId 그대로 들어가 명단에 안 보이던 행을 `m_{clubId}_{userId}`로 보정한다.
  bool ensureMyRosterRow(String clubId) {
    final uid = (_persistAuthUserId ?? currentUserId).trim();
    if (uid.isEmpty || _legacyMockClubIds.contains(clubId)) return false;
    final rid = Member.rosterId(clubId, uid);
    if (_members.any((m) => m.id == rid)) return false;

    final club = _myClubs.where((c) => c.id == clubId).firstOrNull;
    final iAmCreator = club != null && _iAmClubCreator(club);
    if (!_isDemoSession &&
        uid != 'm1' &&
        uid != 'user_me' &&
        !iAmCreator) {
      final leftoverId = _legacyM1RosterId(clubId);
      final leftoverIdx = _members.indexWhere((m) => m.id == leftoverId);
      if (leftoverIdx >= 0) {
        _members[leftoverIdx] = _members[leftoverIdx].withId(rid);
        return true;
      }
    }
    if (iAmCreator && _members.any((m) => m.id == 'm_creator_$clubId')) {
      return false;
    }
    if (club != null &&
        ClubMemberRole.isOfficer(club.myRole) &&
        _members.any((m) => m.id == 'm_creator_$clubId')) {
      return false;
    }

    final orphan = _members.where((m) => m.id == uid).firstOrNull;
    final role = ClubMemberRole.normalize(
      club?.myRole ?? ClubMemberRole.regular,
    );
    _members.add(_selfMember(
      id: rid,
      name: orphan?.name ?? currentUserName,
      memberType: ClubMemberRole.memberTypeForRole(role),
      role: role,
      joinDate: orphan?.joinDate ?? DateTime.now(),
      referrerId: orphan?.referrerId,
      referrerName: orphan?.referrerName,
      inherit: orphan,
    ));
    _members.removeWhere((m) => m.id == uid);
    return true;
  }

  /// 생성자 행과 `m_{clubId}_{userId}` 가 같은 사람이면 한 줄로 합친다.
  /// 회원 탭에 임원진·정회원으로 두 번 나오던 원인.
  bool pruneDuplicateRosterRows() {
    var changed = false;
    for (final club in _myClubs) {
      if (_legacyMockClubIds.contains(club.id)) continue;
      final iAmCreator = _iAmClubCreator(club);
      final authIds = <String>{
        if (club.creatorId.trim().isNotEmpty) club.creatorId.trim(),
      };
      if (iAmCreator) {
        authIds.add(currentUserId);
        if (_persistAuthUserId != null) authIds.add(_persistAuthUserId!);
        authIds.addAll(_authAliases(
          _persistAuthUserId ?? (_isDemoSession ? currentUserId : ''),
        ));
      }
      final result = RosterDedupe.collapseClub(
        members: _members,
        clubId: club.id,
        creatorAuthIds: authIds,
      );
      if (result.droppedIds.isEmpty) {
        if (_syncScheduleMemberNames(club.id)) changed = true;
        continue;
      }
      _members
        ..clear()
        ..addAll(result.members);
      ClubOpsSync.seedRemovedMembers(result.droppedIds);
      final prefix = 'm_${club.id}_';
      for (final oldId in result.droppedIds) {
        if (!oldId.startsWith(prefix)) continue;
        unawaited(ClubOpsSync.deleteClubMemberDoc(
          club.id,
          oldId.substring(prefix.length),
        ));
      }
      _applyRosterIdRemap(
        club.id,
        result.idRemap,
        {for (final m in result.members) m.id: m.name},
      );
      _syncScheduleMemberNames(club.id);
      _setMemberCount(club.id, _officialMemberCount(club.id));
      changed = true;
    }
    if (changed) _syncSelfDisplayName();
    return changed;
  }

  void _applyRosterIdRemap(
    String clubId,
    Map<String, String> remap,
    Map<String, String> names,
  ) {
    if (remap.isEmpty) return;
    int rank(String response) {
      if (response == '참석') return 2;
      if (response == '불참') return 1;
      return 0;
    }

    for (var i = 0; i < _schedules.length; i++) {
      final s = _schedules[i];
      if (s.clubId != clubId) continue;
      final byId = <String, AttendanceResponse>{};
      for (final r in s.responses) {
        final newId = remap[r.memberId] ?? r.memberId;
        final next = AttendanceResponse(
          memberId: newId,
          memberName: names[newId] ?? r.memberName,
          response: r.response,
          memo: r.memo,
          // 동반자도 명단 id 다. 안 바꾸면 조편성에서 빈 자리가 된다.
          companionMemberIds: [
            for (final id in r.companionMemberIds) remap[id] ?? id,
          ],
          respondedAt: r.respondedAt,
        );
        final prev = byId[newId];
        if (prev == null ||
            rank(next.response) > rank(prev.response) ||
            (rank(next.response) == rank(prev.response) &&
                next.respondedAt.isAfter(prev.respondedAt))) {
          byId[newId] = next;
        }
      }
      _schedules[i] = s.copyWith(responses: byId.values.toList());
    }

    for (final entry in _groupAssignments.entries.toList()) {
      final ga = entry.value;
      final sched =
          _schedules.where((s) => s.id == ga.scheduleId).firstOrNull;
      if (sched == null || sched.clubId != clubId) continue;
      _groupAssignments[entry.key] = ga.copyWith(
        groups: [
          for (final g in ga.groups)
            g.copyWithSlots([
              for (final slot in g.slots)
                slot.memberId == null
                    ? slot
                    : slot.copyWith(
                        memberId: remap[slot.memberId] ?? slot.memberId,
                        memberName: names[remap[slot.memberId] ?? slot.memberId!] ??
                            slot.memberName,
                      ),
            ]),
        ],
      );
    }

    for (var i = 0; i < _awardRecords.length; i++) {
      final a = _awardRecords[i];
      final ids = a.winnerIds.map((id) => remap[id] ?? id).toList();
      _awardRecords[i] = AwardRecord(
        id: a.id,
        scheduleId: a.scheduleId,
        scheduleName: a.scheduleName,
        awardName: a.awardName,
        awardIcon: a.awardIcon,
        winnerIds: ids,
        winnerNames: [
          for (var j = 0; j < ids.length; j++)
            names[ids[j]] ??
                (j < a.winnerNames.length ? a.winnerNames[j] : ids[j]),
        ],
        winnerNote: a.winnerNote,
        recordedAt: a.recordedAt,
      );
    }

    for (var i = 0; i < _roundScores.length; i++) {
      final r = _roundScores[i];
      Map<String, int> remapInts(Map<String, int> src) {
        final out = <String, int>{};
        src.forEach((id, value) {
          out[remap[id] ?? id] = value;
        });
        return out;
      }

      _roundScores[i] = RoundScoreRecord(
        scheduleId: r.scheduleId,
        scores: remapInts(r.scores),
        handicaps: remapInts(r.handicaps),
        recordedAt: r.recordedAt,
      );
    }

    // 회비·포인트도 같은 사람이다. 여기서 안 옮기면 행 id 만 바뀌고
    // 납부 내역·랭킹이 옛 id 에 남아 "낸 적 없는 사람"이 된다.
    for (var i = 0; i < _duesPayments.length; i++) {
      final p = _duesPayments[i];
      final to = remap[p.memberId];
      if (to == null || to == p.memberId) continue;
      _duesPayments[i] = DuesPayment(
        id: p.id,
        memberId: to,
        memberName: names[to] ?? p.memberName,
        duesSettingId: p.duesSettingId,
        amount: p.amount,
        paidAt: p.paidAt,
        memo: p.memo,
        recordedBy: p.recordedBy,
        skipsBalance: p.skipsBalance,
      );
    }
    for (var i = 0; i < _paymentRequests.length; i++) {
      final r = _paymentRequests[i];
      final to = remap[r.memberId];
      if (to == null || to == r.memberId) continue;
      _paymentRequests[i] = PaymentRequest(
        id: r.id,
        memberId: to,
        memberName: names[to] ?? r.memberName,
        duesSettingId: r.duesSettingId,
        duesTitle: r.duesTitle,
        amount: r.amount,
        requestedAt: r.requestedAt,
        clubId: r.clubId,
        status: r.status,
        reviewedBy: r.reviewedBy,
        reviewedAt: r.reviewedAt,
        year: r.year,
        month: r.month,
        memo: r.memo,
      );
    }
    for (final entry in remap.entries) {
      if (entry.key == entry.value) continue;
      final events = _pointEvents.remove(entry.key);
      if (events == null || events.isEmpty) continue;
      _pointEvents.update(
        entry.value,
        (cur) => [...cur, ...events],
        ifAbsent: () => events,
      );
    }

    // 대기 명단
    for (var i = 0; i < _waitingList.length; i++) {
      final w = _waitingList[i];
      final to = remap[w.memberId];
      if (to == null || to == w.memberId) continue;
      _waitingList[i] = WaitingEntry(
        id: w.id,
        scheduleId: w.scheduleId,
        memberId: to,
        memberName: names[to] ?? w.memberName,
        registeredAt: w.registeredAt,
        status: w.status,
        notifiedAt: w.notifiedAt,
      );
    }

    // 공지·댓글 작성자, 활동 피드, 소개자 — 이름 옆 표시가 '알 수 없음'이 되지 않게
    for (var i = 0; i < _announcements.length; i++) {
      final a = _announcements[i];
      if (a.clubId != null && a.clubId != clubId) continue;
      final toAuthor = remap[a.authorId ?? ''];
      final comments = [
        for (final c in a.comments)
          remap[c.authorId] == null
              ? c
              : AnnouncementComment(
                  id: c.id,
                  authorId: remap[c.authorId]!,
                  authorName: names[remap[c.authorId]!] ?? c.authorName,
                  text: c.text,
                  createdAt: c.createdAt,
                ),
      ];
      if (toAuthor == null &&
          comments.map((c) => c.authorId).join('|') ==
              a.comments.map((c) => c.authorId).join('|')) {
        continue;
      }
      _announcements[i] = Announcement(
        id: a.id,
        title: a.title,
        content: a.content,
        isPinned: a.isPinned,
        createdAt: a.createdAt,
        comments: comments,
        clubId: a.clubId,
        authorId: toAuthor ?? a.authorId,
        authorName: toAuthor == null
            ? a.authorName
            : (names[toAuthor] ?? a.authorName),
      );
    }
    for (var i = 0; i < _activities.length; i++) {
      final act = _activities[i];
      final to = remap[act.memberId];
      if (to == null || to == act.memberId) continue;
      _activities[i] = ActivityItem(
        id: act.id,
        memberId: to,
        memberName: names[to] ?? act.memberName,
        memberPhotoUrl: act.memberPhotoUrl,
        activityType: act.activityType,
        description: act.description,
        timestamp: act.timestamp,
      );
    }
    for (var i = 0; i < _members.length; i++) {
      final m = _members[i];
      final to = remap[m.referrerId ?? ''];
      if (to == null) continue;
      _members[i] = m.copyWith(referrerId: to);
    }
  }

  /// 이름만 바꾼다. 회비·시상·참석은 memberId 로 이미 붙어 있으므로 표시 이름만 맞춘다.
  void _relabelMemberDisplayName(String memberId, String name) {
    final target = name.trim();
    if (memberId.isEmpty ||
        target.isEmpty ||
        isPlaceholderMemberName(target)) {
      return;
    }
    for (var i = 0; i < _duesPayments.length; i++) {
      final p = _duesPayments[i];
      if (p.memberId != memberId || p.memberName == target) continue;
      _duesPayments[i] = DuesPayment(
        id: p.id,
        memberId: p.memberId,
        memberName: target,
        duesSettingId: p.duesSettingId,
        amount: p.amount,
        paidAt: p.paidAt,
        memo: p.memo,
        recordedBy: p.recordedBy,
        skipsBalance: p.skipsBalance,
      );
    }
    for (var i = 0; i < _paymentRequests.length; i++) {
      final r = _paymentRequests[i];
      if (r.memberId != memberId || r.memberName == target) continue;
      _paymentRequests[i] = r.copyWith(memberName: target);
    }
    for (var i = 0; i < _awardRecords.length; i++) {
      final a = _awardRecords[i];
      if (!a.winnerIds.contains(memberId)) continue;
      final names = <String>[
        for (var j = 0; j < a.winnerIds.length; j++)
          a.winnerIds[j] == memberId
              ? target
              : (j < a.winnerNames.length ? a.winnerNames[j] : a.winnerIds[j]),
      ];
      if (names.join('|') == a.winnerNames.join('|')) continue;
      _awardRecords[i] = AwardRecord(
        id: a.id,
        scheduleId: a.scheduleId,
        scheduleName: a.scheduleName,
        awardName: a.awardName,
        awardIcon: a.awardIcon,
        winnerIds: a.winnerIds,
        winnerNames: names,
        winnerNote: a.winnerNote,
        recordedAt: a.recordedAt,
      );
    }
    for (final club in _myClubs) {
      if (_legacyMockClubIds.contains(club.id)) continue;
      _syncScheduleMemberNames(club.id);
    }
  }

  /// 내가 만든 모임의 방장 표시 이름. 방장 식별자는 host_user_id / creator_id 이다.
  void _pushMyHostDisplayName(String hostName) {
    final uid = (_persistAuthUserId ?? currentUserId).trim();
    if (uid.isEmpty || isPlaceholderMemberName(hostName)) return;
    for (final club in List<Club>.from(_myClubs)) {
      if (_legacyMockClubIds.contains(club.id)) continue;
      if (!_iAmClubCreator(club)) continue;
      unawaited(_pushClubCatalogToServer(
        club.id,
        hostName: hostName,
        hostUserId: uid,
      ));
    }
  }

  bool _syncScheduleMemberNames(String clubId) {
    final byId = {for (final m in membersForClub(clubId)) m.id: m.name};
    var changed = false;
    for (var i = 0; i < _schedules.length; i++) {
      final s = _schedules[i];
      if (s.clubId != clubId) continue;
      var rowChanged = false;
      final next = s.responses.map((r) {
        final name = byId[r.memberId];
        if (name == null || name == r.memberName) return r;
        rowChanged = true;
        return AttendanceResponse(
          memberId: r.memberId,
          memberName: name,
          response: r.response,
          memo: r.memo,
          companionMemberIds: r.companionMemberIds,
          respondedAt: r.respondedAt,
        );
      }).toList();
      if (!rowChanged) continue;
      _schedules[i] = s.copyWith(responses: next);
      changed = true;
    }
    return changed;
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

  Future<void> _recountOfficialMemberCount(String clubId) async {
    if (_isDemoSession || clubId.trim().isEmpty) return;
    if (!AppDependencies.instance.isInitialized ||
        AppDependencies.instance.isOfflineMockMode) {
      return;
    }
    try {
      final n = await AppDependencies.instance.clubRepository
          .recountMemberCount(clubId);
      _setMemberCount(clubId, n);
    } catch (e) {
      debugPrint('[ClubProvider] member count recount skip: $e');
    }
  }

  // ════════════════════════════════════════════════════════
  //  Actions — Update Club teamCount (매달 변경)
  // ════════════════════════════════════════════════════════
  void updateClubTeamCount(String clubId, int teamCount) {
    unawaited(updateClubInfo(clubId: clubId, teamCount: teamCount));
  }

  /// 모임 기본 정보 수정 (이름·소개·이미지·팀 수·지역·업종)
  /// 같은 이름이 이미 있으면 저장하지 않고 false.
  Future<bool> updateClubInfo({
    required String clubId,
    String? name,
    String? description,
    String? imageUrl,
    int? teamCount,
    String? hostName,
    String? hostUserId,
    String? region,
    String? industry,
  }) async {
    if (name != null &&
        await isClubNameTaken(name, exceptClubId: clubId)) {
      return false;
    }
    void apply(List<Club> list) {
      final idx = list.indexWhere((c) => c.id == clubId);
      if (idx == -1) return;
      list[idx] = list[idx].copyWith(
        name: name,
        description: description,
        imageUrl: imageUrl,
        teamCount: teamCount,
        region: region,
        industry: industry,
      );
    }

    apply(_myClubs);
    apply(_allClubs);
    final saved = _myClubs.where((c) => c.id == clubId).firstOrNull ??
        _allClubs.where((c) => c.id == clubId).firstOrNull;
    if (saved != null) {
      _clubInfoOverrides[clubId] = saved;
    }
    notifyListeners();
    _syncMyClubsToMockStore();
    await _persistNow();
    String? catalogImage = imageUrl;
    if (catalogImage != null &&
        catalogImage.startsWith('data:') &&
        catalogImage.length > 180000) {
      catalogImage = null;
    }
    await _pushClubCatalogToServer(clubId,
        name: name,
        description: description,
        imageUrl: catalogImage,
        teamCount: teamCount,
        hostName: hostName,
        hostUserId: hostUserId,
        region: region,
        industry: industry);
    return true;
  }

  Future<void> _pushClubCatalogToServer(
    String clubId, {
    String? name,
    String? description,
    String? imageUrl,
    int? teamCount,
    String? hostName,
    String? hostUserId,
    String? region,
    String? industry,
  }) async {
    if (_isDemoSession) return;
    if (!AppDependencies.instance.isInitialized ||
        AppDependencies.instance.isOfflineMockMode) {
      return;
    }
    try {
      await AppDependencies.instance.clubRepository.updateClubInfo(
        clubId,
        name: name,
        description: description,
        imageUrl: imageUrl,
        teamCount: teamCount,
        hostName: hostName,
        hostUserId: hostUserId,
        region: region,
        industry: industry,
      );
    } catch (e) {
      debugPrint('[ClubProvider] catalog push skip: $e');
    }
  }

  Future<void> _pushOwnedClubCatalog() async {
    if (_isDemoSession) return;
    for (final club in List<Club>.from(_myClubs)) {
      if (_legacyMockClubIds.contains(club.id)) continue;
      if (!_iAmClubCreator(club)) continue;
      if (club.name.trim().isEmpty) continue;
      await _pushClubCatalogToServer(
        club.id,
        name: club.name,
        description: club.description,
        imageUrl: club.imageUrl,
        teamCount: club.teamCount,
        hostName: currentUserName,
        hostUserId: (_persistAuthUserId ?? currentUserId).trim(),
      );
    }
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
    final applicantId = userId ?? _persistAuthUserId ?? currentUserId;
    if (AppDependencies.instance.isInitialized &&
        !AppDependencies.instance.isOfflineMockMode) {
      try {
        final existing = await AppDependencies.instance.joinRequestRepository
            .fetchPendingForUser(clubId, applicantId);
        if (existing != null) {
          await publishJoinRequestToOfficer(existing);
          return true;
        }
      } catch (e) {
        debugPrint('[ClubProvider] fetch pending join user skip: $e');
      }
    }
    final req = JoinRequest(
      id: 'jr_${DateTime.now().millisecondsSinceEpoch}',
      clubId: clubId,
      userId: applicantId,
      userName: userName ?? currentUserName,
      userGender: (_accountGender != null && _accountGender!.isNotEmpty)
          ? _accountGender!
          : '남',
      userHandicap: handicap ?? _accountHandicap,
      userPhone: _accountPhone,
      userPhotoUrl: _accountPhotoUrl,
      userBirthDate: _accountBirthDate,
      message: message,
      referrerId: referrerId,
      referrerName: referrerName,
      requestedAt: DateTime.now(),
    );
    try {
      await AppDependencies.instance.joinRequestRepository.submitJoinRequest(
        clubId: req.clubId,
        userId: req.userId,
        userName: req.userName,
        userGender: req.userGender,
        userHandicap: req.userHandicap,
        userPhone: req.userPhone,
        userPhotoUrl: req.userPhotoUrl,
        userBirthDate: req.userBirthDate,
        message: req.message,
        requestId: req.id,
      );
    } catch (e) {
      debugPrint('[ClubProvider] firestore join submit: $e');
    }
    await publishJoinRequestToOfficer(req);
    return true;
  }

  bool _pendingOpenJoinRequests = false;

  void requestOpenJoinRequests() {
    _pendingOpenJoinRequests = true;
  }

  bool consumeOpenJoinRequests() {
    final open = _pendingOpenJoinRequests;
    _pendingOpenJoinRequests = false;
    return open;
  }

  /// 신청을 총무(없으면 회장) 알림함·모임 대기열에 올린다.
  Future<void> publishJoinRequestToOfficer(JoinRequest req) async {
    try {
      await SharedJoinRequestStore.upsert(req);
    } catch (e) {
      debugPrint('[ClubProvider] shared join upsert early failed: $e');
    }
    _ingestPendingJoinRequest(req);

    _activities.insert(0, ActivityItem(
      id: 'act_join_${DateTime.now().millisecondsSinceEpoch}',
      memberId: req.userId,
      memberName: req.userName,
      activityType: 'join',
      description: '가입 신청 (승인 대기 중)',
      timestamp: DateTime.now(),
    ));

    final club = _allClubs.where((c) => c.id == req.clubId).firstOrNull ??
        _myClubs.where((c) => c.id == req.clubId).firstOrNull;
    // 신청자 폰 명단은 그 모임 총무가 없다. 서버 소속 계정으로 고른다.
    final officerIds = await _resolveJoinNotifyAccountIds(req.clubId);
    final inboxIds = <String>{};
    for (final raw in officerIds) {
      final inbox = raw.isEmpty
          ? ''
          : _fcmInboxIdFor(raw, clubId: req.clubId);
      if (inbox.isNotEmpty) {
        inboxIds.add(inbox);
      } else if (raw.isNotEmpty) {
        inboxIds.add(raw);
      }
    }
    final notifyRole = _joinNotifyHasTreasurer(req.clubId)
        ? ClubMemberRole.treasurer
        : ClubMemberRole.president;
    final primaryInbox = inboxIds.isEmpty ? '' : inboxIds.first;
    final noti = AppNotification(
      id: 'noti_jr_${req.id}',
      type: AppNotificationType.joinRequest,
      clubId: req.clubId,
      clubName: club?.name ?? '모임',
      isAdmin: true,
      title: '가입 신청',
      body: '${req.userName}님이 가입을 신청했습니다 → $notifyRole 수신',
      createdAt: DateTime.now(),
      targetId: req.id,
      targetUserId: primaryInbox.isNotEmpty ? primaryInbox : null,
      isRead: false,
    );

    await ClubOpsSync.upsertClubJoinRequest(req);
    var delivered = false;
    for (final inboxId in inboxIds) {
      if (inboxId.isEmpty || _isSelfTarget(inboxId)) continue;
      delivered = true;
      await ClubOpsSync.appendOfficerInbox(
        authUserId: inboxId,
        notification: noti,
        request: req,
      );
      unawaited(PushNotificationService.enqueue(
        targetUserId: inboxId,
        title: noti.title,
        body: '${req.userName}님이 ${club?.name ?? '모임'} 가입을 신청했습니다',
        type: HqPushCatalog.joinRequest,
        clubId: req.clubId,
      ));
    }
    if (!delivered && primaryInbox.isNotEmpty) {
      unawaited(PushNotificationService.enqueue(
        targetUserId: primaryInbox,
        title: noti.title,
        body: '${req.userName}님이 ${club?.name ?? '모임'} 가입을 신청했습니다',
        type: HqPushCatalog.joinRequest,
        clubId: req.clubId,
      ));
    }

    AppDependencies.instance.mockDataStore?.upsertPendingJoinRequest(req);
    notifyListeners();
    _persistImmediately();
    await _publishJoinRequestCrossAccount(req, noti);
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
    // 실계정은 switchUser 가 currentUserId 를 m1 로 둔다. Firestore 멤버십은
    // 카카오 id 로 써야 초대한 사람 명단에 같은 사람이 보인다.
    final authUserId = _persistAuthUserId ?? currentUserId;
    final userName = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : currentUserName;
    final role = asGuest ? ClubMemberRole.guest : ClubMemberRole.regular;
    final memberType =
        asGuest ? ClubMemberRole.guest : ClubMemberRole.regular;
    final rosterId = Member.rosterId(clubId, authUserId);

    try {
      await FirebaseAuthBridge.ensureStagingSession(userId: authUserId);
    } catch (e) {
      debugPrint('[ClubProvider] joinViaInvite auth skip: $e');
    }

    Club? club = _myClubs.where((c) => c.id == clubId).firstOrNull ??
        _allClubs.where((c) => c.id == clubId).firstOrNull ??
        AppDependencies.instance.mockDataStore?.clubById(clubId);

    Future<Club?> readServerClub() async {
      try {
        return await AppDependencies.instance.clubRepository
            .fetchClubById(clubId, userId: authUserId)
            .timeout(const Duration(seconds: 12));
      } catch (e) {
        debugPrint('[ClubProvider] joinViaInvite fetchClub skip: $e');
        return null;
      }
    }

    club ??= await readServerClub();

    final member = _selfMember(
      id: rosterId,
      name: userName,
      memberType: memberType,
      role: role,
      joinDate: DateTime.now(),
      referrerId: referrerId,
      referrerName: referrerName,
    );

    try {
      await AppDependencies.instance.clubRepository.addMemberViaInvite(
        clubId: clubId,
        userId: authUserId,
        member: member,
      );
    } catch (e) {
      debugPrint('[ClubProvider] joinViaInvite remote fail: $e');
      return false;
    }

    club = await readServerClub() ?? club;
    if (club == null) {
      debugPrint('[ClubProvider] joinViaInvite — no server club $clubId');
      return false;
    }

    final resolvedName = (clubName != null && clubName.trim().isNotEmpty)
        ? clubName.trim()
        : club.name;

    if (!_legacyMockClubIds.contains(clubId)) {
      _freshClubIds.add(clubId);
    }

    // 예전 초대 가입은 userId 그대로 넣어서 명단 필터에 안 걸렸다. 고쳐서 다시 넣는다.
    _members.removeWhere((m) => m.id == currentUserId && m.id != rosterId);

    final alreadyListed = _members.any((m) => m.id == rosterId);
    if (!alreadyListed) {
      _members.add(member);
    }
    try {
      AppDependencies.instance.mockDataStore?.addMember(
        clubId: clubId,
        member: member,
        alsoAsIds: [authUserId, currentUserId],
        bumpCount: !alreadyListed,
      );
    } catch (_) {}

    final joinedClub = club.copyWith(
      name: resolvedName,
      myRole: role,
      memberCount: club.memberCount < 1 ? 1 : club.memberCount,
    );
    if (!_myClubs.any((c) => c.id == clubId)) {
      _myClubs.add(joinedClub);
    } else {
      final i = _myClubs.indexWhere((c) => c.id == clubId);
      if (i != -1) {
        _myClubs[i] = _myClubs[i].copyWith(
          name: resolvedName,
          myRole: role,
        );
      }
    }
    if (!_allClubs.any((c) => c.id == clubId)) {
      _allClubs.add(joinedClub);
    }

    _activities.insert(
      0,
      ActivityItem(
        id: 'act_invite_${DateTime.now().millisecondsSinceEpoch}',
        memberId: authUserId,
        memberName: userName,
        activityType: 'join',
        description: asGuest ? '초대 링크로 게스트 가입' : '초대 링크로 즉시 가입',
        timestamp: DateTime.now(),
      ),
    );

    final notifyTarget = joinRequestNotifyTargetId(clubId);
    addAppNotification(
      AppNotification(
        id: 'noti_invite_join_${clubId}_$authUserId',
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
      final merged = await ClubOpsSync.pullMergeClub(
        clubId: clubId,
        local: _exportBundle(),
        seedIfMissing: false,
      );
      if (merged != null) _importBundle(merged);
    } catch (e) {
      debugPrint('[ClubProvider] joinViaInvite ops pull skip: $e');
    }
    await hydrateClubAccounts(clubId);
    await _hydrateRosterFromServer(clubId);
    // 방장이 이름·번호만 적어 둔 내 행이 있으면 새 행과 합친다 (두 줄 방지)
    _absorbUnlinkedRowsByPhone(clubId);
    _rememberOfficialClub(clubId);

    selectClubById(clubId);
    notifyListeners();
    _persistImmediately();
    return true;
  }

  /// 총무 화면 진입 시 호출 — Firestore 대기열 → 알림 강제 동기화
  Future<void> refreshJoinRequestInbox() async {
    if (!AppDependencies.instance.isOfflineMockMode) {
      for (final club in _myClubs) {
        final canApprove = ClubMemberRole.canApproveJoins(club.myRole) ||
            _userIdsMatch(club.creatorId, currentUserId) ||
            _userIdsMatch(club.creatorId, _persistAuthUserId);
        if (!canApprove) continue;
        try {
          final remote = await AppDependencies.instance.joinRequestRepository
              .fetchPendingForClub(club.id);
          for (final req in remote) {
            _ingestPendingJoinRequest(req);
          }
        } catch (e) {
          debugPrint('[ClubProvider] fetch pending join skip ${club.id}: $e');
        }
      }
    }
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
          roundScores: List<RoundScoreRecord>.from(saved.roundScores),
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
        roundScores: List<RoundScoreRecord>.from(saved.roundScores),
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
    if (!_canReviewJoin(req)) {
      debugPrint('[ClubProvider] approveRequest blocked — not an officer');
      return;
    }

    final assignedRole = ClubMemberRole.roleForMemberType(memberType, role);
    final assignedType = ClubMemberRole.memberTypeForRole(assignedRole);

    _joinRequests[idx] = req.copyWith(
      status: JoinRequestStatus.approved,
      reviewedBy: currentUserName,
      reviewedAt: DateTime.now(),
    );

    // 명단은 신청한 그 모임에만 쌓는다. 총무가 다른 모임을 보고 있어도
    // selectedClub 이 아니라 req.clubId 로 붙인다. 로컬 필터용 rosterId.
    final newMember = Member(
      id: Member.rosterId(req.clubId, req.userId),
      name: req.userName,
      gender: req.userGender,
      memberType: assignedType,
      role: assignedRole,
      handicap: req.userHandicap,
      phone: req.userPhone,
      photoUrl: req.userPhotoUrl,
      birthDate: req.userBirthDate,
      joinDate: DateTime.now(),
      status: '활성',
      referrerId: req.referrerId,
      referrerName: req.referrerName,
    );
    _members.removeWhere((m) =>
        m.id == newMember.id ||
        (m.id == req.userId && Member.isClubRosterId(req.clubId, m.id)));
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

    // 신청자에게 승인 알림 — 누르면 신청한 그 모임으로 들어간다.
    final club = _allClubs.where((c) => c.id == req.clubId).firstOrNull ??
        _myClubs.where((c) => c.id == req.clubId).firstOrNull;
    final approvedNoti = AppNotification(
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
    );
    addAppNotification(
      approvedNoti,
      hqPushTypeId: HqPushCatalog.joinResult,
      notifySelf: false,
    );

    // 탈퇴 이력 있으면 신청자 계정에서 해제 + 내 모임 복구
    unawaited(_clearLeftClubForApplicant(req.userId, req.clubId));

    unawaited(_persistApprovedJoin(
      request: _joinRequests[idx],
      memberType: assignedType,
      role: assignedRole,
      approvedNoti: approvedNoti,
    ));

    notifyListeners();
    _persistImmediately();
  }

  Future<void> _persistApprovedJoin({
    required JoinRequest request,
    required String memberType,
    required String role,
    required AppNotification approvedNoti,
  }) async {
    try {
      await AppDependencies.instance.joinRequestRepository.approveJoinRequest(
        request: request,
        memberType: memberType,
        role: role,
        reviewedBy: _persistAuthUserId ?? currentUserId,
      );
    } catch (e) {
      debugPrint('[ClubProvider] approve join remote skip: $e');
    }
    try {
      await ClubOpsSync.upsertClubJoinRequest(request);
    } catch (e) {
      debugPrint('[ClubProvider] approve join ops skip: $e');
    }
    try {
      await ClubOpsSync.appendApplicantInbox(
        authUserId: request.userId,
        notification: approvedNoti,
      );
    } catch (e) {
      debugPrint('[ClubProvider] approve applicant inbox skip: $e');
    }
    try {
      // 총무가 다른 모임을 보고 있어도 신청한 그 모임 ops만 올린다.
      await ClubOpsSync.pushClubOps(
        clubId: request.clubId,
        bundle: _exportBundle(),
      );
    } catch (e) {
      debugPrint('[ClubProvider] approve club ops skip: $e');
    }
    await _recountOfficialMemberCount(request.clubId);
  }

  void rejectRequest(String requestId) {
    final idx = _joinRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return;
    final req = _joinRequests[idx];
    if (!_canReviewJoin(req)) {
      debugPrint('[ClubProvider] rejectRequest blocked — not an officer');
      return;
    }
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
      if (_isDemoSession &&
          (_persistAuthUserId == 'user_me' || currentUserId == 'm1')) ...[
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
    final leavingUser = (_persistAuthUserId ?? currentUserId).trim();
    if (leavingUser.isNotEmpty &&
        AppDependencies.instance.isInitialized &&
        !AppDependencies.instance.isOfflineMockMode) {
      try {
        await AppDependencies.instance.clubRepository.removeOfficialMembership(
          clubId: resolvedId,
          userId: leavingUser,
        );
      } catch (e) {
        debugPrint('[ClubProvider] leave membership skip: $e');
      }
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
      final prev = _members[idx];
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
        syncAuthGolfProfile(
          birthDate: normalized.birthDate,
          handicap: normalized.handicap,
          gender: normalized.gender,
          phone: normalized.phone,
          photoUrl: normalized.photoUrl,
        );
      }
      // 이름은 라벨이다. ID가 같은 회비·시상·참석 표시만 맞춘다. 새 행을 만들지 않는다.
      if (prev.name.trim() != normalized.name.trim()) {
        _relabelMemberDisplayName(normalized.id, normalized.name);
        if (isSelf &&
            !isPlaceholderMemberName(normalized.name) &&
            !(leftoverStolenNames.contains(normalized.name.trim()) &&
                normalized.name.trim() != _currentUserName.trim())) {
          _currentUserName = normalized.name.trim();
          _pushMyHostDisplayName(normalized.name.trim());
        }
      }
      notifyListeners();
      _persistImmediately();
    }
  }

  /// 소셜 로그인 후 등록한 이름·휴대폰을 로컬 명단에 반영
  ///
  /// 이름은 라벨이다. 내 명단 **ID 행**에만 쓴다. 새 회원을 만들지 않는다.
  /// 전화 인증에서 방금 입력한 실명은 placeholder가 아니어도 덮는다.
  void syncAuthUserProfile({required String phone, String? name}) {
    final authId = _persistAuthUserId ?? currentUserId;
    if (authId.isEmpty || phone.trim().isEmpty) return;
    final trimmedName = name?.trim() ?? '';
    final applyName = trimmedName.isNotEmpty &&
        !isPlaceholderMemberName(trimmedName);
    var changed = false;
    final touchedIds = <String>{};
    for (final club in _myClubs) {
      if (_legacyMockClubIds.contains(club.id)) continue;
      for (var i = 0; i < _members.length; i++) {
        final m = _members[i];
        if (!_isMyRosterRowFor(club, m.id)) continue;
        final phoneDigits = (m.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
        final needPhone = phoneDigits.length < 10;
        final needName = applyName && m.name.trim() != trimmedName;
        if (!needPhone && !needName) continue;
        _members[i] = m.copyWith(
          phone: needPhone ? phone : null,
          name: needName ? trimmedName : null,
        );
        if (needName) touchedIds.add(m.id);
        changed = true;
      }
    }
    if (applyName) {
      _currentUserName = trimmedName;
    }
    if (changed) {
      for (final id in touchedIds) {
        _relabelMemberDisplayName(id, trimmedName);
      }
      if (applyName) _pushMyHostDisplayName(trimmedName);
      notifyListeners();
      _persistImmediately();
    }
  }

  /// 소셜 로그인 후 등록한 휴대폰을 로컬 명단에 반영
  void syncAuthUserPhone(String phone) {
    syncAuthUserProfile(phone: phone);
  }

  void _applyHydratedAuthProfile(AppUser user) {
    final authId = (_persistAuthUserId ?? '').trim();
    if (authId.isEmpty) return;
    if (!_userIdsMatch(user.id, authId)) return;
    syncAuthGolfProfile(
      birthDate: user.birthDate,
      handicap: user.handicap,
      gender: user.gender,
      phone: user.phone,
      photoUrl: user.profileImageUrl,
    );
  }

  Member _preferLocalMemberProfile(Member incoming, Member local) {
    final inPhoto = (incoming.photoUrl ?? '').trim();
    final inPhone = (incoming.phone ?? '').trim();
    return incoming.copyWith(
      photoUrl: inPhoto.isNotEmpty ? incoming.photoUrl : local.photoUrl,
      phone: inPhone.isNotEmpty ? incoming.phone : local.phone,
      birthDate: incoming.birthDate ?? local.birthDate,
      handicap: incoming.handicap ?? local.handicap,
    );
  }

  /// 계정에 저장한 생년월일·평균타수·성별·전화·사진을 내가 속한 모든 모임 명단에 반영.
  ///
  /// 본인이 직접 입력한 값이므로 비어 있지 않으면 덮어쓴다.
  /// 반영 후 Firestore ops bundle 까지 밀어서 다른 기기·총무 화면에도 보이게 한다.
  /// 내 사진의 기준은 계정이다. 모임 명단 문서는 만들 때 한 번 찍힌 값이라
  /// 계정 사진이 나중에 오면 방장 칸이 비어 남는다. 원격 명단을 받은 뒤에도
  /// 계정 값으로 빈 칸만 채운다.
  bool _fillMyRosterProfile() {
    final authId = (_persistAuthUserId ?? '').trim();
    if (authId.isEmpty) return false;
    if (!_isDemoSession && (authId == 'm1' || authId == 'user_me')) return false;

    final photo = (_accountPhotoUrl ?? '').trim();
    final phone = (_accountPhone ?? '').trim();
    if (photo.isEmpty &&
        phone.isEmpty &&
        _accountBirthDate == null &&
        _accountHandicap == null) {
      return false;
    }

    var changed = false;
    for (final club in _myClubs) {
      if (_legacyMockClubIds.contains(club.id)) continue;
      for (var i = 0; i < _members.length; i++) {
        final m = _members[i];
        if (!_isMyRosterRowFor(club, m.id)) continue;
        final needPhoto = photo.isNotEmpty && (m.photoUrl ?? '').trim().isEmpty;
        final needPhone = phone.isNotEmpty && (m.phone ?? '').trim().isEmpty;
        final needBirth = _accountBirthDate != null && m.birthDate == null;
        final needHandicap = _accountHandicap != null && m.handicap == null;
        if (!needPhoto && !needPhone && !needBirth && !needHandicap) continue;
        _members[i] = m.copyWith(
          photoUrl: needPhoto ? photo : null,
          phone: needPhone ? phone : null,
          birthDate: needBirth ? _accountBirthDate : null,
          handicap: needHandicap ? _accountHandicap : null,
        );
        changed = true;
      }
    }
    return changed;
  }

  void syncAuthGolfProfile({
    DateTime? birthDate,
    double? handicap,
    String? gender,
    String? phone,
    String? photoUrl,
  }) {
    if (birthDate != null) _accountBirthDate = birthDate;
    if (handicap != null) _accountHandicap = handicap;
    if (gender != null && gender.isNotEmpty) _accountGender = gender;
    if (phone != null && phone.trim().isNotEmpty) _accountPhone = phone.trim();
    if (photoUrl != null && photoUrl.isNotEmpty) _accountPhotoUrl = photoUrl;

    if (birthDate == null &&
        handicap == null &&
        (gender == null || gender.isEmpty) &&
        (phone == null || phone.trim().isEmpty) &&
        (photoUrl == null || photoUrl.isEmpty)) {
      return;
    }
    final authId = _persistAuthUserId;
    if (authId == null || authId.isEmpty) return;
    // 실계정 키는 카카오 id. m1 을 쓰면 이정원(m_{club}_m1) 사진·생일이 덮인다.
    if (!_isDemoSession && (authId == 'm1' || authId == 'user_me')) return;

    var changed = false;
    for (var i = 0; i < _members.length; i++) {
      final m = _members[i];
      if (_isLegacyM1RosterId(m.id)) continue;
      var match = m.id == authId ||
          m.id.endsWith('_$authId') ||
          (_persistAuthUserId != null &&
              _userIdsMatch(m.id, _persistAuthUserId));
      if (!match && m.id.startsWith('m_creator_')) {
        final clubId = m.id.substring('m_creator_'.length);
        final club = _clubById(clubId);
        if (club != null && _iAmClubCreator(club)) match = true;
      }
      if (!match) continue;
      final nextGender = (gender != null && gender.isNotEmpty)
          ? gender
          : m.gender;
      final nextPhone = (phone != null && phone.trim().isNotEmpty)
          ? phone.trim()
          : m.phone;
      final nextPhoto = (photoUrl != null && photoUrl.isNotEmpty)
          ? photoUrl
          : m.photoUrl;
      final nextBirth = birthDate ?? m.birthDate;
      final nextHandicap = handicap ?? m.handicap;
      if (m.birthDate == nextBirth &&
          m.handicap == nextHandicap &&
          m.gender == nextGender &&
          m.phone == nextPhone &&
          m.photoUrl == nextPhoto) {
        continue;
      }
      _members[i] = m.copyWith(
        birthDate: nextBirth,
        handicap: nextHandicap,
        gender: nextGender,
        phone: nextPhone,
        photoUrl: nextPhoto,
      );
      changed = true;
    }
    if (changed) {
      notifyListeners();
      _persistImmediately();
    }
    unawaited(_pushMyProfileToAllClubMemberDocs());
  }

  Future<void> _pushMyProfileToAllClubMemberDocs() async {
    final uid = (_persistAuthUserId ?? '').trim();
    if (uid.isEmpty || _isDemoSession) return;
    if (!_serverClubsAligned) return;
    final allowed = _confirmedClubIds.isNotEmpty
        ? _confirmedClubIds
        : _sessionCreatedClubIds;
    if (allowed.isEmpty) return;
    for (final club in List<Club>.from(_myClubs)) {
      if (!allowed.contains(club.id)) continue;
      if (ClubOpsSync.isForeignLeftoverMember(
        id: uid,
        name: _currentUserName,
        clubId: club.id,
        creatorUserId: club.creatorId,
      )) {
        continue;
      }
      unawaited(ClubOpsSync.upsertMemberProfile(
        clubId: club.id,
        userId: uid,
        photoUrl: _accountPhotoUrl,
        phone: _accountPhone,
        birthDate: _accountBirthDate,
        handicap: _accountHandicap,
      ));
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

    final wantsOfficer = ClubMemberRole.isOfficer(roleEncoded);
    final alreadyOfficer = ClubMemberRole.isOfficer(_myClubs[myIdx].myRole);
    if (wantsOfficer &&
        !alreadyOfficer &&
        !_iAmClubCreator(_myClubs[myIdx])) {
      return false;
    }

    final creatorId = 'm_creator_$clubId';
    var me = membersForClub(clubId).where((m) {
      return _isMyRosterRowFor(_myClubs[myIdx], m.id);
    }).firstOrNull;
    if (_isDemoSession) {
      me ??= membersForClub(clubId).where((m) {
        return m.id == currentUserId || m.id == 'm_${clubId}_$currentUserId';
      }).firstOrNull;
    }

    if (me == null) {
      me = _selfMember(
        id: creatorId,
        name: currentUserName,
        memberType: ClubMemberRole.memberTypeForRole(roleEncoded),
        role: roleEncoded,
        joinDate: _myClubs[myIdx].createdAt,
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
    if (idx == -1) return;
    if (_members[idx].status == '탈퇴') return;
    _members[idx] = _members[idx].copyWith(status: '탈퇴');
    // 강퇴와 같은 정책. 이게 없으면 원격 '활성' 행이 탈퇴를 되살린다.
    ClubOpsSync.markMemberRemoved(memberId);
    notifyListeners();
    // 예전엔 통지만 하고 저장을 안 해서, 앱을 다시 켜면 탈퇴가 사라졌다.
    _persistImmediately();
  }

  /// 총무 권한 — 회원 강퇴 처리 + 대상 회원에게 즉시 앱 푸시 알림 발송
  void kickMember(String memberId, {String? clubId}) {
    final idx = _members.indexWhere((m) => m.id == memberId);
    if (idx == -1) return;
    final member = _members[idx];
    if (member.status == '강퇴') return;
    _members[idx] = member.copyWith(status: '강퇴');
    // 원격 watch/pull 이 옛 '활성' 행으로 되살리지 못하게 표시한다.
    ClubOpsSync.markMemberRemoved(memberId);

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

  final List<RoundPhoto> _photos = [];

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
  final Map<String, GroupAssignment> _groupAssignments = {};

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
    ).copyWith(
      isFinalized: current.isFinalized,
      finalizedAt: current.finalizedAt,
      mode: current.mode,
      selectedOptions: current.selectedOptions,
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

  /// 조편성 확정. 알림톡은 총무가 보내기를 고른 뒤에만 [sendGroupFinalizeAlimtalk].
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

  /// 조편성 확정 알림톡 — 확정 직후 보내기를 고른 경우에만 호출한다.
  void sendGroupFinalizeAlimtalk(String scheduleId) {
    final schedule = scheduleById(scheduleId);
    if (schedule == null) return;
    _dispatchClubAlimtalk(
      hqTypeId: HqAlimtalkCatalog.groupFinalizeId,
      members: groupAlimtalkRecipientMembers(scheduleId),
      variablesFor: (m) => _alimtalkScheduleVars(schedule, m),
    );
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

  static List<AdApplication> _createDefaultAdApplications() => <AdApplication>[];

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

  List<SponsorApplication> _sponsorApplications =
      _createDefaultSponsorApplications();

  static List<SponsorApplication> _createDefaultSponsorApplications() => <SponsorApplication>[];

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
  //  · 라운딩 참석 +10, 회비 정시납부 +5, 공지당 첫 댓글 +2 / 마지막 댓글 삭제 -2
  //  · 후원사 인사 +2, 노쇼 -10
  // ════════════════════════════════════════════════════════

  // 포인트 이벤트 기록 (memberId → 이벤트 목록)
  final Map<String, List<MembershipPointEvent>> _pointEvents = {};

  /// 같은 사람의 포인트 키 (auth id / m_creator 혼용 보정).
  ///
  /// 로그인 사용자의 키를 다른 회원에게 합치면, `m_{club}_m1` 같은
  /// 옛 명단 행이 총무와 같은 점수를 받는다.
  Set<String> _membershipPointKeysFor(String memberId) {
    // leftover m_{club}_m1 은 이정원 행. 생성자 m1 키를 합치면 안 된다.
    if (_isLegacyM1RosterId(memberId) && memberId != 'm1') {
      return <String>{memberId};
    }

    final keys = <String>{memberId};
    if (_myClubs.isEmpty) return keys;
    final clubId = selectedClub.id;
    final creatorId = 'm_creator_$clubId';

    if (_isSelfTarget(memberId)) {
      if (_persistAuthUserId != null) {
        // 로그인 id 로 합산하면 다른 모임의 정시납부 +5 가
        // 일정·회비 없는 모임 랭킹에도 붙는다.
        keys.add(Member.rosterId(clubId, _persistAuthUserId!));
      }
      if (_isDemoSession) {
        keys.add(currentUserId);
      }
      if (_iAmClubCreator(selectedClub)) {
        keys.add(creatorId);
        keys.add('m1');
        if (_persistAuthUserId != null) {
          keys.add(_persistAuthUserId!);
        }
      }
    } else if (memberId == creatorId) {
      final cid = selectedClub.creatorId.trim();
      if (cid.isNotEmpty) {
        keys.add(cid);
        keys.add(Member.rosterId(clubId, cid));
      }
      if (!_isDemoSession) {
        keys.add('m1');
      }
    }
    return keys;
  }

  Set<String> _memberAliasIds(String memberId) {
    return {
      memberId,
      canonicalMemberId(memberId),
      ..._membershipPointKeysFor(memberId),
    };
  }

  /// 특정 회원의 멤버십 포인트 합산. year 없으면 올해.
  int getMembershipPoints(String memberId, {int? year}) {
    final y = year ?? DateTime.now().year;
    var sum = 0;
    for (final key in _membershipPointKeysFor(memberId)) {
      final events = _pointEvents[key] ?? const <MembershipPointEvent>[];
      for (final e in events) {
        if (e.date.year == y) sum += e.points;
      }
    }
    return sum;
  }

  /// 선택 모임 활성 회원 포인트 랭킹 (올해, 내림차순)
  List<MapEntry<String, int>> get memberPointsRanking =>
      memberPointsRankingForYear(DateTime.now().year);

  List<MapEntry<String, int>> memberPointsRankingForYear(int year) {
    final result = <MapEntry<String, int>>[];
    for (final m in activeMembers) {
      result.add(MapEntry(m.id, getMembershipPoints(m.id, year: year)));
    }
    result.sort((a, b) => b.value.compareTo(a.value));
    return result;
  }

  Member? memberById(String memberId) {
    return activeMembers.where((m) => m.id == memberId).firstOrNull ??
        _members.where((m) => m.id == memberId).firstOrNull;
  }

  /// 내 카카오 명단 행만 생성자 행으로 맞춘다.
  /// `m_{club}_m1` 은 다른 회원(이정원)일 수 있으므로 생성자로 바꾸지 않는다.
  String canonicalMemberId(String rawId, {String? clubId}) {
    if (rawId.isEmpty) return rawId;
    final club = clubId ?? (_myClubs.isEmpty ? '' : selectedClub.id);
    if (club.isEmpty) return rawId;
    final creatorId = 'm_creator_$club';
    if (rawId == creatorId) return rawId;
    if (_persistAuthUserId == null || _isDemoSession) return rawId;
    final c = _clubById(club) ?? selectedClub;
    if (!_iAmClubCreator(c)) return rawId;
    final mine = Member.rosterId(club, _persistAuthUserId!);
    if (rawId == _persistAuthUserId || rawId == mine) return creatorId;
    return rawId;
  }

  Club? _clubById(String clubId) =>
      _myClubs.where((c) => c.id == clubId).firstOrNull ??
      _allClubs.where((c) => c.id == clubId).firstOrNull;

  /// 회비 정시납부 +5. 마감일(월회비=매월 기준일, 연/특별회비=납부 기준일)
  /// 안에 들어온 납부만 적립한다. 마감일 설정이 없으면 판정 불가라 적립도 없다.
  ///
  /// 같은 회비·같은 기간에 두 번 적립되지 않게 desc 태그로 막는다.
  void _awardDuesOnTimePoint({
    required String memberId,
    required String duesSettingId,
    required DateTime paidAt,
    int? year,
    int? month,
  }) {
    final setting =
        _duesSettings.where((d) => d.id == duesSettingId).firstOrNull;
    if (setting == null) return;

    final onTime = setting.isPaidOnTime(paidAt, year: year, month: month);
    if (onTime != true) return; // 연체 또는 마감일 미설정 → 0점

    final tag = duesPointTag(
      duesSettingId: duesSettingId,
      year: year,
      month: month,
    );
    // 같은 회비·기간에 이미 살아 있는 적립이 있으면 건너뛴다.
    if (_duesPointNet(memberId, tag) > 0) return;

    final periodPart = month != null ? '${month}월 ' : '';
    addMembershipPoint(
      memberId: memberId,
      type: MembershipPointType.duesOnTime,
      points: 5,
      desc: '$periodPart${setting.type.label} 정시납부$tag',
    );
  }

  /// 회비 포인트 중복·취소 판별용 태그. 납부 취소 시에도 같은 규칙으로 찾는다.
  static String duesPointTag({
    required String duesSettingId,
    int? year,
    int? month,
  }) =>
      '|dues:$duesSettingId:${year ?? '-'}-${month ?? '-'}';

  /// 같은 회비·기간 태그의 순 포인트. 적립(+5)과 회수(-5)를 합산한다.
  ///
  /// 별칭 키(auth id / m_creator / 회원 id)를 모두 본다 —
  /// `addMembershipPoint` 가 키를 정규화하기 때문이다.
  int _duesPointNet(String memberId, String tag) {
    var net = 0;
    for (final key in _membershipPointKeysFor(memberId)) {
      for (final e in _pointEvents[key] ?? const <MembershipPointEvent>[]) {
        if (e.desc.contains(tag)) net += e.points;
      }
    }
    return net;
  }

  /// 납부를 취소하면 정시납부 포인트도 회수한다.
  /// (이게 없으면 납부 → 취소를 반복해 포인트를 무한히 쌓을 수 있다)
  ///
  /// 이벤트를 지우지 않고 -5 를 덧붙인다. 포인트는 append-only 원장이라
  /// 삭제하면 다른 기기의 원격 이력이 그대로 되살려 버린다.
  void _revokeDuesOnTimePoint({
    required String memberId,
    required String duesSettingId,
    int? year,
    int? month,
  }) {
    final tag = duesPointTag(
      duesSettingId: duesSettingId,
      year: year,
      month: month,
    );
    final net = _duesPointNet(memberId, tag);
    if (net <= 0) return; // 적립된 게 없으면 회수할 것도 없다

    final periodPart = month != null ? '${month}월 ' : '';
    addMembershipPoint(
      memberId: memberId,
      type: MembershipPointType.penalty,
      points: -net,
      desc: '$periodPart회비 납부 취소$tag',
    );
  }

  /// 이 일정의 참석 포인트 순액. +10 / -10 을 합산한다.
  ///
  /// 예전에 "한 번이라도 +10 이력이 있으면 다시 주지 않음"이라
  /// 참석→불참(-10)→다시 참석 때 +10이 막혔다. 순액이 0이면 다시 적립한다.
  int _attendancePointNet(String memberId, String scheduleId) {
    final tag = '|$scheduleId';
    var net = 0;
    for (final key in _memberAliasIds(memberId)) {
      for (final e in _pointEvents[key] ?? const <MembershipPointEvent>[]) {
        if (e.desc.contains(tag)) net += e.points;
      }
    }
    return net;
  }

  bool _hasAttendanceCredit(String memberId, String scheduleId) =>
      _attendancePointNet(memberId, scheduleId) > 0;

  /// 참석 응답은 있는데 포인트 이력이 없는 회원(이정원 leftover 등)을 채운다.
  void _backfillMissingAttendancePoints() {
    var added = false;
    for (final s in _schedules) {
      for (final r in s.responses) {
        if (r.response != '참석') continue;
        if (_hasAttendanceCredit(r.memberId, s.id)) continue;
        _appendPointEvent(
          memberId: r.memberId,
          type: MembershipPointType.roundAttendance,
          points: 10,
          desc: '${s.displayTitle} 참석|${s.id}',
          date: s.roundDate,
        );
        added = true;
      }
    }
    if (added && !_suppressPersist) _persistImmediately();
  }

  void _syncAttendancePoints({
    required String memberId,
    required String scheduleId,
    required String scheduleTitle,
    required String? prev,
    required String response,
  }) {
    final date = scheduleById(scheduleId)?.roundDate ?? DateTime.now();
    if (response == '참석' && prev != '참석') {
      if (_attendancePointNet(memberId, scheduleId) <= 0) {
        addMembershipPoint(
          memberId: memberId,
          type: MembershipPointType.roundAttendance,
          points: 10,
          desc: '$scheduleTitle 참석|$scheduleId',
          date: date,
        );
      }
    } else if (prev == '참석' && response == '불참') {
      if (_attendancePointNet(memberId, scheduleId) > 0) {
        addMembershipPoint(
          memberId: memberId,
          type: MembershipPointType.noShow,
          points: -10,
          desc: '$scheduleTitle 불참 변경|$scheduleId',
          date: date,
        );
      }
    }
  }

  void _appendPointEvent({
    required String memberId,
    required MembershipPointType type,
    required int points,
    required String desc,
    required DateTime date,
  }) {
    _pointEvents.putIfAbsent(memberId, () => []);
    _pointEvents[memberId]!.add(MembershipPointEvent(
      type: type,
      points: points,
      desc: desc,
      date: date,
    ));
  }

  /// 포인트 적립 (클럽 회원 id 기준으로 저장 + 즉시 영속화)
  void addMembershipPoint({
    required String memberId,
    required MembershipPointType type,
    required int points,
    required String desc,
    DateTime? date,
  }) {
    var canonical = memberId;
    if (memberId == currentUserId ||
        memberId == _persistAuthUserId ||
        _isSelfTarget(memberId)) {
      final me = currentMember?.id ?? memberId;
      canonical = _isLegacyM1RosterId(me)
          ? 'm_creator_${selectedClub.id}'
          : canonicalMemberId(me);
    }
    _appendPointEvent(
      memberId: canonical,
      type: type,
      points: points,
      desc: desc,
      date: date ?? DateTime.now(),
    );
    notifyListeners();
    _persistImmediately();
  }

  // ════════════════════════════════════════════════════════
  //  시상 결과 저장
  //  · scheduleId별 수상 기록 관리
  //  · 회원별 올해 시상 횟수 계산
  // ════════════════════════════════════════════════════════

  final List<AwardRecord> _awardRecords = [];

  final List<RoundScoreRecord> _roundScores = [];

  List<AwardRecord> get allAwardRecords => List.unmodifiable(_awardRecords);

  List<AwardRecord> awardRecordsFor(String scheduleId) => _awardRecords
      .where((r) => r.scheduleId == scheduleId)
      .toList(growable: false);

  RoundScoreRecord? roundScoreFor(String scheduleId) =>
      _roundScores.where((r) => r.scheduleId == scheduleId).firstOrNull;

  DateTime awardEventDate(AwardRecord r) {
    final s = scheduleById(r.scheduleId);
    return s?.roundDate ?? r.recordedAt;
  }

  List<AwardRecord> awardsInYear(int year) => _awardRecords
      .where((r) =>
          awardEventDate(r).year == year && _awardBelongsToSelectedClub(r))
      .toList(growable: false);

  /// 시상 원장은 기기 전역이다. 선택 모임이 아니면 횟수에 넣지 않는다.
  /// (이름만 같으면 다른 모임 시상까지 강남 미용모임 5회로 보이던 원인)
  bool _awardBelongsToSelectedClub(AwardRecord r) {
    if (_myClubs.isEmpty) return true;
    final clubId = selectedClub.id;
    final s = scheduleById(r.scheduleId);
    if (s != null) return s.clubId == clubId;
    final creator = 'm_creator_$clubId';
    final prefix = 'm_${clubId}_';
    return r.winnerIds.any((id) => id == creator || id.startsWith(prefix));
  }

  /// 정회원(게스트 제외) 연간 시상 횟수, 많은 순.
  List<MapEntry<String, int>> regularAwardRankingForYear(int year) {
    final allowed = {for (final m in regularMembers) m.id};
    final counts = <String, int>{};
    for (final r in awardsInYear(year)) {
      for (final id in _uniqueCanonicalWinners(r)) {
        if (!allowed.contains(id)) continue;
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    final result = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        final na = memberById(a.key)?.name ?? a.key;
        final nb = memberById(b.key)?.name ?? b.key;
        return na.compareTo(nb);
      });
    return result;
  }

  /// 한 시상 기록의 수상자를 현재 명단 ID로 모은다.
  /// 같은 사람이 m1 / m_creator 로 두 번 들어 있으면 한 명으로 센다.
  Set<String> _uniqueCanonicalWinners(AwardRecord r) {
    final club = scheduleById(r.scheduleId)?.clubId;
    final seen = <String>{};
    if (r.winnerIds.isEmpty) {
      for (final name in r.winnerNames) {
        final id = _canonicalAwardWinnerId(
          rawId: '',
          rawName: name,
          clubId: club,
        );
        if (id != null) seen.add(id);
      }
      return seen;
    }
    for (var i = 0; i < r.winnerIds.length; i++) {
      final id = _canonicalAwardWinnerId(
        rawId: r.winnerIds[i],
        rawName: i < r.winnerNames.length ? r.winnerNames[i] : null,
        clubId: club,
      );
      if (id != null) seen.add(id);
    }
    return seen;
  }

  String? _canonicalAwardWinnerId({
    required String rawId,
    String? rawName,
    String? clubId,
  }) {
    final club = (clubId == null || clubId.isEmpty)
        ? (_myClubs.isEmpty ? null : selectedClub.id)
        : clubId;
    if (rawId.isNotEmpty) {
      if (regularMembers.any((m) => m.id == rawId)) return rawId;
      if (!_isDemoSession && rawId == 'm1' && club != null) {
        final creatorId = 'm_creator_$club';
        if (regularMembers.any((m) => m.id == creatorId)) return creatorId;
      }
      // 다른 모임 명단 id 는 이름만 같다고 이 모임 사람에게 붙이지 않는다.
      if (Member.isStoredRosterId(rawId) &&
          (club == null || !Member.isClubRosterId(club, rawId))) {
        return null;
      }
    }
    final name = (rawName ?? '').trim();
    if (name.isEmpty || seedMemberNames.contains(name)) return null;
    final hits =
        regularMembers.where((m) => m.name.trim() == name).toList();
    if (hits.length == 1) return hits.single.id;
    return null;
  }

  /// 시상 목록용 정회원 수상자 이름. 게스트는 빠져 있다.
  List<String> regularAwardWinnerNames(AwardRecord r) {
    final ids = _uniqueCanonicalWinners(r);
    if (ids.isEmpty) return const [];
    return [
      for (final id in ids) memberById(id)?.name ?? id,
    ];
  }

  Map<int, List<AwardRecord>> awardsByMonthForYear(int year) {
    final map = <int, List<AwardRecord>>{};
    for (final r in awardsInYear(year)) {
      map.putIfAbsent(awardEventDate(r).month, () => []).add(r);
    }
    for (final list in map.values) {
      list.sort((a, b) => awardEventDate(a).compareTo(awardEventDate(b)));
    }
    return map;
  }

  List<int> rankingYearsAvailable() {
    final now = DateTime.now().year;
    final years = <int>{now, now - 1, now - 2};
    for (final list in _pointEvents.values) {
      for (final e in list) {
        years.add(e.date.year);
      }
    }
    for (final s in _schedules) {
      years.add(s.roundDate.year);
    }
    for (final r in _awardRecords) {
      years.add(awardEventDate(r).year);
    }
    final filtered = years.where((y) => y >= 2020 && y <= now + 1).toList()
      ..sort((a, b) => b.compareTo(a));
    return filtered;
  }

  List<int> awardYearsAvailable() => rankingYearsAvailable();

  /// 특정 회원의 올해 시상 횟수
  int getMemberAwardCount(String memberId, {int? year}) {
    final y = year ?? DateTime.now().year;
    final canonical =
        _canonicalAwardWinnerId(rawId: memberId, rawName: null) ?? memberId;
    var n = 0;
    for (final r in awardsInYear(y)) {
      final winners = _uniqueCanonicalWinners(r);
      if (winners.contains(canonical) || winners.contains(memberId)) n++;
    }
    return n;
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
    _persistImmediately();
  }

  /// 한 일정의 시상을 통째로 저장 (수상자 없는 항목은 삭제)
  void saveAwardsForSchedule(String scheduleId, List<AwardRecord> records) {
    _awardRecords.removeWhere((r) => r.scheduleId == scheduleId);
    _awardRecords.addAll(records);
    notifyListeners();
    _persistImmediately();
  }

  /// [merge] true 면 조별 입력처럼 기존 타수에 덮어쓴다.
  void saveRoundScores(RoundScoreRecord record, {bool merge = false}) {
    if (merge) {
      final existing = roundScoreFor(record.scheduleId);
      if (existing != null) {
        record = RoundScoreRecord(
          scheduleId: record.scheduleId,
          scores: {...existing.scores, ...record.scores},
          handicaps: {...existing.handicaps, ...record.handicaps},
          recordedAt: record.recordedAt,
        );
      }
    }
    _roundScores.removeWhere((r) => r.scheduleId == record.scheduleId);
    _roundScores.add(record);
    notifyListeners();
    _persistImmediately();
  }

  // ════════════════════════════════════════════════════════
  //  후원사 감사인사 피드
  //  · ThankYouMessage: 보낸 사람, 후원사, 메시지, 시각
  // ════════════════════════════════════════════════════════

  final List<ThankYouMessage> _thankYouMessages = [];

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
    if (_applyRosterRolesToMyClubs()) {
      notifyListeners();
      _persistImmediately();
    }
  }

  bool _applyRosterRolesToMyClubs() {
    var changed = false;
    for (final club in List<Club>.from(_myClubs)) {
      if (_syncMyRoleFromRosterFor(club.id)) changed = true;
    }
    return changed;
  }

  bool _syncMyRoleFromRosterFor(String clubId) {
    final myIdx = _myClubs.indexWhere((c) => c.id == clubId);
    if (myIdx == -1) return false;
    final club = _myClubs[myIdx];

    final clubMembers = membersForClub(clubId);
    final creatorId = 'm_creator_$clubId';
    final creator =
        clubMembers.where((m) => m.id == creatorId).firstOrNull;
    Member? source;
    for (final m in clubMembers) {
      if (_isMyRosterRowFor(club, m.id)) {
        source = m;
        break;
      }
    }
    final isCreator = _iAmClubCreator(club) ||
        (source != null && source.id == creatorId) ||
        (creator != null && _iAmClubCreator(club));

    // 모임 스코프 명단을 소스로 사용 (전역 시드 m1 제외)
    if (creator != null && isCreator) {
      if (source == null ||
          source.id != creator.id ||
          !ClubMemberRole.isOfficer(source.role)) {
        source = creator;
      }
    }
    if (source == null) return false;
    final sourceId = source.id;

    final clubRole = _myClubs[myIdx].myRole;
    var role = ClubMemberRole.encodeRoles(
      ClubMemberRole.splitRoles(source.role),
    );

    // 내가 만든 모임만 명단을 클럽 임원에 맞춘다.
    // 남의 모임 Club.myRole 이 회장으로 남아 있으면 목록 배지만 틀린 게 아니라
    // 정회원 명단까지 회장으로 덮인다.
    if (ClubMemberRole.isOfficer(clubRole) &&
        !ClubMemberRole.isOfficer(role)) {
      if (!isCreator) {
        _myClubs[myIdx] = _myClubs[myIdx].copyWith(myRole: role);
        final allIdx = _allClubs.indexWhere((c) => c.id == clubId);
        if (allIdx != -1) {
          _allClubs[allIdx] = _allClubs[allIdx].copyWith(myRole: role);
        }
        return true;
      }
      final mIdx = _members.indexWhere((m) => m.id == sourceId);
      if (mIdx != -1 && _members[mIdx].role != clubRole) {
        _members[mIdx] = _members[mIdx].copyWith(role: clubRole);
        return true;
      }
      return false;
    }

    // 생성자인데 양쪽 다 임원이 아니면 회장·총무로 되돌린다.
    if (isCreator && !ClubMemberRole.isOfficer(role)) {
      role = ClubMemberRole.encodeRoles(const [
        ClubMemberRole.president,
        ClubMemberRole.treasurer,
      ]);
      final mIdx = _members.indexWhere((m) => m.id == sourceId);
      if (mIdx != -1) {
        _members[mIdx] = _members[mIdx].copyWith(role: role);
      }
    }

    if (_myClubs[myIdx].myRole == role) return false;
    _myClubs[myIdx] = _myClubs[myIdx].copyWith(myRole: role);
    final allIdx = _allClubs.indexWhere((c) => c.id == clubId);
    if (allIdx != -1) {
      _allClubs[allIdx] = _allClubs[allIdx].copyWith(myRole: role);
    }
    return true;
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
    _persistImmediately();
  }

  /// 대기 취소
  void cancelWaiting(String waitingId) {
    _waitingList.removeWhere((w) => w.id == waitingId);
    notifyListeners();
    _persistImmediately();
  }

  /// 대기 1번 연락: 앱 알림 + FCM. 알림톡은 나가지 않는다.
  /// 자동 참석 확정은 하지 않는다. 대기자가 참석으로 응답해야 들어온다.
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
    final schedule = scheduleById(scheduleId);
    final inboxId = _fcmInboxIdFor(firstWaiter.memberId);
    addAppNotification(AppNotification(
      id: 'noti_wl_${DateTime.now().millisecondsSinceEpoch}',
      type: AppNotificationType.announcement,
      clubId: schedule?.clubId ?? selectedClub.id,
      clubName: selectedClub.name,
      title: '대기 순번 — 참석 가능',
      body:
          '${schedule?.displayTitle ?? '라운딩'}에 자리가 생겼습니다. 12시간 안에 참석으로 응답하면 확정됩니다.',
      createdAt: DateTime.now(),
      targetId: scheduleId,
      targetUserId: inboxId.isNotEmpty ? inboxId : firstWaiter.memberId,
      isRead: false,
    ));
    notifyListeners();
    _persistImmediately();
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
  /// 신규 모임에는 붙이지 않는다 — 다른 모임의 고아 회비가 재무 온보딩을 건너뛰게 한다.
  void _stampOrphanDuesClubIds() {
    if (_myClubs.isEmpty) return;
    if (!_selectedHasLegacyMock) return;
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
    if (!_selectedHasLegacyMock) return;
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

}

class LeaveClubResult {
  final bool success;
  final bool treasurerVacated;
  const LeaveClubResult({
    required this.success,
    required this.treasurerVacated,
  });
}
