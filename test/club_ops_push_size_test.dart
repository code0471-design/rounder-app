import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/services/club_ops_sync.dart';

/// 모임 운영 데이터(일정·회비·명단)가 한 건도 서버에 안 올라가던 원인.
/// 푸시 직전 크기를 재려고 jsonEncode 를 돌리는데, 거기에
/// `FieldValue.serverTimestamp()` 가 들어 있어 예외가 났고 push 전체가 죽었다.
/// 일정이 등록한 사람 폰에만 남아 있던 이유다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('JSON 으로 못 바꾸는 값이 섞여도 크기 측정은 예외를 안 낸다', () {
    expect(
      () => ClubOpsSync.estimateJsonBytes({
        'updatedAt': FieldValue.serverTimestamp(),
        'schedules': const [],
      }),
      returnsNormally,
    );
    expect(
      ClubOpsSync.estimateJsonBytes({'a': 1, 'b': 'x'}),
      greaterThan(0),
    );
  });

  test('serverTimestamp 는 크기를 잰 뒤, 쓰기 직전에 넣는다', () {
    final src = File('lib/services/club_ops_sync.dart').readAsStringSync();
    final start = src.indexOf('static Future<void> pushClubOps(');
    expect(start, greaterThan(0));
    final push = src.substring(start, start + 6000);

    final measure = push.indexOf('estimateJsonBytes(slice)');
    final stamp =
        push.indexOf("slice['updatedAt'] = FieldValue.serverTimestamp()");
    final write = push.indexOf('.set(slice');

    expect(measure, greaterThan(0));
    expect(stamp, greaterThan(measure),
        reason: '측정 전에 넣으면 jsonEncode 가 터져 모임 데이터가 안 올라간다');
    expect(write, greaterThan(stamp));
  });
}
