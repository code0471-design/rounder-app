// ════════════════════════════════════════════════════════════
//  광고 AI 추천 화면
//  · Step1: 업체 정보 입력
//  · Step2: AI 분석 (로딩 애니메이션)
//  · Step3: 우선순위별 추천 모임 리스트
// ════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/club_model.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';
import 'ad_screen.dart';

// ── 광고 추천 입력 모델 ────────────────────────────────────
class AdRecommendInput {
  final String businessName;
  final String industry;
  final String region;
  final String targetAge;    // 20대/30대/40대/50대이상/전체
  final String targetGender; // 남성/여성/전체
  final int budgetMin;
  final int budgetMax;
  final String goal; // 브랜드인지도 / 방문유도 / 할인제공
  AdRecommendInput({
    required this.businessName,
    required this.industry,
    required this.region,
    required this.targetAge,
    required this.targetGender,
    required this.budgetMin,
    required this.budgetMax,
    required this.goal,
  });
}

// ── 추천 결과 모델 ─────────────────────────────────────────
class AdRecommendResult {
  final Club club;
  final int score;        // 0~100
  final List<String> reasons;
  final int estimatedReach; // 예상 노출 횟수/월
  AdRecommendResult({
    required this.club,
    required this.score,
    required this.reasons,
    required this.estimatedReach,
  });
}

// ── 광고 스코어링 엔진 ────────────────────────────────────
class AdScoringEngine {
  // ── 가중치 ──────────────────────────────────────────────────
  // ① 업종 타겟 적합도 : 40점  ← 1순위 (광고 효과의 핵심)
  // ② 회원 규모        : 25점  ← 2순위 (노출 모수)
  // ③ 지역 일치        : 20점  ← 3순위 (지역 밀착)
  // ④ 활동성(팀 수)    : 10점  ← 4순위 (라운딩 빈도)
  // ⑤ 예산 적합성      :  5점  ← 5순위 (부가)
  // 합계               : 100점

  // 업종별 "직접 타겟" 모임 업종 목록
  // · 1순위(exact): 광고주 업종 = 모임 업종이 완전 일치  → 40점
  // · 2순위(close): 고객층이 겹치는 모임 업종             → 24점
  // · 3순위(weak) : 일반 골프 모임(지역/직장 등)         → 10점
  // · 미매핑       :                                      →  5점
  static const Map<String, List<String>> _closeMatch = {
    '의료/의사': ['직장모임', '동창모임'],   // 고소득 직장인·동창 → 의료 잠재 고객
    '미용':      ['여성모임', '동창모임'],   // 여성·동창 모임 → 미용 관심 높음
    '금융':      ['직장모임', '동창모임', '법조'],
    '부동산':    ['직장모임', '법조', '동창모임'],
    '요식업':    ['동창모임', '가족모임', '직장모임'],
    '법조':      ['직장모임', '동창모임'],
    '교육':      ['동창모임', '가족모임'],
    '건설/건축': ['직장모임', '법조'],
    'IT/테크':   ['직장모임', '동창모임'],
    '기타':      ['직장모임', '동창모임'],
  };

  // 지역모임·직장모임·동창모임처럼 업종 특성이 없는 범용 모임
  static const _generalTypes = ['지역모임', '직장모임', '동창모임', '가족모임'];

