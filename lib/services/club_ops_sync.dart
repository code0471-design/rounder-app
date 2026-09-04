import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/firebase/firestore_paths.dart';
import '../di/app_dependencies.dart';
import 'club_data_codec.dart';
import 'club_ops_overflow.dart';

/// 모임 운영 데이터를 rounder-staging Firestore에 공유한다.
///
/// ClubProvider의 로컬 번들 중 **클럽 스코프** 필드를
/// `clubs/{clubId}/ops/bundle` 에 올리고, 다른 기기에서 내려받는다.
class ClubOpsSync {
  ClubOpsSync._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static final Map<String, StreamSubscription<DocumentSnapshot>> _clubSubs =
      {};
  static StreamSubscription<DocumentSnapshot>? _userSub;

  static bool get _enabled =>
      AppDependencies.instance.isInitialized &&
      !AppDependencies.instance.isOfflineMockMode;

  /// Firestore 문서 ~1MiB 한도 직전. 이 값을 넘기면 push가 실패할 수 있다.
  static const int opsBundleSoftLimitBytes = 900000;

  /// data URI 사진이 이 글자 수를 넘으면 Firestore에는 메타만 올린다.
  static const int photoDataUriMaxChars = 700000;

  /// 로컬 전체 번들에서 한 모임의 운영 데이터만 잘라 Firestore에 저장.
  static Future<void> pushClubOps({
    required String clubId,
    required ClubDataBundle bundle,
  }) async {
    if (!_enabled || clubId.isEmpty) return;
    try {
      final full = ClubDataCodec.encode(bundle);
      final slice = _sliceForClub(full, clubId);
      final photos = (slice.remove('photos') as List<dynamic>? ?? []);
      slice['updatedAtClient'] = DateTime.now().toIso8601String();
      slice['updatedAt'] = FieldValue.serverTimestamp();
      slice['schema'] = ClubDataCodec.currentVersion;

      // 로컬 회비가 비어 원격만 있는 경우 merge:false 로 원격 납부를 지워버리지 않음
      final existing =
          await _db.doc(FirestorePaths.clubOpsBundle(clubId)).get();
      if (existing.exists && existing.data() != null) {
        final remote = Map<String, dynamic>.from(existing.data()!);
        await _attachOverflowDocs(clubId, remote);
        final localPayments = slice['duesPayments'] as List? ?? const [];
        final remotePayments = remote['duesPayments'] as List? ?? const [];
        if (localPayments.isEmpty && remotePayments.isNotEmpty) {
          slice['duesPayments'] = remotePayments;
        }
        final localSettings = slice['duesSettings'] as List? ?? const [];
        final remoteSettings = remote['duesSettings'] as List? ?? const [];
        if (localSettings.isEmpty && remoteSettings.isNotEmpty) {
          slice['duesSettings'] = remoteSettings;
        }
        // 초대 가입자가 자기 명단만 들고 올리면 기존 회원이 지워진다 → 합친다
        final localMembers = slice['members'] as List? ?? const [];
        final remoteMembers = remote['members'] as List? ?? const [];
        slice['members'] = _mergeById(remoteMembers, localMembers);

        final localSchedules = slice['schedules'] as List? ?? const [];
        final remoteSchedules = remote['schedules'] as List? ?? const [];
        if (localSchedules.isEmpty && remoteSchedules.isNotEmpty) {
          slice['schedules'] = remoteSchedules;
        }
        final localAnnounce = slice['announcements'] as List? ?? const [];
        final remoteAnnounce = remote['announcements'] as List? ?? const [];
        if (localAnnounce.isEmpty && remoteAnnounce.isNotEmpty) {
          slice['announcements'] = remoteAnnounce;
        }
        final localTx = slice['transactions'] as List? ?? const [];
        final remoteTx = remote['transactions'] as List? ?? const [];
        if (localTx.isEmpty && remoteTx.isNotEmpty) {
          slice['transactions'] = remoteTx;
        }
      }

      final previousYears = ClubOpsOverflow.overflowIndex(
        scheduleYears: const [],
        ledgerYears: const [],
      );
      if (existing.exists && existing.data() != null) {
        final prev = existing.data()!['overflowYears'];
        if (prev is Map) {
          previousYears['sch'] = ClubOpsOverflow.yearsOf(prev['sch']);
          previousYears['led'] = ClubOpsOverflow.yearsOf(prev['led']);
        }
      }

      final schYears = ClubOpsOverflow.splitScheduleYears(slice);
      final ledYears = ClubOpsOverflow.splitLedgerYears(slice);
      ClubOpsOverflow.stripHeavyFields(slice);
      slice['overflowYears'] = ClubOpsOverflow.overflowIndex(
        scheduleYears: schYears.keys,
        ledgerYears: ledYears.keys,
      );

      final bundleBytes = estimateJsonBytes(slice);
      if (bundleBytes > opsBundleSoftLimitBytes) {
        debugPrint(
          '[ClubOpsSync] WARNING ops bundle ${bundleBytes}B > '
          '$opsBundleSoftLimitBytes soft limit club=$clubId '
          'after overflow split — Firestore ~1MB doc limit may reject this push',
        );
      }

      await _pushOverflowDocs(clubId, schYears, ledYears, previousYears);

      await _db
          .doc(FirestorePaths.clubOpsBundle(clubId))
          .set(slice, SetOptions(merge: false));

      // 사진은 문서 1MB 한도 때문에 건별 저장
      await _pushPhotos(clubId, photos);
      debugPrint(
        '[ClubOpsSync] pushed club=$clubId bytes=$bundleBytes photos=${photos.length}',
      );
    } catch (e, st) {
      debugPrint('[ClubOpsSync] pushClubOps fail ($clubId): $e\n$st');
    }
  }

