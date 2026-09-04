import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/admin_repository.dart';
import '../../../screens/admin/admin_models.dart';

/// 어드민 대시보드 상태 — Firestore/Mock [AdminRepository]에 연결
class AdminController extends ChangeNotifier {
  AdminController({required AdminRepository adminRepository})
      : _repo = adminRepository {
    _clubsSub = _repo.watchClubs().listen((clubs) {
      _clubs = clubs;
      _refreshStats();
      notifyListeners();
    }, onError: (e, _) {
      _error = '$e';
      notifyListeners();
    });
    _membersSub = _repo.watchMembers().listen((members) {
      _members = members;
      _refreshStats();
      notifyListeners();
    }, onError: (e, _) {
      _error = '$e';
      notifyListeners();
    });
  }

  final AdminRepository _repo;
  StreamSubscription<List<AdminClub>>? _clubsSub;
  StreamSubscription<List<AdminMember>>? _membersSub;

  List<AdminClub> _clubs = const [];
  List<AdminMember> _members = const [];
  DashboardStats _stats = const DashboardStats(
    totalMembers: 0,
    activeClubs: 0,
    todaySignups: 0,
    todayNewClubs: 0,
    weeklySignups: [0, 0, 0, 0, 0, 0, 0],
    weeklyClubs: [0, 0, 0, 0, 0, 0, 0],
  );
  String? _error;
  bool _busy = false;

  List<AdminClub> get clubs => _clubs;
  List<AdminMember> get members => _members;
  DashboardStats get stats => _stats;
  String? get error => _error;
  bool get isBusy => _busy;

  int get pendingClubCount =>
      _clubs.where((c) => c.status == 'pending').length;

  Future<void> _refreshStats() async {
    try {
      // 「최근 7일」= 오늘 포함 과거 6일 (달력 월~일 주가 아님)
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final today = _dateKey(todayDate);
      final weeklySignups = List<int>.filled(7, 0);
      final weeklyClubs = List<int>.filled(7, 0);
      final weeklyLabels = List<String>.filled(7, '');
      for (var i = 0; i < 7; i++) {
        final d = todayDate.subtract(Duration(days: 6 - i));
        final key = _dateKey(d);
        weeklyLabels[i] = '${d.month}/${d.day}';
        weeklySignups[i] =
            _members.where((m) => _dateKeyFromRaw(m.joinDate) == key).length;
        weeklyClubs[i] =
            _clubs.where((c) => _dateKeyFromRaw(c.createdDate) == key).length;
      }
      // 앱 모임찾기와 동일: active + pending (블라인드/종료 제외)
      final operatingClubs = _clubs
          .where((c) => c.status == 'active' || c.status == 'pending')
          .length;
      var todaySignups =
          _members.where((m) => _dateKeyFromRaw(m.joinDate) == today).length;
      // joinDate 누락 보정: 오늘 개설 모임의 호스트가 회원 목록에 있으면 가입으로 카운트
      if (todaySignups == 0) {
        final todayHosts = _clubs
            .where((c) => _dateKeyFromRaw(c.createdDate) == today)
            .map((c) => c.host)
            .where((h) => h.isNotEmpty && h != '-')
            .toSet();
        if (todayHosts.isNotEmpty) {
          todaySignups = _members
              .where((m) => todayHosts.contains(m.name))
              .length;
          if (todaySignups > 0) {
            weeklySignups[6] = weeklySignups[6] < todaySignups
                ? todaySignups
                : weeklySignups[6];
          }
        }
      }
      _stats = DashboardStats(
        totalMembers: _members.length,
        activeClubs: operatingClubs,
        todaySignups: todaySignups,
        todayNewClubs: _clubs
            .where((c) => _dateKeyFromRaw(c.createdDate) == today)
            .length,
        weeklySignups: weeklySignups,
        weeklyClubs: weeklyClubs,
        weeklyDayLabels: weeklyLabels,
      );
    } catch (e) {
      debugPrint('[AdminController] stats: $e');
    }
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// 날짜 문자열을 yyyy-MM-dd로 정규화 (로컬 자정 기준)
  static String _dateKeyFromRaw(String raw) {
    if (raw.isEmpty || raw == '-') return '';
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) return raw;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final d = parsed.toLocal();
    return _dateKey(d);
  }

  Future<void> updateClubStatus(String clubId, String status) async {
    _busy = true;
    notifyListeners();
    try {
      await _repo.updateClubModerationStatus(clubId, status);
      _error = null;
    } catch (e) {
      _error = '$e';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> resetMemberPhoneAuth(AdminMember member) async {
    _busy = true;
    notifyListeners();
    try {
      await _repo.resetMemberPhoneAuth(member.id);
      _error = null;
    } catch (e) {
      _error = '$e';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> toggleMemberBlock(AdminMember member) async {
    final next = member.status == 'blocked' ? 'normal' : 'blocked';
    _busy = true;
    notifyListeners();
    try {
      await _repo.updateMemberAccountStatus(member.id, next);
      _error = null;
    } catch (e) {
      _error = '$e';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _clubsSub?.cancel();
    _membersSub?.cancel();
    super.dispose();
  }
}