  static List<AdRecommendResult> score(
    List<Club> clubs,
    AdRecommendInput input,
  ) {
    final results = <AdRecommendResult>[];

    for (final club in clubs) {
      int score = 0;
      final reasons = <String>[];

      // ① 업종 타겟 적합도 (40점) ─ 1순위
      final affScore = _calcAffinity(club.industry, input.industry);
      score += affScore;
      if (affScore == 40) {
        reasons.add('🎯 ${input.industry} 전문 모임 — 광고 타겟과 완벽 일치');
      } else if (affScore >= 24) {
        reasons.add('🎯 ${input.industry} 잠재 고객층과 높은 친화도');
      } else if (affScore >= 10) {
        reasons.add('🎯 일반 골프 동호인 대상 광고 가능');
      }

      // ② 회원 규모 (25점) ─ 2순위
      final sizeScore = _calcSize(club.memberCount);
      score += sizeScore;
      if (sizeScore >= 22) {
        reasons.add('👥 ${club.memberCount}명 대형 모임 — 광고 노출 극대화');
      } else if (sizeScore >= 15) {
        reasons.add('👥 ${club.memberCount}명 중형 모임 — 안정적 노출 규모');
      } else if (sizeScore >= 8) {
        reasons.add('👥 ${club.memberCount}명 소형 모임 — 밀착 타겟 노출');
      }

      // ③ 지역 일치 (20점) ─ 3순위
      final regionScore = _calcRegion(club.region, input.region);
      score += regionScore;
      if (regionScore == 20) {
        reasons.add('📍 ${input.region} 동일 지역 — 지역 밀착 광고 효과');
      } else if (regionScore >= 12) {
        reasons.add('📍 인접 지역 모임 — 광역 광고 도달 가능');
      }

      // ④ 활동성 (10점) ─ 4순위
      final actScore = _calcActivity(club.teamCount);
      score += actScore;
      if (actScore >= 9) {
        reasons.add('⚡ ${club.teamCount}팀 운영 — 라운딩 빈도 높아 광고 노출 잦음');
      }

      // ⑤ 예산 적합성 (5점) ─ 5순위
      final budScore = _calcBudget(input.budgetMin, input.budgetMax);
      score += budScore;
      if (budScore == 5) {
        reasons.add('💰 예산 대비 광고 효율 최적');
      }

      if (reasons.isEmpty) {
        reasons.add('골프 동호인 대상 광고 노출 가능');
      }

      // 예상 월 노출 = 회원수 × (팀 수 ÷ 2 + 1) × 2
      final reach = club.memberCount * (club.teamCount ~/ 2 + 1) * 2;

      results.add(AdRecommendResult(
        club: club,
        score: score.clamp(0, 100),
        reasons: reasons,
        estimatedReach: reach,
      ));
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  // 업종 친화도: exact(40) > close(24) > general(10) > weak(5)
  static int _calcAffinity(String? clubIndustry, String inputIndustry) {
    if (clubIndustry == null) return 5;
    if (clubIndustry == inputIndustry) return 40;           // 완전 일치
    final close = _closeMatch[inputIndustry] ?? [];
    if (close.contains(clubIndustry)) return 24;            // 고객층 겹침
    if (_generalTypes.contains(clubIndustry)) return 10;    // 범용 모임
    return 5;                                               // 무관
  }

  // 회원 규모: 30명+ = 25점, 계단식
  static int _calcSize(int memberCount) {
    if (memberCount >= 30) return 25;
    if (memberCount >= 20) return 20;
    if (memberCount >= 15) return 15;
    if (memberCount >= 10) return 8;
    return 4;
  }

  // 지역: 동일(20) > 수도권 인접(12) > 전체 선택(10) > 불일치(2)
  static int _calcRegion(String? clubRegion, String inputRegion) {
    if (clubRegion == null) return 0;
    if (inputRegion == '전체') return 10;
    if (clubRegion == inputRegion) return 20;
    const metro = ['서울', '경기', '인천'];
    if (metro.contains(clubRegion) && metro.contains(inputRegion)) return 12;
    return 2;
  }

  // 활동성: 팀 수 기반
  static int _calcActivity(int teamCount) {
    if (teamCount >= 7) return 10;
    if (teamCount >= 5) return 8;
    if (teamCount >= 3) return 5;
    return 2;
  }

  // 예산 적합성
  static int _calcBudget(int budMin, int budMax) {
    const basePrice = 100000;
    if (budMin <= basePrice && basePrice <= budMax) return 5;
    if (budMax >= basePrice ~/ 2) return 3;
    return 1;
  }
}

// ════════════════════════════════════════════════════════════
//  AdRecommendScreen
// ════════════════════════════════════════════════════════════
class AdRecommendScreen extends StatefulWidget {
  const AdRecommendScreen({super.key});

  @override
  State<AdRecommendScreen> createState() => _AdRecommendScreenState();
}

class _AdRecommendScreenState extends State<AdRecommendScreen>
    with SingleTickerProviderStateMixin {
  // Step: 0=입력, 1=로딩, 2=결과
  int _step = 0;

  // 입력 폼
  final _formKey = GlobalKey<FormState>();
  final _bizNameCtrl = TextEditingController();
  String _industry = '의료/의사';
  String _region = '서울';
  String _targetAge = '전체';
  String _targetGender = '전체';
  String _goal = '브랜드 인지도';
  double _budgetMin = 50000;
  double _budgetMax = 500000;

  List<AdRecommendResult> _results = [];
  late AnimationController _dotCtrl;
  late Animation<double> _dotAnim;

  static const _industries = [
    '의료/의사', '미용', '금융', '부동산', '요식업',
    '법조', '교육', '건설/건축', 'IT/테크', '기타',
  ];
  static const _regions = [
    '전체', '서울', '경기', '인천', '강원',
    '충북', '충남', '대전', '전북', '전남', '광주',
    '경북', '경남', '대구', '울산', '부산', '제주',
  ];
  static const _ages = ['전체', '30대', '40대', '50대이상', '20~30대', '40~50대'];
  static const _genders = ['전체', '남성', '여성'];
  static const _goals = ['브랜드 인지도', '매장 방문 유도', '할인 혜택 제공', '서비스 홍보'];

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _dotAnim = CurvedAnimation(parent: _dotCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    _bizNameCtrl.dispose();
    super.dispose();
  }

  void _runAnalysis() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _step = 1); // 로딩

    // 분석 딜레이 (AI 느낌)
    await Future.delayed(const Duration(milliseconds: 2200));

    final provider = context.read<ClubProvider>();
    final input = AdRecommendInput(
      businessName: _bizNameCtrl.text.trim(),
      industry: _industry,
      region: _region,
      targetAge: _targetAge,
      targetGender: _targetGender,
      budgetMin: _budgetMin.toInt(),
      budgetMax: _budgetMax.toInt(),
      goal: _goal,
    );

    final results = AdScoringEngine.score(provider.allClubs, input);
    setState(() {
      _results = results;
      _step = 2;
    });
  }

