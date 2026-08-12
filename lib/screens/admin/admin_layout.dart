// ════════════════════════════════════════════════════════════
//  ROUNDER Admin Dashboard — Layout Shell
//  사이드바 + 상단바 + 메인 콘텐츠 레이아웃
// ════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/admin/application/admin_app_sync.dart';
import '../../features/admin/application/admin_controller.dart';
import '../../providers/auth_provider.dart';
import '../../providers/club_provider.dart';
import '../../widgets/rounder_app_icon.dart';
import 'admin_theme.dart';
import 'dashboard_screen.dart';
import 'admin_members_screen.dart';
import 'admin_clubs_screen.dart';
import 'admin_notifications_screen.dart';

// ────────────────────────────────────────────────────────────
//  Menu Item Model
// ────────────────────────────────────────────────────────────
class _MenuItem {
  final IconData icon;
  final String label;
  final String key;
  final int? badge;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.key,
    this.badge,
  });

  _MenuItem copyWith({int? badge}) => _MenuItem(
        icon: icon,
        label: label,
        key: key,
        badge: badge,
      );
}

// ────────────────────────────────────────────────────────────
//  Admin Root Screen
// ────────────────────────────────────────────────────────────
class AdminRootScreen extends StatefulWidget {
  const AdminRootScreen({super.key});

  @override
  State<AdminRootScreen> createState() => _AdminRootScreenState();
}

