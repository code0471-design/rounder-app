import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// 카카오톡 앱을 연다. (초대 메시지 붙여넣기용)
///
/// `canLaunchUrl`은 Android 11+에서 쿼리 미등록 시 false를 자주 내므로
/// 바로 `launchUrl`을 시도한다.
Future<bool> openKakaoTalkApp() async {
  final candidates = <Uri>[
    Uri.parse('kakaotalk://launch'),
    Uri.parse('kakaotalk://'),
    // Android intent fallback
    if (defaultTargetPlatform == TargetPlatform.android)
      Uri.parse(
        'intent://#Intent;scheme=kakaotalk;package=com.kakao.talk;end',
      ),
  ];
  for (final uri in candidates) {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return true;
    } catch (e) {
      debugPrint('[openKakaoTalkApp] $uri fail: $e');
    }
  }
  // 미설치 시 스토어로
  final store = Uri.parse(
    defaultTargetPlatform == TargetPlatform.iOS
        ? 'https://apps.apple.com/app/id362057947'
        : 'https://play.google.com/store/apps/details?id=com.kakao.talk',
  );
  try {
    return await launchUrl(store, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('[openKakaoTalkApp] store fail: $e');
    return false;
  }
}
