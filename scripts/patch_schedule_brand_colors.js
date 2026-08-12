/**
 * 일정 상세 하단 옛 주황/보라 액센트 → 브랜드 그린으로 교체.
 * schedule_screen.dart 는 StrReplace 금지 — Node UTF-8 패치만 사용.
 */
const fs = require('fs');
const path = require('path');

const p = path.join(__dirname, '..', 'lib', 'screens', 'schedule', 'schedule_screen.dart');
let s = fs.readFileSync(p, 'utf8');
const before = s;

// 스코어 카드 주황
const orangeReplacements = [
  ['const Color(0xFFF97316)', 'AppColors.primary'],
  ['Color(0xFFF97316)', 'AppColors.primary'],
  ['const Color(0xFFEA580C)', 'AppColors.primaryDark'],
  ['Color(0xFFEA580C)', 'AppColors.primaryDark'],
  // 시상 보라
  ['const Color(0xFF7C3AED)', 'AppColors.primary'],
  ['Color(0xFF7C3AED)', 'AppColors.primary'],
  ['const Color(0xFF6D28D9)', 'AppColors.primaryDark'],
  ['Color(0xFF6D28D9)', 'AppColors.primaryDark'],
  // 사진 섹션 주황 그라데이션/버튼
  ['Color(0xFFFF6D00)', 'AppColors.primary'],
  ['const Color(0xFFFF6D00)', 'AppColors.primary'],
  ['Color(0xFFFFAB40)', 'AppColors.mintBright'],
  ['const Color(0xFFFFAB40)', 'AppColors.mintBright'],
];

for (const [from, to] of orangeReplacements) {
  s = s.split(from).join(to);
}

// Colors.orange leftover in schedule detail area
s = s.replace(
  /backgroundColor:\s*Colors\.orange/g,
  'backgroundColor: AppColors.primary',
);

if (s === before) {
  console.log('No color changes applied (already patched?)');
} else {
  fs.writeFileSync(p, s);
  console.log('OK brand colors patched');
}

// sanity: forbidden accents must be gone from score/photo banners
const forbidden = ['0xFFF97316', '0xFF7C3AED', '0xFFFF6D00', '0xFF6D28D9', '0xFFEA580C'];
const left = forbidden.filter((c) => s.includes(c));
if (left.length) {
  console.warn('Still present:', left.join(', '));
  process.exitCode = 2;
} else {
  console.log('Forbidden accent hex cleared');
}
