// ════════════════════════════════════════════════════════════
//  SolapiService — SOLAPI 알림톡/문자 (어드민 발송용)
//  Key는 --dart-define 또는 추후 .env 연동. 미설정 시 발송 차단.
// ════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SolapiResult {
  final bool success;
  final String? groupId;
  final int requestedCount;
  final int failedCount;
  final String? errorMessage;

  const SolapiResult({
    required this.success,
    this.groupId,
    this.requestedCount = 0,
    this.failedCount = 0,
    this.errorMessage,
  });

  factory SolapiResult.error(String message) =>
      SolapiResult(success: false, errorMessage: message, failedCount: 1);
}

class SolapiService {
  SolapiService._();
  static final SolapiService instance = SolapiService._();

  static const _baseUrl = 'https://api.solapi.com';

  static const _apiKey = String.fromEnvironment('SOLAPI_API_KEY');
  static const _apiSecret = String.fromEnvironment('SOLAPI_API_SECRET');
  static const senderPhone = String.fromEnvironment('SOLAPI_SENDER_PHONE');
  static const kakaoPfId = String.fromEnvironment('SOLAPI_KAKAO_PF_ID');

  bool get isConfigured => _apiKey.isNotEmpty && _apiSecret.isNotEmpty;
  bool get hasSenderPhone => senderPhone.isNotEmpty;
  bool get hasKakaoChannel => kakaoPfId.isNotEmpty;

  static String normalizePhone(String phone) =>
      phone.replaceAll(RegExp(r'[^0-9]'), '');

  String _randomSalt([int length = 32]) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)])
        .join();
  }

  Map<String, String> _authHeaders() {
    final iso = DateTime.now().toUtc().toIso8601String();
    final date = '${iso.split('.').first}Z';
    final salt = _randomSalt();
    final signature = Hmac(sha256, utf8.encode(_apiSecret))
        .convert(utf8.encode('$date$salt'))
        .toString();
    return {
      'Authorization':
          'HMAC-SHA256 apiKey=$_apiKey, date=$date, salt=$salt, signature=$signature',
      'Content-Type': 'application/json',
    };
  }

  Map<String, dynamic> buildSmsMessage({
    required String to,
    required String text,
  }) {
    return {
      'to': normalizePhone(to),
      'from': normalizePhone(senderPhone),
      'text': text,
      'type': text.length > 90 ? 'LMS' : 'SMS',
    };
  }

  Map<String, dynamic> buildAlimtalkMessage({
    required String to,
    required String templateId,
    required Map<String, String> variables,
    String? text,
    String? fallbackText,
  }) {
    return {
      'to': normalizePhone(to),
      'from': normalizePhone(senderPhone),
      'text': text ?? fallbackText ?? '',
      'kakaoOptions': {
        'pfId': kakaoPfId,
        'templateId': templateId,
        'variables': variables,
      },
    };
  }

  Future<SolapiResult> sendManyRaw(List<Map<String, dynamic>> messages) async {
    if (!isConfigured) {
      return SolapiResult.error('SOLAPI API Key가 설정되지 않았습니다.');
    }
    if (!hasSenderPhone) {
      return SolapiResult.error('발신번호(SOLAPI_SENDER_PHONE)가 없습니다.');
    }
    if (messages.isEmpty) {
      return SolapiResult.error('발송 대상이 없습니다.');
    }

    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/messages/v4/send-many/detail'),
        headers: _authHeaders(),
        body: jsonEncode({'messages': messages}),
      );
      final body = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final groupInfo = body is Map ? body['groupInfo'] : null;
        return SolapiResult(
          success: true,
          groupId: groupInfo is Map ? groupInfo['groupId'] as String? : null,
          requestedCount: messages.length,
        );
      }
      debugPrint('[Solapi] send failed: ${res.statusCode} ${res.body}');
      return SolapiResult.error(
        body is Map
            ? (body['errorMessage']?.toString() ?? '발송 실패 (${res.statusCode})')
            : '발송 실패 (${res.statusCode})',
      );
    } catch (e) {
      return SolapiResult.error('발송 오류: $e');
    }
  }
}
