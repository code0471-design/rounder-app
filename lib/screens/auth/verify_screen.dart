import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/identity_verification_result.dart';
import '../../theme/app_theme.dart';
import 'portone_identity_screen.dart';

// ════════════════════════════════════════════════════════════
//  VerifyScreen — SMS / PASS 본인인증
//  - SMS: 인증번호 발송 → 4자리 입력 → 확인
//  - PASS: 포트원 본인인증 화면 연결 (키 없으면 개발용 mock)
// ════════════════════════════════════════════════════════════
class VerifyScreen extends StatefulWidget {
  final String name;
  final String phone;
  final double? handicap;

  const VerifyScreen({
    super.key,
    required this.name,
    required this.phone,
    this.handicap,
  });

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  VerifyMethod _selectedMethod = VerifyMethod.sms;

  // ── SMS 관련 ──
  final _codeCtrl = TextEditingController();
  String? _smsError;

  // ── 타이머 (재발송 카운트다운) ──
  Timer? _timer;
  int _resendSeconds = 0;
  bool get _canResend => _resendSeconds == 0;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ── 인증번호 발송 ────────────────────────────────────────
  Future<void> _sendSms() async {
    final auth = context.read<AuthProvider>();
    await auth.sendSmsCode(widget.phone);
    _startResendTimer();
    if (mounted) setState(() => _smsError = null);
  }

