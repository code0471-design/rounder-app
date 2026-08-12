import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/data_exception.dart';
import '../../../models/club_model.dart' as domain;

/// 회비·정산 Firestore 매퍼 (UI와 완전 분리)
abstract final class FinanceMapper {
  static domain.DuesSetting duesSettingFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw ParseDataException('DuesSetting ${doc.id} has no data');
    }
    return duesSettingFromMap(doc.id, data);
  }

  static domain.DuesSetting duesSettingFromMap(String id, Map<String, dynamic> data) {
    final typeRaw = data['type'] as String? ?? 'monthly';
    final type = domain.DuesType.values.firstWhere(
      (t) => t.name == typeRaw,
      orElse: () => domain.DuesType.monthly,
    );
    return domain.DuesSetting(
      id: id,
      type: type,
      amount: _asInt(data['amount']),
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      createdAt: _asDateTime(data['created_at']) ?? DateTime.now(),
      isActive: data['is_active'] as bool? ?? true,
      startMonth: data['start_month'] as int?,
      endMonth: data['end_month'] as int?,
    );
  }

  static domain.DuesPayment duesPaymentFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw ParseDataException('DuesPayment ${doc.id} has no data');
    }
    return duesPaymentFromMap(doc.id, data);
  }

  static domain.DuesPayment duesPaymentFromMap(String id, Map<String, dynamic> data) {
    return domain.DuesPayment(
      id: id,
      memberId: data['member_id'] as String? ?? '',
      memberName: data['member_name'] as String? ?? '',
      duesSettingId: data['dues_setting_id'] as String? ?? '',
      amount: _asInt(data['amount']),
      paidAt: _asDateTime(data['paid_at']) ?? DateTime.now(),
      memo: data['memo'] as String?,
      recordedBy: data['recorded_by'] as String? ?? '',
      skipsBalance: data['skips_balance'] as bool? ?? false,
    );
  }

  static domain.Transaction transactionFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw ParseDataException('Transaction ${doc.id} has no data');
    }
    return transactionFromMap(doc.id, data);
  }

  static domain.Transaction transactionFromMap(String id, Map<String, dynamic> data) {
    final typeRaw = data['type'] as String? ?? 'income';
    final type = typeRaw == 'expense' ? domain.TxType.expense : domain.TxType.income;
    final sourceRaw = data['source'] as String? ?? 'manual';
    final source = domain.TxSource.values.firstWhere(
      (s) => s.name == sourceRaw,
      orElse: () => domain.TxSource.manual,
    );
    return domain.Transaction(
      id: id,
      type: type,
      amount: _asInt(data['amount']),
      category: data['category'] as String? ?? '',
      title: data['title'] as String? ?? '',
      date: _asDateTime(data['date']) ?? DateTime.now(),
      recordedBy: data['recorded_by'] as String? ?? '',
      source: source,
      duesPaymentId: data['dues_payment_id'] as String?,
    );
  }

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? fallback;
  }

  static DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
