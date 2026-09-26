import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/data/mappers/club_mapper.dart';
import 'package:golf_rounder/data/mappers/member_mapper.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/domain/services/app_data_bootstrap_service.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:golf_rounder/services/club_data_codec.dart';
import 'package:golf_rounder/services/club_ops_sync.dart';
import 'package:golf_rounder/utils/member_join_date.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _read(String relative) => File(relative).readAsStringSync();

void main() {
  const arenaId = 'c_1786973797931';
  final arenaOpen = DateTime.fromMillisecondsSinceEpoch(1786973797931);

  test('모임 id 시각이 개설일이다', () {
    expect(MemberJoinDate.createdAtFromClubId(arenaId), arenaOpen);
  });

  test('덮인 개설일은 모임 id 시각으로 되돌린다', () {
    final club = Club(
      id: arenaId,
      name: '아레나 골프회',
      myRole: '회장',
      memberCount: 2,
      creatorId: 'kakao_host',
      createdAt: DateTime(2026, 9, 25, 21, 10),
    );
    expect(MemberJoinDate.resolvedClubCreatedAt(club), arenaOpen);
  });

  test('모임장 가입일은 개설일이다', () {
    final club = Club(
      id: arenaId,
      name: '아레나 골프회',
      myRole: '회장',
      memberCount: 2,
      creatorId: 'kakao_host',
      createdAt: arenaOpen,
    );
    final host = Member(
      id: 'm_creator_$arenaId',
      name: '안경헌',
      gender: '남',
      memberType: '정회원',
      role: '회장',
      joinDate: DateTime(2026, 9, 25),
    );
    expect(
      MemberJoinDate.repair(member: host, club: club),
      arenaOpen,
    );
  });

  test('초대 회원은 있는 가입일보다 이른 초대일만 쓴다', () {
    final club = Club(
      id: arenaId,
      name: '아레나 골프회',
      myRole: '정회원',
      memberCount: 2,
      creatorId: 'kakao_host',
      createdAt: arenaOpen,
    );
    final lee = Member(
      id: 'm_${arenaId}_lee',
      name: '이정원',
      gender: '남',
      memberType: '정회원',
      role: '정회원',
      joinDate: DateTime(2026, 9, 25),
    );
    expect(
      MemberJoinDate.repair(
        member: lee,
        club: club,
        evidenceAt: DateTime(2026, 9, 12),
      ),
      DateTime(2026, 9, 12),
    );
    expect(
      MemberJoinDate.repair(member: lee, club: club),
      DateTime(2026, 9, 25),
    );
  });

  test('개설일보다 앞선 가입일은 버리고 초대일을 쓴다', () {
    final club = Club(
      id: arenaId,
      name: '아레나 골프회',
      myRole: '정회원',
      memberCount: 2,
      creatorId: 'kakao_host',
      createdAt: arenaOpen,
    );
    final lee = Member(
      id: 'm_${arenaId}_lee',
      name: '이정원',
      gender: '남',
      memberType: '정회원',
      role: '정회원',
      joinDate: DateTime(2026, 7, 22),
    );
    expect(
      MemberJoinDate.repair(
        member: lee,
        club: club,
        evidenceAt: DateTime(2026, 9, 20),
      ),
      DateTime(2026, 9, 20),
    );
    expect(
      MemberJoinDate.keepEarlier(
        DateTime(2026, 7, 22),
        DateTime(2026, 9, 20),
        notBefore: arenaOpen,
      ),
      DateTime(2026, 9, 20),
    );
  });

  test('있는 가입일을 오늘로 덮지 않는다', () {
    final existing = DateTime(2026, 9, 12);
    expect(
      MemberJoinDate.keepEarlier(existing, DateTime(2026, 9, 25)),
      existing,
    );
    expect(MemberJoinDate.keepEarlier(existing, null), existing);
    expect(MemberJoinDate.forNewRow(
      isCreator: false,
      clubCreatedAt: arenaOpen,
      inherit: existing,
      eventAt: DateTime.now(),
    ), existing);
    expect(MemberJoinDate.forNewRow(
      isCreator: true,
      clubCreatedAt: arenaOpen,
    ), arenaOpen);
  });

  test('join_date 없는 명단을 읽어도 오늘이 되지 않는다', () {
    final m = MemberMapper.fromMap('m1', {
      'name': '이정원',
      'gender': '남',
      'member_type': '정회원',
      'role': '정회원',
    });
    expect(m.joinDate, isNull);
    final encoded = MemberMapper.toMap(m);
    expect(encoded.containsKey('join_date'), isFalse);
  });

  test('개설일 없는 모임 문서는 id 시각을 쓴다', () {
    final club = ClubMapper.fromMap(arenaId, {
      'name': '아레나 골프회',
      'member_count': 2,
      'creator_id': 'kakao_host',
    });
    expect(club.createdAt, arenaOpen);
  });

  test('원격이 나중 가입일로 덮어도 이른 날을 지킨다', () {
    final local = ClubDataBundle(
      selectedClubIndex: 0,
      freshClubIds: {arenaId},
      myClubs: [
        Club(
          id: arenaId,
          name: '아레나 골프회',
          myRole: '회장',
          memberCount: 2,
          creatorId: 'kakao_host',
          createdAt: arenaOpen,
        ),
      ],
      allClubs: const [],
      joinRequests: const [],
      members: [
        Member(
          id: 'm_creator_$arenaId',
          name: '안경헌',
          gender: '남',
          memberType: '정회원',
          role: '회장',
          joinDate: arenaOpen,
          status: '활성',
        ),
        Member(
          id: 'm_${arenaId}_lee',
          name: '이정원',
          gender: '남',
          memberType: '정회원',
          role: '정회원',
          joinDate: DateTime(2026, 9, 12),
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

    final overwritten = DateTime(2026, 9, 25).toIso8601String();
    final merged = ClubOpsSync.applyRemoteSlice(local, arenaId, {
      'members': [
        {
          'id': 'm_creator_$arenaId',
          'name': '안경헌',
          'gender': '남',
          'memberType': '정회원',
          'role': '회장',
          'joinDate': overwritten,
          'status': '활성',
        },
        {
          'id': 'm_${arenaId}_lee',
          'name': '이정원',
          'gender': '남',
          'memberType': '정회원',
          'role': '정회원',
          'joinDate': overwritten,
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
    });

    final host = merged.members.singleWhere((m) => m.id == 'm_creator_$arenaId');
    final lee = merged.members.singleWhere((m) => m.id == 'm_${arenaId}_lee');
    expect(host.joinDate, arenaOpen);
    expect(lee.joinDate, DateTime(2026, 9, 12));
  });

  test('앱에서 모임장 가입일이 개설일보다 뒤면 되돌린다', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    AppDependencies.instance.init(offlineMock: true);
    final clubs = ClubProvider();
    await clubs.switchUser('kakao_host', displayName: '안경헌');
    final club = Club(
      id: arenaId,
      name: '아레나 골프회',
      myRole: '회장',
      memberCount: 2,
      creatorId: 'kakao_host',
      createdAt: DateTime(2026, 9, 25),
    );
    clubs.hydrateFromBootstrap(AppBootstrapSnapshot(
      userId: 'kakao_host',
      myClubs: [club],
      discoverableClubs: [club],
      membersByClubId: const {},
      financeByClubId: const {},
      loadedAt: DateTime(2026, 9, 26),
    ));
    clubs.addMember(Member(
      id: 'm_creator_$arenaId',
      name: '안경헌',
      gender: '남',
      memberType: '정회원',
      role: '회장',
      joinDate: DateTime(2026, 9, 25),
    ));
    clubs.addMember(Member(
      id: 'm_${arenaId}_lee',
      name: '이정원',
      gender: '남',
      memberType: '정회원',
      role: '정회원',
      joinDate: DateTime(2026, 9, 25),
    ));
    clubs.addActivityForTest(ActivityItem(
      id: 'act_lee',
      memberId: 'm_${arenaId}_lee',
      memberName: '이정원',
      activityType: 'join',
      description: '초대 링크로 즉시 가입',
      timestamp: DateTime(2026, 9, 12),
    ));

    expect(clubs.repairRosterJoinDates(), isTrue);
    final host = clubs.membersForClub(arenaId).singleWhere(
          (m) => m.id == 'm_creator_$arenaId',
        );
    final lee = clubs.membersForClub(arenaId).singleWhere(
          (m) => m.id == 'm_${arenaId}_lee',
        );
    expect(host.joinDate, arenaOpen);
    expect(lee.joinDate, DateTime(2026, 9, 12));
  });

  test('명단 다시 쓸 때 가입일을 now 로 넣지 않는다', () {
    final src = _read('lib/providers/club_provider.dart');
    final self = src.substring(
      src.indexOf('Member _selfMember('),
      src.indexOf('데모 시드 계정 이름'),
    );
    expect(self.contains('DateTime.now()'), isFalse);
    expect(src.contains('joinDate: newClub.createdAt'), isTrue);
    expect(src.contains('joinDate: orphan?.joinDate ??'), isTrue);
    expect(src.contains('bool repairRosterJoinDates()'), isTrue);

    final mapper = _read('lib/data/mappers/member_mapper.dart');
    expect(mapper.contains("?? DateTime.now()"), isFalse);
  });
}
