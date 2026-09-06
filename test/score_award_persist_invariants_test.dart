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
}
