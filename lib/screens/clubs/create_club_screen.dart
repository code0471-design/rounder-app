import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/club_model.dart';
import '../../models/member_role.dart';
import '../../providers/auth_provider.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';

// ════════════════════════════════════════════════════════════
//  CreateClubScreen  (2단계 스텝 폼)
//   Step 1: 모임 기본 정보
//   Step 2: 내 역할 & 최종 확인
// ════════════════════════════════════════════════════════════
class CreateClubScreen extends StatefulWidget {
  const CreateClubScreen({super.key});

  @override
  State<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends State<CreateClubScreen> {
  final _pageController = PageController();
  int _step = 0; // 0: 모임 정보, 1: 내 역할

  // ── Step 1 폼 ──
  final _formKey1 = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();       // 모임 소개 (필수)
  final _customIndustryCtrl = TextEditingController();
  final _teamCountCtrl = TextEditingController(text: '4');

  // 2단계 지역 선택: 1차 시/도, 2차 구/시
  String _sido = '지역다양함';  // 선택된 광역시/도 (초기: 지역다양함)
  String? _sigungu;            // 선택된 구/시 (null = 전체/미선택)
  String get _region {         // 최종 저장되는 지역값
    if (_sido == '지역다양함') return '지역다양함';
    if (_sigungu != null) return '$_sido $_sigungu';
    return _sido;
  }
  String _industry = '지역모임';
  bool _customIndustry = false;

  // ── Step 2 폼 ──
  final _formKey2 = GlobalKey<FormState>();
  /// 직책 중복 선택 가능 (예: 회장·총무)
  final Set<String> _myRoles = {ClubMemberRole.president};
  bool _submitting = false;

  String get _myRoleEncoded => ClubMemberRole.encodeRoles(_myRoles);

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _customIndustryCtrl.dispose();
    _teamCountCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step == 0) {
      if (!_formKey1.currentState!.validate()) return;
      _pageController.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut);
      setState(() => _step = 1);
    }
  }

  void _prevStep() {
    _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut);
    setState(() => _step = 0);
  }

  Future<void> _submit() async {
    if (!_formKey2.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }

    final name = _nameCtrl.text.trim();
    final description = _descCtrl.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모임 이름은 2자 이상 입력해주세요')),
      );
      return;
    }
    if (description.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모임 소개는 10자 이상 입력해주세요')),
      );
      return;
    }
    if (_customIndustry && _customIndustryCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('업종을 직접 입력해주세요')),
      );
      return;
    }

    setState(() => _submitting = true);

    final provider = context.read<ClubProvider>();
    final industryFinal = _customIndustry
        ? _customIndustryCtrl.text.trim()
        : _industry;

    if (_myRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('직책을 하나 이상 선택해주세요')),
      );
      setState(() => _submitting = false);
      return;
    }

    final synced = await provider.createClub(
      name: name,
      region: _region,
      industry: industryFinal,
      teamCount: _teamCountValue,
      myRole: _myRoleEncoded,
      description: description,
    );

    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              synced ? Icons.check_circle : Icons.warning_amber_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                synced
                    ? '\'$name\' 모임이 생성되었습니다!'
                    : '\'$name\' 생성됨 · 어드민 동기화 실패 (어드민에서 동기화 필요)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: synced ? AppColors.success : Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        title: const Text('모임 만들기',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _StepProgressBar(step: _step),
        ),
      ),
      body: Column(
        children: [
          // 단계 표시
          _StepIndicator(step: _step),
          // 폼 페이지
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                _buildStep2(),
              ],
            ),
          ),
          // 하단 버튼
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  Step 1: 모임 기본 정보
  // ════════════════════════════════════════════════════════
  Widget _buildStep1() {
    return Form(
      key: _formKey1,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 모임 이미지
          _buildImagePicker(),
          const SizedBox(height: 20),

          _Label('모임 이름 *'),
          const SizedBox(height: 6),
          _FormCard(
            child: TextFormField(
              controller: _nameCtrl,
              decoration: _deco(hint: '예: 강남 골프회', icon: Icons.group_outlined),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return '모임 이름을 입력해주세요';
                if (t.length < 2) return '2자 이상 입력해주세요';
                if (t.length > 30) return '30자 이내로 입력해주세요';
                return null;
              },
            ),
          ),
          const SizedBox(height: 16),

          _Label('지역 *'),
          const SizedBox(height: 6),
          _buildRegionGrid(),
          const SizedBox(height: 16),

          _Label('주요 업종 *'),
          const SizedBox(height: 6),
          _buildIndustryChips(),
          if (_customIndustry) ...[
            const SizedBox(height: 10),
            _FormCard(
              child: TextFormField(
                controller: _customIndustryCtrl,
                decoration: _deco(
                    hint: '업종 직접 입력 (예: 치과, 스타트업...)',
                    icon: Icons.edit_outlined),
                validator: _customIndustry
                    ? (v) => (v == null || v.trim().isEmpty)
                        ? '업종을 입력해주세요'
                        : null
                    : null,
              ),
            ),
          ],
          const SizedBox(height: 16),

          _Label('팀 수 (1~30)'),
          const SizedBox(height: 4),
          const Text(
            '최대 30팀까지 설정할 수 있습니다. 조편성 때도 수정 가능합니다.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          _buildTeamCountRow(),
          const SizedBox(height: 16),

          _Label('모임 소개 *'),
          const SizedBox(height: 4),
          const Text(
            '모임 찾기에 표시되는 소개글입니다. 모임의 특징·분위기를 알려주세요.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          _FormCard(
            child: TextFormField(
              controller: _descCtrl,
              decoration: _deco(
                  hint: '예: 매월 정기 라운딩으로 친목 도모 및 핸디캡 향상을 목표로 합니다.',
                  icon: Icons.notes_outlined),
              maxLines: 4,
              minLines: 2,
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return '모임 소개를 입력해주세요';
                if (t.length < 10) return '10자 이상 입력해주세요';
                return null;
              },
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── 이미지 피커 ──
  Widget _buildImagePicker() {
    return Center(
      child: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미지 업로드 기능은 준비 중입니다.'),
            duration: Duration(seconds: 2),
          ),
        ),
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1.5,
                style: BorderStyle.solid),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  size: 32,
                  color: AppColors.primary.withValues(alpha: 0.7)),
              const SizedBox(height: 4),
              Text('모임 이미지',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  시/도 → 구/시 2단계 선택 데이터
  // ════════════════════════════════════════════════════════
  static const _kSidoList = [
    '지역다양함',
    '서울', '부산', '대구', '인천', '광주', '대전', '울산', '세종',
    '경기', '강원', '충북', '충남', '전북', '전남', '경북', '경남', '제주',
  ];

  static const _kSigunguMap = <String, List<String>>{
    '서울': ['강남구','서초구','송파구','강동구','마포구','용산구','성동구','광진구',
             '강서구','양천구','영등포구','구로구','동작구','관악구','금천구',
             '종로구','중구','동대문구','중랑구','성북구','강북구','도봉구','노원구',
             '은평구','서대문구'],
    '부산': ['해운대구','수영구','남구','동구','서구','북구','사하구','사상구',
             '금정구','동래구','연제구','부산진구','중구','영도구','강서구','기장군'],
    '대구': ['수성구','달서구','동구','서구','남구','북구','중구','달성군'],
    '인천': ['남동구','부평구','서구','미추홀구','연수구','계양구','동구','중구',
             '강화군','옹진군'],
    '광주': ['광산구','북구','동구','서구','남구'],
    '대전': ['유성구','서구','동구','중구','대덕구'],
    '울산': ['남구','북구','동구','중구','울주군'],
    '세종': ['세종시'],
    '경기': ['수원시','성남시','고양시','용인시','부천시','안산시','화성시','광명시',
             '평택시','시흥시','파주시','김포시','의정부시','남양주시','하남시','구리시',
             '광주시','안양시','군포시','의왕시','과천시','오산시','안성시','이천시',
             '여주시','양평군','가평군','포천시','동두천시','양주시','연천군'],
    '강원': ['춘천시','원주시','강릉시','동해시','태백시','속초시','삼척시',
             '홍천군','횡성군','영월군','평창군','정선군','철원군','화천군',
             '양구군','인제군','고성군','양양군'],
    '충북': ['청주시','충주시','제천시','보은군','옥천군','영동군','증평군',
             '진천군','괴산군','음성군','단양군'],
    '충남': ['천안시','공주시','보령시','아산시','서산시','논산시','계룡시',
             '당진시','금산군','부여군','서천군','청양군','홍성군','예산군','태안군'],
    '전북': ['전주시','군산시','익산시','정읍시','남원시','김제시',
             '완주군','진안군','무주군','장수군','임실군','순창군','고창군','부안군'],
    '전남': ['목포시','여수시','순천시','나주시','광양시',
             '담양군','곡성군','구례군','고흥군','보성군','화순군','장흥군',
             '강진군','해남군','영암군','무안군','함평군','영광군','장성군',
             '완도군','진도군','신안군'],
    '경북': ['포항시','경주시','김천시','안동시','구미시','영주시','영천시',
             '상주시','문경시','경산시','군위군','의성군','청송군','영양군',
             '영덕군','청도군','고령군','성주군','칠곡군','예천군','봉화군',
             '울진군','울릉군'],
    '경남': ['창원시','진주시','통영시','사천시','김해시','밀양시','거제시',
             '양산시','의령군','함안군','창녕군','고성군','남해군','하동군',
             '산청군','함양군','거창군','합천군'],
    '제주': ['제주시','서귀포시'],
  };

  // ── 지역 2단계 선택 UI ──
  Widget _buildRegionGrid() {
    final sigunguList = _sido == '지역다양함' ? <String>[] : (_kSigunguMap[_sido] ?? <String>[]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1단계: 광역시/도 드롭다운
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sido,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
              style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500),
              items: _kSidoList.map((s) => DropdownMenuItem(
                value: s,
                child: Row(
                  children: [
                    if (s == '지역다양함') ...[
                      const Icon(Icons.public, size: 14, color: Color(0xFF6366F1)),
                      const SizedBox(width: 6),
                    ],
                    Text(s),
                  ],
                ),
              )).toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _sido = val;
                  _sigungu = null; // 시/도 변경 시 구/시 초기화
                });
              },
            ),
          ),
        ),

        // 2단계: 구/시 드롭다운 (지역다양함이 아닐 때만 표시)
        if (_sido != '지역다양함' && sigunguList.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _sigungu != null ? AppColors.primary : AppColors.divider,
                width: _sigungu != null ? 1.5 : 1.0,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sigungu,
                hint: Text('구/시 선택 (선택사항)',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('전체 (구/시 미선택)',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  ...sigunguList.map((sg) => DropdownMenuItem(
                    value: sg,
                    child: Text(sg),
                  )),
                ],
                onChanged: (val) => setState(() => _sigungu = val),
              ),
            ),
          ),
        ],

        // 선택된 지역 표시 칩
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _sido == '지역다양함'
                ? const Color(0xFF6366F1).withValues(alpha: 0.1)
                : AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _sido == '지역다양함'
                  ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                  : AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _sido == '지역다양함' ? Icons.public : Icons.location_on,
                size: 13,
                color: _sido == '지역다양함' ? const Color(0xFF6366F1) : AppColors.primary,
              ),
              const SizedBox(width: 5),
              Text(
                _region,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _sido == '지역다양함' ? const Color(0xFF6366F1) : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 업종 칩 ──
  Widget _buildIndustryChips() {
    final industries = kIndustries.where((i) => i != '기타').toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...industries.map((ind) {
          final sel = !_customIndustry && _industry == ind;
          return GestureDetector(
            onTap: () => setState(() {
              _industry = ind;
              _customIndustry = false;
            }),
            child: _IndustryChip(label: ind, selected: sel),
          );
        }),
        // 기타 (수기)
        GestureDetector(
          onTap: () => setState(() {
            _industry = '기타';
            _customIndustry = true;
          }),
          child: _IndustryChip(label: '기타 (직접 입력)', selected: _customIndustry),
        ),
      ],
    );
  }

  int get _teamCountValue {
    final n = int.tryParse(_teamCountCtrl.text) ?? 4;
    return n.clamp(1, 30);
  }

  void _setTeamCount(int next) {
    final n = next.clamp(1, 30);
    setState(() => _teamCountCtrl.text = '$n');
  }

  // ── 팀 수 조절 (1~30) ──
  Widget _buildTeamCountRow() {
    final count = _teamCountValue;
    return _FormCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.people_outline,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                const Text('이 모임의 팀 수',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
                const Spacer(),
                Text(
                  '$count팀',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              ),
              child: Slider(
                value: count.toDouble(),
                min: 1,
                max: 30,
                divisions: 29,
                label: '$count팀',
                activeColor: AppColors.primary,
                onChanged: (v) => _setTeamCount(v.round()),
              ),
            ),
            Row(
              children: [
                _CountBtn(
                  icon: Icons.remove,
                  onTap: () => _setTeamCount(count - 1),
                ),
                const Spacer(),
                Text(
                  '최소 1 · 최대 30',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary.withValues(alpha: 0.9),
                  ),
                ),
                const Spacer(),
                _CountBtn(
                  icon: Icons.add,
                  onTap: () => _setTeamCount(count + 1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  Step 2: 내 역할
  // ════════════════════════════════════════════════════════
  Widget _buildStep2() {
    return Form(
      key: _formKey2,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 요약 카드
          _buildSummaryCard(),
          const SizedBox(height: 24),

          _Label('모임에서 나의 직책'),
          const SizedBox(height: 8),
          Text(
            '모임을 만드는 당신은 자동으로 첫 번째 회원이 됩니다. 직책은 중복 선택할 수 있습니다.',
            style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 12),
          _buildDuesNotice(),
          const SizedBox(height: 14),
          _buildRoleSelector(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildDuesNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF8F00), width: 1.5),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.priority_high_rounded,
              size: 20, color: Color(0xFFE65100)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '회비관리는 총무만 가능합니다',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFFE65100),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final industry = _customIndustry
        ? (_customIndustryCtrl.text.trim().isEmpty
            ? '기타'
            : _customIndustryCtrl.text.trim())
        : _industry;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sports_golf, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              const Text('생성될 모임 정보',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _nameCtrl.text.trim().isEmpty ? '(모임 이름 없음)' : _nameCtrl.text.trim(),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _SummaryChip(icon: Icons.location_on_outlined, label: _region),
              _SummaryChip(icon: Icons.business_outlined, label: industry),
              _SummaryChip(
                  icon: Icons.people_outline,
                  label: '${_teamCountCtrl.text.trim().isEmpty ? "4" : _teamCountCtrl.text.trim()}팀'),
            ],
          ),
          if (_descCtrl.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            if (_descCtrl.text.trim().isNotEmpty)
              Text(
                _descCtrl.text.trim(),
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (false) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📌 ',
                      style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Text(
                      '',
                      style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _toggleRole(String role) {
    setState(() {
      if (role == ClubMemberRole.legacyRegular ||
          role == ClubMemberRole.regular) {
        _myRoles
          ..clear()
          ..add(ClubMemberRole.regular);
        return;
      }
      _myRoles.remove(ClubMemberRole.regular);
      _myRoles.remove(ClubMemberRole.legacyRegular);
      if (_myRoles.contains(role)) {
        _myRoles.remove(role);
        if (_myRoles.isEmpty) _myRoles.add(ClubMemberRole.regular);
      } else {
        _myRoles.add(role);
      }
    });
  }

  Widget _buildRoleSelector() {
    final roles = [
      (ClubMemberRole.president, Icons.military_tech, '모임을 대표합니다'),
      (ClubMemberRole.vicePresident, Icons.stars_outlined, '회장을 보좌합니다'),
      (ClubMemberRole.treasurer, Icons.manage_accounts_outlined, '운영 실무·회비를 담당합니다'),
      (ClubMemberRole.regular, Icons.person_outline, '일반 회원으로 참여합니다'),
    ];

    return Column(
      children: [
        ...roles.map((r) {
          final selected = _myRoles.contains(r.$1) ||
              (r.$1 == ClubMemberRole.regular &&
                  _myRoles.contains(ClubMemberRole.legacyRegular));
          return GestureDetector(
            onTap: () => _toggleRole(r.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.07)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.divider,
                  width: selected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ],
              ),
              child: Row(
                children: [
                  Icon(r.$2,
                      size: 24,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.$1 == ClubMemberRole.regular ? '일반' : r.$1,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(r.$3,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 22,
                  ),
                ],
              ),
            ),
          );
        }),
        if (_myRoles.length > 1 ||
            (_myRoles.length == 1 &&
                !_myRoles.contains(ClubMemberRole.regular)))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '선택: ${_myRoleEncoded}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════
  //  하단 버튼
  // ════════════════════════════════════════════════════════
  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      child: Row(
        children: [
          if (_step == 1) ...[
            OutlinedButton(
              onPressed: _prevStep,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(80, 48),
              ),
              child: const Text('이전',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: _submitting
                  ? null
                  : (_step == 0 ? _nextStep : _submit),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: _submitting && _step == 1
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                _step == 0 ? '다음 단계  →' : '🏌️ 모임 만들기',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 헬퍼 ──
  InputDecoration _deco({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          const TextStyle(fontSize: 14, color: AppColors.textSecondary),
      prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
      border: InputBorder.none,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

// ════════════════════════════════════════
//  재사용 위젯
// ════════════════════════════════════════

class _StepProgressBar extends StatelessWidget {
  final int step;
  const _StepProgressBar({required this.step});

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: (step + 1) / 2,
      backgroundColor: Colors.white24,
      color: AppColors.accent,
      minHeight: 4,
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryDark,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StepDot(n: 1, active: step >= 0, label: '모임 정보'),
          Container(
              width: 48, height: 2,
              color: step >= 1
                  ? AppColors.accent
                  : Colors.white24),
          _StepDot(n: 2, active: step >= 1, label: '내 역할'),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int n;
  final bool active;
  final String label;
  const _StepDot(
      {required this.n, required this.active, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: active ? AppColors.accent : Colors.white24,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$n',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: active ? Colors.white : Colors.white54),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: active ? Colors.white : Colors.white38)),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary));
  }
}

class _FormCard extends StatelessWidget {
  final Widget child;
  const _FormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1))
        ],
      ),
      child: child,
    );
  }
}

class _IndustryChip extends StatelessWidget {
  final String label;
  final bool selected;
  const _IndustryChip({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider),
        boxShadow: selected
            ? [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ]
            : [],
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary)),
    );
  }
}

class _CountBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CountBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SummaryChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.white)),
        ],
      ),
    );
  }
}
