import '../../../models/club_model.dart';
import '../../datasources/firestore/firestore_member_datasource.dart';
import '../club_repository.dart';

class FirestoreMemberRepository implements MemberRepository {
  FirestoreMemberRepository({FirestoreMemberDataSource? dataSource})
      : _dataSource = dataSource ?? FirestoreMemberDataSource();

  final FirestoreMemberDataSource _dataSource;

  @override
  Future<List<Member>> fetchMembers(String clubId) =>
      _dataSource.fetchMembers(clubId);

  @override
  Stream<List<Member>> watchMembers(String clubId) =>
      _dataSource.watchMembers(clubId);
}
