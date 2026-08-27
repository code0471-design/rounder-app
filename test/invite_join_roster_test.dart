import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/models/club_model.dart';

void main() {
  test('초대 가입 회원 ID는 모임 명단 필터에 맞게 만든다', () {
    expect(Member.rosterId('c_abc', 'kakao_9'), 'm_c_abc_kakao_9');
  });
}
