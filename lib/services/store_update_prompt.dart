import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/invite_links.dart';
import '../core/config/runtime_mode.dart';
import '../core/firebase/firestore_paths.dart';
import '../navigation/app_navigator.dart';
import '../theme/app_theme.dart';

/// pubspec `version:` 의 +build 와 같아야 한다.
const kStoreUpdateInstalledBuild = 216;

const _androidBuildKey = 'androidBuild';
const _iosBuildKey = 'iosBuild';

const _iosStoreUrl = 'https://apps.apple.com/kr/app/rounder/id6800716470';

bool storeUpdateIsAvailable({
  required int installedBuild,
  required int latestBuild,
}) {
  return installedBuild > 0 && latestBuild > installedBuild;
}

String storeUpdateBuildKey({required bool ios}) =>
    ios ? _iosBuildKey : _androidBuildKey;

int? storeUpdateBuildFromData(Map<String, dynamic>? data, {required bool ios}) {
  if (data == null) return null;
  final raw = data[storeUpdateBuildKey(ios: ios)];
  if (raw is num) return raw.toInt();
  return null;
}

/// 스토어에 더 높은 빌드가 있으면 안내 얼럿을 띄운다.
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
    if (Firebase.apps.isEmpty) return;

    final latest = await _readAndPublishLatest();
    if (latest == null) return;
    if (!storeUpdateIsAvailable(
      installedBuild: kStoreUpdateInstalledBuild,
      latestBuild: latest,
    )) {
      return;
    }

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

  static Future<int?> _readAndPublishLatest() async {
    try {
      final ios = defaultTargetPlatform == TargetPlatform.iOS;
      final key = storeUpdateBuildKey(ios: ios);
      final ref =
          FirebaseFirestore.instance.doc(FirestorePaths.metaStoreVersion);
      final snap = await ref.get();
      final remote = storeUpdateBuildFromData(snap.data(), ios: ios) ?? 0;
      if (kStoreUpdateInstalledBuild > remote) {
        await ref.set(
          {
            key: kStoreUpdateInstalledBuild,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        return kStoreUpdateInstalledBuild;
      }
      return remote;
    } catch (e) {
      debugPrint('[StoreUpdate] skip: $e');
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
