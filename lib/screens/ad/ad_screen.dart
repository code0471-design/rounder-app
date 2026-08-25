import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/clubs/application/club_list_controller.dart';
import '../../models/club_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';
import '../club_room/club_room_screen.dart';
import '../legal/service_about_screen.dart';
import '../members/my_role_change_screen.dart';

// ── 후원 기간 포맷 헬퍼 ──────────────────────────────────────
// 1개월: "2025년 8월 (1개월)"
// 복수:  "2025년 8월 ~ 10월 (3개월)"
String _fmtSponsorPeriod(SponsorApplication sp) {
  final y  = sp.startMonth.year;
  final sm = sp.startMonth.month;
  final em = sp.startMonth.month + sp.durationMonths - 1; // 마지막 달
  final d  = sp.durationMonths;
  if (d == 1) return '$y년 ${sm}월 (1개월)';
  return '$y년 ${sm}월 ~ ${em}월 (${d}개월)';
}

// ════════════════════════════════════════════════════════════
//  AdApplicationScreen — 광고 신청 메인 화면
//  진입: 모임찾기 or 내 모임에서 "광고 신청하기" 탭
// ════════════════════════════════════════════════════════════
class AdApplicationScreen extends StatefulWidget {
  final Club club;
  const AdApplicationScreen({super.key, required this.club});

  @override
  State<AdApplicationScreen> createState() => _AdApplicationScreenState();
}

class _AdApplicationScreenState extends State<AdApplicationScreen> {
  // Step: 0=슬롯선택 1=기간선택 2=정보입력 3=확인
  int _step = 0;

