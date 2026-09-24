import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/utils/date_picker_utils.dart';

void main() {
  test('티오프 분은 10분 단위로만 맞춘다', () {
    expect(snapTeeMinute(30), 30);
    expect(snapTeeMinute(0), 0);
    expect(snapTeeMinute(7), 10);
    expect(snapTeeMinute(14), 10);
    expect(snapTeeMinute(55), 50);
  });

  test('일정 날짜 달력은 세로 스크롤이고 시계 다이얼이 없다', () {
    final source = File('lib/utils/date_picker_utils.dart').readAsStringSync();
    expect(source.contains('class _VerticalMonthCalendar'), isTrue);
    expect(source.contains('ListView.builder'), isTrue);
    expect(source.contains('PageView'), isFalse,
        reason: '가로로 밀어서 넘기는 달력이면 안 된다');
    expect(source.contains('CalendarDatePicker'), isFalse);
    expect(source.contains('showTimePicker'), isFalse);
    expect(source.contains('kTeeTimeMinuteSteps'), isTrue);
    expect(source.contains('for (var h = 0; h <= 23; h++)'), isTrue);
    expect(
      source.contains('[0, 10, 20, 30, 40, 50]'),
      isTrue,
    );
  });
}
