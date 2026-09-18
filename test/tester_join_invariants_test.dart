import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/models/club_model.dart';

String _read(String relative) => File(relative).readAsStringSync();

void main() {
  group('카카오 시작하기가 스피너에 묶이지 않는다', () {
    test('카카오톡 로그인은 시간 제한 후 계정 로그인으로 넘어간다', () {
      final src = _read('lib/services/social_auth_service.dart');
      expect(src.contains('loginWithKakaoTalk()'), isTrue);
      expect(src.contains('Duration(seconds: 20)'), isTrue);
      expect(src.contains('TimeoutException'), isTrue);
      expect(src.contains('loginWithKakaoAccount()'), isTrue);
    });

    test('로그인 화면은 모임 동기화를 기다리지 않고 넘어간다', () {
      final login = _read('lib/screens/auth/login_screen.dart');
      expect(login.contains('await _syncClubProvider()'), isFalse);
      expect(login.contains('unawaited(_syncClubProvider())'), isTrue);
      expect(login.contains("pushReplacementNamed("), isTrue);
    });

    test('소셜 로그인 Firestore 사용자 조회도 시간 제한이 있다', () {
      final auth = _read('lib/providers/auth_provider.dart');
      expect(auth.contains('Duration(seconds: 8)'), isTrue);
    });
  });

  group('초대 가입은 빈 모임을 만들지 않는다', () {
    test('서버에 모임이 없으면 로컬 껍데기를 만들지 않는다', () {
      final join = _read('lib/providers/club_provider.dart');
      final start = join.indexOf('Future<bool> joinViaInvite(');
      expect(start, greaterThan(0));
      final fn = join.substring(start, start + 8000);
      expect(fn.contains('club ??= Club('), isFalse);
      expect(fn.contains('joinViaInvite remote skip'), isFalse);
      expect(fn.contains('joinViaInvite remote fail'), isTrue);
      expect(fn.contains('seedIfMissing: false'), isTrue);
      expect(fn.contains('_persistAuthUserId ?? currentUserId'), isTrue);
      expect(fn.contains('_hydrateRosterFromServer(clubId)'), isTrue);
      expect(fn.contains('addMemberViaInvite('), isTrue);
    });

    test('없는 모임 문서에 member_count 만 올려 빈 모임을 만들지 않는다', () {
      final ds = _read(
        'lib/data/datasources/firestore/firestore_club_datasource.dart',
      );
      expect(ds.contains("if (!clubSnap.exists)"), isTrue);
      expect(ds.contains('초대 대상 모임이 없습니다'), isTrue);
    });

    test('초대 가입자가 빈 운영 번들로 기존 모임을 최초 업로드하지 않는다', () {
      final ops = _read('lib/services/club_ops_sync.dart');
      expect(ops.contains('bool seedIfMissing = true'), isTrue);
      expect(ops.contains('if (seedIfMissing)'), isTrue);
      expect(ops.contains('skip empty ops create'), isTrue);
    });
  });

  group('내부 테스터 실계정이 데모 명단과 섞이지 않는다', () {
    test('실계정 별칭에 m1/user_me 를 넣지 않는다', () {
      final src = _read('lib/providers/club_provider.dart');
      final start = src.indexOf('Set<String> _authAliases');
      expect(start, greaterThan(0));
      final fn = src.substring(start, start + 900);
      expect(fn.contains("currentUserId == 'm1'"), isFalse);
      expect(fn.contains('_isDemoSession'), isTrue);
    });

    test('빈 creatorId 를 아무 실계정 생성자로 보지 않는다', () {
      final src = _read('lib/providers/club_provider.dart');
      expect(src.contains('bool _iAmClubCreator'), isTrue);
      // m1/빈 creatorId 는 임원+생성자 행이 있을 때만 나다.
      expect(src.contains("cid == 'm1'"), isTrue);
      expect(src.contains('ClubMemberRole.isOfficer(club.myRole)'), isTrue);
      expect(src.contains('_purgeDemoIdentityClubs'), isTrue);
      expect(src.contains('_hydrateRosterFromServer'), isTrue);
    });

    test('명단 id 는 카카오 id 를 m_creator / m_{club}_ 로 바꾼다', () {
      expect(
        Member.canonicalRosterId(
          clubId: 'c_arena',
          rawId: 'kakao_1',
          creatorUserId: 'kakao_1',
        ),
        'm_creator_c_arena',
      );
      expect(
        Member.canonicalRosterId(
          clubId: 'c_arena',
          rawId: 'kakao_2',
          creatorUserId: 'kakao_1',
        ),
        'm_c_arena_kakao_2',
      );
      expect(
        Member.canonicalRosterId(
          clubId: 'c_aladdin',
          rawId: 'kakao_host',
          creatorUserId: 'kakao_host',
        ),
        'm_creator_c_aladdin',
      );
      expect(
        Member.canonicalRosterId(
          clubId: 'c_aladdin',
          rawId: 'kakao_guest',
          creatorUserId: 'kakao_host',
        ),
        'm_c_aladdin_kakao_guest',
      );
      expect(
        Member.canonicalRosterId(
          clubId: 'c_arena',
          rawId: 'm_c_other_kakao_2',
          creatorUserId: 'kakao_1',
        ),
        'm_c_other_kakao_2',
        reason: '다른 모임 명단 id 를 이 모임 행으로 바꾸면 안 된다',
      );
    });
  });

  group('정회원 화면에 생성자가 빠져 본인만 남지 않는다', () {
    test('회원 조회는 join_date 없는 문서를 빠뜨리지 않는다', () {
      final src = _read(
        'lib/data/datasources/firestore/firestore_member_datasource.dart',
      );
      expect(src.contains("orderBy('join_date'"), isFalse);
    });

    test('회원 문서에 명단 id 를 저장한다', () {
      final src = _read('lib/data/mappers/member_mapper.dart');
      expect(src.contains("'id': member.id"), isTrue);
      expect(src.contains('Member.isStoredRosterId'), isTrue);
    });

    test('랭킹 합산에 로그인 id 를 넣으면 다른 모임 +5 가 샌다', () {
      final src = _read('lib/providers/club_provider.dart');
      final start = src.indexOf('Set<String> _membershipPointKeysFor');
      expect(start, greaterThan(0));
      final fn = src.substring(start, src.indexOf('Set<String> _memberAliasIds'));
      expect(
        fn.contains('keys.add(_persistAuthUserId!)'),
        isTrue,
        reason: '내가 만든 모임만 옛 로그인 id 이력을 본다',
      );
      expect(fn.contains('_iAmClubCreator(selectedClub)'), isTrue);
      final selfBlock = fn.substring(
        fn.indexOf('if (_isSelfTarget(memberId))'),
        fn.indexOf('} else if (memberId == creatorId)'),
      );
      final beforeCreator = selfBlock.substring(
        0,
        selfBlock.indexOf('if (_iAmClubCreator(selectedClub))'),
      );
      expect(
        beforeCreator.contains('keys.add(_persistAuthUserId!)'),
        isFalse,
        reason: '정회원 모임 랭킹에 로그인 id 점수를 합치면 안 된다',
      );
    });

    test('서버 명단을 받으면 화면에 바로 반영한다', () {
      final src = _read('lib/providers/club_provider.dart');
      final start = src.indexOf('Future<void> _mergeRemoteRoster(');
      expect(start, greaterThan(0));
      final fn = src.substring(
        start,
        src.indexOf('void _purgeDemoSeedNotifications()'),
      );
      expect(fn.contains('notifyListeners()'), isTrue);
      expect(fn.contains('_persistImmediately()'), isTrue);
      expect(fn.contains('ClubMemberRole.president'), isTrue);
      expect(src.contains('_watchSelectedClubMembers()'), isTrue);
    });

    test('회원 문서 하나 깨져도 나머지 명단은 살린다', () {
      final src = _read(
        'lib/data/datasources/firestore/firestore_member_datasource.dart',
      );
      expect(src.contains('for (final doc in snap.docs)'), isTrue);
      expect(src.contains('MemberMapper.fromFirestore(doc)'), isTrue);
    });
  });

  group('신규 모임 재무는 다른 모임 회계를 붙이지 않는다', () {
    test('고아 회비·거래는 데모 모임에만 현재 모임을 붙인다', () {
      final src = _read('lib/providers/club_provider.dart');
      final dues = src.substring(src.indexOf('void _stampOrphanDuesClubIds()'));
      final duesFn = dues.substring(0, dues.indexOf('void _stampOrphanTransactionClubIds()'));
      expect(duesFn.contains('if (!_selectedHasLegacyMock) return;'), isTrue);

      final tx = src.substring(src.indexOf('void _stampOrphanTransactionClubIds()'));
      final txFn = tx.substring(0, 400);
      expect(txFn.contains('if (!_selectedHasLegacyMock) return;'), isTrue);
    });

    test('일정은 선택 모임 clubId만 보여주고 첫 안내가 있다', () {
      final src = _read('lib/providers/club_provider.dart');
      expect(src.contains('bool get needsFirstScheduleGuide'), isTrue);
      expect(src.contains('canCreateSchedule && schedules.isEmpty'), isTrue);
      final up = src.substring(src.indexOf('List<RoundSchedule> get upcomingSchedules'));
      final upFn = up.substring(0, up.indexOf('가장 가까운 예정 일정'));
      expect(upFn.contains('s.clubId == clubId'), isTrue);

      final finance = _read('lib/screens/finance/finance_screen.dart');
      expect(finance.contains('TreasurerFinanceOnboardingScreen'), isTrue);
      expect(src.contains('needsTreasurerFinanceOnboarding'), isTrue);
    });
  });
}
