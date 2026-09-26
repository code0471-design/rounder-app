import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/services/join_request_service.dart';

import '../core/firebase/firestore_paths.dart';
import '../firebase_options.dart';
import '../utils/d1_enqueue_policy.dart';
import '../utils/dues_d1_schedule.dart';
import 'hq_push_catalog.dart';
import 'hq_remote_settings.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('[Push] background init skip: $e');
  }
}

/// FCM 토큰 저장 + 포그라운드 로컬 알림 + Firestore 수신함.
/// 앱이 꺼져 있을 때의 잠금화면 푸시는 `functions/` 트리거가 토큰으로 발송한다.
abstract final class PushNotificationService {
  static const _androidChannelId = 'rounder_default';
  static const _androidChannelName = '라운더 알림';

  static final _local = FlutterLocalNotificationsPlugin();
  static final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _inboxSubs = [];
  static final Set<String> _seenInbox = {};
  static final Set<String> _boundIds = {};
  static StreamSubscription<String>? _tokenSub;
  static String? _lastLocalKey;
  static DateTime? _lastLocalAt;
  static bool _initialized = false;
  static bool _backgroundHandlerRegistered = false;
  static Future<void> Function()? onD1AlimtalkHint;
  static void Function({
    required String inboxId,
    required String title,
    required String body,
    required String clubId,
  })? onRemoteD1Inbox;
  static void Function(String type, String clubId)? onOpenedFromPush;
  static String? _pendingOpenType;
  static String? _pendingOpenClubId;

