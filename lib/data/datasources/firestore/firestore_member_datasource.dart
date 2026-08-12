import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/data_exception.dart';
import '../../../core/firebase/firestore_paths.dart';
import '../../../models/club_model.dart';
import '../../mappers/member_mapper.dart';

class FirestoreMemberDataSource {
  FirestoreMemberDataSource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<List<Member>> fetchMembers(String clubId) async {
    try {
      final snap = await _db
          .collection(FirestorePaths.clubMembers(clubId))
          .orderBy('join_date', descending: true)
          .get();
      return snap.docs.map(MemberMapper.fromFirestore).toList();
    } on FirebaseException catch (e) {
      throw NetworkDataException('members 조회 실패 ($clubId)', cause: e);
    }
  }

  Stream<List<Member>> watchMembers(String clubId) {
    return _db
        .collection(FirestorePaths.clubMembers(clubId))
        .orderBy('join_date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(MemberMapper.fromFirestore).toList());
  }
}
