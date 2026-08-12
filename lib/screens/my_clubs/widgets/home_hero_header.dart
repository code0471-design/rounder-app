import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/one_line_slogan.dart';

/// 홈 상단 — 화이트 AppHeader + 딥그린 플로팅 그리팅 카드
class HomeHeroHeader extends StatelessWidget {
  final VoidCallback onNotificationTap;
  final VoidCallback? onProfileTap;

  const HomeHeroHeader({
    super.key,
    required this.onNotificationTap,
    this.onProfileTap,
  });

  static const _greetingRadius = 24.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppHeader(
          onNotificationTap: onNotificationTap,
          onProfileTap: onProfileTap,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.heroGreen,
              borderRadius: BorderRadius.circular(_greetingRadius),
              boxShadow: AppShadows.soft,
            ),
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
            child: Consumer<AuthProvider>(
              builder: (_, auth, __) {
                final name = auth.currentUser?.name ?? '회원';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '안녕하세요, $name님 👋',
                      style: const TextStyle(
                        fontSize: 13,
                        letterSpacing: 0.35,
                        color: AppColors.textOnDarkSecondary,
                        fontWeight: FontWeight.w500,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const OneLineSlogan(
                      text: '오늘도 즐거운 라운딩 되세요 ⛳',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textOnDark,
                        letterSpacing: -0.2,
                        height: 1.0,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
