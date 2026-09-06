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
}
