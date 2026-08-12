import 'package:flutter/foundation.dart';

import '../../data/datasources/firestore/firestore_club_datasource.dart';
import '../data/club_sample_catalog.dart';

/// Firestore clubs 컬렉션이 비어 있을 때 샘플 모임 데이터 시드
class ClubSeedService {
  ClubSeedService({FirestoreClubDataSource? dataSource})
      : _dataSource = dataSource ?? FirestoreClubDataSource();

  final FirestoreClubDataSource _dataSource;

  /// 비어 있고 카탈로그에 샘플이 있을 때만 업로드. true = 시드 수행됨
  Future<bool> seedIfEmpty() async {
    try {
      // 클린 슬레이트: 샘플 카탈로그가 비어 있으면 절대 시드하지 않음
      if (ClubSampleCatalog.clubs.isEmpty) {
        debugPrint('[ClubSeedService] 샘플 카탈로그 비어 있음 — 시드 안 함');
        return false;
      }
      final empty = await _dataSource.isCatalogEmpty();
      if (!empty) {
        debugPrint('[ClubSeedService] clubs 컬렉션에 데이터 있음 — 시드 생략');
        return false;
      }

      debugPrint('[ClubSeedService] clubs 컬렉션 비어 있음 — 샘플 데이터 업로드');
      await _dataSource.seedSampleClubs(ClubSampleCatalog.clubs);
      return true;
    } catch (e, st) {
      debugPrint('[ClubSeedService] 시드 실패: $e\n$st');
      return false;
    }
  }
}
