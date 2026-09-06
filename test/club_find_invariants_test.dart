import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/models/club_model.dart';

String _read(String relative) => File(relative).readAsStringSync();

void main() {
  test('모임찾기 카드에 모임소개가 있다', () {
    final dash =
        _read('lib/features/clubs/presentation/club_list_dashboard_screen.dart');
    expect(dash.contains('club.description'), isTrue);
    expect(dash.contains('maxLines: 3'), isTrue);
    expect(dash.contains('width: 64'), isTrue);
  });

  test('검색 필터 기본값은 지역전체·업종전체이고 시·도만 고른다', () {
    expect(kClubFindRegions.first, kRegionFilterAll);
    expect(kClubFindRegions.contains('전체'), isFalse);
    expect(kClubFindRegions.contains('서울 강남구'), isFalse);
    expect(kClubFindRegions, [kRegionFilterAll, ...kSidoList]);

    final dash =
        _read('lib/features/clubs/presentation/club_list_dashboard_screen.dart');
    expect(dash.contains('kClubFindRegions'), isTrue);
    expect(dash.contains("label: '지역'"), isTrue);
    expect(dash.contains("label: '업종'"), isTrue);
    expect(dash.contains('kIndustryFilterAll'), isTrue);
    expect(dash.contains('모임 이름, 소개로 검색'), isTrue);
  });
}
