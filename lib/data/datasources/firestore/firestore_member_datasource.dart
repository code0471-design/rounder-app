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
      // join_date 없는 문서는 orderBy 에서 빠져 정회원 화면에
      // 본인만 남는 원인이었다. 정렬은 메모리에서 한다.
      final snap =
          await _db.collection(FirestorePaths.clubMembers(clubId)).get();
      final members = snap.docs.map(MemberMapper.fromFirestore).toList();
      members.sort((a, b) => (b.joinDate ?? DateTime(0))
          .compareTo(a.joinDate ?? DateTime(0)));
      return members;
    } on FirebaseException catch (e) {
      throw NetworkDataException('members 조회 실패 ($clubId)', cause: e);
    }
  }

  Stream<List<Member>> watchMembers(String clubId) {
    return _db
        .collection(FirestorePaths.clubMembers(clubId))
        .snapshots()
        .map((snap) {
      final members = snap.docs.map(MemberMapper.fromFirestore).toList();
      members.sort((a, b) => (b.joinDate ?? DateTime(0))
          .compareTo(a.joinDate ?? DateTime(0)));
      return members;
    });
  }
}
