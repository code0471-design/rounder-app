import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/screens/admin/admin_models.dart';
import 'package:golf_rounder/services/member_roster_csv.dart';

void main() {
  test('회원 명단 CSV에 이름과 연락처가 들어간다', () {
    final csv = clubMemberRosterCsv([
      Member(
        id: '1',
        name: '김골프',
        gender: '남',
        phone: '010-1234-5678',
        memberType: '정회원',
        role: '총무',
        handicap: 12,
        joinDate: DateTime(2026, 3, 1),
      ),
    ]);

    expect(csv.startsWith('\uFEFF'), isTrue);
    expect(csv, contains('이름'));
    expect(csv, contains('김골프'));
    expect(csv, contains('010-1234-5678'));
    expect(csv, contains('총무'));
  });

  test('본사 회원 명단 CSV에 닉네임과 상태가 들어간다', () {
    final csv = adminMemberRosterCsv(const [
      AdminMember(
        id: 'u1',
        name: '김골프',
        phone: '010-1234-5678',
        nickname: '라운더',
        gender: '남',
        joinDate: '2026-03-01',
        status: 'normal',
        clubCount: 2,
        email: 'a@b.com',
      ),
    ]);
    expect(csv, contains('닉네임'));
    expect(csv, contains('라운더'));
    expect(csv, contains('정상'));
  });

  test('쉼표가 있는 값은 따옴표로 감싼다', () {
    expect(csvEscape('서울, 동작구'), '"서울, 동작구"');
  });

  test('파일 이름에서 금지 문자를 제거한다', () {
    expect(safeFileStem('라운더/서울:모임'), '라운더_서울_모임');
  });
}
