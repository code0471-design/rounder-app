import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/data/repositories/club_repository.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/domain/services/app_data_bootstrap_service.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:golf_rounder/services/club_ops_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 방장 칸에 다른 실명이 있으면 그 모임 사람이다.
/// 이정원 폰이 생성자로 보여도 회장 이름을 덮어 회원수가 깜빡이던 경로.
/// 볼케이노만이 아니라 아무 모임이나 같다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ClubProvider> openClub({
    required String clubId,
    required String clubName,
    bool includeJang = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    ClubOpsSync.resetMemberTombstones();
    AppDependencies.instance.init(offlineMock: true);
    final clubs = ClubProvider();
    await clubs.switchUser(
      'kakao_jung',
      displayName: '이정원',
      phone: '010-2222-3333',
    );

    final club = Club(
      id: clubId,
      name: clubName,
      myRole: '부회장',
      memberCount: 4,
      creatorId: 'kakao_jung',
      region: '서울',
      industry: '미용',
      teamCount: 4,
      description: '',
      createdAt: DateTime(2026, 8, 22),
    );
    clubs.hydrateFromBootstrap(AppBootstrapSnapshot(
      userId: 'kakao_jung',
      myClubs: [club],
      discoverableClubs: [club],
      membersByClubId: const {},
      financeByClubId: const {},
      loadedAt: DateTime(2026, 10, 6),
    ));
    clubs.selectClubById(clubId);

    if (includeJang) {
      clubs.addMember(Member(
        id: 'm_creator_$clubId',
        name: '장창현',
        gender: '남',
        memberType: '정회원',
        role: '회장',
      ));
    }
    clubs.addMember(Member(
      id: Member.rosterId(clubId, 'kakao_jung'),
      name: '이정원',
      gender: '남',
      memberType: '정회원',
      role: '부회장',
    ));
    clubs.addMember(Member(
      id: Member.rosterId(clubId, 'yang'),
      name: '양우석',
      gender: '남',
      memberType: '정회원',
      role: '정회원',
    ));
    clubs.addMember(Member(
      id: Member.rosterId(clubId, 'kakao_ahn'),
      name: '안경헌',
      gender: '남',
      memberType: '게스트',
      role: '게스트',
    ));
    return clubs;
  }

  Future<void> expectPresidentKept(ClubProvider clubs, String clubId) async {
    expect(clubs.activeHeadcount(clubId), 4);
    clubs.repairMyDisplayName('이정원');
    clubs.importBundleForTest(clubs.exportBundleForTest());

    final names = clubs.membersForClub(clubId).map((m) => m.name).toSet();
    expect(names, contains('장창현'),
        reason: '이정원이 생성자로 보여도 그 모임 회장 실명은 덮으면 안 된다');
    expect(names, contains('이정원'));
    expect(clubs.activeHeadcount(clubId), 4);
    expect(
      clubs.membersForClub(clubId).any((m) => m.name == '장창현' && m.role == '회장'),
      isTrue,
    );
  }

  test('볼케이노 회장 장창현은 이정원 이름 복구에 안 덮인다', () async {
    const clubId = 'c_1787397091896';
    final clubs = await openClub(clubId: clubId, clubName: '볼케이노~~');
    await expectPresidentKept(clubs, clubId);
  });

  test('강남처럼 다른 모임에서도 회장 실명은 안 덮인다', () async {
    const clubId = 'c_1788832826557';
    final clubs = await openClub(clubId: clubId, clubName: '강남 미용모임');
    await expectPresidentKept(clubs, clubId);
  });

  test('새로 만든 모임 id 에서도 회장 실명은 안 덮인다', () async {
    const clubId = 'c_1888888888888';
    final clubs = await openClub(clubId: clubId, clubName: '새 모임');
    await expectPresidentKept(clubs, clubId);
  });

  test('로컬 명단에 없어도 가입 계정이면 볼케이노에 그대로 나온다', () async {
    const clubId = 'c_1787397091896';
    final clubs = await openClub(
      clubId: clubId,
      clubName: '볼케이노~~',
      includeJang: false,
    );
    expect(
      clubs.membersForClub(clubId).any((m) => m.name == '장창현'),
      isFalse,
    );
    clubs.restoreMembersFromAccountsForTest(clubId, const [
      ClubMemberAccount(
        userId: 'kakao_jang',
        role: '회장',
        name: '장창현',
      ),
      ClubMemberAccount(
        userId: 'kakao_jung',
        role: '부회장',
        name: '이정원',
      ),
      ClubMemberAccount(
        userId: 'yang',
        role: '정회원',
        name: '양우석',
      ),
      ClubMemberAccount(
        userId: 'kakao_ahn',
        role: '게스트',
        name: '안경헌',
      ),
    ]);
    expect(
      clubs.membersForClub(clubId).map((m) => m.name).toSet(),
      {'장창현', '이정원', '양우석', '안경헌'},
    );
    expect(clubs.activeHeadcount(clubId), 4);
  });
}
