import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/domain/services/finance/dues_ledger_service.dart';
import 'package:golf_rounder/models/club_model.dart';

void main() {
  final service = DuesLedgerService();
  final asOf = DateTime(2025, 3, 1);

  final members = [
    Member(
      id: 'm1',
      name: '김골프',
      gender: '남',
      memberType: '정회원',
      role: '일반',
      status: '활성',
    ),
    Member(
      id: 'm2',
      name: '이골프',
      gender: '여',
      memberType: '정회원',
      role: '일반',
      status: '활성',
    ),
    Member(
      id: 'g1',
      name: '게스트',
      gender: '남',
      memberType: '게스트',
      role: '일반',
      status: '활성',
    ),
  ];

  final monthlySetting = DuesSetting(
    id: 'ds1',
    type: DuesType.monthly,
    amount: 50000,
    title: '2025 월회비',
    createdAt: DateTime(2025, 1, 1),
    startMonth: 1,
    endMonth: 12,
  );

  group('DuesLedgerService', () {
    test('monthly unpaid counts eligible members without payment', () {
      final payments = [
        DuesPayment(
          id: 'p1',
          memberId: 'm1',
          memberName: '김골프',
          duesSettingId: 'ds1',
          amount: 50000,
          paidAt: DateTime(2025, 1, 5),
          recordedBy: '총무',
        ),
      ];

      // Jan–Mar: m1 paid Jan only; m2 unpaid all 3 months → 5 slots
      expect(
        service.unpaidSlotsForSetting(
          setting: monthlySetting,
          members: members,
          payments: payments,
          asOf: asOf,
        ),
        5,
      );
    });

    test('guest members excluded from monthly dues', () {
      expect(
        service.unpaidSlotsForSetting(
          setting: monthlySetting,
          members: members,
          payments: const [],
          asOf: asOf,
        ),
        6, // 2 members × 3 months
      );
    });

    test('totalUnpaidAmount multiplies slots by setting amount', () {
      expect(
        service.totalUnpaidAmount(
          activeSettings: [monthlySetting],
          members: members,
          payments: const [],
          asOf: asOf,
        ),
        6 * 50000,
      );
    });

    test('hasAnyUnpaid returns false when all paid', () {
      final payments = <DuesPayment>[];
      for (final m in members.where((x) => x.memberType == '정회원')) {
        for (var month = 1; month <= 3; month++) {
          payments.add(
            DuesPayment(
              id: '${m.id}-$month',
              memberId: m.id,
              memberName: m.name,
              duesSettingId: 'ds1',
              amount: 50000,
              paidAt: DateTime(2025, month, 1),
              recordedBy: '총무',
            ),
          );
        }
      }

      expect(
        service.hasAnyUnpaid(
          activeSettings: [monthlySetting],
          members: members,
          payments: payments,
          asOf: asOf,
        ),
        isFalse,
      );
    });
  });
}
