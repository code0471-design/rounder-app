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

const src = fs.readFileSync(file, 'utf8');
const start = src.indexOf('  void _confirmCancel(BuildContext context, ClubProvider provider) {');
const end = src.indexOf('  String _fmtDate(DateTime d) =>', start);
if (start < 0 || end < 0) {
  console.error('confirmCancel markers missing', { start, end });
  process.exit(1);
}

const nl = src.includes('\r\n') ? '\r\n' : '\n';
const next = [
  '  void _confirmCancel(BuildContext context, ClubProvider provider) {',
  '    showDialog(',
  '      context: context,',
  '      builder: (dialogCtx) => AlertDialog(',
  '        shape:',
  '            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),',
  "        title: const Text('일정 취소'),",
  "        content: Text('\${schedule.title} 일정을 취소하시겠습니까?'),",
  '        actions: [',
  '          TextButton(',
  '            onPressed: () => Navigator.of(dialogCtx).pop(),',
  "            child: const Text('닫기'),",
  '          ),',
  '          ElevatedButton(',
  '            onPressed: () {',
  '              final parentNav = Navigator.of(context);',
  '              Navigator.of(dialogCtx).pop();',
  '              provider.cancelSchedule(schedule.id);',
  '              if (parentNav.canPop()) parentNav.pop();',
  '            },',
  '            style: ElevatedButton.styleFrom(',
  '                backgroundColor: AppColors.danger,',
  '                foregroundColor: Colors.white),',
  "            child: const Text('취소 확정'),",
  '          ),',
  '        ],',
  '      ),',
  '    );',
  '  }',
  '',
].join(nl);

const out = src.slice(0, start) + next + src.slice(end);
fs.writeFileSync(file, out, 'utf8');
console.log('patched schedule cancel dialog');
