import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/domain/services/app_data_bootstrap_service.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 남이 만든 모임에 초대로 들어갔을 때, 서버 명단이 내 폰에 그대로 들어와야 한다.
/// (내 폰에만 "나 혼자" 보이던 버그)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const clubId = 'c_1789270673471';
  const hostUid = 'kakao_host';
  const myUid = 'kakao_me';

  late ClubProvider clubs;

  Member remoteRow({
    required String id,
    required String name,
    required String role,
    String? phone,
  }) =>
      Member(
        id: id,
        name: name,
        gender: '남',
        memberType: '정회원',
        role: role,
        phone: phone,
        joinDate: DateTime(2026, 9, 1),
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppDependencies.instance.init(offlineMock: true);
    clubs = ClubProvider();
    await clubs.switchUser(myUid, displayName: '안경헌', phone: '010-4511-0471');
    final club = Club(
      id: clubId,
      name: '알라딘 정기월례회',
      myRole: '정회원',
      memberCount: 2,
      creatorId: hostUid,
      region: '서울',
      industry: '골프',
      teamCount: 4,
      description: '',
      createdAt: DateTime(2026, 9, 1),
    );
    clubs.hydrateFromBootstrap(AppBootstrapSnapshot(
      userId: myUid,
      myClubs: [club],
      discoverableClubs: [club],
      membersByClubId: const {},
      financeByClubId: const {},
      loadedAt: DateTime(2026, 9, 19),
    ));
    clubs.selectClubById(clubId);
  });

  test('서버 명단 2명이면 내 폰에도 2명이 뜬다', () async {
    await clubs.mergeRemoteRosterForTest(clubId, [
      remoteRow(id: hostUid, name: '장창현', role: '회장'),
      remoteRow(id: myUid, name: '안경헌', role: '정회원'),
    ]);

    final roster = clubs.membersForClub(clubId);
    expect(roster.length, 2, reason: '방장이 빠지면 나 혼자 보인다');
    expect(roster.map((m) => m.name).toSet(), {'장창현', '안경헌'});
    expect(roster.any((m) => m.id == 'm_creator_$clubId'), isTrue,
        reason: '방장 자리는 서버 방장 것이다');
  });

  test('방장 자리에 내 행이 박혀 있어도 방장이 들어오고 내 회비는 따라온다', () async {
    // 예전 빌드가 초대 가입인데도 내 행을 방장 자리에 만들어 둔 상태
    clubs.addMember(Member(
      id: 'm_creator_$clubId',
      name: '안경헌',
      gender: '남',
      memberType: '정회원',
      role: '정회원',
      phone: '010-4511-0471',
      joinDate: DateTime(2026, 9, 1),
    ));
    clubs.addDuesSetting(DuesSetting(
      id: 'ds_year',
      type: DuesType.annual,
      amount: 120000,
      title: '연회비',
      createdAt: DateTime(2026, 1, 1),
      clubId: clubId,
    ));
    clubs.recordPayment(
      memberId: 'm_creator_$clubId',
      memberName: '안경헌',
      duesSettingId: 'ds_year',
      amount: 120000,
      year: 2026,
    );

    await clubs.mergeRemoteRosterForTest(clubId, [
      remoteRow(id: hostUid, name: '장창현', role: '회장'),
      remoteRow(
        id: myUid,
        name: '안경헌',
        role: '정회원',
        phone: '010-4511-0471',
      ),
    ]);

    final roster = clubs.membersForClub(clubId);
    expect(roster.map((m) => m.name).toSet(), {'장창현', '안경헌'});
    expect(
      roster.where((m) => m.id == 'm_creator_$clubId').single.name,
      '장창현',
      reason: '서버 방장이 방장 자리를 가져가야 한다',
    );

    final myId = Member.rosterId(clubId, myUid);
    expect(roster.any((m) => m.id == myId), isTrue, reason: '내 행은 내 id 로 남는다');
    expect(clubs.hasPaid(myId, 'ds_year', year: 2026), isTrue,
        reason: '행을 옮겼는데 납부 기록이 끊기면 안 된다');
  });
}
