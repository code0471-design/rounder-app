import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/data_exception.dart';
import '../../../core/firebase/firestore_paths.dart';
import '../../../models/club_model.dart';
import '../../mappers/join_request_mapper.dart';
import '../../mappers/member_mapper.dart';

class FirestoreJoinRequestDataSource {
  FirestoreJoinRequestDataSource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _requests(String clubId) =>
      _db.collection(FirestorePaths.clubJoinRequests(clubId));

  Future<List<JoinRequest>> fetchPendingForClub(String clubId) async {
    try {
      final snap = await _requests(clubId)
          .where('status', isEqualTo: JoinRequestStatus.pending.name)
          .orderBy('requested_at', descending: true)
          .get();
      return snap.docs
          .map((d) => JoinRequestMapper.fromFirestore(d, clubId: clubId))
          .toList();
    } on FirebaseException catch (e) {
      throw NetworkDataException('가입 신청 목록 조회 실패', cause: e);
    }
  }

  Future<JoinRequest?> fetchPendingForUser(
    String clubId,
    String userId,
  ) async {
    try {
      final snap = await _requests(clubId)
          .where('user_id', isEqualTo: userId)
          .where('status', isEqualTo: JoinRequestStatus.pending.name)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return JoinRequestMapper.fromFirestore(snap.docs.first, clubId: clubId);
    } on FirebaseException catch (e) {
      throw NetworkDataException('내 가입 신청 조회 실패', cause: e);
    }
  }

  Future<String> submit({
    required String clubId,
    required String userId,
    required String userName,
    required String userGender,
    double? userHandicap,
    required String message,
  }) async {
    try {
      final existing = await fetchPendingForUser(clubId, userId);
      if (existing != null) {
        throw const NetworkDataException('이미 가입 신청 중입니다');
      }

      final doc = _requests(clubId).doc();
      await doc.set(JoinRequestMapper.toSubmitMap(
        userId: userId,
        userName: userName,
        userGender: userGender,
        userHandicap: userHandicap,
        message: message,
      ));
      return doc.id;
    } on FirebaseException catch (e) {
      throw NetworkDataException('가입 신청 저장 실패', cause: e);
    }
  }

  Future<void> approve({
    required JoinRequest request,
    required String memberType,
    required String role,
    required String reviewedBy,
  }) async {
    try {
      final batch = _db.batch();
      final clubId = request.clubId;
      final requestRef = _db.doc(
        FirestorePaths.clubJoinRequestDoc(clubId, request.id),
      );
      final memberRef = _db.doc(
        FirestorePaths.clubMemberDoc(clubId, request.userId),
      );
      final membershipRef = _db.doc(
        FirestorePaths.userMembershipDoc(request.userId, clubId),
      );
      final clubRef = _db.doc(FirestorePaths.clubDoc(clubId));

      batch.update(
        requestRef,
        JoinRequestMapper.toReviewMap(
          status: JoinRequestStatus.approved,
          reviewedBy: reviewedBy,
        ),
      );

      final member = Member(
        id: request.userId,
        name: request.userName,
        gender: request.userGender,
        memberType: memberType,
        role: role,
        handicap: request.userHandicap,
        joinDate: DateTime.now(),
        status: '활성',
      );
      batch.set(memberRef, MemberMapper.toMap(member), SetOptions(merge: true));

      batch.set(membershipRef, {
        'user_id': request.userId,
        'club_id': clubId,
        'role': role,
        'member_type': memberType,
        'joined_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.update(clubRef, {
        'member_count': FieldValue.increment(1),
        'updated_at': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } on FirebaseException catch (e) {
      throw NetworkDataException('가입 승인 처리 실패', cause: e);
    }
  }

  Future<void> reject({
    required String clubId,
    required String requestId,
    required String reviewedBy,
  }) async {
    try {
      await _db.doc(FirestorePaths.clubJoinRequestDoc(clubId, requestId)).update(
        JoinRequestMapper.toReviewMap(
          status: JoinRequestStatus.rejected,
          reviewedBy: reviewedBy,
        ),
      );
    } on FirebaseException catch (e) {
      throw NetworkDataException('가입 거절 처리 실패', cause: e);
    }
  }

  Future<void> cancel({
    required String clubId,
    required String requestId,
    required String userId,
  }) async {
    try {
      final ref = _db.doc(FirestorePaths.clubJoinRequestDoc(clubId, requestId));
      final snap = await ref.get();
      if (!snap.exists) {
        throw const NetworkDataException('가입 신청을 찾을 수 없습니다');
      }
      final data = snap.data();
      if (data?['user_id'] != userId) {
        throw const NetworkDataException('본인의 가입 신청만 취소할 수 있습니다');
      }
      await ref.update(
        JoinRequestMapper.toReviewMap(
          status: JoinRequestStatus.rejected,
          reviewedBy: userId,
        ),
      );
    } on FirebaseException catch (e) {
      throw NetworkDataException('가입 신청 취소 실패', cause: e);
    }
  }
}
