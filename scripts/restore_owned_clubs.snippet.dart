  /// MockStore / Prefs / 리포에서 내가 만든·총무인 모임 복구.
  /// 어드민에만 보이는 c_* 모임이 내 모임에서 빠지는 치명 버그 방지.
  Future<bool> _restoreOwnedClubsFromStores(String authUserId) async {
    var changed = false;
    final aliases = _authAliases(authUserId);

    // 1) Mock 공유 저장소 (+ prefs 보강)
    final store = AppDependencies.instance.mockDataStore;
    if (store != null) {
      try {
        await store.hydrateFromDisk();
      } catch (_) {}
      try {
        await _forceScanPrefsIntoStore(store);
      } catch (e) {
        debugPrint('[ClubProvider] prefs→store scan skip: $e');
      }
      for (final c in List<Club>.from(store.clubs)) {
        if (!c.id.startsWith('c_')) continue;
        if (!_isStoreClubOwnedByMe(store, c, aliases)) continue;
        if (_ingestOwnedClub(c, store.membersOf(c.id))) changed = true;
        _ensureStoreMembershipAliases(store, c, aliases);
      }
      if (changed) {
        unawaited(MockStorePersistence.save(store));
      }
    }

    // 2) 계정 번들 — user_guest 의 c_* 는 전부 내 모임으로 복구
    for (final uid in <String>{
      authUserId,
      'user_guest',
      'user_me',
      'user_other',
    }) {
      try {
        final bundle = await ClubPersistence.load(uid);
        if (bundle == null) continue;
        for (final c in [...bundle.myClubs, ...bundle.allClubs]) {
          if (!c.id.startsWith('c_')) continue;
          final mine = aliases.contains(c.creatorId) ||
              (uid == authUserId &&
                  (c.myRole == '총무' || c.myRole == '회장')) ||
              (authUserId == 'user_guest' && uid == 'user_guest');
          if (!mine) continue;
          final related = bundle.members
              .where((m) =>
                  m.id == 'm_creator_${c.id}' ||
                  m.id.startsWith('m_${c.id}_') ||
                  m.name == currentUserName)
              .toList();
          if (_ingestOwnedClub(c, related)) changed = true;
        }
      } catch (e) {
        debugPrint('[ClubProvider] restore bundle $uid skip: $e');
      }
    }

    // 3) Prefs 전수 스캔
    try {
      if (await _restoreOwnedClubsFromRawPrefs(aliases, authUserId)) {
        changed = true;
      }
    } catch (e) {
      debugPrint('[ClubProvider] raw prefs restore skip: $e');
    }

    // 4) 리포 fetchMyClubs + discoverable(creatorId)
    for (final uid in aliases) {
      try {
        final remote =
            await AppDependencies.instance.clubRepository.fetchMyClubs(uid);
        for (final c in remote) {
          if (_legacyMockClubIds.contains(c.id)) continue;
          if (c.id.startsWith('seed_')) continue;
          if (_ingestOwnedClub(c, const [])) changed = true;
        }
      } catch (e) {
        debugPrint('[ClubProvider] restore fetchMyClubs($uid) skip: $e');
      }
    }
    try {
      final discoverable = await AppDependencies.instance.clubRepository
          .fetchDiscoverableClubs();
      for (final c in discoverable) {
        if (!c.id.startsWith('c_')) continue;
        if (c.creatorId.isEmpty || !aliases.contains(c.creatorId)) continue;
        if (_ingestOwnedClub(c, const [])) changed = true;
      }
    } catch (e) {
      debugPrint('[ClubProvider] restore discoverable skip: $e');
    }

    if (changed) {
      final names = _myClubs
          .where((c) => c.id.startsWith('c_'))
          .map((c) => c.name)
          .toList();
      debugPrint('[ClubProvider] restored owned clubs → $names');
    }
    return changed;
  }

  void _ensureStoreMembershipAliases(
    MockDataStore store,
    Club c,
    Set<String> aliases,
  ) {
    final creator = store.membersByClub[c.id]?['m_creator_${c.id}'] ??
        store
            .membersOf(c.id)
            .where((m) => m.name == currentUserName)
            .firstOrNull;
    if (creator == null) return;
    store.addMember(
      clubId: c.id,
      member: creator,
      bumpCount: false,
      alsoAsIds: aliases.toList(),
      persist: false,
    );
  }

  Future<void> _forceScanPrefsIntoStore(MockDataStore store) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.reload();
    } catch (_) {}
    for (final key in prefs.getKeys()) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty || !raw.contains('"c_')) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final map = Map<String, dynamic>.from(decoded);
        for (final listKey in ['myClubs', 'allClubs', 'clubs']) {
          final list = map[listKey];
          if (list is! List) continue;
          for (final item in list) {
            if (item is! Map) continue;
            final m = Map<String, dynamic>.from(item);
            final id = m['id'] as String? ?? '';
            if (!id.startsWith('c_')) continue;
            final existing = store.clubById(id);
            final scannedCreator = m['creatorId'] as String? ?? '';
            store.upsertClub(
              Club(
                id: id,
                name: m['name'] as String? ?? existing?.name ?? '모임',
                myRole: m['myRole'] as String? ?? existing?.myRole ?? '총무',
                memberCount:
                    m['memberCount'] as int? ?? existing?.memberCount ?? 1,
                creatorId: scannedCreator.isNotEmpty
                    ? scannedCreator
                    : (existing?.creatorId ?? ''),
                region: m['region'] as String? ?? existing?.region ?? '',
                industry: m['industry'] as String? ?? existing?.industry ?? '',
                teamCount: m['teamCount'] as int? ?? existing?.teamCount ?? 4,
                description: m['description'] as String? ??
                    existing?.description ??
                    '',
                createdAt: m['createdAt'] != null
                    ? DateTime.tryParse(m['createdAt'] as String) ??
                        existing?.createdAt ??
                        DateTime.now()
                    : existing?.createdAt ?? DateTime.now(),
              ),
              moderationStatus: m['moderationStatus'] as String? ??
                  store.clubModerationStatusOrNull(id) ??
                  'active',
              persist: false,
            );
          }
        }
      } catch (_) {}
    }
  }

  Future<bool> _restoreOwnedClubsFromRawPrefs(
    Set<String> aliases,
    String authUserId,
  ) async {
    var changed = false;
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.reload();
    } catch (_) {}
    for (final key in prefs.getKeys()) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty || !raw.contains('"c_')) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final map = Map<String, dynamic>.from(decoded);
        final authInKey = map['authUserId'] as String?;
        for (final listKey in ['myClubs', 'allClubs', 'clubs']) {
          final list = map[listKey];
          if (list is! List) continue;
          for (final item in list) {
            if (item is! Map) continue;
            final m = Map<String, dynamic>.from(item);
            final id = m['id'] as String? ?? '';
            if (!id.startsWith('c_')) continue;
            final creatorId = m['creatorId'] as String? ?? '';
            final myRole = m['myRole'] as String? ?? '';
            final name = m['name'] as String? ?? '';
            final mine = aliases.contains(creatorId) ||
                (authInKey != null && aliases.contains(authInKey)) ||
                (authUserId == 'user_guest' &&
                    (key.contains('user_guest') ||
                        authInKey == 'user_guest')) ||
                (creatorId.isEmpty &&
                    (myRole == '총무' || myRole == '회장') &&
                    aliases.contains(authUserId));
            if (!mine) continue;
            final club = Club(
              id: id,
              name: name.isEmpty ? '모임' : name,
              myRole: myRole.isEmpty ? '총무' : myRole,
              memberCount: m['memberCount'] as int? ?? 1,
              creatorId: creatorId.isNotEmpty ? creatorId : authUserId,
              region: m['region'] as String? ?? '',
              industry: m['industry'] as String? ?? '',
              teamCount: m['teamCount'] as int? ?? 4,
              description: m['description'] as String? ?? '',
              createdAt: m['createdAt'] != null
                  ? DateTime.tryParse(m['createdAt'] as String) ?? DateTime.now()
                  : DateTime.now(),
            );
            if (_ingestOwnedClub(club, const [])) changed = true;
          }
        }
      } catch (_) {}
    }
    return changed;
  }

