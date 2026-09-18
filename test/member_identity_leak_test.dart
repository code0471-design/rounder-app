import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 실계정이 currentUserId=m1 을 공유해서 생기던 누수.
/// 댓글 홍길동, 다른 회원과 같은 랭킹 점수, 시상 횟수 누락.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClubProvider clubs;
  late String clubId;
  late String creatorId;

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
    clubId = clubs.selectedClub.id;
    clubs.selectClubById(clubId);
    creatorId = clubs.currentMember!.id;
    clubs.addMember(Member(
      id: 'm_${clubId}_m1',
      name: 'Jeongwon Lee',
      gender: '남',
      memberType: '정회원',
      role: '일반',
      joinDate: DateTime(2026, 1, 1),
    ));
    clubs.addMember(Member(
      id: 'm_${clubId}_kakao_other',
      name: '김철수',
      gender: '남',
      memberType: '정회원',
      role: '일반',
      joinDate: DateTime(2026, 1, 1),
    ));
    clubs.ensureCreatorMembers();
  });

  test('실계정 currentUserId 는 카카오 id 이고 m1 이 아니다', () {
    expect(clubs.currentUserId, 'kakao_ahn');
    expect(clubs.currentUserId, isNot('m1'));
  });

  test('실계정 currentMember 가 이정원 m_{club}_m1 행이 되면 안 된다', () {
    expect(clubs.currentMember!.id, creatorId);
    expect(clubs.currentMember!.id, isNot('m_${clubId}_m1'));
    expect(clubs.currentMember!.name, '안경현');
  });

  test('이정원과 안경헌은 명단에 둘 다 남는다', () {
    expect(
      clubs.activeMembers.any((m) => m.id == 'm_${clubId}_m1'),
      isTrue,
    );
    expect(
      clubs.activeMembers.any((m) => m.name == 'Jeongwon Lee'),
      isTrue,
    );
    expect(clubs.currentUserName, '안경현');
    expect(clubs.canonicalMemberId('m_${clubId}_m1'), isNot(creatorId));
  });

  test('댓글 시드 이름 홍길동은 생성자 이름으로 보여 준다', () {
    expect(
      clubs.displayAuthorName(
        authorId: 'm1',
        authorName: '홍길동',
        clubId: clubId,
      ),
      '안경현',
    );
    expect(
      clubs.displayAuthorName(
        authorId: creatorId,
        authorName: '홍길동',
        clubId: clubId,
      ),
      '안경현',
    );
  });

  test('다른 회원은 총무 포인트를 같이 받지 않는다', () {
    clubs.addAnnouncement(title: '공지', content: '내용');
    final annId = clubs.announcements.first.id;
    expect(clubs.addAnnouncementComment(announcementId: annId, text: '네'), isTrue);

    final mine = clubs.getMembershipPoints(creatorId);
    expect(mine, greaterThan(0));
    expect(
      clubs.getMembershipPoints('m_${clubId}_kakao_other'),
      0,
      reason: '다른 회원에게 총무 점수가 복사되면 안 된다',
    );

    final ranking = clubs.memberPointsRanking;
    expect(ranking.any((e) => e.key == 'm_${clubId}_m1'), isTrue);
    final jeongwon =
        ranking.where((e) => e.key == 'm_${clubId}_m1').firstOrNull;
    expect(jeongwon!.value, 0);
    final other =
        ranking.where((e) => e.key == 'm_${clubId}_kakao_other').firstOrNull;
    expect(other, isNotNull);
    expect(other!.value, 0);
  });

  test('시상 winnerId 가 m1 이어도 생성자 횟수에 포함된다', () {
    final when = DateTime(2026, 9, 2);
    clubs.addSchedule(RoundSchedule(
      id: 's_sep',
      clubId: clubId,
      title: '9월',
      roundDate: when,
      teeTime: '07:00',
      courseName: 'A',
      teamCount: 4,
      status: ScheduleStatus.upcoming,
      createdBy: '안경현',
    ));
    clubs.saveAwardsForSchedule('s_sep', [
      AwardRecord(
        id: 'ar1',
        scheduleId: 's_sep',
        scheduleName: '9월',
        awardName: '메달리스트',
        awardIcon: '🥇',
        winnerIds: [creatorId],
        winnerNames: const ['안경현'],
        recordedAt: when,
      ),
      AwardRecord(
        id: 'ar2',
        scheduleId: 's_sep',
        scheduleName: '9월',
        awardName: '메달리스트',
        awardIcon: '🥇',
        winnerIds: const ['m1'],
        winnerNames: const ['안경현'],
        recordedAt: when,
      ),
      AwardRecord(
        id: 'ar3',
        scheduleId: 's_sep',
        scheduleName: '9월',
        awardName: '니어리스트',
        awardIcon: '🎯',
        winnerIds: [creatorId],
        winnerNames: const ['안경현'],
        recordedAt: when,
      ),
    ]);

    final ranking = clubs.regularAwardRankingForYear(2026);
    expect(ranking, isNotEmpty);
    expect(ranking.first.key, creatorId);
    expect(ranking.first.value, 3, reason: '월별 3건이 위에 2회로 줄면 안 된다');
    expect(clubs.getMemberAwardCount(creatorId, year: 2026), 3);
  });

  test('이정원 leftover 행 포인트는 생성자와 섞이지 않는다', () {
    final leftoverId = 'm_${clubId}_m1';
    final creatorBefore = clubs.getMembershipPoints(creatorId);
    clubs.addMembershipPoint(
      memberId: leftoverId,
      type: MembershipPointType.roundAttendance,
      points: 10,
      desc: '3월 라운딩 참석|s_past',
    );
    expect(clubs.getMembershipPoints(leftoverId), greaterThanOrEqualTo(10));
    expect(
      clubs.getMembershipPoints(creatorId),
      creatorBefore,
      reason: '이정원 참석 포인트가 안경헌 랭킹으로 넘어가면 안 된다',
    );
  });

  test('이정원 행에 복사된 생성자 사진·생일은 지운다', () {
    final photo = 'https://example.com/ahn.jpg';
    final birth = DateTime(1971, 3, 1);
    clubs.syncAuthGolfProfile(photoUrl: photo, birthDate: birth);
    final leftoverId = 'm_${clubId}_m1';
    final leftover =
        clubs.activeMembers.where((m) => m.id == leftoverId).first;
    clubs.updateMember(Member(
      id: leftover.id,
      name: leftover.name,
      gender: leftover.gender,
      birthDate: birth,
      photoUrl: photo,
      memberType: leftover.memberType,
      role: leftover.role,
      joinDate: leftover.joinDate,
    ));
    expect(clubs.ensureCreatorMembers(), isTrue);
    final repaired =
        clubs.activeMembers.where((m) => m.id == leftoverId).first;
    expect(repaired.photoUrl, isNull);
    expect(repaired.birthDate, isNull);
    expect(repaired.name, 'Jeongwon Lee');
    final creator = clubs.activeMembers.where((m) => m.id == creatorId).first;
    expect(creator.photoUrl, photo);
  });

  test('골프 프로필 동기화가 이정원 m1 행을 다시 덮지 않는다', () {
    clubs.syncAuthGolfProfile(
      photoUrl: 'https://example.com/ahn2.jpg',
      birthDate: DateTime(1971, 3, 1),
    );
    final leftover =
        clubs.activeMembers.where((m) => m.id == 'm_${clubId}_m1').first;
    expect(leftover.photoUrl, isNull);
    expect(leftover.birthDate, isNull);
  });
}
