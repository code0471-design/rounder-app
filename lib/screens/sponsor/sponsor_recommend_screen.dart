// ════════════════════════════════════════════════════════════
//  후원 AI 추천 화면
//  · Step1: 업체 정보 입력
//  · Step2: AI 분석 (로딩 애니메이션)
//  · Step3: 우선순위별 추천 모임 리스트
// ════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/club_model.dart';
import '../../providers/club_provider.dart';
import '../sponsor/sponsor_screen.dart';

// ── 후원 추천 입력 모델 ────────────────────────────────────
class SponsorRecommendInput {
  final String businessName;
  final String industry;
  final String region;
  final int budgetMin;
  final int budgetMax;
  final String purpose; // 지역 인지도 / 고객 유치 / 브랜드 신뢰 / 네트워킹
  final String benefit; // 후원사가 제공할 혜택 설명
  SponsorRecommendInput({
    required this.businessName,
    required this.industry,
    required this.region,
    required this.budgetMin,
    required this.budgetMax,
    required this.purpose,
    required this.benefit,
  });
}

// ── 추천 결과 모델 ─────────────────────────────────────────
class SponsorRecommendResult {
  final Club club;
  final int score;
  final List<String> reasons;
  final String matchType; // 최적/우수/양호
  SponsorRecommendResult({
    required this.club,
    required this.score,
    required this.reasons,
    required this.matchType,
  });
}

// ── 후원 스코어링 엔진 ────────────────────────────────────
class SponsorScoringEngine {
  // ── 기본 가중치 ────────────────────────────────────────────
  // ① 업종 친화도  : 40점  ← 1순위 (후원 ROI의 핵심)
  // ② 회원 규모    : 25점  ← 2순위 (홈페이지 방문 모수)
  // ③ 지역 일치    : 20점  ← 3순위 (지역 인지도)
  // ④ 모임 충성도  : 10점  ← 4순위 (지속 노출 가능성)
  // ⑤ 예산 적합성  :  5점  ← 5순위
  // 합계           : 100점
  //
  // 목적 선택 시 해당 항목에 +10pt 보너스 (다른 항목에서 차감 없음)
  // → 목적이 순위를 바꾸되, 업종이 여전히 가장 강력한 기준

  // 업종별 "고객층이 겹치는" 모임 업종 (2순위 친화)
  static const Map<String, List<String>> _closeMatch = {
    '의료/의사': ['직장모임', '동창모임'],
    '미용':      ['여성모임', '동창모임'],
    '금융':      ['직장모임', '동창모임', '법조'],
    '부동산':    ['직장모임', '법조', '동창모임'],
    '요식업':    ['동창모임', '가족모임', '직장모임'],
    '법조':      ['직장모임', '동창모임'],
    '교육':      ['동창모임', '가족모임'],
    '건설/건축': ['직장모임', '법조'],
    'IT/테크':   ['직장모임', '동창모임'],
    '교회/종교': ['가족모임', '지역모임'],
    '기타':      ['직장모임', '동창모임'],
  };

  static const _generalTypes = ['지역모임', '직장모임', '동창모임', '가족모임'];

  static const Map<String, String> _purposePreference = {
    '지역 인지도': 'region',
    '고객 유치':   'size',
    '브랜드 신뢰': 'loyalty',
    '네트워킹':    'industry',
  };

