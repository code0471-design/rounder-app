const fs = require('fs');
const path = require('path');

const providerPath = path.join(
  __dirname,
  '..',
  'lib',
  'providers',
  'club_provider.dart',
);
const snippetPath = path.join(__dirname, 'restore_owned_clubs.snippet.dart');

let s = fs.readFileSync(providerPath, 'utf8');
const snippet = fs.readFileSync(snippetPath, 'utf8');

if (!s.includes("import 'package:shared_preferences/shared_preferences.dart';")) {
  s = s.replace(
    "import 'package:flutter/material.dart';\n",
    "import 'dart:convert';\n" +
      "import 'package:flutter/material.dart';\n" +
      "import 'package:shared_preferences/shared_preferences.dart';\n",
  );
}

let seenConvert = false;
s = s.replace(/import 'dart:convert';\n/g, () => {
  if (seenConvert) return '';
  seenConvert = true;
  return "import 'dart:convert';\n";
});

// Broaden ownership: any member named current user counts
const oldOwned =
  '  bool _isStoreClubOwnedByMe(\n' +
  '    MockDataStore store,\n' +
  '    Club c,\n' +
  '    Set<String> aliases,\n' +
  '  ) {\n' +
  '    if (aliases.contains(c.creatorId)) return true;\n' +
  '    if (aliases.any((id) => store.isMember(c.id, id))) return true;\n' +
  '\n' +
  "    final creatorKey = 'm_creator_${c.id}';\n" +
  '    for (final m in store.membersOf(c.id)) {\n' +
  "      if (m.id == creatorKey || m.id.startsWith('m_creator_')) {\n" +
  '        // creatorId 유실돼도 생성자 행 이름/역할로 소유 판정 (어드민 호스트와 동일)\n' +
  '        if (m.name == currentUserName) return true;\n' +
  '        if (aliases.contains(m.id)) return true;\n' +
  '      }\n' +
  '      if (m.name == currentUserName &&\n' +
  "          (m.role == '회장' || m.role == '총무')) {\n" +
  '        return true;\n' +
  '      }\n' +
  '    }\n' +
  '    return false;\n' +
  '  }';

const newOwned =
  '  bool _isStoreClubOwnedByMe(\n' +
  '    MockDataStore store,\n' +
  '    Club c,\n' +
  '    Set<String> aliases,\n' +
  '  ) {\n' +
  '    if (aliases.contains(c.creatorId)) return true;\n' +
  '    if (aliases.any((id) => store.isMember(c.id, id))) return true;\n' +
  '\n' +
  '    // 어드민 host 판정과 동일: 내 이름이 회원/생성자로 있으면 내 모임\n' +
  '    for (final m in store.membersOf(c.id)) {\n' +
  '      if (m.name == currentUserName) return true;\n' +
  '      if (aliases.contains(m.id)) return true;\n' +
  '    }\n' +
  '    return false;\n' +
  '  }';

if (s.includes(oldOwned)) {
  s = s.replace(oldOwned, newOwned);
  console.log('ownership check broadened');
} else if (s.includes('어드민 host 판정과 동일: 내 이름이 회원/생성자로 있으면 내 모임')) {
  console.log('ownership already broadened');
} else {
  console.warn('ownership block not found — continuing');
}

const start = s.indexOf(
  '  /// MockStore / clubRepository 에서 creator·멤버십 기준 내 모임 복구.',
);
const start2 = s.indexOf(
  '  /// MockStore / Prefs / 리포에서 내가 만든·총무인 모임 복구.',
);
const end = s.indexOf('  bool _ingestOwnedClub(Club club, List<Member> storeMembers) {');
const from = start2 >= 0 ? start2 : start;
if (from < 0 || end < 0) {
  console.error('restore markers not found', { from, end });
  process.exit(2);
}

s = s.slice(0, from) + snippet + s.slice(end);
fs.writeFileSync(providerPath, s);
console.log('OK force restore spliced');
