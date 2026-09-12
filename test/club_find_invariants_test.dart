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
    expect(dash.contains('ClubCoverMark'), isTrue);
    expect(dash.contains('size: 64'), isTrue);
  });

  test('모임찾기는 내 모임을 포함한다', () {
    final dash =
        _read('lib/features/clubs/presentation/club_list_dashboard_screen.dart');
    final provider = _read('lib/providers/club_provider.dart');
    expect(dash.contains('legacyProvider.myClubs'), isTrue);
    expect(dash.contains('byId.putIfAbsent'), isTrue);
    expect(provider.contains('byId.putIfAbsent(c.id, () => c)'), isTrue);
    expect(
      provider.contains('name: bootClub.name.trim().isNotEmpty'),
      isTrue,
      reason: '내 모임 이름이 서버와 다르게 남지 않아야 한다',
    );
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
    expect(
      dash.contains('if (!kReleaseMode && controller.usingLocalFallback)'),
      isTrue,
      reason: '테스터에게 Firestore 샘플 배너가 보이면 안 된다',
    );
    expect(
      dash.contains("import 'package:flutter/foundation.dart';"),
      isTrue,
      reason: 'kReleaseMode는 foundation import가 있어야 릴리스 빌드가 된다',
    );
  });

  test('내 모임 카드는 원클럽형 커버와 구분선이 있다', () {
    final card = _read('lib/screens/my_clubs/widgets/home_club_card.dart');
    final home = _read('lib/screens/my_clubs/my_clubs_screen.dart');
    final mark = _read('lib/widgets/club_cover_mark.dart');
    expect(card.contains('ClubCoverMark(club: club, size: 80)'), isTrue);
    expect(home.contains('Divider('), isTrue);
    expect(mark.contains('Color(0xFF111827)'), isTrue);
    expect(mark.contains('width: 1.5'), isTrue);
    expect(mark.contains('club.imageUrl'), isTrue);
  });
}
