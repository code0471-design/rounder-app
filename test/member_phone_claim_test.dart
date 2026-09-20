import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/services/member_phone_index.dart';

void main() {
  test('남의 방장 자리는 번호가 같아도 소속이 되지 않는다', () {
    expect(
      MemberPhoneIndex.canClaimRow(
        userId: 'kakao_jang',
        clubId: 'c_arena',
        memberId: 'm_creator_c_arena',
        creatorUserId: 'kakao_host',
      ),
      isFalse,
    );
  });

  test('내가 만든 모임 방장 행만 번호로 잇는다', () {
    expect(
      MemberPhoneIndex.canClaimRow(
        userId: 'kakao_jang',
        clubId: 'c_mine',
        memberId: 'm_creator_c_mine',
        creatorUserId: 'kakao_jang',
      ),
      isTrue,
    );
  });

  test('다른 소셜 계정 명단 행은 잇지 않는다', () {
    expect(
      MemberPhoneIndex.canClaimRow(
        userId: 'kakao_jang',
        clubId: 'c_arena',
        memberId: 'm_c_arena_kakao_other',
        creatorUserId: 'kakao_host',
      ),
      isFalse,
    );
  });

  test('내 계정 명단 행은 잇는다', () {
    expect(
      MemberPhoneIndex.canClaimRow(
        userId: 'kakao_jang',
        clubId: 'c_arena',
        memberId: 'm_c_arena_kakao_jang',
        creatorUserId: 'kakao_host',
      ),
      isTrue,
    );
  });
}
