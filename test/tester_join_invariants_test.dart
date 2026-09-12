import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
      final fn = join.substring(start, start + 5500);
      expect(fn.contains('club ??= Club('), isFalse);
      expect(fn.contains('joinViaInvite remote skip'), isFalse);
      expect(fn.contains('joinViaInvite remote fail'), isTrue);
      expect(fn.contains('seedIfMissing: false'), isTrue);
      expect(fn.contains('_persistAuthUserId ?? currentUserId'), isTrue);
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
