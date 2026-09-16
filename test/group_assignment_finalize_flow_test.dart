import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/auth_provider.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClubProvider clubs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppDependencies.instance.init(offlineMock: true);
    final auth = AuthProvider();
    await auth.loginAsync('010-1234-5678');
    clubs = ClubProvider();
    await clubs.switchUser(
      auth.currentUser!.id,
      displayName: auth.currentUser!.name,
    );
  });

  GroupAssignment filled({
    required String id,
    required bool finalized,
  }) {
    return GroupAssignment(
      scheduleId: id,
      teamCount: 1,
      perGroup: 4,
      isFinalized: finalized,
      finalizedAt: finalized ? DateTime(2026, 9, 1) : null,
      groups: [
        AssignGroup(groupNumber: 1, slots: [
          const GroupSlot(
            memberId: 'm1',
            memberName: '홍길동',
            gender: '남',
            handicap: 12.0,
          ),
          const GroupSlot(),
          const GroupSlot(),
          const GroupSlot(),
        ]),
      ],
    );
  }

  test('초기화만 하면 비우고 확정은 유지한다', () {
    const id = 'ga_reset_keep';
    clubs.saveAssignment(filled(id: id, finalized: true));
    clubs.clearAssignment(id);
    final after = clubs.groupAssignment(id)!;
    expect(after.assignedCount, 0);
    expect(after.isFinalized, isTrue,
        reason: '상태는 저장할 때 바뀐다');
  });

  test('빈 조편성 저장은 미확정이다', () {
    const id = 'ga_empty_unfinal';
    clubs.saveAssignment(filled(id: id, finalized: true));
    clubs.clearAssignment(id);
    clubs.unfinalizeAssignment(id);
    expect(clubs.groupAssignment(id)!.isFinalized, isFalse);
    expect(clubs.groupAssignment(id)!.assignedCount, 0);
  });

  test('다시 짠 뒤 저장은 확정이다', () {
    const id = 'ga_rewrite_final';
    clubs.saveAssignment(filled(id: id, finalized: true));
    clubs.clearAssignment(id);
    clubs.unfinalizeAssignment(id);
    clubs.saveAssignment(filled(id: id, finalized: false));
    clubs.finalizeAssignment(id);
    expect(clubs.groupAssignment(id)!.isFinalized, isTrue);
    expect(clubs.groupAssignment(id)!.assignedCount, 1);
  });
}
