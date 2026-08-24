import '../../../models/club_model.dart';
import '../../datasources/firestore/firestore_club_datasource.dart';
import '../club_repository.dart';

class FirestoreClubRepository implements ClubRepository {
  FirestoreClubRepository({FirestoreClubDataSource? dataSource})
      : _dataSource = dataSource ?? FirestoreClubDataSource();

  final FirestoreClubDataSource _dataSource;

  @override
  Future<List<Club>> fetchDiscoverableClubs() =>
      _dataSource.fetchAllClubs();

  @override
  Future<List<Club>> fetchMyClubs(String userId) =>
      _dataSource.fetchMyClubs(userId);

  @override
  Stream<List<Club>> watchDiscoverableClubs() =>
      _dataSource.watchAllClubs();

  @override
  Future<Club?> fetchClubById(String clubId, {required String userId}) =>
      _dataSource.fetchClubById(clubId, userId: userId);

  @override
  Future<bool> isUserMember(String clubId, String userId) =>
      _dataSource.isUserMember(clubId, userId);

  @override
  Future<void> updateTeamCount(String clubId, int teamCount) =>
      _dataSource.updateTeamCount(clubId, teamCount);

  @override
  Future<void> updateClubInfo(
    String clubId, {
    String? name,
    String? description,
    String? imageUrl,
    int? teamCount,
  }) =>
      _dataSource.updateClubInfo(
        clubId,
        name: name,
        description: description,
        imageUrl: imageUrl,
        teamCount: teamCount,
      );

  @override
  Future<void> createClub({
    required Club club,
    required String userId,
    required String userName,
    required Member creatorMember,
    String moderationStatus = 'active',
  }) =>
      _dataSource.createUserClub(
        club: club,
        userId: userId,
        userName: userName,
        creatorMember: creatorMember,
        moderationStatus: moderationStatus,
      );

  @override
  Future<void> addMemberViaInvite({
    required String clubId,
    required String userId,
    required Member member,
  }) =>
      _dataSource.addMemberViaInvite(
        clubId: clubId,
        userId: userId,
        member: member,
      );
}