  void _reset() => setState(() { _step = 0; _results = []; });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18, color: Color(0xFF1E1B4B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6D00), Color(0xFFFFAB40)],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('AI',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5)),
            ),
            const SizedBox(width: 8),
            const Text('광고 모임 추천',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1B4B))),
          ],
        ),
        actions: [
          if (_step == 2)
            TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh, size: 15),
              label: const Text('다시 분석', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF6D00),
              ),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _step == 0
            ? _buildInputStep()
            : _step == 1
                ? _buildLoadingStep()
                : _buildResultStep(),
      ),
    );
  }

  // ── Step 0: 입력 폼 ──────────────────────────────────────
  Widget _buildInputStep() {
    return SingleChildScrollView(
      key: const ValueKey('input'),
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 안내 배너
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6D00), Color(0xFFFFAB40)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      const Text('AI 광고 모임 추천',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '업체 정보를 입력하면 AI가 광고 효과가 높은\n모임을 우선순위별로 추천해드립니다.',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _sectionTitle('업체 기본 정보'),
            const SizedBox(height: 12),

            // 업체명
            TextFormField(
              controller: _bizNameCtrl,
              decoration: _inputDeco(
                label: '업체명 / 브랜드명',
                hint: '예: 강남 스카이치과',
                icon: Icons.business,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '업체명을 입력해 주세요' : null,
            ),
            const SizedBox(height: 14),

            // 업종
            _labelText('업종'),
            const SizedBox(height: 8),
            _chipSelector(
              items: _industries,
              selected: _industry,
              color: const Color(0xFFFF6D00),
              onSelect: (v) => setState(() => _industry = v),
            ),
            const SizedBox(height: 20),

            _sectionTitle('광고 타겟'),
            const SizedBox(height: 12),

            // 지역
            _labelText('광고 집행 지역'),
            const SizedBox(height: 8),
            _dropdownField(
              value: _region,
              items: _regions,
              icon: Icons.location_on_outlined,
              onChanged: (v) => setState(() => _region = v!),
            ),
            const SizedBox(height: 14),

            // 타겟 연령
            _labelText('타겟 연령대'),
            const SizedBox(height: 8),
            _chipSelector(
              items: _ages,
              selected: _targetAge,
              color: const Color(0xFFFF6D00),
              onSelect: (v) => setState(() => _targetAge = v),
            ),
            const SizedBox(height: 14),

            // 타겟 성별
            _labelText('타겟 성별'),
            const SizedBox(height: 8),
            _chipSelector(
              items: _genders,
              selected: _targetGender,
              color: const Color(0xFFFF6D00),
              onSelect: (v) => setState(() => _targetGender = v),
            ),
            const SizedBox(height: 20),

            _sectionTitle('광고 목표'),
            const SizedBox(height: 8),
            _chipSelector(
              items: _goals,
              selected: _goal,
              color: const Color(0xFFFF6D00),
              onSelect: (v) => setState(() => _goal = v),
            ),
            const SizedBox(height: 20),

            _sectionTitle('월 광고 예산'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmtWon(_budgetMin.toInt()),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF6D00))),
                Text('~ ${_fmtWon(_budgetMax.toInt())}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF6D00))),
              ],
            ),
            RangeSlider(
              values: RangeValues(_budgetMin, _budgetMax),
              min: 0,
              max: 2000000,
              divisions: 40,
              activeColor: const Color(0xFFFF6D00),
              inactiveColor: const Color(0xFFFF6D00).withValues(alpha: 0.2),
              onChanged: (v) => setState(() {
                _budgetMin = v.start;
                _budgetMax = v.end;
              }),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0원',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                Text('200만원',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),

            const SizedBox(height: 32),

            // 분석 버튼
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _runAnalysis,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('AI 추천 모임 분석 시작',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6D00),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Step 1: 로딩 ─────────────────────────────────────────
  Widget _buildLoadingStep() {
    final steps = [
      '업체 정보 분석 중...',
      '모임 데이터 스캔 중...',
      '지역 & 업종 매칭 중...',
      '광고 효과 시뮬레이션 중...',
      '최적 모임 선별 중...',
    ];

    return Center(
      key: const ValueKey('loading'),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // AI 아이콘 애니메이션
            AnimatedBuilder(
              animation: _dotAnim,
              builder: (_, __) => Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF6D00)
                          .withValues(alpha: 0.7 + 0.3 * _dotAnim.value),
                      const Color(0xFFFFAB40),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6D00)
                          .withValues(alpha: 0.3 * _dotAnim.value),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome,
                    size: 42, color: Colors.white),
              ),
            ),
            const SizedBox(height: 32),
            const Text('AI가 최적 모임을 찾고 있습니다',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1B4B))),
            const SizedBox(height: 24),
            // 단계별 텍스트
            ...steps.asMap().entries.map((e) {
              final delay = e.key * 0.18;
              return AnimatedBuilder(
                animation: _dotCtrl,
                builder: (_, __) {
                  final t = (_dotCtrl.value - delay).clamp(0.0, 1.0);
                  return Opacity(
                    opacity: t,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            t > 0.8 ? Icons.check_circle : Icons.radio_button_unchecked,
                            size: 14,
                            color: t > 0.8
                                ? const Color(0xFFFF6D00)
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 8),
                          Text(e.value,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: t > 0.8
                                      ? const Color(0xFF1E1B4B)
                                      : Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Step 2: 결과 ─────────────────────────────────────────
  Widget _buildResultStep() {
    return CustomScrollView(
      key: const ValueKey('result'),
      slivers: [
        // 결과 요약 헤더
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6D00), Color(0xFFFFAB40)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_bizNameCtrl.text} 추천 결과',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '총 ${_results.length}개 모임 중 광고 효과 순위 분석 완료',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // 결과 리스트
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _AdResultCard(
              result: _results[i],
              rank: i + 1,
              bizName: _bizNameCtrl.text,
            ),
            childCount: _results.length,
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  // ── 공통 위젯 ────────────────────────────────────────────
  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E1B4B)));

  Widget _labelText(String label) => Text(label,
      style: TextStyle(fontSize: 12, color: Colors.grey.shade600));

  InputDecoration _inputDeco({
    required String label,
    required String hint,
    required IconData icon,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFFFF6D00)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFFF6D00), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  Widget _chipSelector({
    required List<String> items,
    required String selected,
    required Color color,
    required ValueChanged<String> onSelect,
  }) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((item) {
          final isSelected = item == selected;
          return GestureDetector(
            onTap: () => onSelect(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected ? color : Colors.grey.shade300),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2))
                      ]
                    : [],
              ),
              child: Text(
                item,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.grey.shade700),
              ),
            ),
          );
        }).toList(),
      );

  Widget _dropdownField({
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFFFF6D00)),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: value,
                  isExpanded: true,
                  items: items
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      );
}

