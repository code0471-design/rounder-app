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
    expect(dash.contains('for (final c in legacyProvider.myClubs)'), isTrue);
    expect(dash.contains('existing.coalesceDisplayFields(c)'), isTrue);
    expect(provider.contains('byId.putIfAbsent(c.id, () => c)'), isTrue);
    expect(
      provider.contains('설정에서 고친 이름'),
      isTrue,
      reason: '설정에서 고친 이름·소개는 서버 옛값으로 덮지 않는다',
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
      dash.contains('error && clubs.isEmpty'),
      isTrue,
      reason: '서버 조회 실패해도 내 모임 목록은 가려지지 않아야 한다',
    );
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

  test('모임 정보 수정이 없는 모임을 새로 만들지 않고 created_at 없는 모임도 목록에 남긴다', () {
    final src =
        _read('lib/data/datasources/firestore/firestore_club_datasource.dart');
    expect(src.contains('orderBy(\'created_at\''), isFalse);
    expect(src.contains('if (!existing.exists)'), isTrue);
    expect(src.contains('.update(data)'), isTrue);
    expect(
      src.contains('await _clubs.doc(clubId).set(data, SetOptions(merge: true));'),
      isFalse,
    );
  });

  test('모임찾기 상세에 입장 버튼이 없다', () {
    final dash = _read(
        'lib/features/clubs/presentation/club_detail_dashboard_screen.dart');
    expect(dash.contains('_enterClubRoom'), isFalse);
    expect(dash.contains("'모임 입장'"), isFalse);
    expect(dash.contains("isAdmin ? '입장'"), isFalse);
    expect(dash.contains('ClubRoomScreen'), isFalse);
  });

  test('모임 상세 헤더 위 빈 그린을 키우지 않는다', () {
    final dash = _read(
        'lib/features/clubs/presentation/club_detail_dashboard_screen.dart');
    final legacy = _read('lib/screens/clubs/club_detail_screen.dart');
    expect(dash.contains('expandedHeight: 220'), isFalse);
    expect(dash.contains('fromLTRB(20, 52'), isFalse);
    expect(dash.contains('expandedHeight: 152'), isTrue);
    expect(legacy.contains('expandedHeight: 220'), isFalse);
    expect(legacy.contains('fromLTRB(20, 52'), isFalse);
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
    expect(mark.contains('gaplessPlayback: true'), isTrue,
        reason: '동기화로 화면이 다시 그려져도 모임 이미지가 깜빡이면 안 된다');
  });
}
