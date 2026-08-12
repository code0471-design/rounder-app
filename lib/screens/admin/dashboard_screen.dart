// ════════════════════════════════════════════════════════════
//  ROUNDER Admin — Dashboard Home
//  요약 카드 + 주간 그래프 + 최근 현황
// ════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'admin_theme.dart';
import 'package:provider/provider.dart';
import '../../di/app_dependencies.dart';
import '../../features/admin/application/admin_app_sync.dart';
import '../../features/admin/application/admin_controller.dart';
import '../../providers/club_provider.dart';
import 'admin_models.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminController>();
    final clubsApp = context.watch<ClubProvider>();
    final stats = admin.stats;

    // Mock 모드면 공유 스토어 운영 모임 수를 우선 (시드 6개와 어드민 일치)
    final store = AppDependencies.instance.mockDataStore;
    final int mergedClubCount;
    if (store != null) {
      mergedClubCount = store.clubs.where((c) {
        final s = store.clubModerationStatus(c.id);
        return s == 'active' || s == 'pending';
      }).length;
    } else {
      final clubIds = <String>{
        for (final c in admin.clubs)
          if (c.status == 'active' || c.status == 'pending') c.id,
        for (final c in clubsApp.myClubs)
          if (c.id.startsWith('c_') || clubsApp.isFreshClub(c.id)) c.id,
        for (final c in clubsApp.allClubs)
          if (c.id.startsWith('c_') || clubsApp.isFreshClub(c.id)) c.id,
      };
      mergedClubCount = {
        for (final c in admin.clubs)
          if (c.status == 'active' || c.status == 'pending') c.id,
        ...clubIds,
      }.length;
    }

    return ColoredBox(
      color: AdminColors.contentBg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AdminSizes.sectionPadding, AdminSizes.listPagePaddingTop, AdminSizes.sectionPadding, AdminSizes.sectionPadding),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPageHeader(),
                  const SizedBox(height: 16),
                  _buildSyncBanner(admin, mergedClubCount),
                  const SizedBox(height: 20),
                  _buildStatCards(stats, admin.clubs, mergedClubCount),
                  const SizedBox(height: 24),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: _buildWeeklySignupsCard(stats)),
                        const SizedBox(width: 16),
                        Expanded(flex: 4, child: _buildWeeklyClubsCard(stats)),
                      ],
                    )
                  else ...[
                    _buildWeeklySignupsCard(stats),
                    const SizedBox(height: 16),
                    _buildWeeklyClubsCard(stats),
                  ],
                  const SizedBox(height: 24),
                  _buildRecentMembers(admin),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeeklySignupsCard(DashboardStats stats) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
              '주간 신규 가입자', Icons.person_add_rounded, AdminColors.statusOk),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: _WeeklyBarChart(
              data: stats.weeklySignups,
              color: AdminColors.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyClubsCard(DashboardStats stats) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
              '주간 모임 개설', Icons.group_add_rounded, AdminColors.statusInfo),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: _WeeklyBarChart(
              data: stats.weeklyClubs,
              color: AdminColors.statusInfo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncBanner(AdminController admin, int mergedClubCount) {
    final report = AdminAppSync.lastReport;
    // 회원 수는 AdminController 스트림(실제 목록)을 우선 — lastReport의
    // memberCount는 user_me 제외 집계라 0으로 보이는 불일치가 날 수 있음
    final memberCount = admin.members.length;
    final modeTag = AppDependencies.instance.isOfflineMockMode ? ' · Mock' : '';
    final detail = report == null
        ? '우측 상단 새로고침으로 앱 모임을 불러오세요'
        : '모임 $mergedClubCount · 회원 $memberCount$modeTag'
            '${report.userClubNames.isEmpty ? '' : ' · 생성:${report.userClubNames.join(", ")}'}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0EC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1B4D3E).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync_rounded, color: Color(0xFF1B4D3E), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              detail,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF152820),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader() {
    final now = DateTime.now();
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('대시보드', style: AdminTextStyles.pageTitle),
            Text(
              '${now.year}년 ${now.month}월 ${now.day}일 기준 데이터',
              style: const TextStyle(color: AdminColors.textSecond, fontSize: 13),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AdminColors.accent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download_rounded, color: Colors.white, size: 15),
              SizedBox(width: 6),
              Text('리포트 내보내기', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards(
      DashboardStats stats, List<AdminClub> clubs, int mergedClubCount) {
    final clubCount = mergedClubCount;
    final cards = [
      _StatCardData(
        label: '총 회원 수',
        value: '${stats.totalMembers.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}명',
        change: '+3.2%',
        isUp: true,
        icon: Icons.people_rounded,
        gradient: [AdminColors.statGreen1, AdminColors.statGreen2],
        subLabel: '전주 대비',
      ),
      _StatCardData(
        label: '전체 모임 수',
        value: '$clubCount개',
        change: '+5개',
        isUp: true,
        icon: Icons.golf_course_rounded,
        gradient: [AdminColors.statBlue1, AdminColors.statBlue2],
        subLabel: '운영 중',
      ),
      _StatCardData(
        label: '오늘 가입자',
        value: '${stats.todaySignups}명',
        change: '+4명',
        isUp: true,
        icon: Icons.person_add_rounded,
        gradient: [AdminColors.statPurple1, AdminColors.statPurple2],
        subLabel: '어제 대비',
      ),
      _StatCardData(
        label: '오늘 개설 모임',
        value: '${stats.todayNewClubs}개',
        change: '±0개',
        isUp: true,
        icon: Icons.group_add_rounded,
        gradient: [AdminColors.statOrange1, AdminColors.statOrange2],
        subLabel: '어제 대비',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : 600.0;
        final crossAxisCount = maxW > 900 ? 4 : 2;
        final itemWidth =
            (maxW - (crossAxisCount - 1) * 16) / crossAxisCount;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: cards
              .map((c) => SizedBox(
                    width: itemWidth.clamp(140.0, maxW),
                    child: _buildStatCard(c),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildStatCard(_StatCardData data) {
    return Container(
      constraints: const BoxConstraints(minHeight: 130),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: data.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AdminSizes.cardRadius),
        boxShadow: [
          BoxShadow(
            color: data.gradient.first.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(data.icon, color: Colors.white.withValues(alpha: 0.9), size: 20),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      data.isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      color: Colors.white,
                      size: 11,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      data.change,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(data.value, style: AdminTextStyles.cardValue),
          const SizedBox(height: 2),
          Text(data.label, style: AdminTextStyles.cardLabel),
        ],
      ),
    );
  }

  Widget _buildCardHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(title, style: AdminTextStyles.sectionTitle),
        const Spacer(),
        Text('최근 7일', style: TextStyle(color: AdminColors.textHint, fontSize: 12)),
      ],
    );
  }

  Widget _buildRecentMembers(AdminController admin) {
    final recent = admin.members.take(5).toList();

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
              '최근 가입 회원', Icons.person_outline_rounded, AdminColors.statusOk),
          const SizedBox(height: 16),
          const Divider(color: AdminColors.divider, height: 1),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '가입 회원이 없습니다',
                  style: TextStyle(color: AdminColors.textHint, fontSize: 13),
                ),
              ),
            )
          else
            ...recent.map((m) => _buildMemberRow(m)),
        ],
      ),
    );
  }

  Widget _buildMemberRow(AdminMember m) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AdminColors.divider)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AdminColors.accent.withValues(alpha: 0.12),
            child: Text(
              m.name.isNotEmpty ? m.name.substring(0, 1) : '?',
              style: const TextStyle(color: AdminColors.accent, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminColors.textPrimary)),
                Text(m.phone, style: const TextStyle(fontSize: 11, color: AdminColors.textHint)),
              ],
            ),
          ),
          Text(
            m.joinDate.length >= 10 ? m.joinDate.substring(5) : m.joinDate,
            style: const TextStyle(fontSize: 11, color: AdminColors.textHint),
          ),
          const SizedBox(width: 8),
          AdminBadge(label: m.statusLabel, color: m.statusColor),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  Weekly Bar Chart (Custom Painter)
