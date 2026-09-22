import '../services/club_ops_sync.dart';

/// D-1 대기열. 명단 id와 로그인 id가 갈라지면 같은 번호로 여러 통이 나간다.
class D1RosterMatch {
  const D1RosterMatch({required this.clubId, required this.suffix});

  final String clubId;
  final String suffix;
}

abstract final class D1EnqueuePolicy {
  static final _rosterId = RegExp(r'^m_(c_\d+|c\d+|seed_c\d+)_(.+)$');
  static final _legacySeed = RegExp(r'^m[g]?\d+$');

  /// 알라딘만 장창현 본인 계정이다. 다른 모임 큐는 creator를 몰라도 막는다.
  static const leftoverAllowClubCreators = {
    'c_1789270673471': 'kakao_5049673364',
  };

  static D1RosterMatch? rosterMatch(String memberOrUserId) {
    final raw = memberOrUserId.trim();
    final hit = _rosterId.firstMatch(raw);
    if (hit == null) return null;
    return D1RosterMatch(clubId: hit.group(1)!, suffix: hit.group(2)!);
  }

  static String canonicalUserId({
    required String memberOrUserId,
    String clubId = '',
    String creatorUserId = '',
  }) {
    final raw = memberOrUserId.trim();
    if (raw.isEmpty) return '';
    if (_legacySeed.hasMatch(raw)) return '';
    final roster = rosterMatch(raw);
    if (roster != null) {
      if (_legacySeed.hasMatch(roster.suffix)) return '';
      return roster.suffix;
    }
    if (clubId.isNotEmpty && raw == 'm_creator_$clubId') {
      return creatorUserId.trim();
    }
    if (raw.startsWith('m_creator_')) return creatorUserId.trim();
    return raw;
  }

  static bool isBlockedRecipient({
    required String name,
    required String userId,
    required String clubId,
    String creatorUserId = '',
  }) {
    final creator = creatorUserId.trim().isNotEmpty
        ? creatorUserId.trim()
        : (leftoverAllowClubCreators[clubId] ?? '');
    return ClubOpsSync.isForeignLeftoverMember(
      id: userId,
      name: name,
      clubId: clubId,
      creatorUserId: creator,
    );
  }

  static String phoneDigits(String phone) =>
      phone.replaceAll(RegExp(r'\D'), '');

  static String sendDedupKey({
    required String scheduleId,
    required String sendOn,
    required String phone,
  }) {
    return '$scheduleId|$sendOn|${phoneDigits(phone)}';
  }
}