  static List<SponsorRecommendResult> score(
    List<Club> clubs,
    SponsorRecommendInput input,
  ) {
    final pref = _purposePreference[input.purpose] ?? 'region';
    final results = <SponsorRecommendResult>[];

    for (final club in clubs) {
      int score = 0;
      final reasons = <String>[];

      // ① 업종 친화도 (40점, 목적='네트워킹'이면 +10 보너스 → 50점)
      final affMax = pref == 'industry' ? 50 : 40;
      final affScore = _calcAffinity(club.industry, input.industry, affMax);
      score += affScore;
      if (affScore == affMax) {
        reasons.add('🤝 ${input.industry} 전문 모임 — 잠재 고객과 완벽 일치');
      } else if (affScore >= (affMax * 0.55).round()) {
        reasons.add('🤝 ${input.industry} 고객층과 높은 친화도');
      } else if (affScore >= (affMax * 0.25).round()) {
        reasons.add('🤝 일반 골프 동호인 네트워크 활용 가능');
      }

      // ② 회원 규모 (25점, 목적='고객 유치'이면 +10 보너스 → 35점)
      final sizeMax = pref == 'size' ? 35 : 25;
      final sizeScore = _calcSize(club.memberCount, sizeMax);
      score += sizeScore;
      if (sizeScore >= (sizeMax * 0.85).round()) {
        reasons.add('👥 ${club.memberCount}명 — 홈페이지 방문 기대 높음');
      } else if (sizeScore >= (sizeMax * 0.55).round()) {
        reasons.add('👥 ${club.memberCount}명 — 안정적 후원 노출');
      }

      // ③ 지역 일치 (20점, 목적='지역 인지도'이면 +10 보너스 → 30점)
      final regionMax = pref == 'region' ? 30 : 20;
      final regionScore = _calcRegion(club.region, input.region, regionMax);
      score += regionScore;
      if (regionScore == regionMax) {
        reasons.add('📍 ${input.region} 동일 지역 — 지역 인지도 직접 상승');
      } else if (regionScore >= (regionMax * 0.55).round()) {
        reasons.add('📍 인접 지역 모임 — 광역 후원 효과');
      }

      // ④ 모임 충성도 (10점, 목적='브랜드 신뢰'이면 +10 보너스 → 20점)
      final loyalMax = pref == 'loyalty' ? 20 : 10;
      final loyalScore = _calcLoyalty(club.teamCount, club.memberCount, loyalMax);
      score += loyalScore;
      if (loyalScore >= (loyalMax * 0.8).round()) {
        reasons.add('⭐ 결속력 높은 정기 모임 — 후원사 지속 노출');
      }

      // ⑤ 예산 적합성 (5점)
      final budScore = _calcBudget(input.budgetMin, input.budgetMax);
      score += budScore;
      if (budScore == 5) {
        reasons.add('💰 예산 대비 후원 ROI 최적');
      }

      if (reasons.isEmpty) {
        reasons.add('골프 동호인 네트워크를 통한 브랜드 노출 가능');
      }

      // 목적 보너스를 반영한 100점 기준으로 정규화
      // (보너스 최대 10점 → 전체 최대 110점 → clamp 100)
      final matchType = score >= 75
          ? '최적'
          : score >= 50
              ? '우수'
              : '양호';

      results.add(SponsorRecommendResult(
        club: club,
        score: score.clamp(0, 100),
        reasons: reasons,
        matchType: matchType,
      ));
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  // 업종 친화도: exact(max) > close(55%) > general(25%) > weak(10%)
  static int _calcAffinity(String? clubIndustry, String inputIndustry, int max) {
    if (clubIndustry == null) return (max * 0.1).round();
    if (clubIndustry == inputIndustry) return max;
    final close = _closeMatch[inputIndustry] ?? [];
    if (close.contains(clubIndustry)) return (max * 0.55).round();
    if (_generalTypes.contains(clubIndustry)) return (max * 0.25).round();
    return (max * 0.1).round();
  }

  // 회원 규모
  static int _calcSize(int memberCount, int max) {
    if (memberCount >= 30) return max;
    if (memberCount >= 20) return (max * 0.8).round();
    if (memberCount >= 15) return (max * 0.6).round();
    if (memberCount >= 10) return (max * 0.4).round();
    return (max * 0.2).round();
  }

  // 지역 일치
  static int _calcRegion(String? clubRegion, String inputRegion, int max) {
    if (clubRegion == null) return 0;
    if (inputRegion == '전체') return (max * 0.5).round();
    if (clubRegion == inputRegion) return max;
    const metro = ['서울', '경기', '인천'];
    if (metro.contains(clubRegion) && metro.contains(inputRegion)) {
      return (max * 0.6).round();
    }
    return (max * 0.1).round();
  }

  // 충성도: 팀당 인원 & 팀 수 기반
  static int _calcLoyalty(int teamCount, int memberCount, int max) {
    final perTeam = teamCount > 0 ? memberCount / teamCount : memberCount.toDouble();
    if (teamCount >= 5 && perTeam <= 5) return max;
    if (teamCount >= 3) return (max * 0.75).round();
    if (teamCount >= 2) return (max * 0.5).round();
    return (max * 0.25).round();
  }

  // 예산 적합성
  static int _calcBudget(int budMin, int budMax) {
    const optMin = 100000;
    const optMax = 600000;
    if (budMin <= optMax && budMax >= optMin) return 5;
    if (budMax >= optMin ~/ 2) return 3;
    return 1;
  }
}

// ════════════════════════════════════════════════════════════
//  SponsorRecommendScreen
// ════════════════════════════════════════════════════════════
class SponsorRecommendScreen extends StatefulWidget {
  const SponsorRecommendScreen({super.key});

  @override
  State<SponsorRecommendScreen> createState() => _SponsorRecommendScreenState();
}

class _SponsorRecommendScreenState extends State<SponsorRecommendScreen>
    with SingleTickerProviderStateMixin {
  int _step = 0;

  final _formKey = GlobalKey<FormState>();
  final _bizNameCtrl = TextEditingController();
  final _benefitCtrl = TextEditingController();
  String _industry = '의료/의사';
  String _region = '서울';
  String _purpose = '지역 인지도';
  double _budgetMin = 100000;
  double _budgetMax = 500000;

  List<SponsorRecommendResult> _results = [];
  late AnimationController _dotCtrl;
  late Animation<double> _dotAnim;

  static const _industries = [
    '의료/의사', '미용', '금융', '부동산', '요식업',
    '법조', '교육', '건설/건축', 'IT/테크', '교회/종교', '기타',
  ];
  static const _regions = [
    '전체', '서울', '경기', '인천', '강원',
    '충북', '충남', '대전', '전북', '전남', '광주',
    '경북', '경남', '대구', '울산', '부산', '제주',
  ];
  static const _purposes = [
    '지역 인지도', '고객 유치', '브랜드 신뢰', '네트워킹',
  ];

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
    _benefitCtrl.dispose();
    super.dispose();
  }

  void _runAnalysis() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _step = 1);
    await Future.delayed(const Duration(milliseconds: 2400));

