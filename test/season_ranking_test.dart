import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/utils/season_ranking.dart';

void main() {
  test('내역 한 줄은 태그 없이 실제 적립만 보여 준다', () {
    expect(
      SeasonRanking.historyLine(MembershipPointEvent(
        type: MembershipPointType.roundAttendance,
        points: 10,
        desc: '8월 월례회 참석|sched_1',
        date: DateTime(2026, 8, 10),
      )),
      '8월 월례회 참석 +10p',
    );
    expect(
      SeasonRanking.historyLine(MembershipPointEvent(
        type: MembershipPointType.duesOnTime,
        points: 5,
        desc: '6월 월회비 정시납부|dues:d1:2026-6',
        date: DateTime(2026, 6, 1),
      )),
      '6월 월회비 정시납부 +5p',
    );
    expect(
      SeasonRanking.historyEmptyMessage(2026, nowYear: 2026),
      '올해 적립된 포인트가 없습니다',
    );
  });

  test('연도 라벨은 올해와 확정을 구분한다', () {
    expect(
      SeasonRanking.yearLabel(2027, nowYear: 2027, closed: false),
      '2027 올해',
    );
    expect(
      SeasonRanking.yearLabel(2026, nowYear: 2027, closed: true),
      '2026 확정',
    );
    expect(
      SeasonRanking.closeButtonLabel(2026, closed: false),
      '2026시즌 랭킹 마감 확정하기',
    );
    expect(SeasonRanking.closeButtonLabel(2026, closed: true), '2026시즌 마감 취소하기');
    expect(
      SeasonRanking.closeConfirmMessage(2026, nowYear: 2026),
      '올해 멤버십 랭킹을 마감, 확정하시겠습니까?',
    );
  });

  test('회원 탭은 점수만 내역 팝업이고 자세히 보기·배너는 그대로다', () {
    final src =
        File('lib/screens/members/members_screen.dart').readAsStringSync();
    expect(src.contains("'올해 랭킹'"), isTrue);
    expect(src.contains("'자세히 보기'"), isTrue);
    expect(src.contains('_showPointHistoryPopup'), isTrue);
    expect(src.contains('_showFullRankingSheet(provider)'), isTrue);
    expect(src.contains("'임원만 가능합니다'"), isTrue);
    expect(src.contains('SeasonRanking.closeConfirmMessage'), isTrue);
    expect(src.contains('SeasonRanking.reopenConfirmMessage'), isTrue);
    expect(src.contains('_confirmSeasonReopen'), isTrue);
    expect(src.contains("'확정할래요?'"), isFalse);
    expect(src.contains('SeasonRanking.closeButtonLabel'), isTrue);
    expect(src.contains("'일정 참석'"), isTrue);
    expect(src.contains("'회비 정시 납부'"), isTrue);
    expect(src.contains("'공지 댓글 (글당 1회)'"), isTrue);
    expect(src.contains("'댓글 삭제'"), isTrue);
    expect(src.contains('isClubExecutive'), isTrue,
        reason: '일반회원에게 마감 버튼을 숨기면 안 된다');
    final searchIdx = src.indexOf('_buildSearchBar()');
    final tabViewIdx = src.indexOf('TabBarView(');
    expect(tabViewIdx, greaterThan(searchIdx));
    expect(
      src.substring(searchIdx, tabViewIdx).contains('_buildPointsRankingBanner'),
      isFalse,
    );
  });
}
