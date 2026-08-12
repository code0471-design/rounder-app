import 'package:flutter/material.dart';
import '../../../features/clubs/presentation/club_list_navigation.dart';
import '../../../theme/app_theme.dart';
import '../../clubs/create_club_screen.dart';

/// 홈 퀵 액션 — 컬러 카드 2열 (프리미엄 그린·골드)
class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.travel_explore_rounded,
                label: '모임 찾기',
                sub: '지역·업종별 검색',
                cardBg: AppColors.accentSoft,
                iconColor: AppColors.primary,
                iconBg: Colors.white.withValues(alpha: 0.85),
                labelColor: AppColors.primary,
                subColor: AppColors.primary.withValues(alpha: 0.65),
                borderColor: AppColors.accent.withValues(alpha: 0.35),
                onTap: () => openClubListDashboard(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionTile(
                icon: Icons.add_circle_outline_rounded,
                label: '모임 만들기',
                sub: '새 골프 모임 개설',
                cardBg: AppColors.accent,
                iconColor: AppColors.primaryDark,
                iconBg: Colors.white.withValues(alpha: 0.55),
                labelColor: AppColors.primaryDark,
                subColor: AppColors.primaryDark.withValues(alpha: 0.72),
                borderColor: AppColors.accentMuted,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateClubScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color cardBg;
  final Color iconColor;
  final Color iconBg;
  final Color labelColor;
  final Color subColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.cardBg,
    required this.iconColor,
    required this.iconBg,
    required this.labelColor,
    required this.subColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        splashColor: iconColor.withValues(alpha: 0.08),
        highlightColor: iconColor.withValues(alpha: 0.04),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: borderColor, width: 1),
            ),
            padding: const EdgeInsets.fromLTRB(10, 15, 10, 15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(height: 9),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                    letterSpacing: -0.3,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sub,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: subColor,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
