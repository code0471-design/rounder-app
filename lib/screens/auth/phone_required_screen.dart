import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';

/// 소셜 로그인 후 이름·휴대폰 번호 필수 수집 화면
class PhoneRequiredScreen extends StatefulWidget {
  const PhoneRequiredScreen({super.key});

  @override
  State<PhoneRequiredScreen> createState() => _PhoneRequiredScreenState();
}

class _PhoneRequiredScreenState extends State<PhoneRequiredScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  Timer? _timer;
  int _resendSeconds = 0;
  bool _namePrefillDone = false;

  bool get _canResend => _resendSeconds == 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_namePrefillDone) return;
    _namePrefillDone = true;
    final auth = context.read<AuthProvider>();
    final hint = auth.greetingName.trim();
    if (hint.isNotEmpty &&
        hint != '회원' &&
        !AuthProvider.isPlaceholderName(hint)) {
      _nameCtrl.text = hint;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
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
      await auth.sendSmsCode(
        _phoneCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
      );
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
        _error = e is StateError
            ? e.message
            : '인증번호 알림톡 발송에 실패했습니다. 다시 시도해 주세요.';
      });
    }
  }

  Future<void> _verifySmsAndSave() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = auth.verifySmsCode(_codeCtrl.text.trim());
    if (!ok) {
      setState(() {
        _error = kDebugMode
            ? '인증번호가 올바르지 않습니다.\n(디버그·미설정 시) 코드: 1234'
            : '인증번호가 올바르지 않습니다';
      });
      return;
    }
    await _savePhone(VerifyMethod.sms);
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
      final name = _nameCtrl.text.trim();
      final user = await auth.attachPhoneToCurrentUser(
        phone: phone,
        name: name,
        verifyMethod: method,
      );
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _busy = false;
          _error = '이름·전화번호 저장에 실패했습니다.';
        });
        return;
      }

      try {
        context.read<ClubProvider>().syncAuthUserProfile(
          phone: user.phone,
          name: user.name,
        );
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
        _error = '저장 중 오류가 발생했습니다.';
      });
    }
  }

  Future<void> _goLogin() async {
    final auth = context.read<AuthProvider>();
    await auth.logoutAsync();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.textPrimary,
          onPressed: _busy ? null : _goLogin,
        ),
        title: const Text(
          '회원 정보 입력',
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
                const Text(
                  '이름과 휴대폰 번호를 입력해 주세요',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '알림톡·모임 연락에 사용됩니다.\n카카오 알림톡으로 인증번호를 보내 드릴게요.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  '이름',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  enabled: !_busy && !_codeSent,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: '실명 또는 모임에서 쓸 이름',
                    prefixIcon: const Icon(Icons.person_outline),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.length < 2) return '이름을 2자 이상 입력해 주세요';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
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
                  enabled: !_busy && !_codeSent,
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
                if (_codeSent) ...[
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      hintText: '알림톡 인증번호 4자리',
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
                            if (!_codeSent) {
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
                            _codeSent ? '인증 완료' : '인증번호 받기',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                if (_codeSent && _canResend) ...[
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
