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

  test('홈 참석 현황은 게스트를 미답변에서 빼지 않는다', () {
    final home = read('lib/screens/club_room/club_room_screen.dart');
    expect(
      home.contains('prov.regularMembers'),
      isFalse,
      reason: '홈 참석 현황 미답변에서 게스트를 빼면 안 된다',
    );
    expect(home.contains('roster.where((m) => !respondedIds.contains(m.id))'), isTrue);
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
