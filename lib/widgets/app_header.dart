import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/club_provider.dart';
import '../screens/ad/ad_screen.dart';
import '../theme/app_theme.dart';
import 'rounder_logo.dart';

/// 앱 전역 상단 헤더 — 화이트 배경 + 확대 투명 로고 + 알림/프로필
class AppHeader extends StatelessWidget {
  static const logoHeight = 42.0;

  final VoidCallback onNotificationTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLogoTap;
  final Widget? leading;
  final List<Widget>? trailingActions;
  final int? notificationCount;

  const AppHeader({
    super.key,
    required this.onNotificationTap,
    this.onProfileTap,
    this.onLogoTap,
    this.leading,
    this.trailingActions,
    this.notificationCount,
  });

  static void openMyPage(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const MyAdScreen()),
    );
  }

  static Widget compactIcon({
    required VoidCallback onTap,
    required Widget icon,
  }) {
    return IconButton(
      onPressed: onTap,
      icon: icon,
      style: IconButton.styleFrom(
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(32, 32),
        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
      ),
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileTap = onProfileTap ?? () => openMyPage(context);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0EFEA), width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 2),
              ],
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: RounderLogo(
                    height: logoHeight,
                    forWhiteHeader: true,
                    onTap: onLogoTap,
                  ),
                ),
              ),
              if (trailingActions != null) ...trailingActions!,
              _HeaderNotificationButton(
                onTap: onNotificationTap,
                count: notificationCount,
              ),
              _HeaderProfileAvatar(onTap: profileTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderNotificationButton extends StatelessWidget {
  final VoidCallback onTap;
  final int? count;

  const _HeaderNotificationButton({
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    if (count != null) {
      return _NotificationIcon(onTap: onTap, count: count!);
    }

    return Consumer<ClubProvider>(
      builder: (_, prov, __) => _NotificationIcon(
        onTap: onTap,
        count: prov.visibleUnreadNotificationCount,
      ),
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  final VoidCallback onTap;
  final int count;

  const _NotificationIcon({
    required this.onTap,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppHeader.compactIcon(
          onTap: onTap,
          icon: const Icon(
            Icons.notifications_outlined,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        if (count > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 14),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.surface, width: 1),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeaderProfileAvatar extends StatelessWidget {
  final VoidCallback onTap;

  const _HeaderProfileAvatar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppHeader.compactIcon(
      onTap: onTap,
      icon: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.sageLighter,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.person_outline_rounded,
          color: AppColors.primary,
          size: 16,
        ),
      ),
    );
  }
}
