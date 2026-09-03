import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/services/club_data_codec.dart';
import 'package:golf_rounder/services/club_ops_sync.dart';

void main() {
  test('applyRemoteSlice merges schedules for same club', () {
    final local = ClubDataBundle(
      selectedClubIndex: 0,
      freshClubIds: {'c_test'},
      myClubs: [
        Club(
          id: 'c_test',
          name: '테스트',
          myRole: '총무',
          memberCount: 1,
          region: '서울',
          industry: 'IT',
          teamCount: 4,
        ),
      ],
      allClubs: const [],
      joinRequests: const [],
      members: [
        Member(
          id: 'm_creator_c_test',
          name: '홍길동',
          gender: '남',
          memberType: '정회원',
          role: '총무',
          joinDate: DateTime(2024, 1, 1),
          status: '활성',
        ),
      ],
      activities: const [],
      announcements: const [],
      appNotifications: const [],
      duesSettings: const [],
      duesPayments: const [],
      paymentRequests: const [],
      transactions: const [],
      schedules: [
        RoundSchedule(
          id: 's_local',
          clubId: 'c_test',
          title: '로컬일정',
          roundDate: DateTime(2026, 9, 1),
          teeTime: '07:00',
          courseName: 'A',
          teamCount: 4,
          status: ScheduleStatus.upcoming,
          createdBy: '홍길동',
        ),
      ],
      photos: const [],
      groupAssignments: const {},
      adApplications: const [],
      adNotifications: const [],
      sponsorApplications: const [],
      pointEvents: const {},
      awardRecords: const [],
      thankYouMessages: const [],
      waitingList: const [],
      alimtalkSettings: const {},
    );

    final remote = <String, dynamic>{
      'clubId': 'c_test',
      'schedules': [
        {
          'id': 's_remote',
          'clubId': 'c_test',
          'title': '원격일정',
          'roundDate': DateTime(2026, 9, 2).toIso8601String(),
          'teeTime': '08:00',
          'courseName': 'B',
          'teamCount': 4,
          'status': 'upcoming',
          'createdBy': '김철수',
          'responses': <dynamic>[],
          'companionIds': <dynamic>[],
          'deadlineNotified': false,
        },
      ],
      'announcements': <dynamic>[],
      'members': [
        {
          'id': 'm_creator_c_test',
          'name': '홍길동',
          'gender': '남',
          'memberType': '정회원',
          'role': '총무',
          'joinDate': DateTime(2024, 1, 1).toIso8601String(),
          'status': '활성',
        },
        {
          'id': 'm_c_test_u2',
          'name': '테스터',
          'gender': '남',
          'memberType': '정회원',
          'role': '일반',
          'joinDate': DateTime(2024, 2, 1).toIso8601String(),
          'status': '활성',
        },
      ],
      'activities': <dynamic>[],
      'duesSettings': <dynamic>[],
      'duesPayments': <dynamic>[],
      'paymentRequests': <dynamic>[],
      'transactions': <dynamic>[],
      'photos': <dynamic>[],
      'groupAssignments': <String, dynamic>{},
      'waitingList': <dynamic>[],
      'alimtalkSettings': <String, dynamic>{},
      'adApplications': <dynamic>[],
      'adNotifications': <dynamic>[],
      'sponsorApplications': <dynamic>[],
      'awardRecords': <dynamic>[],
      'thankYouMessages': <dynamic>[],
      'pointEvents': <String, dynamic>{},
    };

    final merged = ClubOpsSync.applyRemoteSlice(local, 'c_test', remote);
    expect(merged.schedules.any((s) => s.id == 's_remote'), isTrue);
    expect(merged.schedules.any((s) => s.id == 's_local'), isFalse);
    expect(merged.members.any((m) => m.id == 'm_c_test_u2'), isTrue);
  });

  test('overflow attach 실패로 키가 없으면 로컬 일정·장부를 유지한다', () {
    final local = ClubDataBundle(
      selectedClubIndex: 0,
      freshClubIds: {'c_test'},
      myClubs: [
        Club(
          id: 'c_test',
          name: '테스트',
          myRole: '총무',
          memberCount: 1,
          region: '서울',
          industry: 'IT',
          teamCount: 4,
        ),
      ],
      allClubs: const [],
      joinRequests: const [],
      members: const [],
      activities: const [],
      announcements: const [],
      appNotifications: const [],
      duesSettings: const [],
      duesPayments: [
        DuesPayment(
          id: 'pay_keep',
          memberId: 'm1',
          memberName: '홍',
          duesSettingId: 'ds_club_1',
          amount: 10000,
          paidAt: DateTime(2026, 1, 5),
          recordedBy: '총무',
        ),
      ],
      paymentRequests: const [],
      transactions: const [],
      schedules: [
        RoundSchedule(
          id: 's_keep',
          clubId: 'c_test',
          title: '로컬유지',
          roundDate: DateTime(2026, 8, 1),
          teeTime: '07:00',
          courseName: 'A',
          teamCount: 4,
          status: ScheduleStatus.upcoming,
          createdBy: '홍길동',
        ),
      ],
      photos: const [],
      groupAssignments: const {},
      adApplications: const [],
      adNotifications: const [],
      sponsorApplications: const [],
      pointEvents: const {},
      awardRecords: const [],
      thankYouMessages: const [],
      waitingList: const [],
      alimtalkSettings: const {},
    );

    final remote = <String, dynamic>{
      'clubId': 'c_test',
      'overflowYears': {
        'sch': [2026],
        'led': [2026],
      },
      'announcements': <dynamic>[],
      'members': <dynamic>[],
    };

    final merged = ClubOpsSync.applyRemoteSlice(local, 'c_test', remote);
    expect(merged.schedules.any((s) => s.id == 's_keep'), isTrue);
    expect(merged.duesPayments.any((p) => p.id == 'pay_keep'), isTrue);
  });

  test('원격 명단에 없어도 로컬 초대 가입 회원은 유지한다', () {
    final local = ClubDataBundle(
      selectedClubIndex: 0,
      freshClubIds: {'c_test'},
      myClubs: [
        Club(
          id: 'c_test',
          name: '테스트',
          myRole: '정회원',
          memberCount: 1,
          region: '서울',
          industry: 'IT',
          teamCount: 4,
        ),
      ],
      allClubs: const [],
      joinRequests: const [],
      members: [
        Member(
          id: Member.rosterId('c_test', 'kakao_1'),
          name: '초대가입',
          gender: '남',
          memberType: '정회원',
          role: '정회원',
          joinDate: DateTime(2026, 8, 27),
          status: '활성',
        ),
      ],
      activities: const [],
      announcements: const [],
      appNotifications: const [],
      duesSettings: const [],
      duesPayments: const [],
      paymentRequests: const [],
      transactions: const [],
      schedules: const [],
      photos: const [],
      groupAssignments: const {},
      adApplications: const [],
      adNotifications: const [],
      sponsorApplications: const [],
      pointEvents: const {},
      awardRecords: const [],
      thankYouMessages: const [],
      waitingList: const [],
      alimtalkSettings: const {},
    );

    final remote = <String, dynamic>{
      'clubId': 'c_test',
      'members': [
        {
          'id': 'm_creator_c_test',
          'name': '총무',
          'gender': '남',
          'memberType': '정회원',
          'role': '총무',
          'joinDate': DateTime(2024, 1, 1).toIso8601String(),
          'status': '활성',
        },
      ],
      'schedules': <dynamic>[],
      'announcements': <dynamic>[],
      'activities': <dynamic>[],
      'duesSettings': <dynamic>[],
      'duesPayments': <dynamic>[],
      'paymentRequests': <dynamic>[],
      'transactions': <dynamic>[],
      'photos': <dynamic>[],
      'groupAssignments': <String, dynamic>{},
      'waitingList': <dynamic>[],
      'alimtalkSettings': <String, dynamic>{},
      'adApplications': <dynamic>[],
      'adNotifications': <dynamic>[],
      'sponsorApplications': <dynamic>[],
      'awardRecords': <dynamic>[],
      'thankYouMessages': <dynamic>[],
      'pointEvents': <String, dynamic>{},
    };

    final merged = ClubOpsSync.applyRemoteSlice(local, 'c_test', remote);
    expect(merged.members.any((m) => m.id == 'm_creator_c_test'), isTrue);
    expect(
      merged.members.any((m) => m.id == Member.rosterId('c_test', 'kakao_1')),
      isTrue,
    );
  });

  test('원격 납부가 비어 있어도 로컬 회비 납부 내역은 유지한다', () {
    final local = ClubDataBundle(
      selectedClubIndex: 0,
      freshClubIds: {'c_test'},
      myClubs: [
        Club(
          id: 'c_test',
          name: '테스트',
          myRole: '총무',
          memberCount: 1,
          region: '서울',
          industry: 'IT',
          teamCount: 4,
        ),
      ],
      allClubs: const [],
      joinRequests: const [],
      members: const [],
      activities: const [],
      announcements: const [],
      appNotifications: const [],
      duesSettings: [
        DuesSetting(
          id: 'ds_club_1',
          type: DuesType.monthly,
          amount: 50000,
          title: '2026년 월회비',
          createdAt: DateTime(2026, 1, 1),
          clubId: 'c_test',
        ),
      ],
      duesPayments: [
        DuesPayment(
          id: 'pay_local_1',
          memberId: 'm1',
          memberName: '홍길동',
          duesSettingId: 'ds_club_1',
          amount: 50000,
          paidAt: DateTime(2026, 3, 1),
          recordedBy: '총무',
        ),
      ],
      paymentRequests: const [],
      transactions: const [],
      schedules: const [],
      photos: const [],
      groupAssignments: const {},
      adApplications: const [],
      adNotifications: const [],
      sponsorApplications: const [],
      pointEvents: const {},
      awardRecords: const [],
      thankYouMessages: const [],
      waitingList: const [],
      alimtalkSettings: const {},
    );

    final remote = <String, dynamic>{
      'clubId': 'c_test',
      'schedules': <dynamic>[],
      'announcements': <dynamic>[],
      'members': <dynamic>[],
      'activities': <dynamic>[],
      'duesSettings': [
        {
          'id': 'ds_club_1',
          'type': 'monthly',
          'amount': 50000,
          'title': '2026년 월회비',
          'createdAt': DateTime(2026, 1, 1).toIso8601String(),
          'isActive': true,
          'clubId': 'c_test',
          'amountHistory': <dynamic>[],
        },
      ],
      'duesPayments': <dynamic>[],
      'paymentRequests': <dynamic>[],
      'transactions': <dynamic>[],
      'photos': <dynamic>[],
      'groupAssignments': <String, dynamic>{},
      'waitingList': <dynamic>[],
      'alimtalkSettings': <String, dynamic>{},
      'adApplications': <dynamic>[],
      'adNotifications': <dynamic>[],
      'sponsorApplications': <dynamic>[],
      'awardRecords': <dynamic>[],
      'thankYouMessages': <dynamic>[],
      'pointEvents': <String, dynamic>{},
    };

    final merged = ClubOpsSync.applyRemoteSlice(local, 'c_test', remote);
    expect(merged.duesPayments.any((p) => p.id == 'pay_local_1'), isTrue);
    expect(merged.duesSettings.any((d) => d.id == 'ds_club_1'), isTrue);
  });

  test('원격 거래가 비어 있어도 로컬 회비 수입 거래(잔고)는 유지한다', () {
    final paidAt = DateTime(2026, 3, 1);
    final local = ClubDataBundle(
      selectedClubIndex: 0,
      freshClubIds: {'c_test'},
      myClubs: [
        Club(
          id: 'c_test',
          name: '테스트',
          myRole: '총무',
          memberCount: 1,
          region: '서울',
          industry: 'IT',
          teamCount: 4,
        ),
      ],
      allClubs: const [],
      joinRequests: const [],
      members: const [],
      activities: const [],
      announcements: const [],
      appNotifications: const [],
      duesSettings: [
        DuesSetting(
          id: 'ds_club_1',
          type: DuesType.monthly,
          amount: 50000,
          title: '2026년 월회비',
          createdAt: DateTime(2026, 1, 1),
          clubId: 'c_test',
        ),
      ],
      duesPayments: [
        DuesPayment(
          id: 'pay_local_1',
          memberId: 'm1',
          memberName: '홍길동',
          duesSettingId: 'ds_club_1',
          amount: 50000,
          paidAt: paidAt,
          recordedBy: '총무',
        ),
      ],
      paymentRequests: const [],
      transactions: [
        Transaction(
          id: 'tx_local_1',
          type: TxType.income,
          category: '회비',
          amount: 50000,
          title: '홍길동 월회비',
          date: paidAt,
          recordedBy: '총무',
          source: TxSource.dues,
          duesPaymentId: 'pay_local_1',
          clubId: 'c_test',
        ),
      ],
      schedules: const [],
      photos: const [],
      groupAssignments: const {},
      adApplications: const [],
      adNotifications: const [],
      sponsorApplications: const [],
      pointEvents: const {},
      awardRecords: const [],
      thankYouMessages: const [],
      waitingList: const [],
      alimtalkSettings: const {},
    );

    final remote = <String, dynamic>{
      'clubId': 'c_test',
      'schedules': <dynamic>[],
      'announcements': <dynamic>[],
      'members': <dynamic>[],
      'activities': <dynamic>[],
      'duesSettings': [
        {
          'id': 'ds_club_1',
          'type': 'monthly',
          'amount': 50000,
          'title': '2026년 월회비',
          'createdAt': DateTime(2026, 1, 1).toIso8601String(),
          'isActive': true,
          'clubId': 'c_test',
          'amountHistory': <dynamic>[],
        },
      ],
      'duesPayments': <dynamic>[],
      'paymentRequests': <dynamic>[],
      'transactions': <dynamic>[],
      'photos': <dynamic>[],
      'groupAssignments': <String, dynamic>{},
      'waitingList': <dynamic>[],
      'alimtalkSettings': <String, dynamic>{},
      'adApplications': <dynamic>[],
      'adNotifications': <dynamic>[],
      'sponsorApplications': <dynamic>[],
      'awardRecords': <dynamic>[],
      'thankYouMessages': <dynamic>[],
      'pointEvents': <String, dynamic>{},
    };

    final merged = ClubOpsSync.applyRemoteSlice(local, 'c_test', remote);
    expect(merged.duesPayments.any((p) => p.id == 'pay_local_1'), isTrue);
    expect(merged.transactions.any((t) => t.id == 'tx_local_1'), isTrue);
    expect(
      merged.transactions
          .where((t) => t.clubId == 'c_test')
          .fold<int>(
            0,
            (s, t) => s + (t.type == TxType.income ? t.amount : -t.amount),
          ),
      50000,
    );
  });

  group('capacity / scale guards', () {
    test('huge dues and transaction amounts round-trip in codec', () {
      const huge = 2100000000; // ~21억 원 — JS 안전정수 안쪽
      final bundle = ClubDataBundle(
        selectedClubIndex: 0,
        freshClubIds: {'c_test'},
        myClubs: [
          Club(
            id: 'c_test',
            name: '테스트',
            myRole: '총무',
            memberCount: 1,
            region: '서울',
            industry: 'IT',
            teamCount: 4,
          ),
        ],
        allClubs: const [],
        joinRequests: const [],
        members: const [],
        activities: const [],
        announcements: const [],
        appNotifications: const [],
        duesSettings: [
          DuesSetting(
            id: 'ds1',
            type: DuesType.monthly,
            amount: huge,
            title: '대형회비',
            createdAt: DateTime(2026, 1, 1),
            clubId: 'c_test',
          ),
        ],
        duesPayments: [
          DuesPayment(
            id: 'pay_huge',
            memberId: 'm1',
            memberName: '홍길동',
            duesSettingId: 'ds1',
            amount: huge,
            paidAt: DateTime(2026, 1, 5),
            recordedBy: '총무',
          ),
        ],
        paymentRequests: const [],
        transactions: [
          Transaction(
            id: 'tx_huge',
            clubId: 'c_test',
            type: TxType.income,
            amount: huge,
            category: '회비',
            title: '대형',
            date: DateTime(2026, 1, 5),
            recordedBy: '총무',
          ),
        ],
        schedules: const [],
        photos: const [],
        groupAssignments: const {},
        adApplications: const [],
        adNotifications: const [],
        sponsorApplications: const [],
        pointEvents: const {},
        awardRecords: const [],
        thankYouMessages: const [],
        waitingList: const [],
        alimtalkSettings: const {},
      );

      final encoded = ClubDataCodec.encode(bundle);
      final decoded = ClubDataCodec.decode(encoded);
      expect(decoded.duesSettings.single.amount, huge);
      expect(decoded.duesPayments.single.amount, huge);
      expect(decoded.transactions.single.amount, huge);
      expect(
        decoded.transactions.fold<int>(
          0,
          (s, t) => s + (t.type == TxType.income ? t.amount : -t.amount),
        ),
        huge,
      );
    });

    test('oversized photo data URI is omitted for Firestore', () {
      final hugeUri = 'data:image/jpeg;base64,${'A' * (ClubOpsSync.photoDataUriMaxChars + 10)}';
      final prepared = ClubOpsSync.preparePhotoMapForFirestore({
        'id': 'p1',
        'clubId': 'c_test',
        'imageUrl': hugeUri,
      });
      expect(prepared['imageUrl'], '');
      expect(prepared['imageOmitted'], isTrue);

      final ok = ClubOpsSync.preparePhotoMapForFirestore({
        'id': 'p2',
        'imageUrl': 'data:image/jpeg;base64,abc',
      });
      expect(ok['imageUrl'], 'data:image/jpeg;base64,abc');
      expect(ok['imageOmitted'], isNull);
    });

    test('dense schedule history can exceed ops bundle soft limit', () {
      // 참석 응답이 많은 일정이 쌓이면 단일 ops/bundle 문서(~1MB)를 넘길 수 있다.
      final schedules = List.generate(280, (i) {
        return <String, dynamic>{
          'id': 's_$i',
          'clubId': 'c_test',
          'title': '정기라운드 ${i + 1}회차 오전부 동코스 모임',
          'roundDate': DateTime(2020, 1, 1).add(Duration(days: i * 7)).toIso8601String(),
          'teeTime': '07:00',
          'courseName': '테스트CC 동코스 프론트나인',
          'teamCount': 8,
          'status': 'completed',
          'createdBy': '홍길동',
          'note': '메모 내용이 조금 긴 일정 설명입니다. ' * 3,
          'responses': List.generate(30, (j) {
            return <String, dynamic>{
              'memberId': 'm_$j',
              'memberName': '회원이름충분하게$j',
              'status': 'attending',
              'respondedAt': DateTime(2020, 1, 2).toIso8601String(),
              'companions': <dynamic>[
                {'name': '동반A$j', 'gender': '남'},
                {'name': '동반B$j', 'gender': '여'},
              ],
            };
          }),
        };
      });
      final groupAssignments = <String, dynamic>{};
      for (var i = 0; i < 280; i++) {
        groupAssignments['s_$i'] = {
          'scheduleId': 's_$i',
          'teamCount': 8,
          'perGroup': 4,
          'isFinalized': true,
          'groups': List.generate(8, (g) {
            return {
              'index': g,
              'memberIds': List.generate(4, (m) => 'm_${g * 4 + m}'),
            };
          }),
        };
      }
      final slice = <String, dynamic>{
        'clubId': 'c_test',
        'schedules': schedules,
        'groupAssignments': groupAssignments,
        'members': List.generate(40, (j) => {
              'id': 'm_$j',
              'name': '회원이름충분$j',
              'phone': '0101234${j.toString().padLeft(4, '0')}',
            }),
        'duesPayments': List.generate(400, (i) {
          return {
            'id': 'pay_$i',
            'clubId': 'c_test',
            'memberId': 'm_${i % 40}',
            'memberName': '회원${i % 40}',
            'amount': 50000,
            'year': 2020 + (i ~/ 12),
            'month': (i % 12) + 1,
            'paidAt': DateTime(2020, 1, 1).toIso8601String(),
            'recordedBy': '총무',
          };
        }),
        'transactions': List.generate(400, (i) {
          return {
            'id': 'tx_$i',
            'clubId': 'c_test',
            'type': 'income',
            'amount': 50000,
            'category': '회비',
            'title': '납부 $i',
            'date': DateTime(2020, 1, 1).toIso8601String(),
            'recordedBy': '총무',
          };
        }),
        'announcements': <dynamic>[],
        'photos': <dynamic>[],
      };
      final bytes = ClubOpsSync.estimateJsonBytes(slice);
      expect(
        bytes,
        greaterThan(ClubOpsSync.opsBundleSoftLimitBytes),
        reason: '이 규모면 soft limit을 넘겨 Firestore push 실패 가능 — 구조 분리 필요 신호',
      );
    });

    test('many photo metas without data URIs stay under soft limit', () {
      final photos = List.generate(300, (i) {
        return <String, dynamic>{
          'id': 'p_$i',
          'clubId': 'c_test',
          'uploaderId': 'm1',
          'uploaderName': '홍길동',
          'imageUrl': '',
          'imageOmitted': true,
          'caption': '캡션 $i',
          'takenAt': DateTime(2026, 1, 1).add(Duration(minutes: i)).toIso8601String(),
        };
      });
      final bytes = ClubOpsSync.estimateJsonBytes({'photos': photos});
      expect(bytes, lessThan(ClubOpsSync.opsBundleSoftLimitBytes));
    });
  });
}
