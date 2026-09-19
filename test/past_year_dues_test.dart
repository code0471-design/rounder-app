import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 작년·재작년 회비를 납부 처리하면 그 해로 들어가야 한다.
/// 예전에는 오늘 날짜로 기록해서 이번 달 수입에 잡히고 그 해는 계속 미납이었다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClubProvider clubs;
  late String memberId;
  final now = DateTime.now();
  final lastYear = now.year - 1;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppDependencies.instance.init(offlineMock: true);
    clubs = ClubProvider();
    await clubs.switchUser('kakao_ahn', displayName: '안경헌');
    await clubs.createClub(
      name: '아레나 골프회',
      region: '서울',
      industry: '골프',
      teamCount: 4,
      myRole: '회장',
    );
    clubs.selectClubById(clubs.selectedClub.id);
    memberId = clubs.currentMember!.id;

    clubs.addDuesSetting(DuesSetting(
      id: 'ds_annual',
      type: DuesType.annual,
      amount: 400000,
      title: '연회비',
      createdAt: DateTime(lastYear, 1, 1),
      clubId: clubs.selectedClub.id,
      dueDate: DateTime(lastYear, 3, 31),
    ));
  });

  test('작년 연회비를 납부하면 작년 납부로 잡힌다', () {
    clubs.recordPayment(
      memberId: memberId,
      memberName: '안경헌',
      duesSettingId: 'ds_annual',
      amount: 400000,
      year: lastYear,
    );

    expect(clubs.hasPaid(memberId, 'ds_annual', year: lastYear), isTrue,
        reason: '납부했는데 계속 미납으로 보이던 문제');
    expect(clubs.hasPaid(memberId, 'ds_annual', year: now.year), isFalse,
        reason: '작년 납부가 올해 납부로 둔갑하면 안 된다');
  });

  test('작년 연회비는 이번 달 수입에 들어가지 않는다', () {
    clubs.recordPayment(
      memberId: memberId,
      memberName: '안경헌',
      duesSettingId: 'ds_annual',
      amount: 400000,
      year: lastYear,
    );

    expect(clubs.monthlyIncome(now.year, now.month), 0,
        reason: '작년 회비가 이번 달 수입으로 잡히던 문제');
    final tx = clubs.transactions.where((t) => t.amount == 400000).single;
    expect(tx.date.year, lastYear);
    expect(clubs.totalBalance, 400000, reason: '잔고에는 그대로 들어간다');
  });

  test('올해 연회비는 오늘 날짜 그대로다', () {
    clubs.recordPayment(
      memberId: memberId,
      memberName: '안경헌',
      duesSettingId: 'ds_annual',
      amount: 400000,
      year: now.year,
    );

    expect(clubs.hasPaid(memberId, 'ds_annual', year: now.year), isTrue);
    expect(clubs.monthlyIncome(now.year, now.month), 400000);
  });

  test('월회비도 그 달로 잡힌다 (31일에 눌러도 달이 안 넘어간다)', () {
    clubs.addDuesSetting(DuesSetting(
      id: 'ds_monthly',
      type: DuesType.monthly,
      amount: 50000,
      title: '월회비',
      createdAt: DateTime(lastYear, 1, 1),
      clubId: clubs.selectedClub.id,
    ));
    clubs.recordPayment(
      memberId: memberId,
      memberName: '안경헌',
      duesSettingId: 'ds_monthly',
      amount: 50000,
      year: lastYear,
      month: 2,
    );

    expect(clubs.hasPaid(memberId, 'ds_monthly', year: lastYear, month: 2),
        isTrue);
    final tx = clubs.transactions.where((t) => t.amount == 50000).single;
    expect(tx.date.month, 2);
  });
}
