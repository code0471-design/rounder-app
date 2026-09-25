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

  test('내 소셜 계정 명단 행도 번호로 소속을 만들지 않는다', () {
    expect(
      MemberPhoneIndex.canClaimRow(
        userId: 'kakao_jang',
        clubId: 'c_arena',
        memberId: 'm_c_arena_kakao_jang',
        creatorUserId: 'kakao_host',
      ),
      isFalse,
      reason: '남은 m_{모임}_kakao_장창현 행이 아레나 총무 소속을 다시 만들었다',
    );
    expect(
      MemberPhoneIndex.isSocialAccountRosterId(
        'c_arena',
        'm_c_arena_kakao_jang',
      ),
      isTrue,
    );
    expect(
      MemberPhoneIndex.isPhoneClaimableMemberId(
        'c_arena',
        'm_c_arena_kakao_jang',
      ),
      isFalse,
    );
  });

  test('방장이 손으로 추가한 행만 번호로 잇는다', () {
    expect(
      MemberPhoneIndex.isPhoneClaimableMemberId('c_arena', 'm_1789000000000'),
      isTrue,
    );
    expect(
      MemberPhoneIndex.canClaimRow(
        userId: 'kakao_jang',
        clubId: 'c_arena',
        memberId: 'm_1789000000000',
        creatorUserId: 'kakao_host',
      ),
      isTrue,
    );
    expect(
      MemberPhoneIndex.isPhoneClaimableMemberId(
        'c_arena',
        'm_c_arena_guestnote',
      ),
      isTrue,
    );
  });

  test('이정원 leftover m1 행은 번호로 잇지 않는다', () {
    expect(
      MemberPhoneIndex.canClaimRow(
        userId: 'kakao_jang',
        clubId: 'c_arena',
        memberId: 'm_c_arena_m1',
        creatorUserId: 'kakao_host',
      ),
      isFalse,
    );
  });

  test('소속 없는 계정 행은 명단에서 뺀다', () {
    final src = File('lib/providers/club_provider.dart').readAsStringSync();
    expect(src.contains('bool _dropUnmemberedAccountRows(String clubId)'), isTrue);
    expect(src.contains('MemberPhoneIndex.removeClub(digits, clubId)'), isTrue);
    expect(src.contains('revokeSpuriousPhoneMemberships('), isTrue,
        reason: '잘못된 번호 소속을 먼저 지워야 아레나 총무가 다시 안 붙는다');
    expect(src.contains('MemberPhoneIndex.claimForUser('), isFalse,
        reason: '번호로 소속을 만들면 가입하지 않은 모임이 내 모임이 된다');
    expect(src.contains('if (_isSelfTarget(authorId))'), isTrue);
    expect(src.contains('if (!_isMyRosterRowById(selectedClub, me.id)) return;'),
        isTrue);
    expect(
      src.contains('if (MemberPhoneIndex.isSocialAccountRosterId(clubId, memberId))'),
      isTrue,
      reason: '소셜 행은 번호가 같아도 내 명단 행이 아니다',
    );
  });

  test('번호 색인은 손추가 행만 쓰고 소셜 행은 쓰지 않는다', () {
    final src = File('lib/services/member_phone_index.dart').readAsStringSync();
    expect(src.contains('if (!isPhoneClaimableMemberId(clubId, memberId)) continue;'),
        isTrue);
    expect(src.contains('revokeSpuriousPhoneMemberships('), isTrue);
    expect(src.contains("['claimed_by_phone'] == true"), isTrue);
    expect(src.contains('_dropClubFromIndex(digits, clubId)'), isTrue);
    expect(src.contains("if (!await _clubExists(clubId))"), isTrue);
    expect(src.contains('releasePhoneForUser'), isTrue);
  });
}
