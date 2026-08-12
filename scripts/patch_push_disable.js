const fs = require('fs');
const path = require('path');
const file = path.join(
  __dirname,
  '..',
  'lib/screens/admin/admin_notifications_screen.dart',
);
let src = fs.readFileSync(file, 'utf8');

const start = src.indexOf(
  'class _PushNotificationTabState extends State<_PushNotificationTab> {',
);
if (start < 0) {
  console.error('state class missing');
  process.exit(1);
}

// Replace from state class fields through end of _clubTable method (keep broadcast+)
const clubTableEnd = src.indexOf('  // ── 본사 전체 발송 테이블');
if (clubTableEnd < 0) {
  console.error('broadcast marker missing');
  process.exit(1);
}

const replacement = `class _PushNotificationTabState extends State<_PushNotificationTab> {
  static const _prefsKey = 'admin_hq_push_types_v1';

  int _mode = 0; // 0 club auto, 1 hq broadcast
  /// true = 사용중 목록, false = 사용중지 목록
  bool _showActiveClubTypes = true;

  late List<HqPushType> _clubTypes;
  late List<HqBroadcastJob> _broadcasts;
  bool _loadingTypes = true;

  @override
  void initState() {
    super.initState();
    _clubTypes = List<HqPushType>.from(AdminCatalog.hqPushTypes);
    _broadcasts = [
      HqBroadcastJob(
        id: 'bc1',
        title: 'ROUNDER 업데이트 안내',
        body: '앱이 업데이트되었습니다. 최신 버전으로 이용해 주세요.',
        when: DateTime.now().subtract(const Duration(days: 2)),
        sendNow: true,
        status: 'sent',
      ),
    ];
    _loadClubTypes();
  }

  Future<void> _loadClubTypes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List)
            .map((e) => HqPushType.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (list.isNotEmpty) {
          _clubTypes = list;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loadingTypes = false);
  }

  Future<void> _persistClubTypes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_clubTypes.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  List<HqPushType> get _visibleClubTypes => _clubTypes
      .where((t) => _showActiveClubTypes ? t.enabled : !t.enabled)
      .toList();

  Future<void> _setClubEnabled(HqPushType t, bool enabled) async {
    final i = _clubTypes.indexWhere((x) => x.id == t.id);
    if (i < 0) return;
    setState(() {
      _clubTypes[i] = t.copyWith(enabled: enabled);
    });
    await _persistClubTypes();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(enabled
            ? '\${t.name}을(를) 사용 상태로 복원했습니다.'
            : '\${t.name}을(를) 사용중지했습니다.'),
        backgroundColor:
            enabled ? AdminColors.statusOk : AdminColors.statusWarn,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(),
          const SizedBox(height: 14),
          Expanded(child: _mode == 0 ? _clubTable() : _broadcastTable()),
        ],
      ),
    );
  }

  // ── 상단: 모드 + 추가 버튼 (항상 보임) ───────────────────
  Widget _toolbar() {
    return Row(
      children: [
        _pill(0, '모임 자동 푸시', Icons.groups_rounded),
        const SizedBox(width: 8),
        _pill(1, '본사 전체 발송', Icons.campaign_rounded),
        const Spacer(),
        if (_mode == 0)
          _primaryBtn(
            icon: Icons.add_rounded,
            label: '푸시 종류 추가',
            onTap: () => _openClubEditor(),
          )
        else
          _primaryBtn(
            icon: Icons.add_rounded,
            label: '새 발송 추가',
            onTap: () => _openBroadcastEditor(),
          ),
      ],
    );
  }

  Widget _pill(int i, String label, IconData icon) {
    final on = _mode == i;
    return Material(
      color: on ? AdminColors.accent : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => setState(() => _mode = i),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: on ? AdminColors.accent : AdminColors.cardBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: on ? Colors.white : AdminColors.textSecond),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: on ? Colors.white : AdminColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _primaryBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AdminColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _statusFilter() {
    final activeN = _clubTypes.where((t) => t.enabled).length;
    final stoppedN = _clubTypes.where((t) => !t.enabled).length;
    Widget chip(bool active, String label, int n) {
      final on = _showActiveClubTypes == active;
      final color = active ? AdminColors.accent : AdminColors.statusWarn;
      return InkWell(
        onTap: () => setState(() => _showActiveClubTypes = active),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: on ? color.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: on ? color : AdminColors.cardBorder),
          ),
          child: Text(
            '\$label \$n',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: on ? color : AdminColors.textSecond,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(true, '사용중', activeN),
        const SizedBox(width: 8),
        chip(false, '사용중지', stoppedN),
      ],
    );
  }

  // ── 모임 자동 푸시 테이블 ────────────────────────────────
  Widget _clubTable() {
    final rows = _visibleClubTypes;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: _showActiveClubTypes
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFFFF7ED),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: const Border(
                  bottom: BorderSide(color: AdminColors.cardBorder)),
            ),
            child: Row(
              children: [
                Icon(
                  _showActiveClubTypes
                      ? Icons.check_circle_outline
                      : Icons.pause_circle_outline,
                  size: 16,
                  color: _showActiveClubTypes
                      ? AdminColors.accent
                      : AdminColors.statusWarn,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _showActiveClubTypes
                        ? '사용 중인 모임 자동 푸시 · 사용중지하면 발송되지 않습니다'
                        : '사용중지된 푸시 · 복원하면 다시 사용 목록으로 이동합니다',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _showActiveClubTypes
                          ? AdminColors.accent
                          : const Color(0xFFB45309),
                    ),
                  ),
                ),
                _statusFilter(),
              ],
            ),
          ),
          _tableHeader(const [
            (3, '알림 종류'),
            (2, '발송 대상'),
            (2, '발송 시간'),
            (1, '상태'),
            (2, ''),
          ]),
          Expanded(
            child: _loadingTypes
                ? const Center(child: CircularProgressIndicator())
                : rows.isEmpty
                    ? Center(
                        child: Text(
                          _showActiveClubTypes
                              ? '사용 중인 푸시가 없습니다'
                              : '사용중지된 푸시가 없습니다',
                          style: const TextStyle(
                              color: AdminColors.textHint, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (_, i) {
                          final t = rows[i];
                          return Container(
                            height: 56,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: i.isEven
                                  ? Colors.white
                                  : const Color(0xFFF8FAFC),
                              border: const Border(
                                  bottom: BorderSide(
                                      color: AdminColors.divider)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(t.name,
                                      style: AdminTextStyles.tableCell
                                          .copyWith(
                                              fontWeight: FontWeight.w700),
                                      overflow: TextOverflow.ellipsis),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: AdminBadge(
                                      label: t.audience.label,
                                      color: _audienceColor(t.audience),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: AdminBadge(
                                      label: t.timing.label,
                                      color: AdminColors.statusInfo,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: AdminBadge(
                                      label: t.enabled ? '사용중' : '사용중지',
                                      color: t.enabled
                                          ? AdminColors.statusOk
                                          : AdminColors.statusWarn,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (t.enabled) ...[
                                          TextButton(
                                            onPressed: () =>
                                                _openClubEditor(existing: t),
                                            child: const Text('수정',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700)),
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  AdminColors.accent,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                _confirmDisable(t),
                                            child: const Text('사용중지',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700)),
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  AdminColors.statusDanger,
                                            ),
                                          ),
                                        ] else ...[
                                          TextButton.icon(
                                            onPressed: () =>
                                                _setClubEnabled(t, true),
                                            icon: const Icon(
                                                Icons.restart_alt_rounded,
                                                size: 16),
                                            label: const Text('복원',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w800)),
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  AdminColors.accent,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDisable(HqPushType t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('사용중지',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          '\${t.name} 푸시를 사용중지할까요?\\n사용중지 목록에 남으며, 언제든 복원할 수 있습니다.',
          style: const TextStyle(height: 1.5, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.statusDanger,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('사용중지',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok == true) await _setClubEnabled(t, false);
  }

`;

// Fix JS template escapes for Dart interpolations
const fixed = replacement
  .replace(/\\\$\{/g, '${')
  .replace(/\\\\n/g, '\\n');

src = src.slice(0, start) + fixed + src.slice(clubTableEnd);
fs.writeFileSync(file, src, 'utf8');
console.log('patched club disable/restore', fixed.length);
