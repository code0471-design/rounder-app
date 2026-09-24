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
