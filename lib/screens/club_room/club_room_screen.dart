import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/club_model.dart';
import '../../models/member_role.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/d_day_utils.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_header.dart';
import '../invite/invite_send_screen.dart';
import '../invite/guest_invite_form_screen.dart';
import '../schedule/schedule_screen.dart';
import '../members/members_screen.dart';
import '../finance/finance_screen.dart';
import '../records/records_screen.dart';
import '../gallery/gallery_screen.dart';
import '../ad/ad_screen.dart';
import '../sponsor/sponsor_screen.dart';
import '../sponsor/thank_you_feed_screen.dart';
import '../clubs/club_settings_screen.dart';
import '../members/treasurer_transfer_screen.dart';
import '../alimtalk/alimtalk_settings_screen.dart';
import '../group_assignment/group_assignment_screen.dart';

// ── 초대 버튼 (정회원/게스트 공용 칩 버튼) ──
class _InviteChipButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;
  final VoidCallback onTap;

  const _InviteChipButton({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textColor)),
          ],
        ),
      ),
    );
  }
}

/// 금액 포맷 헬퍼 (천 단위 콤마)
String _fmtAmount(int amount) {
  final s = amount.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

// ════════════════════════════════════════════════════════════
//  ClubRoomScreen — 모임 방
//  · 상단: 고정 헤더 (ROUNDER 로고 탭 → 첫 화면으로 복귀)
//  · 하단: 탭 (홈/일정/회원/재무/기록)
// ════════════════════════════════════════════════════════════
class ClubRoomScreen extends StatefulWidget {
  final Club club;
  /// 하단 탭: 0홈 1일정 2갤러리 3회원 4재무
  final int initialTab;
  /// 일정 상세(또는 조편성)로 바로 열 일정 id
  final String? openScheduleId;
  /// true면 일정 상세 대신 조편성 화면
  final bool openGroupAssignment;
  /// id 없을 때 다가오는 일정 상세/조편성으로 진입 (알림톡 딥링크용)
  final bool openNearestSchedule;

  const ClubRoomScreen({
    super.key,
    required this.club,
    this.initialTab = 0,
    this.openScheduleId,
    this.openGroupAssignment = false,
    this.openNearestSchedule = false,
  });

  @override
  State<ClubRoomScreen> createState() => _ClubRoomScreenState();
}

class _ClubRoomScreenState extends State<ClubRoomScreen> {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    final startTab = widget.initialTab;
    if (startTab >= 0 && startTab < 5) {
      _tabIndex = startTab;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final p = context.read<ClubProvider>();
      p.selectClubById(widget.club.id);
      if (p.ensureCreatorMembers()) p.notifyListeners();
      // 직책 수정/인수인계 후 Club.myRole 불일치 복구
      p.syncMyRoleFromMemberRoster();
      // 다른 계정 가입신청 → 총무 알림 동기화
      await p.refreshJoinRequestInbox();
      if (!mounted) return;
      // 재무 탭이 막혀 있으면 홈으로
      if (_tabIndex == _financeTabIndex && !_canOpenFinanceTab()) {
        setState(() => _tabIndex = 0);
      }
      await _openDeepLinkTarget(p);
    });
  }

  Future<void> _openDeepLinkTarget(ClubProvider provider) async {
    final scheduleId = widget.openScheduleId?.trim() ?? '';
    final shouldOpen = scheduleId.isNotEmpty ||
        widget.openGroupAssignment ||
        widget.openNearestSchedule;
    if (!shouldOpen) return;

    // 탭 Navigator가 붙은 뒤 push
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    openTab(scheduleTabIndex);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    final nav = _navigatorKeys[scheduleTabIndex].currentState;
    if (nav == null) return;

    RoundSchedule? schedule;
    if (scheduleId.isNotEmpty) {
      schedule = provider.scheduleById(scheduleId);
    }
    // id 없으면 다가오는 일정 하나
    schedule ??= provider.upcomingSchedules.isNotEmpty
        ? provider.upcomingSchedules.first
        : null;
    if (schedule == null) return;

    if (widget.openGroupAssignment) {
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) => GroupAssignmentScreen(schedule: schedule!),
        ),
      );
      return;
    }

    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => ScheduleDetailScreen(schedule: schedule!),
      ),
    );
  }

  static const int scheduleTabIndex = 1;

  // ── 탭별 독립 Navigator 키 (5개) ──
  // 각 탭이 자체 Navigator 스택을 가져 하위 페이지 push/pop이 탭 안에서만 일어남
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    5,
    (_) => GlobalKey<NavigatorState>(),
  );

  final List<_TabItem> _tabs = const [
    _TabItem(label: '홈',   icon: Icons.home_outlined,                  activeIcon: Icons.home),
    _TabItem(label: '일정', icon: Icons.calendar_month_outlined,         activeIcon: Icons.calendar_month),
    _TabItem(label: '갤러리', icon: Icons.photo_library_outlined,        activeIcon: Icons.photo_library),
    _TabItem(label: '회원', icon: Icons.group_outlined,                  activeIcon: Icons.group),
    _TabItem(label: '재무', icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet),
  ];

  // ── 탭별 루트 화면 (Navigator로 감쌀 초기 화면) ──
  static const List<Widget> _rootScreens = [
    ClubHomeTab(),
    ScheduleScreen(),
    GalleryScreen(),
    MembersScreen(),
    FinanceScreen(),
  ];

  // ── 탭 Navigator 빌더 ──
  // 각 탭을 독립 Navigator로 감싸 탭 내부 push/pop이 탭바를 가리지 않게 함
  Widget _buildTabNavigator(int index) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => _rootScreens[index],
      ),
    );
  }

  // ── 현재 탭의 Navigator가 pop 가능한지 확인 ──
  bool get _canPopCurrentTab =>
      _navigatorKeys[_tabIndex].currentState?.canPop() ?? false;

  // 재무 탭 인덱스 (하단 탭바 4번째 항목)
  static const int _financeTabIndex = 4;

  void openTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    if (index == _financeTabIndex && !_canOpenFinanceTab()) return;
    setState(() => _tabIndex = index);
  }

  /// 재무 탭 진입 가능 여부
  /// · 게스트 차단
  /// · Case A: 총무가 아니고 회비 미설정이면 차단 (방장·정회원 포함)
  bool _canOpenFinanceTab() {
    final provider = context.read<ClubProvider>();
    if (provider.isGuestMember) {
      _showGuestRestrictedDialog();
      return false;
    }
    if (!provider.isTreasurer && provider.isFinanceSetupPending) {
      _showFinanceSetupPendingDialog();
      return false;
    }
    return true;
  }

  /// 게스트 회원의 재무 탭 접근을 차단하고 안내 팝업을 띄운다.
  void _showGuestRestrictedDialog() {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.danger, size: 20),
            SizedBox(width: 8),
            Text('접근 제한',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text('게스트 회원은 권한이 없습니다.',
            style: TextStyle(fontSize: 14, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
            child: const Text('확인',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showFinanceSetupPendingDialog() {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.hourglass_empty_rounded,
                color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text('회비 설정 전',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          '아직 회비 설정 전입니다. 총무가 최초 설정한 후 조회 가능합니다',
          style: TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
            child: const Text('확인',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _onClubSettingsTap(BuildContext context, ClubProvider provider) {
    final isAdmin = provider.isClubExecutive;
    final canEdit = provider.canEditClubInfo;

    if (!canEdit && !isAdmin) {
      showDialog(
        context: context,
        useRootNavigator: true,
        builder: (dialogCtx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline, color: AppColors.danger, size: 20),
              SizedBox(width: 8),
              Text('권한 없음',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: const Text('관리자만 모임 설정을 변경할 수 있습니다.',
              style: TextStyle(fontSize: 14, height: 1.6)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
              child: const Text('확인',
                  style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('모임 설정',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
              if (canEdit)
                ListTile(
                  leading: const Icon(Icons.edit_outlined,
                      color: AppColors.primary),
                  title: const Text('모임 정보 수정',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('이름 · 소개 · 이미지 · 팀 수',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.textTertiary),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    // 저장 후 pop → 설정 버튼 누르기 전(모임 방)으로 복귀
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ClubSettingsScreen()),
                    );
                  },
                ),
              if (isAdmin)
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline,
                      color: AppColors.sageDeep),
                  title: const Text('알림톡 설정',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('일정 · 조편성 · 일정 변경 발송 ON/OFF',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.textTertiary),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const AlimtalkSettingsScreen()),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 시스템 뒤로가기 처리:
      //   1. 탭 내 하위 화면이 있으면 → 해당 탭 Navigator pop
      //   2. 홈 탭이 아니면 → 홈 탭으로 이동
      //   3. 홈 탭 루트면 → 차단 (모임 방 탈출은 헤더 ← 버튼으로만)
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (_canPopCurrentTab) {
          _navigatorKeys[_tabIndex].currentState?.pop();
        } else if (_tabIndex != 0) {
          setState(() => _tabIndex = 0);
        }
        // 홈 탭 루트: 아무것도 안 함
      },
      child: Consumer<ClubProvider>(
        builder: (context, provider, _) {
          final club = provider.selectedClub;

          return Scaffold(
            backgroundColor: AppColors.background,
            body: Column(
              children: [
                // ── 고정 헤더 ──
                _buildHeader(context, provider, club),
                // ── 탭 컨텐츠 (IndexedStack으로 탭 상태 유지) ──
                Expanded(
                  child: IndexedStack(
                    index: _tabIndex,
                    children: List.generate(5, _buildTabNavigator),
                  ),
                ),
              ],
            ),
            // ── 하단 탭바 (항상 표시) ──
            bottomNavigationBar: _buildBottomNav(provider),
          );
        },
      ),
    );
  }

  // ────────────────────────────────────────
  // 고정 헤더
  // ────────────────────────────────────────
  Widget _buildHeader(
      BuildContext context, ClubProvider provider, Club club) {
    final unread = provider.unreadNotificationCountFor(club.id);

    void handleBack() {
      if (_canPopCurrentTab) {
        _navigatorKeys[_tabIndex].currentState?.pop();
      } else if (_tabIndex != 0) {
        setState(() => _tabIndex = 0);
      } else {
        Navigator.pop(context);
      }
    }

    return AppHeader(
      leading: GestureDetector(
        onTap: handleBack,
        behavior: HitTestBehavior.opaque,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.primary,
            size: 18,
          ),
        ),
      ),
      onLogoTap: () => Navigator.pop(context),
      trailingActions: [
        AppHeader.compactIcon(
          onTap: () => _onClubSettingsTap(context, provider),
          icon: const Icon(
            Icons.settings_outlined,
            color: AppColors.primary,
            size: 22,
          ),
        ),
      ],
      onNotificationTap: () => _showNotificationPanel(context, provider),
      onProfileTap: () => AppHeader.openMyPage(context),
      notificationCount: unread,
    );
  }

  // ────────────────────────────────────────
  // 하단 탭바
  // ────────────────────────────────────────
  Widget _buildBottomNav(ClubProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: const Border(
          top: BorderSide(color: AppColors.divider, width: 1),
        ),
        boxShadow: AppShadows.soft,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final selected = _tabIndex == i;
              return Expanded(
                  child: GestureDetector(
                  onTap: () {
                    if (i == _financeTabIndex && !_canOpenFinanceTab()) {
                      return;
                    }
                    setState(() => _tabIndex = i);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _navigatorKeys[i]
                          .currentState
                          ?.popUntil((route) => route.isFirst);
                    });
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        selected ? tab.activeIcon : tab.icon,
                        size: 24,
                        color: selected
                            ? AppColors.accent
                            : AppColors.textTertiary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? AppColors.accent
                              : AppColors.textTertiary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────
// 탭 아이템 정의
// ────────────────────────────────────────
class _TabItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _TabItem(
      {required this.label,
      required this.icon,
      required this.activeIcon});
}

// ════════════════════════════════════════
//  ClubHomeTab — 모임 방의 홈 탭 컨텐츠
//  (기존 HomeScreen 본문 내용 그대로)
// ════════════════════════════════════════
class ClubHomeTab extends StatelessWidget {
  const ClubHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final club = provider.selectedClub;
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async =>
              await Future.delayed(const Duration(seconds: 1)),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // 모임 이름 + 초대 버튼
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              club.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${club.region} · ${club.industry} · ${club.memberCount}명',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      // 회원 초대 버튼 — 정회원 초대 / 게스트 초대 분리
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _InviteChipButton(
                            label: '정회원 초대하기',
                            icon: Icons.badge_outlined,
                            bgColor: const Color(0xFFFEF08A),
                            borderColor: const Color(0xFFFACC15),
                            textColor: const Color(0xFF92400E),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InviteSendScreen(club: club),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          _InviteChipButton(
                            label: '게스트 초대하기',
                            icon: Icons.person_add_alt_1_outlined,
                            bgColor: AppColors.primary.withValues(alpha: 0.10),
                            borderColor: AppColors.primary.withValues(alpha: 0.35),
                            textColor: AppColors.primary,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GuestInviteFormScreen(club: club),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (provider.isSelectedTreasurerVacant &&
                    ['회장', '부회장'].contains(provider.selectedClub.myRole))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Material(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TreasurerTransferScreen(),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.warning_amber_rounded,
                                    color: Color(0xFFE65100), size: 22),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '총무 공석',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFE65100),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      '총무가 인수인계 없이 탈퇴했습니다. 탭하여 총무를 선임하세요.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFBF360C),
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  color: Color(0xFFE65100)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildNextRoundSection(context, provider),
                ),
                if (provider.upcomingSchedules.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _AttendanceCard(
                      provider: provider,
                      onTap: () {
                        final next = provider.nextUpcomingSchedule!;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ScheduleDetailScreen(schedule: next),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // 공식 후원사 섹션 (숨김)
                // _OfficialSponsorsSection(clubId: club.id, club: club),
                // const SizedBox(height: 12),
                // 회계 현황 (탭하면 회계 탭으로 이동)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _FinanceSummaryCard(
                    provider: provider,
                    onTap: () {
                      final room = context
                          .findAncestorStateOfType<_ClubRoomScreenState>();
                      if (room == null) return;
                      // 총무만 재무 탭 진입 — 그 외는 Case A 안내
                      room.openTab(4);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // 공지사항
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _AnnouncementSection(
                    announcements: provider.announcements,
                    isAdmin: provider.isClubExecutive,
                    provider: provider,
                  ),
                ),
                const SizedBox(height: 12),
                // ── 광고 배너 (숨김) ──
                // Padding(
                //   padding: const EdgeInsets.symmetric(horizontal: 16),
                //   child: AdBanner(
                //     type: AdBannerType.banner,
                //     adIndex: 1,
                //     clubId: club.id,
                //     slotType: AdSlotType.home,
                //   ),
                // ),
                // const SizedBox(height: 16),
                // 최근 활동
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ActivitySection(activities: provider.activities),
                ),
                const SizedBox(height: 12),
                // ── 제휴 광고 메뉴 (숨김) ──
                // Padding(
                //   padding: const EdgeInsets.symmetric(horizontal: 16),
                //   child: _AdMenuSection(club: club, provider: provider),
                // ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNextRoundSection(
      BuildContext context, ClubProvider provider) {
    final nextSchedule = provider.nextUpcomingSchedule;

    if (provider.upcomingSchedules.isEmpty) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.event_busy,
                      size: 22, color: Colors.grey.shade400),
                ),
                const SizedBox(width: 14),
                Text(
                  '예정된 모임이 없습니다',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          if (provider.canCreateSchedule)
            TextButton.icon(
              onPressed: () => openAddScheduleSheet(context, provider),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('일정 추가하기',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      );
    }

    final date = nextSchedule!.roundDate;
    final days = DDayUtils.daysFromToday(date);
    var title = nextSchedule.displayTitle.trim();
    if (title.isEmpty) title = '${date.month}월 정기 모임';
    if (title.length >= 2 &&
        ((title.startsWith('<') && title.endsWith('>')) ||
            (title.startsWith('〈') && title.endsWith('〉')))) {
      title = title.substring(1, title.length - 1).trim();
    }
    final place = nextSchedule.courseName.isNotEmpty
        ? nextSchedule.courseName
        : '장소 미정';

    final card = Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3B6FE0),
            Color(0xFF16368F),
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('다음 일정',
                  style: TextStyle(
                      color: Color(0xFFC5D4F5),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35), width: 0.8),
                ),
                child: const Text('자세히 보기',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$place · ${date.month}월 ${date.day}일',
                      style: const TextStyle(
                          color: Color(0xFFD4DCF0),
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                      color: const Color(0xFFE53935), width: 2.6),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      days == 0 ? 'D-day' : (days < 0 ? 'D+' : 'D-day'),
                      style: TextStyle(
                        color: const Color(0xFFE53935),
                        fontSize: days == 0 ? 13 : 11,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    if (days != 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        days > 0 ? '-${days.abs()}' : '+${days.abs()}',
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white.withValues(alpha: 0.15),
        highlightColor: Colors.white.withValues(alpha: 0.08),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ScheduleDetailScreen(schedule: nextSchedule),
          ),
        ),
        child: card,
      ),
    );
  }
}

// ── 출석 현황 카드 (실시간 응답 + 카운트) ──
class _AttendanceCard extends StatelessWidget {
  final ClubProvider provider;
  final VoidCallback? onTap;
  const _AttendanceCard({required this.provider, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, prov, _) {
        final nextSchedule = prov.nextUpcomingSchedule;

        if (nextSchedule == null) {
          return const SizedBox.shrink();
        }

        final memberIds = {for (final m in prov.activeMembers) m.id};
        final responses = nextSchedule.responses
            .where((r) => memberIds.contains(r.memberId))
            .toList();
        final guestIds = {for (final m in prov.guestMembers) m.id};
        final guestNames = {for (final m in prov.guestMembers) m.name};
        bool isGuest(AttendanceResponse r) =>
            guestIds.contains(r.memberId) || guestNames.contains(r.memberName);

        // 게스트: 미응답 → 미답변 제외. 참석 시에만 참석 집계에 포함.
        // 클럽 회원 id가 아닌 응답(옛 자동참석/ID불일치)은 제외.
        final confirmedList =
            responses.where((r) => r.response == '참석').toList();
        final confirmed = confirmedList.length;
        final guestAttend =
            confirmedList.where(isGuest).length;
        final declined = responses
            .where((r) => r.response == '불참' && !isGuest(r))
            .length;
        final respondedIds = {
          ...confirmedList
              .where((r) => !isGuest(r))
              .map((r) => r.memberId),
          ...responses
              .where((r) => r.response == '불참' && !isGuest(r))
              .map((r) => r.memberId),
        };
        final noResponse = prov.regularMembers
            .where((m) => !respondedIds.contains(m.id))
            .length;
        Widget mini(String status, String countLabel, Color fg) {
          return Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              ),
              child: Column(
                children: [
                  Text(status,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9CA3AF))),
                  const SizedBox(height: 6),
                  Text(countLabel,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          color: fg)),
                  if (status == '참석' && guestAttend > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '게스트 $guestAttend명 포함',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Text('참석 현황',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink)),
                    Spacer(),
                    Text('참석 응답 · 명단 보기 >',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    mini('참석', '$confirmed', const Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    mini('불참', '$declined', const Color(0xFFE53935)),
                    const SizedBox(width: 8),
                    mini('미답변', '$noResponse', const Color(0xFF6B7280)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MemberSection extends StatelessWidget {
  final String label;
  final Color color;
  final List<AttendanceResponse> members;
  const _MemberSection(this.label, this.color, this.members);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 6, height: 6,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
              const SizedBox(width: 4),
              Text('${members.length}명',
                  style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7))),
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 10, runSpacing: 7,
            children: members.map((m) {
              final initials = m.memberName.isNotEmpty ? m.memberName.substring(0, 1) : '?';
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Center(
                      child: Text(initials,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(m.memberName,
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── 공지사항 ──
class _AnnouncementSection extends StatelessWidget {
  final List<Announcement> announcements;
  final bool isAdmin;
  final ClubProvider provider;
  const _AnnouncementSection({
    required this.announcements,
    required this.isAdmin,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = announcements.isEmpty;
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 (제목 + 더보기 + 관리자용 작성 버튼) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.campaign_outlined,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('공지사항',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                ),
                if (announcements.isNotEmpty)
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => _AnnouncementListScreen(
                        announcements: announcements,
                        isAdmin: isAdmin,
                        provider: provider,
                      ),
                    )),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('전체보기',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const Icon(Icons.keyboard_arrow_right, size: 14,
                            color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                if (isAdmin)
                  TextButton.icon(
                    onPressed: () => _showWriteDialog(context),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('작성', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // ── 공지 없을 때 ──
          if (isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  isAdmin ? '공지사항을 작성해보세요' : '등록된 공지사항이 없습니다',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            )
          else ...[
            ...announcements.take(4).map((a) => _AnnouncementTile(
                  announcement: a,
                  isAdmin: isAdmin,
                  provider: provider,
                )),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── 공지사항 작성 다이얼로그 ──
  void _showWriteDialog(BuildContext context) {
    final titleCtrl   = TextEditingController();
    final contentCtrl = TextEditingController();
    bool pin = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setS) {
          final mq = MediaQuery.of(sheetCtx);
          final keyboard = mq.viewInsets.bottom;
          // 키보드가 올라와도 화면 밖으로 넘치지 않도록 높이 제한 + 스크롤
          final maxH = mq.size.height - keyboard - mq.padding.top - 24;
          return SafeArea(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              padding: EdgeInsets.fromLTRB(20, 12, 20, keyboard + 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxH.clamp(240.0, mq.size.height),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Row(
                        children: [
                          Icon(Icons.campaign_outlined,
                              size: 18, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text('공지사항 작성',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text('제목 *',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleCtrl,
                        maxLength: 50,
                        textInputAction: TextInputAction.next,
                        decoration: _fieldDeco('예: 6월 정기 라운딩 일정 안내'),
                      ),
                      const SizedBox(height: 12),
                      const Text('내용',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: contentCtrl,
                        maxLines: keyboard > 0 ? 3 : 4,
                        maxLength: 500,
                        decoration: _fieldDeco('공지 내용을 입력하세요'),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => setS(() => pin = !pin),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: pin
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: pin
                                      ? AppColors.primary
                                      : Colors.grey.shade400,
                                ),
                              ),
                              child: pin
                                  ? const Icon(Icons.check,
                                      size: 14, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            const Text('상단 고정',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary)),
                            const SizedBox(width: 4),
                            const Icon(Icons.push_pin_outlined,
                                size: 14, color: AppColors.accent),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            final t = titleCtrl.text.trim();
                            if (t.isEmpty) return;
                            provider.addAnnouncement(
                              title: t,
                              content: contentCtrl.text.trim().isEmpty
                                  ? null
                                  : contentCtrl.text.trim(),
                              pin: pin,
                            );
                            Navigator.pop(sheetCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 8),
                                  Text('공지사항이 등록되었습니다'),
                                ]),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('공지 등록',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static InputDecoration _fieldDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontSize: 13, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5)),
      );
}

// ── 공지사항 타일 (상세보기 + 관리자 액션) ──
class _AnnouncementTile extends StatelessWidget {
  final Announcement announcement;
  final bool isAdmin;
  final ClubProvider provider;
  const _AnnouncementTile({
    required this.announcement,
    required this.isAdmin,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    // Consumer로 감싸서 댓글 추가 후 실시간 카운트 반영
    return Consumer<ClubProvider>(
      builder: (_, prov, __) {
        // 최신 announcement 데이터 (댓글 수 포함)
        final a = prov.announcements.firstWhere(
          (x) => x.id == announcement.id,
          orElse: () => announcement,
        );
        final commentCount = a.comments.length;

        return InkWell(
          onTap: () => _showDetail(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 고정 or 일반 아이콘
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    a.isPinned ? Icons.push_pin : Icons.article_outlined,
                    size: 15,
                    color: a.isPinned ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 제목 + 댓글수
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              a.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: a.isPinned ? FontWeight.w600 : FontWeight.normal,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (commentCount > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              '($commentCount)',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.sageDeep,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (a.content != null && a.content!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          a.content!,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _relativeDate(a.createdAt),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 공지 상세보기 + 댓글 + 관리자 액션 ──
  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => _AnnouncementDetailSheet(
        announcement: announcement,
        isAdmin: isAdmin,
        provider: provider,
      ),
    );
  }

  void _confirmDelete(BuildContext context, BuildContext sheetCtx) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('공지 삭제',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('"${announcement.title}"\n공지사항을 삭제하시겠습니까?',
            style: const TextStyle(fontSize: 14, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
            child: Text('취소',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteAnnouncement(announcement.id);
              Navigator.pop(context);   // 다이얼로그
              Navigator.pop(sheetCtx);  // 상세 시트
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('공지사항이 삭제되었습니다'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}/${dt.day}';
  }
}

// ════════════════════════════════════════
//  공지사항 상세 + 댓글 시트
// ════════════════════════════════════════
class _AnnouncementDetailSheet extends StatefulWidget {
  final Announcement announcement;
  final bool isAdmin;
  final ClubProvider provider;

  const _AnnouncementDetailSheet({
    required this.announcement,
    required this.isAdmin,
    required this.provider,
  });

  @override
  State<_AnnouncementDetailSheet> createState() => _AnnouncementDetailSheetState();
}

class _AnnouncementDetailSheetState extends State<_AnnouncementDetailSheet> {
  final TextEditingController _commentCtrl = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);

    final gotPoints = widget.provider.addAnnouncementComment(
      announcementId: widget.announcement.id,
      text: text,
    );
    _commentCtrl.clear();
    _commentFocus.unfocus();
    setState(() => _submitting = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(gotPoints
          ? '댓글이 등록되었습니다! 공지 참여 포인트 +2 획득 🎉'
          : '댓글이 등록되었습니다!'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: gotPoints ? AppColors.success : null,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _editAnnouncement(
      BuildContext context, ClubProvider prov, Announcement a) async {
    final titleCtrl = TextEditingController(text: a.title);
    final contentCtrl = TextEditingController(text: a.content ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('공지 수정',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: '제목',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '내용',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(dialogCtx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (ok == true) {
      prov.updateAnnouncement(
        id: a.id,
        title: titleCtrl.text,
        content: contentCtrl.text,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('공지사항이 수정되었습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _confirmDelete(BuildContext dialogCtx, BuildContext sheetCtx) {
    showDialog(
      context: dialogCtx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('공지 삭제',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('"${widget.announcement.title}"\n공지사항을 삭제하시겠습니까?',
            style: const TextStyle(fontSize: 14, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('취소', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              widget.provider.deleteAnnouncement(widget.announcement.id);
              Navigator.pop(dialogCtx);
              Navigator.pop(sheetCtx);
              ScaffoldMessenger.of(dialogCtx).showSnackBar(
                const SnackBar(content: Text('공지사항이 삭제되었습니다'), behavior: SnackBarBehavior.floating),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (ctx, prov, _) {
        // 최신 공지 데이터 (댓글 추가 후 실시간 반영)
        final a = prov.announcements.firstWhere(
          (x) => x.id == widget.announcement.id,
          orElse: () => widget.announcement,
        );
        final comments = a.comments;

        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.88,
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            backgroundColor: AppColors.surface,
            body: Column(
            children: [
              // ── 스크롤 영역 ──
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  children: [
                    // 핸들바
                    Center(
                      child: Container(
                        width: 36, height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 고정 배지
                    if (a.isPinned)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: const [
                          Icon(Icons.push_pin, size: 12, color: AppColors.accent),
                          SizedBox(width: 4),
                          Text('상단 고정',
                              style: TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    // 제목
                    Text(a.title,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    Text(
                      '${a.createdAt.year}.${a.createdAt.month.toString().padLeft(2, '0')}.${a.createdAt.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const Divider(height: 24),
                    // 본문
                    Text(
                      a.content?.isNotEmpty == true ? a.content! : '(내용 없음)',
                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.7),
                    ),
                    // 관리/작성자 버튼
                    if (widget.isAdmin || prov.isOwnAnnouncement(a)) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(children: [
                        if (widget.isAdmin)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                prov.toggleAnnouncementPin(a.id);
                                Navigator.pop(context);
                              },
                              icon: Icon(a.isPinned ? Icons.push_pin_outlined : Icons.push_pin, size: 16),
                              label: Text(a.isPinned ? '고정 해제' : '상단 고정'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accent,
                                side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        if (widget.isAdmin) const SizedBox(width: 10),
                        if (widget.isAdmin || prov.isOwnAnnouncement(a))
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _editAnnouncement(context, prov, a),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('수정'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _confirmDelete(context, context),
                            icon: const Icon(Icons.delete_outline, size: 16),
                            label: const Text('삭제'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ]),
                    ],
                    // ── 댓글 섹션 ──
                    const SizedBox(height: 20),
                    Row(children: [
                      const Icon(Icons.chat_bubble_outline, size: 15, color: AppColors.sageDeep),
                      const SizedBox(width: 6),
                      Text(
                        '댓글 ${comments.length}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    if (comments.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: const Text('첫 번째 댓글을 남겨보세요! 💬',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            textAlign: TextAlign.center),
                      )
                    else
                      ...comments
                          .map((c) => _CommentItem(
                                announcementId: a.id,
                                comment: c,
                                provider: prov,
                              ))
                          .toList(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              // ── 댓글 입력 바 (시트 하단에 고정) ──
              SafeArea(
                top: false,
                child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(children: [
                  // 내 아바타
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.sageDeep.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        prov.currentUserName.isNotEmpty ? prov.currentUserName[0] : '?',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.sageDeep),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      focusNode: _commentFocus,
                      decoration: InputDecoration(
                        hintText: '댓글을 입력하세요…',
                        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: AppColors.sageDeep),
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitComment(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _submitting
                      ? const SizedBox(width: 36, height: 36,
                          child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
                      : IconButton(
                          onPressed: _submitComment,
                          icon: const Icon(Icons.send_rounded, color: AppColors.sageDeep, size: 20),
                          splashRadius: 20,
                        ),
                ]),
              ),
              ),
            ],
            ),
          ),
        );
      },
    );
  }
}

// ── 댓글 아이템 ──
class _CommentItem extends StatelessWidget {
  final String announcementId;
  final AnnouncementComment comment;
  final ClubProvider provider;
  const _CommentItem({
    required this.announcementId,
    required this.comment,
    required this.provider,
  });

  Future<void> _edit(BuildContext context) async {
    final ctrl = TextEditingController(text: comment.text);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('댓글 수정',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(dialogCtx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (ok == true) {
      provider.updateAnnouncementComment(
        announcementId: announcementId,
        commentId: comment.id,
        text: ctrl.text,
      );
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('댓글 삭제',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('이 댓글을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true) {
      provider.deleteAnnouncementComment(
        announcementId: announcementId,
        commentId: comment.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = comment;
    final canManage =
        provider.isOwnAnnouncementComment(c) || provider.isClubExecutive;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: AppColors.sageLighter.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                c.authorName.isNotEmpty ? c.authorName[0] : '?',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.sageDarker),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(c.authorName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(width: 6),
                  Text(_timeAgo(c.createdAt),
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  const Spacer(),
                  if (canManage)
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: const Icon(Icons.more_horiz,
                          size: 18, color: AppColors.textSecondary),
                      onSelected: (v) {
                        if (v == 'edit') _edit(context);
                        if (v == 'delete') _delete(context);
                      },
                      itemBuilder: (_) => [
                        if (provider.isOwnAnnouncementComment(c))
                          const PopupMenuItem(
                              value: 'edit', child: Text('수정')),
                        const PopupMenuItem(
                            value: 'delete', child: Text('삭제')),
                      ],
                    ),
                ]),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(c.text,
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}/${dt.day}';
  }
}

// ── 최근 활동 ──
class _ActivitySection extends StatelessWidget {
  final List<ActivityItem> activities;
  const _ActivitySection({required this.activities});

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) return const SizedBox.shrink();
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.history, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('최근 활동',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                ),
                if (activities.isNotEmpty)
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => _ActivityListScreen(activities: activities),
                    )),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('전체보기',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const Icon(Icons.keyboard_arrow_right, size: 14,
                            color: AppColors.textSecondary),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          ...activities.take(4).map((a) => ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    a.memberName.isNotEmpty ? a.memberName[0] : '?',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  '${a.memberName} · ${a.description}',
                  style: const TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(a.timeAgo,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary)),
              )),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════
//  회계 현황 카드
// ════════════════════════════════════════
class _FinanceSummaryCard extends StatelessWidget {
  final ClubProvider provider;
  final VoidCallback? onTap;
  const _FinanceSummaryCard({required this.provider, this.onTap});

  String _fmt(int n) {
    if (n == 0) return '0';
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isTreasurer = provider.isTreasurer;
    final canOpenFinance =
        isTreasurer || !provider.isFinanceSetupPending;
    final detailTap = canOpenFinance ? onTap : null;
    final balance = provider.totalBalance;
    final isGuest = provider.isGuestMember;
    final totalMembers = provider.regularMembers.length;
    final homeDues = provider.currentHomeDuesSetting(now.year, now.month);
    final paidCount = provider.paidCountForMonth(now.year, now.month);
    final prevUnpaid = provider.previousMonthUnpaidCount();
    final isMonthly = homeDues?.type == DuesType.monthly;
    final canNudge = ['회장', '부회장', '총무']
        .contains(provider.selectedClub.myRole);

    return GestureDetector(
      onTap: detailTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('현 회비 잔고',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary)),
                      if (isGuest) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.lock_outline,
                            size: 11, color: AppColors.textTertiary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            isGuest
                                ? '*********'
                                : (balance < 0
                                    ? '-${_fmt(balance)}'
                                    : _fmt(balance)),
                            maxLines: 1,
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: !isGuest && balance < 0
                                    ? const Color(0xFFC62828)
                                    : AppColors.ink,
                                height: 1.1,
                                letterSpacing: -0.2),
                          ),
                        ),
                      ),
                      const Text(' 원',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: const Color(0xFFE5E7EB),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (homeDues != null) ...[
                    Text(
                      isMonthly ? '이달 ${homeDues.title}' : homeDues.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: totalMembers > 0
                              ? Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '$paidCount',
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF2563EB)),
                                      ),
                                      TextSpan(
                                        text: '명 / $totalMembers명',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.ink),
                                      ),
                                    ],
                                  ),
                                )
                              : const Text('회원 없음',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary)),
                        ),
                        if (canNudge)
                          GestureDetector(
                            onTap: () =>
                                _showPaymentReminderSheet(context, provider),
                            child: const Text('독촉하기',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2563EB))),
                          ),
                      ],
                    ),
                    if (isMonthly) ...[
                      const SizedBox(height: 4),
                      Text(
                        '전월 미납 $prevUnpaid명',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: prevUnpaid > 0
                                ? AppColors.danger
                                : AppColors.textSecondary),
                      ),
                    ],
                  ] else
                    const Text('회비 미설정',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showNotificationPanel(BuildContext context, ClubProvider provider) {
    final clubId = provider.selectedClub.id;
    // 다른 계정에서 신청한 가입 알림을 열기 직전에 강제 동기화
    unawaited(provider.refreshJoinRequestInbox());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => Consumer<ClubProvider>(
          builder: (context, prov, __) {
            final notifs = prov.notificationsForClub(clubId);
            final unread = prov.unreadNotificationCountFor(clubId);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      const Text('알림', style: AppText.title),
                      const SizedBox(width: 8),
                      if (unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$unread',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.bold)),
                        ),
                      const Spacer(),
                      if (unread > 0)
                        TextButton(
                          onPressed: () =>
                              prov.markAllNotificationsReadForClub(clubId),
                          child: const Text('모두 읽음',
                              style: TextStyle(fontSize: 12)),
                        ),
                      if (notifs.isNotEmpty)
                        TextButton(
                          onPressed: () =>
                              prov.removeAllNotificationsForClub(clubId),
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
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final n = notifs[i];
                            final isUnread = !n.isRead;
                            return Dismissible(
                              key: ValueKey(n.id),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) =>
                                  prov.removeNotification(n.id),
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: AppColors.danger
                                      .withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.lg),
                                ),
                                child: const Icon(Icons.delete_outline,
                                    color: AppColors.danger),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () =>
                                      prov.markNotificationRead(n.id),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.lg),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isUnread
                                          ? AppColors.surface
                                          : AppColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(
                                          AppRadius.lg),
                                      border: Border.all(
                                        color: isUnread
                                            ? AppColors.sageDeep
                                                .withValues(alpha: 0.18)
                                            : AppColors.divider,
                                      ),
                                      boxShadow: isUnread
                                          ? AppShadows.soft
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isUnread
                                              ? Icons
                                                  .mark_email_unread_outlined
                                              : Icons
                                                  .mark_email_read_outlined,
                                          color: isUnread
                                              ? AppColors.sageDeep
                                              : AppColors.textTertiary,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                n.title,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: isUnread
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                  color: isUnread
                                                      ? AppColors.textPrimary
                                                      : AppColors
                                                          .textSecondary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                n.body,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isUnread
                                                      ? AppColors
                                                          .textSecondary
                                                      : AppColors
                                                          .textTertiary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                              minWidth: 32, minHeight: 32),
                                          icon: Icon(Icons.close,
                                              size: 18,
                                              color: AppColors.textTertiary
                                                  .withValues(alpha: 0.8)),
                                          onPressed: () => prov
                                              .removeNotification(n.id),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

// ── 납부 독촉 3단계 바텀시트 (top-level helper) ─────────────────────────────
void _showPaymentReminderSheet(BuildContext context, ClubProvider provider) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PaymentReminderSheet(provider: provider),
  );
}

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.4)),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  _AdMenuSection — 제휴 광고주 / 후원사 관리 메뉴 (홈 탭 하단)
//  · 광고 신청하기 (모든 회원)
//  · 후원 신청하기 (모든 회원)
//  · 광고/후원 관리 (총무/부회장/회장만)
// ════════════════════════════════════════════════════════════
class _AdMenuSection extends StatelessWidget {
  final Club club;
  final ClubProvider provider;
  const _AdMenuSection({required this.club, required this.provider});

  bool get _isAdmin => ClubMemberRole.isOfficer(club.myRole);

  @override
  Widget build(BuildContext context) {
    final pendingAdCount      = provider.pendingAdsForClub(club.id).length;
    final pendingSponsorCount = provider.pendingSponsorsForClub(club.id).length;
    final totalPendingCount   = pendingAdCount + pendingSponsorCount;

    return Container(
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
      child: Column(
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6D00), Color(0xFFFFAB40)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('AD',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5)),
                ),
                const SizedBox(width: 8),
                const Text('제휴 광고주 / 후원사 관리',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const Spacer(),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // 광고 신청하기 버튼 (누구나)
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdApplicationScreen(club: club),
              ),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.campaign_outlined,
                        size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('우리 모임에 제휴광고 신청하기',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        SizedBox(height: 2),
                        Text('홈·일정·회원 탭 배너 광고 신청',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 18, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),

          // ── 후원 신청하기 버튼 (누구나) ──
          const Divider(height: 1, color: AppColors.divider, indent: 16, endIndent: 16),
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SponsorApplicationScreen(club: club),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.volunteer_activism_outlined,
                        size: 18, color: Color(0xFF4F46E5)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('우리 모임에 후원 신청하기',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        SizedBox(height: 2),
                        Text('모임 공식 후원사로 참여하기',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 18, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),

          // ── 광고/후원 관리 버튼 (총무/부회장/회장만) ──
          if (_isAdmin) ...[
            const Divider(
                height: 1,
                color: AppColors.divider,
                indent: 16,
                endIndent: 16),
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdManagementScreen(club: club),
                ),
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6D00).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.admin_panel_settings_outlined,
                          size: 18, color: Color(0xFFFF6D00)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('광고/후원 관리',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          SizedBox(height: 2),
                          Text('광고·후원 신청 승인·거절 (관리자 전용)',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    // 승인 대기 배지 (광고 + 후원 합산)
                    if (totalPendingCount > 0)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6D00),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$totalPendingCount건',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    const Icon(Icons.chevron_right,
                        size: 18, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  공식 후원사 섹션 — 모임 홈 (참석현황~회계현황 사이)
// ════════════════════════════════════════════════════════════
class _OfficialSponsorsSection extends StatelessWidget {
  final String clubId;
  final Club club;
  const _OfficialSponsorsSection({required this.clubId, required this.club});

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final sponsors = provider.activeSponsorsForClub(clubId);
        // 디버그: 후원사 목록 확인
        if (kDebugMode) {
          debugPrint('[OfficialSponsors] clubId=$clubId, count=${sponsors.length}');
          for (final s in provider.sponsorApplicationsForClub(clubId)) {
            final now = DateTime.now();
            final dateYM  = now.year * 12 + now.month - 1;
            final startYM = s.startMonth.year * 12 + s.startMonth.month - 1;
            final endYM   = s.endMonth.year * 12 + s.endMonth.month - 1;
            debugPrint('[OfficialSponsors] sp=${s.id} status=${s.status} '
                'dateYM=$dateYM startYM=$startYM endYM=$endYM '
                'active=${s.isActiveOn(now)}');
          }
        }
        // 섹션 헤더 (항상 표시)
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 섹션 헤더
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite, size: 11, color: Colors.white),
                        SizedBox(width: 4),
                        Text('공식 후원사',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('이 모임을 응원합니다',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
              const SizedBox(height: 10),
              // 후원사 뱃지 목록 or 없음 안내
              if (sponsors.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border,
                          size: 14, color: Colors.grey.shade400),
                      const SizedBox(width: 6),
                      Text('공식 후원사가 없습니다',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                )
              else
                // 후원사 가로 스크롤 — 3.5개 노출로 '더 있음' 암시
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    // 뱃지 1개 너비 = 전체폭 / 3.5 (소수점으로 절반 노출)
                    final badgeW = (constraints.maxWidth / 3.5).clamp(90.0, 160.0);
                    return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                      child: Row(
                        children: sponsors
                            .map((sp) => SizedBox(
                                  width: badgeW,
                                  child: _SponsorBadge(sponsor: sp),
                                ))
                            .toList(),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 10),
              // ── 감사인사 피드 진입 버튼 ──
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ThankYouFeedScreen(),
                  ),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFE91E8C).withValues(alpha: 0.07),
                        const Color(0xFFE91E8C).withValues(alpha: 0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFE91E8C).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Text('💌', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '감사인사 피드 보기',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE91E8C)),
                            ),
                            Consumer<ClubProvider>(
                              builder: (_, p, __) => Text(
                                '회원들의 감사 메시지 ${p.thankYouMessages.length}개',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          size: 14, color: Color(0xFFE91E8C)),
                    ],
                  ),
                ),
              ),
              // (홈페이지 방문 안내 배너 제거됨 — 하단 후원사 섹션에 동일 내용 있음)
            ],
          ),
        );
      },
    );
  }
}

// ── 후원사 뱃지 ──────────────────────────────────────────────
class _SponsorBadge extends StatelessWidget {
  final SponsorApplication sponsor;
  const _SponsorBadge({required this.sponsor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSponsorDetail(context),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.mintBright.withValues(alpha: 0.45), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 공식후원사 뱃지
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.mintPale,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('공식후원사',
                  style: TextStyle(
                      fontSize: 9,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 5),
            // 후원사 이름
            Text(
              sponsor.sponsorName,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            // 응원하기 버튼
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.mintBright,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('응원하기',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSponsorDetail(BuildContext context) {
    final monthlyAmt = sponsor.amount ~/ sponsor.durationMonths;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 상단 헤더 (딥그린) ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // 공식후원사 뱃지
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.mintBright.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('공식 후원사',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mintBright)),
                  ),
                  const SizedBox(height: 10),
                  // 후원사 이름
                  Text(sponsor.sponsorName,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  if (sponsor.representativeName != null &&
                      sponsor.representativeName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(sponsor.representativeName!,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.75))),
                  ],
                  const SizedBox(height: 6),
                  // 후원 신청자(당사자) 이름
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_outline,
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Text('신청자: ${sponsor.applicantName}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.6))),
                    ],
                  ),
                ],
              ),
            ),
            // ── 본문 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 후원 내용 강조 박스
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.mintPale,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.mintBright.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.campaign_rounded,
                                size: 15, color: AppColors.primary),
                            const SizedBox(width: 6),
                            const Text('후원 내용',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(sponsor.description,
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                                height: 1.55)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 월 후원금
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.volunteer_activism,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text('월 후원금',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                        const Spacer(),
                        Text(
                          '${_fmtAmount(monthlyAmt)}원 / 월',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  // URL (있을 때만)
                  if (sponsor.landingUrl.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.link,
                              size: 14,
                              color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(sponsor.landingUrl,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // 응원하기 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showThankYouDialog(context, sponsor.sponsorName);
                      },
                      icon: const Icon(Icons.favorite, size: 16),
                      label: const Text('응원하기',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mintBright,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text('닫기'),
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

  // ── 감사인사 다이얼로그 (Provider 연동) ──────────────────────
  void _showThankYouDialog(BuildContext context, String sponsorName) {
    final ctrl = TextEditingController();
    final provider = context.read<ClubProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE91E8C).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite,
                  color: Color(0xFFE91E8C), size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              '$sponsorName 에게\n감사인사 보내기',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1B4B),
                  height: 1.4),
            ),
            const SizedBox(height: 4),
            Text(
              '작성한 메시지는 모든 회원이 피드에서 볼 수 있어요 (+2P)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              maxLines: 4,
              maxLength: 150,
              decoration: InputDecoration(
                hintText: '예: 항상 응원해 주셔서 감사합니다! 꼭 방문하겠습니다 😊',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE91E8C), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final msg = ctrl.text.trim();
              if (msg.isEmpty) return;
              // Provider에 저장 (포인트 +2 자동 처리)
              provider.addThankYouMessage(
                senderId: provider.currentUserId,
                senderName: '홍길동',
                sponsorName: sponsorName,
                message: msg,
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.favorite, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('$sponsorName 에게 감사인사를 전달했습니다! +2 포인트 💕'),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFFE91E8C),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('보내기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E8C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  납부 독촉 3단계 바텀시트
//  Step 0: 회비 선택
//  Step 1: 미납자 목록 + 선택
//  Step 2: 발송 확인 & 완료
// ════════════════════════════════════════════════════════════
class _PaymentReminderSheet extends StatefulWidget {
  final ClubProvider provider;
  const _PaymentReminderSheet({required this.provider});

  @override
  State<_PaymentReminderSheet> createState() => _PaymentReminderSheetState();
}

class _PaymentReminderSheetState extends State<_PaymentReminderSheet> {
  int _step = 0;
  DuesSetting? _selectedDues;
  final Set<String> _selectedMemberIds = {};

  ClubProvider get pv => widget.provider;

  // 선택된 회비의 미납자 목록
  List<Member> get _unpaidMembers {
    if (_selectedDues == null) return [];
    final club = pv.selectedClub;
    final paid = pv.duesPayments
        .where((p) => p.duesSettingId == _selectedDues!.id &&
            p.paidAt.year == DateTime.now().year &&
            p.paidAt.month == DateTime.now().month)
        .map((p) => p.memberId)
        .toSet();
    return pv.activeMembers
        .where((m) => m.memberType == '정회원' && !paid.contains(m.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          0, 12, 0, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          // 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (_step > 0)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 16),
                    onPressed: () => setState(() => _step--),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (_step > 0) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _step == 0
                        ? '납부 독촉 — 회비 선택'
                        : _step == 1
                            ? '미납자 선택'
                            : '발송 확인',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                // 단계 인디케이터
                Row(
                  children: List.generate(3, (i) => Container(
                    width: i == _step ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: i <= _step ? AppColors.primary : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )),
                ),
              ],
            ),
          ),
          const Divider(height: 20, color: Color(0xFFEEEEEE)),

          if (_step == 0) _buildStep0(),
          if (_step == 1) _buildStep1(),
          if (_step == 2) _buildStep2(),
        ],
      ),
    );
  }

  // ─── Step 0: 회비 선택 ───────────────────────────────────
  Widget _buildStep0() {
    final active = pv.activeDuesSettings;
    if (active.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('활성 회비 설정이 없습니다.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...active.map((s) => ListTile(
          leading: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(s.type.icon,
                style: const TextStyle(fontSize: 16))),
          ),
          title: Text(s.title,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${s.type.label} · ${_fmtN(s.amount)}원'),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          onTap: () {
            setState(() {
              _selectedDues = s;
              _selectedMemberIds.clear();
              _selectedMemberIds.addAll(_unpaidMembers.map((m) => m.id));
              _step = 1;
            });
          },
        )),
        const SizedBox(height: 8),
      ],
    );
  }

  // ─── Step 1: 미납자 선택 ────────────────────────────────
  Widget _buildStep1() {
    final unpaid = _unpaidMembers;
    if (unpaid.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.check_circle, size: 40, color: AppColors.success),
            SizedBox(height: 8),
            Text('모든 회원이 납부했습니다! 🎉',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 전체선택 토글
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('미납자 ${unpaid.length}명',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedMemberIds.length == unpaid.length) {
                      _selectedMemberIds.clear();
                    } else {
                      _selectedMemberIds.addAll(unpaid.map((m) => m.id));
                    }
                  });
                },
                child: Text(
                  _selectedMemberIds.length == unpaid.length
                      ? '전체 해제'
                      : '전체 선택',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: unpaid.length,
            itemBuilder: (_, i) {
              final m = unpaid[i];
              final sel = _selectedMemberIds.contains(m.id);
              return CheckboxListTile(
                value: sel,
                onChanged: (_) {
                  setState(() {
                    if (sel) {
                      _selectedMemberIds.remove(m.id);
                    } else {
                      _selectedMemberIds.add(m.id);
                    }
                  });
                },
                title: Text(m.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: Text(m.role,
                    style: const TextStyle(fontSize: 11)),
                secondary: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.danger.withValues(alpha: 0.12),
                  child: Text(m.name[0],
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.danger)),
                ),
                activeColor: AppColors.primary,
                controlAffinity: ListTileControlAffinity.trailing,
                dense: true,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _selectedMemberIds.isEmpty
                  ? null
                  : () => setState(() => _step = 2),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('${_selectedMemberIds.length}명에게 독촉 보내기',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  // ─── Step 2: 발송 확인 ────────────────────────────────────
  Widget _buildStep2() {
    final names = _unpaidMembers
        .where((m) => _selectedMemberIds.contains(m.id))
        .map((m) => m.name)
        .join(', ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text('${_selectedDues?.title ?? ''} 납부 독촉',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('대상: $names',
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                Text('총 ${_selectedMemberIds.length}명에게 알림톡이 발송됩니다.',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                pv.sendDuesNudge(
                  memberIds: _selectedMemberIds.toList(),
                  duesTitle: _selectedDues?.title ?? '',
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '${_selectedMemberIds.length}명에게 납부 독촉 알림을 발송했습니다.'),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const Text('발송하기',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtN(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ── 알림 데이터 모델 (클럽룸 내부용) ──────────────────────────────────────────
class _ClubNotification {
  final String clubName;
  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final bool isAdminOnly;
  final DateTime time;
  const _ClubNotification({
    required this.clubName,
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    required this.isAdminOnly,
    required this.time,
  });
}

// ════════════════════════════════════════════════════════════
//  공지사항 전체보기 화면
// ════════════════════════════════════════════════════════════
class _AnnouncementListScreen extends StatelessWidget {
  final List<Announcement> announcements;
  final bool isAdmin;
  final ClubProvider provider;
  const _AnnouncementListScreen({
    required this.announcements,
    required this.isAdmin,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        title: const Text('공지사항',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: announcements.isEmpty
          ? const Center(
              child: Text('등록된 공지사항이 없습니다',
                  style: TextStyle(color: AppColors.textSecondary)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: announcements.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _AnnouncementTile(
                announcement: announcements[i],
                isAdmin: isAdmin,
                provider: provider,
              ),
            ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  최근활동 전체보기 화면
// ════════════════════════════════════════════════════════════
class _ActivityListScreen extends StatelessWidget {
  final List<ActivityItem> activities;
  const _ActivityListScreen({required this.activities});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        title: const Text('최근 활동',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: activities.isEmpty
          ? const Center(
              child: Text('활동 내역이 없습니다',
                  style: TextStyle(color: AppColors.textSecondary)))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: activities.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (_, i) {
                final a = activities[i];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      a.memberName.isNotEmpty ? a.memberName[0] : '?',
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    '${a.memberName} · ${a.description}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: Text(a.timeAgo,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                );
              },
            ),
    );
  }
}
