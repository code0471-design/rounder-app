import 'dart:async';

import '../../../models/club_model.dart';
import 'mock_data_store.dart';
import '../club_repository.dart';

/// 오프라인 Mock — Firestore 없이 샘플 카탈로그 제공
class MockClubRepository implements ClubRepository {
  MockClubRepository(this._store);

  final MockDataStore _store;

  /// 공개 탐색: 승인·대기 노출 (블라인드/종료만 숨김)
  List<Club> get _discoverable => _store.clubs.where((c) {
        final s = _store.clubModerationStatus(c.id);
        return s == 'active' || s == 'pending';
      }).toList(growable: false);

  @override
  Future<List<Club>> fetchDiscoverableClubs() async =>
      List.unmodifiable(_discoverable);

  Set<String> _userAliases(String userId) => {
        userId,
        if (userId == 'user_guest') 'mg1',
        if (userId == 'mg1') 'user_guest',
        if (userId == 'user_me') 'm1',
        if (userId == 'm1') 'user_me',
      };

  Set<String> _clubKeys(String clubId) {
    final keys = <String>{clubId};
    if (clubId.startsWith('seed_')) {
      keys.add(clubId.substring(5));
    } else if (RegExp(r'^c\d+$').hasMatch(clubId)) {
      keys.add('seed_$clubId');
    }
    return keys;
  }

  bool _isMemberAnyKey(String clubId, Set<String> userAliases) {
    for (final key in _clubKeys(clubId)) {
      if (userAliases.any((id) => _store.isMember(key, id))) return true;
    }
    return false;
  }

  @override
  Future<List<Club>> fetchMyClubs(String userId) async {
    final aliases = _userAliases(userId);
    return _store.clubs
        .where((c) {
          if (_isMemberAnyKey(c.id, aliases)) return true;
          // 멤버십 키 유실돼도 creatorId로 내 생성 모임 복구
          if (c.creatorId.isNotEmpty && aliases.contains(c.creatorId)) {
            return true;
          }
          return false;
        })
        .map((c) {
          try {
            return _store.clubForUser(c.id, userId);
          } catch (_) {
            return c;
          }
        })
        .toList();
  }

  @override
  Stream<List<Club>> watchDiscoverableClubs() async* {
    yield List.unmodifiable(_discoverable);
    await for (final _ in _storeAsStream()) {
      yield List.unmodifiable(_discoverable);
    }
  }

  Stream<void> _storeAsStream() {
    late final StreamController<void> controller;
    void listener() {
      if (!controller.isClosed) controller.add(null);
    }

    controller = StreamController<void>(
      onListen: () => _store.addListener(listener),
      onCancel: () {
        _store.removeListener(listener);
        controller.close();
      },
    );
    return controller.stream;
  }

  @override
  Future<Club?> fetchClubById(String clubId, {required String userId}) async {
    if (_store.clubById(clubId) == null) return null;
    return _store.clubForUser(clubId, userId);
  }

  @override
  Future<bool> isUserMember(String clubId, String userId) async =>
      _isMemberAnyKey(clubId, _userAliases(userId));

  @override
  Future<void> updateTeamCount(String clubId, int teamCount) async {
    await updateClubInfo(clubId, teamCount: teamCount);
  }

  @override
  Future<void> updateClubInfo(
    String clubId, {
    String? name,
    String? description,
    String? imageUrl,
    int? teamCount,
  }) async {
    final i = _store.clubs.indexWhere((c) => c.id == clubId);
    if (i == -1) return;
    _store.clubs[i] = _store.clubs[i].copyWith(
      name: name,
      description: description,
      imageUrl: imageUrl,
      teamCount: teamCount,
    );
    _store.bump();
  }

  @override
  Future<void> createClub({
    required Club club,
    required String userId,
    required String userName,
    required Member creatorMember,
    String moderationStatus = 'pending',
  }) async {
    _store.upsertClub(
      club,
      moderationStatus: moderationStatus,
      persist: false,
    );
    _store.addMember(
      clubId: club.id,
      member: creatorMember,
      bumpCount: false,
      alsoAsIds: [
        userId,
        if (userId == 'user_guest') 'mg1',
        if (userId == 'user_me') 'm1',
        if (userId == 'mg1') 'user_guest',
        if (userId == 'm1') 'user_me',
      ],
      persist: false,
    );
    _store.bump(persist: true);
  }
}
