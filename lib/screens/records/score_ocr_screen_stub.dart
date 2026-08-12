// 앱(Android/iOS) 전용: image_picker로 이미지 선택
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickResult {
  final Uint8List bytes;
  final String mimeType;
  const ImagePickResult({required this.bytes, required this.mimeType});
}

Future<ImagePickResult?> pickImageBytes({bool fromCamera = false}) async {
  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    final ext = picked.path.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

    return ImagePickResult(bytes: bytes, mimeType: mimeType);
  } catch (e) {
    if (kDebugMode) debugPrint('image_picker error: $e');
    return null;
  }
}
