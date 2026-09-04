import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String room;
  late String provider;
  late String members;

  setUpAll(() {
    room = File('lib/screens/club_room/club_room_screen.dart').readAsStringSync();
    provider = File('lib/providers/club_provider.dart').readAsStringSync();
    members = File('lib/screens/members/members_screen.dart').readAsStringSync();
  });

  test('홈 다음 일정·참석현황은 원클럽형 카드다', () {
    expect(room.contains("'다음 일정'"), isTrue);
    expect(room.contains("'자세히 보기'"), isTrue);
    expect(room.contains('예정된 모임이 없습니다'), isTrue);
    expect(room.contains("'참석 응답 · 명단 보기 >'"), isTrue);
    expect(room.contains('upcomingSchedules.isNotEmpty'), isTrue);
  });

  test('홈 현 회비 잔고는 월회비·연회비를 다르게 보여 준다', () {
    expect(room.contains('currentHomeDuesSetting'), isTrue);
    expect(room.contains('previousMonthUnpaidCount'), isTrue);
    expect(room.contains("isMonthly ? '이달 \${homeDues.title}' : homeDues.title"), isTrue);
    expect(room.contains("'전월 미납 \$prevUnpaid명'"), isTrue);
    expect(room.contains("'회비 미설정'"), isTrue);
    expect(room.contains("'이달 회비 납부'"), isFalse);
    expect(provider.contains('DuesSetting? currentHomeDuesSetting'), isTrue);
    expect(provider.contains('if (clubPrimaryDuesType != DuesType.monthly) return 0;'), isTrue);
  });

  test('모임 홈 헤더는 원클럽형 썸네일·가로 초대 버튼이다', () {
    expect(room.contains('class _ClubThumb'), isTrue);
    expect(room.contains('assets/icons/rounder_ball_crop.png'), isTrue);
    expect(room.contains('Color(0xFFF7F8FA)'), isTrue);
    expect(room.contains('Color(0xFF6B7280)'), isTrue);
    expect(room.contains('_ClubThumb(club: club, size: 80)'), isTrue);
    expect(room.contains("label: '정회원 초대하기'"), isTrue);
    expect(room.contains("label: '게스트 초대하기'"), isTrue);
    expect(room.contains('Icons.badge_outlined'), isFalse);
    expect(
      room.indexOf('_ClubThumb(club: club, size: 80)'),
      lessThan(room.indexOf("label: '정회원 초대하기'")),
    );
  });

  test('독촉하기는 전월 미납과 같은 줄이다', () {
    final unpaid = room.indexOf("'전월 미납 \$prevUnpaid명'");
    final nudge = room.indexOf("'독촉하기'");
    expect(unpaid, greaterThan(0));
    expect(nudge, greaterThan(unpaid));
  });

  test('회원 탭에 회원 관리 헤더가 없어야 한다', () {
    expect(members.contains("'회원 관리'"), isFalse);
    expect(members.contains('Tab(text: \'전체'), isTrue);
  });

  test('회원 탭은 이름 검색까지 고정하고 랭킹은 스크롤 영역에 둔다', () {
    final searchIdx = members.indexOf('_buildSearchBar()');
    final tabViewIdx = members.indexOf('TabBarView(');
    expect(searchIdx, greaterThan(0));
    expect(tabViewIdx, greaterThan(searchIdx));
    final pinned = members.substring(searchIdx, tabViewIdx);
    expect(pinned.contains('_buildPointsRankingBanner'), isFalse);
    expect(members.contains('scrollHeader'), isTrue);
    expect(members.contains('_buildPointsRankingBanner(provider)'), isTrue);
    expect(members.contains('_buildBirthdayBanner'), isFalse);
    expect(members.contains('birthdayThisMonth'), isFalse);
    expect(members.contains('GuestInviteFormScreen'), isTrue);
    expect(members.contains('_TreasurerTransferEntry'), isTrue);
    expect(members.contains('file_download_outlined'), isTrue);
  });
}
