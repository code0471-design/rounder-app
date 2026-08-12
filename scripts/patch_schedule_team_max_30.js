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
const from = 'if (next < 1) return;';
const to = 'if (next < 1 || next > 30) return;';

if (!src.includes(from)) {
  if (src.includes(to)) {
    console.log('already patched');
    process.exit(0);
  }
  console.error('pattern not found');
  process.exit(1);
}

src = src.replace(from, to);
fs.writeFileSync(file, src, 'utf8');
console.log('patched schedule team max 30');
