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

function replaceOnce(from, to, label) {
  const idx = src.indexOf(from);
  if (idx < 0) {
    console.error('missing:', label);
    process.exit(1);
  }
  if (src.indexOf(from, idx + 1) >= 0) {
    console.error('duplicate:', label);
    process.exit(1);
  }
  src = src.slice(0, idx) + to + src.slice(idx + from.length);
}

replaceOnce(
  `                    } else if (label == '불참') {
                      final ok = await _showAbsentConfirmDialogCard(context);`,
  `                    } else if (label == '불참') {
                      final warnTreasurer = currentResponse == '참석' &&
                          (provider.groupAssignment(schedule.id)?.isFinalized ??
                              false);
                      final ok = await _showAbsentConfirmDialogCard(
                        context,
                        notifyTreasurer: warnTreasurer,
                      );`,
  'detail absent tap',
);

replaceOnce(
  `                    final confirmed = await _showAbsentConfirmDialog(sheetCtx);`,
  `                    final warnTreasurer = currentResponse == '참석' &&
                        (provider.groupAssignment(schedule.id)?.isFinalized ??
                            false);
                    final confirmed = await _showAbsentConfirmDialog(
                      sheetCtx,
                      notifyTreasurer: warnTreasurer,
                    );`,
  'sheet absent tap',
);

const sheetStart = src.indexOf('  // ── 불참 확인 다이얼로그 ──\n');
const sheetEnd = src.indexOf('  // ── 정원 마감 다이얼로그 ──\n', sheetStart);
if (sheetStart < 0 || sheetEnd < 0) {
  console.error('sheet dialog markers missing');
  process.exit(1);
}
src =
  src.slice(0, sheetStart) +
  `  // ── 불참 확인 다이얼로그 ──
  Future<bool?> _showAbsentConfirmDialog(
    BuildContext context, {
    bool notifyTreasurer = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel_outlined,
                  color: AppColors.danger, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('불참 확인',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          notifyTreasurer
              ? '조편성이 확정되었기 때문에 불참 변경시 총무에게 알림이 갑니다. 불참으로 변경하시겠습니까?'
              : '이번 모임에 불참하시겠습니까?\\n\\n참석명단이 마감될 경우 참석으로 변경하면 대기 상태로 등록됩니다.',
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('불참 확정',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

` +
  src.slice(sheetEnd);

const cardStart = src.indexOf('  // ── _AttendanceCard 전용 불참 확인 다이얼로그 ──\n');
const cardEnd = src.indexOf('  // ── _AttendanceCard 전용 정원 마감 다이얼로그 ──\n', cardStart);
if (cardStart < 0 || cardEnd < 0) {
  console.error('card dialog markers missing');
  process.exit(1);
}
src =
  src.slice(0, cardStart) +
  `  // ── _AttendanceCard 전용 불참 확인 다이얼로그 ──
  Future<bool?> _showAbsentConfirmDialogCard(
    BuildContext context, {
    bool notifyTreasurer = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel_outlined,
                  color: AppColors.danger, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('불참 확인',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          notifyTreasurer
              ? '조편성이 확정되었기 때문에 불참 변경시 총무에게 알림이 갑니다. 불참으로 변경하시겠습니까?'
              : '이번 모임에 불참하시겠습니까?\\n\\n참석명단이 마감될 경우 참석으로 변경하면 대기 상태로 등록됩니다.',
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('취소'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('불참 확정',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

` +
  src.slice(cardEnd);

fs.writeFileSync(file, src, 'utf8');
console.log('absent-confirm patched');
