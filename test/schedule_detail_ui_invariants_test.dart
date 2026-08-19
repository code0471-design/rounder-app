import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 일정 상세 UI 회귀 방지 — 딥그린 헤더 카드 + 주황 조편성 + 슬림 상세 하단 유지.
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

  test('조편성 헤더는 주황 톤, 옛 블루/보라 배너 금지', () {
    expect(source.contains('0xFFFF8F00'), isTrue,
        reason: '조편성 주황(_orange)이 사라짐');
    expect(source.contains('0xFF0D47A1'), isFalse);
    expect(source.contains('0xFF1565C0'), isFalse);
    // 스코어/시상/사진 옛 보라 액센트 금지
    expect(source.contains('0xFF7C3AED'), isFalse);
    expect(source.contains('0xFF6D28D9'), isFalse);
  });

  test('기준 UI: 딥그린 헤더 카드 + 장소·시간 강조 (SliverAppBar/RoundHero 금지)', () {
    expect(source.contains('Size.fromHeight(108)'), isTrue,
        reason: '장소·시간 강조 카드형 AppBar(108)가 사라짐');
    expect(source.contains('Icons.place_rounded'), isTrue);
    expect(source.contains('Icons.schedule_rounded'), isTrue);
    expect(source.contains('BorderRadius.circular(16)'), isTrue,
        reason: '상단 카드형 라운드가 사라짐');
    expect(
      source.contains('딥그린 카드형') ||
          source.contains('[AppColors.primaryDark, AppColors.primary]'),
      isTrue,
      reason: '헤더 딥그린 그라데이션이 사라짐',
    );
    expect(source.contains('SliverAppBar'), isFalse,
        reason: '옛 SliverAppBar 상세로 회귀');
    expect(source.contains('class _RoundHeroCard'), isFalse,
        reason: '대체 히어로 디자인이 다시 들어옴 — 제거 유지');
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
}
