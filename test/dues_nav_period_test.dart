import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/models/club_model.dart';

DuesSetting monthly({
  int? startYear,
  int startMonth = 3,
  int? endYear,
  int? endMonth,
}) =>
    DuesSetting(
      id: 'm',
      type: DuesType.monthly,
      amount: 30000,
      title: '월회비',
      createdAt: DateTime(2026, 1, 15),
      startYear: startYear ?? 2026,
      startMonth: startMonth,
      endYear: endYear,
      endMonth: endMonth,
    );

void main() {
  test('월회비 계속은 시작 이후 모든 달이 대상이다', () {
    final s = monthly();
    expect(s.isActiveForYearMonth(2026, 2), isFalse);
    expect(s.isActiveForYearMonth(2026, 3), isTrue);
    expect(s.isActiveForYearMonth(2027, 1), isTrue);
    expect(s.isActiveForYearMonth(2027, 2), isTrue);
    expect(s.canNavigateDuesPrev(2026, 3), isFalse);
    expect(s.canNavigateDuesNext(2026, 3), isTrue);
    expect(s.canNavigateDuesPrev(2027, 1), isTrue);
    expect(s.canNavigateDuesNext(2027, 2), isTrue);
    expect(s.clampDuesView(2026, 2), (year: 2026, month: 3));
    expect(s.clampDuesView(2027, 1), (year: 2027, month: 1));
  });

  test('월회비 종료가 있으면 그 기간만 이동한다', () {
    final s = monthly(endYear: 2026, endMonth: 12);
    expect(s.isActiveForYearMonth(2026, 2), isFalse);
    expect(s.isActiveForYearMonth(2026, 3), isTrue);
    expect(s.isActiveForYearMonth(2026, 12), isTrue);
    expect(s.isActiveForYearMonth(2027, 1), isFalse);
    expect(s.canNavigateDuesPrev(2026, 3), isFalse);
    expect(s.canNavigateDuesNext(2026, 12), isFalse);
    expect(s.canNavigateDuesPrev(2026, 12), isTrue);
    expect(s.canNavigateDuesNext(2026, 3), isTrue);
    expect(s.clampDuesView(2026, 2), (year: 2026, month: 3));
    expect(s.clampDuesView(2027, 1), (year: 2026, month: 12));
  });

  test('특별회비는 납부 기준일 그 달만 고정이다', () {
    final s = DuesSetting(
      id: 'sp',
      type: DuesType.special,
      amount: 50000,
      title: '여행 특별회비',
      createdAt: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 6, 15),
    );
    expect(s.pinnedDueYear, 2026);
    expect(s.pinnedDueMonth, 6);
    expect(s.canNavigateDuesPrev(2026, 6), isFalse);
    expect(s.canNavigateDuesNext(2026, 6), isFalse);
  });
}
