import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 일정 등록 시 등록자 본인에게도 푸시·알림톡이 가도록 유지.
void main() {
  test('일정 등록 HQ 푸시는 등록자 본인 enqueue를 켠다', () {
    final src = File('lib/providers/club_provider.dart').readAsStringSync();
    expect(src.contains('notifySelf: true'), isTrue);
    expect(src.contains('_scheduleBroadcastUserIds()'), isTrue);
    expect(
      src.contains('bool notifySelf = false'),
      isTrue,
    );
  });

  test('일정 등록 알림톡 다이얼로그는 등록자를 제외하지 않는다', () {
    final src =
        File('lib/screens/schedule/schedule_screen.dart').readAsStringSync();
    expect(
      src.contains("m.id != provider.currentUserId"),
      isFalse,
      reason: '알림톡 대상에서 등록자 본인을 다시 빼고 있음',
    );
  });
}
