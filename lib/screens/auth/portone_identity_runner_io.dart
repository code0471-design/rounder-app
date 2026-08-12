import 'package:flutter/material.dart';
import 'package:portone_flutter/iamport_certification.dart';
import 'package:portone_flutter/model/certification_data.dart';
import '../../config/portone_config.dart';
import '../../services/identity_verification_result.dart';
import '../../theme/app_theme.dart';
import 'portone_identity_fallback.dart';

/// iOS/Android — 키가 있으면 포트원 V1 본인인증, 없으면 fallback
Widget buildPortoneIdentityBody({
  required BuildContext context,
  required String expectedName,
  required String expectedPhone,
  required void Function(IdentityVerificationResult result) onResult,
}) {
  if (!PortoneConfig.isConfigured) {
    return PortoneIdentityFallback(
      expectedName: expectedName,
      expectedPhone: expectedPhone,
      onResult: onResult,
      onCancel: () => onResult(
        IdentityVerificationResult.failure('본인인증이 취소되었습니다'),
      ),
    );
  }

  final merchantUid = PortoneConfig.newMerchantUid();
  final phoneDigits = expectedPhone.replaceAll(RegExp(r'[^0-9]'), '');

  return IamportCertification(
    appBar: AppBar(
      backgroundColor: AppColors.primaryDark,
      title: const Text(
        '본인인증',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.close, color: AppColors.textPrimary),
        onPressed: () => onResult(
          IdentityVerificationResult.failure('본인인증이 취소되었습니다'),
        ),
      ),
    ),
    initialChild: const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            '본인인증 화면을 불러오는 중...',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
    userCode: PortoneConfig.userCode,
    data: CertificationData(
      pg: PortoneConfig.pg,
      merchantUid: merchantUid,
      company: PortoneConfig.company,
      name: expectedName,
      phone: phoneDigits,
    ),
    callback: (Map<String, String> result) {
      final successRaw = (result['success'] ?? result['imp_success'] ?? '')
          .toLowerCase();
      final ok = successRaw == 'true' ||
          (result['error_code'] == null &&
              result['error_msg'] == null &&
              (result['imp_uid']?.isNotEmpty ?? false));

      onResult(
        IdentityVerificationResult(
          success: ok,
          name: expectedName,
          phone: expectedPhone,
          identityVerificationId: result['imp_uid'] ?? merchantUid,
          errorMessage: ok
              ? null
              : (result['error_msg'] ??
                  result['message'] ??
                  '본인인증에 실패했습니다'),
        ),
      );
    },
  );
}
