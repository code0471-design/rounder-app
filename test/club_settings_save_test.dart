import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/domain/services/app_data_bootstrap_service.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClubProvider clubs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppDependencies.instance.init(offlineMock: true);
    clubs = ClubProvider();
    await clubs.switchUser(
      'kakao_settings',
      displayName: '테스터',
      phone: '010-1111-2222',
    );
  });

  test('설정에서 고친 이름·소개·지역은 bootstrap이 덮지 않는다', () async {
    final ok = await clubs.createClub(
      name: '옛이름',
      region: '서울',
      industry: '골프',
      teamCount: 4,
      myRole: '회장',
      description: '옛소개',
    );
    expect(ok, isTrue);
    final id = clubs.selectedClub.id;

    await clubs.updateClubInfo(
      clubId: id,
      name: '새이름',
      description: '새소개',
      region: '부산',
      industry: '제조',
      teamCount: 6,
    );
    expect(clubs.selectedClub.name, '새이름');
    expect(clubs.selectedClub.description, '새소개');
    expect(clubs.selectedClub.region, '부산');
    expect(clubs.selectedClub.industry, '제조');
    expect(clubs.selectedClub.teamCount, 6);

    clubs.hydrateFromBootstrap(AppBootstrapSnapshot(
      userId: 'kakao_settings',
      myClubs: [
        Club(
          id: id,
          name: '옛이름',
          myRole: '회장',
          memberCount: 1,
          region: '서울',
          industry: '골프',
          teamCount: 4,
          description: '옛소개',
          creatorId: 'kakao_settings',
        ),
      ],
      discoverableClubs: const [],
      membersByClubId: const {},
      financeByClubId: const {},
      loadedAt: DateTime(2026, 9, 24),
    ));

    expect(clubs.selectedClub.name, '새이름',
        reason: '서버 옛 이름이 설정 저장을 지우면 안 된다');
    expect(clubs.selectedClub.description, '새소개');
    expect(clubs.selectedClub.region, '부산');
    expect(clubs.selectedClub.industry, '제조');
    expect(clubs.selectedClub.teamCount, 6);
  });
}
