import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/club_repository.dart';
import '../../../data/repositories/join_request_repository.dart';
import '../../../di/app_dependencies.dart';
import '../../../domain/data/sample_club_filter.dart';
import '../../../domain/services/club_discovery_service.dart';
import '../../../models/club_model.dart';

enum ClubListLoadState { idle, loading, loaded, error }

/// 모임 목록 대시보드 — UI와 Firestore 사이 Application Layer
class ClubListController extends ChangeNotifier {
  ClubListController({
    required ClubRepository clubRepository,
    JoinRequestRepository? joinRequestRepository,
    Set<String>? myClubIds,
    Set<String>? pendingClubIds,
  })  : _clubRepository = clubRepository,
        _joinRequestRepository = joinRequestRepository,
        _myClubIds = myClubIds ?? {},
        _pendingClubIds = pendingClubIds ?? {};

  final ClubRepository _clubRepository;
  final JoinRequestRepository? _joinRequestRepository;
  Set<String> _myClubIds;
  Set<String> _pendingClubIds;
  Set<String> _checkedPendingClubIds = {};

  ClubListLoadState _state = ClubListLoadState.idle;
  List<Club> _clubs = [];
  String? _errorMessage;

  String _region = kRegionFilterAll;
  String _industry = kIndustryFilterAll;
  String _keyword = '';
  bool _usingLocalFallback = false;

  ClubListLoadState get state => _state;
  String? get errorMessage => _errorMessage;
  List<Club> get clubs => _clubs;
  bool get usingLocalFallback => _usingLocalFallback;
  String get region => _region;
  String get industry => _industry;
  String get keyword => _keyword;
  List<Club> get filteredClubs => ClubDiscoveryService.filter(
        clubs: _clubs,
        region: _region,
        industry: _industry,
        keyword: _keyword,
      );

  void updateFilters({
    String? region,
    String? industry,
    String? keyword,
  }) {
    if (region != null) _region = region;
    if (industry != null) _industry = industry;
    if (keyword != null) _keyword = keyword;
    notifyListeners();
  }

  void updateMembershipHints({
    Set<String>? myClubIds,
    Set<String>? pendingClubIds,
  }) {
    if (myClubIds != null) _myClubIds = myClubIds;
    if (pendingClubIds != null) _pendingClubIds = pendingClubIds;
    notifyListeners();
  }

  bool isMyClub(String clubId) => _myClubIds.contains(clubId);
  bool hasPendingRequest(String clubId) => _pendingClubIds.contains(clubId);
  Set<String> get pendingClubIds => Set.unmodifiable(_pendingClubIds);
  Set<String> get checkedPendingClubIds =>
      Set.unmodifiable(_checkedPendingClubIds);

  /// 내 모임·가입 신청 상태 동기화 (상세 화면 복귀 후 호출)
  Future<void> syncMembershipState(String userId) async {
    final joinRepo =
        _joinRequestRepository ?? AppDependencies.instance.joinRequestRepository;
    // 홈에서 이미 넘긴 내 모임 id가 있으면 카탈로그를 다시 받지 않는다.
    if (_myClubIds.isEmpty) {
      final myClubs = await _clubRepository.fetchMyClubs(userId);
      _myClubIds = myClubs.map((c) => c.id).toSet();
    }

    final pending = <String>{};
    final checked = <String>{};
    final results = await Future.wait(_clubs.map((club) async {
      try {
        final req = await joinRepo.fetchPendingForUser(club.id, userId);
        return (id: club.id, pending: req != null, checked: true);
      } catch (e) {
        debugPrint('[ClubListController] pending skip ${club.id}: $e');
        return (id: club.id, pending: false, checked: false);
      }
    }));
    for (final row in results) {
      if (row.checked) checked.add(row.id);
      if (row.pending) pending.add(row.id);
    }
    _pendingClubIds = pending;
    _checkedPendingClubIds = checked;
    notifyListeners();
  }

  void markPending(String clubId) {
    _pendingClubIds = {..._pendingClubIds, clubId};
    notifyListeners();
  }

  Future<bool> _safeSeedIfEmpty() async {
    if (AppDependencies.instance.isOfflineMockMode) return false;
    try {
      return await AppDependencies.instance.ensureClubCatalogSeeded();
    } catch (e) {
      debugPrint('[ClubListController] seed skip: $e');
      return false;
    }
  }

  Future<void> load({String? userId}) async {
    _state = ClubListLoadState.loading;
    _errorMessage = null;
    _usingLocalFallback = AppDependencies.instance.isOfflineMockMode;
    notifyListeners();

    try {
      if (AppDependencies.instance.isOfflineMockMode) {
        _clubs = (await _clubRepository
                .fetchDiscoverableClubs()
                .timeout(const Duration(seconds: 8)))
            .where((c) => !SampleClubFilter.isSample(id: c.id, name: c.name))
            .toList();
        if (userId != null && userId.isNotEmpty) {
          await syncMembershipState(userId);
        }
        _state = ClubListLoadState.loaded;
        notifyListeners();
        return;
      }

      unawaited(_safeSeedIfEmpty());

      _clubs = (await _clubRepository
              .fetchDiscoverableClubs()
              .timeout(const Duration(seconds: 8)))
          .where((c) => !SampleClubFilter.isSample(id: c.id, name: c.name))
          .toList();
      debugPrint('[ClubListController] Firestore clubs ${_clubs.length}건');
      _usingLocalFallback = false;
      _state = ClubListLoadState.loaded;
      notifyListeners();

      if (userId != null && userId.isNotEmpty) {
        try {
          await syncMembershipState(userId);
        } catch (e) {
          debugPrint('[ClubListController] membership skip: $e');
        }
      }
    } catch (e, st) {
      debugPrint('[ClubListController] load 실패: $e\n$st');
      // 테스터에게 전체 에러 화면을 띄우지 않는다. 내 모임은 화면에 남긴다.
      _clubs = [];
      _usingLocalFallback = false;
      _state = ClubListLoadState.loaded;
      _errorMessage = null;
    }
    notifyListeners();
  }

  /// 빈 Firestore에 샘플 업로드 후 재조회 (수동 트리거)
  Future<void> seedAndReload() async {
    await _safeSeedIfEmpty();
    await load();
  }

  Future<void> refresh({String? userId}) => load(userId: userId);
}
