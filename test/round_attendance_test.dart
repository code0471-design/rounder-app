import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/domain/services/round_attendance.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'dart:io';

Member _m(String id, String type) => Member(
      id: id,
      name: id,
      gender: '남',
      memberType: type,
      role: type == '게스트' ? '게스트' : '정회원',
    );

AttendanceResponse _r(String id, String response) => AttendanceResponse(
      memberId: id,
      memberName: id,
      response: response,
      respondedAt: DateTime(2026, 10, 1),
    );

void main() {
  test('정회원과 게스트를 같은 명단으로 센다', () {
    final tally = RoundAttendance.of(
      roster: [
        _m('a', '정회원'),
        _m('b', '정회원'),
        _m('c', '정회원'),
        _m('g', '게스트'),
      ],
      responses: const [],
    );
    expect(tally.attend, 0);
    expect(tally.decline, 0);
    expect(tally.noResponse, 4);
    expect(tally.total, 4);
    expect(tally.regularCount, 3);
    expect(tally.guestCount, 1);
    expect(tally.headLabel, '정회원 3명 · 게스트 1명');
  });

  test('같은 사람 응답이 두 줄이어도 한 명이다', () {
    final tally = RoundAttendance.of(
      roster: [
        _m('a', '정회원'),
        _m('g', '게스트'),
      ],
      responses: [
        _r('g', '참석'),
        _r('g', '참석'),
        _r('a', '불참'),
      ],
    );
    expect(tally.attend, 1);
    expect(tally.guestAttend, 1);
    expect(tally.decline, 1);
    expect(tally.noResponse, 0);
    expect(tally.total, 2);
  });

  test('홈과 일정 화면이 이 집계만 쓴다', () {
    final home = File('lib/screens/club_room/club_room_screen.dart')
        .readAsStringSync();
    final schedule =
        File('lib/screens/schedule/schedule_screen.dart').readAsStringSync();
    expect(home.contains('RoundAttendance.of('), isTrue);
    expect(schedule.contains('RoundAttendance.of('), isTrue);
    expect(schedule.contains('regular - respondedRegular'), isFalse);
    expect(
      schedule.contains("provider.regularMembers\n            .where"),
      isFalse,
    );
  });
}
