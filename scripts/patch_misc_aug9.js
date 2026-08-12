/**
 * Misc Aug 9 fixes: logo, signup→users, points, admin members, club_room counts
 */
const fs = require('fs');
const path = require('path');

function read(rel) {
  return fs.readFileSync(path.join(__dirname, '..', rel), 'utf8');
}
function write(rel, src) {
  fs.writeFileSync(path.join(__dirname, '..', rel), src, 'utf8');
  console.log('OK', rel);
}
function mustReplace(src, oldS, newS, label) {
  if (!src.includes(oldS)) throw new Error('FAIL ' + label);
  return src.replace(oldS, newS);
}

// ── 3) Intro logo ──
{
  let src = read('lib/widgets/rounder_logo.dart');
  src = mustReplace(
    src,
    "  static const verticalAssetPath =\n      'assets/icons/rounder_emblem_nobg.png';",
    "  static const verticalAssetPath =\n      'assets/images/rounder_intro_logo.png';",
    'logo path',
  );
  write('lib/widgets/rounder_logo.dart', src);

  let login = read('lib/screens/auth/login_screen.dart');
  login = mustReplace(
    login,
    '              RounderLogo(\n                vertical: true,\n                height: h * 0.30,\n                width: h * 0.236,\n              ),',
    '              RounderLogo(\n                vertical: true,\n                height: h * 0.38,\n                width: h * 0.38,\n              ),',
    'logo size',
  );
  // Reduce top spacer so logo isn't pushed down
  login = mustReplace(
    login,
    '              const Spacer(flex: 2),\n\n              // ── 로고 ──',
    '              const Spacer(flex: 1),\n\n              // ── 로고 ──',
    'logo spacer',
  );
  write('lib/screens/auth/login_screen.dart', login);

  let pub = read('pubspec.yaml');
  if (!pub.includes('rounder_intro_logo.png')) {
    pub = mustReplace(
      pub,
      '    - assets/images/rounder_logo_vertical_transparent.png',
      '    - assets/images/rounder_logo_vertical_transparent.png\n    - assets/images/rounder_intro_logo.png',
      'pubspec asset',
    );
    write('pubspec.yaml', pub);
  }
}

// ── 1) Signup → platform users (mock + firestore) ──
{
  let src = read('lib/providers/auth_provider.dart');
  if (!src.includes('registerPlatformUser')) {
    // add import if needed - check existing imports
    if (!src.includes('app_dependencies')) {
      src = src.replace(
        "import 'package:flutter/foundation.dart';",
        "import 'package:flutter/foundation.dart';\nimport '../di/app_dependencies.dart';\nimport '../data/repositories/mock/mock_data_store.dart';\nimport 'package:cloud_firestore/cloud_firestore.dart';\nimport '../core/firebase/firestore_paths.dart';",
      );
    }
    src = mustReplace(
      src,
      '    _registeredUsers.add(newUser);\n    _currentUser = newUser;\n    // ignore: unawaited_futures\n    FirebaseAuthBridge.ensureSignedIn(newUser);\n    _clearVerifyState();\n    notifyListeners();\n    return newUser;',
      [
        '    _registeredUsers.add(newUser);',
        '    _currentUser = newUser;',
        '    // ignore: unawaited_futures',
        '    FirebaseAuthBridge.ensureSignedIn(newUser);',
        '    // 어드민 회원 수: 모임 미가입 신규 유저도 카운트',
        '    // ignore: unawaited_futures',
        '    _persistPlatformUser(newUser);',
        '    _clearVerifyState();',
        '    notifyListeners();',
        '    return newUser;',
      ].join('\n'),
      'completeSignup persist',
    );

    // append helper before end of class — find last closing of class carefully
    if (!src.includes('_persistPlatformUser')) {
      const helper = `
  Future<void> _persistPlatformUser(AppUser user) async {
    try {
      final deps = AppDependencies.instance;
      if (deps.isOfflineMockMode) {
        final store = deps.mockDataStore;
        if (store != null) {
          store.upsertAppUser(
            MockAppUser(
              id: user.id,
              name: user.name,
              phone: user.phone,
              gender: '남',
              createdAt: DateTime.now(),
            ),
          );
        }
        return;
      }
      await FirebaseFirestore.instance
          .collection(FirestorePaths.users)
          .doc(user.id)
          .set({
        'name': user.name,
        'phone': user.phone,
        'nickname': user.name,
        'gender': '남',
        'account_status': 'normal',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[AuthProvider] persist platform user failed: \$e');
    }
  }
`;
      // insert before final class closing — AuthProvider ends with last method
      const marker = '  InviteToken? findToken(String token) {';
      // better: append before last `\n}` of file's main class
      const idx = src.lastIndexOf('\n}');
      if (idx < 0) throw new Error('no class end');
      src = src.slice(0, idx) + helper + src.slice(idx);
    }
    write('lib/providers/auth_provider.dart', src);
  }
}

