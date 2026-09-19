import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 이름은 라벨, 사람은 회원 ID.
/// 개명해도 명단에서 빠지거나 회비·시상·랭킹이 끊기면 안 된다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClubProvider clubs;
  late String clubId;
  late String creatorId;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    AppDependencies.instance.init(offlineMock: true);
    clubs = ClubProvider();
    await clubs.switchUser('kakao_ahn', displayName: '안경헌');
    final ok = await clubs.createClub(
      name: '아레나',
      region: '서울',
      industry: '골프',
      teamCount: 4,
      myRole: '회장,총무',
    );
    expect(ok, isTrue);
    clubId = clubs.selectedClub.id;
    clubs.selectClubById(clubId);
    creatorId = clubs.currentMember!.id;

    clubs.addDuesSetting(DuesSetting(
      id: 'ds_year',
      type: DuesType.annual,
      amount: 120000,
      title: '연회비',
      createdAt: DateTime(2026, 1, 1),
      clubId: clubId,
    ));
    clubs.recordPayment(
      memberId: creatorId,
      memberName: '안경헌',
      duesSettingId: 'ds_year',
      amount: 120000,
      year: 2026,
    );

    final when = DateTime(2026, 3, 1);
    clubs.addSchedule(RoundSchedule(
      id: 's_name',
      clubId: clubId,
      title: '3월',
      roundDate: when,
      teeTime: '07:00',
      courseName: 'A',
      teamCount: 4,
      status: ScheduleStatus.upcoming,
      createdBy: '안경헌',
    ));
    clubs.saveAwardsForSchedule('s_name', [
      AwardRecord(
        id: 'ar_name',
        scheduleId: 's_name',
        scheduleName: '3월',
        awardName: '메달리스트',
        awardIcon: '🥇',
        winnerIds: [creatorId],
        winnerNames: const ['안경헌'],
        recordedAt: when,
      ),
    ]);
    clubs.addMembershipPoint(
      memberId: creatorId,
      type: MembershipPointType.roundAttendance,
      points: 10,
      desc: '3월 라운딩 참석|s_name',
    );
  });

  test('개명해도 회원 ID는 그대로이고 둘째 줄이 생기지 않는다', () {
    final before = clubs.activeMembers.where((m) => m.id == creatorId).length;
    expect(before, 1);
    clubs.updateMember(clubs.currentMember!.copyWith(name: '김안경'));
    expect(clubs.currentMember!.id, creatorId);
    expect(clubs.currentMember!.name, '김안경');
    expect(clubs.activeMembers.where((m) => m.id == creatorId).length, 1);
    expect(clubs.activeMembers.where((m) => m.name == '안경헌').length, 0);
  });

  test('회비는 memberId 로 남고 표시 이름만 바뀐다', () {
    expect(clubs.hasPaid(creatorId, 'ds_year', year: 2026), isTrue);
    final mine = clubs.duesPayments.where((p) => p.memberId == creatorId);
    expect(mine, isNotEmpty);
    expect(mine.every((p) => p.memberName == '김안경'), isTrue);
    expect(clubs.duesPayments.where((p) => p.memberName == '안경헌'), isEmpty);
  });

  test('시상·랭킹은 winnerId / memberId 로 남는다', () {
    expect(clubs.getMemberAwardCount(creatorId, year: 2026), 1);
    expect(
      clubs.regularAwardWinnerNames(
        clubs.allAwardRecords.where((r) => r.id == 'ar_name').first,
      ),
      ['김안경'],
    );
    final ranking = clubs.memberPointsRankingForYear(2026);
    expect(ranking.any((e) => e.key == creatorId), isTrue);
    expect(
      ranking.where((e) => e.key == creatorId).first.value,
      greaterThanOrEqualTo(10),
    );
  });
}
