import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/domain/services/finance/balance_ledger_service.dart';
import 'package:golf_rounder/models/club_model.dart';

void main() {
  final service = BalanceLedgerService();

  final transactions = [
    Transaction(
      id: '1',
      type: TxType.income,
      amount: 100000,
      category: '회비',
      title: '1월 회비',
      date: DateTime(2025, 1, 15),
      recordedBy: '총무',
    ),
    Transaction(
      id: '2',
      type: TxType.expense,
      amount: 30000,
      category: '식비',
      title: '모임 식사',
      date: DateTime(2025, 1, 20),
      recordedBy: '총무',
    ),
    Transaction(
      id: '3',
      type: TxType.income,
      amount: 50000,
      category: '회비',
      title: '2월 회비',
      date: DateTime(2025, 2, 10),
      recordedBy: '총무',
    ),
  ];

  group('BalanceLedgerService', () {
    test('totalBalance sums income minus expense', () {
      expect(service.totalBalance(transactions), 120000);
    });

    test('monthlyIncome filters by year and month', () {
      expect(service.monthlyIncome(transactions, 2025, 1), 100000);
      expect(service.monthlyIncome(transactions, 2025, 2), 50000);
      expect(service.monthlyIncome(transactions, 2025, 3), 0);
    });

    test('monthlyExpense filters by year and month', () {
      expect(service.monthlyExpense(transactions, 2025, 1), 30000);
      expect(service.monthlyExpense(transactions, 2025, 2), 0);
    });

    test('balanceAtYearEnd includes only transactions up to year', () {
      final withPriorYear = [
        Transaction(
          id: '0',
          type: TxType.income,
          amount: 200000,
          category: '회비',
          title: '2024 이월',
          date: DateTime(2024, 12, 31),
          recordedBy: '총무',
        ),
        ...transactions,
      ];
      expect(service.balanceAtYearEnd(withPriorYear, 2024), 200000);
      expect(service.balanceAtYearEnd(withPriorYear, 2025), 320000);
    });
  });
}
