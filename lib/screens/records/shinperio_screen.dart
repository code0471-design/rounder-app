import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/shinperio_calculator.dart';
import '../../theme/app_theme.dart';

// ════════════════════════════════════════════════════════════
//  ShinperioScreen — 신페리오 핸디캡 계산 전용 화면
//
//  흐름 (3단계):
//   Step 1 — 전반 + 후반 사진 동시 업로드 → AI 한 번에 분석
//   Step 2 — 18홀 그리드 확인/수정
//   Step 3 — 신페리오 계산 결과 + 순위
// ════════════════════════════════════════════════════════════

class ShinperioScreen extends StatefulWidget {
  /// 참여 멤버 목록 (id, name)
  final List<ShinperioMemberInfo> members;

  /// 이미 선정된 12홀 (null이면 화면 내부에서 랜덤 선정)
  final List<int>? preSelectedHoles;

  const ShinperioScreen({
    super.key,
    required this.members,
    this.preSelectedHoles,
  });

  @override
  State<ShinperioScreen> createState() => _ShinperioScreenState();
}

class ShinperioMemberInfo {
  final String id;
  final String name;
  const ShinperioMemberInfo({required this.id, required this.name});
}

// ── 내부 상태 ─────────────────────────────────────────────────
// 2단계: input(직접 입력) → result(결과)
enum _Step { input, result }