  void _startResendTimer() {
    _resendSeconds = 180; // 3분
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds <= 0) {
        t.cancel();
      } else {
        if (mounted) setState(() => _resendSeconds--);
      }
    });
  }

  String get _timerText {
    final m = _resendSeconds ~/ 60;
    final s = _resendSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── SMS 코드 검증 ────────────────────────────────────────
  void _verifySms() {
    final auth = context.read<AuthProvider>();
    final ok = auth.verifySmsCode(_codeCtrl.text.trim());
    if (ok) {
      _completeSignup(VerifyMethod.sms);
    } else {
      setState(() {
        _smsError = kDebugMode
            ? '인증번호가 올바르지 않습니다.\n(디버그) 코드: 1234'
            : '인증번호가 올바르지 않습니다';
      });
    }
  }

  // ── PASS 인증 (포트원 화면 연결) ───────────────────────────
  Future<void> _requestPass() async {
    final result = await Navigator.push<IdentityVerificationResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PortoneIdentityScreen(
          expectedName: widget.name,
          expectedPhone: widget.phone,
        ),
      ),
    );
    if (!mounted || result == null) return;

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? '본인인증에 실패했습니다'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    auth.confirmPassVerified(phone: result.phone ?? widget.phone);
    if (!mounted) return;
    if (kDebugMode && result.usedMock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('개발용 본인인증으로 가입을 완료합니다'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
    _completeSignup(VerifyMethod.pass);
  }

  // ── 회원가입 완료 ─────────────────────────────────────────
  void _completeSignup(VerifyMethod method) {
    final auth = context.read<AuthProvider>();
    auth.setSignupData(
      name: widget.name,
      phone: widget.phone,
      handicap: widget.handicap,
      verifyMethod: method,
    );
    auth.completeSignup();
    // 모든 이전 스택 제거 후 메인으로
    Navigator.of(context).pushNamedAndRemoveUntil('/main', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
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
              '본인인증',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 사용자 정보 카드 ──
                _InfoCard(name: widget.name, phone: widget.phone),
                const SizedBox(height: 28),

                // ── 인증 방법 선택 탭 ──
                const Text(
                  '인증 방법 선택',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                _MethodSelector(
                  selected: _selectedMethod,
                  onChanged: (m) {
                    setState(() {
                      _selectedMethod = m;
                      _smsError = null;
                    });
                    auth.resetVerify();
                  },
                ),
                const SizedBox(height: 28),

                // ── 인증 UI ──
                if (_selectedMethod == VerifyMethod.sms)
                  _SmsSection(
                    auth: auth,
                    codeCtrl: _codeCtrl,
                    error: _smsError,
                    canResend: _canResend,
                    timerText: _timerText,
                    onSendSms: _sendSms,
                    onVerify: _verifySms,
                  )
                else
                  _PassSection(
                    auth: auth,
                    onRequest: _requestPass,
                  ),

                const SizedBox(height: 20),

                // ── 안내 문구 ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 14, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text('인증 안내',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        kDebugMode
                            ? '• 본인 명의 휴대폰으로만 인증 가능합니다\n'
                                '• 인증 정보는 회원 관리 목적으로만 사용됩니다\n'
                                '• (디버그) SMS 인증번호: 1234'
                            : '• 본인 명의 휴대폰으로만 인증 가능합니다\n'
                                '• 인증 정보는 회원 관리 목적으로만 사용됩니다',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.7),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────
//  사용자 정보 카드
// ────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String name;
  final String phone;
  const _InfoCard({required this.name, required this.phone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(phone,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  인증 방법 선택 탭
// ────────────────────────────────────────────────────────────
class _MethodSelector extends StatelessWidget {
  final VerifyMethod selected;
  final ValueChanged<VerifyMethod> onChanged;
  const _MethodSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MethodTab(
            icon: Icons.sms_outlined,
            label: 'SMS 인증',
            sub: '문자 메시지',
            isSelected: selected == VerifyMethod.sms,
            onTap: () => onChanged(VerifyMethod.sms),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MethodTab(
            icon: Icons.verified_user_outlined,
            label: 'PASS 인증',
            sub: '통신사 앱',
            isSelected: selected == VerifyMethod.pass,
            onTap: () => onChanged(VerifyMethod.pass),
          ),
        ),
      ],
    );
  }
}

class _MethodTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final bool isSelected;
  final VoidCallback onTap;

  const _MethodTab({
    required this.icon,
    required this.label,
    required this.sub,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                size: 26),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.textPrimary)),
            Text(sub,
                style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? Colors.white70
                        : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  SMS 인증 섹션
// ────────────────────────────────────────────────────────────
class _SmsSection extends StatelessWidget {
  final AuthProvider auth;
  final TextEditingController codeCtrl;
  final String? error;
  final bool canResend;
  final String timerText;
  final VoidCallback onSendSms;
  final VoidCallback onVerify;

  const _SmsSection({
    required this.auth,
    required this.codeCtrl,
    required this.error,
    required this.canResend,
    required this.timerText,
    required this.onSendSms,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    if (!auth.smsCodeSent) {
      // ── 발송 전 ──
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('인증번호를 발송하려면 아래 버튼을 누르세요.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: auth.isVerifying ? null : onSendSms,
              icon: auth.isVerifying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_outlined, size: 18),
              label: Text(auth.isVerifying ? '발송 중...' : 'SMS 인증번호 발송'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      );
    }

    // ── 발송 후: 코드 입력 ──
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
            const SizedBox(width: 6),
            const Text('인증번호가 발송되었습니다',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: codeCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 10),
                decoration: InputDecoration(
                  hintText: '- - - -',
                  hintStyle: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[400],
                      letterSpacing: 8),
                  filled: true,
                  fillColor: const Color(0xFFF7F8FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.danger, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 타이머
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                timerText,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.danger),
              ),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!,
              style: const TextStyle(fontSize: 12, color: AppColors.danger)),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: onVerify,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text('인증 확인',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: canResend ? onSendSms : null,
            child: Text(
              canResend ? '인증번호 재발송' : '재발송 가능 시간: $timerText',
              style: TextStyle(
                  fontSize: 13,
                  color: canResend ? AppColors.primary : AppColors.textSecondary),
            ),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
//  PASS 인증 섹션
// ────────────────────────────────────────────────────────────
class _PassSection extends StatelessWidget {
  final AuthProvider auth;
  final VoidCallback onRequest;

  const _PassSection({required this.auth, required this.onRequest});

  @override
  Widget build(BuildContext context) {
    if (auth.isVerifying) {
      return Column(
        children: [
          const SizedBox(height: 20),
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 20),
          const Text(
            'PASS 앱에서 인증을 진행해 주세요',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '통신사 PASS 앱에서 인증을 완료해 주세요',
            style: TextStyle(
                fontSize: 12, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // PASS 로고 영역
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.verified_user,
                    color: Colors.white, size: 34),
              ),
              const SizedBox(height: 12),
              const Text('PASS 본인인증',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('SKT · KT · LG U+ 통신사 인증',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'PASS / 휴대폰 본인인증을 진행합니다.\n'
          '포트원 키가 설정되면 실제 인증창이 열리고,\n'
          '키가 없으면 개발용 완료 화면으로 이동합니다.',
          style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.6),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: onRequest,
            icon: const Icon(Icons.verified_user_outlined, size: 20),
            label: const Text('PASS / 휴대폰 본인인증하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}
