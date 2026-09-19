import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 납부 처리·수입지출 입력은 화면에 **바로** 반영돼야 한다.
/// (저장이 화면보다 먼저 돌아 "다른 탭 갔다 와야 바뀌던" 문제)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClubProvider clubs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppDependencies.instance.init(offlineMock: true);
    clubs = ClubProvider();
    await clubs.switchUser('kakao_ahn', displayName: '안경헌');
    await clubs.createClub(
      name: '아레나 골프회',
      region: '서울',
      industry: '골프',
      teamCount: 4,
      myRole: '회장',
    );
    clubs.selectClubById(clubs.selectedClub.id);
  });

  test('납부 처리 통지 시점에 이미 잔고가 올라가 있다', () {
    clubs.addDuesSetting(DuesSetting(
      id: 'ds_year',
      type: DuesType.annual,
      amount: 120000,
      title: '연회비',
      createdAt: DateTime(2026, 1, 1),
      clubId: clubs.selectedClub.id,
    ));
    final before = clubs.totalBalance;

    int? balanceAtNotify;
    void listener() => balanceAtNotify ??= clubs.totalBalance;
    clubs.addListener(listener);

    clubs.recordPayment(
      memberId: clubs.currentMember!.id,
      memberName: '안경헌',
      duesSettingId: 'ds_year',
      amount: 120000,
      year: 2026,
    );
    clubs.removeListener(listener);

    expect(balanceAtNotify, before + 120000,
        reason: '통지 시점에 값이 아직 옛날이면 화면이 한 박자 늦게 바뀐다');
    expect(clubs.totalBalance, before + 120000);
  });

  test('수입·지출 입력도 바로 잔고에 반영된다', () {
    final before = clubs.totalBalance;
    clubs.addTransaction(Transaction(
      id: 'tx_test',
      type: TxType.expense,
      amount: 30000,
      category: '식대',
      title: '뒤풀이',
      date: DateTime(2026, 9, 19),
      recordedBy: '안경헌',
      clubId: clubs.selectedClub.id,
    ));
    expect(clubs.totalBalance, before - 30000);
  });

  test('저장은 화면을 먼저 그린 뒤에 돈다', () {
    final src = File('lib/providers/club_provider.dart').readAsStringSync();
    final start = src.indexOf('void _persistImmediately() {');
    expect(start, greaterThan(0));
    final body = src.substring(start, start + 400);
    expect(body.contains('Timer(Duration.zero'), isTrue,
        reason: '번들 전체 JSON 인코딩을 프레임 앞에서 돌리면 금액이 늦게 바뀐다');
  });
}
