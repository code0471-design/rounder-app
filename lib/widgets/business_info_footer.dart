import 'package:flutter/material.dart';

import '../config/business_info.dart';
import '../screens/legal/service_about_screen.dart';
import '../theme/app_theme.dart';

/// 본인인증이 이루어지는 화면 하단에 고정 노출하는 사업자 정보.
class BusinessInfoFooter extends StatelessWidget {
  final bool showAboutLink;

  const BusinessInfoFooter({super.key, this.showAboutLink = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '사업자 정보',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              _BizLine(label: '상호명', value: BusinessInfo.tradeName),
              _BizLine(label: '사업자번호', value: BusinessInfo.registrationNo),
              _BizLine(label: '대표자명', value: BusinessInfo.ceo),
              _BizLine(label: '사업장주소지', value: BusinessInfo.address),
              _BizLine(label: '전화번호', value: BusinessInfo.phone),
            ],
          ),
        ),
        if (showAboutLink) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ServiceAboutScreen(),
                ),
              );
            },
            child: const Text(
              '서비스 소개 보기',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BizLine extends StatelessWidget {
  final String label;
  final String value;

  const _BizLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label  ',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            TextSpan(
              text: value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
