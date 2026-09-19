import '../../models/club_model.dart';

/// Club 데이터 접근 계약 (Firestore·Mock 교체 가능)
abstract class ClubRepository {
  Future<List<Club>> fetchDiscoverableClubs();
  Future<List<Club>> fetchMyClubs(String userId);
  Stream<List<Club>> watchDiscoverableClubs();
  Future<Club?> fetchClubById(String clubId, {required String userId});
  Future<bool> isUserMember(String clubId, String userId);
  Future<void> updateTeamCount(String clubId, int teamCount);
  Future<void> updateClubInfo(
    String clubId, {
    String? name,
    String? description,
    String? imageUrl,
    int? teamCount,
    String? hostName,
    String? hostUserId,
    String? region,
    String? industry,
  });

  /// 사용자 모임 생성 (Firestore: clubs + membership + creator member)
  Future<void> createClub({
    required Club club,
    required String userId,
    required String userName,
    required Member creatorMember,
    String moderationStatus = 'active',
  });

  /// 초대 수락 — 승인 없이 멤버·멤버십 즉시 등록
  Future<void> addMemberViaInvite({
    required String clubId,
    required String userId,
    required Member member,
  });

  /// 이 모임에 소속된 **계정** 목록. 푸시 대상은 명단 행이 아니라 계정이다.
  Future<List<ClubMemberAccount>> fetchClubMemberAccounts(String clubId);
}

/// 모임 소속 계정 한 명. 명단 행 id 와 계정 id 를 잇는 데 쓴다.
class ClubMemberAccount {
  const ClubMemberAccount({
    required this.userId,
    this.role = '',
    this.phone = '',
  });

  final String userId;
  final String role;
  final String phone;

  bool get isGuest => role.contains('게스트');
}

abstract class MemberRepository {
  Future<List<Member>> fetchMembers(String clubId);
  Stream<List<Member>> watchMembers(String clubId);
}

abstract class FinanceRepository {
  Future<List<DuesSetting>> fetchDuesSettings(String clubId);
  Future<List<DuesPayment>> fetchDuesPayments(String clubId);
  Future<List<Transaction>> fetchTransactions(String clubId);

  Future<ClubFinanceSnapshot> fetchClubFinanceSnapshot(String clubId);
}

/// 모임별 재무 스냅샷 (Service Layer 입력용)
class ClubFinanceSnapshot {
  final String clubId;
  final List<DuesSetting> duesSettings;
  final List<DuesPayment> duesPayments;
  final List<Transaction> transactions;

  const ClubFinanceSnapshot({
    required this.clubId,
    required this.duesSettings,
    required this.duesPayments,
    required this.transactions,
  });
}
