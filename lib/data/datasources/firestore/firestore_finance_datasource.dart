import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/data_exception.dart';
import '../../../core/firebase/firestore_paths.dart';
import '../../../models/club_model.dart' as domain;
import '../../mappers/finance_mapper.dart';

class FirestoreFinanceDataSource {
  FirestoreFinanceDataSource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<List<domain.DuesSetting>> fetchDuesSettings(String clubId) async {
    try {
      final snap = await _db
          .collection(FirestorePaths.clubDuesSettings(clubId))
          .get();
      return snap.docs.map(FinanceMapper.duesSettingFromFirestore).toList();
    } on FirebaseException catch (e) {
      throw NetworkDataException('dues_settings 조회 실패', cause: e);
    }
  }

  Future<List<domain.DuesPayment>> fetchDuesPayments(String clubId) async {
    try {
      final snap = await _db
          .collection(FirestorePaths.clubDuesPayments(clubId))
          .orderBy('paid_at', descending: true)
          .get();
      return snap.docs.map(FinanceMapper.duesPaymentFromFirestore).toList();
    } on FirebaseException catch (e) {
      throw NetworkDataException('dues_payments 조회 실패', cause: e);
    }
  }

  Future<List<domain.Transaction>> fetchTransactions(String clubId) async {
    try {
      final snap = await _db
          .collection(FirestorePaths.clubTransactions(clubId))
          .orderBy('date', descending: true)
          .get();
      return snap.docs.map(FinanceMapper.transactionFromFirestore).toList();
    } on FirebaseException catch (e) {
      throw NetworkDataException('transactions 조회 실패', cause: e);
    }
  }
}