String _fmtWon(int amount) {
  if (amount == 0) return '0원';
  if (amount >= 10000) return '${(amount ~/ 10000)}만원';
  return '$amount원';
}

// ════════════════════════════════════════════════════════════
//  _AdResultCard — 추천 결과 카드
// ════════════════════════════════════════════════════════════
class _AdResultCard extends StatelessWidget {
  final AdRecommendResult result;
  final int rank;
  final String bizName;
  const _AdResultCard({
    required this.result,
    required this.rank,
    required this.bizName,
  });

  @override
  Widget build(BuildContext context) {
    final club = result.club;
    final score = result.score;

    // 순위별 색상
    final rankColor = rank == 1
        ? const Color(0xFFFF6D00)
        : rank == 2
            ? const Color(0xFF7C3AED)
            : rank == 3
                ? const Color(0xFF0EA5E9)
                : Colors.grey.shade500;

    final rankLabel = rank == 1 ? '🥇 1위' : rank == 2 ? '🥈 2위' : rank == 3 ? '🥉 3위' : '$rank위';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: rank <= 3
            ? Border.all(color: rankColor.withValues(alpha: 0.4), width: 1.5)
            : Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: rankColor.withValues(alpha: rank <= 3 ? 0.08 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ─ 상단: 순위 + 모임명 + 점수 ─
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                // 순위 뱃지
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: rankColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(rankLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: rankColor)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(club.name,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E1B4B))),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 11, color: Colors.grey.shade500),
                          const SizedBox(width: 2),
                          Text('${club.region ?? '-'}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500)),
                          const SizedBox(width: 8),
                          Icon(Icons.people,
                              size: 11, color: Colors.grey.shade500),
                          const SizedBox(width: 2),
                          Text('${club.memberCount}명',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ),
                    ],
                  ),
                ),
                // 점수
                Column(
                  children: [
                    Text('$score',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: rankColor)),
                    Text('/ 100',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
              ],
            ),
          ),

          // ─ 점수 바 ─
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(rankColor),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ─ 추천 이유 ─
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: result.reasons
                  .map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(r,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                      height: 1.4)),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),

          // ─ 예상 노출 + 신청 버튼 ─
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // 예상 노출
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('월 예상 노출',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade500)),
                    Text('약 ${result.estimatedReach}회',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: rankColor)),
                  ],
                ),
                const Spacer(),
                // 광고 신청 버튼
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdApplicationScreen(club: club),
                    ),
                  ),
                  icon: const Icon(Icons.ads_click, size: 14),
                  label: const Text('광고 신청',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6D00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
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
