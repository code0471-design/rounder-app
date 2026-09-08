import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/utils/finance_onboarding.dart';

void main() {
  test('올시즌은 올해 1월 1일, 이번달은 이번 달 1일', () {
    final now = DateTime(2026, 9, 6);
    expect(
      FinanceOnboarding.openingAsOf(FinanceStartMode.season, now),
      DateTime(2026, 1, 1),
    );
    expect(
      FinanceOnboarding.openingAsOf(FinanceStartMode.thisMonth, now),
      DateTime(2026, 9, 1),
    );
    expect(
      FinanceOnboarding.memoFor(FinanceStartMode.season, now),
      contains('올시즌'),
    );
    expect(
      FinanceOnboarding.memoFor(FinanceStartMode.thisMonth, now),
      contains('이번달'),
    );
  });

  test('잔고 다음 스텝은 연·월 회비 종류를 묻는다', () {
    final src = File(
            'lib/screens/finance/treasurer_finance_onboarding_screen.dart')
        .readAsStringSync();
    expect(src.contains('잔고등록을 잘 마쳤습니다'), isTrue);
    expect(src.contains('우리 모임은 연회비를 걷나요? 월회비를 걷나요?'), isTrue);
    expect(src.contains('연회비를 걷어요'), isTrue);
    expect(src.contains('월회비를 걷어요'), isTrue);
    expect(src.contains('setOpeningBalance'), isTrue);
    expect(src.contains('_step = 2'), isTrue);
  });
}
