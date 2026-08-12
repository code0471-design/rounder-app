import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/club_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/rounder_logo.dart';
import '../../widgets/app_header.dart';
import '../../models/club_model.dart';
import '../../features/clubs/presentation/club_list_navigation.dart';
import '../clubs/create_club_screen.dart';
import '../club_room/club_room_screen.dart';
import '../ad/ad_recommend_screen.dart';
import '../ad/ad_screen.dart';
import '../sponsor/sponsor_recommend_screen.dart';
import '../sponsor/sponsor_screen.dart';
import '../sponsor/thank_you_feed_screen.dart';

// ════════════════════════════════════════════════════════════
//  HomeScreen — 젠스파크 리디자인 v2
//  Cream / Sage / Amber / Rose 팔레트
// ════════════════════════════════════════════════════════════
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ClubProvider, AuthProvider>(
      builder: (context, clubProvider, authProvider, _) {
        final myClubs = clubProvider.myClubs;
        final userName = authProvider.currentUser?.name ?? '골퍼';

        return Scaffold(
          backgroundColor: AppColors.sandSoft,
          body: CustomScrollView(
            slivers: [
              // ── 세이지 헤더 ──
              SliverToBoxAdapter(child: _buildHeader(context, clubProvider, userName)),

              // ── 바디: 크림 배경으로 전환 ──
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.sandSoft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 퀵 액션 (1:1 정사각형 2칸)
                      _buildQuickActions(context),
                      const SizedBox(height: 16),
                      // AI 추천 섹션 (광고/후원 — 숨김)
                      // _buildAiSection(context),
                      // const SizedBox(height: 16),
                      // 후원/광고 배너 (숨김)
                      // _buildSponsorBanner(context, clubProvider, myClubs),
                      // const SizedBox(height: 20),
                      // 내 모임 섹션 헤더
                      _buildMyGroupsHeader(myClubs.length),
                      const SizedBox(height: 10),
                      // 내 모임 카드 목록
                      if (myClubs.isEmpty)
                        _buildEmptyState(context)
                      else
                        ...myClubs.map((club) => _GroupCard(
                              club: club,
                              onTap: () {
                                clubProvider.selectClubById(club.id);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => ClubRoomScreen(club: club)),
                                );
                              },
                            )),
                      const SizedBox(height: 40),
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

  // ────────────────────────────────────────
  //  헤더 — sage 그라디언트 + 흰 ROUNDER 필 + 환영 문구
  // ────────────────────────────────────────
  Widget _buildHeader(BuildContext context, ClubProvider provider, String userName) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.sageDeep, AppColors.sageDarker],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 바 (브랜드 + 알림/프로필)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 0),
              child: Row(
                children: [
                  // 좌측 여백
                  const SizedBox(width: 4),
                  const RounderLogo(height: 40),
                  const Spacer(),
                  // 알림
                  Consumer<ClubProvider>(
                    builder: (_, prov, __) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined,
                              color: Colors.white, size: 22),
                          onPressed: () => _showNotifications(context, prov),
                        ),
                        if (prov.unreadNotificationCount > 0)
                          Positioned(
                            right: 6, top: 6,
                            child: Container(
                              width: 16, height: 16,
                              decoration: BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.sageDeep, width: 1.5),
                              ),
                              child: Center(
                                child: Text(
                                  '${prov.unreadNotificationCount}',
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // 프로필 → 마이페이지
                  GestureDetector(
                    onTap: () => AppHeader.openMyPage(context),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            // 환영 문구 (한 줄)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 4, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '안녕하세요, $userName님  👋',
                    style: TextStyle(
                      fontSize: 13, color: Colors.white.withValues(alpha: 0.75),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '오늘도 즐거운 라운딩 되세요! ⛳',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontFamily: 'NanumGothic',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────
  //  퀵 액션 — 정사각형 2칸 (모임찾기 / 만들기)
  // ────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          // 모임 찾기 (연한 sage 배경)
          Expanded(
            child: _QuickCard(
              icon: Icons.travel_explore,
              label: '모임 찾기',
              sub: '지역·업종별 검색',
              bgColor: const Color(0xFFDFE5D4),
              iconColor: AppColors.sageDarker,
              labelColor: AppColors.sageDarker,
              subColor: AppColors.sageDarker.withValues(alpha: 0.7),
              onTap: () => openClubListDashboard(context),
            ),
          ),
          const SizedBox(width: 10),
          // 모임 만들기 (진한 sage 배경)
          Expanded(
            child: _QuickCard(
              icon: Icons.add_circle_outline,
              label: '모임 만들기',
              sub: '새 골프 모임 개설',
              bgColor: AppColors.sage,
              iconColor: Colors.white,
              labelColor: Colors.white,
              subColor: Colors.white.withValues(alpha: 0.75),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CreateClubScreen())),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────
  //  AI 추천 섹션 — cream-2 배경, 2칸 서브 카드
  // ────────────────────────────────────────
  Widget _buildAiSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cream2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.sage,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('AI',
                        style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w800,
                            color: Colors.white, letterSpacing: 0.15 * 9)),
                  ),
                  const SizedBox(width: 8),
                  const Text('비즈니스 AI 추천',
                      style: TextStyle(
                          fontFamily: 'NanumGothic', fontSize: 13,
                          fontWeight: FontWeight.w700, color: AppColors.sageDeep,
                          letterSpacing: -0.01 * 13)),
                  const Spacer(),
                  Text('업체 → 최적 모임 추천',
                      style: TextStyle(fontSize: 9, color: AppColors.inkSoft.withValues(alpha: 0.55))),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.black.withValues(alpha: 0.12)),
            const SizedBox(height: 12),
            // 2칸 서브 카드
            Row(
              children: [
                Expanded(child: _AiSubCard(
                  icon: Icons.ads_click,
                  pill: 'AD',
                  pillColor: AppColors.sageDeep,
                  pillBg: AppColors.sageDeep.withValues(alpha: 0.12),
                  title: '광고 AI 추천',
                  sub: '노출 효과 높은 모임',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AdRecommendScreen())),
                )),
                const SizedBox(width: 8),
                Expanded(child: _AiSubCard(
                  icon: Icons.volunteer_activism,
                  pill: '후원',
                  pillColor: AppColors.mauve,
                  pillBg: AppColors.mauve.withValues(alpha: 0.2),
                  title: '후원 AI 추천',
                  sub: 'ROI 높은 후원 모임',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SponsorRecommendScreen())),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────
  //  후원/광고 배너 (딥 퍼플 그라디언트)
  // ────────────────────────────────────────
  Widget _buildSponsorBanner(BuildContext context, ClubProvider provider, List<Club> clubs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          if (clubs.isNotEmpty) {
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => SponsorApplicationScreen(club: clubs.first)));
          } else {
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => const ThankYouFeedScreen()));
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4A4064), Color(0xFF322A4A)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              // 아이콘
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.volunteer_activism, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('SPONSOR',
                          style: TextStyle(fontSize: 8, letterSpacing: 0.2 * 8,
                              color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 3),
                    const Text('골프 모임 후원으로\n브랜드를 알리세요',
                        style: TextStyle(
                            fontFamily: 'NanumGothic', fontSize: 13,
                            fontWeight: FontWeight.w800, color: Colors.white,
                            height: 1.15, letterSpacing: -0.02 * 13)),
                    const SizedBox(height: 4),
                    Text('지역 골퍼들에게 자연스러운 노출 효과',
                        style: TextStyle(
                            fontSize: 9.5, color: Colors.white.withValues(alpha: 0.8),
                            height: 1.4)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: const Text('신청하기',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────
  //  내 모임 섹션 헤더
  // ────────────────────────────────────────
  Widget _buildMyGroupsHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        children: [
          const Text('내 모임',
              style: TextStyle(
                  fontFamily: 'NanumGothic', fontSize: 15,
                  fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(width: 6),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.cream2,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$count',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppColors.sageDeep, letterSpacing: 0.05 * 10)),
            ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────
  //  빈 상태
  // ────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.sports_golf, size: 48, color: AppColors.inkSoft.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            const Text('아직 참여 중인 모임이 없어요',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 15, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            const Text('모임을 만들거나 가입 신청해 보세요!',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CreateClubScreen())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.sageDeep,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('모임 만들기',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context, ClubProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => _NotificationSheet(
        provider: provider,
        onNavigate: (n) {
          Navigator.pop(sheetCtx);
          _navigateToNotification(context, n, provider);
        },
      ),
    );
  }

  void _navigateToNotification(BuildContext context, AppNotification n, ClubProvider provider) {
    provider.selectClubById(n.clubId);
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ClubRoomScreen(club: provider.selectedClub)));
  }
}

