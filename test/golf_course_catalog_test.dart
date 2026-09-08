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

  test('골프장 이름은 CC·GC·골프클럽을 붙여 넣는다', () {
    expect(canonicalGolfCourseName('레이크사이드'), '레이크사이드CC');
    expect(canonicalGolfCourseName('남서울'), '남서울CC');
    expect(canonicalGolfCourseName('안양베네스트'), '안양베네스트GC');
    expect(canonicalGolfCourseName('더크로스비'), '더크로스비골프클럽');
    expect(canonicalGolfCourseName('더크로스비골프클럽'), '더크로스비골프클럽');
    expect(canonicalGolfCourseName('레이크사이드CC'), '레이크사이드CC');
  });
}
