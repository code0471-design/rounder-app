import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/club_model.dart';
import '../../models/member_role.dart';
import '../../providers/club_provider.dart';
import '../../services/csv_download.dart';
import '../../services/member_roster_csv.dart';
import '../../theme/app_theme.dart';
import '../../utils/avatar_image.dart';
import 'member_detail_screen.dart';
import 'treasurer_transfer_screen.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ────────────────────────────────
  // 검색 필터
  // ────────────────────────────────
  List<Member> _filter(List<Member> list) {
    if (_searchQuery.isEmpty) return list;
    return list
        .where((m) => m.name.contains(_searchQuery))
        .toList();
  }

  List<Member> _membersForCurrentTab({
    required List<Member> all,
    required List<Member> regular,
    required List<Member> guests,
  }) {
    switch (_tabController.index) {
      case 1:
        return regular;
      case 2:
        return guests;
      default:
        return all;
    }
  }

  Future<void> _downloadExcel(
    BuildContext context,
    ClubProvider provider, {
    required List<Member> all,
    required List<Member> regular,
    required List<Member> guests,
  }) async {
    final members = _membersForCurrentTab(
      all: all,
      regular: regular,
      guests: guests,
    );
    if (members.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('다운로드할 회원이 없습니다')),
      );
      return;
    }

    final clubName = safeFileStem(provider.selectedClub.name);
    final filename = '${clubName}_회원명단.xlsx';
    try {
      await downloadCsvFile(
        filename: filename,
        bytes: clubMemberRosterXlsx(members),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파일 앱의 다운로드 폴더에서 열어 주세요')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('엑셀 파일을 만들지 못했습니다')),
      );
    }
  }

  /// 세그먼트 탭 — 폭이 좁아도 글자가 잘리지 않게 축소만 허용한다.
  /// (고정 height 40 + 라벨 3등분에서 "전체 (" 처럼 끊기던 문제)
  Tab _segmentTab(String label, int count) {
    return Tab(
      height: 36,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$label ($count)',
          maxLines: 1,
          softWrap: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final all = _filter(provider.activeMembers);
        final regular = _filter(provider.regularMembers);
        final guests = _filter(provider.guestMembers);
        final totalAll = provider.activeMembers.length;
        final totalReg = provider.regularMembers.length;
        final totalGuest = provider.guestMembers.length;

        final pending =
            provider.pendingRequestsOf(provider.selectedClub.id);

        return Scaffold(
          backgroundColor: AppColors.cream,
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicatorPadding: const EdgeInsets.all(4),
                          labelColor: Colors.white,
                          unselectedLabelColor: AppColors.ink,
                          dividerColor: Colors.transparent,
                          labelPadding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          tabs: [
                            _segmentTab('전체', totalAll),
                            _segmentTab('정회원', totalReg),
                            _segmentTab('게스트', totalGuest),
                          ],
                        ),
                      ),
                    ),
                    if (pending.isNotEmpty)
                      IconButton(
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.how_to_reg,
                                color: AppColors.primary),
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(
                                  color: AppColors.danger,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${pending.length}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        tooltip: '가입 신청',
                        onPressed: () =>
                            _showJoinRequests(context, provider),
                      ),
                    // 초대는 홈 탭의 '정회원 초대하기 / 게스트 초대하기' 버튼으로 통일.
                    // 여기서는 명단 내보내기만 남긴다.
                    if (provider.isClubExecutive)
                      IconButton(
                        icon: const Icon(Icons.file_download_outlined,
                            color: AppColors.primary),
                        tooltip: '명단 엑셀 다운로드',
                        onPressed: () => _downloadExcel(
                          context,
                          provider,
                          all: all,
                          regular: regular,
                          guests: guests,
                        ),
                      ),
                  ],
                ),
              ),
              _buildSearchBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTabContent(all, provider, showSections: true),
                    _buildTabContent(regular, provider, showSections: true),
                    _buildTabContent(guests, provider, showSections: false),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ────────────────────────────────
  // 검색창
  // ────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: '이름으로 검색',
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: AppColors.accent),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────
  // 멤버십 포인트 TOP3 랭킹 배너
  // ────────────────────────────────
  Widget _buildPointsRankingBanner(ClubProvider provider) {
    final ranking = provider.memberPointsRanking;
    if (ranking.isEmpty) return const SizedBox.shrink();
    final top3 = ranking.take(3).toList();

    return GestureDetector(
      onTap: () => _showFullRankingSheet(provider),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('올해 랭킹',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
            const SizedBox(height: 8),
            ...List.generate(top3.length, (i) {
              final entry = top3[i];
              final memberObj = provider.activeMembers
                  .where((m) => m.id == entry.key)
                  .firstOrNull;
              final name = memberObj?.name ?? entry.key;
              final medalColors = [
                const Color(0xFFD4AF37),
                const Color(0xFF9CA3AF),
                const Color(0xFFBF8B40),
              ];
              return Column(
                children: [
                  if (i > 0)
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: medalColors[i],
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text('${i + 1}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(name,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink)),
                        ),
                        Text('${entry.value}P',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2563EB))),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────
  // 전체 랭킹 바텀시트
  // ────────────────────────────────
  void _showFullRankingSheet(ClubProvider provider) {
    final ranking = provider.memberPointsRanking;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            // 핸들
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            // 헤더
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Text('🏅', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Text('멤버십 포인트 랭킹',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  SizedBox(width: 6),
                  Text('(올해 기준)',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Divider(height: 1),
            // 랭킹 목록
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: ranking.length,
                itemBuilder: (_, idx) {
                  final entry = ranking[idx];
                  final memberId = entry.key;
                  final pts = entry.value;
                  final memberObj = provider.activeMembers
                      .where((m) => m.id == memberId)
                      .firstOrNull;
                  final name = memberObj?.name ?? memberId;
                  final rank = idx + 1;
                  final rankLabel = rank == 1
                      ? '🥇'
                      : rank == 2
                          ? '🥈'
                          : rank == 3
                              ? '🥉'
                              : '$rank';
                  return ListTile(
                    leading: SizedBox(
                      width: 32,
                      child: Center(
                        child: Text(rankLabel,
                            style: TextStyle(
                                fontSize: rank <= 3 ? 20 : 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary)),
                      ),
                    ),
                    title: Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(memberObj?.role ?? '',
                        style: const TextStyle(fontSize: 11)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: rank <= 3
                            ? const Color(0xFF1A237E).withValues(alpha: 0.1)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$pts P',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: rank <= 3
                              ? const Color(0xFF1A237E)
                              : AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // 포인트 기준 안내
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('포인트 적립 기준',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary)),
                  SizedBox(height: 6),
                  _PointGuideRow(label: '라운딩 참석', pts: '+10 P'),
                  _PointGuideRow(label: '회비 납부', pts: '+5 P'),
                  _PointGuideRow(label: '공지 참여', pts: '+2 P'),
                  // _PointGuideRow(label: '후원사 감사인사', pts: '+2 P'),
                  _PointGuideRow(label: '노쇼', pts: '-10 P', negative: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────
  // 탭 컨텐츠 (섹션 구분 여부)
  // ────────────────────────────────
  Widget _buildTabContent(
    List<Member> filtered,
    ClubProvider provider, {
    required bool showSections,
  }) {
    final scrollHeader = <Widget>[
      _buildPointsRankingBanner(provider),
      _TreasurerTransferEntry(
        canAccess: provider.canAccessTreasurerTransfer,
      ),
    ];

    if (filtered.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        children: [
          ...scrollHeader,
          _buildEmptyState(),
        ],
      );
    }

    if (!showSections) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        children: [
          ...scrollHeader,
          const SizedBox(height: 8),
          ...filtered.map(
            (m) => _MemberCard(member: m, provider: provider),
          ),
        ],
      );
    }

    final officers =
        filtered.where((m) => ClubMemberRole.isOfficer(m.role)).toList();
    final regular = filtered
        .where((m) =>
            !ClubMemberRole.isOfficer(m.role) &&
            m.memberType != ClubMemberRole.guest)
        .toList();
    final guests = filtered
        .where((m) => m.memberType == ClubMemberRole.guest)
        .toList();

    final allItems = <Widget>[
      ...scrollHeader,
      if (officers.isNotEmpty) ...[
        _SectionHeader(title: '임원진', count: officers.length),
        ...officers.map((m) => _MemberCard(member: m, provider: provider)),
      ],
      if (regular.isNotEmpty) ...[
        _SectionHeader(title: '정회원', count: regular.length),
        ...regular.map((m) => _MemberCard(member: m, provider: provider)),
      ],
      if (guests.isNotEmpty) ...[
        _SectionHeader(title: '게스트', count: guests.length),
        ...guests.map((m) => _MemberCard(member: m, provider: provider)),
      ],
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: allItems,
    );
  }

  // ────────────────────────────────
  // 빈 상태
  // ────────────────────────────────
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline,
              size: 56, color: AppColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isEmpty ? '회원이 없습니다' : '"$_searchQuery" 검색 결과 없음',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────
  // 가입 신청 목록 시트
  // ────────────────────────────────
  void _showJoinRequests(BuildContext context, ClubProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) =>
          _JoinRequestSheet(provider: provider),
    );
  }
}

// ════════════════════════════════════════
// 섹션 헤더
// ════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════
// 회원 카드
// ════════════════════════════════════════
class _MemberCard extends StatelessWidget {
  final Member member;
  final ClubProvider provider;
  const _MemberCard({required this.member, required this.provider});

  @override
  Widget build(BuildContext context) {
    final isOfficer = ClubMemberRole.isOfficer(member.role);
    final isGuest = member.memberType == ClubMemberRole.guest;

    // 아바타 색상 / 이니셜
    Color avatarBg;
    Color avatarFg;
    if (isOfficer) {
      avatarBg = AppColors.primary.withValues(alpha: 0.15);
      avatarFg = AppColors.primary;
    } else if (isGuest) {
      avatarBg = AppColors.warning.withValues(alpha: 0.12);
      avatarFg = AppColors.warning;
    } else {
      avatarBg = AppColors.primaryLight.withValues(alpha: 0.1);
      avatarFg = AppColors.primaryLight;
    }

    // 그림자는 바깥 Container, ripple은 ClipRRect + Material + InkWell로 처리
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MemberDetailScreen(
                    member: member,
                    provider: provider,
                  ),
                ),
              );
            },
            splashColor: AppColors.mintBright.withValues(alpha: 0.2),
            highlightColor: AppColors.mintPale.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  _buildAvatar(avatarBg, avatarFg),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              member.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (isOfficer)
                              Text(member.role,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF9CA3AF))),
                            if (isGuest) _GuestBadge(),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          provider.selectedClub.name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        member.age > 0
                            ? '${member.age}세 · ${member.gender}'
                            : member.gender,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                      if (member.address != null &&
                          member.address!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          member.address!,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 프로필 사진 or 이니셜 아바타
  Widget _buildAvatar(Color avatarBg, Color avatarFg) {
    // 갤러리 사진은 data URI — NetworkImage 로는 안 그려진다.
    final img = avatarImage(member.photoUrl);
    if (img != null) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: img,
        onBackgroundImageError: (_, __) {},
        backgroundColor: avatarBg,
        child: null,
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: avatarBg,
      child: Text(
        member.name.isNotEmpty ? member.name[0] : '?',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: avatarFg,
        ),
      ),
    );
  }
}

// ── 게스트 배지 ──
class _GuestBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        '게스트',
        style: TextStyle(
          color: AppColors.warning,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════
//  가입 신청 목록 시트 (총무/관리자 전용)
// ════════════════════════════════════════
class _JoinRequestSheet extends StatefulWidget {
  final ClubProvider provider;
  const _JoinRequestSheet({required this.provider});

  @override
  State<_JoinRequestSheet> createState() => _JoinRequestSheetState();
}

class _JoinRequestSheetState extends State<_JoinRequestSheet> {
  @override
  Widget build(BuildContext context) {
    final pending = widget.provider.pendingRequestsOf(
        widget.provider.selectedClub.id);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          // 핸들
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // 타이틀
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                const Text('가입 신청 목록',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${pending.length}건',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.danger,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 목록
          Expanded(
            child: pending.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.how_to_reg,
                            size: 48,
                            color: AppColors.textSecondary),
                        SizedBox(height: 12),
                        Text('대기 중인 가입 신청이 없습니다',
                            style: TextStyle(
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  )
                : ListView.separated(
                    controller: ctrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: pending.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => _JoinRequestCard(
                      request: pending[i],
                      provider: widget.provider,
                      onApproved: () => setState(() {}),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────
//  가입 신청 카드 (승인/거절 + 정회원/게스트/직책 선택)
// ────────────────────────────────────────
class _JoinRequestCard extends StatefulWidget {
  final JoinRequest request;
  final ClubProvider provider;
  final VoidCallback onApproved;

  const _JoinRequestCard({
    required this.request,
    required this.provider,
    required this.onApproved,
  });

  @override
  State<_JoinRequestCard> createState() => _JoinRequestCardState();
}

class _JoinRequestCardState extends State<_JoinRequestCard> {
  String _memberType = ClubMemberRole.regular;
  final Set<String> _roles = {ClubMemberRole.regular};

  String get _roleEncoded => ClubMemberRole.encodeRoles(_roles);

  void _toggleApproveRole(String role, void Function(void Function()) setDlg) {
    setDlg(() {
      if (role == ClubMemberRole.regular) {
        _roles
          ..clear()
          ..add(ClubMemberRole.regular);
        return;
      }
      _roles.remove(ClubMemberRole.regular);
      if (_roles.contains(role)) {
        _roles.remove(role);
        if (_roles.isEmpty) _roles.add(ClubMemberRole.regular);
      } else {
        _roles.add(role);
      }
    });
  }

  void _approve(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          title: Text('${widget.request.userName}님 승인',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 회원 유형
              const Text('회원 유형',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Row(
                children: [ClubMemberRole.regular, ClubMemberRole.guest]
                    .map((type) {
                  final selected = _memberType == type;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setDlg(() {
                        _memberType = type;
                        if (type == ClubMemberRole.guest) {
                          _roles
                            ..clear()
                            ..add(ClubMemberRole.regular);
                        }
                      }),
                      child: Container(
                        margin: EdgeInsets.only(
                            right: type == ClubMemberRole.regular ? 8 : 0),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Center(
                          child: Text(type,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textPrimary)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_memberType != ClubMemberRole.guest) ...[
                const SizedBox(height: 16),
                const Text('직책 지정 (복수 선택 가능)',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ClubMemberRole.president,
                    ClubMemberRole.vicePresident,
                    ClubMemberRole.treasurer,
                    ClubMemberRole.regular,
                  ].map((r) {
                    final selected = _roles.contains(r) ||
                        (r == ClubMemberRole.regular &&
                            !ClubMemberRole.isOfficer(_roleEncoded));
                    return FilterChip(
                      label: Text(r == ClubMemberRole.regular
                          ? '일반 회원'
                          : r),
                      selected: selected,
                      onSelected: (_) =>
                          _toggleApproveRole(r, setDlg),
                      selectedColor:
                          AppColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _memberType == ClubMemberRole.guest
                      ? '승인 시 게스트로 권한이 설정됩니다.'
                      : '승인 시 $_roleEncoded 직책으로 권한이 설정됩니다.',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.primary),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소',
                  style:
                      TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final role = ClubMemberRole.roleForMemberType(
                    _memberType, _roleEncoded);
                widget.provider.approveRequest(
                  widget.request.id,
                  memberType:
                      ClubMemberRole.memberTypeForRole(role),
                  role: role,
                );
                Navigator.pop(context);
                widget.onApproved();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '${widget.request.userName}님이 $_memberType으로 승인되었습니다'),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('승인'),
            ),
          ],
        ),
      ),
    );
  }

  void _reject(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('가입 거절',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
            '${widget.request.userName}님의 가입 신청을 거절하시겠습니까?',
            style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.provider.rejectRequest(widget.request.id);
              Navigator.pop(context);
              widget.onApproved();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '${widget.request.userName}님의 신청을 거절했습니다'),
                  backgroundColor: AppColors.danger,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('거절'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final timeAgo = DateTime.now().difference(req.requestedAt);
    final timeText = timeAgo.inMinutes < 60
        ? '${timeAgo.inMinutes}분 전'
        : timeAgo.inHours < 24
            ? '${timeAgo.inHours}시간 전'
            : '${timeAgo.inDays}일 전';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 아바타
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    req.userName.isNotEmpty
                        ? req.userName[0]
                        : '?',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(req.userName,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        const SizedBox(width: 6),
                        Text(req.userGender,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '핸디 ${req.userHandicap?.toStringAsFixed(0) ?? "-"}  ·  $timeText',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // 대기 배지
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('승인 대기',
                    style: TextStyle(
                        fontSize: 10,
                        color: AppColors.warning,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (req.message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${req.message}"',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _reject(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(
                        color: AppColors.danger.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('거절',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => _approve(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                  ),
                  child: const Text('승인 (유형·직책 선택)',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════
// 포인트 기준 안내 행
// ════════════════════════════════════════
class _PointGuideRow extends StatelessWidget {
  final String label;
  final String pts;
  final bool negative;
  const _PointGuideRow({
    required this.label,
    required this.pts,
    this.negative = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
          Text(
            pts,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: negative ? AppColors.danger : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

/// 총무 인수인계 진입 — 모든 회원에게 노출, 권한 없으면 안내
class _TreasurerTransferEntry extends StatelessWidget {
  final bool canAccess;
  const _TreasurerTransferEntry({required this.canAccess});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (!canAccess) {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text('접근 제한',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  content: const Text(
                    '총무만 접근할 수 있는 메뉴입니다.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('확인'),
                    ),
                  ],
                ),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TreasurerTransferScreen(),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.swap_horiz_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '총무 인수인계',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '총무 권한을 다른 회원에게 이전합니다',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: canAccess
                      ? AppColors.textSecondary
                      : AppColors.textSecondary.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
