import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/domain/services/app_data_bootstrap_service.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 테스터 폰에서 남의 모임이 전부 '내 모임'으로 보이던 버그.
/// 내 모임은 서버 멤버십·생성자·내 명단 행으로만 정해진다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClubProvider clubs;
  late String myClubId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppDependencies.instance.init(offlineMock: true);
    clubs = ClubProvider();
    await clubs.switchUser(
      'kakao_tester',
      displayName: '장창현',
      phone: '010-1111-2222',
    );
    final ok = await clubs.createClub(
      name: '알라딘 정기월례회',
      region: '서울',
      industry: '골프',
      teamCount: 4,
      myRole: '회장',
    );
    expect(ok, isTrue);
    myClubId = clubs.selectedClub.id;
  });

  test('남의 모임이 내 모임 목록에 끼어 있으면 새로고침에서 빠진다', () async {
    final store = AppDependencies.instance.mockDataStore!;
    final foreign = Club(
      id: 'c_1786973797931',
      name: '아레나 골프회',
      myRole: '정회원',
      memberCount: 2,
      creatorId: 'kakao_ahn',
      region: '서울',
      industry: '골프',
      teamCount: 4,
      description: '',
      createdAt: DateTime(2026, 9, 1),
    );
    store.upsertClub(foreign, persist: false);

    // 예전 빌드가 탐색 카탈로그를 내 모임으로 저장해 둔 상태를 재현
    clubs.hydrateFromBootstrap(AppBootstrapSnapshot(
      userId: 'kakao_tester',
      myClubs: [foreign],
      discoverableClubs: [foreign],
      membersByClubId: const {},
      financeByClubId: const {},
      loadedAt: DateTime(2026, 9, 19),
    ));
    expect(clubs.myClubs.any((c) => c.id == foreign.id), isTrue);

    await clubs.refreshOwnedClubs();

    expect(clubs.myClubs.any((c) => c.id == foreign.id), isFalse,
        reason: '서버 멤버십도 생성자도 내 명단 행도 없으면 내 모임이 아니다');
    expect(clubs.myClubs.any((c) => c.id == myClubId), isTrue,
        reason: '내가 만든 모임은 그대로 남아야 한다');
    expect(clubs.allClubs.any((c) => c.id == foreign.id), isTrue,
        reason: '탐색 목록에서는 계속 보여야 한다');
  });

  test('초대로 들어온 모임은 명단 행이 있으면 안 지운다', () async {
    final store = AppDependencies.instance.mockDataStore!;
    final invited = Club(
      id: 'c_1788832826557',
      name: '강남 미용모임',
      myRole: '정회원',
      memberCount: 3,
      creatorId: 'kakao_ahn',
      region: '서울',
      industry: '미용',
      teamCount: 4,
      description: '',
      createdAt: DateTime(2026, 8, 1),
    );
    store.upsertClub(invited, persist: false);
    store.addMember(
      clubId: invited.id,
      member: Member(
        id: 'kakao_tester',
        name: '장창현',
        gender: '남',
        memberType: '정회원',
        role: '정회원',
        joinDate: DateTime(2026, 8, 2),
      ),
      persist: false,
    );

    clubs.hydrateFromBootstrap(AppBootstrapSnapshot(
      userId: 'kakao_tester',
      myClubs: [invited],
      discoverableClubs: [invited],
      membersByClubId: const {},
      financeByClubId: const {},
      loadedAt: DateTime(2026, 9, 19),
    ));

    await clubs.refreshOwnedClubs();

    expect(clubs.myClubs.any((c) => c.id == invited.id), isTrue,
        reason: '서버 멤버십이 있으면 남긴다');
  });

  test('서버 조회 실패·카탈로그 빈 응답에는 아무것도 지우지 않는다', () {
    final src = File('lib/providers/club_provider.dart').readAsStringSync();
    final start = src.indexOf('Future<bool> _pruneForeignClubs(');
    expect(start, greaterThan(0));
    final body = src.substring(start, start + 2200);
    expect(body.contains('if (_isDemoSession || _myClubs.isEmpty) return false;'),
        isTrue);
    expect(body.contains('} catch (e) {'), isTrue);
    expect(body.contains('if (catalog.isEmpty) return false;'), isTrue,
        reason: '카탈로그를 못 읽었는데 지우면 비행기모드에서 내 모임이 사라진다');
    expect(body.contains('if (!catalogIds.contains(c.id)) continue;'), isTrue,
        reason: '방금 만들어 아직 안 올라간 모임은 건드리지 않는다');
    expect(body.contains('_clubRosterHasMyPhone(c.id)'), isFalse,
        reason: '로컬 명단·번호만으로 남기면 잘못 붙은 모임이 다시 내 모임이 된다');
    expect(body.contains('if (mineIds.contains(c.id)) continue;'), isTrue);
  });
}
