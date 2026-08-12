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
  '          // ── 슬림 AppBar (장소·시간 강조 — 8/8 직후 보완, 회귀 금지) ──\n';
const endMarker = '          body: SingleChildScrollView(\n';

const start = src.indexOf(startMarker);
const end = src.indexOf(endMarker);
if (start < 0 || end < 0 || end <= start) {
  console.error('markers not found', { start, end });
  process.exit(1);
}

const replacement = `          // ── 슬림 AppBar 카드형 (장소·시간 강조 — 상단 보완) ──
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(108),
            child: ColoredBox(
              color: AppColors.background,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
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
                      padding: const EdgeInsets.fromLTRB(2, 6, 4, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new,
                                color: AppColors.textPrimary, size: 18),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  schedule.displayTitle,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.place_rounded,
                                          color: AppColors.primary, size: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        schedule.courseName.isEmpty
                                            ? '장소 미정'
                                            : schedule.courseName,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          height: 1.15,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.schedule_rounded,
                                          color: AppColors.primary, size: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '\${_fmtDate(schedule.roundDate)}  \${schedule.teeTime.isEmpty ? '--:--' : schedule.teeTime} 티오프',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          height: 1.2,
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
          ),
`;

src = src.slice(0, start) + replacement + src.slice(end);
fs.writeFileSync(file, src, 'utf8');
console.log('patched schedule detail header to card style');
