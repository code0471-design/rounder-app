import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/utils/dues_period_eligibility.dart';

Member _m({
  required String id,
  String type = '정회원',
  String status = '활성',
  DateTime? join,
  DateTime? regularSince,
  DateTime? left,
}) =>
    Member(
      id: id,
      name: id,
      gender: '남',
      memberType: type,
      role: '일반',
      joinDate: join,
      regularSince: regularSince,
      leftAt: left,
      status: status,
    );

void main() {
  final asOf = DateTime(2026, 9, 25);

  test('게스트는 목록에 없다', () {
    expect(
      DuesPeriodEligibility.isVisible(
        member: _m(id: 'g', type: '게스트'),
        type: DuesType.monthly,
        year: 2026,
        month: 9,
        asOf: asOf,
      ),
      isFalse,
    );
  });

  test('가입일 없는 예전 회원은 대상이다', () {
    expect(
      DuesPeriodEligibility.classify(
        member: _m(id: 'old'),
        type: DuesType.monthly,
        year: 2026,
        month: 8,
        hasPaid: false,
        asOf: asOf,
      ),
      DuesChip.unpaid,
    );
  });

  test('가입한 달부터 내고 그전은 가입 전이다', () {
    final m = _m(id: 'sep', join: DateTime(2026, 9, 10));
    expect(
      DuesPeriodEligibility.classify(
        member: m,
        type: DuesType.monthly,
        year: 2026,
        month: 8,
        hasPaid: false,
        asOf: asOf,
      ),
      DuesChip.beforeJoin,
    );
    expect(
      DuesPeriodEligibility.classify(
        member: m,
        type: DuesType.monthly,
        year: 2026,
        month: 9,
        hasPaid: false,
        asOf: asOf,
      ),
      DuesChip.unpaid,
    );
  });

  test('아직 안 된 달·해는 예정이지 미납이 아니다', () {
    expect(
      DuesPeriodEligibility.classify(
        member: _m(id: 'a', join: DateTime(2026, 1, 1)),
        type: DuesType.monthly,
        year: 2026,
        month: 10,
        hasPaid: false,
        asOf: asOf,
      ),
      DuesChip.scheduled,
    );
    expect(
      DuesPeriodEligibility.classify(
        member: _m(id: 'a', join: DateTime(2026, 1, 1)),
        type: DuesType.annual,
        year: 2027,
        hasPaid: false,
        asOf: asOf,
      ),
      DuesChip.scheduled,
    );
    expect(DuesPeriodEligibility.canRecord(DuesChip.scheduled), isTrue);
    expect(DuesPeriodEligibility.canRecord(DuesChip.unpaid), isTrue);
    expect(DuesPeriodEligibility.canRecord(DuesChip.beforeJoin), isFalse);
  });

  test('미리 낸 다음 달은 예정이 아니라 납부다', () {
    expect(
      DuesPeriodEligibility.classify(
        member: _m(id: 'a', join: DateTime(2026, 1, 1)),
        type: DuesType.monthly,
        year: 2026,
        month: 10,
        hasPaid: true,
        asOf: asOf,
      ),
      DuesChip.paid,
    );
  });

  test('탈퇴한 달부터 숨기고 그전 달은 탈퇴 배지로 남긴다', () {
    final left = _m(
      id: 'left',
      join: DateTime(2026, 1, 1),
      status: '탈퇴',
      left: DateTime(2026, 9, 5),
    );
    expect(
      DuesPeriodEligibility.isVisible(
        member: left,
        type: DuesType.monthly,
        year: 2026,
        month: 9,
        asOf: asOf,
      ),
      isFalse,
    );
    expect(
      DuesPeriodEligibility.classify(
        member: left,
        type: DuesType.monthly,
        year: 2026,
        month: 8,
        hasPaid: true,
        asOf: asOf,
      ),
      DuesChip.paid,
    );
  });

  test('탈퇴일 없는 예전 탈퇴는 오늘로 보고 지난달까지만 보인다', () {
    final left = _m(
      id: 'legacy',
      join: DateTime(2025, 1, 1),
      status: '탈퇴',
    );
    expect(
      DuesPeriodEligibility.isVisible(
        member: left,
        type: DuesType.monthly,
        year: 2026,
        month: 9,
        asOf: asOf,
      ),
      isFalse,
    );
    expect(
      DuesPeriodEligibility.isVisible(
        member: left,
        type: DuesType.monthly,
        year: 2026,
        month: 8,
        asOf: asOf,
      ),
      isTrue,
    );
  });

  test('게스트에서 정회원이 되면 전환 달부터 내고 게스트 달은 가입 전이다', () {
    final m = _m(
      id: 'conv',
      join: DateTime(2026, 7, 3),
      regularSince: DateTime(2026, 9, 20),
    );
    expect(
      DuesPeriodEligibility.classify(
        member: m,
        type: DuesType.monthly,
        year: 2026,
        month: 8,
        hasPaid: false,
        asOf: asOf,
      ),
      DuesChip.beforeJoin,
    );
    expect(
      DuesPeriodEligibility.classify(
        member: m,
        type: DuesType.monthly,
        year: 2026,
        month: 9,
        hasPaid: false,
        asOf: asOf,
      ),
      DuesChip.unpaid,
    );
    expect(m.joinDate, DateTime(2026, 7, 3));
  });

  test('연회비는 가입한 해부터, 탈퇴한 해부터 숨긴다', () {
    final m = _m(id: 'y', join: DateTime(2026, 9, 1));
    expect(
      DuesPeriodEligibility.classify(
        member: m,
        type: DuesType.annual,
        year: 2025,
        hasPaid: false,
        asOf: asOf,
      ),
      DuesChip.beforeJoin,
    );
    expect(
      DuesPeriodEligibility.classify(
        member: m,
        type: DuesType.annual,
        year: 2026,
        hasPaid: false,
        asOf: asOf,
      ),
      DuesChip.unpaid,
    );

    final left = _m(
      id: 'yl',
      join: DateTime(2024, 1, 1),
      status: '탈퇴',
      left: DateTime(2026, 3, 1),
    );
    expect(
      DuesPeriodEligibility.isVisible(
        member: left,
        type: DuesType.annual,
        year: 2026,
        asOf: asOf,
      ),
      isFalse,
    );
    expect(
      DuesPeriodEligibility.classify(
        member: left,
        type: DuesType.annual,
        year: 2025,
        hasPaid: true,
        asOf: asOf,
      ),
      DuesChip.paid,
    );
  });

  test('탈퇴했다가 다시 들어온 달은 미납이 아니라 미가입이다', () {
    final rejoined = Member(
      id: 'back',
      name: '박재가입',
      gender: '남',
      memberType: '정회원',
      role: '일반',
      joinDate: DateTime(2026, 1, 1),
      status: '활성',
      awayPeriods: MemberAway.closing(
        _m(
          id: 'back',
          join: DateTime(2026, 1, 1),
          status: '탈퇴',
          left: DateTime(2026, 8, 1),
        ),
        DateTime(2026, 10, 14),
      ),
    );
    expect(
      DuesPeriodEligibility.classify(
        member: rejoined,
        type: DuesType.monthly,
        year: 2026,
        month: 7,
        hasPaid: false,
        asOf: asOf,
      ),
      DuesChip.unpaid,
    );
    expect(
      DuesPeriodEligibility.classify(
        member: rejoined,
        type: DuesType.monthly,
        year: 2026,
        month: 8,
        hasPaid: false,
        asOf: asOf,
      ),
      DuesChip.away,
    );
    expect(
      DuesPeriodEligibility.classify(
        member: rejoined,
        type: DuesType.monthly,
        year: 2026,
        month: 9,
        hasPaid: false,
        asOf: asOf,
      ),
      DuesChip.away,
    );
    expect(
      DuesPeriodEligibility.classify(
        member: rejoined,
        type: DuesType.monthly,
        year: 2026,
        month: 10,
        hasPaid: false,
        asOf: asOf,
      ),
      DuesChip.scheduled,
    );
    expect(
      DuesPeriodEligibility.classify(
        member: rejoined,
        type: DuesType.monthly,
        year: 2026,
        month: 8,
        hasPaid: true,
        asOf: asOf,
      ),
      DuesChip.paid,
    );
    expect(DuesPeriodEligibility.canRecord(DuesChip.away), isFalse);
  });
}
