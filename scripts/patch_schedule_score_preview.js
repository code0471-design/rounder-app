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
const nHead = '\r\n';

function replaceOnce(oldStr, newStr, label) {
  const n = src.split(oldStr).length - 1;
  if (n !== 1) {
    console.error(`${label}: expected 1 match, got ${n}`);
    process.exit(1);
  }
  src = src.replace(oldStr, newStr);
}

replaceOnce(
  `import '../records/score_award_screen.dart';${nHead}`,
  `import '../records/score_award_screen.dart';${nHead}` +
    `import '../../widgets/score_award_results.dart';${nHead}`,
  'import preview widget',
);

replaceOnce(
  `              isPast${nHead}` +
    `                  ? '모든 회원이 스코어를 확인하고 시상 내역을 볼 수 있어요'${nHead}` +
    `                  : '조를 선택하면 해당 조 멤버의 스코어를 입력할 수 있어요',${nHead}` +
    `              style: const TextStyle(${nHead}` +
    `                color: AppColors.textTertiary,${nHead}` +
    `                fontSize: 12,${nHead}` +
    `              ),${nHead}` +
    `            ),${nHead}` +
    `            const SizedBox(height: 14),`,
  `              isPast${nHead}` +
    `                  ? '모든 회원이 스코어를 확인하고 시상 내역을 볼 수 있어요'${nHead}` +
    `                  : '조를 선택하면 해당 조 멤버의 스코어를 입력할 수 있어요',${nHead}` +
    `              style: const TextStyle(${nHead}` +
    `                color: AppColors.textTertiary,${nHead}` +
    `                fontSize: 12,${nHead}` +
    `              ),${nHead}` +
    `            ),${nHead}` +
    `            ScoreAwardResultsPreview(scheduleId: schedule.id),${nHead}` +
    `            const SizedBox(height: 14),`,
  'insert results preview',
);

fs.writeFileSync(file, src, 'utf8');
const lines = src.split(/\r?\n/);
const markers = [
  'class ScheduleDetailScreen',
  'class _GroupViewBannerCard',
  'class _ScoreAwardBannerCard',
  'class _GroupSelectSheet',
];
for (const m of markers) {
  const i = lines.findIndex((l) => l.includes(m));
  console.log(`${m}: ${i + 1}`);
}
console.log('patched', file);
