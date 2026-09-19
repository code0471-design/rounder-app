import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/services/member_phone_index.dart';

/// 방장이 손으로 추가한 회원이 나중에 같은 번호로 가입하면 모임이 붙어야 한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('번호는 숫자만 남기고 10자리 미만은 색인하지 않는다', () {
    expect(MemberPhoneIndex.digitsOf('010-1234-5678'), '01012345678');
    expect(MemberPhoneIndex.digitsOf(' 010 1234 5678 '), '01012345678');
    expect(MemberPhoneIndex.digitsOf('01012345678'), '01012345678');
    expect(MemberPhoneIndex.digitsOf('1234'), '',
        reason: '짧은 번호로 남의 모임에 붙으면 안 된다');
    expect(MemberPhoneIndex.digitsOf(''), '');
    expect(MemberPhoneIndex.digitsOf(null), '');
  });

  test('Firestore 없이(오프라인 목) 돌면 아무 일도 안 한다', () async {
    AppDependencies.instance.init(offlineMock: true);
    final claimed = await MemberPhoneIndex.claimForUser(
      userId: 'kakao_tester',
      phone: '010-1234-5678',
    );
    expect(claimed, isEmpty);
  });

  test('로그인 순서: 번호로 잇고 → 소속 읽고 → 남의 모임 정리', () {
    final src = File('lib/providers/club_provider.dart').readAsStringSync();
    final claim = src.indexOf('await _claimClubsByPhone(authUserId);');
    final ingest = src.indexOf('if (await _ingestServerMemberships(authUserId)) recovered = true;');
    final prune = src.indexOf('if (await _pruneForeignClubs(authUserId)) recovered = true;');
    expect(claim, greaterThan(0));
    expect(ingest, greaterThan(claim),
        reason: '소속을 만든 뒤에 읽어야 방금 붙은 모임이 보인다');
    expect(prune, greaterThan(ingest),
        reason: '정리가 먼저 돌면 방금 번호로 붙은 모임이 지워진다');
  });

  test('명단이 바뀌면 번호 색인도 같이 올라간다', () {
    final src = File('lib/services/club_ops_sync.dart').readAsStringSync();
    expect(src.contains('MemberPhoneIndex.syncClub('), isTrue,
        reason: '색인을 안 올리면 나중에 가입한 회원이 모임을 못 찾는다');
  });

  test('계정 ID 로 붙은 내 행이 있으면 번호 추정은 하지 않는다', () {
    final src = File('lib/providers/club_provider.dart').readAsStringSync();
    final start = src.indexOf('bool _isMyRosterRowFor(Club club, String memberId) {');
    expect(start, greaterThan(0));
    final body = src.substring(start, start + 400);
    expect(body.contains('_rosterHasIdLinkedRowOfMine(club)'), isTrue,
        reason: '둘 다 내 행이 되면 명단에 내가 두 줄로 보인다');
  });
}