  /// 사진 Firestore 문서용 — 초대형 data URI는 메타만 남긴다.
  @visibleForTesting
  static Map<String, dynamic> preparePhotoMapForFirestore(
    Map<String, dynamic> raw,
  ) {
    final m = Map<String, dynamic>.from(raw);
    final imageUrl = m['imageUrl'] as String? ?? '';
    if (imageUrl.startsWith('data:') &&
        imageUrl.length > photoDataUriMaxChars) {
      m['imageUrl'] = '';
      m['imageOmitted'] = true;
    }
    return m;
  }

  /// 내 모임들 + 데이터가 있는 클럽 id 전부 전부 push.
  static Future<void> pushAllRelevant(
    ClubDataBundle bundle, {
    String? authUserId,
  }) async {
    if (!_enabled) return;
    final ids = <String>{
      ...bundle.myClubs.map((c) => c.id),
      ...bundle.schedules.map((s) => s.clubId),
      ...bundle.announcements
          .map((a) => a.clubId)
          .whereType<String>(),
      ...bundle.photos.map((p) => p.clubId),
      ...bundle.duesSettings
          .map((d) => d.clubId)
          .whereType<String>(),
      ...bundle.alimtalkSettings.keys,
    };
    for (final id in ids) {
      if (id.isEmpty) continue;
      await pushClubOps(clubId: id, bundle: bundle);
    }
    await pushUserOps(bundle: bundle, authUserId: authUserId);
  }

  /// 계정 단위 (인앱 알림 등)
  static Future<void> deleteUserOps(String authUserId) async {
    if (!_enabled || authUserId.isEmpty) return;
    try {
      await _db.doc(FirestorePaths.userOpsBundle(authUserId)).delete();
    } catch (e) {
      debugPrint('[ClubOpsSync] deleteUserOps fail: $e');
    }
  }

  static Future<void> deleteUserMemberships(String userId) async {
    if (!_enabled || userId.isEmpty) return;
    try {
      final snap = await _db
          .collection(FirestorePaths.userMemberships)
          .where('user_id', isEqualTo: userId)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('[ClubOpsSync] deleteUserMemberships fail: $e');
    }
  }

