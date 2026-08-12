import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/data/repositories/club_repository.dart';
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

  @override
  Future<List<Club>> fetchMyClubs(String userId) async => [];

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

    test('load falls back to sample catalog on repository failure', () async {
      final controller = ClubListController(
        clubRepository: _FakeClubRepository([], shouldFail: true),
      );

      await controller.load();

      expect(controller.state, ClubListLoadState.loaded);
      expect(controller.clubs.length, 10);
      expect(controller.usingLocalFallback, isTrue);
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
  });
}
