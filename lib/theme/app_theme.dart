import 'package:flutter/material.dart';

// ════════════════════════════════════════════════════════════
//  ROUNDER Design System v5 — Premium Final
// ════════════════════════════════════════════════════════════
class AppColors {
  // ── 브랜드 ───────────────────────────────────────────────
  static const primary        = Color(0xFF1B4D3E);
  static const primaryDark    = Color(0xFF153D32);
  static const primaryLight   = Color(0xFF2A6B55);
  static const accent         = Color(0xFFD4AF37);
  static const accentSoft     = Color(0xFFF5ECD7);
  static const accentMuted    = Color(0xFFE8D5A3);

  // ── 배경 ─────────────────────────────────────────────────
  static const background     = Color(0xFFFDFCF0);
  static const surface        = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF5F4EE);
  static const sandSoft       = Color(0xFFFDFCF0);
  static const cream          = Color(0xFFFDFCF0);
  static const cream2         = Color(0xFFF5F4EE);
  static const sand           = Color(0xFFE8E6DC);

  // ── 컬러 히어로 배너 (환영 카피 등) ─────────────────────
  static const heroGreen      = Color(0xFF1B4D3E);
  static const heroGreenDark  = Color(0xFF153D32);

  // ── 레거시 alias ─────────────────────────────────────────
  static const sage           = primaryLight;
  static const sageDeep       = primary;
  static const sageDarker     = primaryDark;
  static const sageLighter    = Color(0xFFE8F0EC);
  static const mintBright     = primaryLight;
  static const mintPale       = sageLighter;
  static const mintBadge      = sageLighter;
  static const mintLight      = sageLighter;
  static const mintMedium     = primaryLight;
  static const mintSoft       = sageLighter;
  static const cardMint       = sageLighter;

  // ── 텍스트 (컬러 배경 위) ────────────────────────────────
  static const textOnDark         = Color(0xFFF5F4EE);
  static const textOnDarkSecondary= Color(0xFFB8C9C2);
  static const textOnDarkMuted    = Color(0xFF7A9A8E);

  // ── 텍스트 (밝은 배경·카드 위) — 40~60대 가독성 강화 ──
  static const ink            = Color(0xFF152820);
  static const inkSoft        = Color(0xFF3A4E47);
  static const textPrimary    = Color(0xFF152820);
  static const textSecondary  = Color(0xFF3F524B);
  static const textTertiary   = Color(0xFF5E7169);

  // ── 액센트 ───────────────────────────────────────────────
  static const amber          = accent;
  static const amberSoft      = accentSoft;
  static const gold           = accent;
  static const rose           = Color(0xFFEF4444);
  static const roseSoft       = Color(0xFFFEE2E2);
  static const mauve          = Color(0xFF8B5CF6);
  static const accentOrange   = accent;

  // ── 상태 ─────────────────────────────────────────────────
  static const danger         = Color(0xFFC0392B);
  static const warning        = accent;
  static const success        = primary;

  // ── UI ───────────────────────────────────────────────────
  static const cardWhite      = surface;
  static const divider        = Color(0xFFE8E6DC);
  static const dividerOnCard  = Color(0xFFE8E6DC);
  static const paidBg         = Color(0xFFE8F0EC);
  static const unpaidBg       = Color(0xFFFEE2E2);
  static const attendBg       = Color(0xFFE8F0EC);
  static const attendText     = primary;
  static const undecidedBg    = Color(0xFFF5F4EE);
  static const undecidedText  = textSecondary;
  static const absentBg       = Color(0xFFFEE2E2);
  static const absentText     = danger;
}

class AppDecorations {
  static const heroBottomRadius = 32.0;

  /// 홈 히어로 — 딥그린 단색 + 하단 곡선
  static BoxDecoration get homeHero => const BoxDecoration(
        color: AppColors.heroGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(heroBottomRadius),
          bottomRight: Radius.circular(heroBottomRadius),
        ),
      );

  /// 토스 스타일 표준 화이트 카드
  static BoxDecoration get standardCard => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: AppShadows.soft,
      );

  /// 퀵 액션 프리미엄 카드
  static BoxDecoration get premiumQuickCard => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.28),
          width: 1,
        ),
        boxShadow: AppShadows.premiumCard,
      );
}

class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
}

class AppShadows {
  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// 프리미엄 화이트 카드 — 은은한 입체감
  static List<BoxShadow> get premiumCard => [
        BoxShadow(
          color: AppColors.accent.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get elevated => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];
}

class AppText {
  static const title = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );
  static const subtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.5,
  );
  static const caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textTertiary,
  );
  static const accentLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.accent,
    letterSpacing: 0.2,
  );
}

class AppTheme {
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.background,
        ),
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Pretendard',

        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),

        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),

        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surface,
          modalBackgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
        ),

        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.background,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: AppColors.textTertiary,
          selectedLabelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(fontSize: 11),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),

        tabBarTheme: const TabBarThemeData(
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.accent,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          unselectedLabelStyle: TextStyle(fontSize: 14),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );
}
