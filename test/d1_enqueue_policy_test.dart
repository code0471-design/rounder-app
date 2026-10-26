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

  test('아레나 명단의 장창현은 회비 안내를 받는다', () {
    const jang = 'kakao_5049673364';
    const arena = 'c_1786973797931';
    expect(
      D1EnqueuePolicy.isBlockedRecipient(
        name: '장창현',
        userId: 'm_${arena}_$jang',
        clubId: arena,
      ),
      isFalse,
    );
    expect(
      D1EnqueuePolicy.isBlockedRecipient(
        name: '장창현',
        userId: jang,
        clubId: 'c_1789270673471',
        creatorUserId: jang,
      ),
      isFalse,
    );
  });

  test('같은 모임·같은 날 월회비 설정이 두 개여도 번호당 한 통이다', () {
    expect(
      D1EnqueuePolicy.sendDedupKey(
        scheduleId: 'dues_ds1',
        sendOn: '2026-09-24',
        phone: '010-4511-0471',
        kind: 'dues',
        clubId: 'c_1786973797931',
      ),
      D1EnqueuePolicy.sendDedupKey(
        scheduleId: 'dues_ds_1786973987209',
        sendOn: '2026-09-24',
        phone: '01045110471',
        kind: 'dues',
        clubId: 'c_1786973797931',
      ),
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
    expect(
      D1EnqueuePolicy.sendDedupKey(
        scheduleId: 'sched_1',
        sendOn: '2026-09-22',
        phone: '821092874073',
      ),
      D1EnqueuePolicy.sendDedupKey(
        scheduleId: 'sched_1',
        sendOn: '2026-09-22',
        phone: '01092874073',
      ),
      reason: '82 국가번호와 010이 다르면 같은 사람한테 두 통 간다',
    );
  });
}