// ────────────────────────────────────────────────────────────
class _WeeklyBarChart extends StatelessWidget {
  final List<int> data;
  final Color color;

  const _WeeklyBarChart({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Text('데이터 없음', style: TextStyle(color: AdminColors.textHint)),
      );
    }
    final maxVal = data.reduce((a, b) => a > b ? a : b).toDouble();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(data.length, (i) {
        final ratio = maxVal > 0 ? data[i] / maxVal : 0.0;
        final isMax = data[i] == data.reduce((a, b) => a > b ? a : b);
        final dayLabel = i < AdminCatalog.weekDays.length
            ? AdminCatalog.weekDays[i]
            : '';

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Value Label
                Text(
                  '${data[i]}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isMax ? color : AdminColors.textHint,
                  ),
                ),
                const SizedBox(height: 4),
                // Bar
                AnimatedContainer(
                  duration: Duration(milliseconds: 400 + i * 60),
                  curve: Curves.easeOut,
                  height: 130 * ratio.clamp(0.05, 1.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: isMax ? 1.0 : 0.5),
                        color.withValues(alpha: isMax ? 0.7 : 0.3),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                  ),
                ),
                const SizedBox(height: 6),
                // Day Label
                Text(
                  dayLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: isMax ? color : AdminColors.textHint,
                    fontWeight: isMax ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ── Helper Data Class
class _StatCardData {
  final String label;
  final String value;
  final String change;
  final bool isUp;
  final IconData icon;
  final List<Color> gradient;
  final String subLabel;

  const _StatCardData({
    required this.label,
    required this.value,
    required this.change,
    required this.isUp,
    required this.icon,
    required this.gradient,
    required this.subLabel,
  });
}
