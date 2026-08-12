/**
 * Fix membership points not showing after attend/comment.
 * - Award under club member id (m_creator_*), not auth user id
 * - Read sums alias ids so old mis-keyed events still count
 * - Persist immediately on award
 */
const fs = require('fs');
const path = require('path');
const file = path.join(__dirname, '..', 'lib/providers/club_provider.dart');
let src = fs.readFileSync(file, 'utf8');

function must(oldS, newS, label) {
  if (!src.includes(oldS)) {
    console.error('FAIL:', label);
    process.exit(1);
  }
  src = src.replace(oldS, newS);
  console.log('OK', label);
}

// 1) Comment awards → club member id + persist
must(
  [
    "    final newComment = AnnouncementComment(",
    "      id: 'cmt_${DateTime.now().millisecondsSinceEpoch}',",
    '      authorId: currentUserId,',
    '      authorName: currentUserName,',
    '      text: text.trim(),',
    '      createdAt: DateTime.now(),',
    '    );',
    '',
    '    // 댓글 추가',
    '    final updatedComments = [...a.comments, newComment];',
  ].join('\n'),
  [
    '    final pointMemberId = currentMember?.id ?? currentUserId;',
    "    final newComment = AnnouncementComment(",
    "      id: 'cmt_${DateTime.now().millisecondsSinceEpoch}',",
    '      authorId: pointMemberId,',
    '      authorName: currentUserName,',
    '      text: text.trim(),',
    '      createdAt: DateTime.now(),',
    '    );',
    '',
    '    // 댓글 추가',
    '    final updatedComments = [...a.comments, newComment];',
  ].join('\n'),
  'comment author id',
);

must(
  [
    '    // 첫 댓글인 경우에만 포인트 +2 (동일 공지에 중복 부여 방지)',
    '    final alreadyCommented = a.comments.any((c) => c.authorId == currentUserId);',
    '    if (!alreadyCommented) {',
    '      addMembershipPoint(',
    '        memberId: currentUserId,',
    '        type: MembershipPointType.commentActivity,',
    '        points: 2,',
    "        desc: '공지 참여 (+2): ${a.title}',",
    '      );',
    '    }',
  ].join('\n'),
  [
    '    // 첫 댓글인 경우에만 포인트 +2 (동일 공지에 중복 부여 방지)',
    '    final alreadyCommented = a.comments.any((c) =>',
    '        c.authorId == pointMemberId || c.authorId == currentUserId);',
    '    if (!alreadyCommented) {',
    '      addMembershipPoint(',
    '        memberId: pointMemberId,',
    '        type: MembershipPointType.commentActivity,',
    '        points: 2,',
    "        desc: '공지 참여 (+2): ${a.title}',",
    '      );',
    '    }',
  ].join('\n'),
  'comment points id',
);

must(
  [
    '    notifyListeners();',
    '    return !alreadyCommented; // 포인트 획득 여부 반환',
    '  }',
  ].join('\n'),
  [
    '    notifyListeners();',
    '    _persistImmediately();',
    '    return !alreadyCommented; // 포인트 획득 여부 반환',
    '  }',
  ].join('\n'),
  'comment persist',
);

// 2) respondToSchedule persist
must(
  [
    '    ));',
    '    notifyListeners();',
    '    return true;',
    '  }',
    '',
    '  /// 총무 권한 — 특정 회원의 참석 상태를 강제로 변경하고 즉시 앱 푸시 알림 발송',
  ].join('\n'),
  [
    '    ));',
    '    notifyListeners();',
    '    _persistImmediately();',
    '    return true;',
    '  }',
    '',
    '  /// 총무 권한 — 특정 회원의 참석 상태를 강제로 변경하고 즉시 앱 푸시 알림 발송',
  ].join('\n'),
  'attend persist',
);

// 3) Replace getMembershipPoints + addMembershipPoint block with alias-aware version
must(
  [
    '  /// 특정 회원의 올해 멤버십 포인트 합산',
    '  int getMembershipPoints(String memberId) {',
    '    final now = DateTime.now();',
    '    final events = _pointEvents[memberId] ?? [];',
    '    return events',
    '        .where((e) => e.date.year == now.year)',
    '        .fold(0, (sum, e) => sum + e.points);',
    '  }',
  ].join('\n'),
  [
    '  /// 같은 사람의 포인트 키 (auth id / m_creator / currentMember 혼용 보정)',
    '  Set<String> _membershipPointKeysFor(String memberId) {',
    '    final keys = <String>{memberId};',
    "    final creatorId = 'm_creator_${selectedClub.id}';",
    '    final meIds = <String>{',
    '      currentUserId,',
    '      if (currentMember != null) currentMember!.id,',
    '      creatorId,',
    '      if (_persistAuthUserId != null) _persistAuthUserId!,',
    '    };',
    '    if (meIds.contains(memberId)) {',
    '      keys.addAll(meIds);',
    '    }',
    '    // 생성자 레코드면 auth/creator 키도 합산',
    '    if (memberId == creatorId || memberId.startsWith(\'m_creator_\')) {',
    '      keys.add(creatorId);',
    '      keys.add(currentUserId);',
    '      if (_persistAuthUserId != null) keys.add(_persistAuthUserId!);',
    '    }',
    '    return keys;',
    '  }',
    '',
    '  /// 특정 회원의 올해 멤버십 포인트 합산',
    '  int getMembershipPoints(String memberId) {',
    '    final now = DateTime.now();',
    '    var sum = 0;',
    '    for (final key in _membershipPointKeysFor(memberId)) {',
    '      final events = _pointEvents[key] ?? const <MembershipPointEvent>[];',
    '      for (final e in events) {',
    '        if (e.date.year == now.year) sum += e.points;',
    '      }',
    '    }',
    '    return sum;',
    '  }',
  ].join('\n'),
  'alias-aware getMembershipPoints',
);

must(
  [
    '  /// 포인트 적립',
    '  void addMembershipPoint({',
    '    required String memberId,',
    '    required MembershipPointType type,',
    '    required int points,',
    '    required String desc,',
    '  }) {',
    '    _pointEvents.putIfAbsent(memberId, () => []);',
    '    _pointEvents[memberId]!.add(MembershipPointEvent(',
    '      type: type,',
    '      points: points,',
    '      desc: desc,',
    '      date: DateTime.now(),',
    '    ));',
    '    notifyListeners();',
    '  }',
  ].join('\n'),
  [
    '  /// 포인트 적립 (클럽 회원 id 기준으로 저장 + 즉시 영속화)',
    '  void addMembershipPoint({',
    '    required String memberId,',
    '    required MembershipPointType type,',
    '    required int points,',
    '    required String desc,',
    '  }) {',
    '    // 가능하면 현재 클럽 멤버 id로 정규화',
    '    final canonical = (memberId == currentUserId ||',
    '            memberId == _persistAuthUserId)',
    '        ? (currentMember?.id ?? memberId)',
    '        : memberId;',
    '    _pointEvents.putIfAbsent(canonical, () => []);',
    '    _pointEvents[canonical]!.add(MembershipPointEvent(',
    '      type: type,',
    '      points: points,',
    '      desc: desc,',
    '      date: DateTime.now(),',
    '    ));',
    '    notifyListeners();',
    '    _persistImmediately();',
    '  }',
  ].join('\n'),
  'addMembershipPoint persist+canonical',
);

fs.writeFileSync(file, src, 'utf8');
console.log('DONE');
