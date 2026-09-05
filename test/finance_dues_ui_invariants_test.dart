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

  test('잔고 카드는 좌우 1:1이다 (왼쪽이 넓지 않다)', () {
    // 왼쪽 잔고가 넓어서 오른쪽 수입/지출 금액이 줄어들던 문제
    expect(finance.contains('flex: 11'), isFalse);
    expect(finance.contains('flex: 9'), isFalse);
  });

  test('수입/지출 월 요약은 변동액이고 테두리가 있다', () {
    expect(finance.contains("leftLabel: '변동액'"), isTrue);
    expect(finance.contains("leftLabel: '잔액'"), isFalse);
    expect(finance.contains('borderColor: const Color(0xFFE5E7EB)'), isTrue);
  });

  test('결산보고는 원클럽형 — 연 결산 히어로 카드', () {
    expect(finance.contains('class _YearlyHeroCard'), isTrue);
    expect(finance.contains('연간 결산보고'), isTrue);
    // 3분할 _StatCard 대신 _SplitMoneyRow 재사용
    expect(finance.contains('class _StatCard'), isFalse);
    // 월 결산은 기간 선택 + 헤더 + 잔고 흐름
    expect(finance.contains('class _ReportPeriodSelector'), isTrue);
    expect(finance.contains('class _BalanceFlowCard'), isTrue);
    expect(finance.contains('class _MonthlyTable'), isTrue);
  });

  test('월 결산에서 변동액 요약 카드는 잔고 흐름과 겹쳐서 뺐다', () {
    // _BalanceFlowCard 가 이전잔고 + 수입 − 지출 = 마감잔고 를 이미 보여 준다.
    // 바로 위에 총수입·총지출을 또 띄우면 같은 숫자가 두 번 나온다.
    expect(finance.contains('class _SummaryCards'), isFalse);
    expect(finance.contains('_SummaryCards('), isFalse);

    // 월 결산 본문에는 헤더 다음이 곧바로 잔고 흐름이어야 한다.
    final report = finance.substring(
      finance.indexOf('class _MonthlyReport'),
      finance.indexOf('//  연 결산 보고서'),
    );
    expect(report.contains('_ReportHeader('), isTrue);
    expect(report.contains('_BalanceFlowCard('), isTrue);
    expect(
      report.indexOf('_BalanceFlowCard('),
      greaterThan(report.indexOf('_ReportHeader(')),
    );
  });

  test('기존 잔액 등록 카드는 총무만 본다', () {
    // 비총무는 잠금 안내만 보고 금액·수정 버튼을 못 본다.
    expect(finance.contains('final isAdmin = isTreasurer;'), isTrue);
    final block = finance.substring(
      finance.indexOf('// ── 기존 잔액 등록'),
      finance.indexOf('// ── 기존 잔액 등록') + 1400,
    );
    expect(block.contains('if (isAdmin)'), isTrue);
    expect(block.contains('_OpeningBalanceSettingCard'), isTrue);
    expect(block.contains('초기 잔고·회비 세팅은 총무만 가능합니다'), isTrue);
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
