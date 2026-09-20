import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/firebase/firestore_paths.dart';
import '../di/app_dependencies.dart';

/// 전화번호 → 모임 명단 색인.
///
/// 방장이 앱에서 손으로 추가한 회원은 계정이 없다. 그 사람이 나중에 같은 번호로
/// 가입해도 서버에는 소속(`user_memberships`)이 없어서 "가입했는데 모임이 안 보여요"
/// 가 된다. 명단에 번호를 남긴 사람은 로그인할 때 자동으로 이어 붙인다.
///
/// 문서 id 가 번호(숫자만)라서 로그인 조회는 **읽기 1회**다. 명단이 바뀔 때만
/// 바뀐 번호를 쓴다(전체 재작성 금지).
abstract final class MemberPhoneIndex {
  MemberPhoneIndex._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static bool get _enabled =>
      AppDependencies.instance.isInitialized &&
      !AppDependencies.instance.isOfflineMockMode;

  /// clubId → (번호 → 명단 행 id). 같은 세션에서 안 바뀐 번호는 다시 안 쓴다.
  static final Map<String, Map<String, String>> _pushed = {};

  @visibleForTesting
  static void resetCache() => _pushed.clear();

  /// 숫자만 남긴 번호. 10자리 미만은 색인하지 않는다(오매칭 방지).
  static String digitsOf(Object? phone) {
    final digits = '${phone ?? ''}'.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 10 ? digits : '';
  }

  /// 한 모임 명단의 번호 색인을 맞춘다. [members] 는 ops 슬라이스의 회원 맵.
  static Future<void> syncClub({
    required String clubId,
    required List<dynamic> members,
  }) async {
    if (!_enabled || clubId.isEmpty) return;
    final next = <String, String>{};
    for (final m in members) {
      if (m is! Map) continue;
      final digits = digitsOf(m['phone']);
      final memberId = '${m['id'] ?? ''}'.trim();
      if (digits.isEmpty || memberId.isEmpty) continue;
      next[digits] = memberId;
    }
    final prev = _pushed[clubId] ?? const <String, String>{};
    if (mapEquals(prev, next)) return;

    try {
      for (final entry in next.entries) {
        if (prev[entry.key] == entry.value) continue;
        await _db.collection(FirestorePaths.memberPhoneIndex).doc(entry.key).set(
          {
            'clubs': {clubId: entry.value},
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      for (final gone in prev.keys.where((k) => !next.containsKey(k))) {
        await _db.collection(FirestorePaths.memberPhoneIndex).doc(gone).set(
          {
            'clubs': {clubId: FieldValue.delete()},
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      _pushed[clubId] = next;
    } catch (e) {
      debugPrint('[MemberPhoneIndex] sync $clubId skip: $e');
    }
  }

  /// 내 번호로 명단에 올라 있는 모임을 찾아 소속을 만든다.
  ///
  /// 반환은 `모임 → 내 명단 행 id`. 이미 소속이 있으면 만들지 않는다.
  /// 명단 행이 다른 계정에 연결돼 있으면 번호가 겹친 것으로 보고 건너뛴다.
  static Future<Map<String, String>> claimForUser({
    required String userId,
    required Object? phone,
  }) async {
    final digits = digitsOf(phone);
    if (!_enabled || userId.trim().isEmpty || digits.isEmpty) return const {};
    try {
      final doc = await _db
          .collection(FirestorePaths.memberPhoneIndex)
          .doc(digits)
          .get();
      final clubs = doc.data()?['clubs'];
      if (clubs is! Map) return const {};

      final claimed = <String, String>{};
      for (final e in clubs.entries) {
        final clubId = '${e.key}'.trim();
        final memberId = '${e.value ?? ''}'.trim();
        if (clubId.isEmpty || memberId.isEmpty) continue;

        final membershipRef =
            _db.doc(FirestorePaths.userMembershipDoc(userId, clubId));
        final existing = await membershipRef.get();
        if (existing.exists) {
          claimed[clubId] = memberId;
          continue;
        }
        if (!await _clubExists(clubId)) {
          await _dropClubFromIndex(digits, clubId);
          continue;
        }
        final creatorId = await _clubCreatorId(clubId);
        if (!canClaimRow(
          userId: userId,
          clubId: clubId,
          memberId: memberId,
          creatorUserId: creatorId,
        )) {
          debugPrint('[MemberPhoneIndex] $clubId $memberId 는 내 행이 아님');
          continue;
        }
        if (await _rowBelongsToAnotherAccount(clubId, memberId, userId)) {
          debugPrint('[MemberPhoneIndex] $clubId $memberId 은 다른 계정 행');
          continue;
        }

        await membershipRef.set({
          'user_id': userId,
          'club_id': clubId,
          'role': '정회원',
          'status': '활성',
          'claimed_by_phone': true,
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        claimed[clubId] = memberId;
        debugPrint('[MemberPhoneIndex] 번호로 소속 연결: $clubId');
      }
      return claimed;
    } catch (e) {
      debugPrint('[MemberPhoneIndex] claim skip: $e');
      return const {};
    }
  }

  /// 번호가 맞아도 남의 방장 자리·다른 소셜 계정 행은 소속으로 만들지 않는다.
  static bool canClaimRow({
    required String userId,
    required String clubId,
    required String memberId,
    required String creatorUserId,
  }) {
    if (userId.isEmpty || clubId.isEmpty || memberId.isEmpty) return false;
    if (memberId == 'm_creator_$clubId') {
      return creatorUserId.isNotEmpty && creatorUserId == userId;
    }
    final prefix = 'm_${clubId}_';
    if (!memberId.startsWith(prefix)) return false;
    final suffix = memberId.substring(prefix.length);
    if (suffix == userId) return true;
    if (RegExp(r'^(kakao_|google_|apple_)').hasMatch(suffix)) return false;
    if (RegExp(r'^m\d+$').hasMatch(suffix) || suffix == 'user_me') return false;
    return true;
  }

  static Future<void> _dropClubFromIndex(String digits, String clubId) async {
    try {
      await _db.collection(FirestorePaths.memberPhoneIndex).doc(digits).set(
        {
          'clubs': {clubId: FieldValue.delete()},
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[MemberPhoneIndex] drop $clubId skip: $e');
    }
  }

  static Future<bool> _clubExists(String clubId) async {
    final snap = await _db.doc(FirestorePaths.clubDoc(clubId)).get();
    return snap.exists;
  }

  static Future<String> _clubCreatorId(String clubId) async {
    try {
      final snap = await _db.doc(FirestorePaths.clubDoc(clubId)).get();
      final data = snap.data() ?? const <String, dynamic>{};
      for (final key in ['host_user_id', 'hostUserId', 'creator_id', 'creatorId']) {
        final v = '${data[key] ?? ''}'.trim();
        if (v.isNotEmpty) return v;
      }
    } catch (_) {}
    return '';
  }

  static Future<bool> _rowBelongsToAnotherAccount(
    String clubId,
    String memberId,
    String userId,
  ) async {
    final snap =
        await _db.doc(FirestorePaths.clubMemberDoc(clubId, memberId)).get();
    final owner = '${snap.data()?['user_id'] ?? ''}'.trim();
    return owner.isNotEmpty && owner != userId;
  }
}
