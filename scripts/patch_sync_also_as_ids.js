const fs = require('fs');
const path = require('path');

const p = path.join(__dirname, '..', 'lib', 'providers', 'club_provider.dart');
let s = fs.readFileSync(p, 'utf8');

if (s.includes("m.id == 'm_creator_${c.id}'")) {
  console.log('already patched');
  process.exit(0);
}

const startNeedle =
  '      for (final m in membersForClub(c.id)) {\n' +
  '        // alsoAsIds(로그인 계정 별칭)는 "나 자신"의 회원 레코드에만 붙여야 한다.';
const start = s.indexOf(startNeedle);
if (start < 0) {
  console.error('start marker not found');
  process.exit(2);
}

const endNeedle = "    store.setMemberClubCountOverride('m1', _myClubs.length);\n";
const end = s.indexOf(endNeedle, start);
if (end < 0) {
  console.error('end marker not found');
  process.exit(3);
}

const replacement =
  '      for (final m in membersForClub(c.id)) {\n' +
  '        // alsoAsIds는 본인/생성자 레코드에만 — 게스트에 user_me를 붙이지 않음\n' +
  '        final isSelf = m.id == currentUserId ||\n' +
  '            m.id == _persistAuthUserId ||\n' +
  "            m.id == 'm_creator_${c.id}';\n" +
  '        final selfAliases = <String>{\n' +
  '          if (_persistAuthUserId != null) _persistAuthUserId!,\n' +
  '          currentUserId,\n' +
  "          if (_persistAuthUserId == 'user_guest' || currentUserId == 'mg1') ...[\n" +
  "            'user_guest',\n" +
  "            'mg1',\n" +
  '          ],\n' +
  "          if (_persistAuthUserId == 'user_me' || currentUserId == 'm1') ...[\n" +
  "            'user_me',\n" +
  "            'm1',\n" +
  '          ],\n' +
  '        };\n' +
  '        store.addMember(\n' +
  '          clubId: resolvedTargetId,\n' +
  '          member: m,\n' +
  '          bumpCount: false,\n' +
  '          alsoAsIds: isSelf ? selfAliases.toList() : const [],\n' +
  '          persist: false,\n' +
  '        );\n' +
  '      }\n' +
  '    }\n' +
  "    final authKey = _persistAuthUserId ?? 'user_me';\n" +
  '    store.setMemberClubCountOverride(authKey, _myClubs.length);\n' +
  "    if (authKey == 'user_me' || authKey == 'm1') {\n" +
  "      store.setMemberClubCountOverride('user_me', _myClubs.length);\n" +
  "      store.setMemberClubCountOverride('m1', _myClubs.length);\n" +
  '    }\n' +
  "    if (authKey == 'user_guest' || authKey == 'mg1') {\n" +
  "      store.setMemberClubCountOverride('user_guest', _myClubs.length);\n" +
  "      store.setMemberClubCountOverride('mg1', _myClubs.length);\n" +
  '    }\n';

s = s.slice(0, start) + replacement + s.slice(end + endNeedle.length);
fs.writeFileSync(p, s);
console.log('OK patched sync alsoAsIds');
