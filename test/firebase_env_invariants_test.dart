import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/core/config/app_environment.dart';

/// 운영 전환 사고 방지용 불변식.
///
/// 여기서 깨지면 "운영 빌드가 스테이징에 쓴다" 같은 사고로 이어진다.
void main() {
  const stagingId = 'rounder-staging';
  const prodId = 'rounder-f6019';

  String read(String path) => File(path).readAsStringSync();

  Map<String, dynamic> readJson(String path) =>
      jsonDecode(read(path)) as Map<String, dynamic>;

  /// plist 에서 <key>K</key><string>V</string> 추출
  String? plistValue(String text, String key) {
    final m = RegExp('<key>$key</key>\\s*<string>([^<]*)</string>')
        .firstMatch(text);
    return m?.group(1);
  }

  group('AppEnv', () {
    test('dart-define 없으면 스테이징이 기본', () {
      expect(AppEnv.rawValue, 'staging');
      expect(AppEnv.isStaging, isTrue);
      expect(AppEnv.isProd, isFalse);
      expect(AppEnv.isRecognized, isTrue);
      expect(AppEnv.expectedProjectId, stagingId);
    });

    test('프로젝트 ID 상수가 실제 Firebase 프로젝트와 일치', () {
      expect(AppEnv.stagingProjectId, stagingId);
      expect(AppEnv.prodProjectId, prodId);
    });
  });

  group('firebase_config 설정 파일', () {
    for (final entry in const {
      'staging': stagingId,
      'prod': prodId,
    }.entries) {
      final env = entry.key;
      final expectedId = entry.value;

      test('$env — env.json / google-services.json / plist 의 프로젝트가 같다', () {
        final manifest = readJson('firebase_config/$env/env.json');
        expect(manifest['projectId'], expectedId);

        final gs = readJson('firebase_config/$env/google-services.json');
        expect(
          (gs['project_info'] as Map)['project_id'],
          expectedId,
          reason: '$env google-services.json 이 다른 프로젝트를 가리킨다',
        );

        final plist = read('firebase_config/$env/GoogleService-Info.plist');
        expect(
          plistValue(plist, 'PROJECT_ID'),
          expectedId,
          reason: '$env GoogleService-Info.plist 가 다른 프로젝트를 가리킨다',
        );
        expect(
          plistValue(plist, 'BUNDLE_ID'),
          'com.golfrounder.golfRounder',
          reason: 'iOS 번들 ID 가 바뀌면 심사 통과한 앱과 달라진다',
        );
      });
    }

    test('운영 설정에 스테이징 프로젝트 번호가 섞여 있지 않다', () {
      for (final f in [
        'firebase_config/prod/env.json',
        'firebase_config/prod/google-services.json',
        'firebase_config/prod/GoogleService-Info.plist',
      ]) {
        expect(
          read(f).contains('909216389322'),
          isFalse,
          reason: '$f 에 스테이징 프로젝트 번호가 남아 있다',
        );
        expect(read(f).contains(stagingId), isFalse, reason: '$f');
      }
    });

    test('적용된 네이티브 설정은 Android·iOS 가 같은 프로젝트를 본다', () {
      final androidId = (readJson('android/app/google-services.json')
          ['project_info'] as Map)['project_id'];
      final iosId = plistValue(
        read('ios/Runner/GoogleService-Info.plist'),
        'PROJECT_ID',
      );
      expect(
        androidId,
        iosId,
        reason: 'select_firebase_env.js 가 반쯤 적용된 상태 — 한쪽만 운영을 본다',
      );
    });
  });

  group('firebase_options.dart', () {
    final src = read('lib/firebase_options.dart');

    test('두 환경을 모두 담고 APP_ENV 로 고른다', () {
      expect(src.contains(stagingId), isTrue);
      expect(src.contains(prodId), isTrue);
      expect(
        src.contains('AppEnv.isProd'),
        isTrue,
        reason: '환경 분기 없이 한쪽으로 고정되면 운영 전환이 불가능하다',
      );
    });

    test('운영 옵션이 스테이징 프로젝트 번호를 쓰지 않는다', () {
      final prodBlock =
          src.substring(src.indexOf('abstract final class _ProdOptions'));
      expect(prodBlock.contains('909216389322'), isFalse);
      expect(prodBlock.contains(stagingId), isFalse);
    });
  });

  group('codemagic.yaml', () {
    final yaml = read('codemagic.yaml');

    test('모든 flutter build 에 APP_ENV dart-define 이 붙는다', () {
      // 쉘 줄바꿈(\) 으로 이어진 명령을 한 줄로 합친 뒤 검사
      final joined = <String>[];
      for (final raw in yaml.split(RegExp(r'\r?\n'))) {
        final line = raw.trim();
        if (joined.isNotEmpty && joined.last.endsWith(r'\')) {
          joined[joined.length - 1] =
              '${joined.last.substring(0, joined.last.length - 1).trim()} $line';
        } else {
          joined.add(line);
        }
      }

      final builds =
          joined.where((l) => l.contains('flutter build ')).toList();
      expect(
        builds.length,
        greaterThanOrEqualTo(4),
        reason: 'ios-first(2) + apk(1) + aab(1)',
      );

      for (final cmd in builds) {
        expect(
          cmd.contains('--dart-define=APP_ENV'),
          isTrue,
          reason: 'APP_ENV 를 안 넘기면 Dart 쪽이 항상 스테이징을 본다:\n$cmd',
        );
      }
    });

    test('모든 워크플로가 환경 선택 스크립트를 먼저 돌린다', () {
      final workflows = RegExp(r'^  ([a-z0-9-]+):\s*$', multiLine: true)
          .allMatches(yaml)
          .map((m) => m.group(1)!)
          .toList();
      expect(workflows.length, greaterThanOrEqualTo(3));

      for (var i = 0; i < workflows.length; i++) {
        final start = yaml.indexOf('  ${workflows[i]}:');
        final end = i + 1 < workflows.length
            ? yaml.indexOf('  ${workflows[i + 1]}:')
            : yaml.length;
        final block = yaml.substring(start, end);
        expect(
          block.contains('select_firebase_env.js'),
          isTrue,
          reason: '${workflows[i]} 가 네이티브 설정을 안 바꾸면 APP_ENV 와 어긋난다',
        );
        expect(
          block.contains('APP_ENV: staging'),
          isTrue,
          reason: '${workflows[i]} 의 기본값이 없으면 실수로 운영이 될 수 있다',
        );
      }
    });

    test('빌드 번호는 여전히 pubspec 에서 읽는다', () {
      expect(yaml.contains('--build-number="\$BUILD_NUMBER"'), isTrue);
      expect(
        RegExp(r'--build-number[= ]"?\d').hasMatch(yaml),
        isFalse,
        reason: '빌드 번호 하드코딩은 Play 버전 충돌을 만든다',
      );
    });
  });
}
