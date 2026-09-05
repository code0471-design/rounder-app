import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/club_model.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';
import '../../navigation/app_navigator.dart';
import '../../utils/alimtalk_utils.dart';
import '../group_assignment/group_assignment_screen.dart';
import '../records/score_award_screen.dart';
import 'round_photo_widgets.dart';
import '../../widgets/ad_banner.dart';
import '../../widgets/golf_course_field.dart';
import '../../utils/reservation_sms_parser.dart';
import '../../widgets/reservation_sms_fill_banner.dart';

// ════════════════════════════════════════════════════════════
//  보험 관련 상수
// ════════════════════════════════════════════════════════════
const _kInsuranceUrl = 'https://www.google.com'; // TODO: 보험사 API 연동 후 교체
const _kInsurancePrice = '3,900원~';
const _kInsuranceName = '1일 홀인원보험';

// ════════════════════════════════════════════════════════════
//  ScheduleScreen — 일정 탭 (예정 / 지난 일정)
// ════════════════════════════════════════════════════════════
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    // 일정 실시간 동기화 — 다른 기기의 추가·수정이 즉시 반영된다
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ClubProvider>();
      provider.startSchedulesRealtimeSync(provider.selectedClub.id);
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final isAdmin = provider.canCreateSchedule;

        return Scaffold(
          backgroundColor: AppColors.cream,
          body: Column(
            children: [
              // ── 탭바 (디자인: border-bottom 1px) ──
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  border: Border(
                    bottom: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                  ),
                ),
                child: TabBar(
                  controller: _tab,
                  labelColor: const Color(0xFF111827),
                  unselectedLabelColor: AppColors.inkSoft,
                  indicatorColor: AppColors.accent,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                      fontFamily: 'NanumGothic', fontSize: 15,
                      fontWeight: FontWeight.w800),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                  tabs: const [
                    Tab(text: '예정 일정'),
                    Tab(text: '지난 일정'),
                  ],
                ),
              ),
              // ── 탭 컨텐츠 ──
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _ScheduleList(
                        schedules: provider.upcomingSchedules,
                        isPast: false,
                        clubId: provider.selectedClub.id),
                    _ScheduleList(
                        schedules: provider.pastSchedules,
                        isPast: true,
                        clubId: provider.selectedClub.id),
                  ],
                ),
              ),
            ],
          ),
          // ── FAB (관리자만) ──
          floatingActionButton: isAdmin
              ? FloatingActionButton.extended(
                  onPressed: () => showAddScheduleSheet(context, provider),
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('일정 등록',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: Colors.white)),
                )
              : null,
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════
//  일정 등록 바텀시트 열기 — 다른 화면(홈 탭 등)에서도 재사용
// ════════════════════════════════════════════════════════════
void openAddScheduleSheet(BuildContext context, ClubProvider provider) {
  showAddScheduleSheet(context, provider);
}

void showAddScheduleSheet(BuildContext context, ClubProvider provider) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ScheduleFormSheet(provider: provider),
  );
}

// ════════════════════════════════════════════════════════════
//  일정 목록
// ════════════════════════════════════════════════════════════
class _ScheduleList extends StatefulWidget {
  final List<RoundSchedule> schedules;
  final bool isPast;
  final String? clubId;
  const _ScheduleList({required this.schedules, required this.isPast, this.clubId});

  @override
  State<_ScheduleList> createState() => _ScheduleListState();
}

class _ScheduleListState extends State<_ScheduleList> {
  static const _pageSize = 40;
  int _visible = 40;

  List<RoundSchedule> get schedules => widget.schedules;
  bool get isPast => widget.isPast;

  @override
  void didUpdateWidget(covariant _ScheduleList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schedules.length != widget.schedules.length) {
      _visible = isPast ? _pageSize : widget.schedules.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (schedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPast ? Icons.history : Icons.calendar_month_outlined,
              size: 56,
              color: AppColors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              isPast ? '지난 일정이 없습니다' : '예정된 일정이 없습니다',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 15),
            ),
          ],
        ),
      );
    }

    // 광고 배너 OFF (런칭) — AdBanner 복구 금지
    final showAll = !isPast;
    final take = showAll ? schedules.length : _visible.clamp(0, schedules.length);
    final visible = schedules.take(take).toList();
    final hasMore = isPast && take < schedules.length;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async =>
          await Future.delayed(const Duration(milliseconds: 500)),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: visible.length + (hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, i) {
          if (hasMore && i == visible.length) {
            return TextButton(
              onPressed: () => setState(() => _visible += _pageSize),
              child: Text(
                '지난 일정 더 보기 (${schedules.length - take}건)',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            );
          }
          return _ScheduleCard(
            schedule: visible[i],
            isPast: isPast,
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  일정 카드
// ════════════════════════════════════════════════════════════
class _ScheduleCard extends StatelessWidget {
  final RoundSchedule schedule;
  final bool isPast;
  const _ScheduleCard({required this.schedule, required this.isPast});

  @override
  Widget build(BuildContext context) {
    final d = schedule.roundDate;
    final weekday = ['월', '화', '수', '목', '금', '토', '일'][d.weekday - 1];
    final time = schedule.teeTime.trim();
    final dateLine =
        '${d.month}월 ${d.day}일 ($weekday)${time.isNotEmpty ? ' · $time' : ''}';
    final hasNotice =
        schedule.notice != null && schedule.notice!.trim().isNotEmpty;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ScheduleDetailScreen(schedule: schedule))),
      child: Container(
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ScheduleDateTile(date: d, isPast: isPast),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                schedule.displayTitle,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isPast ? AppColors.inkSoft : AppColors.ink,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _ScheduleDdayBadge(
                              label: isPast ? '완료' : schedule.dDayText,
                              isPast: isPast,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dateLine,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.location_on_outlined,
                              size: 13, color: Color(0xFF9CA3AF)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              schedule.courseName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF9CA3AF)),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F7F4),
                border: const Border(
                  top: BorderSide(color: Color(0xFFE5E7EB)),
                ),
                borderRadius: hasNotice
                    ? BorderRadius.zero
                    : const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Consumer<ClubProvider>(
                builder: (_, prov, __) {
                  final latest = prov.schedules.firstWhere(
                    (s) => s.id == schedule.id,
                    orElse: () => schedule,
                  );
                  final regular = prov.regularMembers.length;
                  final guestIds = {
                    for (final m in prov.guestMembers) m.id
                  };
                  final memberIds = {
                    for (final m in prov.activeMembers) m.id
                  };
                  final valid = latest.responses
                      .where((r) => memberIds.contains(r.memberId))
                      .toList();
                  final attend =
                      valid.where((r) => r.response == '참석').length;
                  final decline = valid
                      .where((r) =>
                          r.response == '불참' &&
                          !guestIds.contains(r.memberId))
                      .length;
                  final respondedRegular = valid
                      .where((r) =>
                          (r.response == '참석' || r.response == '불참') &&
                          !guestIds.contains(r.memberId))
                      .map((r) => r.memberId)
                      .toSet();
                  final noRes =
                      (regular - respondedRegular.length).clamp(0, regular);
                  return Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _AttChip2('참석', attend, const Color(0xFF2563EB)),
                            _AttChip2('불참', decline, const Color(0xFFE53935)),
                            _AttChip2('미답변', noRes, const Color(0xFF6B7280)),
                          ],
                        ),
                      ),
                      if (!isPast) ...[
                        const SizedBox(width: 8),
                        _AttendButton(
                          schedule: schedule,
                          currentResponse:
                              prov.myResponse(schedule.id)?.response,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            if (hasNotice)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(
                          color: Colors.black.withValues(alpha: 0.08))),
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16)),
                ),
                child: Row(children: [
                  const Icon(Icons.campaign_outlined,
                      size: 13, color: AppColors.inkSoft),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(schedule.notice!,
                        style: TextStyle(
                            fontSize: 10,
                            color: AppColors.inkSoft.withValues(alpha: 0.65))),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleDateTile extends StatelessWidget {
  final DateTime date;
  final bool isPast;
  const _ScheduleDateTile({required this.date, required this.isPast});

  @override
  Widget build(BuildContext context) {
    final weekday = ['월', '화', '수', '목', '금', '토', '일'][date.weekday - 1];
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isPast ? const Color(0xFFF3F4F6) : const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '${date.month}월',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isPast ? const Color(0xFF9CA3AF) : AppColors.accent,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isPast ? const Color(0xFF6B7280) : Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            weekday,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isPast ? const Color(0xFF9CA3AF) : AppColors.accent,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleDdayBadge extends StatelessWidget {
  final String label;
  final bool isPast;
  const _ScheduleDdayBadge({required this.label, required this.isPast});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPast
            ? const Color(0xFFF3F4F6)
            : const Color(0xFFE53935).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isPast ? AppColors.inkSoft : const Color(0xFFE53935),
        ),
      ),
    );
  }
}

