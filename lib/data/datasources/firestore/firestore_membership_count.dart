import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firestore_paths.dart';

/// 모임 회원수 = 서버 명단의 활성 인원. 게스트를 포함한다.
/// 명단 문서가 없을 때만 user_memberships 를 센다.
/// 폰이 자기 숫자로 increment 하지 않는다.
Future<int> recountClubMemberCount(
  FirebaseFirestore db,
  String clubId,
) async {
  if (clubId.trim().isEmpty) return 0;
  final club = db.doc(FirestorePaths.clubDoc(clubId));
  final existing = await club.get();
  final creator =
      '${existing.data()?['creator_id'] ?? existing.data()?['creatorId'] ?? ''}'
          .trim();
  final memberSnap = await db
      .collection(FirestorePaths.clubs)
      .doc(clubId)
      .collection(FirestorePaths.members)
      .get();
  final people = <String>{};
  for (final d in memberSnap.docs) {
    final data = d.data();
    final status = '${data['status'] ?? '활성'}'.trim();
    if (status == '탈퇴' || status == '강퇴') continue;
    final key = _rosterPersonKey(clubId, creator, data, d.id);
    if (key.isNotEmpty) people.add(key);
  }
  var n = people.length;
  if (n == 0) {
    final snap = await db
        .collection(FirestorePaths.userMemberships)
        .where('club_id', isEqualTo: clubId)
        .get();
    final ids = <String>{};
    for (final d in snap.docs) {
      final uid = '${d.data()['user_id'] ?? ''}'.trim();
      if (uid.isNotEmpty) ids.add(uid);
    }
    n = ids.length;
  }
  if (!existing.exists) return n;
  await club.update({
    'member_count': n,
    'updated_at': FieldValue.serverTimestamp(),
  });
  return n;
}

String _rosterPersonKey(
  String clubId,
  String creatorId,
  Map<String, dynamic> data,
  String docId,
) {
  final uid = '${data['user_id'] ?? data['userId'] ?? ''}'.trim();
  if (uid.isNotEmpty) return uid;
  final id = '${data['id'] ?? docId}'.trim();
  if (id == 'm_creator_$clubId' || (creatorId.isNotEmpty && id == creatorId)) {
    return creatorId.isNotEmpty ? creatorId : 'creator:$clubId';
  }
  final account = RegExp(r'((?:kakao|google|apple)_[A-Za-z0-9]+)')
      .firstMatch(id)
      ?.group(1);
  if (account != null && account.isNotEmpty) return account;
  return id;
}
