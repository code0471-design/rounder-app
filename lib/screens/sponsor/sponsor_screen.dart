import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/club_model.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';

// 후원 컬러 상수
const _kSponsorPrimary   = Color(0xFF4F46E5); // 인디고
const _kSponsorSecondary = Color(0xFF7C3AED); // 바이올렛
const _kSponsorBg        = Color(0xFFF5F3FF); // 연보라 배경

// ════════════════════════════════════════════════════════════
//  SponsorApplicationScreen — 후원 신청 화면
//  · 후원사명 / 후원 내용 / 랜딩 URL / 금액 / 기간 입력
// ════════════════════════════════════════════════════════════
class SponsorApplicationScreen extends StatefulWidget {
  final Club club;
  const SponsorApplicationScreen({super.key, required this.club});

  @override
  State<SponsorApplicationScreen> createState() =>
      _SponsorApplicationScreenState();
}

class _SponsorApplicationScreenState
    extends State<SponsorApplicationScreen> {
  int _step = 0; // 0=기본정보 1=금액/기간 2=확인

  final _nameCtrl   = TextEditingController(); // 후원사 이름
  final _descCtrl   = TextEditingController(); // 후원 내용
  final _urlCtrl    = TextEditingController(); // 랜딩 URL (선택)
  final _repCtrl    = TextEditingController(); // 담당자/대표자 이름 (선택)
  final _amountCtrl = TextEditingController(); // 금액

  int _durationMonths = 1;
  DateTime _startMonth =
      DateTime(DateTime.now().year, DateTime.now().month + 1, 1);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _urlCtrl.dispose();
    _repCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  int get _parsedAmount {
    final raw = _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(raw) ?? 0;
  }

  int get _totalAmount => _parsedAmount * _durationMonths;

  bool get _canNext {
    switch (_step) {
      case 0:
        return _nameCtrl.text.trim().isNotEmpty &&
            _descCtrl.text.trim().isNotEmpty;
      case 1:
        return _parsedAmount >= 10000;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: _kSponsorPrimary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${widget.club.name} 후원 신청',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: Column(
        children: [
          // 스텝 인디케이터
          _buildStepIndicator(),
          // 본문
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _step == 0
                  ? _buildStep0()
                  : _step == 1
                      ? _buildStep1(context)
                      : _buildStep2(),
            ),
          ),
          // 하단 버튼
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['기본 정보', '금액/기간', '최종 확인'];
    return Container(
      color: _kSponsorPrimary,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: List.generate(steps.length, (i) {
          final done = i < _step;
          final active = i == _step;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: done
                                  ? Colors.white
                                  : active
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: done
                                  ? Icon(Icons.check,
                                      size: 14, color: _kSponsorPrimary)
                                  : Text('${i + 1}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: active
                                              ? _kSponsorPrimary
                                              : Colors.white)),
                            ),
                          ),
                          if (i < steps.length - 1) ...[
                            Expanded(
                              child: Container(
                                height: 1,
                                color: done
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(steps[i],
                          style: TextStyle(
                              color: active || done
                                  ? Colors.white
                                  : Colors.white54,
                              fontSize: 10,
                              fontWeight: active
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Step 0: 기본 정보 ──────────────────────────────────
  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('후원사 기본 정보를 입력하세요',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('총무 검토 및 회원들에게 표시될 내용입니다.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        _SponsorInputLabel('후원사 이름 *'),
        const SizedBox(height: 6),
        TextField(
          controller: _nameCtrl,
          maxLength: 30,
          onChanged: (_) => setState(() {}),
          decoration: _inputDeco('예: 다다치과, 강남 헬스클럽'),
        ),
        const SizedBox(height: 16),
        _SponsorInputLabel('후원 내용 (최대한 자세히) *'),
        const SizedBox(height: 6),
        TextField(
          controller: _descCtrl,
          maxLines: 4,
          maxLength: 150,
          onChanged: (_) => setState(() {}),
          decoration: _inputDeco('예: 강남구 소재 치과. 회원 대상 첫 방문 20% 할인 혜택 제공'),
        ),
        const SizedBox(height: 16),
        // 담당자/대표자 이름 (선택)
        Row(
          children: [
            _SponsorInputLabel('담당자 / 대표자 이름'),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('선택',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _repCtrl,
          maxLength: 20,
          onChanged: (_) => setState(() {}),
          decoration: _inputDeco('예: 홍길동'),
        ),
        const SizedBox(height: 16),
        // URL (선택)
        Row(
          children: [
            _SponsorInputLabel('홈페이지 / SNS URL'),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('선택',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('뱃지 클릭 시 이동할 홈페이지, 블로그, SNS 주소입니다.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 6),
        TextField(
          controller: _urlCtrl,
          keyboardType: TextInputType.url,
          onChanged: (_) => setState(() {}),
          decoration: _inputDeco('https://your-website.com (입력 안 해도 됩니다)'),
        ),
        if (_urlCtrl.text.trim().isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _kSponsorBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: _kSponsorPrimary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.link, size: 14, color: _kSponsorPrimary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_urlCtrl.text.trim(),
                      style: const TextStyle(
                          fontSize: 12, color: _kSponsorPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Step 1: 금액 / 기간 ────────────────────────────────
  Widget _buildStep1(BuildContext context) {
    final now = DateTime.now();
    final months = List.generate(
        12, (i) => DateTime(now.year, now.month + i + 1, 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('후원 금액과 기간을 설정하세요',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('금액은 자유롭게 설정하실 수 있습니다.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 24),

        // 금액 입력
        _SponsorInputLabel('월 후원 금액 (원) *'),
        const SizedBox(height: 4),
        Text('최소 10,000원 이상',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 6),
        TextField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: _inputDeco('예: 100000'),
        ),
        // 빠른 선택 버튼
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [50000, 100000, 200000, 300000, 500000].map((amt) {
            final selected = _parsedAmount == amt;
            return GestureDetector(
              onTap: () {
                _amountCtrl.text = amt.toString();
                setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? _kSponsorPrimary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? _kSponsorPrimary
                        : AppColors.divider,
                  ),
                ),
                child: Text(
                  '${_fmt(amt)}원',
                  style: TextStyle(
                      fontSize: 12,
                      color: selected
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // 기간 선택
        _SponsorInputLabel('게재 기간 (개월)'),
        const SizedBox(height: 10),
        Row(
          children: [1, 3, 6, 12].map((m) {
            final selected = _durationMonths == m;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _durationMonths = m),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color:
                        selected ? _kSponsorPrimary : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? _kSponsorPrimary
                          : AppColors.divider,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text('$m개월',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textPrimary)),
                      if (_parsedAmount > 0)
                        Text(
                          '${_fmt(_parsedAmount * m)}원',
                          style: TextStyle(
                              fontSize: 10,
                              color: selected
                                  ? Colors.white70
                                  : AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // 시작 월 선택
        _SponsorInputLabel('게재 시작 월'),
        const SizedBox(height: 6),
        DropdownButtonFormField<DateTime>(
          value: _startMonth,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.divider)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.divider)),
          ),
          items: months
              .map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(
                        '${m.year}년 ${m.month}월',
                        style: const TextStyle(fontSize: 14)),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _startMonth = v!),
        ),
        const SizedBox(height: 20),

        // 금액 요약
        if (_parsedAmount > 0)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kSponsorBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _kSponsorPrimary.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                _SponsorConfirmRow('월 후원 금액',
                    '${_fmt(_parsedAmount)}원'),
                _SponsorConfirmRow('후원 기간',
                    _durationMonths == 1
                        ? '${_startMonth.year}년 ${_startMonth.month}월 (1개월)'
                        : '${_startMonth.year}년 ${_startMonth.month}월 ~ ${_startMonth.month + _durationMonths - 1}월 (${_durationMonths}개월)'),
                const Divider(height: 16),
                _SponsorConfirmRow('총 후원 금액',
                    '${_fmt(_totalAmount)}원',
                    bold: true,
                    valueColor: _kSponsorPrimary),
                _SponsorConfirmRow('  └ 플랫폼 수수료 (10%)',
                    '${_fmt((_totalAmount * 0.1).round())}원'),
                _SponsorConfirmRow('  └ 모임 전달 (90%)',
                    '${_fmt((_totalAmount * 0.9).round())}원'),
              ],
            ),
          ),
      ],
    );
  }

  // ── Step 2: 최종 확인 ──────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('후원 신청 내용을 확인하세요',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SponsorConfirmRow('후원 모임', widget.club.name),
              _SponsorConfirmRow('후원사 이름', _nameCtrl.text),
              _SponsorConfirmRow('후원 내용', _descCtrl.text),
              if (_repCtrl.text.trim().isNotEmpty)
                _SponsorConfirmRow('담당자 이름', _repCtrl.text),
              if (_urlCtrl.text.trim().isNotEmpty)
                _SponsorConfirmRow('홈페이지 URL', _urlCtrl.text),
              _SponsorConfirmRow('후원 기간',
                  _durationMonths == 1
                      ? '${_startMonth.year}년 ${_startMonth.month}월 (1개월)'
                      : '${_startMonth.year}년 ${_startMonth.month}월 ~ ${_startMonth.month + _durationMonths - 1}월 (${_durationMonths}개월)'),
              const Divider(height: 20),
              _SponsorConfirmRow('총 후원 금액',
                  '${_fmt(_totalAmount)}원',
                  bold: true,
                  valueColor: _kSponsorPrimary),
              _SponsorConfirmRow('  └ 모임 전달 (90%)',
                  '${_fmt((_totalAmount * 0.9).round())}원'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kSponsorBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: _kSponsorPrimary.withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: _kSponsorPrimary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '총무 승인 후 결제 안내가 발송됩니다.\n결제 완료 시 후원사 뱃지가 즉시 게재됩니다.',
                  style: TextStyle(
                      fontSize: 12,
                      color: _kSponsorPrimary,
                      height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            if (_step > 0) ...[
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: () => setState(() => _step--),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('이전',
                      style:
                          TextStyle(color: AppColors.textSecondary)),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _canNext ? () => _onNext(context) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kSponsorPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.divider,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  _step == 2 ? '후원 신청하기' : '다음',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onNext(BuildContext context) {
    if (_step < 2) {
      setState(() => _step++);
      return;
    }
    // 후원 신청 제출
    final provider = context.read<ClubProvider>();
    final sp = SponsorApplication(
      id: 'sp_${DateTime.now().millisecondsSinceEpoch}',
      clubId: widget.club.id,
      clubName: widget.club.name,
      applicantId: 'user_me',
      applicantName: provider.currentUserName,
      sponsorName: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      landingUrl: _urlCtrl.text.trim(),
      representativeName: _repCtrl.text.trim().isNotEmpty
          ? _repCtrl.text.trim()
          : null,
      amount: _parsedAmount,
      durationMonths: _durationMonths,
      startMonth: _startMonth,
      status: SponsorStatus.pending,
      appliedAt: DateTime.now(),
    );
    provider.applyForSponsor(sp);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '후원 신청이 접수됐습니다! 총무 승인 후 결제 안내를 보내드립니다.'),
        backgroundColor: _kSponsorPrimary,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: _kSponsorPrimary, width: 2)),
        filled: true,
        fillColor: Colors.white,
      );
}

// ════════════════════════════════════════════════════════════
//  SponsorManagementScreen — 총무용 후원 관리 화면
// ════════════════════════════════════════════════════════════
class SponsorManagementScreen extends StatelessWidget {
  final Club club;
  const SponsorManagementScreen({super.key, required this.club});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: true,
          backgroundColor: _kSponsorPrimary,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('후원 관리',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17)),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: '승인 대기'),
              Tab(text: '전체 현황'),
            ],
          ),
        ),
        body: Consumer<ClubProvider>(
          builder: (context, provider, _) {
            final all = provider.sponsorApplicationsForClub(club.id);
            final pending =
                all.where((s) => s.status == SponsorStatus.pending).toList();
            return TabBarView(
              children: [
                _PendingSponsorList(
                    sponsors: pending, provider: provider),
                _AllSponsorList(sponsors: all),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PendingSponsorList extends StatelessWidget {
  final List<SponsorApplication> sponsors;
  final ClubProvider provider;
  const _PendingSponsorList(
      {required this.sponsors, required this.provider});

  @override
  Widget build(BuildContext context) {
    if (sponsors.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 48, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text('검토 대기 중인 후원 신청이 없습니다.',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sponsors.length,
      itemBuilder: (context, i) =>
          _SponsorReviewCard(sponsor: sponsors[i], provider: provider),
    );
  }
}

class _SponsorReviewCard extends StatelessWidget {
  final SponsorApplication sponsor;
  final ClubProvider provider;
  const _SponsorReviewCard(
      {required this.sponsor, required this.provider});

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _kSponsorPrimary.withValues(alpha: 0.07),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_kSponsorPrimary, _kSponsorSecondary]),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Text(sponsor.sponsorName[0],
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sponsor.sponsorName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(sponsor.applicantName,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('검토 대기',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.amber,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SponsorConfirmRow('후원 내용', sponsor.description),
                _SponsorConfirmRow('랜딩 URL', sponsor.landingUrl),
                _SponsorConfirmRow('월 금액',
                    '${_fmt(sponsor.amount)}원 × ${sponsor.durationMonths}개월'),
                _SponsorConfirmRow('총 금액',
                    '${_fmt(sponsor.amount * sponsor.durationMonths)}원',
                    bold: true,
                    valueColor: _kSponsorPrimary),
                _SponsorConfirmRow('모임 수익 (90%)',
                    '${_fmt(sponsor.clubRevenue)}원'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _showRejectDialog(context, provider),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.danger),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('거절',
                            style: TextStyle(color: AppColors.danger)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          provider.approveSponsor(sponsor.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '${sponsor.sponsorName} 후원 승인됐습니다!'),
                              backgroundColor: _kSponsorPrimary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10)),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kSponsorPrimary,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('승인하기',
                            style: TextStyle(
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, ClubProvider provider) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('거절 사유',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '거절 사유를 입력해 주세요.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소',
                  style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              provider.rejectSponsor(sponsor.id, ctrl.text.trim());
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('거절'),
          ),
        ],
      ),
    );
  }
}

class _AllSponsorList extends StatelessWidget {
  final List<SponsorApplication> sponsors;
  const _AllSponsorList({required this.sponsors});

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (sponsors.isEmpty) {
      return const Center(
          child: Text('후원 신청 내역이 없습니다.',
              style: TextStyle(color: AppColors.textSecondary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sponsors.length,
      itemBuilder: (context, i) {
        final sp = sponsors[i];
        final statusColor = sp.status == SponsorStatus.active
            ? _kSponsorPrimary
            : sp.status == SponsorStatus.pending
                ? Colors.amber.shade700
                : sp.status == SponsorStatus.rejected
                    ? AppColors.danger
                    : AppColors.textSecondary;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_kSponsorPrimary, _kSponsorSecondary]),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Text(sp.sponsorName[0],
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sp.sponsorName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    Text(
                      '${_fmt(sp.amount * sp.durationMonths)}원 · ${sp.durationMonths}개월',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(sp.status.label,
                    style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════
//  공유 위젯
// ════════════════════════════════════════════════════════════
class _SponsorInputLabel extends StatelessWidget {
  final String text;
  const _SponsorInputLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      );
}

class _SponsorConfirmRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  const _SponsorConfirmRow(this.label, this.value,
      {this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.normal,
                    color: valueColor ?? AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
