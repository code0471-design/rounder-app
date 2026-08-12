import 'package:flutter/material.dart';
import '../../../models/club_model.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/d_day_utils.dart';

/// 내 모임 카드 — 토스 스타일
class HomeClubCard extends StatelessWidget {
  final Club club;
  final VoidCallback onTap;

  const HomeClubCard({
    super.key,
    required this.club,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dDayText = DDayUtils.format(club.nextRoundDate);
    final dDayClose = DDayUtils.isUrgent(club.nextRoundDate);
    final hasSchedule = club.nextRoundDate != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: AppDecorations.standardCard,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.sageLighter,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      clubIndustryEmoji(club.industry),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        club.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${club.region} · ${club.industry} · ${club.memberCount}명',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.0,
                        ),
                      ),
                      if (club.nextRoundCourse != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.sports_golf_rounded,
                              size: 12,
                              color:
                                  AppColors.textSecondary.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                club.nextRoundCourse!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _RoleBadge(role: club.myRole),
                    if (hasSchedule) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: dDayClose
                              ? AppColors.primary
                              : AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          dDayText,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  (Color, Color) get _colors {
    switch (role) {
      case '회장':
        return (AppColors.accentSoft, const Color(0xFF6B5426));
      case '총무':
        return (const Color(0xFFFFE4CC), const Color(0xFF8B5E2A));
      case '정회원':
        return (AppColors.sageLighter, AppColors.primary);
      case '게스트':
        return (AppColors.roseSoft, AppColors.danger);
      default:
        return (AppColors.cream2, AppColors.textSecondary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
