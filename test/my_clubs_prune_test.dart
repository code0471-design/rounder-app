import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/domain/services/app_data_bootstrap_service.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 테스터 폰에서 남의 모임이 전부 '내 모임'으로 보이던 버그.
/// 내 모임은 서버 멤버십·생성자·내 명단 행으로만 정해진다.
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
        reason: '서버 멤버십도 생성자도 내 명단 행도 없으면 내 모임이 아니다');
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
        reason: '방금 만든 모임만 카탈로그 없어도 남긴다. 지운 모임은 뺀다');
    expect(body.contains('_clubRosterHasMyPhone(c.id)'), isFalse,
        reason: '로컬 명단·번호만으로 남기면 잘못 붙은 모임이 다시 내 모임이 된다');
    expect(body.contains('if (mineIds.contains(c.id)) continue;'), isTrue);
    expect(body.contains('_iAmClubCreator(c)'), isFalse,
        reason: '로컬 방장 id 를 믿으면 장창현 폰에 남의 모임이 남는다');
    expect(body.contains('fetchClubById'), isTrue,
        reason: '탐색 목록이 비면 모임 문서를 하나씩 보고 소속 아닌 것을 뺀다');
    expect(body.contains('notifyListeners()'), isTrue,
        reason: '빼고 나서 홈을 다시 그려야 예전 7개가 화면에 남지 않는다');
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
