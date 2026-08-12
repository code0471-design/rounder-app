import '../../../models/club_model.dart';
import '../club_repository.dart';

class MockFinanceRepository implements FinanceRepository {
  @override
  Future<List<DuesSetting>> fetchDuesSettings(String clubId) async => [];

  @override
  Future<List<DuesPayment>> fetchDuesPayments(String clubId) async => [];

  @override
  Future<List<Transaction>> fetchTransactions(String clubId) async => [];

  @override
  Future<ClubFinanceSnapshot> fetchClubFinanceSnapshot(String clubId) async {
    return ClubFinanceSnapshot(
      clubId: clubId,
      duesSettings: const [],
      duesPayments: const [],
      transactions: const [],
    );
  }
}
