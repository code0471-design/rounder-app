import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/club_provider.dart';
import '../../services/identity_verification_result.dart';
import '../../theme/app_theme.dart';
import 'portone_identity_screen.dart';

/// 소셜 로그인 후 휴대폰 번호가 없을 때 필수 수집 화면
class PhoneRequiredScreen extends StatefulWidget {
  const PhoneRequiredScreen({super.key});

  @override
  State<PhoneRequiredScreen> createState() => _PhoneRequiredScreenState();
}

class _PhoneRequiredScreenState extends State<PhoneRequiredScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  VerifyMethod _method = VerifyMethod.sms;
  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  Timer? _timer;
  int _resendSeconds = 0;

  bool get _canResend => _resendSeconds == 0;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendSeconds = 180;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds <= 0) {
        t.cancel();
      } else if (mounted) {
        setState(() => _resendSeconds--);
      }
    });
  }

  String get _timerText {
    final m = _resendSeconds ~/ 60;
    final s = _resendSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _sendSms() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      await auth.sendSmsCode(_phoneCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _busy = false;
      });
      _startResendTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '인증번호 발송에 실패했습니다. 다시 시도해 주세요.';
      });
    }
  }

  Future<void> _verifySmsAndSave() async {
    final auth = context.read<AuthProvider>();
    final ok = auth.verifySmsCode(_codeCtrl.text.trim());
    if (!ok) {
      setState(() {
        _error = kDebugMode
            ? '인증번호가 올바르지 않습니다.\n(디버그) 코드: 1234'
            : '인증번호가 올바르지 않습니다';
      });
      return;
    }
    await _savePhone(VerifyMethod.sms);
  }

  Future<void> _requestPass() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final name = auth.currentUser?.name ?? '회원';
    final phone = _phoneCtrl.text.trim();

    final result = await Navigator.push<IdentityVerificationResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PortoneIdentityScreen(
          expectedName: name,
          expectedPhone: phone,
        ),
      ),
    );
    if (!mounted || result == null) return;

    if (!result.success) {
      setState(() {
        _error = result.errorMessage ?? '본인인증에 실패했습니다';
      });
      return;
    }

    auth.confirmPassVerified(phone: result.phone ?? phone);
    await _savePhone(VerifyMethod.pass, phoneOverride: result.phone ?? phone);
  }

  Future<void> _savePhone(
    VerifyMethod method, {
    String? phoneOverride,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final phone = phoneOverride ?? _phoneCtrl.text.trim();
      final user = await auth.attachPhoneToCurrentUser(
        phone: phone,
        verifyMethod: method,
      );
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _busy = false;
          _error = '전화번호 저장에 실패했습니다.';
        });
        return;
      }

      // 로컬 모임 명단에도 반영
      try {
        context.read<ClubProvider>().syncAuthUserPhone(user.phone);
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (_) => false);
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '전화번호 저장 중 오류가 발생했습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name = auth.greetingName;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          '휴대폰 번호 등록',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name님, 휴대폰 번호가 필요합니다',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '모임 알림·회비·초대를 위해 휴대폰 번호를 등록해 주세요.\n카카오 로그인만으로는 번호가 전달되지 않습니다.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  '휴대폰 번호',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneCtrl,
                  enabled: !_busy,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _PhoneFormatter(),
                  ],
                  maxLength: 13,
                  decoration: InputDecoration(
                    hintText: '010-0000-0000',
                    counterText: '',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) {
                    final digits =
                        (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                    if (digits.length < 10) {
                      return '올바른 전화번호를 입력해 주세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  '인증 방법',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MethodChip(
                        label: 'SMS 인증',
                        selected: _method == VerifyMethod.sms,
                        onTap: () => setState(() {
                          _method = VerifyMethod.sms;
                          _error = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MethodChip(
                        label: 'PASS 인증',
                        selected: _method == VerifyMethod.pass,
                        onTap: () => setState(() {
                          _method = VerifyMethod.pass;
                          _error = null;
                          _codeSent = false;
                        }),
                      ),
                    ),
                  ],
                ),
                if (_method == VerifyMethod.sms && _codeSent) ...[
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      hintText: '인증번호 4자리',
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixText: _canResend ? null : _timerText,
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _busy
                        ? null
                        : () {
                            if (_method == VerifyMethod.pass) {
                              _requestPass();
                            } else if (!_codeSent) {
                              _sendSms();
                            } else {
                              _verifySmsAndSave();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _method == VerifyMethod.pass
                                ? 'PASS로 인증하기'
                                : (_codeSent ? '인증 완료' : '인증번호 받기'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                if (_method == VerifyMethod.sms &&
                    _codeSent &&
                    _canResend) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: _busy ? null : _sendSms,
                      child: const Text('인증번호 재발송'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MethodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE5E7EB),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    var formatted = digits;
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
