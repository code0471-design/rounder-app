import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/domain/services/member_photo.dart';
import 'package:golf_rounder/models/club_model.dart';

void main() {
  Member row(String id, String name, {String? photo, String? phone}) {
    return Member(
      id: id,
      name: name,
      gender: '남',
      memberType: '정회원',
      role: '정회원',
      photoUrl: photo,
      phone: phone,
    );
  }

  test('다른 모임에만 있는 사진을 같은 사람에게 보여 준다', () {
    final withPhoto = row(
      'm_c_1_kakao_5049673364',
      '장창현',
      photo: 'data:image/png;base64,aaa',
    );
    final bare = row('m_c_2_kakao_5049673364', '장창현');
    expect(
      MemberPhoto.fill(member: bare, roster: [withPhoto, bare]),
      'data:image/png;base64,aaa',
    );
  });

  test('이름이 같아도 사진이 둘이면 아무 사진이나 붙이지 않는다', () {
    final a = row('m_c_1_kakao_a', '장창현', photo: 'photo-a');
    final b = row('m_c_2_kakao_b', '장창현', photo: 'photo-b');
    final bare = row('m_c_3_kakao_c', '장창현');
    expect(MemberPhoto.fill(member: bare, roster: [a, b, bare]), isNull);
  });

  test('내 계정 사진이 있으면 빈 줄을 채운다', () {
    final me = row('m_c_9_kakao_me', '안경헌');
    expect(
      MemberPhoto.fill(
        member: me,
        roster: [me],
        isSelf: true,
        selfPhoto: 'account-photo',
      ),
      'account-photo',
    );
  });
}
