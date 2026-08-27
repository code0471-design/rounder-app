import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/data/golf_courses_kr.dart';

void main() {
  test('골프장 이름 일부만 쳐도 목록과 주소가 나온다', () {
    final hits = searchGolfCourses('레이크');
    expect(hits, isNotEmpty);
    expect(hits.first.name, contains('레이크사이드'));
    expect(hits.first.address, contains('용인'));
  });

  test('공백 검색은 목록을 열지 않는다', () {
    expect(searchGolfCourses('  '), isEmpty);
  });
}
