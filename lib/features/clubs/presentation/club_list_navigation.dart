import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../application/club_list_controller.dart';
import 'club_list_dashboard_screen.dart';

/// 모임 찾기 진입 — 시드를 기다리지 않고 바로 연다.
Future<void> openClubListDashboard(BuildContext context) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const ClubListDashboardScreen(),
    ),
  );

  if (!context.mounted) return;
  final userId = context.read<AuthProvider>().currentUser?.id ?? '';
  unawaited(context.read<ClubListController>().refresh(userId: userId));
}
