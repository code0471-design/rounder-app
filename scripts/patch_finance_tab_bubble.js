/**
 * Finance: show red speech bubble on first tabs pointing to 회비설정.
 */
const fs = require('fs');
const path = require('path');

const file = path.join(__dirname, '..', 'lib', 'screens', 'finance', 'finance_screen.dart');
let src = fs.readFileSync(file, 'utf8');

const oldInit = `  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    // 신규 모임에 생성자 회원이 빠진 경우 복구
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<ClubProvider>();
      if (p.ensureCreatorMembers()) p.notifyListeners();
    });
  }`;

const newInit = `  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _tab.addListener(() {
      if (mounted && !_tab.indexIsChanging) setState(() {});
    });
    // 신규 모임에 생성자 회원이 빠진 경우 복구
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<ClubProvider>();
      if (p.ensureCreatorMembers()) p.notifyListeners();
    });
  }`;

if (!src.includes(oldInit)) {
  if (src.includes('_tab.addListener')) {
    console.log('initState already patched');
  } else {
    console.error('FAIL: initState block not found');
    process.exit(1);
  }
} else {
  src = src.replace(oldInit, newInit);
}

const oldBuild = `        // 재무 관리(설정·초기세팅·수정)는 총무만 — Case B/C
        final isAdmin = isTreasurer;
        final now = DateTime.now();

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              // ── 상단 잔고 요약 ──
              _BalanceSummaryCard(
                balance: provider.totalBalance,
                income: provider.monthlyIncome(now.year, now.month),
                expense: provider.monthlyExpense(now.year, now.month),
              ),
              // ── 총무 최초 진입 가이드 ──
              if (isTreasurer && provider.isFinanceSetupPending)
                const _TreasurerFirstVisitGuideBanner(),
              // ── 초기잔액 등록됐지만 회비 설정이 없을 때 ──
              if (isTreasurer &&
                  !provider.isFinanceEmpty &&
                  provider.hasOpeningBalance &&
                  provider.activeDuesSettings.isEmpty)
                const _SetupDuesHintBanner(),
              // ── 탭바 ──
              Container(
                color: AppColors.cream,
                child: TabBar(
                  controller: _tab,
                  labelColor: AppColors.sageDeep,
                  unselectedLabelColor: AppColors.inkSoft,
                  indicatorColor: AppColors.sageDeep,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: '납부현황'),
                    Tab(text: '수입/지출'),
                    Tab(text: '결산보고'),
                    Tab(text: '회비설정'),
                  ],
                ),
              ),
              // ── 탭 컨텐츠 ──
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _PaymentStatusTab(isAdmin: isAdmin),
                    _TransactionTab(isAdmin: isAdmin),
                    _SettlementReportTab(isAdmin: isAdmin),
                    _DuesSettingTab(isAdmin: isAdmin),
                  ],
                ),
              ),
            ],
          ),
        );`;

const newBuild = `        // 재무 관리(설정·초기세팅·수정)는 총무만 — Case B/C
        final isAdmin = isTreasurer;
        final now = DateTime.now();
        // 총무 최초: 회비설정 탭을 가리키는 말풍선 (회비설정 탭 안에서는 FAB 말풍선만)
        final showTabGuideBubble =
            isTreasurer && provider.isFinanceSetupPending && _tab.index != 3;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  // ── 상단 잔고 요약 ──
                  _BalanceSummaryCard(
                    balance: provider.totalBalance,
                    income: provider.monthlyIncome(now.year, now.month),
                    expense: provider.monthlyExpense(now.year, now.month),
                  ),
                  // ── 총무 최초 진입 가이드 ──
                  if (isTreasurer && provider.isFinanceSetupPending)
                    const _TreasurerFirstVisitGuideBanner(),
                  // ── 초기잔액 등록됐지만 회비 설정이 없을 때 ──
                  if (isTreasurer &&
                      !provider.isFinanceEmpty &&
                      provider.hasOpeningBalance &&
                      provider.activeDuesSettings.isEmpty)
                    const _SetupDuesHintBanner(),
                  // ── 탭바 ──
                  Container(
                    color: AppColors.cream,
                    child: TabBar(
                      controller: _tab,
                      labelColor: AppColors.sageDeep,
                      unselectedLabelColor: AppColors.inkSoft,
                      indicatorColor: AppColors.sageDeep,
                      indicatorWeight: 2.5,
                      labelStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      tabs: const [
                        Tab(text: '납부현황'),
                        Tab(text: '수입/지출'),
                        Tab(text: '결산보고'),
                        Tab(text: '회비설정'),
                      ],
                    ),
                  ),
                  // ── 탭 컨텐츠 ──
                  Expanded(
                    child: TabBarView(
                      controller: _tab,
                      children: [
                        _PaymentStatusTab(isAdmin: isAdmin),
                        _TransactionTab(isAdmin: isAdmin),
                        _SettlementReportTab(isAdmin: isAdmin),
                        _DuesSettingTab(isAdmin: isAdmin),
                      ],
                    ),
                  ),
                ],
              ),
              // 총무 + 회비 미설정 → 회비설정 탭을 가리키는 말풍선 (첫 페이지 포함)
              if (showTabGuideBubble)
                Positioned(
                  right: 10,
                  top: 118,
                  child: _DuesSetupSpeechBubble(
                    label: '회비설정에서 시작하세요',
                    tailUp: true,
                    onTap: () => _tab.animateTo(3),
                  ),
                ),
            ],
          ),
        );`;

if (!src.includes(oldBuild)) {
  if (src.includes('showTabGuideBubble')) {
    console.log('build already patched');
  } else {
    console.error('FAIL: finance build block not found');
    process.exit(1);
  }
} else {
  src = src.replace(oldBuild, newBuild);
}

fs.writeFileSync(file, src, 'utf8');
console.log('OK: finance tab guide bubble');
