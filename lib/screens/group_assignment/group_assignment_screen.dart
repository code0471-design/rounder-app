import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/club_model.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/alimtalk_utils.dart';

// ─────────────────────────────────────────────
//  조별 색상 팔레트 — 브랜드 그린 톤
// ─────────────────────────────────────────────
const _kGroupColors = [
  Color(0xFF1B4D3E), // 1조
  Color(0xFF2A6B55), // 2조
  Color(0xFF3D6B5A), // 3조
  Color(0xFF5A8F7B), // 4조
  Color(0xFF2F5C4C), // 5조
  Color(0xFF4A7A68), // 6조
  Color(0xFF153D32), // 7조
  Color(0xFF6B9B88), // 8조
];

Color _groupColor(int groupNumber) =>
    _kGroupColors[(groupNumber - 1) % _kGroupColors.length];

// ─────────────────────────────────────────────
//  조편성 메인 화면 (세로 스크롤)
// ─────────────────────────────────────────────
class GroupAssignmentScreen extends StatefulWidget {
  final RoundSchedule schedule;
  const GroupAssignmentScreen({super.key, required this.schedule});

  @override
  State<GroupAssignmentScreen> createState() => _GroupAssignmentScreenState();
}

class _GroupAssignmentScreenState extends State<GroupAssignmentScreen> {
  final Set<AutoAssignOption> _selectedOptions = {};
  GroupSlot? _draggingSlot;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    final p = context.read<ClubProvider>();
    // 일정에 설정된 팀 수(1팀 포함)로 조편성 동기화
    p.syncAssignmentTeamCountFromSchedule(widget.schedule.id);
    final assign = p.getOrCreateAssignment(widget.schedule.id);
    _selectedOptions.addAll(assign.selectedOptions);
    if (p.groupAssignment(widget.schedule.id) == null) {
      Future.microtask(() => p.saveAssignment(assign));
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── 팀 수 변경 ──
  void _onTeamCountChanged(ClubProvider p, int newCount) {
    p.changeTeamCount(widget.schedule.id, newCount);
  }

  // ── 자동 배정 실행 ──
  void _runAutoAssign(ClubProvider p) {
    final scheduleId = widget.schedule.id;
    final assignment = p.getOrCreateAssignment(scheduleId);
    final schedule = p.scheduleById(scheduleId) ?? widget.schedule;
    final attendeeCount =
        schedule.responses.where((r) => r.response == '참석').length;
    final totalSlots = assignment.groups.fold<int>(
      0,
      (sum, g) => sum + g.slots.length,
    );
    final assignedBefore = assignment.assignedCount;

    if (attendeeCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('참석 확정 인원이 없어 자동 배정할 수 없습니다.'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // 전체 자동: 기존 배정 무시 / 혼합: 수동 배정 유지
    final keepManual = assignment.mode != GroupAssignmentMode.auto;

    p.setAssignmentOptions(scheduleId, _selectedOptions.toList());
    p.autoAssign(
      scheduleId: scheduleId,
      options: _selectedOptions.toList(),
      keepManual: keepManual,
    );

    final after = p.groupAssignment(scheduleId);
    final emptyAfter = after?.emptyCount ?? 0;
    final assignedAfter = after?.assignedCount ?? 0;
    final short = attendeeCount < totalSlots;

    if (assignedAfter <= assignedBefore && keepManual) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            assignedAfter == attendeeCount
                ? '이미 모든 참석자가 배정되어 있습니다.'
                : '배정할 빈 자리가 없거나 미배정 인원이 없습니다. 조 수를 늘리거나 초기화 후 다시 시도하세요.',
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(short
            ? '✅ 자동 배정 완료! (참석 $attendeeCount명 / 자리 $totalSlots · 빈자리 $emptyAfter)\n'
                '팀 수를 줄이거나 참석 신청을 더 받은 뒤 다시 배정해보세요.'
            : '✅ 자동 배정 완료! ($assignedAfter명 배정)'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: short ? 4 : 2),
      ),
    );
  }

  void _onModeChanged(ClubProvider p, GroupAssignmentMode mode) {
    p.setAssignmentMode(widget.schedule.id, mode);
  }

  void _onOptionToggled(ClubProvider p, AutoAssignOption opt) {
    setState(() {
      if (_selectedOptions.contains(opt)) {
        _selectedOptions.remove(opt);
      } else {
        _selectedOptions.add(opt);
      }
    });
    p.setAssignmentOptions(widget.schedule.id, _selectedOptions.toList());
  }

  // ── 초기화 확인 다이얼로그 ──
  Future<void> _confirmClear(ClubProvider p) async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('조편성 초기화',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('모든 배정을 초기화하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
    if (ok == true) p.clearAssignment(widget.schedule.id);
  }

  // ── 확정 / 확정 취소 ──
  Future<void> _confirmFinalize(ClubProvider p, bool isFinalized) async {
    if (!isFinalized) {
      // 저장 보장: 아직 map에 없으면 현재 화면 상태 저장
      if (p.groupAssignment(widget.schedule.id) == null) {
        p.saveAssignment(p.getOrCreateAssignment(widget.schedule.id));
      }
      final assign = p.groupAssignment(widget.schedule.id);
      final emptyCount = assign?.emptyCount ?? 0;
      bool proceed = true;
      if (emptyCount > 0) {
        proceed = await showDialog<bool>(
              context: context,
              useRootNavigator: true,
              barrierDismissible: false,
              builder: (dialogCtx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: const Text('조편성 확정',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                content: Text('빈 슬롯이 $emptyCount개 있습니다.\n그래도 확정하시겠습니까?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(false),
                      child: const Text('취소')),
                  ElevatedButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                    child: const Text('확정'),
                  ),
                ],
              ),
            ) ??
            false;
      }
      if (!proceed || !mounted) return;
      p.finalizeAssignment(widget.schedule.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('조편성이 확정되었습니다'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );

      final live =
          p.scheduleById(widget.schedule.id) ?? widget.schedule;
      final settings = p.alimtalkSettingsOf(live.clubId);
      final isAdmin =
          p.isClubExecutive;
      if (isAdmin && settings.promptOnGroupFinalize) {
        final sent = await AlimtalkUtils.runGroupFlow(
          provider: p,
          schedule: live,
        );
        if (sent == true && mounted) {
          Navigator.of(context).pop(); // 조편성 → 일정 상세
          if (mounted) Navigator.of(context).pop(); // 일정 상세 → 일정 목록
          return;
        }
      }
      if (mounted) Navigator.of(context).pop(); // 일정 상세로 복귀
    } else {
      p.unfinalizeAssignment(widget.schedule.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('확정이 취소되었습니다. 조편성을 수정할 수 있습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(builder: (context, provider, _) {
      final schedule =
          provider.scheduleById(widget.schedule.id) ?? widget.schedule;
      final assignment = provider.getOrCreateAssignment(schedule.id);
      final attendees = schedule.responses
          .where((r) => r.response == '참석')
          .toList();
      final isFinalized = assignment.isFinalized;
      final assignedCount = assignment.assignedCount;
      final totalAttend = attendees.length;

      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Color(0xFF333333), size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          titleSpacing: 0,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                schedule.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFF999999), fontSize: 11),
              ),
              Row(
                children: [
                  const Text('조편성',
                      style: TextStyle(
                          color: Color(0xFF222222),
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  if (isFinalized) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('확정',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ],
          ),
          actions: [
            if (!isFinalized)
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: Color(0xFF999999), size: 20),
                tooltip: '전체 초기화',
                onPressed: () => _confirmClear(provider),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FilledButton(
                onPressed: () => _confirmFinalize(provider, isFinalized),
                style: FilledButton.styleFrom(
                  backgroundColor: isFinalized
                      ? const Color(0xFFF5F5F5)
                      : AppColors.primary,
                  foregroundColor: isFinalized
                      ? const Color(0xFF777777)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 0),
                  minimumSize: const Size(0, 34),
                ),
                child: Text(
                  isFinalized ? '수정하기' : '확  정',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(37),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '참석 $totalAttend명 · 배정 $assignedCount명',
                        style: const TextStyle(
                            color: Color(0xFF777777),
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                Container(color: const Color(0xFFEEEEEE), height: 1),
              ],
            ),
          ),
        ),
        body: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [

            // ── 조편성 방식 3가지 선택 (확정 전) ──
            if (!isFinalized)
              SliverToBoxAdapter(
                child: _ModeSelector(
                  selected: assignment.mode,
                  onChanged: (mode) => _onModeChanged(provider, mode),
                ),
              ),

            // ── 컨트롤 패널 (조 수 + 자동배정 옵션: 모드에 따라) ──
            if (!isFinalized)
              SliverToBoxAdapter(
                child: _ControlPanel(
                  assignment: assignment,
                  selectedOptions: _selectedOptions,
                  onTeamCountChanged: (n) =>
                      _onTeamCountChanged(provider, n),
                  onOptionToggled: (opt) =>
                      _onOptionToggled(provider, opt),
                  onAutoAssign: () => _runAutoAssign(provider),
                ),
              ),

            // ── 미배정 멤버 풀 (확정 전만 표시) ──
            if (!isFinalized)
              SliverToBoxAdapter(
                child: _UnassignedPool(
                  assignment: assignment,
                  attendees: attendees,
                  onDragStarted: (slot) =>
                      setState(() => _draggingSlot = slot),
                  onDragEnded: () =>
                      setState(() => _draggingSlot = null),
                ),
              ),

            // ── 1조 ~ N조 카드 (한 줄에 2조) ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, rowIndex) {
                    final left = rowIndex * 2;
                    final right = left + 1;
                    final count = assignment.teamCount;

                    Widget buildCard(int gi) => _GroupCard(
                          group: assignment.groups[gi],
                          assignment: assignment,
                          isFinalized: isFinalized,
                          draggingSlot: _draggingSlot,
                          onDragStarted: (slot) =>
                              setState(() => _draggingSlot = slot),
                          onDragEnded: () =>
                              setState(() => _draggingSlot = null),
                          onSlotTap: (si) => _showSlotPicker(
                              context, provider, assignment, gi, si),
                          onDrop: (si, slot) => provider.assignMember(
                            scheduleId: widget.schedule.id,
                            groupIndex: gi,
                            slotIndex: si,
                            slot: slot,
                          ),
                          onClearSlot: (si) => provider.clearSlot(
                            scheduleId: widget.schedule.id,
                            groupIndex: gi,
                            slotIndex: si,
                          ),
                        );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: buildCard(left)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: right < count
                                  ? buildCard(right)
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: (assignment.teamCount + 1) ~/ 2,
                ),
              ),
            ),

            // ── 하단 여백 ──
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      );  // Scaffold
    });
  }

  // ── 슬롯 멤버 선택 바텀시트 ──
  Future<void> _showSlotPicker(
    BuildContext context,
    ClubProvider provider,
    GroupAssignment assignment,
    int gi,
    int si,
  ) async {
    final schedule =
        provider.scheduleById(widget.schedule.id) ?? widget.schedule;
    final attendees = schedule.responses
        .where((r) => r.response == '참석')
        .toList();
    final memberMap = {for (final m in provider.members) m.id: m};
    final currentSlot = assignment.groups[gi].slots[si];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SlotPickerSheet(
        groupNumber: gi + 1,
        slotIndex: si,
        currentSlot: currentSlot,
        assignment: assignment,
        attendees: attendees,
        memberMap: memberMap,
        onSelect: (slot) => provider.assignMember(
          scheduleId: widget.schedule.id,
          groupIndex: gi,
          slotIndex: si,
          slot: slot,
        ),
        onClear: () => provider.clearSlot(
          scheduleId: widget.schedule.id,
          groupIndex: gi,
          slotIndex: si,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  조편성 방식 3가지 선택
// ─────────────────────────────────────────────
class _ModeSelector extends StatelessWidget {
  final GroupAssignmentMode selected;
  final ValueChanged<GroupAssignmentMode> onChanged;

  const _ModeSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '조편성 방식 선택',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '원하는 방식을 하나 고른 뒤 배정을 진행하세요',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ...GroupAssignmentMode.values.map((mode) {
            final isSelected = mode == selected;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : const Color(0xFFF7F8F9),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => onChanged(mode),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : const Color(0xFFE5E7EB),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(mode.icon, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mode.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                mode.description,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          size: 22,
                          color: isSelected
                              ? AppColors.primary
                              : const Color(0xFFB0B8C1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  컨트롤 패널 (조 수 + 자동배정 옵션)
// ─────────────────────────────────────────────
class _ControlPanel extends StatelessWidget {
  final GroupAssignment assignment;
  final Set<AutoAssignOption> selectedOptions;
  final ValueChanged<int> onTeamCountChanged;
  final ValueChanged<AutoAssignOption> onOptionToggled;
  final VoidCallback onAutoAssign;

  const _ControlPanel({
    required this.assignment,
    required this.selectedOptions,
    required this.onTeamCountChanged,
    required this.onOptionToggled,
    required this.onAutoAssign,
  });

  @override
  Widget build(BuildContext context) {
    final showAuto = assignment.mode.usesAutoRules;

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 조 수 선택 ──
          Row(
            children: [
              const Icon(Icons.grid_view_rounded,
                  size: 15, color: Color(0xFF546E7A)),
              const SizedBox(width: 6),
              const Text('조 수',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF37474F))),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    // 1~30조 (모임/일정 팀 수 설정 반영)
                    children: List.generate(30, (i) => i + 1).map((n) {
                      final selected = n == assignment.teamCount;
                      return GestureDetector(
                        onTap: () => onTeamCountChanged(n),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 6),
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : const Color(0xFFE0E0E0),
                              width: selected ? 0 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$n조',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF78909C),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),

          if (showAuto) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF0F4F8)),
            const SizedBox(height: 12),

            // ── 자동배정 옵션 ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.auto_awesome,
                      size: 15, color: Color(0xFF546E7A)),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text('자동배정 옵션',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF37474F))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: AutoAssignOption.values.map((opt) {
                      final sel = selectedOptions.contains(opt);
                      return GestureDetector(
                        onTap: () => onOptionToggled(opt),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.primary
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                  ? AppColors.primary
                                  : const Color(0xFFE0E0E0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (sel) ...[
                                const Icon(Icons.check,
                                    size: 11, color: Colors.white),
                                const SizedBox(width: 3),
                              ],
                              Text(
                                opt.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: sel
                                      ? Colors.white
                                      : const Color(0xFF78909C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── 자동 배정 버튼 ──
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: onAutoAssign,
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: Text(
                  assignment.mode == GroupAssignmentMode.auto
                      ? '전체 자동 배정 실행'
                      : '빈 자리 자동 배정',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '참가자를 드래그하거나 슬롯을 탭해 직접 배정하세요.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  미배정 멤버 풀
// ─────────────────────────────────────────────
class _UnassignedPool extends StatelessWidget {
  final GroupAssignment assignment;
  final List<AttendanceResponse> attendees;
  final ValueChanged<GroupSlot> onDragStarted;
  final VoidCallback onDragEnded;

  const _UnassignedPool({
    required this.assignment,
    required this.attendees,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  @override
  Widget build(BuildContext context) {
    final assignedIds = <String>{};
    for (final g in assignment.groups) {
      for (final s in g.slots) {
        if (s.isFilled) assignedIds.add(s.memberId!);
      }
    }
    final unassigned =
        attendees.where((r) => !assignedIds.contains(r.memberId)).toList();

    return Container(
      margin: const EdgeInsets.only(top: 2),
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: unassigned.isEmpty
                      ? AppColors.success
                      : AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                unassigned.isEmpty
                    ? '모든 참석자 배정 완료 ✅'
                    : '미배정 ${unassigned.length}명 — 드래그하거나 탭하여 배정',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: unassigned.isEmpty
                      ? AppColors.success
                      : AppColors.primary,
                ),
              ),
            ],
          ),
          if (unassigned.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: unassigned.map((r) {
                  final slot = GroupSlot(memberId: r.memberId, memberName: r.memberName);
                  return Draggable<GroupSlot>(
                    data: slot,
                    onDragStarted: () => onDragStarted(slot),
                    onDragEnd: (_) => onDragEnded(),
                    feedback: Material(
                      color: Colors.transparent,
                      child: _MemberChip(name: r.memberName, isDragging: true),
                    ),
                    childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: _MemberChip(name: r.memberName)),
                    child: _MemberChip(name: r.memberName),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  final String name;
  final bool isDragging;
  const _MemberChip({required this.name, this.isDragging = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDragging
            ? AppColors.primary
            : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDragging
              ? AppColors.primaryDark
              : AppColors.primary.withValues(alpha: 0.25),
        ),
        boxShadow: isDragging
            ? [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ]
            : null,
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDragging ? Colors.white : AppColors.primary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  한 조 카드 (2열 그리드용)
// ─────────────────────────────────────────────
class _GroupCard extends StatelessWidget {
  final AssignGroup group;
  final GroupAssignment assignment;
  final bool isFinalized;
  final GroupSlot? draggingSlot;
  final ValueChanged<GroupSlot> onDragStarted;
  final VoidCallback onDragEnded;
  final ValueChanged<int> onSlotTap;
  final void Function(int si, GroupSlot slot) onDrop;
  final ValueChanged<int> onClearSlot;

  const _GroupCard({
    required this.group,
    required this.assignment,
    required this.isFinalized,
    required this.draggingSlot,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onSlotTap,
    required this.onDrop,
    required this.onClearSlot,
  });

  @override
  Widget build(BuildContext context) {
    final color = _groupColor(group.groupNumber);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── 조 헤더 ──
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.75)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                // 조 번호 원
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${group.groupNumber}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${group.groupNumber}조',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${group.filledCount}/${group.slots.length}명',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (group.filledCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '⌀${group.avgHandicap.toStringAsFixed(1)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),

          // ── 슬롯 목록 ──
          ...List.generate(group.slots.length, (si) {
            final slot = group.slots[si];
            final isLast = si == group.slots.length - 1;
            return Column(
              children: [
                _SlotRow(
                  slot: slot,
                  slotIndex: si,
                  groupColor: color,
                  isFinalized: isFinalized,
                  compact: true,
                  onTap: isFinalized ? null : () => onSlotTap(si),
                  onDrop: (dropped) => onDrop(si, dropped),
                  onClear: () => onClearSlot(si),
                  onDragStarted: slot.isFilled && !isFinalized
                      ? () => onDragStarted(slot)
                      : null,
                  onDragEnded: onDragEnded,
                ),
                if (!isLast)
                  const Divider(
                      height: 1, indent: 10, endIndent: 10,
                      color: Color(0xFFF0F4F8)),
              ],
            );
          }),

          // ── 성별 분포 바 ──
          if (group.filledCount > 0) ...[
            const Divider(height: 1, color: Color(0xFFF5F5F5)),
            _GenderBar(slots: group.slots, color: color),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  슬롯 행
// ─────────────────────────────────────────────
class _SlotRow extends StatelessWidget {
  final GroupSlot slot;
  final int slotIndex;
  final Color groupColor;
  final bool isFinalized;
  final bool compact;
  final VoidCallback? onTap;
  final ValueChanged<GroupSlot> onDrop;
  final VoidCallback onClear;
  final VoidCallback? onDragStarted;
  final VoidCallback onDragEnded;

  const _SlotRow({
    required this.slot,
    required this.slotIndex,
    required this.groupColor,
    required this.isFinalized,
    this.compact = false,
    required this.onTap,
    required this.onDrop,
    required this.onClear,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  @override
  Widget build(BuildContext context) {
    final rowH = compact ? 48.0 : 62.0;
    final hPad = compact ? 8.0 : 16.0;
    final avatar = compact ? 28.0 : 38.0;

    if (slot.isEmpty) {
      // ── 빈 슬롯 ──
      return DragTarget<GroupSlot>(
        onWillAcceptWithDetails: (d) => d.data.isFilled && !isFinalized,
        onAcceptWithDetails: (d) => onDrop(d.data),
        builder: (_, candidateData, __) {
          final hovering = candidateData.isNotEmpty;
          return GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: rowH,
              padding: EdgeInsets.symmetric(horizontal: hPad),
              decoration: BoxDecoration(
                color: hovering
                    ? groupColor.withValues(alpha: 0.06)
                    : Colors.transparent,
              ),
              child: Row(
                children: [
                  // 슬롯 번호
                  Container(
                    width: compact ? 24 : 30,
                    height: compact ? 24 : 30,
                    decoration: BoxDecoration(
                      color: hovering
                          ? groupColor.withValues(alpha: 0.15)
                          : const Color(0xFFF5F5F5),
                      shape: BoxShape.circle,
                      border: hovering
                          ? Border.all(
                              color: groupColor.withValues(alpha: 0.4))
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '${slotIndex + 1}',
                        style: TextStyle(
                          fontSize: compact ? 11 : 13,
                          fontWeight: FontWeight.w700,
                          color: hovering
                              ? groupColor
                              : const Color(0xFFBDBDBD),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 14),
                  Expanded(
                    child: Text(
                      hovering
                          ? '놓기'
                          : (compact ? '+ 추가' : '+ 멤버 추가'),
                      style: TextStyle(
                        fontSize: compact ? 11 : 13,
                        color: hovering
                            ? groupColor
                            : const Color(0xFFD0D0D0),
                        fontWeight: hovering
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isFinalized && !hovering && !compact)
                    Icon(Icons.add_circle_outline,
                        size: 20,
                        color: groupColor.withValues(alpha: 0.35)),
                  if (hovering)
                    Icon(Icons.south_rounded,
                        size: compact ? 14 : 18, color: groupColor),
                ],
              ),
            ),
          );
        },
      );
    }

    // ── 채워진 슬롯 ──
    final genderIcon = slot.gender == '여' ? '♀' : '♂';
    final genderColor = slot.gender == '여'
        ? const Color(0xFFE91E63)
        : AppColors.primaryLight;

    final rowContent = DragTarget<GroupSlot>(
      onWillAcceptWithDetails: (d) =>
          d.data.isFilled &&
          d.data.memberId != slot.memberId &&
          !isFinalized,
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (_, candidateData, __) {
        final hovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: rowH,
          padding: EdgeInsets.symmetric(horizontal: hPad),
          decoration: BoxDecoration(
            color: hovering
                ? groupColor.withValues(alpha: 0.05)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              // 아바타
              Container(
                width: avatar,
                height: avatar,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      groupColor.withValues(alpha: 0.18),
                      groupColor.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    slot.memberName!.substring(0, 1),
                    style: TextStyle(
                      color: groupColor,
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 12 : 16,
                    ),
                  ),
                ),
              ),
              SizedBox(width: compact ? 6 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            slot.memberName!,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: compact ? 12 : 14,
                              color: const Color(0xFF1C2B36),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(genderIcon,
                            style: TextStyle(
                                fontSize: compact ? 10 : 11,
                                color: genderColor)),
                      ],
                    ),
                    if (slot.handicap != null && !compact)
                      Text(
                        '핸디 ${slot.handicap!.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF90A4AE)),
                      ),
                  ],
                ),
              ),
              if (hovering)
                Icon(Icons.swap_horiz_rounded,
                    size: compact ? 16 : 22, color: groupColor),
              // X 삭제 버튼
              if (!isFinalized && !hovering)
                GestureDetector(
                  onTap: onClear,
                  child: Container(
                    width: compact ? 22 : 28,
                    height: compact ? 22 : 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(Icons.close_rounded,
                        size: compact ? 12 : 14,
                        color: const Color(0xFF90A4AE)),
                  ),
                ),
            ],
          ),
        );
      },
    );

    // 드래그 가능 여부
    if (!isFinalized && onDragStarted != null) {
      return Draggable<GroupSlot>(
        data: slot,
        onDragStarted: onDragStarted!,
        onDragEnd: (_) => onDragEnded(),
        feedback: Material(
          color: Colors.transparent,
          child: _MemberChip(name: slot.memberName!, isDragging: true),
        ),
        childWhenDragging:
            Opacity(opacity: 0.3, child: rowContent),
        child: rowContent,
      );
    }
    return rowContent;
  }
}

// ─────────────────────────────────────────────
//  성별 분포 바
// ─────────────────────────────────────────────
class _GenderBar extends StatelessWidget {
  final List<GroupSlot> slots;
  final Color color;
  const _GenderBar({required this.slots, required this.color});

  @override
  Widget build(BuildContext context) {
    final filled = slots.where((s) => s.isFilled).toList();
    final males = filled.where((s) => s.gender == '남').length;
    final females = filled.where((s) => s.gender == '여').length;
    if (filled.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Text('♂ $males',
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryLight)),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  if (males > 0)
                    Flexible(
                      flex: males,
                      child: Container(
                          height: 5, color: AppColors.primaryLight),
                    ),
                  if (females > 0)
                    Flexible(
                      flex: females,
                      child: Container(
                          height: 5, color: const Color(0xFFE91E63)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('♀ $females',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE91E63))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  멤버 선택 바텀시트
// ─────────────────────────────────────────────
class _SlotPickerSheet extends StatelessWidget {
  final int groupNumber;
  final int slotIndex;
  final GroupSlot currentSlot;
  final GroupAssignment assignment;
  final List<AttendanceResponse> attendees;
  final Map<String, Member> memberMap;
  final ValueChanged<GroupSlot> onSelect;
  final VoidCallback onClear;

  const _SlotPickerSheet({
    required this.groupNumber,
    required this.slotIndex,
    required this.currentSlot,
    required this.assignment,
    required this.attendees,
    required this.memberMap,
    required this.onSelect,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final color = _groupColor(groupNumber);

    // 이미 배정된 ID (현재 슬롯 제외)
    final assignedIds = <String>{};
    for (final g in assignment.groups) {
      for (final s in g.slots) {
        if (s.isFilled && s.memberId != currentSlot.memberId) {
          assignedIds.add(s.memberId!);
        }
      }
    }
    final available =
        attendees.where((r) => !assignedIds.contains(r.memberId)).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2)),
          ),

          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.7)],
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Text('$groupNumber',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$groupNumber조 ${slotIndex + 1}번 슬롯',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                if (currentSlot.isFilled)
                  TextButton.icon(
                    onPressed: () {
                      onClear();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.person_remove_outlined,
                        size: 14, color: Colors.red),
                    label: const Text('비우기',
                        style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero),
                  ),
              ],
            ),
          ),

          const Divider(height: 20),

          // 멤버 목록
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: available.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('배정 가능한 멤버가 없습니다',
                        style: TextStyle(color: Color(0xFF90A4AE))),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: available.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 60),
                    itemBuilder: (_, i) {
                      final r = available[i];
                      final m = memberMap[r.memberId];
                      final isCurrent = currentSlot.memberId == r.memberId;
                      final gIcon = m?.gender == '여' ? '♀' : '♂';
                      final gColor = m?.gender == '여'
                          ? const Color(0xFFE91E63)
                          : AppColors.primaryLight;

                      // 이미 다른 조에 배정된 경우 해당 조 번호 표시
                      int? existingGroup;
                      for (final g in assignment.groups) {
                        for (final s in g.slots) {
                          if (s.memberId == r.memberId &&
                              g.groupNumber != groupNumber) {
                            existingGroup = g.groupNumber;
                          }
                        }
                      }

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCurrent
                              ? color.withValues(alpha: 0.15)
                              : const Color(0xFFF0F4F8),
                          child: Text(
                            r.memberName.substring(0, 1),
                            style: TextStyle(
                              color: isCurrent
                                  ? color
                                  : const Color(0xFF607D8B),
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(r.memberName,
                                style: TextStyle(
                                  fontWeight: isCurrent
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 14,
                                )),
                            const SizedBox(width: 5),
                            Text(gIcon,
                                style: TextStyle(
                                    fontSize: 11, color: gColor)),
                            if (existingGroup != null) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _groupColor(existingGroup)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '현 $existingGroup조',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          _groupColor(existingGroup)),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: m?.handicap != null
                            ? Text(
                                '핸디 ${m!.handicap!.toStringAsFixed(0)}  ·  ${m.gender}  ·  ${m.role}',
                                style: const TextStyle(fontSize: 11),
                              )
                            : null,
                        trailing: isCurrent
                            ? Icon(Icons.check_circle_rounded,
                                color: color)
                            : null,
                        onTap: () {
                          onSelect(GroupSlot(
                            memberId: r.memberId,
                            memberName: r.memberName,
                            gender: m?.gender,
                            handicap: m?.handicap,
                          ));
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