// mock upsertAppUser
{
  let src = read('lib/data/repositories/mock/mock_data_store.dart');
  if (!src.includes('upsertAppUser')) {
    src = mustReplace(
      src,
      '  void addAppUser(MockAppUser user) {\n    appUsers.add(\n',
      '  void upsertAppUser(MockAppUser user) {\n    final i = appUsers.indexWhere((u) => u.id == user.id);\n    if (i >= 0) {\n      appUsers[i] = user;\n    } else {\n      appUsers.add(user);\n    }\n    notifyListeners();\n    _schedulePersist();\n  }\n\n  void addAppUser(MockAppUser user) {\n    appUsers.add(\n',
      'upsertAppUser',
    );
    // If addAppUser signature differs, try alternate
    if (!src.includes('upsertAppUser')) {
      // find appUsers.add location near seed
      const anchor = '  final List<MockAppUser> appUsers = [];';
      if (!src.includes(anchor)) throw new Error('appUsers missing');
      src = src.replace(
        anchor,
        anchor +
          `\n\n  void upsertAppUser(MockAppUser user) {\n    final i = appUsers.indexWhere((u) => u.id == user.id);\n    if (i >= 0) {\n      appUsers[i] = user;\n    } else {\n      appUsers.add(user);\n    }\n    notifyListeners();\n    _schedulePersist();\n  }`,
      );
    }
    write('lib/data/repositories/mock/mock_data_store.dart', src);
  }
}

// ── 7/8) Membership points ranking + attend award ──
{
  let src = read('lib/providers/club_provider.dart');
  src = mustReplace(
    src,
    [
      '  /// 전체 멤버 포인트 조회 (내림차순)',
      '  List<MapEntry<String, int>> get memberPointsRanking {',
      '    final result = <MapEntry<String, int>>[];',
      '    for (final m in _members) {',
      '      result.add(MapEntry(m.id, getMembershipPoints(m.id)));',
      '    }',
      '    result.sort((a, b) => b.value.compareTo(a.value));',
      '    return result;',
      '  }',
    ].join('\n'),
    [
      '  /// 선택 모임 활성 회원 포인트 랭킹 (내림차순)',
      '  List<MapEntry<String, int>> get memberPointsRanking {',
      '    final result = <MapEntry<String, int>>[];',
      '    for (final m in activeMembers) {',
      '      result.add(MapEntry(m.id, getMembershipPoints(m.id)));',
      '    }',
      '    result.sort((a, b) => b.value.compareTo(a.value));',
      '    return result;',
      '  }',
      '',
      '  Member? memberById(String memberId) {',
      '    return activeMembers.where((m) => m.id == memberId).firstOrNull ??',
      '        _members.where((m) => m.id == memberId).firstOrNull;',
      '  }',
    ].join('\n'),
    'points ranking scope',
  );

  // Award/deduct in respondToSchedule
  src = mustReplace(
    src,
    [
      '    // 참석 → 불참으로 바뀌면 자리 생김 → 대기자 알림',
      "    if (prev == '참석' && response == '불참') {",
      '      notifyFirstWaiting(scheduleId);',
      '    }',
      '',
      '    // 활동 피드에 추가',
    ].join('\n'),
    [
      '    // 참석 → 불참으로 바뀌면 자리 생김 → 대기자 알림',
      "    if (prev == '참석' && response == '불참') {",
      '      notifyFirstWaiting(scheduleId);',
      '    }',
      '',
      '    // 멤버십 포인트: 참석 +10 / 참석→불참 -10 (일정당 1회)',
      '    _syncAttendancePoints(',
      '      memberId: myId,',
      '      scheduleId: scheduleId,',
      '      scheduleTitle: schedule.displayTitle,',
      '      prev: prev,',
      '      response: response,',
      '    );',
      '',
      '    // 활동 피드에 추가',
    ].join('\n'),
    'respond points hook',
  );

  if (!src.includes('_syncAttendancePoints')) {
    src = mustReplace(
      src,
      '  /// 포인트 적립\n  void addMembershipPoint({',
      [
        '  void _syncAttendancePoints({',
        '    required String memberId,',
        '    required String scheduleId,',
        '    required String scheduleTitle,',
        '    required String? prev,',
        '    required String response,',
        '  }) {',
        '    final tag = \'|$scheduleId\';',
        '    final events = _pointEvents[memberId] ?? [];',
        "    if (response == '참석' && prev != '참석') {",
        '      final already = events.any((e) =>',
        '          e.type == MembershipPointType.roundAttendance &&',
        '          e.points > 0 &&',
        '          e.desc.contains(tag));',
        '      if (!already) {',
        '        addMembershipPoint(',
        '          memberId: memberId,',
        '          type: MembershipPointType.roundAttendance,',
        '          points: 10,',
        "          desc: '\$scheduleTitle 참석\$tag',",
        '        );',
        '      }',
        "    } else if (prev == '참석' && response == '불참') {",
        '      final alreadyDeducted = events.any((e) =>',
        '          e.points < 0 && e.desc.contains(tag));',
        '      if (!alreadyDeducted) {',
        '        addMembershipPoint(',
        '          memberId: memberId,',
        '          type: MembershipPointType.noShow,',
        '          points: -10,',
        "          desc: '\$scheduleTitle 불참 변경\$tag',",
        '        );',
        '      }',
        '    }',
        '  }',
        '',
        '  /// 포인트 적립',
        '  void addMembershipPoint({',
      ].join('\n'),
      'syncAttendancePoints method',
    );
  }

  // Fix JS-escaped $ in desc strings if any
  src = src.replace("desc: '\\$scheduleTitle 참석\\$tag',", "desc: '$scheduleTitle 참석$tag',");
  src = src.replace("desc: '\\$scheduleTitle 불참 변경\\$tag',", "desc: '$scheduleTitle 불참 변경$tag',");

  write('lib/providers/club_provider.dart', src);
}

