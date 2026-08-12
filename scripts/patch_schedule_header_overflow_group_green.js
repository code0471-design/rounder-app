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

const header = `          // ── 슬림 AppBar 카드형 (장소·시간 강조 — 상단 보완) ──
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(108),
            child: ColoredBox(
              color: AppColors.background,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8EEE9)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
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
                              color: AppColors.textPrimary, size: 18),
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
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
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
                                      color: AppColors.primary
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: const Icon(Icons.place_rounded,
                                        color: AppColors.primary, size: 14),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      schedule.courseName.isEmpty
                                          ? '장소 미정'
                                          : schedule.courseName,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
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
                                      color: AppColors.primary
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: const Icon(Icons.schedule_rounded,
                                        color: AppColors.primary, size: 14),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '\${_fmtDate(schedule.roundDate)}  \${schedule.teeTime.isEmpty ? '--:--' : schedule.teeTime} 티오프',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
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
                                color: AppColors.textSecondary),
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

// 조편성 확정 헤더 → 브랜드 딥그린 (primaryDark → primary)
const oldGrad = `                gradient: isFinalized
                    ? const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
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
                        colors: [AppColors.primaryDark, AppColors.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [AppColors.sageLighter, Color(0xFFF3F7F5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),`;

if (!src.includes(oldGrad)) {
  console.error('group gradient block not found');
  process.exit(1);
}
src = src.replace(oldGrad, newGrad);

// 조 미리보기 색상 — 브랜드 그린 톤만 (주황/피치 금지)
const oldColors = `  static const List<Color> _groupColors = [
    AppColors.primary,
    AppColors.primaryLight,
    Color(0xFF3D6B5A),
    Color(0xFF5A8F7B),
    Color(0xFF2F5C4C),
    Color(0xFF4A7A68),
  ];`;

const newColors = `  static const List<Color> _groupColors = [
    AppColors.primaryDark,
    AppColors.primary,
    AppColors.primaryLight,
    Color(0xFF3D6B5A),
    Color(0xFF2F5C4C),
    Color(0xFF4A7A68),
  ];`;

if (!src.includes(oldColors)) {
  console.error('group colors not found');
  process.exit(1);
}
src = src.replace(oldColors, newColors);

// 조편성 카드 보더/섀도우를 딥그린 쪽으로
src = src.replace(
  `            color: isFinalized
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.primaryLight.withValues(alpha: 0.3),`,
  `            color: isFinalized
                ? AppColors.primaryDark.withValues(alpha: 0.45)
                : AppColors.primaryLight.withValues(alpha: 0.3),`,
);

src = src.replace(
  `              color: isFinalized
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.primaryLight.withValues(alpha: 0.08),`,
  `              color: isFinalized
                  ? AppColors.primaryDark.withValues(alpha: 0.18)
                  : AppColors.primaryLight.withValues(alpha: 0.08),`,
);

fs.writeFileSync(file, src, 'utf8');
console.log('patched header overflow + group brand green');
