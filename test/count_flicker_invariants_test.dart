import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:golf_rounder/services/club_data_codec.dart';
import 'package:golf_rounder/services/club_ops_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('회원수·참석 숫자는 중간 동기화에서 다시 그리지 않는다', () {
    final provider = File('lib/providers/club_provider.dart').readAsStringSync();
    expect(provider.contains('bool _suppressRosterNotify'), isTrue);
    expect(provider.contains('_lastHeadcount'), isTrue);
    expect(provider.contains('attendanceTallyFor('), isTrue);
    expect(provider.contains('await _hydrateRosterFromServer(clubId)'), isTrue);
    expect(
      provider.contains('unawaited(_hydrateRosterFromServer(clubId))'),
      isFalse,
      reason: 'watch가 명단 받기 전에 숫자를 그리면 잠깐 틀린 값이 나온다',
    );
  });

  test('홈·일정은 모임 id로 참석을 센다', () {
    final home = File('lib/screens/club_room/club_room_screen.dart')
        .readAsStringSync();
    expect(home.contains('nextUpcomingScheduleOf(clubId)'), isTrue);
    expect(home.contains('attendanceTallyFor('), isTrue);
    expect(home.contains('prov.nextUpcomingSchedule;'), isFalse);
  });

  test('명단이 잠깐 비어도 방금 센 회원수를 유지한다', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    ClubOpsSync.resetMemberTombstones();
    AppDependencies.instance.init(offlineMock: true);
    final clubs = ClubProvider();
    await clubs.switchUser(
      'kakao_tester',
      displayName: '장창현',
      phone: '010-1111-2222',
    );
    final ok = await clubs.createClub(
      name: '볼케이노',
      region: '인천',
      industry: '골프',
      teamCount: 4,
      myRole: '총무',
    );
    expect(ok, isTrue);
    final clubId = clubs.selectedClub.id;
    final shown = clubs.activeHeadcount(clubId);
    expect(shown, greaterThan(0));

    final stale = clubs.exportBundleForTest();
    clubs.importBundleForTest(ClubDataBundle(
      selectedClubIndex: stale.selectedClubIndex,
      freshClubIds: stale.freshClubIds,
      myClubs: stale.myClubs,
      allClubs: stale.allClubs,
      joinRequests: stale.joinRequests,
      members: const [],
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
    ));
    expect(clubs.activeHeadcount(clubId), shown,
        reason: '짧은 스냅샷이 와도 카드 인원이 서버 숫자와 번갈아 바뀌면 안 된다');
  });
}
