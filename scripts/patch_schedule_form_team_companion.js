/**
 * Patch schedule add form:
 * - default teamCount from selectedClub.teamCount (not hardcoded 4)
 * - remove "동반자 명단 (선택)" UI + picker class
 * UTF-8 safe (no PowerShell / Cursor StrReplace on this file).
 */
const fs = require('fs');
const path = require('path');

const file = path.join(
  __dirname,
  '..',
  'lib',
  'screens',
  'schedule',
  'schedule_screen.dart',
);

let src = fs.readFileSync(file, 'utf8');
const before = src;

// 1) Init team count from club
src = src.replace(
  `class _ScheduleFormSheetState extends State<_ScheduleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _courseCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _noticeCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay _teeTime = const TimeOfDay(hour: 7, minute: 30);
  int _teamCount = 4;
  bool _saving = false;
  final Set<String> _selectedCompanionIds = {};
  DateTime? _rsvpDeadlineDate;
  TimeOfDay? _rsvpDeadlineTime;

  @override
  void dispose() {`,
  `class _ScheduleFormSheetState extends State<_ScheduleFormSheet> {
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
  DateTime? _rsvpDeadlineDate;
  TimeOfDay? _rsvpDeadlineTime;

  @override
  void initState() {
    super.initState();
    final clubTeams = widget.provider.selectedClub.teamCount;
    _teamCount = clubTeams > 0 ? clubTeams : 1;
  }

  @override
  void dispose() {`,
);

if (src === before) {
  console.error('FAIL: teamCount init block not found');
  process.exit(1);
}

// 2) Remove companion picker field from form
const companionField = `
                    // 동반자 명단 (선택)
                    _FormField(
                      label: '동반자 명단 (선택)',
                      child: _CompanionPicker(
                        members: widget.provider.members,
                        selectedIds: _selectedCompanionIds,
                        onToggle: (id) {
                          setState(() {
                            if (_selectedCompanionIds.contains(id)) {
                              _selectedCompanionIds.remove(id);
                            } else {
                              _selectedCompanionIds.add(id);
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
`;

if (!src.includes(companionField)) {
  console.error('FAIL: companion field block not found');
  process.exit(1);
}
src = src.replace(companionField, '\n');

// 3) Save: only creator as attending (no companions)
const oldResponses = `    // 등록자 본인 + 선택한 동반자를 '참석'으로 미리 반영
    final responses = <AttendanceResponse>[
      AttendanceResponse(
        memberId: widget.provider.currentUserId,
        memberName: widget.provider.currentUserName,
        response: '참석',
        respondedAt: DateTime.now(),
      ),
      for (final id in _selectedCompanionIds)
        if (id != widget.provider.currentUserId)
          AttendanceResponse(
            memberId: id,
            memberName: widget.provider.members
                .cast<Member?>()
                .firstWhere((m) => m?.id == id, orElse: () => null)
                ?.name ?? id,
            response: '참석',
            respondedAt: DateTime.now(),
          ),
    ];`;

const newResponses = `    // 등록자 본인을 '참석'으로 미리 반영
    final responses = <AttendanceResponse>[
      AttendanceResponse(
        memberId: widget.provider.currentUserId,
        memberName: widget.provider.currentUserName,
        response: '참석',
        respondedAt: DateTime.now(),
      ),
    ];`;

if (!src.includes(oldResponses)) {
  console.error('FAIL: companion responses block not found');
  process.exit(1);
}
src = src.replace(oldResponses, newResponses);

src = src.replace(
  `      companionIds: _selectedCompanionIds.toList(),`,
  `      companionIds: const [],`,
);

// 4) Remove _CompanionPicker widget class
const pickerStart =
  '// ════════════════════════════════════════════════════════════\n' +
  '//  동반자 명단 선택 — 모임 회원 중 함께할 인원을 체크박스로 선택\n' +
  '//  선택된 인원은 일정 생성 시 자동으로 \'참석\'으로 반영된다.\n' +
  '// ════════════════════════════════════════════════════════════\n' +
  'class _CompanionPicker extends StatelessWidget {';

const pickerEndMarker =
  '// ════════════════════════════════════════════════════════════\n' +
  '//  보험 배너 카드 (일정 상세 화면용)\n' +
  '// ════════════════════════════════════════════════════════════';

const startIdx = src.indexOf(pickerStart);
const endIdx = src.indexOf(pickerEndMarker);
if (startIdx < 0 || endIdx < 0 || endIdx <= startIdx) {
  console.error('FAIL: _CompanionPicker class bounds not found');
  process.exit(1);
}
src = src.slice(0, startIdx) + pickerEndMarker + src.slice(endIdx + pickerEndMarker.length);

fs.writeFileSync(file, src, 'utf8');
console.log('OK: schedule form teamCount + companion removed');
