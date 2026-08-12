/**
 * Wipe ClubProvider demo seed: clubs / members / schedules / joins.
 * Keeps only platform users m1(홍길동) + mg1(이민준).
 */
const fs = require('fs');
const path = require('path');

const file = path.join(__dirname, '..', 'lib', 'providers', 'club_provider.dart');
let s = fs.readFileSync(file, 'utf8');

for (const name of [
  '_adminClubs',
  '_guestClubs',
  '_otherMemberClubs',
  '_demoAllClubs',
]) {
  const re = new RegExp(
    `static final List<Club> ${name} = \\[[\\s\\S]*?\\n  \\];`,
  );
  if (!re.test(s)) throw new Error('missing ' + name);
  s = s.replace(re, `static final List<Club> ${name} = [];`);
  console.log('emptied', name);
}

s = s.replace(
  /final List<Club> _myClubs = List\.of\(_adminClubs\);/,
  'final List<Club> _myClubs = [];',
);
s = s.replace(
  /final List<Club> _allClubs = List\.of\(_demoAllClubs\);/,
  'final List<Club> _allClubs = [];',
);

if (
  !/final List<JoinRequest> _joinRequests = \[[\s\S]*?\n  \];/.test(s)
) {
  throw new Error('joinRequests not found');
}
s = s.replace(
  /final List<JoinRequest> _joinRequests = \[[\s\S]*?\n  \];/,
  'final List<JoinRequest> _joinRequests = [];',
);
console.log('emptied joinRequests');

const membersBlock = `final List<Member> _members = [
    Member(id: 'm1', name: '홍길동', gender: '남',
        birthDate: DateTime(1974, 3, 15), memberType: '정회원', role: '일반',
        phone: '010-1234-5678',
        bio: '',
        handicap: 12.0, joinDate: DateTime(2018, 1, 1),
        address: '서울시 강남구', status: '활성'),
    Member(id: 'mg1', name: '이민준', gender: '남',
        birthDate: DateTime(1991, 9, 20), memberType: '정회원', role: '일반',
        phone: '010-9999-0000',
        bio: '',
        handicap: 18.0, joinDate: DateTime(2022, 7, 1),
        address: '서울시 강남구', status: '활성'),
  ];`;

if (!/final List<Member> _members = \[[\s\S]*?\n  \];/.test(s)) {
  throw new Error('members not found');
}
s = s.replace(/final List<Member> _members = \[[\s\S]*?\n  \];/, membersBlock);
console.log('members trimmed');

s = s.replace(
  /final List<ActivityItem> _activities = \[[\s\S]*?\n  \];/,
  'final List<ActivityItem> _activities = [];',
);
console.log('activities');

s = s.replace(
  /final List<Announcement> _announcements = \[[\s\S]*?\n  \];/,
  'final List<Announcement> _announcements = [];',
);
console.log('announcements');

const i = s.indexOf('final List<RoundSchedule> _schedules = [');
if (i < 0) throw new Error('schedules start missing');
let depth = 0;
const j = i + s.slice(i).indexOf('[');
for (let k = j; k < s.length; k++) {
  if (s[k] === '[') depth++;
  else if (s[k] === ']') {
    depth--;
    if (depth === 0) {
      let end = k + 1;
      if (s[end] === ';') end++;
      s =
        s.slice(0, i) +
        'final List<RoundSchedule> _schedules = [];' +
        s.slice(end);
      console.log('schedules emptied');
      break;
    }
  }
}

s = s.replace(/rounder_left_clubs_v1_/g, 'rounder_left_clubs_v2_');

fs.writeFileSync(file, s);
console.log('done, len', s.length);
