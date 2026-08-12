import '../../models/club_model.dart';

abstract class JoinRequestRepository {
  Future<List<JoinRequest>> fetchPendingForClub(String clubId);
  Future<JoinRequest?> fetchPendingForUser(String clubId, String userId);
  Future<String> submitJoinRequest({
    required String clubId,
    required String userId,
    required String userName,
    required String userGender,
    double? userHandicap,
    required String message,
  });
  Future<void> approveJoinRequest({
    required JoinRequest request,
    required String memberType,
    required String role,
    required String reviewedBy,
  });
  Future<void> rejectJoinRequest({
    required String clubId,
    required String requestId,
    required String reviewedBy,
  });
  Future<void> cancelJoinRequest({
    required String clubId,
    required String requestId,
    required String userId,
  });
}
