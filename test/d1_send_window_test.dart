import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/utils/d1_send_window.dart';

void main() {
  final sendOn = DateTime(2026, 9, 24);

  test('10시 전에는 예약하고 오후에 즉시 보내지 않는다', () {
    final morning = DateTime(2026, 9, 24, 9, 40);
    expect(D1SendWindow.shouldReserve(morning, sendOn), isTrue);
    expect(D1SendWindow.shouldSendNow(morning, sendOn), isFalse);
    expect(D1SendWindow.shouldSkipAsMissed(morning, sendOn), isFalse);
  });

  test('10시 직후 20분만 미예약분을 즉시 보낸다', () {
    final justAfter = DateTime(2026, 9, 24, 10, 12);
    expect(D1SendWindow.shouldSendNow(justAfter, sendOn), isTrue);
    expect(D1SendWindow.shouldReserve(justAfter, sendOn), isFalse);
    expect(D1SendWindow.shouldSkipAsMissed(justAfter, sendOn), isFalse);
  });

  test('오후 1시 52분에 회비 알림톡을 따라 보내지 않는다', () {
    final afternoon = DateTime(2026, 9, 24, 13, 52);
    expect(D1SendWindow.shouldSendNow(afternoon, sendOn), isFalse);
    expect(D1SendWindow.shouldReserve(afternoon, sendOn), isFalse);
    expect(D1SendWindow.shouldSkipAsMissed(afternoon, sendOn), isTrue);
  });
}
