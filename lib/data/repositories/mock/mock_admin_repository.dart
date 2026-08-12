import 'dart:async';

import 'package:intl/intl.dart';

import '../../../models/club_model.dart';
import '../../../screens/admin/admin_models.dart';
import '../admin_repository.dart';
import 'mock_data_store.dart';

/// 오프라인 Mock — 앱과 동일 [MockDataStore]를 공유해 어드민↔앱 동기화
class MockAdminRepository implements AdminRepository {
  MockAdminRepository(this._store) {
    _store.addListener(_emit);
    _emit();
  }

  final MockDataStore _store;
  static final _dateFmt = DateFormat('yyyy-MM-dd');

  final _clubsCtrl = StreamController<List<AdminClub>>.broadcast();
  final _membersCtrl = StreamController<List<AdminMember>>.broadcast();

  List<AdminClub> _clubs = const [];
  List<AdminMember> _members = const [];

  void _emit() {
    _clubs = _buildClubs();
    _members = _buildMembers();
    if (!_clubsCtrl.isClosed) _clubsCtrl.add(_clubs);
    if (!_membersCtrl.isClosed) _membersCtrl.add(_members);
  }

  List<AdminClub> _buildClubs() {
    return _store.clubs.map((c) {
      final members = _store.membersOf(c.id);
      Member? hostMember;
      for (final m in members) {
        if (m.id == c.creatorId || m.id == 'm_creator_${c.id}') {
          hostMember = m;
          break;
        }
      }
      hostMember ??= () {
        for (final m in members) {
          if (m.id != 'user_me') return m;
        }
        return null;
      }();
      // 앱과 동일: 게스트 제외 활성 정회원 수
      final regularCount = _regularMemberCount(c.id);
      return AdminClub(
        id: c.id,
        name: c.name,
        host: hostMember?.name ?? (c.creatorId.isEmpty ? '-' : c.creatorId),
        memberCount: regularCount > 0 ? regularCount : c.memberCount,
        createdDate: _dateFmt.format(c.createdAt),
        status: _store.clubModerationStatus(c.id),
        region: c.region,
        description: c.description.isEmpty ? null : c.description,
        maxMembers: _store.clubMaxMembers(c.id),
      );
    }).toList()
      ..sort((a, b) => b.createdDate.compareTo(a.createdDate));
  }

  /// 게스트·user_me alias 제외, seed↔c 별칭 합산
  int _regularMemberCount(String clubId) {
    final clubIds = <String>{clubId};
    if (clubId.startsWith('seed_')) {
      clubIds.add(clubId.substring(5));
    } else if (RegExp(r'^c\d+$').hasMatch(clubId)) {
      clubIds.add('seed_$clubId');
    }
    final seen = <String>{};
    var n = 0;
    for (final id in clubIds) {
      for (final m in _store.membersOf(id)) {
        if (m.status != '활성') continue;
        if (m.memberType == '게스트') continue;
        if (m.id == 'user_me') continue;
        final key =
            (m.phone != null && m.phone!.isNotEmpty) ? m.phone! : '${m.id}:${m.name}';
        if (!seen.add(key)) continue;
        n++;
      }
    }
    return n;
  }

