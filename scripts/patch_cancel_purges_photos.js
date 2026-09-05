#!/usr/bin/env node
// schedule_screen.dart 는 UTF-8 안전 패치만 허용 (.cursor/rules/commit-small-ui-fixes.mdc)
// 일정 취소 확인 얼럿에 "사진 N장도 함께 삭제" 경고 + 결과 스낵바 추가.
'use strict';

const fs = require('fs');
const path = require('path');

const TARGET = path.join(
  __dirname,
  '..',
  'lib',
  'screens',
  'schedule',
  'schedule_screen.dart'
);

let src = fs.readFileSync(TARGET, 'utf8');
const eol = src.includes('\r\n') ? '\r\n' : '\n';

/** LF 로 쓴 패턴을 대상 파일의 EOL 에 맞춘다. */
const nl = (s) => s.split('\n').join(eol);

const FIND = nl(`  void _confirmCancel(BuildContext context, ClubProvider provider) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('일정 취소'),
        content: Text('\${schedule.title} 일정을 취소하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('닫기'),
          ),
          ElevatedButton(
            onPressed: () {
              final parentNav = Navigator.of(context);
              Navigator.of(dialogCtx).pop();
              provider.cancelSchedule(schedule.id);
              if (parentNav.canPop()) parentNav.pop();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white),
            child: const Text('취소 확정'),
          ),
        ],
      ),
    );
  }`);

const REPLACE = nl(`  void _confirmCancel(BuildContext context, ClubProvider provider) {
    // 취소하면 이 일정의 사진도 함께 지운다. 되돌릴 수 없으니 장수를 먼저 알린다.
    final photoCount = provider.schedulePhotoCount(schedule.id);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('일정 취소'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('\${schedule.title} 일정을 취소하시겠습니까?'),
            if (photoCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 18, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '이 일정의 사진 \$photoCount장도 함께 삭제됩니다.\\n'
                        '삭제한 사진은 되돌릴 수 없습니다.',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('닫기'),
          ),
          ElevatedButton(
            onPressed: () {
              final parentNav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(dialogCtx).pop();
              final purged = provider.cancelSchedule(schedule.id);
              if (parentNav.canPop()) parentNav.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(purged > 0
                      ? '일정을 취소하고 사진 \$purged장을 삭제했습니다'
                      : '일정을 취소했습니다'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white),
            child: const Text('취소 확정'),
          ),
        ],
      ),
    );
  }`);

if (src.includes(REPLACE)) {
  console.log('[patch] 이미 적용됨 — 변경 없음');
  process.exit(0);
}

const hits = src.split(FIND).length - 1;
if (hits !== 1) {
  console.error(
    `[patch] 실패: _confirmCancel 원본을 ${hits}번 찾았습니다 (1번이어야 함).` +
      '\n  파일이 이미 수정됐는지 확인하세요.'
  );
  process.exit(1);
}

src = src.replace(FIND, REPLACE);

// ── 인바리언트 자체 점검 (test/schedule_detail_ui_invariants_test.dart) ──
const start = src.indexOf('void _confirmCancel');
const end = src.indexOf('String _fmtDate(DateTime d)', start);
const fn = src.slice(start, end);
const checks = [
  ['builder: (dialogCtx)', true],
  ['Navigator.of(dialogCtx).pop()', true],
  ["child: const Text('취소 확정')", true],
  ['provider.schedulePhotoCount(schedule.id)', true],
  ['final purged = provider.cancelSchedule(schedule.id)', true],
];
for (const [needle, want] of checks) {
  if (fn.includes(needle) !== want) {
    console.error(`[patch] 검증 실패: "${needle}" 기대=${want}`);
    process.exit(1);
  }
}
if (fn.includes('Navigator.pop(context);' + eol + '              Navigator.pop(context);')) {
  console.error('[patch] 검증 실패: 부모를 두 번 pop 합니다');
  process.exit(1);
}

fs.writeFileSync(TARGET, src, 'utf8');
console.log('[patch] _confirmCancel 갱신 완료 (사진 삭제 경고 + 결과 안내)');
