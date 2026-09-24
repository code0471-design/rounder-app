/// D-1 알림톡은 납부/라운딩 하루 전 10시(KST)만.
/// 10시 20분이 지나면 보내지 않는다. 앱을 오후에 열었다고 따라 보내면 안 된다.
abstract final class D1SendWindow {
  static const hour = 10;
  static const catchUpMinutes = 20;

  static DateTime kstNow([DateTime? utc]) {
    final u = utc ?? DateTime.now().toUtc();
    return u.add(const Duration(hours: 9));
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _minutes(DateTime kst) => kst.hour * 60 + kst.minute;

  /// 오늘 10:00~10:20. 예약이 실패한 분만 이 구간에 즉시 발송.
  static bool shouldSendNow(DateTime nowKst, DateTime sendOn) {
    if (_day(nowKst) != _day(sendOn)) return false;
    final m = _minutes(nowKst);
    return m >= hour * 60 && m < hour * 60 + catchUpMinutes;
  }

  /// 내일 분이거나 오늘 10시 이전. 솔라피 10시 예약.
  static bool shouldReserve(DateTime nowKst, DateTime sendOn) {
    final today = _day(nowKst);
    final on = _day(sendOn);
    if (on.isAfter(today)) return true;
    if (on != today) return false;
    return _minutes(nowKst) < hour * 60;
  }

  /// 이미 지난 날이거나 오늘 10:20 이후. 보내지 않고 끝난 것으로 표시.
  static bool shouldSkipAsMissed(DateTime nowKst, DateTime sendOn) {
    final today = _day(nowKst);
    final on = _day(sendOn);
    if (on.isBefore(today)) return true;
    if (on != today) return false;
    return _minutes(nowKst) >= hour * 60 + catchUpMinutes;
  }
}
