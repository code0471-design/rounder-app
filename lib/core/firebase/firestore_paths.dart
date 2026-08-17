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

  static String clubDoc(String clubId) => '$clubs/$clubId';

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
