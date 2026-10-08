import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/services/club_data_codec.dart';
import 'package:golf_rounder/services/club_ops_sync.dart';

void main() {
  test('다른 폰에 없는 일정은 올릴 때 서버 일정을 지우지 않는다', () {
    final merged = ClubOpsSync.mergeRowsById(
      local: [
        {'id': 'old', 'title': '예전'},
      ],
      remote: [
        {'id': 'old', 'title': '예전-서버수정'},
        {'id': 'sep25', 'title': '더크로스비', 'roundDate': '2026-09-25'},
      ],
      localWins: true,
    );
    expect(merged.any((e) => e['id'] == 'sep25'), isTrue,
        reason: '이 폰 목록에 없어도 서버에 있는 9/25 일정은 남긴다');
    expect(
      merged.firstWhere((e) => e['id'] == 'old')['title'],
      '예전',
      reason: '이 폰이 가진 일정은 이 폰 내용을 유지한다',
    );
  });

  test('정원 초과 참석은 먼저 응답한 사람만 남긴다', () {
    final capped = ClubOpsSync.capScheduleAttendance([
      {
        'id': 's1',
        'teamCount': 1,
        'responses': [
          {'memberId': 'a', 'response': '참석', 'respondedAt': '2026-01-01'},
          {'memberId': 'b', 'response': '참석', 'respondedAt': '2026-01-02'},
          {'memberId': 'c', 'response': '참석', 'respondedAt': '2026-01-03'},
          {'memberId': 'd', 'response': '참석', 'respondedAt': '2026-01-04'},
          {'memberId': 'e', 'response': '참석', 'respondedAt': '2026-01-05'},
        ],
      },
    ]);
    final responses = (capped.first as Map)['responses'] as List;
    expect(responses.length, 4);
    expect(responses.any((r) => r['memberId'] == 'e'), isFalse);
  });

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
    expect(merged.schedules.any((s) => s.id == 's_local'), isTrue,
        reason: '이 폰에서만 만든 일정은 서버에 다른 일정이 있어도 지우면 안 된다');
    expect(merged.members.any((m) => m.id == 'm_c_test_u2'), isTrue);
  });

  test('빈 원격 참석이 로컬 참석을 덮지 않는다', () {
    final kept = ClubOpsSync.mergeAttendanceResponses(
      [
        {
          'memberId': 'a',
          'response': '참석',
          'respondedAt': '2026-10-01T00:00:00.000',
        },
      ],
      <dynamic>[],
    );
    expect(kept.single['memberId'], 'a');
    expect(kept.single['response'], '참석');

    final newer = ClubOpsSync.mergeAttendanceResponses(
      [
        {
          'memberId': 'a',
          'response': '참석',
          'respondedAt': '2026-10-01T00:00:00.000',
        },
      ],
      [
        {
          'memberId': 'a',
          'response': '불참',
          'respondedAt': '2026-10-02T00:00:00.000',
        },
      ],
    );
    expect(newer.single['response'], '불참');

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
          id: 's1',
          clubId: 'c_test',
          title: '10월',
          roundDate: DateTime(2026, 10, 10),
          teeTime: '07:00',
          courseName: 'A',
          teamCount: 4,
          status: ScheduleStatus.upcoming,
          createdBy: '안경헌',
          responses: [
            AttendanceResponse(
              memberId: 'a',
              memberName: 'A',
              response: '참석',
              respondedAt: DateTime(2026, 10, 1),
            ),
          ],
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
      'schedules': [
        {
          'id': 's1',
          'clubId': 'c_test',
          'title': '10월',
          'roundDate': DateTime(2026, 10, 10).toIso8601String(),
          'teeTime': '07:00',
          'courseName': 'A',
          'teamCount': 4,
          'status': 'upcoming',
          'createdBy': '안경헌',
          'responses': <dynamic>[],
        },
      ],
    });
    expect(merged.schedules.single.responses.single.memberId, 'a');
    expect(merged.schedules.single.responses.single.response, '참석');
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
    expect(ClubOpsSync.isMemberRemoved('m_c_arena_m1'), isTrue);
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

    test('탈퇴 행의 leftAt 은 원격 활성이 덮지 않는다', () {
      ClubOpsSync.markMemberRemoved('m_c_test_left');
      final leftAt = DateTime(2026, 8, 1);
      final local = bundleWith([
        Member(
          id: 'm_c_test_left',
          name: '박탈퇴',
          gender: '남',
          memberType: '정회원',
          role: '일반',
          joinDate: DateTime(2024, 1, 1),
          status: '탈퇴',
          leftAt: leftAt,
        ),
      ]);
      final merged = ClubOpsSync.applyRemoteSlice(
        local,
        'c_test',
        remoteWith([remoteMember('m_c_test_left', '박탈퇴', '활성')]),
      );
      final row = merged.members.firstWhere((m) => m.id == 'm_c_test_left');
      expect(row.status, '탈퇴');
      expect(row.leftAt, leftAt);
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

  test('같은 일정·같은 시상명이 다른 id 면 한 줄로 합친다', () {
    final collapsed = ClubOpsSync.collapseAwardRecords([
      {
        'id': 'ar_s1_a1',
        'scheduleId': 's1',
        'awardName': '메달리스트',
        'winnerIds': ['m1'],
        'winnerNames': ['이정원'],
        'recordedAt': '2026-09-15T07:00:00.000',
      },
      {
        'id': 'ar_s1_ar_s1_a1',
        'scheduleId': 's1',
        'awardName': '메달리스트',
        'winnerIds': ['m1'],
        'winnerNames': ['이정원'],
        'recordedAt': '2026-09-15T08:00:00.000',
      },
      {
        'id': 'ar_s1_a2',
        'scheduleId': 's1',
        'awardName': '니어리스트',
        'winnerIds': ['m2'],
        'winnerNames': ['안경헌'],
        'recordedAt': '2026-09-15T07:00:00.000',
      },
    ]);
    expect(collapsed.length, 2, reason: '메달리스트가 저장마다 두 줄이면 횟수가 두 배다');
    expect(
      collapsed.where((e) => e['awardName'] == '메달리스트').length,
      1,
    );
    expect(collapsed.singleWhere((e) => e['awardName'] == '메달리스트')['id'],
        'ar_s1_메달리스트');
    expect(
      collapsed.singleWhere((e) => e['awardName'] == '니어리스트')['id'],
      'ar_s1_a2',
      reason: '한 줄짜리 시상 id 를 바꾸면 watch 가 다시 돌고 회원수가 깜빡인다',
    );
  });

  test('시상이 한 줄이면 id 를 그대로 둔다', () {
    final collapsed = ClubOpsSync.collapseAwardRecords([
      {
        'id': 'ar_s1_a1',
        'scheduleId': 's1',
        'awardName': '메달리스트',
        'winnerIds': ['m1'],
        'winnerNames': ['이정원'],
        'recordedAt': '2026-09-15T07:00:00.000',
      },
    ]);
    expect(collapsed.single['id'], 'ar_s1_a1',
        reason: '중복이 아닌데 id 를 갈아끼우면 시상 저장 뒤 명단이 다시 돌아간다');
  });

  test('원격 옛 시상과 로컬 새 id 를 합쳐도 횟수가 늘지 않는다', () {
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
          id: 's1',
          clubId: 'c_test',
          title: '추가월례회',
          roundDate: DateTime(2026, 9, 15),
          teeTime: '07:30',
          courseName: 'A',
          teamCount: 1,
          status: ScheduleStatus.done,
          createdBy: '이정원',
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
          id: 'ar_s1_ar_s1_a1',
          scheduleId: 's1',
          scheduleName: '추가월례회',
          awardName: '메달리스트',
          awardIcon: '🥇',
          winnerIds: const ['m1'],
          winnerNames: const ['이정원'],
          recordedAt: DateTime(2026, 9, 15, 8),
        ),
      ],
      roundScores: const [],
      thankYouMessages: const [],
      waitingList: const [],
      alimtalkSettings: const {},
    );
    final merged = ClubOpsSync.applyRemoteSlice(local, 'c_test', {
      'clubId': 'c_test',
      'schedules': [
        {
          'id': 's1',
          'clubId': 'c_test',
          'title': '추가월례회',
          'roundDate': DateTime(2026, 9, 15).toIso8601String(),
          'teeTime': '07:30',
          'courseName': 'A',
          'teamCount': 1,
          'status': 'done',
          'createdBy': '이정원',
          'responses': <dynamic>[],
        },
      ],
      'awardRecords': [
        {
          'id': 'ar_s1_a1',
          'scheduleId': 's1',
          'scheduleName': '추가월례회',
          'awardName': '메달리스트',
          'awardIcon': '🥇',
          'winnerIds': ['m1'],
          'winnerNames': ['이정원'],
          'winnerNote': null,
          'recordedAt': DateTime(2026, 9, 15, 7).toIso8601String(),
        },
      ],
      'members': <dynamic>[],
    });
    expect(merged.awardRecords.length, 1,
        reason: '회원탭 다시 들어갈 때마다 시상 줄이 늘면 안 된다');
    expect(merged.awardRecords.single.awardName, '메달리스트');
  });

  test('강남 시상에 남은 장창현 이름은 그 모임 회원 이름으로 고친다', () {
    const gangnam = 'c_1788832826557';
    final fixed = ClubOpsSync.rewriteLeftoverAwardWinnerNames(
      awards: [
        {
          'id': 'ar1',
          'scheduleId': 'sched_test',
          'awardName': '메달리스트',
          'winnerIds': ['m_creator_$gangnam'],
          'winnerNames': ['장창현'],
        },
      ],
      members: [
        {'id': 'm_creator_$gangnam', 'name': '안경헌'},
      ],
      clubId: gangnam,
    );
    expect(fixed.single['winnerNames'], ['안경헌'],
        reason: '혼자인 모임에 장창현 메달리스트가 보이면 안 된다');
    expect(fixed.single['winnerIds'], ['m_creator_$gangnam']);
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
      isFalse,
      reason: '총무가 만든 사람이 아니어도 이름만으로 지우면 회원 탭에서 사라진다',
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
    expect(
      ClubOpsSync.isForeignLeftoverMember(
        id: 'm_creator_c_1786973797931',
        name: '장창현',
        clubId: 'c_1786973797931',
        creatorUserId: 'kakao_5049673364',
      ),
      isTrue,
      reason: '아레나 방장 자리에 남은 장창현은 찌꺼기다',
    );
    expect(
      ClubOpsSync.isForeignLeftoverMember(
        id: 'm_creator_c_new_aladdin',
        name: '장창현',
        clubId: 'c_new_aladdin',
        creatorUserId: 'kakao_5049673364',
      ),
      isFalse,
      reason: '새로 만든 모임의 방장 장창현까지 지우면 정회원 폰에는 본인만 남는다',
    );
    final shown = ClubOpsSync.assignClubRosterIds(
      [
        {'id': 'kakao_5049673364', 'name': '장창현', 'role': '총무'},
        {'id': 'kakao_me', 'name': '안경헌', 'role': '정회원'},
      ],
      clubId: 'c_new_aladdin',
      creatorUserId: 'kakao_5049673364',
    );
    expect(shown[0]['id'], 'm_creator_c_new_aladdin');
    expect(shown[1]['id'], 'm_c_new_aladdin_kakao_me');

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
    expect(kept.map((e) => (e as Map)['name']), ['안경헌', '장창현']);
    expect(
      ClubOpsSync.isMemberRemoved('m_${gangnam}_kakao_5049673364'),
      isFalse,
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

  test('지운 회비 설정은 원격 옛 목록이 되살리지 못한다', () {
    ClubOpsSync.resetDuesSettingTombstones();
    addTearDown(ClubOpsSync.resetDuesSettingTombstones);
    ClubOpsSync.markDuesSettingRemoved('ds_club_1', clubId: 'c_test');

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
    });
    expect(merged.duesSettings.any((d) => d.id == 'ds_club_1'), isFalse,
        reason: '회비를 지운 뒤 동기화가 다시 넣으면 삭제가 안 된다');
  });

  test('회비 수정은 원격 옛 제목으로 돌아가지 않는다', () {
    ClubOpsSync.resetDuesSettingTombstones();
    addTearDown(ClubOpsSync.resetDuesSettingTombstones);
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
          amount: 70000,
          title: '새 월회비',
          createdAt: DateTime(2026, 1, 1),
          clubId: 'c_test',
        ),
      ],
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
      'duesSettings': [
        {
          'id': 'ds_club_1',
          'type': 'monthly',
          'amount': 50000,
          'title': '옛 월회비',
          'createdAt': DateTime(2026, 1, 1).toIso8601String(),
          'isActive': true,
          'clubId': 'c_test',
          'amountHistory': <dynamic>[],
        },
      ],
    });
    expect(merged.duesSettings.single.title, '새 월회비');
    expect(merged.duesSettings.single.amount, 70000);
  });

  test('원격 명단 사진이 비어도 로컬 프로필 사진을 유지한다', () {
    final local = ClubDataBundle(
      selectedClubIndex: 0,
      freshClubIds: {'c_test'},
      myClubs: [
        Club(
          id: 'c_test',
          name: '테스트',
          myRole: '회장',
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
          photoUrl: 'data:image/jpeg;base64,abc',
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
      'members': [
        {
          'id': 'm_creator_c_test',
          'name': '안경헌',
          'gender': '남',
          'memberType': '정회원',
          'role': '회장',
          'joinDate': DateTime(2024, 1, 1).toIso8601String(),
          'status': '활성',
        },
      ],
    });
    expect(merged.members.single.photoUrl, 'data:image/jpeg;base64,abc',
        reason: '원격이 사진을 빼면 내 프로필 사진이 사라진다');
  });

  test('빈 원격이 정회원 전환·regularSince 를 게스트로 되돌리지 않는다', () {
    final converted = DateTime(2026, 9, 20);
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
        ),
      ],
      allClubs: const [],
      joinRequests: const [],
      members: [
        Member(
          id: 'm_c_test_kakao_g',
          name: '전환회원',
          gender: '남',
          memberType: '정회원',
          role: '정회원',
          joinDate: DateTime(2026, 7, 1),
          regularSince: converted,
          memberTypeUpdatedAt: converted,
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
      'members': [
        {
          'id': 'm_c_test_kakao_g',
          'name': '전환회원',
          'gender': '남',
          'memberType': '게스트',
          'role': '게스트',
          'joinDate': DateTime(2026, 7, 1).toIso8601String(),
          'status': '활성',
        },
      ],
    });
    final row = merged.members.singleWhere((m) => m.id == 'm_c_test_kakao_g');
    expect(row.memberType, '정회원',
        reason: '총무가 정회원으로 저장한 뒤 옛 원격 게스트가 덮으면 안 된다');
    expect(row.regularSince, converted);
    expect(row.joinDate, DateTime(2026, 7, 1),
        reason: '전환해도 가입일(게스트로 들어온 날)은 그대로다');
  });

  test('시즌 마감 확정본은 빈 원격이 지우지 않는다', () {
    final merged = ClubOpsSync.mergeSeasonLocks(
      local: [
        {
          'clubId': 'c_test',
          'year': 2026,
          'closedAt': '2026-12-01T00:00:00.000',
          'ranks': [
            {'memberId': 'm1', 'name': '이정원', 'points': 12, 'rank': 1},
          ],
        },
      ],
      remote: const [],
    );
    expect(merged.length, 1);
    expect(merged.first['year'], 2026);
    expect((merged.first['ranks'] as List).length, 1,
        reason: '이벤트 전체를 다시 복사하지 않고 확정 순위만 남긴다');
  });

  test('임원이 마감을 취소한 쪽이 옛 확정본을 이긴다', () {
    final merged = ClubOpsSync.mergeSeasonLocks(
      local: [
        {
          'clubId': 'c_test',
          'year': 2026,
          'closedAt': '2026-12-01T00:00:00.000',
          'reopenedAt': '2026-12-10T00:00:00.000',
          'ranks': [
            {'memberId': 'm1', 'name': '이정원', 'points': 12, 'rank': 1},
          ],
        },
      ],
      remote: [
        {
          'clubId': 'c_test',
          'year': 2026,
          'closedAt': '2026-12-01T00:00:00.000',
          'ranks': [
            {'memberId': 'm1', 'name': '이정원', 'points': 12, 'rank': 1},
          ],
        },
      ],
    );
    expect(merged.single['reopenedAt'], '2026-12-10T00:00:00.000');
  });

  test('가입 소속이 있는데 회원 문서가 없으면 만든다', () {
    expect(
      ClubOpsSync.shouldCreateJoinedMemberDoc(
        clubId: 'c_1790768750847',
        creatorUserId: 'kakao_5049673364',
        userId: 'kakao_5049673364',
        name: '장창현',
        existingMemberIds: {
          'google_107587661463302574049',
          'kakao_5044456654',
          'kakao_5087241992',
        },
      ),
      isTrue,
    );
  });

  test('이미 회원 문서가 있으면 다시 만들지 않는다', () {
    expect(
      ClubOpsSync.shouldCreateJoinedMemberDoc(
        clubId: 'c_1789296617949',
        creatorUserId: 'kakao_5044456654',
        userId: 'kakao_5049673364',
        name: '장창현',
        existingMemberIds: {'kakao_5044456654', 'kakao_5049673364'},
      ),
      isFalse,
    );
  });

  test('아레나 찌꺼기 이름은 회원 문서를 만들지 않는다', () {
    expect(
      ClubOpsSync.shouldCreateJoinedMemberDoc(
        clubId: 'c_1786973797931',
        creatorUserId: 'kakao_5044456654',
        userId: 'kakao_5049673364',
        name: '장창현',
        existingMemberIds: const {},
      ),
      isFalse,
    );
  });

  test('가입한 사람·방장 회원 문서는 지우지 않는다', () {
    expect(
      ClubOpsSync.shouldDeleteClubMemberDoc(
        clubId: 'c_1789270673471',
        memberDocId: 'kakao_5049673364',
        creatorUserId: 'kakao_5049673364',
        joinedUserIds: const {},
        name: '장창현',
      ),
      isFalse,
      reason: '방장 문서를 지우면 알라딘처럼 회장이 빠진다',
    );
    expect(
      ClubOpsSync.shouldDeleteClubMemberDoc(
        clubId: 'c_1790768750847',
        memberDocId: 'kakao_5087241992',
        creatorUserId: 'kakao_5049673364',
        joinedUserIds: {'kakao_5087241992'},
        name: '양우석',
      ),
      isFalse,
    );
    expect(
      ClubOpsSync.shouldDeleteClubMemberDoc(
        clubId: 'c_1786973797931',
        memberDocId: 'kakao_5049673364',
        creatorUserId: 'kakao_5044456654',
        joinedUserIds: const {},
        name: '장창현',
      ),
      isTrue,
      reason: '아레나 찌꺼기만 지운다',
    );
  });
}
