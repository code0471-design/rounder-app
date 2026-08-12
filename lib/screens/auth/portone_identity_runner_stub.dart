import 'package:flutter/material.dart';
import '../../services/identity_verification_result.dart';
import 'portone_identity_fallback.dart';

/// 웹 등 — 포트원 네이티브 모듈 미지원
Widget buildPortoneIdentityBody({
  required BuildContext context,
  required String expectedName,
  required String expectedPhone,
  required void Function(IdentityVerificationResult result) onResult,
}) {
  return PortoneIdentityFallback(
    expectedName: expectedName,
    expectedPhone: expectedPhone,
    onResult: onResult,
    onCancel: () => onResult(
      IdentityVerificationResult.failure('본인인증이 취소되었습니다'),
    ),
  );
}
