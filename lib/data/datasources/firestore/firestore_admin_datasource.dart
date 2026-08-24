import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/data_exception.dart';
import '../../../core/firebase/firestore_paths.dart';
import '../../../screens/admin/admin_models.dart';

/// 어드민용 Firestore Raw I/O — 앱과 동일 `clubs` / `members` / `users` 경로
class FirestoreAdminDataSource {
  FirestoreAdminDataSource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static final _dateFmt = DateFormat('yyyy-MM-dd');

  CollectionReference<Map<String, dynamic>> get _clubs =>
      _db.collection(FirestorePaths.clubs);

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(FirestorePaths.users);

  Stream<List<AdminClub>> watchClubs() {
    return _clubs.snapshots().asyncMap((snap) async {
      final clubs = <AdminClub>[];
      for (final doc in snap.docs) {
        clubs.add(await _clubFromDoc(doc));
      }
      clubs.sort((a, b) => b.createdDate.compareTo(a.createdDate));
      return clubs;
    });
  }

  Future<AdminClub> _clubFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data() ?? const <String, dynamic>{};
    final creatorId = data['creator_id'] as String? ?? '';
    var host = data['host_name'] as String? ?? '';
    if (host.isEmpty && creatorId.isNotEmpty) {
      host = await _resolveUserName(creatorId);
    }
    if (host.isEmpty) host = creatorId.isEmpty ? '-' : creatorId;

