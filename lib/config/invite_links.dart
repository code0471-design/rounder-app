/// 모임 초대 HTTPS 링크.
///
/// `https://rounder.app` 은 다른 회사 앱(Talk Trash)이라 쓰면 안 된다.
class InviteLinks {
  InviteLinks._();

  static const webOrigin = 'https://rounder-f6019.web.app';

  static const hosts = <String>{
    'rounder-f6019.web.app',
    'rounder-staging.web.app',
  };

  static const playStore =
      'https://play.google.com/store/apps/details?id=com.golfrounder.golf';

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
