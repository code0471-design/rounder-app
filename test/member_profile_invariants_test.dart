import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/domain/services/attendance_stats.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/models/user_model.dart';
import 'package:golf_rounder/utils/avatar_image.dart';

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

    test('참석률 경계값 — 0% / 100% / 반올림', () {
      AttendanceStats rate(int attend, int skip) => AttendanceStats.forMember(
            schedules: [
              for (var i = 0; i < attend; i++)
                _schedule(
                    id: 'a$i', date: past, responses: [_res('m1', '참석')]),
              for (var i = 0; i < skip; i++)
                _schedule(
                    id: 'b$i', date: past, responses: [_res('m1', '불참')]),
            ],
            clubId: 'c1',
            memberId: 'm1',
          );

      expect(rate(0, 3).ratePercent, 0);
      expect(rate(3, 0).ratePercent, 100);
      expect(rate(1, 2).ratePercent, 33); // 33.33 → 33
      expect(rate(2, 1).ratePercent, 67); // 66.67 → 67
      expect(rate(1, 1).ratePercent, 50);
      expect(rate(1, 7).ratePercent, 13); // 12.5 → 13 (round half up)
    });

    test('응답을 안 한 지난 라운딩도 분모에 들어간다', () {
      // '지난 일정 기준' 이므로 무응답도 안 간 것으로 본다.
      final stats = AttendanceStats.forMember(
        schedules: [
          _schedule(id: 's1', date: past, responses: [_res('m1', '참석')]),
          _schedule(id: 's2', date: past, responses: [_res('m2', '참석')]),
        ],
        clubId: 'c1',
        memberId: 'm1',
      );
      expect(stats.attended, 1);
      expect(stats.finished, 2);
      expect(stats.ratePercent, 50);
    });

    test('당일 라운딩은 자정을 넘기기 전까지 세지 않는다', () {
      // isPast 는 날짜만 비교한다 — 당일 하루는 '예정'이다.
      final stats = AttendanceStats.forMember(
        schedules: [
          _schedule(
              id: 's1', date: DateTime.now(), responses: [_res('m1', '참석')]),
        ],
        clubId: 'c1',
        memberId: 'm1',
      );
      expect(stats.finished, 0, reason: '당일은 아직 다녀온 게 아니다');
    });

    test('회원 상세가 계산 결과를 그대로 보여 준다', () {
      // 화면이 자체 계산으로 돌아가면 위 규칙이 무력화된다.
      final detail = _read('lib/screens/members/member_detail_screen.dart');
      expect(detail.contains('AttendanceStats.forMember('), isTrue);
      expect(detail.contains('stats.attended'), isTrue);
      expect(detail.contains('stats.finished'), isTrue);
      expect(detail.contains('stats.ratePercent'), isTrue);
      // 예전처럼 responses 를 직접 세면 예정 일정이 섞인다.
      expect(
        detail.contains("r.response == '참석'"),
        isFalse,
        reason: '상세 화면이 직접 세면 예정·취소 일정이 다시 새어 든다',
      );
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

  group('마이페이지 편집 시트', () {
    final mypage = _read('lib/screens/ad/ad_screen.dart');
    final sheet = mypage.substring(
      mypage.indexOf('void _showProfileEditDialog('),
      mypage.indexOf('static Future<void> _pickPhotoWeb('),
    );

    test('취소 버튼이 있다', () {
      // 저장만 있으면 잘못 들어왔을 때 나갈 길이 스와이프뿐이다.
      expect(sheet.contains("child: const Text('취소'"), isTrue);
      expect(sheet.contains('Navigator.pop(sheetCtx)'), isTrue);
      // 저장 버튼도 그대로 있어야 한다.
      expect(sheet.contains("child: const Text('저장'"), isTrue);
    });

    test('앱에서도 사진을 실제로 고를 수 있다', () {
      // 예전엔 kIsWeb 아니면 "지원됩니다" 안내만 띄우고 아무 일도 안 했다.
      expect(sheet.contains('ImagePicker().pickImage('), isTrue);
      expect(sheet.contains('ImageSource.gallery'), isTrue);
      expect(sheet.contains('base64Encode(bytes)'), isTrue);
      expect(
        sheet.contains('앱 빌드에서는 갤러리 연동이 지원됩니다'),
        isFalse,
        reason: '동작하지 않는데 된다고 안내하면 안 된다',
      );
      // 웹 경로도 남아 있어야 한다.
      expect(sheet.contains('_pickPhotoWeb('), isTrue);
    });

    test('저장 버튼이 홈 인디케이터에 가리지 않는다', () {
      // viewInsets(키보드) 만 더하면 제스처 바에 버튼이 깔린다.
      expect(sheet.contains('MediaQuery.viewPaddingOf(sheetCtx).bottom'), isTrue);
      expect(sheet.contains('MediaQuery.viewInsetsOf(sheetCtx).bottom'), isTrue);
      expect(sheet.contains('+ safeBottom'), isTrue);
    });
  });

  group('핸디캡은 정수만 쓴다', () {
    test('입력 화면들이 소수점을 막는다', () {
      const paths = {
        'lib/screens/ad/ad_screen.dart': '마이페이지 편집',
        'lib/screens/auth/golf_profile_screen.dart': '가입 단계',
        'lib/screens/members/member_form_screen.dart': '회원 등록·수정',
      };
      for (final e in paths.entries) {
        final src = _read(e.key);
        final at = src.indexOf('_handicapCtrl');
        final ctrl = at >= 0 ? '_handicapCtrl' : 'handicapCtrl';
        final field = src.substring(
          src.indexOf('controller: $ctrl'),
          src.indexOf('controller: $ctrl') + 600,
        );
        expect(
          field.contains('FilteringTextInputFormatter.digitsOnly'),
          isTrue,
          reason: '${e.value}: 소수점이 들어가면 핸디 표기가 갈린다',
        );
        expect(
          field.contains('decimal: true'),
          isFalse,
          reason: '${e.value}: 소수점 키패드를 띄우면 안 된다',
        );
      }
    });

    test('표시도 소수점 없이 반올림한다', () {
      final user = _read('lib/models/user_model.dart');
      expect(user.contains("handicap!.round().toString()"), isTrue);
      expect(
        user.contains('handicap!.toStringAsFixed(1)'),
        isFalse,
        reason: '예전 소수점 값이 저장돼 있어도 정수로 보여야 한다',
      );

      final mypage = _read('lib/screens/ad/ad_screen.dart');
      expect(mypage.contains('handicap.toStringAsFixed(1)'), isFalse);
    });

    test('저장 시 0~54 정수로 검증한다', () {
      final signup = _read('lib/screens/auth/golf_profile_screen.dart');
      expect(signup.contains('int.tryParse(raw)'), isTrue);
      expect(signup.contains('n < 0 || n > 54'), isTrue);

      final mypage = _read('lib/screens/ad/ad_screen.dart');
      expect(mypage.contains('int.tryParse(handicapCtrl.text.trim())'), isTrue);
      expect(mypage.contains('rawHandicap > 54'), isTrue);
    });

    test('신페리오 계산 핸디는 소수점을 유지한다', () {
      // (1.5 배 계산 결과라 정수가 아니다 — 여기까지 정수로 바꾸면 안 된다)
      final shinperio = _read('lib/screens/records/shinperio_screen.dart');
      expect(shinperio.contains('p.handicap.toStringAsFixed(1)'), isTrue);
    });
  });

  group('갤러리 사진(data URI)이 아바타에 보인다', () {
    test('회원 사진은 공용 헬퍼로만 그린다', () {
      // NetworkImage 는 http/https 만 처리한다. data URI 를 넘기면
      // onBackgroundImageError 가 조용히 삼켜 빈 아바타가 된다.
      // (저장은 됐는데 사진이 안 보이던 원인)
      const paths = [
        'lib/screens/ad/ad_screen.dart',
        'lib/screens/members/members_screen.dart',
        'lib/screens/members/member_detail_screen.dart',
      ];
      for (final p in paths) {
        final src = _read(p);
        expect(src.contains("import '../../utils/avatar_image.dart';"), isTrue,
            reason: p);
        expect(src.contains('avatarImage('), isTrue, reason: p);
        expect(
          src.contains('NetworkImage('),
          isFalse,
          reason: '$p: 직접 NetworkImage 를 쓰면 갤러리 사진이 다시 안 보인다',
        );
      }
    });

    test('헬퍼가 data URI / http / 빈 값을 구분한다', () {
      // 1x1 투명 PNG
      const png =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
          'AAAADUlEQVR42mP8z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg==';
      expect(avatarImage(png), isA<MemoryImage>());
      expect(avatarImage('https://example.com/a.jpg'), isA<NetworkImage>());
      expect(avatarImage(null), isNull);
      expect(avatarImage(''), isNull);
      expect(avatarImage('   '), isNull);
      // 콤마 없는 깨진 data URI — 예외 대신 null 로 떨어져야 한다.
      expect(avatarImage('data:image/png;base64'), isNull);
      // 잘린 base64
      expect(avatarImage('data:image/png;base64,!!!not-base64!!!'), isNull);
      // 상대경로 등 알 수 없는 형식은 이니셜로
      expect(avatarImage('assets/x.png'), isNull);
    });
  });

  group('회원 상세 화면 상단', () {
    final detail = _read('lib/screens/members/member_detail_screen.dart');

    test('96px 그라데이션 배너를 걷어냈다', () {
      // 배너 + 겹친 아바타 + 52px 여백이라 이름이 한참 아래에서 시작했다.
      expect(detail.contains('height: 96,'), isFalse);
      expect(detail.contains('const SizedBox(height: 52),'), isFalse);
      expect(detail.contains('Positioned(\n                top: 56,'), isFalse);
      // 아바타와 이름이 가로 한 줄에 온다.
      expect(detail.contains('_buildAvatar(radius: 34, fontSize: 22)'), isTrue);
    });

    test('사진 변경이 URL 입력이 아니라 갤러리 선택이다', () {
      expect(detail.contains('ImagePicker().pickImage('), isTrue);
      expect(detail.contains('ImageSource.gallery'), isTrue);
      expect(
        detail.contains('사진 URL을 입력하거나'),
        isFalse,
        reason: '폰에서 URL 을 타이핑할 수는 없다',
      );
      // 쓰이지 않던 이모지·색상 리스트도 함께 정리했다.
      expect(detail.contains("'🔵', '🟢', '🔴'"), isFalse);
      expect(detail.contains('final avatarColors ='), isFalse);
    });

    test('본문에 그린이 없다 — 로고 헤더·탭바 전용', () {
      final green = RegExp(
        r'AppColors\.(primary|primaryDark|primaryLight|sage\w*|mint\w*|'
        r'cardMint|paidBg)\b',
      );
      final offenders = <String>[];
      final lines = detail.split(RegExp(r'\r?\n'));
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // 모든 카드가 공유하는 그림자. alpha 0.06 이라 눈에 보이지 않는다.
        if (line.contains('alpha: 0.06')) continue;
        if (green.hasMatch(line)) offenders.add('${i + 1}: ${line.trim()}');
      }
      expect(offenders, isEmpty,
          reason: '회원 상세에 그린이 남았다:\n  ${offenders.join('\n  ')}');
    });
  });
}
