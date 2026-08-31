/**
 * 일정 등록: 예약 문자 붙여넣기.
 * UTF-8 safe (no PowerShell / Cursor StrReplace on schedule_screen.dart).
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

if (!src.includes("import '../../widgets/reservation_sms_fill_banner.dart';")) {
  src = src.replace(
    "import '../../widgets/golf_course_field.dart';",
    "import '../../widgets/golf_course_field.dart';\nimport '../../utils/reservation_sms_parser.dart';\nimport '../../widgets/reservation_sms_fill_banner.dart';",
  );
}

const applyMethod = `
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
        _capacityCtrl.text = '\${_teamCount * 4}';
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
        content: Text('\${bits.join(' · ')}을 채웠습니다. 확인하고 등록하세요.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
`;

if (!src.includes('_applyReservationParse')) {
  const anchor = '  void _setTeamCount(int next) {';
  const idx = src.indexOf(anchor);
  if (idx < 0) {
    console.error('FAIL: _setTeamCount not found');
    process.exit(1);
  }
  src = src.slice(0, idx) + applyMethod + '\n' + src.slice(idx);
}

const banner = `                    if (!_isEdit)
                      ReservationSmsFillBanner(
                        extras: golfCoursesFromSchedules(widget.provider.schedules),
                        onFilled: _applyReservationParse,
                      ),
                    // 일정 제목`;

if (!src.includes('ReservationSmsFillBanner')) {
  if (!src.includes('                    // 일정 제목')) {
    console.error('FAIL: title comment not found');
    process.exit(1);
  }
  src = src.replace('                    // 일정 제목', banner);
}

if (src === before) {
  console.error('FAIL: no changes');
  process.exit(1);
}

fs.writeFileSync(file, src, 'utf8');
console.log('OK: reservation SMS fill wired');
