import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../core/config/runtime_mode.dart';

/// 어드민 ↔ 앱이 공유하는 HQ 설정 문서 읽기/쓰기.
abstract final class HqRemoteSettings {
  static bool get available =>
      !RuntimeMode.useOfflineMock && Firebase.apps.isNotEmpty;

  static Future<Map<String, dynamic>?> read(String docPath) async {
    if (!available) return null;
    try {
      final snap = await FirebaseFirestore.instance.doc(docPath).get();
      final data = snap.data();
      if (data == null || data.isEmpty) return null;
      return Map<String, dynamic>.from(data);
    } catch (e) {
      debugPrint('[HqRemote] read skip $docPath: $e');
      return null;
    }
  }

  static Future<void> write(String docPath, Map<String, dynamic> data) async {
    if (!available) return;
    try {
      await FirebaseFirestore.instance.doc(docPath).set(data);
    } catch (e) {
      debugPrint('[HqRemote] write skip $docPath: $e');
    }
  }
}
