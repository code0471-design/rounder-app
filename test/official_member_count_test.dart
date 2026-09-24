import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/domain/services/official_member_count.dart';
import 'package:golf_rounder/models/club_model.dart';

Member _m(
  String id,
  String name, {
  String type = '정회원',
  String status = '활성',
}) =>
    Member(
      id: id,
      name: name,
      gender: '남',
      memberType: type,
      role: '정회원',
      status: status,
    );

void main() {
  const clubId = 'c_1789197362113';
  const creator = 'kakao_5085342288';

  test('방장 자리와 계정 자리는 같은 사람 1명이다', () {
    expect(
      OfficialMemberCount.of(
        clubId: clubId,
        creatorUserId: creator,
        roster: [
          _m('m_creator_$clubId', '박흥열'),
          _m('m_${clubId}_$creator', '박흥열'),
        ],
      ),
      1,
    );
  });

  test('그 모임 회원이 아닌 찌꺼기는 회원수에 안 넣는다', () {
    expect(
      OfficialMemberCount.of(
        clubId: clubId,
        creatorUserId: creator,
        roster: [
          _m('m_creator_$clubId', '박흥열'),
          _m('m_${clubId}_kakao_5049673364', '장창현'),
        ],
      ),
      1,
    );
  });

  test('게스트는 모임찾기 회원수가 아니다', () {
    expect(
      OfficialMemberCount.of(
        clubId: clubId,
        creatorUserId: creator,
        roster: [
          _m('m_creator_$clubId', '박흥열'),
          _m('m_${clubId}_guest1', '손님', type: '게스트'),
        ],
      ),
      1,
    );
  });
}
