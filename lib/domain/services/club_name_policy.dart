import '../../models/club_model.dart';

/// 모임 이름은 공백·대소문자만 달라도 같은 모임으로 본다.
abstract final class ClubNamePolicy {
  static String key(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  static bool isTaken({
    required String name,
    required Iterable<Club> clubs,
    String? exceptClubId,
  }) {
    final want = key(name);
    if (want.isEmpty) return false;
    return clubs.any((c) {
      if (exceptClubId != null && c.id == exceptClubId) return false;
      return key(c.name) == want;
    });
  }
}
