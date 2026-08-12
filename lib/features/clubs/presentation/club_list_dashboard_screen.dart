import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../di/app_dependencies.dart';
import '../../../domain/services/club_discovery_service.dart';
import '../../../models/club_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/club_provider.dart';
import '../../../screens/clubs/create_club_screen.dart';
import '../../../theme/app_theme.dart';
import '../application/club_list_controller.dart';
import 'club_detail_navigation.dart';

/// 모임 목록 대시보드 — Presentation Layer (Firestore Controller 기반)
class ClubListDashboardScreen extends StatefulWidget {
  const ClubListDashboardScreen({super.key});

  @override
  State<ClubListDashboardScreen> createState() =>
      _ClubListDashboardScreenState();
}

class _ClubListDashboardScreenState extends State<ClubListDashboardScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      context.read<ClubListController>().updateFilters(
            keyword: _searchCtrl.text.trim(),
          );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!AppDependencies.instance.isOfflineMockMode) {
        await AppDependencies.instance.ensureClubCatalogSeeded();
      }

      if (!mounted) return;

      final auth = context.read<AuthProvider>();
      final userId = auth.currentUser?.id ?? '';

      final bootstrap = AppDependencies.instance.lastBootstrap;
      if (bootstrap != null) {
        context.read<ClubListController>().updateMembershipHints(
              myClubIds: bootstrap.myClubs.map((c) => c.id).toSet(),
            );
      }
      await context.read<ClubListController>().load(userId: userId);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final legacyProvider = context.watch<ClubProvider>();

    return Consumer<ClubListController>(
      builder: (context, controller, _) {
        // Firebase: Firestore(controller)만. Mock일 때만 ClubProvider 목록 병합
        final byId = <String, Club>{
          for (final c in controller.clubs)
            ClubProvider.legacyClubIdFor(c.id): c,
          if (AppDependencies.instance.isOfflineMockMode)
            for (final c in legacyProvider.allClubs) c.id: c,
        };
        final clubs = ClubDiscoveryService.filter(
          clubs: byId.values.toList(),
          region: controller.region,
          industry: controller.industry,
          keyword: controller.keyword,
        )..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.primaryDark,
            title: const Text(
              '모임 찾기',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              if (controller.state == ClubListLoadState.loading)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () {
              final userId =
                  context.read<AuthProvider>().currentUser?.id ?? '';
              return controller.refresh(userId: userId);
            },
            child: _buildBody(controller, clubs, legacyProvider),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateClubScreen()),
              );
              if (!context.mounted) return;
              final userId =
                  context.read<AuthProvider>().currentUser?.id ?? '';
              await context.read<ClubListController>().refresh(userId: userId);
            },
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              '모임 만들기',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    ClubListController controller,
    List<Club> clubs,
    ClubProvider legacyProvider,
  ) {
    if (controller.state == ClubListLoadState.error) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.cloud_off,
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            '모임 목록을 불러오지 못했습니다',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            controller.errorMessage ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: controller.refresh,
              child: const Text('다시 시도'),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (controller.usingLocalFallback) _LocalFallbackBanner(controller: controller),
        _SearchBar(controller: _searchCtrl),
        _FilterRow(
          region: controller.region,
          industry: controller.industry,
          onRegionChanged: (v) =>
              controller.updateFilters(region: v ?? '전체'),
          onIndustryChanged: (v) =>
              controller.updateFilters(industry: v ?? '전체'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '검색 결과 ${clubs.length}개',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        Expanded(
          child: clubs.isEmpty
              ? _EmptyResult(onSeed: controller.seedAndReload)
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 88),
                  itemCount: clubs.length,
                  itemBuilder: (_, i) => _ClubListCard(
                    club: clubs[i],
                    isPending: controller.hasPendingRequest(clubs[i].id) ||
                        legacyProvider.hasPendingRequest(clubs[i].id) ||
                        legacyProvider.hasPendingRequest(
                            ClubProvider.legacyClubIdFor(clubs[i].id)),
                    isMine: !legacyProvider.hasLeftClub(clubs[i].id) &&
                        !(controller.hasPendingRequest(clubs[i].id) ||
                            legacyProvider.hasPendingRequest(clubs[i].id) ||
                            legacyProvider.hasPendingRequest(
                                ClubProvider.legacyClubIdFor(clubs[i].id))) &&
                        (legacyProvider.isMyClub(clubs[i].id) ||
                            controller.isMyClub(clubs[i].id)),
                    onTap: () => openClubDetail(context, club: clubs[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: '모임 이름, 소개로 검색',
          prefixIcon: const Icon(Icons.search, color: AppColors.primary),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final String region;
  final String industry;
  final ValueChanged<String?> onRegionChanged;
  final ValueChanged<String?> onIndustryChanged;

  const _FilterRow({
    required this.region,
    required this.industry,
    required this.onRegionChanged,
    required this.onIndustryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: _FilterDropdown(
              icon: Icons.location_on_outlined,
              value: region,
              items: kRegions,
              onChanged: onRegionChanged,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _FilterDropdown(
              icon: Icons.business_outlined,
              value: industry,
              items: ['전체', ...kIndustries],
              onChanged: onIndustryChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubListCard extends StatelessWidget {
  final Club club;
  final bool isMine;
  final bool isPending;
  final VoidCallback onTap;

  const _ClubListCard({
    required this.club,
    required this.isMine,
    required this.isPending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _ClubAvatar(club: club),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          club.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isMine)
                        _Badge(label: '참여중', color: AppColors.primary)
                      else if (isPending)
                        _Badge(label: '신청중', color: AppColors.warning),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${club.region} · ${club.industry} · ${club.memberCount}명',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _ClubAvatar extends StatelessWidget {
  final Club club;
  const _ClubAvatar({required this.club});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        clubIndustryEmoji(club.industry),
        style: const TextStyle(fontSize: 22),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _LocalFallbackBanner extends StatelessWidget {
  final ClubListController controller;
  const _LocalFallbackBanner({required this.controller});

  @override
  Widget build(BuildContext context) {
    final mockMode = AppDependencies.instance.isOfflineMockMode;
    return MaterialBanner(
      backgroundColor: AppColors.accentSoft,
      content: Text(
        mockMode
            ? '오프라인 Mock 모드 — 로컬 샘플 데이터로 실행 중입니다.'
            : 'Firestore에 모임이 없거나 연결되지 않아 샘플 데이터를 표시합니다.',
        style: const TextStyle(fontSize: 12),
      ),
      actions: [
        if (!mockMode)
          TextButton(
            onPressed: controller.seedAndReload,
            child: const Text('Firestore에 업로드'),
          ),
        TextButton(
          onPressed: () =>
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

class _EmptyResult extends StatelessWidget {
  final VoidCallback onSeed;
  const _EmptyResult({required this.onSeed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '검색 결과가 없습니다',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onSeed,
            child: const Text('샘플 모임 데이터 불러오기'),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final IconData icon;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items
              .map((i) => DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
