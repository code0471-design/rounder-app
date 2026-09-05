import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 일정 상세 UI 회귀 방지 — 크림·골드·차콜 톤 + 슬림 상세 하단 유지.
///
/// 그린(AppColors.primary 계열)은 상단 로고 헤더와 하단 탭바 전용이다.
/// 일정 상세 본문에 그린이 다시 들어오면 아래 테스트가 잡는다.
void main() {
  late String source;

  setUpAll(() {
    source =
        File('lib/screens/schedule/schedule_screen.dart').readAsStringSync();
  });

  test('홀인원보험 배너는 일정 상세에서 비활성(주석)이어야 한다', () {
    final activeCall = RegExp(
      r'^\s*if\s*\(!isPast\)\s*_InsuranceBannerCard',
      multiLine: true,
    );
    expect(activeCall.hasMatch(source), isFalse,
        reason: '일정 상세에서 _InsuranceBannerCard 활성 호출이 다시 켜짐');
  });

  test('조편성 카드는 크림·골드 톤, 옛 블루/보라/주황 배너 금지', () {
    expect(source.contains('0xFFC9A227'), isFalse,
        reason: '조편성 전용 골드 상수는 AppColors.accent 로 합쳤다');
    expect(source.contains('0xFFFBF6E4'), isFalse,
        reason: '파스텔 베이지 그라데이션은 제거했다');
    expect(source.contains('0xFFF8F1D6'), isFalse);
    expect(source.contains('0xFFFF8F00'), isFalse,
        reason: '옛 주황 조편성 톤이 남아 있음');
    expect(source.contains('0xFF0D47A1'), isFalse);
    expect(source.contains('0xFF1565C0'), isFalse);
    // 스코어/시상/사진 옛 보라 액센트 금지
    expect(source.contains('0xFF7C3AED'), isFalse);
    expect(source.contains('0xFF6D28D9'), isFalse);
  });

  test('기준 UI: 웜차콜 헤더 카드 + 장소·시간 강조 (SliverAppBar/RoundHero 금지)', () {
    expect(source.contains('Size.fromHeight(128)'), isTrue,
        reason: '장소·시간 강조 카드형 AppBar(128)가 사라짐');
    expect(source.contains('Icons.place_rounded'), isTrue);
    expect(source.contains('Icons.schedule_rounded'), isTrue);
    expect(source.contains('BorderRadius.circular(16)'), isTrue,
        reason: '상단 카드형 라운드가 사라짐');
    expect(
      source.contains('[AppColors.charcoalDeep, AppColors.charcoal]'),
      isTrue,
      reason: '헤더 배너가 웜 차콜이 아님',
    );
    expect(
      source.contains('[AppColors.primaryDark, AppColors.primary]'),
      isFalse,
      reason: '헤더가 딥그린으로 되돌아감 — 그린은 로고 헤더·탭바 전용',
    );
    expect(source.contains('SliverAppBar'), isFalse,
        reason: '옛 SliverAppBar 상세로 회귀');
    expect(source.contains('class _RoundHeroCard'), isFalse,
        reason: '대체 히어로 디자인이 다시 들어옴 — 제거 유지');
  });

  test('일정 상세 본문에 그린이 없다', () {
    // 그린은 상단 로고 헤더와 하단 탭바 전용.
    // 여기서 걸리면 본문 어딘가에 primary 계열이 다시 들어온 것이다.
    final lines = source.split(RegExp(r'\r?\n'));
    final green = RegExp(
      r'AppColors\.(primary|primaryDark|primaryLight|success|sage\w*|'
      r'mint\w*|heroGreen\w*|cardMint|paidBg)\b'
      r'|0xFF1B4D3E|0xFF153D32|0xFF2A6B55|0xFFE8F0EC',
    );
    // 상세 화면·상세에서 여는 카드/시트가 있는 구간만 본다.
    // (일정 목록·등록 폼은 아직 그린을 쓴다 — 별도 작업)
    const ranges = [
      [974, 1900], // ScheduleDetailScreen 본문 + 응답 다이얼로그
      [2189, 2500], // 응답 마감 · 대기 명단
      [2491, 2760], // 참석 현황
      [4762, 5160], // 조편성 카드
      [5159, 5370], // 스코어 & 시상
    ];

    final offenders = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final no = i + 1;
      if (!ranges.any((r) => no >= r[0] && no <= r[1])) continue;
      final line = lines[i];
      // 모든 카드가 공유하는 그림자. alpha 0.06 이라 눈에 보이지 않는다.
      if (line.contains('alpha: 0.06')) continue;
      if (green.hasMatch(line)) offenders.add('$no: ${line.trim()}');
    }
    expect(
      offenders,
      isEmpty,
      reason: '일정 상세 본문에 그린이 남았다:\n  ${offenders.join('\n  ')}',
    );
  });

  test('본문 강조 토큰이 팔레트에 있다', () {
    final theme = File('lib/theme/app_theme.dart').readAsStringSync();
    expect(theme.contains('static const charcoal       = Color(0xFF2B2A26)'),
        isTrue);
    expect(theme.contains('static const charcoalDeep   = Color(0xFF1B1A17)'),
        isTrue);
    expect(
        theme.contains('static const goldDeep       = Color(0xFF8A6D1B)'),
        isTrue);
  });

  test('내 응답은 참석/불참 2버튼 (미정 3버튼 금지)', () {
    expect(source.contains("children: ['참석', '불참']"), isTrue);
    expect(source.contains("['참석', '불참', '미정']"), isFalse,
        reason: '미정 3버튼 UI로 회귀');
  });

  test('일정 취소 확정은 dialogCtx로 먼저 pop 해야 한다', () {
    expect(source.contains('void _confirmCancel'), isTrue);
    expect(source.contains("child: const Text('취소 확정')"), isTrue);
    final start = source.indexOf('void _confirmCancel');
    final end = source.indexOf('String _fmtDate(DateTime d)', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final cancelFn = source.substring(start, end);
    expect(cancelFn.contains('builder: (dialogCtx)'), isTrue,
        reason: '취소 확정이 부모 context를 pop하면 버튼이 안 먹은 것처럼 보인다');
    expect(cancelFn.contains('Navigator.of(dialogCtx).pop()'), isTrue);
    expect(cancelFn.contains('Navigator.pop(context);\n              Navigator.pop(context);'),
        isFalse,
        reason: '취소 전에 부모를 두 번 pop하면 얼럿이 남고 취소만 뒤에서 반영된다');
  });

  test('조편성 미확정 얼럿은 dialogCtx로 pop 해야 한다', () {
    expect(source.contains('Navigator.of(dialogCtx).pop()'), isTrue,
        reason: '확인 버튼이 부모 context를 pop하면 에러남');
    expect(
      source.contains('아직 조편성이 확정되지 않았습니다'),
      isTrue,
    );
    expect(
      source.contains('조편성이 확정되었기 때문에 불참 변경시 총무에게 알림이 갑니다'),
      isTrue,
      reason: '조편성 확정 후 불참 변경 안내 얼럿이 사라짐',
    );
  });

  test('리치 상세 하단 구성요소 유지 (건드리지 말 것)', () {
    expect(source.contains('class _ReviewMemoCard'), isTrue);
    expect(source.contains('class _RsvpWaitingCard'), isTrue);
    expect(source.contains('class _GroupViewBannerCard'), isTrue);
    expect(source.contains('class _ScoreAwardBannerCard'), isTrue);
  });

  test('한글이 깨지지 않아야 한다 (??? / mojibake 금지)', () {
    expect(source.contains('조편성'), isTrue);
    expect(source.contains('내 응답'), isTrue);
    expect(source.contains('티오프'), isTrue);
    expect(RegExp(r'\?\?\?').hasMatch(source), isFalse,
        reason: 'UTF-8 깨짐 — StrReplace로 schedule_screen을 건드리지 말 것');
  });

  test('일정 상세는 provider.scheduleById로 최신 일정을 써야 한다', () {
    expect(source.contains('provider.scheduleById(this.schedule.id)'), isTrue,
        reason: '스냅샷 schedule만 쓰면 참석/조편성 인원이 어긋난다');
  });

  test('참석 현황은 스코어/시상 카드 위에 있어야 한다', () {
    final bodyStart = source.indexOf('body: SingleChildScrollView(');
    final bodyEnd = source.indexOf('Widget _buildMyResponseCard(', bodyStart);
    expect(bodyStart, greaterThanOrEqualTo(0));
    expect(bodyEnd, greaterThan(bodyStart));
    final body = source.substring(bodyStart, bodyEnd);
    final attendance = body.indexOf('_AttendanceCard(schedule: schedule)');
    final score =
        body.indexOf('_ScoreAwardBannerCard(schedule: schedule, isPast: isPast)');
    final group = body.indexOf('_GroupViewBannerCard(');
    final info = body.indexOf('_InfoCard(schedule: schedule)');
    expect(attendance, greaterThanOrEqualTo(0),
        reason: '참석 현황 카드가 사라짐');
    expect(score, greaterThanOrEqualTo(0), reason: '스코어/시상 카드가 사라짐');
    expect(group, greaterThanOrEqualTo(0), reason: '조편성 배너가 사라짐');
    expect(info, greaterThanOrEqualTo(0), reason: '일정 정보 카드가 사라짐');
    expect(group < attendance, isTrue, reason: '조편성 다음에 참석 현황이 와야 함');
    expect(attendance < score, isTrue,
        reason: '참석 현황이 스코어/시상 아래로 내려가면 안 됨');
    expect(score < info, isTrue, reason: '스코어/시상 다음에 일정 정보가 와야 함');
    expect(body.contains('class _ReviewMemoCard'), isFalse);
    expect(body.contains('_ReviewMemoCard(schedule: schedule)'), isTrue);
    expect(body.contains('_RsvpWaitingCard(schedule: schedule, isAdmin: isAdmin)'),
        isTrue);
    expect(body.contains('_PhotoSection(schedule: schedule)'), isTrue);
  });

  test('일정 상세 카드는 리뉴얼 톤(흰 카드+divider 테두리+딥그린 그림자)으로 통일돼 있다', () {
    int countOf(String needle) => source.split(needle).length - 1;
    // 내 응답 / 조편성 / 참석 현황 / RSVP·대기 / 스코어 / 일정 정보 / 사진 / 후기
    expect(countOf('border: Border.all(color: AppColors.divider),'),
        greaterThanOrEqualTo(6),
        reason: '카드 테두리가 다시 빠졌다 (radius 14 + 검정 그림자 옛 스타일 회귀)');
    expect(countOf('color: AppColors.primary.withValues(alpha: 0.06),'),
        greaterThanOrEqualTo(6),
        reason: '카드 그림자가 딥그린 톤에서 검정으로 회귀');
  });

  test('상세 카드에 옛 회색·블루그레이 팔레트가 없어야 한다', () {
    for (final hex in const [
      '0xFF999999',
      '0xFF222222',
      '0xFFEEEEEE',
      '0xFF90A4AE',
      '0xFF78909C',
      '0xFFF5F7FA',
      '0xFFF8F9FA',
    ]) {
      expect(source.contains(hex), isFalse,
          reason: '옛 팔레트 $hex 가 다시 들어옴 — AppColors를 쓸 것');
    }
  });

  test('일정 정보 행은 rounded 아이콘을 쓴다', () {
    expect(source.contains("_InfoRow(Icons.golf_course_rounded, '골프장'"), isTrue);
    expect(source.contains("_InfoRow(Icons.schedule_rounded, '티오프'"), isTrue);
    for (final old in const [
      '_InfoRow(Icons.golf_course,',
      '_InfoRow(Icons.access_time,',
      '_InfoRow(Icons.group_outlined,',
      '_InfoRow(Icons.person_outline,',
      '_InfoRow(Icons.location_on_outlined,',
      '_InfoRow(Icons.campaign_outlined,',
      '_InfoRow(Icons.people_alt_outlined,',
    ]) {
      expect(source.contains(old), isFalse, reason: '옛 아이콘 회귀: $old');
    }
  });

  test('일정 등록에 예약 문자 붙여넣기가 있어야 한다', () {
    expect(source.contains('ReservationSmsFillBanner'), isTrue,
        reason: '일정 등록 예약 문자 배너가 사라짐');
    expect(source.contains('_applyReservationParse'), isTrue);
    expect(source.contains('if (!_isEdit)'), isTrue,
        reason: '예약 문자는 신규 등록에서만 보여야 함');
    final banner = File('lib/widgets/reservation_sms_fill_banner.dart')
        .readAsStringSync();
    expect(banner.contains('예약 문자 붙여넣기'), isTrue);
    expect(banner.contains('parseReservationSms'), isTrue);
  });

  test('일정 갤러리는 다중 선택 삭제와 삭제 후 목록 복귀가 있어야 한다', () {
    expect(source.contains('deletePhotos'), isTrue,
        reason: '여러 장 삭제 API 호출이 없음');
    expect(source.contains('_selecting'), isTrue, reason: '앨범 선택 모드가 없음');
    expect(source.contains('삭제 후 목록(앨범)으로 복귀'), isTrue,
        reason: '뷰어 삭제 후 목록 복귀 주석/동작이 없음');
  });

  test('일정 카드는 날짜 타일과 일시·참석 푸터를 유지한다', () {
    expect(source.contains('class _ScheduleDateTile'), isTrue);
    expect(source.contains('class _ScheduleDdayBadge'), isTrue);
    expect(source.contains('calendar_today_outlined'), isFalse);
    expect(source.contains('class _AttendButton'), isTrue);
    expect(source.contains("responded ? currentResponse! : '미답변'"), isTrue);
    expect(source.contains("responded ? currentResponse! : '참석'"), isFalse);
    expect(source.contains("responded ? currentResponse! : '응답하기'"), isFalse);
  });
}
