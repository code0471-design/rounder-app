import '../../models/club_model.dart';

/// Firestore 시드·로컬 폴백용 골프 모임 샘플.
/// Mock 클린 슬레이트: 시드 모임 없음 — 사용자가 만든 모임만 존재.
abstract final class ClubSampleCatalog {
  static const seedMarkerDoc = '_meta/club_catalog'; // FirestorePaths.metaClubCatalog

  static List<Club> get clubs => List.unmodifiable(_clubs);

  static final List<Club> _clubs = <Club>[];
}
