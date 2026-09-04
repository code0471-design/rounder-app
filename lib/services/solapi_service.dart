// ════════════════════════════════════════════════════════════
//  SolapiService — SOLAPI 알림톡 (어드민 발송용)
//  어드민 알림톡: 실패 시 문자 대체 없음 (disableSms: true).
//  가입 OTP만: 알림톡 실패 시 등록 발신번호로 SMS 대체.
//  Key는 --dart-define. 미설정 시 발송 차단.
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

  /// OTP 알림톡 실패 시 SMS 발신번호 (솔라피 사전등록). 기본: 01045110471
  static const senderPhone = String.fromEnvironment(
    'SOLAPI_SENDER_PHONE',
    defaultValue: '01045110471',
  );
  static const kakaoPfId = String.fromEnvironment(
    'SOLAPI_KAKAO_PF_ID',
    defaultValue: 'KA01PF260819163601284VyeVGcfZZWg',
  );

  /// 휴대폰 인증번호 알림톡 템플릿 ID (솔라피 콘솔, 2026-09-04 승인)
  /// 템플릿 변수명: #{인증번호}, #{이름}
  static const otpTemplateId = String.fromEnvironment(
    'SOLAPI_OTP_TEMPLATE_ID',
    defaultValue: 'KA01TP260827200825010BAkqpx4TyCt',
  );
  static const scheduleUploadTemplateId = String.fromEnvironment(
    'SOLAPI_TEMPLATE_ID_SCHEDULE_UPLOAD',
    defaultValue: 'KA01TP260819165935819h6YMQUQnxD6',
  );
  static const scheduleChangeTemplateId = String.fromEnvironment(
    'SOLAPI_TEMPLATE_ID_SCHEDULE_CHANGE',
    defaultValue: 'KA01TP260819170717941dD6OSJifLZy',
  );
  static const d1ReminderTemplateId = String.fromEnvironment(
    'SOLAPI_TEMPLATE_ID_D1',
    defaultValue: 'KA01TP260819170856743YpkKVjb5WfS',
  );
  static const scheduleCancelTemplateId = String.fromEnvironment(
    'SOLAPI_TEMPLATE_ID_SCHEDULE_CANCEL',
    defaultValue: 'KA01TP260819170942410EzVbYmO06U2',
  );
  static const duesNudgeTemplateId = String.fromEnvironment(
    'SOLAPI_TEMPLATE_ID_DUES_NUDGE',
    defaultValue: 'KA01TP2608191713271305WAQ7IzWNzo',
  );
  static const duesRequestTemplateId = String.fromEnvironment(
    'SOLAPI_TEMPLATE_ID_DUES_REQUEST',
    defaultValue: 'KA01TP260819171813223rmS1ByutYaw',
  );
  static const groupFinalizeTemplateId = String.fromEnvironment(
    'SOLAPI_TEMPLATE_ID_GROUP_FINALIZE',
    defaultValue: 'KA01TP260819170319298NrCEHKRX6u3',
  );

  /// 어드민 본사 발송 카탈로그 id (T003…) → 솔라피 템플릿 ID
  static String? templateIdForAdminCatalog(String catalogId) =>
      switch (catalogId) {
        'T003' => scheduleUploadTemplateId,
        'T004' => d1ReminderTemplateId,
        'T005' => duesRequestTemplateId,
        'T006' => scheduleCancelTemplateId,
        'T008' => duesNudgeTemplateId,
        'T009' => scheduleChangeTemplateId,
        'T010' => groupFinalizeTemplateId,
        _ => null,
      };

  /// 모임 자동 알림톡 종류 id (atk_…) → 솔라피 템플릿 ID
  static String? templateIdForHqType(String hqTypeId) =>
      switch (hqTypeId) {
        'atk_schedule_upload' => scheduleUploadTemplateId,
        'atk_schedule_change' => scheduleChangeTemplateId,
        'atk_d1_reminder' => d1ReminderTemplateId,
        'atk_schedule_cancel' => scheduleCancelTemplateId,
        'atk_dues_request' => duesRequestTemplateId,
        'atk_dues_nudge' => duesNudgeTemplateId,
        'atk_group_finalize' => groupFinalizeTemplateId,
        _ => null,
      };

  bool get isConfigured => _apiKey.isNotEmpty && _apiSecret.isNotEmpty;
  bool get hasSenderPhone => normalizePhone(senderPhone).isNotEmpty;
  bool get hasKakaoChannel => kakaoPfId.isNotEmpty;
  bool get hasOtpTemplate => otpTemplateId.trim().isNotEmpty;

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

  /// 어드민 등 일반 알림톡 — 문자 대체 없음.
  Map<String, dynamic> buildAlimtalkMessage({
    required String to,
    required String templateId,
    required Map<String, String> variables,
    String? text,
  }) {
    return {
      'to': normalizePhone(to),
      if (text != null && text.isNotEmpty) 'text': text,
      'kakaoOptions': {
        'pfId': kakaoPfId,
        'templateId': templateId,
        'variables': variables,
        'disableSms': true,
      },
    };
  }

  /// 가입·번호 등록 OTP: 알림톡 우선, 실패 시 SMS(등록 발신번호).
  Future<SolapiResult> sendOtpAlimtalk({
    required String to,
    required String code,
    String? name,
  }) async {
    if (!isConfigured) {
      return SolapiResult.error('SOLAPI API Key가 설정되지 않았습니다.');
    }
    if (!hasKakaoChannel) {
      return SolapiResult.error('카카오 채널(PFID)이 설정되지 않았습니다.');
    }
    if (!hasOtpTemplate) {
      return SolapiResult.error(
        '인증번호 알림톡 템플릿(SOLAPI_OTP_TEMPLATE_ID)이 없습니다.',
      );
    }

    final displayName = (name ?? '').trim();
    final smsText = displayName.isEmpty
        ? '[라운더] 인증번호는 $code 입니다. 3분 내에 입력해 주세요.'
        : '[라운더] $displayName님 인증번호는 $code 입니다. 3분 내에 입력해 주세요.';
    final allowSmsFallback = hasSenderPhone;
    final variables = <String, String>{
      '#{인증번호}': code,
      if (displayName.isNotEmpty) '#{이름}': displayName,
    };
    final message = <String, dynamic>{
      'to': normalizePhone(to),
      'text': smsText,
      if (allowSmsFallback) 'from': normalizePhone(senderPhone),
      'kakaoOptions': {
        'pfId': kakaoPfId,
        'templateId': otpTemplateId.trim(),
        'variables': variables,
        // OTP만: 카톡 미연동 등 알림톡 실패 시 SMS 대체
        'disableSms': !allowSmsFallback,
      },
    };
    return sendManyRaw([message]);
  }

  Future<SolapiResult> sendManyRaw(List<Map<String, dynamic>> messages) async {
    if (!isConfigured) {
      return SolapiResult.error('SOLAPI API Key가 설정되지 않았습니다.');
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
