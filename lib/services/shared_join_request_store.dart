import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/club_model.dart';

/// 계정 전환과 무관하게 공유되는 가입 신청 대기열.
/// - 프로세스 메모리: 같은 탭에서 계정 전환 시 즉시 공유
/// - localStorage: 새로고침 후에도 유지 (같은 origin/포트)
abstract final class SharedJoinRequestStore {
  static const _key = 'rounder_shared_pending_joins_v2';

  /// 세션 메모리 — SharedPreferences 레이스/포트 이슈 대비
  static final List<JoinRequest> _memory = [];

  static List<JoinRequest> peekMemory() =>
      List<JoinRequest>.unmodifiable(_memory);

  static Future<List<JoinRequest>> loadAll() async {
    final fromDisk = <JoinRequest>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      try {
        await prefs.reload();
      } catch (_) {}
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List? ?? const [];
        for (final item in list) {
          final req = _decode(Map<String, dynamic>.from(item as Map));
          if (req != null) fromDisk.add(req);
        }
      }
    } catch (_) {}

    // 메모리 ∪ 디스크 (id 기준)
    final byId = <String, JoinRequest>{
      for (final r in _memory) r.id: r,
      for (final r in fromDisk) r.id: r,
    };
    final merged = byId.values.toList();
    _memory
      ..clear()
      ..addAll(merged);
    return List<JoinRequest>.from(merged);
  }

  static Future<void> upsert(JoinRequest req) async {
    _memory.removeWhere(
      (r) =>
          r.id == req.id ||
          (r.clubId == req.clubId &&
              r.userId == req.userId &&
              r.status == JoinRequestStatus.pending),
    );
    _memory.add(req);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(_memory.map(_encode).toList()),
      );
    } catch (_) {
      // 디스크 실패해도 메모리는 유지 — 같은 세션 계정 전환에는 충분
    }
  }

  static Future<void> remove(String requestId) async {
    _memory.removeWhere((r) => r.id == requestId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(_memory.map(_encode).toList()),
      );
    } catch (_) {}
  }

  static Map<String, dynamic> _encode(JoinRequest r) => {
        'id': r.id,
        'clubId': r.clubId,
        'userId': r.userId,
        'userName': r.userName,
        'userGender': r.userGender,
        'userHandicap': r.userHandicap,
        'message': r.message,
        'referrerId': r.referrerId,
        'referrerName': r.referrerName,
        'status': r.status.name,
        'requestedAt': r.requestedAt.toIso8601String(),
        'reviewedBy': r.reviewedBy,
        'reviewedAt': r.reviewedAt?.toIso8601String(),
      };

  static JoinRequest? _decode(Map<String, dynamic> m) {
    final id = m['id'] as String?;
    final clubId = m['clubId'] as String?;
    final userId = m['userId'] as String?;
    if (id == null || clubId == null || userId == null) return null;
    final statusName = m['status'] as String? ?? 'pending';
    final status = JoinRequestStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => JoinRequestStatus.pending,
    );
    if (status != JoinRequestStatus.pending) return null;
    return JoinRequest(
      id: id,
      clubId: clubId,
      userId: userId,
      userName: m['userName'] as String? ?? '',
      userGender: m['userGender'] as String? ?? '남',
      userHandicap: (m['userHandicap'] as num?)?.toDouble(),
      message: m['message'] as String? ?? '',
      referrerId: m['referrerId'] as String?,
      referrerName: m['referrerName'] as String?,
      status: status,
      requestedAt: DateTime.tryParse(m['requestedAt'] as String? ?? '') ??
          DateTime.now(),
      reviewedBy: m['reviewedBy'] as String?,
      reviewedAt: m['reviewedAt'] != null
          ? DateTime.tryParse(m['reviewedAt'] as String)
          : null,
    );
  }
}
