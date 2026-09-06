import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/domain/services/roster_dedupe.dart';
import 'package:golf_rounder/models/club_model.dart';

Member _m({
  required String id,
  required String name,
  required String role,
}) =>
    Member(
      id: id,
      name: name,
      gender: '남',
      memberType: '정회원',
      role: role,
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
        _m(id: 'm_c1_uidB', name: '홍길동', role: '정회원'),
      ],
      clubId: 'c1',
    );
    expect(result.droppedIds, isEmpty);
    expect(result.members.length, 2);
  });
}
