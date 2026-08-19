import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/firebase/firestore_paths.dart';
import '../screens/admin/admin_models.dart';
import 'hq_remote_settings.dart';

/// 본사 푸시 종류 카탈로그 — 어드민 사용중지가 앱 발송을 막는다.
class HqPushCatalog {
  static const prefsKey = 'admin_hq_push_types_v1';

  static const joinRequest = 'push_join_request';
  static const joinResult = 'push_join_result';
  static const scheduleConfirm = 'push_schedule_confirm';
  static const d1Reminder = 'push_d1_reminder';
  static const duesRequest = 'push_dues_request';
  static const scheduleCancel = 'push_schedule_cancel';
  static const duesNudge = 'push_dues_nudge';

  static List<HqPushType>? _memory;
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static List<HqPushType> _mergeWithDefaults(List<HqPushType> list) {
    final byId = {for (final t in list) t.id: t};
    final merged = <HqPushType>[];
    for (final def in AdminCatalog.hqPushTypes) {
      final saved = byId[def.id];
      merged.add(saved == null ? def : def.copyWith(enabled: saved.enabled));
    }
    return merged;
  }

  static (DateTime?, List<HqPushType>)? _decodeEnvelope(dynamic decoded) {
    try {
      if (decoded is List) {
        final list = decoded
            .map((e) => HqPushType.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (list.isEmpty) return null;
        return (null, _mergeWithDefaults(list));
      }
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        final typesRaw = map['types'];
        if (typesRaw is! List) return null;
        final list = typesRaw
            .map((e) => HqPushType.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (list.isEmpty) return null;
        final atRaw = map['updatedAt'];
        DateTime? at;
        if (atRaw is Timestamp) {
          at = atRaw.toDate();
        } else {
          at = DateTime.tryParse(atRaw?.toString() ?? '');
        }
        return (at, _mergeWithDefaults(list));
      }
    } catch (e) {
      debugPrint('[HqPushCatalog] decode fail: $e');
    }
    return null;
  }

  static Map<String, dynamic> _envelope(List<HqPushType> types) => {
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'types': types.map((e) => e.toJson()).toList(),
      };

  static Future<List<HqPushType>> load({bool forceDisk = true}) async {
    if (!forceDisk && _memory != null) {
      return List<HqPushType>.from(_memory!);
    }

    DateTime bestAt = DateTime.fromMillisecondsSinceEpoch(0);
    List<HqPushType>? best;

    void consider(dynamic raw, {required String source}) {
      final parsed = raw is String
          ? _decodeEnvelope(_tryJson(raw))
          : _decodeEnvelope(raw);
      if (parsed == null) return;
      final score = parsed.$1 ?? DateTime.fromMillisecondsSinceEpoch(1);
      if (best == null || score.isAfter(bestAt)) {
        best = parsed.$2;
        bestAt = score;
        debugPrint(
          '[HqPushCatalog] pick $source disabled='
          '${parsed.$2.where((t) => !t.enabled).map((t) => t.id).toList()}',
        );
      }
    }

    consider(await HqRemoteSettings.read(FirestorePaths.metaHqPush),
        source: 'firestore');

    try {
      final prefs = await SharedPreferences.getInstance();
      try {
        await prefs.reload();
      } catch (_) {}
      consider(prefs.getString(prefsKey), source: 'prefs');
    } catch (e) {
      debugPrint('[HqPushCatalog] prefs load fail: $e');
    }

    final result = best ?? List<HqPushType>.from(AdminCatalog.hqPushTypes);
    _memory = result;
    return List<HqPushType>.from(result);
  }

  static dynamic _tryJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(List<HqPushType> types) async {
    final merged = _mergeWithDefaults(types);
    _memory = merged;
    final env = _envelope(merged);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, jsonEncode(env));
    } catch (e) {
      debugPrint('[HqPushCatalog] prefs save fail: $e');
    }
    await HqRemoteSettings.write(FirestorePaths.metaHqPush, env);
    revision.value++;
  }

  static bool isEnabledSync(String id) {
    final types = _memory ?? AdminCatalog.hqPushTypes;
    return types.where((t) => t.id == id).firstOrNull?.enabled ?? true;
  }

  static HqPushType? byIdSync(String id) {
    final types = _memory ?? AdminCatalog.hqPushTypes;
    return types.where((t) => t.id == id).firstOrNull;
  }

  static String applyVars(String template, Map<String, String> vars) {
    var out = template;
    vars.forEach((k, v) {
      out = out.replaceAll('{{$k}}', v);
    });
    return out;
  }
}
