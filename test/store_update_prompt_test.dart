import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/services/store_update_prompt.dart';

void main() {
  test('설치된 빌드보다 스토어 빌드가 높을 때만 안내한다', () {
    expect(
      storeUpdateIsAvailable(installedBuild: 215, latestBuild: 216),
      isTrue,
    );
    expect(
      storeUpdateIsAvailable(installedBuild: 215, latestBuild: 215),
      isFalse,
    );
    expect(
      storeUpdateIsAvailable(installedBuild: 215, latestBuild: 214),
      isFalse,
    );
    expect(
      storeUpdateIsAvailable(installedBuild: 0, latestBuild: 216),
      isFalse,
    );
  });

  test('스토어 버전 이름이 같으면 서버 빌드가 높아도 안내하지 않는다', () {
    expect(
      storeUpdateNeeded(
        installedVersion: '1.0.4',
        installedBuild: 227,
        storeVersion: '1.0.4',
        remoteBuild: 999,
      ),
      isFalse,
    );
    expect(
      storeUpdateNeeded(
        installedVersion: '1.0.4',
        installedBuild: 227,
        storeVersion: '1.0.3',
        remoteBuild: 999,
      ),
      isFalse,
    );
    expect(
      storeUpdateNeeded(
        installedVersion: '1.0.4',
        installedBuild: 227,
        storeVersion: '1.0.5',
        remoteBuild: null,
      ),
      isTrue,
    );
    expect(
      storeUpdateNeeded(
        installedVersion: '1.0.4',
        installedBuild: 227,
        storeVersion: null,
        remoteBuild: 228,
      ),
      isTrue,
    );
    expect(
      storeUpdateNeeded(
        installedVersion: '1.0.4',
        installedBuild: 227,
        storeVersion: '  ',
        remoteBuild: 227,
      ),
      isFalse,
    );
  });

  test('스토어 버전 이름이 더 높으면 안내한다', () {
    expect(
      storeVersionNameIsNewer(installed: '1.0.2', store: '1.0.3'),
      isTrue,
    );
    expect(
      storeVersionNameIsNewer(installed: '1.0.3', store: '1.0.3'),
      isFalse,
    );
    expect(
      storeVersionNameIsNewer(installed: '1.0.3', store: '1.0.2'),
      isFalse,
    );
  });

  test('Play HTML과 App Store lookup에서 버전 이름을 읽는다', () {
    expect(
      parsePlayStoreVersionName(r'''"141":[[["1.0.3"]]],"145":[]'''),
      '1.0.3',
    );
    expect(
      parsePlayStoreVersionName(r'''\"141\":[[[\"1.0.3\"]]]'''),
      '1.0.3',
    );
    expect(
      parseIosLookupVersion(
        '{"resultCount":1,"results":[{"version":"1.0.3","trackId":1}]}',
      ),
      '1.0.3',
    );
  });

  test('깔린 빌드 버전이 있으면 그 버전으로 안다', () {
    final fromPackage = storeInstalledIdentity(
      packageVersion: '1.0.4',
      packageBuild: '227',
    );
    expect(fromPackage.version, '1.0.4');
    expect(fromPackage.build, 227);
    expect(
      storeUpdateNeeded(
        installedVersion: fromPackage.version,
        installedBuild: fromPackage.build,
        storeVersion: '1.0.4',
        remoteBuild: 999,
      ),
      isFalse,
    );
    final fallback = storeInstalledIdentity(packageVersion: '', packageBuild: '');
    expect(fallback.version, kStoreUpdateInstalledVersion);
    expect(fallback.build, kStoreUpdateInstalledBuild);
  });

  test('컴파일 버전은 pubspec version 과 같다', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final spec = line.substring('version:'.length).trim();
    final name = spec.split('+').first;
    final code = int.parse(spec.split('+').last);
    expect(kStoreUpdateInstalledVersion, name);
    expect(kStoreUpdateInstalledBuild, code);
  });

  test('안드로이드·iOS 빌드 키를 섞지 않는다', () {
    expect(storeUpdateBuildKey(ios: false), 'androidBuild');
    expect(storeUpdateBuildKey(ios: true), 'iosBuild');
    expect(
      storeUpdateBuildFromData({'androidBuild': 216, 'iosBuild': 210},
          ios: false),
      216,
    );
    expect(
      storeUpdateBuildFromData({'androidBuild': 216, 'iosBuild': 210},
          ios: true),
      210,
    );
  });

  test('업데이트 안내는 스토어를 보고, 지금 빌드를 최신으로 덮지 않는다', () {
    final src =
        File('lib/services/store_update_prompt.dart').readAsStringSync();
    expect(src.contains('업데이트 안내'), isTrue);
    expect(src.contains('새 버전이 있습니다'), isTrue);
    expect(src.contains('itunes.apple.com/lookup'), isTrue);
    expect(src.contains('InviteLinks.playStore'), isTrue);
    expect(src.contains('FirestorePaths.metaStoreVersion'), isTrue);
    expect(src.contains('_readRemoteBuild'), isTrue);
    expect(src.contains('PackageInfo.fromPlatform'), isTrue);
    expect(src.contains('storeInstalledIdentity'), isTrue);
    expect(src.contains('SetOptions(merge: true)'), isFalse,
        reason: '지금 깔린 빌드를 최신으로 쓰면 스토어 업데이트가 있어도 안내가 안 뜬다');
    expect(src.contains('club_ops_sync'), isFalse);
    expect(src.contains('ClubProvider'), isFalse);
    expect(src.contains('duesPayments'), isFalse);
    expect(src.contains('d1_queue'), isFalse);

    final app = File('lib/app/rounder_app.dart').readAsStringSync();
    expect(app.contains('StoreUpdatePrompt.scheduleAfterLaunch'), isTrue);

    final provider = File('lib/providers/club_provider.dart').readAsStringSync();
    expect(provider.contains('StoreUpdatePrompt'), isFalse);
  });
}
