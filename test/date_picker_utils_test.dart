import 'dart:io';

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

  test('일정 날짜 달력은 세로 스크롤이고 시계 다이얼이 없다', () {
    final source = File('lib/utils/date_picker_utils.dart').readAsStringSync();
    expect(source.contains('class _VerticalMonthCalendar'), isTrue);
    expect(source.contains('ListView.builder'), isTrue);
    expect(source.contains('PageView'), isFalse,
        reason: '가로로 밀어서 넘기는 달력이면 안 된다');
    expect(source.contains('CalendarDatePicker'), isFalse);
    expect(source.contains('showTimePicker'), isFalse);
    expect(source.contains('for (var h = 0; h <= 23; h++)'), isTrue);
    expect(source.contains('for (var m = 0; m <= 59; m++)'), isTrue);
    expect(
      source.contains('[0, 10, 20, 30, 40, 50]'),
      isFalse,
      reason: '10분 단위만 있으면 8:36을 못 넣는다',
    );
  });
}
