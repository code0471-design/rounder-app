import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/admin/application/admin_controller.dart';
import '../../services/hq_alimtalk_catalog.dart';
import '../../services/solapi_service.dart';
import 'admin_models.dart';
import 'admin_theme.dart';

/// 알림톡 관리 — 푸시 관리와 동일한 구조
/// · 모임 자동 알림톡: 종류 표 · 사용중/사용중지 · 수정
/// · 본사 발송: 템플릿 선택 후 발송
class AdminAlimtalkManagementTab extends StatefulWidget {
  const AdminAlimtalkManagementTab({super.key});

  @override
  State<AdminAlimtalkManagementTab> createState() =>
      _AdminAlimtalkManagementTabState();
}

class _AdminAlimtalkManagementTabState
    extends State<AdminAlimtalkManagementTab> {
  int _mode = 0; // 0 auto, 1 hq send
  bool _showActive = true;

  late List<HqAlimtalkType> _types;
  bool _loadingTypes = true;

  // ── 본사 발송 상태 ───────────────────────────────────────
  String? _selectedTemplateId;
  String _targetType = 'all';
  String _selectedClubId = '';
  bool _isSending = false;

  AlimtalkTemplate? get _template => AdminCatalog.templates
      .where((t) => t.id == _selectedTemplateId)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    _types = List<HqAlimtalkType>.from(AdminCatalog.hqAlimtalkTypes);
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    _types = await HqAlimtalkCatalog.load();
    if (!mounted) return;
    setState(() => _loadingTypes = false);
  }

  Future<void> _persistTypes() async {
    await HqAlimtalkCatalog.save(_types);
  }

  List<HqAlimtalkType> get _visible =>
      _types.where((t) => _showActive ? t.enabled : !t.enabled).toList();

  Future<void> _setEnabled(HqAlimtalkType t, bool enabled) async {
    final i = _types.indexWhere((x) => x.id == t.id);
    if (i < 0) return;
    final next = t.copyWith(enabled: enabled);
    setState(() => _types[i] = next);
    // 카탈로그 save → prefs + raw localStorage (앱 탭이 즉시 읽음)
    await HqAlimtalkCatalog.setEnabled(t.id, enabled);
    // 메모리/디스크와 동기화
    _types = await HqAlimtalkCatalog.load(forceDisk: true);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(enabled
            ? '${t.name}을(를) 사용으로 복원했습니다. 앱 모든 모임에 반영됩니다.'
            : '${t.name}을(를) 사용중지했습니다. 앱 모든 모임에 반영됩니다.'),
        backgroundColor:
            enabled ? AdminColors.statusOk : AdminColors.statusWarn,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmDisable(HqAlimtalkType t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('사용중지',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          '${t.name} 알림톡을 사용중지할까요?\n앱의 모든 모임에 사용중지로 반영됩니다.',
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
    if (ok == true) await _setEnabled(t, false);
  }

  Color _audienceColor(PushAudienceKind a) => switch (a) {
        PushAudienceKind.allMembers => AdminColors.accent,
        PushAudienceKind.attendees => AdminColors.statusInfo,
        PushAudienceKind.specificMember => AdminColors.statusWarn,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(),
          const SizedBox(height: 14),
          Expanded(child: _mode == 0 ? _autoTable() : _sendPanel()),
        ],
      ),
    );
  }

  Widget _toolbar() {
    return Row(
      children: [
        _pill(0, '모임 자동 알림톡', Icons.groups_rounded),
        const SizedBox(width: 8),
        _pill(1, '본사 발송', Icons.campaign_rounded),
        const Spacer(),
        if (_mode == 0)
          _primaryBtn(
            icon: Icons.add_rounded,
            label: '알림톡 종류 추가',
            onTap: () => _openEditor(),
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
    final activeN = _types.where((t) => t.enabled).length;
    final stoppedN = _types.where((t) => !t.enabled).length;
    Widget chip(bool active, String label, int n) {
      final on = _showActive == active;
      final color = active ? AdminColors.accent : AdminColors.statusWarn;
      return InkWell(
        onTap: () => setState(() => _showActive = active),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: on ? color.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: on ? color : AdminColors.cardBorder),
          ),
          child: Text(
            '$label $n',
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

  Widget _tableHeader(List<(int, String)> cols) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          for (final (flex, label) in cols)
            Expanded(
              flex: flex,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.textHint,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _autoTable() {
    final rows = _visible;
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
              color: _showActive
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFFFF7ED),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              border: const Border(
                  bottom: BorderSide(color: AdminColors.cardBorder)),
            ),
            child: Row(
              children: [
                Icon(
                  _showActive
                      ? Icons.check_circle_outline
                      : Icons.pause_circle_outline,
                  size: 16,
                  color: _showActive
                      ? AdminColors.accent
                      : AdminColors.statusWarn,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _showActive
                        ? '사용 중인 모임 자동 알림톡 · 사용중지하면 앱 모든 모임에 반영됩니다'
                        : '사용중지된 알림톡 · 복원하면 앱 모든 모임에 다시 사용으로 반영됩니다',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _showActive
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
                          _showActive
                              ? '사용 중인 알림톡이 없습니다'
                              : '사용중지된 알림톡이 없습니다',
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
                                                _openEditor(existing: t),
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
                                        ] else
                                          TextButton.icon(
                                            onPressed: () =>
                                                _setEnabled(t, true),
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

  Future<void> _openEditor({HqAlimtalkType? existing}) async {
    final isNew = existing == null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final previewCtrl = TextEditingController(text: existing?.preview ?? '');
    final detailCtrl =
        TextEditingController(text: existing?.audienceDetail ?? '');
    var audience = existing?.audience ?? PushAudienceKind.allMembers;
    var timing = existing?.timing ?? PushTimingKind.immediate;
    var enabled = existing?.enabled ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isNew ? '알림톡 종류 추가' : '알림톡 종류 수정',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '알림 종류명',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PushAudienceKind>(
                    value: audience,
                    decoration: const InputDecoration(
                      labelText: '발송 대상',
                      border: OutlineInputBorder(),
                    ),
                    items: PushAudienceKind.values
                        .map((a) => DropdownMenuItem(
                              value: a,
                              child: Text(a.label),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setD(() => audience = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PushTimingKind>(
                    value: timing,
                    decoration: const InputDecoration(
                      labelText: '발송 시간',
                      border: OutlineInputBorder(),
                    ),
                    items: PushTimingKind.values
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.label),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setD(() => timing = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: detailCtrl,
                    decoration: const InputDecoration(
                      labelText: '대상 상세 (선택)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: previewCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '본문 미리보기',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('사용중',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    value: enabled,
                    activeColor: AdminColors.accent,
                    onChanged: (v) => setD(() => enabled = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: Text(isNew ? '추가' : '저장',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final next = HqAlimtalkType(
      id: existing?.id ?? 'atk_${DateTime.now().millisecondsSinceEpoch}',
      name: nameCtrl.text.trim(),
      audience: audience,
      timing: timing,
      audienceDetail: detailCtrl.text.trim(),
      preview: previewCtrl.text.trim(),
      enabled: enabled,
    );
    setState(() {
      if (isNew) {
        _types = [..._types, next];
      } else {
        final i = _types.indexWhere((x) => x.id == existing.id);
        if (i >= 0) _types[i] = next;
      }
    });
    await _persistTypes();
  }

  // ── 본사 발송 (기존 템플릿 발송 UI) ───────────────────────
  Widget _sendPanel() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: _buildTemplateList()),
        const SizedBox(width: 20),
        Expanded(flex: 5, child: _buildRightPanel()),
      ],
    );
  }

  Widget _buildTemplateList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('템플릿 선택', style: AdminTextStyles.sectionTitle),
        const SizedBox(height: 2),
        const Text('발송할 알림톡 템플릿을 선택하세요',
            style: TextStyle(fontSize: 12, color: AdminColors.textHint)),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: AdminCatalog.templates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final t = AdminCatalog.templates[i];
              final isSelected = t.id == _selectedTemplateId;
              return InkWell(
                onTap: () => setState(
                    () => _selectedTemplateId = isSelected ? null : t.id),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AdminColors.accent.withValues(alpha: 0.07)
                        : AdminColors.contentBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AdminColors.accent
                          : AdminColors.cardBorder,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AdminColors.accent
                              : AdminColors.textHint.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.chat_bubble_rounded,
                            size: 18,
                            color: isSelected
                                ? Colors.white
                                : AdminColors.textHint),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.name,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? AdminColors.accent
                                        : AdminColors.textPrimary)),
                            const SizedBox(height: 3),
                            Text(
                              t.preview.split('\n').first,
                              style: const TextStyle(
                                  fontSize: 11, color: AdminColors.textHint),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded,
                            color: AdminColors.accent, size: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('미리보기', style: AdminTextStyles.sectionTitle),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F0E8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD4C89A)),
          ),
          child: _template == null
              ? const Center(
                  child: Text('템플릿을 선택해주세요',
                      style: TextStyle(
                          color: AdminColors.textHint, fontSize: 13)))
              : Text(
                  _template!.preview,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.black87, height: 1.6),
                ),
        ),
        const SizedBox(height: 16),
        const Text('발송 대상', style: AdminTextStyles.sectionTitle),
        const SizedBox(height: 8),
        _targetRadio(
            'all',
            '전체 회원 (${context.watch<AdminController>().members.length}명)'),
        _targetRadio('club', '특정 모임 회원'),
        if (_targetType == 'club') ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedClubId.isEmpty ? null : _selectedClubId,
            hint: const Text('모임 선택',
                style: TextStyle(fontSize: 13, color: AdminColors.textHint)),
            items: context
                .watch<AdminController>()
                .clubs
                .map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (v) => setState(() => _selectedClubId = v ?? ''),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AdminColors.cardBorder)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: AdminColors.contentBg,
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                _selectedTemplateId == null || _isSending ? null : _send,
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.accent,
              disabledBackgroundColor:
                  AdminColors.textHint.withValues(alpha: 0.2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text('알림톡 발송',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _targetRadio(String value, String label) {
    return InkWell(
      onTap: () => setState(() => _targetType = value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _targetType,
              onChanged: (v) => setState(() => _targetType = v!),
              activeColor: AdminColors.accent,
              visualDensity: VisualDensity.compact,
            ),
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AdminColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  List<AdminMember> _resolveTargets() {
    if (_targetType == 'all') return context.read<AdminController>().members;
    final club = context
        .read<AdminController>()
        .clubs
        .where((c) => c.id == _selectedClubId)
        .firstOrNull;
    if (club == null) return const [];
    return context
        .read<AdminController>()
        .members
        .take(club.memberCount)
        .toList();
  }

  Future<void> _send() async {
    final template = _template;
    if (template == null) return;
    if (_targetType == 'club' && _selectedClubId.isEmpty) {
      _showResultSnackBar(false, '발송할 모임을 선택해주세요.');
      return;
    }
    final solapi = SolapiService.instance;
    if (!solapi.isConfigured) {
      _showResultSnackBar(false,
          'SOLAPI API Key/Secret이 설정되지 않았습니다.\n.env 파일을 확인해주세요.');
      return;
    }
    if (!solapi.hasKakaoChannel) {
      _showResultSnackBar(false,
          '카카오 채널(SOLAPI_KAKAO_PF_ID)이 설정되지 않았습니다.\n솔라피에서 채널 연동 후 PFID를 넣어주세요.');
      return;
    }
    final templateId = (template.solapiTemplateId?.trim().isNotEmpty == true)
        ? template.solapiTemplateId!.trim()
        : (SolapiService.templateIdForAdminCatalog(template.id) ?? '');
    if (templateId.isEmpty) {
      _showResultSnackBar(false,
          '이 템플릿의 솔라피 templateId가 없습니다.\n문자 대체발송은 하지 않습니다.');
      return;
    }
    final targets = _resolveTargets();
    if (targets.isEmpty) {
      _showResultSnackBar(false, '발송 대상이 없습니다.');
      return;
    }
    setState(() => _isSending = true);
    final clubName = _targetType == 'club'
        ? (context
                .read<AdminController>()
                .clubs
                .where((c) => c.id == _selectedClubId)
                .firstOrNull
                ?.name ??
            'ROUNDER')
        : 'ROUNDER';
    final messages = targets.map((m) {
      final name = m.name.trim().isEmpty ? '회원' : m.name.trim();
      return solapi.buildAlimtalkMessage(
        to: m.phone,
        templateId: templateId,
        variables: {
          '#{이름}': name,
          '#{모임명}': clubName,
          '#{일시}': '-',
          '#{장소}': '-',
          '#{금액}': '-',
          '#{기한}': '-',
          '#{사유}': '본사 안내',
        },
      );
    }).toList();
    final result = await solapi.sendManyRaw(messages);
    setState(() => _isSending = false);
    if (!mounted) return;
    _showResultSnackBar(
      result.success,
      result.success
          ? '알림톡 "${template.name}" 발송이 완료되었습니다. (${targets.length}명 대상)'
          : '발송 중 일부 실패했습니다: ${result.errorMessage ?? "확인이 필요합니다"} '
              '(실패 ${result.failedCount}/${targets.length}건)',
    );
  }

  void _showResultSnackBar(bool success, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            success ? AdminColors.statusOk : AdminColors.statusDanger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
