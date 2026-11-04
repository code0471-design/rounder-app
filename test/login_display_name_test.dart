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

  test('번호 없는 카카오 계정은 가입 회원으로 올리지 않는다', () {
    expect(AuthProvider.shouldPublishSignedUpAccount(null), isFalse);
    expect(AuthProvider.shouldPublishSignedUpAccount(''), isFalse);
    expect(AuthProvider.shouldPublishSignedUpAccount('회원'), isFalse);
    expect(AuthProvider.shouldPublishSignedUpAccount('010-1234-5678'), isTrue);
  });

  test('이미 있는 가입일은 로그인할 때 다시 찍지 않는다', () {
    expect(AuthProvider.shouldStampAccountCreatedAt(null), isTrue);
    expect(
      AuthProvider.shouldStampAccountCreatedAt('2026-09-01T00:00:00.000Z'),
      isFalse,
    );
  });
}
