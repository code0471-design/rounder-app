import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/services/hq_alimtalk_catalog.dart';
import 'package:golf_rounder/services/solapi_service.dart';

/// 휴대폰 인증은 카카오 알림톡 OTP. PASS UI / 어드민 SMS 대체로 회귀하면 실패.
void main() {
  late String phoneRequired;
  late String verify;
  late String signup;
  late String solapi;
  late String codemagic;

  setUpAll(() {
    phoneRequired =
        File('lib/screens/auth/phone_required_screen.dart').readAsStringSync();
    verify = File('lib/screens/auth/verify_screen.dart').readAsStringSync();
    signup = File('lib/screens/auth/signup_screen.dart').readAsStringSync();
    solapi = File('lib/services/solapi_service.dart').readAsStringSync();
    codemagic = File('codemagic.yaml').readAsStringSync();
  });

  test('번호 수집·인증 화면에 PASS 선택 UI가 없어야 한다', () {
    for (final src in [phoneRequired, verify]) {
      expect(src.contains('PASS 인증'), isFalse);
      expect(src.contains('PASS로 인증'), isFalse);
      expect(src.contains('PASS 앱'), isFalse);
      expect(src.contains('requestPassVerify'), isFalse);
      expect(src.contains('_PassSection'), isFalse);
    }
  });

  test('phone_required는 이름+전화만 수집해야 한다', () {
    expect(phoneRequired.contains("'이름'"), isTrue);
    expect(phoneRequired.contains('이름을 2자 이상'), isTrue);
    expect(phoneRequired.contains('enabled: !_busy && !_codeSent'), isTrue);
    expect(phoneRequired.contains('핸디캡'), isFalse);
    expect(phoneRequired.contains('카카오 알림톡'), isTrue);
  });

  test('가입 다음 단계는 휴대폰 인증(알림톡)이어야 한다', () {
    expect(signup.contains('다음 — 휴대폰 인증'), isTrue);
    expect(signup.contains('다음 — 본인인증'), isFalse);
    expect(verify.contains("'휴대폰 인증'"), isTrue);
  });

  test('App Store Review는 공개 데모 번호+코드만 통과해야 한다', () {
    final auth = File('lib/providers/auth_provider.dart').readAsStringSync();
    expect(auth.contains("appStoreReviewPhoneDigits = '01000000000'"), isTrue);
    expect(auth.contains("appStoreReviewOtp = '0000'"), isTrue);
    expect(auth.contains('isAppStoreReviewPhone'), isTrue);
    expect(auth.contains('if (isAppStoreReviewPhone(phone))'), isTrue);
  });

  test('OTP는 알림톡 우선, 승인된 KA01TP 8종, SMS 대체는 OTP만', () {
    expect(solapi.contains('otpTemplateId'), isTrue);
    expect(solapi.contains('KA01TP260827200825010BAkqpx4TyCt'), isTrue);
    expect(solapi.contains('KA01TP260819165935819h6YMQUQnxD6'), isTrue);
    expect(solapi.contains('KA01TP260819170717941dD6OSJifLZy'), isTrue);
    expect(solapi.contains('KA01TP260819170856743YpkKVjb5WfS'), isTrue);
    expect(solapi.contains('KA01TP260819170942410EzVbYmO06U2'), isTrue);
    expect(solapi.contains('KA01TP2608191713271305WAQ7IzWNzo'), isTrue);
    expect(solapi.contains('KA01TP260819171813223rmS1ByutYaw'), isTrue);
    expect(solapi.contains('KA01TP260819170319298NrCEHKRX6u3'), isTrue);
    expect(solapi.contains('UnnQDOxu0b'), isFalse);
    expect(solapi.contains('templateIdForHqType'), isTrue);
    expect(solapi.contains('templateIdForAdminCatalog'), isTrue);
    expect(solapi.contains("'#{인증번호}'"), isTrue);
    expect(solapi.contains("'#{이름}'"), isTrue);
    expect(solapi.contains("'disableSms': true"), isTrue);
    expect(solapi.contains('sendOtpAlimtalk'), isTrue);
    expect(solapi.contains('[라운더]'), isTrue);
    expect(codemagic.contains('UnnQDOxu0b'), isFalse);
    expect(
      SolapiService.templateIdForHqType(HqAlimtalkCatalog.groupFinalizeId),
      'KA01TP260819170319298NrCEHKRX6u3',
    );
    expect(
      SolapiService.templateIdForHqType(HqAlimtalkCatalog.scheduleUploadId),
      'KA01TP260819165935819h6YMQUQnxD6',
    );
    expect(
      SolapiService.templateIdForAdminCatalog('T010'),
      'KA01TP260819170319298NrCEHKRX6u3',
    );
  });
}
