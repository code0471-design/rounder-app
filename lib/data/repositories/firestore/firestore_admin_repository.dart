import 'dart:async';

import '../../../screens/admin/admin_models.dart';
import '../../datasources/firestore/firestore_admin_datasource.dart';
import '../admin_repository.dart';

class FirestoreAdminRepository implements AdminRepository {
  FirestoreAdminRepository({FirestoreAdminDataSource? dataSource})
      : _dataSource = dataSource ?? FirestoreAdminDataSource();

  final FirestoreAdminDataSource _dataSource;

  List<AdminClub> _clubs = const [];
  List<AdminMember> _members = const [];

  @override
  Stream<List<AdminClub>> watchClubs() {
    return _dataSource.watchClubs().map((clubs) {
      _clubs = clubs;
      return clubs;
    });
  }

  @override
  Stream<List<AdminMember>> watchMembers() {
    return _dataSource.watchMembers().map((members) {
      _members = members;
      return members;
    });
  }

  @override
  Future<DashboardStats> fetchStats() => _dataSource.fetchStats(
        members: _members,
        clubs: _clubs,
      );

  @override
  Future<void> updateClubModerationStatus(String clubId, String status) =>
      _dataSource.updateClubModerationStatus(clubId, status);

  @override
  Future<void> updateMemberAccountStatus(String userId, String status) =>
      _dataSource.updateMemberAccountStatus(userId, status);
}
