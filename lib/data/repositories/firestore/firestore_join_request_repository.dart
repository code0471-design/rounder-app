import '../../../models/club_model.dart';
import '../../datasources/firestore/firestore_join_request_datasource.dart';
import '../join_request_repository.dart';

class FirestoreJoinRequestRepository implements JoinRequestRepository {
  FirestoreJoinRequestRepository({FirestoreJoinRequestDataSource? dataSource})
      : _dataSource = dataSource ?? FirestoreJoinRequestDataSource();

  final FirestoreJoinRequestDataSource _dataSource;

  @override
  Future<List<JoinRequest>> fetchPendingForClub(String clubId) =>
      _dataSource.fetchPendingForClub(clubId);

  @override
  Future<JoinRequest?> fetchPendingForUser(String clubId, String userId) =>
      _dataSource.fetchPendingForUser(clubId, userId);

  @override
  Future<String> submitJoinRequest({
    required String clubId,
    required String userId,
    required String userName,
    required String userGender,
    double? userHandicap,
    required String message,
  }) =>
      _dataSource.submit(
        clubId: clubId,
        userId: userId,
        userName: userName,
        userGender: userGender,
        userHandicap: userHandicap,
        message: message,
      );

  @override
  Future<void> approveJoinRequest({
    required JoinRequest request,
    required String memberType,
    required String role,
    required String reviewedBy,
  }) =>
      _dataSource.approve(
        request: request,
        memberType: memberType,
        role: role,
        reviewedBy: reviewedBy,
      );

  @override
  Future<void> rejectJoinRequest({
    required String clubId,
    required String requestId,
    required String reviewedBy,
  }) =>
      _dataSource.reject(
        clubId: clubId,
        requestId: requestId,
        reviewedBy: reviewedBy,
      );

  @override
  Future<void> cancelJoinRequest({
    required String clubId,
    required String requestId,
    required String userId,
  }) =>
      _dataSource.cancel(
        clubId: clubId,
        requestId: requestId,
        userId: userId,
      );
}
