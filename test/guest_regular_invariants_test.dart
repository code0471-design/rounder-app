import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('정회원 전환은 서버 명단 member_type·regular_since 를 남긴다', () {
    final src = read('lib/providers/club_provider.dart');
    expect(src.contains('_persistMemberTypeToServer'), isTrue);
    expect(src.contains('clearRegularSince'), isTrue);
    expect(src.contains('joinDate: prev.joinDate'), isTrue);

    final mapper = read('lib/data/mappers/member_mapper.dart');
    expect(mapper.contains('regular_since'), isTrue);

    final ops = read('lib/services/club_ops_sync.dart');
    expect(ops.contains('regular_since'), isTrue);
    expect(ops.contains('writeTypePairInto'), isTrue);
    expect(ops.contains('FieldValue.delete()'), isTrue);
  });

  test('회비는 regular_since 가 있으면 그 달부터다', () {
    final dues = read('lib/utils/dues_period_eligibility.dart');
    expect(dues.contains('duesStart'), isTrue);
    expect(dues.contains('regularSince ?? member.joinDate'), isTrue);
  });

  test('일정 등록 알림톡은 정회원 수만 안내한다', () {
    final schedule = read('lib/screens/schedule/schedule_screen.dart');
    expect(schedule.contains('provider.regularMembers.length'), isTrue);
    expect(
      schedule.contains("m.status == '활성').length"),
      isFalse,
      reason: '게스트까지 세면 참석여부 요청 인원이 커진다',
    );
  });

  test('홈·일정 미답변은 정회원만 센다', () {
    final tally = read('lib/domain/services/round_attendance.dart');
    expect(tally.contains('!guestIds.contains(id) && !answered.contains(id)'),
        isTrue);
    expect(
      tally.contains('미답변은 정회원만'),
      isTrue,
      reason: '게스트는 신청할 수 있어도 미답변 대상이 아니다',
    );
  });

  test('초대 링크는 게스트/정회원을 읽고 가입신청으로 바꾸지 않는다', () {
    final deep = read('lib/services/deep_link_service.dart');
    expect(deep.contains('InviteMemberType.parse'), isTrue);

    final landing = read('lib/screens/invite/invite_landing_screen.dart');
    expect(landing.contains('joinViaInvite'), isTrue);
    expect(landing.contains('submitJoinRequest'), isFalse);

    final golf = read('lib/screens/auth/golf_profile_screen.dart');
    expect(golf.contains('DeepLinkService.instance.onAppReady()'), isTrue);

    final login = read('lib/screens/auth/login_screen.dart');
    expect(login.contains('DeepLinkService.instance.onAppReady()'), isTrue);

    final phone = read('lib/screens/auth/phone_required_screen.dart');
    expect(phone.contains('DeepLinkService.instance.onAppReady()'), isTrue);
  });
}
