import '../models/club_model.dart';

/// 회비납부 탭 한 칸 칩. hidden 은 목록에 안 넣는다.
enum DuesChip { hidden, beforeJoin, scheduled, paid, unpaid }

/// 가입·탈퇴·예정. 정회원만. 게스트는 대상이 아니다.
abstract final class DuesPeriodEligibility {
  static bool isRegular(Member member) => member.memberType == '정회원';

  static bool isLeft(Member member) => member.status == '탈퇴';

  /// 탈퇴일. 없으면 오늘. 활성은 null.
  static DateTime? effectiveLeftAt(Member member, DateTime asOf) {
    if (!isLeft(member)) return null;
    return member.leftAt ?? asOf;
  }

  static int yearMonth(int year, int month) => year * 12 + month;

  /// 그 기간에 회원이었으면 목록에 남긴다. 탈퇴한 달·해부터는 숨긴다.
  static bool isVisible({
    required Member member,
    required DuesType type,
    required int year,
    int? month,
    required DateTime asOf,
  }) {
    if (!isRegular(member)) return false;
    final left = effectiveLeftAt(member, asOf);
    if (left == null) return true;
    if (type == DuesType.monthly) {
      final viewMonth = month ?? 1;
      return yearMonth(year, viewMonth) < yearMonth(left.year, left.month);
    }
    return year < left.year;
  }

  static DuesChip classify({
    required Member member,
    required DuesType type,
    required int year,
    int? month,
    required bool hasPaid,
    required DateTime asOf,
  }) {
    if (!isVisible(
      member: member,
      type: type,
      year: year,
      month: month,
      asOf: asOf,
    )) {
      return DuesChip.hidden;
    }

    if (member.joinDate != null) {
      final joined = member.joinDate!;
      if (type == DuesType.monthly) {
        final viewMonth = month ?? 1;
        if (yearMonth(year, viewMonth) <
            yearMonth(joined.year, joined.month)) {
          return DuesChip.beforeJoin;
        }
      } else if (year < joined.year) {
        return DuesChip.beforeJoin;
      }
    }

    if (type == DuesType.monthly) {
      final viewMonth = month ?? 1;
      if (yearMonth(year, viewMonth) > yearMonth(asOf.year, asOf.month)) {
        return DuesChip.scheduled;
      }
    } else if (year > asOf.year) {
      return DuesChip.scheduled;
    }

    if (hasPaid) return DuesChip.paid;
    return DuesChip.unpaid;
  }
}
