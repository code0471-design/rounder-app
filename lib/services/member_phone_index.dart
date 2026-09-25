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
/// 소셜 계정 명단 행(`m_{모임}_kakao_…`)은 초대·승인·생성으로만 소속이 생긴다.
/// 번호 색인으로 그 행을 잇으면, 남은 행만으로 남의 모임 총무가 된다.
///
/// 문서 id 가 번호(숫자만)라서 로그인 조회는 **읽기 1회**다. 명단이 바뀔 때만
/// 바뀐 번호를 쓴다(전체 재작성 금지).
abstract final class MemberPhoneIndex {
  MemberPhoneIndex._();

  static final _socialAccount = RegExp(r'^(kakao_|google_|apple_)');
  static final _legacySeedSuffix = RegExp(r'^m\d+$');
  static final _handAddedTimestampId = RegExp(r'^m_\d{10,}$');

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

  /// 카카오/구글/애플 계정으로 붙은 명단 행인지.
  static bool isSocialAccountRosterId(String clubId, String memberId) {
    final prefix = 'm_${clubId}_';
    if (!memberId.startsWith(prefix)) return false;
    return _socialAccount.hasMatch(memberId.substring(prefix.length));
  }

  /// 방장이 이름·번호만 적어 둔 행. 나중에 같은 번호로 가입하면 이 행만 잇는다.
  static bool isPhoneClaimableMemberId(String clubId, String memberId) {
    if (clubId.isEmpty || memberId.isEmpty) return false;
    if (memberId == 'm_creator_$clubId') return false;
    if (_handAddedTimestampId.hasMatch(memberId)) return true;
    final prefix = 'm_${clubId}_';
    if (!memberId.startsWith(prefix)) return false;
    final suffix = memberId.substring(prefix.length);
    if (suffix.isEmpty) return false;
    if (_socialAccount.hasMatch(suffix)) return false;
    if (_legacySeedSuffix.hasMatch(suffix) || suffix == 'user_me') return false;
    return true;
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
      if (!isPhoneClaimableMemberId(clubId, memberId)) continue;
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

  /// 번호로 잘못 만든 소속·소셜 행 색인을 먼저 지운다.
  ///
  /// `claimForUser` 보다 먼저 호출해야 한다. 순서가 바뀌면 남은 소셜 행이
  /// 소속을 만들고, 그 소속 때문에 명단 삭제가 무시된다.
  static Future<void> revokeSpuriousPhoneMemberships({
    required String userId,
    required Object? phone,
  }) async {
    final digits = digitsOf(phone);
    if (!_enabled || userId.trim().isEmpty) return;
    try {
      final indexed = <String, String>{};
      if (digits.isNotEmpty) {
        final doc = await _db
            .collection(FirestorePaths.memberPhoneIndex)
            .doc(digits)
            .get();
        final clubs = doc.data()?['clubs'];
        if (clubs is Map) {
          for (final e in clubs.entries) {
            final clubId = '${e.key}'.trim();
            final memberId = '${e.value ?? ''}'.trim();
            if (clubId.isEmpty || memberId.isEmpty) continue;
            indexed[clubId] = memberId;
          }
        }
      }

      final snap = await _db
          .collection(FirestorePaths.userMemberships)
          .where('user_id', isEqualTo: userId)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final clubId = '${data['club_id'] ?? ''}'.trim();
        if (clubId.isEmpty) continue;
        if (data['via_invite'] == true) continue;
        final creatorId = await _clubCreatorId(clubId);
        if (creatorId.isNotEmpty && creatorId == userId) continue;

        final indexMemberId = indexed[clubId] ?? '';
        final claimable = indexMemberId.isNotEmpty &&
            canClaimRow(
              userId: userId,
              clubId: clubId,
              memberId: indexMemberId,
              creatorUserId: creatorId,
            );
        if (claimable) continue;
        if (data['claimed_by_phone'] != true) {
          if (indexMemberId.isNotEmpty &&
              !isPhoneClaimableMemberId(clubId, indexMemberId) &&
              digits.isNotEmpty) {
            await _dropClubFromIndex(digits, clubId);
            indexed.remove(clubId);
          }
          continue;
        }

        await doc.reference.delete();
        if (digits.isNotEmpty) {
          await _dropClubFromIndex(digits, clubId);
        }
        indexed.remove(clubId);
        debugPrint('[MemberPhoneIndex] 잘못된 번호 소속 삭제: $clubId');
      }

      for (final e in indexed.entries) {
        if (isPhoneClaimableMemberId(e.key, e.value)) continue;
        if (digits.isEmpty) continue;
        await _dropClubFromIndex(digits, e.key);
      }
    } catch (e) {
      debugPrint('[MemberPhoneIndex] revoke skip: $e');
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
        final creatorId = await _clubCreatorId(clubId);
        if (!canClaimRow(
          userId: userId,
          clubId: clubId,
          memberId: memberId,
          creatorUserId: creatorId,
        )) {
          if (existing.exists &&
              existing.data()?['claimed_by_phone'] == true &&
              existing.data()?['via_invite'] != true &&
              creatorId != userId) {
            await membershipRef.delete();
          }
          await _dropClubFromIndex(digits, clubId);
          debugPrint('[MemberPhoneIndex] $clubId $memberId 는 번호로 잇지 않음');
          continue;
        }
        if (existing.exists) {
          claimed[clubId] = memberId;
          continue;
        }
        if (!await _clubExists(clubId)) {
          await _dropClubFromIndex(digits, clubId);
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

  /// 번호가 맞아도 남의 방장 자리·소셜 계정 행은 소속으로 만들지 않는다.
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
    return isPhoneClaimableMemberId(clubId, memberId);
  }

  static Future<void> removeClub(String digits, String clubId) =>
      _dropClubFromIndex(digits, clubId);

  /// 탈퇴·번호 변경 때 예전 번호를 색인에서 뺀다. 소셜 행은 잇지 않는다.
  static Future<void> releasePhoneForUser({
    required String userId,
    required Object? phone,
  }) async {
    final digits = digitsOf(phone);
    if (!_enabled || userId.trim().isEmpty || digits.isEmpty) return;
    try {
      final doc = await _db
          .collection(FirestorePaths.memberPhoneIndex)
          .doc(digits)
          .get();
      final clubs = doc.data()?['clubs'];
      if (clubs is! Map) return;
      for (final e in clubs.entries) {
        final clubId = '${e.key}'.trim();
        final memberId = '${e.value ?? ''}'.trim();
        if (clubId.isEmpty || memberId.isEmpty) continue;
        final ownSocial = isSocialAccountRosterId(clubId, memberId) &&
            memberId.endsWith('_$userId');
        final ownCreator = memberId == 'm_creator_$clubId';
        final ownId = memberId == userId || memberId.endsWith('_$userId');
        if (ownSocial || ownCreator || ownId) {
          await _dropClubFromIndex(digits, clubId);
        }
      }
    } catch (e) {
      debugPrint('[MemberPhoneIndex] release $digits skip: $e');
    }
  }

  static Future<void> _dropClubFromIndex(String digits, String clubId) async {
    if (digits.isEmpty || clubId.isEmpty) return;
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
