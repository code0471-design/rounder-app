import 'package:flutter/material.dart';
import '../../services/identity_verification_result.dart';
import 'portone_identity_runner_stub.dart'
    if (dart.library.io) 'portone_identity_runner_io.dart';

/// 포트원 V2 본인인증 진입 화면
///
/// - 키가 있고 모바일: 포트원 인증창
/// - 웹 / 키 없음: 안내 + 개발용 완료
class PortoneIdentityScreen extends StatelessWidget {
  final String expectedName;
  final String expectedPhone;

  const PortoneIdentityScreen({
    super.key,
    required this.expectedName,
    required this.expectedPhone,
  });

  void _finish(BuildContext context, IdentityVerificationResult result) {
    if (!context.mounted) return;
    if (!result.success &&
        (result.errorMessage?.contains('취소') ?? false)) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return buildPortoneIdentityBody(
      context: context,
      expectedName: expectedName,
      expectedPhone: expectedPhone,
      onResult: (result) => _finish(context, result),
    );
  }
}
