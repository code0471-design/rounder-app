import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/domain/services/official_member_count.dart';
import 'package:golf_rounder/models/club_model.dart';

Member _m(
  String id,
  String name, {
  String type = '정회원',
  String role = '정회원',
  String status = '활성',
}) =>
    Member(
      id: id,
      name: name,
      gender: '남',
      memberType: type,
      role: role,
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

  test('아레나 찌꺼기만 빼고 다른 모임 총무는 회원수에 넣는다', () {
    const arena = 'c_1786973797931';
    expect(
      OfficialMemberCount.of(
        clubId: arena,
        creatorUserId: 'kakao_5049673364',
        roster: [
          _m('m_creator_$arena', '장창현'),
          _m('m_${arena}_kakao_other', '다른회원'),
        ],
      ),
      1,
    );
    expect(
      OfficialMemberCount.of(
        clubId: clubId,
        creatorUserId: creator,
        roster: [
          _m('m_creator_$clubId', '박흥열'),
          _m('m_${clubId}_kakao_5049673364', '장창현'),
        ],
      ),
      2,
    );
  });

  test('같은 사람 줄이 붙어도 참석 인원은 그대로다', () {
    final base = [
      _m('m_creator_$clubId', '장창현', role: '총무'),
      _m('m_${clubId}_a', '김철수'),
      _m('m_${clubId}_b', '이영희', type: '게스트'),
    ];
    final withDuplicate = [
      ...base,
      _m('m_${clubId}_kakao_x', '장창현'),
    ];

    List<Member> roster(List<Member> rows) =>
        OfficialMemberCount.attendanceRoster(
          clubId: clubId,
          creatorUserId: creator,
          roster: rows,
        );

    final baseRoster = roster(base);
    final dupRoster = roster(withDuplicate);
    expect(
      baseRoster.where((m) => m.memberType == '정회원').length,
      dupRoster.where((m) => m.memberType == '정회원').length,
    );
    expect(baseRoster.length, dupRoster.length);
    expect(baseRoster.where((m) => m.memberType == '정회원').length, 2);
    expect(baseRoster.length, 3);
    expect(dupRoster.any((m) => m.name == '김철수'), isTrue);
    expect(dupRoster.any((m) => m.name == '이영희'), isTrue);
  });

  test('방장 자리에 내 이름이 있어도 이름이 다른 회원은 화면에 남는다', () {
    const host = 'kakao_host';
    final roster = OfficialMemberCount.attendanceRoster(
      clubId: clubId,
      creatorUserId: host,
      roster: [
        _m('m_creator_$clubId', '안경헌', role: '정회원'),
        _m('m_${clubId}_$host', '장창현', role: '총무'),
      ],
    );
    expect(roster.map((m) => m.name).toSet(), {'안경헌', '장창현'});
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
