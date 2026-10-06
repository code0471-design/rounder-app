import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/domain/services/app_data_bootstrap_service.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:golf_rounder/services/club_ops_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 볼케이노 회장 장창현은 그 모임 사람이다.
/// 이정원 폰이 방장 칸을 내 행으로 보고 이름을 덮어 회원수가 3↔4로 깜빡이던 경로.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const clubId = 'c_1787397091896';

  test('이정원 이름 복구가 볼케이노 회장 장창현을 지우지 않는다', () async {
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
      name: '볼케이노~~',
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

    clubs.addMember(Member(
      id: 'm_creator_$clubId',
      name: '장창현',
      gender: '남',
      memberType: '정회원',
      role: '회장',
    ));
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

    expect(clubs.activeHeadcount(clubId), 4);
    clubs.repairMyDisplayName('이정원');
    clubs.importBundleForTest(clubs.exportBundleForTest());

    final names = clubs.membersForClub(clubId).map((m) => m.name).toSet();
    expect(names, contains('장창현'),
        reason: '이정원이 생성자로 보여도 볼케이노 회장 장창현은 그 모임 사람이다');
    expect(names, contains('이정원'));
    expect(clubs.activeHeadcount(clubId), 4);
    expect(
      clubs.membersForClub(clubId).any((m) => m.name == '장창현' && m.role == '회장'),
      isTrue,
    );
  });
}
