import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/providers/club_provider.dart';

/// 실계정 이름이 데모 시드 이름('홍길동')으로 저장되던 버그 방지.
///
/// 원인: switchUser 가 시드 계정 3개만 알고 나머지를 전부 m1/홍길동으로
/// 떨어뜨렸다. 그 상태로 ensureCreatorMembers 가 생성자 행을 만들어서
/// 명단·조편성·참석자에 '홍길동'이 그대로 박혔다.
void main() {
  final provider =
      File('lib/providers/club_provider.dart').readAsStringSync();

  group('placeholder 이름 판정', () {
    test('시드 이름과 임시 이름은 덮어쓸 수 있다', () {
      for (final name in ['홍길동', '이민준', '박민준']) {
        expect(ClubProvider.isPlaceholderMemberName(name), isTrue,
            reason: '$name 은 데모 시드 이름이다');
      }
      for (final name in ['', '  ', '회원', '카카오 회원', 'Google 회원', 'Apple 회원']) {
        expect(ClubProvider.isPlaceholderMemberName(name), isTrue);
      }
    });

    test('사람이 입력한 이름은 건드리지 않는다', () {
      for (final name in ['안경헌', '김철수', 'Royce', '홍길순']) {
        expect(ClubProvider.isPlaceholderMemberName(name), isFalse);
      }
    });
  });

  group('switchUser 계정 분기', () {
    test('시드 계정과 실계정 분기가 갈라져 있다', () {
      final block = provider.substring(
        provider.indexOf('Future<void> switchUser('),
        provider.indexOf('Future<void> switchUser(') + 1600,
      );
      // 예전에는 case 'user_me' 와 default 가 붙어 있어서
      // 실계정이 전부 홍길동이 됐다.
      expect(block.contains("case 'user_me':"), isTrue);
      expect(block.contains("case 'default':"), isTrue);
      expect(block.contains('_realDisplayName(displayName)'), isTrue);

      final userMe = block.indexOf("case 'user_me':");
      final fallthrough = block.indexOf('default:');
      expect(fallthrough, greaterThan(userMe));
      // default 분기가 홍길동을 쓰면 안 된다.
      final defaultBlock = block.substring(fallthrough);
      expect(defaultBlock.contains("_currentUserName = '홍길동'"), isFalse);
    });

    test('displayName 을 받는 시그니처다', () {
      expect(
        provider.contains(
            'Future<void> switchUser(String authUserId, {String? displayName})'),
        isTrue,
      );
    });

    test('로그인 진입점이 실제 이름을 넘긴다', () {
      for (final path in [
        'lib/screens/splash/splash_screen.dart',
        'lib/screens/auth/login_screen.dart',
        'lib/screens/auth/verify_screen.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src.contains('switchUser('), isTrue, reason: path);
        expect(
          src.contains('displayName:'),
          isTrue,
          reason: '$path 가 이름을 안 넘기면 명단이 다시 홍길동이 된다',
        );
      }
    });
  });

  group('기존 데이터 복구', () {
    test('switchUser 가 명단 복구를 생성자 행 보정보다 먼저 돌린다', () {
      final block = provider.substring(
        provider.indexOf('Future<void> switchUser('),
        provider.indexOf('void selectClub('),
      );
      final repair = block.indexOf('repairMyDisplayName(_currentUserName)');
      final ensure = block.indexOf('ensureCreatorMembers();');
      expect(repair, greaterThan(0));
      expect(ensure, greaterThan(repair),
          reason: '복구가 뒤에 오면 그 회차에는 홍길동이 그대로 보인다');
    });

    test('복구는 내 행만, 데모 모임은 빼고 고친다', () {
      final fn = provider.substring(
        provider.indexOf('bool repairMyDisplayName('),
        provider.indexOf('bool ensureMyRosterRow('),
      );
      expect(fn.contains('_legacyMockClubIds.contains(club.id)'), isTrue,
          reason: '데모 c1~c5 는 공유 시드 명단이라 손대면 안 된다');
      expect(fn.contains('_isMyRosterRowFor(club, m.id)'), isTrue);
      expect(fn.contains('isPlaceholderMemberName(m.name)'), isTrue,
          reason: '사람이 고친 이름을 덮어쓰면 안 된다');
      expect(fn.contains('_persistImmediately()'), isTrue,
          reason: '고쳐 놓고 저장을 안 하면 다음 실행에 또 홍길동이다');
    });

    test('내 행 판정은 membersForClub 과 같은 ID 규칙만 본다', () {
      final fn = provider.substring(
        provider.indexOf('bool _isMyRosterRowFor('),
        provider.indexOf('bool _isMyRosterRowFor(') + 900,
      );
      expect(fn.contains("'m_creator_\${club.id}'"), isTrue);
      expect(fn.contains("'m_\${club.id}_'"), isTrue);
      // 실계정도 currentUserId 가 m1 이라, 맨 'm1' 행까지 잡으면
      // 데모 시드 회원 이름을 바꿔 버린다.
      expect(fn.contains('_userIdsMatch(memberId, currentUserId)'), isFalse);
    });

    test('전화 인증 후 이름 반영도 같은 판정을 쓴다', () {
      final fn = provider.substring(
        provider.indexOf('void syncAuthUserProfile('),
        provider.indexOf('void syncAuthUserPhone('),
      );
      expect(fn.contains('isPlaceholderMemberName(m.name)'), isTrue);
      // 하드코딩 목록이 두 벌로 갈라지면 한쪽만 고치게 된다.
      expect(fn.contains("m.name.trim() == '카카오 회원'"), isFalse);
    });
  });
}
