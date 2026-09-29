import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/data/repositories/club_repository.dart';
import 'package:golf_rounder/data/repositories/join_request_repository.dart';
import 'package:golf_rounder/features/clubs/application/club_list_controller.dart';
import 'package:golf_rounder/models/club_model.dart';

class _FakeClubRepository implements ClubRepository {
  _FakeClubRepository(this._clubs, {this.shouldFail = false});

  final List<Club> _clubs;
  final bool shouldFail;

  @override
  Future<List<Club>> fetchDiscoverableClubs() async {
    if (shouldFail) throw Exception('Firestore unavailable');
    return _clubs;
  }

  int myClubsCalls = 0;

  @override
  Future<List<Club>> fetchMyClubs(String userId) async {
    myClubsCalls++;
    return [];
  }

  @override
  Stream<List<Club>> watchDiscoverableClubs() async* {
    yield _clubs;
  }

  @override
  Future<Club?> fetchClubById(String clubId, {required String userId}) async {
    try {
      return _clubs.firstWhere((c) => c.id == clubId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> isUserMember(String clubId, String userId) async => false;

  @override
  Future<void> updateTeamCount(String clubId, int teamCount) async {}

  @override
  Future<void> updateClubInfo(
    String clubId, {
    String? name,
    String? description,
    String? imageUrl,
    int? teamCount,
    int? memberCount,
    String? hostName,
    String? hostUserId,
    String? region,
    String? industry,
  }) async {}

  @override
  Future<void> createClub({
    required Club club,
    required String userId,
    required String userName,
    required Member creatorMember,
    String moderationStatus = 'active',
  }) async {}

  @override
  Future<void> addMemberViaInvite({
    required String clubId,
    required String userId,
    required Member member,
  }) async {}

  @override
  Future<int> recountMemberCount(String clubId) async => 0;

  @override
  Future<void> removeOfficialMembership({
    required String clubId,
    required String userId,
  }) async {}

  @override
  Future<List<ClubMemberAccount>> fetchClubMemberAccounts(String clubId) async =>
      const [];
}

void main() {
  final sampleClubs = [
    Club(
      id: '1',
      name: '서울 라운더',
      myRole: '일반',
      region: '서울',
      industry: 'IT/테크',
      memberCount: 12,
    ),
    Club(
      id: '2',
      name: '부산 골프',
      myRole: '일반',
      region: '부산',
      industry: '금융',
      memberCount: 8,
    ),
  ];

  group('ClubListController', () {
    test('load populates clubs on success', () async {
      final controller = ClubListController(
        clubRepository: _FakeClubRepository(sampleClubs),
      );

      await controller.load();

      expect(controller.state, ClubListLoadState.loaded);
      expect(controller.clubs.length, 2);
      expect(controller.usingLocalFallback, isFalse);
    });

    test('empty catalog is success, not sample fallback', () async {
      final controller = ClubListController(
        clubRepository: _FakeClubRepository([]),
      );

      await controller.load();

      expect(controller.state, ClubListLoadState.loaded);
      expect(controller.clubs, isEmpty);
      expect(controller.usingLocalFallback, isFalse);
    });

    test('load keeps an empty list on repository failure, not an error screen',
        () async {
      final controller = ClubListController(
        clubRepository: _FakeClubRepository([], shouldFail: true),
      );

      await controller.load();

      expect(controller.state, ClubListLoadState.loaded);
      expect(controller.clubs, isEmpty);
      expect(controller.usingLocalFallback, isFalse);
    });

    test('updateFilters narrows filteredClubs', () async {
      final controller = ClubListController(
        clubRepository: _FakeClubRepository(sampleClubs),
      );
      await controller.load();

      controller.updateFilters(region: '부산');
      expect(controller.filteredClubs.length, 1);
      expect(controller.filteredClubs.first.name, '부산 골프');

      controller.updateFilters(keyword: '라운더');
      expect(controller.filteredClubs, isEmpty);

      controller.updateFilters(region: '전체', keyword: '라운더');
      expect(controller.filteredClubs.length, 1);
    });

    test('membership hints drive isMyClub and hasPendingRequest', () {
      final controller = ClubListController(
        clubRepository: _FakeClubRepository(sampleClubs),
        myClubIds: {'1'},
        pendingClubIds: {'2'},
      );

      expect(controller.isMyClub('1'), isTrue);
      expect(controller.isMyClub('2'), isFalse);
      expect(controller.hasPendingRequest('2'), isTrue);
    });

    test('load shows clubs before pending checks finish', () async {
      final join = _GateJoinRepository();
      final controller = ClubListController(
        clubRepository: _FakeClubRepository(sampleClubs),
        joinRequestRepository: join,
        myClubIds: {'1'},
      );

      var sawClubsWhilePendingOpen = false;
      controller.addListener(() {
        if (controller.state == ClubListLoadState.loaded &&
            controller.clubs.length == 2 &&
            !join.released) {
          sawClubsWhilePendingOpen = true;
          join.release();
        }
      });

      await controller.load(userId: 'user_1');

      expect(sawClubsWhilePendingOpen, isTrue);
      expect(controller.clubs.length, 2);
      expect(controller.hasPendingRequest('2'), isTrue);
    });

    test('pending checks run together and skip my-club refetch', () async {
      final repo = _FakeClubRepository(sampleClubs);
      final join = _ParallelJoinRepository();
      final controller = ClubListController(
        clubRepository: repo,
        joinRequestRepository: join,
        myClubIds: {'1'},
      );

      await controller.load(userId: 'user_1');

      expect(repo.myClubsCalls, 0);
      expect(join.starts.length, 2);
      expect(
        join.starts[1].difference(join.starts[0]).inMilliseconds < 40,
        isTrue,
        reason: '가입 상태를 모임마다 차례로 읽으면 목록이 늦어진다',
      );
    });
  });
}

class _GateJoinRepository implements JoinRequestRepository {
  bool released = false;
  void release() => released = true;

  Future<void> _wait() async {
    for (var i = 0; i < 40 && !released; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  @override
  Future<JoinRequest?> fetchPendingForUser(String clubId, String userId) async {
    await _wait();
    return clubId == '2'
        ? JoinRequest(
            id: 'jr_2',
            clubId: clubId,
            userId: userId,
            userName: '테스터',
            userGender: '남',
            status: JoinRequestStatus.pending,
            requestedAt: DateTime(2026, 9, 1),
          )
        : null;
  }

  @override
  Future<List<JoinRequest>> fetchPendingForClub(String clubId) async =>
      const [];

  @override
  Future<String> submitJoinRequest({
    required String clubId,
    required String userId,
    required String userName,
    required String userGender,
    double? userHandicap,
    String? userPhone,
    String? userPhotoUrl,
    DateTime? userBirthDate,
    required String message,
    String? requestId,
  }) async =>
      'jr';

  @override
  Future<void> approveJoinRequest({
    required JoinRequest request,
    required String memberType,
    required String role,
    required String reviewedBy,
  }) async {}

  @override
  Future<void> rejectJoinRequest({
    required String clubId,
    required String requestId,
    required String reviewedBy,
  }) async {}

  @override
  Future<void> cancelJoinRequest({
    required String clubId,
    required String requestId,
    required String userId,
  }) async {}
}

class _ParallelJoinRepository implements JoinRequestRepository {
  final starts = <DateTime>[];

  @override
  Future<JoinRequest?> fetchPendingForUser(String clubId, String userId) async {
    starts.add(DateTime.now());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return null;
  }

  @override
  Future<List<JoinRequest>> fetchPendingForClub(String clubId) async =>
      const [];

  @override
  Future<String> submitJoinRequest({
    required String clubId,
    required String userId,
    required String userName,
    required String userGender,
    double? userHandicap,
    String? userPhone,
    String? userPhotoUrl,
    DateTime? userBirthDate,
    required String message,
    String? requestId,
  }) async =>
      'jr';

  @override
  Future<void> approveJoinRequest({
    required JoinRequest request,
    required String memberType,
    required String role,
    required String reviewedBy,
  }) async {}

  @override
  Future<void> rejectJoinRequest({
    required String clubId,
    required String requestId,
    required String reviewedBy,
  }) async {}

  @override
  Future<void> cancelJoinRequest({
    required String clubId,
    required String requestId,
    required String userId,
  }) async {}
}
