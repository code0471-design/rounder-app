// 일정 상세 2차 — 다이얼로그·바텀시트·응답 마감 카드에 남은 그린 정리.
//   node scripts/patch_schedule_detail_no_green2.js
//
// 같은 다이얼로그가 일정 목록/상세에 두 벌로 복사돼 있다. 한쪽만 고치면
// 같은 화면인데 색이 갈리므로 두 벌을 함께 바꾼다.
//
// alpha 0.06 카드 그림자(AppColors.primary)는 눈에 보이지 않고
// 모든 카드가 공유하는 톤이라 그대로 둔다.

const fs = require('fs');
const path = require('path');

const FILE = path.join('lib', 'screens', 'schedule', 'schedule_screen.dart');
let src = fs.readFileSync(FILE, 'utf8');
const eol = src.includes('\r\n') ? '\r\n' : '\n';
const nl = (s) => s.replace(/\r?\n/g, eol);

let applied = 0;
const failed = [];

/** [expected] 개만큼 정확히 나올 때만 전부 바꾼다. */
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

// ── 참석/불참 선택 시트 (목록·상세 2벌) ──
replaceExactly(
  '응답 시트 참석 버튼',
  `                  label: '참석',
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,`,
  `                  label: '참석',
                  icon: Icons.check_circle_outline,
                  color: AppColors.charcoal,`,
  2,
);

// ── 참석 확인 다이얼로그 (목록·상세 2벌) ──
replaceExactly(
  '참석 확인 다이얼로그 아이콘',
  `                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: AppColors.success, size: 20),`,
  `                color: AppColors.accent.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: AppColors.goldDeep, size: 20),`,
  2,
);

replaceExactly(
  '참석 확정 버튼',
  `                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  elevation: 0,`,
  `                  backgroundColor: AppColors.charcoal,
                  foregroundColor: Colors.white,
                  elevation: 0,`,
  1,
);

// ── 응답 마감 카드 타이머 아이콘은 골드로 (나머지 sageDeep 은 차콜) ──
replaceExactly(
  '마감 카드 타이머 아이콘',
  `                            color: schedule.isRsvpClosed
                                ? AppColors.danger
                                : AppColors.sageDeep),`,
  `                            color: schedule.isRsvpClosed
                                ? AppColors.danger
                                : AppColors.goldDeep),`,
  1,
);

// ── 남은 sageDeep 전부 (정원 안내 다이얼로그 2벌 + 알림톡 시트) ──
replaceExactly(
  'sageDeep 잔여',
  `AppColors.sageDeep`,
  `AppColors.charcoal`,
  9,
);

// ── 더보기 시트 '일정 변경' ──
replaceExactly(
  '더보기 일정 변경 아이콘',
  `              leading: const Icon(Icons.edit_calendar_outlined,
                  color: AppColors.primary),`,
  `              leading: const Icon(Icons.edit_calendar_outlined,
                  color: AppColors.goldDeep),`,
  1,
);

// ── 참석 응답 마감 카드 ──
replaceExactly(
  '마감 카드 상태 라벨',
  `                              color: schedule.isRsvpClosed
                                  ? AppColors.danger
                                  : AppColors.success),`,
  `                              color: schedule.isRsvpClosed
                                  ? AppColors.danger
                                  : AppColors.goldDeep),`,
  1,
);

replaceExactly(
  '미응답 알림 스낵바',
  `                                  content: Text('미응답자 \$sent명에게 알림을 보냈습니다 🔔'),
                                  backgroundColor: AppColors.primary,`,
  `                                  content: Text('미응답자 \$sent명에게 알림을 보냈습니다 🔔'),
                                  backgroundColor: AppColors.charcoal,`,
  1,
);

replaceExactly(
  '알림 보내기 버튼',
  `                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 4)),`,
  `                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.goldDeep,
                                padding: const EdgeInsets.symmetric(horizontal: 4)),`,
  1,
);

if (failed.length) {
  console.error('실패한 패치:');
  for (const f of failed) console.error('  - ' + f);
  process.exit(1);
}

fs.writeFileSync(FILE, src, 'utf8');
console.log(`적용 ${applied}건 · ${FILE}`);
