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
// 목록 카드 구간은 \r\r\n, 상세 헤더는 \r\n 이 섞여 있다.
const nList = '\r\r\n';
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
  `_ScheduleDateTile(date: d, isPast: isPast),`,
  `_ScheduleDateTile(date: d, isPast: false),`,
  'date tile always upcoming colors',
);

replaceOnce(
  `color: isPast ? AppColors.inkSoft : AppColors.ink,`,
  `color: AppColors.ink,`,
  'title always ink',
);

replaceOnce(
  `                            _ScheduleDdayBadge(${nList}` +
    `                              label: isPast ? '완료' : schedule.dDayText,${nList}` +
    `                              isPast: isPast,${nList}` +
    `                            ),`,
  `                            _ScheduleDdayBadge(${nList}` +
    `                              label: isPast ? '완료' : schedule.dDayText,${nList}` +
    `                              isPast: false,${nList}` +
    `                            ),`,
  'badge upcoming red style',
);

replaceOnce(
  `                        Row(children: [${nList}` +
    `                          const Icon(Icons.location_on_outlined,${nList}` +
    `                              size: 13, color: Color(0xFF9CA3AF)),${nList}` +
    `                          const SizedBox(width: 3),${nList}` +
    `                          Expanded(${nList}` +
    `                            child: Text(${nList}` +
    `                              schedule.courseName,${nList}` +
    `                              maxLines: 1,${nList}` +
    `                              overflow: TextOverflow.ellipsis,${nList}` +
    `                              style: const TextStyle(${nList}` +
    `                                  fontSize: 12, color: Color(0xFF9CA3AF)),${nList}` +
    `                            ),${nList}` +
    `                          ),${nList}` +
    `                        ]),`,
  `                        Row(children: [${nList}` +
    `                          const Icon(Icons.location_on_outlined,${nList}` +
    `                              size: 13, color: Color(0xFF9CA3AF)),${nList}` +
    `                          const SizedBox(width: 3),${nList}` +
    `                          Expanded(${nList}` +
    `                            child: Text(${nList}` +
    `                              schedule.courseName,${nList}` +
    `                              maxLines: 1,${nList}` +
    `                              overflow: TextOverflow.ellipsis,${nList}` +
    `                              style: const TextStyle(${nList}` +
    `                                  fontSize: 12, color: Color(0xFF9CA3AF)),${nList}` +
    `                            ),${nList}` +
    `                          ),${nList}` +
    `                        ]),${nList}` +
    `                        const SizedBox(height: 4),${nList}` +
    `                        Row(children: [${nList}` +
    `                          const Icon(Icons.groups_outlined,${nList}` +
    `                              size: 13, color: Color(0xFF9CA3AF)),${nList}` +
    `                          const SizedBox(width: 3),${nList}` +
    `                          Text(${nList}` +
    `                            '팀수 \${schedule.teamCount}',${nList}` +
    `                            style: const TextStyle(${nList}` +
    `                                fontSize: 12, color: Color(0xFF9CA3AF)),${nList}` +
    `                          ),${nList}` +
    `                        ]),`,
  'list card team count',
);

replaceOnce(
  `            preferredSize: const Size.fromHeight(128),`,
  `            preferredSize: const Size.fromHeight(160),`,
  'detail header taller',
);

replaceOnce(
  `                                      '\${_fmtDate(schedule.roundDate)}  \${schedule.teeTime.isEmpty ? '--:--' : schedule.teeTime} 티오프',${nHead}` +
    `                                      style: const TextStyle(${nHead}` +
    `                                        color: Colors.white,${nHead}` +
    `                                        fontSize: 14,${nHead}` +
    `                                        fontWeight: FontWeight.w700,${nHead}` +
    `                                        height: 1.1,${nHead}` +
    `                                      ),${nHead}` +
    `                                      maxLines: 1,${nHead}` +
    `                                      overflow: TextOverflow.ellipsis,${nHead}` +
    `                                    ),${nHead}` +
    `                                  ),${nHead}` +
    `                                ],${nHead}` +
    `                              ),${nHead}` +
    `                            ],${nHead}` +
    `                          ),`,
  `                                      '\${_fmtDate(schedule.roundDate)}  \${schedule.teeTime.isEmpty ? '--:--' : schedule.teeTime} 티오프',${nHead}` +
    `                                      style: const TextStyle(${nHead}` +
    `                                        color: Colors.white,${nHead}` +
    `                                        fontSize: 14,${nHead}` +
    `                                        fontWeight: FontWeight.w700,${nHead}` +
    `                                        height: 1.1,${nHead}` +
    `                                      ),${nHead}` +
    `                                      maxLines: 1,${nHead}` +
    `                                      overflow: TextOverflow.ellipsis,${nHead}` +
    `                                    ),${nHead}` +
    `                                  ),${nHead}` +
    `                                ],${nHead}` +
    `                              ),${nHead}` +
    `                              const SizedBox(height: 6),${nHead}` +
    `                              Row(${nHead}` +
    `                                children: [${nHead}` +
    `                                  Container(${nHead}` +
    `                                    width: 24,${nHead}` +
    `                                    height: 24,${nHead}` +
    `                                    decoration: BoxDecoration(${nHead}` +
    `                                      color: AppColors.accent${nHead}` +
    `                                          .withValues(alpha: 0.20),${nHead}` +
    `                                      borderRadius: BorderRadius.circular(7),${nHead}` +
    `                                    ),${nHead}` +
    `                                    child: const Icon(Icons.groups_rounded,${nHead}` +
    `                                        color: AppColors.accent, size: 14),${nHead}` +
    `                                  ),${nHead}` +
    `                                  const SizedBox(width: 6),${nHead}` +
    `                                  Expanded(${nHead}` +
    `                                    child: Text(${nHead}` +
    `                                      '팀수 \${schedule.teamCount}',${nHead}` +
    `                                      style: const TextStyle(${nHead}` +
    `                                        color: Colors.white,${nHead}` +
    `                                        fontSize: 14,${nHead}` +
    `                                        fontWeight: FontWeight.w700,${nHead}` +
    `                                        height: 1.1,${nHead}` +
    `                                      ),${nHead}` +
    `                                      maxLines: 1,${nHead}` +
    `                                      overflow: TextOverflow.ellipsis,${nHead}` +
    `                                    ),${nHead}` +
    `                                  ),${nHead}` +
    `                                ],${nHead}` +
    `                              ),${nHead}` +
    `                            ],${nHead}` +
    `                          ),`,
  'detail header team count',
);

fs.writeFileSync(file, src, 'utf8');

const lines = src.split(/\r?\n/);
const markers = [
  'class ScheduleDetailScreen',
  'Widget _buildMyResponseCard',
  'class _RsvpWaitingCard ',
  'class _AttendanceCard ',
  'class _GroupViewBannerCard',
  'class _ScoreAwardBannerCard',
  'class _GroupSelectSheet',
];
for (const m of markers) {
  const i = lines.findIndex((l) => l.includes(m));
  console.log(`${m}: ${i + 1}`);
}
console.log('patched', file);
