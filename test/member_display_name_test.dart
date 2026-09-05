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

    test('이름·생년월일·핸디를 받는 시그니처다', () {
      final sig = provider.substring(
        provider.indexOf('Future<void> switchUser('),
        provider.indexOf('Future<void> switchUser(') + 200,
      );
      expect(sig.contains('String? displayName'), isTrue);
      expect(sig.contains('DateTime? birthDate'), isTrue);
      expect(sig.contains('double? handicap'), isTrue);
    });

    test('로그인 진입점이 이름·핸디를 넘긴다', () {
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
        expect(
          src.contains('handicap: auth.currentUser!.handicap'),
          isTrue,
          reason: '$path 가 핸디를 안 넘기면 자동 조편성이 초보(99)로 잡는다',
        );
      }
    });
  });

  group('핸디캡이 자동 조편성까지 간다', () {
    test('로그인마다 계정 핸디를 명단에 흘려 넣는다', () {
      final block = provider.substring(
        provider.indexOf('Future<void> switchUser('),
        provider.indexOf('void selectClub('),
      );
      final ensure = block.indexOf('ensureCreatorMembers();');
      final sync = block.indexOf('syncAuthGolfProfile(birthDate: birthDate');
      expect(sync, greaterThan(0),
          reason: '가입 때 입력한 핸디가 나중에 만든 모임 명단에 안 붙는다');
      expect(sync, greaterThan(ensure),
          reason: '생성자 행을 만든 뒤에 반영해야 그 행에도 핸디가 들어간다');
    });

    test('배정용 Member 는 명단 회원을 그대로 쓴다', () {
      // memberById 가 핸디를 들고 있는 Member 를 준다.
      final fn = provider.substring(
        provider.indexOf('Member _memberForAssignment('),
        provider.indexOf('Member _memberForAssignment(') + 500,
      );
      expect(fn.contains('memberById(response.memberId)'), isTrue);
      expect(fn.contains('if (existing != null) return existing;'), isTrue);
    });

    test('핸디 균등 옵션이 Member.handicap 을 쓴다', () {
      final svc =
          File('lib/domain/services/group_assignment_service.dart')
              .readAsStringSync();
      expect(svc.contains('AutoAssignOption.balanceHandicap'), isTrue);
      // 핸디 내림차순 정렬 + 스네이크 드래프트
      expect(svc.contains('(b.handicap ?? 99).compareTo(a.handicap ?? 99)'),
          isTrue);
      expect(svc.contains('double _handicapBalanceScore('), isTrue);
      final score = svc.substring(
        svc.indexOf('double _handicapBalanceScore('),
        svc.indexOf('double _handicapBalanceScore(') + 500,
      );
      expect(score.contains('m.handicap ?? 99'), isTrue);
      expect(score.contains("s.handicap"), isTrue,
          reason: '이미 배정된 조의 평균 핸디와 비교해야 균등해진다');
    });
  });

  group('원격 동기화가 이름 복구를 되돌리지 않는다', () {
    test('_importBundle 이 명단을 덮은 직후 이름을 다시 고친다', () {
      // switchUser 에서 한 번 고쳐도 pull/watch 가 _members 를 통째로
      // 교체하므로 '홍길동'이 되살아났다.
      final import = provider.substring(
        provider.indexOf('void _importBundle(ClubDataBundle b) {'),
        provider.indexOf("_activities\r\n      ..clear()") > 0
            ? provider.indexOf("_activities\r\n      ..clear()")
            : provider.indexOf('_activities\n      ..clear()'),
      );
      expect(import.contains('_repairMyRosterNames(_currentUserName)'), isTrue,
          reason: 'members 를 addAll 한 뒤 복구를 걸어야 한다');
      expect(import.contains('..addAll(b.members)'), isTrue);
      expect(
        import.indexOf('_repairMyRosterNames'),
        greaterThan(import.indexOf('..addAll(b.members)')),
        reason: '덮기 전에 고치면 의미가 없다',
      );
    });

    test('공개 API 는 통지·저장까지, 내부 헬퍼는 순수하게 둔다', () {
      // _importBundle 안에서는 통지·저장을 하면 안 된다 (suppressPersist 구간).
      expect(provider.contains('bool _repairMyRosterNames(String realName) {'),
          isTrue);
      final pure = provider.substring(
        provider.indexOf('bool _repairMyRosterNames(String realName) {'),
        provider.indexOf('bool _isMyRosterRowFor('),
      );
      expect(pure.contains('notifyListeners()'), isFalse);
      expect(pure.contains('_persistImmediately()'), isFalse);

      final publicApi = provider.substring(
        provider.indexOf('bool repairMyDisplayName(String realName) {'),
        provider.indexOf('bool _repairMyRosterNames(String realName) {'),
      );
      expect(publicApi.contains('_repairMyRosterNames(realName)'), isTrue);
      expect(publicApi.contains('notifyListeners()'), isTrue);
      expect(publicApi.contains('_persistImmediately()'), isTrue);
    });
  });

  group('삭제한 회원이 동기화로 되살아나지 않는다', () {
    final sync = File('lib/services/club_ops_sync.dart').readAsStringSync();

    test('회원 tombstone API 가 있다', () {
      expect(sync.contains('static void markMemberRemoved(String memberId)'),
          isTrue);
      expect(sync.contains('static bool isMemberRemoved(String memberId)'),
          isTrue);
      expect(
          sync.contains('static void seedRemovedMembers(Iterable<String>'),
          isTrue);
    });

    test('members merge 양쪽이 tombstone 을 본다', () {
      // push(로컬 우선) / pull·watch(원격 우선) 둘 다 걸어야 한다.
      // 한쪽만 막으면 다른 쪽에서 되살아난다.
      expect(sync.contains('static List<dynamic> _mergeMembersById({'), isTrue);
      final pushSite = sync.substring(
        sync.indexOf("final remoteMembers = remote['members'] as List?"),
        sync.indexOf("final remoteMembers = remote['members'] as List?") + 400,
      );
      expect(pushSite.contains('_mergeMembersById('), isTrue);
      expect(pushSite.contains('remoteWins: false'), isTrue);

      final pullSite = sync.substring(
        sync.indexOf("// members: 합집합"),
        sync.indexOf("// members: 합집합") + 500,
      );
      expect(pullSite.contains('_mergeMembersById('), isTrue);
      expect(pullSite.contains('remoteWins: true'), isTrue);
    });

    test('강퇴·탈퇴 둘 다 표식을 남기고 저장한다', () {
      // 짝 필드 규칙: 한쪽만 막으면 다른 경로로 되살아난다.
      final kick = provider.substring(
        provider.indexOf('void kickMember(String memberId'),
        provider.indexOf('void kickMember(String memberId') + 500,
      );
      expect(kick.contains('ClubOpsSync.markMemberRemoved(memberId)'), isTrue);

      final deactivate = provider.substring(
        provider.indexOf('void deactivateMember(String memberId'),
        provider.indexOf('void deactivateMember(String memberId') + 600,
      );
      expect(deactivate.contains('ClubOpsSync.markMemberRemoved(memberId)'),
          isTrue);
      expect(
        deactivate.contains('_persistImmediately()'),
        isTrue,
        reason: '예전엔 통지만 하고 저장을 안 해서 앱을 다시 켜면 탈퇴가 사라졌다',
      );
    });

    test('앱 재시작 후에도 로컬 비활성 회원을 표식으로 되살린다', () {
      // 표식은 메모리에만 있다. _importBundle 에서 다시 심어야 한다.
      expect(
        provider.contains('ClubOpsSync.seedRemovedMembers('),
        isTrue,
      );
      expect(provider.contains("m.status != '활성'"), isTrue);
    });
  });

  group('기존 가입자도 골프 프로필을 한 번 받는다', () {
    final auth = File('lib/providers/auth_provider.dart').readAsStringSync();

    test('물어봤는지 계정별로 기억한다', () {
      expect(auth.contains('Future<bool> shouldAskGolfProfile()'), isTrue);
      expect(auth.contains('Future<void> markGolfProfileAsked()'), isTrue);
      // 계정별 키 — 다른 계정으로 바꾸면 다시 물어봐야 한다.
      expect(auth.contains("'\$_kGolfProfileAsked\${user.id}'"), isTrue);
      final should = auth.substring(
        auth.indexOf('Future<bool> shouldAskGolfProfile()'),
        auth.indexOf('Future<void> markGolfProfileAsked()'),
      );
      expect(should.contains('!user.needsGolfProfile'), isTrue,
          reason: '이미 입력한 사람에게 또 물어보면 안 된다');
    });

    test('자동로그인·소셜로그인 둘 다 골프 프로필로 보낸다', () {
      for (final path in [
        'lib/screens/splash/splash_screen.dart',
        'lib/screens/auth/login_screen.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src.contains('shouldAskGolfProfile()'), isTrue, reason: path);
        expect(src.contains("'/golf-profile'"), isTrue, reason: path);
      }
    });

    test("'나중에'도 물어본 걸로 기록한다", () {
      final screen =
          File('lib/screens/auth/golf_profile_screen.dart').readAsStringSync();
      final skip = screen.substring(
        screen.indexOf('Future<void> _skip()'),
        screen.indexOf('Future<void> _skip()') + 400,
      );
      expect(skip.contains('markGolfProfileAsked()'), isTrue,
          reason: '기록을 안 하면 앱 켤 때마다 이 화면이 뜬다');
      expect(screen.contains('await auth.markGolfProfileAsked();'), isTrue,
          reason: '저장했을 때도 기록해야 한다');
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
