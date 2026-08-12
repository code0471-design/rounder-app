// ════════════════════════════════════════════════════════════
//  ROUNDER Admin Dashboard — Theme & Constants
// ════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

class AdminColors {
  // ── Primary Palette (Dark Green / Golf)
  static const Color sidebarBg     = Color(0xFF0F2218);   // 딥 다크 그린
  static const Color sidebarHover  = Color(0xFF1A3828);   // 호버 상태
  static const Color sidebarActive = Color(0xFF1E6B45);   // 선택된 메뉴
  static const Color accent        = Color(0xFF2D9E63);   // 액센트 그린
  static const Color accentLight   = Color(0xFF3DB875);   // 밝은 그린

  // ── Content Area
  static const Color contentBg    = Color(0xFFF4F6F8);   // 배경
  static const Color cardBg       = Color(0xFFFFFFFF);   // 카드
  static const Color cardBorder   = Color(0xFFE8ECF0);   // 카드 테두리
  static const Color divider      = Color(0xFFEDF0F3);   // 구분선

  // ── Text (40~60대 가독성: 흐린 회색 대신 또렷한 톤)
  static const Color textPrimary  = Color(0xFF15202B);
  static const Color textSecond   = Color(0xFF3D4A5C);
  static const Color textHint     = Color(0xFF5C6B7A);
  static const Color textWhite    = Color(0xFFFFFFFF);
  static const Color textSidebar  = Color(0xFFD0E0D6);

  // ── Status Colors
  static const Color statusOk      = Color(0xFF2D9E63);   // 정상/활성
  static const Color statusWarn    = Color(0xFFF59E0B);   // 경고
  static const Color statusDanger  = Color(0xFFEF4444);   // 차단/종료
  static const Color statusInfo    = Color(0xFF3B82F6);   // 정보

  // ── Stat Card Gradients
  static const Color statGreen1   = Color(0xFF1E6B45);
  static const Color statGreen2   = Color(0xFF2D9E63);
  static const Color statBlue1    = Color(0xFF1E40AF);
  static const Color statBlue2    = Color(0xFF3B82F6);
  static const Color statPurple1  = Color(0xFF6D28D9);
  static const Color statPurple2  = Color(0xFF8B5CF6);
  static const Color statOrange1  = Color(0xFFB45309);
  static const Color statOrange2  = Color(0xFFF59E0B);
}

class AdminSizes {
  static const double sidebarWidth    = 248.0;
  static const double topbarHeight    = 52.0;
  static const double cardRadius      = 12.0;
  static const double cardPadding     = 20.0;
  static const double sectionPadding  = 24.0;
  /// 목록형 관리 페이지(회원/모임) 상단 여백 — 탑바 직후 최소 간격
  static const double listPagePaddingTop = 8.0;
  /// 글자 키워도 줄바꿈 없도록 행 높이 여유
  static const double tableRowHeight  = 58.0;

  /// 어드민 전체 레이아웃 최소 너비.
  /// 창이 이보다 좁아지면 레이아웃이 줄어들지 않고 가로 스크롤이 생긴다.
  static const double layoutMinWidth  = 1240.0;
}

class AdminTextStyles {
  static const TextStyle pageTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AdminColors.textPrimary,
    letterSpacing: -0.3,
  );
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AdminColors.textPrimary,
  );
  static const TextStyle cardValue = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    color: AdminColors.textWhite,
    letterSpacing: -0.5,
  );
  static const TextStyle cardLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Color(0xF0FFFFFF),
  );
  static const TextStyle tableHeader = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AdminColors.textSecond,
    letterSpacing: 0.2,
  );
  static const TextStyle tableCell = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AdminColors.textPrimary,
  );
  static const TextStyle sidebarMenu = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AdminColors.textSidebar,
  );
  static const TextStyle sidebarMenuActive = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AdminColors.textWhite,
  );
}

// ── Reusable Admin Widgets
class AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? radius;

  const AdminCard({
    super.key,
    required this.child,
    this.padding,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(radius ?? AdminSizes.cardRadius),
        border: Border.all(color: AdminColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(AdminSizes.cardPadding),
      child: child,
    );
  }
}

class AdminBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;

  const AdminBadge({
    super.key,
    required this.label,
    required this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor ?? color,
        ),
      ),
    );
  }
}

class AdminActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;

  const AdminActionButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
