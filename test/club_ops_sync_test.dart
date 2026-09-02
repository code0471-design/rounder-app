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
}
