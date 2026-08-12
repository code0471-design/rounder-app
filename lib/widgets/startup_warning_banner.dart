import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// runApp 이후 전역 경고 배너 (Firebase 미연결 등)
class StartupWarningBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const StartupWarningBanner({
    super.key,
    required this.message,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warning.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 18, color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}
