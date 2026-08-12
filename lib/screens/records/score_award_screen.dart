import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/club_model.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';
// import 'score_ocr_screen.dart'; // 비활성 — 사진 자동입력 (결제/AI 연동 후 복구)

// ════════════════════════════════════════════════════════════
//  ScoreAwardScreen — 라운딩 스코어 및 시상 관리
//  · 참석 멤버별 스코어 입력
//  · 시상 항목 커스텀 설정 (메달리스트/롱기스트/니어리스트 등)
//  · 저장 후 기록 탭에 표시
// ════════════════════════════════════════════════════════════
class ScoreAwardScreen extends StatefulWidget {
  final RoundSchedule schedule;
  final int initialTab;
  final AssignGroup? groupFilter;  // null = 전체 참석자
  final int? groupNumber;          // 1-based 조 번호

  const ScoreAwardScreen({
    super.key,
    required this.schedule,
    this.initialTab = 0,
    this.groupFilter,
    this.groupNumber,
  });

  @override
  State<ScoreAwardScreen> createState() => _ScoreAwardScreenState();
}

class _ScoreAwardScreenState extends State<ScoreAwardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // ── 스코어 데이터 (멤버별) ──────────────────────────────
  final Map<String, TextEditingController> _scoreCtrl = {};
  final Map<String, TextEditingController> _handicapCtrl = {};

  // ── 시상 목록 ──────────────────────────────────────────
  final List<_AwardItem> _awards = [
    _AwardItem(id: 'a1', name: '메달리스트', icon: '🥇', allowCustom: true),
    _AwardItem(id: 'a2', name: '니어리스트', icon: '🎯', allowCustom: true),
    _AwardItem(id: 'a3', name: '롱기스트', icon: '🏌️', allowCustom: true),
  ];

  // 실제 참석 멤버 (schedule.responses 기반, 참석 응답자만)
  List<_ScoreMember> _members = [];

  bool _isSaved = false;
  // bool _ocrApplied = false; // OCR 자동입력 적용 여부 (비활성)


  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _buildMembersFromSchedule();
  }

  // ── 참석자 목록 구성 ───────────────────────────────────────
  void _buildMembersFromSchedule() {
    final provider = context.read<ClubProvider>();

    // ── 조 필터가 있으면 해당 조 슬롯 멤버만 사용 ──
    if (widget.groupFilter != null) {
      final group = widget.groupFilter!;
      _members = group.slots
          .where((s) => s.isFilled)
          .map((s) {
            final clubMember = provider.members
                .cast<Member?>()
                .firstWhere((m) => m?.id == s.memberId, orElse: () => null);
            return _ScoreMember(
              id: s.memberId ?? s.memberName ?? '',
              name: s.memberName ?? '?',
              role: clubMember?.role ?? '일반',
            );
          })
          .toList();
    } else {
      // 전체 참석자: 조편성 배정 인원을 우선 (조별로 나뉜 전원)
      final assignment = provider.groupAssignment(widget.schedule.id);
      if (assignment != null) {
        final seen = <String>{};
        final fromGroups = <_ScoreMember>[];
        for (final g in assignment.groups) {
          for (final s in g.slots) {
            if (!s.isFilled) continue;
            final id = s.memberId ?? s.memberName ?? '';
            if (id.isEmpty || seen.contains(id)) continue;
            seen.add(id);
            final clubMember = provider.members
                .cast<Member?>()
                .firstWhere((m) => m?.id == s.memberId, orElse: () => null);
            fromGroups.add(_ScoreMember(
              id: id,
              name: s.memberName ?? '?',
              role: clubMember?.role ?? '일반',
            ));
          }
        }
        if (fromGroups.isNotEmpty) {
          _members = fromGroups;
        }
      }

      // 조편성 없으면 참석 응답 기준
      if (_members.isEmpty) {
        final attendingResponses = widget.schedule.responses
            .where((r) => r.response == '참석')
            .toList();

        if (attendingResponses.isNotEmpty) {
          _members = attendingResponses.map((r) {
            final clubMember = provider.members
                .cast<Member?>()
                .firstWhere((m) => m?.id == r.memberId, orElse: () => null);
            return _ScoreMember(
              id: r.memberId,
              name: r.memberName,
              role: clubMember?.role ?? '일반',
            );
          }).toList();
        } else {
          _members = provider.members
              .map((m) => _ScoreMember(
                    id: m.id,
                    name: m.name,
                    role: m.role,
                  ))
              .toList();
        }
      }
    }

    // 컨트롤러 초기화
    for (final m in _members) {
      _scoreCtrl[m.id] = TextEditingController();
      _handicapCtrl[m.id] = TextEditingController(
          text: provider.members
              .cast<Member?>()
              .firstWhere((mb) => mb?.id == m.id, orElse: () => null)
              ?.handicap
              ?.toStringAsFixed(0) ?? '');
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    for (final c in _scoreCtrl.values) { c.dispose(); }
    for (final c in _handicapCtrl.values) { c.dispose(); }
    super.dispose();
  }

  // ── OCR 스코어카드 인식 (비활성 — score_ocr_screen import 후 복구) ──
  // Future<void> _openOcrScreen() async { ... }

  // ── 메달리스트 자동 계산 (최저 타수) ─────────────────────
  _ScoreMember? get _medallist {
    int? best;
    _ScoreMember? winner;
    for (final m in _members) {
      final score = int.tryParse(_scoreCtrl[m.id]?.text ?? '');
      if (score == null) continue;
      if (best == null || score < best) {
        best = score;
        winner = m;
      }
    }
    return winner;
  }

  // ── 시상 추가 ────────────────────────────────────────────
  void _addAward() {
    final nameCtrl = TextEditingController();
    String selectedIcon = '🏆';
    final icons = ['🏆', '🥇', '🥈', '🥉', '🎯', '🏌️', '⛳', '🎖️', '🌟', '💪'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('시상 항목 추가',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('아이콘 선택',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: icons.map((ic) => GestureDetector(
                  onTap: () => setS(() => selectedIcon = ic),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: selectedIcon == ic
                          ? const Color(0xFF7C3AED).withValues(alpha: 0.12)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: selectedIcon == ic
                          ? Border.all(color: const Color(0xFF7C3AED))
                          : null,
                    ),
                    child: Text(ic, style: const TextStyle(fontSize: 20)),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),
              const Text('시상명', style: TextStyle(fontSize: 12,
                  color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: '예: 버디왕, 파세이브왕',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: const Color(0xFF7C3AED), width: 1.5),
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
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                setState(() {
                  _awards.add(_AwardItem(
                    id: 'a_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameCtrl.text.trim(),
                    icon: selectedIcon,
                    allowCustom: true,
                    winnerIds: const [],
                    winnerNames: const [],
                  ));
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 시상 수상자 선택 (다중 선택 지원) ──────────────────────
  void _selectAwardWinner(int index) {
    final award = _awards[index];
    // 기존 수상자 ID 목록 복사
    final selectedIds = List<String>.from(award.winnerIds);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('${award.icon} ${award.name} 수상자',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1B4B))),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '복수 선택 가능',
                      style: TextStyle(
                          fontSize: 10,
                          color: const Color(0xFF7C3AED),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  controller: scrollCtrl,
                  shrinkWrap: true,
                  itemCount: _members.length,
                  itemBuilder: (_, i) {
                    final m = _members[i];
                    final isSelected = selectedIds.contains(m.id);
                    return GestureDetector(
                      onTap: () {
                        setS(() {
                          if (isSelected) {
                            selectedIds.remove(m.id);
                          } else {
                            selectedIds.add(m.id);
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF7C3AED).withValues(alpha: 0.07)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF7C3AED).withValues(alpha: 0.35)
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            // 체크박스 스타일
                            Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF7C3AED) : Colors.grey.shade400,
                                  width: 1.5,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: isSelected
                                  ? const Color(0xFF7C3AED).withValues(alpha: 0.12)
                                  : Colors.grey.shade200,
                              child: Text(m.name[0],
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? const Color(0xFF7C3AED)
                                          : AppColors.textSecondary)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.name,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? const Color(0xFF7C3AED)
                                              : const Color(0xFF1E1B4B))),
                                  Text(m.role,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            if (_scoreCtrl[m.id]?.text.isNotEmpty == true)
                              Text('${_scoreCtrl[m.id]?.text}타',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              // 선택된 수상자 요약
              if (selectedIds.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '선택됨: ${selectedIds.map((id) => _members.firstWhere((m) => m.id == id, orElse: () => _ScoreMember(id: id, name: '?', role: '')).name).join(', ')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      final winnerNames = selectedIds
                          .map((id) => _members
                              .firstWhere((m) => m.id == id,
                                  orElse: () => _ScoreMember(id: id, name: id, role: ''))
                              .name)
                          .toList();
                      _awards[index] = _AwardItem(
                        id: award.id,
                        name: award.name,
                        icon: award.icon,
                        allowCustom: award.allowCustom,
                        winnerIds: selectedIds,
                        winnerNames: winnerNames,
                        winnerNote: _awards[index].winnerNote,
                      );
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    selectedIds.isEmpty ? '선택 초기화' : '${selectedIds.length}명 확인',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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


  void _saveAll() {
    setState(() => _isSaved = true);

    // ── Provider에 AwardRecord 저장 ──────────────────────
    final provider = context.read<ClubProvider>();
    for (final award in _awards) {
      if (award.hasWinner) {
        final record = AwardRecord(
          id: 'ar_${widget.schedule.id}_${award.id}_${DateTime.now().millisecondsSinceEpoch}',
          scheduleId: widget.schedule.id,
          scheduleName: widget.schedule.displayTitle,
          awardName: award.name,
          awardIcon: award.icon,
          winnerIds: List<String>.from(award.winnerIds),
          winnerNames: List<String>.from(award.winnerNames),
          winnerNote: award.winnerNote,
          recordedAt: DateTime.now(),
        );
        provider.saveAwardRecord(record);
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('스코어 및 시상 결과가 저장되었습니다!'),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // ── AppBar — 흰색 배경, 깔끔한 단색 ──
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Color(0xFF333333), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.groupNumber != null
                  ? '${widget.groupNumber}조 스코어 입력'
                  : '스코어 & 시상',
              style: const TextStyle(
                  color: Color(0xFF999999), fontSize: 11),
            ),
            Text(
              widget.schedule.displayTitle,
              style: const TextStyle(
                  color: Color(0xFF222222),
                  fontSize: 17,
                  fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        titleSpacing: 0,
        actions: [
          TextButton(
            onPressed: _saveAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              backgroundColor: _isSaved
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFF7C3AED).withValues(alpha: 0.10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              minimumSize: const Size(0, 34),
            ),
            child: Text(
              _isSaved ? '저장됨 ✓' : '저장',
              style: TextStyle(
                color: _isSaved
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF7C3AED),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFF7C3AED),
          unselectedLabelColor: const Color(0xFFAAAAAA),
          indicatorColor: const Color(0xFF7C3AED),
          indicatorWeight: 3,
          dividerColor: const Color(0xFFEEEEEE),
          tabs: const [
            Tab(text: '📊 스코어'),
            Tab(text: '🏆 시상'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // ── 탭 1: 스코어 입력 ──────────────────────
          _ScoreTab(
            members: _members,
            scoreCtrl: _scoreCtrl,
            handicapCtrl: _handicapCtrl,
            medallist: _medallist,
          ),
          // ── 탭 2: 시상 관리 ─────────────────────────
          _AwardTab(
            awards: _awards,
            members: _members,
            onAddAward: _addAward,
            onSelectWinner: _selectAwardWinner,
            onDeleteAward: (i) => setState(() => _awards.removeAt(i)),
            onUpdateNote: (i, note) => setState(() {
              final a = _awards[i];
              _awards[i] = _AwardItem(
                id: a.id, name: a.name, icon: a.icon,
                allowCustom: a.allowCustom,
                winnerIds: a.winnerIds,
                winnerNames: a.winnerNames,
                winnerNote: note,
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  스코어 탭
// ════════════════════════════════════════════════════════════
class _ScoreTab extends StatefulWidget {
  final List<_ScoreMember> members;
  final Map<String, TextEditingController> scoreCtrl;
  final Map<String, TextEditingController> handicapCtrl;
  final _ScoreMember? medallist;

  const _ScoreTab({
    required this.members,
    required this.scoreCtrl,
    required this.handicapCtrl,
    required this.medallist,
  });

  @override
  State<_ScoreTab> createState() => _ScoreTabState();
}

class _ScoreTabState extends State<_ScoreTab> {
  bool _sortByScore = false;

  List<_ScoreMember> get _sorted {
    if (!_sortByScore) return widget.members;
    final withScore = widget.members.where(
        (m) => int.tryParse(widget.scoreCtrl[m.id]?.text ?? '') != null).toList()
      ..sort((a, b) =>
          int.parse(widget.scoreCtrl[a.id]!.text)
              .compareTo(int.parse(widget.scoreCtrl[b.id]!.text)));
    final noScore = widget.members.where(
        (m) => int.tryParse(widget.scoreCtrl[m.id]?.text ?? '') == null).toList();
    return [...withScore, ...noScore];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── OCR 버튼 바 (비활성 — 필요 시 주석 해제) ────────────────
        // Container(
        //   color: const Color(0xFFF5F3FF),
        //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        //   child: GestureDetector(
        //     onTap: widget.onOcrTap,
        //     child: Container(
        //       width: double.infinity,
        //       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        //       decoration: BoxDecoration(
        //         color: const Color(0xFF7C3AED).withValues(alpha: 0.07),
        //         borderRadius: BorderRadius.circular(10),
        //         border: Border.all(
        //           color: const Color(0xFF7C3AED).withValues(alpha: 0.20),
        //         ),
        //       ),
        //       child: const Row(
        //         mainAxisAlignment: MainAxisAlignment.center,
        //         children: [
        //           Icon(Icons.document_scanner, size: 16, color: Color(0xFF7C3AED)),
        //           SizedBox(width: 8),
        //           Text('📷 스코어카드 사진으로 자동 입력',
        //               style: TextStyle(
        //                   fontSize: 13,
        //                   fontWeight: FontWeight.w600,
        //                   color: Color(0xFF7C3AED))),
        //         ],
        //       ),
        //     ),
        //   ),
        // ),
        // const Divider(height: 1, color: Color(0xFFE0E0E0)),
        // ── 정렬 & 요약 바 ──────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text('${widget.members.length}명 참석',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: Color(0xFF1E1B4B))),
              const Spacer(),
              if (widget.medallist != null) ...[
                const Icon(Icons.emoji_events, size: 14, color: Colors.amber),
                const SizedBox(width: 4),
                Text('현재 선두: ${widget.medallist!.name}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.amber,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
              ],
              GestureDetector(
                onTap: () => setState(() => _sortByScore = !_sortByScore),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _sortByScore
                        ? const Color(0xFF7C3AED).withValues(alpha: 0.08)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _sortByScore
                          ? const Color(0xFF7C3AED).withValues(alpha: 0.25)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sort,
                          size: 13,
                          color: _sortByScore
                              ? const Color(0xFF7C3AED)
                              : AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('타수 정렬',
                          style: TextStyle(
                              fontSize: 11,
                              color: _sortByScore
                                  ? const Color(0xFF7C3AED)
                                  : AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: _sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final m = _sorted[i];
              final rank = _sortByScore && i < _sorted.length
                  ? (int.tryParse(widget.scoreCtrl[m.id]?.text ?? '') != null
                      ? i + 1 : null)
                  : null;
              return _ScoreCard(
                member: m,
                scoreCtrl: widget.scoreCtrl[m.id]!,
                handicapCtrl: widget.handicapCtrl[m.id]!,
                rank: rank,
                isMedallist: widget.medallist?.id == m.id,
                onChanged: () => setState(() {}),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final _ScoreMember member;
  final TextEditingController scoreCtrl;
  final TextEditingController handicapCtrl;
  final int? rank;
  final bool isMedallist;
  final VoidCallback onChanged;

  const _ScoreCard({
    required this.member,
    required this.scoreCtrl,
    required this.handicapCtrl,
    this.rank,
    required this.isMedallist,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasScore = scoreCtrl.text.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMedallist
              ? Colors.amber.withValues(alpha: 0.5)
              : AppColors.divider,
          width: isMedallist ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── 순위 / 아바타 ────────────────────────────
          SizedBox(
            width: 36,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (rank != null && rank! <= 3)
                  Text(
                    rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉',
                    style: const TextStyle(fontSize: 18),
                  )
                else
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: isMedallist
                        ? Colors.amber.withValues(alpha: 0.2)
                        : const Color(0xFF7C3AED).withValues(alpha: 0.08),
                    child: Text(member.name[0],
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isMedallist
                                ? Colors.amber.shade700
                                : const Color(0xFF7C3AED))),
                  ),
                if (rank != null && rank! > 3)
                  Text('$rank위',
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // ── 이름 / 역할 ─────────────────────────────
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(member.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1B4B))),
                    if (isMedallist) ...[
                      const SizedBox(width: 4),
                      const Text('선두',
                          style: TextStyle(
                              fontSize: 10, color: Colors.amber,
                              fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
                Text(member.role,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // ── 핸디캡 입력 ──────────────────────────────
          SizedBox(
            width: 60,
            child: TextFormField(
              controller: handicapCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'H/C',
                hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: const Color(0xFF7C3AED))),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 8),
          // ── 스코어 입력 ──────────────────────────────
          SizedBox(
            width: 70,
            child: TextFormField(
              controller: scoreCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '타수',
                hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                filled: true,
                fillColor: hasScore
                    ? AppColors.success.withValues(alpha: 0.06)
                    : Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color: hasScore
                            ? AppColors.success.withValues(alpha: 0.3)
                            : Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color: hasScore
                            ? AppColors.success.withValues(alpha: 0.3)
                            : Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: const Color(0xFF7C3AED), width: 1.5)),
                suffixText: hasScore ? '타' : null,
                suffixStyle: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isMedallist ? Colors.amber.shade700 : const Color(0xFF1E1B4B)),
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  시상 탭
// ════════════════════════════════════════════════════════════
class _AwardTab extends StatelessWidget {
  final List<_AwardItem> awards;
  final List<_ScoreMember> members;
  final VoidCallback onAddAward;
  final ValueChanged<int> onSelectWinner;
  final ValueChanged<int> onDeleteAward;
  final void Function(int, String) onUpdateNote;

  const _AwardTab({
    required this.awards,
    required this.members,
    required this.onAddAward,
    required this.onSelectWinner,
    required this.onDeleteAward,
    required this.onUpdateNote,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── 헤더 ──────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text('시상 항목 ${awards.length}개',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: Color(0xFF1E1B4B))),
              const Spacer(),
              GestureDetector(
                onTap: onAddAward,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text('시상 추가',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: awards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🏆',
                          style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      const Text('시상 항목이 없습니다.',
                          style: TextStyle(
                              fontSize: 15, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: onAddAward,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('시상 추가하기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: awards.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _AwardCard(
                    award: awards[i],
                    index: i,
                    onSelectWinner: () => onSelectWinner(i),
                    onDelete: () => onDeleteAward(i),
                    onUpdateNote: (note) => onUpdateNote(i, note),
                  ),
                ),
        ),
      ],
    );
  }
}

class _AwardCard extends StatelessWidget {
  final _AwardItem award;
  final int index;
  final VoidCallback onSelectWinner;
  final VoidCallback onDelete;
  final ValueChanged<String> onUpdateNote;

  const _AwardCard({
    required this.award,
    required this.index,
    required this.onSelectWinner,
    required this.onDelete,
    required this.onUpdateNote,
  });

  @override
  Widget build(BuildContext context) {
    final hasWinner = award.hasWinner;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasWinner
              ? Colors.amber.withValues(alpha: 0.4)
              : AppColors.divider,
          width: hasWinner ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── 헤더 ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: hasWinner
                  ? Colors.amber.withValues(alpha: 0.06)
                  : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Text(award.icon,
                    style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(award.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1B4B))),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: Colors.grey.shade400,
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // ── 수상자 영역 ──────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onSelectWinner,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: hasWinner
                          ? Colors.amber.withValues(alpha: 0.08)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: hasWinner
                            ? Colors.amber.withValues(alpha: 0.3)
                            : AppColors.divider,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (hasWinner)
                          // 다중 수상자 아바타 (최대 3명)
                          SizedBox(
                            width: award.winnerIds.length > 1 ? 44 : 28,
                            height: 28,
                            child: Stack(
                              children: [
                                for (int i = 0; i < award.winnerIds.length.clamp(0, 3); i++)
                                  Positioned(
                                    left: i * 12.0,
                                    child: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.amber.withValues(alpha: 0.2),
                                      child: Text(
                                        award.winnerNames.length > i
                                            ? award.winnerNames[i][0]
                                            : '?',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade700),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        else
                          const Icon(Icons.person_add_alt,
                              size: 20, color: AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasWinner ? award.winnerDisplay : '수상자 선택하기',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: hasWinner
                                      ? FontWeight.bold : FontWeight.normal,
                                  color: hasWinner
                                      ? Colors.amber.shade700
                                      : AppColors.textSecondary,
                                ),
                              ),
                              if (hasWinner && award.winnerIds.length > 1)
                                Text(
                                  '${award.winnerIds.length}명 공동수상',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.amber.shade500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: hasWinner
                              ? Colors.amber.shade400
                              : Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                ),
                if (hasWinner) ...[
                  const SizedBox(height: 10),
                  // 비고 입력
                  TextFormField(
                    initialValue: award.winnerNote,
                    decoration: InputDecoration(
                      hintText: '예: 홀 12번 2m (선택 입력)',
                      hintStyle: TextStyle(
                          fontSize: 11, color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade200)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade200)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: const Color(0xFF7C3AED), width: 1.2)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12),
                    onChanged: onUpdateNote,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  데이터 클래스
// ════════════════════════════════════════════════════════════
class _ScoreMember {
  final String id;
  final String name;
  final String role;
  const _ScoreMember({required this.id, required this.name, required this.role});
}

class _AwardItem {
  final String id;
  final String name;
  final String icon;
  final bool allowCustom;
  final List<String> winnerIds;    // 다중 수상자 ID 목록
  final List<String> winnerNames;  // 다중 수상자 이름 목록
  final String? winnerNote;

  const _AwardItem({
    required this.id,
    required this.name,
    required this.icon,
    this.allowCustom = true,
    this.winnerIds = const [],
    this.winnerNames = const [],
    this.winnerNote,
  });

  bool get hasWinner => winnerIds.isNotEmpty;
  String get winnerDisplay => winnerNames.isEmpty ? '' : winnerNames.join(', ');
  // 구버전 호환용 getter
  String? get winnerId => winnerIds.isEmpty ? null : winnerIds.first;
  String? get winnerName => winnerNames.isEmpty ? null : winnerDisplay;
}
