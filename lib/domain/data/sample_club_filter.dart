/// 코드에서 비운 샘플·목업이 Firestore·로컬에 남아도 앱에 안 보이게.
abstract final class SampleClubFilter {
  static final _compact = RegExp(r'\s+');

  static const mockIds = {
    'c1', 'c2', 'c3', 'c4', 'c5', 'c6',
    'c001', 'c002', 'c003', 'c004', 'c005',
    'c006', 'c007', 'c008', 'c009', 'c010',
  };

  static const mockNames = {
    '강남골프회',
    '강남축구회',
    '강남축구클럽',
    '분당골프클럽',
    '강남버디클럽',
    '판교IT골프모임',
    '분당주말라운딩',
    '송파이글파크',
    '마포선셋골프클럽',
    '제주그린아일랜드',
    '수원버디버디',
    '논란의골프클럽',
    '강북선데이골프',
    '인천베이사이드',
    '시흥CC',
    '시흘CC',
  };

  static bool isSample({
    required String id,
    String name = '',
    bool? flagged,
  }) {
    if (flagged == true) return true;
    if (id.startsWith('seed_')) return true;
    if (mockIds.contains(id)) return true;
    if (RegExp(r'^c0\d{2}$').hasMatch(id)) return true;
    final compact = name.replaceAll(_compact, '');
    return compact.isNotEmpty && mockNames.contains(compact);
  }

  static bool isSampleDoc(String id, Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    return isSample(
      id: id,
      name: (map['name'] as String?) ?? '',
      flagged: map['is_sample'] == true,
    );
  }
}
