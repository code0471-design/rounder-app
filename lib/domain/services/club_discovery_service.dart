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
      final regionOk = isAllRegionFilter(region) ||
          club.region == region ||
          club.region.startsWith(region);
      final industryOk =
          isAllIndustryFilter(industry) || club.industry == industry;
      final keywordOk = matchesKeyword(club, keyword);
      return regionOk && industryOk && keywordOk;
    }).toList();
  }

  /// 모임명·소개 검색. 대소문자·공백 차이는 무시한다.
  static bool matchesKeyword(Club club, String keyword) {
    final raw = keyword.trim();
    if (raw.isEmpty) return true;
    final kw = _fold(raw);
    final kwCompact = kw.replaceAll(' ', '');
    bool hit(String s) {
      final folded = _fold(s);
      return folded.contains(kw) ||
          folded.replaceAll(' ', '').contains(kwCompact);
    }

    return hit(club.name) || hit(club.description);
  }

  static String _fold(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}
