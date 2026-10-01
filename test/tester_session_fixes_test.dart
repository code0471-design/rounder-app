import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('승인은 서버 저장이 끝나기 전에 화면을 닫는다', () {
    final src = read('lib/providers/club_provider.dart');
    final fn = src.substring(
      src.indexOf('Future<bool> approveRequest('),
      src.indexOf('Future<void> _persistApprovedJoin('),
    );
    expect(fn.contains('notifyListeners();'), isTrue);
    expect(fn.contains('await _persistApprovedJoin'), isFalse);
    expect(fn.contains('Duration(seconds: 12)'), isTrue);
    final notifyAt = fn.lastIndexOf('notifyListeners();');
    final persistAt = fn.indexOf('_persistApprovedJoin(');
    expect(notifyAt, lessThan(persistAt));
  });

  test('게스트 추천인은 그 모임 정회원이다', () {
    final src = read('lib/screens/invite/guest_invite_form_screen.dart');
    expect(src.contains('membersForClub(widget.club.id)'), isTrue);
    expect(src.contains("m.memberType != '게스트'"), isTrue);
    expect(src.contains('.regularMembers'), isFalse);
  });

  test('내 참석은 명단 id와 로그인 id를 같이 찾는다', () {
    final src = read('lib/providers/club_provider.dart');
    expect(src.contains('bool _isMyAttendanceMemberId('), isTrue);
    final fn = src.substring(
      src.indexOf('AttendanceResponse? myResponse('),
      src.indexOf('WaitingEntry? myWaitingEntry('),
    );
    expect(fn.contains('_isMyAttendanceMemberId'), isTrue);
    expect(fn.contains('currentMember?.id ?? currentUserId'), isFalse);
  });

  test('한글 계정 이름을 영문 명단이 덮지 않는다', () {
    final src = read('lib/providers/club_provider.dart');
    final fn = src.substring(
      src.indexOf('void _syncSelfDisplayName()'),
      src.indexOf('bool _isMyRosterRowFor('),
    );
    expect(fn.contains('[가-힣]'), isTrue);
    expect(fn.contains('copyWith(name: _currentUserName)'), isTrue);
  });
}
