import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/utils/date_picker_utils.dart';

void main() {
  test('티오프 분은 8:36처럼 그대로 둔다', () {
    expect(snapTeeMinute(36), 36);
    expect(snapTeeMinute(0), 0);
    expect(snapTeeMinute(7), 7);
    expect(snapTeeMinute(59), 59);
    expect(clampTeeMinute(80), 59);
  });

  test('오전 오후와 12시간은 24시간과 맞는다', () {
    expect(hour12From24(0), 12);
    expect(hour12From24(7), 7);
    expect(hour12From24(12), 12);
    expect(hour12From24(13), 1);
    expect(hour12From24(19), 7);
    expect(isAfternoonHour(7), isFalse);
    expect(isAfternoonHour(12), isTrue);
    expect(hour24From12(hour12: 7, isPm: false), 7);
    expect(hour24From12(hour12: 7, isPm: true), 19);
    expect(hour24From12(hour12: 12, isPm: false), 0);
    expect(hour24From12(hour12: 12, isPm: true), 12);
    expect(formatTeeTimeKo(7, 30), '오전 7:30');
    expect(formatTeeTimeKo(19, 36), '오후 7:36');
    expect(formatTeeTimeKo(0, 5), '오전 12:05');
    expect(formatTeeTimeKo(12, 0), '오후 12:00');
    expect(formatStoredTeeTimeKo('07:30'), '오전 7:30');
    expect(formatStoredTeeTimeKo('19:36'), '오후 7:36');
    expect(formatStoredTeeTimeKo(''), '');
  });

  test('달력 스크롤은 오늘이 속한 달 위치다', () {
    final now = DateTime(2026, 9, 25);
    final first = DateTime(now.year - 2, 1, 1);
    final last = now.add(const Duration(days: 365));
    final months = monthListForPicker(first, last);
    expect(months.first, DateTime(2024, 1));
    expect(
      months.any((m) => m.year == 2026 && m.month == 9),
      isTrue,
    );
    final offset = rounderMonthScrollOffset(
      firstDate: first,
      lastDate: last,
      initialDate: now,
    );
    final index = months.indexWhere((m) => m.year == 2026 && m.month == 9);
    expect(index, greaterThan(0));
    expect(offset, index * kRounderMonthBlockExtent);
    expect(offset, isNot(0), reason: '2년 전 1월에 머무르면 안 된다');
  });

  test('일정 날짜 달력은 세로 스크롤이고 시계 다이얼이 없다', () {
    final source = File('lib/utils/date_picker_utils.dart').readAsStringSync();
    expect(source.contains('class _VerticalMonthCalendar'), isTrue);
    expect(source.contains('ListView.builder'), isTrue);
    expect(source.contains('itemExtent: kRounderMonthBlockExtent'), isTrue);
    expect(source.contains('318.0'), isFalse,
        reason: '달마다 높이가 다른데 318로 점프하면 다른 달이 열린다');
    expect(source.contains('PageView'), isFalse,
        reason: '가로로 밀어서 넘기는 달력이면 안 된다');
    expect(source.contains('CalendarDatePicker'), isFalse);
    expect(source.contains('showTimePicker'), isFalse);
    expect(source.contains("'오전'"), isTrue);
    expect(source.contains("'오후'"), isTrue);
    expect(source.contains('for (var h = 0; h <= 23; h++)'), isFalse,
        reason: '24시간 칩은 오전·오후 12시간으로 나눈다');
    expect(source.contains('itemCount: 60'), isTrue);
    expect(
      source.contains('[0, 10, 20, 30, 40, 50]'),
      isFalse,
      reason: '10분 단위만 있으면 8:36을 못 넣는다',
    );
  });

  testWidgets('달력은 오늘이 속한 달을 열고 2년 전 1월을 맨 위에 두지 않는다',
      (tester) async {
    final now = DateTime.now();
    final first = DateTime(now.year - 2, 1, 1);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              showRounderDatePicker(
                context: context,
                initialDate: DateTime(now.year, now.month, now.day),
                firstDate: first,
                lastDate: now.add(const Duration(days: 365)),
                helpText: '라운딩 날짜',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('${now.year}년 ${now.month}월'), findsOneWidget);
    if (first.year != now.year || first.month != now.month) {
      expect(find.text('${first.year}년 ${first.month}월'), findsNothing);
    }
    expect(find.text('${now.day}'), findsWidgets);
  });

  testWidgets('시간 선택은 오전 오후를 바꾸고 분은 그대로 고른다', (tester) async {
    TimeOfDay? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked = await showRounderTimePicker(
                context: context,
                initialTime: const TimeOfDay(hour: 7, minute: 30),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('오전 7:30'), findsOneWidget);
    expect(find.text('오전'), findsWidgets);
    expect(find.text('오후'), findsWidgets);
    expect(find.byKey(const Key('tee_minute_grid')), findsOneWidget);
    await tester.tap(find.text('오후'));
    await tester.pump();
    expect(find.text('오후 7:30'), findsOneWidget);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(picked?.hour, 19);
    expect(picked?.minute, 30);
  });
}
