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
if (src.charCodeAt(0) === 0xfeff) src = src.slice(1);

// Normalize to \n for matching, restore original EOL at write
const eol = src.includes('\r\n') ? '\r\n' : '\n';
const norm = src.replace(/\r\n/g, '\n');

let next = norm;

if (!next.includes('final materialChanged = provider.updateSchedule(updated);')) {
  const oldA = '      provider.updateSchedule(updated);';
  const newA =
    '      final materialChanged = provider.updateSchedule(updated);';
  if (!next.includes(oldA)) {
    console.error('FAIL: updateSchedule call not found');
    process.exit(1);
  }
  next = next.replace(oldA, newA);
}

const oldB = `      if (settings.promptOnScheduleChange) {
        await Future.delayed(const Duration(milliseconds: 300));
        await AlimtalkUtils.runScheduleChangeFlow(
          provider: provider,
          schedule: updated,
        );
      }
      return;`;

const newB = `      // 제목·공지만 바뀐 경우 재참석 알림톡 생략
      if (materialChanged && settings.promptOnScheduleChange) {
        await Future.delayed(const Duration(milliseconds: 300));
        await AlimtalkUtils.runScheduleChangeFlow(
          provider: provider,
          schedule: updated,
        );
      }
      return;`;

if (next.includes('materialChanged && settings.promptOnScheduleChange')) {
  console.log('OK: already patched');
} else if (!next.includes(oldB)) {
  console.error('FAIL: promptOnScheduleChange block not found');
  process.exit(1);
} else {
  next = next.replace(oldB, newB);
  console.log('OK: schedule change alimtalk only on material fields');
}

fs.writeFileSync(file, next.replace(/\n/g, eol), 'utf8');
