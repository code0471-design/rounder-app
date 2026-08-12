const fs = require('fs');
const path = require('path');
const file = path.join(__dirname, '..', 'lib/screens/finance/finance_screen.dart');
let src = fs.readFileSync(file, 'utf8');

const old = `        return Scaffold(
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

const neu = `        return Scaffold(
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
              // ── 탭바 (+ 회비설정 안내 말풍선) ──
              Container(
                color: AppColors.cream,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    TabBar(
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
                    if (showTabGuideBubble)
                      Positioned(
                        right: 6,
                        top: 44,
                        child: _DuesSetupSpeechBubble(
                          label: '회비설정에서 시작하세요',
                          tailUp: true,
                          onTap: () => _tab.animateTo(3),
                        ),
                      ),
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

if (!src.includes(old)) {
  console.error('FAIL: scaffold block not found');
  process.exit(1);
}
fs.writeFileSync(file, src.replace(old, neu), 'utf8');
console.log('OK bubble position under tab bar');
