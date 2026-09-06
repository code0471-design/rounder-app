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
const nl = src.includes('\r\n') ? '\r\n' : '\n';

function replaceOnce(oldStr, newStr, label) {
  const n = src.split(oldStr).length - 1;
  if (n !== 1) {
    console.error(`${label}: expected 1 match, got ${n}`);
    process.exit(1);
  }
  src = src.replace(oldStr, newStr);
}

replaceOnce(
  `                          isFinalized${nl}` +
    `                              ? '\${schedule.teamCount}개 조 확정 완료 — 탭해서 확인'${nl}` +
    `                              : isAdmin${nl}` +
    `                                  ? '탭해서 조편성 시작하기'${nl}` +
    `                                  : '총무가 확정하면 여기서 확인할 수 있어요',${nl}` +
    `                          style: TextStyle(${nl}` +
    `                            fontSize: 12,${nl}` +
    `                            color: isFinalized${nl}` +
    `                                ? Colors.white.withValues(alpha: 0.9)${nl}` +
    `                                : AppColors.textTertiary,${nl}` +
    `                          ),`,
  `                          isFinalized${nl}` +
    `                              ? '\${schedule.teamCount}개 조 확정완료\\n탭해서 확인하세요'${nl}` +
    `                              : isAdmin${nl}` +
    `                                  ? '탭해서 조편성 시작하기'${nl}` +
    `                                  : '총무가 확정하면 여기서 확인할 수 있어요',${nl}` +
    `                          maxLines: 2,${nl}` +
    `                          style: TextStyle(${nl}` +
    `                            fontSize: 12,${nl}` +
    `                            height: 1.35,${nl}` +
    `                            color: isFinalized${nl}` +
    `                                ? Colors.white.withValues(alpha: 0.9)${nl}` +
    `                                : AppColors.textTertiary,${nl}` +
    `                          ),`,
  'subtitle',
);

const oldBadges =
  `                  // 상태 뱃지${nl}` +
  `                  Container(${nl}` +
  `                    padding: const EdgeInsets.symmetric(${nl}` +
  `                        horizontal: 10, vertical: 5),${nl}` +
  `                    decoration: BoxDecoration(${nl}` +
  `                      color: isFinalized${nl}` +
  `                          ? AppColors.accent.withValues(alpha: 0.28)${nl}` +
  `                          : AppColors.sand,${nl}` +
  `                      borderRadius: BorderRadius.circular(20),${nl}` +
  `                    ),${nl}` +
  `                    child: Text(${nl}` +
  `                      isFinalized ? '확정 ✓' : '미확정',${nl}` +
  `                      style: TextStyle(${nl}` +
  `                        fontSize: 11,${nl}` +
  `                        fontWeight: FontWeight.w700,${nl}` +
  `                        color: isFinalized${nl}` +
  `                            ? AppColors.accent${nl}` +
  `                            : AppColors.inkSoft,${nl}` +
  `                      ),${nl}` +
  `                    ),${nl}` +
  `                  ),${nl}` +
  `                  const SizedBox(width: 4),${nl}` +
  `                  // 총무: 편집 버튼 표시${nl}` +
  `                  if (isAdmin) ...${nl}` +
  `                    [${nl}` +
  `                      Container(${nl}` +
  `                        padding: const EdgeInsets.symmetric(${nl}` +
  `                            horizontal: 8, vertical: 4),${nl}` +
  `                        decoration: BoxDecoration(${nl}` +
  `                          color: isFinalized${nl}` +
  `                              ? AppColors.accent.withValues(alpha: 0.28)${nl}` +
  `                              : AppColors.sand,${nl}` +
  `                          borderRadius: BorderRadius.circular(8),${nl}` +
  `                        ),${nl}` +
  `                        child: Row(${nl}` +
  `                          mainAxisSize: MainAxisSize.min,${nl}` +
  `                          children: [${nl}` +
  `                            Icon(${nl}` +
  `                              Icons.edit_rounded,${nl}` +
  `                              size: 13,${nl}` +
  `                              color: isFinalized${nl}` +
  `                                  ? AppColors.accent${nl}` +
  `                                  : AppColors.goldDeep,${nl}` +
  `                            ),${nl}` +
  `                            const SizedBox(width: 3),${nl}` +
  `                            Text(${nl}` +
  `                              '편집',${nl}` +
  `                              style: TextStyle(${nl}` +
  `                                fontSize: 11,${nl}` +
  `                                fontWeight: FontWeight.w700,${nl}` +
  `                                color: isFinalized${nl}` +
  `                                    ? AppColors.accent${nl}` +
  `                                    : AppColors.goldDeep,${nl}` +
  `                              ),${nl}` +
  `                            ),${nl}` +
  `                          ],${nl}` +
  `                        ),${nl}` +
  `                      ),${nl}` +
  `                    ]${nl}` +
  `                  else ...${nl}` +
  `                    [${nl}` +
  `                      Icon(${nl}` +
  `                        Icons.chevron_right_rounded,${nl}` +
  `                        color: isFinalized${nl}` +
  `                            ? Colors.white.withValues(alpha: 0.7)${nl}` +
  `                            : AppColors.textTertiary,${nl}` +
  `                      ),${nl}` +
  `                    ],`;

