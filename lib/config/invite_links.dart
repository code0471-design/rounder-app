/// 모임 초대 HTTPS 링크.
///
/// `https://rounder.app` 은 다른 회사 앱(Talk Trash)이라 쓰면 안 된다.
class InviteLinks {
  InviteLinks._();

  static const webOrigin = 'https://rounder-f6019.web.app';
  static const playPackage = 'com.golfrounder.golf';

  static const hosts = <String>{
    'rounder-f6019.web.app',
    'rounder-staging.web.app',
  };

  static const playStore =
      'https://play.google.com/store/apps/details?id=$playPackage';

  static Uri inviteDeepLink(Map<String, String> query) => Uri(
        scheme: 'rounder',
        host: 'invite',
        queryParameters: query,
      );

  /// Play 설치 후에도 초대를 이어가도록 referrer에 초대 쿼리를 넣는다.
  static String playStoreUrl({Map<String, String> inviteQuery = const {}}) {
    if (inviteQuery.isEmpty) return playStore;
    final referrer = Uri(queryParameters: inviteQuery).query;
    return '$playStore&referrer=${Uri.encodeComponent(referrer)}';
  }

  static Uri? uriFromPlayReferrer(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var decoded = raw.trim().replaceAll('+', ' ');
    if (!decoded.contains('=') && decoded.contains('%')) {
      try {
        decoded = Uri.decodeComponent(decoded);
      } catch (_) {}
    }
    Map<String, String> q;
    try {
      q = Uri.splitQueryString(decoded);
    } catch (_) {
      return null;
    }
    final club = (q['club'] ?? q['clubId'] ?? '').trim();
    final token = (q['token'] ?? '').trim();
    if (club.isEmpty && token.isEmpty) return null;

    String pick(String a, [String? b]) {
      final v = (q[a] ?? (b == null ? null : q[b]) ?? '').trim();
      return v;
    }

    return inviteDeepLink({
      if (token.isNotEmpty) 'token': token,
      if (club.isNotEmpty) 'club': club,
      if (pick('name', 'clubName').isNotEmpty) 'name': pick('name', 'clubName'),
      if (pick('inviter', 'inviterName').isNotEmpty)
        'inviter': pick('inviter', 'inviterName'),
      if (pick('type').isNotEmpty) 'type': pick('type'),
      if (pick('referrer', 'referrerId').isNotEmpty)
        'referrer': pick('referrer', 'referrerId'),
      if (pick('referrerName').isNotEmpty) 'referrerName': pick('referrerName'),
      if (pick('guest', 'guestName').isNotEmpty)
        'guest': pick('guest', 'guestName'),
    });
  }

  static bool isInviteHttps(Uri uri) {
    if (uri.scheme != 'https' && uri.scheme != 'http') return false;
    if (!hosts.contains(uri.host.toLowerCase())) return false;
    return uri.path == '/invite' || uri.path.startsWith('/invite/');
  }

  static bool isInviteUri(Uri uri) {
    if (uri.scheme == 'rounder' && uri.host.toLowerCase() == 'invite') {
      return true;
    }
    return isInviteHttps(uri);
  }
}
