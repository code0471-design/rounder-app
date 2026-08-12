const fs = require('fs');
const path = require('path');

const p = path.join(__dirname, '..', 'lib', 'providers', 'club_provider.dart');
let s = fs.readFileSync(p, 'utf8');

const start = s.indexOf('    // 다른 계정에서 신청한 가입 요청·알림을 공유 스토어에서 병합');
if (start < 0) {
  console.error('start marker missing');
  process.exit(1);
}
const endMarker = '  String _normalizeLegacyClubId(String clubId) {';
const end = s.indexOf(endMarker, start);
if (end < 0) {
  console.error('end marker missing');
  process.exit(1);
}

const dollar = '$';
const neu = `
    // 다른 계정에서 신청한 가입 요청·알림을 공유 스토어에서 병합
    await mergeSharedJoinRequests();
    notifyListeners();
  }

  /// 공유 대기열(localStorage + MockDataStore)의 가입 신청을 현재 계정에 병합.
  /// 로그인/계정 전환 직후 호출해 총무 알림 유실을 막는다.
  Future<void> mergeSharedJoinRequests() async {
    final shared = await SharedJoinRequestStore.loadAll();
    final store = AppDependencies.instance.mockDataStore;
    final fromStore = store == null
        ? const <JoinRequest>[]
        : List<JoinRequest>.from(store.pendingJoinRequests);

    if (store != null) {
      for (final req in shared) {
        store.upsertPendingJoinRequest(req, persist: false);
      }
      if (shared.isNotEmpty) {
        unawaited(MockStorePersistence.save(store));
      }
    }

    final seen = <String>{};
    for (final req in [...shared, ...fromStore]) {
      if (req.status != JoinRequestStatus.pending) continue;
      if (!seen.add(req.id)) continue;
      _ingestPendingJoinRequest(req);
    }
  }

  void _ingestPendingJoinRequest(JoinRequest req) {
    final clubId = _normalizeLegacyClubId(req.clubId);
    final normalized = clubId == req.clubId
        ? req
        : JoinRequest(
            id: req.id,
            clubId: clubId,
            userId: req.userId,
            userName: req.userName,
            userGender: req.userGender,
            userHandicap: req.userHandicap,
            message: req.message,
            referrerId: req.referrerId,
            referrerName: req.referrerName,
            status: req.status,
            requestedAt: req.requestedAt,
            reviewedBy: req.reviewedBy,
            reviewedAt: req.reviewedAt,
          );

    final exists = _joinRequests.any(
      (r) =>
          r.id == normalized.id ||
          (r.clubId == normalized.clubId &&
              r.userId == normalized.userId &&
              r.status == JoinRequestStatus.pending),
    );
    if (!exists) {
      _joinRequests.add(normalized);
    }

    final notiId = 'noti_jr_${dollar}{normalized.id}';
    if (_appNotifications.any((n) => n.id == notiId)) return;

    final inMyClubs = _myClubs.any((c) => c.id == clubId);
    if (!inMyClubs) return;

    final club = _allClubs.where((c) => c.id == clubId).firstOrNull ??
        _myClubs.where((c) => c.id == clubId).firstOrNull;
    final notifyTarget = joinRequestNotifyTargetId(clubId);
    final notifyRole = hasActiveTreasurer(clubId)
        ? ClubMemberRole.treasurer
        : ClubMemberRole.president;
    _appNotifications.insert(
      0,
      AppNotification(
        id: notiId,
        type: AppNotificationType.joinRequest,
        clubId: clubId,
        clubName: club?.name ?? '모임',
        isAdmin: true,
        title: '가입 신청',
        body: '${dollar}{normalized.userName}님이 가입을 신청했습니다 → ${dollar}notifyRole 수신',
        createdAt: normalized.requestedAt,
        targetId: normalized.id,
        targetUserId: notifyTarget ?? currentUserId,
        isRead: false,
      ),
    );
  }

`.replaceAll('${dollar}', '$');

s = s.slice(0, start) + neu + s.slice(end);
fs.writeFileSync(p, s);
console.log('OK mergeSharedJoinRequests patched');
