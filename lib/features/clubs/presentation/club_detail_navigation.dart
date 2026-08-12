import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../di/app_dependencies.dart';
import '../../../models/club_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/club_provider.dart';
import '../application/club_detail_controller.dart';
import '../application/club_list_controller.dart';
import 'club_detail_dashboard_screen.dart';

/// 모임 상세(Firestore Controller) 진입
void openClubDetail(
  BuildContext context, {
  required Club club,
}) {
  final auth = context.read<AuthProvider>();
  final userId = auth.currentUser?.id ?? '';

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => ClubDetailController(
          clubRepository: AppDependencies.instance.clubRepository,
          joinRequestRepository: AppDependencies.instance.joinRequestRepository,
        )..load(clubId: club.id, userId: userId, initialClub: club),
        child: ClubDetailDashboardScreen(
          clubId: club.id,
          legacyProvider: context.read<ClubProvider>(),
        ),
      ),
    ),
  ).then((_) async {
    if (!context.mounted) return;
    final listCtrl = context.read<ClubListController>();
    if (userId.isNotEmpty) {
      await listCtrl.syncMembershipState(userId);
      try {
        final snap = await AppDependencies.instance.bootstrapForUser(userId);
        final pending = AppDependencies.instance.mockDataStore
                ?.pendingJoinRequests
                .where((r) => r.userId == userId)
                .toList() ??
            const [];
        if (context.mounted) {
          context.read<ClubProvider>().hydrateFromBootstrap(
                snap,
                pendingRequests: pending,
              );
        }
      } catch (_) {}
    } else {
      await listCtrl.refresh();
    }
  });
}
