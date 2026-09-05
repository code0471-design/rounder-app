import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 일정 등록 시 등록자 본인에게도 푸시·알림톡이 가도록 유지.
void main() {
  late String src;

  setUpAll(() {
    src = File('lib/providers/club_provider.dart').readAsStringSync();
  });

  test('일정 등록 HQ 푸시는 등록자 본인 enqueue를 켠다', () {
    expect(src.contains('notifySelf: true'), isTrue);
    expect(src.contains('_fcmInboxIdFor'), isTrue,
        reason: '명단 ID(m_creator_*)를 FCM 로그인 ID로 바꿔야 본인 폰에 푸시가 간다');
    expect(
      src.contains('bool notifySelf = false'),
      isTrue,
    );
  });

  test('어드민 7종 푸시는 본인 포함 + FCM 로그인 ID로 보낸다', () {
    expect(src.contains('HqPushCatalog.joinRequest'), isTrue);
    expect(src.contains('HqPushCatalog.joinResult'), isTrue);
    expect(src.contains('HqPushCatalog.scheduleConfirm'), isTrue);
    expect(src.contains('HqPushCatalog.duesRequest'), isTrue);
    expect(src.contains('HqPushCatalog.scheduleCancel'), isTrue);
    expect(src.contains('HqPushCatalog.duesNudge'), isTrue);
    expect(src.contains('userId: _fcmInboxIdFor(memberId)'), isTrue,
        reason: 'D-1 리마인더는 명단 ID가 아니라 FCM 로그인 ID로 예약해야 한다');
    expect(src.contains('final fcmId = _fcmInboxIdFor(id);'), isTrue,
        reason: 'HQ 푸시 대상 ID를 FCM 키로 바꿔야 한다');
    expect(src.contains('hqPushTypeId: HqPushCatalog.duesNudge') ||
            src.contains('typeId: HqPushCatalog.duesNudge'),
        isTrue);
    final selfCount = 'notifySelf: true'.allMatches(src).length;
    expect(selfCount, greaterThanOrEqualTo(7),
        reason: '7종 푸시에서 총무/등록자 본인 skip이 다시 켜지면 안 된다');
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
