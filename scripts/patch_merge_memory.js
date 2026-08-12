const fs = require('fs');
const path = require('path');
const p = path.join(__dirname, '..', 'lib', 'providers', 'club_provider.dart');
let s = fs.readFileSync(p, 'utf8');

const old = `  Future<void> mergeSharedJoinRequests() async {
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
  }`;

const neu = `  Future<void> mergeSharedJoinRequests() async {
    final shared = await SharedJoinRequestStore.loadAll();
    final mem = SharedJoinRequestStore.peekMemory();
    final store = AppDependencies.instance.mockDataStore;
    final fromStore = store == null
        ? const <JoinRequest>[]
        : List<JoinRequest>.from(store.pendingJoinRequests);

    if (store != null) {
      for (final req in [...shared, ...mem]) {
        store.upsertPendingJoinRequest(req, persist: false);
      }
      if (shared.isNotEmpty || mem.isNotEmpty) {
        unawaited(MockStorePersistence.save(store));
      }
    }

    final seen = <String>{};
    for (final req in [...mem, ...shared, ...fromStore]) {
      if (req.status != JoinRequestStatus.pending) continue;
      if (!seen.add(req.id)) continue;
      _ingestPendingJoinRequest(req);
    }
  }`;

if (!s.includes(old)) {
  console.error('merge block not found');
  process.exit(1);
}
fs.writeFileSync(p, s.replace(old, neu));
console.log('OK');
