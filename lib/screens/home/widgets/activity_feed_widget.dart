import 'package:flutter/material.dart';
import '../../../models/club_model.dart';
import '../../../theme/app_theme.dart';

class ActivityFeedWidget extends StatelessWidget {
  final List<ActivityItem> activities;

  const ActivityFeedWidget({super.key, required this.activities});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.timeline,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '최근 활동',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '더보기 >',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          ...activities.map((activity) => _buildActivityItem(activity)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildActivityItem(ActivityItem activity) {
    final config = _getActivityConfig(activity.activityType);
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // 프로필 아바타
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: config['bgColor'] as Color,
                  child: Text(
                    activity.memberName.substring(0, 1),
                    style: TextStyle(
                      color: config['iconColor'] as Color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: config['iconColor'] as Color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Icon(
                      config['icon'] as IconData,
                      size: 9,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  children: [
                    TextSpan(
                      text: '${activity.memberName}님 ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: activity.description),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              activity.timeAgo,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getActivityConfig(String type) {
    switch (type) {
      case 'attendance':
        return {
          'icon': Icons.check,
          'iconColor': AppColors.success,
          'bgColor': AppColors.success.withValues(alpha: 0.15),
        };
      case 'payment':
        return {
          'icon': Icons.attach_money,
          'iconColor': AppColors.primary,
          'bgColor': AppColors.primary.withValues(alpha: 0.12),
        };
      case 'cancel':
        return {
          'icon': Icons.close,
          'iconColor': AppColors.danger,
          'bgColor': AppColors.danger.withValues(alpha: 0.12),
        };
      case 'score':
        return {
          'icon': Icons.emoji_events,
          'iconColor': AppColors.gold,
          'bgColor': AppColors.gold.withValues(alpha: 0.15),
        };
      default:
        return {
          'icon': Icons.info_outline,
          'iconColor': AppColors.textSecondary,
          'bgColor': Colors.grey.withValues(alpha: 0.12),
        };
    }
  }
}
