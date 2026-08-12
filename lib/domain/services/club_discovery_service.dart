import '../../models/club_model.dart';

/// 모임 탐색 필터 — 순수 함수 (단위 테스트 가능)
abstract final class ClubDiscoveryService {
  static List<Club> filter({
    required List<Club> clubs,
    String region = '전체',
    String industry = '전체',
    String keyword = '',
  }) {
    return clubs.where((club) {
      final regionOk = region == '전체' ||
          club.region == region ||
          club.region.startsWith(region);
      final industryOk =
          industry == '전체' || club.industry == industry;
      final kw = keyword.trim().toLowerCase();
      final keywordOk = kw.isEmpty ||
          club.name.toLowerCase().contains(kw) ||
          club.description.toLowerCase().contains(kw);
      return regionOk && industryOk && keywordOk;
    }).toList();
  }
}
