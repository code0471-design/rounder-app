import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/firebase/firestore_paths.dart';
import '../firebase_options.dart';
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
        unawaited(showLocal(title: title, body: body));
      });

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
  }) async {
    if (!HqRemoteSettings.available) return;
    final id = targetUserId.trim();
    if (id.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection(FirestorePaths.pushInboxItems(id))
          .add({
        'title': title,
        'body': body,
        'type': type ?? '',
        'clubId': clubId ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
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

  /// 참석 확정 시 D-1 10시 리마인더 예약. 불참이면 삭제.
  static Future<void> syncD1Reminder({
    required String scheduleId,
    required String userId,
    required DateTime roundDate,
    required String clubId,
    required String clubName,
    required String scheduleTitle,
    required bool attending,
  }) async {
    if (!HqRemoteSettings.available) return;
    final doc = FirebaseFirestore.instance
        .collection(FirestorePaths.d1Queue)
        .doc(_d1DocId(scheduleId, userId));
    try {
      if (!attending) {
        await doc.delete();
        return;
      }
      final sendOn = DateTime(roundDate.year, roundDate.month, roundDate.day)
          .subtract(const Duration(days: 1));
      final today = DateTime(DateTime.now().year, DateTime.now().month,
          DateTime.now().day);
      if (sendOn.isBefore(today)) return;
      final t = HqPushCatalog.byIdSync(HqPushCatalog.d1Reminder);
      await doc.set({
        'userId': userId,
        'scheduleId': scheduleId,
        'clubId': clubId,
        'sendOn': _ymd(sendOn),
        'title': HqPushCatalog.applyVars(
            t?.defaultTitle ?? '내일 라운딩 안내', {'모임명': clubName}),
        'body': HqPushCatalog.applyVars(
            t?.defaultBody ?? '내일 $clubName 라운딩이 있습니다. 늦지 않게 준비해 주세요.',
            {'모임명': clubName}),
        'scheduleTitle': scheduleTitle,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[Push] d1 sync skip: $e');
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

  static Future<void> showLocal({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    final key = '$title|$body';
    final now = DateTime.now();
    if (_lastLocalKey == key &&
        _lastLocalAt != null &&
        now.difference(_lastLocalAt!) < const Duration(seconds: 4)) {
      return;
    }
    _lastLocalKey = key;
    _lastLocalAt = now;
    try {
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
                final created = change.doc.data()?['createdAt'];
                if (created is Timestamp) {
                  final age = DateTime.now().difference(created.toDate());
                  if (age.inSeconds > 8) continue;
                }
                final title = change.doc.data()?['title']?.toString() ?? '라운더';
                final body = change.doc.data()?['body']?.toString() ?? '';
                unawaited(showLocal(title: title, body: body));
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