class _ShinperioScreenState extends State<ShinperioScreen>
    with SingleTickerProviderStateMixin {
  _Step _step = _Step.input;

  // 18홀 편집용 컨트롤러 (이름 → 18개 TextEditingController)
  final Map<String, List<TextEditingController>> _holeCtrl = {};

  // 신페리오 계산 결과
  ShinperioResult? _result;

  // 선정된 12홀 (0-based)
  List<int>? _selectedHoles;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    _initControllers();
    _initRowScrollControllers();

    _selectedHoles = widget.preSelectedHoles ??
        ShinperioCalculator.selectHoles();
  }

  void _initControllers() {
    for (final m in widget.members) {
      _holeCtrl[m.id] = List.generate(18, (_) => TextEditingController());
    }
  }

  // ── 컨트롤러 → 18홀 배열 ──────────────────────────────────
  List<int?> _getHolesFromController(String memberId) {
    final ctrls = _holeCtrl[memberId]!;
    return ctrls.map((c) => int.tryParse(c.text.trim())).toList();
  }

  // ── 신페리오 계산 ──────────────────────────────────────────
  void _calculate() {
    final inputs = widget.members.map((m) {
      return ShinperioInput(
        memberId: m.id,
        memberName: m.name,
        holes: _getHolesFromController(m.id),
      );
    }).toList();

    final result = ShinperioCalculator.calculate(
      inputs,
      selectedHoles: _selectedHoles,
    );

    setState(() {
      _result = result;
      _step = _Step.result;
    });
    _animCtrl
      ..reset()
      ..forward();
  }

  // ── 스텝 이동 ────────────────────────────────────────────
  void _goTo(_Step step) {
    setState(() {
      _step = step;
    });
    _animCtrl
      ..reset()
      ..forward();
  }

  // ════════════════════════════════════════════════════════
  //  빌드
  // ════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('신페리오 계산',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(_stepSubtitle,
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () {
            if (_step == _Step.result) {
              _goTo(_Step.input);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (_step == _Step.input)
            TextButton(
              onPressed: _calculate,
              child: const Text('계산',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
          if (_step == _Step.result && _result != null)
            TextButton(
              onPressed: _saveAndClose,
              child: const Text('저장',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  String get _stepSubtitle {
    switch (_step) {
      case _Step.input:
        return 'Step 1 · 18홀 스코어 입력';
      case _Step.result:
        return 'Step 2 · 신페리오 결과';
    }
  }

  // ── 스텝 인디케이터 (2단계) ─────────────────────────────
  Widget _buildStepIndicator() {
    final steps = ['스코어\n입력', '결과'];
    final currentIndex = _step.index;

    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final stepIdx = i ~/ 2;
            final isCompleted = currentIndex > stepIdx;
            return Expanded(
              child: Container(
                height: 2,
                color: isCompleted
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.3),
              ),
            );
          }
          final stepIdx = i ~/ 2;
          final isActive = stepIdx == currentIndex;
          final isCompleted = stepIdx < currentIndex;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isActive ? 28 : 24,
                height: isActive ? 28 : 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? Colors.white
                      : isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.3),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, size: 14, color: AppColors.primary)
                      : Text('${stepIdx + 1}',
                          style: TextStyle(
                            fontSize: isActive ? 13 : 11,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.5),
                          )),
                ),
              ),
              const SizedBox(height: 4),
              Text(steps[stepIdx],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    color: isActive || isCompleted
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    height: 1.2,
                  )),
            ],
          );
        }),
      ),
    );
  }

  // ── 바디 라우팅 ─────────────────────────────────────────
  Widget _buildBody() {
    switch (_step) {
      case _Step.input:
        return _buildReviewStep();
      case _Step.result:
        return _buildResultStep();
    }
  }

  // ════════════════════════════════════════════════════════
  //  Step 3: 18홀 검토 및 수정
  //  구조: [이름 고정 | 18홀 가로스크롤 | 합계 고정]
  //  동기화: 헤더 ScrollController + 각 행 ScrollController
  //         NotificationListener로 헤더→행 동기화
  // ════════════════════════════════════════════════════════

  // 셀 크기 상수
  static const double _nameW = 52.0;   // 이름 열 너비
  static const double _holeW = 30.0;   // 홀 셀 너비
  static const double _cellH = 44.0;   // 헤더 행 높이 (홀번호+파수 2줄)
  static const double _sumW  = 34.0;   // 합계 열 너비

  // 헤더 스크롤 컨트롤러 (전체 동기화 기준)
  final ScrollController _headerScrollCtrl = ScrollController();
  // 각 행의 스크롤 컨트롤러 (헤더와 동기화됨)
  final List<ScrollController> _rowScrollCtrls = [];
  bool _isSyncingScroll = false;

  void _initRowScrollControllers() {
    // 기존 컨트롤러 dispose
    for (final c in _rowScrollCtrls) c.dispose();
    _rowScrollCtrls.clear();
    // 멤버 수만큼 생성
    for (int i = 0; i < widget.members.length; i++) {
      _rowScrollCtrls.add(ScrollController());
    }
    // 헤더 컨트롤러 리스너 등록
    _headerScrollCtrl.addListener(_onHeaderScroll);
  }

  void _onHeaderScroll() {
    if (_isSyncingScroll) return;
    _isSyncingScroll = true;
    final offset = _headerScrollCtrl.offset;
    for (final rowCtrl in _rowScrollCtrls) {
      if (rowCtrl.hasClients && rowCtrl.offset != offset) {
        rowCtrl.jumpTo(offset);
      }
    }
    _isSyncingScroll = false;
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    for (final ctrls in _holeCtrl.values) {
      for (final c in ctrls) c.dispose();
    }
    _headerScrollCtrl.removeListener(_onHeaderScroll);
    _headerScrollCtrl.dispose();
    for (final c in _rowScrollCtrls) c.dispose();
    super.dispose();
  }

  Widget _buildReviewStep() {
    return Column(
      children: [
        // ── 안내 배너 ─────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.edit_note, color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '파=0  버디=-1  이글=-2  보기=+1  더블=+2',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ),
              GestureDetector(
                onTap: _showSelectedHolesInfo,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary, size: 12),
                      SizedBox(width: 3),
                      Text('선정 홀',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── 그리드 본체 (헤더 + 선수 행) ──────────────────
        Expanded(
          child: Column(
            children: [
              // 헤더 행 (NotificationListener로 드라이브)
              _buildSyncedHeader(),
              const Divider(height: 1, color: Color(0xFF3A3A6B)),
              // 선수 행들
              Expanded(
                child: ListView.builder(
                  itemCount: widget.members.length,
                  itemBuilder: (_, i) =>
                      _buildSyncedMemberRow(widget.members[i], i),
                ),
              ),
            ],
          ),
        ),

        // ── 하단 계산 버튼 ────────────────────────────────
        _buildCalculateButton(),
      ],
    );
  }

  // ── 헤더: 이름칸 고정 + 홀번호 가로스크롤 + 합계 고정 ────────
  Widget _buildSyncedHeader() {
    return Container(
      color: const Color(0xFF1E1B4B),
      height: _cellH,
      child: Row(
        children: [
          // 이름 고정
          Container(
            width: _nameW,
            height: _cellH,
            alignment: Alignment.center,
            child: const Text('이름',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white60)),
          ),
          // 18홀 번호 가로 스크롤 (헤더 — 드라이버)
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                // 헤더 스크롤을 모든 행에 전파
                if (!_isSyncingScroll) {
                  _isSyncingScroll = true;
                  final offset = _headerScrollCtrl.offset;
                  for (final rowCtrl in _rowScrollCtrls) {
                    if (rowCtrl.hasClients && rowCtrl.offset != offset) {
                      rowCtrl.jumpTo(offset);
                    }
                  }
                  _isSyncingScroll = false;
                }
                return false;
              },
              child: SingleChildScrollView(
                controller: _headerScrollCtrl,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Row(
                  children: List.generate(18, (i) {
                    final isSelected = _selectedHoles?.contains(i) ?? false;
                    final isFrontHole = i < 9;
                    return Container(
                      width: _holeW,
                      height: _cellH,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white
                            : (isFrontHole
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.07)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${i + 1}',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.white70)),
                          Text('P${ShinperioCalculator.getPar(i)}',
                              style: TextStyle(
                                  fontSize: 8,
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.7)
                                      : Colors.white38)),
                          if (isSelected)
                            Container(
                              width: 4, height: 4,
                              decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle),
                            ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          // 합계 헤더 고정
          _buildSumHeaderCell('전반'),
          _buildSumHeaderCell('후반'),
          _buildSumHeaderCell('총'),
        ],
      ),
    );
  }

  Widget _buildSumHeaderCell(String label) {
    return Container(
      width: _sumW,
      height: _cellH,
      alignment: Alignment.center,
      color: AppColors.primary,
      child: Text(label,
          style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.white)),
    );
  }

  // ── 선수 행: 이름 고정 + 홀 스크롤(헤더와 동기화) + 합계 고정 ──
  Widget _buildSyncedMemberRow(ShinperioMemberInfo member, int idx) {
    if (idx >= _rowScrollCtrls.length) return const SizedBox.shrink();
    final ctrls = _holeCtrl[member.id]!;
    final rowCtrl = _rowScrollCtrls[idx];
    final isEven = idx.isEven;

    return Container(
      height: _cellH + 4,
      color: isEven ? Colors.white : const Color(0xFFF8F9FA),
      child: Row(
        children: [
          // 이름 고정
          Container(
            width: _nameW,
            height: _cellH + 4,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isEven ? Colors.white : const Color(0xFFF8F9FA),
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Text(
              member.name,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E1B4B)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 18홀 스크롤 (행마다 고유 controller, 헤더와 동기화)
          Expanded(
            child: SingleChildScrollView(
              controller: rowCtrl,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(), // 헤더가 드라이브
              child: Row(
                children: List.generate(18, (i) {
                  final isSelected = _selectedHoles?.contains(i) ?? false;
                  return _HoleScoreCell(
                    ctrl: ctrls[i],
                    isSelected: isSelected,
                    cellW: _holeW,
                    cellH: _cellH,
                  );
                }),
              ),
            ),
          ),
          // 합계 고정 (전반/후반/총)
          _buildSumCell(ctrls, 0, 9),
          _buildSumCell(ctrls, 9, 18),
          _buildTotalCell(ctrls),
        ],
      ),
    );
  }

  Widget _buildSumCell(List<TextEditingController> ctrls, int start, int end) {
    return StatefulBuilder(
      builder: (ctx, setS) {
        int sum = 0;
        bool hasNull = false;
        for (int i = start; i < end; i++) {
          final v = int.tryParse(ctrls[i].text);
          if (v == null) { hasNull = true; } else { sum += v; }
        }
        // 컨트롤러 변경 감지
        for (int i = start; i < end; i++) {
          ctrls[i].addListener(() { if (ctx.mounted) setS(() {}); });
        }
        return Container(
          width: _sumW,
          height: _cellH + 4,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            border: Border(left: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Text(
            hasNull ? '?' : '$sum',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: hasNull ? Colors.grey.shade400 : AppColors.primary),
          ),
        );
      },
    );
  }

  Widget _buildTotalCell(List<TextEditingController> ctrls) {
    return StatefulBuilder(
      builder: (ctx, setS) {
        int total = 0;
        bool hasNull = false;
        for (final c in ctrls) {
          final v = int.tryParse(c.text);
          if (v == null) { hasNull = true; } else { total += v; }
        }
        for (final c in ctrls) {
          c.addListener(() { if (ctx.mounted) setS(() {}); });
        }
        return Container(
          width: _sumW,
          height: _cellH + 4,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primary,
          ),
          child: Text(
            hasNull ? '?' : '$total',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildCalculateButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          // 선정 홀 정보
          if (_selectedHoles != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('신페리오 선정 홀',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    _selectedHoles!
                        .map((i) => '${i + 1}번')
                        .join(', '),
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _calculate,
            icon: const Icon(Icons.calculate, size: 18),
            label: const Text('신페리오 계산',
                style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // 선정 홀 안내 다이얼로그
  void _showSelectedHolesInfo() {
    if (_selectedHoles == null) return;
    final frontHoles = _selectedHoles!.where((i) => i < 9).toList();
    final backHoles = _selectedHoles!.where((i) => i >= 9).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('신페리오 선정 홀',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '앱이 랜덤으로 선정한 12홀입니다.\n이 홀들의 타수로 핸디캡을 계산합니다.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            _InfoRow(label: '전반 선정 (6홀)',
                value: frontHoles.map((i) => '${i + 1}번').join(', ')),
            const SizedBox(height: 8),
            _InfoRow(label: '후반 선정 (6홀)',
                value: backHoles.map((i) => '${i + 1}번').join(', ')),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '핸디캡 = (12홀 합계 × 1.5) - 72\n넷스코어 = 그로스 - 핸디캡',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('확인')),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  Step 4: 신페리오 결과
  // ════════════════════════════════════════════════════════
  Widget _buildResultStep() {
    final result = _result!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타이틀 배너
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const Text('🏆',
                    style: TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                const Text('신페리오 계산 완료',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  '선정 홀: ${result.selectedHoleIndices.map((i) => '${i + 1}번').join(', ')}',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 1위 하이라이트
          if (result.champion != null) _buildChampionCard(result.champion!),

          const SizedBox(height: 14),
          const Text('전체 순위',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1B4B))),
          const SizedBox(height: 8),

          // 순위 리스트
          ...result.players
              .map((p) => _buildRankCard(p, result)),

          const SizedBox(height: 20),

          // 상세 계산 내역
          const Text('상세 계산 내역',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1B4B))),
          const SizedBox(height: 8),
          ...result.players.map((p) => _buildDetailCard(p)),

          const SizedBox(height: 20),

          // 저장 버튼
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _saveAndClose,
              icon: const Icon(Icons.save_alt, size: 18),
              label: const Text('결과 저장 및 시상 연동',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChampionCard(ShinperioPlayerResult p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFD700).withValues(alpha: 0.15),
            const Color(0xFFFFD700).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.5),
            width: 1.5),
      ),
      child: Row(
        children: [
          const Text('🥇', style: TextStyle(fontSize: 40)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('우승',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF5D4037),
                        fontWeight: FontWeight.w600)),
                Text(p.memberName,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1B4B))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('넷 ${p.netScore}',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
              Text('핸디 ${p.handicap.toStringAsFixed(1)}',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankCard(ShinperioPlayerResult p, ShinperioResult result) {
    final rankEmoji = p.rank == 1
        ? '🥇'
        : p.rank == 2
            ? '🥈'
            : p.rank == 3
                ? '🥉'
                : '${p.rank}위';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: p.rank == 1
              ? const Color(0xFFFFD700).withValues(alpha: 0.4)
              : Colors.grey.shade200,
          width: p.rank == 1 ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(rankEmoji,
                style: TextStyle(
                    fontSize: p.rank <= 3 ? 22 : 14,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.memberName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E1B4B))),
                Text(
                  '그로스 ${p.grossScore} · 핸디 ${p.handicap.toStringAsFixed(1)}',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('넷 ${p.netScore}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(ShinperioPlayerResult p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 선수명 + 순위
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(p.memberName[0],
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
              ),
              const SizedBox(width: 8),
              Text(p.memberName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${p.rank}위',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // 홀별 스코어 그리드
          _buildHoleGrid(p),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // 계산 과정
          Row(
            children: [
              _CalcChip(
                  label: '그로스',
                  value: '${p.grossScore}타',
                  color: const Color(0xFF1E1B4B)),
              const SizedBox(width: 6),
              _CalcChip(
                  label: '선정12홀합',
                  value: '${p.selectedSum}타',
                  color: AppColors.primary),
              const SizedBox(width: 6),
              _CalcChip(
                  label: '핸디캡',
                  value: p.handicap.toStringAsFixed(1),
                  color: const Color(0xFF7B1FA2)),
              const SizedBox(width: 6),
              _CalcChip(
                  label: '넷스코어',
                  value: '${p.netScore}',
                  color: AppColors.success,
                  highlight: true),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '핸디 계산: (${p.selectedSum} × 1.5) - 72 = ${p.handicap.toStringAsFixed(1)}',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildHoleGrid(ShinperioPlayerResult p) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(18, (i) {
          final rel = p.holes[i]; // 상대값
          final style = ShinperioCalculator.getHoleStyle(rel);
          final isSelected = p.isSelectedHole(i);

          // 표시 문자열: 파=E, 버디=-1, 이글=-2, 보기=+1, 더블=+2
          String displayText;
          if (rel == null) {
            displayText = '-';
          } else if (rel == 0) {
            displayText = 'E';
          } else if (rel > 0) {
            displayText = '+$rel';
          } else {
            displayText = '$rel';
          }

          return Container(
            width: 30,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Column(
              children: [
                // 홀 번호
                Text('${i + 1}',
                    style: TextStyle(
                        fontSize: 8,
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.shade400,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal)),
                const SizedBox(height: 2),
                // 스코어 셀
                Container(
                  width: 28,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Color(style.bgColor),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey.shade200,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      displayText,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(style.textColor)),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── 저장 & 닫기 ──────────────────────────────────────────
  void _saveAndClose() {
    if (_result == null) return;
    Navigator.pop(context, _result);
  }
}

// ════════════════════════════════════════════════════════════
//  서브 위젯들
// ════════════════════════════════════════════════════════════


class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}


class _HoleScoreCell extends StatefulWidget {
  final TextEditingController ctrl;
  final bool isSelected;
  final double cellW;
  final double cellH;

  const _HoleScoreCell({
    required this.ctrl,
    required this.isSelected,
    this.cellW = 30.0,
    this.cellH = 36.0,
  });

  @override
  State<_HoleScoreCell> createState() => _HoleScoreCellState();
}

class _HoleScoreCellState extends State<_HoleScoreCell> {
  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    widget.ctrl.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ctrl.text는 상대값 문자열 (-2, -1, 0, 1, 2 …)
    final rel = int.tryParse(widget.ctrl.text);
    final style = ShinperioCalculator.getHoleStyle(rel);

    return Container(
      width: widget.cellW,
      height: widget.cellH,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: widget.isSelected
            ? const Color(0xFFE8F5E9)
            : Color(style.bgColor),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: widget.isSelected
              ? AppColors.primary
              : Colors.grey.shade200,
          width: widget.isSelected ? 1.5 : 0.5,
        ),
      ),
      child: TextField(
        controller: widget.ctrl,
        textAlign: TextAlign.center,
        // 상대값: 음수(-1, -2)도 입력 가능
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^-?\d*$')),
        ],
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: widget.isSelected
              ? AppColors.primary
              : Color(style.textColor),
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _CalcChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool highlight;

  const _CalcChip({
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: highlight
              ? color.withValues(alpha: 0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: color.withValues(alpha: highlight ? 0.4 : 0.2)),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade500)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }
}


