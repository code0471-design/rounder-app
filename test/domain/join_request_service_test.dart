import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/domain/services/join_request_service.dart';

void main() {
  group('JoinRequestService', () {
    test('canSubmit returns true when not member and no pending', () {
      expect(
        JoinRequestService.canSubmit(isMember: false, hasPendingRequest: false),
        isTrue,
      );
    });

    test('canSubmit returns false when already member', () {
      expect(
        JoinRequestService.canSubmit(isMember: true, hasPendingRequest: false),
        isFalse,
      );
    });

    test('canSubmit returns false when pending request exists', () {
      expect(
        JoinRequestService.canSubmit(isMember: false, hasPendingRequest: true),
        isFalse,
      );
    });

    test('isAdminRole recognizes executive roles', () {
      expect(JoinRequestService.isAdminRole('회장'), isTrue);
      expect(JoinRequestService.isAdminRole('부회장'), isTrue);
      expect(JoinRequestService.isAdminRole('총무'), isTrue);
      expect(JoinRequestService.isAdminRole('일반'), isFalse);
    });

    test('신청자 로컬 명단이 없어도 서버 총무 계정으로 알림을 보낸다', () {
      const clubId = 'c_arena';
      expect(
        JoinRequestService.notifyAccountIds(
          officers: const [
            JoinOfficer(userId: 'kakao_applicant', role: '정회원'),
            JoinOfficer(
              userId: 'kakao_treasurer',
              role: '총무',
            ),
            JoinOfficer(userId: 'kakao_president', role: '회장'),
          ],
          creatorId: 'kakao_president',
        ),
        ['kakao_treasurer'],
      );
      expect(
        JoinRequestService.accountIdOf(
          clubId: clubId,
          memberOrUserId: 'm_${clubId}_kakao_treasurer',
        ),
        'kakao_treasurer',
      );
    });

    test('총무가 없으면 회장, 둘 다 없으면 생성자에게 보낸다', () {
      expect(
        JoinRequestService.notifyAccountIds(
          officers: const [
            JoinOfficer(userId: 'kakao_president', role: '회장'),
            JoinOfficer(userId: 'kakao_member', role: '정회원'),
          ],
          creatorId: 'kakao_creator',
        ),
        ['kakao_president'],
      );
      expect(
        JoinRequestService.notifyAccountIds(
          officers: const [],
          creatorId: 'kakao_creator',
        ),
        ['kakao_creator'],
      );
    });

    test('신청 문서 id는 jr_모임_계정 이다', () {
      expect(
        JoinRequestService.requestId('c_arena', 'kakao_a'),
        'jr_c_arena_kakao_a',
      );
      expect(JoinRequestService.isJoinPushType('joinRequest'), isTrue);
      expect(JoinRequestService.isJoinPushType('push_join_request'), isTrue);
      expect(JoinRequestService.isJoinPushType(''), isFalse);
    });

    test('명단 행은 로그인 계정으로만 접고 같은 사람은 한 번만 보낸다', () {
      const clubId = 'c_arena';
      expect(
        JoinRequestService.notifyAccountIds(
          officers: const [
            JoinOfficer(
              userId: 'm_c_arena_kakao_treasurer',
              role: '총무',
            ),
            JoinOfficer(userId: 'kakao_treasurer', role: '총무'),
            JoinOfficer(userId: 'm_creator_c_arena', role: '회장'),
          ],
          creatorId: 'kakao_president',
          clubId: clubId,
        ),
        ['kakao_treasurer'],
      );
      expect(
        JoinRequestService.loginAccountIdOf(
          clubId: clubId,
          memberOrUserId: 'm_creator_c_arena',
          creatorId: 'kakao_president',
        ),
        'kakao_president',
      );
      expect(JoinRequestService.isLoginAccountId('m_c_arena_kakao_a'), isFalse);
      expect(JoinRequestService.isLoginAccountId('kakao_a'), isTrue);
    });

    test('Club.myRole이 비어 있어도 명단 총무면 승인한다', () {
      expect(
        JoinRequestService.canApprove(
          myRole: '',
          creatorId: 'kakao_president',
          reviewerId: 'kakao_treasurer',
          memberRole: '총무',
        ),
        isTrue,
      );
      expect(
        JoinRequestService.canApprove(
          myRole: '정회원',
          creatorId: 'kakao_president',
          reviewerId: 'kakao_member',
          memberRole: '정회원',
        ),
        isFalse,
      );
    });

    test('신청자는 승인할 수 없고 총무·회장만 승인한다', () {
      expect(
        JoinRequestService.canApprove(
          myRole: '정회원',
          creatorId: 'kakao_president',
          reviewerId: 'kakao_applicant',
        ),
        isFalse,
      );
      expect(
        JoinRequestService.canApprove(
          myRole: '총무',
          creatorId: 'kakao_president',
          reviewerId: 'kakao_treasurer',
        ),
        isTrue,
      );
      expect(
        JoinRequestService.canApprove(
          myRole: '정회원',
          creatorId: 'kakao_president',
          reviewerId: 'kakao_president',
        ),
        isTrue,
      );
    });
  });
}
