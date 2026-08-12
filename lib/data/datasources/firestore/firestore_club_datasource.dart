import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/data_exception.dart';
import '../../../core/firebase/firestore_paths.dart';
import '../../../models/club_model.dart';
import '../../mappers/club_mapper.dart';
import '../../mappers/member_mapper.dart';

/// clubs 컬렉션 Raw I/O (Repository 하위 계층)
class FirestoreClubDataSource {
  FirestoreClubDataSource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _clubs =>
      _db.collection(FirestorePaths.clubs);

  Future<List<Club>> fetchAllClubs({String defaultMyRole = '일반'}) async {
    try {
      final snap = await _fetchAllClubDocs();
      final clubs = snap.docs
          .where(_isDiscoverable)
          .map((d) => ClubMapper.fromFirestore(d, myRole: defaultMyRole))
          .toList();
      clubs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return clubs;
    } on FirebaseException catch (e) {
      throw NetworkDataException(
        'clubs 조회 실패 (${e.code}: ${e.message})',
        cause: e,
      );
    }
  }

  /// 블라인드·종료만 탐색 숨김
  bool _isDiscoverable(DocumentSnapshot<Map<String, dynamic>> doc) {
    final status = doc.data()?['moderation_status'] as String?;
    if (status == null || status.isEmpty) return true;
    return status == 'active' || status == 'pending';
  }

  /// orderBy 실패·created_at 누락 문서 대비 — unordered 조회 fallback
  Future<QuerySnapshot<Map<String, dynamic>>> _fetchAllClubDocs() async {
    try {
      final ordered = await _clubs.orderBy('created_at', descending: true).get();
      if (ordered.docs.isNotEmpty) return ordered;
    } on FirebaseException catch (e) {
      debugPrint(
        '[FirestoreClubDataSource] orderBy(created_at) 실패 — '
        'unordered fallback (${e.code})',
      );
    }

    return _clubs.get();
  }

  Future<bool> isCatalogEmpty() async {
    final snap = await _clubs.limit(1).get();
    return snap.docs.isEmpty;
  }

  Future<void> seedSampleClubs(List<Club> clubs) async {
    if (clubs.isEmpty) return;
    try {
      final batch = _db.batch();
      for (final club in clubs) {
        batch.set(
          _clubs.doc(club.id),
          ClubMapper.toMap(club),
          SetOptions(merge: true),
        );
      }
      batch.set(
        _db.doc(FirestorePaths.metaClubCatalog),
        {
          'seeded_at': FieldValue.serverTimestamp(),
          'count': clubs.length,
          'version': 1,
        },
        SetOptions(merge: true),
      );
      await batch.commit();
    } on FirebaseException catch (e) {
      throw NetworkDataException('clubs 시드 실패', cause: e);
    }
  }

  /// 사용자 생성 모임 — 어드민 검수(pending) + 생성자 멤버십 포함
  Future<void> createUserClub({
    required Club club,
    required String userId,
    required String userName,
    required Member creatorMember,
    String moderationStatus = 'active',
  }) async {
    try {
      final batch = _db.batch();
      final data = ClubMapper.toMap(club);
      data['is_sample'] = false;
      data['moderation_status'] = moderationStatus;
      data['host_name'] = userName;

      batch.set(_clubs.doc(club.id), data, SetOptions(merge: true));

      batch.set(
        _db.doc(FirestorePaths.userMembershipDoc(userId, club.id)),
        {
          'user_id': userId,
          'club_id': club.id,
          'role': creatorMember.role,
          'created_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final memberData = MemberMapper.toMap(creatorMember);
      memberData['user_id'] = userId;
      batch.set(
        _db.doc(FirestorePaths.clubMemberDoc(club.id, userId)),
        memberData,
        SetOptions(merge: true),
      );

      batch.set(
        _db.collection(FirestorePaths.users).doc(userId),
        {
          'name': userName,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
    } on FirebaseException catch (e) {
      throw NetworkDataException('모임 생성 실패', cause: e);
    }
  }

  Future<List<Club>> fetchMyClubs(
    String userId, {
    String defaultMyRole = '일반',
  }) async {
    try {
      final membershipSnap = await _db
          .collection(FirestorePaths.userMemberships)
          .where('user_id', isEqualTo: userId)
          .get();

      if (membershipSnap.docs.isEmpty) return [];

      final clubIds = membershipSnap.docs
          .map((d) => d.data()['club_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      if (clubIds.length <= 10) {
        final snap = await _clubs
            .where(FieldPath.documentId, whereIn: clubIds)
            .get();
        return snap.docs.map((d) {
          final role = membershipSnap.docs
              .firstWhere(
                (m) => m.data()['club_id'] == d.id,
                orElse: () => membershipSnap.docs.first,
              )
              .data()['role'] as String?;
          return ClubMapper.fromFirestore(
            d,
            myRole: role ?? defaultMyRole,
          );
        }).toList();
      }

      final all = await fetchAllClubs(defaultMyRole: defaultMyRole);
      return all.where((c) => clubIds.contains(c.id)).toList();
    } on FirebaseException catch (e) {
      throw NetworkDataException('내 모임 조회 실패', cause: e);
    }
  }

  Stream<List<Club>> watchAllClubs({String defaultMyRole = '일반'}) {
    return _clubs.orderBy('created_at', descending: true).snapshots().map(
          (snap) => snap.docs
              .where(_isDiscoverable)
              .map((d) => ClubMapper.fromFirestore(d, myRole: defaultMyRole))
              .toList(),
        );
  }

  Future<Club?> fetchClubById(
    String clubId, {
    String userId = '',
    String defaultMyRole = '일반',
  }) async {
    try {
      final doc = await _clubs.doc(clubId).get();
      if (!doc.exists) return null;
      final role = userId.isEmpty
          ? defaultMyRole
          : await fetchUserRoleInClub(clubId, userId) ?? defaultMyRole;
      return ClubMapper.fromFirestore(doc, myRole: role);
    } on FirebaseException catch (e) {
      throw NetworkDataException('모임 상세 조회 실패', cause: e);
    }
  }

  Future<String?> fetchUserRoleInClub(String clubId, String userId) async {
    try {
      final snap = await _db
          .collection(FirestorePaths.userMemberships)
          .where('user_id', isEqualTo: userId)
          .where('club_id', isEqualTo: clubId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.data()['role'] as String?;
    } on FirebaseException catch (e) {
      throw NetworkDataException('멤버십 조회 실패', cause: e);
    }
  }

  Future<bool> isUserMember(String clubId, String userId) async {
    final role = await fetchUserRoleInClub(clubId, userId);
    return role != null;
  }

  Future<void> updateTeamCount(String clubId, int teamCount) async {
    await updateClubInfo(clubId, teamCount: teamCount);
  }

  Future<void> updateClubInfo(
    String clubId, {
    String? name,
    String? description,
    String? imageUrl,
    int? teamCount,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (imageUrl != null) data['image_url'] = imageUrl;
      if (teamCount != null) data['team_count'] = teamCount;
      await _clubs.doc(clubId).update(data);
    } on FirebaseException catch (e) {
      throw NetworkDataException('모임 정보 업데이트 실패', cause: e);
    }
  }
}
