/// 모임 ops 번들(~1MB)이 일정·장부로 커질 때 연도별 문서로 나눈다.
///
/// 번들에는 회원·회비설정·공지 등 가벼운 필드만 남기고,
/// 일정/조편성/대기는 `sch_YYYY`, 납부/거래는 `led_YYYY`로 올린다.
class ClubOpsOverflow {
  ClubOpsOverflow._();

  static const scheduleDocPrefix = 'sch_';
  static const ledgerDocPrefix = 'led_';

  static const scheduleKeys = <String>[
    'schedules',
    'groupAssignments',
    'waitingList',
    'awardRecords',
  ];

  static const ledgerKeys = <String>[
    'duesPayments',
    'transactions',
    'paymentRequests',
  ];

  static int? yearFromValue(dynamic value) {
    if (value is int && value >= 2000 && value <= 2100) return value;
    if (value is String && value.length >= 4) {
      final y = int.tryParse(value.substring(0, 4));
      if (y != null && y >= 2000 && y <= 2100) return y;
    }
    return null;
  }

  static int yearFromSchedule(Map<String, dynamic> s) =>
      yearFromValue(s['roundDate']) ?? DateTime.now().year;

  static int yearFromPayment(Map<String, dynamic> p) =>
      yearFromValue(p['year']) ??
      yearFromValue(p['paidAt']) ??
      DateTime.now().year;

  static int yearFromTransaction(Map<String, dynamic> t) =>
      yearFromValue(t['date']) ?? DateTime.now().year;

  static int yearFromPaymentRequest(Map<String, dynamic> r) =>
      yearFromValue(r['createdAt']) ??
      yearFromValue(r['dueDate']) ??
      DateTime.now().year;

  /// 일정 id → 연도
  static Map<String, int> scheduleYears(List<dynamic> schedules) {
    final out = <String, int>{};
    for (final raw in schedules) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final id = m['id'] as String? ?? '';
      if (id.isEmpty) continue;
      out[id] = yearFromSchedule(m);
    }
    return out;
  }

  /// 연도 → 일정 overflow 문서
  static Map<int, Map<String, dynamic>> splitScheduleYears(
    Map<String, dynamic> slice,
  ) {
    final schedules = slice['schedules'] as List? ?? const [];
    final years = scheduleYears(schedules);
    final byYear = <int, Map<String, dynamic>>{};

    Map<String, dynamic> bucket(int year) => byYear.putIfAbsent(
          year,
          () => {
            'year': year,
            'schedules': <dynamic>[],
            'groupAssignments': <String, dynamic>{},
            'waitingList': <dynamic>[],
            'awardRecords': <dynamic>[],
          },
        );

    for (final raw in schedules) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final year = yearFromSchedule(m);
      (bucket(year)['schedules'] as List).add(m);
    }

    final ga = slice['groupAssignments'];
    if (ga is Map) {
      ga.forEach((k, v) {
        final year = years[k as String] ?? DateTime.now().year;
        (bucket(year)['groupAssignments'] as Map)[k] = v;
      });
    }

    for (final raw in slice['waitingList'] as List? ?? const []) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final sid = m['scheduleId'] as String? ?? '';
      final year = years[sid] ?? DateTime.now().year;
      (bucket(year)['waitingList'] as List).add(m);
    }

    for (final raw in slice['awardRecords'] as List? ?? const []) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final sid = m['scheduleId'] as String? ?? '';
      final year = years[sid] ?? DateTime.now().year;
      (bucket(year)['awardRecords'] as List).add(m);
    }

    return byYear;
  }

  /// 연도 → 장부 overflow 문서
  static Map<int, Map<String, dynamic>> splitLedgerYears(
    Map<String, dynamic> slice,
  ) {
    final byYear = <int, Map<String, dynamic>>{};

    Map<String, dynamic> bucket(int year) => byYear.putIfAbsent(
          year,
          () => {
            'year': year,
            'duesPayments': <dynamic>[],
            'transactions': <dynamic>[],
            'paymentRequests': <dynamic>[],
          },
        );

    for (final raw in slice['duesPayments'] as List? ?? const []) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      (bucket(yearFromPayment(m))['duesPayments'] as List).add(m);
    }
    for (final raw in slice['transactions'] as List? ?? const []) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      (bucket(yearFromTransaction(m))['transactions'] as List).add(m);
    }
    for (final raw in slice['paymentRequests'] as List? ?? const []) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      (bucket(yearFromPaymentRequest(m))['paymentRequests'] as List).add(m);
    }
    return byYear;
  }

  static Map<String, dynamic> overflowIndex({
    required Iterable<int> scheduleYears,
    required Iterable<int> ledgerYears,
  }) {
    final sch = scheduleYears.toList()..sort();
    final led = ledgerYears.toList()..sort();
    return {'sch': sch, 'led': led};
  }

  /// 번들에 남기지 않는 무거운 필드. [overflowYears]는 호출 쪽에서 넣는다.
  static void stripHeavyFields(Map<String, dynamic> slice) {
    slice['schedules'] = <dynamic>[];
    slice['groupAssignments'] = <String, dynamic>{};
    slice['waitingList'] = <dynamic>[];
    slice['awardRecords'] = <dynamic>[];
    slice['duesPayments'] = <dynamic>[];
    slice['transactions'] = <dynamic>[];
    slice['paymentRequests'] = <dynamic>[];
  }

  static void mergeSidecarIntoRemote(
    Map<String, dynamic> remote,
    Map<String, dynamic> sidecar,
  ) {
    void appendList(String key) {
      final extra = sidecar[key];
      if (extra is! List) return;
      final cur = List<dynamic>.from(remote[key] as List? ?? const []);
      cur.addAll(extra);
      remote[key] = cur;
    }

    void mergeMap(String key) {
      final extra = sidecar[key];
      if (extra is! Map) return;
      final cur = Map<String, dynamic>.from(
        remote[key] is Map ? remote[key] as Map : const {},
      );
      extra.forEach((k, v) => cur[k.toString()] = v);
      remote[key] = cur;
    }

    appendList('schedules');
    appendList('waitingList');
    appendList('awardRecords');
    appendList('duesPayments');
    appendList('transactions');
    appendList('paymentRequests');
    mergeMap('groupAssignments');
  }

  /// overflow 인덱스가 있는데 사이드카를 못 읽으면, 빈 배열로 로컬을 지우지 않게 키를 뺀다.
  static void markOverflowUnavailable(Map<String, dynamic> remote) {
    for (final key in [...scheduleKeys, ...ledgerKeys]) {
      remote.remove(key);
    }
  }

  static List<int> yearsOf(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e is int ? e : int.tryParse('$e'))
        .whereType<int>()
        .toList();
  }
}
