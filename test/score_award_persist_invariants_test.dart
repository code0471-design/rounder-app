import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String screen;
  late String provider;
  late String codec;

  setUpAll(() {
    screen = File('lib/screens/records/score_award_screen.dart').readAsStringSync();
    provider = File('lib/providers/club_provider.dart').readAsStringSync();
    codec = File('lib/services/club_data_codec.dart').readAsStringSync();
  });

  test('스코어와 시상은 따로 저장하고 즉시 persist 한다', () {
    expect(screen.contains("'스코어 저장'"), isTrue);
    expect(screen.contains("'시상 저장'"), isTrue);
    expect(screen.contains('_saveScores'), isTrue);
    expect(screen.contains('_saveAwards'), isTrue);
    expect(screen.contains('_saveAll'), isFalse);
    expect(provider.contains('void saveRoundScores('), isTrue);
    expect(provider.contains('void saveAwardsForSchedule('), isTrue);
    expect(provider.contains('_persistImmediately();'), isTrue);
    expect(screen.contains('merge: widget.groupFilter != null'), isTrue,
        reason: '조별 스코어 저장이 다른 조 타수를 지우면 안 됨');
    final start = provider.indexOf('void saveRoundScores(');
    final end = provider.indexOf('후원사 감사인사', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final scoreFn = provider.substring(start, end);
    expect(scoreFn.contains('_persistImmediately()'), isTrue);
    expect(scoreFn.contains('{bool merge = false}'), isTrue);
    expect(codec.contains("'roundScores'"), isTrue);
    expect(provider.contains('regularAwardRankingForYear'), isTrue);
    final preview =
        File('lib/widgets/score_award_results.dart').readAsStringSync();
    expect(preview.contains('i += 3'), isTrue, reason: '스코어는 한 줄에 3명');
    expect(preview.contains('a.value.compareTo(b.value)'), isTrue,
        reason: '스코어는 타수 낮은 순');
  });

  test('스코어·시상은 리뉴얼 톤이고 저장하면 일정 상세로 돌아간다', () {
    expect(screen.contains('const AppColors.'), isFalse,
        reason: 'const AppColors.x 는 생성자처럼 파싱되어 릴리스 빌드가 깨진다');
    expect(screen.contains('0xFF7C3AED'), isFalse, reason: '옛 보라 액센트 회귀');
    expect(screen.contains('0xFF1E1B4B'), isFalse, reason: '옛 인디고 이름색 회귀');
    expect(screen.contains('Colors.amber.shade700'), isFalse,
        reason: '시상자 이름이 붉은 앰버로 돌아가면 안 됨');
    expect(screen.contains('AppColors.ink'), isTrue);
    expect(screen.contains('AppColors.charcoal'), isTrue);
    expect(screen.contains('AppColors.goldDeep'), isTrue);
    final scores = screen.indexOf('void _saveScores()');
    final awards = screen.indexOf('void _saveAwards()');
    final scoresFn = screen.substring(scores, awards);
    final awardsFn = screen.substring(awards, screen.indexOf('  @override', awards));
    expect(scoresFn.contains('if (mounted) Navigator.pop(context);'), isTrue);
    expect(awardsFn.contains('if (mounted) Navigator.pop(context);'), isTrue);
  });
}
