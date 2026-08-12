const fs = require('fs');
const path = require('path');
const p = path.join(
  __dirname,
  '..',
  'lib/features/clubs/presentation/club_detail_dashboard_screen.dart',
);
let s = fs.readFileSync(p, 'utf8');
const from = `(club.myRole == '회장' ||
                    club.myRole == '부회장' ||
                    club.myRole == '총무')`;
const to = 'ClubMemberRole.isOfficer(club.myRole)';
if (!s.includes(from)) {
  console.error('MISS dashboard officer check');
  process.exit(1);
}
s = s.split(from).join(to);
if (!s.includes('member_role.dart')) {
  s = s.replace(
    "import '../../../models/club_model.dart';",
    "import '../../../models/club_model.dart';\nimport '../../../models/member_role.dart';",
  );
}
fs.writeFileSync(p, s, 'utf8');
console.log('OK dashboard');
