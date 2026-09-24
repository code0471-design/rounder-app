import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/domain/services/app_data_bootstrap_service.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:golf_rounder/services/club_data_codec.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 테스터 폰에서 남의 모임이 전부 '내 모임'으로 보이던 버그.
/// 내 모임 = 서버 멤버십만. 회원수 = 서버 가입만. 폰 찌꺼기는 기준이 아니다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClubProvider clubs;
  late String myClubId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppDependencies.instance.init(offlineMock: true);
    clubs = ClubProvider();
    await clubs.switchUser(
      'kakao_tester',
      displayName: '장창현',
      phone: '010-1111-2222',
    );
    final ok = await clubs.createClub(
      name: '알라딘 정기월례회',
      region: '서울',
      industry: '골프',
      teamCount: 4,
      myRole: '회장',
    );
    expect(ok, isTrue);
    myClubId = clubs.selectedClub.id;
  });

  test('남의 모임이 내 모임 목록에 끼어 있으면 새로고침에서 빠진다', () async {
    final store = AppDependencies.instance.mockDataStore!;
    final foreign = Club(
      id: 'c_1786973797931',
      name: '아레나 골프회',
      myRole: '정회원',
      memberCount: 2,
      creatorId: 'kakao_ahn',
      region: '서울',
      industry: '골프',
      teamCount: 4,
      description: '',
      createdAt: DateTime(2026, 9, 1),
    );
    store.upsertClub(foreign, persist: false);

    // 예전 빌드가 탐색 카탈로그를 내 모임으로 저장해 둔 상태를 재현
    clubs.hydrateFromBootstrap(AppBootstrapSnapshot(
      userId: 'kakao_tester',
      myClubs: [foreign],
      discoverableClubs: [foreign],
      membersByClubId: const {},
      financeByClubId: const {},
      loadedAt: DateTime(2026, 9, 19),
    ));
    expect(clubs.myClubs.any((c) => c.id == foreign.id), isTrue);

    await clubs.refreshOwnedClubs();

    expect(clubs.myClubs.any((c) => c.id == foreign.id), isFalse,
        reason: '서버 멤버십이 없으면 내 모임이 아니다');
    expect(clubs.myClubs.any((c) => c.id == myClubId), isTrue,
        reason: '내가 만든 모임은 그대로 남아야 한다');
    expect(clubs.allClubs.any((c) => c.id == foreign.id), isTrue,
        reason: '탐색 목록에서는 계속 보여야 한다');
  });

  test('초대로 들어온 모임은 명단 행이 있으면 안 지운다', () async {
    final store = AppDependencies.instance.mockDataStore!;
    final invited = Club(
      id: 'c_1788832826557',
      name: '강남 미용모임',
      myRole: '정회원',
      memberCount: 3,
      creatorId: 'kakao_ahn',
      region: '서울',
      industry: '미용',
      teamCount: 4,
      description: '',
      createdAt: DateTime(2026, 8, 1),
    );
    store.upsertClub(invited, persist: false);
    store.addMember(
      clubId: invited.id,
      member: Member(
        id: 'kakao_tester',
        name: '장창현',
        gender: '남',
        memberType: '정회원',
        role: '정회원',
        joinDate: DateTime(2026, 8, 2),
      ),
      persist: false,
    );

    clubs.hydrateFromBootstrap(AppBootstrapSnapshot(
      userId: 'kakao_tester',
      myClubs: [invited],
      discoverableClubs: [invited],
      membersByClubId: const {},
      financeByClubId: const {},
      loadedAt: DateTime(2026, 9, 19),
    ));

    await clubs.refreshOwnedClubs();

    expect(clubs.myClubs.any((c) => c.id == invited.id), isTrue,
        reason: '서버 멤버십이 있으면 남긴다');
  });

  test('폰에 없어도 서버에 가입된 모임은 내 모임에 넣는다', () async {
    final store = AppDependencies.instance.mockDataStore!;
    final invited = Club(
      id: 'c_1789270673471',
      name: '알라딘 정기월례회',
      myRole: '정회원',
      memberCount: 2,
      creatorId: 'kakao_jang',
      region: '서울',
      industry: '골프',
      teamCount: 4,
      description: '',
      createdAt: DateTime(2026, 9, 13),
    );
    store.upsertClub(invited, persist: false);
    store.addMember(
      clubId: invited.id,
      member: Member(
        id: 'kakao_tester',
        name: '테스터',
        gender: '남',
        memberType: '정회원',
        role: '정회원',
        joinDate: DateTime(2026, 9, 13),
      ),
      persist: false,
    );
    expect(clubs.myClubs.any((c) => c.id == invited.id), isFalse);

    await clubs.refreshOwnedClubs();

    expect(clubs.myClubs.any((c) => c.id == invited.id), isTrue,
        reason: '원클럽처럼 서버 소속이 있으면 내가 만든 모임이 아니어도 내 모임이다');
  });

  test('멤버십 조회가 실패하면 아무것도 지우지 않는다', () {
    final src = File('lib/providers/club_provider.dart').readAsStringSync();
    final start = src.indexOf('Future<bool> _pruneForeignClubs(');
    final end = src.indexOf('void _stripHardcodedDemoPayload(', start);
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    final body = src.substring(start, end);
    expect(body.contains('if (_isDemoSession || _myClubs.isEmpty) return false;'),
        isTrue);
    expect(body.contains('멤버십 조회 실패'), isTrue,
        reason: '멤버십을 못 읽으면 비행기모드에서 내 모임을 지우면 안 된다');
    expect(body.contains('if (catalog.isEmpty) return false;'), isFalse,
        reason: '탐색 목록이 비었다고 정리를 건너뛰면 폰에 남은 남의 모임이 남는다');
    expect(body.contains('if (_sessionCreatedClubIds.contains(c.id)) continue;'),
        isTrue,
        reason: '방금 만든 모임만 서버에 아직 없어도 남긴다. 지운 모임은 뺀다');
    expect(body.contains('_clubRosterHasMyPhone(c.id)'), isFalse,
        reason: '로컬 명단·번호만으로 남기면 잘못 붙은 모임이 다시 내 모임이 된다');
    expect(body.contains('if (mineIds.contains(c.id)) continue;'), isTrue);
    expect(body.contains('_iAmClubCreator(c)'), isFalse,
        reason: '로컬 방장 id 를 믿으면 장창현 폰에 남의 모임이 남는다');
    expect(body.contains('fetchClubById'), isFalse,
        reason: '카탈로그·문서 생성자로 남기면 가입 안 한 모임이 내 모임에 남는다');
    expect(body.contains('isUserMember'), isFalse,
        reason: '멤버십 목록이 기준이다. 다른 경로로 남기지 않는다');
    expect(body.contains('serverCreator'), isFalse,
        reason: '서버 생성자만 맞아도 가입이 없으면 내 모임이 아니다');
    expect(body.contains('if (catalogOk && catalog.isNotEmpty)'), isFalse,
        reason: '탐색 목록에 없다고 지우면 초대 가입 모임이 빠진다');
    expect(body.contains('notifyListeners()'), isTrue,
        reason: '빼고 나서 홈을 다시 그려야 예전 7개가 화면에 남지 않는다');
    expect(body.contains('_serverClubsAligned = true'), isTrue,
        reason: '멤버십을 읽은 뒤에는 그 목록을 확정해야 한다');
    expect(src.contains('await _alignMyClubsWithServer()'), isFalse,
        reason: '서버 소속을 기다리면 인트로 뒤 홈이 다시 늦어진다');
    expect(src.contains('List<Club> get myClubs => List.unmodifiable(_myClubs);'),
        isTrue,
        reason: '서버 정리를 기다리다 내 모임을 숨기면 홈이 빈다');
    expect(src.contains('_shouldHideUnalignedMyClubs'), isFalse,
        reason: '맞추기 전 숨김이 안경헌 홈을 비게 했다');
    expect(src.contains('afterSwitch align skip'), isTrue,
        reason: '소속 조회가 실패해도 마지막 서버 확정 목록은 유지한다');
    expect(
      src.contains('!_confirmedClubIds.contains(c.id)'),
      isTrue,
      reason: '동기화가 예전 목록을 다시 넣으면 7개가 돌아온다',
    );
    expect(src.contains('_replaceMyClubsFromServerMemberships'), isTrue,
        reason: '원클럽처럼 내 모임은 서버 소속 목록이다');
    expect(src.contains('MemberPhoneIndex.claimForUser('), isFalse,
        reason: '번호 색인으로 소속을 만들면 가입 안 한 모임이 내 모임이 된다');
    expect(src.contains('restore discoverable skip'), isFalse,
        reason: '카탈로그 생성자를 내 모임으로 복구하면 안 된다');
    expect(src.contains('if (!_isDemoSession) return;'), isTrue,
        reason: '실계정 회원수를 폰 명단 길이로 맞추면 안 된다');
    expect(src.contains('memberCount: c.memberCount,'), isTrue,
        reason: '내 모임 회원수는 서버 카탈로그 값이다');
    expect(src.contains('_applyMembershipOnlyMyClubs()'), isTrue,
        reason: '폰에 남은 클럽 목록은 실제 가입처럼 보여 주면 안 된다');
    final refreshStart = src.indexOf('Future<void> refreshOwnedClubs()');
    final refreshEnd = src.indexOf('bool get _isDemoSession', refreshStart);
    expect(refreshStart, greaterThan(0));
    expect(refreshEnd, greaterThan(refreshStart));
    final refreshBody = src.substring(refreshStart, refreshEnd);
    expect(
      refreshBody.indexOf('_replaceMyClubsFromServerMemberships'),
      lessThan(refreshBody.indexOf('_pruneForeignClubs')),
      reason: '새로고침이 서버 소속을 넣기 전에 지우면 알라딘이 안 뜬다',
    );
    final replaceStart =
        src.indexOf('Future<bool> _replaceMyClubsFromServerMemberships');
    final replaceEnd = src.indexOf('bool _purgeDemoIdentityClubs', replaceStart);
    expect(replaceStart, greaterThan(0));
    expect(replaceEnd, greaterThan(replaceStart));
    final replaceBody = src.substring(replaceStart, replaceEnd);
    expect(replaceBody.contains('if (remote.isEmpty)'), isTrue,
        reason: '멤버십이 비었다고 내 모임을 통째로 바꾸면 업데이트 후 홈이 빈다');
    expect(replaceBody.contains('empty memberships'), isTrue);
    expect(replaceBody.contains('_dropUnconfirmedMyClubs()'), isTrue,
        reason: '조회가 비면 확정 가입은 남기고 장창현 7개 같은 찌꺼기만 뺀다');
    expect(src.contains('멤버십 목록 비어 있음'), isTrue,
        reason: '멤버십이 비면 정리도 건너뛴다');
  });

  test('내 모임 서버 조회는 멤버십 문서만 보지 않는다', () {
    final ds = File(
      'lib/data/datasources/firestore/firestore_club_datasource.dart',
    ).readAsStringSync();
    expect(ds.contains("where('creator_id'"), isTrue);
    expect(ds.contains("where('host_user_id'"), isTrue);
    expect(ds.contains('collectionGroup'), isFalse,
        reason: '명단 찌꺼기로 소속을 만들면 가입 안 한 모임이 다시 내 모임이 된다');
    expect(ds.contains("if (membershipSnap.docs.isEmpty) return [];"), isFalse,
        reason: '멤버십 문서가 없다고 바로 빈 목록이면 예전 가입이 다 빠진다');
  });

  test('서버 조회가 비면 확정 안 된 찌꺼기만 빠지고 가입한 모임은 남는다', () async {
    final leftover = Club(
      id: 'c_1786973797931',
      name: '아레나 골프회',
      myRole: '정회원',
      memberCount: 2,
      creatorId: 'kakao_ahn',
      region: '서울',
      industry: '골프',
      teamCount: 4,
      description: '',
      createdAt: DateTime(2026, 9, 1),
    );
    clubs.hydrateFromBootstrap(AppBootstrapSnapshot(
      userId: 'kakao_tester',
      myClubs: [leftover],
      discoverableClubs: [leftover],
      membersByClubId: const {},
      financeByClubId: const {},
      loadedAt: DateTime(2026, 9, 24),
    ));
    expect(clubs.myClubs.any((c) => c.id == leftover.id), isTrue);
    expect(clubs.myClubs.any((c) => c.id == myClubId), isTrue);

    AppDependencies.instance.mockDataStore!.membersByClub.clear();
    await clubs.refreshOwnedClubs();

    expect(clubs.myClubs.any((c) => c.id == leftover.id), isFalse,
        reason: '가입하지 않은 아레나는 서버가 비어도 다시 내 모임이 되면 안 된다');
    expect(clubs.myClubs.any((c) => c.id == myClubId), isTrue,
        reason: '이미 확정된 가입 모임은 조회가 비어도 지우면 안 된다');
  });

  test('탐색 목록이 비어도 서버 소속이 아닌 모임은 내 모임에서 빠진다', () async {
    final store = AppDependencies.instance.mockDataStore!;
    final mine = clubs.myClubs.firstWhere((c) => c.id == myClubId);
    store.upsertClub(mine, moderationStatus: 'closed', persist: false);

    final gone = Club(
      id: 'c_1787397091896',
      name: '볼케이노',
      myRole: '총무',
      memberCount: 1,
      creatorId: 'kakao_tester',
      region: '서울',
      industry: '골프',
      teamCount: 7,
      description: '화산',
      createdAt: DateTime(2026, 8, 22),
    );
    clubs.hydrateFromBootstrap(AppBootstrapSnapshot(
      userId: 'kakao_tester',
      myClubs: [gone],
      discoverableClubs: const [],
      membersByClubId: const {},
      financeByClubId: const {},
      loadedAt: DateTime(2026, 9, 23),
    ));
    expect(clubs.myClubs.any((c) => c.id == gone.id), isTrue);

    await clubs.refreshOwnedClubs();

    expect(clubs.myClubs.any((c) => c.id == gone.id), isFalse,
        reason: '탐색 목록이 비어도 멤버십에 없으면 폰 내 모임에서 빠진다');
    expect(clubs.myClubs.any((c) => c.id == myClubId), isTrue,
        reason: '내가 만든 모임은 그대로 남아야 한다');
  });

  test('로컬 방장 id 가 내 계정이어도 서버 생성자가 다르면 내 모임에서 빠진다', () async {
    final store = AppDependencies.instance.mockDataStore!;
    final stolen = Club(
      id: 'c_1788832999001',
      name: '강남 미용모임',
      myRole: '정회원',
      memberCount: 2,
      creatorId: 'kakao_tester',
      region: '서울',
      industry: '미용',
      teamCount: 4,
      description: '',
      createdAt: DateTime(2026, 8, 1),
    );
    store.upsertClub(
      stolen.copyWith(creatorId: 'kakao_ahn'),
      persist: false,
    );

    clubs.hydrateFromBootstrap(AppBootstrapSnapshot(
      userId: 'kakao_tester',
      myClubs: [stolen],
      discoverableClubs: [stolen.copyWith(creatorId: 'kakao_ahn')],
      membersByClubId: const {},
      financeByClubId: const {},
      loadedAt: DateTime(2026, 9, 22),
    ));
    expect(clubs.myClubs.any((c) => c.id == stolen.id), isTrue);

    await clubs.refreshOwnedClubs();

    expect(clubs.myClubs.any((c) => c.id == stolen.id), isFalse,
        reason: '장창현 폰 로컬에 남은 강남은 내 모임이 아니다');
    expect(clubs.myClubs.any((c) => c.id == myClubId), isTrue,
        reason: '알라딘만 남아야 한다');
  });

  test('서버에서 지운 모임은 카탈로그에 없어도 내 모임에서 빠진다', () async {
    final gone = Club(
      id: 'c_1787397091896',
      name: '볼케이노',
      myRole: '회장',
      memberCount: 1,
      creatorId: 'kakao_tester',
      region: '서울',
      industry: '골프',
      teamCount: 7,
      description: '화산',
      createdAt: DateTime(2026, 8, 22),
    );
    clubs.hydrateFromBootstrap(AppBootstrapSnapshot(
      userId: 'kakao_tester',
      myClubs: [gone],
      discoverableClubs: const [],
      membersByClubId: const {},
      financeByClubId: const {},
      loadedAt: DateTime(2026, 9, 20),
    ));
    expect(clubs.myClubs.any((c) => c.id == gone.id), isTrue);

    await clubs.refreshOwnedClubs();

    expect(clubs.myClubs.any((c) => c.id == gone.id), isFalse,
        reason: '서버 문서가 없는 모임은 폰 내 모임에서 빠져야 한다');
    expect(clubs.myClubs.any((c) => c.id == myClubId), isTrue);
  });

  test('폰에 남은 모임 목록은 실제 가입처럼 다시 넣지 않는다', () {
    final leftover = Club(
      id: 'c_viewed_only',
      name: '모임찾기에서 본 모임',
      myRole: '정회원',
      memberCount: 9,
      creatorId: 'kakao_other',
      region: '서울',
      industry: '골프',
      teamCount: 4,
      description: '',
      createdAt: DateTime(2026, 9, 1),
    );
    final stale = clubs.exportBundleForTest();
    clubs.importBundleForTest(ClubDataBundle(
      selectedClubIndex: stale.selectedClubIndex,
      freshClubIds: stale.freshClubIds,
      myClubs: [...stale.myClubs, leftover],
      allClubs: [...stale.allClubs, leftover],
      joinRequests: stale.joinRequests,
      members: stale.members,
      activities: stale.activities,
      announcements: stale.announcements,
      appNotifications: stale.appNotifications,
      duesSettings: stale.duesSettings,
      duesPayments: stale.duesPayments,
      paymentRequests: stale.paymentRequests,
      transactions: stale.transactions,
      schedules: stale.schedules,
      photos: stale.photos,
      groupAssignments: stale.groupAssignments,
      adApplications: stale.adApplications,
      adNotifications: stale.adNotifications,
      sponsorApplications: stale.sponsorApplications,
      pointEvents: stale.pointEvents,
      awardRecords: stale.awardRecords,
      roundScores: stale.roundScores,
      thankYouMessages: stale.thankYouMessages,
      waitingList: stale.waitingList,
      alimtalkSettings: stale.alimtalkSettings,
    ));

    expect(clubs.myClubs.any((c) => c.id == leftover.id), isFalse,
        reason: '모임찾기에서 보기만 한 모임은 내 모임이 아니다');
    expect(clubs.myClubs.any((c) => c.id == myClubId), isTrue,
        reason: '서버에 가입된 모임만 남는다');
  });

  test('내 모임 카드 직책은 Club.myRole이 아니라 그 모임 명단을 본다', () {
    final screen =
        File('lib/screens/my_clubs/my_clubs_screen.dart').readAsStringSync();
    final card =
        File('lib/screens/my_clubs/widgets/home_club_card.dart').readAsStringSync();
    final providerSrc =
        File('lib/providers/club_provider.dart').readAsStringSync();
    expect(screen.contains('myDisplayRoleFor'), isTrue);
    expect(card.contains('roleLabel'), isTrue);
    expect(providerSrc.contains('String myDisplayRoleFor(Club club)'), isTrue);
  });
}
