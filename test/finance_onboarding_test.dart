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
}
