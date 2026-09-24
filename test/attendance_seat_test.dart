import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/domain/services/attendance_seat.dart';

void main() {
  test('정원만큼만 참석을 받는다', () {
    expect(
      AttendanceSeat.canClaim(attendingOthers: 3, capacity: 4),
      isTrue,
    );
    expect(
      AttendanceSeat.canClaim(attendingOthers: 4, capacity: 4),
      isFalse,
    );
  });

  test('동시 참석이 넘치면 먼저 응답한 사람만 남긴다', () {
    final capped = AttendanceSeat.capAttending([
      {'memberId': 'a', 'response': '참석', 'respondedAt': '2026-01-01'},
      {'memberId': 'b', 'response': '참석', 'respondedAt': '2026-01-02'},
      {'memberId': 'c', 'response': '참석', 'respondedAt': '2026-01-03'},
    ], 2);
    expect(capped.where((r) => r['response'] == '참석').length, 2);
    expect(capped.any((r) => r['memberId'] == 'c'), isFalse);
  });

  test('정원 없는 일정은 자르지 않는다', () {
    final rows = [
      {'memberId': 'a', 'response': '참석'},
      {'memberId': 'b', 'response': '참석'},
    ];
    expect(AttendanceSeat.capAttending(rows, 0).length, 2);
    expect(
      AttendanceSeat.capacityFromSchedule({'teamCount': 0}),
      0,
    );
  });
}
