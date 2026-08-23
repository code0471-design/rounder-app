import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../di/app_dependencies.dart';
import '../../providers/auth_provider.dart';
import '../../providers/club_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    _run();
  }

  Future<void> _run() async {
    String? bootstrapNote;
    var autoLoggedIn = false;

    try {
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

    final frag = Uri.base.fragment;
    final wantsAdmin = frag == '/admin' || frag == 'admin';
    final needsPhone =
        autoLoggedIn && context.read<AuthProvider>().needsPhoneNumber;
    final route = wantsAdmin
        ? '/admin'
        : (autoLoggedIn
            ? (needsPhone ? '/phone-required' : '/main')
            : '/login');
    await Navigator.of(context).pushReplacementNamed(route);

    if (bootstrapNote != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Firestore 연결 지연/실패 — 오프라인으로 계속합니다.',
            style: TextStyle(fontSize: 12),
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFFFFFF),
      body: SizedBox.expand(),
    );
  }
}
