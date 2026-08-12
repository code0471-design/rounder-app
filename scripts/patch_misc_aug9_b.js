const fs = require('fs');
const path = require('path');
function read(rel) { return fs.readFileSync(path.join(__dirname, '..', rel), 'utf8'); }
function write(rel, src) { fs.writeFileSync(path.join(__dirname, '..', rel), src, 'utf8'); console.log('OK', rel); }
function must(src, a, b, label) {
  if (!src.includes(a)) throw new Error('FAIL ' + label);
  return src.replace(a, b);
}

// auth imports + helper
{
  let src = read('lib/providers/auth_provider.dart');
  if (!src.includes("import '../di/app_dependencies.dart'")) {
    src = must(
      src,
      "import '../services/firebase_auth_bridge.dart';\n",
      [
        "import '../services/firebase_auth_bridge.dart';",
        "import '../di/app_dependencies.dart';",
        "import '../data/repositories/mock/mock_data_store.dart';",
        "import 'package:cloud_firestore/cloud_firestore.dart';",
        "import '../core/firebase/firestore_paths.dart';",
        '',
      ].join('\n'),
      'auth imports',
    );
  }
  if (!src.includes('Future<void> _persistPlatformUser')) {
    src = must(
      src,
      '  String _normalizePhone(String phone) =>\n      phone.replaceAll(RegExp(r\'[^0-9]\'), \'\');\n',
      [
        '  Future<void> _persistPlatformUser(AppUser user) async {',
        '    try {',
        '      final deps = AppDependencies.instance;',
        '      if (deps.isOfflineMockMode) {',
        '        final store = deps.mockDataStore;',
        '        if (store != null) {',
        '          store.upsertAppUser(',
        '            MockAppUser(',
        '              id: user.id,',
        '              name: user.name,',
        '              phone: user.phone,',
        "              gender: '남',",
        '              createdAt: DateTime.now(),',
        '            ),',
        '          );',
        '        }',
        '        return;',
        '      }',
        '      await FirebaseFirestore.instance',
        '          .collection(FirestorePaths.users)',
        '          .doc(user.id)',
        '          .set({',
        "        'name': user.name,",
        "        'phone': user.phone,",
        "        'nickname': user.name,",
        "        'gender': '남',",
        "        'account_status': 'normal',",
        "        'created_at': FieldValue.serverTimestamp(),",
        "        'updated_at': FieldValue.serverTimestamp(),",
        '      }, SetOptions(merge: true));',
        '    } catch (e) {',
        "      debugPrint('[AuthProvider] persist platform user failed: \$e');",
        '    }',
        '  }',
        '',
        '  String _normalizePhone(String phone) =>',
        "      phone.replaceAll(RegExp(r'[^0-9]'), '');",
        '',
      ].join('\n'),
      'persist helper',
    );
    src = src.replace(
      "debugPrint('[AuthProvider] persist platform user failed: \\$e');",
      "debugPrint('[AuthProvider] persist platform user failed: $e');",
    );
  }
  write('lib/providers/auth_provider.dart', src);
}

// mock upsertAppUser
{
  let src = read('lib/data/repositories/mock/mock_data_store.dart');
  if (!src.includes('upsertAppUser')) {
    src = must(
      src,
      '  /// Auth와 공유할 앱 사용자 목록 (어드민 회원 관리)\n  final List<MockAppUser> appUsers = [];\n',
      [
        '  /// Auth와 공유할 앱 사용자 목록 (어드민 회원 관리)',
        '  final List<MockAppUser> appUsers = [];',
        '',
        '  void upsertAppUser(MockAppUser user) {',
        '    final i = appUsers.indexWhere((u) => u.id == user.id);',
        '    if (i >= 0) {',
        '      appUsers[i] = user;',
        '    } else {',
        '      appUsers.add(user);',
        '    }',
        '    notifyListeners();',
        '    _schedulePersist();',
        '  }',
        '',
      ].join('\n'),
      'upsertAppUser',
    );
  }
  write('lib/data/repositories/mock/mock_data_store.dart', src);
}

// points ranking + sync
{
  let src = read('lib/providers/club_provider.dart');
  if (!src.includes('memberById(')) {
    src = must(
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
      'ranking',
    );
  }

  if (!src.includes('_syncAttendancePoints')) {
    src = must(
      src,
      [
        "    if (prev == '참석' && response == '불참') {",
        '      notifyFirstWaiting(scheduleId);',
        '    }',
        '',
        '    // 활동 피드에 추가',
      ].join('\n'),
      [
        "    if (prev == '참석' && response == '불참') {",
        '      notifyFirstWaiting(scheduleId);',
        '    }',
        '',
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
      'points hook',
    );

    src = must(
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
        "    final tag = '|$scheduleId';",
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
        "          desc: '$scheduleTitle 참석$tag',",
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
        "          desc: '$scheduleTitle 불참 변경$tag',",
        '        );',
        '      }',
        '    }',
        '  }',
        '',
        '  /// 포인트 적립',
        '  void addMembershipPoint({',
      ].join('\n'),
      'sync method',
    );
  }
  write('lib/providers/club_provider.dart', src);
}

