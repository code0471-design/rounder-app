import '../../../models/club_model.dart';
import 'mock_data_store.dart';
import '../club_repository.dart';

class MockMemberRepository implements MemberRepository {
  MockMemberRepository(this._store);

  final MockDataStore _store;

  @override
  Future<List<Member>> fetchMembers(String clubId) async =>
      _store.membersOf(clubId);

  @override
  Stream<List<Member>> watchMembers(String clubId) async* {
    yield _store.membersOf(clubId);
  }
}
