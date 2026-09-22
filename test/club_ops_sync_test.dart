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
          name: '안경헌',
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
          createdBy: '안경헌',
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
          'name': '안경헌',
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

  test('빈 원격 일정은 로컬 일정을 지우지 않는다', () {
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
          name: '안경헌',
          gender: '남',
          memberType: '정회원',
          role: '회장',
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
          createdBy: '안경헌',
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

    final merged = ClubOpsSync.applyRemoteSlice(local, 'c_test', {
      'schedules': <dynamic>[],
      'announcements': <dynamic>[],
      'members': <dynamic>[],
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
    });
    expect(merged.schedules.any((s) => s.id == 's_local'), isTrue);
    expect(merged.members.any((m) => m.id == 'm_creator_c_test'), isTrue);
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
          memberId: 'm_c_test_user',
          memberName: '안경헌',
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
          memberId: 'm_c_test_user',
          memberName: '안경헌',
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
          memberId: 'm_c_test_user',
          memberName: '안경헌',
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
          title: '안경헌 월회비',
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

  test('원격 홍길동 회원·납부·거래는 merge에서 삭제한다', () {
    ClubOpsSync.resetMemberTombstones();
    final local = ClubDataBundle(
      selectedClubIndex: 0,
      freshClubIds: {'c_arena'},
      myClubs: [
        Club(
          id: 'c_arena',
          name: '아레나',
          myRole: '총무',
          memberCount: 2,
          region: '서울',
          industry: 'IT',
          teamCount: 4,
        ),
      ],
      allClubs: const [],
      joinRequests: const [],
      members: [
        Member(
          id: 'm_creator_c_arena',
          name: '안경헌',
          gender: '남',
          memberType: '정회원',
          role: '회장',
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
      'clubId': 'c_arena',
      'schedules': <dynamic>[],
      'announcements': <dynamic>[],
      'members': [
        {
          'id': 'm_creator_c_arena',
          'name': '안경헌',
          'gender': '남',
          'memberType': '정회원',
          'role': '회장',
          'joinDate': DateTime(2024, 1, 1).toIso8601String(),
          'status': '활성',
        },
        {
          'id': 'm1',
          'name': '홍길동',
          'gender': '남',
          'memberType': '정회원',
          'role': '일반',
          'joinDate': DateTime(2024, 1, 1).toIso8601String(),
          'status': '활성',
        },
      ],
      'activities': <dynamic>[],
      'duesSettings': <dynamic>[],
      'duesPayments': [
        {
          'id': 'pay_ghost',
          'memberId': 'm1',
          'memberName': '홍길동',
          'duesSettingId': 'ds_1',
          'amount': 50000,
          'paidAt': DateTime(2026, 3, 1).toIso8601String(),
          'recordedBy': '총무',
        },
      ],
      'paymentRequests': <dynamic>[],
      'transactions': [
        {
          'id': 'tx_ghost',
          'type': 'income',
          'category': '회비',
          'amount': 50000,
          'title': '9월 월회비 - 홍길동',
          'date': DateTime(2026, 3, 1).toIso8601String(),
          'recordedBy': '총무',
          'clubId': 'c_arena',
        },
      ],
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

    final merged = ClubOpsSync.applyRemoteSlice(local, 'c_arena', remote);
    expect(merged.members.any((m) => m.name.contains('홍길동')), isFalse);
    expect(merged.members.any((m) => m.id == 'm1'), isFalse);
    expect(merged.duesPayments.any((p) => p.id == 'pay_ghost'), isFalse);
    expect(merged.transactions.any((t) => t.id == 'tx_ghost'), isFalse);
    expect(merged.members.any((m) => m.id == 'm_creator_c_arena'), isTrue);
    expect(ClubOpsSync.isMemberRemoved('m1'), isTrue);
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
            memberId: 'm_c_test_user',
            memberName: '안경헌',
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

  group('강퇴·탈퇴 회원은 원격이 되살리지 못한다', () {
    // 회원은 hard delete 가 없고 status 만 바뀐다. 그런데 members merge 는
    // 같은 id 면 원격 레코드로 통째 교체하므로, push 가 늦으면 원격의 옛
    // '활성' 행이 로컬 강퇴를 덮었다. (테스트 회원 '홍길동' 부활 경로)
    setUp(ClubOpsSync.resetMemberTombstones);

    ClubDataBundle bundleWith(List<Member> members) => ClubDataBundle(
          selectedClubIndex: 0,
          freshClubIds: {'c_test'},
          myClubs: [
            Club(
              id: 'c_test',
              name: '테스트',
              myRole: '총무',
              memberCount: members.length,
              region: '서울',
              industry: 'IT',
              teamCount: 4,
            ),
          ],
          allClubs: const [],
          joinRequests: const [],
          members: members,
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

    Map<String, dynamic> remoteMember(String id, String name, String status) => {
          'id': id,
          'name': name,
          'gender': '남',
          'memberType': '정회원',
          'role': '일반',
          'joinDate': DateTime(2024, 1, 1).toIso8601String(),
          'status': status,
        };

    Map<String, dynamic> remoteWith(List<Map<String, dynamic>> members) => {
          'clubId': 'c_test',
          'members': members,
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

    test('tombstone 없으면 원격 활성 행이 로컬 강퇴를 덮는다 (기존 동작)', () {
      final local = bundleWith([
        Member(
          id: 'm_c_test_keep',
          name: '안경헌',
          gender: '남',
          memberType: '정회원',
          role: '총무',
          joinDate: DateTime(2024, 1, 1),
          status: '활성',
        ),
      ]);
      final merged = ClubOpsSync.applyRemoteSlice(
        local,
        'c_test',
        remoteWith([remoteMember('m_c_test_ghost', '김유령', '활성')]),
      );
      // 표식이 없으면 합집합이므로 들어온다 — 그래서 표식이 필요하다.
      expect(merged.members.any((m) => m.id == 'm_c_test_ghost'), isTrue);
    });

    test('강퇴 표식을 남기면 원격에만 있는 행은 버린다', () {
      ClubOpsSync.markMemberRemoved('m_c_test_ghost2');
      final local = bundleWith([
        Member(
          id: 'm_c_test_keep',
          name: '안경헌',
          gender: '남',
          memberType: '정회원',
          role: '총무',
          joinDate: DateTime(2024, 1, 1),
          status: '활성',
        ),
      ]);
      final merged = ClubOpsSync.applyRemoteSlice(
        local,
        'c_test',
        remoteWith([remoteMember('m_c_test_ghost2', '홍길동', '활성')]),
      );
      expect(merged.members.any((m) => m.id == 'm_c_test_ghost2'), isFalse,
          reason: '우리가 지운 회원이 원격에서 되살아나면 안 된다');
      expect(merged.members.any((m) => m.id == 'm_c_test_keep'), isTrue,
          reason: '남은 회원은 그대로여야 한다');
    });

    test('로컬 강퇴 행이 있으면 상태를 지킨다 (기록 보존)', () {
      ClubOpsSync.markMemberRemoved('m_c_test_kicked');
      final local = bundleWith([
        Member(
          id: 'm_c_test_kicked',
          name: '김철수',
          gender: '남',
          memberType: '정회원',
          role: '일반',
          joinDate: DateTime(2024, 1, 1),
          status: '강퇴',
        ),
      ]);
      final merged = ClubOpsSync.applyRemoteSlice(
        local,
        'c_test',
        remoteWith([remoteMember('m_c_test_kicked', '김철수', '활성')]),
      );
      final row =
          merged.members.firstWhere((m) => m.id == 'm_c_test_kicked');
      expect(row.status, '강퇴',
          reason: '원격 활성이 강퇴를 덮으면 명단에 다시 나타난다');
    });

    test('표식 없는 다른 회원은 원격 값이 그대로 반영된다', () {
      final local = bundleWith([
        Member(
          id: 'm_c_test_normal',
          name: '옛이름',
          gender: '남',
          memberType: '정회원',
          role: '일반',
          joinDate: DateTime(2024, 1, 1),
          status: '활성',
        ),
      ]);
      final merged = ClubOpsSync.applyRemoteSlice(
        local,
        'c_test',
        remoteWith([remoteMember('m_c_test_normal', '새이름', '활성')]),
      );
      final row =
          merged.members.firstWhere((m) => m.id == 'm_c_test_normal');
      expect(row.name, '새이름', reason: 'tombstone 이 일반 회원 동기화를 막으면 안 된다');
    });

    test('seedRemovedMembers 로 여러 건을 한 번에 등록한다', () {
      ClubOpsSync.seedRemovedMembers(['m_c_test_s1', 'm_c_test_s2']);
      expect(ClubOpsSync.isMemberRemoved('m_c_test_s1'), isTrue);
      expect(ClubOpsSync.isMemberRemoved('m_c_test_s2'), isTrue);
      expect(ClubOpsSync.isMemberRemoved('m_c_test_never'), isFalse);
      // 빈 문자열은 무시 — 전부 걸리는 사고를 막는다.
      ClubOpsSync.markMemberRemoved('');
      expect(ClubOpsSync.isMemberRemoved(''), isFalse);
    });
  });

  test('원격 시상이 비면 로컬 시상·스코어를 지우지 않는다', () {
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
      awardRecords: [
        AwardRecord(
          id: 'ar1',
          scheduleId: 's_local',
          scheduleName: '로컬일정',
          awardName: '메달리스트',
          awardIcon: '🥇',
          winnerIds: const ['m1'],
          winnerNames: const ['홍길동'],
          recordedAt: DateTime(2026, 9, 1),
        ),
      ],
      roundScores: [
        RoundScoreRecord(
          scheduleId: 's_local',
          scores: const {'m1': 82},
          recordedAt: DateTime(2026, 9, 1),
        ),
      ],
      thankYouMessages: const [],
      waitingList: const [],
      alimtalkSettings: const {},
    );
    final merged = ClubOpsSync.applyRemoteSlice(local, 'c_test', {
      'clubId': 'c_test',
      'schedules': [
        {
          'id': 's_local',
          'clubId': 'c_test',
          'title': '로컬일정',
          'roundDate': DateTime(2026, 9, 1).toIso8601String(),
          'teeTime': '07:00',
          'courseName': 'A',
          'teamCount': 4,
          'status': 'upcoming',
          'createdBy': '홍길동',
          'responses': <dynamic>[],
        },
      ],
      'awardRecords': <dynamic>[],
      'roundScores': <dynamic>[],
      'members': <dynamic>[],
    });
    expect(merged.awardRecords, isNotEmpty);
    expect(merged.roundScores.single.scores['m1'], 82);
  });

  test('생성자·로스터 중복 회원은 pull 후에도 한 줄이다', () {
    final local = ClubDataBundle(
      selectedClubIndex: 0,
      freshClubIds: {'c_test'},
      myClubs: [
        Club(
          id: 'c_test',
          name: '테스트',
          myRole: '총무',
          memberCount: 2,
          region: '서울',
          industry: 'IT',
          teamCount: 4,
          creatorId: 'uidA',
        ),
      ],
      allClubs: const [],
      joinRequests: const [],
      members: [
        Member(
          id: 'm_creator_c_test',
          name: '안경헌',
          gender: '남',
          memberType: '정회원',
          role: '총무',
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
    final merged = ClubOpsSync.applyRemoteSlice(local, 'c_test', {
      'clubId': 'c_test',
      'members': [
        {
          'id': 'm_creator_c_test',
          'name': '안경헌',
          'gender': '남',
          'memberType': '정회원',
          'role': '총무',
          'status': '활성',
        },
        {
          'id': 'm_c_test_uidA',
          'name': '안경헌',
          'gender': '남',
          'memberType': '정회원',
          'role': '정회원',
          'status': '활성',
        },
      ],
    });
    final names = merged.members.map((m) => '${m.id}:${m.name}').toList();
    expect(names, ['m_creator_c_test:안경헌']);
  });

  test('원격 생성자가 카카오 uid 여도 명단 필터 id 로 맞춘다', () {
    final local = ClubDataBundle(
      selectedClubIndex: 0,
      freshClubIds: {'c_test'},
      myClubs: [
        Club(
          id: 'c_test',
          name: '알라딘 정기월례회',
          myRole: '정회원',
          memberCount: 1,
          region: '서울',
          industry: '골프',
          teamCount: 4,
          creatorId: 'kakao_host',
        ),
      ],
      allClubs: const [],
      joinRequests: const [],
      members: [
        Member(
          id: 'm_c_test_kakao_guest',
          name: '안경헌',
          gender: '남',
          memberType: '정회원',
          role: '정회원',
          joinDate: DateTime(2026, 9, 1),
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
    final merged = ClubOpsSync.applyRemoteSlice(local, 'c_test', {
      'clubId': 'c_test',
      'members': [
        {
          'id': 'kakao_host',
          'name': '모임장',
          'gender': '남',
          'memberType': '정회원',
          'role': '회장',
          'status': '활성',
        },
      ],
    });
    final ids = merged.members.map((m) => m.id).toSet();
    expect(ids, contains('m_creator_c_test'));
    expect(ids, contains('m_c_test_kakao_guest'));
    expect(ids, isNot(contains('kakao_host')));
  });

  test('남의 모임에 남은 장창현 소셜 행은 합쳐도 다시 안 붙는다', () {
    ClubOpsSync.resetMemberTombstones();
    addTearDown(ClubOpsSync.resetMemberTombstones);

    const gangnam = 'c_1788832826557';
    const aladdin = 'c_1789270673471';
    expect(
      ClubOpsSync.isForeignLeftoverMember(
        id: 'm_${gangnam}_kakao_5049673364',
        name: '장창현',
        clubId: gangnam,
        creatorUserId: 'kakao_5044456654',
      ),
      isTrue,
      reason: '강남 명단에 장창현이 다시 붙으면 테스터 폰에도 그대로 보인다',
    );
    expect(
      ClubOpsSync.isForeignLeftoverMember(
        id: 'm_creator_$aladdin',
        name: '장창현',
        clubId: aladdin,
        creatorUserId: 'kakao_5049673364',
      ),
      isFalse,
      reason: '알라딘 방장 장창현은 남겨야 한다',
    );

    final kept = ClubOpsSync.dropForeignLeftoverMembers(
      members: [
        {
          'id': 'm_creator_$gangnam',
          'name': '안경헌',
          'role': '회장',
        },
        {
          'id': 'm_${gangnam}_kakao_5049673364',
          'name': '장창현',
          'role': '정회원',
        },
      ],
      clubId: gangnam,
      creatorUserId: 'kakao_5044456654',
    );
    expect(kept.map((e) => (e as Map)['name']), ['안경헌']);
    expect(
      ClubOpsSync.isMemberRemoved('m_${gangnam}_kakao_5049673364'),
      isTrue,
    );
  });

  test('지운 인앱 알림은 원격 목록에서 되살아나지 않는다', () {
    ClubOpsSync.resetNotificationTombstones();
    addTearDown(ClubOpsSync.resetNotificationTombstones);

    ClubOpsSync.markNotificationRemoved('noti_old');
    final kept = ClubOpsSync.applyNotificationTombstones([
      {'id': 'noti_old', 'title': '댓글'},
      {'id': 'noti_new', 'title': '공지'},
    ]);
    expect(kept.map((e) => e['id']), ['noti_new']);
  });

  test('원격 가입 신청은 그 모임 대기열에 합쳐진다', () {
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
    final merged = ClubOpsSync.applyRemoteSlice(local, 'c_test', {
      'joinRequests': [
        {
          'id': 'jr_remote',
          'clubId': 'c_test',
          'userId': 'google_lee',
          'userName': '이정원',
          'userGender': '남',
          'message': '',
          'status': 'pending',
          'requestedAt': DateTime(2026, 9, 23).toIso8601String(),
        },
      ],
    });
    expect(merged.joinRequests.any((r) => r.id == 'jr_remote'), isTrue);
  });
}
