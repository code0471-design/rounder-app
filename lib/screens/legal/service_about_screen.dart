import 'package:flutter/material.dart';

import '../../config/business_info.dart';
import '../../theme/app_theme.dart';
import '../../widgets/business_info_footer.dart';

/// 포트원 본인인증 심사용 서비스 소개 페이지.
class ServiceAboutScreen extends StatelessWidget {
  const ServiceAboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text(
          '서비스 소개',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        children: [
          Text(
            '${BusinessInfo.serviceName} (${BusinessInfo.serviceNameKo})',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            BusinessInfo.serviceHeadline,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            BusinessInfo.serviceIntro,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '제공하는 기능',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...BusinessInfo.serviceFeatures.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textPrimary)),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          const BusinessInfoFooter(showAboutLink: false),
        ],
      ),
    );
  }
}
