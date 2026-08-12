const fs = require('fs');
const path = require('path');
const screen = path.join(__dirname, '..', 'lib/screens/admin/admin_notifications_screen.dart');
const frag = path.join(__dirname, '_push_tab_fragment.dart');
let src = fs.readFileSync(screen, 'utf8');
const fragment = fs.readFileSync(frag, 'utf8');
const start = src.indexOf('// ────────────────────────────────────────────────────────────\n//  Push Notification Tab');
if (start < 0) {
  console.error('start marker missing');
  process.exit(1);
}
// file may end at push tab class close
const endMarkers = [
  src.indexOf('\n// ── Helper Models'),
  src.length,
];
let end = -1;
for (const e of endMarkers) {
  if (e > start) { end = e; break; }
}
// Prefer cutting from Push tab to EOF if no helper models
const lastClassClose = src.lastIndexOf('\n}');
src = src.slice(0, start) + fragment.trimEnd() + '\n';
fs.writeFileSync(screen, src, 'utf8');
console.log('OK', src.length);
