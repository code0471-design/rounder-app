import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/domain/services/club_discovery_service.dart';

void main() {
  final clubs = [
    Club(
      id: '1',
      name: '서울 골프',
      myRole: '회장',
      region: '서울',
      industry: 'IT/테크',
      memberCount: 10,
      createdAt: DateTime(2024, 1, 1),
    ),
    Club(
      id: '2',
      name: '부산 라운더',
      myRole: '일반',
      region: '부산',
      industry: '금융',
      memberCount: 5,
      createdAt: DateTime(2024, 2, 1),
    ),
    Club(
      id: '3',
      name: '서울 금융',
      myRole: '총무',
      region: '서울',
      industry: '금융',
      memberCount: 8,
      createdAt: DateTime(2024, 3, 1),
    ),
  ];

  group('ClubDiscoveryService', () {
    test('returns all when filters are 전체', () {
      final result = ClubDiscoveryService.filter(
        clubs: clubs,
        region: '전체',
        industry: '전체',
        keyword: '',
      );
      expect(result.length, 3);
    });

    test('filters by region', () {
      final result = ClubDiscoveryService.filter(
        clubs: clubs,
        region: '서울',
        industry: '전체',
        keyword: '',
      );
      expect(result.length, 2);
      expect(result.every((c) => c.region.startsWith('서울')), isTrue);
    });

    test('filters by industry', () {
      final result = ClubDiscoveryService.filter(
        clubs: clubs,
        region: '전체',
        industry: '금융',
        keyword: '',
      );
      expect(result.length, 2);
    });

    test('filters by keyword (case insensitive)', () {
      final result = ClubDiscoveryService.filter(
        clubs: clubs,
        region: '전체',
        industry: '전체',
        keyword: '라운더',
      );
      expect(result.length, 1);
      expect(result.first.name, '부산 라운더');
    });

    test('combines region, industry, keyword', () {
      final result = ClubDiscoveryService.filter(
        clubs: clubs,
        region: '서울',
        industry: '금융',
        keyword: '',
      );
      expect(result.length, 1);
      expect(result.first.name, '서울 금융');
    });
  });
}
