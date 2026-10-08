import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import 'app_environment.dart';

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

  static const _googleIosOverride = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );
  static const _googleServerOverride = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  static const _prodIosClientId =
      '399890870575-a6otilvplbdlsh1ulhlnsmkqlp0983ke.apps.googleusercontent.com';
  static const _prodServerClientId =
      '399890870575-lsb5q67o4pag06e70ul6c8ugjpo25ti2.apps.googleusercontent.com';
  static const _devIosClientId =
      '909216389322-jfgbktkrvk7ulhtdc8u63el6ubk2i7n3.apps.googleusercontent.com';
  static const _devServerClientId =
      '909216389322-3jp0348rm4d575jpl3rv0ngaj8proea6.apps.googleusercontent.com';

  /// iOS용 OAuth 클라이언트 ID (Google Cloud / Firebase)
  ///
  /// dart-define이 없으면 APP_ENV 를 따른다. 스토어 빌드는 prod 인데
  /// 여기만 다른 프로젝트 ID 를 쓰면 구글 버튼이 안 열린다.
  static String get googleIosClientId {
    final override = _googleIosOverride.trim();
    if (override.isNotEmpty) return override;
    return AppEnv.isProd ? _prodIosClientId : _devIosClientId;
  }

  /// Web/서버 클라이언트 ID (idToken용, Firebase Auth에 권장)
  static String get googleServerClientId {
    final override = _googleServerOverride.trim();
    if (override.isNotEmpty) return override;
    return AppEnv.isProd ? _prodServerClientId : _devServerClientId;
  }

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
