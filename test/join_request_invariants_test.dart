import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 원클럽 `join_request_invariants` 와 같은 잠금.
/// 푸시만 오고 회원 탭·알림함·상단 아이콘·서버 승인이 없으면 실패한 것이다.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('신청은 서버 모임 신청 컬렉션에 남는다', () {
    final ds = read(
      'lib/data/datasources/firestore/firestore_join_request_datasource.dart',
    );
    expect(ds.contains('clubJoinRequests'), isTrue);
    expect(ds.contains("memberData['user_id'] = request.userId"), isTrue);

    final src = read('lib/providers/club_provider.dart');
    expect(src.contains('joinRequestRepository.submitJoinRequest'), isTrue);
    expect(src.contains('JoinRequestService.requestId'), isTrue);
    expect(src.contains('fetchPendingForClub'), isTrue);
    expect(src.contains('itemId: req.id'), isTrue);
    expect(src.contains('loginAccountIdOf'), isTrue);
    expect(src.contains('resultInboxItemId'), isTrue);
    expect(src.contains('uniquePendingByUser'), isTrue);
    expect(src.contains('dropMyPendingForClub'), isTrue);
    expect(src.contains('dropMyPendingNotOnServer'), isTrue);
    final inboxAt = src.indexOf('Future<void> refreshJoinRequestInbox()');
    expect(
      src.indexOf('await mergeSharedJoinRequests();', inboxAt) <
          src.indexOf('_pullPendingJoinRequestsForClub(c.id)', inboxAt),
      isTrue,
      reason: '공유 로컬을 서버 pull 뒤에 다시 넣으면 지운 신청이 살아난다',
    );
    expect(
      src.contains("joinOwned"),
      isTrue,
      reason: '가입 푸시는 publish/approve 한 경로만 큐에 넣는다',
    );
    expect(src.contains('join officer members skip'), isTrue);
    expect(
      src.contains('if (!hasOfficer)'),
      isFalse,
      reason: '소속이 회장이어도 명단 총무를 읽어야 한다',
    );
    expect(
      src.contains('if (inboxId.isEmpty || _isSelfTarget(inboxId)) continue'),
      isFalse,
      reason: '신청자 기기에서 임원 알림함을 건너뛰면 방장 알림함이 비어 있다',
    );
    expect(
      src.contains('if (!canApprove) continue'),
      isFalse,
      reason: 'Club.myRole 이 정회원이라고 서버 신청 읽기를 건너뛰면 총무 시트가 비어 있다',
    );
  });

  test('신청 쿼리 인덱스가 있고 문서 id로 내 신청을 읽는다', () {
    final indexes = read('firestore.indexes.json');
    expect(indexes.contains('"status"'), isTrue);
    expect(indexes.contains('"requested_at"'), isTrue);
    expect(indexes.contains('"user_id"'), isTrue);

    final ds = read(
      'lib/data/datasources/firestore/firestore_join_request_datasource.dart',
    );
    expect(ds.contains('JoinRequestService.requestId'), isTrue);
    expect(ds.contains("e.code != 'failed-precondition'"), isTrue);

    final controller = read(
      'lib/features/clubs/application/club_detail_controller.dart',
    );
    expect(
      controller.contains(
        'await _joinRequestRepository.fetchPendingForUser(club.id, user.id)',
      ),
      isFalse,
      reason: '저장 직후 fetchPending 실패로 임원 알림을 건너뛰면 안 된다',
    );
    expect(controller.contains('_myPendingRequest = JoinRequest('), isTrue);

    final push = read('lib/services/push_notification_service.dart');
    expect(push.contains('String? itemId'), isTrue);
    expect(push.contains('SetOptions(merge: true)'), isTrue);
  });

  test('총무 알림함 type=joinRequest 이고 계정 id로 보낸다', () {
    final src = read('lib/providers/club_provider.dart');
    expect(src.contains('AppNotificationType.joinRequest'), isTrue);
    expect(src.contains('targetId: req.id'), isTrue);
    expect(src.contains('ClubOpsSync.appendOfficerInbox'), isTrue);
    expect(src.contains('JoinRequestService.notifyAccountIds'), isTrue);
    expect(src.contains('fetchClubMemberAccounts'), isTrue);
    expect(src.contains("notifySelf: true"), isTrue);
  });

  test('푸시/알림 탭 → 회원 탭 3 + openJoinRequests / showJoinRequestsSheet', () {
    final dash = read(
      'lib/features/clubs/presentation/club_detail_dashboard_screen.dart',
    );
    expect(dash.contains('legacyProvider.submitJoinRequest'), isTrue);
    expect(
      dash.contains('controller.state == ClubDetailLoadState.loaded'),
      isTrue,
      reason: '서버에 없는 신청을 폰 로컬 때문에 가입신청중으로 두면 안 된다',
    );
    expect(
      dash.contains('controller.submitJoinRequest'),
      isFalse,
      reason: '대시보드가 저장과 푸시를 각각 부르면 푸시가 두 번 나간다',
    );
    expect(dash.contains('legacyProvider.approveRequest'), isTrue);
    expect(dash.contains('dropMyPendingForClub'), isTrue);
    expect(dash.contains('serverConfirmedNoPending'), isTrue);

    final listDash = read(
      'lib/features/clubs/presentation/club_list_dashboard_screen.dart',
    );
    expect(
      listDash.contains('legacyProvider.hasPendingRequest(clubs[i].id)'),
      isFalse,
      reason: '목록의 가입신청중은 서버 조회만 본다',
    );
    expect(listDash.contains('dropMyPendingNotOnServer'), isTrue);

    final home = read('lib/screens/home/home_screen.dart');
    expect(home.contains('openJoinRequests: openJoins'), isTrue);
    expect(home.contains('initialTab: openJoins ? 3 : 0'), isTrue);

    final my = read('lib/screens/my_clubs/my_clubs_screen.dart');
    expect(my.contains('openJoinRequests: openJoins'), isTrue);
    expect(my.contains('initialTab: openJoins ? 3 : 0'), isTrue);
    expect(my.contains('_openNotificationTarget'), isTrue);

    final room = read('lib/screens/club_room/club_room_screen.dart');
    expect(
      room.contains('await provider.refreshJoinRequestInbox()'),
      isFalse,
      reason: '알림 종을 서버 동기화 뒤에 열면 한참 걸리거나 안 열린다',
    );
    expect(room.contains('MembersScreen.showJoinRequestsSheet'), isTrue);
    expect(room.contains('refreshJoinRequestsForClub'), isTrue);
    expect(room.contains('openTab(3)'), isTrue);

    final members = read('lib/screens/members/members_screen.dart');
    expect(members.contains('showJoinRequestsSheet'), isTrue);
    expect(members.contains('consumeOpenJoinRequests'), isTrue);

    final push = read('lib/services/push_notification_service.dart');
    expect(push.contains('onMessageOpenedApp'), isTrue);
    expect(push.contains('getInitialMessage'), isTrue);
    expect(push.contains('handleOpenedData'), isTrue);

    final deep = read('lib/services/deep_link_service.dart');
    expect(deep.contains('openJoinRequests: true'), isTrue);
    expect(deep.contains('initialTab: 3'), isTrue);
    expect(deep.contains('JoinRequestService.isJoinPushType'), isTrue);
  });

  test('임원 회원 탭에 how_to_reg 가 있고 pending.isEmpty 로 숨기지 않는다', () {
    final members = read('lib/screens/members/members_screen.dart');
    expect(members.contains('if (provider.isClubExecutive)'), isTrue);
    expect(members.contains('Icons.how_to_reg'), isTrue);
    expect(
      members.contains('if (pending.isEmpty) return const SizedBox.shrink()'),
      isFalse,
      reason: '대기 0건이어도 아이콘은 남아 있어야 한다',
    );
    expect(members.contains('if (pending.isNotEmpty)'), isTrue);
  });

  test('승인은 계정 id 명단 + membership 이고 가짜 m_시각 id 가 없다', () {
    final src = read('lib/providers/club_provider.dart');
    expect(src.contains('_persistApprovedJoin'), isTrue);
    expect(src.contains('approveJoinRequest'), isTrue);
    expect(src.contains('Member.rosterId(req.clubId, req.userId)'), isTrue);
    expect(src.contains("m_\${userId}_\${"), isFalse);
    expect(src.contains('millisecondsSinceEpoch}'), isTrue);

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

  test('내 모임 prune 잠금이 그대로다 — 가입신청이 그 로직을 건드리면 안 된다', () {
    final prune = read('test/my_clubs_prune_test.dart');
    expect(prune.contains('아레나 골프회'), isTrue);
    expect(prune.contains('알라딘 정기월례회'), isTrue);
    expect(
      prune.contains('서버 멤버십이 없으면 내 모임이 아니다'),
      isTrue,
    );
    expect(
      prune.contains('내가 만든 모임은 그대로 남아야 한다'),
      isTrue,
    );
  });
}
