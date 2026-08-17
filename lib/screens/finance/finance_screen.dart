import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/club_model.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';
import 'dues_payment_screen.dart';

// ════════════════════════════════════════════════════════════
//  숫자 포맷 헬퍼
// ════════════════════════════════════════════════════════════
String _fmt(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// 부호 포함 포맷 (마이너스 잔고 표시용)
String _fmtSigned(int n) {
  if (n < 0) return '-${_fmt(n)}';
  return _fmt(n);
}

// ════════════════════════════════════════════════════════════
//  FinanceScreen — 재무 탭
// ════════════════════════════════════════════════════════════
class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
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
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        // 게스트 회원은 재무 탭 열람 권한이 없음 (홈 하단 탭바에서 이미 차단되지만,
        // 다른 경로로 직접 진입하는 경우를 대비한 이중 방어)
        if (provider.isGuestMember) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_outline,
                          color: AppColors.danger, size: 30),
                    ),
                    const SizedBox(height: 16),
                    const Text('게스트 회원은 권한이 없습니다.',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    const Text(
                      '재무 정보는 정회원 이상만 열람할 수 있어요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // 회비 미설정: 총무만 진입 가능 (방장·정회원 포함 차단) — Case A
        final isTreasurer = provider.isTreasurer;
        if (!isTreasurer && provider.isFinanceSetupPending) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: _FinanceSetupPendingView(),
          );
        }

        // 재무 관리(설정·초기세팅·수정)는 총무만 — Case B/C
        final isAdmin = isTreasurer;
        final now = DateTime.now();
        // 총무 최초: 회비설정 탭을 가리키는 말풍선 (회비설정 탭 안에서는 FAB 말풍선만)
        final showTabGuideBubble =
            isTreasurer && provider.isFinanceSetupPending && _tab.index != 3;

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
                      indicatorSize: TabBarIndicatorSize.label,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      labelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.2),
                      unselectedLabelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.2),
                      tabs: const [
                        Tab(height: 46, child: _FinanceTabLabel('납부현황')),
                        Tab(height: 46, child: _FinanceTabLabel('수입/지출')),
                        Tab(height: 46, child: _FinanceTabLabel('결산보고')),
                        Tab(height: 46, child: _FinanceTabLabel('회비설정')),
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
        );
      },
    );
  }
}

class _FinanceTabLabel extends StatelessWidget {
  final String text;
  const _FinanceTabLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, softWrap: false),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  상단 잔고 요약 카드
// ════════════════════════════════════════════════════════════
class _BalanceSummaryCard extends StatelessWidget {
  final int balance;
  final int income;
  final int expense;

  const _BalanceSummaryCard({
    required this.balance,
    required this.income,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.sageDeep, AppColors.sageDarker],
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // 장식 원 (우측 상단)
          Positioned(
            right: -30, top: -20,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 라벨
                    Row(children: [
                      Text('현 회비 잔고',
                          style: TextStyle(
                              fontSize: 10, letterSpacing: 0.2 * 10,
                              color: Colors.white.withValues(alpha: 0.7))),
                    ]),
                    // 금액 (큰 숫자)
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(_fmtSigned(balance),
                            style: TextStyle(
                              fontFamily: 'NanumGothic',
                              fontSize: 42, fontWeight: FontWeight.w300,
                              color: balance < 0
                                  ? const Color(0xFFFFCDD2)
                                  : Colors.white,
                              letterSpacing: -0.02 * 42,
                            )),
                        const SizedBox(width: 4),
                        Text('원',
                            style: TextStyle(fontSize: 15,
                                color: Colors.white.withValues(alpha: 0.75))),
                      ],
                    ),
                    // 수입/지출 flow-row
                    const SizedBox(height: 12),
                    Row(children: [
                      _FlowItem(label: '이달 수입', amount: income,
                          valueColor: const Color(0xFFB8D4A5)),
                      const SizedBox(width: 20),
                      _FlowItem(label: '이달 지출', amount: expense,
                          valueColor: const Color(0xFFE8B8B8)),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// fin-hero flow item (수입/지출)
class _FlowItem extends StatelessWidget {
  final String label;
  final int amount;
  final Color valueColor;
  const _FlowItem({required this.label, required this.amount, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label,
          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.65))),
      const SizedBox(width: 6),
      Text(
        '${label.contains('수입') ? '+' : '-'}${_fmt(amount)}원',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: valueColor),
      ),
    ]);
  }
}

// 구 _MiniStat 호환 유지
class _MiniStat extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  const _MiniStat(this.label, this.amount, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      const SizedBox(width: 6),
      Text('${label.contains('수입') ? '+' : '-'}${_fmt(amount)}원',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    ]);
  }
}

// ════════════════════════════════════════════════════════════
//  탭 1 — 납부현황
// ════════════════════════════════════════════════════════════
class _PaymentStatusTab extends StatefulWidget {
  final bool isAdmin;
  const _PaymentStatusTab({required this.isAdmin});

  @override
  State<_PaymentStatusTab> createState() => _PaymentStatusTabState();
}

class _PaymentStatusTabState extends State<_PaymentStatusTab> {
  String? _selectedDuesId;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final settings = provider.activeDuesSettings;
        final currentUserId = provider.currentUserId;
        final pendingCount = provider.pendingRequestCount;

