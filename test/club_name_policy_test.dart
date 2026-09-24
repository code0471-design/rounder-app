import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/domain/services/club_name_policy.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Club _club(String id, String name) => Club(
      id: id,
      name: name,
      myRole: '회장',
      memberCount: 1,
      region: '서울',
      industry: '골프',
      teamCount: 4,
      description: '',
      creatorId: 'kakao_a',
    );

void main() {
  test('공백·대소문자만 다른 이름은 같은 모임이다', () {
    expect(ClubNamePolicy.key('  아레나   골프회 '), '아레나 골프회');
    expect(
      ClubNamePolicy.isTaken(
        name: '아레나  골프회',
        clubs: [_club('c1', '아레나 골프회')],
      ),
      isTrue,
    );
    expect(
      ClubNamePolicy.isTaken(
        name: '아레나 골프회',
        clubs: [_club('c1', '아레나 골프회')],
        exceptClubId: 'c1',
      ),
      isFalse,
    );
  });

  test('이미 있는 이름으로는 모임을 만들거나 바꿀 수 없다', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    AppDependencies.instance.init(offlineMock: true);
    final clubs = ClubProvider();
    await clubs.switchUser(
      'kakao_name',
      displayName: '테스터',
      phone: '010-1111-2222',
    );
    expect(
      await clubs.createClub(
        name: '아레나 골프회',
        region: '서울',
        industry: '골프',
        teamCount: 4,
        myRole: '회장',
        description: '첫 모임',
      ),
      isTrue,
    );
    final firstId = clubs.selectedClub.id;
    expect(
      await clubs.createClub(
        name: '아레나  골프회',
        region: '부산',
        industry: '골프',
        teamCount: 2,
        myRole: '회장',
        description: '둘째',
      ),
      isFalse,
    );
    expect(clubs.myClubs.where((c) => c.id != firstId), isEmpty);

    expect(
      await clubs.createClub(
        name: '알라딘 정기월례회',
        region: '서울',
        industry: '골프',
        teamCount: 4,
        myRole: '회장',
        description: '다른 이름',
      ),
      isTrue,
    );
    expect(
      await clubs.updateClubInfo(
        clubId: clubs.selectedClub.id,
        name: '아레나 골프회',
      ),
      isFalse,
    );
    expect(clubs.selectedClub.name, '알라딘 정기월례회');
  });
}