// ════════════════════════════════════════
//  알림 시트 — addListener 방식으로 직접 listen
//  (showModalBottomSheet는 별도 route라 Provider.of가 작동 안 함)
// ════════════════════════════════════════
class _NotificationSheet extends StatefulWidget {
  final ClubProvider provider;
  final void Function(AppNotification) onNavigate;
  const _NotificationSheet({required this.provider, required this.onNavigate});

  @override
  State<_NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<_NotificationSheet> {
  @override
  void initState() {
    super.initState();
    // provider 변경시 setState 직접 호출 — Provider 트리 우회
    widget.provider.addListener(_onProviderChanged);
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onProviderChanged);
    super.dispose();
  }

  void _onProviderChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final prov   = widget.provider;
    final notifs = prov.visibleNotifications;
    final unread = prov.visibleUnreadNotificationCount;
    final hasRead = notifs.any((n) => n.isRead);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.88,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
            child: Row(children: [
              const Icon(Icons.notifications, color: AppColors.sageDeep, size: 20),
              const SizedBox(width: 8),
              const Text('알림',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('$unread',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              const Spacer(),
              // 모두 읽음 버튼
              if (unread > 0)
                TextButton(
                  onPressed: prov.markAllNotificationsRead,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.sageDeep,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('모두 읽음', style: TextStyle(fontSize: 12)),
                ),
              // 읽은 알림 삭제 버튼
              if (hasRead)
                TextButton(
                  onPressed: () => _confirmDeleteRead(context, prov),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('읽은 거 삭제', style: TextStyle(fontSize: 12)),
                ),
            ]),
          ),
          const Divider(height: 1),
          // 힌트 텍스트
          if (notifs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(children: [
                Icon(Icons.swipe_left_outlined, size: 13,
                    color: AppColors.inkSoft.withValues(alpha: 0.4)),
                const SizedBox(width: 4),
                Text('좌로 밀면 삭제',
                    style: TextStyle(fontSize: 11, color: AppColors.inkSoft.withValues(alpha: 0.5))),
              ]),
            ),
          // 목록
          Expanded(
            child: notifs.isEmpty
                ? Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Icon(Icons.notifications_none,
                          size: 48,
                          color: AppColors.inkSoft.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      const Text('알림이 없습니다',
                          style: TextStyle(color: AppColors.inkSoft)),
                    ]))
                : ListView.separated(
                    controller: ctrl,
                    itemCount: notifs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (_, i) {
                      final n = notifs[i];
                      return Dismissible(
                        key: ValueKey(n.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: AppColors.danger,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete_outline,
                              color: Colors.white, size: 22),
                        ),
                        onDismissed: (_) {
                          prov.removeNotification(n.id);
                        },
                        child: _NotificationTile(
                          notification: n,
                          onTap: () {
                            prov.markNotificationRead(n.id);
                            widget.onNavigate(n);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRead(BuildContext context, ClubProvider prov) {
    final readCount = prov.appNotifications.where((n) => n.isRead).length;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('읽은 알림 삭제'),
        content: Text('읽은 알림 $readCount개를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              prov.deleteReadNotifications();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════
//  알림 타일
// ════════════════════════════════════════
class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final isUnread = !n.isRead;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isUnread ? AppColors.sageLighter.withValues(alpha: 0.35) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 아이콘
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _iconBg(n.type),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconData(n.type), size: 18, color: _iconColor(n.type)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: n.isAdmin
                            ? AppColors.accent.withValues(alpha: 0.12)
                            : AppColors.sageDeep.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(n.clubName,
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: n.isAdmin ? AppColors.accent : AppColors.sageDeep,
                          )),
                    ),
                    if (n.isAdmin) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('관리자',
                            style: TextStyle(fontSize: 9, color: AppColors.accent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    const Spacer(),
                    Text(_timeAgo(n.createdAt),
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    if (isUnread) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(n.title,
                      style: TextStyle(
                        fontSize: 13, fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                        color: AppColors.textPrimary,
                      )),
                  const SizedBox(height: 2),
                  Text(n.body,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconData(AppNotificationType t) {
    switch (t) {
      case AppNotificationType.joinRequest:  return Icons.person_add_outlined;
      case AppNotificationType.joinApproved: return Icons.check_circle_outline;
      case AppNotificationType.announcement: return Icons.campaign_outlined;
      case AppNotificationType.comment:      return Icons.chat_bubble_outline;
      case AppNotificationType.schedule:     return Icons.event_outlined;
      case AppNotificationType.paymentRequest: return Icons.payments_outlined;
      case AppNotificationType.attendanceChanged: return Icons.how_to_reg_outlined;
      case AppNotificationType.memberKicked: return Icons.block_outlined;
      case AppNotificationType.scheduleChanged: return Icons.edit_calendar_outlined;
      case AppNotificationType.scheduleCancelled: return Icons.event_busy_outlined;
    }
  }

  Color _iconBg(AppNotificationType t) {
    switch (t) {
      case AppNotificationType.joinRequest:  return AppColors.accent.withValues(alpha: 0.12);
      case AppNotificationType.joinApproved: return AppColors.success.withValues(alpha: 0.12);
      case AppNotificationType.announcement: return AppColors.sageDeep.withValues(alpha: 0.12);
      case AppNotificationType.comment:      return AppColors.warning.withValues(alpha: 0.12);
      case AppNotificationType.schedule:     return Colors.blueAccent.withValues(alpha: 0.12);
      case AppNotificationType.paymentRequest: return AppColors.warning.withValues(alpha: 0.12);
      case AppNotificationType.attendanceChanged: return AppColors.accent.withValues(alpha: 0.12);
      case AppNotificationType.memberKicked: return AppColors.danger.withValues(alpha: 0.12);
      case AppNotificationType.scheduleChanged: return Colors.blueAccent.withValues(alpha: 0.12);
      case AppNotificationType.scheduleCancelled: return AppColors.danger.withValues(alpha: 0.12);
    }
  }

  Color _iconColor(AppNotificationType t) {
    switch (t) {
      case AppNotificationType.joinRequest:  return AppColors.accent;
      case AppNotificationType.joinApproved: return AppColors.success;
      case AppNotificationType.announcement: return AppColors.sageDeep;
      case AppNotificationType.comment:      return AppColors.warning;
      case AppNotificationType.schedule:     return Colors.blueAccent;
      case AppNotificationType.paymentRequest: return AppColors.warning;
      case AppNotificationType.attendanceChanged: return AppColors.accent;
      case AppNotificationType.memberKicked: return AppColors.danger;
      case AppNotificationType.scheduleChanged: return Colors.blueAccent;
      case AppNotificationType.scheduleCancelled: return AppColors.danger;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24)   return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

// ════════════════════════════════════════
//  퀵 카드 위젯 (정사각형 1:1)
// ════════════════════════════════════════
class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color bgColor;
  final Color iconColor;
  final Color labelColor;
  final Color subColor;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.label,
    required this.sub,
    required this.bgColor,
    required this.iconColor,
    required this.labelColor,
    required this.subColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.9,  // 이미지 참고: 낮고 넓은 카드
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 반투명 원형 아이콘 컨테이너
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      fontFamily: 'NanumGothic', fontSize: 17,
                      fontWeight: FontWeight.w800, color: labelColor,
                      height: 1.15, letterSpacing: -0.01 * 17)),
              const SizedBox(height: 4),
              Text(sub,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 10, color: subColor,
                      height: 1.45, letterSpacing: 0.02 * 10)),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════
//  AI 서브 카드 위젯
// ════════════════════════════════════════
class _AiSubCard extends StatelessWidget {
  final IconData icon;
  final String pill;
  final Color pillColor;
  final Color pillBg;
  final String title;
  final String sub;
  final VoidCallback onTap;

  const _AiSubCard({
    required this.icon,
    required this.pill,
    required this.pillColor,
    required this.pillBg,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: pillColor),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: pillBg, borderRadius: BorderRadius.circular(20)),
                  child: Text(pill,
                      style: TextStyle(
                          fontSize: 8, fontWeight: FontWeight.w800,
                          color: pillColor, letterSpacing: 0.08 * 8)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(title,
                style: const TextStyle(
                    fontFamily: 'NanumGothic', fontSize: 12,
                    fontWeight: FontWeight.w700, color: AppColors.sageDeep,
                    letterSpacing: -0.03 * 12)),
            const SizedBox(height: 2),
            Text(sub,
                style: TextStyle(
                    fontSize: 10, color: AppColors.inkSoft.withValues(alpha: 0.6),
                    height: 1.4, letterSpacing: 0.02 * 10)),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════
//  내 모임 그룹 카드 (group-card 스타일)
// ════════════════════════════════════════
class _GroupCard extends StatelessWidget {
  final Club club;
  final VoidCallback onTap;
  const _GroupCard({required this.club, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // D-day
    final days = club.daysUntilNextRound;
    final dDayText = days < 0 ? '일정 없음' : days == 0 ? 'D-Day!' : 'D-$days';
    final dDayClose = days >= 0 && days <= 7;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          // 메인 카드 (탭 → 모임 방 진입)
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // 썸네일 (업종 이모지)
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.sandSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(clubIndustryEmoji(club.industry),
                              style: const TextStyle(fontSize: 20)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 이름
                        Text(club.name,
                            style: const TextStyle(
                                fontFamily: 'NanumGothic', fontSize: 17,
                                fontWeight: FontWeight.w400,
                                color: AppColors.ink, height: 1.15)),
                        // 지역·업종·인원
                        const SizedBox(height: 2),
                        Text('${club.region} · ${club.industry} · ${club.memberCount}명',
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.inkSoft,
                                letterSpacing: 0.02 * 10)),
                        // 다음 라운딩
                        if (club.nextRoundCourse != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.sports_golf, size: 11, color: AppColors.inkSoft),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(club.nextRoundCourse!,
                                    style: const TextStyle(
                                        fontSize: 10, color: AppColors.inkSoft),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 우측: 직책 배지 + D-day 배지
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _RoleBadge(role: club.myRole),
                      const SizedBox(height: 6),
                      if (days >= 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: dDayClose ? AppColors.sageDeep : AppColors.sage,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(dDayText,
                              style: const TextStyle(
                                  fontSize: 9, fontWeight: FontWeight.w700,
                                  color: Colors.white, letterSpacing: 0.06 * 9)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 하단 CTA (광고/후원 신청 — 숨김)
          // Container(
          //   decoration: BoxDecoration(
          //     border: Border(
          //         top: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
          //     borderRadius: const BorderRadius.only(
          //       bottomLeft: Radius.circular(20),
          //       bottomRight: Radius.circular(20),
          //     ),
          //   ),
          //   child: Row(
          //     children: [
          //       // 광고 신청하기
          //       Expanded(
          //         child: InkWell(
          //           onTap: () => Navigator.push(context,
          //               MaterialPageRoute(builder: (_) => AdApplicationScreen(club: club))),
          //           borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20)),
          //           child: Padding(
          //             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          //             child: Row(
          //               mainAxisAlignment: MainAxisAlignment.center,
          //               children: [
          //                 Container(
          //                   padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          //                   decoration: BoxDecoration(
          //                     gradient: const LinearGradient(
          //                       colors: [Color(0xFFFF6D00), Color(0xFFFFAB40)],
          //                     ),
          //                     borderRadius: BorderRadius.circular(4),
          //                   ),
          //                   child: const Text('AD',
          //                       style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
          //                 ),
          //                 const SizedBox(width: 5),
          //                 const Text('광고 신청하기',
          //                     style: TextStyle(fontSize: 10, color: AppColors.inkSoft,
          //                         letterSpacing: 0.05 * 10)),
          //                 const SizedBox(width: 2),
          //                 const Icon(Icons.arrow_forward_ios, size: 9, color: AppColors.inkSoft),
          //               ],
          //             ),
          //           ),
          //         ),
          //       ),
          //       Container(width: 1, height: 30, color: Colors.black.withValues(alpha: 0.06)),
          //       // 후원하기
          //       Expanded(
          //         child: InkWell(
          //           onTap: () => Navigator.push(context,
          //               MaterialPageRoute(builder: (_) => SponsorApplicationScreen(club: club))),
          //           borderRadius: const BorderRadius.only(bottomRight: Radius.circular(20)),
          //           child: Padding(
          //             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          //             child: Row(
          //               mainAxisAlignment: MainAxisAlignment.center,
          //               children: [
          //                 Container(
          //                   padding: const EdgeInsets.all(3),
          //                   decoration: BoxDecoration(
          //                     gradient: const LinearGradient(
          //                       colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          //                     ),
          //                     borderRadius: BorderRadius.circular(4),
          //                   ),
          //                   child: const Icon(Icons.volunteer_activism, size: 8, color: Colors.white),
          //                 ),
          //                 const SizedBox(width: 5),
          //                 const Text('후원하기',
          //                     style: TextStyle(fontSize: 10, color: Color(0xFF4F46E5),
          //                         letterSpacing: 0.05 * 10)),
          //                 const SizedBox(width: 2),
          //                 const Icon(Icons.arrow_forward_ios, size: 9, color: Color(0xFF4F46E5)),
          //               ],
          //             ),
          //           ),
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }
}

// ── 직책 배지 ──
class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  Color get _bg {
    switch (role) {
      case '회장':   return AppColors.amberSoft;
      case '부회장': return const Color(0xFFDBE6EC);
      case '총무':   return const Color(0xFFFFE4CC);
      case '정회원': return const Color(0xFFDBE6EC);
      case '게스트': return AppColors.roseSoft;
      default:       return AppColors.cream2;
    }
  }
  Color get _fg {
    switch (role) {
      case '회장':   return const Color(0xFF6B5426);
      case '부회장': return const Color(0xFF395A6B);
      case '총무':   return const Color(0xFF8B5E2A);
      case '정회원': return const Color(0xFF395A6B);
      case '게스트': return const Color(0xFF8F5555);
      default:       return AppColors.inkSoft;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(20)),
      child: Text(role,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
              color: _fg, letterSpacing: 0.1 * 9)),
    );
  }
}
