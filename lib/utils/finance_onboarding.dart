/// 신규 모임 총무가 재무를 어디서부터 잡을지
enum FinanceStartMode {
  /// 올시즌(올해 1월 1일)부터
  season,

  /// 이번 달 1일부터
  thisMonth,
}

abstract final class FinanceOnboarding {
  static DateTime openingAsOf(FinanceStartMode mode, [DateTime? now]) {
    final n = now ?? DateTime.now();
    if (mode == FinanceStartMode.season) {
      return DateTime(n.year, 1, 1);
    }
    return DateTime(n.year, n.month, 1);
  }

  static String memoFor(FinanceStartMode mode, [DateTime? now]) {
    final asOf = openingAsOf(mode, now);
    final label =
        '${asOf.year}년 ${asOf.month}월 ${asOf.day}일 기준';
    return mode == FinanceStartMode.season
        ? '올시즌 시작 잔고 ($label)'
        : '이번달 시작 잔고 ($label)';
  }

  static String asOfLabel(DateTime asOf) =>
      '${asOf.year}년 ${asOf.month}월 ${asOf.day}일';

  static FinanceStartMode? modeFromMemo(String? memo) {
    final t = memo ?? '';
    if (t.contains('올시즌')) return FinanceStartMode.season;
    if (t.contains('이번달')) return FinanceStartMode.thisMonth;
    return null;
  }

  static FinanceStartMode? inferMode({
    String? memo,
    DateTime? asOf,
    DateTime? now,
  }) {
    final fromMemo = modeFromMemo(memo);
    if (fromMemo != null) return fromMemo;
    final n = now ?? DateTime.now();
    if (asOf != null &&
        asOf.year == n.year &&
        asOf.month == 1 &&
        asOf.day == 1) {
      return FinanceStartMode.season;
    }
    return null;
  }

  /// 올시즌(1월부터)이면 1월 1일, 이번달·그 외는 오늘.
  static DateTime defaultTransactionDate({
    String? memo,
    DateTime? asOf,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final mode = inferMode(memo: memo, asOf: asOf, now: n);
    if (mode == FinanceStartMode.season) {
      return DateTime(n.year, 1, 1);
    }
    return DateTime(n.year, n.month, n.day);
  }
}
