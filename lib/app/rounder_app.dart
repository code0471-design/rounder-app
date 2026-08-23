import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../di/app_dependencies.dart';
import '../features/admin/application/admin_controller.dart';
import '../features/clubs/application/club_list_controller.dart';
import '../features/clubs/presentation/club_list_dashboard_screen.dart';
import '../navigation/app_navigator.dart';
import '../providers/auth_provider.dart';
import '../providers/club_provider.dart';
import '../screens/admin/admin_layout.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/phone_required_screen.dart';
import '../screens/clubs/create_club_screen.dart';
import '../screens/my_clubs/my_clubs_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../theme/app_theme.dart';
import 'app_startup_result.dart';

class RounderApp extends StatefulWidget {
  final AppStartupResult? startup;

  const RounderApp({super.key, this.startup});

  @override
  State<RounderApp> createState() => _RounderAppState();
}

class _RounderAppState extends State<RounderApp> {

  /// 웹 기본 = 어드민. 앱만 볼 때는 `?app=1`.
  /// `#/login` `#/main` 같은 예전 해시가 남아 있어도 어드민을 덮지 않음.
  static bool _isWebAdminMode() {
    if (!kIsWeb) return false;
    return Uri.base.queryParameters['app'] != '1';
  }

  @override
  Widget build(BuildContext context) {
    final webAdmin = _isWebAdminMode();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ClubProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (_) => ClubListController(
            clubRepository: AppDependencies.instance.clubRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminController(
            adminRepository: AppDependencies.instance.adminRepository,
          ),
        ),
      ],
      child: MaterialApp(
        navigatorKey: AppNavigator.key,
        title: '라운더',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        locale: const Locale('ko', 'KR'),
        supportedLocales: const [
          Locale('ko', 'KR'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          // 시스템 글자 확대는 허용하되 레이아웃 깨짐 방지를 위해 상한 제한
          final mq = MediaQuery.of(context);
          final clamped = mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: 1.15,
            ),
          );

          Widget content = child ??
              const ColoredBox(
                color: Colors.white,
                child: Center(child: CircularProgressIndicator()),
              );

          // 스테이징/Mock 경고 배너는 인트로 전에 깜빡이므로 사용자 화면에서는 숨긴다.

          return MediaQuery(data: clamped, child: content);
        },
        // URL 해시(#/login 등)가 있어도 웹 어드민 모드면 강제 어드민
        onGenerateInitialRoutes: (initialRoute) {
          if (webAdmin) {
            return [
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: '/admin'),
                builder: (_) => const AdminRootScreen(),
              ),
            ];
          }
          return [
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/'),
              builder: (_) => const SplashScreen(),
            ),
          ];
        },
        routes: {
          '/': (_) => webAdmin ? const AdminRootScreen() : const SplashScreen(),
          '/main': (_) => const MyClubsScreen(),
          '/login': (_) => const LoginScreen(),
          '/signup': (_) => const SignupScreen(),
          '/phone-required': (_) => const PhoneRequiredScreen(),
          '/clubs': (_) => const ClubListDashboardScreen(),
          '/clubs/create': (_) => const CreateClubScreen(),
          '/admin': (_) => const AdminRootScreen(),
        },
      ),
    );
  }
}
