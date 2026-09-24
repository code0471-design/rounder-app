import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/models/user_model.dart';
import 'package:golf_rounder/providers/auth_provider.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 내 프로필 사진이 명단에서 안 보이던 문제.
/// 원격 명단을 받아오면 내 행이 원격 값(사진 없음)으로 통째 교체됐다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const clubId = 'c_arena';
  const myUid = 'kakao_ahn';
  const photo = 'https://example.com/me.jpg';
  const phone = '010-4511-0471';

  test('원격 명단이 내려와도 내 사진·번호가 남는다', () async {
    SharedPreferences.setMockInitialValues({});
    AppDependencies.instance.init(offlineMock: true);
    final clubs = ClubProvider();
    await clubs.switchUser(
      myUid,
      displayName: '안경헌',
      phone: phone,
      photoUrl: photo,
    );
    await clubs.createClub(
      name: '아레나 골프회',
      region: '서울',
      industry: '골프',
      teamCount: 4,
      myRole: '회장',
    );
    final id = clubs.selectedClub.id;
    clubs.selectClubById(id);
    expect(clubs.currentMember?.photoUrl, photo, reason: '만들 때부터 사진이 붙어야 한다');

    // 서버 명단에는 사진·번호가 없는 상태로 내려온다
    await clubs.mergeRemoteRosterForTest(id, [
      Member(
        id: myUid,
        name: '안경헌',
        gender: '남',
        memberType: '정회원',
        role: '회장',
        joinDate: DateTime(2026, 9, 1),
      ),
    ]);

    final me = clubs.membersForClub(id).firstWhere(
          (m) => (m.photoUrl ?? '').isNotEmpty || m.name == '안경헌',
        );
    expect(me.photoUrl, photo, reason: '원격 행이 덮어써서 사진이 사라지면 안 된다');
  });

  test('내 프로필 저장은 만든 모임·다른 모임 명단에 같이 반영된다', () async {
    SharedPreferences.setMockInitialValues({});
    AppDependencies.instance.init(offlineMock: true);
    final clubs = ClubProvider();
    await clubs.switchUser(
      myUid,
      displayName: '안경헌',
      phone: phone,
    );
    expect(
      await clubs.createClub(
        name: '알라딘',
        region: '서울',
        industry: '골프',
        teamCount: 4,
        myRole: '회장',
      ),
      isTrue,
    );
    final aladdinId = clubs.selectedClub.id;
    expect(
      await clubs.createClub(
        name: '아레나',
        region: '서울',
        industry: '골프',
        teamCount: 4,
        myRole: '회장',
      ),
      isTrue,
    );
    final arenaId = clubs.selectedClub.id;

    clubs.syncAuthGolfProfile(photoUrl: photo, phone: phone);

    final aladdinMe = clubs
        .membersForClub(aladdinId)
        .firstWhere((m) => m.id == 'm_creator_$aladdinId');
    final arenaMe = clubs
        .membersForClub(arenaId)
        .firstWhere((m) => m.id == 'm_creator_$arenaId');
    expect(aladdinMe.photoUrl, photo);
    expect(arenaMe.photoUrl, photo, reason: '계정 사진은 모든 내 모임 명단에 같아야 한다');
  });

  test('자동로그인 뒤에 계정 사진이 오면 만든 모임 방장 칸에도 붙는다', () async {
    SharedPreferences.setMockInitialValues({});
    AppDependencies.instance.init(offlineMock: true);
    final clubs = ClubProvider();
    await clubs.switchUser(
      myUid,
      displayName: '안경헌',
      phone: phone,
    );
    expect(
      await clubs.createClub(
        name: '아레나',
        region: '서울',
        industry: '골프',
        teamCount: 4,
        myRole: '회장',
      ),
      isTrue,
    );
    final arenaId = clubs.selectedClub.id;
    expect((clubs.currentMember?.photoUrl ?? '').trim(), isEmpty,
        reason: '계정 사진 없이 만든 방장 칸은 비어 있어야 한다');

    AuthProvider.onRemoteProfileHydrated?.call(AppUser(
      id: myUid,
      name: '안경헌',
      phone: phone,
      profileImageUrl: photo,
    ));

    expect(clubs.currentMember?.photoUrl, photo,
        reason: '서버에서 계정 사진이 오면 그 모임 명단에 반영돼야 한다');

    await clubs.mergeRemoteRosterForTest(arenaId, [
      Member(
        id: myUid,
        name: '안경헌',
        gender: '남',
        memberType: '정회원',
        role: '회장',
        joinDate: DateTime(2026, 9, 1),
      ),
    ]);
    expect(clubs.currentMember?.photoUrl, photo,
        reason: '사진 없는 서버 명단이 계정 사진을 지우면 안 된다');
  });

  test('계정 프로필은 모든 모임 명단 문서에 같이 쓴다', () {
    final ops = File('lib/services/club_ops_sync.dart').readAsStringSync();
    expect(ops.contains('static Future<void> upsertMemberProfile('), isTrue);
    final clubs = File('lib/providers/club_provider.dart').readAsStringSync();
    expect(clubs.contains('_pushMyProfileToAllClubMemberDocs()'), isTrue);
    expect(clubs.contains('ClubOpsSync.upsertMemberProfile('), isTrue);
  });

  test('자동로그인 원격 프로필이 명단에 다시 흘러가게 연결돼 있다', () {
    final auth = File('lib/providers/auth_provider.dart').readAsStringSync();
    expect(auth.contains('onRemoteProfileHydrated?.call(sessionUser)'), isTrue);
    final clubs = File('lib/providers/club_provider.dart').readAsStringSync();
    expect(clubs.contains('AuthProvider.onRemoteProfileHydrated'), isTrue);
    expect(clubs.contains('_applyHydratedAuthProfile'), isTrue);
  });

  test('번들을 다시 불러와도 계정 사진을 채운다', () {
    final src = File('lib/providers/club_provider.dart').readAsStringSync();
    final start = src.indexOf('_repairMyRosterNames(_currentUserName);');
    expect(start, greaterThan(0));
    expect(src.substring(start, start + 300).contains('_fillMyRosterProfile()'),
        isTrue,
        reason: '이름과 같은 자리에서 사진·번호도 다시 채워야 한다');
  });

  test('회비납부 탭도 프로필 사진을 쓴다', () {
    final src =
        File('lib/screens/finance/finance_screen.dart').readAsStringSync();
    expect(src.contains('avatarImage(member.photoUrl)'), isTrue,
        reason: '회비납부 명단만 이니셜로 나오면 안 된다');
  });
}
