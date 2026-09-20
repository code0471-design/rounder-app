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

  group('총무 공석 재무 권한', () {
    test('총무는 항상 재무 권한이 있다', () {
      expect(
        ClubMemberRole.canActAsTreasurer('총무', treasurerVacant: false),
        isTrue,
      );
      expect(
        ClubMemberRole.canActAsTreasurer('회장·총무', treasurerVacant: false),
        isTrue,
      );
    });

    test('총무가 있으면 회장만으로는 재무 권한이 없다', () {
      expect(
        ClubMemberRole.canActAsTreasurer('회장', treasurerVacant: false),
        isFalse,
      );
    });

    test('총무가 없으면 회장·부회장이 재무를 맡는다', () {
      expect(
        ClubMemberRole.canActAsTreasurer('회장', treasurerVacant: true),
        isTrue,
      );
      expect(
        ClubMemberRole.canActAsTreasurer('부회장', treasurerVacant: true),
        isTrue,
      );
      expect(
        ClubMemberRole.canActAsTreasurer('정회원', treasurerVacant: true),
        isFalse,
      );
    });
  });
}
