const fs = require('fs');
const path = require('path');
const p = path.join(__dirname, '..', 'lib', 'providers', 'club_provider.dart');
let s = fs.readFileSync(p, 'utf8');

const start = s.indexOf('  // ─── 앱 알림 목록 (읽지않은 알림 포함) ───');
const end = s.indexOf(
  '  // ════════════════════════════════════════════════════════\n  //  Getters — My Clubs',
);
if (start < 0 || end < 0) {
  if (s.includes('final List<AppNotification> _appNotifications = [];')) {
    console.log('already empty');
    process.exit(0);
  }
  console.error('markers', start, end);
  process.exit(2);
}

const rep =
  '  // ─── 앱 알림 목록 — 시드 없음(실제 액션만). 잔존 시드는 로그인 시 purge ───\n' +
  '  final List<AppNotification> _appNotifications = [];\n\n';

s = s.slice(0, start) + rep + s.slice(end);
fs.writeFileSync(p, s);
console.log('cleared', !s.includes("id: 'noti0'"));
