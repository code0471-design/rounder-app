import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/rounder_logo.dart';

/// Firebase/DI 부트스트랩 — 인트로와 같은 가운데 로고
class StartupLoadingScreen extends StatelessWidget {
  const StartupLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: _CenteredIntroLogo(),
      ),
    );
  }
}

class _CenteredIntroLogo extends StatelessWidget {
  const _CenteredIntroLogo();

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return Center(
      child: RounderLogo(
        vertical: true,
        height: h * 0.36,
        width: h * 0.36,
      ),
    );
  }
}

/// 치명적 시작 오류 — 재시도 버튼
class StartupFatalScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const StartupFatalScreen({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_outlined,
                    size: 56, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                const Text(
                  '연결이 지연되고 있습니다',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message.contains('Exception') || message.contains('Error')
                      ? '네트워크를 확인한 뒤 다시 시도해 주세요.'
                      : message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
