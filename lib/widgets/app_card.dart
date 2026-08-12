import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 프리미엄 골프 모임 공통 카드 — 화이트 · 16px · 소프트 섀도우
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool goldAccent;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.goldAccent = false,
  });

  static BoxDecoration decoration({Color? bg, bool goldAccent = false}) {
    if (goldAccent) return AppDecorations.premiumQuickCard;
    return AppDecorations.standardCard.copyWith(color: bg ?? AppColors.surface);
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: decoration(bg: color, goldAccent: goldAccent),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: content,
      ),
    );
  }
}
