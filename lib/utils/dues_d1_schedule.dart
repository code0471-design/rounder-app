import '../models/club_model.dart';

/// 회비 납부요청 알림톡 — 납부기준일 1일 전 10시(KST) 큐.
abstract final class DuesD1Schedule {
  static const noticeText = '납부기준일 1일전 회원들에게 알림톡이 발송됩니다';

  static const kind = 'dues';

  static String scheduleIdFor(String settingId) => 'dues_$settingId';

  static DateTime sendOnDate(DateTime dueDate) {
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.subtract(const Duration(days: 1));
  }

  static String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String periodKey(DuesSetting setting, DateTime due) {
    if (setting.type == DuesType.monthly) {
      return '${due.year}-${due.month.toString().padLeft(2, '0')}';
    }
    return ymd(due);
  }

  static String queueDocId({
    required String settingId,
    required String userId,
    required String periodKey,
  }) =>
      '${scheduleIdFor(settingId)}__${userId}__$periodKey';

  static String dueText(DateTime due) =>
      '${due.year}.${due.month.toString().padLeft(2, '0')}.'
      '${due.day.toString().padLeft(2, '0')}';

  /// D-1이 오늘 이후인 납부일. 월회비는 앞으로 [monthsAhead]개월.
  static List<DateTime> upcomingDueDates(
    DuesSetting setting, {
    DateTime? now,
    int monthsAhead = 12,
  }) {
    if (!setting.isActive) return const [];
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final out = <DateTime>[];

    if (setting.type == DuesType.monthly) {
      for (var i = 0; i < monthsAhead; i++) {
        final cursor = DateTime(n.year, n.month + i, 1);
        if (!setting.isActiveForYearMonth(cursor.year, cursor.month)) {
          continue;
        }
        final due = setting.dueDateFor(year: cursor.year, month: cursor.month);
        if (due == null) continue;
        if (sendOnDate(due).isBefore(today)) continue;
        out.add(due);
      }
      return out;
    }

    final due = setting.dueDateFor();
    if (due == null) return const [];
    final day = DateTime(due.year, due.month, due.day);
    if (sendOnDate(day).isBefore(today)) return const [];
    return [day];
  }
}
