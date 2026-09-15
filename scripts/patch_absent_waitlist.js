const fs = require('fs');
const path = 'lib/screens/schedule/schedule_screen.dart';
let s = fs.readFileSync(path, 'utf8');
const nl = s.includes('\r\n') ? '\r\n' : '\n';
s = s.replace(/\r\n/g, '\n');

function mustReplace(oldStr, newStr, label) {
  const needle = oldStr.replace(/\r\n/g, '\n');
  if (!s.includes(needle)) {
    throw new Error('missing: ' + label);
  }
  const n = s.split(needle).length - 1;
  s = s.split(needle).join(newStr.replace(/\r\n/g, '\n'));
  console.log('ok', label, 'x' + n);
}

mustReplace(
`                    final cnt = schedule.responses
                        .where((r) => r.response == '참석').length;
                    final maxCap = schedule.maxCapacity ?? 9999;
                    final isFull = cnt >= maxCap && currentResponse != '참석';

                    Navigator.pop(sheetCtx);
                    if (isFull) {
                      _showAttendFullDialog(sheetCtx);
                      return;
                    }`,
`                    final isFull = currentResponse != '참석' &&
                        provider.isAttendanceFull(schedule.id);

                    Navigator.pop(sheetCtx);
                    if (isFull) {
                      _showAttendFullDialog(sheetCtx, provider);
                      return;
                    }`,
  'attend button full check',
);

mustReplace(
`                      final cnt = schedule.responses
                          .where((r) => r.response == '참석')
                          .length;
                      final maxCap = schedule.maxCapacity ?? 9999;
                      if (cnt >= maxCap && currentResponse != '참석') {
                        _showAttendFullDialogCard(context);
                        return;
                      }`,
`                      if (currentResponse != '참석' &&
                          provider.isAttendanceFull(schedule.id)) {
                        _showWaitingDialog(context, provider);
                        return;
                      }`,
  'detail card full check',
);

mustReplace(
`                    final confirmed = schedule.responses
                        .where((r) => r.response == '참석')
                        .length;
                    final maxCap = schedule.maxCapacity ?? 9999;
                    if (confirmed >= maxCap && current != '참석') {
                      // 이미 정원 초과 → 대기 등록 다이얼로그
                      Navigator.pop(context);
                      _showWaitingDialog(context, provider);`,
`                    if (current != '참석' &&
                        provider.isAttendanceFull(schedule.id)) {
                      Navigator.pop(context);
                      _showWaitingDialog(context, provider);`,
  'detail sheet full check',
);

const absentContent = `        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '불참으로 바꾸면 조편성에서도 빠집니다.',
              style: TextStyle(
                  fontSize: 15, height: 1.5, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              '대기 1번에게 앱 푸시로 자리가 생겼다고 알립니다. 그 사람이 참석으로 응답하면 대신 들어옵니다.',
              style: TextStyle(fontSize: 14, height: 1.55),
            ),
            if (notifyTreasurer) ...[
              const SizedBox(height: 10),
              const Text(
                '조편성이 확정된 일정이라 총무에게도 알림이 갑니다.',
                style: TextStyle(
                    fontSize: 13, height: 1.5, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),`;

mustReplace(
`        content: Text(
          notifyTreasurer
              ? '조편성이 확정되었기 때문에 불참 변경시 총무에게 알림이 갑니다. 불참으로 변경하시겠습니까?'
              : '이번 모임에 불참하시겠습니까?\\n\\n참석명단이 마감될 경우 참석으로 변경하면 대기 상태로 등록됩니다.',
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),`,
  absentContent,
  'absent confirm copy',
);

mustReplace(
`  void _showAttendFullDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline,
                  color: AppColors.amber, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('정원 마감',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          '이미 정원이 마감된 모임입니다.\\n\\n대기 상태로 등록되며, 결원 발생 시 자동으로 참석 확정됩니다.',
          style: TextStyle(fontSize: 14, height: 1.6),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.charcoal,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('확인',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],`,
`  void _showAttendFullDialog(BuildContext context, ClubProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline,
                  color: AppColors.amber, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('정원 마감',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          '이미 정원이 마감된 모임입니다.\\n\\n대기 명단에 등록하면 자리가 생길 때 앱 푸시로 알려 드립니다. 참석으로 응답해야 확정됩니다.',
          style: TextStyle(fontSize: 14, height: 1.6),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
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
                  onPressed: () {
                    final currentMember = provider.currentMember;
                    if (currentMember != null) {
                      provider.addToWaitingList(
                        scheduleId: schedule.id,
                        memberId: currentMember.id,
                        memberName: currentMember.name,
                      );
                    }
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('대기 명단에 등록되었습니다'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.charcoal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('대기 등록',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],`,
  'attend full dialog waitlist',
);

if (s.includes('maxCapacity ?? 9999')) {
  throw new Error('maxCapacity ?? 9999 still present');
}

fs.writeFileSync(path, nl === '\r\n' ? s.replace(/\n/g, '\r\n') : s);
console.log('patched', path);
