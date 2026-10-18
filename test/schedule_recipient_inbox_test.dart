import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 일정 등록 알림은 올린 사람이 아니라 받는 사람 알림함에 남아야 한다.
void main() {
  test('일정 등록 푸시는 받는 사람 계정 알림함에도 남긴다', () {
    final src = File('lib/providers/club_provider.dart').readAsStringSync();
    expect(src.contains('ClubOpsSync.appendApplicantInbox'), isTrue,
        reason: 'FCM만 보내면 받는 사람 알림 아이콘이 비어 있다');
    expect(src.contains('if (!isSelf)'), isTrue);
    expect(src.contains('ingestRemotePushInbox'), isTrue,
        reason: '이미 받은 푸시함 건도 알림 아이콘에 넣어야 한다');
    expect(src.contains('enqueuePush: false'), isTrue,
        reason: '수신함에서 다시 enqueue 하면 푸시가 한 번 더 간다');
    expect(src.contains('PushNotificationService.onInboxItem'), isTrue);
  });

  test('푸시 수신함은 최신 순으로 읽고 알림 아이콘에 넘긴다', () {
    final pushSrc =
        File('lib/services/push_notification_service.dart').readAsStringSync();
    expect(pushSrc.contains('onInboxItem'), isTrue);
    expect(pushSrc.contains("orderBy('createdAt', descending: true)"), isTrue,
        reason: '수신함 20개를 문서 id 로 자르면 새 일정 알림이 빠진다');
    expect(pushSrc.contains('.limit(40)'), isTrue);
  });
}
