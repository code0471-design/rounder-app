import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'club_data_codec.dart';

/// 계정별 로컬 데이터 저장 (웹: localStorage, 앱: SharedPreferences)
class ClubPersistence {
  static String _key(String authUserId) => 'rounder_club_data_v2_$authUserId';

  static Future<void> save(String authUserId, ClubDataBundle bundle) async {
    final prefs = await SharedPreferences.getInstance();
    final json = ClubDataCodec.encode(bundle);
    json['savedAt'] = DateTime.now().toIso8601String();
    json['authUserId'] = authUserId;
    await prefs.setString(_key(authUserId), jsonEncode(json));
  }

  static Future<ClubDataBundle?> load(String authUserId) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.reload(); // 다른 탭에서 저장한 모임 반영
    } catch (_) {}
    final raw = prefs.getString(_key(authUserId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = Map<String, dynamic>.from(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      final version = json['version'] as int? ?? 0;
      if (version < 4) return null;

      if (version < ClubDataCodec.currentVersion) {
        _migrateJson(json, version);
      }

      return ClubDataCodec.decode(json);
    } catch (_) {
      return null;
    }
  }

  /// 이전 버전 저장 데이터를 현재 스키마로 승격 (일정 등 사용자 데이터 유지)
  static void _migrateJson(Map<String, dynamic> json, int fromVersion) {
    if (fromVersion < 5) {
      json.putIfAbsent('alimtalkSettings', () => <String, dynamic>{});
    }
    if (fromVersion < 6) {
      _scrubUndersizedScheduleCapacity(json);
    }
    json['version'] = ClubDataCodec.currentVersion;
  }

  /// 팀수×4보다 작은 maxCapacity(구 테스트값)를 제거
  static void _scrubUndersizedScheduleCapacity(Map<String, dynamic> json) {
    final schedules = json['schedules'];
    if (schedules is! List) return;
    for (final item in schedules) {
      if (item is! Map) continue;
      final teamCount = item['teamCount'] as int? ?? 0;
      final maxCapacity = item['maxCapacity'] as int?;
      if (maxCapacity != null && maxCapacity < teamCount * 4) {
        item['maxCapacity'] = null;
      }
    }
  }

  static Future<void> clear(String authUserId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(authUserId));
  }
}
