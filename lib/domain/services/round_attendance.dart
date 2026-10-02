import '../../models/club_model.dart';

/// 홈·일정 목록·일정 상세가 같은 참석 숫자를 쓰게 하는 집계.
///
/// 정회원만 세면 홈(전체)과 일정(정회원)이 한 명씩 어긋난다.
/// 게스트도 응답 대상이므로 활성 명단 전체를 한 번씩만 센다.
class RoundAttendance {
  final List<String> attendIds;
  final List<String> declineIds;
  final int noResponse;
  final int regularCount;
  final int guestCount;
  final int guestAttend;

  const RoundAttendance({
    required this.attendIds,
    required this.declineIds,
    required this.noResponse,
    required this.regularCount,
    required this.guestCount,
    required this.guestAttend,
  });

  int get attend => attendIds.length;
  int get decline => declineIds.length;

  /// 참석 + 불참 + 미답변. 활성 명단 수와 같다.
  int get total => attend + decline + noResponse;

  String get headLabel {
    if (guestCount <= 0) return '정회원 $regularCount명';
    return '정회원 $regularCount명 · 게스트 $guestCount명';
  }

  static bool isGuest(Member m) => m.memberType == '게스트';

  static RoundAttendance of({
    required Iterable<Member> roster,
    required Iterable<AttendanceResponse> responses,
  }) {
    final people = roster.toList();
    final ids = <String>[];
    final seen = <String>{};
    final guestIds = <String>{};
    for (final m in people) {
      if (!seen.add(m.id)) continue;
      ids.add(m.id);
      if (isGuest(m)) guestIds.add(m.id);
    }
    final attendIds = <String>[];
    final declineIds = <String>[];
    final answered = <String>{};
    for (final r in responses) {
      if (!seen.contains(r.memberId) || !answered.add(r.memberId)) continue;
      if (r.response == '참석') {
        attendIds.add(r.memberId);
      } else if (r.response == '불참') {
        declineIds.add(r.memberId);
      } else {
        answered.remove(r.memberId);
      }
    }
    return RoundAttendance(
      attendIds: attendIds,
      declineIds: declineIds,
      noResponse: ids.where((id) => !answered.contains(id)).length,
      regularCount: ids.length - guestIds.length,
      guestCount: guestIds.length,
      guestAttend: attendIds.where(guestIds.contains).length,
    );
  }
}
