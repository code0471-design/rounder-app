/**
 * Patch schedule + club_room so 회장/부회장/총무 can create schedules
 * (uses ClubProvider.canCreateSchedule / isClubExecutive; multi-role safe).
 * UTF-8 Node patch — do not StrReplace schedule_screen.dart directly.
 */
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');

function patchFile(rel, replacements) {
  const file = path.join(root, rel);
  let src = fs.readFileSync(file, 'utf8');
  let changed = 0;
  for (const [from, to] of replacements) {
    if (!src.includes(from)) {
      console.error(`MISS in ${rel}:\n${from.slice(0, 120)}...`);
      process.exitCode = 1;
      continue;
    }
    const next = src.split(from).join(to);
    if (next !== src) {
      changed += 1;
      src = next;
    }
  }
  fs.writeFileSync(file, src, 'utf8');
  console.log(`OK ${rel} (${changed} replacements)`);
}

patchFile('lib/screens/schedule/schedule_screen.dart', [
  [
    `        final isAdmin = ['회장', '부회장', '총무']
            .contains(provider.selectedClub.myRole);

        return Scaffold(
          backgroundColor: AppColors.cream,`,
    `        final isAdmin = provider.canCreateSchedule;

        return Scaffold(
          backgroundColor: AppColors.cream,`,
  ],
  [
    `        final isAdmin = ['회장', '부회장', '총무']
            .contains(provider.selectedClub.myRole);

        return Scaffold(
          backgroundColor: AppColors.background,`,
    `        final isAdmin = provider.canCreateSchedule;

        return Scaffold(
          backgroundColor: AppColors.background,`,
  ],
]);

patchFile('lib/screens/club_room/club_room_screen.dart', [
  [
    `                        subtitle: provider.isClubExecutive
                            ? '새 라운딩 일정을 만들어 회원들을 초대해 보세요'
                            : '총무가 새 일정을 등록하면 여기에 표시됩니다',
                        action: provider.isClubExecutive`,
    `                        subtitle: provider.canCreateSchedule
                            ? '새 라운딩 일정을 만들어 회원들을 초대해 보세요'
                            : '임원이 새 일정을 등록하면 여기에 표시됩니다',
                        action: provider.canCreateSchedule`,
  ],
  [
    `  bool get _isAdmin =>
      ['회장', '부회장', '총무'].contains(club.myRole);`,
    `  bool get _isAdmin => ClubMemberRole.isOfficer(club.myRole);`,
  ],
]);

// Ensure club_room imports member_role if we added ClubMemberRole usage
(() => {
  const file = path.join(root, 'lib/screens/club_room/club_room_screen.dart');
  let src = fs.readFileSync(file, 'utf8');
  if (src.includes('ClubMemberRole.') && !src.includes("member_role.dart")) {
    src = src.replace(
      "import '../../models/club_model.dart';",
      "import '../../models/club_model.dart';\nimport '../../models/member_role.dart';",
    );
    fs.writeFileSync(file, src, 'utf8');
    console.log('OK club_room import member_role.dart');
  }
})();

// group_assignment + club detail hardcoded lists
const extras = [
  [
    'lib/screens/group_assignment/group_assignment_screen.dart',
    `['회장', '부회장', '총무'].contains(p.selectedClub.myRole)`,
    `p.isClubExecutive`,
  ],
  [
    'lib/screens/clubs/club_detail_screen.dart',
    `club.myRole == '회장' ||
      club.myRole == '부회장' ||
      club.myRole == '총무'`,
    `ClubMemberRole.isOfficer(club.myRole)`,
  ],
];

for (const [rel, from, to] of extras) {
  const file = path.join(root, rel);
  let src = fs.readFileSync(file, 'utf8');
  if (!src.includes(from)) {
    console.warn(`SKIP (not found) ${rel}`);
    continue;
  }
  src = src.split(from).join(to);
  if (rel.includes('club_detail') && !src.includes('member_role.dart')) {
    src = src.replace(
      /import .+club_model\.dart';/,
      (m) => `${m}\nimport '../../models/member_role.dart';`,
    );
  }
  fs.writeFileSync(file, src, 'utf8');
  console.log(`OK ${rel}`);
}
