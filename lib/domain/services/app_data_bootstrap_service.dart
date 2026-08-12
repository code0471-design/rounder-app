import '../../data/repositories/club_repository.dart';
import '../../models/club_model.dart';

/// 앱 시작 시 Firestore에서 핵심 데이터를 한 번에 로드
class AppBootstrapSnapshot {
  final String userId;
  final List<Club> myClubs;
  final List<Club> discoverableClubs;
  final Map<String, List<Member>> membersByClubId;
  final Map<String, ClubFinanceSnapshot> financeByClubId;
  final DateTime loadedAt;

  const AppBootstrapSnapshot({
    required this.userId,
    required this.myClubs,
    required this.discoverableClubs,
    required this.membersByClubId,
    required this.financeByClubId,
    required this.loadedAt,
  });

  bool get isEmpty =>
      myClubs.isEmpty && discoverableClubs.isEmpty;
}

class AppDataBootstrapService {
  AppDataBootstrapService({
    required ClubRepository clubRepository,
    required MemberRepository memberRepository,
    required FinanceRepository financeRepository,
  })  : _clubRepository = clubRepository,
        _memberRepository = memberRepository,
        _financeRepository = financeRepository;

  final ClubRepository _clubRepository;
  final MemberRepository _memberRepository;
  final FinanceRepository _financeRepository;

  /// 로그인 사용자 기준 초기 스냅샷 (clubs → members → finance 순)
  Future<AppBootstrapSnapshot> loadForUser(String userId) async {
    final discoverable = await _clubRepository.fetchDiscoverableClubs();
    final myClubs = await _clubRepository.fetchMyClubs(userId);

    final clubIds = {
      ...myClubs.map((c) => c.id),
      ...discoverable.map((c) => c.id),
    };

    final membersByClubId = <String, List<Member>>{};
    final financeByClubId = <String, ClubFinanceSnapshot>{};

    for (final clubId in clubIds) {
      membersByClubId[clubId] =
          await _memberRepository.fetchMembers(clubId);
      financeByClubId[clubId] =
          await _financeRepository.fetchClubFinanceSnapshot(clubId);
    }

    return AppBootstrapSnapshot(
      userId: userId,
      myClubs: myClubs,
      discoverableClubs: discoverable,
      membersByClubId: membersByClubId,
      financeByClubId: financeByClubId,
      loadedAt: DateTime.now(),
    );
  }
}
