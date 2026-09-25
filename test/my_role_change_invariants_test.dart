import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('직책 칩은 명단 직책으로 열고, 일반 회원으로 바꿨다고 임원 칩을 숨기지 않는다', () {
    final src = read('lib/screens/members/my_role_change_screen.dart');
    expect(src.contains('myDisplayRoleFor'), isTrue);
    expect(src.contains('_officerEligibleClubIds'), isTrue);
    expect(src.contains('canPickOfficer = ClubMemberRole.isOfficer(club.myRole)'),
        isFalse);
  });

  test('직책 저장은 로컬만이 아니라 그 모임 서버 명단에도 남긴다', () {
    final src = read('lib/providers/club_provider.dart');
    expect(src.contains('setMyRoleForClub'), isTrue);
    expect(src.contains('ClubOpsSync.upsertMemberRole'), isTrue);
    expect(src.contains('ClubOpsSync.pushClubOps'), isTrue);
    expect(
      src.contains('생성자인데 양쪽 다 임원이 아니면 회장·총무로 되돌린다'),
      isFalse,
      reason: '생성자가 일반 회원으로 저장한 뒤 페이지를 나가면 회장·총무로 되돌아가던 버그',
    );
  });

  test('서버 직책 쓰기는 있는 명단 문서만 고친다', () {
    final src = read('lib/services/club_ops_sync.dart');
    expect(src.contains('upsertMemberRole'), isTrue);
    expect(src.contains("if (!snap.exists) continue"), isTrue);
    expect(src.contains('userMembershipDoc'), isTrue);
  });
}
