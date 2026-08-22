import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:url_launcher/url_launcher.dart';

/// 카카오톡 **공유(친구/채팅 선택)** 화면을 연다.
///
/// `kakaotalk://` 로 앱만 띄우면 채팅 목록만 열리고 대상을 고를 수 없다.
/// ShareClient는 카톡의 공유 대상 선택 UI를 연다 (친구·단톡 1곳).
/// 여러 개인에게 한 번에 보내려면 카카오 메시지 API·친구목록 권한이 따로 필요하다.
Future<KakaoInviteShareResult> shareInviteViaKakaoTalk({
  required String clubName,
  required String message,
  required String webUrl,
  String buttonTitle = '초대 확인하기',
}) async {
  final linkUri = Uri.tryParse(webUrl) ?? Uri.parse('https://rounder.app');
  final text = _clipText(message, 200);
  final template = TextTemplate(
    text: text.isEmpty ? '[ROUNDER] $clubName 모임에 초대합니다.' : text,
    link: Link(
      webUrl: linkUri,
      mobileWebUrl: linkUri,
    ),
    buttonTitle: buttonTitle,
  );

  try {
    final available =
        await ShareClient.instance.isKakaoTalkSharingAvailable();
    if (available) {
      final uri =
          await ShareClient.instance.shareDefault(template: template);
      await ShareClient.instance.launchKakaoTalk(uri);
      return KakaoInviteShareResult.openedPicker;
    }

    // 미설치 → 웹 공유
    final shareUrl =
        await WebSharerClient.instance.makeDefaultUrl(template: template);
    final ok = await launchUrl(shareUrl, mode: LaunchMode.externalApplication);
    return ok
        ? KakaoInviteShareResult.openedWebShare
        : KakaoInviteShareResult.failed;
  } catch (e) {
    debugPrint('[shareInviteViaKakaoTalk] fail: $e');
    // 공유 실패 시 예전처럼 앱만 열어 붙여넣기 가능하게
    final fallback = await openKakaoTalkApp();
    return fallback
        ? KakaoInviteShareResult.openedAppOnly
        : KakaoInviteShareResult.failed;
  }
}

enum KakaoInviteShareResult {
  openedPicker,
  openedWebShare,
  openedAppOnly,
  failed,
}

String _clipText(String raw, int max) {
  final t = raw.trim();
  if (t.length <= max) return t;
  return '${t.substring(0, max - 1)}…';
}

/// 카카오톡 앱을 연다. (공유 실패 시 붙여넣기용 폴백)
Future<bool> openKakaoTalkApp() async {
  final candidates = <Uri>[
    Uri.parse('kakaotalk://launch'),
    Uri.parse('kakaotalk://'),
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