        if (settings.isEmpty) {
          return const Center(
            child: Text('회비 설정이 없습니다.\n회비설정 탭에서 추가해주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }

        // 기본 선택: 첫 번째 활성 설정
        _selectedDuesId ??= settings.first.id;
        final selected = settings.firstWhere((s) => s.id == _selectedDuesId,
            orElse: () => settings.first);

        // 월회비: 월 단위 / 연회비·특별회비: 연 단위
        final isMonthly = selected.type == DuesType.monthly;
        final payments = isMonthly
            ? provider.paymentsOf(selected.id, year: _year, month: _month)
            : provider.paymentsOf(selected.id, year: _year);

        // 월회비는 정회원만 납부 대상 / 연회비·특별회비는 전체 활성 회원
        final members = selected.type == DuesType.monthly
            ? provider.regularMembers
            : provider.activeMembers;
        final paidIds = payments.map((p) => p.memberId).toSet();
        final paidCount = paidIds.length;
        final totalCount = members.length;
        final paidPct =
            totalCount == 0 ? 0.0 : paidCount / totalCount;

        // 기간 범위 밖인지 체크
        final isOutOfRange = isMonthly &&
            !selected.isMonthInPeriod(_month);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            // ── 관리자 전용: 대기 중인 입금 확인 요청 배너 ──
            if (widget.isAdmin && pendingCount > 0)
              GestureDetector(
                onTap: () => _showRequestListSheet(context, provider),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '$pendingCount',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '입금 확인 요청 $pendingCount건',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE65100)),
                            ),
                            const Text(
                              '탭하여 확인하고 납부 처리하세요',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppColors.warning, size: 20),
                    ],
                  ),
                ),
              ),

            // ── 회비 종류 선택 ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: settings.map((s) {
                  final selected2 = s.id == _selectedDuesId;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDuesId = s.id;
                        // 월회비 선택 시 현재 월이 기간 내인지 확인 후 조정
                        if (s.type == DuesType.monthly &&
                            !s.isMonthInPeriod(_month)) {
                          _month = s.startMonth ?? DateTime.now().month;
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected2
                            ? AppColors.primary
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected2
                              ? AppColors.primary
                              : AppColors.divider,
                        ),
                        boxShadow: selected2
                            ? [
                                BoxShadow(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s.type.icon,
                              style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 5),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                s.title,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected2
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                              // 월회비 기간 표시
                              if (s.periodText != null)
                                Text(
                                  s.periodText!,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: selected2
                                        ? Colors.white70
                                        : AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // ── 기간 선택 ──
            if (isMonthly)
              _MonthSelector(
                year: _year,
                month: _month,
                minMonth: selected.startMonth,
                maxMonth: selected.endMonth,
                onChanged: (y, m) => setState(() {
                  _year = y;
                  _month = m;
                }),
              ),
            if (!isMonthly)
              _YearSelector(
                year: _year,
                onChanged: (y) => setState(() => _year = y),
              ),
            const SizedBox(height: 14),

            // ── 납부율 요약 ──
            if (!isOutOfRange)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isMonthly
                              ? '$_year년 $_month월 납부현황'
                              : '$_year년 납부현황',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary),
                        ),
                        Text(
                          '$paidCount / $totalCount명 (${(paidPct * 100).round()}%)',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: paidPct,
                        minHeight: 10,
                        backgroundColor: AppColors.divider,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.mintBright,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${selected.type.icon} ${_fmt(selected.amount)}원/인',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                        const Spacer(),
                        Text(
                          '총 수납액 ${_fmt(paidCount * selected.amount)}원',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            if (isOutOfRange)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined,
                        color: AppColors.warning, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$_month월은 납부 기간(${selected.startMonth ?? 1}월~${selected.endMonth ?? 12}월) 밖입니다.',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 14),

            // ── 회원별 납부 목록 ──
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      children: [
                        if (widget.isAdmin) ...
                          [
                            const Text('납부 O',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.success,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            const Text('/ 미납',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.bold)),
                          ]
                        else
                          const Text('납부 현황',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.bold)),
                        const Spacer(),
                        const Text('회원 목록',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  ...members.map((m) {
                    final paid = paidIds.contains(m.id);
                    // 나의 대기 중인 요청 조회
                    final myRequest = provider.myPendingRequest(
                      memberId: m.id,
                      duesSettingId: selected.id,
                      year: _year,
                      month: isMonthly ? _month : null,
                    );
                    return _MemberPaymentTile(
                      member: m,
                      paid: paid,
                      isAdmin: widget.isAdmin,
                      currentUserId: currentUserId,
                      pendingRequest: myRequest,
                      onToggle: isOutOfRange
                          ? null
                          : () => _showPaymentToggleDialog(
                                context,
                                provider,
                                member: m,
                                paid: paid,
                                setting: selected,
                                year: _year,
                                month: isMonthly ? _month : null,
                              ),
                      onRequestPayment: isOutOfRange
                          ? null
                          : () => _showRequestSheet(
                                context,
                                provider,
                                m,
                                selected,
                                isMonthly ? _month : null,
                                _year,
                              ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── 납부 토글 다이얼로그 (잔고 반영 여부 선택) ──
  void _showPaymentToggleDialog(
    BuildContext context,
    ClubProvider provider, {
    required Member member,
    required bool paid,
    required DuesSetting setting,
    required int year,
    int? month,
  }) {
    // 납부 취소는 바로 처리 (이미 납부된 것을 취소하는 경우는 단순)
    if (paid) {
      provider.cancelPayment(
        member.id, setting.id,
        year: year,
        month: month,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${member.name} 납부 취소 처리했습니다'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // 납부 처리 → 잔고 반영 여부 선택 다이얼로그
    bool skipsBalance = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.mintPale,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.payments_outlined,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${member.name} 납부 처리',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 금액 표시
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        size: 15, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      '${setting.type.label}  ',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Text(
                      '${_fmt(setting.amountForPeriod(year: year, month: month ?? 1))}원',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 체크박스 옵션
              InkWell(
                onTap: () => setDialogState(() => skipsBalance = !skipsBalance),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: skipsBalance,
                          onChanged: (v) =>
                              setDialogState(() => skipsBalance = v ?? false),
                          activeColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '잔고에 반영하지 않기',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '이전 납부 또는 현금 별도 관리 시 선택',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      provider.recordPayment(
                        memberId: member.id,
                        memberName: member.name,
                        duesSettingId: setting.id,
                        amount: setting.amountForPeriod(
                            year: year, month: month ?? 1),
                        year: year,
                        month: month,
                        skipsBalance: skipsBalance,
                      );
                      final msg = skipsBalance
                          ? '${member.name} 납부 처리 (잔고 미반영)'
                          : '${member.name} 납부 완료 처리했습니다';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          backgroundColor: skipsBalance
                              ? AppColors.primary
                              : AppColors.success,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text('납부 처리',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRequestListSheet(
      BuildContext context, ClubProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentRequestListSheet(provider: provider),
    );
  }

  void _showRequestSheet(
    BuildContext context,
    ClubProvider provider,
    Member member,
    DuesSetting setting,
    int? month,
    int year,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RequestPaymentSheet(
        provider: provider,
        member: member,
        setting: setting,
        month: month,
        year: year,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  월 선택기 (납부 기간 제한 표시)
// ════════════════════════════════════════════════════════════
class _MonthSelector extends StatelessWidget {
  final int year;
  final int month;
  final int? minMonth;
  final int? maxMonth;
  final void Function(int y, int m) onChanged;

  const _MonthSelector({
    required this.year,
    required this.month,
    required this.onChanged,
    this.minMonth,
    this.maxMonth,
  });

  @override
  Widget build(BuildContext context) {
    final isOutOfRange = (minMonth != null && month < minMonth!) ||
        (maxMonth != null && month > maxMonth!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.chevron_left,
                    color: AppColors.primary),
                onPressed: () {
                  if (month == 1) {
                    onChanged(year - 1, 12);
                  } else {
                    onChanged(year, month - 1);
                  }
                },
              ),
              Column(
                children: [
                  Text(
                    '$year년 $month월',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isOutOfRange
                            ? AppColors.textSecondary
                            : AppColors.textPrimary),
                  ),
                  if (minMonth != null || maxMonth != null)
                    Text(
                      '납부 기간: ${minMonth ?? 1}월~${maxMonth ?? 12}월',
                      style: TextStyle(
                          fontSize: 9,
                          color: isOutOfRange
                              ? AppColors.warning
                              : AppColors.textSecondary),
                    ),
                ],
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.chevron_right,
                    color: AppColors.primary),
                onPressed: () {
                  if (month == 12) {
                    onChanged(year + 1, 1);
                  } else {
                    onChanged(year, month + 1);
                  }
                },
              ),
            ],
          ),
          // 기간 밖 월 경고
          if (isOutOfRange)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '납부 기간(${minMonth ?? 1}월~${maxMonth ?? 12}월)에 포함되지 않는 달입니다',
                style:
                    const TextStyle(fontSize: 10, color: AppColors.warning),
              ),
            ),
        ],
      ),
    );
  }
}

// 연도 선택기
class _YearSelector extends StatelessWidget {
  final int year;
  final void Function(int y) onChanged;
  const _YearSelector({required this.year, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.chevron_left, color: AppColors.primary),
            onPressed: () => onChanged(year - 1),
          ),
          Text('$year년',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.chevron_right, color: AppColors.primary),
            onPressed: () => onChanged(year + 1),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  회원 납부 타일 — 역할별 3분기 UI
//  관리자: 납부✓/미납 직접 토글
//  본인(일반): 입금확인요청 버튼 / 대기중 취소
//  타인(일반): 납부/미납 상태 텍스트만
// ════════════════════════════════════════════════════════════
class _MemberPaymentTile extends StatelessWidget {
  final Member member;
  final bool paid;
  final bool isAdmin;
  final String currentUserId;       // 현재 로그인 사용자 ID
  final PaymentRequest? pendingRequest; // 이 회원의 대기 중인 요청 (있으면)
  final VoidCallback? onToggle;     // 관리자용 토글 (null = 기간 외 비활성)
  final VoidCallback? onRequestPayment; // 본인용 요청 (null = 기간 외)

  const _MemberPaymentTile({
    required this.member,
    required this.paid,
    required this.isAdmin,
    required this.currentUserId,
    this.pendingRequest,
    required this.onToggle,
    this.onRequestPayment,
  });

  // currentUserId (provider) == member.id 로 본인 확인
  bool get _isSelf => member.id == currentUserId;

  @override
  Widget build(BuildContext context) {
    // 아바타 색상: 납부 완료 → 초록, 대기 중 → 주황, 미납 → 빨강
    Color avatarBg;
    Color avatarFg;
    if (paid) {
      avatarBg = AppColors.success.withValues(alpha: 0.15);
      avatarFg = AppColors.success;
    } else if (pendingRequest != null) {
      avatarBg = AppColors.warning.withValues(alpha: 0.15);
      avatarFg = AppColors.warning;
    } else {
      avatarBg = AppColors.danger.withValues(alpha: 0.1);
      avatarFg = AppColors.danger;
    }

    // 대기 중 상태(본인)는 트레일링이 2줄이라 dense 높이로는 부족해 오버플로 발생
    final needsExtraHeight = _isSelf && !paid && pendingRequest != null;
    return ListTile(
      dense: !needsExtraHeight,
      contentPadding: needsExtraHeight
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 6)
          : null,
      onTap: isAdmin ? onToggle : null,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: avatarBg,
        child: Text(
          member.name[0],
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: avatarFg,
          ),
        ),
      ),
      title: Text(member.name,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      subtitle: Text(member.role,
          style:
              const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      trailing: _buildTrailing(context),
    );
  }

  Widget _buildTrailing(BuildContext context) {
    // ── 관리자: 납부✓/미납 직접 토글 ──
    if (isAdmin) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: paid
                  ? AppColors.success.withValues(alpha: 0.12)
                  : AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: paid
                    ? AppColors.success.withValues(alpha: 0.5)
                    : AppColors.danger.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              paid ? '납부 ✓' : '미납',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: paid ? AppColors.success : AppColors.danger,
              ),
            ),
          ),
        ),
      );
    }

    // ── 일반 회원(본인): 입금 확인 요청 버튼 / 대기 중 취소 ──
    if (_isSelf) {
      // 이미 납부 완료된 경우 → 상태 표시
      if (paid) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            '납부 ✓',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.success,
            ),
          ),
        );
      }

      // 대기 중인 요청이 있을 때
      if (pendingRequest != null) {
        return GestureDetector(
          onTap: () {
            // 요청 취소 확인
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: const Text('요청 취소',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                content: const Text(
                  '입금 확인 요청을 취소하시겠습니까?',
                  style: TextStyle(fontSize: 13),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('아니오'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      final provider = context.read<ClubProvider>();
                      provider.cancelPaymentRequest(pendingRequest!.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('요청이 취소되었습니다'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('취소'),
                  ),
                ],
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule,
                        size: 12, color: AppColors.warning),
                    SizedBox(width: 4),
                    Text(
                      '대기 중',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                '탭하여 취소',
                style: TextStyle(
                    fontSize: 9, color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      }

      // 미납 + 요청 없음 → 본인에게만 미납 뱃지 + 입금 확인 요청
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.35)),
            ),
            child: const Text(
              '미납',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.danger,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRequestPayment,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.send_outlined,
                      size: 12, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text('입금 확인 요청',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ],
              ),
            ),
          ),
        ],
      );

      // // 미납 + 요청 없음 → "납부하기" 버튼 (직접 결제 or 입금요청 — 숨김)
      // return PopupMenuButton<String>(
      //   padding: EdgeInsets.zero,
      //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      //   onSelected: (val) {
      //     if (val == 'pay') {
      //       // 직접 결제 화면
      //       final provider = context.read<ClubProvider>();
      //       final settings = provider.activeDuesSettings;
      //       if (settings.isNotEmpty) {
      //         Navigator.push(
      //           context,
      //           MaterialPageRoute(
      //             builder: (_) => DuesPaymentScreen(
      //               duesSetting: settings.first,
      //               targetMonth: DateTime.now().month,
      //             ),
      //           ),
      //         );
      //       }
      //     } else if (val == 'request') {
      //       onRequestPayment?.call();
      //     }
      //   },
      //   itemBuilder: (_) => [
      //     const PopupMenuItem(
      //       value: 'pay',
      //       child: Row(
      //         children: [
      //           Icon(Icons.credit_card, size: 16, color: AppColors.primary),
      //           SizedBox(width: 8),
      //           Text('카드/이체 결제', style: TextStyle(fontSize: 13)),
      //         ],
      //       ),
      //     ),
      //     const PopupMenuItem(
      //       value: 'request',
      //       child: Row(
      //         children: [
      //           Icon(Icons.send_outlined, size: 16, color: AppColors.textSecondary),
      //           SizedBox(width: 8),
      //           Text('입금 확인 요청', style: TextStyle(fontSize: 13)),
      //         ],
      //       ),
      //     ),
      //   ],
      //   child: Container(
      //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      //     decoration: BoxDecoration(
      //       color: AppColors.primary.withValues(alpha: 0.1),
      //       borderRadius: BorderRadius.circular(20),
      //       border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      //     ),
      //     child: const Row(
      //       mainAxisSize: MainAxisSize.min,
      //       children: [
      //         Icon(Icons.payment, size: 12, color: AppColors.primary),
      //         SizedBox(width: 4),
      //         Text('납부하기',
      //             style: TextStyle(
      //                 fontSize: 11,
      //                 fontWeight: FontWeight.w600,
      //                 color: AppColors.primary)),
      //       ],
      //     ),
      //   ),
      // );
    }

    // ── 일반 회원(타인): 납부/미납 상태 표시만 ──
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: paid
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        paid ? '납부 ✓' : '미납',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: paid ? AppColors.success : AppColors.danger,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  탭 2 — 수입/지출 내역
// ════════════════════════════════════════════════════════════
class _TransactionTab extends StatefulWidget {
  final bool isAdmin;
  const _TransactionTab({required this.isAdmin});

  @override
  State<_TransactionTab> createState() => _TransactionTabState();
}

class _TransactionTabState extends State<_TransactionTab> {
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final txList = provider.transactionsByMonth(_year, _month);
        final income =
            txList.where((t) => t.type == TxType.income).toList();
        final expense =
            txList.where((t) => t.type == TxType.expense).toList();
        final totalIncome = income.fold(0, (s, t) => s + t.amount);
        final totalExpense = expense.fold(0, (s, t) => s + t.amount);

