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
const needle = "m.status == '활성' && m.id != provider.currentUserId";
const count = src.split(needle).length - 1;
if (count === 0) {
  console.error('needle not found');
  process.exit(1);
}
src = src.split(needle).join("m.status == '활성'");
fs.writeFileSync(file, src, 'utf8');
console.log('patched schedule alimtalk self-exclude x' + count);
