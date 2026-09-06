import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/utils/past_schedule_import.dart';

void main() {
  test('제목의 월로 지난 날짜를 만든다', () {
    final d = PastScheduleImport.resolveRoundDate(
      title: '3월 월례회',
      now: DateTime(2026, 9, 6),
    );
    expect(d, DateTime(2026, 3, 15));
  });

  test('아직 안 온 달은 작년으로 넣는다', () {
    final d = PastScheduleImport.resolveRoundDate(
      title: '12월 모임',
      now: DateTime(2026, 6, 1),
    );
    expect(d, DateTime(2025, 12, 15));
  });

  test('기억나는 날짜가 있으면 그 날짜를 쓴다', () {
    final d = PastScheduleImport.resolveRoundDate(
      title: '봄맞이',
      roundDate: DateTime(2026, 4, 12),
      now: DateTime(2026, 9, 6),
    );
    expect(d, DateTime(2026, 4, 12));
  });

  test('일정 일괄 등록은 임원 전용이고 알림톡을 보내지 않는다', () {
    final provider =
        File('lib/providers/club_provider.dart').readAsStringSync();
    final start = provider.indexOf('bool importPastSchedule(');
    final end = provider.indexOf('List<String> _scheduleBroadcastUserIds', start);
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    final fn = provider.substring(start, end);
    expect(fn.contains('canCreateSchedule'), isTrue);
    expect(fn.contains('ScheduleStatus.done'), isTrue);
    expect(fn.contains('_syncAttendancePoints'), isTrue);
    expect(fn.contains('_awardRecords.addAll'), isTrue);
    expect(fn.contains('_persistImmediately()'), isTrue);
    expect(fn.contains('_dispatchClubAlimtalk'), isFalse);
    expect(fn.contains('_notifyHqPush'), isFalse);
    expect(fn.contains('adminSetAttendance'), isFalse);
  });

  test('일정 탭에 처음 사용자 안내가 있다', () {
    final tab =
        File('lib/screens/schedule/schedule_screen.dart').readAsStringSync();
    final flow = File('lib/screens/schedule/past_schedule_import_screen.dart')
        .readAsStringSync();
    expect(tab.contains('PastScheduleImportBanner'), isTrue);
    expect(tab.contains('if (isAdmin)'), isTrue);
    expect(flow.contains("'앱이 처음이신가요?'"), isTrue);
    expect(flow.contains('올해 이미 지난 일정을 일괄로 등록할 수 있습니다'), isTrue);
    expect(flow.contains("'다음 일정 이어서 넣기'"), isTrue);
    expect(flow.contains('잘 모르겠어요, 건너뛰기'), isTrue);
    expect(flow.contains("'일정 이름은 꼭 적어 주세요'"), isTrue);
  });
}
