import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/config/runtime_mode.dart';
import '../models/user_model.dart';

/// Staging용 Firebase Auth 브릿지
///
/// 앱 UI는 기존 전화번호 Mock 로그인을 유지하고,
/// 로그인 성공 시 Firestore rules용 Firebase Auth 세션을 맞춘다.
///
/// 이메일: `{userId}@staging.rounder.app`
/// 비밀번호: 스테이징 고정값 (운영 금지)
abstract final class FirebaseAuthBridge {
  static const stagingPassword = 'RounderStaging1!';
  static const stagingBootstrapUserId = 'user_me';

  static String emailFor(String userId) =>
      '${userId.trim().toLowerCase()}@staging.rounder.app';

  /// 어드민/시드용 — 로그인 UI 없이도 Auth 세션 확보
  static Future<bool> ensureStagingSession({String? userId}) async {
    if (RuntimeMode.useOfflineMock) return false;
    final id = (userId == null || userId.isEmpty)
        ? stagingBootstrapUserId
        : userId;
    return ensureSignedIn(
      AppUser(
        id: id,
        name: 'Staging',
        phone: '010-0000-0000',
        isAdmin: true,
        role: '총무',
      ),
    );
  }

  /// 앱 유저로 Firebase Auth 세션 확보 (없으면 생성)
  static Future<bool> ensureSignedIn(AppUser user) async {
    if (RuntimeMode.useOfflineMock) return false;

    try {
      final auth = FirebaseAuth.instance;
      final email = emailFor(user.id);
      final current = auth.currentUser;

      if (current != null &&
          (current.email?.toLowerCase() == email ||
              current.uid.isNotEmpty && current.email == email)) {
        debugPrint('[FirebaseAuthBridge] already signed in as $email');
        return true;
      }

      if (current != null) {
        await auth.signOut();
      }

      try {
        await auth.signInWithEmailAndPassword(
          email: email,
          password: stagingPassword,
        );
        debugPrint('[FirebaseAuthBridge] signed in $email');
        return true;
      } on FirebaseAuthException catch (e) {
        // 계정 없음 / 자격 증명 오류 → 생성 후 재시도
        if (e.code == 'user-not-found' ||
            e.code == 'invalid-credential' ||
            e.code == 'wrong-password' ||
            e.code == 'INVALID_LOGIN_CREDENTIALS') {
          try {
            final cred = await auth.createUserWithEmailAndPassword(
              email: email,
              password: stagingPassword,
            );
            await cred.user?.updateDisplayName(user.name);
            debugPrint('[FirebaseAuthBridge] created+signed $email');
            return true;
          } on FirebaseAuthException catch (createErr) {
            if (createErr.code == 'email-already-in-use') {
              await auth.signInWithEmailAndPassword(
                email: email,
                password: stagingPassword,
              );
              debugPrint('[FirebaseAuthBridge] signed in existing $email');
              return true;
            }
            debugPrint(
                '[FirebaseAuthBridge] create failed: ${createErr.code} ${createErr.message}');
            return false;
          }
        }
        debugPrint(
            '[FirebaseAuthBridge] signIn failed: ${e.code} ${e.message}');
        return false;
      }
    } catch (e, st) {
      debugPrint('[FirebaseAuthBridge] ensureSignedIn error: $e\n$st');
      return false;
    }
  }

  static Future<void> signOut() async {
    if (RuntimeMode.useOfflineMock) return;
    try {
      await FirebaseAuth.instance.signOut();
      debugPrint('[FirebaseAuthBridge] signed out');
    } catch (e) {
      debugPrint('[FirebaseAuthBridge] signOut skip: $e');
    }
  }

  static String? get currentUid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }
}