  List<AdminMember> _buildMembers() {
    final byId = <String, _Agg>{};

    // 클럽 생성일 — 생성자 joinDate 보정용
    final clubCreated = <String, DateTime>{
      for (final c in _store.clubs) c.id: c.createdAt,
    };

    for (final entry in _store.membersByClub.entries) {
      final clubId = entry.key;
      for (final m in entry.value.values) {
        // 시드 데모 계정 alias는 플랫폼 회원 집계에서 제외
        if (m.id == 'user_me') continue;
        if (m.memberType == '게스트') continue;
        if (m.status != '활성') continue;

        var join = m.joinDate?.toLocal();
        // 생성자인데 가입일이 없으면 모임 개설일로 보정 → 오늘 가입자 집계
        if (join == null &&
            (m.id == 'm_creator_$clubId' || m.id == clubCreated[clubId]?.toString())) {
          join = clubCreated[clubId]?.toLocal();
        }
        if (join == null && m.id.startsWith('m_creator_')) {
          join = clubCreated[clubId]?.toLocal() ?? DateTime.now();
        }

        final existing = byId[m.id];
        if (existing == null) {
          byId[m.id] = _Agg(
            id: m.id,
            name: m.name,
            phone: m.phone ?? '',
            gender: m.gender,
            joinDate: join,
            clubCount: 1,
          );
        } else {
          existing.clubCount += 1;
          if (join != null &&
              (existing.joinDate == null || join.isBefore(existing.joinDate!))) {
            existing.joinDate = join;
          }
        }
      }
    }

    // 플랫폼 가입 사용자 (홍길동·이민준 포함, 모임 미가입도 표시)
    for (final u in _store.appUsers) {
      final created = u.createdAt.toLocal();
      final existing = byId[u.id];
      if (existing == null) {
        byId[u.id] = _Agg(
          id: u.id,
          name: u.name,
          phone: u.phone,
          gender: u.gender,
          joinDate: created,
          clubCount: 0,
        );
      } else {
        if (existing.phone.isEmpty && u.phone.isNotEmpty) {
          existing.phone = u.phone;
        }
        if (existing.joinDate == null || created.isBefore(existing.joinDate!)) {
          existing.joinDate = created;
        }
      }
    }

    // 동일 인물(전화/이름) 중복 제거 — m_creator_* + user_guest 등
    final deduped = <String, _Agg>{};
    for (final m in byId.values) {
      final key = m.phone.isNotEmpty
          ? 'p:${m.phone.replaceAll(RegExp(r'[^0-9]'), '')}'
          : 'n:${m.name}|${m.gender}';
      final prev = deduped[key];
      if (prev == null) {
        deduped[key] = m;
        continue;
      }
      prev.clubCount += m.clubCount;
      if (m.joinDate != null &&
          (prev.joinDate == null || m.joinDate!.isBefore(prev.joinDate!))) {
        prev.joinDate = m.joinDate;
      }
      // 플랫폼 계정 id(user_*) 우선 표시
      if (m.id.startsWith('user_') && !prev.id.startsWith('user_')) {
        prev.id = m.id;
        prev.phone = m.phone.isNotEmpty ? m.phone : prev.phone;
      }
    }

    return deduped.values.map((m) {
      final override = _store.memberClubCountOverride(m.id);
      return AdminMember(
        id: m.id,
        name: m.name,
        phone: m.phone,
        nickname: m.name,
        gender: m.gender,
        joinDate: m.joinDate != null ? _dateFmt.format(m.joinDate!.toLocal()) : '-',
        status: _store.userAccountStatus(m.id),
        clubCount: override ?? m.clubCount,
      );
    }).toList()
      ..sort((a, b) => b.joinDate.compareTo(a.joinDate));
  }

  @override
  Stream<List<AdminClub>> watchClubs() async* {
    // 구독 시점마다 최신 스냅샷 (broadcast 이벤트 유실 방지)
    _emit();
    yield _clubs;
    yield* _clubsCtrl.stream;
  }

  @override
  Stream<List<AdminMember>> watchMembers() async* {
    yield _members;
    yield* _membersCtrl.stream;
  }

  @override
  Future<DashboardStats> fetchStats() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = _dateFmt.format(today);
    final weekday = now.weekday;
    final weekStart = today.subtract(Duration(days: weekday - 1));
    final weeklySignups = List<int>.filled(7, 0);
    final weeklyClubs = List<int>.filled(7, 0);
    for (var i = 0; i < 7; i++) {
      final key = _dateFmt.format(weekStart.add(Duration(days: i)));
      weeklySignups[i] =
          _members.where((m) => m.joinDate == key).length;
      weeklyClubs[i] = _clubs.where((c) => c.createdDate == key).length;
    }
    // joinDate가 '-'인 신규 생성자: 오늘 개설 모임의 호스트 이름으로 보정 카운트
    final todayHostNames = _clubs
        .where((c) => c.createdDate == todayStr)
        .map((c) => c.host)
        .where((h) => h.isNotEmpty && h != '-')
        .toSet();
    var todaySignups =
        _members.where((m) => m.joinDate == todayStr).length;
    if (todaySignups == 0 && todayHostNames.isNotEmpty) {
      todaySignups = _members
          .where((m) =>
              (m.joinDate == todayStr || m.joinDate == '-') &&
              todayHostNames.contains(m.name))
          .length;
    }
    return DashboardStats(
      totalMembers: _members.length,
      activeClubs: _clubs
          .where((c) => c.status == 'active' || c.status == 'pending')
          .length,
      todaySignups: todaySignups,
      todayNewClubs: _clubs.where((c) => c.createdDate == todayStr).length,
      weeklySignups: weeklySignups,
      weeklyClubs: weeklyClubs,
    );
  }

  @override
  Future<void> updateClubModerationStatus(String clubId, String status) async {
    _store.setClubModerationStatus(clubId, status);
  }

  @override
  Future<void> updateMemberAccountStatus(String userId, String status) async {
    _store.setUserAccountStatus(userId, status);
  }

  void dispose() {
    _store.removeListener(_emit);
    _clubsCtrl.close();
    _membersCtrl.close();
  }
}

class _Agg {
  _Agg({
    required this.id,
    required this.name,
    required this.phone,
    required this.gender,
    required this.joinDate,
    required this.clubCount,
  });

  String id;
  String name;
  String phone;
  String gender;
  DateTime? joinDate;
  int clubCount;
}
