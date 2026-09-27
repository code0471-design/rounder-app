import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClubProvider clubs;
  late String memberId;
  late String clubId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppDependencies.instance.init(offlineMock: true);
    clubs = ClubProvider();
    await clubs.switchUser('kakao_ahn', displayName: '안경헌');
    await clubs.createClub(
      name: '기간 끝난 회비 모임',
      region: '서울',
      industry: '골프',
      teamCount: 4,
      myRole: '회장',
    );
    clubId = clubs.selectedClub.id;
    clubs.selectClubById(clubId);
    memberId = clubs.currentMember!.id;
  });

  test('11월 종료 월회비는 12월에 11월분을 늦게 낼 수 있고 12월분은 안 걷는다', () {
    clubs.addDuesSetting(DuesSetting(
      id: 'ds_nov',
      type: DuesType.monthly,
      amount: 50000,
      title: '월회비',
      createdAt: DateTime(2026, 3, 1),
      clubId: clubId,
      startYear: 2026,
      startMonth: 3,
      endYear: 2026,
      endMonth: 11,
      dueDayOfMonth: 10,
    ));

    expect(clubs.currentHomeDuesSetting(2026, 12)?.id, 'ds_nov');
    expect(
      clubs.currentHomeDuesSetting(2026, 12)!
          .collectableView(DateTime(2026, 12, 8)),
      (year: 2026, month: 11),
    );

    clubs.recordPayment(
      memberId: memberId,
      memberName: '안경헌',
      duesSettingId: 'ds_nov',
      amount: 50000,
      year: 2026,
      month: 11,
    );
    expect(clubs.hasPaid(memberId, 'ds_nov', year: 2026, month: 11), isTrue);

    clubs.recordPayment(
      memberId: memberId,
      memberName: '안경헌',
      duesSettingId: 'ds_nov',
      amount: 50000,
      year: 2026,
      month: 12,
    );
    expect(clubs.hasPaid(memberId, 'ds_nov', year: 2026, month: 12), isFalse,
        reason: '12월분은 안 걷는다');
    expect(clubs.hasPaid(memberId, 'ds_nov', year: 2026, month: 11), isTrue,
        reason: '납부·수입 기록은 남긴다');
    expect(clubs.transactions.where((t) => t.amount == 50000).length, 1);
    expect(clubs.allDuesSettings.singleWhere((d) => d.id == 'ds_nov').isActive,
        isTrue,
        reason: '기간이 끝났다고 종료된 회비로 보내면 안 된다');
    final asOfDec = DateTime(2026, 12, 8);
    expect(clubs.unpaidCountForMonth(2026, 12, asOf: asOfDec), 0,
        reason: '12월에 열면 11월분 납부 현황이다');
    expect(clubs.paidCountForMonth(2026, 12, asOf: asOfDec), 1);
  });

  test('납부 기준일을 지나면 연체여도 납부는 되고 정시 포인트는 없다', () {
    final now = DateTime.now();
    final last = DuesSetting.shiftYearMonth(now.year, now.month, -1);
    clubs.addDuesSetting(DuesSetting(
      id: 'ds_late',
      type: DuesType.monthly,
      amount: 30000,
      title: '월회비',
      createdAt: DateTime(last.year, last.month, 1),
      clubId: clubId,
      startYear: last.year,
      startMonth: last.month,
      dueDayOfMonth: 1,
    ));
    final before = clubs.getMembershipPoints(memberId, year: now.year);
    clubs.recordPayment(
      memberId: memberId,
      memberName: '안경헌',
      duesSettingId: 'ds_late',
      amount: 30000,
      year: last.year,
      month: last.month,
    );
    expect(
      clubs.hasPaid(memberId, 'ds_late', year: last.year, month: last.month),
      isTrue,
    );
    expect(clubs.getMembershipPoints(memberId, year: now.year), before,
        reason: '기준일 지난 납부는 정시 포인트가 없다');
  });
}
