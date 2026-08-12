const fs = require('fs');
const path = 'lib/screens/schedule/schedule_screen.dart';
const src =
  'C:/ROUND_ADMIN/flutter_app/lib/screens/schedule/schedule_screen.dart';

if (!fs.existsSync(src)) {
  console.error('MISSING ADMIN source');
  process.exit(1);
}

let t = fs.readFileSync(src, 'utf8');
console.log('src hangul 조편성', t.includes('조편성'), '???', (t.match(/\?\?\?/g) || []).length);

const D = '$' + '{';

function mustReplace(old, neu, label) {
  if (!t.includes(old)) {
    console.error('MISS', label);
    console.error(JSON.stringify(old.slice(0, 160)));
    process.exit(2);
  }
  t = t.replace(old, neu);
  console.log('OK', label);
}

// API alias
if (!t.includes('void openAddScheduleSheet(')) {
  mustReplace(
    'void showAddScheduleSheet(',
    'void openAddScheduleSheet(BuildContext context, ClubProvider provider) {\n' +
      '  showAddScheduleSheet(context, provider);\n' +
      '}\n\n' +
      'void showAddScheduleSheet(',
    'openAddScheduleSheet alias',
  );
}

// Hide insurance
mustReplace(
  `                      // ── ② 홀인원보험 배너 ──
                      if (!isPast) _InsuranceBannerCard(schedule: schedule),

                      if (!isPast) const SizedBox(height: 16),
`,
  `                      // ── ② 홀인원보험 배너 (런칭 광고 OFF — 복구 금지)
                      // if (!isPast) _InsuranceBannerCard(schedule: schedule),
                      // if (!isPast) const SizedBox(height: 16),
`,
  'hide insurance',
);

// Brand green group colors
mustReplace(
  `  static const List<Color> _groupColors = [
    AppColors.primary, AppColors.primaryLight, Color(0xFFE65100),
    Color(0xFF6A1B9A), Color(0xFF00838F), Color(0xFFC62828),
  ];`,
  `  static const List<Color> _groupColors = [
    AppColors.primary,
    AppColors.primaryLight,
    Color(0xFF3D6B5A),
    Color(0xFF5A8F7B),
    Color(0xFF2F5C4C),
    Color(0xFF4A7A68),
  ];`,
  'groupColors',
);

// Orange → green in GroupView class only
{
  const classStart = t.indexOf('class _GroupViewBannerCard');
  const classEnd = t.indexOf('\nclass ', classStart + 10);
  let s = t.slice(classStart, classEnd);
  s = s.replaceAll('const Color(0xFFFF8F00)', 'AppColors.primary');
  s = s.replaceAll('Color(0xFFFF8F00)', 'AppColors.primary');
  s = s.replaceAll('const Color(0xFFFFB300)', 'AppColors.primaryLight');
  s = s.replaceAll('Color(0xFFFFB300)', 'AppColors.primaryLight');
  s = s.replaceAll('const Color(0xFFE65100)', 'AppColors.primary');
  s = s.replaceAll('Color(0xFFE65100)', 'AppColors.primary');
  s = s.replaceAll('const Color(0xFFBF360C)', 'AppColors.primaryDark');
  s = s.replaceAll('Color(0xFFBF360C)', 'AppColors.primaryDark');
  s = s.replaceAll(
    'colors: [Color(0xFFFFF8E1), Color(0xFFFFFDE7)]',
    'colors: [AppColors.sageLighter, Color(0xFFF3F7F5)]',
  );
  t = t.slice(0, classStart) + s + t.slice(classEnd);
  console.log('OK GroupView green remap');
}

// Score banner polish (EEEEEE border → divider / primary accents) — small safe swaps in Score class
{
  const classStart = t.indexOf('class _ScoreAwardBannerCard');
  const classEnd = t.indexOf('\nclass ', classStart + 10);
  let s = t.slice(classStart, classEnd);
  s = s.replaceAll(
    'border: Border.all(color: const Color(0xFFEEEEEE))',
    'border: Border.all(color: AppColors.divider)',
  );
  s = s.replaceAll(
    'color: Colors.black.withValues(alpha: 0.06)',
    'color: AppColors.primary.withValues(alpha: 0.06)',
  );
  s = s.replaceAll(
    'color: Color(0xFF999999), size: 15',
    'color: AppColors.primary, size: 18',
  );
  t = t.slice(0, classStart) + s + t.slice(classEnd);
  console.log('OK Score banner polish');
}

// Fix TabBar Container color+decoration crash
mustReplace(
  `              Container(
                color: AppColors.cream,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                  ),
                ),`,
  `              Container(
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  border: Border(
                    bottom: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                  ),
                ),`,
  'tabbar color+decoration',
);

// Also catch cream → background alias if cream missing in theme - AppColors.cream exists

// AppBar place/time
mustReplace(
  `          // ── 슬림 AppBar: 제목+날짜만 담고 진녹색 최소화 ──
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(72),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 8, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              schedule.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${D}_fmtDate(schedule.roundDate)}  ${D}schedule.teeTime} 티오프',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (isAdmin && !isPast)
                        IconButton(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onPressed: () => _showAdminMenu(context, provider),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),`,
  `          // ── 슬림 AppBar (장소·시간 강조 — 8/8 직후 보완, 회귀 금지) ──
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(96),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 8, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              schedule.displayTitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.place_rounded,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    schedule.courseName.isEmpty
                                        ? '장소 미정'
                                        : schedule.courseName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      height: 1.15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(Icons.schedule_rounded,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${D}_fmtDate(schedule.roundDate)}  ${D}schedule.teeTime.isEmpty ? '--:--' : schedule.teeTime} 티오프',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      height: 1.15,
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
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onPressed: () => _showAdminMenu(context, provider),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),`,
  'appbar place/time',
);

