import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../di/app_dependencies.dart';
import '../../models/club_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';
import '../../features/clubs/presentation/club_list_navigation.dart';
import '../club_room/club_room_screen.dart';
import '../clubs/create_club_screen.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/app_header.dart';
import 'widgets/home_hero_header.dart';
import 'widgets/home_quick_actions.dart';
import 'widgets/home_club_card.dart';

// ════════════════════════════════════════════════════════════
//  MyClubsScreen — Premium Home (Clean Slate v1)
// ════════════════════════════════════════════════════════════
class MyClubsScreen extends StatelessWidget {
  const MyClubsScreen({super.key});

  Future<void> _refreshClubs(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      await Future.delayed(const Duration(milliseconds: 400));
      return;
    }
    final userId = auth.currentUser!.id;
    final snap = await AppDependencies.instance.bootstrapForUser(userId);
    final pending = AppDependencies.instance.mockDataStore
            ?.pendingJoinRequests
            .where((r) => r.userId == userId)
            .toList() ??
        const [];
    if (context.mounted) {
      final clubs = context.read<ClubProvider>();
      clubs.hydrateFromBootstrap(
        snap,
        pendingRequests: pending,
      );
      await clubs.refreshOwnedClubs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final clubs = provider.myClubs;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              HomeHeroHeader(
                onNotificationTap: () =>
                    _openNotifications(context, provider),
                onProfileTap: () => AppHeader.openMyPage(context),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onRefresh: () => _refreshClubs(context),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 12),
                      ),
                      const SliverToBoxAdapter(
                        child: HomeQuickActions(),
                      ),
                      SliverToBoxAdapter(
                        child: _SectionHeader(count: clubs.length),
                      ),
                      if (clubs.isEmpty)
                        SliverToBoxAdapter(
                          child: _EmptyClubs(
                            onFind: () => openClubListDashboard(context),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => HomeClubCard(
                              club: clubs[i],
                              onTap: () =>
                                  _enterClub(context, provider, clubs[i]),
                            ),
                            childCount: clubs.length,
                          ),
                        ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 32),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _enterClub(BuildContext context, ClubProvider provider, Club club) {
    provider.selectClubById(club.id);
    final selected = provider.myClubs.firstWhere(
      (c) => c.id == club.id,
      orElse: () => club,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClubRoomScreen(club: selected),
      ),
    );
  }

  void _goCreate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateClubScreen()),
    );
  }

  void _openNotifications(BuildContext context, ClubProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => Consumer<ClubProvider>(
          builder: (context, prov, __) {
            final notifs = prov.visibleNotifications;
            final unread = prov.visibleUnreadNotificationCount;

            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_outlined,
                          color: AppColors.primary, size: 22),
                      const SizedBox(width: 8),
                      const Text('알림', style: AppText.title),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (unread > 0)
                        TextButton(
                          onPressed: prov.markAllVisibleNotificationsRead,
                          child: const Text('모두 읽음',
                              style: TextStyle(fontSize: 12)),
                        ),
                      if (notifs.isNotEmpty)
                        TextButton(
                          onPressed: prov.removeAllVisibleNotifications,
                          child: const Text('전체 삭제',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.danger)),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: notifs.isEmpty
                      ? const Center(
                          child: EmptyState(
                            icon: Icons.notifications_none_outlined,
                            title: '새로운 알림이 없습니다',
                          ),
                        )
                      : ListView.separated(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.all(16),
                          itemCount: notifs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _NotificationTile(
                            notification: notifs[i],
                            onRead: () =>
                                prov.markNotificationRead(notifs[i].id),
                            onDelete: () =>
                                prov.removeNotification(notifs[i].id),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── 섹션 헤더 ──
class _SectionHeader extends StatelessWidget {
  final int count;
  const _SectionHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            '내 모임',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: -0.3,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 빈 상태 ──
class _EmptyClubs extends StatelessWidget {
  final VoidCallback onFind;
  const _EmptyClubs({required this.onFind});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          children: [
            Icon(
              Icons.sports_golf_rounded,
              size: 48,
              color: AppColors.primary.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            const Text(
              '아직 참여 중인 모임이 없어요',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '모임을 찾거나 가입 신청해 보세요',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onFind,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
                child: const Text(
                  '모임 찾기',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 알림 타일 ──
class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onRead;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.notification,
    required this.onRead,
    required this.onDelete,
  });

  IconData get _icon {
    switch (notification.type) {
      case AppNotificationType.joinRequest:
        return Icons.how_to_reg_outlined;
      case AppNotificationType.joinApproved:
        return Icons.check_circle_outline;
      case AppNotificationType.announcement:
        return Icons.campaign_outlined;
      case AppNotificationType.schedule:
        return Icons.event_outlined;
      case AppNotificationType.comment:
        return Icons.chat_bubble_outline;
      case AppNotificationType.paymentRequest:
        return Icons.payments_outlined;
      case AppNotificationType.attendanceChanged:
        return Icons.how_to_reg_outlined;
      case AppNotificationType.memberKicked:
        return Icons.block_outlined;
      case AppNotificationType.scheduleChanged:
        return Icons.edit_calendar_outlined;
      case AppNotificationType.scheduleCancelled:
        return Icons.event_busy_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onRead,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Ink(
            decoration: AppDecorations.standardCard.copyWith(
              color: unread ? AppColors.surface : AppColors.surfaceVariant,
              border: Border.all(
                color: unread
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.divider,
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: unread
                        ? AppColors.sageLighter
                        : AppColors.divider.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _icon,
                    size: 20,
                    color: unread ? AppColors.primary : AppColors.textTertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.clubName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: unread
                              ? AppColors.primary
                              : AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w500,
                          color: unread
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: unread
                              ? AppColors.textSecondary
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close,
                      size: 18,
                      color: AppColors.textTertiary.withValues(alpha: 0.7)),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
