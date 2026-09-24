/// 일정 참석 정원. 동시 클릭이어도 서버 정원 초과로 넣지 않는다.
abstract final class AttendanceSeat {
  AttendanceSeat._();

  static int attendingCount(
    Iterable<Map<String, dynamic>> responses, {
    String? excludingMemberId,
  }) {
    var n = 0;
    for (final r in responses) {
      if (r['response'] != '참석') continue;
      final id = '${r['memberId'] ?? ''}';
      if (excludingMemberId != null && id == excludingMemberId) continue;
      n++;
    }
    return n;
  }

  static bool canClaim({
    required int attendingOthers,
    required int capacity,
  }) {
    if (capacity <= 0) return true;
    return attendingOthers < capacity;
  }

  static int capacityFromSchedule(Map<String, dynamic> s) {
    final team = (s['teamCount'] as num?)?.toInt() ?? 0;
    final max = (s['maxCapacity'] as num?)?.toInt();
    final byTeams = team * 4;
    if (max != null && max >= byTeams) return max;
    return byTeams;
  }

  static Map<String, dynamic> capScheduleMap(Map<String, dynamic> s) {
    final cap = capacityFromSchedule(s);
    if (cap <= 0) return s;
    final m = Map<String, dynamic>.from(s);
    m['responses'] = capAttending(m['responses'] as List? ?? const [], cap);
    return m;
  }

  /// 정원만큼만 참석을 남긴다. 먼저 응답한 사람을 살린다.
  static List<Map<String, dynamic>> capAttending(
    List<dynamic> responses,
    int capacity,
  ) {
    final list = [
      for (final raw in responses)
        if (raw is Map) Map<String, dynamic>.from(raw),
    ];
    if (capacity <= 0) return list;
    final attending = list.where((r) => r['response'] == '참석').toList()
      ..sort((a, b) {
        final at = '${a['respondedAt'] ?? ''}';
        final bt = '${b['respondedAt'] ?? ''}';
        return at.compareTo(bt);
      });
    if (attending.length <= capacity) return list;
    final keep = {
      for (final r in attending.take(capacity)) '${r['memberId'] ?? ''}',
    };
    return [
      for (final r in list)
        if (r['response'] != '참석' || keep.contains('${r['memberId'] ?? ''}')) r,
    ];
  }
}
