import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

/// 마이페이지 번호 변경용 알림톡 OTP 시트. 새 전체 화면을 만들지 않는다.
Future<bool> showPhoneOtpSheet({
  required BuildContext context,
  required String phone,
  String? name,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => PhoneOtpSheet(phone: phone, name: name),
  );
  return result == true;
}

class PhoneOtpSheet extends StatefulWidget {
  final String phone;
  final String? name;

  const PhoneOtpSheet({
    super.key,
    required this.phone,
    this.name,
  });

  @override
  State<PhoneOtpSheet> createState() => _PhoneOtpSheetState();
}

class _PhoneOtpSheetState extends State<PhoneOtpSheet> {
  final _codeCtrl = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  Timer? _timer;
  int _resendSeconds = 0;

  bool get _canResend => _resendSeconds == 0;

  @override
  void dispose() {
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

  Future<void> _sendCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      await auth.assertPhoneFreeForCurrentUser(widget.phone);
      await auth.sendSmsCode(
        widget.phone,
        name: widget.name,
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

  Future<void> _verify() async {
    final auth = context.read<AuthProvider>();
    final ok = auth.verifySmsCode(_codeCtrl.text.trim());
    if (!ok) {
      setState(() {
        _error = '인증번호가 올바르지 않습니다';
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final formatted = AuthProvider.formatPhone(widget.phone);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + safeBottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '휴대폰 번호 변경',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '이름·휴대폰 / 카카오 알림톡 인증번호로 확인합니다. PASS·통신사 본인인증은 쓰지 않습니다.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            formatted,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
          ),
          if (_codeSent) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '알림톡 인증번호 4자리',
                counterText: '',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixText: _canResend ? null : _timerText,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _busy
                  ? null
                  : () {
                      if (!_codeSent) {
                        _sendCode();
                      } else {
                        _verify();
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
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _busy ? null : _sendCode,
                child: const Text('인증번호 재발송'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
