import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String room;
  late String provider;

  setUpAll(() {
    room = File('lib/screens/club_room/club_room_screen.dart').readAsStringSync();
    provider = File('lib/providers/club_provider.dart').readAsStringSync();
  });

  test('홈 다음 일정·참석현황은 원클럽형 카드다', () {
    expect(room.contains("'다음 일정'"), isTrue);
    expect(room.contains("'자세히 보기'"), isTrue);
    expect(room.contains('예정된 모임이 없습니다'), isTrue);
    expect(room.contains("'참석 응답 · 명단 보기 >'"), isTrue);
    expect(room.contains('upcomingSchedules.isNotEmpty'), isTrue);
  });

  test('홈 현 회비 잔고는 월회비·연회비를 다르게 보여 준다', () {
    expect(room.contains('currentHomeDuesSetting'), isTrue);
    expect(room.contains('previousMonthUnpaidCount'), isTrue);
    expect(room.contains("isMonthly ? '이달 \${homeDues.title}' : homeDues.title"), isTrue);
    expect(room.contains("'전월 미납 \$prevUnpaid명'"), isTrue);
    expect(room.contains("'회비 미설정'"), isTrue);
    expect(room.contains("'이달 회비 납부'"), isFalse);
    expect(provider.contains('DuesSetting? currentHomeDuesSetting'), isTrue);
    expect(provider.contains('if (clubPrimaryDuesType != DuesType.monthly) return 0;'), isTrue);
  });
}
