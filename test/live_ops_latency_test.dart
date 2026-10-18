import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('참석 버튼은 서버 자리잡기를 기다리지 않고 화면에 먼저 반영한다', () {
    final src = File('lib/providers/club_provider.dart').readAsStringSync();
    final live = src.indexOf('Future<bool> respondToScheduleLive');
    final confirm = src.indexOf('Future<void> _confirmClaimedSeat');
    expect(live, greaterThan(0));
    expect(confirm, greaterThan(live));
    final liveBody = src.substring(live, confirm);
    expect(liveBody.contains('unawaited(_confirmClaimedSeat'), isTrue);
    expect(liveBody.contains('await ClubOpsSync.claimScheduleSeat'), isFalse,
        reason: '자리잡기를 기다리면 참석 버튼이 몇 분씩 안 바뀐다');
  });

  test('실시간 구독은 사진 전체를 다시 받지 않고 연도 일정을 본다', () {
    final src = File('lib/services/club_ops_sync.dart').readAsStringSync();
    expect(src.contains('_syncSidecarWatches'), isTrue);
    expect(src.contains('clubOpsScheduleYear'), isTrue);
    final watch = src.indexOf('static void watchClub(');
    final stop = src.indexOf('static void stopWatchClub(');
    final body = src.substring(watch, stop);
    expect(body.contains('clubPhotos'), isFalse,
        reason: '번들이 바뀔 때마다 사진을 다시 받으면 참석·일정이 늦다');
  });

  test('저장 중인 동안 참석을 눌러도 나중에 서버에 올린다', () {
    final src = File('lib/providers/club_provider.dart').readAsStringSync();
    expect(src.contains('_persistQueuedDuringApply'), isTrue);
  });
}
