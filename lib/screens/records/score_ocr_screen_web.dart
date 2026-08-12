// 웹 전용: HTML input[file]로 이미지 선택
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class ImagePickResult {
  final Uint8List bytes;
  final String mimeType;
  const ImagePickResult({required this.bytes, required this.mimeType});
}

Future<ImagePickResult?> pickImageBytes({bool fromCamera = false}) async {
  final completer = Completer<ImagePickResult?>();

  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false;

  if (fromCamera) {
    input.setAttribute('capture', 'environment');
  }

  input.onChange.listen((_) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }
    final file = files[0];
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    reader.onLoad.listen((_) {
      final result = reader.result as List<int>;
      final bytes = Uint8List.fromList(result);
      completer.complete(ImagePickResult(
        bytes: bytes,
        mimeType: file.type.isNotEmpty ? file.type : 'image/jpeg',
      ));
    });
    reader.onError.listen((_) => completer.complete(null));
  });

  input.click();

  // 취소한 경우 3초 후 null 반환
  Future.delayed(const Duration(seconds: 30), () {
    if (!completer.isCompleted) completer.complete(null);
  });

  return completer.future;
}
