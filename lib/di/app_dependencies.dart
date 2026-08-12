import '../data/repositories/admin_repository.dart';
import '../data/repositories/club_repository.dart';
import '../data/repositories/firestore/firestore_admin_repository.dart';
import '../data/repositories/firestore/firestore_club_repository.dart';
import '../data/repositories/firestore/firestore_finance_repository.dart';
import '../data/repositories/firestore/firestore_member_repository.dart';
import '../data/repositories/firestore/firestore_join_request_repository.dart';
import '../data/repositories/join_request_repository.dart';
import '../data/repositories/mock/mock_admin_repository.dart';
import '../data/repositories/mock/mock_club_repository.dart';
import '../data/repositories/mock/mock_data_store.dart';
import '../data/repositories/mock/mock_finance_repository.dart';
import '../data/repositories/mock/mock_join_request_repository.dart';
import '../data/repositories/mock/mock_member_repository.dart';
import '../domain/services/app_data_bootstrap_service.dart';
import '../domain/services/club_seed_service.dart';
import '../domain/services/finance/balance_ledger_service.dart';
import '../domain/services/finance/dues_ledger_service.dart';

/// 앱 전역 의존성 (Singleton — settings.json 미사용)
final class AppDependencies {
  AppDependencies._();

  static final AppDependencies instance = AppDependencies._();

  late final ClubRepository clubRepository;
  late final MemberRepository memberRepository;
  late final FinanceRepository financeRepository;
  late final JoinRequestRepository joinRequestRepository;
  late final AdminRepository adminRepository;

  late final AppDataBootstrapService bootstrapService;
  late final ClubSeedService? clubSeedService;
  late final DuesLedgerService duesLedgerService;
  late final BalanceLedgerService balanceLedgerService;

  MockDataStore? _mockDataStore;

  AppBootstrapSnapshot? lastBootstrap;

  bool _initialized = false;
  bool _offlineMock = false;

  bool get isInitialized => _initialized;
  bool get isOfflineMockMode => _offlineMock;
  MockDataStore? get mockDataStore => _mockDataStore;

  void init({bool offlineMock = false}) {
    if (_initialized) return;
    _initialized = true;
    _offlineMock = offlineMock;

    if (offlineMock) {
      _mockDataStore = MockDataStore();
      clubRepository = MockClubRepository(_mockDataStore!);
      memberRepository = MockMemberRepository(_mockDataStore!);
      financeRepository = MockFinanceRepository();
      joinRequestRepository = MockJoinRequestRepository(_mockDataStore!);
      adminRepository = MockAdminRepository(_mockDataStore!);
      clubSeedService = null;
    } else {
      clubRepository = FirestoreClubRepository();
      memberRepository = FirestoreMemberRepository();
      financeRepository = FirestoreFinanceRepository();
      joinRequestRepository = FirestoreJoinRequestRepository();
      adminRepository = FirestoreAdminRepository();
      clubSeedService = ClubSeedService();
    }

    bootstrapService = AppDataBootstrapService(
      clubRepository: clubRepository,
      memberRepository: memberRepository,
      financeRepository: financeRepository,
    );
    duesLedgerService = DuesLedgerService();
    balanceLedgerService = BalanceLedgerService();
  }

  Future<bool> ensureClubCatalogSeeded() async {
    if (_offlineMock) return false;
    return clubSeedService!.seedIfEmpty();
  }

  Future<AppBootstrapSnapshot> bootstrapForUser(String userId) async {
    if (_offlineMock) {
      final myClubs = await clubRepository.fetchMyClubs(userId);
      final discoverable = await clubRepository.fetchDiscoverableClubs();
      lastBootstrap = AppBootstrapSnapshot(
        userId: userId,
        myClubs: myClubs,
        discoverableClubs: discoverable,
        membersByClubId: const {},
        financeByClubId: const {},
        loadedAt: DateTime.now(),
      );
      return lastBootstrap!;
    }

    await ensureClubCatalogSeeded();
    lastBootstrap = await bootstrapService.loadForUser(userId);
    return lastBootstrap!;
  }
}
