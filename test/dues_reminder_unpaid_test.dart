import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClubProvider clubs;
  late String unpaidId;
  late String septJoinId;
  late String leftId;
  late DuesSetting monthly;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    AppDependencies.instance.init(offlineMock: true);
    clubs = ClubProvider();
    await clubs.switchUser('kakao_ahn', displayName: '안경현');
    final ok = await clubs.createClub(
      name: '아레나',
      region: '서울',
      industry: '골프',
      teamCount: 4,
      myRole: '회장,총무',
    );
    expect(ok, isTrue);
    unpaidId = 'm_${clubs.selectedClub.id}_unpaid';
    septJoinId = 'm_${clubs.selectedClub.id}_sept';
    leftId = 'm_${clubs.selectedClub.id}_left';
    clubs.addMember(Member(
      id: unpaidId,
      name: '미납자',
      gender: '남',
      memberType: '정회원',
      role: '일반',
      joinDate: DateTime(2026, 1, 1),
    ));
    clubs.addMember(Member(
      id: septJoinId,
      name: '구월가입',
      gender: '남',
      memberType: '정회원',
      role: '일반',
      joinDate: DateTime(2026, 9, 1),
    ));
    clubs.addMember(Member(
      id: leftId,
      name: '탈퇴자',
      gender: '남',
      memberType: '정회원',
      role: '일반',
      joinDate: DateTime(2026, 1, 1),
      status: '탈퇴',
      leftAt: DateTime(2026, 9, 1),
    ));
    clubs.addMember(Member(
      id: 'm_${clubs.selectedClub.id}_guest',
      name: '게스트',
      gender: '남',
      memberType: '게스트',
      role: '일반',
      joinDate: DateTime(2026, 1, 1),
    ));
    monthly = DuesSetting(
      id: 'ds_monthly',
      type: DuesType.monthly,
      amount: 30000,
      title: '월회비',
      createdAt: DateTime(2026, 1, 1),
      clubId: clubs.selectedClub.id,
      startYear: 2026,
      startMonth: 1,
      dueDayOfMonth: 25,
    );
    clubs.addDuesSetting(monthly);
  });

  test('독촉은 지금 보는 그 월만이고 시작월부터 훑지 않는다', () {
    final rows = clubs.reminderUnpaidMembers(
      monthly,
      year: 2026,
      month: 9,
      asOf: DateTime(2026, 9, 15),
    );
    expect(rows.any((r) => r.member.id == unpaidId), isTrue);
    expect(rows.any((r) => r.member.id == septJoinId), isTrue);
    expect(rows.every((r) => r.periodLabel == '9월 미납'), isTrue);
    expect(rows.any((r) => r.member.memberType == '게스트'), isFalse);
    expect(rows.any((r) => r.member.id == leftId), isFalse);
  });

  test('8월 독촉에 9월 가입자와 탈퇴월 회원은 없다', () {
    final rows = clubs.reminderUnpaidMembers(
      monthly,
      year: 2026,
      month: 8,
      asOf: DateTime(2026, 9, 15),
    );
    expect(rows.any((r) => r.member.id == unpaidId), isTrue);
    expect(rows.any((r) => r.member.id == septJoinId), isFalse);
    expect(rows.any((r) => r.member.id == leftId), isFalse,
        reason: '탈퇴 회원은 독촉 대상이 아니다');
    expect(rows.every((r) => r.periodLabel == '8월 미납'), isTrue);
  });

  test('그 기간에 미납이 없으면 빈 목록이다', () {
    clubs.recordPayment(
      memberId: unpaidId,
      memberName: '미납자',
      duesSettingId: monthly.id,
      amount: 30000,
      year: 2026,
      month: 7,
    );
    final rows = clubs.reminderUnpaidMembers(
      monthly,
      year: 2026,
      month: 7,
      asOf: DateTime(2026, 9, 15),
    );
    expect(rows.any((r) => r.member.id == unpaidId), isFalse);
  });

  test('탈퇴 회원은 활성 정회원 목록에 다시 안 들어간다', () {
    expect(clubs.regularMembers.any((m) => m.id == leftId), isFalse);
    expect(clubs.activeMembers.any((m) => m.id == leftId), isFalse);
  });
}
