import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/models/member_role.dart';

void main() {
  group('직책 겸직', () {
    test('회장·부회장·총무를 한 사람이 모두 겸할 수 있다', () {
      expect(
        ClubMemberRole.encodeRoles([
          ClubMemberRole.president,
          ClubMemberRole.vicePresident,
          ClubMemberRole.treasurer,
        ]),
        '회장·부회장·총무',
      );
    });

    test('정회원은 임원과 같이 저장되지 않는다', () {
      expect(
        ClubMemberRole.encodeRoles([
          ClubMemberRole.president,
          ClubMemberRole.treasurer,
          ClubMemberRole.regular,
        ]),
        '회장·총무',
      );
    });

    test('임원만 빼면 정회원으로 돌아간다', () {
      expect(
        ClubMemberRole.encodeRoles([ClubMemberRole.regular]),
        ClubMemberRole.regular,
      );
    });
  });
}
