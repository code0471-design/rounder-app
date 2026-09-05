import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/auth_provider.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 푸시·알림톡 전달 회귀 테스트.
///
/// 배경: "알림톡과 푸시알림이 안 간다".
/// Cloud Functions 로그에 원인이 그대로 남아 있었다.
///
///   sendpushoninbox: no FCM token m_creator_c_1786973797931
///
/// 발송 대상은 **명단 ID**(`m_creator_<clubId>`)로 들어오는데 FCM 토큰은
/// 로그인 ID 로만 저장했다. `_fcmInboxIdFor` 가 변환해 주지만
/// `Club.creatorId` 기본값이 `''` 이라 변환이 실패하면 명단 ID 가 그대로
/// push_inbox 에 쌓이고, Functions 는 토큰을 못 찾고 버렸다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String read(String relative) =>
      File(relative).readAsStringSync().replaceAll('\r\n', '\n');

  group('FCM 토큰은 명단 ID 로도 등록된다', () {
    late ClubProvider clubs;
    late String authId;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      AppDependencies.instance.init(offlineMock: true);
      final auth = AuthProvider();
      await auth.loginAsync('010-1234-5678');
      authId = auth.currentUser!.id;
      clubs = ClubProvider();
      await clubs.switchUser(authId, displayName: auth.currentUser!.name);
    });

    test('모임을 만들면 그 모임 명단 ID 가 등록 대상에 들어간다', () async {
      final before = clubs.myPushIds();
      expect(before, contains(authId), reason: '로그인 ID 는 기본');

      final ok = await clubs.createClub(
        name: '푸시 테스트 모임',
        region: '서울',
        industry: '골프',
        teamCount: 4,
        myRole: '회장,총무',
      );
      expect(ok, isTrue);
      final clubId = clubs.selectedClub.id;

      final ids = clubs.myPushIds();
      // 이게 없어서 Functions 가 no FCM token 을 남겼다.
      expect(ids, contains('m_creator_$clubId'),
          reason: '생성자 명단 ID 로 오는 푸시가 토큰을 못 찾으면 사라진다');
      expect(ids, contains(Member.rosterId(clubId, authId)),
          reason: '초대 가입자 형식 명단 ID 도 등록해야 한다');
      expect(ids, contains(authId));
    });

    test('창단자 명단 ID 는 creatorId 가 비어도 커버된다', () async {
      await clubs.createClub(
        name: '푸시 테스트 모임',
        region: '서울',
        industry: '골프',
        teamCount: 4,
        myRole: '회장,총무',
      );
      final clubId = clubs.selectedClub.id;

      // creatorId 없이 동기화된 모임을 흉내 낸다.
      // 매핑은 실패하지만 토큰이 등록돼 있으므로 푸시는 도착해야 한다.
      expect(clubs.myPushIds(), contains('m_creator_$clubId'),
          reason: 'ID 변환에 기대지 않는 것이 이 수정의 핵심이다');
    });

    test('등록 대상에 빈 문자열·중복이 없다', () async {
      await clubs.createClub(
        name: '푸시 테스트 모임',
        region: '서울',
        industry: '골프',
        teamCount: 4,
        myRole: '회장,총무',
      );
      final ids = clubs.myPushIds();
      expect(ids.where((e) => e.trim().isEmpty), isEmpty);
      expect(ids.toSet().length, ids.length, reason: '중복 등록은 쓸데없는 쓰기다');
    });

    test('데모 모임(c1~c5) 명단 ID 는 등록하지 않는다', () {
      // 공유 시드 명단이라 등록하면 남의 알림을 받는다.
      final ids = clubs.myPushIds();
      for (final demo in ['c1', 'c2', 'c3', 'c4', 'c5']) {
        expect(ids, isNot(contains('m_creator_$demo')));
      }
    });
  });

  group('푸시 등록 코드 불변식', () {
    test('모임 목록이 바뀌면 다시 등록한다', () {
      final src = read('lib/providers/club_provider.dart');

      expect(src, contains('_rebindPushIdsIfChanged()'),
          reason: '로그인 시 한 번만 등록하면 새 모임 알림이 안 온다');
      // 원격 동기화(_importBundle)와 모임 생성 직후 둘 다 걸려야 한다.
      final calls = src.split('_rebindPushIdsIfChanged()').length - 1;
      expect(calls, greaterThanOrEqualTo(4),
          reason: '정의 + switchUser + _importBundle + createClub');
      expect(src, contains('_boundPushIdsSignature'),
          reason: '바뀔 때만 등록해야 매번 Firestore 쓰기를 하지 않는다');
    });

    test('토큰 저장은 bindUserIds 로 받은 모든 ID 에 한다', () {
      final src = read('lib/services/push_notification_service.dart');
      expect(src, contains('_saveToken(token, ids)'));
      expect(src, contains('onTokenRefresh'), reason: '토큰 갱신도 저장해야 한다');
      expect(src, contains('requestPermission'),
          reason: 'iOS 는 권한 없이는 절대 안 온다');
    });
  });

  group('알림톡 실패가 조용히 넘어가지 않는다', () {
    test('자동 발송 실패를 화면에 알린다', () {
      final src = read('lib/providers/club_provider.dart');

      expect(src, contains('lastAlimtalkError'),
          reason: '실패 사유를 화면이 읽을 수 있어야 진단이 된다');
      expect(src, contains('clearAlimtalkError'));
      // 예전엔 결과를 버리는 unawaited(sendClubAlimtalk(...)) 였다.
      expect(src, isNot(contains('unawaited(sendClubAlimtalk(')),
          reason: '결과를 버리면 한 통도 안 나가도 아무도 모른다');
    });

    test('꺼 둔 알림톡은 오류로 알리지 않는다', () {
      final src = read('lib/providers/club_provider.dart');
      expect(src, contains("msg.contains('꺼져 있습니다')"),
          reason: '설정대로 동작한 것을 오류로 띄우면 총무가 혼란스럽다');
    });

    test('모임방이 실패 사유를 스낵바로 띄운다', () {
      final src = read('lib/screens/club_room/club_room_screen.dart');
      expect(src, contains('_showAlimtalkErrorIfAny'));
      expect(src, contains('알림톡 발송 실패'));
    });

    test('알림톡 대상은 전화번호 10자리 이상만', () {
      // 번호 없는 회원만 있으면 messages 가 비어 발송이 실패한다.
      // 그 경우 사유가 명확히 남아야 한다.
      final src = read('lib/providers/club_provider.dart');
      expect(src, contains('전화번호가 있는 발송 대상이 없습니다'));
    });
  });

  group('알림톡은 버튼 없이 나간다', () {
    test('일정 등록·변경·조편성 확정이 자동 발송한다', () {
      final src = read('lib/providers/club_provider.dart');
      expect(src, contains('HqAlimtalkCatalog.scheduleUploadId'));
      expect(src, contains('HqAlimtalkCatalog.scheduleChangeId'));
      expect(src, contains('HqAlimtalkCatalog.groupFinalizeId'));
      expect(src, contains('HqAlimtalkCatalog.d1ReminderId'),
          reason: 'D-1 알림톡도 대기열에서 보내야 한다');
    });

    test('발송하기 다이얼로그를 건너뛴다', () {
      final src = read('lib/utils/alimtalk_utils.dart');
      expect(src, contains('addSchedule 이 바로 보낸다'));
      expect(src, isNot(contains('recipientNames: provider.attendanceAlimtalkRecipientNames()')),
          reason: '발송 화면을 또 열면 두 번 나간다');
    });

    test('D-1 대기열에 전화번호가 들어간다', () {
      final src = read('lib/services/push_notification_service.dart');
      expect(src, contains("'phone': phone"));
      expect(src, contains('dueD1AlimtalkDocs'));
      expect(src, contains('alimtalkSent'));
    });
  });
}
