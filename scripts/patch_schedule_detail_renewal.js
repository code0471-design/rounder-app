/**
 * 일정 상세 UI를 리뉴얼 톤(원클럽형 흰 카드)으로 통일한다.
 *
 * schedule_screen.dart 는 Cursor 편집/PowerShell 치환으로 건드리면 한글이 깨지므로
 * 이 스크립트로만 패치한다. 실행 후 반드시:
 *   flutter test test/schedule_detail_ui_invariants_test.dart
 *
 * 바꾸는 것 (레이아웃·순서는 그대로):
 *  1) 카드 decoration 통일 — 흰 배경 + radius 16 + divider 테두리 + 딥그린 은은한 그림자
 *  2) 섹션 제목 통일 — fontSize 15 / w800 / AppColors.ink
 *  3) 하드코딩 hex(회색·블루그레이) → AppColors 팔레트
 *  4) 아이콘을 rounded 계열로 통일
 *  5) 일정 정보 행을 아이콘 칩 + 큰 라벨/값으로 개선
 *
 * Usage: node scripts/patch_schedule_detail_renewal.js [--dry]
 */
const fs = require('fs');
const path = require('path');

const FILE = path.join(
  __dirname,
  '..',
  'lib',
  'screens',
  'schedule',
  'schedule_screen.dart',
);
const DRY = process.argv.includes('--dry');

let src = fs.readFileSync(FILE, 'utf8');
const before = src;

/** 통일 카드 decoration 본문 (들여쓰기 pad 기준) */
function cardDeco(pad) {
  return [
    `${pad}color: Colors.white,`,
    `${pad}borderRadius: BorderRadius.circular(16),`,
    `${pad}border: Border.all(color: AppColors.divider),`,
    `${pad}boxShadow: [`,
    `${pad}  BoxShadow(`,
    `${pad}    color: AppColors.primary.withValues(alpha: 0.06),`,
    `${pad}    blurRadius: 8,`,
    `${pad}    offset: const Offset(0, 2),`,
    `${pad}  ),`,
    `${pad}],`,
  ].join('\n');
}

/** 통일 섹션 제목 스타일 (pad = style 내부 들여쓰기) */
function titleStyle(pad) {
  return [
    `${pad}fontSize: 15,`,
    `${pad}fontWeight: FontWeight.w800,`,
    `${pad}color: AppColors.ink)),`,
  ].join('\n');
}

// 이 파일은 CRLF 로 저장되어 있다. 찾는 문자열의 줄바꿈을 파일과 맞춘다.
const EOL = src.includes('\r\n') ? '\r\n' : '\n';
const eol = (s) => s.split('\n').join(EOL);

const edits = [];
function edit(name, find, replace, expected = 1) {
  edits.push({ name, find: eol(find), replace: eol(replace), expected });
}

// ────────────────────────────────────────────────────────────
// 1) 카드 decoration 통일
// ────────────────────────────────────────────────────────────

// _InfoCard — radius 14 + 검정 그림자 + 테두리 없음 → 통일
edit(
  '_InfoCard 카드',
  `      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('일정 정보',`,
  `      decoration: BoxDecoration(
${cardDeco('        ')}
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('일정 정보',`,
);

// _ReviewMemoCard
edit(
  '_ReviewMemoCard 카드',
  `        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),`,
  `        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
${cardDeco('            ')}
          ),`,
);

// _RsvpWaitingCard — 참석 응답 마감 (margin 있음)
edit(
  'RSVP 마감 카드',
  `              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2)),
                  ],
                ),`,
  `              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
${cardDeco('                  ')}
                ),`,
);

// _RsvpWaitingCard — 대기 명단 (margin 없음)
edit(
  '대기 명단 카드',
  `              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2)),
                  ],
                ),`,
  `              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
${cardDeco('                  ')}
                ),`,
);

// _AttendanceCard — 테두리 없음 + 검정 그림자
edit(
  '_AttendanceCard 카드',
  `        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),`,
  `        return Container(
          decoration: BoxDecoration(
${cardDeco('            ')}
          ),`,
);

// _PhotoSection
edit(
  '_PhotoSection 카드',
  `        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),`,
  `        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
${cardDeco('            ')}
          ),`,
);

// ────────────────────────────────────────────────────────────
// 2) 섹션 제목 통일 (14 bold / 14 w700 / hex → 15 w800 ink)
// ────────────────────────────────────────────────────────────

