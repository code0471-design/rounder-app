import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../di/app_dependencies.dart';
import '../application/club_list_controller.dart';
import 'club_list_dashboard_screen.dart';

/// 모임 찾기 진입 — 시드 후 대시보드 표시
Future<void> openClubListDashboard(BuildContext context) async {
  if (!AppDependencies.instance.isOfflineMockMode) {
    await AppDependencies.instance.ensureClubCatalogSeeded();
  }
  if (!context.mounted) return;

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const ClubListDashboardScreen(),
    ),
  );

  if (!context.mounted) return;
  context.read<ClubListController>().refresh();
}
