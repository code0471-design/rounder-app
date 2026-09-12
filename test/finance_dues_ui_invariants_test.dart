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
    expect(
      finance.contains('members.where((m) => paidIds.contains(m.id)).length'),
      isTrue,
      reason: '납부 인원은 현재 회원과 교집합이어야 함 (2/1·미납 -1 방지)',
    );
    expect(finance.contains('미납 \$unpaidCount'), isTrue);
    expect(finance.contains('미납 \${totalCount - paidCount}'), isFalse,
        reason: '미납이 음수가 되면 안 됨');
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
      provider.indexOf('void switchPrimaryDuesType') + 1400,
    );
    expect(switchBlock.contains('_persistImmediately()'), isTrue);
  });

  test('신규 모임 총무는 재무 첫 방문 온보딩을 보고 비총무는 기존 안내다', () {
    expect(finance.contains('TreasurerFinanceOnboardingScreen'), isTrue);
    expect(finance.contains('needsTreasurerFinanceOnboarding'), isTrue);
    expect(finance.contains('_FinanceSetupPendingView'), isTrue);
    expect(provider.contains('needsTreasurerFinanceOnboarding'), isTrue);
    final onboard = File(
            'lib/screens/finance/treasurer_finance_onboarding_screen.dart')
        .readAsStringSync();
    expect(onboard.contains('총무님 반갑습니다'), isTrue);
    expect(onboard.contains('올시즌 처음부터 회계 현황을 입력'), isTrue);
    expect(onboard.contains('이번달 회계자료부터 입력'), isTrue);
    expect(onboard.contains('잔고등록을 잘 마쳤습니다'), isTrue);
    expect(onboard.contains('우리 모임은 연회비를 걷나요? 월회비를 걷나요?'), isTrue);
    expect(
      onboard.contains(
          'void Function(DuesType kind, FinanceStartMode mode) onFinished'),
      isTrue,
    );
    expect(onboard.contains('class TreasurerTxPromptScreen'), isTrue);
    expect(finance.contains('_treasurerOnboardingSession'), isTrue);
    expect(finance.contains('_showTxPrompt'), isTrue);
    expect(finance.contains('_finishTxPrompt'), isTrue);
    expect(finance.contains("initialType: kind"), isTrue);
    expect(finance.contains('defaultYear: asOf.year'), isTrue);
    expect(finance.contains('_date = DateTime(y, m, 1)'), isTrue);
    expect(finance.contains("'예: 모임 월회비'"), isTrue);
    expect(finance.contains("'예: \$y년 월회비'"), isFalse);
    expect(finance.contains('class _YearMonthPickerSheet'), isTrue);
    expect(finance.contains('class _DayOfMonthPickerSheet'), isTrue);
    expect(finance.contains('minHeight: 56'), isTrue);
  });

  test('잔고 등록 완료 회비설정 안내 카드는 없다', () {
    expect(finance.contains('_SetupDuesHintBanner'), isFalse);
    expect(finance.contains('잔고 등록 완료!'), isFalse);
  });

  test('게스트는 회비 납부 대상이 아니다', () {
    expect(finance.contains('연회비·특별회비는 전체 활성 회원'), isFalse);
    expect(finance.contains('게스트는 월·연·특별 모두 제외'), isTrue);
    expect(
      finance.contains('final members = provider.regularMembers;'),
      isTrue,
    );
    expect(
      finance.contains(': provider.activeMembers;'),
      isFalse,
      reason: '납부현황 분모에 게스트가 들어가면 안 됨',
    );
    final unpaid = provider.substring(
      provider.indexOf('int unpaidCountForDuesSetting('),
      provider.indexOf('MonthUnpaidSummary monthUnpaidSummary('),
    );
    expect(unpaid.contains('regularMembers'), isTrue);
    expect(unpaid.contains('activeMembers'), isFalse);
  });

  test('납부는 다른 모임 회비의 clubId를 이 모임으로 바꾸지 않는다', () {
    final start = provider.indexOf('// 잔고 스코프는 selectedClub 기준');
    expect(start, greaterThan(0));
    final fn = provider.substring(start, start + 1600);
    expect(fn.contains('clubId: txClubId'), isTrue);
    expect(fn.contains("s.clubId == null || s.clubId!.isEmpty"), isTrue);
    expect(
      fn.contains('!clubIdAliases(selectedClub.id).contains(s.clubId)'),
      isFalse,
      reason: '다른 모임 회비를 현재 모임으로 바꿔 붙이면 재무가 섞인다',
    );
  });

  test('납부 인원은 현재 회원만 센다', () {
    final start = provider.indexOf('int paidCountForMonth(');
    final end = provider.indexOf('int unpaidCountForMonth(', start);
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    final fn = provider.substring(start, end);
    expect(fn.contains('members.where((m) => paidIds.contains(m.id)).length'),
        isTrue);
    expect(fn.contains('.toSet()\n        .length'), isFalse,
        reason: '탈퇴·게스트 납부까지 분자에 넣으면 2/1·200%가 된다');
  });

  test('납부기준일 1일전 알림톡 안내와 내역추가 기본값이 있다', () {
    expect(finance.contains('DuesD1Schedule.noticeText'), isTrue);
    expect(
      File('lib/utils/dues_d1_schedule.dart').readAsStringSync().contains(
          '납부기준일 1일전 회원들에게 알림톡이 발송됩니다'),
      isTrue,
    );
    expect(finance.contains("kind == DuesType.annual ? '연회비' : '월회비'"), isTrue);
    expect(finance.contains("'후원'"), isTrue);
    expect(finance.contains("'경비'"), isTrue);
    expect(finance.contains('저장하고 계속 입력'), isTrue);
    expect(finance.contains('TreasurerTxPromptScreen'), isTrue);
    expect(finance.contains('_showTxPrompt'), isTrue);
    final addBlock = provider.substring(
      provider.indexOf('void addDuesSetting'),
      provider.indexOf('void sendDuesNudge'),
    );
    expect(addBlock.contains('_dispatchClubAlimtalk'), isFalse);
    expect(addBlock.contains('syncDuesD1Reminders'), isTrue);
  });
}
