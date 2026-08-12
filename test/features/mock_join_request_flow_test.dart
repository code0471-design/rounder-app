import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/data/repositories/mock/mock_club_repository.dart';
import 'package:golf_rounder/data/repositories/mock/mock_data_store.dart';
import 'package:golf_rounder/data/repositories/mock/mock_join_request_repository.dart';
import 'package:golf_rounder/features/clubs/application/club_detail_controller.dart';
import 'package:golf_rounder/features/clubs/application/club_list_controller.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/models/user_model.dart';

void main() {
  final store = MockDataStore();
  final clubRepo = MockClubRepository(store);
  final joinRepo = MockJoinRequestRepository(store);

  final guestUser = AppUser(
    id: 'user_guest',
    name: '이민준',
    phone: '010-9999-0000',
    handicap: 18,
    isVerified: true,
  );

  group('Mock join request E2E', () {
    test('guest submits join request and list syncs pending badge', () async {
      final listController = ClubListController(
        clubRepository: clubRepo,
        joinRequestRepository: joinRepo,
      );
      await listController.load(userId: guestUser.id);

      expect(listController.hasPendingRequest('seed_c2'), isFalse);

      final detailController = ClubDetailController(
        clubRepository: clubRepo,
        joinRequestRepository: joinRepo,
      );
      await detailController.load(
        clubId: 'seed_c2',
        userId: guestUser.id,
      );

      final ok = await detailController.submitJoinRequest(
        user: guestUser,
        message: '가입 희망합니다',
      );

      expect(ok, isTrue);
      expect(detailController.isPending, isTrue);

      await listController.syncMembershipState(guestUser.id);
      expect(listController.hasPendingRequest('seed_c2'), isTrue);
    });

    test('admin approves request and applicant becomes member', () async {
      await joinRepo.submitJoinRequest(
        clubId: 'seed_c1',
        userId: guestUser.id,
        userName: guestUser.name,
        userGender: '남',
        userHandicap: guestUser.handicap,
        message: '테스트',
      );

      final pending = await joinRepo.fetchPendingForClub('seed_c1');
      expect(pending.length, 1);

      final adminController = ClubDetailController(
        clubRepository: clubRepo,
        joinRequestRepository: joinRepo,
      );
      await adminController.load(clubId: 'seed_c1', userId: 'user_me');

      expect(adminController.isAdmin, isTrue);
      expect(adminController.isMember, isTrue);
      expect(adminController.pendingRequests.length, 1);

      final approved = await adminController.approveRequest(
        pending.first,
        memberType: '정회원',
        reviewedBy: '홍길동',
      );

      expect(approved, isTrue);
      expect(await clubRepo.isUserMember('seed_c1', guestUser.id), isTrue);
      expect(await joinRepo.fetchPendingForUser('seed_c1', guestUser.id), isNull);
    });

    test('admin rejects request', () async {
      await joinRepo.submitJoinRequest(
        clubId: 'seed_c3',
        userId: guestUser.id,
        userName: guestUser.name,
        userGender: '남',
        message: '거절 테스트',
      );

      final req = await joinRepo.fetchPendingForUser('seed_c3', guestUser.id);
      expect(req, isNotNull);

      final controller = ClubDetailController(
        clubRepository: clubRepo,
        joinRequestRepository: joinRepo,
      );
      await controller.load(clubId: 'seed_c3', userId: 'user_me');

      // user_me is not admin of seed_c3 — use direct reject via repo
      await joinRepo.rejectJoinRequest(
        clubId: 'seed_c3',
        requestId: req!.id,
        reviewedBy: '관리자',
      );

      expect(await joinRepo.fetchPendingForUser('seed_c3', guestUser.id), isNull);
    });
    test('guest cancels pending join request', () async {
      await joinRepo.submitJoinRequest(
        clubId: 'seed_c4',
        userId: guestUser.id,
        userName: guestUser.name,
        userGender: '남',
        message: '취소 테스트',
      );

      final controller = ClubDetailController(
        clubRepository: clubRepo,
        joinRequestRepository: joinRepo,
      );
      await controller.load(clubId: 'seed_c4', userId: guestUser.id);
      expect(controller.isPending, isTrue);

      final cancelled = await controller.cancelMyJoinRequest();
      expect(cancelled, isTrue);
      expect(controller.isPending, isFalse);
      expect(await joinRepo.fetchPendingForUser('seed_c4', guestUser.id), isNull);
    });
  });
}
