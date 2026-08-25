import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../di/app_dependencies.dart';
import '../../providers/auth_provider.dart';
import '../../providers/club_provider.dart';
import '../../services/social_auth_service.dart';
import '../legal/service_about_screen.dart';
import '../../widgets/rounder_logo.dart';

// ════════════════════════════════════════════════════════════
//  LoginScreen — 카카오 / 구글 / Apple 로그인만
// ════════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  SocialProvider? _active;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().loadLastLoginMethod();
    });
  }

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
        await clubs.refreshOwnedClubs();
        await clubs.mergeSharedJoinRequests();
      }
    } catch (_) {
      if (mounted) {
        final clubs = context.read<ClubProvider>();
        await clubs.refreshOwnedClubs();
        await clubs.mergeSharedJoinRequests();
      }
    }
  }

  Future<void> _signIn(SocialProvider provider) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _active = provider;
    });

    try {
      final profile = await SocialAuthService.signIn(provider);
      if (!mounted) return;
      await context.read<AuthProvider>().loginWithSocial(profile);
      if (!mounted) return;
      await _syncClubProvider();
      if (!mounted) return;
      final needsPhone = context.read<AuthProvider>().needsPhoneNumber;
      Navigator.of(context).pushReplacementNamed(
        needsPhone ? '/phone-required' : '/main',
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is SocialAuthException
          ? e.message
          : '로그인에 실패했습니다. 잠시 후 다시 시도해 주세요.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _loading = false;
        _active = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final showApple = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 1),
              RounderLogo(
                vertical: true,
                height: h * 0.36,
                width: h * 0.36,
              ),
              const Spacer(flex: 2),
              Consumer<AuthProvider>(
                builder: (_, auth, __) {
                  final hint = auth.lastLoginHint();
                  if (hint.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      hint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  );
                },
              ),
              _SocialLoginButton(
                label: '카카오로 시작하기',
                backgroundColor: const Color(0xFFFEE500),
                foregroundColor: const Color(0xFF191919),
                borderColor: null,
                loading: _loading && _active == SocialProvider.kakao,
                enabled: !_loading,
                leading: _KakaoMark(),
                onPressed: () => _signIn(SocialProvider.kakao),
              ),
              const SizedBox(height: 12),
              _SocialLoginButton(
                label: '구글로 시작하기',
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1F1F1F),
                borderColor: const Color(0xFFDADCE0),
                loading: _loading && _active == SocialProvider.google,
                enabled: !_loading,
                leading: _GoogleMark(),
                onPressed: () => _signIn(SocialProvider.google),
              ),
              if (showApple) ...[
                const SizedBox(height: 12),
                _SocialLoginButton(
                  label: 'Apple로 시작하기',
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  borderColor: null,
                  loading: _loading && _active == SocialProvider.apple,
                  enabled: !_loading,
                  leading: const Icon(Icons.apple, size: 22, color: Colors.white),
                  onPressed: () => _signIn(SocialProvider.apple),
                ),
              ],
              const Spacer(flex: 1),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ServiceAboutScreen(),
                    ),
                  );
                },
                child: const Text('서비스 소개 · 사업자 정보'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

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
