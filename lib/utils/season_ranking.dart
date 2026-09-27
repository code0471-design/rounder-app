import '../models/club_model.dart';

/// 시즌 랭킹 마감·내역 표시. 화면 문구를 한곳에 둔다.
abstract final class SeasonRanking {
  static String lockKey(String clubId, int year) => '$clubId:$year';

  static String yearLabel(
    int year, {
    required int nowYear,
    required bool closed,
  }) {
    if (year == nowYear && closed) return '$year 올해 확정';
    if (year == nowYear) return '$year 올해';
    if (closed) return '$year 확정';
    return '$year년';
  }

  static String closeButtonLabel(int year, {required bool closed}) {
    return closed ? '${year}시즌 마감 취소하기' : '${year}시즌 랭킹 마감 확정하기';
  }

  static String closeConfirmMessage(int year, {int? nowYear}) {
    final now = nowYear ?? DateTime.now().year;
    if (year == now) return '올해 멤버십 랭킹을 마감, 확정하시겠습니까?';
    return '$year년 멤버십 랭킹을 마감, 확정하시겠습니까?';
  }

  static String reopenConfirmMessage(int year, {int? nowYear}) {
    final now = nowYear ?? DateTime.now().year;
    if (year == now) return '올해 멤버십 랭킹 마감을 취소하시겠습니까?';
    return '$year년 멤버십 랭킹 마감을 취소하시겠습니까?';
  }

  static String historyEmptyMessage(int year, {int? nowYear}) {
    final now = nowYear ?? DateTime.now().year;
    if (year == now) return '올해 적립된 포인트가 없습니다';
    return '$year년 적립된 포인트가 없습니다';
  }

  static String historyLine(MembershipPointEvent e) {
    var desc = e.desc;
    final pipe = desc.lastIndexOf('|');
    if (pipe != -1) desc = desc.substring(0, pipe);
    desc = desc.trim();
    final sign = e.points > 0 ? '+' : '';
    return '$desc $sign${e.points}p';
  }
}
