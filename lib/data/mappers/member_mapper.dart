import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/data_exception.dart';
import '../../models/club_model.dart';

abstract final class MemberMapper {
  static Member fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw ParseDataException('Member document ${doc.id} has no data');
    }
    return fromMap(doc.id, data);
  }

  static Member fromMap(String id, Map<String, dynamic> data) {
    try {
      return Member(
        id: id,
        name: data['name'] as String? ?? '',
        gender: data['gender'] as String? ?? '남',
        birthDate: _asDateTime(data['birth_date']) ?? DateTime(1980, 1, 1),
        photoUrl: data['photo_url'] as String?,
        phone: data['phone'] as String?,
        bio: data['bio'] as String?,
        memberType: data['member_type'] as String? ?? '정회원',
        role: data['role'] as String? ?? '일반',
        handicap: _asDouble(data['handicap']),
        joinDate: _asDateTime(data['join_date']) ?? DateTime.now(),
        address: data['address'] as String?,
        memo: data['memo'] as String?,
        status: data['status'] as String? ?? '활성',
      );
    } catch (e) {
      throw ParseDataException('Failed to parse member $id', cause: e);
    }
  }

  static Map<String, dynamic> toMap(Member member) => {
        'name': member.name,
        'gender': member.gender,
        'birth_date': member.birthDate?.toIso8601String(),
        'photo_url': member.photoUrl,
        'phone': member.phone,
        'bio': member.bio,
        'member_type': member.memberType,
        'role': member.role,
        'handicap': member.handicap,
        'join_date': member.joinDate?.toIso8601String(),
        'address': member.address,
        'memo': member.memo,
        'status': member.status,
        'updated_at': FieldValue.serverTimestamp(),
      };

  static DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static double _asDouble(dynamic v, {double fallback = 0}) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? fallback;
  }
}
