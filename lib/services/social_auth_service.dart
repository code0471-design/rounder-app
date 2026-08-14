import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../core/config/social_auth_config.dart';
import '../core/config/runtime_mode.dart';

enum SocialProvider { kakao, google, apple }

class SocialProfile {
  final SocialProvider provider;
  final String providerUserId;
  final String name;
  final String? email;
  final String? photoUrl;

  const SocialProfile({
    required this.provider,
    required this.providerUserId,
    required this.name,
    this.email,
    this.photoUrl,
  });

  String get appUserId {
    switch (provider) {
      case SocialProvider.kakao:
        return 'kakao_$providerUserId';
      case SocialProvider.google:
        return 'google_$providerUserId';
      case SocialProvider.apple:
        return 'apple_$providerUserId';
    }
  }
}

class SocialAuthException implements Exception {
  final String message;
  const SocialAuthException(this.message);

  @override
  String toString() => message;
}

/// 카카오 / 구글 / Apple 실제 OAuth
abstract final class SocialAuthService {
  static bool _kakaoInitialized = false;
  static bool _googleInitialized = false;

  static Future<void> ensureKakaoInitialized() async {
    if (_kakaoInitialized) return;
    if (!SocialAuthConfig.isKakaoConfigured) {
      throw const SocialAuthException(
        '카카오 앱 키가 없습니다. KAKAO_NATIVE_APP_KEY를 설정해 주세요.',
      );
    }
    KakaoSdk.init(nativeAppKey: SocialAuthConfig.kakaoNativeAppKey.trim());
    _kakaoInitialized = true;
  }

  static Future<void> ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(
      clientId: SocialAuthConfig.googleIosClientId.trim().isEmpty
          ? null
          : SocialAuthConfig.googleIosClientId.trim(),
      serverClientId: SocialAuthConfig.googleServerClientId.trim().isEmpty
          ? null
          : SocialAuthConfig.googleServerClientId.trim(),
    );
    _googleInitialized = true;
  }

  static Future<SocialProfile> signIn(SocialProvider provider) {
    switch (provider) {
      case SocialProvider.kakao:
        return _signInWithKakao();
      case SocialProvider.google:
        return _signInWithGoogle();
      case SocialProvider.apple:
        return _signInWithApple();
    }
  }

  static Future<SocialProfile> _signInWithKakao() async {
    await ensureKakaoInitialized();
    try {
      if (await isKakaoTalkInstalled()) {
        await UserApi.instance.loginWithKakaoTalk();
      } else {
        await UserApi.instance.loginWithKakaoAccount();
      }
    } catch (e) {
      // 카카오톡 취소/실패 → 계정 로그인 재시도
      debugPrint('[SocialAuth] KakaoTalk login fallback: $e');
      await UserApi.instance.loginWithKakaoAccount();
    }

    final user = await UserApi.instance.me();
    final name = user.kakaoAccount?.profile?.nickname?.trim();
    return SocialProfile(
      provider: SocialProvider.kakao,
      providerUserId: user.id.toString(),
      name: (name == null || name.isEmpty) ? '카카오 회원' : name,
      email: user.kakaoAccount?.email,
      photoUrl: user.kakaoAccount?.profile?.profileImageUrl,
    );
  }

  static Future<SocialProfile> _signInWithGoogle() async {
    await ensureGoogleInitialized();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;

      if (!RuntimeMode.useOfflineMock &&
          idToken != null &&
          idToken.isNotEmpty) {
        try {
          final credential = GoogleAuthProvider.credential(idToken: idToken);
          await FirebaseAuth.instance.signInWithCredential(credential);
        } catch (e) {
          debugPrint('[SocialAuth] Firebase Google credential skip: $e');
        }
      }

      final name = account.displayName?.trim();
      return SocialProfile(
        provider: SocialProvider.google,
        providerUserId: account.id,
        name: (name == null || name.isEmpty) ? 'Google 회원' : name,
        email: account.email,
        photoUrl: account.photoUrl,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const SocialAuthException('구글 로그인이 취소되었습니다.');
      }
      throw SocialAuthException('구글 로그인 실패: ${e.description ?? e.code.name}');
    }
  }

  static Future<SocialProfile> _signInWithApple() async {
    if (kIsWeb) {
      throw const SocialAuthException('웹에서는 Apple 로그인을 지원하지 않습니다.');
    }

    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final apple = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final userId = apple.userIdentifier;
    if (userId == null || userId.isEmpty) {
      throw const SocialAuthException('Apple 사용자 정보를 가져오지 못했습니다.');
    }

    if (!RuntimeMode.useOfflineMock &&
        apple.identityToken != null &&
        apple.identityToken!.isNotEmpty) {
      try {
        final oauth = OAuthProvider('apple.com').credential(
          idToken: apple.identityToken,
          rawNonce: rawNonce,
          accessToken: apple.authorizationCode,
        );
        await FirebaseAuth.instance.signInWithCredential(oauth);
      } catch (e) {
        debugPrint('[SocialAuth] Firebase Apple credential skip: $e');
      }
    }

    final given = apple.givenName?.trim() ?? '';
    final family = apple.familyName?.trim() ?? '';
    final fullName = '$family$given'.trim();
    return SocialProfile(
      provider: SocialProvider.apple,
      providerUserId: userId,
      name: fullName.isEmpty ? 'Apple 회원' : fullName,
      email: apple.email,
    );
  }

  static Future<void> signOutProviders() async {
    try {
      if (_googleInitialized) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {}
    try {
      if (_kakaoInitialized) {
        await UserApi.instance.logout();
      }
    } catch (_) {}
  }

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
