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

  test('컴파일 빌드 번호는 pubspec version +code 와 같다', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final code = int.parse(line.split('+').last.trim());
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

  test('업데이트 안내는 전용 서비스만 쓰고 명단·알림·재무를 건드리지 않는다', () {
    final src =
        File('lib/services/store_update_prompt.dart').readAsStringSync();
    expect(src.contains('업데이트 안내'), isTrue);
    expect(src.contains('새 버전이 있습니다'), isTrue);
    expect(src.contains('FirestorePaths.metaStoreVersion'), isTrue);
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
