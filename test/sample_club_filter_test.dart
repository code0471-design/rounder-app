import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/domain/data/sample_club_filter.dart';

void main() {
  test('강남축구회·분당골프클럽·c1 은 샘플로 본다', () {
    expect(
      SampleClubFilter.isSample(id: 'c1', name: '강남 골프회'),
      isTrue,
    );
    expect(
      SampleClubFilter.isSample(id: 'xyz', name: '강남축구회'),
      isTrue,
    );
    expect(
      SampleClubFilter.isSample(id: 'xyz', name: '분당 골프클럽'),
      isTrue,
    );
    expect(
      SampleClubFilter.isSampleDoc('c001', {'name': '아무개', 'is_sample': true}),
      isTrue,
    );
  });

  test('테스터가 만든 c_ 모임은 샘플이 아니다', () {
    expect(
      SampleClubFilter.isSample(id: 'c_123', name: '아레나'),
      isFalse,
    );
  });
}
