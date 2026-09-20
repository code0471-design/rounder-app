import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 명단 행을 합치거나 옮길 때 그 사람에게 붙은 기록이 **전부** 따라와야 한다.
/// 하나라도 빠지면 "회비는 따라왔는데 시상이 사라졌다"가 된다.
void main() {
  late String remapFn;

  setUpAll(() {
    final src = File('lib/providers/club_provider.dart').readAsStringSync();
    final start = src.indexOf('void _applyRosterIdRemap(');
    expect(start, greaterThan(0));
    // 다음 함수 선언 전까지
    final end = src.indexOf('  /// 이름만 바꾼다.', start);
    expect(end, greaterThan(start));
    remapFn = src.substring(start, end);
  });

  test('회비·시상·참석·조편성·스코어·포인트가 모두 따라온다', () {
    expect(remapFn.contains('_duesPayments'), isTrue, reason: '회비 납부');
    expect(remapFn.contains('_paymentRequests'), isTrue, reason: '입금 확인 요청');
    expect(remapFn.contains('_awardRecords'), isTrue, reason: '시상');
    expect(remapFn.contains('_roundScores'), isTrue, reason: '스코어');
    expect(remapFn.contains('_pointEvents'), isTrue, reason: '포인트·랭킹');
    expect(remapFn.contains('_schedules'), isTrue, reason: '참석 응답');
    expect(remapFn.contains('_groupAssignments'), isTrue, reason: '조편성');
  });

  test('대기 명단·동반자·작성자·소개자도 따라온다', () {
    expect(remapFn.contains('_waitingList'), isTrue, reason: '대기 명단');
    expect(remapFn.contains('for (final id in r.companionMemberIds)'), isTrue,
        reason: '동반자를 안 옮기면 조편성에서 빈 자리가 된다');
    expect(remapFn.contains('_announcements'), isTrue, reason: '공지·댓글 작성자');
    expect(remapFn.contains('_activities'), isTrue, reason: '활동 피드');
    expect(remapFn.contains('referrerId'), isTrue, reason: '소개자(추천인)');
  });
}