// members_screen name
{
  let src = read('lib/screens/members/members_screen.dart');
  if (src.includes('provider.memberById(memberId)')) {
    console.log('skip members name');
  } else {
    src = must(
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
      'name resolve',
    );
    write('lib/screens/members/members_screen.dart', src);
  }
}

// club_room orphan filter
{
  let src = read('lib/screens/club_room/club_room_screen.dart');
  if (!src.includes('클럽 회원 id가 아닌 응답')) {
    src = must(
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
      'club_room filter',
    );
    write('lib/screens/club_room/club_room_screen.dart', src);
  }
}

// admin club members dialog — load firestore + creator fallback
{
  let src = read('lib/screens/admin/admin_clubs_screen.dart');
  if (!src.includes('_loadClubMembers')) {
    // change _showClubMembers to async loader
    src = must(
      src,
      '  void _showClubMembers(AdminClub club) {\n    final store = AppDependencies.instance.mockDataStore;\n    var members = store?.membersOf(club.id) ?? const <Member>[];\n    if (members.isEmpty && mounted) {\n      members = context.read<ClubProvider>().membersForClub(club.id);\n    }\n\n    showDialog<void>(',
      [
        '  Future<void> _showClubMembers(AdminClub club) async {',
        '    final members = await _loadClubMembers(club);',
        '    if (!mounted) return;',
        '',
        '    showDialog<void>(',
      ].join('\n'),
      'showClubMembers async',
    );

    // insert loader method before _showClubMembers
    src = must(
      src,
      '  Future<void> _showClubMembers(AdminClub club) async {',
      [
        '  Future<List<Member>> _loadClubMembers(AdminClub club) async {',
        '    final store = AppDependencies.instance.mockDataStore;',
        '    var members = store?.membersOf(club.id) ?? const <Member>[];',
        '    if (members.isEmpty && mounted) {',
        '      members = context.read<ClubProvider>().membersForClub(club.id);',
        '    }',
        '    // Firestore: clubs/{id}/members',
        '    if (members.isEmpty && !AppDependencies.instance.isOfflineMockMode) {',
        '      try {',
        '        final snap = await FirebaseFirestore.instance',
        "            .collection('clubs')",
        '            .doc(club.id)',
        "            .collection('members')",
        '            .get();',
        '        members = snap.docs.map((d) {',
        '          final data = d.data();',
        '          return Member(',
        '            id: d.id,',
        "            name: (data['name'] as String?) ?? '',",
        "            gender: (data['gender'] as String?) ?? '남',",
        "            phone: data['phone'] as String?,",
        "            memberType: (data['member_type'] as String?) ??",
        "                (data['memberType'] as String?) ??",
        "                '정회원',",
        "            role: (data['role'] as String?) ?? '일반',",
        "            status: (data['status'] as String?) ?? '활성',",
        '          );',
        '        }).toList();',
        '      } catch (_) {}',
        '    }',
        '    // 최후: 방장 이름만이라도 표시',
        '    if (members.isEmpty && club.host.isNotEmpty) {',
        '      members = [',
        '        Member(',
        "          id: 'host_${club.id}',",
        '          name: club.host,',
        "          gender: '남',",
        "          memberType: '정회원',",
        "          role: '총무',",
        "          status: '활성',",
        '        ),',
        '      ];',
        '    }',
        '    return members;',
        '  }',
        '',
        '  Future<void> _showClubMembers(AdminClub club) async {',
      ].join('\n'),
      'loadClubMembers',
    );

    // ensure imports
    if (!src.includes('cloud_firestore')) {
      src = must(
        src,
        "import 'package:flutter/material.dart';\n",
        "import 'package:flutter/material.dart';\nimport 'package:cloud_firestore/cloud_firestore.dart';\n",
        'firestore import',
      );
    }
    if (!src.includes("import '../../models/club_model.dart'") && !src.includes("import '../../models/club_model.dart\"")) {
      // Member type
      if (!src.includes('club_model.dart')) {
        src = must(
          src,
          "import 'package:provider/provider.dart';\n",
          "import 'package:provider/provider.dart';\nimport '../../models/club_model.dart';\n",
          'member model import',
        );
      }
    }
  }
  write('lib/screens/admin/admin_clubs_screen.dart', src);
}

console.log('DONE b');