        return Scaffold(
          backgroundColor: AppColors.background,
          floatingActionButton: widget.isAdmin
              ? FloatingActionButton.extended(
                  onPressed: () =>
                      _showAddTransactionSheet(context, provider),
                  backgroundColor: AppColors.mintBright,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('내역 추가',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                )
              : null,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // 월 선택
              _MonthSelector(
                year: _year,
                month: _month,
                onChanged: (y, m) => setState(() {
                  _year = y;
                  _month = m;
                }),
              ),
              const SizedBox(height: 14),

              // 월 요약
              Row(
                children: [
                  Expanded(
                    child: _TxSummaryCard(
                      label: '수입',
                      amount: totalIncome,
                      color: AppColors.success,
                      icon: Icons.arrow_upward,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TxSummaryCard(
                      label: '지출',
                      amount: totalExpense,
                      color: AppColors.danger,
                      icon: Icons.arrow_downward,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TxSummaryCard(
                      label: '변동액',
                      amount: totalIncome - totalExpense,
                      color: AppColors.primary,
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (txList.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('이달 내역이 없습니다',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),

              // 수입 내역
              if (income.isNotEmpty) ...[
                _TxSectionHeader(
                    '수입', totalIncome, AppColors.success),
                const SizedBox(height: 6),
                ...income.map((t) => _TxTile(tx: t)),
                const SizedBox(height: 14),
              ],

              // 지출 내역
              if (expense.isNotEmpty) ...[
                _TxSectionHeader(
                    '지출', totalExpense, AppColors.danger),
                const SizedBox(height: 6),
                ...expense.map((t) => _TxTile(tx: t)),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showAddTransactionSheet(
      BuildContext context, ClubProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransactionFormSheet(
          provider: provider, defaultYear: _year, defaultMonth: _month),
    );
  }
}

class _TxSummaryCard extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final IconData icon;
  const _TxSummaryCard(
      {required this.label,
      required this.amount,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _fmtSigned(amount),
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: amount < 0
                    ? AppColors.danger
                    : AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _TxSectionHeader extends StatelessWidget {
  final String label;
  final int total;
  final Color color;
  const _TxSectionHeader(this.label, this.total, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color)),
        const Spacer(),
        Text('합계 ${_fmt(total)}원',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ── 거래 타일 (소스 배지 포함) ──
class _TxTile extends StatelessWidget {
  final Transaction tx;
  const _TxTile({required this.tx});

  static const _categoryIcons = {
    '월회비': '📅',
    '연회비': '📆',
    '특별회비': '⭐',
    '이월잔액': '🔄',
    '초기잔액': '💰',   // 신규 모임 온보딩 초기 잔액
    '벌금': '⚡',
    '식비': '🍽️',
    '상품': '🏆',
    '운영비': '📁',
    '기타': '📌',
  };

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.type == TxType.income;
    final color = isIncome ? AppColors.success : AppColors.danger;
    final icon = _categoryIcons[tx.category] ?? '📌';

    // 소스 배지
    Color? badgeColor;
    String? badgeText;
    Color? badgeTextColor;
    if (tx.source == TxSource.dues) {
      badgeColor = AppColors.primary.withValues(alpha: 0.12);
      badgeText = '회비자동';
      badgeTextColor = AppColors.primary;
    } else if (tx.source == TxSource.carryover) {
      badgeColor = Colors.amber.withValues(alpha: 0.18);
      badgeText = '이월';
      badgeTextColor = Colors.amber.shade700;
    } else if (tx.source == TxSource.openingBalance) {
      badgeColor = AppColors.success.withValues(alpha: 0.12);
      badgeText = '초기잔액';
      badgeTextColor = AppColors.success;
    // } else if (tx.source == TxSource.ad) {
    //   badgeColor = Colors.orange.withValues(alpha: 0.15);
    //   badgeText = '광고자동';
    //   badgeTextColor = Colors.orange.shade700;
    // } else if (tx.source == TxSource.sponsor) {
    //   badgeColor = Colors.indigo.withValues(alpha: 0.12);
    //   badgeText = '후원자동';
    //   badgeTextColor = Colors.indigo;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Row(
                  children: [
                    Text(
                      '${tx.date.month}/${tx.date.day} · ${tx.category}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary),
                    ),
                    if (badgeText != null) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: badgeTextColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'}${_fmt(tx.amount)}원',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  탭 3 — 회비 설정
// ════════════════════════════════════════════════════════════
class _DuesSettingTab extends StatelessWidget {
  final bool isAdmin;
  const _DuesSettingTab({required this.isAdmin});

  void _guardTreasurerSetup(BuildContext context, VoidCallback onAllowed) {
    final provider = context.read<ClubProvider>();
    if (provider.isTreasurer) {
      onAllowed();
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.danger, size: 20),
            SizedBox(width: 8),
            Text('권한 없음',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text('초기 세팅은 총무만 가능합니다',
            style: TextStyle(fontSize: 14, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final settings = provider.allDuesSettings;
        final activeSettings = settings.where((s) => s.isActive).toList();
        final isTreasurer = provider.isTreasurer;
        final showDuesBubble = isTreasurer && activeSettings.isEmpty;

        return Scaffold(
          backgroundColor: AppColors.background,
          floatingActionButton: FloatingActionButton.extended(
                  onPressed: () => _guardTreasurerSetup(
                    context,
                    () => _showAddDuesSheet(context, provider),
                  ),
                  backgroundColor: isTreasurer
                      ? AppColors.mintBright
                      : AppColors.textTertiary,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('회비 추가',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
          body: Stack(
            children: [
              ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              if (!isTreasurer)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 14, color: AppColors.primary),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text('회비 설정·초기 세팅은 총무만 가능합니다',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),
              if (!isTreasurer) const SizedBox(height: 12),

              // ── 기존 잔액 등록 (총무 전용 UI, 비총무는 탭 시 경고) ──
              if (isAdmin) ...[
                _OpeningBalanceSettingCard(provider: provider),
                const SizedBox(height: 20),
              ] else ...[
                GestureDetector(
                  onTap: () => _guardTreasurerSetup(context, () {}),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_outline,
                            size: 18, color: AppColors.textSecondary),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text('초기 잔고·회비 세팅은 총무만 가능합니다',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 활성 회비
              const _SettingSectionLabel('활성 회비'),
              const SizedBox(height: 8),
              if (activeSettings.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.sageDeep.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.payments_outlined,
                          size: 32, color: AppColors.sageDeep),
                      SizedBox(height: 10),
                      Text(
                        '아직 설정된 회비가 없어요',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '아래 버튼으로 월회비·연회비를 추가하세요',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              for (final s in activeSettings)
                _DuesSettingCard(
                  setting: s,
                  isAdmin: isAdmin,
                  onDeactivate: () => provider.deactivateDuesSetting(s.id),
                  onDelete:
                      isAdmin ? () => provider.deleteDuesSetting(s.id) : null,
                  onEdit: isAdmin
                      ? () => _showEditDuesSheet(context, provider, s)
                      : null,
                ),

              if (settings.any((s) => !s.isActive)) ...[
                const SizedBox(height: 16),
                const _SettingSectionLabel('종료된 회비'),
                const SizedBox(height: 8),
                ...settings
                    .where((s) => !s.isActive)
                    .map((s) => _DuesSettingCard(
                          setting: s,
                          isAdmin: isAdmin,
                          onDeactivate: () {},
                          onDelete: isAdmin
                              ? () => provider.deleteDuesSetting(s.id)
                              : null,
                          // 종료된 회비는 수정 불가 (재활성화 대신 새로 추가)
                          onEdit: null,
                        )),
              ],
            ],
          ),
              // 총무 + 회비 미설정 → FAB를 가리키는 말풍선
              if (showDuesBubble)
                Positioned(
                  right: 12,
                  bottom: 72, // FAB 바로 위
                  child: _DuesSetupSpeechBubble(
                    onTap: () => _showAddDuesSheet(context, provider),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAddDuesSheet(BuildContext context, ClubProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DuesSettingFormSheet(provider: provider),
    );
  }

  void _showEditDuesSheet(
      BuildContext context, ClubProvider provider, DuesSetting target) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _DuesSettingFormSheet(provider: provider, editTarget: target),
    );
  }
}

/// 회비 미설정 안내 말풍선 (레드) — 탭/FAB 공용
class _DuesSetupSpeechBubble extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final bool tailUp;
  const _DuesSetupSpeechBubble({
    required this.onTap,
    this.label = '회비를 설정하세요',
    this.tailUp = false,
  });

  static const _bubbleColor = AppColors.danger;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _bubbleColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _bubbleColor.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.campaign_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.touch_app_rounded, color: Colors.white70, size: 16),
        ],
      ),
    );

    final tail = Padding(
      padding: const EdgeInsets.only(right: 36),
      child: CustomPaint(
        size: const Size(16, 10),
        painter: _SpeechBubbleTailPainter(
          color: _bubbleColor,
          pointUp: tailUp,
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: tailUp ? [tail, bubble] : [bubble, tail],
        ),
      ),
    );
  }
}

class _SpeechBubbleTailPainter extends CustomPainter {
  final Color color;
  final bool pointUp;
  const _SpeechBubbleTailPainter({
    required this.color,
    this.pointUp = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointUp) {
      path
        ..moveTo(size.width * 0.65, 0)
        ..lineTo(0, size.height)
        ..lineTo(size.width, size.height)
        ..close();
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width * 0.65, size.height)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SpeechBubbleTailPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pointUp != pointUp;
}

class _SettingSectionLabel extends StatelessWidget {
  final String label;
  const _SettingSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary));
  }
}

class _DuesSettingCard extends StatelessWidget {
  final DuesSetting setting;
  final bool isAdmin;
  final VoidCallback onDeactivate;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  const _DuesSettingCard({
    required this.setting,
    required this.isAdmin,
    required this.onDeactivate,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final active = setting.isActive;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: active ? Colors.white : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
        border: active
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.2))
            : null,
        boxShadow: active
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ]
            : [],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.divider,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(setting.type.icon,
                  style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        setting.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: active
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.divider,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        setting.type.label,
                        style: TextStyle(
                          fontSize: 10,
                          color: active
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${_fmt(setting.amount)}원',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: active
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                    // 월회비 기간 뱃지
                    if (setting.periodText != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.green.withValues(alpha: 0.1)
                              : AppColors.divider,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '📅 ${setting.periodText}',
                          style: TextStyle(
                            fontSize: 10,
                            color: active
                                ? Colors.green.shade700
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (setting.dueBasisText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '납부 기준 ${setting.dueBasisText}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? AppColors.inkSoft
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
                if (setting.description != null &&
                    setting.description!.isNotEmpty)
                  Text(
                    setting.description!,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (isAdmin && active)
            IconButton(
              icon: const Icon(Icons.more_vert,
                  color: AppColors.textSecondary, size: 20),
              onPressed: () => _showMenu(context),
            ),
          if (!active)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text('종료',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 드래그 핸들
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 4),
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      setting.type.icon,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          setting.title,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary),
                        ),
                        Text(
                          '${setting.type.label} · ${_fmt(setting.amount)}원',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.divider),
            // 수정
            if (onEdit != null)
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit_outlined,
                      color: AppColors.primary, size: 18),
                ),
                title: const Text('회비 수정',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                subtitle: const Text('제목·금액·기간을 변경합니다',
                    style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  onEdit!();
                },
              ),
            // 삭제
            if (onDelete != null)
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_outline,
                      color: AppColors.danger, size: 18),
                ),
                title: const Text('회비 삭제',
                    style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600)),
                subtitle: const Text(
                  '설정 자체를 완전히 삭제합니다\n납부 기록도 함께 삭제됩니다',
                  style: TextStyle(fontSize: 11, height: 1.4),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context);
                },
              ),
            // 회비 종료 — 확인 다이얼로그 포함
            ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.stop_circle_outlined,
                    color: AppColors.warning, size: 18),
              ),
              title: const Text('회비 종료',
                  style: TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600)),
              subtitle: const Text(
                '더 이상 이 회비를 받지 않을 때 사용\n기존 납부 기록은 유지됩니다',
                style: TextStyle(fontSize: 11, height: 1.4),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDeactivate(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 회비 종료 전 확인 다이얼로그
  void _confirmDeactivate(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 22),
            const SizedBox(width: 8),
            const Text('회비 종료',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    setting.title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${setting.type.label} · ${_fmt(setting.amount)}원',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '이 회비를 종료하면 더 이상 납부 현황에\n표시되지 않습니다.\n\n기존 납부 기록과 수입 내역은 그대로 유지됩니다.',
              style: TextStyle(fontSize: 13, height: 1.6),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDeactivate();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('\'${setting.title}\' 회비를 종료했습니다'),
                  backgroundColor: AppColors.textSecondary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('종료 확인'),
          ),
        ],
      ),
    );
  }

  /// 회비 삭제 전 확인 다이얼로그
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded,
                color: AppColors.danger, size: 22),
            const SizedBox(width: 8),
            const Text('회비 삭제',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    setting.title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${setting.type.label} · ${_fmt(setting.amount)}원',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_rounded,
                      size: 14, color: Color(0xFF856404)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '이 작업은 되돌릴 수 없습니다.\n회비 설정과 연결된 납부 기록이 모두 삭제됩니다.',
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Color(0xFF856404)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete?.call();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('\'${setting.title}\' 회비를 삭제했습니다'),
                  backgroundColor: AppColors.danger,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('삭제 확인'),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  거래 내역 추가 폼
// ════════════════════════════════════════════════════════════
class _TransactionFormSheet extends StatefulWidget {
  final ClubProvider provider;
  final int defaultYear;
  final int defaultMonth;
  const _TransactionFormSheet({
    required this.provider,
    required this.defaultYear,
    required this.defaultMonth,
  });

  @override
  State<_TransactionFormSheet> createState() =>
      _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<_TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  TxType _type = TxType.income;
  String _category = '월회비';
  DateTime _date = DateTime.now();

  static const _incomeCategories = ['월회비', '연회비', '특별회비', '벌금', '기타'];
  static const _expenseCategories = ['식비', '상품', '운영비', '기타'];

  List<String> get _categories =>
      _type == TxType.income ? _incomeCategories : _expenseCategories;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // 헤더
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: AppColors.divider))),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Text('내역 추가',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('취소'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // 수입/지출 토글
                    Row(
                      children: [
                        _TypeBtn('수입', TxType.income, _type, (v) {
                          setState(() {
                            _type = v;
                            _category = _categories.first;
                          });
                        }),
                        const SizedBox(width: 10),
                        _TypeBtn('지출', TxType.expense, _type, (v) {
                          setState(() {
                            _type = v;
                            _category = _categories.first;
                          });
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 카테고리
                    const Text('카테고리',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((c) {
                        final sel = c == _category;
                        return GestureDetector(
                          onTap: () => setState(() => _category = c),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.primary
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: sel
                                    ? AppColors.primary
                                    : AppColors.divider,
                              ),
                            ),
                            child: Text(c,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sel
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                )),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // 제목
                    const Text('제목 *',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: _deco('예: 6월 월회비 수납'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? '제목을 입력하세요' : null,
                    ),
                    const SizedBox(height: 16),

                    // 금액
                    const Text('금액 (원) *',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _deco('예: 300000'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return '금액을 입력하세요';
                        if (int.tryParse(v.trim()) == null) return '숫자만 입력하세요';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 날짜
                    const Text('날짜',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xFFDDDDDD)),
                          borderRadius: BorderRadius.circular(10),
                          color: const Color(0xFFF8F8F8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_outlined,
                                size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              '${_date.year}년 ${_date.month}월 ${_date.day}일',
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 메모
                    const Text('메모 (선택)',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _memoCtrl,
                      decoration: _deco('추가 메모'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 28),

                    // 등록 / 계속 입력
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: () => _save(keepOpen: true),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(
                                    color: AppColors.primary, width: 1.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('계속 입력',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () => _save(keepOpen: false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('등록',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save({required bool keepOpen}) {
    if (!_formKey.currentState!.validate()) return;
    final tx = Transaction(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      type: _type,
      amount: int.parse(_amountCtrl.text.trim()),
      category: _category,
      title: _titleCtrl.text.trim(),
      memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
      date: _date,
      recordedBy: widget.provider.currentUserName,
      source: TxSource.manual,
    );
    widget.provider.addTransaction(tx);

    if (keepOpen) {
      // 같은 시트에서 이어서 입력 — 제목/금액/메모만 초기화
      _titleCtrl.clear();
      _amountCtrl.clear();
      _memoCtrl.clear();
      _formKey.currentState!.reset();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('등록됨 (${_fmt(tx.amount)}원) · 이어서 입력하세요'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('내역이 등록되었습니다 (${_fmt(tx.amount)}원)'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            color: AppColors.textSecondary, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final TxType value;
  final TxType groupValue;
  final ValueChanged<TxType> onTap;
  const _TypeBtn(this.label, this.value, this.groupValue, this.onTap);

  @override
  Widget build(BuildContext context) {
    final sel = value == groupValue;
    final color =
        value == TxType.income ? AppColors.success : AppColors.danger;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? color : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: sel ? color : AppColors.divider, width: 1.5),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: sel ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 회비 유형 선택 박스 노출 순서: 연회비 → 월회비 → 특별회비
const List<DuesType> _duesTypeOrder = [
  DuesType.annual,
  DuesType.monthly,
  DuesType.special,
];

/// 연회비/월회비 기간 선택 시 노출할 연도 범위
final List<int> _duesYearOptions =
    List.generate(2040 - 2025 + 1, (i) => 2025 + i);

// ════════════════════════════════════════════════════════════
//  회비 설정 추가 폼 (월회비 기간 선택 포함)
// ════════════════════════════════════════════════════════════
class _DuesSettingFormSheet extends StatefulWidget {
  final ClubProvider provider;
  final DuesSetting? editTarget; // null = 추가 모드, non-null = 수정 모드
  const _DuesSettingFormSheet({required this.provider, this.editTarget});

  @override
  State<_DuesSettingFormSheet> createState() =>
      _DuesSettingFormSheetState();
}

class _DuesSettingFormSheetState extends State<_DuesSettingFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DuesType _type = DuesType.monthly;
  int? _startMonth = 3;
  int? _endMonth = 11;
  int? _startYear = DateTime.now().year;
  int? _endYear = DateTime.now().year;
  /// 월회비: 종료 연월 없이 시작 이후 계속
  bool _noEndDate = false;
  int? _annualYear;
  /// 연회비·특별회비 납부 기준일
  DateTime? _dueDate;
  /// 월회비 매월 납부 기준일 (1~31)
  int? _dueDayOfMonth = 25;

  bool get _isEditMode => widget.editTarget != null;

  String get _titleHint {
    final y = DateTime.now().year;
    switch (_type) {
      case DuesType.annual:
        return '예: $y년 연회비';
      case DuesType.monthly:
        return '예: $y년 월회비';
      case DuesType.special:
        return '예: $y년 여행 특별회비';
    }
  }

  @override
  void initState() {
    super.initState();
    // 수정 모드: 기존 값으로 폼 초기화
    if (_isEditMode) {
      final s = widget.editTarget!;
      _titleCtrl.text = s.title;
      _amountCtrl.text = s.amount.toString();
      _descCtrl.text = s.description ?? '';
      _type = s.type;
      _startMonth = s.startMonth ?? 1;
      _startYear = s.startYear ?? s.createdAt.year;
      _noEndDate = s.type == DuesType.monthly &&
          s.endYear == null &&
          s.endMonth == null;
      if (_noEndDate) {
        _endMonth = null;
        _endYear = null;
      } else {
        _endMonth = s.endMonth ?? 12;
        _endYear = s.endYear ?? _startYear;
      }
      _annualYear = s.year ?? (s.type == DuesType.annual ? s.createdAt.year : null);
      _dueDate = s.dueDate;
      _dueDayOfMonth = s.dueDayOfMonth ??
          (s.type == DuesType.monthly ? 25 : null);
    } else {
      _annualYear = DateTime.now().year;
      _dueDayOfMonth = 25;
      _dueDate = DateTime(DateTime.now().year, 3, 1);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: AppColors.divider))),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          _isEditMode ? '회비 수정' : '회비 추가',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('취소'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // 회비 유형
                    const Text('회비 유형',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Row(
                      children: _duesTypeOrder.map((t) {
                        final sel = t == _type;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _type = t;
                              if (t != DuesType.monthly) {
                                _startMonth = null;
                                _endMonth = null;
                                _startYear = null;
                                _endYear = null;
                                _dueDayOfMonth = null;
                                _dueDate ??= DateTime(
                                  DateTime.now().year,
                                  t == DuesType.annual ? 3 : DateTime.now().month,
                                  1,
                                );
                              } else {
                                _startMonth = 3;
                                _startYear ??= DateTime.now().year;
                                if (_noEndDate) {
                                  _endMonth = null;
                                  _endYear = null;
                                } else {
                                  _endMonth = 11;
                                  _endYear ??= DateTime.now().year;
                                }
                                _dueDayOfMonth ??= 25;
                                _dueDate = null;
                              }
                              if (t == DuesType.annual) {
                                _annualYear ??= DateTime.now().year;
                              } else {
                                _annualYear = null;
                              }
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: EdgeInsets.only(
                                  right: t != DuesType.special ? 8 : 0),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppColors.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: sel
                                        ? AppColors.primary
                                        : AppColors.divider,
                                    width: 1.5),
                              ),
                              child: Column(
                                children: [
                                  Text(t.icon,
                                      style: const TextStyle(fontSize: 18)),
                                  const SizedBox(height: 4),
                                  Text(
                                    t.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: sel
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // 제목
                    const Text('회비명 *',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: _deco(_titleHint),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? '회비명을 입력하세요' : null,
                    ),
                    const SizedBox(height: 16),

                    // 금액
                    const Text('금액 (원) *',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _deco('예: 50000'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return '금액을 입력하세요';
                        if (int.tryParse(v.trim()) == null) return '숫자만 입력하세요';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 월회비인 경우 납부 기간 선택
                    if (_type == DuesType.monthly) ...[
                      Row(
                        children: [
                          const Text('납부 기간',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('월회비 전용',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _noEndDate
                            ? '시작 연월부터 종료 없이 계속 청구됩니다'
                            : '납부 시작~종료 연월을 설정하세요 (예: 2025년 3월~2025년 11월)',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _noEndDate,
                        activeColor: AppColors.primary,
                        title: const Text('종료 없이 계속',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: const Text('종료 연월을 두지 않고 시작 이후 계속 납부',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                        onChanged: (v) => setState(() {
                          _noEndDate = v ?? false;
                          if (_noEndDate) {
                            _endYear = null;
                            _endMonth = null;
                          } else {
                            _endYear ??= _startYear ?? DateTime.now().year;
                            _endMonth ??= 12;
                          }
                        }),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _YearMonthField(
                              label: '시작',
                              year: _startYear ?? DateTime.now().year,
                              month: _startMonth ?? 1,
                              onYearChanged: (v) =>
                                  setState(() => _startYear = v),
                              onMonthChanged: (v) =>
                                  setState(() => _startMonth = v),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Text('~',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary)),
                            ),
                          ),
                          Expanded(
                            child: _noEndDate
                                ? Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: AppColors.sageLighter,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.25)),
                                      ),
                                      child: const Text('계속',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary)),
                                    ),
                                  )
                                : _YearMonthField(
                                    label: '종료',
                                    year: _endYear ?? DateTime.now().year,
                                    month: _endMonth ?? 12,
                                    onYearChanged: (v) =>
                                        setState(() => _endYear = v),
                                    onMonthChanged: (v) =>
                                        setState(() => _endMonth = v),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('납부 기준일 *',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text(
                        '매월 몇 일까지 납부해야 하는지 지정하세요',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: _dueDayOfMonth ?? 25,
                        decoration: _deco('매월 ㅇㅇ일'),
                        items: List.generate(
                          31,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text('매월 ${i + 1}일'),
                          ),
                        ),
                        onChanged: (v) =>
                            setState(() => _dueDayOfMonth = v),
                        validator: (v) =>
                            v == null ? '납부 기준일을 선택하세요' : null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 연회비인 경우 청구 연도 선택
                    if (_type == DuesType.annual) ...[
                      const Text('청구 연도',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text(
                        '해당 연회비가 적용되는 연도입니다',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      _YearDropdown(
                        label: '연도',
                        value: _annualYear ?? DateTime.now().year,
                        hint: '${DateTime.now().year}',
                        onChanged: (v) =>
                            setState(() => _annualYear = v),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 연회비·특별회비: 날짜 지정 납부 기준일
                    if (_type == DuesType.annual ||
                        _type == DuesType.special) ...[
                      const Text('납부 기준일 *',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        _type == DuesType.annual
                            ? '연회비 납부 기준 날짜를 지정하세요'
                            : '특별회비 납부 기준 날짜를 지정하세요',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dueDate ?? now,
                            firstDate: DateTime(now.year - 2),
                            lastDate: DateTime(now.year + 5),
                            helpText: '납부 기준일',
                            confirmText: '선택',
                            cancelText: '취소',
                          );
                          if (picked != null) {
                            setState(() => _dueDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: InputDecorator(
                          decoration: _deco('ㅇㅇㅇㅇ년 ㅇㅇ월 ㅇㅇ일').copyWith(
                            suffixIcon: const Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          child: Text(
                            _dueDate == null
                                ? '날짜를 선택하세요'
                                : '${_dueDate!.year}년 ${_dueDate!.month.toString().padLeft(2, '0')}월 ${_dueDate!.day.toString().padLeft(2, '0')}일',
                            style: TextStyle(
                              fontSize: 14,
                              color: _dueDate == null
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              fontWeight: _dueDate == null
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 설명
                    const Text('설명 (선택)',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descCtrl,
                      decoration: _deco('용도 등'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                            _isEditMode ? '수정 완료' : '추가',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    // 월회비 기간 유효성 검사 (종료 있음일 때만 시작 ≤ 종료)
    if (_type == DuesType.monthly &&
        !_noEndDate &&
        ((_startYear ?? DateTime.now().year) * 12 + (_startMonth ?? 1)) >
            ((_endYear ?? DateTime.now().year) * 12 + (_endMonth ?? 12))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('시작 연월은 종료 연월보다 이전이어야 합니다'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_type == DuesType.monthly && _dueDayOfMonth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('월회비 납부 기준일(매월 ㅇㅇ일)을 선택하세요'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if ((_type == DuesType.annual || _type == DuesType.special) &&
        _dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('납부 기준 날짜를 선택하세요'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final desc = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
    final amount = int.parse(_amountCtrl.text.trim());
    final title = _titleCtrl.text.trim();

    if (_isEditMode) {
      // ── 수정 모드: 기존 ID·createdAt 유지, 나머지 갱신
      final original = widget.editTarget!;
      List<DuesAmountChange>? newHistory;
      if (amount != original.amount) {
        // 금액이 바뀌면 오늘부터 적용되는 새 이력을 추가
        // (과거 미납분은 기존 이력의 금액으로 그대로 청구됨)
        final now = DateTime.now();
        newHistory = [
          ...original.amountHistory,
          DuesAmountChange(
            amount: amount,
            effectiveYear: now.year,
            effectiveMonth: now.month,
            changedAt: now,
          ),
        ];
      }
      final monthlyOpenEnded =
          _type == DuesType.monthly && _noEndDate;
      final updated = original.copyWith(
        type: _type,
        amount: amount,
        title: title,
        description: desc,
        startMonth: _type == DuesType.monthly ? _startMonth : null,
        endMonth: monthlyOpenEnded
            ? null
            : (_type == DuesType.monthly ? _endMonth : null),
        startYear: _type == DuesType.monthly ? _startYear : null,
        endYear: monthlyOpenEnded
            ? null
            : (_type == DuesType.monthly ? _endYear : null),
        year: _type == DuesType.annual ? (_annualYear ?? DateTime.now().year) : null,
        dueDayOfMonth: _type == DuesType.monthly ? _dueDayOfMonth : null,
        dueDate: (_type == DuesType.annual || _type == DuesType.special)
            ? _dueDate
            : null,
        amountHistory: newHistory,
        clearStartMonth: _type != DuesType.monthly,
        clearEndMonth: _type != DuesType.monthly || monthlyOpenEnded,
        clearStartYear: _type != DuesType.monthly,
        clearEndYear: _type != DuesType.monthly || monthlyOpenEnded,
        clearYear: _type != DuesType.annual,
        clearDueDayOfMonth: _type != DuesType.monthly,
        clearDueDate: _type == DuesType.monthly,
      );
      widget.provider.updateDuesSetting(updated);
      Navigator.pop(context);
      final msg = newHistory != null
          ? '\'$title\' 회비가 수정되었습니다 (변경 전 미납분은 기존 금액으로 청구돼요)'
          : '\'$title\' 회비가 수정되었습니다';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      // ── 추가 모드
      final now = DateTime.now();
      final monthlyOpenEnded =
          _type == DuesType.monthly && _noEndDate;
      final setting = DuesSetting(
        id: 'ds_${now.millisecondsSinceEpoch}',
        type: _type,
        amount: amount,
        title: title,
        description: desc,
        createdAt: now,
        clubId: widget.provider.selectedClub.id,
        startMonth: _type == DuesType.monthly ? _startMonth : null,
        endMonth: monthlyOpenEnded
            ? null
            : (_type == DuesType.monthly ? _endMonth : null),
        startYear: _type == DuesType.monthly ? _startYear : null,
        endYear: monthlyOpenEnded
            ? null
            : (_type == DuesType.monthly ? _endYear : null),
        year: _type == DuesType.annual ? (_annualYear ?? now.year) : null,
        dueDayOfMonth: _type == DuesType.monthly ? _dueDayOfMonth : null,
        dueDate: (_type == DuesType.annual || _type == DuesType.special)
            ? _dueDate
            : null,
      );
      widget.provider.addDuesSetting(setting);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('\'$title\' 회비가 추가되었습니다'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            color: AppColors.textSecondary, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}

/// 연도+월을 한 필드에서 함께 선택 (예: "2025년 3월")
class _YearMonthField extends StatelessWidget {
  final String label;
  final int year;
  final int month;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int> onMonthChanged;

  const _YearMonthField({
    required this.label,
    required this.year,
    required this.month,
    required this.onYearChanged,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDDDDDD)),
          ),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: year,
                    isExpanded: true,
                    isDense: true,
                    borderRadius: BorderRadius.circular(10),
                    items: _duesYearOptions
                        .map((y) => DropdownMenuItem<int>(
                              value: y,
                              child: Text('$y년',
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onYearChanged(v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: month,
                    isExpanded: true,
                    isDense: true,
                    borderRadius: BorderRadius.circular(10),
                    items: List.generate(12, (i) => i + 1)
                        .map((m) => DropdownMenuItem<int>(
                              value: m,
                              child: Text('$m월',
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onMonthChanged(v);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _YearDropdown extends StatelessWidget {
  final String label;
  final int? value;
  final String hint;
  final ValueChanged<int?> onChanged;
  const _YearDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint = '설정 안함',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDDDDDD)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: value,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              borderRadius: BorderRadius.circular(10),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(hint,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ),
                ..._duesYearOptions.map((y) => DropdownMenuItem<int?>(
                      value: y,
                      child:
                          Text('$y년', style: const TextStyle(fontSize: 13)),
                    )),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
//  입금 확인 요청 바텀시트 (일반 회원 → 관리자에게 요청)
// ════════════════════════════════════════════════════════════
class _RequestPaymentSheet extends StatefulWidget {
  final ClubProvider provider;
  final Member member;
  final DuesSetting setting;
  final int? month;
  final int year;

  const _RequestPaymentSheet({
    required this.provider,
    required this.member,
    required this.setting,
    required this.month,
    required this.year,
  });

  @override
  State<_RequestPaymentSheet> createState() => _RequestPaymentSheetState();
}

class _RequestPaymentSheetState extends State<_RequestPaymentSheet> {
  final _memoCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _memoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final periodText = widget.month != null
        ? '${widget.year}년 ${widget.month}월'
        : '${widget.year}년';

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.85,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ── 헤더 ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: AppColors.divider))),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(Icons.send_outlined,
                              color: AppColors.primary, size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('입금 확인 요청',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold)),
                            Text('총무에게 알림이 발송됩니다',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('취소'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── 내용 ──
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                children: [
                  // 회비 정보 카드
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      children: [
                        _InfoRow('회비명', widget.setting.title),
                        const SizedBox(height: 6),
                        _InfoRow('기간', periodText),
                        const SizedBox(height: 6),
                        _InfoRow('금액',
                            '${_fmt(widget.setting.amountForPeriod(year: widget.year, month: widget.month ?? 1))}원'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 메모 입력
                  const Text('메모 (선택)',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text(
                    '이체 시간, 계좌 마지막 번호 등 확인에 도움이 되는 내용을 남겨주세요',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _memoCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: '예: 방금 이체했습니다. 토스 사용, 오후 2시경',
                      hintStyle: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8F8F8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFFDDDDDD)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFFDDDDDD)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 요청 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _sending ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('요청 전송',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline,
                          size: 12, color: AppColors.textSecondary),
                      SizedBox(width: 4),
                      Text(
                        '총무가 통장을 확인 후 납부 완료 처리합니다',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    setState(() => _sending = true);
    widget.provider.submitPaymentRequest(
      memberId: widget.member.id,
      memberName: widget.member.name,
      duesSettingId: widget.setting.id,
      amount: widget.setting.amountForPeriod(
          year: widget.year, month: widget.month ?? 1),
      year: widget.year,
      month: widget.month,
      memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('입금 확인 요청이 전송되었습니다. 총무가 확인 후 처리합니다.'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// 회비 정보 행 헬퍼
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
//  입금 확인 요청 목록 (관리자 전용 — 승인/반려)
// ════════════════════════════════════════════════════════════
class _PaymentRequestListSheet extends StatelessWidget {
  final ClubProvider provider;
  const _PaymentRequestListSheet({required this.provider});

  @override
  Widget build(BuildContext context) {
    final requests = provider.pendingPaymentRequests;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ── 헤더 ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: AppColors.divider))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(Icons.checklist_rounded,
                              color: AppColors.warning, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('입금 확인 요청',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold)),
                          Text('대기 중 ${requests.length}건',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('닫기'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── 요청 목록 ──
            Expanded(
              child: requests.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 48, color: AppColors.success),
                          SizedBox(height: 12),
                          Text('대기 중인 요청이 없습니다',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: ctrl,
                      padding: const EdgeInsets.all(16),
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemCount: requests.length,
                      itemBuilder: (context, i) {
                        final req = requests[i];
                        return _PaymentRequestCard(
                          request: req,
                          onApprove: () =>
                              _approve(context, req.id, req.memberName),
                          onReject: () =>
                              _reject(context, req.id, req.memberName),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _approve(
      BuildContext context, String requestId, String memberName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('납부 완료 처리',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          '$memberName님의 입금을 확인하고\n납부 완료로 처리하시겠습니까?',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.approvePaymentRequest(requestId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('$memberName님 납부 완료 처리되었습니다'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('납부 완료'),
          ),
        ],
      ),
    );
  }

  void _reject(
      BuildContext context, String requestId, String memberName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('요청 반려',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          '$memberName님의 입금 확인 요청을\n반려하시겠습니까?',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.rejectPaymentRequest(requestId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$memberName님 요청이 반려되었습니다'),
                  backgroundColor: AppColors.danger,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('반려'),
          ),
        ],
      ),
    );
  }
}

// ── 요청 카드 위젯 ──
class _PaymentRequestCard extends StatelessWidget {
  final PaymentRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PaymentRequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final timeAgo = _timeAgo(request.requestedAt);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 요청자 + 시간
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    AppColors.warning.withValues(alpha: 0.15),
                child: Text(
                  request.memberName[0],
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.memberName,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    Text(timeAgo,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('확인 대기',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 10),

          // 회비 정보
          _InfoRow('회비', request.duesTitle),
          const SizedBox(height: 4),
          _InfoRow('기간', request.periodText),
          const SizedBox(height: 4),
          _InfoRow('금액', '${_fmt(request.amount)}원'),

          // 메모
          if (request.memo != null && request.memo!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.chat_bubble_outline,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      request.memo!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // 승인 / 반려 버튼
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(
                        color: AppColors.danger.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('반려',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('납부 완료 처리',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

// ════════════════════════════════════════════════════════════
//  탭 3 — 결산보고 (_SettlementReportTab)
//  월 결산 / 연 결산 보고서를 한눈에 + PDF 다운로드(인쇄) 지원
// ════════════════════════════════════════════════════════════
class _SettlementReportTab extends StatefulWidget {
  final bool isAdmin;
  const _SettlementReportTab({required this.isAdmin});

  @override
  State<_SettlementReportTab> createState() => _SettlementReportTabState();
}

class _SettlementReportTabState extends State<_SettlementReportTab>
    with SingleTickerProviderStateMixin {
  late TabController _inner;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _inner = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _inner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final years = provider.availableYears;
        if (!years.contains(_year)) _year = years.first;

        return Column(
          children: [
            // ── 내부 탭 (월결산 / 연결산) ──
            Container(
              color: const Color(0xFFF8F9FA),
              child: TabBar(
                controller: _inner,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 2,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: '월 결산'),
                  Tab(text: '연 결산'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _inner,
                children: [
                  // ── 월 결산 ──
                  _MonthlyReport(
                    year: _year,
                    month: _month,
                    availableYears: years,
                    provider: provider,
                    onYearChanged: (y) => setState(() => _year = y),
                    onMonthChanged: (m) => setState(() => _month = m),
                  ),
                  // ── 연 결산 ──
                  _YearlyReport(
                    year: _year,
                    availableYears: years,
                    provider: provider,
                    onYearChanged: (y) => setState(() => _year = y),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────
//  월 결산 보고서
// ────────────────────────────────────────────────────────────
class _MonthlyReport extends StatelessWidget {
  final int year, month;
  final List<int> availableYears;
  final ClubProvider provider;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int> onMonthChanged;

  const _MonthlyReport({
    required this.year,
    required this.month,
    required this.availableYears,
    required this.provider,
    required this.onYearChanged,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final txs = provider.transactionsByMonth(year, month);
    final income = provider.monthlyIncome(year, month);
    final expense = provider.monthlyExpense(year, month);
    final net = income - expense;
    // 전월 잔고 / 마감 잔고 (선택 모임 누적 — 상단 현 잔고와 동일 기준)
    final prevBalance = month == 1
        ? provider.balanceAtYearEnd(year - 1)
        : provider.balanceUntil(year: year, month: month - 1);
    final closingBalance = provider.balanceUntil(year: year, month: month);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // ── 기간 선택 ──
        _ReportPeriodSelector(
          year: year,
          month: month,
          availableYears: availableYears,
          onYearChanged: onYearChanged,
          onMonthChanged: onMonthChanged,
        ),
        const SizedBox(height: 16),

        // ── 보고서 헤더 ──
        _ReportHeader(
          title: '$year년 $month월 결산보고',
          subtitle: '${provider.selectedClub.name} · '
              '${DateTime.now().year}년 ${DateTime.now().month}월 ${DateTime.now().day}일 작성',
          icon: Icons.calendar_month_rounded,
          color: AppColors.primary,
        ),
        const SizedBox(height: 14),

        // ── 요약 카드 (3분할) ──
        _SummaryCards(income: income, expense: expense, net: net),
        const SizedBox(height: 14),

        // ── 잔고 흐름 ──
        _BalanceFlowCard(
          label: '$month월',
          opening: prevBalance,
          income: income,
          expense: expense,
          closing: closingBalance,
        ),
        const SizedBox(height: 14),

        // ── 수입 항목별 합계 ──
        if (txs.any((t) => t.type == TxType.income)) ...[
          _CategorySummarySection(
            title: '수입 항목',
            color: AppColors.primaryLight,
            icon: Icons.arrow_downward_rounded,
            items: txs.where((t) => t.type == TxType.income).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // ── 지출 항목별 합계 ──
        if (txs.any((t) => t.type == TxType.expense)) ...[
          _CategorySummarySection(
            title: '지출 항목',
            color: const Color(0xFFC62828),
            icon: Icons.arrow_upward_rounded,
            items: txs.where((t) => t.type == TxType.expense).toList(),
          ),
          const SizedBox(height: 12),
        ],

        if (txs.isEmpty)
          _EmptyReport(label: '$year년 $month월 거래 내역이 없습니다'),

        // ── PDF 다운로드 버튼 ──
        _PdfDownloadButton(
          reportTitle: '$year년 $month월 결산보고',
          onDownload: () => _showPdfDialog(context, '$year년 $month월 결산보고'),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
//  연 결산 보고서
// ────────────────────────────────────────────────────────────
class _YearlyReport extends StatelessWidget {
  final int year;
  final List<int> availableYears;
  final ClubProvider provider;
  final ValueChanged<int> onYearChanged;

  const _YearlyReport({
    required this.year,
    required this.availableYears,
    required this.provider,
    required this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    final income = provider.yearlyIncome(year);
    final expense = provider.yearlyExpense(year);
    final net = income - expense;
    final opening = provider.balanceAtYearEnd(year - 1);
    // 연말 마감 = 해당 연도까지의 누적 잔고 (상단 현 잔고와 동일 기준)
    final closing = provider.balanceAtYearEnd(year);
    final monthly = provider.monthlySummary(year);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // ── 연도 선택 ──
        _YearSelector(
          year: year,
          onChanged: onYearChanged,
        ),
        const SizedBox(height: 16),

        // ── 보고서 헤더 ──
        _ReportHeader(
          title: '$year년 연간 결산보고',
          subtitle: '${provider.selectedClub.name} · '
              '${year}년 1월 1일 ~ 12월 31일',
          icon: Icons.bar_chart_rounded,
          color: const Color(0xFF6A1B9A),
        ),
        const SizedBox(height: 14),

        // ── 연간 요약 ──
        _SummaryCards(income: income, expense: expense, net: net),
        const SizedBox(height: 14),

        // ── 연간 잔고 흐름 ──
        _BalanceFlowCard(
          label: '$year년',
          opening: opening,
          income: income,
          expense: expense,
          closing: closing,
        ),
        const SizedBox(height: 14),

        // ── 수입 항목별 합계 ──
        if (provider.transactionsByYear(year).any((t) => t.type == TxType.income)) ...[
          _CategorySummarySection(
            title: '수입 항목',
            color: AppColors.primaryLight,
            icon: Icons.arrow_downward_rounded,
            items: provider.transactionsByYear(year)
                .where((t) => t.type == TxType.income).toList(),
          ),
          const SizedBox(height: 14),
        ],

        // ── 지출 항목별 합계 ──
        if (provider.transactionsByYear(year).any((t) => t.type == TxType.expense)) ...[
          _CategorySummarySection(
            title: '지출 항목',
            color: const Color(0xFFC62828),
            icon: Icons.arrow_upward_rounded,
            items: provider.transactionsByYear(year)
                .where((t) => t.type == TxType.expense).toList(),
          ),
          const SizedBox(height: 14),
        ],

        // ── 월별 내역 테이블 ──
        if (monthly.isNotEmpty) ...[
          _MonthlyTable(rows: monthly),
          const SizedBox(height: 14),
        ],

        // ── 월별 수지 차트 (바 차트) ──
        if (monthly.isNotEmpty) ...[
          _MonthlyBarChart(rows: monthly),
          const SizedBox(height: 14),
        ],

        if (monthly.isEmpty)
          _EmptyReport(label: '$year년 거래 내역이 없습니다'),

        // ── PDF 다운로드 ──
        _PdfDownloadButton(
          reportTitle: '$year년 연간 결산보고',
          onDownload: () => _showPdfDialog(context, '$year년 연간 결산보고'),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
//  공용 서브 위젯들
// ════════════════════════════════════════════════════════════

// ── 기간 선택기 (월 결산용) ──
class _ReportPeriodSelector extends StatelessWidget {
  final int year, month;
  final List<int> availableYears;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int> onMonthChanged;

  const _ReportPeriodSelector({
    required this.year,
    required this.month,
    required this.availableYears,
    required this.onYearChanged,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 연도 드롭다운
        _DropdownSelector<int>(
          value: year,
          items: availableYears,
          label: (y) => '$y년',
          onChanged: onYearChanged,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        // 월 드롭다운
        _DropdownSelector<int>(
          value: month,
          items: List.generate(12, (i) => i + 1),
          label: (m) => '$m월',
          onChanged: onMonthChanged,
          color: AppColors.primary,
        ),
      ],
    );
  }
}

// ── 드롭다운 공용 ──
class _DropdownSelector<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final Color color;

  const _DropdownSelector({
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color),
          icon: Icon(Icons.expand_more_rounded, color: color, size: 18),
          items: items
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(label(e)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

// ── 보고서 헤더 ──
class _ReportHeader extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;

  const _ReportHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 요약 카드 3분할 ──
class _SummaryCards extends StatelessWidget {
  final int income, expense, net;
  const _SummaryCards(
      {required this.income,
      required this.expense,
      required this.net});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: '총 수입',
            amount: income,
            color: AppColors.primaryLight,
            bgColor: const Color(0xFFE8F5E9),
            icon: Icons.arrow_drop_up_rounded,
            prefix: '+',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: '총 지출',
            amount: expense,
            color: const Color(0xFFC62828),
            bgColor: const Color(0xFFFFEBEE),
            icon: Icons.arrow_drop_down_rounded,
            prefix: '-',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: '변동액',
            amount: net,
            color: net >= 0 ? AppColors.primary : const Color(0xFFE65100),
            bgColor:
                net >= 0 ? const Color(0xFFE3F2FD) : const Color(0xFFFFF3E0),
            icon: Icons.account_balance_wallet_rounded,
            prefix: net > 0 ? '+' : (net < 0 ? '-' : ''),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, prefix;
  final int amount;
  final Color color, bgColor;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.bgColor,
    required this.icon,
    required this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$prefix${_fmt(amount.abs())}',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color),
          ),
          Text('원', style: TextStyle(fontSize: 9, color: color)),
        ],
      ),
    );
  }
}

// ── 잔고 계산 카드 (이전 → 수입/지출 → 마감)
class _BalanceFlowCard extends StatelessWidget {
  final String label;
  final int opening, income, expense, closing;

  const _BalanceFlowCard({
    required this.label,
    required this.opening,
    required this.income,
    required this.expense,
    required this.closing,
  });

  @override
  Widget build(BuildContext context) {
    final closingColor =
        closing >= 0 ? AppColors.primary : const Color(0xFFE65100);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // 이전 잔고
          _CalcRow(
            badge: '시작',
            badgeColor: AppColors.textSecondary,
            label: '$label 이전 잔고',
            amount: opening,
            amountColor: AppColors.textPrimary,
          ),
          const SizedBox(height: 8),
          // 수입 / 지출 박스
          Row(
            children: [
              Expanded(
                child: _CalcChip(
                  sign: '+',
                  label: '수입',
                  amount: income,
                  color: AppColors.primaryLight,
                  bg: const Color(0xFFE8F5E9),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CalcChip(
                  sign: '−',
                  label: '지출',
                  amount: expense,
                  color: const Color(0xFFC62828),
                  bg: const Color(0xFFFFEBEE),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 등호 구분선
          Row(
            children: [
              Expanded(child: Divider(color: closingColor.withValues(alpha: 0.25), thickness: 1.2)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.drag_handle_rounded,
                    size: 16, color: closingColor.withValues(alpha: 0.55)),
              ),
              Expanded(child: Divider(color: closingColor.withValues(alpha: 0.25), thickness: 1.2)),
            ],
          ),
          const SizedBox(height: 10),
          // 마감 잔고 강조
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: closingColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: closingColor.withValues(alpha: 0.28)),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: closingColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('마감',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$label 마감 잔고',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: closingColor),
                  ),
                ),
                Text(
                  '${_fmtSigned(closing)}원',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: closingColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalcRow extends StatelessWidget {
  final String badge, label;
  final Color badgeColor, amountColor;
  final int amount;

  const _CalcRow({
    required this.badge,
    required this.badgeColor,
    required this.label,
    required this.amount,
    required this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(badge,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: badgeColor)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ),
        Text(
          '${_fmtSigned(amount)}원',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: amountColor),
        ),
      ],
    );
  }
}

class _CalcChip extends StatelessWidget {
  final String sign, label;
  final int amount;
  final Color color, bg;

  const _CalcChip({
    required this.sign,
    required this.label,
    required this.amount,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$sign $label',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color)),
          const SizedBox(height: 4),
          Text(
            '${_fmt(amount)}원',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

// ── 거래 섹션 ──
class _TxSection extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final List<Transaction> items;

  const _TxSection({
    required this.title,
    required this.color,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final total = items.fold(0, (s, t) => s + t.amount);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 섹션 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color)),
                const Spacer(),
                Text(
                  '${items.length}건 · ${_fmt(total)}원',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color),
                ),
              ],
            ),
          ),
          // 항목 목록
          ...items.asMap().entries.map((e) {
            final t = e.value;
            final isLast = e.key == items.length - 1;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.title,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary)),
                            Text(
                              '${t.date.month}/${t.date.day} · '
                              '${t.source.label}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${_fmt(t.amount)}원',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: color),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  const Divider(height: 1, indent: 32, endIndent: 16),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  항목별 합계 섹션 (결산보고용) — 카테고리로 묶어 합계 표시
// ────────────────────────────────────────────────────────────
class _CategorySummarySection extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final List<Transaction> items;

  const _CategorySummarySection({
    required this.title,
    required this.color,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    // 카테고리별 합계 계산
    final Map<String, int> grouped = {};
    for (final t in items) {
      grouped[t.category] = (grouped[t.category] ?? 0) + t.amount;
    }
    final total = items.fold(0, (s, t) => s + t.amount);
    // 금액 큰 순으로 정렬
    final entries = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── 섹션 헤더 ──
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const Spacer(),
                Text(
                  '${entries.length}개 항목',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          // ── 카테고리별 행 ──
          ...entries.asMap().entries.map((e) {
            final isLast = e.key == entries.length - 1;
            return Column(
              children: [
                _CategoryRow(
                  label: e.value.key,
                  amount: e.value.value,
                  color: color,
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: color.withValues(alpha: 0.08),
                  ),
              ],
            );
          }),

          // ── 구분선 ──
          Divider(
            height: 1,
            color: color.withValues(alpha: 0.15),
          ),

          // ── 합계 행 ──
          _CategoryRow(
            label: '합  계',
            amount: total,
            color: color,
            isBold: true,
            isTotal: true,
          ),
        ],
      ),
    );
  }
}

// ── 카테고리 행 ──
class _CategoryRow extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final bool isBold;
  final bool isTotal;

  const _CategoryRow({
    required this.label,
    required this.amount,
    required this.color,
    this.isBold = false,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: isTotal
          ? BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
            )
          : null,
      child: Row(
        children: [
          if (!isTotal) ...[
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 13 : 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: isTotal ? color : AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            '${_fmt(amount)}원',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 월별 테이블 (연간용) ──
class _MonthlyTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _MonthlyTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF6A1B9A),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: const Row(
              children: [
                Expanded(
                    flex: 1,
                    child: Text('월',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white))),
                Expanded(
                    flex: 2,
                    child: Text('수입',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white))),
                Expanded(
                    flex: 2,
                    child: Text('지출',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white))),
                Expanded(
                    flex: 2,
                    child: Text('변동액',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white))),
              ],
            ),
          ),
          ...rows.asMap().entries.map((e) {
            final r = e.value;
            final net = r['net'] as int;
            final isEven = e.key % 2 == 0;
            return Container(
              color: isEven ? Colors.white : const Color(0xFFF8F9FA),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 9),
              child: Row(
                children: [
                  Expanded(
                      flex: 1,
                      child: Text('${r['month']}월',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary))),
                  Expanded(
                      flex: 2,
                      child: Text(
                        '+${_fmt(r['income'] as int)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primaryLight),
                      )),
                  Expanded(
                      flex: 2,
                      child: Text(
                        '-${_fmt(r['expense'] as int)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFC62828)),
                      )),
                  Expanded(
                      flex: 2,
                      child: Text(
                        '${net >= 0 ? '+' : ''}${_fmt(net)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: net >= 0
                                ? AppColors.primary
                                : const Color(0xFFE65100)),
                      )),
                ],
              ),
            );
          }),
          // 합계 행
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF6A1B9A).withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Expanded(
                    flex: 1,
                    child: Text('합계',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary))),
                Expanded(
                    flex: 2,
                    child: Text(
                      '+${_fmt(rows.fold<int>(0, (s, r) => s + (r['income'] as int)))}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryLight),
                    )),
                Expanded(
                    flex: 2,
                    child: Text(
                      '-${_fmt(rows.fold<int>(0, (s, r) => s + (r['expense'] as int)))}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFC62828)),
                    )),
                Expanded(
                    flex: 2,
                    child: Builder(builder: (context) {
                      final totNet = rows.fold<int>(
                          0, (s, r) => s + (r['net'] as int));
                      return Text(
                        '${totNet >= 0 ? '+' : ''}${_fmt(totNet)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: totNet >= 0
                                ? AppColors.primary
                                : const Color(0xFFE65100)),
                      );
                    })),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 월별 바 차트 ──
class _MonthlyBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _MonthlyBarChart({required this.rows});

  @override
  Widget build(BuildContext context) {
    final maxVal = rows
        .map((r) => [r['income'] as int, r['expense'] as int])
        .expand((e) => e)
        .fold<int>(0, (m, v) => v > m ? v : m);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('월별 변동액 현황',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          // 범례
          Row(
            children: [
              _Legend(color: AppColors.primaryLight, label: '수입'),
              const SizedBox(width: 12),
              _Legend(color: const Color(0xFFC62828), label: '지출'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: rows.map((r) {
                final inc = r['income'] as int;
                final exp = r['expense'] as int;
                final incH = maxVal > 0 ? (inc / maxVal * 100) : 0.0;
                final expH = maxVal > 0 ? (exp / maxVal * 100) : 0.0;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _Bar(height: incH, color: AppColors.primaryLight),
                          const SizedBox(width: 2),
                          _Bar(height: expH, color: const Color(0xFFC62828)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${r['month']}월',
                          style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double height;
  final Color color;
  const _Bar({required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: height.clamp(2, 100),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 10, height: 10, color: color,
            margin: const EdgeInsets.only(right: 4)),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ── 빈 상태 ──
class _EmptyReport extends StatelessWidget {
  final String label;
  const _EmptyReport({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 48, color: AppColors.divider),
            const SizedBox(height: 12),
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ── PDF 다운로드 버튼 ──
class _PdfDownloadButton extends StatelessWidget {
  final String reportTitle;
  final VoidCallback onDownload;

  const _PdfDownloadButton(
      {required this.reportTitle, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onDownload,
        icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
        label: const Text('PDF로 다운로드',
            style: TextStyle(fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE53935),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 3,
          shadowColor: const Color(0xFFE53935).withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ── PDF 다운로드 다이얼로그 (실제 PDF 생성 안내) ──
void _showPdfDialog(BuildContext context, String title) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.picture_as_pdf_rounded,
                  color: Color(0xFFE53935), size: 30),
            ),
            const SizedBox(height: 16),
            Text('$title\nPDF 저장',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'PDF 저장 기능은 실제 앱에서\n인쇄/저장 기능과 연동됩니다.\n\n지금은 미리보기 모드입니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.6),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('닫기'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('📄 "$title" PDF 저장 완료'),
                          backgroundColor: const Color(0xFFE53935),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('저장',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════
//  회비 미설정 — 비총무 차단 화면
// ════════════════════════════════════════════════════════════
class _FinanceSetupPendingView extends StatelessWidget {
  const _FinanceSetupPendingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_empty_rounded,
                  color: AppColors.primary, size: 30),
            ),
            const SizedBox(height: 16),
            const Text(
              '아직 회비 설정 전입니다.\n총무가 최초 설정한 후 조회 가능합니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  총무 최초 재무 진입 가이드
// ════════════════════════════════════════════════════════════
class _TreasurerFirstVisitGuideBanner extends StatelessWidget {
  const _TreasurerFirstVisitGuideBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '회비설정 탭에서 설정하고 사용을 시작해요\n'
              '(예: 2026년 연회비 / 2026년 월회비 / 2026 투어 특별회비 등)',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                height: 1.55,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  초기 잔액 세팅 바텀시트
//  Step 0: 두 가지 방법 선택 (잔액만 입력 vs 직접 내역 입력)
//  Step 1: 잔액만 입력 → 금액 + 기준일 입력
//  Step 2: 직접 내역 → "수입/지출 내역 추가" 안내 + 바로이동
//
//  [initialStep] : 0이면 선택화면, 1이면 잔고입력 폼으로 바로 진입
//  [initialAmount]: 기존 등록된 금액이 있을 때 폼에 미리 채워줌
// ════════════════════════════════════════════════════════════
class _BalanceOnboardingSheet extends StatefulWidget {
  final ClubProvider provider;
  final int initialStep;      // 0=선택화면, 1=잔고입력 직접 진입
  final int? initialAmount;   // 기존 등록 금액 (수정 모드에서 미리 채움)
  const _BalanceOnboardingSheet({
    required this.provider,
    this.initialStep = 0,
    this.initialAmount,
  });

  @override
  State<_BalanceOnboardingSheet> createState() =>
      _BalanceOnboardingSheetState();
}

class _BalanceOnboardingSheetState extends State<_BalanceOnboardingSheet> {
  // 0 = 선택 화면, 1 = 잔액 직접 입력, 2 = 히스토리 안내
  late int _step;

  // step 1 입력값
  final _amountCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  DateTime _asOf = DateTime(DateTime.now().year, 1, 1);
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep;
    // 수정 모드: 기존 금액 미리 채우기
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _amountCtrl.text = widget.initialAmount.toString();
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: _step == 0 ? 0.78 : 0.82,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── 드래그 핸들 ──
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),
            // ── 헤더 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 0),
              child: Row(
                children: [
                  if (_step > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          size: 18, color: AppColors.textPrimary),
                      onPressed: () => setState(() => _step = 0),
                    ),
                  Expanded(
                    child: Text(
                      _step == 0
                          ? '회비 잔고 시작하기'
                          : _step == 1
                              ? (widget.initialAmount != null ? '기존 잔액 수정' : '기존 잔액 등록')
                              : '올해 내역 직접 입력',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기',
                        style:
                            TextStyle(color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            // ── 컨텐츠 ──
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: _step == 0
                    ? _buildChoiceStep()
                    : _step == 1
                        ? _buildDirectInputStep()
                        : _buildHistoryGuideStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 0: 두 가지 경로 선택 ──
  Widget _buildChoiceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 상황 설명
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('💡', style: TextStyle(fontSize: 18)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '이 앱을 처음 사용하시나요?\n'
                  '기존 모임의 회비 잔고를 이어받아 시작할 수 있어요.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '어떻게 시작하시겠어요?',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),

        // 옵션 A: 잔액만 입력
        _OnboardingOptionCard(
          emoji: '💵',
          title: '현재 잔고만 빠르게 입력',
          subtitle: '지금 통장에 있는 금액만 입력하고\n앞으로의 내역을 관리할게요.',
          badge: '간편',
          badgeColor: AppColors.success,
          onTap: () => setState(() => _step = 1),
        ),
        const SizedBox(height: 12),

        // 옵션 B: 올해 내역 직접 입력
        _OnboardingOptionCard(
          emoji: '📋',
          title: '올해 수입·지출 내역 직접 입력',
          subtitle: '1월부터 지금까지의 내역을 하나씩\n입력해서 정확한 기록을 남길게요.',
          badge: '상세',
          badgeColor: AppColors.primary,
          onTap: () => setState(() => _step = 2),
        ),
        const SizedBox(height: 12),

        // 옵션 C: 잔고등록 하지 않기 (0원 시작)
        _OnboardingOptionCard(
          emoji: '🆕',
          title: '잔고등록 하지 않기',
          subtitle: '기존 잔고 없이 0원부터 시작합니다.\n앞으로의 수입·지출만 기록할게요.',
          badge: '0원',
          badgeColor: const Color(0xFF78909C),
          onTap: _skipOpeningBalance,
        ),
        const SizedBox(height: 24),

        // 나중에 하기
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '나중에 입력하기',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  void _skipOpeningBalance() {
    widget.provider.setOpeningBalance(
      amount: 0,
      asOf: DateTime.now(),
      memo: '잔고 등록 안 함 (0원 시작)',
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('0원으로 시작했어요. 수입·지출을 기록해 주세요.'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Step 1: 현재 잔고 직접 입력 ──
  Widget _buildDirectInputStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 추천 안내 문구 ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFFFCC02).withValues(alpha: 0.6)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('💡', style: TextStyle(fontSize: 16)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '추천 : 지난달 잔고를 등록하고 이번달부터의 수입 지출을 관리하는 방법을 추천합니다',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5D4037),
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── 처리 안내 ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('✅', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Text(
                      '이렇게 처리돼요',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '입력한 금액이 "앱 도입 전 잔액"으로\n'
                  '수입/지출 내역에 자동 등록됩니다.\n'
                  '이후 납부·지출 내역을 이어서 기록하면 돼요.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryLight,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 잔고 금액
          const Text('현재 회비 잔고 (원) *',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  fontSize: 22),
              suffixText: '원',
              suffixStyle: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 16),
              filled: true,
              fillColor: const Color(0xFFF8F8F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFDDDDDD)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFDDDDDD)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 18),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '금액을 입력하세요';
              final n = int.tryParse(v.trim().replaceAll(',', ''));
              if (n == null || n < 0) return '올바른 금액을 입력하세요';
              return null;
            },
          ),

          // 빠른 금액 입력 칩
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [100000, 300000, 500000, 1000000].map((amt) {
              return GestureDetector(
                onTap: () => _amountCtrl.text =
                    amt.toString(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color:
                            AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    '+${_fmt(amt)}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // 기준일
          const Text('기준 날짜',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
            '이 금액이 얼마 기준인지 날짜를 선택하세요.',
            style: TextStyle(
                fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                border: Border.all(color: const Color(0xFFDDDDDD)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_outlined,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(
                    '${_asOf.year}년 ${_asOf.month}월 ${_asOf.day}일',
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  const Text('변경',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.primary)),
                ],
              ),
            ),
          ),

          // 빠른 날짜 선택 칩
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: _quickDates().map((item) {
              return GestureDetector(
                onTap: () => setState(() => _asOf = item['date'] as DateTime),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _asOf == item['date']
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(16),
                    border: _asOf == item['date']
                        ? Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3))
                        : null,
                  ),
                  child: Text(
                    item['label'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _asOf == item['date']
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // 메모 (선택)
          const Text('메모 (선택)',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _memoCtrl,
            decoration: InputDecoration(
              hintText: '예: 통장 잔액 기준, 회비 통장 이전 잔액',
              hintStyle: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF8F8F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFDDDDDD)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFDDDDDD)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 32),

          // 저장 버튼
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _saveOpeningBalance,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                '잔고 등록하기',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: 히스토리 직접 입력 안내 ──
  Widget _buildHistoryGuideStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 안내 메시지
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('📋', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 10),
                  Text(
                    '직접 입력 방법 안내',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                '수입/지출 탭의 "내역 추가 +" 버튼으로\n'
                '월별 내역을 직접 입력할 수 있어요.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 순서 가이드
        const Text(
          '추천 입력 순서',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _GuideStep(
          number: '1',
          icon: '⚙️',
          title: '회비 설정 먼저',
          desc: '회비설정 탭 → 월회비·연회비 금액을 먼저 등록하세요.',
        ),
        _GuideStep(
          number: '2',
          icon: '📅',
          title: '납부현황 탭에서 납부 처리',
          desc: '1월부터 지금까지 납부한 회원을 월별로 체크하세요.\n(납부 처리 시 수입 내역이 자동 등록됩니다)',
        ),
        _GuideStep(
          number: '3',
          icon: '➖',
          title: '지출 내역 추가',
          desc: '수입/지출 탭 → 식비, 상품, 운영비 등\n지출 내역을 날짜별로 추가하세요.',
        ),
        _GuideStep(
          number: '4',
          icon: '✅',
          title: '결산보고로 검증',
          desc: '결산보고 탭에서 월별 잔액이 맞는지\n실제 통장과 비교해 확인하세요.',
        ),
        const SizedBox(height: 20),

        // 팁 박스
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('💡', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '시간이 없다면 "현재 잔고만 입력" 방법으로 빠르게 시작하고,\n나중에 히스토리를 보완할 수 있어요.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5D4037),
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 빠른 방법으로 전환
        OutlinedButton.icon(
          onPressed: () => setState(() => _step = 1),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('현재 잔고만 입력으로 전환'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),

        // 수입/지출 탭으로 이동
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // 탭 전환은 부모 FinanceScreen의 TabController로 처리
              // 여기서는 닫기만 하고 사용자가 탭을 누르도록 안내
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      '"수입/지출" 탭 → 관리자 버튼 "내역 추가 +"를 눌러 입력하세요'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 4),
                ),
              );
            },
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: const Text('수입/지출 탭에서 직접 입력',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  // 빠른 날짜 선택 목록
  List<Map<String, dynamic>> _quickDates() {
    final now = DateTime.now();
    final year = now.year;
    return [
      {'label': '${year}년 1월 1일', 'date': DateTime(year, 1, 1)},
      {'label': '작년 말', 'date': DateTime(year - 1, 12, 31)},
      {'label': '오늘', 'date': DateTime(now.year, now.month, now.day)},
    ];
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _asOf,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _asOf = picked);
  }

  void _saveOpeningBalance() {
    if (!_formKey.currentState!.validate()) return;
    final amount = int.parse(
        _amountCtrl.text.trim().replaceAll(',', ''));
    final memo = _memoCtrl.text.trim().isEmpty
        ? '앱 도입 전 잔액'
        : _memoCtrl.text.trim();
    widget.provider.setOpeningBalance(
      amount: amount,
      asOf: _asOf,
      memo: memo,
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '초기 잔고 ${_fmt(amount)}원이 등록되었습니다! 🎉'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ── 옵션 선택 카드 ──
class _OnboardingOptionCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _OnboardingOptionCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child:
                    Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── 순서 가이드 스텝 위젯 ──
class _GuideStep extends StatelessWidget {
  final String number;
  final String icon;
  final String title;
  final String desc;

  const _GuideStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 번호 원형
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  기존 잔액 등록 설정 카드
//  · 회비설정 탭 최상단에 관리자만 표시
//  · 미등록: 주황 강조 + 등록하기 버튼
//  · 등록됨: 초록 확인 + 금액 표시 + 수정 버튼
// ════════════════════════════════════════════════════════════
class _OpeningBalanceSettingCard extends StatelessWidget {
  final ClubProvider provider;
  const _OpeningBalanceSettingCard({required this.provider});

  // 등록된 초기잔액 거래 가져오기
  Transaction? get _openingTx {
    try {
      return provider.transactions.firstWhere(
          (t) => t.source == TxSource.openingBalance);
    } catch (_) {
      return null;
    }
  }

  String _fmt(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  void _openSheet(BuildContext context, {bool isEdit = false}) {
    final tx = _openingTx;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BalanceOnboardingSheet(
        provider: provider,
        // 신규: 선택 화면(0원 시작 포함) / 수정: 바로 금액 폼
        initialStep: isEdit ? 1 : 0,
        initialAmount: isEdit ? tx?.amount : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tx = _openingTx;
    final isRegistered = tx != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 라벨
        Row(
          children: [
            const Text(
              '기존 잔액 등록',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '총무 전용',
                style: TextStyle(
                    fontSize: 9,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 메인 카드
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRegistered
                  ? AppColors.success.withValues(alpha: 0.4)
                  : const Color(0xFFFFCC02).withValues(alpha: 0.7),
              width: isRegistered ? 1 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isRegistered ? AppColors.success : Colors.amber)
                    .withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── 상단: 상태 + 금액 ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  children: [
                    // 아이콘
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isRegistered
                            ? AppColors.success.withValues(alpha: 0.12)
                            : Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          isRegistered ? '💰' : '📭',
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 텍스트
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isRegistered
                                    ? (tx.amount == 0
                                        ? '0원으로 시작'
                                        : '기존 잔액 등록됨')
                                    : '기존 잔액 미등록',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isRegistered
                                      ? AppColors.success
                                      : const Color(0xFF5D4037),
                                ),
                              ),
                              if (isRegistered) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '✓ 완료',
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: AppColors.success,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          if (isRegistered)
                            Text(
                              tx.amount == 0
                                  ? '잔고등록 하지 않음  ·  ${tx.date.year}.${tx.date.month.toString().padLeft(2, '0')}.${tx.date.day.toString().padLeft(2, '0')}'
                                  : '${_fmt(tx.amount)}원  ·  기준 ${tx.date.year}.${tx.date.month.toString().padLeft(2, '0')}.${tx.date.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            )
                          else
                            const Text(
                              '앱 도입 전 회비 잔고를 등록해 주세요',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF795548),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // 버튼
                    GestureDetector(
                      onTap: () => _openSheet(context, isEdit: isRegistered),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isRegistered
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : const Color(0xFFFFCC02),
                          borderRadius: BorderRadius.circular(20),
                          border: isRegistered
                              ? Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.3))
                              : null,
                        ),
                        child: Text(
                          isRegistered ? '수정' : '등록하기',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isRegistered
                                ? AppColors.primary
                                : const Color(0xFF4E3800),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── 구분선 + 추천 안내 문구 ──
              const Divider(height: 1, color: AppColors.divider),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '추천 : 지난달 잔고를 등록하고 이번달부터의 수입 지출을 관리하는 방법을 추천합니다',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF795548),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
//  회비 설정 안내 배너
//  · 초기잔액은 등록됐지만 회비 설정이 없을 때 표시
// ════════════════════════════════════════════════════════════
class _SetupDuesHintBanner extends StatelessWidget {
  const _SetupDuesHintBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Text('⚙️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '잔고 등록 완료! 다음은 "회비설정" 탭에서\n월회비·연회비 금액을 추가해 보세요.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                height: 1.5,
              ),
            ),
          ),
          const Icon(Icons.arrow_forward_ios,
              size: 14, color: AppColors.primary),
        ],
      ),
    );
  }
}
