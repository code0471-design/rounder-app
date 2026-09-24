import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firestore_paths.dart';

/// 모임찾기 회원수 = 만든 사람·초대·승인으로 생긴 서버 멤버십 수.
/// 폰 명단·increment 로는 쓰지 않는다.
Future<int> recountClubMemberCount(
  FirebaseFirestore db,
  String clubId,
) async {
  if (clubId.trim().isEmpty) return 0;
  final snap = await db
      .collection(FirestorePaths.userMemberships)
      .where('club_id', isEqualTo: clubId)
      .get();
  final ids = <String>{};
  for (final d in snap.docs) {
    final uid = '${d.data()['user_id'] ?? ''}'.trim();
    if (uid.isNotEmpty) ids.add(uid);
  }
  final n = ids.length;
  final club = db.doc(FirestorePaths.clubDoc(clubId));
  final existing = await club.get();
  if (!existing.exists) return n;
  await club.update({
    'member_count': n,
    'updated_at': FieldValue.serverTimestamp(),
  });
  return n;
}
