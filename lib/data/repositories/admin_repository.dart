import '../../screens/admin/admin_models.dart';

/// 플랫폼 어드민용 데이터 접근 (앱과 동일 Firestore/Mock 저장소)
abstract class AdminRepository {
  Stream<List<AdminClub>> watchClubs();
  Stream<List<AdminMember>> watchMembers();
  Future<DashboardStats> fetchStats();

  Future<void> updateClubModerationStatus(String clubId, String status);
  Future<void> updateMemberAccountStatus(String userId, String status);
}
