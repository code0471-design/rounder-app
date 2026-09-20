import 'dart:io';

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

  test('소속 없는 계정 행은 명단에서 뺀다', () {
    final src = File('lib/providers/club_provider.dart').readAsStringSync();
    expect(src.contains('bool _dropUnmemberedAccountRows(String clubId)'), isTrue);
    expect(src.contains('MemberPhoneIndex.removeClub(digits, clubId)'), isTrue);
    expect(src.contains('if (_isSelfTarget(authorId))'), isTrue,
        reason: '내가 올린 사진은 저장된 장창현 이름보다 내 이름을 먼저 쓴다');
    expect(src.contains('if (!_isMyRosterRowById(selectedClub, me.id)) return;'),
        isTrue);
  });

  test('없는 모임은 번호 색인에서 빼는 경로가 있다', () {
    final src = File('lib/services/member_phone_index.dart').readAsStringSync();
    expect(src.contains('_dropClubFromIndex(digits, clubId)'), isTrue);
    expect(src.contains("if (!await _clubExists(clubId))"), isTrue);
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
