import 'package:shared_preferences/shared_preferences.dart';

/// 스토어 설치 전·후, 로그인 전에 초대 딥링크를 잠깐 보관한다.
class PendingInviteStore {
  PendingInviteStore._();

  static const _key = 'pending_invite_uri_v1';
  /// Play Install Referrer는 설치 기간 동안 같은 값을 계속 준다.
  /// 한 번 읽었으면 다시 초대로 쓰지 않는다.
  static const _referrerUsedKey = 'play_invite_referrer_used_v1';

  static Future<void> save(Uri uri) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, uri.toString());
    } catch (_) {}
  }

  static Future<Uri?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      return Uri.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }

  static Future<bool> wasPlayReferrerUsed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_referrerUsedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markPlayReferrerUsed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_referrerUsedKey, true);
    } catch (_) {}
  }
}
