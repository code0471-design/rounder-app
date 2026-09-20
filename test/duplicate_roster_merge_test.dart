import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/domain/services/app_data_bootstrap_service.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 방장이 이름·번호만 적어 둔 회원이 초대 링크로 가입하면 같은 사람이 두 줄이 됐다.
/// (아레나: 'Jeongwon Lee' 옛 행 + '이정원' 계정 행)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const clubId = 'c_1786973797931';
  const hostUid = 'kakao_host';
  const myUid = 'google_me';
  const phone = '010-9287-4073';

  late ClubProvider clubs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppDependencies.instance.init(offlineMock: true);
    clubs = ClubProvider();
    await clubs.switchUser(myUid, displayName: '이정원', phone: phone);
    final club = Club(
      id: clubId,
      name: '아레나 골프회',
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
      loadedAt: DateTime(2026, 9, 20),
    ));
    clubs.selectClubById(clubId);

    // 방장이 번호만 적어 둔 옛 행 + 거기 붙은 포인트
    clubs.addMember(Member(
      id: 'm_${clubId}_m1',
      name: 'Jeongwon Lee',
      gender: '남',
      memberType: '정회원',
      role: '정회원',
      phone: phone,
      joinDate: DateTime(2026, 9, 12),
    ));
    clubs.addMembershipPoint(
      memberId: 'm_${clubId}_m1',
      type: MembershipPointType.roundAttendance,
      points: 10,
      desc: '9월 라운딩 참석',
    );
  });

  test('초대 가입해도 같은 사람이 두 줄이 되지 않는다', () async {
    await clubs.mergeRemoteRosterForTest(clubId, [
      Member(
        id: hostUid,
        name: '안경헌',
        gender: '남',
        memberType: '정회원',
        role: '회장',
        joinDate: DateTime(2026, 9, 1),
      ),
      Member(
        id: myUid,
        name: '이정원',
        gender: '남',
        memberType: '정회원',
        role: '정회원',
        phone: phone,
        joinDate: DateTime(2026, 9, 20),
      ),
    ]);

    final roster = clubs.membersForClub(clubId);
    expect(roster.length, 2, reason: '안경헌 + 이정원 두 명이어야 한다');
    expect(roster.where((m) => m.name == 'Jeongwon Lee'), isEmpty,
        reason: '옛 행이 그대로 남으면 같은 사람이 두 줄이다');
    expect(roster.any((m) => m.id == Member.rosterId(clubId, myUid)), isTrue);
  });

  test('합칠 때 옛 행에 붙어 있던 포인트가 따라온다', () async {
    await clubs.mergeRemoteRosterForTest(clubId, [
      Member(
        id: myUid,
        name: '이정원',
        gender: '남',
        memberType: '정회원',
        role: '정회원',
        phone: phone,
        joinDate: DateTime(2026, 9, 20),
      ),
    ]);

    final myId = Member.rosterId(clubId, myUid);
    final ranking = clubs.memberPointsRankingForYear(DateTime.now().year);
    expect(ranking.any((e) => e.key == myId), isTrue,
        reason: '행을 합쳤는데 포인트가 옛 id 에 남으면 랭킹에서 사라진다');
    expect(ranking.any((e) => e.key == 'm_${clubId}_m1'), isFalse);
  });

  test('다른 번호의 계정 행은 흡수하지 않는다', () async {
    clubs.addMember(Member(
      id: 'm_${clubId}_kakao_other',
      name: '다른사람',
      gender: '남',
      memberType: '정회원',
      role: '정회원',
      phone: '010-1111-2222',
      joinDate: DateTime(2026, 9, 15),
    ));
    await clubs.mergeRemoteRosterForTest(clubId, [
      Member(
        id: myUid,
        name: '이정원',
        gender: '남',
        memberType: '정회원',
        role: '정회원',
        phone: phone,
        joinDate: DateTime(2026, 9, 20),
      ),
    ]);

    final roster = clubs.membersForClub(clubId);
    expect(roster.any((m) => m.id == 'm_${clubId}_kakao_other'), isTrue,
        reason: '다른 번호 계정 행을 삼키면 그 사람이 명단에서 사라진다');
  });

  test('방장이 봐도 같은 번호 이정원 두 줄은 한 줄이다', () async {
    final host = ClubProvider();
    await host.switchUser(hostUid, displayName: '안경헌', phone: '010-1111-2222');
    final club = Club(
      id: clubId,
      name: '아레나 골프회',
      myRole: '회장',
      memberCount: 3,
      creatorId: hostUid,
      region: '서울',
      industry: '골프',
      teamCount: 4,
      description: '',
      createdAt: DateTime(2026, 9, 1),
    );
    host.hydrateFromBootstrap(AppBootstrapSnapshot(
      userId: hostUid,
      myClubs: [club],
      discoverableClubs: [club],
      membersByClubId: const {},
      financeByClubId: const {},
      loadedAt: DateTime(2026, 9, 20),
    ));
    host.selectClubById(clubId);
    await host.mergeRemoteRosterForTest(clubId, [
      Member(
        id: hostUid,
        name: '안경헌',
        gender: '남',
        memberType: '정회원',
        role: '회장',
        phone: '010-1111-2222',
        joinDate: DateTime(2026, 9, 1),
      ),
      Member(
        id: 'kakao_lee',
        name: 'Jeongwon Leeee',
        gender: '남',
        memberType: '정회원',
        role: '정회원',
        phone: phone,
        joinDate: DateTime(2026, 9, 12),
      ),
      Member(
        id: 'google_lee',
        name: '이정원',
        gender: '남',
        memberType: '정회원',
        role: '정회원',
        phone: phone,
        joinDate: DateTime(2026, 9, 12),
      ),
    ]);

    final roster = host.membersForClub(clubId);
    expect(roster.length, 2, reason: '안경헌 + 이정원만 보여야 한다');
    expect(roster.where((m) => m.name.contains('Jeongwon')), isEmpty);
    expect(roster.where((m) => m.name == '이정원').length, 1);
  });
}
