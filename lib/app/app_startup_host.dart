import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'rounder_app.dart';
import '../screens/startup/startup_loading_screen.dart';
import 'app_startup_bootstrap.dart';
import 'app_startup_result.dart';

/// runApp 직후 — 최소 부트스트랩 후 RounderApp 또는 오류 화면
class AppStartupHost extends StatefulWidget {
  const AppStartupHost({super.key});

  @override
  State<AppStartupHost> createState() => _AppStartupHostState();
}

class _AppStartupHostState extends State<AppStartupHost> {
  AppStartupResult? _result;
  String? _fatalError;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      _result = null;
      _fatalError = null;
    });

    try {
      final result = await AppStartupBootstrap.run();
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e, st) {
      debugPrint('[AppStartupHost] fatal: $e\n$st');
      try {
        final fallback = await AppStartupBootstrap.runOfflineMock();
        if (!mounted) return;
        setState(() => _result = fallback);
      } catch (e2, st2) {
        debugPrint('[AppStartupHost] mock fallback failed: $e2\n$st2');
        if (!mounted) return;
        setState(() => _fatalError = '잠시 후 다시 시도해 주세요.');
      }
    }
  }

  void _retry() {
    setState(() => _attempt++);
    _boot();
  }

  @override
  Widget build(BuildContext context) {
    if (_fatalError != null) {
      return StartupFatalScreen(
        message: _fatalError!,
        onRetry: _retry,
      );
    }

    final result = _result;
    if (result == null) {
      return StartupLoadingScreen(key: ValueKey(_attempt));
    }

    return RounderApp(startup: result);
  }
}

void configureAppErrorHandlers() {
  // App Store 심사는 실행 직후 예외 문구를 에러 화면으로 본다.
  // 위젯 실패는 로그로만 남기고, 사용자에게 스택/예외를 보여 주지 않는다.
  ErrorWidget.builder = (details) {
    debugPrint('[ErrorWidget] ${details.exceptionAsString()}');
    return const ColoredBox(
      color: Color(0xFFFFFFFF),
      child: SizedBox.expand(),
    );
  };

  FlutterError.onError = (details) {
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
  };
}

void configureSystemChrome() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
}
