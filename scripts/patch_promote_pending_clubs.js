const fs = require('fs');
const path = require('path');

// Default persisted status → active
{
  const rel = 'lib/features/admin/application/admin_app_sync.dart';
  const file = path.join(__dirname, '..', rel);
  let src = fs.readFileSync(file, 'utf8');
  src = src.replace(
    "            final status = m['moderationStatus'] as String? ??\n" +
      '                store.clubModerationStatusOrNull(id) ??\n' +
      "                'pending';",
    "            final status = m['moderationStatus'] as String? ??\n" +
      '                store.clubModerationStatusOrNull(id) ??\n' +
      "                'active';",
  );
  // After loading store clubs, promote any leftover pending to active
  if (!src.includes('// promote leftover pending clubs')) {
    const marker = '    final pendingNames = store.clubs';
    const idx = src.indexOf(marker);
    if (idx >= 0) {
      const inject =
        '    // promote leftover pending clubs (승인 개념 제거)\n' +
        '    for (final c in store.clubs) {\n' +
        "      if (store.clubModerationStatus(c.id) == 'pending') {\n" +
        "        store.upsertClub(c, moderationStatus: 'active', persist: false);\n" +
        '      }\n' +
        '    }\n\n    ';
      src = src.slice(0, idx) + inject + src.slice(idx);
    }
  }
  fs.writeFileSync(file, src, 'utf8');
  console.log('OK', rel);
}

// mock_store_persistence default
{
  const rel = 'lib/data/repositories/mock/mock_store_persistence.dart';
  const file = path.join(__dirname, '..', rel);
  let src = fs.readFileSync(file, 'utf8');
  if (src.includes("?? 'pending'")) {
    src = src.replace(
      "final status = m['moderationStatus'] as String? ?? 'pending';",
      "final status = m['moderationStatus'] as String? ?? 'active';",
    );
    fs.writeFileSync(file, src, 'utf8');
    console.log('OK', rel);
  } else {
    console.log('skip', rel);
  }
}
