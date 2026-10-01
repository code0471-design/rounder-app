import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/providers/auth_provider.dart';

void main() {
  test('구글 영문 leftover는 이미 바꾼 한글 이름을 덮지 않는다', () {
    expect(
      AuthProvider.pickLoginDisplayName(
        social: 'Jeongwon Lee',
        remote: '이정원',
      ),
      '이정원',
    );
    expect(
      AuthProvider.pickLoginDisplayName(
        social: 'JeongwonLee',
        remote: 'Jeongwon Lee',
      ),
      'Jeongwon Lee',
    );
    expect(
      AuthProvider.pickLoginDisplayName(social: 'Jeongwonleeee'),
      'Jeongwonleeee',
    );
    expect(
      AuthProvider.isLeftoverEnglishDisplayName('Jeongwon Lee'),
      isTrue,
    );
    expect(AuthProvider.isLeftoverEnglishDisplayName('이정원'), isFalse);
  });
}
