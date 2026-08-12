// Firebase 설정 — STAGING 프로젝트 (rounder-staging)
// 운영(rounder-f6019)과 분리됨. flutterfire configure로 재생성 가능.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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

  static bool get isStaging => currentPlatform.projectId == 'rounder-staging';

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

  // Web — rounder-staging
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDsdZ8Ws-PawrUe30LN2b7rYqCOH31b_cI',
    appId: '1:909216389322:web:ebc5063889f3d00cf0bc33',
    messagingSenderId: '909216389322',
    projectId: 'rounder-staging',
    authDomain: 'rounder-staging.firebaseapp.com',
    storageBucket: 'rounder-staging.firebasestorage.app',
  );

  // Android — rounder-staging
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyABEhMGGKZ5CUMEvfrEo3hOsmo4Ps9s1LQ',
    appId: '1:909216389322:android:9abba6c9905236d5f0bc33',
    messagingSenderId: '909216389322',
    projectId: 'rounder-staging',
    storageBucket: 'rounder-staging.firebasestorage.app',
  );

  // iOS — 아직 미등록 (필요 시 flutterfire configure)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'rounder-staging',
    storageBucket: 'rounder-staging.firebasestorage.app',
    iosBundleId: 'com.golfrounder.golf',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'rounder-staging',
    storageBucket: 'rounder-staging.firebasestorage.app',
    iosBundleId: 'com.golfrounder.golf',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'rounder-staging',
    authDomain: 'rounder-staging.firebaseapp.com',
    storageBucket: 'rounder-staging.firebasestorage.app',
  );
}
