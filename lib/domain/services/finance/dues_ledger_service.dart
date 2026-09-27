import '../../../models/club_model.dart';

/// 회비·미납 계산 — UI·Provider와 분리된 순수 Service Layer
class DuesLedgerService {
  /// 활성 회비 1건의 미납 건수 (회원×기간)
  int unpaidSlotsForSetting({
    required DuesSetting setting,
    required List<Member> members,
    required List<DuesPayment> payments,
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    final eligible = members
        .where((m) => m.status == '활성' && m.memberType == '정회원')
        .toList();
    if (eligible.isEmpty) return 0;

    switch (setting.type) {
      case DuesType.monthly:
        var count = 0;
        for (final period in _expectedMonthlyPeriods(setting, now)) {
          for (final m in eligible) {
            if (!_hasPaid(
              payments,
              memberId: m.id,
              duesSettingId: setting.id,
              year: period.year,
              month: period.month,
            )) {
              count++;
            }
          }
        }
        return count;
      case DuesType.annual:
        if (setting.createdAt.year > now.year) return 0;
        return eligible
            .where((m) => !_hasPaid(
                  payments,
                  memberId: m.id,
                  duesSettingId: setting.id,
                  year: setting.createdAt.year,
                ))
            .length;
      case DuesType.special:
        return eligible
            .where((m) => !_hasPaid(
                  payments,
                  memberId: m.id,
                  duesSettingId: setting.id,
                ))
            .length;
    }
  }

  int totalUnpaidAmount({
    required List<DuesSetting> activeSettings,
    required List<Member> members,
    required List<DuesPayment> payments,
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    return activeSettings
        .where((s) => s.isActive)
        .fold<int>(
          0,
          (sum, s) =>
              sum +
              unpaidSlotsForSetting(
                    setting: s,
                    members: members,
                    payments: payments,
                    asOf: now,
                  ) *
                  s.amount,
        );
  }

  bool hasAnyUnpaid({
    required List<DuesSetting> activeSettings,
    required List<Member> members,
    required List<DuesPayment> payments,
    DateTime? asOf,
  }) =>
      totalUnpaidAmount(
        activeSettings: activeSettings,
        members: members,
        payments: payments,
        asOf: asOf,
      ) >
      0;

  bool _hasPaid(
    List<DuesPayment> payments, {
    required String memberId,
    required String duesSettingId,
    int? year,
    int? month,
  }) {
    return payments.any((p) {
      if (p.memberId != memberId || p.duesSettingId != duesSettingId) {
        return false;
      }
      if (year != null && p.paidAt.year != year) return false;
      if (month != null && p.paidAt.month != month) return false;
      return true;
    });
  }

  Iterable<({int year, int month})> _expectedMonthlyPeriods(
    DuesSetting setting,
    DateTime asOf,
  ) sync* {
    var year = setting.startYear ?? setting.createdAt.year;
    var month = setting.startMonth ?? 1;
    final asOfKey = asOf.year * 12 + asOf.month;
    for (var i = 0; i < 240; i++) {
      if (year * 12 + month > asOfKey) break;
      if (setting.isActiveForYearMonth(year, month)) {
        yield (year: year, month: month);
      }
      final next = DuesSetting.shiftYearMonth(year, month, 1);
      year = next.year;
      month = next.month;
    }
  }
}
