import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/club_model.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';

// ════════════════════════════════════════════════════════════
//  DuesPaymentScreen — 회비 결제 화면
//  · 카드결제 / 계좌이체 UI
//  · 결제 완료 시 재무탭 자동 수입 처리
// ════════════════════════════════════════════════════════════
class DuesPaymentScreen extends StatefulWidget {
  final DuesSetting duesSetting;
  final int? targetMonth; // 월회비인 경우 해당 월

  const DuesPaymentScreen({
    super.key,
    required this.duesSetting,
    this.targetMonth,
  });

  @override
  State<DuesPaymentScreen> createState() => _DuesPaymentScreenState();
}

class _DuesPaymentScreenState extends State<DuesPaymentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _isProcessing = false;

  // ── 카드 결제 폼 ──────────────────────────────────────────
  final _cardNumCtrl = TextEditingController();
  final _cardExpCtrl = TextEditingController();
  final _cardCvcCtrl = TextEditingController();
  final _cardNameCtrl = TextEditingController();
  bool _saveCard = false;

  // ── 계좌이체 폼 ───────────────────────────────────────────
  String _selectedBank = '국민은행';
  final _accountCtrl = TextEditingController();
  final _depositorCtrl = TextEditingController();

  static const List<String> _bankList = [
    '국민은행', '신한은행', '우리은행', 'NH농협', '하나은행',
    'IBK기업', '카카오뱅크', '토스뱅크', '케이뱅크', '부산은행',
  ];

  // 모임 계좌 (mock)
  static const String _clubBank = '국민은행';
  static const String _clubAccount = '123-456-789012';
  static const String _clubAccountHolder = '서울골프클럽';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _cardNumCtrl.dispose();
    _cardExpCtrl.dispose();
    _cardCvcCtrl.dispose();
    _cardNameCtrl.dispose();
    _accountCtrl.dispose();
    _depositorCtrl.dispose();
    super.dispose();
  }

  String _fmtAmount(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String get _periodLabel {
    if (widget.duesSetting.type == DuesType.monthly && widget.targetMonth != null) {
      return '${DateTime.now().year}년 ${widget.targetMonth}월';
    }
    return widget.duesSetting.title;
  }

  // ── 카드 결제 처리 ────────────────────────────────────────
  Future<void> _processCardPayment() async {
    if (_cardNumCtrl.text.replaceAll(' ', '').length < 16) {
      _showError('카드번호 16자리를 입력해 주세요.');
      return;
    }
    if (_cardExpCtrl.text.length < 5) {
      _showError('유효기간을 입력해 주세요. (MM/YY)');
      return;
    }
    if (_cardCvcCtrl.text.length < 3) {
      _showError('CVC 3자리를 입력해 주세요.');
      return;
    }

    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    // 재무탭 자동 수입 처리
    _recordPayment('카드결제');
    setState(() => _isProcessing = false);
    _showSuccessDialog('카드결제');
  }

  // ── 계좌이체 결제 처리 ────────────────────────────────────
  Future<void> _processTransferPayment() async {
    if (_accountCtrl.text.isEmpty) {
      _showError('출금 계좌번호를 입력해 주세요.');
      return;
    }
    if (_depositorCtrl.text.isEmpty) {
      _showError('예금주명을 입력해 주세요.');
      return;
    }

    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    _recordPayment('계좌이체');
    setState(() => _isProcessing = false);
    _showSuccessDialog('계좌이체');
  }

  // ── 재무탭 자동 수입 처리 ─────────────────────────────────
  void _recordPayment(String method) {
    final provider = context.read<ClubProvider>();
    final now = DateTime.now();
    final title = '${widget.duesSetting.title}'
        '${widget.targetMonth != null ? " ${widget.targetMonth}월" : ""}'
        ' ($method)';

    // Transaction으로 수입 자동 등록
    provider.addTransaction(Transaction(
      id: 'dues_pay_${now.millisecondsSinceEpoch}',
      type: TxType.income,
      amount: widget.duesSetting.amount,
      category: '회비',
      title: title,
      memo: '홍길동 $method 결제',
      date: now,
      recordedBy: '시스템(자동)',
      source: TxSource.dues,
    ));

    // submitPaymentRequest → 총무 확인 필요 흐름 (선택적)
    provider.submitPaymentRequest(
      memberId: 'user_me',
      memberName: '홍길동',
      duesSettingId: widget.duesSetting.id,
      amount: widget.duesSetting.amount,
      year: now.year,
      month: widget.targetMonth,
      memo: '$method 결제 완료',
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessDialog(String method) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('결제 완료!',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1B4B))),
            const SizedBox(height: 8),
            Text(
              '$_periodLabel\n${_fmtAmount(widget.duesSetting.amount)}원이 결제되었습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_balance_wallet,
                      size: 14, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text('재무탭 수입으로 자동 처리됨',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true); // 결제 성공 반환
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('확인',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('회비 결제',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.credit_card, size: 16),
                  SizedBox(width: 6),
                  Text('카드결제', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_outlined, size: 16),
                  SizedBox(width: 6),
                  Text('계좌이체', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ── 결제 금액 요약 배너 ──────────────────────
              _PaymentSummaryBanner(
                title: _periodLabel,
                amount: widget.duesSetting.amount,
                fmtAmount: _fmtAmount,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    // 탭 1: 카드결제
                    _CardPaymentTab(
                      cardNumCtrl: _cardNumCtrl,
                      cardExpCtrl: _cardExpCtrl,
                      cardCvcCtrl: _cardCvcCtrl,
                      cardNameCtrl: _cardNameCtrl,
                      saveCard: _saveCard,
                      onSaveCardChanged: (v) => setState(() => _saveCard = v),
                      amount: widget.duesSetting.amount,
                      fmtAmount: _fmtAmount,
                      onPay: _processCardPayment,
                    ),
                    // 탭 2: 계좌이체
                    _TransferPaymentTab(
                      bankList: _bankList,
                      selectedBank: _selectedBank,
                      onBankChanged: (v) => setState(() => _selectedBank = v!),
                      accountCtrl: _accountCtrl,
                      depositorCtrl: _depositorCtrl,
                      clubBank: _clubBank,
                      clubAccount: _clubAccount,
                      clubAccountHolder: _clubAccountHolder,
                      amount: widget.duesSetting.amount,
                      fmtAmount: _fmtAmount,
                      onPay: _processTransferPayment,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // ── 처리 중 오버레이 ────────────────────────────
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 40, height: 40,
                        child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 3),
                      ),
                      const SizedBox(height: 16),
                      const Text('결제 처리 중...',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E1B4B))),
                      const SizedBox(height: 4),
                      Text('잠시만 기다려 주세요.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  결제 금액 요약 배너
// ════════════════════════════════════════════════════════════
class _PaymentSummaryBanner extends StatelessWidget {
  final String title;
  final int amount;
  final String Function(int) fmtAmount;

  const _PaymentSummaryBanner({
    required this.title,
    required this.amount,
    required this.fmtAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7))),
              const SizedBox(height: 4),
              Text(
                '${fmtAmount(amount)}원',
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 12, color: Colors.white),
                const SizedBox(width: 4),
                Text('안전결제',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  카드 결제 탭
// ════════════════════════════════════════════════════════════
class _CardPaymentTab extends StatelessWidget {
  final TextEditingController cardNumCtrl;
  final TextEditingController cardExpCtrl;
  final TextEditingController cardCvcCtrl;
  final TextEditingController cardNameCtrl;
  final bool saveCard;
  final ValueChanged<bool> onSaveCardChanged;
  final int amount;
  final String Function(int) fmtAmount;
  final VoidCallback onPay;

  const _CardPaymentTab({
    required this.cardNumCtrl,
    required this.cardExpCtrl,
    required this.cardCvcCtrl,
    required this.cardNameCtrl,
    required this.saveCard,
    required this.onSaveCardChanged,
    required this.amount,
    required this.fmtAmount,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 카드 미리보기 ──────────────────────────────
          Container(
            height: 170,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.credit_card, color: Colors.white, size: 24),
                      const Spacer(),
                      Text('GOLF ROUNDER',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.7),
                              letterSpacing: 1.5)),
                    ],
                  ),
                  const Spacer(),
                  ValueListenableBuilder(
                    valueListenable: cardNumCtrl,
                    builder: (_, __, ___) {
                      final raw = cardNumCtrl.text.replaceAll(' ', '');
                      final groups = <String>[];
                      for (int i = 0; i < 16; i += 4) {
                        groups.add(raw.length > i
                            ? raw.substring(i, raw.length > i + 4 ? i + 4 : raw.length).padRight(4, '•')
                            : '••••');
                      }
                      return Text(
                        groups.join('  '),
                        style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('VALID THRU',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.white.withValues(alpha: 0.6))),
                          ValueListenableBuilder(
                            valueListenable: cardExpCtrl,
                            builder: (_, __, ___) => Text(
                              cardExpCtrl.text.isEmpty ? 'MM/YY' : cardExpCtrl.text,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CARDHOLDER',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.white.withValues(alpha: 0.6))),
                          ValueListenableBuilder(
                            valueListenable: cardNameCtrl,
                            builder: (_, __, ___) => Text(
                              cardNameCtrl.text.isEmpty ? '홍길동' : cardNameCtrl.text,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── 카드 정보 입력 ─────────────────────────────
          _FormLabel('카드번호'),
          const SizedBox(height: 6),
          TextFormField(
            controller: cardNumCtrl,
            keyboardType: TextInputType.number,
            maxLength: 19,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _CardNumberFormatter(),
            ],
            decoration: _inputDeco('1234 5678 9012 3456'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FormLabel('유효기간'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: cardExpCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _ExpDateFormatter(),
                      ],
                      decoration: _inputDeco('MM/YY'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FormLabel('CVC'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: cardCvcCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 3,
                      obscureText: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: _inputDeco('•••'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _FormLabel('카드 소유자명'),
          const SizedBox(height: 6),
          TextFormField(
            controller: cardNameCtrl,
            decoration: _inputDeco('예: 홍길동'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(
                value: saveCard,
                onChanged: (v) => onSaveCardChanged(v ?? false),
                activeColor: AppColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const Text('카드 정보 저장 (다음 결제 시 자동 입력)',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 24),
          // ── 결제 버튼 ──────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onPay,
              icon: const Icon(Icons.credit_card, size: 18),
              label: Text(
                '카드로 ${fmtAmount(amount)}원 납부하기',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 보안 안내
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.security, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text('256-bit SSL 보안 암호화 결제',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade400)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  계좌이체 탭
// ════════════════════════════════════════════════════════════
class _TransferPaymentTab extends StatelessWidget {
  final List<String> bankList;
  final String selectedBank;
  final ValueChanged<String?> onBankChanged;
  final TextEditingController accountCtrl;
  final TextEditingController depositorCtrl;
  final String clubBank;
  final String clubAccount;
  final String clubAccountHolder;
  final int amount;
  final String Function(int) fmtAmount;
  final VoidCallback onPay;

  const _TransferPaymentTab({
    required this.bankList,
    required this.selectedBank,
    required this.onBankChanged,
    required this.accountCtrl,
    required this.depositorCtrl,
    required this.clubBank,
    required this.clubAccount,
    required this.clubAccountHolder,
    required this.amount,
    required this.fmtAmount,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 모임 계좌 정보 ─────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.account_balance,
                          size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    const Text('모임 입금 계좌',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1B4B))),
                  ],
                ),
                const SizedBox(height: 14),
                _AccountRow('은행', clubBank),
                const SizedBox(height: 6),
                _AccountRow('계좌번호', clubAccount, highlight: true),
                const SizedBox(height: 6),
                _AccountRow('예금주', clubAccountHolder),
                const SizedBox(height: 6),
                _AccountRow('입금금액', '${fmtAmount(amount)}원',
                    highlight: true, bold: true),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: clubAccount));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('계좌번호가 복사되었습니다.'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.copy, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        const Text('계좌번호 복사',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 이체 정보 입력 ─────────────────────────────
          const Text('이체 정보 입력',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1B4B))),
          const SizedBox(height: 14),
          _FormLabel('출금 은행'),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedBank,
                isExpanded: true,
                items: bankList
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: onBankChanged,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _FormLabel('출금 계좌번호'),
          const SizedBox(height: 6),
          TextFormField(
            controller: accountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDeco('계좌번호 입력 (숫자만)'),
          ),
          const SizedBox(height: 14),
          _FormLabel('예금주명'),
          const SizedBox(height: 6),
          TextFormField(
            controller: depositorCtrl,
            decoration: _inputDeco('예: 홍길동'),
          ),
          const SizedBox(height: 14),
          // 주의 안내
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '입금자명을 반드시 본인 이름으로 입력해 주세요.\n'
                    '총무에게 자동으로 납부 확인 알림이 전송됩니다.',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.brown.shade600,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // ── 이체 실행 버튼 ────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onPay,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: Text(
                '${fmtAmount(amount)}원 이체하기',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 계좌 정보 행 ─────────────────────────────────────────────
class _AccountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final bool bold;

  const _AccountRow(this.label, this.value,
      {this.highlight = false, this.bold = false});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                    color: highlight
                        ? AppColors.primary
                        : const Color(0xFF1E1B4B))),
          ),
        ],
      );
}

// ── 폼 레이블 ────────────────────────────────────────────────
class _FormLabel extends StatelessWidget {
  final String label;
  const _FormLabel(this.label);
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E1B4B)));
}

InputDecoration _inputDeco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );

// ── 카드번호 포맷터 (4자리마다 공백) ─────────────────────────
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue next) {
    final digits = next.text.replaceAll(' ', '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final str = buf.toString();
    return TextEditingValue(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

// ── 유효기간 포맷터 (MM/YY) ──────────────────────────────────
class _ExpDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue next) {
    final digits = next.text.replaceAll('/', '');
    if (digits.length <= 2) {
      return next.copyWith(text: digits);
    }
    final str = '${digits.substring(0, 2)}/${digits.substring(2, digits.length.clamp(2, 4))}';
    return TextEditingValue(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}
