import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/data_exception.dart';
import '../../models/club_model.dart';

abstract final class JoinRequestMapper {
  static JoinRequest fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String clubId,
  }) {
    final data = doc.data();
    if (data == null) {
      throw ParseDataException('JoinRequest ${doc.id} has no data');
    }
    return fromMap(doc.id, clubId, data);
  }

  static JoinRequest fromMap(
    String id,
    String clubId,
    Map<String, dynamic> data,
  ) {
    final statusRaw = data['status'] as String? ?? 'pending';
    final status = JoinRequestStatus.values.firstWhere(
      (s) => s.name == statusRaw,
      orElse: () => JoinRequestStatus.pending,
    );
    return JoinRequest(
      id: id,
      clubId: clubId,
      userId: data['user_id'] as String? ?? '',
      userName: data['user_name'] as String? ?? '',
      userGender: data['user_gender'] as String? ?? '남',
      userHandicap: _asDouble(data['user_handicap']),
      message: data['message'] as String? ?? '',
      status: status,
      requestedAt: _asDateTime(data['requested_at']) ?? DateTime.now(),
      reviewedBy: data['reviewed_by'] as String?,
      reviewedAt: _asDateTime(data['reviewed_at']),
    );
  }

  static Map<String, dynamic> toSubmitMap({
    required String userId,
    required String userName,
    required String userGender,
    double? userHandicap,
    required String message,
  }) =>
      {
        'user_id': userId,
        'user_name': userName,
        'user_gender': userGender,
        'user_handicap': userHandicap,
        'message': message,
        'status': JoinRequestStatus.pending.name,
        'requested_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

  static Map<String, dynamic> toReviewMap({
    required JoinRequestStatus status,
    required String reviewedBy,
  }) =>
      {
        'status': status.name,
        'reviewed_by': reviewedBy,
        'reviewed_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  static DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
