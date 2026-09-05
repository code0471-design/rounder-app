// 일정 상세 4차 — 쓰이지 않게 된 조편성 색 상수 제거.
//   node scripts/patch_schedule_detail_no_green4.js

const fs = require('fs');
const path = require('path');

const FILE = path.join('lib', 'screens', 'schedule', 'schedule_screen.dart');
let src = fs.readFileSync(FILE, 'utf8');
const eol = src.includes('\r\n') ? '\r\n' : '\n';
const nl = (s) => s.replace(/\r?\n/g, eol);

const from = nl(`  // 조편성 팔레트 — 크림·골드·차콜 컨셉. 그린과 파스텔은 쓰지 않는다.
  static const Color _gold = AppColors.accent;
  static const Color _goldDeep = AppColors.goldDeep;
  // 조 배지는 같은 웜 계열의 명도 차이로만 구분한다.`);
const to = nl(`  // 조편성 팔레트 — 크림·골드·차콜 컨셉. 그린과 파스텔은 쓰지 않는다.
  // 조 배지는 같은 웜 계열의 명도 차이로만 구분한다.`);

const parts = src.split(from);
if (parts.length !== 2) {
  console.error(`실패: 상수 블록 매칭 ${parts.length - 1}건`);
  process.exit(1);
}

fs.writeFileSync(FILE, parts.join(to), 'utf8');
console.log(`적용 1건 · ${FILE}`);
