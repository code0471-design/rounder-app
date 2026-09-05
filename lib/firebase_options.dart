// Firebase 설정 — 스테이징(rounder-staging) / 운영(rounder-f6019)
//
// 어느 쪽을 쓸지는 `--dart-define=APP_ENV=prod|staging` 이 정한다.
// 네이티브(google-services.json / GoogleService-Info.plist)도 같이 바뀌어야 하므로
// 빌드 전에 반드시 `python3 tool/select_firebase_env.py --env <env>` 를 돌린다.
//
// flutterfire configure 로 재생성할 때는 해당 환경 블록만 갈아끼울 것.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'core/config/app_environment.dart';

class DefaultFirebaseOptions {
  /// Web 앱이 Firebase Console에 등록·설정되었는지
  static bool get isWebConfigured {
    final id = web.appId;
    final key = web.apiKey;
    if (key.isEmpty || key == 'REPLACE_ME') return false;
    if (id.contains('REPLACE') || id.contains('000000000000')) return false;
    if (id.contains('rounder_web_app')) return false;
    return true;
  }

  static bool get isStaging => currentPlatform.projectId == AppEnv.stagingProjectId;

  static bool get isProd => currentPlatform.projectId == AppEnv.prodProjectId;

  static FirebaseOptions get web =>
      AppEnv.isProd ? _ProdOptions.web : _StagingOptions.web;

  static FirebaseOptions get android =>
      AppEnv.isProd ? _ProdOptions.android : _StagingOptions.android;

  static FirebaseOptions get ios =>
      AppEnv.isProd ? _ProdOptions.ios : _StagingOptions.ios;

  static FirebaseOptions get macos =>
      AppEnv.isProd ? _ProdOptions.ios : _StagingOptions.macos;

  static FirebaseOptions get windows =>
      AppEnv.isProd ? _ProdOptions.web : _StagingOptions.windows;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }
}

/// STAGING — rounder-staging (테스터 검증용)
abstract final class _StagingOptions {
  static const web = FirebaseOptions(
    apiKey: 'AIzaSyDsdZ8Ws-PawrUe30LN2b7rYqCOH31b_cI',
    appId: '1:909216389322:web:ebc5063889f3d00cf0bc33',
    messagingSenderId: '909216389322',
    projectId: 'rounder-staging',
    authDomain: 'rounder-staging.firebaseapp.com',
    storageBucket: 'rounder-staging.firebasestorage.app',
  );

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyABEhMGGKZ5CUMEvfrEo3hOsmo4Ps9s1LQ',
    appId: '1:909216389322:android:9abba6c9905236d5f0bc33',
    messagingSenderId: '909216389322',
    projectId: 'rounder-staging',
    storageBucket: 'rounder-staging.firebasestorage.app',
  );

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyDILdqtIdWIInN7QzDBa6VVX-pD7sd9LGQ',
    appId: '1:909216389322:ios:449f12d1cd1a1b2df0bc33',
    messagingSenderId: '909216389322',
    projectId: 'rounder-staging',
    storageBucket: 'rounder-staging.firebasestorage.app',
    iosBundleId: 'com.golfrounder.golfRounder',
    iosClientId:
        '909216389322-jfgbktkrvk7ulhtdc8u63el6ubk2i7n3.apps.googleusercontent.com',
  );

  static const macos = FirebaseOptions(
    apiKey: 'AIzaSyDILdqtIdWIInN7QzDBa6VVX-pD7sd9LGQ',
    appId: '1:909216389322:ios:449f12d1cd1a1b2df0bc33',
    messagingSenderId: '909216389322',
    projectId: 'rounder-staging',
    storageBucket: 'rounder-staging.firebasestorage.app',
    iosBundleId: 'com.golfrounder.golfRounder',
  );

  static const windows = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'rounder-staging',
    authDomain: 'rounder-staging.firebaseapp.com',
    storageBucket: 'rounder-staging.firebasestorage.app',
  );
}

/// PROD — rounder-f6019 (실사용자)
abstract final class _ProdOptions {
  static const web = FirebaseOptions(
    apiKey: 'AIzaSyA876ZzWwgRXGWyw-bj_zNMzYhLlA3l-qc',
    appId: '1:399890870575:web:ada67cfa5d076443e6f1da',
    messagingSenderId: '399890870575',
    projectId: 'rounder-f6019',
    authDomain: 'rounder-f6019.firebaseapp.com',
    storageBucket: 'rounder-f6019.firebasestorage.app',
    measurementId: 'G-6ZGSY22LRL',
  );

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyDydqGGrRgZKbUkNTpSXRXa7MqE0zAfT_Q',
    appId: '1:399890870575:android:0524445ffa5f1738e6f1da',
    messagingSenderId: '399890870575',
    projectId: 'rounder-f6019',
    storageBucket: 'rounder-f6019.firebasestorage.app',
  );

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyDouApkSglNVeIXJkGRE-J4p-Y-1F5dSQE',
    appId: '1:399890870575:ios:90c233302ff4f1e4e6f1da',
    messagingSenderId: '399890870575',
    projectId: 'rounder-f6019',
    storageBucket: 'rounder-f6019.firebasestorage.app',
    iosBundleId: 'com.golfrounder.golfRounder',
    iosClientId:
        '399890870575-a6otilvplbdlsh1ulhlnsmkqlp0983ke.apps.googleusercontent.com',
  );
}