    final created = _asDateTime(data['created_at'] ?? data['createdAt']);
    final status = (data['moderation_status'] as String?)?.trim();
    return AdminClub(
      id: doc.id,
      name: data['name'] as String? ?? '',
      host: host,
      memberCount: _asInt(data['member_count'] ?? data['memberCount']),
      createdDate: created != null ? _dateFmt.format(created) : '-',
      status: (status == null || status.isEmpty) ? 'active' : status,
      region: data['region'] as String? ?? '',
      description: data['description'] as String?,
      maxMembers: _asInt(data['max_members'] ?? data['maxMembers'], fallback: 20),
    );
  }

  Future<String> _resolveUserName(String userId) async {
    try {
      final userDoc = await _users.doc(userId).get();
      final name = userDoc.data()?['name'] as String?;
      if (name != null && name.isNotEmpty) return name;

      // users 문서 없으면 멤버십 → 클럽 멤버 프로필에서 이름 조회
      final memberships = await _db
          .collection(FirestorePaths.userMemberships)
          .where('user_id', isEqualTo: userId)
          .limit(1)
          .get();
      if (memberships.docs.isEmpty) return '';
      final clubId = memberships.docs.first.data()['club_id'] as String?;
      if (clubId == null) return '';
      final member = await _db.doc(FirestorePaths.clubMemberDoc(clubId, userId)).get();
      return member.data()?['name'] as String? ?? '';
    } catch (e) {
      debugPrint('[FirestoreAdminDataSource] host resolve failed: $e');
      return '';
    }
  }

  /// 회원 = `users` 우선, 없으면 클럽 `members` collectionGroup 집계
  Stream<List<AdminMember>> watchMembers() {
    return _users.snapshots().asyncMap((usersSnap) async {
      if (usersSnap.docs.isNotEmpty) {
        return _membersFromUsers(usersSnap.docs);
      }
      return _membersFromClubMembers();
    });
  }

  Future<List<AdminMember>> _membersFromUsers(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final membershipCounts = await _membershipCountsByUser();
    final list = docs.map((doc) {
      final data = doc.data();
      final created = _asDateTime(data['created_at'] ?? data['createdAt']);
      final lastLogin = _asDateTime(data['last_login'] ?? data['lastLogin']);
      final status = data['account_status'] as String? ?? 'normal';
      return AdminMember(
        id: doc.id,
        name: data['name'] as String? ?? '',
        phone: data['phone'] as String? ?? '',
        nickname: data['nickname'] as String? ?? data['name'] as String? ?? '',
        gender: data['gender'] as String? ?? '남',
        joinDate: created != null ? _dateFmt.format(created.toLocal()) : '-',
        status: status == 'blocked' ? 'blocked' : 'normal',
        clubCount: membershipCounts[doc.id] ?? 0,
        email: data['email'] as String?,
        lastLogin: lastLogin != null
            ? _dateFmt.format(lastLogin.toLocal())
            : null,
      );
    }).toList();
    list.sort((a, b) => b.joinDate.compareTo(a.joinDate));
    return list;
  }

  Future<List<AdminMember>> _membersFromClubMembers() async {
    try {
      final snap = await _db.collectionGroup(FirestorePaths.members).get();
      final byUser = <String, _AggMember>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final id = doc.id;
        final existing = byUser[id];
        final join = _asDateTime(data['join_date'] ?? data['joinDate']);
        if (existing == null) {
          byUser[id] = _AggMember(
            id: id,
            name: data['name'] as String? ?? '',
            phone: data['phone'] as String? ?? '',
            gender: data['gender'] as String? ?? '남',
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

      // users 차단 상태 병합
      final blocked = <String>{};
      try {
        final blockedSnap = await _users
            .where('account_status', isEqualTo: 'blocked')
            .get();
        blocked.addAll(blockedSnap.docs.map((d) => d.id));
      } catch (_) {}

      final list = byUser.values.map((m) {
        return AdminMember(
          id: m.id,
          name: m.name,
          phone: m.phone,
          nickname: m.name,
          gender: m.gender,
          joinDate: m.joinDate != null
              ? _dateFmt.format(m.joinDate!.toLocal())
              : '-',
          status: blocked.contains(m.id) ? 'blocked' : 'normal',
          clubCount: m.clubCount,
        );
      }).toList();
      list.sort((a, b) => b.joinDate.compareTo(a.joinDate));
      return list;
    } on FirebaseException catch (e) {
      throw NetworkDataException(
        'members 집계 실패 (${e.code}: ${e.message})',
        cause: e,
      );
    }
  }

  Future<Map<String, int>> _membershipCountsByUser() async {
    try {
      final snap = await _db.collection(FirestorePaths.userMemberships).get();
      final counts = <String, int>{};
      for (final doc in snap.docs) {
        final uid = doc.data()['user_id'] as String?;
        if (uid == null) continue;
        counts[uid] = (counts[uid] ?? 0) + 1;
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  Future<DashboardStats> fetchStats({
    required List<AdminMember> members,
    required List<AdminClub> clubs,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = _dateFmt.format(today);

    final todaySignups =
        members.where((m) => m.joinDate == todayStr).length;
    final todayNewClubs =
        clubs.where((c) => c.createdDate == todayStr).length;
    final activeClubs =
        clubs.where((c) => c.status == 'active').length;

    final weeklySignups = List<int>.filled(7, 0);
    final weeklyClubs = List<int>.filled(7, 0);
    final weeklyLabels = List<String>.filled(7, '');
    // index 0 = 6일 전 … 6 = 오늘 (최근 7일)
    for (var i = 0; i < 7; i++) {
      final day = today.subtract(Duration(days: 6 - i));
      final key = _dateFmt.format(day);
      weeklyLabels[i] = '${day.month}/${day.day}';
      weeklySignups[i] = members.where((m) => m.joinDate == key).length;
      weeklyClubs[i] = clubs.where((c) => c.createdDate == key).length;
    }

    return DashboardStats(
      totalMembers: members.length,
      activeClubs: activeClubs,
      todaySignups: todaySignups,
      todayNewClubs: todayNewClubs,
      weeklySignups: weeklySignups,
      weeklyClubs: weeklyClubs,
      weeklyDayLabels: weeklyLabels,
    );
  }

  Future<void> updateClubModerationStatus(String clubId, String status) async {
    try {
      await _clubs.doc(clubId).set(
        {
          'moderation_status': status,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      throw NetworkDataException('모임 상태 변경 실패', cause: e);
    }
  }

  Future<void> updateMemberAccountStatus(String userId, String status) async {
    try {
      await _users.doc(userId).set(
        {
          'account_status': status,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      throw NetworkDataException('회원 상태 변경 실패', cause: e);
    }
  }

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? fallback;
  }

  static DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}

class _AggMember {
  _AggMember({
    required this.id,
    required this.name,
    required this.phone,
    required this.gender,
    required this.joinDate,
    required this.clubCount,
  });

  final String id;
  String name;
  String phone;
  String gender;
  DateTime? joinDate;
  int clubCount;
}
