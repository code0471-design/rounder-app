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
    expect(source.contains("isFinalized && !_editing ? '수정하기' : '확정하기'"),
        isTrue);
    expect(source.contains('_beginEdit()'), isTrue);
    expect(source.contains('p.unfinalizeAssignment'), isFalse,
        reason: '수정하기가 바로 미확정으로 저장되면 뒤로가기만 해도 확정이 풀린다');
    expect(source.contains('자동배정 옵션'), isTrue);
    expect(source.contains('opt.description'), isTrue);
  });

  test('편집 화면에 초기화가 있고 확정 알림톡은 보내기를 고른 뒤에만 나간다', () {
    expect(source.contains("label: const Text("), isTrue);
    expect(source.contains("'초기화'"), isTrue);
    expect(source.contains('onClear: () => _confirmClear(provider)'), isTrue);
    expect(source.contains('_confirmClear'), isTrue);
    expect(source.contains('AlimtalkUtils.promptGroupFinalize'), isTrue);
    expect(source.contains('sendGroupFinalizeAlimtalk'), isTrue);
    expect(source.contains('alreadyFinalized'), isTrue);
    final provider = File('lib/providers/club_provider.dart').readAsStringSync();
    final start = provider.indexOf('void finalizeAssignment(');
    final end = provider.indexOf('void sendGroupFinalizeAlimtalk(');
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    expect(provider.substring(start, end).contains('_dispatchClubAlimtalk'),
        isFalse,
        reason: '확정만으로 알림톡이 나가면 수정·초기화마다 다시 발송된다');
    expect(provider.substring(end, end + 500).contains('_dispatchClubAlimtalk'),
        isTrue);
  });
}
