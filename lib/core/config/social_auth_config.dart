import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// 소셜 로그인 콘솔 키
///
/// Codemagic 등에서 dart-define으로 덮어쓸 수 있습니다.
abstract final class SocialAuthConfig {
  static const _kakaoIosDefault = '3f68f1701188818915ef76bcc764b687';
  static const _kakaoAndroidDefault = 'a4b6744dd621da26f0cf3244e9ea8fb5';

  static const kakaoIosAppKey = String.fromEnvironment(
    'KAKAO_IOS_APP_KEY',
    defaultValue: _kakaoIosDefault,
  );

  static const kakaoAndroidAppKey = String.fromEnvironment(
    'KAKAO_ANDROID_APP_KEY',
    defaultValue: _kakaoAndroidDefault,
  );

  /// 하위 호환 — 단일 키 dart-define이 있으면 우선
  static const kakaoNativeAppKeyOverride = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
  );

  /// iOS용 OAuth 클라이언트 ID (Google Cloud / Firebase)
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue:
        '909216389322-jfgbktkrvk7ulhtdc8u63el6ubk2i7n3.apps.googleusercontent.com',
  );

  /// Web/서버 클라이언트 ID (idToken용, Firebase Auth에 권장)
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '909216389322-3jp0348rm4d575jpl3rv0ngaj8proea6.apps.googleusercontent.com',
  );

  static String get kakaoNativeAppKey {
    final override = kakaoNativeAppKeyOverride.trim();
    if (override.isNotEmpty) return override;
    if (kIsWeb) return kakaoIosAppKey.trim();
    try {
      if (Platform.isAndroid) return kakaoAndroidAppKey.trim();
    } catch (_) {}
    return kakaoIosAppKey.trim();
  }

  static bool get isKakaoConfigured => kakaoNativeAppKey.isNotEmpty;

  static bool get isGoogleConfigured => googleIosClientId.trim().isNotEmpty;
}
