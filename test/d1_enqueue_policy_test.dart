import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/utils/d1_enqueue_policy.dart';

void main() {
  test('아레나 명단 id와 로그인 id는 같은 수신자로 접힌다', () {
    const arena = 'c_1786973797931';
    const google = 'google_107587661463302574049';
    expect(
      D1EnqueuePolicy.canonicalUserId(
        memberOrUserId: 'm_${arena}_$google',
        clubId: 'c_other',
      ),
      google,
      reason: '선택된 모임이 달라도 같은 사람이 두 줄이 되면 알림톡이 두 번 간다',
    );
    expect(
      D1EnqueuePolicy.canonicalUserId(memberOrUserId: google, clubId: arena),
      google,
    );
  });

  test('장창현은 알라딘만 받고 아레나 대기열에서는 막는다', () {
    const jang = 'kakao_5049673364';
    expect(
      D1EnqueuePolicy.isBlockedRecipient(
        name: '장창현',
        userId: jang,
        clubId: 'c_1786973797931',
      ),
      isTrue,
      reason: '아레나 회원이 아닌데 D-1이 나갔다',
    );
    expect(
      D1EnqueuePolicy.isBlockedRecipient(
        name: '장창현',
        userId: jang,
        clubId: 'c_1789270673471',
        creatorUserId: jang,
      ),
      isFalse,
      reason: '알라딘 방장 본인 일정은 나가야 한다',
    );
  });

  test('같은 일정·같은 번호는 한 통으로 묶는다', () {
    expect(
      D1EnqueuePolicy.sendDedupKey(
        scheduleId: 'sched_1',
        sendOn: '2026-09-22',
        phone: '010-9287-4073',
      ),
      D1EnqueuePolicy.sendDedupKey(
        scheduleId: 'sched_1',
        sendOn: '2026-09-22',
        phone: '01092874073',
      ),
    );
  });
}
