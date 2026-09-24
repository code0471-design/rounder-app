import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String relative) => File(relative).readAsStringSync();

void main() {
  test('카탈로그 수정은 폰이 준 member_count 를 쓰지 않는다', () {
    final src = _read(
        'lib/data/datasources/firestore/firestore_club_datasource.dart');
    expect(src.contains("if (memberCount != null) data['member_count']"),
        isFalse);
    expect(src.contains('removeOfficialMembership'), isTrue);
  });

  test('초대·승인은 increment 가 아니라 멤버십을 다시 센다', () {
    final invite = _read(
        'lib/data/datasources/firestore/firestore_club_datasource.dart');
    final approve = _read(
        'lib/data/datasources/firestore/firestore_join_request_datasource.dart');
    expect(invite.contains('recountClubMemberCount(_db, clubId)'), isTrue);
    expect(approve.contains('recountClubMemberCount(_db, clubId)'), isTrue);
    expect(invite.contains('FieldValue.increment'), isFalse);
    expect(approve.contains('FieldValue.increment'), isFalse);
  });
}
