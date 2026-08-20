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

const src = fs.readFileSync(file, 'utf8');
const nl = src.includes('\r\n') ? '\r\n' : '\n';

const marker = `${nl}                      // ── ④ 스코어/시상 카드 ──${nl}`;
const scoreAt = src.indexOf(marker);
if (scoreAt < 0) {
  console.error('score card marker missing');
  process.exit(1);
}

const attendanceBlock =
  `${nl}                      // ── 참석 현황 카드 ──${nl}` +
  `                      _AttendanceCard(schedule: schedule),${nl}` +
  `${nl}` +
  `                      const SizedBox(height: 16),${nl}`;

const attendanceAt = src.indexOf(attendanceBlock);
if (attendanceAt < 0) {
  if (
    src.indexOf('_AttendanceCard(schedule: schedule)') <
      src.indexOf('_ScoreAwardBannerCard(schedule: schedule, isPast: isPast)') &&
    src.indexOf('_AttendanceCard(schedule: schedule)') > 0
  ) {
    console.log('already ordered: attendance above score');
    process.exit(0);
  }
  console.error('attendance block missing');
  process.exit(1);
}

const withoutAttendance =
  src.slice(0, attendanceAt) + src.slice(attendanceAt + attendanceBlock.length);

const scoreAt2 = withoutAttendance.indexOf(marker);
if (scoreAt2 < 0) {
  console.error('score card marker missing after removal');
  process.exit(1);
}

const insert =
  `${nl}                      // ── 참석 현황 카드 (스코어/시상 위) ──${nl}` +
  `                      _AttendanceCard(schedule: schedule),${nl}` +
  `${nl}` +
  `                      const SizedBox(height: 16),${nl}` +
  marker;

const next =
  withoutAttendance.slice(0, scoreAt2) +
  insert +
  withoutAttendance.slice(scoreAt2 + marker.length);

fs.writeFileSync(file, next, 'utf8');
console.log('moved _AttendanceCard above _ScoreAwardBannerCard');
