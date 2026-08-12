import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/club_model.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';
import 'create_club_screen.dart';
import 'club_detail_screen.dart';

// ════════════════════════════════════════════════════════════
//  ClubListScreen — 모임 탐색/검색/가입신청
// ════════════════════════════════════════════════════════════
class ClubListScreen extends StatefulWidget {
  const ClubListScreen({super.key});

  @override
  State<ClubListScreen> createState() => _ClubListScreenState();
}

class _ClubListScreenState extends State<ClubListScreen> {
  final _searchCtrl = TextEditingController();
  String _keyword   = '';
  String _region    = '전체';
  String _industry  = '전체';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
        () => setState(() => _keyword = _searchCtrl.text.trim()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final clubs = provider.filteredClubs(
          region: _region,
          industry: _industry,
          keyword: _keyword,
        );

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.primaryDark,
            title: const Text('모임 찾기',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CreateClubScreen()),
                ),
                icon: const Icon(Icons.add, color: AppColors.accent, size: 18),
                label: const Text('만들기',
                    style: TextStyle(
                        color: AppColors.accent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          body: Column(
            children: [
              // ── 검색창 ──
              _buildSearchBar(),
              // ── 필터 행 ──
              _buildFilterRow(),
              // ── 결과 수 ──
              _buildResultCount(clubs.length),
              // ── 모임 목록 ──
              Expanded(
                child: clubs.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                        itemCount: clubs.length,
                        itemBuilder: (_, i) => _ClubCard(
                          club: clubs[i],
                          provider: provider,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClubDetailScreen(
                                  club: clubs[i], provider: provider),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateClubScreen()),
            ),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('모임 만들기',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  // ────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: '모임 이름, 소개로 검색',
          hintStyle:
              const TextStyle(color: AppColors.textTertiary, fontSize: 14),
          prefixIcon:
              const Icon(Icons.search, color: AppColors.primary, size: 20),
          suffixIcon: _keyword.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear,
                      size: 18, color: AppColors.textSecondary),
                  onPressed: () => _searchCtrl.clear(),
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Row(
        children: [
          // 지역 필터
          Expanded(
            child: _FilterDropdown(
              icon: Icons.location_on_outlined,
              value: _region,
              items: kRegions,
              onChanged: (v) => setState(() => _region = v ?? '전체'),
            ),
          ),
          const SizedBox(width: 10),
          // 업종 필터
          Expanded(
            child: _FilterDropdown(
              icon: Icons.business_outlined,
              value: _industry,
              items: ['전체', ...kIndustries],
              onChanged: (v) => setState(() => _industry = v ?? '전체'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCount(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Text(
            '검색 결과 $count개',
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off,
              size: 56,
              color: AppColors.textSecondary.withValues(alpha: 0.35)),
          const SizedBox(height: 12),
          const Text('검색 결과가 없습니다',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateClubScreen()),
            ),
            child: const Text('새 모임 만들기',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════
//  모임 카드
// ════════════════════════════════════════
class _ClubCard extends StatelessWidget {
  final Club club;
  final ClubProvider provider;
  final VoidCallback onTap;
  const _ClubCard(
      {required this.club,
      required this.provider,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isMine    = provider.isMyClub(club.id);
    final isPending = provider.hasPendingRequest(club.id);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 아이콘/이미지
              _ClubAvatar(club: club),
              const SizedBox(width: 12),
              // 내용
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(club.name,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary)),
                        ),
                        if (isMine)
                          _Badge(label: '참여중', color: AppColors.primary)
                        else if (isPending)
                          _Badge(label: '신청중', color: AppColors.warning),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 태그들
                    Wrap(
                      spacing: 6,
                      children: [
                        _Tag(Icons.location_on_outlined, club.region),
                        _Tag(Icons.business_outlined, club.industry),
                        _Tag(Icons.people_outline,
                            '${club.memberCount}명'),
                        _Tag(Icons.sports_golf, '${club.teamCount}팀'),
                      ],
                    ),
                    if (club.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        club.description,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right,
                  color: AppColors.textSecondary, size: 18),
            ],
          ),
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
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            clubIndustryEmoji(club.industry),
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 1),
          Text(
            clubIndustryLabel(club.industry),
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                height: 1.0),
          ),
        ],
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
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold)),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Tag(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppColors.textSecondary),
        const SizedBox(width: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final IconData icon;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _FilterDropdown(
      {required this.icon,
      required this.value,
      required this.items,
      required this.onChanged});

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
          icon: const Icon(Icons.keyboard_arrow_down,
              size: 18, color: AppColors.textSecondary),
          style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500),
          items: items
              .map((i) => DropdownMenuItem(
                    value: i,
                    child: Row(
                      children: [
                        Icon(icon,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(i,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
