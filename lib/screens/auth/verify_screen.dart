import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';

// ════════════════════════════════════════════════════════════
//  VerifyScreen — 휴대폰 인증 (카카오 알림톡 인증번호)
// ════════════════════════════════════════════════════════════
class VerifyScreen extends StatefulWidget {
  final String name;
  final String phone;
  final double? handicap;
  final String? inviteClubId;
  final String? inviteClubName;
  final String? inviteInviterName;
  final String? inviteToken;
  final bool inviteAsGuest;
  final String? inviteReferrerId;
  final String? inviteReferrerName;
  final String? inviteGuestName;

  const VerifyScreen({
    super.key,
    required this.name,
    required this.phone,
    this.handicap,
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
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
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

  // ── 인증번호 발송 (카카오 알림톡) ─────────────────────────
  Future<void> _sendSms() async {
    final auth = context.read<AuthProvider>();
    try {
      await auth.sendSmsCode(widget.phone, name: widget.name);
      _startResendTimer();
      if (mounted) setState(() => _smsError = null);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _smsError = e is StateError
            ? e.message
            : '인증번호 알림톡 발송에 실패했습니다. 다시 시도해 주세요.';
      });
    }
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
            ? '인증번호가 올바르지 않습니다.\n(디버그·미설정 시) 코드: 1234'
            : '인증번호가 올바르지 않습니다';
      });
    }
  }

  // ── 회원가입 완료 ─────────────────────────────────────────
  Future<void> _completeSignup(VerifyMethod method) async {
    final auth = context.read<AuthProvider>();
    auth.setSignupData(
      name: widget.name,
      phone: widget.phone,
      handicap: widget.handicap,
      verifyMethod: method,
    );
    final signedUp = auth.completeSignup();

    final clubId = widget.inviteClubId?.trim() ?? '';
    if (clubId.isNotEmpty) {
      final clubs = context.read<ClubProvider>();
      await clubs.switchUser(
        auth.currentUser!.id,
        displayName: auth.currentUser!.name,
      );
      await clubs.joinViaInvite(
        clubId: clubId,
        clubName: widget.inviteClubName,
        asGuest: widget.inviteAsGuest,
        referrerId: widget.inviteReferrerId,
        referrerName: widget.inviteReferrerName,
        displayName: widget.inviteAsGuest &&
                (widget.inviteGuestName?.trim().isNotEmpty ?? false)
            ? widget.inviteGuestName!.trim()
            : widget.name,
      );
      final token = widget.inviteToken?.trim() ?? '';
      if (token.isNotEmpty && token != 'link') {
        auth.markTokenUsed(token);
      }
    }

    if (!mounted) return;
    // 초대 가입도 생년월일은 아직 없다 — 있으면 건너뛴다.
    final next = signedUp.needsGolfProfile ? '/golf-profile' : '/main';
    Navigator.of(context).pushNamedAndRemoveUntil(next, (_) => false);
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
              '휴대폰 인증',
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

                _SmsSection(
                  auth: auth,
                  codeCtrl: _codeCtrl,
                  error: _smsError,
                  canResend: _canResend,
                  timerText: _timerText,
                  onSendSms: _sendSms,
                  onVerify: _verifySms,
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
                            ? '• 입력한 번호로 카카오 알림톡 인증번호를 보냅니다\n'
                                '• 번호는 알림톡·모임 연락에 사용됩니다\n'
                                '• (디버그·미설정 시) 코드: 1234'
                            : '• 입력한 번호로 카카오 알림톡 인증번호를 보냅니다\n'
                                '• 번호는 알림톡·모임 연락에 사용됩니다',
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
              label: Text(auth.isVerifying ? '발송 중...' : '알림톡 인증번호 발송'),
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
