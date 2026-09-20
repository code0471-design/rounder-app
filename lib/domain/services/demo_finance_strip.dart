/// 데모 시드 재무만 지운다. 실모임 잔고·납부는 이름이 홍길동이어도 건드리지 않는다.
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
    if (RegExp(r'(^|_)m\d+$').hasMatch(memberId) ||
        memberId == 'user_me' ||
        memberId == 'mg1') {
      return true;
    }
    if (inRealClub) return false;
    if (id.startsWith('dp_')) return false;
    if (id == 'pr1' || id == 'pr2') return true;
    if (RegExp(r'^dp\d{1,2}$').hasMatch(id)) return true;
    return false;
  }

  /// 실모임 장부에 남은 시드 이름. 지운 홍길동이 pull 마다 다시 보이는 원인.
  static bool isHongGilDongGhost(String title) => title.contains('홍길동');

  /// 카카오/구글 닉이 장부 제목에 박힌 경우 한글 이름으로.
  static String rewriteLedgerTitle(String title) {
    return title
        .replaceAll('Jeongwonleeee', '이정원')
        .replaceAll('Jeongwon Lee', '이정원')
        .replaceAll('JeongwonLee', '이정원');
  }
}
