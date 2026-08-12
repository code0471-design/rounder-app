const fs = require('fs');
const path = require('path');
const file = path.join(__dirname, '..', 'lib', 'screens', 'schedule', 'schedule_screen.dart');
let s = fs.readFileSync(file, 'utf8');

const old = `    await Future.delayed(const Duration(milliseconds: 400));
    final rootCtx = AppNavigator.context;
    if (rootCtx != null) {
      _showAlimtalkDialog(
        context: rootCtx,
        provider: provider,
        scheduleId: schedule.id,
        scheduleTitle: schedule.title,
        roundDate: schedule.roundDate,
      );
    }
  }`;

const neu = `    await Future.delayed(const Duration(milliseconds: 400));
    await AlimtalkUtils.runAttendanceFlow(
      provider: provider,
      schedule: schedule,
    );
  }`;

if (!s.includes(old)) {
  console.error('create alimtalk block not found');
  process.exit(1);
}
s = s.replace(old, neu);
fs.writeFileSync(file, s, 'utf8');
console.log('patched create to use runAttendanceFlow');