  final Set<AdSlotType> _selectedSlots = {};
  int _durationMonths = 1;
  DateTime _startMonth = DateTime(DateTime.now().year, DateTime.now().month + 1, 1);

  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  int get _totalFee =>
      _selectedSlots.fold(0, (sum, s) => sum + s.monthlyFee * _durationMonths);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: AppColors.primaryDark,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${widget.club.name} 광고 신청',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: Column(
        children: [
          // ── 단계 표시 ──
          _StepIndicator(current: _step),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: [
                _buildStep0(),
                _buildStep1(context),
                _buildStep2(),
                _buildStep3(context),
              ][_step],
            ),
          ),
          // ── 하단 버튼 ──
          _buildBottomBar(context),
        ],
      ),
    );
  }

  // ── Step 0: 배너 슬롯 선택 ──────────────────────────────
  Widget _buildStep0() {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('광고할 배너를 선택하세요',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('중복 선택 가능합니다.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ...AdSlotType.values.map((slot) {
              // pending/approved/paid 포함 기간 충돌 체크
              final occupied = provider.occupiedAdForSlot(
                  widget.club.id, slot, _startMonth, _durationMonths);
              final earliest = provider.earliestAvailableDate(widget.club.id, slot);
              final isOccupied = occupied != null;
              final selected = _selectedSlots.contains(slot);

              return GestureDetector(
                onTap: () {
                  if (isOccupied) {
                    _showOccupiedDialog(context, slot, earliest, provider);
                  } else {
                    setState(() {
                      if (selected) {
                        _selectedSlots.remove(slot);
                      } else {
                        _selectedSlots.add(slot);
                      }
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.divider,
                      width: selected ? 2 : 1,
                    ),
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
                      // 체크
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? AppColors.primary : Colors.transparent,
                          border: Border.all(
                            color: selected ? AppColors.primary : AppColors.divider,
                            width: 2,
                          ),
                        ),
                        child: selected
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(slot.label,
                                    style: const TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary)),
                                const SizedBox(width: 8),
                                if (isOccupied)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.danger.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                                    ),
                                    child: const Text('게재 중',
                                        style: TextStyle(fontSize: 10, color: AppColors.danger, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(slot.description,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            if (isOccupied) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${earliest.month}월 1일부터 게재 가능 · 탭하면 예약 신청',
                                style: TextStyle(fontSize: 11, color: AppColors.primary.withValues(alpha: 0.8)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        '${_fmt(slot.monthlyFee)}원/월',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (_selectedSlots.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('선택된 배너 ${_selectedSlots.length}개',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    Text('월 ${_fmt(_selectedSlots.fold(0, (s, t) => s + t.monthlyFee))}원',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _showOccupiedDialog(BuildContext context, AdSlotType slot, DateTime earliest, ClubProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(slot.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          '현재 타 광고 게재중입니다.\n${earliest.month}월 1일부터 게재 가능합니다.\n\n신청하시겠습니까?',
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _selectedSlots.add(slot);
                _startMonth = earliest;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('신청하기'),
          ),
        ],
      ),
    );
  }

  // ── Step 1: 기간 선택 ──────────────────────────────────
  Widget _buildStep1(BuildContext context) {
    final now = DateTime.now();
    final months = List.generate(12, (i) {
      final m = DateTime(now.year, now.month + i + 1, 1);
      return m;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('게재 시작월을 선택하세요',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        // 시작월 선택
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<DateTime>(
              value: _startMonth,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              borderRadius: BorderRadius.circular(12),
              items: months.map((m) => DropdownMenuItem(
                value: m,
                child: Text('${m.year}년 ${m.month}월'),
              )).toList(),
              onChanged: (v) => setState(() => _startMonth = v!),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text('게재 기간을 선택하세요',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        // 기간 선택 (1~6개월)
        Wrap(
          spacing: 10,
          children: List.generate(6, (i) {
            final months = i + 1;
            final selected = _durationMonths == months;
            return ChoiceChip(
              label: Text('$months개월'),
              selected: selected,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600),
              onSelected: (_) => setState(() => _durationMonths = months),
            );
          }),
        ),
        const SizedBox(height: 24),
        // 요약 카드
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              _SummaryRow('게재 시작', '${_startMonth.year}년 ${_startMonth.month}월'),
              const SizedBox(height: 8),
              _SummaryRow('게재 종료',
                  '${_startMonth.year}년 ${_startMonth.month + _durationMonths - 1}월'),
              const SizedBox(height: 8),
              _SummaryRow('선택 배너', _selectedSlots.map((s) => s.label).join(', ')),
              const Divider(height: 20),
              _SummaryRow(
                '총 광고비',
                '${_fmt(_totalFee)}원',
                bold: true,
                valueColor: AppColors.primary,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('  └ 플랫폼 수수료 (10%)',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  Text('${_fmt((_totalFee * 0.1).round())}원',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('  └ 모임 수익 (90%)',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  Text('${_fmt((_totalFee * 0.9).round())}원',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 2: 광고 정보 입력 ─────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('광고 정보를 입력하세요',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('총무 검토 및 배너에 표시될 내용입니다.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        _InputLabel('광고 제목 *'),
        const SizedBox(height: 6),
        TextField(
          controller: _titleCtrl,
          maxLength: 30,
          onChanged: (_) => setState(() {}),
          decoration: _inputDeco('예: 스카이72 골프 & 리조트'),
        ),
        const SizedBox(height: 16),
        _InputLabel('광고 내용 (최대한 자세히) *'),
        const SizedBox(height: 6),
        TextField(
          controller: _descCtrl,
          maxLines: 4,
          maxLength: 150,
          onChanged: (_) => setState(() {}),
          decoration: _inputDeco('예: 인천 영종도 36홀 · 주중 그린피 15% 할인, 카트 무료, 부킹 우선 배정 혜택'),
        ),
        const SizedBox(height: 16),
        // 이미지 첨부 안내
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFE082)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '배너 이미지 및 상세페이지 이미지는 결제 완료 후 업로드할 수 있습니다.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 3: 최종 확인 ──────────────────────────────────
  Widget _buildStep3(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('신청 내용을 확인하세요',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ConfirmRow('광고 모임', widget.club.name),
              _ConfirmRow('배너 종류', _selectedSlots.map((s) => s.label).join('\n')),
              _ConfirmRow('게재 기간',
                  '${_startMonth.year}년 ${_startMonth.month}월 ~ '
                  '${_startMonth.month + _durationMonths - 1}월 (${_durationMonths}개월)'),
              _ConfirmRow('광고 제목', _titleCtrl.text),
              _ConfirmRow('광고 내용', _descCtrl.text),
              const Divider(height: 20),
              _ConfirmRow('총 광고비', '${_fmt(_totalFee)}원', bold: true, valueColor: AppColors.primary),
              _ConfirmRow('  └ 모임 수익', '${_fmt((_totalFee * 0.9).round())}원'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 알림톡 안내
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFE082)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(children: [
                Icon(Icons.notifications_outlined, size: 15, color: Color(0xFFF59E0B)),
                SizedBox(width: 6),
                Text('신청 후 진행 절차', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
              ]),
              SizedBox(height: 8),
              _ProcessStep('1', '총무에게 알림톡 발송'),
              _ProcessStep('2', '총무 승인 시 알림톡 수신'),
              _ProcessStep('3', '48시간 내 광고비 결제'),
              _ProcessStep('4', '배너 이미지 업로드 후 게재 시작'),
            ],
          ),
        ),
      ],
    );
  }

  // ── 하단 버튼 ──────────────────────────────────────────
  Widget _buildBottomBar(BuildContext context) {
    final canNext = switch (_step) {
      0 => _selectedSlots.isNotEmpty,
      1 => true,
      2 => _titleCtrl.text.trim().isNotEmpty && _descCtrl.text.trim().isNotEmpty,
      _ => true,
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            if (_step > 0)
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: () => setState(() => _step--),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('이전', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            if (_step > 0) const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: canNext ? () => _onNext(context) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.divider,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  _step == 3 ? '신청하기' : '다음',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onNext(BuildContext context) {
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    // 최종 신청
    final provider = context.read<ClubProvider>();
    final now = DateTime.now();
    for (final slot in _selectedSlots) {
      provider.applyForAd(AdApplication(
        id: 'ad_${now.millisecondsSinceEpoch}_${slot.name}',
        clubId: widget.club.id,
        clubName: widget.club.name,
        applicantId: 'user_me',
        applicantName: '홍길동',
        slotType: slot,
        startMonth: _startMonth,
        durationMonths: _durationMonths,
        status: AdStatus.pending,
        appliedAt: now,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        landingUrl: null,
      ));
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: AppColors.success, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('광고 신청 완료!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              '총무에게 알림톡이 발송되었습니다.\n승인 후 결제를 진행해 주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('확인'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
}

// ════════════════════════════════════════════════════════════
//  총무 광고 관리 화면 — 승인/거절 + 내역 확인
// ════════════════════════════════════════════════════════════
class AdManagementScreen extends StatelessWidget {
  final Club club;
  const AdManagementScreen({super.key, required this.club});

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final pendingAds     = provider.pendingAdsForClub(club.id).length;
        final pendingSponsors = provider.pendingSponsorsForClub(club.id).length;

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              automaticallyImplyLeading: true,
              backgroundColor: AppColors.primaryDark,
              iconTheme: const IconThemeData(color: Colors.white),
              title: const Text('광고·후원 관리',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
              bottom: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('광고 검토', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        if (pendingAds > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orange, borderRadius: BorderRadius.circular(8)),
                            child: Text('$pendingAds',
                                style: const TextStyle(color: Colors.white, fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('후원 검토', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        if (pendingSponsors > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(8)),
                            child: Text('$pendingSponsors',
                                style: const TextStyle(color: Colors.white, fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(text: '전체 내역'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _PendingAdList(club: club),
                _PendingSponsorList(club: club),
                _AllAdList(club: club),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── 총무용 후원 검토 탭 ────────────────────────────────────────
class _PendingSponsorList extends StatelessWidget {
  final Club club;
  const _PendingSponsorList({required this.club});

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final pending = provider.pendingSponsorsForClub(club.id);
        // paid (입금됨) 도 함께 표시 — 총무가 활성화 처리
        final paid    = provider.sponsorApplicationsForClub(club.id)
            .where((s) => s.status == SponsorStatus.paid).toList();

        if (pending.isEmpty && paid.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.volunteer_activism_outlined,
                      size: 32, color: Color(0xFF4F46E5)),
                ),
                const SizedBox(height: 12),
                const Text('검토 대기 중인 후원 신청이 없습니다.',
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (paid.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_outlined,
                        size: 16, color: Color(0xFF4F46E5)),
                    const SizedBox(width: 8),
                    Text('입금 완료 ${paid.length}건 — 활성화 처리 필요',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF4F46E5),
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              ...paid.map((s) => _SponsorReviewCard(sponsor: s, club: club)),
              if (pending.isNotEmpty) const Divider(height: 24),
            ],
            ...pending.map((s) => _SponsorReviewCard(sponsor: s, club: club)),
          ],
        );
      },
    );
  }
}

// ── 후원 검토 카드 ────────────────────────────────────────────
class _SponsorReviewCard extends StatelessWidget {
  final SponsorApplication sponsor;
  final Club club;
  const _SponsorReviewCard({required this.sponsor, required this.club});

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
    final isPaid = sponsor.status == SponsorStatus.paid;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isPaid
            ? Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.4))
            : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('공식후원',
                      style: TextStyle(fontSize: 10, color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(sponsor.sponsorName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                if (isPaid)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('입금완료',
                        style: TextStyle(fontSize: 11, color: Colors.green,
                            fontWeight: FontWeight.bold)),
                  )
                else
                  Text('신청: ${sponsor.appliedAt.month}/${sponsor.appliedAt.day}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sponsor.description,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                _ConfirmRow('신청자', sponsor.applicantName),
                _ConfirmRow('후원 기간', _fmtSponsorPeriod(sponsor)),
                _ConfirmRow('월 후원금',
                    '${_fmt(sponsor.amount)}원 → 모임 수익 ${_fmt(sponsor.clubRevenue)}원',
                    bold: true, valueColor: const Color(0xFF4F46E5)),
                _ConfirmRow('랜딩 URL', sponsor.landingUrl),
                const SizedBox(height: 14),
                if (isPaid) ...[
                  // 입금 완료 → 총무가 활성화 (현재는 사용 안함, markSponsorPaid에서 자동 active)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Colors.green),
                        SizedBox(width: 8),
                        Text('결제 완료 · 공식 후원사로 등록되었습니다',
                            style: TextStyle(fontSize: 12, color: Colors.green,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ] else ...[
                  // 대기 중 → 승인/거절
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showRejectDialog(context),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('거절'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            context.read<ClubProvider>().approveSponsor(sponsor.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${sponsor.applicantName}님의 후원을 승인했습니다.'),
                                backgroundColor: const Color(0xFF4F46E5),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          },
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('승인'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('후원 거절', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('거절 사유를 입력하세요.\n신청자에게 알림톡으로 전달됩니다.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '예: 후원 내용이 모임 성격과 맞지 않습니다.',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              context.read<ClubProvider>().rejectSponsor(sponsor.id, ctrl.text.trim());
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('거절 처리 완료. 신청자에게 알림톡 발송됨.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('거절 처리'),
          ),
        ],
      ),
    );
  }
}

class _PendingAdList extends StatelessWidget {
  final Club club;
  const _PendingAdList({required this.club});

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final pending = provider.pendingAdsForClub(club.id);
        if (pending.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: AppColors.textSecondary),
                SizedBox(height: 12),
                Text('검토 대기 중인 광고 신청이 없습니다.',
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pending.length,
          itemBuilder: (context, i) => _AdReviewCard(ad: pending[i], club: club),
        );
      },
    );
  }
}

class _AdReviewCard extends StatelessWidget {
  final AdApplication ad;
  final Club club;
  const _AdReviewCard({required this.ad, required this.club});

  String _fmt(int n) {
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                _SlotBadge(ad.slotType),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(ad.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Text('신청: ${ad.appliedAt.month}/${ad.appliedAt.day}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ad.description,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                _ConfirmRow('신청자', ad.applicantName),
                _ConfirmRow('게재 기간',
                    '${ad.startMonth.year}년 ${ad.startMonth.month}월 ~ ${ad.endMonth.month - 1}월 (${ad.durationMonths}개월)'),
                _ConfirmRow('광고비', '${_fmt(ad.totalFee)}원 → 모임 수익 ${_fmt(ad.clubRevenue)}원', bold: true, valueColor: AppColors.success),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showRejectDialog(context),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('거절'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.read<ClubProvider>().approveAd(ad.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${ad.applicantName}님의 광고를 승인했습니다. 알림톡 발송 완료.'),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('승인'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    );
  }

  void _showRejectDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('광고 거절', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('거절 사유를 입력하세요.\n신청자에게 알림톡으로 전달됩니다.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '예: 광고 내용이 모임 성격과 맞지 않습니다.',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              context.read<ClubProvider>().rejectAd(ad.id, ctrl.text.trim());
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('거절 처리 완료. 신청자에게 알림톡 발송됨.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('거절 처리'),
          ),
        ],
      ),
    );
  }
}

class _AllAdList extends StatelessWidget {
  final Club club;
  const _AllAdList({required this.club});

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final ads      = provider.adApplicationsForClub(club.id);
        final sponsors = provider.sponsorApplicationsForClub(club.id);

        if (ads.isEmpty && sponsors.isEmpty) {
          return const Center(
            child: Text('광고·후원 내역이 없습니다.',
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 광고 내역
            if (ads.isNotEmpty) ...[
              _AllListHeader(
                icon: Icons.campaign_outlined,
                color: const Color(0xFFFF6D00),
                label: '광고 내역',
                count: ads.length,
              ),
              const SizedBox(height: 8),
              ...ads.map((ad) => _AdHistoryTile(ad: ad)),
              const SizedBox(height: 16),
            ],
            // 후원 내역
            if (sponsors.isNotEmpty) ...[
              _AllListHeader(
                icon: Icons.volunteer_activism_outlined,
                color: const Color(0xFF4F46E5),
                label: '후원 내역',
                count: sponsors.length,
              ),
              const SizedBox(height: 8),
              ...sponsors.map((sp) => _SponsorHistoryTile(sponsor: sp)),
            ],
          ],
        );
      },
    );
  }
}

// ── 전체 내역 섹션 헤더 ───────────────────────────────────────
class _AllListHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int count;
  const _AllListHeader({required this.icon, required this.color,
      required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$count건',
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// ── 후원 히스토리 타일 ────────────────────────────────────────
class _SponsorHistoryTile extends StatelessWidget {
  final SponsorApplication sponsor;
  const _SponsorHistoryTile({required this.sponsor});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (sponsor.status) {
      SponsorStatus.active   => AppColors.success,
      SponsorStatus.approved => const Color(0xFF4F46E5),
      SponsorStatus.paid     => const Color(0xFF7C3AED),
      SponsorStatus.pending  => const Color(0xFFF59E0B),
      SponsorStatus.rejected => AppColors.danger,
      SponsorStatus.expired  => AppColors.textSecondary,
    };
    final statusLabel = switch (sponsor.status) {
      SponsorStatus.active   => '후원 중',
      SponsorStatus.approved => '결제 대기',
      SponsorStatus.paid     => '확인 중',
      SponsorStatus.pending  => '검토 대기',
      SponsorStatus.rejected => '거절됨',
      SponsorStatus.expired  => '만료',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.volunteer_activism,
                size: 16, color: Color(0xFF4F46E5)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sponsor.sponsorName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text('${sponsor.applicantName} · ${_fmtSponsorPeriod(sponsor)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(statusLabel,
                style: TextStyle(fontSize: 10, color: statusColor,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _AdHistoryTile extends StatelessWidget {
  final AdApplication ad;
  const _AdHistoryTile({required this.ad});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (ad.status) {
      AdStatus.active   => AppColors.success,
      AdStatus.approved => AppColors.primary,
      AdStatus.pending  => const Color(0xFFF59E0B),
      AdStatus.rejected => AppColors.danger,
      _                 => AppColors.textSecondary,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          _SlotBadge(ad.slotType),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ad.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text('${ad.applicantName} · ${ad.startMonth.month}월~${ad.endMonth.month - 1}월',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(ad.status.label,
                style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  내 광고 현황 화면 — 결제 + 이미지 업로드
// ════════════════════════════════════════════════════════════
// ════════════════════════════════════════════════════════════
//  MyAdScreen — 광고주 마이페이지
//  진입: ClubRoomScreen 헤더 프로필 아이콘
// ════════════════════════════════════════════════════════════
// ════════════════════════════════════════════════════════════
//  MyAdScreen — 광고 + 후원 통합 마이페이지 (탭 분리)
//
//  [비활성] 광고 관리 / 후원 관리 탭 — 결제 연동 후 복구:
//  · DefaultTabController(length: 3)
//  · AppBar bottom: TabBar → 광고 관리, 후원 관리, 계정 설정
//  · body: TabBarView → _MyAdTab(), _MySponsorTab(), _AccountSettingsTab()
//  · unreadAd / unreadSponsor 배지는 Consumer<ClubProvider>에서 조회
// ════════════════════════════════════════════════════════════
class MyAdScreen extends StatelessWidget {
  const MyAdScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: AppColors.primaryDark,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          '마이페이지',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        // [비활성] 광고 관리 / 후원 관리 TabBar — 결제 연동 후 복구 (파일 하단 _MyAdTab, _MySponsorTab 참고)
      ),
      body: const _AccountSettingsTab(),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  _AccountSettingsTab — 계정 설정 / 탈퇴
// ════════════════════════════════════════════════════════════
class _AccountSettingsTab extends StatefulWidget {
  const _AccountSettingsTab();
  @override
  State<_AccountSettingsTab> createState() => _AccountSettingsTabState();
}

class _AccountSettingsTabState extends State<_AccountSettingsTab> {
  @override
  Widget build(BuildContext context) {
    return Consumer2<ClubProvider, AuthProvider>(
      builder: (_, provider, auth, __) {
        final myClubs = provider.myClubs;
        final displayName =
            provider.currentMember?.name ?? auth.currentUser?.name ?? '회원';

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          children: [
            // ── 프로필 카드 ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  // 아바타 (프로필 사진 or 그라디언트)
                  GestureDetector(
                    onTap: () => _showProfileEditDialog(context, provider),
                    child: Stack(
                      children: [
                        () {
                          final m = provider.currentMember;
                          if (m != null && m.photoUrl != null && m.photoUrl!.isNotEmpty) {
                            return CircleAvatar(
                              radius: 27,
                              backgroundImage: NetworkImage(m.photoUrl!),
                              onBackgroundImageError: (_, __) {},
                            );
                          }
                          return Container(
                            width: 54, height: 54,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryLight],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                (displayName.isNotEmpty ? displayName[0] : '나'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }(),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            width: 18, height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(Icons.edit, color: Colors.white, size: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                              color: Color(0xFF1E1B4B)),
                        ),
                        const SizedBox(height: 2),
                        Text('참여 모임 ${myClubs.length}개',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  // 편집 버튼
                  TextButton.icon(
                    onPressed: () => _showProfileEditDialog(context, provider),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('편집', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 직책 변경 ────────────────────────────────
            const _AccountSectionHeader(label: '직책'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MyRoleChangeScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.military_tech_outlined,
                            color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('직책 변경',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            SizedBox(height: 2),
                            Text('내 모임 선택 후 직책을 수정합니다',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── 내 모임 (입장 / 탈퇴) ────────────────────────────────
            const _AccountSectionHeader(label: '내 모임'),
            const SizedBox(height: 10),
            if (myClubs.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('참여 중인 모임이 없습니다.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              )
            else
              ...myClubs.map((club) => _ClubWithdrawTile(club: club, provider: provider)),

            const SizedBox(height: 28),

            const _AccountSectionHeader(label: '서비스'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ServiceAboutScreen(),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '서비스 소개 · 사업자 정보',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── 로그아웃 ─────────────────────────────────
            const _AccountSectionHeader(label: '계정'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _confirmLogout(context, provider),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.logout_rounded,
                            color: Colors.orange.shade600, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Text('로그아웃',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const Spacer(),
                      Icon(Icons.chevron_right,
                          color: Colors.grey.shade400, size: 20),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── 앱 탈퇴 ─────────────────────────────────
            const _AccountSectionHeader(label: '앱 탈퇴'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 18),
                        const SizedBox(width: 8),
                        const Text('앱 탈퇴 안내',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1B4B))),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Text(
                      '• 탈퇴 시 모든 모임에서 자동 탈퇴됩니다.\n'
                      '• 광고/후원 내역 및 결제 정보가 삭제됩니다.\n'
                      '• 삭제된 계정은 복구할 수 없습니다.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.7),
                    ),
                  ),
                  Divider(height: 1, color: Colors.red.shade50),
                  InkWell(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                    onTap: () => _confirmAppWithdraw(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.exit_to_app, color: Colors.red.shade400, size: 18),
                          const SizedBox(width: 8),
                          Text('앱 탈퇴하기',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                                  color: Colors.red.shade500)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── 로그아웃 확인 다이얼로그 ──────────────────────────────
  void _confirmLogout(BuildContext context, ClubProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.orange.shade500, size: 22),
            const SizedBox(width: 8),
            const Text('로그아웃', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          '로그아웃 하시겠습니까?\n자동로그인이 해제되며 다음에 다시 로그인해야 합니다.',
          style: TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final auth = context.read<AuthProvider>();
              await auth.logoutAsync();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (_) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  // ── 프로필 편집 다이얼로그 (전체 필드) ──────────────────────
  void _showProfileEditDialog(BuildContext context, ClubProvider provider) {
    final member = provider.currentMember ??
        (provider.activeMembers.isNotEmpty ? provider.activeMembers.first : null);
    if (member == null) return;

    final messenger = ScaffoldMessenger.of(context);

    // 컨트롤러 초기화
    final nameCtrl    = TextEditingController(text: member.name);
    final phoneCtrl   = TextEditingController(text: member.phone ?? '');
    final addressCtrl = TextEditingController(text: member.address ?? '');
    final handicapCtrl = TextEditingController(
        text: member.handicap != null ? member.handicap!.toStringAsFixed(1) : '');
    final bioCtrl     = TextEditingController(text: member.bio ?? '');

    // 상태 변수 (StatefulBuilder 밖에서 선언 후 참조)
    String selectedGender = member.gender;
    DateTime? selectedBirth = member.birthDate;
    String? photoDataUrl = member.photoUrl; // base64 data URL or http URL

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setS) {

          // ── 생년월일 선택 ──
          Future<void> pickBirthDate() async {
            final picked = await showDatePicker(
              context: sheetCtx,
              initialDate: selectedBirth ?? DateTime(1980, 1, 1),
              firstDate: DateTime(1940),
              lastDate: DateTime.now(),
              helpText: '생년월일 선택',
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.light(primary: AppColors.primary),
                ),
                child: child!,
              ),
            );
            if (picked != null) setS(() => selectedBirth = picked);
          }

          // ── 사진 선택 ──
          Future<void> pickPhoto() async {
            // 웹 환경에서 파일 선택 다이얼로그
            if (kIsWeb) {
              await _pickPhotoWeb((dataUrl) {
                setS(() => photoDataUrl = dataUrl);
              });
            } else {
              if (sheetCtx.mounted) {
                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                  const SnackBar(content: Text('앱 빌드에서는 갤러리 연동이 지원됩니다')),
                );
              }
            }
          }

          // ── 입력 데코레이션 공통 ──
          InputDecoration fieldDeco(String hint, {Widget? suffix}) => InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            suffixIcon: suffix,
          );

          final birthStr = selectedBirth != null
              ? '${selectedBirth!.year}년 ${selectedBirth!.month}월 ${selectedBirth!.day}일'
              : '생년월일 선택';

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 핸들바 ──
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),

                // ── 타이틀 ──
                const Text('내 프로필 편집',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // ── 사진 ──
                Center(
                  child: GestureDetector(
                    onTap: pickPhoto,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                          backgroundImage: photoDataUrl != null && photoDataUrl!.isNotEmpty
                              ? (photoDataUrl!.startsWith('data:')
                                  ? MemoryImage(base64Decode(
                                      photoDataUrl!.split(',').last))
                                  : NetworkImage(photoDataUrl!) as ImageProvider)
                              : null,
                          child: (photoDataUrl == null || photoDataUrl!.isEmpty)
                              ? Text(
                                  nameCtrl.text.isNotEmpty ? nameCtrl.text[0] : '나',
                                  style: const TextStyle(
                                      fontSize: 32, fontWeight: FontWeight.bold,
                                      color: AppColors.primary),
                                )
                              : null,
                        ),
                        Positioned(
                          right: 0, bottom: 0,
                          child: Container(
                            width: 26, height: 26,
                            decoration: const BoxDecoration(
                                color: AppColors.primary, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                          ),
                        ),
                        if (photoDataUrl != null && photoDataUrl!.isNotEmpty)
                          Positioned(
                            left: 0, bottom: 0,
                            child: GestureDetector(
                              onTap: () => setS(() => photoDataUrl = null),
                              child: Container(
                                width: 22, height: 22,
                                decoration: const BoxDecoration(
                                    color: Colors.red, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 12),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text('사진 변경',
                      style: TextStyle(fontSize: 12, color: AppColors.primary.withValues(alpha: 0.8))),
                ),
                const SizedBox(height: 20),

                // ── 이름 ──
                _EditLabel('이름 *'),
                const SizedBox(height: 6),
                TextField(controller: nameCtrl, decoration: fieldDeco('홍길동')),
                const SizedBox(height: 14),

                // ── 성별 ──
                _EditLabel('성별'),
                const SizedBox(height: 6),
                Row(
                  children: ['남', '여'].map((g) {
                    final selected = selectedGender == g;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setS(() => selectedGender = g),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: EdgeInsets.only(right: g == '남' ? 8 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary : AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected ? AppColors.primary : Colors.transparent,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              g == '남' ? '남성' : '여성',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? Colors.white : AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // ── 생년월일 ──
                _EditLabel('생년월일'),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: pickBirthDate,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cake_outlined, size: 16,
                            color: selectedBirth != null
                                ? AppColors.primary
                                : Colors.grey.shade400),
                        const SizedBox(width: 8),
                        Text(
                          birthStr,
                          style: TextStyle(
                              fontSize: 14,
                              color: selectedBirth != null
                                  ? AppColors.textPrimary
                                  : Colors.grey.shade400),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── 휴대폰 ──
                _EditLabel('휴대폰'),
                const SizedBox(height: 6),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: fieldDeco('010-0000-0000'),
                ),
                const SizedBox(height: 14),

                // ── 핸디캡 ──
                _EditLabel('핸디캡'),
                const SizedBox(height: 6),
                TextField(
                  controller: handicapCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: fieldDeco('예: 12.5'),
                ),
                const SizedBox(height: 14),

                // ── 주소 ──
                _EditLabel('주소'),
                const SizedBox(height: 6),
                TextField(
                  controller: addressCtrl,
                  decoration: fieldDeco('서울시 강남구 ...'),
                ),
                const SizedBox(height: 14),

                // ── 본인 소개 ──
                _EditLabel('본인 소개'),
                const SizedBox(height: 6),
                TextField(
                  controller: bioCtrl,
                  maxLines: 3,
                  maxLength: 200,
                  decoration: fieldDeco('골프 경력, 특기 등 자유롭게 소개해주세요'),
                ),
                const SizedBox(height: 10),

                // ── 저장 버튼 ──
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final newName = nameCtrl.text.trim();
                      final newPhone = phoneCtrl.text.trim();
                      final newAddress = addressCtrl.text.trim();
                      final newHandicap = double.tryParse(handicapCtrl.text.trim());

                      final newBio = bioCtrl.text.trim();
                      final updated = member.copyWith(
                        name: newName.isNotEmpty ? newName : member.name,
                        gender: selectedGender,
                        birthDate: selectedBirth,
                        phone: newPhone.isNotEmpty ? newPhone : member.phone,
                        address: newAddress.isNotEmpty ? newAddress : member.address,
                        handicap: newHandicap ?? member.handicap,
                        bio: newBio.isNotEmpty ? newBio : member.bio,
                        photoUrl: (photoDataUrl != null && photoDataUrl!.isNotEmpty)
                            ? photoDataUrl
                            : member.photoUrl,
                        clearPhoto: photoDataUrl == null,
                      );
                      provider.updateMember(updated);
                      Navigator.pop(sheetCtx);
                      messenger.showSnackBar(
                        SnackBar(
                          content: const Row(children: [
                            Icon(Icons.check_circle, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text('프로필이 업데이트되었습니다'),
                          ]),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('저장',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── 웹 파일 선택 헬퍼 ──────────────────────────────────────
  static Future<void> _pickPhotoWeb(void Function(String dataUrl) onPicked) async {
    try {
      await _ProfilePhotoWebPicker.pick(onPicked);
    } catch (_) {
      // 지원되지 않는 환경
    }
  }

  void _confirmAppWithdraw(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade400),
            const SizedBox(width: 8),
            const Text('앱 탈퇴', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          '정말로 탈퇴하시겠습니까?\n\n모든 모임과 데이터가 삭제되며\n이 작업은 되돌릴 수 없습니다.',
          style: TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // mock: 탈퇴 완료 후 로그인 화면으로
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('탈퇴가 완료되었습니다. 이용해 주셔서 감사합니다.'),
                  backgroundColor: Colors.red,
                ),
              );
              Future.delayed(const Duration(seconds: 2), () {
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );
  }
}

class _AccountSectionHeader extends StatelessWidget {
  final String label;
  const _AccountSectionHeader({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
          color: Color(0xFF1E1B4B)));
}

class _ClubWithdrawTile extends StatelessWidget {
  final Club club;
  final ClubProvider provider;
  const _ClubWithdrawTile({required this.club, required this.provider});

  void _enterClub(BuildContext context) {
    provider.selectClubById(club.id);
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => ClubRoomScreen(club: club)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () => _enterClub(context),
        leading: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.sports_golf, color: AppColors.primary, size: 18),
        ),
        title: Text(club.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text('${club.memberCount}명 · ${club.region ?? ""}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => _enterClub(context),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('입장',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => _confirmClubWithdraw(context, club, provider),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade400,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('탈퇴',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClubWithdraw(BuildContext context, Club club, ClubProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${club.name} 탈퇴',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          '"${club.name}" 모임에서 탈퇴하시겠습니까?\n탈퇴 후 재가입은 총무 승인이 필요합니다.',
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // close dialog
              final result = await provider.leaveClub(club.id);
              // 모임찾기 컨트롤러의 오래된 "참여중" 힌트 제거
              if (context.mounted) {
                try {
                  context.read<ClubListController>().updateMembershipHints(
                        myClubIds: provider.myClubs.map((c) => c.id).toSet(),
                      );
                } catch (_) {}
              }
              final message = !result.success
                  ? '탈퇴 처리에 실패했습니다. 다시 시도해 주세요.'
                  : result.treasurerVacated
                      ? '"${club.name}" 탈퇴 완료. 총무 공석 — 회장/부회장에게 선임 안내가 표시됩니다.'
                      : '"${club.name}" 모임에서 탈퇴했습니다.';
              // 남은 다른 모임 홈이 아니라 플랫폼 홈(내 모임 리스트)으로 이동
              final messenger = ScaffoldMessenger.maybeOf(context);
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true)
                    .pushNamedAndRemoveUntil('/main', (route) => false);
              }
              messenger?.showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor:
                      result.success ? Colors.orange : Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );
  }
}

// ── 광고 탭 ──────────────────────────────────────────────────
class _MyAdTab extends StatelessWidget {
  const _MyAdTab();

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
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final myAds       = provider.myAdApplications('user_me');
        final notifications = provider.myAdNotifications('user_me');
        final activeAds   = myAds.where((a) => a.status == AdStatus.active).toList();
        final pendingPay  = myAds.where((a) => a.status == AdStatus.approved).toList();
        final pendingRev  = myAds.where((a) => a.status == AdStatus.pending).toList();
        final doneAds     = myAds.where((a) =>
            a.status == AdStatus.expired || a.status == AdStatus.rejected).toList();
        final paidAds     = myAds.where((a) => a.status == AdStatus.paid).toList();
        final totalSpend  = myAds
            .where((a) => a.paidAmount != null)
            .fold<int>(0, (s, a) => s + (a.paidAmount ?? 0));
        final unreadCount = provider.unreadAdNotificationCount('user_me');

        if (myAds.isEmpty && notifications.isEmpty) {
          return _EmptyAdPage();
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _AdDashboardCard(
              activeCount:  activeAds.length,
              pendingCount: pendingPay.length + pendingRev.length + paidAds.length,
              totalSpend:   totalSpend,
              unreadCount:  unreadCount,
            ),
            const SizedBox(height: 20),
            if (activeAds.isNotEmpty) ...[
              _SectionHeader(icon: Icons.broadcast_on_personal,
                  iconColor: AppColors.success, label: '게재 중', count: activeAds.length),
              const SizedBox(height: 8),
              ...activeAds.map((ad) => _MyAdCard(ad: ad, fmt: _fmt)),
              const SizedBox(height: 16),
            ],
            if (pendingPay.isNotEmpty) ...[
              _SectionHeader(icon: Icons.payment,
                  iconColor: AppColors.primary, label: '결제 대기',
                  count: pendingPay.length, badge: '빠른 결제 필요'),
              const SizedBox(height: 8),
              ...pendingPay.map((ad) => _MyAdCard(ad: ad, fmt: _fmt)),
              const SizedBox(height: 16),
            ],
            if (paidAds.isNotEmpty) ...[
              _SectionHeader(icon: Icons.image_outlined,
                  iconColor: Colors.deepPurple, label: '이미지 업로드 대기', count: paidAds.length),
              const SizedBox(height: 8),
              ...paidAds.map((ad) => _MyAdCard(ad: ad, fmt: _fmt)),
              const SizedBox(height: 16),
            ],
            if (pendingRev.isNotEmpty) ...[
              _SectionHeader(icon: Icons.hourglass_top_rounded,
                  iconColor: Colors.amber.shade700, label: '검토 대기', count: pendingRev.length),
              const SizedBox(height: 8),
              ...pendingRev.map((ad) => _MyAdCard(ad: ad, fmt: _fmt)),
              const SizedBox(height: 16),
            ],
            if (doneAds.isNotEmpty) ...[
              _SectionHeader(icon: Icons.history,
                  iconColor: AppColors.textSecondary, label: '지난 광고', count: doneAds.length),
              const SizedBox(height: 8),
              ...doneAds.map((ad) => _MyAdCard(ad: ad, fmt: _fmt)),
              const SizedBox(height: 16),
            ],
            if (notifications.isNotEmpty) ...[
              _SectionHeader(icon: Icons.notifications_outlined,
                  iconColor: AppColors.textSecondary, label: '알림 내역', count: notifications.length),
              const SizedBox(height: 8),
              ...notifications.map((n) => _AdNotifTile(notif: n)),
            ],
          ],
        );
      },
    );
  }
}

// ── 후원 탭 ──────────────────────────────────────────────────
const _kSpPrimary   = Color(0xFF4F46E5);
const _kSpSecondary = Color(0xFF7C3AED);
const _kSpBg        = Color(0xFFF5F3FF);

class _MySponsorTab extends StatelessWidget {
  const _MySponsorTab();

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
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final mySponsors = provider.mySponsorApplications('user_me');
        final notifications = provider.myAdNotifications('user_me')
            .where((n) => n.adApplicationId?.startsWith('sp') == true).toList();

        if (mySponsors.isEmpty && notifications.isEmpty) {
          return _EmptySponsorPage();
        }

        final activeSponsors  = mySponsors.where((s) => s.status == SponsorStatus.active).toList();
        final approvedSponsors = mySponsors.where((s) => s.status == SponsorStatus.approved).toList();
        final paidSponsors    = mySponsors.where((s) => s.status == SponsorStatus.paid).toList();
        final pendingSponsors = mySponsors.where((s) => s.status == SponsorStatus.pending).toList();
        final doneSponsors    = mySponsors.where((s) =>
            s.status == SponsorStatus.expired || s.status == SponsorStatus.rejected).toList();

        final totalSpend = mySponsors
            .where((s) => s.paidAmount != null)
            .fold<int>(0, (sum, s) => sum + (s.paidAmount ?? 0));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // ── 후원 대시보드 ──────────────────────────────
            _SponsorDashboardCard(
              activeCount:  activeSponsors.length,
              pendingCount: approvedSponsors.length + paidSponsors.length + pendingSponsors.length,
              totalSpend:   totalSpend,
            ),
            const SizedBox(height: 20),

            // ── 후원 중 ───────────────────────────────────
            if (activeSponsors.isNotEmpty) ...[
              _SpSectionHeader(icon: Icons.volunteer_activism,
                  iconColor: _kSpPrimary, label: '후원 중', count: activeSponsors.length),
              const SizedBox(height: 8),
              ...activeSponsors.map((s) => _MySponsorCard(sponsor: s, fmt: _fmt)),
              const SizedBox(height: 16),
            ],

            // ── 결제 대기 ─────────────────────────────────
            if (approvedSponsors.isNotEmpty) ...[
              _SpSectionHeader(icon: Icons.payment,
                  iconColor: _kSpPrimary, label: '결제 대기',
                  count: approvedSponsors.length, badge: '입금 후 후원 시작'),
              const SizedBox(height: 8),
              ...approvedSponsors.map((s) => _MySponsorCard(sponsor: s, fmt: _fmt)),
              const SizedBox(height: 16),
            ],

            // ── 입금 확인 중 ───────────────────────────────
            if (paidSponsors.isNotEmpty) ...[
              _SpSectionHeader(icon: Icons.hourglass_bottom,
                  iconColor: _kSpSecondary, label: '입금 확인 중', count: paidSponsors.length),
              const SizedBox(height: 8),
              ...paidSponsors.map((s) => _MySponsorCard(sponsor: s, fmt: _fmt)),
              const SizedBox(height: 16),
            ],

            // ── 검토 대기 ─────────────────────────────────
            if (pendingSponsors.isNotEmpty) ...[
              _SpSectionHeader(icon: Icons.hourglass_top_rounded,
                  iconColor: Colors.amber.shade700, label: '검토 대기', count: pendingSponsors.length),
              const SizedBox(height: 8),
              ...pendingSponsors.map((s) => _MySponsorCard(sponsor: s, fmt: _fmt)),
              const SizedBox(height: 16),
            ],

            // ── 완료 / 거절 ───────────────────────────────
            if (doneSponsors.isNotEmpty) ...[
              _SpSectionHeader(icon: Icons.history,
                  iconColor: AppColors.textSecondary, label: '지난 후원', count: doneSponsors.length),
              const SizedBox(height: 8),
              ...doneSponsors.map((s) => _MySponsorCard(sponsor: s, fmt: _fmt)),
              const SizedBox(height: 16),
            ],

            // ── 알림 내역 ─────────────────────────────────
            if (notifications.isNotEmpty) ...[
              _SpSectionHeader(icon: Icons.notifications_outlined,
                  iconColor: AppColors.textSecondary, label: '알림 내역', count: notifications.length),
              const SizedBox(height: 8),
              ...notifications.map((n) => _AdNotifTile(notif: n)),
            ],
          ],
        );
      },
    );
  }
}

// ── 후원 탭 빈 상태 ───────────────────────────────────────────
class _EmptySponsorPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: _kSpPrimary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.volunteer_activism_outlined, size: 40, color: _kSpPrimary),
          ),
          const SizedBox(height: 16),
          const Text('신청한 후원이 없습니다',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('모임 상세 화면에서 후원을 신청해 보세요',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _kSpBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kSpPrimary.withValues(alpha: 0.2)),
            ),
            child: const Text(
              '💜  후원하시면 귀사의 홈페이지를 회원들이 방문하게 됩니다',
              style: TextStyle(fontSize: 12, color: _kSpPrimary, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 후원 대시보드 카드 ────────────────────────────────────────
class _SponsorDashboardCard extends StatelessWidget {
  final int activeCount, pendingCount, totalSpend;
  const _SponsorDashboardCard({
    required this.activeCount, required this.pendingCount, required this.totalSpend});

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
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4338CA), _kSpPrimary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: _kSpPrimary.withValues(alpha: 0.35),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.volunteer_activism, color: Colors.white70, size: 18),
                SizedBox(width: 6),
                Text('후원 현황 요약',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _SpDashStat(label: '후원 중', value: '$activeCount건',
                    icon: Icons.volunteer_activism, color: Colors.greenAccent.shade400),
                const SizedBox(width: 12),
                _SpDashStat(label: '진행 중', value: '$pendingCount건',
                    icon: Icons.hourglass_top, color: Colors.amberAccent),
                const SizedBox(width: 12),
                _SpDashStat(label: '총 후원액', value: '${_fmt(totalSpend)}원',
                    icon: Icons.attach_money, color: Colors.white),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpDashStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _SpDashStat({required this.label, required this.value,
      required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── 후원 섹션 헤더 ────────────────────────────────────────────
class _SpSectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final int count;
  final String? badge;
  const _SpSectionHeader({required this.icon, required this.iconColor,
      required this.label, required this.count, this.badge});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count', style: TextStyle(fontSize: 11, color: iconColor,
              fontWeight: FontWeight.bold)),
        ),
        if (badge != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _kSpPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(badge!,
                style: const TextStyle(fontSize: 10, color: _kSpPrimary,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }
}

// ── 내 후원 카드 ──────────────────────────────────────────────
class _MySponsorCard extends StatelessWidget {
  final SponsorApplication sponsor;
  final String Function(int) fmt;
  const _MySponsorCard({required this.sponsor, required this.fmt});

  Color get _statusColor => switch (sponsor.status) {
    SponsorStatus.active   => AppColors.success,
    SponsorStatus.approved => _kSpPrimary,
    SponsorStatus.paid     => _kSpSecondary,
    SponsorStatus.pending  => const Color(0xFFF59E0B),
    SponsorStatus.rejected => AppColors.danger,
    SponsorStatus.expired  => AppColors.textSecondary,
  };

  String get _statusLabel => switch (sponsor.status) {
    SponsorStatus.active   => '후원 중',
    SponsorStatus.approved => '결제 대기',
    SponsorStatus.paid     => '입금 확인 중',
    SponsorStatus.pending  => '검토 대기',
    SponsorStatus.rejected => '거절됨',
    SponsorStatus.expired  => '만료',
  };

  @override
  Widget build(BuildContext context) {
    final daysLeft = sponsor.daysLeft;
    final isNearExpiry = sponsor.status == SponsorStatus.active && daysLeft <= 5;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNearExpiry ? Colors.orange.withValues(alpha: 0.5)
              : sponsor.status == SponsorStatus.active
                  ? _kSpPrimary.withValues(alpha: 0.2)
                  : AppColors.divider,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _kSpBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kSpPrimary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('공식후원',
                      style: TextStyle(fontSize: 10, color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(sponsor.sponsorName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                          color: AppColors.textPrimary)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_statusLabel,
                      style: TextStyle(fontSize: 11, color: _statusColor,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          // 본문
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${sponsor.clubName} · ${sponsor.description}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                _SpConfirmRow('후원 기간', _fmtSponsorPeriod(sponsor)),
                _SpConfirmRow('월 후원금',
                    '${fmt(sponsor.amount)}원 → 모임 수익 ${fmt(sponsor.clubRevenue)}원',
                    bold: true, valueColor: _kSpPrimary),
                _SpConfirmRow('랜딩 URL', sponsor.landingUrl),
                if (isNearExpiry) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('후원이 $daysLeft일 후 만료됩니다. 연장 신청을 고려해 보세요.',
                              style: const TextStyle(fontSize: 12, color: Colors.deepOrange)),
                        ),
                      ],
                    ),
                  ),
                ],
                if (sponsor.status == SponsorStatus.approved) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmPayment(context),
                      icon: const Icon(Icons.credit_card_outlined, size: 16),
                      label: Text('후원금 결제 — ${fmt(sponsor.amount)}원'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kSpPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kSpBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '결제 즉시 공식 후원사로 등록됩니다.',
                      style: TextStyle(fontSize: 11, color: _kSpPrimary, height: 1.5),
                    ),
                  ),
                ],
                if (sponsor.status == SponsorStatus.rejected &&
                    sponsor.rejectReason != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('거절 사유: ${sponsor.rejectReason}',
                        style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmPayment(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('후원금 결제', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          '${sponsor.sponsorName} 후원금\n${fmt(sponsor.amount)}원을 결제하시겠습니까?\n\n'
          '결제 즉시 공식 후원사로 등록됩니다.',
          style: const TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              context.read<ClubProvider>().markSponsorPaid(sponsor.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('결제 완료! 공식 후원사로 등록되었습니다.'),
                  backgroundColor: _kSpPrimary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kSpPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('결제하기'),
          ),
        ],
      ),
    );
  }
}

// ── 후원 확인 행 ──────────────────────────────────────────────
class _SpConfirmRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  final Color? valueColor;
  const _SpConfirmRow(this.label, this.value, {this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(fontSize: 12, color: valueColor ?? AppColors.textPrimary,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          ),
        ],
      ),
    );
  }
}

// ── 빈 상태 ──────────────────────────────────────────────────
class _EmptyAdPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.campaign_outlined, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('신청한 광고가 없습니다',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('모임에서 광고를 신청해 보세요',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── 대시보드 카드 ──────────────────────────────────────────────
class _AdDashboardCard extends StatelessWidget {
  final int activeCount;
  final int pendingCount;
  final int totalSpend;
  final int unreadCount;

  const _AdDashboardCard({
    required this.activeCount,
    required this.pendingCount,
    required this.totalSpend,
    required this.unreadCount,
  });

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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                const Icon(Icons.bar_chart_rounded, color: Colors.white70, size: 18),
                const SizedBox(width: 6),
                const Text('광고 현황 요약',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const Spacer(),
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('알림 $unreadCount건',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _DashStat(
                  label: '게재 중',
                  value: '$activeCount건',
                  icon: Icons.broadcast_on_personal,
                  color: Colors.greenAccent.shade400,
                ),
                const SizedBox(width: 12),
                _DashStat(
                  label: '진행 대기',
                  value: '$pendingCount건',
                  icon: Icons.pending_actions,
                  color: Colors.amber.shade300,
                ),
                const SizedBox(width: 12),
                _DashStat(
                  label: '누적 집행',
                  value: '${_fmt(totalSpend)}원',
                  icon: Icons.receipt_long,
                  color: Colors.lightBlueAccent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _DashStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white60, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── 섹션 헤더 ─────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final int count;
  final String? badge;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.count,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$count',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: iconColor)),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(badge!,
                style: const TextStyle(fontSize: 10, color: AppColors.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }
}

// ── 알림 타일 ─────────────────────────────────────────────────
class _AdNotifTile extends StatelessWidget {
  final AdNotification notif;
  const _AdNotifTile({required this.notif});

  @override
  Widget build(BuildContext context) {
    final isUnread = !notif.isRead;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isUnread ? AppColors.primary.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isUnread ? AppColors.primary.withValues(alpha: 0.2) : AppColors.divider,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8, height: 8,
            margin: const EdgeInsets.only(top: 5, right: 10),
            decoration: BoxDecoration(
              color: isUnread ? AppColors.primary : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notif.body,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  '${notif.sentAt.month}월 ${notif.sentAt.day}일 ${notif.sentAt.hour}:${notif.sentAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 광고 카드 ─────────────────────────────────────────────────
class _MyAdCard extends StatelessWidget {
  final AdApplication ad;
  final String Function(int) fmt;
  const _MyAdCard({required this.ad, required this.fmt});

  // 상태별 색상
  Color get _headerBg {
    switch (ad.status) {
      case AdStatus.active:   return AppColors.success.withValues(alpha: 0.07);
      case AdStatus.approved: return AppColors.primary.withValues(alpha: 0.06);
      case AdStatus.paid:     return Colors.deepPurple.withValues(alpha: 0.06);
      case AdStatus.rejected: return AppColors.danger.withValues(alpha: 0.06);
      default:                return AppColors.background;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 카드 헤더 ────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _headerBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                _SlotBadge(ad.slotType),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(ad.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                _StatusChip(ad.status),
              ],
            ),
          ),

          // ── 카드 본문 ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 기본 정보 행
                Row(
                  children: [
                    Expanded(
                      child: _InfoPill(
                        icon: Icons.group_outlined,
                        text: ad.clubName,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _InfoPill(
                        icon: Icons.calendar_today_outlined,
                        text: '${ad.startMonth.month}월~${ad.endMonth.month - 1}월 (${ad.durationMonths}개월)',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _InfoPill(
                        icon: Icons.receipt_outlined,
                        text: '${fmt(ad.totalFee)}원',
                        highlight: true,
                      ),
                    ),
                    if (ad.paidAt != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InfoPill(
                          icon: Icons.check_circle_outline,
                          text: '결제완료',
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                // ── 상태별 액션 영역 ──────────────────────
                if (ad.status == AdStatus.approved)
                  _PaymentSection(ad: ad, fmt: fmt),

                if (ad.status == AdStatus.paid)
                  _ImageUploadSection(ad: ad),

                if (ad.status == AdStatus.active)
                  _ActiveBanner(ad: ad),

                if (ad.status == AdStatus.rejected)
                  _RejectedBanner(reason: ad.rejectReason),

                if (ad.status == AdStatus.pending)
                  _PendingBanner(),

                if (ad.status == AdStatus.expired)
                  _ExpiredBanner(endMonth: ad.endMonth),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 정보 필 위젯 ──────────────────────────────────────────────
class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlight;
  final Color? color;

  const _InfoPill({
    required this.icon,
    required this.text,
    this.highlight = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? (highlight ? AppColors.primary : AppColors.textSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 5),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12,
                    color: highlight ? c : AppColors.textPrimary,
                    fontWeight: highlight ? FontWeight.bold : FontWeight.normal),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ── 상태별 배너 위젯들 ────────────────────────────────────────
class _ActiveBanner extends StatelessWidget {
  final AdApplication ad;
  const _ActiveBanner({required this.ad});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysLeft = ad.endMonth.difference(now).inDays;
    final isExpiringSoon = daysLeft <= 5 && daysLeft >= 0;

    return Column(
      children: [
        // 게재 중 상태 바
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: isExpiringSoon
                ? Colors.orange.withValues(alpha: 0.08)
                : AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isExpiringSoon
                  ? Colors.orange.withValues(alpha: 0.35)
                  : AppColors.success.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isExpiringSoon ? Icons.timer_outlined : Icons.broadcast_on_personal,
                size: 15,
                color: isExpiringSoon ? Colors.orange.shade700 : AppColors.success,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isExpiringSoon
                      ? '광고 게재 중 · $daysLeft일 후 만료'
                      : '현재 광고 게재 중 · ${daysLeft}일 남음',
                  style: TextStyle(
                    color: isExpiringSoon ? Colors.orange.shade700 : AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              // 연장하기 버튼
              GestureDetector(
                onTap: () => _showExtendDialog(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text('광고연장하기',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // 만료 임박 경고 배너
        if (isExpiringSoon) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '⚠️  광고 만료가 임박했습니다. 연장하지 않으면 배너가 자동 종료됩니다.',
              style: TextStyle(fontSize: 11, color: Colors.deepOrange, height: 1.4),
            ),
          ),
        ],
      ],
    );
  }

  void _showExtendDialog(BuildContext context) {
    int selectedMonths = 1;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text('광고 연장 신청', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${ad.slotType.label} 광고를 연장 신청합니다.\n'
                '현재 만료: ${ad.endMonth.year}년 ${ad.endMonth.month - 1}월 말',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text('연장 개월 수', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [1, 2, 3].map((m) {
                  final selected = selectedMonths == m;
                  return GestureDetector(
                    onTap: () => setDlgState(() => selectedMonths = m),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 60, height: 60,
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? AppColors.primary : AppColors.divider,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$m개월',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: selected ? Colors.white : AppColors.textPrimary,
                              )),
                          Text(
                            '${_fmtFee(ad.slotType.monthlyFee * m)}원',
                            style: TextStyle(
                              fontSize: 10,
                              color: selected ? Colors.white70 : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<ClubProvider>().extendAd(ad.id, selectedMonths);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${selectedMonths}개월 연장 신청이 접수됐습니다. 총무 승인 후 진행됩니다.'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('${_fmtFee(ad.slotType.monthlyFee * selectedMonths)}원 연장 신청'),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtFee(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _PendingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_top_rounded, size: 15, color: Colors.amber.shade700),
          const SizedBox(width: 6),
          Text('총무 검토 중',
              style: TextStyle(color: Colors.amber.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

class _RejectedBanner extends StatelessWidget {
  final String? reason;
  const _RejectedBanner({this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cancel_outlined, size: 14, color: AppColors.danger),
              SizedBox(width: 5),
              Text('거절됨',
                  style: TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.bold)),
            ],
          ),
          if (reason != null && reason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(reason!,
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
          ],
        ],
      ),
    );
  }
}

class _ExpiredBanner extends StatelessWidget {
  final DateTime endMonth;
  const _ExpiredBanner({required this.endMonth});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_busy, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            '${endMonth.year}년 ${endMonth.month - 1}월 종료',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── 결제 섹션 ────────────────────────────────────────────────
class _PaymentSection extends StatelessWidget {
  final AdApplication ad;
  final String Function(int) fmt;
  const _PaymentSection({required this.ad, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              _ConfirmRow('결제 금액', '${fmt(ad.totalFee)}원', bold: true, valueColor: AppColors.primary),
              const SizedBox(height: 4),
              _ConfirmRow('  └ 플랫폼 수수료', '${fmt(ad.platformFee)}원'),
              _ConfirmRow('  └ 모임 정산', '${fmt(ad.clubRevenue)}원'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text('* 승인 후 48시간 내 결제 완료 필요',
            style: TextStyle(fontSize: 11, color: AppColors.danger)),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showPaymentSheet(context),
            icon: const Icon(Icons.payment, size: 18),
            label: Text('${fmt(ad.totalFee)}원 결제하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  void _showPaymentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _PaymentBottomSheet(ad: ad, fmt: fmt),
    );
  }
}

class _PaymentBottomSheet extends StatefulWidget {
  final AdApplication ad;
  final String Function(int) fmt;
  const _PaymentBottomSheet({required this.ad, required this.fmt});

  @override
  State<_PaymentBottomSheet> createState() => _PaymentBottomSheetState();
}

class _PaymentBottomSheetState extends State<_PaymentBottomSheet> {
  int _selectedMethod = 0; // 0=카드 1=계좌이체 2=카카오페이
  final _methods = ['신용/체크카드', '계좌이체', '카카오페이'];
  final _methodIcons = [Icons.credit_card, Icons.account_balance, Icons.chat_bubble];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('결제 수단 선택',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 결제 금액 표시
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('결제 금액', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  Text('${widget.fmt(widget.ad.totalFee)}원',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 결제 수단
            ...List.generate(_methods.length, (i) => GestureDetector(
              onTap: () => setState(() => _selectedMethod = i),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedMethod == i ? AppColors.primary : AppColors.divider,
                    width: _selectedMethod == i ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(_methodIcons[i],
                        color: _selectedMethod == i ? AppColors.primary : AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Text(_methods[i],
                        style: TextStyle(
                            fontWeight: _selectedMethod == i ? FontWeight.bold : FontWeight.normal,
                            color: _selectedMethod == i ? AppColors.primary : AppColors.textPrimary)),
                    const Spacer(),
                    if (_selectedMethod == i)
                      const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  context.read<ClubProvider>().markAdPaid(widget.ad.id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('결제 완료! ${widget.fmt(widget.ad.totalFee)}원 · 이미지를 업로드해 주세요.'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                child: Text('${widget.fmt(widget.ad.totalFee)}원 결제하기'),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('* PG 결제 연동 예정 (현재 개발 중)',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 이미지 업로드 섹션 ─────────────────────────────────────
class _ImageUploadSection extends StatefulWidget {
  final AdApplication ad;
  const _ImageUploadSection({required this.ad});

  @override
  State<_ImageUploadSection> createState() => _ImageUploadSectionState();
}

class _ImageUploadSectionState extends State<_ImageUploadSection> {
  String? _bannerName;
  String? _detailName;

  @override
  Widget build(BuildContext context) {
    final bothUploaded = _bannerName != null && _detailName != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('이미지 업로드',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        _ImagePickerTile(
          label: '배너 이미지 *',
          hint: '권장: 720×200px, JPG/PNG',
          fileName: _bannerName,
          onTap: () => setState(() => _bannerName = 'banner_image.jpg'),
        ),
        const SizedBox(height: 8),
        _ImagePickerTile(
          label: '상세페이지 이미지 *',
          hint: '권장: 720×1280px, JPG/PNG',
          fileName: _detailName,
          onTap: () => setState(() => _detailName = 'detail_image.jpg'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: bothUploaded
                ? () {
                    context.read<ClubProvider>().activateAd(
                          widget.ad.id,
                          bannerImageUrl: _bannerName!,
                          detailImageUrl: _detailName!,
                        );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('광고가 활성화되었습니다! 게재가 시작됩니다.'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.rocket_launch, size: 18),
            label: const Text('광고 게재 시작'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.divider,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

class _ImagePickerTile extends StatelessWidget {
  final String label;
  final String hint;
  final String? fileName;
  final VoidCallback onTap;

  const _ImagePickerTile({
    required this.label,
    required this.hint,
    required this.fileName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final uploaded = fileName != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: uploaded ? AppColors.success.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: uploaded ? AppColors.success.withValues(alpha: 0.4) : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            Icon(
              uploaded ? Icons.check_circle : Icons.image_outlined,
              color: uploaded ? AppColors.success : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(
                    uploaded ? fileName! : hint,
                    style: TextStyle(
                        fontSize: 11,
                        color: uploaded ? AppColors.success : AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              uploaded ? '변경' : '선택',
              style: TextStyle(
                  fontSize: 12,
                  color: uploaded ? AppColors.textSecondary : AppColors.primary,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  공통 위젯
// ════════════════════════════════════════════════════════════

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  static const _labels = ['배너 선택', '기간 선택', '정보 입력', '최종 확인'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        children: List.generate(_labels.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Expanded(
              child: Container(
                height: 2,
                color: i ~/ 2 < current ? AppColors.primary : AppColors.divider,
              ),
            );
          }
          final step = i ~/ 2;
          final done = step < current;
          final active = step == current;
          return Column(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done || active ? AppColors.primary : Colors.white,
                  border: Border.all(
                    color: done || active ? AppColors.primary : AppColors.divider,
                    width: 2,
                  ),
                ),
                child: done
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Center(
                        child: Text('${step + 1}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: active ? Colors.white : AppColors.textSecondary)),
                      ),
              ),
              const SizedBox(height: 4),
              Text(_labels[step],
                  style: TextStyle(
                      fontSize: 10,
                      color: active ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: active ? FontWeight.bold : FontWeight.normal)),
            ],
          );
        }),
      ),
    );
  }
}

class _SlotBadge extends StatelessWidget {
  final AdSlotType slot;
  const _SlotBadge(this.slot);

  @override
  Widget build(BuildContext context) {
    final color = switch (slot) {
      AdSlotType.home     => AppColors.primary,
      AdSlotType.schedule => const Color(0xFF7C3AED),
      AdSlotType.member   => const Color(0xFF0891B2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(slot.label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final AdStatus status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AdStatus.active   => AppColors.success,
      AdStatus.approved => AppColors.primary,
      AdStatus.pending  => const Color(0xFFF59E0B),
      AdStatus.rejected => AppColors.danger,
      AdStatus.paid     => const Color(0xFF7C3AED),
      _                 => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(status.label,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  const _SummaryRow(this.label, this.value, {this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: valueColor ?? AppColors.textPrimary)),
      ],
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  const _ConfirmRow(this.label, this.value, {this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                    color: valueColor ?? AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _InputLabel extends StatelessWidget {
  final String text;
  const _InputLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary));
  }
}

class _ProcessStep extends StatelessWidget {
  final String number;
  final String text;
  const _ProcessStep(this.number, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 18, height: 18,
            decoration: const BoxDecoration(
              color: Color(0xFFF59E0B),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(number,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF92400E))),
        ],
      ),
    );
  }
}

// ── 프로필 편집 라벨 위젯 ─────────────────────────────────────
class _EditLabel extends StatelessWidget {
  final String text;
  const _EditLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      );
}

// ── 웹 사진 선택 헬퍼 ────────────────────────────────────────
class _ProfilePhotoWebPicker {
  static Future<void> pick(void Function(String dataUrl) onPicked) async {
    if (!kIsWeb) return;
    // dart:html 동적 로드 (web only)
    try {
      // ignore: avoid_web_libraries_in_flutter
      final completer = Completer<String?>();
      // JS eval을 통해 file input 생성
      _triggerFilePicker(completer, onPicked);
    } catch (_) {
      // 지원 안 되는 환경
    }
  }

  static void _triggerFilePicker(dynamic completer, void Function(String) onPicked) {
    // Flutter web에서 dart:html 없이 file 선택하는 방법:
    // universal_html 패키지 없이 간단히 처리
    // 실제 앱 빌드 시 image_picker 패키지 연동
  }
}
