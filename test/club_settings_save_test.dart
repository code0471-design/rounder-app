import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/domain/services/app_data_bootstrap_service.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:golf_rounder/services/club_data_codec.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClubProvider clubs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppDependencies.instance.init(offlineMock: true);
    clubs = ClubProvider();
    await clubs.switchUser(
      'kakao_settings',
      displayName: '테스터',
      phone: '010-1111-2222',
    );
  });

  test('설정에서 고친 이름·소개·지역은 bootstrap이 덮지 않는다', () async {
    final ok = await clubs.createClub(
      name: '옛이름',
      region: '서울',
      industry: '골프',
      teamCount: 4,
      myRole: '회장',
      description: '옛소개',
    );
    expect(ok, isTrue);
    final id = clubs.selectedClub.id;

    await clubs.updateClubInfo(
      clubId: id,
      name: '새이름',
      description: '새소개',
      region: '부산',
      industry: '제조',
      teamCount: 6,
    );
    expect(clubs.selectedClub.name, '새이름');
    expect(clubs.selectedClub.description, '새소개');
    expect(clubs.selectedClub.region, '부산');
    expect(clubs.selectedClub.industry, '제조');
    expect(clubs.selectedClub.teamCount, 6);

    clubs.hydrateFromBootstrap(AppBootstrapSnapshot(
      userId: 'kakao_settings',
      myClubs: [
        Club(
          id: id,
          name: '옛이름',
          myRole: '회장',
          memberCount: 1,
          region: '서울',
          industry: '골프',
          teamCount: 4,
          description: '옛소개',
          creatorId: 'kakao_settings',
        ),
      ],
      discoverableClubs: const [],
      membersByClubId: const {},
      financeByClubId: const {},
      loadedAt: DateTime(2026, 9, 24),
    ));

    expect(clubs.selectedClub.name, '새이름',
        reason: '서버 옛 이름이 설정 저장을 지우면 안 된다');
    expect(clubs.selectedClub.description, '새소개');
    expect(clubs.selectedClub.region, '부산');
    expect(clubs.selectedClub.industry, '제조');
    expect(clubs.selectedClub.teamCount, 6);
  });

  test('설정 후 다른 화면 동기화가 옛 번들을 넣어도 모임 정보가 유지된다', () async {
    final ok = await clubs.createClub(
      name: '옛이름',
      region: '서울',
      industry: '골프',
      teamCount: 4,
      myRole: '회장',
      description: '옛소개',
    );
    expect(ok, isTrue);
    final id = clubs.selectedClub.id;
    final stale = clubs.exportBundleForTest();

    await clubs.updateClubInfo(
      clubId: id,
      name: '새이름',
      description: '새소개',
      region: '부산',
      industry: '제조',
      teamCount: 6,
    );
    expect(clubs.selectedClub.name, '새이름');

    clubs.importBundleForTest(stale);

    expect(clubs.selectedClub.name, '새이름',
        reason: '일정·홈 동기화가 옛 정보를 다시 넣어도 설정 저장을 지우면 안 된다');
    expect(clubs.selectedClub.description, '새소개');
    expect(clubs.selectedClub.region, '부산');
    expect(clubs.selectedClub.industry, '제조');
    expect(clubs.selectedClub.teamCount, 6);
  });

  test('동기화가 빈 이미지를 넣어도 있던 모임 사진은 유지된다', () async {
    expect(
      await clubs.createClub(
        name: '아레나',
        region: '서울',
        industry: '골프',
        teamCount: 4,
        myRole: '회장',
        description: '아레나',
        imageUrl: 'https://example.com/arena.jpg',
      ),
      isTrue,
    );
    final id = clubs.selectedClub.id;
    expect(clubs.selectedClub.imageUrl, 'https://example.com/arena.jpg');

    final stale = clubs.exportBundleForTest();
    final blank = ClubDataBundle(
      selectedClubIndex: stale.selectedClubIndex,
      freshClubIds: stale.freshClubIds,
      myClubs: [
        for (final c in stale.myClubs)
          c.id == id ? c.copyWith(imageUrl: '') : c,
      ],
      allClubs: stale.allClubs,
      joinRequests: stale.joinRequests,
      members: stale.members,
      activities: stale.activities,
      announcements: stale.announcements,
      appNotifications: stale.appNotifications,
      duesSettings: stale.duesSettings,
      duesPayments: stale.duesPayments,
      paymentRequests: stale.paymentRequests,
      transactions: stale.transactions,
      schedules: stale.schedules,
      photos: stale.photos,
      groupAssignments: stale.groupAssignments,
      adApplications: stale.adApplications,
      adNotifications: stale.adNotifications,
      sponsorApplications: stale.sponsorApplications,
      pointEvents: stale.pointEvents,
      awardRecords: stale.awardRecords,
      roundScores: stale.roundScores,
      thankYouMessages: stale.thankYouMessages,
      waitingList: stale.waitingList,
      alimtalkSettings: stale.alimtalkSettings,
    );

    clubs.importBundleForTest(blank);
    expect(clubs.selectedClub.imageUrl, 'https://example.com/arena.jpg',
        reason: '서버가 빈 이미지를 내려도 있던 모임 사진을 지우면 깜빡인다');
  });

  test('알라딘에 들어가 있으면 옛 번들이 아레나 선택으로 되돌리지 않는다', () async {
    expect(
      await clubs.createClub(
        name: '아레나',
        region: '서울',
        industry: '골프',
        teamCount: 4,
        myRole: '회장',
        description: '아레나',
      ),
      isTrue,
    );
    expect(
      await clubs.createClub(
        name: '알라딘',
        region: '서울',
        industry: '골프',
        teamCount: 4,
        myRole: '회장',
        description: '알라딘',
      ),
      isTrue,
    );
    expect(clubs.selectedClub.name, '알라딘');
    final arenaId = clubs.myClubs.firstWhere((c) => c.name == '아레나').id;
    final aladdinId = clubs.selectedClub.id;

    clubs.selectClubById(arenaId);
    expect(clubs.selectedClub.name, '아레나');
    final stale = clubs.exportBundleForTest();

    clubs.selectClubById(aladdinId);
    expect(clubs.selectedClub.name, '알라딘');

    clubs.importBundleForTest(stale);
    expect(clubs.selectedClub.id, aladdinId,
        reason: '동기화가 선택 모임을 아레나로 바꾸면 안 된다');
    expect(clubs.selectedClub.name, '알라딘');
  });

  test('bootstrap이 모임 목록 순서를 바꿔도 들어간 모임을 유지한다', () async {
    expect(
      await clubs.createClub(
        name: '아레나',
        region: '서울',
        industry: '골프',
        teamCount: 4,
        myRole: '회장',
        description: '아레나',
      ),
      isTrue,
    );
    final arenaId = clubs.selectedClub.id;
    expect(
      await clubs.createClub(
        name: '알라딘',
        region: '서울',
        industry: '골프',
        teamCount: 4,
        myRole: '회장',
        description: '알라딘',
      ),
      isTrue,
    );
    final aladdinId = clubs.selectedClub.id;

    clubs.hydrateFromBootstrap(AppBootstrapSnapshot(
      userId: 'kakao_settings',
      myClubs: [
        Club(
          id: arenaId,
          name: '아레나',
          myRole: '회장',
          memberCount: 1,
          region: '서울',
          industry: '골프',
          teamCount: 4,
          description: '아레나',
          creatorId: 'kakao_settings',
        ),
        Club(
          id: aladdinId,
          name: '알라딘',
          myRole: '회장',
          memberCount: 1,
          region: '서울',
          industry: '골프',
          teamCount: 4,
          description: '알라딘',
          creatorId: 'kakao_settings',
        ),
      ],
      discoverableClubs: const [],
      membersByClubId: const {},
      financeByClubId: const {},
      loadedAt: DateTime(2026, 9, 24),
    ));

    expect(clubs.selectedClub.id, aladdinId,
        reason: '홈 새로고침이 알라딘에서 아레나로 바꿔면 안 된다');
  });

  test('설정에서도 같은 이름으로는 저장하지 않는다', () {
    final src =
        File('lib/screens/clubs/club_settings_screen.dart').readAsStringSync();
    expect(src.contains('같은 이름의 모임이 이미 있습니다'), isTrue);
  });
}
