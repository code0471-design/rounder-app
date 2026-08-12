import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/identity_verification_result.dart';
import '../../theme/app_theme.dart';

/// 키 없음 / 웹 — 안내 + 개발용 완료 (전체 화면)
class PortoneIdentityFallback extends StatelessWidget {
  final String expectedName;
  final String expectedPhone;
  final void Function(IdentityVerificationResult result) onResult;
  final VoidCallback onCancel;

  const PortoneIdentityFallback({
    super.key,
    required this.expectedName,
    required this.expectedPhone,
    required this.onResult,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final reason = kIsWeb
        ? '웹 미리보기에서는 포트원 PASS 본인인증을 실행할 수 없습니다.\n모바일 빌드 + 가맹점 키가 필요합니다.'
        : '포트원 가맹점 식별코드가 아직 설정되지 않았습니다.\nlib/config/portone_config.dart 에 userCode 를 넣어 주세요.';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: AppColors.textPrimary),
          onPressed: onCancel,
        ),
        title: const Text(
          'PASS 본인인증',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      reason,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '$expectedName · $expectedPhone',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '개발 중에는 아래 버튼으로 인증 완료를 시뮬레이션할 수 있습니다.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const Spacer(),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  onResult(
                    IdentityVerificationResult.mock(
                      name: expectedName,
                      phone: expectedPhone,
                    ),
                  );
                },
                icon: const Icon(Icons.verified_user_outlined, size: 20),
                label: const Text('개발용 — 본인인증 완료'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onCancel,
              child: const Text('취소'),
            ),
          ],
        ),
      ),
    );
  }
}
