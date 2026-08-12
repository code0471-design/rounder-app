import '../../../models/club_model.dart';
import '../../datasources/firestore/firestore_finance_datasource.dart';
import '../club_repository.dart';

class FirestoreFinanceRepository implements FinanceRepository {
  FirestoreFinanceRepository({FirestoreFinanceDataSource? dataSource})
      : _dataSource = dataSource ?? FirestoreFinanceDataSource();

  final FirestoreFinanceDataSource _dataSource;

  @override
  Future<List<DuesSetting>> fetchDuesSettings(String clubId) =>
      _dataSource.fetchDuesSettings(clubId);

  @override
  Future<List<DuesPayment>> fetchDuesPayments(String clubId) =>
      _dataSource.fetchDuesPayments(clubId);

  @override
  Future<List<Transaction>> fetchTransactions(String clubId) =>
      _dataSource.fetchTransactions(clubId);

  @override
  Future<ClubFinanceSnapshot> fetchClubFinanceSnapshot(String clubId) async {
    final results = await Future.wait([
      fetchDuesSettings(clubId),
      fetchDuesPayments(clubId),
      fetchTransactions(clubId),
    ]);
    return ClubFinanceSnapshot(
      clubId: clubId,
      duesSettings: results[0] as List<DuesSetting>,
      duesPayments: results[1] as List<DuesPayment>,
      transactions: results[2] as List<Transaction>,
    );
  }
}
