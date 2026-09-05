import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/services/club_ops_sync.dart';
import 'package:golf_rounder/services/photo_compress_service.dart';

/// 사진 20장 제한 회귀 테스트.
///
/// 배경: "아까는 20장에서 얼럿이 나왔는데 왜 또 20장 넘어도 계속 선택되냐"
/// 실제로 라운더에는 장수 제한이 **아예 없었다** — limit 인자도, 잘라내기도,
/// 얼럿도 없었다. 원클럽(잘 동작하는 쪽) 구현을 그대로 옮겼다.
///
/// 이 테스트는 소스 불변식을 검사한다. 갤러리 선택은 기기 UI 라
/// 유닛 테스트로 실제 선택을 재현할 수 없기 때문이다.
void main() {
  String read(String relative) =>
      File(relative).readAsStringSync().replaceAll('\r\n', '\n');

  group('사진은 한 번에 20장까지', () {
    test('최대 장수는 20이고 압축 목표는 Firestore 한도 안이다', () {
      expect(PhotoCompressService.maxPickCount, 20);

      // 압축 목표(280KB)를 base64 로 부풀려도(약 4/3배)
      // ClubOpsSync 가 이미지를 버리는 기준보다 작아야 한다.
      final base64Bytes = (PhotoCompressService.targetBytes * 4 / 3).ceil();
      expect(base64Bytes, lessThan(ClubOpsSync.photoDataUriMaxChars),
          reason: '압축 후에도 한도를 넘으면 Firestore 에 이미지가 조용히 빠진다');
    });

    test('picker 에 limit 을 넘기고, 넘겨받은 뒤에도 한 번 더 자른다', () {
      final src = read('lib/services/photo_compress_service.dart');

      expect(src, contains('limit: maxPickCount'),
          reason: 'limit 을 안 주면 피커가 무제한으로 고르게 한다');
      expect(src, contains('picked.length > maxPickCount'),
          reason: '초과 여부를 호출부에 알려 얼럿을 띄워야 한다');
      expect(src, contains('picked.take(maxPickCount)'),
          reason: 'limit 을 무시하는 피커(구글 포토)가 있으므로 직접 자른다');
    });

    test('안드로이드 시스템 포토 피커를 강제한다', () {
      // 구글 포토 앱은 limit 을 무시한다. 이 설정이 없으면 제한이 안 걸린다.
      final src = read('lib/main.dart');

      expect(src, contains('useAndroidPhotoPicker = true'));
      expect(src, contains('configureAndroidPhotoPicker()'),
          reason: 'main 에서 실제로 호출해야 효과가 있다');
      expect(src, contains('ImagePickerAndroid'));
    });

    test('선택 함수가 초과 여부를 함께 돌려준다', () {
      final src = read('lib/screens/schedule/round_photo_widgets.dart');

      expect(src, contains('Future<(List<String>, bool)> pickRoundPhotoDataUrls'),
          reason: '초과 여부를 못 돌려주면 호출부가 얼럿을 띄울 수 없다');
      expect(src, contains('PhotoCompressService.pickAndCompress'),
          reason: '압축 없이 원본을 base64 하면 문서 한도를 넘는다');
      expect(src, contains('showRoundPhotoLimitAlert'));
      expect(src, contains('한 번에 \$roundPhotoMaxPickCount장까지 선택할 수 있습니다'));
    });

    test('여러 장 선택 호출부는 모두 초과 여부를 처리한다', () {
      // 한 곳만 고치면 다른 화면에서 또 무제한으로 선택된다.
      const sites = [
        'lib/screens/schedule/round_photo_widgets.dart',
        'lib/screens/schedule/schedule_screen.dart',
      ];

      for (final path in sites) {
        final src = read(path);
        var handled = 0;

        for (var i = src.indexOf('pickRoundPhotoDataUrls()');
            i >= 0;
            i = src.indexOf('pickRoundPhotoDataUrls()', i + 1)) {
          // 선언부와 단일 사진 헬퍼(`final (list, _) =`)는 제외한다.
          final lineStart = src.lastIndexOf('\n', i) + 1;
          final line = src.substring(lineStart, i);
          if (line.contains('Future<(List<String>, bool)> ')) continue;
          if (line.contains('(list, _) = await ')) continue;

          expect(line, contains('exceeded'),
              reason: '$path 이 초과 여부를 버리면 조용히 20장만 들어간다');
          final window = src.substring(i, (i + 600).clamp(0, src.length));
          expect(window, contains('showRoundPhotoLimitAlert'),
              reason: '$path 에서 사용자에게 알려야 한다');
          handled++;
        }

        expect(handled, greaterThan(0),
            reason: '$path 에 여러 장 선택 호출이 있어야 한다');
      }
    });

    test('pickMultiImage 를 직접 부르는 곳은 압축 서비스뿐이다', () {
      // 다른 곳에서 직접 부르면 제한이 또 새어 나간다.
      final dir = Directory('lib');
      final offenders = <String>[];
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        if (f.path.replaceAll('\\', '/').endsWith(
            'lib/services/photo_compress_service.dart')) {
          continue;
        }
        if (f.readAsStringSync().contains('.pickMultiImage(')) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty,
          reason: '여러 장 선택은 PhotoCompressService 를 거쳐야 한다');
    });
  });
}
