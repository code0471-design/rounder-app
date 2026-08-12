import '../../../models/club_model.dart';
import 'mock_data_store.dart';
import '../join_request_repository.dart';

/// 오프라인 Mock — 메모리 내 가입 신청 + 승인 시 멤버 추가
class MockJoinRequestRepository implements JoinRequestRepository {
  MockJoinRequestRepository(this._store);

  final MockDataStore _store;

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

  bool _isMemberAny(String clubId, String userId) {
    final users = _userAliases(userId);
    for (final key in _clubKeys(clubId)) {
      if (users.any((id) => _store.isMember(key, id))) return true;
    }
    return false;
  }

  void _removeMemberAny(String clubId, String userId) {
    final users = _userAliases(userId);
    for (final key in _clubKeys(clubId)) {
      final map = _store.membersByClub[key];
      if (map == null) continue;
      for (final id in users) {
        map.remove(id);
      }
    }
  }

  JoinRequest? _pendingAny(String clubId, String userId) {
    final clubs = _clubKeys(clubId);
    final users = _userAliases(userId);
    for (final r in _store.pendingJoinRequests) {
      if (r.status != JoinRequestStatus.pending) continue;
      if (clubs.contains(r.clubId) && users.contains(r.userId)) return r;
    }
    return null;
  }

  @override
  Future<List<JoinRequest>> fetchPendingForClub(String clubId) async {
    final clubs = _clubKeys(clubId);
    return _store.pendingJoinRequests
        .where((r) =>
            clubs.contains(r.clubId) && r.status == JoinRequestStatus.pending)
        .toList();
  }

  @override
  Future<JoinRequest?> fetchPendingForUser(String clubId, String userId) async =>
      _pendingAny(clubId, userId);

  @override
  Future<String> submitJoinRequest({
    required String clubId,
    required String userId,
    required String userName,
    required String userGender,
    double? userHandicap,
    required String message,
  }) async {
    // 탈퇴 후 재신청: 스토어에 남은 ghost 멤버십 제거
    _removeMemberAny(clubId, userId);

    if (_pendingAny(clubId, userId) != null) {
      throw StateError('이미 가입 신청 중입니다');
    }

    final id = 'mock_jr_${DateTime.now().millisecondsSinceEpoch}';
    _store.pendingJoinRequests.add(
      JoinRequest(
        id: id,
        clubId: clubId,
        userId: userId,
        userName: userName,
        userGender: userGender,
        userHandicap: userHandicap,
        message: message,
        requestedAt: DateTime.now(),
      ),
    );
    _store.bump(persist: true);
    return id;
  }

  @override
  Future<void> approveJoinRequest({
    required JoinRequest request,
    required String memberType,
    required String role,
    required String reviewedBy,
  }) async {
    _store.pendingJoinRequests.removeWhere((r) => r.id == request.id);
    if (_isMemberAny(request.clubId, request.userId)) return;

    final targetClubId = request.clubId.startsWith('seed_')
        ? request.clubId
        : (_clubKeys(request.clubId)
            .firstWhere((k) => k.startsWith('seed_'), orElse: () => request.clubId));

    _store.addMember(
      clubId: targetClubId,
      member: Member(
        id: request.userId,
        name: request.userName,
        gender: request.userGender,
        memberType: memberType,
        role: role,
        handicap: request.userHandicap,
        joinDate: DateTime.now(),
      ),
      alsoAsIds: _userAliases(request.userId).toList(),
    );
  }

  @override
  Future<void> rejectJoinRequest({
    required String clubId,
    required String requestId,
    required String reviewedBy,
  }) async {
    _store.pendingJoinRequests.removeWhere((r) => r.id == requestId);
  }

  @override
  Future<void> cancelJoinRequest({
    required String clubId,
    required String requestId,
    required String userId,
  }) async {
    final users = _userAliases(userId);
    final clubs = _clubKeys(clubId);
    JoinRequest? match;
    for (final r in _store.pendingJoinRequests) {
      if (r.id == requestId) {
        match = r;
        break;
      }
    }
    match ??= _pendingAny(clubId, userId);
    if (match == null) {
      throw StateError('취소할 가입 신청을 찾을 수 없습니다');
    }
    final id = match.id;
    _store.pendingJoinRequests.removeWhere(
      (r) =>
          r.id == id ||
          (clubs.contains(r.clubId) &&
              users.contains(r.userId) &&
              r.status == JoinRequestStatus.pending),
    );
    _store.bump(persist: true);
  }
}
