import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 조편성 참석 인원 — 열린 시점 스냅샷이 아니라 provider 최신 schedule을 써야 한다.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/group_assignment/group_assignment_screen.dart')
        .readAsStringSync();
  });

  test('참석자 목록은 scheduleById 기준이어야 한다', () {
    expect(source.contains('provider.scheduleById(widget.schedule.id)'), isTrue);
    expect(source.contains('widget.schedule.responses'), isFalse,
        reason: '스냅샷 responses를 쓰면 참석/불참 후 조편성 인원이 어긋난다');
  });
}
