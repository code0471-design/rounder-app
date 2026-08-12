const fs = require('fs');
const path = require('path');

const p = path.join(__dirname, '..', 'lib', 'providers', 'club_provider.dart');
let s = fs.readFileSync(p, 'utf8');

if (s.includes('_purgeLegacySeedJoinNotifications')) {
  console.log('purge helper already present');
  process.exit(0);
}

const from =
  '    // 다른 계정에서 신청한 가입 요청·알림을 공유 스토어에서 병합\n' +
  '    await mergeSharedJoinRequests();\n' +
  '    notifyListeners();\n' +
  '  }\n\n' +
  '  /// 공유 대기열';

const to =
  '    // 다른 계정에서 신청한 가입 요청·알림을 공유 스토어에서 병합\n' +
  '    await mergeSharedJoinRequests();\n' +
  '    _purgeLegacySeedJoinNotifications();\n' +
  '    notifyListeners();\n' +
  '  }\n\n' +
  '  /// 예전 시드 가입 알림 + 동일 targetId 중복 제거 (localStorage 잔존 포함)\n' +
  '  void _purgeLegacySeedJoinNotifications() {\n' +
  "    const seedIds = {'noti1', 'noti3', 'noti_jr3'};\n" +
  '    _appNotifications.removeWhere((n) => seedIds.contains(n.id));\n' +
  '    final seenTargets = <String>{};\n' +
  '    _appNotifications.removeWhere((n) {\n' +
  '      if (n.type != AppNotificationType.joinRequest) return false;\n' +
  '      final tid = n.targetId;\n' +
  '      if (tid == null || tid.isEmpty) return false;\n' +
  '      if (!seenTargets.add(tid)) return true;\n' +
  '      return false;\n' +
  '    });\n' +
  '  }\n\n' +
  '  /// 공유 대기열';

if (!s.includes(from)) {
  console.error('marker not found');
  process.exit(2);
}

s = s.replace(from, to);
fs.writeFileSync(p, s);
console.log('OK purge helper injected');
