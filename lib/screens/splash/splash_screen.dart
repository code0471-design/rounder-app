import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../di/app_dependencies.dart';
import '../../providers/auth_provider.dart';
import '../../providers/club_provider.dart';
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
    _scale = Tween<double>(begin: 0.80, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _run();
  }

  Future<bool> _autoLoginAndHydrate() async {
    var autoLoggedIn = false;
    try {
      if (!mounted) return false;

      final auth = context.read<AuthProvider>();
      autoLoggedIn = await auth.tryAutoLogin().timeout(
            const Duration(seconds: 5),
            onTimeout: () => false,
          );

      if (!mounted) return autoLoggedIn;

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
      debugPrint('[SplashScreen] splash flow error: $e\n$st');
    }
    return autoLoggedIn;
  }

  Future<void> _run() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _controller.forward();

    final loginFuture = _autoLoginAndHydrate();
    await Future.delayed(const Duration(milliseconds: 1800));
    var autoLoggedIn = await loginFuture;

    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    // 번호 미등록 세션은 로그인 화면부터 다시 (카카오 → 번호 입력 순서)
    if (autoLoggedIn && auth.needsPhoneNumber) {
      await auth.logoutAsync();
      autoLoggedIn = false;
    }
    if (!mounted) return;

    final frag = Uri.base.fragment;
    final wantsAdmin = frag == '/admin' || frag == 'admin';
    final route = wantsAdmin
        ? '/admin'
        : (autoLoggedIn ? '/main' : '/login');
    await Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SizedBox.expand(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              final h = MediaQuery.sizeOf(context).height;
              return FadeTransition(
                opacity: _fade,
                child: Transform.scale(
                  scale: _scale.value,
                  child: Center(
                    child: RounderLogo(
                      vertical: true,
                      height: h * 0.36,
                      width: h * 0.36,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
