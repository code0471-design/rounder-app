import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 회원 사진용 ImageProvider.
///
/// 갤러리에서 고른 사진은 `data:image/jpeg;base64,...` 형태로 저장된다.
/// `NetworkImage` 는 http/https 만 처리하므로 data URI 를 넘기면 조용히 실패해
/// 빈 아바타가 된다. (편집 시트에서는 보이는데 저장하면 사라지던 원인)
///
/// 사진이 없거나 형식이 깨져 있으면 null — 호출부는 이니셜을 그린다.
ImageProvider? avatarImage(String? url) {
  final raw = url?.trim() ?? '';
  if (raw.isEmpty) return null;

  if (raw.startsWith('data:')) {
    final comma = raw.indexOf(',');
    if (comma < 0) return null;
    try {
      return MemoryImage(base64Decode(raw.substring(comma + 1)));
    } catch (e) {
      // 잘린 base64 — 이니셜로 떨어뜨린다.
      if (kDebugMode) debugPrint('avatarImage: data URI 디코드 실패 $e');
      return null;
    }
  }

  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    return NetworkImage(raw);
  }
  return null;
}
