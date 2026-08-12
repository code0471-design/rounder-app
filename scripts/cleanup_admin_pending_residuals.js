const fs = require('fs');
const path = require('path');

function patch(rel, fn) {
  const file = path.join(__dirname, '..', rel);
  let src = fs.readFileSync(file, 'utf8');
  const next = fn(src);
  if (next == null) return;
  fs.writeFileSync(file, next, 'utf8');
  console.log('OK', rel);
}

// notifications: remove unused club-approved prefs
patch('lib/screens/admin/admin_notifications_screen.dart', (src) => {
  let s = src;
  s = s.replace('  bool _autoClubApproved = true;\n', '');
  s = s.replace(
    "      _autoClubApproved = prefs.getBool('push_auto_club_approved') ?? true;\n",
    '',
  );
  return s;
});

// models: treat legacy pending as 활성
patch('lib/screens/admin/admin_models.dart', (src) => {
  return src
    .replace("      case 'pending':\n        return '승인대기';", "      case 'pending':\n        return '활성'")
    .replace(
      "      case 'pending':\n        return AdminColors.statusWarn;",
      "      case 'pending':\n        return AdminColors.statusOk;",
    );
});

// theme comment
patch('lib/screens/admin/admin_theme.dart', (src) =>
  src.replace('// 승인대기', '// 경고'),
);

// datasource comment
patch('lib/data/datasources/firestore/firestore_club_datasource.dart', (src) =>
  src.replace(
    '  /// 블라인드·종료만 탐색 숨김 (승인대기는 노출)',
    '  /// 블라인드·종료만 탐색 숨김',
  ),
);
