import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:golf_rounder/services/club_data_codec.dart';
import 'package:golf_rounder/services/club_ops_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 참석 숫자가 스냅샷마다 바뀌던 것.
/// 짧은 명단이 와도 활성 회원은 유지하고, 같은 사람 두 줄은 한 명으로 센다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClubProvider clubs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ClubOpsSync.resetMemberTombstones();
    AppDependencies.instance.init(offlineMock: true);
    clubs = ClubProvider();
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
  });

  ClubDataBundle withMembers(List<Member> members) {
    final stale = clubs.exportBundleForTest();
    return ClubDataBundle(
      selectedClubIndex: stale.selectedClubIndex,
      freshClubIds: stale.freshClubIds,
      myClubs: stale.myClubs,
      allClubs: stale.allClubs,
      joinRequests: stale.joinRequests,
      members: members,
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
  }

  Member person(String id, String name, {String type = '정회원', String role = '정회원'}) {
    return Member(
      id: id,
      name: name,
      gender: '남',
      memberType: type,
      role: role,
    );
  }

  test('짧은 명단과 같은 사람 중복이 와도 참석 인원은 같다', () {
    final clubId = clubs.selectedClub.id;
    final full = [
      ...clubs.exportBundleForTest().members,
      person('m_${clubId}_kim', '김철수'),
      person('m_${clubId}_guest', '이영희', type: '게스트', role: '게스트'),
    ];
    clubs.importBundleForTest(withMembers(full));
    final regular = clubs.regularMembers.length;
    final active = clubs.activeMembers.length;
    expect(regular, greaterThan(1));
    expect(active, regular + 1);

    final short = full.where((m) => m.id != 'm_${clubId}_kim').toList();
    clubs.importBundleForTest(withMembers(short));
    expect(clubs.regularMembers.length, regular,
        reason: '스냅샷에 빠졌다고 정회원을 빼면 안 된다');
    expect(clubs.activeMembers.length, active);

    final duplicated = [
      ...full,
      person('m_${clubId}_kakao_dup', '장창현'),
    ];
    clubs.importBundleForTest(withMembers(duplicated));
    expect(clubs.regularMembers.length, regular,
        reason: '방장과 같은 사람 줄이 생겨도 정회원 수는 그대로다');
    expect(clubs.activeMembers.length, active);
  });

  test('탈퇴한 회원은 짧은 명단에서 빠진다', () {
    final clubId = clubs.selectedClub.id;
    final kim = person('m_${clubId}_kim', '김철수');
    final full = [...clubs.exportBundleForTest().members, kim];
    clubs.importBundleForTest(withMembers(full));
    final before = clubs.regularMembers.length;

    ClubOpsSync.markMemberRemoved(kim.id);
    clubs.importBundleForTest(
      withMembers(full.where((m) => m.id != kim.id).toList()),
    );
    expect(clubs.regularMembers.length, before - 1);
  });
}
