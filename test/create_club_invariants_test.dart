import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String relative) => File(relative).readAsStringSync();

void main() {
  group('모임 만들기 토스 7단계', () {
    late String src;
    late String provider;

    setUpAll(() {
      src = _read('lib/screens/clubs/create_club_screen.dart');
      provider = _read('lib/providers/club_provider.dart');
    });

    test('이름 → 이미지 → 지역 → 업종 → 팀수 → 소개 → 직책 순서로 따라간다', () {
      expect(src.contains('_kTotalSteps = 7'), isTrue);
      expect(src.contains('_buildNameStep()'), isTrue);
      expect(src.contains('_buildImageStep()'), isTrue);
      expect(src.contains('_buildRegionStep()'), isTrue);
      expect(src.contains('_buildIndustryStep()'), isTrue);
      expect(src.contains('_buildTeamStep()'), isTrue);
      expect(src.contains('_buildIntroStep()'), isTrue);
      expect(src.contains('return _buildStep2();'), isTrue);
      expect(src.indexOf('_buildNameStep()'),
          lessThan(src.indexOf('_buildImageStep()')));
      expect(src.indexOf('_buildImageStep()'),
          lessThan(src.indexOf('_buildRegionStep()')));
      expect(src.indexOf('_buildRegionStep()'),
          lessThan(src.indexOf('_buildIndustryStep()')));
      expect(src.indexOf('_buildIndustryStep()'),
          lessThan(src.indexOf('_buildTeamStep()')));
      expect(src.indexOf('_buildTeamStep()'),
          lessThan(src.indexOf('_buildIntroStep()')));
      expect(src.indexOf('_buildIntroStep()'),
          lessThan(src.indexOf('return _buildStep2();')));
    });

    test('이미지는 선택이고 나중에 하기로 건너뛸 수 있다', () {
      expect(src.contains('나중에 하기'), isTrue);
      expect(src.contains("imageUrl: _imageUrl"), isTrue);
      expect(src.contains('이미지 업로드 기능은 준비 중'), isFalse);
    });

    test('팀수는 조편성때 수정 가능하다고 안내하고 1~30만 받는다', () {
      expect(src.contains('조편성때 수정 가능합니다'), isTrue);
      expect(src.contains('n.clamp(1, 30)'), isTrue);
      expect(src.contains('min: 1'), isTrue);
      expect(src.contains('max: 30'), isTrue);
    });

    test('직책 화면은 기존 선택·총무 안내를 유지한다', () {
      expect(src.contains('_buildRoleSelector'), isTrue);
      expect(src.contains('회비관리는 총무만 가능합니다'), isTrue);
      expect(src.contains('직책은 중복 선택할 수 있습니다'), isTrue);
      expect(src.contains('ClubMemberRole.encodeRoles(_myRoles)'), isTrue);
      expect(src.contains('직책을 하나 이상 선택해주세요'), isTrue);
    });

    test('createClub 인자와 소개 10자 제한을 깨지 않는다', () {
      expect(src.contains('provider.createClub('), isTrue);
      expect(src.contains('myRole: _myRoleEncoded'), isTrue);
      expect(src.contains('region: _region'), isTrue);
      expect(src.contains('teamCount: _teamCountValue'), isTrue);
      expect(src.contains('10자 이상'), isFalse);
      expect(src.contains('length < 10'), isFalse);
      expect(provider.contains('String? imageUrl'), isTrue);
      expect(provider.contains('imageUrl: imageUrl'), isTrue);
    });

    test('로그인·어드민 동기화 안내를 유지한다', () {
      expect(src.contains('로그인이 필요합니다'), isTrue);
      expect(src.contains('어드민 동기화 실패'), isTrue);
    });
  });
}
