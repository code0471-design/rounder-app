import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClubProvider clubs;
  late String unpaidId;
  late String paidLastId;
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
    paidLastId = 'm_${clubs.selectedClub.id}_paid_last';
    clubs.addMember(Member(
      id: unpaidId,
      name: '미납자',
      gender: '남',
      memberType: '정회원',
      role: '일반',
      joinDate: DateTime(2026, 1, 1),
    ));
    clubs.addMember(Member(
      id: paidLastId,
      name: '지난달납부',
      gender: '남',
      memberType: '정회원',
      role: '일반',
      joinDate: DateTime(2026, 1, 1),
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
    clubs.recordPayment(
      memberId: paidLastId,
      memberName: '지난달납부',
      duesSettingId: monthly.id,
      amount: 30000,
      year: 2026,
      month: 8,
    );
  });

  test('납부일 전에는 이번달 미납이 아니고 지난달 미납만 나온다', () {
    final rows = clubs.reminderUnpaidMembers(
      monthly,
      asOf: DateTime(2026, 9, 15),
    );
    final unpaid = rows.firstWhere((r) => r.member.id == unpaidId);
    expect(unpaid.owesPreviousMonth, isTrue);
    expect(unpaid.owesCurrentMonth, isFalse);
    expect(unpaid.periodLabel, '지난달 미납');
    expect(rows.any((r) => r.member.id == paidLastId), isFalse);
    expect(rows.any((r) => r.member.memberType == '게스트'), isFalse);
  });

  test('납부일 당일에는 이번달을 미납으로 넣지 않는다', () {
    final rows = clubs.reminderUnpaidMembers(
      monthly,
      asOf: DateTime(2026, 9, 25),
    );
    final unpaid = rows.firstWhere((r) => r.member.id == unpaidId);
    expect(unpaid.owesPreviousMonth, isTrue);
    expect(unpaid.owesCurrentMonth, isFalse);
  });

  test('납부일이 지난 뒤에는 지난달과 이번달 미납이 같이 나온다', () {
    final rows = clubs.reminderUnpaidMembers(
      monthly,
      asOf: DateTime(2026, 9, 26),
    );
    final unpaid = rows.firstWhere((r) => r.member.id == unpaidId);
    expect(unpaid.owesPreviousMonth, isTrue);
    expect(unpaid.owesCurrentMonth, isTrue);
    expect(unpaid.periodLabel, '지난달 · 이번달 미납');

    final paidLast = rows.firstWhere((r) => r.member.id == paidLastId);
    expect(paidLast.owesPreviousMonth, isFalse);
    expect(paidLast.owesCurrentMonth, isTrue);
    expect(paidLast.periodLabel, '이번달 미납');
  });

  test('지난달만 냈으면 그전 달 미납은 독촉 목록에 없다', () {
    final rows = clubs.reminderUnpaidMembers(
      monthly,
      asOf: DateTime(2026, 9, 15),
    );
    expect(rows.any((r) => r.member.id == paidLastId), isFalse);
  });
}
