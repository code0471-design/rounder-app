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

// Ensure alimtalk_utils import
if (!src.includes("alimtalk_utils.dart")) {
  const imp = "import '../../theme/app_theme.dart';\n";
  // find a good import anchor near top
  const m = src.match(/import '[^']+theme\/app_theme\.dart';\n/);
  if (!m) {
    console.error('app_theme import not found');
    process.exit(1);
  }
  src = src.replace(
    m[0],
    m[0] + "import '../../utils/alimtalk_utils.dart';\n",
  );
  console.log('added alimtalk_utils import');
}

// Admin menu: add 일정 변경
const oldMenu = `            ListTile(
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

  void _confirmCancel(BuildContext context, ClubProvider provider) {`;

const newMenu = `            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined,
                  color: AppColors.primary),
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

  void _confirmCancel(BuildContext context, ClubProvider provider) {`;

if (!src.includes(oldMenu)) {
  if (src.includes('_openEditSchedule')) {
    console.log('edit menu already present');
  } else {
    console.error('admin menu block not found');
    process.exit(1);
  }
} else {
  src = src.replace(oldMenu, newMenu);
  console.log('added schedule edit menu');
}

// Form sheet: accept optional editTarget
const oldClass = `class _ScheduleFormSheet extends StatefulWidget {
  final ClubProvider provider;
  const _ScheduleFormSheet({required this.provider});

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

  @override
  void initState() {
    super.initState();
    final clubTeams = widget.provider.selectedClub.teamCount;
    _teamCount = clubTeams > 0 ? clubTeams : 1;
    _capacityCtrl.text = '\${_teamCount * 4}';
  }`;

const newClass = `class _ScheduleFormSheet extends StatefulWidget {
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
      _capacityCtrl.text = '\${_teamCount * 4}';
    } else {
      final clubTeams = widget.provider.selectedClub.teamCount;
      _teamCount = clubTeams > 0 ? clubTeams : 1;
      _capacityCtrl.text = '\${_teamCount * 4}';
    }
  }`;

if (!src.includes(oldClass)) {
  if (src.includes('final RoundSchedule? editTarget')) {
    console.log('form editTarget already present');
  } else {
    console.error('form class block not found');
    process.exit(1);
  }
} else {
  src = src.replace(oldClass, newClass);
  console.log('patched form for edit');
}

// Title text
src = src.replace(
  `                        const Text('일정 등록',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold)),`,
  `                        Text(_isEdit ? '일정 변경' : '일정 등록',
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold)),`,
);

// Save button label
src = src.replace(
  `                            : const Text('일정 등록',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),`,
  `                            : Text(_isEdit ? '변경 저장' : '일정 등록',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),`,
);

// Replace _save body create-only with create/edit
const oldSave = `  Future<void> _save() async {
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
        '\${_teeTime.hour.toString().padLeft(2, '0')}:\${_teeTime.minute.toString().padLeft(2, '0')}';

    // 일정 등록 시 자동 참석 금지 — 전원 미답변으로 시작
    final schedule = RoundSchedule(
      id: 'sched_\${DateTime.now().millisecondsSinceEpoch}',
      clubId: widget.provider.selectedClub.id,
      title: _titleCtrl.text.trim(),
      roundDate: _selectedDate!,
      teeTime: teeStr,
      courseName: _courseCtrl.text.trim(),
      courseAddress: _addressCtrl.text.trim().isEmpty
          ? null
          : _addressCtrl.text.trim(),
      teamCount: _teamCount,
      maxCapacity: _teamCount * 4,
      notice: _noticeCtrl.text.trim().isEmpty
          ? null
          : _noticeCtrl.text.trim(),
      createdBy: widget.provider.currentUserName,
      responses: const [],
      companionIds: const [],
    );

    widget.provider.addSchedule(schedule);

    if (mounted) {
      Navigator.pop(context);
      // 일정 등록 완료 스낵바
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('\${schedule.title} 일정이 등록되었습니다 🗓️'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
      // 알림톡 발송 다이얼로그 (총무 전용)
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        _showAlimtalkDialog(
          context: context,
          provider: widget.provider,
          scheduleId: schedule.id,
          scheduleTitle: schedule.title,
          roundDate: schedule.roundDate,
        );
      }
    }
  }`;

const newSave = `  Future<void> _save() async {
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
        '\${_teeTime.hour.toString().padLeft(2, '0')}:\${_teeTime.minute.toString().padLeft(2, '0')}';

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
      widget.provider.updateSchedule(updated);
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('\${updated.title} 일정이 변경되었습니다'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
      final settings = widget.provider
          .alimtalkSettingsOf(widget.provider.selectedClub.id);
      if (settings.promptOnScheduleChange) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          await AlimtalkUtils.runScheduleChangeFlow(
            provider: widget.provider,
            schedule: updated,
          );
        }
      }
      return;
    }

    // 일정 등록 시 자동 참석 금지 — 전원 미답변으로 시작
    final schedule = RoundSchedule(
      id: 'sched_\${DateTime.now().millisecondsSinceEpoch}',
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

    widget.provider.addSchedule(schedule);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('\${schedule.title} 일정이 등록되었습니다 🗓️'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        _showAlimtalkDialog(
          context: context,
          provider: widget.provider,
          scheduleId: schedule.id,
          scheduleTitle: schedule.title,
          roundDate: schedule.roundDate,
        );
      }
    }
  }`;

if (!src.includes(oldSave)) {
  if (src.includes('_isEdit) {')) {
    console.log('save already patched');
  } else {
    console.error('save block not found');
    process.exit(1);
  }
} else {
  src = src.replace(oldSave, newSave);
  console.log('patched save for edit+alimtalk');
}

// Date picker: allow editing past-ish dates when editing (use existing date as initial)
src = src.replace(
  `  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),`,
  `  Future<void> _pickDate() async {
    final initial = _selectedDate ?? DateTime.now().add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(DateTime.now()) ? DateTime.now() : initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),`,
);

fs.writeFileSync(file, src, 'utf8');
console.log('done');
