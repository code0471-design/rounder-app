import 'package:flutter/foundation.dart';

import '../../../data/repositories/club_repository.dart';
import '../../../data/repositories/join_request_repository.dart';
import '../../../di/app_dependencies.dart';
import '../../../domain/data/club_sample_catalog.dart';
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

  ClubListLoadState _state = ClubListLoadState.idle;
  List<Club> _clubs = [];
  String? _errorMessage;

  String _region = '전체';
  String _industry = '전체';
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

  /// 내 모임·가입 신청 상태 동기화 (상세 화면 복귀 후 호출)
  Future<void> syncMembershipState(String userId) async {
    final joinRepo =
        _joinRequestRepository ?? AppDependencies.instance.joinRequestRepository;
    final myClubs = await _clubRepository.fetchMyClubs(userId);
    _myClubIds = myClubs.map((c) => c.id).toSet();

    final pending = <String>{};
    for (final club in _clubs) {
      final req = await joinRepo.fetchPendingForUser(club.id, userId);
      if (req != null) pending.add(club.id);
    }
    _pendingClubIds = pending;
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
        _clubs = await _clubRepository.fetchDiscoverableClubs();
        if (userId != null && userId.isNotEmpty) {
          await syncMembershipState(userId);
        }
        _state = ClubListLoadState.loaded;
        notifyListeners();
        return;
      }

      final seeded = await _safeSeedIfEmpty();
      if (seeded) {
        debugPrint('[ClubListController] Firestore 샘플 모임 시드 완료');
      }

      _clubs = await _clubRepository.fetchDiscoverableClubs();
      debugPrint('[ClubListController] Firestore clubs ${_clubs.length}건');

      if (_clubs.isEmpty) {
        _clubs = ClubSampleCatalog.clubs;
        _usingLocalFallback = true;
        debugPrint('[ClubListController] 로컬 샘플 폴백 ${_clubs.length}건');
      }

      _state = ClubListLoadState.loaded;
    } catch (e, st) {
      debugPrint('[ClubListController] load 실패: $e\n$st');
      _clubs = ClubSampleCatalog.clubs;
      _usingLocalFallback = true;
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
