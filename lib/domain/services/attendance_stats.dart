import '../../models/club_model.dart';

/// 회원 한 명의 라운딩 참석 집계.
///
/// '참석 라운딩'은 **실제로 다녀온 횟수**다. 그래서 두 가지를 뺀다.
/// - 아직 안 열린(예정) 일정: 참석 응답만 해둔 상태라 다녀온 게 아니다.
/// - 취소된 일정: 응답은 남아 있지만 라운딩 자체가 없었다.
///
/// `RoundSchedule.isPast` 가 위 두 경우를 모두 false 로 만들어 주지만,
/// 나중에 isPast 정의가 바뀌어도 취소 일정이 새지 않게 명시적으로 한 번 더 건다.
class AttendanceStats {
  /// 참석으로 응답하고 실제로 지난 라운딩 수
  final int attended;

  /// 집계 대상이 된 지난 라운딩 수 (취소 제외)
  final int finished;

  const AttendanceStats({required this.attended, required this.finished});

  /// 참석률(%) — 지난 라운딩이 없으면 null
  int? get ratePercent {
    if (finished <= 0) return null;
    return (attended * 100 / finished).round();
  }

  static const empty = AttendanceStats(attended: 0, finished: 0);

  /// [schedules] 중 [clubId] 모임의 지난 라운딩을 기준으로 [memberId] 참석을 센다.
  static AttendanceStats forMember({
    required Iterable<RoundSchedule> schedules,
    required String clubId,
    required String memberId,
  }) {
    if (memberId.isEmpty) return empty;

    var attended = 0;
    var finished = 0;
    for (final s in schedules) {
      if (s.clubId != clubId) continue;
      if (s.status == ScheduleStatus.cancelled) continue;
      if (!s.isPast) continue;
      finished++;
      final came = s.responses.any(
        (r) => r.memberId == memberId && r.response == '참석',
      );
      if (came) attended++;
    }
    return AttendanceStats(attended: attended, finished: finished);
  }
}
