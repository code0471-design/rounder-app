const fs = require('fs');
const path = require('path');
const file = path.join(__dirname, '..', 'lib/screens/admin/dashboard_screen.dart');
let src = fs.readFileSync(file, 'utf8');

const bad =
  "        : '모임 $mergedClubCount · 회원 $memberCount$modeTag'\n" +
  "            '${report.userClubNames.isEmpty ? '' : ' · 생성:${report.userClubNames.join(\", \")}'}'\n" +
  ';';

const good =
  "        : '모임 $mergedClubCount · 회원 $memberCount$modeTag'\n" +
  "            '${report.userClubNames.isEmpty ? '' : ' · 생성:${report.userClubNames.join(\", \")}'}';";

if (!src.includes(bad)) {
  // try CRLF
  const bad2 = bad.replace(/\n/g, '\r\n');
  if (src.includes(bad2)) {
    src = src.replace(bad2, good.replace(/\n/g, '\r\n'));
  } else {
    console.error('FAIL: banner detail block not found');
    const i = src.indexOf('회원 $memberCount');
    console.log(JSON.stringify(src.slice(i, i + 180)));
    process.exit(1);
  }
} else {
  src = src.replace(bad, good);
}

fs.writeFileSync(file, src, 'utf8');
console.log('OK dashboard banner syntax');
