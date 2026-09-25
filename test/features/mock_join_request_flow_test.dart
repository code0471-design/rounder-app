import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/data/repositories/mock/mock_club_repository.dart';
import 'package:golf_rounder/data/repositories/mock/mock_data_store.dart';
import 'package:golf_rounder/data/repositories/mock/mock_join_request_repository.dart';
import 'package:golf_rounder/features/clubs/application/club_detail_controller.dart';
import 'package:golf_rounder/features/clubs/application/club_list_controller.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/models/user_model.dart';

void main() {
  late MockDataStore store;
  late MockClubRepository clubRepo;
  late MockJoinRequestRepository joinRepo;

  final guestUser = AppUser(
    id: 'user_guest',
    name: '이민준',
    phone: '010-9999-0000',
    handicap: 18,
    isVerified: true,
  );

  Club club(String id, {String myRole = '정회원'}) => Club(
        id: id,
        name: '테스트 $id',
        myRole: myRole,
        memberCount: 1,
        creatorId: 'user_me',
        region: '서울',
        industry: '골프',
        teamCount: 4,
        description: '',
        createdAt: DateTime(2026, 9, 1),
      );

  setUp(() {
    store = MockDataStore(seedClubs: const []);
    clubRepo = MockClubRepository(store);
    joinRepo = MockJoinRequestRepository(store);
    for (final id in ['jr_c2', 'jr_c1', 'jr_c3', 'jr_c4']) {
      store.upsertClub(club(id), persist: false);
    }
    store.addMember(
      clubId: 'jr_c1',
      member: Member(
        id: 'user_me',
        name: '회장',
        gender: '남',
        role: '회장',
        memberType: '정회원',
        status: '활성',
      ),
      persist: false,
    );
  });

  group('Mock join request E2E', () {
    test('guest submits join request and list syncs pending badge', () async {
      final listController = ClubListController(
        clubRepository: clubRepo,
        joinRequestRepository: joinRepo,
      );
      await listController.load(userId: guestUser.id);

      expect(listController.hasPendingRequest('jr_c2'), isFalse);

      final detailController = ClubDetailController(
        clubRepository: clubRepo,
        joinRequestRepository: joinRepo,
      );
      await detailController.load(
        clubId: 'jr_c2',
        userId: guestUser.id,
      );

      final ok = await detailController.submitJoinRequest(
        user: guestUser,
        message: '가입 희망합니다',
      );

      expect(ok, isTrue);
      expect(detailController.isPending, isTrue);
      expect(detailController.myPendingRequest?.id, 'jr_jr_c2_user_guest');

      await listController.syncMembershipState(guestUser.id);
      expect(listController.hasPendingRequest('jr_c2'), isTrue);
    });

    test('admin approves request and applicant becomes member', () async {
      await joinRepo.submitJoinRequest(
        clubId: 'jr_c1',
        userId: guestUser.id,
        userName: guestUser.name,
        userGender: '남',
        userHandicap: guestUser.handicap,
        message: '테스트',
        requestId: 'jr_jr_c1_user_guest',
      );

      final pending = await joinRepo.fetchPendingForClub('jr_c1');
      expect(pending.length, 1);

      final adminController = ClubDetailController(
        clubRepository: clubRepo,
        joinRequestRepository: joinRepo,
      );
      await adminController.load(clubId: 'jr_c1', userId: 'user_me');

      expect(adminController.isAdmin, isTrue);
      expect(adminController.isMember, isTrue);
      expect(adminController.pendingRequests.length, 1);

      final approved = await adminController.approveRequest(
        pending.first,
        memberType: '정회원',
        reviewedBy: '회장',
      );

      expect(approved, isTrue);
      expect(await clubRepo.isUserMember('jr_c1', guestUser.id), isTrue);
      expect(await joinRepo.fetchPendingForUser('jr_c1', guestUser.id), isNull);
    });

    test('admin rejects request', () async {
      await joinRepo.submitJoinRequest(
        clubId: 'jr_c3',
        userId: guestUser.id,
        userName: guestUser.name,
        userGender: '남',
        message: '거절 테스트',
        requestId: 'jr_jr_c3_user_guest',
      );

      final req = await joinRepo.fetchPendingForUser('jr_c3', guestUser.id);
      expect(req, isNotNull);

      await joinRepo.rejectJoinRequest(
        clubId: 'jr_c3',
        requestId: req!.id,
        reviewedBy: '관리자',
      );

      expect(await joinRepo.fetchPendingForUser('jr_c3', guestUser.id), isNull);
    });

    test('guest cancels pending join request', () async {
      await joinRepo.submitJoinRequest(
        clubId: 'jr_c4',
        userId: guestUser.id,
        userName: guestUser.name,
        userGender: '남',
        message: '취소 테스트',
        requestId: 'jr_jr_c4_user_guest',
      );

      final controller = ClubDetailController(
        clubRepository: clubRepo,
        joinRequestRepository: joinRepo,
      );
      await controller.load(clubId: 'jr_c4', userId: guestUser.id);
      expect(controller.isPending, isTrue);

      final cancelled = await controller.cancelMyJoinRequest();
      expect(cancelled, isTrue);
      expect(controller.isPending, isFalse);
      expect(await joinRepo.fetchPendingForUser('jr_c4', guestUser.id), isNull);
    });
  });
}
