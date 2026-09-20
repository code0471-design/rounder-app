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
        await context.read<ClubProvider>().switchUser(
              userId,
              displayName: auth.currentUser!.name,
              birthDate: auth.currentUser!.birthDate,
              handicap: auth.currentUser!.handicap,
              gender: auth.currentUser!.gender,
              phone: auth.currentUser!.phone,
              photoUrl: auth.currentUser!.profileImageUrl,
            );
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
    // 시작 로딩에서 이미 로고를 보여 줬다. 여기서 다시 그리면 인트로가 두 번이다.
    var autoLoggedIn = await _autoLoginAndHydrate();

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

    // 이 기능 전에 가입한 계정은 생년월일·핸디가 비어 있다.
    // 핸디가 없으면 자동 조편성이 초보로 잡으므로 한 번만 물어본다.
    var next = autoLoggedIn ? '/main' : '/login';
    if (autoLoggedIn && await auth.shouldAskGolfProfile()) {
      next = '/golf-profile';
    }
    if (!mounted) return;

    final route = wantsAdmin ? '/admin' : next;
    await Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SizedBox.expand(),
      ),
    );
  }
}
