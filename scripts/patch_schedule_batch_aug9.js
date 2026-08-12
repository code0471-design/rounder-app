/**
 * Schedule batch (UTF-8 safe) — Aug 9
 * Uses only single-quoted JS strings so Dart ${} is never interpolated.
 */
const fs = require('fs');
const path = require('path');
const file = path.join(__dirname, '..', 'lib/screens/schedule/schedule_screen.dart');
let src = fs.readFileSync(file, 'utf8');

function must(oldS, newS, label) {
  if (!src.includes(oldS)) {
    console.error('FAIL:', label);
    const preview = oldS.slice(0, 80).replace(/\n/g, '\\n');
    console.error('looking for:', preview);
    process.exit(1);
  }
  src = src.replace(oldS, newS);
  console.log('OK', label);
}

// 1) Hide AdBanner
must(
  [
    '    // 광고를 맨 위에 배치 (index 0)',
    '    // items: [AD, 카드0, 카드1, 카드2, ...]',
    '    return RefreshIndicator(',
    '      color: AppColors.primary,',
    '      onRefresh: () async =>',
    '          await Future.delayed(const Duration(milliseconds: 500)),',
    '      child: ListView.separated(',
    '        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),',
    '        itemCount: schedules.length + 1, // +1 for ad banner',
    '        separatorBuilder: (_, __) => const SizedBox(height: 14),',
    '        itemBuilder: (context, i) {',
    '          // 맨 위에 광고 배너',
    '          if (i == 0) {',
    '            return AdBanner(',
    '              type: AdBannerType.native,',
    '              adIndex: 3,',
    '              clubId: clubId,',
    '              slotType: AdSlotType.schedule,',
    '            );',
    '          }',
    '          return _ScheduleCard(',
    '            schedule: schedules[i - 1],',
    '            isPast: isPast,',
    '          );',
    '        },',
    '      ),',
    '    );',
  ].join('\n'),
  [
    '    // 광고 배너 OFF (런칭) — AdBanner 복구 금지',
    '    return RefreshIndicator(',
    '      color: AppColors.primary,',
    '      onRefresh: () async =>',
    '          await Future.delayed(const Duration(milliseconds: 500)),',
    '      child: ListView.separated(',
    '        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),',
    '        itemCount: schedules.length,',
    '        separatorBuilder: (_, __) => const SizedBox(height: 14),',
    '        itemBuilder: (context, i) {',
    '          return _ScheduleCard(',
    '            schedule: schedules[i],',
    '            isPast: isPast,',
    '          );',
    '        },',
    '      ),',
    '    );',
  ].join('\n'),
  'hide list AdBanner',
);

// 2) List chips
must(
  [
    "                      return Row(",
    "                        mainAxisSize: MainAxisSize.min,",
    "                        children: [",
    "                          _AttChip2('참석', latest.confirmedCount, false, false),",
    "                          const SizedBox(width: 5),",
    "                          _AttChip2('미정', latest.pendingCount, true, false),",
    "                          const SizedBox(width: 5),",
    "                          _AttChip2('불참', latest.declinedCount, false, true),",
    "                        ],",
    "                      );",
  ].join('\n'),
  [
    "                      final regular = prov.regularMembers.length;",
    "                      final guestIds = {",
    "                        for (final m in prov.guestMembers) m.id",
    "                      };",
    "                      final memberIds = {",
    "                        for (final m in prov.activeMembers) m.id",
    "                      };",
    "                      final valid = latest.responses",
    "                          .where((r) => memberIds.contains(r.memberId))",
    "                          .toList();",
    "                      final attend =",
    "                          valid.where((r) => r.response == '참석').length;",
    "                      final decline = valid",
    "                          .where((r) =>",
    "                              r.response == '불참' &&",
    "                              !guestIds.contains(r.memberId))",
    "                          .length;",
    "                      final respondedRegular = valid",
    "                          .where((r) =>",
    "                              (r.response == '참석' || r.response == '불참') &&",
    "                              !guestIds.contains(r.memberId))",
    "                          .map((r) => r.memberId)",
    "                          .toSet();",
    "                      final noRes =",
    "                          (regular - respondedRegular.length).clamp(0, regular);",
    "                      return Row(",
    "                        mainAxisSize: MainAxisSize.min,",
    "                        children: [",
    "                          _AttChip2('참석', attend, false, false),",
    "                          const SizedBox(width: 5),",
    "                          _AttChip2('미답변', noRes, true, false),",
    "                          const SizedBox(width: 5),",
    "                          _AttChip2('불참', decline, false, true),",
    "                        ],",
    "                      );",
  ].join('\n'),
  'list chips',
);