class _AdminRootScreenState extends State<AdminRootScreen>
    with WidgetsBindingObserver {
  String _currentPage = 'dashboard';
  bool _sidebarCollapsed = false;
  bool _synced = false;
  bool _syncing = false;

  static const _menuBase = <_MenuItem>[
    _MenuItem(icon: Icons.dashboard_rounded,     label: '대시보드',   key: 'dashboard'),
    _MenuItem(icon: Icons.people_rounded,        label: '회원 관리',  key: 'members'),
    _MenuItem(icon: Icons.golf_course_rounded,   label: '모임 관리',  key: 'clubs'),
    _MenuItem(icon: Icons.notifications_rounded, label: '알림 관리',  key: 'notifications'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncAppData(force: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱 탭에서 모임 만든 뒤 어드민 탭으로 돌아오면 다시 동기화
    if (state == AppLifecycleState.resumed) {
      _synced = false;
      _syncAppData(force: true);
    }
  }

  Future<void> _syncAppData({bool force = false}) async {
    if (!force && _synced) return;
    if (_syncing || !mounted) return;
    _syncing = true;
    final report = await AdminAppSync.syncFromApp(
      auth: context.read<AuthProvider>(),
      clubs: context.read<ClubProvider>(),
    );
    _syncing = false;
    if (!mounted) return;
    _synced = true;
    setState(() {});
    if (!force) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '동기화 완료 · 운영 ${report.operating}개',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _confirmResetMockData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('테스트 데이터 초기화'),
        content: const Text(
          '앱·어드민에 저장된 모든 모임/회원 테스트 데이터를 지우고\n'
          '기본 데모 모임 6개(내 모임 3개 + 그 외 3개)로 되돌립니다.\n\n'
          '이 작업은 되돌릴 수 없습니다. 계속할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final authId =
        context.read<AuthProvider>().currentUser?.id ?? 'user_me';
    final report = await AdminAppSync.resetAllMockData(
      clubs: context.read<ClubProvider>(),
      authUserId: authId,
    );
    if (!mounted) return;

    _synced = false;
    setState(() {});

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('초기화 완료'),
        content: Text(
          '테스트 데이터를 초기화했습니다.\n'
          '데모 모임 ${report.operating}개(시드)로 되돌렸습니다.\n\n'
          '앱 화면이 어색하면 브라우저 새로고침(F5)을 한 번 해주세요.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  List<_MenuItem> _menuItems(AdminController admin) {
    final blocked = admin.members.where((m) => m.status == 'blocked').length;
    return [
      for (final item in _menuBase)
        if (item.key == 'members' && blocked > 0)
          item.copyWith(badge: blocked)
        else
          item,
    ];
  }

  Widget _buildPage() {
    switch (_currentPage) {
      case 'members':       return const AdminMembersScreen();
      case 'clubs':         return const AdminClubsScreen();
      case 'notifications': return const AdminNotificationsScreen();
      case 'dashboard':
      default:              return const AdminDashboardScreen();
    }
  }

  String _pageTitle() {
    switch (_currentPage) {
      case 'members':       return '회원 관리';
      case 'clubs':         return '모임 관리';
      case 'notifications': return '알림 관리';
      default:              return '대시보드';
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = constraints.maxWidth < 800;

        // 폰: Drawer 네비 (가로 스크롤 강제 없음)
        if (isPhone) {
          return Scaffold(
            backgroundColor: AdminColors.contentBg,
            appBar: AppBar(
              backgroundColor: AdminColors.cardBg,
              foregroundColor: AdminColors.textPrimary,
              elevation: 0,
              title: Text(
                _pageTitle(),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: AdminColors.textPrimary,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: '앱 데이터 동기화',
                  onPressed: () => _syncAppData(force: true),
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  tooltip: '테스트 데이터 초기화',
                  onPressed: _confirmResetMockData,
                  icon: const Icon(Icons.restart_alt_rounded),
                ),
              ],
            ),
            drawer: Drawer(
              backgroundColor: AdminColors.sidebarBg,
              child: SafeArea(child: _buildSidebar(collapsed: false)),
            ),
            body: _buildPage(),
          );
        }

        // 태블릿~데스크톱: 사이드바 + (좁으면) 가로 스크롤
        final minW = AdminSizes.layoutMinWidth;
        final needsHScroll = constraints.maxWidth < minW;
        final shell = SizedBox(
          width: needsHScroll ? minW : constraints.maxWidth,
          height: constraints.maxHeight,
          child: _buildDesktopLayout(),
        );

        return Scaffold(
          backgroundColor: AdminColors.contentBg,
          body: needsHScroll
              ? Scrollbar(
                  thumbVisibility: true,
                  notificationPredicate: (n) =>
                      n.metrics.axis == Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: shell,
                  ),
                )
              : shell,
        );
      },
    );
  }

  // ── Desktop Layout (고정 min-width 셸 안에서 항상 이 레이아웃 사용)
  Widget _buildDesktopLayout() {
    final sidebarW = _sidebarCollapsed ? 68.0 : AdminSizes.sidebarWidth;

    return Row(
      children: [
        // ── Sidebar
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          width: sidebarW,
          child: _buildSidebar(collapsed: _sidebarCollapsed),
        ),

        // ── Content Area
        Expanded(
          child: Column(
            children: [
              // Top Bar
              _buildTopBar(),
              // Page Content
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  // 기본 Stack alignment=center면 짧은 페이지가 세로 중앙에 떠서
                  // 회원/모임 관리 상단이 쓸데없이 내려감 → 상단 고정
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: <Widget>[
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<String>(_currentPage),
                    child: _buildPage(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Sidebar
  Widget _buildSidebar({required bool collapsed}) {
    return Container(
      color: AdminColors.sidebarBg,
      child: Column(
        children: [
          // Logo Area
          _buildSidebarLogo(collapsed),
          const SizedBox(height: 8),

          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 8 : 12,
                vertical: 4,
              ),
              children: [
                if (!collapsed)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 6, top: 4),
                    child: Text(
                      'MAIN MENU',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textSidebar.withValues(alpha: 0.5),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ..._menuItems(context.watch<AdminController>())
                    .map((item) => _buildMenuItem(item, collapsed)),
              ],
            ),
          ),

          // Bottom Section
          _buildSidebarFooter(collapsed),
        ],
      ),
    );
  }

  Widget _buildSidebarLogo(bool collapsed) {
    return Container(
      height: AdminSizes.topbarHeight,
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 12 : 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          const RounderAppIcon(size: 36),
          if (!collapsed) ...[
            const SizedBox(width: 10),
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ROUNDER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    color: AdminColors.textSidebar,
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              onPressed: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
              icon: const Icon(Icons.chevron_left_rounded, color: AdminColors.textSidebar, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ] else ...[
            const Spacer(),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuItem(_MenuItem item, bool collapsed) {
    final isActive = _currentPage == item.key;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _currentPage = item.key);
          },
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 0 : 12,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? AdminColors.sidebarActive.withValues(alpha: 0.9)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: collapsed
                ? Tooltip(
                    message: item.label,
                    preferBelow: false,
                    child: Center(child: _menuIcon(item, isActive)),
                  )
                : Row(
                    children: [
                      _menuIcon(item, isActive),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.label,
                          style: isActive
                              ? AdminTextStyles.sidebarMenuActive
                              : AdminTextStyles.sidebarMenu,
                        ),
                      ),
                      if (item.badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AdminColors.statusDanger,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${item.badge}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _menuIcon(_MenuItem item, bool isActive) {
    return Icon(
      item.icon,
      size: 20,
      color: isActive ? Colors.white : AdminColors.textSidebar,
    );
  }

  Widget _buildSidebarFooter(bool collapsed) {
    return Container(
      padding: EdgeInsets.all(collapsed ? 8 : 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: collapsed
          ? Center(
              child: IconButton(
                onPressed: () => setState(() => _sidebarCollapsed = false),
                icon: const Icon(Icons.chevron_right_rounded, color: AdminColors.textSidebar, size: 20),
                padding: EdgeInsets.zero,
              ),
            )
          : Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AdminColors.sidebarHover,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person, color: AdminColors.textSidebar, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('관리자', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('admin@rounder.app', style: TextStyle(color: AdminColors.textSidebar, fontSize: 10)),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pushReplacementNamed('/login'),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.logout_rounded, color: AdminColors.textSidebar, size: 17),
                  ),
                ),
              ],
            ),
    );
  }

  // ── Top Bar
  Widget _buildTopBar() {
    return Container(
      height: AdminSizes.topbarHeight,
      decoration: const BoxDecoration(
        color: AdminColors.cardBg,
        border: Border(bottom: BorderSide(color: AdminColors.cardBorder)),
        boxShadow: [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Breadcrumb
          Text(
            '관리자',
            style: TextStyle(color: AdminColors.textHint, fontSize: 13),
          ),
          const Icon(Icons.chevron_right, color: AdminColors.textHint, size: 16),
          Text(
            _pageTitle(),
            style: const TextStyle(
              color: AdminColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),

          const Spacer(),

          // Actions
          _buildTopBarAction(
            Icons.refresh_rounded,
            '새로고침',
            () => _syncAppData(force: true),
          ),
          const SizedBox(width: 8),
          _buildTopBarAction(
            Icons.restart_alt_rounded,
            '테스트 데이터 초기화',
            _confirmResetMockData,
          ),
          const SizedBox(width: 8),
          _buildTopBarAction(Icons.help_outline_rounded, '도움말', () {}),
          const SizedBox(width: 12),

          // Admin Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AdminColors.statGreen1, AdminColors.statGreen2],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarAction(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AdminColors.contentBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminColors.cardBorder),
          ),
          child: Icon(icon, size: 18, color: AdminColors.textSecond),
        ),
      ),
    );
  }

}
