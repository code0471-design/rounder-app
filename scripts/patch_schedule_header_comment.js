// 배너가 더 이상 딥그린이 아니므로 주석을 실제 색과 맞춘다.
//   node scripts/patch_schedule_header_comment.js

const fs = require('fs');
const path = require('path');

const FILE = path.join('lib', 'screens', 'schedule', 'schedule_screen.dart');
let src = fs.readFileSync(FILE, 'utf8');

const from = '// ── 슬림 AppBar 딥그린 카드형';
const to = '// ── 슬림 AppBar 웜차콜 카드형';

const parts = src.split(from);
if (parts.length !== 2) {
  console.error(`실패: 주석 매칭 ${parts.length - 1}건`);
  process.exit(1);
}

fs.writeFileSync(FILE, parts.join(to), 'utf8');
console.log(`적용 1건 · ${FILE}`);
