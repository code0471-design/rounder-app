import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('가입 신청은 Firestore와 총무 알림함에 같은 건을 남긴다', () {
    final src = read('lib/providers/club_provider.dart');
    expect(src.contains('publishJoinRequestToOfficer'), isTrue);
    expect(src.contains('joinRequestRepository.submitJoinRequest'), isTrue);
    expect(src.contains('ClubOpsSync.upsertClubJoinRequest'), isTrue);
    expect(src.contains('ClubOpsSync.appendOfficerInbox'), isTrue);
    expect(src.contains("notifySelf: true"), isTrue);
    expect(
      src.contains('fetchPendingForClub'),
      isTrue,
      reason: '총무 폰이 신청자 로컬을 열지 않아도 대기열을 받아야 한다',
    );
  });

  test('회원 탭 아이콘은 대기 없어도 보이고 알림을 누르면 승인 목록이 열린다', () {
    final members = read('lib/screens/members/members_screen.dart');
    expect(members.contains('if (provider.isClubExecutive)'), isTrue);
    expect(members.contains('if (pending.isNotEmpty)'), isTrue);
    expect(members.contains('consumeOpenJoinRequests'), isTrue);

    final home = read('lib/screens/home/home_screen.dart');
    expect(home.contains('openJoinRequests: openJoins'), isTrue);
    expect(home.contains('initialTab: openJoins ? 3 : 0'), isTrue);
  });

  test('승인하면 원격 명단·소속에 자동 회원으로 들어간다', () {
    final src = read('lib/providers/club_provider.dart');
    expect(src.contains('_persistApprovedJoin'), isTrue);
    expect(src.contains('approveJoinRequest'), isTrue);
    final ds = read(
      'lib/data/datasources/firestore/firestore_join_request_datasource.dart',
    );
    expect(ds.contains('userMembershipDoc'), isTrue);
    expect(ds.contains('clubMemberDoc(clubId, request.userId)'), isTrue);
    expect(ds.contains("memberData['user_id'] = request.userId"), isTrue);
    expect(ds.contains('millisecondsSinceEpoch'), isFalse);
    expect(
      ds.contains('Member.rosterId(clubId, request.userId)'),
      isFalse,
      reason: '명단 문서는 신청자 계정 ID. 가짜 회원 번호로 넣지 않는다',
    );
  });

  test('승인 모임은 신청한 그 모임이고 신청자 내 모임에도 붙는다', () {
    final src = read('lib/providers/club_provider.dart');
    expect(src.contains('_updateMemberCount(req.clubId'), isTrue);
    expect(src.contains('Member.rosterId(req.clubId, req.userId)'), isTrue);
    expect(src.contains('clubId: request.clubId'), isTrue);
    expect(src.contains('appendApplicantInbox'), isTrue);
    expect(src.contains('attachApprovedClub'), isTrue);
    expect(src.contains('pushClubOps'), isTrue);

    final home = read('lib/screens/home/home_screen.dart');
    expect(home.contains('attachApprovedClub(n.clubId)'), isTrue);
    expect(home.contains('AppNotificationType.joinApproved'), isTrue);
  });
}
