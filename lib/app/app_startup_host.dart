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
      if (!mounted) return;
      setState(() => _fatalError = e.toString());
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
  // MaterialApp을 중첩하면(특히 어드민 Expanded 안) 흰 빈 화면만 보이는 경우가 있음.
  // 오류 위젯은 항상 단순 컨테이너로 표시한다.
  ErrorWidget.builder = (details) {
    return ColoredBox(
      color: const Color(0xFFFFF5F5),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.bug_report_outlined,
                    size: 40, color: Colors.red),
                const SizedBox(height: 12),
                const Text(
                  '화면 렌더링 오류',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  details.exceptionAsString(),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
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