edit(
  "'일정 정보' 제목",
  `          const Text('일정 정보',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),`,
  `          const Text('일정 정보',
              style: TextStyle(
${titleStyle('                  ')}`,
);

edit(
  "'참석 현황' 제목",
  `                    const Text('참석 현황',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),`,
  `                    const Text('참석 현황',
                        style: TextStyle(
${titleStyle('                            ')}`,
);

edit(
  "'참석 응답 마감' 제목",
  `                        Text('참석 응답 마감',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),`,
  `                        Text('참석 응답 마감',
                            style: const TextStyle(
${titleStyle('                                ')}`,
);

edit(
  "'대기 명단' 제목",
  `                        Text('대기 명단 (정원 \${schedule.maxCapacity}명)',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),`,
  `                        Text('대기 명단 (정원 \${schedule.maxCapacity}명)',
                            style: const TextStyle(
${titleStyle('                                ')}`,
);

edit(
  "'라운딩 후기 · 메모' 제목",
  `                  const Text('라운딩 후기 · 메모',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),`,
  `                  const Text('라운딩 후기 · 메모',
                      style: TextStyle(
${titleStyle('                          ')}`,
);

edit(
  "'라운딩 사진' 제목",
  `                            const Text('라운딩 사진',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),`,
  `                            const Text('라운딩 사진',
                                style: TextStyle(
${titleStyle('                                    ')}`,
);

// 조편성 배너 제목 — 골드 톤은 유지하고 굵기만 통일
edit(
  "'조편성 보기' 제목 굵기",
  `                          '조편성 보기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,`,
  `                          '조편성 보기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,`,
);

// 스코어/시상 메인 제목 — hex 회색 팔레트 → 브랜드 잉크
edit(
  '스코어/시상 메인 제목',
  `              style: const TextStyle(
                color: Color(0xFF222222),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),`,
  `              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),`,
);

// 스코어/시상 내부 버튼 라벨 bold → w800
edit(
  '스코어 입력 버튼 라벨',
  `                            '스코어 입력',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,`,
  `                            '스코어 입력',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,`,
);

edit(
  '시상 내역 버튼 라벨',
  `                            '시상 내역',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,`,
  `                            '시상 내역',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,`,
);

// ────────────────────────────────────────────────────────────
// 3) 하드코딩 hex → AppColors
// ────────────────────────────────────────────────────────────

// 옛 회색 라벨 (_StatItem, 스코어/시상 라벨·부제)
edit('회색 라벨 hex', 'color: Color(0xFF999999),', 'color: AppColors.textTertiary,', 3);

// 참석 통계 구분선
edit(
  '통계 구분선 hex',
  '      color: const Color(0xFFEEEEEE),',
  '      color: AppColors.divider,',
);

// 사진 빈 상태 배경 (const Color 자리라 const 키워드까지 함께 치환)
edit('사진 빈 상태 hex', 'const Color(0xFFF8F9FA)', 'AppColors.surfaceVariant');

// 조편성 미확정 안내 — 블루그레이 팔레트 → 브랜드 중립색
edit(
  '조편성 안내 배경 hex',
  '                    color: const Color(0xFFF5F7FA),',
  '                    color: AppColors.surfaceVariant,',
);
edit(
  '조편성 안내 아이콘 hex',
  '                          size: 15, color: Color(0xFF90A4AE)),',
  '                          size: 15, color: AppColors.textTertiary),',
);
edit(
  '조편성 안내 텍스트 hex',
  `                              color: Color(0xFF78909C),`,
  `                              color: AppColors.textTertiary,`,
);

// ────────────────────────────────────────────────────────────
// 4) 아이콘 rounded 통일 (일정 정보 행 + 상세 카드)
// ────────────────────────────────────────────────────────────

