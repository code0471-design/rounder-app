const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const screen = path.join(root, 'lib/screens/admin/admin_notifications_screen.dart');
const frag = path.join(root, 'scripts/_push_tab_fragment.dart');

let src = fs.readFileSync(screen, 'utf8');
const fragment = fs.readFileSync(frag, 'utf8');

const start = src.indexOf(
  '// ────────────────────────────────────────────────────────────\n//  Push Notification Tab',
);
const end = src.indexOf('// ── Helper Models');
if (start < 0 || end < 0) {
  console.error('markers missing', start, end);
  process.exit(1);
}
src = src.slice(0, start) + fragment + '\n\n' + src.slice(end);

// Fix outer layout: Column + Expanded TabBarView (no nested page scroll)
const oldBuild = `  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AdminSizes.sectionPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),
          const SizedBox(height: 20),

          // Tabs
          AdminCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tab Bar
                Container(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AdminColors.cardBorder)),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    labelColor: AdminColors.accent,
                    unselectedLabelColor: AdminColors.textSecond,
                    labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
                    indicator: const UnderlineTabIndicator(
                      borderSide: BorderSide(width: 2.5, color: AdminColors.accent),
                      insets: EdgeInsets.symmetric(horizontal: 0),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.table_chart_outlined, size: 16),
                            SizedBox(width: 6),
                            Text('알림 정책'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('알림톡 발송'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_active_outlined, size: 16),
                            SizedBox(width: 6),
                            Text('푸시 알림 발송'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab Content
                SizedBox(
                  height: 820,
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: const [
                      _NotificationPolicyTab(),
                      _AlimtalkTab(),
                      _PushNotificationTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Send History
          _buildSendHistory(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }`;

const newBuild = `  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AdminSizes.sectionPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: AdminCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: AdminColors.cardBorder)),
                    ),
                    child: TabBar(
                      controller: _tabCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      labelColor: AdminColors.accent,
                      unselectedLabelColor: AdminColors.textSecond,
                      labelStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                      unselectedLabelStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w400),
                      indicator: const UnderlineTabIndicator(
                        borderSide:
                            BorderSide(width: 2.5, color: AdminColors.accent),
                        insets: EdgeInsets.symmetric(horizontal: 0),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: const [
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.table_chart_outlined, size: 16),
                              SizedBox(width: 6),
                              Text('알림 정책'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 16),
                              SizedBox(width: 6),
                              Text('알림톡 발송'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.notifications_active_outlined,
                                  size: 16),
                              SizedBox(width: 6),
                              Text('푸시 관리'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabCtrl,
                      children: const [
                        _NotificationPolicyTab(),
                        _AlimtalkTab(),
                        _PushNotificationTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }`;

if (!src.includes(oldBuild)) {
  console.error('old build block not found — trying softer replace');
  // fallback: only height + label
  src = src.replace('height: 820,', 'height: 820, // legacy');
} else {
  src = src.replace(oldBuild, newBuild);
  console.log('layout replaced');
}

// Fix default color param (not const-safe)
src = src.replace(
  'Color color = AdminColors.statusInfo,',
  'Color? color,',
);
src = src.replace(
  'color: color = AdminColors.statusInfo,',
  'color: color,',
);
// fix _hintBanner body to use color ?? 
src = src.replace(
  `  Widget _hintBanner({
    required IconData icon,
    required String title,
    required String body,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),`,
  `  Widget _hintBanner({
    required IconData icon,
    required String title,
    required String body,
    Color? color,
  }) {
    final c = color ?? AdminColors.statusInfo;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c),`,
);

src = src.replace(
  `                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color)),`,
  `                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: c)),`,
);

fs.writeFileSync(screen, src, 'utf8');
console.log('OK written', screen);
