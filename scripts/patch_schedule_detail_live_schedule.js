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

const needle =
  `    return Consumer<ClubProvider>(${nl}` +
  `      builder: (context, provider, _) {${nl}` +
  `        final myRes = provider.myResponse(schedule.id);${nl}`;
const insert =
  `    return Consumer<ClubProvider>(${nl}` +
  `      builder: (context, provider, _) {${nl}` +
  `        final schedule =${nl}` +
  `            provider.scheduleById(this.schedule.id) ?? this.schedule;${nl}` +
  `        final myRes = provider.myResponse(schedule.id);${nl}`;

const classMarker = 'class ScheduleDetailScreen extends StatelessWidget {';
const classAt = src.indexOf(classMarker);
if (classAt < 0) {
  console.error('ScheduleDetailScreen class missing');
  process.exit(1);
}

if (src.includes('provider.scheduleById(this.schedule.id)')) {
  console.log('already patched');
  process.exit(0);
}

const at = src.indexOf(needle, classAt);
if (at < 0) {
  console.error('ScheduleDetailScreen Consumer needle missing');
  process.exit(1);
}

const next = src.slice(0, at) + insert + src.slice(at + needle.length);
fs.writeFileSync(file, next, 'utf8');
console.log('patched ScheduleDetailScreen live schedule');
