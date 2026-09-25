import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/providers/auth_provider.dart';

void main() {
  late String auth;
  late String ad;
  late String sheet;
  late String form;
  late String club;
  late String index;

  setUpAll(() {
    auth = File('lib/providers/auth_provider.dart').readAsStringSync();
    ad = File('lib/screens/ad/ad_screen.dart').readAsStringSync();
    sheet = File('lib/widgets/phone_otp_sheet.dart').readAsStringSync();
    form = File('lib/screens/members/member_form_screen.dart').readAsStringSync();
    club = File('lib/providers/club_provider.dart').readAsStringSync();
    index = File('lib/services/member_phone_index.dart').readAsStringSync();
  });

  test('같은 번호는 인증 없이 두고 다른 번호는 OTP 후에만 저장한다', () {
    expect(AuthProvider.samePhoneDigits('010-4511-0471', '01045110471'), isTrue);
    expect(AuthProvider.samePhoneDigits('010-1111-2222', '010-3333-4444'), isFalse);
    expect(AuthProvider.phoneDigitsOf('010-4062-0830'), '01040620830');

    expect(ad.contains('showPhoneOtpSheet'), isTrue);
    expect(ad.contains('phoneChanged'), isTrue);
    expect(ad.contains('updateAccountProfile'), isTrue);
    expect(ad.contains('phone: phoneChanged ? null : newPhone'), isTrue);
    expect(
      ad.contains('phone: newPhone.isNotEmpty ? newPhone : member.phone'),
      isFalse,
      reason: '인증 없이 phoneCtrl 을 명단에 바로 넣으면 안 된다',
    );
    expect(auth.contains('숫자가 다른 번호는 무시한다'), isTrue);
    expect(auth.contains('Future<AppUser?> updateAccountProfile'), isTrue);
  });

  test('OTP 성공 시에만 계정과 본인 명단을 새 번호로 덮는다', () {
    expect(ad.contains('attachPhoneToCurrentUser'), isTrue);
    expect(auth.contains('assertPhoneFreeForCurrentUser'), isTrue);
    expect(auth.contains('이미 다른 계정에 등록된 전화번호입니다'), isTrue);
    expect(
      auth.contains(
        "if (existing.replaceAll(RegExp(r'[^0-9]'), '').length >= 10) continue;",
      ),
      isFalse,
      reason: '이미 10자리면 skip 하면 번호 변경이 명단에 안 남는다',
    );
    expect(auth.contains('본인 행은 이미 번호가 있어도 덮는다'), isTrue);
    expect(auth.contains('releasePhoneForUser'), isTrue);
  });

  test('마이페이지 OTP 시트는 알림톡이고 PASS UI가 없다', () {
    expect(sheet.contains('카카오 알림톡'), isTrue);
    expect(sheet.contains('이름·휴대폰'), isTrue);
    expect(sheet.contains('PASS'), isTrue);
    expect(sheet.contains('PASS 인증'), isFalse);
    expect(sheet.contains('다날'), isFalse);
    expect(sheet.contains('requestPassVerify'), isFalse);
  });

  test('총무 회원 수정은 연락처만이고 OTP가 없다', () {
    expect(form.contains('showPhoneOtpSheet'), isFalse);
    expect(form.contains('attachPhoneToCurrentUser'), isFalse);
    expect(form.contains('sendSmsCode'), isFalse);
    expect(form.contains('인증번호'), isFalse);
  });

  test('persist는 번호가 있을 때만 normal 로 올린다', () {
    final persist = auth.substring(auth.indexOf('Future<void> _persistPlatformUser'));
    expect(
      persist.contains("if (!isPhoneMissing(user.phone))"),
      isTrue,
    );
    expect(
      persist.contains("data['account_status'] = 'normal';"),
      isTrue,
    );
    final alwaysNormal = persist.split("data = <String, dynamic>{")[1];
    final header = alwaysNormal.split('};').first;
    expect(
      header.contains("'account_status': 'normal'"),
      isFalse,
      reason: '탈퇴 직후 소셜 재로그인이 withdrawn 을 풀면 안 된다',
    );
    expect(auth.contains("if (status == 'withdrawn')"), isTrue);
    expect(auth.contains('withdrawn 이면 members 에서 번호 복원 금지'), isTrue);
  });

  test('탈퇴는 users.phone 과 본인 명단·색인 번호를 비운다', () {
    expect(auth.contains('_wipeOwnRosterPhones'), isTrue);
    expect(auth.contains("'phone': FieldValue.delete()"), isTrue);
    expect(auth.contains("'account_status': 'withdrawn'"), isTrue);
    expect(index.contains('releasePhoneForUser'), isTrue);
    expect(index.contains('isSocialAccountRosterId'), isTrue);
  });

  test('번호로 내 모임을 다시 붙이지 않는다', () {
    expect(club.contains('MemberPhoneIndex.claimForUser('), isFalse);
    expect(auth.contains('user_memberships'), isFalse);
    expect(auth.contains('claimForUser'), isFalse);
  });
}