    final provider = context.read<ClubProvider>();
    final input = SponsorRecommendInput(
      businessName: _bizNameCtrl.text.trim(),
      industry: _industry,
      region: _region,
      budgetMin: _budgetMin.toInt(),
      budgetMax: _budgetMax.toInt(),
      purpose: _purpose,
      benefit: _benefitCtrl.text.trim(),
    );

    final results = SponsorScoringEngine.score(provider.allClubs, input);
    setState(() {
      _results = results;
      _step = 2;
    });
  }

  void _reset() => setState(() { _step = 0; _results = []; });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              size: 18, color: Color(0xFF1E1B4B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
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
            const Text('후원 모임 추천',
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
                  foregroundColor: const Color(0xFF4F46E5)),
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
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.volunteer_activism,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('AI 후원 모임 추천',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '업체 정보와 후원 목적을 입력하면\nAI가 최적의 후원 모임을 우선순위별로 추천합니다.\n후원사로 등록되면 회원들이 홈페이지를 방문합니다.',
                    style: TextStyle(
                        color: Colors.white, fontSize: 12, height: 1.5),
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
                label: '업체명 / 후원사명',
                hint: '예: 다다치과, 강남세무법인',
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
              color: const Color(0xFF4F46E5),
              onSelect: (v) => setState(() => _industry = v),
            ),
            const SizedBox(height: 20),

            _sectionTitle('후원 대상 지역'),
            const SizedBox(height: 8),
            _dropdownField(
              value: _region,
              items: _regions,
              icon: Icons.location_on_outlined,
              color: const Color(0xFF4F46E5),
              onChanged: (v) => setState(() => _region = v!),
            ),
            const SizedBox(height: 20),

            _sectionTitle('후원 목적'),
            const SizedBox(height: 6),
            Text(
              '목적에 따라 AI 추천 가중치가 달라집니다',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 10),
            ..._purposes.map((p) => _purposeCard(p)),
            const SizedBox(height: 20),

            _sectionTitle('제공할 혜택 (선택)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _benefitCtrl,
              maxLines: 2,
              decoration: _inputDeco(
                label: '혜택 내용',
                hint: '예: 회원 첫 방문 20% 할인, 무료 상담 제공',
                icon: Icons.card_giftcard,
              ),
            ),
            const SizedBox(height: 20),

            _sectionTitle('월 후원 예산'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmtWon(_budgetMin.toInt()),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4F46E5))),
                Text('~ ${_fmtWon(_budgetMax.toInt())}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4F46E5))),
              ],
            ),
            RangeSlider(
              values: RangeValues(_budgetMin, _budgetMax),
              min: 0,
              max: 3000000,
              divisions: 60,
              activeColor: const Color(0xFF4F46E5),
              inactiveColor:
                  const Color(0xFF4F46E5).withValues(alpha: 0.2),
              onChanged: (v) => setState(() {
                _budgetMin = v.start;
                _budgetMax = v.end;
              }),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0원',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
                Text('300만원',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
            const SizedBox(height: 32),

            // 분석 버튼
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _runAnalysis,
                icon: const Icon(Icons.volunteer_activism, size: 18),
                label: const Text('AI 후원 모임 분석 시작',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
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

  Widget _purposeCard(String p) {
    final isSelected = p == _purpose;
    final icons = {
      '지역 인지도': Icons.location_city,
      '고객 유치': Icons.person_add,
      '브랜드 신뢰': Icons.verified,
      '네트워킹': Icons.handshake,
    };
    final descs = {
      '지역 인지도': '같은 지역 모임 우선 추천',
      '고객 유치': '규모 크고 활발한 모임 우선',
      '브랜드 신뢰': '결속력 높은 정기 모임 우선',
      '네트워킹': '업종 친화도 높은 모임 우선',
    };
    return GestureDetector(
      onTap: () => setState(() => _purpose = p),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4F46E5).withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4F46E5)
                : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icons[p] ?? Icons.star,
                size: 20,
                color: isSelected
                    ? const Color(0xFF4F46E5)
                    : Colors.grey.shade400),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFF1E1B4B))),
                  Text(descs[p] ?? '',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                  size: 18, color: Color(0xFF4F46E5)),
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
      '지역 & 업종 친화도 계산 중...',
      '후원 ROI 시뮬레이션 중...',
      '모임 충성도 평가 중...',
      '최적 후원 모임 선별 중...',
    ];

    return Center(
      key: const ValueKey('loading'),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _dotAnim,
              builder: (_, __) => Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF4F46E5)
                          .withValues(alpha: 0.7 + 0.3 * _dotAnim.value),
                      const Color(0xFF7C3AED),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5)
                          .withValues(alpha: 0.3 * _dotAnim.value),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(Icons.volunteer_activism,
                    size: 42, color: Colors.white),
              ),
            ),
            const SizedBox(height: 32),
            const Text('AI가 최적 후원 모임을 찾고 있습니다',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1B4B))),
            const SizedBox(height: 24),
            ...steps.asMap().entries.map((e) {
              final delay = e.key * 0.15;
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
                            t > 0.8
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 14,
                            color: t > 0.8
                                ? const Color(0xFF4F46E5)
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
    final topThree = _results.take(3).toList();
    final rest = _results.skip(3).toList();

    return CustomScrollView(
      key: const ValueKey('result'),
      slivers: [
        // 헤더
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.volunteer_activism,
                    color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_bizNameCtrl.text} 후원 추천 결과',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '총 ${_results.length}개 모임 · ${_purpose} 목적 기준 분석 완료',
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

        // TOP 3 강조
        if (topThree.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events,
                      size: 16, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 6),
                  const Text('최우선 추천 모임',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1B4B))),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _SponsorResultCard(
                result: topThree[i],
                rank: i + 1,
                bizName: _bizNameCtrl.text,
                isHighlight: true,
              ),
              childCount: topThree.length,
            ),
          ),
        ],

        // 나머지
        if (rest.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  Icon(Icons.list, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text('기타 추천 모임',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600)),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _SponsorResultCard(
                result: rest[i],
                rank: i + 4,
                bizName: _bizNameCtrl.text,
                isHighlight: false,
              ),
              childCount: rest.length,
            ),
          ),
        ],

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
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
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
              child: Text(item,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : Colors.grey.shade700)),
            ),
          );
        }).toList(),
      );

  Widget _dropdownField({
    required String value,
    required List<String> items,
    required IconData icon,
    required Color color,
    required ValueChanged<String?> onChanged,
  }) =>
      Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: value,
                  isExpanded: true,
                  items: items
                      .map((e) =>
                          DropdownMenuItem(value: e, child: Text(e)))
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
//  _SponsorResultCard
// ════════════════════════════════════════════════════════════
class _SponsorResultCard extends StatelessWidget {
  final SponsorRecommendResult result;
  final int rank;
  final String bizName;
  final bool isHighlight;
  const _SponsorResultCard({
    required this.result,
    required this.rank,
    required this.bizName,
    required this.isHighlight,
  });

