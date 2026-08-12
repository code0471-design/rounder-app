import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/data/club_sample_catalog.dart';
import '../../../models/club_model.dart';
import 'mock_data_store.dart';

/// MockDataStore 영속화 — 앱/어드민이 같은 localStorage를 공유
abstract final class MockStorePersistence {
  static const _key = 'rounder_mock_store_v2';

  static final _seedIds =
      ClubSampleCatalog.clubs.map((c) => c.id).toSet();

  /// 시드가 아닌 모임 저장 (템플릿 c1~c10 + 사용자 c_*)
  static bool isPersistableUserClub(String id) {
    if (_seedIds.contains(id) || id.startsWith('seed_')) return false;
    return true;
  }

  static Future<void> loadInto(MockDataStore store) async {
    final prefs = await SharedPreferences.getInstance();
    // 다른 탭(앱)에서 쓴 localStorage를 어드민이 읽으려면 캐시 무효화 필요
    try {
      await prefs.reload();
    } catch (e) {
      debugPrint('[MockStorePersistence] prefs.reload skip: $e');
    }
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final clubs = json['clubs'] as List? ?? const [];
      var loaded = 0;
      for (final item in clubs) {
        final m = Map<String, dynamic>.from(item as Map);
        final club = _decodeClub(m);
        if (!isPersistableUserClub(club.id)) continue;
        final status = m['moderationStatus'] as String? ?? 'pending';
        final maxMembers = m['maxMembers'] as int? ?? 20;
        store.upsertClub(
          club,
          moderationStatus: status,
          maxMembers: maxMembers,
          persist: false,
        );
        for (final mem in (m['members'] as List? ?? const [])) {
          store.addMember(
            clubId: club.id,
            member: _decodeMember(Map<String, dynamic>.from(mem as Map)),
            bumpCount: false,
            persist: false,
          );
        }
        loaded++;
      }
      final mods = Map<String, dynamic>.from(json['moderation'] as Map? ?? {});
      for (final e in mods.entries) {
        final id = e.key;
        // 데모 시드 모임은 항상 active 유지 — 예전 블라인드/종료 상태가
        // hydrate 때 덮어써 "전체 모임 2개"처럼 보이는 것을 방지
        if (_seedIds.contains(id) || id.startsWith('seed_')) {
          store.setClubModerationStatus(id, 'active', persist: false);
          continue;
        }
        store.setClubModerationStatus(id, e.value as String, persist: false);
      }
      // 계정 전환과 무관한 공유 가입 신청
      store.pendingJoinRequests.clear();
      for (final item in (json['pendingJoinRequests'] as List? ?? const [])) {
        final req = _decodeJoinRequest(Map<String, dynamic>.from(item as Map));
        if (req != null) store.pendingJoinRequests.add(req);
      }
      // 플랫폼 가입 사용자 (오늘 가입자 집계용)
      final loadedUsers = <MockAppUser>[];
      for (final item in (json['appUsers'] as List? ?? const [])) {
        final m = Map<String, dynamic>.from(item as Map);
        final id = m['id'] as String?;
        if (id == null || id.isEmpty) continue;
        loadedUsers.add(
          MockAppUser(
            id: id,
            name: m['name'] as String? ?? '',
            phone: m['phone'] as String? ?? '',
            gender: m['gender'] as String? ?? '남',
            createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ??
                DateTime.now(),
          ),
        );
      }
      if (loadedUsers.isNotEmpty) {
        store.appUsers
          ..clear()
          ..addAll(loadedUsers);
      }
      debugPrint(
        '[MockStorePersistence] loaded $loaded non-seed clubs, '
        '${store.pendingJoinRequests.length} join requests, '
        '${store.appUsers.length} appUsers from disk',
      );
    } catch (e) {
      debugPrint('[MockStorePersistence] load fail: $e');
    }
  }

  static Future<void> save(MockDataStore store) async {
    try {
      final toSave =
          store.clubs.where((c) => isPersistableUserClub(c.id)).toList();
      final clubsJson = toSave.map((c) {
        final members = store.membersOf(c.id);
        return {
          'id': c.id,
          'name': c.name,
          'imageUrl': c.imageUrl,
          'myRole': c.myRole,
          'memberCount': c.memberCount,
          'creatorId': c.creatorId,
          'region': c.region,
          'industry': c.industry,
          'teamCount': c.teamCount,
          'description': c.description,
          'createdAt': c.createdAt.toIso8601String(),
          'moderationStatus': store.clubModerationStatus(c.id),
          'maxMembers': store.clubMaxMembers(c.id),
          'members': members.map(_encodeMember).toList(),
        };
      }).toList();

      final moderation = <String, String>{};
      for (final c in store.clubs) {
        moderation[c.id] = store.clubModerationStatus(c.id);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'version': 3,
          'clubs': clubsJson,
          'moderation': moderation,
          'pendingJoinRequests':
              store.pendingJoinRequests.map(_encodeJoinRequest).toList(),
          'appUsers': store.appUsers
              .map(
                (u) => {
                  'id': u.id,
                  'name': u.name,
                  'phone': u.phone,
                  'gender': u.gender,
                  'createdAt': u.createdAt.toIso8601String(),
                },
              )
              .toList(),
          'savedAt': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('[MockStorePersistence] save fail: $e');
    }
  }

  static Map<String, dynamic> _encodeMember(Member m) => {
        'id': m.id,
        'name': m.name,
        'gender': m.gender,
        'phone': m.phone,
        'memberType': m.memberType,
        'role': m.role,
        'handicap': m.handicap,
        'joinDate': m.joinDate?.toIso8601String(),
        'status': m.status,
      };

  static Member _decodeMember(Map<String, dynamic> m) => Member(
        id: m['id'] as String,
        name: m['name'] as String? ?? '',
        gender: m['gender'] as String? ?? '남',
        phone: m['phone'] as String?,
        memberType: m['memberType'] as String? ?? '정회원',
        role: m['role'] as String? ?? '정회원',
        handicap: (m['handicap'] as num?)?.toDouble(),
        joinDate: m['joinDate'] != null
            ? DateTime.tryParse(m['joinDate'] as String)
            : null,
        status: m['status'] as String? ?? '활성',
      );

  static Club _decodeClub(Map<String, dynamic> m) => Club(
        id: m['id'] as String,
        name: m['name'] as String? ?? '',
        imageUrl: m['imageUrl'] as String?,
        myRole: m['myRole'] as String? ?? '총무',
        memberCount: m['memberCount'] as int? ?? 1,
        creatorId: m['creatorId'] as String? ?? '',
        region: m['region'] as String? ?? '',
        industry: m['industry'] as String? ?? '',
        teamCount: m['teamCount'] as int? ?? 4,
        description: m['description'] as String? ?? '',
        createdAt: m['createdAt'] != null
            ? DateTime.tryParse(m['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  static Map<String, dynamic> _encodeJoinRequest(JoinRequest r) => {
        'id': r.id,
        'clubId': r.clubId,
        'userId': r.userId,
        'userName': r.userName,
        'userGender': r.userGender,
        'userHandicap': r.userHandicap,
        'message': r.message,
        'referrerId': r.referrerId,
        'referrerName': r.referrerName,
        'status': r.status.name,
        'requestedAt': r.requestedAt.toIso8601String(),
        'reviewedBy': r.reviewedBy,
        'reviewedAt': r.reviewedAt?.toIso8601String(),
      };

  static JoinRequest? _decodeJoinRequest(Map<String, dynamic> m) {
    final id = m['id'] as String?;
    final clubId = m['clubId'] as String?;
    final userId = m['userId'] as String?;
    if (id == null || clubId == null || userId == null) return null;
    final statusName = m['status'] as String? ?? 'pending';
    final status = JoinRequestStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => JoinRequestStatus.pending,
    );
    // 승인/거절된 건은 공유 대기열에 두지 않음
    if (status != JoinRequestStatus.pending) return null;
    return JoinRequest(
      id: id,
      clubId: clubId,
      userId: userId,
      userName: m['userName'] as String? ?? '',
      userGender: m['userGender'] as String? ?? '남',
      userHandicap: (m['userHandicap'] as num?)?.toDouble(),
      message: m['message'] as String? ?? '',
      referrerId: m['referrerId'] as String?,
      referrerName: m['referrerName'] as String?,
      status: status,
      requestedAt: DateTime.tryParse(m['requestedAt'] as String? ?? '') ??
          DateTime.now(),
      reviewedBy: m['reviewedBy'] as String?,
      reviewedAt: m['reviewedAt'] != null
          ? DateTime.tryParse(m['reviewedAt'] as String)
          : null,
    );
  }
}
