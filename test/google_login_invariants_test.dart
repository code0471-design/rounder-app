import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// App Store 2.1(a): 구글 버튼이 네이티브 GIDClientID 와 다른
/// 클라이언트 ID 로 초기화되면 아이폰·아이패드에서 로그인이 안 된다.
void main() {
  String read(String path) => File(path).readAsStringSync();

  String? plistValue(String text, String key) {
    return RegExp('<key>$key</key>\\s*<string>([^<]*)</string>')
        .firstMatch(text)
        ?.group(1);
  }

  test('운영 Info.plist 구글 ID 는 env.json 과 같다', () {
    final manifest = jsonDecode(read('firebase_config/prod/env.json'))
        as Map<String, dynamic>;
    final plist = read('ios/Runner/Info.plist');
    expect(
      plistValue(plist, 'GIDClientID'),
      manifest['googleIosClientId'],
    );
    expect(
      plistValue(plist, 'GIDServerClientID'),
      manifest['googleServerClientId'],
    );
    final reversed =
        'com.googleusercontent.apps.${(manifest['googleIosClientId'] as String).replaceAll('.apps.googleusercontent.com', '')}';
    expect(plist, contains(reversed));
  });

  test('스토어 빌드는 APP_ENV 에 맞는 구글 클라이언트 ID 를 쓴다', () {
    final config = read('lib/core/config/social_auth_config.dart');
    expect(config, contains('AppEnv.isProd'));
    expect(
      config,
      contains('399890870575-a6otilvplbdlsh1ulhlnsmkqlp0983ke'),
      reason: '운영 구글 iOS 클라이언트',
    );
    expect(
      config.contains("defaultValue:\n        '909216389322-"),
      isFalse,
      reason: 'dart-define 기본값을 스테이징으로 두면 스토어 빌드 구글 버튼이 죽는다',
    );
  });

  test('아이폰·아이패드는 Info.plist GIDClientID 로 구글을 연다', () {
    final auth = read('lib/services/social_auth_service.dart');
    expect(auth, contains('usePlistClient'));
    expect(auth, contains('TargetPlatform.iOS'));
    expect(auth, contains('clientId: usePlistClient ? null'));
    expect(auth, contains("authenticate(scopeHint: const ['email', 'profile'])"));
  });

  test('Codemagic 솔라피 define 파일에 구글 클라이언트 ID 도 넣는다', () {
    final script = read('tool/write_solapi_defines.py');
    expect(script, contains('GOOGLE_IOS_CLIENT_ID'));
    expect(script, contains('GOOGLE_SERVER_CLIENT_ID'));
    expect(script, contains('googleIosClientId'));
    expect(script, contains('firebase_config'));
  });
}
