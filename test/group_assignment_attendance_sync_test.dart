import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 조편성 참석 인원 — 열린 시점 스냅샷이 아니라 provider 최신 schedule을 써야 한다.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/group_assignment/group_assignment_screen.dart')
        .readAsStringSync();
  });

  test('참석자 목록은 scheduleById 기준이어야 한다', () {
    expect(source.contains('provider.scheduleById(widget.schedule.id)'), isTrue);
    expect(source.contains('widget.schedule.responses'), isFalse,
        reason: '스냅샷 responses를 쓰면 참석/불참 후 조편성 인원이 어긋난다');
  });

  test('확정된 조편성은 수정하기만으로 미확정이 되지 않는다', () {
    expect(source.contains("isFinalized && !_editing ? '수정하기' : '저장'"),
        isTrue);
    expect(source.contains('_beginEdit()'), isTrue);
    final begin = source.indexOf('void _beginEdit()');
    final save = source.indexOf('Future<void> _confirmFinalize');
    expect(begin, greaterThan(-1));
    expect(save, greaterThan(begin));
    expect(source.substring(begin, save).contains('unfinalize'), isFalse,
        reason: '수정하기가 바로 미확정으로 저장되면 뒤로가기만 해도 확정이 풀린다');
    expect(source.contains('자동배정 옵션'), isTrue);
    expect(source.contains('opt.description'), isTrue);
  });

  test('초기화 후 빈 저장은 미확정, 다시 짜면 확정과 알림톡 얼럿', () {
    expect(source.contains("'초기화'"), isTrue);
    expect(source.contains('_confirmClear(provider)'), isTrue);
    expect(source.contains('if (assigned == 0)'), isTrue);
    expect(source.contains('p.unfinalizeAssignment'), isTrue);
    expect(source.contains('AlimtalkUtils.promptGroupFinalize'), isTrue);
    expect(source.contains('sendGroupFinalizeAlimtalk'), isTrue);
    final empty = source.indexOf('if (assigned == 0)');
    final unfinal = source.indexOf('p.unfinalizeAssignment');
    final finalize = source.indexOf('p.finalizeAssignment');
    final prompt = source.indexOf('AlimtalkUtils.promptGroupFinalize');
    expect(unfinal, greaterThan(empty));
    expect(unfinal, lessThan(finalize));
    expect(prompt, greaterThan(finalize),
        reason: '다시 짠 뒤 저장만 확정+알림톡 얼럿');
    final provider = File('lib/providers/club_provider.dart').readAsStringSync();
    final start = provider.indexOf('void finalizeAssignment(');
    final end = provider.indexOf('void sendGroupFinalizeAlimtalk(');
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    expect(provider.substring(start, end).contains('_dispatchClubAlimtalk'),
        isFalse,
        reason: '확정만으로 알림톡이 나가면 초기화 저장에도 발송된다');
    expect(provider.substring(end, end + 500).contains('_dispatchClubAlimtalk'),
        isTrue);
  });
}
