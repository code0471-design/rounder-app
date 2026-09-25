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
    expect(
      src.contains('if (!canApprove) continue'),
      isFalse,
      reason: 'Club.myRole 이 정회원이라고 서버 신청 읽기를 건너뛰면 총무 시트가 비어 있다',
    );
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
    final home = read('lib/screens/home/home_screen.dart');
    expect(home.contains('openJoinRequests: openJoins'), isTrue);
    expect(home.contains('initialTab: openJoins ? 3 : 0'), isTrue);

    final my = read('lib/screens/my_clubs/my_clubs_screen.dart');
    expect(my.contains('openJoinRequests: openJoins'), isTrue);
    expect(my.contains('initialTab: openJoins ? 3 : 0'), isTrue);
    expect(my.contains('_openNotificationTarget'), isTrue);

    final room = read('lib/screens/club_room/club_room_screen.dart');
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
