import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/data_exception.dart';
import '../../models/club_model.dart';

/// Club ↔ Firestore 문서 변환 (UI·Provider와 분리)
abstract final class ClubMapper {
  static Club fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    String myRole = '일반',
  }) {
    final data = doc.data();
    if (data == null) {
      throw ParseDataException('Club document ${doc.id} has no data');
    }
    return fromMap(doc.id, data, myRole: myRole);
  }

  static Club fromMap(
    String id,
    Map<String, dynamic> data, {
    String myRole = '일반',
  }) {
    try {
      return Club(
        id: id,
        name: data['name'] as String? ?? '',
        imageUrl: data['image_url'] as String? ?? data['imageUrl'] as String?,
        myRole: data['my_role'] as String? ?? data['myRole'] as String? ?? myRole,
        memberCount: _asInt(data['member_count'] ?? data['memberCount']),
        nextRoundDate: _asDateTime(data['next_round_date'] ?? data['nextRoundDate']),
        nextRoundCourse:
            data['next_round_course'] as String? ?? data['nextRoundCourse'] as String?,
        creatorId: data['creator_id'] as String? ?? data['creatorId'] as String? ?? '',
        region: data['region'] as String? ?? '서울',
        industry: data['industry'] as String? ?? '기타',
        teamCount: _asInt(data['team_count'] ?? data['teamCount'], fallback: 4),
        description: data['description'] as String? ?? '',
        createdAt: _asDateTime(data['created_at'] ?? data['createdAt']) ??
            DateTime.now(),
      );
    } catch (e) {
      throw ParseDataException('Failed to parse club $id', cause: e);
    }
  }

  static Map<String, dynamic> toMap(Club club) => {
        'name': club.name,
        'image_url': club.imageUrl,
        'member_count': club.memberCount,
        'next_round_date': club.nextRoundDate?.toIso8601String(),
        'next_round_course': club.nextRoundCourse,
        'creator_id': club.creatorId,
        'region': club.region,
        'industry': club.industry,
        'team_count': club.teamCount,
        'description': club.description,
        'created_at': Timestamp.fromDate(club.createdAt),
        'updated_at': FieldValue.serverTimestamp(),
        'is_sample': true,
        // 플랫폼 어드민 검수 상태 — 앱 탐색 목록은 active만 노출
        'moderation_status': 'active',
        'max_members': 20,
      };

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
