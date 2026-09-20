/// 시드 홍길동은 실모임에서 삭제다. 이름만 바꾸거나 merge 로 되살리지 않는다.
abstract final class DemoFinanceStrip {
  static const _legacyMockClubIds = {
    'c1',
    'c2',
    'c3',
    'c4',
    'c5',
    'c6',
  };
  static final _seedMonthlyTx = RegExp(r'^t_m\d+_\d+$');

  static bool isLegacyMockClub(String? clubId) =>
      clubId != null && _legacyMockClubIds.contains(clubId);

  static bool isSeedTransaction({
    required String id,
    String? clubId,
  }) {
    final seedId = id == 'ob_demo' ||
        id == 't0' ||
        id == 't_ad_sky72' ||
        _seedMonthlyTx.hasMatch(id);
    if (!seedId) return false;
    return clubId == null || _legacyMockClubIds.contains(clubId);
  }

  static bool isSeedDuesPayment({
    required String id,
    required String memberId,
    required bool inRealClub,
  }) {
    if (isGhostMemberId(memberId) || isGhostName(memberId)) return true;
    if (inRealClub) return false;
    if (id.startsWith('dp_')) return false;
    if (id == 'pr1' || id == 'pr2') return true;
    if (RegExp(r'^dp\d{1,2}$').hasMatch(id)) return true;
    return false;
  }

  static bool isGhostName(String? raw) => '${raw ?? ''}'.contains('홍길동');

  static bool isGhostMemberId(String? raw) {
    final id = (raw ?? '').trim();
    if (id.isEmpty) return false;
    if (id == 'm1' || id == 'user_me' || id == 'mg1') return true;
    if (RegExp(r'(^|_)m1$').hasMatch(id)) return true;
    if (RegExp(r'^m\d+$').hasMatch(id)) return true;
    return false;
  }

  /// 실모임 장부에 남은 시드 이름.
  static bool isHongGilDongGhost(String title) => isGhostName(title);

  static bool isGhostMemberMap(Map<String, dynamic> m) =>
      isGhostName('${m['name'] ?? ''}') || isGhostMemberId('${m['id'] ?? ''}');

  static bool isGhostPaymentMap(Map<String, dynamic> m) =>
      isGhostName('${m['memberName'] ?? ''}') ||
      isGhostName('${m['recordedBy'] ?? ''}') ||
      isGhostMemberId('${m['memberId'] ?? ''}');

  static bool isGhostTransactionMap(Map<String, dynamic> m) {
    final clubId = m['clubId'] as String?;
    if (isLegacyMockClub(clubId)) return false;
    return isHongGilDongGhost('${m['title'] ?? ''}') ||
        isGhostMemberId('${m['memberId'] ?? ''}') ||
        isSeedTransaction(id: '${m['id'] ?? ''}', clubId: clubId);
  }

  static List<dynamic> dropGhostMembers(List? raw, {required String clubId}) {
    if (isLegacyMockClub(clubId)) {
      return List<dynamic>.from(raw ?? const []);
    }
    return [
      for (final e in raw ?? const [])
        if (e is! Map || !isGhostMemberMap(Map<String, dynamic>.from(e))) e,
    ];
  }

  static List<dynamic> dropGhostPayments(List? raw) => [
        for (final e in raw ?? const [])
          if (e is! Map || !isGhostPaymentMap(Map<String, dynamic>.from(e))) e,
      ];

  static List<dynamic> dropGhostTransactions(List? raw) => [
        for (final e in raw ?? const [])
          if (e is! Map ||
              !isGhostTransactionMap(Map<String, dynamic>.from(e)))
            e,
      ];

  static String rewriteLedgerTitle(String title) {
    return title
        .replaceAll('Jeongwonleeee', '이정원')
        .replaceAll('Jeongwon Lee', '이정원')
        .replaceAll('JeongwonLee', '이정원');
  }
}
