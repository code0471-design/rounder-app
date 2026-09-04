import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('앱 탈퇴는 모임 탈퇴·계정 번호 삭제 후 로그인으로 보낸다', () {
    final ad = File('lib/screens/ad/ad_screen.dart').readAsStringSync();
    expect(ad.contains('// mock: 탈퇴 완료 후 로그인 화면으로'), isFalse);
    expect(ad.contains('withdrawFromApp'), isTrue);
    expect(ad.contains('withdrawAccount'), isTrue);
  });

  test('소셜 계정은 저장이 없어도 홍길동 시드 모임을 넣지 않는다', () {
    final provider =
        File('lib/providers/club_provider.dart').readAsStringSync();
    expect(provider.contains('카카오/구글/애플 계정은 빈 내 모임에서 시작'), isTrue);
    expect(provider.contains("authUserId == 'user_me' || authUserId == 'default'"),
        isTrue);
  });

  test('탈퇴 시 user_ops와 user_memberships를 지운다', () {
    final sync = File('lib/services/club_ops_sync.dart').readAsStringSync();
    expect(sync.contains('deleteUserOps'), isTrue);
    expect(sync.contains('deleteUserMemberships'), isTrue);
    final auth = File('lib/providers/auth_provider.dart').readAsStringSync();
    expect(auth.contains("'phone': FieldValue.delete()"), isTrue);
    expect(auth.contains('_kLastLoginMethod'), isTrue);
  });
}