const newBadges =
  `                  Column(${nl}` +
  `                    mainAxisSize: MainAxisSize.min,${nl}` +
  `                    crossAxisAlignment: CrossAxisAlignment.end,${nl}` +
  `                    children: [${nl}` +
  `                      Container(${nl}` +
  `                        padding: const EdgeInsets.symmetric(${nl}` +
  `                            horizontal: 10, vertical: 5),${nl}` +
  `                        decoration: BoxDecoration(${nl}` +
  `                          color: isFinalized${nl}` +
  `                              ? AppColors.accent.withValues(alpha: 0.28)${nl}` +
  `                              : AppColors.sand,${nl}` +
  `                          borderRadius: BorderRadius.circular(20),${nl}` +
  `                        ),${nl}` +
  `                        child: Text(${nl}` +
  `                          isFinalized ? '확정 ✓' : '미확정',${nl}` +
  `                          style: TextStyle(${nl}` +
  `                            fontSize: 11,${nl}` +
  `                            fontWeight: FontWeight.w700,${nl}` +
  `                            color: isFinalized${nl}` +
  `                                ? AppColors.accent${nl}` +
  `                                : AppColors.inkSoft,${nl}` +
  `                          ),${nl}` +
  `                        ),${nl}` +
  `                      ),${nl}` +
  `                      if (isAdmin) ...[${nl}` +
  `                        const SizedBox(height: 6),${nl}` +
  `                        Container(${nl}` +
  `                          padding: const EdgeInsets.symmetric(${nl}` +
  `                              horizontal: 8, vertical: 4),${nl}` +
  `                          decoration: BoxDecoration(${nl}` +
  `                            color: isFinalized${nl}` +
  `                                ? AppColors.accent.withValues(alpha: 0.28)${nl}` +
  `                                : AppColors.sand,${nl}` +
  `                            borderRadius: BorderRadius.circular(8),${nl}` +
  `                          ),${nl}` +
  `                          child: Row(${nl}` +
  `                            mainAxisSize: MainAxisSize.min,${nl}` +
  `                            children: [${nl}` +
  `                              Icon(${nl}` +
  `                                Icons.edit_rounded,${nl}` +
  `                                size: 13,${nl}` +
  `                                color: isFinalized${nl}` +
  `                                    ? AppColors.accent${nl}` +
  `                                    : AppColors.goldDeep,${nl}` +
  `                              ),${nl}` +
  `                              const SizedBox(width: 3),${nl}` +
  `                              Text(${nl}` +
  `                                '편집',${nl}` +
  `                                style: TextStyle(${nl}` +
  `                                  fontSize: 11,${nl}` +
  `                                  fontWeight: FontWeight.w700,${nl}` +
  `                                  color: isFinalized${nl}` +
  `                                      ? AppColors.accent${nl}` +
  `                                      : AppColors.goldDeep,${nl}` +
  `                                ),${nl}` +
  `                              ),${nl}` +
  `                            ],${nl}` +
  `                          ),${nl}` +
  `                        ),${nl}` +
  `                      ] else ...[${nl}` +
  `                        const SizedBox(height: 4),${nl}` +
  `                        Icon(${nl}` +
  `                          Icons.chevron_right_rounded,${nl}` +
  `                          color: isFinalized${nl}` +
  `                              ? Colors.white.withValues(alpha: 0.7)${nl}` +
  `                              : AppColors.textTertiary,${nl}` +
  `                        ),${nl}` +
  `                      ],${nl}` +
  `                    ],${nl}` +
  `                  ),`;

replaceOnce(oldBadges, newBadges, 'badges');

fs.writeFileSync(file, src);
console.log('patched group banner');
