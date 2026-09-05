import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// 사용자가 원본을 줄일 필요 없이, 앱이 업로드용 JPEG로 맞춘다.
///
/// 원클럽(`oneclub/lib/services/photo_compress_service.dart`)과 같은 구현이다.
/// 라운더에는 장수 제한·압축이 아예 없어서
/// ① 20장이 넘어도 계속 선택됐고
/// ② data URI 가 커지면 `ClubOpsSync.photoDataUriMaxChars` 를 넘겨
///    Firestore 에 이미지가 조용히 빠진 채 올라갔다.
abstract final class PhotoCompressService {
  /// 한 번에 고를 수 있는 최대 장수.
  static const int maxPickCount = 20;

  /// 장당 목표 용량. Firestore 사진 문서(1MB)와
  /// `ClubOpsSync.photoDataUriMaxChars` 안에 넉넉히 들어간다.
  static const int targetBytes = 280 * 1024;

  /// 갤러리에서 여러 장 고른 뒤 압축한다.
  ///
  /// 반환: (압축된 이미지 목록, 20장 초과 여부)
  static Future<(List<Uint8List>, bool)> pickAndCompress() async {
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1280,
      imageQuality: 70,
      requestFullMetadata: false,
      limit: maxPickCount,
    );
    if (picked.isEmpty) return (const <Uint8List>[], false);

    // limit 을 무시하는 피커(구글 포토 등)가 있으므로 여기서 한 번 더 자른다.
    final exceeded = picked.length > maxPickCount;
    final out = <Uint8List>[];
    for (final file in picked.take(maxPickCount)) {
      final raw = await file.readAsBytes();
      if (raw.isEmpty) continue;
      out.add(await compress(raw));
    }
    return (out, exceeded);
  }

  static Future<Uint8List> compress(Uint8List bytes) async {
    var out = bytes;
    if (out.lengthInBytes <= targetBytes) return out;
    if (kIsWeb) return out;

    var quality = 70;
    var minWidth = 1280;
    for (var i = 0; i < 4; i++) {
      if (out.lengthInBytes <= targetBytes) return out;
      try {
        final next = await FlutterImageCompress.compressWithList(
          out,
          minWidth: minWidth,
          minHeight: 1,
          quality: quality,
          format: CompressFormat.jpeg,
        );
        if (next.isEmpty) break;
        out = Uint8List.fromList(next);
      } catch (e) {
        debugPrint('[PhotoCompress] $e');
        break;
      }
      quality = (quality - 15).clamp(35, 70);
      minWidth = (minWidth * 0.85).round().clamp(640, 1280);
    }
    return out;
  }
}
