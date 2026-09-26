import '../models/club_model.dart';

/// 명단 가입일. 있는 값을 오늘·serverTimestamp 로 덮지 않는다.
abstract final class MemberJoinDate {
  static DateTime? parse(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  /// `c_{millis}` 모임 id 에 들어 있는 개설 시각.
  static DateTime? createdAtFromClubId(String clubId) {
    if (!clubId.startsWith('c_')) return null;
    final ms = int.tryParse(clubId.substring(2));
    if (ms == null || ms < 1000000000000 || ms > 4000000000000) return null;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    if (dt.year < 2020 || dt.year > 2100) return null;
    return dt;
  }

  static DateTime resolvedClubCreatedAt(Club club) {
    final fromId = createdAtFromClubId(club.id);
    final stored = club.createdAt;
    if (fromId == null) return stored;
    return stored.isBefore(fromId) ? stored : fromId;
  }

  static bool isCreatorRow({
    required String memberId,
    required Club club,
  }) {
    if (memberId == 'm_creator_${club.id}') return true;
    final cid = club.creatorId.trim();
    if (cid.isEmpty) return false;
    if (memberId == cid) return true;
    if (memberId == Member.rosterId(club.id, cid)) return true;
    return false;
  }

  /// 모임 개설일보다 앞선 가입일은 없는 것과 같다.
  static DateTime? onOrAfterClub(DateTime? date, DateTime? clubCreatedAt) {
    if (date == null) return null;
    if (clubCreatedAt == null) return date;
    final day = DateTime(date.year, date.month, date.day);
    final open = DateTime(
      clubCreatedAt.year,
      clubCreatedAt.month,
      clubCreatedAt.day,
    );
    if (day.isBefore(open)) return null;
    return date;
  }

  /// 둘 다 있으면 더 이른 날. 한쪽만 있으면 그 값. 오늘을 지어내지 않는다.
  /// 개설일보다 앞선 값은 버린다.
  static DateTime? keepEarlier(
    DateTime? existing,
    DateTime? incoming, {
    DateTime? notBefore,
  }) {
    final a = onOrAfterClub(existing, notBefore);
    final b = onOrAfterClub(incoming, notBefore);
    if (a == null) return b;
    if (b == null) return a;
    return a.isBefore(b) ? a : b;
  }

  static DateTime? earliest(Iterable<DateTime?> dates) {
    DateTime? best;
    for (final d in dates) {
      if (d == null) continue;
      if (best == null || d.isBefore(best)) best = d;
    }
    return best;
  }

  /// 새 명단 행. 모임장은 개설일, 나머지는 초대·승인 시각. inherit 이 있으면 그걸 지킨다.
  static DateTime? forNewRow({
    required bool isCreator,
    required DateTime clubCreatedAt,
    DateTime? eventAt,
    DateTime? inherit,
  }) {
    if (inherit != null) return inherit;
    if (isCreator) return clubCreatedAt;
    return eventAt;
  }

  static DateTime? repair({
    required Member member,
    required Club club,
    DateTime? evidenceAt,
  }) {
    final created = resolvedClubCreatedAt(club);
    if (isCreatorRow(memberId: member.id, club: club)) {
      return created;
    }
    return keepEarlier(member.joinDate, evidenceAt, notBefore: created);
  }

  static DateTime? fromMemberMap(Map<dynamic, dynamic> m) {
    return parse(m['joinDate'] ?? m['join_date']);
  }

  /// merge 대상 map 에 더 이른 가입일을 남긴다.
  static void writeEarlierInto(
    Map<dynamic, dynamic> target,
    Iterable<Map<dynamic, dynamic>?> sources, {
    DateTime? notBefore,
  }) {
    DateTime? best;
    for (final src in sources) {
      if (src == null) continue;
      best = keepEarlier(best, fromMemberMap(src), notBefore: notBefore);
    }
    if (best == null) return;
    if (target.containsKey('join_date') ||
        sources.any((s) => s != null && s.containsKey('join_date'))) {
      target['join_date'] = best.toIso8601String();
    }
    if (target.containsKey('joinDate') ||
        sources.any((s) => s != null && s.containsKey('joinDate'))) {
      target['joinDate'] = best.toIso8601String();
    }
  }
}
