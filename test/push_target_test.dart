import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 푸시가 방장에게 두 번 가고 정작 그 회원은 못 받던 문제.
/// 옛 시드 id(`m1`)로 남은 명단 행을 방장 계정으로 해석한 탓이다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClubProvider clubs;
  late String clubId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppDependencies.instance.init(offlineMock: true);
    clubs = ClubProvider();
    await clubs.switchUser('kakao_ahn', displayName: '안경헌');
    final ok = await clubs.createClub(
      name: '아레나 골프회',
      region: '서울',
      industry: '골프',
      teamCount: 4,
      myRole: '회장',
    );
    expect(ok, isTrue);
    clubId = clubs.selectedClub.id;
    clubs.selectClubById(clubId);
  });

  test('옛 m1 명단 행은 내 수신함으로 가지 않는다', () {
    expect(clubs.fcmInboxIdForTest('m_${clubId}_m1'), '',
        reason: '방장이 같은 알림을 두 번 받던 원인');
    expect(clubs.fcmInboxIdForTest('m1'), '');
    expect(clubs.fcmInboxIdForTest('mg1'), '');
  });

  test('내 행과 계정 id 는 그대로 내 수신함이다', () {
    expect(clubs.fcmInboxIdForTest('m_creator_$clubId'), 'kakao_ahn');
    expect(clubs.fcmInboxIdForTest('m_${clubId}_kakao_ahn'), 'kakao_ahn');
    expect(clubs.fcmInboxIdForTest('kakao_ahn'), 'kakao_ahn');
  });

  test('다른 회원의 계정 id 는 그 사람 수신함으로 간다', () {
    expect(clubs.fcmInboxIdForTest('m_${clubId}_google_lee'), 'google_lee');
    expect(
      clubs.fcmInboxIdForTest('m_c_1786973797931_google_lee'),
      'google_lee',
      reason: '선택된 모임이 달라도 같은 사람이 두 줄이면 알림톡이 두 번 간다',
    );
  });

  test('옛 m1 행도 전화번호가 소속 계정과 맞으면 그 사람에게 간다', () async {
    const phone = '010-9287-4073';
    AppDependencies.instance.mockDataStore!.addMember(
      clubId: clubId,
      member: Member(
        id: 'google_lee',
        name: '이정원',
        gender: '남',
        memberType: '정회원',
        role: '정회원',
        phone: phone,
        joinDate: DateTime(2026, 9, 1),
      ),
      persist: false,
    );
    clubs.addMember(Member(
      id: 'm_${clubId}_m1',
      name: '이정원',
      gender: '남',
      memberType: '정회원',
      role: '정회원',
      phone: phone,
      joinDate: DateTime(2026, 9, 1),
    ));
    await clubs.hydrateClubAccounts(clubId);

    expect(clubs.fcmInboxIdForTest('m_${clubId}_m1'), 'google_lee',
        reason: '옛 행이라고 빼 버리면 그 회원은 알림을 한 번도 못 받는다');
  });

  test('앱이 화면에 없으면 수신함 리스너가 알림을 또 띄우지 않는다', () {
    final src =
        File('lib/services/push_notification_service.dart').readAsStringSync();
    expect(src.contains('if (!_appInForeground) continue;'), isTrue,
        reason: 'OS 가 띄운 FCM 알림 위에 로컬 알림을 또 띄우면 두 번 온다');
    expect(src.contains('_localDedupeWindow'), isTrue);
  });
}
