import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/data/repositories/club_repository.dart';
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

  test('방장 자리 이름이 내 계정과 달라도 서버 방장은 빠지지 않는다', () async {
    clubs.addMember(Member(
      id: 'm_creator_$clubId',
      name: '안경현',
      gender: '남',
      memberType: '정회원',
      role: '정회원',
      joinDate: DateTime(2026, 9, 1),
    ));

    await clubs.mergeRemoteRosterForTest(clubId, [
      remoteRow(id: hostUid, name: '장창현', role: '총무'),
      remoteRow(id: myUid, name: '안경헌', role: '정회원', phone: '010-4511-0471'),
    ]);

    final roster = clubs.activeMembers;
    expect(roster.any((m) => m.name == '장창현'), isTrue,
        reason: '방장 자리에 내 이름이 있어도 서버 방장은 보여야 한다');
    expect(roster.length, greaterThan(1));
    expect(
      roster.where((m) => m.id == 'm_creator_$clubId').single.name,
      '장창현',
    );
  });

  test('번호가 같아도 총무 줄을 내 줄로 지우지 않는다', () async {
    await clubs.mergeRemoteRosterForTest(clubId, [
      remoteRow(
        id: hostUid,
        name: '장창현',
        role: '총무',
        phone: '010-4511-0471',
      ),
      remoteRow(
        id: myUid,
        name: '안경헌',
        role: '정회원',
        phone: '010-4511-0471',
      ),
    ]);

    expect(
      clubs.activeMembers.map((m) => m.name).toSet(),
      {'장창현', '안경헌'},
    );
  });

  test('명단에 없어도 가입 계정이면 회원으로 그대로 나온다', () {
    clubs.addMember(Member(
      id: Member.rosterId(clubId, myUid),
      name: '안경헌',
      gender: '남',
      memberType: '정회원',
      role: '정회원',
      phone: '010-4511-0471',
    ));
    clubs.cacheClubAccountsForTest(clubId, const [
      ClubMemberAccount(
        userId: myUid,
        role: '정회원',
        name: '안경헌',
        phone: '010-4511-0471',
      ),
      ClubMemberAccount(
        userId: hostUid,
        role: '회장',
        name: '장창현',
        phone: '010-0000-0000',
      ),
    ]);
    expect(
      clubs.membersForClub(clubId).map((m) => m.name).toSet(),
      {'안경헌', '장창현'},
      reason: '원클럽처럼 가입 소속이면 명단 줄이 없어도 회원이다',
    );
    expect(clubs.activeHeadcount(clubId), 2);
  });

  test('짧은 번들이 와도 가입 계정은 빠지지 않는다', () {
    clubs.addMember(Member(
      id: Member.rosterId(clubId, myUid),
      name: '안경헌',
      gender: '남',
      memberType: '정회원',
      role: '정회원',
      phone: '010-4511-0471',
    ));
    clubs.cacheClubAccountsForTest(clubId, const [
      ClubMemberAccount(
        userId: myUid,
        role: '정회원',
        name: '안경헌',
        phone: '010-4511-0471',
      ),
      ClubMemberAccount(
        userId: hostUid,
        role: '회장',
        name: '장창현',
        phone: '010-0000-0000',
      ),
    ]);
    clubs.importBundleForTest(clubs.exportBundleForTest());
    expect(
      clubs.membersForClub(clubId).map((m) => m.name).toSet(),
      {'안경헌', '장창현'},
    );
    expect(clubs.activeHeadcount(clubId), 2);
  });

  test('명단이 지워져도 소속 계정이 있으면 방장을 다시 넣는다', () {
    clubs.addMember(Member(
      id: Member.rosterId(clubId, myUid),
      name: '안경헌',
      gender: '남',
      memberType: '정회원',
      role: '정회원',
      phone: '010-4511-0471',
    ));
    final restored = clubs.restoreMembersFromAccountsForTest(clubId, [
      const ClubMemberAccount(
        userId: hostUid,
        role: '총무',
        name: '장창현',
        phone: '010-0000-0000',
      ),
    ]);
    expect(restored, isTrue);
    expect(
      clubs.activeMembers.map((m) => m.name).toSet(),
      {'안경헌', '장창현'},
    );
  });

  test('명단을 합친다고 가입 회원 문서를 지우지 않는다', () {
    final provider = File('lib/providers/club_provider.dart').readAsStringSync();
    final prune = provider.substring(
      provider.indexOf('bool pruneDuplicateRosterRows()'),
      provider.indexOf('void _applyRosterIdRemap('),
    );
    expect(prune.contains('deleteClubMemberDoc'), isFalse);
    expect(prune.contains('seedRemovedMembers'), isFalse);
  });
}
