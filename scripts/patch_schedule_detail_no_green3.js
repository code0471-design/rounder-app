// 일정 상세 3차 — 상세에서 여는 '조 선택' 바텀시트 팔레트 정리.
//   node scripts/patch_schedule_detail_no_green3.js

const fs = require('fs');
const path = require('path');

const FILE = path.join('lib', 'screens', 'schedule', 'schedule_screen.dart');
let src = fs.readFileSync(FILE, 'utf8');
const eol = src.includes('\r\n') ? '\r\n' : '\n';
const nl = (s) => s.replace(/\r?\n/g, eol);

let applied = 0;
const failed = [];

function replaceExactly(label, from, to, expected) {
  const a = nl(from);
  const parts = src.split(a);
  if (parts.length - 1 !== expected) {
    failed.push(`${label} (matches=${parts.length - 1}, expected=${expected})`);
    return;
  }
  src = parts.join(nl(to));
  applied++;
}

// 조 배지 색은 _GroupViewBannerCard 와 같은 웜 계열로 맞춘다.
replaceExactly(
  '조 선택 시트 팔레트',
  `  static const List<Color> _groupColors = [
    AppColors.primary, AppColors.primaryLight, Color(0xFFE65100),
    Color(0xFF6A1B9A), Color(0xFF00838F), Color(0xFFC62828),
  ];`,
  `  // 조편성 카드와 같은 웜 계열. 조 번호가 두 화면에서 같은 색으로 보인다.
  static const List<Color> _groupColors = [
    AppColors.goldDeep, AppColors.charcoal, Color(0xFFB08A2E),
    Color(0xFF6B6459), Color(0xFF8C6239), Color(0xFF3F3B33),
  ];`,
  1,
);

replaceExactly(
  '조 선택 시트 헤더 아이콘',
  `                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.groups_rounded,
                    color: AppColors.primary, size: 22),`,
  `                  color: AppColors.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.groups_rounded,
                    color: AppColors.goldDeep, size: 22),`,
  1,
);

if (failed.length) {
  console.error('실패한 패치:');
  for (const f of failed) console.error('  - ' + f);
  process.exit(1);
}

fs.writeFileSync(FILE, src, 'utf8');
console.log(`적용 ${applied}건 · ${FILE}`);
