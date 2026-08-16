import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/agent/agent_store.dart';
import '../../features/auth/app_lock.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/sync/sync_service.dart';
import 'local_cache.dart';

/// Efface les données **de ce compte** — les dossiers des autres comptes restent.
Future<void> wipeLocalUserData(WidgetRef ref) async {
  final uid = ref.read(authProvider).user?.id;
  final cache = ref.read(localCacheProvider);
  if (uid != null && uid.isNotEmpty) {
    await cache.delete(LocalCacheKeys.agentDossiersFor(uid));
    await ref.read(offlineQueueProvider).clearForOwner(uid);
  }
  await cache.delete(LocalCacheKeys.agentDossiers);
  await cache.delete(LocalCacheKeys.profile);
  await ref.read(appLockProvider.notifier).clear();
  ref.read(agentDossiersRevisionProvider.notifier).state++;
  ref.read(agentCoopProvider.notifier).reset();
  ref.read(syncPendingProvider.notifier).state = 0;
  ref.read(syncErrorProvider.notifier).state = null;
}