  static Future<void> pushUserOps({
    required ClubDataBundle bundle,
    String? authUserId,
  }) async {
    if (!_enabled) return;
    final uid = authUserId;
    if (uid == null || uid.isEmpty) return;
    try {
      final full = ClubDataCodec.encode(bundle);
      final payload = <String, dynamic>{
        'appNotifications': full['appNotifications'],
        'joinRequests': full['joinRequests'],
        'updatedAtClient': DateTime.now().toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
        'schema': ClubDataCodec.currentVersion,
      };
      await _db
          .doc(FirestorePaths.userOpsBundle(uid))
          .set(payload, SetOptions(merge: false));
    } catch (e) {
      debugPrint('[ClubOpsSync] pushUserOps fail: $e');
    }
  }

  /// Firestore → 로컬 번들 병합 (서버가 더 최신이면 서버 우선).
  static Future<ClubDataBundle?> pullMergeClub({
    required String clubId,
    required ClubDataBundle local,
  }) async {
    if (!_enabled || clubId.isEmpty) return null;
    try {
      final snap =
          await _db.doc(FirestorePaths.clubOpsBundle(clubId)).get();
      if (!snap.exists || snap.data() == null) {
        // 서버 비어 있으면 로컬을 최초 업로드
        await pushClubOps(clubId: clubId, bundle: local);
        return null;
      }
      final remote = Map<String, dynamic>.from(snap.data()!);
      await _attachOverflowDocs(clubId, remote);
      final photosSnap =
          await _db.collection(FirestorePaths.clubPhotos(clubId)).get();
      remote['photos'] = photosSnap.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data());
        m['id'] = d.id;
        return m;
      }).toList();

      final merged = _mergeClubIntoBundle(local, clubId, remote);
      debugPrint('[ClubOpsSync] pulled club=$clubId');
      return merged;
    } catch (e, st) {
      debugPrint('[ClubOpsSync] pullMergeClub fail ($clubId): $e\n$st');
      return null;
    }
  }

  static Future<ClubDataBundle?> pullMergeUser({
    required String authUserId,
    required ClubDataBundle local,
  }) async {
    if (!_enabled || authUserId.isEmpty) return null;
    try {
      final snap =
          await _db.doc(FirestorePaths.userOpsBundle(authUserId)).get();
      if (!snap.exists || snap.data() == null) {
        await pushUserOps(bundle: local, authUserId: authUserId);
        return null;
      }
      final remote = Map<String, dynamic>.from(snap.data()!);
      final encoded = ClubDataCodec.encode(local);
      if (remote['appNotifications'] is List) {
        encoded['appNotifications'] = remote['appNotifications'];
      }
      if (remote['joinRequests'] is List) {
        encoded['joinRequests'] = _mergeJoinRequests(
          encoded['joinRequests'] as List? ?? const [],
          remote['joinRequests'] as List,
        );
      }
      return ClubDataCodec.decode(encoded);
    } catch (e) {
      debugPrint('[ClubOpsSync] pullMergeUser fail: $e');
      return null;
    }
  }

  /// 선택 모임 ops 실시간 구독.
  static void watchClub(
    String clubId,
    void Function(Map<String, dynamic> remote) onData,
  ) {
    if (!_enabled || clubId.isEmpty) return;
    unawaited(_clubSubs.remove(clubId)?.cancel());
    _clubSubs[clubId] = _db
        .doc(FirestorePaths.clubOpsBundle(clubId))
        .snapshots()
        .listen((snap) async {
      if (!snap.exists || snap.data() == null) return;
      final remote = Map<String, dynamic>.from(snap.data()!);
      try {
        await _attachOverflowDocs(clubId, remote);
        final photosSnap =
            await _db.collection(FirestorePaths.clubPhotos(clubId)).get();
        remote['photos'] = photosSnap.docs.map((d) {
          final m = Map<String, dynamic>.from(d.data());
          m['id'] = d.id;
          return m;
        }).toList();
      } catch (_) {}
      onData(remote);
    }, onError: (e) {
      debugPrint('[ClubOpsSync] watchClub error ($clubId): $e');
    });
  }

  static void stopWatchClub(String clubId) {
    unawaited(_clubSubs.remove(clubId)?.cancel());
  }

  static void stopAllWatches() {
    for (final s in _clubSubs.values) {
      unawaited(s.cancel());
    }
    _clubSubs.clear();
    unawaited(_userSub?.cancel());
    _userSub = null;
  }

  // ── helpers ─────────────────────────────────────────────

  static final Set<String> _deletedPhotoIds = {};

  /// 로컬 삭제 직후 원격 watch가 사진을 되살리지 않게 동기적으로 표시.
  static void markPhotoDeleted(String photoId) {
    if (photoId.isEmpty) return;
    _deletedPhotoIds.add(photoId);
  }

  static bool isPhotoDeleted(String photoId) =>
      photoId.isNotEmpty && _deletedPhotoIds.contains(photoId);

  /// 로컬 삭제 직후 Firestore에서도 바로 지워 원격 watch가 사진을 되살리지 않게 한다.
  static Future<void> deletePhotoDoc(String clubId, String photoId) async {
    if (!_enabled || clubId.isEmpty || photoId.isEmpty) return;
    markPhotoDeleted(photoId);
    try {
      await _db.collection(FirestorePaths.clubPhotos(clubId)).doc(photoId).delete();
      debugPrint('[ClubOpsSync] deleted photo $photoId club=$clubId');
    } catch (e) {
      debugPrint('[ClubOpsSync] photo delete fail $photoId: $e');
    }
  }

  static Future<void> _pushPhotos(
    String clubId,
    List<dynamic> photos,
  ) async {
    final col = _db.collection(FirestorePaths.clubPhotos(clubId));
    final existing = await col.get();
    final keepIds = <String>{};
    for (final raw in photos) {
      if (raw is! Map) continue;
      final prepared = preparePhotoMapForFirestore(
        Map<String, dynamic>.from(raw),
      );
      final id = prepared['id'] as String?;
      if (id == null || id.isEmpty) continue;
      if (_deletedPhotoIds.contains(id)) continue;
      keepIds.add(id);
      if (prepared['imageOmitted'] == true) {
        debugPrint(
          '[ClubOpsSync] photo $id too large for Firestore, meta only',
        );
      }
      prepared['clubId'] = clubId;
      prepared['updatedAt'] = FieldValue.serverTimestamp();
      try {
        await col.doc(id).set(prepared, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[ClubOpsSync] photo push fail $id: $e');
      }
    }
    for (final d in existing.docs) {
      if (!keepIds.contains(d.id) || _deletedPhotoIds.contains(d.id)) {
        try {
          await d.reference.delete();
          _deletedPhotoIds.remove(d.id);
        } catch (_) {}
      }
    }
  }

  static Map<String, dynamic> _sliceForClub(
    Map<String, dynamic> full,
    String clubId,
  ) {
    bool clubField(dynamic item) {
      if (item is! Map) return false;
      return item['clubId'] == clubId;
    }

    bool memberOfClub(dynamic item) {
      if (item is! Map) return false;
      final id = item['id'] as String? ?? '';
      return id == 'm_creator_$clubId' || id.startsWith('m_${clubId}_');
    }

    final scheduleIds = <String>{};
    final schedules = (full['schedules'] as List? ?? [])
        .where(clubField)
        .map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          scheduleIds.add(m['id'] as String? ?? '');
          return m;
        })
        .toList();

    final groupAssignments = <String, dynamic>{};
    final ga = full['groupAssignments'];
    if (ga is Map) {
      ga.forEach((k, v) {
        if (scheduleIds.contains(k)) groupAssignments[k as String] = v;
      });
    }

    final waiting = (full['waitingList'] as List? ?? []).where((w) {
      if (w is! Map) return false;
      return scheduleIds.contains(w['scheduleId']);
    }).toList();

    final alimtalk = <String, dynamic>{};
    final ats = full['alimtalkSettings'];
    if (ats is Map && ats[clubId] != null) {
      alimtalk[clubId] = ats[clubId];
    }

    final members = (full['members'] as List? ?? []).where(memberOfClub).toList();
    final memberIds = members
        .map((m) => (m as Map)['id'] as String?)
        .whereType<String>()
        .toSet();

    final pointEvents = <String, dynamic>{};
    final pe = full['pointEvents'];
    if (pe is Map) {
      pe.forEach((k, v) {
        if (memberIds.contains(k)) pointEvents[k as String] = v;
      });
    }

    final duesSettings = (full['duesSettings'] as List? ?? [])
        .where((e) => e is Map && e['clubId'] == clubId)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final duesSettingIds =
        duesSettings.map((d) => d['id'] as String?).whereType<String>().toSet();

    final duesPayments = (full['duesPayments'] as List? ?? []).where((p) {
      if (p is! Map) return false;
      return duesSettingIds.contains(p['duesSettingId']);
    }).toList();

    final awardRecords = (full['awardRecords'] as List? ?? []).where((a) {
      if (a is! Map) return false;
      return scheduleIds.contains(a['scheduleId']);
    }).toList();

    // ActivityItem에는 clubId가 없음 — 선택 모임 동기화 시 전체 유지(유실 방지)
    // 클럽 전용 피드로 쪼개기 전까지는 번들에 그대로 둠(아래 merge에서 원격 우선 교체 안 함)

    return {
      'clubId': clubId,
      'schedules': schedules,
      'announcements':
          (full['announcements'] as List? ?? []).where(clubField).toList(),
      'members': members,
      'activities': full['activities'] ?? [],
      'duesSettings': duesSettings,
      'duesPayments': duesPayments,
      'paymentRequests':
          (full['paymentRequests'] as List? ?? []).where(clubField).toList(),
      'transactions':
          (full['transactions'] as List? ?? []).where(clubField).toList(),
      'photos': (full['photos'] as List? ?? []).where(clubField).toList(),
      'groupAssignments': groupAssignments,
      'waitingList': waiting,
      'alimtalkSettings': alimtalk,
      'adApplications':
          (full['adApplications'] as List? ?? []).where(clubField).toList(),
      'adNotifications': full['adNotifications'] ?? [],
      'sponsorApplications': (full['sponsorApplications'] as List? ?? [])
          .where(clubField)
          .toList(),
      'awardRecords': awardRecords,
      'thankYouMessages': full['thankYouMessages'] ?? [],
      'pointEvents': pointEvents,
    };
  }

  static ClubDataBundle _mergeClubIntoBundle(
    ClubDataBundle local,
    String clubId,
    Map<String, dynamic> remote,
  ) {
    final encoded = ClubDataCodec.encode(local);

    List<dynamic> replaceClubList(List? localList, List? remoteList) {
      final kept = <dynamic>[
        ...(localList ?? []).where((e) => e is Map && e['clubId'] != clubId),
      ];
      for (final e in remoteList ?? const []) {
        if (e is Map) {
          kept.add(Map<String, dynamic>.from(e));
        } else {
          kept.add(e);
        }
      }
      return kept;
    }

    final scheduleIds = (remote['schedules'] as List? ?? [])
        .whereType<Map>()
        .map((s) => s['id'] as String?)
        .whereType<String>()
        .toSet();

    if (remote.containsKey('schedules')) {
      encoded['schedules'] = replaceClubList(
        encoded['schedules'] as List?,
        remote['schedules'] as List?,
      );
    }
    encoded['announcements'] = replaceClubList(
      encoded['announcements'] as List?,
      remote['announcements'] as List?,
    );
    encoded['duesSettings'] = _mergeClubScopedById(
      encoded['duesSettings'] as List?,
      remote['duesSettings'] as List?,
      clubId,
    );
    if (remote.containsKey('paymentRequests')) {
      encoded['paymentRequests'] = replaceClubList(
        encoded['paymentRequests'] as List?,
        remote['paymentRequests'] as List?,
      );
    }
    // 회비와 동일: 잔고용 거래는 id 합집합. 원격이 비면 로컬 수입/지출 유지
    if (remote.containsKey('transactions')) {
      encoded['transactions'] = _mergeClubScopedById(
        encoded['transactions'] as List?,
        remote['transactions'] as List?,
        clubId,
      );
    }
    // photos 키 없음 = 사진 컬렉션 fetch 실패 → 로컬 유지 (덮어쓰기 금지)
    if (remote.containsKey('photos')) {
      encoded['photos'] = _mergeClubPhotos(
        encoded['photos'] as List?,
        remote['photos'] as List?,
        clubId,
      );
    }
    encoded['adApplications'] = replaceClubList(
      encoded['adApplications'] as List?,
      remote['adApplications'] as List?,
    );
    encoded['sponsorApplications'] = replaceClubList(
      encoded['sponsorApplications'] as List?,
      remote['sponsorApplications'] as List?,
    );

    if (remote.containsKey('duesPayments')) {
      encoded['duesPayments'] = _mergeDuesPayments(
        encoded['duesPayments'] as List?,
        remote['duesPayments'] as List?,
        remote['duesSettings'] as List?,
      );
    }

    final awards = <dynamic>[
      ...(encoded['awardRecords'] as List? ?? []).where(
          (a) => a is! Map || !scheduleIds.contains(a['scheduleId'])),
      ..._asDynamicMaps(remote['awardRecords']),
    ];
    encoded['awardRecords'] = awards;

    encoded['activities'] = _mergeById(
      encoded['activities'] as List? ?? const [],
      remote['activities'] as List? ?? const [],
    );
    encoded['thankYouMessages'] = _mergeById(
      encoded['thankYouMessages'] as List? ?? const [],
      remote['thankYouMessages'] as List? ?? const [],
    );
    encoded['adNotifications'] = _mergeById(
      encoded['adNotifications'] as List? ?? const [],
      remote['adNotifications'] as List? ?? const [],
    );

    // members: 합집합. 원격만 쓰면 초대 가입 직후 로컬 명단이 사라진다.
    encoded['members'] = _mergeById(
      encoded['members'] as List? ?? const [],
      _asDynamicMaps(remote['members']),
    );

    // groupAssignments: replace keys for this club's schedules
    final ga = Map<String, dynamic>.from(
      (encoded['groupAssignments'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v),
          ) ??
          {},
    );
    ga.removeWhere((k, _) => scheduleIds.contains(k));
    final remoteGa = remote['groupAssignments'];
    if (remoteGa is Map) {
      remoteGa.forEach((k, v) => ga[k.toString()] = v);
    }
    encoded['groupAssignments'] = ga;

    final waiting = <dynamic>[
      ...(encoded['waitingList'] as List? ?? []).where(
          (w) => w is! Map || !scheduleIds.contains(w['scheduleId'])),
      ..._asDynamicMaps(remote['waitingList']),
    ];
    encoded['waitingList'] = waiting;

    final ats = Map<String, dynamic>.from(
      (encoded['alimtalkSettings'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v),
          ) ??
          {},
    );
    final remoteAts = remote['alimtalkSettings'];
    if (remoteAts is Map && remoteAts[clubId] != null) {
      ats[clubId] = remoteAts[clubId];
    }
    encoded['alimtalkSettings'] = ats;

    final pe = Map<String, dynamic>.from(
      (encoded['pointEvents'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v),
          ) ??
          {},
    );
    final remotePe = remote['pointEvents'];
    if (remotePe is Map) {
      remotePe.forEach((k, v) => pe[k.toString()] = v);
    }
    encoded['pointEvents'] = pe;

    return ClubDataCodec.decode(encoded);
  }

  static List<Map<String, dynamic>> _asDynamicMaps(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static List<dynamic> _mergeById(List local, List remote) {
    final byId = <String, Map<String, dynamic>>{};
    for (final e in [...local, ...remote]) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final id = m['id'] as String?;
      if (id == null) continue;
      byId[id] = m;
    }
    return byId.values.toList();
  }

  /// clubId 스코프 목록을 id 기준으로 합친다. 원격이 비어 있으면 로컬 유지.
  static List<dynamic> _mergeClubScopedById(
    List? localList,
    List? remoteList,
    String clubId,
  ) {
    final keptOther = <dynamic>[
      ...(localList ?? []).where((e) => e is Map && e['clubId'] != clubId),
    ];
    final remoteMaps = _asDynamicMaps(remoteList);
    if (remoteMaps.isEmpty) {
      return [
        ...keptOther,
        ...(localList ?? []).where((e) => e is Map && e['clubId'] == clubId),
      ];
    }
    final byId = <String, Map<String, dynamic>>{};
    for (final e in localList ?? const []) {
      if (e is! Map) continue;
      if (e['clubId'] != clubId) continue;
      final id = e['id'] as String?;
      if (id == null || id.isEmpty) continue;
      byId[id] = Map<String, dynamic>.from(e);
    }
    for (final m in remoteMaps) {
      final id = m['id'] as String?;
      if (id == null || id.isEmpty) continue;
      byId[id] = m;
    }
    return [...keptOther, ...byId.values];
  }

  /// 회비 납부 병합: id 합집합. 원격 납부가 비어 있으면 로컬 납부 유지.
  static List<dynamic> _mergeDuesPayments(
    List? localList,
    List? remoteList,
    List? remoteDuesSettings,
  ) {
    final remoteSettings = _asDynamicMaps(remoteDuesSettings);
    final remoteSettingIds = remoteSettings
        .map((d) => d['id'] as String?)
        .whereType<String>()
        .toSet();
    final remotePayments = _asDynamicMaps(remoteList);

    // 원격에 회비 설정은 있는데 납부 목록이 비면 → 로컬 납부 보존 (덮어쓰기 방지)
    if (remotePayments.isEmpty) {
      return List<dynamic>.from(localList ?? const []);
    }

    final byId = <String, Map<String, dynamic>>{};
    for (final e in localList ?? const []) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final id = m['id'] as String?;
      if (id == null || id.isEmpty) continue;
      byId[id] = m;
    }
    for (final m in remotePayments) {
      final id = m['id'] as String?;
      if (id == null || id.isEmpty) continue;
      byId[id] = m;
    }

    // 원격에 없는 회비설정(다른 모임·시드) 납부는 그대로 유지된 상태
    if (remoteSettingIds.isEmpty) return byId.values.toList();
    return byId.values.toList();
  }

  /// 모임 사진 병합: 원격이 imageOmitted/빈 URL이면 로컬 data URI를 유지.
  static List<dynamic> _mergeClubPhotos(
    List? localList,
    List? remoteList,
    String clubId,
  ) {
    final keptOther = <dynamic>[
      ...(localList ?? []).where((e) => e is Map && e['clubId'] != clubId),
    ];
    final localById = <String, Map<String, dynamic>>{};
    for (final e in localList ?? const []) {
      if (e is! Map) continue;
      if (e['clubId'] != clubId) continue;
      final id = e['id'] as String?;
      if (id == null || id.isEmpty) continue;
      localById[id] = Map<String, dynamic>.from(e);
    }
    final remoteById = <String, Map<String, dynamic>>{};
    for (final e in remoteList ?? const []) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final id = m['id'] as String?;
      if (id == null || id.isEmpty) continue;
      remoteById[id] = m;
    }

    final merged = <Map<String, dynamic>>[];
    for (final id in {...localById.keys, ...remoteById.keys}) {
      if (_deletedPhotoIds.contains(id)) continue;
      final local = localById[id];
      final remote = remoteById[id];
      if (remote == null) {
        merged.add(local!);
        continue;
      }
      if (local == null) {
        // 로컬에서 지운 직후 원격 스냅샷이 늦게 오면 되살리지 않음
        // (다른 기기 신규 업로드는 로컬에 없는 remote-only → 유지)
        // 방금 삭제한 id는 위에서 skip. 그 외 remote-only는 추가.
        merged.add(remote);
        continue;
      }
      final localUrl = local['imageUrl'] as String? ?? '';
      final remoteUrl = remote['imageUrl'] as String? ?? '';
      final omitted = remote['imageOmitted'] == true;
      final out = Map<String, dynamic>.from(remote);
      if ((remoteUrl.isEmpty || omitted) && localUrl.isNotEmpty) {
        out['imageUrl'] = localUrl;
        out.remove('imageOmitted');
      }
      merged.add(out);
    }
    return [...keptOther, ...merged];
  }

  static List<dynamic> _mergeJoinRequests(List local, List remote) {
    final byId = <String, Map<String, dynamic>>{};
    for (final e in [...local, ...remote]) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final id = m['id'] as String?;
      if (id == null) continue;
      byId[id] = m;
    }
    return byId.values.toList();
  }

  /// watch 콜백용: remote slice → 현재 번들에 병합
  static ClubDataBundle applyRemoteSlice(
    ClubDataBundle local,
    String clubId,
    Map<String, dynamic> remote,
  ) =>
      _mergeClubIntoBundle(local, clubId, remote);

  /// 디버그/테스트용 JSON 크기
  static int estimateJsonBytes(Map<String, dynamic> m) =>
      utf8.encode(jsonEncode(m)).length;

  static Future<void> _pushOverflowDocs(
    String clubId,
    Map<int, Map<String, dynamic>> schYears,
    Map<int, Map<String, dynamic>> ledYears,
    Map<String, dynamic> previousYears,
  ) async {
    for (final entry in schYears.entries) {
      await _db
          .doc(FirestorePaths.clubOpsScheduleYear(clubId, entry.key))
          .set({
        ...entry.value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: false));
    }
    for (final entry in ledYears.entries) {
      await _db.doc(FirestorePaths.clubOpsLedgerYear(clubId, entry.key)).set({
        ...entry.value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: false));
    }

    final keepSch = schYears.keys.toSet();
    final keepLed = ledYears.keys.toSet();
    for (final year in ClubOpsOverflow.yearsOf(previousYears['sch'])) {
      if (keepSch.contains(year)) continue;
      try {
        await _db.doc(FirestorePaths.clubOpsScheduleYear(clubId, year)).delete();
      } catch (_) {}
    }
    for (final year in ClubOpsOverflow.yearsOf(previousYears['led'])) {
      if (keepLed.contains(year)) continue;
      try {
        await _db.doc(FirestorePaths.clubOpsLedgerYear(clubId, year)).delete();
      } catch (_) {}
    }
  }

  static Future<void> _attachOverflowDocs(
    String clubId,
    Map<String, dynamic> remote,
  ) async {
    final index = remote['overflowYears'];
    if (index is! Map) return;

    final schYears = ClubOpsOverflow.yearsOf(index['sch']);
    final ledYears = ClubOpsOverflow.yearsOf(index['led']);
    if (schYears.isEmpty && ledYears.isEmpty) return;

    try {
      var schLoaded = 0;
      var ledLoaded = 0;
      for (final year in schYears) {
        final snap =
            await _db.doc(FirestorePaths.clubOpsScheduleYear(clubId, year)).get();
        if (!snap.exists || snap.data() == null) continue;
        ClubOpsOverflow.mergeSidecarIntoRemote(remote, snap.data()!);
        schLoaded++;
      }
      for (final year in ledYears) {
        final snap =
            await _db.doc(FirestorePaths.clubOpsLedgerYear(clubId, year)).get();
        if (!snap.exists || snap.data() == null) continue;
        ClubOpsOverflow.mergeSidecarIntoRemote(remote, snap.data()!);
        ledLoaded++;
      }
      // 인덱스는 있는데 사이드카가 없으면 빈 배열로 로컬 일정을 지우지 않는다.
      if (schYears.isNotEmpty && schLoaded == 0) {
        for (final key in ClubOpsOverflow.scheduleKeys) {
          remote.remove(key);
        }
      }
      if (ledYears.isNotEmpty && ledLoaded == 0) {
        for (final key in ClubOpsOverflow.ledgerKeys) {
          remote.remove(key);
        }
      }
    } catch (e) {
      debugPrint('[ClubOpsSync] overflow attach fail club=$clubId: $e');
      ClubOpsOverflow.markOverflowUnavailable(remote);
    }
  }
}