  /// runApp 이전에 한 번 호출. 백그라운드 핸들러 등록용.
  static void registerBackgroundHandler() {
    if (!HqRemoteSettings.available) return;
    if (_backgroundHandlerRegistered) return;
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _backgroundHandlerRegistered = true;
    } catch (e) {
      debugPrint('[Push] background handler skip: $e');
    }
  }

  static Future<void> init() async {
    if (_initialized) return;
    if (!HqRemoteSettings.available) return;
    if (Firebase.apps.isEmpty) return;

    try {
      registerBackgroundHandler();

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _local.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
        onDidReceiveNotificationResponse: (resp) {
          handleOpenedPayload(resp.payload);
        },
      );

      final androidPlugin = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _androidChannelId,
          _androidChannelName,
          importance: Importance.high,
        ),
      );

      final messaging = FirebaseMessaging.instance;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      FirebaseMessaging.onMessage.listen((msg) {
        final title = msg.notification?.title ?? msg.data['title'] ?? '라운더';
        final body = msg.notification?.body ?? msg.data['body'] ?? '';
        final type = '${msg.data['type'] ?? ''}';
        final clubId = '${msg.data['clubId'] ?? ''}';
        unawaited(showLocal(
          title: title,
          body: body,
          type: type,
          clubId: clubId,
        ));
        // D-1 푸시가 왔다고 알림톡을 다시 보내면, 앱을 켜 둔 사람만 두 통이 간다.
        if (type == HqPushCatalog.duesRequest) {
          unawaited(onD1AlimtalkHint?.call());
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        handleOpenedData(msg.data);
      });
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        handleOpenedData(initial.data);
      }

      _tokenSub ??= messaging.onTokenRefresh.listen((token) {
        unawaited(_saveToken(token, _boundIds));
      });

      _initialized = true;
      debugPrint('[Push] initialized');
      unawaited(HqPushCatalog.load());
    } catch (e, st) {
      debugPrint('[Push] init skip: $e\n$st');
    }
  }

  static Future<void> _ensurePermission() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final androidPlugin = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('[Push] permission skip: $e');
    }
  }

  static Future<void> bindUserIds(Iterable<String> userIds) async {
    if (!HqRemoteSettings.available) return;
    await init();
    final ids = userIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return;
    _boundIds
      ..clear()
      ..addAll(ids);
    unawaited(_ensurePermission());

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveToken(token, ids);
      } else {
        debugPrint('[Push] no FCM token yet');
      }
      await _listenInboxes(ids);
    } catch (e) {
      debugPrint('[Push] bind skip: $e');
    }
  }

  /// 장창현 토큰이 알라딘 아닌 모임 명단 id 로 남아 있으면 그 모임 푸시가 간다.
  static Future<void> dropForeignLeftoverFcmTokens() async {
    if (!HqRemoteSettings.available) return;
    const uid = 'kakao_5049673364';
    const aladdin = 'c_1789270673471';
    try {
      final col = FirebaseFirestore.instance.collection(FirestorePaths.fcmTokens);
      final snap = await col.get();
      for (final d in snap.docs) {
        final id = d.id;
        if (!id.contains(uid)) continue;
        if (id == uid) continue;
        if (id.contains(aladdin)) continue;
        await d.reference.delete();
        debugPrint('[Push] dropped leftover fcm $id');
      }
    } catch (e) {
      debugPrint('[Push] leftover fcm drop skip: $e');
    }
  }

  static Future<void> unbind() async {
    for (final sub in _inboxSubs) {
      await sub.cancel();
    }
    _inboxSubs.clear();
    _boundIds.clear();
    _seenInbox.clear();
  }

  static Future<void> enqueue({
    required String targetUserId,
    required String title,
    required String body,
    String? type,
    String? clubId,
    String? itemId,
  }) async {
    if (!HqRemoteSettings.available) return;
    final id = targetUserId.trim();
    if (id.isEmpty) return;
    try {
      final data = {
        'title': title,
        'body': body,
        'type': type ?? '',
        'clubId': clubId ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      };
      final col = FirebaseFirestore.instance
          .collection(FirestorePaths.pushInboxItems(id));
      final fixed = itemId?.trim() ?? '';
      if (fixed.isNotEmpty) {
        await col.doc(fixed).set(data, SetOptions(merge: true));
      } else {
        await col.add(data);
      }
    } catch (e) {
      debugPrint('[Push] enqueue skip: $e');
    }
  }

  static String _d1DocId(String scheduleId, String userId) =>
      '${scheduleId}__$userId';

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static Future<void> _deleteD1AliasDocs({
    required String Function(String userId) docIdFor,
    required String keepUserId,
    Iterable<String> aliasUserIds = const [],
  }) async {
    for (final id in aliasUserIds) {
      if (id.isEmpty || id == keepUserId) continue;
      await FirebaseFirestore.instance
          .collection(FirestorePaths.d1Queue)
          .doc(docIdFor(id))
          .delete();
    }
  }

  /// D-1 10시 리마인더. 참석 회원만 큐. enqueue=false면 대기열에서 뺀다.
  static Future<void> syncD1Reminder({
    required String scheduleId,
    required String userId,
    required DateTime roundDate,
    required String clubId,
    required String clubName,
    required String scheduleTitle,
    required bool enqueue,
    String? phone,
    String? memberName,
    String? whenText,
    String? place,
    String creatorUserId = '',
    Iterable<String> aliasUserIds = const [],
  }) async {
    if (!HqRemoteSettings.available) return;
    if (userId.isEmpty) return;
    if (D1EnqueuePolicy.isBlockedRecipient(
      name: memberName ?? '',
      userId: userId,
      clubId: clubId,
      creatorUserId: creatorUserId,
    )) {
      enqueue = false;
    }
    final doc = FirebaseFirestore.instance
        .collection(FirestorePaths.d1Queue)
        .doc(_d1DocId(scheduleId, userId));
    try {
      if (!enqueue) {
        await doc.delete();
        await _deleteD1AliasDocs(
          docIdFor: (id) => _d1DocId(scheduleId, id),
          keepUserId: userId,
          aliasUserIds: aliasUserIds,
        );
        return;
      }
      final sendOn = DateTime(roundDate.year, roundDate.month, roundDate.day)
          .subtract(const Duration(days: 1));
      final today = DateTime(DateTime.now().year, DateTime.now().month,
          DateTime.now().day);
      if (sendOn.isBefore(today)) return;
      final existing = await doc.get();
      if (existing.data()?['alimtalkSent'] == true ||
          existing.data()?['alimtalkScheduled'] == true) {
        await _deleteD1AliasDocs(
          docIdFor: (id) => _d1DocId(scheduleId, id),
          keepUserId: userId,
          aliasUserIds: aliasUserIds,
        );
        return;
      }
      final t = HqPushCatalog.byIdSync(HqPushCatalog.d1Reminder);
      await doc.set({
        'userId': userId,
        'scheduleId': scheduleId,
        'clubId': clubId,
        'sendOn': _ymd(sendOn),
        'title': HqPushCatalog.applyVars(
            t?.defaultTitle ?? '내일 라운딩 안내', {'모임명': clubName}),
        'body': HqPushCatalog.applyVars(
            t?.defaultBody ?? '내일 $clubName 라운딩이 있습니다. 참석 여부를 알려주세요.',
            {'모임명': clubName}),
        'scheduleTitle': scheduleTitle,
        'phone': phone ?? '',
        'memberName': memberName ?? '',
        'whenText': whenText ?? '',
        'place': place ?? '',
        'clubName': clubName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _deleteD1AliasDocs(
        docIdFor: (id) => _d1DocId(scheduleId, id),
        keepUserId: userId,
        aliasUserIds: aliasUserIds,
      );
    } catch (e) {
      debugPrint('[Push] d1 sync skip: $e');
    }
  }

  /// 오늘 보낼 D-1 알림톡 대기열. 이미 보낸 건 제외.
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      dueD1AlimtalkDocs() async {
    if (!HqRemoteSettings.available) return const [];
    try {
      final today = _ymd(DateTime.now());
      final snap = await FirebaseFirestore.instance
          .collection(FirestorePaths.d1Queue)
          .where('sendOn', isEqualTo: today)
          .get();
      return snap.docs.where(_d1AlimtalkOpen).toList();
    } catch (e) {
      debugPrint('[Push] d1 alimtalk query skip: $e');
      return const [];
    }
  }

  /// 오늘 이후(포함) 아직 안 보낸 D-1. 10시 예약용.
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      pendingD1AlimtalkDocs() async {
    final plan = await d1AlimtalkFlushPlan();
    return plan.openDocs;
  }

  /// lookback 이후 큐. 이미 예약된 같은 번호는 다시 보내지 않는다.
  static Future<({
    List<QueryDocumentSnapshot<Map<String, dynamic>>> openDocs,
    Set<String> claimedKeys,
  })> d1AlimtalkFlushPlan() async {
    if (!HqRemoteSettings.available) {
      return (
        openDocs: <QueryDocumentSnapshot<Map<String, dynamic>>>[],
        claimedKeys: <String>{},
      );
    }
    try {
      final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
      final lookback = _ymd(kst.subtract(const Duration(days: 1)));
      final snap = await FirebaseFirestore.instance
          .collection(FirestorePaths.d1Queue)
          .where('sendOn', isGreaterThanOrEqualTo: lookback)
          .get();
      final claimed = <String>{};
      for (final doc in snap.docs) {
        final d = doc.data();
        if (d['alimtalkSent'] == true || d['alimtalkScheduled'] == true) {
          final key = D1EnqueuePolicy.sendDedupKey(
            scheduleId: '${d['scheduleId'] ?? ''}',
            sendOn: '${d['sendOn'] ?? ''}',
            phone: '${d['phone'] ?? ''}',
            kind: '${d['kind'] ?? ''}',
            clubId: '${d['clubId'] ?? ''}',
          );
          if (D1EnqueuePolicy.phoneDigits('${d['phone'] ?? ''}').length >= 10) {
            claimed.add(key);
          }
        }
      }
      return (
        openDocs: snap.docs.where(_d1AlimtalkOpen).toList(),
        claimedKeys: claimed,
      );
    } catch (e) {
      debugPrint('[Push] d1 pending query skip: $e');
      return (
        openDocs: <QueryDocumentSnapshot<Map<String, dynamic>>>[],
        claimedKeys: <String>{},
      );
    }
  }

  static bool _d1AlimtalkOpen(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    return data['alimtalkSent'] != true && data['alimtalkScheduled'] != true;
  }

  static Future<void> markD1AlimtalkSent(
    String docId, {
    bool scheduled = false,
  }) async {
    if (!HqRemoteSettings.available || docId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection(FirestorePaths.d1Queue)
          .doc(docId)
          .set({
        'alimtalkSent': true,
        if (scheduled) 'alimtalkScheduled': true,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Push] d1 alimtalk mark skip: $e');
    }
  }

  /// 솔라피 호출 전에 선점. 두 기기·Functions가 같은 큐를 두 번 예약하지 않게 한다.
  static Future<bool> claimD1Alimtalk(String docId) async {
    if (!HqRemoteSettings.available || docId.isEmpty) return false;
    try {
      final ref = FirebaseFirestore.instance
          .collection(FirestorePaths.d1Queue)
          .doc(docId);
      return FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data() ?? {};
        if (data['alimtalkSent'] == true ||
            data['alimtalkScheduled'] == true) {
          return false;
        }
        tx.set(
          ref,
          {
            'alimtalkScheduled': true,
            'alimtalkClaimedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        return true;
      });
    } catch (e) {
      debugPrint('[Push] d1 alimtalk claim skip: $e');
      return false;
    }
  }

  static Future<void> releaseD1AlimtalkClaim(String docId) async {
    if (!HqRemoteSettings.available || docId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection(FirestorePaths.d1Queue)
          .doc(docId)
          .set({
        'alimtalkScheduled': false,
        'alimtalkClaimedAt': FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Push] d1 alimtalk release skip: $e');
    }
  }

  /// 회비 납부요청 — 납부기준일 1일 전 10시 큐. [kind]=dues 로 라운딩 D-1과 구분.
  static Future<void> syncDuesD1Reminder({
    required String settingId,
    required String userId,
    required DateTime dueDate,
    required String periodKey,
    required String clubId,
    required String clubName,
    required String amountText,
    required String dueText,
    required bool enqueue,
    String? phone,
    required String memberName,
    String creatorUserId = '',
    Iterable<String> aliasUserIds = const [],
  }) async {
    if (!HqRemoteSettings.available) return;
    if (userId.isEmpty) return;
    if (D1EnqueuePolicy.isBlockedRecipient(
      name: memberName,
      userId: userId,
      clubId: clubId,
      creatorUserId: creatorUserId,
    )) {
      enqueue = false;
    }
    final docId = DuesD1Schedule.queueDocId(
      settingId: settingId,
      userId: userId,
      periodKey: periodKey,
      clubId: clubId,
    );
    String duesDocId(String uid) => DuesD1Schedule.queueDocId(
          settingId: settingId,
          userId: uid,
          periodKey: periodKey,
          clubId: clubId,
        );
    final doc = FirebaseFirestore.instance
        .collection(FirestorePaths.d1Queue)
        .doc(docId);
    try {
      if (!enqueue) {
        await doc.delete();
        await _deleteD1AliasDocs(
          docIdFor: duesDocId,
          keepUserId: userId,
          aliasUserIds: aliasUserIds,
        );
        return;
      }
      final sendOn = DuesD1Schedule.sendOnDate(dueDate);
      final today = DateTime(DateTime.now().year, DateTime.now().month,
          DateTime.now().day);
      if (sendOn.isBefore(today)) return;
      final existing = await doc.get();
      if (existing.data()?['alimtalkSent'] == true ||
          existing.data()?['alimtalkScheduled'] == true) {
        await _deleteD1AliasDocs(
          docIdFor: duesDocId,
          keepUserId: userId,
          aliasUserIds: aliasUserIds,
        );
        return;
      }
      final t = HqPushCatalog.byIdSync(HqPushCatalog.duesRequest);
      await doc.set({
        'userId': userId,
        'scheduleId': DuesD1Schedule.scheduleIdFor(settingId),
        'kind': DuesD1Schedule.kind,
        'pushType': HqPushCatalog.duesRequest,
        'duesSettingId': settingId,
        'periodKey': periodKey,
        'clubId': clubId,
        'sendOn': DuesD1Schedule.ymd(sendOn),
        'title': HqPushCatalog.applyVars(
            t?.defaultTitle ?? '회비 납부 안내', {'모임명': clubName}),
        'body': HqPushCatalog.applyVars(
            t?.defaultBody ?? '$clubName 회비 납부를 안내드립니다. 납부 기한: $dueText',
            {'모임명': clubName, '기한': dueText}),
        'phone': phone ?? '',
        'memberName': memberName,
        'clubName': clubName,
        'amount': amountText,
        'dueText': dueText,
        if (existing.data()?['alimtalkSent'] != true) 'alimtalkSent': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _deleteD1AliasDocs(
        docIdFor: duesDocId,
        keepUserId: userId,
        aliasUserIds: aliasUserIds,
      );
    } catch (e) {
      debugPrint('[Push] dues d1 sync skip: $e');
    }
  }

  static Future<void> clearD1ForSchedule(String scheduleId) async {
    if (!HqRemoteSettings.available) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection(FirestorePaths.d1Queue)
          .where('scheduleId', isEqualTo: scheduleId)
          .get();
      for (final d in snap.docs) {
        await d.reference.delete();
      }
    } catch (e) {
      debugPrint('[Push] d1 clear skip: $e');
    }
  }

  static Future<void> submitHqBroadcast({
    required String id,
    required String title,
    required String body,
    required bool sendNow,
    required DateTime when,
  }) async {
    if (!HqRemoteSettings.available) return;
    try {
      await FirebaseFirestore.instance
          .collection(FirestorePaths.hqBroadcasts)
          .doc(id)
          .set({
        'title': title,
        'body': body,
        'sendNow': sendNow,
        'when': Timestamp.fromDate(when),
        'status': sendNow ? 'sending' : 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[Push] broadcast submit skip: $e');
    }
  }

  static bool get _appInForeground =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  /// FCM 으로 온 알림과 수신함 리스너가 같은 건을 각각 띄우던 문제.
  /// 같은 문구는 이 시간 안에 한 번만 보여 준다.
  static const _localDedupeWindow = Duration(seconds: 90);

  static bool isJoinRequestType(String? type) =>
      JoinRequestService.isJoinPushType(type);

  static void handleOpenedPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        handleOpenedData(Map<String, dynamic>.from(decoded));
      }
    } catch (e) {
      debugPrint('[Push] payload parse skip: $e');
    }
  }

  static void handleOpenedData(Map<String, dynamic> data) {
    final type = '${data['type'] ?? ''}';
    final clubId = '${data['clubId'] ?? ''}';
    if (type.isEmpty && clubId.isEmpty) return;
    if (onOpenedFromPush != null) {
      onOpenedFromPush!(type, clubId);
      return;
    }
    _pendingOpenType = type;
    _pendingOpenClubId = clubId;
  }

  static ({String type, String clubId})? consumePendingOpen() {
    final type = _pendingOpenType;
    final clubId = _pendingOpenClubId;
    if (type == null && (clubId == null || clubId.isEmpty)) return null;
    _pendingOpenType = null;
    _pendingOpenClubId = null;
    return (type: type ?? '', clubId: clubId ?? '');
  }

  static Future<void> showLocal({
    required String title,
    required String body,
    String? type,
    String? clubId,
  }) async {
    if (kIsWeb) return;
    final key = '$title|$body';
    final now = DateTime.now();
    if (_lastLocalKey == key &&
        _lastLocalAt != null &&
        now.difference(_lastLocalAt!) < _localDedupeWindow) {
      return;
    }
    _lastLocalKey = key;
    _lastLocalAt = now;
    try {
      final payload = jsonEncode({
        'type': type ?? '',
        'clubId': clubId ?? '',
      });
      await _local.show(
        now.millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannelId,
            _androidChannelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('[Push] local show skip: $e');
    }
  }

  static Future<void> _saveToken(String token, Iterable<String> userIds) async {
    if (userIds.isEmpty) return;
    final payload = {
      'token': token,
      'platform': defaultTargetPlatform.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final firestore = FirebaseFirestore.instance;
    for (final id in userIds) {
      await firestore
          .doc(FirestorePaths.fcmTokenDoc(id))
          .set(payload, SetOptions(merge: true));
    }
    debugPrint('[Push] token saved for ${userIds.join(",")}');
  }

  static Future<void> _listenInboxes(Set<String> userIds) async {
    for (final sub in _inboxSubs) {
      await sub.cancel();
    }
    _inboxSubs.clear();
    _seenInbox.clear();

    for (final userId in userIds) {
      try {
        final col = FirebaseFirestore.instance
            .collection(FirestorePaths.pushInboxItems(userId));
        _inboxSubs.add(
          col.limit(20).snapshots().listen(
            (snap) {
              for (final change in snap.docChanges) {
                if (change.type != DocumentChangeType.added) continue;
                final docId = change.doc.id;
                if (!_seenInbox.add(docId)) continue;
                final data = change.doc.data();
                final title = data?['title']?.toString() ?? '라운더';
                final body = data?['body']?.toString() ?? '';
                final type = data?['type']?.toString() ?? '';
                final clubId = data?['clubId']?.toString() ?? '';
                if (type == HqPushCatalog.d1Reminder) {
                  onRemoteD1Inbox?.call(
                    inboxId: docId,
                    title: title,
                    body: body,
                    clubId: clubId,
                  );
                }
                final created = data?['createdAt'];
                if (created is Timestamp) {
                  final age = DateTime.now().difference(created.toDate());
                  if (age.inSeconds > 8) continue;
                }
                // 앱이 화면에 없으면 FCM 알림을 OS가 이미 띄웠다.
                // 여기서 또 띄우면 같은 알림이 두 번 온다.
                if (!_appInForeground) continue;
                unawaited(showLocal(
                  title: title,
                  body: body,
                  type: type,
                  clubId: clubId,
                ));
              }
            },
            onError: (e) => debugPrint('[Push] inbox listen skip: $e'),
          ),
        );
      } catch (e) {
        debugPrint('[Push] inbox start skip: $e');
      }
    }
  }
}
