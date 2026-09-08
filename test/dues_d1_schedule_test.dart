import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/utils/dues_d1_schedule.dart';

void main() {
  DuesSetting monthly({int dueDay = 25, int? startYear}) => DuesSetting(
        id: 'ds1',
        type: DuesType.monthly,
        amount: 30000,
        title: '월회비',
        createdAt: DateTime(2026, 1, 1),
        startYear: startYear ?? 2026,
        startMonth: 1,
        dueDayOfMonth: dueDay,
      );

  test('납부일 1일 전이 sendOn 이다', () {
    expect(
      DuesD1Schedule.sendOnDate(DateTime(2026, 9, 25)),
      DateTime(2026, 9, 24),
    );
    expect(
      DuesD1Schedule.sendOnDate(DateTime(2026, 10, 1)),
      DateTime(2026, 9, 30),
    );
  });

  test('월회비는 이번 달 이후 D-1만 잡고, 이미 지난 납부일은 빼다', () {
    final s = monthly(dueDay: 25);
    final now = DateTime(2026, 9, 8);
    final dues = DuesD1Schedule.upcomingDueDates(s, now: now, monthsAhead: 3);
    expect(dues, [
      DateTime(2026, 9, 25),
      DateTime(2026, 10, 25),
      DateTime(2026, 11, 25),
    ]);
  });

  test('오늘이 납부일 당일이면 이번 달 D-1은 이미 지나 다음 달만 잡는다', () {
    final s = monthly(dueDay: 25);
    final now = DateTime(2026, 9, 25);
    final dues = DuesD1Schedule.upcomingDueDates(s, now: now, monthsAhead: 2);
    expect(dues.first, DateTime(2026, 10, 25));
  });

  test('연회비는 dueDate 하루 전 한 번만', () {
    final s = DuesSetting(
      id: 'ds2',
      type: DuesType.annual,
      amount: 120000,
      title: '연회비',
      createdAt: DateTime(2026, 1, 1),
      year: 2026,
      dueDate: DateTime(2026, 3, 10),
    );
    expect(
      DuesD1Schedule.upcomingDueDates(s, now: DateTime(2026, 3, 1)),
      [DateTime(2026, 3, 10)],
    );
    expect(
      DuesD1Schedule.upcomingDueDates(s, now: DateTime(2026, 3, 10)),
      isEmpty,
    );
  });
}
