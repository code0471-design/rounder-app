import '../../models/club_model.dart';

/// 회원 사진은 모임 문서마다 따로 있다.
/// 한 모임에만 사진이 있으면 같은 사람의 다른 모임 줄에도 그 사진을 보여 준다.
abstract final class MemberPhoto {
  static String? fill({
    required Member member,
    required Iterable<Member> roster,
    String? selfPhoto,
    bool isSelf = false,
  }) {
    final own = (member.photoUrl ?? '').trim();
    if (own.isNotEmpty) return own;

    final phone = _digits(member.phone);
    final uid = userIdOf(member.id);
    final name = member.name.trim();
    String? named;
    var namedCount = 0;
    for (final other in roster) {
      if (other.id == member.id) continue;
      final url = (other.photoUrl ?? '').trim();
      if (url.isEmpty) continue;
      final otherPhone = _digits(other.phone);
      if (phone.length >= 10 && phone == otherPhone) return url;
      final otherUid = userIdOf(other.id);
      if (uid.isNotEmpty && uid == otherUid) return url;
      if (name.isNotEmpty && name == other.name.trim()) {
        namedCount++;
        named = url;
      }
    }
    if (namedCount == 1 && named != null) return named;
    if (isSelf) {
      final account = (selfPhoto ?? '').trim();
      if (account.isNotEmpty) return account;
    }
    return null;
  }

  /// `m_{clubId}_{userId}` 에서 userId. 방장 칸은 비운다.
  static String userIdOf(String memberId) {
    final id = memberId.trim();
    final match = RegExp(r'^m_(c_\d+)_(.+)$').firstMatch(id);
    if (match == null) return '';
    final userId = match.group(2) ?? '';
    if (userId.startsWith('creator')) return '';
    return userId;
  }

  static String _digits(String? phone) =>
      (phone ?? '').replaceAll(RegExp(r'\D'), '');
}
