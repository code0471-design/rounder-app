import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('본사 회원 상세에 인증 초기화가 있어야 한다', () {
    final members =
        File('lib/screens/admin/admin_members_screen.dart').readAsStringSync();
    expect(members.contains('인증 초기화'), isTrue);
    expect(members.contains('resetMemberPhoneAuth'), isTrue);
  });

  test('소셜 로그인은 Firestore 번호가 비어 있으면 인증 화면을 건너뛰지 않는다', () {
    final auth = File('lib/providers/auth_provider.dart').readAsStringSync();
    expect(auth.contains('remoteUserRead'), isTrue);
    expect(auth.contains('본사 인증 초기화'), isTrue);
  });

  test('어드민은 users.phone을 지운다', () {
    final ds = File('lib/data/datasources/firestore/firestore_admin_datasource.dart')
        .readAsStringSync();
    expect(ds.contains('resetMemberPhoneAuth'), isTrue);
    expect(ds.contains("'phone': FieldValue.delete()"), isTrue);
  });
}