// members_screen name resolve
{
  let src = read('lib/screens/members/members_screen.dart');
  src = mustReplace(
    src,
    [
      '                  final memberObj = provider.activeMembers',
      '                      .where((m) => m.id == memberId)',
      '                      .firstOrNull;',
      '                  final name = memberObj?.name ?? memberId;',
    ].join('\n'),
    [
      '                  final memberObj = provider.memberById(memberId);',
      '                  final name = memberObj?.name ?? memberId;',
    ].join('\n'),
    'points name resolve',
  );
  write('lib/screens/members/members_screen.dart', src);
}

// ── 6) club_room attendance: ignore orphan responses ──
{
  let src = read('lib/screens/club_room/club_room_screen.dart');
  src = mustReplace(
    src,
    [
      '        final responses = nextSchedule.responses;',
      '        final guestIds = {for (final m in prov.guestMembers) m.id};',
      '        final guestNames = {for (final m in prov.guestMembers) m.name};',
      '        bool isGuest(AttendanceResponse r) =>',
      '            guestIds.contains(r.memberId) || guestNames.contains(r.memberName);',
      '',
      '        // 게스트: 미응답 → 미답변 제외. 참석 시에만 참석 집계에 포함.',
      '        final confirmedList =',
      "            responses.where((r) => r.response == '참석').toList();",
    ].join('\n'),
    [
      '        final memberIds = {for (final m in prov.activeMembers) m.id};',
      '        final responses = nextSchedule.responses',
      '            .where((r) => memberIds.contains(r.memberId))',
      '            .toList();',
      '        final guestIds = {for (final m in prov.guestMembers) m.id};',
      '        final guestNames = {for (final m in prov.guestMembers) m.name};',
      '        bool isGuest(AttendanceResponse r) =>',
      '            guestIds.contains(r.memberId) || guestNames.contains(r.memberName);',
      '',
      '        // 게스트: 미응답 → 미답변 제외. 참석 시에만 참석 집계에 포함.',
      '        // 클럽 회원 id가 아닌 응답(옛 자동참석/ID불일치)은 제외.',
      '        final confirmedList =',
      "            responses.where((r) => r.response == '참석').toList();",
    ].join('\n'),
    'club_room orphan filter',
  );
  write('lib/screens/club_room/club_room_screen.dart', src);
}

console.log('DONE misc part1');
