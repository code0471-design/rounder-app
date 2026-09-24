import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 정원 마감→대기, 불참 시 조편성 제외, 대기 전원 앱푸시, leftover 참석 포인트.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClubProvider clubs;
  late String clubId;
  late String creatorId;
  late String leftoverId;
  late String waiterId;
  late String extraA;
  late String extraB;
  late String extraC;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    AppDependencies.instance.init(offlineMock: true);
    clubs = ClubProvider();
    await clubs.switchUser('kakao_waitlist', displayName: '안경현');
    final ok = await clubs.createClub(
      name: '대기포인트모임',
      region: '서울',
      industry: '골프',
      teamCount: 1,
      myRole: '회장,총무',
    );
    expect(ok, isTrue);
    clubId = clubs.selectedClub.id;
    clubs.selectClubById(clubId);
    creatorId = clubs.currentMember!.id;
    leftoverId = 'm_${clubId}_m1';
    waiterId = 'm_${clubId}_kakao_wait';
    extraA = 'm_${clubId}_a';
    extraB = 'm_${clubId}_b';
    extraC = 'm_${clubId}_c';
    clubs.addMember(Member(
      id: leftoverId,
      name: 'Jeongwon Lee',
      gender: '남',
      memberType: '정회원',
      role: '일반',
      joinDate: DateTime(2026, 1, 1),
    ));
    clubs.addMember(Member(
      id: waiterId,
      name: '대기김',
      gender: '남',
      memberType: '정회원',
      role: '일반',
      joinDate: DateTime(2026, 1, 1),
    ));
    clubs.addMember(Member(
      id: extraA,
      name: '회원A',
      gender: '남',
      memberType: '정회원',
      role: '일반',
      joinDate: DateTime(2026, 1, 1),
    ));
    clubs.addMember(Member(
      id: extraB,
      name: '회원B',
      gender: '남',
      memberType: '정회원',
      role: '일반',
      joinDate: DateTime(2026, 1, 1),
    ));
    clubs.addMember(Member(
      id: extraC,
      name: '회원C',
      gender: '남',
      memberType: '정회원',
      role: '일반',
      joinDate: DateTime(2026, 1, 1),
    ));
  });

  RoundSchedule sched(String id, {int teamCount = 1}) => RoundSchedule(
        id: id,
        clubId: clubId,
        title: '만원 라운딩',
        roundDate: DateTime(2026, 6, 1),
        teeTime: '07:00',
        courseName: '테스트CC',
        teamCount: teamCount,
        createdBy: '총무',
      );

  test('정원(팀수×4)이 차면 참석은 거부되고 대기로 등록된다', () {
    clubs.addSchedule(sched('s_full'));
    clubs.adminSetAttendance(
      scheduleId: 's_full',
      memberId: leftoverId,
      memberName: 'Jeongwon Lee',
      response: '참석',
    );
    clubs.adminSetAttendance(
      scheduleId: 's_full',
      memberId: extraA,
      memberName: '회원A',
      response: '참석',
    );
    clubs.adminSetAttendance(
      scheduleId: 's_full',
      memberId: extraB,
      memberName: '회원B',
      response: '참석',
    );
    clubs.adminSetAttendance(
      scheduleId: 's_full',
      memberId: extraC,
      memberName: '회원C',
      response: '참석',
    );
    expect(clubs.isAttendanceFull('s_full'), isTrue);
    expect(
      clubs.respondToSchedule(scheduleId: 's_full', response: '참석'),
      isFalse,
      reason: '정원 찬 일정은 참석 확정 대신 대기로 가야 한다',
    );
    clubs.addToWaitingList(
      scheduleId: 's_full',
      memberId: waiterId,
      memberName: '대기김',
    );
    expect(clubs.waitingListForSchedule('s_full'), isNotEmpty);
    expect(
      clubs.waitingListForSchedule('s_full').first.status,
      WaitingStatus.waiting,
    );
  });

  test('불참하면 조편성에서 빠지고 대기자 전원에게 앱 알림이 간다', () {
    clubs.addSchedule(sched('s_drop'));
    clubs.adminSetAttendance(
      scheduleId: 's_drop',
      memberId: leftoverId,
      memberName: 'Jeongwon Lee',
      response: '참석',
    );
    clubs.assignMember(
      scheduleId: 's_drop',
      groupIndex: 0,
      slotIndex: 0,
      slot: GroupSlot(
        memberId: leftoverId,
        memberName: 'Jeongwon Lee',
        gender: '남',
      ),
    );
    expect(
      clubs.groupAssignment('s_drop')?.groupOfAny({leftoverId}),
      1,
    );
    clubs.addToWaitingList(
      scheduleId: 's_drop',
      memberId: waiterId,
      memberName: '대기김',
    );
    clubs.adminSetAttendance(
      scheduleId: 's_drop',
      memberId: leftoverId,
      memberName: 'Jeongwon Lee',
      response: '불참',
    );
    expect(
      clubs.groupAssignment('s_drop')?.groupOfAny({leftoverId}),
      isNull,
      reason: '불참 회원이 조편성 슬롯에 남아 있으면 안 된다',
    );
    final waiters = clubs.waitingListForSchedule('s_drop');
    expect(waiters.first.status, WaitingStatus.notified);
    expect(
      clubs.scheduleById('s_drop')!.responses.any(
            (r) => r.memberId == waiterId && r.response == '참석',
          ),
      isFalse,
      reason: '결원 시 대기 1번을 자동 참석 시키면 안 된다',
    );
    expect(
      clubs.appNotifications.any((n) =>
          n.title == '참석이 가능해졌습니다' &&
          n.body.contains('참석으로 변경해 주세요') &&
          (n.targetUserId == waiterId || n.targetUserId == 'kakao_wait')),
      isTrue,
      reason: '대기자는 푸시·인박스로 참석 가능만 알린다',
    );
    expect(
      clubs.appNotifications.any((n) => n.title.contains('참석이 확정되었습니다')),
      isFalse,
    );
  });

  test('대기자가 참석으로 바꾸면 명단에서 빠지고 다시 불러와도 없다', () {
    clubs.addSchedule(sched('s_confirm'));
    clubs.adminSetAttendance(
      scheduleId: 's_confirm',
      memberId: leftoverId,
      memberName: 'Jeongwon Lee',
      response: '참석',
    );
    clubs.addToWaitingList(
      scheduleId: 's_confirm',
      memberId: waiterId,
      memberName: '대기김',
    );
    clubs.adminSetAttendance(
      scheduleId: 's_confirm',
      memberId: leftoverId,
      memberName: 'Jeongwon Lee',
      response: '불참',
    );
    expect(clubs.waitingListForSchedule('s_confirm'), isNotEmpty);
    clubs.adminSetAttendance(
      scheduleId: 's_confirm',
      memberId: waiterId,
      memberName: '대기김',
      response: '참석',
    );
    expect(clubs.waitingListForSchedule('s_confirm'), isEmpty,
        reason: '참석 확정 뒤 대기 명단에 남아 있으면 안 된다');
    final stale = clubs.exportBundleForTest();
    expect(
      stale.waitingList.any(
        (w) => w.scheduleId == 's_confirm' && w.memberId == waiterId,
      ),
      isFalse,
      reason: '다시 불러와도 확정된 대기자는 올라오면 안 된다',
    );
    expect(
      stale.schedules
          .firstWhere((s) => s.id == 's_confirm')
          .waitingList
          .any((w) => w.memberId == waiterId),
      isFalse,
      reason: '대기 명단은 일정에 저장되고 확정자는 빠져 있어야 한다',
    );
  });

  test('결원이 나면 대기자 전원에게 알린다', () {
    clubs.addSchedule(sched('s_next'));
    clubs.adminSetAttendance(
      scheduleId: 's_next',
      memberId: leftoverId,
      memberName: 'Jeongwon Lee',
      response: '참석',
    );
    clubs.adminSetAttendance(
      scheduleId: 's_next',
      memberId: extraA,
      memberName: '회원A',
      response: '참석',
    );
    clubs.addToWaitingList(
      scheduleId: 's_next',
      memberId: waiterId,
      memberName: '대기김',
    );
    clubs.addToWaitingList(
      scheduleId: 's_next',
      memberId: extraB,
      memberName: '회원B',
    );
    clubs.adminSetAttendance(
      scheduleId: 's_next',
      memberId: leftoverId,
      memberName: 'Jeongwon Lee',
      response: '불참',
    );
    expect(
      clubs.waitingListForSchedule('s_next').map((w) => w.memberId).toSet(),
      {waiterId, extraB},
    );
    expect(
      clubs.waitingListForSchedule('s_next').every(
        (w) => w.status == WaitingStatus.notified,
      ),
      isTrue,
      reason: '결원 시 대기 1번만 알리면 안 된다',
    );
    expect(
      clubs.appNotifications
          .where((n) =>
              n.title == '참석이 가능해졌습니다' && n.targetId == 's_next')
          .length,
      greaterThanOrEqualTo(2),
    );
  });

  test('먼저 참석한 사람만 확정되고 늦은 사람은 대기에 남는다', () {
    clubs.addSchedule(sched('s_late'));
    clubs.adminSetAttendance(
      scheduleId: 's_late',
      memberId: leftoverId,
      memberName: 'Jeongwon Lee',
      response: '참석',
    );
    clubs.adminSetAttendance(
      scheduleId: 's_late',
      memberId: extraA,
      memberName: '회원A',
      response: '참석',
    );
    clubs.adminSetAttendance(
      scheduleId: 's_late',
      memberId: extraB,
      memberName: '회원B',
      response: '참석',
    );
    clubs.adminSetAttendance(
      scheduleId: 's_late',
      memberId: extraC,
      memberName: '회원C',
      response: '참석',
    );
    clubs.addToWaitingList(
      scheduleId: 's_late',
      memberId: creatorId,
      memberName: '안경현',
    );
    clubs.addToWaitingList(
      scheduleId: 's_late',
      memberId: waiterId,
      memberName: '대기김',
    );
    clubs.adminSetAttendance(
      scheduleId: 's_late',
      memberId: leftoverId,
      memberName: 'Jeongwon Lee',
      response: '불참',
    );
    clubs.adminSetAttendance(
      scheduleId: 's_late',
      memberId: waiterId,
      memberName: '대기김',
      response: '참석',
    );
    expect(
      clubs.scheduleById('s_late')!.responses.any(
            (r) => r.memberId == waiterId && r.response == '참석',
          ),
      isTrue,
    );
    expect(
      clubs.waitingListForSchedule('s_late').any((w) => w.memberId == waiterId),
      isFalse,
    );
    expect(
      clubs.respondToSchedule(scheduleId: 's_late', response: '참석'),
      isFalse,
      reason: '자리가 찼으면 늦은 대기자는 참석하면 안 된다',
    );
    expect(
      clubs.waitingListForSchedule('s_late').any((w) => w.memberId == creatorId),
      isTrue,
      reason: '늦은 사람은 다시 등록하지 않고 대기에 남아야 한다',
    );
    expect(
      clubs.scheduleById('s_late')!.responses.any(
            (r) => r.memberId == creatorId && r.response == '참석',
          ),
      isFalse,
    );
  });

  test('대기자가 불참하면 명단에서 뺀다', () {
    clubs.addSchedule(sched('s_wout'));
    clubs.addToWaitingList(
      scheduleId: 's_wout',
      memberId: creatorId,
      memberName: '안경현',
    );
    expect(clubs.waitingListForSchedule('s_wout'), isNotEmpty);
    expect(
      clubs.respondToSchedule(scheduleId: 's_wout', response: '불참'),
      isTrue,
    );
    expect(clubs.waitingListForSchedule('s_wout'), isEmpty);
  });

  test('이정원이 지난 일정에 참석했는데 포인트가 0이면 안 된다', () {
    final before = clubs.getMembershipPoints(leftoverId, year: 2026);
    final ok = clubs.importPastSchedule(
      title: '4월 라운딩',
      roundDate: DateTime(2026, 4, 12),
      attendeeIds: [leftoverId],
    );
    expect(ok, isTrue);
    expect(
      clubs.getMembershipPoints(leftoverId, year: 2026),
      greaterThanOrEqualTo(before + 10),
      reason: '지난 일정 참석은 leftover 키로 +10 적립돼야 한다',
    );
    expect(
      clubs.getMembershipPoints(creatorId, year: 2026),
      0,
      reason: '이정원 참석 포인트가 생성자 랭킹으로 넘어가면 안 된다',
    );
  });

  test('랭킹·시상 연도는 올해만 나오지 않는다', () {
    final years = clubs.rankingYearsAvailable();
    expect(years.contains(DateTime.now().year), isTrue);
    expect(years.contains(DateTime.now().year - 1), isTrue);
    expect(clubs.awardYearsAvailable(), years);
    clubs.addMembershipPoint(
      memberId: leftoverId,
      type: MembershipPointType.roundAttendance,
      points: 10,
      desc: '작년 참석|s_2025',
      date: DateTime(2025, 5, 1),
    );
    expect(clubs.getMembershipPoints(leftoverId, year: 2025), 10);
    expect(
      clubs.memberPointsRankingForYear(2025).any((e) => e.key == leftoverId),
      isTrue,
    );
  });

  test('회원 화면 랭킹 자세히보기에 연도 선택이 있다', () {
    final src =
        File('lib/screens/members/members_screen.dart').readAsStringSync();
    expect(src.contains('rankingYearsAvailable()'), isTrue);
    expect(src.contains('memberPointsRankingForYear(year)'), isTrue);
    expect(src.contains('(올해 기준)'), isFalse,
        reason: '랭킹도 시상처럼 연도 드롭다운이어야 한다');
  });
}