// chip 2 (디자인 사양: go=sage, maybe=amber, no=rose)
class _AttChip2 extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _AttChip2(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

// 참석 요약 칩
class _AttChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color bgColor;
  const _AttChip(this.label, this.count, this.color, this.bgColor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// 참석 응답 버튼
class _AttendButton extends StatelessWidget {
  final RoundSchedule schedule;
  final String? currentResponse;
  const _AttendButton({required this.schedule, this.currentResponse});

  @override
  Widget build(BuildContext context) {
    final responded = currentResponse != null;
    final isAttend = currentResponse == '참석';
    final isDecline = currentResponse == '불참';
    final label = responded ? currentResponse! : '미답변';

    return GestureDetector(
      onTap: () => _showResponseSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isAttend ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: isAttend
              ? null
              : Border.all(
                  color: isDecline
                      ? const Color(0xFFE53935)
                      : const Color(0xFF9CA3AF),
                ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isAttend
                ? Colors.white
                : isDecline
                    ? const Color(0xFFE53935)
                    : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  void _showResponseSheet(BuildContext context) {
    final provider = context.read<ClubProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 핸들
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
            const SizedBox(height: 20),
            Text(
              schedule.title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${schedule.courseName}  ${schedule.teeTime}',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            const Text('참석 여부를 선택해주세요',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                _ResponseBtn(
                  label: '참석',
                  icon: Icons.check_circle_outline,
                  color: AppColors.charcoal,
                  selected: currentResponse == '참석',
                  onTap: () async {
                    final sheetCtx = context;
                    // 마감 여부 체크
                    final cnt = schedule.responses
                        .where((r) => r.response == '참석').length;
                    final maxCap = schedule.maxCapacity ?? 9999;
                    final isFull = cnt >= maxCap && currentResponse != '참석';

                    Navigator.pop(sheetCtx);
                    if (isFull) {
                      _showAttendFullDialog(sheetCtx);
                      return;
                    }
                    final confirmed = await _showAttendConfirmDialog(sheetCtx, '참석');
                    if (confirmed == true) {
                      provider.respondToSchedule(
                          scheduleId: schedule.id, response: '참석');
                      if (sheetCtx.mounted) {
                        ScaffoldMessenger.of(sheetCtx).showSnackBar(
                          _snack('참석이 확정되었습니다 ✅', AppColors.success),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(width: 10),
                _ResponseBtn(
                  label: '미정',
                  icon: Icons.help_outline,
                  color: AppColors.warning,
                  selected: currentResponse == '미정',
                  onTap: () {
                    provider.respondToSchedule(
                        scheduleId: schedule.id, response: '미정');
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      _snack('미정으로 응답했습니다', AppColors.warning),
                    );
                  },
                ),
                const SizedBox(width: 10),
                _ResponseBtn(
                  label: '불참',
                  icon: Icons.cancel_outlined,
                  color: AppColors.danger,
                  selected: currentResponse == '불참',
                  onTap: () async {
                    final sheetCtx = context;
                    Navigator.pop(sheetCtx);
                    final warnTreasurer = currentResponse == '참석' &&
                        (provider.groupAssignment(schedule.id)?.isFinalized ??
                            false);
                    final confirmed = await _showAbsentConfirmDialog(
                      sheetCtx,
                      notifyTreasurer: warnTreasurer,
                    );
                    if (confirmed == true) {
                      provider.respondToSchedule(
                          scheduleId: schedule.id, response: '불참');
                      if (sheetCtx.mounted) {
                        ScaffoldMessenger.of(sheetCtx).showSnackBar(
                          _snack('불참으로 확정되었습니다', AppColors.danger),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 참석 확인 다이얼로그 ──
  Future<bool?> _showAttendConfirmDialog(BuildContext context, String label) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: AppColors.goldDeep, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('참석 확인',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          '모임에 참석하시겠습니까?',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('참석 확정',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 불참 확인 다이얼로그 ──
  Future<bool?> _showAbsentConfirmDialog(
    BuildContext context, {
    bool notifyTreasurer = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel_outlined,
                  color: AppColors.danger, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('불참 확인',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          notifyTreasurer
              ? '조편성이 확정되었기 때문에 불참 변경시 총무에게 알림이 갑니다. 불참으로 변경하시겠습니까?'
              : '이번 모임에 불참하시겠습니까?\n\n참석명단이 마감될 경우 참석으로 변경하면 대기 상태로 등록됩니다.',
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('불참 확정',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 정원 마감 다이얼로그 ──
  void _showAttendFullDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline,
                  color: AppColors.amber, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('정원 마감',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          '이미 정원이 마감된 모임입니다.\n\n대기 상태로 등록되며, 결원 발생 시 자동으로 참석 확정됩니다.',
          style: TextStyle(fontSize: 14, height: 1.6),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.charcoal,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('확인',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  SnackBar _snack(String msg, Color color) => SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      );
}

class _ResponseBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ResponseBtn(
      {required this.label,
      required this.icon,
      required this.color,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? color : color.withValues(alpha: 0.3),
                width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? Colors.white : color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  ScheduleDetailScreen — 일정 상세
// ════════════════════════════════════════════════════════════
class ScheduleDetailScreen extends StatelessWidget {
  final RoundSchedule schedule;
  const ScheduleDetailScreen({super.key, required this.schedule});

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final schedule =
            provider.scheduleById(this.schedule.id) ?? this.schedule;
        final myRes = provider.myResponse(schedule.id);
        // 날짜 기준 자동 판정 — 라운딩 당일 자정이 지나면 자동으로 지난 일정으로 표시됨
        final isPast = schedule.isPast;
        final isAdmin = provider.canCreateSchedule;

        return Scaffold(
          backgroundColor: AppColors.background,
          // ── 슬림 AppBar 웜차콜 카드형 (장소·시간 강조 — 상단 보완) ──
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(128),
            child: ColoredBox(
              color: AppColors.background,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      // 그린은 로고 헤더·하단 탭바 전용. 화면 안은 웜 차콜.
                      colors: [AppColors.charcoalDeep, AppColors.charcoal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.charcoalDeep.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 18),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                schedule.displayTitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppColors.accent
                                          .withValues(alpha: 0.20),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: const Icon(Icons.place_rounded,
                                        color: AppColors.accent, size: 14),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      schedule.courseName.isEmpty
                                          ? '장소 미정'
                                          : schedule.courseName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        height: 1.1,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppColors.accent
                                          .withValues(alpha: 0.20),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: const Icon(Icons.schedule_rounded,
                                        color: AppColors.accent, size: 14),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${_fmtDate(schedule.roundDate)}  ${schedule.teeTime.isEmpty ? '--:--' : schedule.teeTime} 티오프',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        height: 1.1,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isAdmin && !isPast)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            icon: const Icon(Icons.more_vert,
                                color: Colors.white),
                            onPressed: () =>
                                _showAdminMenu(context, provider),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── ① 내 응답 상태 카드 (최상단) ──
                      if (!isPast) _buildMyResponseCard(context, provider, myRes),

                      if (!isPast) const SizedBox(height: 16),

                      // ── ② 홀인원보험 배너 (런칭 광고 OFF — 복구 금지)
                      // if (!isPast) _InsuranceBannerCard(schedule: schedule),
                      // if (!isPast) const SizedBox(height: 16),

                      // ── ③ 조편성 보기 ──
                      _GroupViewBannerCard(
                        schedule: schedule,
                        provider: provider,
                        isAdmin: isAdmin,
                      ),

                      const SizedBox(height: 16),

                      // ── 참석 현황 카드 (스코어/시상 위) ──
                      _AttendanceCard(schedule: schedule),

                      const SizedBox(height: 16),

                      // ── RSVP 마감 안내 + 대기 명단 (정원 초과 자동 승격) ──
                      _RsvpWaitingCard(schedule: schedule, isAdmin: isAdmin),

                      const SizedBox(height: 16),

                      // ── ④ 스코어/시상 카드 ──
                      _ScoreAwardBannerCard(schedule: schedule, isPast: isPast),

                      const SizedBox(height: 16),

                      // ── 일정 정보 카드 ──
                      _InfoCard(schedule: schedule),

                      const SizedBox(height: 16),

                      // ── 사진 섹션 (항상 업로드 가능) ──
                      _PhotoSection(schedule: schedule),

                      const SizedBox(height: 16),

                      // ── 라운딩 후기/메모 (지난 일정이 되어도 언제든 열람·수정 가능) ──
                      _ReviewMemoCard(schedule: schedule),

                      const SizedBox(height: 16),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
          ),
        );
      },
    );
  }

  Widget _buildMyResponseCard(
      BuildContext context, ClubProvider provider, AttendanceResponse? myRes) {
    final responded = myRes != null;
    final currentResponse = myRes?.response;
    final statusColor = !responded
        ? AppColors.textTertiary
        : currentResponse == '참석'
            ? AppColors.goldDeep
            : currentResponse == '불참'
                ? AppColors.danger
                : AppColors.textTertiary;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              responded
                  ? (currentResponse == '참석'
                      ? Icons.check_circle
                      : currentResponse == '불참'
                          ? Icons.cancel
                          : Icons.help)
                  : Icons.check_circle_outline,
              color: statusColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '내 응답',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                (!responded || currentResponse == '미정')
                    ? '미응답'
                    : currentResponse!,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: ['참석', '불참'].map((label) {
              final isSelected = currentResponse == label;
              final btnColor =
                  label == '참석' ? AppColors.charcoal : AppColors.danger;
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onTap: () async {
                    if (label == '참석') {
                      final cnt = schedule.responses
                          .where((r) => r.response == '참석')
                          .length;
                      final maxCap = schedule.maxCapacity ?? 9999;
                      if (cnt >= maxCap && currentResponse != '참석') {
                        _showAttendFullDialogCard(context);
                        return;
                      }
                      final ok = await _showAttendConfirmDialogCard(context);
                      if (ok == true) {
                        provider.respondToSchedule(
                            scheduleId: schedule.id, response: label);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('참석이 확정되었습니다'),
                              backgroundColor: AppColors.charcoal,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                      return;
                    } else if (label == '불참') {
                      final warnTreasurer = currentResponse == '참석' &&
                          (provider.groupAssignment(schedule.id)?.isFinalized ??
                              false);
                      final ok = await _showAbsentConfirmDialogCard(
                        context,
                        notifyTreasurer: warnTreasurer,
                      );
                      if (ok == true) {
                        provider.respondToSchedule(
                            scheduleId: schedule.id, response: label);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('불참으로 확정되었습니다'),
                              backgroundColor: AppColors.danger,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                      return;
                    }
                    provider.respondToSchedule(
                        scheduleId: schedule.id, response: label);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? btnColor : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isSelected ? btnColor : AppColors.divider,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showResponseSheet(
      BuildContext context, ClubProvider provider, String? current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('참석 여부를 선택해주세요',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                _ResponseBtn(
                  label: '참석',
                  icon: Icons.check_circle_outline,
                  color: AppColors.charcoal,
                  selected: current == '참석',
                  onTap: () {
                    // 정원 체크: 확정 참석자 수 vs 최대 정원
                    final confirmed = schedule.responses
                        .where((r) => r.response == '참석')
                        .length;
                    final maxCap = schedule.maxCapacity ?? 9999;
                    if (confirmed >= maxCap && current != '참석') {
                      // 이미 정원 초과 → 대기 등록 다이얼로그
                      Navigator.pop(context);
                      _showWaitingDialog(context, provider);
                    } else {
                      provider.respondToSchedule(
                          scheduleId: schedule.id, response: '참석');
                      Navigator.pop(context);
                    }
                  },
                ),
                const SizedBox(width: 10),
                _ResponseBtn(
                  label: '미정',
                  icon: Icons.help_outline,
                  color: AppColors.warning,
                  selected: current == '미정',
                  onTap: () {
                    provider.respondToSchedule(
                        scheduleId: schedule.id, response: '미정');
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 10),
                _ResponseBtn(
                  label: '불참',
                  icon: Icons.cancel_outlined,
                  color: AppColors.danger,
                  selected: current == '불참',
                  onTap: () {
                    provider.respondToSchedule(
                        scheduleId: schedule.id, response: '불참');
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── _AttendanceCard 전용 참석 확인 다이얼로그 ──
  Future<bool?> _showAttendConfirmDialogCard(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: AppColors.goldDeep, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('참석 확인',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          '모임에 참석하시겠습니까?',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('취소'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.charcoal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('참석 확정',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── _AttendanceCard 전용 불참 확인 다이얼로그 ──
  Future<bool?> _showAbsentConfirmDialogCard(
    BuildContext context, {
    bool notifyTreasurer = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel_outlined,
                  color: AppColors.danger, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('불참 확인',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          notifyTreasurer
              ? '조편성이 확정되었기 때문에 불참 변경시 총무에게 알림이 갑니다. 불참으로 변경하시겠습니까?'
              : '이번 모임에 불참하시겠습니까?\n\n참석명단이 마감될 경우 참석으로 변경하면 대기 상태로 등록됩니다.',
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('취소'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('불참 확정',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── _AttendanceCard 전용 정원 마감 다이얼로그 ──
  void _showAttendFullDialogCard(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline,
                  color: AppColors.amber, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('정원 마감',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          '이미 정원이 마감된 모임입니다.\n\n대기 상태로 등록되며, 결원 발생 시 자동으로 참석 확정됩니다.',
          style: TextStyle(fontSize: 14, height: 1.6),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.charcoal,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('확인',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────
  // 대기 등록 다이얼로그
  // ────────────────────────────────
  void _showWaitingDialog(BuildContext context, ClubProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top_rounded,
                  color: AppColors.warning, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('정원 마감', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.6),
                children: [
                  const TextSpan(text: '이 라운딩은 '),
                  TextSpan(
                    text: '정원이 마감',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.danger),
                  ),
                  const TextSpan(text: '되었습니다.\n\n'),
                  const TextSpan(text: '대기 명단에 등록하면 자리가 생길 때 알림을 드립니다. '),
                  TextSpan(
                    text: '(12시간 내 수락 필요)',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppColors.warning),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      '취소자 발생 시 대기 순서대로 알림이 발송됩니다',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final currentMember = provider.currentMember;
              if (currentMember != null) {
                provider.addToWaitingList(
                  scheduleId: schedule.id,
                  memberId: currentMember.id,
                  memberName: currentMember.name,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text('대기 명단에 등록되었습니다!'),
                      ],
                    ),
                    backgroundColor: AppColors.warning,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('대기 등록', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAdminMenu(BuildContext context, ClubProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined,
                  color: AppColors.goldDeep),
              title: const Text('일정 변경'),
              subtitle: const Text('날짜·시간·장소 등 수정',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              onTap: () {
                Navigator.pop(context);
                _openEditSchedule(context, provider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined, color: AppColors.danger),
              title: const Text('일정 취소',
                  style: TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(context);
                _confirmCancel(context, provider);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openEditSchedule(BuildContext context, ClubProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScheduleFormSheet(
        provider: provider,
        editTarget: schedule,
      ),
    );
  }

  void _confirmCancel(BuildContext context, ClubProvider provider) {
    // 취소하면 이 일정의 사진도 함께 지운다. 되돌릴 수 없으니 장수를 먼저 알린다.
    final photoCount = provider.schedulePhotoCount(schedule.id);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('일정 취소'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${schedule.title} 일정을 취소하시겠습니까?'),
            if (photoCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 18, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '이 일정의 사진 $photoCount장도 함께 삭제됩니다.\n'
                        '삭제한 사진은 되돌릴 수 없습니다.',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('닫기'),
          ),
          ElevatedButton(
            onPressed: () {
              final parentNav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(dialogCtx).pop();
              final purged = provider.cancelSchedule(schedule.id);
              if (parentNav.canPop()) parentNav.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(purged > 0
                      ? '일정을 취소하고 사진 $purged장을 삭제했습니다'
                      : '일정을 취소했습니다'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white),
            child: const Text('취소 확정'),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.month}월 ${d.day}일 (${['월', '화', '수', '목', '금', '토', '일'][d.weekday - 1]})';
}

// ── 일정 정보 카드 ──
class _InfoCard extends StatelessWidget {
  final RoundSchedule schedule;
  const _InfoCard({required this.schedule});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('일정 정보',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          const SizedBox(height: 12),
          _InfoRow(Icons.golf_course_rounded, '골프장', schedule.courseName),
          if (schedule.courseAddress != null)
            _InfoRow(Icons.place_rounded, '주소',
                schedule.courseAddress!),
          _InfoRow(Icons.schedule_rounded, '티오프', schedule.teeTime),
          _InfoRow(Icons.groups_rounded, '팀 수', '${schedule.teamCount}팀'),
          if (schedule.companionIds.isNotEmpty)
            _InfoRow(Icons.people_alt_rounded, '동반자',
                _companionNames(context, schedule.companionIds)),
          if (schedule.notice != null && schedule.notice!.isNotEmpty)
            _InfoRow(Icons.campaign_rounded, '메모', schedule.notice!),
          _InfoRow(Icons.person_rounded, '등록자', schedule.createdBy),
        ],
      ),
    );
  }

  String _companionNames(BuildContext context, List<String> ids) {
    final provider = context.read<ClubProvider>();
    return ids
        .map((id) => provider.members
            .cast<Member?>()
            .firstWhere((m) => m?.id == id, orElse: () => null)
            ?.name ?? id)
        .join(', ');
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 56,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                      color: AppColors.ink)),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  라운딩 후기 · 메모 카드
//  · 지난 일정으로 넘어간 뒤에도 언제든 열람·수정 가능 (제한 없음)
//  · 저장 즉시 Firestore에 반영되어 다른 회원도 실시간으로 확인 가능
// ════════════════════════════════════════════════════════════
class _ReviewMemoCard extends StatefulWidget {
  final RoundSchedule schedule;
  const _ReviewMemoCard({required this.schedule});

  @override
  State<_ReviewMemoCard> createState() => _ReviewMemoCardState();
}

class _ReviewMemoCardState extends State<_ReviewMemoCard> {
  late TextEditingController _ctrl;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.schedule.reviewMemo ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save(ClubProvider provider) async {
    setState(() => _saving = true);
    provider.saveReviewMemo(widget.schedule.id, _ctrl.text.trim());
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      setState(() {
        _saving = false;
        _editing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('후기가 저장되었습니다 📝'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final latest = provider.schedules.firstWhere(
          (s) => s.id == widget.schedule.id,
          orElse: () => widget.schedule,
        );
        if (!_editing && _ctrl.text != (latest.reviewMemo ?? '') && !_saving) {
          _ctrl.text = latest.reviewMemo ?? '';
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_note_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  const Text('라운딩 후기 · 메모',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                  const Spacer(),
                  if (!_editing)
                    TextButton(
                      onPressed: () => setState(() => _editing = true),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4)),
                      child: Text(
                        latest.reviewMemo == null || latest.reviewMemo!.isEmpty
                            ? '작성하기'
                            : '수정',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (_editing) ...[
                TextField(
                  controller: _ctrl,
                  maxLines: 4,
                  minLines: 3,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '오늘 라운딩은 어땠나요? 후기나 메모를 남겨보세요',
                    hintStyle: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _saving
                            ? null
                            : () => setState(() {
                                  _editing = false;
                                  _ctrl.text = latest.reviewMemo ?? '';
                                }),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : () => _save(provider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('저장'),
                      ),
                    ),
                  ],
                ),
              ] else
                Text(
                  latest.reviewMemo == null || latest.reviewMemo!.isEmpty
                      ? '아직 작성된 후기가 없습니다. 스코어와 함께 그날의 기억을 남겨보세요.'
                      : latest.reviewMemo!,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: latest.reviewMemo == null || latest.reviewMemo!.isEmpty
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    fontStyle:
                        latest.reviewMemo == null || latest.reviewMemo!.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════
//  RSVP 마감 안내 + 대기 명단(정원 초과 자동 승격) 카드
//  · 마감시간이 지나면 미응답자 알림이 자동 발송된다 (관리자는 즉시 재발송 가능)
//  · 정원 초과로 대기 등록된 인원은 자리가 나면 순서대로 자동 알림을 받고,
//    12시간 내 수락하지 않으면 자동으로 다음 대기자에게 순번이 넘어간다
// ════════════════════════════════════════════════════════════
class _RsvpWaitingCard extends StatefulWidget {
  final RoundSchedule schedule;
  final bool isAdmin;
  const _RsvpWaitingCard({required this.schedule, required this.isAdmin});

  @override
  State<_RsvpWaitingCard> createState() => _RsvpWaitingCardState();
}

class _RsvpWaitingCardState extends State<_RsvpWaitingCard> {
  @override
  void initState() {
    super.initState();
    final provider = context.read<ClubProvider>();
    provider.syncWaitingListFromFirestore(widget.schedule.id);
    provider.startWaitingListRealtimeSync(widget.schedule.id);
  }

  @override
  void dispose() {
    context.read<ClubProvider>().stopWaitingListRealtimeSync(widget.schedule.id);
    super.dispose();
  }

  Color _waitingStatusColor(WaitingStatus s) {
    switch (s) {
      case WaitingStatus.waiting:   return AppColors.textSecondary;
      case WaitingStatus.notified:  return AppColors.warning;
      case WaitingStatus.accepted:  return AppColors.goldDeep;
      case WaitingStatus.expired:   return AppColors.danger;
      case WaitingStatus.cancelled: return AppColors.textSecondary;
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.month}월 ${d.day}일 (${['월', '화', '수', '목', '금', '토', '일'][d.weekday - 1]})';

  SnackBar _snack(String message, Color color) {
    return SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final schedule = provider.scheduleById(widget.schedule.id) ?? widget.schedule;
        final hasDeadline = schedule.rsvpDeadline != null;
        final hasCapacity = schedule.maxCapacity != null;
        if (!hasDeadline && !hasCapacity) return const SizedBox.shrink();

        final nonResponders = provider.nonRespondersFor(schedule.id);
        final waitList = provider.waitingListForSchedule(schedule.id)
            .where((w) => w.status != WaitingStatus.cancelled)
            .toList();
        final myEntry = provider.myWaitingEntry(schedule.id);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── RSVP 마감시간 안내 ──
            if (hasDeadline)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                            schedule.isRsvpClosed
                                ? Icons.lock_clock_rounded
                                : Icons.timer_rounded,
                            size: 18,
                            color: schedule.isRsvpClosed
                                ? AppColors.danger
                                : AppColors.goldDeep),
                        const SizedBox(width: 6),
                        Text('참석 응답 마감',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink)),
                        const Spacer(),
                        Text(
                          schedule.isRsvpClosed ? '마감됨' : '진행중',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: schedule.isRsvpClosed
                                  ? AppColors.danger
                                  : AppColors.goldDeep),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_fmtDate(schedule.rsvpDeadline!)} '
                      '${schedule.rsvpDeadline!.hour.toString().padLeft(2, '0')}:'
                      '${schedule.rsvpDeadline!.minute.toString().padLeft(2, '0')}까지',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    if (widget.isAdmin && nonResponders.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '미응답 ${nonResponders.length}명',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.warning,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              final sent = provider.notifyNonResponders(schedule.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('미응답자 $sent명에게 알림을 보냈습니다 🔔'),
                                  backgroundColor: AppColors.charcoal,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                            icon: const Icon(Icons.notifications_active_rounded, size: 16),
                            label: const Text('알림 보내기',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.goldDeep,
                                padding: const EdgeInsets.symmetric(horizontal: 4)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

            // ── 대기 명단 (정원 설정된 일정만 표시) ──
            if (hasCapacity)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.hourglass_top_rounded,
                            size: 18, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Text('대기 명단 (정원 ${schedule.maxCapacity}명)',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink)),
                        const Spacer(),
                        Text('${waitList.length}명',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                    // ── 내가 자리 제안(알림)을 받은 경우 — 수락/거절 배너 ──
                    if (myEntry != null && myEntry.status == WaitingStatus.notified) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('🎉 자리가 났습니다! 지금 수락하시겠어요?',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 4),
                            Text(
                              '${kWaitingAcceptWindow.inHours}시간 내 수락하지 않으면 다음 대기자에게 순번이 넘어갑니다',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      provider.respondToWaitingOffer(myEntry.id, accept: false);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        _snack('대기를 거절했습니다', AppColors.textSecondary),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.textSecondary),
                                    child: const Text('거절'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      provider.respondToWaitingOffer(myEntry.id, accept: true);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        _snack('참석이 확정되었습니다 ✅', AppColors.charcoal),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.charcoal,
                                        foregroundColor: Colors.white),
                                    child: const Text('수락'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (waitList.isEmpty) ...[
                      const SizedBox(height: 10),
                      const Text('대기 등록된 회원이 없습니다',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ] else ...[
                      const SizedBox(height: 10),
                      ...waitList.asMap().entries.map((entry) {
                        final i = entry.key;
                        final w = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 22, height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  shape: BoxShape.circle,
                                ),
                                child: Text('${i + 1}',
                                    style: const TextStyle(
                                        fontSize: 11, fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(w.memberName,
                                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                              ),
                              Text(w.statusLabel,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _waitingStatusColor(w.status))),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── 참석 현황 카드 (Consumer로 실시간 반영) ──
class _AttendanceCard extends StatelessWidget {
  final RoundSchedule schedule;
  const _AttendanceCard({required this.schedule});

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        // provider에서 최신 schedule 가져오기
        final latest = provider.schedules.firstWhere(
          (s) => s.id == schedule.id,
          orElse: () => schedule,
        );
        final memberIds = {for (final m in provider.activeMembers) m.id};
        final guestIds = {for (final m in provider.guestMembers) m.id};
        final responses = latest.responses
            .where((r) => memberIds.contains(r.memberId))
            .toList();
        final confirmed = responses.where((r) => r.response == '참석').toList();
        final declined  = responses
            .where((r) => r.response == '불참' && !guestIds.contains(r.memberId))
            .toList();
        final respondedRegular = {
          ...confirmed.where((r) => !guestIds.contains(r.memberId)).map((r) => r.memberId),
          ...declined.map((r) => r.memberId),
        };
        final noResponse = provider.regularMembers
            .where((m) => !respondedRegular.contains(m.id))
            .length;
        final total = provider.regularMembers.length;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Container(
                      width: 4, height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('참석 현황',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink)),
                    const Spacer(),
                    Text('정회원 $total명',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              // 3개 통계
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    _StatItem(count: confirmed.length, label: '참석', color: AppColors.goldDeep),
                    _Divider(),
                    _StatItem(count: noResponse, label: '미답변', color: AppColors.textSecondary),
                    _Divider(),
                    _StatItem(count: declined.length,  label: '불참', color: AppColors.danger),
                  ],
                ),
              ),
              // 구분선
              if (total > 0)
                Divider(height: 1, color: Colors.black.withValues(alpha: 0.06)),
              // ── 참석 명단 직접 표시 ──
              if (confirmed.isNotEmpty) ...[
                _MemberListSection(label: '참석', color: AppColors.goldDeep, members: confirmed),
              ],

              if (declined.isNotEmpty) ...[
                _MemberListSection(label: '불참', color: AppColors.danger, members: declined),
              ],
              if (total == 0)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Text('아직 응답한 멤버가 없습니다.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

// ── 명단 섹션 ──
class _MemberListSection extends StatelessWidget {
  final String label;
  final Color color;
  final List<AttendanceResponse> members;
  const _MemberListSection({
    required this.label,
    required this.color,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 라벨
          Row(
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color)),
              const SizedBox(width: 4),
              Text('${members.length}명',
                  style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7))),
            ],
          ),
          const SizedBox(height: 8),
          // 멤버 아바타 + 이름 리스트
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: members.map((m) => _MemberChip(member: m, color: color)).toList(),
          ),
        ],
      ),
    );
  }
}

// ── 멤버 칩 ──
class _MemberChip extends StatelessWidget {
  final AttendanceResponse member;
  final Color color;
  const _MemberChip({required this.member, required this.color});

  @override
  Widget build(BuildContext context) {
    final initials = member.memberName.isNotEmpty
        ? member.memberName.substring(0, 1)
        : '?';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(initials,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ),
        ),
        const SizedBox(width: 5),
        Text(member.memberName,
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary)),
      ],
    );
  }
}

// 세련된 통계 아이템 (배경색 없이 숫자+라벨)
class _StatItem extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _StatItem({
    required this.count,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count명',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.divider,
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryBadge(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$label $count',
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _ResponseSection extends StatelessWidget {
  final String title;
  final List<AttendanceResponse> items;
  final Color color;
  const _ResponseSection(this.title, this.items, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Text(title,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ),
        ...items.map((r) => ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Text(
                  r.memberName.isNotEmpty ? r.memberName[0] : '?',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color),
                ),
              ),
              title: Text(r.memberName,
                  style: const TextStyle(fontSize: 13)),
              subtitle: r.memo != null && r.memo!.isNotEmpty
                  ? Text(r.memo!,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary))
                  : null,
            )),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
//  일정 등록 폼 (바텀시트)
// ════════════════════════════════════════════════════════════
class _ScheduleFormSheet extends StatefulWidget {
  final ClubProvider provider;
  final RoundSchedule? editTarget;
  const _ScheduleFormSheet({required this.provider, this.editTarget});

  @override
  State<_ScheduleFormSheet> createState() => _ScheduleFormSheetState();
}

class _ScheduleFormSheetState extends State<_ScheduleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _courseCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _noticeCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay _teeTime = const TimeOfDay(hour: 7, minute: 30);
  late int _teamCount;
  bool _saving = false;

  bool get _isEdit => widget.editTarget != null;

  @override
  void initState() {
    super.initState();
    final edit = widget.editTarget;
    if (edit != null) {
      _titleCtrl.text = edit.title;
      _courseCtrl.text = edit.courseName;
      _addressCtrl.text = edit.courseAddress ?? '';
      _noticeCtrl.text = edit.notice ?? '';
      _selectedDate = edit.roundDate;
      final parts = edit.teeTime.split(':');
      final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 7;
      final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 30;
      _teeTime = TimeOfDay(hour: h, minute: m);
      _teamCount = edit.teamCount.clamp(1, 30);
      _capacityCtrl.text = '${_teamCount * 4}';
    } else {
      final clubTeams = widget.provider.selectedClub.teamCount;
      _teamCount = clubTeams > 0 ? clubTeams : 1;
      _capacityCtrl.text = '${_teamCount * 4}';
    }
  }


  void _applyReservationParse(ReservationSmsParse parsed) {
    setState(() {
      if (parsed.date != null) _selectedDate = parsed.date;
      if (parsed.hour != null) {
        _teeTime = TimeOfDay(
          hour: parsed.hour!,
          minute: parsed.minute ?? 0,
        );
      }
      if (parsed.courseName != null && parsed.courseName!.trim().isNotEmpty) {
        _courseCtrl.text = parsed.courseName!.trim();
      }
      if (parsed.address != null && parsed.address!.trim().isNotEmpty) {
        _addressCtrl.text = parsed.address!.trim();
      }
      if (_titleCtrl.text.trim().isEmpty &&
          parsed.titleHint != null &&
          parsed.titleHint!.trim().isNotEmpty) {
        _titleCtrl.text = parsed.titleHint!.trim();
      }
      if (parsed.teamCount != null) {
        _teamCount = parsed.teamCount!;
        _capacityCtrl.text = '${_teamCount * 4}';
      }
    });
    final bits = <String>[];
    if (parsed.date != null) bits.add('날짜');
    if (parsed.hour != null) bits.add('시간');
    if (parsed.courseName != null && parsed.courseName!.trim().isNotEmpty) {
      bits.add('골프장');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${bits.join(' · ')}을 채웠습니다. 확인하고 등록하세요.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _setTeamCount(int next) {
    if (next < 1 || next > 30) return;
    setState(() {
      _teamCount = next;
      _capacityCtrl.text = '${next * 4}';
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _courseCtrl.dispose();
    _addressCtrl.dispose();
    _noticeCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // 핸들 + 헤더
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: AppColors.divider)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(_isEdit ? '일정 변경' : '일정 등록',
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('취소'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 폼 내용
              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (!_isEdit)
                      ReservationSmsFillBanner(
                        extras: golfCoursesFromSchedules(widget.provider.schedules),
                        onFilled: _applyReservationParse,
                      ),
                    // 일정 제목
                    _FormField(
                      label: '일정 제목 *',
                      child: TextFormField(
                        controller: _titleCtrl,
                        decoration: _deco('예: 7월 월례회'),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? '제목을 입력하세요' : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 날짜 선택
                    _FormField(
                      label: '라운딩 날짜 *',
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFDDDDDD)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month_outlined,
                                  size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                _selectedDate == null
                                    ? '날짜를 선택하세요'
                                    : _fmtDate(_selectedDate!),
                                style: TextStyle(
                                  color: _selectedDate == null
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 티오프 시간
                    _FormField(
                      label: '티오프 시간 *',
                      child: GestureDetector(
                        onTap: _pickTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFDDDDDD)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time,
                                  size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                _teeTime.format(context),
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 골프장 이름 — 입력 시 목록에서 고르면 주소가 따라옴
                    _FormField(
                      label: '골프장 이름 *',
                      child: GolfCourseNameField(
                        courseController: _courseCtrl,
                        addressController: _addressCtrl,
                        extras: golfCoursesFromSchedules(widget.provider.schedules),
                        decoration: _deco('골프장 이름 입력'),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? '골프장을 입력하세요' : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 주소 (선택)
                    _FormField(
                      label: '주소 (선택)',
                      child: TextFormField(
                        controller: _addressCtrl,
                        decoration: _deco('예: 경기도 용인시 처인구'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 팀 수
                    _FormField(
                      label: '팀 수',
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _teamCount > 1
                                ? () => _setTeamCount(_teamCount - 1)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline,
                                color: AppColors.primary),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.divider),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$_teamCount팀',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _setTeamCount(_teamCount + 1),
                            icon: const Icon(Icons.add_circle_outline,
                                color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 정원 = 팀수×4 (자동). 초과 시 대기 등록
                    _FormField(
                      label: '정원 (팀수 × 4 · 초과 시 자동 대기등록)',
                      child: TextFormField(
                        controller: _capacityCtrl,
                        keyboardType: TextInputType.number,
                        readOnly: true,
                        decoration: _deco('팀수 × 4'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 공지 · 메모 (선택)
                    _FormField(
                      label: '메모 (선택)',
                      child: TextFormField(
                        controller: _noticeCtrl,
                        decoration: _deco('복장 규정, 준비물 등'),
                        maxLines: 3,
                        minLines: 2,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 저장 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(_isEdit ? '변경 저장' : '일정 등록',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final initial = _selectedDate ?? DateTime.now().add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(DateTime.now()) ? DateTime.now() : initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ko', 'KR'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _teeTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _teeTime = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('날짜를 선택해주세요')),
      );
      return;
    }

    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 400));

    final teeStr =
        '${_teeTime.hour.toString().padLeft(2, '0')}:${_teeTime.minute.toString().padLeft(2, '0')}';

    final notice = _noticeCtrl.text.trim().isEmpty
        ? null
        : _noticeCtrl.text.trim();
    final address = _addressCtrl.text.trim().isEmpty
        ? null
        : _addressCtrl.text.trim();

    if (_isEdit) {
      final original = widget.editTarget!;
      final updated = original.copyWith(
        title: _titleCtrl.text.trim(),
        roundDate: _selectedDate!,
        teeTime: teeStr,
        courseName: _courseCtrl.text.trim(),
        courseAddress: address,
        teamCount: _teamCount,
        maxCapacity: _teamCount * 4,
        notice: notice,
      );
      final provider = widget.provider;
      final materialChanged = provider.updateSchedule(updated);
      setState(() => _saving = false);
      if (mounted) Navigator.pop(context);
      final messenger = AppNavigator.context != null
          ? ScaffoldMessenger.maybeOf(AppNavigator.context!)
          : null;
      messenger?.showSnackBar(
        SnackBar(
          content: Text('${updated.title} 일정이 변경되었습니다'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
      final settings =
          provider.alimtalkSettingsOf(provider.selectedClub.id);
      // 제목·공지만 바뀐 경우 재참석 알림톡 생략
      if (materialChanged && settings.promptOnScheduleChange) {
        await Future.delayed(const Duration(milliseconds: 300));
        await AlimtalkUtils.runScheduleChangeFlow(
          provider: provider,
          schedule: updated,
        );
      }
      return;
    }

    // 일정 등록 시 자동 참석 금지 — 전원 미답변으로 시작
    final schedule = RoundSchedule(
      id: 'sched_${DateTime.now().millisecondsSinceEpoch}',
      clubId: widget.provider.selectedClub.id,
      title: _titleCtrl.text.trim(),
      roundDate: _selectedDate!,
      teeTime: teeStr,
      courseName: _courseCtrl.text.trim(),
      courseAddress: address,
      teamCount: _teamCount,
      maxCapacity: _teamCount * 4,
      notice: notice,
      createdBy: widget.provider.currentUserName,
      responses: const [],
      companionIds: const [],
    );

    final provider = widget.provider;
    provider.addSchedule(schedule);

    if (mounted) Navigator.pop(context);
    final messenger = AppNavigator.context != null
        ? ScaffoldMessenger.maybeOf(AppNavigator.context!)
        : null;
    messenger?.showSnackBar(
      SnackBar(
        content: Text('${schedule.title} 일정이 등록되었습니다 🗓️'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 400));
    await AlimtalkUtils.runAttendanceFlow(
      provider: provider,
      schedule: schedule,
    );
  }

  /// 일정 등록 후 알림톡 발송 다이얼로그
  void _showAlimtalkDialog({
    required BuildContext context,
    required ClubProvider provider,
    required String scheduleId,
    required String scheduleTitle,
    required DateTime roundDate,
  }) {
    final dateStr =
        '${roundDate.month}월 ${roundDate.day}일 (${['월','화','수','목','금','토','일'][roundDate.weekday-1]})';
    final memberCount = provider.members.where((m) =>
        m.status == '활성').length;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.charcoal.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.send_rounded, color: AppColors.charcoal, size: 20),
          ),
          const SizedBox(width: 10),
          const Text('알림톡 보내기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('회원 $memberCount명에게 참석여부 요청을 보낼까요?',
                style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F9F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.charcoal.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.golf_course_rounded, size: 14, color: AppColors.charcoal),
                    const SizedBox(width: 6),
                    Text(provider.selectedClub.name,
                        style: TextStyle(fontSize: 11, color: AppColors.charcoal,
                            fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    '[$dateStr]\n$scheduleTitle 일정이 등록됐습니다.\n참석여부를 앱에서 알려주세요!',
                    style: const TextStyle(fontSize: 13, height: 1.55, color: Color(0xFF333333)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('나중에', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final memberIds = provider.members
                  .where((m) =>
                      m.status == '활성')
                  .map((m) => m.id)
                  .toList();
              final sent = provider.sendScheduleAlimtalk(
                scheduleId: scheduleId,
                memberIds: memberIds,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(children: [
                    const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text('$sent명에게 알림톡을 보냈습니다 ✉️'),
                  ]),
                  backgroundColor: AppColors.charcoal,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('보내기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.charcoal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            color: AppColors.textSecondary, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  String _fmtDate(DateTime d) =>
      '${d.year}년 ${d.month}월 ${d.day}일 (${['월', '화', '수', '목', '금', '토', '일'][d.weekday - 1]})';
}

class _FormField extends StatelessWidget {
  final String label;
  final Widget child;
  const _FormField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
//  보험 배너 카드 (일정 상세 화면용)
// ════════════════════════════════════════════════════════════
class _InsuranceBannerCard extends StatelessWidget {
  final RoundSchedule schedule;
  const _InsuranceBannerCard({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final days = schedule.daysUntil;
    final isUrgent = days <= 1; // D-1 또는 D-Day

    return GestureDetector(
      onTap: () => _InsuranceSheet.show(context, schedule),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 배경 장식 원
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              right: 30,
              bottom: -30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            // 컨텐츠
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 아이콘
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text('⛳', style: TextStyle(fontSize: 26)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // 텍스트
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isUrgent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            margin: const EdgeInsets.only(bottom: 5),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              days == 0 ? '🔔 오늘 라운딩!' : '🔔 내일 라운딩!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const Text(
                          '1일 홀인원보험',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '홀인원 발생 시 최대 300만원 보장',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '$_kInsurancePrice / 1일',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '2분 내 가입 완료',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 화살표
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward_ios,
                        color: Colors.white, size: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  보험 안내 바텀시트
// ════════════════════════════════════════════════════════════
class _InsuranceSheet {
  static void show(BuildContext context, RoundSchedule schedule) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InsuranceSheetBody(schedule: schedule),
    );
  }
}

class _InsuranceSheetBody extends StatelessWidget {
  final RoundSchedule schedule;
  const _InsuranceSheetBody({required this.schedule});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: ctrl,
          padding: EdgeInsets.zero,
          children: [
            // ── 헤더 ──
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: Column(
                children: [
                  // 핸들
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('⛳',
                      style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 8),
                  const Text(
                    '1일 홀인원보험',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${schedule.courseName} · ${_fmtDate(schedule.roundDate)}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 왜 필요한가 ──
                  const Text('홀인원이 나면?',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _InsurancePoint(
                      icon: '🍽️',
                      text: '동반자 식사·음료 비용 (평균 50~100만원)'),
                  _InsurancePoint(
                      icon: '🏆',
                      text: '기념품·트로피 구매 (평균 30~50만원)'),
                  _InsurancePoint(
                      icon: '🎁',
                      text: '캐디피·그린피 부담 (클럽 관례)'),
                  _InsurancePoint(
                      icon: '💸',
                      text: '총 지출 100~300만원 이상 예상'),

                  const SizedBox(height: 20),

                  // ── 보험 혜택 ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.primaryLight
                              .withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shield_outlined,
                                color: AppColors.primary, size: 18),
                            SizedBox(width: 6),
                            Text('보장 내용',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.primary,
                                )),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _CoverageRow('홀인원 축하 비용', '최대 200만원'),
                        _CoverageRow('동반자 그린피', '최대 50만원'),
                        _CoverageRow('기념품 구입비', '최대 30만원'),
                        _CoverageRow('기타 부대비용', '최대 20만원'),
                        const Divider(height: 20),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('보험료',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(
                              '$_kInsurancePrice / 1일',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── 가입 안내 ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: const Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 15, color: Colors.amber),
                            SizedBox(width: 6),
                            Text('가입 안내',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                          ],
                        ),
                        SizedBox(height: 8),
                        _InsuranceNote('라운딩 당일 00:00 이전까지 가입 가능'),
                        _InsuranceNote('본인 인증 후 2분 내 가입 완료'),
                        _InsuranceNote('보험사 API 연동 준비 중 (곧 자동화 예정)'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── 가입하기 버튼 ──
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // TODO: 보험사 API 연동 후 실제 가입 페이지로 이동
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Text('⛳ '),
                                Expanded(
                                  child: Text(
                                    '보험사 API 연동 후 바로 가입 가능합니다!',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: AppColors.primary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.security, size: 20),
                          SizedBox(width: 8),
                          Text(
                            '1일 홀인원보험 가입하기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 닫기
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('나중에'),
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      '* 보험사 연동 준비 중 · 곧 자동 가입 지원 예정',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.month}월 ${d.day}일 (${['월', '화', '수', '목', '금', '토', '일'][d.weekday - 1]})';
}

// 보험 설명 포인트
class _InsurancePoint extends StatelessWidget {
  final String icon;
  final String text;
  const _InsurancePoint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// 보장 항목 행
class _CoverageRow extends StatelessWidget {
  final String label;
  final String value;
  const _CoverageRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textPrimary)),
          Text(value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              )),
        ],
      ),
    );
  }
}

// 가입 안내 노트
class _InsuranceNote extends StatelessWidget {
  final String text;
  const _InsuranceNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(
                  color: Colors.amber, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  _PhotoSection — 일정별 사진 업로드/보기
// ════════════════════════════════════════════════════════════
class _PhotoSection extends StatelessWidget {
  final RoundSchedule schedule;

  const _PhotoSection({required this.schedule});

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final photos = provider.photosOf(schedule.id);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 헤더 ──
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.mintBright],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_camera_rounded,
                        color: Colors.white, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('라운딩 사진',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink)),
                            if (photos.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${photos.length}장',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const Text(
                          '라운딩 사진을 올려 추억을 남기세요',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showUploadDialog(context, provider),
                      borderRadius: BorderRadius.circular(20),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.mintBright],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate_rounded,
                                color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('사진 추가',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── 사진 그리드 미리보기 (3열 × 2줄) ──
              if (photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: photos.length.clamp(0, 6),
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    return GestureDetector(
                      onTap: () => _openViewer(context, photos, index),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: RoundPhotoView(imageUrl: photo.imageUrl),
                      ),
                    );
                  },
                ),
                if (photos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _openAlbum(context, photos),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        '전체보기 (${photos.length}장)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ] else ...[
                const SizedBox(height: 16),
                Material(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => _showUploadDialog(context, provider),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.divider,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.add_photo_alternate_rounded,
                              size: 36,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.5)),
                          const SizedBox(height: 8),
                          const Text('아직 사진이 없습니다',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          const Text(
                            '+ 첫 번째 사진 올리기',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _openViewer(
      BuildContext context, List<RoundPhoto> photos, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SchedulePhotoViewer(
          scheduleId: schedule.id,
          photos: photos,
          initialIndex: index,
        ),
      ),
    );
  }

  void _openAlbum(BuildContext context, List<RoundPhoto> photos) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SchedulePhotoAlbumScreen(
          scheduleId: schedule.id,
          title: schedule.displayTitle,
          photos: photos,
        ),
      ),
    );
  }

  Future<void> _showUploadDialog(
      BuildContext context, ClubProvider provider) async {
    List<String> dataUrls;
    var exceeded = false;
    try {
      (dataUrls, exceeded) = await pickRoundPhotoDataUrls();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 불러오지 못했습니다')),
      );
      return;
    }
    if (dataUrls.isEmpty || !context.mounted) return;
    // 20장 초과 안내. 예전엔 제한도 안내도 없어 계속 선택됐다.
    if (exceeded) {
      await showRoundPhotoLimitAlert(context);
      if (!context.mounted) return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => PhotoUploadSheet(
        schedule: schedule,
        provider: provider,
        initialDataUrls: dataUrls,
      ),
    );
  }
}



// ── 일정 라운딩 사진첩 (전체보기) ──
class _SchedulePhotoAlbumScreen extends StatefulWidget {
  final String scheduleId;
  final String title;
  final List<RoundPhoto> photos;
  const _SchedulePhotoAlbumScreen({
    required this.scheduleId,
    required this.title,
    required this.photos,
  });

  @override
  State<_SchedulePhotoAlbumScreen> createState() =>
      _SchedulePhotoAlbumScreenState();
}

class _SchedulePhotoAlbumScreenState extends State<_SchedulePhotoAlbumScreen> {
  bool _selecting = false;
  final Set<String> _selected = <String>{};

  void _toggleSelectMode() {
    setState(() {
      _selecting = !_selecting;
      if (!_selecting) _selected.clear();
    });
  }

  void _toggleId(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _deleteSelected(ClubProvider provider, List<RoundPhoto> live) async {
    final targets = live
        .where((p) => _selected.contains(p.id) && provider.canDeletePhoto(p))
        .map((p) => p.id)
        .toList();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('삭제할 수 있는 사진이 없습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('사진 삭제'),
        content: Text('선택한 ${targets.length}장을 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('삭제',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final n = provider.deletePhotos(targets);
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _selecting = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(n > 0 ? '$n장 삭제했습니다' : '삭제하지 못했습니다'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final live = provider.photosOf(widget.scheduleId);
        final canBulk = live.any(provider.canDeletePhoto);
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                _selecting ? Icons.close : Icons.arrow_back_ios_new,
                size: 18,
                color: AppColors.textPrimary,
              ),
              onPressed: () {
                if (_selecting) {
                  _toggleSelectMode();
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            title: Text(
              _selecting
                  ? '선택 ${_selected.length}장'
                  : '${widget.title} · ${live.length}장',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            actions: [
              if (live.isNotEmpty && canBulk)
                TextButton(
                  onPressed: _toggleSelectMode,
                  child: Text(
                    _selecting ? '취소' : '선택',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (_selecting && _selected.isNotEmpty)
                TextButton(
                  onPressed: () => _deleteSelected(provider, live),
                  child: const Text(
                    '삭제',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          body: live.isEmpty
              ? const Center(
                  child: Text(
                    '사진이 없습니다',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: live.length,
                  itemBuilder: (context, index) {
                    final photo = live[index];
                    final selected = _selected.contains(photo.id);
                    return GestureDetector(
                      onTap: () {
                        if (_selecting) {
                          if (!provider.canDeletePhoto(photo)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('이 사진은 삭제할 수 없습니다'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          _toggleId(photo.id);
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _SchedulePhotoViewer(
                              scheduleId: widget.scheduleId,
                              photos: live,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                      onLongPress: () {
                        if (!provider.canDeletePhoto(photo)) return;
                        if (!_selecting) {
                          setState(() {
                            _selecting = true;
                            _selected
                              ..clear()
                              ..add(photo.id);
                          });
                        } else {
                          _toggleId(photo.id);
                        }
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: RoundPhotoView(imageUrl: photo.imageUrl),
                          ),
                          if (_selecting)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected
                                      ? AppColors.primary
                                      : Colors.black45,
                                  border: Border.all(
                                      color: Colors.white, width: 1.5),
                                ),
                                child: selected
                                    ? const Icon(Icons.check,
                                        size: 14, color: Colors.white)
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

// ── 일정 내 사진 뷰어 ──
class _SchedulePhotoViewer extends StatefulWidget {
  final String scheduleId;
  final List<RoundPhoto> photos;
  final int initialIndex;
  const _SchedulePhotoViewer({
    required this.scheduleId,
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<_SchedulePhotoViewer> createState() => _SchedulePhotoViewerState();
}

class _SchedulePhotoViewerState extends State<_SchedulePhotoViewer> {
  late PageController _controller;
  late int _current;
  late List<RoundPhoto> _photos;

  @override
  void initState() {
    super.initState();
    _photos = List<RoundPhoto>.from(widget.photos);
    _current = widget.initialIndex;
    if (_photos.isNotEmpty) {
      _current = _current.clamp(0, _photos.length - 1);
    } else {
      _current = 0;
    }
    _controller = PageController(initialPage: _current);
  }

  void _syncFromProvider(ClubProvider provider) {
    final live = provider.photosOf(widget.scheduleId);
    final prevId = (_photos.isNotEmpty && _current < _photos.length)
        ? _photos[_current].id
        : null;
    _photos = List<RoundPhoto>.from(live);
    if (_photos.isEmpty) {
      _current = 0;
      return;
    }
    var next =
        prevId == null ? 0 : _photos.indexWhere((p) => p.id == prevId);
    if (next < 0) {
      next = _current.clamp(0, _photos.length - 1);
    }
    _current = next;
  }

  Future<void> _editCaption(
      BuildContext context, ClubProvider provider, RoundPhoto photo) async {
    final ctrl = TextEditingController(text: photo.caption ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('사진 설명 수정'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('저장')),
        ],
      ),
    );
    if (ok == true) {
      provider.updatePhotoCaption(photo.id, ctrl.text);
      if (mounted) setState(() => _syncFromProvider(provider));
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, ClubProvider provider, RoundPhoto photo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('사진 삭제'),
        content: const Text('이 사진을 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('삭제',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    final deleted = provider.deletePhoto(photo.id);
    if (!mounted) return;
    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사진을 삭제할 수 없습니다. 본인 사진이거나 운영진만 삭제할 수 있습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    // 삭제 후 목록(앨범)으로 복귀
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final live = provider.photosOf(widget.scheduleId);
        final liveKey = live.map((p) => p.id).join('|');
        final localKey = _photos.map((p) => p.id).join('|');
        if (liveKey != localKey) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _syncFromProvider(provider));
            if (_photos.isEmpty) {
              Navigator.pop(context);
            } else if (_controller.hasClients) {
              _controller.jumpToPage(_current);
            }
          });
        }
        if (_photos.isEmpty) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: SizedBox.shrink(),
          );
        }
        final safeIndex = _current.clamp(0, _photos.length - 1);
        final photo = _photos[safeIndex];
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              '${safeIndex + 1} / ${_photos.length}',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            centerTitle: true,
            actions: [
              if (provider.canDeletePhoto(photo) || provider.isOwnPhoto(photo))
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (provider.isOwnPhoto(photo))
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            color: Colors.white70),
                        onPressed: () =>
                            _editCaption(context, provider, photo),
                      ),
                    if (provider.canDeletePhoto(photo))
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.white70),
                        onPressed: () =>
                            _confirmDelete(context, provider, photo),
                      ),
                  ],
                ),
            ],
          ),
          body: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: _photos.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, i) => InteractiveViewer(
                  child: RoundPhotoView(
                    imageUrl: _photos[i].imageUrl,
                    fit: BoxFit.contain,
                    error: const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white30, size: 60),
                    ),
                  ),
                ),
              ),
              if (photo.caption != null || photo.uploaderName.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (photo.caption != null)
                          Text(
                            photo.caption!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '${photo.uploaderName} · ${photo.takenAt.month}/${photo.takenAt.day}',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12),
                        ),
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
}

// ────────────────────────────────────────────────────────────
//  조편성 진입 카드 (일정 상세 → 조편성 화면 연결)
// ────────────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════
//  _GroupViewBannerCard — 모든 회원용 조편성 보기 (최상단 강조 배너)
//  · 확정된 경우: 조편성 화면으로 이동
//  · 미확정:     얼럿 표시
// ════════════════════════════════════════════════════════════
class _GroupViewBannerCard extends StatelessWidget {
  final RoundSchedule schedule;
  final ClubProvider provider;
  final bool isAdmin;

  const _GroupViewBannerCard({
    required this.schedule,
    required this.provider,
    required this.isAdmin,
  });

  // 조편성 팔레트 — 크림·골드·차콜 컨셉. 그린과 파스텔은 쓰지 않는다.
  // 조 배지는 같은 웜 계열의 명도 차이로만 구분한다.
  static const List<Color> _groupColors = [
    AppColors.goldDeep,
    AppColors.charcoal,
    Color(0xFFB08A2E),
    Color(0xFF6B6459),
    Color(0xFF8C6239),
    Color(0xFF3F3B33),
  ];

  @override
  Widget build(BuildContext context) {
    final assignment = provider.groupAssignment(schedule.id);
    final isFinalized = assignment?.isFinalized ?? false;

    return GestureDetector(
      onTap: () {
        if (!isFinalized && !isAdmin) {
          // 일반 회원 + 미확정 → 얼럿 (dialogCtx pop — 회귀 금지)
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (dialogCtx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.cream2,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.groups_rounded,
                        color: AppColors.goldDeep, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text('조편성',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cream2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 18, color: AppColors.goldDeep),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '아직 조편성이 확정되지 않았습니다.\n총무가 확정하면 이곳에서 확인할 수 있습니다.',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.charcoal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        } else {
          // 총무이거나 확정된 경우 → 조편성 화면
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupAssignmentScreen(schedule: schedule),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          // 다른 카드와 같은 테두리·그림자. 조편성만 튀지 않게 한다.
          border: Border.all(
            color: isFinalized ? AppColors.goldDeep : AppColors.divider,
            width: isFinalized ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── 헤더 ──
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              decoration: BoxDecoration(
                // 확정: 차콜 + 골드 아이콘 / 미확정: 조용한 크림
                gradient: isFinalized
                    ? const LinearGradient(
                        colors: [AppColors.charcoal, AppColors.charcoalDeep],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isFinalized ? null : AppColors.cream2,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  // 아이콘
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isFinalized
                          ? AppColors.accent.withValues(alpha: 0.22)
                          : AppColors.sand,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.groups_rounded,
                      color: isFinalized
                          ? AppColors.accent
                          : AppColors.goldDeep,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '조편성 보기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isFinalized
                                ? Colors.white
                                : AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isFinalized
                              ? '${schedule.teamCount}개 조 확정 완료 — 탭해서 확인'
                              : isAdmin
                                  ? '탭해서 조편성 시작하기'
                                  : '총무가 확정하면 여기서 확인할 수 있어요',
                          style: TextStyle(
                            fontSize: 12,
                            color: isFinalized
                                ? Colors.white.withValues(alpha: 0.9)
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 상태 뱃지
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isFinalized
                          ? AppColors.accent.withValues(alpha: 0.28)
                          : AppColors.sand,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isFinalized ? '확정 ✓' : '미확정',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isFinalized
                            ? AppColors.accent
                            : AppColors.inkSoft,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // 총무: 편집 버튼 표시
                  if (isAdmin) ...
                    [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isFinalized
                              ? AppColors.accent.withValues(alpha: 0.28)
                              : AppColors.sand,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              size: 13,
                              color: isFinalized
                                  ? AppColors.accent
                                  : AppColors.goldDeep,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '편집',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isFinalized
                                    ? AppColors.accent
                                    : AppColors.goldDeep,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]
                  else ...
                    [
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isFinalized
                            ? Colors.white.withValues(alpha: 0.7)
                            : AppColors.textTertiary,
                      ),
                    ],
                ],
              ),
            ),

            // ── 확정된 경우: 조 미리보기 ──
            if (isFinalized && assignment != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  children: [
                    for (int gi = 0;
                        gi < assignment.groups.length;
                        gi++) ...[
                      if (gi > 0) const SizedBox(height: 6),
                      _GroupRow(
                        group: assignment.groups[gi],
                        color: _groupColors[gi % _groupColors.length],
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // ── 미확정: 안내 ──
            if (!isFinalized) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_clock_rounded,
                          size: 15, color: AppColors.textTertiary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '조편성이 확정되면 이름, 배정 조를 확인할 수 있습니다',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 조 한 행 미리보기
class _GroupRow extends StatelessWidget {
  final AssignGroup group;
  final Color color;
  const _GroupRow({required this.group, required this.color});

  @override
  Widget build(BuildContext context) {
    final names = group.slots
        .where((s) => s.isFilled)
        .map((s) => s.memberName!)
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Text(
                '${group.groupNumber}조',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              names.isEmpty ? '(미배정)' : names.join('  ·  '),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.85)),
            ),
          ),
          Text(
            '${names.length}명',
            style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  _ScoreAwardBannerCard — 예정/완료 라운딩 스코어/시상 진입 배너
//  · 모든 회원이 접근 가능 (isAdmin 조건 없음)
//  · 예정 일정: 미리 스코어 입력 가능 안내
//  · 완료 일정: 스코어 & 시상 내역 확인
// ════════════════════════════════════════════════════════════
class _ScoreAwardBannerCard extends StatelessWidget {
  final RoundSchedule schedule;
  final bool isPast;
  const _ScoreAwardBannerCard({
    required this.schedule,
    this.isPast = false,
  });

  // 조 선택 바텀시트 → 해당 조 멤버로 ScoreAwardScreen 진입
  void _showGroupSelectSheet(BuildContext context) {
    final provider = context.read<ClubProvider>();
    final assignment = provider.groupAssignment(schedule.id);
    final isFinalized = assignment?.isFinalized ?? false;

    if (!isFinalized || assignment == null) {
      // 조편성 미확정 → 전체 멤버로 바로 진입
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScoreAwardScreen(schedule: schedule, initialTab: 0),
        ),
      );
      return;
    }

    // 조편성 확정 → 조 선택 바텀시트
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _GroupSelectSheet(
        schedule: schedule,
        assignment: assignment,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_rounded,
                    color: AppColors.goldDeep, size: 18),
                const SizedBox(width: 6),
                Text(
                  isPast ? '라운딩 기록' : '스코어 & 시상',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!isPast) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('조별로 입력',
                        style: TextStyle(
                            color: AppColors.goldDeep,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isPast ? '스코어 & 시상 내역' : '스코어 & 시상 입력',
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isPast
                  ? '모든 회원이 스코어를 확인하고 시상 내역을 볼 수 있어요'
                  : '조를 선택하면 해당 조 멤버의 스코어를 입력할 수 있어요',
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                // 스코어 입력 버튼
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showGroupSelectSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.cream2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.sand),
                      ),
                      child: const Column(
                        children: [
                          Text('📊', style: TextStyle(fontSize: 24)),
                          SizedBox(height: 6),
                          Text(
                            '스코어 입력',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '조 선택 후 입력',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.goldDeep,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // 시상 내역 버튼
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScoreAwardScreen(
                          schedule: schedule,
                          initialTab: 1,
                        ),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.cream2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.sand),
                      ),
                      child: const Column(
                        children: [
                          Text('🏆', style: TextStyle(fontSize: 24)),
                          SizedBox(height: 6),
                          Text(
                            '시상 내역',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '수상자 보기/등록',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.goldDeep,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  _GroupSelectSheet — 조 선택 바텀시트
//  · 각 조 카드를 탭하면 해당 조 멤버 필터로 ScoreAwardScreen 진입
// ════════════════════════════════════════════════════════════
class _GroupSelectSheet extends StatelessWidget {
  final RoundSchedule schedule;
  final GroupAssignment assignment;

  const _GroupSelectSheet({
    required this.schedule,
    required this.assignment,
  });

  // 조편성 카드와 같은 웜 계열. 조 번호가 두 화면에서 같은 색으로 보인다.
  static const List<Color> _groupColors = [
    AppColors.goldDeep, AppColors.charcoal, Color(0xFFB08A2E),
    Color(0xFF6B6459), Color(0xFF8C6239), Color(0xFF3F3B33),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // 헤더
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.groups_rounded,
                    color: AppColors.goldDeep, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('몇 조 스코어카드인가요?',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1B4B))),
                  Text('${assignment.groups.length}개 조',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // 조 목록
          ...assignment.groups.map((group) {
            final idx = group.groupNumber - 1;
            final color = _groupColors[idx % _groupColors.length];
            final names = group.slots
                .where((s) => s.isFilled)
                .map((s) => s.memberName!)
                .toList();
            final memberIds = group.slots
                .where((s) => s.isFilled && s.memberId != null)
                .map((s) => GroupSlot(
                      memberId: s.memberId,
                      memberName: s.memberName,
                      gender: s.gender,
                      handicap: s.handicap,
                    ))
                .toList();

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context); // 바텀시트 닫기
                  // 해당 조 멤버 필터 정보를 schedule에 담아 ScoreAwardScreen 진입
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScoreAwardScreen(
                        schedule: schedule,
                        initialTab: 0,
                        groupFilter: group,       // ← 조 필터
                        groupNumber: group.groupNumber,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      // 조 번호 뱃지
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '${group.groupNumber}조',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 멤버 이름
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              names.isEmpty ? '(멤버 없음)' : names.join('  ·  '),
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: color),
                            ),
                            Text('${names.length}명',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 15, color: color.withValues(alpha: 0.6)),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 4),
          // 전체 보기 옵션
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScoreAwardScreen(
                    schedule: schedule,
                    initialTab: 0,
                  ),
                ),
              );
            },
            child: const Text('전체 참석자 스코어 보기',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
