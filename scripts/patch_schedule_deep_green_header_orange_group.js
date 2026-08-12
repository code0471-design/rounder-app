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

const startMarker =
  '          // ── 슬림 AppBar 카드형 (장소·시간 강조 — 상단 보완) ──\n';
const endMarker = '          body: SingleChildScrollView(\n';

const start = src.indexOf(startMarker);
const end = src.indexOf(endMarker);
if (start < 0 || end < 0 || end <= start) {
  console.error('header markers not found', { start, end });
  process.exit(1);
}

const header = `          // ── 슬림 AppBar 딥그린 카드형 (장소·시간 강조 — 상단 보완) ──
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(108),
            child: ColoredBox(
              color: AppColors.background,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryDark.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 18),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                schedule.displayTitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: const Icon(Icons.place_rounded,
                                        color: Colors.white, size: 14),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      schedule.courseName.isEmpty
                                          ? '장소 미정'
                                          : schedule.courseName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        height: 1.1,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: const Icon(Icons.schedule_rounded,
                                        color: Colors.white, size: 14),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '\${_fmtDate(schedule.roundDate)}  \${schedule.teeTime.isEmpty ? '--:--' : schedule.teeTime} 티오프',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        height: 1.1,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isAdmin && !isPast)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            icon: const Icon(Icons.more_vert,
                                color: Colors.white),
                            onPressed: () =>
                                _showAdminMenu(context, provider),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
`;

src = src.slice(0, start) + header + src.slice(end);

// ── 조편성: 주황 톤 (첨부 레퍼런스) ──
const oldColors = `  static const List<Color> _groupColors = [
    AppColors.primaryDark,
    AppColors.primary,
    AppColors.primaryLight,
    Color(0xFF3D6B5A),
    Color(0xFF2F5C4C),
    Color(0xFF4A7A68),
  ];`;

const newColors = `  // 조편성 미리보기 팔레트 (주황 헤더 레퍼런스)
  static const Color _orange = Color(0xFFFF8F00);
  static const Color _orangeDeep = Color(0xFFF57C00);
  static const List<Color> _groupColors = [
    AppColors.primary,
    Color(0xFF00897B),
    Color(0xFFE65100),
    Color(0xFF5A8F7B),
    Color(0xFFEF6C00),
    Color(0xFF2F5C4C),
  ];`;

if (!src.includes(oldColors)) {
  console.error('group colors block not found');
  process.exit(1);
}
src = src.replace(oldColors, newColors);

const oldCardDecor = `        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFinalized
                ? AppColors.primaryDark.withValues(alpha: 0.45)
                : AppColors.primaryLight.withValues(alpha: 0.3),
            width: isFinalized ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isFinalized
                  ? AppColors.primaryDark.withValues(alpha: 0.18)
                  : AppColors.primaryLight.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),`;

const newCardDecor = `        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFinalized
                ? _orange.withValues(alpha: 0.55)
                : _orange.withValues(alpha: 0.28),
            width: isFinalized ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isFinalized
                  ? _orange.withValues(alpha: 0.22)
                  : _orange.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),`;

if (!src.includes(oldCardDecor)) {
  console.error('group card decor not found');
  process.exit(1);
}
src = src.replace(oldCardDecor, newCardDecor);

const oldGrad = `                gradient: isFinalized
                    ? const LinearGradient(
                        colors: [AppColors.primaryDark, AppColors.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [AppColors.sageLighter, Color(0xFFF3F7F5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),`;

const newGrad = `                gradient: isFinalized
                    ? const LinearGradient(
                        colors: [_orange, Color(0xFFFFB300)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFFFF3E0), Color(0xFFFFF8E1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),`;

if (!src.includes(oldGrad)) {
  console.error('group header gradient not found');
  process.exit(1);
}
src = src.replace(oldGrad, newGrad);

// 미확정 상태 아이콘/텍스트를 주황 톤으로
const replacements = [
  [
    `                      color: isFinalized
                          ? Colors.white.withValues(alpha: 0.25)
                          : AppColors.primaryLight.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.groups_rounded,
                      color: isFinalized
                          ? Colors.white
                          : AppColors.primary,`,
    `                      color: isFinalized
                          ? Colors.white.withValues(alpha: 0.25)
                          : _orange.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.groups_rounded,
                      color: isFinalized
                          ? Colors.white
                          : _orangeDeep,`,
  ],
  [
    `                            color: isFinalized
                                ? Colors.white
                                : AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isFinalized
                              ? '\${schedule.teamCount}개 조 확정 완료 — 탭해서 확인'
                              : isAdmin
                                  ? '탭해서 조편성 시작하기'
                                  : '총무가 확정하면 여기서 확인할 수 있어요',
                          style: TextStyle(
                            fontSize: 12,
                            color: isFinalized
                                ? Colors.white.withValues(alpha: 0.85)
                                : AppColors.primaryDark.withValues(alpha: 0.7),
                          ),`,
    `                            color: isFinalized
                                ? Colors.white
                                : _orangeDeep,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isFinalized
                              ? '\${schedule.teamCount}개 조 확정 완료 — 탭해서 확인'
                              : isAdmin
                                  ? '탭해서 조편성 시작하기'
                                  : '총무가 확정하면 여기서 확인할 수 있어요',
                          style: TextStyle(
                            fontSize: 12,
                            color: isFinalized
                                ? Colors.white.withValues(alpha: 0.9)
                                : _orangeDeep.withValues(alpha: 0.85),
                          ),`,
  ],
  [
    `                      color: isFinalized
                          ? Colors.white.withValues(alpha: 0.25)
                          : AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isFinalized ? '확정 ✓' : '미확정',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isFinalized
                            ? Colors.white
                            : AppColors.primary,
                      ),`,
    `                      color: isFinalized
                          ? Colors.white.withValues(alpha: 0.28)
                          : _orange.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isFinalized ? '확정 ✓' : '미확정',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isFinalized
                            ? Colors.white
                            : _orangeDeep,
                      ),`,
  ],
  [
    `                          color: isFinalized
                              ? Colors.white.withValues(alpha: 0.25)
                              : AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              size: 13,
                              color: isFinalized
                                  ? Colors.white
                                  : AppColors.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '편집',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isFinalized
                                    ? Colors.white
                                    : AppColors.primary,
                              ),`,
    `                          color: isFinalized
                              ? Colors.white.withValues(alpha: 0.28)
                              : _orange.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              size: 13,
                              color: isFinalized
                                  ? Colors.white
                                  : _orangeDeep,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '편집',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isFinalized
                                    ? Colors.white
                                    : _orangeDeep,
                              ),`,
  ],
];

for (const [from, to] of replacements) {
  if (!src.includes(from)) {
    console.error('replacement block not found:\n', from.slice(0, 80));
    process.exit(1);
  }
  src = src.replace(from, to);
}

fs.writeFileSync(file, src, 'utf8');
console.log('patched deep-green header + orange group card');