edit(
  '일정 정보 아이콘 rounded',
  `          _InfoRow(Icons.golf_course, '골프장', schedule.courseName),
          if (schedule.courseAddress != null)
            _InfoRow(Icons.location_on_outlined, '주소',
                schedule.courseAddress!),
          _InfoRow(Icons.access_time, '티오프', schedule.teeTime),
          _InfoRow(Icons.group_outlined, '팀 수', '\${schedule.teamCount}팀'),
          if (schedule.companionIds.isNotEmpty)
            _InfoRow(Icons.people_alt_outlined, '동반자',
                _companionNames(context, schedule.companionIds)),
          if (schedule.notice != null && schedule.notice!.isNotEmpty)
            _InfoRow(Icons.campaign_outlined, '메모', schedule.notice!),
          _InfoRow(Icons.person_outline, '등록자', schedule.createdBy),`,
  `          _InfoRow(Icons.golf_course_rounded, '골프장', schedule.courseName),
          if (schedule.courseAddress != null)
            _InfoRow(Icons.place_rounded, '주소',
                schedule.courseAddress!),
          _InfoRow(Icons.schedule_rounded, '티오프', schedule.teeTime),
          _InfoRow(Icons.groups_rounded, '팀 수', '\${schedule.teamCount}팀'),
          if (schedule.companionIds.isNotEmpty)
            _InfoRow(Icons.people_alt_rounded, '동반자',
                _companionNames(context, schedule.companionIds)),
          if (schedule.notice != null && schedule.notice!.isNotEmpty)
            _InfoRow(Icons.campaign_rounded, '메모', schedule.notice!),
          _InfoRow(Icons.person_rounded, '등록자', schedule.createdBy),`,
);

edit('후기 아이콘 rounded', 'Icons.edit_note,', 'Icons.edit_note_rounded,');
edit(
  '스코어/시상 아이콘 rounded',
  'Icons.emoji_events_outlined',
  'Icons.emoji_events_rounded',
);
edit(
  'RSVP 마감 아이콘 rounded',
  `                                ? Icons.lock_clock_outlined
                                : Icons.timer_outlined,`,
  `                                ? Icons.lock_clock_rounded
                                : Icons.timer_rounded,`,
);
edit(
  '자리 제안 아이콘 rounded',
  'Icons.notifications_active_outlined',
  'Icons.notifications_active_rounded',
);
edit(
  '사진 추가 아이콘 rounded',
  'Icons.add_photo_alternate_outlined',
  'Icons.add_photo_alternate_rounded',
);

// ────────────────────────────────────────────────────────────
// 5) 일정 정보 행 — 아이콘 칩 + 라벨/값 가독성 상향
// ────────────────────────────────────────────────────────────
edit(
  '_InfoRow 레이아웃',
  `    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );`,
  `    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 56,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                      color: AppColors.ink)),
            ),
          ),
        ],
      ),
    );`,
);

// ────────────────────────────────────────────────────────────
// 적용
// ────────────────────────────────────────────────────────────
const failures = [];
for (const { name, find, replace, expected } of edits) {
  const count = src.split(find).length - 1;
  if (count !== expected) {
    failures.push(`  [${name}] ${expected}개를 기대했지만 ${count}개 찾음`);
    continue;
  }
  src = src.split(find).join(replace);
  console.log(`ok  ${name}${expected > 1 ? ` (x${expected})` : ''}`);
}

if (failures.length) {
  console.error('\n패치 실패 — 원문이 예상과 다릅니다:');
  console.error(failures.join('\n'));
  process.exit(1);
}

// 안전 점검 — 인바리언트 테스트가 지키는 것들
const mustKeep = [
  'Size.fromHeight(128)',
  'Icons.place_rounded',
  'Icons.schedule_rounded',
  'BorderRadius.circular(16)',
  '[AppColors.primaryDark, AppColors.primary]',
  '0xFFC9A227',
  "children: ['참석', '불참']",
  '조편성',
  '내 응답',
  '티오프',
];
const mustNotHave = [
  'SliverAppBar',
  'class _RoundHeroCard',
  '0xFFFF8F00',
  '0xFF0D47A1',
  '0xFF1565C0',
  '0xFF7C3AED',
  '0xFF6D28D9',
  'calendar_today_outlined',
  '???',
];
for (const s of mustKeep) {
  if (!src.includes(s)) {
    console.error(`안전 점검 실패 — 사라지면 안 되는 값: ${s}`);
    process.exit(1);
  }
}
for (const s of mustNotHave) {
  if (src.includes(s)) {
    console.error(`안전 점검 실패 — 있으면 안 되는 값: ${s}`);
    process.exit(1);
  }
}

if (src === before) {
  console.log('\n변경 없음.');
  process.exit(0);
}

if (DRY) {
  console.log('\n(--dry: 저장하지 않았습니다)');
} else {
  fs.writeFileSync(FILE, src, 'utf8');
  console.log(`\n저장 완료: ${path.basename(FILE)}`);
}
