import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/domain/services/attendance_stats.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/models/user_model.dart';

String _read(String relative) => File(relative).readAsStringSync();

AttendanceResponse _res(String memberId, String response) => AttendanceResponse(
      memberId: memberId,
      memberName: memberId,
      response: response,
      respondedAt: DateTime(2024, 1, 1),
    );

RoundSchedule _schedule({
  required String id,
  required DateTime date,
  ScheduleStatus status = ScheduleStatus.upcoming,
  List<AttendanceResponse> responses = const [],
  String clubId = 'c1',
}) {
  return RoundSchedule(
    id: id,
    clubId: clubId,
    title: '테스트 라운딩',
    roundDate: date,
    teeTime: '07:00',
    courseName: '테스트CC',
    teamCount: 2,
    status: status,
    createdBy: '총무',
    responses: responses,
  );
}

void main() {
  final past = DateTime.now().subtract(const Duration(days: 30));
  final future = DateTime.now().add(const Duration(days: 30));

  group('참석 라운딩 카운팅', () {
    test('지난 라운딩에 참석한 것만 센다', () {
      final stats = AttendanceStats.forMember(
        schedules: [
          _schedule(id: 's1', date: past, responses: [_res('m1', '참석')]),
          _schedule(id: 's2', date: past, responses: [_res('m1', '참석')]),
          _schedule(id: 's3', date: past, responses: [_res('m1', '불참')]),
        ],
        clubId: 'c1',
        memberId: 'm1',
      );
      expect(stats.attended, 2);
      expect(stats.finished, 3);
      expect(stats.ratePercent, 67);
    });

    test('예정된 일정에 참석 응답만 해둔 것은 세지 않는다', () {
      // 이게 기존 버그였다. D-Day 전에 '참석'만 눌러도 라운딩 이력으로 잡혔다.
      final stats = AttendanceStats.forMember(
        schedules: [
          _schedule(id: 's1', date: past, responses: [_res('m1', '참석')]),
          _schedule(id: 's2', date: future, responses: [_res('m1', '참석')]),
          _schedule(id: 's3', date: future, responses: [_res('m1', '참석')]),
        ],
        clubId: 'c1',
        memberId: 'm1',
      );
      expect(stats.attended, 1, reason: '미래 일정은 다녀온 게 아니다');
      expect(stats.finished, 1);
    });

    test('취소된 일정은 참석 응답이 남아 있어도 세지 않는다', () {
      final stats = AttendanceStats.forMember(
        schedules: [
          _schedule(id: 's1', date: past, responses: [_res('m1', '참석')]),
          _schedule(
            id: 's2',
            date: past,
            status: ScheduleStatus.cancelled,
            responses: [_res('m1', '참석')],
          ),
        ],
        clubId: 'c1',
        memberId: 'm1',
      );
      expect(stats.attended, 1);
      expect(stats.finished, 1, reason: '취소는 분모에서도 빠져야 참석률이 안 깎인다');
    });

    test('다른 모임 일정은 섞이지 않는다', () {
      final stats = AttendanceStats.forMember(
        schedules: [
          _schedule(id: 's1', date: past, responses: [_res('m1', '참석')]),
          _schedule(
            id: 's2',
            date: past,
            clubId: 'c2',
            responses: [_res('m1', '참석')],
          ),
        ],
        clubId: 'c1',
        memberId: 'm1',
      );
      expect(stats.attended, 1);
      expect(stats.finished, 1);
    });

    test('수동 완료 처리된 일정은 날짜가 미래여도 센다', () {
      final stats = AttendanceStats.forMember(
        schedules: [
          _schedule(
            id: 's1',
            date: future,
            status: ScheduleStatus.done,
            responses: [_res('m1', '참석')],
          ),
        ],
        clubId: 'c1',
        memberId: 'm1',
      );
      expect(stats.attended, 1);
    });

    test('지난 라운딩이 없으면 참석률은 null', () {
      final stats = AttendanceStats.forMember(
        schedules: [
          _schedule(id: 's1', date: future, responses: [_res('m1', '참석')]),
        ],
        clubId: 'c1',
        memberId: 'm1',
      );
      expect(stats.finished, 0);
      expect(stats.ratePercent, isNull);
    });
  });

  group('AppUser 생년월일·핸디캡', () {
    test('생년월일과 음력 여부를 담는다', () {
      final user = AppUser(
        id: 'u1',
        name: '홍길동',
        phone: '010-1234-5678',
        birthDate: DateTime(1985, 3, 21),
        birthIsLunar: true,
        handicap: 18,
      );
      expect(user.birthDate, DateTime(1985, 3, 21));
      expect(user.birthIsLunar, isTrue);
      expect(user.birthDateText, '1985.03.21 (음력)');
      expect(user.needsGolfProfile, isFalse);
    });

    test('기본은 양력이고 미입력이면 가입 단계가 필요하다', () {
      final user = AppUser(id: 'u1', name: '홍길동', phone: '010-1234-5678');
      expect(user.birthIsLunar, isFalse);
      expect(user.birthDateText, '미입력');
      expect(user.needsGolfProfile, isTrue);
    });

    test('copyWith 가 생년월일·음력·핸디캡을 유지한다', () {
      final user = AppUser(
        id: 'u1',
        name: '홍길동',
        phone: '010-1234-5678',
        birthDate: DateTime(1990, 1, 2),
        birthIsLunar: true,
        handicap: 12.5,
      );
      final renamed = user.copyWith(name: '김철수');
      expect(renamed.birthDate, DateTime(1990, 1, 2));
      expect(renamed.birthIsLunar, isTrue);
      expect(renamed.handicap, 12.5);
    });
  });

  group('생년월일·핸디캡은 Firestore 에 저장된다', () {
    // 로컬에만 남으면 기기 교체·재설치 때 사라진다.
    final auth = _read('lib/providers/auth_provider.dart');

    test('users 문서에 birth_date / handicap 을 쓴다', () {
      expect(auth.contains("data['birth_date']"), isTrue);
      expect(auth.contains("data['birth_is_lunar']"), isTrue);
      expect(auth.contains("data['handicap']"), isTrue);
    });

    test('빈 값으로 원격을 덮지 않는다', () {
      expect(auth.contains('if (user.birthDate != null)'), isTrue);
      expect(auth.contains('if (user.handicap != null)'), isTrue);
    });

    test('로그인 시 원격 값을 다시 읽어 온다', () {
      expect(auth.contains("data['birth_date']"), isTrue);
      expect(auth.contains('remoteBirthDate'), isTrue);
      expect(auth.contains('remoteHandicap'), isTrue);
      expect(
        auth.contains('birthDate: remoteBirthDate ?? memory?.birthDate'),
        isTrue,
      );
    });

    test('updateGolfProfile 이 저장까지 한다', () {
      expect(auth.contains('Future<AppUser?> updateGolfProfile('), isTrue);
      expect(
        RegExp(r'updateGolfProfile\([\s\S]{0,1200}_persistPlatformUser')
            .hasMatch(auth),
        isTrue,
        reason: '메모리만 갱신하고 끝나면 테스터끼리 안 보인다',
      );
    });

    test('모임 명단에도 전파한다', () {
      final club = _read('lib/providers/club_provider.dart');
      expect(club.contains('void syncAuthGolfProfile('), isTrue);
      expect(
        RegExp(r'syncAuthGolfProfile\([\s\S]{0,1600}_persistImmediately')
            .hasMatch(club),
        isTrue,
      );
    });
  });

  group('가입 단계 — 인증 후 생년월일·핸디캡', () {
    test('골프 프로필 화면이 라우트에 등록돼 있다', () {
      final app = _read('lib/app/rounder_app.dart');
      expect(app.contains("'/golf-profile'"), isTrue);
    });

    test('휴대폰 인증 완료 후 골프 프로필로 보낸다', () {
      final phone = _read('lib/screens/auth/phone_required_screen.dart');
      expect(phone.contains("'/golf-profile'"), isTrue);
      expect(phone.contains('needsGolfProfile'), isTrue);
    });

    test('초대 가입(OTP) 도 같은 단계를 지난다', () {
      final verify = _read('lib/screens/auth/verify_screen.dart');
      expect(verify.contains("'/golf-profile'"), isTrue);
      expect(verify.contains('needsGolfProfile'), isTrue);
    });

    test('양력·음력을 모두 고를 수 있다', () {
      final screen = _read('lib/screens/auth/golf_profile_screen.dart');
      expect(screen.contains("'양력'"), isTrue);
      expect(screen.contains("'음력'"), isTrue);
      expect(screen.contains('syncAuthGolfProfile'), isTrue);
    });

    test('2월 30일 같은 날짜가 남지 않는다', () {
      final screen = _read('lib/screens/auth/golf_profile_screen.dart');
      expect(screen.contains('_clampDay'), isTrue);
      expect(screen.contains('_daysInSelectedMonth'), isTrue);
    });
  });

  group('회원 목록 헤더', () {
    final members = _read('lib/screens/members/members_screen.dart');

    test('탭 라벨이 잘리지 않게 축소를 허용한다', () {
      expect(members.contains('_segmentTab'), isTrue);
      expect(members.contains('BoxFit.scaleDown'), isTrue);
      expect(
        members.contains('height: 40,\n                        decoration'),
        isFalse,
        reason: 'TabBar 기본 높이보다 낮으면 글자 아래가 잘린다',
      );
    });

    test('초대 아이콘은 홈 탭 버튼으로 통일 — 헤더에서 제거', () {
      expect(members.contains('InviteSendScreen'), isFalse);
      expect(members.contains('GuestInviteFormScreen'), isFalse);
      expect(members.contains('Icons.person_add_alt_1_outlined'), isFalse);
      expect(members.contains('Icons.link'), isFalse);
    });

    test('초대는 홈 탭에 그대로 남아 있다', () {
      final home = _read('lib/screens/club_room/club_room_screen.dart');
      expect(home.contains('InviteSendScreen'), isTrue);
      expect(home.contains('GuestInviteFormScreen'), isTrue);
      expect(home.contains("'정회원 초대하기'"), isTrue);
      expect(home.contains("'게스트 초대하기'"), isTrue);
    });

    test('명단 내보내기와 가입 신청은 유일한 진입점이라 남긴다', () {
      expect(members.contains('Icons.file_download_outlined'), isTrue);
      expect(members.contains('_showJoinRequests'), isTrue);
    });
  });

  group('회원 상세 — 활동 기록', () {
    final detail = _read('lib/screens/members/member_detail_screen.dart');

    test('직접 세지 않고 AttendanceStats 를 쓴다', () {
      expect(detail.contains('AttendanceStats.forMember'), isTrue);
      expect(
        detail.contains(".where((s) => s.responses.any(\n"),
        isFalse,
        reason: '인라인 카운팅으로 돌아가면 취소·미래 필터가 또 빠진다',
      );
    });

    test('핸디캡을 두 카드에서 중복 표시하지 않는다', () {
      final handicapLabels =
          RegExp(r"label: '핸디캡'").allMatches(detail).length;
      expect(handicapLabels, 1);
    });
  });

  group('마이페이지', () {
    final mypage = _read('lib/screens/ad/ad_screen.dart');

    test("'서비스 소개 · 사업자 정보' 항목을 제거했다", () {
      expect(mypage.contains('서비스 소개 · 사업자 정보'), isFalse);
      expect(mypage.contains('ServiceAboutScreen'), isFalse);
    });

    test('사업자 정보는 로그인 화면에서 계속 볼 수 있다', () {
      // 전자상거래 표기 경로가 완전히 사라지면 안 된다.
      final login = _read('lib/screens/auth/login_screen.dart');
      expect(login.contains('ServiceAboutScreen'), isTrue);
    });

    test('프로필 카드에 핸디캡·생년월일을 보여 준다', () {
      expect(mypage.contains('_ProfileStat'), isTrue);
      expect(mypage.contains("label: '핸디캡'"), isTrue);
      expect(mypage.contains("'생년월일 (음력)'"), isTrue);
    });

    test('편집에서 양력·음력을 바꿀 수 있고 계정에 저장한다', () {
      expect(mypage.contains('birthIsLunar'), isTrue);
      expect(mypage.contains('auth.updateGolfProfile('), isTrue);
    });

    test('편집 시작값은 계정 값을 먼저 쓴다', () {
      expect(mypage.contains('account?.birthDate ?? member.birthDate'), isTrue);
      expect(mypage.contains('account?.handicap ?? member.handicap'), isTrue);
    });
  });
}