  @override
  Widget build(BuildContext context) {
    final club = result.club;
    final score = result.score;

    final rankColor = rank == 1
        ? const Color(0xFF4F46E5)
        : rank == 2
            ? const Color(0xFF7C3AED)
            : rank == 3
                ? const Color(0xFF0EA5E9)
                : Colors.grey.shade500;

    final matchColor = result.matchType == '최적'
        ? const Color(0xFF4F46E5)
        : result.matchType == '우수'
            ? const Color(0xFF0EA5E9)
            : Colors.grey.shade600;

    final rankEmoji = rank == 1
        ? '🥇'
        : rank == 2
            ? '🥈'
            : rank == 3
                ? '🥉'
                : '$rank';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isHighlight
            ? Border.all(color: rankColor.withValues(alpha: 0.4), width: 1.5)
            : Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: rankColor.withValues(alpha: isHighlight ? 0.08 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                // 순위
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: rankColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isHighlight ? '$rankEmoji $rank위' : '$rank위',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: rankColor),
                  ),
                ),
                const SizedBox(width: 6),
                // 매칭 타입 뱃지
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: matchColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(result.matchType,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: matchColor)),
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
                                  fontSize: 11,
                                  color: Colors.grey.shade500)),
                          const SizedBox(width: 8),
                          Icon(Icons.people,
                              size: 11, color: Colors.grey.shade500),
                          const SizedBox(width: 2),
                          Text('${club.memberCount}명',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500)),
                          const SizedBox(width: 8),
                          Icon(Icons.groups,
                              size: 11, color: Colors.grey.shade500),
                          const SizedBox(width: 2),
                          Text('${club.teamCount}팀',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500)),
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

          // 점수 바
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

          // 추천 이유
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: result.reasons
                  .map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(r,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                height: 1.4)),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),

          // 하단: 후원 신청 버튼
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
                // 모임 업종 칩
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    club.industry ?? '기타',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF4F46E5),
                        fontWeight: FontWeight.w500),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SponsorApplicationScreen(club: club),
                    ),
                  ),
                  icon: const Icon(Icons.volunteer_activism, size: 14),
                  label: const Text('후원 신청',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
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
