import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/business_info_footer.dart';
import 'verify_screen.dart';
import 'login_screen.dart';

// ════════════════════════════════════════════════════════════
//  SignupScreen — 회원가입 (이름 / 전화번호 / 핸디캡)
//  → 다음: VerifyScreen (본인인증)
// ════════════════════════════════════════════════════════════
class SignupScreen extends StatefulWidget {
  /// 초대 경로로 진입 시 클럽 ID 전달 (선택)
  final String? inviteClubId;
  final String? inviteClubName;
  final String? inviteInviterName;
  final String? inviteToken;
  final bool inviteAsGuest;
  final String? inviteReferrerId;
  final String? inviteReferrerName;
  final String? inviteGuestName;

  const SignupScreen({
    super.key,
    this.inviteClubId,
    this.inviteClubName,
    this.inviteInviterName,
    this.inviteToken,
    this.inviteAsGuest = false,
    this.inviteReferrerId,
    this.inviteReferrerName,
    this.inviteGuestName,
  });

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _handicapCtrl = TextEditingController();
  bool _agreeTerms = false;
  bool _agreePrivacy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _handicapCtrl.dispose();
    super.dispose();
  }

  // ── 다음 단계 (본인인증) ──────────────────────────────────
  void _goToVerify() {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeTerms || !_agreePrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이용약관과 개인정보 처리방침에 동의해 주세요'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final handicap = _handicapCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_handicapCtrl.text.trim());

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerifyScreen(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          handicap: handicap,
          inviteClubId: widget.inviteClubId,
          inviteClubName: widget.inviteClubName,
          inviteInviterName: widget.inviteInviterName,
          inviteToken: widget.inviteToken,
          inviteAsGuest: widget.inviteAsGuest,
          inviteReferrerId: widget.inviteReferrerId,
          inviteReferrerName: widget.inviteReferrerName,
          inviteGuestName: widget.inviteGuestName,
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
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '회원가입',
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 초대 배너 (초대 경로일 때만) ──
              if (widget.inviteClubName != null) ...[
                _InviteBanner(clubName: widget.inviteClubName!),
                const SizedBox(height: 20),
              ],

              // ── 진행 단계 표시 ──
              _StepIndicator(current: 1, total: 2),
              const SizedBox(height: 24),

              const Text(
                '기본 정보 입력',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                '골프 모임 가입에 필요한 기본 정보를 입력하세요',
                style:
                    TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),

              // ── 이름 ──
              _FieldLabel(label: '이름', required: true),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: _inputDeco(
                  hint: '홍길동',
                  icon: Icons.person_outline,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '이름을 입력해 주세요';
                  if (v.trim().length < 2) return '이름은 2자 이상이어야 합니다';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── 전화번호 ──
              _FieldLabel(label: '전화번호', required: true),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _PhoneFormatter(),
                ],
                maxLength: 13,
                textInputAction: TextInputAction.next,
                decoration: _inputDeco(
                  hint: '010-0000-0000',
                  icon: Icons.phone_outlined,
                ).copyWith(counterText: ''),
                validator: (v) {
                  final digits =
                      (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                  if (digits.length < 10) return '올바른 전화번호를 입력해 주세요';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── 핸디캡 ──
              _FieldLabel(label: '핸디캡', required: false),
              const SizedBox(height: 4),
              const Text(
                '정확한 핸디캡을 입력하면 모임 팀 구성에 도움이 됩니다',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _handicapCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                textInputAction: TextInputAction.done,
                decoration: _inputDeco(
                  hint: '예: 12 (선택사항)',
                  icon: Icons.sports_golf_outlined,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null; // 선택
                  final val = double.tryParse(v.trim());
                  if (val == null) return '숫자로 입력해 주세요';
                  if (val < 0 || val > 54) return '핸디캡은 0~54 사이로 입력해 주세요';
                  return null;
                },
              ),
              const SizedBox(height: 28),

              // ── 약관 동의 ──
              _AgreeRow(
                label: '[필수] 이용약관 동의',
                value: _agreeTerms,
                onChanged: (v) => setState(() => _agreeTerms = v),
                onTap: () => _showTerms(context, '이용약관'),
              ),
              const SizedBox(height: 10),
              _AgreeRow(
                label: '[필수] 개인정보 처리방침 동의',
                value: _agreePrivacy,
                onChanged: (v) => setState(() => _agreePrivacy = v),
                onTap: () => _showTerms(context, '개인정보 처리방침'),
              ),
              const SizedBox(height: 32),

              // ── 다음 버튼 ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _goToVerify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text(
                    '다음 — 본인인증',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const BusinessInfoFooter(),
              const SizedBox(height: 8),

              // ── 로그인으로 ──
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('이미 계정이 있으신가요?',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[500])),
                    TextButton(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoginScreen()),
                      ),
                      child: const Text(
                        '로그인',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showTerms(BuildContext context, String title) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        height: 320,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Expanded(
              child: SingleChildScrollView(
                child: Text(
                  'ROUNDER 서비스를 이용해 주셔서 감사합니다.\n\n'
                  '본 약관은 골프 모임 관리 앱 ROUNDER의 서비스 이용에 관한 사항을 규정합니다.\n\n'
                  '수집하는 개인정보: 이름, 전화번호, 핸디캡\n'
                  '이용 목적: 회원 식별, 모임 관리, 초대장 발송\n'
                  '보유 기간: 탈퇴 시까지\n\n'
                  '위 내용에 동의하시면 서비스를 이용하실 수 있습니다.',
                  style: TextStyle(fontSize: 13, height: 1.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  단계 인디케이터
// ────────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i + 1 <= current;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: active ? AppColors.primary : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  필드 레이블
// ────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel({required this.label, required this.required});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        if (required) ...[
          const SizedBox(width: 3),
          const Text('*',
              style: TextStyle(fontSize: 13, color: AppColors.danger)),
        ] else
          Text(' (선택)',
              style:
                  TextStyle(fontSize: 11, color: Colors.grey[400])),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
//  약관 동의 행
// ────────────────────────────────────────────────────────────
class _AgreeRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTap;

  const _AgreeRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: value ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: value ? AppColors.primary : const Color(0xFFD1D5DB),
                width: 1.5,
              ),
            ),
            child: value
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textPrimary)),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(40, 30)),
          child: const Text('보기',
              style: TextStyle(fontSize: 12, color: AppColors.primary)),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
//  초대 배너
// ────────────────────────────────────────────────────────────
class _InviteBanner extends StatelessWidget {
  final String clubName;
  const _InviteBanner({required this.clubName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primaryLight.withValues(alpha: 0.1)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Text('⛳', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('골프 모임 초대를 받았습니다!',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.primary)),
                Text(clubName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  전화번호 자동 하이픈 포맷터
// ────────────────────────────────────────────────────────────
class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    String formatted = digits;
    if (digits.length > 3 && digits.length <= 7) {
      formatted = '${digits.substring(0, 3)}-${digits.substring(3)}';
    } else if (digits.length > 7) {
      formatted =
          '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    }
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
