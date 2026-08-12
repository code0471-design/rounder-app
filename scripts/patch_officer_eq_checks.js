const fs = require('fs');
const path = require('path');

const file = path.join(__dirname, '..', 'lib/providers/club_provider.dart');
let s = fs.readFileSync(file, 'utf8');

const reps = [
  [
    `(c.myRole == '총무' || c.myRole == '회장')`,
    `ClubMemberRole.isOfficer(c.myRole)`,
  ],
  [
    `(myRole == '총무' || myRole == '회장')`,
    `ClubMemberRole.isOfficer(myRole)`,
  ],
  [
    `.where((c) => c.myRole == '회장' || c.myRole == '부회장' || c.myRole == '총무')`,
    `.where((c) => ClubMemberRole.isOfficer(c.myRole))`,
  ],
];

let n = 0;
for (const [from, to] of reps) {
  if (!s.includes(from)) {
    console.log('skip', from.slice(0, 40));
    continue;
  }
  const before = s;
  s = s.split(from).join(to);
  n += before === s ? 0 : 1;
}
fs.writeFileSync(file, s, 'utf8');
console.log('patched', n);

// dashboard already patched; ensure ClubMemberRole import in features
const dash = path.join(
  __dirname,
  '..',
  'lib/features/clubs/presentation/club_detail_dashboard_screen.dart',
);
let d = fs.readFileSync(dash, 'utf8');
if (d.includes('ClubMemberRole.') && !d.includes('member_role.dart')) {
  d = d.replace(
    "import '../../../models/club_model.dart';",
    "import '../../../models/club_model.dart';\nimport '../../../models/member_role.dart';",
  );
  fs.writeFileSync(dash, d, 'utf8');
  console.log('dashboard import ok');
}
