import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/data/repositories/club_repository.dart';
import 'package:golf_rounder/data/repositories/join_request_repository.dart';
import 'package:golf_rounder/features/clubs/application/club_detail_controller.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/models/user_model.dart';

class _FakeClubRepository implements ClubRepository {
  _FakeClubRepository(this._club, {this.isMember = false});

  final Club _club;
  final bool isMember;
  int? lastTeamCount;

  @override
  Future<Club?> fetchClubById(String clubId, {required String userId}) async =>
      _club.id == clubId ? _club : null;

  @override
  Future<bool> isUserMember(String clubId, String userId) async => isMember;

  @override
  Future<void> updateTeamCount(String clubId, int teamCount) async {
    lastTeamCount = teamCount;
  }

  @override
  Future<List<Club>> fetchDiscoverableClubs() async => [_club];

  @override
  Future<List<Club>> fetchMyClubs(String userId) async => [];

  @override
  Stream<List<Club>> watchDiscoverableClubs() async* {
    yield [_club];
  }
}

class _FakeJoinRequestRepository implements JoinRequestRepository {
  JoinRequest? pendingForUser;
  final List<JoinRequest> pendingForClub = [];
  int submitCount = 0;
  int approveCount = 0;

  @override
  Future<void> approveJoinRequest({
    required JoinRequest request,
    required String memberType,
    required String role,
    required String reviewedBy,
  }) async {
    approveCount++;
    pendingForClub.removeWhere((r) => r.id == request.id);
    pendingForUser = null;
  }

  @override
  Future<JoinRequest?> fetchPendingForUser(String clubId, String userId) async =>
      pendingForUser;

  @override
  Future<List<JoinRequest>> fetchPendingForClub(String clubId) async =>
      pendingForClub;

  @override
  Future<void> rejectJoinRequest({
    required String clubId,
    required String requestId,
    required String reviewedBy,
  }) async {
    pendingForClub.removeWhere((r) => r.id == requestId);
  }

  @override
  Future<void> cancelJoinRequest({
    required String clubId,
    required String requestId,
    required String userId,
  }) async {
    pendingForClub.removeWhere((r) => r.id == requestId);
    if (pendingForUser?.id == requestId) {
      pendingForUser = null;
    }
  }

  @override
  Future<String> submitJoinRequest({
    required String clubId,
    required String userId,
    required String userName,
    required String userGender,
    double? userHandicap,
    required String message,
  }) async {
    submitCount++;
    pendingForUser = JoinRequest(
      id: 'jr1',
      clubId: clubId,
      userId: userId,
      userName: userName,
      userGender: userGender,
      userHandicap: userHandicap,
      message: message,
      requestedAt: DateTime(2025, 1, 1),
    );
    return 'jr1';
  }
}

void main() {
  final club = Club(
    id: 'c1',
    name: '테스트 모임',
    myRole: '일반',
    region: '서울',
    industry: 'IT/테크',
    memberCount: 5,
  );

  final user = AppUser(
    id: 'u1',
    name: '테스트유저',
    phone: '010-1234-5678',
    handicap: 15,
    isVerified: true,
  );

  group('ClubDetailController', () {
    test('load sets loaded state with club data', () async {
      final joinRepo = _FakeJoinRequestRepository();
      final controller = ClubDetailController(
        clubRepository: _FakeClubRepository(club),
        joinRequestRepository: joinRepo,
      );

      await controller.load(clubId: club.id, userId: user.id, initialClub: club);

      expect(controller.state, ClubDetailLoadState.loaded);
      expect(controller.club?.name, '테스트 모임');
      expect(controller.canSubmitJoin, isTrue);
    });

    test('submitJoinRequest marks pending state', () async {
      final joinRepo = _FakeJoinRequestRepository();
      final controller = ClubDetailController(
        clubRepository: _FakeClubRepository(club),
        joinRequestRepository: joinRepo,
      );
      await controller.load(clubId: club.id, userId: user.id, initialClub: club);

      final ok = await controller.submitJoinRequest(user: user, message: '안녕');

      expect(ok, isTrue);
      expect(joinRepo.submitCount, 1);
      expect(controller.isPending, isTrue);
      expect(controller.canSubmitJoin, isFalse);
    });

    test('admin load fetches pending requests', () async {
      final adminClub = club.copyWith(myRole: '총무');
      final joinRepo = _FakeJoinRequestRepository()
        ..pendingForClub.add(
          JoinRequest(
            id: 'jr2',
            clubId: club.id,
            userId: 'u2',
            userName: '신청자',
            userGender: '남',
            requestedAt: DateTime(2025, 1, 2),
          ),
        );
      final controller = ClubDetailController(
        clubRepository: _FakeClubRepository(adminClub, isMember: true),
        joinRequestRepository: joinRepo,
      );

      await controller.load(
        clubId: adminClub.id,
        userId: 'admin',
        initialClub: adminClub,
      );

      expect(controller.isAdmin, isTrue);
      expect(controller.pendingRequests.length, 1);
    });
  });
}