// 3) Form state
must(
  [
    '  late int _teamCount;',
    '  bool _saving = false;',
    '  DateTime? _rsvpDeadlineDate;',
    '  TimeOfDay? _rsvpDeadlineTime;',
    '',
    '  @override',
    '  void initState() {',
    '    super.initState();',
    '    final clubTeams = widget.provider.selectedClub.teamCount;',
    '    _teamCount = clubTeams > 0 ? clubTeams : 1;',
    '  }',
    '',
    '  @override',
    '  void dispose() {',
    '    _titleCtrl.dispose();',
    '    _courseCtrl.dispose();',
    '    _addressCtrl.dispose();',
    '    _noticeCtrl.dispose();',
    '    _capacityCtrl.dispose();',
    '    super.dispose();',
    '  }',
    '',
    '  Future<void> _pickRsvpDeadline() async {',
    '    final date = await showDatePicker(',
    '      context: context,',
    '      initialDate: _rsvpDeadlineDate ?? DateTime.now(),',
    '      firstDate: DateTime.now().subtract(const Duration(days: 1)),',
    '      lastDate: DateTime.now().add(const Duration(days: 365)),',
    '    );',
    '    if (date == null || !mounted) return;',
    '    final time = await showTimePicker(',
    '      context: context,',
    '      initialTime: _rsvpDeadlineTime ?? const TimeOfDay(hour: 22, minute: 0),',
    '    );',
    '    if (time == null) return;',
    '    setState(() {',
    '      _rsvpDeadlineDate = date;',
    '      _rsvpDeadlineTime = time;',
    '    });',
    '  }',
  ].join('\n'),
  [
    '  late int _teamCount;',
    '  bool _saving = false;',
    '',
    '  @override',
    '  void initState() {',
    '    super.initState();',
    '    final clubTeams = widget.provider.selectedClub.teamCount;',
    '    _teamCount = clubTeams > 0 ? clubTeams : 1;',
    "    _capacityCtrl.text = '${_teamCount * 4}';",
    '  }',
    '',
    '  void _setTeamCount(int next) {',
    '    if (next < 1) return;',
    '    setState(() {',
    '      _teamCount = next;',
    "      _capacityCtrl.text = '${next * 4}';",
    '    });',
    '  }',
    '',
    '  @override',
    '  void dispose() {',
    '    _titleCtrl.dispose();',
    '    _courseCtrl.dispose();',
    '    _addressCtrl.dispose();',
    '    _noticeCtrl.dispose();',
    '    _capacityCtrl.dispose();',
    '    super.dispose();',
    '  }',
  ].join('\n'),
  'form init',
);

must(
  [
    '                          IconButton(',
    '                            onPressed: () {',
    '                              if (_teamCount > 1) {',
    '                                setState(() => _teamCount--);',
    '                              }',
    '                            },',
    '                            icon: const Icon(Icons.remove_circle_outline,',
    '                                color: AppColors.primary),',
    '                          ),',
  ].join('\n'),
  [
    '                          IconButton(',
    '                            onPressed: _teamCount > 1',
    '                                ? () => _setTeamCount(_teamCount - 1)',
    '                                : null,',
    '                            icon: const Icon(Icons.remove_circle_outline,',
    '                                color: AppColors.primary),',
    '                          ),',
  ].join('\n'),
  'team minus',
);

must(
  [
    '                          IconButton(',
    "                            onPressed: () => setState(() => _teamCount++),",
    '                            icon: const Icon(Icons.add_circle_outline,',
    '                                color: AppColors.primary),',
    '                          ),',
  ].join('\n'),
  [
    '                          IconButton(',
    '                            onPressed: () => _setTeamCount(_teamCount + 1),',
    '                            icon: const Icon(Icons.add_circle_outline,',
    '                                color: AppColors.primary),',
    '                          ),',
  ].join('\n'),
  'team plus',
);

// 5) Replace capacity field + delete rsvp UI by locating markers
const capStart = src.indexOf("                    // 정원 (선택) — 설정 시 초과 인원은 대기 등록으로 자동 전환됨");
const memoStart = src.indexOf("                    // 공지 · 메모 (선택)");
if (capStart < 0 || memoStart < 0 || memoStart <= capStart) {
  console.error('FAIL: capacity/rsvp block bounds');
  process.exit(1);
}
const replacement = [
  '                    // 정원 = 팀수×4 (자동). 초과 시 대기 등록',
  '                    _FormField(',
  "                      label: '정원 (팀수 × 4 · 초과 시 자동 대기등록)',",
  '                      child: TextFormField(',
  '                        controller: _capacityCtrl,',
  '                        keyboardType: TextInputType.number,',
  '                        readOnly: true,',
  "                        decoration: _deco('팀수 × 4'),",
  '                      ),',
  '                    ),',
  '                    const SizedBox(height: 16),',
  '',
  '',
].join('\n');
src = src.slice(0, capStart) + replacement + src.slice(memoStart);
console.log('OK capacity+rsvp ui');

