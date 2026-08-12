const fs = require('fs');
const path = require('path');
const file = path.join(__dirname, '..', 'lib/providers/club_provider.dart');
let src = fs.readFileSync(file, 'utf8');
const old = [
  '    final existing = schedule.responses.indexWhere((r) => r.memberId == memberId);',
  '    final newResponses = List<AttendanceResponse>.from(schedule.responses);',
  '    if (existing != -1) {',
  '      newResponses[existing] = newResponse;',
  '    } else {',
  '      newResponses.add(newResponse);',
  '    }',
  '    _schedules[idx] = schedule.copyWith(responses: newResponses);',
  '',
  '    final club = _myClubs.where((c) => c.id == schedule.clubId).firstOrNull ??',
].join('\n');
const neu = [
  '    final existing = schedule.responses.indexWhere((r) => r.memberId == memberId);',
  '    final prev = existing != -1 ? schedule.responses[existing].response : null;',
  '    final newResponses = List<AttendanceResponse>.from(schedule.responses);',
  '    if (existing != -1) {',
  '      newResponses[existing] = newResponse;',
  '    } else {',
  '      newResponses.add(newResponse);',
  '    }',
  '    _schedules[idx] = schedule.copyWith(responses: newResponses);',
  '',
  '    _syncAttendancePoints(',
  '      memberId: memberId,',
  '      scheduleId: scheduleId,',
  '      scheduleTitle: schedule.displayTitle,',
  '      prev: prev,',
  '      response: response,',
  '    );',
  '',
  '    final club = _myClubs.where((c) => c.id == schedule.clubId).firstOrNull ??',
].join('\n');
if (!src.includes(old)) {
  if (src.includes('_syncAttendancePoints(\n      memberId: memberId,')) {
    console.log('already patched');
    process.exit(0);
  }
  console.error('FAIL pattern');
  process.exit(1);
}
fs.writeFileSync(file, src.replace(old, neu), 'utf8');
console.log('OK');
