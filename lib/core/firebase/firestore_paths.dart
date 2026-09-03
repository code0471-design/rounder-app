/// Firestore 컬렉션·서브컬렉션 경로 (단일 소스)
abstract final class FirestorePaths {
  static const clubs = 'clubs';
  static const members = 'members';
  static const users = 'users';
  static const duesSettings = 'dues_settings';
  static const duesPayments = 'dues_payments';
  static const transactions = 'transactions';
  static const joinRequests = 'join_requests';
  static const userMemberships = 'user_memberships';
  static const fcmTokens = 'fcm_tokens';
  static const pushInboxCol = 'push_inbox';
  static const metaClubCatalog = '_meta/club_catalog';
  static const metaHqPush = '_meta/hq_push';
  static const metaHqAlimtalk = '_meta/hq_alimtalk';
  static const hqBroadcasts = 'hq_broadcasts';
  static const d1Queue = 'd1_queue';
  /// 모임 운영 스냅샷 (일정·공지·회비·조편성 등) — 테스터 공유용
  static const ops = 'ops';
  static const opsBundleDoc = 'bundle';
  /// 연도별 일정·조편성 overflow (`sch_2026`)
  static const opsSchedulePrefix = 'sch_';
  /// 연도별 회비·장부 overflow (`led_2026`)
  static const opsLedgerPrefix = 'led_';
  static const photos = 'photos';
  static const userOps = 'user_ops';

  static String clubDoc(String clubId) => '$clubs/$clubId';

  static String clubOpsBundle(String clubId) =>
      '${clubDoc(clubId)}/$ops/$opsBundleDoc';

  static String clubOpsScheduleYear(String clubId, int year) =>
      '${clubDoc(clubId)}/$ops/$opsSchedulePrefix$year';

  static String clubOpsLedgerYear(String clubId, int year) =>
      '${clubDoc(clubId)}/$ops/$opsLedgerPrefix$year';

  static String clubPhotos(String clubId) => '${clubDoc(clubId)}/$photos';

  static String clubPhotoDoc(String clubId, String photoId) =>
      '${clubPhotos(clubId)}/$photoId';

  static String userOpsBundle(String userId) =>
      '$users/$userId/$userOps/$opsBundleDoc';

  static String clubMembers(String clubId) =>
      '${clubDoc(clubId)}/$members';

  static String clubMemberDoc(String clubId, String memberId) =>
      '${clubMembers(clubId)}/$memberId';

  static String clubDuesSettings(String clubId) =>
      '${clubDoc(clubId)}/$duesSettings';

  static String clubDuesPayments(String clubId) =>
      '${clubDoc(clubId)}/$duesPayments';

  static String clubTransactions(String clubId) =>
      '${clubDoc(clubId)}/$transactions';

  static String clubJoinRequests(String clubId) =>
      '${clubDoc(clubId)}/$joinRequests';

  static String clubJoinRequestDoc(String clubId, String requestId) =>
      '${clubJoinRequests(clubId)}/$requestId';

  static String userMembershipDoc(String userId, String clubId) =>
      '${userMemberships}/${userId}_$clubId';

  static String fcmTokenDoc(String userId) => '$fcmTokens/$userId';

  static String pushInboxItems(String userId) => '$pushInboxCol/$userId/items';
}