// 6) Save: no auto-attend + capacity always team*4 + no rsvp
must(
  [
    "    // 등록자 본인을 '참석'으로 미리 반영",
    '    final responses = <AttendanceResponse>[',
    '      AttendanceResponse(',
    '        memberId: widget.provider.currentUserId,',
    '        memberName: widget.provider.currentUserName,',
    "        response: '참석',",
    '        respondedAt: DateTime.now(),',
    '      ),',
    '    ];',
    '',
    '    final schedule = RoundSchedule(',
    "      id: 'sched_${DateTime.now().millisecondsSinceEpoch}',",
    '      clubId: widget.provider.selectedClub.id,',
    '      title: _titleCtrl.text.trim(),',
    '      roundDate: _selectedDate!,',
    '      teeTime: teeStr,',
    '      courseName: _courseCtrl.text.trim(),',
    '      courseAddress: _addressCtrl.text.trim().isEmpty',
    '          ? null',
    '          : _addressCtrl.text.trim(),',
    '      teamCount: _teamCount,',
    '      maxCapacity: int.tryParse(_capacityCtrl.text.trim()),',
    '      notice: _noticeCtrl.text.trim().isEmpty',
    '          ? null',
    '          : _noticeCtrl.text.trim(),',
    '      createdBy: widget.provider.currentUserName,',
    '      responses: responses,',
    '      companionIds: const [],',
    '      rsvpDeadline: (_rsvpDeadlineDate != null && _rsvpDeadlineTime != null)',
    '          ? DateTime(',
    '              _rsvpDeadlineDate!.year,',
    '              _rsvpDeadlineDate!.month,',
    '              _rsvpDeadlineDate!.day,',
    '              _rsvpDeadlineTime!.hour,',
    '              _rsvpDeadlineTime!.minute,',
    '            )',
    '          : null,',
    '    );',
  ].join('\n'),
  [
    '    // 일정 등록 시 자동 참석 금지 — 전원 미답변으로 시작',
    '    final schedule = RoundSchedule(',
    "      id: 'sched_${DateTime.now().millisecondsSinceEpoch}',",
    '      clubId: widget.provider.selectedClub.id,',
    '      title: _titleCtrl.text.trim(),',
    '      roundDate: _selectedDate!,',
    '      teeTime: teeStr,',
    '      courseName: _courseCtrl.text.trim(),',
    '      courseAddress: _addressCtrl.text.trim().isEmpty',
    '          ? null',
    '          : _addressCtrl.text.trim(),',
    '      teamCount: _teamCount,',
    '      maxCapacity: _teamCount * 4,',
    '      notice: _noticeCtrl.text.trim().isEmpty',
    '          ? null',
    '          : _noticeCtrl.text.trim(),',
    '      createdBy: widget.provider.currentUserName,',
    '      responses: const [],',
    '      companionIds: const [],',
    '    );',
  ].join('\n'),
  'save no auto-attend',
);

// 7) Detail _AttendanceCard — use club members + 미답변
must(
  [
    '        final responses = latest.responses;',
    '        final confirmed = responses.where((r) => r.response == \'참석\').toList();',
    '        final declined  = responses.where((r) => r.response == \'불참\').toList();',
    '        final pending   = responses.where((r) => r.response == \'미정\').toList();',
    '        final total = responses.length;',
  ].join('\n'),
  [
    '        final memberIds = {for (final m in provider.activeMembers) m.id};',
    '        final guestIds = {for (final m in provider.guestMembers) m.id};',
    '        final responses = latest.responses',
    '            .where((r) => memberIds.contains(r.memberId))',
    '            .toList();',
    '        final confirmed = responses.where((r) => r.response == \'참석\').toList();',
    '        final declined  = responses',
    '            .where((r) => r.response == \'불참\' && !guestIds.contains(r.memberId))',
    '            .toList();',
    '        final respondedRegular = {',
    '          ...confirmed.where((r) => !guestIds.contains(r.memberId)).map((r) => r.memberId),',
    '          ...declined.map((r) => r.memberId),',
    '        };',
    '        final noResponse = provider.regularMembers',
    '            .where((m) => !respondedRegular.contains(m.id))',
    '            .length;',
    '        final total = provider.regularMembers.length;',
  ].join('\n'),
  'detail attendance counts',
);

must(
  [
    "                    Text('총 $total명',",
  ].join('\n'),
  [
    "                    Text('정회원 $total명',",
  ].join('\n'),
  'detail total label',
);

must(
  [
    "                    _StatItem(count: confirmed.length, label: '참석', color: AppColors.success),",
    '                    _Divider(),',
    "                    _StatItem(count: pending.length,   label: '미정', color: const Color(0xFFD48E00)),",
    '                    _Divider(),',
    "                    _StatItem(count: declined.length,  label: '불참', color: AppColors.danger),",
  ].join('\n'),
  [
    "                    _StatItem(count: confirmed.length, label: '참석', color: AppColors.success),",
    '                    _Divider(),',
    "                    _StatItem(count: noResponse, label: '미답변', color: AppColors.textSecondary),",
    '                    _Divider(),',
    "                    _StatItem(count: declined.length,  label: '불참', color: AppColors.danger),",
  ].join('\n'),
  'detail stats 미답변',
);

// Remove pending member list section references that would break
must(
  [
    '              if (pending.isNotEmpty) ...[',
    "                _MemberListSection(label: '미정', color: const Color(0xFFD48E00), members: pending),",
    '              ],',
  ].join('\n'),
  '',
  'remove pending list section',
);

fs.writeFileSync(file, src, 'utf8');
console.log('DONE schedule batch');
