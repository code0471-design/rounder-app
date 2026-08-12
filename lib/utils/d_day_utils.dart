/// 라운딩 날짜 기준 D-Day 계산 (D-3, D-Day, D+1 …)
class DDayUtils {
  DDayUtils._();

  /// 오늘(자정) 기준 남은 일수. 음수 = 지난 날.
  static int daysFromToday(DateTime date) {
    final now = DateTime.now();
    final target = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    return target.difference(today).inDays;
  }

  static String format(DateTime? date, {String emptyLabel = '일정 없음'}) {
    if (date == null) return emptyLabel;
    final d = daysFromToday(date);
    if (d > 0) return 'D-$d';
    if (d == 0) return 'D-Day';
    return 'D+${-d}';
  }

  static bool isUrgent(DateTime? date, {int withinDays = 7}) {
    if (date == null) return false;
    final d = daysFromToday(date);
    return d >= 0 && d <= withinDays;
  }
}
