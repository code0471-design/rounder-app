import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('아이패드 Apple 로그인에 창 기준이 있다', () {
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(appDelegate, contains('ASAuthorizationControllerPresentationContextProviding'));
    expect(appDelegate, contains('presentationContextProvider'));
    expect(appDelegate, contains('rounderInstallIPadAnchor'));
  });

  test('Apple 로그인 실패는 화면 오류로 바뀐다', () {
    final auth = File('lib/services/social_auth_service.dart').readAsStringSync();
    expect(auth, contains('on SignInWithAppleAuthorizationException'));
    expect(auth, contains('AuthorizationErrorCode.canceled'));
  });

  test('Apple 세션을 스테이징 계정으로 바꾸지 않는다', () {
    final bridge = File('lib/services/firebase_auth_bridge.dart').readAsStringSync();
    expect(bridge, contains('keep oauth session'));
    expect(bridge, contains("@staging.rounder.app"));
  });
}
