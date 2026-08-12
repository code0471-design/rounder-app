import '../../../models/club_model.dart';

/// 잔고·수입·지출 집계 — UI와 분리 (단위 테스트 가능)
class BalanceLedgerService {
  int totalBalance(List<Transaction> transactions) {
    var balance = 0;
    for (final t in transactions) {
      balance += t.type == TxType.income ? t.amount : -t.amount;
    }
    return balance;
  }

  int monthlyIncome(List<Transaction> transactions, int year, int month) {
    return transactions
        .where((t) =>
            t.type == TxType.income &&
            t.date.year == year &&
            t.date.month == month)
        .fold<int>(0, (sum, t) => sum + t.amount);
  }

  int monthlyExpense(List<Transaction> transactions, int year, int month) {
    return transactions
        .where((t) =>
            t.type == TxType.expense &&
            t.date.year == year &&
            t.date.month == month)
        .fold<int>(0, (sum, t) => sum + t.amount);
  }

  int balanceAtYearEnd(List<Transaction> transactions, int year) {
    var balance = 0;
    for (final t in transactions) {
      if (t.date.year <= year) {
        balance += t.type == TxType.income ? t.amount : -t.amount;
      }
    }
    return balance;
  }
}
