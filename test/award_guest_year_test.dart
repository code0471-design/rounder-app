import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClubProvider clubs;
  late String regularId;
  late String guestId;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    AppDependencies.instance.init(offlineMock: true);
    clubs = ClubProvider();
    await clubs.switchUser('kakao_ahn', displayName: '안경현');
    final ok = await clubs.createClub(
      name: '아레나',
      region: '서울',
      industry: '골프',
      teamCount: 4,
      myRole: '회장,총무',
    );
    expect(ok, isTrue);
    regularId = clubs.currentMember!.id;
    guestId = 'm_${clubs.selectedClub.id}_guest';
    clubs.addMember(Member(
      id: guestId,
      name: '게스트김',
      gender: '남',
      memberType: '게스트',
      role: '게스트',
      joinDate: DateTime(2026, 1, 1),
    ));
    clubs.saveAwardRecord(AwardRecord(
      id: 'ar_guest',
      scheduleId: 's_guest',
      scheduleName: '테스트라운드',
      awardName: '롱기스트',
      awardIcon: '🏌️',
      winnerIds: [guestId],
      winnerNames: ['게스트김'],
      recordedAt: DateTime(2026, 9, 1),
    ));
    clubs.saveAwardRecord(AwardRecord(
      id: 'ar_regular',
      scheduleId: 's_reg',
      scheduleName: '테스트라운드',
      awardName: '메달리스트',
      awardIcon: '🥇',
      winnerIds: [regularId],
      winnerNames: ['안경현'],
      recordedAt: DateTime(2026, 9, 1),
    ));
  });

  test('게스트 시상은 시상 목록 횟수에 안 잡힌다', () {
    final ranking = clubs.regularAwardRankingForYear(2026);
    expect(ranking.any((e) => e.key == guestId), isFalse);
    expect(ranking.any((e) => e.key == regularId), isTrue);
  });

  test('게스트만 탄 시상은 월별 이름에도 안 나온다', () {
    final guestAward = clubs.allAwardRecords.firstWhere((r) => r.id == 'ar_guest');
    expect(clubs.regularAwardWinnerNames(guestAward), isEmpty);
    final regularAward =
        clubs.allAwardRecords.firstWhere((r) => r.id == 'ar_regular');
    expect(clubs.regularAwardWinnerNames(regularAward), isNotEmpty);
    final years = clubs.awardYearsAvailable();
    expect(years.contains(DateTime.now().year), isTrue);
    expect(years.contains(DateTime.now().year - 1), isTrue,
        reason: '시상 연도가 올해만 나오면 작년 기록을 고를 수 없다');
  });
}
