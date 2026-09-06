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
const nl = '\r\n';

function replaceOnce(oldStr, newStr, label) {
  const n = src.split(oldStr).length - 1;
  if (n !== 1) {
    console.error(`${label}: expected 1 match, got ${n}`);
    process.exit(1);
  }
  src = src.replace(oldStr, newStr);
}

replaceOnce(
  `import '../../widgets/reservation_sms_fill_banner.dart';${nl}`,
  `import '../../widgets/reservation_sms_fill_banner.dart';${nl}` +
    `import 'past_schedule_import_screen.dart';${nl}`,
  'import past import screen',
);

replaceOnce(
  `            children: [${nl}` +
    `              // ── 탭바 (디자인: border-bottom 1px) ──${nl}` +
    `              Container(`,
  `            children: [${nl}` +
    `              if (isAdmin)${nl}` +
    `                PastScheduleImportBanner(${nl}` +
    `                  clubId: provider.selectedClub.id,${nl}` +
    `                  onStart: () => openPastScheduleImport(context),${nl}` +
    `                ),${nl}` +
    `              // ── 탭바 (디자인: border-bottom 1px) ──${nl}` +
    `              Container(`,
  'banner above tabs',
);

replaceOnce(
  `                    _ScheduleList(${nl}` +
    `                        schedules: provider.pastSchedules,${nl}` +
    `                        isPast: true,${nl}` +
    `                        clubId: provider.selectedClub.id),`,
  `                    _ScheduleList(${nl}` +
    `                        schedules: provider.pastSchedules,${nl}` +
    `                        isPast: true,${nl}` +
    `                        clubId: provider.selectedClub.id,${nl}` +
    `                        onImportPast: isAdmin${nl}` +
    `                            ? () => openPastScheduleImport(context)${nl}` +
    `                            : null),`,
  'past list import callback',
);

replaceOnce(
  `  final String? clubId;${nl}` +
    `  const _ScheduleList({required this.schedules, required this.isPast, this.clubId});`,
  `  final String? clubId;${nl}` +
    `  final VoidCallback? onImportPast;${nl}` +
    `  const _ScheduleList({${nl}` +
    `    required this.schedules,${nl}` +
    `    required this.isPast,${nl}` +
    `    this.clubId,${nl}` +
    `    this.onImportPast,${nl}` +
    `  });`,
  'list constructor',
);

replaceOnce(
  `            Text(${nl}` +
    `              isPast ? '지난 일정이 없습니다' : '예정된 일정이 없습니다',${nl}` +
    `              style: const TextStyle(${nl}` +
    `                  color: AppColors.textSecondary, fontSize: 15),${nl}` +
    `            ),${nl}` +
    `          ],${nl}` +
    `        ),`,
  `            Text(${nl}` +
    `              isPast ? '지난 일정이 없습니다' : '예정된 일정이 없습니다',${nl}` +
    `              style: const TextStyle(${nl}` +
    `                  color: AppColors.textSecondary, fontSize: 15),${nl}` +
    `            ),${nl}` +
    `            if (isPast && widget.onImportPast != null) ...[${nl}` +
    `              const SizedBox(height: 16),${nl}` +
    `              TextButton(${nl}` +
    `                onPressed: widget.onImportPast,${nl}` +
    `                child: const Text(${nl}` +
    `                  '올해 지난 일정 일괄 등록',${nl}` +
    `                  style: TextStyle(${nl}` +
    `                      fontWeight: FontWeight.w700,${nl}` +
    `                      color: Color(0xFF191F28)),${nl}` +
    `                ),${nl}` +
    `              ),${nl}` +
    `            ],${nl}` +
    `          ],${nl}` +
    `        ),`,
  'empty past CTA',
);

fs.writeFileSync(file, src, 'utf8');
const lines = src.split(/\r?\n/);
const markers = [
  'class ScheduleDetailScreen',
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
