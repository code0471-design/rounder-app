import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/firebase/firestore_paths.dart';
import '../screens/admin/admin_models.dart';
import 'hq_alimtalk_web_storage_stub.dart'
    if (dart.library.html) 'hq_alimtalk_web_storage.dart' as web_ls;
import 'hq_remote_settings.dart';

/// 본사(어드민) 알림톡 종류 카탈로그
///
/// 여러 저장소에 동일 페이로드를 쓰고, 로드 시 updatedAt이 가장 최신인 값을 사용.
/// (웹에서 어드민 탭 ↔ 앱 탭 SharedPreferences 캐시 불일치 방지)
class HqAlimtalkCatalog {
  static const prefsKey = 'admin_hq_alimtalk_types_v1';
  static const rawLsKey = 'rounder_hq_alimtalk_types_v1';
  /// 앱↔어드민이 이미 공유하는 mock store 키에 함께 저장
  static const mockStoreKey = 'rounder_mock_store_v2';

  static const scheduleUploadId = 'atk_schedule_upload';
  static const groupFinalizeId = 'atk_group_finalize';
  static const scheduleChangeId = 'atk_schedule_change';

  static const clubLinkedIds = <String>{
    scheduleUploadId,
    groupFinalizeId,
    scheduleChangeId,
  };

  static List<HqAlimtalkType>? _memory;
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static List<HqAlimtalkType> _mergeWithDefaults(List<HqAlimtalkType> list) {
    final byId = {for (final t in list) t.id: t};
    final merged = <HqAlimtalkType>[];
    for (final def in AdminCatalog.hqAlimtalkTypes) {
      merged.add(byId[def.id] ?? def);
    }
    for (final t in list) {
      if (!merged.any((m) => m.id == t.id)) merged.add(t);
    }
    return merged;
  }

  /// envelope: { updatedAt, types: [...] } 또는 레거시 배열
  static (DateTime?, List<HqAlimtalkType>)? _decodeEnvelope(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded
            .map((e) =>
                HqAlimtalkType.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (list.isEmpty) return null;
        return (null, _mergeWithDefaults(list));
      }
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        final typesRaw = map['types'];
        if (typesRaw is! List) return null;
        final list = typesRaw
            .map((e) =>
                HqAlimtalkType.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (list.isEmpty) return null;
        final at = DateTime.tryParse(map['updatedAt'] as String? ?? '');
        return (at, _mergeWithDefaults(list));
      }
    } catch (e) {
      debugPrint('[HqAlimtalkCatalog] decode fail: $e');
    }
    return null;
  }

  static String _encodeEnvelope(List<HqAlimtalkType> types) => jsonEncode({
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'types': types.map((e) => e.toJson()).toList(),
      });

  static Future<List<HqAlimtalkType>> load({bool forceDisk = true}) async {
    if (!forceDisk && _memory != null) {
      return List<HqAlimtalkType>.from(_memory!);
    }

    DateTime bestAt = DateTime.fromMillisecondsSinceEpoch(0);
    List<HqAlimtalkType>? best;

    void consider(String? raw, {String source = '?'}) {
      final parsed = _decodeEnvelope(raw);
      if (parsed == null) return;
      final at = parsed.$1 ?? DateTime.fromMillisecondsSinceEpoch(0);
      final score =
          parsed.$1 != null ? at : DateTime.fromMillisecondsSinceEpoch(1);
      if (best == null || score.isAfter(bestAt)) {
        best = parsed.$2;
        bestAt = score;
        debugPrint(
          '[HqAlimtalkCatalog] pick from $source at=$score '
          'disabled=${parsed.$2.where((t) => !t.enabled).map((t) => t.id).toList()}',
        );
      }
    }

    final remote = await HqRemoteSettings.read(FirestorePaths.metaHqAlimtalk);
    if (remote != null) {
      consider(jsonEncode(remote), source: 'firestore');
    }

    if (kIsWeb) {
      consider(web_ls.hqAlimtalkReadRaw(rawLsKey), source: 'rawLS');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      try {
        await prefs.reload();
      } catch (_) {}
      consider(prefs.getString(prefsKey), source: 'prefs');

      final mockRaw = prefs.getString(mockStoreKey);
      if (mockRaw != null && mockRaw.isNotEmpty) {
        try {
          final mock = Map<String, dynamic>.from(jsonDecode(mockRaw) as Map);
          final hq = mock['hqAlimtalk'];
          if (hq != null) {
            consider(jsonEncode(hq), source: 'mockStore');
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[HqAlimtalkCatalog] prefs load fail: $e');
    }

    final result =
        best ?? List<HqAlimtalkType>.from(AdminCatalog.hqAlimtalkTypes);
    _memory = result;
    return List<HqAlimtalkType>.from(result);
  }

  static Future<void> save(List<HqAlimtalkType> types) async {
    final merged = _mergeWithDefaults(types);
    _memory = merged;
    final raw = _encodeEnvelope(merged);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, raw);

      // mock store JSON에 병합 저장 (다른 탭이 clubs와 같이 읽음)
      try {
        await prefs.reload();
        final mockRaw = prefs.getString(mockStoreKey);
        Map<String, dynamic> mock = {};
        if (mockRaw != null && mockRaw.isNotEmpty) {
          mock = Map<String, dynamic>.from(jsonDecode(mockRaw) as Map);
        }
        mock['hqAlimtalk'] = jsonDecode(raw);
        mock['savedAt'] = DateTime.now().toIso8601String();
        await prefs.setString(mockStoreKey, jsonEncode(mock));
      } catch (e) {
        debugPrint('[HqAlimtalkCatalog] mockStore merge fail: $e');
      }
    } catch (e) {
      debugPrint('[HqAlimtalkCatalog] prefs save failed: $e');
    }

    if (kIsWeb) {
      try {
        web_ls.hqAlimtalkWriteRaw(rawLsKey, raw);
      } catch (e) {
        debugPrint('[HqAlimtalkCatalog] localStorage save failed: $e');
      }
    }

    try {
      await HqRemoteSettings.write(
        FirestorePaths.metaHqAlimtalk,
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (e) {
      debugPrint('[HqAlimtalkCatalog] firestore save fail: $e');
    }

    revision.value++;
    debugPrint(
      '[HqAlimtalkCatalog] saved disabled='
      '${merged.where((t) => !t.enabled).map((t) => t.id).toList()}',
    );
  }

  static Future<bool> isGloballyEnabled(String id) async {
    final types = await load(forceDisk: true);
    final hit = types.where((t) => t.id == id).firstOrNull;
    return hit?.enabled ?? true;
  }

  static Future<void> setEnabled(String id, bool enabled) async {
    final types = await load(forceDisk: true);
    final i = types.indexWhere((t) => t.id == id);
    if (i < 0) {
      debugPrint('[HqAlimtalkCatalog] setEnabled: id not found $id');
      return;
    }
    types[i] = types[i].copyWith(enabled: enabled);
    await save(types);
  }

  static Future<HqAlimtalkType?> byId(String id) async {
    final types = await load(forceDisk: true);
    return types.where((t) => t.id == id).firstOrNull;
  }
}
