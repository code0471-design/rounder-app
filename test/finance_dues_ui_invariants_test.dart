import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String finance;
  late String provider;

  setUpAll(() {
    finance = File('lib/screens/finance/finance_screen.dart').readAsStringSync();
    provider = File('lib/providers/club_provider.dart').readAsStringSync();
  });

  test('재무 잔고는 크림 위 다크 카드이고 금액과 원이 붙어 있다', () {
    expect(finance.contains('class _SplitMoneyRow'), isTrue);
    expect(finance.contains("leftValue: '\${_fmtSigned(balance)}원'"), isTrue);
    expect(finance.contains('Color(0xFF0D1117)'), isTrue);
    expect(finance.contains('letterSpacing: 0.2 * 10'), isFalse);
    expect(finance.contains('fontSize: 42, fontWeight: FontWeight.w300'), isFalse);
  });

  test('회비설정은 연·월 모임 선택 후 해당 회비와 특별회비만 연다', () {
    expect(finance.contains('월회비 모임'), isTrue);
    expect(finance.contains('연회비 모임'), isTrue);
    expect(finance.contains('어떤 종류의 회비를 걷는 모임인지 선택하세요'), isTrue);
    expect(finance.contains('clubPrimaryDuesType'), isTrue);
    expect(finance.contains('switchPrimaryDuesType'), isTrue);
    expect(finance.contains('연회비로 변경'), isTrue);
    expect(finance.contains('기존 납부 기록은 유지됩니다'), isTrue);
    expect(
      finance.contains("allowedTypes: const [DuesType.monthly, DuesType.special]"),
      isTrue,
    );
    expect(
      finance.contains("allowedTypes: const [DuesType.annual, DuesType.special]"),
      isTrue,
    );
  });

  test('회비 추가 버튼에 말풍선이 없다', () {
    expect(finance.contains('showDuesBubble'), isFalse);
    expect(finance.contains("onTap: () => _showAddDuesSheet(context, provider)"), isFalse);
  });

  test('재무 4탭은 원클럽형 텍스트 탭이다', () {
    expect(finance.contains("Tab(text: '납부현황')"), isTrue);
    expect(finance.contains("Tab(text: '수입/지출')"), isTrue);
    expect(finance.contains("Tab(text: '결산보고')"), isTrue);
    expect(finance.contains("Tab(text: '회비설정')"), isTrue);
    expect(finance.contains('_FinanceTabLabel'), isFalse);
    expect(finance.contains('회비를 설정하고 사용하세요'), isTrue);
    expect(finance.contains("const Text('납부 O'"), isFalse);
    expect(finance.contains('납부 \$paidCount'), isTrue);
    expect(finance.contains("label: const Text('회비추가'"), isTrue);
    expect(finance.contains('panelColor: Colors.white'), isTrue);
  });

  test('월↔연 전환은 로컬만 남기지 않고 persist 한다', () {
    expect(provider.contains('void switchPrimaryDuesType'), isTrue);
    expect(provider.contains('_persistImmediately();'), isTrue);
    final switchBlock = provider.substring(
      provider.indexOf('void switchPrimaryDuesType'),
      provider.indexOf('void switchPrimaryDuesType') + 700,
    );
    expect(switchBlock.contains('_persistImmediately()'), isTrue);
  });
}
