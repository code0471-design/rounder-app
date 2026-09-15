import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('기록', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: const Center(
        child: Text(
          '아직 기록이 없습니다',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
