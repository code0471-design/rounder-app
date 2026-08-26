import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/club_provider.dart';
import '../../screens/admin/admin_models.dart';
import '../../services/hq_alimtalk_catalog.dart';
import '../../theme/app_theme.dart';

/// 모임 방 · 알림톡 설정 (어드민 알림톡 관리와 동일 목록·연동)
class AlimtalkSettingsScreen extends StatefulWidget {
  const AlimtalkSettingsScreen({super.key});

  @override
  State<AlimtalkSettingsScreen> createState() => _AlimtalkSettingsScreenState();
}

class _AlimtalkSettingsScreenState extends State<AlimtalkSettingsScreen> {
  bool _showActive = true;
  bool _loading = true;
  List<HqAlimtalkType> _hqTypes = const [];

  @override
  void initState() {
    super.initState();
    HqAlimtalkCatalog.revision.addListener(_onHqRevision);
    _reloadHq();
  }

  @override
  void dispose() {
    HqAlimtalkCatalog.revision.removeListener(_onHqRevision);
    super.dispose();
  }

  void _onHqRevision() {
    _reloadHq();
  }

  Future<void> _reloadHq() async {
    final types = await HqAlimtalkCatalog.load(forceDisk: true);
    if (!mounted) return;
    setState(() {
      _hqTypes = types;
      _loading = false;
    });
  }

  /// 실효 사용중 = 본사 사용중 AND 이 모임 로컬 사용중
  bool _effectiveEnabled(ClubProvider p, HqAlimtalkType t) {
    if (!t.enabled) return false;
    return p.isClubAlimtalkTypeEnabled(p.selectedClub.id, t.id);
  }

  bool _hqDisabled(HqAlimtalkType t) => !t.enabled;

  Future<void> _setEnabled(
    ClubProvider p,
    HqAlimtalkType t,
    bool enabled,
  ) async {
    // 앱(모임) 토글은 해당 모임에만 적용 — 본사 카탈로그는 변경하지 않음
    if (enabled && _hqDisabled(t)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t.name}은(는) 본사에서 사용중지 상태입니다.'),
          backgroundColor: const Color(0xFFB45309),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    p.setClubAlimtalkTypeEnabled(p.selectedClub.id, t.id, enabled);
    await _reloadHq();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? '${t.name}을(를) 이 모임에서 사용으로 복원했습니다.'
              : '${t.name}을(를) 이 모임에서만 사용중지했습니다.',
        ),
        backgroundColor: enabled ? AppColors.primary : const Color(0xFFB45309),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _confirmDisable(ClubProvider p, HqAlimtalkType t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('사용중지',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          '${t.name} 알림톡을 이 모임에서만 사용중지할까요?\n본사 알림톡 관리 상태는 그대로 유지됩니다.',
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
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('사용중지',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok == true) await _setEnabled(p, t, false);
  }

  Future<void> _openEditor(ClubProvider p, HqAlimtalkType t) async {
    // 편집 UI는 모임 로컬 스위치를 보여 주되, 본사 중지면 안내
    var enabled = p.isClubAlimtalkTypeEnabled(p.selectedClub.id, t.id);
    final hqOff = _hqDisabled(t);
    final audience = t.audienceDetail.isNotEmpty
        ? t.audienceDetail
        : t.audience.label;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(ctx).padding.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(t.name,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    t.preview.isEmpty ? '본사 알림톡 관리와 연동된 알림입니다.' : t.preview,
                    style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _metaChip(audience, AppColors.primary),
                      const SizedBox(width: 8),
                      _metaChip(t.timing.label, const Color(0xFF0284C7)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hqOff
                        ? '본사에서 사용중지 — 모든 모임에 적용 중 (모임만 켤 수 없음)'
                        : '이 모임에만 적용됩니다. 본사 상태는 바뀌지 않습니다.',
                    style: TextStyle(
                      fontSize: 11,
                      color: hqOff
                          ? const Color(0xFFB45309)
                          : AppColors.textTertiary,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('이 모임에서 사용',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      hqOff
                          ? '본사 중지 상태에서는 사용할 수 없습니다'
                          : (enabled
                              ? '이벤트 발생 시 발송 여부를 묻습니다'
                              : '사용중지 — 이 모임에서만 묻지 않습니다'),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    value: hqOff ? false : enabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: hqOff
                        ? null
                        : (v) => setSheet(() => enabled = v),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _setEnabled(p, t, enabled);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('저장',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _metaChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _statusFilter(int activeN, int stoppedN) {
    Widget chip(bool active, String label, int n) {
      final on = _showActive == active;
      final color = active ? AppColors.primary : const Color(0xFFB45309);
      return InkWell(
        onTap: () => setState(() => _showActive = active),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: on ? color.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: on ? color : AppColors.divider),
          ),
          child: Text(
            '$label $n',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: on ? color : AppColors.textSecondary,
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClubProvider>();
    final activeN =
        _hqTypes.where((t) => _effectiveEnabled(provider, t)).length;
    final stoppedN = _hqTypes.length - activeN;
    final rows = _hqTypes
        .where((t) =>
            _showActive ? _effectiveEnabled(provider, t) : !_effectiveEnabled(provider, t))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('알림톡 설정',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '본사 설정 새로고침',
            onPressed: _loading ? null : _reloadHq,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statusFilter(activeN, stoppedN),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.divider),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : rows.isEmpty
                    ? Center(
                        child: Text(
                          _showActive
                              ? '사용 중인 알림톡이 없습니다'
                              : '사용중지된 알림톡이 없습니다',
                          style: const TextStyle(
                              color: AppColors.textTertiary, fontSize: 14),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final t = rows[i];
                          final enabled = _effectiveEnabled(provider, t);
                          final hqOff = _hqDisabled(t);
                          final audience = t.audienceDetail.isNotEmpty
                              ? t.audienceDetail
                              : t.audience.label;
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _openEditor(provider, t),
                              child: Container(
                                padding:
                                    const EdgeInsets.fromLTRB(14, 14, 10, 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            t.name,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        _metaChip(
                                          enabled
                                              ? '사용중'
                                              : (hqOff ? '본사중지' : '사용중지'),
                                          enabled
                                              ? AppColors.primary
                                              : const Color(0xFFB45309),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        _metaChip(
                                            audience, AppColors.sageDeep),
                                        _metaChip(t.timing.label,
                                            const Color(0xFF0284C7)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        if (enabled) ...[
                                          TextButton(
                                            onPressed: () =>
                                                _openEditor(provider, t),
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  AppColors.primary,
                                              padding: EdgeInsets.zero,
                                              minimumSize: const Size(0, 36),
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            child: const Text('수정',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w800)),
                                          ),
                                          const SizedBox(width: 8),
                                          TextButton(
                                            onPressed: () =>
                                                _confirmDisable(provider, t),
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  AppColors.danger,
                                              padding: EdgeInsets.zero,
                                              minimumSize: const Size(0, 36),
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            child: const Text('사용중지',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w800)),
                                          ),
                                        ] else if (hqOff)
                                          const Text(
                                            '본사에서 사용중지됨',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFB45309),
                                            ),
                                          )
                                        else
                                          TextButton.icon(
                                            onPressed: () =>
                                                _setEnabled(provider, t, true),
                                            icon: const Icon(
                                                Icons.restart_alt_rounded,
                                                size: 16),
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  AppColors.primary,
                                              padding: EdgeInsets.zero,
                                              minimumSize: const Size(0, 36),
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            label: const Text('복원',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w800)),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
