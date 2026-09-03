import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/services/club_ops_overflow.dart';
import 'package:golf_rounder/services/club_ops_sync.dart';

void main() {
  test('schedules split by year and reconstruct', () {
    final slice = <String, dynamic>{
      'schedules': [
        {
          'id': 's_24',
          'clubId': 'c1',
          'roundDate': DateTime(2024, 3, 1).toIso8601String(),
          'title': '24년',
        },
        {
          'id': 's_26',
          'clubId': 'c1',
          'roundDate': DateTime(2026, 8, 10).toIso8601String(),
          'title': '26년',
        },
      ],
      'groupAssignments': {
        's_24': {'scheduleId': 's_24', 'teamCount': 2},
        's_26': {'scheduleId': 's_26', 'teamCount': 4},
      },
      'waitingList': [
        {'scheduleId': 's_24', 'memberId': 'm1'},
      ],
      'awardRecords': [
        {'scheduleId': 's_26', 'title': '우승'},
      ],
    };

    final years = ClubOpsOverflow.splitScheduleYears(slice);
    expect(years.keys.toSet(), {2024, 2026});
    expect((years[2024]!['schedules'] as List).single['id'], 's_24');
    expect((years[2026]!['groupAssignments'] as Map).containsKey('s_26'), true);
    expect((years[2024]!['waitingList'] as List), isNotEmpty);
    expect((years[2026]!['awardRecords'] as List), isNotEmpty);

    final remote = <String, dynamic>{
      'schedules': <dynamic>[],
      'groupAssignments': <String, dynamic>{},
      'waitingList': <dynamic>[],
      'awardRecords': <dynamic>[],
    };
    ClubOpsOverflow.mergeSidecarIntoRemote(remote, years[2024]!);
    ClubOpsOverflow.mergeSidecarIntoRemote(remote, years[2026]!);
    expect((remote['schedules'] as List).length, 2);
    expect((remote['groupAssignments'] as Map).length, 2);
  });

  test('ledger split by year', () {
    final slice = <String, dynamic>{
      'duesPayments': [
        {'id': 'p1', 'year': 2025, 'amount': 50000},
        {'id': 'p2', 'paidAt': DateTime(2026, 1, 5).toIso8601String(), 'amount': 30000},
      ],
      'transactions': [
        {'id': 't1', 'date': DateTime(2025, 6, 1).toIso8601String(), 'amount': 1000},
      ],
      'paymentRequests': [
        {'id': 'r1', 'createdAt': DateTime(2026, 2, 1).toIso8601String()},
      ],
    };
    final years = ClubOpsOverflow.splitLedgerYears(slice);
    expect(years.keys.toSet(), {2025, 2026});
    expect((years[2025]!['duesPayments'] as List).length, 1);
    expect((years[2026]!['duesPayments'] as List).length, 1);
    expect((years[2025]!['transactions'] as List).length, 1);
    expect((years[2026]!['paymentRequests'] as List).length, 1);
  });

  test('stripHeavyFields leaves overflow-ready lean bundle', () {
    final slice = <String, dynamic>{
      'clubId': 'c1',
      'members': [
        {'id': 'm1', 'name': '홍'}
      ],
      'schedules': [
        {'id': 's1', 'roundDate': '2026-01-01'}
      ],
      'transactions': [
        {'id': 't1', 'date': '2026-01-01', 'amount': 1}
      ],
      'duesPayments': [
        {'id': 'p1', 'year': 2026}
      ],
    };
    final sch = ClubOpsOverflow.splitScheduleYears(slice);
    final led = ClubOpsOverflow.splitLedgerYears(slice);
    ClubOpsOverflow.stripHeavyFields(slice);
    slice['overflowYears'] = ClubOpsOverflow.overflowIndex(
      scheduleYears: sch.keys,
      ledgerYears: led.keys,
    );
    expect(slice['schedules'], isEmpty);
    expect(slice['transactions'], isEmpty);
    expect((slice['overflowYears'] as Map)['sch'], [2026]);
    expect(
      ClubOpsSync.estimateJsonBytes(slice),
      lessThan(ClubOpsSync.opsBundleSoftLimitBytes),
    );
  });

  test('year-split dense history stays under soft limit per doc', () {
    final schedules = List.generate(280, (i) {
      return <String, dynamic>{
        'id': 's_$i',
        'clubId': 'c_test',
        'title': '정기라운드 ${i + 1}회차',
        'roundDate': DateTime(2020, 1, 1).add(Duration(days: i * 7)).toIso8601String(),
        'teeTime': '07:00',
        'courseName': '테스트CC',
        'teamCount': 8,
        'status': 'completed',
        'createdBy': '홍길동',
        'note': '메모 ' * 8,
        'responses': List.generate(20, (j) {
          return {
            'memberId': 'm_$j',
            'memberName': '회원$j',
            'status': 'attending',
          };
        }),
      };
    });
    final slice = <String, dynamic>{
      'schedules': schedules,
      'groupAssignments': <String, dynamic>{},
      'waitingList': <dynamic>[],
      'awardRecords': <dynamic>[],
    };
    final years = ClubOpsOverflow.splitScheduleYears(slice);
    expect(years.length, greaterThan(1));
    for (final doc in years.values) {
      expect(
        ClubOpsSync.estimateJsonBytes(doc),
        lessThan(ClubOpsSync.opsBundleSoftLimitBytes),
      );
    }
  });

  test('missing overflow keys do not wipe local schedules', () {
    ClubOpsOverflow.markOverflowUnavailable(remoteWithoutKeys);
    expect(remoteWithoutKeys.containsKey('schedules'), isFalse);
    expect(remoteWithoutKeys.containsKey('transactions'), isFalse);
  });
}

final remoteWithoutKeys = <String, dynamic>{
  'clubId': 'c1',
  'overflowYears': {
    'sch': [2026],
    'led': [2026],
  },
  'schedules': <dynamic>[],
  'transactions': <dynamic>[],
};
