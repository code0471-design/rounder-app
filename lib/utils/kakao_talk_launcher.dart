import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// 밴드처럼 OS **텍스트 공유** 시트를 연다.
/// 카카오톡을 고르면 카톡에서 친구/채팅을 선택할 수 있다.
Future<bool> shareInviteText({
  required String message,
  String subject = 'ROUNDER 초대장',
}) async {
  final text = message.trim();
  if (text.isEmpty) return false;
  try {
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: subject,
        title: subject,
      ),
    );
    return true;
  } catch (e) {
    debugPrint('[shareInviteText] fail: $e');
    return false;
  }
}
