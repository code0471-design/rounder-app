import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/domain/data/club_sample_catalog.dart';

void main() {
  test('ClubSampleCatalog is empty in clean-slate mock', () {
    expect(ClubSampleCatalog.clubs, isEmpty);
  });
}
