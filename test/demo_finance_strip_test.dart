import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/domain/services/demo_finance_strip.dart';

void main() {
  test('실모임 tx_ 거래는 시드가 아니다', () {
    expect(
      DemoFinanceStrip.isSeedTransaction(
        id: 'tx_1710000000000',
        clubId: 'c_arena',
      ),
      isFalse,
    );
  });

  test('실모임 초기잔고 ob_타임스탬프는 시드가 아니다', () {
    expect(
      DemoFinanceStrip.isSeedTransaction(
        id: 'ob_1710000000000',
        clubId: 'c_arena',
      ),
      isFalse,
    );
  });

  test('데모 시드 거래 id만 시드로 본다', () {
    expect(
      DemoFinanceStrip.isSeedTransaction(id: 'ob_demo', clubId: null),
      isTrue,
    );
    expect(
      DemoFinanceStrip.isSeedTransaction(id: 't_m7_1', clubId: 'c1'),
      isTrue,
    );
  });

  test('실모임 장부의 홍길동 월회비는 시드 유령이다', () {
    expect(DemoFinanceStrip.isHongGilDongGhost('9월 월회비 - 홍길동'), isTrue);
    expect(DemoFinanceStrip.isHongGilDongGhost('9월 월회비 - 안경헌'), isFalse);
    expect(
      DemoFinanceStrip.rewriteLedgerTitle('9월 월회비 - Jeongwon Lee'),
      '9월 월회비 - 이정원',
    );
  });

  test('실모임의 m1 납부는 지운다', () {
    expect(
      DemoFinanceStrip.isSeedDuesPayment(
        id: 'dp_1710000000000',
        memberId: 'm_c_arena_m1',
        inRealClub: true,
      ),
      isTrue,
    );
  });

  test('실모임 납부는 지우지 않는다', () {
    expect(
      DemoFinanceStrip.isSeedDuesPayment(
        id: 'dp_1710000000000',
        memberId: 'm_creator_c_arena',
        inRealClub: true,
      ),
      isFalse,
    );
  });
}