// My response card
{
  const methodIdx = t.indexOf('  Widget _buildMyResponseCard(');
  const respStart = t.indexOf(
    '    return Container(\n      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),',
    methodIdx,
  );
  const respEnd = t.indexOf('  void _showResponseSheet(', respStart);
  if (methodIdx < 0 || respStart < 0 || respEnd < 0) {
    console.error('MISS response', methodIdx, respStart, respEnd);
    process.exit(3);
  }
  const newResp = `    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              responded
                  ? (currentResponse == '참석'
                      ? Icons.check_circle
                      : currentResponse == '불참'
                          ? Icons.cancel
                          : Icons.help)
                  : Icons.check_circle_outline,
              color: statusColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '내 응답',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                (!responded || currentResponse == '미정')
                    ? '미응답'
                    : currentResponse!,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: ['참석', '불참'].map((label) {
              final isSelected = currentResponse == label;
              final btnColor =
                  label == '참석' ? AppColors.primary : AppColors.danger;
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onTap: () async {
                    if (label == '참석') {
                      final cnt = schedule.responses
                          .where((r) => r.response == '참석')
                          .length;
                      final maxCap = schedule.maxCapacity ?? 9999;
                      if (cnt >= maxCap && currentResponse != '참석') {
                        _showAttendFullDialogCard(context);
                        return;
                      }
                      final ok = await _showAttendConfirmDialogCard(context);
                      if (ok == true) {
                        provider.respondToSchedule(
                            scheduleId: schedule.id, response: label);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('참석이 확정되었습니다'),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                      return;
                    } else if (label == '불참') {
                      final ok = await _showAbsentConfirmDialogCard(context);
                      if (ok == true) {
                        provider.respondToSchedule(
                            scheduleId: schedule.id, response: label);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('불참으로 확정되었습니다'),
                              backgroundColor: AppColors.danger,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                      return;
                    }
                    provider.respondToSchedule(
                        scheduleId: schedule.id, response: label);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? btnColor : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isSelected ? btnColor : AppColors.divider,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

`;
  t = t.slice(0, respStart) + newResp + t.slice(respEnd);
  console.log('OK response');
}

// Alert dialogCtx
{
  const alertAnchor =
    '아직 조편성이 확정되지 않았습니다.\\n총무가 확정하면 이곳에서 확인할 수 있습니다.';
  const ai = t.indexOf(alertAnchor);
  if (ai < 0) {
    console.error('MISS alert');
    process.exit(4);
  }
  const blockStart = t.lastIndexOf('if (!isFinalized && !isAdmin)', ai);
  const blockEnd = t.indexOf('} else {', ai);
  let block = t.slice(blockStart, blockEnd);
  block = block
    .replace(
      '// 일반 회원 + 미확정 → 얼럿',
      '// 일반 회원 + 미확정 → 얼럿 (dialogCtx pop — 회귀 금지)',
    )
    .replace(
      'showDialog(\n            context: context,\n            builder: (_) => AlertDialog(',
      'showDialog(\n            context: context,\n            barrierDismissible: true,\n            builder: (dialogCtx) => AlertDialog(',
    )
    .replace(
      'onPressed: () => Navigator.pop(context)',
      'onPressed: () => Navigator.of(dialogCtx).pop()',
    )
    .replace(
      'color: const Color(0xFF78909C).withValues(alpha: 0.15)',
      'color: AppColors.sageLighter',
    )
    .replace(
      'color: const Color(0xFF78909C).withValues(alpha: 0.08)',
      'color: AppColors.sageLighter',
    )
    .replaceAll('Color(0xFF78909C)', 'AppColors.primary')
    .replace('color: Color(0xFF546E7A)', 'color: AppColors.textSecondary');
  t = t.slice(0, blockStart) + block + t.slice(blockEnd);
  console.log('OK alert');
}

// Alimtalk API fix if present
{
  const old = `              final sent = provider.sendScheduleAlimtalk(
                scheduleId: scheduleId,
                scheduleTitle: scheduleTitle,
                roundDate: roundDate,
              );`;
  const neu = `              final memberIds = provider.members
                  .where((m) =>
                      m.status == '활성' && m.id != provider.currentUserId)
                  .map((m) => m.id)
                  .toList();
              final sent = provider.sendScheduleAlimtalk(
                scheduleId: scheduleId,
                memberIds: memberIds,
              );`;
  if (t.includes(old)) {
    t = t.replace(old, neu);
    console.log('OK alimtalk');
  } else {
    console.log('WARN alimtalk pattern miss (may already be fixed)');
  }
}

// Final sanity
const checks = {
  조편성: t.includes('조편성'),
  내응답: t.includes('내 응답'),
  티오프: t.includes('티오프'),
  qmarks: (t.match(/\?\?\?/g) || []).length,
  appbar96: t.includes('Size.fromHeight(96)'),
  dialogCtx: t.includes('Navigator.of(dialogCtx).pop()'),
  colorDeco: t.includes('color: AppColors.cream,\n                decoration:'),
};
console.log(checks);
if (!checks.조편성 || checks.qmarks > 0 || checks.colorDeco) {
  console.error('SANITY FAIL');
  process.exit(9);
}

fs.writeFileSync(path, t, 'utf8');
console.log('DONE wrote', path, 'bytes', Buffer.byteLength(t));
