const fs = require('fs');
const path = require('path');

// 1) Persist appUsers in MockStorePersistence
const persistPath = path.join(
  __dirname,
  '..',
  'lib',
  'data',
  'repositories',
  'mock',
  'mock_store_persistence.dart',
);
let persist = fs.readFileSync(persistPath, 'utf8');

if (!persist.includes("json['appUsers']")) {
  persist = persist.replace(
    `      debugPrint(
        '[MockStorePersistence] loaded $loaded non-seed clubs, '
        '\${store.pendingJoinRequests.length} join requests from disk',
      );`,
    `      // 플랫폼 가입 사용자 (오늘 가입자 집계용)
      for (final item in (json['appUsers'] as List? ?? const [])) {
        final m = Map<String, dynamic>.from(item as Map);
        final id = m['id'] as String?;
        if (id == null || id.isEmpty) continue;
        store.upsertAppUser(
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
      debugPrint(
        '[MockStorePersistence] loaded $loaded non-seed clubs, '
        '\${store.pendingJoinRequests.length} join requests, '
        '\${store.appUsers.length} appUsers from disk',
      );`,
  );

  // Fix JS escaping for dart interpolations - the file should keep $store
  persist = persist
    .replace(
      "'\\${store.pendingJoinRequests.length} join requests, '",
      "'\${store.pendingJoinRequests.length} join requests, '",
    )
    .replace(
      "'\\${store.appUsers.length} appUsers from disk'",
      "'\${store.appUsers.length} appUsers from disk'",
    );

  persist = persist.replace(
    `          'pendingJoinRequests':
              store.pendingJoinRequests.map(_encodeJoinRequest).toList(),
          'savedAt': DateTime.now().toIso8601String(),`,
    `          'pendingJoinRequests':
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
          'savedAt': DateTime.now().toIso8601String(),`,
  );

  // upsertAppUser during load calls notify/persist — use direct list add instead
  persist = persist.replace(
    `      // 플랫폼 가입 사용자 (오늘 가입자 집계용)
      for (final item in (json['appUsers'] as List? ?? const [])) {
        final m = Map<String, dynamic>.from(item as Map);
        final id = m['id'] as String?;
        if (id == null || id.isEmpty) continue;
        store.upsertAppUser(
          MockAppUser(
            id: id,
            name: m['name'] as String? ?? '',
            phone: m['phone'] as String? ?? '',
            gender: m['gender'] as String? ?? '남',
            createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ??
                DateTime.now(),
          ),
        );
      }`,
    `      // 플랫폼 가입 사용자 (오늘 가입자 집계용)
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
      }`,
  );

  fs.writeFileSync(persistPath, persist);
  console.log('OK mock_store_persistence appUsers');
} else {
  console.log('skip persist (already patched)');
}

console.log('done');
