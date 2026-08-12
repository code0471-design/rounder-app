import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../di/app_dependencies.dart';
import '../../providers/auth_provider.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/rounder_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _run();
  }

  Future<void> _run() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _controller.forward();

    final mockMode = AppDependencies.instance.isOfflineMockMode;
    final splashDelay = mockMode ? 600 : 2000;

    String? bootstrapNote;
    var autoLoggedIn = false;

    try {
      await Future.delayed(Duration(milliseconds: splashDelay));
      if (!mounted) return;

      final auth = context.read<AuthProvider>();
      autoLoggedIn = await auth.tryAutoLogin().timeout(
            const Duration(seconds: 5),
            onTimeout: () => false,
          );

      if (!mounted) return;

      if (autoLoggedIn) {
        final userId = auth.currentUser!.id;
        await context.read<ClubProvider>().switchUser(userId);
        if (!AppDependencies.instance.isOfflineMockMode) {
          try {
            final snap = await AppDependencies.instance
                .bootstrapForUser(userId)
                .timeout(const Duration(seconds: 10));
            final pending = AppDependencies.instance.mockDataStore
                    ?.pendingJoinRequests
                    .where((r) => r.userId == userId)
                    .toList() ??
                const [];
            if (mounted) {
              context.read<ClubProvider>().hydrateFromBootstrap(
                    snap,
                    pendingRequests: pending,
                  );
            }
          } catch (e, st) {
            bootstrapNote = e.toString();
            debugPrint('[SplashScreen] Firestore bootstrap 실패: $e\n$st');
          }
        } else {
          final snap =
              await AppDependencies.instance.bootstrapForUser(userId);
          final pending = AppDependencies.instance.mockDataStore
                  ?.pendingJoinRequests
                  .where((r) => r.userId == userId)
                  .toList() ??
              const [];
          if (mounted) {
            context.read<ClubProvider>().hydrateFromBootstrap(
                  snap,
                  pendingRequests: pending,
                );
          }
        }
      }
    } catch (e, st) {
      bootstrapNote = e.toString();
      debugPrint('[SplashScreen] splash flow error: $e\n$st');
    }

    if (!mounted) return;

    // 웹 미리보기: #/admin 으로 들어오면 어드민으로 직행
    final frag = Uri.base.fragment;
    final wantsAdmin = frag == '/admin' || frag == 'admin';
    final route = wantsAdmin
        ? '/admin'
        : (autoLoggedIn ? '/main' : '/login');
    await Navigator.of(context).pushReplacementNamed(route);

    if (bootstrapNote != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Firestore 연결 지연/실패 — 오프라인으로 계속합니다.',
            style: const TextStyle(fontSize: 12),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Stack(
        children: [
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => FadeTransition(
                opacity: _fade,
                child: Transform.scale(
                  scale: _scale.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RounderLogo(
                        vertical: true,
                        height: h * 0.364, // +30%
                        width: h * 0.286,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _fade,
              builder: (_, __) => Opacity(
                opacity: _fade.value,
                child: const Text(
                  'v1.0',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
