import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ClubMapper는 새 모임을 샘플로 쓰지 않는다', () {
    final src = File('lib/data/mappers/club_mapper.dart').readAsStringSync();
    expect(src.contains("'is_sample': true"), isFalse);
    expect(src.contains("'is_sample': false"), isTrue);
  });

  test('실계정 로그인 경로에 하드코딩 시드 페이로드를 지운다', () {
    final src = File('lib/providers/club_provider.dart').readAsStringSync();
    expect(src.contains('_stripHardcodedDemoPayload'), isTrue);
    expect(src.contains("final List<Member> _members = [];"), isTrue);
    expect(src.contains("final List<Transaction> _transactions = [];"), isTrue);
    expect(src.contains("final List<RoundPhoto> _photos = [];"), isTrue);
    expect(
      src.contains("static List<AdApplication> _createDefaultAdApplications() => <AdApplication>[];"),
      isTrue,
    );
  });

  test('샘플 카탈로그는 비어 있다', () {
    final src =
        File('lib/domain/data/club_sample_catalog.dart').readAsStringSync();
    expect(src.contains('static final List<Club> _clubs = <Club>[];'), isTrue);
  });
}
