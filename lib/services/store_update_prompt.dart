import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../config/invite_links.dart';
import '../core/config/runtime_mode.dart';
import '../core/firebase/firestore_paths.dart';
import '../navigation/app_navigator.dart';
import '../theme/app_theme.dart';

/// pubspec `version:` 의 name. +build 와 짝이다.
const kStoreUpdateInstalledVersion = '1.0.3';

/// pubspec `version:` 의 +build 와 같아야 한다.
const kStoreUpdateInstalledBuild = 219;

const _androidBuildKey = 'androidBuild';
const _iosBuildKey = 'iosBuild';

const _iosStoreUrl = 'https://apps.apple.com/kr/app/rounder/id6800716470';
const _iosLookupUrl =
    'https://itunes.apple.com/lookup?bundleId=com.golfrounder.golfRounder&country=kr';

bool storeUpdateIsAvailable({
  required int installedBuild,
  required int latestBuild,
}) {
  return installedBuild > 0 && latestBuild > installedBuild;
}

int compareStoreVersionNames(String a, String b) {
  List<int> parts(String v) => v
      .split('.')
      .map((p) => int.tryParse(p.trim()) ?? 0)
      .toList(growable: false);
  final pa = parts(a);
  final pb = parts(b);
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final da = i < pa.length ? pa[i] : 0;
    final db = i < pb.length ? pb[i] : 0;
    if (da != db) return da.compareTo(db);
  }
  return 0;
}

bool storeVersionNameIsNewer({
  required String installed,
  required String store,
}) {
  if (installed.trim().isEmpty || store.trim().isEmpty) return false;
  return compareStoreVersionNames(installed, store) < 0;
}

String storeUpdateBuildKey({required bool ios}) =>
    ios ? _iosBuildKey : _androidBuildKey;

int? storeUpdateBuildFromData(Map<String, dynamic>? data, {required bool ios}) {
  if (data == null) return null;
  final raw = data[storeUpdateBuildKey(ios: ios)];
  if (raw is num) return raw.toInt();
  return null;
}

String? parseIosLookupVersion(String body) {
  try {
    final json = jsonDecode(body);
    if (json is! Map) return null;
    final results = json['results'];
    if (results is! List || results.isEmpty) return null;
    final first = results.first;
    if (first is! Map) return null;
    final version = first['version'];
    return version is String ? version.trim() : null;
  } catch (_) {
    return null;
  }
}

String? parsePlayStoreVersionName(String html) {
  final decoded = html.replaceAll(r'\"', '"');
  for (final re in [
    RegExp(r'"141"\s*:\s*\[\[\["(\d+(?:\.\d+){1,3})"\]\]'),
    RegExp(r'"softwareVersion"\s*:\s*"(\d+(?:\.\d+){1,3})"'),
    RegExp(
      r'itemprop="softwareVersion"[^>]*>\s*(\d+(?:\.\d+){1,3})',
      caseSensitive: false,
    ),
  ]) {
    final m = re.firstMatch(decoded);
    if (m != null) return m.group(1);
  }
  return null;
}

/// 스토어에 더 높은 버전이 있으면 안내 얼럿을 띄운다.
/// 명단·알림·재무는 읽거나 쓰지 않는다.
abstract final class StoreUpdatePrompt {
  static bool _sessionShown = false;
  static bool _scheduled = false;

  @visibleForTesting
  static void resetForTest() {
    _sessionShown = false;
    _scheduled = false;
  }

  static void scheduleAfterLaunch() {
    if (kIsWeb || RuntimeMode.useOfflineMock) return;
    if (_scheduled) return;
    _scheduled = true;
    unawaited(_runAfterLaunch());
  }

  static Future<void> _runAfterLaunch() async {
    await Future<void>.delayed(const Duration(milliseconds: 2800));
    await maybeShow();
    await Future<void>.delayed(const Duration(seconds: 8));
    await maybeShow();
  }

  static Future<void> maybeShow() async {
    if (kIsWeb || RuntimeMode.useOfflineMock) return;
    if (_sessionShown) return;

    final needs = await _needsStoreUpdate();
    if (!needs) return;

    final ctx = AppNavigator.context;
    if (ctx == null || !ctx.mounted) return;
    if (_sessionShown) return;
    _sessionShown = true;

    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('업데이트 안내'),
          content: const Text('새 버전이 있습니다. 스토어에서 업데이트해 주세요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('나중에'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                unawaited(openStoreListing());
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: const Text('업데이트'),
            ),
          ],
        );
      },
    );
  }

  static Future<bool> _needsStoreUpdate() async {
    try {
      final storeName = await _fetchStoreVersionName();
      if (storeName != null &&
          storeVersionNameIsNewer(
            installed: kStoreUpdateInstalledVersion,
            store: storeName,
          )) {
        return true;
      }
    } catch (e) {
      debugPrint('[StoreUpdate] store lookup skip: $e');
    }

    final remoteBuild = await _readRemoteBuild();
    return storeUpdateIsAvailable(
      installedBuild: kStoreUpdateInstalledBuild,
      latestBuild: remoteBuild ?? 0,
    );
  }

  static Future<String?> _fetchStoreVersionName() async {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (ios) {
      final res = await http.get(Uri.parse(_iosLookupUrl)).timeout(
            const Duration(seconds: 8),
          );
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      return parseIosLookupVersion(res.body);
    }
    final res = await http
        .get(
          Uri.parse('${InviteLinks.playStore}&hl=en&gl=kr'),
          headers: const {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          },
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    return parsePlayStoreVersionName(res.body);
  }

  /// 읽기만 한다. 지금 깔린 빌드를 최신으로 덮으면 스토어 업데이트가 있어도 안내가 안 뜬다.
  static Future<int?> _readRemoteBuild() async {
    if (Firebase.apps.isEmpty) return null;
    try {
      final ios = defaultTargetPlatform == TargetPlatform.iOS;
      final snap = await FirebaseFirestore.instance
          .doc(FirestorePaths.metaStoreVersion)
          .get();
      return storeUpdateBuildFromData(snap.data(), ios: ios);
    } catch (e) {
      debugPrint('[StoreUpdate] remote skip: $e');
      return null;
    }
  }

  static Future<void> openStoreListing() async {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final url = Uri.parse(ios ? _iosStoreUrl : InviteLinks.playStore);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[StoreUpdate] open store skip: $e');
    }
  }
}
