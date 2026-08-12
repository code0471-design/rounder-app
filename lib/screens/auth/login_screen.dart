import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../di/app_dependencies.dart';
import '../../providers/auth_provider.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/rounder_logo.dart';

// ════════════════════════════════════════════════════════════
//  LoginScreen — 소셜 로그인 (카카오 / 구글)
// ════════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String? _activeProvider; // 'kakao' | 'google' | test phone

  Future<void> _syncClubProvider() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;

    final userId = auth.currentUser!.id;
    await context.read<ClubProvider>().switchUser(userId);
    try {
      final snap = await AppDependencies.instance.bootstrapForUser(userId);
      final pending = AppDependencies.instance.mockDataStore
              ?.pendingJoinRequests
              .where((r) => r.userId == userId)
              .toList() ??
          const [];
      if (mounted) {
        final clubs = context.read<ClubProvider>();
        clubs.hydrateFromBootstrap(
          snap,
          pendingRequests: pending,
        );
        // 어드민에만 남은 내가 만든 모임 복구 + 가입신청 병합
        await clubs.refreshOwnedClubs();
        await clubs.mergeSharedJoinRequests();
      }
    } catch (_) {
      // Firestore 미연결 시에도 앱 진입
      if (mounted) {
        final clubs = context.read<ClubProvider>();
        await clubs.refreshOwnedClubs();
        await clubs.mergeSharedJoinRequests();
      }
    }
  }

  Future<void> _loginWithPhone(String phone, {String? providerKey}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _activeProvider = providerKey ?? phone;
    });

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.loginAsync(phone, saveSession: true);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _loading = false;
        _activeProvider = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('테스트 계정을 찾을 수 없습니다')),
      );
      return;
    }

    await _syncClubProvider();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/main');
  }

  Future<void> _loginSocial(String provider) async {
    // 소셜 버튼은 총무(홍길동) 계정으로 진입
    await _loginWithPhone('010-1234-5678', providerKey: provider);
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // ── 로고 ──
              RounderLogo(
                vertical: true,
                height: h * 0.38,
                width: h * 0.38,
              ),

              const Spacer(flex: 2),

              // ── 카카오 ──
              _SocialLoginButton(
                label: '카카오로 시작하기',
                backgroundColor: const Color(0xFFFEE500),
                foregroundColor: const Color(0xFF191919),
                borderColor: null,
                loading: _loading && _activeProvider == 'kakao',
                enabled: !_loading,
                leading: _KakaoMark(),
                onPressed: () => _loginSocial('kakao'),
              ),
              const SizedBox(height: 12),

              // ── 구글 ──
              _SocialLoginButton(
                label: '구글로 시작하기',
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1F1F1F),
                borderColor: const Color(0xFFDADCE0),
                loading: _loading && _activeProvider == 'google',
                enabled: !_loading,
                leading: _GoogleMark(),
                onPressed: () => _loginSocial('google'),
              ),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '테스트 계정',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 12),
              _TestAccountButton(
                title: '홍길동',
                subtitle: '010-1234-5678 · 모임 생성/총무 테스트',
                loading: _loading && _activeProvider == '010-1234-5678',
                enabled: !_loading,
                onPressed: () => _loginWithPhone('010-1234-5678'),
              ),
              const SizedBox(height: 8),
              _TestAccountButton(
                title: '이민준',
                subtitle: '010-9999-0000 · 가입 신청 테스트',
                loading: _loading && _activeProvider == '010-9999-0000',
                enabled: !_loading,
                onPressed: () => _loginWithPhone('010-9999-0000'),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestAccountButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool loading;
  final bool enabled;
  final VoidCallback onPressed;

  const _TestAccountButton({
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : Row(
                children: [
                  Icon(Icons.person_outline_rounded,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: Colors.grey.shade400),
                ],
              ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  소셜 로그인 버튼
// ────────────────────────────────────────────────────────────
class _SocialLoginButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final Widget leading;
  final bool loading;
  final bool enabled;
  final VoidCallback onPressed;

  const _SocialLoginButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.leading,
    required this.loading,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.7),
          disabledForegroundColor: foregroundColor.withValues(alpha: 0.7),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: borderColor != null
                ? BorderSide(color: borderColor!, width: 1.2)
                : BorderSide.none,
          ),
        ),
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: foregroundColor,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  leading,
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: foregroundColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _KakaoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Color(0xFF191919),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text(
        'K',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Color(0xFFFEE500),
          height: 1,
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

/// 간단한 Google "G" 마크 (외부 에셋 없이)
class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.42;
    final stroke = size.width * 0.18;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.35, 1.8, false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 1.45, 1.0, false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.45, 0.7, false, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.15, 0.9, false, paint);

    final bar = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - stroke / 2, r + stroke * 0.2, stroke),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
