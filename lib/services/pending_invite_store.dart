import 'package:shared_preferences/shared_preferences.dart';

/// 스토어 설치 전·후, 로그인 전에 초대 딥링크를 잠깐 보관한다.
class PendingInviteStore {
  PendingInviteStore._();

  static const _key = 'pending_invite_uri_v1';

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
}
