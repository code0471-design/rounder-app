import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/club_model.dart';
import '../../models/member_role.dart';
import '../../theme/app_theme.dart';

class MemberFormScreen extends StatefulWidget {
  /// null이면 신규 등록, 값이 있으면 수정
  final Member? member;
  const MemberFormScreen({super.key, this.member});

  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // 컨트롤러
  final _nameCtrl = TextEditingController();
  final _handicapCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();

  // 선택값
  String _gender = '남';
  String _memberType = ClubMemberRole.regular;
  final Set<String> _roles = {ClubMemberRole.regular};
  DateTime? _birthDate;
  DateTime? _joinDate;

  bool get _isEdit => widget.member != null;

  String get _roleEncoded => ClubMemberRole.encodeRoles(_roles);

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final m = widget.member!;
      _nameCtrl.text = m.name;
      _handicapCtrl.text =
          m.handicap != null ? m.handicap!.toStringAsFixed(0) : '';
      _addressCtrl.text = m.address ?? '';
      _memoCtrl.text = m.memo ?? '';
      _gender = m.gender;
      _memberType = m.memberType == ClubMemberRole.guest
          ? ClubMemberRole.guest
          : ClubMemberRole.regular;
      _roles
        ..clear()
        ..addAll(ClubMemberRole.splitRoles(m.role));
      if (_roles.isEmpty || _memberType == ClubMemberRole.guest) {
        _roles
          ..clear()
          ..add(ClubMemberRole.regular);
      }
      _birthDate = m.birthDate;
      _joinDate = m.joinDate;
    } else {
      _joinDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _handicapCtrl.dispose();
    _addressCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  // ────────────────────────────────
  // 저장
  // ────────────────────────────────
  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final id = _isEdit
        ? widget.member!.id
        : 'm_${now.millisecondsSinceEpoch}';

    final role = _memberType == ClubMemberRole.guest
        ? ClubMemberRole.guest
        : _roleEncoded;
    final member = Member(
      id: id,
      name: _nameCtrl.text.trim(),
      gender: _gender,
      birthDate: _birthDate,
      memberType: _memberType == ClubMemberRole.guest
          ? ClubMemberRole.guest
          : ClubMemberRole.memberTypeForRole(role),
      role: role,
      handicap: _handicapCtrl.text.isNotEmpty
          ? double.tryParse(_handicapCtrl.text)
          : null,
      joinDate: _joinDate,
      address: _addressCtrl.text.trim().isEmpty
          ? null
          : _addressCtrl.text.trim(),
      memo: _memoCtrl.text.trim().isEmpty
          ? null
          : _memoCtrl.text.trim(),
      status: _isEdit ? widget.member!.status : '활성',
    );

    Navigator.pop(context, member);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        title: Text(
          _isEdit ? '회원 수정' : '회원 등록',
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              '저장',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── 사진 영역 ──
            _buildPhotoSection(),
            const SizedBox(height: 20),

            // ── 기본 정보 ──
            _SectionTitle(title: '기본 정보'),
            const SizedBox(height: 10),
            _buildNameField(),
            const SizedBox(height: 12),
            _buildGenderSelector(),
            const SizedBox(height: 12),
            _buildDateField(
              label: '생년월일',
              icon: Icons.cake_outlined,
              date: _birthDate,
              onTap: () => _pickDate(
                context,
                initial: _birthDate ??
                    DateTime(DateTime.now().year - 40),
                firstDate: DateTime(1930),
                lastDate: DateTime.now(),
                onPicked: (d) => setState(() => _birthDate = d),
              ),
            ),
            const SizedBox(height: 20),

            // ── 골프 정보 ──
            _SectionTitle(title: '골프 정보'),
            const SizedBox(height: 10),
            _buildHandicapField(),
            const SizedBox(height: 20),

            // ── 회원 정보 ──
            _SectionTitle(title: '회원 정보'),
            const SizedBox(height: 10),
            _buildMemberTypeSelector(),
            if (_memberType != ClubMemberRole.guest) ...[
              const SizedBox(height: 12),
              _buildRoleSelector(),
            ],
            const SizedBox(height: 12),
            _buildDateField(
              label: '가입일',
              icon: Icons.event_available_outlined,
              date: _joinDate,
              onTap: () => _pickDate(
                context,
                initial: _joinDate ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
                onPicked: (d) => setState(() => _joinDate = d),
              ),
            ),
            const SizedBox(height: 20),

            // ── 기타 ──
            _SectionTitle(title: '기타'),
            const SizedBox(height: 10),
            _buildAddressField(),
            const SizedBox(height: 12),
            _buildMemoField(),
            const SizedBox(height: 32),

            // ── 저장 버튼 ──
            _buildSaveButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────
  // 사진 섹션
  // ────────────────────────────────
  Widget _buildPhotoSection() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              _nameCtrl.text.isNotEmpty ? _nameCtrl.text[0] : '?',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {
                // TODO: 사진 업로드 구현
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('사진 업로드 기능은 준비 중입니다.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt,
                    color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────
  // 이름
  // ────────────────────────────────
  Widget _buildNameField() {
    return _FormCard(
      child: TextFormField(
        controller: _nameCtrl,
        decoration: _inputDeco(label: '이름 *', icon: Icons.person_outline),
        style: const TextStyle(fontSize: 14),
        onChanged: (_) => setState(() {}),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return '이름을 입력해주세요';
          return null;
        },
      ),
    );
  }

  // ────────────────────────────────
  // 성별
  // ────────────────────────────────
  Widget _buildGenderSelector() {
    return _FormCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.wc_outlined,
                size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            const Text('성별',
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
            const Spacer(),
            _ToggleChip(
              label: '남',
              selected: _gender == '남',
              onTap: () => setState(() => _gender = '남'),
            ),
            const SizedBox(width: 8),
            _ToggleChip(
              label: '여',
              selected: _gender == '여',
              onTap: () => setState(() => _gender = '여'),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────
  // 날짜 필드 (공통)
  // ────────────────────────────────
  Widget _buildDateField({
    required String label,
    required IconData icon,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    final text = date != null
        ? '${date.year}.${_z(date.month)}.${_z(date.day)}'
        : '날짜 선택';
    return _FormCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Text(label,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textSecondary)),
              const Spacer(),
              Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: date != null
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight:
                      date != null ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  size: 16, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────
  // 핸디캡
  // ────────────────────────────────
  Widget _buildHandicapField() {
    return _FormCard(
      child: TextFormField(
        controller: _handicapCtrl,
        decoration: _inputDeco(
            label: '핸디캡', icon: Icons.sports_golf),
        style: const TextStyle(fontSize: 14),
        keyboardType: TextInputType.number,
        // 소수점 핸디는 안 쓴다 — 마이페이지·가입 화면과 같은 규칙.
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        validator: (v) {
          if (v != null && v.isNotEmpty) {
            final val = double.tryParse(v);
            if (val == null || val < 0 || val > 54) {
              return '0~54 사이 값을 입력해주세요';
            }
          }
          return null;
        },
      ),
    );
  }

  // ────────────────────────────────
  // 회원 유형
  // ────────────────────────────────
  Widget _buildMemberTypeSelector() {
    return _FormCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.card_membership_outlined,
                size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            const Text('회원 유형',
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
            const Spacer(),
            _ToggleChip(
              label: '정회원',
              selected: _memberType == ClubMemberRole.regular,
              onTap: () => setState(() {
                _memberType = ClubMemberRole.regular;
                if (_roles.isEmpty) _roles.add(ClubMemberRole.regular);
              }),
            ),
            const SizedBox(width: 8),
            _ToggleChip(
              label: '게스트',
              selected: _memberType == ClubMemberRole.guest,
              onTap: () => setState(() {
                _memberType = ClubMemberRole.guest;
                _roles
                  ..clear()
                  ..add(ClubMemberRole.regular);
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleRole(String role) {
    setState(() {
      if (role == ClubMemberRole.regular) {
        _roles
          ..clear()
          ..add(ClubMemberRole.regular);
        return;
      }
      _roles.remove(ClubMemberRole.regular);
      _roles.remove(ClubMemberRole.legacyRegular);
      if (_roles.contains(role)) {
        _roles.remove(role);
        if (_roles.isEmpty) _roles.add(ClubMemberRole.regular);
      } else {
        _roles.add(role);
      }
    });
  }

  // ────────────────────────────────
  // 직책 다중 선택 (겸직·일반 복귀 가능)
  // ────────────────────────────────
  Widget _buildRoleSelector() {
    final options = [
      (ClubMemberRole.president, '회장'),
      (ClubMemberRole.vicePresident, '부회장'),
      (ClubMemberRole.treasurer, '총무'),
      (ClubMemberRole.regular, '일반 회원'),
    ];
    return _FormCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.military_tech_outlined,
                    size: 18, color: AppColors.textSecondary),
                SizedBox(width: 12),
                Text('직책',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((o) {
                final selected = _roles.contains(o.$1) ||
                    (o.$1 == ClubMemberRole.regular &&
                        !ClubMemberRole.isOfficer(_roleEncoded));
                return FilterChip(
                  label: Text(o.$2),
                  selected: selected,
                  onSelected: (_) => _toggleRole(o.$1),
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                  side: BorderSide(
                    color: selected ? AppColors.primary : AppColors.divider,
                  ),
                  backgroundColor: Colors.white,
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              ClubMemberRole.isOfficer(_roleEncoded)
                  ? '선택: $_roleEncoded (겸직 가능 · 총무 교체는 인수인계 권장)'
                  : '일반 회원으로 저장됩니다',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────
  // 주소
  // ────────────────────────────────
  Widget _buildAddressField() {
    return _FormCard(
      child: TextFormField(
        controller: _addressCtrl,
        decoration: _inputDeco(
            label: '주소 (선택)', icon: Icons.location_on_outlined),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  // ────────────────────────────────
  // 메모
  // ────────────────────────────────
  Widget _buildMemoField() {
    return _FormCard(
      child: TextFormField(
        controller: _memoCtrl,
        decoration: _inputDeco(
            label: '메모 (선택)', icon: Icons.notes_outlined),
        style: const TextStyle(fontSize: 14),
        maxLines: 3,
        minLines: 1,
      ),
    );
  }

  // ────────────────────────────────
  // 저장 버튼
  // ────────────────────────────────
  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _save,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: Text(
        _isEdit ? '수정 완료' : '등록 완료',
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ────────────────────────────────
  // 날짜 피커
  // ────────────────────────────────
  Future<void> _pickDate(
    BuildContext context, {
    required DateTime initial,
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) onPicked(picked);
  }

  // ────────────────────────────────
  // 헬퍼
  // ────────────────────────────────
  InputDecoration _inputDeco(
      {required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
          fontSize: 14, color: AppColors.textSecondary),
      prefixIcon:
          Icon(icon, size: 18, color: AppColors.textSecondary),
      border: InputBorder.none,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  String _z(int n) => n.toString().padLeft(2, '0');
}

// ════════════════════════════════════════
// 공통 위젯
// ════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
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
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
