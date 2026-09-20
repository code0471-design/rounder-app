import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/auth_provider.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClubProvider clubs;
  late String clubId;
  late String myId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppDependencies.instance.init(offlineMock: true);
    final auth = AuthProvider();
    await auth.loginAsync('010-1234-5678');
    clubs = ClubProvider();
    await clubs.switchUser(auth.currentUser!.id,
        displayName: auth.currentUser!.name);
    final ok = await clubs.createClub(
      name: '일정변경 테스트',
      region: '서울',
      industry: '골프',
      teamCount: 4,
      myRole: '회장,총무',
    );
    expect(ok, isTrue);
    clubId = clubs.selectedClub.id;
    clubs.selectClubById(clubId);
    myId = clubs.currentMember!.id;
  });

  RoundSchedule addAttending({String id = 's_chg'}) {
    clubs.addSchedule(RoundSchedule(
      id: id,
      clubId: clubId,
      title: '월례회',
      roundDate: DateTime(2026, 10, 10),
      teeTime: '07:00',
      courseName: '베르힐CC',
      courseAddress: '인천',
      teamCount: 4,
      createdBy: '총무',
    ));
    expect(clubs.respondToSchedule(scheduleId: id, response: '참석'), isTrue);
    return clubs.scheduleById(id)!;
  }

  test('주소·시간이 바뀌어도 참석은 유지된다', () {
    final prev = addAttending();
    final next = prev.copyWith(
      teeTime: '08:30',
      courseAddress: '서울 강남',
    );
    expect(ClubProvider.isMaterialScheduleChange(prev, next), isTrue);
    expect(clubs.updateSchedule(next), isTrue);
    final kept = clubs.scheduleById(prev.id)!;
    expect(kept.responses.single.memberId, myId);
    expect(kept.responses.single.response, '참석');
  });

  test('일정 변경 후 참석→불참이면 포인트가 회수된다', () {
    addAttending();
    final before = clubs.getMembershipPoints(myId);
    expect(before, 10);
    expect(
      clubs.respondToSchedule(scheduleId: 's_chg', response: '불참'),
      isTrue,
    );
    expect(clubs.getMembershipPoints(myId), 0);
  });

  test('일정 취소 때도 참석 포인트가 회수된다', () {
    addAttending(id: 's_can');
    expect(clubs.getMembershipPoints(myId), 10);
    clubs.cancelSchedule('s_can');
    expect(clubs.getMembershipPoints(myId), 0);
    expect(clubs.scheduleById('s_can')!.status, ScheduleStatus.cancelled);
  });
}
