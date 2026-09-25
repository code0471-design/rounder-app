import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/models/club_model.dart';

void main() {
  late String source;

  setUpAll(() {
    source =
        File('lib/screens/group_assignment/group_assignment_screen.dart')
            .readAsStringSync();
  });

  test('조편성 상단은 팀 수 → 방식 카드 → 자동배정 옵션 순이다', () {
    final team = source.indexOf('_TeamCountPanel(');
    final mode = source.indexOf('_ModeSelector(');
    final auto = source.indexOf('_AutoOptionsPanel(');
    expect(team, greaterThan(0));
    expect(mode, greaterThan(team));
    expect(auto, greaterThan(mode));
    expect(source.contains("'팀 수'"), isTrue);
    expect(source.contains("'조 수'"), isFalse);
  });

  test('동반자와 같은 조는 없고 평균타수·직전 모임 분리 문구를 쓴다', () {
    expect(source.contains('pairCompanions'), isTrue,
        reason: '저장된 옛 옵션만 걸러야 한다');
    expect(source.contains('_kAutoOptions'), isTrue);
    expect(source.contains('AutoAssignOption.pairCompanions'), isTrue);
    expect(source.contains("label: '동반자"), isFalse);
    expect(AutoAssignOption.balanceHandicap.label, '평균타수 밸런스');
    expect(AutoAssignOption.avoidLastMonth.label, '직전 모임 같은 조 분리');
    expect(AutoAssignOption.pairGuestReferrer.label, '게스트+소개자');
  });

  test('하단 초기화 버튼은 없고 헤더 초기화는 버튼이다', () {
    expect(source.contains('class _ControlPanel'), isFalse);
    expect(source.contains('OutlinedButton('), isTrue);
    expect(source.contains('_confirmClear(provider)'), isTrue);
    expect(source.contains('OutlinedButton.icon'), isFalse,
        reason: '본문 아래 초기화 버튼이 남아 있으면 안 된다');
  });

  test('조 카드는 가운데 조명과 한글 성별 원만 보여 준다', () {
    expect(source.contains("filledCount}/\${group.slots.length}명"), isFalse);
    expect(source.contains('avgHandicap'), isFalse);
    expect(source.contains('class _GenderBar'), isFalse);
    expect(source.contains("alignment: Alignment.center"), isTrue);
    expect(source.contains("fontSize: 18"), isTrue);
    expect(source.contains("genderLabel = isFemale ? '여' : '남'"), isTrue);
    expect(source.contains('0xFF3B82F6'), isTrue);
    expect(source.contains('0xFFEC4899'), isTrue);
    expect(source.contains("compact ? 15 : 17"), isTrue);
  });

  test('헤더 일정명이 본문보다 크고 자동배정 글자는 스케일된다', () {
    expect(source.contains('schedule.displayTitle'), isTrue);
    expect(source.contains('fontSize: 16'), isTrue);
    expect(source.contains("color: Color(0xFF999999), fontSize: 11"), isFalse,
        reason: '일정명이 회색 작은 글자면 안 보인다');
    expect(source.contains('FittedBox'), isTrue);
    expect(source.contains("'빈 자리 자동 배정'"), isTrue);
  });
}
