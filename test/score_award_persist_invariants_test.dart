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
    final scoreFn = provider.substring(
      provider.indexOf('void saveRoundScores('),
      provider.indexOf('void saveRoundScores(') + 280,
    );
    expect(scoreFn.contains('_persistImmediately()'), isTrue);
    expect(codec.contains("'roundScores'"), isTrue);
  });
}
