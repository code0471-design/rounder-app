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

