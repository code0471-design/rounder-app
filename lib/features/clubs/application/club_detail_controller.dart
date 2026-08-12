import 'package:flutter/foundation.dart';

import '../../../data/repositories/club_repository.dart';
import '../../../data/repositories/join_request_repository.dart';
import '../../../domain/services/join_request_service.dart';
import '../../../models/club_model.dart';
import '../../../models/user_model.dart';

enum ClubDetailLoadState { idle, loading, loaded, error }

/// 모임 상세 + 가입신청 — Firestore Application Layer
class ClubDetailController extends ChangeNotifier {
  ClubDetailController({
    required ClubRepository clubRepository,
    required JoinRequestRepository joinRequestRepository,
  })  : _clubRepository = clubRepository,
        _joinRequestRepository = joinRequestRepository;

  final ClubRepository _clubRepository;
  final JoinRequestRepository _joinRequestRepository;

  ClubDetailLoadState _state = ClubDetailLoadState.idle;
  Club? _club;
  String? _userId;
  bool _isMember = false;
  JoinRequest? _myPendingRequest;
  List<JoinRequest> _pendingRequests = [];
  String? _errorMessage;
  bool _actionInProgress = false;

  ClubDetailLoadState get state => _state;
  Club? get club => _club;
  bool get isMember => _isMember;
  JoinRequest? get myPendingRequest => _myPendingRequest;
  List<JoinRequest> get pendingRequests => _pendingRequests;
  String? get errorMessage => _errorMessage;
  bool get actionInProgress => _actionInProgress;

  bool get isPending => _myPendingRequest != null;
  bool get isAdmin =>
      _club != null && JoinRequestService.isAdminRole(_club!.myRole);

  bool get canSubmitJoin => JoinRequestService.canSubmit(
        isMember: _isMember,
        hasPendingRequest: isPending,
      );

  Future<void> load({
    required String clubId,
    required String userId,
    Club? initialClub,
  }) async {
    _userId = userId;
    _state = ClubDetailLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _club = (await _clubRepository.fetchClubById(clubId, userId: userId)) ??
          initialClub;
      if (_club == null) {
        throw Exception('모임을 찾을 수 없습니다');
      }

      _isMember = await _clubRepository.isUserMember(clubId, userId);
      _myPendingRequest =
          await _joinRequestRepository.fetchPendingForUser(clubId, userId);

      if (_isMember && isAdmin) {
        _pendingRequests =
            await _joinRequestRepository.fetchPendingForClub(clubId);
      } else {
        _pendingRequests = [];
      }

      _state = ClubDetailLoadState.loaded;
    } catch (e) {
      _state = ClubDetailLoadState.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<bool> cancelMyJoinRequest() async {
    final club = _club;
    final userId = _userId;
    if (club == null || userId == null || userId.isEmpty) {
      return false;
    }
    var request = _myPendingRequest;
    request ??=
        await _joinRequestRepository.fetchPendingForUser(club.id, userId);

    _actionInProgress = true;
    notifyListeners();

    try {
      await _joinRequestRepository.cancelJoinRequest(
        clubId: club.id,
        requestId: request?.id ?? '',
        userId: userId,
      );
      _myPendingRequest = null;
      _isMember = false;
      _actionInProgress = false;
      notifyListeners();
      return true;
    } catch (e) {
      final raw = e.toString();
      _errorMessage = raw
          .replaceFirst('Bad state: ', '')
          .replaceFirst('Exception: ', '');
      _actionInProgress = false;
      notifyListeners();
      return false;
    }
  }

  /// 모임방(ClubProvider) 연동용 legacy ID — seed_c* → c*
  String? get legacyClubIdForRoom {
    const map = {
      'seed_c1': 'c1',
      'seed_c2': 'c2',
      'seed_c3': 'c3',
      'seed_c4': 'c4',
      'seed_c5': 'c5',
    };
    return map[_club?.id];
  }

  /// 탈퇴 후 재신청 — 스토어에 남은 멤버십 스냅샷을 무시
  void allowRejoinAfterLeave() {
    _isMember = false;
    _myPendingRequest = null;
    notifyListeners();
  }

  void markJoinPending(JoinRequest request) {
    _isMember = false;
    _myPendingRequest = request;
    notifyListeners();
  }

  Future<bool> submitJoinRequest({
    required AppUser user,
    String message = '',
    bool allowRejoin = false,
  }) async {
    final club = _club;
    if (club == null) return false;
    if (allowRejoin) {
      _isMember = false;
    }
    if (isPending) {
      _errorMessage = '이미 가입 신청 중입니다';
      notifyListeners();
      return false;
    }
    // 탈퇴 직후 UI는 가입 버튼인데 _isMember가 stale일 수 있음 → allowRejoin으로 통과
    if (!allowRejoin && !canSubmitJoin) {
      _errorMessage = '이미 가입된 모임이거나 신청할 수 없습니다';
      notifyListeners();
      return false;
    }

    _actionInProgress = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _joinRequestRepository.submitJoinRequest(
        clubId: club.id,
        userId: user.id,
        userName: user.name,
        userGender: '남',
        userHandicap: user.handicap,
        message: message,
      );
      _isMember = false;
      _myPendingRequest =
          await _joinRequestRepository.fetchPendingForUser(club.id, user.id);
      _actionInProgress = false;
      notifyListeners();
      return true;
    } catch (e) {
      final raw = e.toString();
      _errorMessage = raw
          .replaceFirst('Bad state: ', '')
          .replaceFirst('Exception: ', '');
      _actionInProgress = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> approveRequest(
    JoinRequest request, {
    required String memberType,
    required String reviewedBy,
    String role = '정회원',
  }) async {
    _actionInProgress = true;
    notifyListeners();

    try {
      await _joinRequestRepository.approveJoinRequest(
        request: request,
        memberType: memberType,
        role: role,
        reviewedBy: reviewedBy,
      );
      await load(clubId: request.clubId, userId: _userId ?? '');
      _actionInProgress = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _actionInProgress = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectRequest(
    JoinRequest request, {
    required String reviewedBy,
  }) async {
    _actionInProgress = true;
    notifyListeners();

    try {
      await _joinRequestRepository.rejectJoinRequest(
        clubId: request.clubId,
        requestId: request.id,
        reviewedBy: reviewedBy,
      );
      _pendingRequests.removeWhere((r) => r.id == request.id);
      _actionInProgress = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _actionInProgress = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTeamCount(int teamCount) async {
    final club = _club;
    if (club == null || !isAdmin) return false;

    _actionInProgress = true;
    notifyListeners();

    try {
      await _clubRepository.updateTeamCount(club.id, teamCount);
      _club = club.copyWith(teamCount: teamCount);
      _actionInProgress = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _actionInProgress = false;
      notifyListeners();
      return false;
    }
  }
}
