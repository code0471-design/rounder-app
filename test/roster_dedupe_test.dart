import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/domain/services/roster_dedupe.dart';
import 'package:golf_rounder/models/club_model.dart';

Member _m({
  required String id,
  required String name,
  required String role,
  String? phone,
}) =>
    Member(
      id: id,
      name: name,
      gender: '남',
      memberType: '정회원',
      role: role,
      phone: phone,
      status: '활성',
    );

void main() {
  test('생성자 행과 같은 사람 로스터 행을 한 줄로 합친다', () {
    final result = RosterDedupe.collapseMembers(
      members: [
        _m(id: 'm_creator_c1', name: '안경헌', role: '총무'),
        _m(id: 'm_c1_uidA', name: '안경헌', role: '정회원'),
        _m(id: 'm_c1_other', name: '홍길동', role: '정회원'),
      ],
      clubId: 'c1',
      creatorAuthIds: {'uidA'},
    );
    expect(result.droppedIds, {'m_c1_uidA'});
    expect(result.members.map((m) => m.id).toSet(), {
      'm_creator_c1',
      'm_c1_other',
    });
    expect(result.members.where((m) => m.name == '안경헌').length, 1);
  });

  test('같은 이름 정회원 중복도 생성자 행만 남긴다', () {
    final result = RosterDedupe.collapseMembers(
      members: [
        _m(id: 'm_creator_c1', name: '안경헌', role: '총무'),
        _m(id: 'm_c1_otheruid', name: '안경헌', role: '정회원'),
      ],
      clubId: 'c1',
    );
    expect(result.droppedIds, {'m_c1_otheruid'});
    expect(result.members.single.id, 'm_creator_c1');
    expect(result.members.single.role, '총무');
  });

  test('다른 이름 회원은 그대로 둔다', () {
    final result = RosterDedupe.collapseMembers(
      members: [
        _m(id: 'm_creator_c1', name: '안경헌', role: '총무'),
        _m(id: 'm_c1_uidB', name: '김철수', role: '정회원'),
      ],
      clubId: 'c1',
    );
    expect(result.droppedIds, isEmpty);
    expect(result.members.length, 2);
  });

  test('이정원 m1 행은 안경헌과 다른 회원이면 합치지 않는다', () {
    final result = RosterDedupe.collapseMembers(
      members: [
        _m(id: 'm_creator_c1', name: '안경헌', role: '총무'),
        _m(id: 'm_c1_m1', name: 'Jeongwon Lee', role: '정회원'),
      ],
      clubId: 'c1',
      creatorAuthIds: {'kakao_ahn'},
    );
    expect(result.droppedIds, isEmpty);
    expect(result.members.length, 2);
    expect(result.members.map((m) => m.name).toSet(), {
      '안경헌',
      'Jeongwon Lee',
    });
  });

  test('같은 번호면 Jeongwon Leeee와 이정원을 한 줄로 합친다', () {
    const phone = '01092874073';
    final result = RosterDedupe.collapseSamePhone(
      members: [
        _m(
            id: 'm_c1_kakao_1',
            name: 'Jeongwon Leeee',
            role: '정회원',
            phone: phone),
        _m(id: 'm_c1_m1', name: '이정원', role: '정회원', phone: phone),
        _m(id: 'm_creator_c1', name: '안경헌', role: '회장', phone: '01011112222'),
      ],
      clubId: 'c1',
    );
    expect(result.droppedIds.length, 1);
    expect(result.members.where((m) => Member.isClubRosterId('c1', m.id)).length, 2);
    expect(result.members.any((m) => m.name == '이정원'), isTrue);
    expect(result.members.any((m) => m.name == 'Jeongwon Leeee'), isFalse);
  });

  test('번호가 다른 회원은 합치지 않는다', () {
    final result = RosterDedupe.collapseSamePhone(
      members: [
        _m(id: 'm_c1_a', name: '이정원', role: '정회원', phone: '01011112222'),
        _m(id: 'm_c1_b', name: '안경헌', role: '정회원', phone: '01033334444'),
      ],
      clubId: 'c1',
    );
    expect(result.droppedIds, isEmpty);
    expect(result.members.length, 2);
  });
}
